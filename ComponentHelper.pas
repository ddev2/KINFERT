{$I Defines.pas}
unit ComponentHelper;
interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils, Controls, Forms, Grids, StdCtrls, ValEdit, Dialogs, Graphics,
	Declarations;

const
	kIsInteger = 0;
	kIsDouble = 1;
	kIsString = 2;

var
	gCheckSelected: boolean = TRUE;
	//gFocusHandler: TNotifyEvent = NIL;

	procedure EnableControl (form: TForm; name: string; state: boolean = TRUE);
	procedure checkKinsetChange (ks: KinListName);
	
type

	TUnCheckIfFalse = class
		controlToUncheck: TCheckBox;
		myInverse: boolean;
		next: TUnCheckIfFalse;
	public
		constructor Create (C: TComponent; inverse: boolean = false); overload;
		destructor Destroy; override;
		procedure setChecked (val: boolean = false);
	end;
	
	TEnableDisable = class
	private
		ControlDisabled: TControl;
		ValDisabling: longint;
		TestValEnabled: boolean;
		DisablingState: boolean;
		ValEnabled_min, ValEnabled_max: longint;
		next: TEnableDisable;
	public
		constructor Create (C: TComponent; val, valMax: longint); overload;
		destructor Destroy; override;
		procedure setEnabledState (aVal: boolean); virtual;
		procedure update (aVal: longint);
		procedure updateFloat (aVal: double);
	end;

	TEnableDisable_StablePop = class(TEnableDisable)
		procedure setEnabledState (aVal: boolean); override;
	end;

	TComponentChange = class(TControl)
	private
		Component: TControl;
		// linked list of other components that can be disabled depending on the state of this one
		disableAction: TEnableDisable;
		// linked list of other components that need to be unchecked (if that apply) if this component is inactive
		uncheckList: TUnCheckIfFalse;
		
		myVal: GenericName;
		next: TComponentChange;
		componentsToUpdate: array of TComponentChange;


	public
		constructor Create (C: TComponent; p: GenericName); overload;
		destructor Destroy; override;
		procedure setMyHint;
		procedure showMyHint(state: boolean);
		function canShowHint: boolean;
		procedure ActivateDisabling (C: TComponent;
				val: longint = kNotUsed; valMax: longint = kNotUsed;
				DisablingStateInit: boolean = false); virtual;
		procedure ActivateUnCheck (C: TComponent; inverse: boolean = false); virtual;
		procedure ChangeDisablingState (C: TComponent; state: boolean);
		procedure ValidateAndReadValue (myName: string; aCol, aRow: Integer; const OldValue: string; var NewValue: string);
		procedure myValidateAndGetValue (aCol, aRow: Integer; const OldValue: string; var NewValue: string); virtual;
		procedure SelectedValue (myName: string; used: boolean);
		procedure myEnableDisable; virtual;
		procedure myUncheck (state: boolean); virtual;
		procedure mySelectedValue (used: boolean); virtual;
		procedure ReadValue (myName: string);
		procedure ShowValue;
		procedure ActOnChange (state: boolean);
		procedure UpdateOtherOnChange (C: TComponentChange);
		procedure UpdateValue (p: GenericName); virtual;
		procedure mySetOnChange (e: TNotifyEvent); virtual;
		procedure SetOnChange (state: boolean); virtual; abstract;
		procedure mySetValue; virtual; abstract;
		procedure myGetValue; virtual;
		procedure myCheckChanged; virtual; abstract;
		procedure showChange; virtual; abstract;
	end;

	TComponentChange_StablePop = class(TComponentChange)
		procedure ActivateDisabling (C: TComponent;
				val: longint = kNotUsed; valMax: longint = kNotUsed;
				DisablingStateInit: boolean = false); override;
	end;
	
	TComponentChangeNotifyEvent = class(TComponentChange)
	private
		onChangeHandler: TNotifyEvent;
	public
		constructor Create (C: TComponent; p: GenericName; e: TNotifyEvent); overload;
		procedure mySetOnChange (e: TNotifyEvent); override;
	end;

	TCheckBoxChange = class(TComponentChangeNotifyEvent)
	public
		procedure SetOnChange (state: boolean); override;
		procedure myEnableDisable; override;
		procedure myUncheck (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TToggleBoxChange = class(TComponentChangeNotifyEvent)
	public
		procedure SetOnChange (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TEditChange = class(TComponentChangeNotifyEvent)
	private
		editType: longint;
		minValue, maxValue: longint;
		checkValue: boolean;
	public
		constructor Create (C: TComponent; p: GenericName; e: TNotifyEvent; minV: longint = 0; maxV: longint = 0); overload;
		procedure SetOnChange (state: boolean); override;
		procedure myEnableDisable; override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TEditChange_CTFR = class(TEditChange)
	public
		procedure UpdateValue(p: GenericName); override;
	end;

	TEditChange_lastCohort = class(TEditChange)
	public
		procedure UpdateValue(p: GenericName); override;
	end;

	TMemoChange = class(TComponentChangeNotifyEvent)
	public
		procedure SetOnChange (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TEduComboBoxChange = class(TComponentChangeNotifyEvent)
	public
		procedure SetOnChange (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TKinFmtComboBoxChange = class(TComponentChangeNotifyEvent)
	public
		procedure SetOnChange (state: boolean); override;
		procedure selectFields(itemSelected: longint);
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TCountryInheritanceComboBoxChange = class(TComponentChangeNotifyEvent)
	public
		procedure SetOnChange (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TCohortComboBoxChange = class(TComponentChangeNotifyEvent)
	private
		myCohorts: arrayOflongint;
	public
		destructor Destroy; override;
		procedure getCohorts;
		procedure SetOnChange (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
		procedure UpdateValue (p: GenericName); override;
	end;

	TFixedFertComboBoxChange = class(TComponentChangeNotifyEvent)
	private
		myTFRs: arrayOflongint;
	public
		destructor Destroy; override;
		procedure getTFRs;
		procedure SetOnChange (state: boolean); override;
		procedure mySetValue; override;
		procedure myGetValue; override;
		procedure myCheckChanged; override;
		procedure showChange; override;
		procedure UpdateValue (p: GenericName); override;
	end;

	TComponentChangeValidateEntryEvent = class(TComponentChange)
	private
		onValidateHandler: TValidateEntryEvent;
		maxValueShown, maxValueDataset: longint;
		minValue, maxValue: longint;
	public
		constructor Create (C: TComponent; p: GenericName; e: TValidateEntryEvent; mvs, mvd: longint; minV: longint = 0; maxV: longint = 1); overload;
		destructor Destroy; override;
		procedure mySetOnChange (e: TValidateEntryEvent); overload;
		procedure SetOnChange (state: boolean); override;
		procedure myGetValue; override;
		procedure mySetValue; override;
		procedure myValidateAndGetValue (aCol, aRow: Integer; const OldValue: string; var NewValue: string); override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TComponentChangeSelectionChangeEvent = class(TComponentChange)
	private
		onSelectionChangeHandler: TSelectionChangeEvent;
	public
		constructor Create (C: TComponent; p: GenericName; e: TSelectionChangeEvent); overload;
		procedure mySetOnChange (e: TSelectionChangeEvent); overload;
		procedure SetOnChange (state: boolean); override;
	end;

	TKinListBoxChange = class(TComponentChangeSelectionChangeEvent)
	public
		procedure mySetValue; override;
		procedure mySelectedValue (used: boolean); override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TFieldListBoxChange = class(TComponentChangeSelectionChangeEvent)
	public
		procedure mySetValue; override;
		procedure mySelectedValue (used: boolean); override;
		procedure myCheckChanged; override;
		procedure showChange; override;
	end;

	TComponentHelper = class
		constructor Create;
		procedure CreateComponentChange (aComp: TComponent; p: GenericName; var lastComponentChange: TComponentChange; e: TNotifyEvent;
			EditType: longint = kIsDouble; minValueInput: longint = 0; maxValueInput: longint = 0; maxValueShown: longint = 0; maxValueDataset: longint = 0);
	end;

implementation

uses
	ReadCmdFileUnit, DemographicRegime, LazConfig, LazOutput;

	procedure EnableControl (form: TForm; name: string; state: boolean = TRUE);
	begin
		TControl (form.FindComponent (name)).enabled := state;
	end;

	procedure checkKinsetChange (ks: KinListName);
	var
		rel: KinTypes;
	begin
		ks.Changed := false;
		for rel := low(KinTypes) to high(KinTypes) do
			if (rel in ks.value) xor (rel in ks.default) then begin
				ks.Changed := true;
				exit;
			end;
	end;

	function strToDouble (input: string): double;
	var
		tempDec: char;
	begin
		tempDec := DefaultFormatSettings.DecimalSeparator;
		DefaultFormatSettings.DecimalSeparator := '.';
		commaToPeriod (input);
		strToDouble := strToFloat (input);
		DefaultFormatSettings.DecimalSeparator := tempDec;
	end;

	constructor TUnCheckIfFalse.Create (C: TComponent; inverse: boolean = false); overload;
	begin
		inherited Create();
		controlToUncheck := TCheckBox (C);
		myInverse := inverse;
		next := nil;
	end;
	
	destructor TUnCheckIfFalse.Destroy;
	begin
		if next <> nil then begin
			next.Destroy;
			next := nil;
		end;
		inherited;
	end;
	
	procedure TUnCheckIfFalse.setChecked (val: boolean = false);
	begin
		if myInverse then
			if val then
				controlToUncheck.checked := false
			else
				controlToUncheck.checked := true
		else if not val then
			controlToUncheck.checked := false
	end;

	constructor TEnableDisable.Create (C: TComponent; val, valMax: longint); overload;
	begin
		inherited Create();
		next := nil;
		ControlDisabled := TControl (C);
		ValDisabling := val;
		TestValEnabled := valMax <> kNotUsed;
		// The dependent control will be disabled if the main control is a checkbox in state DisablingState
		// This can be reversed setting DisablingState to TRUE
		DisablingState := false;
		ValEnabled_min := val;
		ValEnabled_max := valMax;
	end;

	destructor TEnableDisable.Destroy();
	begin
		if next <> nil then begin
			next.Destroy;
			next := nil;
		end;
		inherited;
	end;

	procedure TEnableDisable.setEnabledState (aVal: boolean);
	begin
		ControlDisabled.Enabled := (aVal = not DisablingState);
		ControlDisabled.showHint := ControlDisabled.Enabled;
	end;
	
	procedure TEnableDisable.update (aVal: longint);
	begin
		if TestValEnabled then begin
			ControlDisabled.Enabled := (aVal > ValEnabled_min) and (aVal <= ValEnabled_max);
		end else begin
			ControlDisabled.Enabled := (aVal <> ValDisabling)
		end;
	end;

	procedure TEnableDisable.updateFloat (aVal: double);
	begin
		update (trunc (aVal * 10000));
	end;

	procedure TEnableDisable_StablePop.setEnabledState (aVal: boolean);
	begin
		ControlDisabled.Enabled := stablePopulation ();
	end;

	constructor TComponentHelper.Create;
	begin
		inherited;
	end;

	procedure TComponentHelper.CreateComponentChange (aComp: TComponent; p: GenericName; var lastComponentChange: TComponentChange; e: TNotifyEvent;
		editType: longint = kIsDouble; minValueInput: longint = 0; maxValueInput: longint = 0; maxValueShown: longint = 0; maxValueDataset: longint = 0);
	var
		aCompChange: TComponentChange;
	begin
		if aComp = nil then
		begin
			exit;
		end;

		//if (gFocusHandler <> nil) and aComp.InheritsFrom(TWinControl) then begin
			//TWinControl(aComp).onEnter := gFocusHandler;
		//end;

		if aComp is TCheckBox then
		begin
			aCompChange := TCheckBoxChange.Create(aComp, p, e);
		end else if aComp is TToggleBox then
		begin
			aCompChange := TToggleBoxChange.Create(aComp, p, e);
		end else if aComp is TEdit then
		begin
			if aComp.name = 'CTFR' then begin
				aCompChange := TEditChange_CTFR.Create(aComp, p, e, minValueInput, maxValueInput);
			end else if aComp.name = 'LAST_COHORT' then begin
				aCompChange := TEditChange_lastCohort.Create(aComp, p, e, minValueInput, maxValueInput);
			end else begin
				aCompChange := TEditChange.Create(aComp, p, e, minValueInput, maxValueInput);
			end;
			TEditChange(aCompChange).editType := editType;
		end else if aComp is TMemo then
		begin
			aCompChange := TMemoChange.Create(aComp, p, e);
		end else if aComp is TListBox then
		begin
			if aComp.name = 'KinList_' then begin
				aCompChange := TKinListBoxChange.Create(aComp, p, TSelectionChangeEvent(e));
			end else if aComp.name = 'OutputFileFields_' then begin
				aCompChange := TFieldListBoxChange.Create(aComp, p, TSelectionChangeEvent(e));
			end;
		end else if aComp is TComboBox then
		begin
			if aComp.name = 'EDUCATION' then begin
				aCompChange := TEduComboBoxChange.Create(aComp, p, e);
			end else if aComp.name = 'COHORTS' then begin
				aCompChange := TCohortComboBoxChange.Create(aComp, p, e);
			end else if aComp.name = 'FIXED_FERTILITY_VALUE' then begin
				aCompChange := TFixedFertComboBoxChange.Create(aComp, p, e);
			end else if aComp.name = 'KINSHIP_INDIV_FORMAT' then begin
				aCompChange := TKinFmtComboBoxChange.Create(aComp, p, e);
			end else if aComp.name = 'COUNTRY_INHERITANCE_RULES' then begin
				aCompChange := TCountryInheritanceComboBoxChange.Create(aComp, p, e);
			end;
		end else if aComp is TValueListEditor then
		begin
			aCompChange := TComponentChangeValidateEntryEvent.Create(aComp, p, TValidateEntryEvent(e), maxValueShown, maxValueDataset, minValueInput, maxValueInput);
		end;
		if lastComponentChange <> nil then
			lastComponentChange.next := aCompChange;
		lastComponentChange := aCompChange
	end;

	constructor TComponentChange.Create (C: TComponent; p: GenericName);
	begin
		inherited Create(C);
		next := nil;
		disableAction := nil;
		Component := TControl (C);
		myVal := p;
		self.showMyHint (false);
		if self.canShowHint then begin
			setMyHint;
			self.showMyHint (true);
		end;
	end;

	destructor TComponentChange.Destroy();
	begin
		if next <> nil then begin
			next.Destroy;
			next := nil;
		end;
		if disableAction <> nil then
			disableAction.Destroy();
		setLength (componentsToUpdate, 0);
		inherited;
	end;

	procedure TComponentChange.setMyHint;
	begin
		if myVal.comment = '' then
			Component.Hint := Component.name
		else if copy (Component.name, length(Component.name), 1) = '_' then
			Component.Hint := myVal.comment
		else
			Component.Hint := Component.name + LineEnding + myVal.comment + LineEnding + 'Default value: ' + myVal.defaultValue;
	end;

	procedure TComponentChange.showMyHint(state: boolean);
	begin
		Component.ShowHint := state;
	end;
	
	function TComponentChange.canShowHint: boolean;
	begin
		result := myVal.name <> '';
	end;
	
	procedure TComponentChange.ActivateUnCheck (C: TComponent; inverse: boolean = false);
	var
		lastUnCheck: TUnCheckIfFalse;
	begin
		if uncheckList = nil then begin
			uncheckList := TUnCheckIfFalse.Create (C, inverse);
			uncheckList.next := nil;
			exit;
		end;
		lastUnCheck := uncheckList;
		while lastUnCheck.next <> nil do begin
			lastUnCheck := lastUnCheck.next;
		end;
		lastUnCheck.next := TUnCheckIfFalse.Create (C, inverse);
	end;

	procedure TComponentChange.ActivateDisabling (C: TComponent;
			val: longint = kNotUsed; valMax: longint = kNotUsed;
			DisablingStateInit: boolean = false);
	var
		lastAction: TEnableDisable;
	begin
		if disableAction = nil then begin
			disableAction := TEnableDisable.Create (C, val, valMax);
			disableAction.DisablingState := DisablingStateInit;
			disableAction.next := nil;
			exit;
		end;
		lastAction := disableAction;
		while lastAction.next <> nil do begin
			lastAction := lastAction.next;
		end;
		lastAction.next := TEnableDisable.Create (C, val, valMax);
		lastAction.next.DisablingState := DisablingStateInit;
	end;

	procedure TComponentChange.ChangeDisablingState (C: TComponent; state: boolean);
	var
		lastAction: TEnableDisable;
	begin
		lastAction := disableAction;
		while lastAction <> nil do begin
				if lastAction.ControlDisabled = C then begin
					lastAction.DisablingState := state;
					exit;
				end;
				lastAction := lastAction.next;
		end;
	end;

	procedure TComponentChange.ValidateAndReadValue (myName: string; aCol, aRow: Integer;
		const OldValue: string; var NewValue: string);
	begin
		if Component.name = myName then
		begin
			self.myValidateAndGetValue (aCol, aRow, OldValue, NewValue);
		end else if next <> nil then
		begin
			next.ValidateAndReadValue (myName, aCol, aRow, OldValue, NewValue);
		end else
			ShowMessage('Not found component: ' + myName);
		myCheckChanged;
	end;

	procedure TComponentChange.myValidateAndGetValue (aCol, aRow: Integer; const OldValue: string; var NewValue: string);
	begin
	end;

    procedure TComponentChange.mySelectedValue (used: boolean);
	begin
	end;

	procedure TComponentChange.SelectedValue (myName: string; used: boolean);
	begin
		if Component.name = myName then
		begin
				self.mySelectedValue (used);
				myCheckChanged;
		end else if next <> nil then
		begin
			next.SelectedValue (myName, used);
		end else begin
			ShowMessage('Not found component: ' + myName);
		end;
	end;

    procedure TComponentChange.myEnableDisable;
    begin
    end;

    procedure TComponentChange.myUncheck (state: boolean);
    begin
    end;

	procedure TComponentChange.ShowValue;
	begin
		mySetValue;
		if (next <> nil) then
			next.ShowValue;
		myCheckChanged;
		showChange;
	end;

	procedure TComponentChange.ActOnChange (state: boolean);
	begin
		SetOnChange(state);
		if (next <> nil) then next.ActOnChange(state);
	end;

	procedure TComponentChange.UpdateOtherOnChange (C: TComponentChange);
	begin
		setLength (componentsToUpdate, length(componentsToUpdate) + 1);
		componentsToUpdate [length(componentsToUpdate) - 1] := C;
	end;

    procedure TComponentChange.UpdateValue (p: GenericName);
	begin
	end;

    procedure TComponentChange.mySetOnChange (e: TNotifyEvent);
	begin
	end;

	procedure TComponentChange.myGetValue;
	var
		ind: longint;
	begin
		if ( length(componentsToUpdate) > 0 ) then
			for ind := 0 to (length(componentsToUpdate)-1) do
				componentsToUpdate [ind].UpdateValue (myVal);
	end;
	
	procedure TComponentChange.ReadValue (myName: string);
	begin
		if Component.name = myName then begin
			myGetValue();
			gConfigValuesEdited := True;
			myCheckChanged();
		end else if next <> nil then
			next.ReadValue (myName)
		else
			showMessage('Component not found: ' + myName);
	end;

	constructor TComponentChangeNotifyEvent.Create (C: TComponent; p: GenericName; e: TNotifyEvent);
	begin
		inherited Create(C, p);
		mySetOnChange(e);
	end;

	procedure TComponentChangeNotifyEvent.mySetOnChange (e: TNotifyEvent);
	begin
		onChangeHandler := e;
	end;


	procedure TComponentChange_StablePop.ActivateDisabling (C: TComponent;
				val: longint = kNotUsed; valMax: longint = kNotUsed;
				DisablingStateInit: boolean = false);
	var
		lastAction: TEnableDisable;
	begin
		if disableAction = nil then begin
			disableAction := TEnableDisable_StablePop.Create (C, val, valMax);
			disableAction.DisablingState := DisablingStateInit;
			exit;
		end;
		lastAction := disableAction;
		while lastAction.next <> nil do begin
			lastAction := lastAction.next;
		end;
		lastAction.next := TEnableDisable_StablePop.Create (C, val, valMax);
		lastAction.next.DisablingState := DisablingStateInit;
	end;


	procedure TCheckBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TCheckBox(Component).OnChange := onChangeHandler
		else
			TCheckBox(Component).OnChange := nil;
	end;

	procedure TCheckBoxChange.myEnableDisable;
	var
		lastAction: TEnableDisable;
	begin
		lastAction := disableAction;
		while lastAction <> nil do begin
			lastAction.setEnabledState (BooleanName (myVal).value);
			lastAction := lastAction.next;
		end;
	end;

	procedure TCheckBoxChange.myUncheck (state: boolean);
	var
		lastUncheck: TUnCheckIfFalse;
	begin
		if uncheckList = nil then exit;
		lastUncheck := uncheckList;
		while lastUncheck <> nil do begin
			lastUncheck.setChecked (state);
			lastUncheck := lastUncheck.next;
		end;
	end;

	procedure TCheckBoxChange.mySetValue;
	begin
		TCheckBox(Component).Checked := BooleanName(myVal).value;
		myEnableDisable;
		myUncheck (TCheckBox(Component).Checked);
	end;

	procedure TCheckBoxChange.myGetValue;
	begin
		BooleanName(myVal).value := TCheckBox(Component).Checked;
		myEnableDisable;
		myUncheck (TCheckBox(Component).Checked);
	end;

	procedure TCheckBoxChange.myCheckChanged;
	begin
		myVal.changed := (BooleanName(myVal).value <> BooleanName(myVal).default);
	end;

	procedure TCheckBoxChange.showChange;
	begin
		if myVal.changed then
			Component.Font.Color := clGreen
		else
			Component.Font.Color := clDefault;
	end;

	procedure TToggleBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TToggleBox(Component).OnChange := onChangeHandler
		else
			TToggleBox(Component).OnChange := nil;
	end;

	procedure TToggleBoxChange.mySetValue;
	begin
		TToggleBox(Component).Checked := BooleanName(myVal).value;
	end;

	procedure TToggleBoxChange.myGetValue;
	begin
		BooleanName(myVal).value := TToggleBox(Component).Checked;
	end;

	procedure TToggleBoxChange.myCheckChanged;
	begin
		myVal.changed := (BooleanName(myVal).value <> BooleanName(myVal).default);
	end;

	procedure TToggleBoxChange.showChange;
	begin
	end;

	procedure TMemoChange.SetOnChange (state: boolean);
	begin
		if state then
			TMemo(Component).OnChange := onChangeHandler
		else
			TMemo(Component).OnChange := nil;
	end;

	procedure TMemoChange.mySetValue;
	begin
		TMemo(Component).Text := StringName(myVal).value;
	end;

	procedure TMemoChange.myGetValue;
	begin
		StringName(myVal).value := TMemo(Component).Text;
	end;

	procedure TMemoChange.myCheckChanged;
	begin
		myVal.changed := (StringName(myVal).value <> StringName(myVal).default);
	end;

	procedure TMemoChange.showChange;
	begin
	end;

	procedure TEduComboBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TComboBox(Component).OnChange := onChangeHandler
		else
			TComboBox(Component).OnChange := nil;
	end;

	procedure TEduComboBoxChange.mySetValue;
	var
		myCombo: TComboBox;
	begin
		myCombo:= TComboBox(Component);
		myCombo.Items.Clear;
		myCombo.Items.Add('None');
		myCombo.Items.Add('Stochastic');
		myCombo.Items.Add('Individual');
		myCombo.Items.Add('Intrafamily');
		myCombo.ItemIndex := ord(eduStatusName(myVal).value);
	end;

	procedure TEduComboBoxChange.myGetValue;
	begin
		case TComboBox(Component).ItemIndex of	//what entry (which item) has currently been chosen
			0: eduStatusName(myVal).value := eduNone;
			1: eduStatusName(myVal).value := eduStochastic;
			2: eduStatusName(myVal).value := eduCohort;
			3: eduStatusName(myVal).value := eduIntraFamily;
		end;
	end;

	procedure TEduComboBoxChange.myCheckChanged;
	begin
		myVal.changed := (LongintName(myVal).value <> LongintName(myVal).default);
	end;

	procedure TEduComboBoxChange.showChange;
	begin
	end;

	procedure TKinFmtComboBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TComboBox(Component).OnChange := onChangeHandler
		else
			TComboBox(Component).OnChange := nil;
	end;

	procedure TKinFmtComboBoxChange.selectFields(itemSelected: longint);
	begin
		//OutputForm.OutputFileFields_.Enabled := not (itemSelected = 1); // DemoCare does not want those...
		//OutputForm.KinList_.Enabled := not (itemSelected = 1);
		//OutputForm.AllKinBtn.Enabled := not (itemSelected = 1);
		OutputForm.NON_BIO_KIN.Enabled := not (itemSelected = 1);
		OutputForm.INHERITANCE.Enabled := not (itemSelected = 1);
		OutputForm.PARTNER_FIRST_HEIR.Enabled := not (itemSelected = 1);
		OutputForm.PARTNER_FULL_HEIR.Enabled := not (itemSelected = 1);
		OutputForm.PARTNER_DECEDENT.Enabled := not (itemSelected = 1);
		OutputForm.ALL_EGO_PARTNERS_GENEALOGY.Enabled := not (itemSelected = 1);
	end;

	procedure TKinFmtComboBoxChange.mySetValue;
	var
		myCombo: TComboBox;
	begin
		myCombo:= TComboBox(Component);
		myCombo.Items.Clear;
		myCombo.Items.Add('Ego genealogy'); // 0
		myCombo.Items.Add('DemoCare'); // 1
		myCombo.Items.Add('GEDCOM'); // 2
		myCombo.ItemIndex := ord(KinFileFmtName(myVal).value);
		selectFields (myCombo.ItemIndex);
	end;

	procedure TKinFmtComboBoxChange.myGetValue;
	var
		myCombo: TComboBox;
	begin
		myCombo:= TComboBox(Component);
		case myCombo.ItemIndex of	//what entry (which item) has currently been chosen
			0: KinFileFmtName(myVal).value := out_EgoGenealogy;
			1: KinFileFmtName(myVal).value := out_DemoCare;
			2: KinFileFmtName(myVal).value := out_GEDCOM;
		end;
		selectFields (myCombo.ItemIndex);
	end;

	procedure TKinFmtComboBoxChange.myCheckChanged;
	begin
		myVal.changed := (LongintName(myVal).value <> LongintName(myVal).default);
	end;

	procedure TKinFmtComboBoxChange.showChange;
	begin
	end;

	procedure TCountryInheritanceComboBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TComboBox(Component).OnChange := onChangeHandler
		else
			TComboBox(Component).OnChange := nil;
	end;

	procedure TCountryInheritanceComboBoxChange.mySetValue;
	var
		myCombo: TComboBox;
	begin
		myCombo:= TComboBox(Component);
		myCombo.Items.Clear;
		myCombo.Items.Add('Spain'); // 0
		myCombo.Items.Add('Other'); // 1
		myCombo.ItemIndex := ord(CountryInheritanceName(myVal).value);
	end;

	procedure TCountryInheritanceComboBoxChange.myGetValue;
	var
		myCombo: TComboBox;
	begin
		myCombo:= TComboBox(Component);
		case myCombo.ItemIndex of	//what entry (which item) has currently been chosen
			0: CountryInheritanceName(myVal).value := inher_Spain;
			1: CountryInheritanceName(myVal).value := inher_Other;
		end;
	end;

	procedure TCountryInheritanceComboBoxChange.myCheckChanged;
	begin
		myVal.changed := (LongintName(myVal).value <> LongintName(myVal).default);
	end;

	procedure TCountryInheritanceComboBoxChange.showChange;
	begin
	end;

	destructor TCohortComboBoxChange.Destroy;
	begin
		setLength (myCohorts, 0);
		inherited;
	end;

	procedure TCohortComboBoxChange.getCohorts;
	begin
		DemRegimeCollection_yearsReadInConfig (myCohorts);
	end;

	procedure TCohortComboBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TComboBox(Component).OnChange := onChangeHandler
		else
			TComboBox(Component).OnChange := nil;
	end;

	procedure TCohortComboBoxChange.mySetValue;
	var
		myCombo: TComboBox;
		ind, selItem: longint;
	begin
		self.getCohorts;
		myCombo:= TComboBox(Component);
		myCombo.Items.Clear;
		selItem := 0;
		for ind := 0 to high(myCohorts) do begin
				myCombo.Items.Add(intToStr(myCohorts[ind]));
				if myCohorts[ind] = LongintName(myVal).value then
					selItem := ind;
		end;
		myCombo.ItemIndex := selItem;
		if (LongintName(myVal).value <> g_pDEM_REG^.yearOfBirth.value) and (length (myCohorts) > 1) then begin
			ConfigForm.currCohort := LongintName(myVal).value;
			ConfigForm.needToUpdate := true;
		end;
	end;

	procedure TCohortComboBoxChange.myGetValue;
	var
		selCohort: longint;
	begin
		selCohort := myCohorts[TComboBox(Component).ItemIndex];
		g_pDEM_REG := getCohort_p (selCohort);
		LongintName(myVal).value := selCohort;
		ConfigForm.updateValues;
	end;

	procedure TCohortComboBoxChange.myCheckChanged;
	begin
		// This is not a parameter for the demographic regime
		myVal.changed := FALSE;
	end;

	procedure TCohortComboBoxChange.showChange;
	begin
	end;

	procedure TCohortComboBoxChange.UpdateValue (p: GenericName);
	var
		pDemReg: pStructDemographicRegimeSettings;
	begin
		if length(myCohorts) = 1 then begin
			pDemReg := getCohort_p (myCohorts [0]);
			pDemReg^.yearOfBirth.value := LongintName(p).value;
			self.mySetValue;
		end;
	end;

	destructor TFixedFertComboBoxChange.Destroy;
	begin
		setLength (myTFRs, 0);
		inherited;
	end;

	procedure TFixedFertComboBoxChange.getTFRs;
	begin
		if length(myTFRs) = 0 then begin
			myTFRs := [1, 2, 3, 4];
		end;
	end;

	procedure TFixedFertComboBoxChange.SetOnChange (state: boolean);
	begin
		if state then
			TComboBox(Component).OnChange := onChangeHandler
		else
			TComboBox(Component).OnChange := nil;
	end;

	procedure TFixedFertComboBoxChange.mySetValue;
	var
		myCombo: TComboBox;
		ind, selItem: longint;
	begin
		self.getTFRs;
		myCombo:= TComboBox(Component);
		myCombo.Items.Clear;
		selItem := 0;
		for ind := 0 to high(myTFRs) do begin
			myCombo.Items.Add(intToStr(myTFRs[ind]));
			if myTFRs[ind] = LongintName(myVal).value then
				selItem := ind;
		end;
		myCombo.ItemIndex := selItem;
	end;

	procedure TFixedFertComboBoxChange.myGetValue;
	var
		selTFR: longint;
	begin
		selTFR := myTFRs[TComboBox(Component).ItemIndex];
		LongintName(myVal).value := selTFR;
		g_GENPARAM.FIXED_FERTILITY_VALUE.value := selTFR;
		ConfigForm.updateValues;
	end;

	procedure TFixedFertComboBoxChange.myCheckChanged;
	begin
		// This is not a parameter for the demographic regime
		myVal.changed := FALSE;
	end;

	procedure TFixedFertComboBoxChange.showChange;
	begin
	end;

	procedure TFixedFertComboBoxChange.UpdateValue (p: GenericName);
	begin
	end;

	constructor TEditChange.Create (C: TComponent; p: GenericName; e: TNotifyEvent; minV: longint = 0; maxV: longint = 0);
	begin
		inherited Create(C, p, e);

		TEdit(Component).OnEditingDone := onChangeHandler;
		TEdit(Component).OnMouseLeave := onChangeHandler;
		minValue := minV;
		maxValue := maxV;
		checkValue := not ( (minValue = 0) and (maxValue = 0) );
		if checkValue then Component.Hint := Component.Hint + LineEnding + '(Value between ' + IntToStr(minValue) + ' and ' + IntToStr(maxValue) + ' both included)';
	end;

	procedure TEditChange.SetOnChange (state: boolean);
	begin
		if state then begin
			TEdit(Component).OnEditingDone := onChangeHandler;
			TEdit(Component).OnMouseLeave := onChangeHandler;
		end else begin
			TEdit(Component).OnEditingDone := nil;
			TEdit(Component).OnMouseLeave := nil;
		end;
	end;

	procedure TEditChange.myEnableDisable;
	var
		lastAction: TEnableDisable;
	begin
		lastAction := disableAction;
		while lastAction <> nil do begin
			case editType of
				kIsInteger: lastAction.update (LongintName (myVal).value);
				kIsDouble: lastAction.updateFloat (DoubleName (myVal).value);
			end;
			lastAction := lastAction.next;
		end;
	end;

	procedure TEditChange.mySetValue;
	begin
		case editType of
			kIsInteger: begin
				TEdit (Component).text := IntToStr (LongintName (myVal).value);
				if disableAction <> nil then
					disableAction.update (LongintName (myVal).value);
			end;
			kIsDouble: begin
				TEdit (Component).text := FloatToStr (DoubleName (myVal).value);
				if disableAction <> nil then
					disableAction.updateFloat (DoubleName (myVal).value);
			end;
			kIsString:
				begin
					TEdit (Component).text := StringName (myVal).value;
				end;
		end;
		TEdit(Component).Alignment:= taRightJustify;
	end;

	procedure TEditChange.myGetValue;
	var
		intValue: longint;
		doubleValue: double;
		errorValue: boolean = false;
	begin
		case editType of
			kIsInteger: begin
				try
					intValue := strToInt (TEdit(Component).text);
				except
					On E : EConvertError do begin
						intValue := LongintName(myVal).default;
						TEdit(Component).text := intToStr(intValue);
					end;
				end;
				if not checkValue or ( (intValue >= minValue) and (intValue <= maxValue) ) or (intValue = LongintName(myVal).default) then begin
						LongintName(myVal).value := intValue;
				end else
						errorValue := true;
				if disableAction <> nil then
					disableAction.update (intValue);
			end;
			kIsDouble: begin
				try
					doubleValue := strToDouble (TEdit(Component).text);
				except
					On E : EConvertError do begin
						doubleValue := DoubleName(myVal).default;
						TEdit(Component).text := FloatToStr(doubleValue);
					end;
				end;
				if not checkValue or ( (doubleValue >= minValue) and (doubleValue <= maxValue) ) or (doubleValue = DoubleName(myVal).default) then begin
					DoubleName(myVal).value := doubleValue;
				end else
					errorValue := true;
				if disableAction <> nil then
					disableAction.updateFloat (doubleValue);
			end;
			kIsString:
				begin
					StringName(myVal).value := TEdit(Component).text;
				end;
		end;
		if errorValue then begin
			ShowMessage('Only values between ' + IntToStr(minValue) + ' and ' + IntToStr(maxValue) + ' (both included) allowed');
			mySetValue;
		end;
		
		inherited;
	end;

	procedure TEditChange.myCheckChanged;
	begin
		case editType of
			kIsInteger:
				myVal.changed := (LongintName(myVal).value <> LongintName(myVal).default);
			kIsDouble:
				myVal.changed := (DoubleName(myVal).value <> DoubleName(myVal).default);
			kIsString:
				myVal.changed := (StringName(myVal).value <> StringName(myVal).default);
		end;
	end;

	procedure TEditChange.showChange;
	begin
	end;

	procedure TEditChange_CTFR.UpdateValue(p: GenericName);
	begin
		DoubleName (myVal).value := computeTFRfromPPRs(ArrayOfDoubleName (p));
		TEdit (Component).text := FloatToStr (DoubleName (myVal).value);
	end;

	procedure TEditChange_lastCohort.UpdateValue(p: GenericName);
	var
		val: longint;
	begin
		val := StrToInt (TEdit (Component).text);
		if LongintName (p).value > val then begin
			LongintName (myVal).value := LongintName (p).value;
			TEdit (Component).text := IntToStr (LongintName (myVal).value);
		end;
	end;

	constructor TComponentChangeValidateEntryEvent.Create (C: TComponent; p: GenericName; e: TValidateEntryEvent; mvs, mvd: longint; minV: longint = 0; maxV: longint = 1);
	begin
		inherited Create(C, p);
		mySetOnChange(e);
		maxValueShown := mvs;
		maxValueDataset := mvd;
		minValue := minV;
		maxValue := maxV;
	end;

	destructor TComponentChangeValidateEntryEvent.Destroy;
	begin
		TValueListEditor(Component).Clear;
		inherited;
	end;

	procedure TComponentChangeValidateEntryEvent.mySetOnChange (e: TValidateEntryEvent);
	begin
		onValidateHandler := e;
	end;

	procedure TComponentChangeValidateEntryEvent.SetOnChange (state: boolean);
	begin
		if state then
			TValueListEditor(Component).OnValidateEntry := onValidateHandler
		else
			TValueListEditor(Component).OnValidateEntry := nil;
	end;

	procedure TComponentChangeValidateEntryEvent.myGetValue;
	begin
		inherited;
	end;
	
	procedure TComponentChangeValidateEntryEvent.mySetValue;
	var
		parity, row: longint;
		MyEditor: TValueListEditor;
		debugString: string;
	begin
		MyEditor := TValueListEditor(Component);
		MyEditor.Clear;
		for parity := 0 to maxValueShown do begin
				debugString := FloatToStr (ArrayOfDoubleName(myVal).value[parity]);
				row := MyEditor.InsertRow(IntToStr(parity), FloatToStr (ArrayOfDoubleName(myVal).value[parity]), true);
		end;
{		if (Component.name = 'APRIORI_PPR') then begin
			if (componentToUpdate <> nil) then
				TEditChange_CTFR (componentToUpdate).mySetValue(myVal);
		end;
}
		MyEditor.Row := 0;
		MyEditor.Col := 1;
		setMyHint;
		Component.Hint := Component.Hint + LineEnding + '(For convenience, the last value entered is repeated onwards)';
		myGetValue;
	end;

	procedure TComponentChangeValidateEntryEvent.myValidateAndGetValue (aCol, aRow: Integer; const OldValue: string; var NewValue: string);
	var
		OldValue_double, NewValue_double: double;
		par: longint;
	begin
		OldValue_double := strToDouble (OldValue);
		try
			NewValue_double := strToDouble (NewValue);
		except
			On E : EConvertError do begin
				NewValue_double := OldValue_double;
				NewValue := OldValue;
			end;
		end;
		if (NewValue_double < minValue) or (NewValue_double > maxValue) then begin
			NewValue := OldValue;
			ShowMessage('Only values between ' + IntToStr(minValue) + ' and ' + IntToStr(maxValue) + ' (both included) allowed');
		end else if (OldValue <> NewValue) then begin
			gConfigValuesEdited := True;
			(ArrayOfDoubleName(myVal).value[aRow-1]) := NewValue_double;
			for par := aRow to maxValueDataset do begin
				(ArrayOfDoubleName(myVal).value[par]) := (ArrayOfDoubleName(myVal).value[par-1]);
			end;
			for par := 0 to maxValueShown do
				TValueListEditor(Component).Cells[1, par+1] := FloatToStr((ArrayOfDoubleName(myVal).value[par]));
			NewValue := FloatToStr((ArrayOfDoubleName(myVal).value[aRow-1]));
{			if (Component.name = 'APRIORI_PPR') then begin
				if (componentToUpdate <> nil) then
					TEditChange_CTFR (componentToUpdate).mySetValue(myVal);
			end;
}
			myGetValue;
		end;
	end;

	procedure TComponentChangeValidateEntryEvent.myCheckChanged;
	var
		par: longint;
	begin
		myVal.Changed := false;
		for par := 0 to maxValueDataset do begin
			myVal.changed := myVal.changed or
					((ArrayOfDoubleName(myVal).value[par]) <> (ArrayOfDoubleName(myVal).default[par]));
		end;
	end;

	procedure TComponentChangeValidateEntryEvent.showChange;
	begin
	end;

	constructor TComponentChangeSelectionChangeEvent.Create (C: TComponent; p: GenericName; e: TSelectionChangeEvent);
	begin
		inherited Create(C, p);
		mySetOnChange(e);
	end;

	procedure TComponentChangeSelectionChangeEvent.mySetOnChange (e: TSelectionChangeEvent);
	begin
		onSelectionChangeHandler := e;
	end;

	procedure TComponentChangeSelectionChangeEvent.SetOnChange (state: boolean);
	begin
		if state then
			TListBox(Component).OnSelectionChange := onSelectionChangeHandler
		else
			TListBox(Component).OnSelectionChange := nil;
	end;

	procedure TKinListBoxChange.mySetValue;
	var
		lb: TListBox;
		rel: KinTypes;
		ind: longint;
	begin
		lb := TListBox (Component);
		lb.multiselect := true;
		ind := -1;
		for rel := kFirstKinInEnumOutput to kLastKinInEnumOutput do begin
				lb.items.add (str_kinship[rel]);
				Inc ( ind );
				if rel in KinListName(myVal).value then begin
					lb.selected[ind] := true;
				end else begin
					lb.selected[ind] := false;
				end;
		end;
	end;

	procedure TKinListBoxChange.mySelectedValue (used: boolean);
	var
		lb: TListBox;
		rel: KinTypes;
		ind: longint;
	begin
		if not gCheckSelected or (g_GENPARAM.KINSHIP.value = false) then
		begin
			exit;
		end;
		lb := TListBox (Component);
		ind := -1;
			for rel := kFirstKinInEnumOutput to kLastKinInEnumOutput do begin
				Inc ( ind );
				if rel in KinListName(myVal).value then begin
					lb.selected[ind] := true;
				end else begin
					lb.selected[ind] := false;
				end;
			end;
		ind := -1;
		KinListName(myVal).value := [];
		for rel := kFirstKinInEnumOutput to kLastKinInEnumOutput do begin
				Inc ( ind );
				if lb.selected[ind] then
					Include(KinListName(myVal).value, rel);
		end;
	end;

	procedure TKinListBoxChange.myCheckChanged;
	var
		rel: KinTypes;
	begin
		myVal.Changed := false;
		for rel := low(KinTypes) to high(KinTypes) do begin
			myVal.Changed := myVal.Changed or ( (rel in KinListName(myVal).value) xor (rel in KinListName(myVal).default) );
		end;
	end;

	procedure TKinListBoxChange.showChange;
	begin
	end;

	procedure TFieldListBoxChange.mySetValue;
	var
		lb: TListBox;
		fn: FieldNamesTypes;
		ind: longint;
	begin
		lb := TListBox (Component);
		lb.Clear;
		lb.multiselect := true;
		ind := -1;
		for fn := low(FieldNamesTypes) to high(FieldNamesTypes) do begin
				lb.items.add (str_FieldNames[fn]);
				Inc ( ind );
				lb.selected[ind] := (fn in FieldListName(myVal).value);
		end;
		//filled_not_clicked := true;
	end;

	procedure TFieldListBoxChange.mySelectedValue (used: boolean);
	var
		lb: TListBox;
		fn: FieldNamesTypes;
		ind: longint;
	begin
		if not gCheckSelected or (g_GENPARAM.KINSHIP.value = false) then
		begin
			exit;
		end;
		lb := TListBox (Component);
		ind := -1;
		//if filled_not_clicked then begin
			//just_filled := true;
			for fn := low(FieldNamesTypes) to high(FieldNamesTypes) do begin
				Inc ( ind );
				lb.selected[ind] := (fn in FieldListName(myVal).value);
			end;
			//just_filled := false;
			//filled_not_clicked := false;
		//end;
		ind := -1;
		FieldListName(myVal).value := [];
		for fn := low(FieldNamesTypes) to high(FieldNamesTypes) do begin
				Inc ( ind );
				if lb.selected[ind] then
					Include(FieldListName(myVal).value, fn);
		end;
	end;

	procedure TFieldListBoxChange.myCheckChanged;
	var
		fn: FieldNamesTypes;
	begin
		myVal.Changed := false;
		for fn := low(FieldNamesTypes) to high(FieldNamesTypes) do begin
			myVal.Changed := myVal.Changed or ( (fn in FieldListName(myVal).value) xor (fn in FieldListName(myVal).default) );
		end;
	end;

	procedure TFieldListBoxChange.showChange;
	begin
	end;
end.

