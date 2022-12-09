program ClpTst;

uses
  Forms,
  Win32SimpleHooks in '..\Win32SimpleHooks.pas',
  uclptst in 'uclptst.pas' {Form31},
  ClipboardLocaleFixOut in '..\ClipboardLocaleFixOut.pas',
  ClipboardLocaleFixIn in '..\ClipboardLocaleFixIn.pas';

//  If you had to delete *.dproj - go program opitions
//     and DEFINE the HookAtWill conditional compilation symbol

{$WARN SYMBOL_PLATFORM OFF}{$T+}

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm31, Form31);
  Application.Run;
end.
