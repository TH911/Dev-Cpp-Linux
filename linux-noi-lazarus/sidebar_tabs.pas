unit sidebar_tabs;
{$mode objfpc}{$H+}
interface
uses Classes,Types,Controls,StdCtrls,Graphics;
type
  TSidebarCaption=class(TStaticText)
  protected
    procedure CreateWnd;override;
  end;
  TSidebarArrow=class(TCustomControl)
  private
    FDown,FHot:Boolean;
  protected
    procedure CreateWnd;override;
    procedure Paint;override;
    procedure MouseDown(Button:TMouseButton;Shift:TShiftState;X,Y:Integer);override;
    procedure MouseUp(Button:TMouseButton;Shift:TShiftState;X,Y:Integer);override;
    procedure MouseMove(Shift:TShiftState;X,Y:Integer);override;
    procedure MouseEnter;override;
    procedure MouseLeave;override;
  public
    constructor Create(AOwner:TComponent);override;
    procedure Click;override;
  end;
  TSidebarTabs=class(TCustomControl)
  private
    FLabels:array[0..2] of TStaticText;
    FArrows:array[0..1] of TSidebarArrow;
    FRects:array[0..2] of TRect;
    FWidths:array[0..2] of Integer;
    FFirst,FActive:Integer;
    FUpdating:Boolean;
    FOnSelect,FOnScroll:TNotifyEvent;
    procedure LabelClick(Sender:TObject);
    procedure ArrowClick(Sender:TObject);
    procedure SetFirst(Value:Integer);
    procedure SetActive(Value:Integer);
    procedure LayoutTabs;
    function TabFullyVisible(Index:Integer):Boolean;
    procedure SelectTab(Value:Integer);
  protected
    procedure Paint;override;
    procedure Resize;override;
    procedure FontChanged(Sender:TObject);override;
    procedure MouseDown(Button:TMouseButton;Shift:TShiftState;X,Y:Integer);override;
    procedure KeyDown(var Key:Word;Shift:TShiftState);override;
  public
    constructor Create(AOwner:TComponent);override;
    property FirstVisible:Integer read FFirst write SetFirst;
    property ActiveIndex:Integer read FActive write SetActive;
    property OnSelect:TNotifyEvent read FOnSelect write FOnSelect;
    property OnScroll:TNotifyEvent read FOnScroll write FOnScroll;
  end;
implementation
uses SysUtils,Math,LCLType,ui_language {$IFDEF LCLgtk2},Gtk2,Atk,Pango{$ENDIF};
procedure CaptionSize(LabelControl:TStaticText;out AWidth,AHeight:Integer);
{$IFDEF LCLgtk2}
var Frame,NativeLabel:PGtkWidget;
{$ENDIF}
begin
  {$IFDEF LCLgtk2}
  { Ask the inner label, not the outer LCL frame: its preferred-size query
    includes the frame's currently allocated child size on GTK2. }
  Frame:=PGtkWidget(LabelControl.Handle);
  NativeLabel:=gtk_bin_get_child(PGtkBin(gtk_bin_get_child(PGtkBin(Frame))));
  pango_layout_get_pixel_size(gtk_label_get_layout(PGtkLabel(NativeLabel)),@AWidth,@AHeight);
  {$ELSE}
  LabelControl.GetPreferredSize(AWidth,AHeight);
  {$ENDIF}
end;
procedure TSidebarCaption.CreateWnd;
begin
  inherited CreateWnd;
  {$IFDEF LCLgtk2}
  gtk_widget_set_name(PGtkWidget(Handle),'devcpp-sidebar-caption');
  {$ENDIF}
end;
constructor TSidebarArrow.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  ControlStyle:=ControlStyle+[csOpaque,csClickEvents,csCaptureMouse];
  Width:=18;Height:=18;TabStop:=False;DoubleBuffered:=True;
end;
procedure TSidebarArrow.CreateWnd;
var Widget:PGtkWidget;S:string;
begin
  inherited CreateWnd;
  {$IFDEF LCLgtk2}
  Widget:=PGtkWidget(Handle);
  if Tag=0 then S:='devcpp-sidebar-left' else S:='devcpp-sidebar-right';
  gtk_widget_set_name(Widget,PChar(S));
  atk_object_set_name(gtk_widget_get_accessible(Widget),PChar(Hint));
  atk_object_set_role(gtk_widget_get_accessible(Widget),ATK_ROLE_PUSH_BUTTON);
  {$ENDIF}
end;
procedure TSidebarArrow.Paint;
var X,Y,D:Integer;Face,Border:TColor;
begin
  Face:=$00F0F0F0;Border:=$00A0A0A0;D:=0;
  if Enabled and FHot then begin Face:=$00FBF1E5;Border:=$00D77800;end;
  if Enabled and FDown and FHot then begin Face:=$00F7E4CC;D:=1;end;
  Canvas.Brush.Color:=Face;Canvas.FillRect(ClientRect);
  Canvas.Pen.Color:=Border;Canvas.Rectangle(0,0,Width,Height);
  if not (Enabled and FHot) then begin
    Canvas.Pen.Color:=clWhite;Canvas.Line(1,1,Width-1,1);Canvas.Line(1,1,1,Height-1);
  end;
  X:=(Width-1) div 2+D;Y:=(Height-1) div 2+D;
  Canvas.Pen.Color:=clBlack;
  { The original up/down control uses a three-column, five-pixel triangle. }
  if Tag=0 then begin
    Canvas.Line(X-1,Y,X,Y);Canvas.Line(X,Y-1,X,Y+2);Canvas.Line(X+1,Y-2,X+1,Y+3);
  end else begin
    Canvas.Line(X-1,Y-2,X-1,Y+3);Canvas.Line(X,Y-1,X,Y+2);Canvas.Line(X+1,Y,X+2,Y);
  end;
end;
procedure TSidebarArrow.MouseDown(Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
begin
  if (Button=mbLeft) and Enabled then begin FDown:=True;FHot:=True;Invalidate;end;
  inherited MouseDown(Button,Shift,X,Y);
end;
procedure TSidebarArrow.MouseUp(Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
begin
  if Button=mbLeft then begin FDown:=False;Invalidate;end;
  inherited MouseUp(Button,Shift,X,Y);
end;
procedure TSidebarArrow.MouseMove(Shift:TShiftState;X,Y:Integer);
var Hot:Boolean;
begin
  Hot:=PtInRect(ClientRect,Point(X,Y));
  if Hot<>FHot then begin FHot:=Hot;Invalidate;end;
  inherited MouseMove(Shift,X,Y);
end;
procedure TSidebarArrow.MouseEnter;
begin inherited MouseEnter;FHot:=True;Invalidate;end;
procedure TSidebarArrow.MouseLeave;
begin inherited MouseLeave;FHot:=False;Invalidate;end;
procedure TSidebarArrow.Click;
begin if Enabled then inherited Click;end;
constructor TSidebarTabs.Create(AOwner:TComponent);
const Names:array[0..2] of string=('Project','Classes','Debug');
var I:Integer;
begin
  inherited Create(AOwner);Height:=22;Width:=160;TabStop:=True;
  for I:=0 to 2 do begin
    FLabels[I]:=TSidebarCaption.Create(Self);FLabels[I].Parent:=Self;
    FLabels[I].AutoSize:=False;FLabels[I].Alignment:=taCenter;FLabels[I].ParentColor:=False;
    FLabels[I].Tag:=I;FLabels[I].OnClick:=@LabelClick;
    SetUiProperty(FLabels[I],'Caption',Names[I]);
  end;
  for I:=0 to 1 do begin
    FArrows[I]:=TSidebarArrow.Create(Self);FArrows[I].Tag:=I;
    FArrows[I].Hint:=Tr('Scroll sidebar tabs');FArrows[I].Parent:=Self;
    FArrows[I].Hint:=Tr('Scroll sidebar tabs');FArrows[I].ShowHint:=True;
    FArrows[I].OnClick:=@ArrowClick;
  end;
end;
procedure TSidebarTabs.LayoutTabs;
var I,X,Space,TabTop,TextWidth,TextHeight,NeededHeight:Integer;
begin
  if FUpdating or (FLabels[2]=nil) or (FArrows[1]=nil) then Exit;
  FUpdating:=True;
  try
  Canvas.Font.Assign(Font);NeededHeight:=22;
  for I:=0 to 2 do begin
    CaptionSize(FLabels[I],TextWidth,TextHeight);
    FWidths[I]:=Max(TextWidth,Canvas.TextWidth(FLabels[I].Caption))+12;
    NeededHeight:=Max(NeededHeight,TextHeight+4);
  end;
  { The label's GTK frame has no theme padding. Keep enough height for its
    actual text plus the inactive tab's two-pixel offset and two insets. }
  if Height<>NeededHeight then Height:=NeededHeight;
  Space:=Max(0,ClientWidth-36);
  for I:=0 to 1 do begin
    FArrows[I].Visible:=True;
    FArrows[I].SetBounds(Max(0,ClientWidth-36)+I*18,(ClientHeight-18) div 2,18,18);
  end;
  X:=0;
  for I:=0 to 2 do begin
    FRects[I]:=Rect(0,0,0,0);
    FLabels[I].Visible:=(I>=FFirst) and (I<FFirst+2) and (X+8<Space) and
      ((X+FWidths[I]<=Space) or (I=FFirst));
    if not FLabels[I].Visible then Continue;
    TabTop:=2;if I=FActive then TabTop:=0;
    if I=FActive then FLabels[I].Color:=clWhite else FLabels[I].Color:=$00F0F0F0;
    FRects[I]:=Rect(X,TabTop,Min(X+FWidths[I],Space),ClientHeight);
    FLabels[I].SetBounds(X+4,TabTop+1,Max(0,FRects[I].Right-X-8),Max(0,ClientHeight-TabTop-2));
    Inc(X,FWidths[I]);
  end;
  FArrows[0].Enabled:=FFirst>0;
  FArrows[1].Enabled:=(FFirst<2) and not TabFullyVisible(2);
  finally FUpdating:=False;end;
end;
function TSidebarTabs.TabFullyVisible(Index:Integer):Boolean;
begin
  Result:=FLabels[Index].Visible and
    (FRects[Index].Right-FRects[Index].Left>=FWidths[Index]);
end;
procedure TSidebarTabs.Paint;
var I,L,T,R,B:Integer;Fill:TColor;
begin
  LayoutTabs;Canvas.Brush.Color:=$00F0F0F0;Canvas.FillRect(ClientRect);
  Canvas.Pen.Color:=$00A0A0A0;Canvas.Line(0,ClientHeight-1,ClientWidth,ClientHeight-1);
  for I:=0 to 2 do if FLabels[I].Visible then begin
    L:=FRects[I].Left;T:=FRects[I].Top;R:=FRects[I].Right-1;B:=ClientHeight-1;
    Fill:=$00F0F0F0;if I=FActive then Fill:=clWhite;
    Canvas.Brush.Color:=Fill;Canvas.FillRect(L+1,T+2,R,B);
    Canvas.Pen.Color:=clWhite;Canvas.Line(L,T+2,L,B);Canvas.Line(L+2,T,R-1,T);
    Canvas.Line(L,T+2,L+2,T);Canvas.Pen.Color:=$00A0A0A0;
    Canvas.Line(R-1,T,R,T+2);Canvas.Line(R,T+2,R,B);
    if I=FActive then begin Canvas.Pen.Color:=clWhite;Canvas.Line(L+1,B,R,B);end;
  end;
end;
procedure TSidebarTabs.Resize;
begin inherited Resize;if FLabels[2]<>nil then LayoutTabs;Invalidate;end;
procedure TSidebarTabs.FontChanged(Sender:TObject);
begin inherited FontChanged(Sender);LayoutTabs;Invalidate;end;
procedure TSidebarTabs.SetFirst(Value:Integer);
begin FFirst:=EnsureRange(Value,0,2);LayoutTabs;Invalidate;end;
procedure TSidebarTabs.SetActive(Value:Integer);
begin
  Value:=EnsureRange(Value,0,2);if Value=FActive then Exit;
  FActive:=Value;LayoutTabs;
  if Value<FFirst then SetFirst(Value);
  while not TabFullyVisible(Value) and (FFirst<Value) do SetFirst(FFirst+1);
  Invalidate;
end;
procedure TSidebarTabs.SelectTab(Value:Integer);
begin SetFocus;SetActive(Value);if Assigned(FOnSelect) then FOnSelect(Self);end;
procedure TSidebarTabs.LabelClick(Sender:TObject);
begin SelectTab(TControl(Sender).Tag);end;
procedure TSidebarTabs.ArrowClick(Sender:TObject);
begin
  if TControl(Sender).Tag=0 then SetFirst(FFirst-1)
  else if not TabFullyVisible(2) then SetFirst(FFirst+1);
  if Assigned(FOnScroll) then FOnScroll(Self);
end;
procedure TSidebarTabs.MouseDown(Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
var I:Integer;
begin
  inherited MouseDown(Button,Shift,X,Y);if Button<>mbLeft then Exit;
  for I:=0 to 2 do if PtInRect(FRects[I],Point(X,Y)) then begin SelectTab(I);Exit;end;
end;
procedure TSidebarTabs.KeyDown(var Key:Word;Shift:TShiftState);
begin
  inherited KeyDown(Key,Shift);if Shift<>[] then Exit;
  case Key of
    VK_LEFT:SelectTab(Max(0,FActive-1));VK_RIGHT:SelectTab(Min(2,FActive+1));
    VK_HOME:SelectTab(0);VK_END:SelectTab(2);
    else Exit;
  end;Key:=0;
end;
end.
