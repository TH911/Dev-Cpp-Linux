unit editor_themes;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Graphics, Forms, SynEdit, SynEditHighlighter,
  SynHighlighterCpp, SynGutterLineNumber, SynGutterChanges;

const EditorThemeCount = 4;

type
  TEditorThemeColors = record
    ErrorForeground, ErrorBackground: TColor;
  end;

function EditorThemeName(Index: Integer): string;
function EditorThemeIndex(const Name: string): Integer;
function DefaultEditorFontName: string;
procedure ApplyEditorTheme(Editor: TSynEdit; Syntax: TSynCppSyn;
  BracketAttr, CharacterAttr: TSynHighlighterAttributes; const ThemeName: string;
  out Colors: TEditorThemeColors);

implementation

const
  { Original Orwell 5.11 Source/DefaultFiles.rc attribute tables (1..22).
    Keep Win32 system colors stable when GTK uses a different desktop palette. }
  ThemeNames: array[0..EditorThemeCount - 1] of string =
    ('Classic Plus', 'Twilight', 'Visual Studio', 'Obsidian');
  ThemeData: array[0..EditorThemeCount - 1, 1..22] of string = (
    (
      'clBlue, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clHighlight, clNone, 0, 1, 0',
      'clPurple, clNone, 0, 0, 0',
      'clPurple, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clPurple, clNone, 0, 0, 0',
      'clPurple, clNone, 0, 0, 0',
      'clGreen, clNone, 0, 0, 0',
      'clBlack, clNone, 1, 0, 0',
      'clBlack, clWhite, 0, 0, 0',
      'clBlue, clNone, 1, 0, 0',
      'clRed, clNone, 1, 0, 0',
      'clHighlight, clWhite, 0, 0, 0',
      'clWhite, clMaroon, 0, 0, 0',
      'clWhite, clRed',
      'clWhite, clMaroon',
      'clWhite, clBlue',
      'clBlack, clBtnFace',
      'clWhite, clNavy',
      'clBlack, clBtnFace'
    ),
    (
      'clLime, clNone, 0, 0, 0',
      'clYellow, clNone, 0, 0, 0',
      'clSilver, clNone, 0, 1, 0',
      'clFuchsia, clNone, 0, 0, 0',
      'clFuchsia, clNone, 0, 0, 0',
      'clWhite, clNone, 0, 0, 0',
      'clYellow, clMaroon, 0, 0, 0',
      'clFuchsia, clNone, 0, 0, 0',
      'clFuchsia, clNone, 0, 0, 0',
      'clGreen, clNone, 0, 0, 0',
      'clAqua, clNone, 0, 0, 0',
      'clWhite, clBlack, 0, 0, 0',
      'clYellow, clNone, 0, 0, 0',
      'clAqua, clNone, 0, 0, 0',
      'clWhite, clRed, 0, 0, 0',
      'clWhite, clMaroon, 0, 0, 0',
      'clWhite, clRed',
      'clWhite, clMaroon',
      'clWhite, clBlue',
      'clWhite, clBlack',
      'clWhite, clNavy',
      'clWhite, clBtnFace'
    ),
    (
      'clBlack, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clGreen, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clRed, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clBlue, clNone, 0, 0, 0',
      'clBlue, clNone, 0, 0, 0',
      'clNone, clWhite, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clBlack, clNone, 0, 0, 0',
      'clGreen, clNone, 0, 0, 0',
      'clRed, clNone, 0, 0, 0',
      'clWhite, clRed',
      'clRed, clNone',
      'clWhite, clBlue',
      'clNone, clWhite',
      'clWhite, clNavy',
      'clNone, clBtnFace'
    ),
    (
      '$0063c793, clNone, 0, 0, 0',
      '$000984ff, clNone, 0, 0, 0',
      '$007b7466, clNone, 0, 1, 0',
      '$0022cdff, clNone, 0, 0, 0',
      '$0022cdff, clNone, 0, 0, 0',
      '$00e4e2e0, clNone, 0, 0, 0',
      '$000000fb, clNone, 0, 0, 0',
      '$0022cdff, clNone, 0, 0, 0',
      '$0022cdff, clNone, 0, 0, 0',
      '$00bd82a0, clNone, 0, 0, 0',
      '$00b18c67, clNone, 0, 0, 0',
      'clNone, $02343129, 0, 0, 0',
      '$000076ec, clNone, 0, 0, 0',
      '$00b7e2e8, clNone, 0, 0, 0',
      'clHighlight, clWhite, 0, 0, 0',
      'clWhite, clMaroon, 0, 0, 0',
      '16777215, $0000cc99',
      '16777215, $001212d5',
      '16777215, $00ffcc00',
      '$0088806a, $003c382f',
      '16777215, $00514e40',
      '$000000c0, $00514e40'
    )
  );

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
  Result := 0;
end;

function DefaultEditorFontName: string;
const Candidates: array[0..2] of string =
  ('DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono');
var I: Integer;
begin
  for I := Low(Candidates) to High(Candidates) do
    if Screen.Fonts.IndexOf(Candidates[I]) >= 0 then Exit(Candidates[I]);
  Result := 'Monospace';
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
  out Colors: TEditorThemeColors);
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
    Attr[4] := nil;
    Attr[5] := nil;
    Attr[6] := Syntax.IdentifierAttri;
    Attr[7] := Syntax.InvalidAttri;
    Attr[8] := Syntax.NumberAttri;
    Attr[9] := nil;
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
    if Theme in [1, 3] then Editor.LineHighlightColor.Background := $00423E36
    else Editor.LineHighlightColor.Background := $00FFFFCC;
    Editor.LineHighlightColor.Style := [];
    Editor.LineHighlightColor.StyleMask := [];
    Editor.Gutter.Color := Background[20];
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
    if Colors.ErrorForeground = clNone then Colors.ErrorForeground := clRed;
    if Colors.ErrorBackground = clNone then Colors.ErrorBackground := Editor.Color;
    Editor.Invalidate;
  finally Editor.EndUpdate; end;
end;

end.
