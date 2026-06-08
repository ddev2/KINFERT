	procedure initMotherhood;
	var
		cohort, age, indMother, indBride, indCohort: longint;
		pDemReg: pStructDemographicRegimeSettings;
		cohortArrayOfWomen: array of TWomenMemoryManager;
		womanObj: TWomanMemoryBlock;
		cohortThreadData: ThreadCohortData;
		threadNumber: longint;
		cohortWomenThreads: array of TCohortWomenSet;
		nActiveThreads: longint;
		indChild: longint;
		tStart: TDateTime;  // Begin and end of measurement

        realMultiThreading: boolean = false;
		numberWomen, totalWomenBridesCreated: longint;
		r: double;
        dummy: longint = 0;
{$IFDEF DEBUG}
ind, res: longint;
f: TFileType; // used in the main thread
{$ENDIF}
	
	begin
		tStart:= Now();  // Get date+time

{$IFDEF DEBUG}
	if g_GENPARAM.CHECK_DATASTRUCT.value then begin
	if checkDirResult () then begin
		f := TFileType.Create (gPathToResult + 'ProblemBrides.txt', res, 'PROBLEMBRIDES');
		if res = 0 then
			cWriteLn (f, 'Bad brides! (no problem if this is the only line)');
		f.Destroy;
		f := TFileType.Create (gPathToResult + 'ProblemChildren.txt', res, 'PROBLEMCHILDREN');
		if res = 0 then
			cWriteLn (f, 'Bad chidren! (no problem if this is the only line)');
		f.Destroy;
	end;
end;
{$ENDIF}
		if gBACKFOR_mode then begin
			memoWriteLn (['Le Bras'' BACKFOR mode']);
		end;
		if gBACKFOR_mode_pure then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			memoWriteLn (['Le Bras'' pure BACKFOR mode']);
		end;
		if gCAMSIM_1987 then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			memoWriteLn (['CAMSIM 1987 mode']);
		end;
		if gCAMSIM_1993 then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			memoWriteLn (['CAMSIM 1993 mode']);
		end;

		if StablePopulation() then begin
			gFirstCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
			gLastCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_lastCohort].value;
			numberWomen := g_GENPARAM.RUNTIME[cmd_numberWomen].value;
			if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
				// For stable populations, we simulate only one birth cohort, and the rest will use the same mothers and brides datasets
				// this explains why we use only 'gFirstCohortAncestorsChildren'
				// 'gFirstCohortBrides' is the year of birth of the oldest cohort of potential brides (women who may be brides of the youngest
				// grooms, and who are older, up to 'kMaxDiffAgeUnion_men_olderWomen', constant that fixes the highest difference of age at union_men_women
				// between a man and an older woman)
				// Example: if gFirstCohortAncestorsChildren=2000 and kMaxDiffAgeUnion_men_olderWomen=20 ==> gFirstCohortBrides=1980
				// which corresponds to brides who form unions with grooms 20 years younger
				gFirstCohortBrides := gFirstCohortAncestorsChildren - kMaxDiffAgeUnion_men_olderWomen;
				// 'gLastCohortBrides' is the year of birth of the youngest cohort of potential brides (women who may be brides of the oldest
				// grooms, and who are younger, aged less than 'kMaxDiffAgeUnion_women_olderMen' years)
				gLastCohortBrides := gFirstCohortAncestorsChildren + kMaxDiffAgeUnion_women_olderMen;
				// 'gFirstCohortGrooms' and 'gLastCohortGrooms' are the birth cohort range of grooms of the preceding women / brides
				// Observe that we keep track of age at union of grooms in that range only for computing a cross-tables of age at union
				// as in the simulation we will only form unions between men born in year 'gFirstCohortAncestorsChildren'
				// and brides that form a union with these grooms
				// 'gFirstCohortGrooms' is the year of birth of older grooms who form a union with the youngest women of the older birth cohort
				gFirstCohortGrooms := gFirstCohortBrides - kMaxDiffAgeUnion_women_olderMen;
				// 'gLastCohortGrooms' corresponds to the grooms who are younger than the oldest brides of the last birth cohort
				gLastCohortGrooms := gLastCohortBrides + kMaxDiffAgeUnion_men_olderWomen;
				gFirstCohortWomen := gFirstCohortAncestorsChildren - kMaxAgeFert;
				gLastCohortWomen := gFirstCohortAncestorsChildren - kMinAgeFert;
			end else begin
				gFirstCohortBrides := gFirstCohortAncestorsChildren - kMaxAgeUnion_women;
				gLastCohortBrides := gLastCohortAncestorsChildren - kMinAgeUnion_women;
				gFirstCohortGrooms := gFirstCohortAncestorsChildren - kMaxAgeUnion_men;
				gLastCohortGrooms := gLastCohortAncestorsChildren - kMinAgeUnion_men;
				gFirstCohortWomen := gFirstCohortBrides;
				gLastCohortWomen := gLastCohortBrides;
			end;
						
			pDemReg := getCohort_p (gFirstCohortAncestorsChildren);
			r := pDemReg^.r;
			
			if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			end else begin
				// hack. We should find a better solution
				if (r < -0.02) then begin
					r := -0.02;
					memoWriteLn (['===> WARNING: initMotherhood: stable population growth rate too low, limited to -0.02']);
				end;
				if (r > 0.02) then begin
					r := 0.02;
					memoWriteLn (['===> WARNING: initMotherhood: stable population growth rate too high, limited to 0.02']);
				end;
			end;
			
			if g_GENPARAM.DEBUG.value and not g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			// use non stable population values to check range
				gFirstCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_firstCohort].value - 2 * kMaxAgeFert;
				gLastCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_lastCohort].value;
				gFirstCohortBrides := gFirstCohortAncestorsChildren;
				gLastCohortBrides := gLastCohortAncestorsChildren + kMaxAgeUnion_women;
				gFirstCohortGrooms := gFirstCohortAncestorsChildren;
				gLastCohortGrooms := gLastCohortAncestorsChildren + kMaxAgeUnion_men; // bug corrected
				gFirstCohortWomen := gFirstCohortBrides;
				gLastCohortWomen := gLastCohortBrides;
			end;
		end else begin
			gFirstCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_firstCohort].value - 2 * kMaxAgeFert;
			gLastCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_lastCohort].value;
			
			gFirstCohortBrides := gFirstCohortAncestorsChildren;
			gLastCohortBrides := gLastCohortAncestorsChildren + kMaxAgeUnion_women;
			gFirstCohortGrooms := gFirstCohortAncestorsChildren;
			if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
				gLastCohortGrooms := gLastCohortAncestorsChildren + kMaxAgeUnion_men;
			end else begin
				// probable bug there, caught in the new version of the algorithm
				gLastCohortGrooms := gLastCohortAncestorsChildren + kMinAgeUnion_men;
			end;
			gFirstCohortWomen := gFirstCohortBrides;
			gLastCohortWomen := gLastCohortBrides;
		end;
		// obsolete
		gFirstYearUnions := gFirstCohortBrides + kMinAgeUnion_women;
		gLastYearUnions := gLastCohortBrides + kMaxAgeUnion_women;

		SetLength (g_RangeBirthsNb, gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren + 1);
		SetLength (g_RangeBirthsInfo, gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren + 1, kSetLengthBirths);
		if gCAMSIM_1993 then begin
			for indChild := 0 to kMaxNbChildrenCalc do begin
				SetLength (CAMSIM_RangeBirthsNb [indChild], gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren + 1);
				SetLength (CAMSIM_RangeBirthsInfo [indChild], gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren + 1, kSetLengthBirths);
			end;
		end;
		
		gThisIsNotAnArrayOfBrides := true;
		gBig_ArrayWomen_NEW := TWomenMemoryManager.Create();
		SetLength (g_WomenPopNumbers, gLastCohortWomen - gFirstCohortWomen + 1);
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation() then begin
				gThisIsNotAnArrayOfBrides := false;
				gBig_ArrayBrides_NEW := TWomenMemoryManager.Create();
				SetLength (g_BridesPopNumbers, gLastCohortBrides - gFirstCohortBrides + 1);
			end;
		end;

		//SetLength (RangeWomenInfo, gLastCohortWomen - gFirstCohortWomen + 1);
		SetLength (g_RangeBridesNb, gLastCohortBrides - gFirstCohortBrides + 1, kMaxAgeUnion_women - kMinAgeUnion_women + 1);
		SetLength (g_RangeBridesInfo, gLastCohortBrides - gFirstCohortBrides + 1, kMaxAgeUnion_women - kMinAgeUnion_women + 1, kSetLengthBrides);
		SetLength (g_RangeGroomsNb, gLastCohortGrooms - gFirstCohortGrooms + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1);
		SetLength (g_RangeGroomsNotFound, gLastCohortGrooms - gFirstCohortGrooms + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1);
		SetLength (g_RangeGroomsInfo, gLastCohortGrooms - gFirstCohortGrooms + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1, kSetLengthGrooms);
		SetLength (g_RangeYearUnionsNb, gLastYearUnions - gFirstYearUnions + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1);
		SetLength (g_RangeYearUnionsNotFound, gLastYearUnions - gFirstYearUnions + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1);
		SetLength (g_RangeYearUnionsInfo, gLastYearUnions - gFirstYearUnions + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1, kSetLengthUnions);
		
		if gBACKFOR_mode then begin
			SetLength (RangeBirthsBACKFORNb,
				gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren + 1,
				kMaxAgeFert - kMinAgeFert + 1);
			SetLength (RangeBirthsBACKFORInfo, gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren + 1,
				kMaxAgeFert - kMinAgeFert + 1,
				kSetLengthBirths);
		end;

		memoWriteLn(['============  Init cohort of women possible mothers and / or brides ========']);
		FlushIO ();
		totalWomenBridesCreated := 0;
		threadNumber := 0;
		for cohort := gFirstCohortWomen to gLastCohortWomen do begin
			pDemReg := getCohort_p (cohort);
			indCohort := cohort - gFirstCohortWomen;
			// should be a number equivalent to births
			if StablePopulation() then begin
			// exponential growth of births, with the rate of the associated stable population
			// this is why we limit the value of r: if too high or too low, we reach very high values
				g_WomenPopNumbers[indCohort] := trunc ( numberWomen * exp ( -r * ( gLastCohortWomen - cohort )) );
			end else begin
			// number of births read in the cohort file
				g_WomenPopNumbers[indCohort] := pDemReg^.lp[nWomenPar].value;
			end;
			//SetLength (RangeWomenInfo[indCohort], g_WomenPopNumbers[indCohort]);

			cohortThreadData.pDemReg := pDemReg;
			cohortThreadData.nWomen := g_WomenPopNumbers[indCohort];
			cohortThreadData.cohort := cohort;
			cohortThreadData.womenType := 'women';

			threadNumber := 0;
			cohortThreadData.womenCollection := gBig_ArrayWomen_NEW;
		
			CreateWomenSetForCohort(@cohortThreadData, threadNumber, totalWomenBridesCreated);
		end; {cohort}

		if (totalWomenBridesCreated <> gBig_ArrayWomen_NEW.numWomen()) then
			totalWomenBridesCreated := gBig_ArrayWomen_NEW.numWomen();

		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation() then begin
				threadNumber := 0;
				for cohort := gFirstCohortBrides to gLastCohortBrides do begin
					pDemReg := getCohort_p (cohort);
					indCohort := cohort - gFirstCohortBrides;
					// should be a number equivalent to births
					// exponential growth of births, with the rate of the associated stable population
					// this is why we limit the value of r: if too high or too low, we reach very high values
					g_BridesPopNumbers[indCohort] := trunc ( numberWomen * exp ( -r * ( gLastCohortBrides - cohort )) );

					cohortThreadData.pDemReg := pDemReg;
					cohortThreadData.nWomen := g_BridesPopNumbers[indCohort];
					cohortThreadData.cohort := cohort;
					cohortThreadData.womenType := 'brides';

					threadNumber := 0;
					cohortThreadData.womenCollection := gBig_ArrayBrides_NEW;
		
					CreateWomenSetForCohort(@cohortThreadData, threadNumber, totalWomenBridesCreated);
				end; {cohort}
		
				if (totalWomenBridesCreated <> ( gBig_ArrayWomen_NEW.numWomen() + gBig_ArrayBrides_NEW.numWomen() )) then
					totalWomenBridesCreated := gBig_ArrayWomen_NEW.numWomen() + gBig_ArrayBrides_NEW.numWomen(); // problem
			end; {StablePopulation}
		end;
		
		if StablePopulation() then begin
			if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
				for indMother := 0 to gBig_ArrayWomen_NEW.numWomen - 1 do begin
					// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
					// AFTER THE BIG ARRAY HAVE BEEN CREATED
					addChildrenInfo (indMother);
					if gBACKFOR_mode then
						addChildrenBACKFORInfo (indMother);
				end;
				for indBride := 0 to gBig_ArrayBrides_NEW.numWomen - 1 do begin
					// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
					// AFTER THE BIG ARRAY HAVE BEEN CREATED
					addBridesInfo (indBride, gThisIsNotAnArrayOfBrides);
					addGroomsInfo (indBride, gThisIsNotAnArrayOfBrides);
					addUnionsInfo (indBride, gThisIsNotAnArrayOfBrides);
				end;
			end else begin
				for indMother := 0 to gBig_ArrayWomen_NEW.numWomen - 1 do begin
					// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
					// AFTER THE BIG ARRAY HAVE BEEN CREATED
					addBridesInfo (indMother);
					addGroomsInfo (indMother);
					addChildrenInfo (indMother);
					if gBACKFOR_mode then
						addChildrenBACKFORInfo (indMother);
					addUnionsInfo (indMother);
				end;
			end;
		end else begin
			for indMother := 0 to gBig_ArrayWomen_NEW.numWomen - 1 do begin
				// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
				// AFTER THE BIG ARRAY HAVE BEEN CREATED
				addBridesInfo (indMother);
				addGroomsInfo (indMother);
				addChildrenInfo (indMother);
				if gBACKFOR_mode then
					addChildrenBACKFORInfo (indMother);
				addUnionsInfo (indMother);
			end;
		end;

		SetLength (gMen_Women, gLastCohortGrooms - gFirstCohortGrooms + 1, kMaxAgeUnion_men - kMinAgeUnion_men + 1, kMaxAgeUnion_women - kMinAgeUnion_women + 1);
		SetLength (gStateChildren, (gLastCohortAncestorsChildren + kStateRangeLengthLimit) - (gFirstCohortAncestorsChildren - kStateRangeLengthLimit) + 1);
		SetLength (gStateMothers, (gLastCohortWomen + kStateRangeLengthLimit) - (gFirstCohortWomen - kStateRangeLengthLimit) + 1);
		SetLength (gStateBrides, (gLastCohortBrides + kStateRangeLengthLimit) - (gFirstCohortBrides - kStateRangeLengthLimit) + 1);
		SetLength (gStateGrooms, (gLastCohortGrooms + kStateRangeLengthLimit) - (gFirstCohortGrooms - kStateRangeLengthLimit) + 1);
		SetLength (gStateYearUnions, (gLastYearUnions + kStateRangeLengthLimit) - (gFirstYearUnions - kStateRangeLengthLimit) + 1);

		LookMemory;

{$IFDEF DEBUG}
for age := kMinAgeFert to kMaxAgeFert do begin
	gAgeChildbearing [age] := 0;
	gAgeChildbearingBACKFOR [age] := 0;
	gAgeChildbearingBACKFOR_post [age] := 0;
end;
for cohort := gFirstCohortAncestorsChildren to gLastCohortAncestorsChildren do begin
	indCohort := cohort-gFirstCohortAncestorsChildren;
	if g_RangeBirthsNb[indCohort] > 0 then
		for indChild := 0 to g_RangeBirthsNb[indCohort] - 1 do begin
			Inc (gAgeChildbearing [ trunc (
				getAgeChildbearing (getWomanFromBigArray (g_RangeBirthsInfo[indCohort, indChild]).pChildrenList,
				cohort)
				)]);
		end;
end;
{$ENDIF}

//if g_GENPARAM.CHECK_DATASTRUCT.value then begin
//writeInfoWomen;
//writeInfoBrides;
//writeInfoGrooms(g_RangeGroomsNb);
//writeInfoBridesYear(g_RangeYearUnionsNb);
//checkBrides ('End initMotherhood', gThisIsNotAnArrayOfBrides);
//checkChildren ('End initMotherhood');
//end;

		stopTime (tStart, '===== initMotherhood lasted: ');

	end; {initMotherhood}

	procedure disposeMotherhood;
	var
		ind: longint;
	begin
		if ( (gBACKFOR_mode_pure or gCAMSIM_1993) and (gBACKFOR_women > 0) ) then begin
			fileScreenWriteLn (gOutFileKin, ['BACKFOR Women: ', gBACKFOR_women, ', mean number of tries: ', gBACKFOR_nTries / gBACKFOR_women]);
		end;
		
		{$IFDEF DEBUG}
		if g_GENPARAM.CHECK_DATASTRUCT.value then begin
			writeAgeChildbearingStates;
			writeInfoBridesYear(g_RangeYearUnionsNotFound, 'NotFound_');
			writeInfoGrooms(g_RangeGroomsNotFound, 'NotFound_');
			writeStates;
			writeInfoMenWomen;
			checkBrides ('disposeMotherhood', gThisIsNotAnArrayOfBrides);
			checkChildren ('disposeMotherhood');
		end;
		{$ENDIF}
		SetLength (g_RangeBirthsNb, 0);
		SetLength (g_RangeBirthsInfo, 0);
		for ind := 0 to kMaxNbChildrenCalc do begin
			SetLength (CAMSIM_RangeBirthsNb [ind], 0);
			SetLength (CAMSIM_RangeBirthsInfo [ind], 0);
		end;
		SetLength (RangeBirthsBACKFORNb, 0);
		SetLength (RangeBirthsBACKFORInfo, 0);
		SetLength (g_WomenPopNumbers, 0);
		//SetLength (RangeWomenInfo, 0);
		SetLength (g_RangeBridesNb, 0);
		SetLength (g_RangeBridesInfo, 0);
		SetLength (g_RangeYearUnionsNb, 0);
		SetLength (g_RangeYearUnionsNotFound, 0);
		SetLength (g_RangeYearUnionsInfo, 0);
		SetLength (g_RangeGroomsNb, 0);
		SetLength (g_RangeGroomsNotFound, 0);
		SetLength (g_RangeGroomsInfo, 0);
		gBig_ArrayWomen_NEW.Destroy;
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then
			if StablePopulation() then
				gBig_ArrayBrides_NEW.Destroy;

	end;
