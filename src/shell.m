// VEEX shell build 164 — tabla de símbolos de UnityFramework
// Sólo lee. No engancha.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#define VX_BUILD 164
#define VX_CAP 400

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
                               "jbdetect", "jailbreak", "sysctl", "detect", "cheat", NULL };
    char b[200];
    size_t n = strlen(s);
    size_t m = n < sizeof(b) - 1 ? n : sizeof(b) - 1;
    for (size_t i = 0; i < m; i++) b[i] = (char)tolower((unsigned char)s[i]);
    b[m] = 0;
    for (int i = 0; k[i]; i++) if (strstr(b, k[i])) return 1;
    return 0;
}

static const struct mach_header_64 *vxUnity(void) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) return (const void *)_dyld_get_image_header(i);
    }
    return NULL;
}

static void vxRun(void) {
    vxLog(@"==== simbolos ====");
    const struct mach_header_64 *h = vxUnity();
    if (!h) { vxLog(@"sin unity"); return; }

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB) { st = (const void *)lc; break; }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    if (!st) { vxLog(@"sin LC_SYMTAB"); return; }
    vxLog([NSString stringWithFormat:@"nsyms=%u strsize=%u", st->nsyms, st->strsize]);

    const char *str = (const char *)h + st->stroff;
    uint32_t hits = 0;
    for (uint32_t off = 0; off < st->strsize && hits < VX_CAP; off++) {
        const char *s = str + off;
        if (!*s) continue;
        size_t n = strlen(s);
        if (n < 3 || n > 190) { off += n; continue; }
        if (vxKey(s)) {
            vxLog([NSString stringWithFormat:@"S %s", s]);
            hits++;
        }
        off += n;
    }
    vxLog([NSString stringWithFormat:@"hits=%u", hits]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
