#include "fishhook.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <mach-o/loader.h>

struct rebindings_entry {
    struct rebinding *rebindings;
    size_t n;
    struct rebindings_entry *next;
};
static struct rebindings_entry *_head;

static int prepend(struct rebindings_entry **head, struct rebinding rb[], size_t n) {
    struct rebindings_entry *e = calloc(1, sizeof(*e));
    if (!e) return -1;
    e->rebindings = malloc(sizeof(struct rebinding) * n);
    if (!e->rebindings) { free(e); return -1; }
    memcpy(e->rebindings, rb, sizeof(struct rebinding) * n);
    e->n = n;
    e->next = *head;
    *head = e;
    return 0;
}

static void do_section(struct rebindings_entry *e, struct section_64 *sect, intptr_t slide,
                       struct nlist_64 *symtab, char *strtab, uint32_t *indirect) {
    uint32_t *idx = indirect + sect->reserved1;
    void **bind = (void **)((uintptr_t)slide + sect->addr);
    for (uint32_t i = 0; i < sect->size / sizeof(void *); i++) {
        uint32_t sym = idx[i];
        if (sym == INDIRECT_SYMBOL_LOCAL || sym == INDIRECT_SYMBOL_ABS) continue;
        char *name = strtab + symtab[sym].n_un.n_strx;
        if (name[0] == '_') name++;
        struct rebindings_entry *cur = e;
        while (cur) {
            for (size_t j = 0; j < cur->n; j++) {
                if (strcmp(name, cur->rebindings[j].name)) continue;
                if (cur->rebindings[j].replaced && bind[i] != cur->rebindings[j].replacement)
                    *(cur->rebindings[j].replaced) = bind[i];
                bind[i] = cur->rebindings[j].replacement;
            }
            cur = cur->next;
        }
    }
}

static void do_image(struct rebindings_entry *e, const struct mach_header *header, intptr_t slide) {
    if (header->magic != MH_MAGIC_64) return;
    const struct mach_header_64 *mh = (const struct mach_header_64 *)header;
    struct symtab_command *st = NULL;
    struct dysymtab_command *dt = NULL;
    uint8_t *p = (uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        struct load_command *lc = (struct load_command *)p;
        if (lc->cmd == LC_SYMTAB) st = (struct symtab_command *)lc;
        else if (lc->cmd == LC_DYSYMTAB) dt = (struct dysymtab_command *)lc;
        p += lc->cmdsize;
    }
    if (!st || !dt || !dt->nindirectsyms) return;

    struct nlist_64 *symtab = (struct nlist_64 *)((uintptr_t)slide + st->symoff);
    char *strtab = (char *)((uintptr_t)slide + st->stroff);
    uint32_t *indirect = (uint32_t *)((uintptr_t)slide + dt->indirectsymoff);

    p = (uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        struct load_command *lc = (struct load_command *)p;
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64 *)lc;
            struct section_64 *sect = (struct section_64 *)(seg + 1);
            for (uint32_t j = 0; j < seg->nsects; j++) {
                uint32_t t = sect[j].flags & SECTION_TYPE;
                if (t == S_LAZY_SYMBOL_POINTERS || t == S_NON_LAZY_SYMBOL_POINTERS)
                    do_section(e, &sect[j], slide, symtab, strtab, indirect);
            }
        }
        p += lc->cmdsize;
    }
}

int rebind_symbols(struct rebinding rb[], size_t n) {
    if (prepend(&_head, rb, n) < 0) return -1;
    for (uint32_t i = 0; i < _dyld_image_count(); i++)
        do_image(_head, _dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
    return 0;
}
