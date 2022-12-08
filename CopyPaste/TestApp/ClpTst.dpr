program ClpTst;

uses
  Forms,
  uclptst in 'uclptst.pas' {Form31},
  ClipboardLocaleFixOut in '..\ClipboardLocaleFixOut.pas';

{$WARN SYMBOL_PLATFORM OFF}{$T+}

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm31, Form31);
  Application.Run;
end.
