{$I Defines.pas}
unit Fertility;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, RandomNumbers, Utilities, Verification, Math, SysUtils, Memory
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
	procedure betaHeterogeneityFecundability (alpha, beta: double);

	procedure resetFecundabilityCheck;
	procedure reportFecundabilityCheck;
	function definitiveSterilityModelName: string;
	function intrauterineRiskModelName: string;
	function stillbirthRiskModelName: string;

	procedure init_temporary_sterility (p: pStructDemographicRegimeSettings; alpha, beta: double);
	{This was declared as a function returning the median of the distribution, but the
	 result was never set, so what the caller read was whatever the return register held.
	 None of the six call sites used the value. It is now a procedure. The median can be
	 recovered from arrayDurationAcc, which holds the accumulated distribution, if it is
	 ever wanted.}
	procedure init_waiting_time_distribution (
			maxDuration: longint;
			var arrayDurationAcc: array of double;
			mean, propContraception: double;
			lambda_erlang: double = 1);
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

const
	{How far the mean a waiting time distribution delivers may stand from the mean asked for,
	 in years, before chk_fer_waitingTimeMean counts it a failure. The distribution is built on
	 whole lunar months and is cut off at the end of its array, so the two cannot agree exactly;
	 measured over the ranges the program uses, the gap is under a thousandth of a year. Twenty
	 thousandths leaves room for a long mean in a short array and still catches an error of the
	 kind the rate used to cause, which was a factor of more than three.}
	kWaitingTimeMeanTolerance = 0.02;

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
	{Gergő Nemes's approximation. No longer used by the Erlang waiting time, which works with
	 the logarithm of the gamma function instead, but left here since it is a general routine.}
	var
		res: double;
	begin
		res := 0.5 * ( ln (2* pi) - ln (z) ) + z * ( ln ( z + 1 / ( 12 * z - 1 / (10 * z) ) ) - 1);
		result := exp (res);
	end;

	function lnGammaFn (z: double): double;
	{The logarithm of the gamma function, by the Lanczos approximation with g = 7 and nine
	 coefficients, which holds about fifteen significant digits for a positive argument. The
	 logarithm rather than the function itself, because the incomplete gamma below needs it
	 inside an exponential and Gamma (z) itself passes the range of a double at z = 171.}
	const
		kLanczos_g = 7.0;
		kLanczos: array [0..8] of double = (
			0.99999999999980993, 676.5203681218851, -1259.1392167224028,
			771.32342877765313, -176.61502916214059, 12.507343278686905,
			-0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7);
	var
		x, t, sum: double;
		i: longint;
	begin
		x := z - 1.0;
		sum := kLanczos [0];
		for i := 1 to 8 do
			sum := sum + kLanczos [i] / (x + i);
		t := x + kLanczos_g + 0.5;
		result := 0.5 * ln (2 * pi) + (x + 0.5) * ln (t) - t + ln (sum);
	end;

	function gammaP (a, x: double): double;
	{The regularised lower incomplete gamma function, that is the distribution function of a
	 gamma variate of shape a and rate one evaluated at x. The series below converges quickly
	 for x under a + 1 and the continued fraction for x above it, which is the standard
	 division; both are written in logarithms, so no intermediate can overflow.

	 It is here so that the Erlang waiting time can be written as a distribution function
	 rather than as a sum of densities: the array then needs no normalisation, since it is a
	 distribution function by construction.

	 Checked against three closed forms to twelve decimals: P(1, x) = 1 - exp(-x),
	 P(2, x) = 1 - (1 + x) exp(-x), and P(0.5, x) = erf(sqrt(x)).}
	const
		kMaxIterations = 300;
		kRelativeAccuracy = 3.0e-14;
		kTinyDouble = 1.0e-300;
	var
		ap, del, sum, b, c, d, h, an: double;
		i: longint;
	begin
		result := 0.0;
		if (x <= 0.0) or (a <= 0.0) then exit;
		if (x < a + 1.0) then begin
			{series}
			ap := a;
			del := 1.0 / a;
			sum := del;
			for i := 1 to kMaxIterations do begin
				ap := ap + 1.0;
				del := del * x / ap;
				sum := sum + del;
				if (abs (del) < abs (sum) * kRelativeAccuracy) then break;
			end;
			result := sum * exp (-x + a * ln (x) - lnGammaFn (a));
		end else begin
			{continued fraction, in the modified Lentz form, for the complement}
			b := x + 1.0 - a;
			c := 1.0 / kTinyDouble;
			d := 1.0 / b;
			h := d;
			for i := 1 to kMaxIterations do begin
				an := -i * (i - a);
				b := b + 2.0;
				d := an * d + b;
				if (abs (d) < kTinyDouble) then d := kTinyDouble;
				c := b + an / c;
				if (abs (c) < kTinyDouble) then c := kTinyDouble;
				d := 1.0 / d;
				del := d * c;
				h := h * del;
				if (abs (del - 1.0) < kRelativeAccuracy) then break;
			end;
			result := 1.0 - exp (-x + a * ln (x) - lnGammaFn (a)) * h;
		end;
		{rounding can put the result a hair outside its range}
		if (result < 0.0) then result := 0.0;
		if (result > 1.0) then result := 1.0;
	end;
	
	procedure init_waiting_time_distribution_Erlang (maxDuration: longint; var arrayDurationAcc: array of double; mean, propContraception: double; lambda: double = 1);
	var
		k: double;
		i: longint;
		last: double;
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

			{**The Erlang waiting time, rewritten.** Three faults are corrected, and the array is
			 built as a distribution function rather than as an accumulated sum of densities, so
			 that it needs no normalisation.

			 (a) The shape now carries the rate. An Erlang of shape k and rate lambda has mean
			 k / lambda, and k was set from the mean alone. The two repartnering calls in
			 Nuptiality pass lambda = 0.3, so those two distributions had a mean 1 / 0.3, that
			 is 3.33 times, larger than the value the user asked for: a mean of 5 years was
			 delivered as 16.7. The five calls in DemographicRegime pass the default lambda = 1
			 and were right for that reason alone.

			 (b) No term is evaluated at zero. The old line called power (i, k - 1) at i = 0,
			 which is zero raised to a negative power for a shape below one, and zero raised to
			 zero for the exponential case. Nothing is evaluated at a point now: each cell is
			 the distribution function at the upper edge of the month it stands for.

			 (c) No normalisation, and none needed. The old code summed the DENSITY at each
			 whole month and then forced the last cell to 1. A sum of densities is not a sum of
			 probabilities: for a small shape it passes 1 well before the end of the array, so
			 the cumulative curve saturated early and the tail of the distribution was dead. A
			 mean of three months came out as three and a half. Each cell now holds
			 P(k, lambda * (i + 0.5)), the probability that the wait is nearer to i months than
			 to any other whole number, accumulated by construction and bounded by 1. The last
			 cell is still forced to 1, which puts the tail beyond the end of the array into the
			 last month, exactly as the Poisson version above does.

			 What it changes in practice. With lambda = 1 the two forms agree: the delivered mean
			 was already the mean asked for and the largest gap between the two cumulative curves
			 is 0.001, so the contraception and spacing distributions barely move. Repartnering
			 moves by the factor of 3.33.}
			k := mean * kNbLunarMonths * lambda;
			for i := 0 to maxDuration do
				arrayDurationAcc [i] := gammaP (k, lambda * (i + 0.5));

			{the mean the array actually delivers, in years, read against the mean asked for}
			mean_check := 0.0;
			last := 0.0;
			for i := 0 to maxDuration do begin
				mean_check := mean_check + i * (arrayDurationAcc [i] - last);
				last := arrayDurationAcc [i];
			end;
			mean_check := mean_check / kNbLunarMonths;
			checkValue (chk_fer_waitingTimeMean, mean_check, mean, kWaitingTimeMeanTolerance);

			arrayDurationAcc [maxDuration] := 1.0;
		end;
	end;
	

	procedure init_waiting_time_distribution (
			maxDuration: longint;
			var arrayDurationAcc: array of double;
			mean, propContraception: double;
			lambda_erlang: double = 1);
	{the two local variables of the earlier function, ind and median, were never used}
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
		
		for i := kMinAgeFert to kMaxAgeFert do
			gFecundability[i] := gFecundability[i] * 12 / kNbLunarMonths;
	end;
	
	{ --------------------------------------------------------------------------------
	  Verification of the fecundability heterogeneity model

	  resetFecundabilityCheck empties the histogram of drawn levels and is called at the
	  end of every rebuild of gDistrib_fecundability, so that the counts always refer to
	  the distribution in force. fecundabilityLevel then counts each draw, and
	  reportFecundabilityCheck compares the simulated distribution with the theoretical
	  one at the end of the run.

	  The check always runs. It costs one atomic increment per draw, which is about five
	  nanoseconds more than an ordinary increment, so a run drawing ten million levels
	  spends some fifty milliseconds on it. The increment has to be atomic: fecundabilityLevel
	  is called from the cohort worker threads. Only the two dump files are kept for runs
	  from the IDE, since they are written into the results folder; the summary in the memo
	  and gDistrib_fecundability_simulated, which the graph window plots against the
	  theoretical curve, are produced on every run.

	  What the comparison can and cannot show. The simulated histogram is compared with
	  the distribution stored in gDistrib_fecundability, so it verifies the inverse-CDF
	  sampler and the random number generator. It cannot verify the formula that built
	  gDistrib_fecundability, since that array is at once the source of the draws and the
	  standard of comparison. The report therefore also gives the mean and the standard
	  deviation of the built grid itself, which can be read against the parameters
	  requested from normalHeterogeneityFecundability or betaHeterogeneityFecundability.
	  For the normal the two will not agree exactly: the grid is truncated at p = 0,
	  which raises the mean and lowers the standard deviation, so 0.23 and 0.12 become
	  about 0.238 and 0.112. For the beta they should agree to the precision of the grid.

	  On the index: the sampler returns the smallest i in [1, kMaxDistribFecundability]
	  whose cumulative value reaches the draw, so the theoretical probability of i = 1 is
	  gDistrib_fecundability[1], which absorbs cell 0, and that of i > 1 is the difference
	  between two consecutive cumulative values. The theoretical column below is built
	  that way, so a correct sampler shows no gap at the first cell.
	  -------------------------------------------------------------------------------- }
	procedure resetFecundabilityCheck;
		var
			i: longint;
	begin
		for i := 0 to kMaxDistribFecundability do begin
			gCount_fecundability_draws [i] := 0;
			gDistrib_fecundability_simulated [i] := 0.0;
		end;
		gHasObserved_fecundability := false;
	end;

	procedure reportFecundabilityCheck;
		var
			i, nDraws: longint;
			theoretical: array [0..kMaxDistribFecundability] of double;
			p, w: double;
			meanSim, meanThe, sdSim, sdThe: double;
			sumSqSim, sumSqThe: double;
			cumSim, cumThe, gap, maxGap, pAtMaxGap: double;
	begin
		nDraws := 0;
		for i := 0 to kMaxDistribFecundability do
			nDraws := nDraws + gCount_fecundability_draws [i];

		if (nDraws = 0) then begin
			memoWriteLn (['Fecundability heterogeneity check: no draw recorded. Either no woman ',
				'was simulated, or the fixed parameter homogeneousFecundability is set.']);
			exit;
		end;

		{probability of each index, as the sampler sees it}
		theoretical [0] := 0.0;
		theoretical [1] := gDistrib_fecundability [1];
		for i := 2 to kMaxDistribFecundability do
			theoretical [i] := gDistrib_fecundability [i] - gDistrib_fecundability [i-1];

		{the verdict goes into the verification table; the lines below stay in the memo
		 because they carry the demography rather than the statistic}
		checkDistribution (chk_fecundabilityDraws, gCount_fecundability_draws, theoretical);

		meanSim := 0.0; meanThe := 0.0; sumSqSim := 0.0; sumSqThe := 0.0;
		for i := 0 to kMaxDistribFecundability do begin
			p := 1.0 * i / kMaxDistribFecundability;
			w := gCount_fecundability_draws [i] / nDraws;
			gDistrib_fecundability_simulated [i] := w;
			gHasObserved_fecundability := true;
			meanSim := meanSim + w * p;
			sumSqSim := sumSqSim + w * p * p;
			meanThe := meanThe + theoretical [i] * p;
			sumSqThe := sumSqThe + theoretical [i] * p * p;
		end;
		sdSim := sqrt (max (0.0, sumSqSim - meanSim * meanSim));
		sdThe := sqrt (max (0.0, sumSqThe - meanThe * meanThe));

		{largest distance between the two cumulative distributions}
		cumSim := 0.0; cumThe := 0.0; maxGap := 0.0; pAtMaxGap := 0.0;
		for i := 0 to kMaxDistribFecundability do begin
			cumSim := cumSim + gDistrib_fecundability_simulated [i];
			cumThe := cumThe + theoretical [i];
			gap := abs (cumSim - cumThe);
			if (gap > maxGap) then begin
				maxGap := gap;
				pAtMaxGap := 1.0 * i / kMaxDistribFecundability;
			end;
		end;

		memoWriteLn (['--- Fecundability heterogeneity check ---']);
		memoWriteLn (['Draws recorded: ', nDraws]);
		memoWriteLn (['Theoretical grid in force: mean ', meanThe, ', standard deviation ', sdThe]);
		memoWriteLn (['Parameters requested: mean ', gMean_fecundability, ', standard deviation ',
			gStdDev_fecundability, ' (normal); alpha ', gFecundability_alpha, ', beta ', gFecundability_beta, ' (beta)']);
		memoWriteLn (['Simulated women: mean ', meanSim, ', standard deviation ', sdSim]);
		memoWriteLn (['Mean multiplier applied to gFecundability: simulated ', meanSim / gMean_fecundability,
			', theoretical ', meanThe / gMean_fecundability, '. The two agree when the sampler is unbiased. ',
			'Both are above 1 when the grid is truncated, which is the case for a normal centred on 0.23.']);
		memoWriteLn (['Largest gap between the simulated and the theoretical cumulative distribution: ',
			maxGap, ' at fecundability ', pAtMaxGap]);
		memoWriteLn (['Kolmogorov-Smirnov 5 per cent band for this number of draws: ', 1.36 / sqrt (1.0 * nDraws),
			'. With several million draws that band is very narrow, so read the size of the gap itself.']);

		{written only from the IDE, like the other dumps in this unit, to keep them out of
		 the results folder of an ordinary run}
		if gRunFromIDE then begin
			dumpArray ('fecundability_simulated', gDistrib_fecundability_simulated);
			dumpArray ('fecundability_theoretical', theoretical);
		end;
	end;

	function definitiveSterilityModelName: string;
	{Which of the three models wrote gDefinitive_sterility for this run. All three write the
	 same array, and both the draw and the check read that array, so the comparison is always
	 against the model actually in use. This is for the chart title.}
	begin
		if g_GENPARAM.fixedParameters [LeridonDefinitiveSterility].state.value then
			result := 'Leridon'
		else if g_GENPARAM.fixedParameters [KinFertDefinitiveSterility].state.value then
			result := 'KinFert'
		else
			result := 'Pittinger and Wood';
		if g_GENPARAM.fixedParameters [noInitialSterility].state.value then
			result := result + ', no initial sterility';
		if g_GENPARAM.fixedParameters [fixedDefinitiveSterility].state.value then
			result := result + ', fixed after age ' +
					IntToStr (round (g_GENPARAM.fixedParameters [fixedDefinitiveSterility].param.value));
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
		
		if gRunFromIDE then
			dumpArray ('gDistrib_fecundability_beta', gDistrib_fecundability);

		// cumulative function
		for i := 1 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] + gDistrib_fecundability [i-1];
		
		gDistrib_fecundability [kMaxDistribFecundability] := 1.0;
		
		initFecundability ();
		resetFecundabilityCheck;
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

		if gRunFromIDE then
			dumpArray ('gDistrib_fecundability_normal', gDistrib_fecundability);

		// cumulative function
		for i := 1 to kMaxDistribFecundability do
			gDistrib_fecundability [i] := gDistrib_fecundability [i] + gDistrib_fecundability [i-1];

		gDistrib_fecundability [kMaxDistribFecundability] := 1.0;

		initFecundability ();
		resetFecundabilityCheck;
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

		initFecundability ();
	end;
	
	procedure initFertilityModel;
		var
			ageWomen: FecundAges;
			i: longint;
	begin
		{Pittinger / Wood}
		for ageWomen := kMinAgeFert to kMaxAgeFert do
			gDefinitive_sterility_PW[ageWomen] := 1 - exp(0.00043 * (1 - power (1.14345, ageWomen - 5.67)) / ln (1.14345) );
		gDefinitive_sterility_PW[kMaxAgeFert] := 1.0;
		gDefinitive_sterility := copy (gDefinitive_sterility_PW);
		{Kinfert}
		gDefinitive_sterility_Kinfert[10] := 0.01;
		gDefinitive_sterility_Kinfert[11] := 0.0115;
		gDefinitive_sterility_Kinfert[12] := 0.013;
		gDefinitive_sterility_Kinfert[13] := 0.0145;
		gDefinitive_sterility_Kinfert[14] := 0.016;
		gDefinitive_sterility_Kinfert[15] := 0.0175;
		gDefinitive_sterility_Kinfert[16] := 0.019;
		gDefinitive_sterility_Kinfert[17] := 0.0205;
		gDefinitive_sterility_Kinfert[18] := 0.022;
		gDefinitive_sterility_Kinfert[19] := 0.0235;
		gDefinitive_sterility_Kinfert[20] := 0.025;
		gDefinitive_sterility_Kinfert[21] := 0.0265;
		gDefinitive_sterility_Kinfert[22] := 0.028;
		gDefinitive_sterility_Kinfert[23] := 0.0295;
		gDefinitive_sterility_Kinfert[24] := 0.031;
		gDefinitive_sterility_Kinfert[25] := 0.0325;
		gDefinitive_sterility_Kinfert[26] := 0.035;
		gDefinitive_sterility_Kinfert[27] := 0.03722199;
		gDefinitive_sterility_Kinfert[28] := 0.040377765;
		gDefinitive_sterility_Kinfert[29] := 0.045386742;
		gDefinitive_sterility_Kinfert[30] := 0.05167339;
		gDefinitive_sterility_Kinfert[31] := 0.060726363;
		gDefinitive_sterility_Kinfert[32] := 0.073012125;
		gDefinitive_sterility_Kinfert[33] := 0.088836923;
		gDefinitive_sterility_Kinfert[34] := 0.108178073;
		gDefinitive_sterility_Kinfert[35] := 0.131531607;
		gDefinitive_sterility_Kinfert[36] := 0.159840247;
		gDefinitive_sterility_Kinfert[37] := 0.192559791;
		gDefinitive_sterility_Kinfert[38] := 0.227886378;
		gDefinitive_sterility_Kinfert[39] := 0.264109658;
		gDefinitive_sterility_Kinfert[40] := 0.3;
		gDefinitive_sterility_Kinfert[41] := 0.335109658;
		gDefinitive_sterility_Kinfert[42] := 0.371886378;
		gDefinitive_sterility_Kinfert[43] := 0.416559791;
		gDefinitive_sterility_Kinfert[44] := 0.496840247;
		gDefinitive_sterility_Kinfert[45] := 0.626531607;
		gDefinitive_sterility_Kinfert[46] := 0.751178073;
		gDefinitive_sterility_Kinfert[47] := 0.838836923;
		gDefinitive_sterility_Kinfert[48] := 0.899012125;
		gDefinitive_sterility_Kinfert[49] := 0.931726363;
		gDefinitive_sterility_Kinfert[50] := 0.95067339;
		gDefinitive_sterility_Kinfert[51] := 0.965386742;
		gDefinitive_sterility_Kinfert[52] := 0.978377765;
		gDefinitive_sterility_Kinfert[53] := 0.99022199;
		gDefinitive_sterility_Kinfert[54] := 0.996;
		gDefinitive_sterility_Kinfert[55] := 0.997;
		gDefinitive_sterility_Kinfert[56] := 0.998;
		gDefinitive_sterility_Kinfert[57] := 0.9985;
		gDefinitive_sterility_Kinfert[58] := 0.9991;
		gDefinitive_sterility_Kinfert[59] := 1;
		{Leridon 2008}
		gDefinitive_sterility_Leridon[10] := 0.01;
		gDefinitive_sterility_Leridon[11] := 0.01;
		gDefinitive_sterility_Leridon[12] := 0.01;
		gDefinitive_sterility_Leridon[13] := 0.01;
		gDefinitive_sterility_Leridon[14] := 0.01;
		gDefinitive_sterility_Leridon[15] := 0.01;
		gDefinitive_sterility_Leridon[16] := 0.01;
		gDefinitive_sterility_Leridon[17] := 0.01;
		gDefinitive_sterility_Leridon[18] := 0.01;
		gDefinitive_sterility_Leridon[19] := 0.01;
		gDefinitive_sterility_Leridon[20] := 0.01;
		gDefinitive_sterility_Leridon[21] := 0.01;
		gDefinitive_sterility_Leridon[22] := 0.01;
		gDefinitive_sterility_Leridon[23] := 0.01;
		gDefinitive_sterility_Leridon[24] := 0.01;
		gDefinitive_sterility_Leridon[25] := 0.01;
		gDefinitive_sterility_Leridon[26] := 0.011;
		gDefinitive_sterility_Leridon[27] := 0.012;
		gDefinitive_sterility_Leridon[28] := 0.014;
		gDefinitive_sterility_Leridon[29] := 0.017;
		gDefinitive_sterility_Leridon[30] := 0.02;
		gDefinitive_sterility_Leridon[31] := 0.024;
		gDefinitive_sterility_Leridon[32] := 0.029;
		gDefinitive_sterility_Leridon[33] := 0.035;
		gDefinitive_sterility_Leridon[34] := 0.042;
		gDefinitive_sterility_Leridon[35] := 0.051;
		gDefinitive_sterility_Leridon[36] := 0.064;
		gDefinitive_sterility_Leridon[37] := 0.082;
		gDefinitive_sterility_Leridon[38] := 0.105;
		gDefinitive_sterility_Leridon[39] := 0.133;
		gDefinitive_sterility_Leridon[40] := 0.166;
		gDefinitive_sterility_Leridon[41] := 0.204;
		gDefinitive_sterility_Leridon[42] := 0.249;
		gDefinitive_sterility_Leridon[43] := 0.306;
		gDefinitive_sterility_Leridon[44] := 0.401;
		gDefinitive_sterility_Leridon[45] := 0.546;
		gDefinitive_sterility_Leridon[46] := 0.685;
		gDefinitive_sterility_Leridon[47] := 0.785;
		gDefinitive_sterility_Leridon[48] := 0.855;
		gDefinitive_sterility_Leridon[49] := 0.895;
		gDefinitive_sterility_Leridon[50] := 0.919;
		gDefinitive_sterility_Leridon[51] := 0.937;
		gDefinitive_sterility_Leridon[52] := 0.952;
		gDefinitive_sterility_Leridon[53] := 0.965;
		gDefinitive_sterility_Leridon[54] := 0.976;
		gDefinitive_sterility_Leridon[55] := 0.985;
		gDefinitive_sterility_Leridon[56] := 0.991;
		gDefinitive_sterility_Leridon[57] := 0.996;
		gDefinitive_sterility_Leridon[58] := 0.999;
		gDefinitive_sterility_Leridon[59] := 1;

		{-------- intrauterine mortality risk by age: two alternative schedules --------}
		{Léridon 2004, rétropolé et extrapolé par ajustement d'un polynome du troisième degré.
		 A cubic cannot reproduce the J shape: it has no minimum, it runs about 35 per cent
		 above the observed level through the twenties, and it understates the near
		 exponential rise after 38 (0.315 against 0.536 at age 45).}
		for ageWomen := kMinAgeFert to kMaxAgeFert do
			gIntrauterine_mortality_risk_Leridon[ageWomen] := 0.05091517857 + 0.0093172619 * ageWomen - 0.00046642857 * ageWomen * ageWomen + 0.00000866667 * ageWomen * ageWomen * ageWomen;
		gIntrauterine_mortality_risk_Leridon[kMaxAgeFert] := 1.0;

		{Magnus, Wilcox, Morken, Weinberg and Haberg (2019), BMJ 364:l869: the whole Norwegian
		 register 2009-2013, 421,201 pregnancies, risk of miscarriage by maternal age, overall
		 12.8 per cent. Anchors at the published group midpoints (15.8 per cent under 20, 11.2
		 at 20-24, 9.8 at 25-29 with the minimum 9.5 at age 27, 10.8 at 30-34, 16.7 at 35-39,
		 32.2 at 40-44, 53.6 at 45 and over), interpolated by single year of age with a
		 monotone cubic on the logit scale. Held flat below 18, where the source has one open
		 group only. These are CLINICALLY RECOGNISED pregnancies, the same basis as the
		 fecundability parameter, so the two are consistent.}
		gIntrauterine_mortality_risk_Magnus[10] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[11] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[12] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[13] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[14] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[15] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[16] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[17] := 0.170000;
		gIntrauterine_mortality_risk_Magnus[18] := 0.162464;
		gIntrauterine_mortality_risk_Magnus[19] := 0.152626;
		gIntrauterine_mortality_risk_Magnus[20] := 0.139453;
		gIntrauterine_mortality_risk_Magnus[21] := 0.126146;
		gIntrauterine_mortality_risk_Magnus[22] := 0.115582;
		gIntrauterine_mortality_risk_Magnus[23] := 0.109116;
		gIntrauterine_mortality_risk_Magnus[24] := 0.103684;
		gIntrauterine_mortality_risk_Magnus[25] := 0.099186;
		gIntrauterine_mortality_risk_Magnus[26] := 0.096131;
		gIntrauterine_mortality_risk_Magnus[27] := 0.095000;
		gIntrauterine_mortality_risk_Magnus[28] := 0.095666;
		gIntrauterine_mortality_risk_Magnus[29] := 0.097512;
		gIntrauterine_mortality_risk_Magnus[30] := 0.100326;
		gIntrauterine_mortality_risk_Magnus[31] := 0.103897;
		gIntrauterine_mortality_risk_Magnus[32] := 0.108000;
		gIntrauterine_mortality_risk_Magnus[33] := 0.113974;
		gIntrauterine_mortality_risk_Magnus[34] := 0.123155;
		gIntrauterine_mortality_risk_Magnus[35] := 0.135305;
		gIntrauterine_mortality_risk_Magnus[36] := 0.150098;
		gIntrauterine_mortality_risk_Magnus[37] := 0.167000;
		gIntrauterine_mortality_risk_Magnus[38] := 0.187646;
		gIntrauterine_mortality_risk_Magnus[39] := 0.214112;
		gIntrauterine_mortality_risk_Magnus[40] := 0.246043;
		gIntrauterine_mortality_risk_Magnus[41] := 0.282534;
		gIntrauterine_mortality_risk_Magnus[42] := 0.322000;
		gIntrauterine_mortality_risk_Magnus[43] := 0.362727;
		gIntrauterine_mortality_risk_Magnus[44] := 0.405641;
		gIntrauterine_mortality_risk_Magnus[45] := 0.452820;
		gIntrauterine_mortality_risk_Magnus[46] := 0.506340;
		gIntrauterine_mortality_risk_Magnus[47] := 0.568107;
		gIntrauterine_mortality_risk_Magnus[48] := 0.638548;
		gIntrauterine_mortality_risk_Magnus[49] := 0.711528;
		gIntrauterine_mortality_risk_Magnus[50] := 0.780000;
		gIntrauterine_mortality_risk_Magnus[51] := 0.798000;
		gIntrauterine_mortality_risk_Magnus[52] := 0.816000;
		gIntrauterine_mortality_risk_Magnus[53] := 0.834000;
		gIntrauterine_mortality_risk_Magnus[54] := 0.852000;
		gIntrauterine_mortality_risk_Magnus[55] := 0.870000;
		gIntrauterine_mortality_risk_Magnus[56] := 0.888000;
		gIntrauterine_mortality_risk_Magnus[57] := 0.906000;
		gIntrauterine_mortality_risk_Magnus[58] := 0.924000;
		gIntrauterine_mortality_risk_Magnus[kMaxAgeFert] := 1.0;

		{-------- stillbirth risk by age: two alternative schedules --------}
		{Barrett 1971, linear and monotone. The level at age 30 is plausible for a historical
		 population; the shape is not, since the observed curve is J shaped with a minimum
		 around 27 and an elevation below 20.}
		for i := kMinAgeFert to kMaxAgeFert do
			gStillbirth_mortality_risk_Barrett[i] := 0.03 + 0.001 * (i - 30);
		gStillbirth_mortality_risk_Barrett[kMaxAgeFert] := 1.0;

		{National Center for Health Statistics, Fetal Mortality: United States, 2023, National
		 Vital Statistics Reports 74(8): fetal deaths at 20 weeks or more per 1,000 live births
		 plus fetal deaths, by maternal age (6.91 at 15-19, 5.51 at 20-24, 5.07 at 25-29, 5.15
		 at 30-34, 5.86 at 35-39, 8.36 at 40-44, 13.25 at 45 and over). The SHAPE only is taken
		 from that source and rescaled so that age 30 keeps Barrett's 3.0 per cent, which is a
		 plausible historical level; modern absolute rates are several times lower. Part of the
		 elevation below 20 in the United States is social rather than obstetric, so that end of
		 the curve is the least certain.}
		gStillbirth_mortality_risk_US2023[10] := 0.040638;
		gStillbirth_mortality_risk_US2023[11] := 0.040638;
		gStillbirth_mortality_risk_US2023[12] := 0.040638;
		gStillbirth_mortality_risk_US2023[13] := 0.040638;
		gStillbirth_mortality_risk_US2023[14] := 0.040638;
		gStillbirth_mortality_risk_US2023[15] := 0.040638;
		gStillbirth_mortality_risk_US2023[16] := 0.040638;
		gStillbirth_mortality_risk_US2023[17] := 0.040638;
		gStillbirth_mortality_risk_US2023[18] := 0.038583;
		gStillbirth_mortality_risk_US2023[19] := 0.036778;
		gStillbirth_mortality_risk_US2023[20] := 0.035220;
		gStillbirth_mortality_risk_US2023[21] := 0.033909;
		gStillbirth_mortality_risk_US2023[22] := 0.032844;
		gStillbirth_mortality_risk_US2023[23] := 0.031992;
		gStillbirth_mortality_risk_US2023[24] := 0.031184;
		gStillbirth_mortality_risk_US2023[25] := 0.030488;
		gStillbirth_mortality_risk_US2023[26] := 0.030001;
		gStillbirth_mortality_risk_US2023[27] := 0.029817;
		gStillbirth_mortality_risk_US2023[28] := 0.029839;
		gStillbirth_mortality_risk_US2023[29] := 0.029901;
		gStillbirth_mortality_risk_US2023[30] := 0.030000;
		gStillbirth_mortality_risk_US2023[31] := 0.030130;
		gStillbirth_mortality_risk_US2023[32] := 0.030287;
		gStillbirth_mortality_risk_US2023[33] := 0.030621;
		gStillbirth_mortality_risk_US2023[34] := 0.031250;
		gStillbirth_mortality_risk_US2023[35] := 0.032131;
		gStillbirth_mortality_risk_US2023[36] := 0.033218;
		gStillbirth_mortality_risk_US2023[37] := 0.034463;
		gStillbirth_mortality_risk_US2023[38] := 0.036171;
		gStillbirth_mortality_risk_US2023[39] := 0.038618;
		gStillbirth_mortality_risk_US2023[40] := 0.041702;
		gStillbirth_mortality_risk_US2023[41] := 0.045284;
		gStillbirth_mortality_risk_US2023[42] := 0.049165;
		gStillbirth_mortality_risk_US2023[43] := 0.053411;
		gStillbirth_mortality_risk_US2023[44] := 0.058312;
		gStillbirth_mortality_risk_US2023[45] := 0.063959;
		gStillbirth_mortality_risk_US2023[46] := 0.070456;
		gStillbirth_mortality_risk_US2023[47] := 0.077924;
		gStillbirth_mortality_risk_US2023[48] := 0.082599;
		gStillbirth_mortality_risk_US2023[49] := 0.087275;
		gStillbirth_mortality_risk_US2023[50] := 0.091950;
		gStillbirth_mortality_risk_US2023[51] := 0.096625;
		gStillbirth_mortality_risk_US2023[52] := 0.101301;
		gStillbirth_mortality_risk_US2023[53] := 0.105976;
		gStillbirth_mortality_risk_US2023[54] := 0.110652;
		gStillbirth_mortality_risk_US2023[55] := 0.115327;
		gStillbirth_mortality_risk_US2023[56] := 0.120003;
		gStillbirth_mortality_risk_US2023[57] := 0.124678;
		gStillbirth_mortality_risk_US2023[58] := 0.129353;
		gStillbirth_mortality_risk_US2023[kMaxAgeFert] := 1.0;

		{The working arrays. The defaults are the newer schedules, Magnus for intrauterine
		 mortality and the United States 2023 shape for stillbirth. INTRA_LERIDON_MAGNUS and
		 STILLBIRTH_BARRETT_US2023 put the older Léridon and Barrett schedules back, so a
		 ticked box means the earlier behaviour and an unticked box the current evidence.}
		gIntrauterine_mortality_risk := copy (gIntrauterine_mortality_risk_Magnus);
		gStillbirth_mortality_risk := copy (gStillbirth_mortality_risk_US2023);

		{Barrett (1971), Demography 8(4):481-490, p.482, verbatim: "The gestation interval
		 preceding a foetal death is geometrically distributed. Twenty-four per cent of
		 conceptions end in foetal deaths. The program causes the probability of foetal death
		 to increase from 0.11 in the second month of gestation to Pn = P(n-1) x 0.55 in the
		 nth month (3 <= n <= 8), losses in the first month being regarded as equivalent to
		 reduced fecundability."

		 So the index runs from 2 to 8, SEVEN values, and there is deliberately no first
		 month: losses before the end of the first month of gestation are absorbed into
		 fecundability, which is also what keeps this schedule on the same basis as the
		 fecundability parameter. Barrett's absolute values 0.11 x 0.55^k for k = 0 to 6 sum
		 to 0.2407, the 24 per cent of conceptions he quotes, so they are per-conception
		 probabilities; normalised over the seven terms the first is 0.45 / (1 - 0.55^7).

		 Until 9 September 2026 this table held eight values at indices 1 to 8, normalised
		 over eight terms as 0.45 / (1 - 0.55^8) = 0.453799845, so every share sat one month
		 earlier than Barrett intended and an eighth month was invented. Because
		 durationPregnancyInMonths is used directly as a duration in AbortionOrStillBorn, the
		 mean month of loss was 2.1547 against Barrett's 3.1140, and every spontaneous
		 abortion shortened the non-susceptible period by 0.96 of a month. Indices 0 and 1 are
		 left at zero, and the search in FertilityRuntime.pas now starts at 2.

		 Two points from the same page that are NOT addressed here, and remain open:
		   1. Barrett's month is a lunar month, "13 months to a year, a definition that
		      applies here wherever months refers to the simulation" (p.481). kNbLunarMonths
		      is 12, so these are calendar months and the schedule is stretched by 13/12.
		   2. kLivingBirth_durationPregnancyInMonths = kNbLunarMonths - 3 gives Barrett's 10
		      lunar months for a live birth only when kNbLunarMonths is 13. With 12 it gives
		      9, which is Barrett's gestation for a stillbirth, and
		      kStillBirth_durationPregnancyInMonths = kNbLunarMonths - 4 then gives 8. Both
		      are one lunar month short of the paper.}
		gDistrib_intrauterine_mortality_risk[0] := 0.0;
		gDistrib_intrauterine_mortality_risk[1] := 0.0;
		gDistrib_intrauterine_mortality_risk[2] := 0.456956872;
		gDistrib_intrauterine_mortality_risk[3] := gDistrib_intrauterine_mortality_risk[2] + 0.251326280;
		gDistrib_intrauterine_mortality_risk[4] := gDistrib_intrauterine_mortality_risk[3] + 0.138229454;
		gDistrib_intrauterine_mortality_risk[5] := gDistrib_intrauterine_mortality_risk[4] + 0.076026200;
		gDistrib_intrauterine_mortality_risk[6] := gDistrib_intrauterine_mortality_risk[5] + 0.041814410;
		gDistrib_intrauterine_mortality_risk[7] := gDistrib_intrauterine_mortality_risk[6] + 0.022997925;
		gDistrib_intrauterine_mortality_risk[8] := gDistrib_intrauterine_mortality_risk[7] + 0.012648859;
	
		{Fecundability heterogeneity distributed as a beta function}
		{Hutterite: Majumdar & Sheps [1970]}
		betaHeterogeneityFecundability (3.4, 9.19);	{Majumdar & Sheps: mean 0.2701, sd 0.1204, CV 44.6%}
		betaHeterogeneityFecundability (2.599, 8.700); {For Leridon's N(0.23, 0.12) instead, that is mean 0.23 and sd 0.12 exactly}
		
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

	{ ------------------------------------------------------------------------------
	  Conflicts between the fixed parameters, declared beside the definitions below.

	  Several case arms of fixParameter write the SAME table, and initFixedParameters
	  walks the enum from low to high, so without the two declarations here the switch
	  that happens to sit later in fixedParameterKind silently wins and the user is told
	  nothing. The two situations are different and are handled differently.

	  kExclusionGroups: switches that each write a WHOLE table are alternatives, so at
	  most one of a group may be on. resolveFixedParameterConflicts reports the clash and
	  turns off all but one, so the run is defined and the configuration echo records what
	  actually happened.

	  kFixedParamModifiers: switches that ADJUST whatever table is already in place. They
	  must run after the ones that write a whole table, so initFixedParameters applies the
	  parameters in two passes. This leaves the order of fixedParameterKind untouched.
	  ------------------------------------------------------------------------------ }
	type
		exclusionGroupType = record
			what: string;
			members: set of fixedParameterKind;
		end;

	const
		kNbExclusionGroups = 2;
		kExclusionGroups: array [1..kNbExclusionGroups] of exclusionGroupType = (
			(what: 'the age schedule of permanent sterility (gDefinitive_sterility)';
			 members: [LeridonDefinitiveSterility, KinFertDefinitiveSterility]),
			(what: 'the fecundability age schedule (gFecundability)';
			 members: [HighLowFecundability, normaldistributionfecundability])
		);
		{LeridonOverMagnusIntrauterine and BarrettOverUS2023Stillbirth each write one whole
		 table and each has only one alternative, the unflagged default, so no exclusion group
		 is needed. Add one here if a third schedule is ever introduced for either.}


		{noInitialSterility zeroes ages up to 25, fixedDefinitiveSterility flattens from 26:
		 both adjust the base table rather than replacing it.}
		kFixedParamModifiers = [noInitialSterility, fixedDefinitiveSterility,
								fixedIntrauterineMortality];
		{fixedIntrauterineMortality flattens whatever pair of risk schedules is in place, so
		 it belongs in the second pass. Before this it ran in the first pass and wrote a
		 hard coded constant of its own, which silently discarded the selected schedule.}
		kMaxRiskSumAtAnyAge = 0.99;
		{the runtime tests dummy < intrauterine + stillbirth with dummy on [0,1), so the two
		 risks must sum to less than one at every age or a live birth becomes impossible}

	procedure resolveFixedParameterConflicts;
	var
		ind: longint;
		kind, winner: fixedParameterKind;
		nOn: longint;
		names: string;
	begin
		for ind := 1 to kNbExclusionGroups do begin
			nOn := 0;
			names := '';
			winner := low (fixedParameterKind);
			for kind := low (fixedParameterKind) to high (fixedParameterKind) do
				if (kind in kExclusionGroups[ind].members) and
				   (g_GENPARAM.fixedParameters [kind].state.value) then begin
					nOn := nOn + 1;
					names := stringConcatenate_sep (names, g_GENPARAM.fixedParameters [kind].state.name, ', ');
					{the last one found is the one the old single-pass loop left in place,
					 so keeping it changes no run that was already working}
					winner := kind;
				end;
			if (nOn > 1) then begin
				writeAndWaitConst (['===> ERROR: ', names,
					' are all set, and they all define ', kExclusionGroups[ind].what,
					'. Only one can apply. Keeping ',
					g_GENPARAM.fixedParameters [winner].state.name,
					' and turning the others off.']);
				for kind := low (fixedParameterKind) to high (fixedParameterKind) do
					if (kind in kExclusionGroups[ind].members) and (kind <> winner) then
						g_GENPARAM.fixedParameters [kind].state.value := false;
			end;
		end;
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
			{Which age schedule of intrauterine mortality: the older Léridon or the newer Magnus}
			fixedParameters [LeridonOverMagnusIntrauterine] := parameterStateName.Create (kNotUsed, FALSE, 'INTRA_LERIDON_MAGNUS', '',
												'Age schedule of intrauterine mortality: Leridon [2004] if TRUE, Magnus et al. [2019] if FALSE' + LineEnding +
												'The default is FALSE, that is Magnus, whose J shape has its minimum at age 27 and rises' + LineEnding +
												'to 53.6 per cent at 45. The Léridon cubic has no minimum and reaches only 31.5 per cent.',
												'', g_GENPARAM.listOfParams);
			{Which age schedule of stillbirth risk: the older Barrett or the newer United States 2023 shape}
			fixedParameters [BarrettOverUS2023Stillbirth] := parameterStateName.Create (kNotUsed, FALSE, 'STILLBIRTH_BARRETT_US2023', '',
												'Age schedule of stillbirth risk: Barrett [1971] if TRUE, United States 2023 shape if FALSE' + LineEnding +
												'The default is FALSE, that is the J shaped NCHS 2023 pattern rescaled to Barrett''s 3 per' + LineEnding +
												'cent at age 30. Barrett is 0.03 + 0.001 * (age - 30), linear and without the young-age rise.',
												'', g_GENPARAM.listOfParams);
			{Intrauterine mortality and stillbirth rate do not increase with age. Constant at their level at age 15}
			fixedParameters [fixedIntrauterineMortality] := parameterStateName.Create (kNotUsed, FALSE, 'FIXED_INTRAUTERINE_MORTALITY', '',
												'Intrauterine mortality is constant with age (TRUE or FALSE)', '', g_GENPARAM.listOfParams);
			{No difference in the risk of separation according to family size}
			fixedParameters [homogeneousSeparation] := parameterStateName.Create (kNotUsed, FALSE, 'HOMOGENEOUS_SEPARATION', '',
												'Separation risk does not depend on number of children (TRUE or FALSE)', '', g_GENPARAM.listOfParams);
			{Fecundability is distributed according to a normal instead of beta}
			{Default changed from TRUE to FALSE: the beta set in initFertilityModel now stands.
			 Fecundability is a probability bounded on (0,1), so a beta is the natural family,
			 while truncating the normal at p = 0 distorts the moments, turning Leridon's
			 nominal 0.23 and 0.12 into a realised 0.2381 and 0.1118. Set this back to TRUE to
			 reproduce runs made before 9 September 2026.}
			fixedParameters [normaldistributionfecundability] := parameterStateName.Create (kNotUsed, FALSE, 'NORMAL_HETEROGENEITY_FECUNDABILITY', '',

												'Heterogeneity of fecundability distributed as a normal mean 0.23, std dev 0.12, like Leridon [2004] (TRUE) or as a beta (FALSE)', '', g_GENPARAM.listOfParams);																											  
			fixedParameters [stdUnionDanielOrCampbellWood] := parameterStateName.Create (kNotUsed, TRUE, 'STDDEV_UNION_KIND', '',
												'(Obsolete) Standard Deviation of Union according to Daniel (TRUE) or to Campbell and Wood 1988. Defect value is TRUE', '', g_GENPARAM.listOfParams);
			fixedParameters [waitingTimeErlangPoisson] := parameterStateName.Create (kNotUsed, TRUE, 'WAITING_TIME_ERLANG_POISSON', '',
												'Either Erlang (TRUE) or Poisson (FALSE) for the model of waiting time before no contraception, after union or after each birth', '', g_GENPARAM.listOfParams);
		end; {with g_GENPARAM}
		
	end;
	
	procedure capConceptionOutcomeRisks;
	{The two risks are read together at conception, as dummy < intrauterine + stillbirth with
	 dummy on [0,1), so their sum must stay below one at every age. Any pairing of the
	 schedules can break that at the oldest ages, where both are close to their ceiling. Where
	 the sum is too large both are scaled by the same factor, which preserves their ratio and
	 so preserves the split between an abortion and a stillbirth.}
	var
		ageWomen: longint;
		total, factor: double;
	begin
		for ageWomen := kMinAgeFert to kMaxAgeFert - 1 do begin
			total := gIntrauterine_mortality_risk[ageWomen] + gStillbirth_mortality_risk[ageWomen];
			if total > kMaxRiskSumAtAnyAge then begin
				factor := kMaxRiskSumAtAnyAge / total;
				gIntrauterine_mortality_risk[ageWomen] := gIntrauterine_mortality_risk[ageWomen] * factor;
				gStillbirth_mortality_risk[ageWomen] := gStillbirth_mortality_risk[ageWomen] * factor;
			end;
		end;
	end;

	procedure initFixedParameters();
	var
		kind: fixedParameterKind;
	begin
		{Rebuild the base tables first. The case arms below OVERWRITE gDefinitive_sterility,
		 gFecundability, gIntrauterine_mortality_risk and gStillbirth_mortality_risk, so
		 without this a switch could only be turned ON. initFertilityModel used to run only
		 from initGeneral, that is only at program start, while this routine runs on every
		 run through initParams; so unticking a switch left whatever the last run had
		 written, and the option appeared to do nothing. initFertilityModel is a pure table
		 builder, no allocation and no I/O, so calling it here is safe and cheap.}
		initFertilityModel;

		resolveFixedParameterConflicts;
		{First pass: the parameters that write a whole table.}
		for kind := low (fixedParameterKind) to high (fixedParameterKind) do begin
			if not (kind in kFixedParamModifiers) then
				fixParameter (kind, g_GENPARAM.fixedParameters [kind].param.value);
		end;
		{Second pass: the modifiers, which adjust whatever the first pass left in place.
		 Without this, noInitialSterility and fixedDefinitiveSterility ran at enum
		 positions 2 and 3 and were then overwritten by LERIDON_STERILITY or
		 KINFERT_STERILITY at positions 9 and 10.}
		for kind := low (fixedParameterKind) to high (fixedParameterKind) do begin
			if (kind in kFixedParamModifiers) then
				fixParameter (kind, g_GENPARAM.fixedParameters [kind].param.value);
		end;
		capConceptionOutcomeRisks;
	end;
	
	function intrauterineRiskModelName: string;
	begin
		if g_GENPARAM.fixedParameters [LeridonOverMagnusIntrauterine].state.value then
			result := 'Léridon [2004]'
		else
			result := 'Magnus [2019]';

		if g_GENPARAM.fixedParameters [fixedIntrauterineMortality].state.value then
			result := result + ', constant with age';
	end;

	function stillbirthRiskModelName: string;
	begin
		if g_GENPARAM.fixedParameters [BarrettOverUS2023Stillbirth].state.value then
			result := 'Barrett [1971]'
		else
			result := 'United States 2023 shape';

		if g_GENPARAM.fixedParameters [fixedIntrauterineMortality].state.value then
			result := result + ', constant with age';
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
		if ( g_GENPARAM.fixedParameters [LeridonOverMagnusIntrauterine].state.value = true ) then
			aWriteLnAll (' LeridonOverMagnusIntrauterine');
		if ( g_GENPARAM.fixedParameters [BarrettOverUS2023Stillbirth].state.value = true ) then
			aWriteLnAll (' BarrettOverUS2023Stillbirth');

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
						for i := kMinAgeFert to kMaxAgeFert do
							gFecundability[i] := gFecundability[i] * 12 / kNbLunarMonths;
					end;
				LeridonOverMagnusIntrauterine:
					begin
						{ticked means the older schedule; Magnus is what initFertilityModel left}
						gIntrauterine_mortality_risk := copy (gIntrauterine_mortality_risk_Leridon);
					end;
				BarrettOverUS2023Stillbirth:
					begin
						{ticked means the older schedule; US 2023 is what initFertilityModel left}
						gStillbirth_mortality_risk := copy (gStillbirth_mortality_risk_Barrett);
					end;
				fixedIntrauterineMortality:
					begin
						{Flatten whichever pair of schedules the first pass left in place, at its
						 own value at age 15. It used to write two hard coded constants instead,
						 one of them from a Leridon fit that is nowhere else in the unit, so the
						 selected schedule was discarded and the level did not match it.}
						for ageWomen := kMinAgeFert to kMaxAgeFert do
							gIntrauterine_mortality_risk[ageWomen] := gIntrauterine_mortality_risk[15];
						for i := kMinAgeFert to kMaxAgeFert do
							gStillbirth_mortality_risk[i] := gStillbirth_mortality_risk[15];
					end;

				KinFertDefinitiveSterility:
					begin
						gDefinitive_sterility := copy (gDefinitive_sterility_Kinfert);
					end;
				LeridonDefinitiveSterility:
					begin
						gDefinitive_sterility := copy (gDefinitive_sterility_Leridon);
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
				breakOnFailure;
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
			breakOnFailure;
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
			breakOnFailure;
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
				breakOnFailure;
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
			breakOnFailure;
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
			breakOnFailure;
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
			breakOnFailure;
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
			InterLockedIncrement (gCount_fecundability_draws [i]);
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

		if (fecundLife.ageSterile > kMinAgeFert) and (fecundLife.ageSterile < kMaxAgeFert) then begin
			valInf := gDefinitive_sterility[trunc (fecundLife.ageSterile) - 1];
			valSup := gDefinitive_sterility[trunc (fecundLife.ageSterile)];
			if (valSup > valInf) then
				fecundLife.ageSterile := fecundLife.ageSterile - 1.0 + (dummy - valInf) / (valSup - valInf)
			else
				fecundLife.ageSterile := fecundLife.ageSterile - 1.0 + randomGenerator.alea(0, 0.99999999999);
		end;
		if (fecundLife.ageSterile < kMinAgeFert) then
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
		InterLockedIncrement (gCount_ageSterile [max (kMinAgeFert, min (kMaxAgeFert, ceil (fecundLife.ageSterile)))]);
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
		{The multiplier that the schedule just built carries, kept as its reciprocal so that
		 RESHUFFLED_FECUNDABILITY can take it back out with a multiplication and put a newly drawn
		 one in its place at each cycle, leaving the woman's own age schedule, taper included, as
		 it is. fecundabilityLevel returns i / (gMean_fecundability * kMaxDistribFecundability)
		 with i at least 1, so the level cannot be zero; the test only keeps the division safe. A
		 reciprocal of 1 with a schedule of zeros leaves the woman infecund, which is what a level
		 of zero would mean.}
		if (fecundLife.relativeFecundabilityLevel > 0.0) then
			fecundLife.invRelativeFecundabilityLevel := 1.0 / fecundLife.relativeFecundabilityLevel
		else
			fecundLife.invRelativeFecundabilityLevel := 1.0;
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
