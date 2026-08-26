unit LazKinDecedentSet;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Declarations, ComponentHelper;
type

  { TDecedentsSet }

  TDecedentsSet = class(TForm)
    AllNoneBtn: TButton;
    PartnerSelect: TCheckBox;
    greatGrandMotherSelect: TCheckBox;
    siblingSelect: TCheckBox;
    nieceNephewSelect: TCheckBox;
    grandNieceNephewSelect: TCheckBox;
    auntUncleSelect: TCheckBox;
    firstCousinSelect: TCheckBox;
    grandAuntUncleSelect: TCheckBox;
    ChildSelect: TCheckBox;
    grandChildSelect: TCheckBox;
    greatGrandChildSelect: TCheckBox;
    fatherSelect: TCheckBox;
    motherSelect: TCheckBox;
    grandFatherSelect: TCheckBox;
    grandMotherSelect: TCheckBox;
    greatGrandFatherSelect: TCheckBox;
    OkBtn: TButton;
    GroupBox1: TGroupBox;
    procedure AllNoneBtnClick(Sender: TObject);
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
	checkBoxValues: array [KinTypes] of BooleanName;
	initialValue: boolean;

  end;

var
  DecedentsSet: TDecedentsSet;

implementation

{$R *.lfm}
uses
	Utilities;

{ TDecedentsSet }
var
	str_kinship_select : array [KinTypes] of string = (
				'', '', 'partner', 'child', 'grandChild', 'greatGrandChild',
				'father', 'mother', 'sibling', 'nieceNephew', 'grandNieceNephew', '',
				'grandFather', 'grandMother', 'auntUncle', 'firstCousin', '', '', '',
				'greatGrandFather', 'greatGrandMother', 'grandAuntUncle', '', '', '',
				'',
				'', '');

procedure TDecedentsSet.OkBtnClick(Sender: TObject);
begin
        ModalResult := mrClose;
end;

procedure TDecedentsSet.AllNoneBtnClick(Sender: TObject);
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

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TDecedentsSet.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TDecedentsSet.FormCreate(Sender: TObject);
begin
	FirstTime := True;
	initialValue := false;
	ChangesMadeToDefaultValues := false;
	onChangeHandler := @myChangeHandler;
	selectionChangeHandler := @mySelectionChangeHandler;
end;

procedure TDecedentsSet.FormActivate(Sender: TObject);
begin
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	showValues;
end;

procedure TDecedentsSet.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
	aKin: KinTypes;
begin
	for aKin := low (KinTypes) to high(KinTypes) do begin
		if (str_kinship_select[aKin] <> '') then begin
			if checkBoxValues[aKin].value then
				Include (g_GENPARAM.DECEDENTS_KINTYPES.value, aKin)
			else
				Exclude (g_GENPARAM.DECEDENTS_KINTYPES.value, aKin);
		end;
	end;
	CanClose := true;
	NoOnChange;
	checkKinsetChange(g_GENPARAM.DECEDENTS_KINTYPES);
end;

procedure TDecedentsSet.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
	aKin: KinTypes;
	selected: boolean;
begin
	myComponentHelper := TComponentHelper.Create;
	firstComponentChange := nil;
	for aKin := low (KinTypes) to high(KinTypes) do begin
		if (str_kinship_select[aKin] <> '') then begin
			selected := aKin in g_GENPARAM.DECEDENTS_KINTYPES.value;
			checkBoxValues[aKin] := BooleanName.Create(selected, str_kinship[aKin], 'Select or unselect ' + str_kinship[aKin], nil);
			myComponentHelper.CreateComponentChange(FindComponent (str_kinship_select[aKin] + 'Select'), checkBoxValues[aKin], currentComponentChange, onChangeHandler);
			if firstComponentChange = nil then
				firstComponentChange := currentComponentChange;
		end;
	end;
end;

procedure TDecedentsSet.componentsInfoDestroy;
var
	ind: KinTypes;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
	{the BooleanName objects are created in componentsInfoCreate with no owner,
	 so they have to be released here, otherwise every open of this dialog leaks}
	for ind := low(KinTypes) to high(KinTypes) do
		FreeAndNil (checkBoxValues[ind]);
end;

procedure TDecedentsSet.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TDecedentsSet.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TDecedentsSet.myChangeHandler(Sender : TObject);
begin
	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TDecedentsSet.mySelectionChangeHandler(Sender : TObject; used: boolean);
begin
	firstComponentChange.SelectedValue(TComponent (Sender).name, used);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//

end.

