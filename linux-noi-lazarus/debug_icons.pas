unit debug_icons;

{$mode objfpc}{$H+}

interface

uses Graphics;

function DebuggerIcon(const Name: string): TBitmap;

implementation

uses Types;

function DebuggerIcon(const Name: string): TBitmap;
var C: TCanvas;
begin
  Result := TBitmap.Create;
  Result.SetSize(16, 16);
  C := Result.Canvas;
  C.Brush.Color := clFuchsia;
  C.FillRect(0, 0, 16, 16);
  C.Pen.Color := $00303030;
  if (Name = 'breakpoint') or (Name = 'current-breakpoint') then
  begin
    C.Brush.Color := $003030DC;
    C.Ellipse(2, 2, 14, 14);
    C.Pen.Color := $00A0A0FF;
    C.Arc(4, 4, 12, 12, 4, 8, 8, 4);
    C.Pen.Color := $00303030;
  end;
  if (Name = 'current') or (Name = 'current-breakpoint') then
  begin
    C.Brush.Color := $0000DFFF;
    C.Polygon([Point(1, 5), Point(8, 5), Point(8, 2), Point(15, 8),
      Point(8, 14), Point(8, 11), Point(1, 11)]);
  end
  else if (Name = 'debug') or (Name = 'continue') then
  begin
    C.Brush.Color := $00309830;
    C.Polygon([Point(4, 2), Point(13, 8), Point(4, 14)]);
    if Name = 'continue' then
    begin C.Brush.Color := $00309830; C.Rectangle(1, 2, 3, 14); end;
  end
  else if Name = 'stop-debug' then
  begin
    C.Brush.Color := $003030D0;
    C.Rectangle(3, 3, 13, 13);
  end
  else if (Name = 'step-over') or (Name = 'step-into') then
  begin
    C.Pen.Color := $00B06020;
    C.Pen.Width := 2;
    C.MoveTo(3, 3); C.LineTo(9, 3); C.LineTo(9, 9);
    C.Brush.Color := $00B06020;
    C.Polygon([Point(5, 7), Point(12, 7), Point(9, 12)]);
    C.Pen.Color := $00404040; C.Pen.Width := 1;
    if Name = 'step-over' then C.Line(2, 14, 14, 14)
    else begin C.Line(2, 12, 2, 15); C.Line(14, 12, 14, 15); end;
  end;
end;

end.
