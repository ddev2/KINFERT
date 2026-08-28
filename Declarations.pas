{$I Defines.pas}
unit Declarations;
interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils;
	
{DECLARATIONS_CONST}
const
	kMinAgeLife = 0;
	kMaxAgeLife = 130;

	kMinAgeFert = 10;
	kMaxAgeFert = 59;
	
	kMinAgeUnion = 10;
	kMaxAgeUnion = 79;
	
	kMinMeanAgeUnion = 15;
	
	kMinAgeUnion_women = kMinAgeUnion;
	kMinAgeUnion_men = kMinAgeUnion + 4;
	kMaxAgeUnion_women = kMaxAgeUnion - 5;
	kMaxAgeUnion_men = kMaxAgeUnion;
	// useful for initMotherhood procedure
	kMaxDiffAgeUnion_men_olderWomen = 20; // a man will marry a woman at most older than this age
	kMaxDiffAgeUnion_women_olderMen = 30; // a woman will marry a man at most older than this age
	
	kMinAgeFert_men = kMinAgeUnion_men;
	kMaxAgeFert_men = kMaxAgeUnion_men;
	
	kMinAgeSingle = kMinAgeUnion;
	kMaxAgeSingle = kMaxAgeUnion + 1;
	kMaxAgeSingle_women = kMaxAgeUnion_women + 1;
	kMaxAgeSingle_men = kMaxAgeUnion_men + 1;
	
	kNbLunarMonths = 12; {Yearly number of lunar months}
	
	kMaxAgeFertInMonths = (kMaxAgeFert+1) * kNbLunarMonths - 1;
	kMaxAgeLifeInMonths = (kMaxAgeLife+1) * kNbLunarMonths - 1;
	
	kMaxDurationUnion = kMaxAgeLife - kMinAgeUnion + 1;
	kMaxShownDurationUnion = 49;
	kMaxDurationUnionInMonths = kMaxDurationUnion * kNbLunarMonths;
	kMaxDurationContraceptionUnionInMonths = 10 * kNbLunarMonths; // 10 years
	kMaxDurationContraceptionInBirthIntervals = 10 * kNbLunarMonths;
	kMaxParityInput = 9;
	kNumDifferentsBirthIntervals = 5; // The parameters for contraception use in birth intervals have different values for the first, the second, etc.
	kMaxIndBirthIntervals = kNumDifferentsBirthIntervals - 1; //
	kMaxDurationIntervals = 15;
	kMaxDurationIntervalsInMonth = kMaxDurationIntervals * kNbLunarMonths;
	kMaxShownDurationUnionInMonths = kMaxShownDurationUnion * kNbLunarMonths;
	
	kMinDurationSeparation = 0;
	kMaxDurationSeparation = 29;
	kMean_repartneringAfterSeparation_men = 1;
	kMean_repartneringAfterSeparation_women = 1;
	kMean_repartneringAfterWidowhood_men = 1.5;
	kMean_repartneringAfterWidowhood_women = 2;
	
	kNotUsed = -999999999;

type
	agesLife = kMinAgeLife..kMaxAgeLife;
	agesFert = kMinAgeFert..kMaxAgeFert;
	agesUnion = kMinAgeUnion..kMaxAgeUnion;
	durationsUnion = 0..kMaxShownDurationUnion;
	agesSingle = kMinAgeSingle..kMaxAgeSingle;
	agesUnionWomen = kMinAgeUnion_women..kMaxAgeUnion_women;
	agesUnionMen = kMinAgeUnion_men..kMaxAgeUnion_men;
	agesSingleWomen = kMinAgeSingle..kMaxAgeSingle_women;
	agesSingleMen = kMinAgeSingle..kMaxAgeSingle_men;
	durationSeparation = kMinDurationSeparation..kMaxDurationSeparation;

	KinTypes = (kt_none, kt_ego, kt_partner, kt_child, kt_grandChild, kt_greatGrandChild,
				kt_father, kt_mother, kt_sibling, kt_nieceNephew, kt_grandNieceNephew, kt_greatGrandNieceNephew,
				kt_grandFather, kt_grandMother, kt_auntUncle, kt_cousin, kt_cousin_removed, kt_cousin_twice_removed, kt_cousin_thrice_removed,
				kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle, kt_great_cousin_removed, kt_second_cousin, kt_second_cousin_removed, kt_second_cousin_twice_removed,
				kt_nonBio, kt_total);
	KinStates = (born, alive);
	KinSetType = set of KinTypes;
	KinBranchType = array [KinTypes] of KinSetType;
	
const
	kFirstKinInEnum = kt_ego;
	kLastKinInEnum = kt_nonBio;
	kFirstKinInEnumOutput = kt_ego;
	kLastKinInEnumOutput = kt_second_cousin_twice_removed;
	
	str_kinship : array [KinTypes] of string = (
				'none', 'ego', 'partner', 'child', 'grand child', 'great grand child',
				'father', 'mother', 'sibling', 'niece-nephew', 'grand niece-nephew', 'great grand niece-nephew',
				'grand father', 'grand mother', 'aunt-uncle', 'first cousin', 'first cousin once removed', 'first cousin twice removed', 'first cousin thrice removed',
				'great grand father', 'great grand mother', 'grand aunt-uncle', 'great first cousin once removed', 'second cousin', 'second cousin once removed', 'second cousin twice removed',
				'non-bio', 'total');
var
{GLOBAL VARIABLES INITIALIZED WHEN THE PROGRAM STARTS, WHICH CAN CHANGE LATER, BUT BEFORE THE START OF THE SIMULATION}
	gKinToSimulate: KinSetType = [kt_ego, kt_partner, kt_father, kt_mother, kt_sibling, kt_grandFather, kt_grandMother, kt_auntUncle, kt_child, kt_grandChild];
	gKinWithNoDescendance: KinSetType = [kt_greatGrandChild, kt_greatGrandNieceNephew, kt_cousin_thrice_removed, kt_second_cousin_twice_removed];
	gStdKinSet: KinSetType = [kt_ego, kt_partner, kt_father, kt_mother, kt_sibling, kt_grandFather, kt_grandMother,
								kt_auntUncle, kt_cousin, kt_nieceNephew, kt_child, kt_grandChild];
	gDemoCareKinSet: KinSetType = [kt_ego, kt_partner, kt_child, kt_grandChild];
	// list of possible heirs of ego (we will need to add egos's kt_partner later)
	gPossibleHeirs: KinSetType = [kt_partner, kt_child, kt_grandChild, kt_greatGrandChild, kt_father, kt_mother,
							kt_sibling, kt_nieceNephew, kt_grandNieceNephew,
							kt_grandFather, kt_grandMother, kt_auntUncle, kt_cousin,
							kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle];
	// minimum kin set simulated for studying ego's heirship rights (if not complete, we cannot study it)
	gMinKinSetforEgoInheritance: KinSetType = [kt_ego, kt_partner, kt_child, kt_grandChild, kt_greatGrandChild,
							kt_father, kt_mother, kt_sibling, kt_nieceNephew, kt_grandNieceNephew, kt_greatGrandNieceNephew,
							kt_grandFather, kt_grandMother, kt_auntUncle, kt_cousin,
							kt_cousin_removed, kt_cousin_twice_removed, kt_cousin_thrice_removed,
							kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle,
							kt_great_cousin_removed, kt_second_cousin, kt_second_cousin_removed, kt_second_cousin_twice_removed
							];
	// kin from whom ego can receive an inheritance (possibly the same set than gPossibleHeirs, depending on the oountry's intestate rules)
	gPossibleDecedents: KinSetType = [kt_partner, kt_child, kt_grandChild, kt_greatGrandChild, kt_father, kt_mother,
										kt_sibling, kt_nieceNephew, kt_grandNieceNephew,
										kt_grandFather, kt_grandMother,
										kt_auntUncle, kt_cousin, kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle];

type
	FieldNamesTypes = (	fn_yBirth, fn_mBirth, fn_yBirthFloat, fn_yDeathFloat, fn_nChildren, fn_birthOrder, fn_ageRelEgo, fn_ageDeath, fn_ageUnion,
						fn_ageEndUnion, fn_causeEnd,
						fn_ageMotherAtChildbirth, fn_ageFatherAtChildbirth, fn_status, fn_cohortDemReg, fn_motherUnionNumber,
						fn_heirs, fn_shareHeirs, fn_kinHeirs, fn_decedents, fn_shareInheritance, fn_kinDecedents);
	FieldSetType = set of FieldNamesTypes;
	
	typeOfHeirs = (th_doNotApply, th_none, th_childrenTree, th_ascendantsTree, th_partner, th_siblingsTree, th_auntUncleTree, th_grandAuntUncleTree);
	//typeEgoAsHeir = (eh_doNotApply, eh_notHeir, eh_indirectHeir, eh_directHeir, eh_onlyHeir);
	typeOfHeirsSetType = set of typeOfHeirs;
	
const	
	str_FieldNames : array [FieldNamesTypes] of string = (
		'Year birth', 'Month birth', 'Year birth float', 'Year death float',  'Number children', 'Birth order', 'age relative ego', 'age at death', 'age at union',
		'age end union', 'cause end union',
		'age mother at childbirth', 'age father at childbirth', 'status', 'cohort Dem. Reg.', 'Mother union number',
		'heirs', 'share heirs', 'kintype heirs', 'decedents', 'share inheritance', 'kintype decedents');

	str_typeOfHeirs : array [typeOfHeirs] of string = (
		// 'do not apply' means the relative has no simulated descendance
		// or it does not make sense to search for heirs, because the relative is either very young or very old relative to ego
		'do not apply', 'none', 'childrenTree', 'ascendants', 'partner', 'siblingsTree', 'auntUncleTree', 'grandAuntUncleTree'
	);
	//str_egoHeir : array [typeEgoAsHeir] of string = ('do not apply', 'notHeir', 'indirectHeir', 'directHeir', 'onlyHeir');
	
	kNewReproductiveLife = true; {for calcCompleteFertilityWoman}
	
	kLivingBirth_durationPregnancyInMonths = kNbLunarMonths - 3;
	kStillBirth_durationPregnancyInMonths = kNbLunarMonths - 4;
	kIntrauterineMort_NonSusceptPeriod_minInMonths = 1;
	kMaxMultipleBirths = 6;
	
	kMaxMonthTemporarySterility = 44;
	
	kMaxNbChildren = kMaxAgeFert-kMinAgeFert+1;
	kMaxNbChildrenPlusUn = kMaxNbChildren+1;
	kMaxNbChildrenCalc = 15;

	kMaxNbUnion = 30;
	
	kMax_param_TotalFertAgeUnion = 10;
	
	tab = char(9);
	LF = char(10);
	CR = char(13);
	tabSet = [#9];
	comma = ',';
	uSet = ['_'];
	
	kMaxDistribFecundability = 300;
	
	man = 0;
	woman = 1;
	
	kMemoryAllocatedPIN = 123456789;
	
	out_EgoGenealogy = 0;
	out_DemoCare = 1;
	out_GEDCOM = 2;

	inher_Spain = 0;
	inher_Other = 1;
	
	no_union = 0;
	end_by_death = 1;
	end_by_widowhood = 2;
	end_by_separation = 3;
	end_allTypes = 4;

	kInfoChildCheck = 1234567890;

var
	gFormatSettings: TFormatSettings;
	
type
	Sex = man..woman;
	SexTotal = (men, women, all);
	ArrayOfSex = array of Sex;
	
const
	sSex : array [Sex] of string = ('man', 'woman');
	str_gender : array [Sex] of string = ('M', 'F');
	sSexTotal : array [SexTotal] of string = ('Men', 'Women', 'Total');
	
const
	eduLow = 0; eduMedium = 1; eduHigh = 2;
type
	EduLevels = eduLow..eduHigh;
const
	strEduLevels: array [EduLevels] of string = ('LOW', 'MEDIUM', 'HIGH');

const
	eduNone = 0; {educational level is not used}
	eduStochastic = 1; {educational level is determined in a totally stochastic way, 1/3 for each of the three levels}
	eduCohort = 2; {educational level is determined in a stochastic way at the individual level,
					but based on observed distribution of educational level for the cohort, with NO intrafamily correlation}
	eduIntraFamily = 3; {same at eduCohort, but with intrafamily correlation}
type
	EduStatusKinds = eduNone..eduIntraFamily;
const
	strEduStatusKinds: array [EduStatusKinds] of string = ('none', 'stochastic', 'cohort observed', 'intra family');

{DECLARATIONS_TYPE}
type
	
	arrayOfLongint = array of longint;
	pArrayOfLongint = ^arrayOfLongint;
	arraydoubletype = array of double;
	array2OfLongint = array of array of longint;
	array2doubletype = array of array of double;
	array3doubletype = array of array of array of double;
			
{General}
	tabSex = array[Sex] of double;

	ageQuinq = (f1014, f1519, f2024, f2529, f3034, f3539, f4044, f4549, f5054, f5559, ftotal);

{Nuptiality}
	typTabNupt = (normal, aggregated);
	{'dead' is added AFTER 'any' on purpose: several arrays are indexed by this type and
	 many loops run 'neverInUnion to any', so appending keeps every existing ordinal.}
	PartnershipStatusesType = (neverInUnion, firstUnion, secondUnions, widow, separated, everInUnion, any, dead);
	// any = neverInUnion + firstUnion + secondUnions + widow + separated
	// everInUnion = firstUnion + secondUnions + widow + separated
	UnionGenStatesType = (ongoing, endedAge50);
{$IFDEF UnionStatesType}
	UnionStatesType = (ongoing_union, ended_separation, ended_widowhood);
{$ENDIF}
	paramSinglehood_RT_type = ( freqFinUnion, meanUnion, stdUnion );
	ArrayParamSinglehood_RT_type = array [paramSinglehood_RT_type] of double;
	tabNupt = array[agesUnion] of double;
	tabNuptVar = array of double;
	tabSingle = array[agesSingle] of double;
	tabSingleVar = array of double;
	tabNuptCrossed = array[agesUnion, typTabNupt] of tabNuptVar;
	pTabNupt = ^tabNupt;
	pTabSingle = ^tabSingle;
	pTabSingleVar = ^TabSingleVar;
	
{$IFDEF UnionStatesType}
	destinyUnionType = array[0..kMaxDurationUnion, UnionStatesType] of longint;
{$ENDIF}
	intensityRepartneringType = array[Sex, kMinAgeUnion..kMaxAgeSingle_men, -1..kMaxDurationUnion] of longint;
															{Broken Female Unions.
															We're counting weddings and
															the delayed time for repartnering.
															At the duration -1 we put the number
															of union interrupted by
															widowhood and separation.
															The age is the age of interruption
															of the previous union.}

	CausesEndUnionType = no_union..end_allTypes;
	
const
	str_endUnion : array [CausesEndUnionType] of string = ('None', 'Death', 'Wid', 'Sep', 'All');
type
	StatusAge50 = (allStates50, alive50EverInUnion, aliveWithFirstPartner50);
	StatusUnion = (su_before, su_inUnion, su_after, su_none);
	
type
	// Forward declarations of classes
	GenericName = class;
	LongintName = class;
	BooleanName = class;
	DoubleName = class;
	DoubleCumulName = class;
	StringName = class;
	ArrayOfDoubleName = class;
	EduStatusName = class;
	KinFileFmtName = class;
	CountryInheritanceName = class;
	
	KinListName = class;
	FieldListName = class;
	parameterStateName = class;

{Nuptiality}
	NuptialitySettings = record
		{Monotonic decreasing function from 1 to the level of final celibacy}
		prop_cel_women, prop_cel_men: tabSingleVar;
		{Rate of union risk}
		union_women, nupt_men: tabNuptVar;
		// Age of men who marry women, for each age of women
		union_women_men: tabNuptCrossed;
		// Reverse: age of women who marry men, for each age of men
		union_men_women: tabNuptCrossed;
		nupt_men_women_init: boolean;
		unionParam: array [Sex] of ArrayParamSinglehood_RT_type;

		{repartnering HAVE A LOOK AT IT. VALUE DEPEND ON AGE AND NOT ON AGE AT SEPARATION OR WIDOWING. ALSO REPARTNERING RISK LOW AT YOUNG AGES??}
		//prop_repartnering: array [Sex, ageUnion] of double; {COMPUTED INTERNALLY VIA LOG-LOGISTIC AND VALUES OF REPARTNERING_MEN & REPARTNERING_WOMEN}
		prop_repartnering: array of array of double;
		prop_not_repartnering: array of double; // equivalent to prop_cel
		prop_repartnering_widowhood: array of array of double;
		prop_not_repartnering_widowhood: array of double; // equivalent to prop_cel
		prop_repartnering_duration: array of array of double;
		prop_repartnering_widowhood_duration: array of array of double;
	end;
	pNuptialitySettings = ^NuptialitySettings;
	
{Separation}
	nbChildrenEnum = (oneChild, TwoChildrenMore);
	separationRelRisqueType = array[-11..kMaxDurationUnionInMonths] of double;
	separationRelRisque2Type = array[nbChildrenEnum] of separationRelRisqueType;
	
	separationSettings = record
		separationPossible: boolean;
		separation_median,
		separation_shape,																																								 
		separation_proportion: double;
		freqSeparation: double;
		freqSeparation_adjusted: double;
		freqSeparation_result: double;
		{**********}
	
		{monthly_risk_separation: array[0..kMaxDurationUnionInMonths] of double;}
		monthly_risk_separation: array of double; {CAN BE CHANGED VIA CONFIG}
	
		cumul_separation: array[0..kMaxDurationUnionInMonths] of double;
		relRisk_separation_children_duration: separationRelRisque2Type;
	end;

{Fertility}
	setCohorts = array of longint;
	FecundAges = kMinAgeFert..kMaxAgeFert;
	DistribChildren = 0..kMaxNbChildren;
	DistribChildrenCalc = 0..kMaxNbChildrenCalc;
	TabFecundAges = array[FecundAges] of double;
	TabFecundAgesStates = array [DistribChildrenCalc, PartnershipStatusesType, UnionGenStatesType] of TabFecundAges;
	pTabFecundAges = ^TabFecundAges;
	pTabFecundAgesStates = ^TabFecundAgesStates;
	
	TabCompFertAgeStates = array[FecundAges, DistribChildrenCalc, PartnershipStatusesType, UnionGenStatesType] of longint;
	TabCompFertAge = array[FecundAges, DistribChildrenCalc] of longint;
	pTabCompFertAge = ^TabCompFertAge;

	DurationSincePreviousEventType = array [DistribChildrenCalc, -1..15] of double;
	FinalParityType = array [DistribChildrenCalc, FecundAges, 0..1] of longint;

	IntervalType = array [ageQuinq, DistribChildren, DistribChildren] of double;
	CompleteFertilityType = array[DistribChildren, PartnershipStatusesType] of longint; {Partnership Status at age 50}
	ParityProgressionType = array[DistribChildren, PartnershipStatusesType] of double;
	
	WomenPopType = array[FecundAges, PartnershipStatusesType] of longint;
	
	{kMaxAgeUnion+1 is for the total									0 in nbUnions is for the total
																		1 is the first union
																		2 is the second and more union}
	TabAgeUnionDurationNumUnionType = array[kMinAgeUnion..kMaxAgeUnion+1, 0..kMaxShownDurationUnion, 0..2] of longint;
	{																kMaxShownDurationUnion+1 is for the ISF by duration and age at union}
	FertAgeUnionDurationNumUnionType = array[kMinAgeUnion..kMaxAgeUnion+1, 0..kMaxShownDurationUnion+1, 0..2] of double;
	pTabAgeUnionDurationNumUnionType = ^TabAgeUnionDurationNumUnionType;
	pFertAgeUnionDurationNumUnionType = ^FertAgeUnionDurationNumUnionType;
	
{Mortality}
	TabSurvival = array of double;
	{TabSurvival = array[ageLife] of double;}
	pTabSurvival = ^TabSurvival;

	mortalitySettings = record
		survival_men, survival_women: TabSurvival;

		survivalAdult_women: array[agesUnion] of double;
		survivalAdult_men: array[agesUnion] of double;
	end;
		
{Kinship}
	KinshipTableType = array[KinTypes] of array[kMinAgeLife..kMaxAgeLife+1] of longint;
	KinshipStruct = array [SexTotal] of array [KinStates] of KinshipTableType;
	pKinshipStruct = ^KinshipStruct;		

	FatherChildrenState = (ageAtBirthFirst, ageAtBirthLast, ageDeathFather, ageAtUnionFirstChild, ageAtUnionLastChild, numberCases);

{DECLARATIONS_RECORD}
	
	durationValues = 0..5;
	durationEventType = (eventLiveBirth, eventEndUnion, totalEvents);
	durationCountType = array [durationEventType] of longint;
	numberDurationEventType = array [durationValues] of durationCountType;
	
	noFecundationType = record
		{Number of women who want a children, and don't have a birth or an ongoing pregnancy after 1 year, 3 years, 5 years}
		{We have to count for all the intervals, because a union can break (separation, death of partner) in between}
		number_tot: array [durationValues] of durationCountType;
		numbers: array [FecundAges, durationValues] of durationCountType;
	end;

	DurationsType = record {caution: these are durations in lunar months (kNbLunarMonths)}
		durationUnionInMonths: longint;
		durationUnionInMonthsWithSeparation: longint;
		durationAliveWoman: longint;
		durationAliveMan: longint;
		durationFecundInMonths: longint;
	end;

{FERTILITY}
	FecundLifeType = record
		ageSterile: double;
		relativeFecundabilityLevel: double;
		{== durationFecundInMonths: longint; ==}
		levelFecundabilityAge: TabFecundAges;
		// whether the woman has reached her desired fertility level
		// which corresponds to the case when a random draw is greater
		// than the PPR for her current parity
		stopping: boolean;
	end;
	
	LifeEvents = (le_sexualLifeStarted, le_union, le_endUnion, le_death);
	TabAgeEvents = array[LifeEvents] of tabSex;

const
	kInitNumberChildType = 50;
	kAddNumberChildType = 10;
	
type
	pInfoChildType = ^InfoChildType;
    arrayOfInfoChild = array of pInfoChildType;

	InfoChildType = record
		livingAtBirth: boolean;
		sex: Sex;
		birthOrder: longint;
		yearBirth: double;
		durationUnion: longint; {duration of the union at the birth of this child}
		motherUnionNumber: longint; {As father union history is not complete, the union number is not informed for him, but can be retrieved from his partners}
		ageMotherAtFecundation: double;
		ageMotherAtChildbirth: double;
		ageFatherAtChildbirth: double;
		ageDeath: double; {negative or equal to zero for a spontaneous abortion or stillbirth}
		deathChildSinceBirthOfMotherInMonths: longint; {To speed up separation calculations}
		monthStartInterval: longint; {Start of the interval before the birth of this child: month of previous delivery or month of union start}
		monthFecundation: longint; {pretty much self-explaining}
		monthEndPregnancy: longint; {pretty much self-explaining}
		monthNewOvulation: longint; {after the pregnancy}
		previous, next: pInfoChildType;
		check: longint;
		arrayChildren: arrayOfInfoChild;
		posInArray: longint; {position in arrayChildren}
	end;

	LastChildrenType = record
		Distrib: array [DistribChildren, 1..2] of double;
		Age: array[FecundAges] of double;
	end;

const
	kNotDefined = -1;
	KUnionIncr = 3;
	kMaxChildrenInListElement = 5;

type
	pRelativeType = ^RelativeType;

	UnionAgeDurationsType = record
		durations: DurationsType;
		ages: TabAgeEvents;
		nBirths: longint;
		monthStart: longint;	{start of reproductive life inside current union: month when the couple stops using contraceptive means}
		monthStop: longint;		{stop of reproductive life: month when the couple starts using contraceptive means again, because their fertile desires are fulfilled}
								{or when there is a separation or the partner dies}
		monthStopIsStopping: boolean;
	end;
	
	TUnionsType = class
		nIndividual: longint;
		gender: sex;
		nbUnions: longint;
		breakdownBySeparation: boolean; {a previous union breakdown by separation (increases the risk of another separation in the future)}
		nbChildren: longint;
		fecundLife: FecundLifeType;
		partnershipStatusAt50: PartnershipStatusesType;
		Unions: array of UnionAgeDurationsType; // CHANGE TO TLIST OR LINKED LIST
		
		constructor Create(n: longint; s: sex);
		destructor Destroy; override;
		procedure initUnion (indUnion: longint; initAges: boolean = true);
		function mySize: longint;
		procedure copyMe(var o: TUnionsType);
		procedure newUnion(initAges: boolean = true);
		procedure visualizeIncoherentUnions(forceWrite: boolean = false);
		function checkMe (pRelative: pRelativeType): boolean;
	end;

	TableUnionsType = array [	1..kMaxNbUnion+1,
								kMinAgeUnion..kMaxAgeUnion+1,
								0..kMaxDurationUnion+1, 
								CausesEndUnionType,
								0..kMaxNbChildren+1] of longint;
	pTableUnionsType = ^TableUnionsType;

{KINSHIP MODULE}
	arrayOfRelatives = array of pRelativeType;
	
	pUnionInfoType = ^UnionInfoType;
	UnionInfoType = record
		ageUnion: double;
		ageEndUnion: double;
		yearUnion: double;
		yearEndUnion: double;
		partner: pRelativeType;
		endOfPartnership: CausesEndUnionType;
		next: pUnionInfoType;
	end;

	TChildInfo = class
	private
		arrayChildInfo: arrayOfRelatives;
		next: TChildInfo;
	public
		Constructor Create;
		Destructor Destroy; override;
		procedure addChild (aChild: pRelativeType);
		function getChild (var ind: longint): pRelativeType;
	end;

	TChildList = class
	private
		nChildren: longint;
		first: TChildInfo;
	public
		Constructor Create;
		Destructor Destroy; override;
		procedure addChild (aChild: pRelativeType);
		function getChild (ind: longint): pRelativeType;
		function nbChildren: longint;
		function isChildInList (aChild: pRelativeType): boolean;
		function mySize(): longint;
	end;

	inheritanceType = record // inheritance from a decedent  
		isHeir: boolean; // this relative will be an heir if she/he is alive at death of the dead relative
						 // if the relative died before, then his own heirs can receive the inheritance anyway.
						 // If the relative died before, the share will be positive and will be the sum of his/her heirs' one
						 // Then if isHeir=1, then the relative was alive and is an heir, with a share of the inheritance
						 // Else if isHeir=0 and share > 0, then her/his heirs get the share of the inheritance
		degree: longint; // distance in the tree from the dead relative
		nLivingSiblings: longint; 	// number of living siblings that will share the inheritance
									// (we set this value even if the relative is NOT an heir,
									// as this allows to trace back the share owned by all her/his descendants)
		share: double;	// share that will receive the heir (this is always computed for ego, not necessarily for all the rest of the heirs)
		pDeadRelative: pRelativeType; // the person to be inherited (the decedent)
	end;
	
	heirInfo = record
		heir: pRelativeType;
		share: double;
		kinType: KinTypes;
		isHeir: boolean;
	end;
	inheritanceInfo = record
		decedent: pRelativeType;
		share: double;
		kinType: KinTypes;
	end;
	arrayHeirInfo = array of heirInfo;
		
	{TO CHANGE: RELATIVE IN UNION NUMBER?}
	RelativeType = record
		ageMotherAtChildbirth: double;
		ageFatherAtChildbirth: double;
		indNumber: longint; 	{a unique reference number that identify the kin.
								 the position in the current relatives list can be computed by substracting
								 ego indNumber}
		gender: Sex;
		typeOfKin: KinTypes;
		kinOf: pRelativeType; 	{typeOfKin is in relation with kinOf, usually ego).
								if kinOf is not ego, then the relatives are kin of kinOf}
		birthOrder: ShortInt;
		status: string[5]; {socio-economic variable like educational status}
		scanned: boolean;
		descendanceSimulated: boolean;
		cohort: longint; {year of birth}
		cohortDemReg: longint; {year of Demographic Regime}
		ageAtBirthOfEgo: longint; //CHANGE TO FLOAT
		yearBirth: double;
		ageDeath: double;
		yearDeath: double;
		father, mother, prevRelative, nextRelative: pRelativeType;
		motherUnionNumber: ShortInt; {Union number of biological mother}
		fatherUnionNumber: ShortInt; {Union number of biological father}
		nUnions: ShortInt;
		UList: pUnionInfoType; // created anew. We can destroy everything on exit
		partnershipStatusAt50: PartnershipStatusesType;
		childrenList: TChildList; // We cannot destroy the children info on exit, as it is referenced in ego's kinship list
		inKinSet: boolean; {whether that person is linked to at least another relative in the output file with information for each individual}

		typeHeir: typeOfHeirs;
		//egoAsHeir: typeEgoAsHeir;
		// First algorithm, with incomplete information on heirs (complete only for ego)
		nHeirs: longint;
		heirs: arrayOfRelatives;
		nInheritances: longint;
		inheritances: array of inheritanceType;
		// Second algorithm, in which we try to get all the heirs for all relatives
		// although most relatives have incomplete genealogy tree (only ego has a complete genealogy tree)
		fullTree: boolean; // whether the genealogical tree is complete and the heirs are the correct ones
		nHeirs_2: longint;
		heirs_2: array of HeirInfo;
		// in this second algorithm, we copy below the above information for the relatives who inherit
		nInheritances_2: longint;
		inheritances_2: array of inheritanceInfo;

// obsolete
{$IFDEF addOldUnionType}
		ageUnion: array [1..kMaxNbUnion] of double;
		ageEndUnion: array [1..kMaxNbUnion] of double;
		partners: array [1..kMaxNbUnion] of pRelativeType;
		endOfPartnership: array [1..kMaxNbUnion] of CausesEndUnionType;
{$ENDIF}
{$IFDEF OLDCHILDRENLIST}
		nbChildren: ShortInt;
		children: array [1..kMaxNbChildren] of pRelativeType; {only biological children} // destroy the array, not the struct pointed at
{$ENDIF}
		//useful: boolean; {whether that person is useful in the kinset: is alive or contribute a link to other living kin}
	end;

{Execution parameters}
	paramDemReg_double = (	e0_women, e0_men,
							propFinalCelibacyLow, propFinalCelibacyHigh, propFinalCelibacyMen, meanAgeUnionWomenLow, meanAgeUnionWomenHigh, meanAgeUnionMen, stdnupt,
							meanTimeContraceptionAfterUnionHigh, propContraceptionAfterUnion, effContBeforeUnion,
							freqSeparation, rel_risk_2Separation, freqSeparationFirstIteration, 
							repartnering_men_par, repartnering_women_par, repartnering_wid_men_par, repartnering_wid_women_par,
							amenorrhea_alpha, amenorrhea_beta, propWomenAtBirth);
	paramDemReg_longint = (nWomenPar, nEgoPar);
	runtimeParam_longint = (
							nStepsUnion_mean, nStepsUnion_prop, nStepsUnion_Dev, nStepsAmeno, nStepsContrFert, nStepsSeparation, nStepsContrUseAfterUnion, gBootstrap_nRuns,
							cmd_firstCohort, cmd_lastCohort, cmd_stepCohort, cmd_numberWomen
							);

	arrayDemReg_double = array [paramDemReg_double] of DoubleName;
	arrayDemReg_longint = array [paramDemReg_longint] of LongintName;

	pArrayRuntimeParam_longint = ^arrayRuntimeParam_longint;
	arrayRuntimeParam_longint = array [runtimeParam_longint] of LongintName;
	
	{output formats}
	outputKind_boolean = (
					res_fert_GenFert, res_fert_intervals, res_fert_intervals_conceptions, res_fert_LastChild,
					res_fert_durationPreviousEvent, res_fert_FinalParity_parity_age,
					res_fert_repartneringStatesType, res_fert_CTFR, res_fert_AgeChildbearing, res_fert_TotFert, res_fert_prop_single,
					res_fert_no_fecundation, res_fert_PPRs, res_fert_ageFirstUnion,
					res_fert_dump_UnionTable, res_fert_dump_UnionStates, res_fert_fertility_durationUnion, res_fert_fertility_unionStatus,
					res_kin_stats, res_kin_fathers_son, res_kin_dist, res_kin_reldist, res_kin_agedist, res_kin_numByAge,
					res_kin_unionTable, res_kin_totalNumbers,
{
					cmd_dump, cmd_dumpall, cmd_dumpallcohorts, cmd_detailed_cohort_data,
					cmd_fertility, cmd_kinship, cmd_survivalparents, cmd_constant_demreg, cmd_ppr_target,
					cmd_output_aggregate_kinship, cmd_output_individual_kinship_info,
					cmd_output_individual_fertility_info, cmd_output_exclude_abortion, cmd_output_shortfilename,
					cmd_debug,
}
					cmd_outputtomainfile
				 );
				 
const
	outputs_fertility = [res_fert_GenFert, res_fert_intervals, res_fert_intervals_conceptions, res_fert_LastChild,
						res_fert_durationPreviousEvent, res_fert_FinalParity_parity_age,
						res_fert_repartneringStatesType, res_fert_CTFR, res_fert_AgeChildbearing, res_fert_TotFert,
						res_fert_prop_single, res_fert_no_fecundation,
						res_fert_dump_UnionTable, res_fert_dump_UnionStates, res_fert_fertility_durationUnion, res_fert_fertility_unionStatus,
						res_fert_PPRs, res_fert_ageFirstUnion];
	outputs_kinship = 	[res_kin_stats, res_kin_fathers_son,
						res_kin_dist, res_kin_reldist, res_kin_agedist, res_kin_numByAge, res_kin_unionTable, res_kin_totalNumbers];
type		
	outputKind_longint = (res_numUnion, res_numBirths, res_floatingNumberDigits, res_floatingNumberPrecision, res_maxThreads,
							res_fertSurvey_ageMin, res_fertSurvey_ageMax);
	
	{============ CONTROL OF BIOLOGICAL FACTORS ============}
	fixedParameterKind = (	fixedUnionAge, noInitialSterility, fixedDefinitiveSterility, fixedAmenorrhea,
							fixedFecundability, homogeneousFecundability, HighLowFecundability, reshuffledFecundability,
							LeridonDefinitiveSterility, KinFertDefinitiveSterility, fixedIntrauterineMortality,
							homogeneousSeparation, normaldistributionfecundability, stdUnionDanielOrCampbellWood,
							waitingTimeErlangPoisson
						 );

	parameterStateArray = array [fixedParameterKind] of parameterStateName;

	pGeneralParameters = ^GeneralParameters;			
	GeneralParameters = record
		memoryAllocatedPIN: longint;
		listOfParams: GenericName; {linked list of parameters for tracking changes relative to default values
									and to release memory}

		eduKind: EduStatusName;
		kinIndFmt: KinFileFmtName;
		countryInheritance: CountryInheritanceName;
		
		{COMMAND FILE}
		DUMP, DUMPALL, DUMPALLCOHORTS, CREATE_COHORT_FILE, ZIP_INDIVIDUAL, SAVE_LOG, TALKATIVE,
		MULTITHREADING, MULTITHREADING_INIT, MULTITHREADING_INITMOTHERHOOD, MULTITHREADING_SIMKIN,
		FORCE_NUM_THREADS, USE_ARRAY_CHILDREN,
		DETAILED_COHORT_DATA, WRITE_ADJUSTED_VALUES, WRITE_ONLY_CHANGES, WRITE_FOLDER,
		FERTILITY, KINSHIP, SURVIVALPARENTS, FIXED_FERTILITY,
		STABLE_POPULATION, PPR_TARGET, FORCE_PPR_TARGET, SEP_TARGET, FORCE_SEP_ITER,
		INIT_RANDOM_NUMBERS,
		OUTPUT_INDIVIDUAL_FERTILITY_INFO,
		OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED,
		OUTPUT_INDIVIDUAL_KINSHIP_INFO,
		OUTPUT_INDIVIDUAL_AGE_FLOAT,
		NON_BIO_KIN, INHERITANCE, PARTNER_DECEDENT, ALL_EGO_PARTNERS_GENEALOGY,
		PARTNER_FIRST_HEIR, PARTNER_FULL_HEIR,
		OUTPUT_AGGREGATE_FERTILITY,
		OUTPUT_AGGREGATE_KINSHIP,
		OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES,
		OUTPUT_EXCLUDE_ABORTION,
		OUTPUT_FERT_SURVEY,
		OUTPUT_SHORTFILENAME,
		CHECK_DATASTRUCT,
		DEMOCARE_LARGE_FIELDS,
		DEBUG: BooleanName;
		NEW_INIT_MOTHERHOOD: BooleanName;
		FIXED_FERTILITY_VALUE: LongintName;
		MODEGO: LongintName;
		OPTIMAL_TREES: LongintName;
		DOCUMENTATION: StringName;

		HEIRS_KINTYPES: KinListName;
		DECEDENTS_KINTYPES: KinListName;
		OUTPUT_KINTYPES: KinListName;
		OUTPUT_KINTYPES_STD, OUTPUT_KINTYPES_DEMOCARE: KinListName;
		OUTPUT_FIELDS: FieldListName;
		OUTPUT_DIRECTORY: stringName;
		
		RUNTIME: arrayRuntimeParam_longint;
		
{INPUTS}
		fixedParameters: parameterStateArray;
{OUTPUTS}
		outputs_opt: array [outputKind_boolean] of BooleanName;
		outputs_fmt: array [outputKind_longint] of LongintName;
	end;

	{=========== Main execution parameters ========}
	pRunParamRec = ^RunParamRec;
	RunParamRec = record
		key: longint;
		indBootstrap: longint;
		indAgeUnion, indCelibacy: longint;
		indStdCel: longint;
		indFertAmeno, indFertControl, indFertSeparation, indFertContrUseAfterUnion: longint;
		valAgeUnion, valCelibacy: double;
		valStdCel: double;
		valFertAmeno, valFertControl, valFertSeparation, valFertContrUseAfterUnion: double;
		wKey, wKeyBootstrap: boolean;
		wKeyAgeUnion, wKeyCelibacy: boolean;
		wKeyStdCel: boolean;
		wKeyFertAmeno, wKeyFertControl, wKeyFertSeparation, wKeyFertContrUseAfterUnion: boolean;
	end;

	AdjustedValues = record
		aPrioriPPR: ArrayOfDoubleName;
		separation_proportion: double;
	end;
	
	arrayNbChildren = array [StatusAge50] of array [0..kMaxNbChildrenPlusUn] of longint;
	
	pStructDemographicRegimeSettings = ^structDemographicRegimeSettings;
	structDemographicRegimeSettings = record {CAN BE CHANGED VIA CONFIG}
		readInConfig: boolean; // read in config file (TRUE) or values interpolated (FALSE)
		listOfParams: GenericName; // linked list of parameters for tracking changes relative to default values
		
	{============ GENERAL PARAMETERS SET IN CONFIG ===========}
		yearOfBirth: LongintName;

	{============ GENERAL INPUT VALUES ============}
		dp: arrayDemReg_double;
		lp: arrayDemReg_longint;
		
	{============ ARRAYS OF INPUT VALUES: CONTRACEPTION BEFORE AND AFTER UNION =============}
		aPrioriPPR: ArrayOfDoubleName;
		CTFR: DoubleName; // It is not a setting proper and is a computed value: total fertility level associated with aPrioriPPR
		aPrioriPPR_adjusted: ArrayOfDoubleName;
		CTFR_adjusted: DoubleName; // It is not a setting proper and is a computed value: total fertility level associated with aPrioriPPR
		aPrioriPPR_result: ArrayOfDoubleName;
		
		{at the moment aPrioriPPR_adjusted is an internal array, but it could added to the CONFIG file
		The following array keeps track of the PPRs associated with the option PPR_TARGET}

		effStopping: ArrayOfDoubleName;
		effSpacing: ArrayOfDoubleName;
		meanTimeSpacing: ArrayOfDoubleName;

	{============ INPUT VALUES: EDUCATION ===========}
		eduEgo : Array[EduLevels, Sex] of DoubleCumulName;
		eduEgoPartner : Array[EduLevels, Sex, EduLevels] of DoubleCumulName;
		eduEgoPartnerChildren : Array[EduLevels, EduLevels, EduLevels] of DoubleCumulName;
		
	{=========== DEMOGRAPHIC REGIME STATE VARIABLES SET BY PREVIOUS PARAMETERS ============}
		{MORTALITY}
		mortalityInfo: mortalitySettings;

		{NUPTIALITY}
		nuptialityInfo: NuptialitySettings;
		pCurrUnionInfo: pNuptialitySettings;
		
		{SEPARATION}
		{**********}
		separationInfo: separationSettings;

		{FERTILITY}
		DF_apriori: double;
		
	{==== INTERNAL VARIABLES DETERMINED BY INPUT VALUES ====}
		r: double; {Intrinsic growth rate of the associated stable population}

		curr_contracepStopping: array[DistribChildren] of double; {inverse direct function of aprioriPPR}

		MeanTimeContraceptionAfterUnion: double; {mean time of contraception after the first union}
		propContraceptionAfterUnion_var: double; {proportion of women who don't use contraceptive mean during the union before the first conception}
		AccDurationContrAfterUnion: array of double; {Distribution of waiting time of contraception use after union}

		AccDurationWaitingTime: array [0..kMaxIndBirthIntervals] of array of double; {Distribution of waiting time of contraception use in birth intervals}

		distribStableFert: pTabFecundAges;

		{temporary_sterility: array[10..kMaxMonthTemporarySterility+10] of double;}
		temporary_sterility: array of double;
					
		{MAIN FERTILITY RESULTS}
		parityProgressionRatio: ParityProgressionType;
		ageChildbearing: array [DistribChildrenCalc, PartnershipStatusesType, UnionGenStatesType] of double;
		completeFertility: CompleteFertilityType; // complete fertility for women alive at 50
		df: array [DistribChildrenCalc, PartnershipStatusesType, UnionGenStatesType] of double;
{			distNbChildren: array [StatusAge50] of array of longint;
}			distNbChildren: arrayNbChildren;

		{***** UTILITIES VARIABLES ***}
		toBeInterpolated: boolean; {whether the values need to be interpolated}
		adjustedValues: boolean; {whether values were read in state file}
		interpolate_from, interpolate_until: longint;

		adjusted: AdjustedValues;
	end;
	
	GenericName = class
	public
		name: string;
		comment: string;
		changed: boolean;
		optional: boolean; // whether the variable is not used by default (if false, it is not written in the standard cohort file)
		readInConfigFile: boolean; // whether the value was read in the config file
		next: GenericName;
{$IFDEF DEBUG}
		checkIt: boolean;
{$ENDIF}

{$IFDEF DEBUG}
		constructor Create (n: string; c: string; linkedListOfParams: GenericName = nil; check: boolean = false); overload;
{$ELSE}
		constructor Create (n: string; c: string; linkedListOfParams: GenericName = nil); overload;
{$ENDIF}
		destructor Destroy; override;
		function defaultValue: string; virtual;
		function readValue (s: string): word; virtual; overload;
		procedure setChanged; virtual;
		procedure copyMeTo (var toObj: GenericName); virtual;
	end;

	LongintName = class(GenericName)
	public
		value: longint;
		default: longint;
		constructor Create(v: longint; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: LongintName); overload;
	end;

	BooleanName = class(GenericName)
	public
		value: boolean;
		default: boolean;
		constructor Create(v: boolean; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (b: boolean): word; overload;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: BooleanName); overload;
	end;

	DoubleName = class(GenericName)
	public
		value: double;
		default: double;
		constructor Create(v: double; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: DoubleName); overload;
	end;

	DoubleCumulName = class(GenericName)
	public
		value: double;
		cumulValue: double;
		default: double;
		constructor Create(v: double; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: DoubleCumulName); overload;
	end;
	
	StringName = class(GenericName)
	public
		value: string;
		default: string;
		constructor Create(v: string; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		destructor Destroy; override;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: StringName); overload;
	end;

	ArrayOfDouble = array of double;
	ArrayOfDoubleName = class(GenericName)
	public
		value: ArrayOfDouble;
		default: ArrayOfDouble;
		// last element that is unique. The rest of the array is made of identical values
		myLastEltNoChange: longint;
		myLength: longint;
		constructor Create(lengthArray: longint; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		destructor Destroy; override;
		function defaultValue: string; override;
		procedure setChanged; override;
		procedure lastElt;
		procedure setDefault;
		procedure copyMeTo (var toObj: ArrayOfDoubleName); overload;
	end;
	
	EduStatusName = class(GenericName)
	public
		value: EduStatusKinds;
		default: EduStatusKinds;
		constructor Create(v: EduStatusKinds; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: EduStatusName); overload;
	end;

	Kinship_FileFormat = out_EgoGenealogy..out_GEDCOM;
	KinFileFmtName = class(GenericName)
	public
		value: Kinship_FileFormat;
		default: Kinship_FileFormat;
		constructor Create(v: Kinship_FileFormat; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: KinFileFmtName); overload;
	end;

	Inheritance_Country_Rules = inher_Spain..inher_Other;
	CountryInheritanceName = class(GenericName)
	public
		value: Inheritance_Country_Rules;
		default: Inheritance_Country_Rules;
		constructor Create(v: Inheritance_Country_Rules; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: CountryInheritanceName); overload;
	end;

	KinListName = class(GenericName)
	public
		value: KinSetType;
		default: KinSetType;
		constructor Create(v: KinSetType; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: KinListName); overload;
	end;

	FieldListName = class(GenericName)
	public
		value: FieldSetType;
		default: FieldSetType;
		constructor Create(v: FieldSetType; n: string; c: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string): word; override;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: FieldListName); overload;
	end;

	parameterStateName = class(GenericName)
	public
		state: BooleanName;
		param: DoubleName;
		
		constructor Create(v: double; s: boolean; nState, nValue: string; cState, cValue: string; linkedListOfParams: GenericName = nil); overload;
		function defaultValue: string; override;
		function readValue (s: string; b: boolean): word; overload;
		procedure setChanged; override;
		procedure copyMeTo (var toObj: parameterStateName); overload;
	end;

var
{GLOBAL VARIABLES USED IN THE MAIN THREAD}
	g_GENPARAM: GeneralParameters;
	gWritingConfigFile: boolean = false;
	
const
	kInitCohort = 2000;

type
	fixedFertilityType = record
		ageUnionWoman, ageEndUnionWoman, ageUnionMan: double;
		nbChildren: longint;
		ageFert: array of double;
	end;

	DemRegimeCollection = record
		nCohorts: longint; // the number of cohorts less one (because we use a dynamic array)
		firstCohort, lastCohort, lastCohortAdded: longint;
		data: array of pStructDemographicRegimeSettings;
		pInit: pStructDemographicRegimeSettings; // data structure that serves for copying
		stateRead: boolean;		
	end;
	pDemRegimeCollection = ^DemRegimeCollection;

var
	g_FIXED_FERTILITY_DATA: fixedFertilityType;
	
	{Parameters for the current demographic model
	It is a pointer to one of the regimes stored in g_pCOHORT_COLLECTION}
	{*VERY* *IMPORTANT* *GLOBAL VARIABLE* THAT *SHOULD* BE MADE *LOCAL* OR PASSED BY *PARAMETER* BECAUSE
	IT IS USED IN MULTIPLE THREADS RUNNING AT THE SAME TIME}
	g_pDEM_REG: pStructDemographicRegimeSettings = nil;

	{Set of cohort Demographic Regimes, at the moment read from an external file only.
	If there is more than one Demographic Regime, than g_pDEM_REG
	will point to the current one used for individuals born that year}
	{GLOBAL VARIABLE USED IN THE MAIN THREAD (INITIALIZED AT START AND CONSIDERED AT READONLY)}
	g_pCOHORT_COLLECTION: pDemRegimeCollection = nil;
	
{DECLARATIONS_VAR}
var
{GLOBAL VARIABLES INITIALIZED IN THE MAIN THREAD (FILES)}
	g_FileName: StringName;
	g_FileName_DemographicRegime: StringName;
	g_FileName_DemographicRegime_save: StringName;

	{enfantAgeStatut: TabCompFertAgeStates;}
const
	kDeathOfMotherPossible = TRUE;
	kDeathOfFatherPossible = TRUE;
	kNoDeathOfMother = FALSE;
	kNoDeathOfFather = FALSE;
			
{INPUTS GLOBAL VARIABLES}
{THESE VARIABLES ARE INITIALIZED AT THE START OF THE PROGRAM AND DOES NOT CHANGE AFTERWARDS:
THEY CAN BE CONSIDERED AS READONLY}
var
	{Biological determinants of the fertility model}	
	gFecundability: array of double; {MODIFIABLE VIA CONFIG but constant with time}
	gSchedule_temporary_sterility: array[0..kMaxMonthTemporarySterility] of double; {constant with time}
	gDefinitive_sterility: array of double; {MODIFIABLE VIA CONFIG but constant with time}
	gMean_fecundability: double; {constant}
	gStdDev_fecundability: double; {constant}
	gDistrib_fecundability: array of double; {MODIFICABLE VIA VARIABLES BELOW constant with time}
	gFecundability_alpha, gFecundability_beta: double; {VARIABLE FOR ALTERING BETA FECUNDABILITY. AT THE MOMENT NOT ADJUSTABLE THROUGH CONFIG	 constant with time}
	
	{intrauterine mortality and stillbirths}
	gIntrauterine_mortality_risk: array of double; {MODIFIABLE VIA CONFIG but constant with time}
	gDistrib_intrauterine_mortality_risk: array of double; {MODIFIABLE VIA CONFIG but constant with time}
	gStillbirth_mortality_risk: array of double; {MODIFIABLE VIA CONFIG but constant with time}
	
{OUTPUT GLOBAL VARIABLES}
{MOST OF THESE VARIABLES CHANGE AT RUNTIME, SO WE SHOULD *CHECK* AND *DETERMINE* WHICH ARE MODIFIED INSIDE A SPECIFIC THREAD}
	g_nRuns: longint = 0; // In interactive mode, this allows us to store results and compare them for plotting
	g_nRuns_aggrKinship: longint = 0; // In interactive mode, this allows us to store results and compare them for plotting
	{A)}
	//gTOT_descFinaleAgeUnion: array [ageQuinq, DistribChildren, 1..kMax_param_TotalFertAgeUnion] of longint;
																		{For women still in union at the age of 50
																		 The last parameter makes it possible to differentiate,
																		 e.g. the case of different levels of amenorrhea}
	gParam_descFinaleAgeUnion: longint = 1; {The selection parameter of this last dimension}

	{C) We declare them here and allocate memory for them as they don't fit in the stack memory}
	//g_pGenFert: pTabFecundAgesStates; // res_fert_GenFert
	//gBirthDuration, gWomanDuration: pTabAgeUnionDurationNumUnionType;
	//gFertDuration: pFertAgeUnionDurationNumUnionType;

	{D)}
	//gOut_intervals: IntervalType; // res_fert_intervals {For women still in their first union at the age of 50.}
	{F)}
	//gOut_lastChildren: LastChildrenType; // res_fert_LastChild {For women still in their first union at the age of 50.}
	
	{G)}
	//gRepartneringStates: intensityRepartneringType;
	
	{H)}
type
	setAges = set of agesLife;
	
const
	kMaxNbAgeEgo = 7;
	
	kSetAgesEgo: setAges = [0, 5, 20, 35, 50, 65, 80, 95];
	kTotal = -1;
	kMaxNumRelatives = 10;
	kMaxNumRelatives_extended = 15;
	
type
	relativeCounts = kTotal..kMaxNumRelatives_extended;
	ageEgoInt = 0..kMaxNbAgeEgo;
	AgeEgo_arrayKinshipStruct = array [ageEgoInt] of KinshipStruct;
	KinByAgeEgoStruct = array [SexTotal, agesLife, KinTypes] of longint;
	KinByAgeEgoIndStruct = array [ageEgoInt, SexTotal, KinTypes] of longint;
	KinBySexStruct = array [SexTotal, KinTypes] of longint;
	stateTypes = (number, value, valueSquared);
	
	TUnionTable = class
	public
		pTableUnions: pTableUnionsType;
		pGenFert: pTabFecundAgesStates; // res_fert_GenFert

		constructor Create ();
		procedure Init();
		destructor Destroy (); override;
	end;
	
	TOutputFertility = class
	public
		noFecundation : array [DistribChildrenCalc] of noFecundationType;
		pBirthDuration, pWomanDuration: pTabAgeUnionDurationNumUnionType;
		pFertDuration: pFertAgeUnionDurationNumUnionType;
		TOT_descFinaleAgeUnion: array [ageQuinq, DistribChildren, 1..kMax_param_TotalFertAgeUnion] of longint;
		OUT_intervals: IntervalType; // res_fert_intervals {For women still in their first union at the age of 50.}
		OUT_lastChildren: LastChildrenType; // res_fert_LastChild {For women still in their first union at the age of 50.}	
		RepartneringStates: intensityRepartneringType;
		
		constructor Create ();
		procedure Init;
		destructor Destroy (); override;
	end;
{GLOBAL VARIABLES}
{WE SHOULD *CHECK EACH ONE* WHETHER THEY ARE USED ONLY IN THE MAIN THREAD OR ARE MODIFIED BY MULTIPLES THREADS}
var
	g_FileNames: array of string;
	gOut_totKinship: array of AgeEgo_arrayKinshipStruct;
	g_NumKinByAgeEgo: array of KinByAgeEgoStruct;
	//g_TotalBornKinship: array [KinTypes, SexTotal, kTotal..kMaxNumRelatives_extended] of longint;
	g_TotalBornKinship: array of array of array of longint;
	g_momEcAge: array [SexTotal, ageEgoInt, KinTypes, stateTypes] of double;
	g_distribKin: array [ageEgoInt, 0..kMaxNumRelatives, KinTypes] of double;
	g_distribKin_SurvEgo: array [SexTotal, ageEgoInt, 0..kMaxNumRelatives, KinTypes] of double;
	g_distribBornKins_SurvEgo: array [SexTotal, ageEgoInt, 0..kMaxNumRelatives, KinTypes] of double;

	{I)}
	//gNoFecundation : array [DistribChildrenCalc] of noFecundationType;
	
	{J)}
	//gTableUnions: pTableUnionsType;
	
	{K)}
	gOut_intervals_between_conceptions: array of array of array of double; // res_fert_intervals_conceptions
	 
	{Main execution parameters}
	RP: RunParamRec;

	gDebug_indWoman: longint;

	gMemAllocated: Longword = 0;
	gMaxMemoryAvailable: Longword = 0;

type								
	DoItModes = (initAndReadFile, initAndNoReadFile, noInitAndReadFile, noInitAndNoReadFile);
Var
	gPathToConfig, gPathToResult, gMainPathToResult: string;
	gConfigFileCollection: array of string;
	gSimulationRunning: boolean = false;

{$IFDEF LAZARUS_GUI}
	gCfgFilename: string;
	gRunFromIDE: boolean;
	gNumCoresForMultiThreading: longint;
	gNumLogicalThreadsForMultiThreading: longint;
	gMaxThreads: longint;
	gWorkingMessage: string;
	gMac: boolean;
	gBlanks: string = '';
{$ENDIF}

	procedure GenParamSetChangedValues;
	procedure LookMemory;
	function sizeOfRelativeType (pRelative: pRelativeType): longint;

	function DateTimeToMilliseconds(aDateTime: TDateTime): Int64;


	function getUnionInfoByIndex (pRelative: pRelativeType; index: longint): pUnionInfoType;
	function getNumUnionInfo (pRelative: pRelativeType): ShortInt;
	function getLastUnionInfo (pRelative: pRelativeType): pUnionInfoType;
	
{$IFDEF LAZARUS_GUI}
	procedure defaultConfigFile;
{$ENDIF}

	type
		loopTypes = (k_onlyOne, k_first, k_second, k_last);
		
implementation

uses Memory, Utilities;

{$IFDEF LAZARUS_GUI}
procedure defaultConfigFile;
begin
 gCfgFilename := 'Default values';
end;
{$ENDIF}

	function getUnionInfoByIndex (pRelative: pRelativeType; index: longint): pUnionInfoType;
	var
		ind: longint = 0;
	begin
		with pRelative^ do begin
			if (index < 1) or (index > nUnions) then begin
				result := nil;
				exit;
			end;
			result := UList;
			ind := 1;
			while (ind < index) do begin
				result := result^.next;
				ind := ind + 1;
			end;
		end;
	end;
	
	function getNumUnionInfo (pRelative: pRelativeType): ShortInt;
	var
		UInfo: pUnionInfoType;
	begin
		result := 0;
		UInfo := pRelative^.UList;
		while UInfo <> nil do begin
			Inc (result);
			UInfo := UInfo^.next;
		end;
	end;
	
	function getLastUnionInfo (pRelative: pRelativeType): pUnionInfoType;
	begin
		result := pRelative^.UList;
		if (result = nil) then exit;
		while (result^.next <> nil) and (result^.partner <> nil) do
			result := result^.next;
	end;

	function sizeOfRelativeType (pRelative: pRelativeType): longint;
	begin
		with pRelative^ do
			result :=
				sizeOf (typeOfKin) +
				sizeOf (kinOf) +
				sizeOf (birthOrder) +
				sizeOf (ageMotherAtChildbirth) +
				sizeOf (ageFatherAtChildbirth) +
				sizeOf (indNumber) +
				sizeOf (gender) +
				sizeOf (status) +
				sizeOf (scanned) +
				sizeOf (cohort) +
				sizeOf (cohortDemReg) +
				sizeOf (ageAtBirthOfEgo) +
				sizeOf (yearBirth) +
				sizeOf (ageDeath) +
				sizeOf (yearDeath) +
				4 * sizeOf (father) + // mother...
				2 * sizeOf (motherUnionNumber) +
				sizeOf (nUnions) +
				sizeOf (partnershipStatusAt50) +
				sizeOf (typeOfHeirs) +
				sizeOf (nHeirs) +
				sizeOf (heirs) +
				sizeOf (nInheritances) +
				sizeOf (inheritances) +
				sizeOf (fullTree) +
				sizeOf (nHeirs_2) +
				sizeOf (heirs_2) +
				sizeOf (nInheritances_2) +
				sizeOf (inheritances_2) +
{$IFDEF addOldUnionType}
				sizeOf (ageUnion) +
				sizeOf (ageEndUnion) +
				sizeOf (partners) +
				sizeOf (endOfPartnership) +
{$ENDIF}
				nUnions * sizeOf (UList^) +
{$IFDEF OLDCHILDRENLIST}
				sizeOf (nbChildren) +
				sizeOf (children) +
{$ENDIF}
				childrenList.mySize +
				sizeOf (inKinSet);
	end;

    function DateTimeToMilliseconds(aDateTime: TDateTime): Int64;
	var
		TimeStamp: TTimeStamp;
	begin
		{Call DateTimeToTimeStamp to convert DateTime to TimeStamp:}
		TimeStamp:= DateTimeToTimeStamp (aDateTime);
		{Multiply and add to complete the conversion:}
		DateTimeToMilliseconds := TimeStamp.Time;
	end;


{$IFDEF DEBUG}
	constructor GenericName.Create (n: string; c: string; linkedListOfParams: GenericName = nil; check: boolean = false); overload;
{$ELSE}
	constructor GenericName.Create (n: string; c: string; linkedListOfParams: GenericName = nil); overload;
{$ENDIF}
	begin
		inherited Create;
		name := n;
		comment := c;
		changed := false;
		optional := false;
		readInConfigFile := false;
{$IFDEF DEBUG}
		checkIt := check;
		if checkIt then
			checkIt := checkIt;
{$ENDIF}
		next := nil;
		if linkedListOfParams = nil then exit;
		while linkedListOfParams.next <> nil do
			linkedListOfParams := linkedListOfParams.next;
		linkedListOfParams.next := self;
	end;

	destructor GenericName.Destroy ();
	begin
{$IFDEF DEBUG}
		if checkIt then
			checkIt := checkIt;
{$ENDIF}
		inherited Destroy;
	end;

	 function GenericName.defaultValue: string;
	begin
		result := '';
	end;

	function GenericName.readValue (s: string): word;
	 begin
		result := 0;
	end;

	procedure GenericName.setChanged;
	begin
	end;
	
	procedure GenericName.copyMeTo (var toObj: GenericName);
	begin
		if toObj = nil then exit;
		toObj.name := name;
		toObj.comment := comment;
		toObj.changed := changed;
		toObj.next := nil;
	end;
	
	constructor LongintName.Create (v: longint; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function LongintName.defaultValue: string;
	begin
		result := IntToStr (default);
	end;

	function LongintName.readValue (s: string): word;
	begin
		val ( s, value, result );
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure LongintName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure LongintName.copyMeTo (var toObj: LongintName);
	begin
	 	if toObj = nil then exit;
			inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor BooleanName.Create (v: boolean; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function BooleanName.defaultValue: string;
	begin
		if default then
			result := 'TRUE or ON'
		else
			result := 'FALSE or OFF';
	end;

	function BooleanName.readValue (b: boolean): word;
	begin
		result := 0;
		value := b;
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure BooleanName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure BooleanName.copyMeTo (var toObj: BooleanName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor DoubleName.Create (v: double; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function DoubleName.defaultValue: string;
	begin
		result := FloatToStr (default);
	end;

	function DoubleName.readValue (s: string): word;
	begin
		val ( s, value, result );
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure DoubleName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure DoubleName.copyMeTo (var toObj: DoubleName);
	begin
	 	if toObj = nil then exit;
			inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor StringName.Create (v: string; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	destructor StringName.Destroy;
	begin
		inherited;
	end;
	
	function StringName.defaultValue: string;
	begin
		result := default;
	end;
	
	function StringName.readValue (s: string): word;
	begin
		  result := 0;
		  value := s;
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure StringName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure StringName.copyMeTo (var toObj: StringName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor DoubleCumulName.Create (v: double; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		cumulValue := 0;
		default := v;
	end;

	function DoubleCumulName.defaultValue: string;
	begin
		result := FloatToStr (default);
	end;

	function DoubleCumulName.readValue (s: string): word;
	begin
		val ( s, value, result );
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure DoubleCumulName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure DoubleCumulName.copyMeTo (var toObj: DoubleCumulName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.cumulValue := cumulValue;
		toObj.default := default;
	end;

	constructor ArrayOfDoubleName.Create(lengthArray: longint; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		setLength (value, lengthArray);
		myLength := lengthArray;
		myLastEltNoChange := 0;
		default := nil;
	end;

	destructor ArrayOfDoubleName.Destroy;
	begin
		setLength (value, 0);
		setLength (default, 0);
		inherited;
	end;

	procedure ArrayOfDoubleName.setChanged;
	var
		ind: longint;
	begin
		for ind := 0 to length(value) - 1 do begin
			changed := default[ind] <> value[ind];
			if changed then exit;
		end;
	end;

	procedure ArrayOfDoubleName.copyMeTo (var toObj: ArrayOfDoubleName);
	var
		ind: longint;
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.myLength := myLength;
		setLength (toObj.value, 0);
		setLength (toObj.value, length(value));
		setLength (toObj.default, 0);
		setLength (toObj.default, length(default));
		for ind := 0 to length(value) - 1 do begin
			toObj.value[ind] := value[ind];
			toObj.default[ind] := default[ind];
		end;
		toObj.myLastEltNoChange := myLastEltNoChange;
	end;

	function ArrayOfDoubleName.defaultValue: string;
	var
		ind, lg: longint;
	begin
		result := '';
		if default = nil then exit;
		lg := length(default) - 1;
		for ind := 0 to lg do begin
				result := result + LineEnding + floatToStr (default[ind]);
				if ind > 6 then begin
					result := result + LineEnding + '...';
					break;
				end;
		end;
	end;
	
	procedure ArrayOfDoubleName.lastElt;
	begin
		myLastEltNoChange := myLength-1;
		while (myLastEltNoChange > 0) and (value[myLastEltNoChange] <> value[myLastEltNoChange-1]) do
			myLastEltNoChange := myLastEltNoChange - 1;
	end;
	
	procedure ArrayOfDoubleName.setDefault;
	begin
		default := copy (value, 0, length(value));
	end;

	constructor EduStatusName.Create(v: EduStatusKinds; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function EduStatusName.defaultValue: string;
	begin
		result := strEduStatusKinds [default];
	end;

	function EduStatusName.readValue (s: string): word;
	var
		lValue: longint;
	begin
		val ( s, lValue, result );
		if (lValue < low(EduStatusKinds)) or (lValue > high(EduStatusKinds)) then
			result := 1;
		value := EduStatusKinds (lValue);
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure EduStatusName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure EduStatusName.copyMeTo (var toObj: EduStatusName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor KinListName.Create(v: KinSetType; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function KinListName.defaultValue: string;
	begin
		result := kinSetToString (default);
	end;

	function KinListName.readValue (s: string): word;
	begin
		{value := readKinSet ( s, result );
		if (result = 0) then
			readInConfigFile := true;}
		  result := 0;
	end;
	
	procedure KinListName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure KinListName.copyMeTo (var toObj: KinListName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor FieldListName.Create(v: FieldSetType; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function FieldListName.defaultValue: string;
	begin
		result := fieldSetToString (default);
	end;

	function FieldListName.readValue (s: string): word;
	begin
		{value := readFieldSet ( s, result );
		if (result = 0) then
			readInConfigFile := true;}
		  result := 0;
	end;
	
	procedure FieldListName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure FieldListName.copyMeTo (var toObj: FieldListName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor KinFileFmtName.Create(v: Kinship_FileFormat; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function KinFileFmtName.defaultValue: string;
	begin
		case default of
			 out_EgoGenealogy: result := 'out_EgoGenealogy';
			 out_DemoCare: result := 'out_DemoCare';
			 out_GEDCOM: result := 'out_GEDCOM';
		end;
	end;

	function KinFileFmtName.readValue (s: string): word;
	var
		lValue: longint;
	begin
		val ( s, lValue, result );
		if (lValue < low(Kinship_FileFormat)) or (lValue > high(Kinship_FileFormat)) then
			result := 1;
		value := Kinship_FileFormat (lValue);
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure KinFileFmtName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure KinFileFmtName.copyMeTo (var toObj: KinFileFmtName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor CountryInheritanceName.Create(v: Inheritance_Country_Rules; n: string; c: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(n, c, linkedListOfParams);
		value := v;
		default := v;
	end;

	function CountryInheritanceName.defaultValue: string;
	begin
		case default of
			 inher_Spain: result := 'Spain';
			 inher_Other: result := 'Other';
		end;
	end;

	function CountryInheritanceName.readValue (s: string): word;
	var
		lValue: longint;
	begin
		val ( s, lValue, result );
		if (lValue < low(Inheritance_Country_Rules)) or (lValue > high(Inheritance_Country_Rules)) then
			result := 1;
		value := Inheritance_Country_Rules (lValue);
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure CountryInheritanceName.setChanged;
	begin
		changed := default <> value;
	end;

	procedure CountryInheritanceName.copyMeTo (var toObj: CountryInheritanceName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		toObj.value := value;
		toObj.default := default;
	end;

	constructor parameterStateName.Create(v: double; s: boolean; nState, nValue: string; cState, cValue: string; linkedListOfParams: GenericName = nil);
	begin
		inherited Create(nState, cState, linkedListOfParams);
		state := BooleanName.Create(s, nState, cState, linkedListOfParams);
		param := DoubleName.Create(v, nValue, cValue, linkedListOfParams)
	end;

	function parameterStateName.defaultValue: string;
	begin
		if state.value then
			result := 'TRUE & Value=' + FloatToStr (param.value)
		else
			result := 'FALSE';
	end;

	function parameterStateName.readValue (s: string; b: boolean): word;
	 	begin
		val ( s, param.value, result );
		state.value := b;
		if result = 0 then begin
			// numerical value instead of boolean value, so set the latter to TRUE
			state.value := TRUE;
		end;
		result := 0;
		if (result = 0) then
			readInConfigFile := true;
	end;
	
	procedure parameterStateName.setChanged;
	begin
		state.setChanged;
		param.setChanged;
		changed := state.changed or param.changed;
	end;

	procedure parameterStateName.copyMeTo (var toObj: parameterStateName);
	begin
		if toObj = nil then exit;
		inherited copyMeTo (GenericName (toObj));
		if (state <> nil) then state.copyMeTo (toObj.state);
		if (param <> nil) then param.copyMeTo (toObj.param);
	end;

	Constructor TChildInfo.Create;
	begin
		inherited Create;
		setLength (arrayChildInfo, kMaxChildrenInListElement);
		next := nil;
	end;
	
	Destructor TChildInfo.Destroy;
	begin
		if next <> nil then
			next.Destroy;
		setLength (arrayChildInfo, 0);
		inherited Destroy;
	end;
	
	procedure TChildInfo.addChild (aChild: pRelativeType);
	var
		ind: longint;
	begin
		// find an empty slot. If none, go to next, and create it if necessary
		for ind := 1 to kMaxChildrenInListElement do
		// arrayChildInfo index is zero based
			if arrayChildInfo [ind - 1] = nil then begin
				arrayChildInfo [ind - 1] := aChild;
				exit;
			end;
		if next = nil then
			next := TChildInfo.Create();
		next.addChild (aChild);
	end;
	
	function TChildInfo.getChild (var ind: longint): pRelativeType;
	begin
		if (ind > kMaxChildrenInListElement) then begin
			// the child we look for is not in this element. We look to the following one
			ind := ind - kMaxChildrenInListElement;
			result := next.getChild (ind);
		end else begin
			result := arrayChildInfo [ind - 1];
		end;
	end;

	Constructor TChildList.Create;
	begin
		inherited Create;
		nChildren := 0;
		first := TChildInfo.Create();
	end;
	
	Destructor TChildList.Destroy;
	begin
		first.Destroy();
		inherited Destroy;
	end;
	
	procedure TChildList.addChild (aChild: pRelativeType);
	begin
		first.addChild (aChild);
		Inc (nChildren);
	end;
	
	function TChildList.getChild (ind: longint): pRelativeType;
	begin
		result := first.getChild (ind);
	end;
	
	function TChildList.nbChildren: longint;
	begin
		result := nChildren;
	end;

	function TChildList.isChildInList (aChild: pRelativeType): boolean;
	var
		ind: longint;
	begin
		result := false;
		for ind := 1 to nChildren do begin
			if (aChild = getChild (ind)) then
			begin
				result := true;
				exit;
			end
		end;
	end;

	function TChildList.mySize(): longint;
	var
		nElts: longint;
	begin
		nElts := trunc ( nChildren / kMaxChildrenInListElement ) + 1;
		result := InstanceSize + (nElts - 1) * sizeOf (first);
	end;

	constructor TUnionsType.Create(n: longint; s: sex);
	begin
		nIndividual := n;
		gender:= s;
		nbUnions := 0;
		breakdownBySeparation := FALSE;
		partnershipStatusAt50 := neverInUnion;
		nbChildren := 0;
		SetLength (Unions, KUnionIncr);
		initUnion (1);
	end;
	
	procedure TUnionsType.initUnion (indUnion: longint; initAges: boolean = true);
	var
		indStates: LifeEvents;
	begin
		with Unions [indUnion - 1] do
		begin
			monthStart := kNotDefined;
			monthStop := kNotDefined;
			monthStopIsStopping := false;
			nBirths := kNotDefined;
			durations.durationUnionInMonths := kNotDefined;
			durations.durationUnionInMonthsWithSeparation := kNotDefined;
			durations.durationAliveWoman := kNotDefined;
			durations.durationAliveMan := kNotDefined;
			durations.durationFecundInMonths := kNotDefined;
			if initAges then
				for indStates := le_sexualLifeStarted to le_death do
				begin
					Ages[indStates, woman] := kNotDefined;
					Ages[indStates, man] := kNotDefined;
				end;
		end;
	end;
	
	function TUnionsType.mySize: longint;
	begin
		result := InstanceSize + length (Unions) * sizeOf (UnionAgeDurationsType);
	end;

	procedure TUnionsType.copyMe(var o: TUnionsType);
	var
		indUnion: longint;
		ageFec: FecundAges;
	begin
	{
			*nbUnions: byte;
			*breakdownBySeparation: boolean;
			*nbChildren: byte;
			fecundLife: FecundLifeType;
			*partnershipStatusAt50: PartnershipStatusesType;
			*Unions: array of UnionAgeDurationsType;
	}
		o := TUnionsType.Create(nIndividual, gender);
		o.nbUnions := nbUnions;
		o.breakdownBySeparation := breakdownBySeparation;
		o.partnershipStatusAt50 := partnershipStatusAt50;
		o.nbChildren := nbChildren;
		o.fecundLife.ageSterile := fecundLife.ageSterile;
		o.fecundLife.relativeFecundabilityLevel := fecundLife.relativeFecundabilityLevel;
		for ageFec := low(FecundAges) to high(FecundAges) do
			o.fecundLife.levelFecundabilityAge [ageFec] := fecundLife.levelFecundabilityAge [ageFec];
		o.fecundLife.stopping := fecundLife.stopping;
		SetLength (o.Unions, nbUnions);
		for indUnion := 1 to nbUnions do begin
			o.Unions [indUnion - 1] := Unions [indUnion - 1];
		end;
	end;

	destructor TUnionsType.Destroy;
	begin
		SetLength (Unions, 0);
		inherited;
	end;

	procedure TUnionsType.newUnion (initAges: boolean = true);
	begin
		Inc (nbUnions);
		if nbUnions > length (Unions) then begin
			SetLength (Unions, length (Unions) + KUnionIncr);
		end;
		initUnion (nbUnions, initAges);
	end;

	procedure TUnionsType.visualizeIncoherentUnions(forceWrite: boolean = false);
	var
		ind: longint;
	begin
		// we check only union history of individuals with at least two unions
		if (nbUnions = 1) then exit;

		if (nbUnions > 2) then
			forceWrite := forceWrite or (Unions[1].ages[le_union, gender] < Unions[0].ages[le_endUnion, gender]);
		if (nbUnions > 3) then
			forceWrite := forceWrite or (Unions[2].ages[le_union, gender] < Unions[1].ages[le_endUnion, gender]);
		if (nbUnions > 4) then
			forceWrite := forceWrite or (Unions[3].ages[le_union, gender] < Unions[2].ages[le_endUnion, gender]);
		if forceWrite then
			for ind := 1 to nbUnions do
				memoWriteLn(['Individual: ', nIndividual, ' ', str_gender[gender] ,' ',
				Unions[ind-1].ages[le_union, man], ' ',
				Unions[ind-1].ages[le_union, woman], ' ',
				Unions[ind-1].ages[le_endUnion, man], ' ',
				Unions[ind-1].ages[le_endUnion, woman], ' ',
				Unions[ind-1].ages[le_death, man], ' ',
				Unions[ind-1].ages[le_death, woman]
			]);

	end;

	function TUnionsType.checkMe (pRelative: pRelativeType): boolean;
	var
		ind: longint;
		ageCurrUnion, ageCurrEndUnion: double;
		lastAgeUnion: double = 0.0;
		lastAgeEndUnion: double = 0.0;
	begin
		result := true;
		for ind := 1 to nbUnions do begin
			ageCurrUnion := Unions [ind - 1].ages[le_union, gender];
			ageCurrEndUnion := Unions [ind - 1].ages[le_endUnion, gender];
			if ageCurrUnion < lastAgeUnion then begin
				result := false;
				writeAndWait ('ERROR ==> Age at union not coherent in checkUnionStates, gender: '
				 				 + str_gender[gender] + ', individual: '
				 				 + inttostr(nIndividual) + ' union: ' + inttostr(ind));
			end;
			if lastAgeEndUnion > ageCurrUnion then begin
				result := false;
				writeAndWait ('ERROR ==> Age at union inferior to age at end of last union in checkUnionStates , gender: '
							 + str_gender[gender] + ', individual: '
							 + inttostr(nIndividual) + ' union: ' + inttostr(ind));
				visualizeIncoherentUnions(true);
			end;
			lastAgeUnion := ageCurrUnion;
			lastAgeEndUnion := ageCurrEndUnion;
		end;
		if nbUnions > 10 then
		begin
			result := false;
			writeAndWait ('ERROR ==> Case of more than 10 unions: ' + IntToStr (nbUnions));
		end;
	end;
	
	constructor TUnionTable.Create();
	begin
		new (pTableUnions);
		newPtr (ptr(pTableUnions), 'pTableUnions');
		new(pGenFert);
		newPtr (ptr(pGenFert), 'pGenFert');
	end;

	Destructor TUnionTable.Destroy();
	begin
{		dispose(pTableUnions);}
		disposePtr(ptr(pTableUnions), 'pTableUnions');
{		dispose(pGenFert);}
		disposePtr(ptr(pGenFert), 'pGenFert');
	end;

	procedure TUnionTable.Init();
	var
		num, age, durationUnion, nbChildren: longint;
		cause: CausesEndUnionType;

	begin
		{
		TableUnionsType = array [	1..kMaxNbUnion+1,
									kMinAgeUnion..kMaxAgeUnion+1,
									0..kMaxDurationUnion+1, 
									CausesEndUnionType,
									0..kMaxNbChildren+1] of longint;}
		for num := 1 to kMaxNbUnion+1 do
			for age := kMinAgeUnion to kMaxAgeUnion+1 do
				for durationUnion := 0 to kMaxDurationUnion+1 do
					for cause := no_union to end_allTypes do
						for nbChildren := 0 to kMaxNbChildren+ 1 do
							pTableUnions^ [num, age, durationUnion, cause, nbChildren] := 0;
	end;
		
	constructor TOutputFertility.Create();
	begin
		new(pBirthDuration);
		newPtr (ptr(pBirthDuration), 'pBirthDuration');
		new(pWomanDuration);
		newPtr (ptr(pWomanDuration), 'pWomanDuration');
		new(pFertDuration);
		newPtr (ptr(pFertDuration), 'pFertDuration');
	end;
	
	Destructor TOutputFertility.Destroy();
	begin
{		dispose(pBirthDuration);}
		disposePtr(ptr(pBirthDuration), 'pBirthDuration');
{		dispose(pWomanDuration);}
		disposePtr(ptr(pWomanDuration), 'pWomanDuration');
{		dispose(pFertDuration);}
		disposePtr(ptr(pFertDuration), 'pFertDuration');
	end;

	procedure initEventCount ( var numbers: durationCountType );
	begin
		numbers [eventLiveBirth] := 0;
		numbers [eventEndUnion] := 0;
		numbers [totalEvents] := 0;
	end;
		
	procedure TOutputFertility.Init();
	var
		ageUnion, nUnion: longint;
		ageAtUnion: ageQuinq;
		age, i, j: longint;
		ageWomen: FecundAges;
	begin
		for ageAtUnion := f1519 to f5559 do
			for i := 0 to kMaxNbChildren do
				for j := 1 to kMax_param_TotalFertAgeUnion do
					TOT_descFinaleAgeUnion[ageAtUnion, i, j] := 0;

		{Repartnering}
		for age := kMinAgeUnion to kMaxAgeSingle_women do
			for i := -1 to kMaxDurationUnion do
				RepartneringStates [woman, age, i] := 0;

		for ageWomen := kMinAgeFert to kMaxAgeFert do
			OUT_lastChildren.Age[ageWomen] := 0.0;

		for i := 0 to kMaxNbChildren do
		begin
			OUT_lastChildren.distrib [i, 1] := 0.0;
			OUT_lastChildren.distrib [i, 2] := 0.0;
			for j := 0 to kMaxNbChildren do
				for ageAtUnion := f1519 to ftotal do
					OUT_intervals [ageAtUnion, i, j] := 0.0;
		end;
		
		for i := 0 to kMaxNbChildrenCalc do begin
			for j := low (durationValues) to high (durationValues) do begin
				initEventCount (noFecundation [i].number_tot [j]);
				for ageWomen := kMinAgeFert to kMaxAgeFert do begin
					initEventCount (noFecundation [i].numbers [ageWomen, j]);
				end;
			end;
		end;

		for ageUnion := kMinAgeUnion to kMaxAgeUnion+1 do
			for i:= 0 to kMaxShownDurationUnion do
				for nUnion := 0 to 2 do begin
					pBirthDuration^ [ageUnion, i, nUnion] := 0;
					pWomanDuration^ [ageUnion, i, nUnion] := 0;
					pFertDuration^ [ageUnion, i, nUnion] := 0.0;
				end;
	end;
	
	procedure GenParamSetChangedValues;
	var
		aParam: GenericName;
	begin
		aParam := g_GENPARAM.listOfParams;
		while aParam <> nil do begin
			aParam.setChanged;
			aParam := aParam.next;
		end;
	end;
	
	procedure LookMemory;
	var
		memAvDiff, memAllDiff: Longword;
		hp: TFPCHeapStatus;
	begin
	{informative only}
		memAvDiff := gMaxMemoryAvailable;
		memAllDiff := gMemAllocated;
		gMaxMemoryAvailable := GetHeapStatus.TotalAddrSpace;
		gMemAllocated := GetHeapStatus.TotalAllocated;
		if (memAvDiff < gMaxMemoryAvailable) then
			memAvDiff := gMaxMemoryAvailable - memAvDiff
		else
			memAvDiff := gMaxMemoryAvailable;
		if (memAllDiff < gMemAllocated) then
			memAllDiff := gMemAllocated - memAllDiff
		else
			memAllDiff := gMemAllocated;
		memAvDiff := memAvDiff div (1024 * 1024);
		memAllDiff := memAllDiff div (1024 * 1024);

		hp := GetFPCHeapStatus;
	end;

end.
