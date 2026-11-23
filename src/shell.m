// VEEX shell build 182 — inventario de importados por subcadena

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

#define VX_BUILD  182
#define VX_TRIES  40

static pthread_mutex_t vxM = PTHREAD_MUTEX_INITIALIZER;
static FILE *vxF = NULL;
static int vxTries = 0;

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

static void vxDump(void) {
    const struct mach_header_64 *h = vxFind();
    if (!h) { vxLogRaw(@"sin unity"); return; }

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    uint64_t tv = 0, lv = 0, lo = 0, ls = 0;
    int haveText = 0;

    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB) st = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { tv = sg->vmaddr; haveText = 1; }
            if (!strcmp(sg->segname, "__LINKEDIT")) { lv = sg->vmaddr; lo = sg->fileoff; ls = sg->filesize; }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st || !haveText || !lv) { vxLogRaw(@"tablas mal"); return; }
    if (st->symoff < lo || st->symoff >= lo + ls) { vxLogRaw(@"symoff fuera"); return; }
    if (st->stroff < lo || st->stroff >= lo + ls) { vxLogRaw(@"stroff fuera"); return; }

    const uint8_t *le = (const uint8_t *)h + (lv - tv);
    const struct nlist_64 *nl = (const struct nlist_64 *)(le + (st->symoff - lo));
    const char *str = (const char *)(le + (st->stroff - lo));

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
        if (!hit || shown >= 400) continue;
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
    vxLogRaw(@"==== 182 inventario ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}
