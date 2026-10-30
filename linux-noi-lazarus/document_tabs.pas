unit document_tabs;
{$mode objfpc}{$H+}
interface
uses Classes, Types, Controls, ComCtrls;
type
  TDocumentTabs = class(TPageControl)
  private
    FPressedPage: TTabSheet;
    FPressPoint: TPoint;
    FDragging: Boolean;
    FPreviousCursor: TCursor;
    FOnTabMoved: TNotifyEvent;
    function PressedIndex: Integer;
  protected
    procedure CreateWnd; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
  public
    destructor Destroy;override;
    function CancelTabDrag: Boolean;
    property OnTabMoved: TNotifyEvent read FOnTabMoved write FOnTabMoved;
  end;
implementation
uses Math {$IFDEF LCLgtk2},Gtk2{$ENDIF};
procedure TDocumentTabs.CreateWnd;
begin
  inherited CreateWnd;
  {$IFDEF LCLgtk2}
  gtk_widget_set_name(PGtkWidget(Handle),'devcpp-document-tabs');
  gtk_notebook_set_tab_hborder(PGtkNotebook(Handle),9);
  {$ENDIF}
end;
destructor TDocumentTabs.Destroy;
begin
  CancelTabDrag;
  inherited Destroy;
end;
function TDocumentTabs.PressedIndex: Integer;
var I: Integer;
begin
  Result:=-1;
  if FPressedPage=nil then Exit;
  for I:=0 to PageCount-1 do if Pages[I]=FPressedPage then Exit(I);
end;
function TDocumentTabs.CancelTabDrag: Boolean;
begin
  Result:=FDragging;
  if FDragging then Cursor:=FPreviousCursor;
  FDragging:=False;FPressedPage:=nil;
  if MouseCapture then MouseCapture:=False;
end;
procedure TDocumentTabs.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var Index: Integer;
begin
  CancelTabDrag;
  if Button=mbLeft then begin
    Index:=IndexOfPageAt(X,Y);
    if (Index>=0) and (Index<PageCount) then begin
      FPressedPage:=Pages[Index];FPressPoint:=Point(X,Y);
    end;
  end;
  inherited MouseDown(Button,Shift,X,Y);
end;
procedure TDocumentTabs.MouseMove(Shift: TShiftState; X,Y: Integer);
begin
  inherited MouseMove(Shift,X,Y);
  if not (ssLeft in Shift) then begin CancelTabDrag;Exit;end;
  if PressedIndex<0 then Exit;
  if not FDragging and (Max(Abs(X-FPressPoint.X),Abs(Y-FPressPoint.Y))>=6) then begin
    FPreviousCursor:=Cursor;FDragging:=True;MouseCapture:=True;
  end;
  if FDragging then
    if (IndexOfPageAt(X,Y)>=0) and (IndexOfPageAt(X,Y)<>PressedIndex) then
      Cursor:=crDrag
    else Cursor:=crNoDrop;
end;
procedure TDocumentTabs.MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var SourceIndex,TargetIndex: Integer; Selected,Moving: TTabSheet; MoveTab: Boolean;
begin
  SourceIndex:=PressedIndex;TargetIndex:=IndexOfPageAt(X,Y);
  MoveTab:=(Button=mbLeft) and FDragging and (SourceIndex>=0) and
    (TargetIndex>=0) and (TargetIndex<PageCount) and (SourceIndex<>TargetIndex);
  Moving:=FPressedPage;Selected:=ActivePage;
  CancelTabDrag;
  inherited MouseUp(Button,Shift,X,Y);
  if not MoveTab then Exit;
  Moving.PageIndex:=TargetIndex;
  ActivePage:=Selected;
  if Assigned(FOnTabMoved) then FOnTabMoved(Self);
end;
end.
