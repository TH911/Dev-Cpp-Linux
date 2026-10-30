unit classic_checks;
{$mode objfpc}{$H+}
interface
procedure ConfigureClassicChecks;
implementation
uses Classes,SysUtils,Gtk2,Gdk2,Glib2;
type
  TDrawCheck=procedure(Style:PGtkStyle;Window:PGdkWindow;State:TGtkStateType;
    Shadow:TGtkShadowType;Area:PGdkRectangle;Widget:PGtkWidget;Detail:Pgchar;
    X,Y,W,H:gint);cdecl;
  TPatchedStyle=class
    StyleClass:PGtkStyleClass;
    Sample:PGtkStyle;
    Original:TDrawCheck;
  end;
var Styles:TList=nil;StyleSignal:guint=0;StyleHook:gulong=0;
procedure DrawClassicCheck(Style:PGtkStyle;Window:PGdkWindow;State:TGtkStateType;
  Shadow:TGtkShadowType;Area:PGdkRectangle;Widget:PGtkWidget;Detail:Pgchar;
  X,Y,W,H:gint);cdecl;
const Tick:array[0..6] of string=('.......#','......##','.....##.','#...##..','##.##...','.###....','..#.....');
var GC:PGdkGC;C:TGdkColor;I,J,L,T:Integer;MenuCheck:Boolean;Saved:TPatchedStyle;
  procedure Color(R,G,B:Word);
  begin C.pixel:=0;C.red:=R*257;C.green:=G*257;C.blue:=B*257;gdk_gc_set_rgb_fg_color(GC,@C);end;
begin
  if (Widget=nil) or not (GTK_IS_CHECK_BUTTON(Widget) or GTK_IS_CHECK_MENU_ITEM(Widget) or
    ((Detail<>nil) and (string(Detail)='cellcheck'))) then begin
    for I:=0 to Styles.Count-1 do begin
      Saved:=TPatchedStyle(Styles[I]);
      if Saved.StyleClass=GTK_STYLE_GET_CLASS(Style) then begin
        if Assigned(Saved.Original) then Saved.Original(Style,Window,State,Shadow,Area,Widget,Detail,X,Y,W,H);
        Exit;
      end;
    end;Exit;
  end;
  if (Window=nil) or (W<=0) or (H<=0) then Exit;
  GC:=gdk_gc_new(Window);
  try
    if Area<>nil then gdk_gc_set_clip_rectangle(GC,Area);
    MenuCheck:=GTK_IS_CHECK_MENU_ITEM(Widget);L:=X+(W-13) div 2;T:=Y+(H-13) div 2;
    if not MenuCheck then begin
      if State=GTK_STATE_INSENSITIVE then Color(240,240,240) else Color(255,255,255);
      gdk_draw_rectangle(Window,GC,1,L,T,13,13);
      if State=GTK_STATE_PRELIGHT then Color(0,120,215) else Color(112,112,112);
      gdk_draw_rectangle(Window,GC,0,L,T,12,12);
    end;
    if State=GTK_STATE_INSENSITIVE then Color(128,128,128) else Color(0,0,0);
    if Shadow=GTK_SHADOW_ETCHED_IN then gdk_draw_rectangle(Window,GC,1,L+3,T+5,7,3)
    else if Shadow=GTK_SHADOW_IN then
      for I:=0 to 6 do for J:=1 to 8 do if Tick[I][J]='#' then
        gdk_draw_point(Window,GC,L+2+J-1,T+3+I);
  finally g_object_unref(GC);end;
end;
procedure PatchStyle(Style:PGtkStyle);
var I:Integer;K:PGtkStyleClass;Saved:TPatchedStyle;
begin
  if Style=nil then Exit;K:=GTK_STYLE_GET_CLASS(Style);
  for I:=0 to Styles.Count-1 do if TPatchedStyle(Styles[I]).StyleClass=K then Exit;
  Saved:=TPatchedStyle.Create;Saved.StyleClass:=K;Saved.Original:=K^.draw_check;
  { A theme subclass may inherit our already-patched base callback. }
  if Pointer(Saved.Original)=Pointer(@DrawClassicCheck) then
    if Styles.Count>0 then Saved.Original:=TPatchedStyle(Styles[0]).Original;
  Saved.Sample:=PGtkStyle(g_object_ref(Style));
  Styles.Add(Saved);K^.draw_check:=@DrawClassicCheck;
end;
function StyleChanged(Hint:PGSignalInvocationHint;Count:guint;Values:PGValue;Data:gpointer):gboolean;cdecl;
var Widget:PGtkWidget;
begin
  Result:=True;if Count=0 then Exit;
  Widget:=PGtkWidget(g_value_get_object(Values));
  if Widget<>nil then PatchStyle(gtk_widget_get_style(Widget));
end;
procedure ConfigureClassicChecks;
var Style:PGtkStyle;
begin
  if Styles<>nil then Exit;Styles:=TList.Create;
  Style:=gtk_style_new;try PatchStyle(Style);finally g_object_unref(Style);end;
  StyleSignal:=g_signal_lookup('style-set',gtk_widget_get_type);
  if StyleSignal<>0 then StyleHook:=g_signal_add_emission_hook(StyleSignal,0,@StyleChanged,nil,nil);
end;
procedure ReleaseStyles;
var I:Integer;Saved:TPatchedStyle;
begin
  if StyleHook<>0 then g_signal_remove_emission_hook(StyleSignal,StyleHook);
  if Styles=nil then Exit;
  for I:=Styles.Count-1 downto 0 do begin
    Saved:=TPatchedStyle(Styles[I]);Saved.StyleClass^.draw_check:=Saved.Original;g_object_unref(Saved.Sample);Saved.Free;
  end;
  FreeAndNil(Styles);
end;
finalization
  ReleaseStyles;
end.
