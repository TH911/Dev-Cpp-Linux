unit shortcut_dialog;
{$mode objfpc}{$H+}
interface
uses Classes;
function EditShortcutValues(AOwner:TComponent;Labels,Values,Defaults:TStrings):Boolean;
implementation
uses SysUtils,Forms,Controls,StdCtrls,ComCtrls,LCLType,LCLProc,Menus,ui_language,input_appearance;
type
  TShortcutForm=class(TForm)
  private
    FList:TListView;FDefaults:TStrings;
    procedure CaptureKey(Sender:TObject;var Key:Word;Shift:TShiftState);
    procedure ResetAll(Sender:TObject);
    procedure ResetSelected(Sender:TObject);
  public
    constructor CreateKeys(AOwner:TComponent;Labels,Values,Defaults:TStrings);
  end;
constructor TShortcutForm.CreateKeys(AOwner:TComponent;Labels,Values,Defaults:TStrings);
var I:Integer;B:TButton;L:TLabel;Item:TListItem;
begin
  inherited CreateNew(AOwner);Caption:=Tr('Shortcut Options');Position:=poMainFormCenter;BorderStyle:=bsDialog;
  ClientWidth:=720;ClientHeight:=530;Font.Name:='Sans';Font.Size:=9;FDefaults:=Defaults;
  FList:=TListView.Create(Self);FList.Parent:=Self;FList.SetBounds(10,10,700,426);FList.ViewStyle:=vsReport;FList.ReadOnly:=True;FList.RowSelect:=True;FList.HideSelection:=False;
  FList.Columns.Add.Caption:=Tr('Menu item');FList.Columns[0].Width:=535;FList.Columns.Add.Caption:=Tr('Shortcut');FList.Columns[1].Width:=140;
  for I:=0 to Labels.Count-1 do begin Item:=FList.Items.Add;Item.Caption:=Labels[I];Item.SubItems.Add(Values[I]);end;
  FList.OnKeyDown:=@CaptureKey;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(10,444,700,38);L.AutoSize:=False;L.WordWrap:=True;
  L.Caption:=Tr('Select a command and press its shortcut. Escape or Delete clears it. Use unique Ctrl/Alt or function keys.');
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(10,490,114,30);B.Caption:=Tr('Reset all');B.OnClick:=@ResetAll;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(132,490,154,30);B.Caption:=Tr('Reset selected');B.OnClick:=@ResetSelected;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(508,490,94,30);B.Caption:=Tr('OK');B.ModalResult:=mrOK;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(612,490,98,30);B.Caption:=Tr('Cancel');B.ModalResult:=mrCancel;
  if FList.Items.Count>0 then begin FList.Items[0].Selected:=True;FList.Items[0].Focused:=True;end;
  ActiveControl:=FList;PrepareInputAppearance(Self);
end;
procedure TShortcutForm.CaptureKey(Sender:TObject;var Key:Word;Shift:TShiftState);
var Sc:TShortCut;
begin
  if FList.Selected=nil then Exit;
  if (Shift=[]) and (Key in [VK_ESCAPE,VK_DELETE]) then begin FList.Selected.SubItems[0]:='';Key:=0;Exit;end;
  if (Key in [VK_CONTROL,VK_MENU,VK_SHIFT]) then Exit;
  if ((Shift*[ssCtrl,ssAlt])<>[]) or (Key in [VK_F1..VK_F12]) then begin
    Sc:=ShortCut(Key,Shift*[ssCtrl,ssAlt,ssShift]);FList.Selected.SubItems[0]:=ShortCutToText(Sc);Key:=0;
  end;
end;
procedure TShortcutForm.ResetAll(Sender:TObject);
var I:Integer;Sc:Integer;
begin
  for I:=0 to FList.Items.Count-1 do begin
    Sc:=StrToIntDef(FDefaults[I],0);if Sc=0 then FList.Items[I].SubItems[0]:='' else FList.Items[I].SubItems[0]:=ShortCutToText(Sc);
  end;
end;
procedure TShortcutForm.ResetSelected(Sender:TObject);
var Sc:Integer;
begin
  if FList.Selected=nil then Exit;Sc:=StrToIntDef(FDefaults[FList.Selected.Index],0);
  if Sc=0 then FList.Selected.SubItems[0]:='' else FList.Selected.SubItems[0]:=ShortCutToText(Sc);
end;
function EditShortcutValues(AOwner:TComponent;Labels,Values,Defaults:TStrings):Boolean;
var D:TShortcutForm;I:Integer;
begin
  D:=TShortcutForm.CreateKeys(AOwner,Labels,Values,Defaults);
  try Result:=D.ShowModal=mrOK;if Result then for I:=0 to Values.Count-1 do Values[I]:=D.FList.Items[I].SubItems[0];finally D.Free;end;
end;
end.
