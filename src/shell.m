// src/shell.m — VEEX build 63
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>
#import <stdio.h>
#import <stdarg.h>
#import <stdlib.h>
#import <string.h>
#import <time.h>
#import <sys/mman.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#define VX_BUILD 63
#define VX_STAGE 6
#define VX_HOOKSET 1
#define VX_AUTOHOOK 1
#define VX_FPS 20

#define SCRIPT_URL @"https://raw.githubusercontent.com/lyvstoremx/VEEX-IPA/main/scripts/esp.lua"

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define VX_CS_OPS_STATUS      0
#define VX_CS_VALID           0x00000001
#define VX_CS_GET_TASK_ALLOW  0x00000004
#define VX_CS_HARD            0x00000100
#define VX_CS_DEBUGGED        0x10000000

#define VX_PFLAG_OFF          32
#define VX_P_TRACED           0x00000800
#define VX_PG                 0x4000

// identidad oficial
static const char *VX_H     = "00770007d45fe15664db57df30274f5c49daaa04f276be030f20686e673c833b";
static const char *VX_CD    = "d9cf9ae60f2433bf47fe33a29d7122bb1bcc5965";
static const char *VX_MD5ID = "75ead73659249cdb3a0eee33e86c003a";
static const char *VX_TEAM  = "98573T3W6L";
static const char *VX_APPID = "98573T3W6L.com.dts.freefireth";
static const char *VX_FAKE  = "/usr/lib/libobjc.A.dylib";

static NSMutableString *gLog = nil;
static NSString *gDocs = nil;
static UIWindow *gWin = nil;
static UIView *gRoot = nil;
static UIView *gDraw = nil;
static UIView *gPanel = nil;
static UIView *gContent = nil;
static UITextView *gLogView = nil;
static NSMutableDictionary *gCfg = nil;
static NSArray *gTabBtns = nil;
static int gTab = 0;
static int gOpen = 0;
static lua_State *gL = NULL;
static volatile int gRun = 0;
static uint64_t gBase = 0, gSize = 0;
static uint64_t gMainHdr = 0;
static uint32_t gMyIdx = 0xFFFFFFFFu;

// ===== rango __TEXT y contadores =====
static uint64_t gTextLo = 0, gTextHi = 0, gTextSz = 0;
static volatile int gHitMd5 = 0, gHitSha1 = 0, gHitSha256 = 0, gForced = 0;
static volatile unsigned gLastLen256 = 0;
static volatile int gLastIn256 = 0;
static volatile int gBodies = 0;
static int gInstalled = 0;

static int vxInText(const void *p) {
    uint64_t a = (uint64_t)p;
    return (gTextLo && a >= gTextLo && a < gTextHi) ? 1 : 0;
}

// ============ LOG ============
static void vxWriteSync(NSString *s) {
    if (!gDocs) return;
    NSString *p = [gDocs stringByAppendingPathComponent:@"veex.log"];
    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!f) { [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    [f seekToEndOfFile];
    [f writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
    [f closeFile];
}

static void vxLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    if (!gLog) gLog = [NSMutableString new];
    [gLog appendString:s];
    [gLog appendString:@"\n"];
    if (gLog.length > 20000) [gLog deleteCharactersInRange:NSMakeRange(0, gLog.length - 16000)];

    NSString *line = [s stringByAppendingString:@"\n"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ vxWriteSync(line); });

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLogView) {
            gLogView.text = gLog;
            if (gLog.length) [gLogView scrollRangeToVisible:NSMakeRange(gLog.length - 1, 1)];
        }
    });
}

static void vxHex(const char *hex, unsigned char *out, int len) {
    for (int i = 0; i < len; i++) {
        unsigned v = 0;
        sscanf(hex + i * 2, "%2x", &v);
        out[i] = (unsigned char)v;
    }
}

// ============ HOOK INLINE ARM64 ============
static uint8_t gTramp[0x4000] __attribute__((aligned(0x4000)));
static int gTrampUsed = 0;
static int gHooked = 0;
static void (*p_icache)(void *, size_t) = NULL;

static int vxTrampReady(void) {
    uint64_t pg = (uint64_t)gTramp & ~(VX_PG - 1);
    if (vm_protect(mach_task_self(), pg, VX_PG, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE) != KERN_SUCCESS) return -8;
    return 0;
}

static int vxInlineHook(void *target, void *rep, void **origOut) {
    if (!target || !rep || !origOut) return -1;
    if (gTrampUsed > 480) return -9;

    for (int hop = 0; hop < 2; hop++) {
        uint32_t i0 = *(uint32_t *)target;
        if ((i0 & 0x7C000000) == 0x14000000) {
            int32_t off = (int32_t)(i0 & 0x03FFFFFF);
            if (off & 0x02000000) off |= ~0x03FFFFFF;
            void *nx = (void *)((uint8_t *)target + (int64_t)off * 4);
            if (nx == target) break;
            target = nx;
        } else break;
    }

    uint32_t *t = (uint32_t *)target;
    for (int i = 0; i < 4; i++) {
        uint32_t in = t[i];
        if ((in & 0x9F000000) == 0x90000000) return -2;
        if ((in & 0x7C000000) == 0x14000000) return -3;
        if ((in & 0xFF000010) == 0x54000000) return -4;
        if ((in & 0x3B000000) == 0x18000000) return -5;
    }

    if (!gTrampUsed) { int r = vxTrampReady(); if (r) return r; }

    uint8_t *tr = gTramp + (size_t)(gTrampUsed++) * 64;
    memcpy(tr, t, 16);
    uint32_t *w = (uint32_t *)(tr + 16);
    *(uint64_t *)(tr + 24) = (uint64_t)target + 16;
    w[0] = 0x58000050;
    w[1] = 0xD61F0200;

    uint64_t start = (uint64_t)target & ~(VX_PG - 1);
    uint64_t endp = ((uint64_t)target + 16 + VX_PG - 1) & ~(VX_PG - 1);
    size_t span = (size_t)(endp - start);
    if (span < VX_PG) span = VX_PG;
    if (vm_protect(mach_task_self(), start, span, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) return -6;

    uint32_t patch[4];
    patch[0] = 0x58000050;
    patch[1] = 0xD61F0200;
    *(uint64_t *)&patch[2] = (uint64_t)rep;
    memcpy(t, patch, 16);

    if (p_icache) p_icache(t, 16);
    *origOut = tr;
    return 0;
}

static void vxHookName(const char *name, void *rep, void **origOut) {
    void *h = dlopen(NULL, RTLD_NOW);
    void *t = dlsym(h, name);
    if (!t) { vxLog(@"[VEEX] !%@ (sin simbolo)", @(name)); return; }
    int r = vxInlineHook(t, rep, origOut);
    if (r == 0) { gHooked++; vxLog(@"[VEEX] +%@", @(name)); }
    else vxLog(@"[VEEX] !%@ (%d)", @(name), r);
}

// ============ HOOKS ============
static unsigned char *(*o_md5)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *(*o_sha1)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *(*o_sha256)(const void *, CC_LONG, unsigned char *) = NULL;

static unsigned char *h_md5(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_md5 ? o_md5(d, len, md) : NULL;
    gHitMd5++;
    if (r && md && d && len >= 8 && len <= 64) {
        const unsigned char *b = (const unsigned char *)d;
        int ok = 1;
        for (CC_LONG i = 0; i < len; i++) { if (b[i] < 0x20 || b[i] > 0x7E) { ok = 0; break; } }
        if (ok) { vxHex(VX_MD5ID, md, 16); gForced++; }
    }
    return r;
}

static unsigned char *h_sha1(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_sha1 ? o_sha1(d, len, md) : NULL;
    gHitSha1++;
    if (r && md && d && len > 20) {
        const unsigned char *b = (const unsigned char *)d;
        if (b[0] == 0xfa && b[1] == 0xde && b[2] == 0x0c && b[3] == 0x02) {
            vxHex(VX_CD, md, 20);
            gForced++;
        }
    }
    return r;
}

static unsigned char *h_sha256(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_sha256 ? o_sha256(d, len, md) : NULL;
    gHitSha256++;
    gLastLen256 = (unsigned)len;
    gLastIn256 = vxInText(d);
    if (r && md && (gLastIn256 ? (len >= 0x1000) : (gTextSz && (uint64_t)len == gTextSz))) {
        vxHex(VX_H, md, 32);
        gForced++;
    }
    return r;
}

// entitlements
static void *p_security = NULL;
static CFTypeRef (*o_stcve)(void *, CFStringRef, void **) = NULL;
static CFTypeRef h_stcve(void *task, CFStringRef key, void **err) {
    if (key) {
        if (CFStringCompare(key, CFSTR("application-identifier"), 0) == kCFCompareEqualTo)
            return (CFTypeRef)CFBridgingRetain(@(VX_APPID));
        if (CFStringCompare(key, CFSTR("com.apple.developer.team-identifier"), 0) == kCFCompareEqualTo)
            return (CFTypeRef)CFBridgingRetain(@(VX_TEAM));
    }
    return o_stcve ? o_stcve(task, key, err) : NULL;
}

typedef int32_t (*f_scv)(void *, uint32_t, void *);
typedef int32_t (*f_scvw)(void *, uint32_t, void *, void **);
static f_scv o_sscv = NULL, o_sscvw = NULL, o_scv = NULL;
static f_scvw o_scvw = NULL;
static int32_t h_scv(void *a, uint32_t b, void *c) { (void)a; (void)b; (void)c; return 0; }
static int32_t h_scvw(void *a, uint32_t b, void *c, void **d) {
    (void)a; (void)b; (void)c;
    if (d) *d = NULL;
    return 0;
}

// dyld
static uint32_t (*o_dyld_image_count)(void) = NULL;
static const char *(*o_dyld_get_image_name)(uint32_t) = NULL;
static const void *(*o_dyld_get_image_header)(uint32_t) = NULL;
static intptr_t (*o_dyld_get_image_vmaddr_slide)(uint32_t) = NULL;

static uint32_t h_dyld_image_count(void) {
    uint32_t n = o_dyld_image_count ? o_dyld_image_count() : 0;
    if (gMyIdx != 0xFFFFFFFFu && n > 0) n--;
    return n;
}
static const char *h_dyld_get_image_name(uint32_t i) {
    if (gMyIdx != 0xFFFFFFFFu && i >= gMyIdx) i++;
    return o_dyld_get_image_name ? o_dyld_get_image_name(i) : NULL;
}
static const void *h_dyld_get_image_header(uint32_t i) {
    if (gMyIdx != 0xFFFFFFFFu && i >= gMyIdx) i++;
    return o_dyld_get_image_header ? o_dyld_get_image_header(i) : NULL;
}
static intptr_t h_dyld_get_image_vmaddr_slide(uint32_t i) {
    if (gMyIdx != 0xFFFFFFFFu && i >= gMyIdx) i++;
    return o_dyld_get_image_vmaddr_slide ? o_dyld_get_image_vmaddr_slide(i) : 0;
}

// csops / sysctl
static int (*o_csops)(pid_t, unsigned int, void *, size_t) = NULL;
static int h_csops(pid_t p, unsigned int op, void *u, size_t s) {
    int r = o_csops ? o_csops(p, op, u, s) : -1;
    if (r == 0 && op == VX_CS_OPS_STATUS && u) {
        uint32_t f = *(uint32_t *)u;
        f &= ~VX_CS_DEBUGGED;
        f |= VX_CS_VALID | VX_CS_GET_TASK_ALLOW | VX_CS_HARD;
        *(uint32_t *)u = f;
    }
    return r;
}
static int (*o_sysctl)(int *, u_int, void *, size_t *, void *, size_t) = NULL;
static int h_sysctl(int *n, u_int l, void *o, size_t *ol, void *nw, size_t nl) {
    int r = o_sysctl ? o_sysctl(n, l, o, ol, nw, nl) : -1;
    if (r == 0 && o && ol && *ol >= 4 && n && l == 4 && n[0] == CTL_KERN && n[1] == KERN_PROC && n[2] == KERN_PROC_PID) {
        uint32_t f = *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF);
        *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF) = f & ~VX_P_TRACED;
    }
    return r;
}
static int (*o_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;
static int h_sysctlbyname(const char *nm, void *o, size_t *ol, void *nw, size_t nl) {
    int r = o_sysctlbyname ? o_sysctlbyname(nm, o, ol, nw, nl) : -1;
    if (r == 0 && o && ol && *ol >= 4 && nm && strcmp(nm, "kern.proc.pid") == 0) {
        uint32_t f = *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF);
        *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF) = f & ~VX_P_TRACED;
    }
    return r;
}

static void vxInstallHooks(void) {
    if (gInstalled) return;
    gInstalled = 1;
    if (!p_icache) p_icache = (void (*)(void *, size_t))dlsym(RTLD_DEFAULT, "sys_icache_invalidate");

#if VX_HOOKSET >= 1
    vxHookName("CC_MD5",    (void *)h_md5,    (void **)&o_md5);
    vxHookName("CC_SHA1",   (void *)h_sha1,   (void **)&o_sha1);
    vxHookName("CC_SHA256", (void *)h_sha256, (void **)&o_sha256);
#endif
#if VX_HOOKSET >= 2
    if (!p_security) p_security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    if (p_security) {
        void *t1 = dlsym(p_security, "SecTaskCopyValueForEntitlement");
        if (t1 && vxInlineHook(t1, (void *)h_stcve, (void **)&o_stcve) == 0) { gHooked++; vxLog(@"[VEEX] +stcve"); }
        void *t2 = dlsym(p_security, "SecStaticCodeCheckValidity");
        if (t2 && vxInlineHook(t2, (void *)h_scv, (void **)&o_sscv) == 0) gHooked++;
        void *t3 = dlsym(p_security, "SecStaticCodeCheckValidityWithErrors");
        if (t3 && vxInlineHook(t3, (void *)h_scvw, (void **)&o_sscvw) == 0) gHooked++;
        void *t4 = dlsym(p_security, "SecCodeCheckValidity");
        if (t4 && vxInlineHook(t4, (void *)h_scv, (void **)&o_scv) == 0) gHooked++;
        void *t5 = dlsym(p_security, "SecCodeCheckValidityWithErrors");
        if (t5 && vxInlineHook(t5, (void *)h_scvw, (void **)&o_scvw) == 0) gHooked++;
    }
#endif
#if VX_HOOKSET >= 3
    vxHookName("_dyld_image_count",            (void *)h_dyld_image_count,            (void **)&o_dyld_image_count);
    vxHookName("_dyld_get_image_name",         (void *)h_dyld_get_image_name,         (void **)&o_dyld_get_image_name);
    vxHookName("_dyld_get_image_header",       (void *)h_dyld_get_image_header,       (void **)&o_dyld_get_image_header);
    vxHookName("_dyld_get_image_vmaddr_slide", (void *)h_dyld_get_image_vmaddr_slide, (void **)&o_dyld_get_image_vmaddr_slide);
#endif
#if VX_HOOKSET >= 4
    vxHookName("csops",        (void *)h_csops,        (void **)&o_csops);
    vxHookName("sysctlbyname", (void *)h_sysctlbyname, (void **)&o_sysctlbyname);
    vxHookName("sysctl",       (void *)h_sysctl,       (void **)&o_sysctl);
#endif

    if (!gMainHdr) gMainHdr = (uint64_t)_dyld_get_image_header(0);
    vxLog(@"[VEEX] hooked=%d idx=%u main=%llx", gHooked, gMyIdx, gMainHdr);
}

// ============ ocultar imagen ============
static void vxFindSelf(void) {
    Dl_info di;
    if (!dladdr((void *)vxFindSelf, &di) || !di.dli_fbase) return;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++)
        if (_dyld_get_image_header(i) == di.dli_fbase) { gMyIdx = i; return; }
}

static void vxPatchLoadName(void) {
    if (!gMyIdx || gMyIdx == 0xFFFFFFFFu) return;
    const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(gMyIdx);
    if (!h) return;
    const struct load_command *lc = (const struct load_command *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_LOAD_DYLIB) {
            struct dylib_command *dc = (struct dylib_command *)lc;
            char *nm = (char *)dc + dc->dylib.name.offset;
            uint32_t cur = (uint32_t)strlen(nm);
            uint32_t fakeLen = (uint32_t)strlen(VX_FAKE) + 1;
            if (cur >= fakeLen) {
                uint64_t pg = (uint64_t)nm & ~(VX_PG - 1);
                vm_protect(mach_task_self(), pg, (size_t)VX_PG, false,
                           VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                memset(nm, 0, cur);
                memcpy(nm, VX_FAKE, fakeLen);
            }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
}

// ============ reescritura del cuerpo ============
static NSURLSessionDataTask *(*o_dt)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *)) = NULL;
static NSURLSessionUploadTask *(*o_ut)(id, SEL, NSURLRequest *, NSData *, void (^)(NSData *, NSURLResponse *, NSError *)) = NULL;

static NSString *vxSub(NSString *s, const char *k, const char *v) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        [NSString stringWithFormat:@"\"%@\"\\s*:\\s*\"[0-9a-fA-F]+\"", @(k)] options:0 error:NULL];
    if (!re) return s;
    return [re stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length)
            withTemplate:[NSString stringWithFormat:@"\"%@\":\"%@\"", @(k), @(v)]];
}

static NSURLRequest *vxRewrite(NSURLRequest *req) {
    NSData *b = [req HTTPBody];
    if (!b || b.length < 40) return req;
    NSString *s = [[NSString alloc] initWithData:b encoding:NSUTF8StringEncoding];
    if (!s) return req;
    if (![s containsString:@"\"h\""] && ![s containsString:@"\"cdhash\""] && ![s containsString:@"\"md5\""]) return req;

    NSString *o = s;
    s = vxSub(s, "h", VX_H);
    s = vxSub(s, "cdhash", VX_CD);
    s = vxSub(s, "md5", VX_MD5ID);
    s = [s stringByReplacingOccurrencesOfString:@"N5P6RAT4P7" withString:@(VX_TEAM)];
    s = [s stringByReplacingOccurrencesOfString:@"app.badger6804.pineapple6732" withString:@"com.dts.freefireth"];
    if ([s isEqualToString:o]) return req;

    gBodies++;
    if (gBodies <= 6)
        vxLog(@"[VEEX] body (%lu) %@", (unsigned long)b.length, [s substringToIndex:MIN(s.length, 320)]);

    NSMutableURLRequest *m = [req mutableCopy];
    [m setHTTPBody:[s dataUsingEncoding:NSUTF8StringEncoding]];
    return m;
}

static NSURLSessionDataTask *h_dt(id self, SEL c, NSURLRequest *r, void (^cb)(NSData *, NSURLResponse *, NSError *)) {
    NSURLRequest *n = vxRewrite(r);
    return o_dt ? o_dt(self, c, n, cb) : nil;
}
static NSURLSessionUploadTask *h_ut(id self, SEL c, NSURLRequest *r, NSData *d, void (^cb)(NSData *, NSURLResponse *, NSError *)) {
    NSURLRequest *n = vxRewrite(r);
    return o_ut ? o_ut(self, c, n, d, cb) : nil;
}
static void vxInstallBody(void) {
    Method m = class_getInstanceMethod([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:));
    if (m) o_dt = (void *)method_setImplementation(m, (IMP)h_dt);
    Method u = class_getInstanceMethod([NSURLSession class], @selector(uploadTaskWithRequest:fromData:completionHandler:));
    if (u) o_ut = (void *)method_setImplementation(u, (IMP)h_ut);
}

// ============ Attest ============
static void vxKillAttest(void) {
    Class c = NSClassFromString(@"DCAppAttestService");
    if (!c) { vxLog(@"[VEEX] attest sin clase"); return; }
    Method m = class_getInstanceMethod(c, @selector(isSupported));
    if (m) method_setImplementation(m, imp_implementationWithBlock(^BOOL(id s) { (void)s; return NO; }));
    vxLog(@"[VEEX] attest swz=%d", m ? 1 : 0);
}

// ============ huellas ============
static void vxFingerprint(void) {
    vxLog(@"[VEEX] bundle=%@", [[NSBundle mainBundle] bundleIdentifier]);
    vxLog(@"[VEEX] exe=%s", [[[NSBundle mainBundle] executablePath] UTF8String]);

    void *sec = p_security ? p_security : dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    if (!sec) return;
    void *(*mk)(void) = (void *(*)(void))dlsym(sec, "SecTaskCreateFromSelf");
    CFTypeRef (*get)(void *, CFStringRef, void **) = (CFTypeRef (*)(void *, CFStringRef, void **))
        dlsym(sec, "SecTaskCopyValueForEntitlement");
    if (!mk || !get) return;
    void *t = mk();
    if (!t) return;
    const char *keys[] = { "application-identifier", "com.apple.developer.team-identifier",
                           "get-task-allow", "beta-reports-active", "aps-environment" };
    for (int i = 0; i < 5; i++) {
        CFStringRef k = CFStringCreateWithCString(NULL, keys[i], kCFStringEncodingUTF8);
        CFTypeRef v = get(t, k, NULL);
        if (v) {
            vxLog(@"[VEEX] ent %s=%@", keys[i], (__bridge id)v);
            CFRelease(v);
        } else vxLog(@"[VEEX] ent %s=(nil)", keys[i]);
        CFRelease(k);
    }
}

// ============ imagen ============
static void vxSetBase(const struct mach_header_64 *h) {
    if (!h) return;
    gBase = (uint64_t)h;
    const struct load_command *lc = (const struct load_command *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { gSize = sg->vmsize; break; }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
}

static void vxFindImage(void) {
    const struct mach_header_64 *h = NULL;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (nm && strstr(nm, "UnityFramework")) { h = (const struct mach_header_64 *)_dyld_get_image_header(i); break; }
    }
    if (!h) for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (nm && strstr(nm, "/FreeFire")) { h = (const struct mach_header_64 *)_dyld_get_image_header(i); break; }
    }
    if (h) vxSetBase(h);
}

static void vxPatchCryptid(void) {
    if (!gBase) return;
    struct mach_header_64 *h = (struct mach_header_64 *)gBase;
    uint8_t *p = (uint8_t *)h + sizeof(*h);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        struct load_command *lc = (struct load_command *)p;
        if (lc->cmd == LC_ENCRYPTION_INFO_64 &&
            ((struct encryption_info_command_64 *)lc)->cryptid != 1) {
            vm_protect(mach_task_self(), (uint64_t)h & ~(VX_PG - 1), VX_PG, false,
                       VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            ((struct encryption_info_command_64 *)lc)->cryptid = 1;
            vxLog(@"[VEEX] cryptid 0->1 %s", _dyld_get_image_name(0));
        }
        p += lc->cmdsize;
    }
}

// ============ il2cpp ============
typedef void *(*f_v)(void);
typedef void *(*f_asms)(void *, size_t *);
typedef void *(*f_p1)(void *);
typedef size_t (*f_s1)(void *);
typedef void *(*f_i1)(void *, size_t);
typedef const char *(*f_c1)(void *);
typedef void *(*f_mf)(void *, const char *, int);
typedef void *(*f_att)(void *);

static f_v p_dom; static f_asms p_asms; static f_p1 p_img; static f_s1 p_cc;
static f_i1 p_ci; static f_c1 p_cn; static f_mf p_mf;
static f_att p_att; static f_p1 p_kl;
static int gI2C = 0;

static void vxLoadIL2CPP(void) {
    void *h = dlopen(NULL, RTLD_NOW);
#define R(n, v) v = (void *)dlsym(h, n)
    R("il2cpp_domain_get", p_dom);
    R("il2cpp_thread_attach", p_att);
    R("il2cpp_domain_get_assemblies", p_asms);
    R("il2cpp_assembly_get_image", p_img);
    R("il2cpp_image_get_class_count", p_cc);
    R("il2cpp_image_get_class", p_ci);
    R("il2cpp_class_get_name", p_cn);
    R("il2cpp_class_get_method_from_name", p_mf);
    R("il2cpp_object_get_class", p_kl);
#undef R
    gI2C = p_dom && p_asms && p_img && p_cc && p_ci && p_cn && p_mf && p_kl;
    if (gI2C && p_att) p_att(p_dom());
    vxLog(@"[VEEX] il2cpp %@", gI2C ? @"OK" : @"FALLO");
}

// ============ dibujo ============
typedef struct {
    int t; float x, y, w, h; float r, g, b, a; char s[72];
} vxCmd;
#define VX_CMAX 512
static vxCmd gCmd[VX_CMAX];
static volatile int gCmdN = 0;
static volatile int gDrawLock = 0;

static void vxLock(void) {
    while (__atomic_test_and_set((volatile void *)&gDrawLock, __ATOMIC_ACQUIRE)) {}
}
static void vxUnlock(void) { __atomic_clear((volatile void *)&gDrawLock, __ATOMIC_RELEASE); }

@interface VXCanvas : UIView @end
@implementation VXCanvas
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    (void)rect;
    CGContextRef c = UIGraphicsGetCurrentContext();
    vxLock();
    int n = gCmdN;
    for (int i = 0; i < n; i++) {
        vxCmd *q = &gCmd[i];
        CGContextSetRGBStrokeColor(c, q->r, q->g, q->b, q->a);
        CGContextSetRGBFillColor(c, q->r, q->g, q->b, q->a);
        CGContextSetLineWidth(c, 1.4);
        if (q->t == 0) CGContextStrokeRect(c, CGRectMake(q->x, q->y, q->w, q->h));
        else if (q->t == 1) {
            CGContextMoveToPoint(c, q->x, q->y);
            CGContextAddLineToPoint(c, q->w, q->h);
            CGContextStrokePath(c);
        } else if (q->t == 2) {
            UIFont *f = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
            [[NSString stringWithUTF8String:q->s] drawAtPoint:CGPointMake(q->x, q->y)
                withAttributes:@{ NSFontAttributeName: f, NSForegroundColorAttributeName:
                [UIColor colorWithRed:q->r green:q->g blue:q->b alpha:q->a] }];
        }
    }
    vxUnlock();
}
@end

@interface VXRoot : UIView @end
@implementation VXRoot
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return v == self ? nil : v;
}
@end

@interface VXRow : UIButton
- (void)vxPaint;
@end
@implementation VXRow
- (void)vxTap {
    NSString *k = objc_getAssociatedObject(self, "k");
    if (k) { gCfg[k] = [gCfg[k] boolValue] ? @NO : @YES; [self vxPaint]; }
}
- (void)vxPaint {
    NSString *k = objc_getAssociatedObject(self, "k");
    BOOL on = [gCfg[k] boolValue];
    self.backgroundColor = on ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:1 alpha:0.62];
    [self setTitleColor:on ? UIColor.whiteColor : [UIColor colorWithWhite:0.1 alpha:1] forState:UIControlStateNormal];
}
@end

static int l_clear(lua_State *L) { (void)L; vxLock(); gCmdN = 0; vxUnlock(); return 0; }
static int l_rect(lua_State *L) {
    vxLock();
    if (gCmdN < VX_CMAX) {
        vxCmd *q = &gCmd[gCmdN++];
        q->t = 0; q->x = (float)luaL_checknumber(L,1); q->y = (float)luaL_checknumber(L,2);
        q->w = (float)luaL_checknumber(L,3); q->h = (float)luaL_checknumber(L,4);
        q->r = (float)luaL_optnumber(L,5,1); q->g = (float)luaL_optnumber(L,6,1);
        q->b = (float)luaL_optnumber(L,7,1); q->a = (float)luaL_optnumber(L,8,1);
    }
    vxUnlock();
    return 0;
}
static int l_line(lua_State *L) {
    vxLock();
    if (gCmdN < VX_CMAX) {
        vxCmd *q = &gCmd[gCmdN++];
        q->t = 1; q->x = (float)luaL_checknumber(L,1); q->y = (float)luaL_checknumber(L,2);
        q->w = (float)luaL_checknumber(L,3); q->h = (float)luaL_checknumber(L,4);
        q->r = (float)luaL_optnumber(L,5,1); q->g = (float)luaL_optnumber(L,6,1);
        q->b = (float)luaL_optnumber(L,7,1); q->a = (float)luaL_optnumber(L,8,1);
    }
    vxUnlock();
    return 0;
}
static int l_text(lua_State *L) {
    const char *s = luaL_checkstring(L,1);
    vxLock();
    if (gCmdN < VX_CMAX) {
        vxCmd *q = &gCmd[gCmdN++];
        q->t = 2; q->x = (float)luaL_checknumber(L,2); q->y = (float)luaL_checknumber(L,3);
        q->r = (float)luaL_optnumber(L,4,1); q->g = (float)luaL_optnumber(L,5,1);
        q->b = (float)luaL_optnumber(L,6,1); q->a = (float)luaL_optnumber(L,7,1);
        strncpy(q->s, s, 71); q->s[71] = 0;
    }
    vxUnlock();
    return 0;
}

static int l_sw(lua_State *L) { lua_pushnumber(L, [UIScreen mainScreen].bounds.size.width); return 1; }
static int l_sh(lua_State *L) { lua_pushnumber(L, [UIScreen mainScreen].bounds.size.height); return 1; }
static int l_log(lua_State *L) { vxLog(@"[L] %s", luaL_checkstring(L,1)); return 0; }
static int l_sleep(lua_State *L) { [NSThread sleepForTimeInterval:luaL_checknumber(L,1)/1000.0]; return 0; }
static int l_cfg(lua_State *L) {
    id v = gCfg[[NSString stringWithUTF8String:luaL_checkstring(L,1)]];
    if ([v isKindOfClass:[NSNumber class]]) lua_pushnumber(L, [v doubleValue]); else lua_pushnil(L);
    return 1;
}
static int l_r32(lua_State *L) { lua_pushinteger(L, *(uint32_t *)(uintptr_t)luaL_checkinteger(L,1)); return 1; }
static int l_r64(lua_State *L) { lua_pushinteger(L, *(uint64_t *)(uintptr_t)luaL_checkinteger(L,1)); return 1; }
static int l_rf(lua_State *L) { lua_pushnumber(L, *(float *)(uintptr_t)luaL_checkinteger(L,1)); return 1; }
static int l_w32(lua_State *L) { *(uint32_t *)(uintptr_t)luaL_checkinteger(L,1) = (uint32_t)luaL_checkinteger(L,2); return 0; }
static int l_wf(lua_State *L) { *(float *)(uintptr_t)luaL_checkinteger(L,1) = (float)luaL_checknumber(L,2); return 0; }

static int l_i2c_ready(lua_State *L) { lua_pushboolean(L, gI2C); return 1; }

static int l_i2c_class(lua_State *L) {
    const char *cls = luaL_checkstring(L,1);
    if (!gI2C) { lua_pushnil(L); return 1; }
    size_t n = 0;
    void **asms = (void **)p_asms(p_dom(), &n);
    for (size_t a = 0; a < n; a++) {
        void *img = p_img(asms[a]);
        if (!img) continue;
        size_t c = p_cc(img);
        for (size_t i = 0; i < c; i++) {
            void *kl = p_ci(img, i);
            if (kl && !strcmp(p_cn(kl), cls)) { lua_pushinteger(L, (lua_Integer)(uintptr_t)kl); return 1; }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int l_i2c_mptr(lua_State *L) {
    uint64_t kl = (uint64_t)luaL_checkinteger(L,1);
    const char *mth = luaL_checkstring(L,2);
    int argc = (int)luaL_optinteger(L,3,0);
    if (!gI2C || !kl) { lua_pushnil(L); return 1; }
    void *m = p_mf((void *)(uintptr_t)kl, mth, argc);
    if (m) lua_pushinteger(L, *(uint64_t *)m); else lua_pushnil(L);
    return 1;
}

static int l_kl(lua_State *L) {
    uint64_t o = (uint64_t)luaL_checkinteger(L,1);
    lua_pushinteger(L, o ? (lua_Integer)(uintptr_t)p_kl((void *)(uintptr_t)o) : 0);
    return 1;
}

typedef uint64_t (*f_c4)(uint64_t, uint64_t, uint64_t, uint64_t);
static int l_call(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1);
    uint64_t a = (uint64_t)luaL_optinteger(L,2,0), b = (uint64_t)luaL_optinteger(L,3,0);
    uint64_t c = (uint64_t)luaL_optinteger(L,4,0), d = (uint64_t)luaL_optinteger(L,5,0);
    lua_pushinteger(L, f ? (lua_Integer)((f_c4)(uintptr_t)f)(a,b,c,d) : 0);
    return 1;
}
static int l_callv(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1);
    uint64_t a = (uint64_t)luaL_optinteger(L,3,0);
    lua_pushinteger(L, f ? (lua_Integer)((f_c4)(uintptr_t)f)(a,0,0,0) : 0);
    return 1;
}

static int l_arrlen(lua_State *L) {
    uint64_t a = (uint64_t)luaL_checkinteger(L,1);
    lua_pushinteger(L, a ? *(uint32_t *)(uintptr_t)(a + 0x18) : 0);
    return 1;
}
static int l_arrat(lua_State *L) {
    uint64_t a = (uint64_t)luaL_checkinteger(L,1);
    int i = (int)luaL_checkinteger(L,2);
    lua_pushinteger(L, a ? *(uint64_t *)(uintptr_t)(a + 0x20 + (uint64_t)i * 8) : 0);
    return 1;
}

typedef struct { float x, y, z; } vx3f;
static int l_pos3(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1);
    uint64_t o = (uint64_t)luaL_checkinteger(L,2);
    vx3f r = ((vx3f (*)(uint64_t))(uintptr_t)f)(o);
    lua_pushnumber(L, r.x); lua_pushnumber(L, r.y); lua_pushnumber(L, r.z);
    return 3;
}
static int l_gete(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1);
    uint64_t o = (uint64_t)luaL_checkinteger(L,2);
    vx3f r = ((vx3f (*)(uint64_t))(uintptr_t)f)(o);
    lua_pushnumber(L, r.x); lua_pushnumber(L, r.y); lua_pushnumber(L, r.z);
    return 3;
}
static int l_sete(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1);
    uint64_t o = (uint64_t)luaL_checkinteger(L,2);
    float x = (float)luaL_checknumber(L,3), y = (float)luaL_checknumber(L,4), z = (float)luaL_checknumber(L,5);
    ((void (*)(uint64_t, float, float, float))(uintptr_t)f)(o, x, y, z);
    return 0;
}

static int l_str(lua_State *L) {
    uint64_t s = (uint64_t)luaL_checkinteger(L,1);
    if (!s) { lua_pushstring(L, ""); return 1; }
    int32_t len = *(int32_t *)(uintptr_t)(s + 0x10);
    if (len < 0 || len > 64) len = 64;
    char out[200]; int k = 0;
    const uint16_t *ch = (const uint16_t *)(uintptr_t)(s + 0x14);
    for (int32_t i = 0; i < len && k < 190; i++) {
        uint16_t c = ch[i];
        out[k++] = (c < 0x80) ? (char)c : '?';
    }
    out[k] = 0;
    lua_pushstring(L, out);
    return 1;
}

// ============ script ============
static void vxStopScript(void) {
    gRun = 0;
    if (gL) { lua_close(gL); gL = NULL; }
}

static void vxRunScript(void) {
    vxStopScript();
    if (!gI2C) { vxLog(@"[VEEX] sin il2cpp"); return; }

    NSString *path = [gDocs stringByAppendingPathComponent:@"esp.lua"];
    NSData *d = [NSData dataWithContentsOfURL:
        [NSURL URLWithString:[SCRIPT_URL stringByAppendingFormat:@"?t=%d", (int)time(NULL)]]];
    if (d.length > 100) [d writeToFile:path atomically:YES];
    else vxLog(@"[VEEX] sin red, uso copia local");

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { vxLog(@"[VEEX] falta esp.lua"); return; }

    vxLog(@"[VEEX] lanzando script...");
    gL = luaL_newstate();
    luaL_openlibs(gL);
    lua_register(gL, "log", l_log); lua_register(gL, "msleep", l_sleep);
    lua_register(gL, "text", l_text); lua_register(gL, "rect", l_rect);
    lua_register(gL, "line", l_line); lua_register(gL, "clear", l_clear);
    lua_register(gL, "sw", l_sw); lua_register(gL, "sh", l_sh);
    lua_register(gL, "r32", l_r32); lua_register(gL, "r64", l_r64);
    lua_register(gL, "rf", l_rf); lua_register(gL, "w32", l_w32); lua_register(gL, "wf", l_wf);
    lua_register(gL, "cfg", l_cfg);
    lua_register(gL, "i2c_ready", l_i2c_ready); lua_register(gL, "i2c_class", l_i2c_class);
    lua_register(gL, "i2c_mptr", l_i2c_mptr); lua_register(gL, "kl", l_kl);
    lua_register(gL, "call", l_call); lua_register(gL, "callv", l_callv);
    lua_register(gL, "arrlen", l_arrlen); lua_register(gL, "arrat", l_arrat);
    lua_register(gL, "pos3", l_pos3); lua_register(gL, "gete", l_gete);
    lua_register(gL, "sete", l_sete); lua_register(gL, "str", l_str);
    lua_pushinteger(gL, (lua_Integer)gBase); lua_setglobal(gL, "BASE");
    lua_pushinteger(gL, (lua_Integer)gSize); lua_setglobal(gL, "SIZE");
    lua_pushstring(gL, gDocs.UTF8String); lua_setglobal(gL, "DOC");

    if (luaL_dofile(gL, path.UTF8String) != LUA_OK) {
        vxLog(@"[VEEX] LUA ERROR: %s", lua_tostring(gL, -1));
        return;
    }
    vxLog(@"[VEEX] script cargado");
    gRun = 1;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (gRun && gL) {
            lua_getglobal(gL, "tick");
            if (lua_isfunction(gL, -1)) {
                if (lua_pcall(gL, 0, 0, 0) != LUA_OK) {
                    vxLog(@"[VEEX] LUA tick: %s", lua_tostring(gL, -1));
                    lua_pop(gL, 1);
                }
            } else lua_pop(gL, 1);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gDraw) [gDraw setNeedsDisplay];
            });
            [NSThread sleepForTimeInterval:1.0 / VX_FPS];
        }
    });
}

// ============ UI ============
static void vxBuildTab(void);

static void addRow(NSString *title, NSString *key, CGFloat y) {
    VXRow *r = [VXRow buttonWithType:UIButtonTypeCustom];
    r.frame = CGRectMake(8, y, gContent.bounds.size.width - 16, 32);
    r.layer.cornerRadius = 9;
    r.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [r setTitle:title forState:UIControlStateNormal];
    objc_setAssociatedObject(r, "k", key, OBJC_ASSOCIATION_RETAIN);
    [r addTarget:r action:@selector(vxTap) forControlEvents:UIControlEventTouchUpInside];
    [gContent addSubview:r];
    [r vxPaint];
}

static void vxBuildTab(void) {
    for (UIView *v in gContent.subviews) [v removeFromSuperview];
    for (int i = 0; i < (int)gTabBtns.count; i++) {
        UIButton *t = (UIButton *)gTabBtns[i];
        BOOL on = (i == gTab);
        t.backgroundColor = on ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:1 alpha:0.6];
        [t setTitleColor:on ? UIColor.whiteColor : [UIColor colorWithWhite:0.1 alpha:1] forState:UIControlStateNormal];
    }
    CGFloat y = 4;
    if (gTab == 0) {
        addRow(@"ESP master", @"esp.on", y); y += 36;
        addRow(@"Cajas", @"esp.box", y); y += 36;
        addRow(@"Nombres", @"esp.name", y); y += 36;
        addRow(@"Distancia", @"esp.dist", y); y += 36;
        addRow(@"Color auto", @"esp.color", y);
    } else if (gTab == 1) {
        addRow(@"Aimbot", @"aim.on", y); y += 36;
        addRow(@"Predicción", @"aim.pred", y); y += 36;
        addRow(@"Humanizar", @"aim.human", y); y += 36;
        addRow(@"Modo silencioso", @"aim.silent", y); y += 36;
        addRow(@"AWM / larga", @"aim.awm", y);
    } else if (gTab == 2) {
        addRow(@"Líneas", @"draw.line", y); y += 36;
        addRow(@"Salud", @"draw.hp", y); y += 36;
        addRow(@"Arma", @"draw.wpn", y); y += 36;
        addRow(@"Esqueleto", @"draw.skel", y);
    } else if (gTab == 3) {
        addRow(@"Contador FPS", @"misc.fps", y); y += 36;
        addRow(@"Ocultar en lobby", @"misc.hide", y); y += 36;
        addRow(@"Anti-captura", @"misc.anti", y);
    } else {
        addRow(@"RESET GUEST", @"set.reset", y); y += 36;
        addRow(@"Recargar script", @"set.reload", y);
    }
}

static void vxResetGuest(void) {
    vxLog(@"[VEEX] RESET GUEST...");
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword});
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass:(__bridge id)kSecClassInternetPassword});
    NSString *pref = @"/var/mobile/Library/Preferences";
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pref error:nil])
        if ([f hasPrefix:@"com.dts.freefireth"])
            [[NSFileManager defaultManager] removeItemAtPath:[pref stringByAppendingPathComponent:f] error:nil];
    vxLog(@"[VEEX] RESET hecho, cierra el juego");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ exit(0); });
}

@interface VXRoot (Actions)
- (void)vxDoClose;
- (void)vxDoTab:(UIButton *)b;
- (void)vxDoHook;
- (void)vxDoRun;
- (void)vxDoStop;
- (void)vxDoCopy;
@end

static void buildUI(UIWindowScene *sc) {
    gCfg = [NSMutableDictionary dictionary];
    gCfg[@"esp.on"] = @NO; gCfg[@"esp.box"] = @YES; gCfg[@"esp.name"] = @NO;
    gCfg[@"esp.dist"] = @YES; gCfg[@"esp.color"] = @NO;
    gCfg[@"aim.on"] = @NO; gCfg[@"aim.pred"] = @YES; gCfg[@"aim.human"] = @YES;
    gCfg[@"aim.silent"] = @NO; gCfg[@"aim.awm"] = @NO;
    gCfg[@"draw.line"] = @NO; gCfg[@"draw.hp"] = @NO; gCfg[@"draw.wpn"] = @NO; gCfg[@"draw.skel"] = @NO;
    gCfg[@"misc.fps"] = @NO; gCfg[@"misc.hide"] = @NO; gCfg[@"misc.anti"] = @NO;

    gWin = [[UIWindow alloc] initWithWindowScene:sc];
    gWin.frame = sc.coordinateSpace.bounds;
    gWin.windowLevel = UIWindowLevelAlert + 1;
    gWin.backgroundColor = UIColor.clearColor;

    gRoot = [[VXRoot alloc] initWithFrame:gWin.bounds];
    gRoot.backgroundColor = UIColor.clearColor;
    UIViewController *vc = [UIViewController new];
    vc.view = gRoot;
    gWin.rootViewController = vc;
    gWin.hidden = NO;

    gDraw = [[VXCanvas alloc] initWithFrame:gWin.bounds];
    [gRoot addSubview:gDraw];

    CGFloat W = gWin.bounds.size.width;
    CGFloat ph = MIN(468, gWin.bounds.size.height - 90);
    gPanel = [[UIView alloc] initWithFrame:CGRectMake(W - 250, 44, 238, ph)];
    gPanel.layer.cornerRadius = 18;
    gPanel.clipsToBounds = YES;
    gPanel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.92];
    gPanel.hidden = YES;
    [gRoot addSubview:gPanel];

    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 238, 36)];
    head.backgroundColor = [UIColor colorWithWhite:0.11 alpha:1];
    [gPanel addSubview:head];

    UILabel *ttl = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 120, 36)];
    ttl.text = @"VEEX 63";
    ttl.textColor = UIColor.whiteColor;
    ttl.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    [head addSubview:ttl];

    UIButton *hook = [UIButton buttonWithType:UIButtonTypeSystem];
    hook.frame = CGRectMake(150, 6, 46, 24);
    [hook setTitle:@"HOOK" forState:UIControlStateNormal];
    hook.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [hook addTarget:gRoot action:@selector(vxDoHook) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:hook];

    UIButton *cl = [UIButton buttonWithType:UIButtonTypeSystem];
    cl.frame = CGRectMake(200, 6, 30, 24);
    [cl setTitle:@"X" forState:UIControlStateNormal];
    [cl addTarget:gRoot action:@selector(vxDoClose) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:cl];

    NSArray *names = @[@"ESP", @"AIM", @"DRAW", @"MISC", @"SET"];
    NSMutableArray *btns = [NSMutableArray array];
    for (int i = 0; i < (int)names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(8 + i * 44, 42, 40, 26);
        b.tag = i;
        b.layer.cornerRadius = 8;
        b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        [b setTitle:names[i] forState:UIControlStateNormal];
        [b addTarget:gRoot action:@selector(vxDoTab:) forControlEvents:UIControlEventTouchUpInside];
        [gPanel addSubview:b];
        [btns addObject:b];
    }
    gTabBtns = btns;

    gContent = [[UIView alloc] initWithFrame:CGRectMake(0, 72, 238, 190)];
    [gPanel addSubview:gContent];

    CGFloat lh = MAX(90, ph - 316);
    gLogView = [[UITextView alloc] initWithFrame:CGRectMake(8, 266, 222, lh)];
    gLogView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1];
    gLogView.layer.cornerRadius = 8;
    gLogView.editable = NO;
    gLogView.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    gLogView.textColor = [UIColor colorWithWhite:0.15 alpha:1];
    [gPanel addSubview:gLogView];

    UIButton *run = [UIButton buttonWithType:UIButtonTypeSystem];
    run.frame = CGRectMake(8, ph - 42, 70, 30);
    [run setTitle:@"RUN" forState:UIControlStateNormal];
    run.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [run addTarget:gRoot action:@selector(vxDoRun) forControlEvents:UIControlEventTouchUpInside];
    [gPanel addSubview:run];

    UIButton *stop = [UIButton buttonWithType:UIButtonTypeSystem];
    stop.frame = CGRectMake(84, ph - 42, 70, 30);
    [stop setTitle:@"STOP" forState:UIControlStateNormal];
    stop.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [stop addTarget:gRoot action:@selector(vxDoStop) forControlEvents:UIControlEventTouchUpInside];
    [gPanel addSubview:stop];

    UIButton *cp = [UIButton buttonWithType:UIButtonTypeSystem];
    cp.frame = CGRectMake(160, ph - 42, 70, 30);
    [cp setTitle:@"COPIAR" forState:UIControlStateNormal];
    cp.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [cp addTarget:gRoot action:@selector(vxDoCopy) forControlEvents:UIControlEventTouchUpInside];
    [gPanel addSubview:cp];

    UIButton *fab = [UIButton buttonWithType:UIButtonTypeSystem];
    fab.frame = CGRectMake(W - 58, 96, 44, 44);
    fab.layer.cornerRadius = 22;
    fab.backgroundColor = [UIColor colorWithWhite:0.11 alpha:0.85];
    [fab setTitle:@"VX" forState:UIControlStateNormal];
    [fab setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    fab.titleLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    [fab addTarget:gRoot action:@selector(vxDoClose) forControlEvents:UIControlEventTouchUpInside];
    [gRoot addSubview:fab];

    vxBuildTab();
    vxLog(@"[VEEX] UI lista · hits md5=%d sha1=%d sha256=%d", gHitMd5, gHitSha1, gHitSha256);
    gLogView.text = gLog ?: @"";
}

@implementation VXRoot (Actions)
- (void)vxDoClose { gOpen = !gOpen; gPanel.hidden = !gOpen; }
- (void)vxDoTab:(UIButton *)b { gTab = (int)b.tag; vxBuildTab(); }
- (void)vxDoHook { vxInstallHooks(); vxFindSelf(); vxPatchLoadName(); vxKillAttest(); vxFingerprint(); }
- (void)vxDoRun { vxRunScript(); }
- (void)vxDoStop { vxStopScript(); vxLog(@"[VEEX] script detenido"); }
- (void)vxDoCopy { UIPasteboard.generalPasteboard.string = gLog ?: @""; vxLog(@"[VEEX] log copiado"); }
@end

// ============ arranque ============
static void boot(double delay) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindowScene *sc = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { sc = (UIWindowScene *)s; break; }
        if (!sc) { vxLog(@"[VEEX] sin escena"); return; }
        buildUI(sc);
    });
}

static void vxInitEarly(void) {
    if (!gLog) gLog = [NSMutableString new];
    vxLog(@"[VEEX] build %d", VX_BUILD);
    gMainHdr = (uint64_t)_dyld_get_image_header(0);
    if (gMainHdr) {
        size_t sz = 0;
        uint8_t *p = getsegmentdata((const struct mach_header_64 *)gMainHdr, "__TEXT", &sz);
        if (p && sz) { gTextLo = (uint64_t)p; gTextHi = (uint64_t)p + sz; gTextSz = sz; }
    }
#if VX_AUTOHOOK
    vxInstallHooks();
    vxInstallBody();
#endif
}

__attribute__((constructor)) static void vxInit(void) {
    vxInitEarly();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            vxLog(@"[VEEX] init stage=%d set=%d", VX_STAGE, VX_HOOKSET);
            gDocs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *lp = [gDocs stringByAppendingPathComponent:@"veex.log"];
            NSString *prev = [NSString stringWithContentsOfFile:lp encoding:NSUTF8StringEncoding error:nil];
            if (prev.length) {
                NSString *tail = prev.length > 3000 ? [prev substringFromIndex:prev.length - 3000] : prev;
                vxLog(@"--- anterior ---\n%@", tail);
            }
            [@"" writeToFile:lp atomically:YES encoding:NSUTF8StringEncoding error:nil];

            vxLoadIL2CPP();
            for (int i = 0; i < 40 && !gBase; i++) {
                vxFindImage();
                if (!gBase) [NSThread sleepForTimeInterval:0.5];
            }
            vxLog(@"[VEEX] base=%llx size=%llx", gBase, gSize);
#if VX_STAGE >= 3
            vxFindSelf();
            vxPatchLoadName();
            vxKillAttest();
#endif
            [NSThread sleepForTimeInterval:2.0];
#if VX_STAGE >= 4
            vxPatchCryptid();
#endif
            boot(1.5);
            vxLog(@"[VEEX] arranque completo");
        }
    });
}
