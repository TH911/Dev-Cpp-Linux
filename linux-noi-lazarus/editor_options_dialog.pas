unit editor_options_dialog;
{$mode objfpc}{$H+}
interface
uses Classes, editor_preferences;
function EditAdvancedEditor(AOwner: TComponent; Preferences: TEditorPreferences;
  var ThemeName, FontName: string; var FontSize, TabWidth: Integer): Boolean;
implementation
uses SysUtils, Math, Types, LazUTF8, LCLType, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin,
  Graphics, Dialogs, ColorBox, SynEdit, SynEditHighlighter, cpp_highlighter,
  editor_themes, ui_language, input_appearance;
type
  TEditorOptionsForm = class(TForm)
  private
    FWorking: TEditorPreferences;
    FPages: TPageControl;
    FFlags: array[TEditorFlag] of TCheckBox;
    FTheme, FFont, FGutterFont, FInsertCaret, FOverwriteCaret: TComboBox;
    FSize, FTabs, FGutterSize, FSpacing, FMargin, FSeconds: TSpinEdit;
    FMarginColor, FLineColor, FForeground, FBackground: TColorBox;
    FAttributes, FSnippets: TListBox;
    FDefaultCode, FSnippetCode: TSynEdit;
    FPreview: TSynEdit;
    FSyntax: TNoiCppSyn;
    FStyles: array[0..2] of TCheckBox;
    FUpdating: Boolean;
    FSelectedSnippet: Integer;
    procedure DialogKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure RefreshPreview(Sender: TObject);
    procedure ThemeChanged(Sender: TObject);
    procedure AttributeChanged(Sender: TObject);
    procedure ColorChanged(Sender: TObject);
    procedure DrawFont(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure SnippetChanged(Sender: TObject; User: Boolean);
    procedure AddSnippet(Sender: TObject);
    procedure RemoveSnippet(Sender: TObject);
    procedure Accept(Sender: TObject);
    procedure ReadControls;
    function Tab(const ACaption: string): TTabSheet;
    function Group(AParent: TWinControl; const ACaption: string; X,Y,W,H: Integer): TGroupBox;
    function Flag(AParent: TWinControl; Value: TEditorFlag; X,Y,W: Integer): TCheckBox;
    function Combo(AParent: TWinControl; const ACaption: string; X,Y,W: Integer): TComboBox;
    function Spin(AParent: TWinControl; const ACaption: string; X,Y,W,Min,Max,Value: Integer): TSpinEdit;
    function Color(AParent: TWinControl; const ACaption: string; X,Y,W: Integer; Value: TColor): TColorBox;
    procedure LabelAt(AParent: TWinControl; const ACaption: string; X,Y,W,H: Integer);
  public
    constructor CreateSettings(AOwner: TComponent; Preferences: TEditorPreferences;
      const ThemeName, FontName: string; FontSize, TabWidth: Integer);
    destructor Destroy; override;
  end;
function TEditorOptionsForm.Tab(const ACaption: string): TTabSheet;
begin Result:=TTabSheet.Create(Self); Result.PageControl:=FPages; Result.Caption:=Tr(ACaption); end;
function TEditorOptionsForm.Group(AParent: TWinControl; const ACaption: string; X,Y,W,H: Integer): TGroupBox;
begin Result:=TGroupBox.Create(Self);Result.Parent:=AParent;Result.Caption:=Tr(ACaption);Result.SetBounds(X,Y,W,H);end;
procedure TEditorOptionsForm.LabelAt(AParent: TWinControl; const ACaption: string; X,Y,W,H: Integer);
var L:TLabel;
begin L:=TLabel.Create(Self);L.Parent:=AParent;L.Caption:=Tr(ACaption);L.AutoSize:=False;L.WordWrap:=True;L.SetBounds(X,Y,W,H);end;
function TEditorOptionsForm.Flag(AParent: TWinControl; Value:TEditorFlag; X,Y,W:Integer):TCheckBox;
begin
  Result:=TCheckBox.Create(Self);Result.Parent:=AParent;Result.SetBounds(X,Y,W,24);
  Result.Caption:=Tr(EditorFlagCaptions[Value]);Result.Checked:=Value in FWorking.Flags;
  Result.OnClick:=@RefreshPreview;FFlags[Value]:=Result;
end;
function TEditorOptionsForm.Combo(AParent:TWinControl; const ACaption:string; X,Y,W:Integer):TComboBox;
begin
  LabelAt(AParent,ACaption,X,Y,W,20);Result:=TComboBox.Create(Self);Result.Parent:=AParent;
  Result.SetBounds(X,Y+22,W,28);Result.OnChange:=@RefreshPreview;
end;
function TEditorOptionsForm.Spin(AParent:TWinControl;const ACaption:string;X,Y,W,Min,Max,Value:Integer):TSpinEdit;
begin
  LabelAt(AParent,ACaption,X,Y,W,20);Result:=TSpinEdit.Create(Self);Result.Parent:=AParent;
  Result.SetBounds(X,Y+22,W,28);Result.MinValue:=Min;Result.MaxValue:=Max;Result.Value:=Value;Result.OnEditingDone:=@RefreshPreview;
end;
function TEditorOptionsForm.Color(AParent:TWinControl;const ACaption:string;X,Y,W:Integer;Value:TColor):TColorBox;
begin
  LabelAt(AParent,ACaption,X,Y,W,20);Result:=TColorBox.Create(Self);Result.Parent:=AParent;
  Result.SetBounds(X,Y+22,W,28);Result.Style:=Result.Style+[cbCustomColor,cbIncludeNone,cbPrettyNames];
  Result.Selected:=Value;Result.OnChange:=@RefreshPreview;
end;
constructor TEditorOptionsForm.CreateSettings(AOwner:TComponent;Preferences:TEditorPreferences;
  const ThemeName,FontName:string;FontSize,TabWidth:Integer);
var Basic, DisplayTab, SyntaxTab, CodeTab, CompletionTab, RecoveryTab:TTabSheet;
  P:TGroupBox;
  G:TGroupBox; Buttons:TPanel; B:TButton; I:Integer; F:TEditorFlag;
  procedure FontCombo(C:TComboBox;const AName:string);
  begin
    C.Style:=csOwnerDrawEditableFixed;C.Items.Assign(Screen.Fonts);C.Text:=AName;
    C.ItemHeight:=32;C.OnDrawItem:=@DrawFont;
  end;
begin
  inherited CreateNew(AOwner);FUpdating:=True;FSelectedSnippet:=-1;
  FWorking:=TEditorPreferences.Create;FWorking.Assign(Preferences);
  Self.Caption:=Tr('Editor Options');BorderStyle:=bsDialog;Position:=poMainFormCenter;
  Font.Name:='Sans';Font.Size:=9;ClientWidth:=600;ClientHeight:=574;
  KeyPreview:=True;OnKeyDown:=@DialogKeyDown;
  Buttons:=TPanel.Create(Self);Buttons.Parent:=Self;Buttons.Align:=alBottom;Buttons.Height:=42;Buttons.BevelOuter:=bvNone;
  B:=TButton.Create(Self);B.Parent:=Buttons;B.SetBounds(388,6,96,30);B.Caption:=Tr('OK');B.Default:=True;B.OnClick:=@Accept;
  B:=TButton.Create(Self);B.Parent:=Buttons;B.SetBounds(492,6,96,30);B.Caption:=Tr('Cancel');B.Cancel:=True;B.ModalResult:=mrCancel;
  FPages:=TPageControl.Create(Self);FPages.Parent:=Self;FPages.Align:=alClient;
  Basic:=Tab('Basic');DisplayTab:=Tab('Display');SyntaxTab:=Tab('Syntax');CodeTab:=Tab('Code');CompletionTab:=Tab('Code completion');RecoveryTab:=Tab('Auto save');
  G:=Group(Basic,'Editor options',10,8,572,234);
  for I:=0 to 15 do Flag(G,TEditorFlag(I),10+(I div 8)*278,20+(I mod 8)*24,270);
  G:=Group(Basic,'Caret',10,250,280,116);
  FInsertCaret:=Combo(G,'Insert caret',10,20,120);FInsertCaret.Style:=csDropDownList;
  FOverwriteCaret:=Combo(G,'Overwrite caret',142,20,124);FOverwriteCaret.Style:=csDropDownList;
  FInsertCaret.Items.Add(Tr('Vertical line'));FInsertCaret.Items.Add(Tr('Block'));FInsertCaret.Items.Add(Tr('Horizontal line'));FInsertCaret.Items.Add(Tr('Half block'));
  FOverwriteCaret.Items.Assign(FInsertCaret.Items);FInsertCaret.ItemIndex:=FWorking.InsertCaret;FOverwriteCaret.ItemIndex:=FWorking.OverwriteCaret;
  Flag(G,efMatchBrackets,10,82,260);
  G:=Group(Basic,'Right margin',300,250,282,116);Flag(G,efRightMargin,10,18,260);
  FMargin:=Spin(G,'Width',10,46,82,1,1024,FWorking.MarginWidth);FMarginColor:=Color(G,'Color',104,46,164,FWorking.MarginColor);
  G:=Group(Basic,'Tabs',10,374,280,116);Flag(G,efUseTabs,10,18,260);Flag(G,efSmartTabs,10,44,260);
  FTabs:=Spin(G,'Tab width (1-16)',142,64,124,1,16,TabWidth);
  G:=Group(Basic,'Highlight current line',300,374,282,116);Flag(G,efHighlightLine,10,18,260);FLineColor:=Color(G,'Color',10,48,258,FWorking.CurrentLineColor);
  G:=Group(DisplayTab,'Editor font',10,12,572,120);FFont:=Combo(G,'Font',12,22,420);FontCombo(FFont,FontName);
  FSize:=Spin(G,'Size',448,22,110,1,72,FontSize);
  G:=Group(DisplayTab,'Gutter',10,152,572,264);
  Flag(G,efGutterVisible,12,22,264);Flag(G,efGutterAuto,12,50,264);Flag(G,efCustomGutterFont,12,78,264);
  Flag(G,efLineNumbers,290,22,266);Flag(G,efZeroStart,290,50,266);Flag(G,efLeadingZeros,290,78,266);
  FSpacing:=Spin(G,'Gutter spacing',290,116,266,0,40,FWorking.GutterSpacing);
  FGutterFont:=Combo(G,'Font',12,184,420);FontCombo(FGutterFont,FWorking.GutterFont);
  if FGutterFont.Text='' then FGutterFont.Text:=FontName;
  FGutterSize:=Spin(G,'Size',448,184,110,1,72,FWorking.GutterSize);
  LabelAt(DisplayTab,'Use Ctrl+mouse wheel to change the editor font size.',20,446,550,44);
  FAttributes:=TListBox.Create(Self);FAttributes.Parent:=SyntaxTab;FAttributes.SetBounds(10,12,152,204);FAttributes.OnClick:=@AttributeChanged;
  FForeground:=Color(SyntaxTab,'Foreground',10,230,152,clBlack);FForeground.OnChange:=@ColorChanged;
  FBackground:=Color(SyntaxTab,'Background',10,286,152,clWhite);FBackground.OnChange:=@ColorChanged;
  G:=Group(SyntaxTab,'Style',10,346,152,110);
  for I:=0 to 2 do begin FStyles[I]:=TCheckBox.Create(Self);FStyles[I].Parent:=G;FStyles[I].SetBounds(10,20+I*26,132,24);FStyles[I].OnClick:=@ColorChanged;end;
  FStyles[0].Caption:=Tr('Bold');FStyles[1].Caption:=Tr('Italic');FStyles[2].Caption:=Tr('Underline');
  FPreview:=TSynEdit.Create(Self);FPreview.Parent:=SyntaxTab;FPreview.SetBounds(174,12,408,394);FPreview.ReadOnly:=True;
  FPreview.Font.Name:=ResolveEditorFontName(FontName);FPreview.Font.Size:=FontSize;FPreview.RightEdge:=0;
  FSyntax:=TNoiCppSyn.Create(Self);FPreview.Highlighter:=FSyntax;
  FPreview.Lines.Text:='#include <iostream>'+LineEnding+'int main(int argc, char **argv) {'+LineEnding+'    // syntax preview'+LineEnding+'    double number = 1e5;'+LineEnding+'    char letter = ''A'';'+LineEnding+'    std::cout << "total: " << number;'+LineEnding+'    return 0;'+LineEnding+'}';
  for I:=0 to FSyntax.AttrCount-1 do FAttributes.Items.AddObject(FSyntax.Attribute[I].Name,FSyntax.Attribute[I]);
  FTheme:=Combo(SyntaxTab,'Preset',174,418,408);FTheme.Style:=csDropDownList;
  for I:=0 to EditorThemeCount-1 do FTheme.Items.Add(EditorThemeName(I));FTheme.ItemIndex:=EditorThemeIndex(ThemeName);FTheme.OnChange:=@ThemeChanged;
  Flag(SyntaxTab,efSyntax,174,476,408);
  P:=Group(CodeTab,'Inserts',10,10,200,488);
  FSnippets:=TListBox.Create(Self);FSnippets.Parent:=P;FSnippets.SetBounds(10,22,180,170);FSnippets.OnSelectionChange:=@SnippetChanged;
  FSnippetCode:=TSynEdit.Create(Self);FSnippetCode.Parent:=P;FSnippetCode.SetBounds(10,238,180,236);FSnippetCode.ScrollBars:=ssAutoBoth;FSnippetCode.Font.Name:=DefaultEditorFontName;FSnippetCode.Font.Size:=10;FSnippetCode.RightEdge:=0;
  B:=TButton.Create(Self);B.Parent:=P;B.SetBounds(10,200,84,30);B.Caption:=Tr('Add');B.OnClick:=@AddSnippet;
  B:=TButton.Create(Self);B.Parent:=P;B.SetBounds(102,200,88,30);B.Caption:=Tr('Remove');B.OnClick:=@RemoveSnippet;
  for I:=0 to FWorking.Snippets.Count-1 do FSnippets.Items.Add(FWorking.Snippets.Names[I]);
  P:=Group(CodeTab,'Default insert',220,10,362,488);Flag(P,efDefaultCode,10,22,340);
  FDefaultCode:=TSynEdit.Create(Self);FDefaultCode.Parent:=P;FDefaultCode.SetBounds(10,62,342,412);FDefaultCode.Lines.Text:=FWorking.DefaultCode;FDefaultCode.ScrollBars:=ssAutoBoth;FDefaultCode.Font.Name:=DefaultEditorFontName;FDefaultCode.Font.Size:=10;FDefaultCode.RightEdge:=0;
  G:=Group(CompletionTab,'Code completion',10,12,572,150);Flag(G,efCompletion,12,26,548);
  LabelAt(G,'Ctrl+Space invokes completion; automatic member completion uses the current source and local headers.',12,66,548,68);
  LabelAt(CompletionTab,'Function hints and editor hints are configured on the Basic page.',22,188,548,58);
  G:=Group(RecoveryTab,'Auto save',10,12,572,192);Flag(G,efAutoSave,12,26,548);
  FSeconds:=Spin(G,'Interval (seconds)',12,74,230,10,3600,FWorking.AutoSaveSeconds);
  LabelAt(RecoveryTab,'Recovery copies keep unsaved buffers without overwriting source files. They are stored under ~/.cache/dev-cpp/autosave/.',22,236,548,96);
  FPages.ActivePage:=Basic;FUpdating:=False;RefreshPreview(Self);
  if FAttributes.Count>0 then begin FAttributes.ItemIndex:=0;AttributeChanged(Self);end;
  PrepareInputAppearance(Self);
end;
destructor TEditorOptionsForm.Destroy;
begin FUpdating:=True;FWorking.Free;inherited Destroy;end;
procedure TEditorOptionsForm.DialogKeyDown(Sender:TObject;var Key:Word;Shift:TShiftState);
begin
  if (Key=VK_ESCAPE) and (Shift=[]) then begin ModalResult:=mrCancel;Key:=0;Exit;end;
  if (Shift=[ssCtrl]) and (Key=Ord('A')) then begin
    if (ActiveControl is TCustomEdit) and not (ActiveControl is TCustomMemo) then begin TCustomEdit(ActiveControl).SelectAll;Key:=0;end
    else if ActiveControl is TCustomComboBox then begin TCustomComboBox(ActiveControl).SelStart:=0;TCustomComboBox(ActiveControl).SelLength:=UTF8Length(TCustomComboBox(ActiveControl).Text);Key:=0;end;
  end;
end;
procedure TEditorOptionsForm.DrawFont(Control:TWinControl;Index:Integer;ARect:TRect;State:TOwnerDrawState);
var C:TComboBox;S:string;
begin
  C:=TComboBox(Control);C.Canvas.FillRect(ARect);if Index<0 then S:=C.Text else S:=C.Items[Index];
  C.Canvas.Font.Name:=S;C.Canvas.Font.Size:=12;
  C.Canvas.TextOut(ARect.Left+4,ARect.Top+Max(0,(ARect.Bottom-ARect.Top-C.Canvas.TextHeight(S)) div 2),S);
end;
procedure TEditorOptionsForm.ReadControls;
var F:TEditorFlag;
begin
  for F:=Low(F) to High(F) do if FFlags[F]<>nil then
    if FFlags[F].Checked then Include(FWorking.Flags,F) else Exclude(FWorking.Flags,F);
  FWorking.GutterFont:=FGutterFont.Text;FWorking.GutterSize:=FGutterSize.Value;FWorking.GutterSpacing:=FSpacing.Value;
  FWorking.MarginWidth:=FMargin.Value;FWorking.MarginColor:=FMarginColor.Selected;FWorking.CurrentLineColor:=FLineColor.Selected;
  FWorking.InsertCaret:=FInsertCaret.ItemIndex;FWorking.OverwriteCaret:=FOverwriteCaret.ItemIndex;
  FWorking.AutoSaveSeconds:=FSeconds.Value;
end;
procedure TEditorOptionsForm.RefreshPreview(Sender:TObject);
var C:TEditorThemeColors;
begin
  if FUpdating then Exit;FUpdating:=True;
  try
    ReadControls;
    FGutterFont.Enabled:=efCustomGutterFont in FWorking.Flags;FGutterSize.Enabled:=FGutterFont.Enabled;
    FPreview.Font.Name:=ResolveEditorFontName(FFont.Text);FPreview.Font.Size:=FSize.Value;FPreview.TabWidth:=FTabs.Value;
    ApplyEditorTheme(FPreview,FSyntax,FSyntax.BracketAttri,FSyntax.CharacterAttri,EditorThemeName(FTheme.ItemIndex),C,FSyntax.FloatAttri,FSyntax.HexAttri,FSyntax.OctalAttri);
    FWorking.Apply(FPreview,FSyntax);
  finally FUpdating:=False;end;
end;
procedure TEditorOptionsForm.ThemeChanged(Sender:TObject);
begin if FUpdating then Exit;FWorking.Colors.Clear;RefreshPreview(Self);AttributeChanged(Self);end;
procedure TEditorOptionsForm.AttributeChanged(Sender:TObject);
var A:TSynHighlighterAttributes;
begin
  if FUpdating or (FAttributes.ItemIndex<0) then Exit;FUpdating:=True;
  try
    A:=TSynHighlighterAttributes(FAttributes.Items.Objects[FAttributes.ItemIndex]);
    FForeground.Selected:=A.Foreground;FBackground.Selected:=A.Background;
    FStyles[0].Checked:=fsBold in A.Style;FStyles[1].Checked:=fsItalic in A.Style;FStyles[2].Checked:=fsUnderline in A.Style;
  finally FUpdating:=False;end;
end;
procedure TEditorOptionsForm.ColorChanged(Sender:TObject);
var A:TSynHighlighterAttributes;Bits:Integer;
begin
  if FUpdating or (FAttributes.ItemIndex<0) then Exit;
  A:=TSynHighlighterAttributes(FAttributes.Items.Objects[FAttributes.ItemIndex]);Bits:=0;
  if FStyles[0].Checked then Inc(Bits,1);if FStyles[1].Checked then Inc(Bits,2);if FStyles[2].Checked then Inc(Bits,4);
  FWorking.Colors.Values[A.Name+'.Foreground']:=IntToStr(FForeground.Selected);
  FWorking.Colors.Values[A.Name+'.Background']:=IntToStr(FBackground.Selected);
  FWorking.Colors.Values[A.Name+'.Style']:=IntToStr(Bits);RefreshPreview(Self);
end;
procedure TEditorOptionsForm.SnippetChanged(Sender:TObject;User:Boolean);
begin
  if FUpdating then Exit;
  if FSelectedSnippet>=0 then FWorking.Snippets.ValueFromIndex[FSelectedSnippet]:=FSnippetCode.Lines.Text;
  FSelectedSnippet:=FSnippets.ItemIndex;
  if FSelectedSnippet>=0 then FSnippetCode.Lines.Text:=FWorking.Snippets.ValueFromIndex[FSelectedSnippet] else FSnippetCode.Lines.Clear;
end;
procedure TEditorOptionsForm.AddSnippet(Sender:TObject);
var AName:string;
begin
  AName:='';if not UiInputQuery(Tr('Insert'),Tr('Name'),AName) then Exit;AName:=Trim(AName);
  if (AName='') or (Pos(#1,AName)>0) or (Pos(#10,AName)>0) or (FSnippets.Items.IndexOf(AName)>=0) then Exit;
  FWorking.Snippets.Add(AName+#1);FSnippets.Items.Add(AName);FSnippets.ItemIndex:=FSnippets.Count-1;SnippetChanged(Self,True);
end;
procedure TEditorOptionsForm.RemoveSnippet(Sender:TObject);
var I:Integer;
begin
  I:=FSnippets.ItemIndex;if I<0 then Exit;FUpdating:=True;
  try FSelectedSnippet:=-1;FWorking.Snippets.Delete(I);FSnippets.Items.Delete(I);FSnippetCode.Lines.Clear;finally FUpdating:=False;end;
end;
procedure TEditorOptionsForm.Accept(Sender:TObject);
begin
  if Trim(FFont.Text)='' then begin UiMessageDlg(Tr('Font name cannot be empty.'),mtError,[mbOK],0);Exit;end;
  ReadControls;FWorking.DefaultCode:=FDefaultCode.Lines.Text;
  if FSelectedSnippet>=0 then FWorking.Snippets.ValueFromIndex[FSelectedSnippet]:=FSnippetCode.Lines.Text;
  ModalResult:=mrOK;
end;
function EditAdvancedEditor(AOwner:TComponent;Preferences:TEditorPreferences;
  var ThemeName,FontName:string;var FontSize,TabWidth:Integer):Boolean;
var D:TEditorOptionsForm;
begin
  D:=TEditorOptionsForm.CreateSettings(AOwner,Preferences,ThemeName,FontName,FontSize,TabWidth);
  try
    Result:=D.ShowModal=mrOK;
    if Result then begin
      Preferences.Assign(D.FWorking);ThemeName:=EditorThemeName(D.FTheme.ItemIndex);
      FontName:=Trim(D.FFont.Text);FontSize:=D.FSize.Value;TabWidth:=D.FTabs.Value;
    end;
  finally D.Free;end;
end;
end.
