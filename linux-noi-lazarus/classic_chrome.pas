unit classic_chrome;
{$mode objfpc}{$H+}
interface
procedure ConfigureClassicChrome;
implementation
{$IFDEF LCLgtk2}
uses Gtk2,classic_checks;
var Configured: Boolean = False;
{$ENDIF}
procedure ConfigureClassicChrome;
begin
  {$IFDEF LCLgtk2}
  if Configured then Exit;
  Configured := True;
  ConfigureClassicChecks;
  { Application-local chrome. Keep native selection/disabled states and entry
    base colors; the editor's syntax palettes are independent of this style. }
  gtk_rc_parse_string('gtk-button-images = 1 gtk-menu-images = 1 ' +
    'style "devcpp-classic-chrome" {' +
    ' font_name = "Sans 9" bg[NORMAL] = "#f0f0f0" fg[NORMAL] = "#000000" ' +
    ' xthickness = 1 ythickness = 1 } ' +
    'class "GtkWidget" style "devcpp-classic-chrome" ' +
    'style "devcpp-document-tabs" {' +
    ' GtkWidget::focus-line-width = 0 GtkWidget::focus-padding = 0 } ' +
    'widget "*.devcpp-document-tabs" style "devcpp-document-tabs" ' +
    'style "devcpp-sidebar-caption" { xthickness = 0 ythickness = 0 } ' +
    'widget "*.devcpp-sidebar-caption" style "devcpp-sidebar-caption"');
  {$ENDIF}
end;
end.
