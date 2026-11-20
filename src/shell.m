// VEEX shell build 161 — localizar binarios del bundle
// No engancha.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 161

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

static uint64_t vxSize(const struct mach_header_64 *h) {
    uint64_t t = 0;
    const struct load_command *lc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) t += sg->filesize;
            if (!strcmp(sg->segname, "__TEXT_EXEC")) t += sg->filesize;
            if (!strcmp(sg->segname, "__DATA")) t += sg->filesize;
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    return t;
}

static void vxRun(void) {
    const struct mach_header_64 *me = NULL;
    { Dl_info i; if (dladdr((void *)&vxRun, &i)) me = i.dli_fbase; }

    uint32_t n = _dyld_image_count();
    vxLog([NSString stringWithFormat:@"==== bundle ==== imgs=%u", n]);

    int hits = 0;
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!p || !strstr(p, "FreeFire.app")) continue;
        const struct mach_header_64 *h = (const void *)_dyld_get_image_header(i);
        if (!h || h == me) continue;
        vxLog([NSString stringWithFormat:@"%u sz=%llu magic=%x %s",
               i, vxSize(h), h->magic, p]);
        hits++;
        if (hits >= 12) break;
    }
    vxLog([NSString stringWithFormat:@"hits=%d", hits]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
