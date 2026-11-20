// VEEX shell build 166 — volcado crudo de LC_SYMTAB

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 166

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

static NSString *vxHex(const uint8_t *p, size_t n) {
    NSMutableString *s = [NSMutableString stringWithCapacity:n * 3];
    for (size_t i = 0; i < n; i++) [s appendFormat:@"%02x", p[i]];
    return s;
}

static void vxRun(void) {
    vxLog(@"==== crudo symtab ====");
    const struct mach_header_64 *h = NULL;
    int idx = -1;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) { h = (const void *)_dyld_get_image_header(i); idx = (int)i; break; }
    }
    if (!h) { vxLog(@"sin unity"); return; }
    vxLog([NSString stringWithFormat:@"idx=%d h=%lx slide=%lx", idx, (unsigned long)(uintptr_t)h,
           (unsigned long)_dyld_get_image_vmaddr_slide(idx)]);

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    uint64_t leOff = 0, leSize = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) { vxLog(@"cmd roto"); break; }
        if (lc->cmd == LC_SYMTAB) st = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__LINKEDIT")) { leOff = sg->fileoff; leSize = sg->filesize; }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    vxLog([NSString stringWithFormat:@"linkedit off=%llu size=%llu", leOff, leSize]);
    if (!st) { vxLog(@"sin LC_SYMTAB"); return; }

    vxLog([NSString stringWithFormat:@"symoff=%u nsyms=%u stroff=%u strsize=%u",
           st->symoff, st->nsyms, st->stroff, st->strsize]);
    vxLog([NSString stringWithFormat:@"dentro_LE sym=%d str=%d",
           (st->symoff >= leOff && st->symoff < leOff + leSize) ? 1 : 0,
           (st->stroff >= leOff && st->stroff < leOff + leSize) ? 1 : 0]);

    vxLog([NSString stringWithFormat:@"hex_sym %@", vxHex((const uint8_t *)h + st->symoff, 48)]);
    vxLog([NSString stringWithFormat:@"hex_str %@", vxHex((const uint8_t *)h + st->stroff, 48)]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
