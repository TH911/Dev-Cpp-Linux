program format_settings_test;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,Classes,ExtCtrls,StdCtrls,IniFiles,format_dialog,ui_language;
type TObserver=class
  Timer:TTimer;
  procedure AcceptDialog(Sender:TObject);
end;
procedure TObserver.AcceptDialog(Sender:TObject);
var D:TForm;I:Integer;
begin
  D:=Screen.ActiveForm;if (D=nil) or (D.Caption<>Tr('Formatting options')) then Exit;
  Timer.Enabled:=False;
  for I:=0 to D.ComponentCount-1 do if D.Components[I] is TMemo then TMemo(D.Components[I]).Text:='--style=java'+LineEnding+'--indent=spaces=2';
  for I:=0 to D.ComponentCount-1 do if (D.Components[I] is TButton) and (TButton(D.Components[I]).Caption=Tr('OK')) then TButton(D.Components[I]).Click;
end;
procedure Check(Value:Boolean;const S:string);
begin if not Value then raise Exception.Create(S);end;
var Java,Allman,Config:string;Raised:Boolean;O:TObserver;Ini:TIniFile;
begin
  Application.Initialize;
  Java:=FormatSource('int main(){return 0;}','--style=java --indent=spaces=2');
  Allman:=FormatSource('int main(){return 0;}','--style=allman --indent=tab=4');
  Check(Pos('int main() {',Java)>0,'Java style actually reaches AStyle');
  Check(Pos('int main()'+LineEnding+'{',Allman)>0,'Allman style actually reaches AStyle');
  Raised:=False;try FormatSource('int main(){}','$(touch /tmp/should-not-run)');except on E:Exception do Raised:=True;end;
  Check(Raised,'non-option arguments are rejected without shell expansion');
  Raised:=False;try FormatSource('int main(){}','--devcpp-invalid-option');except on E:Exception do Raised:=True;end;
  Check(Raised,'formatter failures are reported');
  Config:=GetTempFileName;O:=TObserver.Create;O.Timer:=TTimer.Create(nil);O.Timer.Interval:=100;O.Timer.OnTimer:=@O.AcceptDialog;
  try
    Check(EditFormatOptions(nil,Config,'int main(){return 0;}'),'formatter dialog accepts valid options');
    Ini:=TIniFile.Create(Config);try Check(Ini.ReadString('AStyle','Arguments','')='--style=java --indent=spaces=2','dialog saves accepted options');finally Ini.Free;end;
  finally O.Timer.Free;O.Free;DeleteFile(Config);end;
  WriteLn('PASS: real AStyle Java/Allman output, argument validation and error reporting');
end.
