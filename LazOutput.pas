unit LazOutput;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
	LazKinHeirSet, LazKinDecedentSet, LazKinSelection, LazKinOutputFields, LazDemoCareFields, ComponentHelper;

type

	{ TOutputForm }

	TOutputForm = class(TForm)
		AGE_CHILDBEARING: TCheckBox;
		ALL_NONE: TButton;
		ALL_EGO_PARTNERS_GENEALOGY: TCheckBox;
        FERT_SURVEY_MAX: TEdit;
        FERT_SURVEY_MIN: TEdit;
        FertSurveyMinLab: TLabel;
        FertSurvMaxLab: TLabel;
		OUTPUT_FERT_SURVEY: TCheckBox;
		WRITE_ADJUSTED_VALUES: TCheckBox;
		WRITE_FOLDER: TCheckBox;
		COUNTRY_INHERITANCE_RULES: TComboBox;
		countryLab: TLabel;
		NON_BIO_KIN: TCheckBox;
		PARTNER_FULL_HEIR: TCheckBox;
		PARTNER_FIRST_HEIR: TCheckBox;
		InheritanceGroup: TGroupBox;
		INHERITANCE: TCheckBox;
		optionalFieldsBtn: TButton;
		PARTNER_DECEDENT: TCheckBox;
		decedentsSetBtn: TButton;
		heirsSetBtn: TButton;
		KinSelectionBtn: TButton;
		TALKATIVE: TCheckBox;
		SAVE_LOG: TCheckBox;
		FORCE_NUM_THREADS: TCheckBox;
		MAX_THREADS: TEdit;
		MaxThreadsLab: TLabel;
		PPRS_BY_UNION_STATUS: TCheckBox;
		PARITY_BY_AGE_AT_UNION: TCheckBox;
		FERTILITY_BY_UNION_STATUS: TCheckBox;
		KIN_TOTAL_NUMBERS: TCheckBox;
		MULTITHREADING_SIMKIN: TCheckBox;
		MULTITHREADING_INITMOTHERHOOD: TCheckBox;
		MULTITHREADING_INIT: TCheckBox;
		MultiTypeBox: TGroupBox;
		MultithreadingBox: TGroupBox;
		UNION_TABLE: TCheckBox;
		ZIP_INDIVIDUAL: TCheckBox;
		MULTITHREADING: TCheckBox;
		OUTPUT_AGGREGATE_FERTILITY: TCheckBox;
		OUTPUT_EXCLUDE_ABORTION: TCheckBox;
		OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED: TCheckBox;
		NUM_KIN_AGE: TCheckBox;
		KIN_FATHERS_SONS: TCheckBox;
		KIN_DISTRIBUTION: TCheckBox;
		KIN_RELATIVE_DISTRIBUTION: TCheckBox;
		KIN_AGE_DISTRIBUTION: TCheckBox;
		KIN_STATISTICS: TCheckBox;
		KinshipAggrResultsBox: TGroupBox;
		DUMP_UNION_TABLE: TCheckBox;
		OUTPUT_MAXNUMBIRTHS: TEdit;
		MaxBirthsLab: TLabel;
		OUTPUT_MAXNUMUNION: TEdit;
		FLOATING_POINT_DIGITS: TEdit;
		FLOATING_POINT_PRECISION: TEdit;
		FERTILITY_BY_UNION_DURATION: TCheckBox;
		INTERVAL_CONCEPTION_UNION_TABLE: TCheckBox;
		floatPrecisionLab: TLabel;
		floatDigitsLab: TLabel;
		INUNION_STATE_TABLE: TCheckBox;
		KinIndFileFmtLab: TLabel;
		KINSHIPGroup: TGroupBox;
		KINSHIP_INDIV_FORMAT: TComboBox;
		MaxUnionLab: TLabel;
		OUTPUT_AGGREGATE_KINSHIP: TCheckBox;
		OUTPUT_INDIVIDUAL_AGE_FLOAT: TCheckBox;
		GeneralBox: TGroupBox;
		NO_FECUNDATION: TCheckBox;
		OUTPUT_INDIVIDUAL_KINSHIP_INFO: TCheckBox;
		PROP_CELIBACY: TCheckBox;
		COHORT_FERTILITY_TABLE: TCheckBox;
		COHORT_TFR: TCheckBox;
		REPARTNERING_STATE_TABLE: TCheckBox;
		PARITY_AGE_TABLE: TCheckBox;
		DURATION_TABLE: TCheckBox;
		LAST_BIRTH: TCheckBox;
		INTERVAL_TABLE: TCheckBox;
		GENERAL_FERTILITY: TCheckBox;
		FertilityAggrResultsBox: TGroupBox;
		OUTPUT_INDIVIDUAL_FERTILITY_INFO: TCheckBox;
		FERTILITYGroup: TGroupBox;
		OKBtn: TButton;
		procedure AllKinBtnClick(Sender: TObject);
		procedure ALL_NONEClick(Sender: TObject);
		procedure decedentsSetBtnClick(Sender: TObject);
		procedure heirsSetBtnClick(Sender: TObject);
		procedure KinList_ShowHint(Sender: TObject; HintInfo: PHintInfo);
		procedure KinSelectionBtnClick(Sender: TObject);
		procedure optionalFieldsBtnClick(Sender: TObject);
		procedure OutputFileFields_ShowHint(Sender: TObject; HintInfo: PHintInfo);
		procedure OKBtnClick(Sender: TObject);

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
		all_none_state: boolean;
	end;

var
	OutputForm: TOutputForm;

implementation

{$R *.lfm}

uses
	LazConfig,
	Declarations, Utilities;

{ TOutputForm }

procedure TOutputForm.OKBtnClick(Sender: TObject);
begin
	ModalResult := mrClose;
end;

procedure TOutputForm.AllKinBtnClick(Sender: TObject);
var
	rel: KinTypes;
begin
	g_GENPARAM.OUTPUT_KINTYPES.value := [];
	for rel := kFirstKinInEnum to kLastKinInEnum do begin
		Include (g_GENPARAM.OUTPUT_KINTYPES.value, rel);
	end;
	gCheckSelected := FALSE;
	FormActivate (Sender);
	gCheckSelected := true;
end;

procedure TOutputForm.ALL_NONEClick(Sender: TObject);
var
	res: outputKind_boolean;
begin
	NoOnChange;
	for res := low(outputKind_boolean) to high(outputKind_boolean) do begin
		if res <> cmd_outputtomainfile then next;
	
		if 	(g_GENPARAM.FERTILITY.value and (res in outputs_fertility)) or
			(g_GENPARAM.KINSHIP.value and (res in outputs_kinship)) then
			g_GENPARAM.outputs_opt [res].value := all_none_state;
	end;
	all_none_state := not all_none_state;
	showValues;
end;

procedure TOutputForm.decedentsSetBtnClick(Sender: TObject);
begin
	NoOnChange;
	DecedentsSet.ShowModal;
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or OutputForm.ChangesMadeToDefaultValues;
end;

procedure TOutputForm.heirsSetBtnClick(Sender: TObject);
begin
	NoOnChange;
	HeirsSet.ShowModal;
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or OutputForm.ChangesMadeToDefaultValues;
end;

procedure TOutputForm.KinList_ShowHint(Sender: TObject; HintInfo: PHintInfo);
begin
	if HintInfo^.CursorPos.y > HintInfo^.CursorRect.Bottom then
		application.cancelhint;
end;

procedure TOutputForm.KinSelectionBtnClick(Sender: TObject);
begin
	NoOnChange;
	KinSelectionForm.ShowModal;
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or OutputForm.ChangesMadeToDefaultValues;
end;

procedure TOutputForm.optionalFieldsBtnClick(Sender: TObject);
begin

	NoOnChange;
	{each output file format has its own set of optional fields}
	if g_GENPARAM.kinIndFmt.value = out_DemoCare then
		DemoCareFields.ShowModal
	else if g_GENPARAM.kinIndFmt.value = out_EgoGenealogy then
		KinOutputFields.ShowModal;
	{out_GEDCOM has no optional fields yet: the button is disabled in TKinFmtComboBoxChange.selectFields}
	ChangesMadeToDefaultValues := ChangesMadeToDefaultValues or OutputForm.ChangesMadeToDefaultValues;
end;

procedure TOutputForm.OutputFileFields_ShowHint(Sender: TObject; HintInfo: PHintInfo);
begin
	if HintInfo^.CursorPos.y > HintInfo^.CursorRect.Bottom then
		application.cancelhint;
end;

//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
destructor TOutputForm.Destroy;
begin
	if not FirstTime then
		componentsInfoDestroy;
	inherited;
end;

procedure TOutputForm.FormCreate(Sender: TObject);
begin
	//================ COMMON PART FOR EACH FORM WITH componentChange values ============//
	FirstTime := True;
	ChangesMadeToDefaultValues := false;
	onChangeHandler := @myChangeHandler;
 //====== END COMMON PART =====//
	all_none_state := true;
	selectionChangeHandler := @mySelectionChangeHandler;
end;

procedure TOutputForm.FormActivate(Sender: TObject);
begin
	if FirstTime then begin
		FirstTime := False;
	end else begin
		componentsInfoDestroy;
	end;
	componentsInfoCreate;
	showValues;
end;

procedure TOutputForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
	CanClose := true;
	NoOnChange;
end;

// ========= THE SAME PROCEDURE EXISTS, BUT WITH DIFFERENT CONTENT ============//
procedure TOutputForm.componentsInfoCreate;
var
	currentComponentChange: TComponentChange = nil;
begin
	if not g_GENPARAM.KINSHIP.value then begin
		g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value := false;
	end;
	if not g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value then begin
		g_GENPARAM.INHERITANCE.value := false;
	end;
	if not g_GENPARAM.INHERITANCE.value then begin
		g_GENPARAM.PARTNER_FIRST_HEIR.value := false;
		g_GENPARAM.PARTNER_FULL_HEIR.value := false;
		g_GENPARAM.PARTNER_DECEDENT.value := false;
	end;
	if not g_GENPARAM.PARTNER_FIRST_HEIR.value then
		g_GENPARAM.PARTNER_FULL_HEIR.value := false;
	if not g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value then
		g_GENPARAM.OUTPUT_FERT_SURVEY.value := false;
	
	myComponentHelper := TComponentHelper.Create;
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_AGGREGATE_KINSHIP'), g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP, firstComponentChange, onChangeHandler);
	currentComponentChange := firstComponentChange;
	if g_GENPARAM.KINSHIP.value then begin
		currentComponentChange.ActivateDisabling (FindComponent ('KIN_STATISTICS'));
		currentComponentChange.ActivateDisabling (FindComponent ('KIN_FATHERS_SONS'));
		currentComponentChange.ActivateDisabling (FindComponent ('KIN_DISTRIBUTION'));
		currentComponentChange.ActivateDisabling (FindComponent ('KIN_RELATIVE_DISTRIBUTION'));
		currentComponentChange.ActivateDisabling (FindComponent ('KIN_AGE_DISTRIBUTION'));
		currentComponentChange.ActivateDisabling (FindComponent ('NUM_KIN_AGE'));
		currentComponentChange.ActivateDisabling (FindComponent ('UNION_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('KIN_TOTAL_NUMBERS'));
	end;
	myComponentHelper.CreateComponentChange(FindComponent ('KIN_STATISTICS'), g_GENPARAM.outputs_opt [res_kin_stats], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('KIN_FATHERS_SONS'), g_GENPARAM.outputs_opt [res_kin_fathers_son], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('KIN_DISTRIBUTION'), g_GENPARAM.outputs_opt [res_kin_dist], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('KIN_RELATIVE_DISTRIBUTION'), g_GENPARAM.outputs_opt [res_kin_reldist], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('KIN_AGE_DISTRIBUTION'), g_GENPARAM.outputs_opt [res_kin_agedist], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('NUM_KIN_AGE'), g_GENPARAM.outputs_opt [res_kin_numByAge], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('UNION_TABLE'), g_GENPARAM.outputs_opt [res_kin_unionTable], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('KIN_TOTAL_NUMBERS'), g_GENPARAM.outputs_opt [res_kin_totalNumbers], currentComponentChange, onChangeHandler);

	myComponentHelper.CreateComponentChange(FindComponent ('KINSHIP_INDIV_FORMAT'), g_GENPARAM.kinIndFmt, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('COUNTRY_INHERITANCE_RULES'), g_GENPARAM.countryInheritance, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('PARTNER_FULL_HEIR'), g_GENPARAM.PARTNER_FULL_HEIR, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('PARTNER_FIRST_HEIR'), g_GENPARAM.PARTNER_FIRST_HEIR, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('PARTNER_FULL_HEIR'));
	currentComponentChange.ActivateUnCheck (FindComponent ('PARTNER_FULL_HEIR'));
	myComponentHelper.CreateComponentChange(FindComponent ('PARTNER_DECEDENT'), g_GENPARAM.PARTNER_DECEDENT, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('ALL_EGO_PARTNERS_GENEALOGY'), g_GENPARAM.ALL_EGO_PARTNERS_GENEALOGY, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('INHERITANCE'), g_GENPARAM.INHERITANCE, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('COUNTRY_INHERITANCE_RULES'));
	currentComponentChange.ActivateDisabling (FindComponent ('countryLab'));
	currentComponentChange.ActivateDisabling (FindComponent ('heirsSetBtn'));
	currentComponentChange.ActivateDisabling (FindComponent ('decedentsSetBtn'));
	currentComponentChange.ActivateDisabling (FindComponent ('PARTNER_DECEDENT'));
	//currentComponentChange.ActivateDisabling (FindComponent ('ALL_EGO_PARTNERS_GENEALOGY'));
	currentComponentChange.ActivateDisabling (FindComponent ('PARTNER_FIRST_HEIR'));
	currentComponentChange.ActivateUnCheck (FindComponent ('PARTNER_FIRST_HEIR'));
	myComponentHelper.CreateComponentChange(FindComponent ('NON_BIO_KIN'), g_GENPARAM.NON_BIO_KIN, currentComponentChange, onChangeHandler);
	//myComponentHelper.CreateComponentChange(FindComponent ('OutputFileFields_'), g_GENPARAM.OUTPUT_FIELDS, currentComponentChange, TNotifyEvent(selectionChangeHandler));
	//myComponentHelper.CreateComponentChange(FindComponent ('KinList_'), g_GENPARAM.OUTPUT_KINTYPES, currentComponentChange, TNotifyEvent(selectionChangeHandler));
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_INDIVIDUAL_KINSHIP_INFO'), g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO, currentComponentChange, onChangeHandler);
	if g_GENPARAM.KINSHIP.value then begin
		currentComponentChange.ActivateDisabling (FindComponent ('KinSelectionBtn'));
		currentComponentChange.ActivateDisabling (FindComponent ('ALL_EGO_PARTNERS_GENEALOGY'));
		currentComponentChange.ActivateDisabling (FindComponent ('INHERITANCE'));
		currentComponentChange.ActivateUnCheck (FindComponent ('INHERITANCE'));
		currentComponentChange.ActivateDisabling (FindComponent ('KINSHIP_INDIV_FORMAT'));
		currentComponentChange.ActivateDisabling (FindComponent ('KinIndFileFmtLab'));
		currentComponentChange.ActivateDisabling (FindComponent ('optionalFieldsBtn'));
		//currentComponentChange.ActivateDisabling (FindComponent ('AllKinBtn'));
		currentComponentChange.ActivateDisabling (FindComponent ('NON_BIO_KIN'));
		//currentComponentChange.ActivateDisabling (FindComponent ('KinList_'));
		//currentComponentChange.ActivateDisabling (FindComponent ('OutputFileFields_'));
	end;

	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_INDIVIDUAL_FERTILITY_INFO'), g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO, currentComponentChange, onChangeHandler);
	if g_GENPARAM.FERTILITY.value then begin
		currentComponentChange.ActivateDisabling (FindComponent ('OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED'));
		currentComponentChange.ActivateDisabling (FindComponent ('OUTPUT_EXCLUDE_ABORTION'));
		currentComponentChange.ActivateDisabling (FindComponent ('OUTPUT_FERT_SURVEY'));
	end;
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED'), g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_EXCLUDE_ABORTION'), g_GENPARAM.OUTPUT_EXCLUDE_ABORTION, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_FERT_SURVEY'), g_GENPARAM.OUTPUT_FERT_SURVEY, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('FERT_SURVEY_MIN'));
	currentComponentChange.ActivateDisabling (FindComponent ('FERT_SURVEY_MAX'));

	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_INDIVIDUAL_AGE_FLOAT'), g_GENPARAM.OUTPUT_INDIVIDUAL_AGE_FLOAT, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FLOATING_POINT_PRECISION'), g_GENPARAM.outputs_fmt [res_floatingNumberPrecision], currentComponentChange, onChangeHandler, kIsInteger, 1, 15);
	myComponentHelper.CreateComponentChange(FindComponent ('FLOATING_POINT_DIGITS'), g_GENPARAM.outputs_fmt [res_floatingNumberDigits], currentComponentChange, onChangeHandler, kIsInteger, 1, 10);
	myComponentHelper.CreateComponentChange(FindComponent ('FERT_SURVEY_MIN'), g_GENPARAM.outputs_fmt [res_fertSurvey_ageMin], currentComponentChange, onChangeHandler, kIsInteger, 1, 30);
	myComponentHelper.CreateComponentChange(FindComponent ('FERT_SURVEY_MAX'), g_GENPARAM.outputs_fmt [res_fertSurvey_ageMax], currentComponentChange, onChangeHandler, kIsInteger, 1, 99);
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_MAXNUMUNION'), g_GENPARAM.outputs_fmt [res_numUnion], currentComponentChange, onChangeHandler, kIsInteger, 1, 30);
	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_MAXNUMBIRTHS'), g_GENPARAM.outputs_fmt [res_numBirths], currentComponentChange, onChangeHandler, kIsInteger, 1, 50);
	myComponentHelper.CreateComponentChange(FindComponent ('ZIP_INDIVIDUAL'), g_GENPARAM.ZIP_INDIVIDUAL, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('SAVE_LOG'), g_GENPARAM.SAVE_LOG, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('WRITE_FOLDER'), g_GENPARAM.WRITE_FOLDER, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('WRITE_ADJUSTED_VALUES'), g_GENPARAM.WRITE_ADJUSTED_VALUES, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('TALKATIVE'), g_GENPARAM.TALKATIVE, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('MULTITHREADING_INIT'), g_GENPARAM.MULTITHREADING_INIT, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('MULTITHREADING_INITMOTHERHOOD'), g_GENPARAM.MULTITHREADING_INITMOTHERHOOD, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('MULTITHREADING_SIMKIN'), g_GENPARAM.MULTITHREADING_SIMKIN, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('MULTITHREADING'), g_GENPARAM.MULTITHREADING, currentComponentChange, onChangeHandler);
	currentComponentChange.ActivateDisabling (FindComponent ('MULTITHREADING_INIT'));
	currentComponentChange.ActivateDisabling (FindComponent ('MULTITHREADING_INITMOTHERHOOD'));
	currentComponentChange.ActivateDisabling (FindComponent ('MULTITHREADING_SIMKIN'));
	myComponentHelper.CreateComponentChange(FindComponent ('FORCE_NUM_THREADS'), g_GENPARAM.FORCE_NUM_THREADS, currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('MAX_THREADS'), g_GENPARAM.outputs_fmt [res_maxThreads], currentComponentChange, onChangeHandler, kIsInteger, 1, 999999);

	myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_AGGREGATE_FERTILITY'), g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY, currentComponentChange, onChangeHandler);
	if g_GENPARAM.FERTILITY.value then begin
		currentComponentChange.ActivateDisabling (FindComponent ('GENERAL_FERTILITY'));
		currentComponentChange.ActivateDisabling (FindComponent ('INTERVAL_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('INTERVAL_CONCEPTION_UNION_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('LAST_BIRTH'));
		currentComponentChange.ActivateDisabling (FindComponent ('DURATION_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('PARITY_AGE_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('REPARTNERING_STATE_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('COHORT_TFR'));
		currentComponentChange.ActivateDisabling (FindComponent ('AGE_CHILDBEARING'));
		currentComponentChange.ActivateDisabling (FindComponent ('COHORT_FERTILITY_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('PROP_CELIBACY'));
		currentComponentChange.ActivateDisabling (FindComponent ('NO_FECUNDATION'));
		currentComponentChange.ActivateDisabling (FindComponent ('DUMP_UNION_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('INUNION_STATE_TABLE'));
		currentComponentChange.ActivateDisabling (FindComponent ('FERTILITY_BY_UNION_DURATION'));
		currentComponentChange.ActivateDisabling (FindComponent ('FERTILITY_BY_UNION_STATUS'));
		currentComponentChange.ActivateDisabling (FindComponent ('PPRS_BY_UNION_STATUS'));
		currentComponentChange.ActivateDisabling (FindComponent ('PARITY_BY_AGE_AT_UNION'));
		//currentComponentChange.ActivateDisabling (FindComponent ('OUTPUT_MAIN_FILE'));
	end;

	myComponentHelper.CreateComponentChange(FindComponent ('GENERAL_FERTILITY'), g_GENPARAM.outputs_opt [res_fert_GenFert], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('INTERVAL_TABLE'), g_GENPARAM.outputs_opt [res_fert_intervals], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('INTERVAL_CONCEPTION_UNION_TABLE'), g_GENPARAM.outputs_opt [res_fert_intervals_conceptions], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('LAST_BIRTH'), g_GENPARAM.outputs_opt [res_fert_LastChild], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('DURATION_TABLE'), g_GENPARAM.outputs_opt [res_fert_durationPreviousEvent], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('PARITY_AGE_TABLE'), g_GENPARAM.outputs_opt [res_fert_FinalParity_parity_age], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('REPARTNERING_STATE_TABLE'), g_GENPARAM.outputs_opt [res_fert_repartneringStatesType], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('COHORT_TFR'), g_GENPARAM.outputs_opt [res_fert_CTFR], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('AGE_CHILDBEARING'), g_GENPARAM.outputs_opt [res_fert_AgeChildbearing], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('COHORT_FERTILITY_TABLE'), g_GENPARAM.outputs_opt [res_fert_TotFert], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('PROP_CELIBACY'), g_GENPARAM.outputs_opt [res_fert_prop_single], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('NO_FECUNDATION'), g_GENPARAM.outputs_opt [res_fert_no_fecundation], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('DUMP_UNION_TABLE'), g_GENPARAM.outputs_opt [res_fert_dump_UnionTable], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('INUNION_STATE_TABLE'), g_GENPARAM.outputs_opt [res_fert_dump_UnionStates], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FERTILITY_BY_UNION_DURATION'), g_GENPARAM.outputs_opt [res_fert_fertility_durationUnion], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('FERTILITY_BY_UNION_STATUS'), g_GENPARAM.outputs_opt [res_fert_fertility_unionStatus], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('PPRS_BY_UNION_STATUS'), g_GENPARAM.outputs_opt [res_fert_PPRs], currentComponentChange, onChangeHandler);
	myComponentHelper.CreateComponentChange(FindComponent ('PARITY_BY_AGE_AT_UNION'), g_GENPARAM.outputs_opt [res_fert_ageFirstUnion], currentComponentChange, onChangeHandler);

	//myComponentHelper.CreateComponentChange(FindComponent ('OUTPUT_MAIN_FILE'), g_GENPARAM.outputs_opt [cmd_outputtomainfile], currentComponentChange, onChangeHandler);

	EnableControl (self, 'OUTPUT_INDIVIDUAL_KINSHIP_INFO', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KINSHIP_INDIV_FORMAT', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'PARTNER_DECEDENT', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'ALL_EGO_PARTNERS_GENEALOGY', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'NON_BIO_KIN', g_GENPARAM.KINSHIP.value);
	//EnableControl (self, 'OutputFileFields_', g_GENPARAM.KINSHIP.value);
	//EnableControl (self, 'KinList_', g_GENPARAM.KINSHIP.value);

	EnableControl (self, 'OUTPUT_AGGREGATE_KINSHIP', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KIN_STATISTICS', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KIN_FATHERS_SONS', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KIN_DISTRIBUTION', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KIN_RELATIVE_DISTRIBUTION', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KIN_AGE_DISTRIBUTION', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'NUM_KIN_AGE', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'UNION_TABLE', g_GENPARAM.KINSHIP.value);
	EnableControl (self, 'KIN_TOTAL_NUMBERS', g_GENPARAM.KINSHIP.value);

	EnableControl (self, 'OUTPUT_INDIVIDUAL_FERTILITY_INFO', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'OUTPUT_EXCLUDE_ABORTION', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'OUTPUT_FERT_SURVEY', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'OUTPUT_AGGREGATE_FERTILITY', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'GENERAL_FERTILITY', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'INTERVAL_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'INTERVAL_CONCEPTION_UNION_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'LAST_BIRTH', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'DURATION_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'PARITY_AGE_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'REPARTNERING_STATE_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'COHORT_TFR', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'AGE_CHILDBEARING', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'COHORT_FERTILITY_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'PROP_CELIBACY', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'NO_FECUNDATION', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'DUMP_UNION_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'INUNION_STATE_TABLE', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'FERTILITY_BY_UNION_DURATION', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'FERTILITY_BY_UNION_STATUS', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'PPRS_BY_UNION_STATUS', g_GENPARAM.FERTILITY.value);
	EnableControl (self, 'PARITY_BY_AGE_AT_UNION', g_GENPARAM.FERTILITY.value);
	//EnableControl (self, 'OUTPUT_MAIN_FILE', g_GENPARAM.FERTILITY.value);
end;

procedure TOutputForm.componentsInfoDestroy;
begin
	FreeAndNil (myComponentHelper);
	FreeAndNil (firstComponentChange);
end;

procedure TOutputForm.NoOnChange;
begin
	firstComponentChange.ActOnChange(false);
end;

procedure TOutputForm.showValues;
begin
	firstComponentChange.ShowValue;
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
	firstComponentChange.ActOnChange(true);
end;

procedure TOutputForm.myChangeHandler(Sender : TObject);
begin
	firstComponentChange.ReadValue(TComponent (Sender).name);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

procedure TOutputForm.mySelectionChangeHandler(Sender : TObject; used: boolean);
begin
	firstComponentChange.SelectedValue(TComponent (Sender).name, used);
	ChangesMadeToDefaultValues := checkChangedDefaultValues();
end;

//================ END COMMON PART ============//

end.

