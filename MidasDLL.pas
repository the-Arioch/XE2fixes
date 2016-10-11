// makes globally registered Midas.dll unnecessary.
// this global HKLM-registration requires UAC-elevation, prone to DLL-Hell, might prevent
//    copying of app folder from backup or retiring computer, etc
// this unit searches for XE2-or-later midas.dll as registered in HKLM-registry, in 
//    the app's exe folder and one folder above, in current working folder and above.
//
// registering custom MIDAS is based on stock MidasLib unit
// DLL-based Midas is reportedly workig faster than Pascal implementaion which can be linked 
//     into monolythic EXE (MidasLib unit)

unit MidasDLL;

interface

implementation

uses Winapi.Windows, Winapi.ActiveX, Datasnap.DSIntf, SysUtils, Registry;

// function DllGetDataSnapClassObject(const CLSID, IID: TGUID; var Obj): HResult; stdcall; external 'Midas.DLL';
//var DllGetDataSnapClassObject: function(const CLSID, IID: TGUID; var Obj): HResult; stdcall; //external 'Midas.DLL';
var DllGetDataSnapClassObject: pointer; //external 'Midas.DLL';

const dllFN = 'Midas.DLL'; dllSubN = 'DllGetDataSnapClassObject';
var DllHandle: HMODULE = 0;

function RegisteredMidasPath: TFileName;
const rpath = '\SOFTWARE\Classes\CLSID\{9E8D2FA1-591C-11D0-BF52-0020AF32BD64}\InProcServer32';
var rry: TRegistry;
begin
  rry := TRegistry.Create( KEY_READ );
  try
    rry.RootKey := HKEY_LOCAL_MACHINE;
    if rry.OpenKeyReadOnly( rpath ) then begin
       Result := rry.ReadString('');
       if not FileExists( Result ) then
          Result := '';
    end;
  finally
    rry.Destroy;
  end;
end;

procedure TryFindMidas;
var fPath, msg: string;
  function TryOne(const fName: TFileName): boolean;
  const  ver_16_0 = 1048576; // $00060001   - XE2-shipped version. Would accept later ones, not older ones.
  var    ver: Cardinal;  ver2w: LongRec absolute ver;
  begin
    Result := false;
    ver := GetFileVersion( fName );
    if LongInt(ver)+1 = 0 then exit; // -1 --> not found
    if ver < ver_16_0 then begin
       msg := msg + #13#10 +
//              'Найдена версия '+IntToStr(ver2w.Hi) + '.' + IntToStr(ver2w.Lo) + ' в библиотеке ' + fName;
              'Version found: '+IntToStr(ver2w.Hi) + '.' + IntToStr(ver2w.Lo) + ' of the library: ' + fName;
       exit;
    end;
    DllHandle := SafeLoadLibrary(fName);
    if DllHandle = 0 then begin
       msg := msg + #13#10 +
//              'Невозможно загрузить ' + fName + '. Возможно 64-битная версия библиотеки, или другая проблема.';
              'Cannot load ' + fName + '. It could have been a 64-bits build DLL or some other loading problem.';
       exit;
    end;
    DllGetDataSnapClassObject := GetProcAddress( DllHandle, dllSubN);
    if nil = DllGetDataSnapClassObject then begin  
       msg := msg + #13#10 +
//              'Невозможно загрузить ' + fName + '. Не найден ' + dllSubN;
              'Cannot load ' + fName + '. Cannot find ' + dllSubN;
       FreeLibrary( DllHandle );
       DllHandle := 0;
    end;
    Result := true;
  end;
  function TryTwo(const fName: TFileName): boolean; // Searching for DLL file in the given folder and its ..
  begin
    Result := TryOne(fName + dllFN);
    if not Result then
      Result := TryOne(fName + '..\' + dllFN); // for sub-project EXEs in directly nested subfolders
  end;
begin
  fPath := ExtractFilePath( ParamStr(0) );
  if TryTwo( fPath ) then exit;

  fPath := IncludeTrailingBackslash( GetCurrentDir() );
  if TryTwo( fPath ) then exit;

  fPath := RegisteredMidasPath;
  if fPath > '' then
     if TryOne( fPath ) then exit;

//  msg := 'Программе необходима библиотека ' + dllFN + ' версии 16.0 и выше.'#13#10 +
//         'Такой библиотеки не найдено, работа программы невозможна.'#13#10 + #13#10 + msg;
  msg := 'This application need ' + dllFN + ' library of version 16.0 or newer.'#13#10 +
         'Because of a failure to locate this library the application can not work.'#13#10 + #13#10 + msg;
  Winapi.Windows.MessageBox(0, PChar(msg), 
           'Application start failed!',  
		   // 'Ошибка запуска!',
         MB_ICONSTOP or MB_TASKMODAL or MB_DEFAULT_DESKTOP_ONLY or MB_TOPMOST );
  Halt(1);
end;


initialization
//  RegisterMidasLib(@DllGetDataSnapClassObject); -- static linking does not work for (InstallDir)\(SubProjectDir)\SubProject.exe

  TryFindMidas; // Halts the program if MIDAS was not found. Останавливает программу, если не найдено
  RegisterMidasLib(DllGetDataSnapClassObject);
finalization
  if DllHandle <> 0 then
     if FreeLibrary( DllHandle ) then
        DllHandle := 0;
end.
