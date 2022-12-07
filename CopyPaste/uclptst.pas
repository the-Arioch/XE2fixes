unit uclptst;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

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
    procedure FormCreate(Sender: TObject);
    procedure btnA2UClick(Sender: TObject);
    procedure btnCCCClick(Sender: TObject);
    procedure btnCECClick(Sender: TObject);
    procedure btnCOCClick(Sender: TObject);
    procedure btnCSDClick(Sender: TObject);
    procedure btnU2AClick(Sender: TObject);
    procedure chkLocClick(Sender: TObject);
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

uses AnsiStrings, Clipbrd;

procedure SetClipAnsi(const sA: AnsiString); forward;
procedure SetClipUni (const sU: UnicodeString); forward;
function  GetClipAnsi: AnsiString; forward;
function NeedLocale: boolean; forward;
{$R *.dfm}

var gb, InjectLCID: boolean;
  msgA: AnsiString = 'Жёлтый жёсткий жук';
  msgU: UnicodeString = 'Мерзкое мёрзлое место';


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
  Log( Clipboard.AsText );
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
  DoLog('a2U', sa);
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

function  GetClipAnsi: AnsiString;
var
  Data: THandle;
begin
  gb := OpenClipboard(Application.Handle);
  Win32Check(gb);

//  NeedLocale;

  Data := GetClipboardData(CF_TEXT);
  try
    if Data <> 0 then
      Result := PAnsiChar(GlobalLock(Data))
    else
      Result := '';
  finally
    if Data <> 0 then
      GlobalUnlock(Data);
    gb := CloseClipboard;
    Win32Check(gb);
  end;
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

procedure TForm31.FormHide(Sender: TObject);
begin
  RemoveClipboardFormatListener(Handle);
end;

procedure TForm31.FormShow(Sender: TObject);
begin
  AddClipboardFormatListener(Handle);
  SetClipboardViewer(Handle);

  Memo1.Lines.Add(
    IntToHex( NativeUInt(
        GetProcAddress( LoadLibrary('user32.dll'), 'CloseClipboard' )),
        2*SizeOf(pointer))
  );
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
