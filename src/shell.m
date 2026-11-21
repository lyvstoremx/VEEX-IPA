// VEEX shell build 171 — enganche pasivo por LC_DYSYMTAB (UnityFramework, __la_symbol_ptr)
// Modo 0 = pasivo: registra y llama al original. No sanea nada.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/mach.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <pthread.h>

#define VX_BUILD  171
#define VX_MODE   0
#define VX_N      22
#define VX_MAXLOG 40
#define VX_TRIES  40

#ifndef SECTION_TYPE
#define SECTION_TYPE 0xff
#endif
#ifndef S_LAZY_SYMBOL_POINTERS
#define S_LAZY_SYMBOL_POINTERS 0x7
#endif
#ifndef INDIRECT_SYMBOL_LOCAL
#define INDIRECT_SYMBOL_LOCAL 0x80000000
#define INDIRECT_SYMBOL_ABS   0x40000000
#endif

typedef uint64_t (*vxFn)(uint64_t, uint64_t, uint64_t, uint64_t,
                         uint64_t, uint64_t, uint64_t, uint64_t);

static pthread_mutex_t vxM = PTHREAD_MUTEX_INITIALIZER;
static FILE *vxF = NULL;
static __thread int vxBusy = 0;

static vxFn     vxOrig[VX_N];
static uint32_t vxCount[VX_N];
static uint32_t vxPatched = 0;
static int      vxTries = 0;

static const char *vxNames[VX_N] = {
    "_csops", "_csops_audittoken", "_ptrace", "_sysctl", "_sysctlbyname",
    "_stat", "_stat$INODE64", "_lstat", "_access", "_open", "_dlopen", "_dlsym",
    "_task_info", "_mach_vm_region", "_vm_region", "_vm_region_64",
    "_proc_pidinfo", "_kdebug_trace", "_getppid", "_getpid",
    "_objc_setHook_getClass", "_mach_port_deallocate"
};

static NSString *vxDoc(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

static void vxLogRaw(NSString *s) {
    pthread_mutex_lock(&vxM);
    if (!vxF) {
        NSString *p = [vxDoc() stringByAppendingPathComponent:@"a.dat"];
        vxF = fopen(p.UTF8String, "a");
    }
    if (vxF) {
        fputs([NSString stringWithFormat:@"[%d] %@\n", VX_BUILD, s].UTF8String, vxF);
        fflush(vxF);
    }
    pthread_mutex_unlock(&vxM);
}

// ---------------- registro ----------------

static void vxNote(int i, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
    uint32_t n = __atomic_add_fetch(&vxCount[i], 1, __ATOMIC_RELAXED);
    if (n > VX_MAXLOG) return;
    if (vxBusy) return;
    vxBusy = 1;

    const char *nm = vxNames[i];
    const char *sp = NULL;
    if (!strcmp(nm, "_dlsym")) sp = (const char *)b;
    else if (!strcmp(nm, "_dlopen") || !strcmp(nm, "_sysctlbyname") ||
             !strcmp(nm, "_open") || !strcmp(nm, "_stat") ||
             !strcmp(nm, "_lstat") || !strcmp(nm, "_access")) sp = (const char *)a;

    NSString *line = [NSString stringWithFormat:@"C %s c=%u a=%llx,%llx,%llx,%llx",
                      nm, n, a, b, c, d];
    if (sp && (uintptr_t)sp > 4096) {
        size_t len = strnlen(sp, 150);
        if (len > 0 && len < 150) {
            line = [line stringByAppendingFormat:@" s=%s", sp];
        }
    }
    vxLogRaw(line);
    vxBusy = 0;
}

#define VX_WRAP(n)                                                                   \
static uint64_t vxW##n(uint64_t a, uint64_t b, uint64_t c, uint64_t d,               \
                       uint64_t e, uint64_t f, uint64_t g, uint64_t h) {             \
    vxNote(n, a, b, c, d);                                                           \
    return vxOrig[n] ? vxOrig[n](a, b, c, d, e, f, g, h) : 0;                        \
}

VX_WRAP(0)  VX_WRAP(1)  VX_WRAP(2)  VX_WRAP(3)  VX_WRAP(4)  VX_WRAP(5)
VX_WRAP(6)  VX_WRAP(7)  VX_WRAP(8)  VX_WRAP(9)  VX_WRAP(10) VX_WRAP(11)
VX_WRAP(12) VX_WRAP(13) VX_WRAP(14) VX_WRAP(15) VX_WRAP(16) VX_WRAP(17)
VX_WRAP(18) VX_WRAP(19) VX_WRAP(20) VX_WRAP(21)

static vxFn vxTab[VX_N] = {
    vxW0,  vxW1,  vxW2,  vxW3,  vxW4,  vxW5,  vxW6,  vxW7,
    vxW8,  vxW9,  vxW10, vxW11, vxW12, vxW13, vxW14, vxW15,
    vxW16, vxW17, vxW18, vxW19, vxW20, vxW21
};

// ---------------- parcheo ----------------

static void vxProt(uint64_t addr, size_t len) {
    vm_size_t ps = vm_page_size;
    uintptr_t a = (uintptr_t)addr & ~((uintptr_t)ps - 1);
    uintptr_t e = ((uintptr_t)addr + len + ps - 1) & ~((uintptr_t)ps - 1);
    vm_protect(mach_task_self(), (vm_address_t)a, (vm_size_t)(e - a),
               false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
}

static const struct mach_header_64 *vxFind(void) {
    for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) {
            vxLogRaw([NSString stringWithFormat:@"img=%u", i]);
            return (const void *)_dyld_get_image_header(i);
        }
    }
    return NULL;
}

static uint32_t vxPatch(void) {
    const struct mach_header_64 *h = vxFind();
    if (!h) return 0;

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    const struct dysymtab_command *dys = NULL;
    uint64_t txtVm = 0, leVm = 0, leOff = 0, leSize = 0;

    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB)    st  = (const void *)lc;
        if (lc->cmd == LC_DYSYMTAB)  dys = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) txtVm = sg->vmaddr;
            if (!strcmp(sg->segname, "__LINKEDIT")) {
                leVm = sg->vmaddr; leOff = sg->fileoff; leSize = sg->filesize;
            }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st || !dys || !leVm || !txtVm) { vxLogRaw(@"sin tablas"); return 0; }
    if (st->symoff < leOff || st->symoff >= leOff + leSize) { vxLogRaw(@"symoff fuera"); return 0; }
    if (st->stroff < leOff || st->stroff >= leOff + leSize) { vxLogRaw(@"stroff fuera"); return 0; }
    if (dys->indirectsymoff < leOff ||
        dys->indirectsymoff + dys->nindirectsyms * 4 > leOff + leSize) {
        vxLogRaw(@"indirect fuera"); return 0;
    }

    const uint8_t *le   = (const uint8_t *)h + (leVm - txtVm);
    const struct nlist_64 *nl = (const struct nlist_64 *)(le + (st->symoff - leOff));
    const char *str     = (const char *)(le + (st->stroff - leOff));
    const uint32_t *ind = (const uint32_t *)(le + (dys->indirectsymoff - leOff));

    uint32_t hits = 0, got = 0;
    uint32_t nseg = h->ncmds;
    const struct load_command *sc = (const void *)(h + 1);

    for (uint32_t i = 0; i < nseg; i++) {
        if (sc->cmdsize < 8) break;
        if (sc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)sc;
            const struct section_64 *s = (const void *)(sg + 1);
            for (uint32_t j = 0; j < sg->nsects; j++, s++) {
                uint8_t type = s->flags & SECTION_TYPE;
                if (type != S_LAZY_SYMBOL_POINTERS &&
                    type != S_NON_LAZY_SYMBOL_POINTERS) continue;

                uint8_t *base = (uint8_t *)h + (s->addr - txtVm);
                uint32_t cnt  = (uint32_t)(s->size / 8);
                for (uint32_t k = 0; k < cnt; k++) {
                    uint32_t si = s->reserved1 + k;
                    if (si >= dys->nindirectsyms) break;
                    uint32_t sidx = ind[si];
                    if (sidx == INDIRECT_SYMBOL_LOCAL || sidx == INDIRECT_SYMBOL_ABS) continue;
                    if (sidx >= st->nsyms || !nl[sidx].n_un.n_strx) continue;
                    const char *nm = str + nl[sidx].n_un.n_strx;

                    for (int t = 0; t < VX_N; t++) {
                        if (strcmp(nm, vxNames[t])) continue;
                        if (vxOrig[t]) break;
                        if (type != S_LAZY_SYMBOL_POINTERS) {
                            vxLogRaw([NSString stringWithFormat:@"GOT %s", nm]);
                            got++;
                            break;
                        }
                        uint64_t *slot = (uint64_t *)(base + k * 8);
                        vxProt((uint64_t)slot, 8);
                        vxOrig[t] = (vxFn)*slot;
                        *slot = (uint64_t)vxTab[t];
                        vxLogRaw([NSString stringWithFormat:@"P %s slot=%llx", nm, (uint64_t)*slot]);
                        hits++;
                        break;
                    }
                }
            }
        }
        sc = (const void *)((const char *)sc + sc->cmdsize);
    }

    vxPatched += hits;
    vxLogRaw([NSString stringWithFormat:@"pasada patch=%u got=%u total=%u", hits, got, vxPatched]);
    return hits;
}

// ---------------- arranque ----------------

static void vxFinal(void) {
    NSMutableString *s = [NSMutableString stringWithFormat:@"fin patch=%u", vxPatched];
    for (int i = 0; i < VX_N; i++) {
        if (vxCount[i]) [s appendFormat:@" %s=%u", vxNames[i], vxCount[i]];
    }
    vxLogRaw(s);
}

static void vxRetry(void);

static void vxStep(void) {
    if (vxPatch() > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12ull * NSEC_PER_SEC),
                       dispatch_get_global_queue(0, 0), ^{ vxFinal(); });
        return;
    }
    if (++vxTries >= VX_TRIES) { vxLogRaw(@"sin enganche"); vxFinal(); return; }
    vxRetry();
}

static void vxRetry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200ull * NSEC_PER_MSEC),
                   dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}

__attribute__((constructor))
static void vxInit(void) {
    vxLogRaw(@"==== 171 pasivo ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}
