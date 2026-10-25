program editor_themes_test;

{$mode objfpc}{$H+}

uses Interfaces, Forms, Classes, SysUtils, Graphics, SynEdit, SynEditHighlighter,
  SynHighlighterCpp, SynGutterLineNumber, editor_themes;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

var
  Form: TForm;
  Editor: TSynEdit;
  Syntax: TSynCppSyn;
  BracketAttr, CharacterAttr: TSynHighlighterAttributes;
  Colors: TEditorThemeColors;
  I: Integer;
begin
  Application.Initialize;
  Form := TForm.CreateNew(nil);
  BracketAttr := TSynHighlighterAttributes.Create('Bracket', 'Bracket');
  CharacterAttr := TSynHighlighterAttributes.Create('Character', 'Character');
  try
    Editor := TSynEdit.Create(Form);
    Editor.Parent := Form;
    Syntax := TSynCppSyn.Create(Form);
    Editor.Highlighter := Syntax;
    Editor.Lines.Text := 'int main() { return 42; }';
    for I := 0 to EditorThemeCount - 1 do
    begin
      ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr,
        EditorThemeName(I), Colors);
      Check(EditorThemeIndex(EditorThemeName(I)) = I, 'theme names must round-trip');
      Check(Editor.SelectedColor.Background <> Editor.Color, 'selection must remain visible');
      Check(Editor.BracketMatchColor.Background <> Editor.Color, 'matched brackets must remain visible');
      Check(Editor.LineHighlightColor.Background <> Editor.Color, 'current line must remain visible');
      Check(Colors.ErrorForeground <> Colors.ErrorBackground, 'error line needs readable foreground');
      Check(BracketAttr.Style = [], 'brackets must not acquire extra bold or italic style');
      Check(not (fsBold in Editor.BracketMatchColor.Style), 'matched brackets must not acquire bold style');
      Check(Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0].MarkupInfo.Foreground <>
        Editor.Gutter.Color, 'line numbers must remain visible');
    end;
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Classic Plus', Colors);
    Check(Editor.Color = clWhite, 'Classic Plus background');
    Check(Syntax.CommentAttri.Foreground = $00D77800, 'Classic Plus Windows comment blue');
    Check(Syntax.StringAttri.Style = [fsBold], 'Classic Plus strings retain original style');
    Check(Syntax.SymbolAttri.Style = [fsBold], 'Classic Plus non-bracket symbols retain original style');
    Check(Editor.Gutter.Color = $00F0F0F0, 'Classic Plus Windows gutter');
    Check((Colors.ErrorForeground = clWhite) and (Colors.ErrorBackground = clMaroon),
      'Classic Plus error line');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Twilight', Colors);
    Check((Editor.Color = clBlack) and (Syntax.IdentifierAttri.Foreground = clWhite), 'Twilight text');
    Check((Syntax.KeyAttri.Style = []) and (Syntax.StringAttri.Style = []),
      'switching from Classic Plus must clear bold styles');
    Check(CharacterAttr.Foreground = clYellow, 'Twilight character literals');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Obsidian', Colors);
    Check(Editor.Color = $00343129, 'Obsidian removes Windows palette flags');
    Check(Syntax.IdentifierAttri.Foreground = $00E4E2E0, 'Obsidian identifier color');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Visual Studio', Colors);
    Check((Editor.Color = clWhite) and (Syntax.CommentAttri.Foreground = clGreen), 'Visual Studio text');
    Check(Editor.Gutter.Color = clWhite, 'Visual Studio gutter must reset dark theme');
    Check(EditorThemeIndex('unknown theme') = 0, 'missing theme should fall back to Classic Plus');
    Check(DefaultEditorFontName <> '', 'Linux font fallback must have a name');
    WriteLn('editor themes: all checks passed');
  finally
    CharacterAttr.Free;
    BracketAttr.Free;
    Form.Free;
  end;
end.
