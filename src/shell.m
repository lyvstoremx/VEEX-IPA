// VEEX shell build 157 — RECONOCIMIENTO FairGuard
// Sólo lista imágenes sospechosas con ruta y tamaño. No engancha.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 157

static NSString *vxDoc(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

static void vxLog(NSString *s) {
    NSString *p = [vxDoc() stringByAppendingPathComponent:@"a.dat"];
    FILE *f = fopen(p.UTF8String, "a");
    if (!f) return;
    fputs([NSString stringWithFormat:@"[%d] %@\n", VX_BUILD, s].UTF8String, f);
    fclose(f);
}

static int vxHit(const char *p) {
    if (!p) return 0;
    static const char *k[] = { "fair", "guard", "sec", "anti", "tencent", "garena",
                               "tp", "beacon", "safe", "protect", "shield", "mono", "il2cpp", NULL };
    for (int i = 0; k[i]; i++)
        if (strcasestr(p, k[i])) return 1;
    return 0;
}

static size_t vxTextSize(const struct mach_header_64 *h) {
    const struct load_command *lc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) return (size_t)sg->vmsize;
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    return 0;
}

static void vxRun(void) {
    uint32_t n = _dyld_image_count();
    vxLog([NSString stringWithFormat:@"==== recon ==== imgs=%u", n]);

    int hits = 0;
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!vxHit(p)) continue;
        const struct mach_header_64 *h = (const void *)_dyld_get_image_header(i);
        vxLog([NSString stringWithFormat:@"%u sz=%zu %s", i, h ? vxTextSize(h) : 0, p ? p : "?"]);
        hits++;
    }
    vxLog([NSString stringWithFormat:@"hits=%d", hits]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
