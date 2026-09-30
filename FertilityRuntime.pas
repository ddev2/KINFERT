{$I Defines.pas}
{$I Defines.pas}
unit FertilityRuntime;


interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, DemographicRegime, Mortality, Fertility, StablePop, Parenthood, Nuptiality, Utilities, RandomNumbers, StringResources, StringOfLib,
	Verification,
	{$IFDEF VerboseProfiler}Profiler,{$ENDIF} Math, SysUtils;

	procedure writeGeneralTables (objOutputFert: TOutputFertility);
	procedure resetFertilityCounts;
	procedure resetFertilityCountsThisSetting;
	procedure reportFertilityChecks (pDemReg: pStructDemographicRegimeSettings);
	function outputFileNameHeader (
							bootstrap_ind : longint;
							pDemReg: pStructDemographicRegimeSettings;
							openFiles: boolean): boolean;
	procedure checkStepsAndStablePopulation;
	procedure RunHeader (pRP: pRunParamRec; pDemReg: pStructDemographicRegimeSettings);
	procedure MessControlFec (pDemReg: pStructDemographicRegimeSettings);

	function calcCompleteFertilityWoman ( 
							randomGenerator: TRandomNumberGenerator;							
							pDemReg: pStructDemographicRegimeSettings; 
							param_deathWoman, param_deathMan: boolean;
							param_ageUnion: double;
							param_currentUnionNumber: longint;
							var unionStates: TUnionsType;
							var ageChildren: TabCompFertAge;
							var pChild: pInfoChildType;
							var fecundLife: FecundLifeType;
							objOutputFert: TOutputFertility;
							var arrayPartners: ArrayOfPersonMemoryBlock;
							useArrayGrooms: boolean = false;
							const arrayChildren: arrayOfInfoChild = nil;
							param_newPartnershipLife: boolean = true;
							isThreaded: boolean = false): longint;

	procedure calcFecGenNuptMas (
								randomGenerator: TRandomNumberGenerator;							
								pDemReg: pStructDemographicRegimeSettings;
								objOutputFert: TOutputFertility;
								objUnionTable: TUnionTable;
								computeDemReg: boolean;
								var idWoman: longint;
								const arrayChildren: arrayOfInfoChild;
								isInitFertility: boolean = false);

implementation

const
	{The parity progression adjustment of computeGenFert. Four passes was the fixed count before
	 N7 was fixed and is kept as the ceiling; the loop now leaves as soon as the cohort total
	 fertility the adjusted ratios produce is within the tolerance of the one asked for.
	 One hundredth of a child is below what the model can distinguish, since computeTFRfromPPRs
	 rounds its result to three decimals.}
	kMaxIterationsPPR = 4;
	kPPRTargetTolerance = 0.01;

	function compute_aprioriDF(pDemReg: pStructDemographicRegimeSettings): double;
	var
		DF_apriori, DF_rang: double;
		i: longint;
	begin
		{Calcul fécondité à priori}
		DF_apriori := 0;
		DF_rang := 1;
		for i := 0 to kMaxNbChildren do
		begin
			DF_rang := DF_rang * pDemReg^.curr_contracepStopping[i];
			DF_apriori := DF_apriori + DF_rang;
		end;
		pDemReg^.DF_apriori := DF_apriori;
		compute_aprioriDF := DF_apriori;
	end;
	
{ ----------------------------------------------------------------------------------
  Does the simulation give back the distributions it was given?

  Each of these compares what was drawn during the run with the input that governs the
  draw. A sampler reading the wrong table, or a table built wrongly, shows here and
  nowhere else: the aggregate output of the model can look reasonable while a schedule is
  read one cell out.

  Each observed curve is also stored in the same form as its input, cumulative against a
  cumulative input and survival against a survival schedule, so that the graph window can
  draw the two on one chart.
  ---------------------------------------------------------------------------------- }
	procedure resetFertilityCounts;
	{once at the start of a run, for everything}
	var
		i: longint;
	begin
		for i := kMinAgeFert to kMaxAgeFert do gCount_ageSterile [i] := 0;
		for i := 0 to kMaxAgeFert do begin
			gCount_conceptions [i] := 0;
			gCount_intrauterine_byAge [i] := 0;
			gCount_stillbirth_byAge [i] := 0;
		end;
		gHasObserved_definitive_sterility := false;
		gHasObserved_intrauterine_risk := false;
		gHasObserved_stillbirth_risk := false;
		gCountSimulationSettings := 0;
		resetFertilityCountsThisSetting;
		gCountSimulationSettings := 0;			{the first setting counts itself when it starts}
	end;

	procedure resetFertilityCountsThisSetting;
	{At the start of each simulation setting, for the quantities the demographic regime defines:
	 the amenorrhea schedule, the distribution of the month a pregnancy is lost, the waiting time
	 of the spacing contraception and the proportion female at birth. A sweep and a run of several
	 cohorts simulate several settings, and a histogram pooled over settings that were given
	 different inputs cannot be read against any one of them. The other counters are left alone:
	 the tables behind them are the same in every setting, so pooling makes them more precise.}
	var
		i, k: longint;
		aSex: Sex;
	begin
		for i := 0 to kMaxMonthTemporarySterility do gCount_amenorrhea [i] := 0;
		for i := 0 to 8 do gCount_intrauterine_month [i] := 0;
		for i := 0 to kMaxIndBirthIntervals do
			for k := 0 to kMaxDurationContraceptionInBirthIntervals do gCount_spacing [i, k] := 0;
		for aSex := low (Sex) to high (Sex) do gCount_birthsBySex [aSex] := 0;
		gHasObserved_temporary_sterility := false;
		gHasObserved_distrib_intrauterine := false;
		Inc (gCountSimulationSettings);
	end;

	procedure reportFertilityChecks (pDemReg: pStructDemographicRegimeSettings);
	var
		i, k, k2, parity, n: longint;
		theoretical: array [0..kMaxDurationContraceptionInBirthIntervals] of double;
		counts: array [0..kMaxDurationContraceptionInBirthIntervals] of longint;
		total, running, propWomen, expected, standardError: double;
		nConceptions, nAbortions, nStillbirths: double;
		expectedAbortion, expectedStillbirth: double;
	begin
		{what the run actually drew, so that a check with nothing to compare says why}
		n := 0;
		for i := kMinAgeFert to kMaxAgeFert do n := n + gCount_ageSterile [i];
		k := 0;
		for i := 0 to kMaxMonthTemporarySterility do k := k + gCount_amenorrhea [i];
		parity := 0;
		for i := 0 to 8 do parity := parity + gCount_intrauterine_month [i];
		total := 0;
		for i := 1 to kMaxIndBirthIntervals do
			for k2 := 0 to kMaxDurationContraceptionInBirthIntervals do
				total := total + gCount_spacing [i, k2];
		memoWriteLn (['Draws counted this run: ', n, ' ages at sterility, ', k, ' amenorrhea, ',
					parity, ' pregnancy losses, ', round (total), ' spacing spells, ',
					gCount_birthsBySex [woman] + gCount_birthsBySex [man], ' live births']);
		if (gCountSimulationSettings > 1) then
			memoWriteLn ([gCountSimulationSettings, ' simulation settings ran. The amenorrhea, the month ',
						'a pregnancy is lost, the spacing and the sex ratio are counted for the last of them ',
						'alone, since the regime defines them and they differ between settings. The age at ',
						'sterility, the fecundability, the intrauterine risk and the stillbirth risk are ',
						'counted over the whole run, their inputs being the same in every setting.']);

		{Age at onset of sterility, against the cumulative risk the draw reads}
		n := 0;
		for i := kMinAgeFert to kMaxAgeFert do begin
			counts [i - kMinAgeFert] := gCount_ageSterile [i];
			n := n + gCount_ageSterile [i];
			if (i = kMinAgeFert) then
				theoretical [0] := gDefinitive_sterility [i]
			else
				theoretical [i - kMinAgeFert] := gDefinitive_sterility [i] - gDefinitive_sterility [i-1];
		end;
		if (n > 0) then begin
			checkDistribution (chk_fer_ageAtSterility, slice (counts, kMaxAgeFert - kMinAgeFert + 1),
					slice (theoretical, kMaxAgeFert - kMinAgeFert + 1));
			running := 0.0;
			for i := 0 to kMinAgeFert - 1 do gObserved_definitive_sterility [i] := 0.0;
			for i := kMinAgeFert to kMaxAgeFert do begin
				running := running + gCount_ageSterile [i] / n;
				gObserved_definitive_sterility [i] := running;
			end;
			gHasObserved_definitive_sterility := true;
		end;

		{Amenorrhea after a live birth, against the schedule of temporary sterility}
		n := 0;
		for i := 0 to kMaxMonthTemporarySterility do begin
			counts [i] := gCount_amenorrhea [i];
			n := n + gCount_amenorrhea [i];
			if (i = 0) then
				theoretical [0] := 1.0 - pDemReg^.temporary_sterility [0]
			else
				theoretical [i] := pDemReg^.temporary_sterility [i-1] - pDemReg^.temporary_sterility [i];
		end;
		if (n > 0) then begin
			checkDistribution (chk_fer_amenorrhea, slice (counts, kMaxMonthTemporarySterility + 1),
					slice (theoretical, kMaxMonthTemporarySterility + 1));
			running := 1.0;
			for i := 0 to kMaxMonthTemporarySterility do begin
				running := running - gCount_amenorrhea [i] / n;
				gObserved_temporary_sterility [i] := max (0.0, running);
			end;
			gHasObserved_temporary_sterility := true;
		end;

		{Month at which a pregnancy is lost, against Barrett's distribution}
		n := 0;
		for i := 0 to 8 do begin
			counts [i] := gCount_intrauterine_month [i];
			n := n + gCount_intrauterine_month [i];
			if (i <= 1) then
				theoretical [i] := gDistrib_intrauterine_mortality_risk [i]
			else
				theoretical [i] := gDistrib_intrauterine_mortality_risk [i] - gDistrib_intrauterine_mortality_risk [i-1];
		end;
		if (n > 0) then begin
			checkDistribution (chk_fer_intrauterineMonth, slice (counts, 9), slice (theoretical, 9));
			running := 0.0;
			for i := 0 to 8 do begin
				running := running + gCount_intrauterine_month [i] / n;
				gObserved_distrib_intrauterine [i] := running;
			end;
			gHasObserved_distrib_intrauterine := true;
		end;

		{The outcome of a conception, against the two risk schedules it is drawn from. Both are
		 read on one uniform draw, the abortion below gIntrauterine_mortality_risk and the
		 stillbirth in the band above it, so each age carries the risk its schedule states. The
		 curves are risks by age, for the chart; the check is on the two pooled proportions,
		 against the risk expected from the ages at which the conceptions actually occurred,
		 which is what makes one number out of fifty.}
		nConceptions := 0.0; nAbortions := 0.0; nStillbirths := 0.0;
		for i := 0 to kMaxAgeFert do begin
			nConceptions := nConceptions + gCount_conceptions [i];
			nAbortions := nAbortions + gCount_intrauterine_byAge [i];
			nStillbirths := nStillbirths + gCount_stillbirth_byAge [i];
		end;
		if (nConceptions > 0) then begin
			expectedAbortion := 0.0;
			expectedStillbirth := 0.0;
			for i := 0 to kMaxAgeFert do begin
				if (gCount_conceptions [i] > 0) then begin
					gObserved_intrauterine_risk [i] := gCount_intrauterine_byAge [i] / gCount_conceptions [i];
					gObserved_stillbirth_risk [i] := gCount_stillbirth_byAge [i] / gCount_conceptions [i];
				end else begin
					gObserved_intrauterine_risk [i] := 0.0;
					gObserved_stillbirth_risk [i] := 0.0;
				end;
				expectedAbortion := expectedAbortion + gCount_conceptions [i] * gIntrauterine_mortality_risk [i];
				expectedStillbirth := expectedStillbirth + gCount_conceptions [i] * gStillbirth_mortality_risk [i];
			end;
			expectedAbortion := expectedAbortion / nConceptions;
			expectedStillbirth := expectedStillbirth / nConceptions;
			gHasObserved_intrauterine_risk := true;
			gHasObserved_stillbirth_risk := true;

			standardError := sqrt (max (1e-12, expectedAbortion * (1.0 - expectedAbortion) / nConceptions));
			checkValue (chk_fer_intrauterineRisk, nAbortions / nConceptions, expectedAbortion, 4.0 * standardError);

			standardError := sqrt (max (1e-12, expectedStillbirth * (1.0 - expectedStillbirth) / nConceptions));
			checkValue (chk_fer_stillbirthRisk, nStillbirths / nConceptions, expectedStillbirth, 4.0 * standardError);

			memoWriteLn (['Conceptions: ', round (nConceptions), ', of which ', round (nAbortions),
						' ended in a spontaneous abortion and ', round (nStillbirths), ' in a stillbirth']);
		end;

		{Spacing contraception, one distribution per birth interval. Parity 0 is left out: the
		 two calls made before the first birth read two different inputs and would be pooled.}
		for parity := 1 to kMaxIndBirthIntervals do begin
			n := 0;
			for k := 0 to kMaxDurationContraceptionInBirthIntervals do begin
				counts [k] := gCount_spacing [parity, k];
				n := n + counts [k];
				if (k = 0) then
					theoretical [0] := pDemReg^.AccDurationWaitingTime [parity] [0]
				else
					theoretical [k] := pDemReg^.AccDurationWaitingTime [parity] [k] -
										pDemReg^.AccDurationWaitingTime [parity] [k-1];
			end;
			if (n > 0) then begin
				checkDistribution (chk_fer_spacingContraception,
						slice (counts, kMaxDurationContraceptionInBirthIntervals + 1),
						slice (theoretical, kMaxDurationContraceptionInBirthIntervals + 1));
				running := 0.0;
				for k := 0 to kMaxDurationContraceptionInBirthIntervals do begin
					running := running + counts [k] / n;
					gObserved_spacing [parity, k] := running;
				end;
			end;
		end;

		{Sex ratio at birth, against the proportion female the regime was given}
		total := gCount_birthsBySex [woman] + gCount_birthsBySex [man];
		if (total > 0) then begin
			propWomen := gCount_birthsBySex [woman] / total;
			expected := pDemReg^.dp[propWomenAtBirth].value;
			standardError := sqrt (expected * (1.0 - expected) / total);
			checkValue (chk_fer_sexRatioAtBirth, propWomen, expected, 4.0 * standardError);
			memoWriteLn (['Proportion female at birth: simulated ', propWomen, ', asked for ', expected,
						', over ', round (total), ' births']);
		end;
	end;

	procedure writeGeneralTables (objOutputFert: TOutputFertility);
	var
		ageAtUnion: ageQuinq;
		i, j: longint;
		n: longint;
	begin
		{Total fertility according to age at first union and level of parameters for postpartum amenorrhea}
		{First we determine how many levels to write}
		if writeResults (res_fert_ageFirstUnion) then
			begin
			aWriteLn (gOutFileFec, ['### Total fertility and age at first union (option ' + g_GENPARAM.outputs_opt[res_fert_ageFirstUnion].name + ')']);
			n := 1;
			while ( objOutputFert.TOT_descFinaleAgeUnion[f1519, 1, n + 1] <> 0 ) do
				Inc ( n );
		
			for j := 1 to n do
			begin
				aWrite (gOutFileFec, ['Age', tab]);
				for i := 0 to kMaxNbChildren do
					aWrite (gOutFileFec, [i, tab]);
				aWriteLn (gOutFileFec, ['']);
				for ageAtUnion := f1519 to f4549 do
				begin
					aWrite (gOutFileFec, [ageQuinqToStr (ageAtUnion), tab]);
					for i := 0 to kMaxNbChildren do
						aWrite (gOutFileFec, [objOutputFert.TOT_descFinaleAgeUnion[ageAtUnion, i, j], tab]);
					aWriteLn (gOutFileFec, ['']);
				end;
			end;
		end;
	end;
		
	{============ OUTPUT FILE NAME AND HEADER ============}
	function outputFileNameHeader (bootstrap_ind: longint; pDemReg: pStructDemographicRegimeSettings; openFiles: boolean): boolean;
	var
			fileName: string;
			resultat: boolean;
			ind: longint;
			WriteExtendedHeader: boolean = false; // lot of not very useful things // obsolete
			label error;
	begin
		resultat := false;
		
		fileName := g_FileName.value;
		
		if (NOT g_GENPARAM.OUTPUT_SHORTFILENAME.value) then begin
		   // OBSOLETE: when having a filename with information on options was meaningful (a long time ago...)
			if g_GENPARAM.fixedParameters [stdUnionDanielOrCampbellWood].state.value then
			begin
				fileName := fileName + 'MDan_';
			end else begin
				fileName := fileName + 'MCW_';
			end;
		
			if pDemReg^.dp[meanTimeContraceptionAfterUnionHigh].value > 0.0 then
				fileName := fileName + cStringOf (['MContAfterUnion_', pDemReg^.dp[meanTimeContraceptionAfterUnionHigh].value]);
		
			if pDemReg^.dp[freqSeparation].value > 0.0 then
				fileName := fileName + cStringOf (['Sep_', pDemReg^.dp[freqSeparation].value]);
			
			if pDemReg^.dp[repartnering_men_par].value > 0.0 then
				fileName := fileName + cStringOf (['_RM_', pDemReg^.dp[repartnering_men_par].value, '_', pDemReg^.dp[repartnering_women_par].value]);
		
			fileName := fileName + cStringOf ([
										'_nStepsUnionMean_', g_GENPARAM.RUNTIME[nStepsUnion_mean].value,
										'_nStepsUnionProp_', g_GENPARAM.RUNTIME[nStepsUnion_prop].value,
										'_nStepsUnion_Dev_', g_GENPARAM.RUNTIME[nStepsUnion_Dev].value,
										'_nStepsContrFert_', g_GENPARAM.RUNTIME[nStepsContrFert].value,
										'_nStepsAmeno_', g_GENPARAM.RUNTIME[nStepsAmeno].value,
										'_nStepsSeparation_', g_GENPARAM.RUNTIME[nStepsSeparation].value,
										'_nStepsContrUseAfterUnion_', g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value
									]);
		end;
		
		if g_GENPARAM.FERTILITY.value and openFiles and not g_silentMode then
			if not initSpecificFileOut( fileName, bootstrap_ind ) then
				goto error;
		
		if 	g_GENPARAM.KINSHIP.value and openFiles then
			if not initAggrKinshipFile ( fileName, true, bootstrap_ind ) then
				goto error;
			
		{First line in case there are steps}
		ind :=
			g_GENPARAM.RUNTIME[nStepsUnion_prop].value *
			g_GENPARAM.RUNTIME[nStepsUnion_Dev].value *
			g_GENPARAM.RUNTIME[nStepsAmeno].value *
			g_GENPARAM.RUNTIME[nStepsContrFert].value *
			g_GENPARAM.RUNTIME[nStepsSeparation].value *
			g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value;
		
		if (ind > 1) then
			aWriteLnAll (cStringOf ([
									ind,
									tab, g_GENPARAM.RUNTIME[nStepsUnion_mean].value, tab]));
		
		{Date and Time}
		aWriteLnAll (dateAndTime());

		if WriteExtendedHeader then begin // obsolete
			if g_GENPARAM.fixedParameters [stdUnionDanielOrCampbellWood].state.value then
				fileName := ' STD UNION DANIEL'
			else
				fileName := ' STD UNION CAMPBELL AND WOOD';
	
			aWriteLnAll (fileName);

			info_FixParameter ();
	
			aWriteLnAll ( cStringOf (['MContrAfterUnionMax_', tab, pDemReg^.dp[meanTimeContraceptionAfterUnionHigh].value]) );
	
			aWriteLnAll ( cStringOf (['SeparationMax', tab, pDemReg^.dp[freqSeparation].value]) );
		
			aWriteLnAll ( cStringOf (['Repartnering men', tab, pDemReg^.dp[repartnering_men_par].value, tab, 'women', tab, pDemReg^.dp[repartnering_women_par].value]) );		

			aWriteLnAll ( cStringOf (['nStepsUnionMean', tab, g_GENPARAM.RUNTIME[nStepsUnion_mean].value]) );
			aWriteLnAll ( cStringOf (['nStepsUnionProp', tab, g_GENPARAM.RUNTIME[nStepsUnion_prop].value]) );
			aWriteLnAll ( cStringOf (['nStepsUnion_Dev', tab, g_GENPARAM.RUNTIME[nStepsUnion_Dev].value]) );
			aWriteLnAll ( cStringOf (['nStepsContrFert', tab, g_GENPARAM.RUNTIME[nStepsContrFert].value]) );
			aWriteLnAll ( cStringOf (['nStepsAmeno', tab, g_GENPARAM.RUNTIME[nStepsAmeno].value]) );
			aWriteLnAll ( cStringOf (['nStepsSeparation', tab, g_GENPARAM.RUNTIME[nStepsSeparation].value]) );
			aWriteLnAll ( cStringOf (['nStepsContrUseAfterUnion', tab, g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value]) );
		
		end;
		
		resultat := true;
		error:
		
		outputFileNameHeader := resultat;
		
	end;
	
	procedure MessSeparation (pRP: pRunParamRec; pDemReg: pStructDemographicRegimeSettings);
	begin
			aWriteLnAll (cStringOf (['freqSeparation', tab, pDemReg^.separationInfo.freqSeparation]));
	end;
	
	procedure MessAmeno (pRP: pRunParamRec; pDemReg: pStructDemographicRegimeSettings);
	begin
		if ( g_GENPARAM.RUNTIME[nStepsAmeno].value > 1 ) then begin
			aWriteLnAll ( cStringOf (['amenorrhea alpha:', tab, pDemReg^.dp[amenorrhea_alpha].value + 2.4 * (pRP^.indFertAmeno-1) / (g_GENPARAM.RUNTIME[nStepsAmeno].value-1)]) );
		end else begin
			aWriteLnAll ( cStringOf (['amenorrhea alpha:', tab, pDemReg^.dp[amenorrhea_alpha].value]) );
		end;
		aWriteLnAll ( cStringOf (['amenorrhea beta:', tab, pDemReg^.dp[amenorrhea_beta].value]) );
	end;
	
	procedure MessControlFec (pDemReg: pStructDemographicRegimeSettings);
		var
			ind: longint;
	begin
		if not g_GENPARAM.FERTILITY.value or not g_silentMode then exit;

		aWriteLn (gOutFilePPR, ['A priori PPR']);
		for ind := 0 to kMaxNbChildrenCalc do
			aWrite (gOutFilePPR, [ind, tab]);
		aWriteLn (gOutFilePPR, [tab]);
		for ind := 0 to kMaxNbChildrenCalc do
			aWrite (gOutFilePPR, [pDemReg^.aPrioriPPR.value[ind], tab]);
		aWriteLn (gOutFilePPR, [tab]);
		aWriteLn (gOutFilePPR, ['A priori PPR - ADJUSTED']);
		for ind := 0 to kMaxNbChildrenCalc do
			aWrite (gOutFilePPR, [ind, tab]);
		aWriteLn (gOutFilePPR, [tab]);
		for ind := 0 to kMaxNbChildrenCalc do
			aWrite (gOutFilePPR, [pDemReg^.curr_contracepStopping[ind], tab]);
		aWriteLn (gOutFilePPR, [tab]);
	end;
	
	procedure MessCelibacy (pRP: pRunParamRec);
	begin
	end;
	
	procedure MessTimeControlFecInUnion (pRP: pRunParamRec; pDemReg: pStructDemographicRegimeSettings);
	begin
		aWriteLnAll (cStringOf (['MeanTimeContraceptionAfterUnion', tab, pDemReg^.MeanTimeContraceptionAfterUnion]));
	end;

	procedure checkStepsAndStablePopulation;
	begin
		if not StablePopulation() or g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value then begin
		// Steps are allowed only for stable population simulation
		// or non bootstrapping
			g_GENPARAM.RUNTIME[nStepsUnion_mean].value := 1;
			g_GENPARAM.RUNTIME[nStepsUnion_prop].value := 1;
			g_GENPARAM.RUNTIME[nStepsUnion_Dev].value := 1;
			g_GENPARAM.RUNTIME[nStepsAmeno].value := 1;
			g_GENPARAM.RUNTIME[nStepsContrFert].value := 1;
			g_GENPARAM.RUNTIME[nStepsSeparation].value := 1;
			g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value := 1;
		end;
	end;

	procedure RunHeader (pRP: pRunParamRec; pDemReg: pStructDemographicRegimeSettings);
	var
		mess: string;
		finalWrite: boolean = FALSE;
		WriteExtendedHeader: boolean = false; // obsolete
		UseSteps: boolean = false;
		
	begin
		UseSteps := (
					g_GENPARAM.RUNTIME[nStepsUnion_mean].value +
					g_GENPARAM.RUNTIME[nStepsUnion_prop].value +
					g_GENPARAM.RUNTIME[nStepsUnion_Dev].value +
 					g_GENPARAM.RUNTIME[nStepsContrFert].value +
					g_GENPARAM.RUNTIME[nStepsSeparation].value +
					g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value +
					g_GENPARAM.RUNTIME[nStepsAmeno].value > 7 );
 
		mess := g_fileName.value;
		
		if UseSteps then
			mess := mess		+ cStringOf ([pRP^.indAgeUnion]) + '$'
								+ cStringOf ([pRP^.indCelibacy]) + '$'
								+ cStringOf ([pRP^.indStdCel]) + '$'
								+ cStringOf ([pRP^.indFertControl]) + '$'
								+ cStringOf ([pRP^.indFertSeparation]) + '$'
								+ cStringOf ([pRP^.indFertContrUseAfterUnion]) + '$'
								+ cStringOf ([pRP^.indFertAmeno])
								+ tab
								+ 'GenFertVar e0=' + cStringOf ([pDemReg^.dp[e0_women].value])  + tab
								+ 'AgeUnion' + tab + cStringOf ([pRP^.indAgeUnion]) + tab
								+ 'EverInUnion' + tab + cStringOf ([pRP^.indCelibacy]) + tab
								+ 'StdUnion' + tab + cStringOf ([pRP^.indStdCel]) + tab
								+ 'FertCont' + tab + cStringOf ([pRP^.indFertControl]) + tab
								+ 'PropSep' + tab + cStringOf ([pRP^.indFertSeparation]) + tab
								+ 'FertContUnion' + tab + cStringOf ([pRP^.indFertContrUseAfterUnion]) + tab
								+ 'Ameno' + tab + cStringOf ([pRP^.indFertAmeno])
								;
								
		aWriteLnAll (mess);
		
		mess := cStringOf (['Year of birth: ', pDemReg^.yearOfBirth.value]);
		aWriteLnAll (mess);

		if WriteExtendedHeader then begin // obsolete
			if (g_GENPARAM.RUNTIME[nStepsUnion_mean].value + g_GENPARAM.RUNTIME[nStepsUnion_prop].value + g_GENPARAM.RUNTIME[nStepsUnion_Dev].value > 3) then begin
				mess := 'Variable celibacy, ';
			end else begin
				mess := 'Fixed celibacy, ';
			end;
			mess := mess + 'e0=' + doubleToMinStringHelper (pDemReg^.dp[e0_women].value);
			screenFileWriteLn(mess);
									
			mess := 'Rodriguez and Trussell''s parameters: ';
			screenFileWriteLn(mess);
			aWriteLnAll (mess);
									
			mess := cStringOf (['freqFin_Cel ', tab, pDemReg^.pCurrUnionInfo^.unionParam [woman, freqFinUnion], tab,
										'mean ', tab, pDemReg^.pCurrUnionInfo^.unionParam [woman, meanUnion], tab,
										'std ', tab, pDemReg^.pCurrUnionInfo^.unionParam [woman, stdUnion]]);
			screenFileWriteLn
			(mess);
			aWriteLnAll (mess);
		
			MessSeparation (pRP, pDemReg);
			MessTimeControlFecInUnion (pRP, pDemReg);
			MessAmeno (pRP, pDemReg);
		end;
		

		screenFileWriteLn('');
		screenFileWriteLn('============================================');
		mess := '';
		if ( g_GENPARAM.RUNTIME[nStepsUnion_mean].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==indAgeUnion step ';
			mess := mess + IntToStr(pRP^.indAgeUnion);
		end;
		if ( g_GENPARAM.RUNTIME[nStepsUnion_prop].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==indSinglewood step ';
			mess := mess + IntToStr(pRP^.indCelibacy);
		end;
		if ( g_GENPARAM.RUNTIME[nStepsUnion_Dev].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==StdCel step ';
			mess := mess + IntToStr(pRP^.indStdCel);
		end;
		if ( g_GENPARAM.RUNTIME[nStepsContrFert].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==Fertility control step ';
			mess := mess + IntToStr(pRP^.indFertControl);
		end;
		if ( g_GENPARAM.RUNTIME[nStepsSeparation].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==Separation step ';
			mess := mess + IntToStr(pRP^.indFertSeparation);
		end;
		if ( g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==Fertility control after first union step ';
			mess := mess + IntToStr(pRP^.indFertContrUseAfterUnion);
		end;
		if ( g_GENPARAM.RUNTIME[nStepsAmeno].value > 1 ) then begin
			finalWrite := TRUE;
			mess := mess + '==Amenorrhea step ';
			mess := mess + IntToStr(pRP^.indFertAmeno);
		end;
		if finalWrite then begin
			screenFileWriteLn (mess);
			screenFileWriteLn('============================================');
		end;

		
	end;

{when we enter this procedure, the pointer to DemographicRegimeSettings refers to the woman birth cohort, so we need to change it to compute man age at death}
	function InitPartnershipLife (
									randomGenerator: TRandomNumberGenerator;
									pDemReg: pStructDemographicRegimeSettings;
									deathWoman, deathMan: boolean;
									fecundLife: FecundLifeType;
									var ageDurationEvents: UnionAgeDurationsType): boolean;
	var
		dummy: double = 0;
		cohort_man: longint;
		mem_ages, mem_ages2, mem_ages3: TabAgeEvents;

	begin
		result := true;
		
if gRunFromIDE then
	move (ageDurationEvents.ages, mem_ages{%H-}, sizeOf(mem_ages));

		{woman's age at first union}
		ageDurationEvents.ages[le_union, woman] := max ( kMinAgeUnion, ageDurationEvents.ages[le_union, woman] );

if (ageDurationEvents.ages[le_union, woman] > 75) then
	writeAndWait ('ERROR ==> ageDurationEvents.ages[le_union, woman] greater than 75 in initPartnershipLife');

try // 1
		{Age at union of man (we don't know whether this is a first union, as we do not have the past history of the man, before this union)}
		if ageDurationEvents.ages[le_union, man] = kNotDefined then
		begin
			dummy := randomGenerator.alea0;
			ageDurationEvents.ages[le_union, man] := kMinAgeUnion_men;
			while dummy > pDemReg^.pCurrUnionInfo^.union_women_men[trunc (ageDurationEvents.ages[le_union, woman]), aggregated, trunc (ageDurationEvents.ages[le_union, man])] do
			begin
				ageDurationEvents.ages[le_union, man] := ageDurationEvents.ages[le_union, man] + 1;
			end;
			{Month of the man's age at union}
			{ages at union are at midyear, so we subtract 0.5}
			ageDurationEvents.ages[le_union, man] := max (kMinAgeUnion, ageDurationEvents.ages[le_union, man] + randomGenerator.alea(0.0, 0.99999999) - 0.5 );
		end;

if gRunFromIDE then
	move (ageDurationEvents.ages, mem_ages2{%H-}, sizeOf(mem_ages));

		{Age at death of the man}
		{age at death are NOT at midyear}
		if deathMan and (ageDurationEvents.ages[le_death, man] = kNotDefined) then
		begin
			{Year of death of man}
			cohort_man := pDemReg^.yearOfBirth.value - trunc (ageDurationEvents.ages[le_union, man] - ageDurationEvents.ages[le_union, woman]);
			ageDurationEvents.ages[le_death, man] := max (ageDurationEvents.ages[le_union, man] + 0.1,
					calc_ageDeath(randomGenerator, trunc (ageDurationEvents.ages[le_union, man]), getCohort_p(cohort_man)^.mortalityInfo.survival_men, man)
				);
			if g_GENPARAM.FIXED_FERTILITY.value and (ageDurationEvents.ages[le_death, man] < 40) then
				ageDurationEvents.ages[le_death, man] := 40;
		end;
{Age at death of the woman}
{age at death are NOT at midyear}
		if deathWoman then
		begin
			{age at death of the woman}
			if ageDurationEvents.ages[le_death, woman] = kNotDefined then begin
				ageDurationEvents.ages[le_death, woman] := max (ageDurationEvents.ages[le_union, woman] + 0.1,
						calc_ageDeath(randomGenerator, trunc (ageDurationEvents.ages[le_union, woman]), pDemReg^.mortalityInfo.survival_women, woman)
					);
			if g_GENPARAM.FIXED_FERTILITY.value and (ageDurationEvents.ages[le_death, woman] < 40) then
				ageDurationEvents.ages[le_death, woman] := 40;
			end;
if gRunFromIDE then
	move (ageDurationEvents.ages, mem_ages3{%H-}, sizeOf(mem_ages));
		end;

		if	(ageDurationEvents.ages[le_union, woman] <> kNotDefined) and (ageDurationEvents.ages[le_death, woman] <> kNotDefined) and
			(ageDurationEvents.ages[le_union, woman] > ageDurationEvents.ages[le_death, woman]) then
			exit (false);
		if	(ageDurationEvents.ages[le_union, man] <> kNotDefined) and (ageDurationEvents.ages[le_death, man] <> kNotDefined) and
			(ageDurationEvents.ages[le_union, man] > ageDurationEvents.ages[le_death, man]) then
			exit (false);

{Duration of the fertile period}
		ageDurationEvents.durations.durationFecundInMonths := max ( 0, ageToLunarMonths (fecundLife.ageSterile - ageDurationEvents.ages[le_union, woman]) );
{Duration of life of the woman after union}
		if deathWoman then
			begin
				ageDurationEvents.durations.durationAliveWoman := ageToLunarMonths (ageDurationEvents.ages[le_death, woman] - ageDurationEvents.ages[le_union, woman]);
				ageDurationEvents.durations.durationAliveWoman := ageDurationEvents.durations.durationAliveWoman - kLivingBirth_durationPregnancyInMonths; {pregnancy time is taken into account}
			end
		else
			ageDurationEvents.durations.durationAliveWoman := ageToLunarMonths (kMaxAgeLife+1 - ageDurationEvents.ages[le_union, woman]);
{Duration of life of the man after union}
		if deathMan then
			begin
				ageDurationEvents.durations.durationAliveMan := ageToLunarMonths (ageDurationEvents.ages[le_death, man] - ageDurationEvents.ages[le_union, man]);
			end
		else
			ageDurationEvents.durations.durationAliveMan := ageToLunarMonths (kMaxAgeLife+1 - ageDurationEvents.ages[le_union, man]);
{Duration of union in months}
		if deathWoman and deathMan then begin
			ageDurationEvents.durations.durationUnionInMonths := min(ageDurationEvents.durations.durationAliveMan, ageDurationEvents.durations.durationAliveWoman);
		end else if deathMan then begin
			ageDurationEvents.durations.durationUnionInMonths := ageDurationEvents.durations.durationAliveMan;
		end else begin
			ageDurationEvents.durations.durationUnionInMonths := ageDurationEvents.durations.durationAliveWoman;
		end;
		
		if ageDurationEvents.durations.durationUnionInMonths < 0 then
			ageDurationEvents.durations.durationUnionInMonths := 0;

except // 1
on E: Exception do begin
		writeAndWaitConst(['===> ERROR: ', E.Message]);
breakOnFailure;
	end;
end;

	end;
	
	function calcAgeFatherAtChildbirth (ageMotherAtChildbirth: double; currUnion: longint; unionStates: TUnionsType): double;
	begin
		with unionStates.Unions [currUnion - 1] do
			result := ageMotherAtChildbirth + ages [le_union, man] - ages [le_union, woman];
	end;
	
	function calcStartInterval (pCurrChild: pInfoChildType; monthStart: longint): longint;
	begin
		if pCurrChild^.previous = nil then
			// first conception
			result := monthStart
		else if pCurrChild^.motherUnionNumber = pCurrChild^.previous^.motherUnionNumber then
			// there is a previous conception in the same union
			result := pCurrChild^.previous^.monthEndPregnancy
		else
			// there is a previous conception but in a previous union, se we use the start of current union
			result := monthStart;
	end;

	procedure addChild (age: FecundAges; order: DistribChildrenCalc; number: longint; var ageChildren: TabCompFertAge);
	begin
		ageChildren[age, 0] := ageChildren[age, 0] + number;
		ageChildren[age, order] := ageChildren[age, order] + number;
	end;
				
	function fixedNumChildren (
							randomGenerator: TRandomNumberGenerator;							
							pDemReg: pStructDemographicRegimeSettings;
							var unionStates: TUnionsType;
							var ageChildren: TabCompFertAge;
							var pChild: pInfoChildType;
							var fecundLife: FecundLifeType;
							objOutputFert: TOutputFertility;
							var arrayPartners: ArrayOfPersonMemoryBlock
							): longint;
	var
		indChild: longint;
		monthStart, currMonth: longint;
	begin
		fixedNumChildren := g_FIXED_FERTILITY_DATA.nbChildren;
		
		unionStates.nbUnions := 1;
		unionStates.Unions [0].ages[le_union, woman] := g_FIXED_FERTILITY_DATA.ageUnionWoman;
		if unionStates.Unions [0].ages[le_endUnion, woman] = kNotDefined then
			unionStates.Unions [0].ages[le_endUnion, woman] := g_FIXED_FERTILITY_DATA.ageEndUnionWoman;
		unionStates.Unions [0].ages[le_union, man] := g_FIXED_FERTILITY_DATA.ageUnionMan;
		unionStates.partnershipStatusAt50 := firstUnion;
		unionStates.nbChildren := g_FIXED_FERTILITY_DATA.nbChildren;
		fecundLife.ageSterile := 55;
		for indChild := 1 to unionStates.nbChildren do begin
			addChild (trunc (g_FIXED_FERTILITY_DATA.ageFert [indChild-1]), indChild, 1, ageChildren);

			newChild (pChild);

			with pChild^ do
			begin
				livingAtBirth := true;
				sex := sexAtBirth(randomGenerator, pDemReg, 0);
				birthOrder := indChild;
				yearBirth := kNotDefined;
				motherUnionNumber := unionStates.nbUnions;
				ageMotherAtFecundation := g_FIXED_FERTILITY_DATA.ageFert [indChild-1] - kLivingBirth_durationPregnancyInMonths / 12;
				ageMotherAtChildbirth := g_FIXED_FERTILITY_DATA.ageFert [indChild-1];
				ageFatherAtChildbirth := calcAgeFatherAtChildbirth (ageMotherAtChildbirth, 1, unionStates);
				if sex = man then
					ageDeath := calc_ageDeath(randomGenerator, 0, pDemReg^.mortalityInfo.survival_men, man)
				else
					ageDeath := calc_ageDeath(randomGenerator, 0, pDemReg^.mortalityInfo.survival_women, woman);

				{date ---}
				monthStart := trunc (unionStates.Unions [0].ages[le_union, woman] * 12);
				currMonth := trunc (ageMotherAtChildbirth * 12);
				durationUnion := currMonth - monthStart + kLivingBirth_durationPregnancyInMonths;
				deathChildSinceBirthOfMotherInMonths := ageToLunarMonths (ageDeath + ageMotherAtChildbirth);
				monthStartInterval := calcStartInterval (pChild, monthStart);
				monthFecundation := kNotDefined;
				monthEndPregnancy := currMonth + kLivingBirth_durationPregnancyInMonths;
				monthNewOvulation := kNotDefined;
			end;
		end;
	end;

{Reproductive life of a woman: simulate all the offsprings of a woman who enter a union at age param_ageUnion.
If param_currentUnionNumber is equal to 1, then this will be the first union for the woman and she had no
previous child (pChild will be set to nil and ageChildren table will be zeroed)}
{unionStates should have been initialised before calling that function and may contain values like age of woman at death,
or age at union and at death for previous partners}
{if param_deathWoman is TRUE, we take into account the age at woman's death which interrupts her reproductive life}
{CHECK THAT IT REALLY WORKS WITH deathWoman TRUE... AS WE MADE MANY CHANGES SINCE}
{if param_deathMan is TRUE, the age at death of the man (or the men if there are second unions) is taken into account}
{The function returns the number of children born to that woman.
Other results are man's (men if there are various partners) age at union and death (if not set beforehand),
ages at childbearing as well as a linked list with info on each child.
FecundLife (age at sterility, relative level of fecundability, etc.) will also be obtained as result if the fertility life
is created anew, but if param_newPartnershipLife is FALSE, then FecundLife parameters are specified beforehand
isThreaded is true if the function is called from a parallel thread,
which will prevent some things, like the use of the time profiler as well as writing to files or to the screen
}
	function calcCompleteFertilityWoman (
							randomGenerator: TRandomNumberGenerator;							
							pDemReg: pStructDemographicRegimeSettings;
							param_deathWoman, param_deathMan: boolean;
							param_ageUnion: double;
							param_currentUnionNumber: longint;
							var unionStates: TUnionsType;
							var ageChildren: TabCompFertAge;
							var pChild: pInfoChildType;
							var fecundLife: FecundLifeType;
							objOutputFert: TOutputFertility;
							var arrayPartners: ArrayOfPersonMemoryBlock;
							useArrayGrooms: boolean = false;
							const arrayChildren: arrayOfInfoChild = nil;
							param_newPartnershipLife: boolean = true;
							isThreaded: boolean = false): longint;
	var
		currPartnershipStatus: PartnershipStatusesType;

		procedure calcNbChildren (	pDemReg: pStructDemographicRegimeSettings;
									currUnion: longint;
									var ageDurationEvents: UnionAgeDurationsType;
									var nbChildren: longint;
									var pCurrChild: pInfoChildType );
		{Number of children in current union}
		var
			aleaFecundability: double;
			fecundabilityThisCycle: double;	{RESHUFFLED_FECUNDABILITY}
			pPreviousChild: pInfoChildType;
			currAge: FecundAges;
			ageThisCycle: longint;	{the age at the current cycle, before it is tested and
									 brought inside the bounds of FecundAges}
			{monthStart, monthEnd and currMonth count lunar months since the woman's birth,
			 so lunarMonthsToAge turns any of them into an age}
			monthStart, monthEnd, currMonth: longint;
			monthsElapsed: longint;	{months already applied out of the current monthIncrement}
			monthIncrement: longint = 0;
			nbPregnanciesInCurrentUnion: longint;
			
			testStopping: boolean;
			endUnion: boolean;

			procedure paramSeparation (monthOfSeparation: longint);
			var
				durationUnionWoman: double;
			begin
			{DEBUG: CHECK CURRMONTH COUNT SINCE BIRTH}
				endUnion := true;
				ageDurationEvents.ages[le_endUnion, woman] := lunarMonthsToAge (monthOfSeparation);
				currPartnershipStatus := separated;
				// age at end of union for man is computed adding the duration of union
				durationUnionWoman := (ageDurationEvents.ages[le_endUnion, woman] - ageDurationEvents.ages[le_union, woman]);
				ageDurationEvents.ages[le_endUnion, man] := ageDurationEvents.ages[le_union, man] + durationUnionWoman;
				// we may have an incoherence with the man, who may have died before separation
				if ((ageDurationEvents.ages[le_death, man] > 0) and
					(ageDurationEvents.ages[le_death, man] < ageDurationEvents.ages[le_endUnion, man])
				) then begin
					ageDurationEvents.ages[le_endUnion, woman] := ageDurationEvents.ages[le_endUnion, woman] -
					(ageDurationEvents.ages[le_endUnion, man] - ageDurationEvents.ages[le_death, man]);
					ageDurationEvents.ages[le_endUnion, man] := ageDurationEvents.ages[le_death, man];
					currPartnershipStatus := widow;
				end;
				if ((ageDurationEvents.ages[le_death, woman] > 0) and
					(ageDurationEvents.ages[le_death, woman] < ageDurationEvents.ages[le_endUnion, woman])
				) then begin
					ageDurationEvents.ages[le_endUnion, woman] := ageDurationEvents.ages[le_death, woman];
				end;
				ageDurationEvents.durations.durationUnionInMonthsWithSeparation := monthOfSeparation - monthStart + 1;
				if (ageDurationEvents.durations.durationUnionInMonthsWithSeparation < ageDurationEvents.durations.durationUnionInMonths) then
					ageDurationEvents.durations.durationUnionInMonths := ageDurationEvents.durations.durationUnionInMonthsWithSeparation;
			end;

			function waiting_time_contraception (
							pDemReg: pStructDemographicRegimeSettings;
							const AccDurationContr: array of double;
							propContraception: double;
							monthEnd: longint;
							monthSpacingStarts: longint;
							testSeparationHere: boolean): longint;
			{Draws the length of a spell of contraceptive waiting and returns it as a count of
			 months. It does not move currMonth: the caller decides how the woman's clock
			 advances, which is what keeps the wait from being applied twice.
			 monthSpacingStarts is the month at which the waiting begins, on the same clock as
			 currMonth, so that the separation tests below fall on the right dates.

			 testSeparationHere says whether this routine is the one that applies the risk of
			 separation to the months it walks}
			var
				monthsOfContraception: longint;	{months of contraceptive waiting drawn in this call}
				intendedMonths: longint;		{the length before any interruption, for the check}
				monthNow: longint;				{running month inside the waiting, counted like currMonth}
				aleaContraception: double;
			begin
				waiting_time_contraception := 0;
				aleaContraception := randomGenerator.alea0;
				monthNow := monthSpacingStarts;
				if ( AccDurationContr [0] < 1.0 ) and ( aleaContraception < propContraception) and (monthNow <= monthEnd) then
				begin
					aleaContraception := randomGenerator.alea0;
					monthsOfContraception := 0;
					{The length this spell would have had if nothing interrupted it, which is what
					 the input distribution describes. The loop below stops early when the union
					 ends, when the woman stops, or when the fertile life is over, so the spells
					 actually lived are censored and cannot be read against the input directly.}
					intendedMonths := 0;
					while (intendedMonths < high (AccDurationContr)) and
							(aleaContraception > AccDurationContr [intendedMonths]) do
						Inc (intendedMonths);
					InterLockedIncrement (gCount_spacing [min (kMaxIndBirthIntervals, nbChildren),
							min (kMaxDurationContraceptionInBirthIntervals, intendedMonths)]);
					while	(monthNow <= monthEnd) and
							(aleaContraception > AccDurationContr [monthsOfContraception]) and
							(not endUnion) and
							( effectivenessContraceptionStopping(pDemReg, nbChildren) >= randomGenerator.alea0 ) do
					begin
						if testSeparationHere and pDemReg^.separationInfo.separationPossible and
							endBySeparation (randomGenerator, monthStart, monthNow, nbPregnanciesInCurrentUnion,
								pCurrChild, pDemReg^.separationInfo, pDemReg^.dp, unionStates)
						then begin
							paramSeparation (monthNow);
							ageDurationEvents.monthStop := min (monthNow, ageDurationEvents.monthStop);
							ageDurationEvents.monthStopIsStopping := false;
						end else begin
							Inc ( monthsOfContraception );
							Inc ( monthNow );
						end;
					end;
					waiting_time_contraception := monthsOfContraception;
				end;
			end;
			
			function pregnancy (	pDemReg: pStructDemographicRegimeSettings;
									var pCurrChild: pInfoChildType;
									monthEnd: longint): longint;
			var
				dummy: double;
				currAge: FecundAges;
				durationPregnancyInMonths: longint;
				nonSusceptibleLiveBirth: longint;	{gestation and amenorrhea, counted from conception}
				monthsSpacing: longint;				{months of spacing contraception after the birth}
				
				function AbortionOrStillBorn (nonSusceptiblePeriod: longint): longint;
				begin
					newChild (pCurrChild, arrayChildren);

					with pCurrChild^ do
					begin
						livingAtBirth := false;
						birthOrder := 0;
						ageMotherAtChildbirth := lunarMonthsToAge (currMonth + nonSusceptiblePeriod);
						ageFatherAtChildbirth := calcAgeFatherAtChildbirth (ageMotherAtChildbirth, currUnion, unionStates);
						{DEBUG: CURIOUS NEGATIVE?? CHECK}
						ageDeath := lunarMonthsToAge (nonSusceptiblePeriod - kLivingBirth_durationPregnancyInMonths);
						
						{date ---}
						monthEndPregnancy := currMonth + nonSusceptiblePeriod;
						durationUnion := currMonth - monthStart + nonSusceptiblePeriod;
						motherUnionNumber := unionStates.nbUnions;
						monthStartInterval := calcStartInterval (pCurrChild, monthStart);

						deathChildSinceBirthOfMotherInMonths := ageToLunarMonths (ageDeath + ageMotherAtChildbirth);
					end;

					AbortionOrStillBorn := nonSusceptiblePeriod;
				end;
				
				function LivingBirth (pDemReg: pStructDemographicRegimeSettings): longint;
				var
					dummy: double;
					monthDeathChild: array [1..kMaxMultipleBirths] of longint; {To account for multiple births}
					currAge: FecundAges;
					ageDeathChild: double;
					monthsNonSusceptible: longint;	{period from conception during which the woman is not susceptible: gestation plus amenorrhea}
					maxMonthDeathChild: longint;
					nbBirthsInDelivery, indBirthInDelivery: longint;
					sexNewBorn: Sex;

				begin {LivingBirth}					
					testStopping := true;
					currAge := trunc ( lunarMonthsToAge (currMonth + kLivingBirth_durationPregnancyInMonths) ); {Age at birth}

					nbBirthsInDelivery := multipleBirths ( currAge );

					{amenorrea post-partum}
					dummy := randomGenerator.alea0;
					monthsNonSusceptible := kLivingBirth_durationPregnancyInMonths;
					while dummy < pDemReg^.temporary_sterility[monthsNonSusceptible - kLivingBirth_durationPregnancyInMonths] do
						Inc ( monthsNonSusceptible );
					{counted for the comparison with the amenorrhea schedule at the end of the run}
					InterLockedIncrement (gCount_amenorrhea [min (kMaxMonthTemporarySterility,
							monthsNonSusceptible - kLivingBirth_durationPregnancyInMonths)]);
					
					{Case of the possible early death of the newborn, before weaning,
					which may shorten the temporary sterility period}
					maxMonthDeathChild := 0;
					for indBirthInDelivery := 1 to nbBirthsInDelivery do begin // we take care of multiple births
						sexNewBorn := sexAtBirth (randomGenerator, pDemReg, 0);
						InterLockedIncrement (gCount_birthsBySex [sexNewBorn]);	{for the sex ratio at birth}
						if sexNewBorn = woman then
							ageDeathChild := calc_ageDeath (randomGenerator, 0,
													pDemReg^.mortalityInfo.survival_women, woman)
						else
							ageDeathChild := calc_ageDeath (randomGenerator, 0,
													pDemReg^.mortalityInfo.survival_men, man);
						if ageDeathChild < 4 then
							monthDeathChild [indBirthInDelivery] := ageToLunarMonths (ageDeathChild)
						else
							monthDeathChild [indBirthInDelivery] := ageToLunarMonths (ageDeathChild) + 6;
							
						maxMonthDeathChild := max (maxMonthDeathChild, monthDeathChild [indBirthInDelivery]);
						
						Inc ( nbChildren );
						Inc ( ageDurationEvents.nBirths );

						newChild (pCurrChild, arrayChildren);

						with pCurrChild^ do
						begin
							livingAtBirth := true;
							birthOrder := nbChildren;
							sex := sexNewBorn;
							ageMotherAtChildbirth := lunarMonthsToAge (currMonth + kLivingBirth_durationPregnancyInMonths);
							ageFatherAtChildbirth := calcAgeFatherAtChildbirth (ageMotherAtChildbirth, currUnion, unionStates);
							ageDeath := ageDeathChild;
							
							{date ---}
							monthEndPregnancy := currMonth + kLivingBirth_durationPregnancyInMonths;
							durationUnion := currMonth - monthStart + kLivingBirth_durationPregnancyInMonths;
							motherUnionNumber := unionStates.nbUnions;
							monthStartInterval := calcStartInterval (pCurrChild, monthStart);
							
							deathChildSinceBirthOfMotherInMonths := ageToLunarMonths (ageDeath + ageMotherAtChildbirth);
						end;
					end;
					
					addChild (currAge, min (nbChildren, kMaxNbChildrenCalc), nbBirthsInDelivery, ageChildren);

					{maxMonthDeathChild counts from birth, monthsNonSusceptible from conception}
					LivingBirth := min (monthsNonSusceptible, kLivingBirth_durationPregnancyInMonths + maxMonthDeathChild + 1);	
									
				end; {LivingBirth}
				
			begin {pregnancy}
				pregnancy := 1; // number of months of non susceptible period
				{CONCEPTION}
				Inc ( nbPregnanciesInCurrentUnion );
				{We look to see if we have a spontaneous abortion / intrauterine death or a stillborn or live birth}
				dummy := randomGenerator.alea0;
				currAge := trunc ( lunarMonthsToAge (currMonth) ); {Age at conception} {DEBUG check whether currMonth start from birth}
				
				{the outcome of this conception, by the mother's age, for the two risk schedules}
				InterLockedIncrement (gCount_conceptions [max (0, min (kMaxAgeFert, currAge))]);
				if (dummy < gIntrauterine_mortality_risk[currAge] + gStillbirth_mortality_risk[currAge]) then
				begin
					if (dummy < gIntrauterine_mortality_risk[currAge]) then
					begin
						{spontaneous abortion}
						InterLockedIncrement (gCount_intrauterine_byAge [max (0, min (kMaxAgeFert, currAge))]);
						dummy := randomGenerator.alea0;
						{Barrett's schedule runs from the SECOND month of gestation: losses in the
						 first month are absorbed into fecundability, not drawn here. See the note
						 on gDistrib_intrauterine_mortality_risk in Fertility.pas.}
						durationPregnancyInMonths := 2;
						while dummy > gDistrib_intrauterine_mortality_risk[durationPregnancyInMonths] do
							Inc ( durationPregnancyInMonths );
						{counted for the comparison with Barrett's distribution at the end of the run}
						InterLockedIncrement (gCount_intrauterine_month [min (8, durationPregnancyInMonths)]);
						
						pregnancy := AbortionOrStillBorn (kIntrauterineMort_NonSusceptPeriod_minInMonths + durationPregnancyInMonths);
					end else
					begin
						{stillbirth}
						InterLockedIncrement (gCount_stillbirth_byAge [max (0, min (kMaxAgeFert, currAge))]);
						pregnancy := AbortionOrStillBorn (kStillBirth_durationPregnancyInMonths);
					end;
				end else
				begin
					{Live birth. Two spells run from the same conception: the gestation followed by
					 the amenorrhea, and, one month after the birth, any spacing contraception. The
					 couple is exposed again when the later of the two ends, so the interval takes
					 the larger of the two and not their sum. The calls are written as two
					 statements because both have side effects and Pascal does not define the order
					 in which the operands of + are evaluated: LivingBirth increments nbChildren,
					 which decides the spacing distribution read below.}
					nonSusceptibleLiveBirth := LivingBirth (pDemReg);
					monthsSpacing := waiting_time_contraception (
											pDemReg,
											pDemReg^.AccDurationWaitingTime [min(nbChildren, kMaxIndBirthIntervals)],
											effectivenessContraceptionSpacing(pDemReg, nbChildren),
											monthEnd,
											currMonth + kLivingBirth_durationPregnancyInMonths + 1,
											false);	{the advance loop of calcNbChildren walks these months so we don't test for separation here}
					if (monthsSpacing > 0) then
						pregnancy := max (nonSusceptibleLiveBirth,
										kLivingBirth_durationPregnancyInMonths + 1 + monthsSpacing)
					else
						pregnancy := nonSusceptibleLiveBirth;
				end;
				
			end; {pregnancy}
			
			var
				monthOfEndOfFecundLife: longint;
				monthWaitingTime: longint;
				waiting_time_firstUnion: boolean = false;
				
		begin {calcNbChildren}
			monthOfEndOfFecundLife := ageToLunarMonths ( fecundLife.ageSterile );

			monthStart := ageToLunarMonths (ageDurationEvents.ages[le_union, woman]);
			monthEnd := min (kMaxAgeFertInMonths,
				monthStart +
				ageDurationEvents.durations.durationUnionInMonths +
				round(randomGenerator.alea0)
				);
			
			monthEnd := min (monthEnd, monthOfEndOfFecundLife);

			ageDurationEvents.nBirths := 0;
			{Provisional values - may change, depending on contraception use and separation}
			ageDurationEvents.monthStart := monthStart;
			ageDurationEvents.monthStop := kMaxAgeLifeInMonths;
			ageDurationEvents.monthStopIsStopping := false;
			
			currMonth := monthStart;
			endUnion := false;
			testStopping := true;
			nbPregnanciesInCurrentUnion := 0;
			
try // 1
			{Birth control after union. Only first union}
			if currUnion = 1 then begin
				monthWaitingTime := waiting_time_contraception (
					pDemReg,
					pDemReg^.AccDurationContrAfterUnion,
					pDemReg^.propContraceptionAfterUnion_var,
					monthEnd,
					currMonth,
					true);	{nothing else walks these months, so the risk of separation is applied here}
				{the function no longer moves the clock, so the wait is applied here}
				currMonth := currMonth + monthWaitingTime;
				waiting_time_firstUnion := (monthWaitingTime > 0);
			end;
			
			{Birth control any union, before first birth (only if the previous waiting time is zero)}
			if not waiting_time_firstUnion and (nbChildren = 0) then begin
				monthWaitingTime := waiting_time_contraception (
					pDemReg,
					pDemReg^.AccDurationWaitingTime [0],
					effectivenessContraceptionSpacing(pDemReg, 0),
					monthEnd,
					currMonth,
					true); {again nothing else walks these months, so the risk of separation is applied here}
				currMonth := currMonth + monthWaitingTime;
			end;
except // 1
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
breakOnFailure;
		end;
	end;
end;
try // 2
			{Effective value of start of fertile life without contraception use}
			ageDurationEvents.monthStart := currMonth;
			while (currMonth <= monthEnd) and (not endUnion) do
			begin
				ageThisCycle := trunc ( lunarMonthsToAge (currMonth) );
				{The test is on the index into the fecundability tables and not on the fractional
				 age. The last month of the fertile life is 719, whose fractional age is 59.92,
				 above kMaxAgeFert, so a test on the fraction would report a failure for every
				 woman still in a union at that age. What has to hold is that the index is inside
				 the bounds of the tables.
				 The value tested is ageThisCycle, a plain longint, and not currAge, whose type
				 FecundAges has kMinAgeFert and kMaxAgeFert as its own bounds. Written on currAge
				 the test could never report anything: with range checking on, an age outside the
				 bounds raises a range error on the assignment, before the test is reached, and
				 with range checking off the two comparisons are constantly false. The value is
				 brought inside the bounds only after the test, so that a run which is not stopped
				 at the failure carries on with a legal index instead of failing on the assignment.}
				if checkFalse (chk_currAgeInFecundRange,
					(ageThisCycle < kMinAgeFert) or (ageThisCycle > kMaxAgeFert),
					['month ', currMonth, ', age ', ageThisCycle]) then breakOnFailure;
				currAge := max (kMinAgeFert, min (kMaxAgeFert, ageThisCycle));
				aleaFecundability := randomGenerator.alea0 ();
try // 2-1
				{The fecundability that governs this cycle. With RESHUFFLED_FECUNDABILITY off,
				 it is the woman's own schedule read at her age, as before, and no draw is added,
				 so the sequence of random numbers and every result are unchanged.
				 With the switch on, the heterogeneity multiplier is drawn again for this cycle and
				 nothing else changes: invRelativeFecundabilityLevel takes out the multiplier the
				 schedule was built with, leaving the general schedule of fecundability by age and
				 the woman's own Leridon taper, and the new multiplier is applied to that. The unit
				 of the redraw is the cycle of exposure, which is where this test sits, so the
				 months of a non susceptible period, which the loop steps over, draw nothing.
				 This is a different model of heterogeneity and not a correction of the other one:
				 a multiplier drawn afresh each cycle turns variation between women into variation
				 within a woman. The between-woman variance the Leridon parameterisation asks for
				 is then absent, and with it the selection by which the most fecund conceive first,
				 so waiting times and parity progression differ from a run made with the switch
				 off. The switch is off by default.}
				if g_GENPARAM.fixedParameters [reshuffledFecundability].state.value then
					fecundabilityThisCycle := fecundabilityLevel (randomGenerator)
							* fecundLife.invRelativeFecundabilityLevel
							* fecundLife.levelFecundabilityAge [currAge]
				else
					fecundabilityThisCycle := fecundLife.levelFecundabilityAge [currAge];
				if fecundabilityThisCycle >= aleaFecundability then
				{we have a fecundation!}
				begin
					if (not fecundLife.stopping) and testStopping then
					begin
						fecundLife.stopping := (pDemReg^.curr_contracepStopping [nbChildren] < randomGenerator.alea0);
						testStopping := false; // stopping condition is reached: we don't test twice
						if (fecundLife.stopping) then begin
							ageDurationEvents.monthStop := min (currMonth, ageDurationEvents.monthStop);
							ageDurationEvents.monthStopIsStopping := true;
						end;
					end;

					if not fecundLife.stopping then
					begin
						monthIncrement := pregnancy ( pDemReg, pCurrChild, monthEnd );
					end else
					begin
						{stopping contraception effectiveness}						
						if effectivenessContraceptionStopping(pDemReg, nbChildren) < randomGenerator.alea0 then
						begin
							monthIncrement := pregnancy ( pDemReg, pCurrChild, monthEnd );
						end
						else
							// no fecundation
							monthIncrement := 1;
					end;
				end else
				begin
					{we go to the next month}
					monthIncrement := 1;
				end; {fecundabilityThisCycle >= aleaFecundability then}
except // 2-1
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			breakOnFailure;
		end;
	end;
end;
try // 2-2

				if ( monthIncrement > 1 ) then begin
					{There is a pregnancy}
					with pCurrChild^ do begin
						monthFecundation := currMonth;
						
						{the second half is the one that can fail: a pregnancy that ends before it
						 begins is what N6 produced, the clock having moved between the two records}
						if checkFalse (chk_pregnancyLength,
							(monthEndPregnancy > monthFecundation + 11) or (monthEndPregnancy < monthFecundation),
							['conception ', monthFecundation, ', end of pregnancy ', monthEndPregnancy]) then breakOnFailure;
						ageMotherAtFecundation := lunarMonthsToAge (currMonth);
						monthNewOvulation := currMonth + monthIncrement;
					end;
				end;

				{Separation over the non-susceptible period that follows this conception.

				 The risk is applied to every month of that period, so the union can end during the
				 pregnancy and during the amenorrhea. What cannot change is the union the child
				 belongs to: motherUnionNumber is written inside pregnancy, that is at conception,
				 before this loop runs, so the birth is recorded under the union in force when the
				 child was conceived, and with the civil status the woman had then. A child born
				 more than nine months after the end of that union, or after the mother's death, is
				 dropped further down, where the test reads 9/12 of a year although the comment
				 beside it says ten months.

				 Since the N6 fix, monthIncrement also covers the months of any spacing
				 contraception drawn for this interval, because the interval takes the later of the
				 two spells rather than their sum. This loop therefore walks those months too, which
				 is why waiting_time_contraception no longer tests separation on them (N6b): every
				 month of the interval is walked here, exactly once.}
				monthsElapsed := 0;
				while (monthsElapsed < monthIncrement) and (currMonth <= monthEnd) do
				begin
					Inc ( monthsElapsed );
					if pDemReg^.separationInfo.separationPossible and
						endBySeparation (randomGenerator, monthStart, currMonth, nbPregnanciesInCurrentUnion, pCurrChild, pDemReg^.separationInfo, pDemReg^.dp, unionStates)
						then
					begin
						paramSeparation (currMonth);
						ageDurationEvents.monthStop := min (currMonth, ageDurationEvents.monthStop);
						ageDurationEvents.monthStopIsStopping := false;
						monthsElapsed := monthIncrement;
					end else
						Inc ( currMonth );
				end;
except // 2-2
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			breakOnFailure;
		end;
	end;
end;

			end; {while (currMonth <= monthEnd) and (not endUnion)}
except // 2
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			breakOnFailure;
		end;
	end;
end;
try // 3
			if (currPartnershipStatus <> separated) and (ageDurationEvents.durations.durationFecundInMonths > ageDurationEvents.durations.durationAliveMan) then
			begin
				currPartnershipStatus := widow;
			end;
except // 3
	on E: Exception do begin
		writeAndWaitConst(['===> ERROR: ', E.Message]);
		breakOnFailure;
	end;
end;
try // 4
			{for debugging purposes only. We should never have (monthStop = kMaxAgeLifeInMonths) and (currMonth < monthEnd)}
			if checkFalse (chk_monthStopSet,
				(ageDurationEvents.monthStop = kMaxAgeLifeInMonths) and (currMonth < monthEnd),
				['month ', currMonth, ', end of union ', monthEnd]) then breakOnFailure;
			if (ageDurationEvents.monthStop = kMaxAgeLifeInMonths) and (currMonth < monthEnd ) then
				ageDurationEvents.monthStop := currMonth - 1;
except // 4
	on E: Exception do begin
		writeAndWaitConst(['===> ERROR: ', E.Message]);
		breakOnFailure;
	end;
end;
			
			{separation after the end of fecund life - TO BE DEBUGGED !!!}
			if ((currPartnershipStatus = firstUnion) or (currPartnershipStatus = secondUnions)) then
			begin
try // 5
				endUnion := false;
				monthEnd := kMaxAgeLifeInMonths;  {We could take into account the death of the spouse...}

				if ageDurationEvents.durations.durationAliveMan >= 0 then
					monthEnd := monthStart + ageDurationEvents.durations.durationAliveMan; {That's good??}
				if param_deathWoman then
					monthEnd := min (monthEnd, ageToLunarMonths ( ageDurationEvents.ages[le_death, woman] ));
except // 5
	on E: Exception do begin
		writeAndWaitConst(['===> ERROR: ', E.Message]);
		breakOnFailure;
	end;
end;
try // 6
				while (currMonth < monthEnd) and (not endUnion) do
				begin
				if pDemReg^.separationInfo.separationPossible and
					endBySeparation (randomGenerator, monthStart, currMonth, nbPregnanciesInCurrentUnion,
							pCurrChild, pDemReg^.separationInfo, pDemReg^.dp, unionStates) then
					begin
						paramSeparation (currMonth);
						ageDurationEvents.monthStop := min (currMonth, ageDurationEvents.monthStop);
						ageDurationEvents.monthStopIsStopping := false;
					end else
						Inc ( currMonth );
				end;
except // 6
	on E: Exception do begin
		breakOnFailure;
	end;
end;
			end;
			
			if ( ageDurationEvents.monthStop = kMaxAgeLifeInMonths ) then begin
				{If the recorded month that end the reproductive life is the maximum life,
				 we use the end of the union life instead}
				ageDurationEvents.monthStop := monthStart + ageDurationEvents.durations.durationUnionInMonths;
				if ageDurationEvents.durations.durationUnionInMonthsWithSeparation > 1 then
					ageDurationEvents.monthStop := min (ageDurationEvents.monthStop, monthStart + ageDurationEvents.durations.durationUnionInMonthsWithSeparation);
				ageDurationEvents.monthStopIsStopping := false;
			end;
			
			if nbChildren > 0 then
			begin
				// exclude children whose childbirth occurred 10 months or more after separation
				// or after mother's death
				while 	((ageDurationEvents.ages[le_endUnion, woman] <> kNotDefined) and (pCurrChild^.ageMotherAtChildbirth > ageDurationEvents.ages[le_endUnion, woman] + 9/12)) or
						((ageDurationEvents.ages[le_death, woman] <> kNotDefined) and (pCurrChild^.ageMotherAtChildbirth > ageDurationEvents.ages[le_death, woman])) do begin
					if pCurrChild^.LivingAtBirth then
						Dec (nbChildren);
					if pCurrChild^.previous <> nil then begin
						pPreviousChild := pCurrChild^.previous;
 						disposeChild (pCurrChild);
						pCurrChild := pPreviousChild;
					end else begin
						disposeChild (pCurrChild);
						break;
					end;
					if (nbChildren = 0) then break;
				end;
			end;


		end; {calcNbChildren}

	var
		currUnion: longint = 1;
		ageNextUnion: double;
		nbChildren: longint;
		indChild: DistribChildrenCalc;
		age: FecundAges;
		initAges: boolean = false;
		mem_param_currentUnionNumber, indUnion: longint;
		label onExit;

	begin {calcCompleteFertilityWoman}
	
		mem_param_currentUnionNumber := param_currentUnionNumber;

		if param_newPartnershipLife then begin
			nbChildren := 0;
			disposeChild ( pChild );
		
			for age := kMinAgeFert to kMaxAgeFert do
				for indChild := 0 to kMaxNbChildrenCalc do
					ageChildren[age, indChild] := 0;
					
			initFecundLife (randomGenerator, fecundLife);
			unionStates.nbUnions := 0;
			currUnion := param_currentUnionNumber;
		end else begin
			nbChildren := numChildrenBornAlive (pChild);
			currUnion := param_currentUnionNumber;
			fecundLife.stopping := false;
		end;

		if g_GENPARAM.FIXED_FERTILITY.value then begin
			nbChildren := fixedNumChildren (
            		   	  	randomGenerator,
                            pDemReg,
							unionStates,
							ageChildren,
							pChild,
							fecundLife,
							objOutputFert,
							arrayPartners
						);
			InitPartnershipLife (
            	randomGenerator,
            	pDemReg,
                param_deathWoman,
                param_deathMan,
                unionStates.fecundLife,
                unionStates.Unions [param_currentUnionNumber - 1]);
			goto onExit;
		end;
				
		ageNextUnion := max (kMinAgeUnion, param_ageUnion);
		unionStates.Unions [currUnion - 1].ages[le_union, woman] := ageNextUnion;
//try // 1
		while (ageNextUnion <> kNotDefined) do
		begin

			unionStates.newUnion(initAges);
			initAges := true; // subsequent unions will need that...

			if unionStates.nbUnions = 1 then begin
				currPartnershipStatus := firstUnion;
			end
			else begin
				currPartnershipStatus := secondUnions;
				unionStates.Unions [currUnion - 1].ages[le_union, woman] := ageNextUnion;
				unionStates.Unions [currUnion - 1].ages[le_death, woman] := unionStates.Unions [currUnion - 2].ages[le_death, woman];
			end;
			if InitPartnershipLife (randomGenerator, pDemReg, param_deathWoman, param_deathMan, unionStates.fecundLife, unionStates.Unions [currUnion - 1]) then
			begin
				calcNbChildren (pDemReg, currUnion, unionStates.Unions [currUnion - 1], nbChildren, pChild);
				if repartnering_duration (randomGenerator, woman, unionStates.Unions [currUnion - 1], ageNextUnion, pDemReg^.pCurrUnionInfo, objOutputFert) then
					Inc ( currUnion )
				else
					ageNextUnion := kNotDefined;
			end else begin
				Dec (currUnion);
				Dec (unionStates.nbUnions);
				ageNextUnion := kNotDefined;
			end;

		end; {while (ageNextUnion <> kNotDefined)}

{except // 1
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			breakOnFailure;
		end;
	end;
end;}

	onExit:

		goBackToFirstChild ( pChild );
		
		finalPartnershipStatus (unionStates);
		
		unionStates.nbChildren := nbChildren;
		{if DEBUG then writeDebugInfo ( unionStates, pChild );}
					
		timeToConception ( unionStates, pChild, objOutputFert );

		calcCompleteFertilityWoman := nbChildren;

		{We verify ages at start and end of union and age at death are in correct sequences}
		for indUnion := mem_param_currentUnionNumber to unionStates.nbUnions do begin
			if checkFalse (chk_manUnionBeforeEnd,
				(unionStates.Unions [indUnion-1].ages[le_union, man] >
				unionStates.Unions [indUnion-1].ages[le_endUnion, man]) and
				(unionStates.Unions [indUnion-1].ages[le_endUnion, man] <> kNotDefined),
				['union ', indUnion]) then breakOnFailure;
			if checkFalse (chk_womanUnionBeforeEnd,
				(unionStates.Unions [indUnion-1].ages[le_union, woman] >
				unionStates.Unions [indUnion-1].ages[le_endUnion, woman]) and
				(unionStates.Unions [indUnion-1].ages[le_endUnion, woman] <> kNotDefined),
				['union ', indUnion]) then breakOnFailure;
			if param_deathWoman then begin
				if checkFalse (chk_womanUnionBeforeDeath,
					unionStates.Unions [indUnion-1].ages[le_union, woman] >
					unionStates.Unions [indUnion-1].ages[le_death, woman],
					['union ', indUnion]) then breakOnFailure;
				if checkFalse (chk_womanEndUnionBeforeDeath,
					unionStates.Unions [indUnion-1].ages[le_endUnion, woman] >
					unionStates.Unions [indUnion-1].ages[le_death, woman],
					['union ', indUnion]) then breakOnFailure;
			end;
			if param_deathMan then begin
				if checkFalse (chk_manUnionBeforeDeath,
					unionStates.Unions [indUnion-1].ages[le_union, man] >
					unionStates.Unions [indUnion-1].ages[le_death, man],
					['union ', indUnion]) then breakOnFailure;
				if checkFalse (chk_manEndUnionBeforeDeath,
					unionStates.Unions [indUnion-1].ages[le_endUnion, man] >
					unionStates.Unions [indUnion-1].ages[le_death, man],
					['union ', indUnion]) then breakOnFailure;
			end;
		end;

	end; {calcCompleteFertilityWoman}


	procedure computeDFprobAgr (pDemReg: pStructDemographicRegimeSettings);

		var
			i, i_1: longint;
			partnershipStatus: PartnershipStatusesType;

	begin
		
		for i := kMaxNbChildren - 1 downto 0 do
		begin
			for partnershipStatus := neverInUnion to any do
			begin
				pDemReg^.completeFertility[i, partnershipStatus] := pDemReg^.completeFertility[i, partnershipStatus] + pDemReg^.completeFertility[i + 1, partnershipStatus];
			end;
		end;
		
		// include women who never entered a union
		pDemReg^.completeFertility[0, any] := pDemReg^.lp[nWomenPar].value;
		
		pDemReg^.parityProgressionRatio[0, firstUnion] := pDemReg^.completeFertility[0, firstUnion] / pDemReg^.lp[nWomenPar].value;
		pDemReg^.parityProgressionRatio[0, everInUnion] := pDemReg^.completeFertility[0, everInUnion] / pDemReg^.lp[nWomenPar].value;
		pDemReg^.parityProgressionRatio[0, any] := pDemReg^.completeFertility[0, any] / pDemReg^.lp[nWomenPar].value;

		for i := 1 to (kMaxNbChildren - 1) do
		begin
			i_1 := i - 1;
			if ( pDemReg^.completeFertility[i_1, firstUnion] > 0 ) then begin
				pDemReg^.parityProgressionRatio[i, firstUnion] := pDemReg^.completeFertility[i, firstUnion] / pDemReg^.completeFertility[i_1, firstUnion];
			end else begin
				pDemReg^.parityProgressionRatio[i, firstUnion] := 0;
			end;
			if ( pDemReg^.completeFertility[i_1, everInUnion] > 0 ) then begin
				pDemReg^.parityProgressionRatio[i, everInUnion] := pDemReg^.completeFertility[i, everInUnion] / pDemReg^.completeFertility[i_1, everInUnion];
			end else begin
				pDemReg^.parityProgressionRatio[i, everInUnion] := 0;
			end;
			if ( pDemReg^.completeFertility[i_1, any] > 0 ) then begin
				pDemReg^.parityProgressionRatio[i, any] := pDemReg^.completeFertility[i, any] / pDemReg^.completeFertility[i_1, any];
			end else begin
				pDemReg^.parityProgressionRatio[i, any] := 0;
			end;
		end;

		for i := 0 to kMaxNbChildrenCalc - 1 do begin
			pDemReg^.aPrioriPPR_result.value[i] := pDemReg^.parityProgressionRatio[i+1, everInUnion];
		end;
		// smooth values...
		for i := kMaxNbChildrenCalc to kMaxNbChildren do begin
			pDemReg^.aPrioriPPR_result.value[i] := pDemReg^.aPrioriPPR_result.value[i-1];
		end;
		
	end;

	procedure writeDFprogRatio (pDemReg: pStructDemographicRegimeSettings);

		var
			i, i_1: longint;
			partnershipStatus: PartnershipStatusesType;
			nbWomen: array [PartnershipStatusesType] of longint;
			nbChildren: array [PartnershipStatusesType] of longint;
			
			DF_apriori_total, DF_apriori: double;

	begin
		DF_apriori := compute_aprioriDF(pDemReg);
		DF_apriori_total := DF_apriori * pDemReg^.pCurrUnionInfo^.unionParam [woman, freqFinUnion];
		
		for partnershipStatus := neverInUnion to any do
		begin
			nbWomen [partnershipStatus] := 0;
			nbChildren [partnershipStatus] := 0;
		end;
		
		{Cohort Total Fertility by order and union status}
		if writeResults (res_fert_TotFert) then
		begin
			aWriteLn(gOutFileFec, ['### Cohort total fertility (option ' + g_GENPARAM.outputs_opt[res_fert_TotFert].name + ')']);
			aWriteLn(gOutFileFec, ['order', tab, 'firstUnion', tab, 'ever in union']);
			for i := 0 to kMaxNbChildren do
			begin
				for partnershipStatus := neverInUnion to any do
				begin
					nbWomen [partnershipStatus] := nbWomen [partnershipStatus] + pDemReg^.completeFertility[i, partnershipStatus];
					nbChildren [partnershipStatus] := nbChildren  [partnershipStatus] + pDemReg^.completeFertility[i, partnershipStatus] * i;
				end;
				aWriteLn(gOutFileFec, [i, tab, pDemReg^.completeFertility[i, firstUnion], tab, pDemReg^.completeFertility[i, everInUnion]]);
			end;

			aWriteLn(gOutFileFec, [nbWomen [firstUnion], tab, 'women, DF still in union at age 50: ', tab, nbChildren [firstUnion] / nbWomen [firstUnion]]);
			aWrite(gOutFileFec, [nbWomen [everInUnion], tab, 'women, DF ever in union: ', tab, nbChildren [everInUnion] / nbWomen [any]]);
			aWriteLn(gOutFileFec, [tab, 'à priori', tab, DF_apriori] );
			aWrite(gOutFileFec, [pDemReg^.lp[nWomenPar].value, tab, 'women, DF tot: ', tab, nbChildren [any] / pDemReg^.lp[nWomenPar].value]);
			aWriteLn(gOutFileFec, [tab, 'à priori', tab, DF_apriori_total] );
		
		end;
		
		if writeResults (res_fert_fertility_unionStatus) then
		begin
			aWriteLn(gOutFileFec, ['### Total Fertility by parity and union status (option ' + g_GENPARAM.outputs_opt[res_fert_fertility_unionStatus].name + ')']);
			aWrite(gOutFileFec, ['parity']);
			for partnershipStatus := neverInUnion to any do
				aWrite(gOutFileFec, [tab, PartnershipStatusToStr (partnershipStatus)] );
			aWriteLn(gOutFileFec, ['']);
			
			for i := 0 to kMaxNbChildren do
			begin
				aWrite(gOutFileFec, [i]);
				for partnershipStatus := neverInUnion to any do
				begin
					aWrite(gOutFileFec, [tab, pDemReg^.completeFertility[i, partnershipStatus]])
				end;
				aWriteLn(gOutFileFec, ['']);
			end;
		end;
		
		if writeResults (res_fert_PPRs) then
		begin
			aWriteLn(gOutFileFec, ['### Parity Progression Ratios by union status (option ' + g_GENPARAM.outputs_opt[res_fert_PPRs].name + ')']);
			aWriteLn(gOutFilePPR, ['parity progression ratio', tab, 'firstUnion', tab , 'ever in union', tab, 'all']);
			aWriteLn(gOutFilePPR, ['prop. in state ', tab, pDemReg^.parityProgressionRatio[0, firstUnion], tab, pDemReg^.parityProgressionRatio[0, everInUnion], tab, pDemReg^.parityProgressionRatio[0, any]]);

			for i := 1 to (kMaxNbChildrenCalc - 1) do
			begin
				i_1 := i - 1;
				if pDemReg^.completeFertility[i - 1, firstUnion] > 0 then
				begin
					aWriteLn(gOutFilePPR, [i_1, '->', i, tab, pDemReg^.parityProgressionRatio[i, firstUnion], tab, pDemReg^.parityProgressionRatio[i, everInUnion], tab, pDemReg^.parityProgressionRatio[i, any]]);
				end else
				begin
					aWriteLn(gOutFilePPR, [i_1, '->', i, tab, 0.0, tab, 0.0, tab, 0.0]);
				end;
			end;
		
			aWriteLn(gOutFilePPR, [longint(kMaxNbChildrenCalc - 1), '+ ->', kMaxNbChildrenCalc, '+', tab, pDemReg^.parityProgressionRatio[kMaxNbChildrenCalc, firstUnion], tab, pDemReg^.parityProgressionRatio[kMaxNbChildrenCalc, everInUnion], tab, pDemReg^.parityProgressionRatio[kMaxNbChildrenCalc, any]]);
		end;
	end;

	function strDurType ( durType: durationEventType ): string;
	begin
		if durType = eventLiveBirth then
			strDurType := 'birth'
		else if durType = eventEndUnion then
			strDurType := 'endM'
		else if durType = totalEvents then
			strDurType := 'total';
	end;
	
	procedure write_no_fecundation (objOutputFert: TOutputFertility);
	var
		durType: durationEventType;
		i: integer;
		nParity: integer;
		ageFec: FecundAges;
				
	begin
		aWriteLn(gOutFileFec, ['### Time to conception: total (option ' + g_GENPARAM.outputs_opt[res_fert_no_fecundation].name + ')']);
		aWrite(gOutFileFec, ['event', tab, 'parity', tab]);
		for i := 0 to high(durationValues) do begin
			aWrite(gOutFileFec, [i, tab]);
		end;
		aWriteLn(gOutFileFec, ['']);
		for durType := low (durationEventType) to high (durationEventType) do begin
			for nParity := 0 to kMaxNbChildrenCalc do begin
				aWrite(gOutFileFec, [strDurType (durType), tab]);
				aWrite(gOutFileFec, [nParity, tab]);
				for i := 0 to high(durationValues) do begin
					aWrite(gOutFileFec, [objOutputFert.noFecundation [nParity].number_tot[i, durType], tab]);
				end;
				aWriteLn(gOutFileFec, ['']);
			end;
		end;
	
		aWriteLn(gOutFileFec, ['Time to conception: by age at duration 0']);
		aWrite(gOutFileFec, ['event', tab, 'parity', tab, 'age', tab]);
		for i := 0 to high(durationValues) do begin
			aWrite(gOutFileFec, [i, tab]);
		end;
		aWriteLn(gOutFileFec, ['']);
		for durType := low (durationEventType) to high (durationEventType) do begin
			for nParity := 0 to kMaxNbChildrenCalc do begin
				for ageFec := kMinAgeFert to kMaxAgeFert do begin
				aWrite(gOutFileFec, [strDurType (durType), tab]);
				aWrite(gOutFileFec, [nParity, tab]);
				aWrite(gOutFileFec, [ageFec, tab]);
				for i := 0 to high(durationValues) do begin
					aWrite(gOutFileFec, [objOutputFert.noFecundation [nParity].numbers[ageFec, i, durType], tab]);
				end;
				aWriteLn(gOutFileFec, ['']);
				end;
			end;
		end;
	end;
	
	procedure write_INDIVIDUAL_INFO (pDemReg: pStructDemographicRegimeSettings;
	idWoman: longint;
	unionStates: TUnionsType;
	var pFirstChild: pInfoChildType);
	{This procedure write the union and reproductive history for one woman. It writes the file header for the woman with idWoman = 1}
	var
		sep: char = comma;
		unionStates_copy: TUnionsType;
		ageSurvey: double;
		
		procedure writeHeader();
		var
			i: longint;
		begin
			if RP.wKey then bWrite (gOutFileIndivFec, ['nKey', sep]);
			bWrite(gOutFileIndivFec, ['id', sep, 'cohort', sep, 'nUnion', sep, 'nTotBirths', sep, 'nAbortions', sep, 'status50', sep, 'ageSterility']);
			if g_GENPARAM.OUTPUT_FERT_SURVEY.value then bWrite(gOutFileIndivFec, [sep, 'ageSurvey']);
			if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.value then begin
				bWrite(gOutFileIndivFec, [sep, 'relFecundability']);
				for i := kMinAgeFert to kMaxAgeFert do
					bWrite(gOutFileIndivFec, [sep, 'F', i]);
			end;
			for i := 1 to g_GENPARAM.outputs_fmt[res_numUnion].value do
				bWrite (gOutFileIndivFec, [sep, 'ageUnionWoman', i, sep, 'ageUnionMan', i, sep, 'ageSepWoman', i, sep, 'ageSepMan', i, sep,
						'ageDeathWoman', i, sep, 'ageDeathMan', i, sep, 'nBirths', i]);
			for i := 1 to g_GENPARAM.outputs_fmt[res_numBirths].value do begin
				bWrite (gOutFileIndivFec, [sep, 'ageMother', i, sep, 'sex', i, sep, 'order', i, sep, 'nUnion', i]);
				if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.value then
					bWrite (gOutFileIndivFec,
							[sep, 'ageFather', i,
							sep, 'durationUnion', i,
							sep, 'monthStartInterval', i,
							sep, 'monthNewOvulation', i,
							sep, 'monthEndPregnancy', i,
							sep, 'monthFecundation', i]);
			end;
			cWriteLn(gOutFileIndivFec);
		end;

		procedure writeInfo(unionStates: TUnionsType);
		var
			i: longint;
			a, aF: double;
			s, l, n, r, dU, mS, mN, mE, mF: longint;
			nChildrenAlive: longint = 0;
			nAbortions: longint = 0;
			nAbortionsNotWritten: longint = 0;
			pCurrChild: pInfoChildType;

			procedure valuesNotDefined;
			begin
				a := kNotDefined;
				aF := kNotDefined;
				s := kNotDefined;
				l := kNotDefined;
				n := kNotDefined;
				r := kNotDefined;
				dU := kNotDefined;
				mS := kNotDefined;
				mN := kNotDefined;
				mE := kNotDefined;
				mF := kNotDefined;
			end;
						
		begin
			pCurrChild := pFirstChild;
			while pCurrChild <> nil do begin
				if pCurrChild^.livingAtBirth then
					Inc ( nChildrenAlive )
				else
					Inc ( nAbortions );
				pCurrChild := pCurrChild^.next;
			end;
			if checkFalse (chk_childrenCounted, unionStates_copy.nbChildren <> nChildrenAlive,
				['woman ', idWoman, ', counted ', unionStates_copy.nbChildren, ', in the list ', nChildrenAlive]) then breakOnFailure;
				
			if RP.wKey then
				bWrite (gOutFileIndivFec, [RP.key, sep]);
			bWrite(gOutFileIndivFec, [idWoman, sep, pDemReg^.yearOfBirth.value, sep, unionStates_copy.nbUnions, sep, unionStates_copy.nbChildren, sep, nAbortions, sep,
					unionStates_copy.partnershipStatusAt50, sep, doubleToMinString (unionStates_copy.fecundLife.ageSterile)]);
			if g_GENPARAM.OUTPUT_FERT_SURVEY.value then bWrite(gOutFileIndivFec, [sep, doubleToMinString (ageSurvey)]);
			if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.value then begin
				bWrite(gOutFileIndivFec, [sep, doubleToMinString (unionStates_copy.fecundLife.relativeFecundabilityLevel)]);
				for i := kMinAgeFert to kMaxAgeFert do
					bWrite(gOutFileIndivFec, [sep, doubleToMinString (unionStates_copy.fecundLife.levelFecundabilityAge[i])]);
			end;

			for i := 1 to g_GENPARAM.outputs_fmt[res_numUnion].value do
				if (i <= unionStates_copy.nbUnions) then
					bWrite (gOutFileIndivFec,
							[sep, doubleToMinString (unionStates_copy.Unions [i - 1].ages[le_union, woman]),
							sep, doubleToMinString (unionStates_copy.Unions [i - 1].ages[le_union, man]),
							sep, doubleToMinString (unionStates_copy.Unions [i - 1].ages[le_endUnion, woman]),
							sep, doubleToMinString (unionStates_copy.Unions [i - 1].ages[le_endUnion, man]),
							sep, doubleToMinString (unionStates_copy.Unions [i - 1].ages[le_death, woman]),
							sep, doubleToMinString (unionStates_copy.Unions [i - 1].ages[le_death, man]),
							sep, unionStates_copy.Unions [i - 1].nBirths]
							)
				else
					bWrite (gOutFileIndivFec,
							[sep, kNotDefined,
							sep, kNotDefined,
							sep, kNotDefined,
							sep, kNotDefined,
							sep, kNotDefined,
							sep, kNotDefined,
							sep, kNotDefined]
							);

			pCurrChild := pFirstChild;
			for i := 1 to g_GENPARAM.outputs_fmt[res_numBirths].value do begin
				if (pCurrChild <> nil) then begin
					a := pCurrChild^.ageMotherAtChildbirth;
					aF := pCurrChild^.ageFatherAtChildbirth;
					s := pCurrChild^.sex;
					if pCurrChild^.livingAtBirth then begin
						l := 1;
						n := pCurrChild^.birthOrder;
					end else begin
						l := 0;
						n := 0;
					end;
					r := pCurrChild^.motherUnionNumber;
					dU := pCurrChild^.durationUnion;
					mS := pCurrChild^.monthStartInterval;
					mN := pCurrChild^.monthNewOvulation;
					mE := pCurrChild^.monthEndPregnancy;
					mF := pCurrChild^.monthFecundation;
					pCurrChild := pCurrChild^.next;
				end else begin
					valuesNotDefined;
				end;
				if (l = 0) and (g_GENPARAM.OUTPUT_EXCLUDE_ABORTION.value) then begin
					valuesNotDefined;
					Inc (nAbortionsNotWritten);
				end else begin
					bWrite (gOutFileIndivFec, [sep, doubleToMinString (a), sep, s, sep, n, sep, r]);
					if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.value then begin
						bWrite (gOutFileIndivFec, [sep, doubleToMinString (aF), sep, dU, sep, mS, sep, mN, sep, mE, sep, mF]);
					end;
				end;
			end;
			valuesNotDefined;
			for i := 1 to nAbortionsNotWritten do begin
				bWrite (gOutFileIndivFec, [sep, doubleToMinString (a), sep, s, sep, n, sep, r]);
				if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.value then begin
					bWrite (gOutFileIndivFec, [sep, doubleToMinString (aF), sep, dU, sep, mS, sep, mN, sep, mE, sep, mF]);
				end;
			end;
			cWriteLn(gOutFileIndivFec);
		end;

		procedure truncateAt (ageTruncate: double; unionStates: TUnionsType);
		var
			pCurrChild: pInfoChildType;
			i: longint;
            nUnions_truncate, nChildren_truncate: longint;
		begin
		{ TUnionType contains the following fields
			TUnionsType = class
			nIndividual: longint;
			gender: sex;
			nbUnions: longint;
			breakdownBySeparation: boolean;
			nbChildren: longint;
			fecundLife: FecundLifeType;
			partnershipStatusAt50: PartnershipStatusesType;
			Unions: array of UnionAgeDurationsType;
		}
            nUnions_truncate := unionStates.nbUnions;
			for i := 1 to unionStates.nbUnions do begin
 				if unionStates.Unions[i-1].ages[le_union,woman] > ageTruncate then begin
					nUnions_truncate := i - 1;
					Break;
				end; 
				if unionStates.Unions[i-1].ages[le_endUnion,woman] > ageTruncate then begin
					unionStates.Unions[i-1].ages[le_endUnion,woman] := kNotDefined;
					unionStates.Unions[i-1].ages[le_endUnion,man] := kNotDefined;
					unionStates.Unions[i-1].ages[le_death,woman] := kNotDefined;
					unionStates.Unions[i-1].ages[le_death,man] := kNotDefined;
					nUnions_truncate := i;
					if (i = 1) then
						unionStates.partnershipStatusAt50 := firstUnion
					else
						unionStates.partnershipStatusAt50 := secondUnions;
					Break;
				end; 
			end;
            nChildren_truncate := unionStates.nbChildren;
			pCurrChild := pFirstChild;
			for i := 1 to unionStates.nbChildren do begin
				while (not pCurrChild^.livingAtBirth) do
					pCurrChild := pCurrChild^.next;
				
				if pCurrChild^.ageMotherAtChildbirth > ageTruncate then begin
					nChildren_truncate := i - 1;
					if nChildren_truncate = 0 then
						pFirstChild := nil
					else
						pCurrChild^.previous^.next := nil;
					disposeChild (pCurrChild);
					break;
				end;
				pCurrChild := pCurrChild^.next;
			end;
            unionStates.nbUnions := nUnions_truncate;
            unionStates.nbChildren := nChildren_truncate;
		end;
			
	begin {write_INDIVIDUAL_INFO}
		if idWoman = 1 then begin
			if openFileOut(g_FileName.value + '_INDIVIDUAL_FERTILITY_INFO.CSV', 'INDIVIDUAL_FERTILITY_INFO', gOutFileIndivFec, kAsyncFalse) then
				writeHeader()
			else begin
				writeAndWait('===> ERROR: Problem creating file: ' + gOutFileIndivFec.filenameWithPath);
				gOutFileIndivFec.Destroy;
				gOutFileIndivFec := nil;
			end;
		end;
		if gOutFileIndivFec = nil then exit;

		// we make a copy of unionStates object in case we modify its data
		// especially useful in case of creating a fertility survey	
		unionStates.copyMe(unionStates_copy);
		if g_GENPARAM.OUTPUT_FERT_SURVEY.value then begin
			// we don't write in multithreading, so we can use the global random generator
			ageSurvey := gRandomGenerator.alea(
				g_GENPARAM.outputs_fmt[res_fertSurvey_ageMin].value,
				g_GENPARAM.outputs_fmt[res_fertSurvey_ageMax].value - 0.0000000001);
			truncateAt (ageSurvey, unionStates_copy);
		end;

		writeInfo(unionStates_copy);

		unionStates_copy.destroy();

	end; {write_INDIVIDUAL_INFO}

	procedure incrementIntervConc (unionStates: TUnionsType; pChild: pInfoChildType; var intervals_between_conceptions: array3doubletype);
	var
		monthPrev, monthNext, duration, child: longint;
	begin
		if unionStates.nbUnions = 0 then exit;
		monthPrev := ageToLunarMonths ( unionStates.Unions [0].ages[le_union, woman] );
		while ( pChild <> nil ) and ( pChild^.motherUnionNumber = 1 ) and ( pChild^.birthOrder > 0 ) do begin
			monthNext := ageToLunarMonths ( pChild^.ageMotherAtChildbirth ) - kLivingBirth_durationPregnancyInMonths;
			child := pChild^.birthOrder;
			child := min (kMaxNbChildrenCalc, child); 
			duration := min (kMaxDurationIntervalsInMonth, monthNext-monthPrev);
			if checkFalse (chk_conceptionInterval, duration < -2, ['interval ', duration]) then breakOnFailure;
			intervals_between_conceptions [g_nRuns-1, child-1, kMaxDurationIntervalsInMonth+1] :=
				intervals_between_conceptions [g_nRuns-1, child-1, kMaxDurationIntervalsInMonth+1] + 1;
			intervals_between_conceptions [g_nRuns-1, child-1, duration] :=
				intervals_between_conceptions [g_nRuns-1, child-1, duration] + 1;
			monthPrev := monthNext;
			pChild := pChild^.next;
		end;
	end;

	procedure incrementPopWomen_Children (unionStates: TUnionsType; ageChildren: TabCompFertAge; var popWomen : WomenPopType; var TotalAgeChildren: TabCompFertAgeStates);
	var
		ageWomen: longint;
		ageUnion, ageEndUnion: double;
		nUnion: longint;
		currentStatus, statutEndUnion: PartnershipStatusesType;
		
		procedure increments (ageWomen: FecundAges; currentStatus: PartnershipStatusesType);
		var
			i : longint;
		begin
			Inc ( popWomen[ageWomen, any] );
			Inc ( popWomen[ageWomen, currentStatus] );
			if currentStatus in [firstUnion, secondUnions, separated, widow] then
				Inc ( popWomen[ageWomen, everInUnion] );

			for i := 0 to kMaxNbChildrenCalc do begin
				TotalAgeChildren[ageWomen, i, any, endedAge50] :=
					TotalAgeChildren[ageWomen, i, any, endedAge50] + ageChildren[ageWomen, i];
				TotalAgeChildren[ageWomen, i, unionStates.partnershipStatusAt50, endedAge50] :=
					TotalAgeChildren[ageWomen, i, unionStates.partnershipStatusAt50, endedAge50] + ageChildren[ageWomen, i];
				if unionStates.partnershipStatusAt50 in [firstUnion, secondUnions, widow, separated] then
					TotalAgeChildren[ageWomen, i, everInUnion, endedAge50] :=
						TotalAgeChildren[ageWomen, i, everInUnion, endedAge50] + ageChildren[ageWomen, i];

				TotalAgeChildren[ageWomen, i, any, ongoing] :=
					TotalAgeChildren[ageWomen, i, any, ongoing] + ageChildren[ageWomen, i];
				TotalAgeChildren[ageWomen, i, currentStatus, ongoing] :=
					TotalAgeChildren[ageWomen, i, currentStatus, ongoing] + ageChildren[ageWomen, i];
				if currentStatus in [firstUnion, secondUnions, widow, separated] then
					TotalAgeChildren[ageWomen, i, everInUnion, ongoing] :=
						TotalAgeChildren[ageWomen, i, everInUnion, ongoing] + ageChildren[ageWomen, i];
			end;
		end;

	begin
		currentStatus := neverInUnion;
		nUnion := 0;
		if unionStates.nbUnions > nUnion then begin
			Inc ( nUnion );
			ageUnion := unionStates.Unions [nUnion - 1].ages[le_union, woman];
			ageEndUnion := ageWomenEndUnion (unionStates.Unions [nUnion - 1].ages, statutEndUnion);
		end else begin
			ageUnion := kNotDefined; {no union}
			ageEndUnion := kNotDefined;
		end;
		ageWomen := kMinAgeFert;
		while ageWomen <= kMaxAgeFert do begin
			if (ageWomen < trunc(ageUnion)) or (ageUnion < 0) then begin
				increments (ageWomen, currentStatus);
				Inc ( ageWomen );
			end else if (ageWomen >= trunc(ageUnion)) and (ageWomen < trunc(ageEndUnion)) then begin
				if nUnion = 1 then
					currentStatus := firstUnion
				else
					currentStatus := secondUnions;
				increments (ageWomen, currentStatus);
				Inc ( ageWomen );
			end else if ageWomen >= trunc(ageEndUnion) then begin
			{We do it that way because we can have the end of one union and the start of the following one in the same year}
				currentStatus := statutEndUnion;
				if unionStates.nbUnions > nUnion then begin
					Inc ( nUnion );
					ageUnion := unionStates.Unions [nUnion - 1].ages[le_union, woman];
					ageEndUnion := ageWomenEndUnion (unionStates.Unions [nUnion - 1].ages, statutEndUnion);
				end else begin
					ageUnion := kNotDefined; {no further union}
					ageEndUnion := kNotDefined;
				end;
			end;
		end;
	end;

	procedure incrementFertDuration (
					unionStates: TUnionsType;
					pChild: pInfoChildType; 
					objOutputFert: TOutputFertility);
	var
		ageUnion, ageEndUnion: longint;
		nUnion, nUnionMin: longint;
		duration, durationMin, nDuration: longint;
		nbChildren: longint;
		statutEndUnion: PartnershipStatusesType;
	begin
		if objOutputFert = nil then exit; // only for FERTILITY results
		nUnion := 0;
		while (nUnion < unionStates.nbUnions) do begin
			Inc ( nUnion );
			nUnionMin := min (2, nUnion);
			ageUnion := trunc (unionStates.Unions [nUnion - 1].ages[le_union, woman]);
			ageEndUnion := trunc (ageWomenEndUnion (unionStates.Unions [nUnion - 1].ages, statutEndUnion)) + 1; {you can have a child up to a year after the end of the union}
			nDuration := ageEndUnion - ageUnion;
			for duration := 0 to nDuration do begin
				durationMin := min (kMaxShownDurationUnion, duration);
				Inc ( objOutputFert.pWomanDuration^ [ageUnion, durationMin, 0] );
				Inc ( objOutputFert.pWomanDuration^ [ageUnion, durationMin, nUnionMin] );
				Inc ( objOutputFert.pWomanDuration^ [kMaxAgeUnion+1, durationMin, 0] );
				Inc ( objOutputFert.pWomanDuration^ [kMaxAgeUnion+1, durationMin, nUnionMin] );
			end;
		end;
		nbChildren := 0;
		while nbChildren < unionStates.nbChildren do begin
			Inc ( nbChildren );
			nUnion := pChild^.motherUnionNumber;
			nUnionMin := min (2, nUnion);
			ageUnion := trunc (unionStates.Unions [nUnion - 1].ages[le_union, woman]);
			ageEndUnion := trunc (ageWomenEndUnion (unionStates.Unions [nUnion - 1].ages, statutEndUnion)) + 1; {you can have a child up to a year after the end of the union}
			duration := trunc (pChild^.ageMotherAtChildbirth - unionStates.Unions [nUnion - 1].ages[le_union, woman]);
			if checkFalse (chk_birthWithinUnion, duration > ageEndUnion - ageUnion + 1,
				['union at ', ageUnion, ', ended at ', ageEndUnion, ', birth after ', duration]) then breakOnFailure;
			durationMin := min (kMaxShownDurationUnion, duration);
			Inc ( objOutputFert.pBirthDuration^ [ageUnion, durationMin, 0] );
			Inc ( objOutputFert.pBirthDuration^ [ageUnion, durationMin, nUnionMin] );
			Inc ( objOutputFert.pBirthDuration^ [kMaxAgeUnion+1, durationMin, 0] );
			Inc ( objOutputFert.pBirthDuration^ [kMaxAgeUnion+1, durationMin, nUnionMin] );
			pChild := pChild^.next;
		end;
	end;

	procedure writePartnershipStatusTable(f: TFileType; computeGenFert_WomenPop: WomenPopType; forceFile: boolean = false);
	var
		age: FecundAges;
		status: PartnershipStatusesType;
	begin
		aWriteLn (f, ['### Female population by civil status and age' + ' (option ' + g_GENPARAM.outputs_opt[res_fert_dump_UnionStates].name + ')'], forceFile);
		aWriteLn (f, ['age', tab, 'neverInUnion', tab, 'firstUnion', tab, 'secondUnions', tab, 'widow', tab, 'separated', tab, 'ever in union', tab, 'any'], forceFile);
		for age:=kMinAgeFert to kMaxAgeFert do begin
			aWrite (f, [age], forceFile);
			for status := neverInUnion to any do
				aWrite (f, [tab, computeGenFert_WomenPop[age, status]], forceFile);
			aWriteLn(f, [], forceFile);
		end;
	end;

type
	pComputeGenFertDataGroup = ^computeGenFertDataGroup;
	computeGenFertDataGroup = record
		WomenPop: WomenPopType;
		childrenAge: TabCompFertAge;
		childrenAgeTot: TabCompFertAgeStates;
		
		{destinyUnion: destinyUnionType;} {obsolete}
		varianceCompFert: double;
		durationSinceLastEvent: DurationSincePreviousEventType;			
		finalParity: FinalParityType; {we count the number of women who reach parity and the number who go on to the next parity, according to their age}

		{Results}
		propFinalSeparation: double;
	end;

	procedure compute_fecGen_tables (
					pDemReg: pStructDemographicRegimeSettings;
					pData: pComputeGenFertDataGroup;
					objUnionTable: TUnionTable);
	var
		i: longint;
		ageWomen: FecundAges;
		partnershipStatus: PartnershipStatusesType;
		unionGenState: UnionGenStatesType;
	
	begin
		
		for i := 0 to kMaxNbChildrenCalc do
		begin
			for partnershipStatus := neverInUnion to any do
				for unionGenState := ongoing to endedAge50 do begin
					pDemReg^.ageChildbearing [i, partnershipStatus, unionGenState] := 0.0;
					pDemReg^.df [i, partnershipStatus, unionGenState] := 0
				end;
		end;
	
		{Fertility by age}
		for ageWomen := kMinAgeFert to kMaxAgeFert do
		begin
			for i := 0 to kMaxNbChildrenCalc do
				for partnershipStatus := neverInUnion to any do begin
					if ( pData^.WomenPop[ageWomen, partnershipStatus] > 0 ) then begin
						objUnionTable.pGenFert^[i, partnershipStatus, ongoing, ageWomen] :=
						pData^.childrenAgeTot[ageWomen, i, partnershipStatus, ongoing] / pData^.WomenPop[ageWomen, partnershipStatus];
					end else begin
						objUnionTable.pGenFert^[i, partnershipStatus, ongoing, ageWomen] := 0;
					end;

					pDemReg^.ageChildbearing [i, partnershipStatus, ongoing] := pDemReg^.ageChildbearing [i, partnershipStatus, ongoing] + (ageWomen + 0.5) * objUnionTable.pGenFert^[i, partnershipStatus, ongoing, ageWomen];
					pDemReg^.df [i, partnershipStatus, ongoing] := pDemReg^.df [i, partnershipStatus, ongoing] + objUnionTable.pGenFert^[i, partnershipStatus, ongoing, ageWomen];

					if ( pData^.WomenPop[50, partnershipStatus] > 0 ) then begin
						objUnionTable.pGenFert^[i, partnershipStatus, endedAge50, ageWomen] := pData^.childrenAgeTot[ageWomen, i, partnershipStatus, endedAge50] / pData^.WomenPop[50, partnershipStatus];
					end else begin
						objUnionTable.pGenFert^[i, partnershipStatus, endedAge50, ageWomen] := 0;
					end;
					pDemReg^.ageChildbearing [i, partnershipStatus, endedAge50] := pDemReg^.ageChildbearing [i, partnershipStatus, endedAge50] + (ageWomen + 0.5) * objUnionTable.pGenFert^[i, partnershipStatus, endedAge50, ageWomen];
					pDemReg^.df [i, partnershipStatus, endedAge50] := pDemReg^.df [i, partnershipStatus, endedAge50] + objUnionTable.pGenFert^[i, partnershipStatus, endedAge50, ageWomen];
				end;
		end;
									
		computeDFprobAgr(pDemReg);
		
	end;

	procedure write_fecGen_tables (
					pDemReg: pStructDemographicRegimeSettings;
					objUnionTable: TUnionTable;
					objOutputFert: TOutputFertility;
					pData: pComputeGenFertDataGroup);
	const
		kNumIntervals = 5;
	var
		age, ageUnion, nUnion: longint;
		duration, durationUnion: longint;
		child: longint;
		numRepartnering: longint;
		propRepartnering: double;
		ageQ: ageQuinq;
		i, i_1, j: longint;
		ageWomen: FecundAges;

	begin
		if writeResults (res_fert_dump_UnionTable) then
		begin
			writeUnionTable(g_FileName.value + '_UNION_TABLE.TXT', objUnionTable);
		end;
	
		if writeResults (res_fert_dump_UnionStates) then
		begin
			writePartnershipStatusTable(gOutFileAgeMat, pData^.WomenPop);
		end;
	
		if writeResults (res_fert_prop_single) then
		begin
			aWriteLn(gOutFileAgeMat, [UnionFormRateAndSingleProp + ' (option ' + g_GENPARAM.outputs_opt[res_fert_prop_single].name + ')']);
			for age := kMinAgeUnion to kMaxAgeUnion do
				aWriteLn (gOutFileAgeMat, [age, tab, pDemReg^.pCurrUnionInfo^.union_women[age], tab, pDemReg^.pCurrUnionInfo^.prop_cel_women[age]]);
		end;

		aWriteLn(gOutFileAgeMat, ['observed proportion of separation for first union:', tab, 100.0 * pData^.propFinalSeparation]);
		{Write destinyUnion gOutFileAgeMat - obsolete}
		
{			if writeResults (res_destinyUnion) then
		begin
		 
			aWriteLn(gOutFileAgeMat, ['### Destiny union (option ' + g_GENPARAM.outputs_opt[res_destinyUnion].name + ')']);
			for durationUnion := 0 to kMaxDurationUnion do
				aWrite(gOutFileAgeMat, [tab, durationUnion]);
			aWriteLn(gOutFileAgeMat, ['']);
			for unionState := ongoing_union to ended_widowhood do
			begin
				aWrite(gOutFileAgeMat, [UnionStateToStr (unionState), tab]);
				for durationUnion := 0 to kMaxDurationUnion do
					aWrite(gOutFileAgeMat, [destinyUnion [durationUnion, unionState], tab]);
				aWriteLn(gOutFileAgeMat, ['']);
			end;
		end;
}		
		{Write gRepartneringStates gOutFileAgeMat}
		if writeResults (res_fert_repartneringStatesType) then
		begin
			aWriteLn(gOutFileAgeMat, ['### Repartnering: age at end of previous union, number entering a second union and duration in year since end of previous (option ' + g_GENPARAM.outputs_opt[res_fert_repartneringStatesType].name + ')']);
			aWrite(gOutFileAgeMat, ['Age', tab, 'prop', tab, 'Tot']);
			{for durationUnion := 0 to kMaxDurationUnion do}
			for durationUnion := 0 to 20 do
				aWrite(gOutFileAgeMat, [tab, durationUnion]);
			aWriteLn(gOutFileAgeMat, ['']);
		
			age := kMinAgeUnion;
			while age <= kMaxAgeSingle_women do
			begin
				aWrite(gOutFileAgeMat, [age, tab]);
				numRepartnering := 0;
				for durationUnion := 0 to kMaxDurationUnion do
					numRepartnering := numRepartnering + objOutputFert.RepartneringStates [woman, age, durationUnion];
				
				if objOutputFert.RepartneringStates [woman, age, kNotDefined] > 0 then
					propRepartnering := 100.0 * numRepartnering / objOutputFert.RepartneringStates [woman, age, kNotDefined]
				else
					propRepartnering := 0.0;
				
				aWrite(gOutFileAgeMat, [propRepartnering, tab]);
				{for durationUnion := -1 to kMaxDurationUnion do}
				for durationUnion := -1 to 20 do
					aWrite(gOutFileAgeMat, [objOutputFert.RepartneringStates [woman, age, durationUnion], tab]);
				aWriteLn(gOutFileAgeMat, ['']);
			
				age := age + 5;
			end;
		end;
		
		{Write intervals between union and first conception, and following births}
		if writeResults (res_fert_intervals_conceptions) then
		begin
			aWriteLn(gOutFileFec, ['### Intervals between union and first conception, and intervals between following 4 births, in lunar month (option ' + g_GENPARAM.outputs_opt[res_fert_intervals_conceptions].name + ')']);
			aWriteLn(gOutFileFec, ['Duration', tab, 'First', tab, 'Second', tab, 'Third', tab, 'Fourth', tab, 'Fifth and more']);
			{aggregate births kNumIntervals+1 to kMaxNbChildrenCalc to birth kNumIntervals}
			for duration := 0 to kMaxDurationIntervalsInMonth + 1 do
				for child := kNumIntervals to kMaxNbChildrenCalc-1 do
					gOut_intervals_between_conceptions [g_nRuns-1, kNumIntervals-1, duration] :=
					gOut_intervals_between_conceptions [g_nRuns-1, kNumIntervals-1, duration] +
					gOut_intervals_between_conceptions [g_nRuns-1, child, duration];
			for duration := 0 to kMaxDurationIntervalsInMonth do begin
				aWrite(gOutFileFec, [duration]);
				for child := 0 to kNumIntervals-1 do begin
					if gOut_intervals_between_conceptions [g_nRuns-1, child, kMaxDurationIntervalsInMonth + 1] > 0 then
						gOut_intervals_between_conceptions [g_nRuns-1, child, duration] :=
						gOut_intervals_between_conceptions [g_nRuns-1, child, duration] /
						gOut_intervals_between_conceptions [g_nRuns-1, child, kMaxDurationIntervalsInMonth + 1]
					else
						gOut_intervals_between_conceptions [g_nRuns-1, child, duration] := 0;

					aWrite(gOutFileFec, [tab, gOut_intervals_between_conceptions [g_nRuns-1, child, duration]]);
				end;
				aWriteLn (gOutFileFec, []);
			end;
			aWriteLn(gOutFileFec, ['nbIntervals']);
			for child := 0 to kNumIntervals-1 do
				aWrite (gOutFileFec, [tab,
									gOut_intervals_between_conceptions [g_nRuns-1, child, kMaxDurationIntervalsInMonth + 1]]);
			aWriteLn(gOutFileFec, []);
			aWriteLn(gOutFileFec, []);
		end;
		
		{Write intervals}
		if writeResults (res_fert_intervals) then
		begin
			calcIntervals (objOutputFert.OUT_intervals);
					
			aWriteLn(gOutFileFec, ['### Intervals between births (option ' + g_GENPARAM.outputs_opt[res_fert_intervals].name + ')']);
		
			for ageQ := f1519 to f3539 do
			begin
				aWriteLn(gOutFileFec, ['age at union:', ageQuinqToStr (ageQ)]);
				aWrite(gOutFileFec,  ['NumChildren', tab, 'NumWomen', tab]);
				for i := 1 to kMaxNbChildrenCalc do
				begin
					aWrite(gOutFileFec,  [i, tab]);
				end;
				aWriteLn(gOutFileFec, ['']);
			
				for i := 1 to kMaxNbChildrenCalc do
				begin
					aWrite (gOutFileFec, [i, tab]);
					for j := 0 to kMaxNbChildrenCalc do
					begin
						aWrite(gOutFileFec,  [objOutputFert.OUT_intervals [ageQ, i, j], tab]);
					end;
					aWriteLn(gOutFileFec, ['']);
				end;
			end;
		
			for ageQ := fTotal to fTotal do
			begin
				aWriteLn(gOutFileFec, ['age at union:', ageQuinqToStr (ageQ)]);
				aWrite(gOutFileFec,  ['NumChildren', tab, 'NumWomen', tab]);
				for i := i to kMaxNbChildrenCalc do
				begin
					aWrite(gOutFileFec,  [i, tab]);
				end;
				aWriteLn(gOutFileFec, ['']);
			
				for i := 1 to kMaxNbChildrenCalc do
				begin
					aWrite (gOutFileFec, [i, tab]);
					for j := 0 to kMaxNbChildrenCalc do
					begin
						aWrite(gOutFileFec,  [objOutputFert.OUT_intervals [ageQ, i, j], tab]);
					end;
					aWriteLn(gOutFileFec, ['']);
				end;
			end;
		end;
	
		{Duration since last event}
		if writeResults (res_fert_durationPreviousEvent) then
		begin
			calcDurationSinceLastEvent (pData^.durationSinceLastEvent);

			aWriteLn(gOutFileFec, ['### Duration since previous event (option ' + g_GENPARAM.outputs_opt[res_fert_durationPreviousEvent].name + ')']);

			aWrite(gOutFileFec, ['order', tab, 'nbLiveBirths']);
			for j := 0 to 15 do
				aWrite(gOutFileFec, [tab, j]);
			aWriteLn(gOutFileFec, ['']);
			for i := 1 to kMaxNbChildrenCalc do
			begin
				i_1 := i - 1;
				aWrite(gOutFileFec, [i_1, '->', i]);
				aWrite(gOutFileFec, [tab, pData^.durationSinceLastEvent [i, -1]]);
				for j := 0 to 15 do
					aWrite(gOutFileFec, [tab, pData^.durationSinceLastEvent [i, j]]);
				aWriteLn(gOutFileFec, ['']);
			end;
		end;
	
		{age at last child}
		if writeResults (res_fert_LastChild) then
		begin
			calcAgeLastChild (objOutputFert.OUT_lastChildren);
			
			aWriteLn(gOutFileFec, ['### Age at last birth (option ' + g_GENPARAM.outputs_opt[res_fert_LastChild].name + ')']);
			aWriteLn(gOutFileFec, ['Nb Children', tab, 'Nb cases', tab, 'age']);
		
			aWriteLn(gOutFileFec, ['Total', tab, objOutputFert.OUT_lastChildren.distrib [0, 1], tab, objOutputFert.OUT_lastChildren.distrib [0, 2]]);
			for i := 1 to kMaxNbChildrenCalc do
				aWriteLn(gOutFileFec, [i, tab, objOutputFert.OUT_lastChildren.distrib [i, 1], tab, objOutputFert.OUT_lastChildren.distrib [i, 2]]);

			aWriteLn(gOutFileFec, ['Distribution of last birth by age']);
			for ageWomen := kMinAgeFert to kMaxAgeFert do
				aWriteLn(gOutFileFec, [ageWomen, tab, objOutputFert.OUT_lastChildren.Age [ageWomen]]);
		end;
				
		if writeResults (res_fert_GenFert) then
		begin
			aWriteLn(gOutFileFec, ['### Gross general fertility by age and order (option ' + g_GENPARAM.outputs_opt[res_fert_GenFert].name + ')']);
			aWrite(gOutFileFec, ['Age', tab, 'Total'] );
			for i := 1 to kMaxNbChildrenCalc do
				aWrite(gOutFileFec, [tab, i]);
			aWriteLn(gOutFileFec, ['']);

			for ageWomen := kMinAgeFert to kMaxAgeFert do
			begin
				aWrite(gOutFileFec, [ageWomen]);
				for i := 0 to kMaxNbChildrenCalc do
				begin
					aWrite(gOutFileFec, [tab, objUnionTable.pGenFert^[i, any, endedAge50, ageWomen]]);
				end;
				aWriteLn(gOutFileFec, ['']);
			end;
		end;
	
		{Complete Total Fertility and by parity}
		if writeResults (res_fert_CTFR) then
		begin
			pData^.varianceCompFert := pData^.varianceCompFert / pDemReg^.lp[nWomenPar].value - pDemReg^.df [0, any, endedAge50] * pDemReg^.df [0, any, endedAge50];
			aWriteLn(gOutFileFec, ['### Total Fertility (option ' + g_GENPARAM.outputs_opt[res_fert_CTFR].name + ')']);
			aWriteLn(gOutFileFec, ['DF ', tab, pDemReg^.df [0, any, endedAge50], tab, 'Variance DF ', tab, pData^.varianceCompFert]);
			for i := 1 to kMaxNbChildrenCalc do
				aWriteLn(gOutFileFec, ['DF', i , tab, pDemReg^.df [i, any, endedAge50], tab]);
		end;
	
		{Age at childbearing}
		if writeResults (res_fert_AgeChildbearing) then
		begin
			multWriteLn([@gOutFileFec, @gOutFilePPR],  ['### Age at childbearing (option ' + g_GENPARAM.outputs_opt[res_fert_AgeChildbearing].name + ')']);

			multWriteLn([@gOutFileFec, @gOutFilePPR], ['Order', tab, 'firstUnion', tab, 'ever in union', tab, 'total']);			
			if ( pDemReg^.df [0, firstUnion, endedAge50] > 0 ) then begin
				multWrite([@gOutFileFec, @gOutFilePPR],  ['Total', tab, pDemReg^.ageChildbearing [0, firstUnion, endedAge50] / pDemReg^.df [0, firstUnion, endedAge50]]);
			end else begin
				multWrite([@gOutFileFec, @gOutFilePPR],  ['Total', tab, 0.0]);
			end;
			if ( pDemReg^.df [0, everInUnion, endedAge50] > 0 ) then begin
				multWrite([@gOutFileFec, @gOutFilePPR],  [tab, pDemReg^.ageChildbearing [0, everInUnion, endedAge50] / pDemReg^.df [0, everInUnion, endedAge50]]);
			end else begin
				multWrite([@gOutFileFec, @gOutFilePPR],  [tab, 0.0]);
			end;
			if ( pDemReg^.df [0, any, endedAge50] > 0 ) then begin
				multWriteLn([@gOutFileFec, @gOutFilePPR],  [tab, pDemReg^.ageChildbearing [0, any, endedAge50] / pDemReg^.df [0, any, endedAge50]]);
			end else begin
				multWriteLn([@gOutFileFec, @gOutFilePPR],  [tab, 0.0]);
			end;
			for i := 1 to kMaxNbChildrenCalc do begin
				if ( pDemReg^.df [i, firstUnion, endedAge50] > 0 ) then begin
					multWrite([@gOutFileFec, @gOutFilePPR],  [i, tab, pDemReg^.ageChildbearing [i, firstUnion, endedAge50] / pDemReg^.df [i, firstUnion, endedAge50]]);
				end else begin
					multWrite([@gOutFileFec, @gOutFilePPR],  [i, tab, 0.0]);
				end;
				if ( pDemReg^.df [i, everInUnion, endedAge50] > 0 ) then begin
					multWrite([@gOutFileFec, @gOutFilePPR],  [tab, pDemReg^.ageChildbearing [i, everInUnion, endedAge50] / pDemReg^.df [i, everInUnion, endedAge50]]);
				end else begin
					multWrite([@gOutFileFec, @gOutFilePPR],  [tab, 0.0]);
				end;
				if ( pDemReg^.df [i, any, endedAge50] > 0 ) then begin
					multWriteLn([@gOutFileFec, @gOutFilePPR],  [tab, pDemReg^.ageChildbearing [i, any, endedAge50] / pDemReg^.df [i, any, endedAge50]]);
				end else begin
					multWriteLn([@gOutFileFec, @gOutFilePPR],  [tab, 0.0]);
				end;
			end;
		end;
	
		if writeResults (res_fert_fertility_durationUnion) then
		begin
			for ageUnion := kMinAgeUnion to kMaxAgeUnion+1 do begin
				for nUnion := 0 to 2 do begin
					objOutputFert.pFertDuration^ [ageUnion, kMaxShownDurationUnion+1, nUnion] := 0;
					for i:= 0 to kMaxShownDurationUnion do begin
						if objOutputFert.pWomanDuration^ [ageUnion, i, nUnion] > 0 then
							objOutputFert.pFertDuration^ [ageUnion, i, nUnion] := objOutputFert.pBirthDuration^ [ageUnion, i, nUnion] / objOutputFert.pWomanDuration^ [ageUnion, i, nUnion]
						else
							objOutputFert.pFertDuration^ [ageUnion, i, nUnion] := 0;
						objOutputFert.pFertDuration^ [ageUnion, kMaxShownDurationUnion+1, nUnion] := objOutputFert.pFertDuration^ [ageUnion, kMaxShownDurationUnion+1, nUnion] + objOutputFert.pFertDuration^ [ageUnion, i, nUnion];
					end;
				end;
			end;
			aWriteLn (gOutFileFec,  ['### Fertility by duration of union (option ' + g_GENPARAM.outputs_opt[res_fert_fertility_durationUnion].name + ')']);
			aWriteLn (gOutFileFec,  ['Duration', tab, 'all union', tab, 'First Union', tab, 'Other unions']);
			for i:= 0 to kMaxShownDurationUnion do begin
				aWrite (gOutFileFec, [i]);
				for nUnion := 0 to 2 do begin
					aWrite (gOutFileFec, [tab, objOutputFert.pFertDuration^ [kMaxAgeUnion+1, i, nUnion]]);
				end;
				aWriteLn (gOutFileFec, []);
			end;
			aWrite (gOutFileFec, ['ISF']);
			for nUnion := 0 to 2 do begin
				aWrite (gOutFileFec, [tab, objOutputFert.pFertDuration^ [kMaxAgeUnion+1, kMaxShownDurationUnion+1, nUnion]]);
			end;
			aWriteLn (gOutFileFec, []);
		end;
		
		{Final parity, by age and current parity}
		if writeResults (res_fert_FinalParity_parity_age) then
		begin
			aWriteLn(gOutFilePPR,  ['### Parity reached, by age (option ' + g_GENPARAM.outputs_opt[res_fert_FinalParity_parity_age].name + ')']);
			aWrite(gOutFilePPR, ['Age', tab]);
			for i := 0 to kMaxNbChildrenCalc do
				aWrite(gOutFilePPR,  [i , tab, i+1, tab]);
			aWriteLn(gOutFilePPR, ['']);
		
			for age := kMinAgeFert to kMaxAgeFert do
			begin
				aWrite(gOutFilePPR, [age, tab]);
				for i := 0 to kMaxNbChildrenCalc do
					aWrite(gOutFilePPR, [pData^.finalParity [i, age, 0] , tab, pData^.finalParity [i, age, 1] , tab]);
			aWriteLn(gOutFilePPR, ['']);
			end;
		end;

		{Duration without fecundation}
		if writeResults (res_fert_no_fecundation) then begin
			write_no_fecundation (objOutputFert);
		end;

		writeDFprogRatio(pDemReg);
		
	end;

	procedure init_fecGen (
				randomGenerator: TRandomNumberGenerator;							
				mute: boolean;
				pDemReg: pStructDemographicRegimeSettings;
				pData: pComputeGenFertDataGroup;
				objUnionTable: TUnionTable;
				objOutputFert: TOutputFertility;
				var idWoman: longint;
				const arrayChildren: arrayOfInfoChild);
	var
		unionStates: TUnionsType = nil;
		pChildrenList: pInfoChildType = nil;
	
		descFinaleAgeUnion: array[ageQuinq, DistribChildren] of longint; {For women still in union at the age of 50}

		ageWomen: FecundAges;
		ageUnionInt: longint;
		ageUnionReal: double;
		
		i, j: longint;
		fem, numFem, nbChildren: longint;
			
		ageAtUnionQ: ageQuinq;
		duration: longint;
		partnershipStatus: PartnershipStatusesType;
		unionGenState: UnionGenStatesType;
f: TFileType;
		filenameWithPath: string;

	begin {init_fecGen}

		{Init code}
		pData^.varianceCompFert := 0.0;
		if objOutputFert <> nil then objOutputFert.init();
		if objUnionTable <> nil then objUnionTable.init();
	
		for partnershipStatus := neverInUnion to any do
		begin
			for i := 0 to kMaxNbChildren do begin
				pDemReg^.completeFertility[i, partnershipStatus] := 0;
				pDemReg^.parityProgressionRatio[i, partnershipStatus] := 0;
			end;
		end;

		for ageWomen := kMinAgeFert to kMaxAgeFert do
		begin
			for i := 0 to kMaxNbChildrenCalc do
				for partnershipStatus := neverInUnion to any do begin
					pData^.WomenPop[ageWomen, partnershipStatus] := 0;
					for unionGenState := ongoing to endedAge50 do begin
						pData^.childrenAgeTot[ageWomen, i, partnershipStatus, unionGenState] := 0;
					end;
				end;
		end;

		for i := 0 to kMaxNbChildrenCalc do
			for j := -1 to 15 do
				pData^.durationSinceLastEvent [i, j] := 0.0;

		for ageAtUnionQ := f1014 to f5559 do
			for i := 0 to kMaxNbChildren do
				descFinaleAgeUnion[ageAtUnionQ, i] := 0;

		for i := 0 to kMaxNbChildrenCalc do
			for ageUnionInt := kMinAgeFert to kMaxAgeFert do
				for j := 0 to 1 do
					pData^.finalParity [i, ageUnionInt, j] := 0;

		for nbChildren := 0 to kMaxNbChildrenCalc-1 do
			for duration := 0 to kMaxDurationIntervalsInMonth+1 do
				gOut_intervals_between_conceptions [g_nRuns-1, nbChildren, duration] := 0;
				
		if g_GENPARAM.DEBUG.value and not g_GENPARAM.MULTITHREADING.value then begin
			writeDebugHeader ();
		end;

		if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value and not g_silentMode then begin
			memoWriteLn(['======================================================================']);
			memoWriteLn (['================ Writing individual Fertility file ... =============='])
		end;
	
		for ageUnionInt := kMinAgeFert to kMaxAgeFert do
		begin
try // 1
			if g_GENPARAM.FIXED_FERTILITY.value then
				if ageUnionInt = g_FIXED_FERTILITY_DATA.ageUnionWoman then
					numFem := pDemReg^.lp[nWomenPar].value
				else
					numFem := 0
			else
				numFem := round(pDemReg^.lp[nWomenPar].value * pDemReg^.pCurrUnionInfo^.union_women[ageUnionInt]);
			if not mute then memoWriteLn(['Women aged: ', tab, ageUnionInt, tab, 'number: ', tab, numFem]);

			if numFem > 0 then
			begin

				for fem := 1 to numFem do
				begin
					Inc ( idWoman );
try // 2
{*********************************************************************************************************}
					unionStates := TUnionsType.Create (idWoman, woman);
					ageUnionReal := ageUnionInt + randomGenerator.alea(0.0, 0.99999999) - 0.5; // age at union are at midyear
					nbChildren := calcCompleteFertilityWoman(
										randomGenerator,
										pDemReg,
										kNoDeathOfMother,
										kDeathOfFatherPossible,
										ageUnionReal,
										1,
										unionStates,
										pData^.childrenAge,
										pChildrenList,
										unionStates.fecundLife,
										objOutputFert,
										gNilBlock,
										false,
										arrayChildren);
{*********************************************************************************************************}

except // 2
on E: Exception do begin
myHalt([E.Message])
end;
end; // try 2
					if checkFalse (chk_childrenInUnion, nbChildren <> numChildrenInUnion (pChildrenList, 0),
						['counted ', nbChildren, ', in the list ', numChildrenInUnion (pChildrenList, 0)]) then breakOnFailure;
			
					pData^.varianceCompFert := pData^.varianceCompFert + nbChildren * nbChildren;

					Inc ( pDemReg^.completeFertility[nbChildren, unionStates.partnershipStatusAt50] );
					Inc ( pDemReg^.completeFertility[nbChildren, any] );
					if unionStates.partnershipStatusAt50 <> neverInUnion then
						Inc ( pDemReg^.completeFertility[nbChildren, everInUnion] );

					{Intervals duration}
					if nbChildren > 0 then
						addDurationSinceLastEvent (pData^.durationSinceLastEvent, pChildrenList, unionStates);
			
					{Current parity, parity achieved}
					processParity (nbChildren, pChildrenList, pData^.finalParity);

					if (objOutputFert <> nil) and (unionStates.partnershipStatusAt50 = firstUnion) then
					begin
						addIntervals (unionStates, pChildrenList, objOutputFert.OUT_intervals);
						addAgeLastChild (nbChildren, objOutputFert.OUT_lastChildren, pChildrenList);
													descFinaleAgeUnion[toAgeQuinq (ageUnionInt), nbChildren] :=
																				  descFinaleAgeUnion[toAgeQuinq (ageUnionInt), nbChildren] + 1;
						Inc ( objOutputFert.TOT_descFinaleAgeUnion[toAgeQuinq (ageUnionInt), nbChildren, gParam_descFinaleAgeUnion] );
					end;

					incrementPopWomen_Children(unionStates, pData^.childrenAge, pData^.WomenPop, pData^.childrenAgeTot);
			
					if g_GENPARAM.FERTILITY.value then
						incrementIntervConc (unionStates, pChildrenList, gOut_intervals_between_conceptions);
								
					{the 'modern' way to compute propSeparation}
					incrementTableUnions (unionStates, pChildrenList, objUnionTable);
				
					incrementFertDuration (unionStates, pChildrenList, objOutputFert);
				
					if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value and not g_silentMode then begin
						write_INDIVIDUAL_INFO (pDemReg, idWoman, unionStates, pChildrenList);
					end;
	
					disposeChild ( pChildrenList );
					FreeAndNil ( unionStates );
				end; {for fem := 1 to numFem do}

			end; {if numFem > 0 then}
except // 1
	on E: Exception do begin
	myHalt([E.Message])
	end;
end;

		end; {for ageUnionInt := kMinAgeFert to kMaxAgeFert do}

		if g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value and not g_silentMode then begin
			filenameWithPath := gPathToResult + g_FileName.value + '_INDIVIDUAL_FERTILITY_INFO.CSV';
			gOutFileIndivFec.myCloseFile;
			if (g_GENPARAM.ZIP_INDIVIDUAL.value) then
				zipIt (filenameWithPath);
			memoWriteLn (['============================== ... done! ============================']);
			memoWriteLn (['=====================================================================']);
		end;

		{women who never get in a union}
		numFem := pDemReg^.lp[nWomenPar].value - pData^.WomenPop[kMinAgeUnion, any];
		for ageWomen := kMinAgeFert to kMaxAgeFert do begin
			pData^.WomenPop [ageWomen, neverInUnion] := pData^.WomenPop [ageWomen, neverInUnion] + numFem;
			pData^.WomenPop [ageWomen, any] := pData^.WomenPop [ageWomen, any] + numFem;
		end;

if g_GENPARAM.DEBUG.value and not g_GENPARAM.MULTITHREADING.value then begin
	if ( openFileOut(g_FileName.value + '_statusTable.txt', 'STATUSTABLE', f, kAsyncFalse) ) then begin
		writePartnershipStatusTable (f, pData^.WomenPop, true);
		f.Destroy;
	end;
end;
		
		{the 'modern' way to compute propSeparation}
		pData^.propFinalSeparation := separationFinalProp(objUnionTable);
	
	end; {init_fecGen}

	procedure findCorrectPropSeparation (
					randomGenerator: TRandomNumberGenerator;							
					pDemReg: pStructDemographicRegimeSettings;
					objUnionTable: TUnionTable;
					objOutputFert: TOutputFertility;
					const arrayChildren: arrayOfInfoChild;
					pData: pComputeGenFertDataGroup);
	const
		maxIterationFindSeparation = 20;
	
	type
		convSteps = -1..maxIterationFindSeparation;
		convValues = (prior, post);

	var
		nWomen_mem: longint;
		OUTPUT_INDIVIDUAL_FERTILITY_INFO_mem: boolean;
		equal_objectif_resultat_separation: boolean;
		nIterSeparation: longint;
		// we use this array to converge to the 'true' value of apriori separation proportion
		history: array[convValues, convSteps] of double;
		temp, prov_freqSeparation, diff_objective_approx, best_prov_freqSeparation, factorConv: double;
		idWoman: longint;
		
		function iterValue(): double;
		var
			alpha, minv1, minv2, freq, iterValue_result: double;
		begin
		// objective: pDemReg^.separationInfo.freqSeparation
			alpha := 	( history[post, nIterSeparation-2] - pDemReg^.separationInfo.freqSeparation ) /
						( history[post, nIterSeparation-2] - history[post, nIterSeparation-1] );
  
			if (alpha < 0.01) then alpha := 0.01;
					
			iterValue_result := history[prior, nIterSeparation-2] - alpha * (history[prior, nIterSeparation-2] - history[prior, nIterSeparation-1]);
			if (iterValue_result <= 0) or (iterValue_result >= 1) then
			begin
				if ( (history[post, nIterSeparation-2] > pDemReg^.separationInfo.freqSeparation) and
					(history[post, nIterSeparation-1] > pDemReg^.separationInfo.freqSeparation) ) or
				   ( (history[post, nIterSeparation-2] < pDemReg^.separationInfo.freqSeparation) and
				   (history[post, nIterSeparation-1] < pDemReg^.separationInfo.freqSeparation) ) then
				begin
					minv1 := min(history[prior, nIterSeparation-2], history[prior, nIterSeparation-1]);
					minv2 := min(history[post, nIterSeparation-2], history[post, nIterSeparation-1]);
					freq := pDemReg^.separationInfo.freqSeparation;
					iterValue_result := minv1 * freq / minv2;
				end else begin
					iterValue_result := ( history[prior, nIterSeparation-2] + history[prior, nIterSeparation-1] ) / 2.0;
				end;
			end;
			iterValue := iterValue_result;
		end;

		function goodValueSep (calc, target: double; iter: longint = 1): boolean;
		const
			maxIterationFindSeparation = 20;
			threshold_absolute = 0.003;
			threshold_relative = 0.015;
		var
			diff: double;

		begin
			diff := abs(calc - target);
			if	( diff < threshold_absolute ) or
				( (diff / target) < threshold_relative ) then
				exit (true);
			if (iter > maxIterationFindSeparation) then
				exit (true);
			exit (false);
		end;
		
		label onExit;
		
	begin {findCorrectPropSeparation}

		// If there is no separation or everybody separates, no need to search for the right a priori value
		if (pDemReg^.separationInfo.freqSeparation = 0) or (pDemReg^.separationInfo.freqSeparation = 1) then exit;
		// We do not try to adjust freqSeparation and treat it as 'apriori' risk
		if g_GENPARAM.SEP_TARGET.value = false then exit;
	
		nWomen_mem := pDemReg^.lp[nWomenPar].value;
		pDemReg^.lp[nWomenPar].value := g_GENPARAM.RUNTIME[cmd_numberWomen].value;
		OUTPUT_INDIVIDUAL_FERTILITY_INFO_mem := g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value;
		g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value := FALSE;

		idWoman := 0;
		nIterSeparation := 1;
		equal_objectif_resultat_separation := FALSE;
		// very approximate factor for multiplying input level in order to obtain apriori value
		factorConv := 1.1 + pDemReg^.DF_apriori / 30;
		diff_objective_approx := 1000; // high initial value to get it working
		prov_freqSeparation := 0.1; // an init value
		// we monitor the best approximation obtained during the iteration
		if g_GENPARAM.FORCE_SEP_ITER.value then
			best_prov_freqSeparation := 0
		else begin
			best_prov_freqSeparation := pDemReg^.dp[freqSeparationFirstIteration].value;
			calcSeparation (best_prov_freqSeparation, pDemReg^.separationInfo);
			// Copy it so we can write it in the dump file if needed
			pDemReg^.dp[freqSeparationFirstIteration].value := best_prov_freqSeparation;
			// again
			pDemReg^.separationInfo.freqSeparation_adjusted := best_prov_freqSeparation;
			// result value
			pDemReg^.separationInfo.freqSeparation_result := pData^.propFinalSeparation;
			goto onExit;
		end;
		if (pDemReg^.dp[freqSeparationFirstIteration].value > 0) then
		begin
		// the user has given a value for the first step
			prov_freqSeparation := pDemReg^.dp[freqSeparationFirstIteration].value;
			// we try it
			calcSeparation(prov_freqSeparation, pDemReg^.separationInfo);
			init_fecGen (randomGenerator, true, pDemReg, pData, objUnionTable, objOutputFert, idWoman, arrayChildren);

			memoWriteLn([pDemReg^.yearOfBirth.value, ': iterating propSeparation: ', nIterSeparation, ' objective: ',
				pDemReg^.separationInfo.freqSeparation, ' apriori prop: ', prov_freqSeparation, ' (saved) approximation: ', pData^.propFinalSeparation]);
			
			if goodValueSep (pData^.propFinalSeparation, pDemReg^.separationInfo.freqSeparation) then
			begin
				// good we exit
				pDemReg^.separationInfo.freqSeparation_adjusted := pDemReg^.dp[freqSeparationFirstIteration].value;
				pDemReg^.separationInfo.freqSeparation_result := pData^.propFinalSeparation;
				goto onExit;
			end;
			history[prior, -1] := pDemReg^.dp[freqSeparationFirstIteration].value;
			history[post, -1] := pData^.propFinalSeparation;
			history[prior, 0] := min(pDemReg^.dp[freqSeparationFirstIteration].value * factorConv, 0.99);
			history[post, 0] := min(pData^.propFinalSeparation * factorConv, 0.99);
			Inc ( nIterSeparation );
		end else begin
		// no initial value
			history[prior, -1] := min(pDemReg^.separationInfo.freqSeparation * factorConv, 0.99);
			history[post, -1] := pDemReg^.separationInfo.freqSeparation;
			history[prior, 0] := min(pDemReg^.separationInfo.freqSeparation * factorConv * 1.1, 0.95);
			history[post, 0] := min(pDemReg^.separationInfo.freqSeparation * factorConv, 0.90);
		end;

		while ( (prov_freqSeparation > 0) and (prov_freqSeparation < 1) and
				(equal_objectif_resultat_separation = FALSE) and
				(g_GENPARAM.fixedParameters[homogeneousSeparation].state.value = FALSE)
				) do begin
			prov_freqSeparation := IterValue();
			calcSeparation(prov_freqSeparation, pDemReg^.separationInfo);
			init_fecGen (randomGenerator, true, pDemReg, pData, objUnionTable, objOutputFert, idWoman, arrayChildren);
		
			memoWriteLn([pDemReg^.yearOfBirth.value, ': iterating propSeparation: ', nIterSeparation, ' objective: ',
				pDemReg^.separationInfo.freqSeparation, ' apriori prop: ', prov_freqSeparation, ' approximation: ', pData^.propFinalSeparation]);
			
			history[prior, nIterSeparation] := prov_freqSeparation;
			history[post, nIterSeparation] := pData^.propFinalSeparation;
			// keep the best value
			if (abs (pData^.propFinalSeparation - pDemReg^.separationInfo.freqSeparation) < diff_objective_approx) then begin
				diff_objective_approx := abs (pData^.propFinalSeparation - pDemReg^.separationInfo.freqSeparation);
				best_prov_freqSeparation := prov_freqSeparation;
			end;
			Inc ( nIterSeparation );
			equal_objectif_resultat_separation :=
					goodValueSep (
						pData^.propFinalSeparation,
						pDemReg^.separationInfo.freqSeparation,
						nIterSeparation);
		end;

		// Use best value
		if (prov_freqSeparation <> best_prov_freqSeparation) then
			calcSeparation (best_prov_freqSeparation, pDemReg^.separationInfo);
		// Copy it so we can write it in the dump file if needed
		pDemReg^.dp[freqSeparationFirstIteration].value := best_prov_freqSeparation;
		// again
		pDemReg^.separationInfo.freqSeparation_adjusted := best_prov_freqSeparation;
		// result value
		pDemReg^.separationInfo.freqSeparation_result := pData^.propFinalSeparation;
		
		if ( not goodValueSep (pData^.propFinalSeparation, pDemReg^.separationInfo.freqSeparation) ) then
		begin
			memoWriteLn(['No convergence: objective: ',
			pDemReg^.separationInfo.freqSeparation, ' apriori prop: ', best_prov_freqSeparation, ' difference: ', diff_objective_approx]);
		end;

onExit:		
		pDemReg^.lp[nWomenPar].value := nWomen_mem;
		g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value := OUTPUT_INDIVIDUAL_FERTILITY_INFO_mem;
	end;  {findCorrectPropSeparation}

		
	procedure computeGenFert (
					randomGenerator: TRandomNumberGenerator;							
					pDemReg: pStructDemographicRegimeSettings;
					objOutputFert: TOutputFertility;
					objUnionTable: TUnionTable;
					var idWoman: longint;
					const arrayChildren: arrayOfInfoChild;
					isInitFertility: boolean = false);
	var
		computeGenFertData: computeGenFertDataGroup;
		
var
		{utility}
		ind, ind1: longint;
temp : double;
		
	a, b, c: double;
	CTFR_result: double;
	useOdds: boolean = false;
	idWomanTemp: longint = 1;
	factHighOrder: double;
	iterFec: longint;
	targetCTFR, distanceCTFR, bestDistance: double;
	bestIteration, nParityNotReached: longint;
	bestPPR: array of double;
	keptDiffers: boolean;

	begin {computeGenFert}
try
	if not g_GENPARAM.FIXED_FERTILITY.value then
		findCorrectPropSeparation(randomGenerator, pDemReg, objUnionTable, objOutputFert, arrayChildren, @computeGenFertData);
except
	on E: Exception do begin
	myHalt([E.Message])
	end;
end;
try
		init_fecGen (randomGenerator, g_silentMode, pDemReg, @computeGenFertData, objUnionTable, objOutputFert, idWoman, arrayChildren);
except
	on E: Exception do begin
	myHalt([E.Message])
	end;
end;

		compute_fecGen_tables(pDemReg, @computeGenFertData, objUnionTable);

		if 	isInitFertility and
			((g_GENPARAM.PPR_TARGET.value and not pDemReg^.adjustedValues) or
			(g_GENPARAM.FORCE_PPR_TARGET.value)) then begin
		// adjust a priori PPR in order to get them closer to the input values
		// we do it only in a few passes but do not iterate until converging, like we do for separation risk
			
			{**N7 fixed here.** The adjustment nudges the a priori parity progression ratios so
			 that the ratios the simulation produces come closer to the ones asked for. Three
			 faults are corrected.

			 (a) A parity no woman reached. b is the ratio the simulation produced, and it is
			 zero when the parity was never reached, which is the normal state of the higher
			 parities. The old line replaced that zero by 0.00001, so the factor c / b became c
			 times one hundred thousand and the clamp turned the adjusted ratio into 0.99999:
			 the model was told that progression at that parity is all but certain, on the
			 evidence of nobody. Such a parity is now skipped and its adjusted value left as it
			 was, since a simulation that reached nobody says nothing about progression from
			 there.

			 (b) The higher parities. The second loop reused whatever factHighOrder the first
			 loop happened to leave behind, that is the factor of the LAST parity it touched,
			 reached or not. With (a) in place that would now be the factor of the last parity
			 that was actually reached, but relying on the leftover value of a loop variable is
			 what made the fault possible, so the factor is kept explicitly. When no parity at
			 all was reached the factor is 1, which leaves the higher parities alone.

			 (c) No convergence test. The loop ran four times whatever happened, kept the last
			 iterate whether or not it was the best, and set adjustedValues inside itself, so a
			 later run took the adjusted values as settled even when the last pass was the worst
			 of the four. The distance between the cohort total fertility the adjusted ratios
			 produce and the one asked for is now measured at each pass, the best pass is kept,
			 and the loop stops as soon as the distance is within kPPRTargetTolerance. If the
			 best pass is not the last, the tables are rebuilt from it before the routine
			 returns, so what the run uses is what the report names.

			 The memo line at the end says which pass was kept, how far it landed from the
			 target, and how many parities were skipped for want of anyone reaching them.}
			targetCTFR := computeTFRfromPPRs (pDemReg^.aPrioriPPR);
			bestDistance := kNotDefined;
			bestIteration := 0;
			nParityNotReached := 0;
			SetLength (bestPPR{%H-}, kMaxNbChildren + 1);
			for iterFec := 1 to kMaxIterationsPPR do begin
				if g_GENPARAM.TALKATIVE.value then
					memoWriteLn (['Iteration CTFR: ', iterFec, ', cohort: ', pDemReg^.yearOfBirth.value]);
				factHighOrder := 1.0;	{the factor of the last parity actually reached}
				for ind := 0 to kMaxNbChildrenCalc do begin
					c := pDemReg^.aPrioriPPR.value[ind];
					a := pDemReg^.aPrioriPPR_adjusted.value[ind];
					// This are the values computed in a previous step
					// First parityProgressionRatio value is for transition to union, so we add 1 to index
					b := pDemReg^.parityProgressionRatio[ind+1, everInUnion];

					ind1 := ind + 1;
					if g_GENPARAM.TALKATIVE.value then
						memoWriteLn (['p', ind, '->', ind1, ' Tgt: ', c, ' adj: ', a, ' res: ', b]);

					if (b <= 0.0) then begin
						{nobody reached this parity: nothing to learn, so nothing to adjust}
						Inc (nParityNotReached);
						continue;
					end;

					if (useOdds) then begin
						// one option is to use odds in order to limit to [0, 1]
						// first a sanity check
						if (a >= 1) then
							a := 0.99999;
						if (b >= 1) then
							b := 0.99999;
						factHighOrder := (c / (1-c)) / (b / (1-b));
						a := (a / (1-a)) * factHighOrder;
						a := (a / (1+a));
					end else begin
						// a simpler way of doing it
						factHighOrder := c / b;
						a := a * factHighOrder;
						// sanity check at the end..
						if a > 1 then a := 0.99999;
					end;

					pDemReg^.aPrioriPPR_adjusted.value[ind] := a;
				end;
				// the factor of the last parity that was reached is extended to higher parities
				for ind := kMaxNbChildrenCalc+1 to kMaxNbChildren do begin
					c := pDemReg^.aPrioriPPR.value[ind];
					a := pDemReg^.aPrioriPPR_adjusted.value[ind];
					if useOdds then begin
						a := (a / (1-a)) * factHighOrder;
						a := (a / (1+a));
					end else begin
						a := a * factHighOrder;
						if a > 1 then a := 1;
					end;
					pDemReg^.aPrioriPPR_adjusted.value[ind] := a;
				end;

				adjustContraception (pDemReg);
				pDemReg^.DF_apriori := compute_aprioriDF(pDemReg);
				init_fecGen (randomGenerator, g_silentMode, pDemReg, @computeGenFertData, objUnionTable, objOutputFert, idWomanTemp, arrayChildren);
				compute_fecGen_tables(pDemReg, @computeGenFertData, objUnionTable);

				{how far this pass landed from the target, and keep it if it is the best so far}
				distanceCTFR := abs (computeTFRfromPPRs (pDemReg^.aPrioriPPR_result) - targetCTFR);
				if (bestIteration = 0) or (distanceCTFR < bestDistance) then begin
					bestDistance := distanceCTFR;
					bestIteration := iterFec;
					for ind := 0 to kMaxNbChildren do
						bestPPR[ind] := pDemReg^.aPrioriPPR_adjusted.value[ind];
				end;
				if (distanceCTFR <= kPPRTargetTolerance) then break;
 			end; {for iterFec}

			{rebuild from the best pass when the last one was not it}
			if (bestIteration > 0) then begin
				keptDiffers := false;
				for ind := 0 to kMaxNbChildren do
					if (pDemReg^.aPrioriPPR_adjusted.value[ind] <> bestPPR[ind]) then
						keptDiffers := true;
				if keptDiffers then begin
					for ind := 0 to kMaxNbChildren do
						pDemReg^.aPrioriPPR_adjusted.value[ind] := bestPPR[ind];
					adjustContraception (pDemReg);
					pDemReg^.DF_apriori := compute_aprioriDF(pDemReg);
					init_fecGen (randomGenerator, g_silentMode, pDemReg, @computeGenFertData, objUnionTable, objOutputFert, idWomanTemp, arrayChildren);
					compute_fecGen_tables(pDemReg, @computeGenFertData, objUnionTable);
				end;
				pDemReg^.adjustedValues := true;
				memoWriteLn (['PPR adjustment, cohort ', pDemReg^.yearOfBirth.value,
						': pass ', bestIteration, ' of ', iterFec, ' kept, cohort total fertility ',
						str_float (bestDistance), ' from the target of ', str_float (targetCTFR),
						'. Parities skipped for want of anyone reaching them: ', nParityNotReached]);
			end;
			SetLength (bestPPR, 0);
 
 			pDemReg^.CTFR.value := computeTFRfromPPRs (pDemReg^.aPrioriPPR);
 			pDemReg^.CTFR_adjusted.value := computeTFRfromPPRs (pDemReg^.aPrioriPPR_adjusted);
 			CTFR_result := computeTFRfromPPRs (pDemReg^.aPrioriPPR_result);
 			
			if g_GENPARAM.TALKATIVE.value then
				memoWriteLn (['result for: ', pDemReg^.yearOfBirth.value]);
		   	for ind := 0 to kMaxNbChildrenCalc do begin
				c := pDemReg^.aPrioriPPR.value[ind];
  				a := pDemReg^.aPrioriPPR_adjusted.value[ind];
  				// This are the values computed in a previous step
  				// First parityProgressionRatio value is for transition to union, so we add 1 to index
  				b := pDemReg^.parityProgressionRatio[ind+1, everInUnion];
				ind1 := ind + 1;
				if g_GENPARAM.TALKATIVE.value then
  					memoWriteLn (['p', ind, '->', ind1, ' Tgt: ', c, ' adj: ', a, ' res: ', b]);
  			end;
  			memoWriteLn (['Iterated CTFR value for cohort: ', pDemReg^.yearOfBirth.value, ', CTFR tgt: ', pDemReg^.CTFR.value, ' adj: ', pDemReg^.CTFR_adjusted.value, ' res: ', CTFR_result]);
		end;
		
		if g_GENPARAM.FERTILITY.value and not g_silentMode then
			write_fecGen_tables(
				pDemReg,
				objUnionTable, objOutputFert, @computeGenFertData
			);

	end; {computeGenFert}

	procedure calcGrowthRate (pDemReg: pStructDemographicRegimeSettings; objUnionTable: TUnionTable);
		var
			ageWomen: FecundAges;
			sum, tnr, Total_NetFertility: double;
            fWomen: double;
	begin
		pDemReg^.r := intrinsicRate (pDemReg, objUnionTable);

		sum := 0;
		tnr := 0.0;
		screenFileWriteLn(cStringOf(['======================================================================']));
		screenFileWriteLn(cStringOf(['Net general fertility by age']));
		for ageWomen := kMinAgeFert to kMaxAgeFert do
			begin
				Total_NetFertility := objUnionTable.pGenFert^[0, any, endedAge50, ageWomen] * pDemReg^.mortalityInfo.survivalAdult_women[ageWomen];
				tnr := tnr + Total_NetFertility * pDemReg^.dp[propWomenAtBirth].value;
				screenFileWriteLn(cStringOf([ageWomen, tab, Total_NetFertility]));
				pDemReg^.distribStableFert^[ageWomen] := Total_NetFertility * exp(-pDemReg^.r * (ageWomen + 0.5));
				sum := sum + pDemReg^.distribStableFert^[ageWomen];
			end;
		pDemReg^.distribStableFert^[kMinAgeFert] := pDemReg^.distribStableFert^[kMinAgeFert] / sum;
		for ageWomen := kMinAgeFert + 1 to kMaxAgeFert do begin
			pDemReg^.distribStableFert^[ageWomen] := pDemReg^.distribStableFert^[ageWomen - 1] + pDemReg^.distribStableFert^[ageWomen] / sum;
		end;
		{sum: rapport de masculinité à la naissance}
		sum := 1.0 / sum;

		pDemReg^.distribStableFert^[kMaxAgeFert] := 1.0;
		
		ageWomen := kMaxAgeFert;
		while (pDemReg^.distribStableFert^[ageWomen] = pDemReg^.distribStableFert^[ageWomen - 1]) do
			begin
				pDemReg^.distribStableFert^[ageWomen] := 1.0;
				ageWomen := ageWomen - 1;
			end;
		screenFileWriteLn(cStringOf(['Growth rate (per thousand): ', tab, 1000.0 * pDemReg^.r, tab, 'Net reproduction rate: ', tab, tnr]));
	end;

	procedure calcFecGenNuptMas (
								randomGenerator: TRandomNumberGenerator;							
								pDemReg: pStructDemographicRegimeSettings;
								objOutputFert: TOutputFertility;
								objUnionTable: TUnionTable;
								computeDemReg: boolean;
								var idWoman: longint;
								const arrayChildren: arrayOfInfoChild;
								isInitFertility: boolean = false);
	begin
try
		screenFileWriteLn('General fertility, with survival of the mother up to 50 years after the birth of ego');

		adjustContraception (pDemReg);
		writeSMAM(pDemReg);

		pDemReg^.DF_apriori := compute_aprioriDF(pDemReg);
		if computeDemReg then begin
			computeGenFert(randomGenerator, pDemReg, objOutputFert, objUnionTable, idWoman, arrayChildren, isInitFertility);
			calcGrowthRate (pDemReg, objUnionTable);
		end;
		
except
	on E: Exception do begin
	myHalt([E.Message])
	end;
end;
	end;

end.
