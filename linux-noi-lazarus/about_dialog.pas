unit about_dialog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes;
procedure ShowAboutDialog(AOwner:TComponent);
implementation
uses SysUtils,Math,Forms,Controls,StdCtrls,ExtCtrls,ComCtrls,Buttons,Graphics,
  Dialogs,LCLIntf,LCLType,ui_language,app_version,input_appearance,app_paths,
  startup_trace,about_original;
const
  OrwellRepository='https://sf.net/projects/orwelldevcpp/';
  OrwellReddit='http://www.reddit.com/r/devcpp/';
  OrwellBlog='http://orwelldevcpp.blogspot.com';
  MinGWWebsite='http://www.mingw.org';
  TDMWebsite='http://tdm-gcc.tdragon.net/';
  BloodshedWebsite='http://www.bloodshed.net';
  BloodshedForum='http://www.bloodshed.net/forum/';
  BloodshedMailing='http://www.bloodshed.net/devcpp-ml.html';
  BloodshedResources='http://www.bloodshed.net/dev/';
  OriginalDonate='https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=7FD675DNV8KKJ';
type
  TAboutDialog=class(TForm)
  private
    procedure OpenLink(Sender:TObject);
    procedure LinkKey(Sender:TObject;var Key:Word;Shift:TShiftState);
    procedure AuthorsClick(Sender:TObject);
  public
    constructor Create(AOwner:TComponent);override;
  end;
function AboutText(const EnglishText,ChineseText:string):string;
begin
  if CurrentUiLanguage=ulChinese then Result:=ChineseText else Result:=Tr(EnglishText);
end;
function NativeText(Owner:TComponent;Parent:TWinControl;const Text:string;
  X,Y,W,H:Integer):TStaticText;
begin
  Result:=TStaticText.Create(Owner);Result.Parent:=Parent;Result.AutoSize:=False;
  Result.SetBounds(X,Y,W,H);Result.Caption:=Text;
end;
procedure ClassicOK(Button:TBitBtn);
var Glyph:TBitmap;
begin
  Button.Kind:=bkCustom;Button.Default:=True;Button.ModalResult:=mrOK;
  Glyph:=TBitmap.Create;
  try
    Glyph.SetSize(16,16);Glyph.Canvas.Brush.Color:=clFuchsia;Glyph.Canvas.FillRect(0,0,16,16);
    Glyph.Canvas.Pen.Color:=clBlack;Glyph.Canvas.Brush.Color:=clBlack;
    Glyph.Canvas.Polygon([Point(1,7),Point(3,5),Point(6,8),Point(12,1),Point(15,3),Point(6,14)]);
    Glyph.Canvas.Pen.Color:=clLime;Glyph.Canvas.Brush.Color:=clLime;
    Glyph.Canvas.Polygon([Point(2,7),Point(3,6),Point(6,10),Point(13,2),Point(14,3),Point(6,12)]);
    Glyph.TransparentColor:=clFuchsia;Glyph.Transparent:=True;Button.Glyph.Assign(Glyph);
  finally Glyph.Free;end;
end;
procedure TAboutDialog.OpenLink(Sender:TObject);
var URL:string;
begin
  URL:=TControl(Sender).Hint;
  if not OpenURL(URL) then UiMessageDlg(URL,mtError,[mbOK],0);
end;
procedure TAboutDialog.LinkKey(Sender:TObject;var Key:Word;Shift:TShiftState);
begin
  if (Key in [VK_RETURN,VK_SPACE]) and (Shift=[]) then begin Key:=0;OpenLink(Sender);end;
end;
procedure TAboutDialog.AuthorsClick(Sender:TObject);
var Dialog:TForm;Memo:TMemo;Button:TBitBtn;Footer:TPanel;
begin
  Dialog:=TForm.CreateNew(Self);
  try
    Dialog.Caption:=Tr('Authors');Dialog.Position:=poOwnerFormCenter;
    Dialog.BorderStyle:=bsDialog;Dialog.ClientWidth:=620;
    Dialog.ClientHeight:=Min(440,Screen.WorkAreaHeight-80);
    Footer:=TPanel.Create(Dialog);Footer.Parent:=Dialog;Footer.Align:=alBottom;
    Footer.Height:=42;Footer.BevelOuter:=bvNone;
    Button:=TBitBtn.Create(Dialog);Button.Parent:=Footer;ClassicOK(Button);
    Button.Caption:=Tr('&OK');Button.SetBounds(512,7,96,28);Button.Cancel:=True;
    Memo:=TMemo.Create(Dialog);Memo.Parent:=Dialog;Memo.Align:=alClient;
    Memo.BorderSpacing.Around:=8;Memo.ReadOnly:=True;Memo.ScrollBars:=ssAutoBoth;Memo.WordWrap:=True;
    UseReadableInput(Memo);
    Memo.Text:=OriginalAuthorsText+LineEnding+LineEnding+
      AboutText('Linux port: TH911 / Dev-Cpp-Linux contributors','Linux 移植版：TH911 / Dev-Cpp-Linux 贡献者')+
      LineEnding+AppRepositoryUrl+LineEnding+LineEnding+
      AboutText('Historical contact addresses from the original language resources:',
        '原版语言资源中保留的历史联系地址：')+LineEnding+
      'Orwell: inseculous@users.sourceforge.net'+LineEnding+
      'Bloodshed: haiku@bloodshed.net';
    Dialog.ActiveControl:=Button;PrepareInputAppearance(Dialog);Dialog.ShowModal;
  finally Dialog.Free;end;
end;
constructor TAboutDialog.Create(AOwner:TComponent);
var Header,Footer:TPanel;Banner,Donate:TImage;Pages:TPageControl;
  AboutPage,DetailsPage:TTabSheet;Scroll:TScrollBox;LicenseGroup,Links:TGroupBox;
  LicenseMemo,DetailsMemo:TMemo;Button:TBitBtn;UpdateButton:TButton;
  LabelControl:TStaticText;Base,ExecutablePath,Distribution,Details:string;
  procedure LinkRow(const LabelText,URL:string;AY:Integer);
  var Link:TStaticText;
  begin
    LabelControl:=NativeText(Self,Links,Tr(LabelText),10,AY,175,18);LabelControl.Font.Size:=8;
    Link:=NativeText(Self,Links,URL,186,AY,330,18);Link.Name:='UserText_URL'+IntToStr(AY);
    Link.Font.Color:=clBlue;Link.Font.Style:=[fsUnderline];Link.Font.Size:=8;
    Link.Cursor:=crHandPoint;Link.Hint:=URL;Link.ShowHint:=True;
    Link.TabStop:=True;Link.OnClick:=@OpenLink;Link.OnKeyDown:=@LinkKey;
  end;
  procedure Heading(const Value:string;AY:Integer);
  begin LabelControl:=NativeText(Self,Links,Value,10,AY,500,18);LabelControl.Font.Style:=[fsBold];end;
  procedure Separator(AY:Integer);
  var Line:TBevel;
  begin Line:=TBevel.Create(Self);Line.Parent:=Links;Line.Shape:=bsTopLine;Line.SetBounds(10,AY,506,2);end;
  procedure LoadImage(Image:TImage;const FileName:string);
  begin if FileExists(Base+FileName) then Image.Picture.LoadFromFile(Base+FileName);end;
begin
  inherited CreateNew(AOwner,0);Caption:=Tr('About Dev-C++ :)');BorderStyle:=bsDialog;
  Position:=poMainFormCenter;ClientWidth:=560;ClientHeight:=Min(836,Screen.WorkAreaHeight-70);
  Color:=$00F0F0F0;
  Font.Name:='Sans';Font.Size:=9;Base:=ExtractFilePath(ParamStr(0))+'icons/';
  if FileExists(ExtractFilePath(ParamStr(0))+'devcpp.ico') then
    Icon.LoadFromFile(ExtractFilePath(ParamStr(0))+'devcpp.ico');
  Header:=TPanel.Create(Self);Header.Parent:=Self;Header.SetBounds(0,0,ClientWidth,144);
  Header.BevelOuter:=bvNone;Header.Color:=$00A77C55;
  Banner:=TImage.Create(Self);Banner.Parent:=Header;
  { Same 414x107 viewport as AboutFrm.dfm, uniformly enlarged to this dialog.
    The original bitmap is retained byte for byte, including its blue artwork. }
  Banner.SetBounds(0,-58,643,368);Banner.Stretch:=True;LoadImage(Banner,'about-banner.bmp');
  LabelControl:=NativeText(Self,Self,'Copyright (c) Bloodshed Software',10,151,290,18);LabelControl.Font.Style:=[fsBold];
  NativeText(Self,Self,'Orwell Dev-C++ 5.11',306,149,244,18);
  NativeText(Self,Self,'Build time: 2015-04-27 22:11',306,166,246,18);
  NativeText(Self,Self,Tr('Version')+' '+AppVersion+' / '+Tr('NOI Linux edition'),10,190,535,20);
  Footer:=TPanel.Create(Self);Footer.Parent:=Self;Footer.Align:=alBottom;Footer.Height:=43;Footer.BevelOuter:=bvNone;
  UpdateButton:=TButton.Create(Self);UpdateButton.Parent:=Footer;UpdateButton.SetBounds(10,7,200,28);
  UpdateButton.Caption:=Tr('&Check for updates');UpdateButton.Enabled:=False;
  Button:=TBitBtn.Create(Self);Button.Parent:=Footer;Button.SetBounds(334,7,104,28);
  Button.Caption:=Tr('&Authors');Button.OnClick:=@AuthorsClick;
  if FileExists(Base+'about-authors.bmp') then Button.Glyph.LoadFromFile(Base+'about-authors.bmp');
  Button:=TBitBtn.Create(Self);Button.Parent:=Footer;Button.SetBounds(446,7,104,28);
  ClassicOK(Button);Button.Caption:=Tr('&OK');Button.Cancel:=True;Button.ModalResult:=mrOK;
  ActiveControl:=Button;
  Pages:=TPageControl.Create(Self);Pages.Parent:=Self;Pages.SetBounds(8,218,544,ClientHeight-263);
  Pages.Anchors:=[akLeft,akTop,akRight,akBottom];
  AboutPage:=TTabSheet.Create(Self);AboutPage.PageControl:=Pages;AboutPage.Caption:=Tr('About');
  DetailsPage:=TTabSheet.Create(Self);DetailsPage.PageControl:=Pages;DetailsPage.Caption:=Tr('Build and installation');
  Scroll:=TScrollBox.Create(Self);Scroll.Parent:=AboutPage;Scroll.Align:=alClient;Scroll.BorderStyle:=bsNone;
  Scroll.HorzScrollBar.Visible:=False;Scroll.VertScrollBar.Tracking:=True;
  LicenseGroup:=TGroupBox.Create(Self);LicenseGroup.Parent:=Scroll;LicenseGroup.SetBounds(0,0,530,110);
  LicenseGroup.Caption:=Tr('GNU General Public License');
  LicenseMemo:=TMemo.Create(Self);LicenseMemo.Parent:=LicenseGroup;LicenseMemo.Align:=alClient;
  LicenseMemo.BorderSpacing.Around:=6;LicenseMemo.ReadOnly:=True;LicenseMemo.ScrollBars:=ssAutoBoth;
  LicenseMemo.WordWrap:=False;UseReadableInput(LicenseMemo);LicenseMemo.Text:=OriginalGPLText;
  Links:=TGroupBox.Create(Self);Links.Parent:=Scroll;Links.SetBounds(0,116,530,416);
  Links.Caption:=Tr('Contact Information');
  Heading(AboutText('Linux Dev-C++','Linux 版 Dev-C++')+' / '+AppVersion,16);
  LinkRow('Project repository:',AppRepositoryUrl,36);Separator(60);
  Heading(Tr('> 4.9.9.2')+' / Orwell Dev-C++ 5.11',68);
  LinkRow('Repository:',OrwellRepository,88);LinkRow('Subreddit:',OrwellReddit,106);LinkRow('Blog:',OrwellBlog,124);
  Donate:=TImage.Create(Self);Donate.Parent:=Links;Donate.SetBounds(10,145,92,26);
  LoadImage(Donate,'about-donate.bmp');Donate.Cursor:=crHandPoint;
  Donate.Hint:=OriginalDonate;Donate.ShowHint:=True;Donate.OnClick:=@OpenLink;
  NativeText(Self,Links,Tr('Please support Dev-C++ by making a donation:'),112,150,404,20);
  Separator(179);Heading(Tr('Compilers'),187);
  LinkRow('MinGW Compiler Website:',MinGWWebsite,207);LinkRow('TDM-GCC Compiler Website:',TDMWebsite,225);
  Separator(249);Heading(Tr('<= 4.9.9.2 (old stuff)'),257);
  LinkRow('Bloodshed Software Website:',BloodshedWebsite,279);
  LinkRow('Dev-C++ discussion forums:',BloodshedForum,297);
  LinkRow('Dev-C++ users mailing list:',BloodshedMailing,315);
  LinkRow('Authors e-mail:',BloodshedResources,333);
  NativeText(Self,Links,AboutText('Historical contacts / full credits: Authors',
    '历史联系地址及完整名单：见“作者”'),10,361,500,20);
  NativeText(Self,Links,AppLicense,10,385,500,20);
  ExecutablePath:=ExpandFileName(ParamStr(0));
  if ExtractFileDir(ExecutablePath)='/usr/lib/dev-cpp' then Distribution:=Tr('Debian package')
  else Distribution:=Tr('Directory build');
  Details:=AppName+' '+AppVersion+LineEnding+
    Tr('Installation:')+' '+Distribution+LineEnding+
    Tr('Executable:')+' '+ExecutablePath+LineEnding+
    Tr('Configuration:')+' '+ApplicationConfigFile+LineEnding+
    Tr('Compiler:')+' Free Pascal '+{$I %FPCVERSION%}+LineEnding+
    Tr('Platform:')+' '+{$I %FPCTARGETCPU%}+'-'+LowerCase({$I %FPCTARGETOS%})+' / GTK2'+LineEnding+
    Tr('Based on')+' '+AppUpstreamVersion+LineEnding+Tr('License:')+' '+AppLicense+LineEnding+AppRepositoryUrl+
    LineEnding+LineEnding+'Bloodshed Dev-C++ <= 4.9.9.2'+LineEnding+'Orwell Dev-C++ 5.11'+LineEnding+
    'Windows reference build: 2015-04-27 22:11'+LineEnding+OrwellRepository+LineEnding+OrwellReddit+
    LineEnding+OrwellBlog+LineEnding+MinGWWebsite+LineEnding+TDMWebsite+LineEnding+BloodshedWebsite+
    LineEnding+BloodshedForum+LineEnding+BloodshedMailing+LineEnding+BloodshedResources+LineEnding+
    OriginalDonate+LineEnding+LineEnding+OriginalAuthorsText+LineEnding+
    'Startup timing (this process):'+LineEnding+StartupReport;
  DetailsMemo:=TMemo.Create(Self);DetailsMemo.Parent:=DetailsPage;DetailsMemo.Align:=alClient;
  DetailsMemo.ReadOnly:=True;UseReadableInput(DetailsMemo);DetailsMemo.ScrollBars:=ssAutoBoth;
  DetailsMemo.WordWrap:=True;DetailsMemo.BorderSpacing.Around:=8;DetailsMemo.Text:=Details;
  PrepareInputAppearance(Self);
end;
procedure ShowAboutDialog(AOwner:TComponent);
var Dialog:TAboutDialog;
begin
  Dialog:=TAboutDialog.Create(AOwner);
  try Dialog.ShowModal;finally Dialog.Free;end;
end;
end.
