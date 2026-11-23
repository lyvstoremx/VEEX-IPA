// VEEX shell build 180 — identificar el enumerador de regiones

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/mach.h>
#include <libkern/OSCacheControl.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <pthread.h>
#include <dlfcn.h>
#include <time.h>

#define VX_BUILD  180
#define VX_N      31
#define VX_MAXLOG 40
#define VX_MAXKEY 400
#define VX_TRIES  40
#define VX_HIDE   1
#define VX_SHIFT  1

#ifndef SECTION_TYPE
#define SECTION_TYPE 0xff
#endif
#ifndef S_LAZY_SYMBOL_POINTERS
#define S_LAZY_SYMBOL_POINTERS 0x7
#endif
#ifndef S_NON_LAZY_SYMBOL_POINTERS
#define S_NON_LAZY_SYMBOL_POINTERS 0x6
#endif
#ifndef S_SYMBOL_STUBS
#define S_SYMBOL_STUBS 0x8
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
static uint64_t vxT0 = 0;

static vxFn     vxOrig[VX_N];
static uint32_t vxCount[VX_N];
static int      vxDone[VX_N];
static uint32_t vxPatched = 0;
static int      vxTries = 0;

static uint64_t vxSelfLo = 0, vxSelfHi = 0;
static uint32_t vxSelfIdx = 0;
static const char *vxFake = "/usr/lib/libobjc.A.dylib";

static const uint8_t vxPath[VX_N] = {
    0, 0, 0, 0, 1,
    1, 1, 1, 1, 1,
    1, 2,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0,
    0, 0, 0, 0, 0,
    0, 0, 0, 0
};

static const char *vxNames[VX_N] = {
    "_csops", "_csops_audittoken", "_ptrace", "_sysctl", "_sysctlbyname",
    "_stat", "_stat$INODE64", "_lstat", "_access", "_open", "_dlopen", "_dlsym",
    "_task_info", "_mach_vm_region", "_vm_region", "_vm_region_64",
    "_proc_pidinfo", "_kdebug_trace", "_getppid", "_getpid",
    "_objc_setHook_getClass", "_mach_port_deallocate",
    "_dyld_image_count", "_dyld_get_image_header", "_dyld_get_image_name",
    "_dyld_get_image_vmaddr_slide", "_dladdr",
    "_mach_vm_region_recurse", "_vm_region_recurse_64",
    "_mach_vm_region_recurse_64", "_vm_region_recurse"
};

static const char *vxKeys[] = {
    "mobileprovision", "SignedByEsign", "Cydia", "Sileo", "sshd", "apt",
    "stash", "dpkg", "liblog.so", "substrate", "ellekit", "hooker",
    "injector", "systemhook", "loader.app", "suid_profile", "binpack",
    "cydia", "var/lib", "var/Lib", "sftp", NULL
};

static NSString *vxDoc(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

static uint64_t vxNow(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ull + (uint64_t)ts.tv_nsec / 1000000ull;
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

static int vxKey(const char *s) {
    if (!s) return 0;
    for (int i = 0; vxKeys[i]; i++) {
        if (strstr(s, vxKeys[i])) return 1;
    }
    return 0;
}

static void vxNote(int i, uint64_t ret, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
    uint32_t n = __atomic_add_fetch(&vxCount[i], 1, __ATOMIC_RELAXED);
    const char *nm = vxNames[i];

    const char *sp = NULL;
    if (vxPath[i] == 1) sp = (const char *)a;
    else if (vxPath[i] == 2) sp = (const char *)b;
    if (sp && (uintptr_t)sp <= 4096) sp = NULL;

    int key = vxKey(sp);
    if (!strcmp(nm, "_sysctl") || !strcmp(nm, "_dlopen")) key = 1;
    if (i >= 27) key = 1;
    if (!key && n > VX_MAXLOG) return;
    if (n > VX_MAXKEY) return;
    if (vxBusy) return;
    vxBusy = 1;

    NSString *line = [NSString stringWithFormat:@"C %s t=%llu r=%llx a=%llx,%llx,%llx,%llx",
                      nm, vxT0 ? vxNow() - vxT0 : 0, ret, a, b, c, d];

    if (!strcmp(nm, "_sysctl") && (uintptr_t)a > 4096 && b >= 1) {
        int cnt = (int)b;
        if (cnt > 4) cnt = 4;
        const int *mib = (const int *)(uintptr_t)a;
        NSMutableString *m = [NSMutableString stringWithString:@"mib="];
        for (int k = 0; k < cnt; k++) [m appendFormat:@"%d,", mib[k]];
        line = [line stringByAppendingFormat:@" %@", m];
        if (cnt >= 2 && mib[0] == 1 && mib[1] == 14 && c > 4096) {
            line = [line stringByAppendingFormat:@" pflag=%x",
                    *(const int *)((uintptr_t)c + 32)];
        }
    }
    if (i >= 27 && (uintptr_t)b > 4096) {
        line = [line stringByAppendingFormat:@" va=%llx sz=%llx",
                *(const uint64_t *)(uintptr_t)b, *(const uint64_t *)(uintptr_t)c];
    }
    if (sp) {
        size_t len = strnlen(sp, 150);
        if (len > 0 && len < 150) line = [line stringByAppendingFormat:@" s=%s", sp];
    }
    vxLogRaw(line);
    vxBusy = 0;
}

#define VX_WRAP(n)                                                                   \
static uint64_t vxW##n(uint64_t a, uint64_t b, uint64_t c, uint64_t d,               \
                       uint64_t e, uint64_t f, uint64_t g, uint64_t h) {             \
    uint64_t r = vxOrig[n] ? vxOrig[n](a, b, c, d, e, f, g, h) : 0;                  \
    vxNote(n, r, a, b, c, d);                                                        \
    return r;                                                                        \
}

VX_WRAP(0)  VX_WRAP(1)  VX_WRAP(2)  VX_WRAP(3)  VX_WRAP(4)  VX_WRAP(5)
VX_WRAP(6)  VX_WRAP(7)  VX_WRAP(8)  VX_WRAP(9)  VX_WRAP(10) VX_WRAP(11)
VX_WRAP(12) VX_WRAP(13) VX_WRAP(14) VX_WRAP(15) VX_WRAP(16) VX_WRAP(17)
VX_WRAP(18) VX_WRAP(19) VX_WRAP(20) VX_WRAP(21)

static uint32_t vxRealCount(void) {
    return vxOrig[22] ? ((uint32_t (*)(void))(uintptr_t)vxOrig[22])() : _dyld_image_count();
}

static uint32_t vxShift(uint32_t i) {
#if VX_SHIFT
    if (vxSelfIdx && i >= vxSelfIdx) return i + 1;
#endif
    return i;
}

static uint64_t vxW22(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint32_t n = vxRealCount();
    if (++vxCount[22] <= 3) vxLogRaw([NSString stringWithFormat:@"D count %u", n]);
    return n ? n - 1 : 0;
}

static uint64_t vxW23(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint32_t r = vxShift((uint32_t)a);
    if (r >= vxRealCount()) return 0;
    if (++vxCount[23] <= 3) vxLogRaw([NSString stringWithFormat:@"D header %u->%u", (uint32_t)a, r]);
    return vxOrig[23] ? vxOrig[23](r, 0, 0, 0, 0, 0, 0, 0) : 0;
}

static uint64_t vxW24(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint32_t r = vxShift((uint32_t)a);
    if (r >= vxRealCount()) return 0;
    if (++vxCount[24] <= 3) vxLogRaw([NSString stringWithFormat:@"D name %u->%u", (uint32_t)a, r]);
    return vxOrig[24] ? vxOrig[24](r, 0, 0, 0, 0, 0, 0, 0) : 0;
}

static uint64_t vxW25(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint32_t r = vxShift((uint32_t)a);
    if (r >= vxRealCount()) return 0;
    return vxOrig[25] ? vxOrig[25](r, 0, 0, 0, 0, 0, 0, 0) : 0;
}

static uint64_t vxW26(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint64_t r = vxOrig[26] ? vxOrig[26](a, b, c, d, e, f, g, h) : 0;
    if (r && b && vxSelfLo && a >= vxSelfLo && a < vxSelfHi) {
        Dl_info *di = (Dl_info *)(uintptr_t)b;
        if (di->dli_fname) {
            vxLogRaw([NSString stringWithFormat:@"DL t=%llu %llx %s",
                      vxT0 ? vxNow() - vxT0 : 0, a, di->dli_fname]);
        }
#if VX_HIDE
        di->dli_fname = vxFake;
        di->dli_sname = NULL;
        di->dli_saddr = NULL;
#endif
    }
    return r;
}

VX_WRAP(27) VX_WRAP(28) VX_WRAP(29) VX_WRAP(30)

static vxFn vxTab[VX_N] = {
    vxW0,  vxW1,  vxW2,  vxW3,  vxW4,  vxW5,  vxW6,  vxW7,
    vxW8,  vxW9,  vxW10, vxW11, vxW12, vxW13, vxW14, vxW15,
    vxW16, vxW17, vxW18, vxW19, vxW20, vxW21, vxW22, vxW23,
    vxW24, vxW25, vxW26, vxW27, vxW28, vxW29, vxW30
};

static void vxProt(uint64_t addr, size_t len) {
    vm_size_t ps = vm_page_size;
    uintptr_t a = (uintptr_t)addr & ~((uintptr_t)ps - 1);
    uintptr_t e = ((uintptr_t)addr + len + ps - 1) & ~((uintptr_t)ps - 1);
    vm_protect(mach_task_self(), (vm_address_t)a, (vm_size_t)(e - a),
               false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
}

static void vxStub(uint8_t *at, uint64_t dst) {
    uint32_t *w = (uint32_t *)at;
    w[0] = 0xD2800000u | ((uint32_t)(dst & 0xFFFF) << 5) | 16;
    w[1] = 0xF2A00000u | ((uint32_t)((dst >> 16) & 0xFFFF) << 5) | 16;
    w[2] = 0xF2C00000u | ((uint32_t)((dst >> 32) & 0xFFFF) << 5) | 16;
    w[3] = 0xF2E00000u | ((uint32_t)((dst >> 48) & 0xFFFF) << 5) | 16;
    w[4] = 0xD61F0200u;
    sys_icache_invalidate(at, 20);
}

static const struct mach_header_64 *vxFind(void) {
    for (uint32_t i = 0, n = vxRealCount(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) return (const void *)_dyld_get_image_header(i);
    }
    return NULL;
}

static void vxSelf(void) {
    for (uint32_t i = 0, n = vxRealCount(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!p || !strstr(p, "libobjc.A.dylib")) continue;
        if (!strncmp(p, "/usr/lib", 8) || !strncmp(p, "/private/preboot", 16)) continue;
        const struct mach_header_64 *h = (const void *)_dyld_get_image_header(i);
        if (!h) continue;
        uint64_t hi = 0;
        const struct load_command *lc = (const void *)(h + 1);
        for (uint32_t k = 0; k < h->ncmds; k++) {
            if (lc->cmdsize < 8) break;
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *sg = (const void *)lc;
                uint64_t e = sg->vmaddr + sg->vmsize;
                if (e > hi) hi = e;
            }
            lc = (const void *)((const char *)lc + lc->cmdsize);
        }
        vxSelfIdx = i;
        vxSelfLo = (uint64_t)h;
        vxSelfHi = (uint64_t)h + hi;
        vxLogRaw([NSString stringWithFormat:@"self %u %llx-%llx", i, vxSelfLo, vxSelfHi]);
        return;
    }
    vxLogRaw(@"sin self");
}

static uint32_t vxPatch(void) {
    const struct mach_header_64 *h = vxFind();
    if (!h) return 0;

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    const struct dysymtab_command *dys = NULL;
    uint64_t txtVm = 0, leVm = 0, leOff = 0, leSize = 0;
    int haveText = 0;

    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB)   st  = (const void *)lc;
        if (lc->cmd == LC_DYSYMTAB) dys = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { txtVm = sg->vmaddr; haveText = 1; }
            if (!strcmp(sg->segname, "__LINKEDIT")) {
                leVm = sg->vmaddr; leOff = sg->fileoff; leSize = sg->filesize;
            }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st || !dys || !haveText || !leVm) { vxLogRaw(@"tablas incompletas"); return 0; }
    if (!dys->nindirectsyms) { vxLogRaw(@"sin indirect"); return 0; }
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

    uint32_t hits = 0, stubs = 0;
    const struct load_command *sc = (const void *)(h + 1);

    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (sc->cmdsize < 8) break;
        if (sc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)sc;
            const struct section_64 *s = (const void *)(sg + 1);
            for (uint32_t j = 0; j < sg->nsects; j++, s++) {
                uint8_t type = s->flags & SECTION_TYPE;
                int stub = (type == S_SYMBOL_STUBS);
                if (!stub && type != S_LAZY_SYMBOL_POINTERS &&
                    type != S_NON_LAZY_SYMBOL_POINTERS) continue;

                uint8_t *base = (uint8_t *)h + (s->addr - txtVm);
                uint32_t cnt = stub ? (s->reserved2 ? (uint32_t)(s->size / s->reserved2) : 0)
                                    : (uint32_t)(s->size / 8);

                for (uint32_t k = 0; k < cnt; k++) {
                    uint32_t si = s->reserved1 + k;
                    if (si >= dys->nindirectsyms) break;
                    uint32_t sidx = ind[si];
                    if (sidx == INDIRECT_SYMBOL_LOCAL || sidx == INDIRECT_SYMBOL_ABS) continue;
                    if (sidx >= st->nsyms || !nl[sidx].n_un.n_strx) continue;
                    const char *nm = str + nl[sidx].n_un.n_strx;

                    for (int t = 0; t < VX_N; t++) {
                        if (strcmp(nm, vxNames[t])) continue;
                        if (vxDone[t]) break;
                        if (!stub && type != S_LAZY_SYMBOL_POINTERS) break;
                        if (stub && s->reserved2 < 20) break;

                        void *d = dlsym(RTLD_DEFAULT, vxNames[t] + 1);
                        if (!vxOrig[t]) vxOrig[t] = (vxFn)d;

                        if (stub) {
                            uint8_t *at = base + (uint64_t)k * s->reserved2;
                            vxProt((uint64_t)at, 20);
                            vxStub(at, (uint64_t)vxTab[t]);
                            vxLogRaw([NSString stringWithFormat:@"S %s stub=%llx", nm, (uint64_t)at]);
                            stubs++;
                        } else {
                            uint64_t *slot = (uint64_t *)(base + (uint64_t)k * 8);
                            vxProt((uint64_t)slot, 8);
                            *slot = (uint64_t)vxTab[t];
                            vxLogRaw([NSString stringWithFormat:@"P %s slot=%llx", nm, (uint64_t)slot]);
                            hits++;
                        }
                        vxDone[t] = 1;
                        break;
                    }
                }
            }
        }
        sc = (const void *)((const char *)sc + sc->cmdsize);
    }

    vxPatched += hits + stubs;
    vxLogRaw([NSString stringWithFormat:@"pasada slot=%u stub=%u total=%u", hits, stubs, vxPatched]);
    return hits + stubs;
}

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
        vxSelf();
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
    vxT0 = vxNow();
    vxLogRaw(@"==== 180 regiones ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}
