// VEEX shell build 168 — símbolos de UnityFramework por vmaddr

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#define VX_BUILD 168
#define VX_CAP 500

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

static int vxKey(const char *s) {
    static const char *k[] = { "fair", "guard", "fg_", "csops", "ptrace", "tamper",
                               "jbdetect", "jailbreak", "sysctl", "cheat", "detect",
                               "anticheat", "anti_cheat", "hook", "mod", NULL };
    char b[220];
    size_t n = strlen(s);
    size_t m = n < sizeof(b) - 1 ? n : sizeof(b) - 1;
    for (size_t i = 0; i < m; i++) b[i] = (char)tolower((unsigned char)s[i]);
    b[m] = 0;
    for (int i = 0; k[i]; i++) if (strstr(b, k[i])) return 1;
    return 0;
}

static void vxRun(void) {
    vxLog(@"==== simbolos 168 ====");
    const struct mach_header_64 *h = NULL;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) { h = (const void *)_dyld_get_image_header(i); break; }
    }
    if (!h) { vxLog(@"sin unity"); return; }

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    uint64_t txtVm = 0, leVm = 0, leOff = 0, leSize = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB) st = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) txtVm = sg->vmaddr;
            if (!strcmp(sg->segname, "__LINKEDIT")) { leVm = sg->vmaddr; leOff = sg->fileoff; leSize = sg->filesize; }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st || !leVm) { vxLog(@"sin tablas"); return; }
    if (st->stroff < leOff || st->stroff >= leOff + leSize) { vxLog(@"stroff fuera"); return; }

    const uint8_t *le = (const uint8_t *)h + (leVm - txtVm);
    const char *str = (const char *)(le + (st->stroff - leOff));
    vxLog([NSString stringWithFormat:@"strsize=%u nsyms=%u", st->strsize, st->nsyms]);

    uint32_t hits = 0;
    for (uint32_t off = 0; off < st->strsize && hits < VX_CAP; off++) {
        const char *s = str + off;
        if (!*s) continue;
        size_t len = strlen(s);
        if (len >= 3 && len <= 200 && vxKey(s)) {
            vxLog([NSString stringWithFormat:@"S %s", s]);
            hits++;
        }
        off += len;
    }
    vxLog([NSString stringWithFormat:@"hits=%u", hits]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
