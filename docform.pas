unit DocForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComponentHelper, Declarations;

type

  { TDocumentation }

  TDocumentation = class(TForm)
    DocLab: TLabel;
    DOCUMENTATION: TMemo;
    OkBtn: TButton;

 //================ COMMON PART FOR EACH FORM WITH componentChange values ============//
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure myChangeHandler(Sender : TObject);
    procedure mySelectionChangeHandler(Sender : TObject; used: boolean);

    procedure componentsInfoCreate;
    procedure componentsInfoDestroy;
    procedure OKBtnClick(Sender: TObject);
    procedure showValues;
    procedure NoOnChange;
  public
    FirstTime: boolean;
    ChangesMadeToDefaultValues: boolean;
    myComponentHelper: TComponentHelper;
    firstComponentChange: TComponentChange;
    onChangeHandler: TNotifyEvent;
    destructor Destroy; override;

//====== END COMMON PART =====//
  public

  end;

var
  Documentation: TDocumentation;

implementation

{$R *.lfm}

uses Utilities;

{ TDocumentation }

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TDocumentation.Destroy;
begin
  if not FirstTime then
    componentsInfoDestroy;
  inherited;
end;

procedure TDocumentation.FormCreate(Sender: TObject);
begin
  FirstTime := True;
  ChangesMadeToDefaultValues := false;
  onChangeHandler := @myChangeHandler;
end;

procedure TDocumentation.FormActivate(Sender: TObject);
begin
  if FirstTime then begin
    FirstTime := False;
  end else begin
    componentsInfoDestroy;
  end;
  componentsInfoCreate;
  showValues;
end;

procedure TDocumentation.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := true;
  NoOnChange;
end;

// ========= THE SAME PROCEDURE EXISTS, BUT WITH DIFFERENT CONTENT ============//
procedure TDocumentation.componentsInfoCreate;
var
  currentComponentChange: TComponentChange = nil;
begin
  myComponentHelper := TComponentHelper.Create;
  myComponentHelper.CreateComponentChange(FindComponent ('DOCUMENTATION'), g_GENPARAM.DOCUMENTATION, firstComponentChange, onChangeHandler);
  currentComponentChange := firstComponentChange;
end;

procedure TDocumentation.componentsInfoDestroy;
begin
  FreeAndNil (myComponentHelper);
  FreeAndNil (firstComponentChange);
end;

procedure TDocumentation.OKBtnClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TDocumentation.NoOnChange;
begin
  firstComponentChange.ActOnChange(false);
end;

procedure TDocumentation.showValues;
begin
  firstComponentChange.ShowValue;
  ChangesMadeToDefaultValues := checkChangedDefaultValues();
  firstComponentChange.ActOnChange(true);
end;

procedure TDocumentation.myChangeHandler(Sender : TObject);
begin
  firstComponentChange.ReadValue(TComponent (Sender).name);
  ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TDocumentation.mySelectionChangeHandler(Sender : TObject; used: boolean);
begin
  firstComponentChange.SelectedValue(TComponent (Sender).name, used);
  ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//


end.

