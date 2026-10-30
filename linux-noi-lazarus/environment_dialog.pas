unit environment_dialog;
{$mode objfpc}{$H+}
interface
uses Classes;
function EditClassicEnvironment(AOwner:TComponent;const Config:string;
  var Language,Theme:string;var WatchFiles,Reports:Boolean):Boolean;
implementation
uses SysUtils,Forms,Controls,StdCtrls,ComCtrls,ExtCtrls,Spin,CheckLst,Dialogs,
  IniFiles,Graphics,ui_language,language_catalog,input_appearance,font_match,editor_themes;
const
  AssociationCount=6;
  MimeTypes:array[0..5] of string=('text/x-csrc','text/x-c++src','text/x-chdr','text/x-c++hdr','application/x-devcpp-project','text/plain');
  MimeNames:array[0..5] of string=('C Source File (*.c)','C++ Source File (*.cpp; *.cc; *.cxx)','C Header File (*.h)','C++ Header File (*.hpp; *.hxx)','Dev-C++ Project File (*.dev)','Plain text (*.txt; *.in; *.out; *.ans)');
type
  TEnvironmentForm=class(TForm)
  private
    FPages:TPageControl;FLanguage,FTheme,FUIFont:TComboBox;FSize:TSpinEdit;
    FWatch,FReports,FBottom:TCheckBox;FDirectory,FExecutable,FArguments,FName:TEdit;
    FAssociations:TCheckListBox;FInitial:array[0..5] of Boolean;
    FConfig,FMimePath:string;
    procedure Browse(Sender:TObject);
    procedure Accept(Sender:TObject);
    function Page(const AName:string):TTabSheet;
    function Entry(AParent:TWinControl;const ACaption,Value:string;Y:Integer;ReadOnly:Boolean=False):TEdit;
  public
    constructor CreateSettings(AOwner:TComponent;const Config,Language,Theme:string;WatchFiles,Reports:Boolean);
  end;
function TEnvironmentForm.Page(const AName:string):TTabSheet;
begin Result:=TTabSheet.Create(Self);Result.PageControl:=FPages;Result.Caption:=Tr(AName);end;
function TEnvironmentForm.Entry(AParent:TWinControl;const ACaption,Value:string;Y:Integer;ReadOnly:Boolean):TEdit;
var L:TLabel;
begin
  L:=TLabel.Create(Self);L.Parent:=AParent;L.Caption:=Tr(ACaption);L.SetBounds(14,Y,530,20);
  Result:=TEdit.Create(Self);Result.Parent:=AParent;Result.SetBounds(14,Y+23,520,28);Result.Text:=Value;Result.ReadOnly:=ReadOnly;
end;
constructor TEnvironmentForm.CreateSettings(AOwner:TComponent;const Config,Language,Theme:string;WatchFiles,Reports:Boolean);
var Basic,Paths,Programs,Associations:TTabSheet;Ini,Mime:TIniFile;B:TButton;L:TLabel;I:Integer;Assets,CacheFolder:string;
  function Check(Parent:TWinControl;const S:string;Y:Integer;Value:Boolean):TCheckBox;
  begin Result:=TCheckBox.Create(Self);Result.Parent:=Parent;Result.Caption:=Tr(S);Result.SetBounds(14,Y,520,25);Result.Checked:=Value;end;
  function Combo(const S:string;Y:Integer):TComboBox;
  begin
    L:=TLabel.Create(Self);L.Parent:=Basic;L.Caption:=Tr(S);L.SetBounds(14,Y,180,22);
    Result:=TComboBox.Create(Self);Result.Parent:=Basic;Result.SetBounds(200,Y,334,28);Result.Style:=csDropDownList;
  end;
begin
  inherited CreateNew(AOwner);FConfig:=Config;Caption:=Tr('Environment Options');BorderStyle:=bsDialog;Position:=poMainFormCenter;
  Font.Name:='Sans';Font.Size:=9;ClientWidth:=560;ClientHeight:=520;
  FPages:=TPageControl.Create(Self);FPages.Parent:=Self;FPages.SetBounds(0,0,560,474);
  Basic:=Page('Basic');Paths:=Page('Files and folders');Programs:=Page('External programs');Associations:=Page('File associations');
  FLanguage:=Combo('Language',20);for I:=0 to UiLanguageCount-1 do begin FLanguage.Items.Add(UiLanguageName(I));if UiLanguageCode(I)=Language then FLanguage.ItemIndex:=I;end;
  FTheme:=Combo('Editor theme',68);for I:=0 to EditorThemeCount-1 do FTheme.Items.Add(EditorThemeName(I));FTheme.ItemIndex:=EditorThemeIndex(Theme);
  FWatch:=Check(Basic,'Detect external file changes',122,WatchFiles);FReports:=Check(Basic,'Show report window',158,Reports);
  Ini:=TIniFile.Create(Config);
  try
    FBottom:=Check(Basic,'Report tabs at bottom',194,Ini.ReadBool('Interface','ReportTabsBottom',False));
    FUIFont:=Combo('UI font',246);FUIFont.Style:=csDropDown;ListFontFamilies(FUIFont.Items);FUIFont.Text:=Ini.ReadString('Interface','Font','Sans');
    FSize:=TSpinEdit.Create(Self);FSize.Parent:=Basic;FSize.SetBounds(454,294,80,28);FSize.MinValue:=7;FSize.MaxValue:=24;FSize.Value:=Ini.ReadInteger('Interface','FontSize',9);
    L:=TLabel.Create(Self);L.Parent:=Basic;L.Caption:=Tr('Size');L.SetBounds(200,296,200,24);
    Entry(Paths,'Current settings file',Config,12,True);
    FDirectory:=Entry(Paths,'Default folder',Ini.ReadString('Interface','DefaultDirectory',GetEnvironmentVariable('HOME')),80);
    FDirectory.Width:=478;B:=TButton.Create(Self);B.Parent:=Paths;B.SetBounds(498,103,36,28);B.Caption:='...';B.OnClick:=@Browse;
    Assets:=ExtractFilePath(ParamStr(0));Entry(Paths,'Icon folder',Assets+'icons/',148,True);
    Entry(Paths,'Language folder',Assets+'languages/',216,True);Entry(Paths,'Application folder',Assets,284,True);
    CacheFolder:=GetEnvironmentVariable('XDG_CACHE_HOME');if (CacheFolder='') or (CacheFolder[1]<>'/') then CacheFolder:=GetEnvironmentVariable('HOME')+'/.cache';
    Entry(Paths,'Recovery folder',IncludeTrailingPathDelimiter(CacheFolder)+'dev-cpp/autosave/',352,True);
    FName:=Entry(Programs,'Tool name',Ini.ReadString('ExternalTool','Name',Tr('External tool')),16);
    FExecutable:=Entry(Programs,'Executable',Ini.ReadString('ExternalTool','Executable',''),90);
    FArguments:=Entry(Programs,'Arguments',Ini.ReadString('ExternalTool','Arguments',''),164);
    L:=TLabel.Create(Self);L.Parent:=Programs;L.SetBounds(14,248,520,100);L.AutoSize:=False;L.WordWrap:=True;
    L.Caption:=Tr('The configured tool appears in Tools. Arguments use %FILE% and %DIR%; quotes preserve spaces. Shell expansion is not performed.');
  finally Ini.Free;end;
  FAssociations:=TCheckListBox.Create(Self);FAssociations.Parent:=Associations;FAssociations.SetBounds(14,18,520,290);
  FMimePath:=GetEnvironmentVariable('XDG_CONFIG_HOME');if (FMimePath='') or (FMimePath[1]<>'/') then FMimePath:=GetEnvironmentVariable('HOME')+'/.config';FMimePath:=IncludeTrailingPathDelimiter(FMimePath)+'mimeapps.list';
  Mime:=TIniFile.Create(FMimePath);
  try
    for I:=0 to AssociationCount-1 do begin
      FAssociations.Items.Add(MimeNames[I]);FInitial[I]:=Pos('dev-cpp.desktop;',Mime.ReadString('Default Applications',MimeTypes[I],''))=1;
      FAssociations.Checked[I]:=FInitial[I];
    end;
  finally Mime.Free;end;
  L:=TLabel.Create(Self);L.Parent:=Associations;L.SetBounds(14,328,520,96);L.AutoSize:=False;L.WordWrap:=True;
  L.Caption:=Tr('Change user defaults for an installed Dev-C++. Existing system defaults remain available. Unchecking removes only Dev-C++ from the user override.');
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(350,482,94,30);B.Caption:=Tr('OK');B.Default:=True;B.OnClick:=@Accept;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(452,482,96,30);B.Caption:=Tr('Cancel');B.Cancel:=True;B.ModalResult:=mrCancel;
  FPages.ActivePage:=Basic;PrepareInputAppearance(Self);
end;
procedure TEnvironmentForm.Browse(Sender:TObject);
var DirectoryName:string;
begin DirectoryName:=FDirectory.Text;if SelectDirectory(Tr('Default folder'),'',DirectoryName) then FDirectory.Text:=DirectoryName;end;
procedure TEnvironmentForm.Accept(Sender:TObject);
begin
  if (Trim(FDirectory.Text)<>'') and not DirectoryExists(FDirectory.Text) then begin UiMessageDlg(Tr('The working directory does not exist.'),mtError,[mbOK],0);Exit;end;
  if Trim(FUIFont.Text)='' then Exit;ModalResult:=mrOK;
end;
function EditClassicEnvironment(AOwner:TComponent;const Config:string;
  var Language,Theme:string;var WatchFiles,Reports:Boolean):Boolean;
var D:TEnvironmentForm;Ini,Mime:TIniFile;I:Integer;Value:string;
begin
  D:=TEnvironmentForm.CreateSettings(AOwner,Config,Language,Theme,WatchFiles,Reports);
  try
    Result:=D.ShowModal=mrOK;if not Result then Exit;
    Language:=UiLanguageCode(D.FLanguage.ItemIndex);Theme:=EditorThemeName(D.FTheme.ItemIndex);WatchFiles:=D.FWatch.Checked;Reports:=D.FReports.Checked;
    Ini:=TIniFile.Create(Config);
    try
      Ini.WriteString('Interface','Font',D.FUIFont.Text);Ini.WriteInteger('Interface','FontSize',D.FSize.Value);
      Ini.WriteBool('Interface','ReportTabsBottom',D.FBottom.Checked);Ini.WriteString('Interface','DefaultDirectory',D.FDirectory.Text);
      Ini.WriteString('ExternalTool','Name',D.FName.Text);Ini.WriteString('ExternalTool','Executable',D.FExecutable.Text);Ini.WriteString('ExternalTool','Arguments',D.FArguments.Text);
    finally Ini.Free;end;
    Mime:=nil;
    try
      for I:=0 to AssociationCount-1 do if D.FAssociations.Checked[I]<>D.FInitial[I] then begin
        if Mime=nil then begin ForceDirectories(ExtractFileDir(D.FMimePath));Mime:=TIniFile.Create(D.FMimePath);end;
        Value:=Mime.ReadString('Default Applications',MimeTypes[I],'');Value:=StringReplace(Value,'dev-cpp.desktop;','',[rfReplaceAll]);
        if D.FAssociations.Checked[I] then Value:='dev-cpp.desktop;'+Value;
        if Value='' then Mime.DeleteKey('Default Applications',MimeTypes[I]) else Mime.WriteString('Default Applications',MimeTypes[I],Value);
      end;
    finally Mime.Free;end;
  finally D.Free;end;
end;
end.
