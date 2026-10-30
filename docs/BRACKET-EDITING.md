# 括号匹配和自动补全 / Bracket matching and completion

## 中文

`1.3.1~beta3` 修复两项括号交互问题：

- 红色匹配背景只应用于 C++ 代码中的 `()`、`[]`、`{}`。字符串、字符常量、行/块注释及原始字符串中的括号不参加匹配；其中的括号保留原有语法颜色，也不会干扰外层代码括号。
- 输入左括号时，检查右侧括号是否已经属于已有的括号对。已经配对时补齐新的一对；尚未配对时复用已有的右括号。

下表的 `|` 表示光标，不是实际源码：

| 输入前 | 输入 | 输入后 |
| --- | --- | --- |
| `f(\|)` | `(` | `f((\|))` |
| `a[\|]` | `[` | `a[[\|]]` |
| `{\|}` | `{` | `{{\|}}` |
| `\|)` | `(` | `(\|)` |

在字符串和注释中输入括号仍作为普通文字，不自动插入另一半。自动补全的一对括号可一次撤销、重做；仅移动光标查看匹配高亮不会修改文件。关闭语法着色后，匹配仍使用 C++ 上下文判断。

检查包含真实 GTK2 编辑区的像素观察、实际键盘输入和保存结果，以及嵌套、多行、UTF-8 字节坐标、转义引号和原始字符串的回归。

## English

Version `1.3.1~beta3` fixes two bracket interactions:

- Red matching backgrounds apply only to code delimiters `()`, `[]` and `{}`. String/character literals, comments and raw strings are excluded from matching and cannot interfere with surrounding code pairs. Their syntax colors are retained.
- A new opener gets its own closer when the adjacent closer already belongs to another opener. Only an orphan closer is reused. For example, typing `(` in `f(|)` produces `f((|))`; typing it before an orphan `|)` produces `(|)`. Here `|` denotes the caret.

Typing inside literals/comments remains ordinary text. Auto-pair insertion supports one-step Undo/Redo; moving the caret to view matching markup does not edit the document. Matching remains context-aware when syntax coloring is disabled.

Regression checks observe actual GTK2 editor pixels and exercise keyboard input, saved bytes, nested/multiline pairs, UTF-8 byte positions, escaped quotes and raw strings.
