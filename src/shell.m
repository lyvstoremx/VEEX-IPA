#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <dlfcn.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "fishhook.h"

#define SCRIPT_URL "https://raw.githubusercontent.com/lyvstoremx/VEEX-IPA/main/scripts/esp.lua"
#define REF_URL "https://raw.githubusercontent.com/lyvstoremx/VEEX-IPA/main/FreeFire1_v6.dylib"
#define MAXLBL 128

static UIWindow *gWin; static UIView *gRoot;
static UIButton *gBtn; static UIView *gPanel; static UITextView *gLogView;
static UIView *gContent; static NSMutableArray *gTabBtns;
static UILabel *gLbl[MAXLBL]; static int gUsed;
static lua_State *gL; static NSString *gDocs;
static CGRect gBtnR, gPanelR; static int gOpen; static int gTab;
static NSString *gIDFV;
static uint64_t gBase, gSize;
static NSMutableDictionary *gCfg;

typedef void *(*f_dom)(void);
typedef void *(*f_att)(void *);
typedef void *(*f_asms)(void *, size_t *);
typedef void *(*f_img)(void *);
typedef size_t (*f_ccount)(void *);
typedef void *(*f_cidx)(void *, size_t);
typedef const char *(*f_cname)(void *);
typedef void *(*f_miter)(void *, void **);
typedef const char *(*f_mname)(void *);
typedef void *(*f_mfrom)(void *, const char *, int);

static f_dom p_dom; static f_att p_att; static f_asms p_asms; static f_img p_img;
static f_ccount p_cc; static f_cidx p_ci; static f_cname p_cn;
static f_miter p_mi; static f_mname p_mn; static f_mfrom p_mf;
static int gI2C = 0;

static void vxResetGuest(void);
static void vxBuildTab(void);

static void vlog(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!gLogView) return;
        gLogView.text = [gLogView.text stringByAppendingFormat:@"%@\n", s];
        if (gLogView.text.length > 20000)
            gLogView.text = [gLogView.text substringFromIndex:gLogView.text.length - 20000];
        [gLogView scrollRangeToVisible:NSMakeRange(gLogView.text.length, 0)];
    });
}

@interface VXRoot : UIView @end
@implementation VXRoot
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (CGRectContainsPoint(gBtnR, p) || (gOpen && CGRectContainsPoint(gPanelR, p)))
        return [super hitTest:p withEvent:e];
    return nil;
}
@end

static void vxPatchCryptid(void) {
    const struct mach_header_64 *h = (const struct mach_header_64 *)_dyld_get_image_header(0);
    uintptr_t base = (uintptr_t)h & ~(uintptr_t)0x3FFF;
    vm_protect(mach_task_self(), base, 0x8000, false,
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    uint8_t *p = (uint8_t *)h + sizeof(*h);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        struct load_command *lc = (struct load_command *)p;
        if (lc->cmd == LC_ENCRYPTION_INFO_64 &&
            ((struct encryption_info_command_64 *)lc)->cryptid != 1)
            ((struct encryption_info_command_64 *)lc)->cryptid = 1;
        p += lc->cmdsize;
    }
}

typedef int (*f_csops)(pid_t, unsigned int, void *, size_t);
static f_csops o_csops;

static int h_csops(pid_t pid, unsigned int ops, void *ud, size_t sz) {
    int r = o_csops ? o_csops(pid, ops, ud, sz) : 0;
    if (ops == 0 && ud) {
        unsigned *f = (unsigned *)ud;
        *f |= 1 | 2;
        *f &= ~0x100;
    }
    return r;
}

static void vxBypass(void) {
    struct rebinding rb = { "csops", (void *)h_csops, (void **)&o_csops };
    rebind_symbols(&rb, 1);
}

static id h_IDFV(id s, SEL c) {
    if (!gIDFV) gIDFV = [[NSUUID UUID] UUIDString];
    return [[NSUUID alloc] initWithUUIDString:gIDFV];
}

static void vxInstallHooks(void) {
    Method m = class_getInstanceMethod([UIDevice class], @selector(identifierForVendor));
    method_setImplementation(m, (IMP)h_IDFV);
}

static void vxResetGuest(void) {
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword});
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass:(__bridge id)kSecClassInternetPassword});
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass:(__bridge id)kSecClassKey});

    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *lib = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    [fm removeItemAtPath:doc error:nil];
    [fm removeItemAtPath:[lib stringByAppendingPathComponent:@"Preferences"] error:nil];
    [fm createDirectoryAtPath:doc withIntermediateDirectories:YES attributes:nil error:nil];

    gIDFV = [[NSUUID UUID] UUIDString];
    vlog([NSString stringWithFormat:@"reset listo: %@", gIDFV]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ exit(0); });
}

@interface UIButton (VX) @end
@implementation UIButton (VX)
- (void)vxDoTap { gOpen = !gOpen; gPanel.hidden = !gOpen; }
- (void)vxDoReset { vxResetGuest(); }
- (void)vxDoTab { gTab = (int)self.tag; vxBuildTab(); }
- (void)vxDoCopy {
    UIPasteboard.generalPasteboard.string = gLogView.text ?: @"";
    self.backgroundColor = [UIColor colorWithWhite:0.11 alpha:1];
    [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
}
@end

static void vxI2CInit(void) {
    void *h = dlopen(NULL, RTLD_NOW);
    p_dom  = (f_dom)dlsym(h, "il2cpp_domain_get");
    p_att  = (f_att)dlsym(h, "il2cpp_thread_attach");
    p_asms = (f_asms)dlsym(h, "il2cpp_domain_get_assemblies");
    p_img  = (f_img)dlsym(h, "il2cpp_assembly_get_image");
    p_cc   = (f_ccount)dlsym(h, "il2cpp_image_get_class_count");
    p_ci   = (f_cidx)dlsym(h, "il2cpp_image_get_class");
    p_cn   = (f_cname)dlsym(h, "il2cpp_class_get_name");
    p_mi   = (f_miter)dlsym(h, "il2cpp_class_get_methods");
    p_mn   = (f_mname)dlsym(h, "il2cpp_method_get_name");
    p_mf   = (f_mfrom)dlsym(h, "il2cpp_class_get_method_from_name");
    gI2C = p_dom && p_att && p_asms && p_img && p_cc && p_ci && p_cn && p_mi && p_mn && p_mf;
    if (gI2C) p_att(p_dom());
    vlog([NSString stringWithFormat:@"i2c %d", gI2C]);
}

static int l_i2c_ready(lua_State *L) { lua_pushboolean(L, gI2C); return 1; }

static int l_i2c_cls(lua_State *L) {
    const char *cls = luaL_checkstring(L, 1);
    if (!gI2C) { lua_pushnil(L); return 1; }
    size_t n = 0;
    void **asms = (void **)p_asms(p_dom(), &n);
    for (size_t a = 0; a < n; a++) {
        void *img = p_img(asms[a]);
        if (!img) continue;
        size_t c = p_cc(img);
        for (size_t i = 0; i < c; i++) {
            void *kl = p_ci(img, i);
            if (kl && !strcmp(p_cn(kl), cls)) { lua_pushinteger(L, (uint64_t)kl); return 1; }
        }
    }
    lua_pushnil(L); return 1;
}

static int l_i2c_classes(lua_State *L) {
    const char *sub = luaL_checkstring(L, 1);
    lua_newtable(L);
    if (!gI2C) return 1;
    size_t n = 0;
    void **asms = (void **)p_asms(p_dom(), &n);
    int k = 1;
    for (size_t a = 0; a < n; a++) {
        void *img = p_img(asms[a]);
        if (!img) continue;
        size_t c = p_cc(img);
        for (size_t i = 0; i < c; i++) {
            void *kl = p_ci(img, i);
            const char *nm = kl ? p_cn(kl) : NULL;
            if (nm && strstr(nm, sub)) { lua_pushstring(L, nm); lua_rawseti(L, -2, k++); }
        }
    }
    return 1;
}

static int l_i2c_methods(lua_State *L) {
    const char *cls = luaL_checkstring(L, 1);
    const char *sub = luaL_checkstring(L, 2);
    lua_newtable(L);
    if (!gI2C) return 1;
    size_t n = 0;
    void **asms = (void **)p_asms(p_dom(), &n);
    int k = 1;
    for (size_t a = 0; a < n; a++) {
        void *img = p_img(asms[a]);
        if (!img) continue;
        size_t c = p_cc(img);
        for (size_t i = 0; i < c; i++) {
            void *kl = p_ci(img, i);
            if (!kl || strcmp(p_cn(kl), cls)) continue;
            void *it = NULL;
            for (;;) {
                void *m = p_mi(kl, &it);
                if (!m) break;
                const char *mn = p_mn(m);
                if (mn && strstr(mn, sub)) { lua_pushstring(L, mn); lua_rawseti(L, -2, k++); }
            }
        }
    }
    return 1;
}

static int l_i2c_ptr(lua_State *L) {
    const char *cls = luaL_checkstring(L, 1);
    const char *mth = luaL_checkstring(L, 2);
    int argc = (int)luaL_optinteger(L, 3, 0);
    if (!gI2C) { lua_pushnil(L); return 1; }
    size_t n = 0;
    void **asms = (void **)p_asms(p_dom(), &n);
    for (size_t a = 0; a < n; a++) {
        void *img = p_img(asms[a]);
        if (!img) continue;
        size_t c = p_cc(img);
        for (size_t i = 0; i < c; i++) {
            void *kl = p_ci(img, i);
            if (!kl || strcmp(p_cn(kl), cls)) continue;
            void *m = p_mf(kl, mth, argc);
            if (m) { lua_pushinteger(L, *(uint64_t *)m); return 1; }
        }
    }
    lua_pushnil(L); return 1;
}

typedef uint64_t (*f_c4)(uint64_t, uint64_t, uint64_t, uint64_t);
static int l_call(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L, 1);
    uint64_t a = (uint64_t)luaL_optinteger(L, 2, 0);
    uint64_t b = (uint64_t)luaL_optinteger(L, 3, 0);
    uint64_t c = (uint64_t)luaL_optinteger(L, 4, 0);
    uint64_t d = (uint64_t)luaL_optinteger(L, 5, 0);
    lua_pushinteger(L, ((f_c4)f)(a, b, c, d));
    return 1;
}

typedef struct { float x, y, z; } V3;
typedef V3 (*f_gv3)(void *);
typedef V3 (*f_w2s)(void *, V3);

static int l_callv(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L, 1);
    uint64_t self = (uint64_t)luaL_optinteger(L, 2, 0);
    V3 r = ((f_gv3)f)((void *)self);
    lua_pushnumber(L, r.x); lua_pushnumber(L, r.y); lua_pushnumber(L, r.z);
    return 3;
}
static int l_callv3(lua_State *L) {
    uint64_t f = (uint64_t)luaL_checkinteger(L, 1);
    uint64_t self = (uint64_t)luaL_optinteger(L, 2, 0);
    V3 a = { (float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5) };
    V3 r = ((f_w2s)f)((void *)self, a);
    lua_pushnumber(L, r.x); lua_pushnumber(L, r.y); lua_pushnumber(L, r.z);
    return 3;
}

static int l_arrlen(lua_State *L) {
    void *a = (void *)(uintptr_t)luaL_checkinteger(L, 1);
    lua_pushinteger(L, a ? (lua_Integer)*(uint64_t *)((char *)a + 24) : 0);
    return 1;
}
static int l_arrat(lua_State *L) {
    void *a = (void *)(uintptr_t)luaL_checkinteger(L, 1);
    int i = (int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, a ? (lua_Integer)*(uint64_t *)((char *)a + 32 + i * 8) : 0);
    return 1;
}

static int l_cfg(lua_State *L) {
    id v = gCfg[[NSString stringWithUTF8String:luaL_checkstring(L,1)]];
    if (v) lua_pushnumber(L, [v doubleValue]); else lua_pushnil(L);
    return 1;
}
static int l_flen(lua_State *L) {
    NSString *p = [NSString stringWithUTF8String:luaL_checkstring(L,1)];
    NSDictionary *a = [NSFileManager.defaultManager attributesOfItemAtPath:p error:nil];
    lua_pushinteger(L, (lua_Integer)[a[NSFileSize] unsignedLongLongValue]);
    return 1;
}
static int l_fread(lua_State *L) {
    NSString *p = [NSString stringWithUTF8String:luaL_checkstring(L,1)];
    long off = (long)luaL_checkinteger(L,2), len = (long)luaL_checkinteger(L,3);
    NSFileHandle *h = [NSFileHandle fileHandleForReadingAtPath:p];
    if (!h) { lua_pushnil(L); return 1; }
    [h seekToFileOffset:off];
    NSData *d = [h readDataOfLength:len];
    [h closeFile];
    lua_pushlstring(L, d.bytes, d.length);
    return 1;
}

static int l_rd(lua_State *L) {
    uint64_t a = (uint64_t)luaL_checkinteger(L,1); size_t n = (size_t)luaL_checkinteger(L,2);
    uint8_t b[64]; if (n > 64) n = 64; vm_size_t got = 0;
    if (vm_read_overwrite(mach_task_self(), a, n, (vm_address_t)b, &got) != KERN_SUCCESS) { lua_pushnil(L); return 1; }
    lua_pushlstring(L, (char *)b, got); return 1;
}
static int l_r32(lua_State *L) {
    uint32_t v = 0; vm_size_t g = 0;
    if (vm_read_overwrite(mach_task_self(), (uint64_t)luaL_checkinteger(L,1), 4, (vm_address_t)&v, &g) != KERN_SUCCESS) { lua_pushnil(L); return 1; }
    lua_pushinteger(L, v); return 1;
}
static int l_r64(lua_State *L) {
    uint64_t v = 0; vm_size_t g = 0;
    if (vm_read_overwrite(mach_task_self(), (uint64_t)luaL_checkinteger(L,1), 8, (vm_address_t)&v, &g) != KERN_SUCCESS) { lua_pushnil(L); return 1; }
    lua_pushinteger(L, v); return 1;
}
static int l_rf(lua_State *L) {
    float v = 0; vm_size_t g = 0;
    if (vm_read_overwrite(mach_task_self(), (uint64_t)luaL_checkinteger(L,1), 4, (vm_address_t)&v, &g) != KERN_SUCCESS) { lua_pushnil(L); return 1; }
    lua_pushnumber(L, v); return 1;
}
static int l_w32(lua_State *L) {
    *(uint32_t *)(uintptr_t)luaL_checkinteger(L,1) = (uint32_t)luaL_checkinteger(L,2); return 0;
}
static int l_wf(lua_State *L) {
    *(float *)(uintptr_t)luaL_checkinteger(L,1) = (float)luaL_checknumber(L,2); return 0;
}
static int l_scan(lua_State *L) {
    const char *pat = luaL_checkstring(L,1);
    uint8_t by[64]; int8_t mk[64]; int n = 0;
    for (const char *p = pat; *p && n < 64; ) {
        if (*p == ' ') { p++; continue; }
        if (*p == '?') { by[n] = 0; mk[n] = 0; n++; p++; }
        else { char t[3] = { p[0], p[1], 0 }; by[n] = (uint8_t)strtoul(t, NULL, 16); mk[n] = 1; n++; p += 2; }
    }
    if (!n) { lua_pushnil(L); return 1; }
    uint8_t buf[0x10000];
    for (uint64_t off = 0; off < gSize; off += sizeof buf) {
        size_t len = (gSize - off) < sizeof buf ? (gSize - off) : sizeof buf;
        vm_size_t got = 0;
        if (vm_read_overwrite(mach_task_self(), gBase + off, len, (vm_address_t)buf, &got) != KERN_SUCCESS) continue;
        for (size_t i = 0; i + n < got; i++) {
            int ok = 1;
            for (int j = 0; j < n; j++) if (mk[j] && buf[i+j] != by[j]) { ok = 0; break; }
            if (ok) { lua_pushinteger(L, gBase + off + i); return 1; }
        }
    }
    lua_pushnil(L); return 1;
}

static int l_log(lua_State *L) { vlog([NSString stringWithUTF8String:luaL_checkstring(L,1)]); return 0; }
static int l_sleep(lua_State *L) { usleep((useconds_t)(luaL_checknumber(L,1)*1000)); return 0; }

static void drawAt(float x, float y, NSString *s, float sz, uint32_t col) {
    if (gUsed >= MAXLBL) return;
    UILabel *l = gLbl[gUsed++];
    l.frame = CGRectMake(x, y, 340, sz + 4); l.text = s;
    l.font = [UIFont boldSystemFontOfSize:sz];
    l.textColor = [UIColor colorWithRed:((col>>24)&255)/255.0 green:((col>>16)&255)/255.0
                                   blue:((col>>8)&255)/255.0 alpha:(col&255)/255.0];
    l.hidden = NO;
}
static int l_text(lua_State *L) {
    float x = luaL_checknumber(L,1), y = luaL_checknumber(L,2);
    NSString *s = [NSString stringWithUTF8String:luaL_checkstring(L,3)];
    uint32_t c = (uint32_t)luaL_optinteger(L,4,0x00FF00FF);
    float sz = (float)luaL_optnumber(L,5,13);
    dispatch_async(dispatch_get_main_queue(), ^{ drawAt(x,y,s,sz,c); });
    return 0;
}
static int l_clear(lua_State *L) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < gUsed; i++) gLbl[i].hidden = YES; gUsed = 0; });
    return 0;
}

static void runScript(void) {
    vxI2CInit();

    NSData *r = [NSData dataWithContentsOfURL:[NSURL URLWithString:
        [NSString stringWithFormat:@"%@?t=%d", @REF_URL, (int)time(NULL)]]];
    if (r.length) [r writeToFile:[gDocs stringByAppendingPathComponent:@"u.idx"] atomically:YES];

    NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"%s?t=%d", SCRIPT_URL, (int)time(NULL)]];
    NSData *d = [NSData dataWithContentsOfURL:u];
    NSString *path = [gDocs stringByAppendingPathComponent:@"u.dat"];
    if (d && d.length) { [d writeToFile:path atomically:YES]; vlog(@"script ok"); }
    else vlog(@"sin script");

    gL = luaL_newstate(); luaL_openlibs(gL);
    lua_register(gL, "log", l_log); lua_register(gL, "msleep", l_sleep);
    lua_register(gL, "text", l_text); lua_register(gL, "clear", l_clear);
    lua_register(gL, "rd", l_rd); lua_register(gL, "r32", l_r32);
    lua_register(gL, "r64", l_r64); lua_register(gL, "rf", l_rf);
    lua_register(gL, "w32", l_w32); lua_register(gL, "wf", l_wf);
    lua_register(gL, "scan", l_scan); lua_register(gL, "cfg", l_cfg);
    lua_register(gL, "flen", l_flen); lua_register(gL, "fread", l_fread);
    lua_register(gL, "call", l_call); lua_register(gL, "callv", l_callv);
    lua_register(gL, "callv3", l_callv3);
    lua_register(gL, "arrlen", l_arrlen); lua_register(gL, "arrat", l_arrat);
    lua_register(gL, "i2c_ready", l_i2c_ready);
    lua_register(gL, "i2c_cls", l_i2c_cls);
    lua_register(gL, "i2c_classes", l_i2c_classes);
    lua_register(gL, "i2c_methods", l_i2c_methods);
    lua_register(gL, "i2c_ptr", l_i2c_ptr);
    lua_pushinteger(gL, gBase); lua_setglobal(gL, "BASE");
    lua_pushinteger(gL, gSize); lua_setglobal(gL, "SIZE");
    lua_pushstring(gL, gDocs.UTF8String); lua_setglobal(gL, "DOC");
    if (luaL_dofile(gL, path.UTF8String) != LUA_OK) {
        NSString *e = [NSString stringWithUTF8String:lua_tostring(gL,-1)];
        vlog([NSString stringWithFormat:@"LUA ERROR: %@", e]);
    }
}

static void vxFindImage(void) {
    const struct mach_header_64 *h = NULL;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (nm && strstr(nm, "UnityFramework")) {
            h = (const struct mach_header_64 *)_dyld_get_image_header(i);
            vlog([NSString stringWithFormat:@"imagen: %s", nm]);
            break;
        }
    }
    if (!h) { h = (const struct mach_header_64 *)_dyld_get_image_header(0); vlog(@"imagen 0 (fallback)"); }
    gBase = (uint64_t)h;
    const struct segment_command_64 *sg = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (sg->cmd == LC_SEGMENT_64 && strcmp(sg->segname, "__TEXT") == 0) { gSize = sg->vmsize; break; }
        sg = (const void *)((const char *)sg + sg->cmdsize);
    }
}

static const char *kTabs[] = { "ESP", "AIM", "DRAW", "MISC", "SET" };

@interface VXRow : UIButton @end
@implementation VXRow
- (void)vxFlip {
    NSString *k = (NSString *)objc_getAssociatedObject(self, "k");
    BOOL on = ![gCfg[k] boolValue];
    gCfg[k] = @(on);
    self.backgroundColor = on ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:1 alpha:0.55];
    [self setTitleColor:on ? UIColor.whiteColor : [UIColor colorWithWhite:0.11 alpha:1] forState:UIControlStateNormal];
}
@end

static void addRow(NSString *title, NSString *key, CGFloat y) {
    VXRow *b = [VXRow buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(8, y, 250, 34);
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.55];
    b.layer.cornerRadius = 17;
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor colorWithWhite:0.11 alpha:1] forState:UIControlStateNormal];
    objc_setAssociatedObject(b, "k", key, OBJC_ASSOCIATION_RETAIN);
    [b addTarget:b action:@selector(vxFlip) forControlEvents:UIControlEventTouchUpInside];
    [gContent addSubview:b];
}

static void vxBuildTab(void) {
    for (UIView *v in gContent.subviews) [v removeFromSuperview];
    for (int i = 0; i < 5; i++) {
        UIButton *t = gTabBtns[i];
        BOOL on = (i == gTab);
        t.backgroundColor = on ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:1 alpha:0.6];
        [t setTitleColor:on ? UIColor.whiteColor : [UIColor colorWithWhite:0.11 alpha:1] forState:UIControlStateNormal];
    }
    CGFloat y = 4;
    if (gTab == 0) {
        addRow(@"ESP master", @"esp.on", y); y += 38;
        addRow(@"Cajas", @"esp.box", y); y += 38;
        addRow(@"Nombres", @"esp.name", y); y += 38;
        addRow(@"Distancia", @"esp.dist", y);
    } else if (gTab == 1) {
        addRow(@"Aimbot", @"aim.on", y); y += 38;
        addRow(@"Predicción", @"aim.pred", y); y += 38;
        addRow(@"Humanizar", @"aim.human", y); y += 38;
        addRow(@"Triggerbot", @"aim.trigger", y);
    } else if (gTab == 2) {
        addRow(@"Salud", @"draw.hp", y); y += 38;
        addRow(@"Arma", @"draw.wpn", y); y += 38;
        addRow(@"Líneas", @"draw.line", y); y += 38;
        addRow(@"Esqueleto", @"draw.skel", y);
    } else if (gTab == 3) {
        addRow(@"Contador FPS", @"misc.fps", y); y += 38;
        addRow(@"Ocultar en lobby", @"misc.hide", y); y += 38;
        addRow(@"Anti-captura", @"misc.anti", y);
    } else {
        addRow(@"RESET GUEST", @"set.reset", y); y += 38;
        addRow(@"Recargar script", @"set.reload", y);
    }
    for (UIView *v in gContent.subviews) {
        if ([v isKindOfClass:[VXRow class]]) {
            VXRow *r = (VXRow *)v;
            NSString *k = (NSString *)objc_getAssociatedObject(r, "k");
            BOOL on = [gCfg[k] boolValue];
            r.backgroundColor = on ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:1 alpha:0.55];
            [r setTitleColor:on ? UIColor.whiteColor : [UIColor colorWithWhite:0.11 alpha:1] forState:UIControlStateNormal];
        }
    }
}

static void buildUI(UIWindowScene *sc) {
    gCfg = [NSMutableDictionary dictionary];
    gCfg[@"esp.on"] = @NO; gCfg[@"esp.box"] = @YES; gCfg[@"esp.name"] = @NO;
    gCfg[@"esp.dist"] = @YES; gCfg[@"aim.on"] = @NO; gCfg[@"aim.pred"] = @YES;
    gCfg[@"aim.human"] = @YES; gCfg[@"aim.trigger"] = @NO;
    gCfg[@"draw.hp"] = @NO; gCfg[@"draw.wpn"] = @NO; gCfg[@"draw.line"] = @NO;
    gCfg[@"draw.skel"] = @NO; gCfg[@"misc.fps"] = @NO; gCfg[@"misc.hide"] = @NO;
    gCfg[@"misc.anti"] = @NO;

    gWin = [[UIWindow alloc] initWithWindowScene:sc];
    gWin.frame = sc.coordinateSpace.bounds;
    gWin.windowLevel = UIWindowLevelAlert + 1;
    gWin.backgroundColor = UIColor.clearColor;
    gRoot = [[VXRoot alloc] initWithFrame:gWin.bounds];
    gRoot.backgroundColor = UIColor.clearColor;
    UIViewController *vc = [UIViewController new]; vc.view = gRoot;
    gWin.rootViewController = vc;

    for (int i = 0; i < MAXLBL; i++) { gLbl[i] = [[UILabel alloc] init]; gLbl[i].hidden = YES; [gRoot addSubview:gLbl[i]]; }

    gBtnR = CGRectMake(14, 70, 46, 46);
    gBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    gBtn.frame = gBtnR;
    gBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.8];
    gBtn.layer.cornerRadius = 23;
    gBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [gBtn setTitle:@"VX" forState:UIControlStateNormal];
    [gBtn setTitleColor:[UIColor colorWithWhite:0.1 alpha:1] forState:UIControlStateNormal];
    [gBtn addTarget:gBtn action:@selector(vxDoTap) forControlEvents:UIControlEventTouchUpInside];
    [gRoot addSubview:gBtn];

    gPanelR = CGRectMake(14, 108, 300, 296);
    gPanel = [[UIView alloc] initWithFrame:gPanelR];
    gPanel.layer.cornerRadius = 20; gPanel.hidden = YES; gPanel.clipsToBounds = YES;
    [gRoot addSubview:gPanel];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
    blur.frame = gPanel.bounds;
    [gPanel addSubview:blur];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, 120, 24)];
    t.text = @"VEEX"; t.font = [UIFont boldSystemFontOfSize:15];
    t.textColor = [UIColor colorWithWhite:0.1 alpha:1];
    [gPanel addSubview:t];

    UIButton *cp = [UIButton buttonWithType:UIButtonTypeSystem];
    cp.frame = CGRectMake(232, 8, 56, 24);
    cp.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
    cp.layer.cornerRadius = 12;
    cp.titleLabel.font = [UIFont boldSystemFontOfSize:9];
    [cp setTitle:@"COPIAR" forState:UIControlStateNormal];
    [cp setTitleColor:[UIColor colorWithWhite:0.1 alpha:1] forState:UIControlStateNormal];
    [cp addTarget:cp action:@selector(vxDoCopy) forControlEvents:UIControlEventTouchUpInside];
    [gPanel addSubview:cp];

    gTabBtns = [NSMutableArray array];
    for (int i = 0; i < 5; i++) {
        UIButton *tb = [UIButton buttonWithType:UIButtonTypeSystem];
        tb.frame = CGRectMake(16 + i * 54, 34, 50, 26);
        tb.layer.cornerRadius = 13;
        tb.tag = i;
        tb.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        [tb setTitle:[NSString stringWithUTF8String:kTabs[i]] forState:UIControlStateNormal];
        [tb addTarget:tb action:@selector(vxDoTab) forControlEvents:UIControlEventTouchUpInside];
        [gPanel addSubview:tb];
        [gTabBtns addObject:tb];
    }

    gContent = [[UIView alloc] initWithFrame:CGRectMake(8, 64, 284, 150)];
    [gPanel addSubview:gContent];

    gLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, 218, 280, 68)];
    gLogView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:0.9];
    gLogView.layer.cornerRadius = 10; gLogView.editable = NO;
    gLogView.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    gLogView.textColor = UIColor.blackColor;
    [gPanel addSubview:gLogView];

    gTab = 0;
    vxBuildTab();
    gWin.hidden = NO;
}

static void boot(int tries) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *sc = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:UIWindowScene.class] && s.activationState == UISceneActivationStateForegroundActive)
                sc = (UIWindowScene *)s;
        if (!sc) {
            if (tries > 0) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),
                                          dispatch_get_main_queue(), ^{ boot(tries-1); });
            return;
        }
        NSString *cache = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        gDocs = [cache stringByAppendingPathComponent:@"sys"];
        [NSFileManager.defaultManager createDirectoryAtPath:gDocs withIntermediateDirectories:YES
                                                 attributes:nil error:nil];

        vxFindImage();
        vxPatchCryptid();
        buildUI(sc);
        vlog([NSString stringWithFormat:@"VEEX cargado base=%llx size=%llx", gBase, gSize]);
        dispatch_async(dispatch_get_global_queue(0,0), ^{ runScript(); });
    });
}

__attribute__((constructor)) static void vxInit(void) {
    // vxBypass();
    // vxInstallHooks();
    // boot(60);
}
