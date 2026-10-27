# 界面语言资源 / Interface language resources

本目录包含 Orwell Dev-C++ 5.11 原版的全部 33 份 `.lng` 语言文件，转换为 UTF-8，保留原来的编号、文本和注释。来源为[功能对齐清单](../../docs/DEVCPP-5.11-PARITY.md)记录的原版源码；转换脚本为 [`tools/import-upstream-ui.py`](../../tools/import-upstream-ui.py)。原版语言文件及其贡献者归属于 Dev-C++ 原项目，随本移植版按 GPL-2.0-or-later 提供，参见上级目录的 `COPYING.txt`。

在“工具 → 语言”中选择语言后，界面立即切换，设置保存到 `~/.config/devcpp-noi.ini` 的 `[Interface] Language`，重启仍使用该语言。已有 `zh` / `en` 设置和原版 `.lng` 文件名均可识别。无效设置回退到英语。仅翻译界面文字，不修改源代码、路径、字体名称或用户输入。

已有原版翻译按同一编号复用；Linux 特有提示以及原版没有的功能文字，在缺少译文时回退到英语。简体中文保留本移植版原有的补充译文。语言文件数量不等于全部新增文字已完成母语校对；欢迎补充译文并验证实际界面。格式参数不兼容的旧译文不会交给 `Format` 使用。

This directory contains all 33 original Orwell Dev-C++ 5.11 `.lng` catalogs, converted to UTF-8 while retaining their numbered entries, text and comments. The upstream source is identified in the [parity audit](../../docs/DEVCPP-5.11-PARITY.md); the reproducible conversion script is [`tools/import-upstream-ui.py`](../../tools/import-upstream-ui.py). Translation credits remain with the original project and contributors; the catalogs are distributed with this GPL-2.0-or-later port (see `COPYING.txt` in the parent directory).

Select **Tools → Language** to apply a language immediately and save `[Interface] Language` in `~/.config/devcpp-noi.ini`. Existing `zh` / `en` settings and original `.lng` filenames are accepted; unknown values fall back to English. Source text, paths, font names and user input are not translated.

Original interface translations are reused by their IDs. Linux-specific or newly introduced text without an upstream translation falls back to English. Simplified Chinese keeps the port's existing additional translations. Catalog availability does not mean every new phrase has been proofread by a native speaker. Incompatible format placeholders are rejected in favor of the English text.


希伯来语原文件仍使用早期编号，运行时通过 `legacy_ids.ini` 适配为 5.11 编号，不直接混用旧、新数字。对应关系按语言常量名称生成，依据 [Bloodshed 4.9.9.2 官方源码](https://sourceforge.net/projects/dev-cpp/files/Sources/Dev-C%2B%2B%204.9.9.2%20sources/devcpp-4.9.9.2-src.zip/download)中的 `source/LangIDs.inc`；已核对源码 ZIP 的 SHA-256：`39cbc145d00f4a4ae420604c347ac8fa44f7ff7147d224bdedff79d56af1d3aa`。原文件内容和贡献者注释保持不变；没有对应项时回退英语。

The original Hebrew file retains an older ID scheme. `legacy_ids.ini` maps semantic constant names from the official Bloodshed 4.9.9.2 `source/LangIDs.inc` to 5.11 IDs, instead of matching unrelated numeric IDs. The source ZIP SHA-256 is recorded above and in `tools/legacy-lang-symbols.json`. The original catalog and contributor comments remain intact; unmapped entries fall back to English.

| 配置值 / Setting | 原版名称 / Upstream name | 文件 / File | 原始编码 / Original encoding |
| --- | --- | --- | --- |
| `zh` | 简体中文/Chinese | `Chinese.lng` | `gbk` |
| `en` | English (Original) | `English.lng` | `cp1252` |
| `bg` | Bulgarian (Български) | `Bulgarian.lng` | `cp1251` |
| `ca` | Catalan (Català) | `Catalan.lng` | `cp1252` |
| `zh_TW` | Chinese (TW) | `Chinese_TC.lng` | `big5` |
| `hr` | Croatian | `Croatian.lng` | `cp1250` |
| `cs` | Czech (Čeština) | `Czech.lng` | `cp1250` |
| `da` | Danish | `Danish.lng` | `cp1252` |
| `nl` | Dutch (Nederlands) | `Dutch.lng` | `cp1252` |
| `et` | Estonian | `Estonian.lng` | `cp1252` |
| `fr` | French | `French.lng` | `cp1252` |
| `gl` | Galego | `Galego.lng` | `cp1252` |
| `de` | German (Deutsch) | `German.lng` | `cp1252` |
| `el` | Greek (Ελληνικά) | `Greek.lng` | `cp1253` |
| `he` | Hebrew | `Hebrew.lng` | `cp1255` |
| `hu` | Hungarian | `Hungarian.lng` | `cp1250` |
| `it` | Italian | `Italian.lng` | `cp1252` |
| `ja` | 日本語 | `Japanese.lng` | `cp932` |
| `ko` | Korean (한국어) | `Korean.lng` | `cp949` |
| `lv` | Latvian | `Latvian.lng` | `cp1257` |
| `nb` | Norwegian (Norsk bokmål) | `Norwegian.lng` | `cp1252` |
| `pl` | Polish (Polski) | `Polish.lng` | `cp1250` |
| `pt_BR` | Portuguese (Brazil) | `Portuguese.lng` | `cp1252` |
| `ro` | Romanian (Română) | `Romanian.lng` | `cp1250` |
| `ru` | Russian (Русский) | `Russian.lng` | `cp1251` |
| `sk` | Slovak (Slovenský) | `Slovak.lng` | `cp1250` |
| `sl` | Slovenian (slovenščina) | `Slovenian.lng` | `cp1250` |
| `es_419` | Spanish (Latino América) | `Spanish.lng` | `cp1252` |
| `es` | Español (Castellano) | `SpanishCastellano.lng` | `cp1252` |
| `es_CO` | Español (Colombia) | `SpanishColombia.lng` | `cp1252` |
| `sv` | Svenska | `Swedish.lng` | `cp1252` |
| `tr` | Turkish | `Turkish.lng` | `cp1254` |
| `uk` | Ukrainian (Українська) | `Ukrainian.lng` | `cp1251` |
