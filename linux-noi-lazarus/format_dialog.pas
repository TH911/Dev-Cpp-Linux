unit format_dialog;
{$mode objfpc}{$H+}
interface
uses Classes;
function FormatSource(const Source,Arguments:string):string;
function FormatArguments(const Config:string):string;
function EditFormatOptions(AOwner:TComponent;const Config,Source:string):Boolean;
implementation
uses SysUtils,Forms,Controls,StdCtrls,ExtCtrls,Spin,IniFiles,Dialogs,Process,Graphics,
  SynEdit,cpp_highlighter,Gtk2,Gdk2,Glib2,editor_themes,runtime_support,ui_language,input_appearance;
type
  TFormatForm=class(TForm)
  private
    FStyle,FIndent:TComboBox;FWidth,FMax:TSpinEdit;FUseMax:TCheckBox;
    FFlags:array[0..5] of TCheckBox;
    FArguments:TMemo;FPreview:TSynEdit;FError:TLabel;FTimer:TTimer;FSource:string;
    FUpdating:Boolean;FStoredArguments:string;
    procedure Changed(Sender:TObject);
    procedure ArgumentsChanged(Sender:TObject);
    procedure PreviewNow(Sender:TObject);
    procedure Accept(Sender:TObject);
    procedure FinishArgumentInput(Data:PtrInt);
    procedure ArgumentsMouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
  public
    constructor CreateFormat(AOwner:TComponent;const Arguments,Source:string);
    destructor Destroy;override;
  end;
function FormatArguments(const Config:string):string;
var Ini:TIniFile;
begin
  Ini:=TIniFile.Create(Config);
  try Result:=Ini.ReadString('AStyle','Arguments','--style='+Ini.ReadString('AStyle','Style','allman'));
  finally Ini.Free;end;
end;
function StoredFormatArguments(const Text:string):string;
var Parts:TStringList;I:Integer;Value,ErrorText:string;
begin
  Parts:=TStringList.Create;Result:='';
  try
    if not ParseRunArguments(Text,Parts,ErrorText) then raise Exception.Create(ErrorText);
    for I:=0 to Parts.Count-1 do begin
      Value:=Parts[I];
      if (Pos(#10,Value)>0) or (Pos(#13,Value)>0) then raise Exception.Create(Tr('A formatting option value cannot contain a line break.'));
      if (Pos(' ',Value)>0) or (Pos(#9,Value)>0) or (Pos(#39,Value)>0) or (Pos('"',Value)>0) or (Pos('\',Value)>0) then Value:=QuoteShellArgument(Value);
      if Result<>'' then Result:=Result+' ';Result:=Result+Value;
    end;
  finally Parts.Free;end;
end;
function FormatSource(const Source,Arguments:string):string;
var Parts,Lines:TStringList;ErrorText,Temporary,Output:string;A:array of string;I:Integer;
begin
  if not FileExists('/usr/bin/astyle') then raise Exception.Create(Tr('Install the optional astyle package to format source code.'));
  Parts:=TStringList.Create;Lines:=TStringList.Create;Temporary:='';
  try
    if not ParseRunArguments(Arguments,Parts,ErrorText) then raise Exception.Create(ErrorText);
    for I:=0 to Parts.Count-1 do
      if (Parts[I]='') or (Parts[I][1]<>'-') or (Parts[I]='--') then
        raise Exception.Create(Tr('Formatting arguments must contain options only.'));
    Temporary:=GetTempFileName(GetTempDir(False),'devcpp-format-');Lines.Text:=Source;Lines.SaveToFile(Temporary);
    SetLength(A,Parts.Count+4);for I:=0 to Parts.Count-1 do A[I]:=Parts[I];
    A[Parts.Count]:='--mode=c';A[Parts.Count+1]:='--suffix=none';A[Parts.Count+2]:='--quiet';A[Parts.Count+3]:=Temporary;
    if not RunCommand('/usr/bin/astyle',A,Output) then raise Exception.Create(Output);
    Lines.LoadFromFile(Temporary);Result:=Lines.Text;
  finally if Temporary<>'' then DeleteFile(Temporary);Lines.Free;Parts.Free;end;
end;
constructor TFormatForm.CreateFormat(AOwner:TComponent;const Arguments,Source:string);
const Names:array[0..5] of string=('Class','Switch','Case','Namespace','Labels','Preprocessor');
var G:TGroupBox;Buttons:TPanel;L:TLabel;B:TButton;I:Integer;Colors:TEditorThemeColors;Syntax:TNoiCppSyn;Parts:TStringList;ErrorText,Value:string;
  procedure LabelAt(const S:string;X,Y:Integer);
  begin L:=TLabel.Create(Self);L.Parent:=G;L.Caption:=Tr(S);L.SetBounds(X,Y,140,22);end;
begin
  inherited CreateNew(AOwner);FUpdating:=True;FSource:=Source;
  PopupMode:=pmExplicit;if AOwner is TCustomForm then PopupParent:=TCustomForm(AOwner);
  Caption:=Tr('Formatting options');Position:=poMainFormCenter;BorderStyle:=bsDialog;
  ClientWidth:=610;ClientHeight:=640;Font.Name:='Sans';Font.Size:=9;
  Buttons:=TPanel.Create(Self);Buttons.Parent:=Self;Buttons.Align:=alBottom;Buttons.Height:=40;Buttons.BevelOuter:=bvNone;
  B:=TButton.Create(Self);B.OnClick:=@Accept;B.Parent:=Buttons;B.SetBounds(398,6,96,28);B.Caption:=Tr('OK');B.Default:=True;
  B:=TButton.Create(Self);B.Parent:=Buttons;B.SetBounds(504,6,96,28);B.Caption:=Tr('Cancel');B.Cancel:=True;B.ModalResult:=mrCancel;
  G:=TGroupBox.Create(Self);G.Parent:=Self;G.SetBounds(10,8,590,266);G.Caption:=Tr('Options');
  LabelAt('Brace style',12,24);FStyle:=TComboBox.Create(Self);FStyle.Parent:=G;FStyle.SetBounds(138,22,155,28);FStyle.Style:=csDropDownList;
  FStyle.Items.CommaText:='allman,java,kr,stroustrup,whitesmith,gnu,linux,horstmann,1tbs,google,mozilla,webkit';FStyle.ItemIndex:=0;FStyle.OnChange:=@Changed;
  LabelAt('Indent style',12,62);FIndent:=TComboBox.Create(Self);FIndent.Parent:=G;FIndent.SetBounds(138,60,155,28);FIndent.Style:=csDropDownList;
  FIndent.Items.Add(Tr('Tabs'));FIndent.Items.Add(Tr('Spaces'));FIndent.ItemIndex:=0;FIndent.OnChange:=@Changed;
  LabelAt('Tab width (1-16)',12,100);FWidth:=TSpinEdit.Create(Self);FWidth.Parent:=G;FWidth.SetBounds(206,98,87,28);FWidth.MinValue:=1;FWidth.MaxValue:=16;FWidth.Value:=4;FWidth.OnChange:=@Changed;
  FUseMax:=TCheckBox.Create(Self);FUseMax.Parent:=G;FUseMax.SetBounds(12,136,188,24);FUseMax.Caption:=Tr('Maximum line length');FUseMax.OnClick:=@Changed;
  FMax:=TSpinEdit.Create(Self);FMax.Parent:=G;FMax.SetBounds(206,134,87,28);FMax.MinValue:=50;FMax.MaxValue:=200;FMax.Value:=80;FMax.OnChange:=@Changed;
  LabelAt('Indent these constructs',320,24);
  for I:=0 to 5 do begin
    FFlags[I]:=TCheckBox.Create(Self);FFlags[I].Parent:=G;FFlags[I].SetBounds(320+(I div 3)*130,56+(I mod 3)*30,128,24);
    FFlags[I].Caption:=Tr(Names[I]);FFlags[I].OnClick:=@Changed;
  end;
  LabelAt('Final command options (editable)',12,174);
  FArguments:=TMemo.Create(Self);FArguments.Parent:=G;FArguments.SetBounds(12,196,564,58);FArguments.ScrollBars:=ssAutoVertical;FArguments.Text:=Arguments;FArguments.OnChange:=@ArgumentsChanged;FArguments.OnMouseUp:=@ArgumentsMouseUp;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(10,284,590,20);L.Caption:=Tr('Preview');
  FPreview:=TSynEdit.Create(Self);FPreview.Parent:=Self;FPreview.SetBounds(10,308,590,260);FPreview.ReadOnly:=True;FPreview.Font.Name:=DefaultEditorFontName;FPreview.Font.Size:=11;FPreview.RightEdge:=0;
  Syntax:=TNoiCppSyn.Create(Self);FPreview.Highlighter:=Syntax;ApplyEditorTheme(FPreview,Syntax,Syntax.BracketAttri,Syntax.CharacterAttri,EditorThemeName(0),Colors);
  FError:=TLabel.Create(Self);FError.Parent:=Self;FError.SetBounds(10,574,590,22);FError.AutoSize:=False;FError.Font.Color:=clRed;
  FTimer:=TTimer.Create(Self);FTimer.Enabled:=False;FTimer.Interval:=250;FTimer.OnTimer:=@PreviewNow;
  Parts:=TStringList.Create;
  try
    if ParseRunArguments(Arguments,Parts,ErrorText) then for I:=0 to Parts.Count-1 do begin
      Value:=Parts[I];
      if Pos('--style=',Value)=1 then begin
        Value:=Copy(Value,9,MaxInt);FStyle.ItemIndex:=FStyle.Items.IndexOf(Value);
        if FStyle.ItemIndex<0 then begin FStyle.Items.Add(Value);FStyle.ItemIndex:=FStyle.Items.Count-1;end;
      end else if Pos('--indent=spaces=',Value)=1 then begin FIndent.ItemIndex:=1;FWidth.Value:=StrToIntDef(Copy(Value,17,MaxInt),4);end
      else if Pos('--indent=tab=',Value)=1 then begin FIndent.ItemIndex:=0;FWidth.Value:=StrToIntDef(Copy(Value,14,MaxInt),4);end
      else if Pos('--max-code-length=',Value)=1 then begin FUseMax.Checked:=True;FMax.Value:=StrToIntDef(Copy(Value,19,MaxInt),80);end
      else if Value='--indent-classes' then FFlags[0].Checked:=True
      else if Value='--indent-switches' then FFlags[1].Checked:=True
      else if Value='--indent-cases' then FFlags[2].Checked:=True
      else if Value='--indent-namespaces' then FFlags[3].Checked:=True
      else if Value='--indent-labels' then FFlags[4].Checked:=True
      else if Value='--indent-preproc-block' then FFlags[5].Checked:=True;
    end;
  finally Parts.Free;end;
  FUpdating:=False;FTimer.Enabled:=True;PrepareInputAppearance(Self);
end;
procedure TFormatForm.Changed(Sender:TObject);
const Flags:array[0..5] of string=('classes','switches','cases','namespaces','labels','preproc-block');
var S:string;I:Integer;
begin
  if FUpdating then Exit;S:='--style='+FStyle.Text+' --indent=';
  if FIndent.ItemIndex=0 then S:=S+'tab=' else S:=S+'spaces=';
  S:=S+IntToStr(FWidth.Value);if FUseMax.Checked then S:=S+' --max-code-length='+IntToStr(FMax.Value);
  for I:=0 to 5 do if FFlags[I].Checked then S:=S+' --indent-'+Flags[I];
  FArguments.Text:=S;
end;
procedure TFormatForm.ArgumentsChanged(Sender:TObject);
begin if FUpdating then Exit;Application.QueueAsyncCall(@FinishArgumentInput,0);FTimer.Enabled:=False;FTimer.Enabled:=True;end;
destructor TFormatForm.Destroy;
begin Application.RemoveAsyncCalls(Self);inherited Destroy;end;
procedure TFormatForm.ArgumentsMouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
begin Application.QueueAsyncCall(@FinishArgumentInput,0);end;
procedure TFormatForm.FinishArgumentInput(Data:PtrInt);
var Grab:PGtkWidget;X,Y:gint;Mask:TGdkModifierType;
begin
  Grab:=gtk_grab_get_current;
  if (Grab=nil) or not GTK_IS_TEXT_VIEW(Grab) or not FArguments.HandleAllocated then Exit;
  if (Grab<>PGtkWidget(FArguments.Handle)) and not gtk_widget_is_ancestor(Grab,PGtkWidget(FArguments.Handle)) then Exit;
  gdk_window_get_pointer(nil,@X,@Y,@Mask);
  if (Mask and (GDK_BUTTON1_MASK or GDK_BUTTON2_MASK or GDK_BUTTON3_MASK))<>0 then Exit;
  { GTK2 can retain a memo selection grab after the mouse has been released.
    A completed edit must not redirect subsequent button clicks to the memo. }
  gtk_grab_remove(Grab);
end;
procedure TFormatForm.PreviewNow(Sender:TObject);
begin
  FTimer.Enabled:=False;
  try FPreview.Text:=FormatSource(Copy(FSource,1,40000),Trim(FArguments.Text));FError.Caption:='';
  except on E:Exception do FError.Caption:=E.Message;end;
end;
procedure TFormatForm.Accept(Sender:TObject);
begin
  PreviewNow(Self);if FError.Caption<>'' then Exit;
  try FStoredArguments:=StoredFormatArguments(FArguments.Text);ModalResult:=mrOK;
  except on E:Exception do FError.Caption:=E.Message;end;
end;
function EditFormatOptions(AOwner:TComponent;const Config,Source:string):Boolean;
var D:TFormatForm;Ini:TIniFile;
begin
  D:=TFormatForm.CreateFormat(AOwner,FormatArguments(Config),Source);
  try
    Result:=D.ShowModal=mrOK;
    if Result then begin Ini:=TIniFile.Create(Config);try Ini.WriteString('AStyle','Arguments',D.FStoredArguments);finally Ini.Free;end;end;
  finally D.Free;end;
end;
end.
