// VEEX shell build 163 — barrido afinado de FairGuard
// Sólo lee y apunta. No engancha.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#define VX_BUILD 163
#define VX_CAP 1200

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

static const char *vxKey(const char *s, size_t n) {
    static const char *k[] = { "fairguard", "fair_guard", "fair guard", "jailbreak",
                               "jbdetect", "csops", "ptrace", "tamper", "cdhash",
                               "antidebug", "anti_debug", "garena", "detectmod", NULL };
    char b[170];
    size_t m = n < sizeof(b) - 1 ? n : sizeof(b) - 1;
    for (size_t i = 0; i < m; i++) b[i] = (char)tolower((unsigned char)s[i]);
    b[m] = 0;
    for (int i = 0; k[i]; i++) if (strstr(b, k[i])) return k[i];
    return NULL;
}

static const struct mach_header_64 *vxUnity(void) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) return (const void *)_dyld_get_image_header(i);
    }
    return NULL;
}

static int gHits = 0;

static void vxScan(const struct mach_header_64 *h, const struct segment_command_64 *sg) {
    if (!sg->filesize || gHits >= VX_CAP) return;
    const uint8_t *p = (const uint8_t *)h + sg->fileoff;
    size_t n = (size_t)sg->filesize;
    vxLog([NSString stringWithFormat:@"scan %s len=%zu", sg->segname, n]);

    size_t i = 0;
    while (i < n && gHits < VX_CAP) {
        if (p[i] < 0x20 || p[i] > 0x7e) { i++; continue; }
        size_t st = i;
        while (i < n && p[i] >= 0x20 && p[i] <= 0x7e) i++;
        size_t len = i - st;
        if (len < 6 || len > 160) continue;
        const char *kw = vxKey((const char *)p + st, len);
        if (!kw) continue;
        char b[170];
        size_t m = len < sizeof(b) - 1 ? len : sizeof(b) - 1;
        memcpy(b, p + st, m);
        b[m] = 0;
        vxLog([NSString stringWithFormat:@"[%s] @%llx %s", kw, sg->vmaddr + (uint64_t)st, b]);
        gHits++;
    }
}

static void vxRun(void) {
    vxLog(@"==== barrido afinado ====");
    const struct mach_header_64 *h = vxUnity();
    if (!h) { vxLog(@"sin unity"); return; }

    const struct load_command *lc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT") ||
                !strcmp(sg->segname, "__TEXT_EXEC") ||
                !strcmp(sg->segname, "__DATA") ||
                !strcmp(sg->segname, "__DATA_CONST"))
                vxScan(h, sg);
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    vxLog([NSString stringWithFormat:@"hits=%d", gHits]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
