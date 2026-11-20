// VEEX shell build 154 — MODO CERO + DESENGANCHE DE IMAGEN
// Sin ventana, sin ganchos, sin migración, sin script.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/task_info.h>
#import <sys/sysctl.h>
#import <sys/proc.h>
#import <sys/utsname.h>
#import <unistd.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

#define VX_BUILD 154

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

static struct dyld_all_image_infos *vxInfos(void) {
    struct task_dyld_info tdi;
    mach_msg_type_number_t cnt = TASK_DYLD_INFO_COUNT;
    memset(&tdi, 0, sizeof(tdi));
    if (task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&tdi, &cnt) != KERN_SUCCESS)
        return NULL;
    return (struct dyld_all_image_infos *)tdi.all_image_info_addr;
}

static void vxUnlink(void) {
    const struct mach_header_64 *h = vxHdr();
    struct dyld_all_image_infos *inf = vxInfos();
    if (!h || !inf) { vxLog(@"unl sin datos h=%d inf=%d", h ? 1 : 0, inf ? 1 : 0); return; }

    struct dyld_image_info *arr = (struct dyld_image_info *)inf->infoArray;
    uint32_t n = inf->infoArrayCount;
    if (!arr || n < 2) { vxLog(@"unl arr raro n=%u", n); return; }

    int idx = -1;
    for (uint32_t i = 0; i < n; i++)
        if (arr[i].imageLoadAddress == (const struct mach_header *)h) { idx = (int)i; break; }
    if (idx < 0) { vxLog(@"unl no estoy"); return; }

    for (uint32_t i = (uint32_t)idx; i + 1 < n; i++) arr[i] = arr[i + 1];
    inf->infoArrayCount = n - 1;
    inf->infoArrayChangeTimestamp = 1;

    vxLog(@"unl idx=%d n=%u -> %u", idx, n, inf->infoArrayCount);
}

static void vxImgs(void) {
    uint32_t n = _dyld_image_count();
    uint32_t lim = n < 6 ? n : 6;
    for (uint32_t i = 0; i < lim; i++) {
        const char *p = _dyld_get_image_name(i);
        vxLog(@"i%u %s", i, p ? p : "?");
    }
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

    vxLog(@"==== arranque desenganche ====");
    vxLog(@"ios=%@ hw=%s", UIDevice.currentDevice.systemVersion, u.machine);
    vxLog(@"path=%s", di.dli_fname ? di.dli_fname : "?");
    vxFlags();
    vxImgs();

    vxLog(@"antes=%u self=%d", _dyld_image_count(), vxSelfIndex());
    vxUnlink();
    vxLog(@"despues=%u self=%d", _dyld_image_count(), vxSelfIndex());
    vxImgs();

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
