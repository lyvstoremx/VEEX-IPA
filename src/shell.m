// VEEX shell build 151 — MODO CERO
// Presencia + medición de hashes. Nada más.
// Sin ventana, sin ganchos, sin migración, sin script.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach/vm_region.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <CommonCrypto/CommonDigest.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

#define VX_BUILD 151

// Horneados: marcador hasta tener los medidos
static const char *VX_H  = "0000000000000000000000000000000000000000000000000000000000000000";
static const char *VX_CD = "0000000000000000000000000000000000000000";

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define VX_CS_OPS_STATUS 0
#define VX_CS_DEBUGGED   0x10000000

static char gLog[2][512];
static int  gLogN = 0;

static void vxLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    if (!s) return;
    NSString *line = [NSString stringWithFormat:@"[%d] %@\n", VX_BUILD, s];
    for (int i = 0; i < gLogN; i++) {
        FILE *f = fopen(gLog[i], "a");
        if (!f) continue;
        fputs(line.UTF8String, f);
        fclose(f);
    }
}

static void vxPaths(void) {
    NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *cac = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (doc && gLogN < 2) { snprintf(gLog[gLogN], 512, "%s/a.dat", doc.UTF8String); gLogN++; }
    if (cac && gLogN < 2) { snprintf(gLog[gLogN], 512, "%s/b.dat", cac.UTF8String); gLogN++; }
}

static const struct mach_header_64 *vxHdr(void) {
    Dl_info i;
    if (dladdr((void *)&vxHdr, &i) && i.dli_fbase)
        return (const struct mach_header_64 *)i.dli_fbase;
    return NULL;
}

static int vxSelfIndex(void) {
    const struct mach_header_64 *h = vxHdr();
    if (!h) return -1;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++)
        if (_dyld_get_image_header(i) == (const struct mach_header *)h) return (int)i;
    return -1;
}

static int vxTextRange(const struct mach_header_64 *h, uintptr_t *addr, size_t *len) {
    if (!h) return 0;
    const struct load_command *lc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) {
                *addr = (uintptr_t)h + (uintptr_t)sg->vmaddr;
                *len  = (size_t)(sg->filesize < sg->vmsize ? sg->filesize : sg->vmsize);
                return *len > 0;
            }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    return 0;
}

static NSString *vxSHA256(uintptr_t a, size_t n) {
    unsigned char d[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256((const void *)a, (CC_LONG)n, d);
    NSMutableString *s = [NSMutableString stringWithCapacity:64];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [s appendFormat:@"%02x", d[i]];
    return s;
}

struct vxBlobIndex { uint32_t type; uint32_t offset; };
struct vxSuperBlob { uint32_t magic; uint32_t length; uint32_t count; };

static NSString *vxCDHash(const struct mach_header_64 *h) {
    if (!h) return nil;
    const struct load_command *lc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_CODE_SIGNATURE) {
            const struct linkedit_data_command *cs = (const void *)lc;
            if (!cs->datasize) return nil;
            const uint8_t *base = (const uint8_t *)h + cs->dataoff;
            const struct vxSuperBlob *sb = (const void *)base;
            if (sb->magic != 0xfade0cc0 || sb->count > 8) return nil;
            for (uint32_t k = 0; k < sb->count; k++) {
                const struct vxBlobIndex *bi = (const void *)((const uint8_t *)(sb + 1) + k * sizeof(struct vxBlobIndex));
                if (bi->type != 0) continue;
                const uint8_t *cd = base + bi->offset;
                uint32_t clen = *(const uint32_t *)(cd + 4);
                if (clen < 0x2c || clen > cs->datasize) return nil;
                unsigned char d[CC_SHA1_DIGEST_LENGTH];
                CC_SHA1(cd, (CC_LONG)clen, d);
                NSMutableString *s = [NSMutableString stringWithCapacity:40];
                for (int j = 0; j < CC_SHA1_DIGEST_LENGTH; j++) [s appendFormat:@"%02x", d[j]];
                return s;
            }
            return nil;
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    return nil;
}

static void vxFlags(void) {
    uint32_t st = 0;
    if (csops(getpid(), VX_CS_OPS_STATUS, &st, sizeof(st)) == 0)
        vxLog(@"cs=0x%x dbg=%d", st, (st & VX_CS_DEBUGGED) ? 1 : 0);
    else
        vxLog(@"cs=err");

    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc kp; size_t sz = sizeof(kp);
    memset(&kp, 0, sizeof(kp));
    if (sysctl(mib, 4, &kp, &sz, NULL, 0) == 0)
        vxLog(@"trace=%d", (kp.kp_proc.p_flag & P_TRACED) ? 1 : 0);
    else
        vxLog(@"trace=err");
}

static void vxRun(void) {
    vxPaths();
    struct utsname u; memset(&u, 0, sizeof(u)); uname(&u);
    Dl_info di; memset(&di, 0, sizeof(di)); dladdr((void *)&vxHdr, &di);

    vxLog(@"==== arranque modo cero ====");
    vxLog(@"ios=%@ hw=%s", UIDevice.currentDevice.systemVersion, u.machine);
    vxLog(@"imgs=%u self=%d", _dyld_image_count(), vxSelfIndex());
    vxLog(@"path=%s", di.dli_fname ? di.dli_fname : "?");
    vxFlags();

    const struct mach_header_64 *h = vxHdr();
    uintptr_t ta = 0; size_t tl = 0;
    if (h && vxTextRange(h, &ta, &tl)) {
        vxLog(@"txt=0x%lx len=%zu", (unsigned long)ta, tl);
        NSString *mh = vxSHA256(ta, tl);
        NSString *mc = vxCDHash(h);
        vxLog(@"HS h %@ %@", mh ?: @"-", [mh isEqualToString:@(VX_H)] ? @"SI" : @"NO");
        vxLog(@"HS cd %@ %@", mc ?: @"-", [mc isEqualToString:@(VX_CD)] ? @"SI" : @"NO");
    } else {
        vxLog(@"txt=err");
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5ull * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        vxLog(@"vivo 5s");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15ull * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        vxLog(@"vivo 15s fin");
    });
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
