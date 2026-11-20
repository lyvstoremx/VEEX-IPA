// VEEX shell build 153 — RESET GUEST
// Borra datos de sesión y sale. No dibuja nada, no engancha nada.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <unistd.h>
#include <stdio.h>

#define VX_BUILD 153

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

static void vxWipe(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *doc = vxDoc();
    int n = 0;
    if (doc) {
        NSArray *it = [fm contentsOfDirectoryAtPath:doc error:NULL];
        for (NSString *name in it) {
            if ([name isEqualToString:@"a.dat"] || [name isEqualToString:@"b.dat"]) continue;
            if ([fm removeItemAtPath:[doc stringByAppendingPathComponent:name] error:NULL]) n++;
        }
    }
    vxLog([NSString stringWithFormat:@"wipe doc=%d", n]);

    NSDictionary *q = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword };
    OSStatus st = SecItemDelete((__bridge CFDictionaryRef)q);
    vxLog([NSString stringWithFormat:@"wipe keychain=%d", (int)st]);
    vxLog(@"wipe fin, salgo");
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        vxLog(@"==== reset ====");
        vxWipe();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3ull * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            exit(0);
        });
    });
}
