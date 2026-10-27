unit editor_themes;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Graphics, Forms, SynEdit, SynEditHighlighter,
  SynHighlighterCpp, SynGutterLineNumber, SynGutterChanges, SynGutter;

const EditorThemeCount = 11;

type
  TEditorThemeColors = record
    ErrorForeground, ErrorBackground: TColor;
    BreakpointForeground, BreakpointBackground, DebugForeground, DebugBackground: TColor;
  end;

function EditorThemeName(Index: Integer): string;
function EditorThemeIndex(const Name: string): Integer;
function DefaultEditorFontName: string;
function ResolveEditorFontName(const RequestedName: string): string;
procedure ApplyEditorTheme(Editor: TSynEdit; Syntax: TSynCppSyn;
  BracketAttr, CharacterAttr: TSynHighlighterAttributes; const ThemeName: string;
  out Colors: TEditorThemeColors; FloatAttr: TSynHighlighterAttributes = nil;
  HexAttr: TSynHighlighterAttributes = nil; OctalAttr: TSynHighlighterAttributes = nil);

implementation

const
  {$I editor_theme_data.inc}

function EditorThemeName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= EditorThemeCount) then Index := 0;
  Result := ThemeNames[Index];
end;

function EditorThemeIndex(const Name: string): Integer;
var I: Integer;
begin
  for I := 0 to EditorThemeCount - 1 do
    if SameText(ThemeNames[I], Name) then Exit(I);
  if SameText(Name, 'Obisidian') then Exit(3);
  if SameText(Name, 'Obvilion') then Exit(9);
  Result := 0;
end;

function DefaultEditorFontName: string;
const Candidates: array[0..3] of string =
  ('Consolas', 'DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono');
var I: Integer;
begin
  for I := Low(Candidates) to High(Candidates) do
    if Screen.Fonts.IndexOf(Candidates[I]) >= 0 then Exit(Candidates[I]);
  Result := 'Monospace';
end;

function ResolveEditorFontName(const RequestedName: string): string;
begin
  Result := Trim(RequestedName);
  { Retain the saved preference so a later font installation takes effect.
    GTK's substitution for missing Consolas need not be monospaced. }
  if (Result = '') or
    (SameText(Result, 'Consolas') and (Screen.Fonts.IndexOf('Consolas') < 0)) then
    Result := DefaultEditorFontName;
end;

function ThemeColor(const Value: string): TColor;
begin
  if SameText(Trim(Value), 'clHighlight') then Exit($00D77800);
  if SameText(Trim(Value), 'clBtnFace') then Exit($00F0F0F0);
  try
    Result := StringToColor(Trim(Value));
    { The original tables contain Win32 palette flags, irrelevant on Linux. }
    if (Result >= 0) and (Result <> clNone) and (Result <> clDefault) then
      Result := Result and $00FFFFFF;
  except
    Result := clNone;
  end;
end;

procedure ApplyEditorTheme(Editor: TSynEdit; Syntax: TSynCppSyn;
  BracketAttr, CharacterAttr: TSynHighlighterAttributes; const ThemeName: string;
  out Colors: TEditorThemeColors; FloatAttr, HexAttr, OctalAttr: TSynHighlighterAttributes);
var
  Theme, I: Integer;
  Parts: TStringList;
  Attr: array[1..14] of TSynHighlighterAttributes;
  Foreground, Background: array[1..22] of TColor;
  Styles: array[1..22] of TFontStyles;
begin
  Theme := EditorThemeIndex(ThemeName);
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    for I := 1 to 22 do
    begin
      Parts.DelimitedText := ThemeData[Theme, I];
      Foreground[I] := ThemeColor(Parts[0]);
      Background[I] := ThemeColor(Parts[1]);
      Styles[I] := [];
      if Parts.Count >= 5 then
      begin
        if Trim(Parts[2]) = '1' then Include(Styles[I], fsBold);
        if Trim(Parts[3]) = '1' then Include(Styles[I], fsItalic);
        if Trim(Parts[4]) = '1' then Include(Styles[I], fsUnderline);
      end;
    end;
  finally Parts.Free; end;
  Editor.BeginUpdate;
  try
    Editor.Color := Background[12];
    if Foreground[12] = clNone then Editor.Font.Color := clBlack
    else Editor.Font.Color := Foreground[12];
    Attr[1] := Syntax.AsmAttri;
    Attr[2] := CharacterAttr;
    Attr[3] := Syntax.CommentAttri;
    Attr[4] := FloatAttr;
    Attr[5] := HexAttr;
    Attr[6] := Syntax.IdentifierAttri;
    Attr[7] := Syntax.InvalidAttri;
    Attr[8] := Syntax.NumberAttri;
    Attr[9] := OctalAttr;
    Attr[10] := Syntax.DirecAttri;
    Attr[11] := Syntax.KeyAttri;
    Attr[12] := Syntax.SpaceAttri;
    Attr[13] := Syntax.StringAttri;
    Attr[14] := Syntax.SymbolAttri;
    for I := 1 to 14 do
      if Attr[I] <> nil then
      begin
        Attr[I].Foreground := Foreground[I];
        Attr[I].Background := Background[I];
        Attr[I].Style := Styles[I];
      end;
    if BracketAttr <> nil then
    begin
      BracketAttr.Foreground := Foreground[14];
      BracketAttr.Background := Background[14];
      BracketAttr.Style := [];
    end;
    Editor.SelectedColor.Foreground := Foreground[21];
    Editor.SelectedColor.Background := Background[21];
    Editor.SelectedColor.Style := [];
    Editor.SelectedColor.StyleMask := [];
    Editor.BracketMatchColor.Foreground := clWhite;
    Editor.BracketMatchColor.Background := clRed;
    Editor.BracketMatchColor.Style := [];
    Editor.BracketMatchColor.StyleMask := [fsBold, fsItalic, fsUnderline];
    Editor.LineHighlightColor.Foreground := clNone;
    if ((Editor.Color and $FF) + ((Editor.Color shr 8) and $FF) +
      ((Editor.Color shr 16) and $FF)) < 384 then
      Editor.LineHighlightColor.Background := $00423E36
    else Editor.LineHighlightColor.Background := $00FFFFCC;
    Editor.LineHighlightColor.Style := [];
    Editor.LineHighlightColor.StyleMask := [];
    Editor.Gutter.Color := Background[20];
    { Orwell 5.11 devCFG.pas: LeftOffset=4, RightOffset=21,
      BorderStyle=gbsNone. Lazarus splits the gutter into independent parts. }
    Editor.Gutter.LeftOffset := 4;
    if Editor.Gutter.SeparatorPart <> nil then
      with Editor.Gutter.SeparatorPart do
      begin
        AutoSize := False;
        Width := 21;
        LineWidth := 0;
        MarkupInfo.Background := Editor.Gutter.Color;
      end;
    if Editor.Gutter.CodeFoldPart <> nil then
    begin
      Editor.Gutter.CodeFoldPart.MarkupInfo.Foreground := Foreground[22];
      Editor.Gutter.CodeFoldPart.MarkupInfo.Background := Editor.Gutter.Color;
    end;
    if Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0] = nil then
      TSynGutterLineNumber.Create(Editor.Gutter.Parts);
    Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0].MarkupInfo.Foreground := Foreground[20];
    Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0].MarkupInfo.Background := Background[20];
    if Editor.Gutter.Parts.ByClass[TSynGutterChanges, 0] <> nil then
      Editor.Gutter.Parts.ByClass[TSynGutterChanges, 0].Visible := False;
    Editor.FoldedCodeColor.Foreground := Foreground[20];
    Editor.FoldedCodeColor.Background := Background[20];
    Colors.ErrorForeground := Foreground[18];
    Colors.ErrorBackground := Background[18];
    Colors.BreakpointForeground := Foreground[17];
    Colors.BreakpointBackground := Background[17];
    Colors.DebugForeground := Foreground[19];
    Colors.DebugBackground := Background[19];
    if Colors.ErrorForeground = clNone then Colors.ErrorForeground := clRed;
    if Colors.ErrorBackground = clNone then Colors.ErrorBackground := Editor.Color;
    Editor.Invalidate;
  finally Editor.EndUpdate; end;
end;

end.
