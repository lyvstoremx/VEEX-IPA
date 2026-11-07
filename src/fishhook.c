// Copyright (c) 2013, Facebook, Inc.
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#include "fishhook.h"

static struct rebindings_entry *_rebindings_head;

static int prepend_rebindings(struct rebindings_entry **head,
                              struct rebinding rebindings[], size_t nel) {
  struct rebindings_entry *n =
      (struct rebindings_entry *)malloc(sizeof(struct rebindings_entry));
  if (!n) return -1;
  n->rebindings = (struct rebinding *)malloc(sizeof(struct rebinding) * nel);
  if (!n->rebindings) { free(n); return -1; }
  memcpy(n->rebindings, rebindings, sizeof(struct rebinding) * nel);
  n->rebindings_nel = nel;
  n->next = *head;
  *head = n;
  return 0;
}

static void perform_rebinding_with_section(struct rebindings_entry *rebindings,
                                           section_t *section, intptr_t slide,
                                           nlist_t *symtab, char *strtab,
                                           uint32_t *indirect_symtab) {
  uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
  void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->offset);
  for (uint32_t i = 0; i < section->size / sizeof(void *); i++) {
    uint32_t symtab_index = indirect_symbol_indices[i];
    if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL ||
        symtab_index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) continue;
    uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
    char *symbol_name = strtab + strtab_offset;
    struct rebindings_entry *cur = rebindings;
    while (cur) {
      for (uint32_t j = 0; j < cur->rebindings_nel; j++) {
        if (strlen(symbol_name) > 1 &&
            strcmp(&symbol_name[1], cur->rebindings[j].name) == 0) {
          if (cur->rebindings[j].replaced != NULL &&
              indirect_symbol_bindings[i] != cur->rebindings[j].replacement) {
            *(cur->rebindings[j].replaced) = indirect_symbol_bindings[i];
          }
          indirect_symbol_bindings[i] = cur->rebindings[j].replacement;
          goto next;
        }
      }
      cur = cur->next;
    }
  next:;
  }
}

int rebind_symbols_image(void *header, intptr_t slide,
                         struct rebinding rebindings[], size_t rebindings_nel) {
  struct rebindings_entry *head = NULL;
  if (prepend_rebindings(&head, rebindings, rebindings_nel) < 0) return -1;
  head->next = _rebindings_head;

  struct mach_header_64 *mh = (struct mach_header_64 *)header;
  struct load_command *cmd = (struct load_command *)((uintptr_t)mh + sizeof(struct mach_header_64));
  for (uint32_t i = 0; i < mh->ncmds; i++) {
    if (cmd->cmd == LC_SYMTAB) {
      struct symtab_command *symtab_cmd = (struct symtab_command *)cmd;
      nlist_t *symtab = (nlist_t *)((uintptr_t)header + symtab_cmd->symoff);
      char *strtab = (char *)((uintptr_t)header + symtab_cmd->stroff);
      struct load_command *cmd2 = (struct load_command *)((uintptr_t)mh + sizeof(struct mach_header_64));
      for (uint32_t j = 0; j < mh->ncmds; j++) {
        if (cmd2->cmd == LC_SEGMENT_64) {
          struct segment_command_64 *seg = (struct segment_command_64 *)cmd2;
          if (!strcmp(seg->segname, "__DATA") || !strcmp(seg->segname, "__DATA_CONST")) {
            struct section_64 *sect = (struct section_64 *)((uintptr_t)seg + sizeof(struct segment_command_64));
            for (uint32_t k = 0; k < seg->nsects; k++) {
              if ((sect[k].flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS ||
                  (sect[k].flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {
                perform_rebinding_with_section(head, (section_t *)&sect[k], slide,
                                               symtab, strtab,
                                               (uint32_t *)((uintptr_t)header + symtab_cmd->indirectsymoff));
              }
            }
          }
        }
        cmd2 = (struct load_command *)((uintptr_t)cmd2 + cmd2->cmdsize);
      }
      break;
    }
    cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
  }
  return 0;
}

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel) {
  int ret = prepend_rebindings(&_rebindings_head, rebindings, rebindings_nel);
  if (ret < 0) return ret;
  if (!_rebindings_head->next) {
    _dyld_register_func_for_add_image(rebind_symbols_image);
  } else {
    uint32_t c = _dyld_image_count();
    for (uint32_t i = 0; i < c; i++) {
      const struct mach_header *h = _dyld_get_image_header(i);
      rebind_symbols_image((void *)h, _dyld_get_image_vmaddr_slide(i),
                           _rebindings_head->rebindings, _rebindings_head->rebindings_nel);
    }
  }
  return 0;
}
