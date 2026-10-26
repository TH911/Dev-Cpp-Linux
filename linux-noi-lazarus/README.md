# Dev-C++ 5.11 for NOI Linux 2.0

This is the **Lazarus/LCL native port in progress**. It uses only software
listed in the official NOI Linux 2.0 environment: Lazarus 2.0.6, FPC 3.0.4,
GCC/G++ 9.3 and GDB 9.1. This program follows Orwell Dev-C++ 5.11's main window
structure, menu names, F9/F10/F11 actions, and `.dev` project format.
The beta branch adds installed Consolas detection and a monospace fallback; see
[font setup](FONTS.md). Existing user font preferences are retained.

This beta build is **1.1.3~beta1**. Test packages are available from
[beta Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml?query=branch%3Abeta).
The stable release is [v1.1.2](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.1.2).

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
needed. Instance forwarding is now separated by executable path and version, so an
installed release does not activate a running source build or another version.
Close earlier windows when upgrading to avoid confusing them with the new IDE.
`bash launch.sh --new-window file.cpp` explicitly starts a new window. Desktop
registration adds a New Window action and a second Open With application,
plus GNOME Files' Scripts > Open in New Window (Dev-Cpp) context entry (Chinese
when the interface language is Chinese). It forwards all selected files.
`F9` compiles, `Ctrl+F9` checks syntax, `F10` runs, and `F11` compiles and runs in GNOME Terminal.
Execute > Abort Compilation stops an active compiler process.
The application starts with no document. Ctrl+N creates Untitled1, and the
number increases during the current application run. Ctrl+N/O/S/W/F/G and
Ctrl+Shift+S Save As, Ctrl+Shift+A Save All, Ctrl+B Open Containing Folder,
Ctrl+Y redo, Ctrl+R replace, Ctrl+H project options, Ctrl+/ toggle line
comment, Ctrl+; toggle inline comment, Ctrl+Shift+F Find All,
Ctrl+Shift+R Replace All in the active file, Ctrl+Tab/Shift+Ctrl+Tab tab
switching, and Ctrl+Shift+W close all work while the editor has focus. Ctrl+1..9 toggles
numbered bookmarks, Alt+1..9 jumps to them, and Ctrl+Shift+Up/Down moves the
current line or selection as one undoable action. View includes full screen
(Ctrl+F11), status-bar visibility, compiler log (Ctrl+Alt+L), and editor focus
(Ctrl+Alt+E). File > Recent Files / Recent Projects retains the last ten entries;
Close Project supports saving or cancelling before closing project documents.
F3 searches from the caret and wraps without moving the caret if nothing is
found. Dropping source or `.dev` files
onto the window opens them. Ctrl+click opens local or installed headers and
finds simple function definitions in the current file, open documents, project
files, and local quoted headers. Template, macro, and overload resolution are
not yet part of the navigation index.

Launching a source build registers `Dev-Cpp` in the desktop's **Open With** list for C/C++
files using only your user account. To make it the default application for
`.cpp` and `.c` files, run `bash register-desktop.sh --default` in this folder.
No sudo or network connection is needed. The user-level desktop entry points
to this folder, so rerun the launcher after moving it. Source desktop entries use the separate `devcpp-noi-source.desktop` identity.
The installed package has its own visible `devcpp-noi-installed.desktop` entry,
so rebuilding from source does not shadow the installed application. The source
entry is hidden from menus when the package is installed, keeping one visible
Dev-Cpp application. Source entries are refreshed by `bash run.sh` or
`bash register-desktop.sh --default`.
When the package is installed, the explicit `--default` command chooses the
installed entry. Normal launching or package installation does not change MIME
defaults. See [launcher migration](../docs/PACKAGING.md).

Current implementation: tabbed SynEdit editing with C/C++ syntax highlighting,
line numbers, literal Tab indentation with width 4 on Enter and Tab (including
Enter between `{}`), caret movement across each whole Tab, preserved Tab-only
lines, colored preprocessor directives and modern C++ keywords, hidden gutter
change bars, four selectable original syntax themes (Classic Plus, Twilight, Visual Studio
and Obsidian), with independent bracket highlighting and configurable font;
Classic Plus retains red symbols, bold blue strings, blue comments, a light
gray gutter, turquoise current-line color and red matched-bracket backgrounds, vertical caret movement with a remembered visual column
and 4-column Tab width (clamped only on shorter lines until a nonvertical action), Home toggling
between first nonblank character and column one,
and automatic `()`, `[]`, `{}`, quote pairing and pair deletion (`struct` and `class`
declarations close with `};`); word completion from C++ keywords and identifiers in the current
file (`Ctrl+Space` or Edit > Code Completion), plus `struct`/`class`
member completion after `.`, `->`, `::` from the current file and local quoted
headers. `using` and `typedef` aliases and `struct Node {} a,b;` declarations
are indexed. Common standard container members such as `vector<int> g; g.` are
indexed when their standard header is included. The completion popup uses
the original borderless layout, handles Backspace through the dot,
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
The compiler dialog supports named profiles: create, copy, delete and switch
independent C/C++ commands and flags. The toolbar selects the active profile;
Cancel discards dialog edits. Tools > Editor Theme changes themes immediately
for open and new documents; editor options also select a font and size. Theme,
font and active compiler profile persist across restarts.
Remove Windows-only `-Wl,--stack=...` from
Linker flags on NOI Linux; Linux `ld` rejects that option. The compile log
shows arguments separated by spaces. F10/F11 launch GNOME Terminal and run through
the included `console-pauser.sh`, which displays elapsed time, exit status,
and a UTF-8 keypress prompt. The member index does not yet parse the full C++
standard library or resolve overloads, macros, and expression chains.
Debug > Start Debugging (F5) rebuilds with debug information and stops at
`main`. F4 toggles a breakpoint, F7 steps over, F8 steps into, and F6 stops the
session. Left-clicking a line number or gutter marker also toggles its
breakpoint; right-clicks and drag selection do not toggle it. Red dots mark
breakpoints, yellow arrows mark the stopped source line, and line colors come
from the corresponding original syntax theme.
The 1.1.1 Debug report tab places commands and an expression/value table on the
left, with program input/output and the GDB log on the right. The left sidebar
Debug page lists breakpoints; the main toolbar provides debugger actions.
The compact Sans 9 interface and panel structure move toward the original
5.11 layout while remaining native GTK2 controls. Editors become read-only during a session and
are restored after Stop or normal exit. See [the debugger guide](../docs/DEBUGGING.md).
Persistent watches, conditional breakpoints, call-stack browsing, attach and
other advanced debugger features remain pending. Project resource builds,
printing/export, full C++ signature resolution, a second editor view and
full-file formatting are also pending. F9 currently recompiles all project
sources, so F12 has the same compilation scope until an incremental builder
exists. Ctrl+Shift+S is Save As in
this port as requested; original Orwell Dev-C++ used it for Save All, which is
Ctrl+Shift+A here. Find All currently searches open documents, and Replace All
currently acts on the active document.

Execute > Parameters configures program arguments and working directory
separately from compiler flags. Project values are stored in the `.dev` file;
single-file settings do not leak into projects. Arguments support quoted
spaces and empty values. FPC 3.0.x truncates a raw process argument list at an
empty value, so the terminal runner uses a fixed Bash `exec` wrapper with every
path and argument individually quoted as a literal. Shell metacharacters in
arguments are not evaluated.

Saving uses an atomic same-directory replacement, checks for external changes
and preserves file permissions. Symlink aliases identify the same document;
Save As refuses the path of another open buffer and updates project unit
references when applicable. Cancel leaves the document identity intact.
Modified/deleted files prompt before reload or overwrite. Compilation publishes
a new executable only on success; failure/cancellation preserves the previous
file but prevents F10 from silently running it as the latest result.

The 1.1.2 source was built and tested in an Ubuntu 20.04 amd64 container
with Lazarus 2.0.6, FPC 3.0.4, GCC/G++ 9.3.0 and GDB 9.1. Run
`bash ci/check.sh` from the repository root with that toolchain to build and
execute the helper and real GTK2 interaction suites. They cover file identity
and save conflicts, Home/Shift+Home and undo, focus, quoted execution arguments,
working directories, compilation cancellation, actual GDB sessions, themes
and compiler profiles, along with the revised layout, actual line-number clicks,
running breakpoint changes, About links/clipboard and launcher migration.
See [the parity audit](../docs/DEVCPP-5.11-PARITY.md).
Tests use Xvfb and the XTerm fallback. They do not reproduce the official NOI
Linux ISO's GNOME desktop or kernel; visual behavior and GNOME Terminal still
need acceptance testing on that desktop.

Future Release assets include a source ZIP and tar.gz rooted at
`linux-noi-lazarus/`, plus an amd64 `.deb` with the prebuilt binary. Install
with `sudo apt install ./devcpp-noi_VERSION_amd64.deb`, then open **Dev-Cpp** from the software panel or run `/usr/bin/devcpp-noi`.
Use `/usr/bin/devcpp-noi --version` or Help > About to check the version and
actual executable path. The installer keeps old custom launchers and MIME
defaults; recognized historical source launchers are backed up and migrated.
APT installs runtime dependencies; Lazarus/FPC are required only for source
builds. The installed program uses `/usr/lib/devcpp-noi` read-only and stores
user settings separately. See [packaging and uninstall instructions](../docs/PACKAGING.md).

Help > About now shows the application version, the clickable GitHub project
link, Orwell Dev-C++ 5.11 attribution and GPL license. Build and installation
details show the executable and configuration paths, installation type, FPC
version and target platform. Copy Details copies this information for bug
reports. For a terminal-only version check, use `./devcpp-noi --version` from a
source build or `/usr/bin/devcpp-noi --version` for the package; no GUI window
is opened. Check the executable path in About when diagnosing an old launcher.

The launcher now initializes Xlib thread support before GTK and uses CreateNew
for the resource-free main form. Runtime stderr is saved in
`~/.cache/devcpp-noi/runtime.log` (or `$XDG_CACHE_HOME/devcpp-noi/runtime.log`).
These startup changes address possible causes of the reported XCB assertion;
the complete cause still needs confirmation on the NOI Linux desktop.

The port is GPL-2.0-or-later; see `COPYING.txt`. The toolbar bitmaps are copied
from Orwell Dev-C++ 5.11's `Source/Images/newlook` directory.

Version 1.1.2 uses the name Dev-Cpp and the unchanged upstream ICO for both
source and installed launches. Extra toolbar Continue/Step/Breakpoint actions
and the added Evaluate/Send/Copy buttons were removed. Evaluation and program
input use Enter; About details remain selectable with Ctrl+A/C. The source
launcher prints the version reported by its actual compiled binary.
