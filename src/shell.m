// VEEX shell build 159 — mapa de segmentos del binario principal
// No engancha nada.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 159

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

static void vxRun(void) {
    const struct mach_header_64 *mh = (const void *)_dyld_get_image_header(0);
    vxLog(@"==== mapa ====");
    if (!mh) { vxLog(@"sin cabecera"); return; }
    vxLog([NSString stringWithFormat:@"magic=%x cpu=%x sub=%x ncmds=%u flags=%x",
           mh->magic, mh->cputype, mh->cpusubtype, mh->ncmds, mh->flags]);

    const struct load_command *lc = (const void *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (lc->cmdsize < 8) { vxLog(@"cmd roto"); break; }
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            vxLog([NSString stringWithFormat:@"seg %s vm=%llx vs=%llu fo=%llu fs=%llu ns=%u",
                   sg->segname, sg->vmaddr, sg->vmsize, sg->fileoff, sg->filesize, sg->nsects]);
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
