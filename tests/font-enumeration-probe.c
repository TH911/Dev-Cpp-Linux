/* Simulate a slow legacy X font server. Fontconfig/Pango rendering stays real. */
#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
char **XListFonts(Display *display, const char *pattern, int maximum, int *count) {
    static char **(*actual)(Display *, const char *, int, int *);
    if (!actual) actual = dlsym(RTLD_NEXT, "XListFonts");
    const char *path = getenv("DEVC_FONT_ENUM_PROBE");
    if (path && maximum >= 1000) {
        FILE *out = fopen(path, "a");
        if (out) { fprintf(out, "%s %d\n", pattern, maximum); fclose(out); }
        sleep(5);
    }
    return actual(display, pattern, maximum, count);
}
/* Current Lazarus GTK2 builds enumerate every Pango family and face instead. */
void pango_context_list_families(void *context, void ***families, int *count) {
    static void (*actual)(void *, void ***, int *);
    if (!actual) actual = dlsym(RTLD_NEXT, "pango_context_list_families");
    const char *path = getenv("DEVC_FONT_ENUM_PROBE");
    if (path) {
        FILE *out = fopen(path, "a");
        if (out) { fputs("pango families\n", out); fclose(out); }
        sleep(5);
    }
    actual(context, families, count);
}
