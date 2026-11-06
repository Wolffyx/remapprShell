/* Drives a nested KWin's pointer through org_kde_kwin_fake_input.
   stdin lines: "move X Y" (absolute), "down", "up", "glide X1 Y1 X2 Y2 STEPS MS",
   "sleep MS", "key CODE" (pressed and let go), "press CODE", "release CODE"
   (held, for a modifier). Only ever pointed at a --virtual KWin's socket. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "fake-input-client.h"

static struct org_kde_kwin_fake_input *fi;

static void global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    (void)d;
    if (strcmp(iface, "org_kde_kwin_fake_input") == 0)
        fi = wl_registry_bind(r, name, &org_kde_kwin_fake_input_interface, ver < 4 ? ver : 4);
}
static void global_remove(void *d, struct wl_registry *r, uint32_t n) { (void)d; (void)r; (void)n; }
static const struct wl_registry_listener rl = { global, global_remove };

static void moveto(struct wl_display *dpy, double x, double y) {
    org_kde_kwin_fake_input_pointer_motion_absolute(fi, wl_fixed_from_double(x), wl_fixed_from_double(y));
    wl_display_flush(dpy);
}

int main(void) {
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "no display\n"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &rl, NULL);
    wl_display_roundtrip(dpy);
    if (!fi) { fprintf(stderr, "no fake input global\n"); return 1; }
    org_kde_kwin_fake_input_authenticate(fi, "rig", "testing");
    wl_display_roundtrip(dpy);
    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        double a, b, c, e; int steps, ms;
        if (sscanf(line, "move %lf %lf", &a, &b) == 2) moveto(dpy, a, b);
        else if (strncmp(line, "down", 4) == 0) { org_kde_kwin_fake_input_button(fi, 0x110, 1); wl_display_flush(dpy); }
        else if (strncmp(line, "up", 2) == 0) { org_kde_kwin_fake_input_button(fi, 0x110, 0); wl_display_flush(dpy); }
        else if (sscanf(line, "glide %lf %lf %lf %lf %d %d", &a, &b, &c, &e, &steps, &ms) == 6) {
            for (int i = 1; i <= steps; i++) {
                moveto(dpy, a + (c - a) * i / steps, b + (e - b) * i / steps);
                usleep(ms * 1000);
            }
        }
        else if (sscanf(line, "sleep %d", &ms) == 1) usleep(ms * 1000);
        else if (sscanf(line, "press %d", &ms) == 1) { org_kde_kwin_fake_input_keyboard_key(fi, ms, 1); wl_display_flush(dpy); }
        else if (sscanf(line, "release %d", &ms) == 1) { org_kde_kwin_fake_input_keyboard_key(fi, ms, 0); wl_display_flush(dpy); }
        else if (sscanf(line, "key %d", &ms) == 1) {
            org_kde_kwin_fake_input_keyboard_key(fi, ms, 1); wl_display_flush(dpy);
            usleep(20000);
            org_kde_kwin_fake_input_keyboard_key(fi, ms, 0); wl_display_flush(dpy);
        }
        wl_display_roundtrip(dpy);
    }
    wl_display_disconnect(dpy);
    return 0;
}
