{$I Defines.pas}
unit Fertility;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, RandomNumbers, Utilities, Math, SysUtils, Memory
    {$IFDEF VerboseProfiler}, Profiler{$ENDIF}
    ;

	procedure CreateArrayChildren(var arrayChildren: arrayOfInfoChild);
	procedure DestroyArrayChildren(var arrayChildren: arrayOfInfoChild);

	procedure newChild (var pChild: pInfoChildType; const arrayChildren: arrayOfInfoChild = pInfoChildType(nil));
	function duplicateChildrenList (pChild: pInfoChildType): pInfoChildType;
	function duplicateChildrenList_AC (pChild: pInfoChildType; var arrayChildren: arrayOfInfoChild): pInfoChildType;
    procedure disposeChild ( var pChild: pInfoChildType );
	function childInfoSizeOf (pChild: pInfoChildType): longint;
	procedure initFertilityModel;

	procedure initialSetFixedParameters;
	procedure initFixedParameters();
	procedure info_FixParameter ();
	procedure fixParameter (kind: fixedParameterKind; value: double);

	procedure normalHeterogeneityFecundability (mean, stdDev: double);

	procedure init_temporary_sterility (p: pStructDemographicRegimeSettings; alpha, beta: double);
	function init_waiting_time_distribution (
			maxDuration: longint;
			var arrayDurationAcc: array of double;
			mean, propContraception: double;
			lambda_erlang: double = 1): double; // return median value
	procedure noStoppingContraception (p: pStructDemographicRegimeSettings);
	procedure adjustContraception (p: pStructDemographicRegimeSettings);

	procedure initFecundLife (randomGenerator: TRandomNumberGenerator; var fecundLife: FecundLifeType);
	function fecundabilityLevel (randomGenerator: TRandomNumberGenerator):double;
	procedure addDurationSinceLastEvent (	var durationSinceLastEvent: DurationSincePreviousEventType;
											pChild: pInfoChildType; unionStates: TUnionsType );
	procedure addIntervals (unionStates: TUnionsType; pChild: pInfoChildType; var intervals: IntervalType);
	procedure calcIntervals (var intervals: IntervalType);
	procedure calcDurationSinceLastEvent (	var durationSinceLastEvent: DurationSincePreviousEventType );
	procedure calcAgeLastChild (var lastChildren: LastChildrenType);
	procedure addAgeLastChild (nbChildren: longint; var lastChildren: LastChildrenType; pChild: pInfoChildType);
	procedure goBackToFirstChild (var pChild: pInfoChildType );
	procedure gotoToFirstLiveBornChild (var pChild: pInfoChildType);
	procedure gotoToNextLiveBornChild (var pChild: pInfoChildType );
	function numChildrenBornAlive (pChild: pInfoChildType): longint;
	procedure finalPartnershipStatus (var unionStates: TUnionsType);
	procedure processParity (nbChildren: longint; pChild: pInfoChildType; var finalParity: FinalParityType);

	function ageToLunarMonths (age: double): longint;
	function lunarMonthsToAge (duration: longint): double;
	function lunarToCalendarMonth (randomGenerator: TRandomNumberGenerator; lunarMonth: shortint): shortint;

	function effectivenessContraceptionSpacing(p: pStructDemographicRegimeSettings; nbBirths: longint): double;
	function effectivenessContraceptionStopping(p: pStructDemographicRegimeSettings; nbBirths: longint): double;
	procedure timeToConception ( unionStates: TUnionsType; pChild: pInfoChildType; objOutputFert: TOutputFertility );

	function multipleBirths ( age: FecundAges ): longint;

	procedure writeDebugHeader;
	procedure writeDebugInfo ( unionStates: TUnionsType; pChild: pInfoChildType );

	procedure calcFertility_NC (const distNC: array of longint; out TFR, VARIANCE: double);

implementation
	
	function ageToLunarMonths (age: double): longint;
	begin
		if age > 0 then
			ageToLunarMonths := 1 + trunc ( age * ( 1.0 * kNbLunarMonths) )
		else
			ageToLunarMonths := -1 + trunc ( age * ( 1.0 * kNbLunarMonths) )
	end;
	
	function lunarMonthsToAge (duration: longint): double;
	begin
		lunarMonthsToAge := (1.0 * duration) / (1.0 * kNbLunarMonths);
	end;

	function lunarToCalendarMonth (randomGenerator: TRandomNumberGenerator; lunarMonth: shortint): shortint;
	var
		day: shortint;
	begin
		if kNbLunarMonths = 13 then {%H-}begin
			day := trunc (randomGenerator.alea (1, 28.99999999999));
			result := 1 + trunc (((lunarMonth - 1) * 28.07692308 + day) / 30.5);
		end else
			result := lunarMonth;
	end;
	
	procedure initStandardAmenorrhea (p: pStructDemographicRegimeSettings);
	begin
		{Weak: median month between 5 and 6 months}
		p^.dp[amenorrhea_alpha].value := -1.2;
		p^.dp[amenorrhea_beta].value := 1.0;
	end;
	
	procedure init_temporary_sterility (p: pStructDemographicRegimeSettings; alpha, beta: double);
	{Lesthaeghe-Page}
	var
		ind: longint;
		paramVal: longint;
		temp: double;
		
	begin
		if g_GENPARAM.fixedParameters [fixedAmenorrhea].state.value then begin
			// sanity check
			paramVal := max (0, trunc (g_GENPARAM.fixedParameters [fixedAmenorrhea].param.value));
			paramVal := min (kMaxMonthTemporarySterility - 1, paramVal);
			if paramVal > 0 then begin
				for ind := 0 to paramVal - 1 do
					p^.temporary_sterility [ind] := 1;
			end;
			for ind := paramVal to kMaxMonthTemporarySterility do
				p^.temporary_sterility [ind] := 0;
			
			exit;
			
		end else begin
			if (beta = 0) and (alpha = 0) then
			begin
				initStandardAmenorrhea (p);
				alpha := p^.dp[amenorrhea_alpha].value;
				beta := p^.dp[amenorrhea_beta].value;
			end else begin
				p^.dp[amenorrhea_alpha].value := alpha;
				p^.dp[amenorrhea_beta].value := beta;
			end;
		
			if (alpha <> 0) or (beta <> 0) then
			begin
				for ind := 2 to kMaxMonthTemporarySterility do
				// we start from ind = 2 because the first two values of gSchedule_temporary_sterility are equals to 1
				begin
					temp := alpha + beta * 0.5 * ln ( gSchedule_temporary_sterility [ind] / (1 - gSchedule_temporary_sterility [ind]) );
					p^.temporary_sterility [ind] := exp ( 2.0 * temp ) / (1 + exp ( 2.0 * temp ));
				end;
			end;
		
			p^.temporary_sterility [0] := 1.0;
			p^.temporary_sterility [1] := 1.0;
			p^.temporary_sterility [kMaxMonthTemporarySterility] := 0.0;
		end;
	end;
	
	procedure init_waiting_time_distribution_Poisson (maxDuration: longint; var arrayDurationAcc: array of double; mean, propContraception: double);
	var
		i: longint;
		last, temp: double;
		fact: double;
		mean_check: double;
	begin
		if (mean = 0.0) or (propContraception = 0) then
		begin
			for i:= 0 to maxDuration do
				arrayDurationAcc [i] := 1.0;
		end else
		begin
			for i:= 0 to maxDuration do
				arrayDurationAcc [i] := 0.0;
				
			{On calcule au premier jour de chaque année}
			last := 0.0;
			fact := 1.0;
			mean_check := 0.0;
			mean := mean * kNbLunarMonths;
			for i := 0 to maxDuration do
			begin
				if i > 0 then
					fact := fact * i;
				temp := exp ( -mean ) * power (mean, i ) / fact;
				mean_check := mean_check + i * temp;
				arrayDurationAcc [i] := temp + last;
				last := arrayDurationAcc [i];
			end;
			mean_check := ( mean_check / arrayDurationAcc [maxDuration] ) / kNbLunarMonths;
			arrayDurationAcc [maxDuration] := 1.0;			
		end;
	end;
	
	function gamma (z: double): double;
	{Gergő Nemes's approximation}
	var
		res: double;
	begin
		res := 0.5 * ( ln (2* pi) - ln (z) ) + z * ( ln ( z + 1 / ( 12 * z - 1 / (10 * z) ) ) - 1);
		result := exp (res);
	end;
	
	procedure init_waiting_time_distribution_Erlang (maxDuration: longint; var arrayDurationAcc: array of double; mean, propContraception: double; lambda: double = 1);
	var
		k: double;
		i: longint;
		last, temp: double;
		fact: double;
		mean_check: double;
	begin
		if (mean = 0.0) or (propContraception = 0) then
		begin
			for i := 0 to maxDuration do
				arrayDurationAcc [i] := 1.0;
		end else
		begin
			for i := 0 to maxDuration do
				arrayDurationAcc [i] := 0.0;

			k := mean * kNbLunarMonths;
			last := 0.0;
			fact := gamma (k);
			mean_check := 0.0;

			for i := 0 to maxDuration do
			begin
				temp := power (lambda, k) * power (i, k - 1) * exp ( - lambda * i ) / fact;
				mean_check := mean_check + i * temp;
				arrayDurationAcc [i] := temp + last;
				last := arrayDurationAcc [i];
			end;
			mean_check := ( mean_check ) / kNbLunarMonths;
			arrayDurationAcc [maxDuration] := 1.0;			
		end;
	end;
	

	function init_waiting_time_distribution (
			maxDuration: longint;
			var arrayDurationAcc: array of double;
			mean, propContraception: double;
			lambda_erlang: double = 1): double; // return median value
	var
		ind: longint;
		median: double;
	begin
		if ( g_GENPARAM.fixedParameters [waitingTimeErlangPoisson].state.value = true ) then
			init_waiting_time_distribution_Erlang (maxDuration, arrayDurationAcc, mean, propContraception, lambda_erlang)
		else
			init_waiting_time_distribution_Poisson (maxDuration, arrayDurationAcc, mean, propContraception);
	end;
	
	procedure noStoppingContraception (p: pStructDemographicRegimeSettings);
		var
			ind: longint;
	begin
		for ind := 0 to kMaxNbChildren do
			p^.curr_contracepStopping[ind] := 1.0;
	end;
	
	procedure adjustContraception (p: pStructDemographicRegimeSettings);
		var
			ind: longint;
			fact: double;
			step, numStep: longint;
			
	begin
		{Si numStep = 5, on a les niveaux suivants de DF à priori:}
		{step = 1, DF = kMaxNbChildren}
		{step = 2, DF = 4,12}
		{step = 3, DF = 2,89}
		{step = 4, DF = 2,89}
		{step = 5, DF = 2,08}
		
		step := RP.indFertControl;
		numStep := g_GENPARAM.RUNTIME[nStepsContrFert].value;
		
		if numStep = 1 then
			fact := 1
		else
			fact := (step - 1.0) / (numStep - 1.0);
		
		for ind := 0 to kMaxNbChildren do
			p^.curr_contracepStopping[ind] := 1.0 - (1.0 - p^.aPrioriPPR_adjusted.value[ind]) * fact;
		
	end;

	procedure initFecundability ();
		var
			i: longint;
	begin
		{Léridon 2004}
		gFecundability[10] := 0.0;
		gFecundability[11] := 0.001;
		gFecundability[12] := 0.002;
		gFecundability[13] := 0.005;
		gFecundability[14] := 0.01;
		gFecundability[15] := 0.02;
		gFecundability[16] := 0.06;
		gFecundability[17] := 0.10;
		gFecundability[18] := 0.14;
		gFecundability[19] := 0.18;
		gFecundability[20] := 0.22;
		gFecundability[21] := gMean_fecundability;
		
		for i := 22 to kMaxAgeFert do
			gFecundability[i] := gFecundability[i-1];
		
		for i := 10 to kMaxAgeFert do
			gFecundability[i] := gFecundability[i] * 12 / kNbLunarMonths;
	end;
	
	procedure betaHeterogeneityFecundability (alpha, beta: double);
		var
			i: longint;
			p, tot: double;
	begin
		{Beta distribution}
		gFecundability_alpha := alpha;
		gFecundability_beta := beta;
		tot := 0.0;
		gMean_fecundability := gFecundability_alpha / (gFecundability_alpha + gFecundability_beta);
		p := 0.00000001;
		gDistrib_fecundability [0] := power (p, gFecundability_alpha - 1.0) * power (1.0 - p, gFecundability_beta - 1.0);
		tot := gDistrib_fecundability [0];
		for i := 1 to kMaxDistribFecundability - 1 do
		begin
			p := 1.0 * i / kMaxDistribFecundability;
			gDistrib_fecundability [i] := power (p, gFecundability_alpha - 1.0) * power (1.0 - p, gFecundability_beta - 1.0);
			tot := tot + gDistrib_fecundability [i];
		end;
		p := 1.0 - 0.00000001;
		gDistrib_fecundability [kMaxDistribFecundability] :=
				power (p, gFecundability_alpha - 1.0) *
				power (1.0 - p, gFecundability_beta - 1.0);
		tot := tot + gDistrib_fecundability [kMaxDistribFecundability-1];
		
		for i := 0 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] / tot;
		
		for i := 1 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] + gDistrib_fecundability [i-1];
		
		gDistrib_fecundability [kMaxDistribFecundability] := 1.0;
		
		if gRunFromIDE then
			dumpArray ('gDistrib_fecundability_beta', gDistrib_fecundability);

		initFecundability ();
	end;
	
	procedure normalHeterogeneityFecundability (mean, stdDev: double);
		{Builds gDistrib_fecundability, the CUMULATIVE distribution from which
		 fecundabilityLevel draws each woman's constant multiplier.

		 Convention, which is what the parameter description promises:
		   - the grid is a grid on FECUNDABILITY p, from 0 at val = -mean to 1 at index
		     kMaxDistribFecundability, so index i corresponds to p = i / kMaxDistribFecundability;
		   - val is the deviation p - mean, so val runs from -mean to 1 - mean;
		   - stdDev is the standard deviation OF FECUNDABILITY, in the same units as mean.
		     Leridon (2004) is therefore mean = 0.23, stdDev = 0.12.

		 fecundabilityLevel returns i / (mean * kMaxDistribFecundability), that is p / mean,
		 so the multiplier is centred on 1 and its maximum, 1 / mean, gives a fecundability
		 of exactly 1: one conception per cycle. Both properties depend on inc being
		 exactly 1 / kMaxDistribFecundability.

		 Note that the normal is truncated at p = 0, that is at -mean/stdDev standard
		 deviations. With 0.23 and 0.12 that is -1.92, so the realised mean is about 0.238
		 and the realised standard deviation about 0.112 rather than 0.12. A beta, which
		 lives on [0, 1] by construction, avoids this: see betaHeterogeneityFecundability.}
		var
			i: longint;
			val: double;
			inc: double;
			tot: double;
	begin
		if (stdDev <= 0.0) then begin
			writeAndWaitConst (['===> ERROR: stdDev must be > 0 in normalHeterogeneityFecundability']);
			exit;
		end;

		tot := 0.0;
		gMean_fecundability := mean;
		gStdDev_fecundability := stdDev;

		{val is the deviation from the mean, so it starts one step below p = 0}
		val := - gMean_fecundability;
		{one grid step = one 1/kMaxDistribFecundability of the fecundability range [0, 1]}
		inc := 1.0 / kMaxDistribFecundability;

		gDistrib_fecundability [0] := 0.0;
		for i := 1 to kMaxDistribFecundability do
		begin
			val := val + inc;
			gDistrib_fecundability [i] :=
				exp ( -0.5 * sqr ( val / gStdDev_fecundability ) ) /
				( gStdDev_fecundability * power ( 2.0 * 3.14159265359, 0.5));
			tot := tot + gDistrib_fecundability [i];
		end;

		for i := 0 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] / tot;

		// cumulative function
		for i := 1 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] + gDistrib_fecundability [i-1];

		gDistrib_fecundability [kMaxDistribFecundability] := 1.0;

		if gRunFromIDE then
			dumpArray ('gDistrib_fecundability_normal', gDistrib_fecundability);

		initFecundability ();
	end;
	
	procedure normalHeterogeneityFecundability_old (mean, stdDev: double);
		var
			i: longint;
			val: double;
			inc: double;
			tot: double;
	begin
		tot := 0.0;
		gMean_fecundability := mean;
		gStdDev_fecundability := stdDev;
		val := - gMean_fecundability;
		inc := 2.0 * gMean_fecundability / ( (1 + gMean_fecundability * 200) * (kMaxDistribFecundability / 100.0) );
		
		gDistrib_fecundability [0] := 0.0;
		tot := gDistrib_fecundability [0];
		for i := 1 to kMaxDistribFecundability do
		begin
			val := val + inc;
			gDistrib_fecundability [i] :=
				exp( -0.5 * power ( ( val / gMean_fecundability ) / gStdDev_fecundability, 2 ) ) /
				( gStdDev_fecundability * power ( 2.0 * 3.14159265359, 0.5));
			tot := tot + gDistrib_fecundability [i];
		end;
		
		for i := 0 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] / tot;
		
		
		// cumulative function
		for i := 1 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] + gDistrib_fecundability [i-1];
		
		gDistrib_fecundability [kMaxDistribFecundability] := 1.0;

		if gRunFromIDE then
			dumpArray ('gDistrib_fecundability', gDistrib_fecundability);
			
		initFecundability ();
	end;
	
	procedure initFertilityModel;
		var
			ageWomen: FecundAges;
			i: longint;
	begin
		{Pittinger / Wood}
		for ageWomen := kMinAgeFert to kMaxAgeFert do
			gDefinitive_sterility[ageWomen] := 1 - exp(0.00043 * (1 - power (1.14345, ageWomen - 5.67)) / ln (1.14345) );
		gDefinitive_sterility[kMaxAgeFert] := 1.0;
		
		{Léridon 2004, rétropolé et extrapolé par ajustement d'un polynome du troisième degré}
		for ageWomen := kMinAgeFert to kMaxAgeFert do
			gIntrauterine_mortality_risk[ageWomen] := 0.05091517857 + 0.0093172619 * ageWomen - 0.00046642857 * ageWomen * ageWomen + 0.00000866667 * ageWomen * ageWomen * ageWomen;
		gIntrauterine_mortality_risk[kMaxAgeFert] := 1.0;

		{Barrett 1978}
		for i := kMinAgeFert to kMaxAgeFert do
			gStillbirth_mortality_risk[i] := 0.03 + 0.001 * (i - 30);
		gStillbirth_mortality_risk[kMaxAgeFert] := 1.0;

		{Barrett 1978}
		gDistrib_intrauterine_mortality_risk[1] := 0.453799845;
		gDistrib_intrauterine_mortality_risk[2] := gDistrib_intrauterine_mortality_risk[1] + 0.249589915;
		gDistrib_intrauterine_mortality_risk[3] := gDistrib_intrauterine_mortality_risk[2] + 0.137274453;
		gDistrib_intrauterine_mortality_risk[4] := gDistrib_intrauterine_mortality_risk[3] + 0.075500949;
		gDistrib_intrauterine_mortality_risk[5] := gDistrib_intrauterine_mortality_risk[4] + 0.041525522;
		gDistrib_intrauterine_mortality_risk[6] := gDistrib_intrauterine_mortality_risk[5] + 0.022839037;
		gDistrib_intrauterine_mortality_risk[7] := gDistrib_intrauterine_mortality_risk[6] + 0.01256147;
		gDistrib_intrauterine_mortality_risk[8] := gDistrib_intrauterine_mortality_risk[7] + 0.006908809;
	
		{Fecundability heterogeneity distributed as a beta function}
		{Hutterite: Majumdar & Sheps [1970]}
		betaHeterogeneityFecundability (3.14, 9.19);
		
		{Lesthaeghe and Page [1980]}
		gSchedule_temporary_sterility[0]  := 1.0;
		gSchedule_temporary_sterility[1]  := 1.0;
		gSchedule_temporary_sterility[2]  := 0.989;
		gSchedule_temporary_sterility[3]  := 0.964;
		gSchedule_temporary_sterility[4]  := 0.938;
		gSchedule_temporary_sterility[5]  := 0.914;
		gSchedule_temporary_sterility[6]  := 0.888;
		gSchedule_temporary_sterility[7]  := 0.862;
		gSchedule_temporary_sterility[8]  := 0.834;
		gSchedule_temporary_sterility[9]  := 0.803;
		gSchedule_temporary_sterility[10] := 0.77;
		gSchedule_temporary_sterility[11] := 0.732;
		gSchedule_temporary_sterility[12] := 0.687;
		gSchedule_temporary_sterility[13] := 0.631;
		gSchedule_temporary_sterility[14] := 0.564;
		gSchedule_temporary_sterility[15] := 0.49;
		gSchedule_temporary_sterility[16] := 0.414;
		gSchedule_temporary_sterility[17] := 0.343;
		gSchedule_temporary_sterility[18] := 0.282;
		gSchedule_temporary_sterility[19] := 0.232;
		gSchedule_temporary_sterility[20] := 0.19;
		gSchedule_temporary_sterility[21] := 0.156;
		gSchedule_temporary_sterility[22] := 0.128;
		gSchedule_temporary_sterility[23] := 0.106;
		gSchedule_temporary_sterility[24] := 0.089;
		gSchedule_temporary_sterility[25] := 0.075;
		gSchedule_temporary_sterility[26] := 0.063;
		gSchedule_temporary_sterility[27] := 0.053;
		gSchedule_temporary_sterility[28] := 0.044;
		gSchedule_temporary_sterility[29] := 0.037;
		gSchedule_temporary_sterility[30] := 0.032;
		gSchedule_temporary_sterility[31] := 0.026;
		gSchedule_temporary_sterility[32] := 0.022;
		gSchedule_temporary_sterility[33] := 0.019;
		gSchedule_temporary_sterility[34] := 0.016;
		gSchedule_temporary_sterility[35] := 0.013;
		gSchedule_temporary_sterility[36] := 0.011;
		gSchedule_temporary_sterility[37] := 0.009;
		gSchedule_temporary_sterility[38] := 0.008;
		gSchedule_temporary_sterility[39] := 0.006;
		gSchedule_temporary_sterility[40] := 0.005;
		gSchedule_temporary_sterility[41] := 0.005;
		gSchedule_temporary_sterility[42] := 0.005;
		gSchedule_temporary_sterility[43] := 0.005;
		gSchedule_temporary_sterility[44] := 0.00000001; {kMaxMonthTemporarySterility}
		
	end;

	procedure initialSetFixedParameters;
	begin
		with g_GENPARAM do begin
			{Everyone gets married at the same age. If true, then nStepsUnion_Dev > 1 makes no sense}
			fixedParameters [fixedUnionAge] := parameterStateName.Create (kNotUsed, FALSE, 'FIXED_AGE_UNION', '',
												'Same age at union for everybody and all cohorts. If TRUE then:' + LineEnding +
												'- All women will have age at union MEAN_AGE_UNION' + LineEnding +
												'- All men will have MEAN_AGE_UNION_MEN' + LineEnding +
												'- The same if we are stepping for women between MEAN_AGE_UNION and MEAN_AGE_UNION_HIGH)',
												'',
												g_GENPARAM.listOfParams);
			{Zero sterility up to age 25}
			fixedParameters [noInitialSterility] := parameterStateName.Create (kNotUsed, FALSE, 'NO_INITIAL_STERILITY', '',
												'Proportion sterile is 0 up to age 26 if TRUE', '', g_GENPARAM.listOfParams);
			{Constant sterility at its 26 year old level up to a specified age where the proportion of sterile women is equal to 100%.}
			fixedParameters [fixedDefinitiveSterility] := parameterStateName.Create (50, FALSE, 'FIXED_DEFINITIVE_STERILITY', 'AGE_FIXED_DEFINITIVE_STERILITY_',
												'Proportion sterile is constant beginning with age 26 and equal to 1 after age entered as parameter (enter TRUE or parameter value)',
												'Age at total sterility', g_GENPARAM.listOfParams);
			{The duration of postpartum period is the same for all women}
			fixedParameters [fixedAmenorrhea] := parameterStateName.Create (2, FALSE, 'FIXED_AMENORRHEA', 'ZERO_FIXED_AMENORRHEA_',
												'Duration of amenorrhea the same for everybody and all cohorts (enter TRUE or a number of lunar months)',
												'Default of 2 will give two months of temporary sterility after the childbirth', g_GENPARAM.listOfParams);
			{Fecundability is constant until the women is sterile}
			fixedParameters [fixedFecundability] := parameterStateName.Create (kNotUsed, FALSE, 'FIXED_FECUNDABILITY', '',
												'Fecundability is constant until age at sterility (TRUE or FALSE)', '', g_GENPARAM.listOfParams);
			{No fecundability differences between women}
			fixedParameters [homogeneousFecundability] := parameterStateName.Create (kNotUsed, FALSE, 'HOMOGENEOUS_FECUNDABILITY', '',
												'Fecundability level is equal for all women, but may vary with age, depending on other options (TRUE or FALSE)',
												'', g_GENPARAM.listOfParams);
			fixedParameters [reshuffledFecundability] := parameterStateName.Create (kNotUsed, FALSE, 'RESHUFFLED_FECUNDABILITY', '',
												'Fecundability heterogeneity is reshuffled after each childbirth,' + LineEnding +
												'so the relative level of women change for each interval (TRUE or FALSE)',
												'', g_GENPARAM.listOfParams);
												
			{Maximum fecundity at 22 and linear drop to 32 years, constant after NOT CLEAR WHAT THIS IS DOING}
			fixedParameters [HighLowFecundability] := parameterStateName.Create (kNotUsed, FALSE, 'HIGH_LOW_FECUNDABILITY', '',
												'(CHECK THIS - NOT CLEAR) Mean fecundability increases linearly up to age 32, then decrease linearly with age (TRUE or FALSE)',
												'', g_GENPARAM.listOfParams);
			{Léridon’s sterility model}
			fixedParameters [LeridonDefinitiveSterility] := parameterStateName.Create (kNotUsed, FALSE, 'LERIDON_STERILITY', '',
												'Leridon [2008] sterility scheme (TRUE or FALSE)' + LineEnding +
												'If all alternative schemes are FALSE, we fall back on Pittinger and Wood', '', g_GENPARAM.listOfParams);
			{Daniel’s sterility model}
			fixedParameters [KinFertDefinitiveSterility] := parameterStateName.Create (kNotUsed, TRUE, 'KINFERT_STERILITY', '',
												'KinFert''s sterility scheme based on Leridon [2008] and South African 1921 Census (TRUE or FALSE)' + LineEnding +
												'If all alternative schemes are FALSE, we fall back on Pittinger and Wood', '', g_GENPARAM.listOfParams);
			{Intrauterine mortality and stillbirth rate do not increase with age. Constant at their level at age 15}
			fixedParameters [fixedIntrauterineMortality] := parameterStateName.Create (kNotUsed, FALSE, 'FIXED_INTRAUTERINE_MORTALITY', '',
												'Intrauterine mortality is constant with age (TRUE or FALSE)', '', g_GENPARAM.listOfParams);
			{No difference in the risk of separation according to family size}
			fixedParameters [homogeneousSeparation] := parameterStateName.Create (kNotUsed, FALSE, 'HOMOGENEOUS_SEPARATION', '',
												'Separation risk does not depend on number of children (TRUE or FALSE)', '', g_GENPARAM.listOfParams);
			{Fecundability is distributed according to a normal instead of beta}
			fixedParameters [normaldistributionfecundability] := parameterStateName.Create (kNotUsed, TRUE, 'NORMAL_HETEROGENEITY_FECUNDABILITY', '',
												'Heterogeneity of fecundability distributed as a normal mean 0.23, std dev 0.12, like Leridon [2004] (TRUE) or as a beta (FALSE)', '', g_GENPARAM.listOfParams);																											  
			fixedParameters [stdUnionDanielOrCampbellWood] := parameterStateName.Create (kNotUsed, TRUE, 'STDDEV_UNION_KIND', '',
												'(Obsolete) Standard Deviation of Union according to Daniel (TRUE) or to Campbell and Wood 1988. Defect value is TRUE', '', g_GENPARAM.listOfParams);
			fixedParameters [waitingTimeErlangPoisson] := parameterStateName.Create (kNotUsed, TRUE, 'WAITING_TIME_ERLANG_POISSON', '',
												'Either Erlang (TRUE) or Poisson (FALSE) for the model of waiting time before no contraception, after union or after each birth', '', g_GENPARAM.listOfParams);
		end; {with g_GENPARAM}
		
	end;
	
	procedure initFixedParameters();
	var
		kind: fixedParameterKind;
	begin
		for kind := low (fixedParameterKind) to high (fixedParameterKind) do begin
			fixParameter (kind, g_GENPARAM.fixedParameters [kind].param.value);
		end;
	end;
	
	procedure info_FixParameter ();
	begin
		if ( g_GENPARAM.fixedParameters [fixedUnionAge].state.value = true ) then
			aWriteLnAll (' fixedUnionAge');
		if ( g_GENPARAM.fixedParameters [noInitialSterility].state.value = true ) then
			aWriteLnAll (' noInitialSterility');
		if ( g_GENPARAM.fixedParameters [fixedDefinitiveSterility].state.value = true ) then
			aWriteLnAll (' fixedDefinitiveSterility');
		if ( g_GENPARAM.fixedParameters [fixedAmenorrhea].state.value = true ) then
			aWriteLnAll (' fixedAmenorrhea');
		if ( g_GENPARAM.fixedParameters [fixedFecundability].state.value = true ) then
			aWriteLnAll (' fixedFecundability');
		if ( g_GENPARAM.fixedParameters [homogeneousFecundability].state.value = true ) then
			aWriteLnAll (' homogeneousFecundability');
		if ( g_GENPARAM.fixedParameters [HighLowFecundability].state.value = true ) then
			aWriteLnAll (' HighLowFecundability');
		if ( g_GENPARAM.fixedParameters [fixedIntrauterineMortality].state.value = true ) then
			aWriteLnAll (' fixedIntrauterineMortality');
		if ( g_GENPARAM.fixedParameters [LeridonDefinitiveSterility].state.value = true ) then
			aWriteLnAll (' LeridonDefinitiveSterility');
		if ( g_GENPARAM.fixedParameters [KinFertDefinitiveSterility].state.value = true ) then
			aWriteLnAll (' KinFertDefinitiveSterility');
		if ( g_GENPARAM.fixedParameters [homogeneousSeparation].state.value = true ) then
			aWriteLnAll (' homogeneousSeparation');
		if ( g_GENPARAM.fixedParameters [normaldistributionfecundability].state.value = true ) then
			aWriteLnAll (' normaldistributionfecundability');
		if ( g_GENPARAM.fixedParameters [waitingTimeErlangPoisson].state.value = true ) then
			aWriteLnAll (' waitingTimeErlangPoisson');
	end;
	
	procedure fixParameter (kind: fixedParameterKind; value: double);
	var
		ageWomen: longint;
		i: longint;
		
	begin {fixParameter}
		{g_GENPARAM.fixedParameters [kind].state.value := true;}
		g_GENPARAM.fixedParameters [kind].param.value := value;
		
		if ( g_GENPARAM.fixedParameters [kind].state.value = true ) then
		begin
			case kind of
				fixedUnionAge:
					begin
					end;
				noInitialSterility:
					begin
						for ageWomen := kMinAgeFert to 25 do
							gDefinitive_sterility[ageWomen] := 0.0;
					end;
				fixedDefinitiveSterility:
					begin
						for ageWomen := 26 to trunc (value) - 1 do
							gDefinitive_sterility[ageWomen] := gDefinitive_sterility[ageWomen-1];
						for ageWomen := trunc (value) to kMaxAgeFert do
							gDefinitive_sterility[ageWomen] := 1.0;
					end;
				fixedAmenorrhea:
					begin
						//init_temporary_sterility (g_pDEM_REG, value, 2);
					end;
				fixedFecundability:
					begin
					end;
				homogeneousFecundability:
					begin
					end;
				HighLowFecundability:
					begin
						gFecundability[10] := 0.0;
						gFecundability[11] := 0.005;
						gFecundability[12] := 0.01;
						gFecundability[13] := 0.02;
						gFecundability[14] := 0.04;
						gFecundability[15] := 0.06;
						gFecundability[16] := 0.08;
						gFecundability[17] := 0.12;
						gFecundability[18] := 0.16;
						gFecundability[19] := 0.20;
						gFecundability[20] := 0.24;
						gFecundability[21] := 0.28;
						gFecundability[22] := 0.32;
						
						for i := 23 to 32 do
							gFecundability[i] := gFecundability[i-1] - 0.01;
						for i := 33 to kMaxAgeFert do
							gFecundability[i] := gFecundability[i-1];
						for i := 10 to kMaxAgeFert do
							gFecundability[i] := gFecundability[i] * 13 / kNbLunarMonths;
					end;
				fixedIntrauterineMortality:
					begin
						for ageWomen := kMinAgeFert to kMaxAgeFert do
							gIntrauterine_mortality_risk[ageWomen] := 0.32124248 - 0.01775048 * 15 + 0.00039157 * 15 * 15;

						for i := kMinAgeFert to kMaxAgeFert do
							gStillbirth_mortality_risk[i] := 0.03 + 0.001 * (15 - 30);
					end;
				KinFertDefinitiveSterility:
					begin
						gDefinitive_sterility[10] := 0.01;
						gDefinitive_sterility[11] := 0.0115;
						gDefinitive_sterility[12] := 0.013;
						gDefinitive_sterility[13] := 0.0145;
						gDefinitive_sterility[14] := 0.016;
						gDefinitive_sterility[15] := 0.0175;
						gDefinitive_sterility[16] := 0.019;
						gDefinitive_sterility[17] := 0.0205;
						gDefinitive_sterility[18] := 0.022;
						gDefinitive_sterility[19] := 0.0235;
						gDefinitive_sterility[20] := 0.025;
						gDefinitive_sterility[21] := 0.0265;
						gDefinitive_sterility[22] := 0.028;
						gDefinitive_sterility[23] := 0.0295;
						gDefinitive_sterility[24] := 0.031;
						gDefinitive_sterility[25] := 0.0325;
						gDefinitive_sterility[26] := 0.035;
						gDefinitive_sterility[27] := 0.03722199;
						gDefinitive_sterility[28] := 0.040377765;
						gDefinitive_sterility[29] := 0.045386742;
						gDefinitive_sterility[30] := 0.05167339;
						gDefinitive_sterility[31] := 0.060726363;
						gDefinitive_sterility[32] := 0.073012125;
						gDefinitive_sterility[33] := 0.088836923;
						gDefinitive_sterility[34] := 0.108178073;
						gDefinitive_sterility[35] := 0.131531607;
						gDefinitive_sterility[36] := 0.159840247;
						gDefinitive_sterility[37] := 0.192559791;
						gDefinitive_sterility[38] := 0.227886378;
						gDefinitive_sterility[39] := 0.264109658;
						gDefinitive_sterility[40] := 0.3;
						gDefinitive_sterility[41] := 0.335109658;
						gDefinitive_sterility[42] := 0.371886378;
						gDefinitive_sterility[43] := 0.416559791;
						gDefinitive_sterility[44] := 0.496840247;
						gDefinitive_sterility[45] := 0.626531607;
						gDefinitive_sterility[46] := 0.751178073;
						gDefinitive_sterility[47] := 0.838836923;
						gDefinitive_sterility[48] := 0.899012125;
						gDefinitive_sterility[49] := 0.931726363;
						gDefinitive_sterility[50] := 0.95067339;
						gDefinitive_sterility[51] := 0.965386742;
						gDefinitive_sterility[52] := 0.978377765;
						gDefinitive_sterility[53] := 0.99022199;
						gDefinitive_sterility[54] := 0.996;
						gDefinitive_sterility[55] := 0.999;
						gDefinitive_sterility[56] := 0.998;
						gDefinitive_sterility[57] := 0.998;
						gDefinitive_sterility[58] := 0.9991;
						gDefinitive_sterility[59] := 1;
					end;
				LeridonDefinitiveSterility:
					begin
						gDefinitive_sterility[10] := 0.01;
						gDefinitive_sterility[11] := 0.01;
						gDefinitive_sterility[12] := 0.01;
						gDefinitive_sterility[13] := 0.01;
						gDefinitive_sterility[14] := 0.01;
						gDefinitive_sterility[15] := 0.01;
						gDefinitive_sterility[16] := 0.01;
						gDefinitive_sterility[17] := 0.01;
						gDefinitive_sterility[18] := 0.01;
						gDefinitive_sterility[19] := 0.01;
						gDefinitive_sterility[20] := 0.01;
						gDefinitive_sterility[21] := 0.01;
						gDefinitive_sterility[22] := 0.01;
						gDefinitive_sterility[23] := 0.01;
						gDefinitive_sterility[24] := 0.01;
						gDefinitive_sterility[25] := 0.01;
						gDefinitive_sterility[26] := 0.011;
						gDefinitive_sterility[27] := 0.012;
						gDefinitive_sterility[28] := 0.014;
						gDefinitive_sterility[29] := 0.017;
						gDefinitive_sterility[30] := 0.02;
						gDefinitive_sterility[31] := 0.024;
						gDefinitive_sterility[32] := 0.029;
						gDefinitive_sterility[33] := 0.035;
						gDefinitive_sterility[34] := 0.042;
						gDefinitive_sterility[35] := 0.051;
						gDefinitive_sterility[36] := 0.064;
						gDefinitive_sterility[37] := 0.082;
						gDefinitive_sterility[38] := 0.105;
						gDefinitive_sterility[39] := 0.133;
						gDefinitive_sterility[40] := 0.166;
						gDefinitive_sterility[41] := 0.204;
						gDefinitive_sterility[42] := 0.249;
						gDefinitive_sterility[43] := 0.306;
						gDefinitive_sterility[44] := 0.401;
						gDefinitive_sterility[45] := 0.546;
						gDefinitive_sterility[46] := 0.685;
						gDefinitive_sterility[47] := 0.785;
						gDefinitive_sterility[48] := 0.855;
						gDefinitive_sterility[49] := 0.895;
						gDefinitive_sterility[50] := 0.919;
						gDefinitive_sterility[51] := 0.937;
						gDefinitive_sterility[52] := 0.952;
						gDefinitive_sterility[53] := 0.965;
						gDefinitive_sterility[54] := 0.976;
						gDefinitive_sterility[55] := 0.985;
						gDefinitive_sterility[56] := 0.991;
						gDefinitive_sterility[57] := 0.996;
						gDefinitive_sterility[58] := 0.999;
						gDefinitive_sterility[59] := 1;
					end;
				normaldistributionfecundability:
					begin
						{Leridon (2004), Human Reproduction 19(7):1548-1553, p.1550 and Figure 1:
						 Fmax = N(0.23; 0.12), a Gaussian around a mean plateau fecundability of
						 0.23 with a standard deviation of 0.12, both in fecundability units.
						
						 These are the NOMINAL parameters. The grid starts at p = 0, so the normal
						 is truncated at -1.92 standard deviations and the mass below zero is
						 redistributed by the normalisation. The REALISED distribution is therefore
						 mean 0.2381 and standard deviation 0.1118, not 0.23 and 0.12.
						
						 If the model comes out too fecund when checked against Leridon's Table I
						 (conception ending in a live birth within 12 months: 75.4 per cent at age 30,
						 66.0 at 35, 44.3 at 40), replace the call below with
						     normalHeterogeneityFecundability (0.2133, 0.1350);
						 which are the underlying parameters whose truncated realisation has
						 exactly Leridon's mean 0.2300 and standard deviation 0.1200.
						 Keep whichever is chosen consistent with the manual.}
						normalHeterogeneityFecundability (0.23, 0.12);
					end;
				homogeneousSeparation:
					begin
					end;
				waitingTimeErlangPoisson:
					begin
					end;
			end; {case}
		end;
	end;

	procedure goBackToFirstChild (var pChild: pInfoChildType);
	begin
		if pChild = nil then exit;
		
		while ( pChild^.previous <> nil ) do
			pChild := pChild^.previous;
	end;
	
	procedure gotoToFirstLiveBornChild (var pChild: pInfoChildType);
	begin
		while (pChild <> nil) and (not pChild^.livingAtBirth) do
			pChild := pChild^.next;
	end;
	
	procedure gotoToNextLiveBornChild (var pChild: pInfoChildType);
	begin
		if pChild = nil then exit;
		pChild := pChild^.next;		
		gotoToFirstLiveBornChild (pChild);
	end;
	
	function numChildrenBornAlive (pChild: pInfoChildType): longint;
	begin
		result := 0;
		gotoToFirstLiveBornChild (pChild);
		while (pChild <> nil) do begin
			result := result + 1;
			gotoToNextLiveBornChild (pChild);
		end;
	end;
	
	procedure copyChild (pChildFrom: pInfoChildType; var pChildTo: pInfoChildType; createNew: boolean = true);
	begin
		if createNew then newChild (pChildTo);
		pChildTo^ := pChildFrom^;
		with pChildTo^ do
		begin
			previous := nil;
			next := nil;
		end;
	end;
	
	procedure initChild (var pChild: pInfoChildType);
	begin
		if pChild = nil then exit;
		with pChild^ do
		begin
			sex := man;
			yearBirth := 0.0;
			livingAtBirth := false;
			birthOrder := kNotDefined;
			ageMotherAtChildbirth := kNotDefined;
			ageMotherAtFecundation := kNotDefined;
			ageFatherAtChildbirth := kNotDefined;
			ageDeath := kNotDefined;
			motherUnionNumber := kNotDefined;
			durationUnion := kNotDefined;
			monthStartInterval := kNotDefined;
			monthFecundation := kNotDefined;
			monthEndPregnancy := kNotDefined;
			monthNewOvulation := kNotDefined;
			previous := nil;
			next := nil;
			check := kInfoChildCheck;
			arrayChildren := nil;
			posInArray := kNotDefined;
		end;
	end;

	function topOfChildrenList (pChild: pInfoChildType): pInfoChildType;
	begin
		while (pChild^.previous <> nil) do
			pChild := pChild^.previous;
		result := pChild;
	end;
	
	function tailOfChildrenList (pChild: pInfoChildType): pInfoChildType;
	begin
		while (pChild^.next <> nil) do
			pChild := pChild^.next;
		result := pChild;
	end;

	procedure CreateArrayChildren(var arrayChildren: arrayOfInfoChild);
	var
		ind: longint;
        pChild: pInfoChildType;
	begin
		if not g_GENPARAM.USE_ARRAY_CHILDREN.value then begin
			setLength (arrayChildren, 0);
			exit;
		end;
		setLength (arrayChildren, kInitNumberChildType);
		for ind := low(arrayChildren) to high(arrayChildren) do begin
			new (pChild);
			newPtr (ptr(pChild), 'pInfoChildType');
            arrayChildren[ind] := pChild;
		end;
	end;
	
	procedure DestroyArrayChildren(var arrayChildren: arrayOfInfoChild);
	var
		ind: longint;
		pChild: pInfoChildType;
	begin
		if not g_GENPARAM.USE_ARRAY_CHILDREN.value then exit;
		for ind := low(arrayChildren) to high(arrayChildren) do begin
			pChild := arrayChildren[ind];
			if pChild^.arrayChildren <> nil then begin
				if gRunFromIDE then
{$IFNDEF ARM}
					asm int 3 end;
{$ELSE}
					assert(false);
{$ENDIF}
				pChild^.arrayChildren := nil;
			end;
			disposePtr(ptr(pChild), 'pInfoChildType');
            arrayChildren[ind] := nil;
		end;
		setLength (arrayChildren, 0);
	end;	


	procedure newChild_AC (var pChild: pInfoChildType; const arrayChildren: arrayOfInfoChild = nil);
	begin
		if arrayChildren = nil then begin
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
			writeAndWaitConst (['===> ERROR: wrong call to newChild. Very bad']);
			exit;
		end;
		if pChild = nil then begin
			// top of the list
			pChild := arrayChildren[0];
			initChild (pChild);
			pChild^.arrayChildren := arrayChildren;
			pChild^.posInArray := 0;
			exit;
		end;
		// go to tail of list
		while (pChild^.next <> nil) and (pChild^.ageMotherAtChildbirth > 0.0) do begin
			pChild := pChild^.next;
		end;
		if pChild^.next <> nil then begin
			// we are not at the tail, and we have found an empty child record
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
		end;
		// we are at the tail of the list
		if pChild^.posInArray >= (length (pChild^.arrayChildren) - 1) then begin
			setLength (pChild^.arrayChildren, length (pChild^.arrayChildren) + kAddNumberChildType);
			if gRunFromIDE then
				// this is not wrong proper, but should be avoided as we try to reserve enough memory beforehand
				memoWriteLn (['Growing pInfoChildType list']);
		end;
		pChild^.next := pChild^.arrayChildren[pChild^.posInArray + 1];
		initChild (pChild^.next);
		pChild^.next^.arrayChildren := pChild^.arrayChildren;
		pChild^.next^.posInArray := pChild^.posInArray + 1;
		pChild^.next^.previous := pChild;
		pChild := pChild^.next;
	end;

	procedure disposeChild_AC ( var pChild: pInfoChildType );
    var
        pCurrChild: pInfoChildType;
	begin
		if (pChild <> nil) then begin
            pChild^.arrayChildren := nil; // decrease the reference count
            pChild^.posInArray := kNotDefined;
			if (pChild^.previous <> nil) then begin
                pCurrChild := pChild^.previous;
            	pCurrChild^.next := nil;
			end;
			if (pChild^.next <> nil) then begin
                pCurrChild := pChild^.next;
           		disposeChild_AC (pCurrChild);
			end;
            pChild := nil;
		end;
	end;

	function duplicateChildrenList_AC (pChild: pInfoChildType; var arrayChildren: arrayOfInfoChild): pInfoChildType;
	var
		pChild_dup: pInfoChildType = nil;
 		ind: longint;
	begin
		if pChild = nil then begin
			duplicateChildrenList_AC := nil;
			exit;
		end;
        if (length (arrayChildren) = 0) then
			if gRunFromIDE then begin
				writeAndWaitConst (['===> ERROR: Bad: arrayChildren should have a positive size']);
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
			end;
		newChild_AC (pChild_dup, arrayChildren);
		duplicateChildrenList_AC := pChild_dup;
		if length(pChild^.arrayChildren) > length(arrayChildren) then begin
			setLength(arrayChildren, length(pChild^.arrayChildren));
			if gRunFromIDE then
				// this is not wrong proper, but should be avoided as we try to reserve enough memory beforehand
				memoWriteLn (['Growing arrayChildren size']);
		end;
		for ind := 0 to (length(arrayChildren) - 1) do begin
			if pChild = nil then break;
			pChild_dup := arrayChildren[ind];
			// pChild and pChild_dup both are pointers to a record, so we can copy directly
			pChild_dup^ := pChild^;
			pChild_dup^.arrayChildren := arrayChildren;
			pChild_dup^.posInArray := ind;
			if pChild^.previous <> nil then
				pChild_dup^.previous := arrayChildren[ind - 1];
			if pChild^.next <> nil then
				pChild_dup^.next := arrayChildren[ind + 1];
			pChild := pChild^.next;
		end;
	end;

   	procedure newChild (var pChild: pInfoChildType; const arrayChildren: arrayOfInfoChild = nil);
	begin
		if (arrayChildren <> nil) and (length(arrayChildren) > 0) then begin
			newChild_AC (pChild, arrayChildren);
			exit;
		end;
		if pChild = nil then
		begin
			new (pChild);
			newPtr (ptr(pChild), 'pChild');
			initChild (pChild);
			exit;
		end;
		// go to tail of list
		while (pChild^.next <> nil) and (pChild^.ageMotherAtChildbirth > 0.0) do begin
			pChild := pChild^.next;
		end;
		if pChild^.next <> nil then begin
			// we are not at the tail, and we have found an empty child record
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
		end;
		// we are at the tail of the list
		if pChild^.next = nil then
		begin
			// we suppose we are at the tail of the list
			new (pChild^.next);
			newPtr (ptr(pChild^.next), 'pChild');
			initChild (pChild^.next);
			pChild^.next^.previous := pChild;
			pChild := pChild^.next;
		end else
			// if this not the case, we have a problem
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
	end;

    procedure disposeChild ( var pChild: pInfoChildType );
    var
        pCurrChild: pInfoChildType;
	begin
       	if pChild = pInfoChildType(nil) then exit;
        if pChild^.posInArray <> kNotDefined then begin
            disposeChild_AC (pChild);
            exit;
        end;
		if pChild <> pInfoChildType(nil) then begin
			if (pChild^.previous <> pInfoChildType(nil)) then begin
                pCurrChild := pChild^.previous;
            	pCurrChild^.next := pInfoChildType(nil);
			end;
			if (pChild^.next <> pInfoChildType(nil)) then begin
                pCurrChild := pChild^.next;
           		disposeChild (pCurrChild);
			end;
			disposePtr(ptr(pChild), 'pChild');
		end;
	end;
	
	function duplicateChildrenList (pChild: pInfoChildType): pInfoChildType;
	var
		pChild_dup: pInfoChildType = nil;
	begin
		if pChild = nil then
		begin
			duplicateChildrenList := nil;
			exit;
		end;
		if pChild^.posInArray <> kNotDefined then
		begin
			writeAndWaitConst (['===> ERROR: should have been a call to duplicateChildrenList_AC']);
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
		end;
		copyChild (pChild, pChild_dup);
		duplicateChildrenList := pChild_dup;
		while (pChild^.next <> nil) do
		begin
			pChild := pChild^.next;
			copyChild (pChild, pChild_dup^.next);
			pChild_dup^.next^.previous := pChild_dup;
			pChild_dup := pChild_dup^.next;
		end;
	end;

	function childInfoSizeOf (pChild: pInfoChildType): longint;
	begin
		result := 0;
		while (pChild <> nil) do begin
			result := result + sizeOf (pChild^);
			pChild := pChild^.next;
		end;
	end;

	function fecundabilityLevel (randomGenerator: TRandomNumberGenerator):double;
	var
		dummy: double;
		i: longint;
	begin
		if (g_GENPARAM.fixedParameters [homogeneousFecundability].state.value = true) then
		begin
			fecundabilityLevel := 1.0;
		end else begin
			dummy := randomGenerator.alea0();
			{Inverse CDF: i is the SMALLEST index whose cumulative reaches dummy.
			 Starting at 0 and testing [i+1], as this loop used to, returned one index
			 too low for every draw: a systematic shortfall of 1/(mean*kMaxDistribFecundability),
			 that is 1.45 per cent, and a multiplier of exactly 0 for the lowest cell
			 (0.19 per cent of women, sterile from the start by a route unrelated to
			 gDefinitive_sterility). The i < kMax guard also closes an out-of-bounds read.}
			i := 1;
			while (i < kMaxDistribFecundability) and (dummy > gDistrib_fecundability[i]) do
				i := i + 1;
			fecundabilityLevel := (i / (gMean_fecundability * kMaxDistribFecundability));
		end;
	end;
	
	{Nouveau avril 2004}
	function effectivenessContraceptionBeforeUnion (dp: arrayDemReg_double): double;
	begin
		effectivenessContraceptionBeforeUnion := dp[effContBeforeUnion].value;
	end;
	
	function effectivenessContraceptionStopping(p: pStructDemographicRegimeSettings; nbBirths: longint): double;
	var
		indMax: longint;
	begin
		indMax := min (nbBirths, kMaxIndBirthIntervals);
		effectivenessContraceptionStopping := p^.effStopping.value [indMax];
	end;
	
	function effectivenessContraceptionSpacing(p: pStructDemographicRegimeSettings; nbBirths: longint): double;
	var
		indMax: longint;
	begin
		indMax := min (nbBirths, kMaxIndBirthIntervals);
		effectivenessContraceptionSpacing := p^.effSpacing.value [indMax];
	end;
		
	procedure addEvent ( liveBirth: boolean; var numbers: durationCountType );
	begin
		if liveBirth then begin
			numbers [eventLiveBirth] := numbers [eventLiveBirth] + 1;
		end else begin
			numbers [eventEndUnion] := numbers [eventEndUnion] + 1;
		end;
		numbers [totalEvents] := numbers [totalEvents] + 1;
	end;
	
	procedure addEventDuration ( liveBirth: boolean; duration: longint; var numbers: numberDurationEventType );
	var
			dur: durationValues;
	begin
			for dur := low (durationValues) to high (durationValues) do begin
				if duration >= dur * kNbLunarMonths then begin
					addEvent ( liveBirth, numbers [dur] );
				end;
			end;
	end;
	
	procedure addTime ( monthStart: longint; duration: longint; nParity: longint; liveBirth: boolean; objOutputFert: TOutputFertility );
	var
		ageFemStartInterval: FecundAges;
		verifAge : integer;
	begin
		{if DEBUG then bWrite (gDebugFile, monthStart, tab, duration, tab);}
		{DEBUG VERIFIER monthStart COMPTE DEPUIS LA NAISSANCE...}
		verifAge := trunc ( lunarMonthsToAge (monthStart) );
		if (verifAge < low (FecundAges )) or ( verifAge > high (FecundAges)) then begin
			exit; {Out of fertile age}
		end else begin
			ageFemStartInterval := trunc ( lunarMonthsToAge ( monthStart ) );
		end;
		if (nParity > kMaxNbChildrenCalc) then nParity := kMaxNbChildrenCalc;
		with objOutputFert.noFecundation [nParity] do begin
			addEventDuration ( liveBirth, duration, number_tot );
			addEventDuration ( liveBirth, duration, numbers [ageFemStartInterval] );
		end;
	end;
	
	function locateUnion ( pChild: pInfoChildType ): longint;
	begin
		locateUnion := 0;
		if pChild = nil then exit;
		locateUnion := pChild^.motherUnionNumber;
	end;
	
	// Compute TIME TO CONCEPTION table
	procedure timeToConception ( unionStates: TUnionsType; pChild: pInfoChildType; objOutputFert: TOutputFertility );
	var
		unionCurrent, unionNum: longint;
		nParity: longint;
		monthStart, monthStartCurr: longint;
		duration, durationCurr: longint;
		monthStopBad, monthStartIsNewOvulation: boolean;
		
	begin
		if objOutputFert = nil then exit; // only for FERTILITY results
		nParity := 0;
		with unionStates do
		begin
			if nbUnions > 0 then
			begin
				duration := 0;
				unionCurrent := locateUnion ( pChild );
				if unionCurrent = 0 then unionCurrent := 1;
				if unionCurrent > 1 then begin
					for unionNum := 1 to unionCurrent do begin
						durationCurr := Unions [unionNum - 1].monthStop - Unions [unionNum - 1].monthStart + 1;
						if durationCurr > duration then begin
							duration := durationCurr;
							monthStart := Unions [unionNum - 1].monthStart;
						end;
					end;
				end;
				monthStartCurr := Unions [unionCurrent - 1].monthStart;

				while ( pChild <> nil ) do begin
					
					with ( pChild^ ) do begin
						durationCurr := monthFecundation - monthStartCurr + 1;
						if durationCurr > duration then begin
							duration := durationCurr;
							monthStart := monthStartCurr;
						end;
						if livingAtBirth then begin
							addTime ( monthStart, duration, nParity, true, objOutputFert );
							nParity := nParity + 1;
							duration := 0;
						end;
						unionNum := locateUnion ( next );
						if ( unionNum = 0) then unionNum := unionCurrent;
						monthStartIsNewOvulation := false;
						if ( unionCurrent = unionNum ) then begin
							monthStartCurr := monthNewOvulation;
							monthStartIsNewOvulation := true;
						end else begin
							unionCurrent := unionNum;
							monthStartCurr := Unions [unionCurrent - 1].monthStart;
						end;

						pChild := next;
					end;
						
				end; {do while ( pChild <> nil )}

				{No more pregnancy}
				{We always take longest time over unions}
				duration := Unions [unionCurrent - 1].monthStop - monthStartCurr + 1;
				monthStart := monthStartCurr;
				monthStopBad := Unions [unionCurrent - 1].monthStopIsStopping;
				if ( unionCurrent < nbUnions ) then begin
					for unionNum := unionCurrent+1 to nbUnions do begin
							durationCurr := Unions [unionCurrent - 1].monthStop - Unions [unionCurrent - 1].monthStart + 1;
							if durationCurr > duration then begin
								duration := durationCurr;
								monthStart := Unions [unionCurrent - 1].monthStart;
								monthStopBad := Unions [unionNum - 1].monthStopIsStopping;
							end;
					end;
				end;
				if (duration >= 0) then begin
					if monthStopBad then
						monthStopBad := monthStopBad
					else
						addTime ( monthStart, duration, nParity, false, objOutputFert );
				end else if (not monthStartIsNewOvulation) then
 				{There could be a negative duration in case of a birth after the end of union: this should be excluded}
               	if (unionStates.nbChildren > 0) then
					   // In this case the last birth should be excluded (TO BE DONE...)
					   writeAndWait ('===> WARNING: Birth excluded, occurs more than 10 months after end of union in timeToConception');

			end;
		end;
	end;
	
	procedure initFecundLife (randomGenerator: TRandomNumberGenerator; var fecundLife: FecundLifeType);
		var
			dummy: double;
			age: FecundAges;
			ageOfLoweringFecundability: double;
			periodOfLowFecundability: double;
			a, b: longint;
			valInf, valSup: double;
	begin
		periodOfLowFecundability := 12.5; {Léridon 2004}
{Age of permanent sterility}
		dummy := randomGenerator.alea0;
		fecundLife.ageSterile := kMinAgeFert;
		while (fecundLife.ageSterile < kMaxAgeFert) and (dummy > gDefinitive_sterility[trunc (fecundLife.ageSterile)]) do
			fecundLife.ageSterile := fecundLife.ageSterile + 1.0;
			
		if (fecundLife.ageSterile < kMinAgeFert) or (fecundLife.ageSterile > kMaxAgeFert) then
			writeAndWait ('===> ERROR: fecundLife.ageSterile bad in initFecundLife'); {DEBUG}

		{interpolation of exact age}
		if (fecundLife.ageSterile > kMinAgeFert) and (fecundLife.ageSterile < kMaxAgeFert) then begin
			valInf := gDefinitive_sterility[trunc (fecundLife.ageSterile)];
			valSup := gDefinitive_sterility[trunc (fecundLife.ageSterile + 1.0)];
			if (valSup > valInf) then
				fecundLife.ageSterile := fecundLife.ageSterile + (dummy - valInf) / (valSup - valInf)
			else
				fecundLife.ageSterile := fecundLife.ageSterile + randomGenerator.alea(0, 0.99999999999);
		end else
			fecundLife.ageSterile := kMinAgeFert;
{If the age at sterility is less than 33 years old, the period of falling fecundability must be modified, otherwise there is a risk 
that the woman be sterile before this decrease}
		if (fecundLife.ageSterile <= 33) then
		begin
			periodOfLowFecundability := periodOfLowFecundability - (33 - fecundLife.ageSterile);
			if (periodOfLowFecundability) < 0 then
			begin
				periodOfLowFecundability := 0;
			end;
		end;
			
		ageOfLoweringFecundability := max (kMinAgeFert, trunc (fecundLife.ageSterile - periodOfLowFecundability)); {Léridon 2004}
{Woman's level of fecundability}
		fecundLife.relativeFecundabilityLevel := fecundabilityLevel (randomGenerator);
		for age := kMinAgeFert to kMaxAgeFert do
		begin
			fecundLife.levelFecundabilityAge[age] := fecundLife.relativeFecundabilityLevel * gFecundability[age];
		end;
		{Léridon 2004}
		if (g_GENPARAM.fixedParameters [fixedFecundability].state.value = false) then
		begin
			a := trunc (ageOfLoweringFecundability);
			b := min (kMaxAgeFert, 1 + trunc (fecundLife.ageSterile));
			for age := a to b do
			begin
				fecundLife.levelFecundabilityAge[age] := fecundLife.levelFecundabilityAge[a] * ( 1.0 - (age - a) / (b - a) );
			end;
			for age := b to kMaxAgeFert do
				fecundLife.levelFecundabilityAge[age] := 0.0;
		end;
{stopping state}
		fecundLife.stopping := false;
	end;
		
	procedure finalPartnershipStatus (var unionStates: TUnionsType);
	var
		currUnion: longint;
		ageEndUnion: double; {Pour la femme}
		
		ageUnionWoman: double;
		ageDeathWoman: double;
		ageSeparationWoman: double;
		ageWomanAtDeathMan: double; {âge de la femme au décès du mari}
		
		ageFinal: double;
	begin

		ageEndUnion := 0;
		ageFinal := 50.0;
		
		with unionStates do
		begin
			if nbUnions > 0 then
			begin
				currUnion := 0;
				repeat
					currUnion := currUnion + 1;
					
					ageUnionWoman := Unions [currUnion - 1].ages[le_union, woman]; 	{toujours}
					ageDeathWoman := Unions [currUnion - 1].ages[le_death, woman];		{PAS toujours}
					ageSeparationWoman := Unions [currUnion - 1].ages[le_endUnion, woman];	{PAS toujours}
					ageWomanAtDeathMan := Unions [currUnion - 1].ages[le_union, woman]	{PAS toujours}
									+ Unions [currUnion - 1].ages[le_death, man]
									- Unions [currUnion - 1].ages[le_union, man];
									
					if ageUnionWoman < ageFinal then
					begin
						if ageDeathWoman > 0 then
						begin
							ageEndUnion := ageDeathWoman;
							if ageWomanAtDeathMan > 0 then
								ageEndUnion := min_real (ageEndUnion, ageWomanAtDeathMan);
						end else {ageDeathWoman <= 0}
						begin
							if ageWomanAtDeathMan > 0 then
								ageEndUnion := ageWomanAtDeathMan
							else
								ageEndUnion := ageFinal;
						end;
						if ageSeparationWoman > 0 then
							ageEndUnion := min_real (ageEndUnion, ageSeparationWoman);
					end;
						
				until ( (currUnion >= nbUnions) or ( ageEndUnion >= ageFinal) );
				
				if ( ageEndUnion >= ageFinal) then
				begin
					if currUnion = 1 then
						partnershipStatusAt50 := firstUnion
					else
						partnershipStatusAt50 := secondUnions;
				end else if (ageSeparationWoman > 0) and (ageSeparationWoman < ageFinal) then
						partnershipStatusAt50 := separated
				else
						partnershipStatusAt50 := widow;
				
			end;
		end;
	end;

	procedure processParity (nbChildren: longint; pChild: pInfoChildType; var finalParity: FinalParityType);
	var
		indEnf: longint;
		pInfoLastChild: pInfoChildType;
		age: longint;
	begin
	
		age := kMinAgeFert;
		indEnf := 0;
		finalParity [indEnf, age, 0] := finalParity [indEnf, age, 0] + 1;
				
		pInfoLastChild := pChild;
		
		while (indEnf < nbChildren) and (indEnf < kMaxNbChildrenCalc) do
		begin
			if pInfoLastChild^.livingAtBirth = true then
			begin
				finalParity [indEnf, age, 1] := finalParity [indEnf, age, 1] + 1;
				indEnf := indEnf + 1;
				age := round (pInfoLastChild^.ageMotherAtChildbirth - 0.5);
				finalParity [indEnf, age, 0] := finalParity [indEnf, age, 0] + 1;
			end;
			pInfoLastChild := pInfoLastChild^.next;
		end;
	end;
	
	procedure addAgeLastChild (nbChildren: longint; var lastChildren: LastChildrenType; pChild: pInfoChildType);
	var
		indEnf: longint;
		pInfoLastChild: pInfoChildType;
		age: longint;
	begin
		if (nbChildren = 0) then
			exit;
			
		pInfoLastChild := pChild;
		if (pInfoLastChild^.livingAtBirth = true) then
			indEnf := 1
		else
			indEnf := 0;
		
		while (indEnf < nbChildren) do
		begin
			pInfoLastChild := pInfoLastChild^.next;
			if pInfoLastChild^.livingAtBirth = true then
				indEnf := indEnf + 1;
		end;
		
		if ( pInfoLastChild^.birthOrder <> nbChildren ) then
		begin
			{Problem}
			writeAndWait ('===> ERROR: pInfoLastChild^.birthOrder <> nbChildren');
		end;
		
		lastChildren.distrib [nbChildren, 1] := lastChildren.distrib [nbChildren, 1] + 1;
		lastChildren.distrib [nbChildren, 2] := lastChildren.distrib [nbChildren, 2] + pInfoLastChild^.ageMotherAtChildbirth;

		age := trunc (pInfoLastChild^.ageMotherAtChildbirth);
		lastChildren.age [age] := lastChildren.age [age] + 1;

		{total}
		lastChildren.distrib [0, 1] := lastChildren.distrib [0, 1] + 1;
		lastChildren.distrib [0, 2] := lastChildren.distrib [0, 2] + pInfoLastChild^.ageMotherAtChildbirth;
	end;				
	
	procedure calcAgeLastChild (var lastChildren: LastChildrenType);
	var
		nEnf: DistribChildren;
		age: FecundAges;
	begin
		for nEnf := 0 to kMaxNbChildren do
			if (lastChildren.distrib [nEnf, 1] > 0) then
				lastChildren.distrib [nEnf, 2] := lastChildren.distrib [nEnf, 2] / lastChildren.distrib [nEnf, 1];
		
		{aggregated}
		for age := kMinAgeFert+1 to kMaxAgeFert do
			lastChildren.Age [age] := lastChildren.Age [age] + lastChildren.Age [age-1];

		{proportion}
		for age := kMinAgeFert to kMaxAgeFert do
			lastChildren.Age [age] := 100.0 * lastChildren.Age [age] / lastChildren.Age [kMaxAgeFert];
	end;			

	procedure addDurationSinceLastEvent (	var durationSinceLastEvent: DurationSincePreviousEventType;
											pChild: pInfoChildType; unionStates: TUnionsType );
	var
		durationInterval: longint;

		currLivingChild, lastLivingChild: pInfoChildType;
		indChild, indChildCalc: longint;
		
	begin
		{premier intervalle}
		if unionStates.nbChildren = 0 then exit;
		
		currLivingChild := pChild;
		while (currLivingChild^.livingAtBirth = false) do
			currLivingChild := currLivingChild^.next;
		
		durationInterval := trunc ( currLivingChild^.ageMotherAtChildbirth - unionStates.Unions [currLivingChild^.motherUnionNumber - 1].ages[le_union, woman] );
		durationInterval := min (durationInterval, 15);
		
		durationSinceLastEvent [1, -1] := durationSinceLastEvent [1, -1] + 1; {Total}
		durationSinceLastEvent [1, durationInterval] := durationSinceLastEvent [1, durationInterval] + 1;
				
		{next intervals}
		indChild := 1;
		lastLivingChild := currLivingChild;
		currLivingChild := currLivingChild^.next;
		while (indChild < unionStates.nbChildren) do
		begin
			if (currLivingChild^.livingAtBirth = true) then
			begin
				indChild := indChild + 1;
				indChildCalc := min (indChild, kMaxNbChildrenCalc);
				
				durationInterval := trunc ( currLivingChild^.ageMotherAtChildbirth - lastLivingChild^.ageMotherAtChildbirth );
				durationInterval := min (durationInterval, 15);

				durationSinceLastEvent [indChildCalc, -1] := durationSinceLastEvent [indChildCalc, -1] + 1; {Total}
				durationSinceLastEvent [indChildCalc, durationInterval] := durationSinceLastEvent [indChildCalc, durationInterval] + 1;

				lastLivingChild := currLivingChild;
			end;
			currLivingChild := currLivingChild^.next;
		end;
	end;
					
	procedure calcDurationSinceLastEvent (	var durationSinceLastEvent: DurationSincePreviousEventType );
	var
		indChild, duration: longint;
	begin
		for indChild := 1 to kMaxNbChildrenCalc do
			if durationSinceLastEvent [indChild, -1] > 0.0 then
				for duration := 0 to 15 do
				begin
					durationSinceLastEvent [indChild, duration] := 100.0 * durationSinceLastEvent [indChild, duration] /
																		durationSinceLastEvent [indChild, -1];
				end;
	end;
	
	procedure writeDebugHeader;
	var
			i: integer;
	begin
		if (g_silentMode) then exit;
		if not g_GENPARAM.DEBUG.value then exit;
		gDebug_indWoman := 0;
		bWrite (gDebugFertFile, ['Woman', tab]);
		bWrite (gDebugFertFile, ['numUnion', tab]);
		bWrite (gDebugFertFile, ['numChildren', tab]);
		bWrite (gDebugFertFile, ['ageSterile', tab]);
		for i:= 1 to 4 do
			bWrite (gDebugFertFile, ['monthStart', i, tab, 'monthStop', i, tab]);
		for i:= 1 to 20 do
			bWrite (gDebugFertFile, ['liveBirth', i, tab, 'monthFecundation', i, tab, 'monthNewOvulation', i, tab]);
		for i:= 1 to 30 do
			bWrite (gDebugFertFile, ['monthStart', i, tab, 'duration', i, tab]);
		cWriteLn (gDebugFertFile);
	end;
	
	procedure writeDebugInfo ( unionStates: TUnionsType; pChild: pInfoChildType );
	var
			i: integer;
	begin
		if not g_GENPARAM.DEBUG.value then exit;
		gDebug_indWoman := gDebug_indWoman + 1;
		bWrite (gDebugFertFile, [gDebug_indWoman, tab]);
		bWrite (gDebugFertFile, [unionStates.nbUnions, tab]);
		bWrite (gDebugFertFile, [unionStates.nbChildren, tab]);
		bWrite (gDebugFertFile, [unionStates.fecundLife.ageSterile, tab]);
		for i:= 1 to 4 do begin
		if unionStates.nbUnions >= i then
			bWrite (gDebugFertFile, [unionStates.Unions [i - 1].monthStart, tab, unionStates.Unions [i - 1].monthStop, tab])
		else
			bWrite (gDebugFertFile, [0, tab, 0, tab]);
		end;
		for i:= 1 to 20 do begin
			if (pChild <> nil) then begin
				if pChild^.livingAtBirth then
					bWrite (gDebugFertFile, [1, tab])
				else
					bWrite (gDebugFertFile, [0, tab]);
				bWrite (gDebugFertFile, [pChild^.monthFecundation, tab, pChild^.monthNewOvulation, tab]);
				pChild := pChild^.next;
			end else begin
				bWrite (gDebugFertFile, [0, tab, 0, tab, 0, tab]);
			end;
		end;
	end;
	
	procedure addIntervals (unionStates: TUnionsType; pChild: pInfoChildType; var intervals: IntervalType);
	var
		durationInterval: double;
		indChild: longint;
		pLastLiveBornChild: pInfoChildType;
		ageQ: ageQuinq;
		
	begin
		if (unionStates.partnershipStatusAt50 = firstUnion) and (unionStates.nbChildren > 0) then
		begin
			ageQ := toAgeQuinq (trunc (unionStates.Unions [0].ages[le_union, woman]));
			
			{We have the number of women in the interval 0}
			intervals [ageQ, unionStates.nbChildren, 0] := intervals [ageQ, unionStates.nbChildren, 0] + 1;
			intervals [ftotal, unionStates.nbChildren, 0] := intervals [ftotal, unionStates.nbChildren, 0] + 1;

			{first interval}
			gotoToFirstLiveBornChild(pChild);
			
			durationInterval := pChild^.ageMotherAtChildbirth - unionStates.Unions [0].ages[le_union, woman];
			intervals [ageQ, unionStates.nbChildren, 1] := intervals [ageQ, unionStates.nbChildren, 1] + durationInterval;
			intervals [ftotal, unionStates.nbChildren, 1] := intervals [ftotal, unionStates.nbChildren, 1] + durationInterval;
			
			{next intervals}
			indChild := 1;
			while (indChild < unionStates.nbChildren) do
			begin
				indChild := indChild + 1;
				pLastLiveBornChild := pChild;
				gotoToNextLiveBornChild(pChild);
				durationInterval := pChild^.ageMotherAtChildbirth - pLastLiveBornChild^.ageMotherAtChildbirth;
				intervals [ageQ, unionStates.nbChildren, indChild] := intervals [ageQ, unionStates.nbChildren, indChild] + durationInterval;
				intervals [ftotal, unionStates.nbChildren, indChild] := intervals [ftotal, unionStates.nbChildren, indChild] + durationInterval;
			end;
		end;
	end;
					
	procedure calcIntervals (var intervals: IntervalType);
	var
		indChild, intervalle: longint;
		ageQ: ageQuinq;
	begin
		for indChild := 1 to kMaxNbChildrenCalc do
			for ageQ := f1519 to ftotal do
				if intervals [ageQ, indChild, 0] > 0.0 then
					for intervalle := 1 to kMaxNbChildrenCalc do
					begin
						intervals [ageQ, indChild, intervalle] := intervals [ageQ, indChild, intervalle] / intervals [ageQ, indChild, 0];
					end;
	end;

	function multipleBirths ( age: FecundAges ): longint;
{Number of live births for this childbirth}
	begin
		multipleBirths := 1; {Only one at the moment}
	end;

	procedure calcFertility_NC (const distNC: array of longint; out TFR, VARIANCE: double);
	var
		indChild, nbWomen: longint;
	begin
		TFR := 0;
        VARIANCE := 0;
		nbWomen := 0;
		for indChild := 0 to kMaxNbChildren do begin
			nbWomen := nbWomen + distNC [indChild];
			TFR := TFR + distNC [indChild] * indChild;
			VARIANCE := VARIANCE + distNC [indChild] * indChild * indChild;
		end;
		TFR := TFR / nbWomen;
		VARIANCE := VARIANCE / nbWomen - TFR * TFR;
	end;
end.
