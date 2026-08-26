{$I Defines.pas}
unit DemographicRegime;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
    Classes,
	Declarations, Fertility, Mortality, Nuptiality, Utilities, RandomNumbers, StrUtils, SysUtils, Math, Memory;

	procedure DemRegimeCollection_create ();
	procedure DemRegimeCollection_destroy ();
	procedure DemRegimeCollection_init (randomGenerator: TRandomNumberGenerator);
	procedure DemRegimeCollection_initAdjustedValues;
	procedure DemRegimeCollection_saveAdjustedValues;
	function DemRegimeCollection_adjustedValuesSaved: boolean;
	function DemRegimeCollection_VariousCohorts: boolean;
	function DemRegimeCollection_nCohorts: longint;
	function DemRegimeCollection_firstCohort: longint;
	function DemRegimeCollection_lastCohort: longint;
	function DemRegimeCollection_first: pStructDemographicRegimeSettings;
	function DemRegimeCollection_last: pStructDemographicRegimeSettings;
	function DemRegimeCollection_readData (fileName: string): boolean;
	procedure DemRegimeCollection_adjustData ();
	procedure DemRegimeCollection_writeData (cohorts: boolean; fileNameWithPath: string = ''; removeOptional: boolean = true);
	procedure DemRegimeCollection_writeAdjustedValues;
	procedure DemRegimeCollection_SetChangedDefaultValues;
	function DemRegimeCollection_CheckChangedDefaultValues (): boolean;
	function DemographicRegimeSettings_create (): pStructDemographicRegimeSettings;
	procedure DemographicRegimeSettings_destroy (var p: pStructDemographicRegimeSettings);
	procedure DemographicRegimeSettings_copyState (pIn, pOut: pStructDemographicRegimeSettings);
	procedure DemographicRegimeSettings_initOne (
									randomGenerator: TRandomNumberGenerator;
									p: pStructDemographicRegimeSettings;
									cohortInit: longint;
									readState: boolean = false);
	procedure DemographicRegimeSettings_writeDetailedData (p: pStructDemographicRegimeSettings; indStr: string = '');
	procedure DemRegimeCollection_yearsReadInConfig (out a: arrayOfLongint);
	
	function computeTFRfromPPRs(PPRs: ArrayOfDoubleName): double;
	function StablePopulation: boolean;
	function getCohort_p(year: longint): pStructDemographicRegimeSettings;
    procedure DemographicRegimeSettings_initFec (randomGenerator: TRandomNumberGenerator;
    											p: pStructDemographicRegimeSettings;						
    											readState: boolean = false;
    											indThread: longint = kNotDefined);

implementation

uses
	Init, EducationalLevel, FertilityRuntime, Kinship;

	const
		maxValuePos = 200;


	type
		threadStates = (thread_suspended, thread_active, thread_dead);
		TDemRegInitThread = class(TThread)
		public
			myDemReg: pStructDemographicRegimeSettings;
			myRandomGenerator: TRandomNumberGenerator;		
			myThreadSlotUsed: longint;
            myThreadState: threadStates;
			Constructor Create(CreateSuspended : boolean; pDemReg: pStructDemographicRegimeSettings); overload;
			Destructor Destroy; override;
			procedure Execute; override;
		end;

		posValueType = (pfk_double, pfk_longint, ppr, ppr_adjusted, effStopping, effSpacing, meanWaitingTimeSpacing, eduOwn, eduPartner, eduChildren);
		posValueRec = record
			pv: posValueType;
			posTable: longint;
		end;

 	Constructor TDemRegInitThread.Create(CreateSuspended : boolean; pDemReg: pStructDemographicRegimeSettings);
	begin
		inherited Create (CreateSuspended);
		myDemReg := pDemReg;
		myThreadSlotUsed := 0;
        myThreadState := thread_suspended;
		myRandomGenerator := TRandomNumberGenerator.Create (false);
	end;

	Destructor TDemRegInitThread.Destroy();
	begin
		myRandomGenerator.Destroy();
	end;
	
	procedure TDemRegInitThread.Execute;
	var
		ran: double;
	begin
		myThreadState := thread_active;
		myRandomGenerator.initRandomized();
		ran := myRandomGenerator.alea0;
		if (g_GENPARAM.TALKATIVE.value) then
        	memoWriteLn (['TDemRegInitThread.Execute first random number: ', ran]);

		DemographicRegimeSettings_initFec (myRandomGenerator, myDemReg, false, myThreadSlotUsed);
		if (g_GENPARAM.TALKATIVE.value) then
        	memoWriteLn (['TDemRegInitThread.Execute finished: ', myDemReg^.yearOfBirth.value]);
		self.Terminate;
	end;
		
	procedure DemographicRegimeSettings_initialState (var p: pStructDemographicRegimeSettings);
	// Default values
	var
		ind: longint;
		CTFR: double;
		
	begin
		p^.readInConfig := TRUE;
		p^.listOfParams := nil;
		
		{=========== COHORT ===========}
		p^.yearOfBirth := LongintName.Create (kInitCohort, 'YEAR_OF_BIRTH', 'Year of birth of the cohort of egos');
		p^.listOfParams := p^.yearOfBirth;
		p^.r := 0.0;

		p^.lp[nWomenPar] := LongintName.Create(10000, 'NWOMEN', 'Number of women for the fertility model', p^.listOfParams);
		p^.lp[nWomenPar].optional := true;
		p^.lp[nEgoPar] := LongintName.Create(10000, 'NEGO', 'Number of persons for the kinship model (proportional to the number of births in the population)', p^.listOfParams);
				
		{============ MORTALITY =============}
		p^.dp[e0_women] := DoubleName.Create (80, 'LIFE_EXPECTANCY_AT_BIRTH_WOMEN', 'Selecting a West Life Table model for women', p^.listOfParams);
		p^.dp[e0_men] := DoubleName.Create (76.647, 'LIFE_EXPECTANCY_AT_BIRTH_MEN', 'Selecting a West Life Table model for men', p^.listOfParams);
		
		{========= SEX RATIO AT BIRTH ======}
		p^.dp[propWomenAtBirth] := DoubleName.Create (0.488, 'PROP_WOMEN_AT_BIRTH', 'Sex ratio at birth: proportion of women', p^.listOfParams);

		{============ CELIBACY =============}
		{======== Beware: we put here the proportion ever in union}
		p^.dp[propFinalCelibacyLow] := DoubleName.Create (0.95, 'EVER_INUNION_PROP',
			'Proportion of women who ever enter a union.' + LineEnding +
				'This is the minimum when there is a range of values', p^.listOfParams);
		p^.dp[propFinalCelibacyHigh] := DoubleName.Create (0.95, 'EVER_INUNION_PROP_HIGH',
			'If NSTEP_UNION_PROP is more than 1,' + LineEnding +
				'the high values of final celibacy is taken into account', p^.listOfParams);
		p^.dp[propFinalCelibacyHigh].optional := true;
		p^.dp[propFinalCelibacyMen] := DoubleName.Create (0.95, 'EVER_INUNION_PROP_MEN',
			'Proportion of men who ever enter a union', p^.listOfParams);
		
		{============ INTERVAL OF CONTRACEPTION USE AFTER UNION (GIVE SEPARATION SOME TIME!)  =============}
		p^.dp[meanTimeContraceptionAfterUnionHigh] := DoubleName.Create (0, 'CONTRACEP_TIME_AFTER_FIRST_UNION',
			'Length in year of contraception use in first union (spacing)' + LineEnding +
				'before the start of reproductive period for couples who use contraceptive means.' + LineEnding +
				'A value between 0 and 8 (internal table limited to 10 years)', p^.listOfParams);
		p^.dp[propContraceptionAfterUnion] := DoubleName.Create (0, 'PROP_CONTRACEP_AFTER_FIRST_UNION',
			'Proportion of couples who use contraceptive means (for spacing) ' + LineEnding +
				'at the start of first union', p^.listOfParams);
		
		{Contraception effectiveness}
		p^.dp[effContBeforeUnion] := DoubleName.Create (1.0, 'EFF_CONTRACEP_BEFORE_UNION',
			'Effectiveness of contraception before first union (not implemented at the moment)', p^.listOfParams);
		p^.effStopping := ArrayOfDoubleName.Create(kNumDifferentsBirthIntervals, 'EFF_STOPPING_CONTRACEP',
		'A value between 0 and 1 (both included).' + LineEnding +
				'0 means no contraception use and 1 use of perfect contraception means.' + LineEnding +
				'First value for childless woman, second and following for the rest.', p^.listOfParams);

		p^.effSpacing := ArrayOfDoubleName.Create(kNumDifferentsBirthIntervals, 'PROP_USING_SPACING',
		'A value between 0 and 1 (both included).' + LineEnding +
				'0 means nobody use contraception for spacing and 1 everybody does it.' + LineEnding +
				'First value for childless woman, second and following for the rest.', p^.listOfParams);

		p^.meanTimeSpacing := ArrayOfDoubleName.Create(kNumDifferentsBirthIntervals, 'WAITING_TIME_SPACING',
		'Values in years for the mean waiting time' + LineEnding +
				'of the contraception by spacing within union,' + LineEnding +
				'for the first birth and the following ones.' + LineEnding +
				'A value between 0 and 8 (both included).', p^.listOfParams);

		for ind := 0 to kMaxIndBirthIntervals do begin
			p^.effStopping.value [ind] := 1.0;
			p^.effSpacing.value [ind] := 0.0;
			p^.meanTimeSpacing.value [ind] := 0.0;
		end;
		// The values just entered will be the default one
		p^.effStopping.setDefault;
		p^.effSpacing.setDefault;
		p^.meanTimeSpacing.setDefault;

		{============ A PRIORI PARITY PROGRESSION RATIOS  =============}
		p^.aPrioriPPR := ArrayOfDoubleName.Create(kMaxNbChildren+1, 'APRIORI_PPR', 'PPR for women in union.' + LineEnding +
				'For each parity a value between 0 and 1 (both included).', p^.listOfParams);
		p^.aPrioriPPR.value[0] := 0.90;
		p^.aPrioriPPR.value[1] := 0.85;
		p^.aPrioriPPR.value[2] := 0.45;
		p^.aPrioriPPR.value[3] := 0.35;
		p^.aPrioriPPR.value[4] := 0.35;
		p^.aPrioriPPR.value[5] := 0.35;

		for ind := 6 to kMaxNbChildren do
			p^.aPrioriPPR.value[ind] := p^.aPrioriPPR.value[ind-1];
		
		// The values just entered will be the default one
		p^.aPrioriPPR.setDefault();
		
		CTFR := computeTFRfromPPRs (p^.aPrioriPPR);
		p^.CTFR := DoubleName.Create (CTFR, 'CTFR_READONLY',
			'Level of union fertility corresponding to PPRs value (computed)', p^.listOfParams);
		
		{============ ADJUSTED PARITY PROGRESSION RATIOS  =============}
		p^.aPrioriPPR_adjusted := ArrayOfDoubleName.Create(kMaxNbChildren+1, 'ADJUSTED_PPR', 'ADJUSTED PPR for women in union.' + LineEnding +
				'For each parity a value between 0 and 1 (both included).', p^.listOfParams);

		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR_adjusted.value[ind] := 0;
		
		// The values just entered will be the default one
		p^.aPrioriPPR_adjusted.setDefault();
		
		CTFR := computeTFRfromPPRs (p^.aPrioriPPR_adjusted);
		p^.CTFR_adjusted := DoubleName.Create (CTFR, 'CTFR_ADJUSTED',
			'Level of union fertility corresponding to adjusted PPRs value (computed)', p^.listOfParams);

		{============ RESULT PARITY PROGRESSION RATIOS  =============}
		p^.aPrioriPPR_result := ArrayOfDoubleName.Create(kMaxNbChildren+1, '', '', nil);

		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR_result.value[ind] := 0;
		
		{============ REPARTNERING =============}
		{<======== Useful for kinship model}
		p^.dp[repartnering_men_par] := DoubleName.Create (0.0, 'REPARTNERING_MEN',
			'Likelihood of separated men entering into a subsequent union (between 0 and 1)', p^.listOfParams);
		{<======== Useful for both kinship and fertility model}
		p^.dp[repartnering_women_par] := DoubleName.Create (0.0, 'REPARTNERING_WOMEN',
			'Likelihood of separated women entering into a subsequent union (between 0 and 1)', p^.listOfParams);
		p^.dp[repartnering_wid_men_par] := DoubleName.Create (0.0, 'REPARTNERING_WIDOWHOOD_MEN',
			'Likelihood of widowers entering into a subsequent union (between 0 and 1)', p^.listOfParams);
		{<======== Useful for both kinship and fertility model}
		p^.dp[repartnering_wid_women_par] := DoubleName.Create (0.0, 'REPARTNERING_WIDOWHOOD_WOMEN',
			'Likelihood of widows entering into a subsequent union (between 0 and 1)', p^.listOfParams);

		{============ SEPARATION =============}
		p^.dp[freqSeparation] := DoubleName.Create (0.0, 'SEPARATION',
			'Proportion separating (from 0 to 1)', p^.listOfParams);
		p^.dp[rel_risk_2Separation] := DoubleName.Create (2, 'SECOND_SEPARATION_REL_RISK',
			'Relative risk of a new separation for a person who already separated', p^.listOfParams);
		p^.dp[freqSeparationFirstIteration] := DoubleName.Create (0, 'SEPARATION_ADJUSTED',
			'First value of separation in the iterative process of finding the adjusted value', p^.listOfParams);
		p^.dp[freqSeparationFirstIteration].optional := true;

		{============ PARAMETERS FOR THE DISTRIBUTION OF AGES AT UNION =============}
		p^.dp[meanAgeUnionWomenLow] := DoubleName.Create (25, 'MEAN_AGE_UNION',
			'Mean age at first union of women.' + LineEnding +
				'This is also the minimum when there is a range of values', p^.listOfParams);
		p^.dp[meanAgeUnionWomenHigh] := DoubleName.Create (25, 'MEAN_AGE_UNION_HIGH',
			'If NSTEP_UNION_MEAN is more than 1, the high values is taken into account', p^.listOfParams);
		p^.dp[meanAgeUnionWomenHigh].optional := true;
		p^.dp[meanAgeUnionMen] := DoubleName.Create (27, 'MEAN_AGE_UNION_MEN',
			'Mean age at first union of men.' + LineEnding +
				'When the age at first union of women varies, we maintain the difference', p^.listOfParams);
		// a negative number means we compute the value internally, based on the value of MEAN_AGE_UNION
		p^.dp[stdnupt] := DoubleName.Create (kNotDefined, 'STD_DEV_AGE_UNION',
			'Makes sense to set it only when NSTEP_UNION_MEAN > 1 and NSTEP_UNION_STDDEV = 1.' + LineEnding +
				'When a value of -1 is entered, it is computed internally, varying with MEAN_AGE_UNION.' + LineEnding +
				'Zero is not a good idea. See the option FIXED_AGE_UNION instead.', p^.listOfParams);

		{============ AMENORRHEA PP =============}
		// Default values chosen give a median exactly at 5 months
		p^.dp[amenorrhea_alpha] := DoubleName.Create (-1.18174164, 'AMENO_ALPHA',
			'Value of alpha parameter in Lesthaeghe-Page model', p^.listOfParams);
		p^.dp[amenorrhea_beta] := DoubleName.Create (1.0, 'AMENO_BETA',
			'Value of beta parameter in Lesthaeghe-Page model', p^.listOfParams);

		initEduStatus (p);
		
		p^.adjusted.aPrioriPPR := ArrayOfDoubleName.Create(kMaxNbChildren+1, '', '', nil);
		p^.adjusted.separation_proportion := 0;

	end;
	
	procedure DemographicRegimeSettings_initAdjustedValues (p: pStructDemographicRegimeSettings);
	var
		ind: longint;
	begin
		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR_adjusted.value[ind] := p^.adjusted.aPrioriPPR.value[ind];
		
		// The values just entered will be the default one
		p^.aPrioriPPR_adjusted.setDefault();
		
		p^.CTFR_adjusted.value := 0;

		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR_result.value[ind] := 0;
		
		p^.dp[freqSeparationFirstIteration].value := p^.adjusted.separation_proportion;
	end;
	
	procedure DemographicRegimeSettings_saveAdjustedValues (p: pStructDemographicRegimeSettings);
	var
		ind: longint;
	begin
		for ind := 0 to kMaxNbChildren do
			p^.adjusted.aPrioriPPR.value[ind] := p^.aPrioriPPR_adjusted.value[ind];
				
		p^.adjusted.separation_proportion := p^.dp[freqSeparationFirstIteration].value;
	end;

	function DemographicRegimeSettings_adjustedValuesSaved (p: pStructDemographicRegimeSettings): boolean;
	begin
		result := (p^.adjusted.aPrioriPPR.value[0] <> p^.aPrioriPPR_adjusted.value[0]) or
		(p^.adjusted.separation_proportion <> p^.dp[freqSeparationFirstIteration].value);
	end;
	
	procedure DemographicRegimeSettings_SetChangedDefaultValues (p: pStructDemographicRegimeSettings);
	// Traverse the linked list of parameters and set the 'changed' state to its correct value
	var
		listOfParams_temp: GenericName;
	begin
		listOfParams_temp := p^.listOfParams;
		while listOfParams_temp <> nil do begin
			listOfParams_temp.setChanged;
			listOfParams_temp := listOfParams_temp.next;
		end;
	end;
	
	function DemographicRegimeSettings_CheckChangedDefaultValues (p: pStructDemographicRegimeSettings): boolean;
	begin
		result := myCheckChangedDefaultValues (p^.listOfParams);
	end;

	procedure DemographicRegimeSettings_copyState (pIn, pOut: pStructDemographicRegimeSettings);
	// Copy main parameters of a demographic regime (will still need to recreate the rest afterward with init procedure)
	var
		ind: longint;
		pfd: paramDemReg_double;
		pfl: paramDemReg_longint;
		edLevel1, edLevel2, edLevel3: EduLevels;
		aSex: Sex;
	begin
		pIn^.yearOfBirth.copyMeTo (pOut^.yearOfBirth);
		for pfd := low(paramDemReg_double) to high(paramDemReg_double) do begin
			pIn^.dp[pfd].copyMeTo (pOut^.dp[pfd]);
		end;

		for pfl := low(paramDemReg_longint) to high(paramDemReg_longint) do begin
			pIn^.lp[pfl].copyMeTo (pOut^.lp[pfl]);
		end;

		pIn^.effStopping.copyMeTo (pOut^.effStopping);
		pIn^.effSpacing.copyMeTo (pOut^.effSpacing);
		pIn^.meanTimeSpacing.copyMeTo (pOut^.meanTimeSpacing);
		for ind := 0 to kMaxIndBirthIntervals do begin
			pOut^.effStopping.value [ind] := pIn^.effStopping.value [ind];
			pOut^.effSpacing.value [ind] := pIn^.effSpacing.value [ind];
			pOut^.meanTimeSpacing.value [ind] := pIn^.meanTimeSpacing.value [ind];
		end;
	
		pIn^.aPrioriPPR.copyMeTo (pOut^.aPrioriPPR);
		for ind := 0 to kMaxNbChildren do
			pOut^.aPrioriPPR.value[ind] := pIn^.aPrioriPPR.value[ind];
		
		for edLevel1 := low (EduLevels) to high (EduLevels) do begin
			for aSex := low(Sex) to high(Sex) do
				pIn^.eduEgo [edLevel1, aSex].copyMeTo (pOut^.eduEgo [edLevel1, aSex]);
			for edLevel2 := low (EduLevels) to high (EduLevels) do begin
				for aSex := low(Sex) to high(Sex) do
					pIn^.eduEgoPartner [edLevel1, aSex, edLevel2].copyMeTo (pOut^.eduEgoPartner [edLevel1, aSex, edLevel2]);
				for edLevel3 := low (EduLevels) to high (EduLevels) do begin
					pIn^.eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3].copyMeTo (pOut^.eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3]);
				end;
			end;
		end;
	end;

	function DemographicRegimeSettings_create (): pStructDemographicRegimeSettings;
	var
		p : pStructDemographicRegimeSettings;
		ind: longint;
		
	begin
		new(p);
		newPtr (ptr (p), 'pStructDemographicRegimeSettings');
		
		p^.mortalityInfo.survival_men := SetLengthDoubleZero (kMaxAgeLife+1);
		p^.mortalityInfo.survival_women := SetLengthDoubleZero (kMaxAgeLife+1);
		
		newNuptialitySettings (p^.nuptialityInfo);
		p^.pCurrUnionInfo := @p^.nuptialityInfo;

		p^.separationInfo.monthly_risk_separation := SetLengthDoubleZero (kMaxDurationUnionInMonths+1);
		
		p^.temporary_sterility := SetLengthDoubleZero (kMaxMonthTemporarySterility+1);

		{Set initial values, before reading file}
		p^.AccDurationContrAfterUnion := SetLengthDoubleZero (kMaxDurationContraceptionUnionInMonths+1);
		init_waiting_time_distribution (kMaxDurationContraceptionUnionInMonths, p^.AccDurationContrAfterUnion, 0.0, 0.0);

		for ind := 0 to kMaxIndBirthIntervals do begin
			p^.AccDurationWaitingTime[ind] := SetLengthDoubleZero (kMaxDurationContraceptionInBirthIntervals+1);
			init_waiting_time_distribution (kMaxDurationContraceptionInBirthIntervals, p^.AccDurationWaitingTime[ind], 0.0, 0.0);
		end;	
		
		new(p^.distribStableFert);
		newPtr (ptr(p^.distribStableFert), 'distribStableFert');
		p^.adjustedValues := false;
		p^.readInConfig := true;
		p^.toBeInterpolated := false;
		p^.interpolate_from := 0;
		p^.interpolate_until := 0;

{		setLength (p^.distNbChildren[allStates50], kMaxNbChildren+1);
		setLength (p^.distNbChildren[alive50EverInUnion], kMaxNbChildren+1);
		setLength (p^.distNbChildren[aliveWithFirstPartner50], kMaxNbChildren+1);
}		
		DemographicRegimeSettings_initialState (p);
		DemographicRegimeSettings_create := p;
	end;

	function DemographicRegimeSettings_readState (p: pStructDemographicRegimeSettings; f: TFileType): boolean; // Obsolete or to be reimplemented in a future version
	var
		aLine: ansistring;
		s: string;
		res: longint;
		resd: double;
		code: word;
		af: FecundAges;
		n: longint;
		ind, len: longint;
	begin
		readLn (f.fileHandle, aLine);
		val (aLine, res, code);
		if not checkCode (aLine, code ) then begin
			DemographicRegimeSettings_readState := false;
			exit;
		end;
		if p^.yearOfBirth.value <> res then begin
			DemographicRegimeSettings_readState := false;
			exit;
		end;
		readLn (f.fileHandle, aLine);		
		val (aLine, resd, code);
		if not checkCode (aLine, code ) then begin
			DemographicRegimeSettings_readState := false;
			exit;
		end;
		p^.r := resd;
		n := 1;
		readLn (f.fileHandle, aLine);		
		for af := kMinAgeFert to kMaxAgeFert do begin
			s := ExtractWord (n, aLine, tabSet);
			val (s, resd, code);
			if not checkCode (aLine, code ) then begin
				DemographicRegimeSettings_readState := false;
				exit;
			end;
			p^.distribStableFert^ [af] := resd;
			Inc ( n );
		end;
		len := length (p^.aPrioriPPR_adjusted.value) - 1;
		for ind := 0 to len do begin
			readln(f.fileHandle, p^.aPrioriPPR_adjusted.value[ind]);
		end;
		p^.adjustedValues := true;
		DemographicRegimeSettings_readState := true;
	end;

	procedure DemographicRegimeSettings_initMain (p: pStructDemographicRegimeSettings; cohortInit: longint);
	// Computing state variables depending on input values 1
	var
		ind: longint;
	begin
		if (cohortInit > 0) then
			p^.yearOfBirth.value := cohortInit;

		p^.r := 0;
		
		mortality_level (p, p^.dp[e0_women].value, p^.dp[e0_men].value);

		initStandardNuptiality (p, p^.nuptialityInfo);

		calcRepartnering (p^.dp[repartnering_women_par].value, p^.dp[repartnering_men_par].value,
			p^.pCurrUnionInfo^.prop_repartnering, p^.pCurrUnionInfo^.prop_not_repartnering);  {Female and male repartnering after separation}
		calcRepartnering (p^.dp[repartnering_wid_women_par].value, p^.dp[repartnering_wid_men_par].value,
			p^.pCurrUnionInfo^.prop_repartnering_widowhood, p^.pCurrUnionInfo^.prop_not_repartnering_widowhood);  {Female and male repartnering after widowhood}
		calcRepartnering_duration (p^.dp[repartnering_women_par].value, p^.dp[repartnering_men_par].value,
			kMean_repartneringAfterSeparation_women, kMean_repartneringAfterSeparation_men,
			p^.pCurrUnionInfo^.prop_repartnering_duration);  {Female and male repartnering after separation *duration based*}
		calcRepartnering_duration (p^.dp[repartnering_wid_women_par].value, p^.dp[repartnering_wid_men_par].value,
			kMean_repartneringAfterWidowhood_women, kMean_repartneringAfterWidowhood_men,
			p^.pCurrUnionInfo^.prop_repartnering_widowhood_duration);  {Female and male repartnering after widowhood *duration based*}

		if (p^.dp[repartnering_men_par].value <= 0.0) and (p^.dp[repartnering_women_par].value <= 0.0) then
			publishResult (res_fert_repartneringStatesType, false);

		initStandardSeparation (p);
		p^.separationInfo.freqSeparation := p^.dp[freqSeparation].value;
		calcSeparation (p^.separationInfo.freqSeparation, p^.separationInfo); {Separation}
		
		p^.MeanTimeContraceptionAfterUnion := p^.dp[meanTimeContraceptionAfterUnionHigh].value;
		p^.propContraceptionAfterUnion_var := p^.dp[propContraceptionAfterUnion].value;
		
		init_waiting_time_distribution (kMaxDurationContraceptionUnionInMonths,
										p^.AccDurationContrAfterUnion,
										p^.MeanTimeContraceptionAfterUnion,
										p^.propContraceptionAfterUnion_var);
		
		for ind := 0 to kMaxIndBirthIntervals do begin
			init_waiting_time_distribution (kMaxDurationContraceptionInBirthIntervals,
											p^.AccDurationWaitingTime[ind],
											p^.meanTimeSpacing.value[ind],
											p^.effSpacing.value[ind]);
		end;

		noStoppingContraception (p);

		init_temporary_sterility (p, p^.dp[amenorrhea_alpha].value, p^.dp[amenorrhea_beta].value);

		if p^.aPrioriPPR_adjusted.value[0] = 0 then begin
			for ind := 0 to kMaxNbChildren do
				p^.aPrioriPPR_adjusted.value[ind] := p^.aPrioriPPR.value[ind];
			p^.adjustedValues := false;
		end else begin
			p^.adjustedValues := true;
		end;
	end;

	procedure DemographicRegimeSettings_initFec (randomGenerator: TRandomNumberGenerator;							
												p: pStructDemographicRegimeSettings;
												readState: boolean = false;
												indThread: longint = kNotDefined);
	// Computing state variables depending on input values 2
	var
		idWoman: longint;
		ind: longint;
		objUnionTable: TUnionTable;
		arrayChildren: arrayOfInfoChild;

	begin
		idWoman := 0;
		CreateArrayChildren(arrayChildren{%H-});
		objUnionTable := TUnionTable.Create();
		objUnionTable.Init();
		if indThread <> kNotDefined then
			memoWriteLn(['init cohort ', p^.yearOfBirth.value, ', thread: ', indThread])
		else
			memoWriteLn(['init cohort ', p^.yearOfBirth.value]);
		calcFecGenNuptMas(randomGenerator, p, nil, objUnionTable, not readState, idWoman, arrayChildren, true);
		objUnionTable.Destroy();
		DestroyArrayChildren(arrayChildren);
	end;

	procedure DemographicRegimeSettings_initOne (
												randomGenerator: TRandomNumberGenerator;							
												p: pStructDemographicRegimeSettings;
												cohortInit: longint;
												readState: boolean = false);
	// when we init only one demographic regime at a time
	begin
		DemographicRegimeSettings_initMain (p, cohortInit);
		g_silentMode := true;
		DemographicRegimeSettings_initFec (randomGenerator, p, readState);
		g_silentMode := false;
	end;
	
	procedure DemographicRegimeSettings_saveState (p: pStructDemographicRegimeSettings; f: TFileType); // Obsolete or to be reimplemented in a future version
	var
		af: FecundAges;
		ind, len: longint;
		
	begin
		bWriteLn (f, [p^.yearOfBirth.value]);
		bWriteLn (f, [p^.r]);
		for af:= kMinAgeFert to kMaxAgeFert do
			bWrite (f, [p^.distribStableFert^ [af], tab]);
		cWriteLn (f);
		len := length (p^.aPrioriPPR_adjusted.value) - 1;
		for ind := 0 to len do
			bWriteLn(f, [p^.aPrioriPPR_adjusted.value[ind]]);
	end;

	procedure DemographicRegimeSettings_postInit (p: pStructDemographicRegimeSettings);
	begin
	end;
		
	procedure DemographicRegimeSettings__interpolate (p: pStructDemographicRegimeSettings; setInterpolated: boolean = true);
	var
		pFrom, pUntil: pStructDemographicRegimeSettings;
		mult: double;
		pfd: paramDemReg_double;
		pfl: paramDemReg_longint;
		ind: longint;
		edLevel1, edLevel2, edLevel3: EduLevels;
		vSex: Sex;
		
		function lInterp (lFrom, lUntil: longint): longint;
		begin
			lInterp := lFrom + round ( (lUntil - lFrom) * mult );
		end;
		
		function vInterp (vFrom, vUntil: double): double;
		begin
			vInterp := vFrom + (vUntil - vFrom) * mult;
		end;
		
	begin
		if not p^.toBeInterpolated then exit;
		with g_pCOHORT_COLLECTION^ do begin
			pFrom := data[p^.interpolate_from];
			pUntil := data[p^.interpolate_until];
		end;
		mult := (p^.yearOfBirth.value - pFrom^.yearOfBirth.value) / (pUntil^.yearOfBirth.value - pFrom^.yearOfBirth.value);
		
		for pfd := low(paramDemReg_double) to high(paramDemReg_double) do begin
			p^.dp[pfd].value := vInterp (pFrom^.dp[pfd].value, pUntil^.dp[pfd].value);
		end;

		for pfl := low(paramDemReg_longint) to high(paramDemReg_longint) do begin
			p^.lp[pfl].value := lInterp (pFrom^.lp[pfl].value, pUntil^.lp[pfl].value);
		end;

		for ind := 0 to kMaxIndBirthIntervals do begin
			p^.effStopping.value [ind] := vInterp (pFrom^.effStopping.value [ind], pUntil^.effStopping.value [ind]);
			p^.effSpacing.value [ind] := vInterp (pFrom^.effSpacing.value [ind], pUntil^.effSpacing.value [ind]);
			p^.meanTimeSpacing.value [ind] := vInterp (pFrom^.meanTimeSpacing.value [ind], pUntil^.meanTimeSpacing.value [ind]);
		end;
		
		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR.value[ind] := vInterp (pFrom^.aPrioriPPR.value[ind], pUntil^.aPrioriPPR.value[ind]);
		
		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR_adjusted.value[ind] := vInterp (pFrom^.aPrioriPPR_adjusted.value[ind], pUntil^.aPrioriPPR_adjusted.value[ind]);

        adjustContraception (p);

		for ind := 0 to kMaxNbChildren do
			p^.aPrioriPPR_result.value[ind] := vInterp (pFrom^.aPrioriPPR_result.value[ind], pUntil^.aPrioriPPR_result.value[ind]);
		
		for edLevel1 := eduLow to eduHigh do
			for vSex := man to woman do
				p^.eduEgo [edLevel1, vSex].value := vInterp (pFrom^.eduEgo [edLevel1, vSex].value, pUntil^.eduEgo [edLevel1, vSex].value);

		for edLevel1 := eduLow to eduHigh do
			for vSex := man to woman do
				for edLevel2 := eduLow to eduHigh do
					p^.eduEgoPartner [edLevel1, vSex, edLevel2].value := vInterp (
						pFrom^.eduEgoPartner [edLevel1, vSex, edLevel2].value,
						pUntil^.eduEgoPartner [edLevel1, vSex, edLevel2].value);

		for edLevel1 := eduLow to eduHigh do
			for edLevel2 := eduLow to eduHigh do
				for edLevel3 := eduLow to eduHigh do
					p^.eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3].value := vInterp (
						pFrom^.eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3].value,
						pUntil^.eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3].value);

		if setInterpolated then p^.toBeInterpolated := false;
		p^.readInConfig := false;
	end;
	
	procedure DemographicRegimeSettings_destroy (var p: pStructDemographicRegimeSettings);
		var
			ageWomen, ageMen: longint;
			pfd: paramDemReg_double;
			pfl: paramDemReg_longint;
			vSex: Sex;
			ind: longint;
			
	begin
		DestroyEduStatus (p);
		
		SetLength (p^.mortalityInfo.survival_men, 0);
		SetLength (p^.mortalityInfo.survival_women, 0);

		disposeNuptialitySettings (p^.nuptialityInfo);
		
		SetLength (p^.separationInfo.monthly_risk_separation, 0);

		SetLength (p^.temporary_sterility, 0);

		SetLength (p^.AccDurationContrAfterUnion, 0);
		for ind := 0 to kMaxIndBirthIntervals do begin
			SetLength (p^.AccDurationWaitingTime[ind], 0);
		end;
		
		p^.yearOfBirth.Destroy;
		for pfd := low(paramDemReg_double) to high(paramDemReg_double) do begin
			p^.dp[pfd].Destroy;
		end;
		for pfl := low(paramDemReg_longint) to high(paramDemReg_longint) do begin
			p^.lp[pfl].Destroy;
		end;

		p^.aPrioriPPR.Destroy;
		p^.CTFR.Destroy;
		p^.aPrioriPPR_adjusted.Destroy;
		p^.CTFR_adjusted.Destroy;
		p^.aPrioriPPR_result.Destroy;
		p^.effStopping.Destroy;
		p^.effSpacing.Destroy;
		p^.meanTimeSpacing.Destroy;

		disposePtr(ptr(p^.distribStableFert), 'distribStableFert');

{		setLength (p^.distNbChildren[allStates50], 0);
		setLength (p^.distNbChildren[alive50EverInUnion], 0);
		setLength (p^.distNbChildren[aliveWithFirstPartner50], 0);
}
		p^.adjusted.aPrioriPPR.Destroy;
		
		disposePtr(ptr(p), 'pStructDemographicRegimeSettings');
	end;

	procedure DemographicRegimeSettings_dumpData (p: pStructDemographicRegimeSettings; outFile: TFileType; removeOptional: boolean = false); // Main thread only
	var
		ind: longint;
		edLevel1, edLevel2, edLevel3: EduLevels;
		vSex: Sex;
		
	begin
		with p^ do begin
			bWrite (outFile, [yearOfBirth.value, tab]);

			write_Value_ArrayOfLongintName(outFile, tab, lp, removeOptional);
			write_Value_ArrayOfDoubleName(outFile, tab, dp, removeOptional);

	{============ CONTRACEPTION AFTER UNION =============}
			for ind := 0 to (kMaxNbChildrenCalc+1) do
				bWrite (outFile, [aPrioriPPR.value [ind], tab]);
            if not removeOptional then
				for ind := 0 to (kMaxNbChildrenCalc+1) do
					bWrite (outFile, [aPrioriPPR_adjusted.value [ind], tab]);

			writeArrayOfDouble(outFile, tab, effStopping.value);
			writeArrayOfDouble(outFile, tab, effSpacing.value);
			writeArrayOfDouble(outFile, tab, meanTimeSpacing.value);

			if g_GENPARAM.eduKind.value = eduStochastic then
				for vSex := man to woman do
					for edLevel1 := eduLow to eduHigh do
						bWrite (outFile, [eduEgo [edLevel1, vSex].value, tab]);
			if g_GENPARAM.eduKind.value = eduCohort then
				for edLevel1 := eduLow to eduHigh do
					for vSex := man to woman do
						for edLevel2 := eduLow to eduHigh do
						bWrite (outFile, [eduEgoPartner [edLevel1, vSex, edLevel2].value, tab]);
			if g_GENPARAM.eduKind.value = eduIntraFamily then
				for edLevel1 := eduLow to eduHigh do
					for edLevel2 := eduLow to eduHigh do
						for edLevel3 := eduLow to eduHigh do
							bWrite (outFile, [eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3].value, tab]);
			cWriteLn (outFile);
		end;
	end;

	procedure DemographicRegimeSettings_writeDetailedData (p: pStructDemographicRegimeSettings; indStr: string = '');
	var
		outFile: TFileType;
		ind, len: longint;
		indChildren: nbChildrenEnum;

		procedure writeNuptiality (n: nuptialitySettings);
		var
			aNupt: agesUnion;
			ind, len: longint;
		begin
			with n do begin
				cWriteLn (outFile, 'prop_cel_women');
				writeLnArrayOfDoubleOffset(outFile, tab, prop_cel_women, kMinAgeUnion);
				cWriteLn (outFile, 'prop_cel_men');
				writeLnArrayOfDoubleOffset(outFile, tab, prop_cel_men, kMinAgeUnion);
				cWriteLn (outFile, 'union_women');
				writeLnArrayOfDoubleOffset(outFile, tab, union_women, kMinAgeUnion);
				cWriteLn (outFile, 'nupt_men');
				writeLnArrayOfDoubleOffset(outFile, tab, nupt_men, kMinAgeUnion);
				cWriteLn (outFile, 'union_women_men');
				for aNupt := kMinAgeUnion to kMaxAgeUnion_women do begin
					bWrite (outFile, [aNupt, tab, ' normal: ', tab]);
					writeLnArrayOfDoubleOffset(outFile, tab, union_women_men[aNupt, normal], kMinAgeUnion);
					bWrite (outFile, [aNupt, tab, ' aggregated: ', tab]);
					writeLnArrayOfDoubleOffset(outFile, tab, union_women_men[aNupt, aggregated], kMinAgeUnion);
				end;
				cWriteLn (outFile, 'union_men_women');
				for aNupt := kMinAgeUnion to kMaxAgeUnion do begin
					bWrite (outFile, [aNupt, tab, ' normal: ', tab]);
					writeLnArrayOfDoubleOffset(outFile, tab, union_men_women[aNupt, normal], kMinAgeUnion);
					bWrite (outFile, [aNupt, tab, ' aggregated: ', tab]);
					writeLnArrayOfDoubleOffset(outFile, tab, union_men_women[aNupt, aggregated], kMinAgeUnion);
				end;
				cWriteLn (outFile, 'unionParam');
				for ind := man to woman do begin
					bWrite (outFile, [ind, ':', tab]);
					writeLnArrayOfDouble(outFile, tab, unionParam[ind]);
				end;

				cWriteLn (outFile, 'prop_repartnering');
				len := length (prop_repartnering) - 1;
				for ind := 0 to len do begin
					bWrite (outFile, [str_gender [ind], ':', tab]);
					writeLnArrayOfDoubleOffset(outFile, tab, prop_repartnering[ind], kMinAgeUnion);
				end;
			end;
		end;

	begin
		if not openFileOut('demRegCohort' + intToStr (p^.yearOfBirth.value) + indStr + '.txt', 'DEMREGCOHORT', outFile, kAsyncFalse) then
			exit; // Main thread only
		
		with p^ do begin

		{============ GENERAL PARAMETERS SET IN CONFIG ===========}
			bWriteLn (outFile, ['cohort:', tab, yearOfBirth.value]);
			
			cWriteLn(outFile, 'lp');
			writeLnArrayOfLongintName(outFile, tab, lp);

		{============ CONTRÔLE FACTEURS BIOLOGIQUES ============}
		
			cWriteLn(outFile, 'dp');
			writeLnArrayOfDoubleName(outFile, tab, dp);
					
		{============ CONTRACEPTION AFTER UNION =============}
			bWriteLn (outFile, ['MeanTimeContraceptionAfterUnion:', tab, MeanTimeContraceptionAfterUnion]);
			bWriteLn (outFile, ['propContraceptionAfterUnion_var:', tab, propContraceptionAfterUnion_var]);
			cWriteLn (outFile, 'AccDurationContrAfterUnion');
			writeLnArrayOfDouble(outFile, tab, AccDurationContrAfterUnion);

			bWriteLn (outFile, ['aPrioriPPR', tab, 'aPrioriPPR_adjusted', tab, 'aPrioriPPR_result']);
			len := length (aPrioriPPR.value) - 1;
			for ind := 0 to len do
				bWriteLn(outFile, [ind, tab, aPrioriPPR.value[ind], tab, aPrioriPPR_adjusted.value[ind], tab, aPrioriPPR_result.value[ind]]);

			cWriteLn (outFile, 'curr_contracepStopping');
			writeLnArrayOfDouble(outFile, tab, curr_contracepStopping);

			cWriteLn(outFile, 'effStopping');
			writeLnArrayOfDouble(outFile, tab, effStopping.value);
			cWriteLn(outFile, 'proportionUsingSpacing');
			writeLnArrayOfDouble(outFile, tab, effSpacing.value);
			cWriteLn(outFile, 'meanTimeSpacing');
			writeLnArrayOfDouble(outFile, tab, meanTimeSpacing.value);
			cWriteLn (outFile, 'AccDurationWaitingTime');
			for ind := 0 to kMaxIndBirthIntervals do begin
				bWriteLn (outFile, ['AccDurationWaitingTime: ', ind]);
				writeLnArrayOfDouble(outFile, tab, AccDurationWaitingTime[ind]);
			end;
			
		{=========== DEMOGRAPHIC REGIME VARIABLES SET BY PREVIOUS PARAMETERS ============}
			{MORTALITY}
			cWriteLn (outFile, '=====mortalitySettings');
			with mortalityInfo do begin
				cWriteLn (outFile, 'survival_men');
				writeLnArrayOfDouble(outFile, tab, survival_men);
				cWriteLn (outFile, 'survival_women');
				writeLnArrayOfDouble(outFile, tab, survival_women);

				cWriteLn (outFile, 'survivalAdult_women');
				writeLnArrayOfDouble(outFile, tab, survivalAdult_women);
				cWriteLn (outFile, 'survivalAdult_men');
				writeLnArrayOfDouble(outFile, tab, survivalAdult_men);
			end;
			
			{NUPTIALITY}
			if pCurrUnionInfo = @nuptialityInfo then begin
				cWriteLn (outFile, '=====NuptialitySettings');
				writeNuptiality (nuptialityInfo);
			end;

			{SEPARATION}
			{**********}
			cWriteLn (outFile, '=====separationSettings');

			with separationInfo do begin
				bWriteLn (outFile, ['separationPossible:', tab, separationPossible]);
				bWriteLn (outFile, ['separation_median:', tab, separation_median]);
				bWriteLn (outFile, ['separation_shape:', tab, separation_shape]);
				bWriteLn (outFile, ['separation_proportion:', tab, separation_proportion]);
				bWriteLn (outFile, ['freqSeparation:', tab, freqSeparation]);
				bWriteLn (outFile, ['freqSeparation adj:', tab, freqSeparation_adjusted]);
				bWriteLn (outFile, ['freqSeparation res:', tab, freqSeparation_result]);
				{**********}
		
				{monthly_risk_separation: array[0..kMaxDurationUnionInMonths] of double;}
				cWriteLn (outFile, 'monthly_risk_separation');
				writeLnArrayOfDouble(outFile, tab, monthly_risk_separation);
		
				cWriteLn (outFile, 'cumul_separation');
				writeLnArrayOfDouble(outFile, tab, cumul_separation);
				cWriteLn (outFile, 'relRisk_separation_children_duration');
				for indChildren := oneChild to twoChildrenMore do begin
					bWrite(outFile, [indChildren, ':', tab]);
					for ind := -11 to kMaxDurationUnionInMonths do begin
						bWriteLn (outFile, [ind, tab, relRisk_separation_children_duration [indChildren][ind]]);
					end;
				end;
			end;
			
			{FERTILITY}
			bWriteLn (outFile, ['DF_apriori:', tab, DF_apriori]);

			cWriteLn (outFile, 'distribStableFert');
			writeLnArrayOfDouble(outFile, tab, distribStableFert^);

			{temporary_sterility: array[10..kMaxMonthTemporarySterility+10] of double;}
			cWriteLn (outFile, 'temporary_sterility');
			writeLnArrayOfDouble(outFile, tab, temporary_sterility);
			
		end;
		
		outFile.Destroy;
	end;
 
	procedure DemRegimeCollection_create ();
	begin
		if g_pCOHORT_COLLECTION <> nil then begin
		    DemRegimeCollection_destroy;
		end;
		new(g_pCOHORT_COLLECTION);
{		if g_pCOHORT_COLLECTION = nil then
			noMemory('g_pCOHORT_COLLECTION');}
		newPtr (ptr(g_pCOHORT_COLLECTION), 'g_pCOHORT_COLLECTION');


		with g_pCOHORT_COLLECTION^ do begin
			pInit := nil;
			setLength(data, 1);
			data [0] := DemographicRegimeSettings_create ();
			nCohorts := 0; {important: array of double uses index starting at 0,
							therefore nCohorts is the count of cohorts LESS ONE}
			firstCohort := 0;
			lastCohort := 0;
			lastCohortAdded := 0;
			stateRead := false;
		end;
		
		g_pDEM_REG := g_pCOHORT_COLLECTION^.data [0];

	end;

	procedure DemRegimeCollection_readState (); // at the moment obsolete
	var
		ind: longint;
		f: TFileType; // Obsolete, not used, or to be reimplemented in a future version
	begin
		if 	( g_FileName_DemographicRegime_save.value = '' ) or
			not fileExist (g_FileName_DemographicRegime_save.value, false) then exit;
			
		if not openFileRead (g_FileName_DemographicRegime_save.value, 'READDEMREG', f) then begin
			writeAndWaitConst(['===> ERROR: Error reading demographic regimes state']);
			myHalt(['Error reading demographic regimes state']);
		end;

		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_readState (g_pCOHORT_COLLECTION^.data[ind], f);
			end;
		end;

		f.Destroy;
	end;
	
	procedure DemRegimeCollection_saveState (); // probably obsolete
	var
		f: TFileType;
		ind: longint;
	begin
 		if ( g_FileName_DemographicRegime_save.value = '' ) then exit;

		if fileExist (g_FileName_DemographicRegime_save.value, true) then exit;

		if not openFileWriteConfig (g_FileName_DemographicRegime_save.value, 'DEMREGIMECOLLECTION_SAVESTATE', f) then begin
			memoWriteLn(['Error saving demographic regimes state']);
			myHalt(['Error saving demographic regimes state']);
		end;
		
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_saveState (g_pCOHORT_COLLECTION^.data[ind], f);
			end;
		end;

		f.Destroy;
	end;
	
	procedure DemRegimeCollection_destroy ();
	var
		ind: longint;
	begin
		if g_pCOHORT_COLLECTION = nil then exit;
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			DemRegimeCollection_saveState ();
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_destroy (g_pCOHORT_COLLECTION^.data[ind]);
			end;
			SetLength(g_pCOHORT_COLLECTION^.data, 0);
		end;
		if (g_pCOHORT_COLLECTION^.pInit <> nil) then begin
			DemographicRegimeSettings_destroy (g_pCOHORT_COLLECTION^.pInit);
			g_pCOHORT_COLLECTION^.pInit := nil;
		end;
		disposePtr(ptr(g_pCOHORT_COLLECTION), 'g_pCOHORT_COLLECTION');
		g_pDEM_REG := nil;
		disposeMotherhood_DemReg;
	end;

	procedure DemRegimeCollection_interpolate (setInterpolated: boolean = true);
	var
		ind: longint;
		minNumberWomen, mothersBridesMultiplier: double;

	begin
		with g_pCOHORT_COLLECTION^ do begin
			if nCohorts > 0 then
			begin
				minNumberWomen := power(10, 100);
				for ind := 0 to nCohorts do
					if not data[ind]^.toBeInterpolated then
					begin
						if (data[ind]^.lp[nWomenPar].value < minNumberWomen) then
							minNumberWomen := data[ind]^.lp[nWomenPar].value;
					end;
				for ind := 0 to nCohorts do
					if data[ind]^.toBeInterpolated then
						DemographicRegimeSettings__interpolate (data[ind], setInterpolated);
				mothersBridesMultiplier := g_GENPARAM.RUNTIME[cmd_numberWomen].value / minNumberWomen;
				for ind := 0 to nCohorts do
					{Adjust the number of women using the parameter 'cmd_numberWomen' in 'low level options' panel
					using the minimum number of women for scaling}
					data[ind]^.lp[nWomenPar].value := trunc (data[ind]^.lp[nWomenPar].value * mothersBridesMultiplier);
			end;
		end;
	end;
	
	procedure DemRegimeCollection_init (randomGenerator: TRandomNumberGenerator);
	var
		ind: longint;
		readState: boolean = false;
		//f: TFileType; // Obsolete, not used, or to be reimplemented in a future version
		initThreads: array of TDemRegInitThread;
		nActiveThreads: longint;
		threadSlots_used: array of longint;
		firstSlotNotUsed: longint = 0;
		nReadInConfig, indReadInConfig: longint;
        nThreadsUsed: longint = 0;
        tStart: TDateTime;  // Begin and end of measurement, and difference
		allThreadsDead: boolean = true;
	begin
        memoWriteLn (['Demographic regimes init...']);
        tStart := Now();
        flushIO();
		if g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_INIT.value then begin
			nReadInConfig := 0;
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do
				if g_pCOHORT_COLLECTION^.data[ind]^.readInConfig then
					inc (nReadInConfig);
			setLength (initThreads{%H-}, nReadInConfig);
            nThreadsUsed := min(gMaxThreads, nReadInConfig);
			setLength (threadSlots_used{%H-}, nThreadsUsed);
		end;

{		readState := fileExist (g_FileName_DemographicRegime_save.value, false);
		readState := false; // this is obsolete or to be implemented in a future version of the readstate / writestate mechanism
		if readState then
			if not openFileRead (g_FileName_DemographicRegime_save.value, f) then begin
				writeAndWaitConst(['===> ERROR: Error opening Demographic Regimes saved state file']);
				myHalt(['Error opening Demographic Regimes saved state file']);
			end;
}

		with g_pCOHORT_COLLECTION^ do begin
			if nCohorts = 0 then begin
				firstCohort := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
				lastCohort := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
			end;
			if nCohorts >= 0 then
			begin
				DemRegimeCollection_interpolate (false);
				for ind := 0 to nCohorts do
					DemographicRegimeSettings_initMain (data[ind], firstCohort + ind);
			
				g_silentMode := true;
				if not StablePopulation and g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_INIT.value then begin
					nActiveThreads := 0;
					indReadInConfig := 0;
					for ind := 0 to nCohorts do
						if data[ind]^.readInConfig then begin
							initThreads [indReadInConfig] := TDemRegInitThread.create (true, data[ind]);
							Inc (indReadInConfig);
						end;
					if (g_GENPARAM.TALKATIVE.value) then begin
						stopTime (tStart, '===== Init threads phase lasted: ');
					end;
					repeat
						allThreadsDead := true;
						for ind := Low(initThreads) to High(initThreads) do begin
							allThreadsDead := false;
							if not (initThreads[ind].myThreadState = thread_dead) then
								if initThreads[ind].terminated then
								begin
									Dec(nActiveThreads);
									initThreads[ind].myThreadState := thread_dead;
									threadSlots_used[initThreads[ind].myThreadSlotUsed - 1] := 0;
								end else if (nActiveThreads < nThreadsUsed) and (initThreads[ind].myThreadState = thread_suspended) then begin
									firstSlotNotUsed := 0;
									while (threadSlots_used[firstSlotNotUsed] > 0) do
										Inc(firstSlotNotUsed);
									threadSlots_used[firstSlotNotUsed] := ind + 1;
									Inc(nActiveThreads);
									initThreads[ind].myThreadSlotUsed := firstSlotNotUsed + 1;
									initThreads[ind].start;
								end;
						end;
					until (nActiveThreads <= 0) or (allThreadsDead);
					if (g_GENPARAM.TALKATIVE.value) then
						memoWriteLn (['All TDemRegInitThread ended. Now wait for... ',nActiveThreads, ' active threads']);
					for ind := Low(initThreads) to High(initThreads) do begin
						initThreads[ind].WaitFor;
						initThreads[ind].Free;
					end;
					setLength (initThreads, 0);
				end else
					for ind := 0 to nCohorts do
						if data[ind]^.readInConfig then
							DemographicRegimeSettings_initFec (randomGenerator, data[ind], readState);
				g_silentMode := false;
			end;
			
			DemRegimeCollection_interpolate;
		end; {g_pCOHORT_COLLECTION^}
		if g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_INIT.value then begin
			setLength (initThreads{%H-}, 0);
			setLength (threadSlots_used, 0);
		end;
        memoWriteLn (['Demographic regimes init ended']);
        flushIO();
	end;

	procedure DemRegimeCollection_initAdjustedValues;
	var
		ind: longint;
	begin
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_initAdjustedValues (g_pCOHORT_COLLECTION^.data[ind]);
			end;
		end;
	end;
	
	procedure DemRegimeCollection_saveAdjustedValues;
	var
		ind: longint;
	begin
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_saveAdjustedValues (g_pCOHORT_COLLECTION^.data[ind]);
			end;
		end;
	end;
	
	function DemRegimeCollection_adjustedValuesSaved: boolean;
	var
		ind: longint;
	begin
		result := false;
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				result := result or DemographicRegimeSettings_adjustedValuesSaved (g_pCOHORT_COLLECTION^.data[ind]);
			end;
		end;
	end;

	procedure DemRegimeCollection_SetChangedDefaultValues;
	var
		ind: longint;
	begin
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_SetChangedDefaultValues (g_pCOHORT_COLLECTION^.data[ind]);
			end;
		end;
	end;
	
	function DemRegimeCollection_CheckChangedDefaultValues: boolean;
	var
		ind: longint;
	begin
		result := false;
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				result := result or DemographicRegimeSettings_CheckChangedDefaultValues (g_pCOHORT_COLLECTION^.data[ind]);
				if result then
					exit;
			end;
		end;
	end;

	function DemRegimeCollection_VariousCohorts: boolean;
	begin
		result := (g_pCOHORT_COLLECTION^.nCohorts >= 1);
	end;

	function DemRegimeCollection_nCohorts: longint;
	begin
		result := g_pCOHORT_COLLECTION^.nCohorts + 1;
	end;

	function DemRegimeCollection_firstCohort: longint;
	begin
		if g_pCOHORT_COLLECTION^.firstCohort <> 0 then
			result := g_pCOHORT_COLLECTION^.firstCohort
		else begin
			result := g_pCOHORT_COLLECTION^.data[0]^.yearOfBirth.value;
		end;
	end;

	function DemRegimeCollection_lastCohort: longint;
	begin
		if g_pCOHORT_COLLECTION^.lastCohort <> 0 then
			result := g_pCOHORT_COLLECTION^.lastCohort
		else begin
			result := g_pCOHORT_COLLECTION^.data[g_pCOHORT_COLLECTION^.nCohorts]^.yearOfBirth.value;
		end;
	end;

	procedure DemRegimeCollection_postInit ();
	var
		ind: longint;
	begin
		if g_pCOHORT_COLLECTION^.nCohorts >= 0 then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_postInit (g_pCOHORT_COLLECTION^.data[ind]);
			end;
		end;
	end;

	function DemRegimeCollection_first: pStructDemographicRegimeSettings;
	begin
		if g_pCOHORT_COLLECTION = nil then
			exit (nil);
		result := g_pCOHORT_COLLECTION^.data[0];
	end;
	
	function DemRegimeCollection_last: pStructDemographicRegimeSettings;
	begin
		if g_pCOHORT_COLLECTION = nil then
			exit (nil);
		with g_pCOHORT_COLLECTION^ do
			result := data[length(data)-1];
	end;
		
	function DemRegimeCollection_addCohort (yearOfBirth: longint): pStructDemographicRegimeSettings;
	var
		num_from, num_until, n_toInter, ind: longint;
		pFirstDemReg: pStructDemographicRegimeSettings;
		
	begin
		with g_pCOHORT_COLLECTION^ do begin
			if (firstCohort = 0) then begin
				// Preserve an initial copy of what was read from the main file and use that to initialise data for each cohort
				pFirstDemReg := DemRegimeCollection_first;
				pInit := DemographicRegimeSettings_create ();
				DemographicRegimeSettings_copyState (pFirstDemReg, pInit);
				firstCohort := yearOfBirth;
				pFirstDemReg^.yearOfBirth.value := yearOfBirth;
			end else begin
				if (yearOfBirth > lastCohortAdded + 1) then begin
					num_from := nCohorts;
					num_until := nCohorts + yearOfBirth - lastCohortAdded;
					n_toInter := yearOfBirth - lastCohortAdded - 1;
					for ind := 1 to n_toInter do begin
						Inc ( nCohorts );
						SetLength (data, nCohorts+1);
						data [nCohorts] := DemographicRegimeSettings_create ();
						DemographicRegimeSettings_copyState (pInit, data [nCohorts]);
						data [nCohorts]^.yearOfBirth.value := lastCohortAdded + ind;
						data [nCohorts]^.toBeInterpolated := true;
						data [nCohorts]^.readInConfig := false;
						data [nCohorts]^.interpolate_from := num_from;
						data [nCohorts]^.interpolate_until := num_until;
					end;
				end else if (yearOfBirth <= lastCohortAdded) then begin
					writeAndWaitConst(['===> ERROR: Cohort file wrong year of birth: ', yearOfBirth]);
					myHalt(['Cohort file wrong year of birth: ', yearOfBirth]);
				end;
				Inc (nCohorts);
				SetLength (data, nCohorts+1);
				data [nCohorts] := DemographicRegimeSettings_create ();
				DemographicRegimeSettings_copyState (pInit, data [nCohorts]);
				data [nCohorts]^.yearOfBirth.value := yearOfBirth;
			end;
			lastCohort := yearOfBirth;
			lastCohortAdded := yearOfBirth;
			DemRegimeCollection_addCohort := data [nCohorts];
		end;
	end;
	
	function sexToInt (s: string): longint;
	begin
		if (copy (uppercase (s), 1, 3) = 'MAN') then sexToInt := 0
		else if (copy (uppercase (s), 1, 5) = 'WOMAN') then sexToInt := 1
		else sexToInt := kNotDefined;
	end;
	
	function eduLevelsToInt (s: string): longint;
	begin
		if (copy (uppercase (s), 1, 3) = 'LOW') then eduLevelsToInt := 0
		else if (copy (uppercase (s), 1, 6) = 'MEDIUM') then eduLevelsToInt := 1
		else if (copy (uppercase (s), 1, 4) = 'HIGH') then eduLevelsToInt := 2
		else eduLevelsToInt := kNotDefined;
	end;
	
	function DemRegimeCollection_readData (fileName: string): boolean;
	var
		posValues: array [1..maxValuePos] of posValueRec;
		
		s: string;
		code: word;
		n, res, ind: longint;
		aLine: ansistring;
        nLines: longint;
		pDemReg: pStructDemographicRegimeSettings;
		lastPPR: longint = 0;
		lastPPR_adjusted: longint = 0;
		lastEffStopping: longint = 0;
		lastEffSpacing: longint = 0;
		lastMeanTimeSpacing: longint = 0;
		
		function ProcessFirstLine ( aLine: ansistring ): boolean;
		var
			pfd: paramDemReg_double; // we repeat the declaration otherwise it does not compile !!
			pfl: paramDemReg_longint; // we repeat the declaration otherwise it does not compile !!
			n: longint = 1;
			snum: string;
			pFirstDemReg: pStructDemographicRegimeSettings;
			label nextWord;
		begin
			ProcessFirstLine := FALSE;
			pFirstDemReg := DemRegimeCollection_first; // this one has all the labels for reading the header
			s := ExtractWord (n, aLine, tabSet);
			if (s <> 'COHORT') then begin
				memoWriteLn(['First column variable should be COHORT in cohort file']);
				exit;
			end;
			n := 2;
			s := ExtractWord (n, aLine, tabSet);
			while (s <> '') do begin

				for pfd := low(paramDemReg_double) to high(paramDemReg_double) do begin
					if ( s = pFirstDemReg^.dp[pfd].name ) then begin
						with posValues [n] do begin
							pv := pfk_double;
							posTable := ord (pfd);
						end;
						goto nextWord;
					end;
				end;

				for pfl := low(paramDemReg_longint) to high(paramDemReg_longint) do begin
					if ( s = pFirstDemReg^.lp[pfl].name ) then begin
						with posValues [n] do begin
							pv := pfk_longint;
							posTable := ord (pfl);
						end;
						goto nextWord;
					end;
				end;

				if (copy(s, 1, 12) = 'PPR_ADJUSTED') then begin
					snum := ExtractWord (3, s, uSet);
					val (snum, res, code);
					if not checkCode ( s, code ) then exit;
					with posValues [n] do begin
						pv := ppr_adjusted;
						posTable := res;
					end;
				end else if (copy(s, 1, 3) = 'PPR') then begin
					snum := ExtractWord (2, s, uSet);
					val (snum, res, code);
					if not checkCode ( s, code ) then exit;
					with posValues [n] do begin
						pv := ppr;
						posTable := res;
					end;
				end else if (copy(s, 1, 23) = 'EFF_STOPPING_CONTRACEP_') then begin
					snum := ExtractWord (4, s, uSet);
					val (snum, res, code);
					if not checkCode ( s, code ) then exit;
					with posValues [n] do begin
						pv := effStopping;
						posTable := res;
					end;
				end else if (copy(s, 1, 19) = 'PROP_USING_SPACING_') then begin
					snum := ExtractWord (4, s, uSet);
					val (snum, res, code);
					if not checkCode ( s, code ) then exit;
					with posValues [n] do begin
						pv := effSpacing;
						posTable := res;
					end;
				end else if (copy(s, 1, 21) = 'WAITING_TIME_SPACING_') then begin
					snum := ExtractWord (4, s, uSet);
					val (snum, res, code);
					if not checkCode ( s, code ) then exit;
					with posValues [n] do begin
						pv := meanWaitingTimeSpacing;
						posTable := res;
					end;
				end else if (copy (s, 1, 4) = 'EDU_') then begin
					snum := ExtractWord (2, s, uSet);
					res := eduLevelsToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						pv := eduOwn;
						posTable := res * 10;
					end;
					snum := ExtractWord (3, s, uSet);
					res := sexToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						posTable := posTable + res;
					end;
				end else if (copy (s, 1, 11) = 'EDUPARTNER_') then begin
					snum := ExtractWord (2, s, uSet);
					res := eduLevelsToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						pv := eduPartner;
						posTable := res * 100;
					end;
					snum := ExtractWord (3, s, uSet);
					res := sexToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						posTable := posTable + res * 10;
					end;
					snum := ExtractWord (4, s, uSet);
					res := eduLevelsToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						posTable := posTable + res;
					end;
				end else if (copy (s, 1, 19) = 'EDUPARTNERCHILDREN_') then begin
					snum := ExtractWord (2, s, uSet);
					res := eduLevelsToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						pv := eduChildren;
						posTable := res * 100;
					end;
					snum := ExtractWord (3, s, uSet);
					res := eduLevelsToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						posTable := posTable + res * 10;
					end;
					snum := ExtractWord (4, s, uSet);
					res := eduLevelsToInt (snum);
					if res < 0 then begin checkCode (s, 1); exit; end;
					with posValues [n] do begin
						posTable := posTable + res;
					end;
				end else begin
					writeAndWaitConst(['===> ERROR: Unknown variable name in cohort file: ', s]);
					FlushIO;
					exit;
				end;

				nextWord:
					Inc (n);
					s := ExtractWord (n, aLine, tabSet);
			end;
			ProcessFirstLine := TRUE;
		end; {ProcessFirstLine}
	
		function processValuesLine ( aLine: ansistring ): boolean;
		var
			n: longint = 1;
			year: longint;
			resd: double;
			
		begin
			processValuesLine := FALSE;
			s := ExtractWord (n, aLine, tabSet);
			val (s, year, code);
			if not checkCode ( aLine, code ) then exit;

			pDemReg := DemRegimeCollection_addCohort ( year );
				
			n := 2;
			s := ExtractWord (n, aLine, tabSet);
			while (s <> '') do begin

				val (s, resd, code);
				if not checkCode ( s, code ) then exit;

				case posValues [n].pv of
					pfk_double: begin
// --- CLAUDE 2026-08-26 [N12] begin --------------------------------------------------
// was:
//						pDemReg^.dp[paramDemReg_double (posValues [n].posTable)].value := resd;
						pDemReg^.dp[paramDemReg_double (posValues [n].posTable)].value := resd;
						pDemReg^.dp[paramDemReg_double (posValues [n].posTable)].readInConfigFile := true;
// --- CLAUDE 2026-08-26 [N12] end ----------------------------------------------------
					end;
					pfk_longint: begin
// --- CLAUDE 2026-08-26 [N12] begin --------------------------------------------------
// was:
//						pDemReg^.lp[paramDemReg_longint (posValues [n].posTable)].value := trunc (resd);
// postProcessCohort tests lp[nWomenPar].readInConfigFile to decide whether the cohort
// file supplied its own NWOMEN, but readInConfigFile is set only inside the readValue
// methods of Declarations.pas, and processValuesLine assigns straight to .value. An
// explicit NWOMEN column was therefore always discarded and replaced by NEGO for every
// cohort read from the file, while cohort 0 kept its own value. The same is done for the
// double branch for consistency; readInConfigFile is read in exactly one place, so this
// changes nothing else.
						pDemReg^.lp[paramDemReg_longint (posValues [n].posTable)].value := trunc (resd);
						pDemReg^.lp[paramDemReg_longint (posValues [n].posTable)].readInConfigFile := true;
// --- CLAUDE 2026-08-26 [N12] end ----------------------------------------------------
					end;
					ppr: begin
						pDemReg^.aPrioriPPR.value [posValues [n].posTable] := resd;
						lastPPR := posValues [n].posTable;
					end;
					ppr_adjusted: begin
						pDemReg^.aPrioriPPR_adjusted.value [posValues [n].posTable] := resd;
						lastPPR_adjusted := posValues [n].posTable;
					end;
					effStopping: begin
						pDemReg^.effStopping.value [posValues [n].posTable] := resd;
						lastEffStopping := posValues [n].posTable;
					end;
					effSpacing: begin
						pDemReg^.effSpacing.value [posValues [n].posTable] := resd;
						lastEffSpacing := posValues [n].posTable;
					end;
					meanWaitingTimeSpacing: begin
						pDemReg^.meanTimeSpacing.value [posValues [n].posTable] := resd;
						lastMeanTimeSpacing := posValues [n].posTable;
					end;
					eduOwn: begin
						pDemReg^.eduEgo [EduLevels(dPos (posValues [n].posTable, 2)), Sex(dPos (posValues [n].posTable, 1))].value := resd;
					end;
					eduPartner: begin
						pDemReg^.eduEgoPartner [EduLevels(dPos (posValues [n].posTable, 3)), Sex(dPos (posValues [n].posTable, 2)), EduLevels(dPos (posValues [n].posTable, 1))].value := resd;
					end;
					eduChildren: begin
						pDemReg^.eduEgoPartnerChildren [EduLevels(dPos (posValues [n].posTable, 3)), EduLevels(dPos (posValues [n].posTable, 2)), EduLevels(dPos (posValues [n].posTable, 1))].value := resd;
					end;
				else
					begin
						writeAndWaitConst(['===> ERROR: Problem while reading cohort file col ', n, ' year ', year]);
						exit;
					end;
				end;

				Inc ( n );
				s := ExtractWord (n, aLine, tabSet);
			end;
			processValuesLine := TRUE;
		end; {processValuesLine}
		
		procedure postProcessCohort(pDemReg: pStructDemographicRegimeSettings);
		var
			ind: longint;
		begin
			for ind := lastPPR + 1 to kMaxNbChildren do begin
				pDemReg^.aPrioriPPR.value [ind] := pDemReg^.aPrioriPPR.value [ind - 1];
			end;
			for ind := lastPPR_adjusted + 1 to kMaxNbChildren do begin
				pDemReg^.aPrioriPPR_adjusted.value [ind] := pDemReg^.aPrioriPPR_adjusted.value [ind - 1];
			end;
			for ind := lastEffStopping + 1 to kMaxIndBirthIntervals do begin
				pDemReg^.effStopping.value [ind] := pDemReg^.effStopping.value [ind - 1];
			end;
			for ind := lastEffSpacing + 1 to kMaxIndBirthIntervals do begin
				pDemReg^.effSpacing.value [ind] := pDemReg^.effSpacing.value [ind - 1];
			end;
			for ind := lastMeanTimeSpacing + 1 to kMaxIndBirthIntervals do begin
				pDemReg^.meanTimeSpacing.value [ind] := pDemReg^.meanTimeSpacing.value [ind - 1];
			end;
			// nWomen is now the same than nEgo (proportional to the number of births in the population)
			if not pDemReg^.lp[nWomenPar].readInConfigFile then
				pDemReg^.lp[nWomenPar].value := pDemReg^.lp[nEgoPar].value;
		end;

	var
		f: TFileType;
		numYear, firstYear, previousYear, lastYear: longint;
		label onExit;
		
	begin
		DemRegimeCollection_readData := FALSE;
		if not openFileRead (fileName, 'DEMREGIMECOLLECTION_READDATA', f) then begin
			writeAndWaitConst(['===> ERROR: No Cohort file to read: ', fileName]);
			goto onExit;
		end;

        nLines := 0;
		//Read the first line with variable names
		readLn (f.fileHandle, aLine);
		Inc (nLines);
		if not ProcessFirstLine ( aLine ) then goto onExit;

		//Read the range of cohort years (we only read the first value of each line)
		//start with first year
        readLn (f.fileHandle, aLine);
		Inc (nLines);
		if (aLine <> '') then begin
			s := ExtractWord (1, aLine, tabSet);
			val (s, res, code);
			if not checkCode ( aLine, code ) then goto onExit;
			numYear := 1;
			firstYear := res;
			previousYear := firstYear;
		end;
        //.. then the rest of years
		while not eof (f.fileHandle) do begin
			readLn (f.fileHandle, aLine);
    		Inc (nLines);
			if (aLine <> '') then begin
				s := ExtractWord (1, aLine, tabSet);
				val (s, res, code);
				if not checkCode ( aLine, code ) then goto onExit;
				Inc ( numYear );
				lastYear := res;
				// check the year range
				if (lastYear <= previousYear) then begin
					writeAndWaitConst(['===> ERROR: Years in the cohort file should be in ascending order ', lastYear]);
					goto onExit;
				end;
				previousYear := lastYear;
			end;
		end;
		
		// Now read the variable values
		reset (f.fileHandle); // go to first line
		readLn (f.fileHandle, aLine); // step over first line which contains variable names
		while not eof (f.fileHandle) do begin
			readLn (f.fileHandle, aLine);
// --- CLAUDE 2026-08-26 [A1] begin --------------------------------------------------
// was:
//			if not processValuesLine (aLine) then goto onExit;
// A blank line made processValuesLine fail on the empty year field and the whole cohort
// file was rejected, although the first pass over the same file, twenty lines above,
// explicitly tolerates blank lines. The two passes now agree.
			if (aLine <> '') then
				if not processValuesLine (aLine) then goto onExit;
// --- CLAUDE 2026-08-26 [A1] end ----------------------------------------------------
		end;

		with g_pCOHORT_COLLECTION^ do
			for ind := 0 to nCohorts do
				if not data[ind]^.toBeInterpolated then
           			postProcessCohort(data[ind]);

		DemRegimeCollection_readData := TRUE;
		
onExit:
{$I-}
		f.Destroy;
{$I+}
		if (code <> 0) then begin
			writeAndWaitConst (['===> ERROR: Error on line: ', nLines]);
		end;
	end;

	procedure DemRegimeCollection_adjustData ();
	// Some data that was not read in the config file need to be changed
	var
		indCohort: longint;
		pDemReg: pStructDemographicRegimeSettings;
	begin
		if g_pCOHORT_COLLECTION^.nCohorts > 0 then begin
			for indCohort := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin
				pDemReg := g_pCOHORT_COLLECTION^.data[indCohort];
				pDemReg^.dp[propFinalCelibacyHigh].value := 0;
				pDemReg^.dp[meanAgeUnionWomenHigh].value := pDemReg^.dp[meanAgeUnionWomenLow].value;
			end;
		end else begin
			pDemReg := g_pCOHORT_COLLECTION^.data[0];
			if (not pDemReg^.dp[propFinalCelibacyHigh].changed) and (pDemReg^.dp[propFinalCelibacyLow].changed) then begin
				pDemReg^.dp[propFinalCelibacyHigh].value := pDemReg^.dp[propFinalCelibacyLow].value;
				pDemReg^.dp[propFinalCelibacyHigh].changed := true;
			end;
			if (not pDemReg^.dp[meanAgeUnionWomenHigh].changed) and (pDemReg^.dp[meanAgeUnionWomenLow].changed) then begin
				pDemReg^.dp[meanAgeUnionWomenHigh].value := pDemReg^.dp[meanAgeUnionWomenLow].value;
				pDemReg^.dp[meanAgeUnionWomenHigh].changed := true;
			end;
		end;
	end;
	
	procedure DemRegimeCollection_writeAdjustedValues;
	var
		fileNameOut: string;
		outFile: TFileType;
		ind, indCohort: longint;
		pDemReg: pStructDemographicRegimeSettings;
		
	begin
		if g_pCOHORT_COLLECTION^.nCohorts = 1 then exit;
		if not (g_GENPARAM.PPR_TARGET.value or g_GENPARAM.SEP_TARGET.value) then exit;
		//fileNameOut := copy (g_FileName.value, 1, length (g_FileName.value) - 4);
		fileNameOut := g_FileName.value + '_target.txt';

		if not openFileOut(fileNameOut, 'DemRegimeCollection_writeAdjustedValues', outFile, kAsyncFalse) then exit; // Main thread only

		bWrite (outFile, ['Cohort', tab, 'SEPARATION', tab, 'SEPARATION_ADJUSTED', tab]);
		bWrite (outFile, ['SEP_RESULT', tab]);
		for ind := 0 to kMaxNbChildrenCalc-1 do
			bWrite (outFile, ['PPR_', ind, tab]);
		for ind := 0 to kMaxNbChildrenCalc-1 do
			bWrite (outFile, ['PPR_ADJUSTED_', ind, tab]);
		for ind := 0 to kMaxNbChildrenCalc-1 do
			bWrite (outFile, ['PPR_RESULT_', ind, tab]);
		cWriteLn (outFile);

		for indCohort := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin
			pDemReg := g_pCOHORT_COLLECTION^.data[indCohort];
			if pDemReg^.readInConfig then begin
				bWrite (outFile, [pDemReg^.yearOfBirth.value, tab]);
				bWrite (outFile, [pDemReg^.separationInfo.freqSeparation, tab, pDemReg^.dp[freqSeparationFirstIteration].value, tab]);
				bWrite (outFile, [pDemReg^.separationInfo.freqSeparation_result, tab]);
				for ind := 0 to kMaxNbChildrenCalc-1 do
					bWrite (outFile, [pDemReg^.aPrioriPPR.value [ind], tab]);
				for ind := 0 to kMaxNbChildrenCalc-1 do
					bWrite (outFile, [pDemReg^.aPrioriPPR_adjusted.value [ind], tab]);
				for ind := 0 to kMaxNbChildrenCalc-1 do
					bWrite (outFile, [pDemReg^.aPrioriPPR_result.value [ind], tab]);
					
				cWriteLn (outFile);
			end;
		end;

		outFile.Destroy;
 	end;
	
	procedure DemRegimeCollection_writeData (cohorts: boolean; fileNameWithPath: string = ''; removeOptional: boolean = true);
	var
		outFile: TFileType;
		
		ind: longint;
		edLevel1, edLevel2, edLevel3: EduLevels;
		vSex: Sex;
		pFirstDemReg: pStructDemographicRegimeSettings;
		
	begin
		if not cohorts or ( g_pCOHORT_COLLECTION^.nCohorts < 0 ) then exit;
		
		if (length(fileNameWithPath) > 0) then begin
			if not openFileOutWithPath(fileNameWithPath, 'DUMP_COHORTS', outFile, kAsyncFalse) then exit;
		end else begin
			if not openFileOut('DUMP_COHORTS_' + g_FileName.value + '.txt', 'DUMP_COHORTS', outFile, kAsyncFalse) then exit;
		end;

		pFirstDemReg := DemRegimeCollection_first; // this one has a names
		
		bWrite (outFile, ['COHORT', tab]);

		write_Name_ArrayOfLongintName(outFile, tab, pFirstDemReg^.lp, removeOptional);
		write_Name_ArrayOfDoubleName(outFile, tab, pFirstDemReg^.dp, removeOptional);
		
		for ind := 0 to kMaxNbChildrenCalc+1 do
			bWrite (outFile, ['PPR_', ind, tab]);
		if not removeOptional then
			for ind := 0 to kMaxNbChildrenCalc+1 do
				bWrite (outFile, ['PPR_ADJUSTED_', ind, tab]);

		for ind := 0 to kMaxIndBirthIntervals do
			bWrite (outFile, ['EFF_STOPPING_CONTRACEP_', ind, tab]);
		for ind := 0 to kMaxIndBirthIntervals do
			bWrite (outFile, ['PROP_USING_SPACING_', ind, tab]);
		for ind := 0 to kMaxIndBirthIntervals do
			bWrite (outFile, ['WAITING_TIME_SPACING_', ind, tab]);

		if g_GENPARAM.eduKind.value = eduStochastic then
			for vSex := man to woman do
				for edLevel1 := eduLow to eduHigh do
					bWrite (outFile, [pFirstDemReg^.eduEgo [edLevel1, vSex].name, tab]);
		if g_GENPARAM.eduKind.value = eduCohort then
			for edLevel1 := eduLow to eduHigh do
				for vSex := man to woman do
					for edLevel2 := eduLow to eduHigh do
					bWrite (outFile, [pFirstDemReg^.eduEgoPartner [edLevel1, vSex, edLevel2].name, tab]);
		if g_GENPARAM.eduKind.value = eduIntraFamily then
			for edLevel1 := eduLow to eduHigh do
				for edLevel2 := eduLow to eduHigh do
					for edLevel3 := eduLow to eduHigh do
						bWrite (outFile, [pFirstDemReg^.eduEgoPartnerChildren [edLevel1, edLevel2, edLevel3].name, tab]);
		cWriteLn (outFile);

		for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin
			if not g_GENPARAM.CREATE_COHORT_FILE.value or
				(g_pCOHORT_COLLECTION^.data[ind]^.readInConfig and g_GENPARAM.CREATE_COHORT_FILE.value) then
				DemographicRegimeSettings_dumpData (g_pCOHORT_COLLECTION^.data[ind], outFile, removeOptional);
		end;

		outFile.Destroy;

 		if g_GENPARAM.DETAILED_COHORT_DATA.value then
		begin
			for ind := 0 to g_pCOHORT_COLLECTION^.nCohorts do begin				
				DemographicRegimeSettings_writeDetailedData (g_pCOHORT_COLLECTION^.data[ind]);
			end;
		end;
	end;
	
 	function DemRegimeCollection_stateRead (): boolean;
 	begin
 		DemRegimeCollection_stateRead := g_pCOHORT_COLLECTION^.stateRead;
 	end;

	procedure DemRegimeCollection_yearsReadInConfig (out a: arrayOfLongint);
	var
		nYears, indCohort, ind: longint;
	begin
		if length ({%H-}a) > 0 then exit;
		nYears := 0;
		for indCohort := 0 to (g_pCOHORT_COLLECTION^.nCohorts) do begin
			if g_pCOHORT_COLLECTION^.data[indCohort]^.readInConfig then
				Inc ( nYears );
		end;
		setLength(a{%H-}, nYears);
		ind := -1;
		for indCohort := 0 to (g_pCOHORT_COLLECTION^.nCohorts) do begin
			if g_pCOHORT_COLLECTION^.data[indCohort]^.readInConfig then begin
				Inc ( ind );
				a[ind] := g_pCOHORT_COLLECTION^.data[indCohort]^.yearOfBirth.value;
				end;
		end;
	end;
	
	function computeTFRfromPPRs(PPRs: ArrayOfDoubleName): double;
	var
		TFR: double = 0.0;
		last: double;
		ind: integer;
	begin
		last := 1;
		for ind := 0 to PPRs.myLength - 1 do begin
			last := last * PPRs.value[ind];
			TFR := TFR + last;
		end;
		TFR := trunc (TFR * 1000) / 1000;
		result := TFR;
	end;

	function StablePopulation: boolean;
	begin
		result := (g_pCOHORT_COLLECTION^.nCohorts = 0);
	end;
	
	function getCohort_p(year: longint): pStructDemographicRegimeSettings;
	begin
		if g_pCOHORT_COLLECTION = nil then exit (nil);
		with g_pCOHORT_COLLECTION^ do begin
			if nCohorts > 0 then begin
				if (year < firstCohort) then begin
					getCohort_p := data [0];
				end else if (year > lastCohort) then begin
					getCohort_p := data [nCohorts];
				end else begin
					getCohort_p := data [year - firstCohort];
				end;
			end else
				getCohort_p := data [0];
		end;
	end;
	
end.
