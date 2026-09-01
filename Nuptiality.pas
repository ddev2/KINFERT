{$I Defines.pas}
unit Nuptiality;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, Fertility, RandomNumbers, Utilities, Math, SysUtils
        {$IFDEF VerboseProfiler}, Profiler{$ENDIF};

	function newUnionInfo (pRelative: pRelativeType): pUnionInfoType;
	function getAgeUnion (pRelative: pRelativeType; indUnion: longint): double;
	function getYearUnion (pRelative: pRelativeType; indUnion: longint): double;
	function getAgeEndUnion (pRelative: pRelativeType; indUnion: longint): double;
	function getYearEndUnion (pRelative: pRelativeType; indUnion: longint): double;
	function getPartner (pRelative: pRelativeType; indUnion: longint): pRelativeType;
	function getLastPartner (pRelative: pRelativeType): pRelativeType;
	function getCauseEndUnion (pRelative: pRelativeType; indUnion: longint): CausesEndUnionType;
	function getCauseEndLastUnion (pRelative: pRelativeType): CausesEndUnionType;
	procedure setAgeUnion (pRelative: pRelativeType; indUnion: longint; age: double);
	procedure setAgeEndUnion (pRelative: pRelativeType; indUnion: longint; age: double);
	procedure setYearUnion (pRelative: pRelativeType; indUnion: longint; year: double);
	procedure setYearEndUnion (pRelative: pRelativeType; indUnion: longint; year: double);
	procedure setPartner (pRelative: pRelativeType; indUnion: longint; pPartner: pRelativeType);
	function getIndUnion (pRelative, pPartner: pRelativeType): longint;

	procedure newNuptialitySettings (var n: NuptialitySettings);
	procedure disposeNuptialitySettings (var n: NuptialitySettings);

	procedure initStandardNuptiality (p: pStructDemographicRegimeSettings; var n: NuptialitySettings);
	procedure initStandardSeparation (p: pStructDemographicRegimeSettings);
	procedure initStandardRepartnering(var pN: pNuptialitySettings);
		
	procedure calcRepartnering (freqFin_women, freqFin_men: double; var prop_repartnering: array2doubletype; var prop_not_repartnering: arrayOfDouble);
	procedure calcRepartnering_duration (freqFin_women, freqFin_men, mean_women, mean_men: double; var prop_repartnering: array2doubletype);
	procedure initRelativeRiskSeparation(var d: SeparationSettings);
	procedure calcSeparation (freqFin: double; var d: SeparationSettings);
	
	procedure calcNuptScaleFactor (minAge: longint; scaleFactor: double; var n: tabNuptVar);
	procedure calcNuptScaleFactorRT (minAge, maxAge: longint; mean: double; var n: tabNuptVar);
	procedure calcCelibacy (freqFin, scaleFactor: double; var n: NuptialitySettings);
	procedure calcCelibacy_RT_woman (const values: array of ArrayParamSinglehood_RT_type; var n: NuptialitySettings);
	procedure calcCelibacy_RT_man (const values: array of ArrayParamSinglehood_RT_type; var n: NuptialitySettings);

	procedure CoaleFirstUnion (kMinAgeUnion: longint; freqFin, scaleFactor: double; var firstUnion: tabNuptVar);
	procedure calc_firstUnion (min, max: agesUnion; firstUnion: tabNuptVar; var tabNormal, tabCumul: tabNuptVar);

	procedure writeSMAM (p: pStructDemographicRegimeSettings);

	function calc_ageUnion (randomGenerator: TRandomNumberGenerator;
                    		ageMin, ageMax: double;
                            prop_cel: tabSingleVar;
                            singlehoodPossible: boolean = true): double;

	function std_unionLinear (meanAgeUnionWomenLow, meanAgeUnionWomenHigh, stddevBasUnion, stddevHautUnion, mean: double): double;
	function std_Logistic_Dani_2004 (mean, final_level: double): double;
	function std_Campbell_Wood_1988 (mean: double): double;
	function std_Coale_Rodriguez_Trussel (mean: double): double;

	function endBySeparation (randomGenerator: TRandomNumberGenerator;
                            monthStart, currMonth, nbPregnanciesInCurrentUnion: longint;
							pCurrInfoChildren: pInfoChildType;
							d: SeparationSettings;
							dp: arrayDemReg_double;
							var unionStates: TUnionsType): boolean;

	function repartnering (randomGenerator: TRandomNumberGenerator;
                            sex_individual: Sex;
                            currUnionState: UnionAgeDurationsType;
                            var ageNextUnion: double;
                            pN: pNuptialitySettings;
                            objOutputFert: TOutputFertility): boolean;
	function repartnering_duration (randomGenerator: TRandomNumberGenerator;
                            sex_individual: Sex;
                            currUnionState: UnionAgeDurationsType;
                            var ageNextUnion: double;
                            pN: pNuptialitySettings;
                            objOutputFert: TOutputFertility): boolean;

	function causesEndUnion (union: UnionAgeDurationsType): CausesEndUnionType;
	procedure setCauseEndUnion (pRelative: pRelativeType; indUnion: longint; cause: CausesEndUnionType);
	function ageWomenEndUnion (ages: TabAgeEvents; out statutEndUnion: PartnershipStatusesType): double;

	function numChildrenInUnion (pChild: pInfoChildType; nUnion: longint): longint;
	procedure incrementTableUnions (
					unionStates: TUnionsType;
					pChild: pInfoChildType;
					objUnionTable: TUnionTable);
	procedure writeUnionTable(filename: string; objUnionTable: TUnionTable);
	function separationFinalProp(objUnionTable: TUnionTable; fname: string = ''): double;

	const
		// for calc_ageUnion
		kNoSinglehood = false;
implementation

uses Memory;

	function newUnionInfo(): pUnionInfoType;
	begin
		new (result);
		newPtr (ptr(result), 'pU');
		with result^ do begin
			ageUnion := kNotDefined;
			ageEndUnion := kNotDefined;
			yearUnion := kNotDefined;
			yearEndUnion := kNotDefined;
			partner := nil;
			endOfPartnership := no_union;
			next := nil;
		end;
	end;
	
	function newUnionInfo (pRelative: pRelativeType): pUnionInfoType;
	var
		Uinfo: pUnionInfoType = nil;
		UInfoLast: pUnionInfoType = nil;
	begin
		with pRelative^ do begin
			UInfo := UList;
			UInfoLast := UInfo;
			nUnions := 0;
			while UInfo <> nil do begin
				UInfoLast := UInfo;
				Inc (nUnions);
				UInfo := UInfo^.next;
			end;
			if (UInfolast = nil) then begin
				UList := newUnionInfo();
				result := UList;
			end
			else begin
				UInfoLast^.next := newUnionInfo();
				result := UInfoLast^.next;
			end;
			Inc (nUnions);
		end;
	end;
	
	function getAgeUnion (pRelative: pRelativeType; indUnion: longint): double;
	var
		UInfo: pUnionInfoType = nil;
{$IFDEF addOldUnionType}
		ageUnionOld: double;
{$ENDIF}
	begin
{$IFDEF addOldUnionType}
		ageUnionOld := pRelative^.ageUnion [indUnion];
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then
			result := kNotDefined
		else
			result := UInfo^.ageUnion;
{$IFDEF addOldUnionType}
		if ageUnionOld <> result then
			writeAndWait('ERROR ==> Bad getAgeUnion');
{$ENDIF}
	end;

	function getYearUnion (pRelative: pRelativeType; indUnion: longint): double;
	var
		UInfo: pUnionInfoType = nil;
	begin
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then
			result := kNotDefined
		else
			result := UInfo^.yearUnion;
	end;

	procedure setAgeUnion (pRelative: pRelativeType; indUnion: longint; age: double);
	var
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		pRelative^.ageUnion [indUnion] := age;
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			UInfo := newUnionInfo (pRelative);
		end;
		UInfo^.ageUnion := age;
{$IFDEF addOldUnionType}
		if pRelative^.ageUnion [indUnion] <> getUnionInfoByIndex (pRelative, indUnion)^.ageUnion then
			writeAndWait('ERROR ==> Bad setAgeUnion');
{$ENDIF}
	end;
	
	procedure setYearUnion (pRelative: pRelativeType; indUnion: longint; year: double);
	var
		UInfo: pUnionInfoType = nil;
	begin
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			UInfo := newUnionInfo (pRelative);
		end;
		UInfo^.yearUnion := year;
	end;
	
	function getAgeEndUnion (pRelative: pRelativeType; indUnion: longint): double;
	var
{$IFDEF addOldUnionType}
		oldAgeEndUnion: double;
{$ENDIF}
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		oldAgeEndUnion := pRelative^.ageEndUnion [indUnion];
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then
			result := kNotDefined
		else
			result := UInfo^.ageEndUnion;
{$IFDEF addOldUnionType}
		if oldAgeEndUnion <> result then
			writeAndWait('ERROR ==> Bad getAgeEndUnion');
{$ENDIF}
	end;
	
	function getYearEndUnion (pRelative: pRelativeType; indUnion: longint): double;
	var
		UInfo: pUnionInfoType = nil;
	begin
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then
			result := kNotDefined
		else
			result := UInfo^.yearEndUnion;
	end;
	
	procedure setAgeEndUnion (pRelative: pRelativeType; indUnion: longint; age: double);
	var
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		pRelative^.ageEndUnion [indUnion] := age;
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			UInfo := newUnionInfo (pRelative);
		end;
		UInfo^.ageEndUnion := age;
{$IFDEF addOldUnionType}
		if pRelative^.ageEndUnion [indUnion] <> getUnionInfoByIndex (pRelative, indUnion)^.ageEndUnion then
			writeAndWait('ERROR ==> Bad setAgeEndUnion');
{$ENDIF}
	end;
	
	procedure setYearEndUnion (pRelative: pRelativeType; indUnion: longint; year: double);
	var
		UInfo: pUnionInfoType = nil;
	begin
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			UInfo := newUnionInfo (pRelative);
		end;
		UInfo^.yearEndUnion := year;
	end;
	
	function getPartner (pRelative: pRelativeType; indUnion: longint): pRelativeType;
	var
		UInfo: pUnionInfoType = nil;
	begin
		result := nil;
{$IFDEF addOldUnionType}
		result := pRelative^.partners [indUnion];
{$ENDIF}
		if (indUnion < 0) or (indUnion > 20) or (pRelative^.nUnions = 0) then
		begin
			writeAndWaitConst(['===> ERROR: getPartner: incorrect nUnion (', indUnion, '), relative number: ', pRelative^.indNumber]);
			exit;
		end;
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			// problem
			result := nil;
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
		end else
			result := UInfo^.partner;
{$IFDEF addOldUnionType}
		if pRelative^.partners [indUnion] <> getUnionInfoByIndex (pRelative, indUnion)^.partner then
			writeAndWait('ERROR ==> Bad getPartner');
{$ENDIF}
	end;
	
	function getLastPartner (pRelative: pRelativeType): pRelativeType;
	begin
		 result := nil;
		 if (pRelative <> nil) and (pRelative^.nUnions > 0) then
		 	result := getPartner(pRelative, pRelative^.nUnions);
	end;

	function getCauseEndLastUnion (pRelative: pRelativeType): CausesEndUnionType;
	begin
		 result := no_union;
		 if (pRelative <> nil) and (pRelative^.nUnions > 0) then
		 	result := getCauseEndUnion(pRelative, pRelative^.nUnions);
	end;
	
	procedure setPartner (pRelative: pRelativeType; indUnion: longint; pPartner: pRelativeType);
	var
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		pRelative^.partners [indUnion] := pPartner;
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			UInfo := newUnionInfo (pRelative);
		end;
		UInfo^.partner := pPartner;
{$IFDEF addOldUnionType}
		if pRelative^.partners [indUnion] <> getUnionInfoByIndex (pRelative, indUnion)^.partner then
			writeAndWait('ERROR ==> bad setPartner');
{$ENDIF}
	end;
	
	function getIndUnion (pRelative, pPartner: pRelativeType): longint;
	// index of union between pRelative and pPartner (for pRelative)
	var
		indUnion: longint;
	begin
		for indUnion := 1 to pRelative^.nUnions do
			if getPartner(pRelative, indUnion) = pPartner then
				exit (indUnion);
		result:= kNotDefined;
	end;
	
	function getCauseEndUnion (pRelative: pRelativeType; indUnion: longint): CausesEndUnionType;
	var
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		result := pRelative^.endOfPartnership [indUnion];
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then
			result := no_union
		else
			result := UInfo^.endOfPartnership;
	end;
	
	procedure setCauseEndUnion (pRelative: pRelativeType; indUnion: longint; cause: CausesEndUnionType);
	var
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		pRelative^.endOfPartnership [indUnion] := cause;
{$ENDIF}
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		if (UInfo = nil) then begin
			UInfo := newUnionInfo (pRelative);
		end;
		UInfo^.endOfPartnership := cause;
	end;
	
	procedure newNuptialitySettings (var n: NuptialitySettings);
	var
		ageWomen, ageMen: agesUnion;

	begin
		for ageWomen := kMinAgeUnion to kMaxAgeUnion do
			begin
				n.union_women_men[ageWomen, normal] := SetLengthDoubleZero (kMaxAgeUnion+1);
				n.union_women_men[ageWomen, aggregated] := SetLengthDoubleZero (kMaxAgeUnion+1);
			end;
		for ageMen := kMinAgeUnion to kMaxAgeUnion do
			begin
				n.union_men_women[ageMen, normal] := SetLengthDoubleZero (kMaxAgeUnion+1);
				n.union_men_women[ageMen, aggregated] := SetLengthDoubleZero (kMaxAgeUnion+1);
			end;

		n.union_women := SetLengthDoubleZero (kMaxAgeUnion+1);
		n.prop_cel_women := SetLengthDouble (kMaxAgeSingle+1, 1.0);

		n.nupt_men := SetLengthDoubleZero (kMaxAgeUnion+1);
		n.prop_cel_men := SetLengthDouble (kMaxAgeSingle+1, 1.0);

		SetLength (n.prop_repartnering, 2, kMaxAgeSingle+1);
		n.prop_not_repartnering := SetLengthDouble (kMaxDurationSeparation + 1, 1.0);
		SetLength (n.prop_repartnering_widowhood, 2, kMaxAgeSingle+1);
		n.prop_not_repartnering_widowhood := SetLengthDouble (kMaxDurationSeparation + 1, 1.0);
		SetLength (n.prop_repartnering_duration, 2, (kMaxShownDurationUnion+1) * kNbLunarMonths);
		SetLength (n.prop_repartnering_widowhood_duration, 2, (kMaxShownDurationUnion+1) * kNbLunarMonths);
	end;
	
	procedure disposeNuptialitySettings (var n: NuptialitySettings);
	var
		ageWomen, ageMen: longint;
	begin
		for ageWomen := kMinAgeUnion to kMaxAgeUnion do
		begin
			SetLength (n.union_women_men[ageWomen, normal], 0);
			SetLength (n.union_women_men[ageWomen, aggregated], 0);
		end;
		for ageMen := kMinAgeUnion to kMaxAgeUnion do
		begin
			SetLength (n.union_men_women[ageMen, normal], 0);
			SetLength (n.union_men_women[ageMen, aggregated], 0);
		end;

		SetLength (n.union_women, 0);
		SetLength (n.prop_cel_women, 0);

		SetLength (n.nupt_men, 0);
		SetLength (n.prop_cel_men, 0);
		
		SetLength (n.prop_repartnering, 0);
		SetLength (n.prop_not_repartnering, 0);
		SetLength (n.prop_repartnering_widowhood, 0);
		SetLength (n.prop_not_repartnering_widowhood, 0);
		SetLength (n.prop_repartnering_duration, 0);
		SetLength (n.prop_repartnering_widowhood_duration, 0);
	end;

	function calcSmam (prop_cel: tabSingleVar; ageFinal: agesSingle): double;
	var
		age: agesUnion;
		smam : double;
	begin
		smam := kMinAgeUnion - 1.0 - (ageFinal) * prop_cel[ageFinal];
		for age := kMinAgeUnion to ageFinal - 1 do
			smam := smam + prop_cel[age];
		calcSmam := smam / (1.0 - prop_cel[ageFinal]);
	end;

	function calcSmamFromAgeProb (ageFinal: agesUnion; var probs: tabNuptVar): double;
	var
		propCel: tabSingleVar;
		age: agesSingle;
	begin
		propCel := SetLengthDouble (kMaxAgeSingle, 1.0);
		for age := kMinAgeSingle + 1 to ageFinal do
			propCel [age] := propCel [age-1] - probs [age-1];
		calcSmamFromAgeProb := calcSmam(propCel, ageFinal);
		SetLength (propCel, 0)
	end;
	
	procedure propCelFromRates (minAge, maxAge: longint; nupt: tabNuptVar; var propCel: tabSingleVar);
	var
		age: agesSingle;
	begin
 		// From the lowest age up to minAge
	   if minAge < kMinAgeSingle then
		   for age := kMinAgeSingle to minAge - 1 do
			   propCel[age] := 1.0;
		propCel[minAge] := 1.0;
		for age := minAge+1 to maxAge do
			propCel[age] := propCel[age - 1] - nupt[age - 1];
		// prolongate the final proportion single up to the highest age
		if maxAge < kMaxAgeSingle then
			for age := maxAge + 1 to kMaxAgeSingle do
				propCel[age] := propCel[age-1];
	end;
	
	procedure aggregateNupt (ageMax: agesUnion; var n: tabNuptCrossed);
	var
		age1, age2: agesUnion;
	begin
		for age1 := kMinAgeUnion to kMaxAgeUnion do begin
			n[age1, aggregated, kMinAgeUnion] := n[age1, normal, kMinAgeUnion];
			for age2 := kMinAgeUnion+1 to ageMax do begin
				n[age1, aggregated, age2] := n[age1, normal, age2] + n[age1, aggregated, age2-1];
			end;
			for age2 := ageMax to kMaxAgeUnion do begin
				n[age1, aggregated, age2] := 1.0;
			end;
		end;
	end;
	
	procedure writeCrossNupt (fileName: string; n: tabNuptCrossed);
	var
		f: TFileType; // Used by main thread only
		res: longint;
		
		procedure writeCrossNupt_part (typeNupt: typTabNupt);
		var
			age1, age2: agesUnion;
		begin
			cWrite (f, 'age');
			for age2 := kMinAgeUnion to kMaxAgeUnion do
				bWrite(f, [tab, age2]);
			cWriteLn (f);
			for age1 := kMinAgeUnion to kMaxAgeUnion do begin
				bWrite(f, [age1]);
				for age2 := kMinAgeUnion to kMaxAgeUnion do begin
					bWrite(f, [tab, n[age1, typeNupt, age2]]);
				end;
				cWriteLn (f);
			end;
		end;
		
	begin
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + fileName, res, 'WRITECROSSNUPT');
			if res = 0 then begin
				cWriteLn (f, 'normal');
				writeCrossNupt_part (normal);
				cWriteLn (f, 'aggregated');
				writeCrossNupt_part (aggregated);
			end;
			f.Destroy;
		end;
	end;
	
	procedure initStandardNuptiality (p: pStructDemographicRegimeSettings; var n: NuptialitySettings);
	var
		meanDiffSex: double;
		ageWomen: agesUnionWomen;
		ageMen: agesUnionMen;
		mean, scaleFactor, mean_calc: double;
		ageMin: agesUnion;
		ageWomenInit, ageMenInit: agesUnion;
		freq_union_def: double;
		ageMarAll: longint;
	begin
		// First union for women
		if g_GENPARAM.FIXED_FERTILITY.value then begin
			n.unionParam [woman, freqFinUnion] := 1;
			n.unionParam [woman, meanUnion] := g_FIXED_FERTILITY_DATA.ageUnionWoman;
			n.unionParam [woman, stdUnion] := 0;
		end else begin
			n.unionParam [woman, freqFinUnion] := p^.dp[propFinalCelibacyLow].value;
			n.unionParam [woman, meanUnion] := p^.dp[meanAgeUnionWomenLow].value;
			if (p^.dp[stdnupt].value < 0) then begin
					n.unionParam [woman, stdUnion] := std_Coale_Rodriguez_Trussel (n.unionParam [woman, meanUnion]);
			end else
				n.unionParam [woman, stdUnion] := p^.dp[stdnupt].value;
		end;

		if ( g_GENPARAM.fixedParameters [fixedUnionAge].state.value = true ) or g_GENPARAM.FIXED_FERTILITY.value then begin
			// Fixed age at union for women
			freq_union_def := n.unionParam [woman, freqFinUnion];
			ageMarAll := trunc (n.unionParam [woman, meanUnion]);
			for ageWomen := kMinAgeUnion to kMaxAgeUnion_women do
				n.union_women[ageWomen] := 0.0;
			n.union_women[ageMarAll] := freq_union_def;
			propCelFromRates (kMinAgeUnion, kMaxAgeSingle_women, n.union_women, n.prop_cel_women);
		end else begin
			calcCelibacy_RT_woman (n.unionParam, n);
		end;

		// First union for men
		if g_GENPARAM.FIXED_FERTILITY.value then begin
			n.unionParam [man, freqFinUnion] := 1;
			n.unionParam [man, meanUnion] := g_FIXED_FERTILITY_DATA.ageUnionMan;
			n.unionParam [man, stdUnion] := 0;
		end else begin
			n.unionParam [man, freqFinUnion] := p^.dp[propFinalCelibacyMen].value;
			n.unionParam [man, meanUnion] := p^.dp[meanAgeUnionMen].value;
			n.unionParam [man, stdUnion] := std_Coale_Rodriguez_Trussel (n.unionParam [man, meanUnion]);
		end;
		
		if ( g_GENPARAM.fixedParameters [fixedUnionAge].state.value = true ) or g_GENPARAM.FIXED_FERTILITY.value then begin
			// Fixed age at union for men
			freq_union_def := n.unionParam [man, freqFinUnion];
			ageMarAll := trunc (n.unionParam [man, meanUnion]);
			for ageMen := kMinAgeUnion_men to kMaxAgeUnion_men do
				n.nupt_men[ageMen] := 0.0;
			n.nupt_men[ageMarAll] := freq_union_def;
			propCelFromRates (kMinAgeUnion, kMaxAgeSingle, n.nupt_men, n.prop_cel_men);
		end else begin
			calcCelibacy_RT_man (n.unionParam, n);
		end;

		meanDiffSex := n.unionParam [man, meanUnion] - n.unionParam [woman, meanUnion];
		
		for ageWomenInit := kMinAgeUnion to kMaxAgeUnion do
		begin
			for ageMenInit := kMinAgeUnion to kMaxAgeUnion do
				begin
					n.union_women_men[ageWomenInit, normal, ageMenInit] := 0;
					n.union_women_men[ageWomenInit, aggregated, ageMenInit] := 0;
					n.union_men_women[ageMenInit, normal, ageWomenInit] := 0;
					n.union_men_women[ageMenInit, aggregated, ageWomenInit] := 0;
				end;
		end;
		n.nupt_men_women_init := true;
		
		// Distribution of ages at union of men for each age at union of women
		for ageWomen := kMinAgeUnion_women to kMaxAgeUnion_women do begin
			mean := min (kMaxAgeUnion_men - 1, ageWomen + meanDiffSex);
			mean := max (mean, kMinAgeUnion_men + 1);
			ageMin := max (kMinAgeUnion_men, ageWomen - 5);
			scaleFactor := (mean - ageMin) / 11.37;
			calcNuptScaleFactor (ageMin, scaleFactor, n.union_women_men[ageWomen, normal]);
			mean_calc := calcSmamFromAgeProb (kMaxAgeUnion_women, n.union_women_men[ageWomen, normal]);
			if (abs (mean - mean_calc) > 0.01) then begin
					scaleFactor := ((mean + (mean - mean_calc) * (1+ ageWomen / (2 * kMaxAgeUnion_women))) - ageMin) / 11.37;
					calcNuptScaleFactor (ageMin, scaleFactor, n.union_women_men[ageWomen, normal]);
 					mean_calc := calcSmamFromAgeProb (kMaxAgeUnion_women, n.union_women_men[ageWomen, normal]);
 					
if gRunFromIDE then
	if (abs (mean - mean_calc) > 0.5) then
		mean_calc := mean_calc;
						
			end;
		end;

		aggregateNupt (kMaxAgeUnion_men, n.union_women_men);
		
		// Distribution of ages at union of women for each age at union of men
		for ageMen := kMinAgeUnion_men to kMaxAgeUnion_men do begin
			mean := max (kMinAgeUnion_women + 1, ageMen - meanDiffSex);
			mean := min (kMaxAgeUnion_women - 1, mean);
			ageMin := kMinAgeUnion_women + trunc ( (ageMen - kMinAgeUnion_men) / 5 );
			scaleFactor := (mean - ageMin) / 11.37;
			calcNuptScaleFactor (ageMin, scaleFactor, n.union_men_women[ageMen, normal]);
			mean_calc := calcSmamFromAgeProb (kMaxAgeUnion_men, n.union_men_women[ageMen, normal]);
			if (abs (mean - mean_calc) > 0.01) then begin
			  scaleFactor := ((mean + (mean - mean_calc) * (1+ ageMen / (kMaxAgeUnion_men))) - ageMin) / 11.37;
			  calcNuptScaleFactor (ageMin, scaleFactor, n.union_men_women[ageMen, normal]);
 				  mean_calc := calcSmamFromAgeProb (kMaxAgeUnion_men, n.union_men_women[ageMen, normal]);

if gRunFromIDE then
	if (abs (mean - mean_calc) > 0.5) then begin
        mean_calc := mean_calc;
   end;

			end;
		end;

		aggregateNupt (kMaxAgeUnion_women, n.union_men_women);

		if ( g_GENPARAM.fixedParameters [fixedUnionAge].state.value = true ) or g_GENPARAM.FIXED_FERTILITY.value then begin
			// Here we cover the whole age range, although we only need one age
			// distribution of women by age for each age at union of men
			ageMarAll := trunc (n.unionParam [woman, meanUnion]);				
			for ageMen := kMinAgeUnion_men to kMaxAgeUnion_men do begin
				for ageWomen := kMinAgeUnion_women to ageMarAll - 1 do
					n.union_men_women[ageMen, aggregated, ageWomen] := 0.0;
				for ageWomen := ageMarAll to kMaxAgeUnion_women do
					n.union_men_women[ageMen, aggregated, ageWomen] := 1.0;
				for ageWomen := kMinAgeUnion_women to kMaxAgeUnion_women do
					n.union_men_women[ageMen, normal, ageWomen] := 0.0;
				n.union_men_women[ageMen, normal, ageMarAll] := 1.0;
			end;
			// distribution of men by age for each age at union of women
			ageMarAll := trunc (n.unionParam [man, meanUnion]);
			for ageWomen := kMinAgeUnion to kMaxAgeUnion_women do begin
				for ageMen := kMinAgeUnion_men to ageMarAll - 1 do
					n.union_women_men[ageWomen, aggregated, ageMen] := 0.0;
				for ageMen := ageMarAll to kMaxAgeUnion_men do
					n.union_women_men[ageWomen, aggregated, ageMen] := 1.0;
				for ageMen := kMinAgeUnion_men to kMaxAgeUnion_men do
					n.union_women_men[ageWomen, normal, ageMen] := 0.0;
				n.union_women_men[ageWomen, normal, ageMarAll] := 1.0;
			end;
		end;

		if g_GENPARAM.DEBUG.value then begin
 			writeCrossNupt ('union_women_men.txt', n.union_women_men);
			writeCrossNupt ('union_men_women.txt', n.union_men_women);
		end;

	end;
	
	procedure initStandardSeparation (p: pStructDemographicRegimeSettings);
	begin
		{separation_alpha := 1.7;}
		{separation_beta := 0.01;}
		{separation_lambda := 0.015;}

		// inverse of the scale parameter in the generalized log-logistic model: median duration in number of lunar months
		p^.separationInfo.separation_median := 115.6798094; {median value}
		// value of the shape parameter in Bruederl-Diekmann gen. log-logistic model
		p^.separationInfo.separation_shape := 1.97291202;
		// value of the proportion parameter in the generalized log-logistic model
		p^.separationInfo.separation_proportion := 0.00822579;

		initRelativeRiskSeparation (p^.separationInfo);
		
		calcSeparation (0.0, p^.separationInfo); {No separation}
	end;

	procedure initStandardRepartnering(var pN: pNuptialitySettings);
	begin
		calcRepartnering (0.0, 0.0, pN^.prop_repartnering, pN^.prop_not_repartnering); {No repartnering}
		calcRepartnering (0.0, 0.0, pN^.prop_repartnering_widowhood, pN^.prop_not_repartnering_widowhood); {No repartnering}
		calcRepartnering_duration (0.0, 0.0, 0.0, 0.0, pN^.prop_repartnering_duration); {repartnering}
		calcRepartnering_duration (0.0, 0.0, 0.0, 0.0, pN^.prop_repartnering_widowhood_duration); {repartnering}
	end;
	
	procedure adjustTabNupt (freqFin: double; var firstUnion: tabNuptVar);
	var
		freqFinCal: double;
		age: longint;

	begin
		freqFinCal := 0.0;
		for age := low(firstUnion) to high(firstUnion) do begin
			freqFinCal := freqFinCal + firstUnion[age];
		end;

		if (abs (freqFin - freqFinCal) > 0.0) then
		begin
			freqFinCal := freqFin / freqFinCal;
			for age := low(firstUnion) to high(firstUnion) do
				firstUnion[age] := firstUnion[age] * freqFinCal;
		end;
	end;
	
	{kMinAgeUnion: here we use the value of 10 years}
	{freqFin: frequency of celibacy at kMaxAgeUnion years}
	{scaleFactor: The scale factor. Corresponds to the formula (SMAM-kMinAgeUnion)/11.36}
	{BEWARE: when fachEch < 0.135, then the resulting values are too low. So this value of fachEch should be taken as a minimum}
	{BEWARE: also there is a problem, as variance is kept constant, when it should disminish with increasing value of fachEch}
	{BEWARE: in this line the alternative Rodriguez / Trussel formulation may be prefered, as it uses the mean and variance
	as the two function parameters}
{
#' The Coale-McNeil Nuptiality Model (Rodriguez implementation in R)
#'
#' Computes cumulative probabilities of union by age
#' @param age vector of exact ages
#' @param mean scalar representing mean age at union
#' @param stdev scalar representing standard deviation of age at union
#' @param pem probability of ever in union, defaulting to 1
#' @export
pnupt <- function(age, mean, stdev, pem=1) {%H-}{
  if(stdev <= 0)
	stop("Standard deviation must be positive")
  if( pem <= 0 | pem > 1)
	stop ("Probability of ever in union must be in (0,1]")
  z <- (age - mean)/stdev
  pem * pgamma( exp(-1.896 * (z + 0.805)), shape=0.604, lower.tail = FALSE)
}
}

	procedure CoaleFirstUnion (kMinAgeUnion: longint; freqFin, scaleFactor: double; var firstUnion: tabNuptVar);
		var
			age: agesUnion;
			mean: double;
	begin
		freqFin := 1 - freqFin;
		mean := 0;
		for age := kMinAgeUnion to kMaxAgeUnion do begin
			firstUnion[age] := 0.19465 * (freqFin / scaleFactor) * exp(((-0.174 / scaleFactor) * (age - kMinAgeUnion - 6.06 * scaleFactor)) - exp((-0.2881 / scaleFactor) * (age - kMinAgeUnion - 6.06 * scaleFactor)));
			mean := mean + firstUnion[age] * age;
		end;
		adjustTabNupt (freqFin, firstUnion);
	end;
	
{Results will be the same as CoaleFirstUnion (10, 1, 1) using RodTrussFirstUnion (1, 21.36, 6.583312236)
This corresponds to values of the mean and variance of Coale age standard as given in Rodriguez and Trussel (1980)}
	procedure RodTrussFirstUnion (minAgeUnion_calc, maxAgeUnion_calc: longint; freqFin, mean, std: double; var firstUnion: tabNuptVar);
	var
		age: longint;
		temp, meanCalc: double;
	begin
		freqFin := 1 - freqFin;
		meanCalc := 0;
		for age := minAgeUnion_calc to maxAgeUnion_calc do
		begin
			temp := 0.805 + (age - mean) / std;
			firstUnion[age] := (freqFin * 1.2813 / std) * exp( -1.145 * temp - exp (-1.896 * temp) );
			meanCalc := meanCalc + firstUnion[age] * (age);
		end;
				// for checking...
				meanCalc := meanCalc / freqFin;

		adjustTabNupt (freqFin, firstUnion);
	end;

  	procedure calc_firstUnion (min, max: agesUnion; firstUnion: tabNuptVar; var tabNormal, tabCumul: tabNuptVar);
		var
			age: agesUnion;
			ind: agesUnion;
			step, indNupt, sum: double;
	begin
		step := (kMaxAgeUnion - kMinAgeUnion + 1) / (max - min + 1);
		indNupt := kMinAgeUnion - step;
		sum := 0.0;
		for age := min to max do
			begin
				indNupt := indNupt + step;
				ind := trunc(indNupt);
				tabNormal[age] := firstUnion[ind] + (firstUnion[ind + 1] - firstUnion[ind]) * (indNupt - ind);
				sum := sum + tabNormal[age];
			end;
		for age := min to max do
			tabNormal[age] := tabNormal[age] / sum;
		tabCumul[min] := tabNormal[min];
		for age := min + 1 to max do
			tabCumul[age] := tabNormal[age] + tabCumul[age - 1];
		{changement 2003: ajout ligne suivante}
		tabCumul[max] := 1.0;
	end;

	procedure calcRepartnering (freqFin_women, freqFin_men: double; var prop_repartnering: array2doubletype; var prop_not_repartnering: arrayOfDouble);
	var
		ind: longint;
		currSex: Sex;
		param: array [Sex, 1..2] of double;
		freqFin: array [Sex] of double;
		currMinAgeUnion: array [Sex] of longint;
		currMaxAgeUnion: array [Sex] of longint;
	begin
		{
		Logistic distribution of repartnering frequency: repartnering peaks at age kMinAgeUnion,
		then falls slowly and then faster with age until it reaches a lower level.
		With standard values, we have the following form:
		for women, the frequency fall to half between the ages of 43 and 44;
		for men aged 47-48.
		The level falls to 25% of the initial level by the age of 51 for women and 55 for men.
		}
		
		param [man, 1] := 0.03;
		param [man, 2] := 5;

		param [woman, 1] := 0.03;
		param [woman, 2] := 5;

		freqFin [man] := freqFin_men;
		freqFin [woman] := freqFin_women;

		currMinAgeUnion [man] := kMinAgeUnion_men;
		currMinAgeUnion [woman] := kMinAgeUnion_women;

		currMaxAgeUnion [man] := kMaxAgeUnion_men;
		currMaxAgeUnion [woman] := kMaxAgeUnion_women;
		
		for currSex := man to woman do begin
			for ind := kMinAgeUnion to currMinAgeUnion[currSex] - 1 do
				prop_repartnering [currSex, ind] := freqFin [currSex];
			for ind := currMinAgeUnion[currSex] to currMaxAgeUnion [currSex] do
				prop_repartnering [currSex, ind] :=
					freqFin [currSex] * (
						1.0 / (
							1.0 +
							power (param [currSex, 1] * (ind - currMinAgeUnion[currSex]), param [currSex, 2])
							)
					);
			for ind := currMaxAgeUnion [currSex] + 1 to kMaxAgeUnion do
				prop_repartnering [currSex, ind] := 0;
		end;
		
		RodTrussFirstUnion (kMinDurationSeparation, kMaxDurationSeparation, 0, 5, 2, prop_not_repartnering);
 		prop_not_repartnering[kMaxDurationSeparation] := 0;
		for ind := kMaxDurationSeparation-1 downto kMinDurationSeparation do
			prop_not_repartnering[ind] := prop_not_repartnering[ind] + prop_not_repartnering[ind+1];
		prop_not_repartnering[kMinDurationSeparation] := 1;
	end;
	
	procedure calcRepartnering_duration (freqFin_women, freqFin_men, mean_women, mean_men: double; var prop_repartnering: array2doubletype);
	var
		ind: longint;
	begin
		init_waiting_time_distribution ((kMaxShownDurationUnion+1) * kNbLunarMonths - 1, prop_repartnering [woman], mean_women, freqFin_women, 0.3);
		init_waiting_time_distribution ((kMaxShownDurationUnion+1) * kNbLunarMonths - 1, prop_repartnering [man], mean_men, freqFin_men, 0.3);
		for ind := 0 to (length(prop_repartnering [woman]) - 1) do begin
			prop_repartnering [woman, ind] := prop_repartnering [woman, ind] * freqFin_women;
			prop_repartnering [man, ind] := prop_repartnering [man, ind] * freqFin_men;
		end;
	end;

	procedure interpRelRisk (var relRisque: separationRelRisqueType);
	var
		ind, ind1, ind2: longint;
		val1, val2: double;
	begin
		ind1 := -11;
		val1 := relRisque [ind1];
		ind2 := 0;
		val2 := 0.0;
		
		for ind := -10 to kMaxDurationUnionInMonths -1 do
		begin
			if relRisque [ind] = 0.0 then
			begin
				if val2 = 0.0 then
				begin
					ind2 := ind + 1;
					while (ind2 < kMaxDurationUnionInMonths) and (relRisque [ind2] = 0.0) do
					begin
						ind2 := ind2 + 1;
					end;
					val2 := relRisque [ind2];
				end;
				
				relRisque [ind] := interpole (val1, val2, ( ind - ind1 ), ( ind2 - ind1 ));
			end else
			begin
				ind1 := ind;
				val1 := relRisque [ind1];
				ind2 := 0;
				val2 := 0.0;
			end;
		end;
	end;
	
	procedure initRelativeRiskSeparation(var d: SeparationSettings);
	var
		ind: longint;
	begin
		for ind := -11 to kMaxDurationUnionInMonths do
		begin
			d.relRisk_separation_children_duration [oneChild, ind] := 0.0;
			d.relRisk_separation_children_duration [twoChildrenMore, ind] := 0.0;
		end;
		
		if (kNbLunarMonths = 13) then {%H-}begin
			d.relRisk_separation_children_duration [oneChild, -11] := 1.0;
			d.relRisk_separation_children_duration [oneChild, -6] := 0.15;
			d.relRisk_separation_children_duration [oneChild, 3] := 0.05;
			d.relRisk_separation_children_duration [oneChild, 13] := 0.40;
			d.relRisk_separation_children_duration [oneChild, 26] := 0.60;
			d.relRisk_separation_children_duration [oneChild, 52] := 1.0;
			d.relRisk_separation_children_duration [oneChild, kMaxDurationUnionInMonths] := 1.0;
		end else begin
			d.relRisk_separation_children_duration [oneChild, -10] := 1.0;
			d.relRisk_separation_children_duration [oneChild, -6] := 0.15;
			d.relRisk_separation_children_duration [oneChild, 3] := 0.05;
			d.relRisk_separation_children_duration [oneChild, 12] := 0.40;
			d.relRisk_separation_children_duration [oneChild, 24] := 0.60;
			d.relRisk_separation_children_duration [oneChild, 48] := 1.0;
			d.relRisk_separation_children_duration [oneChild, kMaxDurationUnionInMonths] := 1.0;
		end;
		
		interpRelRisk (d.relRisk_separation_children_duration [oneChild]);
		
		if (kNbLunarMonths = 13) then {%H-}begin
			d.relRisk_separation_children_duration [twoChildrenMore, -11] := 0.5;
			d.relRisk_separation_children_duration [twoChildrenMore, -6] := 0.075;
			d.relRisk_separation_children_duration [twoChildrenMore, 3] := 0.025;
			d.relRisk_separation_children_duration [twoChildrenMore, 13] := 0.2;
			d.relRisk_separation_children_duration [twoChildrenMore, 26] := 0.4;
			d.relRisk_separation_children_duration [twoChildrenMore, 52] := 0.65;
			d.relRisk_separation_children_duration [twoChildrenMore, 78] := 0.8;
			d.relRisk_separation_children_duration [twoChildrenMore, 114] := 0.85;
			d.relRisk_separation_children_duration [twoChildrenMore, kMaxDurationUnionInMonths] := 1;
		end else begin
			d.relRisk_separation_children_duration [twoChildrenMore, -10] := 0.5;
			d.relRisk_separation_children_duration [twoChildrenMore, -6] := 0.075;
			d.relRisk_separation_children_duration [twoChildrenMore, 3] := 0.025;
			d.relRisk_separation_children_duration [twoChildrenMore, 12] := 0.2;
			d.relRisk_separation_children_duration [twoChildrenMore, 24] := 0.4;
			d.relRisk_separation_children_duration [twoChildrenMore, 48] := 0.65;
			d.relRisk_separation_children_duration [twoChildrenMore, 72] := 0.8;
			d.relRisk_separation_children_duration [twoChildrenMore, 105] := 0.85;
			d.relRisk_separation_children_duration [twoChildrenMore, kMaxDurationUnionInMonths] := 1;
		end;

		interpRelRisk (d.relRisk_separation_children_duration [twoChildrenMore]);

	end;
	
	procedure calcSeparation (freqFin: double; var d: SeparationSettings);
	const
		duration100for100 = 60 * kNbLunarMonths; // duration at which we reach 100 %
	var
		ind: longint;
		adjust: double;
{$IFDEF DEBUG_SEPARATION}
f: TFileType;
{$ENDIF}		
	begin
		d.separationPossible := (freqFin > 0);
		
		for ind := 0 to kMaxDurationUnionInMonths do begin
			d.monthly_risk_separation [ind] := 0.0;
			d.cumul_separation [ind] := 0.0;
		end;

{generalized log-logistic}
		if d.separationPossible then
		begin
			for ind := 0 to duration100for100 - 1 do
			begin
				d.cumul_separation [ind] := 1 - 1 / power( (1 + power(ind / d.separation_median, d.separation_shape)), d.separation_proportion * d.separation_median);
			end;
			{IMPORTANT: 100% after 60 years of union}
			adjust := d.cumul_separation [duration100for100-1];
			for ind := 0 to duration100for100 - 1 do
			begin
				d.cumul_separation [ind] := d.cumul_separation [ind] / adjust;
			end;
			for ind := duration100for100 to kMaxDurationUnionInMonths do
			begin
				d.cumul_separation [ind] := 1;
			end;

{$IFDEF DEBUG_SEPARATION}
if checkDirResult () then begin
  IOResult;
  new (f);
  f^.filenameWithPath := gPathToResult + 'SeparationInfo.txt';
  assignFile (f.fileHandle, f^.filenameWithPath);
  rewrite (f.fileHandle);
  cWriteLn (f, 'cumul_separation first step');
  writeLnArrayOfDouble(f, tab, d.cumul_separation);
end;
{$ENDIF}						
			if freqFin > 1.0 then
				freqFin := 1.0;
				
			for ind := 0 to kMaxDurationUnionInMonths do
			begin
				d.cumul_separation [ind] := freqFin * d.cumul_separation [ind];
			end;
{$IFDEF DEBUG_SEPARATION}
  cWriteLn (f, 'cumul_separation second step');
  writeLnArrayOfDouble(f, tab, d.cumul_separation);
{$ENDIF}						
			
			for ind := 0 to kMaxDurationUnionInMonths-1 do
			begin
				d.monthly_risk_separation [ind] := d.cumul_separation [ind+1] - d.cumul_separation [ind];
				if d.cumul_separation [ind] < 1 then
					d.monthly_risk_separation [ind] := d.monthly_risk_separation [ind] / (1 - d.cumul_separation [ind])
				else
					d.monthly_risk_separation [ind] := 0;
			end;
{$IFDEF DEBUG_SEPARATION}
  cWriteLn (f, 'monthly_risk_separation');
  writeArrayOfDouble(f, tab, d.monthly_risk_separation, true);
  f.Destroy;
{$ENDIF}						
			
		end;
	end;

	function livingChild (pCurrInfoChildren: pInfoChildType; nbUnions, currMonth: longint): boolean;
	begin
		if pCurrInfoChildren^.motherUnionNumber = nbUnions then
		begin
			livingChild := pCurrInfoChildren^.deathChildSinceBirthOfMotherInMonths >= currMonth;
		end else
		begin
			livingChild := false;
		end;
	end;
	
	function endBySeparation (randomGenerator: TRandomNumberGenerator;
                    		monthStart, currMonth, nbPregnanciesInCurrentUnion: longint;
							pCurrInfoChildren: pInfoChildType;
							d: SeparationSettings;
							dp: arrayDemReg_double;
                            var unionStates: TUnionsType): boolean;
	var
		aleaSeparation: double;
		durationUnion: longint;
		nbChildren_Alive: longint; {On compte la grossesse en cours}
		nbChildren: nbChildrenEnum;
		ageOfYoungerInMonths: longint;
		pInfoChildren: pInfoChildType;
		separationRisk: double;
		
	begin
		if not d.separationPossible then begin
			endBySeparation := false;
			exit;
		end;

		durationUnion := currMonth - monthStart;
		nbChildren_Alive := 0;
		ageOfYoungerInMonths := 0;
try // 1
		if nbPregnanciesInCurrentUnion > 0 then
		begin
			if livingChild (pCurrInfoChildren, unionStates.nbUnions, currMonth) then
			begin
				ageOfYoungerInMonths := durationUnion - pCurrInfoChildren^.durationUnion;
				nbChildren_Alive := nbChildren_Alive + 1;
			end;
			pInfoChildren := pCurrInfoChildren^.previous;
			while pInfoChildren <> nil do
			begin
				if livingChild (pInfoChildren, unionStates.nbUnions, currMonth) then
				begin
					nbChildren_Alive := nbChildren_Alive + 1;
				end;
				pInfoChildren := pInfoChildren^.previous;
			end;
		end;

		aleaSeparation := randomGenerator.alea0;
		separationRisk := d.monthly_risk_separation [durationUnion];

		if (nbChildren_Alive > 0) and ( g_GENPARAM.fixedParameters [homogeneousSeparation].state.value = false ) then
		begin
			nbChildren := oneChild;
			if nbChildren_Alive > 2 then
				nbChildren := twoChildrenMore;
			separationRisk := separationRisk * d.relRisk_separation_children_duration [nbChildren, ageOfYoungerInMonths];
		end;
except // 1
	on E: Exception do begin
    	writeAndWaitConst(['===> ERROR: ', E.Message]);
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(false,E.Message)
{$ENDIF}
	end;
end;

		{in the case of a previous separation, the risk of a new separation is different}
		if unionStates.breakdownBySeparation then
			separationRisk := separationRisk * dp[rel_risk_2Separation].value;
				
		if (separationRisk >= aleaSeparation) then begin
			endBySeparation := true;
			unionStates.breakdownBySeparation := true;
		end else
			endBySeparation := false;
	end;

	procedure calcNuptScaleFactor (minAge: longint; scaleFactor: double; var n: tabNuptVar);
	begin
		CoaleFirstUnion(minAge, 0, scaleFactor, n);

		adjustTabNupt (1, n);
	end;

	procedure calcNuptScaleFactorRT (minAge, maxAge: longint; mean: double; var n: tabNuptVar);
	var
		stdv: double;
	begin
		stdv := std_Coale_Rodriguez_Trussel (mean);
		RodTrussFirstUnion(minAge, maxAge, 0.0, mean, stdv, n);

		adjustTabNupt (1, n);
	end;

	procedure calcCelibacy (freqFin, scaleFactor: double; var n: NuptialitySettings);
	begin
		CoaleFirstUnion(kMinAgeSingle, 1 - freqFin, scaleFactor, n.union_women);
		
		propCelFromRates (kMinAgeSingle, kMaxAgeSingle_women, n.union_women, n.prop_cel_women);
	end;

	procedure calcCelibacy_RT_woman (const values: array of ArrayParamSinglehood_RT_type; var n: NuptialitySettings);
		var
			ageWomen: agesSingleWomen;
			adjust: double;
			
	begin
		for ageWomen := kMinAgeSingle to kMaxAgeSingle_women do
			n.union_women[ageWomen] := 0.0;

		RodTrussFirstUnion(kMinAgeUnion_women, kMaxAgeUnion_women, 1.0 - values [woman, freqFinUnion], values [woman, meanUnion], values [woman, stdUnion], n.union_women);

		adjust := 0;
		for ageWomen := kMinAgeUnion_women to kMaxAgeUnion_women do
			adjust := adjust + n.union_women[ageWomen];
		for ageWomen := kMinAgeUnion_women to kMaxAgeUnion_women do
			n.union_women[ageWomen] := values [woman, freqFinUnion] * n.union_women[ageWomen] / adjust;
			
		propCelFromRates (kMinAgeSingle, kMaxAgeSingle_women, n.union_women, n.prop_cel_women);
		
	end;

	procedure calcCelibacy_RT_man (const values: array of ArrayParamSinglehood_RT_type; var n: NuptialitySettings);
		var
			ageMen: agesSingleMen;
			adjust: double;
			
	begin
		for ageMen := kMinAgeUnion to kMaxAgeUnion do
			n.nupt_men[ageMen] := 0.0;

		RodTrussFirstUnion(kMinAgeUnion_men, kMaxAgeUnion_men, 1.0 - values [man, freqFinUnion], values [man, meanUnion], values [man, stdUnion], n.nupt_men);

		adjust := 0;
		for ageMen := kMinAgeUnion_men to kMaxAgeUnion_men do
			adjust := adjust + n.nupt_men[ageMen];
		for ageMen := kMinAgeUnion_men to kMaxAgeUnion_men do
			n.nupt_men[ageMen] := values [man, freqFinUnion] * n.nupt_men[ageMen] / adjust;
			
		propCelFromRates (kMinAgeSingle, kMaxAgeSingle_men, n.nupt_men, n.prop_cel_men);
	end;

	procedure writeSMAM (p: pStructDemographicRegimeSettings);
		var
			smam_women, smam_men: double;

	begin

		if g_GENPARAM.FIXED_FERTILITY.value then begin
			smam_women := g_FIXED_FERTILITY_DATA.ageUnionWoman;
			smam_men := g_FIXED_FERTILITY_DATA.ageUnionMan;
		end else begin
			smam_women := calcSmam(p^.pCurrUnionInfo^.prop_cel_women, kMaxAgeSingle_women);
			smam_men := calcSmam(p^.pCurrUnionInfo^.prop_cel_men, kMaxAgeSingle_men);
		end;

		if g_GENPARAM.FERTILITY.value then begin
			aWriteLn(gOutFileAgeMat, ['SMAM women: ', tab, smam_women, tab, ', SMAM men: ', tab, smam_men]);
			if NOT g_GENPARAM.outputs_opt[cmd_outputtomainfile].value then
				aWriteLn(gOutFilePPR, ['SMAM women: ', tab, smam_women, tab, ', SMAM men: ', tab, smam_men]);
		end;
	end;

	function calc_ageUnion (randomGenerator: TRandomNumberGenerator;
                            ageMin, ageMax: double;
                            prop_cel: tabSingleVar;
                            singlehoodPossible: boolean = true): double;
	var
		dummy: double;
		age: agesSingle;
		ageMin_int, ageMax_int: agesSingle;
	begin
		ageMin_int := trunc (ageMin);
		ageMax_int := round (ageMax);
	// prop_cel is a monotonically decreasing function
		result := kNotDefined;
		if singlehoodPossible then begin
			dummy := randomGenerator.alea0;
			if dummy < prop_cel[ageMax_int] then
				exit;
		end;
		dummy := randomGenerator.alea(prop_cel[ageMin_int], prop_cel[ageMax_int]);
		age := ageMin_int;
		while (age < kMaxAgeUnion) and (dummy < prop_cel[age + 1]) do
			age := age + 1;
		result := min (ageMax, max(ageMin, age + randomGenerator.alea(0, 0.9999999999) - 0.5));
		if (result = ageMin_int) then
			result := result + randomGenerator.alea(0, 0.9999999999);
	end;
		
	function std_Campbell_Wood_1988 (mean: double): double;
	{adaptation équation Campbell & Wood [1988]}
	var
		std : double;
	begin
		std := 107.0 * ln (mean) - 292.0;
		std_Campbell_Wood_1988 := sqrt (std);
	end;
	
	function std_Logistic_Dani_2004 (mean, final_level: double): double;
	var
		std : double;
	begin
		std := final_level * final_level;
		std := std / ( 1.0 + 500.0 * exp (-2.5 - ( mean - kMinMeanAgeUnion ) / 2.0));
		std_Logistic_Dani_2004 := sqrt (std);
	end;

	function std_Coale_Rodriguez_Trussel (mean: double): double;
	begin
		std_Coale_Rodriguez_Trussel := sqrt (43.34 * abs ( mean - 13.64 ) / 11.36);
	end;
	
	function std_unionLinear (meanAgeUnionWomenLow, meanAgeUnionWomenHigh, stddevBasUnion, stddevHautUnion, mean: double): double;
	var
		std : double;
	begin
		if ( meanAgeUnionWomenHigh = meanAgeUnionWomenLow ) then begin
			std := stddevBasUnion;
		end else begin
			std := stddevBasUnion + ( (mean) - meanAgeUnionWomenLow ) * ( stddevHautUnion - stddevBasUnion) / ( meanAgeUnionWomenHigh - meanAgeUnionWomenLow );
		end;
		std_unionLinear := std;
	end;
		
	function repartnering (randomGenerator: TRandomNumberGenerator;
                            sex_individual: Sex;
                            currUnionState: UnionAgeDurationsType;
                            var ageNextUnion: double;
                            pN: pNuptialitySettings;
                            objOutputFert: TOutputFertility): boolean;
	var
		ageDeath, ageSeparation, ageWhenSpouseDied, ageEndUnion: double;
		sex_spouse: Sex;
		aleaRepartnering: double;
		ageRepartnering: double;
		ind: longint;
		maxAgeCel_sex: longint;
		causeEndUnion: CausesEndUnionType = no_union;
		pRepartnering: array of array of double;
		pNotRepartnering: array of double;

		{no_union = 0;
		end_by_death = 1;
		end_by_widowhood = 2;
		end_by_separation = 3;
		end_allTypes = 4;}
	begin
		result := false;
		ageNextUnion := kNotDefined;

		if sex_individual = woman then
		begin
			sex_spouse := man;
			maxAgeCel_sex := kMaxAgeUnion_women;
		end
		else
		begin
			sex_spouse := woman;
			maxAgeCel_sex := kMaxAgeUnion_men;
		end;
				
		{age of union termination (by separation or death of spouse)}
		ageDeath := currUnionState.ages[le_death, sex_individual];		{NOT always}
		ageSeparation := currUnionState.ages[le_endUnion, sex_individual];	{NOT always}
		ageWhenSpouseDied := currUnionState.ages[le_union, sex_individual]	{NOT always}
							+ currUnionState.ages[le_death, sex_spouse]
							- currUnionState.ages[le_union, sex_spouse];
		
		if ageDeath < 0 then
			ageDeath := kMaxAgeLife+1;
			
		ageEndUnion := ageDeath;
		if ageSeparation > 0 then
			ageEndUnion := min_real (ageEndUnion, ageSeparation);
		if ageWhenSpouseDied > 0 then
			ageEndUnion := min_real (ageEndUnion, ageWhenSpouseDied);
			
		pRepartnering := nil;
		pNotRepartnering := nil;
		if (ageEndUnion = ageSeparation) then begin
			causeEndUnion := end_by_separation;
			pRepartnering := pN^.prop_repartnering;
			pNotRepartnering := pN^.prop_not_repartnering;
		end;
		if (ageEndUnion = ageWhenSpouseDied) then begin
			causeEndUnion := end_by_widowhood;
			pRepartnering := pN^.prop_repartnering_widowhood;
			pNotRepartnering := pN^.prop_not_repartnering_widowhood;
		end;
		if (ageEndUnion = ageDeath) then begin
			causeEndUnion := end_by_death;
			pRepartnering := nil;
			pNotRepartnering := nil;
			exit;
		end;
		
		ageRepartnering := ageDeath;

		ageEndUnion := max(ageEndUnion, kMinAgeUnion);
		if ageEndUnion <  maxAgeCel_sex then
			objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), kNotDefined] :=
									objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), kNotDefined] + 1;
		
		if (ageEndUnion < ageDeath) and (ageEndUnion <= kMaxAgeUnion) then
		begin
			aleaRepartnering := randomGenerator.alea0;
			if aleaRepartnering <= pRepartnering [sex_individual, trunc (ageEndUnion)] then
			begin
				aleaRepartnering := randomGenerator.alea0;
				ind := kMinDurationSeparation;
				while (ind < kMaxDurationSeparation) and (aleaRepartnering < pNotRepartnering[ind]) do
					ind := ind + 1;

				ageRepartnering := ageEndUnion + ind - kMinDurationSeparation + randomGenerator.alea (0, 0.9999999);
				ageRepartnering := max (kMinAgeUnion, ageRepartnering);

				if (ageRepartnering >= ageDeath) or (ageRepartnering >= maxAgeCel_sex) then begin
					ageNextUnion := kNotDefined;
					result := false;
				end else begin
					ageNextUnion := ageRepartnering;
					result := true;
				end;

				objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), trunc (ageRepartnering - ageEndUnion)] :=
					objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), trunc (ageRepartnering - ageEndUnion)] + 1;
			end;
			
		end;
	end;

	function repartnering_duration (randomGenerator: TRandomNumberGenerator;
                            		sex_individual: Sex;
                                    currUnionState: UnionAgeDurationsType;
                                    var ageNextUnion: double;
                                    pN: pNuptialitySettings;
                                    objOutputFert: TOutputFertility): boolean;
	var
		ageDeath, ageSeparation, ageWhenSpouseDied, ageEndUnion: double;
		sex_spouse: Sex;
		aleaRepartnering: double;
		ageRepartnering: double;
		ind: longint;
		maxAgeCel_sex: longint;
		causeEndUnion: CausesEndUnionType = no_union;
		pRepartnering: array of array of double;
		duration, maxDuration: longint;
		
		{no_union = 0;
		end_by_death = 1;
		end_by_widowhood = 2;
		end_by_separation = 3;
		end_allTypes = 4;}
	begin
		result := false;
		ageNextUnion := kNotDefined;

		if sex_individual = woman then
		begin
			sex_spouse := man;
			maxAgeCel_sex := kMaxAgeUnion_women;
		end else begin
			sex_spouse := woman;
			maxAgeCel_sex := kMaxAgeUnion_men;
		end;
				
		{age of union termination (by separation or death of spouse)}
		ageDeath := currUnionState.ages[le_death, sex_individual];		{NOT always}
		ageSeparation := currUnionState.ages[le_endUnion, sex_individual];	{NOT always}
		ageWhenSpouseDied := currUnionState.ages[le_union, sex_individual]	{NOT always}
							+ currUnionState.ages[le_death, sex_spouse]
							- currUnionState.ages[le_union, sex_spouse];
		
		if ageDeath < 0 then
			ageDeath := kMaxAgeLife+1;
			
		ageEndUnion := ageDeath;
		if ageSeparation > 0 then
			ageEndUnion := min_real (ageEndUnion, ageSeparation);
		if ageWhenSpouseDied > 0 then
			ageEndUnion := min_real (ageEndUnion, ageWhenSpouseDied);
			
		pRepartnering := nil;
		if (ageEndUnion = ageSeparation) then begin
			causeEndUnion := end_by_separation;
			pRepartnering := pN^.prop_repartnering_duration;
		end;
		if (ageEndUnion = ageWhenSpouseDied) then begin
			causeEndUnion := end_by_widowhood;
			pRepartnering := pN^.prop_repartnering_widowhood_duration;
		end;
		if (ageEndUnion = ageDeath) then begin
			causeEndUnion := end_by_death;
			pRepartnering := nil;
			exit;
		end;
		
		ageRepartnering := ageDeath;

		ageEndUnion := max(ageEndUnion, kMinAgeUnion);
		if (ageEndUnion <  maxAgeCel_sex) and (objOutputFert <> nil) then
try // 1
			objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), kNotDefined] :=
									objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), kNotDefined] + 1;
except // 1
	on E: Exception do begin
    	writeAndWaitConst(['===> ERROR: ', E.Message]);
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(false,E.Message)
{$ENDIF}
	end;
end;

		if (ageEndUnion < ageDeath) and (ageEndUnion <= kMaxAgeUnion) then
		begin
			aleaRepartnering := randomGenerator.alea0;
			maxDuration := length (pRepartnering[0])-1;
			if aleaRepartnering <= pRepartnering [sex_individual, maxDuration] then
			begin
				ind := kMinDurationSeparation;
try // 2
				while (ind < maxDuration) and (aleaRepartnering > pRepartnering[sex_individual, ind]) do
					ind := ind + 1;
except // 2
	on E: Exception do begin
    	writeAndWaitConst(['===> ERROR: ', E.Message]);
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(false,E.Message)
{$ENDIF}
	end;
end;

				ageRepartnering := ageEndUnion + (ind + 1.0) / kNbLunarMonths;
				ageRepartnering := max (kMinAgeUnion, ageRepartnering);

				if (ageRepartnering >= ageDeath) or (ageRepartnering >= maxAgeCel_sex) then begin
					ageNextUnion := kNotDefined;
					result := false;
				end else begin
					ageNextUnion := ageRepartnering;
					result := true;
				end;
try // 3
				if (objOutputFert <> nil) then
					objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), trunc (ageRepartnering - ageEndUnion)] :=
						objOutputFert.RepartneringStates [sex_individual, trunc (ageEndUnion), trunc (ageRepartnering - ageEndUnion)] + 1;
except // 3
	on E: Exception do begin
    	writeAndWaitConst(['===> ERROR: ', E.Message]);
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(false,E.Message)
{$ENDIF}
	end;
end;

            end;
			
		end;
	end;

	function causesEndUnion (union: UnionAgeDurationsType): CausesEndUnionType;
	begin
		causesEndUnion := no_union;
		if	(union.durations.durationUnionInMonthsWithSeparation > 0) and
			(union.durations.durationUnionInMonthsWithSeparation < union.durations.durationAliveMan) then
			causesEndUnion := end_by_separation
		else if (union.durations.durationUnionInMonths = union.durations.durationAliveMan) then
			causesEndUnion := end_by_widowhood
		else if (union.durations.durationUnionInMonths = union.durations.durationAliveWoman) then
			causesEndUnion := end_by_death
        else
			causesEndUnion := no_union;
	end;

	function ageWomenEndUnion (ages: TabAgeEvents; out statutEndUnion: PartnershipStatusesType): double;
	var
		ageUnion, ageUnionPartner, ageEndUnion, ageAtDeath, ageAtDeathPartner: double;
	begin
		statutEndUnion := neverInUnion;
		ageUnion := ages[le_union, woman];
		ageUnionPartner := ages[le_union, man];
		ageEndUnion := ages[le_endUnion, woman];
		ageAtDeath := ages[le_death, woman];
		ageAtDeathPartner := ages[le_death, man] + ageUnion - ageUnionPartner;
		if (ageAtDeath = kNotDefined) or (ageAtDeath > ageAtDeathPartner) then begin
			ageWomenEndUnion := ageAtDeathPartner;
			statutEndUnion := widow;
		end else begin
			ageWomenEndUnion := ageAtDeath;
			statutEndUnion := everInUnion;
		end;
		if (ageEndUnion > 0) and (ageEndUnion < ageAtDeathPartner) then begin
			ageWomenEndUnion := ageEndUnion;
			statutEndUnion := separated;
		end;
	end;
	
	function numChildrenInUnion (pChild: pInfoChildType; nUnion: longint): longint;
	var
		n: longint;
	begin
		n := 0;
		while pChild <> nil do begin
			if pChild^.birthOrder > 0 then begin
				if nUnion = 0 then begin
					n := n + 1;
				end else if nUnion = pChild^.motherUnionNumber then begin
					n := n + 1;
				end else if nUnion < pChild^.motherUnionNumber then begin
					numChildrenInUnion := n;
					exit(numChildrenInUnion);
				end;
			end;
			pChild := pChild^.next;
		end;
		numChildrenInUnion := n;
	end;

	procedure incrementTableUnions (
					unionStates: TUnionsType;
					pChild: pInfoChildType;
					objUnionTable: TUnionTable);
	var
		nUnion: longint;
		ageUnion: longint;
		durationUnion: longint;
		cause: CausesEndUnionType;
		nbChildrenInUnion: longint;
		
		
	begin
		if unionStates.nbUnions > 0 then begin
			for nUnion := 1 to unionStates.nbUnions do begin
			
				ageUnion := trunc (unionStates.Unions [nUnion - 1].ages[le_union, woman]);
				durationUnion := trunc ( unionStates.Unions [nUnion - 1].durations.durationUnionInMonths / kNbLunarMonths );
				cause := causesEndUnion ( unionStates.Unions [nUnion - 1] );
				nbChildrenInUnion := numChildrenInUnion (pChild, nUnion);
				
				objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildrenInUnion] :=
					objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildrenInUnion] + 1;
			end;
		end;
	end;

	procedure writeUnionTable(filename: string; objUnionTable: TUnionTable);
	var
		nUnion: longint;
		ageUnion: longint;
		durationUnion: longint;
		cause: CausesEndUnionType;
		nbChildren: longint;
		f: TFileType;
		causeText: array[CausesEndUnionType] of string = ('no_union', 'end_by_death', 'end_by_widowhood', 'end_by_separation', 'total');

	begin
	
		if not openFileOut ( filename, 'WRITEUNIONTABLE', f, kAsyncFalse ) then begin
			writeAndWaitConst(['===> ERROR: Error, problem with: ' + filename]);
			exit;
		end;
		
		bWriteLn (f, ['nUnion', tab, 'ageUnion', tab, 'durationUnion', tab, 'cause', tab, 'nbChildren', tab, 'value']);
		for nUnion:=1 to kMaxNbUnion do
			for ageUnion := kMinAgeUnion to kMaxAgeUnion do
				for durationUnion := 0 to kMaxDurationUnion do
					for cause := end_by_death to end_by_separation do
						for nbChildren := 0 to kMaxNbChildren do
							if objUnionTable.pTableUnions^ [nUnion, ageUnion, durationUnion, cause, nbChildren] > 0 then
								bWriteLn (f, 
									[nUnion, tab, ageUnion, tab, durationUnion, tab, causeText[cause], tab, nbChildren, tab,
									objUnionTable.pTableUnions^ [nUnion, ageUnion, durationUnion, cause, nbChildren]]
								);

		f.Destroy;
	end;
	
	function separationFinalProp(objUnionTable: TUnionTable; fname: string = ''): double;
	var
		nUnion: longint;
		ageUnion: longint;
		durationUnion: longint;
		cause: CausesEndUnionType;
		nbChildren: longint;
		prop: double;
		sumUnions: longint;
		f: TFileType;
		
		function computeIt (nUnion, age, nbChildren: longint): double;
		var
			unionTable: array[0..kMaxDurationUnion+1] of array[CausesEndUnionType] of longint;
			durationUnion: longint;
			cause: CausesEndUnionType;
			survProp: double;
			survUnion: longint;
			rate: double;
		begin
			for durationUnion := 0 to kMaxDurationUnion+1 do
				for cause := no_union to end_allTypes do
					unionTable [durationUnion, cause] :=
						objUnionTable.pTableUnions^[nUnion, age, durationUnion, cause, nbChildren];
			
			survUnion := objUnionTable.pTableUnions^[nUnion, age, kMaxDurationUnion+1, end_allTypes, nbChildren];
			survProp := 1;
			for durationUnion := 0 to kMaxDurationUnion do begin
				if survUnion <= 0 then break;
				rate := unionTable[durationUnion, end_by_separation] /
						(survUnion -
						(unionTable[durationUnion, end_allTypes] - unionTable[durationUnion, end_by_separation]) / 2
						);
				survProp := survProp * (1 - rate);
				survUnion := survUnion - unionTable[durationUnion, end_allTypes];
			end;
			computeIt := 1 - survProp;
		end;
		
	begin
		{sum over children}
		for nUnion := 1 to kMaxNbUnion do
			for ageUnion := kMinAgeUnion to kMaxAgeUnion do
				for durationUnion := 0 to kMaxDurationUnion do
					for cause := end_by_death to end_by_separation do
						for nbChildren := 0 to kMaxNbChildren do
							objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, kMaxNbChildren+1] :=
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, kMaxNbChildren+1] +
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildren];
		{sum over cause}
		for nUnion := 1 to kMaxNbUnion do
			for ageUnion := kMinAgeUnion to kMaxAgeUnion do
				for durationUnion := 0 to kMaxDurationUnion do
					for cause := end_by_death to end_by_separation do
						for nbChildren := 0 to kMaxNbChildren+1 do
							objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, end_allTypes, nbChildren] :=
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, end_allTypes, nbChildren] +
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildren];
		{sum over duration}
		for nUnion := 1 to kMaxNbUnion do
			for ageUnion := kMinAgeUnion to kMaxAgeUnion do
				for durationUnion := 0 to kMaxDurationUnion do
					for cause := no_union to end_allTypes do
						for nbChildren := 0 to kMaxNbChildren+1 do
							objUnionTable.pTableUnions^[nUnion, ageUnion, kMaxDurationUnion+1, cause, nbChildren] :=
								objUnionTable.pTableUnions^[nUnion, ageUnion, kMaxDurationUnion+1, cause, nbChildren] +
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildren];
		{sum over age}
		for nUnion := 1 to kMaxNbUnion do
			for ageUnion := kMinAgeUnion to kMaxAgeUnion do
				for durationUnion := 0 to kMaxDurationUnion+1 do
					for cause := no_union to end_allTypes do
						for nbChildren := 0 to kMaxNbChildren+1 do
							objUnionTable.pTableUnions^[nUnion, kMaxAgeUnion+1, durationUnion, cause, nbChildren] :=
								objUnionTable.pTableUnions^[nUnion, kMaxAgeUnion+1, durationUnion, cause, nbChildren] +
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildren];
		{sum over nbUnions}
		for nUnion := 1 to kMaxNbUnion do
			for ageUnion := kMinAgeUnion to kMaxAgeUnion+1 do
				for durationUnion := 0 to kMaxDurationUnion+1 do
					for cause := no_union to end_allTypes do
						for nbChildren := 0 to kMaxNbChildren+1 do
							objUnionTable.pTableUnions^[kMaxNbUnion+1, ageUnion, durationUnion, cause, nbChildren] :=
								objUnionTable.pTableUnions^[kMaxNbUnion+1, ageUnion, durationUnion, cause, nbChildren] +
								objUnionTable.pTableUnions^[nUnion, ageUnion, durationUnion, cause, nbChildren];
								
						
		prop := computeIt (1, kMaxAgeUnion+1, kMaxNbChildren+1);
		separationFinalProp := prop;
		
		sumUnions := objUnionTable.pTableUnions^[kMaxNbUnion+1, kMaxAgeUnion+1, kMaxDurationUnion+1, end_allTypes, kMaxNbChildren+1];
		
		if (fname <> '') then
			if (openFileOut (g_FileName.value + '_' + fname, 'pTABLEUNIONS', f, kAsyncFalse)) then // Main thread only
			begin
				aWriteLn (f, [sumUnions]);
				f.Destroy;
			end;
	end;
end.
