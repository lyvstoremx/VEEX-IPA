#include "fishhook.h"
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#define VXLOG(...) do { fprintf(stderr, "[VEEX] " __VA_ARGS__); fputc('\n', stderr); } while (0)

static int sec_ok(const char *seg, const char *sect) {
    if (strcmp(seg, "__DATA") && strcmp(seg, "__DATA_CONST") &&
        strcmp(seg, "__AUTH") && strcmp(seg, "__AUTH_CONST")) return 0;
    if (!strcmp(sect, "__got")) return 1;
    if (!strcmp(sect, "__auth_got")) return 1;
    if (!strcmp(sect, "__la_symbol_ptr")) return 1;
    if (!strcmp(sect, "__nl_symbol_ptr")) return 1;
    if (!strcmp(sect, "__auth_ptr")) return 1;
    return 0;
}

static void patch_sec(uintptr_t start, uintptr_t end, void *target,
                      void *repl, int *hits, int *blk, int rw) {
    vm_size_t pg = (vm_size_t)getpagesize();
    vm_prot_t back = rw ? (VM_PROT_READ | VM_PROT_WRITE) : VM_PROT_READ;
    uintptr_t s;

    for (s = start; s + sizeof(void *) <= end; s += sizeof(void *)) {
        if (*(void **)s != target) continue;

        uintptr_t page = s & ~(pg - 1);
        kern_return_t kr = vm_protect(mach_task_self(), page, pg, 0,
                                      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        if (kr != KERN_SUCCESS)
            kr = vm_protect(mach_task_self(), page, pg, 0,
                            VM_PROT_READ | VM_PROT_WRITE);
        if (kr != KERN_SUCCESS) { (*blk)++; continue; }

        *(void **)s = repl;
        (*hits)++;
        vm_protect(mach_task_self(), page, pg, 0, back);
    }
}

void *vxHookSym(const char *name, void *repl, void **origOut) {
    if (!name || !repl) return NULL;

    void *target = dlsym(RTLD_DEFAULT, name);
    if (!target) { VXLOG("b! %s nodlsym", name); return NULL; }
    if (target == repl) { VXLOG("b! %s ya", name); return NULL; }

    int hits = 0, blk = 0;
    uint32_t n = _dyld_image_count(), i;

    for (i = 0; i < n; i++) {
        const struct mach_header_64 *mh =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!mh || mh->magic != MH_MAGIC_64) continue;

        VXLOG("b e%u", i);

        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const uint8_t *p = (const uint8_t *)(mh + 1);
        uint32_t c;

        for (c = 0; c < mh->ncmds; c++) {
            const struct load_command *lc = (const struct load_command *)p;
            if (lc->cmdsize < sizeof(*lc)) break;

            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *sc =
                    (const struct segment_command_64 *)lc;
                const struct section_64 *s = (const struct section_64 *)(sc + 1);
                uint32_t k;

                for (k = 0; k < sc->nsects; k++, s++) {
                    if (!sec_ok(sc->segname, s->sectname)) continue;
                    if (s->size < sizeof(void *)) continue;

                    uintptr_t a = (uintptr_t)(s->addr + slide);
                    int before = hits;
                    int rw = !strcmp(sc->segname, "__DATA") ||
                             !strcmp(sc->segname, "__AUTH");

                    patch_sec(a, a + (uintptr_t)s->size, target, repl,
                              &hits, &blk, rw);

                    if (hits > before)
                        VXLOG("b +%u:%s@%p", i, s->sectname, (void *)a);
                }
            }
            p += lc->cmdsize;
        }
    }

    VXLOG("b<%s hits=%d blk=%d old=%p", name, hits, blk, target);

    if (!hits) return NULL;
    if (origOut) *origOut = target;
    return target;
}
