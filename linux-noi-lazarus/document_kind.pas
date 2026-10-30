unit document_kind;
{$mode objfpc}{$H+}
interface
function IsCodeFile(const FileName: string; const Extensions: string = 'c;cpp;h;hpp;cc;cxx;cp;hp;rh;fx;inl;tcc;win'): Boolean;
implementation
uses SysUtils;
function IsCodeFile(const FileName,Extensions:string):Boolean;
var Ext,List:string;
begin
  if FileName='' then Exit(True);
  Ext:=LowerCase(ExtractFileExt(FileName));
  if (Ext='') or (Ext='.in') or (Ext='.out') or (Ext='.ans') then Exit(False);
  Delete(Ext,1,1);
  List:=LowerCase(StringReplace(StringReplace(Extensions,'*.','',[rfReplaceAll]),'.','',[rfReplaceAll]));
  Result:=Pos(';'+Ext+';',';'+List+';')>0;
end;
end.
