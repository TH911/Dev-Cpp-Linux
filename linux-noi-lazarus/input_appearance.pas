unit input_appearance;

{$mode objfpc}{$H+}

interface

uses Classes, Controls, Forms;

procedure UseReadableInput(Control: TWinControl);
procedure PrepareInputAppearance(Form: TForm);
procedure RefreshInputAppearance(Root:TComponent);

implementation

uses Graphics, StdCtrls
  {$IFDEF LCLgtk2}, Gtk2, Glib2, Gdk2{$ENDIF};

type
  TInputAccess = class(TWinControl);
  TInputAppearance = class(TComponent)
  private
    FPreviousShow: TNotifyEvent;
    procedure FormShown(Sender: TObject);
  end;

{$IFDEF LCLgtk2}
procedure StyleNativeInput(Widget: PGtkWidget; Data: gpointer); cdecl;
var Black: TGdkColor;
begin
  FillChar(Black, SizeOf(Black), 0);
  { LCL 2.0.6 SetFont changes NORMAL, ACTIVE and SELECTED together. Leave its
    font color at clDefault and override only NORMAL in the native widget. }
  gtk_widget_modify_text(Widget, GTK_STATE_NORMAL, @Black);
  gtk_widget_modify_fg(Widget, GTK_STATE_NORMAL, @Black);
  { TMemo.SetColor also overwrites ACTIVE base, used for unfocused selection. }
  gtk_widget_modify_base(Widget, GTK_STATE_ACTIVE, nil);
  gtk_widget_modify_base(Widget, GTK_STATE_SELECTED, nil);
  if GTK_IS_CONTAINER(Widget) then
    gtk_container_forall(GTK_CONTAINER(Widget), @StyleNativeInput, nil);
end;
{$ENDIF}

procedure UseReadableInput(Control: TWinControl);
begin
  { Match the original IDE's white fields independently of syntax themes.
    Keep native highlight and insensitive colors, Enabled and ReadOnly. }
  TInputAccess(Control).ParentFont := False;
  TInputAccess(Control).Color := clWhite;
  {$IFDEF LCLgtk2}
  TInputAccess(Control).Font.Color := clDefault;
  if Control.HandleAllocated then
    StyleNativeInput(PGtkWidget(Control.Handle), nil);
  {$ELSE}
  TInputAccess(Control).Font.Color := clBlack;
  {$ENDIF}
end;

procedure StyleFields(Root: TComponent);
var I: Integer;
begin
  if (Root is TCustomEdit) or (Root is TCustomComboBox) then
  begin
    TWinControl(Root).HandleNeeded;
    UseReadableInput(TWinControl(Root));
  end;
  for I := 0 to Root.ComponentCount - 1 do StyleFields(Root.Components[I]);
end;

procedure RefreshInputAppearance(Root:TComponent);
begin StyleFields(Root);end;

procedure TInputAppearance.FormShown(Sender: TObject);
begin
  if Assigned(FPreviousShow) then FPreviousShow(Sender);
  { ShowModal can recreate native controls while setting the transient parent.
    Apply after that recreation, when the form's final handles are available. }
  StyleFields(Owner);
end;

procedure PrepareInputAppearance(Form: TForm);
var Appearance: TInputAppearance;
begin
  Appearance := TInputAppearance.Create(Form);
  Appearance.FPreviousShow := Form.OnShow;
  Form.OnShow := @Appearance.FormShown;
end;

end.
