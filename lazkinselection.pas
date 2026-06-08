unit LazKinSelection;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Declarations, ComponentHelper;

type

  { TKinSelectionForm }

  TKinSelectionForm = class(TForm)
	NON_BIO_KIN: TCheckBox;
	OkBtn: TButton;
	selectAllNoneBtn: TButton;
	secondCousinTwiceSelect: TCheckBox;
	secondCousinOnceSelect: TCheckBox;
	secondCousinSelect: TCheckBox;
	greatFirstCousinOnceSelect: TCheckBox;
	grandMotherSelect: TCheckBox;
	auntUncleSelect: TCheckBox;
	grandAuntUncleSelect: TCheckBox;
	greatGrandMotherSelect: TCheckBox;
	greatGrandFatherSelect: TCheckBox;
	firstCousinThriceSelect: TCheckBox;
	firstCousinTwiceSelect: TCheckBox;
	firstCousinOnceSelect: TCheckBox;
	greatGrandNieceNephewSelect: TCheckBox;
	grandNieceNephewSelect: TCheckBox;
	firstCousinSelect: TCheckBox;
	consanguinityTree: TImage;
	nieceNephewSelect: TCheckBox;
	grandfatherSelect: TCheckBox;
	siblingSelect: TCheckBox;
	motherSelect: TCheckBox;
	fatherSelect: TCheckBox;
	grandChildSelect: TCheckBox;
	greatGrandChildSelect: TCheckBox;
	childSelect: TCheckBox;
	partnerSelect: TCheckBox;
	KinToSimulBox: TGroupBox;
	procedure OkBtnClick(Sender: TObject);
	procedure selectAllNoneBtnClick(Sender: TObject);
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
	checkBoxValues: array [KinTypes] of BooleanName;
	initialValue: boolean;
end;

var
  KinSelectionForm: TKinSelectionForm;

implementation

{$R *.lfm}
uses
	Utilities;

{ TKinSelectionForm }
var
	str_kinship_select : array [KinTypes] of string = (
				'', '', 'partner', 'child', 'grandChild', 'greatGrandChild',
				'father', 'mother', 'sibling', 'nieceNephew', 'grandNieceNephew', 'greatGrandNieceNephew',
				'grandFather', 'grandMother', 'auntUncle', 'firstCousin', 'firstCousinOnce', 'firstCousinTwice', 'firstCousinThrice',
				'greatGrandFather', 'greatGrandMother', 'grandAuntUncle', 'greatFirstCousinOnce', 'secondCousin', 'secondCousinOnce',
				'secondCousinTwice',
				'', '');


procedure TKinSelectionForm.selectAllNoneBtnClick(Sender: TObject);
var
	aKin: KinTypes;
	aComp: TComponent;
begin
	for aKin := low (KinTypes) to high(KinTypes) do begin
		aComp := FindComponent (str_kinship_select[aKin] + 'Select');
		if aComp is TCheckBox then begin
			TCheckBox(aComp).Checked := not initialValue;
			if Assigned(TCheckBox(aComp).OnChange) then
				TCheckBox(aComp).OnChange(TCheckBox(aComp));
		end;
	end;
	initialValue := not initialValue;
end;

procedure TKinSelectionForm.OkBtnClick(Sender: TObject);
begin
	ModalResult := mrClose;
end;

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TKinSelectionForm.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TKinSelectionForm.FormCreate(Sender: TObject);
begin
	FirstTime := True;
	initialValue := false;
	ChangesMadeToDefaultValues := false;
	onChangeHandler := @myChangeHandler;
	selectionChangeHandler := @mySelectionChangeHandler;
end;

procedure TKinSelectionForm.FormActivate(Sender: TObject);
begin
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	showValues;
end;

procedure TKinSelectionForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
	aKin: KinTypes;
begin
	for aKin := low (KinTypes) to high(KinTypes) do begin
		if (str_kinship_select[aKin] <> '') then begin
			if checkBoxValues[aKin].value then
				Include (g_GENPARAM.OUTPUT_KINTYPES.value, aKin)
			else
				Exclude (g_GENPARAM.OUTPUT_KINTYPES.value, aKin);
		end;
	end;
	CanClose := TRUE;
	NoOnChange;
	checkKinsetChange (g_GENPARAM.OUTPUT_KINTYPES);
end;

procedure TKinSelectionForm.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
	aKin: KinTypes;
	selected: boolean;
begin
	myComponentHelper := TComponentHelper.Create;
	myComponentHelper.CreateComponentChange(FindComponent ('NON_BIO_KIN'), g_GENPARAM.NON_BIO_KIN, firstComponentChange, onChangeHandler);
	currentComponentChange := firstComponentChange;
	for aKin := low (KinTypes) to high(KinTypes) do begin
		if (str_kinship_select[aKin] <> '') then begin
			selected := aKin in g_GENPARAM.OUTPUT_KINTYPES.value;
			checkBoxValues[aKin] := BooleanName.Create(selected, str_kinship[aKin], 'Select or unselect ' + str_kinship[aKin], nil);
			myComponentHelper.CreateComponentChange(FindComponent (str_kinship_select[aKin] + 'Select'), checkBoxValues[aKin], currentComponentChange, onChangeHandler);
		end;
	end;
end;

procedure TKinSelectionForm.componentsInfoDestroy;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
end;

procedure TKinSelectionForm.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TKinSelectionForm.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TKinSelectionForm.myChangeHandler(Sender : TObject);
begin
	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TKinSelectionForm.mySelectionChangeHandler(Sender : TObject; used: boolean);
begin
	firstComponentChange.SelectedValue(TComponent (Sender).name, used);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//
end.

