unit LazConfig;

{$mode objFPC}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
	Grids, ValEdit, LResources, Menus, Buttons,
	ComponentHelper, LazOutput,
	Declarations;

type

	{ TConfigForm }

	TConfigForm = class(TForm)
		AgeFirstUnionMenLabel: TLabel;
		FIXED_FERTILITY_VALUE: TComboBox;
		FIXED_FERTILITY: TCheckBox;
		DETAILED_COHORT_DATA: TCheckBox;
		DUMPALLCOHORTS: TCheckBox;
		DUMPALL: TCheckBox;
		CreateCohortFile: TButton;
		ReparWidowGroup: TGroupBox;
		ReparSeparGroup: TGroupBox;
		REPARTNERING_WID_MEN: TEdit;
		REPARTNERING_WID_WOMEN: TEdit;
		STEP_COHORT: TEdit;
		LabStep: TLabel;
		SEP_TARGET: TCheckBox;
		CommentBtn: TButton;
		CTFR: TEdit;
		CTFRLab: TLabel;
		LowLevelOptions: TButton;
		ZERO_FIXED_AMENORRHEA_: TEdit;
		NSTEP_CONTRACEPTION: TEdit;
		FIXED_AMENORRHEA: TCheckBox;
		FIXED_AGE_UNION: TCheckBox;
		ConfigFileOptions: TGroupBox;
		durAmenoLab: TLabel;
		contrStepsLab: TLabel;
		readConfigFile: TButton;
		CohortsFilename: TLabel;
		PROP_WOMEN_AT_BIRTH: TEdit;
		PropWomenLab: TLabel;
		OtherParamBox: TGroupBox;
		OpenDialogCohortsFile: TOpenDialog;
		ReadCohortFile: TButton;
		SeparationIterationGroup: TGroupBox;
		SEPARATION_ADJUSTED: TEdit;
		PROP_USING_SPACING: TValueListEditor;
		EVER_INUNION_PROP_MEN: TEdit;
		PROP_CONTRACEP_AFTER_FIRST_UNION: TEdit;
		NO_CHANGES_SHAPE: TShape;
		WAITING_TIME_SPACING: TValueListEditor;
		WAITINGTIMEGroup: TGroupBox;
		INIT_RANDOM_NUMBERS: TCheckBox;
		PropEverMen: TLabel;
		ModelOptionsGroup: TGroupBox;
		OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES: TCheckBox;
		OutputOptions: TButton;
		COHORTS: TComboBox;
		ContraceptionUseGroup: TGroupBox;
		CONTRACEP_TIME_AFTER_FIRST_UNION: TEdit;
		AMENORRHEA_Group: TGroupBox;
		AMENO_ALPHA: TEdit;
		AMENO_BETA: TEdit;
		DemReg_group: TGroupBox;
		Cohort_label: TLabel;
		DEM_REG_FILENAME: TEdit;
		CohortFileName: TLabel;
		SeparationGroup: TGroupBox;
		SEPARATION: TEdit;
		SeparationSteps: TGroupBox;
		BOOTSTRAP_NRUNS: TEdit;
		Boostrapping: TLabel;
		COHORTS_SIM_Group: TGroupBox;
		LAST_COHORT: TEdit;
		FIRST_COHORT: TEdit;
		FirstCohort: TLabel;
		LastCohort: TLabel;
		nEgosLab: TLabel;
		SPACINGGroup: TGroupBox;
		REPARTNERING_MEN: TEdit;
		REPARTNERING_WOMEN: TEdit;
		FreqRepWomen: TLabel;
		FreqRepMen: TLabel;
		Repartnering: TGroupBox;
		StoppingGroup: TGroupBox;
		NSTEP_SEPARATION: TEdit;
		SECOND_SEPARATION_REL_RISK: TEdit;
		FreqSep: TLabel;
		SecondSeparationLabel: TLabel;
		NEGO: TEdit;
		NSTEP_AMENORRHEA: TEdit;
		NStepsAmenoGroup: TGroupBox;
		AmenoAlpha: TLabel;
		AmenoBeta: TLabel;
		Lestaeghe_pageGroup: TGroupBox;
		NSTEP_CONTRACEP_BEFORE_FIRST_CHILD: TEdit;
		FILENAME: TEdit;
		NStepsContrGroup: TGroupBox;
		RootFileName: TLabel;
		EFF_CONTRACEP_BEFORE_UNION: TEdit;
		EffContraceptionBeforeFirstUnion: TLabel;
		PropContrAfterFirstUnion: TLabel;
		TimeFirstUnionFirstBirth: TLabel;
		TimeAfterFirstUnionGroup: TGroupBox;
		MEAN_AGE_UNION_MEN: TEdit;
		MenGroup: TGroupBox;
		NSTEP_UNION_STDDEV: TEdit;
		STD_DEV_AGE_UNION: TEdit;
		EDUCATION: TComboBox;
		ConfigINFOGroup: TGroupBox;
		EducationGB: TGroupBox;
		NSTEP_UNION_PROP: TEdit;
		NSTEP_UNION_MEAN: TEdit;
		EVER_INUNION_PROP_HIGH: TEdit;
		UnionNstepsGroup: TGroupBox;
		MEAN_AGE_UNION_HIGH: TEdit;
		EVER_INUNION_PROP: TEdit;
		MarMaxValuesGroup: TGroupBox;
		MEAN_AGE_UNION: TEdit;
		UnionWomenGroup: TGroupBox;
		e0W: TLabel;
		e0M: TLabel;
		AgeWomen: TLabel;
		PropEverWomen: TLabel;
		StdDevUnionWomen: TLabel;
		PPR_TARGET: TCheckBox;
		GenFertilityGroup: TGroupBox;
		WRITE_ONLY_CHANGES: TCheckBox;
		DefaultValues: TButton;
		Cancel: TButton;
		LIFE_EXPECTANCY_AT_BIRTH_WOMEN: TEdit;
		LIFE_EXPECTANCY_AT_BIRTH_MEN: TEdit;
		Image1: TImage;
		NuptialityGroup: TGroupBox;
		MORTALITY_group: TGroupBox;
		APRIORI_PPR: TValueListEditor;
		EFF_STOPPING_CONTRACEP: TValueListEditor;
		writeConfigFile: TButton;
		FERTILITY: TCheckBox;
		KINSHIP: TCheckBox;
		ModelTypeGroup: TGroupBox;
		SaveConfigDialog: TSaveDialog;
		procedure CommentBtnClick(Sender: TObject);
		procedure CreateCohortFileClick(Sender: TObject);
		procedure DefaultValuesClick(Sender: TObject);
		procedure CancelClick(Sender: TObject);
		procedure LowLevelOptionsClick(Sender: TObject);
		procedure OutputOptionsClick(Sender: TObject);
		procedure ReadCohortFileClick(Sender: TObject);
		procedure readConfigFileClick(Sender: TObject);
		procedure writeConfigFileClick(Sender: TObject);

		procedure ToggleChanges(Sender : TObject);
		procedure myValidateHandler(Sender : TObject; aCol, aRow: Integer;
			const OldValue: string; var NewValue: string);

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
		procedure FormCreate(Sender: TObject);
		procedure FormDestroy(Sender: TObject);
		procedure FormActivate(Sender: TObject);
		procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
		procedure myFocusHandler(Sender : TObject);
		procedure myChangeHandler(Sender : TObject);
		procedure componentsInfoCreate;
		procedure componentsInfoDestroy;
		procedure showValues;
		procedure updateValues;
		procedure NoOnChange;
	public
		FirstTime: boolean;
		currCohort: longint;
		needToUpdate: boolean;
		ChangesMadeToDefaultValues: boolean;
		myComponentHelper: TComponentHelper;
		firstComponentChange: TComponentChange;
		onChangeHandler: TNotifyEvent;
//====== END COMMON PART =====//
		onValidateHandler: TValidateEntryEvent;
		destructor Destroy; override;
end;

var
	ConfigForm: TConfigForm;
	gLazDumpFileName: string;
	gConfigValuesEdited: boolean;
	//gConfigDemReg: pStructDemographicRegimeSettings;

implementation

{$R *.lfm}
uses
	LazMain, LazLowlevel, DocForm,
	ReadCmdFileUnit, DemographicRegime, FertilityRuntime, Utilities;

var
	gNullIntObj: longintName;
{ TConfigForm }

procedure TConfigForm.writeConfigFileClick(Sender: TObject);
begin
	SaveConfigDialog.Title := 'Write a KinFert config file';
	SaveConfigDialog.Filter := 'KinFert config file|*.txt';
	SaveConfigDialog.DefaultExt := 'txt';
	SaveConfigDialog.FileName := stringConcatenate_sep (g_FileName.value, 'CONFIG.TXT', '_');
	SaveConfigDialog.Options := SaveConfigDialog.Options + [ofOverwritePrompt];
	gLazDumpFileName := '';
	if ( not (gMainPathToResult = '') ) then begin
		g_GENPARAM.OUTPUT_DIRECTORY.value := gMainPathToResult;
	end;
	if SaveConfigDialog.Execute then
	begin
		gLazDumpFileName := SaveConfigDialog.Filename;
		gPathToConfig := ExtractFilePath(gLazDumpFileName);
		gLazDumpFileName := ExtractFileName(gLazDumpFileName);
		initCmd ();
		dumpConfigInfo (gPathToConfig, gLazDumpFileName, true);
	end;
	ToggleChanges(Sender);
	//ModalResult := mrClose;
end;

procedure TConfigForm.OutputOptionsClick(Sender: TObject);
begin
	NoOnChange;
	OutputForm.ShowModal;
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or OutputForm.ChangesMadeToDefaultValues;
	ToggleChanges(Sender);
end;

procedure TConfigForm.ReadCohortFileClick(Sender: TObject);
var
	s: ansistring;
	filenameWithPath: string;
	numSimul: longint = 0;
begin
	defaultConfigFile;
	defaultConfig ();
	s := 'KinFert cohorts file|*.txt';
	OpenDialogCohortsFile.Filter := s;
	OpenDialogCohortsFile.Options := OpenDialogCohortsFile.Options+[ofFileMustExist];
	if not OpenDialogCohortsFile.Execute then exit;
	try
		initCmd ();
		filenameWithPath := OpenDialogCohortsFile.filename;
		gPathToConfig := ExtractFilePath(filenameWithPath);
		g_FileName_DemographicRegime.value := ExtractFileName(filenameWithPath);
		if DemRegimeCollection_readData (g_FileName_DemographicRegime.value) then begin
			DemRegimeCollection_adjustData ();
			CohortsFileName.caption := g_FileName_DemographicRegime.value;
			CohortsFileName.left := 936;
			NoOnChange;
			FormActivate(Sender);
			g_GENPARAM.STABLE_POPULATION.value := FALSE;
		end else begin
			CohortsFileName.caption := 'Error..';
			CohortsFileName.left := 1016;
			KinFertForm.FlushString({%H-}PtrInt(nil));
			MessageDlg('Error reading cohort file...', 'Go back to main window for an explanation', mtError , [mbOk],0)
		end;
	except
		on E: Exception do begin
			MessageDlg('Error','Error: ' + E.Message, mtError, [mbOk],0);
		end;
	end

end;

procedure TConfigForm.readConfigFileClick(Sender: TObject);
begin
	KinFertForm.ChooseConfigButtonClick(Sender);
	NoOnChange;
	FormActivate(Sender);
end;

{procedure TConfigForm.SelectEditor(Sender: TObject; aCol,
	aRow: Integer; var Editor: TWinControl);
begin
	if aCol = 1 then
		Editor := APRIORI_PPR.EditorByStyle(cbsEllipsis);
end;}

procedure TConfigForm.CancelClick(Sender: TObject);
begin
	ModalResult := mrClose;
end;

procedure TConfigForm.LowLevelOptionsClick(Sender: TObject);
begin
	NoOnChange;
	LowLevelForm.ShowModal;
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or LowLevelForm.ChangesMadeToDefaultValues;
	ToggleChanges(Sender);
end;

procedure TConfigForm.DefaultValuesClick(Sender: TObject);
begin
	defaultConfigFile;
	defaultConfig ();
	NoOnChange;
	FormActivate(Sender);
	ChangesMadeToDefaultValues := false;
	ToggleChanges(Sender);
	CohortsFileName.caption := 'no cohorts file';
	CohortsFileName.left := 1016;
end;

procedure TConfigForm.CommentBtnClick(Sender: TObject);
begin
	NoOnChange;
	Documentation.ShowModal;
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or Documentation.ChangesMadeToDefaultValues;
	ToggleChanges(Sender);
end;

procedure TConfigForm.CreateCohortFileClick(Sender: TObject);
var
	cohortConfigFileName: string;
	mem: boolean;
begin
	SaveConfigDialog.Title := 'Write a cohort config file';
	SaveConfigDialog.Filter := 'KinFert config file|*.txt';
	SaveConfigDialog.DefaultExt := 'txt';
	SaveConfigDialog.FileName := g_FileName.value + '_DEM_REG_FILENAME.txt';
	SaveConfigDialog.Options := SaveConfigDialog.Options + [ofOverwritePrompt];
	if SaveConfigDialog.Execute then
	begin
		cohortConfigFileName := SaveConfigDialog.Filename;
		initCmd ();
		mem := g_GENPARAM.CREATE_COHORT_FILE.value;
		g_GENPARAM.CREATE_COHORT_FILE.value := true;
		dumpConfigInfo (ExtractFilePath(cohortConfigFileName), ExtractFileName(cohortConfigFileName), false, true, false);
		g_GENPARAM.CREATE_COHORT_FILE.value := mem;
	end;
end;

procedure TConfigForm.ToggleChanges(Sender: TObject);
begin
	if ChangesMadeToDefaultValues then begin
		NO_CHANGES_SHAPE.brush.color := clRed;
		NO_CHANGES_SHAPE.Hint := 'Changes made to default values';
	end else begin
		NO_CHANGES_SHAPE.brush.color := clBlue;
		NO_CHANGES_SHAPE.Hint := 'No changes made to default values';
	end;
	NO_CHANGES_SHAPE.ShowHint := true;
end;

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TConfigForm.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TConfigForm.FormCreate(Sender: TObject);
begin
	//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
	FirstTime := True;
	ChangesMadeToDefaultValues := False;
	gConfigValuesEdited := False;
	onChangeHandler := @myChangeHandler;
//====== END COMMON PART =====//
	onValidateHandler := @myValidateHandler;
	ToggleChanges(Sender);
	//Image1 := Timage.Create(self);
	Image1.Parent	:= self;
	//Image1.Picture.LoadFromLazarusResource('Under');
	Image1.Picture.LoadFromLazarusResource('CED');
	Image1.Stretch := true;
	Image1.Left := 848;
	Image1.Top := 15;
	//Image1.Width := trunc (1245 / 5);
	//Image1.Height := trunc (830 / 5);
	Image1.Width := trunc (485 / 1.5);
	Image1.Height := trunc (187 / 1.5);

	gNullIntObj := LongintName.Create(0, '', '');
	
end;

procedure TConfigForm.FormDestroy(Sender: TObject);
begin
	gNullIntObj.Destroy;
end;

procedure TConfigForm.FormActivate(Sender: TObject);
begin
	currCohort := g_pDEM_REG^.yearOfBirth.value;
	needToUpdate := false;
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	gLazDumpFileName := '';
	showValues;
	if needToUpdate then begin
		g_pDEM_REG := getCohort_p (currCohort);
		updateValues;
	end;
end;

procedure TConfigForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
	CanClose := true;
	NoOnChange;
end;

procedure TConfigForm.componentsInfoDestroy;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
end;

// ========= THE SAME PROCEDURE EXISTS, BUT WITH DIFFERENT CONTENT ============//
procedure TConfigForm.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
	lastComponentChange: TComponentChange = nil;

begin
	if g_pDEM_REG = nil then
		g_pDEM_REG := getCohort_p (DemRegimeCollection_firstCohort);

	if (DemRegimeCollection_nCohorts = 1) then begin
		if (g_GENPARAM.RUNTIME[cmd_firstCohort].value <> g_pDEM_REG^.yearOfBirth.value) then
			g_pDEM_REG^.yearOfBirth.value := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
		if (g_GENPARAM.RUNTIME[cmd_lastCohort].value < g_GENPARAM.RUNTIME[cmd_firstCohort].value) then
			g_GENPARAM.RUNTIME[cmd_lastCohort].value := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
	end;
	
	//gFocusHandler := @myFocusHandler;
	checkStepsAndStablePopulation;
	myComponentHelper := TComponentHelper.Create;
	// COHORTS should be the first component in the list, as it has the 'power' to kill everything when selecting another cohort
	myComponentHelper.CreateComponentChange(FindComponent ('COHORTS'), gNullIntObj, firstComponentChange, onChangeHandler);
	currentComponentChange := firstComponentChange;
	lastComponentChange := currentComponentChange;
	myComponentHelper.CreateComponentChange(FindComponent ('FIRST_COHORT'), g_GENPARAM.RUNTIME[cmd_firstCohort], currentComponentChange, onChangeHandler, kIsInteger);
	currentComponentChange.UpdateOtherOnChange(lastComponentChange);
	lastComponentChange := currentComponentChange;
	myComponentHelper.CreateComponentChange(FindComponent ('LAST_COHORT'), g_GENPARAM.RUNTIME[cmd_lastCohort], currentComponentChange, onChangeHandler, kIsInteger);
	lastComponentChange.UpdateOtherOnChange(currentComponentChange);
	myComponentHelper.CreateComponentChange(FindComponent ('STEP_COHORT'), g_GENPARAM.RUNTIME[cmd_stepCohort], currentComponentChange, onChangeHandler, kIsInteger);

	myComponentHelper.CreateComponentChange(FindComponent ('FERTILITY'), g_GENPARAM.FERTILITY, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('CTFR'), g_pDEM_REG^.CTFR, currentComponentChange, onChangeHandler, kIsDouble, 0, 100);
	lastComponentChange := currentComponentChange;
	TEdit (FindComponent ('CTFR') ).ReadOnly := true;
	myComponentHelper.CreateComponentChange(FindComponent ('APRIORI_PPR'), g_pDEM_REG^.aPrioriPPR, currentComponentChange, TNotifyEvent(onValidateHandler), kIsInteger, 0, 1, kMaxParityInput, kMaxNbChildren);
	currentComponentChange.UpdateOtherOnChange(lastComponentChange);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_CONTRACEPTION'), g_GENPARAM.RUNTIME[nStepsContrFert], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('NWOMEN'), g_pDEM_REG^.lp[nWomenPar], currentComponentChange, onChangeHandler, kIsInteger, 100, 1000000);
	myComponentHelper.CreateComponentChange(FindComponent ('KINSHIP'), g_GENPARAM.KINSHIP, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('NEGO'), g_pDEM_REG^.lp[nEgoPar], currentComponentChange, onChangeHandler, kIsInteger, 100, 1000000);
	myComponentHelper.CreateComponentChange(FindComponent ('LIFE_EXPECTANCY_AT_BIRTH_WOMEN'), g_pDEM_REG^.dp[e0_women], currentComponentChange, onChangeHandler, kIsDouble, 20, 112);
	myComponentHelper.CreateComponentChange(FindComponent ('LIFE_EXPECTANCY_AT_BIRTH_MEN'), g_pDEM_REG^.dp[e0_men], currentComponentChange, onChangeHandler, kIsDouble, 20, 112);
	myComponentHelper.CreateComponentChange(FindComponent ('PPR_TARGET'), g_GENPARAM.PPR_TARGET, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('SEP_TARGET'), g_GENPARAM.SEP_TARGET, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('INIT_RANDOM_NUMBERS'), g_GENPARAM.INIT_RANDOM_NUMBERS, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('MEAN_AGE_UNION'), g_pDEM_REG^.dp[meanAgeUnionWomenLow], currentComponentChange, onChangeHandler, kIsDouble, 10, 59);
	myComponentHelper.CreateComponentChange(FindComponent ('MEAN_AGE_UNION_HIGH'), g_pDEM_REG^.dp[meanAgeUnionWomenHigh], currentComponentChange, onChangeHandler, kIsDouble, 10, 59);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_UNION_MEAN'), g_GENPARAM.RUNTIME[nStepsUnion_mean], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
// BEWARE: ActivateDisabling is associated to the component which is in charge of enabling/disabling the other one
// So we should put it just AFTER the line in which the first one is created
// In this case, if NSTEP_UNION_MEAN is changed to a value higher than 1, then MEAN_AGE_UNION_HIGH will be enabled
// NSTEP_UNION_MEAN controls the activation of MEAN_AGE_UNION_HIGH
	if StablePopulation() then currentComponentChange.ActivateDisabling (FindComponent ('MEAN_AGE_UNION_HIGH'), 1);
	myComponentHelper.CreateComponentChange(FindComponent ('EVER_INUNION_PROP'), g_pDEM_REG^.dp[propFinalCelibacyLow], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('EVER_INUNION_PROP_HIGH'), g_pDEM_REG^.dp[propFinalCelibacyHigh], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_UNION_PROP'), g_GENPARAM.RUNTIME[nStepsUnion_prop], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	if StablePopulation() then currentComponentChange.ActivateDisabling (FindComponent ('EVER_INUNION_PROP_HIGH'), 1);
	myComponentHelper.CreateComponentChange(FindComponent ('STD_DEV_AGE_UNION'), g_pDEM_REG^.dp[stdnupt], currentComponentChange, onChangeHandler, kIsDouble, 1, 100);
// Here if STD_DEV_AGE_UNION value is superior to 0, then this will enable NSTEP_UNION_STDDEV
	if StablePopulation() then currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_UNION_STDDEV'), 0, 1000000000);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_UNION_STDDEV'), g_GENPARAM.RUNTIME[nStepsUnion_Dev], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('FIXED_AGE_UNION'), g_GENPARAM.fixedParameters [fixedUnionAge].state, currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('MEAN_AGE_UNION_MEN'), g_pDEM_REG^.dp[meanAgeUnionMen], currentComponentChange, onChangeHandler, kIsDouble, 10, 69);
	myComponentHelper.CreateComponentChange(FindComponent ('EVER_INUNION_PROP_MEN'), g_pDEM_REG^.dp[propFinalCelibacyMen], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('SEPARATION'), g_pDEM_REG^.dp[freqSeparation], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	if StablePopulation() then currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_SEPARATION'), 0, 1000000000);
	myComponentHelper.CreateComponentChange(FindComponent ('SEPARATION_ADJUSTED'), g_pDEM_REG^.dp[freqSeparationFirstIteration], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_SEPARATION'), g_GENPARAM.RUNTIME[nStepsSeparation], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('SECOND_SEPARATION_REL_RISK'), g_pDEM_REG^.dp[rel_risk_2Separation], currentComponentChange, onChangeHandler, kIsDouble, 0, 10);
	myComponentHelper.CreateComponentChange(FindComponent ('REPARTNERING_WOMEN'), g_pDEM_REG^.dp[repartnering_women_par], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('REPARTNERING_MEN'), g_pDEM_REG^.dp[repartnering_men_par], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('REPARTNERING_WID_WOMEN'), g_pDEM_REG^.dp[repartnering_wid_women_par], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('REPARTNERING_WID_MEN'), g_pDEM_REG^.dp[repartnering_wid_men_par], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('AMENO_ALPHA'), g_pDEM_REG^.dp[amenorrhea_alpha], currentComponentChange, onChangeHandler, kIsDouble, -100, 100);
	myComponentHelper.CreateComponentChange(FindComponent ('AMENO_BETA'), g_pDEM_REG^.dp[amenorrhea_beta], currentComponentChange, onChangeHandler, kIsDouble, -100, 100);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_AMENORRHEA'), g_GENPARAM.RUNTIME[NStepsAmeno], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('FIXED_AMENORRHEA'), g_GENPARAM.fixedParameters [fixedAmenorrhea].state, currentComponentChange, onChangeHandler);
	if StablePopulation() then currentComponentChange.ActivateDisabling (FindComponent ('ZERO_FIXED_AMENORRHEA_'));
	myComponentHelper.CreateComponentChange(FindComponent ('ZERO_FIXED_AMENORRHEA_'), g_GENPARAM.fixedParameters [fixedAmenorrhea].param, currentComponentChange, onChangeHandler, kIsDouble, 0, 100);
	myComponentHelper.CreateComponentChange(FindComponent ('EFF_CONTRACEP_BEFORE_UNION'), g_pDEM_REG^.dp[effContBeforeUnion], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('CONTRACEP_TIME_AFTER_FIRST_UNION'), g_pDEM_REG^.dp[meanTimeContraceptionAfterUnionHigh], currentComponentChange, onChangeHandler, kIsDouble, 0, 8);
	if StablePopulation() then currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_CONTRACEP_BEFORE_FIRST_CHILD'), 0, 1000000000);
	myComponentHelper.CreateComponentChange(FindComponent ('NSTEP_CONTRACEP_BEFORE_FIRST_CHILD'), g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('PROP_CONTRACEP_AFTER_FIRST_UNION'), g_pDEM_REG^.dp[propContraceptionAfterUnion], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);
	myComponentHelper.CreateComponentChange(FindComponent ('EFF_STOPPING_CONTRACEP'), g_pDEM_REG^.effStopping, currentComponentChange, TNotifyEvent(onValidateHandler), kIsInteger, 0, 1, kMaxIndBirthIntervals, kMaxIndBirthIntervals);
	myComponentHelper.CreateComponentChange(FindComponent ('PROP_USING_SPACING'), g_pDEM_REG^.effSpacing, currentComponentChange, TNotifyEvent(onValidateHandler), kIsInteger, 0, 1, kMaxIndBirthIntervals, kMaxIndBirthIntervals);
	myComponentHelper.CreateComponentChange(FindComponent ('WAITING_TIME_SPACING'), g_pDEM_REG^.meanTimeSpacing, currentComponentChange, TNotifyEvent(onValidateHandler), kIsInteger, 0, 8, kMaxIndBirthIntervals, kMaxIndBirthIntervals);
	myComponentHelper.CreateComponentChange(FindComponent ('PROP_WOMEN_AT_BIRTH'), g_pDEM_REG^.dp[propWomenAtBirth], currentComponentChange, onChangeHandler, kIsDouble, 0, 1);

	//myComponentHelper.CreateComponentChange(FindComponent ('DUMP'), g_GENPARAM.DUMP, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('DUMPALL'), g_GENPARAM.DUMPALL, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateUnCheck (FindComponent ('WRITE_ONLY_CHANGES'), true);
	myComponentHelper.CreateComponentChange(FindComponent ('DUMPALLCOHORTS'), g_GENPARAM.DUMPALLCOHORTS, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('CREATE_COHORT_FILE'), g_GENPARAM.CREATE_COHORT_FILE, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('DETAILED_COHORT_DATA'), g_GENPARAM.DETAILED_COHORT_DATA, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('WRITE_ONLY_CHANGES'), g_GENPARAM.WRITE_ONLY_CHANGES, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FIXED_FERTILITY_VALUE'), g_GENPARAM.FIXED_FERTILITY_VALUE, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FIXED_FERTILITY'), g_GENPARAM.FIXED_FERTILITY, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('FIXED_FERTILITY_VALUE'));
	currentComponentChange.ActivateDisabling (FindComponent ('CTFR'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('APRIORI_PPR'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_CONTRACEPTION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('PPR_TARGET'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('SEP_TARGET'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('MEAN_AGE_UNION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('MEAN_AGE_UNION_HIGH'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_UNION_MEAN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('MEAN_AGE_UNION_HIGH'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('EVER_INUNION_PROP'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('EVER_INUNION_PROP_HIGH'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_UNION_PROP'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('STD_DEV_AGE_UNION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_UNION_STDDEV'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('FIXED_AGE_UNION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('MEAN_AGE_UNION_MEN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('EVER_INUNION_PROP_MEN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('SEPARATION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('SEPARATION_ADJUSTED'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_SEPARATION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('SECOND_SEPARATION_REL_RISK'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('REPARTNERING_WOMEN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('REPARTNERING_MEN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('REPARTNERING_WID_WOMEN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('REPARTNERING_WID_MEN'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('AMENO_ALPHA'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('AMENO_BETA'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_AMENORRHEA'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('FIXED_AMENORRHEA'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('ZERO_FIXED_AMENORRHEA_'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('EFF_CONTRACEP_BEFORE_UNION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('CONTRACEP_TIME_AFTER_FIRST_UNION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('NSTEP_CONTRACEP_BEFORE_FIRST_CHILD'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('PROP_CONTRACEP_AFTER_FIRST_UNION'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('EFF_STOPPING_CONTRACEP'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('PROP_USING_SPACING'), kNotUsed, kNotUsed, true);
	currentComponentChange.ActivateDisabling (FindComponent ('WAITING_TIME_SPACING'), kNotUsed, kNotUsed, true);
	myComponentHelper.CreateComponentChange(FindComponent ('STABLE_POPULATION'), g_GENPARAM.STABLE_POPULATION, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('EDUCATION'), g_GENPARAM.eduKind, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FILENAME'), g_FileName, currentComponentChange, onChangeHandler, kIsString);
	myComponentHelper.CreateComponentChange(FindComponent ('DEM_REG_FILENAME'), g_FileName_DemographicRegime, currentComponentChange, onChangeHandler, kIsString);
	myComponentHelper.CreateComponentChange(FindComponent ('BOOTSTRAP_NRUNS'), g_GENPARAM.RUNTIME[gBootstrap_nRuns], currentComponentChange, onChangeHandler, kIsInteger, 1, 1000000);
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES'), g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES, currentComponentChange, onChangeHandler);

	EnableControl (self, 'NSTEP_UNION_MEAN', StablePopulation());
	EnableControl (self, 'NSTEP_UNION_PROP', StablePopulation());
	EnableControl (self, 'NSTEP_UNION_STDDEV', StablePopulation());
	EnableControl (self, 'NSTEP_SEPARATION', StablePopulation());
	EnableControl (self, 'NSTEP_AMENORRHEA', StablePopulation());
	EnableControl (self, 'FIXED_AMENORRHEA', StablePopulation());
	EnableControl (self, 'ZERO_FIXED_AMENORRHEA_', StablePopulation());
	EnableControl (self, 'NSTEP_CONTRACEP_BEFORE_FIRST_CHILD', StablePopulation());
	EnableControl (self, 'NSTEP_CONTRACEPTION', StablePopulation());

	//gFocusHandler := nil;

end;

procedure TConfigForm.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TConfigForm.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TConfigForm.updateValues;
begin
	self.componentsInfoDestroy;
	self.componentsInfoCreate;
	self.showValues;
end;

procedure TConfigForm.myChangeHandler(Sender : TObject);
begin	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	ToggleChanges(Sender);
end;

procedure TConfigForm.myFocusHandler(Sender : TObject);
begin
	//TWinControl (FindComponent('FERTILITY')).SetFocus;
end;

procedure TConfigForm.myValidateHandler(Sender : TObject; aCol, aRow: Integer;
	const OldValue: string; var NewValue: string);
begin
	firstComponentChange.ValidateAndReadValue(TComponent (Sender).name, aCol, aRow, OldValue, NewValue);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	ToggleChanges(Sender);
end;

//================ END COMMON PART ============//


initialization
{$I kinfertres.lrs}
end.

