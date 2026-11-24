// VEEX shell build 187 — solo diagnóstico: sin hooks, sin patch

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/task_info.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <pthread.h>
#include <dlfcn.h>
#include <time.h>

#define VX_BUILD 187

static pthread_mutex_t vxM = PTHREAD_MUTEX_INITIALIZER;
static FILE *vxF = NULL;
static uint64_t vxT0 = 0;
static uint64_t vxSelfLo = 0, vxSelfHi = 0;
static uint32_t vxSelfIdx = 0;
static char *vxSelfPath = NULL;

static NSString *vxDoc(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

static uint64_t vxNow(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ull + (uint64_t)ts.tv_nsec / 1000000ull;
}

static void vxLogRaw(NSString *s) {
    pthread_mutex_lock(&vxM);
    if (!vxF) {
        NSString *p = [vxDoc() stringByAppendingPathComponent:@"a.dat"];
        vxF = fopen(p.UTF8String, "a");
    }
    if (vxF) {
        fputs([NSString stringWithFormat:@"[%d] %@\n", VX_BUILD, s].UTF8String, vxF);
        fflush(vxF);
    }
    pthread_mutex_unlock(&vxM);
}

typedef const struct dyld_all_image_infos *(*vxInfosFn)(void);

static const struct dyld_all_image_infos *vxInfos(void) {
    static vxInfosFn f = NULL;
    static int t = 0;
    if (!t) {
        t = 1;
        f = (vxInfosFn)dlsym(RTLD_DEFAULT, "_dyld_get_all_image_infos");
        if (!f) f = (vxInfosFn)dlsym(RTLD_DEFAULT, "dyld_get_all_image_infos");
    }
    if (f) {
        const struct dyld_all_image_infos *a = f();
        if (a) return a;
    }
    struct task_dyld_info tdi;
    mach_msg_type_number_t cnt = (mach_msg_type_number_t)(sizeof(tdi) / sizeof(natural_t));
    if (task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&tdi, &cnt) == KERN_SUCCESS) {
        if (tdi.all_image_info_addr) return (const void *)(uintptr_t)tdi.all_image_info_addr;
    }
    return NULL;
}

static kern_return_t vxProt(uint64_t addr, size_t len) {
    vm_size_t ps = vm_page_size;
    uintptr_t a = (uintptr_t)addr & ~((uintptr_t)ps - 1);
    uintptr_t e = ((uintptr_t)addr + len + ps - 1) & ~((uintptr_t)ps - 1);
    size_t l = (size_t)(e - a);
    kern_return_t k = vm_protect(mach_task_self(), (vm_address_t)a, (vm_size_t)l, false,
                                 VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (k == KERN_SUCCESS) return k;
    if (mprotect((void *)a, l, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) return KERN_SUCCESS;
    return k;
}

static void vxSelf(void) {
    for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!p || !strstr(p, "libobjc.A.dylib")) continue;
        if (!strncmp(p, "/usr/lib", 8) || !strncmp(p, "/private/preboot", 16)) continue;
        const struct mach_header_64 *h = (const void *)_dyld_get_image_header(i);
        if (!h) continue;
        uint64_t hi = 0;
        const struct load_command *lc = (const void *)(h + 1);
        for (uint32_t k = 0; k < h->ncmds; k++) {
            if (lc->cmdsize < 8) break;
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *sg = (const void *)lc;
                uint64_t e = sg->vmaddr + sg->vmsize;
                if (e > hi) hi = e;
            }
            lc = (const void *)((const char *)lc + lc->cmdsize);
        }
        vxSelfIdx = i;
        vxSelfLo = (uint64_t)h;
        vxSelfHi = (uint64_t)h + hi;
        if (!vxSelfPath) vxSelfPath = strdup(p);
        vxLogRaw([NSString stringWithFormat:@"self %u %llx-%llx", i, vxSelfLo, vxSelfHi]);
        return;
    }
    vxLogRaw(@"sin self");
}

static void vxInfo(void) {
    const struct dyld_all_image_infos *ai = vxInfos();
    if (!ai) { vxLogRaw(@"sin infos api"); return; }
    uint32_t n = ai->infoArrayCount;
    vxLogRaw([NSString stringWithFormat:@"infos n=%u", n]);
    if (!vxSelfLo) { vxLogRaw(@"sin self"); return; }

    struct dyld_image_info *arr = (struct dyld_image_info *)(uintptr_t)ai->infoArray;
    if (!arr) { vxLogRaw(@"sin arreglo"); return; }

    uint32_t i;
    for (i = 0; i < n; i++) {
        if ((uint64_t)(uintptr_t)arr[i].imageLoadAddress == vxSelfLo) break;
    }
    if (i >= n) { vxLogRaw(@"infos sin self"); return; }
    vxLogRaw([NSString stringWithFormat:@"idx=%u", i]);

    size_t es = sizeof(struct dyld_image_info);
    uint64_t bytes = (uint64_t)(n - i - 1) * es;
    kern_return_t k1 = vxProt((uint64_t)&arr[i], (size_t)bytes + es);
    vxLogRaw([NSString stringWithFormat:@"prot arr=%d", k1]);
    if (k1 != KERN_SUCCESS) return;

    vxLogRaw(@"mov");
    memmove(&arr[i], &arr[i + 1], (size_t)bytes);
    memset(&arr[n - 1], 0, es);

    kern_return_t k2 = vxProt((uint64_t)&ai->infoArrayCount, 4);
    vxLogRaw([NSString stringWithFormat:@"prot cnt=%d", k2]);
    if (k2 != KERN_SUCCESS) return;

    vxLogRaw(@"cnt");
    ((struct dyld_all_image_infos *)(uintptr_t)ai)->infoArrayCount = n - 1;
    vxLogRaw([NSString stringWithFormat:@"infos fuera idx=%u n=%u", i, n - 1]);
}

static void vxImgs(void) {
    const struct dyld_all_image_infos *ai = vxInfos();
    if (ai) vxLogRaw([NSString stringWithFormat:@"infos ahora n=%u", ai->infoArrayCount]);
    uint32_t n = _dyld_image_count();
    vxLogRaw([NSString stringWithFormat:@"visibles n=%u", n]);
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (!p) continue;
        if (!strncmp(p, "/System/Library", 15)) continue;
        if (!strncmp(p, "/usr/lib", 8)) continue;
        vxLogRaw([NSString stringWithFormat:@"vis %u %s", i, p]);
    }
}

__attribute__((constructor))
static void vxInit(void) {
    vxT0 = vxNow();
    vxLogRaw(@"==== 187 diag ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        vxLogRaw(vxInfos() ? @"api ok" : @"api nula");
        vxLogRaw([NSString stringWithFormat:@"imgs n=%u", _dyld_image_count()]);
        vxSelf();
        vxInfo();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6ull * NSEC_PER_SEC),
                       dispatch_get_global_queue(0, 0), ^{ vxImgs(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12ull * NSEC_PER_SEC),
                       dispatch_get_global_queue(0, 0), ^{ vxLogRaw(@"fin diag"); });
    });
    vxLogRaw(@"constructor fin");
}
