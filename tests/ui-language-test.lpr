program ui_language_test;

{$mode objfpc}{$H+}{$codepage utf8}

uses Interfaces, Forms, StdCtrls, SysUtils, ui_language, language_catalog;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then begin WriteLn(StdErr, 'FAIL: ', MessageText); Halt(1); end;
end;

var
  Form: TForm;
  LabelControl, ExecuteRoot, RunAction: TLabel;
  Editor: TEdit;
  I: Integer;
  Config, Expected, Code: string;
begin
  Application.Initialize;
  Config := GetTempFileName(GetTempDir, 'devcpp-lang-');
  Form := TForm.CreateNew(nil);
  try
    InitUiLanguage(Config);
    LabelControl := TLabel.Create(Form);
    LabelControl.Parent := Form;
    LabelControl.Caption := Tr('&File');
    ExecuteRoot:=TLabel.Create(Form);SetUiProperty(ExecuteRoot,'Caption','E&xecute');
    RunAction:=TLabel.Create(Form);SetUiProperty(RunAction,'Caption','&Run');
    Editor := TEdit.Create(Form);
    Editor.Parent := Form;
    Editor.Text := 'user.cpp: int main() { /* 用户内容 */ }';
    Check(UiLanguageCount = 33, 'all original language files are available');
    for I := 0 to UiLanguageCount - 1 do
    begin
      Code := UiLanguageCode(I);
      SetUiLanguage(Code);
      Expected := Tr('&File');
      if Code <> 'en' then
        Check((Expected <> '&File') or (Tr('&Edit') <> '&Edit') or
          (Tr('&Help') <> '&Help'), 'installed upstream catalog actually loaded: ' + Code);
      ApplyUiLanguage(Form);
      Check(ExecuteRoot.Caption=Tr('E&xecute'),'preserve Execute identity across languages');
      Check(RunAction.Caption=Tr('&Run'),'preserve Run identity when the Chinese captions collide');
      Check(LabelControl.Caption = Expected, 'switch caption to ' + Code);
      Check(Editor.Text = 'user.cpp: int main() { /* 用户内容 */ }', 'never translate user data');
      InitUiLanguage(Config);
      Check(CurrentUiLanguage = Code, 'persist and restore ' + Code);
    end;
    SetUiLanguage('fr'); Check(Tr('&File') = '&Fichier', 'French resource decoded');
    SetUiLanguage('de'); Check(Pos('Datei', Tr('&File')) > 0, 'German resource decoded');
    SetUiLanguage('ja'); Check(Tr('&File') <> '&File', 'Japanese resource decoded');
    SetUiLanguage('en'); ApplyUiLanguage(Form);
    Check(LabelControl.Caption = '&File', 'return to English without a stale translation');
    SetUiLanguage('zh'); ApplyUiLanguage(Form);
    Check(Pos('文件', LabelControl.Caption) > 0, 'return to Chinese');
    Check(Tr('Compile & Run') = '编译运行[&o]', 'compile command must not become Compile toolbar');
    Check(Tr('Whole words') = '全字匹配[&W]', 'original search option and W mnemonic');
    Check(Tr('Insert') = '插入', 'status mode must not become a toolbar caption');
    Check(Tr('Project') = '项目管理', 'original sidebar Project caption');
    Check(Tr('Save As') = '保存为', 'original ID_NV_SAVEAS title has no menu mnemonic');
    Check(Tr('Search') = '搜索', 'search dialog must not become Search toolbar');
    Check(Tr('Project Options') = '项目属性[&O]', 'project action must not become a property label');
    Check(Tr('&View') = '视图[&V]', 'original View translation and accelerator');
    Check(Tr('Project Manager') = '项目管理', 'sidebar uses Project, not Go to Project Manager');
    Check(Tr('&Project Manager') = '项目管理[&P]', 'View command retains its original accelerator');
    Check(Tr('&Compiler Options...') = '编译选项[&C]', 'original compiler options wording');
    Check(Tr('En&vironment Options...') = '环境选项[&v]', 'original environment options wording');
    Check(Tr('&Editor Options...') = '编辑器选项[&E]', 'original editor options wording');
    Check(Tr('&Shortcut Options...') = '快捷键选项[&Y]', 'original shortcut options wording');
    Check(ResolveUiLanguage('Chinese_TC.lng') = 'zh_TW', 'original filename migration');
    Check(ResolveUiLanguage('bad-locale') = 'en', 'unknown locale safely falls back');
    WriteLn('PASS: 33 original languages, runtime switching, restart settings and untouched user data');
  finally
    Form.Free;
    DeleteFile(Config);
  end;
end.
