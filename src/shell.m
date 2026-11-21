// VEEX shell build 170 — imports exactos (símbolos indefinidos)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 170

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

static const char *vxNames[] = {
    "_csops", "_csops_audittoken", "_ptrace", "_sysctl", "_sysctlbyname",
    "_stat", "_stat$INODE64", "_lstat", "_access", "_open", "_dlopen", "_dlsym",
    "_task_info", "_mach_vm_region", "_vm_region", "_vm_region_64",
    "_proc_pidinfo", "_kdebug_trace", "_getppid", "_getpid",
    "_objc_setHook_getClass", "_mach_port_deallocate", NULL
};

static void vxRun(void) {
    vxLog(@"==== imports exactos ====");
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
    if (st->symoff < leOff || st->symoff >= leOff + leSize) { vxLog(@"symoff fuera"); return; }
    if (st->stroff < leOff || st->stroff >= leOff + leSize) { vxLog(@"stroff fuera"); return; }

    const uint8_t *le = (const uint8_t *)h + (leVm - txtVm);
    const struct nlist_64 *nl = (const struct nlist_64 *)(le + (st->symoff - leOff));
    const char *str = (const char *)(le + (st->stroff - leOff));

    uint32_t und = 0, hit = 0;
    for (uint32_t i = 0; i < st->nsyms; i++) {
        if ((nl[i].n_type & N_TYPE) != N_UNDF) continue;
        und++;
        if (!nl[i].n_un.n_strx) continue;
        const char *nm = str + nl[i].n_un.n_strx;
        for (int k = 0; vxNames[k]; k++) {
            if (strcmp(nm, vxNames[k])) continue;
            vxLog([NSString stringWithFormat:@"I %s", nm]);
            hit++;
            break;
        }
    }
    vxLog([NSString stringWithFormat:@"und=%u hit=%u nsyms=%u", und, hit, st->nsyms]);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
