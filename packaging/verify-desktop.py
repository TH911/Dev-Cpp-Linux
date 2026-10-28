#!/usr/bin/env python3
"""Discover the installed application as a software panel does, then load its icon."""
import ctypes
from ctypes.util import find_library
from pathlib import Path


class GList(ctypes.Structure):
    pass


GList._fields_ = [('data', ctypes.c_void_p), ('next', ctypes.POINTER(GList)),
                 ('prev', ctypes.POINTER(GList))]
gio = ctypes.CDLL(find_library('gio-2.0'))
glib = ctypes.CDLL(find_library('glib-2.0'))
gobject = ctypes.CDLL(find_library('gobject-2.0'))
pixbuf = ctypes.CDLL(find_library('gdk_pixbuf-2.0'))
gio.g_app_info_get_all.restype = ctypes.POINTER(GList)
for function in ('g_app_info_get_id', 'g_app_info_get_name'):
    getattr(gio, function).argtypes = [ctypes.c_void_p]
    getattr(gio, function).restype = ctypes.c_char_p
gio.g_app_info_should_show.argtypes = [ctypes.c_void_p]
gio.g_app_info_should_show.restype = ctypes.c_int
gio.g_app_info_get_icon.argtypes = [ctypes.c_void_p]
gio.g_app_info_get_icon.restype = ctypes.c_void_p
gio.g_icon_to_string.argtypes = [ctypes.c_void_p]
gio.g_icon_to_string.restype = ctypes.c_void_p
glib.g_free.argtypes = [ctypes.c_void_p]
glib.g_list_free.argtypes = [ctypes.POINTER(GList)]
gobject.g_object_unref.argtypes = [ctypes.c_void_p]
pixbuf.gdk_pixbuf_new_from_file.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
pixbuf.gdk_pixbuf_new_from_file.restype = ctypes.c_void_p

apps = gio.g_app_info_get_all()
node = apps
found = False
visible_names = []
try:
    while node:
        app = node.contents.data
        desktop_id = gio.g_app_info_get_id(app)
        name = gio.g_app_info_get_name(app)
        shown = bool(gio.g_app_info_should_show(app))
        if shown and name:
            visible_names.append(name.decode())
        if desktop_id == b'dev-cpp-linux-installed.desktop':
            assert shown, 'The installed application is hidden from application menus'
            assert name == b'dev-cpp-linux', name
            icon = gio.g_app_info_get_icon(app)
            assert icon, 'The installed application has no icon'
            icon_text = gio.g_icon_to_string(icon)
            try:
                assert ctypes.string_at(icon_text) == b'/usr/share/pixmaps/dev-cpp-linux.ico'
            finally:
                glib.g_free(icon_text)
            found = True
        node = node.contents.next
    assert found, 'The application is absent from GIO application discovery'
    assert visible_names.count('dev-cpp-linux') == 1, 'Ambiguous duplicate dev-cpp-linux menu entries'
finally:
    node = apps
    while node:
        gobject.g_object_unref(node.contents.data)
        node = node.contents.next
    glib.g_list_free(apps)

icon_path = Path('/usr/share/pixmaps/dev-cpp-linux.ico')
assert icon_path.read_bytes() == Path('/usr/lib/dev-cpp-linux/devcpp.ico').read_bytes(), \
    'Desktop and program icons differ'
image = pixbuf.gdk_pixbuf_new_from_file(bytes(icon_path), None)
assert image, 'The original icon cannot be loaded by the desktop image loader'
gobject.g_object_unref(image)
print('PASS: GIO discovers one visible dev-cpp-linux application with the unchanged, loadable original icon')
