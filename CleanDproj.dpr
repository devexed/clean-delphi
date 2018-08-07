program CleanDproj;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.ActiveX,
  Dv.CleanDProj in 'Dv.CleanDProj.pas';

var
  I: Integer;
  AFileName: string;
  AFiles: TArray<string>;
begin
  CoInitialize(nil);
  try
    try
      for I := 1 to ParamCount do
      begin
        if FileExists(ParamStr(I)) then
          DoCleanDproj(ParamStr(I));
      end;
      if (ParamCount = 1) and (ParamStr(1) = 'dir') then
      begin
        AFiles := TArray<string>(TDirectory.GetFiles(GetCurrentDir, '*.dproj', TSearchOption.soAllDirectories));
        for AFileName in AFiles do
          DoCleanDproj(AFileName);
      end;
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    CoUninitialize;
  end;
end.
