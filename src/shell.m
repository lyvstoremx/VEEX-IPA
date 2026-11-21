// VEEX shell build 172 — diagnóstico Mach-O: comandos, secciones, fixups encadenados

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach-o/fixup-chains.h>
#import <mach/mach.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <pthread.h>
#include <dlfcn.h>

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#define VX_STRIP(p) ((uint64_t)ptrauth_strip((void *)(p), ptrauth_key_asia))
#else
#define VX_STRIP(p) ((uint64_t)(p))
#endif

#define VX_BUILD  172
#define VX_N      22
#define VX_TRIES  40

#ifndef SECTION_TYPE
#define SECTION_TYPE 0xff
#endif

static pthread_mutex_t vxM = PTHREAD_MUTEX_INITIALIZER;
static FILE *vxF = NULL;
static int vxTries = 0;

static const char *vxNames[VX_N] = {
    "_csops", "_csops_audittoken", "_ptrace", "_sysctl", "_sysctlbyname",
    "_stat", "_stat$INODE64", "_lstat", "_access", "_open", "_dlopen", "_dlsym",
    "_task_info", "_mach_vm_region", "_vm_region", "_vm_region_64",
    "_proc_pidinfo", "_kdebug_trace", "_getppid", "_getpid",
    "_objc_setHook_getClass", "_mach_port_deallocate"
};

static NSString *vxDoc(void) {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
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

static const struct mach_header_64 *vxFind(void) {
    for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *p = _dyld_get_image_name(i);
        if (p && strstr(p, "UnityFramework")) {
            vxLogRaw([NSString stringWithFormat:@"img=%u", i]);
            return (const void *)_dyld_get_image_header(i);
        }
    }
    return NULL;
}

static void vxDump(void) {
    const struct mach_header_64 *h = vxFind();
    if (!h) { vxLogRaw(@"sin unity"); return; }

    vxLogRaw([NSString stringWithFormat:@"mh ncmds=%u sizeofcmds=%u flags=%x",
              h->ncmds, h->sizeofcmds, h->flags]);

    const struct load_command *lc = (const void *)(h + 1);
    const struct symtab_command *st = NULL;
    const struct linkedit_data_command *ch = NULL;
    uint64_t txtVm = 0, leVm = 0, leOff = 0, leSize = 0;
    int haveDys = 0, haveInfo = 0;

    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (lc->cmdsize < 8) break;
        vxLogRaw([NSString stringWithFormat:@"LC %x", lc->cmd]);
        if (lc->cmd == LC_SYMTAB) st = (const void *)lc;
        if (lc->cmd == LC_DYSYMTAB) haveDys = 1;
        if (lc->cmd == LC_DYLD_INFO_ONLY || lc->cmd == LC_DYLD_INFO) haveInfo = 1;
        if (lc->cmd == LC_DYLD_CHAINED_FIXUPS) ch = (const void *)lc;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)lc;
            if (!strcmp(sg->segname, "__TEXT")) txtVm = sg->vmaddr;
            if (!strcmp(sg->segname, "__LINKEDIT")) {
                leVm = sg->vmaddr; leOff = sg->fileoff; leSize = sg->filesize;
            }
        }
        lc = (const void *)((const char *)lc + lc->cmdsize);
    }

    vxLogRaw([NSString stringWithFormat:@"dys=%d info=%d chained=%d txt=%llx le=%llx",
              haveDys, haveInfo, ch != NULL, txtVm, leVm]);
    if (!txtVm || !leVm || !st) { vxLogRaw(@"base incompleta"); return; }

    const uint8_t *le = (const uint8_t *)h + (leVm - txtVm);

    // secciones de interés
    const struct load_command *sc = (const void *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        if (sc->cmdsize < 8) break;
        if (sc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const void *)sc;
            vxLogRaw([NSString stringWithFormat:@"SEG %s vm=%llx vs=%llx fo=%llx prot=%x ns=%u",
                      sg->segname, sg->vmaddr, sg->vmsize, sg->fileoff,
                      sg->initprot, sg->nsects]);
            const struct section_64 *s = (const void *)(sg + 1);
            for (uint32_t j = 0; j < sg->nsects; j++, s++) {
                uint8_t type = s->flags & SECTION_TYPE;
                if (type != 0x6 && type != 0x7 && type != 0x8 &&
                    !strstr(s->sectname, "stub") && !strstr(s->sectname, "got") &&
                    !strstr(s->sectname, "symbol")) continue;
                vxLogRaw([NSString stringWithFormat:@"SEC %s,%s a=%llx sz=%llx fl=%x r1=%u r2=%u",
                          s->segname, s->sectname, s->addr, s->size,
                          s->flags, s->reserved1, s->reserved2]);
            }
        }
        sc = (const void *)((const char *)sc + sc->cmdsize);
    }

    // importaciones encadenadas
    if (ch) {
        if (ch->dataoff < leOff || ch->dataoff + ch->datasize > leOff + leSize) {
            vxLogRaw(@"fixups fuera");
        } else {
            const uint8_t *base = le + (ch->dataoff - leOff);
            const struct dyld_chained_fixups_header *fh = (const void *)base;
            vxLogRaw([NSString stringWithFormat:@"cf v=%u imp=%u fmt=%u symfmt=%u io=%u so=%u",
                      fh->fixups_version, fh->imports_count, fh->imports_format,
                      fh->symbols_format, fh->imports_offset, fh->symbols_offset]);
            if (fh->imports_format == DYLD_CHAINED_IMPORT ||
                fh->imports_format == DYLD_CHAINED_IMPORT_ADDEND ||
                fh->imports_format == DYLD_CHAINED_IMPORT_ADDEND64) {
                const uint8_t *ib = base + fh->imports_offset;
                const char *sb = (const char *)(base + fh->symbols_offset);
                uint32_t lim = fh->imports_count < 300 ? fh->imports_count : 300;
                for (uint32_t i = 0; i < lim; i++) {
                    const struct dyld_chained_import *im =
                        (const void *)(ib + (size_t)i * sizeof(*im));
                    const char *nm = sb + im->name_offset;
                    vxLogRaw([NSString stringWithFormat:@"IM %u %s", im->lib_ordinal, nm]);
                    for (int t = 0; t < VX_N; t++) {
                        if (!strcmp(nm, vxNames[t] + 1)) {
                            vxLogRaw([NSString stringWithFormat:@"HIT %s i=%u", nm, i]);
                        }
                    }
                }
            }
        }
    }

    // direcciones y coincidencias de punteros
    for (int t = 0; t < VX_N; t++) {
        const char *nm = vxNames[t];
        void *a = dlsym(RTLD_DEFAULT, nm + 1);
        if (!a) a = dlsym(RTLD_DEFAULT, nm);
        uint64_t raw = (uint64_t)a, stp = VX_STRIP(a);
        uint32_t mraw = 0, mstp = 0;
        uint64_t first = 0;

        if (a) {
            const struct load_command *q = (const void *)(h + 1);
            for (uint32_t i = 0; i < h->ncmds; i++) {
                if (q->cmdsize < 8) break;
                if (q->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64 *sg = (const void *)q;
                    if ((sg->initprot & VM_PROT_WRITE) && !strncmp(sg->segname, "__DATA", 6)) {
                        const struct section_64 *s = (const void *)(sg + 1);
                        for (uint32_t j = 0; j < sg->nsects; j++, s++) {
                            const uint64_t *w = (const void *)((const uint8_t *)h + (s->addr - txtVm));
                            for (uint64_t k = 0; k < s->size / 8; k++) {
                                if (w[k] == raw) { if (!mraw) first = (uint64_t)&w[k]; mraw++; }
                                else if (VX_STRIP(w[k]) == stp) { if (!mstp) first = (uint64_t)&w[k]; mstp++; }
                            }
                        }
                    }
                }
                q = (const void *)((const char *)q + q->cmdsize);
            }
        }
        vxLogRaw([NSString stringWithFormat:@"Q %s a=%llx raw=%u stp=%u first=%llx",
                  nm, raw, mraw, mstp, first]);
    }
}

static void vxRetry(void);

static void vxStep(void) {
    vxDump();
    if (++vxTries >= VX_TRIES) return;
    vxRetry();
}

static void vxRetry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200ull * NSEC_PER_MSEC),
                   dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}

__attribute__((constructor))
static void vxInit(void) {
    vxLogRaw(@"==== 172 diag ====");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ vxStep(); });
}
