unit LazLowlevel;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
	ComponentHelper;

type

	{ TLowLevelForm }

	TLowLevelForm = class(TForm)
		AGE_FIXED_DEFINITIVE_STERILITY_: TEdit;
		BaseNumberLab: TLabel;
		OPTIMAL_TREES: TEdit;
		FORCE_SEP_ITER: TCheckBox;
		optimalTreesLab: TLabel;
		MODEGO: TEdit;
		modEgoLab: TLabel;
		USE_ARRAY_CHILDREN: TCheckBox;
		FORCE_PPR_TARGET: TCheckBox;
		LowLevelFertilityGroup: TGroupBox;
		LowLevelOthersGroup: TGroupBox;
		NUMBER_WOMEN: TEdit;
		OKBtn: TButton;
		FIXED_DEFINITIVE_STERILITY: TCheckBox;
		NO_INITIAL_STERILITY: TCheckBox;
		KINFERT_STERILITY: TCheckBox;
		LERIDON_STERILITY: TCheckBox;
		LowLevelSterilityGroup: TGroupBox;
		NORMAL_HETEROGENEITY_FECUNDABILITY: TCheckBox;
		LowLevelFecundabilityGroup: TGroupBox;
		RESHUFFLED_FECUNDABILITY: TCheckBox;
		HOMOGENEOUS_FECUNDABILITY: TCheckBox;
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

	end;

var
	LowLevelForm: TLowLevelForm;

implementation
uses
	Declarations, Utilities;

{$R *.lfm}

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TLowLevelForm.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TLowLevelForm.FormCreate(Sender: TObject);
begin
	FirstTime := True;
	ChangesMadeToDefaultValues := false;
	onChangeHandler := @myChangeHandler;
end;

procedure TLowLevelForm.FormActivate(Sender: TObject);
begin
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	showValues;
end;

procedure TLowLevelForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
	CanClose := TRUE;
	NoOnChange;
end;

// ========= THE SAME PROCEDURE EXISTS, BUT WITH DIFFERENT CONTENT ============//
procedure TLowLevelForm.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
begin
	myComponentHelper := TComponentHelper.Create;
	myComponentHelper.CreateComponentChange(FindComponent ('HOMOGENEOUS_FECUNDABILITY'), g_GENPARAM.fixedParameters [homogeneousFecundability].state, firstComponentChange, onChangeHandler);
	currentComponentChange := firstComponentChange;
	myComponentHelper.CreateComponentChange(FindComponent ('RESHUFFLED_FECUNDABILITY'), g_GENPARAM.fixedParameters [reshuffledFecundability].state, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('NORMAL_HETEROGENEITY_FECUNDABILITY'), g_GENPARAM.fixedParameters [normaldistributionfecundability].state, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('LERIDON_STERILITY'), g_GENPARAM.fixedParameters [LeridonDefinitiveSterility].state, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('KINFERT_STERILITY'));
	currentComponentChange.ChangeDisablingState (FindComponent ('KINFERT_STERILITY'), TRUE);
	myComponentHelper.CreateComponentChange(FindComponent ('KINFERT_STERILITY'), g_GENPARAM.fixedParameters [KinFertDefinitiveSterility].state, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('LERIDON_STERILITY'));
	currentComponentChange.ChangeDisablingState (FindComponent ('LERIDON_STERILITY'), TRUE);
	myComponentHelper.CreateComponentChange(FindComponent ('NO_INITIAL_STERILITY'), g_GENPARAM.fixedParameters [noInitialSterility].state, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FIXED_DEFINITIVE_STERILITY'), g_GENPARAM.fixedParameters [fixedDefinitiveSterility].state, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('AGE_FIXED_DEFINITIVE_STERILITY_'));
	myComponentHelper.CreateComponentChange(FindComponent ('AGE_FIXED_DEFINITIVE_STERILITY_'), g_GENPARAM.fixedParameters [fixedDefinitiveSterility].param, currentComponentChange, onChangeHandler, kIsDouble, 26, 59);
	myComponentHelper.CreateComponentChange(FindComponent ('FORCE_PPR_TARGET'), g_GENPARAM.FORCE_PPR_TARGET, currentComponentChange, onChangeHandler, kIsInteger);
	myComponentHelper.CreateComponentChange(FindComponent ('FORCE_SEP_ITER'), g_GENPARAM.FORCE_SEP_ITER, currentComponentChange, onChangeHandler, kIsInteger);
	myComponentHelper.CreateComponentChange(FindComponent ('USE_ARRAY_CHILDREN'), g_GENPARAM.USE_ARRAY_CHILDREN, currentComponentChange, onChangeHandler, kIsInteger);
	myComponentHelper.CreateComponentChange(FindComponent ('MODEGO'), g_GENPARAM.MODEGO, currentComponentChange, onChangeHandler, kIsInteger);
	myComponentHelper.CreateComponentChange(FindComponent ('OPTIMAL_TREES'), g_GENPARAM.OPTIMAL_TREES, currentComponentChange, onChangeHandler, kIsInteger);
	myComponentHelper.CreateComponentChange(FindComponent ('NUMBER_WOMEN'), g_GENPARAM.RUNTIME[cmd_numberWomen], currentComponentChange, onChangeHandler, kIsInteger);
end;

procedure TLowLevelForm.componentsInfoDestroy;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
end;

procedure TLowLevelForm.OKBtnClick(Sender: TObject);
begin
	ModalResult := mrClose;
end;

procedure TLowLevelForm.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TLowLevelForm.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TLowLevelForm.myChangeHandler(Sender : TObject);
begin
	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TLowLevelForm.mySelectionChangeHandler(Sender : TObject; used: boolean);
begin
	firstComponentChange.SelectedValue(TComponent (Sender).name, used);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//

end.
