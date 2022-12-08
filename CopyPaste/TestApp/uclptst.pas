unit uclptst;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls;

{$if CompilerVersion < 19}
const WM_CLIPBOARDUPDATE = $031D; // missed in Delphi 2007
type UnicodeString = widestring;
{$ifend}

{$WARN SYMBOL_PLATFORM OFF}{$T+}

type
  TForm31 = class(TForm)
    Memo1: TMemo;
    btnA2U: TButton;
    btnU2A: TButton;
    btnCOC: TButton;
    btnCSD: TButton;
    btnCCC: TButton;
    btnCEC: TButton;
    chkLoc: TCheckBox;
    chkPatchOut: TCheckBox;
    chkPatchIn: TCheckBox;
    btnGetLCID: TButton;
    chkLocEu: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure btnA2UClick(Sender: TObject);
    procedure btnCCCClick(Sender: TObject);
    procedure btnCECClick(Sender: TObject);
    procedure btnCOCClick(Sender: TObject);
    procedure btnCSDClick(Sender: TObject);
    procedure btnGetLCIDClick(Sender: TObject);
    procedure btnU2AClick(Sender: TObject);
    procedure chkLocClick(Sender: TObject);
    procedure chkLocEuClick(Sender: TObject);
    procedure chkPatchOutClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure DoLog(const t, s: string);

    procedure WMCLIPBOARDUPDATE(var m: TMessage); message WM_CLIPBOARDUPDATE;
    procedure WMDRAWCLIPBOARD(var m: TMessage); message WM_DRAWCLIPBOARD ;
  public
    procedure Log(const su: unicodestring); overload;
    procedure Log(const sa: ansistring); overload;
  end;

var
  Form31: TForm31;

implementation

uses
{$if CompilerVersion >= 19}
  AnsiStrings,
{$ifend}
  Clipbrd
  , ClipboardLocaleFixOut
  ;

procedure SetClipAnsi(const sA: AnsiString); forward;
procedure SetClipUni (const sU: UnicodeString); forward;
function  GetClipAnsi: AnsiString; forward;
function  GetClipUni: UnicodeString; forward;
function NeedLocale: boolean; forward;

{$if CompilerVersion < 19}
function BoolToStr(const B: Boolean; const Dummy: Boolean = False): string;
begin
  if B then Result := 'TRUE' else RESULT := 'FALSE';
end;

const LOCALE_CUSTOM_UI_DEFAULT = $1400;
const LOCALE_CUSTOM_DEFAULT = $0C00;
{$ifend}
const LOCALE_CUSTOM_USER_DEFAULT = $0C00; // different docs claim different names

var // would be missed on pre-Vista
  RemoveClipboardFormatListener, AddClipboardFormatListener:
    function (hWndNewViewer: HWND): BOOL; stdcall;
  GetThreadUILanguage: function (): LANGID; stdcall;

var
  GoodLocales: array [1 .. 6] of LANGID =
  ( LOCALE_USER_DEFAULT, LOCALE_SYSTEM_DEFAULT, LOCALE_CUSTOM_USER_DEFAULT,
    LOCALE_CUSTOM_UI_DEFAULT, $ffFF, $ffFF);

procedure TryFixPaste;
var
  Data: THandle; Ptr: PCardinal;
  Ansi: AnsiString; U16: UnicodeString;
  Locale: LCID; LocParsed: LongRec absolute Locale;
  MakeAnsi, MakeUni: boolean; W: LANGID;
  i, L, cntA, cntU: integer;
  cA: AnsiChar; cW: WideChar; cWParsed: WordRec absolute cW;
  procedure InnerSetBuffer(const Format: Word; const Buffer: Pointer; Size: Integer);
  var
    Data: THandle;
    DataPtr: Pointer;
  begin
    Data := GlobalAlloc(GMEM_MOVEABLE+GMEM_DDESHARE, Size);
    try
      DataPtr := GlobalLock(Data);
      try
        Move(Buffer^, DataPtr^, Size);
        if SetClipboardData(Format, Data) = 0 then
           raise EOutOfResources.Create('SetClipboardData');
      finally
        GlobalUnlock(Data);
      end;
    except
      GlobalFree(Data);
      raise;
    end;
  end;
begin
  if not IsClipboardFormatAvailable(CF_UNICODETEXT) then exit;

  Locale := GetThreadLocale;
  GoodLocales[5] := LocParsed.Lo;

  if nil <> @GetThreadUILanguage then
     GoodLocales[6] := GetThreadUILanguage();

  Data := GetClipboardData(CF_LOCALE);
  try
    Locale := Cardinal(-2);
    if Data <> 0 then begin
      Ptr := GlobalLock(Data);
      if Ptr <> nil then
         Locale := Ptr^;
    end
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
  end;

  for W in GoodLocales do
    if W = LocParsed.Lo then
      Exit;

  Data := GetClipboardData(CF_UNICODETEXT);
  try
    if Data <> 0 then
      U16 := PWideChar(GlobalLock(Data))
    else
      U16 := '';
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
  end;

  Data := GetClipboardData(CF_TEXT);
  try
    if Data <> 0 then
      Ansi := PAnsiChar(GlobalLock(Data))
    else
      Ansi := '';
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
  end;

//  MakeAnsi := False;
//  MakeUni  := False;

  if Length(Ansi) <= 0 then begin
     MakeAnsi := Length(U16) > 0;
     if not MakeAnsi then
        exit;
  end else begin
     MakeUni := Length(U16) <= 0;
     if not MakeUni then begin
        // нормальный случай - заполнены оба поля...

        L := Length(Ansi);
        i := Length(U16);
        if i < L then L := i;

        cntA := 0; cntU := 0;
        for i := 1 to L do begin
          cA := Ansi[i];
          cW := U16[i];

          if cWParsed.Hi = 0 then begin
             if ((cWParsed.Lo and $80) <> 0) and (cWParsed.Lo = Ord(cA)) then
                Inc(cntA);
          end else begin
             if (cA = '?') and (cWParsed.Lo <> $3F) then
                Inc(cntU);
          end;
        end;

        MakeAnsi := (cntA + cntA) > cntU;
        MakeUni  := (cntU + cntU) > cntA;
        
        if MakeAnsi then begin
           Ansi := AnsiString(U16);
           InnerSetBuffer( CF_TEXT, @Ansi[1], SizeOf(Ansi[1])*(Length(Ansi) + 1));

           CharToOemA(@Ansi[1], @Ansi[1]);
           InnerSetBuffer( CF_OEMTEXT, @Ansi[1], SizeOf(Ansi[1])*
                                 (StrLen(PAnsiChar(@Ansi[1])) + 1));
        end else
        if MakeUni then begin
           U16 := UnicodeString(Ansi);
           InnerSetBuffer( CF_UNICODETEXT, @U16[1], SizeOf(U16[1])*(Length(U16) + 1) );
        end;
     end;
  end;
end;



{$R *.dfm}

var gb, InjectLCID, GuessLCID: boolean;
  msgA: AnsiString = 'Жёлтый ApPlE жёсткий жук';
  msgU: UnicodeString = 'Мерзкое ApPlE мёрзлое место';

//{$o-}
//procedure dummy2;
//label L1, L2;
//begin
////  exit;
//  asm
//    MOV EDI, EDI
//  end;
//
//  goto L2;
//
//  asm
//@@1:
//    NOP; NOP; NOP; NOP; NOP
//
//L1:
//    jmp SHORT PTR @@1
//
//@@2:
//    ret
//  end;
//L2:
//  goto L1
//end;
//{$o+}

procedure TForm31.FormCreate(Sender: TObject);
begin
  Tag := GetClipboardSequenceNumber; // linker
  Memo1.Clear;
  Tag := Memo1.Lines.Count;
end;

procedure TForm31.btnCCCClick(Sender: TObject);
begin
  gb := CloseClipboard;
//  dummy2;
end;

procedure TForm31.btnCOCClick(Sender: TObject);
begin
  gb := OpenClipboard(0);
end;

procedure TForm31.btnCSDClick(Sender: TObject);
var h: THandle;
begin
  h := SetClipboardData(1, 0);
end;

procedure TForm31.btnCECClick(Sender: TObject);
begin
  gb := EmptyClipboard;
end;

procedure TForm31.btnA2UClick(Sender: TObject);
begin
  SetClipAnsi( msgA );
  Log( GetClipUni );
end;

procedure TForm31.btnU2AClick(Sender: TObject);
begin
  SetClipUni( msgU );
  Log( GetClipAnsi );
end;

{ TForm31 }

procedure TForm31.DoLog(const t, s: string);
var m: string;
begin
  Tag := 1+Tag;

  m := Format('%.4d - %s - %s', [Tag, t, s]);
  Memo1.Lines.Insert(0, m);
end;

procedure TForm31.Log(const sa: ansistring);
begin
  DoLog('a2U', string(sa));
end;

procedure TForm31.Log(const su: unicodestring);
begin
  DoLog('U2a', su);
end;

const ForcedLocale: LCID = LOCALE_USER_DEFAULT;

procedure ClipSetBuffer(const Format: Word; const Buffer: Pointer; Size: Integer);
  procedure InnerSetBuffer(const Format: Word; const Buffer: Pointer; Size: Integer);
  var
    Data: THandle;
    DataPtr: Pointer;
  begin
    Data := GlobalAlloc(GMEM_MOVEABLE+GMEM_DDESHARE, Size);
    try
      DataPtr := GlobalLock(Data);
      try
        Move(Buffer^, DataPtr^, Size);
        if SetClipboardData(Format, Data) = 0 then
           raise EOutOfResources.Create('SetClipboardData');
      finally
        GlobalUnlock(Data);
      end;
    except
      GlobalFree(Data);
      raise;
    end;
  end;
begin
  gb := OpenClipboard(Application.Handle);
  Win32Check(gb);
  try
    EmptyClipboard;

    InnerSetBuffer(Format, Buffer, Size );

//    NeedLocale;

    if InjectLCID then
       InnerSetBuffer(CF_LOCALE, @ForcedLocale, SizeOf(ForcedLocale));

//    NeedLocale;

  finally
    gb := CloseClipboard;
    Win32Check(gb);
  end;

//  NeedLocale;
end;

procedure SetClipAnsi(const sA: AnsiString);
begin
  ClipSetBuffer(CF_TEXT, @sA[1], SizeOf(sA[1])*(Length(sA) + 1));
end;

procedure SetClipUni (const sU: UnicodeString);
begin
  ClipSetBuffer(CF_UNICODETEXT, @sU[1], SizeOf(sU[1])*(Length(sU) + 1));
end;

procedure GetClipText(out Ansi, OEM: AnsiString;
    out U16: UnicodeString; out Locale: LCID);
var
  Data: THandle; Ptr: PCardinal;
begin
  gb := OpenClipboard(Application.Handle);
  Win32Check(gb);
  try
    if GuessLCID then
       TryFixPaste;

    Data := GetClipboardData(CF_LOCALE);
    try
      Locale := Cardinal(-1);
      if Data <> 0 then begin
        Ptr := GlobalLock(Data);
        if Ptr <> nil then
           Locale := Ptr^;
      end
    finally
      if Data <> 0 then
        GlobalUnlock(Data);
    end;

    Data := GetClipboardData(CF_UNICODETEXT);
    try
      if Data <> 0 then
        U16 := PWideChar(GlobalLock(Data))
      else
        U16 := '';
    finally
      if Data <> 0 then
        GlobalUnlock(Data);
    end;

    Data := GetClipboardData(CF_TEXT);
    try
      if Data <> 0 then
        Ansi := PAnsiChar(GlobalLock(Data))
      else
        Ansi := '';
    finally
      if Data <> 0 then
        GlobalUnlock(Data);
    end;

    Data := GetClipboardData(CF_OEMTEXT);
    try
      if Data <> 0 then
        OEM := PAnsiChar(GlobalLock(Data))
      else
        OEM := '';
    finally
      if Data <> 0 then
        GlobalUnlock(Data);
    end;

  finally
    gb := CloseClipboard;
    Win32Check(gb);
  end;
end;

function  GetClipAnsi: AnsiString;
var
  Ansi, OEM: AnsiString; U16: UnicodeString;
  Locale: LCID;
begin
  GetClipText(Ansi, OEM, U16, Locale);
  Result := Ansi;
end;

function  GetClipUni: UnicodeString;
var
  Ansi, OEM: AnsiString; U16: UnicodeString;
  Locale: LCID;
begin
  GetClipText(Ansi, OEM, U16, Locale);
  Result := U16;
end;

procedure TForm31.chkLocClick(Sender: TObject);
begin
  InjectLCID := chkLoc.Checked;
end;

function NeedLocale1: boolean;
var has_LC, has_TXT: boolean;
begin
  has_TXT := IsClipboardFormatAvailable(CF_TEXT)
     or IsClipboardFormatAvailable(CF_OEMTEXT)
     or IsClipboardFormatAvailable(CF_UNICODETEXT);
  has_LC := IsClipboardFormatAvailable(CF_LOCALE);
  Result := has_TXT and not has_LC;
end;

function NeedLocale2: boolean;
var
  Format: Word;
  has_LC, has_TXT: boolean;
begin
  has_LC := False; has_TXT := False;

  Format := EnumClipboardFormats(0);
  while Format <> 0 do begin
    if Format = CF_LOCALE then
       has_LC := True;
    if Format = CF_UNICODETEXT then
       has_TXT := True;
    if Format = CF_OEMTEXT then
       has_TXT := True;
    if Format = CF_TEXT then
       has_TXT := True;
    Format := EnumClipboardFormats(Format);
  end;

  Result := has_TXT and not has_LC;
end;

function NeedLocale: boolean;
var n1, n2: boolean; s: string;
begin
  n2 := NeedLocale2;
  n1 := NeedLocale1;

  s := 'CF_LOC[ ' + BoolToStr(n1, True) + '  /  ' + BoolToStr(n2, True) + ' ]';
  Application.MainForm.Caption := s;

  Assert( n1 = n2 );
  Result := n2;
end;

procedure TForm31.btnGetLCIDClick(Sender: TObject);
var Data: THandle; Ptr: Pointer; m: string;
    L: LCID; LP: LongRec absolute L;
begin
  if nil <> @GetThreadUILanguage then
     Memo1.Lines.Insert(0, '    - GetThreadUILanguage: ' + IntToHex(GetThreadUILanguage(),4));
  L := GetThreadLocale();
  m := Format('  - Thread LCID: %.8x   Language: %d  Sort: %d    Rsvd: %d',
       [L, LP.Lo, LP.Hi and 15, LP.Hi shr 4]);
  Memo1.Lines.Insert(0, m);
  if Clipboard.HasFormat(CF_LOCALE) then begin
     Data := Clipboard.GetAsHandle(CF_LOCALE);
     if Data <> 0 then begin
        Ptr := GlobalLock(Data);
        if nil = Ptr then begin
           ShowMessage('data Pointer was zero. Handle was ' + IntToHex(Data,8));
           FillChar(L, SizeOf(L), -1);
        end else begin
          Move(Ptr^, L, SizeOf(L));
        end;
        GlobalUnlock(Data);

//        m := '  - LCID: '+IntToHex(L,8) + Forma;
        m := Format('  - Clipboard LCID: %.8x   Language: %d  Sort: %d    Rsvd: %d',
             [L, LP.Lo, LP.Hi and 15, LP.Hi shr 4]);

        Memo1.Lines.Insert(0, m);
      end else
        ShowMessage('data Handle was zero');
  end else
     ShowMessage('there''s no CF_LOCALE in the clipboard');
end;

procedure TForm31.chkLocEuClick(Sender: TObject);
begin
  GuessLCID := chkLocEu.Checked;
end;

procedure TForm31.chkPatchOutClick(Sender: TObject);
var s: string;
begin
  if chkPatchOut.Checked
     then ClipboardLocaleFixOut.InstallHook
     else ClipboardLocaleFixOut.RemoveHook;

  s := 'Error code (zero for OK): ' + IntToStr(Ord(ClipboardLocaleFixOut.HookError))
     + '   Patch installed: ' + BoolToStr( ClipboardLocaleFixOut.HookInstalled );
  ShowMessage(s);
end;

procedure TForm31.FormHide(Sender: TObject);
begin
  if nil <> @RemoveClipboardFormatListener then
     RemoveClipboardFormatListener(Handle);
end;

procedure TForm31.FormShow(Sender: TObject);
var
  UPtr: THandle;
begin
  UPtr := LoadLibrary('user32.dll');

  Memo1.Lines.Add(
    IntToHex( NativeUInt(
        GetProcAddress( UPtr, 'CloseClipboard' )), 2*SizeOf(pointer))
  );

  AddClipboardFormatListener :=
       GetProcAddress( UPtr, 'AddClipboardFormatListener' );
  RemoveClipboardFormatListener :=
       GetProcAddress( UPtr, 'RemoveClipboardFormatListener' );
  GetThreadUILanguage :=
       GetProcAddress( LoadLibrary( kernel32 ), 'GetThreadUILanguage');

  if nil <> @AddClipboardFormatListener then
     AddClipboardFormatListener(Handle);

  SetClipboardViewer(Handle);
end;

procedure TForm31.WMCLIPBOARDUPDATE(var m: TMessage);
begin
  Memo1.Lines.Insert(0, '  *** WM_CLIPBOARDUPDATE  ' + IntToStr(GetClipboardSequenceNumber));
  inherited;
end;

procedure TForm31.WMDRAWCLIPBOARD(var m: TMessage);
begin
  Memo1.Lines.Insert(0, '  *** WM_DRAWCLIPBOARD  ' + IntToStr(GetClipboardSequenceNumber));
  inherited;
end;

end.
