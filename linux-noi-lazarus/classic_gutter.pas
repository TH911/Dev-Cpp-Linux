unit classic_gutter;
{$mode objfpc}{$H+}
interface
uses Classes, Graphics, Types, SynGutterLineNumber;
type
  TClassicLineNumbers = class(TSynGutterLineNumber)
  private
    FNumberFont: TFont;
    FCustomFont: Boolean;
    procedure Changed(Sender: TObject);
    procedure SetCustomFont(Value: Boolean);
  protected
    function PreferedWidthAtCurrentPPI: Integer; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: Integer); override;
    property NumberFont: TFont read FNumberFont;
    property CustomFont: Boolean read FCustomFont write SetCustomFont;
  end;
implementation
uses SysUtils, Math, SynEdit;
constructor TClassicLineNumbers.Create(AOwner: TComponent);
begin inherited Create(AOwner); FNumberFont := TFont.Create; FNumberFont.OnChange := @Changed; end;
destructor TClassicLineNumbers.Destroy;
begin FNumberFont.Free; inherited Destroy; end;
procedure TClassicLineNumbers.Changed(Sender: TObject);
begin if FCustomFont then begin DoAutoSize; TCustomSynEdit(SynEdit).Invalidate; end; end;
procedure TClassicLineNumbers.SetCustomFont(Value: Boolean);
begin if FCustomFont=Value then Exit; FCustomFont:=Value; DoAutoSize; TCustomSynEdit(SynEdit).Invalidate; end;
function TClassicLineNumbers.PreferedWidthAtCurrentPPI: Integer;
var B: TBitmap;
begin
  if not FCustomFont or (FNumberFont=nil) then Exit(inherited PreferedWidthAtCurrentPPI);
  B := TBitmap.Create;
  try B.Canvas.Font.Assign(FNumberFont); Result := B.Canvas.TextWidth(StringOfChar('0',Max(DigitCount,Length(IntToStr(SynEdit.Lines.Count))))) + 4;
  finally B.Free; end;
end;
procedure TClassicLineNumbers.Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: Integer);
var Row, Line, RowHeight, Digits: Integer; S: string; R: TRect;
begin
  if not FCustomFont then begin inherited Paint(Canvas,AClip,FirstLine,LastLine); Exit; end;
  if not Visible then Exit;
  Canvas.Font.Assign(FNumberFont); Canvas.Font.Color := MarkupInfo.Foreground;
  Canvas.Brush.Color := Gutter.Color; Canvas.FillRect(AClip);
  RowHeight := TCustomSynEdit(SynEdit).LineHeight;
  Digits := Max(DigitCount,Length(IntToStr(SynEdit.Lines.Count)));
  for Row := FirstLine to LastLine do begin
    Line := FoldView.DisplayNumber[Row]; if (Line<1) or (Line>SynEdit.Lines.Count) then Continue;
    S := IntToStr(Line-Ord(ZeroStart)); if LeadingZeros then while Length(S)<Digits do S:='0'+S;
    R := AClip; R.Top := AClip.Top+(Row-FirstLine)*RowHeight; R.Bottom := R.Top+RowHeight;
    Canvas.TextRect(R,R.Right-Canvas.TextWidth(S)-2,R.Top+Max(0,(RowHeight-Canvas.TextHeight(S)) div 2),S);
  end;
end;
end.
