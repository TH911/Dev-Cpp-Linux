unit source_output;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
function ExportSourceText(const Source, Title, Kind: string): string;
procedure PrintSourceText(const Source, Title: string; SetupOnly: Boolean);
implementation
uses Math, Forms, Dialogs, Graphics, Printers, PrintersDlgs, OSPrinters;
function ExportSourceText(const Source, Title, Kind: string): string;
var I, Code: Integer; UnicodeText: UnicodeString; C: Char;
  function Html(const Value: string): string;
  begin
    Result := StringReplace(Value, '&', '&amp;', [rfReplaceAll]);
    Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
    Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
    Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  end;
begin
  if Kind = 'html' then Exit('<!doctype html><html><head><meta charset="utf-8"><title>' +
    Html(Title) + '</title></head><body><pre>' + Html(Source) + '</pre></body></html>');
  Result := '';
  if Kind = 'rtf' then
  begin
    Result := '{\rtf1\ansi\deff0{\fonttbl{\f0\fmodern Courier New;}}\f0\fs20\uc1 ';
    UnicodeText := UTF8Decode(Source);
    for I := 1 to Length(UnicodeText) do
    begin
      Code := Ord(UnicodeText[I]);
      case Code of
        13: ;
        10: Result := Result + '\par' + LineEnding;
        9: Result := Result + '\tab ';
        92, 123, 125: Result := Result + '\' + Chr(Code);
        32..91, 93..122, 124, 126: Result := Result + Chr(Code);
      else
        if Code > 32767 then Dec(Code, 65536);
        Result := Result + '\u' + IntToStr(Code) + '?';
      end;
    end;
    Exit(Result + '}');
  end;
  Result := '\documentclass{article}' + LineEnding + '\usepackage[T1]{fontenc}' + LineEnding +
    '\begin{document}\ttfamily\raggedright\obeylines\obeyspaces' + LineEnding;
  for I := 1 to Length(Source) do
  begin
    C := Source[I];
    case C of
      '\': Result := Result + '\textbackslash{}';
      '{', '}', '%', '$', '&', '#', '_': Result := Result + '\' + C;
      '~': Result := Result + '\textasciitilde{}';
      '^': Result := Result + '\textasciicircum{}';
      #9: Result := Result + '    ';
    else Result := Result + C;
    end;
  end;
  Result := Result + LineEnding + '\end{document}';
end;
procedure PrintSourceText(const Source, Title: string; SetupOnly: Boolean);
var Dialog: TPrintDialog; Setup: TPrinterSetupDialog; Lines: TStringList;
  Row, Y, Margin, LineHeight, PageLines, FirstPage, LastPage, Page, Pages: Integer;
begin
  if Printer.Printers.Count = 0 then raise Exception.Create('No printers are configured.');
  if SetupOnly then
  begin
    Setup := TPrinterSetupDialog.Create(nil);
    try Setup.Execute; finally Setup.Free; end;
    Exit;
  end;
  Dialog := TPrintDialog.Create(nil);
  Lines := TStringList.Create;
  try
    Lines.Text := Source;
    Dialog.Options := [poPageNums];
    if not Dialog.Execute then Exit;
    Printer.Title := Title;
    Printer.BeginDoc;
    try
      Printer.Canvas.Font.Name := 'Monospace';
      Printer.Canvas.Font.Size := 10;
      Margin := Printer.XDPI div 2;
      LineHeight := Max(1, Printer.Canvas.TextHeight('Mg'));
      PageLines := Max(1, (Printer.PageHeight - 2 * Margin) div LineHeight - 2);
      Pages := Max(1, (Lines.Count + PageLines - 1) div PageLines);
      FirstPage := 1; LastPage := Pages;
      if Dialog.PrintRange = prPageNums then
      begin FirstPage := Max(1, Dialog.FromPage); LastPage := Min(Pages, Dialog.ToPage); end;
      for Page := FirstPage to LastPage do
      begin
        if Page > FirstPage then Printer.NewPage;
        Printer.Canvas.TextOut(Margin, Margin, Title + '  (' + IntToStr(Page) + '/' + IntToStr(Pages) + ')');
        Y := Margin + 2 * LineHeight;
        for Row := (Page - 1) * PageLines to Min(Lines.Count - 1, Page * PageLines - 1) do
        begin
          Printer.Canvas.TextOut(Margin, Y, StringReplace(Lines[Row], #9, '    ', [rfReplaceAll]));
          Inc(Y, LineHeight);
        end;
      end;
      Printer.EndDoc;
    except Printer.Abort; raise; end;
  finally Dialog.Free; Lines.Free; end;
end;
end.
