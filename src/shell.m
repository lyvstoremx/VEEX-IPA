#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <dlfcn.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#define SCRIPT_URL "https://raw.githubusercontent.com/1yvstoremx/VEEX-IPA/main/scripts/esp.lua"
#define MAXLBL 128

static UIWindow *gWin; static UIView *gRoot;
static UIButton *gBtn; static UIView *gPanel; static UITextView *gLogView;
static UILabel *gLbl[MAXLBL]; static int gUsed;
static lua_State *gL; static NSString *gDocs;
static CGRect gBtnR, gPanelR; static int gOpen;
static NSString *gIDFV;

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
    uint8_t *p = (uint8_t *)h + sizeof(*h);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        struct load_command *lc = (struct load_command *)p;
        if (lc->cmd == LC_ENCRYPTION_INFO_64)
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
    if (luaL_dofile(gL, path.UTF8String) != LUA_OK) {
        NSString *e = [NSString stringWithUTF8String:lua_tostring(gL,-1)];
        vlog([NSString stringWithFormat:@"LUA ERROR: %@", e]);
    }
}

static void vxTap(void) { gOpen = !gOpen; gPanel.hidden = !gOpen; }

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
    [gBtn addTarget:gBtn action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
    [gRoot addSubview:gBtn];

    gPanelR = CGRectMake(14, 124, 340, 330);
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
    [rst addTarget:rst action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
    [gPanel addSubview:rst];

    gLogView = [[UITextView alloc] initWithFrame:CGRectMake(12, 80, 316, 238)];
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
        buildUI(sc);
        vlog(@"VEEX cargado");
        dispatch_async(dispatch_get_global_queue(0,0), ^{ runScript(); });
    });
}

__attribute__((constructor)) static void vxInit(void) {
    vxPatchCryptid();
    vxInstallHooks();
    boot(60);
}
