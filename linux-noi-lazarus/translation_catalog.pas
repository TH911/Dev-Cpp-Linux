unit translation_catalog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

function TranslateChinese(const EnglishText: string): string;
function TranslateEnglish(const ChineseText: string): string;

implementation

uses SysUtils;

type
  TTranslationEntry = record
    EnglishText: string;
    ChineseText: string;
  end;

const
  Translations: array[0..153] of TTranslationEntry = (
    (EnglishText: '&File'; ChineseText: '文件(&F)'),
    (EnglishText: '&Edit'; ChineseText: '编辑(&E)'),
    (EnglishText: '&Search'; ChineseText: '搜索(&S)'),
    (EnglishText: '&View'; ChineseText: '查看(&V)'),
    (EnglishText: '&Project'; ChineseText: '项目(&P)'),
    (EnglishText: 'E&xecute'; ChineseText: '运行(&X)'),
    (EnglishText: '&Tools'; ChineseText: '工具(&T)'),
    (EnglishText: '&Help'; ChineseText: '帮助(&H)'),
    (EnglishText: '&New Source File'; ChineseText: '新建源代码(&N)'),
    (EnglishText: '&Open project or file...'; ChineseText: '打开项目或文件(&O)...'),
    (EnglishText: '&Save'; ChineseText: '保存(&S)'),
    (EnglishText: 'Save &As...'; ChineseText: '另存为(&A)...'),
    (EnglishText: 'Save A&ll'; ChineseText: '全部保存(&L)'),
    (EnglishText: 'Open Containing &Folder'; ChineseText: '打开所在文件夹(&F)'),
    (EnglishText: '&Close'; ChineseText: '关闭(&C)'),
    (EnglishText: 'Close &All'; ChineseText: '全部关闭(&A)'),
    (EnglishText: 'E&xit'; ChineseText: '退出(&X)'),
    (EnglishText: '&Undo'; ChineseText: '撤销(&U)'),
    (EnglishText: '&Redo'; ChineseText: '重做(&R)'),
    (EnglishText: 'Cu&t'; ChineseText: '剪切(&T)'),
    (EnglishText: '&Copy'; ChineseText: '复制(&C)'),
    (EnglishText: '&Paste'; ChineseText: '粘贴(&P)'),
    (EnglishText: 'Select &All'; ChineseText: '全选(&A)'),
    (EnglishText: '&Comment'; ChineseText: '注释(&C)'),
    (EnglishText: '&Uncomment'; ChineseText: '取消注释(&U)'),
    (EnglishText: '&Toggle Comment'; ChineseText: '切换注释(&T)'),
    (EnglishText: 'Toggle &Inline Comment'; ChineseText: '切换块注释(&I)'),
    (EnglishText: '&Delete Line'; ChineseText: '删除当前行(&D)'),
    (EnglishText: 'D&uplicate Line'; ChineseText: '复制当前行(&U)'),
    (EnglishText: 'Code &Completion'; ChineseText: '代码补全(&C)'),
    (EnglishText: '&Find...'; ChineseText: '查找(&F)...'),
    (EnglishText: 'Find &All...'; ChineseText: '查找全部(&A)...'),
    (EnglishText: 'Find &Next'; ChineseText: '查找下一个(&N)'),
    (EnglishText: 'Find &Previous'; ChineseText: '查找上一个(&P)'),
    (EnglishText: '&Replace...'; ChineseText: '替换(&R)...'),
    (EnglishText: 'Replace &All...'; ChineseText: '全部替换(&A)...'),
    (EnglishText: '&Go to line...'; ChineseText: '跳转到行(&G)...'),
    (EnglishText: '&Project Manager'; ChineseText: '项目管理器(&P)'),
    (EnglishText: '&Next Tab'; ChineseText: '下一个标签页(&N)'),
    (EnglishText: '&Previous Tab'; ChineseText: '上一个标签页(&P)'),
    (EnglishText: 'Swap &Header/Source'; ChineseText: '切换头文件与源文件(&H)'),
    (EnglishText: '&New project...'; ChineseText: '新建项目(&N)...'),
    (EnglishText: '&Open project...'; ChineseText: '打开项目(&O)...'),
    (EnglishText: '&Add file to project...'; ChineseText: '添加文件到项目(&A)...'),
    (EnglishText: '&Remove file from project...'; ChineseText: '从项目移除文件(&R)...'),
    (EnglishText: 'Project &Options...'; ChineseText: '项目选项(&O)...'),
    (EnglishText: '&Compile'; ChineseText: '编译(&C)'),
    (EnglishText: '&Run'; ChineseText: '运行(&R)'),
    (EnglishText: 'Compile && Run'; ChineseText: '编译运行'),
    (EnglishText: 'R&ebuild All'; ChineseText: '全部重新编译(&E)'),
    (EnglishText: '&Abort Compilation'; ChineseText: '中止编译(&A)'),
    (EnglishText: '&Syntax Check'; ChineseText: '语法检查(&S)'),
    (EnglishText: 'Compiler &Parameters...'; ChineseText: '编译参数(&P)...'),
    (EnglishText: '&Compiler Options / Parameters...'; ChineseText: '编译器选项 / 参数(&C)...'),
    (EnglishText: 'E&ditor Options...'; ChineseText: '编辑器选项(&D)...'),
    (EnglishText: '&About Dev-C++'; ChineseText: '关于 Dev-C++(&A)'),
    (EnglishText: 'New Source File'; ChineseText: '新建源代码'),
    (EnglishText: 'Open'; ChineseText: '打开'),
    (EnglishText: 'Save'; ChineseText: '保存'),
    (EnglishText: 'Save All'; ChineseText: '全部保存'),
    (EnglishText: 'Close'; ChineseText: '关闭'),
    (EnglishText: 'Undo'; ChineseText: '撤销'),
    (EnglishText: 'Redo'; ChineseText: '重做'),
    (EnglishText: 'Find'; ChineseText: '查找'),
    (EnglishText: 'Compile'; ChineseText: '编译'),
    (EnglishText: 'Run'; ChineseText: '运行'),
    (EnglishText: 'Compile & Run'; ChineseText: '编译并运行'),
    (EnglishText: 'Rebuild All'; ChineseText: '全部重新编译'),
    (EnglishText: 'Project'; ChineseText: '项目'),
    (EnglishText: 'Classes'; ChineseText: '类'),
    (EnglishText: 'Debug'; ChineseText: '调试'),
    (EnglishText: 'Compiler'; ChineseText: '编译器'),
    (EnglishText: 'Compile log'; ChineseText: '编译日志'),
    (EnglishText: 'Line'; ChineseText: '行'),
    (EnglishText: 'Col'; ChineseText: '列'),
    (EnglishText: 'Unit'; ChineseText: '文件'),
    (EnglishText: 'Message'; ChineseText: '信息'),
    (EnglishText: 'Ready'; ChineseText: '就绪'),
    (EnglishText: 'Find results'; ChineseText: '查找结果'),
    (EnglishText: 'Find All'; ChineseText: '查找全部'),
    (EnglishText: 'Find:'; ChineseText: '查找：'),
    (EnglishText: 'Replace'; ChineseText: '替换'),
    (EnglishText: 'Replace with:'; ChineseText: '替换为：'),
    (EnglishText: 'Go to line'; ChineseText: '跳转到行'),
    (EnglishText: 'Line number:'; ChineseText: '行号：'),
    (EnglishText: 'Project Options'; ChineseText: '项目选项'),
    (EnglishText: 'Additional C flags:'; ChineseText: '附加 C 编译参数：'),
    (EnglishText: 'Additional C++ flags:'; ChineseText: '附加 C++ 编译参数：'),
    (EnglishText: 'Additional linker flags:'; ChineseText: '附加链接参数：'),
    (EnglishText: 'Compiler Options'; ChineseText: '编译器选项'),
    (EnglishText: 'C compiler:'; ChineseText: 'C 编译器：'),
    (EnglishText: 'C++ compiler:'; ChineseText: 'C++ 编译器：'),
    (EnglishText: 'C compile flags:'; ChineseText: 'C 编译参数：'),
    (EnglishText: 'C++ flags (e.g. -std=c++14):'; ChineseText: 'C++ 参数（如 -std=c++14）：'),
    (EnglishText: 'Linux linker flags:'; ChineseText: 'Linux 链接参数：'),
    (EnglishText: 'OK'; ChineseText: '确定'),
    (EnglishText: 'Cancel'; ChineseText: '取消'),
    (EnglishText: 'Yes'; ChineseText: '是'),
    (EnglishText: 'No'; ChineseText: '否'),
    (EnglishText: 'Information'; ChineseText: '提示'),
    (EnglishText: 'Confirmation'; ChineseText: '确认'),
    (EnglishText: 'Warning'; ChineseText: '警告'),
    (EnglishText: 'Error'; ChineseText: '错误'),
    (EnglishText: 'Editor Options'; ChineseText: '编辑器选项'),
    (EnglishText: 'Font size (1-72):'; ChineseText: '字号（1–72）：'),
    (EnglishText: 'Tab width (1-16):'; ChineseText: '制表符宽度（1–16）：'),
    (EnglishText: 'Compiler command cannot be empty.'; ChineseText: '编译器命令不能为空。'),
    (EnglishText: 'Enter a valid font size and tab width.'; ChineseText: '请输入有效的字号和制表符宽度。'),
    (EnglishText: 'Choose a new project file name.'; ChineseText: '请选择新的项目文件名。'),
    (EnglishText: 'Open or create a project first.'; ChineseText: '请先打开或创建项目。'),
    (EnglishText: 'Only console projects are currently supported.'; ChineseText: '目前仅支持控制台项目。'),
    (EnglishText: 'Project has no C/C++ sources.'; ChineseText: '项目中没有 C/C++ 源文件。'),
    (EnglishText: 'Open a C/C++ source file to compile.'; ChineseText: '请打开 C/C++ 源文件后编译。'),
    (EnglishText: 'Compile the program first.'; ChineseText: '请先编译程序。'),
    (EnglishText: 'Missing console-pauser.sh beside the application.'; ChineseText: '程序所在文件夹缺少 console-pauser.sh。'),
    (EnglishText: 'Compiling...'; ChineseText: '正在编译...'),
    (EnglishText: 'Compilation aborted'; ChineseText: '编译已中止'),
    (EnglishText: 'Compilation aborted.'; ChineseText: '编译已中止。'),
    (EnglishText: 'Compilation successful'; ChineseText: '编译成功'),
    (EnglishText: 'Compilation successful.'; ChineseText: '编译成功。'),
    (EnglishText: 'Compilation failed'; ChineseText: '编译失败'),
    (EnglishText: 'The --stack linker option is for Windows. Remove it in Execute > Compiler Parameters.'; ChineseText: '--stack 链接参数用于 Windows。请在“运行 > 编译参数”中移除。'),
    (EnglishText: 'Dev-C++ project|*.dev'; ChineseText: 'Dev-C++ 项目|*.dev'),
    (EnglishText: 'C/C++ files|*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|All files|*'; ChineseText: 'C/C++ 文件|*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|所有文件|*'),
    (EnglishText: 'Dev-C++ project or C/C++ file|*.dev;*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|All files|*'; ChineseText: 'Dev-C++ 项目或 C/C++ 文件|*.dev;*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|所有文件|*'),
    (EnglishText: 'C/C++ source|*.cpp;*.c;*.h;*.hpp|All files|*'; ChineseText: 'C/C++ 源文件|*.cpp;*.c;*.h;*.hpp|所有文件|*'),
    (EnglishText: 'File not found: %s'; ChineseText: '找不到文件：%s'),
    (EnglishText: 'Project not found: %s'; ChineseText: '找不到项目：%s'),
    (EnglishText: 'Save changes to %s?'; ChineseText: '是否保存对 %s 的修改？'),
    (EnglishText: 'Remove %s from project?'; ChineseText: '是否从项目中移除 %s？'),
    (EnglishText: 'Text not found: %s'; ChineseText: '未找到文本：%s'),
    (EnglishText: '%d matches for %s'; ChineseText: '找到 %d 处匹配：%s'),
    (EnglishText: '%s    Line: %d  Col: %d'; ChineseText: '%s    行：%d  列：%d'),
    (EnglishText: 'Compile failed: %s'; ChineseText: '编译失败：%s'),
    (EnglishText: 'Run failed: %s'; ChineseText: '运行失败：%s'),
    (EnglishText: 'Compilation failed (exit %d).'; ChineseText: '编译失败（退出码 %d）。'),
    (EnglishText: 'Dev-C++ 5.11 - NOI Linux native prototype'; ChineseText: 'Dev-C++ 5.11 - NOI Linux 原生移植版'),
    (EnglishText: 'Based on Orwell Dev-C++ 5.11. GPL-2.0-or-later.'; ChineseText: '基于 Orwell Dev-C++ 5.11，采用 GPL-2.0-or-later 许可证。'),
    (EnglishText: 'Abort'; ChineseText: '中止'),
    (EnglishText: 'Retry'; ChineseText: '重试'),
    (EnglishText: 'Ignore'; ChineseText: '忽略'),
    (EnglishText: 'All'; ChineseText: '全部'),
    (EnglishText: 'No to All'; ChineseText: '全部否'),
    (EnglishText: 'Yes to All'; ChineseText: '全部是'),
    (EnglishText: 'Help'; ChineseText: '帮助'),
    (EnglishText: '&Language'; ChineseText: '语言(&L)'),
    (EnglishText: 'Chinese'; ChineseText: '中文'),
    (EnglishText: 'English'; ChineseText: '英语'),
    (EnglishText: 'function'; ChineseText: '函数'),
    (EnglishText: 'type'; ChineseText: '类型'),
    (EnglishText: 'variable'; ChineseText: '变量'),
    (EnglishText: 'symbol'; ChineseText: '符号'),
    (EnglishText: 'keyword'; ChineseText: '关键字'),
    (EnglishText: 'File %s already exists. Overwrite?'; ChineseText: '文件 %s 已存在，是否覆盖？')
  );

  DeletedEnglish: string = '%s was deleted outside Dev-C++.' + LineEnding +
    'Keep the file in the editor?';
  DeletedChinese: string = '%s 已在 Dev-C++ 外部被删除。' + LineEnding +
    '是否在编辑器中保留文件？';
  ReplaceEnglish: string = 'Replace all occurrences?' + LineEnding +
    'Yes: replace all    No: replace next';
  ReplaceChinese: string = '是否替换全部匹配？' + LineEnding +
    '是：替换全部    否：替换下一个';

function TranslateChinese(const EnglishText: string): string;
var
  TranslationIndex: Integer;
begin
  Result := EnglishText;
  for TranslationIndex := Low(Translations) to High(Translations) do
    if EnglishText = Translations[TranslationIndex].EnglishText then
      Exit(Translations[TranslationIndex].ChineseText);
  if EnglishText = DeletedEnglish then Result := DeletedChinese
  else if EnglishText = ReplaceEnglish then Result := ReplaceChinese;
end;

function TranslateEnglish(const ChineseText: string): string;
var
  TranslationIndex: Integer;
begin
  Result := ChineseText;
  for TranslationIndex := Low(Translations) to High(Translations) do
    if ChineseText = Translations[TranslationIndex].ChineseText then
      Exit(Translations[TranslationIndex].EnglishText);
  if ChineseText = DeletedChinese then Result := DeletedEnglish
  else if ChineseText = ReplaceChinese then Result := ReplaceEnglish;
end;

end.
