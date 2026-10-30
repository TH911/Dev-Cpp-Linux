unit search_dialog;
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TSearchMode=(smFind,smFindFiles,smReplace,smReplaceFiles);
  TSearchScope=(scCurrent,scOpen,scProject);
  TClassicSearchSpec=record
    Mode:TSearchMode;Scope:TSearchScope;
    Query,Replacement:string;
    MatchCase,WholeWord,Backward,SelectedOnly,FromCaret,Prompt:Boolean;
  end;
function EditSearch(Owner:TComponent;var Spec:TClassicSearchSpec;HasSelection,HasProject:Boolean):Boolean;
implementation
uses SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, LCLType,
  ui_language,input_appearance;
type
  TSearchForm=class(TForm)
  private
    FTab:TTabControl;
    FQuery,FReplacement:TComboBox;
    FReplacementLabel:TLabel;
    FCase,FWord,FPrompt:TCheckBox;
    FForward,FBackward,FAll,FSelected,FCaret,FTop,FProject,FOpen,FCurrent:TRadioButton;
    FOptions,FDirection,FArea,FOrigin,FScope:TGroupBox;
    FAccept:TButton;
    procedure Changed(Sender:TObject);
    procedure Accept(Sender:TObject);
  protected
    procedure KeyDown(var Key:Word;Shift:TShiftState);override;
  public
    constructor CreateSearch(AOwner:TComponent;const Spec:TClassicSearchSpec;HasSelection,HasProject:Boolean);
    procedure ReadSpec(var Spec:TClassicSearchSpec);
  end;
var QueryHistory,ReplaceHistory:TStringList;
procedure Remember(List:TStringList;const Value:string);
var I:Integer;
begin I:=List.IndexOf(Value);if I>=0 then List.Delete(I);List.Insert(0,Value);while List.Count>20 do List.Delete(List.Count-1);end;
constructor TSearchForm.CreateSearch(AOwner:TComponent;const Spec:TClassicSearchSpec;HasSelection,HasProject:Boolean);
var L:TLabel;B:TButton;
  function Box(const Title:string;X,Y,W,H:Integer):TGroupBox;
  begin Result:=TGroupBox.Create(Self);Result.Parent:=Self;Result.Caption:=Tr(Title);Result.SetBounds(X,Y,W,H);end;
  function Check(Parent:TWinControl;const Text:string;Y:Integer;Value:Boolean):TCheckBox;
  begin Result:=TCheckBox.Create(Self);Result.Parent:=Parent;Result.Caption:=Tr(Text);Result.SetBounds(8,Y,Parent.Width-16,23);Result.Checked:=Value;end;
  function Radio(Parent:TWinControl;const Text:string;Y:Integer;Value:Boolean):TRadioButton;
  begin Result:=TRadioButton.Create(Self);Result.Parent:=Parent;Result.Caption:=Tr(Text);Result.SetBounds(8,Y,Parent.Width-16,23);Result.Checked:=Value;end;
begin
  inherited CreateNew(AOwner);BorderStyle:=bsDialog;Position:=poMainFormCenter;
  ClientWidth:=440;ClientHeight:=360;Font.Name:='Sans';Font.Size:=9;
  FTab:=TTabControl.Create(Self);FTab.Parent:=Self;FTab.SetBounds(0,0,440,30);
  FTab.Tabs.Add(Tr('Search'));FTab.Tabs.Add(Tr('Search in files'));FTab.Tabs.Add(Tr('Replace'));FTab.Tabs.Add(Tr('Replace in files'));
  FTab.TabIndex:=Ord(Spec.Mode);FTab.OnChange:=@Changed;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(10,35,420,19);L.Caption:=Tr('Find:');
  FQuery:=TComboBox.Create(Self);FQuery.Parent:=Self;FQuery.SetBounds(10,54,420,28);FQuery.Items.Assign(QueryHistory);FQuery.Text:=Spec.Query;FQuery.OnChange:=@Changed;
  FReplacementLabel:=TLabel.Create(Self);FReplacementLabel.Parent:=Self;FReplacementLabel.SetBounds(10,84,420,19);FReplacementLabel.Caption:=Tr('Replace with:');
  FReplacement:=TComboBox.Create(Self);FReplacement.Parent:=Self;FReplacement.SetBounds(10,103,420,28);FReplacement.Items.Assign(ReplaceHistory);FReplacement.Text:=Spec.Replacement;
  { GTK2 group boxes already exclude the caption from their client area. }
  FOptions:=Box('Options',10,134,200,100);FCase:=Check(FOptions,'Case sensitive',0,Spec.MatchCase);FWord:=Check(FOptions,'Whole words',23,Spec.WholeWord);FPrompt:=Check(FOptions,'Prompt before replacing',46,Spec.Prompt);
  FDirection:=Box('Direction',230,134,200,100);FForward:=Radio(FDirection,'Forward',0,not Spec.Backward);FBackward:=Radio(FDirection,'Backward',23,Spec.Backward);
  FArea:=Box('Search scope',10,244,200,78);FAll:=Radio(FArea,'All text',0,not Spec.SelectedOnly);FSelected:=Radio(FArea,'Selected text',23,Spec.SelectedOnly and HasSelection);FSelected.Enabled:=HasSelection;
  FOrigin:=Box('Origin',230,244,200,78);FCaret:=Radio(FOrigin,'From caret',0,Spec.FromCaret);FTop:=Radio(FOrigin,'From start',23,not Spec.FromCaret);
  FScope:=Box('Search in',230,134,200,100);FProject:=Radio(FScope,'Project files',0,Spec.Scope=scProject);FProject.Enabled:=HasProject;
  FOpen:=Radio(FScope,'Open files',23,Spec.Scope=scOpen);FCurrent:=Radio(FScope,'Current file',46,Spec.Scope=scCurrent);
  if not HasProject and FProject.Checked then FOpen.Checked:=True;
  FAccept:=TButton.Create(Self);FAccept.Parent:=Self;FAccept.SetBounds(10,326,105,28);FAccept.Default:=True;FAccept.OnClick:=@Accept;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(325,326,105,28);B.Caption:=Tr('Cancel');B.Cancel:=True;B.ModalResult:=mrCancel;
  ActiveControl:=FQuery;Changed(Self);PrepareInputAppearance(Self);
end;
procedure TSearchForm.Changed(Sender:TObject);
var Replacing,Files:Boolean;
begin
  Replacing:=FTab.TabIndex>=2;Files:=(FTab.TabIndex mod 2)=1;
  FReplacement.Visible:=Replacing;FReplacementLabel.Visible:=Replacing;
  if Replacing then begin Caption:=Tr('Replace');FAccept.Caption:=Tr('Replace');end
  else begin Caption:=Tr('Search');FAccept.Caption:=Tr('Search');end;
  FPrompt.Enabled:=Replacing;FDirection.Visible:=not Files;FArea.Visible:=not Files;FOrigin.Visible:=not Files;FScope.Visible:=Files;
  FAccept.Enabled:=FQuery.Text<>'';
end;
procedure TSearchForm.Accept(Sender:TObject);
begin if FQuery.Text<>'' then ModalResult:=mrOK;end;
procedure TSearchForm.KeyDown(var Key:Word;Shift:TShiftState);
begin
  if (Key=VK_ESCAPE) and (Shift=[]) then begin ModalResult:=mrCancel;Key:=0;Exit;end;
  inherited KeyDown(Key,Shift);
end;
procedure TSearchForm.ReadSpec(var Spec:TClassicSearchSpec);
begin
  Spec.Mode:=TSearchMode(FTab.TabIndex);Spec.Query:=FQuery.Text;Spec.Replacement:=FReplacement.Text;
  Spec.MatchCase:=FCase.Checked;Spec.WholeWord:=FWord.Checked;Spec.Prompt:=FPrompt.Checked;
  Spec.Backward:=FBackward.Checked;Spec.SelectedOnly:=FSelected.Checked;Spec.FromCaret:=FCaret.Checked;
  if (FTab.TabIndex mod 2)=1 then begin Spec.SelectedOnly:=False;Spec.FromCaret:=False;end;
  if FProject.Checked then Spec.Scope:=scProject else if FOpen.Checked then Spec.Scope:=scOpen else Spec.Scope:=scCurrent;
end;
function EditSearch(Owner:TComponent;var Spec:TClassicSearchSpec;HasSelection,HasProject:Boolean):Boolean;
var D:TSearchForm;
begin
  if QueryHistory=nil then begin QueryHistory:=TStringList.Create;ReplaceHistory:=TStringList.Create;end;
  D:=TSearchForm.CreateSearch(Owner,Spec,HasSelection,HasProject);
  try
    Result:=D.ShowModal=mrOK;
    if Result then begin D.ReadSpec(Spec);Remember(QueryHistory,Spec.Query);if Spec.Mode>=smReplace then Remember(ReplaceHistory,Spec.Replacement);end;
  finally D.Free;end;
end;
finalization
  QueryHistory.Free;ReplaceHistory.Free;
end.
