// VEEX shell build 181 — inventario de importados por subcadena

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/mach.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <pthread.h>
#include <dlfcn.h>
#include <time.h>

#define VX_BUILD  181
#define VX_N      22
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
static int vxTries = 0;

static const char *vxNames[VX_N] = {
    "_csops", "_csops_audittoken", "_ptrace", "_sysctl", "_sysctlbyname",
    "_stat", "_stat$INODE64", "_lstat", "_access", "_open", "_dlopen", "_dlsym",
    "_task_info", "_mach_vm_region", "_vm_region", "_vm_region_64",
    "_proc_pidinfo", "_kdebug_trace", "_getppid", "_getpid",
    "_objc_setHook_getClass", "_mach_port_deallocate"
};

static const char *vxSubs[] = {
    "region", "dyld", "mach_vm", "proc_", "objc_copy", "task_",
    "csops", "kdebug", "image", "vm_", "thread_get", "host_", NULL
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

static const struct mach_header_64 *vxFind(void) {
    for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) return (const void *)_dyld_get_image_header(i);
    }
    return NULL;
}

static int vxTabs(const struct mach_header_64 *h, const struct symtab_command **sto,
                  const char **stro, uint64_t *leVm, uint64_t *txtVm) {
    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    uint64_t tv = 0, lv = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB) st = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) tv = sg->vmaddr;
            if (!strcmp(sg->segname, "__LINKEDIT")) lv = sg->vmaddr;
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st || !tv || !lv) return 0;
    const uint8_t *le = (const uint8_t *)h + (lv - tv);
    *sto = st;
    *stro = (const char *)(le + st->stroff);
    *leVm = lv;
    *txtVm = tv;
    return 1;
}

static void vxDump(void) {
    const struct mach_header_64 *h = vxFind();
    if (!h) { vxLogRaw(@"sin unity"); return; }
    const struct symtab_command *st = NULL;
    const char *str = NULL;
    uint64_t leVm = 0, txtVm = 0;
    if (!vxTabs(h, &st, &str, &leVm, &txtVm)) { vxLogRaw(@"tablas mal"); return; }
    const uint8_t *le = (const uint8_t *)h + (leVm - txtVm);
    const struct nlist_64 *nl = (const struct nlist_64 *)(le + st->symoff);

    uint32_t und = 0, shown = 0;
    for (uint32_t i = 0; i < st->nsyms; i++) {
        if ((nl[i].n_type & N_TYPE) != N_UNDF) continue;
        und++;
        if (!nl[i].n_un.n_strx) continue;
        const char *nm = str + nl[i].n_un.n_strx;
        int hit = 0;
        for (int k = 0; vxSubs[k]; k++) {
            if (strstr(nm, vxSubs[k])) { hit = 1; break; }
        }
        if (!hit) continue;
        if (shown >= 400) continue;
        vxLogRaw([NSString stringWithFormat:@"U %s", nm]);
        shown++;
    }
    vxLogRaw([NSString stringWithFormat:@"und=%u mostrados=%u nsyms=%u", und, shown, st->nsyms]);
}

static void vxRetry(void);

static void vxStep(void) {
    if (vxFind()) { vxDump(); return; }
    if (++vxTries >= VX_TRIES) { vxLogRaw(@"sin unity"); return; }
    vxRetry();
}

static void vxRetry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200ull * NSEC_PER_MSEC),
                   dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}

__attribute__((constructor))
static void vxInit(void) {
    vxLogRaw(@"==== 181 inventario ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}
