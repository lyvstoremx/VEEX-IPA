#ifndef VX_FISHHOOK_H
#define VX_FISHHOOK_H

#include <stdint.h>
#include <stddef.h>

/* rebindeo por comparacion de slots, sin parsear tablas de simbolos */
void *vxHookSym(const char *name, void *repl, void **origOut);

#endif
