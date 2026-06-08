unit Lazkinoutputfields;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Declarations, ComponentHelper;

type

  { TKinOutputFields }

  TKinOutputFields = class(TForm)
  kinTypeDecedentsSelect: TCheckBox;
	shareDecedentsSelect: TCheckBox;
	yBirthFloatSelect: TCheckBox;
	ageFatherAtChildbirthSelect: TCheckBox;
	statusSelect: TCheckBox;
	cohortDemRegSelect: TCheckBox;
	motherUnionNumberSelect: TCheckBox;
	shareHeirsSelect: TCheckBox;
	heirsSelect: TCheckBox;
	kinTypeHeirsSelect: TCheckBox;
	decedentsSelect: TCheckBox;
	nChildrenSelect: TCheckBox;
	birthOrderSelect: TCheckBox;
	ageRelEgoSelect: TCheckBox;
	ageDeathSelect: TCheckBox;
	ageUnionSelect: TCheckBox;
	ageEndUnionSelect: TCheckBox;
	causeEndSelect: TCheckBox;
	ageMotherAtChildbirthSelect: TCheckBox;
	mBirthSelect: TCheckBox;
	yBirthSelect: TCheckBox;
	OkBtn: TButton;
	opFieldsGroup: TGroupBox;
	AllNoneBtn: TToggleBox;

	procedure AllNoneBtnChange(Sender: TObject);
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
	checkBoxValues: array [FieldNamesTypes] of BooleanName;
	initialValue: boolean;
  end;

var
  KinOutputFields: TKinOutputFields;

implementation

{$R *.lfm}
uses
	Utilities;

{ TKinOutputFields }
var
	opFields_array : array [FieldNamesTypes] of string = (
		'yBirth',
		'mBirth',
		'yBirthFloat',
		'yDeathFloat',
		'nChildren',
		'birthOrder',
		'ageRelEgo',
		'ageDeath',
		'ageUnion',
		'ageEndUnion',
		'causeEnd',
		'ageMotherAtChildbirth',
		'ageFatherAtChildbirth',
		'status',
		'cohortDemReg',
		'motherUnionNumber',
		'heirs',
        'shareHeirs',
        'kinTypeHeirs',
		'decedents',
		'shareDecedents',
		'kinTypeDecedents'
	);

procedure TKinOutputFields.AllNoneBtnChange(Sender: TObject);
var
	aField: FieldNamesTypes;
	aComp: TComponent;
begin
	for aField := low (FieldNamesTypes) to high(FieldNamesTypes) do begin
		aComp := FindComponent (opFields_array[aField] + 'Select');
		if aComp is TCheckBox then begin
			TCheckBox(aComp).Checked := not initialValue;
			if Assigned(TCheckBox(aComp).OnChange) then
				TCheckBox(aComp).OnChange(TCheckBox(aComp));
		end;
	end;
	initialValue := not initialValue;
end;

procedure TKinOutputFields.OkBtnClick(Sender: TObject);
begin
	ModalResult := mrClose;
end;

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TKinOutputFields.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TKinOutputFields.FormCreate(Sender: TObject);
begin
	FirstTime := True;
	initialValue := false;
	ChangesMadeToDefaultValues := false;
	onChangeHandler := @myChangeHandler;
	selectionChangeHandler := @mySelectionChangeHandler;
end;

procedure TKinOutputFields.FormActivate(Sender: TObject);
begin
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	showValues;
end;

procedure TKinOutputFields.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
	aField: FieldNamesTypes;
begin
	for aField := low (FieldNamesTypes) to high(FieldNamesTypes) do begin
		if (opFields_array[aField] <> '') then begin
			if checkBoxValues[aField].value then
				Include (g_GENPARAM.OUTPUT_FIELDS.value, aField)
			else
				Exclude (g_GENPARAM.OUTPUT_FIELDS.value, aField);
		end;
	end;
	CanClose := TRUE;
	NoOnChange;
	g_GENPARAM.OUTPUT_FIELDS.Changed := false;
	for aField := low (FieldNamesTypes) to high(FieldNamesTypes) do
		if (aField in g_GENPARAM.OUTPUT_FIELDS.value) xor (aField in g_GENPARAM.OUTPUT_FIELDS.default) then begin
			g_GENPARAM.OUTPUT_FIELDS.Changed := true;
			break;
		end;
end;

procedure TKinOutputFields.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
	aField: FieldNamesTypes;
	selected: boolean;
begin
	myComponentHelper := TComponentHelper.Create;
	firstComponentChange := nil;
	for aField := low (FieldNamesTypes) to high(FieldNamesTypes) do begin
		if (opFields_array[aField] <> '') then begin
			selected := aField in g_GENPARAM.OUTPUT_FIELDS.value;
			checkBoxValues[aField] := BooleanName.Create(selected, opFields_array[aField], 'Select or unselect ' + opFields_array[aField], nil);
			myComponentHelper.CreateComponentChange(FindComponent (opFields_array[aField] + 'Select'), checkBoxValues[aField], currentComponentChange, onChangeHandler);
			if firstComponentChange = nil then
				firstComponentChange := currentComponentChange;
		end;
	end;
end;

procedure TKinOutputFields.componentsInfoDestroy;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
end;

procedure TKinOutputFields.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TKinOutputFields.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TKinOutputFields.myChangeHandler(Sender: TObject);
begin
	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TKinOutputFields.mySelectionChangeHandler(Sender: TObject; used: boolean);
begin
	firstComponentChange.SelectedValue(TComponent (Sender).name, used);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//

end.

