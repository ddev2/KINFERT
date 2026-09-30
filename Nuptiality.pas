{$I Defines.pas}
unit Nuptiality;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, Fertility, RandomNumbers, Utilities, Verification, Math, SysUtils
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

	{ ----------------------------------------------------------------------------------------
	  THE SCHEDULE OF AGES AT FIRST UNION

	  Everything in this section builds one object: a table that gives, for each whole age, the
	  probability that a person who has never been in a union enters one at that age. The
	  simulation draws an age at first union from it. Three quantities describe such a table:
	  the age at which unions begin, how spread out the entries into union are, and the
	  proportion of the cohort that ever enters a union at all.

	  The family of curves is the one Coale and McNeil proposed in 1971 for first marriage, and
	  KinFert holds it in two equivalent parameterisations. Both are in this unit, both build
	  the same family of curves, and which one is used depends on what the caller has to hand.

	  1. CoaleFirstUnion (startingAge, 1 - everInUnion, scaleFactor)

	  The standard curve, stretched. The standard has its mean 11.37 years above the age at
	  which it starts, which is kCoaleStandardMean below, so a curve whose mean lies m years
	  above its starting age has a scale factor of m / 11.37. A factor of 1 reproduces the
	  standard, a factor of 0.5 halves every interval, and the mean moves in proportion:

	      factor   mean above the starting age
	         2.0        22.74 years
	         1.0        11.37
	         0.5         5.69
	         0.2         2.27
	      1/11.37        1.00

	  This is the form used for the two way table of ages at union, where for each age at which
	  a woman enters a union the schedule of her partner's age has to be built from the
	  difference between the two mean ages at union. The scale factor is the natural parameter
	  there, since that difference is what is known.

	  2. RodTrussFirstUnion (firstAge, lastAge, 1 - everInUnion, mean, standardDeviation)

	  The same family written with the mean and the standard deviation of the age at union as
	  its two parameters, which is the form Rodriguez and Trussell gave in 1980. It is the form
	  used for the schedules of women and of men themselves, where the mean age at union is a
	  parameter of the demographic regime, and for repartnering.

	  The two forms meet at the standard: RodTrussFirstUnion with a mean of 21.36 years and a
	  standard deviation of 6.583312236 builds the same curve as CoaleFirstUnion with a starting
	  age of 10 and a scale factor of 1. A scale factor of one is therefore a standard deviation
	  of 6.583312236 years, and the two are proportional, which is where kMinStdNuptSchedule
	  below comes from. Worth knowing when reading that equivalence: at the mean of the standard,
	  21.36 years, std_Coale_Rodriguez_Trussel returns 5.43 rather than 6.58, so the regression
	  that turns a mean into a standard deviation and the standard deviation of the standard
	  curve itself do not quite agree. Nothing in the program depends on their agreeing, but the
	  20 per cent between them is unexplained.

	  WHERE THE THREE QUANTITIES COME FROM, AND WHAT EACH OF THEM HAS TO SATISFY

	  The mean age at first union is a parameter of the demographic regime, one for women and
	  one for men. initStandardNuptiality holds each of them inside
	  kMinMeanAgeUnionSchedule to kMaxMeanAgeUnionSchedule as it arrives, before anything is
	  computed from it, and reports a value it has to move. A mean cannot take the whole range
	  of an individual age at union, which is what the dialog applies to it.

	  The standard deviation reaches RodTrussFirstUnion by three routes. It can be computed from
	  the mean, by one of the four functions at the end of this unit; it can be given directly,
	  as STD_DEV_AGE_UNION; or a stepped run can build it, in SpecialRuns, which takes it from
	  std_Logistic_Dani_2004 or std_Campbell_Wood_1988 according to the fixed parameter
	  stdUnionDanielOrCampbellWood and writes it into the regime without passing through the
	  range the dialog and the configuration reader apply. It has to be positive, because the
	  schedule divides by it twice, and that third route is the one that can still deliver a
	  zero: std_Campbell_Wood_1988 is exactly zero for every mean at or below 15.32 years, which
	  is inside the range of means the schedule accepts.

	  The proportion ever in union lies between zero and one, and both callers pass it in as its
	  complement, which the two routines undo on entry. Zero is a legal value, and it describes
	  a population in which nobody ever enters a union and therefore nobody has children, so it
	  is reported when it arrives.

	  The scale factor has to be positive, for the same reason: CoaleFirstUnion divides by it
	  three times. It is derived from the difference between the two mean ages at union, men
	  less women, and is zero when men enter unions on average five years younger than women.
	  The derivation is written out where that difference is computed, in
	  initStandardNuptiality.

	  THE THREE GUARDS, AND WHY THEY SIT WHERE THEY DO

	  Each one sits at the arithmetic it protects rather than at the places the value comes
	  from, so that a single test covers every route to it. They report through the verification
	  unit and substitute a usable value rather than stopping the run, because in each case the
	  cause is something the user asked for and not corrupt internal state:

	      meanAgeUnionRange    in initStandardNuptiality, on each mean as it arrives
	      scaleFactorTooLow    in CoaleFirstUnion, on the scale factor
	      stdNuptTooLow        in RodTrussFirstUnion, on the standard deviation

	  A fourth, everInUnionZero, is a notice rather than a guard: it reports a proportion ever
	  in union of zero, which is legal, and the arithmetic that would divide by it is skipped.

	  THE FOUR FUNCTIONS THAT TURN A MEAN INTO A STANDARD DEVIATION

	  Each has a domain of its own, so no single limit on the mean age at union covers them all.
	  The zeros are what matter, since the schedule divides by what they return:

	      std_Coale_Rodriguez_Trussel   zero at a mean of kZeroStd_Coale_Rodriguez_Trussel, and
	                                    mirrored below it by its absolute value, so a mean of 12
	                                    returns the standard deviation of a mean of 15.28. This
	                                    is the function in force for the schedules of women and
	                                    of men.
	      std_Campbell_Wood_1988        zero at and below kZeroStd_Campbell_Wood_1988, about
	                                    15.32 years, and bounded inside itself below that, so it
	                                    returns zero rather than the square root of a negative
	                                    number. Reached from a stepped run.
	      std_Logistic_Dani_2004        no zero in the mean, since its denominator is always
	                                    above one, but zero when its final level is zero.
	                                    Reached from a stepped run.
	      std_unionLinear               whatever the two standard deviations the user gives
	                                    interpolate to, zero included. No caller today.
	  ---------------------------------------------------------------------------------------- }
	const
		{the mean of the standard curve, in years above the age at which it starts}
		kCoaleStandardMean = 11.37;
		{the scale factor CoaleFirstUnion uses in place of one that is zero or negative: the
		 factor of a curve whose mean lies exactly one year above its starting age}
		kMinNuptScaleFactor = 1 / kCoaleStandardMean;
		{the mean at which std_Coale_Rodriguez_Trussel returns zero}
		kZeroStd_Coale_Rodriguez_Trussel = 13.64;
		{the range each mean age at first union is held inside. The lower end is one year above
		 the zero of the standard deviation function in force, which gives a standard deviation
		 of 1.95 years. The upper end is a modelling judgement: 40 years is well above any mean
		 age at first union that has been observed, and it keeps the two fixed age paths inside
		 the arrays they index with trunc (mean).}
		kMinMeanAgeUnionSchedule = kZeroStd_Coale_Rodriguez_Trussel + 1.0;
		kMaxMeanAgeUnionSchedule = 40.0;
		{the difference between the two mean ages at union, men less women, at and below which
		 the schedule of ages at union of men cannot be built. The 5 is the five years by which
		 that schedule is allowed to start below the woman's own age at union.}
		kMinMeanDiffSexUnion = -5.0;
		{the standard deviation of the standard curve, which a scale factor of one corresponds
		 to, and the floor RodTrussFirstUnion uses in place of one that is zero or negative. The
		 floor is that standard deviation taken at kMinNuptScaleFactor, about 0.58 years, which
		 is the same curve the scale factor falls back on.}
		kStdNuptOfScaleFactorOne = 6.583312236;
		kMinStdNuptSchedule = kStdNuptOfScaleFactorOne * kMinNuptScaleFactor;
		{the mean at and below which std_Campbell_Wood_1988 returns zero, which is exp (292/107)
		 written out because a constant expression cannot call exp}
		kZeroStd_Campbell_Wood_1988 = 15.3171;

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

	function unionRecordForSetter (pRelative: pRelativeType; indUnion: longint; whichSetter: string): pUnionInfoType;
	{getUnionInfoByIndex returns nil both for an index that is simply the next one, which is how
	 a person's first and later unions have always been created, and for an index that means
	 nothing at all. The six setters used to treat the two alike and append in either case, so a
	 caller passing kNotDefined added a phantom union and put its value there. The caller that
	 did so is checkEndUnions in Kinship, which takes its index from getIndUnion, and getIndUnion
	 returns kNotDefined exactly when the reciprocal link between two partners is missing: the
	 case the consistency check exists to find. A broken link therefore became an extra union,
	 and the count of unions of that person was wrong from that point on.

	 The cases are now separated. An index one past the last record is an append, which is how
	 the callers that build a person's unions have always worked; an index that names a record
	 the list holds but the nUnions field denies is written into, with the disagreement between
	 the field and the list reported; anything else, kNotDefined included, is reported and
	 refused, and the setter writes nothing. Appending is allowed at the end only, so that the
	 list can hold no gap and the union at index 3 is always the third union.}
	var
		nRecords, ind: longint;
	begin
		result := getUnionInfoByIndex (pRelative, indUnion);
		if (result <> nil) then exit;

		nRecords := getNumUnionInfo (pRelative);
		if (indUnion >= 1) and (indUnion <= kMaxNbUnion) and (indUnion = nRecords + 1) then begin
			{the next union of this person, which is the way every union is created}
			result := newUnionInfo (pRelative);
			exit;
		end;

		if (indUnion >= 1) and (indUnion <= nRecords) then begin
			{The record is there but nUnions says it is not, so getUnionInfoByIndex refused it.
			 The field and the list disagree, which is worth reporting, but the record the
			 caller named exists and writing into it is better than creating another one.}
			if reportFailure (chk_nup_unionIndexInSetter,
					[whichSetter, ': union ', indUnion, ' of relative ', pRelative^.indNumber,
					 ' exists as a record but nUnions is ', pRelative^.nUnions,
					 '. Written into the existing record']) then
				breakOnFailure;
			result := pRelative^.UList;
			for ind := 2 to indUnion do
				result := result^.next;
			exit;
		end;

		{Nothing this index can mean: kNotDefined, zero, negative, or past the end of the list
		 by more than one. Report and write nothing.}
		if reportFailure (chk_nup_unionIndexInSetter,
				[whichSetter, ': union ', indUnion, ' of relative ', pRelative^.indNumber,
				 ', who has ', nRecords, ' union records and nUnions = ', pRelative^.nUnions,
				 '. Nothing written']) then
			breakOnFailure;
		result := nil;
	end;

	procedure setAgeUnion (pRelative: pRelativeType; indUnion: longint; age: double);
	var
		UInfo: pUnionInfoType = nil;
	begin
{$IFDEF addOldUnionType}
		pRelative^.ageUnion [indUnion] := age;
{$ENDIF}
		UInfo := unionRecordForSetter (pRelative, indUnion, 'setAgeUnion');
		if (UInfo = nil) then exit;
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
		UInfo := unionRecordForSetter (pRelative, indUnion, 'setYearUnion');
		if (UInfo = nil) then exit;
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
		UInfo := unionRecordForSetter (pRelative, indUnion, 'setAgeEndUnion');
		if (UInfo = nil) then exit;
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
		UInfo := unionRecordForSetter (pRelative, indUnion, 'setYearEndUnion');
		if (UInfo = nil) then exit;
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
		if checkFalse (chk_nup_unionIndexOfPartner,
				(indUnion < 0) or (indUnion > kMaxNbUnion) or (pRelative^.nUnions = 0),
				['union ', indUnion, ', relative ', pRelative^.indNumber, ', unions ', pRelative^.nUnions]) then begin
			breakOnFailure;
			exit;
		end;
		UInfo := getUnionInfoByIndex (pRelative, indUnion);
		{the union exists, since its index has just been tested, so its record must be there}
		if checkFalse (chk_nup_unionRecordOfPartner, UInfo = nil,
				['union ', indUnion, ', relative ', pRelative^.indNumber]) then
			breakOnFailure;
		if (UInfo = nil) then
			result := nil
		else
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
		UInfo := unionRecordForSetter (pRelative, indUnion, 'setPartner');
		if (UInfo = nil) then exit;
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
		UInfo := unionRecordForSetter (pRelative, indUnion, 'setCauseEndUnion');
		if (UInfo = nil) then exit;
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
		{Holds one mean age at first union inside the range a schedule can be built from,
		 kMinMeanAgeUnionSchedule to kMaxMeanAgeUnionSchedule, and reports a value it has to move.
		 Called at each of the four places below where a mean is set, before anything is computed
		 from it. The dialog applies the range of an individual age at union to these two
		 parameters, 10 to 59 for women and 10 to 69 for men, which is deliberate and is not what
		 a mean can take.}
		procedure boundMeanAgeUnion (sexPerson: Sex; const sexLabel: string);
		var
			meanHeld: double;
		begin
			meanHeld := n.unionParam [sexPerson, meanUnion];
			if (meanHeld < kMinMeanAgeUnionSchedule) or (meanHeld > kMaxMeanAgeUnionSchedule) then begin
				reportFailure (chk_nup_meanAgeUnionRange,
						['mean age at first union of ', sexLabel, ' ', meanHeld,
						 ', range accepted ', kMinMeanAgeUnionSchedule,
						 ' to ', kMaxMeanAgeUnionSchedule]);
				if (meanHeld < kMinMeanAgeUnionSchedule) then
					n.unionParam [sexPerson, meanUnion] := kMinMeanAgeUnionSchedule
				else
					n.unionParam [sexPerson, meanUnion] := kMaxMeanAgeUnionSchedule;
			end;
		end;
	begin
		// First union for women
		if g_GENPARAM.FIXED_FERTILITY.value then begin
			n.unionParam [woman, freqFinUnion] := 1;
			n.unionParam [woman, meanUnion] := g_FIXED_FERTILITY_DATA.ageUnionWoman;
			boundMeanAgeUnion (woman, 'women');
			n.unionParam [woman, stdUnion] := 0;
		end else begin
			n.unionParam [woman, freqFinUnion] := p^.dp[propFinalCelibacyLow].value;
			n.unionParam [woman, meanUnion] := p^.dp[meanAgeUnionWomenLow].value;
			boundMeanAgeUnion (woman, 'women');	{before the standard deviation is taken from it}
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
			boundMeanAgeUnion (man, 'men');
			n.unionParam [man, stdUnion] := 0;
		end else begin
			n.unionParam [man, freqFinUnion] := p^.dp[propFinalCelibacyMen].value;
			n.unionParam [man, meanUnion] := p^.dp[meanAgeUnionMen].value;
			boundMeanAgeUnion (man, 'men');	{before the standard deviation is taken from it}
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
		{The difference between the two mean ages at union, men less women. It is not a parameter
		 of its own, but it is what decides the two way table of ages at union built in the loop
		 below, and it is worth seeing why.

		 For each age at which a woman enters a union, the schedule of her partner's age is built
		 with a scale factor of (mean - ageMin) / kCoaleStandardMean. For every age at union of
		 women above 19, mean is ageWomen + meanDiffSex and ageMin is ageWomen - 5, so the two
		 ages cancel: the factor is (meanDiffSex + 5) / kCoaleStandardMean and depends on the
		 difference alone. At a difference of -4 years it is 0.088, a schedule so compressed that
		 13 per cent of its mass falls between the whole years. At -5 it is exactly zero, and
		 below that negative, which is why kMinMeanDiffSexUnion is -5.

		 Zero and below are caught by the guard in CoaleFirstUnion, which puts
		 kMinNuptScaleFactor in place of the factor so that the run continues. What that builds
		 is a table in which every man enters his first union at the youngest age the model
		 allows. That is a configuration worth reporting rather than an arithmetic fault to
		 repair twice, so the difference is left as the two parameters make it and the schedule
		 is built from it.}
		if (meanDiffSex <= kMinMeanDiffSexUnion) then
			reportFailure (chk_nup_meanAgeUnionDiff,
					['mean age at first union of men ', n.unionParam [man, meanUnion],
					 ', of women ', n.unionParam [woman, meanUnion],
					 ', difference ', meanDiffSex,
					 ', lowest difference the schedule of men can be built from ',
					 kMinMeanDiffSexUnion]);

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
			{nothing keeps mean above ageMin, so this factor can be zero or
			 negative. The guard is in CoaleFirstUnion, which is where the division happens and
			 which every route to it passes through.}
			scaleFactor := (mean - ageMin) / kCoaleStandardMean;
			calcNuptScaleFactor (ageMin, scaleFactor, n.union_women_men[ageWomen, normal]);
			mean_calc := calcSmamFromAgeProb (kMaxAgeUnion_women, n.union_women_men[ageWomen, normal]);
			if (abs (mean - mean_calc) > 0.01) then begin
					scaleFactor := ((mean + (mean - mean_calc) * (1+ ageWomen / (2 * kMaxAgeUnion_women))) - ageMin) / kCoaleStandardMean;
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
			scaleFactor := (mean - ageMin) / kCoaleStandardMean;
			calcNuptScaleFactor (ageMin, scaleFactor, n.union_men_women[ageMen, normal]);
			mean_calc := calcSmamFromAgeProb (kMaxAgeUnion_men, n.union_men_women[ageMen, normal]);
			if (abs (mean - mean_calc) > 0.01) then begin
			  scaleFactor := ((mean + (mean - mean_calc) * (1+ ageMen / (kMaxAgeUnion_men))) - ageMin) / kCoaleStandardMean;
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
		{The loop below divides by scaleFactor three times, so the factor has to be positive. The
		 overview at the top of this unit says where it comes from and why it can fail to be.

		 Why the test is worth having, rather than trusting the callers. At a factor of zero the
		 division raised EZeroDivide, which at least announced itself. Below zero the failure is
		 quiet and worse: every density comes out negative, since the factor divides freqFin and
		 the exponential is always positive, and adjustTabNupt then divides the total wanted by
		 that negative sum and multiplies every cell by the result. Two negatives give a table
		 that is entirely non negative and sums to exactly the total asked for, so it passes every
		 test that could be made of it. Only its shape is nonsense: all of the mass sits on the
		 first age. At a factor of -1/kCoaleStandardMean the table comes out as 1.0 at
		 kMinAgeUnion and zero everywhere else, which says that every woman enters a union at the
		 youngest age the model allows. Nothing downstream can tell that from a real schedule.

		 The test is on zero and below and on nothing else. A small positive factor builds a
		 schedule that is heavily compressed but perfectly computable, and it is what two mean
		 ages at union close together ask for, so refusing it is not this routine's business. It
		 is worth knowing that such a schedule is distorted by being read at whole years: at a
		 factor of 1/kCoaleStandardMean, a mean one year above the start, the densities at the
		 integer ages sum to 0.87 rather than 1, and at half that to 0.29, the rest of the mass
		 falling between the years. adjustTabNupt rescales what is left, so what results is a
		 near spike at the first age rather than the Coale curve that was asked for. That is what
		 holding the two mean ages inside kMinMeanAgeUnionSchedule and kMaxMeanAgeUnionSchedule
		 is for, and it is a separate matter from this test: this one keeps the division safe on
		 every route to it, the other keeps the parameters inside the range a schedule can be
		 built from.

		 scaleFactor is a value parameter, so the substitution is local to this call.}
		if (scaleFactor <= 0.0) then begin
			reportFailure (chk_nup_scaleFactorTooLow,
					['factor ', scaleFactor, ', schedule starting at age ', kMinAgeUnion,
					 ', factor used instead ', kMinNuptScaleFactor]);
			scaleFactor := kMinNuptScaleFactor;
		end;
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
		{The loop below divides by std twice, so the standard deviation has to be positive. The
		 overview at the top of this unit lists the three routes by which it arrives and says
		 which of them can still deliver a zero, which is a stepped run using Campbell and Wood
		 at a mean at or below 15.32 years. A zero divisor raises EInvalidOp under the range
		 checks of Defines.pas, and without them it builds a schedule with no meaning.

		 The guard sits here, at the division, rather than at the places the value comes from,
		 because this is the one routine every route passes through: initStandardNuptiality by
		 way of calcCelibacy_RT_woman and calcCelibacy_RT_man, calcRepartnering, and
		 calcNuptScaleFactorRT.

		 A small positive standard deviation is left as asked for. It builds a schedule
		 concentrated on a few ages, which adjustTabNupt then rescales, and the note above
		 CoaleFirstUnion warns that such a value should be treated as a minimum. std is a value
		 parameter, so the substitution is local to this call.}
		if (std <= 0.0) then begin
			reportFailure (chk_nup_stdNuptTooLow,
					['standard deviation ', std, ', mean age asked for ', mean,
					 ', value used instead ', kMinStdNuptSchedule]);
			std := kMinStdNuptSchedule;
		end;
		freqFin := 1 - freqFin;
		{freqFin now holds the proportion ever in union, restored from the complement the caller
		 passed. At zero every density built below is zero, and the recomputation of the mean
		 that follows the loop would then evaluate 0.0/0.0. A population in which nobody ever
		 enters a union has no births either, so the case is reported, the division is skipped,
		 and the two callers that rescale the table afterwards skip theirs for the same reason.
		 Zero is a legal value of the parameter and this is a notice rather than a correction.}
		if (freqFin <= 0.0) then
			reportFailure (chk_nup_everInUnionZero,
					['proportion ever in union ', freqFin, ', mean age asked for ', mean]);
		meanCalc := 0;
		for age := minAgeUnion_calc to maxAgeUnion_calc do
		begin
			temp := 0.805 + (age - mean) / std;
			firstUnion[age] := (freqFin * 1.2813 / std) * exp( -1.145 * temp - exp (-1.896 * temp) );
			meanCalc := meanCalc + firstUnion[age] * (age);
		end;
		{the mean age at union of the schedule just built, read back from its own densities.
		 Nothing uses it: it is here to be compared in the debugger with the mean that was asked
		 for.}
		if (freqFin > 0.0) then
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
		{Both variables that decide the outcome are given a value here, before anything can
		 go wrong, and that value is the one that means the union does not end: a risk of zero
		 against a draw of one. Before, they were assigned inside the try below, and if anything
		 raised an exception before or during those two assignments the handler reported it and
		 then let execution continue past the end of the try, where the two are compared. They
		 held whatever was on the stack, so the union ended, or did not, at random.

		 The duration is also bounded to the table it indexes. monthly_risk_separation runs from
		 0 to kMaxDurationUnionInMonths, that is 1452 lunar months, which is a union lasting from
		 kMinAgeUnion to kMaxAgeLife, so a duration outside it means the month the union started
		 or the current month is wrong rather than that the union is very long. The value used is
		 the nearest the table holds, and the case is reported.}
		endBySeparation := false;
		aleaSeparation := 1.0;
		separationRisk := 0.0;
		if (durationUnion < 0) or (durationUnion > kMaxDurationUnionInMonths) then begin
			reportFailure (chk_nup_separationIndex,
					['duration of the union in months ', durationUnion,
					 ', month it started ', monthStart, ', current month ', currMonth]);
			if (durationUnion < 0) then
				durationUnion := 0
			else
				durationUnion := kMaxDurationUnionInMonths;
		end;
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
			if nbChildren_Alive >= 2 then
				nbChildren := twoChildrenMore;
			{the second index. The age of the youngest child is the duration of the union
			 less the duration at which that child was born, so it is negative for a child
			 conceived before the union, which is why the table starts at -11 months. A value
			 outside the table means the child is dated outside the union it is recorded in. The
			 nearest cell is used and the case reported.}
			if (ageOfYoungerInMonths < low (d.relRisk_separation_children_duration [nbChildren]))
				or (ageOfYoungerInMonths > high (d.relRisk_separation_children_duration [nbChildren])) then begin
				reportFailure (chk_nup_separationIndex,
						['age of the youngest child in months ', ageOfYoungerInMonths,
						 ', duration of the union ', durationUnion]);
				if (ageOfYoungerInMonths < low (d.relRisk_separation_children_duration [nbChildren])) then
					ageOfYoungerInMonths := low (d.relRisk_separation_children_duration [nbChildren])
				else
					ageOfYoungerInMonths := high (d.relRisk_separation_children_duration [nbChildren]);
			end;
			separationRisk := separationRisk * d.relRisk_separation_children_duration [nbChildren, ageOfYoungerInMonths];
		end;
except // 1
	on E: Exception do begin
    	writeAndWaitConst(['===> ERROR: ', E.Message]);
		breakOnFailure;
		{leave the function rather than falling through to the comparison below, which is what
		 let an exception decide the fate of a union. The union does not end.}
		endBySeparation := false;
		exit;
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
		{adjust is the sum of the densities RodTrussFirstUnion has just built. It is zero only
		 when the proportion ever in union is zero, which that routine has already reported. The
		 table is then all zeros and is already what it should be, so there is nothing to
		 rescale.}
		if (adjust > 0.0) then
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
		{as for the women above, a sum of zero means the proportion ever in union is zero, the
		 table is all zeros already, and there is nothing to rescale.}
		if (adjust > 0.0) then
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
	{adaptation equation Campbell & Wood [1988]}
	{Zero at and below kZeroStd_Campbell_Wood_1988, about 15.32 years, and bounded inside itself
	 below that, so it returns zero rather than the square root of a negative number. SpecialRuns
	 calls it for a stepped run over the mean age at union, and the means the schedule accepts
	 start at 14.64, so a step between 14.64 and 15.32 returns a zero. The floor that keeps it
	 out of the division is kMinStdNuptSchedule, applied in RodTrussFirstUnion.}
	var
		std : double;
	begin
		std := 107.0 * ln (mean) - 292.0;
		// don't let std become negative...
		if (std < 0.0) then std := 0.0;
		std_Campbell_Wood_1988 := sqrt (std);
	end;
	
	function std_Logistic_Dani_2004 (mean, final_level: double): double;
	{kCentringMeanLogistic is the mean at which the logistic
	 is centred and not a limit on anything, and Declarations now carries a kMinMeanAgeUnion that
	 is the lowest mean age at union the dialog and a configuration file accept. Two different
	 quantities under one name, the inner one hiding the outer, is worth avoiding even where the
	 compiler is content.}
	const
		kCentringMeanLogistic = 15.0;
	var
		std : double;

	begin
		{No zero in the mean, since the denominator is always above one, but zero when
		 final_level is zero. SpecialRuns calls it with a final level of 6.708204, so the zero
		 cannot arise from there.}
		std := final_level * final_level;
		std := std / ( 1.0 + 500.0 * exp (-2.5 - ( mean - kCentringMeanLogistic ) / 2.0));
		std_Logistic_Dani_2004 := sqrt (std);
	end;

	function std_Coale_Rodriguez_Trussel (mean: double): double;
	{returns exactly zero at a mean of 13.64}
	{Zero at a mean of kZeroStd_Coale_Rodriguez_Trussel, and mirrored below it by the absolute
	 value, so a mean of 12 returns the standard deviation of a mean of 15.28. The range the two
	 mean ages at union are held inside starts one year above that zero, and kMinStdNuptSchedule
	 catches whatever else reaches the division. This is the function in force for the schedules
	 of women and of men.}
	begin
		std_Coale_Rodriguez_Trussel := sqrt (43.34 * abs ( mean - kZeroStd_Coale_Rodriguez_Trussel ) / 11.36);
	end;
	
	function std_unionLinear (meanAgeUnionWomenLow, meanAgeUnionWomenHigh, stddevBasUnion, stddevHautUnion, mean: double): double;
	{Returns whatever the two standard deviations the user gives interpolate to, zero included,
	 and returns stddevBasUnion unchanged when the two mean ages are equal. It is the one of the
	 four with no caller today.}
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
		breakOnFailure;
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
		breakOnFailure;
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
		breakOnFailure;
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
	{A union ends at the earliest of three events: the woman's own death, the death of her
	 partner expressed on her age scale, and a separation. Any of the three can be kNotDefined,
	 which is a sentinel and not an age, so each one is tested before it is used and the earliest
	 of those that are defined wins. The status follows from which one won.

	 What this changes beyond the guard already in place. The separation used to be compared with
	 the partner's death alone, so a partner with no date of death, which is how a union is left
	 by truncateAtAge and by calcStateWoman before the reconstruction, made every separation
	 invisible: the union was reported as running to her death, with the status everInUnion
	 rather than separated, which puts her exposure and her children in the wrong column of the
	 tables by partnership status. The other residue was a union with neither death defined,
	 which returned the sentinel with the status widow.

	 A union with no end at all is still possible, since all three can be undefined, and it is
	 reported rather than given a status it does not have. kNotDefined is returned in that case,
	 as before, because the callers test for it.}
	var
		ageUnion, ageUnionPartner, ageEndUnion, ageAtDeath, ageAtDeathPartner: double;
	begin
		ageUnion := ages[le_union, woman];
		ageUnionPartner := ages[le_union, man];
		ageEndUnion := ages[le_endUnion, woman];
		ageAtDeath := ages[le_death, woman];
		{the partner's age at death, moved onto the woman's age scale by the difference between
		 their two ages at union. Both of his ages are needed for that, and truncateAtAge clears
		 them together.}
		if (ages[le_death, man] = kNotDefined) or (ageUnionPartner = kNotDefined) then
			ageAtDeathPartner := kNotDefined
		else
			ageAtDeathPartner := ages[le_death, man] + ageUnion - ageUnionPartner;

		result := kNotDefined;
		statutEndUnion := everInUnion;

		{her own death}
		if (ageAtDeath <> kNotDefined) then begin
			result := ageAtDeath;
			statutEndUnion := everInUnion;
		end;
		{his death, if it comes first}
		if (ageAtDeathPartner <> kNotDefined) and
				((result = kNotDefined) or (ageAtDeathPartner < result)) then begin
			result := ageAtDeathPartner;
			statutEndUnion := widow;
		end;
		{the separation, if it comes first. The test on zero is the one that was there: an age at
		 end of union of zero or less means no separation was recorded.}
		if (ageEndUnion > 0) and
				((result = kNotDefined) or (ageEndUnion < result)) then begin
			result := ageEndUnion;
			statutEndUnion := separated;
		end;

		if (result = kNotDefined) then
			if reportFailure (chk_nup_unionHasNoEnd,
					['union at age ', ageUnion, ' of a woman with no age at death, whose partner ',
					 'has no age at death either, and with no separation recorded']) then
				breakOnFailure;
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
