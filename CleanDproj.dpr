program CleanDproj;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  Winapi.ActiveX,
  Dv.CleanDProj in 'Dv.CleanDProj.pas';

var
  AStream: TStream;
  I: Integer;
begin
  CoInitialize(nil);
  try
    try
      for I := 1 to ParamCount do
      begin
        AStream := TFileStream.Create(ParamStr(I), fmOpenReadWrite);
        try
          DoCleanDproj(AStream);
        finally
          AStream.Free;
        end;
      end;
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    CoUninitialize;
  end;
end.
