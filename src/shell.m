// src/shell.m — VEEX build 150
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach/vm_region.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>
#import <stdio.h>
#import <stdarg.h>
#import <stdlib.h>
#import <string.h>
#import <time.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <pthread.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
extern kern_return_t vm_region_64(vm_map_t, vm_address_t *, vm_size_t *, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);
extern kern_return_t mach_vm_region(vm_map_t, uint64_t *, uint64_t *, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);
#define VX_BUILD 150
#define VX_BOOT 3
#define VX_HOOKSET 5
#define VX_AUTOHOOK 1
#define VX_HIDEREG 1
#define VX_FPS 20
#define SCRIPT_URL @"https://raw.githubusercontent.com/lyvstoremx/VEEX-IPA/main/scripts/esp.lua"
extern int csops(pid_t, unsigned int, void *, size_t);
extern int csops_audittoken(pid_t, unsigned int, void *, size_t, uint32_t *);
#define VX_CS_OPS_STATUS 0
#define VX_CS_VALID 1
#define VX_CS_GET_TASK_ALLOW 4
#define VX_CS_HARD 0x100
#define VX_CS_DEBUGGED 0x10000000
#define VX_PFLAG_OFF 32
#define VX_P_TRACED 0x800
#define VX_PG 0x4000
static const char *VX_H = "00770007d45fe15664db57df30274f5c49daaa04f276be030f20686e673c833b";
static const char *VX_CD = "d9cf9ae60f2433bf47fe33a29d7122bb1bcc5965";
static const char *VX_MD5ID = "75ead73659249cdb3a0eee33e86c003a";
static const char *VX_TEAM = "98573T3W6L";
static const char *VX_APPID = "98573T3W6L.com.dts.freefireth";
static const char *VX_FAKE = "/usr/lib/libobjc.A.dylib";
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
static int gTab = 0, gOpen = 0;
static lua_State *gL = NULL;
static volatile int gRun = 0;
static uint64_t gBase = 0, gSize = 0, gMainHdr = 0;
static uint32_t gMyIdx = 0xFFFFFFFFu;
static uint64_t gSelfLo = 0, gSelfHi = 0;
static double gLastPb = 0;
static uint64_t gTextLo = 0, gTextHi = 0, gTextSz = 0;
static volatile int gHitMd5 = 0, gHitSha1 = 0, gHitSha256 = 0, gForced = 0;
static volatile int gBodies = 0, gPLok = 0;
static int gInstallTries = 0, gFails = 0, gHooked = 0;
static int gMapMode = 0;
static size_t gMapLeft = 0;
static uint8_t *gMapW = NULL, *gMapX = NULL;
static void (*p_icache)(void *, size_t) = NULL;
static int (*p_jitwp)(int) = NULL;
static uint8_t *gTrP[140];
static uint8_t *gTrW[140];
static int gTrV[140];
static int gTrN = 0;
static volatile uint64_t gB0A, gB0B, gB1A, gB1B, gB2A, gB2B, gB3A, gB3B;
static volatile uint64_t *gBInstr[4];
static volatile uint64_t *gBAddr[4];
static volatile int gBHN = 0;
static void vxFindSelf(void);
static void vxSelfRange(void);
static void vxHashSelf(void);
static void vxPatchLoadName(void);
static void vxPatchMainLoad(void);
static void vxInstallBody(void);
static void vxInstallHooks(void);
static void vxAuto(void);
static void vxCsLog(const char *tag);
static void vxBuildTab(void);
static void vxPatchCryptid(void);
static void vxKillAttest(void);
static void vxFingerprint(void);
static void vxRunScript(void);
static void vxStopScript(void);
static void vxResetGuest(void);
static void vxLoadIL2CPP(void);
static void vxFindImage(void);
static void vxFindUnityPath(void);
static void vxFieldSyms(void);
static int vxProtOf(void *p);
static int vxTrampPrep(uint8_t **out, void *target);
static int vxTrampExec(uint8_t *tr);
static int vxInlineHook(void *target, void *rep, void **origOut);
static int vxNearHook(void *target);
static int vxBadInstr(uint32_t in);
static void vxEmitAbs(uint32_t *w, uint64_t v);
static void vxSlotWrite(uint8_t *tr, const void *src, size_t n);
static void vxFlush(void *p, size_t n);
static void vxFlushPair(void *w, void *x, size_t n);
static void vxHookSym(const char *name, void *rep, void **origOut);
static void vxRegister(lua_State *L);
static NSString *vxStore(const char *n) {
    static NSString *dir = nil;
    if (!dir) {
        NSString *c = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        dir = c ? [c copy] : [gDocs copy];
    }
    return [dir stringByAppendingPathComponent:@(n)];
}
static void vxRaw(const char *fmt, ...) {
    FILE *f = fopen("/tmp/vx.log", "a");
    if (!f) return;
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap);
    fputc('\n', f); fflush(f); fclose(f);
}
static int vxInText(const void *p) { uint64_t a = (uint64_t)p; return (gTextLo && a >= gTextLo && a < gTextHi) ? 1 : 0; }
static void vxWriteSync(NSString *s) {
    if (!gDocs) return;
    NSString *p = vxStore("b.dat");
    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!f) { [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    [f seekToEndOfFile]; [f writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
    [f synchronizeFile]; [f closeFile];
}
static void vxKeep(NSString *s) {
    if (!gDocs) return;
    static const char *tags[] = {
        "=== build", "[VEEX] cs ", "[VEEX] cave", "[VEEX] gc", "[VEEX] amc", "[VEEX] prep",
        "[VEEX] tramp", "[VEEX] gcx", "[VEEX] xprot", "[VEEX] h1 ", "[VEEX] pm ", "[VEEX] slotx",
        "[VEEX] mp=", "[VEEX] patched", "[VEEX] revertido", "[VEEX] anonx", "[VEEX] sin tramp",
        "[VEEX] hooked", "[VEEX] w ", "[VEEX] wr", "[VEEX] xf", "[VEEX] xp=", "[VEEX] bh",
        "[VEEX] scr=", "[VEEX] AH", "[VEEX] PL", "[VEEX] b", "[VEEX] camuflaje", "[VEEX] HS",
        "[VEEX] VR", "[L] n=", "[L] m=", "[L] k=", "[L] cam=", "[L] f=", "[L] self=",
        "[L] stale", "[L] cam muerta"
    };
    const char *c = s.UTF8String;
    int hit = 0;
    for (unsigned i = 0; i < sizeof(tags) / sizeof(tags[0]); i++)
        if (!strncmp(c, tags[i], strlen(tags[i]))) { hit = 1; break; }
    if (!hit) return;
    NSString *p = vxStore("c.dat");
    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!f) { [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:NULL]; return; }
    [f seekToEndOfFile]; [f writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
    [f synchronizeFile]; [f closeFile];
}
static void vxLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    vxRaw("%s", s.UTF8String);
    if (!gLog) gLog = [NSMutableString new];
    [gLog appendString:s]; [gLog appendString:@"\n"];
    if (gLog.length > 20000) [gLog deleteCharactersInRange:NSMakeRange(0, gLog.length - 16000)];
    NSString *line = [s stringByAppendingString:@"\n"];
    vxWriteSync(line); vxKeep(line);
    double ahora = CFAbsoluteTimeGetCurrent();
    if (ahora - gLastPb > 0.4) {
        gLastPb = ahora;
        NSString *cp = [gLog copy];
        dispatch_async(dispatch_get_main_queue(), ^{ UIPasteboard.generalPasteboard.string = cp; });
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLogView) {
            gLogView.text = gLog;
            if (gLog.length) [gLogView scrollRangeToVisible:NSMakeRange(gLog.length - 1, 1)];
        }
    });
}
static void vxHex(const char *hex, unsigned char *out, int len) {
    for (int i = 0; i < len; i++) { unsigned v = 0; sscanf(hex + i * 2, "%2x", &v); out[i] = (unsigned char)v; }
}
static void vxToHex(const unsigned char *in, int len, char *out) {
    for (int i = 0; i < len; i++) sprintf(out + i * 2, "%02x", in[i]);
    out[len * 2] = 0;
}
__attribute__((used, section("__TEXT,__vxcave"))) static const uint8_t gCavePad[8192] = {0};
#define VX_SLOT 128
static void vxEmitAbs(uint32_t *w, uint64_t v) { w[0] = 0x58000050; w[1] = 0xD61F0200; memcpy(w + 2, &v, 8); }
static int vxEmitMovAbs(uint32_t *w, uint32_t rd, uint64_t v) {
    w[0] = 0xD2800000u | (uint32_t)((v & 0xFFFF) << 5) | rd;
    w[1] = 0xF2800000u | (1u << 21) | (uint32_t)(((v >> 16) & 0xFFFF) << 5) | rd;
    w[2] = 0xF2800000u | (2u << 21) | (uint32_t)(((v >> 32) & 0xFFFF) << 5) | rd;
    w[3] = 0xF2800000u | (3u << 21) | (uint32_t)(((v >> 48) & 0xFFFF) << 5) | rd;
    return 4;
}
static int vxReloc(uint32_t in, uint64_t at, uint32_t *out) {
    if ((in & 0x9F000000) == 0x10000000) {
        uint32_t rd = in & 0x1F;
        int64_t imm = (int64_t)((in >> 5) & 0x7FFFF);
        if (imm & 0x40000) imm |= ~0x7FFFFLL;
        return vxEmitMovAbs(out, rd, at + (uint64_t)imm);
    }
    if ((in & 0x9F000000) == 0x90000000) {
        uint32_t rd = in & 0x1F;
        int64_t imm = (int64_t)((in >> 5) & 0x7FFFF);
        if (imm & 0x40000) imm |= ~0x7FFFFLL;
        return vxEmitMovAbs(out, rd, (at & ~0xFFFULL) + ((uint64_t)imm << 12));
    }
    out[0] = in;
    return 1;
}
static void vxFlush(void *p, size_t n) {
    uint64_t a = (uint64_t)p & ~(uint64_t)15, e = ((uint64_t)p + n + 15) & ~(uint64_t)15;
    for (uint64_t x = a; x < e; x += 16) __asm__ volatile("dc cvau, %0" :: "r"(x) : "memory");
    __asm__ volatile("dsb ish" ::: "memory");
    for (uint64_t x = a; x < e; x += 16) __asm__ volatile("ic ivau, %0" :: "r"(x) : "memory");
    __asm__ volatile("dsb ish" ::: "memory");
    __asm__ volatile("isb" ::: "memory");
    if (p_icache) p_icache(p, n);
}
static void vxFlushPair(void *w, void *x, size_t n) {
    uint64_t a = (uint64_t)w & ~(uint64_t)15, e = ((uint64_t)w + n + 15) & ~(uint64_t)15;
    for (uint64_t q = a; q < e; q += 16) __asm__ volatile("dc cvau, %0" :: "r"(q) : "memory");
    __asm__ volatile("dsb ish" ::: "memory");
    uint64_t a2 = (uint64_t)x & ~(uint64_t)15, e2 = ((uint64_t)x + n + 15) & ~(uint64_t)15;
    for (uint64_t q = a2; q < e2; q += 16) __asm__ volatile("ic ivau, %0" :: "r"(q) : "memory");
    __asm__ volatile("dsb ish" ::: "memory");
    __asm__ volatile("isb" ::: "memory");
}
static void vxCall(void *fn, void *a1) {
    __asm__ volatile("mov x0, %1\nblr %0\n" :: "r"(fn), "r"(a1)
        : "x0","x1","x2","x3","x4","x5","x6","x7","x8","x9","x10","x11","x12","x13","x14","x15","x16","x17","x18","x30","memory");
}
static int vxProtOf(void *p) {
    vm_address_t a = (vm_address_t)p & ~(vm_address_t)(VX_PG - 1);
    vm_size_t sz = 0;
    vm_region_basic_info_data_64_t info;
    mach_port_t obj = MACH_PORT_NULL;
    mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
    if (vm_region_64(mach_task_self(), &a, &sz, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj) != KERN_SUCCESS) return -1;
    return (int)info.protection;
}
static int vxMapTry(const char *path, uint64_t off, int shared, int initw, int how, uint8_t **outCave, void **outBase, size_t *outLen) {
    uint64_t pa = off & ~(uint64_t)(VX_PG - 1);
    size_t delta = (size_t)(off - pa), len = (size_t)VX_PG * 2;
    int prot = PROT_READ | PROT_EXEC | (initw ? PROT_WRITE : 0);
    int flags = shared ? MAP_SHARED : MAP_PRIVATE;
    uint32_t nop = 0xD503201F;
    const int rwx = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE;
    int fd = open(path, O_RDONLY);
    if (fd < 0) { vxLog(@"[VEEX] t%d open=%d e=%d", how, fd, errno); return -1; }
    void *p = mmap(NULL, len, prot, flags, fd, (off_t)pa);
    int em = errno;
    vxLog(@"[VEEX] t%d sh=%d iw=%d p=%p e=%d", how, shared, initw, p, em);
    if (p == MAP_FAILED) { close(fd); return -1; }
    uint8_t *c = (uint8_t *)p + delta;
    int p0 = vxProtOf(c);
    if (how == 1) {
        kern_return_t k1 = vm_protect(mach_task_self(), (vm_address_t)p, (vm_size_t)len, TRUE, rwx);
        kern_return_t k2 = vm_protect(mach_task_self(), (vm_address_t)p, (vm_size_t)len, FALSE, rwx);
        vxLog(@"[VEEX] t%d p0=%x techo=%d act=%d", how, p0, (int)k1, (int)k2);
    } else if (how == 2) {
        int r = mprotect(p, len, PROT_READ | PROT_WRITE | PROT_EXEC);
        vxLog(@"[VEEX] t%d p0=%x mp=%d", how, p0, r);
    } else vxLog(@"[VEEX] t%d p0=%x", how, p0);
    int p1 = vxProtOf(c);
    if (!(p1 & VM_PROT_WRITE)) {
        int r = mprotect(p, len, PROT_READ | PROT_WRITE | PROT_EXEC);
        int pm = vxProtOf(c);
        vxLog(@"[VEEX] t%d p1=%x reb=%d pm=%x", how, p1, r, pm);
        p1 = pm;
        if (!(p1 & VM_PROT_WRITE)) { munmap(p, len); close(fd); return -1; }
    }
    memcpy(c, &nop, 4);
    int p2 = vxProtOf(c);
    vxLog(@"[VEEX] t%d esc=%x tras=%x", how, p1, p2);
    if (!(p2 & VM_PROT_EXECUTE)) {
        vm_protect(mach_task_self(), (vm_address_t)p, (vm_size_t)len, FALSE, rwx);
        int p3 = vxProtOf(c);
        vxLog(@"[VEEX] t%d reaf=%x", how, p3);
        if (!(p3 & VM_PROT_EXECUTE)) { munmap(p, len); close(fd); return -1; }
    }
    close(fd);
    *outCave = c; *outBase = p; *outLen = len;
    return 0;
}
static int vxMapPair(const char *path, uint64_t off) {
    uint8_t *cave = NULL; void *base = NULL; size_t len = 0;
    if (vxMapTry(path, off, 0, 0, 1, &cave, &base, &len) == 0) goto ok;
    if (vxMapTry(path, off, 0, 1, 1, &cave, &base, &len) == 0) goto ok;
    if (vxMapTry(path, off, 1, 0, 1, &cave, &base, &len) == 0) goto ok;
    if (vxMapTry(path, off, 0, 0, 2, &cave, &base, &len) == 0) goto ok;
    vxLog(@"[VEEX] rwx sin cueva");
    return -1;
ok:
    { uint8_t t = cave[0]; cave[0] = 0xA5; vxLog(@"[VEEX] rwx cueva=%p refl=%x prot=%x", cave, cave[0], vxProtOf(cave));
      if (cave[0] != 0xA5) { cave[0] = t; munmap(base, len); return -1; } cave[0] = t; }
    gMapW = cave; gMapX = cave; gMapLeft = 8192;
    return 3;
}
static int vxCaveMap(void) {
    if (gMapMode) return gMapMode;
    gMapMode = -1;
    Dl_info di;
    if (!dladdr((void *)gCavePad, &di) || !di.dli_fbase || !di.dli_fname) { vxLog(@"[VEEX] map sin dladdr"); return -1; }
    const struct mach_header_64 *h = (const struct mach_header_64 *)di.dli_fbase;
    const struct load_command *lc = (const struct load_command *)(h + 1);
    uint64_t tv = 0; int tfound = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { tv = sg->vmaddr; tfound = 1; break; }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
    if (!tfound) { vxLog(@"[VEEX] map sin text"); return -1; }
    uint64_t slide = (uint64_t)h - tv;
    lc = (const struct load_command *)(h + 1);
    uint64_t off = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
            const struct section_64 *s = (const struct section_64 *)(sg + 1);
            for (uint32_t k = 0; k < sg->nsects; k++)
                if (!strcmp(s[k].sectname, "__vxcave")) {
                    uint64_t ra = slide + sg->vmaddr + s[k].addr;
                    off = (uint64_t)s[k].offset + ((uint64_t)gCavePad - ra);
                    break;
                }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
    if (!off) { vxLog(@"[VEEX] map sin seccion"); return -1; }
    int r = vxMapPair(di.dli_fname, off);
    return r > 0 ? r : -1;
}
static int vxTrVia(uint8_t *tr) { for (int i = 0; i < gTrN; i++) if (gTrP[i] == tr) return gTrV[i]; return -1; }
static void vxSlotWrite(uint8_t *tr, const void *src, size_t n) {
    if (vxTrVia(tr) == 6) {
        for (int i = 0; i < gTrN; i++)
            if (gTrP[i] == tr) { memcpy(gTrW[i] + (size_t)(tr - gTrP[i]), src, n); return; }
    }
    memcpy(tr, src, n);
}
typedef struct { uint64_t lo, hi; } vxSeg;
static int vxSegs(uint64_t t, vxSeg *out, int cap) {
    int n = 0;
    vm_address_t a; vm_size_t s; mach_msg_type_number_t c; mach_port_t ob;
    vm_region_basic_info_data_64_t bi;
    a = t; s = 0; c = VM_REGION_BASIC_INFO_COUNT_64;
    if (vm_region_64(mach_task_self(), &a, &s, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&bi, &c, &ob) != KERN_SUCCESS) return 0;
    if (!(bi.protection & VM_PROT_EXECUTE)) { vxLog(@"[VEEX] gc no exec"); return 0; }
    out[n].lo = a; out[n].hi = a + s; n++;
    uint64_t bl = a, bh = a + s;
    a = bh;
    while (n < cap && a < bl + 0x800000) {
        s = 0; c = VM_REGION_BASIC_INFO_COUNT_64;
        if (vm_region_64(mach_task_self(), &a, &s, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&bi, &c, &ob) != KERN_SUCCESS) break;
        if (!(bi.protection & VM_PROT_EXECUTE)) break;
        if (a + s > bl + 0x800000) s = bl + 0x800000 - a;
        out[n].lo = a; out[n].hi = a + s; n++;
        a = a + s;
    }
    a = (bl > 0x800000) ? bl - 0x800000 : 0;
    while (n < cap && a < bl) {
        s = 0; c = VM_REGION_BASIC_INFO_COUNT_64;
        if (vm_region_64(mach_task_self(), &a, &s, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&bi, &c, &ob) != KERN_SUCCESS) break;
        if (!(bi.protection & VM_PROT_EXECUTE)) break;
        out[n].lo = a; out[n].hi = a + s; n++;
        a = a + s;
    }
    return n;
}
static uint8_t *vxFindCave(void *target) {
    uint64_t t = (uint64_t)target;
    Dl_info di; memset(&di, 0, sizeof di);
    if (dladdr((void *)t, &di) == 0 || di.dli_fbase == NULL) { vxLog(@"[VEEX] gc sin img"); return NULL; }
    vxSeg seg[32];
    int n = vxSegs(t, seg, 32);
    vxLog(@"[VEEX] gc segs=%d", n);
    if (n == 0) return NULL;
    static const int needs[3] = { 64, 48, 32 };
    uint64_t best = 0, bat = 0; int bk = 0;
    for (int ni = 0; ni < 3; ni++) {
        int need = needs[ni];
        for (int pass = 1; pass <= 2; pass++) {
            uint32_t pat = (pass == 1) ? 0xD503201Fu : 0u;
            for (int i = 0; i < n; i++) {
                uint64_t s = (seg[i].lo + 0x10) & ~3ULL, e = seg[i].hi;
                for (uint64_t a = s; a + (uint64_t)need <= e; a += 4) {
                    if (a < t + 16 && a + (uint64_t)need > t) continue;
                    if (*(volatile uint32_t *)a != pat) continue;
                    uint64_t run = 4, b = a + 4;
                    while (run < 64 && b + 4 <= e && *(volatile uint32_t *)b == pat) { run += 4; b += 4; }
                    if (run > best) { best = run; bat = a; bk = pass; }
                    if (run >= (uint64_t)need) {
                        vxLog(@"[VEEX] gc hit=%p need=%d k=%d r=%llu", (void *)a, need, pass, (unsigned long long)run);
                        return (uint8_t *)a;
                    }
                }
            }
        }
    }
    vxLog(@"[VEEX] gc nada best=%llu at=%p k=%d", (unsigned long long)best, (void *)bat, bk);
    return NULL;
}
static int vxCaveGame(void *target, uint8_t **out) {
    uint8_t *c = vxFindCave(target);
    if (!c) return -17;
    uint64_t pg = (uint64_t)c & ~(uint64_t)(VX_PG - 1);
    uint64_t endp = ((uint64_t)c + 64 + VX_PG - 1) & ~(uint64_t)(VX_PG - 1);
    size_t span = (size_t)(endp - pg);
    kern_return_t k0 = vm_protect(mach_task_self(), pg, span, TRUE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
    int mp = mprotect((void *)pg, span, PROT_READ | PROT_WRITE | PROT_EXEC);
    int p1 = vxProtOf(c);
    vxLog(@"[VEEX] gc k0=%d mp=%d p1=%x", (int)k0, mp, p1);
    if (!(p1 & VM_PROT_WRITE)) {
        vm_protect(mach_task_self(), pg, span, TRUE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        vm_protect(mach_task_self(), pg, span, FALSE, VM_PROT_READ | VM_PROT_WRITE);
        p1 = vxProtOf(c);
        if (!(p1 & VM_PROT_WRITE)) return -19;
    }
    *out = c;
    return 0;
}
static int vxTrampPrep(uint8_t **out, void *target) {
    if (gTrN >= 140) return -9;
    uint8_t *tr = NULL; int via = -1;
    if (target) {
        int r = vxCaveGame(target, &tr);
        vxLog(@"[VEEX] gcr=%d", r);
        if (r == 0) via = 9; else tr = NULL;
    }
    if (!tr) {
        vm_size_t pgs = (vm_size_t)VX_PG;
        const int rwx3 = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE;
        void *m = mmap(NULL, pgs, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
        if (m != MAP_FAILED) {
            vm_protect(mach_task_self(), (vm_address_t)m, pgs, TRUE, rwx3);
            vm_protect(mach_task_self(), (vm_address_t)m, pgs, FALSE, rwx3 | VM_PROT_COPY);
            int p = vxProtOf(m);
            vxLog(@"[VEEX] amc p=%x", p);
            if ((p & VM_PROT_WRITE) && (p & VM_PROT_EXECUTE)) { tr = (uint8_t *)m; via = 8; }
            else munmap(m, pgs);
        }
    }
    if (!tr) {
        vm_size_t pgs = (vm_size_t)VX_PG;
        void *m = mmap(NULL, pgs, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
        if (m != MAP_FAILED) {
            int p = vxProtOf(m);
            vxLog(@"[VEEX] anonx p=%x", p);
            if (p & VM_PROT_EXECUTE) { tr = (uint8_t *)m; via = 5; }
            else munmap(m, pgs);
        }
    }
    if (!tr && !gMapMode) {
        int r = vxCaveMap();
        vxLog(@"[VEEX] pair r=%d", r);
        if (r > 0 && gMapLeft >= VX_SLOT) {
            uint8_t *x = gMapX, *w = gMapW;
            memset(w, 0, VX_SLOT);
            gMapX += VX_SLOT; gMapW += VX_SLOT; gMapLeft -= VX_SLOT;
            tr = x; via = 6;
        }
    }
    if (!tr) { vxLog(@"[VEEX] sin tramp"); return -11; }
    gTrP[gTrN] = tr; gTrW[gTrN] = tr; gTrV[gTrN] = via; gTrN++;
    *out = tr;
    vxLog(@"[VEEX] tramp=%p via=%d", tr, via);
    return 0;
}
static int vxTrampExec(uint8_t *tr) {
    int via = vxTrVia(tr);
    if (via == 6) {
        uint8_t *w = tr;
        for (int i = 0; i < gTrN; i++) if (gTrP[i] == tr) { w = gTrW[i]; break; }
        vxFlushPair(w, tr, VX_SLOT);
        int p6 = vxProtOf(tr);
        return (p6 & VM_PROT_EXECUTE) ? 0 : -12;
    }
    vxFlush(tr, VX_SLOT);
    if (via == 2) { if (p_jitwp) p_jitwp(1); return 0; }
    int p = vxProtOf(tr);
    if (p & VM_PROT_EXECUTE) { if (p_jitwp) p_jitwp(1); return 0; }
    uint64_t pg = (uint64_t)tr & ~(VX_PG - 1);
    mprotect((void *)pg, VX_PG, PROT_READ | PROT_EXEC);
    p = vxProtOf(tr);
    if (!(p & VM_PROT_EXECUTE)) {
        vm_protect(mach_task_self(), pg, VX_PG, TRUE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
        vm_protect(mach_task_self(), pg, VX_PG, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
        mprotect((void *)pg, VX_PG, PROT_READ | PROT_EXEC);
        vxFlush(tr, VX_SLOT);
        p = vxProtOf(tr);
    }
    if (p_jitwp) p_jitwp(1);
    vxLog(@"[VEEX] xp=%x", p);
    return (p & VM_PROT_EXECUTE) ? 0 : -12;
}
static int vxBadInstr(uint32_t in) {
    if ((in & 0x7C000000) == 0x14000000) return 1;
    if ((in & 0xFC000000) == 0x94000000) return 1;
    if ((in & 0xFF000010) == 0x54000000) return 1;
    if ((in & 0x7E000000) == 0x34000000) return 1;
    if ((in & 0x7E000000) == 0x36000000) return 1;
    if ((in & 0x3B000000) == 0x18000000) return 1;
    return 0;
}
static int vxInlineHook(void *target, void *rep, void **origOut) {
    if (!target || !rep || !origOut) return -1;
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
    vxLog(@"[VEEX] w %08x %08x %08x %08x", t[0], t[1], t[2], t[3]);
    for (int i = 0; i < 4; i++) if (vxBadInstr(t[i])) return -2 - i;
    uint32_t orig[4];
    memcpy(orig, t, 16);
    uint8_t *tr = NULL;
    int pr = vxTrampPrep(&tr, target);
    if (pr != 0) return pr;
    uint32_t buf[40], *w = buf;
    for (int i = 0; i < 4; i++) w += vxReloc(t[i], (uint64_t)target + (uint64_t)i * 4, w);
    vxEmitAbs(w, (uint64_t)target + 16);
    size_t blen = (size_t)((uint8_t *)w - (uint8_t *)buf);
    uint32_t sb[4];
    vxEmitAbs(sb, (uint64_t)rep);
    if (blen + 16 > VX_SLOT) return -26;
    vxSlotWrite(tr, buf, blen);
    vxSlotWrite(tr + blen, sb, 16);
    uint64_t start = (uint64_t)target & ~(VX_PG - 1);
    uint64_t endp = ((uint64_t)target + 16 + VX_PG - 1) & ~(VX_PG - 1);
    size_t span = (size_t)(endp - start);
    if (span < VX_PG) span = VX_PG;
    vm_protect(mach_task_self(), start, span, TRUE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
    int mp = mprotect((void *)start, span, PROT_READ | PROT_WRITE | PROT_EXEC);
    if (mp != 0) {
        if (vm_protect(mach_task_self(), start, span, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) return -10;
    }
    uint32_t patch[4];
    patch[0] = 0x58000050; patch[1] = 0xD61F0200;
    memcpy(patch + 2, &tr, 8);
    memcpy(t, patch, 16);
    vxFlush(t, 16);
    int x1 = vxTrampExec(tr);
    if (x1 != 0) { memcpy(t, orig, 16); vxFlush(t, 16); vxLog(@"[VEEX] revertido"); return x1; }
    *origOut = tr;
    vxLog(@"[VEEX] patched %08x", t[0]);
    return 0;
}
static void vxHookName(const char *name, void *rep, void **origOut) {
    void *h = dlopen(NULL, RTLD_NOW);
    void *t = h ? dlsym(h, name) : NULL;
    if (!t) { vxLog(@"[VEEX] !%@", @(name)); return; }
    int r = vxInlineHook(t, rep, origOut);
    if (r == 0) gHooked++;
    vxLog(@"[VEEX] %@ %@ (%d)", r == 0 ? @"+" : @"!", @(name), r);
}
static uint32_t (*r_count)(void) = NULL;
static const void *(*r_hdr)(uint32_t) = NULL;
static intptr_t (*r_slide)(uint32_t) = NULL;
static void vxHookSym(const char *name, void *rep, void **origOut) {
    void *keep = *origOut;
    *origOut = NULL;
    if (!r_count || !r_hdr || !r_slide) { *origOut = keep; vxLog(@"[VEEX] b!%@ sin dyld", @(name)); return; }
    void *target = dlsym(RTLD_DEFAULT, name);
    if (!target) { *origOut = keep; vxLog(@"[VEEX] b!%@ sin dlsym", @(name)); return; }
    uint32_t n = r_count();
    vxLog(@"[VEEX] b>%@ %p imgs=%u", @(name), target, n);
    int hits = 0, blk = 0;
    for (uint32_t i = 0; i < n; i++) {
        const struct mach_header_64 *h = (const struct mach_header_64 *)r_hdr(i);
        if (!h || h->magic != MH_MAGIC_64) continue;
        intptr_t slide = r_slide(i);
        const struct load_command *lc = (const struct load_command *)(h + 1);
        for (uint32_t k = 0; k < h->ncmds; k++) {
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
                const struct section_64 *s = (const struct section_64 *)(sg + 1);
                for (uint32_t j = 0; j < sg->nsects; j++) {
                    uint32_t t = s[j].flags & SECTION_TYPE;
                    if (t != S_LAZY_SYMBOL_POINTERS && t != S_NON_LAZY_SYMBOL_POINTERS) continue;
                    if (!s[j].size || s[j].addr < 0x1000) continue;
                    void **pt = (void **)((uintptr_t)slide + (uintptr_t)s[j].addr);
                    size_t cnt = s[j].size / sizeof(void *);
                    if (cnt > 20000) cnt = 20000;
                    for (size_t q = 0; q < cnt; q++) {
                        if (pt[q] != target) continue;
                        uint64_t pg = (uint64_t)&pt[q] & ~(uint64_t)(VX_PG - 1);
                        int pr = vxProtOf((void *)pg);
                        if (!(pr & VM_PROT_WRITE)) {
                            int r = mprotect((void *)pg, VX_PG, PROT_READ | PROT_WRITE);
                            int p2 = vxProtOf((void *)pg);
                            if (r != 0 || !(p2 & VM_PROT_WRITE)) {
                                vm_protect(mach_task_self(), pg, VX_PG, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                                p2 = vxProtOf((void *)pg);
                                if (!(p2 & VM_PROT_WRITE)) { blk++; continue; }
                            }
                        }
                        if (!*origOut) *origOut = pt[q];
                        pt[q] = rep;
                        hits++;
                        vxLog(@"[VEEX] b +%u:%s@%p", i, s[j].sectname, &pt[q]);
                    }
                }
            }
            lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
        }
    }
    vxLog(@"[VEEX] b<%@ hits=%d blk=%d old=%p", @(name), hits, blk, *origOut);
    if (!*origOut) *origOut = keep;
    if (hits) gHooked++;
}
static unsigned char *(*o_md5)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *(*o_sha1)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *(*o_sha256)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *h_md5(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_md5 ? o_md5(d, len, md) : NULL;
    gHitMd5++;
    if (r && md && d && len >= 8 && len <= 64) {
        const unsigned char *b = (const unsigned char *)d;
        int ok = 1;
        for (CC_LONG i = 0; i < len; i++) if (b[i] < 0x20 || b[i] > 0x7E) { ok = 0; break; }
        if (ok) { vxHex(VX_MD5ID, md, 16); gForced++; }
    }
    return r;
}
static unsigned char *h_sha1(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_sha1 ? o_sha1(d, len, md) : NULL;
    gHitSha1++;
    if (r && md && len > 20) {
        const unsigned char *b = (const unsigned char *)d;
        if (b[0] == 0xfa && b[1] == 0xde && b[2] == 0x0c && b[3] == 0x02) { vxHex(VX_CD, md, 20); gForced++; }
    }
    return r;
}
static unsigned char *h_sha256(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_sha256 ? o_sha256(d, len, md) : NULL;
    gHitSha256++;
    if (r && md && (vxInText(d) ? (len >= 0x1000) : (gTextSz && (uint64_t)len == gTextSz))) { vxHex(VX_H, md, 32); gForced++; }
    return r;
}
static uint32_t (*o_dyld_image_count)(void) = NULL;
static const char *(*o_dyld_get_image_name)(uint32_t) = NULL;
static const void *(*o_dyld_get_image_header)(uint32_t) = NULL;
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
static kern_return_t (*o_vr64)(vm_map_t, vm_address_t *, vm_size_t *, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *) = NULL;
static kern_return_t (*o_mvr)(vm_map_t, uint64_t *, uint64_t *, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *) = NULL;
static kern_return_t h_vr64(vm_map_t t, vm_address_t *a, vm_size_t *s, vm_region_flavor_t f, vm_region_info_t inf, mach_msg_type_number_t *c, mach_port_t *ob) {
    kern_return_t r = o_vr64(t, a, s, f, inf, c, ob);
    for (int k = 0; r == KERN_SUCCESS && gSelfHi && k < 6; k++) {
        uint64_t lo = *a, hi = lo + *s;
        if (hi <= gSelfLo || lo >= gSelfHi) break;
        *a = (vm_address_t)(hi > gSelfHi ? hi : gSelfHi);
        r = o_vr64(t, a, s, f, inf, c, ob);
    }
    return r;
}
static kern_return_t h_mvr(vm_map_t t, uint64_t *a, uint64_t *s, vm_region_flavor_t f, vm_region_info_t inf, mach_msg_type_number_t *c, mach_port_t *ob) {
    kern_return_t r = o_mvr(t, a, s, f, inf, c, ob);
    for (int k = 0; r == KERN_SUCCESS && gSelfHi && k < 6; k++) {
        uint64_t lo = *a, hi = lo + *s;
        if (hi <= gSelfLo || lo >= gSelfHi) break;
        *a = (hi > gSelfHi ? hi : gSelfHi);
        r = o_mvr(t, a, s, f, inf, c, ob);
    }
    return r;
}
static int (*o_csops)(pid_t, unsigned int, void *, size_t) = NULL;
static int h_csops(pid_t p, unsigned int op, void *u, size_t s) {
    int r = o_csops ? o_csops(p, op, u, s) : -1;
    if (r == 0 && op == VX_CS_OPS_STATUS && u && s >= 4) {
        uint32_t f = *(uint32_t *)u;
        f &= ~VX_CS_DEBUGGED;
        f |= VX_CS_VALID | VX_CS_GET_TASK_ALLOW | VX_CS_HARD;
        *(uint32_t *)u = f;
    }
    return r;
}
static int (*o_csaudit)(pid_t, unsigned int, void *, size_t, uint32_t *) = NULL;
static int h_csaudit(pid_t p, unsigned int op, void *u, size_t s, uint32_t *tk) {
    int r = o_csaudit ? o_csaudit(p, op, u, s, tk) : csops(p, op, u, s);
    if (r == 0 && op == VX_CS_OPS_STATUS && u && s >= 4) {
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
    if (r == 0 && o && ol && *ol >= VX_PFLAG_OFF + 4 && n && l == 4 &&
        n[0] == CTL_KERN && n[1] == KERN_PROC && n[2] == KERN_PROC_PID) {
        uint32_t f = *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF);
        *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF) = f & ~VX_P_TRACED;
    }
    return r;
}
static int (*o_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;
static int h_sysctlbyname(const char *nm, void *o, size_t *ol, void *nw, size_t nl) {
    int r = o_sysctlbyname ? o_sysctlbyname(nm, o, ol, nw, nl) : -1;
    if (r == 0 && o && ol && *ol >= VX_PFLAG_OFF + 4 && nm && !strcmp(nm, "kern.proc.pid")) {
        uint32_t f = *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF);
        *(uint32_t *)((uint8_t *)o + VX_PFLAG_OFF) = f & ~VX_P_TRACED;
    }
    return r;
}
#define VXH(nm, fn, orig) do { vxHookSym(nm, (void *)(fn), (void **)&orig); if (!orig) { gFails++; vxLog(@"[VEEX] miss %@", @(nm)); } } while (0)
static void vxCsLog(const char *tag) {
    uint32_t st = 0;
    int r = csops(getpid(), VX_CS_OPS_STATUS, &st, sizeof st);
    vxLog(@"[VEEX] cs %s r=%d st=%x", tag, r, st);
}
static void vxInstallHooks(void) {
    if (gInstallTries >= 2) return;
    gInstallTries++;
    if (!p_icache) p_icache = (void (*)(void *, size_t))dlsym(RTLD_DEFAULT, "sys_icache_invalidate");
    if (!r_count) r_count = (uint32_t (*)(void))dlsym(RTLD_DEFAULT, "_dyld_image_count");
    if (!r_hdr) r_hdr = (const void *(*)(uint32_t))dlsym(RTLD_DEFAULT, "_dyld_get_image_header");
    if (!r_slide) r_slide = (intptr_t (*)(uint32_t))dlsym(RTLD_DEFAULT, "_dyld_get_image_vmaddr_slide");
    vxCsLog("pre");
#if VX_HOOKSET >= 1
    VXH("CC_MD5", h_md5, o_md5);
    VXH("CC_SHA1", h_sha1, o_sha1);
    VXH("CC_SHA256", h_sha256, o_sha256);
#endif
#if VX_HOOKSET >= 3
    VXH("_dyld_image_count", h_dyld_image_count, o_dyld_image_count);
    VXH("_dyld_get_image_name", h_dyld_get_image_name, o_dyld_get_image_name);
    VXH("_dyld_get_image_header", h_dyld_get_image_header, o_dyld_get_image_header);
#endif
#if VX_HOOKSET >= 4
    VXH("sysctlbyname", h_sysctlbyname, o_sysctlbyname);
    VXH("sysctl", h_sysctl, o_sysctl);
#endif
#if VX_HOOKSET >= 5
    VXH("csops", h_csops, o_csops);
    VXH("csops_audittoken", h_csaudit, o_csaudit);
#endif
#if VX_HIDEREG
    VXH("vm_region_64", h_vr64, o_vr64);
    VXH("vm_region", h_vr64, o_vr64);
    VXH("mach_vm_region", h_mvr, o_mvr);
#endif
    if (!gMainHdr) gMainHdr = (uint64_t)_dyld_get_image_header(0);
    vxLog(@"[VEEX] hooked=%d fails=%d try=%d", gHooked, gFails, gInstallTries);
}
static void vxFindSelf(void) {
    Dl_info di;
    if (!dladdr((void *)vxFindSelf, &di) || !di.dli_fbase) return;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++)
        if (_dyld_get_image_header(i) == di.dli_fbase) { gMyIdx = i; return; }
}
static void vxSelfRange(void) {
    if (!gMyIdx || gMyIdx == 0xFFFFFFFFu) return;
    const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(gMyIdx);
    if (!h) return;
    const struct load_command *lc = (const struct load_command *)(h + 1);
    uint64_t tv = 0, lo = 0, hi = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
            if (!strcmp(sg->segname, "__TEXT")) tv = sg->vmaddr;
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
    uint64_t slide = (uint64_t)h - tv;
    lc = (const struct load_command *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
            if (sg->vmsize) {
                uint64_t s = slide + sg->vmaddr;
                if (!lo || s < lo) lo = s;
                if (s + sg->vmsize > hi) hi = s + sg->vmsize;
            }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
    gSelfLo = lo; gSelfHi = hi;
    vxLog(@"[VEEX] VR rango %llx-%llx", lo, hi);
}
static void vxPatchLoadName(void) {
    if (!gMyIdx || gMyIdx == 0xFFFFFFFFu) return;
    const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(gMyIdx);
    if (!h) return;
    const struct load_command *lc = (const struct load_command *)(h + 1);
    uint32_t fakeLen = (uint32_t)strlen(VX_FAKE) + 1;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_ID_DYLIB) {
            struct dylib_command *dc = (struct dylib_command *)lc;
            char *nm = (char *)dc + dc->dylib.name.offset;
            uint32_t cur = (uint32_t)strlen(nm);
            if (cur >= fakeLen) {
                uint64_t pg = (uint64_t)nm & ~(VX_PG - 1);
                vm_protect(mach_task_self(), pg, (size_t)VX_PG, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                memset(nm, 0, cur);
                memcpy(nm, VX_FAKE, fakeLen);
                vxLog(@"[VEEX] id_dylib camuflado");
            }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
}
static void vxPatchMainLoad(void) {
    if (!gMainHdr) { vxLog(@"[VEEX] PL sin main"); return; }
    struct mach_header_64 *h = (struct mach_header_64 *)gMainHdr;
    if (h->magic != MH_MAGIC_64) { vxLog(@"[VEEX] PL magic=%x", h->magic); return; }
    if (h->ncmds > 4096) { vxLog(@"[VEEX] PL ncmds=%u", h->ncmds); return; }
    const char *base = "libAudioEngine.dylib";
    Dl_info me;
    if (dladdr((void *)vxPatchMainLoad, &me) && me.dli_fname) {
        const char *sl = strrchr(me.dli_fname, '/');
        if (sl && sl[1]) base = sl + 1;
    }
    uint32_t fakeLen = (uint32_t)strlen(VX_FAKE) + 1;
    uint8_t *p = (uint8_t *)h + sizeof(*h);
    int n = 0, fits = 0, nofit = 0, ya = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        struct load_command *lc = (struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command)) break;
        if (lc->cmd == LC_LOAD_DYLIB || lc->cmd == LC_LOAD_WEAK_DYLIB) {
            struct dylib_command *dc = (struct dylib_command *)lc;
            char *nm = (char *)dc + dc->dylib.name.offset;
            uint32_t cur = (uint32_t)strlen(nm);
            if (!strstr(nm, base)) { p += lc->cmdsize; continue; }
            n++;
            if (!strcmp(nm, VX_FAKE)) {
                ya++;
                vxLog(@"[VEEX] PL i=%u ya era %s", i, nm);
                p += lc->cmdsize;
                continue;
            }
            if (cur + 1 >= fakeLen) {
                char repl[64];
                memset(repl, 0, sizeof repl);
                memcpy(repl, VX_FAKE, fakeLen);
                uint64_t pg = (uint64_t)nm & ~(uint64_t)(VX_PG - 1);
                vm_protect(mach_task_self(), pg, (size_t)VX_PG * 2, false,
                           VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                char tmp[256];
                snprintf(tmp, sizeof tmp, "%s", nm);
                memcpy(nm, repl, fakeLen);
                fits++; gPLok = 1;
                vxLog(@"[VEEX] PL i=%u %s -> %s", i, tmp, VX_FAKE);
            } else {
                nofit++;
                vxLog(@"[VEEX] PL i=%u no cabe %u<%u", i, cur, fakeLen);
            }
        }
        p += lc->cmdsize;
    }
    vxLog(@"[VEEX] PL n=%d ok=%d ya=%d nc=%d base=%s", n, fits, ya, nofit, base);
}
static void vxHashSelf(void) {
    if (!gMainHdr) { vxLog(@"[VEEX] HS sin main"); return; }
    struct mach_header_64 *h = (struct mach_header_64 *)gMainHdr;
    struct load_command *lc = (struct load_command *)(h + 1);
    uint64_t off = 0, sz = 0;
    uint32_t sigOff = 0, sigSz = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *sg = (struct segment_command_64 *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { off = sg->fileoff; sz = sg->filesize; }
        } else if (lc->cmd == LC_CODE_SIGNATURE) {
            struct linkedit_data_command *ld = (struct linkedit_data_command *)lc;
            sigOff = ld->dataoff; sigSz = ld->datasize;
        }
        lc = (struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
    if (!sz) { vxLog(@"[VEEX] HS sin text"); return; }
    NSString *exe = [[NSBundle mainBundle] executablePath];
    int fd = open(exe.UTF8String, O_RDONLY);
    if (fd < 0) { vxLog(@"[VEEX] HS open=%d", errno); return; }
    CC_SHA256_CTX c256;
    CC_SHA256_Init(&c256);
    uint8_t *buf = malloc(262144);
    uint64_t done = 0;
    while (buf && done < sz) {
        size_t want = (size_t)((sz - done) > 262144 ? 262144 : (sz - done));
        ssize_t r = read(fd, buf, want);
        if (r <= 0) break;
        CC_SHA256_Update(&c256, buf, (CC_LONG)r);
        done += (uint64_t)r;
    }
    unsigned char md[32];
    CC_SHA256_Final(md, &c256);
    char hx[80];
    vxToHex(md, 32, hx);
    vxLog(@"[VEEX] HS h=%s esp=%s %s", hx, VX_H, strcmp(hx, VX_H) ? "NO" : "SI");
    if (sigOff && sigSz && sigSz < 262144) {
        uint8_t *sb = malloc(sigSz);
        if (sb && pread(fd, sb, sigSz, (off_t)sigOff) == (ssize_t)sigSz) {
            uint32_t magic = *(uint32_t *)sb;
            if (magic == 0xfade0cc0 && sigSz >= 12) {
                uint32_t cnt = *(uint32_t *)(sb + 8);
                uint32_t boff = 0, blen = 0;
                for (uint32_t k = 0; k < cnt && 12 + (k + 1) * 8 <= sigSz; k++) {
                    uint32_t ty = *(uint32_t *)(sb + 12 + k * 8);
                    uint32_t of = *(uint32_t *)(sb + 16 + k * 8);
                    if (ty == 0 && of + 8 <= sigSz) { boff = of; blen = *(uint32_t *)(sb + of + 4); break; }
                }
                if (boff && blen && boff + blen <= sigSz && *(uint32_t *)(sb + boff) == 0xfade0c02) {
                    unsigned char cd[20];
                    CC_SHA1(sb + boff, blen, cd);
                    char cx[60];
                    vxToHex(cd, 20, cx);
                    vxLog(@"[VEEX] HS cd=%s esp=%s %s", cx, VX_CD, strcmp(cx, VX_CD) ? "NO" : "SI");
                } else vxLog(@"[VEEX] HS cd sin blob");
            } else vxLog(@"[VEEX] HS sb magic=%x", magic);
        }
        free(sb);
    }
    free(buf);
    close(fd);
}
static void vxAuto(void) {
    vxLog(@"[VEEX] AH0 auto");
    vxFindSelf();
    vxSelfRange();
    vxLog(@"[VEEX] AH1 self idx=%u", gMyIdx);
    vxPatchLoadName();
    vxLog(@"[VEEX] AH2 id_dylib");
    vxPatchMainLoad();
    vxLog(@"[VEEX] AH3 main");
    vxInstallBody();
    vxLog(@"[VEEX] AH4 body");
    vxCsLog("auto");
    vxHashSelf();
}
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
    if (gBodies <= 6) vxLog(@"[VEEX] body %@", [s substringToIndex:MIN(s.length, 240)]);
    NSMutableURLRequest *m = [req mutableCopy];
    [m setHTTPBody:[s dataUsingEncoding:NSUTF8StringEncoding]];
    return m;
}
static NSURLSessionDataTask *(*o_dt)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *)) = NULL;
static NSURLSessionUploadTask *(*o_ut)(id, SEL, NSURLRequest *, NSData *, void (^)(NSData *, NSURLResponse *, NSError *)) = NULL;
static NSURLSessionDataTask *h_dt(id self, SEL c, NSURLRequest *r, void (^cb)(NSData *, NSURLResponse *, NSError *)) {
    return o_dt ? o_dt(self, c, vxRewrite(r), cb) : nil;
}
static NSURLSessionUploadTask *h_ut(id self, SEL c, NSURLRequest *r, NSData *d, void (^cb)(NSData *, NSURLResponse *, NSError *)) {
    return o_ut ? o_ut(self, c, vxRewrite(r), d, cb) : nil;
}
static void vxInstallBody(void) {
    Method m = class_getInstanceMethod([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:));
    if (m) o_dt = (void *)method_setImplementation(m, (IMP)h_dt);
    Method u = class_getInstanceMethod([NSURLSession class], @selector(uploadTaskWithRequest:fromData:completionHandler:));
    if (u) o_ut = (void *)method_setImplementation(u, (IMP)h_ut);
}
static void vxKillAttest(void) {
    Class c = NSClassFromString(@"DCAppAttestService");
    if (!c) { vxLog(@"[VEEX] attest sin clase"); return; }
    Method m = class_getInstanceMethod(c, @selector(isSupported));
    if (m) method_setImplementation(m, imp_implementationWithBlock(^BOOL(id s) { (void)s; return NO; }));
    vxLog(@"[VEEX] attest swz=%d", m ? 1 : 0);
}
static void vxFingerprint(void) {
    vxLog(@"[VEEX] F1 bundle=%@", [[NSBundle mainBundle] bundleIdentifier]);
    void *sec = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    if (!sec) return;
    void *(*mk)(void *) = (void *(*)(void *))dlsym(sec, "SecTaskCreateFromSelf");
    CFTypeRef (*get)(void *, CFStringRef, void **) = (CFTypeRef (*)(void *, CFStringRef, void **))dlsym(sec, "SecTaskCopyValueForEntitlement");
    if (!mk || !get) return;
    void *t = mk(NULL);
    if (!t) return;
    const char *keys[] = { "application-identifier", "com.apple.developer.team-identifier", "get-task-allow", "aps-environment" };
    for (int i = 0; i < 4; i++) {
        CFStringRef k = CFStringCreateWithCString(NULL, keys[i], kCFStringEncodingUTF8);
        CFTypeRef v = get(t, k, NULL);
        if (v) { vxLog(@"[VEEX] ent %s=%@", keys[i], (__bridge id)v); CFRelease(v); }
        CFRelease(k);
    }
    CFRelease(t);
}
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
        if (lc->cmd == LC_ENCRYPTION_INFO_64 && ((struct encryption_info_command_64 *)lc)->cryptid != 1) {
            vm_protect(mach_task_self(), (uint64_t)h & ~(VX_PG - 1), VX_PG, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            ((struct encryption_info_command_64 *)lc)->cryptid = 1;
            vxLog(@"[VEEX] cryptid 0->1");
        }
        p += lc->cmdsize;
    }
}
typedef void *(*f_v)(void);
typedef void *(*f_asms)(void *, size_t *);
typedef void *(*f_p1)(void *);
typedef size_t (*f_s1)(void *);
typedef void *(*f_i1)(void *, size_t);
typedef const char *(*f_c1)(void *);
typedef void *(*f_mf)(void *, const char *, int);
typedef void *(*f_att)(void *);
typedef const char *(*f_ns)(void *);
typedef void *(*f_meths)(void *, void **);
typedef const char *(*f_mname)(void *);
typedef uint32_t (*f_pc)(void *);
static f_v p_dom; static f_asms p_asms; static f_p1 p_img; static f_s1 p_cc;
static f_i1 p_ci; static f_c1 p_cn; static f_mf p_mf;
static f_att p_att; static f_p1 p_kl;
static f_ns p_cns; static f_meths p_ml; static f_mname p_mn;
static f_pc p_pc = NULL;
static int gI2C = 0;
static char gUnityPath[1024];
static void *gUniHandle = NULL;
static void *(*p_gchn)(void *, int) = NULL;
static void (*p_gchf)(uint32_t) = NULL;
static void vxFindUnityPath(void) {
    if (gUnityPath[0]) return;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (nm && strstr(nm, "UnityFramework")) { strncpy(gUnityPath, nm, sizeof(gUnityPath) - 1); return; }
    }
}
static void *vxSym(const char *n) {
    if (gUniHandle) { void *p = dlsym(gUniHandle, n); if (p) return p; }
    void *p = dlsym(RTLD_DEFAULT, n);
    if (p) return p;
    void *m = dlopen(NULL, RTLD_NOW);
    return m ? dlsym(m, n) : NULL;
}
static void vxLoadIL2CPP(void) {
    if (gI2C) return;
    if (!gUniHandle) {
        vxFindUnityPath();
        if (gUnityPath[0]) gUniHandle = dlopen(gUnityPath, RTLD_NOW | RTLD_GLOBAL);
        vxLog(@"[VEEX] uhandle=%p", gUniHandle);
    }
    int got = 0;
#define R(n, v) do { v = (void *)vxSym(n); if (v) got++; } while (0)
    R("il2cpp_domain_get", p_dom);
    R("il2cpp_thread_attach", p_att);
    R("il2cpp_domain_get_assemblies", p_asms);
    R("il2cpp_assembly_get_image", p_img);
    R("il2cpp_image_get_class_count", p_cc);
    R("il2cpp_image_get_class", p_ci);
    R("il2cpp_class_get_name", p_cn);
    R("il2cpp_class_get_namespace", p_cns);
    R("il2cpp_class_get_methods", p_ml);
    R("il2cpp_method_get_name", p_mn);
    R("il2cpp_class_get_method_from_name", p_mf);
    R("il2cpp_object_get_class", p_kl);
    R("il2cpp_method_get_param_count", p_pc);
    R("il2cpp_gchandle_new", p_gchn);
    R("il2cpp_gchandle_free", p_gchf);
#undef R
    int finder = (p_mf != NULL) || (p_ml && p_mn && p_pc);
    gI2C = p_dom && p_asms && p_img && p_cc && p_ci && p_cn && p_kl && finder;
    vxLog(@"[VEEX] il2cpp %d/15 ok=%d", got, gI2C);
}
typedef struct { int t; float x, y, w, h; float r, g, b, a; char s[72]; } vxCmd;
#define VX_CMAX 512
static vxCmd gCmd[VX_CMAX];
static volatile int gCmdN = 0;
static volatile int gDrawLock = 0;
static void vxLock(void) { while (__atomic_test_and_set((volatile void *)&gDrawLock, __ATOMIC_ACQUIRE)) {} }
static void vxUnlock(void) { __atomic_clear((volatile void *)&gDrawLock, __ATOMIC_RELEASE); }
@interface VXCanvas : UIView @end
@implementation VXCanvas
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { self.backgroundColor = UIColor.clearColor; self.userInteractionEnabled = NO; }
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
        else if (q->t == 1) { CGContextMoveToPoint(c, q->x, q->y); CGContextAddLineToPoint(c, q->x + q->w, q->y + q->h); CGContextStrokePath(c); }
        else if (q->t == 2) {
            UIFont *f = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
            [[NSString stringWithUTF8String:q->s] drawAtPoint:CGPointMake(q->x, q->y)
                withAttributes:@{ NSFontAttributeName: f, NSForegroundColorAttributeName:
                [UIColor colorWithRed:q->r green:q->g blue:q->b alpha:q->a] }];
        }
    }
    vxUnlock();
}
@end
@interface VXRoot : UIView
- (void)vxDoClose;
- (void)vxDoTab:(UIButton *)b;
- (void)vxDoHook;
- (void)vxDoRun;
- (void)vxDoStop;
- (void)vxDoCopy;
- (void)vxDoRst;
@end
@implementation VXRoot
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return v == self ? nil : v;
}
- (void)vxDoClose { gOpen = !gOpen; gPanel.hidden = !gOpen; }
- (void)vxDoTab:(UIButton *)b { gTab = (int)b.tag; vxBuildTab(); }
- (void)vxDoHook {
    vxLog(@"[VEEX] HOOK tap");
    vxInstallBody();
    vxInstallHooks();
    vxFindSelf();
    vxSelfRange();
    vxLog(@"[VEEX] H3 self idx=%u", gMyIdx);
    vxPatchLoadName();
    vxPatchMainLoad();
    vxPatchCryptid();
    vxKillAttest();
    vxFingerprint();
    vxCsLog("post");
    vxHashSelf();
    vxLog(@"[VEEX] H8 fin");
}
- (void)vxDoRun { vxRunScript(); }
- (void)vxDoStop { vxStopScript(); vxLog(@"[VEEX] stop"); }
- (void)vxDoCopy { UIPasteboard.generalPasteboard.string = gLog ?: @""; vxLog(@"[VEEX] log copiado"); }
- (void)vxDoRst { vxLog(@"[VEEX] RST tap"); vxResetGuest(); }
@end
@interface VXWindow : UIWindow @end
@implementation VXWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    if (!v || v == self || v == self.rootViewController.view) return nil;
    return v;
}
@end
@interface VXRow : UIButton
- (void)vxPaint;
- (void)vxTap;
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
    vxUnlock(); return 0;
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
    vxUnlock(); return 0;
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
    vxUnlock(); return 0;
}
static int l_sw(lua_State *L) { lua_pushnumber(L, [UIScreen mainScreen].bounds.size.width); return 1; }
static int l_sh(lua_State *L) { lua_pushnumber(L, [UIScreen mainScreen].bounds.size.height); return 1; }
static int l_log(lua_State *L) { vxLog(@"[L] %s", luaL_checkstring(L,1)); return 0; }
static int l_cfg(lua_State *L) {
    id v = gCfg[[NSString stringWithUTF8String:luaL_checkstring(L,1)]];
    if ([v isKindOfClass:[NSNumber class]]) lua_pushnumber(L, [v doubleValue]); else lua_pushnil(L);
    return 1;
}
static int l_setcfg(lua_State *L) {
    const char *k = luaL_checkstring(L,1);
    gCfg[@(k)] = luaL_optinteger(L,2,0) ? @YES : @NO;
    return 0;
}
static int l_r32(lua_State *L) { lua_pushinteger(L, *(uint32_t *)(uintptr_t)luaL_checkinteger(L,1)); return 1; }
static int l_w32(lua_State *L) { *(uint32_t *)(uintptr_t)luaL_checkinteger(L,1) = (uint32_t)luaL_checkinteger(L,2); return 0; }
static int l_rf(lua_State *L) { lua_pushnumber(L, *(float *)(uintptr_t)luaL_checkinteger(L,1)); return 1; }
static int l_wf(lua_State *L) { *(float *)(uintptr_t)luaL_checkinteger(L,1) = (float)luaL_checknumber(L,2); return 0; }
static int l_sym(lua_State *L) {
    const char *n = luaL_checkstring(L, 1);
    void *h = dlopen(NULL, RTLD_NOW);
    void *p = h ? dlsym(h, n) : NULL;
    if (p) lua_pushinteger(L, (lua_Integer)(uintptr_t)p); else lua_pushnil(L);
    return 1;
}
static int l_gch(lua_State *L) {
    uint64_t o = (uint64_t)luaL_optinteger(L, 1, 0);
    if (!o || !p_gchn) { lua_pushinteger(L, 0); return 1; }
    lua_pushinteger(L, (lua_Integer)(uintptr_t)p_gchn((void *)(uintptr_t)o, 0));
    return 1;
}
static int l_gchf(lua_State *L) {
    uint64_t h = (uint64_t)luaL_optinteger(L, 1, 0);
    if (h && p_gchf) p_gchf((uint32_t)h);
    return 0;
}
static int l_reset(lua_State *L) { (void)L; dispatch_async(dispatch_get_main_queue(), ^{ vxResetGuest(); }); return 0; }
static int l_reload(lua_State *L) {
    (void)L;
    gRun = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ vxRunScript(); });
    return 0;
}
static int l_i2c_ready(lua_State *L) { lua_pushboolean(L, gI2C); return 1; }
static int l_i2c_class(lua_State *L) {
    const char *a1 = luaL_checkstring(L,1);
    const char *wantNs = NULL, *wantName = a1;
    if (!lua_isnoneornil(L,2)) { wantNs = a1; wantName = luaL_checkstring(L,2); }
    if (!gI2C) { lua_pushnil(L); return 1; }
    size_t n = 0;
    void **asms = (void **)p_asms(p_dom(), &n);
    for (size_t a = 0; a < n; a++) {
        void *img = p_img(asms[a]); if (!img) continue;
        size_t c = p_cc(img);
        for (size_t i = 0; i < c; i++) {
            void *kl = p_ci(img, i); if (!kl) continue;
            const char *nm = p_cn(kl);
            if (!nm || strcmp(nm, wantName)) continue;
            if (wantNs) { const char *ns = p_cns ? p_cns(kl) : ""; if (!ns || strcmp(ns, wantNs)) continue; }
            lua_pushinteger(L, (lua_Integer)(uintptr_t)kl);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}
static void *vxMethodOf(void *kl, const char *name, int argc) {
    if (p_mf) { void *m = p_mf(kl, name, argc); if (m) return m; }
    if (!p_ml || !p_mn) return NULL;
    void *it = NULL, *m;
    while ((m = p_ml(kl, &it))) {
        const char *nm = p_mn(m);
        if (!nm || strcmp(nm, name)) continue;
        if (p_pc && (int)p_pc(m) != argc) continue;
        return m;
    }
    return NULL;
}
static int l_i2c_mptr(lua_State *L) {
    uint64_t kl = (uint64_t)luaL_checkinteger(L,1);
    const char *mth = luaL_checkstring(L,2);
    int argc = (int)luaL_optinteger(L,3,0);
    if (!gI2C || !kl) { lua_pushnil(L); return 1; }
    void *m = vxMethodOf((void *)(uintptr_t)kl, mth, argc);
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
static int l_gete(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1), o = (uint64_t)luaL_checkinteger(L,2);
    vx3f r = ((vx3f (*)(uint64_t))(uintptr_t)f)(o);
    lua_pushnumber(L, r.x); lua_pushnumber(L, r.y); lua_pushnumber(L, r.z);
    return 3;
}
static int l_sete(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L,1), o = (uint64_t)luaL_checkinteger(L,2);
    ((void (*)(uint64_t, float, float, float))(uintptr_t)f)(o, (float)luaL_checknumber(L,3), (float)luaL_checknumber(L,4), (float)luaL_checknumber(L,5));
    return 0;
}
static int l_str(lua_State *L) {
    uint64_t s = (uint64_t)luaL_checkinteger(L,1);
    if (!s) { lua_pushstring(L, ""); return 1; }
    int32_t len = *(int32_t *)(uintptr_t)(s + 0x10);
    if (len < 0 || len > 64) len = 64;
    char out[200]; int k = 0;
    const uint16_t *ch = (const uint16_t *)(uintptr_t)(s + 0x14);
    for (int32_t i = 0; i < len && k < 190; i++) { uint16_t c = ch[i]; out[k++] = (c < 0x80) ? (char)c : '?'; }
    out[k] = 0;
    lua_pushstring(L, out);
    return 1;
}
typedef struct { float m[16]; } vx4x4;
static float gMW[16];
static float gMP[16];
static int gCamOK = 0;
static uint64_t gCamM = 0, gCamP = 0, gCamObj = 0;
static void vxReadMat(uint64_t f, uint64_t o, float *dst) {
    memset(dst, 0, 64);
    if (!f || !o) return;
    vx4x4 r = ((vx4x4 (*)(uint64_t))(uintptr_t)f)(o);
    memcpy(dst, r.m, 64);
}
static int l_camset(lua_State *L) {
    gCamM = (uint64_t)luaL_checkinteger(L, 1);
    gCamP = (uint64_t)luaL_checkinteger(L, 2);
    gCamObj = (uint64_t)luaL_checkinteger(L, 3);
    lua_pushboolean(L, (gCamM && gCamP && gCamObj) ? 1 : 0);
    return 1;
}
static int l_camupd(lua_State *L) {
    (void)L;
    if (!gCamObj) { gCamOK = 0; return 0; }
    vxReadMat(gCamM, gCamObj, gMW);
    vxReadMat(gCamP, gCamObj, gMP);
    gCamOK = 1;
    return 0;
}
static int l_w2smu(lua_State *L) {
    float x = (float)luaL_checknumber(L,1), y = (float)luaL_checknumber(L,2), z = (float)luaL_checknumber(L,3);
    if (!gCamOK) { lua_pushnumber(L,0); lua_pushnumber(L,0); return 2; }
    const float *V = gMW, *P = gMP;
    float vx = V[0]*x + V[4]*y + V[8]*z + V[12];
    float vy = V[1]*x + V[5]*y + V[9]*z + V[13];
    float vz = V[2]*x + V[6]*y + V[10]*z + V[14];
    float cx = P[0]*vx + P[4]*vy + P[8]*vz + P[12];
    float cy = P[1]*vx + P[5]*vy + P[9]*vz + P[13];
    float cw = P[3]*vx + P[7]*vy + P[11]*vz + P[15];
    if (cw < 0.0001f) { lua_pushnumber(L,0); lua_pushnumber(L,0); return 2; }
    lua_pushnumber(L, ((cx/cw) * 0.5f + 0.5f) * [UIScreen mainScreen].bounds.size.width);
    lua_pushnumber(L, (1.0f - ((cy/cw) * 0.5f + 0.5f)) * [UIScreen mainScreen].bounds.size.height);
    return 2;
}
static int l_w2sm(lua_State *L) {
    float x = (float)luaL_checknumber(L,1), y = (float)luaL_checknumber(L,2), z = (float)luaL_checknumber(L,3);
    if (!gCamOK) { lua_pushnumber(L,0); lua_pushnumber(L,0); lua_pushboolean(L,0); return 3; }
    const float *V = gMW, *P = gMP;
    float vx = V[0]*x + V[4]*y + V[8]*z + V[12];
    float vy = V[1]*x + V[5]*y + V[9]*z + V[13];
    float vz = V[2]*x + V[6]*y + V[10]*z + V[14];
    float cx = P[0]*vx + P[4]*vy + P[8]*vz + P[12];
    float cy = P[1]*vx + P[5]*vy + P[9]*vz + P[13];
    float cw = P[3]*vx + P[7]*vy + P[11]*vz + P[15];
    if (cw < 0.01f) { lua_pushnumber(L,0); lua_pushnumber(L,0); lua_pushboolean(L,0); return 3; }
    float nx = cx/cw, ny = cy/cw;
    lua_pushnumber(L, (nx * 0.5f + 0.5f) * [UIScreen mainScreen].bounds.size.width);
    lua_pushnumber(L, (1.0f - (ny * 0.5f + 0.5f)) * [UIScreen mainScreen].bounds.size.height);
    lua_pushboolean(L, (nx > -2.5 && nx < 2.5 && ny > -2.5 && ny < 2.5) ? 1 : 0);
    return 3;
}
static int l_w2smd(lua_State *L) {
    float x = (float)luaL_checknumber(L,1), y = (float)luaL_checknumber(L,2), z = (float)luaL_checknumber(L,3);
    if (!gCamOK) { for (int i = 0; i < 6; i++) lua_pushnumber(L, 0); return 6; }
    const float *V = gMW, *P = gMP;
    float vx = V[0]*x + V[4]*y + V[8]*z + V[12];
    float vy = V[1]*x + V[5]*y + V[9]*z + V[13];
    float vz = V[2]*x + V[6]*y + V[10]*z + V[14];
    float cx = P[0]*vx + P[4]*vy + P[8]*vz + P[12];
    float cy = P[1]*vx + P[5]*vy + P[9]*vz + P[13];
    float cw = P[3]*vx + P[7]*vy + P[11]*vz + P[15];
    float nx = 0, ny = 0;
    if (cw > 0.0001f) { nx = cx / cw; ny = cy / cw; }
    lua_pushnumber(L, vx); lua_pushnumber(L, vy); lua_pushnumber(L, vz);
    lua_pushnumber(L, cw); lua_pushnumber(L, nx); lua_pushnumber(L, ny);
    return 6;
}
static int l_matdump(lua_State *L) {
    (void)L;
    char b[400]; int k = snprintf(b, sizeof b, "[L] MW");
    for (int i = 0; i < 16; i++) k += snprintf(b + k, sizeof b - k, " %.3f", gMW[i]);
    vxLog(@"%s", b);
    k = snprintf(b, sizeof b, "[L] MP");
    for (int i = 0; i < 16; i++) k += snprintf(b + k, sizeof b - k, " %.3f", gMP[i]);
    vxLog(@"%s", b);
    return 0;
}
static void vxStopScript(void) { gRun = 0; }
static void vxWipe(void) {
    vxLog(@"[VEEX] WIPE inicio");
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *doms = @[ bid ?: @"", @"com.dts.freefireth", @"app.badger6804.pineapple6732" ];
    for (NSString *d in doms) {
        if (!d.length) continue;
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:d];
        vxLog(@"[PF] dominio %@", d);
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSString *prefDir = [[gDocs stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Preferences"];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:prefDir error:NULL];
    int pfn = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"plist"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[prefDir stringByAppendingPathComponent:f] error:NULL]) pfn++;
    }
    vxLog(@"[VEEX] prefs borradas=%d", pfn);
    NSArray *classes = @[ (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClassInternetPassword, (__bridge id)kSecClassKey ];
    int kcf = 0;
    for (int ci = 0; ci < 3; ci++) {
        NSDictionary *q = @{ (__bridge id)kSecClass: classes[ci],
                             (__bridge id)kSecReturnAttributes: @YES,
                             (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll };
        CFTypeRef res = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &res) == errSecSuccess && res) {
            NSArray *arr = (__bridge_transfer NSArray *)res;
            kcf += (int)arr.count;
            NSMutableDictionary *dq = [NSMutableDictionary dictionary];
            dq[(__bridge id)kSecClass] = classes[ci];
            SecItemDelete((__bridge CFDictionaryRef)dq);
        }
    }
    vxLog(@"[VEEX] guest borrados=%d", kcf);
    vxLog(@"[VEEX] WIPE fin");
}
static void vxResetGuest(void) {
    vxLog(@"[VEEX] RESET armado");
    NSString *flag = vxStore("e.dat");
    [@"1" writeToFile:flag atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSUserDefaults standardUserDefaults] synchronize];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}
typedef void *(*f_flds)(void *, void **);
typedef const char *(*f_fname)(void *);
typedef size_t (*f_foff)(void *);
typedef void *(*f_ftype)(void *);
typedef const char *(*f_tname)(void *);
typedef void *(*f_parent)(void *);
static f_flds p_fl; static f_fname p_fn; static f_foff p_fo;
static f_ftype p_ft; static f_tname p_tn; static f_parent p_par;
static void vxFieldSyms(void) {
    if (p_fl) return;
    void *h = NULL;
    vxFindUnityPath();
    if (gUnityPath[0]) h = dlopen(gUnityPath, RTLD_NOW);
    if (!h) h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    p_fl = (f_flds)dlsym(h, "il2cpp_class_get_fields");
    p_fn = (f_fname)dlsym(h, "il2cpp_field_get_name");
    p_fo = (f_foff)dlsym(h, "il2cpp_field_get_offset");
    p_ft = (f_ftype)dlsym(h, "il2cpp_field_get_type");
    p_tn = (f_tname)dlsym(h, "il2cpp_type_get_name");
    p_par = (f_parent)dlsym(h, "il2cpp_class_get_parent");
}
static int vxFieldKeep(const char *t) {
    if (!t) return 0;
    const char *k[] = { "Vector3", "Vector2", "Transform", "Single", "Int32", "Boolean",
                        "String", "UInt32", "Int16", "UInt16", "Int64", "List`1", "Dictionary",
                        "HashSet", "Player", "ITransformNode" };
    for (int i = 0; i < 16; i++) if (strstr(t, k[i])) return 1;
    return 0;
}
static int l_fields(lua_State *L) {
    uint64_t kl = (uint64_t)luaL_checkinteger(L, 1);
    lua_newtable(L);
    vxFieldSyms();
    if (!gI2C || !kl || !p_fl) return 1;
    void *it = NULL, *f; int k = 0; char b[220];
    while ((f = p_fl((void *)(uintptr_t)kl, &it)) && k < 260) {
        const char *nm = p_fn ? p_fn(f) : NULL; if (!nm) continue;
        const char *tn = (p_ft && p_tn) ? p_tn(p_ft(f)) : "";
        if (!vxFieldKeep(tn)) continue;
        snprintf(b, sizeof(b), "0x%zx %s %s", p_fo ? p_fo(f) : 0, tn ? tn : "?", nm);
        lua_pushstring(L, b);
        lua_rawseti(L, -2, ++k);
    }
    return 1;
}
static int l_parents(lua_State *L) {
    uint64_t kl = (uint64_t)luaL_checkinteger(L, 1);
    lua_newtable(L);
    vxFieldSyms();
    if (!p_par || !kl) return 1;
    int k = 0;
    void *c = (void *)(uintptr_t)kl;
    while ((c = p_par(c)) && k < 12) {
        const char *ns = p_cns ? p_cns(c) : "";
        const char *nm = p_cn ? p_cn(c) : "";
        char b[220];
        snprintf(b, sizeof(b), "%s::%s", (ns && *ns) ? ns : "-", nm ? nm : "?");
        lua_pushstring(L, b);
        lua_rawseti(L, -2, ++k);
    }
    return 1;
}
static void *gHarvest[512];
static volatile int gHarvestN = 0;
static void *gOrig1 = NULL;
__attribute__((used, noinline)) static void h_harvest_c(void *self) {
    if (self && gHarvestN < 512) {
        int dup = 0;
        for (int i = 0; i < gHarvestN; i++) if (gHarvest[i] == self) { dup = 1; break; }
        if (!dup) gHarvest[gHarvestN++] = self;
    }
}
__attribute__((naked)) static void h_harvest(void) {
    __asm__ volatile(
        "sub sp, sp, #112\n" "stp x0, x1, [sp, #0]\n" "stp x2, x3, [sp, #16]\n"
        "stp x4, x5, [sp, #32]\n" "stp x6, x7, [sp, #48]\n" "stp x29, x30, [sp, #64]\n"
        "str x8, [sp, #80]\n" "ldr x0, [sp, #0]\n" "bl _h_harvest_c\n"
        "ldp x0, x1, [sp, #0]\n" "ldp x2, x3, [sp, #16]\n" "ldp x4, x5, [sp, #32]\n"
        "ldp x6, x7, [sp, #48]\n" "ldp x29, x30, [sp, #64]\n" "ldr x8, [sp, #80]\n"
        "add sp, sp, #112\n" "adrp x9, _gOrig1@PAGE\n" "ldr x9, [x9, _gOrig1@PAGEOFF]\n"
        "cbz x9, 1f\n" "br x9\n" "1:\n" "ret\n");
}
#define VX_BSTUB(N) \
__attribute__((naked, used)) static void vxB##N(void) { \
    __asm__ volatile( \
        "sub sp, sp, #160\n" "stp x0, x1, [sp, #0]\n" "stp x2, x3, [sp, #16]\n" \
        "stp x4, x5, [sp, #32]\n" "stp x6, x7, [sp, #48]\n" "stp x29, x30, [sp, #64]\n" \
        "str x8, [sp, #80]\n" "ldr x0, [sp, #0]\n" "bl _h_harvest_c\n" \
        "ldp x0, x1, [sp, #0]\n" "ldp x2, x3, [sp, #16]\n" "ldp x4, x5, [sp, #32]\n" \
        "ldp x6, x7, [sp, #48]\n" "ldp x29, x30, [sp, #64]\n" "ldr x8, [sp, #80]\n" \
        "add sp, sp, #160\n" "adrp x9, _gB" #N "A@PAGE\n" "ldr x10, [x9, _gB" #N "A@PAGEOFF]\n" \
        "ubfx x11, x10, #10, #12\n" "ubfx x12, x10, #22, #1\n" "lsl x11, x11, x12\n" \
        "sub sp, sp, x11\n" "adrp x9, _gB" #N "B@PAGE\n" "ldr x9, [x9, _gB" #N "B@PAGEOFF]\n" \
        "br x9\n"); \
}
VX_BSTUB(0) VX_BSTUB(1) VX_BSTUB(2) VX_BSTUB(3)
static const uintptr_t gStubTbl[4] = { (uintptr_t)&vxB0, (uintptr_t)&vxB1, (uintptr_t)&vxB2, (uintptr_t)&vxB3 };
static int vxNearHook(void *target) {
    if (!target) return -1;
    if (gBHN >= 4) return -20;
    uint32_t *t = (uint32_t *)target;
    uint32_t i0 = t[0];
    if (vxBadInstr(i0)) return -21;
    if ((i0 & 0xFFC003FF) != 0xD10003FF) return -22;
    void *stub = (void *)gStubTbl[gBHN];
    int64_t d = (int64_t)((uint8_t *)stub - (uint8_t *)target);
    if (d & 3) return -23;
    if (d < -(1LL << 27) || d >= (1LL << 27)) return -24;
    uint64_t pg = (uint64_t)target & ~(uint64_t)(VX_PG - 1);
    if (mprotect((void *)pg, VX_PG, PROT_READ | PROT_WRITE | PROT_EXEC) != 0)
        if (vm_protect(mach_task_self(), pg, VX_PG, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) return -25;
    int idx = gBHN++;
    *gBInstr[idx] = (uint64_t)i0;
    *gBAddr[idx] = (uint64_t)target + 4;
    t[0] = 0x94000000u | (uint32_t)((d >> 2) & 0x03FFFFFF);
    vxFlush(t, 4);
    return 0;
}
static int l_hook1(lua_State *L) {
    uint64_t a = (uint64_t)luaL_checkinteger(L, 1);
    gHarvestN = 0;
    if (!a) { lua_pushinteger(L, -1); return 1; }
    if (!p_icache) p_icache = (void (*)(void *, size_t))dlsym(RTLD_DEFAULT, "sys_icache_invalidate");
    int r = vxNearHook((void *)(uintptr_t)a);
    if (r != 0) r = vxInlineHook((void *)(uintptr_t)a, (void *)h_harvest, &gOrig1);
    lua_pushinteger(L, r);
    return 1;
}
static int l_hookm(lua_State *L) {
    uint64_t kl = (uint64_t)luaL_checkinteger(L, 1);
    const char *nm = luaL_checkstring(L, 2);
    int argc = (int)luaL_optinteger(L, 3, 0);
    gHarvestN = 0;
    if (!gI2C || !kl) { lua_pushinteger(L, -1); lua_pushinteger(L, 0); return 2; }
    void *m = vxMethodOf((void *)(uintptr_t)kl, nm, argc);
    if (!m) { lua_pushinteger(L, -2); lua_pushinteger(L, 0); return 2; }
    uint64_t *w = (uint64_t *)m;
    if (w[0] == (uint64_t)&h_harvest) { lua_pushinteger(L, 2); lua_pushinteger(L, (lua_Integer)(uintptr_t)gOrig1); return 2; }
    if (!(vxProtOf((void *)w[0]) & VM_PROT_EXECUTE)) { lua_pushinteger(L, -3); lua_pushinteger(L, (lua_Integer)(uintptr_t)w[0]); return 2; }
    uint64_t pg = (uint64_t)m & ~(uint64_t)(VX_PG - 1);
    if (mprotect((void *)pg, VX_PG, PROT_READ | PROT_WRITE) != 0)
        if (vm_protect(mach_task_self(), pg, VX_PG, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) {
            lua_pushinteger(L, -4); lua_pushinteger(L, (lua_Integer)(uintptr_t)w[0]); return 2;
        }
    uint64_t old = w[0];
    gOrig1 = (void *)(uintptr_t)old;
    w[0] = (uint64_t)&h_harvest;
    vxFlush(m, 8);
    lua_pushinteger(L, 1);
    lua_pushinteger(L, (lua_Integer)old);
    return 2;
}
static int l_hv_count(lua_State *L) { lua_pushinteger(L, gHarvestN); return 1; }
static int l_hv_get(lua_State *L) {
    int i = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >= 0 && i < gHarvestN) ? (lua_Integer)(uintptr_t)gHarvest[i] : 0);
    return 1;
}
static int l_hv_clear(lua_State *L) { (void)L; gHarvestN = 0; return 0; }
static int l_r64(lua_State *L) {
    uint64_t a = (uint64_t)luaL_checkinteger(L, 1);
    lua_pushinteger(L, a ? *(uint64_t *)(uintptr_t)a : 0);
    return 1;
}
static void vxRegister(lua_State *L) {
    lua_register(L, "log", l_log); lua_register(L, "text", l_text);
    lua_register(L, "rect", l_rect); lua_register(L, "line", l_line); lua_register(L, "clear", l_clear);
    lua_register(L, "sw", l_sw); lua_register(L, "sh", l_sh);
    lua_register(L, "r32", l_r32); lua_register(L, "w32", l_w32);
    lua_register(L, "rf", l_rf); lua_register(L, "wf", l_wf);
    lua_register(L, "sym", l_sym); lua_register(L, "cfg", l_cfg); lua_register(L, "setcfg", l_setcfg);
    lua_register(L, "reset", l_reset); lua_register(L, "reload", l_reload);
    lua_register(L, "i2c_ready", l_i2c_ready); lua_register(L, "i2c_class", l_i2c_class);
    lua_register(L, "i2c_mptr", l_i2c_mptr); lua_register(L, "kl", l_kl);
    lua_register(L, "fields", l_fields); lua_register(L, "parents", l_parents);
    lua_register(L, "hook1", l_hook1); lua_register(L, "hookm", l_hookm);
    lua_register(L, "hv_count", l_hv_count); lua_register(L, "hv_get", l_hv_get);
    lua_register(L, "hv_clear", l_hv_clear); lua_register(L, "r64", l_r64);
    lua_register(L, "call", l_call);
    lua_register(L, "arrlen", l_arrlen); lua_register(L, "arrat", l_arrat);
    lua_register(L, "gete", l_gete); lua_register(L, "sete", l_sete); lua_register(L, "str", l_str);
    lua_register(L, "camset", l_camset); lua_register(L, "camupd", l_camupd);
    lua_register(L, "w2sm", l_w2sm); lua_register(L, "w2smu", l_w2smu); lua_register(L, "w2smd", l_w2smd);
    lua_register(L, "matdump", l_matdump);
    lua_register(L, "gch", l_gch); lua_register(L, "gchf", l_gchf);
}
static void *vxRunThread(void *arg) {
    (void)arg;
    [NSThread sleepForTimeInterval:1.2];
    for (int i = 0; i < 120 && !gI2C; i++) { vxLoadIL2CPP(); if (!gI2C) [NSThread sleepForTimeInterval:0.2]; }
    if (!gI2C || !p_dom || !p_att) { vxLog(@"[VEEX] R3 ABORTO"); return NULL; }
    void *dom = NULL;
    for (int i = 0; i < 40; i++) { dom = p_dom(); if (dom) break; [NSThread sleepForTimeInterval:0.2]; }
    if (!dom) { vxLog(@"[VEEX] R6 ABORTO dom"); return NULL; }
    p_att(dom);
    NSString *path = vxStore("a.dat");
    NSMutableURLRequest *rq = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:[SCRIPT_URL stringByAppendingFormat:@"?t=%d", (int)time(NULL)]]];
    [rq setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
    [rq setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    [rq setValue:@"no-cache" forHTTPHeaderField:@"Pragma"];
    NSURLResponse *rs = nil; NSError *er = nil;
    NSData *d = [NSURLConnection sendSynchronousRequest:rq returningResponse:&rs error:&er];
    if (d.length > 100) [d writeToFile:path atomically:YES];
    else vxLog(@"[VEEX] sin red, copia local");
    if (d.length > 20) vxLog(@"[VEEX] scr=%@", [[NSString alloc] initWithData:[d subdataWithRange:NSMakeRange(0, 20)] encoding:NSUTF8StringEncoding] ?: @"?");
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { vxLog(@"[VEEX] RD falta script"); return NULL; }
    gL = luaL_newstate();
    if (!gL) { vxLog(@"[VEEX] RE sin estado"); return NULL; }
    luaL_openlibs(gL);
    vxRegister(gL);
    lua_pushinteger(gL, (lua_Integer)gBase); lua_setglobal(gL, "BASE");
    lua_pushstring(gL, gDocs.UTF8String); lua_setglobal(gL, "DOC");
    if (luaL_dofile(gL, path.UTF8String) != LUA_OK) { vxLog(@"[VEEX] RE LUA ERROR: %s", lua_tostring(gL, -1)); return NULL; }
    gRun = 1;
    lua_State *L = gL;
    while (gRun && gL == L) {
        lua_getglobal(L, "tick");
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0) != LUA_OK) { vxLog(@"[VEEX] LUA tick: %s", lua_tostring(L, -1)); lua_pop(L, 1); }
        } else lua_pop(L, 1);
        dispatch_async(dispatch_get_main_queue(), ^{ if (gDraw) [gDraw setNeedsDisplay]; });
        [NSThread sleepForTimeInterval:1.0 / VX_FPS];
    }
    return NULL;
}
static void vxRunScript(void) {
    gRun = 0;
    if (gL) { lua_close(gL); gL = NULL; }
    pthread_t t; pthread_attr_t at;
    pthread_attr_init(&at);
    pthread_attr_setdetachstate(&at, PTHREAD_CREATE_DETACHED);
    pthread_attr_setstacksize(&at, 1024 * 1024);
    pthread_create(&t, &at, vxRunThread, NULL);
    pthread_attr_destroy(&at);
    vxLog(@"[VEEX] RUN hilo lanzado");
}
static void addRow(NSString *title, NSString *key, CGFloat y) {
    VXRow *r = [[VXRow alloc] initWithFrame:CGRectZero];
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
        addRow(@"Prediccion", @"aim.pred", y); y += 36;
        addRow(@"Humanizar", @"aim.human", y); y += 36;
        addRow(@"Modo silencioso", @"aim.silent", y); y += 36;
        addRow(@"AWM / larga", @"aim.awm", y);
    } else if (gTab == 2) {
        addRow(@"Lineas", @"draw.line", y); y += 36;
        addRow(@"Salud", @"draw.hp", y); y += 36;
        addRow(@"Arma", @"draw.wpn", y); y += 36;
        addRow(@"Esqueleto", @"draw.skel", y);
    } else if (gTab == 3) {
        addRow(@"Contador FPS", @"misc.fps", y); y += 36;
        addRow(@"Velocidad", @"misc.speed", y); y += 36;
        addRow(@"Anti-captura", @"misc.anti", y);
    } else if (gTab == 4) {
        addRow(@"RESET GUEST", @"set.reset", y); y += 36;
        addRow(@"Recargar script", @"set.reload", y);
    } else {
        addRow(@"Dump TODO", @"dbg.all", y); y += 36;
        addRow(@"Copiar metadata", @"dbg.meta", y);
    }
}
static void buildUI(UIWindowScene *sc) {
    gCfg = [NSMutableDictionary dictionary];
    gCfg[@"esp.on"] = @NO; gCfg[@"esp.box"] = @YES; gCfg[@"esp.name"] = @NO;
    gCfg[@"esp.dist"] = @YES; gCfg[@"esp.color"] = @NO;
    gCfg[@"aim.on"] = @NO; gCfg[@"aim.pred"] = @YES; gCfg[@"aim.human"] = @YES;
    gCfg[@"aim.silent"] = @NO; gCfg[@"aim.awm"] = @NO;
    gCfg[@"draw.line"] = @NO; gCfg[@"draw.hp"] = @NO; gCfg[@"draw.wpn"] = @NO; gCfg[@"draw.skel"] = @NO;
    gCfg[@"misc.fps"] = @NO; gCfg[@"misc.anti"] = @NO;
    gWin = [[VXWindow alloc] initWithWindowScene:sc];
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
    UILabel *ttl = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 88, 36)];
    ttl.text = [NSString stringWithFormat:@"VEEX %d", VX_BUILD];
    ttl.textColor = UIColor.whiteColor;
    ttl.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
    [head addSubview:ttl];
    UIButton *rst = [UIButton buttonWithType:UIButtonTypeSystem];
    rst.frame = CGRectMake(102, 6, 40, 24);
    [rst setTitle:@"RST" forState:UIControlStateNormal];
    rst.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [rst addTarget:gRoot action:@selector(vxDoRst) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:rst];
    UIButton *hook = [UIButton buttonWithType:UIButtonTypeSystem];
    hook.frame = CGRectMake(146, 6, 46, 24);
    [hook setTitle:@"HOOK" forState:UIControlStateNormal];
    hook.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [hook addTarget:gRoot action:@selector(vxDoHook) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:hook];
    UIButton *cl = [UIButton buttonWithType:UIButtonTypeSystem];
    cl.frame = CGRectMake(200, 6, 30, 24);
    [cl setTitle:@"X" forState:UIControlStateNormal];
    [cl addTarget:gRoot action:@selector(vxDoClose) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:cl];
    NSArray *names = @[@"ESP", @"AIM", @"DRAW", @"MISC", @"SET", @"DBG"];
    NSMutableArray *btns = [NSMutableArray array];
    for (int i = 0; i < (int)names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(8 + i * 37, 42, 34, 26);
        b.tag = i;
        b.layer.cornerRadius = 8;
        b.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
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
    vxLog(@"[VEEX] UI lista");
    gLogView.text = gLog ?: @"";
}
static void boot(double delay) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        static int tries = 0;
        if (gWin) return;
        UIWindowScene *sc = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { sc = (UIWindowScene *)s; break; }
        if (sc) { buildUI(sc); return; }
        if (++tries > 15) return;
        boot(1.0);
    });
}
static void vxLegacy(void) {
    for (int i = 0; i < 5; i++) {
        static const char *n[] = { "esp.lua", "veex.log", "veex.last", "veex.boot", "veex.reset" };
        NSString *p = [gDocs stringByAppendingPathComponent:@(n[i])];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p])
            [[NSFileManager defaultManager] removeItemAtPath:p error:NULL];
    }
}
__attribute__((constructor)) static void vxInit(void) {
    vxRaw("=== build %d: constructor ===", VX_BUILD);
    gBInstr[0] = &gB0A; gBInstr[1] = &gB1A; gBInstr[2] = &gB2A; gBInstr[3] = &gB3A;
    gBAddr[0] = &gB0B; gBAddr[1] = &gB1B; gBAddr[2] = &gB2B; gBAddr[3] = &gB3B;
    p_icache = (void (*)(void *, size_t))dlsym(RTLD_DEFAULT, "sys_icache_invalidate");
    p_jitwp = (int (*)(int))dlsym(RTLD_DEFAULT, "pthread_jit_write_protect_np");
    gLog = [NSMutableString new];
    gDocs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    vxLegacy();
    vxLog(@"[VEEX] build %d", VX_BUILD);
    NSString *lastp = vxStore("c.dat");
    NSString *last = [NSString stringWithContentsOfFile:lastp encoding:NSUTF8StringEncoding error:NULL];
    if (last.length) {
        [gLog appendString:@"--- ultimo run ---\n"];
        [gLog appendString:last];
        [[NSFileManager defaultManager] removeItemAtPath:lastp error:NULL];
    }
    NSString *lp = vxStore("b.dat");
    NSDictionary *lat = [[NSFileManager defaultManager] attributesOfItemAtPath:lp error:NULL];
    if ([[lat objectForKey:NSFileSize] unsignedLongLongValue] > 500000)
        [[NSFileManager defaultManager] removeItemAtPath:lp error:NULL];
    NSString *flag = vxStore("e.dat");
    if ([[NSFileManager defaultManager] fileExistsAtPath:flag]) {
        [[NSFileManager defaultManager] removeItemAtPath:flag error:NULL];
        @try { vxWipe(); } @catch (NSException *e) { vxRaw("wipe EXC"); }
    }
    gMainHdr = (uint64_t)_dyld_get_image_header(0);
    if (gMainHdr) {
        size_t sz = 0;
        uint8_t *p = getsegmentdata((const struct mach_header_64 *)gMainHdr, "__TEXT", &sz);
        if (p && sz) { gTextLo = (uint64_t)p; gTextHi = (uint64_t)p + sz; gTextSz = sz; }
    }
#if VX_AUTOHOOK
    dispatch_async(dispatch_get_main_queue(), ^{
        vxLog(@"[VEEX] camuflaje temprano");
        vxFindSelf();
        vxSelfRange();
        vxPatchLoadName();
        vxPatchMainLoad();
        vxLog(@"[VEEX] AH temprano fin idx=%u ok=%d", gMyIdx, gPLok);
        vxHashSelf();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        vxInstallBody();
        if (!gPLok) vxPatchMainLoad();
        vxInstallHooks();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!gPLok) vxPatchMainLoad();
        vxInstallHooks();
    });
#endif
    dispatch_async(dispatch_get_main_queue(), ^{ boot(0.8); });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            for (int i = 0; i < 60 && !gBase; i++) { vxFindImage(); if (!gBase) [NSThread sleepForTimeInterval:0.5]; }
            for (int i = 0; i < 240 && !gI2C; i++) { vxLoadIL2CPP(); if (!gI2C) [NSThread sleepForTimeInterval:0.5]; }
        }
    });
}
