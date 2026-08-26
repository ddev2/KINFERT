unit LazDemoCareFields;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Declarations, ComponentHelper;

type

  { TDemoCareFields }

  TDemoCareFields = class(TForm)
	DEMOCARE_LARGE_FIELDS: TCheckBox;
	OkBtn: TButton;
	opFieldsGroup: TGroupBox;

	procedure OkBtnClick(Sender: TObject);
//================ COMMON PART FOR EACH FORM WITH componentChange values ============//

	procedure FormCreate(Sender: TObject);
	procedure FormActivate(Sender: TObject);
	procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
	procedure myChangeHandler(Sender : TObject);
	procedure mySelectionChangeHandler(Sender : TObject; used: boolean);

	procedure componentsInfoCreate;
	procedure componentsInfoDestroy;
	procedure showValues;
	procedure NoOnChange;
public
	destructor Destroy; override;
public
	FirstTime: boolean;
	ChangesMadeToDefaultValues: boolean;
	myComponentHelper: TComponentHelper;
	firstComponentChange: TComponentChange;
	onChangeHandler: TNotifyEvent;
	selectionChangeHandler: TSelectionChangeEvent;
//====== END COMMON PART =====//
  end;

var
  DemoCareFields: TDemoCareFields;

implementation

{$R *.lfm}
uses
	Utilities;

{ TDemoCareFields }

procedure TDemoCareFields.OkBtnClick(Sender: TObject);
begin
	ModalResult := mrClose;
end;

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TDemoCareFields.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TDemoCareFields.FormCreate(Sender: TObject);
begin
	FirstTime := True;
	ChangesMadeToDefaultValues := false;
	onChangeHandler := @myChangeHandler;
	selectionChangeHandler := @mySelectionChangeHandler;
end;

procedure TDemoCareFields.FormActivate(Sender: TObject);
begin
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	showValues;
end;

procedure TDemoCareFields.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
	CanClose := TRUE;
	NoOnChange;
end;

procedure TDemoCareFields.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
begin
	myComponentHelper := TComponentHelper.Create;
	firstComponentChange := nil;
	myComponentHelper.CreateComponentChange(FindComponent ('DEMOCARE_LARGE_FIELDS'), g_GENPARAM.DEMOCARE_LARGE_FIELDS, currentComponentChange, onChangeHandler);
	firstComponentChange := currentComponentChange;
end;

procedure TDemoCareFields.componentsInfoDestroy;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
end;

procedure TDemoCareFields.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TDemoCareFields.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TDemoCareFields.myChangeHandler(Sender: TObject);
begin
	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TDemoCareFields.mySelectionChangeHandler(Sender: TObject; used: boolean);
begin
	firstComponentChange.SelectedValue(TComponent (Sender).name, used);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//

end.
