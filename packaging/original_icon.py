"""Export the original ICO to PNG using the GTK image loader, without redrawing."""
import ctypes
from ctypes.util import find_library
import os


def load_icon(path):
    pixbuf = ctypes.CDLL(find_library("gdk_pixbuf-2.0"))
    pixbuf.gdk_pixbuf_new_from_file.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
    pixbuf.gdk_pixbuf_new_from_file.restype = ctypes.c_void_p
    image = pixbuf.gdk_pixbuf_new_from_file(os.fsencode(path), None)
    if not image:
        raise ValueError("Cannot load original icon: " + str(path))
    return pixbuf, image


def release_icon(image):
    gobject = ctypes.CDLL(find_library("gobject-2.0"))
    gobject.g_object_unref.argtypes = [ctypes.c_void_p]
    gobject.g_object_unref(image)


def export_original_icon(source, destination):
    pixbuf, image = load_icon(source)
    try:
        pixbuf.gdk_pixbuf_savev.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                         ctypes.c_char_p, ctypes.c_void_p,
                                         ctypes.c_void_p, ctypes.c_void_p]
        pixbuf.gdk_pixbuf_savev.restype = ctypes.c_int
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not pixbuf.gdk_pixbuf_savev(image, os.fsencode(destination), b"png", None, None, None):
            raise ValueError("Cannot export original icon: " + str(destination))
        destination.chmod(0o644)
    finally:
        release_icon(image)


def icon_pixels(path):
    """Read tightly packed RGBA rows for comparison, ignoring row padding."""
    pixbuf, image = load_icon(path)
    try:
        for name in ("width", "height", "n_channels", "rowstride"):
            function = getattr(pixbuf, "gdk_pixbuf_get_" + name)
            function.argtypes = [ctypes.c_void_p]
            function.restype = ctypes.c_int
        width = pixbuf.gdk_pixbuf_get_width(image)
        height = pixbuf.gdk_pixbuf_get_height(image)
        channels = pixbuf.gdk_pixbuf_get_n_channels(image)
        stride = pixbuf.gdk_pixbuf_get_rowstride(image)
        pixbuf.gdk_pixbuf_get_pixels.argtypes = [ctypes.c_void_p]
        pixbuf.gdk_pixbuf_get_pixels.restype = ctypes.c_void_p
        pixels = pixbuf.gdk_pixbuf_get_pixels(image)
        return width, height, channels, b"".join(
            ctypes.string_at(pixels + row * stride, width * channels)
            for row in range(height))
    finally:
        release_icon(image)
