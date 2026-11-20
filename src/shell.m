// VEEX shell build 165 — muestra de símbolos + instrumentación GOT en 1265

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/mach.h>
#import <mach/task_info.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <unistd.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>

#define VX_BUILD 165
#define VX_MAX 250

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

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

static uintptr_t gBase = 0;
static size_t    gSize = 0;
static int       gCnt = 0;

static void vxHit(const char *fn, void *ra, unsigned long a1, unsigned long a2) {
    if (!gBase || (uintptr_t)ra < gBase || (uintptr_t)ra > gBase + gSize) return;
    if (gCnt >= VX_MAX) return;
    gCnt++;
    vxLog([NSString stringWithFormat:@"H %s ra=%lx a1=%lx a2=%lx",
           fn, (unsigned long)((uintptr_t)ra - gBase), a1, a2]);
}

static int (*o_csops)(pid_t, unsigned int, void *, size_t);
static int h_csops(pid_t p, unsigned int op, void *a, size_t s) {
    vxHit("csops", __builtin_return_address(0), op, (unsigned long)(uintptr_t)a);
    return o_csops(p, op, a, s);
}

static int (*o_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int h_sysctl(int *m, u_int l, void *o, size_t *ol, void *n, size_t nl) {
    vxHit("sysctl", __builtin_return_address(0), l ? (unsigned long)m[0] : 0, l > 1 ? (unsigned long)m[1] : 0);
    return o_sysctl(m, l, o, ol, n, nl);
}

static int (*o_stat)(const char *, struct stat *);
static int h_stat(const char *p, struct stat *b) {
    vxHit("stat", __builtin_return_address(0), (unsigned long)(uintptr_t)p, 0);
    return o_stat(p, b);
}

static int (*o_access)(const char *, int);
static int h_access(const char *p, int m) {
    vxHit("access", __builtin_return_address(0), (unsigned long)(uintptr_t)p, m);
    return o_access(p, m);
}

static kern_return_t (*o_task_info)(task_t, task_flavor_t, task_info_t, mach_msg_type_number_t *);
static kern_return_t h_task_info(task_t t, task_flavor_t f, task_info_t i, mach_msg_type_number_t *c) {
    vxHit("task_info", __builtin_return_address(0), f, 0);
    return o_task_info(t, f, i, c);
}

static kern_return_t vxWritable(void *addr, size_t len) {
    vm_address_t a = (vm_address_t)addr & ~((vm_address_t)vm_page_size - 1);
    size_t off = (vm_address_t)addr - a;
    size_t sz = ((off + len + vm_page_size - 1) / vm_page_size) * vm_page_size;
    return vm_protect(mach_task_self(), a, sz, FALSE,
                      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
}

static int vxPatch(void *slot, const char *name, void *stub, void **orig) {
    void *cur = *(void **)slot;
    void *real = dlsym(RTLD_DEFAULT, name);
    if (!cur || !real || cur != real) return 0;
    if (vxWritable(slot, sizeof(void *)) != KERN_SUCCESS) return 0;
    *orig = cur;
    *(void **)slot = stub;
    return 1;
}

static const struct mach_header_64 *vxUnity(void) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) return (const void *)_dyld_get_image_header(i);
    }
    return NULL;
}

static void vxSyms(const struct mach_header_64 *h) {
    const struct load_command *lc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SYMTAB) {
            const struct symtab_command *st = (const void *)lc;
            const char *str = (const char *)h + st->stroff;
            uint32_t shown = 0;
            for (uint32_t off = 0; off < st->strsize && shown < 40; off++) {
                const char *s = str + off;
                if (!*s) continue;
                size_t n = strlen(s);
                if (n >= 3) { vxLog([NSString stringWithFormat:@"S %s", s]); shown++; }
                off += n;
            }
            return;
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
}

static void vxHook(const struct mach_header_64 *h) {
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const struct load_command *lc = (const void *)(h + 1);
    int ok = 0;
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) { gBase = (uintptr_t)h; gSize = (size_t)sg->vmsize; }
            if (!strncmp(sg->segname, "__DATA", 6) || !strncmp(sg->segname, "__AUTH", 6)) {
                const struct section_64 *sc = (const void *)(sg + 1);
                for (uint32_t k = 0; k < sg->nsects; k++, sc++) {
                    if (strcmp(sc->sectname, "__la_symbol_ptr") && strcmp(sc->sectname, "__got")) continue;
                    uintptr_t b = (uintptr_t)h + slide + sc->offset;
                    uint32_t cnt = (uint32_t)(sc->size / sizeof(void *));
                    for (uint32_t j = 0; j < cnt; j++) {
                        void **slot = (void **)(b + j * sizeof(void *));
                        ok += vxPatch(slot, "csops", (void *)h_csops, (void **)&o_csops);
                        ok += vxPatch(slot, "sysctl", (void *)h_sysctl, (void **)&o_sysctl);
                        ok += vxPatch(slot, "stat", (void *)h_stat, (void **)&o_stat);
                        ok += vxPatch(slot, "access", (void *)h_access, (void **)&o_access);
                        ok += vxPatch(slot, "task_info", (void *)h_task_info, (void **)&o_task_info);
                    }
                }
            }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }
    vxLog([NSString stringWithFormat:@"got=%d base=%lx size=%zu", ok, (unsigned long)gBase, gSize]);
}

static void vxRun(void) {
    vxLog(@"==== sims + got 1265 ====");
    const struct mach_header_64 *h = vxUnity();
    if (!h) { vxLog(@"sin unity"); return; }
    vxSyms(h);
    vxHook(h);
}

__attribute__((constructor))
static void vxInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ vxRun(); });
}
