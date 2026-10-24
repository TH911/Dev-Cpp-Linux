# Dev-C++ 5.11 for NOI Linux 2.0

This is the **Lazarus/LCL native port in progress**. It uses only software
listed in the official NOI Linux 2.0 environment: Lazarus 2.0.6, FPC 3.0.4,
and GCC/G++ 9.3. This program follows Orwell Dev-C++ 5.11's main window
structure, menu names, F9/F10/F11 actions, and `.dev` project format.

On a stock NOI Linux 2.0 desktop, open a terminal in this directory and run:

```sh
bash run.sh [source.cpp | project.dev]
```

The terminal launcher builds with the preinstalled `lazbuild`; desktop icons
and file association use `launch.sh` to start an up-to-date binary immediately.
If no binary exists or sources are newer, the desktop launcher builds once and saves any build error
to `~/.cache/devcpp-noi/launch-build.log`. No network access or additional
packages are needed.
The build explicitly selects the GTK2 widget set used by NOI Linux 2.0.
It links to `devcpp-noi.build`, then atomically moves the successful
output to `devcpp-noi`. A build lock serializes builders. This avoids Linux's
`Text file busy` error when an earlier IDE executable is still running.
Normal launches forward file paths to an existing window using FPC SimpleIPC,
which is part of the preinstalled Free Pascal libraries. The UI polls requests
without creating a background GUI thread. If no window exists, a window starts.
The desktop launcher attempts forwarding before checking whether a build is
needed. Close all windows from an earlier release once when applying this
update, because those releases do not implement the forwarding protocol.
`bash launch.sh --new-window file.cpp` explicitly starts a new window. Desktop
registration adds a New Window action and a second Open With application,
plus GNOME Files' Scripts > Open in New Window (Dev-C++) context entry (Chinese
when the interface language is Chinese). It forwards all selected files.
`F9` compiles, `Ctrl+F9` checks syntax, `F10` runs, and `F11` compiles and runs in GNOME Terminal.
Execute > Abort Compilation stops an active compiler process.
The application starts with no document. Ctrl+N creates Untitled1, and the
number increases during the current application run. Ctrl+N/O/S/W/F/G and
Ctrl+Shift+S Save As, Ctrl+Shift+A Save All, Ctrl+B Open Containing Folder,
Ctrl+Y redo, Ctrl+R replace, Ctrl+H project options, Ctrl+/ toggle line
comment, Ctrl+; toggle inline comment, Ctrl+Shift+F Find All,
Ctrl+Shift+R Replace All in the active file, Ctrl+Tab/Shift+Ctrl+Tab tab
switching, and Ctrl+Shift+W close all work while the editor has focus.
F3 searches from the caret and wraps without moving the caret if nothing is
found. Dropping source or `.dev` files
onto the window opens them. Ctrl+click opens local or installed headers and
finds simple function definitions in the current file, open documents, project
files, and local quoted headers. Template, macro, and overload resolution are
not yet part of the navigation index.

Launching once registers `Dev-C++` in the desktop's **Open With** list for C/C++
files using only your user account. To make it the default application for
`.cpp` and `.c` files, run `bash register-desktop.sh --default` in this folder.
No sudo or network connection is needed. The user-level desktop entry points
to this folder, so rerun the launcher after moving it. Existing desktop entries
are refreshed by `bash run.sh` or `bash register-desktop.sh --default`.

Current implementation: tabbed SynEdit editing with C/C++ syntax highlighting,
line numbers, literal Tab indentation with width 4 on Enter and Tab (including
Enter between `{}`), caret movement across each whole Tab, preserved Tab-only
lines, colored preprocessor directives and modern C++ keywords, hidden gutter
change bars, original Classic Plus syntax colors (including red symbols and
bold blue strings), fixed Windows-blue comments and light gray gutter instead
of GTK theme colors, turquoise current-line color and red matched-bracket
character backgrounds, vertical caret movement with a remembered visual column
and 4-column Tab width (clamped only on shorter lines until a nonvertical action), Home toggling
between first nonblank character and column one,
and automatic `()`, `[]`, `{}`, quote pairing and pair deletion (`struct` and `class`
declarations close with `};`); word completion from C++ keywords and identifiers in the current
file (`Ctrl+Space` or Edit > Code Completion), plus `struct`/`class`
member completion after `.`, `->`, `::` from the current file and local quoted
headers. `using` and `typedef` aliases and `struct Node {} a,b;` declarations
are indexed. Common standard container members such as `vector<int> g; g.` are
indexed when their standard header is included. The completion popup uses
the original borderless Courier layout, handles Backspace through the dot,
and supports Enter, Escape, and arrow selection while the editor retains
keyboard focus. It distinguishes member functions, types, and
variables; function candidates show `()` and inserting one adds `()` unless an
opening parenthesis is already present. Escape suppresses immediate reopening
until the source changes; array element expressions such as `s[1].` resolve
back to the declared array name. Known standard container members are indexed
from their declared type even when the header line is absent from the current
snippet. Ctrl+mouse wheel zooms the fonts of all open editors. New files are
named Untitled1, Untitled2, and so on for the current session; the Save dialog
prefills UntitledN.cpp. String quote delimiters follow the original string
color; bracket matching excludes quotes, as in Orwell Dev-C++.
The interface defaults to Chinese. Tools > Language switches between Chinese
and English immediately; the choice persists in `~/.config/devcpp-noi.ini`.
Menus, tooltips, settings, dialog buttons, status text,
and console exit messages follow the language. Compiler diagnostics and C++
source identifiers retain their original text.
Integer suffixes are validated as a whole: `1ll` and `1ull` are colored as
numbers, while malformed literals such as `1llllll` are black. Ctrl+; acts only
on a selection and retains the selected content when toggling comment markers.
Home first goes to the first nonblank character, skipping spaces and Tab
characters. Consecutive Home presses toggle between that position and column
one; other keys and mouse actions reset the cycle. It is intercepted before
SynEdit's native Home processing. Shift+Up/Down uses the same remembered visual
column as Up/Down, with a stable selection anchor. Ctrl+Backspace from inside
an empty function-call pair removes both parentheses with the function name.
Confirmation and input dialogs measure labels and buttons using the current
font instead of fixed text heights. Compiler settings place labels above their
fields and size each row to fit. Dialog buttons are translated directly, so
Chinese confirmations no longer retain the native English Yes/No captions.
Angle bracket pairing is restricted to `#include<...>`; comparison and template
expressions do not insert `>`. Completion categories such as `function` retain
their English spelling. Save As asks before replacing an existing file.
Compiler diagnostics move the caret to the reported position and paint the
error line white on maroon, as in the original Classic Plus theme; editing or
compiling again clears that marker.
Function completion candidates show the return type and typed parameters. After insertion,
the argument tip marks the active parameter in red. Candidate row height is
the measured Courier font height plus two pixels; the tip uses measured text
height plus six pixels. The tip is a panel within
the editor window, so it cannot take focus. Function declarations do not show
a call tip. The popup is scheduled
immediately after the triggering key, with no artificial delay. An externally
deleted open file prompts to keep it in the editor or close it.
Closing an untouched empty UntitledN document needs no confirmation. Modified
UntitledN and named files prompt to save, discard, or cancel. Opening an
existing file does not advance the UntitledN counter.
Original New Look toolbar icons and left-side tabs; editor options for font
size and tab width, plus project creation, adding/removing files and project
compiler flags in the original `.dev` INI format;
open/save, project tree, single-file and multi-file console compilation,
search, go to line, and a compiler error list that selects the first error
and highlights its source line. Execute > Compiler Parameters (also available
under Tools, or Ctrl+Alt+O) edits the C and C++ compiler commands, compile flags
such as `-std=c++14`, and Linux linker flags; these settings are saved
in `~/.config/devcpp-noi.ini`. New C++ settings include `-O2 -std=c++14`;
an unchanged earlier default is upgraded, while custom saved flags are kept.
Remove Windows-only `-Wl,--stack=...` from
Linker flags on NOI Linux; Linux `ld` rejects that option. The compile log
shows arguments separated by spaces. F10/F11 launch GNOME Terminal and run through
the included `console-pauser.sh`, which displays elapsed time, exit status,
and a UTF-8 keypress prompt. The member index does not yet parse the full C++
standard library or resolve overloads, macros, and expression chains.
Debugging, translations, project
resource builds, printing, full C++ signature resolution, and pixel-identical VCL
controls are also pending. F9 currently recompiles all project sources, so
F12 has the same compilation scope until an incremental project builder exists.
Shortcuts for the unavailable debugger, printing, a second editor view, full-file formatting,
and incremental project builds remain unavailable. Ctrl+Shift+S is Save As in
this port as requested; original Orwell Dev-C++ used it for Save All, which is
Ctrl+Shift+A here. Find All currently searches open documents, and Replace All
currently acts on the active document.

The application has been built and smoke-tested in an Ubuntu 20.04 amd64
container with Lazarus 2.0.6, FPC 3.0.4, and GCC/G++ 9.3.0. The automated test
opens a C++ file in a path containing Chinese characters and spaces, compiles
with F9, runs with F10 and F11, and forwards a second file to the existing window.
See `../tests/noi-linux-smoke.sh` and `../.github/workflows/noi-linux.yml`.
The test uses Xvfb and the XTerm fallback. It does not reproduce the official
NOI Linux ISO's GNOME desktop or kernel; visual behavior and GNOME Terminal
still need acceptance testing on that desktop.

The launcher now initializes Xlib thread support before GTK and uses CreateNew
for the resource-free main form. Runtime stderr is saved in
`~/.cache/devcpp-noi/runtime.log` (or `$XDG_CACHE_HOME/devcpp-noi/runtime.log`).
These startup changes address possible causes of the reported XCB assertion;
the complete cause still needs confirmation on the NOI Linux desktop.

The port is GPL-2.0-or-later; see `COPYING.txt`. The toolbar bitmaps are copied
from Orwell Dev-C++ 5.11's `Source/Images/newlook` directory.
