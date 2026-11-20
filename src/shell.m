// VEEX shell build 160 — busca cadenas de FairGuard en el binario del juego
// Sólo lee y apunta offsets. No engancha.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#define VX_BUILD 160
#define VX_CAP 300
#define VX_MAXLEN 200u * 1024u * 1024u

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

static int vxKey(const char *s, size_t n) {
    static const char *k[] = { "fairguard", "fair_guard", "fair guard", "fg_", "_fg",
                               "jailbreak", "jbdetect", "cheat", "hack", "moddetect",
                               "antidebug", "anti_debug", "ptrace", "sysctl", "csops",
                               "detected", "tamper", "integrity", "signature", "cdhash",
                               NULL };
    char b[160];
    size_t m = n < sizeof(b) - 1 ? n : sizeof(b) - 1;
    for (size_t i = 0; i < m; i++) b[i] = (char)tolower((unsigned char)s[i]);
    b[m] = 0;
    for (int i = 0; k[i]; i++) if (strstr(b, k[i])) return 1;
    return 0;
}

static void vxRun(void) {
    const struct mach_header_64 *mh = (const void *)_dyld_get_image_header(0);
    vxLog(@"==== cadenas ====");
    if (!mh) { vxLog(@"sin cabecera"); return; }

    const struct load_command *lc = (const void *)(mh + 1);
    const struct segment_command_64 *txt = NULL;
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { txt = sg; break; }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!txt) { vxLog(@"sin __TEXT"); return; }

    const uint8_t *p = (const uint8_t *)mh + txt->fileoff;
    size_t n = (size_t)txt->filesize;
    if (n > VX_MAXLEN) n = VX_MAXLEN;
    vxLog([NSString stringWithFormat:@"base=%llx len=%zu", txt->vmaddr, n]);

    int hits = 0;
    size_t i = 0;
    while (i < n && hits < VX_CAP) {
        if (p[i] < 0x20 || p[i] > 0x7e) { i++; continue; }
        size_t st = i;
        while (i < n && p[i] >= 0x20 && p[i] <= 0x7e) i++;
        size_t len = i - st;
        if (len < 6 || len > 150) continue;
        if (!vxKey((const char *)p + st, len)) continue;
        char b[160];
        size_t m = len < sizeof(b) - 1 ? len : sizeof(b) - 1;
        memcpy(b, p + st, m);
        b[m] = 0;
        vxLog([NSString stringWithFormat:@"@%llx %s", txt->vmaddr + (uint64_t)st, b]);
        hits++;
    }
    vxLog([NSString stringWithFormat:@"hits=%d", hits]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
