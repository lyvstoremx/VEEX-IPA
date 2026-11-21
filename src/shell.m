// VEEX shell build 167 — lectura por dirección virtual del segmento

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 167

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
    vxLog(@"==== lectura por vmaddr ====");
    const struct mach_header_64 *h = NULL;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) { h = (const void *)_dyld_get_image_header(i); break; }
    }
    if (!h) { vxLog(@"sin unity"); return; }

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    uint64_t txtVm = 0;
    uint64_t leVm = 0, leOff = 0, leSize = 0;
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
    vxLog([NSString stringWithFormat:@"txtVm=%llu leVm=%llu leOff=%llu leSize=%llu", txtVm, leVm, leOff, leSize]);
    if (!st) { vxLog(@"sin LC_SYMTAB"); return; }
    if (!leVm || !leSize) { vxLog(@"sin linkedit"); return; }

    uint64_t delta = leVm - txtVm;
    const uint8_t *le = (const uint8_t *)h + delta;
    vxLog([NSString stringWithFormat:@"le=%lx", (unsigned long)(uintptr_t)le]);
    vxLog([NSString stringWithFormat:@"hex_le %@", vxHex(le, 32)]);

    if (st->stroff < leOff || st->stroff >= leOff + leSize) { vxLog(@"stroff fuera"); return; }
    if (st->symoff < leOff || st->symoff >= leOff + leSize) { vxLog(@"symoff fuera"); return; }

    const uint8_t *sp = le + (st->stroff - leOff);
    vxLog([NSString stringWithFormat:@"str@%lx hex %@", (unsigned long)(uintptr_t)sp, vxHex(sp, 48)]);
    vxLog([NSString stringWithFormat:@"primero=%.60s", (const char *)sp + 1]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
