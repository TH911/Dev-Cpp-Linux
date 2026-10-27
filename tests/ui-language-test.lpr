program ui_language_test;

{$mode objfpc}{$H+}{$codepage utf8}

uses Interfaces, Forms, StdCtrls, SysUtils, ui_language, language_catalog;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then begin WriteLn(StdErr, 'FAIL: ', MessageText); Halt(1); end;
end;

var
  Form: TForm;
  LabelControl: TLabel;
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
    Check(ResolveUiLanguage('Chinese_TC.lng') = 'zh_TW', 'original filename migration');
    Check(ResolveUiLanguage('bad-locale') = 'en', 'unknown locale safely falls back');
    WriteLn('PASS: 33 original languages, runtime switching, restart settings and untouched user data');
  finally
    Form.Free;
    DeleteFile(Config);
  end;
end.
