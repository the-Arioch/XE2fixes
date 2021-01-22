unit dbx_FB_no_ini;

(* How to deploy a database application without a DBXDrivers.ini file.
   XE2 + Firebird 2.x port, with some tweaks.
   Original: http://andy.jgknet.de/blog/2010/11/dbx-without-deploying-dbxdrivers-ini/
   Now: https://www.idefixpack.de/blog/2010/11/dbx-without-deploying-dbxdrivers-ini/
   
   Quote: If you want to connect to an other database vendor, you 
     have to adjust the string literals in TDBXInternalProperties.Create 
	 and the driver name in the RegisterDriverClass(СMySQLТ, ..) call. 
   I could not override DBX "Interbase" driver with this trick, perhaps
     dbx4 FB driver has some extra checks inside. So moving the dbx3 
	 project to dbx4 requires driver name change.
   
   One can also use this as a sample to load Firebird Embedded DLL into
   dbExpress 4 based application without dirty tricks like renaming 
   Firebird DLLs. 
*)



interface

implementation

uses
  DBXCommon, DBXDynalinkNative, Data.DBXFirebird {required for connection!!!};

type
  TDBXInternalDriver = class(TDBXDynalinkDriverNative)
  public
    constructor Create(DriverDef: TDBXDriverDef); override;
  end;

  TDBXInternalProperties = class(TDBXProperties)
  public
    constructor Create(DBXContext: TDBXContext); override;
  end;

{ TDBXInternalDriver }

constructor TDBXInternalDriver.Create(DriverDef: TDBXDriverDef);
begin
  inherited Create(DriverDef, TDBXDynalinkDriverLoader);
  InitDriverProperties(TDBXInternalProperties.Create(DriverDef.FDBXContext));
end;

{ TDBXInternalProperties }

constructor TDBXInternalProperties.Create(DBXContext: TDBXContext);
begin
  inherited Create(DBXContext);

(*
DriverUnit=Data.DBXFirebird
DriverPackageLoader=TDBXDynalinkDriverLoader,DbxCommonDriver160.bpl
DriverAssemblyLoader=Borland.Data.TDBXDynalinkDriverLoader,Borland.Data.DbxCommonDriver,Version=16.0.0.0,Culture=neutral,PublicKeyToken=91d62ebb5b0d1b1b
MetaDataPackageLoader=TDBXFirebirdMetaDataCommandFactory,DbxFirebirdDriver160.bpl
MetaDataAssemblyLoader=Borland.Data.TDBXFirebirdMetaDataCommandFactory,Borland.Data.DbxFirebirdDriver,Version=16.0.0.0,Culture=neutral,PublicKeyToken=91d62ebb5b0d1b1b
GetDriverFunc=getSQLDriverINTERBASE
LibraryName=dbxfb.dll
LibraryNameOsx=libsqlfb.dylib
VendorLib=fbclient.dll
VendorLibWin64=fbclient.dll
VendorLibOsx=/Library/Frameworks/Firebird.framework/Firebird
BlobSize=-1
CommitRetain=False
Database=database.fdb
ErrorResourceFile=
LocaleCode=0000
Password=masterkey
RoleName=RoleName
ServerCharSet=
SQLDialect=3
IsolationLevel=ReadCommitted
User_Name=sysdba
WaitOnLocks=True
Trim Char=False  *)

  Values[TDBXPropertyNames.DriverUnit] := ''; // This is for the IDE only

  Values[TDBXPropertyNames.GetDriverFunc] := 'getSQLDriverINTERBASE';
  Values[TDBXPropertyNames.LibraryName] := 'dbxfb.dll';
  Values[TDBXPropertyNames.VendorLib] := 'fbclient.dll';
//  Values[TDBXPropertyNames.VendorLibWin64] := 'fbclient.dll';


  Values[TDBXPropertyNames.Database] := 'DatabaseName.fdb';
  Values[TDBXPropertyNames.UserName] := 'sysdba';
  Values[TDBXPropertyNames.Password] := 'masterkey';

  Values[TDBXPropertyNames.MaxBlobSize] := '-1';

  Values['WaitOnLocks'] := 'True';
  Values['Trim Char']   := 'False';

  Values['SQLDialect'] := '3';
  Values['CommitRetain'] := 'False';

  Values['DriverUnit'] := 'Data.DBXFirebird';
//  Values['DriverPackageLoader'] := 'TDBXDynalinkDriverLoader,DbxCommonDriver160.bpl';
//  Values['DriverAssemblyLoader'] := 'Borland.Data.TDBXDynalinkDriverLoader,Borland.Data.DbxCommonDriver,Version=16.0.0.0,Culture=neutral,PublicKeyToken=91d62ebb5b0d1b1b';
//  Values['MetaDataPackageLoader'] := 'TDBXFirebirdMetaDataCommandFactory,DbxFirebirdDriver160.bpl';
//  Values['MetaDataAssemblyLoader'] := 'Borland.Data.TDBXFirebirdMetaDataCommandFactory,Borland.Data.DbxFirebirdDriver,Version=16.0.0.0,Culture=neutral,PublicKeyToken=91d62ebb5b0d1b1b';
end;

var
  InternalConnectionFactory: TDBXMemoryConnectionFactory;

initialization
  TDBXDriverRegistry.RegisterDriverClass('Firebird', TDBXInternalDriver);
//  TDBXDriverRegistry.RegisterDriverClass('Interbase', TDBXInternalDriver);
//     не помогает, надо править параметры TSQLConnection
//     this does not work, one has to override driver name in TSQLConnection

  InternalConnectionFactory := TDBXMemoryConnectionFactory.Create;
  InternalConnectionFactory.Open;
  TDBXConnectionFactory.SetConnectionFactory(InternalConnectionFactory);
end.
