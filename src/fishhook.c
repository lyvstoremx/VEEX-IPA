// Copyright (c) 2013, Facebook, Inc. — versión 64 bits
#include <stdbool.h>
#include <stdint.h>
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

#ifndef INDIRECT_SYMBOL_LOCAL
#define INDIRECT_SYMBOL_LOCAL 0x80000000
#endif
#ifndef INDIRECT_SYMBOL_ABS
#define INDIRECT_SYMBOL_ABS 0x40000000
#endif

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
                                           struct section_64 *section,
                                           intptr_t slide,
                                           struct nlist_64 *symtab,
                                           char *strtab,
                                           uint32_t *indirect_symtab) {
  uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
  void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);

  for (uint32_t i = 0; i < section->size / sizeof(void *); i++) {
    uint32_t symtab_index = indirect_symbol_indices[i];
    if (symtab_index == INDIRECT_SYMBOL_ABS ||
        symtab_index == INDIRECT_SYMBOL_LOCAL ||
        symtab_index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
      continue;
    }
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
  struct symtab_command *symtab_cmd = NULL;
  struct dysymtab_command *dysym_cmd = NULL;

  struct load_command *cmd =
      (struct load_command *)((uintptr_t)mh + sizeof(struct mach_header_64));
  for (uint32_t i = 0; i < mh->ncmds; i++) {
    if (cmd->cmd == LC_SYMTAB) symtab_cmd = (struct symtab_command *)cmd;
    if (cmd->cmd == LC_DYSYMTAB) dysym_cmd = (struct dysymtab_command *)cmd;
    cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
  }
  if (!symtab_cmd || !dysym_cmd) return 0;

  struct nlist_64 *symtab =
      (struct nlist_64 *)((uintptr_t)header + symtab_cmd->symoff);
  char *strtab = (char *)((uintptr_t)header + symtab_cmd->stroff);
  uint32_t *indirect =
      (uint32_t *)((uintptr_t)header + dysym_cmd->indirectsymoff);

  struct load_command *cmd2 =
      (struct load_command *)((uintptr_t)mh + sizeof(struct mach_header_64));
  for (uint32_t j = 0; j < mh->ncmds; j++) {
    if (cmd2->cmd == LC_SEGMENT_64) {
      struct segment_command_64 *seg = (struct segment_command_64 *)cmd2;
      if (!strcmp(seg->segname, "__DATA") ||
          !strcmp(seg->segname, "__DATA_CONST")) {
        struct section_64 *sect =
            (struct section_64 *)((uintptr_t)seg + sizeof(struct segment_command_64));
        for (uint32_t k = 0; k < seg->nsects; k++) {
          uint32_t type = sect[k].flags & SECTION_TYPE;
          if (type == S_LAZY_SYMBOL_POINTERS || type == S_NON_LAZY_SYMBOL_POINTERS) {
            perform_rebinding_with_section(head, &sect[k], slide,
                                           symtab, strtab, indirect);
          }
        }
      }
    }
    cmd2 = (struct load_command *)((uintptr_t)cmd2 + cmd2->cmdsize);
  }
  return 0;
}

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel) {
  int ret = prepend_rebindings(&_rebindings_head, rebindings, rebindings_nel);
  if (ret < 0) return ret;

  if (!_rebindings_head->next) {
    _dyld_register_func_for_add_image(
        (void (*)(const struct mach_header *, intptr_t))rebind_symbols_image);
  } else {
    uint32_t c = _dyld_image_count();
    for (uint32_t i = 0; i < c; i++) {
      const struct mach_header *h = _dyld_get_image_header(i);
      rebind_symbols_image((void *)h, _dyld_get_image_vmaddr_slide(i),
                           _rebindings_head->rebindings,
                           _rebindings_head->rebindings_nel);
    }
  }
  return 0;
}
