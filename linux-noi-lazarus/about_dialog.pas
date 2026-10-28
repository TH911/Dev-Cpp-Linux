unit about_dialog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes;

procedure ShowAboutDialog(AOwner: TComponent);

implementation

uses SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Graphics,
  Dialogs, LCLIntf, LCLType, ui_language, app_version, input_appearance, app_paths;

type
  TAboutDialog = class(TForm)
  private
    FDetails: string;
    procedure OpenRepository(Sender: TObject);
    procedure RepositoryKey(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent); override;
  end;

constructor TAboutDialog.Create(AOwner: TComponent);
var
  Logo: TImage;
  LabelControl, RepositoryLink: TStaticText;
  Pages: TPageControl;
  AboutPage, DetailsPage: TTabSheet;
  DetailsMemo: TMemo;
  Button: TButton;
  ExecutablePath, Distribution, IconPath: string;

  function TextAt(ParentControl: TWinControl; const Text: string;
    X, Y, AWidth, AHeight: Integer): TStaticText;
  begin
    { Native text widgets expose the displayed version and links to desktop
      accessibility tools, in addition to preserving the classic layout. }
    Result := TStaticText.Create(Self);
    Result.Parent := ParentControl;
    Result.AutoSize := False;
    Result.SetBounds(X, Y, AWidth, AHeight);
    Result.Caption := Text;
  end;

begin
  inherited CreateNew(AOwner, 0);
  Caption := Tr('About') + ' ' + AppName;
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  ClientWidth := 600;
  ClientHeight := 432;
  Font.Name := 'Sans';
  Font.Size := 9;

  Logo := TImage.Create(Self);
  Logo.Parent := Self;
  Logo.SetBounds(20, 22, 64, 64);
  Logo.Proportional := True;
  Logo.Center := True;
  IconPath := ExtractFilePath(ParamStr(0)) + 'devcpp.ico';
  if FileExists(IconPath) then
    try
      Logo.Picture.LoadFromFile(IconPath);
      Icon.LoadFromFile(IconPath);
    except
      { A missing desktop icon must not hide version and diagnostic details. }
    end;
  LabelControl := TextAt(Self, AppName, 104, 18, 470, 32);
  LabelControl.Font.Size := 18;
  LabelControl.Font.Style := [fsBold];
  TextAt(Self, Tr('NOI Linux edition'), 106, 54, 468, 22);
  TextAt(Self, Tr('Version') + ' ' + AppVersion, 106, 78, 468, 22);

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.SetBounds(20, 118, 560, 244);
  AboutPage := TTabSheet.Create(Self);
  AboutPage.PageControl := Pages;
  AboutPage.Caption := Tr('About');
  DetailsPage := TTabSheet.Create(Self);
  DetailsPage.PageControl := Pages;
  DetailsPage.Caption := Tr('Build and installation');
  TextAt(AboutPage, Tr('Based on') + ' ' + AppUpstreamVersion,
    14, 16, 520, 24);
  TextAt(AboutPage, Tr('License:') + ' ' + AppLicense,
    14, 46, 520, 24);
  TextAt(AboutPage, Tr('Project repository:'), 14, 80, 520, 22);
  RepositoryLink := TextAt(AboutPage, AppRepositoryUrl, 14, 104, 520, 26);
  RepositoryLink.Font.Color := clBlue;
  RepositoryLink.Font.Style := [fsUnderline];
  RepositoryLink.Cursor := crHandPoint;
  RepositoryLink.Hint := AppRepositoryUrl;
  RepositoryLink.ShowHint := True;
  RepositoryLink.OnClick := @OpenRepository;
  RepositoryLink.TabStop := True;
  RepositoryLink.OnKeyDown := @RepositoryKey;
  TextAt(AboutPage, Tr('Native GTK2 IDE for NOI Linux 2.0.'),
    14, 154, 520, 42);

  ExecutablePath := ExpandFileName(ParamStr(0));
  if ExtractFileDir(ExecutablePath) = '/usr/lib/dev-cpp-linux' then
    Distribution := Tr('Debian package')
  else Distribution := Tr('Directory build');
  FDetails := AppName + ' ' + AppVersion + LineEnding +
    Tr('Installation:') + ' ' + Distribution + LineEnding +
    Tr('Executable:') + ' ' + ExecutablePath + LineEnding +
    Tr('Configuration:') + ' ' + ApplicationConfigFile + LineEnding +
    Tr('Compiler:') + ' Free Pascal ' + {$I %FPCVERSION%} + LineEnding +
    Tr('Platform:') + ' ' + {$I %FPCTARGETCPU%} + '-' +
      LowerCase({$I %FPCTARGETOS%}) + ' / GTK2' + LineEnding +
    Tr('Based on') + ' ' + AppUpstreamVersion + LineEnding +
    Tr('License:') + ' ' + AppLicense + LineEnding + AppRepositoryUrl;
  DetailsMemo := TMemo.Create(Self);
  DetailsMemo.Parent := DetailsPage;
  DetailsMemo.Align := alClient;
  DetailsMemo.ReadOnly := True;
  UseReadableInput(DetailsMemo);
  DetailsMemo.ScrollBars := ssAutoBoth;
  DetailsMemo.WordWrap := True;
  DetailsMemo.BorderSpacing.Around := 8;
  DetailsMemo.Text := FDetails;

  Button := TButton.Create(Self);
  Button.Parent := Self;
  Button.SetBounds(490, 382, 90, 32);
  Button.Caption := Tr('OK');
  Button.Default := True;
  Button.Cancel := True;
  Button.ModalResult := mrOK;
  ActiveControl := Button;
  PrepareInputAppearance(Self);
end;

procedure TAboutDialog.OpenRepository(Sender: TObject);
begin
  if not OpenURL(AppRepositoryUrl) then
    UiMessageDlg(Tr('Could not open the project repository.') + LineEnding +
      AppRepositoryUrl, mtError, [mbOK], 0);
end;

procedure TAboutDialog.RepositoryKey(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key in [VK_RETURN, VK_SPACE]) and (Shift = []) then
  begin
    Key := 0;
    OpenRepository(Sender);
  end;
end;

procedure ShowAboutDialog(AOwner: TComponent);
var Dialog: TAboutDialog;
begin
  Dialog := TAboutDialog.Create(AOwner);
  try
    Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

end.
