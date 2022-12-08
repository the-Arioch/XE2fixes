program ClpTst;

uses
  Vcl.Forms,
  uclptst in '..\uclptst.pas' {Form31},
  ClipboardLocaleFixOut in '..\ClipboardLocaleFixOut.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm31, Form31);
  Application.Run;
end.
