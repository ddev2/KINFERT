{$I Defines.pas}
unit Verification;

{$mode objfpc}{$H+}

{ ----------------------------------------------------------------------------------
  Verification of the simulation

  One place where the checks the program makes are registered, counted and reported, so
  that a run ends with a verdict rather than with messages that only somebody watching
  the memo would see.

  Four kinds of check:

    checkFalse, checkTrue   an invariant: a state that cannot occur if the model is
                            right. Cheap, called from inside the simulation loops, safe
                            on the worker threads.
    reportFailure           a failure point: a line the code reaches only when it has
                            already found something wrong. It is not a test of its own,
                            it reports a test the surrounding code has made.
    checkValue              a quantity against a target, with a tolerance. Published
                            values belong here, such as Leridon's proportions
                            conceiving within twelve months.
    checkDistribution       a simulated histogram against the distribution it was drawn
                            from. Moments and the Kolmogorov-Smirnov distance.

  The difference between the first two kinds matters at the end of a run, where a check
  that did not run is reported. An invariant that did not run says that the code it
  watches was not executed, so nothing was tested. A failure point that did not run says
  that no failure of that kind was recorded, which is the result one wants. The report
  keeps the two apart, and so should any new check: give it the kind that matches the way
  it is called.

  Each check has an identifier of type TCheckId, so that no string is built while the
  simulation runs, and the report keeps a fixed order and can be compared between two
  runs with a plain diff.

  An invariant is not counted, only recorded as having run and counted when it fails.
  Some of them sit in the monthly loop and are reached hundreds of millions of times in
  a large run, and a counter shared by the worker threads would cost more than the test
  itself: writing to one line of cache from every thread costs about thirteen
  nanoseconds a time whether the write is atomic or not. Reading a flag that is written
  once costs nothing, so the fast path is a read and a comparison. Failures are rare, so
  their counter is atomic.

  Invariants are always checked: a check that runs only in a debug session is a check
  that never runs. The debugger trap is conditional, on gRunFromIDE, and stays at the
  failing line rather than here, so that the Locals window shows the variables of the
  routine that failed. The checking functions return true on the first failure of each
  check, so the trap is taken once rather than at every occurrence:

      if checkFalse (chk_something, badCondition, ['woman ', idWoman]) then breakOnFailure;

  The first failure of each check also writes one line to the memo and sets gDebugError,
  which is what lights the red indicator at the end of a run. That is what the sites
  converted from writeAndWait used to do, once per occurrence rather than once per check.
  Nothing waits for the user: a run in a batch finishes and reports.

  resetVerification is called once at the start of a run and verificationReport once at
  the end. The report goes to the memo and to <results>/verification.txt.

  To add a check: add an identifier to TCheckId, its name and the property it asserts to
  kCheckName and kCheckWhat, and its kind to kCheckKindOf, then call it from the code. The
  four arrays are kept in the same order, which the compiler enforces, each of them being
  indexed by TCheckId.
  ---------------------------------------------------------------------------------- }

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, Utilities, Math, SysUtils;

type
	TCheckKind = (ck_invariant, ck_failurePoint, ck_value, ck_distribution);

	TCheckId = (
		{FertilityRuntime: the reproductive life of one woman}
		chk_currAgeInFecundRange,
		chk_pregnancyLength,
		chk_monthStopSet,
		chk_manUnionBeforeEnd,
		chk_womanUnionBeforeEnd,
		chk_womanUnionBeforeDeath,
		chk_womanEndUnionBeforeDeath,
		chk_manUnionBeforeDeath,
		chk_manEndUnionBeforeDeath,
		chk_childrenCounted,
		chk_conceptionInterval,
		chk_birthWithinUnion,
		chk_childrenInUnion,
		{Fertility: heterogeneity of fecundability}
		chk_fecundabilityDraws,
		{Nuptiality}
		chk_nup_unionIndexOfPartner,
		chk_nup_unionRecordOfPartner,
		{Kinship}
		chk_kin_diffEndUnionEvenAfter,
		chk_kin_ageChildbearingAddToTFTtables,
		chk_kin_noMother,
		chk_kin_partnerNilAddWoman,
		chk_kin_possibleGroomExists,
		chk_kin_ageUnionWomanIndex,
		chk_kin_mismatchNumberChildrenAdded,
		chk_kin_ageUnionGMenWomen,
		chk_kin_valueCohortManGMenWomen,
		chk_kin_valueAgeUnionManGMenWomen,
		chk_kin_valueAgeUnionWomanGMenWomen,
		chk_kin_inconsistentNumberChildrenEgo,
		chk_kin_unionFoundForGroomAge,
		chk_kin_missingChildId,
		chk_kin_missingPartnerIndividual,
		chk_kin_missingAgeAtUnion,
		chk_kin_missingAgeAtEnd,
		chk_kin_currentAgeAtUnion,
		chk_kin_currentAgeAtEnd,
		chk_kin_currentAgeAtUnion2,
		chk_kin_motherThatMustExist,
		chk_kin_fatherThatMustExist,
		chk_kin_ageEgoAddToTableKinship,
		{Kinship, second batch}
		chk_kin_yearEndUnionIndividuals,
		chk_kin_diffBetweenYearEnd,
		chk_kin_endUnionByDeath,
		chk_kin_relativePartnerDiffYear,
		chk_kin_deathEndUnionDiff,
		chk_kin_diedAfterRelativeWho,
		chk_kin_partnerEndUnionDiff,
		chk_kin_relativeDiedBeforeSeparation,
		chk_kin_partnerDiedBeforeSeparation,
		chk_kin_relativeEndUnionDiff,
		chk_kin_numberChildrenDoesCheck,
		chk_kin_democareKinshipFile,
		chk_kin_linkFound,
		chk_kin_brides,
		chk_kin_childrenCheckChildren,
		chk_kin_unionYearOutRange,
		chk_kin_datesCalcAgeAtBirthOfEgo,
		chk_kin_foundLookingForRefChild,
		chk_kin_womenFoundInBackfor,
		chk_kin_motherFoundBACKFOR,
		chk_kin_foundPartnershipNumberAge,
		chk_kin_relativeNIL,
		chk_kin_relativeNumber,
		chk_kin_groomBrideMismatch,
		chk_kin_brideFoundByCohortAndAge,
		chk_kin_egoPartnerShouldDied,
		chk_kin_endUnionShouldOccur,
		chk_kin_partnerShouldDiedAfter,
		chk_kin_partnerShouldDiedBefore,
		chk_kin_egoPartnerShouldDied2,
		chk_kin_egoAgeAtDeathTooLow,
		{Fertility: what the simulation gives back}
		chk_fer_ageAtSterility,
		chk_fer_amenorrhea,
		chk_fer_intrauterineMonth,
		chk_fer_spacingContraception,
		chk_fer_sexRatioAtBirth,
		chk_fer_intrauterineRisk,
		chk_fer_stillbirthRisk,
		chk_fer_waitingTimeMean,
		{Mortality: an input the run was given}
		chk_mor_e0OutOfRange,
		{Kinship: the cohort ranges the groom index is built on}
		chk_kin_groomCohortRange,
		chk_kin_noBrideAvailable,
		{Nuptiality and Kinship: the union records of a person, see N28. A setter of Nuptiality
		 is given an index that names no union of that person, and the reciprocal link between
		 two partners that produces such an index}
		chk_nup_unionIndexInSetter,
		chk_kin_noReciprocalUnion,
		chk_nup_unionHasNoEnd,
		{The alternate mother searches, reached only when one of gBACKFOR_mode,
		 gBACKFOR_mode_pure, gCAMSIM_1987 or gCAMSIM_1993 is set. None of them runs in a
		 normal KINFERT run, so all three of these appear in the report as failure points
		 that recorded nothing.}
		chk_kin_backforAgeChildbearing,
		chk_kin_backforAgeDrawnAgain,
		chk_kin_backforNoMother,
		chk_kin_camsimParityIndexEmpty,
		chk_nup_separationIndex,
		chk_nup_scaleFactorTooLow,
		chk_nup_meanAgeUnionRange,
		chk_nup_meanAgeUnionDiff,
		{N51}
		chk_nup_stdNuptTooLow,
		chk_nup_everInUnionZero,
		{EducationalLevel}
		chk_edu_rowSumsToOne,
		chk_edu_levelName,
		chk_edu_relativeMissing,
		chk_edu_cohortNotAssigned,
		chk_edu_parentStatusMissing,
{Inheritance: what the two algorithms of the module agree about == start}
		chk_inh_partnerTestsDiffer,
		chk_inh_heirsFoundByOneOnly,
		chk_inh_heirKinTypes,
		chk_inh_heirNotConfirmed,
		chk_inh_ascendantsSameDegree,
		chk_inh_noCommonAncestor,
{Inheritance: what the two algorithms of the module agree about == end}
		{everything reported through writeAndWait, which has no check id of its own}
		chk_reportedProblem
	);

	procedure resetVerification;
	{Records a message that writeAndWait has already put in the memo, so that it is counted
	 and printed in verification.txt at the end of the run. Verification hooks this onto
	 gProblemReporter in its initialization, so no call site has to change.}
	procedure reportProblem (const message: string);

	{An invariant. checkFalse states the condition that must never hold, which is how the
	 checks in the simulation loops are written; checkTrue states the property that must
	 hold; reportFailure records a failure at a point already known to be wrong, which is
	 what the code inside a failing branch needs. context is written out with the first
	 failures, so pass what identifies the case: the woman, the month, the union.

	 All three return TRUE on the FIRST failure of that check and false otherwise, so that

	     if checkFalse (chk_something, badCondition, ['woman ', idWoman]) then breakOnFailure;

	 stops the debugger at the failing line, with that routine's variables in view, and
	 stops there once rather than at every occurrence. The result can be discarded when no
	 trap is wanted. breakOnFailure is defined in Defines.pas.

	 Note that the context is evaluated at every call, not only on failure, so pass plain
	 variables rather than expressions that allocate or compute.}
	function checkFalse (id: TCheckId; conditionThatMustNotHold: boolean; const context: array of const): boolean;
	function checkTrue (id: TCheckId; conditionThatMustHold: boolean; const context: array of const): boolean;
	function reportFailure (id: TCheckId; const context: array of const): boolean;

	{A quantity against a target. Called from the main thread at the end of a run.}
	procedure checkValue (id: TCheckId; observed, expected, tolerance: double);

	{A simulated histogram against the probabilities it was drawn from: the verdict is a
	 Kolmogorov-Smirnov comparison, described at length above the implementation. counts
	 and probabilities are indexed alike and the probabilities sum to one. Called from the
	 main thread at the end of a run.}
	procedure checkDistribution (id: TCheckId; const counts: array of longint; const probabilities: array of double);

	{The three counts the end of run report and the error indicator are built from. They are
	 kept apart because one fault can show up in more than one of them, and adding them
	 together said three problems where there was one.

	   verificationFailedChecks  how many checks failed, each counted once however many
	                             times it failed
	   verificationFailures      how many times checks failed in all, which for an invariant
	                             is the number of occurrences
	   verificationReports       how many messages came through writeAndWait, which are
	                             messages the program wrote itself and not checks

	 verificationFailures no longer includes the writeAndWait messages. It used to, so the
	 error indicator added them to the check failures while the table below subtracted them,
	 and the two disagreed.}
	function verificationFailedChecks: longint;
	function verificationFailures: longint;
	function verificationReports: longint;

	{Attaches a line to a check, printed under it in the report. It is how a routine that
	 summarises a fault at the end of a run puts its summary and its advice where the check
	 that caught each case is, instead of writing a second message that would be counted as a
	 second problem. Called from the main thread.}
	procedure setCheckNote (id: TCheckId; note: string);
	procedure verificationReport;

implementation

const
	kMaxKeptContexts = 3;

	{The name of each check, in the order of TCheckId}
	kCheckName: array [TCheckId] of string = (
		'currAgeInFecundRange',
		'pregnancyLength',
		'monthStopSet',
		'manUnionBeforeEnd',
		'womanUnionBeforeEnd',
		'womanUnionBeforeDeath',
		'womanEndUnionBeforeDeath',
		'manUnionBeforeDeath',
		'manEndUnionBeforeDeath',
		'childrenCounted',
		'conceptionInterval',
		'birthWithinUnion',
		'childrenInUnion',
		'fecundabilityDraws',
		'unionIndexOfPartner',
		'unionRecordOfPartner',
		'diffEndUnionEvenAfter',
		'ageChildbearingAddToTFTtables',
		'noMother',
		'partnerNilAddWoman',
		'possibleGroomExists',
		'ageUnionWomanIndex',
		'mismatchNumberChildrenAdded',
		'ageUnionGMenWomen',
		'valueCohortManGMenWomen',
		'valueAgeUnionManGMenWomen',
		'valueAgeUnionWomanGMenWomen',
		'inconsistentNumberChildrenEgo',
		'unionFoundForGroomAge',
		'missingChildId',
		'missingPartnerIndividual',
		'missingAgeAtUnion',
		'missingAgeAtEnd',
		'currentAgeAtUnion',
		'currentAgeAtEnd',
		'currentAgeAtUnion2',
		'motherThatMustExist',
		'fatherThatMustExist',
		'ageEgoAddToTableKinship',
		'yearEndUnionIndividuals',
		'diffBetweenYearEnd',
		'endUnionByDeath',
		'relativePartnerDiffYear',
		'deathEndUnionDiff',
		'diedAfterRelativeWho',
		'partnerEndUnionDiff',
		'relativeDiedBeforeSeparation',
		'partnerDiedBeforeSeparation',
		'relativeEndUnionDiff',
		'numberChildrenDoesCheck',
		'democareKinshipFile',
		'linkFound',
		'brides',
		'childrenCheckChildren',
		'unionYearOutRange',
		'datesCalcAgeAtBirthOfEgo',
		'foundLookingForRefChild',
		'womenFoundInBackfor',
		'motherFoundBACKFOR',
		'foundPartnershipNumberAge',
		'relativeNIL',
		'relativeNumber',
		'groomBrideMismatch',
		'brideFoundByCohortAndAge',
		'egoPartnerShouldDied',
		'endUnionShouldOccur',
		'partnerShouldDiedAfter',
		'partnerShouldDiedBefore',
		'egoPartnerShouldDied2',
		'egoAgeAtDeathTooLow',
		'ageAtSterility',
		'amenorrhea',
		'intrauterineMonth',
		'spacingContraception',
		'sexRatioAtBirth',
		'intrauterineRisk',
		'stillbirthRisk',
		'waitingTimeMean',
		'e0OutOfRange',
		'groomCohortRange',
		'noBrideAvailable',
		'unionIndexInSetter',
		'noReciprocalUnion',
		'unionHasNoEnd',
		'backforAgeChildbearing',
		'backforAgeDrawnAgain',
		'backforNoMother',
		'camsimParityIndexEmpty',
		'separationIndex',
		'scaleFactorTooLow',
		'meanAgeUnionRange',
		'meanAgeUnionDiff',
		'stdNuptTooLow',
		'everInUnionZero',
		'eduRowSumsToOne',
		'eduLevelName',
		'eduRelativeMissing',
		'eduCohortNotAssigned',
		'eduParentStatusMissing',
{Inheritance: what the two algorithms of the module agree about == start}
		'inhPartnerTestsDiffer',
		'inhHeirsFoundByOneOnly',
		'inhHeirKinTypes',
		'inhHeirNotConfirmed',
		'inhAscendantsSameDegree',
		'inhNoCommonAncestor',
{Inheritance: what the two algorithms of the module agree about == end}
		'reportedProblem'
	);

	{What each check asserts, in the same order}
	kCheckWhat: array [TCheckId] of string = (
		'the age used to read the fecundability tables is inside their bounds',
		'a pregnancy ends after it begins and no more than eleven months later',
		'the month exposure stops is set whenever the union outlives the fertile life',
		'the man enters a union before it ends',
		'the woman enters a union before it ends',
		'the woman enters a union before she dies',
		'the woman leaves a union before she dies',
		'the man enters a union before he dies',
		'the man leaves a union before he dies',
		'the children counted for a woman match the children in her list',
		'the interval between two conceptions is not negative',
		'a birth falls no more than a year after the end of the union',
		'the number of children in a union matches the union list',
		'the drawn levels of fecundability follow gDistrib_fecundability',
		'the union index handed to getPartner is one the person has',
		'the union record exists for an index the person has',
		'diff EndUnion even after correction, for ego',
		'Bad ageChildbearing in addToTFTtables',
		'No mother!!',
		'partner is nil in addWoman',
		'no possible groom in getAgeUnionSelected',
		'Bad value of ageUnionWomanInd in lookingForABrideByAgeAndCohort',
		'Mismatch in number of children added in Arrays, women',
		'age union bad for gMen_Women',
		'Bad value for cohortMan in gMen_Women',
		'Bad value for ageUnionMan in gMen_Women',
		'Bad value for ageUnionWoman in gMen_Women',
		'inconsistent number of children for ego',
		'Union not found in selectBrideByGroomAgeAtUnion!!',
		'Missing child id',
		'Missing partner individual',
		'Missing age at union individual',
		'Missing age at end union individual',
		'Current age at union lower than preceding one, individual',
		'Current age at end of union lower than preceding one, individual',
		'Current age at union lower than age at end of preceding union, individual',
		'a mother that must exist was not found',
		'a father that must exist was not found',
		'ageEgo is 0 in addToTableKinship',
		'in yearEndUnion for individuals',
		'Diff between year end union',
		'End union by death while partner died before',
		'Relative and partner have diff year of end, partner',
		'death and EndUnion diff',
		'died after relative who widowed at',
		'partner end union diff from relative',
		'relative died before separation',
		'partner died before separation',
		'relative end union diff partner',
		'Number of children does not check in addPersonsAndBirths',
		'Not a Democare Kinship file',
		'Link not found',
		'Problem with brides',
		'Problem with children in checkChildren',
		'union year out of range. Not useful in addUnionInfo',
		'Problem dates in calcAgeAtBirthOfEgo',
		'Not found lookingForRefChild',
		'No women found at',
		'Mother not found in BACKFOR',
		'Not found partnership number for age at union',
		'Relative is NIL',
		'Problem with relative number',
		'Groom and bride mismatch',
		'No bride found in selectBrideByGroomCohortAndAgeAtUnion!!',
		'Ego and/or partner should have died after the start of union',
		'End union should occur after start of union',
		'Partner should have died after ego',
		'Partner should have died before ego',
		'Ego or partner should have died after the end of union',
		'ego''s age at death is lower than the age needed for this kin',
		'the ages at onset of sterility follow gDefinitive_sterility',
		'the amenorrhea drawn after a live birth follows the schedule of temporary sterility',
		'the month a pregnancy is lost follows Barrett''s distribution',
		'the spacing contraception drawn in a birth interval follows its waiting time distribution',
		'the proportion female at birth is the one the regime was given',
		'conceptions end in a spontaneous abortion at the risk gIntrauterine_mortality_risk gives for the age',
		'conceptions end in a stillbirth at the risk gStillbirth_mortality_risk gives for the age',
		'every waiting time distribution built delivers the mean it was asked for',
		'the life expectancy asked for lies inside the model life table, 20 to 112 years',
		'every union of a woman implies a groom born inside the groom cohort range',
		'a bride can be found for the cohort and age at union asked for, or near them',
		'the union index handed to a setter names a union that person has, or the next one',
		'the partner of a union has the same union recorded on his or her own side',
		'a union ends by a death or a separation, so it has an age at end of union',
		'the age at childbearing drawn for a mother in BACKFOR or CAMSIM mode lies inside the fertile ages',
		'a mother is found at the first age at childbearing drawn, without drawing another one',
		'a mother is found for every reference child in BACKFOR or CAMSIM mode',
		'the CAMSIM parity index holds at least one mother for the cohort and the parity asked for',
		'the duration of a union and the age of its youngest child lie inside the tables of separation risks',
		'the scale factor of the standard nuptiality schedule is positive, so the schedule it builds has positive densities',
		'each mean age at first union lies inside the range a nuptiality schedule can be built from',
		'the mean age at first union of men is high enough with respect to that of women for their schedule of ages at union to be built',
		'the standard deviation of the schedule of ages at first union is positive, so the schedule it builds has positive densities',
		'the proportion ever in union is above zero, so somebody enters a union and the schedule has a mean',
		'each row of the three education distributions sums to one',
		'the education status of a person is B, M or A',
		'the person, the partner or the parent whose education level is needed is in the network',
		'the cohort of a person whose education level is drawn is assigned',
		'a status conditional on the parents, or on the partner, is drawn only once they have one',
{Inheritance: what the two algorithms of the module agree about == start}
		'the two algorithms that look for the heirs of a relative make the same test on the surviving partner',
		'the two algorithms that look for the heirs of a relative either both find heirs or both find none',
		'the kin types of the heirs found by the second algorithm lie in the branch of the tree named by the first',
		'every heir found by the first algorithm is also found by the second',
		'the ascendants who inherit all belong to the same generation, so that the nearest degree excludes the rest',
		'ego and a lateral relative of ego have at least one ancestor in common on one of the two sides of ego''s family',
{Inheritance: what the two algorithms of the module agree about == end}
		'no problem was reported through writeAndWait anywhere in the program'
	);

	kCheckKindOf: array [TCheckId] of TCheckKind = (
		{FertilityRuntime: the reproductive life of one woman}
		ck_invariant, ck_invariant, ck_invariant, ck_invariant, ck_invariant,
		ck_invariant, ck_invariant, ck_invariant, ck_invariant, ck_invariant,
		ck_invariant, ck_invariant, ck_invariant,
		{Fertility: heterogeneity of fecundability}
		ck_distribution,
		{Nuptiality}
		ck_invariant, ck_invariant,
		{Kinship. Two of them, on the ages at union of the two ways table, are called both
		 ways, and are counted as invariants: not having run says nothing was tested there.}
		ck_invariant, ck_invariant, ck_invariant, ck_invariant, ck_invariant,
		ck_invariant, ck_invariant, ck_invariant, ck_invariant, ck_invariant,
		ck_invariant, ck_invariant, ck_invariant, ck_invariant, ck_invariant,
		ck_invariant, ck_invariant, ck_invariant, ck_invariant, ck_invariant,
		ck_invariant, ck_invariant, ck_invariant,
		{Kinship, second batch. These are failure points: the code reaches them only when it
		 has already found something wrong, so not having run is the result one wants.}
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint,
		{Fertility: the parameters the simulation was given must come back}
		ck_distribution, ck_distribution, ck_distribution, ck_distribution,
		ck_value, ck_value, ck_value,
		ck_value,
		{e0 is tested on every call, so it is an invariant; a reported problem only ever
		 appears when something went wrong, so it is a failure point}
		ck_invariant, ck_invariant, ck_failurePoint,
		{the two of N28 and the one of N31: all three are reached only when something is
		 already wrong}
		ck_failurePoint, ck_failurePoint, ck_failurePoint,
		{the three of the alternate mother searches}
		ck_failurePoint, ck_failurePoint, ck_failurePoint,
		{the CAMSIM parity index}
		ck_failurePoint,
		{the two indices of the separation tables, N32}
		ck_failurePoint,
		{the scale factor of the nuptiality schedule, N29}
		ck_failurePoint,
		{the two mean ages at first union and the difference between them, N53, then the standard
		 deviation of the schedule and the proportion ever in union, N51}
		ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint,
		{education: the sum of each row is a value against a target, the other four are failure
		 points, N20, N18 and the five writeAndWait sites of EducationalLevel}
		ck_value,
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		{inheritance: the four comparisons between the two algorithms, the one degree of
		 the ascendant heirs, and the ancestor shared with a lateral relative}
		ck_failurePoint, ck_failurePoint, ck_failurePoint, ck_failurePoint,
		ck_failurePoint, ck_failurePoint,
		ck_failurePoint
	);

	kCheckKindName: array [TCheckKind] of string = ('invariant', 'failure point', 'value', 'distribution');

var
	hasRun: array [TCheckId] of boolean;
	nFailed: array [TCheckId] of longint;
	nKept: array [TCheckId] of longint;
	keptContext: array [TCheckId, 0..kMaxKeptContexts-1] of string;
	worstDeviation: array [TCheckId] of double;
	checkNote: array [TCheckId] of string;
	verificationLock: TRTLCriticalSection;

	function contextToString (const context: array of const): string;
	var
		i: longint;
		s: string;
	begin
		s := '';
		for i := 0 to high (context) do begin
			case context[i].VType of
				vtInteger:    s := s + IntToStr (context[i].VInteger);
				vtInt64:      s := s + IntToStr (context[i].VInt64^);
				vtBoolean:    s := s + BoolToStr (context[i].VBoolean, true);
				vtChar:       s := s + context[i].VChar;
				vtExtended:   s := s + str_float (context[i].VExtended^);
				vtString:     s := s + context[i].VString^;
				vtAnsiString: s := s + ansistring (context[i].VAnsiString);
				else          s := s + '?';
			end;
		end;
		contextToString := s;
	end;

	function recordFailure (id: TCheckId; const context: array of const): boolean;
	{returns true for the first failure of this check, which is what lets the call site take
	 the trap once. The trap itself is at the call site: stopping here would show the
	 debugger this routine's variables instead of those of the code that failed.}
	var
		firstOne: boolean;
	begin
		firstOne := (InterLockedIncrement (nFailed [id]) = 1);
		result := firstOne;
		if firstOne then begin
			{what the converted sites used to do through writeAndWait: a line in the memo and
			 the red indicator that endSimulation lights when gDebugError is set. It is done
			 on the first failure of each check only, since some of these are reached once per
			 woman and per month, and the rest are counted in the table at the end of the run.}
			memoWriteLn (['===> ', kCheckName [id], ' failed: ', kCheckWhat [id],
						'. First case: ', contextToString (context),
						'. Further failures are counted in the verification table.']);
			gDebugError := true;
		end;
		if (nKept [id] < kMaxKeptContexts) then begin
			EnterCriticalSection (verificationLock);
			if (nKept [id] < kMaxKeptContexts) then begin
				keptContext [id, nKept [id]] := contextToString (context);
				Inc (nKept [id]);
			end;
			LeaveCriticalSection (verificationLock);
		end;
	end;

	function checkFalse (id: TCheckId; conditionThatMustNotHold: boolean; const context: array of const): boolean;
	begin
		if not hasRun [id] then hasRun [id] := true;
		result := false;
		if conditionThatMustNotHold then
			result := recordFailure (id, context);
	end;

	function checkTrue (id: TCheckId; conditionThatMustHold: boolean; const context: array of const): boolean;
	begin
		if not hasRun [id] then hasRun [id] := true;
		result := false;
		if not conditionThatMustHold then
			result := recordFailure (id, context);
	end;

	function reportFailure (id: TCheckId; const context: array of const): boolean;
	{for a point the code has already found to be wrong, inside the failing branch}
	begin
		if not hasRun [id] then hasRun [id] := true;
		result := recordFailure (id, context);
	end;

	procedure reportProblem (const message: string);
	{Deliberately does not write to the memo: writeAndWait has already done that, and the
	 point of coming here is to keep the message somewhere that survives the run. Counted
	 like any failure, so the verification table carries the number and the first few texts.}
	begin
		if not hasRun [chk_reportedProblem] then hasRun [chk_reportedProblem] := true;
		InterLockedIncrement (nFailed [chk_reportedProblem]);
		if (nKept [chk_reportedProblem] < kMaxKeptContexts) then begin
			EnterCriticalSection (verificationLock);
			if (nKept [chk_reportedProblem] < kMaxKeptContexts) then begin
				keptContext [chk_reportedProblem, nKept [chk_reportedProblem]] := message;
				Inc (nKept [chk_reportedProblem]);
			end;
			LeaveCriticalSection (verificationLock);
		end;
	end;

	procedure checkValue (id: TCheckId; observed, expected, tolerance: double);
	var
		deviation: double;
	begin
		hasRun [id] := true;
		deviation := abs (observed - expected);
		if (deviation > worstDeviation [id]) then
			worstDeviation [id] := deviation;
		checkNote [id] := 'observed ' + str_float (observed) +
						', expected ' + str_float (expected) +
						', tolerance ' + str_float (tolerance);
		if (deviation > tolerance) then
			recordFailure (id, ['observed ', str_float (observed), ' against ', str_float (expected)]);
	end;

	procedure checkDistribution (id: TCheckId; const counts: array of longint; const probabilities: array of double);
	{Compares what the simulation drew with what it should have drawn.

	 counts [i] is the number of times cell i came out of the draw. probabilities [i] is
	 the probability cell i should have had. The two arrays are indexed alike and the
	 probabilities sum to one. For the levels of fecundability, counts is
	 gCount_fecundability_draws, filled one increment at a time inside fecundabilityLevel,
	 and probabilities is the density recovered from gDistrib_fecundability by differencing
	 it, the first cell being gDistrib_fecundability[1] because the sampler returns the
	 smallest index whose cumulative value reaches the draw.

	 The test is the Kolmogorov-Smirnov one. Both series are accumulated into cumulative
	 distributions and the largest vertical distance between the two curves is taken:

	     D = max over i of | (counts up to i) / n  minus  (probabilities up to i) |

	 D is then read against the distance that sampling alone would produce. With n draws
	 from the right distribution D is of the order of 1 / sqrt(n), and the probability that
	 it exceeds c / sqrt(n) is about 2 * exp(-2 * c * c). Fixing how often we are willing
	 to see a false alarm therefore fixes c, which is sqrt(-0.5 * ln(alpha / 2)): 1.36 for
	 the alpha of 0.05 used in a published test, 2.2262 for the alpha of 0.0001 used here.

	 Why one in ten thousand rather than one in twenty. The band is a threshold that a
	 correct sampler crosses with probability alpha. At the usual 5 per cent, one run in
	 twenty would be reported as a failure with nothing wrong, and a table that cries wolf
	 that often after every run is a table nobody reads. At 0.0001 a false alarm is a
	 once-in-ten-thousand-runs event, and little is lost, because a defect in a sampler is
	 not a small deviation. With two million draws from the Leridon grid the band is
	 0.00157; a correct sampler gives about 0.0004; the off-by-one that fecundabilityLevel
	 used to have, which returned one cell too low for every woman, gives 0.0114, seven
	 times the band.

	 The mean cell of each series is reported next to D, because a shift that moves the
	 whole distribution shows up there in a form that is easier to read than a distance.

	 What this cannot tell you: whether probabilities is itself right. The draws are
	 compared with the table they were drawn from, so what is verified is the sampler and
	 the random number generator, not the formula that built the table. A wrong table
	 faithfully sampled passes. Checking the table itself means comparing its moments with
	 the parameters that were asked for, which is what the report in Fertility.pas prints
	 beside this verdict.}
	const
		kBandCoefficient = 2.2262;	{alpha = 0.0001; see the note above}
	var
		i, n, nDraws: longint;
		cumSim, cumThe, gap, maxGap, band: double;
		meanSim, meanThe: double;
	begin
		hasRun [id] := true;
		n := min (high (counts), high (probabilities));
		nDraws := 0;
		for i := 0 to n do
			nDraws := nDraws + counts [i];
		if (nDraws = 0) then begin
			checkNote [id] := 'no draw recorded';
			exit;
		end;

		cumSim := 0.0; cumThe := 0.0; maxGap := 0.0;
		meanSim := 0.0; meanThe := 0.0;
		for i := 0 to n do begin
			meanSim := meanSim + i * (counts [i] / nDraws);
			meanThe := meanThe + i * probabilities [i];
			cumSim := cumSim + counts [i] / nDraws;
			cumThe := cumThe + probabilities [i];
			gap := abs (cumSim - cumThe);
			if (gap > maxGap) then maxGap := gap;
		end;
		band := kBandCoefficient / sqrt (1.0 * nDraws);
		if (maxGap > worstDeviation [id]) then worstDeviation [id] := maxGap;	{several calls may share one identifier}
		checkNote [id] := IntToStr (nDraws) + ' draws, largest gap ' + str_float (maxGap) +
						' against a band of ' + str_float (band) +
						', mean cell ' + str_float (meanSim) + ' against ' + str_float (meanThe);
		if (maxGap > band) then
			recordFailure (id, ['largest gap ', str_float (maxGap), ' against a band of ', str_float (band)]);
	end;

	procedure resetVerification;
	var
		id: TCheckId;
		i: longint;
	begin
		for id := low (TCheckId) to high (TCheckId) do begin
			hasRun [id] := false;
			nFailed [id] := 0;
			nKept [id] := 0;
			worstDeviation [id] := 0.0;
			checkNote [id] := '';
			for i := 0 to kMaxKeptContexts-1 do
				keptContext [id, i] := '';
		end;
	end;

	function verificationFailedChecks: longint;
	{checks with at least one failure, which is the number the error indicator should name:
	 one check that failed twice is one problem, not two}
	var
		id: TCheckId;
	begin
		result := 0;
		for id := low (TCheckId) to high (TCheckId) do begin
			if (id = chk_reportedProblem) then continue;
			if (nFailed [id] > 0) then Inc (result);
		end;
	end;

	function verificationFailures: longint;
	{failures in all, over the checks only. chk_reportedProblem counts messages that
	 writeAndWait produced, not a property of the model, and verificationReports returns
	 those.}
	var
		id: TCheckId;
	begin
		result := 0;
		for id := low (TCheckId) to high (TCheckId) do begin
			if (id = chk_reportedProblem) then continue;
			result := result + nFailed [id];
		end;
	end;

	function verificationReports: longint;
	begin
		result := nFailed [chk_reportedProblem];
	end;

	procedure setCheckNote (id: TCheckId; note: string);
	begin
		checkNote [id] := note;
	end;

	function padRight (s: string; n: longint): string;
	{a fixed width column, so that the report reads as a table in a plain text editor. A name
	 longer than the column pushes its line out rather than being cut: a truncated check name
	 cannot be looked up in the source.}
	begin
		result := s;
		while (length (result) < n) do result := result + ' ';
	end;

	function plural (n: longint; one, many: string): string;
	begin
		if (n = 1) then result := one else result := many;
	end;

	procedure verificationReport;
	{The report is arranged by outcome rather than by the order of TCheckId, because the order
	 of the enumeration means nothing to a reader and put the most important lines in the middle
	 of a long table.

	 Five sections, in the order they should be read:
	   what failed, with the first cases kept for each;
	   what was reported through writeAndWait, which is not a check and had no business sitting
	     in the table of checks with a property it was supposed to hold;
	   what passed, grouped by kind, since a passing check needs its name and nothing else;
	   the failure points that recorded nothing, which is the outcome one wants;
	   the checks that did not run at all, which tested nothing.

	 The memo receives the first two sections and a summary of the rest; the whole report goes
	 to verification.txt, where there is room for it.}
	var
		id: TCheckId;
		i, res, nRan, nBad, nInSection: longint;
		f: TFileType;
		nNotRunSilent, nNotRunUntested, nReported: longint;
		kind: TCheckKind;
		rule: string;

		procedure line (const args: array of const);
		{memo and file}
		begin
			memoWriteLn (args);
			if (res = 0) then bWriteLn (f, args);
		end;

		procedure fileLine (const args: array of const);
		{file only}
		begin
			if (res = 0) then bWriteLn (f, args);
		end;

		procedure sectionToFile (title: string);
		begin
			fileLine (['']);
			fileLine ([rule]);
			fileLine ([title]);
			fileLine ([rule]);
		end;

		procedure sectionToBoth (title: string);
		begin
			line (['']);
			line ([rule]);
			line ([title]);
			line ([rule]);
		end;

	begin
		res := -1;
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + 'verification.txt', res, 'VERIFICATION');
			if (res = 0) then f.aSync := false;
		end;
		rule := '------------------------------------------------------------------------';

		{chk_reportedProblem counts messages that writeAndWait produced, not a property of the
		 model, so it is kept out of every count of checks and given its own section}
		nRan := 0;
		nBad := 0;
		for id := low (TCheckId) to high (TCheckId) do begin
			if (id = chk_reportedProblem) then continue;
			if not hasRun [id] then continue;
			Inc (nRan);
			if (nFailed [id] > 0) then Inc (nBad);
		end;
		nReported := nFailed [chk_reportedProblem];

		line (['']);
		line (['======================= Verification of the run ========================']);
		if (nRan = 0) then
			line (['No check ran. Either the run did nothing, or the checks are not called ',
					'from the code that ran.'])
		else if (nBad = 0) then
			line ([nRan, ' checks ran and all of them passed.'])
		else
			{no subtraction here any more: verificationFailures counts the checks only}
			line ([nRan, ' checks ran, ', nBad, ' of them failed, ',
					verificationFailures, ' failures in all.']);
		if (nReported > 0) then
			line ([nReported, plural (nReported, ' problem was', ' problems were'),
					' reported through writeAndWait, listed below.']);

		{1. what failed}
		if (nBad > 0) then begin
			sectionToBoth ('FAILED');
			for id := low (TCheckId) to high (TCheckId) do begin
				if (id = chk_reportedProblem) then continue;
				if not hasRun [id] then continue;
				if (nFailed [id] = 0) then continue;
				line ([padRight (kCheckName [id], 32), kCheckKindName [kCheckKindOf [id]], ', ',
						nFailed [id], plural (nFailed [id], ' failure', ' failures')]);
				line ([padRight ('   what it watches', 22), kCheckWhat [id]]);
				if (kCheckKindOf [id] in [ck_value, ck_distribution]) then
					line ([padRight ('   worst deviation', 22), str_float (worstDeviation [id])]);
				{'measured' is right for a quantity against a target, and wrong for the note a
				 summary attaches to an invariant, which is a remark and not a measurement}
				if (checkNote [id] <> '') then
					if (kCheckKindOf [id] in [ck_value, ck_distribution]) then
						line ([padRight ('   measured', 22), checkNote [id]])
					else
						line ([padRight ('   note', 22), checkNote [id]]);
				for i := 0 to nKept [id] - 1 do
					if (i = 0) then
						line ([padRight ('   first cases', 22), keptContext [id, i]])
					else
						line ([padRight ('', 22), keptContext [id, i]]);
				if (nFailed [id] > nKept [id]) then
					line ([padRight ('', 22), '(', nFailed [id] - nKept [id],
							' further failures, not kept)']);
			end;
		end;

		{2. what writeAndWait reported}
		if (nReported > 0) then begin
			sectionToBoth ('Problems reported through writeAndWait');
			if (nReported > kMaxKeptContexts) then
				line (['Messages the program wrote itself, not checks. Only the first ',
						kMaxKeptContexts, ' of ', nReported, ' are kept.'])
			else
				line (['Messages the program wrote itself, not checks.']);
			for i := 0 to nKept [chk_reportedProblem] - 1 do
				line (['   ', keptContext [chk_reportedProblem, i]]);
		end;

		{3. what passed, grouped by kind}
		if (nRan - nBad > 0) then begin
			sectionToFile ('Passed');
			for kind := low (TCheckKind) to high (TCheckKind) do begin
				nInSection := 0;
				for id := low (TCheckId) to high (TCheckId) do begin
					if (id = chk_reportedProblem) then continue;
					if not hasRun [id] then continue;
					if (nFailed [id] > 0) then continue;
					if (kCheckKindOf [id] <> kind) then continue;
					if (nInSection = 0) then begin
						fileLine (['']);
						fileLine ([kCheckKindName [kind], 's']);
					end;
					Inc (nInSection);
					fileLine (['   ', padRight (kCheckName [id], 32), kCheckWhat [id]]);
					if (checkNote [id] <> '') then
						fileLine (['   ', padRight ('', 32), checkNote [id]]);
				end;
			end;
			memoWriteLn ([nRan - nBad, ' checks passed. They are named in verification.txt']);
		end;

		{4 and 5. what did not run. A check that did not run is not a check that passed, and
		 what its silence means depends on how it is called. A failure point is reached only
		 when the code has already found something wrong, so silence there is the good outcome.
		 Any other check has to be executed to test anything, so its silence means the code it
		 watches was not reached and nothing was tested, neither a pass nor a failure. Both
		 lists are printed: a check that quietly stops being called would otherwise look like
		 silence, and silence reads as success.}
		nNotRunSilent := 0;
		nNotRunUntested := 0;
		for id := low (TCheckId) to high (TCheckId) do
			if (not hasRun [id]) and (id <> chk_reportedProblem) then begin
				if (kCheckKindOf [id] = ck_failurePoint) then
					Inc (nNotRunSilent)
				else
					Inc (nNotRunUntested);
			end;

		if (nNotRunSilent > 0) then begin
			sectionToFile ('Failure points that recorded nothing, which is the outcome one wants');
			fileLine (['The code reaches these lines only when it has already found something wrong.']);
			fileLine (['']);
			for id := low (TCheckId) to high (TCheckId) do
				if (not hasRun [id]) and (id <> chk_reportedProblem)
						and (kCheckKindOf [id] = ck_failurePoint) then
					fileLine (['   ', padRight (kCheckName [id], 32), kCheckWhat [id]]);
			memoWriteLn ([nNotRunSilent, ' failure points recorded nothing: no failure of these kinds ',
						'occurred in this run. They are named in verification.txt']);
		end;

		if (nNotRunUntested > 0) then begin
			sectionToFile ('Checks that did not run, so tested nothing');
			fileLine (['The code they watch was not reached in this run: neither a pass nor a failure.']);
			fileLine (['']);
			for id := low (TCheckId) to high (TCheckId) do
				if (not hasRun [id]) and (id <> chk_reportedProblem)
						and (kCheckKindOf [id] <> ck_failurePoint) then
					fileLine (['   ', padRight (kCheckName [id], 32), kCheckWhat [id]]);
			memoWriteLn ([nNotRunUntested, ' checks did not run: the code they watch was not reached in ',
						'this run, so they tested nothing, neither a pass nor a failure. They are named ',
						'in verification.txt']);
		end;

		fileLine (['']);
		fileLine ([rule]);
		fileLine (['End of the verification report']);

		if (res = 0) then f.Destroy;
	end;

initialization
	InitCriticalSection (verificationLock);
	{turn the dependency round: Utilities cannot use Verification, so Verification hands
	 Utilities the routine to call. Set here so that it is in place before any unit body
	 that might report a problem has run.}
	gProblemReporter := @reportProblem;
	resetVerification;

finalization
	DoneCriticalSection (verificationLock);

end.
