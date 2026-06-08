{$I Defines.pas}
unit FertilityRuntime;


interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, DemographicRegime, Mortality, Fertility, StablePop, Parenthood, Nuptiality, Utilities, RandomNumbers, StringResources, StringOfLib,
	{$IFDEF VerboseProfiler}Profiler,{$ENDIF} Math, SysUtils;

	procedure writeGeneralTables (objOutputFert: TOutputFertility);
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
							out ageChildren: TabCompFertAge;
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
{$IFDEF DEBUG}
		mem_ages, mem_ages2, mem_ages3: TabAgeEvents;
{$ENDIF}

	begin
		result := true;
		
{$IFDEF DEBUG}
if gRunFromIDE then
	move (ageDurationEvents.ages, mem_ages{%H-}, sizeOf(mem_ages));
{$ENDIF}

		{woman's age at first union}
		ageDurationEvents.ages[le_union, woman] := max ( kMinAgeUnion, ageDurationEvents.ages[le_union, woman] );

{$IFDEF DEBUG}
if (ageDurationEvents.ages[le_union, woman] > 75) then
	writeAndWait ('ERROR ==> ageDurationEvents.ages[le_union, woman] greater than 75 in initPartnershipLife');
{$ENDIF}

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

{$IFDEF DEBUG}
if gRunFromIDE then
	move (ageDurationEvents.ages, mem_ages2{%H-}, sizeOf(mem_ages));
{$ENDIF}

		{Age at death of the man}
		{age at death are NOT at midyear}
		if deathMan and (ageDurationEvents.ages[le_death, man] = kNotDefined) then
		begin
			{Year of death of man}
			cohort_man := pDemReg^.yearOfBirth.value - trunc (ageDurationEvents.ages[le_union, man] - ageDurationEvents.ages[le_union, woman]);
			ageDurationEvents.ages[le_death, man] := max (ageDurationEvents.ages[le_union, man] + 0.1,
					calc_ageDeath(randomGenerator, trunc (ageDurationEvents.ages[le_union, man]), getCohort_p(cohort_man)^.mortalityInfo.survival_men)
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
						calc_ageDeath(randomGenerator, trunc (ageDurationEvents.ages[le_union, woman]), pDemReg^.mortalityInfo.survival_women)
					);
			if g_GENPARAM.FIXED_FERTILITY.value and (ageDurationEvents.ages[le_death, woman] < 40) then
				ageDurationEvents.ages[le_death, woman] := 40;
			end;
{$IFDEF DEBUG}
if gRunFromIDE then
	move (ageDurationEvents.ages, mem_ages3{%H-}, sizeOf(mem_ages));
{$ENDIF}
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
if gRunFromIDE then
{$IFNDEF ARM}
	asm int 3 end;
{$ELSE}
	assert(true,E.Message)
{$ENDIF}
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

	procedure addChild (age: FecundAges; order: DistribChildrenCalc; number: longint; out ageChildren: TabCompFertAge);
	begin
		ageChildren[age, 0] := ageChildren[age, 0] + number;
		ageChildren[age, order] := ageChildren[age, order] + number;
	end;
				
	function fixedNumChildren (
							randomGenerator: TRandomNumberGenerator;							
							pDemReg: pStructDemographicRegimeSettings;
							var unionStates: TUnionsType;
							out ageChildren: TabCompFertAge;
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
					ageDeath := calc_ageDeath(randomGenerator, 0, pDemReg^.mortalityInfo.survival_men)
				else
					ageDeath := calc_ageDeath(randomGenerator, 0, pDemReg^.mortalityInfo.survival_women);

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
							out ageChildren: TabCompFertAge;
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
			pPreviousChild: pInfoChildType;
			currAge: FecundAges;
			monthStart, monthEnd, currMonth: longint;
			month: longint;
			monthIncrement: longint = 0;
			nbPregnanciesInCurrentUnion: longint;
			
			testStopping: boolean;
			endUnion: boolean;

			procedure paramSeparation;
			var
				durationUnionWoman: double;
			begin
			{DEBUG: CHECK CURRMONTH COUNT SINCE BIRTH}
				ageDurationEvents.ages[le_endUnion, woman] := lunarMonthsToAge (currMonth);
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
				ageDurationEvents.durations.durationUnionInMonthsWithSeparation := currMonth - monthStart + 1;
				if (ageDurationEvents.durations.durationUnionInMonthsWithSeparation < ageDurationEvents.durations.durationUnionInMonths) then
					ageDurationEvents.durations.durationUnionInMonths := ageDurationEvents.durations.durationUnionInMonthsWithSeparation;
				if
					((ageDurationEvents.ages[le_death, woman] > 0) and
					(ageDurationEvents.ages[le_death, woman] < ageDurationEvents.ages[le_endUnion, woman])) or
					((ageDurationEvents.ages[le_death, man] > 0) and
					(ageDurationEvents.ages[le_death, man] < ageDurationEvents.ages[le_endUnion, man])) then begin
if gRunFromIDE then
{$IFNDEF ARM}
	asm int 3 end;
{$ELSE}
	assert(true);
{$ENDIF}
					writeAndWaitConst(['===> ERROR: age at death inferior to age at end union for one of the partners']);
				end;
			end;

			function waiting_time_contraception (
							pDemReg: pStructDemographicRegimeSettings;
							const AccDurationContr: array of double;
							propContraception: double;
							monthEnd: longint;
							var wt_currMonth: longint): longint;
			var
				month: longint;
				aleaContraception: double;
			begin
				waiting_time_contraception := 0;
				aleaContraception := randomGenerator.alea0;
				if ( AccDurationContr [0] < 1.0 ) and ( aleaContraception < propContraception) and (wt_currMonth <= monthEnd) then
				begin
					aleaContraception := randomGenerator.alea0;
					month := 0;
					while	(wt_currMonth <= monthEnd) and
							(aleaContraception > AccDurationContr [month]) and
							(not endUnion) and
							( effectivenessContraceptionStopping(pDemReg, nbChildren) >= randomGenerator.alea0 ) do
					begin
						if pDemReg^.separationInfo.separationPossible and
							endBySeparation (randomGenerator, monthStart, currMonth, nbPregnanciesInCurrentUnion,
								pCurrChild, pDemReg^.separationInfo, pDemReg^.dp, unionStates)
						then begin
							paramSeparation;
							ageDurationEvents.monthStop := min (wt_currMonth, ageDurationEvents.monthStop);
							ageDurationEvents.monthStopIsStopping := false;
						end else begin
							Inc ( month );
							Inc ( wt_currMonth );
						end;
					end;
					waiting_time_contraception := month;
				end;
			end;
			
			function pregnancy (	pDemReg: pStructDemographicRegimeSettings;
									var pCurrChild: pInfoChildType;
									monthEnd: longint;
									var wt_currMonth: longint): longint;
			var
				dummy: double;
				currAge: FecundAges;
				durationPregnancyInMonths: longint;
				
				function AbortionOrStillBorn (nonSusceptiblePeriod: longint): longint;
				begin
					newChild (pCurrChild, arrayChildren);

					with pCurrChild^ do
					begin
						livingAtBirth := false;
						birthOrder := 0;
						ageMotherAtChildbirth := lunarMonthsToAge (wt_currMonth + nonSusceptiblePeriod);
						ageFatherAtChildbirth := calcAgeFatherAtChildbirth (ageMotherAtChildbirth, currUnion, unionStates);
						{DEBUG: CURIOUS NEGATIVE?? CHECK}
						ageDeath := lunarMonthsToAge (nonSusceptiblePeriod - kLivingBirth_durationPregnancyInMonths);
						
						{date ---}
						monthEndPregnancy := wt_currMonth + nonSusceptiblePeriod;
						durationUnion := wt_currMonth - monthStart + nonSusceptiblePeriod;
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
					month: longint;
					maxMonthDeathChild: longint;
					nbBirthsInDelivery, indBirthInDelivery: longint;
					sexNewBorn: Sex;

				begin {LivingBirth}					
					testStopping := true;
					currAge := trunc ( lunarMonthsToAge (currMonth + kLivingBirth_durationPregnancyInMonths) ); {Age at birth}

					nbBirthsInDelivery := multipleBirths ( currAge );

					{amenorrea post-partum}
					dummy := randomGenerator.alea0;
					month := 10;
					while dummy < pDemReg^.temporary_sterility[month - 10] do
						Inc ( month );
					
					{Case of the possible early death of the newborn, before weaning,
					which may shorten the temporary sterility period}
					maxMonthDeathChild := 0;
					for indBirthInDelivery := 1 to nbBirthsInDelivery do begin // we take care of multiple births
						sexNewBorn := sexAtBirth (randomGenerator, pDemReg, 0);
						if sexNewBorn = woman then
						begin
							ageDeathChild := calc_ageDeath (randomGenerator, 0, pDemReg^.mortalityInfo.survival_women);
							if ageDeathChild < 4 then
								ageDeathChild := calc_ageDeath0_3years ( randomGenerator,
														trunc (ageDeathChild),
														pDemReg^.mortalityInfo.survival_women );
						end else
						begin
							ageDeathChild := calc_ageDeath (randomGenerator, 0, pDemReg^.mortalityInfo.survival_men);
							if ageDeathChild < 4 then
								ageDeathChild := calc_ageDeath0_3years (randomGenerator, trunc (ageDeathChild), pDemReg^.mortalityInfo.survival_men );
						end;
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

					LivingBirth := min (month, maxMonthDeathChild + 1);
					
				end; {LivingBirth}
				
			begin {pregnancy}
				pregnancy := 1; // number of months of non susceptible period
				{CONCEPTION}
				Inc ( nbPregnanciesInCurrentUnion );
				{We look to see if we have a spontaneous abortion / intrauterine death or a stillborn or live birth}
				dummy := randomGenerator.alea0;
				currAge := trunc ( lunarMonthsToAge (wt_currMonth) ); {Age at conception} {DEBUG check whether currMonth start from birth}
				
				if (dummy < gIntrauterine_mortality_risk[currAge] + gStillbirth_mortality_risk[currAge]) then
				begin
					if (dummy < gIntrauterine_mortality_risk[currAge]) then
					begin
						{spontaneous abortion}
						dummy := randomGenerator.alea0;
						durationPregnancyInMonths := 1;
						while dummy > gDistrib_intrauterine_mortality_risk[durationPregnancyInMonths] do
							Inc ( durationPregnancyInMonths );
						
						pregnancy := AbortionOrStillBorn (kIntrauterineMort_NonSusceptPeriod_minInMonths + durationPregnancyInMonths);
					end else
					begin
						{stillbirth}
						pregnancy := AbortionOrStillBorn (kStillBirth_durationPregnancyInMonths);
					end;
				end else
				begin
					{Live birth}
					pregnancy := LivingBirth (pDemReg) +
								waiting_time_contraception (
											pDemReg, 
											pDemReg^.AccDurationWaitingTime [min(nbChildren, kMaxIndBirthIntervals)],
											effectivenessContraceptionSpacing(pDemReg, nbChildren),
											monthEnd, wt_currMonth);
				end;
				
				if g_GENPARAM.fixedParameters [reshuffledFecundability].state.value then begin
				// Relative level of fecundability changes for each interval
					fecundLife.relativeFecundabilityLevel := fecundabilityLevel (randomGenerator);
					for currAge := kMinAgeFert to kMaxAgeFert do
					begin
						fecundLife.levelFecundabilityAge[currAge] :=  fecundLife.relativeFecundabilityLevel * gFecundability[currAge];
					end;
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

if (monthOfEndOfFecundLife < monthEnd) then begin
	if gRunFromIDE then
{$IFNDEF ARM}
		asm int 3 end;
{$ELSE}
		assert(true);
{$ENDIF}
	writeAndWaitConst(['===> ERROR: monthOfEndOfFecundLife < monthEnd']);
end;
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
				monthWaitingTime := waiting_time_contraception (pDemReg, pDemReg^.AccDurationContrAfterUnion, pDemReg^.propContraceptionAfterUnion_var, monthEnd, currMonth);
				waiting_time_firstUnion := (monthWaitingTime > 0);
			end;
			
			{Birth control any union, before first birth (only if the previous waiting time is zero)}
			if not waiting_time_firstUnion and (nbChildren = 0) then begin
				monthWaitingTime := waiting_time_contraception (pDemReg, pDemReg^.AccDurationWaitingTime [0], effectivenessContraceptionSpacing(pDemReg, 0), monthEnd, currMonth);
			end;
except // 1
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
if gRunFromIDE then
{$IFNDEF ARM}
	asm int 3 end;
{$ELSE}
	assert(true,E.Message)
{$ENDIF}
		end;
	end;
end;
try // 2
			{Effective value of start of fertile life without contraception use}
			ageDurationEvents.monthStart := currMonth;
			while (currMonth <= monthEnd) and (not endUnion) do
			begin
{$IFDEF DEBUG}
if (lunarMonthsToAge (currMonth) < kMinAgeFert) or (lunarMonthsToAge (currMonth) > kMaxAgeFert) then
	writeAndWait ('===> ERROR: currMonth bad value in calcNbChildren');
{$ENDIF}
				currAge := trunc ( lunarMonthsToAge (currMonth) );
				aleaFecundability := randomGenerator.alea0 ();
try // 2-1
				if fecundLife.levelFecundabilityAge [currAge] >= aleaFecundability then
				{we have a fecundation!}
				begin
					if (not fecundLife.stopping) and testStopping then
					begin
						fecundLife.stopping := (pDemReg^.curr_contracepStopping [nbChildren] < randomGenerator.alea0);
						testStopping := false;
						if (fecundLife.stopping) then begin
							ageDurationEvents.monthStop := min (currMonth, ageDurationEvents.monthStop);
							ageDurationEvents.monthStopIsStopping := true;
						end;
					end;

					if not fecundLife.stopping then
					begin
						monthIncrement := pregnancy ( pDemReg, pCurrChild, monthEnd, currMonth );
					end else
					begin
						{stopping contraception effectiveness}						
						if effectivenessContraceptionStopping(pDemReg, nbChildren) < randomGenerator.alea0 then
						begin
							monthIncrement := pregnancy ( pDemReg, pCurrChild, monthEnd, currMonth );
						end;
					end; {if contracepArret[nbChildren] >= randomGenerator.alea0 then}
				end else
				begin
					{we go to the next month}
					monthIncrement := 1;
				end; {fecundLife.levelFecundabilityAge [currAge] >= aleaFecundability then}
except // 2-1
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(true,E.Message)
{$ENDIF}
		end;
	end;
end;
try // 2-2

				if ( monthIncrement > 1 ) then begin
					{There is a pregnancy}
					with pCurrChild^ do begin
						monthFecundation := currMonth;
						
						if (monthEndPregnancy > monthFecundation + 11) then begin
if gRunFromIDE then
{$IFNDEF ARM}
	asm int 3 end;
{$ELSE}
	assert(true);
{$ENDIF}
							writeAndWaitConst (['===> ERROR: monthEndPregnancy > monthFecundation + 11']);
						end;
						ageMotherAtFecundation := lunarMonthsToAge (currMonth);
						monthNewOvulation := currMonth + monthIncrement;
					end;
				end;

				{There is a problem with current civil status: it cannot change during pregnancy}
				{or the amenorrhoea period. This means that the birth will be registered with civil status}
				{of the woman at the time of conception}

				{separation after fecundation}
				month := 0;
				while (month < monthIncrement) and (currMonth <= monthEnd) do
				begin
					Inc ( month );
					if pDemReg^.separationInfo.separationPossible and
						endBySeparation (randomGenerator, monthStart, currMonth, nbPregnanciesInCurrentUnion, pCurrChild, pDemReg^.separationInfo, pDemReg^.dp, unionStates)
						then
					begin
						paramSeparation;
						ageDurationEvents.monthStop := min (currMonth, ageDurationEvents.monthStop);
						ageDurationEvents.monthStopIsStopping := false;
						month := monthIncrement;
					end else
						Inc ( currMonth );
				end;
except // 2-2
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(true,E.Message)
{$ENDIF}
		end;
	end;
end;

			end; {while (currMonth <= monthEnd) and (not endUnion)}
except // 2
	on E: Exception do begin
		if not isThreaded then begin
			writeAndWaitConst(['===> ERROR: ', E.Message]);
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(true,E.Message)
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true,E.Message)
{$ENDIF}
	end;
end;
try // 4
			{for debugging purposes only. We should never have (monthStop = kMaxAgeLifeInMonths) and (currMonth < monthEnd)}
			if (ageDurationEvents.monthStop = kMaxAgeLifeInMonths) and (currMonth < monthEnd ) then begin
				ageDurationEvents.monthStop := currMonth - 1;
				writeAndWait ('===> ERROR: ageDurationEvents.monthStop bad in calcNbChildren');
			end;
except // 4
	on E: Exception do begin
		writeAndWaitConst(['===> ERROR: ', E.Message]);
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true,E.Message)
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true,E.Message)
{$ENDIF}
	end;
end;
try // 6
				while (currMonth < monthEnd) and (not endUnion) do
				begin
				if pDemReg^.separationInfo.separationPossible and
					endBySeparation (randomGenerator, monthStart, currMonth, nbPregnanciesInCurrentUnion,
							pCurrChild, pDemReg^.separationInfo, pDemReg^.dp, unionStates) then
					begin
						paramSeparation;
						ageDurationEvents.monthStop := min (currMonth, ageDurationEvents.monthStop);
						ageDurationEvents.monthStopIsStopping := false;
					end else
						Inc ( currMonth );
				end;
except // 6
	on E: Exception do begin
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true,E.Message)
{$ENDIF}
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
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(true,E.Message)
{$ENDIF}
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

		if gRunFromIDE then begin
			// check ages
			for indUnion := mem_param_currentUnionNumber to unionStates.nbUnions do begin
				if (unionStates.Unions [indUnion-1].ages[le_union, man] >
					unionStates.Unions [indUnion-1].ages[le_endUnion, man]) and
					(unionStates.Unions [indUnion-1].ages[le_endUnion, man] <> kNotDefined) then
					writeAndWaitConst(['===> ERROR: Bad man: age union superior to age end']);
				if (unionStates.Unions [indUnion-1].ages[le_union, woman] >
					unionStates.Unions [indUnion-1].ages[le_endUnion, woman]) and
					(unionStates.Unions [indUnion-1].ages[le_endUnion, woman] <> kNotDefined) then
					writeAndWaitConst(['===> ERROR: Bad woman: age union superior to age end']);
				if param_deathWoman then begin
					if unionStates.Unions [indUnion-1].ages[le_union, woman] >
						unionStates.Unions [indUnion-1].ages[le_death, woman] then
						writeAndWaitConst(['===> ERROR: Bad woman: age union superior to age death']);
					if unionStates.Unions [indUnion-1].ages[le_endUnion, woman] >
						unionStates.Unions [indUnion-1].ages[le_death, woman] then
						writeAndWaitConst(['===> ERROR: Bad woman: age end union superior to age death']);
				end;
				if param_deathMan then begin
					if unionStates.Unions [indUnion-1].ages[le_union, man] >
						unionStates.Unions [indUnion-1].ages[le_death, man] then
						writeAndWaitConst(['===> ERROR: Bad man: age union superior to age death']);
					if unionStates.Unions [indUnion-1].ages[le_endUnion, man] >
						unionStates.Unions [indUnion-1].ages[le_death, man] then
						writeAndWaitConst(['===> ERROR: Bad man: age end union superior to age death']);
				end;
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
			if unionStates_copy.nbChildren <> ( nChildrenAlive ) then
				writeAndWait ('===> ERROR: nbChildren snafus, woman: ' + IntToStr (idWoman));
				
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
			if (duration < 0) then begin
				if (duration < -2) then
				   writeAndWait ('===> ERROR: duration bad in incrementIntervConc');
				duration := 0; {debug}
			end;
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
			if (duration > ageEndUnion - ageUnion + 1) then
				writeAndWait('===> ERROR: birth more than one year after the end of current union');
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
{$IFDEF DEBUG}
f: TFileType;
{$ENDIF}
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
					if (nbChildren <> numChildrenInUnion (pChildrenList, 0)) then
					begin
						{debug}
						writeAndWait ('===> ERROR: nbChildren not equal to numChildrenInUnion (pChildrenList)');
						nbChildren := nbChildren;
					end;
			
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
		numFem := pDemReg^.lp[nWomenPar].value - pData^.WomenPop[10, any];
		for ageWomen := kMinAgeFert to kMaxAgeFert do begin
			pData^.WomenPop [ageWomen, neverInUnion] := pData^.WomenPop [ageWomen, neverInUnion] + numFem;
			pData^.WomenPop [ageWomen, any] := pData^.WomenPop [ageWomen, any] + numFem;
		end;

{$IFDEF DEBUG}
if g_GENPARAM.DEBUG.value and not g_GENPARAM.MULTITHREADING.value then begin
	if ( openFileOut(g_FileName.value + '_statusTable.txt', 'STATUSTABLE', f, kAsyncFalse) ) then begin
		writePartnershipStatusTable (f, pData^.WomenPop, true);
		f.Destroy;
	end;
end;
{$ENDIF}
		
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
{$IFDEF DEBUG}
temp : double;
{$ENDIF}
		
	a, b, c: double;
	CTFR_result: double;
	useOdds: boolean = false;
	idWomanTemp: longint = 1;
	factHighOrder: double;
	iterFec: longint;

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
			
			for iterFec := 1 to 4 do begin
				if g_GENPARAM.TALKATIVE.value then
					memoWriteLn (['Iteration CTFR: ', iterFec, ', cohort: ', pDemReg^.yearOfBirth.value]);
				for ind := 0 to kMaxNbChildrenCalc do begin
					c := pDemReg^.aPrioriPPR.value[ind];
					a := pDemReg^.aPrioriPPR_adjusted.value[ind];
					// This are the values computed in a previous step
					// First parityProgressionRatio value is for transition to union, so we add 1 to index
					b := pDemReg^.parityProgressionRatio[ind+1, everInUnion];
					
					if (b = 0) then b := 0.00001;
					ind1 := ind + 1;
					if g_GENPARAM.TALKATIVE.value then
						memoWriteLn (['p', ind, '->', ind1, ' Tgt: ', c, ' adj: ', a, ' res: ', b]);
				
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
				// last value for the factHighOrder term is extended to higher parities
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
				pDemReg^.adjustedValues := true;

 			end; {for iterFec}
 
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
				tnr := tnr + Total_NetFertility * 0.488;
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
