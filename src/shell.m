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

#define SCRIPT_URL "https://raw.githubusercontent.com/lyvstoremx/VEEX-IPA/main/scripts/esp.lua"
#define MAXLBL 128

static UIWindow *gWin; static UIView *gRoot;
static UIButton *gBtn; static UIView *gPanel; static UITextView *gLogView;
static UILabel *gLbl[MAXLBL]; static int gUsed;
static lua_State *gL; static NSString *gDocs;
static CGRect gBtnR, gPanelR; static int gOpen;
static NSString *gIDFV;
static uint64_t gBase, gSize;

static void vxResetGuest(void);

static void vlog(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gLogView.text = [gLogView.text stringByAppendingFormat:@"%@\n", s];
        if (gLogView.text.length > 6000)
            gLogView.text = [gLogView.text substringFromIndex:gLogView.text.length - 6000];
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
@end

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

static void drawAt(float x, float y, NSString *s, float sz) {
    if (gUsed >= MAXLBL) return;
    UILabel *l = gLbl[gUsed++];
    l.frame = CGRectMake(x, y, 320, sz + 4); l.text = s;
    l.font = [UIFont boldSystemFontOfSize:sz];
    l.textColor = UIColor.greenColor; l.hidden = NO;
}
static int l_text(lua_State *L) {
    float x = luaL_checknumber(L,1), y = luaL_checknumber(L,2);
    NSString *s = [NSString stringWithUTF8String:luaL_checkstring(L,3)];
    float sz = (float)luaL_optnumber(L,4,13);
    dispatch_async(dispatch_get_main_queue(), ^{ drawAt(x,y,s,sz); });
    return 0;
}
static int l_clear(lua_State *L) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < gUsed; i++) gLbl[i].hidden = YES; gUsed = 0; });
    return 0;
}

static void runScript(void) {
    NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"%s?t=%d", SCRIPT_URL, (int)time(NULL)]];
    NSData *d = [NSData dataWithContentsOfURL:u];
    NSString *path = [gDocs stringByAppendingPathComponent:@"esp.lua"];
    if (d && d.length) { [d writeToFile:path atomically:YES]; vlog(@"script ok"); }
    else vlog(@"sin script, uso copia local");

    gL = luaL_newstate(); luaL_openlibs(gL);
    lua_register(gL, "log", l_log); lua_register(gL, "msleep", l_sleep);
    lua_register(gL, "text", l_text); lua_register(gL, "clear", l_clear);
    lua_register(gL, "rd", l_rd); lua_register(gL, "r32", l_r32);
    lua_register(gL, "r64", l_r64); lua_register(gL, "rf", l_rf);
    lua_register(gL, "w32", l_w32); lua_register(gL, "wf", l_wf);
    lua_register(gL, "scan", l_scan);
    lua_pushinteger(gL, gBase); lua_setglobal(gL, "BASE");
    lua_pushinteger(gL, gSize); lua_setglobal(gL, "SIZE");
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

static void buildUI(UIWindowScene *sc) {
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
    gBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.75];
    gBtn.layer.cornerRadius = 23;
    gBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [gBtn setTitle:@"VX" forState:UIControlStateNormal];
    [gBtn setTitleColor:[UIColor colorWithWhite:0.1 alpha:1] forState:UIControlStateNormal];
    [gBtn addTarget:gBtn action:@selector(vxDoTap) forControlEvents:UIControlEventTouchUpInside];
    [gRoot addSubview:gBtn];

    gPanelR = CGRectMake(14, 124, 340, 250);
    gPanel = [[UIView alloc] initWithFrame:gPanelR];
    gPanel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.85];
    gPanel.layer.cornerRadius = 18; gPanel.hidden = YES; gPanel.clipsToBounds = YES;
    [gRoot addSubview:gPanel];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, 220, 26)];
    t.text = @"VEEX 1.0"; t.font = [UIFont boldSystemFontOfSize:15];
    t.textColor = [UIColor colorWithWhite:0.1 alpha:1];
    [gPanel addSubview:t];

    UIButton *rst = [UIButton buttonWithType:UIButtonTypeSystem];
    rst.frame = CGRectMake(16, 40, 140, 32);
    rst.backgroundColor = [UIColor colorWithRed:0.9 green:0.25 blue:0.25 alpha:1];
    rst.layer.cornerRadius = 16;
    rst.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [rst setTitle:@"RESET GUEST" forState:UIControlStateNormal];
    [rst setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [rst addTarget:rst action:@selector(vxDoReset) forControlEvents:UIControlEventTouchUpInside];
    [gPanel addSubview:rst];

    gLogView = [[UITextView alloc] initWithFrame:CGRectMake(12, 80, 316, 158)];
    gLogView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1];
    gLogView.layer.cornerRadius = 10; gLogView.editable = NO;
    gLogView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    gLogView.textColor = UIColor.blackColor;
    [gPanel addSubview:gLogView];

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
        gDocs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

        vxFindImage();
        buildUI(sc);
        vxPatchCryptid();
        vlog([NSString stringWithFormat:@"VEEX cargado base=%llx size=%llx", gBase, gSize]);
        dispatch_async(dispatch_get_global_queue(0,0), ^{ runScript(); });
    });
}

__attribute__((constructor)) static void vxInit(void) {
    vxInstallHooks();
    boot(60);
}
