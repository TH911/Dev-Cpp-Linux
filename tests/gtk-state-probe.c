/* Read-only GTK2 widget observation for xdotool regression tests.
 * Loaded only into the isolated test IDE with LD_PRELOAD. It never changes
 * focus, widget state, text, input events, or application/debugger behavior. */
#define _GNU_SOURCE
#include <gtk/gtk.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int installed;
static int first;

static void json_string(FILE *out, const char *text) {
    const unsigned char *p = (const unsigned char *)(text ? text : "");
    fputc('"', out);
    for (; *p; ++p) {
        if (*p == '"' || *p == '\\') fprintf(out, "\\%c", *p);
        else if (*p < 32) fprintf(out, "\\u%04x", *p);
        else fputc(*p, out);
    }
    fputc('"', out);
}

static gboolean inspect_tree_row(GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter, gpointer data) {
    (void)path;
    GString *result = data;
    for (int col = 0; col < gtk_tree_model_get_n_columns(model); ++col) {
        GValue value = G_VALUE_INIT;
        gtk_tree_model_get_value(model, iter, col, &value);
        if (G_VALUE_HOLDS_STRING(&value)) {
            const char *text = g_value_get_string(&value);
            if (text) { g_string_append(result, text); g_string_append_c(result, '\t'); }
        }
        g_value_unset(&value);
    }
    g_string_append_c(result, '\n');
    return FALSE;
}

static void inspect_widget(GtkWidget *widget, gpointer data) {
    FILE *out = data;
    char *owned_text = NULL;
    const char *text = "";
    if (GTK_IS_LABEL(widget)) text = gtk_label_get_text(GTK_LABEL(widget));
    else if (GTK_IS_ENTRY(widget)) text = gtk_entry_get_text(GTK_ENTRY(widget));
    else if (GTK_IS_BUTTON(widget)) text = gtk_button_get_label(GTK_BUTTON(widget));
    else if (GTK_IS_WINDOW(widget)) text = gtk_window_get_title(GTK_WINDOW(widget));
    else if (GTK_IS_TEXT_VIEW(widget)) {
        GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(widget));
        GtkTextIter start, end;
        gtk_text_buffer_get_bounds(buffer, &start, &end);
        owned_text = gtk_text_buffer_get_text(buffer, &start, &end, TRUE);
        text = owned_text;
    }
    if (GTK_IS_TREE_VIEW(widget)) {
        GtkTreeModel *model = gtk_tree_view_get_model(GTK_TREE_VIEW(widget));
        if (model) {
            GString *rows = g_string_new("");
            gtk_tree_model_foreach(model, inspect_tree_row, rows);
            owned_text = g_string_free(rows, FALSE); text = owned_text;
        }
    }
    if (!first) fputc(',', out);
    first = 0;
    fprintf(out, "{\"id\":\"%p\",\"type\":", (void *)widget);
    json_string(out, G_OBJECT_TYPE_NAME(widget));
    fprintf(out, ",\"grab\":%s", widget == gtk_grab_get_current() ? "true" : "false");
    fputs(",\"text\":", out); json_string(out, text);
    if (GTK_IS_LABEL(widget)) {
        int text_width = 0, text_height = 0;
        pango_layout_get_pixel_size(gtk_label_get_layout(GTK_LABEL(widget)), &text_width, &text_height);
        fprintf(out, ",\"text_width\":%d,\"text_height\":%d", text_width, text_height);
    }
    if (GTK_IS_FILE_CHOOSER(widget)) {
        char *folder = gtk_file_chooser_get_current_folder(GTK_FILE_CHOOSER(widget));
        fputs(",\"folder\":", out); json_string(out, folder); g_free(folder);
    }
    GtkAllocation allocation;
    gint root_x = 0, root_y = 0;
    gtk_widget_get_allocation(widget, &allocation);
    if (gtk_widget_get_realized(widget) && gtk_widget_get_window(widget)) {
        /* Native controls own a GdkWindow; labels and layout containers share
           their parent's window and need their allocation offset. Translating
           through a GtkWindow double-counts its allocation on some GTK2 modal
           windows, leaving the observed point in client coordinates. */
        gdk_window_get_origin(gtk_widget_get_window(widget), &root_x, &root_y);
        if (!gtk_widget_get_has_window(widget)) {
            root_x += allocation.x;
            root_y += allocation.y;
        }
    }
    fputs(",\"name\":", out); json_string(out, gtk_widget_get_name(widget));
    fprintf(out, ",\"parent\":\"%p\",\"x\":%d,\"y\":%d,\"width\":%d,\"height\":%d",
            (void *)gtk_widget_get_parent(widget), root_x, root_y,
            allocation.width, allocation.height);
    fprintf(out, ",\"focus\":%s,\"sensitive\":%s,\"visible\":%s",
            gtk_widget_has_focus(widget) ? "true" : "false",
            gtk_widget_is_sensitive(widget) ? "true" : "false",
            gtk_widget_get_visible(widget) ? "true" : "false");
    if (GTK_IS_ENTRY(widget) || GTK_IS_TEXT_VIEW(widget)) {
        GtkStyle *style = gtk_widget_get_style(widget);
        const GtkStateType states[] = {GTK_STATE_NORMAL, GTK_STATE_ACTIVE,
            GTK_STATE_SELECTED, GTK_STATE_INSENSITIVE};
        const char *names[] = {"normal", "active", "selected", "insensitive"};
        for (int i = 0; i < 4; ++i) {
            const GdkColor *text = &style->text[states[i]];
            const GdkColor *base = &style->base[states[i]];
            fprintf(out, ",\"%s_text\":\"%02x%02x%02x\",\"%s_base\":\"%02x%02x%02x\"",
                names[i], text->red >> 8, text->green >> 8, text->blue >> 8,
                names[i], base->red >> 8, base->green >> 8, base->blue >> 8);
        }
        if (GTK_IS_ENTRY(widget)) {
            gint start = 0, end = 0;
            gboolean selected = gtk_editable_get_selection_bounds(GTK_EDITABLE(widget), &start, &end);
            fprintf(out, ",\"selected\":%s", selected && start != end ? "true" : "false");
        }
    }
    fprintf(out, ",\"mapped\":%s,\"viewable\":%s}",
        gtk_widget_get_mapped(widget) ? "true" : "false",
        gtk_widget_get_window(widget) && gdk_window_is_viewable(gtk_widget_get_window(widget)) ? "true" : "false");
    g_free(owned_text);
    if (GTK_IS_CONTAINER(widget)) gtk_container_forall(GTK_CONTAINER(widget), inspect_widget, out);
}

static gboolean snapshot(gpointer unused) {
    (void)unused;
    const char *path = getenv("DEVC_GTK_STATE");
    if (!path || !*path) return TRUE;
    char *temporary = g_strdup_printf("%s.tmp", path);
    FILE *out = fopen(temporary, "w");
    if (out) {
        GList *windows = gtk_window_list_toplevels();
        fputc('[', out); first = 1;
        for (GList *p = windows; p; p = p->next) inspect_widget(p->data, out);
        fputs("]\n", out); fclose(out);
        g_list_free(windows);
        rename(temporary, path);
    }
    g_free(temporary);
    /* A test can request a screenshot explicitly; never capture every tick. */
    const char *image_path = getenv("DEVC_GTK_SCREENSHOT");
    if (image_path && *image_path) {
        char *request = g_strdup_printf("%s.request", image_path);
        if (access(request, F_OK) == 0) {
            GdkWindow *root = gdk_get_default_root_window();
            int width, height;
            gdk_drawable_get_size(root, &width, &height);
            GdkPixbuf *pixels = gdk_pixbuf_get_from_drawable(NULL, root, NULL,
                0, 0, 0, 0, width, height);
            if (pixels) {
                gdk_pixbuf_save(pixels, image_path, "png", NULL, NULL);
                g_object_unref(pixels);
            }
            unlink(request);
        }
        g_free(request);
    }
    return TRUE;
}

static void install_probe(void) {
    if (!installed) { installed = 1; g_timeout_add(80, snapshot, NULL); }
}

void gtk_init(int *argc, char ***argv) {
    void (*original)(int *, char ***) = dlsym(RTLD_NEXT, "gtk_init");
    original(argc, argv); install_probe();
}

gboolean gtk_init_check(int *argc, char ***argv) {
    gboolean (*original)(int *, char ***) = dlsym(RTLD_NEXT, "gtk_init_check");
    gboolean result = original(argc, argv);
    if (result) install_probe();
    return result;
}
