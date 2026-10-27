program editor_themes_test;

{$mode objfpc}{$H+}

uses Interfaces, Forms, Classes, SysUtils, Graphics, SynEdit, SynEditHighlighter,
  SynHighlighterCpp, SynGutterLineNumber, editor_themes, mainform;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure CheckLiteral(Syntax: TNoiCppSyn; const Text: string;
  Expected: TSynHighlighterAttributes);
var Count: Integer;
begin
  Syntax.ResetRange;
  Syntax.SetLine(Text, 0);
  Count := 0;
  while not Syntax.GetEol do
  begin
    Check(Syntax.GetTokenAttribute = Expected,
      'literal ' + Text + ' token ' + Syntax.GetToken + ' has the wrong attribute');
    Inc(Count);
    Syntax.Next;
  end;
  Check(Count > 0, 'literal test must observe real lexer tokens');
end;

var
  Form: TForm;
  Editor: TSynEdit;
  Syntax: TNoiCppSyn;
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
    Syntax := TNoiCppSyn.Create(Form);
    Editor.Highlighter := Syntax;
    Editor.Lines.Text := 'int main() { return 42; }';
    for I := 0 to EditorThemeCount - 1 do
    begin
      ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr,
        EditorThemeName(I), Colors, Syntax.FloatAttri, Syntax.HexAttri, Syntax.OctalAttri);
      Check(EditorThemeIndex(EditorThemeName(I)) = I, 'theme names must round-trip');
      Check((Editor.SelectedColor.Background <> Editor.Color) or
        ((Editor.SelectedColor.Foreground <> clNone) and
         (Editor.SelectedColor.Foreground <> Syntax.IdentifierAttri.Foreground)),
        'selection must remain visible');
      Check(Editor.BracketMatchColor.Background <> Editor.Color, 'matched brackets must remain visible');
      Check(Editor.LineHighlightColor.Background <> Editor.Color, 'current line must remain visible');
      Check(Colors.ErrorForeground <> Colors.ErrorBackground, 'error line needs readable foreground');
      Check(BracketAttr.Style = [], 'brackets must not acquire extra bold or italic style');
      Check(not (fsBold in Editor.BracketMatchColor.Style), 'matched brackets must not acquire bold style');
      Check(Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0].MarkupInfo.Foreground <>
        Editor.Gutter.Color, 'line numbers must remain visible');
      Check(Editor.Gutter.SeparatorPart.Width >= 21,
        'leave the original Dev-Cpp gap between line numbers and source');
      Check(Editor.Gutter.SeparatorPart.MarkupInfo.Background = Editor.Gutter.Color,
        'gutter spacing follows the selected theme');
    end;
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Classic Plus', Colors, Syntax.FloatAttri, Syntax.HexAttri, Syntax.OctalAttri);
    Check(Syntax.NumberAttri.Foreground = clPurple, 'Classic Plus numbers retain original purple');
    CheckLiteral(Syntax, '1e5', Syntax.FloatAttri);
    CheckLiteral(Syntax, '1E+5', Syntax.FloatAttri);
    CheckLiteral(Syntax, '1e-5', Syntax.FloatAttri);
    CheckLiteral(Syntax, '1e-5f', Syntax.FloatAttri);
    CheckLiteral(Syntax, '1.25e+10L', Syntax.FloatAttri);
    CheckLiteral(Syntax, '.5e2', Syntax.FloatAttri);
    CheckLiteral(Syntax, '0x1.fp+2', Syntax.FloatAttri);
    CheckLiteral(Syntax, '0x1e5ULL', Syntax.HexAttri);
    CheckLiteral(Syntax, '0b1010ull', Syntax.NumberAttri);
    CheckLiteral(Syntax, '123abc', Syntax.IdentifierAttri);
    CheckLiteral(Syntax, '1e', Syntax.IdentifierAttri);
    CheckLiteral(Syntax, 'name1e5', Syntax.IdentifierAttri);
    Check(Editor.Color = clWhite, 'Classic Plus background');
    Check(Syntax.CommentAttri.Foreground = $00D77800, 'Classic Plus Windows comment blue');
    Check(Syntax.StringAttri.Style = [fsBold], 'Classic Plus strings retain original style');
    Check(Syntax.SymbolAttri.Style = [fsBold], 'Classic Plus non-bracket symbols retain original style');
    Check(Editor.Gutter.Color = $00F0F0F0, 'Classic Plus Windows gutter');
    Check((Colors.ErrorForeground = clWhite) and (Colors.ErrorBackground = clMaroon),
      'Classic Plus error line');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Twilight', Colors, Syntax.FloatAttri, Syntax.HexAttri, Syntax.OctalAttri);
    Check((Editor.Color = clBlack) and (Syntax.IdentifierAttri.Foreground = clWhite), 'Twilight text');
    Check((Syntax.KeyAttri.Style = []) and (Syntax.StringAttri.Style = []),
      'switching from Classic Plus must clear bold styles');
    Check(CharacterAttr.Foreground = clYellow, 'Twilight character literals');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Obsidian', Colors, Syntax.FloatAttri, Syntax.HexAttri, Syntax.OctalAttri);
    Check(Editor.Color = $00343129, 'Obsidian removes Windows palette flags');
    Check(Syntax.IdentifierAttri.Foreground = $00E4E2E0, 'Obsidian identifier color');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Visual Studio', Colors, Syntax.FloatAttri, Syntax.HexAttri, Syntax.OctalAttri);
    Check((Editor.Color = clWhite) and (Syntax.CommentAttri.Foreground = clGreen), 'Visual Studio text');
    Check(Editor.Gutter.Color = clWhite, 'Visual Studio gutter must reset dark theme');
    Check(EditorThemeCount = 11, 'all original 5.11 themes are available');
    ApplyEditorTheme(Editor, Syntax, BracketAttr, CharacterAttr, 'Matrix', Colors,
      Syntax.FloatAttri, Syntax.HexAttri, Syntax.OctalAttri);
    CheckLiteral(Syntax, '123', Syntax.NumberAttri);
    CheckLiteral(Syntax, '1e5', Syntax.FloatAttri);
    CheckLiteral(Syntax, '0x1e5', Syntax.HexAttri);
    CheckLiteral(Syntax, '077', Syntax.OctalAttri);
    Check(Syntax.NumberAttri.Foreground = clBlue, 'Matrix decimal numbers');
    Check(Syntax.FloatAttri.Foreground = clFuchsia, 'Matrix floats have their own attribute');
    Check(EditorThemeIndex('unknown theme') = 0, 'missing theme should fall back to Classic Plus');
    Check(DefaultEditorFontName <> '', 'Linux font fallback must have a name');
    if Screen.Fonts.IndexOf('Consolas') >= 0 then
      Check(DefaultEditorFontName = 'Consolas', 'installed Consolas is preferred')
    else
      Check(ResolveEditorFontName('Consolas') <> 'Consolas',
        'missing Consolas uses an explicit monospace fallback');
    Check(ResolveEditorFontName('') = DefaultEditorFontName,
      'an empty font preference uses the default');
    Check(ResolveEditorFontName('Liberation Mono') = 'Liberation Mono',
      'an explicit different font preference is retained');
    Editor.Font.Name := ResolveEditorFontName('Consolas');
    Editor.Font.Size := 12;
    Form.Show;
    Application.ProcessMessages;
    Editor.Canvas.Font.Assign(Editor.Font);
    Check(Editor.Canvas.TextWidth('iiiiiiii') = Editor.Canvas.TextWidth('WWWWWWWW'),
      'Consolas or its fallback must render equal-width ASCII glyphs');
    WriteLn('editor themes: all checks passed');
  finally
    CharacterAttr.Free;
    BracketAttr.Free;
    Form.Free;
  end;
end.
