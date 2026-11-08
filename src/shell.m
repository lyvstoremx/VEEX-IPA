// src/shell.m — VEEX
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
#import <dlfcn.h>
#import <stdio.h>
#import <libkern/OSCacheControl.h>
#import <sys/mman.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

// ===== etapa 6: hooks inline (chained fixups) =====
#define VX_STAGE 6
#define VX_FPS 20

#define SCRIPT_API @"https://api.github.com/repos/lyvstoremx/VEEX-IPA/contents/scripts/esp.lua"
#define SCRIPT_RAW @"https://raw.githubusercontent.com/lyvstoremx/VEEX-IPA/main/scripts/esp.lua"

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define VX_CS_OPS_STATUS      0
#define VX_CS_VALID           0x00000001
#define VX_CS_GET_TASK_ALLOW  0x00000004
#define VX_CS_HARD            0x00000100
#define VX_CS_DEBUGGED        0x10000000

#define VX_PFLAG_OFF          32
#define VX_P_TRACED           0x00000800

static const char *VX_FAKE = "/usr/lib/libobjc.A.dylib";

// ===== huellas oficiales App Store =====
static const char *VX_TEAM   = "98573T3W6L";
static const char *VX_APPID  = "98573T3W6L.com.dts.freefireth";
static const char *VX_H      = "00770007d45fe15664db57df30274f5c49daaa04f276be030f20686e673c833b";
static const char *VX_CD     = "d9cf9ae60f2433bf47fe33a29d7122bb1bcc5965";
static const char *VX_MD5ID  = "75ead73659249cdb3a0eee33e86c003a";

// ============ LOG ============
static NSMutableString *gLog = nil;
static UITextView *gLogView = nil;

static NSString *vxLogPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veex.log"];
}

static void vxHex(const char *hex, unsigned char *out, int n) {
    for (int i = 0; i < n; i++) {
        unsigned v = 0;
        sscanf(hex + i * 2, "%2x", &v);
        out[i] = (unsigned char)v;
    }
}

static void vxLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    if (!gLog) gLog = [NSMutableString new];
    [gLog appendFormat:@"%@\n", s];
    if (gLog.length > 12000) [gLog deleteCharactersInRange:NSMakeRange(0, gLog.length - 12000)];

    NSString *line = [s stringByAppendingString:@"\n"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:vxLogPath()];
        if (!fh) {
            [[NSData data] writeToFile:vxLogPath() atomically:YES];
            fh = [NSFileHandle fileHandleForWritingAtPath:vxLogPath()];
        }
        if (fh) {
            @try { [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; }
            @catch (NSException *e) {}
            [fh closeFile];
        }
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLogView) {
            gLogView.text = gLog;
            if (gLog.length) [gLogView scrollRangeToVisible:NSMakeRange(gLog.length - 1, 1)];
        }
    });
}

// ============ HOOK INLINE ARM64 ============
static int gHooked = 0;

static int vxInlineHook(void *target, void *rep, void **origOut) {
    if (!target || !rep || !origOut) return -1;
    uint32_t *t = (uint32_t *)target;

    for (int i = 0; i < 4; i++) {
        uint32_t in = t[i];
        if ((in & 0x9F000000) == 0x90000000) return -2;  // adrp
        if ((in & 0x7C000000) == 0x14000000) return -3;  // b / bl
        if ((in & 0xFF000010) == 0x54000000) return -4;  // b.cond
        if ((in & 0x3B000000) == 0x18000000) return -5;  // ldr literal
    }

    uint8_t *tr = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (tr == MAP_FAILED) return -6;
    memcpy(tr, t, 16);
    uint32_t *w = (uint32_t *)(tr + 16);
    w[0] = 0x58000050;  // ldr x16, #8
    w[1] = 0xD61F0200;  // br x16
    *(uint64_t *)(tr + 24) = (uint64_t)target + 16;
    mprotect(tr, 4096, PROT_READ | PROT_EXEC);

    uint64_t pg = (uint64_t)target & ~0xFFFULL;
    if (vm_protect(mach_task_self(), pg, 0x4000, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) {
        munmap(tr, 4096);
        return -7;
    }
    t[0] = 0x58000050;
    t[1] = 0xD61F0200;
    *(uint64_t *)(t + 2) = (uint64_t)rep;
    vm_protect(mach_task_self(), pg, 0x4000, false, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate(target, 16);

    *origOut = tr;
    return 0;
}

static void vxHookName(const char *name, void *rep, void **origOut) {
    void *t = dlsym(RTLD_DEFAULT, name);
    if (!t) { vxLog(@"[VEEX] !falta %s", name); return; }
    int r = vxInlineHook(t, rep, origOut);
    if (r == 0) gHooked++;
    else vxLog(@"[VEEX] !hook %s=%d", name, r);
}

// ============ CANVAS ============
@interface VXCanvas : UIView
@property (nonatomic, strong) NSMutableArray *cmds;
@end
@implementation VXCanvas
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.cmds = [NSMutableArray new];
    }
    return self;
}
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    for (NSArray *a in self.cmds) {
        NSString *t = a[0];
        if ([t isEqualToString:@"rect"]) {
            [a[2] setStroke];
            CGContextSetLineWidth(c, 1.6);
            CGContextStrokeRect(c, CGRectFromString(a[1]));
        } else if ([t isEqualToString:@"fill"]) {
            [a[2] setFill];
            CGContextFillRect(c, CGRectFromString(a[1]));
        } else if ([t isEqualToString:@"line"]) {
            [a[3] setStroke];
            CGContextSetLineWidth(c, 1.3);
            CGPoint p1 = CGPointFromString(a[1]), p2 = CGPointFromString(a[2]);
            CGContextMoveToPoint(c, p1.x, p1.y);
            CGContextAddLineToPoint(c, p2.x, p2.y);
            CGContextStrokePath(c);
        } else if ([t isEqualToString:@"text"]) {
            NSDictionary *at = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:11],
                                 NSForegroundColorAttributeName: a[3]};
            [a[1] drawAtPoint:CGPointFromString(a[2]) withAttributes:at];
        }
    }
}
@end

// ============ ROOT ============
static UIView *gPanelRef(void);
static UIView *gFabRef(void);

@interface VXRoot : UIView
@end
@implementation VXRoot
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *panel = gPanelRef();
    UIView *fab = gFabRef();
    if (panel && !panel.hidden && CGRectContainsPoint(panel.frame, p))
        return [super hitTest:p withEvent:e];
    if (fab && !fab.hidden && CGRectContainsPoint(fab.frame, p))
        return fab;
    return nil;
}
@end

// ============ ARRASTRE ============
@interface VXPan : NSObject
@end

static VXRoot *gRoot = nil;
static UIView *gPanel = nil;
static UIButton *gFab = nil;
static VXCanvas *gCanvas = nil;
static UIView *gPages[5];
static NSMutableDictionary *gSw = nil;
static VXPan *gPan = nil;
static int gTab = 0;

static UIView *gPanelRef(void) { return gPanel; }
static UIView *gFabRef(void) { return gFab; }

@implementation VXPan
- (void)handle:(UIPanGestureRecognizer *)g {
    if (!gPanel) return;
    CGPoint d = [g translationInView:gRoot];
    CGRect f = gPanel.frame;
    f.origin.x += d.x;
    f.origin.y += d.y;
    CGSize s = gRoot.bounds.size;
    if (f.origin.x < 0) f.origin.x = 0;
    if (f.origin.y < 0) f.origin.y = 0;
    if (f.origin.x + f.size.width > s.width) f.origin.x = s.width - f.size.width;
    if (f.origin.y + f.size.height > s.height) f.origin.y = s.height - f.size.height;
    gPanel.frame = f;
    [g setTranslation:CGPointZero inView:gRoot];
}
@end

// ============ BOTONES ============
@interface UIButton (VX)
- (void)vxDoTap;
- (void)vxDoTab;
- (void)vxDoCopy;
- (void)vxDoClear;
- (void)vxDoReset;
- (void)vxDoRun;
- (void)vxDoClose;
@end

static void buildUI(void);
static void vxAttach(void);

@implementation UIButton (VX)
- (void)vxDoTap {
    if (!gPanel) return;
    gPanel.hidden = !gPanel.hidden;
    if (!gPanel.hidden) [gRoot bringSubviewToFront:gPanel];
}
- (void)vxDoTab {
    gTab = (int)self.tag;
    for (int i = 0; i < 5; i++) gPages[i].hidden = (i != gTab);
}
- (void)vxDoCopy {
    [UIPasteboard generalPasteboard].string = gLog ?: @"";
    vxLog(@"[VEEX] log copiado");
}
- (void)vxDoClear {
    [gLog setString:@""];
    [[NSData data] writeToFile:vxLogPath() atomically:YES];
    if (gLogView) gLogView.text = @"";
}
- (void)vxDoReset {
    vxLog(@"[VEEX] RESET GUEST...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *q = @{ (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword };
        OSStatus st = SecItemDelete((__bridge CFDictionaryRef)q);
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *pref = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences"];
        for (NSString *f in [fm contentsOfDirectoryAtPath:pref error:nil]) {
            NSString *low = f.lowercaseString;
            if ([low containsString:@"freefire"] || [low containsString:@"com.dts."]) {
                [fm removeItemAtPath:[pref stringByAppendingPathComponent:f] error:nil];
            }
        }
        vxLog(@"[VEEX] RESET hecho (%d), cierra el juego", (int)st);
    });
}
- (void)vxDoRun {
    extern void runScript(void);
    vxLog(@"[VEEX] lanzando script...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        runScript();
    });
}
- (void)vxDoClose {
    gPanel.hidden = YES;
}
@end

// ============ UI HELPERS ============
static UISwitch *vxSw(NSString *key, BOOL on) {
    UISwitch *s = [UISwitch new];
    s.on = on;
    s.transform = CGAffineTransformMakeScale(0.72, 0.72);
    if (!gSw) gSw = [NSMutableDictionary new];
    gSw[key] = s;
    return s;
}
static BOOL vxOn(NSString *key) {
    UISwitch *s = gSw[key];
    return s ? s.isOn : NO;
}
static UIView *vxRow(NSString *title, UIView *ctl) {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    row.layer.cornerRadius = 10;
    UILabel *l = [UILabel new];
    l.text = title;
    l.textColor = [UIColor colorWithWhite:1 alpha:0.9];
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:l];
    [row addSubview:ctl];
    ctl.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [l.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [l.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [ctl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10],
        [ctl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:34],
    ]];
    return row;
}
static UIView *vxPage(void) {
    UIView *p = [UIView new];
    p.hidden = YES;
    return p;
}

// ============ MEMORIA ============
static uint64_t gBase = 0;
static uint64_t gSize = 0;

static void vxSetBase(const struct mach_header_64 *h) {
    if (!h || gBase) return;
    gBase = (uint64_t)h;
    const struct load_command *lc = (const struct load_command *)(h + 1);
    for (uint32_t k = 0; k < h->ncmds; k++) {
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *s = (const void *)lc;
            if (!strcmp(s->segname, "__TEXT")) { gSize = s->vmsize; break; }
        }
        lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
    }
}

static void vxFindImage(void) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (!nm || !strstr(nm, "UnityFramework")) continue;
        vxSetBase((const struct mach_header_64 *)_dyld_get_image_header(i));
        break;
    }
}

static void vxPatchCryptid(void) {
    uint32_t n = _dyld_image_count();
    int hechos = 0;
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (!nm) continue;
        if (strstr(nm, "Frameworks") || strstr(nm, ".framework")) continue;
        const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!h || h->magic != MH_MAGIC_64) continue;
        const struct load_command *lc = (const struct load_command *)(h + 1);
        for (uint32_t k = 0; k < h->ncmds; k++) {
            if (lc->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64 *e = (void *)lc;
                if (e->cryptid != 1) {
                    uint64_t pg = (uint64_t)e & ~0xFFFULL;
                    vm_protect(mach_task_self(), pg, 0x4000, false,
                               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                    uint32_t viejo = e->cryptid;
                    e->cryptid = 1;
                    vxLog(@"[VEEX] cryptid %u->1 %s", viejo, nm);
                    hechos++;
                }
                break;
            }
            lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
        }
    }
    vxLog(@"[VEEX] cryptid imgs=%d", hechos);
}

// ============ IL2CPP ============
static void *gUF = NULL;
static void *(*p_domain_get)(void) = NULL;
static void *(*p_domain_get_assemblies)(void *, size_t *) = NULL;
static void *(*p_assembly_get_image)(void *) = NULL;
static size_t (*p_image_get_class_count)(void *) = NULL;
static void *(*p_image_get_class)(void *, size_t) = NULL;
static const char *(*p_class_get_name)(void *) = NULL;
static void *(*p_class_get_method_from_name)(void *, const char *, int) = NULL;
static const char *(*p_method_get_name)(void *) = NULL;
static void *(*p_class_get_methods)(void *, void **) = NULL;
static void *(*p_runtime_invoke)(void *, void *, void **, void **) = NULL;
static void (*p_runtime_class_init)(void *) = NULL;
static void *(*p_thread_attach)(void *) = NULL;
static void *(*p_class_get_type)(void *) = NULL;
static void *(*p_type_get_object)(void *) = NULL;

static void vxLoadIL2CPP(void) {
    if (gUF) return;
    gUF = dlopen("@rpath/UnityFramework.framework/UnityFramework", RTLD_NOW);
    if (!gUF) gUF = dlopen("UnityFramework", RTLD_NOW);
    if (!gUF) { vxLog(@"[VEEX] dlopen UF fallo"); return; }
    p_domain_get                 = dlsym(gUF, "il2cpp_domain_get");
    p_domain_get_assemblies      = dlsym(gUF, "il2cpp_domain_get_assemblies");
    p_assembly_get_image         = dlsym(gUF, "il2cpp_assembly_get_image");
    p_image_get_class_count      = dlsym(gUF, "il2cpp_image_get_class_count");
    p_image_get_class            = dlsym(gUF, "il2cpp_image_get_class");
    p_class_get_name             = dlsym(gUF, "il2cpp_class_get_name");
    p_class_get_method_from_name = dlsym(gUF, "il2cpp_class_get_method_from_name");
    p_method_get_name            = dlsym(gUF, "il2cpp_method_get_name");
    p_class_get_methods          = dlsym(gUF, "il2cpp_class_get_methods");
    p_runtime_invoke             = dlsym(gUF, "il2cpp_runtime_invoke");
    p_runtime_class_init         = dlsym(gUF, "il2cpp_runtime_class_init");
    p_thread_attach              = dlsym(gUF, "il2cpp_thread_attach");
    p_class_get_type             = dlsym(gUF, "il2cpp_class_get_type");
    p_type_get_object            = dlsym(gUF, "il2cpp_type_get_object");
    vxLog(@"[VEEX] il2cpp %s", p_runtime_invoke ? "OK" : "PARCIAL");
}

static void vxInitClass(void *c) {
    if (c && p_runtime_class_init) p_runtime_class_init(c);
}

static void *vxFindClass(const char *name) {
    if (!p_domain_get || !p_runtime_invoke || !p_class_get_name) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(p_domain_get(), &n);
    for (size_t i = 0; i < n; i++) {
        void *img = p_assembly_get_image(as[i]);
        if (!img) continue;
        size_t cc = p_image_get_class_count(img);
        for (size_t j = 0; j < cc; j++) {
            void *c = p_image_get_class(img, j);
            const char *cn = p_class_get_name(c);
            if (cn && !strcmp(cn, name)) return c;
        }
    }
    return NULL;
}

#define VXP(x) ((void *)(uintptr_t)(x))

typedef struct { float x, y, z; } VXVec3;

static void *vxCode(void *mi) {
    if (!mi) return NULL;
    return *(void **)mi;
}

// ============ LUA ============
static lua_State *L = NULL;
static CADisplayLink *gLink = nil;

void vxPauseLink(BOOL p) { if (gLink) gLink.paused = p; }

static int l_log(lua_State *S) {
    const char *s = lua_tostring(S, 1);
    if (s) vxLog(@"[L] %s", s);
    return 0;
}
static int l_get(lua_State *S) {
    const char *k = lua_tostring(S, 1);
    lua_pushboolean(S, k ? vxOn([NSString stringWithUTF8String:k]) : 0);
    return 1;
}
static int l_pause(lua_State *S) { vxPauseLink(lua_toboolean(S, 1)); return 0; }
static int l_w32(lua_State *S) { *(uint32_t *)VXP(lua_tointeger(S,1)) = (uint32_t)lua_tointeger(S,2); return 0; }
static int l_wf(lua_State *S)  { *(float *)VXP(lua_tointeger(S,1)) = (float)lua_tonumber(S,2); return 0; }
static int l_r32(lua_State *S) { lua_pushinteger(S, *(uint32_t *)VXP(lua_tointeger(S,1))); return 1; }
static int l_rf(lua_State *S)  { lua_pushnumber(S, *(float *)VXP(lua_tointeger(S,1))); return 1; }

static int l_buf(lua_State *S) {
    size_t n = (size_t)lua_tointeger(S, 1);
    if (!n) n = 64;
    void *p = calloc(1, n);
    lua_pushinteger(S, (lua_Integer)(uintptr_t)p);
    return 1;
}
static int l_wv3(lua_State *S) {
    float *p = VXP(lua_tointeger(S, 1));
    p[0] = (float)lua_tonumber(S, 2);
    p[1] = (float)lua_tonumber(S, 3);
    p[2] = (float)lua_tonumber(S, 4);
    return 0;
}
static int l_rv3(lua_State *S) {
    float *p = VXP(lua_tointeger(S, 1));
    lua_pushnumber(S, p[0]); lua_pushnumber(S, p[1]); lua_pushnumber(S, p[2]);
    return 3;
}
static int l_sc(lua_State *S) { lua_pushnumber(S, [UIScreen mainScreen].scale); return 1; }
static int l_sw(lua_State *S) { lua_pushnumber(S, [UIScreen mainScreen].bounds.size.width); return 1; }
static int l_sh(lua_State *S) { lua_pushnumber(S, [UIScreen mainScreen].bounds.size.height); return 1; }

static int l_str(lua_State *S) {
    void *p = VXP(lua_tointeger(S, 1));
    if (!p) { lua_pushstring(S, ""); return 1; }
    int32_t len = *(int32_t *)((char *)p + 0x10);
    const uint16_t *u = (const uint16_t *)((char *)p + 0x14);
    char *o = malloc((size_t)len * 4 + 1);
    int k = 0;
    for (int i = 0; i < len; i++) {
        uint32_t c = u[i];
        if (c < 0x80) o[k++] = (char)c;
        else if (c < 0x800) { o[k++] = (char)(0xC0 | (c >> 6)); o[k++] = (char)(0x80 | (c & 0x3F)); }
        else { o[k++] = (char)(0xE0 | (c >> 12)); o[k++] = (char)(0x80 | ((c >> 6) & 0x3F)); o[k++] = (char)(0x80 | (c & 0x3F)); }
    }
    o[k] = 0;
    lua_pushstring(S, o);
    free(o);
    return 1;
}

static int l_pos3(lua_State *S) {
    void *code = vxCode(VXP(lua_tointeger(S, 1)));
    void *o = VXP(lua_tointeger(S, 2));
    VXVec3 r = {0, 0, 0};
    if (code) { VXVec3 (*fn)(void *) = (VXVec3 (*)(void *))code; r = fn(o); }
    lua_pushnumber(S, r.x); lua_pushnumber(S, r.y); lua_pushnumber(S, r.z);
    return 3;
}
static int l_w2s3(lua_State *S) {
    void *code = vxCode(VXP(lua_tointeger(S, 1)));
    void *o = VXP(lua_tointeger(S, 2));
    float x = (float)lua_tonumber(S, 3), y = (float)lua_tonumber(S, 4), z = (float)lua_tonumber(S, 5);
    VXVec3 r = {0, 0, 0};
    if (code) { VXVec3 (*fn)(void *, float, float, float) = (VXVec3 (*)(void *, float, float, float))code; r = fn(o, x, y, z); }
    lua_pushnumber(S, r.x); lua_pushnumber(S, r.y); lua_pushnumber(S, r.z);
    return 3;
}
static int l_calli(lua_State *S) {
    void *code = vxCode(VXP(lua_tointeger(S, 1)));
    void *o = VXP(lua_tointeger(S, 2));
    int r = 0;
    if (code) { int (*fn)(void *) = (int (*)(void *))code; r = fn(o); }
    lua_pushinteger(S, r);
    return 1;
}
static int l_callf(lua_State *S) {
    void *code = vxCode(VXP(lua_tointeger(S, 1)));
    void *o = VXP(lua_tointeger(S, 2));
    float r = 0;
    if (code) { float (*fn)(void *) = (float (*)(void *))code; r = fn(o); }
    lua_pushnumber(S, r);
    return 1;
}

static int l_clsinit(lua_State *S) { vxInitClass(VXP(lua_tointeger(S, 1))); return 0; }
static int l_clstype(lua_State *S) {
    void *c = VXP(lua_tointeger(S, 1));
    vxInitClass(c);
    void *t = (c && p_class_get_type) ? p_class_get_type(c) : NULL;
    void *o = (t && p_type_get_object) ? p_type_get_object(t) : NULL;
    if (o) lua_pushinteger(S, (lua_Integer)(uintptr_t)o); else lua_pushnil(S);
    return 1;
}

static int l_i2c_cls(lua_State *S) {
    const char *n = lua_tostring(S, 1);
    void *c = n ? vxFindClass(n) : NULL;
    if (c) lua_pushinteger(S, (lua_Integer)(uintptr_t)c); else lua_pushnil(S);
    return 1;
}
static int l_i2c_classes(lua_State *S) {
    lua_newtable(S);
    if (!p_domain_get || !p_class_get_name) return 1;
    size_t n = 0; int idx = 1;
    void **as = p_domain_get_assemblies(p_domain_get(), &n);
    for (size_t i = 0; i < n; i++) {
        void *img = p_assembly_get_image(as[i]);
        if (!img) continue;
        size_t cc = p_image_get_class_count(img);
        for (size_t j = 0; j < cc; j++) {
            const char *cn = p_class_get_name(p_image_get_class(img, j));
            if (!cn) continue;
            lua_pushstring(S, cn);
            lua_rawseti(S, -2, idx++);
            if (idx > 40000) return 1;
        }
    }
    return 1;
}
static int l_i2c_methods(lua_State *S) {
    const char *n = lua_tostring(S, 1);
    void *c = n ? vxFindClass(n) : NULL;
    lua_newtable(S);
    if (!c || !p_class_get_methods || !p_method_get_name) return 1;
    void *iter = NULL; void *m = NULL; int idx = 1;
    while ((m = p_class_get_methods(c, &iter)) != NULL && idx < 8000) {
        const char *mn = p_method_get_name(m);
        if (mn) { lua_pushstring(S, mn); lua_rawseti(S, -2, idx++); }
    }
    return 1;
}
static int l_i2c_ptr(lua_State *S) {
    const char *cn = lua_tostring(S, 1);
    const char *mn = lua_tostring(S, 2);
    int argc = (int)lua_tointeger(S, 3);
    void *c = cn ? vxFindClass(cn) : NULL;
    if (!c) { lua_pushnil(S); return 1; }
    vxInitClass(c);
    void *m = p_class_get_method_from_name(c, mn, argc);
    if (m) lua_pushinteger(S, (lua_Integer)(uintptr_t)m); else lua_pushnil(S);
    return 1;
}
static int l_i2c_clsall(lua_State *S) {
    const char *n = lua_tostring(S, 1);
    lua_newtable(S);
    if (!n || !p_domain_get || !p_class_get_name) return 1;
    size_t cnt = 0; int idx = 1;
    void **as = p_domain_get_assemblies(p_domain_get(), &cnt);
    for (size_t i = 0; i < cnt; i++) {
        void *img = p_assembly_get_image(as[i]);
        if (!img) continue;
        size_t cc = p_image_get_class_count(img);
        for (size_t j = 0; j < cc; j++) {
            void *c = p_image_get_class(img, j);
            const char *cn = p_class_get_name(c);
            if (cn && !strcmp(cn, n)) {
                lua_pushinteger(S, (lua_Integer)(uintptr_t)c);
                lua_rawseti(S, -2, idx++);
                if (idx > 50) return 1;
            }
        }
    }
    return 1;
}
static int l_i2c_cname(lua_State *S) {
    void *c = VXP(lua_tointeger(S, 1));
    const char *n = (c && p_class_get_name) ? p_class_get_name(c) : NULL;
    lua_pushstring(S, n ? n : "?");
    return 1;
}
static int l_i2c_mnames(lua_State *S) {
    void *c = VXP(lua_tointeger(S, 1));
    lua_newtable(S);
    if (!c || !p_class_get_methods || !p_method_get_name) return 1;
    void *it = NULL; void *m = NULL; int idx = 1;
    while ((m = p_class_get_methods(c, &it)) != NULL && idx < 400) {
        const char *mn = p_method_get_name(m);
        if (mn) { lua_pushstring(S, mn); lua_rawseti(S, -2, idx++); }
    }
    return 1;
}
static int l_i2c_mptr(lua_State *S) {
    void *c = VXP(lua_tointeger(S, 1));
    const char *mn = lua_tostring(S, 2);
    int argc = (int)lua_tointeger(S, 3);
    if (!c) { lua_pushnil(S); return 1; }
    vxInitClass(c);
    void *m = p_class_get_method_from_name ? p_class_get_method_from_name(c, mn, argc) : NULL;
    if (m) lua_pushinteger(S, (lua_Integer)(uintptr_t)m); else lua_pushnil(S);
    return 1;
}

static int l_call(lua_State *S) {
    void *m = VXP(lua_tointeger(S,1)), *o = VXP(lua_tointeger(S,2)), *exc = NULL;
    void *r = p_runtime_invoke(m, o, NULL, &exc);
    if (r) lua_pushinteger(S, (lua_Integer)(uintptr_t)r); else lua_pushnil(S);
    return 1;
}
static int l_callv(lua_State *S) {
    void *m = VXP(lua_tointeger(S,1)), *o = VXP(lua_tointeger(S,2)), *exc = NULL;
    void *a[1] = { VXP(lua_tointeger(S,3)) };
    void *r = p_runtime_invoke(m, o, a, &exc);
    if (r) lua_pushinteger(S, (lua_Integer)(uintptr_t)r); else lua_pushnil(S);
    return 1;
}
static int l_arrlen(lua_State *S) { lua_pushinteger(S, *(uint64_t *)((char *)VXP(lua_tointeger(S,1)) + 24)); return 1; }
static int l_arrat(lua_State *S) {
    void *a = VXP(lua_tointeger(S,1));
    uint64_t i = lua_tointeger(S,2);
    lua_pushinteger(S, *(uint64_t *)((char *)a + 32 + 8 * i));
    return 1;
}
static int l_scan(lua_State *S) {
    const char *pat = lua_tostring(S, 1);
    lua_newtable(S);
    if (!pat || !gBase) return 1;
    unsigned char bytes[64]; int wild[64]; int n = 0;
    const char *p = pat;
    while (*p && n < 64) {
        while (*p == ' ') p++;
        if (!*p) break;
        if (p[0] == '?' && p[1] == '?') { wild[n] = 1; bytes[n] = 0; p += 2; }
        else { wild[n] = 0; bytes[n] = (unsigned char)strtoul(p, (char **)&p, 16); }
        n++;
    }
    if (!n) return 1;
    int idx = 1;
    unsigned char *b = (unsigned char *)gBase;
    for (uint64_t o = 0; o + n < gSize; o++) {
        int ok = 1;
        for (int k = 0; k < n; k++) if (!wild[k] && b[o+k] != bytes[k]) { ok = 0; break; }
        if (ok) {
            lua_pushinteger(S, (lua_Integer)(gBase + o));
            lua_rawseti(S, -2, idx++);
            if (idx > 200) break;
        }
    }
    return 1;
}
static int l_clear(lua_State *S) { [gCanvas.cmds removeAllObjects]; return 0; }
static UIColor *vxCol(lua_State *S, int base) {
    if (lua_gettop(S) >= base + 3)
        return [UIColor colorWithRed:lua_tonumber(S,base) green:lua_tonumber(S,base+1)
                               blue:lua_tonumber(S,base+2) alpha:lua_tonumber(S,base+3)];
    return [UIColor redColor];
}
static int l_rect(lua_State *S) {
    CGRect r = CGRectMake(lua_tonumber(S,1), lua_tonumber(S,2), lua_tonumber(S,3), lua_tonumber(S,4));
    [gCanvas.cmds addObject:@[@"rect", NSStringFromCGRect(r), vxCol(S, 5)]];
    return 0;
}
static int l_fill(lua_State *S) {
    CGRect r = CGRectMake(lua_tonumber(S,1), lua_tonumber(S,2), lua_tonumber(S,3), lua_tonumber(S,4));
    [gCanvas.cmds addObject:@[@"fill", NSStringFromCGRect(r), vxCol(S, 5)]];
    return 0;
}
static int l_line(lua_State *S) {
    CGPoint a = CGPointMake(lua_tonumber(S,1), lua_tonumber(S,2));
    CGPoint b = CGPointMake(lua_tonumber(S,3), lua_tonumber(S,4));
    [gCanvas.cmds addObject:@["line", NSStringFromCGPoint(a), NSStringFromCGPoint(b), vxCol(S, 5)]];
    return 0;
}
static int l_text(lua_State *S) {
    const char *t = lua_tostring(S, 1);
    CGPoint p = CGPointMake(lua_tonumber(S,2), lua_tonumber(S,3));
    [gCanvas.cmds addObject:@[@"text", [NSString stringWithUTF8String:t ?: ""], NSStringFromCGPoint(p), vxCol(S, 4)]];
    return 0;
}

static void vxTick(void) {
    if (!L) return;
    @autoreleasepool {
        lua_getglobal(L, "tick");
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
                const char *e = lua_tostring(L, -1);
                if (e) vxLog(@"[L] tick err: %s", e);
                lua_pop(L, 1);
            }
        } else lua_pop(L, 1);
        [gCanvas setNeedsDisplay];
    }
}

static void vxReg(lua_State *S) {
    lua_register(S, "log", l_log);
    lua_register(S, "get", l_get);
    lua_register(S, "pause", l_pause);
    lua_register(S, "w32", l_w32);
    lua_register(S, "wf", l_wf);
    lua_register(S, "r32", l_r32);
    lua_register(S, "rf", l_rf);
    lua_register(S, "buf", l_buf);
    lua_register(S, "wv3", l_wv3);
    lua_register(S, "rv3", l_rv3);
    lua_register(S, "sc", l_sc);
    lua_register(S, "sw", l_sw);
    lua_register(S, "sh", l_sh);
    lua_register(S, "str", l_str);
    lua_register(S, "scan", l_scan);
    lua_register(S, "pos3", l_pos3);
    lua_register(S, "w2s3", l_w2s3);
    lua_register(S, "calli", l_calli);
    lua_register(S, "callf", l_callf);
    lua_register(S, "clsinit", l_clsinit);
    lua_register(S, "clstype", l_clstype);
    lua_register(S, "i2c_cls", l_i2c_cls);
    lua_register(S, "i2c_classes", l_i2c_classes);
    lua_register(S, "i2c_methods", l_i2c_methods);
    lua_register(S, "i2c_ptr", l_i2c_ptr);
    lua_register(S, "i2c_clsall", l_i2c_clsall);
    lua_register(S, "i2c_cname", l_i2c_cname);
    lua_register(S, "i2c_mnames", l_i2c_mnames);
    lua_register(S, "i2c_mptr", l_i2c_mptr);
    lua_register(S, "call", l_call);
    lua_register(S, "callv", l_callv);
    lua_register(S, "arrlen", l_arrlen);
    lua_register(S, "arrat", l_arrat);
    lua_register(S, "clear", l_clear);
    lua_register(S, "rect", l_rect);
    lua_register(S, "fill", l_fill);
    lua_register(S, "line", l_line);
    lua_register(S, "text", l_text);
}

static NSData *vxFetch(NSString *url, NSString *accept) {
    NSMutableURLRequest *rq =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                            timeoutInterval:20];
    [rq setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    if (accept) [rq setValue:accept forHTTPHeaderField:@"Accept"];
    __block NSData *got = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionDataTask *t = [[NSURLSession sharedSession]
        dataTaskWithRequest:rq
          completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            got = d;
            if (e) vxLog(@"[VEEX] err %@", e.localizedDescription);
            dispatch_semaphore_signal(sem);
        }];
    [t resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC));
    return got;
}

void runScript(void) {
    int t = (int)[NSDate date].timeIntervalSince1970;
    NSData *got = vxFetch([NSString stringWithFormat:@"%@?ref=main&t=%d", SCRIPT_API, t],
                          @"application/vnd.github.raw");
    if (!got || got.length < 20) {
        got = vxFetch([NSString stringWithFormat:@"%@?t=%d", SCRIPT_RAW, t], nil);
    }
    if (!got || got.length < 20) { vxLog(@"[VEEX] descarga fallo"); return; }

    NSString *txt = [[NSString alloc] initWithData:got encoding:NSUTF8StringEncoding];
    NSString *first = txt ? [txt componentsSeparatedByString:@"\n"].firstObject : @"?";
    vxLog(@"[VEEX] %lu bytes | %@", (unsigned long)got.length, first);

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"veex_esp.lua"];
    [got writeToFile:tmp atomically:YES];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (p_thread_attach && p_domain_get) p_thread_attach(p_domain_get());
        if (L) { lua_close(L); L = NULL; }
        L = luaL_newstate();
        luaL_openlibs(L);
        vxReg(L);
        lua_pushinteger(L, (lua_Integer)gBase);
        lua_setglobal(L, "BASE");
        if (luaL_dofile(L, tmp.fileSystemRepresentation) != LUA_OK) {
            const char *e = lua_tostring(L, -1);
            vxLog(@"[L] load err: %s", e ? e : "?");
            return;
        }
        vxLog(@"[VEEX] script cargado");
        if (!gLink) {
            CADisplayLink *ln = [CADisplayLink displayLinkWithTarget:[NSBlockOperation blockOperationWithBlock:^{ vxTick(); }]
                                                           selector:@selector(main)];
            ln.preferredFramesPerSecond = VX_FPS;
            gLink = ln;
            [ln addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        } else {
            gLink.paused = NO;
        }
    });
}

// ============ HOOKS ============
static uint32_t (*o_dyld_image_count)(void) = NULL;
static const char *(*o_dyld_get_image_name)(uint32_t) = NULL;
static const struct mach_header *(*o_dyld_get_image_header)(uint32_t) = NULL;
static intptr_t (*o_dyld_get_image_vmaddr_slide)(uint32_t) = NULL;
static int (*o_csops)(pid_t, unsigned int, void *, size_t) = NULL;
static int (*o_sysctl)(int *, u_int, void *, size_t *, void *, size_t) = NULL;
static int (*o_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;
static OSStatus (*o_sscv)(void *, uint32_t, void *) = NULL;
static OSStatus (*o_sscvw)(void *, uint32_t, void *, CFErrorRef *) = NULL;
static OSStatus (*o_scv)(void *, uint32_t, void *) = NULL;
static OSStatus (*o_scvw)(void *, uint32_t, void *, CFErrorRef *) = NULL;
static CFTypeRef (*o_stcve)(void *, CFStringRef, CFErrorRef *) = NULL;

static unsigned char *(*o_md5)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *(*o_sha1)(const void *, CC_LONG, unsigned char *) = NULL;
static unsigned char *(*o_sha256)(const void *, CC_LONG, unsigned char *) = NULL;

static uint32_t gMyIdx = 0xFFFFFFFFu;
static uint64_t gMainHdr = 0;

static uint32_t h_dyld_image_count(void) {
    uint32_t n = o_dyld_image_count ? o_dyld_image_count() : 0;
    if (gMyIdx != 0xFFFFFFFFu && n > 0) n--;
    return n;
}
static const char *h_dyld_get_image_name(uint32_t i) {
    if (gMyIdx != 0xFFFFFFFFu && i >= gMyIdx) i++;
    return o_dyld_get_image_name ? o_dyld_get_image_name(i) : NULL;
}
static const struct mach_header *h_dyld_get_image_header(uint32_t i) {
    if (gMyIdx != 0xFFFFFFFFu && i >= gMyIdx) i++;
    return o_dyld_get_image_header ? o_dyld_get_image_header(i) : NULL;
}
static intptr_t h_dyld_get_image_vmaddr_slide(uint32_t i) {
    if (gMyIdx != 0xFFFFFFFFu && i >= gMyIdx) i++;
    return o_dyld_get_image_vmaddr_slide ? o_dyld_get_image_vmaddr_slide(i) : 0;
}

static int h_csops(pid_t pid, unsigned int op, void *buf, size_t sz) {
    int r = o_csops ? o_csops(pid, op, buf, sz) : -1;
    if (r == 0 && op == VX_CS_OPS_STATUS && buf) {
        uint32_t f = *(uint32_t *)buf;
        f |= (VX_CS_VALID | VX_CS_HARD);
        f &= ~(VX_CS_DEBUGGED | VX_CS_GET_TASK_ALLOW);
        *(uint32_t *)buf = f;
    }
    return r;
}

static void vxClearTraced(void *buf, size_t *len) {
    if (!buf || !len || *len < (VX_PFLAG_OFF + 4)) return;
    int *pf = (int *)((char *)buf + VX_PFLAG_OFF);
    *pf &= ~VX_P_TRACED;
}

static int h_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int r = o_sysctl ? o_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
    if (r == 0 && name && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC)
        vxClearTraced(oldp, oldlenp);
    return r;
}

static int h_sysctlbyname(const char *nm, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int r = o_sysctlbyname ? o_sysctlbyname(nm, oldp, oldlenp, newp, newlen) : -1;
    if (r == 0 && nm && !strncmp(nm, "kern.proc", 9)) vxClearTraced(oldp, oldlenp);
    return r;
}

static OSStatus h_sscv(void *c, uint32_t f, void *req) {
    if (o_sscv) o_sscv(c, f, req);
    return 0;
}
static OSStatus h_sscvw(void *c, uint32_t f, void *req, CFErrorRef *e) {
    if (o_sscvw) o_sscvw(c, f, req, e);
    return 0;
}
static OSStatus h_scv(void *c, uint32_t f, void *req) {
    if (o_scv) o_scv(c, f, req);
    return 0;
}
static OSStatus h_scvw(void *c, uint32_t f, void *req, CFErrorRef *e) {
    if (o_scvw) o_scvw(c, f, req, e);
    return 0;
}

static CFTypeRef h_stcve(void *task, CFStringRef ent, CFErrorRef *e) {
    CFTypeRef v = o_stcve ? o_stcve(task, ent, e) : NULL;
    if (ent) {
        if (CFEqual(ent, CFSTR("get-task-allow"))) {
            if (v) CFRelease(v);
            return CFRetain(kCFBooleanFalse);
        }
        if (CFEqual(ent, CFSTR("beta-reports-active"))) {
            if (v) CFRelease(v);
            return CFRetain(kCFBooleanTrue);
        }
        if (CFEqual(ent, CFSTR("application-identifier"))) {
            if (v) CFRelease(v);
            return CFStringCreateWithCString(kCFAllocatorDefault, VX_APPID, kCFStringEncodingUTF8);
        }
        if (CFEqual(ent, CFSTR("com.apple.developer.team-identifier"))) {
            if (v) CFRelease(v);
            return CFStringCreateWithCString(kCFAllocatorDefault, VX_TEAM, kCFStringEncodingUTF8);
        }
    }
    return v;
}

// ===== digest: devolver el oficial cuando el input es el que importa =====
static unsigned char *h_md5(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_md5 ? o_md5(d, len, md) : NULL;
    if (r && d && len == 29 && !memcmp(d, "com.dts.freefireth_", 19)) {
        vxHex(VX_MD5ID, md, 16);
        vxLog(@"[VEEX] md5 id forzado");
    }
    return r;
}

static unsigned char *h_sha1(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_sha1 ? o_sha1(d, len, md) : NULL;
    if (r && d && len > 20) {
        const unsigned char *b = (const unsigned char *)d;
        if (b[0] == 0xfa && b[1] == 0xde && b[2] == 0x0c && b[3] == 0x02) {
            vxHex(VX_CD, md, 20);
            vxLog(@"[VEEX] cdhash forzado");
        }
    }
    return r;
}

static unsigned char *h_sha256(const void *d, CC_LONG len, unsigned char *md) {
    unsigned char *r = o_sha256 ? o_sha256(d, len, md) : NULL;
    if (r && d && (uint64_t)d == gMainHdr) {
        vxHex(VX_H, md, 32);
        vxLog(@"[VEEX] h forzado len=%u", (unsigned)len);
    }
    return r;
}

// ===== App Attest: fingir que el dispositivo no lo soporta =====
static BOOL vxNoSupport(id self, SEL _cmd) { return NO; }

static void vxAttestFail(id self, SEL _cmd, id a, id b, void (^h)(id, id)) {
    if (h) h([NSData data], [NSError errorWithDomain:@"DCAppAttestErrorDomain" code:1 userInfo:nil]);
}

static void vxKillAttest(void) {
    dlopen("/System/Library/Frameworks/DeviceCheck.framework/DeviceCheck", RTLD_NOW);
    Class c = objc_getClass("DCAppAttestService");
    if (!c) { vxLog(@"[VEEX] sin DCAppAttestService"); return; }
    int n = 0;
    Method m = class_getClassMethod(c, @selector(isSupported));
    if (!m) m = class_getInstanceMethod(c, @selector(isSupported));
    if (m) { method_setImplementation(m, (IMP)vxNoSupport); n++; }
    m = class_getInstanceMethod(c, NSSelectorFromString(@"attestKey:clientDataHash:completionHandler:"));
    if (m) { method_setImplementation(m, (IMP)vxAttestFail); n++; }
    m = class_getInstanceMethod(c, NSSelectorFromString(@"generateAssertion:clientDataHash:completionHandler:"));
    if (m) { method_setImplementation(m, (IMP)vxAttestFail); n++; }
    vxLog(@"[VEEX] attest swz=%d", n);
}

// ===== huella: qué puede leer el juego de su propia firma =====
static void vxFingerprint(void) {
    NSBundle *b = [NSBundle mainBundle];
    vxLog(@"[VEEX] bundle=%@", b.bundleIdentifier);
    vxLog(@"[VEEX] exe=%@", b.executablePath);

    void *sec = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    if (!sec) { vxLog(@"[VEEX] sin Security"); return; }
    void *(*cfs)(CFAllocatorRef) =
        (void *(*)(CFAllocatorRef))dlsym(sec, "SecTaskCreateFromSelf");
    CFTypeRef (*cvfe)(void *, CFStringRef, CFErrorRef *) =
        (CFTypeRef (*)(void *, CFStringRef, CFErrorRef *))dlsym(sec, "SecTaskCopyValueForEntitlement");
    if (!cfs || !cvfe) { vxLog(@"[VEEX] sin SecTask"); return; }
    void *t = cfs(kCFAllocatorDefault);
    if (!t) { vxLog(@"[VEEX] sin task"); return; }

    const char *keys[] = { "application-identifier", "com.apple.developer.team-identifier",
                           "get-task-allow", "beta-reports-active", "aps-environment" };
    for (int i = 0; i < 5; i++) {
        CFStringRef k = CFStringCreateWithCString(kCFAllocatorDefault, keys[i], kCFStringEncodingUTF8);
        CFTypeRef v = cvfe(t, k, NULL);
        vxLog(@"[VEEX] ent %s=%@", keys[i], v ? (__bridge id)v : @"(nil)");
        if (v) CFRelease(v);
        CFRelease(k);
    }
    CFRelease(t);
}

static void vxFindSelf(void) {
    Dl_info di;
    if (!dladdr((void *)&vxFindSelf, &di) || !di.dli_fbase) return;
    if (!o_dyld_image_count || !o_dyld_get_image_header) return;
    uint32_t n = o_dyld_image_count();
    for (uint32_t k = 0; k < n; k++) {
        if ((const void *)o_dyld_get_image_header(k) == di.dli_fbase) { gMyIdx = k; return; }
    }
}

static void vxPatchLoadName(void) {
    if (!o_dyld_image_count || !o_dyld_get_image_header) return;
    uint32_t n = o_dyld_image_count();
    size_t fakeLen = strlen(VX_FAKE);
    for (uint32_t k = 0; k < n; k++) {
        const struct mach_header_64 *h = (const void *)o_dyld_get_image_header(k);
        if (!h) continue;
        const struct load_command *lc = (const struct load_command *)(h + 1);
        for (uint32_t c = 0; c < h->ncmds; c++) {
            if (lc->cmd == LC_LOAD_DYLIB || lc->cmd == LC_ID_DYLIB) {
                struct dylib_command *d = (struct dylib_command *)lc;
                char *nm = (char *)lc + d->dylib.name.offset;
                if (strstr(nm, "libAudioEngine") || strstr(nm, "veex")) {
                    size_t cur = strlen(nm);
                    if (cur >= fakeLen) {
                        uint64_t pg = (uint64_t)nm & ~0xFFFULL;
                        vm_protect(mach_task_self(), pg, 0x4000, false,
                                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                        memset(nm, 0, cur);
                        memcpy(nm, VX_FAKE, fakeLen);
                        vxLog(@"[VEEX] load name oculto");
                    }
                }
            }
            lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
        }
    }
}

static void vxInstallHooks(void) {
    vxHookName("_dyld_image_count",            (void *)h_dyld_image_count,            (void **)&o_dyld_image_count);
    vxHookName("_dyld_get_image_name",         (void *)h_dyld_get_image_name,         (void **)&o_dyld_get_image_name);
    vxHookName("_dyld_get_image_header",       (void *)h_dyld_get_image_header,       (void **)&o_dyld_get_image_header);
    vxHookName("_dyld_get_image_vmaddr_slide", (void *)h_dyld_get_image_vmaddr_slide, (void **)&o_dyld_get_image_vmaddr_slide);
    vxHookName("csops",                        (void *)h_csops,                       (void **)&o_csops);
    vxHookName("sysctl",                       (void *)h_sysctl,                      (void **)&o_sysctl);
    vxHookName("sysctlbyname",                 (void *)h_sysctlbyname,                (void **)&o_sysctlbyname);
    vxHookName("SecStaticCodeCheckValidity",           (void *)h_sscv,  (void **)&o_sscv);
    vxHookName("SecStaticCodeCheckValidityWithErrors", (void *)h_sscvw, (void **)&o_sscvw);
    vxHookName("SecCodeCheckValidity",                 (void *)h_scv,   (void **)&o_scv);
    vxHookName("SecCodeCheckValidityWithErrors",       (void *)h_scvw,  (void **)&o_scvw);
    vxHookName("SecTaskCopyValueForEntitlement",       (void *)h_stcve, (void **)&o_stcve);
    vxHookName("CC_MD5",                       (void *)h_md5,                         (void **)&o_md5);
    vxHookName("CC_SHA1",                      (void *)h_sha1,                        (void **)&o_sha1);
    vxHookName("CC_SHA256",                    (void *)h_sha256,                      (void **)&o_sha256);

    vxFindSelf();
    vxPatchLoadName();
    vxKillAttest();
    if (o_dyld_get_image_header) gMainHdr = (uint64_t)o_dyld_get_image_header(0);
    vxLog(@"[VEEX] hooked=%d idx=%u main=%llx", gHooked, gMyIdx, gMainHdr);
    vxFingerprint();
}

// ============ UI BUILD ============
static UIWindow *vxHostWindow(void) {
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (kw) return kw;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.isHidden && w.bounds.size.width > 100) return w;
    }
    return nil;
}

static void vxAttach(void) {
    if (!gRoot) return;
    UIWindow *h = vxHostWindow();
    if (!h) return;
    if (gRoot.superview == h) return;
    gRoot.frame = h.bounds;
    gRoot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [h addSubview:gRoot];
    [h bringSubviewToFront:gRoot];
}

static void buildUI(void) {
    if (gPanel) return;

    gLog = [NSMutableString new];
    NSString *prev = [NSString stringWithContentsOfFile:vxLogPath() encoding:NSUTF8StringEncoding error:nil];
    if (prev.length) {
        if (prev.length > 9000) prev = [prev substringFromIndex:prev.length - 9000];
        [gLog appendString:@"--- anterior ---\n"];
        [gLog appendString:prev];
    }

    gRoot = [[VXRoot alloc] initWithFrame:CGRectMake(0, 0, 320, 568)];
    gRoot.backgroundColor = [UIColor clearColor];
    vxAttach();
    if (!gRoot.superview) return;

    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *tm) {
        vxAttach();
    }];

    gCanvas = [[VXCanvas alloc] initWithFrame:gRoot.bounds];
    gCanvas.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [gRoot addSubview:gCanvas];

    UIButton *fab = [UIButton buttonWithType:UIButtonTypeCustom];
    fab.frame = CGRectMake(14, 96, 46, 46);
    fab.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    fab.layer.cornerRadius = 23;
    fab.layer.borderWidth = 1;
    fab.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    [fab setTitle:@"VX" forState:UIControlStateNormal];
    fab.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [fab addTarget:fab action:@selector(vxDoTap) forControlEvents:UIControlEventTouchUpInside];
    [gRoot addSubview:fab];
    gFab = fab;

    CGSize scr = gRoot.bounds.size;
    CGFloat ph = MIN(452.0, scr.height - 90.0);
    gPanel = [[UIView alloc] initWithFrame:CGRectMake((scr.width - 300) / 2, 50, 300, ph)];
    gPanel.hidden = YES;
    gPanel.layer.cornerRadius = 20;
    gPanel.clipsToBounds = YES;
    [gRoot addSubview:gPanel];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.frame = gPanel.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [gPanel addSubview:blur];

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:gPanel.bounds];
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sv.contentSize = CGSizeMake(300, 452);
    sv.showsVerticalScrollIndicator = NO;
    sv.alwaysBounceVertical = YES;
    [gPanel addSubview:sv];

    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 452)];
    [sv addSubview:content];

    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
    head.backgroundColor = [UIColor clearColor];
    [content addSubview:head];
    if (!gPan) gPan = [VXPan new];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:gPan action:@selector(handle:)];
    [head addGestureRecognizer:pan];

    UILabel *title = [UILabel new];
    title.text = @"VEEX";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightHeavy];
    title.frame = CGRectMake(16, 8, 120, 24);
    [head addSubview:title];

    UIButton *x = [UIButton buttonWithType:UIButtonTypeCustom];
    x.frame = CGRectMake(258, 6, 30, 30);
    [x setTitle:@"✕" forState:UIControlStateNormal];
    [x setTitleColor:[UIColor colorWithWhite:1 alpha:0.7] forState:UIControlStateNormal];
    [x addTarget:x action:@selector(vxDoClose) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:x];

    NSArray *names = @[@"ESP", @"AIM", @"DRAW", @"MISC", @"SET"];
    UIStackView *tabs = [[UIStackView alloc] initWithFrame:CGRectMake(12, 44, 276, 30)];
    tabs.distribution = UIStackViewDistributionFillEqually;
    tabs.spacing = 6;
    [content addSubview:tabs];
    for (int i = 0; i < 5; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        [b setTitle:names[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        b.layer.cornerRadius = 8;
        [b addTarget:b action:@selector(vxDoTab) forControlEvents:UIControlEventTouchUpInside];
        [tabs addArrangedSubview:b];
    }

    UIView *holder = [[UIView alloc] initWithFrame:CGRectMake(12, 82, 276, 236)];
    [content addSubview:holder];
    for (int i = 0; i < 5; i++) {
        gPages[i] = vxPage();
        gPages[i].frame = holder.bounds;
        [holder addSubview:gPages[i]];
    }
    gPages[0].hidden = NO;

    UIStackView *p0 = [[UIStackView alloc] initWithFrame:gPages[0].bounds];
    p0.axis = UILayoutConstraintAxisVertical; p0.spacing = 5;
    [gPages[0] addSubview:p0];
    [p0 addArrangedSubview:vxRow(@"ESP activo", vxSw(@"esp", YES))];
    [p0 addArrangedSubview:vxRow(@"Cajas",      vxSw(@"box", YES))];
    [p0 addArrangedSubview:vxRow(@"Línea",      vxSw(@"line", YES))];
    [p0 addArrangedSubview:vxRow(@"Nombre",     vxSw(@"name", YES))];
    [p0 addArrangedSubview:vxRow(@"Distancia",  vxSw(@"dist", YES))];
    [p0 addArrangedSubview:vxRow(@"Salud",      vxSw(@"hp", YES))];

    UIStackView *p1 = [[UIStackView alloc] initWithFrame:gPages[1].bounds];
    p1.axis = UILayoutConstraintAxisVertical; p1.spacing = 5;
    [gPages[1] addSubview:p1];
    [p1 addArrangedSubview:vxRow(@"Aimbot",     vxSw(@"aim", NO))];
    [p1 addArrangedSubview:vxRow(@"FOV 4°",     vxSw(@"aimfov", YES))];
    [p1 addArrangedSubview:vxRow(@"Suave 0.30", vxSw(@"aimsmooth", YES))];

    UIStackView *p2 = [[UIStackView alloc] initWithFrame:gPages[2].bounds];
    p2.axis = UILayoutConstraintAxisVertical; p2.spacing = 5;
    [gPages[2] addSubview:p2];
    [p2 addArrangedSubview:vxRow(@"Esqueleto",  vxSw(@"skel", NO))];

    UIStackView *p3 = [[UIStackView alloc] initWithFrame:gPages[3].bounds];
    p3.axis = UILayoutConstraintAxisVertical; p3.spacing = 5;
    [gPages[3] addSubview:p3];

    UIStackView *p4 = [[UIStackView alloc] initWithFrame:gPages[4].bounds];
    p4.axis = UILayoutConstraintAxisVertical; p4.spacing = 5;
    [gPages[4] addSubview:p4];

    gLogView = [[UITextView alloc] initWithFrame:CGRectMake(12, 326, 276, 72)];
    gLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    gLogView.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    gLogView.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    gLogView.editable = NO;
    gLogView.layer.cornerRadius = 8;
    [content addSubview:gLogView];
    gLogView.text = gLog;

    NSArray *acts = @[@"COPIAR", @"LIMPIAR", @"RUN", @"RESET", @"CERRAR"];
    SEL sels[5] = { @selector(vxDoCopy), @selector(vxDoClear), @selector(vxDoRun),
                    @selector(vxDoReset), @selector(vxDoClose) };
    UIStackView *foot = [[UIStackView alloc] initWithFrame:CGRectMake(12, 408, 276, 32)];
    foot.distribution = UIStackViewDistributionFillEqually;
    foot.spacing = 5;
    [content addSubview:foot];
    for (int i = 0; i < 5; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:acts[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
        b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
        b.layer.cornerRadius = 8;
        [b addTarget:b action:sels[i] forControlEvents:UIControlEventTouchUpInside];
        [foot addArrangedSubview:b];
    }
    vxLog(@"[VEEX] UI lista");
}

// ============ ARRANQUE ============
static void boot(double delay) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        buildUI();
    });
}

__attribute__((constructor)) static void vxInit(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            if (!gLog) gLog = [NSMutableString new];
            vxLog(@"[VEEX] init stage=%d", VX_STAGE);
            vxLoadIL2CPP();

            for (int i = 0; i < 40 && !gBase; i++) {
                vxFindImage();
                if (!gBase) [NSThread sleepForTimeInterval:0.5];
            }
            if (!gBase && p_domain_get) {
                Dl_info di;
                if (dladdr((void *)p_domain_get, &di) && di.dli_fbase)
                    vxSetBase((const struct mach_header_64 *)di.dli_fbase);
            }
            vxLog(@"[VEEX] base=%llx size=%llx", gBase, gSize);

#if VX_STAGE >= 3
            vxInstallHooks();
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
