program syntax_preview_test;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,ExtCtrls,ComCtrls,Graphics,Controls,SynEdit,
  editor_options_dialog,editor_preferences,ui_language;
type
  TObserver=class
    Timer:TTimer;
    Checked:Boolean;
    procedure Inspect(Sender:TObject);
  end;
procedure Check(Value:Boolean;const S:string);
begin if not Value then begin WriteLn(StdErr,'FAIL: ',S);Halt(1);end;end;
procedure TObserver.Inspect(Sender:TObject);
const Rows:array[0..3] of Integer=(7,9,11,15);
  Backgrounds:array[0..3] of TColor=(clRed,clBlue,clMaroon,clNavy);
var D:TForm;E:TSynEdit;I,J:Integer;FG,BG:TColor;Special:Boolean;Picture:TBitmap;
begin
  D:=Screen.ActiveForm;if (D=nil) or (D.Caption<>Tr('Editor Options')) then Exit;
  Timer.Enabled:=False;E:=nil;
  for I:=0 to D.ComponentCount-1 do begin
    if D.Components[I] is TPageControl then TPageControl(D.Components[I]).ActivePageIndex:=2;
    if (D.Components[I] is TSynEdit) and (Pos('float average, total;',TSynEdit(D.Components[I]).Text)>0) then E:=TSynEdit(D.Components[I]);
  end;
  Check(E<>nil,'original syntax sample exists');Check(E.Lines.Count=16,'original sixteen-line example');
  Check(Pos('getch()',E.Lines[14])>0,'selection example belongs to line 15');
  for I:=0 to 3 do begin
    FG:=clNone;BG:=clNone;Special:=False;E.OnSpecialLineColors(E,Rows[I],Special,FG,BG);
    Check(Special and (FG=clWhite) and (BG=Backgrounds[I]),'original full-line colors at row '+IntToStr(Rows[I]));
  end;
  Application.ProcessMessages;E.Repaint;
  Picture:=TBitmap.Create;
  try
    Picture.SetSize(E.Width,E.Height);E.PaintTo(Picture.Canvas,0,0);
    for I:=0 to 3 do begin
      J:=E.LineHeight*(Rows[I]-1)+E.LineHeight div 2;
      Check(ColorToRGB(Picture.Canvas.Pixels[E.Width-35,J])=ColorToRGB(Backgrounds[I]),'rendered full-width row '+IntToStr(Rows[I]));
    end;
  finally Picture.Free;end;
  Checked:=True;D.ModalResult:=mrCancel;
end;
var O:TObserver;P:TEditorPreferences;Theme,FontName:string;Size,Tabs:Integer;
begin
  Application.Initialize;P:=TEditorPreferences.Create;O:=TObserver.Create;
  O.Timer:=TTimer.Create(nil);O.Timer.Interval:=100;O.Timer.OnTimer:=@O.Inspect;
  Theme:='Classic Plus';FontName:='DejaVu Sans Mono';Size:=10;Tabs:=4;
  try
    Check(not EditAdvancedEditor(nil,P,Theme,FontName,Size,Tabs),'Cancel preserves caller settings');
    Check(O.Checked,'actual modal syntax page inspected');
    WriteLn('PASS: original sixteen-line syntax sample; rows 7,9,11,15 render red/blue/maroon/navy across the preview');
  finally O.Timer.Free;O.Free;P.Free;end;
end.
