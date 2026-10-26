# GDB debugging on NOI Linux 2.0

This guide describes version 1.1.2.

The native IDE uses the installed GDB 9.1 through its MI2 protocol. Starting a
debug session rebuilds the current source or project with `-g3 -O0` and frame
pointers, then stops at `main`. Cancelling Save, failing compilation, or
cancelling compilation does not start an older executable.

Use Debug > Toggle Breakpoint (F4), or left-click the source line number or
marker gutter to toggle a breakpoint. A right-click or a drag does not toggle
one. F5 starts debugging, F7 steps over, F8 steps into, and F6 stops. Continue,
Step Into and Step Over are available while paused; Stop ends the debug session
and its program. A normal program exit also ends the session and unlocks the
editor. Breakpoints have red gutter dots; the stopped source line has a yellow
arrow. Their line colors follow the original theme's breakpoint and active
breakpoint entries rather than applying one fixed color to every theme.

The 1.1.1 layout follows Dev-C++ 5.11's bottom debugging sheet: commands, an
expression field and an expression/value table are on the left; program
input/output and the debugger log are pages on the right. A splitter adjusts
the two areas. The left sidebar's Debug page lists breakpoints, and the main
toolbar includes debugging actions. The compact GTK2 controls move toward the
original structure without promising identical VCL rendering.

Enter a line in the program input field and press Enter  to
supply standard input. Enter an expression, variable name or array subscript
and press Enter  while paused. The result appears in
the expression/value table and the debugger log. Expressions use the current
stopped frame; this table is not a persistent watch list.

Breakpoint changes while running use an asynchronous interrupt, wait for the
actual stop, edit the breakpoint, then resume only when the pause was internal.
A real user breakpoint or another signal remains paused. Stop cancels a pending
edit and its automatic resume. Continue, stepping and evaluation are disabled
during the change. This path has passed real GDB 9.1 and GTK2 mouse regressions.

Input/output uses a separate POSIX pseudo-terminal created with `openpty` from
Ubuntu 20.04's `libutil` (part of `libc6`). The program's terminal is assigned
with `-inferior-tty-set`; program input is never sent into GDB's MI command
pipe. The output widget displays text; it does not emulate terminal screen
control sequences or provide a full-screen curses interface.

The IDE launches GDB using `TProcess.Executable` and separate `Parameters`.
GDB 9.1's normal Unix inferior launcher uses a shell. Run arguments are parsed
into separate values by the IDE, each value is quoted with POSIX single quotes,
and that argument list is passed through one MI-encoded `set args` command.
This preserves literal spaces, quotes, backslashes and shell metacharacters.
Disabling GDB's startup shell in this version loses arguments containing spaces,
because its direct-launch path splits on whitespace without processing quotes.
No user argument is inserted as an unquoted shell expression.

`gdb_session.pas` polls MI output and terminal output without waiting for the
inferior. Reads are limited to 64 KiB per stream per tick, incomplete MI records
are capped at 1 MiB, and each visible text history is bounded. Shutdown has a
bounded termination fallback. Breakpoints are kept for the current IDE session;
Save As migrates their file paths after a successful save. Inserting, deleting
or moving source lines after stopping does not relocate their line numbers. Call-stack
browsing, persistent watch lists and conditional breakpoints are not implemented.

To test with the target FPC 3.0.4 and GDB 9.1:

```sh
bash tests/gdb-session-smoke.sh
# After building the IDE, exercise the actual GTK2 debugger controls:
xvfb-run -a bash tests/gdb-ui-smoke.sh
```

The real-process test covers MI strings and UTF-8, paths containing spaces,
literal arguments including a `$(touch ...)` payload, breakpoint creation and
deletion, source locations, stepping into and over, expression evaluation,
interactive standard input/output, normal exit/restart, and termination of the
inferior when stopping a running session. It compiles only its independent
helper and C fixture.

Both suites passed for 1.1.1 with the versions above in the Ubuntu 20.04
container. They cover actual line-number clicks, right-click/drag protection,
breakpoint changes while running and paused, safe Stop during an edit, and a
race with a real user breakpoint.
The GUI test checks breakpoint and stopped-line highlighting, read-only editors
while debugging (including Tab, Return, bracket pairing and completion, then
saving and comparing the buffer after Stop), stepping, evaluation, terminal
input/output, normal exit and
Stop restoring editability. It uses a test-only read-only GTK widget probe; the
probe is not part of the installed program. The original NOI Linux GNOME desktop
still needs acceptance testing.

Version 1.1.2 keeps only Debug and Stop in the top compile/debug toolbar,
as in the original 5.11 layout. Source stepping and Continue remain available
in the original bottom controls, menus and shortcuts. The extra Evaluate
and Send Input buttons were removed; press Enter in the relevant field.
