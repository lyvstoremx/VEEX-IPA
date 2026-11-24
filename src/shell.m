// VEEX shell build 190 — prot con EXECUTE y escritura a stride

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/mach.h>
#import <mach/task_info.h>
#include <libkern/OSCacheControl.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <pthread.h>
#include <dlfcn.h>
#include <time.h>

#define VX_BUILD  190
#define VX_N      28
#define VX_MAXLOG 40
#define VX_TRIES  40
#define VX_HIDE   1

#ifndef SECTION_TYPE
#define SECTION_TYPE 0xff
#endif
#ifndef S_LAZY_SYMBOL_POINTERS
#define S_LAZY_SYMBOL_POINTERS 0x7
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
static char    *vxSelfPath = NULL;
static const char *vxFake = "/usr/lib/libobjc.A.dylib";

static const uint8_t vxPath[VX_N] = {
    0, 0, 0, 0, 1,
    1, 1, 1, 1, 1,
    1, 2,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0,
    0, 0, 0, 0, 0, 0
};

static const char *vxNames[VX_N] = {
    "_csops", "_csops_audittoken", "_ptrace", "_sysctl", "_sysctlbyname",
    "_stat", "_stat$INODE64", "_lstat", "_access", "_open", "_dlopen", "_dlsym",
    "_task_info", "_mach_vm_region", "_vm_region", "_vm_region_64",
    "_proc_pidinfo", "_kdebug_trace", "_getppid", "_getpid",
    "_objc_setHook_getClass", "_mach_port_deallocate",
    "__dyld_image_count", "__dyld_get_image_header", "__dyld_get_image_name",
    "__dyld_get_image_vmaddr_slide", "_dladdr", "_objc_copyImageNames"
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

// --- dyld_all_image_infos sin símbolo privado ---

typedef const struct dyld_all_image_infos *(*vxInfosFn)(void);

static const struct dyld_all_image_infos *vxInfos(void) {
    static vxInfosFn f = NULL;
    static int t = 0;
    if (!t) {
        t = 1;
        f = (vxInfosFn)dlsym(RTLD_DEFAULT, "_dyld_get_all_image_infos");
        if (!f) f = (vxInfosFn)dlsym(RTLD_DEFAULT, "dyld_get_all_image_infos");
    }
    if (f) {
        const struct dyld_all_image_infos *a = f();
        if (a) return a;
    }
    struct task_dyld_info tdi;
    mach_msg_type_number_t cnt = (mach_msg_type_number_t)(sizeof(tdi) / sizeof(natural_t));
    if (task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&tdi, &cnt) == KERN_SUCCESS) {
        if (tdi.all_image_info_addr) return (const void *)(uintptr_t)tdi.all_image_info_addr;
    }
    return NULL;
}

// ---------------- registro ----------------

static void vxNote(int i, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
    uint32_t n = __atomic_add_fetch(&vxCount[i], 1, __ATOMIC_RELAXED);
    if (n > VX_MAXLOG) return;
    if (vxBusy) return;
    vxBusy = 1;

    const char *nm = vxNames[i];
    const char *sp = NULL;
    if (vxPath[i] == 1) sp = (const char *)a;
    else if (vxPath[i] == 2) sp = (const char *)b;

    NSString *line = [NSString stringWithFormat:@"C %s t=%llu r=%llx a=%llx,%llx",
                      nm, vxT0 ? vxNow() - vxT0 : 0, a, a, b];
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
    uint64_t r = vxOrig[n] ? vxOrig[n](a, b, c, d, e, f, g, h) : 0;                  \
    vxNote(n, r, a, b, c);                                                           \
    return r;                                                                        \
}

VX_WRAP(0)  VX_WRAP(1)  VX_WRAP(2)  VX_WRAP(3)  VX_WRAP(4)  VX_WRAP(5)
VX_WRAP(6)  VX_WRAP(7)  VX_WRAP(8)  VX_WRAP(9)  VX_WRAP(10) VX_WRAP(11)
VX_WRAP(12) VX_WRAP(13) VX_WRAP(14) VX_WRAP(15) VX_WRAP(16) VX_WRAP(17)
VX_WRAP(18) VX_WRAP(19) VX_WRAP(20) VX_WRAP(21)

static uint32_t vxRealCount(void) {
    return vxOrig[22] ? ((uint32_t (*)(void))(uintptr_t)vxOrig[22])() : _dyld_image_count();
}

static uint32_t vxIdx(void) {
    static uint32_t c = 0;
    if (!vxSelfPath) return 0;
    if (c && vxOrig[24]) {
        const char *p = ((const char *(*)(uint32_t))(uintptr_t)vxOrig[24])(c);
        if (p && !strcmp(p, vxSelfPath)) return c;
        c = 0;
    }
    uint32_t n = vxRealCount();
    for (uint32_t i = 0; i < n && i < 4096; i++) {
        const char *p = vxOrig[24] ? ((const char *(*)(uint32_t))(uintptr_t)vxOrig[24])(i) : NULL;
        if (p && !strcmp(p, vxSelfPath)) { c = i; return i; }
    }
    return 0;
}

static uint32_t vxShift(uint32_t i) {
    uint32_t o = vxIdx();
    if (!o) return i;
    return i >= o ? i + 1 : i;
}

static uint64_t vxW22(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint64_t r = vxOrig[22] ? vxOrig[22](a, b, c, d, e, f, g, h) : 0;
    if (r && vxIdx()) r--;
    vxNote(22, r, a, b, c);
    return r;
}

static uint64_t vxW23(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint64_t r = vxOrig[23] ? vxOrig[23](vxShift((uint32_t)a), b, c, d, e, f, g, h) : 0;
    vxNote(23, r, a, b, c);
    return r;
}

static uint64_t vxW24(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint64_t r = vxOrig[24] ? vxOrig[24](vxShift((uint32_t)a), b, c, d, e, f, g, h) : 0;
    vxNote(24, r, a, b, c);
    return r;
}

static uint64_t vxW25(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    uint64_t r = vxOrig[25] ? vxOrig[25](vxShift((uint32_t)a), b, c, d, e, f, g, h) : 0;
    vxNote(25, r, a, b, c);
    return r;
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

static uint64_t vxW27(uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                      uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    unsigned int n = 0;
    const char **r = NULL;
    if (vxOrig[27]) r = ((const char **(*)(unsigned int *))(uintptr_t)vxOrig[27])(&n);
    if (!r) { if (a) *(unsigned int *)(uintptr_t)a = n; return 0; }

    const char **o = (const char **)malloc((size_t)(n + 1) * sizeof(char *));
    if (!o) { if (a) *(unsigned int *)(uintptr_t)a = n; return (uint64_t)r; }

    unsigned int k = 0;
    int fnd = 0;
    for (unsigned int i = 0; i < n; i++) {
        if (vxSelfPath && r[i] && !strcmp(r[i], vxSelfPath)) { fnd = 1; continue; }
        o[k++] = r[i];
    }
    o[k] = NULL;
    if (a) *(unsigned int *)(uintptr_t)a = k;
    free((void *)r);
    if (__atomic_add_fetch(&vxCount[27], 1, __ATOMIC_RELAXED) <= 3)
        vxLogRaw([NSString stringWithFormat:@"OC n=%u k=%u f=%d", n, k, fnd]);
    return (uint64_t)o;
}

static vxFn vxTab[VX_N] = {
    vxW0,  vxW1,  vxW2,  vxW3,  vxW4,  vxW5,  vxW6,  vxW7,
    vxW8,  vxW9,  vxW10, vxW11, vxW12, vxW13, vxW14, vxW15,
    vxW16, vxW17, vxW18, vxW19, vxW20, vxW21, vxW22, vxW23,
    vxW24, vxW25, vxW26, vxW27
};

// R + W + X + COPY: sin la X la página deja de ejecutarse
static kern_return_t vxProt(uint64_t addr, size_t len) {
    vm_size_t ps = vm_page_size;
    uintptr_t a = (uintptr_t)addr & ~((uintptr_t)ps - 1);
    uintptr_t e = ((uintptr_t)addr + len + ps - 1) & ~((uintptr_t)ps - 1);
    size_t l = (size_t)(e - a);
    kern_return_t k = vm_protect(mach_task_self(), (vm_address_t)a, (vm_size_t)l, false,
                                 VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
    if (k == KERN_SUCCESS) return k;
    if (mprotect((void *)a, l, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) return KERN_SUCCESS;
    return k;
}

static const struct mach_header_64 *vxFind(void) {
    for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) return (const void *)_dyld_get_image_header(i);
    }
    return NULL;
}

static void vxSelf(void) {
    if (!vxSelfPath) {
        for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
            const char *p = _dyld_get_image_name(i);
            if (!p || !strstr(p, "libobjc.A.dylib")) continue;
            if (!strncmp(p, "/usr/lib", 8) || !strncmp(p, "/private/preboot", 16)) continue;
            vxSelfPath = strdup(p);
            vxSelfIdx = i;
            break;
        }
    }
    if (!vxSelfPath) { vxLogRaw(@"sin self"); return; }
    const struct mach_header_64 *h = (const void *)_dyld_get_image_header(vxIdx());
    if (!h) { vxLogRaw(@"sin header"); return; }
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
    vxSelfLo = (uint64_t)h;
    vxSelfHi = (uint64_t)h + hi;
    vxLogRaw([NSString stringWithFormat:@"self %u %llx-%llx", vxIdx(), vxSelfLo, vxSelfHi]);
}

static void vxInfo(void) {
    const struct dyld_all_image_infos *ai = vxInfos();
    if (!ai) { vxLogRaw(@"sin infos api"); return; }
    vxLogRaw([NSString stringWithFormat:@"infos n=%u idx=%u", ai->infoArrayCount, vxIdx()]);
}

// --- parche ---

static uint32_t vxPatch(void) {
    vxLogRaw(@"patch ini");
    const struct mach_header_64 *h = vxFind();
    if (!h) { vxLogRaw(@"sin unity"); return 0; }
    vxLogRaw([NSString stringWithFormat:@"h=%llx", (uint64_t)h]);

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    const struct dysymtab_command *dys = NULL;
    uint64_t txtVm = 0, leVm = 0;
    int haveText = 0;

    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB)   st  = (const void *)lc;
        if (lc->cmd == LC_DYSYMTAB) dys = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { txtVm = sg->vmaddr; haveText = 1; }
            if (!strcmp(sg->segname, "__LINKEDIT")) { leVm = sg->vmaddr; }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st || !dys || !haveText) { vxLogRaw(@"tablas mal"); return 0; }
    vxLogRaw(@"tablas ok");

    uint64_t vbase = (uint64_t)h - txtVm;
    uint64_t lbase = vbase + leVm;
    const struct nlist_64 *nl = (const void *)(lbase + st->symoff);
    const char *str = (const void *)(lbase + st->stroff);
    const uint32_t *ind = (const void *)(lbase + dys->indirectsymoff);

    uint32_t hits = 0, stubs = 0;
    const struct load_command *c2 = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (c2->cmdsize < 8) break;
        if (c2->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)c2;
            const struct section_64 *sc = (const void *)(sg + 1);
            for (uint32_t j = 0; j < sg->nsects; j++) {
                uint32_t ty = sc->flags & SECTION_TYPE;
                if (ty == S_LAZY_SYMBOL_POINTERS || ty == S_SYMBOL_STUBS) {
                    uint32_t stride = (ty == S_SYMBOL_STUBS) ? sc->reserved2 : 8;
                    if (stride && sc->size) {
                        uint32_t wr = (stride < 16) ? stride : 16;
                        vxLogRaw([NSString stringWithFormat:@"sec %s ty=%x n=%llu st=%u wr=%u",
                                  sc->sectname, ty, (uint64_t)(sc->size / stride), stride, wr]);
                        for (uint32_t k = 0; k < sc->size / stride; k++) {
                            uint32_t si = ind[sc->reserved1 + k];
                            if (si & (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) continue;
                            const char *nm = str + nl[si].n_un.n_strx;
                            for (int t = 0; t < VX_N; t++) {
                                if (vxDone[t] || strcmp(nm, vxNames[t])) continue;
                                if (ty == S_SYMBOL_STUBS) {
                                    uint8_t *sp = (uint8_t *)(vbase + sc->addr + (uint64_t)k * stride);
                                    kern_return_t kp = vxProt((uint64_t)sp, wr);
                                    vxLogRaw([NSString stringWithFormat:@"hit S %s p=%d", nm, kp]);
                                    if (kp != KERN_SUCCESS) break;
                                    uint64_t fn = (uint64_t)vxTab[t];
                                    uint32_t lo = (uint32_t)(fn & 0xffff);
                                    uint32_t hi = (uint32_t)((fn >> 16) & 0xffff);
                                    uint32_t ins[4];
                                    ins[0] = 0xd2800010u | (lo << 5);
                                    ins[1] = 0xf2a00010u | (hi << 5);
                                    ins[2] = 0xd61f0200u;
                                    ins[3] = 0xd503201fu;
                                    memcpy(sp, ins, wr);
                                    sys_icache_invalidate(sp, wr);
                                    vxLogRaw([NSString stringWithFormat:@"S ok %llx", (uint64_t)sp]);
                                    stubs++;
                                } else {
                                    uint64_t *slot = (uint64_t *)(vbase + sc->addr + (uint64_t)k * stride);
                                    kern_return_t kp = vxProt((uint64_t)slot, 8);
                                    vxLogRaw([NSString stringWithFormat:@"hit P %s p=%d", nm, kp]);
                                    if (kp != KERN_SUCCESS) break;
                                    vxOrig[t] = (vxFn)*slot;
                                    *slot = (uint64_t)vxTab[t];
                                    vxLogRaw([NSString stringWithFormat:@"P ok %llx", (uint64_t)slot]);
                                    hits++;
                                }
                                vxDone[t] = 1;
                                break;
                            }
                        }
                    }
                }
                sc = (const void *)((const char *)sc + sizeof(*sc));
            }
        }
        c2 = (const void *)((const char *)c2 + c2->cmdsize);
    }

    vxPatched += hits + stubs;
    vxLogRaw([NSString stringWithFormat:@"pasada slot=%u stub=%u total=%u", hits, stubs, vxPatched]);
    return hits + stubs;
}

static void vxImgs(void) {
    const struct dyld_all_image_infos *ai = vxInfos();
    if (ai) vxLogRaw([NSString stringWithFormat:@"infos ahora n=%u idx=%u", ai->infoArrayCount, vxIdx()]);
    uint32_t n = _dyld_image_count();
    vxLogRaw([NSString stringWithFormat:@"visibles n=%u", n]);
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!p) continue;
        if (!strncmp(p, "/System/Library", 15)) continue;
        if (!strncmp(p, "/usr/lib", 8)) continue;
        vxLogRaw([NSString stringWithFormat:@"vis %u %s", i, p]);
    }
    unsigned int oc = 0;
    if (vxOrig[27]) {
        const char **r = ((const char **(*)(unsigned int *))(uintptr_t)vxOrig[27])(&oc);
        if (r) {
            int f = 0;
            for (unsigned int i = 0; i < oc; i++) if (vxSelfPath && r[i] && !strcmp(r[i], vxSelfPath)) f = 1;
            vxLogRaw([NSString stringWithFormat:@"oc ahora n=%u f=%d", oc, f]);
            free((void *)r);
        }
    }
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
    vxLogRaw([NSString stringWithFormat:@"step %d", vxTries]);
    uint32_t p = vxPatch();
    vxLogRaw([NSString stringWithFormat:@"ret %u", p]);
    if (p > 0) {
        vxSelf();
        vxInfo();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6ull * NSEC_PER_SEC),
                       dispatch_get_global_queue(0, 0), ^{ vxImgs(); });
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
    vxLogRaw(@"==== 190 prot exec ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}
