program command_state_test;

{$mode objfpc}{$H+}

uses Interfaces, Forms, Classes, SysUtils, ComCtrls, StdCtrls, ExtCtrls, Menus,
  mainform, app_instance, ui_language, language_catalog;

function Tool(Owner: TComponent; const Caption: string): TToolButton;
var I: Integer;
begin
  if (Owner is TToolButton) and (TToolButton(Owner).Caption = Caption) then
    Exit(TToolButton(Owner));
  for I := 0 to Owner.ComponentCount - 1 do
  begin
    Result := Tool(Owner.Components[I], Caption);
    if Result <> nil then Exit;
  end;
  Result := nil;
end;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then begin WriteLn(StdErr, 'FAIL: ', MessageText); Halt(1); end;
end;

var Form: TMainForm; I, J, Selected: Integer;
  NewButton, FindButton, SaveButton, CloseButton: TToolButton;
  LanguageMenu: TMenuItem; OriginalCode: string;
begin
  Application.Initialize;
  Check(PrepareInstance, 'initialize isolated test instance');
  Form := TMainForm.Create(nil);
  try
    Form.Show;
    Application.ProcessMessages;
    { Isolate immediate event-driven state from the 100ms fallback timer. }
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TTimer then TTimer(Form.Components[I]).Enabled := False;
    NewButton := Tool(Form, Tr('New Source File'));
    FindButton := Tool(Form, Tr('Find'));
    SaveButton := Tool(Form, Tr('Save'));
    CloseButton := Tool(Form, Tr('Close'));
    if (NewButton=nil) or (FindButton=nil) or (SaveButton=nil) or (CloseButton=nil) then begin
      WriteLn('Expected: ',Tr('New Source File'),' / ',Tr('Find'),' / ',Tr('Save'),' / ',Tr('Close'));
      for I:=0 to Form.ComponentCount-1 do if Form.Components[I] is TToolBar then
        with TToolBar(Form.Components[I]) do for J:=0 to ButtonCount-1 do WriteLn('Button: ',Buttons[J].Caption);
    end;
    Check((NewButton <> nil) and (FindButton <> nil) and
      (SaveButton <> nil) and (CloseButton <> nil), 'toolbar commands found');
    Check(not FindButton.Enabled and not SaveButton.Enabled, 'no-document command state');
    for I := 1 to 10 do
    begin
      NewButton.Click;
      Check(FindButton.Enabled, 'Find enabled immediately after New, before a timer tick');
      Check(SaveButton.Enabled, 'Save enabled immediately after New, before a timer tick');
      CloseButton.Click;
      Check(not FindButton.Enabled and not SaveButton.Enabled,
        'commands disabled immediately after closing the last document');
    end;
    WriteLn('PASS: immediate New/Find/Save/Close state over ten cycles without polling');
    LanguageMenu := nil;
    for I := 0 to Form.ComponentCount - 1 do
      if (Form.Components[I] is TMenuItem) and
        (TMenuItem(Form.Components[I]).Count = UiLanguageCount) then
        LanguageMenu := TMenuItem(Form.Components[I]);
    Check(LanguageMenu <> nil, 'real language menu has all 33 choices');
    OriginalCode := CurrentUiLanguage;
    for I := 0 to UiLanguageCount - 1 do
    begin
      LanguageMenu.Items[I].Click;
      Check(CurrentUiLanguage = UiLanguageCode(I), 'real menu selected language');
      Check(FindButton.Caption=Tr('Find'),'toolbar keeps its original action across language switches');
      for J:=0 to Form.ComponentCount-1 do
        if (Form.Components[J] is TMenuItem) and (TMenuItem(Form.Components[J]).ShortCut=121) then
          Check(TMenuItem(Form.Components[J]).Caption=Tr('&Run'),'F10 retains Run, not Execute, in each language');
      Check(Form.Menu.Items[0].Caption = Tr('&File'), 'real File menu translated correctly');
      Selected := 0;
      for J := 0 to UiLanguageCount - 1 do
        if LanguageMenu.Items[J].Checked then Inc(Selected);
      Check((Selected = 1) and LanguageMenu.Items[I].Checked, 'one checked language');
    end;
    for I := 0 to UiLanguageCount - 1 do
      if UiLanguageCode(I) = OriginalCode then LanguageMenu.Items[I].Click;
    WriteLn('PASS: all 33 real main-window language actions and radio states');
    NewButton.Click;
    NewButton.Click;
    { Finally frees a window with multiple live editors and focus callbacks. }
  finally Form.Free; end;
end.
