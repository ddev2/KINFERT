{$I Defines.pas}
unit SpecialRuns;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}

	Declarations, DemographicRegime, FertilityRuntime, Fertility, Nuptiality, Inheritance, Kinship,
	Utilities, RandomNumbers, Init, StringOfLib, SysUtils{$IFDEF VerboseProfiler}, Profiler{$ENDIF};

	function run_all(	randomGenerator: TRandomNumberGenerator;
						currCohort: longint;
						bootstrap_ind: longint;
					    loopPhase: loopTypes = k_onlyOne): boolean;

	implementation

	procedure FERTILITY_loops (randomGenerator: TRandomNumberGenerator;
      							pDemReg: pStructDemographicRegimeSettings;
								var idWoman: longint);
	var
		pDemReg_mem: pStructDemographicRegimeSettings;
		freqFin_Cel: double; {final celibacy frequency}
		freqDiv: double;
		indAgeUnion, indCelibacy, indStdCel, indFertControl, indFertSeparation, indFertContrUseAfterUnion, indFertAmeno: longint;
		mean, std, stdv: double; {Union model}
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// std_initial keeps the standard deviation of the age at union as it stood before
// the loops. pCurrUnionInfo is not copied by DemographicRegimeSettings_copyState,
// so unlike the dp[] parameters it cannot be recovered from pDemReg_mem.
		std_initial: double;
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
		meanTimeContr: double;
		ind, idWomanTemp: longint;
		arrayChildren: arrayOfInfoChild;
		objOutputFert: TOutputFertility;
		objUnionTable: TUnionTable;
		varyingUnionOrFertility: boolean = FALSE;

	begin
		CreateArrayChildren (arrayChildren{%H-});

		objOutputFert := TOutputFertility.Create();
		objOutputFert.init();
		objUnionTable := TUnionTable.Create();
		objUnionTable.init();

		// if values in pDemReg change in the following loops,
		// we use pDemReg_mem to restore the original values
		pDemReg_mem := DemographicRegimeSettings_create();
		DemographicRegimeSettings_copyState (pDemReg, pDemReg_mem);
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// Every stepped value below must be computed from the parameters as they stood
// before the loops, that is from pDemReg_mem, never from pDemReg. The innermost
// block writes the stepped values into pDemReg^.dp[], so a base read from pDemReg
// on the next pass returned the previous step's value instead of the original one.
// For the two multiplicative steps (separation, contraception after union) step 1
// writes base * 0 = 0, so every later step read 0 and the sweep collapsed.
		std_initial := pDemReg^.pCurrUnionInfo^.unionParam [woman, stdUnion];
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
		
		checkStepsAndStablePopulation;  // Steps only make sense when we are in a stable population
										// (when we have only one demographic regime)		
		{============== LOOPS ============}
		for indAgeUnion := 1 to g_GENPARAM.RUNTIME[nStepsUnion_mean].value do
		begin
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The base of the sweep must come from the untouched copy.
// was:
//			mean := (pDemReg^.dp[meanAgeUnionWomenLow].value);
			mean := (pDemReg_mem^.dp[meanAgeUnionWomenLow].value);
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// dp[stdnupt] is overwritten in the innermost block and initOne then recomputes
// unionParam[woman, stdUnion] from it, so this read drifted with the previous step.
// was:
//			std := pDemReg^.pCurrUnionInfo^.unionParam [woman, stdUnion];
			std := std_initial;
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
			if g_GENPARAM.RUNTIME[nStepsUnion_mean].value > 1 then
			begin
				varyingUnionOrFertility := TRUE;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The base of the sweep must come from the untouched copy (continued below).
// was:
//				mean := (pDemReg^.dp[meanAgeUnionWomenLow].value) +
				mean := (pDemReg_mem^.dp[meanAgeUnionWomenLow].value) +
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// RP.indAgeUnion is assigned nine lines below, so it still held the previous step.
// was:
//					( RP.indAgeUnion - 1) * (pDemReg^.dp[meanAgeUnionWomenHigh].value-pDemReg^.dp[meanAgeUnionWomenLow].value) /
//					( g_GENPARAM.RUNTIME[nStepsUnion_mean].value - 1 );
					( indAgeUnion - 1) * (pDemReg_mem^.dp[meanAgeUnionWomenHigh].value-pDemReg_mem^.dp[meanAgeUnionWomenLow].value) /
					( g_GENPARAM.RUNTIME[nStepsUnion_mean].value - 1 );
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------

				if g_GENPARAM.fixedParameters [stdUnionDanielOrCampbellWood].state.value then
					std := std_Logistic_Dani_2004 (mean, 6.708204)
				else
					std := std_Campbell_Wood_1988 (mean);
			end;
			
			RP.indAgeUnion := indAgeUnion;
			RP.valAgeUnion := mean;

			for indCelibacy := 1 to g_GENPARAM.RUNTIME[nStepsUnion_prop].value do
			begin

// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The base of the sweep must come from the untouched copy.
// was:
//				freqFin_Cel := pDemReg^.dp[propFinalCelibacyLow].value;
				freqFin_Cel := pDemReg_mem^.dp[propFinalCelibacyLow].value;
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
				if g_GENPARAM.RUNTIME[nStepsUnion_prop].value > 1 then
				begin
					varyingUnionOrFertility := TRUE;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// RP.indCelibacy is assigned three lines below, so it still held the previous step.
// was:
//					freqFin_Cel := pDemReg^.dp[propFinalCelibacyHigh].value - (pDemReg^.dp[propFinalCelibacyHigh].value - pDemReg^.dp[propFinalCelibacyLow].value) * (RP.indCelibacy - 1) / (g_GENPARAM.RUNTIME[nStepsUnion_prop].value - 1);
					freqFin_Cel := pDemReg_mem^.dp[propFinalCelibacyHigh].value - (pDemReg_mem^.dp[propFinalCelibacyHigh].value - pDemReg_mem^.dp[propFinalCelibacyLow].value) * (indCelibacy - 1) / (g_GENPARAM.RUNTIME[nStepsUnion_prop].value - 1);
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
				end;

				RP.indCelibacy := indCelibacy;
				RP.valCelibacy := freqFin_Cel;
				
				for indStdCel := 1 to g_GENPARAM.RUNTIME[nStepsUnion_Dev].value do
				begin
						
					stdv := std;
					if g_GENPARAM.RUNTIME[nStepsUnion_Dev].value > 1 then begin
						varyingUnionOrFertility := TRUE;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// RP.indStdCel is assigned three lines below, so it still held the previous step.
// was:
//						stdv := std * (0.5 + (RP.indStdCel - 1) / (g_GENPARAM.RUNTIME[nStepsUnion_Dev].value - 1))
//					end;
						stdv := std * (0.5 + (indStdCel - 1) / (g_GENPARAM.RUNTIME[nStepsUnion_Dev].value - 1))
					end;
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
		
					RP.indStdCel := indStdCel;
					RP.valStdCel := stdv;

					for indFertControl := 1 to g_GENPARAM.RUNTIME[nStepsContrFert].value do
					begin
					
						{CONTRACEPTION IS ADJUSTED BY procedure adjustContraception, using values of step (RP.indFertControl)
						and of numStep (g_GENPARAM.RUNTIME[nStepsContrFert].value), changing value of PPRs}
						RP.indFertControl := indFertControl;
						RP.valFertControl := indFertControl * 1.0;

						if (g_GENPARAM.RUNTIME[nStepsContrFert].value > 1) then varyingUnionOrFertility := TRUE;
						
						for indFertSeparation := 1 to g_GENPARAM.RUNTIME[nStepsSeparation].value do
						begin
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The base of the sweep must come from the untouched copy.
// was:
//							freqDiv := pDemReg^.dp[freqSeparation].value;
							freqDiv := pDemReg_mem^.dp[freqSeparation].value;
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
							if (g_GENPARAM.RUNTIME[nStepsSeparation].value > 1) then begin
								varyingUnionOrFertility := TRUE;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// RP.indFertSeparation is assigned three lines below, and the base was read from
// pDemReg, which step 1 had already overwritten with base * 0 = 0. The separation
// sweep therefore collapsed to zero after the first step and never recovered.
// was:
//								freqDiv := pDemReg^.dp[freqSeparation].value * (RP.indFertSeparation - 1.0) /
//											(g_GENPARAM.RUNTIME[nStepsSeparation].value - 1.0);
								freqDiv := pDemReg_mem^.dp[freqSeparation].value * (indFertSeparation - 1.0) /
											(g_GENPARAM.RUNTIME[nStepsSeparation].value - 1.0);
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
							end;

							RP.indFertSeparation := indFertSeparation;
							RP.valFertSeparation := freqDiv;
							
							for indFertContrUseAfterUnion := 1 to g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value do
							begin
							
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The base of the sweep must come from the untouched copy.
// was:
//								meanTimeContr := pDemReg^.dp[meanTimeContraceptionAfterUnionHigh].value;
								meanTimeContr := pDemReg_mem^.dp[meanTimeContraceptionAfterUnionHigh].value;
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
								if ( g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value > 1 ) then
								begin
									varyingUnionOrFertility := TRUE;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// RP.indFertContrUseAfterUnion is assigned three lines below, and the base was read
// from pDemReg, which step 1 had already overwritten with base * 0 = 0. This sweep
// collapsed to zero in the same way as the separation sweep.
// was:
//									meanTimeContr := pDemReg^.dp[meanTimeContraceptionAfterUnionHigh].value *
//														(RP.indFertContrUseAfterUnion - 1.0) /
//														(g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value - 1.0);
									meanTimeContr := pDemReg_mem^.dp[meanTimeContraceptionAfterUnionHigh].value *
														(indFertContrUseAfterUnion - 1.0) /
														(g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value - 1.0);
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
								end;

								RP.indFertContrUseAfterUnion := indFertContrUseAfterUnion;
								RP.valFertContrUseAfterUnion := meanTimeContr;
									
								for indFertAmeno := 1 to g_GENPARAM.RUNTIME[nStepsAmeno].value do
								begin

									RP.indFertAmeno := indFertAmeno;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The base of the sweep must come from the untouched copy.
// was:
//									RP.valFertAmeno := pDemReg^.dp[amenorrhea_alpha].value;									
									RP.valFertAmeno := pDemReg_mem^.dp[amenorrhea_alpha].value;									
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
									if ( g_GENPARAM.RUNTIME[nStepsAmeno].value > 1 ) then
									begin
										varyingUnionOrFertility := TRUE;
// --- FIX 2026-08-26 [N1] begin ---------------------------------------------------
// The index was already assigned before this read, so only the base was wrong: it came
// from pDemReg, which the previous step had already incremented, so the amenorrhea
// sweep accumulated its increments instead of stepping from the original value.
// was:
//										RP.valFertAmeno := pDemReg^.dp[amenorrhea_alpha].value + 2.4 * (RP.indFertAmeno-1) / (g_GENPARAM.RUNTIME[nStepsAmeno].value-1);
										RP.valFertAmeno := pDemReg_mem^.dp[amenorrhea_alpha].value + 2.4 * (RP.indFertAmeno-1) / (g_GENPARAM.RUNTIME[nStepsAmeno].value-1);
// --- FIX 2026-08-26 [N1] end -----------------------------------------------------
									end;
									
									writeKeys;

									if (varyingUnionOrFertility) then begin
										DemographicRegimeSettings_copyState (pDemReg_mem, pDemReg);
										with pDemReg^ do begin
											dp[propFinalCelibacyLow].value := RP.valCelibacy;
											dp[meanAgeUnionWomenLow].value := RP.valAgeUnion;
											dp[stdnupt].value := RP.valStdCel;
											dp[freqSeparation].value := RP.valFertSeparation;
											dp[meanTimeContraceptionAfterUnionHigh].value := RP.valFertContrUseAfterUnion;
											dp[amenorrhea_alpha].value := RP.valFertAmeno;
										end;
										DemographicRegimeSettings_initOne (randomGenerator, pDemReg, 0);
//										pDemReg^.adjustedValues := false;
									end;

									gParam_descFinaleAgeUnion := RP.indFertAmeno; {We need that value in the fertility unit}

									idWomanTemp := idWoman;
									RunHeader (@RP, pDemReg);

									calcFecGenNuptMas(randomGenerator, pDemReg, objOutputFert, objUnionTable, TRUE, idWoman, arrayChildren);

									MessControlFec (pDemReg);
									memoWriteLn(['Number of women simulated in that step: ', intToStr (idWoman-idWomanTemp)]);

									if ( g_GENPARAM.SURVIVALPARENTS.value ) then begin
										survivalParents (randomGenerator, pDemReg^.yearOfBirth.value, true, true);
									end;

								end; {for indFertAmeno := 1 to g_GENPARAM.RUNTIME[nStepsAmeno] do}
							end; {for indFertContrUseAfterUnion := 1 to g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion] do}
						end; {for indFertSeparation := 1 to g_GENPARAM.RUNTIME[nStepsSeparation] do}
					end; {for indFertControl := 1 to g_GENPARAM.RUNTIME[nStepsContrFert] do}
				end; {for indStdCel := 1 to g_GENPARAM.RUNTIME[nStepsUnion_Dev] do}
			end; {for indCelibacy := 1 to g_GENPARAM.RUNTIME[nStepsUnion_prop] do}
		end; {for indAgeUnion := 1 to g_GENPARAM.RUNTIME[nStepsUnion_mean] do}

		writeGeneralTables(objOutputFert);

		if (varyingUnionOrFertility) then begin
			DemographicRegimeSettings_copyState (pDemReg_mem, pDemReg);
			DemographicRegimeSettings_initOne (randomGenerator, pDemReg, 0);
		end;

		DemographicRegimeSettings_destroy (pDemReg_mem);
		objOutputFert.Destroy();
		objUnionTable.Destroy();
		DestroyArrayChildren(arrayChildren);
	end;
	
	function run_all(	randomGenerator: TRandomNumberGenerator;
						currCohort: longint;
						bootstrap_ind: longint;
					    loopPhase: loopTypes = k_onlyOne): boolean;
	var
		ind: longint;
		idWoman: longint;
		pDemReg: pStructDemographicRegimeSettings;
		aYear: longint;
		
		label error;
	begin
		result := false;
{$IFDEF VerboseProfiler} timeProfile_start_proc('run_all'); {$ENDIF}
		pDemReg := getCohort_p (currCohort);
		gWorkingMessage := 'Working on cohort: ' + intToStr(currCohort);
		
		if (loopPhase <> k_onlyOne) then
			memoWriteLn(['Simulating cohort: ', currCohort]);
		
		if ( (loopPhase = k_onlyOne) or (loopPhase = k_first) ) then
			if not initParams(randomGenerator) then goto error;
			
		idWoman := 0;
				
		if (g_GENPARAM.RUNTIME[gBootstrap_nRuns].value > 1) then begin
			screenFileWriteLn('==============================================================');
			screenFileWriteLn('Bootstrapping: ' + IntToStr(RP.indBootstrap));
			screenFileWriteLn('==============================================================');
		end;

		if ( g_GENPARAM.KINSHIP.value ) then begin
			setKinshipToSimulate (g_GENPARAM.OUTPUT_KINTYPES.value, true);
			checkInheritanceStatus ();
		end;

		if ( g_GENPARAM.FERTILITY.value or g_GENPARAM.KINSHIP.value ) then
			if not outputFileNameHeader (bootstrap_ind, pDemReg, ((loopPhase = k_onlyOne) or (loopPhase = k_first))) then
            	goto error;

		if ( g_GENPARAM.FERTILITY.value ) then begin
			if pDemReg^.separationInfo.freqSeparation <= 0.0 then begin
				{publishResult (res_destinyUnion, false, '');}
			end else begin
				aWriteLn(gOutFileAgeMat, ['Life table separation without children:']);
				ind := 5;
				while ind <= 50 do
				begin
					aWriteLn(gOutFileAgeMat, [ind, tab, 100.0 * ( 1.0 - pDemReg^.separationInfo.cumul_separation [ind * kNbLunarMonths] )]);
					ind := ind + 5;
				end;
			end;		
			FERTILITY_loops (randomGenerator, pDemReg, idWoman);
		end;

		if ( g_GENPARAM.KINSHIP.value ) then begin
			if ((loopPhase = k_onlyOne) or (loopPhase = k_first)) then
				initMotherhood (randomGenerator);
	if gRunFromIDE then begin
		bWriteLn (gDebugFertFile, ['Births from women potential mothers of egos and other kin']);
		for aYear := 0 to 2999 do
			if gAllBirths [aYear] > 0 then
				bWriteLn (gDebugFertFile, [aYear, tab, gAllBirths [aYear]]);
		//gDebugFertFile.myFlush;
	end;
			simulateKinship (randomGenerator, currCohort, bootstrap_ind, loopPhase);
		end;
		
		if (bootstrap_ind > 1) then
			memoWriteLn(['Total number of women simulated: ', idWoman]);

		if ( g_GENPARAM.KINSHIP.value ) and ((loopPhase = k_onlyOne) or (loopPhase = k_last)) then
			disposeMotherhood;

		result := true;
		
      error:

{$IFDEF VerboseProfiler} timeProfile_end_proc('run_all'); {$ENDIF}

	end;
end.
