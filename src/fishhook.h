// Copyright (c) 2013, Facebook, Inc.
#ifndef FISHHOOK_H
#define FISHHOOK_H

#include <stddef.h>
#include <stdint.h>

struct rebinding {
  const char *name;
  void *replacement;
  void **replaced;
};

struct rebindings_entry {
  struct rebinding *rebindings;
  size_t rebindings_nel;
  struct rebindings_entry *next;
};

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);
int rebind_symbols_image(void *header, intptr_t slide,
                         struct rebinding rebindings[], size_t rebindings_nel);

#endif
