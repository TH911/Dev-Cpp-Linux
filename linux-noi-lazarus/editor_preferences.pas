unit editor_preferences;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, IniFiles, Graphics, SynEdit, SynEditHighlighter, cpp_highlighter, editor_themes;
type
  TEditorFlag = (efAutoIndent, efAddIndent, efInsertMode, efFindAtCursor,
    efGroupUndo, efDropInsert, efSpecialChars, efTrimSpaces, efEnhanceHome,
    efPastEOL, efPastEOF, efScrollOnNeed, efHalfPage, efScrollHint,
    efEditorHints, efFunctionHints, efUseTabs, efSmartTabs, efMatchBrackets,
    efHighlightLine, efSyntax, efCompletion, efGutterVisible, efLineNumbers,
    efGutterAuto, efCustomGutterFont, efZeroStart, efLeadingZeros,
    efRightMargin, efDefaultCode, efAutoSave);
  TEditorFlags = set of TEditorFlag;
  TEditorPreferences = class
  public
    Flags: TEditorFlags;
    GutterFont: string;
    GutterSize, GutterSpacing, MarginWidth, InsertCaret, OverwriteCaret,
      AutoSaveSeconds, AutoSaveScope, AutoSaveNaming, CompletionDelay, PairMask: Integer;
    PairSymbols, DeletePairs, ScanLocalHeaders: Boolean;
    CompletionColor:TColor;
    MarginColor, CurrentLineColor: TColor;
    DefaultCode, SyntaxExtensions: string;
    Colors, Snippets: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TEditorPreferences);
    procedure Load(Ini: TCustomIniFile);
    procedure Save(Ini: TCustomIniFile);
    procedure ApplySpecial(Editor:TSynEdit;var ThemeColors:TEditorThemeColors);
    procedure Apply(Editor: TSynEdit; Syntax: TNoiCppSyn;Code:Boolean=True);
  end;
const
  EditorFlagNames: array[TEditorFlag] of string = ('AutoIndent', 'AddIndent', 'InsertMode',
    'FindAtCursor', 'GroupUndo', 'DropInsert', 'SpecialChars', 'TrimSpaces', 'EnhanceHome',
    'PastEOL', 'PastEOF', 'ScrollOnNeed', 'HalfPage', 'ScrollHint', 'EditorHints',
    'FunctionHints', 'UseTabs', 'SmartTabs', 'MatchBrackets', 'HighlightLine', 'Syntax',
    'Completion', 'GutterVisible', 'LineNumbers', 'GutterAuto', 'CustomGutterFont',
    'ZeroStart', 'LeadingZeros', 'RightMargin', 'DefaultCode', 'AutoSave');
  EditorFlagCaptions: array[TEditorFlag] of string = ('Auto indent', 'Add indent to {} and :',
    'Insert mode', 'Find text at cursor', 'Group undo', 'Insert dropped files',
    'Show special characters', 'Trim trailing spaces', 'Enhance Home key', 'Cursor past EOL',
    'Cursor past EOF', 'Scrollbars as needed', 'Half-page scrolling', 'Show scroll hint',
    'Show editor hints', 'Show function hints', 'Use tab character', 'Smart tabs',
    'Highlight matching symbols', 'Highlight current line', 'Use syntax highlighting',
    'Enable code completion', 'Gutter visible', 'Show line numbers', 'Auto-size gutter',
    'Use custom gutter font', 'Start at zero', 'Show leading zeros', 'Right margin visible',
    'Insert default code in new files', 'Auto-save recovery copies');
implementation
uses base64, Math, StdCtrls, SynEditPointClasses, SynGutterLineNumber, SynGutterBase, classic_gutter;
function DecodeStored(const Value:string):string;
begin
  { FPC 3.0.4 raises EStreamError for an empty base64 stream. Missing or
    malformed preference text must not prevent the editor from starting. }
  if Value='' then Exit('');
  try Result:=DecodeStringBase64(Value); except Result:='';end;
end;
constructor TEditorPreferences.Create;
begin
  inherited Create;
  Flags := [efAutoIndent, efAddIndent, efInsertMode, efGroupUndo, efEnhanceHome,
    efScrollOnNeed, efScrollHint, efEditorHints, efFunctionHints, efUseTabs,
    efMatchBrackets, efHighlightLine, efSyntax, efCompletion, efGutterVisible,
    efLineNumbers, efGutterAuto];
  GutterSize := 14; GutterSpacing := 4; MarginWidth := 80; AutoSaveSeconds := 60;
  AutoSaveScope:=1;AutoSaveNaming:=0;CompletionDelay:=1;PairMask:=111;
  PairSymbols:=True;DeletePairs:=True;ScanLocalHeaders:=True;CompletionColor:=clWhite;
  SyntaxExtensions:='c;cpp;h;hpp;cc;cxx;cp;hp;rh;fx;inl;tcc;win';
  InsertCaret := 0; OverwriteCaret := 1;
  MarginColor := clSilver; CurrentLineColor := clNone;
  Colors := TStringList.Create; Snippets := TStringList.Create;
  Snippets.NameValueSeparator := #1;
  Snippets.Add('main'#1'int main() {'#9'return 0; }');
end;
destructor TEditorPreferences.Destroy;
begin Colors.Free; Snippets.Free; inherited Destroy; end;
procedure TEditorPreferences.Assign(Source: TEditorPreferences);
begin
  AutoSaveScope:=Source.AutoSaveScope;AutoSaveNaming:=Source.AutoSaveNaming;
  CompletionDelay:=Source.CompletionDelay;PairMask:=Source.PairMask;PairSymbols:=Source.PairSymbols;
  DeletePairs:=Source.DeletePairs;ScanLocalHeaders:=Source.ScanLocalHeaders;CompletionColor:=Source.CompletionColor;
  SyntaxExtensions:=Source.SyntaxExtensions;
  Flags := Source.Flags; GutterFont := Source.GutterFont; GutterSize := Source.GutterSize;
  GutterSpacing := Source.GutterSpacing; MarginWidth := Source.MarginWidth;
  InsertCaret := Source.InsertCaret; OverwriteCaret := Source.OverwriteCaret;
  AutoSaveSeconds := Source.AutoSaveSeconds; MarginColor := Source.MarginColor;
  CurrentLineColor := Source.CurrentLineColor; DefaultCode := Source.DefaultCode;
  Colors.Assign(Source.Colors); Snippets.Assign(Source.Snippets);
end;
procedure TEditorPreferences.Load(Ini: TCustomIniFile);
var F: TEditorFlag; I, Count: Integer;
begin
  for F := Low(F) to High(F) do
    if Ini.ReadBool('Editor.Behavior', EditorFlagNames[F], F in Flags) then Include(Flags,F) else Exclude(Flags,F);
  GutterFont := Ini.ReadString('Editor.Display', 'GutterFont', '');
  GutterSize := EnsureRange(Ini.ReadInteger('Editor.Display','GutterSize',14),1,72);
  GutterSpacing := EnsureRange(Ini.ReadInteger('Editor.Display','GutterSpacing',4),0,40);
  MarginWidth := EnsureRange(Ini.ReadInteger('Editor.Display','MarginWidth',80),1,1024);
  MarginColor := Ini.ReadInteger('Editor.Display','MarginColor',clSilver);
  CurrentLineColor := Ini.ReadInteger('Editor.Display','CurrentLineColor',clNone);
  InsertCaret := EnsureRange(Ini.ReadInteger('Editor.Display','InsertCaret',0),0,3);
  OverwriteCaret := EnsureRange(Ini.ReadInteger('Editor.Display','OverwriteCaret',1),0,3);
  AutoSaveSeconds := EnsureRange(Ini.ReadInteger('Editor.Recovery','Seconds',60),10,3600);
  AutoSaveScope:=EnsureRange(Ini.ReadInteger('Editor.Recovery','Scope',1),0,2);
  AutoSaveNaming:=EnsureRange(Ini.ReadInteger('Editor.Recovery','Naming',0),0,2);
  CompletionDelay:=EnsureRange(Ini.ReadInteger('Editor.Completion','Delay',1),1,2000);
  PairMask:=Ini.ReadInteger('Editor.Completion','Pairs',111) and 127;
  PairSymbols:=Ini.ReadBool('Editor.Completion','PairSymbols',True);
  DeletePairs:=Ini.ReadBool('Editor.Completion','DeletePairs',True);
  ScanLocalHeaders:=Ini.ReadBool('Editor.Completion','LocalHeaders',True);
  CompletionColor:=Ini.ReadInteger('Editor.Completion','Background',clWhite);
  SyntaxExtensions:=Ini.ReadString('Editor','SyntaxExtensions',SyntaxExtensions);
  DefaultCode := Ini.ReadString('Editor.Code','Default','');
  if Ini.ReadString('Editor.Code','Encoding','')='base64' then DefaultCode:=DecodeStored(DefaultCode)
  else DefaultCode := StringReplace(DefaultCode, '<LF>', LineEnding, [rfReplaceAll]);
  Ini.ReadSectionValues('Editor.Colors', Colors);
  Count := EnsureRange(Ini.ReadInteger('Editor.Snippets','Count',-1),-1,128);
  if Count >= 0 then begin
    Snippets.Clear;
    for I := 0 to Count-1 do
      Snippets.Add(Ini.ReadString('Editor.Snippets','Name'+IntToStr(I),'Snippet') + #1 +
        DecodeStored(Ini.ReadString('Editor.Snippets','Code'+IntToStr(I),'')));
  end;
end;
procedure TEditorPreferences.Save(Ini: TCustomIniFile);
var F: TEditorFlag; I: Integer;
begin
  for F := Low(F) to High(F) do Ini.WriteBool('Editor.Behavior', EditorFlagNames[F], F in Flags);
  Ini.WriteString('Editor.Display','GutterFont',GutterFont);
  Ini.WriteInteger('Editor.Display','GutterSize',GutterSize);
  Ini.WriteInteger('Editor.Display','GutterSpacing',GutterSpacing);
  Ini.WriteInteger('Editor.Display','MarginWidth',MarginWidth);
  Ini.WriteInteger('Editor.Display','MarginColor',MarginColor);
  Ini.WriteInteger('Editor.Display','CurrentLineColor',CurrentLineColor);
  Ini.WriteInteger('Editor.Display','InsertCaret',InsertCaret);
  Ini.WriteInteger('Editor.Display','OverwriteCaret',OverwriteCaret);
  Ini.WriteInteger('Editor.Recovery','Seconds',AutoSaveSeconds);
  Ini.WriteInteger('Editor.Recovery','Scope',AutoSaveScope);Ini.WriteInteger('Editor.Recovery','Naming',AutoSaveNaming);
  Ini.WriteInteger('Editor.Completion','Delay',CompletionDelay);Ini.WriteInteger('Editor.Completion','Pairs',PairMask);
  Ini.WriteBool('Editor.Completion','PairSymbols',PairSymbols);Ini.WriteBool('Editor.Completion','DeletePairs',DeletePairs);
  Ini.WriteBool('Editor.Completion','LocalHeaders',ScanLocalHeaders);Ini.WriteInteger('Editor.Completion','Background',CompletionColor);
  Ini.WriteString('Editor','SyntaxExtensions',SyntaxExtensions);
  Ini.WriteString('Editor.Code','Encoding','base64');
  Ini.WriteString('Editor.Code','Default',EncodeStringBase64(DefaultCode));
  Ini.EraseSection('Editor.Colors');
  for I := 0 to Colors.Count-1 do Ini.WriteString('Editor.Colors',Colors.Names[I],Colors.ValueFromIndex[I]);
  Ini.EraseSection('Editor.Snippets'); Ini.WriteInteger('Editor.Snippets','Count',Snippets.Count);
  for I := 0 to Snippets.Count-1 do begin
    Ini.WriteString('Editor.Snippets','Name'+IntToStr(I),Snippets.Names[I]);
    Ini.WriteString('Editor.Snippets','Code'+IntToStr(I),EncodeStringBase64(Snippets.ValueFromIndex[I]));
  end;
end;
procedure TEditorPreferences.Apply(Editor: TSynEdit; Syntax: TNoiCppSyn;Code:Boolean);
const Carets: array[0..3] of TSynEditCaretType = (ctVerticalLine, ctBlock, ctHorizontalLine, ctHalfBlock);
var Opt: TSynEditorOptions; Part: TClassicLineNumbers; Old: TSynGutterPartBase;
  I, Bits: Integer; A: TSynHighlighterAttributes; Key: string;
  procedure Option(F: TEditorFlag; Value: TSynEditorOption);
  begin if F in Flags then Include(Opt,Value) else Exclude(Opt,Value); end;
begin
  Opt := Editor.Options;
  Option(efGroupUndo,eoGroupUndo); Option(efSpecialChars,eoShowSpecialChars);
  Option(efTrimSpaces,eoTrimTrailingSpaces); Option(efPastEOL,eoScrollPastEol);
  Option(efPastEOF,eoScrollPastEof); Option(efHalfPage,eoHalfPageScroll);
  Option(efScrollHint,eoShowScrollHint); Option(efSmartTabs,eoSmartTabs);
  if efUseTabs in Flags then Exclude(Opt,eoTabsToSpaces) else Include(Opt,eoTabsToSpaces);
  Editor.Options := Opt;
  Editor.ShowHint:=efEditorHints in Flags;
  Editor.InsertMode := efInsertMode in Flags;
  Editor.InsertCaret := Carets[InsertCaret]; Editor.OverwriteCaret := Carets[OverwriteCaret];
  if efScrollOnNeed in Flags then Editor.ScrollBars := ssAutoBoth else Editor.ScrollBars := ssBoth;
  if efRightMargin in Flags then Editor.RightEdge := MarginWidth else Editor.RightEdge := 0;
  Editor.RightEdgeColor := MarginColor;
  if not (efHighlightLine in Flags) then Editor.LineHighlightColor.Background := clNone
  else if CurrentLineColor <> clNone then Editor.LineHighlightColor.Background := CurrentLineColor;
  if not (efMatchBrackets in Flags) then begin
    Editor.BracketMatchColor.Foreground := clNone; Editor.BracketMatchColor.Background := clNone;
  end;
  Editor.Gutter.Visible := efGutterVisible in Flags; Editor.Gutter.LeftOffset := GutterSpacing;
  Old := Editor.Gutter.Parts.ByClass[TSynGutterLineNumber,0];
  if not (Old is TClassicLineNumbers) then begin
    Part := TClassicLineNumbers.Create(Editor.Gutter.Parts);
    if Old <> nil then begin Part.Assign(Old); Part.Index := Old.Index; Old.Free; end;
  end else Part := TClassicLineNumbers(Old);
  Part.CustomFont := efCustomGutterFont in Flags;
  Part.NumberFont.Name := GutterFont; if GutterFont = '' then Part.NumberFont.Name := Editor.Font.Name;
  Part.NumberFont.Size := GutterSize;
  Part.Visible := efLineNumbers in Flags; Part.AutoSize := efGutterAuto in Flags;
  if not Part.AutoSize then Part.Width := Editor.CharWidth * 5;
  Part.ZeroStart := efZeroStart in Flags; Part.LeadingZeros := efLeadingZeros in Flags;
  if Code and (efSyntax in Flags) then Editor.Highlighter := Syntax else Editor.Highlighter := nil;
  for I := 0 to Syntax.AttrCount-1 do begin
    A := Syntax.Attribute[I]; Key := A.Name;
    if Colors.Values[Key+'.Foreground'] <> '' then A.Foreground := StrToIntDef(Colors.Values[Key+'.Foreground'],A.Foreground);
    if Colors.Values[Key+'.Background'] <> '' then A.Background := StrToIntDef(Colors.Values[Key+'.Background'],A.Background);
    if Colors.Values[Key+'.Style'] <> '' then begin
      Bits := StrToIntDef(Colors.Values[Key+'.Style'],0); A.Style := [];
      if Bits and 1 <> 0 then A.Style := A.Style + [fsBold];
      if Bits and 2 <> 0 then A.Style := A.Style + [fsItalic];
      if Bits and 4 <> 0 then A.Style := A.Style + [fsUnderline];
    end;
  end;
end;
procedure TEditorPreferences.ApplySpecial(Editor:TSynEdit;var ThemeColors:TEditorThemeColors);
  procedure ReadColor(const Name:string;var FG,BG:TColor);
  begin
    FG:=StrToIntDef(Self.Colors.Values[Name+'.Foreground'],FG);
    BG:=StrToIntDef(Self.Colors.Values[Name+'.Background'],BG);
  end;
var FG,BG:TColor;
begin
  ReadColor('Breakpoints',ThemeColors.BreakpointForeground,ThemeColors.BreakpointBackground);
  ReadColor('Active breakpoints',ThemeColors.DebugForeground,ThemeColors.DebugBackground);
  ReadColor('Error line',ThemeColors.ErrorForeground,ThemeColors.ErrorBackground);
  FG:=Editor.SelectedColor.Foreground;BG:=Editor.SelectedColor.Background;
  ReadColor('Selected text',FG,BG);Editor.SelectedColor.Foreground:=FG;Editor.SelectedColor.Background:=BG;
  FG:=Editor.Gutter.Parts.ByClass[TSynGutterLineNumber,0].MarkupInfo.Foreground;BG:=Editor.Gutter.Color;
  ReadColor('Gutter',FG,BG);Editor.Gutter.Color:=BG;
  Editor.Gutter.Parts.ByClass[TSynGutterLineNumber,0].MarkupInfo.Foreground:=FG;
  Editor.Gutter.Parts.ByClass[TSynGutterLineNumber,0].MarkupInfo.Background:=BG;
  if Editor.Gutter.CodeFoldPart<>nil then begin
    FG:=Editor.Gutter.CodeFoldPart.MarkupInfo.Foreground;BG:=Editor.Gutter.CodeFoldPart.MarkupInfo.Background;
    ReadColor('Fold markers',FG,BG);Editor.Gutter.CodeFoldPart.MarkupInfo.Foreground:=FG;Editor.Gutter.CodeFoldPart.MarkupInfo.Background:=BG;
  end;
end;

end.
