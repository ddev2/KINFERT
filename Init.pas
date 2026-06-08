{$I Defines.pas}
unit Init;
interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	SysUtils, Math, NumCPULib, Declarations, DemographicRegime, Fertility, RandomNumbers, {$IFDEF VerboseProfiler}Profiler,{$ENDIF} Utilities, Memory;

	procedure initGeneral;
	procedure clearResults ( var nSimul: longint );
	procedure initResults ( filename: string; nSimul: longint );
	function initParams(randomGenerator: TRandomNumberGenerator): boolean;
	procedure initGeneralCmd;
	procedure initResultats;
	procedure publishResult (res: outputKind_boolean; state: boolean; name: string = ''; comment: string = '');
	procedure closeAll;
	
	procedure zero_kinshipStruct (var tabKinship: KinshipStruct);
	procedure zero_KinByAgeEgoStruct (var tabKinship: KinByAgeEgoStruct);

	function init_kinshipStruct: pKinshipStruct;

	function initKinshipTree(var nbTotRelatives: longint): pRelativeType;

	function newRelative (	pLastRelative: pRelativeType;
							kinOf: pRelativeType;
							var nbTotRelatives: longint;
							typeOfKin: KinTypes = kt_none
							): pRelativeType;
	procedure initRelative (par: KinTypes; var pLastRelative: pRelativeType; parKinOf: pRelativeType;
							var  nbTotRelatives: longint);

	procedure disposeKinship (var pEgo: pRelativeType);

implementation
var
	memoryAllocated: boolean = FALSE;
		
	procedure initEcran;

	begin
//		SetRect(r, 0, 40, 512, 342);
//		SetTextRect(r);
//		ShowText;
	end; {Ecran}

	procedure initMemory_fec;
	begin
		SetLength (gFecundability, kMaxAgeFert+1);
		SetLength (gDefinitive_sterility, kMaxAgeFert+1);
	end;

	procedure releaseMemory_fec;
	begin
		SetLength (gFecundability, 0);
		SetLength (gDefinitive_sterility, 0);
	end;

	procedure initMemory;
	begin
		g_GENPARAM.memoryAllocatedPIN := 0;
		memoryAllocated := true;

		initMemory_fec;

		gIntrauterine_mortality_risk := SetLengthDoubleZero (kMaxAgeFert+1);
		gStillbirth_mortality_risk := SetLengthDoubleZero (kMaxAgeFert+1);
		gDistrib_intrauterine_mortality_risk := SetLengthDoubleZero (9);
		

		gDistrib_fecundability := SetLengthDoubleZero (kMaxDistribFecundability+1);
	
	end;

	procedure clearResults ( var nSimul: longint );
	begin
		nSimul := 0;

		g_nRuns_aggrKinship := 0;
		
		SetLength(g_FileNames, 0);
		SetLength(g_FileNames, 1);
		SetLength(gOut_totKinship, 0);
		SetLength(gOut_totKinship, 1);
		SetLength(g_NumKinByAgeEgo, 0);
		SetLength(g_NumKinByAgeEgo, 1);

		SetLength(gOut_intervals_between_conceptions, 0);
		SetLength(gOut_intervals_between_conceptions, 1, kMaxNbChildrenCalc, kMaxDurationIntervalsInMonth+2);		
	end;

	procedure initResults ( filename: string; nSimul: longint );
	begin
		if (g_GENPARAM.KINSHIP.value) then begin
			Inc (g_nRuns_aggrKinship);
			SetLength(g_FileNames, g_nRuns_aggrKinship);
			g_FileNames [g_nRuns_aggrKinship-1] := filename;
			SetLength(gOut_totKinship, g_nRuns_aggrKinship);
			SetLength(g_NumKinByAgeEgo, g_nRuns_aggrKinship);
		end;

		SetLength (gOut_intervals_between_conceptions, nSimul, kMaxNbChildrenCalc, kMaxDurationIntervalsInMonth+2);		
	end;
	
	procedure disposeUnionList (var aUnion: pUnionInfoType);
	begin
		if aUnion = nil then exit;
		disposeUnionList (aUnion^.next);
		disposePtr(ptr(aUnion), 'pU');
		aUnion := nil;
	end;

	procedure disposeKinshipOld (var pEgo: pRelativeType);
	begin
		if pEgo = nil then exit;
		disposeKinship (pEgo^.nextRelative);
		disposeUnionList (pEgo^.UList);
		pEgo^.childrenList.Destroy;
		disposePtr(ptr(pEgo), 'pR');
		pEgo := nil;
	end;

	procedure disposeKinship (var pEgo: pRelativeType);
	var
		pRel: pRelativeType;
	begin
		while (pEgo <> nil) do begin
			disposeUnionList (pEgo^.UList);
			pEgo^.childrenList.Destroy;
			setLength(pEgo^.Heirs, 0);
			setLength(pEgo^.Inheritances, 0);
			setLength(pEgo^.Heirs_2, 0);
			setLength(pEgo^.Inheritances_2, 0);
			pRel := pEgo^.nextRelative;
			disposePtr(ptr(pEgo), 'pR');
			pEgo := pRel;
		end;
		pEgo := nil;
	end;

	procedure releaseMemory;
		procedure releaseNamedObjects (obj: GenericName);
		begin
			if obj = nil then exit;
			if obj.next <> nil then releaseNamedObjects (obj.next);
			obj.Destroy;
		end;
	begin
		memoryAllocated := FALSE;
		g_GENPARAM.memoryAllocatedPIN := 0;
		
		releaseNamedObjects (g_GENPARAM.listOfParams);
		g_GENPARAM.listOfParams := nil;
		
		releaseMemory_fec;

		{dispose(gIntrauterine_mortality_risk);
		dispose(gStillbirth_mortality_risk);}
		SetLength(gIntrauterine_mortality_risk, 0);
		SetLength(gStillbirth_mortality_risk, 0);
		SetLength (gDistrib_intrauterine_mortality_risk, 0);

		SetLength (gDistrib_fecundability, 0);

	end;

	procedure initRelative (par: KinTypes; var pLastRelative: pRelativeType; parKinOf: pRelativeType;
							var  nbTotRelatives: longint);
	begin
		{initialize just created kin by new}
		Inc (nbTotRelatives);
		with pLastRelative^ do begin
			typeOfKin := par;
			kinOf := parKinOf;
			birthOrder := kNotDefined;
			ageMotherAtChildbirth := kNotDefined;
			ageFatherAtChildbirth := kNotDefined;
			indNumber := nbTotRelatives;
			gender := man;
			status := '';
			scanned := FALSE;
			descendanceSimulated := FALSE;
			cohort := kNotDefined;
			cohortDemReg := kNotDefined;
			ageAtBirthOfEgo := kNotDefined;
			yearBirth := kNotDefined;
			ageDeath := kNotDefined;
			yearDeath := kNotDefined;
			nUnions := 0;
			partnershipStatusAt50 := any;
			typeHeir := th_doNotApply;
			//egoAsHeir := eh_doNotApply;
			nHeirs := 0;
			setLength (heirs, 0);			
			nInheritances := 0;
			setLength (inheritances, 0);	
			fullTree := false;
			nHeirs_2 := 0;
			setLength (heirs_2, 0);			
			nInheritances_2 := 0;
			setLength (inheritances_2, 0);			
			inKinSet := false;
{$IFDEF addOldUnionType}
			for i := 1 to kMaxNbUnion do begin
				ageUnion[i] := kNotDefined;
				ageEndUnion[i] := kNotDefined;
				partners[i] := nil;
				endOfPartnership[i] := no_union;
			end;
{$ENDIF}
			UList := nil;
{$IFDEF OLDCHILDRENLIST}
			nbChildren := 0;
			for i:= 1 to kMaxNbChildren do begin
				children[i] := nil;
			end;
{$ENDIF}
			childrenList := TChildList.Create();
			father := nil;
			mother := nil;
			motherUnionNumber := kNotDefined;
			fatherUnionNumber := kNotDefined;
			prevRelative := nil;
			nextRelative := nil;
		end;
	end;

	function initKinshipTree(var nbTotRelatives: longint): pRelativeType;
	var
		pEgo: pRelativeType = nil;
	begin
		new(pEgo);
		newPtr (ptr(pEgo), 'pEgo');
		initRelative(kt_ego, pEgo, pEgo, nbTotRelatives);
		result := pEgo;
	end;

	function newRelative (pLastRelative: pRelativeType; kinOf: pRelativeType;
		var nbTotRelatives: longint; typeOfKin: KinTypes = kt_none): pRelativeType;
	var
		pRelative: pRelativeType;
	begin

		new(pRelative);
		newPtr (ptr(pRelative), 'relative');
		if (pLastRelative <> nil) then begin
			pLastRelative^.nextRelative := pRelative;
		end;
		initRelative(typeOfKin, pRelative, kinOf, nbTotRelatives);
		pRelative^.prevRelative := pLastRelative;

		newRelative := pRelative;
	end;

	procedure zero_kinshipStruct (var tabKinship: KinshipStruct);
	var
		age: longint;
		par: KinTypes;
		state: KinStates;
		sexT: SexTotal;
	begin
		for sexT := men to all do
			for state := born to alive do
				for par := kFirstKinInEnum to kt_total do
					for age := kMinAgeLife to kMaxAgeLife + 1 do
						tabKinship[sexT, state, par, age] := 0;
	end;

	procedure zero_KinByAgeEgoStruct (var tabKinship: KinByAgeEgoStruct);
	// Probably not necessary, but we err on the side of caution...
	var
		age: agesLife;
		par: KinTypes;
		aSex: SexTotal;
	begin
		for age := low(agesLife) to high(agesLife) do
			for par := low(KinTypes) to high(KinTypes) do
				for aSex := low(SexTotal) to high(SexTotal) do
					tabKinship [aSex, age, par] := 0;
	end;

	function init_kinshipStruct: pKinshipStruct;
	var
		tabKinship: pKinshipStruct;
	begin
		tabKinship := nil;
		new(tabKinship);
		newPtr (ptr(tabKinship), 'tabKinship');
		zero_kinshipStruct(tabKinship^);
		init_kinshipStruct := tabKinship;
	end;

	procedure initRuntime ();
		procedure initRuntimeValues;
		begin
			g_GENPARAM.RUNTIME[gBootstrap_nRuns].value := 1;
			g_GENPARAM.RUNTIME[nStepsUnion_mean].value := 1;
			g_GENPARAM.RUNTIME[nStepsUnion_prop].value := 1;
			g_GENPARAM.RUNTIME[nStepsUnion_Dev].value := 1;
			g_GENPARAM.RUNTIME[nStepsAmeno].value := 1;
			g_GENPARAM.RUNTIME[nStepsContrFert].value := 1;
			g_GENPARAM.RUNTIME[nStepsSeparation].value := 1;
			g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value := 1;
			g_GENPARAM.RUNTIME[cmd_firstCohort].value := kInitCohort;
			g_GENPARAM.RUNTIME[cmd_lastCohort].value := kInitCohort;
			g_GENPARAM.RUNTIME[cmd_stepCohort].value := 1;
			g_GENPARAM.RUNTIME[cmd_numberWomen].value := 10000;
			g_GENPARAM.outputs_fmt[res_floatingNumberDigits].value := 3;
			g_GENPARAM.outputs_fmt[res_floatingNumberPrecision].value := 10;
			g_GENPARAM.outputs_fmt[res_fertSurvey_ageMin].value := 15;
			g_GENPARAM.outputs_fmt[res_fertSurvey_ageMax].value := 50;
			g_GENPARAM.outputs_fmt[res_numUnion].value := 5;
			g_GENPARAM.outputs_fmt[res_numBirths].value := 15;
			g_GENPARAM.outputs_fmt[res_maxThreads].value := gNumCoresForMultiThreading;
		
		end;
	begin
		if g_GENPARAM.memoryAllocatedPIN <> kMemoryAllocatedPIN then begin

			{============ NUMBER AND TYPES OF RUNS =============}
			g_GENPARAM.RUNTIME[gBootstrap_nRuns] := LongintName.Create(1, 'BOOTSTRAP_NRUNS', 'Number of runs (for bootstrapping purpose)', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[nStepsUnion_mean] := LongintName.Create(1, 'NSTEP_UNION_MEAN',
				'Number of steps for mean age at union' + LineEnding +
				'(taking extreme values between MEAN_AGE_UNION and MEAN_AGE_UNION_HIGH)', g_GENPARAM.listOfParams); {Change age at union}
			g_GENPARAM.RUNTIME[nStepsUnion_prop] := LongintName.Create(1, 'NSTEP_UNION_PROP',
				'Number of steps for proportion ever in union at age 50' + LineEnding +
				'(taking extreme values between EVER_INUNION_PROP and EVER_INUNION_PROP_HIGH)', g_GENPARAM.listOfParams); {Change in the proportion ever in union}
			g_GENPARAM.RUNTIME[nStepsUnion_Dev] := LongintName.Create(1, 'NSTEP_UNION_STDDEV',
				'Number of steps for standard deviation of age at union' + LineEnding +
				'(taking values between 0.5 and 1.5 time STD_DEV_AGE_UNION)', g_GENPARAM.listOfParams); {For variable union standard deviation if > 1}
			g_GENPARAM.RUNTIME[nStepsAmeno] := LongintName.Create(1, 'NSTEP_AMENORRHEA',
				'Number of steps for amenorrhea, taking values from 0 to the value in AMENO_ALPHA', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[nStepsContrFert] := LongintName.Create(1, 'NSTEP_CONTRACEPTION',
				'Number of steps for contraception within union,' + LineEnding +
				'taking values from 0 to the value of (1-APRIORI_PPR) for each order', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[nStepsSeparation] := LongintName.Create(1, 'NSTEP_SEPARATION',
				'Number of steps for separation, taking values from 0 to the value in SEPARATION', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion] := LongintName.Create(1, 'NSTEP_CONTRACEP_BEFORE_FIRST_CHILD',
				'Number of steps for contraception use in first union before the first birth,' + LineEnding +
				'taking values from 0 to the value in CONTRACEP_TIME_AFTER_FIRST_UNION', g_GENPARAM.listOfParams);

			g_GENPARAM.RUNTIME[cmd_firstCohort] := LongintName.Create(kInitCohort, 'FIRST_COHORT',
				'First birth cohort for KINSHIP', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[cmd_lastCohort] := LongintName.Create(kInitCohort, 'LAST_COHORT',
				'Last birth cohort for KINSHIP', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[cmd_stepCohort] := LongintName.Create(1, 'STEP_COHORT',
				'Number of steps between first and last cohort for KINSHIP', g_GENPARAM.listOfParams);
			g_GENPARAM.RUNTIME[cmd_numberWomen] := LongintName.Create(10000, 'NUMBER_WOMEN',
				'Base number of women for the children and brides-grooms algorithm in the Kinship module', g_GENPARAM.listOfParams);
				
			{=========== Format for outputs_opt ==========}
			g_GENPARAM.outputs_fmt[res_numUnion] := LongintName.Create (5, 'OUTPUT_MAXNUMUNION',
				'Number of unions in individual output file (maximum value of ' + IntToStr (kMaxNbUnion) + ')', g_GENPARAM.listOfParams);
			g_GENPARAM.outputs_fmt[res_numBirths]:= LongintName.Create (15, 'OUTPUT_MAXNUMBIRTHS',
				'Number of births in individual output file (maximum value of ' + IntToStr (kMaxNbChildren) + ')', g_GENPARAM.listOfParams);

			g_GENPARAM.outputs_fmt[res_floatingNumberDigits] := LongintName.Create(3, 'FLOATING_POINT_DIGITS',
				'Number of digits for the fractional part', g_GENPARAM.listOfParams);
			g_GENPARAM.outputs_fmt[res_floatingNumberPrecision] := LongintName.Create(10, 'FLOATING_POINT_PRECISION',
				'Maximum number of digits for real numbers (scientific format used if low value)', g_GENPARAM.listOfParams);
			g_GENPARAM.outputs_fmt[res_fertSurvey_ageMin] := LongintName.Create(15, 'FERT_SURVEY_MIN',
				'Minimum age of women for the fertility survey file', g_GENPARAM.listOfParams);
			g_GENPARAM.outputs_fmt[res_fertSurvey_ageMax] := LongintName.Create(50, 'FERT_SURVEY_MAX',
				'Maximum age of women for the fertility survey file', g_GENPARAM.listOfParams);
			g_GENPARAM.outputs_fmt[res_maxThreads] := LongintName.Create(gNumCoresForMultiThreading, 'MAX_THREADS',
				'Maximum number of threads used by the application' + LineEnding +
				'(the default value is the number of logical threads on this computer)', g_GENPARAM.listOfParams);
		end;
		initRuntimeValues;
	end;

	procedure Settings_in_out ();

	begin
		{============ OUTPUT OPTIONS =============}
		if g_GENPARAM.memoryAllocatedPIN <> kMemoryAllocatedPIN then begin
			//g_FileName should be persistent, so we do not include it in the linked list of parameters to be cleared at the end...
			g_FileName := StringName.Create ('KINFERT', 'FILENAME', 
				'File name root if different from the CONFIG file name (the output files name will start with that root)', nil);
		
			g_FileName_DemographicRegime := StringName.Create ('', 'DEM_REG_FILENAME', 
				'File with values changing for each cohort', g_GENPARAM.listOfParams);
		
			g_FileName_DemographicRegime_save := StringName.Create ('', 'DEM_REG_FILENAME_SAVE', 
				'Save the state of some variables to speed up computation', g_GENPARAM.listOfParams);
		end;

	end;

	procedure initGeneralCmd;
	var
		stdFieldSet: FieldSetType;
		
		procedure initGeneralCmd_values;
		begin
			if g_FileName <> nil then begin
            	g_FileName.value := 'KINFERT';
                g_FileName_DemographicRegime.value := '';
                g_FileName_DemographicRegime_save.value := '';
            end;
			g_GENPARAM.eduKind.value := eduNone;
			g_GENPARAM.kinIndFmt.value := out_EgoGenealogy;
			g_GENPARAM.countryInheritance.value := inher_Spain;

			g_GENPARAM.DUMP.value := TRUE;
			g_GENPARAM.DUMPALL.value := FALSE;
			g_GENPARAM.ZIP_INDIVIDUAL.value := TRUE;
			g_GENPARAM.SAVE_LOG.value := TRUE;
			g_GENPARAM.TALKATIVE.value := FALSE;
			g_GENPARAM.MULTITHREADING.value := TRUE;
			g_GENPARAM.MULTITHREADING_INIT.value := TRUE;
			g_GENPARAM.MULTITHREADING_INITMOTHERHOOD.value := TRUE;
			g_GENPARAM.MULTITHREADING_SIMKIN.value := TRUE;
			g_GENPARAM.FORCE_NUM_THREADS.value := FALSE;
			g_GENPARAM.BATCH.value := FALSE;
			g_GENPARAM.USE_ARRAY_CHILDREN.value := FALSE;
			g_GENPARAM.MODEGO.value := 200;
			g_GENPARAM.OPTIMAL_TREES.value := 200;
			g_GENPARAM.DUMPALLCOHORTS.value := FALSE;
			g_GENPARAM.CREATE_COHORT_FILE.value := FALSE;
			g_GENPARAM.DETAILED_COHORT_DATA.value := FALSE;
			g_GENPARAM.WRITE_ADJUSTED_VALUES.value := TRUE;
			g_GENPARAM.WRITE_FOLDER.value := TRUE;
			g_GENPARAM.WRITE_ONLY_CHANGES.value := TRUE;
			g_GENPARAM.FERTILITY.value := FALSE;
			g_GENPARAM.KINSHIP.value := TRUE;
			g_GENPARAM.SURVIVALPARENTS.value := FALSE;
			g_GENPARAM.FIXED_FERTILITY.value := FALSE;
			g_GENPARAM.FIXED_FERTILITY_VALUE.value := 3;
			g_GENPARAM.STABLE_POPULATION.value := FALSE;
			g_GENPARAM.PPR_TARGET.value := TRUE;
			g_GENPARAM.FORCE_PPR_TARGET.value := FALSE;
			g_GENPARAM.SEP_TARGET.value := TRUE;
			g_GENPARAM.FORCE_SEP_ITER.value := TRUE;
			g_GENPARAM.INIT_RANDOM_NUMBERS.value := TRUE;
			g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value := FALSE;
			g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.value := FALSE;
			g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value := FALSE;
			g_GENPARAM.OUTPUT_INDIVIDUAL_AGE_FLOAT.value := TRUE;
			g_GENPARAM.NON_BIO_KIN.value := FALSE;
			g_GENPARAM.INHERITANCE.value := FALSE;
			g_GENPARAM.PARTNER_FIRST_HEIR.value := FALSE;
			g_GENPARAM.PARTNER_FULL_HEIR.value := FALSE;
			g_GENPARAM.PARTNER_DECEDENT.value := FALSE;
			g_GENPARAM.ALL_EGO_PARTNERS_GENEALOGY.value := FALSE;
			g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY.value := TRUE;
			g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP.value := TRUE;
			g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value := TRUE;
			g_GENPARAM.OUTPUT_EXCLUDE_ABORTION.value := TRUE;
			g_GENPARAM.OUTPUT_FERT_SURVEY.value := FALSE;
			g_GENPARAM.OUTPUT_SHORTFILENAME.value := TRUE;
			g_GENPARAM.CHECK_DATASTRUCT.value := FALSE;
			g_GENPARAM.DEBUG.value := FALSE;
			g_GENPARAM.NEW_INIT_MOTHERHOOD.value := TRUE;

			g_GENPARAM.DOCUMENTATION.value := '';
			
			g_GENPARAM.HEIRS_KINTYPES.value := gPossibleHeirs;
			g_GENPARAM.DECEDENTS_KINTYPES.value := gPossibleDecedents;
			g_GENPARAM.OUTPUT_KINTYPES.value := gStdKinSet;
			g_GENPARAM.OUTPUT_FIELDS.value := stdFieldSet;
			g_GENPARAM.OUTPUT_DIRECTORY.value := '';
		end;
	begin
		stdFieldSet := [fn_yBirth, fn_mBirth, fn_yBirthFloat, fn_yDeathFloat, fn_nChildren, fn_birthOrder, fn_ageRelEgo, fn_ageDeath, fn_ageUnion, fn_ageEndUnion, fn_causeEnd];
		
		//g_GENPARAM.listOfParams := nil;
		
		if g_GENPARAM.memoryAllocatedPIN <> kMemoryAllocatedPIN then begin
			g_GENPARAM.FERTILITY := BooleanName.Create(FALSE, 'FERTILITY', 'Run the fertility model');
			// The first element in the linked list will be whether to run the FERTILITY model
			g_GENPARAM.listOfParams := g_GENPARAM.FERTILITY;
			g_GENPARAM.KINSHIP := BooleanName.Create(TRUE, 'KINSHIP', 'Run the kinship model', g_GENPARAM.listOfParams);
			g_GENPARAM.eduKind := EduStatusName.Create(eduNone, 'EDUCATION',
					'Values can be 0 (none, not taken into account), 1 (totally stochastic), 2 (stochastic but based on observed levels), 3 (idem, but with intrafamily correlation)',
					g_GENPARAM.listOfParams);
			g_GENPARAM.kinIndFmt := KinFileFmtName.Create(out_EgoGenealogy, 'KINSHIP_INDIV_FORMAT',
					'Values can be 0 (Ego genealogy), 1 (DemoCare), 2 (GEDCOM)',
					g_GENPARAM.listOfParams);
			g_GENPARAM.countryInheritance := CountryInheritanceName.Create(inher_Spain, 'COUNTRY_INHERITANCE_RULES',
					'Values can be 0 (Spain), 1 (Other)',
					g_GENPARAM.listOfParams);

			g_GENPARAM.DUMP := BooleanName.Create(FALSE, 'DUMP',
				'Write the main command file you can use as a basis', g_GENPARAM.listOfParams);
			g_GENPARAM.DUMPALL := BooleanName.Create(FALSE, 'DUMPALL',
					'Write a detailed config file, which includes all tables for the fertility model generated by the main input commands',
					g_GENPARAM.listOfParams);
			g_GENPARAM.ZIP_INDIVIDUAL := BooleanName.Create(TRUE, 'ZIP_INDIVIDUAL',
					'Zip the files with individual information',
					g_GENPARAM.listOfParams);
			g_GENPARAM.SAVE_LOG := BooleanName.Create(TRUE, 'SAVE_LOG',
					'Automatically save the output log from the main window',
					g_GENPARAM.listOfParams);
			g_GENPARAM.TALKATIVE := BooleanName.Create(FALSE, 'TALKATIVE',
					'Give lots of feedback when running the Kinship simulation in multithreading (just to let you know that the programme is not dead ;-)',
					g_GENPARAM.listOfParams);
			g_GENPARAM.MULTITHREADING := BooleanName.Create(TRUE, 'MULTITHREADING',
					'Accelerate lengthly computations with parallelism',
					g_GENPARAM.listOfParams);
			g_GENPARAM.MULTITHREADING_INIT := BooleanName.Create(TRUE, 'MULTITHREADING_INIT',
					'Init Demographic Regime',
					g_GENPARAM.listOfParams);
			g_GENPARAM.MULTITHREADING_INITMOTHERHOOD := BooleanName.Create(TRUE, 'MULTITHREADING_INITMOTHERHOOD',
					'Simulate Kinship',
					g_GENPARAM.listOfParams);
			g_GENPARAM.MULTITHREADING_SIMKIN := BooleanName.Create(TRUE, 'MULTITHREADING_SIMKIN',
					'Accelerate lengthly computations with parallelism',
					g_GENPARAM.listOfParams);
			g_GENPARAM.FORCE_NUM_THREADS := BooleanName.Create(FALSE, 'FORCE_NUM_THREADS',
					'Forces the application to use the maximum number of threads specified',
					g_GENPARAM.listOfParams);
			g_GENPARAM.BATCH := BooleanName.Create(FALSE, 'BATCH',
					'Use an EXPERIMENTAL different algorithm for multithreading (multiple batches of threads, some executing while one is saving to disk)',
					g_GENPARAM.listOfParams);
			g_GENPARAM.USE_ARRAY_CHILDREN := BooleanName.Create(TRUE, 'USE_ARRAY_CHILDREN',
					'Internals: optimization of malloc for the children list',
					g_GENPARAM.listOfParams);
			g_GENPARAM.MODEGO := LongintName.Create(200, 'MODEGO',
					'Count step for visualizing ego simulation',
					g_GENPARAM.listOfParams);
			g_GENPARAM.OPTIMAL_TREES := LongintName.Create(1000, 'OPTIMAL_TREES',
					'Number of trees for each thread, when doing multithreading',
					g_GENPARAM.listOfParams);
			g_GENPARAM.DUMPALLCOHORTS := BooleanName.Create(FALSE, 'DUMPALLCOHORTS',
				'Write a file with demographic regime data for all cohorts', g_GENPARAM.listOfParams);
			g_GENPARAM.CREATE_COHORT_FILE := BooleanName.Create(FALSE, 'CREATE_COHORT_FILE',
				'Write a file with cohorts information, useful for the simulation config file (value for DEM_REG_FILENAME)', g_GENPARAM.listOfParams);
			g_GENPARAM.DETAILED_COHORT_DATA := BooleanName.Create(FALSE, 'DETAILED_COHORT_DATA',
				'Write a detailed file for each cohort', g_GENPARAM.listOfParams);
			g_GENPARAM.WRITE_ADJUSTED_VALUES := BooleanName.Create(TRUE, 'WRITE_ADJUSTED_VALUES',
				'Write adjusted fertility and/or separation parameters when TARGET options are selected', g_GENPARAM.listOfParams);
			g_GENPARAM.WRITE_ONLY_CHANGES := BooleanName.Create(TRUE, 'WRITE_ONLY_CHANGES',
				'Write only in the configuration file the parameters which value has changed (is not the default one)', g_GENPARAM.listOfParams);
			g_GENPARAM.WRITE_FOLDER := BooleanName.Create(TRUE, 'WRITE_FOLDER',
				'Write the output files in a folder in the same directory than the CONFIG file', g_GENPARAM.listOfParams);
			g_GENPARAM.SURVIVALPARENTS := BooleanName.Create(FALSE, 'SURVIVALPARENTS',
				'Write tables giving results for the survival of parents at various age of ego', g_GENPARAM.listOfParams);
			g_GENPARAM.FIXED_FERTILITY := BooleanName.Create(FALSE, 'FIXED_FERTILITY',
				'All the women have the exact same fertility (no heterogeneity)', g_GENPARAM.listOfParams);
			g_GENPARAM.FIXED_FERTILITY_VALUE := LongintName.Create(3, 'FIXED_FERTILITY_VALUE',
				'Number of children with fixed fertility', g_GENPARAM.listOfParams);
			g_GENPARAM.STABLE_POPULATION := BooleanName.Create(FALSE, 'STABLE_POPULATION',
				'Each cohort simulated as stable population (fixed Demographic Regime)', g_GENPARAM.listOfParams);
			g_GENPARAM.PPR_TARGET := BooleanName.Create(TRUE, 'PPR_TARGET',
				'PPR values are treated as targets (ON) or *a priori* one (OFF) for all cohorts', g_GENPARAM.listOfParams);
			g_GENPARAM.FORCE_PPR_TARGET := BooleanName.Create(FALSE, 'FORCE_PPR_TARGET',
				'Force PPT TARGET computation, even if we have adjusted values in the configuration file', g_GENPARAM.listOfParams);
			g_GENPARAM.SEP_TARGET := BooleanName.Create(TRUE, 'SEP_TARGET',
				'Separation and second union values are treated as targets (ON) or *a priori* one (OFF) for all cohorts', g_GENPARAM.listOfParams);
			g_GENPARAM.FORCE_SEP_ITER := BooleanName.Create(TRUE, 'FORCE_SEP_ITER',
				'Force separation TARGET computation, even if we have an adjusted value in the configuration file', g_GENPARAM.listOfParams);
			g_GENPARAM.INIT_RANDOM_NUMBERS := BooleanName.Create(TRUE, 'INIT_RANDOM_NUMBERS',
				'If the simulation is NOT multithreaded, whether the sequence of random numbers and the results will be the same for all the runs of this file (TRUE) or different for each run (FALSE)',
				g_GENPARAM.listOfParams);
			g_GENPARAM.DOCUMENTATION := StringName.Create('', 'DOCUMENTATION',
				'A text that document the simulation' + LineEnding +
				'Enter as many lines as you need, separated with RETURNS' + LineEnding +
				'If you write it directly in the config file, the text should end with a line of at least three dash (---)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO := BooleanName.Create(FALSE, 'OUTPUT_INDIVIDUAL_FERTILITY_INFO', 'Write all the individual information for FERTILITY', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED := BooleanName.Create(FALSE, 'OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED', 'Simple (OFF) or extended (ON) individual FERTILITY file', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO := BooleanName.Create(FALSE, 'OUTPUT_INDIVIDUAL_KINSHIP_INFO', 'Write all the individual information for KINSHIP', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_INDIVIDUAL_AGE_FLOAT := BooleanName.Create(TRUE, 'OUTPUT_INDIVIDUAL_AGE_FLOAT', 'Write all ages in individual files as Float (TRUE) or Integer (FALSE)', g_GENPARAM.listOfParams);
			g_GENPARAM.NON_BIO_KIN := BooleanName.Create(FALSE, 'NON_BIO_KIN',
				'Write individual information for all kin' + LineEnding +
				'including non ego''s blood kin', g_GENPARAM.listOfParams);
			g_GENPARAM.INHERITANCE := BooleanName.Create(FALSE, 'INHERITANCE',
				'Look for ego'' heirs,' + LineEnding +
				'or ego''s decedents', g_GENPARAM.listOfParams);
			g_GENPARAM.PARTNER_DECEDENT := BooleanName.Create(FALSE, 'PARTNER_DECEDENT',
				'Ego can inherit from her or his partner,' + LineEnding +
				'therefore we need to simulate the partner''s ancestors', g_GENPARAM.listOfParams);
			g_GENPARAM.ALL_EGO_PARTNERS_GENEALOGY := BooleanName.Create(FALSE, 'ALL_EGO_PARTNERS_GENEALOGY',
				'Simulate genealogy for all ego''s partners' + LineEnding +
				'with the same kin set', g_GENPARAM.listOfParams);
			g_GENPARAM.PARTNER_FIRST_HEIR := BooleanName.Create(FALSE, 'PARTNER_FIRST_HEIR',
				'In some countries the partner inherit fully before the descendants,' + LineEnding +
				'either partly or fully (next parameter takes care of that)', g_GENPARAM.listOfParams);
			g_GENPARAM.PARTNER_FULL_HEIR := BooleanName.Create(FALSE, 'PARTNER_FULL_HEIR',
				'If TRUE, the partner inherits fully before the descendants.' + LineEnding +
				'If FALSE, then partner'' share will be 50%)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY := BooleanName.Create(TRUE, 'OUTPUT_AGGREGATE_FERTILITY', 'Write tables giving results for the fertility model', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP := BooleanName.Create(TRUE, 'OUTPUT_AGGREGATE_KINSHIP', 'Write tables giving results for the kinship at various age of ego', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES := BooleanName.Create(TRUE, 'OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES', 'Bootstrapping uses multiple files (ON/TRUE) or only one file for output (OFF/FALSE)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_EXCLUDE_ABORTION := BooleanName.Create(TRUE, 'OUTPUT_EXCLUDE_ABORTION',
			'Do not write individual information for dead born children or natural abortion (default is ON)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_FERT_SURVEY := BooleanName.Create(FALSE, 'OUTPUT_FERT_SURVEY',
			'Write as a fertility survey, truncating the information for each woman at a random age: the age range can be adjusted below (default is OFF)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_SHORTFILENAME := BooleanName.Create(TRUE, 'OUTPUT_SHORTFILENAME', 'The name of output file is short and does not contain information on the steps (default is ON)', g_GENPARAM.listOfParams);
			g_GENPARAM.CHECK_DATASTRUCT := BooleanName.Create(FALSE, 'CHECK_DATASTRUCT', 'Thoroughly check internal data structures, especially for KINSHIP', g_GENPARAM.listOfParams);
			g_GENPARAM.DEBUG := BooleanName.Create(FALSE, 'DEBUG', 'Debug mode', g_GENPARAM.listOfParams);
			g_GENPARAM.NEW_INIT_MOTHERHOOD := BooleanName.Create(TRUE, 'NEW_INIT_MOTHERHOOD',
			'New algo for mothers and brides mode: for stable populations, we separate the generation of mothers and brides', g_GENPARAM.listOfParams);

			g_GENPARAM.HEIRS_KINTYPES := KinListName.Create(gPossibleHeirs, 'HEIRS_KINTYPES', 'Set of kin who can be ego''s heirs', g_GENPARAM.listOfParams);
			g_GENPARAM.DECEDENTS_KINTYPES := KinListName.Create(gPossibleDecedents, 'DECEDENTS_KINTYPES', 'Set of kin who can be ego''s decedents', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_KINTYPES := KinListName.Create(gStdKinSet, 'OUTPUT_KINTYPES', 'Kin types written in individual file (apply only to Genealogy files)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_FIELDS := FieldListName.Create(stdFieldSet, 'OUTPUT_FIELDS', 'Optional fields in individual file (apply only to Genealogy files)', g_GENPARAM.listOfParams);
			g_GENPARAM.OUTPUT_DIRECTORY := StringName.Create('', 'OUTPUT_DIRECTORY', 'The complete path for output files', g_GENPARAM.listOfParams);
		end;
		Settings_in_out ();

		initGeneralCmd_values;
		
		initRuntime();
		
		initialSetFixedParameters;
		initResultats;
		
		g_GENPARAM.memoryAllocatedPIN := kMemoryAllocatedPIN;
				
	end;

	procedure publishResult (res: outputKind_boolean; state: boolean; name: string = ''; comment: string = '');
	begin
		// We check we are not doing this two times with kMemoryAllocatedPIN
		if g_GENPARAM.memoryAllocatedPIN <> kMemoryAllocatedPIN then
			g_GENPARAM.outputs_opt [res] := BooleanName.Create (state, name, comment, g_GENPARAM.listOfParams)
		else
			g_GENPARAM.outputs_opt [res].value := state;
	end;
		
	procedure initResultats;
	begin
		publishResult (res_fert_GenFert, true, 'GENERAL_FERTILITY');
		publishResult (res_fert_intervals, false, 'INTERVAL_TABLE');
		publishResult (res_fert_intervals_conceptions, true, 'INTERVAL_CONCEPTION_UNION_TABLE');
		publishResult (res_fert_LastChild, false, 'LAST_BIRTH');
		publishResult (res_fert_durationPreviousEvent, true, 'DURATION_TABLE');
		publishResult (res_fert_FinalParity_parity_age, false, 'PARITY_AGE_TABLE');
		publishResult (res_fert_repartneringStatesType, false, 'REPARTNERING_STATE_TABLE', 'Can be TRUE only if separation and repartnering risks are non zero. Will be FALSE if not');
		{publishResult (res_destinyUnion, false, 'UNION_STATE_TABLE');}
		publishResult (res_fert_CTFR, true, 'COHORT_TFR');
		publishResult (res_fert_AgeChildbearing, true, 'AGE_CHILDBEARING');
		publishResult (res_fert_TotFert, false, 'COHORT_FERTILITY_TABLE');
		publishResult (res_fert_prop_single, true, 'PROP_CELIBACY');
		publishResult (res_fert_no_fecundation, false, 'NO_FECUNDATION');
		publishResult (res_fert_dump_UnionTable, false, 'DUMP_UNION_TABLE');
		publishResult (res_fert_dump_UnionStates, false, 'INUNION_STATE_TABLE');
		publishResult (res_fert_fertility_durationUnion, false, 'FERTILITY_BY_UNION_DURATION');
		publishResult (res_fert_fertility_unionStatus, true, 'FERTILITY_BY_UNION_STATUS');
		publishResult (res_fert_PPRs, true, 'PPRS_BY_UNION_STATUS');
		publishResult (res_fert_ageFirstUnion, true, 'PARITY_BY_AGE_AT_UNION');
		publishResult (res_kin_stats, true, 'KIN_STATISTICS');
		publishResult (res_kin_fathers_son, false, 'KIN_FATHERS_SONS');
		publishResult (res_kin_dist, false, 'KIN_DISTRIBUTION');
		publishResult (res_kin_reldist, true, 'KIN_RELATIVE_DISTRIBUTION');
		publishResult (res_kin_agedist, false, 'KIN_AGE_DISTRIBUTION');
		publishResult (res_kin_numByAge, false, 'NUM_KIN_AGE');
		publishResult (res_kin_unionTable, true, 'UNION_TABLE');
		publishResult (res_kin_totalNumbers, true, 'KIN_TOTAL_NUMBERS');
		publishResult (cmd_outputtomainfile, true, 'OUTPUT_MAIN_FILE', 'Aggregate results for Fertility model are written in only one file');
	end;
	
	procedure initFixedFertility (TFR: longint);
	begin
		case TFR of
			1: with g_FIXED_FERTILITY_DATA do begin
				ageUnionWoman := 25;
				ageEndUnionWoman := kNotDefined;
				ageUnionMan := 27;
				nbChildren := 1;
				setLength (ageFert, nbChildren);
				ageFert[0] := trunc (ageUnionWoman) + 1.5;
			end;
			2: with g_FIXED_FERTILITY_DATA do begin
				ageUnionWoman := 25;
				ageEndUnionWoman := kNotDefined;
				ageUnionMan := 27;
				nbChildren := 2;
				setLength (ageFert, nbChildren);
				ageFert[0] := trunc (ageUnionWoman) + 1.5;
				ageFert[1] := 39.5;
			end;
			3: with g_FIXED_FERTILITY_DATA do begin
				ageUnionWoman := 25;
				ageEndUnionWoman := kNotDefined;
				ageUnionMan := 27;
				nbChildren := 3;
				setLength (ageFert, nbChildren);
				ageFert[0] := trunc (ageUnionWoman) + 1.5;
				ageFert[1] := ageFert[0] + 3;
				ageFert[2] := 39.5;
			end;
			4: with g_FIXED_FERTILITY_DATA do begin
				ageUnionWoman := 25;
				ageEndUnionWoman := kNotDefined;
				ageUnionMan := 27;
				nbChildren := 4;
				setLength (ageFert, nbChildren);
				ageFert[0] := trunc (ageUnionWoman) + 1.5;
				ageFert[1] := ageFert[0] + 3;
				ageFert[2] := ageFert[1] + 3;
				ageFert[3] := 39.5;
			end;
		end;
	end;
	
	procedure initGeneral;
	var
		i, j: longint;
		ageAtUnion: ageQuinq;
		
	begin
		{$IFDEF darwin}
		gMac := True;
		{$ELSE}
		gMac := False;
		{$ENDIF}
		gFormatSettings := DefaultFormatSettings;
		gFormatSettings.DecimalSeparator := '.';
		initRandomNumbers;
		gNumCoresForMultiThreading := TNumCPULib.GetPhysicalCPUCount();
		gNumLogicalThreadsForMultiThreading := TNumCPULib.GetLogicalCPUCount();
		gMaxThreads := max(2, gNumCoresForMultiThreading);

		if (not memoryAllocated) then
			initMemory;

		initEcran;

{		for ageAtUnion := f1519 to f5559 do
			for i := 0 to kMaxNbChildren do
				for j := 1 to kMax_param_TotalFertAgeUnion do
					gTOT_descFinaleAgeUnion[ageAtUnion, i, j] := 0;
}

		{initStandardRepartnering;}
		
		initFertilityModel;

		//memoWriteLn(['init ended']);
	end;

	function initParams(randomGenerator: TRandomNumberGenerator): boolean;
	label error;
    var
        ind: longint;
		// Measure execution time
		tStart: TDateTime;  // Begin and end of measurement, and difference

	begin
		tStart := Now();
		g_GENPARAM.CHECK_DATASTRUCT.value := g_GENPARAM.DEBUG.value;
		for ind := 1 to 100 do
			gBlanks := gBlanks + ' ';
		initParams := false;
		if not initDebugFile() then goto error;
		if g_GENPARAM.FIXED_FERTILITY.value then
			initFixedFertility (g_GENPARAM.FIXED_FERTILITY_VALUE.value);
		initFixedParameters();
		DemRegimeCollection_init(randomGenerator);
		initParams := true;
		
		stopTime (tStart, '===== General init phase lasted: ');
	error:
	end;

	procedure closeAll;
	begin
		stopRandomNumbers;
		if (memoryAllocated) then
			releaseMemory;
	end;

end.
