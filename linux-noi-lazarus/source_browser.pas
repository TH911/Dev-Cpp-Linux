unit source_browser;
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TBrowserKind=(bkType,bkFunction,bkVariable);
  TBrowserSymbol=record
    Name,Arguments,TypeName:string;
    Line,Parent,ImageIndex:Integer;
    Kind:TBrowserKind;
  end;
  TBrowserSymbols=array of TBrowserSymbol;
procedure CollectBrowserSymbols(Lines:TStrings;out Symbols:TBrowserSymbols);
implementation
uses SysUtils,noi_syn_cpp;
type
  TToken=record Text:string;Line:Integer;end;
  TTokens=array of TToken;
function Ident(const S:string):Boolean;
var I:Integer;
begin
  Result:=(S<>'') and (S[1] in ['a'..'z','A'..'Z','_','~']);
  if Result then for I:=2 to Length(S) do if not (S[I] in ['a'..'z','A'..'Z','_','0'..'9']) then Exit(False);
end;
procedure CollectBrowserSymbols(Lines:TStrings;out Symbols:TBrowserSymbols);
var Lexer:TSynCppSyn;Tokens:TTokens;Count,Row,Capacity,I:Integer;
  function Token(Index:Integer):string;
  begin if (Index<0) or (Index>=Count) then Result:='' else Result:=Tokens[Index].Text;end;
  function Join(First,Last:Integer;StripQualifiers:Boolean=False):string;
  var K:Integer;S,Previous:string;
  begin
    Result:='';Previous:='';
    for K:=First to Last do begin
      S:=Token(K);
      if StripQualifiers and ((S='static') or (S='constexpr') or (S='const') or (S='extern') or (S='inline') or (S='virtual') or (S='friend')) then Continue;
      if ((Ident(S) or ((S<>'') and (S[1] in ['0'..'9']))) and Ident(Previous)) or (Previous=',') then Result:=Result+' ';
      Result:=Result+S;Previous:=S;
    end;
  end;
  function Add(AParent,At:Integer;AKind:TBrowserKind;const AName,Args,AType:string;Access:Integer):Integer;
  begin
    Result:=Length(Symbols);SetLength(Symbols,Result+1);
    with Symbols[Result] do begin
      Name:=AName;Arguments:=Args;TypeName:=AType;Parent:=AParent;Kind:=AKind;Line:=Tokens[At].Line;
      case AKind of
        bkType:ImageIndex:=1;
        bkFunction:ImageIndex:=5+Access;
        bkVariable:ImageIndex:=2+Access;
      end;
    end;
  end;
  procedure Declaration(First,Last,Parent,Access:Integer;const ForcedType:string='');
  var K,J,NameAt,Paren,Bracket,Angle,Start,Stop,Unused:Integer;TypeName,Args,S:string;
  begin
    if First>Last then Exit;
    S:=Token(First);
    if (S='using') or (S='typedef') or (S='return') or (S='static_assert') or
      (S='if') or (S='for') or (S='while') or (S='switch') then Exit;
    Paren:=0;Bracket:=0;Angle:=0;
    for K:=First to Last do begin
      S:=Token(K);
      if (S='=') and (Bracket=0) and (Angle=0) then Break;
      if S='[' then Inc(Bracket) else if S=']' then Dec(Bracket)
      else if S='<' then Inc(Angle) else if S='>' then Dec(Angle)
      else if (S='(') and (Bracket=0) and (Angle=0) then begin
        NameAt:=K-1;if not Ident(Token(NameAt)) then Exit;
        J:=NameAt;
        while (J>First+1) and (Token(J-1)='::') do Dec(J,2);
        TypeName:=Join(First,J-1,True);
        if (TypeName='') and (Parent<0) then Exit;
        Start:=K;Paren:=1;
        { Locate the matching argument list without treating its commas as
          separate declarations. Function bodies are skipped by Scope. }
        J:=Start+1;
        while (J<=Last) and (Paren>0) do begin
          if Token(J)='(' then Inc(Paren) else if Token(J)=')' then Dec(Paren);
          Inc(J);
        end;
        if Paren<>0 then Exit;
        Args:=Join(Start,J-1);
        Unused:=Add(Parent,NameAt,bkFunction,Token(NameAt),Args,TypeName,Access);Exit;
      end;
    end;
    TypeName:=ForcedType;Start:=First;Bracket:=0;Angle:=0;Paren:=0;
    for K:=First to Last+1 do begin
      S:=Token(K);
      if S='[' then Inc(Bracket) else if S=']' then Dec(Bracket)
      else if S='<' then Inc(Angle) else if S='>' then Dec(Angle)
      else if S='(' then Inc(Paren) else if S=')' then Dec(Paren);
      if (K=Last+1) or ((S=',') and (Bracket=0) and (Angle=0) and (Paren=0)) then begin
        Stop:=K-1;NameAt:=-1;Args:='';
        for J:=Start to Stop do begin
          if (Token(J)='=') or (Token(J)='{') then Break;
          if Token(J)='[' then begin Args:=Join(J,Stop);Break;end;
          if Ident(Token(J)) then NameAt:=J;
        end;
        if NameAt>=Start then begin
          if TypeName='' then TypeName:=Join(Start,NameAt-1,True);
          if TypeName<>'' then begin
            J:=Pos('=',Args);if J>0 then Args:=Copy(Args,1,J-1);
            Unused:=Add(Parent,NameAt,bkVariable,Token(NameAt),Args,TypeName,Access);
          end;
        end;
        Start:=K+1;
      end;
    end;
  end;
  procedure Scope(var At:Integer;Parent,Access,Depth:Integer);
  var Start,K,N,Level,Child,BeforeTail,AfterTail,Instance,Member,NewMember:Integer;S,TypeName:string;
  begin
    if Depth>64 then begin At:=Count;Exit;end;
    Start:=At;
    while At<Count do begin
      S:=Token(At);
      if S='}' then begin Inc(At);Exit;end;
      if (S='template') and (Token(At+1)='<') then begin
        Inc(At,2);Level:=1;
        while (At<Count) and (Level>0) do begin
          if Token(At)='<' then Inc(Level) else if Token(At)='>' then Dec(Level)
          else if Token(At)='>>' then Dec(Level,2);
          Inc(At);
        end;
        Start:=At;Continue;
      end;
      if ((S='public') or (S='protected') or (S='private')) and (Token(At+1)=':') then begin
        if S='private' then Access:=0 else if S='protected' then Access:=1 else Access:=2;
        Inc(At,2);Start:=At;Continue;
      end;
      if ((S='struct') or (S='class') or (S='namespace') or (S='union')) and Ident(Token(At+1)) then begin
        TypeName:=S;N:=At+1;K:=N+1;
        while (K<Count) and (Token(K)<>'{') and (Token(K)<>';') do Inc(K);
        if Token(K)='{' then begin
          Child:=Parent;
          if S<>'namespace' then Child:=Add(Parent,N,bkType,Token(N),'',TypeName,Access);
          At:=K+1;
          if S='class' then Scope(At,Child,0,Depth+1) else Scope(At,Child,2,Depth+1);
          Start:=At;
          if S<>'namespace' then begin
            while (At<Count) and (Token(At)<>';') and (Token(At)<>'}') do Inc(At);
            if Start<At then begin
              BeforeTail:=Length(Symbols);Declaration(Start,At-1,Parent,Access,TypeName);
              AfterTail:=Length(Symbols);
              for Instance:=BeforeTail to AfterTail-1 do begin
                { Windows displays inline structure instances as expandable
                  structure rows, with their members beneath them. }
                Symbols[Instance].Kind:=bkType;Symbols[Instance].ImageIndex:=1;
                Symbols[Instance].Arguments:='';
                for Member:=Child+1 to BeforeTail-1 do if Symbols[Member].Parent=Child then begin
                  NewMember:=Length(Symbols);SetLength(Symbols,NewMember+1);
                  Symbols[NewMember]:=Symbols[Member];Symbols[NewMember].Parent:=Instance;
                end;
              end;
            end;
            if Token(At)=';' then Inc(At);
          end;
          Start:=At;Continue;
        end;
      end;
      if S='{' then begin
        Declaration(Start,At-1,Parent,Access);
        Level:=1;Inc(At);
        while (At<Count) and (Level>0) do begin
          if Token(At)='{' then Inc(Level) else if Token(At)='}' then Dec(Level);
          Inc(At);
        end;
        { Bodies never contribute local variables to the class browser. }
        Start:=At;
        Continue;
      end;
      if S=';' then begin Declaration(Start,At-1,Parent,Access);Start:=At+1;end;
      Inc(At);
    end;
  end;
begin
  SetLength(Symbols,0);Count:=0;Capacity:=1024;SetLength(Tokens,Capacity);
  Lexer:=TSynCppSyn.Create(nil);
  try
    Lexer.ResetRange;
    for Row:=0 to Lines.Count-1 do begin
      Lexer.SetLine(Lines[Row],Row);
      while not Lexer.GetEol do begin
        if not (Lexer.GetTokenID in [tkComment,tkDirective,tkNull,tkSpace,tkString]) then begin
          if Count=Capacity then begin Capacity:=Capacity*2;SetLength(Tokens,Capacity);end;
          Tokens[Count].Text:=Lexer.GetToken;Tokens[Count].Line:=Row+1;Inc(Count);
        end;
        Lexer.Next;
      end;
    end;
    I:=0;Scope(I,-1,2,0);
  finally Lexer.Free;end;
end;
end.
