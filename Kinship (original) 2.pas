{$I Defines.pas}
unit Kinship;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
    Classes,
	Math, SysUtils, Typinfo,
	{$IFDEF VerboseProfiler}Profiler,{$ENDIF}
    StringOfLib, Declarations, DemographicRegime, Fertility, FertilityRuntime, Inheritance, Nuptiality, Mortality,
	EducationalLevel, RandomNumbers, Utilities, Init, StringResources;

var
    g_endInitMotherhood: boolean;
	// Birth cohorts of egos or egos' ancestors to be simulated by the backward algorithm:
	// they are the years of births of egos as simulated by their possible mothers
	// as well as the years of births of egos' parents as simulated by their possible grand mothers
	// (we go upward for two generations only)
	gFirstCohortAncestorsChildren, gLastCohortAncestorsChildren: longint;
	// Birth cohorts of women possible mothers or grand mothers of egos
	gFirstCohortWomen, gLastCohortWomen: longint;
	// Birth cohorts of women possible brides or grand mothers of egos
	gFirstCohortBrides, gLastCohortBrides: longint;
	// Birth cohorts of grooms simulated in the backward algorithm
	gFirstCohortGrooms, gLastCohortGrooms: longint;
	// year range for unions with brides (obsolete)
	gFirstYearUnions, gLastYearUnions: longint;
	
	// When using the backward algorithms of BACKFOR and CAMSIM (various versions)
	gBACKFOR_mode: boolean = false;
	gBACKFOR_mode_pure: boolean = false;
	gCAMSIM_1987: boolean = false;
	gCAMSIM_1993: boolean = false;
	gCAMSIM_1993_unbounded: boolean = true;
	gBACKFOR_women, gBACKFOR_nTries: longint;
	
	{The following arrays record the number of access to the range arrays for children, brides, grooms,
	etc, by birth or calendar year, in order to check whether the ranges of years used are wide enough.
	In order to do that, these arrays use wider ranges of years (plus or minus kStateRangeLengthLimit),
	so that we can check whether we need a wider range for each of the preceding ones}
	{In fact we will use only the arrays for Children (by year of birth) and Grooms (by year of birth and age at union).
	Tracking mothers, brides and year of union was useful in alternate and now obsolete versions of the algorithm}
	gStateChildren, gStateGrooms: array of longint;
	// OBSOLETE
	gStateBrides, gStateMothers, gStateYearUnions: array of longint;
{$IFDEF DEBUG}
	gAgeChildbearing, gAgeChildbearingBACKFOR, gAgeChildbearingBACKFOR_post: array [FecundAges] of longint;
{$ENDIF}
const
	// when looking at mothers, brides or year of unions, we may have a lot of values out of range
	// when accessing the RangeXXXX arrays.
	// we keep track of that through the statesXXXX arrays which record the index values used
	// when accessing RangeXXXX arrays. RangeXXXX arrays each have a range of possible values for the index.
	// stateXXXX arrays have a wider range of values, with kStateRangeLengthLimit more on the left and on the right
	// That way we know whether RangeXXXX ranges are too short and should be extended
	kStateRangeLengthLimit = 30;

	procedure initMotherhood (randomGenerator: TRandomNumberGenerator);
	procedure disposeMotherhood;
	procedure disposeMotherhood_DemReg;
	function openFileKinship (bootstrap_ind: longint): boolean;
	procedure survivalParents (randomGenerator: TRandomNumberGenerator; cohort: longint; writeAges, writeSurvival: boolean);
	procedure setKinshipToSimulate (kinsToSimulate: KinSetType; writeIt: boolean = false);
	procedure initComputeStatesKinship (sCohorts: setCohorts);
	procedure simulateKinship (randomGenerator: TRandomNumberGenerator; cohort: longint; bootstrap_ind: longint; loopPhase: loopTypes);
	procedure computeStatesKinship;
	procedure computeMenWomen2WaysTable;

	function readDemocareFile (path, filename: string): boolean;
	procedure setChildren (pMain, pKinOf: pRelativeType; kinTypeChild, kinTypeGrandChild: KinTypes);
	procedure setPartners (pMain, pKinOf: pRelativeType; kinTypeChild, kinTypeGrandChild: KinTypes);

	function byUnion (pEgo, pRelative: pRelativeType): boolean;
	function getNumChildren (pRelative: pRelativeType): longint;
	function getChildFromRelative (pRelative: pRelativeType; ind: longint): pRelativeType;

	procedure addToCohortSet (cohort: longint; var sC: setCohorts);

var
	gViewFromEgo: longint = 0;
	gViewToEgo: longint = 0;
	gViewEgos: array of longint;
	
implementation
	uses LazUtiles;

	const
		kMaxAgeUnionMale = 71;
		// value used to grow RangeBirthsXXX arrays by SetLength
		kSetLengthBirths = 50;
		// value used to grow RangeBridesXXX arrays by SetLength
		kSetLengthBrides = 50;
		// value used to grow RangeGroomsXXX arrays by SetLength
		kSetLengthGrooms = 50;
		// value used to grow RangeYearUnionXXX arrays by SetLength
		kSetLengthUnions = 50;
		// value used to grow gBig_ArrayWomen by SetLength
		kSetWomen = 1000;

	Type
		TWomanMemoryBlock = class
		public
			idWoman: longint;
			cohort: smallint;
			dateBirth: DateOfBirthType;
			nbChildren: longint;
			unionStates: TUnionsType;
			arrayChildren: arrayOfInfoChild;
			pChildrenList: pInfoChildType;

			Constructor Create(randomGenerator: TRandomNumberGenerator;
							idMother, cohortMother, nC: longint;
							ms: TUnionsType;
							pCh: pInfoChildType;
							const aC: arrayOfInfoChild;
							ageUnionTrunc: double = 0.0); overload;
			Destructor Destroy(); override;
			procedure truncateAtAge (ageUnionTrunc: double);
			function mySize: longint;
		
{$IFDEF DEBUG}
function hasChild (bornOnYear: longint): boolean;
function checkOwnUnionStates: boolean;
function checkUnionStates (ms: TUnionsType): boolean;
function checkOwnChildrenList: boolean;
function checkChildrenList (nC: longint; pChild: pInfoChildType): boolean;
{$ENDIF}
		end;

		TWomenMemoryManager = class
		private
			womenList: array of array of array of TWomanMemoryBlock;
			nWomen: longint;
			countLevel1, countLevel2: longint;
			nw_level1, nw_level2, nw_level3: longint;
			destroyWomenCollection: boolean;
	
		public
			Constructor Create (approxSize: longint = 0;
				destroyWomanObjOnExit: boolean = true);
			Destructor Destroy; override;
			function addWoman (aWomanObj: TWomanMemoryBlock): boolean;
			function getWoman (womanInd: longint): TWomanMemoryBlock;
			function numWomen(): longint;
			procedure indexToArrayPos (womanInd: longint; out ind1, ind2, ind3: longint);
			function arrayPosToIndex (ind1, ind2, ind3: longint): longint;
		end;

		CohortDataType = record
			pDemReg: pStructDemographicRegimeSettings;
			nWomen, cohort: longint;
		end;
		
		pThreadCohortDataArray = ^ThreadCohortDataArray;
		ThreadCohortDataArray = record
			arrayOfData: array of CohortDataType;
			womenType: string;
			womenCollection: TWomenMemoryManager;
		end;

		pThreadCohortData = ^ThreadCohortData;
		ThreadCohortData = record
			pDemReg: pStructDemographicRegimeSettings;
			nWomen, cohort: longint;
			womenType: string;
			womenCollection: TWomenMemoryManager;
		end;

		TBigCohortsWomenSet = class(TThread)
		private
			FAFinished: boolean;
			myThreadNumber: longint;
			myData: ThreadCohortDataArray;
            myRandomGenerator: TRandomNumberGenerator;
            MyWomenCount: longint;
		public	
			Constructor Create(CreateSuspended : boolean; pData: pThreadCohortDataArray; ind: longint); overload;
            Destructor Destroy (); override;
			procedure Execute; override;
			property AFinished: boolean read FAFinished write FAFinished;
		end;

		TCohortWomenSet = class(TThread)
		private
			FAFinished: boolean;
			myThreadNumber: longint;
			myData: ThreadCohortData;
			myRandomGenerator: TRandomNumberGenerator;
		public	
			Constructor Create(CreateSuspended : boolean; pData: pThreadCohortData; ind: longint); overload;
			Destructor Destroy(); override;
			procedure Execute; override;
			property AFinished: boolean read FAFinished write FAFinished;
		end;

		pEgoTreeData = ^EgoTreeData;
		EgoTreeData = record
			yearOfBirthEgo: longint;
		end;

		TSimulEgoTree = class(TThread)
		private
			FAFinished: boolean;
			myExecuteIt: boolean;
			myThreadNumber: longint;
			pMyData: pEgoTreeData;
			myTotalKinCount: longint;
			pMyEgos: array of pRelativeType;
			myNumTreesStored: longint;
			myRandomGenerator: TRandomNumberGenerator;
			arrayChildren: arrayOfInfoChild;
			
		public	
			Constructor Create(pData: pEgoTreeData; ind: longint; maxNumTrees: longint); overload;
			Destructor Destroy; override;
			procedure Terminate; overload;
			procedure initTrees (num: longint);
			procedure Execute; override;
			function Simulate(numEgos: longint): boolean;
			function meanNumberOfKins: double;
			function UpdateKinNumber (offsetNumber: longint): boolean;
			property AFinished: boolean read FAFinished write FAFinished;
		end;
				
		personsOrBirths = (cf_persons, cf_births);
		catUnion = (cu_person, cu_firstUnion, cu_firstSeparation, cu_firstWidowhood,
					cu_secondUnionAfterSeparation, cu_secondUnionAfterWidowhood);
		catMulti = (cm_person, cm_firstUnion, cm_firstSeparation, cm_firstWidowhood,
					cm_secondUnionAfterSeparation, cm_secondUnionAfterWidowhood,
					cm_death_single, cm_death_firstUnion, cm_death_firstSeparation, cm_death_firstWidowhood,
					cm_death_secondUnionAfterSeparation, cm_death_secondUnionAfterWidowhood);

		KinshipInfo = record
			pEgo: pRelativeType;
			nKin: longint;
		end;

		arraySexCatUnionAgeType = array [Sex] of array [catMulti] of array [agesLife] of longint;
		arraySexCatUnionDurationType = array [Sex] of array [catMulti] of array [durationsUnion] of longint;
		resMultipleType = (mu_never, mu_FirstWidowhood, mu_FirstSeparation, mu_SecondUnionWidowhood, mu_SecondUnionSeparation);
		arrayMultipleType = array [Sex] of array [resMultipleType] of double;
		
		DemocareTypes = (dt_id,dt_sex,dt_age,dt_ageDef,dt_status,dt_tickIn,dt_tickOut,dt_linked,dt_ego,dt_useful,dt_partnershipStatus,dt_cohort,dt_cohortRegDem,dt_relative,dt_alliance,dt_ageAtTickZero,dt_nChildren);

	var
		gThisIsNotanArrayOfBrides: boolean = true; // this is a mothers' array!!

	var
{$IFDEF DEBUG}
gCheckRelativesCount: longint = 0;
gCheckRelativesMax: longint = 0;
gNumEgoMen, gNumEgoWomen, gChildrenEgoMen, gChildrenEgoWomen: longint;
gIndMother: longint = 0;
gIndEgo: longint = 0;
{$ENDIF}
		// set of year of births of the cohorts with different demographic regimes
		g_setCohorts: setCohorts; // READ_ONLY - THREAD SAFE
		// DemoCare file does not have age at union info so 'g_AgeUnionAvailable' keeps track of that...
		g_AgeUnionAvailable: boolean = TRUE;
		// Arrays used for computing fertility and nuptiality levels from kin networks in order to check the results
		// 1. Fertility by age for egos' mothers, taking the sex of ego into account
		g_fertilityEgoMothers: array of array [Sex] of array [personsOrBirths] of array [FecundAges] of longint; // MAIN THREAD
		// 2. Fertility by age of egos with at least one child, for comparison sake with egos' mother fertility
		g_fertilityEgosWithAtLeastOneChild: array of array [Sex] of array [personsOrBirths] of array [FecundAges] of longint; // MAIN THREAD
		// 3. Distribution of number of children of egos' mothers, taking the sex of ego into account
		g_NumChildrenEgoMothers: array of array [Sex] of array [DistribChildren] of longint; // MAIN THREAD
		// 4. Fertility by age of egos, for computing age rates
		g_fertilityEgos: array of array [personsOrBirths] of array [Sex] of array [FecundAges] of longint; // MAIN THREAD
		// 5. Distribution of number of children of egos, taking her/his sex into account
		g_NumChildrenEgos: array of array [Sex] of array [DistribChildren] of longint; // MAIN THREAD
		// 6. Fertility by age of egos' first partner, for computing age rates
		g_fertilityEgoPartners: array of array [personsOrBirths] of array [Sex] of array [FecundAges] of longint; // MAIN THREAD
		// 7. Distribution of number of children of egos' first partner, taking her/his sex into account
		g_NumChildrenEgoPartners: array of array [Sex] of array [DistribChildren] of longint; // MAIN THREAD
		// 8. Distribution of number of children of egos by union status at age 50
		g_DistNbChildren: array of arrayNbChildren; // MAIN THREAD
		// 9. Arrays used for computing union formation and separation indicators and frequencies from kin network
		// For computing mean age at first union of ego and their parents 
		g_UnionTable: array of array [Sex] of array [agesUnion] of longint; // MAIN THREAD
		g_UnionTableEgoParents: array of array [Sex] of array [agesUnion] of longint; // MAIN THREAD
		// Table for union formation and separation: we follow only first union formation and separation
		g_Union: array of array [Sex] of array [catUnion] of longint; // MAIN THREAD
		// Count of persons and events for computing the multistate table by for union formation and separation
		g_UnionMultiState: array of arraySexCatUnionAgeType; // MAIN THREAD
		g_UnionDurationMultiState: array of arraySexCatUnionDurationType; // MAIN THREAD
		// old results...
		gAgeFatherAgeSon: array[FatherChildrenState] of longint; // MADE THREAD SAFE (using InterlockedIncrement)
		
	const
		kNumWomen_Level3 = 10000;
		kNumWomen_Level2 = 100;
		kNumWomen_Level1 = 100;
	
	var
		{We simulate the lifecycle of a set of women who could be mothers of ego
		or her/his parents, or even her/his grand parents, when we look for the ancestry of kin.
		First each kin has a mother, who is then linked to a father, then in turn each one
		is attributed a mother in the same stochastic way, then a father, etc
		Then each couple of parents or grand parents may have children than
		will be siblings or aunts and uncles of ego, and those in turn may have children that
		will be nieces/nephews or fist cousins of the representative person (ego)
		This set of women is also useful when looking for brides of kin,
		especially in the case when there are separations and second unions. When we are
		simulating the life of a male kin, we set first an age at first union
		and then the age at union of his bride then in case of a separation, we determine
		an age at second union and again look for a bride, etc. But this woman could have had previous
		unions, so we select a woman from the already
		set of simulated women and we retain her lifecycle up to the age at union with the
		kin we simulate (so we truncate her lifecycle after this age).
		There are two mechanisms to select a bride:
		1. The old one is based on the age of the groom, then the age of the bride which allow determining her year of birth
		2. The new one is based on the range of bride who form an union in a specific year with a groom with a specific age at union. We then select a bride at random and
		we have at a result her age at union, which micmic the mechanism for selecting a mother from her births
		}
// for stable populations, we use a separate array for brides in order to minimize memory
		gBig_ArrayBrides_NEW: TWomenMemoryManager; // possible brides // MAIN THREAD
		gBig_ArrayWomen_NEW: TWomenMemoryManager; // possible mothers // MAIN THREAD
		{The following two arrays keeps track of possible mothers according to
		the year of birth of their children and the age at childbearing}
		g_RangeBirthsNb: array of longint; // MAIN THREAD
		g_RangeBirthsInfo: array of array of longint; // MAIN THREAD
		{Number of women simulated in each cohort for the big array}
{$IFDEF OLD_INITMOTHERHOOD}
		g_WomenPopNumbers: array of longint; // MAIN THREAD
		g_BridesPopNumbers: array of longint; // MAIN THREAD
{$ENDIF}
		{NOT USED AT THE MOMENT}
		//RangeWomenInfo: array of array of longint;
		{******* ALTERNATE AND OBSOLETE *****}
		{Two arrays to keep track of possible brides according to their year of birth
		and age at union}
		g_RangeBridesNb: array of array of longint; // MAIN THREAD
		g_RangeBridesInfo: array of array of array of longint; // MAIN THREAD
		{******* END *****}
		{======== MAIN ALGORITHM USE THESE ARRAYS ==============}
		{Two arrays to keep track of brides classified by grooms' birth cohort and age at union}
		g_RangeGroomsNb: array of array of longint; // MAIN THREAD
		g_RangeGroomsInfo: array of array of array of longint; // MAIN THREAD
		// one array of statistical nature to keep track of cohort and ages of groom at union with no corresponding brides
		g_RangeGroomsNotFound: array of array of longint; // MAIN THREAD
		{======== END ==============}
		{******* ALTERNATE AND OBSOLETE *****}
		{Two more arrays to keep track of possible brides according to year of union and age at union of grooms}
		g_RangeYearUnionsNb: array of array of longint; // MAIN THREAD
		g_RangeYearUnionsNotFound: array of array of longint; // MAIN THREAD
		g_RangeYearUnionsInfo: array of array of array of longint; // MAIN THREAD
		{******* END *****}

		{Keep track of mothers according to year of birth of their children, and age at current union (in order to test Le Bras's BACKFOR algorithm)}
		RangeBirthsBACKFORNb: array of array of longint;
		RangeBirthsBACKFORInfo: array of array of array of longint;
		{The following two arrays keeps track of possible mothers according to
		the year of birth of their children, the age at childbearing and the number of births (for CAMSIM1993)}
		CAMSIM_RangeBirthsNb: array [DistribChildrenCalc] of array of longint;
		CAMSIM_RangeBirthsInfo: array [DistribChildrenCalc] of array of array of longint;

		{First union of men by birth cohort, age at union and age at union of bride}
		gMen_Women : array of array of array of longint; // MADE THREAD SAFE (using InterlockedIncrement)

	function getWomanFromBigArray (womanInd: longint; arrayMothers: boolean = TRUE): TWomanMemoryBlock;
	begin
		if arrayMothers then
			result := gBig_ArrayWomen_NEW.getWoman (womanInd);
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if not arrayMothers then
			result := gBig_ArrayBrides_NEW.getWoman (womanInd);
		end else begin
			if not arrayMothers then
				writeAndWait('Problem getWomanFromBigArray');
		end;
		
	end;

	function isChildAlreadyInList (pRelative, pChild: pRelativeType): boolean;
{$IFDEF OLDCHILDRENLIST}
	var
		indCh: longint;
		resultOld: boolean = false;
{$ENDIF}
	begin
{$IFDEF OLDCHILDRENLIST}
		result := false;
		if pRelative^.nbChildren > 0 then
			for indCh := 1 to pRelative^.nbChildren do
				if pChild = pRelative^.children[indCh] then begin
					resultOld := true;
					exit;
				end;
{$ENDIF}
		result := pRelative^.childrenList.isChildInList (pChild);
{$IFDEF OLDCHILDRENLIST}
		if result <> resultOld then
			writeAndWait ('Problem isChildAlreadyInList');
{$ENDIF}
	end;

	function getNumChildren (pRelative: pRelativeType): longint;
{$IFDEF OLDCHILDRENLIST}
	var
		resultOld: longint = 1000;
{$ENDIF}
	begin
{$IFDEF OLDCHILDRENLIST}
		resultOld := pRelative^.nbChildren;
{$ENDIF}
		result := pRelative^.childrenList.nbChildren();
{$IFDEF OLDCHILDRENLIST}
		if result <> resultOld then
			writeAndWait ('Problem getNumChildren');
{$ENDIF}
	end;

	procedure emptyRelativeChildList (pRelative: pRelativeType);
{$IFDEF OLDCHILDRENLIST}
	var
		ind: longint;
{$ENDIF}
	begin
{$IFDEF OLDCHILDRENLIST}
		for ind := 1 to pRelative^.nbChildren do begin
			pRelative^.children [ind] := nil;
		end;
		pRelative^.nbChildren := 0;
{$ENDIF}
		pRelative^.childrenList.Destroy();
		pRelative^.childrenList := TChildList.Create()
	end;
	
	procedure addChildToRelative (pRelative, pChild: pRelativeType);
	begin
{$IFDEF OLDCHILDRENLIST}
		Inc (pRelative^.nbChildren);
		pRelative^.children [pRelative^.nbChildren] := pChild;
{$ENDIF}
		pRelative^.childrenList.addChild (pChild);
	end;
	
	function getChildFromRelative (pRelative: pRelativeType; ind: longint): pRelativeType;
{$IFDEF OLDCHILDRENLIST}
	var
		resultOld: pRelativeType = nil;
{$ENDIF}
	begin
{$IFDEF OLDCHILDRENLIST}
		resultOld := pRelative^.children [ind];
{$ENDIF}
		result := pRelative^.childrenList.getChild (ind);
{$IFDEF OLDCHILDRENLIST}
		if result <> resultOld then
			writeAndWait ('Problem getChildFromRelative');
{$ENDIF}
	end;
	
	procedure incrementNbChildren (var distNbChildren: arrayNbChildren; nbChildren, nbUnion: longint; ageDeathWoman, ageEndFirstUnion: double);
	begin
		Inc (distNbChildren [allStates50, nbChildren]);
		if nbUnion > 0 then begin
			if (ageDeathWoman >= 50) then
				Inc (distNbChildren [alive50EverInUnion, nbChildren]);
			if (ageEndFirstUnion >= 50) then
				Inc (distNbChildren [aliveWithFirstPartner50, nbChildren]);
		end;
	end;
	
{$IFDEF DEBUG}
function TWomanMemoryBlock.hasChild (bornOnYear: longint): boolean;
var
	pChild: pInfoChildType;
	
begin
	result := false;
	pChild := pChildrenList;
	while pChild <> nil do begin
		if pChild^.livingAtBirth then begin
			if 	(pChild^.dateBirth.yearBirth = bornOnYear) then
			begin
				result := true;
				break;
			end;
		end;
		pChild := pChild^.next;
	end;
end;

function TWomanMemoryBlock.checkOwnUnionStates: boolean;
begin
	result := checkUnionStates(unionStates);
end;

function TWomanMemoryBlock.checkUnionStates (ms: TUnionsType): boolean;
begin
	result := ms.checkMe(nil);
end;

function TWomanMemoryBlock.checkOwnChildrenList: boolean;
begin
	result := checkChildrenList(nbChildren, pChildrenList);
end;

function TWomanMemoryBlock.checkChildrenList (nC: longint; pChild: pInfoChildType): boolean;
var
	ind: longint;
begin
	ind := 0;
	result := true;
	while pChild <> nil do begin
		if pChild^.check <> kInfoChildCheck then begin
			writeAndWait ('Bad pointer children list in checkChildrenList: ' + IntToStr (ind));
			exit;
		end;
		if pChild^.livingAtBirth then ind := ind + 1;
		if ind > nC then begin
			writeAndWait ('Nil pointer masked mother in checkChildrenList: ' + IntToStr (ind));
			result := false;
			break;
		end;
		if pChild^.motherUnionNumber > 10 then begin
			writeAndWait ('Too much mothers in checkChildrenList: ' + IntToStr (pChild^.motherUnionNumber));
			result := false;
			break;
		end;
		if pChild^.birthOrder > 35 then begin
			writeAndWait ('Too much children in checkChildrenList: ' + IntToStr (pChild^.birthOrder));
			result := false;
			break;
		end;
		pChild := pChild^.next;
	end;
end;
{$ENDIF}

	// This object copy info from a bride and adjust it to the current groom
	Constructor TWomanMemoryBlock.Create(randomGenerator: TRandomNumberGenerator;
        								idMother, cohortMother, nC: longint;
                                        ms: TUnionsType;
                                        pCh: pInfoChildType;
                                        const aC: arrayOfInfoChild;
                                        ageUnionTrunc: double = 0.0); overload;
	var
		statutEndUnion: PartnershipStatusesType;

	begin
		inherited Create();
{$IFDEF DEBUG}
if gRunFromIDE then begin
	checkUnionStates (ms);
	checkChildrenList (nC, pCh);
end;
{$ENDIF}
		idWoman := idMother;
		cohort := cohortMother;
		// the mother has a year of birth and we set a month of birth...
		dateBirth.yearBirth := cohort;
		dateBirth.monthBirth := trunc (randomGenerator.alea (1, kNbLunarMonths + 0.9999999999));
		dateBirth.dayBirth := trunc (randomGenerator.alea (1, 30.9999999999));
		nbChildren := nC;
		ms.copyMe (unionStates);
		arrayChildren := aC;
		if (arrayChildren = nil) or (length(arrayChildren) = 0) then
			// we do not use array of children and we copy the linked list
			pChildrenList := duplicateChildrenList (pCh)
        else
            // we have an arrayChildren and we use it to copy the childrenList
			pChildrenList := duplicateChildrenList_AC (pCh, arrayChildren);

		incrementNbChildren (
					getCohort_p(cohort)^.distNbChildren,
					nbChildren,
					unionStates.nbUnions,
					unionStates.Unions [0].ages[le_death, woman],
					ageWomenEndUnion (unionStates.Unions [0].ages, statutEndUnion));
{		Inc (getCohort_p(cohort)^.distNbChildren [allStates50, nbChildren]);
		if (unionStates.Unions [0].ages[le_death, woman] >= 50) then
			Inc (getCohort_p(cohort)^.distNbChildren [alive50EverInUnion, nbChildren]);
		if (ageWomenEndUnion (unionStates.Unions [0].ages, statutEndUnion) >= 50) then
			Inc (getCohort_p(cohort)^.distNbChildren [aliveWithFirstPartner50, nbChildren]);
}		
		if (ageUnionTrunc > 0) then
			truncateAtAge (ageUnionTrunc);
{$IFDEF DEBUG}
if gRunFromIDE then begin
	checkOwnUnionStates;
	checkOwnChildrenList;
end
{$ENDIF}
	end;

	Destructor TWomanMemoryBlock.Destroy;
	begin
		disposeChild (pChildrenList);
		FreeAndNil (unionStates);
		inherited Destroy;
	end;

	procedure TWomanMemoryBlock.truncateAtAge (ageUnionTrunc: double);
	var
		indUnion, indUnion2: longint;
		aSex: Sex;
		pChild: pInfoChildType;
		truncateIt: boolean;
		
	begin
	//eliminating unions and children which occurred after ageUnionTrunc

		// Start with unions
		truncateIt := false;
		for indUnion := 1 to unionStates.nbUnions do
			if unionStates.Unions [indUnion - 1].ages[le_union, woman] > ageUnionTrunc then begin
				truncateIt := true;
				break;
			end;

		if truncateIt then begin
			// the last union is to be truncated so we decrement indUnion to get to the current union
			indUnion := indUnion - 1;
		end;
		
		// Delete info for the union that starts at age 'ageUnionTrunc'
		// retaining only useful info for the woman
		unionStates.Unions [indUnion - 1].ages[le_union, man] := kNotDefined;
		unionStates.Unions [indUnion - 1].ages[le_death, man] := kNotDefined;
		unionStates.Unions [indUnion - 1].ages[le_endUnion, man] := kNotDefined;
		unionStates.Unions [indUnion - 1].ages[le_endUnion, woman] := kNotDefined;
		// Delete info for unions that start after 'ageUnionTrunc'
		if truncateIt then begin
			for indUnion2 := indUnion + 1 to unionStates.nbUnions do
				for aSex := man to woman do begin
					unionStates.Unions [indUnion2 - 1].ages[le_union, aSex] := kNotDefined;
					unionStates.Unions [indUnion2 - 1].ages[le_death, aSex] := kNotDefined;
					unionStates.Unions [indUnion2 - 1].ages[le_endUnion, aSex] := kNotDefined;
				end;
		end;
		// indUnion points to the last useful union
		unionStates.nbUnions := indUnion - 1;

		// Now delete children born or abortions whose fecundation occurred after 'ageUnionTrunc'
		pChild := pChildrenList;
		nbChildren := 0;
		//gotoToFirstLiveBornChild (pChild);
		while pChild <> nil do begin
			if pChild^.ageMotherAtFecundation >= ageUnionTrunc then
				break;
			if pChild^.livingAtBirth then Inc (nbChildren);
			//gotoToNextLiveBornChild (pChild);
			pChild := pChild^.next;
		end;
		if pChild <> nil then begin
			if pChild^.previous <> nil then begin
				// is this a child of order > 1?
				pChild^.previous^.next := nil;
				disposeChild (pChild);
			end else begin
				// we are deleting everything, starting with the first child
				// so dispose of the whole linked list
				disposeChild (pChildrenList);
			end;
		end;
	end;

	function TWomanMemoryBlock.mySize: longint;
	begin
		result := 	sizeOf (idWoman) +
					sizeOf (cohort) +
					sizeOf (dateBirth) +
					sizeOf (nbChildren) +
					childInfoSizeOf (pChildrenList) +
					unionStates.mySize;
	end;

{$IFDEF CHANGE_IN_MAY2024}
	Constructor TWomenMemoryManager.Create (approxSize: longint = 0;
		destroyWomanObjOnExit: boolean = true);
	begin
		if (approxSize = 0) then begin
			nw_level1 := kNumWomen_Level1;
			nw_level2 := kNumWomen_Level2;
			nw_level3 := kNumWomen_Level3;
		end else begin
			nw_level1 := 3;
			nw_level3 := min (5000, trunc (approxSize / 3));
			nw_level2 := trunc (approxSize / nw_level3) + 2;
		end;
		destroyWomenCollection := destroyWomanObjOnExit;
		nWomen := 0;
		setLength (womenList, nw_level1);
		countLevel1 := 1;
		setLength (womenList[0], nw_level2);
		countLevel2 := 1;
		setLength (womenList[0, 0], nw_level3);
	end;
{$ELSE}
	Constructor TWomenMemoryManager.Create (approxSize: longint = 0;
		destroyWomanObjOnExit: boolean = true);
	begin
		if (approxSize = 0) then begin
			nw_level1 := kNumWomen_Level1;
			nw_level2 := kNumWomen_Level2;
			nw_level3 := kNumWomen_Level3;
		end else begin
			nw_level1 := 1;
			nw_level3 := max (kNumWomen_Level3, trunc (approxSize / 3));
			nw_level2 := trunc (approxSize / nw_level3) + 1;
		end;
		destroyWomenCollection := destroyWomanObjOnExit;
		nWomen := 0;
		setLength (womenList, nw_level1, nw_level2, nw_level3);
		countLevel1 := 1;
		countLevel2 := 1;
	end;
{$ENDIF}
	
	Destructor TWomenMemoryManager.Destroy;
	var
		ind: longint;
	begin
		if destroyWomenCollection then
			for ind := 1 to nWomen do
				getWoman (ind - 1).Destroy;
		setLength (womenList, 0);
	end;

{$IFDEF CHANGE_IN_MAY2024}
	function TWomenMemoryManager.addWoman (aWomanObj: TWomanMemoryBlock): boolean;
	var
		ind1, ind2, ind3: longint;
	begin
		result := false;
		Inc (nWomen);
		self.indexToArrayPos (nWomen - 1, ind1{%H-}, ind2, ind3{%H-});
		if (ind1 > nw_level1) then begin
			Inc (nw_level1);
			setLength (womenList, nw_level1, nw_level2, nw_level3);
		end;
		if (ind1 > countLevel1 - 1) then begin
			Inc (countLevel1);
		end;
		if (ind2 > countLevel2 - 1) then begin
			Inc (countLevel2);
		end;
		womenList [ind1, ind2, ind3] := aWomanObj;
		result := true;
	end;
{$ELSE}
	function TWomenMemoryManager.addWoman (aWomanObj: TWomanMemoryBlock): boolean;
	var
		ind1, ind2, ind3: longint;
	begin
		result := false;
		Inc (nWomen);
		self.indexToArrayPos (nWomen - 1, ind1{%H-}, ind2, ind3{%H-});
		if (ind1 > length (womenList) - 1) then begin
		// Out of memory
			exit;
		end;
		if (ind1 > countLevel1 - 1) then begin
			Inc (countLevel1);
			setLength (womenList[ind1], nw_level2);
			// ind2 should be equal to 0
			if (ind2 <> 0) then begin
				exit;
				//myHalt (['ind2 is not right in TWomenMemoryManager.addWoman. Stopping...']);
			end;
			setLength (womenList[ind1, 0], nw_level3);
		end;
		if (ind2 > countLevel2 - 1) then begin
			Inc (countLevel2);
			// ind3 should be equal to 0
			if (ind3 <> 0) then begin
				exit;
				//myHalt (['ind3 is not right in TWomenMemoryManager.addWoman. Stopping...']);
			end;
			setLength (womenList[ind1, ind2], nw_level3);
		end;
		womenList [ind1, ind2, ind3] := aWomanObj;
		result := true;
	end;
{$ENDIF}
 	
	function TWomenMemoryManager.getWoman (womanInd: longint): TWomanMemoryBlock;
	// womanInd is 0 based and the last woman is located at womanInd = nWomen - 1
	var
		ind1, ind2, ind3: longint;
	begin
		self.indexToArrayPos (womanInd, ind1, ind2, ind3);
		result := womenList [ind1, ind2, ind3];
	end;

	function TWomenMemoryManager.numWomen: longint;
	begin
		result := nWomen;
	end;

	procedure TWomenMemoryManager.indexToArrayPos (womanInd: longint; out ind1, ind2, ind3: longint);
	begin
		ind3 := (womanInd) mod nw_level3;
		ind2 := trunc ( (womanInd) / nw_level3 ) mod nw_level2;
		ind1 := trunc ( trunc ( (womanInd) / nw_level3 ) / nw_level2 );
	end;

	function TWomenMemoryManager.arrayPosToIndex (ind1, ind2, ind3: longint): longint;
	begin
		result := ind1 * nw_level2 * nw_level3 + ind2 * nw_level3 + ind3 + 1;
	end;

	// CMC is Century Month Code defined as 1 on January of Year 0 (1/0)
	function yearFromCMC (cmc: longint): longint;
	begin
		result := trunc ((cmc-1) / 12);
	end;

	function monthFromCMC (cmc: longint): longint;
	begin
		result := cmc - yearFromCMC (cmc) * 12;
	end;

	// CDC is Century Day Code defined as 1 on January 1st of Year 0 (1/1/0)
	// with 360 days in a year and months of 30 days
	function yearFromCDC (cdc: longint): longint;
	begin
		result := trunc ((cdc-1) / 360);
	end;

	function monthFromCDC (cdc: longint): longint;
	begin
		result := 1 + trunc ( (cdc - yearFromCDC (cdc) * 360) / 30 );
	end;

	function dayFromCDC (cdc: longint): longint;
	begin
		result := cdc - (monthFromCDC (cdc)-1)*30 - yearFromCDC (cdc) * 360;
	end;

	function CMCFromAge (age: double; cmcBirth: longint = 1): longint;
	begin
		result := trunc (age * 12) + cmcBirth;
	end;

	function CMCFromDate (randomGenerator: TRandomNumberGenerator; dateBirth: DateOfBirthType): longint;
	begin
		result:= dateBirth.yearBirth * 12 + lunarToCalendarMonth (randomGenerator, dateBirth.monthBirth);
	end;
	
	function ageFromCMC (cmc: longint; cmcBirth: longint = 1): double;
	begin
		result := (cmc - cmcBirth) / 12;
	end;
	
	function CDCFromDate (randomGenerator: TRandomNumberGenerator; dateBirth: DateOfBirthType): longint;
	begin
		with dateBirth do
			result := yearBirth * 360 + (lunarToCalendarMonth (randomGenerator, monthBirth) - 1) * 30 + dayBirth;
	end;
	
	function CDCFromAge (age: double; cdcBirth: longint = 1): longint;
	begin
		result := trunc (age * 360) + cdcBirth;
	end;
	
	function ageFromCDC (cdc: longint; cdcBirth: longint = 1): double;
	begin
		result := (cdc - cdcBirth) / 360;
	end;
	
	function CMCFromCDC (cdc: longint): longint;
	begin
		result := 1 + trunc (cdc / 30);
	end;

    procedure dateFromCdc (cdcObj: longint; var dateToCompute: DateOfBirthType);
	begin
		with dateToCompute do begin
			yearBirth := yearFromCDC (cdcObj);
			monthBirth := monthFromCDC (cdcObj);
			dayBirth := dayFromCDC (cdcObj);
		end;
	end;

	procedure computeCDC (randomGenerator: TRandomNumberGenerator; pEgo: pRelativeType);
	var
		indUnion, indUnionPartner: longint;
        cdc1, cdc2: longint;
		pUnionInfo: pUnionInfoType;
		pRelative, pPartner: pRelativeType;
        ageEndUnion1, ageEndUnion2: double;
        date1, date2: DateOfBirthType;
	begin
		pRelative := pEgo;
		while (pRelative <> nil) do begin
			pRelative^.cdcBirth := CDCFromDate (randomGenerator, pRelative^.dateBirth);
			pRelative^.cdcDeath := CDCFromAge (pRelative^.ageDeath, pRelative^.cdcBirth);
			for indUnion := 1 to pRelative^.nUnions do begin
				pUnionInfo := getUnionInfoByIndex (pRelative, indUnion);
				with pUnionInfo^ do begin
					cdcStartUnion := CDCFromAge (ageUnion, pRelative^.cdcBirth);
					if ageEndUnion > 0 then begin
						cdcEndUnion := CDCFromAge (ageEndUnion, pRelative^.cdcBirth);
					end else begin
						cdcEndUnion := kNotDefined;
					end;
				end;
			end;
			pRelative := pRelative^.nextRelative;
        end;
		// due to the conversion between float ages and ages in calendar month, some dates of end of union for partners will be shifted one month. We correct this here
		pRelative := pEgo;
		while (pRelative <> nil) do begin
			if not byUnion (pEgo, pRelative) and (pRelative^.typeOfKin <> kt_partner) then begin
				// only ego or ego's kins by blood
				for indUnion := 1 to pRelative^.nUnions do begin
					pPartner := getPartner (pRelative, indUnion);
                    if (pPartner = nil) then continue;
					indUnionPartner := getIndUnion (pPartner, pRelative);
                    cdc1 := getCDCEndUnion(pRelative, indUnion);
                    ageEndUnion1 := getAgeEndUnion(pRelative, indUnion);
                    cdc2 := getCDCEndUnion(pPartner, indUnionPartner);
                    ageEndUnion2 := getAgeEndUnion(pPartner, indUnionPartner);
					if abs (cdc1 - cdc2) > 1 then begin
	                    writeAndWait('Fam: ' + intToStr(gIndEgo) + ', diff: ' + intToStr(cdc1-cdc2) + ' cdcEndUnion ' + intToStr(pRelative^.indNumber) + ' ' + intToStr(pPartner^.indNumber));
	                end;
					case getCauseEndUnion (pRelative, indUnion) of
						end_by_death:
							begin
								// kin's cdcDeath and cdcEndUnion should coincide
								if pRelative^.cdcDeath <> getCDCEndUnion(pRelative, indUnion) then begin
									setCDCEndUnion (pRelative, indUnion, pRelative^.cdcDeath);
                                    writeAndWait(intToStr(cdc1) + ' cdcDeath and cdcEndUnion ' + intToStr(pRelative^.cdcDeath));
								end;
								// the kin should have died before her/his partner and we use his/her age at end of union;
								if (pRelative^.cdcDeath > pPartner^.cdcDeath) then begin
									// bad
									pPartner^.cdcDeath := pRelative^.cdcDeath;
								end;
								if getCDCEndUnion(pRelative, indUnion) <> getCDCEndUnion(pPartner, indUnionPartner) then begin
									setCDCEndUnion (pPartner, indUnionPartner, getCDCEndUnion(pRelative, indUnion));
								end;
							end;
						end_by_widowhood:
							begin
								// partner cdcDeath and cdcEndUnion should be the same
								if pPartner^.cdcDeath <> getCDCEndUnion(pPartner, indUnionPartner) then begin
									setCDCEndUnion (pPartner, indUnionPartner, pPartner^.cdcDeath);
                                    writeAndWait(intToStr(cdc2) + ' cdcDeath and cdcEndUnion ' + intToStr(pPartner^.cdcDeath));
								end;
								// kin should have died after the partner (and partner's death is the master);
								if (pRelative^.cdcDeath < pPartner^.cdcDeath) then begin
									// bad
									pRelative^.cdcDeath := pPartner^.cdcDeath
								end;
								if getCDCEndUnion(pRelative, indUnion) <> getCDCEndUnion(pPartner, indUnionPartner) then begin
									setCDCEndUnion (pRelative, indUnion, getCDCEndUnion(pPartner, indUnionPartner));
								end;
							end;
						end_by_separation:
							begin
								if (pRelative^.cdcDeath < getCDCEndUnion(pRelative, indUnion)) then begin
									setCDCEndUnion (pRelative, indUnion, pRelative^.cdcDeath);
									setCDCEndUnion (pPartner, indUnionPartner, pRelative^.cdcDeath);
								end;
								if (pPartner^.cdcDeath < getCDCEndUnion(pPartner, indUnionPartner)) then begin
									setCDCEndUnion (pRelative, indUnion, pPartner^.cdcDeath);
									setCDCEndUnion (pPartner, indUnionPartner, pPartner^.cdcDeath);
								end;
								if getCDCEndUnion(pRelative, indUnion) <> getCDCEndUnion(pPartner, indUnionPartner) then begin
									// kin's cdc value is the master
									setCDCEndUnion (pPartner, indUnionPartner, getCDCEndUnion(pRelative, indUnion));
								end;
							end;
					end; // end case
                    cdc1 := getCDCEndUnion(pRelative, indUnion);
                    cdc2 := getCDCEndUnion(pPartner, indUnionPartner);
					if cdc1 <> cdc2 then
	                    writeAndWait(intToStr(cdc1-cdc2) + ' cdcEndUnion after correction with ego:' + intToStr(gIndEgo));

				end;
			end;
			pRelative := pRelative^.nextRelative;
		end;
	end;

	procedure unScan (pRelative: pRelativeType);
	// reset scanned flag to false for all the kinship network
	begin
		while (pRelative <> nil) do begin
			pRelative^.scanned := FALSE;
			pRelative := pRelative^.nextRelative;
		end;
	end;

	procedure addLastPartner (pRelative, pPartner: pRelativeType);
	var
		Uinfo: pUnionInfoType = nil;
{$IFDEF addOldUnionType}
		i: longint = 1;
		ageEndUnion: double;
{$ENDIF}
	begin
		if (pRelative = nil) or (pPartner = nil) then
			exit;
{$IFDEF addOldUnionType}
if (pRelative^.ageDeath < 1) or (pPartner^.ageDeath < 1) then
	writeAndWait ('BAD BAD: age at death bad for partners in addLastPartner');
		while (i <= kMaxNbUnion) and (pRelative^.partners [i] <> nil) do
		// we search for an empty slot
			Inc (i);
		if (i > kMaxNbUnion) then {problem}
			writeAndWait ('We have a person with more partners than allowed by the program in addLastPartner!!');
		// we store the reference to the partner
		pRelative^.partners [i] := pPartner;
		pRelative^.nUnions := i;
{$ENDIF}
		UInfo := getLastUnionInfo (pRelative);
		if (UInfo = nil) then
			UInfo := newUnionInfo (pRelative)
		else if (UInfo^.partner <> nil) then begin
			UInfo^.next := newUnionInfo (pRelative);
			UInfo := UInfo^.next;
		end;
		UInfo^.partner := pPartner;
{$IFDEF addOldUnionType}
		if (pRelative^.partners [pRelative^.nUnions] <> getUnionInfoByIndex (pRelative, pRelative^.nUnions)^.partner) then
			writeAndWait ('BAD BAD: partner wrong');
{$ENDIF}
	end;

	procedure addChild (pRelative, pChild: pRelativeType);
{$IFDEF DEBUG}
	var
		indCh: longint;
{$ENDIF}
	begin
		if (pRelative = nil) or (pChild = nil) then
			exit;
{$IFDEF DEBUG}
if g_GENPARAM.CHECK_DATASTRUCT.value then
begin
	if isChildAlreadyInList (pRelative, pChild) then
	// check we don't add the same child two times
		myHalt (['Repeated children in addChild']);
	if pRelative^.gender = man then begin
		if pChild^.father <> pRelative then
			myHalt (['Not child of that father!']);
	end else begin
		if pChild^.mother <> pRelative then
			myHalt (['Not child of that mother!']);
	end;
end;

{$ENDIF}
		addChildToRelative (pRelative, pChild);
	end;

{returns the first relative of kin pEgo, of gender genderRelative, of kin type kinType, that we have not yet scanned. If there is none, we return nil}
	function LookingForRelative (	pEgo: pRelativeType;
									kinType: KinTypes;
									genderRelative: Sex;
									hint: pRelativeType = nil): pRelativeType;
		var
			pRelative: pRelativeType;
			found: boolean;
	begin
{$IFDEF VerboseProfiler} timeProfile_start_proc('LookingForRelative'); {$ENDIF}
		found := FALSE;
		pRelative := pEgo;
		while (pRelative <> nil) and not found do
		begin
			with pRelative^ do begin
				found := (typeOfKin = kinType) and (kinOf = pEgo) and (gender = genderRelative) and not scanned;
				if found and (hint <> nil) then
					found := (hint = pRelative);
			end;
			if not found then pRelative := pRelative^.nextRelative;
		end;
		if found then
			begin
				pRelative^.scanned := TRUE;
				result := pRelative;
			end
		else
			result := nil;
{$IFDEF VerboseProfiler} timeProfile_end_proc('LookingForRelative'); {$ENDIF}
	end;

	function indCohortSet (cohort: longint; sC: setCohorts): longint;
	var
		ind: longint;
	begin
		result := -1;
		if sC = nil then exit;
		for ind := 0 to length (sC) - 1 do
			if sC [ind] = cohort then begin
				result := ind;
				exit;
			end;
	end;

	procedure addToCohortSet (cohort: longint; var sC: setCohorts);
	var
		nC: longint;
	begin
		if (indCohortSet (cohort, sC) < 0) then begin
			nC := length (sC);
			setLength(sC, nC+1);
			sC [nC] := cohort;
		end;
	end;
	
	procedure sortCohortSet (var sC: setCohorts);
	var
		ind1, ind2, temp: longint;
	begin
		// sort cohorts (bubble sort!!)
		for ind1 := 0 to length (sC) - 2 do
			for ind2 := ind1 + 1 to length (sC) - 1 do
				if sC [ind2] < sC [ind1] then begin
					temp := sC [ind1];
					sC [ind1] := sC [ind2];
					sC [ind2] := temp;
				end;
	end;
	
	function kinshipSearchCohorts (const pRels: array of KinshipInfo; nKinships: longint): setCohorts;
	var
		sC: setCohorts;
		ind: longint;
		pEgo: pRelativeType;
	begin
		sC := [];
		for ind := 1 to nKinships do begin
			pEgo := pRels[ind-1].pEgo;
			addToCohortSet (pEgo^.cohort, sC);
		end;
		sortCohortSet (sC);
		result := sC;
	end;
	
	procedure initComputeStatesKinship (sCohorts: setCohorts);
	{compute total and by cohort for egos and her/his parents:
	1. proportion single (only egos!)
	2. age at union (if possible)
	3. total fertility and fertility of mothers (of ego and of ego's mother and father)
	}
	var
		ageFec: FecundAges;
		ageUnion: agesUnion;
		age: agesLife;
		durUnion: durationsUnion;
		indCohort, indChild, nCohorts: longint;
		aSex: Sex;
		aUnionState: catUnion;
		aUnionMultiState: catMulti;

	begin
		nCohorts := length (sCohorts);
		g_setCohorts := sCohorts;
		SetLength (g_fertilityEgoMothers, nCohorts);
		SetLength (g_fertilityEgosWithAtLeastOneChild, nCohorts);
		SetLength (g_fertilityEgos, nCohorts);
		SetLength (g_fertilityEgoPartners, nCohorts);
		SetLength (g_NumChildrenEgoMothers, nCohorts);
		SetLength (g_NumChildrenEgos, nCohorts);
		SetLength (g_NumChildrenEgoPartners, nCohorts);
		SetLength (g_DistNbChildren, nCohorts);
		if g_AgeUnionAvailable then begin
			SetLength (g_UnionTable, nCohorts);
			SetLength (g_UnionTableEgoParents, nCohorts);
		end;
		SetLength (g_Union, nCohorts);
		SetLength (g_UnionMultiState, nCohorts);
		SetLength (g_UnionDurationMultiState, nCohorts);

		// Is it necessary to zero the arrays after a SetLength? Anyway we get on the safe side...
		for indCohort := 0 to nCohorts-1 do begin
			for aSex := man to woman do begin
				for ageFec := low(FecundAges) to high(FecundAges) do begin
					g_fertilityEgoMothers[indCohort, aSex, cf_persons, ageFec] := 0;
					g_fertilityEgoMothers[indCohort, aSex, cf_births, ageFec] := 0;
					g_fertilityEgosWithAtLeastOneChild[indCohort, aSex, cf_persons, ageFec] := 0;
					g_fertilityEgosWithAtLeastOneChild[indCohort, aSex, cf_births, ageFec] := 0;
					g_fertilityEgos[indCohort, cf_persons, aSex, ageFec] := 0;
					g_fertilityEgos[indCohort, cf_births, aSex, ageFec] := 0;
					g_fertilityEgoPartners[indCohort, cf_persons, aSex, ageFec] := 0;
					g_fertilityEgoPartners[indCohort, cf_births, aSex, ageFec] := 0;
				end;
				for indChild := 0 to kMaxNbChildren do begin
					g_NumChildrenEgoMothers [indCohort, aSex, indChild] := 0;
					g_NumChildrenEgos [indCohort, aSex, indChild] := 0;
					g_NumChildrenEgoPartners [indCohort, aSex, indChild] := 0;
				end;
				for indChild := 0 to kMaxNbChildren+1 do begin
					g_DistNbChildren [indCohort, allStates50, indChild] := 0;
					g_DistNbChildren [indCohort, alive50EverInUnion, indChild] := 0;
					g_DistNbChildren [indCohort, aliveWithFirstPartner50, indChild] := 0;
				end;
				if g_AgeUnionAvailable then
					for ageUnion := kMinAgeUnion to kMaxAgeUnion do begin
						g_UnionTable[indCohort, aSex, ageUnion] := 0;
						g_UnionTable[indCohort, aSex, ageUnion] := 0;
						g_UnionTableEgoParents[indCohort, aSex, ageUnion] := 0;
						g_UnionTableEgoParents[indCohort, aSex, ageUnion] := 0;
					end;
 				for aUnionState := low(catUnion) to high(catUnion) do
					g_Union[indCohort, aSex, aUnionState] := 0;
     			for aUnionMultiState := low(catMulti) to high(catMulti) do begin
					for age := low(agesLife) to high(agesLife) do begin
						g_UnionMultiState[indCohort, aSex, aUnionMultiState, age] := 0;
					end;
					for durUnion := low(durationsUnion) to high(durationsUnion) do begin
						g_UnionDurationMultiState[indCohort, aSex, aUnionMultiState, durUnion] := 0;
					end;
				end;
			end;
		end;
	end;
	
	function relativeDiedBefore (pRelativeOne, pRelativeTwo: pRelativeType; var ageEndUnion: double): boolean;
	// returns true if relative two died before relative one, than if true also returns 'ageEndUnion', the age of end of union / age of widowhood of relative one
	begin
		ageEndUnion := pRelativeTwo^.ageDeath - pRelativeTwo^.ageAtBirthOfEgo + pRelativeOne^.ageAtBirthOfEgo;
		relativeDiedBefore := ageEndUnion < pRelativeOne^.ageDeath;
	end;
	
	function aliveAtAgeWithPartner (pWoman: pRelativeType; ageLimit: longint): boolean;
	// woman alive at age ageLimit and still in union
	var
		ageWomanEndUnion: double;
	begin
	   result := (pWoman^.ageDeath >= ageLimit) and (getAgeEndUnion (pWoman, pWoman^.nUnions) >= ageLimit);
 	end;
	
	procedure addToTFRtables(pEgo: pRelativeType);
	var
		egoMother, egoSibling, partner: pRelativeType;
		ageMother, ageChildbearing: longint;
		aSex: Sex;
		indCohort: longint;
		nC: longint = 0;
		indUnion: longint;
		
		procedure UnionMultiStateCounts (pEgo: pRelativeType; indCohort: longint);
		var
			ageDeath, ageFirstUnion, ageEndFirstUnion, ageSecondUnion: longint;
			age: agesLife;
			durUnion: durationsUnion;
			cat: catMulti;
{			catMulti = (cm_person, cm_firstUnion, cm_firstSeparation, cm_firstWidowhood,
					cm_secondUnionAfterSeparation, cm_secondUnionAfterWidowhood,
					cm_death_single, cm_death_firstUnion, cm_death_firstSeparation, cm_death_firstWidowhood,
					cm_death_secondUnionAfterSeparation, cm_death_secondUnionAfterWidowhood);
}
			causeEndFirstUnion: CausesEndUnionType;
			{end_by_death = 1;
			end_by_widowhood = 2;
			end_by_separation = 3;}
			aSex: Sex;
		begin {UnionMultiStateCounts}
			ageDeath := trunc (pEgo^.ageDeath);
			aSex := pEgo^.gender;
			// persons-year lived
			for age := low(agesLife) to min (ageDeath, high(agesLife)) do
				Inc (g_UnionMultiState [indCohort, aSex, cm_person, age]);
			ageFirstUnion := kNotDefined;
			ageEndFirstUnion := kNotDefined;
			ageSecondUnion := kNotDefined;
			if (pEgo^.nUnions > 0) then begin
				ageFirstUnion := trunc (getAgeUnion(pEgo, 1));
				Inc (g_UnionMultiState [indCohort, aSex, cm_firstUnion, ageFirstUnion]);
				ageEndFirstUnion := trunc (getAgeEndUnion(pEgo, 1));
				causeEndFirstUnion := getCauseEndUnion(pEgo, 1);
				if (pEgo^.nUnions > 1) then
					ageSecondUnion := trunc (getAgeUnion(pEgo, 2));
					
				// DURATION (only for ever in union)
				if (ageEndFirstUnion > 0) then begin
					// the union ended
					durUnion := min (high(durationsUnion), trunc (getAgeEndUnion(pEgo, 1) - getAgeUnion(pEgo, 1))) ;
					case causeEndFirstUnion of
						end_by_death:
							// ego's death
							Inc (g_UnionDurationMultiState [indCohort, aSex, cm_death_firstUnion, durUnion]);
						end_by_widowhood: begin
							// partner's death
							Inc (g_UnionDurationMultiState [indCohort, aSex, cm_firstWidowhood, durUnion]);
							if ageSecondUnion > 0 then begin
								// ego entered a second union
								durUnion := min (high(durationsUnion), trunc (getAgeUnion(pEgo, 2) - getAgeEndUnion(pEgo, 1)));
								Inc (g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterWidowhood, durUnion]);
								// we count only ego's death after the second union (we ignore further separations or widowhoods)
								durUnion := min (high(durationsUnion), trunc (pEgo^.ageDeath - getAgeUnion(pEgo, 2)));
								Inc (g_UnionDurationMultiState [indCohort, aSex, cm_death_secondUnionAfterWidowhood, durUnion])
							end else begin
								// ego did not enter a second union after widowhood
								durUnion := min (high(durationsUnion), trunc (pEgo^.ageDeath - getAgeEndUnion(pEgo, 1)));
								Inc (g_UnionDurationMultiState [indCohort, aSex, cm_death_firstWidowhood, durUnion])
							end
						end;
						end_by_separation: begin
							Inc (g_UnionDurationMultiState [indCohort, aSex, cm_firstSeparation, durUnion]);
							if ageSecondUnion > 0 then begin
								// ego entered a second union
								durUnion := min (high(durationsUnion), trunc (getAgeUnion(pEgo, 2) - getAgeEndUnion(pEgo, 1)));
								Inc (g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterSeparation, durUnion]);
								// we count only ego's death after the second union (we ignore further separations or widowhoods)
								durUnion := min (high(durationsUnion), trunc (pEgo^.ageDeath - getAgeUnion(pEgo, 2)));
								Inc (g_UnionDurationMultiState [indCohort, aSex, cm_death_secondUnionAfterSeparation, durUnion])
							end else begin
								// ego did not enter a second union after separating
								durUnion := min (high(durationsUnion), trunc (pEgo^.ageDeath - getAgeEndUnion(pEgo, 1)));
								Inc (g_UnionDurationMultiState [indCohort, aSex, cm_death_firstSeparation, durUnion])
							end
						end;
					end;
				end else begin
					// ego's death (but this case should have been already taken into account with end_by_death)
					durUnion := min (high(durationsUnion), trunc (pEgo^.ageDeath - getAgeUnion(pEgo, 1)));
					Inc (g_UnionDurationMultiState [indCohort, aSex, cm_death_firstUnion, durUnion])
				end;
				// AGE
				if (ageEndFirstUnion > 0) then begin
					case causeEndFirstUnion of
						end_by_death: Inc (g_UnionMultiState [indCohort, aSex, cm_death_firstUnion, ageEndFirstUnion]);
						end_by_widowhood: begin
								Inc (g_UnionMultiState [indCohort, aSex, cm_firstWidowhood, ageEndFirstUnion]);
								if ageSecondUnion > 0 then begin
									Inc (g_UnionMultiState [indCohort, aSex, cm_secondUnionAfterWidowhood, ageSecondUnion]);
									Inc (g_UnionMultiState [indCohort, aSex, cm_death_secondUnionAfterWidowhood, ageDeath])
								end else
									Inc (g_UnionMultiState [indCohort, aSex, cm_death_firstWidowhood, ageDeath])
							end;
						end_by_separation: begin
								Inc (g_UnionMultiState [indCohort, aSex, cm_firstSeparation, ageEndFirstUnion]);
								if ageSecondUnion > 0 then begin
									Inc (g_UnionMultiState [indCohort, aSex, cm_secondUnionAfterSeparation, ageSecondUnion]);
									Inc (g_UnionMultiState [indCohort, aSex, cm_death_secondUnionAfterSeparation, ageDeath])
								end else
									Inc (g_UnionMultiState [indCohort, aSex, cm_death_firstSeparation, ageDeath])
							end;
					else
						WriteAndWait('causeEndFirstUnion wrong value');
					end;
				end else begin
					// ego's death (but this case should have been already taken into account with end_by_death)
 					Inc (g_UnionMultiState [indCohort, aSex, cm_death_firstUnion, ageDeath]);
					if gRunFromIDE then
{$IFNDEF ARM}
						asm int 3 end;
{$ELSE}
						assert(true);
{$ENDIF}
 				end;
			end else
				Inc (g_UnionMultiState [indCohort, aSex, cm_death_single, ageDeath]);
		end; {UnionMultiStateCounts}
		
		procedure egoPartnerAddPersonsAndBirths (pPartner: pRelativeType; ageLimit: longint; indCohort: longint);
		var
			ageFecund, ind: longint;
			aSex: Sex;
			aChild: pRelativeType;
		begin
			// 1. number of children for partner who survive up to ageLimit
			if (pPartner^.ageDeath >= ageLimit) then
				Inc (g_NumChildrenEgoPartners[indCohort, pPartner^.gender, getNumChildren (pPartner)]);
			// 2. Person-year and childbirth by age to compute rates
			{adding persons' years}
			for ageFecund := low(fecundAges) to high(fecundAges) do begin
				if ageFecund < trunc(pPartner^.ageDeath) then begin
					Inc ( g_fertilityEgoPartners[indCohort, cf_persons, pPartner^.gender, ageFecund] );
				end;
			end;
			// adding children
			for ind := 1 to getNumChildren (pPartner) do begin
				aChild := getChildFromRelative (pPartner, ind);
				ageChildbearing := trunc (aChild^.ageMotherAtChildbirth);
				Inc ( g_fertilityEgoPartners[indCohort, cf_births, pPartner^.gender, ageChildbearing] );
			end;
		end; {procedure egoPartnerAddPersonsAndBirths}

		procedure egoAddPersonsAndBirths (pEgo: pRelativeType; ageLimit: longint; indCohort: longint);
		var
			ageFecund: longint;
			aSex: Sex;
			egoChild: pRelativeType;
{$IFDEF DEBUG}
pRelative, pMother: pRelativeType;
{$ENDIF}
		begin
			// 1. number of children for egos who survive up to ageLimit
			if (pEgo^.ageDeath >= ageLimit) then
				Inc (g_NumChildrenEgos[indCohort, pEgo^.gender, getNumChildren (pEgo)]);
			// 2. Person-year and childbirth by age to compute rates
			{adding persons' years}
			for ageFecund := low(fecundAges) to high(fecundAges) do begin
				if ageFecund < trunc(pEgo^.ageDeath) then begin
					Inc ( g_fertilityEgos[indCohort, cf_persons, pEgo^.gender, ageFecund] );
					if (getNumChildren (pEgo) > 0) then
						Inc ( g_fertilityEgosWithAtLeastOneChild[indCohort, pEgo^.gender, cf_persons, ageFecund] );
				end;
			end;
			// 3. adding ego's children. Sons then daughters
			nC := 0;
			for aSex := man to woman do begin
				egoChild := LookingForRelative(pEgo, kt_child, aSex);
				while (egoChild <> nil) do begin
					Inc (nC);
					ageChildbearing := trunc (egoChild^.ageMotherAtChildbirth);
{$IFDEF DEBUG}
if not checkDebugLongint (ageChildbearing, kMinAgeFert, kMaxAgeFert) then begin
	writeAndWait ('Bad ageChildbearing in addToTFTtables');
end;
{$ENDIF}
					Inc ( g_fertilityEgosWithAtLeastOneChild[indCohort, pEgo^.gender, cf_births, ageChildbearing] );
					Inc ( g_fertilityEgos[indCohort, cf_births, pEgo^.gender, ageChildbearing] );
					egoChild := LookingForRelative(pEgo, kt_child, aSex);
				end;
			end;
			if nC <> getNumChildren (pEgo) then begin
				writeAndWait ('Number of children does not check in addPersonsAndBirths');
			end;
			// 4. counts for union multistate table
			UnionMultiStateCounts (pEgo, indCohort);
			// 5. count of children
			incrementNbChildren (
				g_DistNbChildren [indCohort],
				getNumChildren (pEgo),
				pEgo^.nUnions,
				pEgo^.ageDeath,
				getAgeEndUnion (pEgo, 1));

		end; {procedure egoAddPersonsAndBirths}
		
	begin {addToTFRtables}
		indCohort := indCohortSet (pEgo^.cohort, g_setCohorts);
		// CHECKING: adding info to compute fertility of egos' mother (will be TFR for women with at least one child)
		// First we set the whole kinship network to unscanned state in order to find relatives
		unScan (pEgo);
		egoMother := LookingForRelative(pEgo, kt_mother, woman);
		if egoMother <> nil then begin
			if (egoMother^.ageDeath >= 50) then
				Inc (g_NumChildrenEgoMothers[indCohort, pEgo^.gender, getNumChildren (egoMother)]);
			// adding to women's years
			for ageMother := low(fecundAges) to high(fecundAges) do begin
				if ageMother < trunc(egoMother^.ageDeath) then begin
					Inc ( g_fertilityEgoMothers[indCohort, pEgo^.gender, cf_persons, ageMother] );
				end;
			end;
			// adding birth of ego
			ageChildbearing := trunc (pEgo^.ageMotherAtChildbirth);
			Inc ( g_fertilityEgoMothers[indCohort, pEgo^.gender, cf_births, ageChildbearing] );
			// adding births of ego's siblings. Brothers then sisters
			for aSex := man to woman do begin
				egoSibling := LookingForRelative(pEgo, kt_sibling, aSex);
				while (egoSibling <> nil) do begin
					ageChildbearing := trunc (egoSibling^.ageMotherAtChildbirth);
					Inc ( g_fertilityEgoMothers[indCohort, pEgo^.gender, cf_births, ageChildbearing] );
					egoSibling := LookingForRelative(pEgo, kt_sibling, aSex);
				end;
			end;
		end else
			writeAndWait ('No mother!!');

		// Fertility of egos
		// in order to compare with egos' mother
		// First we set the whole kinship network to unscanned state in order to find relatives
		unScan (pEgo);
		if (pEgo^.gender = woman) then
			egoAddPersonsAndBirths (pEgo, 50, indCohort)
		else
			egoAddPersonsAndBirths (pEgo, 60, indCohort);

		// Fertility of ego's partners
		if (pEgo^.nUnions > 0) then begin
			for indUnion := 1 to pEgo^.nUnions do begin
				partner := getPartner (pEgo, indUnion);
{$IFDEF DEBUG}
if partner = nil then
	partner := partner
else
{$ENDIF}
				if (partner^.gender = woman) then
					egoPartnerAddPersonsAndBirths (partner, 50, indCohort)
				else
					egoPartnerAddPersonsAndBirths (partner, 60, indCohort);
			end;
		end;
	end; {addToTFRtables}

	procedure addToNuptialityTables(pEgo: pRelativeType);
	var
		aSex: Sex;
		indCohort: longint;
		ageUnionInt: longint;
		causeEndPartnership: CausesEndUnionType;

	begin {addToNuptialityTables}
		if pEgo^.ageDeath < 50 then exit;
		indCohort := indCohortSet (pEgo^.cohort, g_setCohorts);
		aSex := pEgo^.gender;
		if g_AgeUnionAvailable then begin
			if pEgo^.nUnions > 0 then begin
				// first union only
				ageUnionInt := trunc(getAgeUnion (pEgo, 1));
				Inc ( g_UnionTable[indCohort, aSex, ageUnionInt]);
			end;
			ageUnionInt := trunc(getAgeUnion (pEgo^.mother, 1));
			Inc (g_UnionTableEgoParents[indCohort, woman, ageUnionInt]);
			ageUnionInt := trunc(getAgeUnion (pEgo^.father, 1));
			Inc (g_UnionTableEgoParents[indCohort, man, ageUnionInt]);
		end;
		
		{catUnion = (cu_person, cu_firstUnion, cu_firstSeparation, cu_firstWidowhood,
					cu_secondUnionAfterSeparation, cu_secondUnionAfterWidowhood);}
		//end_by_death = 1;
		//end_by_widowhood = 2;
		//end_by_separation = 3;

		Inc ( g_Union [indCohort, aSex, cu_person] );
		if pEgo^.nUnions > 0 then begin
			Inc ( g_Union [indCohort, aSex, cu_firstUnion] );
			causeEndPartnership := getCauseEndUnion (pEgo, 1);
			if ( causeEndPartnership = end_by_separation ) then begin
				Inc ( g_Union [indCohort, aSex, cu_firstSeparation] );
				if pEgo^.nUnions > 1 then
					Inc ( g_Union [indCohort, aSex, cu_secondUnionAfterSeparation] );
			end;
			if ( causeEndPartnership = end_by_widowhood ) then begin
				Inc ( g_Union [indCohort, aSex, cu_firstWidowhood] );
				if pEgo^.nUnions > 1 then
					Inc ( g_Union [indCohort, aSex, cu_secondUnionAfterWidowhood] );
			end;
		end;
	end; {addToNuptialityTables}

	procedure addToStatesKinship (pEgo: pRelativeType);
	begin
		addToTFRtables(pEgo);
		addToNuptialityTables(pEgo);
	end;

	procedure writeAgeMultiState (cohort: longint; table: arraySexCatUnionAgeType; writeToFile: boolean; writeToScreen: boolean = true);
	// arraySexCatUnionAgeType = array [Sex] of array [catMulti] of array [agesLife] of longint;
{			catMulti = (cm_person, cm_firstUnion, cm_firstSeparation, cm_firstWidowhood,
					cm_secondUnionAfterSeparation, cm_secondUnionAfterWidowhood,
					cm_death_single, cm_death_firstUnion, cm_death_firstSeparation, cm_death_firstWidowhood,
					cm_death_secondUnionAfterSeparation, cm_death_secondUnionAfterWidowhood);
}
	var
		aSex: Sex;
		aCat: catMulti;
		age: agesLife;
	begin
		fileScreenWriteLn (gOutFileKin, ['======================================================================'], col_none, writeToFile, writeToScreen);
		fileScreenWriteLn (gOutFileKin, ['=========== Union life table: population and events (age) ============'], col_none, writeToFile, writeToScreen);
		fileScreenWriteLn (gOutFileKin,
					[
					'Cohort', tab,
					'Age', tab,
					'Gender', tab,
					'person', tab,
					'1stUnion', tab,
					'1stSep', tab,
					'1stWid', tab,
					'2UnionAfterSep', tab,
					'2UnionAfterWid', tab,
					'death_single', tab,
					'death_1Union', tab,
					'death_1Sep', tab,
					'death_1Wid', tab,
					'death_2UnionSep', tab,
					'death_2UnionWid'
					], col_header, writeToFile, writeToScreen);
		for aSex := man to woman do
			for age := low(agesLife) to high(agesLife) do
				fileScreenWriteLn (gOutFileKin,
							[
							cohort, tab,
							age, tab,
							str_gender[aSex], tab,
							table[aSex, cm_person, age], tab,
							table[aSex, cm_firstUnion, age], tab,
							table[aSex, cm_firstSeparation, age], tab,
							table[aSex, cm_firstWidowhood, age], tab,
							table[aSex, cm_secondUnionAfterSeparation, age], tab,
							table[aSex, cm_secondUnionAfterWidowhood, age], tab,
							table[aSex, cm_death_single, age], tab,
							table[aSex, cm_death_firstUnion, age], tab,
							table[aSex, cm_death_firstSeparation, age], tab,
							table[aSex, cm_death_firstWidowhood, age], tab,
							table[aSex, cm_death_secondUnionAfterSeparation, age], tab,
							table[aSex, cm_death_secondUnionAfterWidowhood, age]
							], col_table, writeToFile, writeToScreen);
		fileScreenWriteLn (gOutFileKin, ['======================================================================'], col_none, writeToFile, writeToScreen);
	end;
	
	procedure writeDurationMultiState (cohort: longint; table: arraySexCatUnionDurationType; writeToFile: boolean; writeToScreen: boolean = true);
	// arraySexCatUnionDurationType = array [Sex] of array [catMulti] of array [durationsUnion] of longint;
{			catMulti = (cm_person, cm_firstUnion, cm_firstSeparation, cm_firstWidowhood,
					cm_secondUnionAfterSeparation, cm_secondUnionAfterWidowhood,
					cm_death_single, cm_death_firstUnion, cm_death_firstSeparation, cm_death_firstWidowhood,
					cm_death_secondUnionAfterSeparation, cm_death_secondUnionAfterWidowhood);
}
	var
		aSex: Sex;
		aCat: catMulti;
		durUnion: durationsUnion;
	begin
		fileScreenWriteLn (gOutFileKin, ['======================================================================'], col_none, writeToFile, writeToScreen);
		fileScreenWriteLn (gOutFileKin, ['=========== Union life table: population and events (duration) ======='], col_none, writeToFile, writeToScreen);
		fileScreenWriteLn (gOutFileKin,
					[
					'Cohort', tab,
					'Duration', tab,
					'Gender', tab,
					'person', tab,
					'1Union', tab,
					'1Sep', tab,
					'1Wid', tab,
					'2UnionAfterSep', tab,
					'2UnionAfterWid', tab,
					'death_single', tab,
					'death_1Union', tab,
					'death_1Sep', tab,
					'death_1Wid', tab,
					'death_2UnionSep', tab,
					'death_2UnionWid'
					], col_header, writeToFile, writeToScreen);
		for aSex := man to woman do
			for durUnion := low(durationsUnion) to high(durationsUnion) do
				fileScreenWriteLn (gOutFileKin,
							[
							cohort, tab,
							durUnion, tab,
							str_gender[aSex], tab,
							table[aSex, cm_person, durUnion], tab,
							table[aSex, cm_firstUnion, durUnion], tab,
							table[aSex, cm_firstSeparation, durUnion], tab,
							table[aSex, cm_firstWidowhood, durUnion], tab,
							table[aSex, cm_secondUnionAfterSeparation, durUnion], tab,
							table[aSex, cm_secondUnionAfterWidowhood, durUnion], tab,
							table[aSex, cm_death_single, durUnion], tab,
							table[aSex, cm_death_firstUnion, durUnion], tab,
							table[aSex, cm_death_firstSeparation, durUnion], tab,
							table[aSex, cm_death_firstWidowhood, durUnion], tab,
							table[aSex, cm_death_secondUnionAfterSeparation, durUnion], tab,
							table[aSex, cm_death_secondUnionAfterWidowhood, durUnion]
							], col_table, writeToFile, writeToScreen);
		fileScreenWriteLn (gOutFileKin, ['======================================================================'], col_none, writeToFile, writeToScreen);
	end;
	
	function computeUnionMultistate (indCohort: longint; writeToFile: boolean): arrayMultipleType;
	// arraySexCatUnionAgeType = array [Sex] of array [catMulti] of array [ageLife] of longint;
{		catMulti = (cm_person, cm_firstUnion, cm_firstSeparation, cm_firstWidowhood,
					cm_secondUnionAfterSeparation, cm_secondUnionAfterWidowhood,
					cm_death_single, cm_death_firstUnion, cm_death_firstSeparation, cm_death_firstWidowhood,
					cm_death_secondUnionAfterSeparation, cm_death_secondUnionAfterWidowhood);
}

	type
		personAgeUnionStates = (pa_Total, pa_Single, pa_FirstUnion, pa_FirstSep, pa_FirstWid, pa_2ndUnionSep, pa_2ndUnionWid);
		AgeLifeTableUnionStates = (pu_FirstUnion, pu_FirstWid, pu_FirstSep, pu_2ndUnionSep, pu_2ndUnionWid);
		eventUnionType = (eu_firstUnion, eu_firstWid, eu_firstSep, eu_secondUnionWid, eu_secondUnionSep);
		personDurationStates = (pd_FirstUnion, pd_FirstSep, pd_FirstWid);
		
	var
		aSex: Sex;
		aCat: catMulti;
		age: agesLife;
		duration: durationsUnion;
		persons: double;
		personAge: array [Sex] of array [personAgeUnionStates] of array [agesLife] of longint;
		ageRates: array [Sex] of array [eventUnionType] of array [agesLife] of double;
		ageMultiLifeTable: array [Sex] of array [AgeLifeTableUnionStates] of array [agesLife] of double;
		personDuration: array [Sex] of array [personDurationStates] of array [durationsUnion] of longint;
		durRates: array [Sex] of array [eventUnionType] of array [durationsUnion] of double;
		durMultiLifeTable: array [Sex] of array [eventUnionType] of array [durationsUnion] of double;
		
	begin {computeUnionMultistate}
		if g_GENPARAM.outputs_opt[res_kin_unionTable].value then begin
			writeAgeMultiState (g_setCohorts [indCohort], g_UnionMultiState[indCohort], writeToFile, false);
			writeDurationMultiState (g_setCohorts [indCohort], g_UnionDurationMultiState[indCohort], writeToFile, false);
		end;
		
		// UNION BY AGE
		for aSex := man to woman do begin
			// observed life table of union states
			for age := low(agesLife) to high(agesLife) do begin
				personAge [aSex, pa_Total, age] := g_UnionMultiState[indCohort, aSex, cm_person, age];
			end;
			personAge [aSex, pa_Single, low(agesLife)] := personAge [aSex, pa_Total, low(agesLife)];
			personAge [aSex, pa_FirstUnion, low(agesLife)] := 0;
			personAge [aSex, pa_FirstSep, low(agesLife)] := 0;
			personAge [aSex, pa_FirstWid, low(agesLife)] := 0;
			personAge [aSex, pa_2ndUnionSep, low(agesLife)] := 0;
			personAge [aSex, pa_2ndUnionWid, low(agesLife)] := 0;
			for age := low(agesLife) + 1 to high(agesLife) do begin
				personAge [aSex, pa_Single, age] := personAge [aSex, pa_Single, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_firstUnion, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_death_single, age-1];
				personAge [aSex, pa_FirstUnion, age] := personAge [aSex, pa_FirstUnion, age-1] +
					g_UnionMultiState[indCohort, aSex, cm_firstUnion, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_firstSeparation, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_firstWidowhood, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_death_firstUnion, age-1];
				personAge [aSex, pa_FirstSep, age] := personAge [aSex, pa_FirstSep, age-1] +
					g_UnionMultiState[indCohort, aSex, cm_firstSeparation, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_secondUnionAfterSeparation, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_death_firstSeparation, age-1];
				personAge [aSex, pa_FirstWid, age] := personAge [aSex, pa_FirstWid, age-1] +
					g_UnionMultiState[indCohort, aSex, cm_firstWidowhood, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_secondUnionAfterWidowhood, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_death_firstWidowhood, age-1];
				personAge [aSex, pa_2ndUnionSep, age] := personAge [aSex, pa_2ndUnionSep, age-1] +
					g_UnionMultiState[indCohort, aSex, cm_secondUnionAfterSeparation, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_death_secondUnionAfterSeparation, age-1];
				personAge [aSex, pa_2ndUnionWid, age] := personAge [aSex, pa_2ndUnionWid, age-1] +
					g_UnionMultiState[indCohort, aSex, cm_secondUnionAfterWidowhood, age-1] -
					g_UnionMultiState[indCohort, aSex, cm_death_secondUnionAfterWidowhood, age-1];
			end;
		
			// computing rates
			for age := low(agesLife) to high(agesLife) do begin
				persons := (personAge [aSex, pa_Single, age] - g_UnionMultiState[indCohort, aSex, cm_death_single, age] / 2);
				if (persons > 0) then
					ageRates[aSex, eu_firstUnion, age] := g_UnionMultiState[indCohort, aSex, cm_firstUnion, age] / persons
				else
					ageRates[aSex, eu_firstUnion, age] := 0;
				persons := (personAge [aSex, pa_FirstUnion, age] - g_UnionMultiState[indCohort, aSex, cm_death_firstUnion, age] / 2
																- g_UnionMultiState[indCohort, aSex, cm_firstWidowhood, age] / 2);
				if (persons > 0) then
					ageRates[aSex, eu_firstSep, age] := g_UnionMultiState[indCohort, aSex, cm_firstSeparation, age] / persons
				else
					ageRates[aSex, eu_firstSep, age] := 0;
				persons := (personAge [aSex, pa_FirstUnion, age] - g_UnionMultiState[indCohort, aSex, cm_death_firstUnion, age] / 2
																- g_UnionMultiState[indCohort, aSex, cm_firstSeparation, age] / 2);
				if (persons > 0) then
					ageRates[aSex, eu_firstWid, age] := g_UnionMultiState[indCohort, aSex, cm_firstWidowhood, age] / persons
				else
					ageRates[aSex, eu_firstWid, age] := 0;
				persons := (personAge [aSex, pa_FirstSep, age] - g_UnionMultiState[indCohort, aSex, cm_death_firstSeparation, age] / 2);
				if (persons > 0) then
					ageRates[aSex, eu_secondUnionSep, age] := g_UnionMultiState[indCohort, aSex, cm_secondUnionAfterSeparation, age] / persons
				else
					ageRates[aSex, eu_secondUnionSep, age] := 0;
				persons := (personAge [aSex, pa_FirstWid, age] - g_UnionMultiState[indCohort, aSex, cm_death_firstWidowhood, age] / 2);
				if (persons > 0) then
					ageRates[aSex, eu_secondUnionWid, age] := g_UnionMultiState[indCohort, aSex, cm_secondUnionAfterWidowhood, age] / persons
				else
					ageRates[aSex, eu_secondUnionWid, age] := 0;
						
			end;
		
			// age multi life table
			ageMultiLifeTable[aSex, pu_FirstUnion, low(agesLife)] := 10000;
			ageMultiLifeTable[aSex, pu_FirstWid, low(agesLife)] := 10000;
			ageMultiLifeTable[aSex, pu_FirstSep, low(agesLife)] := 10000;
			ageMultiLifeTable[aSex, pu_2ndUnionSep, low(agesLife)] := 10000;
			ageMultiLifeTable[aSex, pu_2ndUnionWid, low(agesLife)] := 10000;
			for age := (low(agesLife)+1) to high(agesLife) do begin
				ageMultiLifeTable[aSex, pu_FirstUnion, age] := ageMultiLifeTable[aSex, pu_FirstUnion, age - 1] *
															(1 - ageRates[aSex, eu_firstUnion, age - 1]);
				ageMultiLifeTable[aSex, pu_FirstWid, age] := ageMultiLifeTable[aSex, pu_FirstWid, age - 1] *
															(1 - ageRates[aSex, eu_firstWid, age - 1]);
				ageMultiLifeTable[aSex, pu_FirstSep, age] := ageMultiLifeTable[aSex, pu_FirstSep, age - 1] *
															(1 - ageRates[aSex, eu_firstSep, age - 1]);
				ageMultiLifeTable[aSex, pu_2ndUnionSep, age] := ageMultiLifeTable[aSex, pu_2ndUnionSep, age - 1] *
															(1 - ageRates[aSex, eu_secondUnionSep, age - 1]);
				ageMultiLifeTable[aSex, pu_2ndUnionWid, age] := ageMultiLifeTable[aSex, pu_2ndUnionWid, age - 1] *
															(1 - ageRates[aSex, eu_secondUnionWid, age - 1]);
			end;
		end; {aSex}

		// UNION BY DURATION
		for aSex := man to woman do begin
			// observed life table of union states by duration
			personDuration [aSex, pd_FirstUnion, high(durationsUnion)] :=
				g_UnionDurationMultiState [indCohort, aSex, cm_firstSeparation, high(durationsUnion)] +
				g_UnionDurationMultiState [indCohort, aSex, cm_firstWidowhood, high(durationsUnion)] +
				g_UnionDurationMultiState [indCohort, aSex, cm_death_firstUnion, high(durationsUnion)];
			personDuration [aSex, pd_FirstSep, high(durationsUnion)] :=
				g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterSeparation, high(durationsUnion)] +
				g_UnionDurationMultiState [indCohort, aSex, cm_death_firstSeparation, high(durationsUnion)];
			personDuration [aSex, pd_FirstWid, high(durationsUnion)] :=
				g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterWidowhood, high(durationsUnion)] +
				g_UnionDurationMultiState [indCohort, aSex, cm_death_firstWidowhood, high(durationsUnion)];
				
			for duration := (high(durationsUnion)-1) downto low(durationsUnion) do begin
				personDuration [aSex, pd_FirstUnion, duration] :=
					personDuration [aSex, pd_FirstUnion, duration + 1] +
					g_UnionDurationMultiState [indCohort, aSex, cm_firstSeparation, duration] +
					g_UnionDurationMultiState [indCohort, aSex, cm_firstWidowhood, duration] +
					g_UnionDurationMultiState [indCohort, aSex, cm_death_firstUnion, duration];
				personDuration [aSex, pd_FirstSep, duration] :=
					personDuration [aSex, pd_FirstSep, duration + 1] +
					g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterSeparation, duration] +
					g_UnionDurationMultiState [indCohort, aSex, cm_death_firstSeparation, duration];
				personDuration [aSex, pd_FirstWid, duration] :=
					personDuration [aSex, pd_FirstWid, duration + 1] +
					g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterWidowhood, duration] +
					g_UnionDurationMultiState [indCohort, aSex, cm_death_firstWidowhood, duration];
			end;

			// duration rates
			for duration := (low(durationsUnion)) to high(durationsUnion) do begin
				persons :=
					(
						personDuration [aSex, pd_FirstUnion, duration] -
						(g_UnionDurationMultiState [indCohort, aSex, cm_death_firstUnion, duration] / 2) -
						(g_UnionDurationMultiState [indCohort, aSex, cm_firstWidowhood, duration] / 2)
					);
				if persons > 0 then
					durRates [aSex, eu_firstSep, duration] :=
						g_UnionDurationMultiState [indCohort, aSex, cm_firstSeparation, duration] / persons
				else
					durRates [aSex, eu_firstSep, duration] := 0;
				persons :=
					(
						personDuration [aSex, pd_FirstUnion, duration] -
						(g_UnionDurationMultiState [indCohort, aSex, cm_death_firstUnion, duration] / 2) -
						(g_UnionDurationMultiState [indCohort, aSex, cm_firstSeparation, duration] / 2)
					);
				if persons > 0 then
					durRates [aSex, eu_firstWid, duration] :=
						g_UnionDurationMultiState [indCohort, aSex, cm_firstWidowhood, duration] / persons
				else
					durRates [aSex, eu_firstWid, duration] := 0;
				persons :=
					(
						personDuration [aSex, pd_FirstSep, duration] -
						(g_UnionDurationMultiState [indCohort, aSex, cm_death_firstSeparation, duration] / 2)
					);
				if persons > 0 then
					durRates [aSex, eu_secondUnionSep, duration] :=
						g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterSeparation, duration] / persons
				else
					durRates [aSex, eu_secondUnionSep, duration] := 0;
				persons :=
					(
						personDuration [aSex, pd_FirstWid, duration] -
						(g_UnionDurationMultiState [indCohort, aSex, cm_death_firstWidowhood, duration] / 2)
					);
				if persons > 0 then
					durRates [aSex, eu_secondUnionWid, duration] :=
						g_UnionDurationMultiState [indCohort, aSex, cm_secondUnionAfterWidowhood, duration] / persons
				else
					durRates [aSex, eu_secondUnionWid, duration] := 0;
			end;
			// duration multi life table
			durMultiLifeTable[aSex, eu_firstSep, low(durationsUnion)] := 10000;
			durMultiLifeTable[aSex, eu_firstWid, low(durationsUnion)] := 10000;
			durMultiLifeTable[aSex, eu_secondUnionSep, low(durationsUnion)] := 10000;
			durMultiLifeTable[aSex, eu_secondUnionWid, low(durationsUnion)] := 10000;
			for duration := (low(durationsUnion)+1) to high(durationsUnion) do begin
				durMultiLifeTable[aSex, eu_firstSep, duration] := durMultiLifeTable[aSex, eu_firstSep, duration - 1] *
															(1 - durRates[aSex, eu_firstSep, duration - 1]);
				durMultiLifeTable[aSex, eu_firstWid, duration] := durMultiLifeTable[aSex, eu_firstWid, duration - 1] *
															(1 - durRates[aSex, eu_firstWid, duration - 1]);
				durMultiLifeTable[aSex, eu_secondUnionSep, duration] := durMultiLifeTable[aSex, eu_secondUnionSep, duration - 1] *
															(1 - durRates[aSex, eu_secondUnionSep, duration - 1]);
				durMultiLifeTable[aSex, eu_secondUnionWid, duration] := durMultiLifeTable[aSex, eu_secondUnionWid, duration - 1] *
															(1 - durRates[aSex, eu_secondUnionWid, duration - 1]);
			end;

		end;
		
		// results...
		for aSex := man to woman do begin
			result [aSex, mu_never] := 1 - ageMultiLifeTable[aSex, pu_FirstUnion, high(agesLife)] / 10000;
			result [aSex, mu_FirstWidowhood] := 1 - durMultiLifeTable[aSex, eu_firstWid, high(durationsUnion)] / 10000;
			result [aSex, mu_FirstSeparation] := 1 - durMultiLifeTable[aSex, eu_firstSep, high(durationsUnion)] / 10000;
			result [aSex, mu_SecondUnionWidowhood] := 1 - durMultiLifeTable[aSex, eu_secondUnionWid, high(durationsUnion)] / 10000;
			result [aSex, mu_SecondUnionSeparation] := 1 - durMultiLifeTable[aSex, eu_secondUnionSep, high(durationsUnion)] / 10000;
		end;
	end; {computeUnionMultistate}
	
	procedure computeStatesKinship;
	var
		writeToFile: boolean;
		ageFec: FecundAges;
		ageUnion: agesUnion;
		sumRates: double;
		sumParents: longint;
		sumEgos, sumEgoMothers, sumEgoPartners: longint;
		aSex: Sex;
		rate: double;
		indCohort, nCohorts, cohort: longint;
		indChildren: longint;
		MultiRes: array of arrayMultipleType;
		PropSingle, PropSeparation, PropWidowhood, PropSecondUnionAfterSep, PropSecondUnionAfterWidowhood,
			meanAgeUnion_egos, meanAgeUnion_egoParents: array of array [Sex] of double;
		TFR1PLUS_egoMothers, TFR_egoMothers_NC: array of array [sex] of double;
		TFR_egos, TFR1PLUS_egos, TFR_egos_NC, VAR_egos: array of array [Sex] of double;
		TFR_egoPartners, TFR_egoPartners_NC: array of array [Sex] of double;
		MotherLookup: string;
		TFR, VARIANCE: array [sex] of array [StatusAge50] of double;
		ind: longint;
		
	begin
		nCohorts := length(g_setCohorts);
		writeToFile := g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP.value;

		// UNION FORMATION AND SEPARATION
		setLength (PropSingle{%H-}, nCohorts);
		setLength (PropSeparation{%H-}, nCohorts);
		setLength (PropWidowhood{%H-}, nCohorts);
		setLength (PropSecondUnionAfterSep{%H-}, nCohorts);
		setLength (PropSecondUnionAfterWidowhood{%H-}, nCohorts);
		setLength (meanAgeUnion_egos{%H-}, nCohorts);
		setLength (meanAgeUnion_egoParents{%H-}, nCohorts);
		// FERTILITY
		setLength (TFR1PLUS_egoMothers{%H-}, nCohorts);
		setLength (TFR1PLUS_egos{%H-}, nCohorts);
		setLength (TFR_egos{%H-}, nCohorts);
		setLength (TFR_egoPartners{%H-}, nCohorts);
		setLength (TFR_egoMothers_NC{%H-}, nCohorts);
		setLength (TFR_egos_NC{%H-}, nCohorts);
		setLength (TFR_egoPartners_NC{%H-}, nCohorts);
		setLength (VAR_egos{%H-}, nCohorts);
		setLength (MultiRes{%H-}, nCohorts);
		
		for indCohort := 0 to nCohorts - 1 do begin
			MultiRes [indCohort] := computeUnionMultistate (indCohort, writeToFile);
			{Union formation and separation of egos, as well as their age at union and of their parents}
			for aSex := man to woman do begin
				sumRates := 0;
				sumParents := 0;
				meanAgeUnion_egos [indCohort, aSex] := 0;
				meanAgeUnion_egoParents [indCohort, aSex] := 0;
				if g_AgeUnionAvailable then begin
					for ageUnion := kMinAgeUnion to kMaxAgeUnion do begin
						rate := 0;
						if g_Union [indCohort, aSex, cu_person] > 0 then
							rate := g_UnionTable[indCohort, aSex, ageUnion] / g_Union[indCohort, aSex, cu_person];
						sumRates := sumRates + rate;
						meanAgeUnion_egos [indCohort, aSex] := meanAgeUnion_egos [indCohort, aSex] + ( ageUnion + 0.5 ) * rate;
						sumParents := sumParents + g_UnionTableEgoParents[indCohort, aSex, ageUnion];
						meanAgeUnion_egoParents [indCohort, aSex] := meanAgeUnion_egoParents [indCohort, aSex] + ( ageUnion + 0.5 ) * g_UnionTableEgoParents[indCohort, aSex, ageUnion];
					end;
					meanAgeUnion_egos [indCohort, aSex] := meanAgeUnion_egos [indCohort, aSex] / sumRates;
					meanAgeUnion_egoParents [indCohort, aSex] := meanAgeUnion_egoParents [indCohort, aSex] / sumParents;
				end;
				if g_Union [indCohort, aSex, cu_person] > 0 then
					PropSingle [indCohort, aSex] := g_Union [indCohort, aSex, cu_firstUnion] /
						g_Union [indCohort, aSex, cu_person];
				if g_Union [indCohort, aSex, cu_firstUnion] > 0 then
					PropSeparation [indCohort, aSex] := g_Union [indCohort, aSex, cu_firstSeparation] /
						(g_Union [indCohort, aSex, cu_firstUnion] - g_Union [indCohort, aSex, cu_firstWidowhood] / 2);
				if g_Union [indCohort, aSex, cu_firstUnion] > 0 then
					PropWidowhood [indCohort, aSex] := g_Union [indCohort, aSex, cu_firstWidowhood] /
						(g_Union [indCohort, aSex, cu_firstUnion] - g_Union [indCohort, aSex, cu_firstSeparation] / 2);
				if g_Union [indCohort, aSex, cu_firstSeparation] > 0 then
					PropSecondUnionAfterSep [indCohort, aSex] := g_Union [indCohort, aSex, cu_secondUnionAfterSeparation] /
						g_Union [indCohort, aSex, cu_firstSeparation];
				if g_Union [indCohort, aSex, cu_firstWidowhood] > 0 then
					PropSecondUnionAfterWidowhood [indCohort, aSex] := g_Union [indCohort, aSex, cu_secondUnionAfterWidowhood] /
						g_Union [indCohort, aSex, cu_firstWidowhood];
				PropSeparation [indCohort, aSex] := MultiRes [indCohort, aSex, mu_FirstSeparation];
				PropWidowhood [indCohort, aSex] := MultiRes [indCohort, aSex, mu_FirstWidowhood];
				PropSecondUnionAfterSep [indCohort, aSex] := MultiRes [indCohort, aSex, mu_SecondUnionSeparation];
				PropSecondUnionAfterWidowhood [indCohort, aSex] := MultiRes [indCohort, aSex, mu_SecondUnionWidowhood];
			end;
			{Fertility of egos' mother and father and of egos}
			for ageFec := low (FecundAges) to high(FecundAges) do
				for aSex := man to woman do begin
					rate := 0;
					if g_fertilityEgoMothers[indCohort, aSex, cf_persons, ageFec] > 0 then
						rate := g_fertilityEgoMothers[indCohort, aSex, cf_births, ageFec] /
							g_fertilityEgoMothers[indCohort, aSex, cf_persons, ageFec];
					TFR1PLUS_egoMothers[indCohort, aSex] := TFR1PLUS_egoMothers[indCohort, aSex] + rate;
					rate := 0;
					if g_fertilityEgosWithAtLeastOneChild[indCohort, aSex, cf_persons, ageFec] > 0 then
						rate := g_fertilityEgosWithAtLeastOneChild[indCohort, aSex, cf_births, ageFec] /
							g_fertilityEgosWithAtLeastOneChild[indCohort, aSex, cf_persons, ageFec];
					TFR1PLUS_egos[indCohort, aSex] := TFR1PLUS_egos[indCohort, aSex] + rate;
					rate := 0;
					if g_fertilityEgos[indCohort, cf_persons, aSex, ageFec] > 0 then
						rate := g_fertilityEgos[indCohort, cf_births, aSex, ageFec] /
							g_fertilityEgos[indCohort, cf_persons, aSex, ageFec];
					TFR_egos[indCohort, aSex] := TFR_egos[indCohort, aSex] + rate;
					rate := 0;
					if g_fertilityEgoPartners[indCohort, cf_persons, aSex, ageFec] > 0 then
						rate := g_fertilityEgoPartners[indCohort, cf_births, aSex, ageFec] /
							g_fertilityEgoPartners[indCohort, cf_persons, aSex, ageFec];
					TFR_egoPartners[indCohort, aSex] := TFR_egoPartners[indCohort, aSex] + rate;
				end;
			{Fertility levels based on number of children, not age at childbearing and measure of the 'siblings effect'}
			for aSex := man to woman do begin
				sumEgos := 0;
				sumEgoMothers := 0;
				sumEgoPartners := 0;
				for indChildren := 0 to kMaxNbChildren do begin
					sumEgos := sumEgos + g_NumChildrenEgos [indCohort, aSex, indChildren];
					sumEgoMothers := sumEgoMothers + g_NumChildrenEgoMothers [indCohort, aSex, indChildren];
					sumEgoPartners := sumEgoPartners + g_NumChildrenEgoPartners [indCohort, aSex, indChildren];
					TFR_egos_NC [indCohort, aSex] := TFR_egos_NC [indCohort, aSex] +
						indChildren * g_NumChildrenEgos [indCohort, aSex, indChildren];
					TFR_egoMothers_NC [indCohort, aSex] := TFR_egoMothers_NC [indCohort, aSex] +
						indChildren * g_NumChildrenEgoMothers [indCohort, aSex, indChildren];
					TFR_egoPartners_NC [indCohort, aSex] := TFR_egoPartners_NC [indCohort, aSex] +
						indChildren * g_NumChildrenEgoPartners [indCohort, aSex, indChildren];
					VAR_egos [indCohort, aSex] := VAR_egos [indCohort, aSex] +
						indChildren * indChildren * g_NumChildrenEgos [indCohort, aSex, indChildren];
				end;
				TFR_egos_NC [indCohort, aSex] := TFR_egos_NC [indCohort, aSex] / sumEgos;
				TFR_egoMothers_NC [indCohort, aSex] := TFR_egoMothers_NC [indCohort, aSex] / sumEgoMothers;
				TFR_egoPartners_NC [indCohort, aSex] := TFR_egoPartners_NC [indCohort, aSex] / sumEgoPartners;
				VAR_egos [indCohort, aSex] := VAR_egos [indCohort, aSex] / sumEgos -
						 TFR_egos_NC [indCohort, aSex] * TFR_egos_NC [indCohort, aSex];
			end;
		end; {indCohort}
	
		MotherLookup := 'KINFERT';
		if gBACKFOR_mode_pure then
			MotherLookup := 'BACKFOR';
		if gBACKFOR_mode then
			MotherLookup := 'BACKFOR_mixed';
		if gCAMSIM_1987 then
			MotherLookup := 'CAMSIM_1987';
		if gCAMSIM_1993 then begin
			MotherLookup := 'CAMSIM_1993';
			if gCAMSIM_1993_unbounded then
				MotherLookup := MotherLookup + '_unbounded';
		end;

		fileScreenWriteLn (gOutFileKin, ['======================================================================'], col_none, writeToFile);
		fileScreenWriteLn (gOutFileKin, ['Demographic statistics computed on kinship networks'], col_none, writeToFile);
		fileScreenWriteLn (gOutFileKin, ['Algorithm for ascendant genealogies: ', MotherLookup], col_none, writeToFile);
		fileScreenWriteLn (gOutFileKin, ['Union formation and separation'], col_none, writeToFile);
		fileScreenWriteLn (gOutFileKin,
					[
					'Cohort', tab,
					'Gender', tab,
					'pEverUnion', tab,
					'pFirstSep', tab,
					'pFirstWid', tab,
					'pSecUnionAfSep', tab,
					'pSecUnionAfWid', tab,
					'AgeUnion', tab,
					'AgeUnionParents'
					], col_header, writeToFile);
		for indCohort := 0 to nCohorts - 1 do begin
			cohort := g_setCohorts[indCohort];
			for aSex := man to woman do begin
				fileScreenWriteLn (gOutFileKin,
							[
							cohort, tab,
							sSex[aSex], tab,
							PropSingle [indCohort, aSex], tab,
							PropSeparation [indCohort, aSex], tab,
							PropWidowhood [indCohort, aSex], tab,
							PropSecondUnionAfterSep [indCohort, aSex], tab,
							PropSecondUnionAfterWidowhood [indCohort, aSex], tab,
							meanAgeUnion_egos [indCohort, aSex], tab,
							meanAgeUnion_egoParents [indCohort, aSex]
							], col_table, writeToFile);
			end;
		end;
		EndTableWithHeader();
		
		fileScreenWriteLn (gOutFileKin, ['Fertility of egos and their mothers'], col_none, writeToFile);
		fileScreenWriteLn (gOutFileKin,
					[
					'Cohort', tab,
					'Gender', tab,
					'TFR_egos', tab,
					'TFR1+_egos', tab,
					'TFR1+_egosMother', tab,
					'TFR_Siblings', tab,
					'TFR_egoPartners'
					], col_header, writeToFile);
		for indCohort := 0 to nCohorts - 1 do begin
			cohort := g_setCohorts[indCohort];
			for aSex := man to woman do begin
				fileScreenWriteLn (gOutFileKin,
							[
							cohort, tab,
							sSex[aSex], tab,
							TFR_egos_NC[indCohort, aSex], tab,
							TFR1PLUS_egos[indCohort, aSex], tab,
							TFR_egoMothers_NC[indCohort, aSex], tab,
							TFR_egos_NC[indCohort, aSex] + VAR_egos[indCohort, aSex] / TFR_egos_NC[indCohort, aSex], tab,
							TFR_egoPartners_NC[indCohort, aSex]
							], col_table, writeToFile);
			end;
		end;
		EndTableWithHeader();
				
		fileScreenWriteLn (gOutFileKin, ['Fertility of female egos who entered at least one union and were living at age 50'], col_none, writeToFile);
		fileScreenWriteLn (gOutFileKin,
					[
					'Cohort', tab,
					'TFR_input', tab,
					'TFR_adjusted', tab,
					'TFR_result', tab,
					'TFR_output', tab
					], col_header, writeToFile);
		for indCohort := 0 to nCohorts - 1 do begin
			calcFertility_NC (g_DistNbChildren[indCohort, allStates50], TFR[woman, allStates50], VARIANCE[woman, allStates50]);
			calcFertility_NC (g_DistNbChildren[indCohort, alive50EverInUnion], TFR[woman, alive50EverInUnion], VARIANCE[woman, alive50EverInUnion]);
			calcFertility_NC (g_DistNbChildren[indCohort, aliveWithFirstPartner50], TFR[woman, aliveWithFirstPartner50], VARIANCE[woman, aliveWithFirstPartner50]);
			fileScreenWriteLn (gOutFileKin,
						[
						cohort, tab,
						computeTFRfromPPRs(getCohort_p (cohort)^.aPrioriPPR), tab,
						computeTFRfromPPRs(getCohort_p (cohort)^.aPrioriPPR_adjusted), tab,
						computeTFRfromPPRs(getCohort_p (cohort)^.aPrioriPPR_result), tab,
						TFR[woman, alive50EverInUnion], tab
						], col_table, writeToFile);
		end;
		EndTableWithHeader();

		if g_GENPARAM.DEBUG.value then begin		
			fileScreenWriteLn (gOutFileKin, ['=========== distNbChildren ========================'], col_none, writeToFile);
			fileScreenWriteLn (gOutFileKin,
						[
						'Cohort', tab,
						'nbChildren', tab,
						'allStates50', tab,
						'alive50EverInUnion', tab,
						'aliveWithFirstPartner50', tab
						], col_header, writeToFile);
			for indCohort := 0 to nCohorts - 1 do begin
				for ind := 0 to kMaxNbChildren do begin
					cohort := g_setCohorts[indCohort];
					fileScreenWriteLn (gOutFileKin,
							[
							cohort, tab,
							ind, tab,
							g_DistNbChildren[indCohortSet (cohort, g_setCohorts), allStates50, ind], tab,
							g_DistNbChildren[indCohortSet (cohort, g_setCohorts), alive50EverInUnion, ind], tab,
							g_DistNbChildren[indCohortSet (cohort, g_setCohorts), aliveWithFirstPartner50, ind], tab
							], col_table, writeToFile);
					end;
			end;
		end;
		
		EndTableWithHeader();

		fileScreenWriteLn (gOutFileKin, ['======================================================================'], col_none, writeToFile);

		setLength (PropSingle, 0);
		setLength (meanAgeUnion_egos, 0);
		setLength (meanAgeUnion_egoParents, 0);
		setLength (TFR1PLUS_egoMothers, 0);
		setLength (TFR1PLUS_egos, 0);
		setLength (TFR_egos, 0);
		setLength (TFR_egoMothers_NC, 0);
		setLength (TFR_egos_NC, 0);
		setLength (VAR_egos, 0);
		setLength (MultiRes, 0);
		setLength (g_setCohorts, 0);
		SetLength (g_fertilityEgoMothers, 0);
		SetLength (g_fertilityEgosWithAtLeastOneChild, 0);
		SetLength (g_fertilityEgos, 0);
		SetLength (g_NumChildrenEgoMothers, 0);
		SetLength (g_NumChildrenEgos, 0);
		SetLength (g_DistNbChildren, 0);
		if g_AgeUnionAvailable then begin
			SetLength (g_UnionTable, 0);
			SetLength (g_UnionTableEgoParents, 0);
		end;
		SetLength (g_Union, 0);
		SetLength (g_UnionMultiState, 0);
		SetLength (g_UnionDurationMultiState, 0);
	end;

	procedure stuffStringsInRelative (Header, A: TStringArray; cohortEgo: longint; var pRelative: pRelativeType);
	var
		s: string;
		longHeader: boolean = TRUE;
		age, ageDef, tickIn, tickOut, cohortIn: longint;

	begin
	// id,sex,age,ageDef,status,tickIn,tickOut,ego

		longHeader := (length (Header) > 10);
		age := StrToInt (A[ord(dt_age)]);
		ageDef := StrToInt (A[ord(dt_agedef)]);
		tickIn := StrToInt (A[ord(dt_tickin)]);
		tickOut := StrToInt (A[ord(dt_tickOut)]);
		with pRelative^ do begin
			//typeOfKin: KinTypes;
			//kinOf: pRelativeType;
			//birthOrder : longint;
			//ageMotherAtChildbirth: double;
			indNumber := StrToInt (A[ord(dt_id)]);
			s := A[ord(dt_sex)];
			if s = 'M' then
				gender := man
			else
				gender := woman;
			status := A[ord(dt_status)];
			//scanned: boolean;
			ageDeath := ageDef;
			ageAtBirthOfEgo := age - tickIn - 50;
			if longHeader then begin
				cohort := StrToInt (A[ord(dt_cohort)]);
				cohortDemReg := StrToInt (A[ord(dt_cohortRegDem)]);
			end;
			cohortIn := cohortEgo - ageAtBirthOfEgo;
			if not longHeader then cohort := cohortIn;
			//dateBirth: DateOfBirthType;
			//father, mother, prevRelative, nextRelative: pRelativeType;
			//motherUnionNumber: longint; {Union number of biological mother}
			//nUnions: longint;
			//ageUnion: array [1..kMaxNbUnion] of double;
			//ageEndUnion: array [1..kMaxNbUnion] of double;
			//partners: array [1..kMaxNbUnion] of pRelativeType;
			//endOfPartnership: array [1..kMaxNbUnion] of CausesEndUnionType;
			//nbChildren := StrToInt (A[ord(dt_nChildren)]);
			//children: array [1..kMaxNbChildren] of pRelativeType; {only biological children}
		end;
	end;

	function lookForCohortInName (filename: string): longint;
	begin
		result := StrToInt ( copy (filename, 4, 4) );
	end;

	function lookForRelativeById (pRelative: pRelativeType; id: longint): pRelativeType;
	begin
		result := nil;
		while (pRelative <> nil) do begin
			if pRelative^.indNumber = id then begin
				result := pRelative;
				exit;
			end;
			pRelative := pRelative^.nextRelative;
		end;
	end;

	procedure setPartners (pMain, pKinOf: pRelativeType;  kinTypeChild, kinTypeGrandChild: KinTypes);
	var
		pPartner: pRelativeType;
		indPartner: longint;
	begin
		if pMain <> nil then
			for indPartner := 1 to pMain^.nUnions do begin
				pPartner := getPartner (pMain, indPartner);
				if pPartner <> nil then begin
					pPartner^.TypeOfKin := kt_partner;
					pPartner^.kinOf := pKinOf;
					setChildren (pPartner, pMain^.kinOf, kinTypeChild, kinTypeGrandChild);
				end;
			end;
	end;
	
	procedure setChildren (pMain, pKinOf: pRelativeType; kinTypeChild, kinTypeGrandChild: KinTypes);
	var
		pChild: pRelativeType;
		indChildren: longint;
	begin
		if pMain <> nil then
			for indChildren := 1 to getNumChildren (pMain) do begin
				pChild := getChildFromRelative (pMain, indChildren);
				pChild^.TypeOfKin := kinTypeChild;
				pChild^.kinOf := pKinOf;
				if kinTypeGrandChild <> kt_none then begin
					setChildren (pChild, pChild^.kinOf, kinTypeGrandChild, kt_none);
					setPartners (pChild, pChild, kinTypeGrandChild, kt_none);
				end;
			end;
	end;
	
	function readDemocareFile (path, filename: string): boolean;
	const
		kRelativeNetworks = 100;

	var
		f: TFileType;  // Main thread only
		pEgo, pLastRelative, pId, pIdLink: pRelativeType;
		pRels: array of KinshipInfo;
		cohortEgo: longint;
		nRel, indEgo, res: longint;
		aLine: string;
		A, Header: TStringArray;
		democareFields: DemocareTypes;
		kt: KinTypes;
		id,idLink,idFamily: longint;
		linkType: string;
		indKinship, ind: longint;
		nbTotRelatives: longint = 0;
		
	begin
		result := false;
		g_AgeUnionAvailable := false;
		stdWriteLn(['File: ' + path + filename]);
		f := TFileType.Create (path + filename, res, 'READDEMOCAREFILE', f_reset);
		if res <> 0 then begin
			f.Destroy;
			exit;
		end;
		f.aSync := false;
		cohortEgo := lookForCohortInName (filename);
		readLn (f.fileHandle, aLine);
		Header := aLine.Split (',');
		if (length (Header) < 6) or (Header[5] <> 'tickIn') then begin
			writeAndWait ('Not a Democare Kinship file');
			exit;
		end;
		nRel := 0;
		SetLength (pRels{%H-}, kRelativeNetworks);
		// id,sex,age,ageDef,status,tickIn,tickOut,ego
		while not eof (f.fileHandle) do begin
			readLn (f.fileHandle, aLine);
			A := aLine.Split (',');
			indEgo := ord(dt_ego);
			if A[indEgo] = 'TRUE' then begin
				Inc (nRel);
				if nRel > length (pRels) then
				SetLength (pRels, length (pRels) + kRelativeNetworks);
				pEgo := newRelative(nil, nil, nbTotRelatives, kt_ego);
				pEgo^.kinOf := pEgo;
				pLastRelative := pEgo;
				pRels[nRel-1].pEgo := pEgo;
				pRels[nRel-1].nKin := 1;
			end else begin
				kt := kt_nonBio;
				pLastRelative := newRelative(pLastRelative, pEgo, nbTotRelatives, kt);
				Inc (pRels[nRel-1].nKin);
			end;
			stuffStringsInRelative (Header, A, cohortEgo, pLastRelative);
		end;
		f.Destroy;
		// Link file
		filename := copy ( filename, 1, Pos ('.', fileName) - 1 ) + '_link.txt';
		f := TFileType.Create (path + filename, res, 'READDEMOCAREFILE', f_reset);
		if res <> 0 then begin
			f.Destroy;
			exit;
		end;
		f.aSync := false;
		readLn (f.fileHandle, aLine);
		Header := aLine.Split (',');
		while not eof (f.fileHandle) do begin
			readLn (f.fileHandle, aLine);
			A := aLine.Split (',');
			id := StrToInt (A[0]);
			idLink := StrToInt (A[1]);
			linkType := A[2];
			idFamily := StrToInt (A[3]);
			pEgo := pRels[idFamily-1].pEgo;
			pId := lookForRelativeById (pEgo, id);
			pIdLink := lookForRelativeById (pEgo, idLink);
			if (pId = nil) or (pIdLink = nil) then
			writeAndWait ('Link not found');
			if linkType = 'M' then begin
				addLastPartner (pId, pIdLink);
				if pIdLink^.typeOfKin <> kt_ego then begin
				pIdLink^.typeOfKin := kt_partner;
				pIdLink^.kinOf := pId;
				end;
			end else begin
				addChild (pId, pIdLink);
				pIdLink^.mother := pId;
			end;
		end;
		f.Destroy;

		for indKinship := 0 to nRel-1 do begin
			pEgo := pRels[indKinship].pEgo;
			setChildren (pEgo, pEgo, kt_child, kt_grandChild);
			setPartners (pEgo, pEgo, kt_child, kt_grandChild);
		end;
		
		initComputeStatesKinship ( kinshipSearchCohorts (pRels, nRel) );
		for ind := 1 to nRel do begin
			addToStatesKinship (pRels[ind-1].pEgo);
		end;
		computeStatesKinship;

		SetLength (pRels, 0);
		result := true;
	end;

	procedure calcDateBirth (randomGenerator: TRandomNumberGenerator; var dateToCompute: DateOfBirthType; dateRef: DateOfBirthType; ageObjective, ageRef: double);
	// dateRef is a known date of birth and of age 'ageRef' at a precise moment of time
	// we are going to compute date of birth 'dateToCompute' of a person who is aged 'ageObjective' at the same moment
	var
		cdcObj, cdcRef, cdcDiffAge: longint;
	begin
		cdcRef := CDCFromDate (randomGenerator, dateRef);
		cdcDiffAge := CDCFromAge (ageRef - ageObjective) - 1;
		cdcObj := cdcRef + cdcDiffAge;
		dateFromCdc (cdcObj, dateToCompute);
	end;

	procedure calcDateBirth2 (var dateToCompute: DateOfBirthType; dateRef: DateOfBirthType; ageObjective, ageRef: double);
	// dateRef is a known date of birth and of age 'ageRef' at a precise moment of time
	// we are going to compute date of birth 'dateToCompute' of a person who is aged 'ageObjective' at the same moment
	var
		nMonths, nYears: longint;
		diffAge: double;
	begin
		diffAge := ageRef - ageObjective;
		nMonths := ageToLunarMonths(diffAge - trunc (diffAge));
		dateToCompute.monthBirth := dateRef.monthBirth + nMonths;
		nYears := 0;
		if dateToCompute.monthBirth > kNbLunarMonths then begin
			dateToCompute.monthBirth := dateToCompute.monthBirth - kNbLunarMonths;
			nYears := 1;
		end else if dateToCompute.monthBirth <= 0 then begin
			dateToCompute.monthBirth := kNbLunarMonths + dateToCompute.monthBirth;
			nYears := -1;
		end;
		dateToCompute.yearBirth := dateRef.yearBirth + trunc(diffAge) + nYears;
	end;

{$IFDEF DEBUG}
procedure scanChildrenList (pChildrenList: pInfoChildType);
// good for having a look inside the debugger...
var
	pCh: pInfoChildType;
	n: longint;
begin
	pCh := pChildrenList;
	n := 0;
	while (pCh <> nil) do begin
		Inc (n);
		pCh := pCh^.next;
	end;
	pCh := pChildrenList;
	n := 0;
	gotoToFirstLiveBornChild(pCh);
	while (pCh <> nil) do begin
		Inc (n);
		gotoToNextLiveBornChild(pCh);
	end;
end;
{$ENDIF}

	function byUnion (pEgo, pRelative: pRelativeType): boolean;
	begin
		//all kins by union except ego's partner who has ego as 'kinOf'
		result := (pRelative^.kinOf <> pEgo);
	end;

	function fieldEnabled (fn: FieldNamesTypes): boolean;
	begin
		result := fn in g_GENPARAM.OUTPUT_FIELDS.value;
	end;
	
	function lookInRange (index, minVal, maxVal: longint; var state: array of longint): longint;
	// Given a range of years for birth cohorts with precalculated information,
	//  returns the closest birth cohort in the range when asking for year 'index'
	var
		indexInExtraRange: longint;
	begin
		if length (state) > 0 then begin
			indexInExtraRange := max (0, index - (minVal - kStateRangeLengthLimit));
			indexInExtraRange := min (length (state) - 1, indexInExtraRange);
			InterlockedIncrement (state [indexInExtraRange]);
		end;
		result := min (maxVal, max (minVal, index)) - minVal;
	end;
	
	function lookInChildrenRange (cohortChild: longint): longint;
	begin
		result := lookInRange (cohortChild, gFirstCohortAncestorsChildren, gLastCohortAncestorsChildren, gStateChildren);
	end;
	
	function lookInMothersRange (cohortMother: longint): longint;
	begin
		result := lookInRange (cohortMother, gFirstCohortWomen, gLastCohortWomen, gStateMothers);
	end;
	
	function lookInBridesRange (cohortBride: longint): longint;
	begin
		result := lookInRange (cohortBride, gFirstCohortBrides, gLastCohortBrides, gStateBrides);
	end;
	
	function lookInGroomsRange (cohortGroom: longint): longint;
	begin
		result := lookInRange (cohortGroom, gFirstCohortGrooms, gLastCohortGrooms, gStateGrooms);
	end;
	
	function lookInYearsUnionRange (yearUnion: longint): longint;
	begin
		result := lookInRange (yearUnion, gFirstYearUnions, gLastYearUnions, gStateYearUnions);
	end;
	
{$IFDEF DEBUG}
	procedure checkBrides (where: string; arrayMothers: boolean = TRUE);
	var
		cohortWomanInd, ageUnionWomanInd, ind, size, res: longint;
		cohortWoman, ageUnionWoman: longint;
		womanInd: longint;
		check: boolean = true;
		indFile: longint; // used in the main thread
	begin
		if checkDirResult () then begin
			indFile := gFiles.new (gPathToResult + 'ProblemBrides.txt');
			if (indFile < 0) then
				exit;

			for cohortWomanInd := 0 to (gLastCohortBrides - gFirstCohortBrides) do begin
				cohortWoman := cohortWomanInd + gFirstCohortBrides;
				for ageUnionWomanInd := 0 to kMaxAgeUnion_women-kMinAgeUnion_women do begin
					ageUnionWoman := ageUnionWomanInd + kMinAgeUnion_women;
					size := g_RangeBridesNb[cohortWomanInd, ageUnionWomanInd] - 1;
					for ind := 0 to size do begin
						womanInd := g_RangeBridesInfo[cohortWomanInd, ageUnionWomanInd, ind];
						if (not getWomanFromBigArray (womanInd, arrayMothers).checkOwnUnionStates) or not (getWomanFromBigArray (womanInd, arrayMothers).checkOwnChildrenList)  then begin
							stdWriteLn ([getWomanFromBigArray (womanInd, arrayMothers).idWoman, ' has problems, stored at (', cohortWomanInd, ',', ageUnionWomanInd, ',', ind, ')']);
							bWriteLn (gFiles.get (indFile), [getWomanFromBigArray (womanInd, arrayMothers).idWoman, ' has problems, stored at (', cohortWomanInd, ',', ageUnionWomanInd, ',', ind, ')']);
							check := false;
						end;
						if (cohortWoman <> getWomanFromBigArray (womanInd, arrayMothers).cohort) then begin
							stdWriteLn ([getWomanFromBigArray (womanInd, arrayMothers).idWoman, ' bad cohort (', cohortWomanInd, ',', ageUnionWomanInd, ',', ind, ')']);
							bWriteLn (gFiles.get (indFile), [getWomanFromBigArray (womanInd, arrayMothers).idWoman, ' bad cohort (', cohortWomanInd, ',', ageUnionWomanInd, ',', ind, ')']);
							check := false;
						end;
						if (ageUnionWoman <> trunc ( getWomanFromBigArray (womanInd, arrayMothers).unionStates.Unions [0].ages[le_union, woman] )) then begin
							stdWriteLn ([getWomanFromBigArray (womanInd, arrayMothers).idWoman, ' bad age union (', cohortWomanInd, ',', ageUnionWomanInd, ',', ind, ')']);
							bWriteLn (gFiles.get (indFile), [getWomanFromBigArray (womanInd, arrayMothers).idWoman, ' bad age union (', cohortWomanInd, ',', ageUnionWomanInd, ',', ind, ')']);
							check := false;
						end;
					end;
				end;
			end;
			if check then begin
				stdWriteLn ([Where, ': all brides checked OK!']);
				bWriteLn (gFiles.get (indFile), [Where, ': all brides checked OK!']);
			end else begin
				writeAndWait ('Problem with brides');
			end;
		end;
end;

procedure checkChildren (where: string);
	var
		cohortChildInd, ind, size, res: longint;
		cohortChild: longint;
		womanInd: longint;
		check: boolean = true;
		indFile: longint; // used in the main thread
	begin
		if checkDirResult () then begin
			indFile := gFiles.new (gPathToResult + 'ProblemChildren.txt');
			if (indFile < 0) then
				exit;
			for cohortChildInd := 0 to (gLastCohortAncestorsChildren - gFirstCohortAncestorsChildren) do begin
				cohortChild := cohortChildInd + gFirstCohortAncestorsChildren;
				if g_RangeBirthsNb[cohortChildInd] > 0 then
				begin
					size := g_RangeBirthsNb[cohortChildInd] - 1;
					for ind := 0 to size do begin
						womanInd := g_RangeBirthsInfo[cohortChildInd, ind];
						if (not getWomanFromBigArray (womanInd).checkOwnUnionStates) or not (getWomanFromBigArray (womanInd).checkOwnChildrenList)  then begin
							stdWriteLn ([getWomanFromBigArray (womanInd).idWoman, ' has problems, stored at (', cohortChildInd, ',', ind, ')']);
							bWriteLn (gFiles.get (indFile), [getWomanFromBigArray (womanInd).idWoman, ' has problems, stored at (', cohortChildInd, ',', ind, ')']);
							check := false;
						end;
						if not getWomanFromBigArray (womanInd).hasChild (cohortChild) then begin
							stdWriteLn ([getWomanFromBigArray (womanInd).idWoman, ' child missing (', cohortChildInd, ',', ind, ')']);
							bWriteLn (gFiles.get (indFile), [getWomanFromBigArray (womanInd).idWoman, ' child missing (', cohortChildInd, ',', ind, ')']);
							check := false;
						end;
					end;
					if not getWomanFromBigArray (womanInd).hasChild (cohortChild) then begin
						stdWriteLn ([getWomanFromBigArray (womanInd).idWoman, ' child missing (', cohortChildInd, ',', ind, ')']);
						bWriteLn (gFiles.get (indFile), [getWomanFromBigArray (womanInd).idWoman, ' child missing (', cohortChildInd, ',', ind, ')']);
						check := false;
					end;
				end;
			end;
			if check then begin
				stdWriteLn ([Where, ': all children checked OK!']);
				bWriteLn (gFiles.get (indFile), [Where, ': all children checked OK!']);
			end else
				writeAndWait ('Problem with children in checkChildren');
		end;
end;
{$ENDIF}

	function findEgo (pRelative: pRelativeType): pRelativeType;
	begin
		while (pRelative^.prevRelative <> nil) do
			pRelative := pRelative^.prevRelative;
		result := pRelative;
	end;
	
	function getAgeUnionSelected (randomGenerator: TRandomNumberGenerator;
                                    womanInd: longint;
                                    ageUnionWoman: longint;
                                    ageUnionMan: longint = kNotDefined;
                                    arrayMothers: boolean = true): double;
	{Get exact woman age at union based on age at union woman in integer or age at union of a partner}
	var
		indUnion, indUnionSelected, numPossibleGrooms, ageUnion: longint;
		setGrooms: set of char;
		sexSel: Sex;
	begin
		result := 0;
		setGrooms := [];
// look for a specific union, taking into account that the women could have had two or more in the same year
		numPossibleGrooms := 0;
		indUnionSelected := 0;
		if ageUnionWoman > 0 then begin
			sexSel := woman;
			ageUnion := ageUnionWoman;
		end else begin
			sexSel := man;
			ageUnion := ageUnionMan;
		end;
		for indUnion := 1 to getWomanFromBigArray (womanInd, arrayMothers).unionStates.nbUnions do
			if (trunc (getWomanFromBigArray (womanInd, arrayMothers).unionStates.Unions [indUnion - 1].ages[le_union, sexSel]) = ageUnion) or
			(trunc (getWomanFromBigArray (womanInd, arrayMothers).unionStates.Unions [indUnion - 1].ages[le_union, sexSel]) + 1 = ageUnion) then begin
				numPossibleGrooms := numPossibleGrooms + 1;
				setGrooms := setGrooms + [char (indUnion)];
				indUnionSelected := indUnion;
			end;
		if numPossibleGrooms > 1 then begin
			indUnionSelected := longint ( elementInSet (setGrooms, trunc (randomGenerator.alea (0, numPossibleGrooms-0.0000000001))) );
		end;
{$IFDEF DEBUG}
if (numPossibleGrooms = 0) or (indUnionSelected = 0) then
	writeAndWait ('no possible groom in getAgeUnionSelected');
if (indUnionSelected > 4) then
	indUnionSelected := indUnionSelected;
{$ENDIF}
		result := getWomanFromBigArray (womanInd, arrayMothers).unionStates.Unions [indUnionSelected - 1].ages[le_union, woman];
	end;
	
	function lookingForABrideByAgeAndCohort (randomGenerator: TRandomNumberGenerator;
                                    cohortWoman, ageUnionWoman: longint;
                                    out ageUnionSelected: double): longint;
	var
		cohortWomanInd, indBride, ageUnionWomanInd: longint;
		womanInd: longint;
	begin
		cohortWomanInd := lookInBridesRange (cohortWoman);
		ageUnionWomanInd := min (kMaxAgeUnion_women, max(ageUnionWoman, kMinAgeUnion_women)) - kMinAgeUnion_women;
{$IFDEF DEBUG}
if (ageUnionWomanInd < 0) or ( ageUnionWomanInd >= length(g_RangeBridesNb[cohortWomanInd]) ) then
	writeAndWait ('Bad value of ageUnionWomanInd in lookingForABrideByAgeAndCohort');
{$ENDIF}
		// we randomly select a bride
		while g_RangeBridesNb[cohortWomanInd, ageUnionWomanInd] = 0 do begin
			//we look for a bride with approximately the same age at union
			if ageUnionWoman < 20 then
				ageUnionWomanInd := ageUnionWomanInd + 1
			else
				ageUnionWomanInd := ageUnionWomanInd - 1;
		end;
		indBride := trunc ( randomGenerator.alea ( 0, g_RangeBridesNb[cohortWomanInd, ageUnionWomanInd] - 0.00000000001 ) );
		womanInd := g_RangeBridesInfo[cohortWomanInd, ageUnionWomanInd, indBride];
		
		ageUnionSelected := getAgeUnionSelected (randomGenerator, womanInd, ageUnionWomanInd + kMinAgeUnion_women, kNotDefined, gThisIsNotanArrayOfBrides);

		result := womanInd;
	end;

	procedure addGroomsInfo (womanInd: longint; arrayMothers: boolean = TRUE);
	var
		ind, cohortMan, cohortManInd, ageUnionMan, ageUnionManInd, cohortWoman, ageUnionWoman: longint;
	begin
		with getWomanFromBigArray (womanInd, arrayMothers) do begin
			cohortWoman := cohort;
			for ind := 1 to unionStates.nbUnions do begin
				ageUnionMan := trunc ( unionStates.Unions [ind - 1].ages[le_union, man] );
				ageUnionWoman := trunc ( unionStates.Unions [ind - 1].ages[le_union, woman] );
				ageUnionManInd := max (0, ageUnionMan - kMinAgeUnion_men);
				cohortMan := cohortWoman - ageUnionMan + ageUnionWoman;
				if (cohortMan < gFirstCohortGrooms) or (cohortMan > gLastCohortGrooms) then exit;
				cohortManInd := cohortMan - gFirstCohortGrooms;
				
				if g_RangeGroomsNb[cohortManInd, ageUnionManInd] >= length(g_RangeGroomsInfo[cohortManInd, ageUnionManInd]) then
					setLength (g_RangeGroomsInfo[cohortManInd, ageUnionManInd], length(g_RangeGroomsInfo[cohortManInd, ageUnionManInd]) + kSetLengthGrooms);
				g_RangeGroomsInfo[cohortManInd, ageUnionManInd, g_RangeGroomsNb[cohortManInd, ageUnionManInd]] := womanInd;
				Inc (g_RangeGroomsNb[cohortManInd, ageUnionManInd]);
			end;
		end;
	end;
	
	procedure addBridesInfo (womanInd: longint; arrayMothers: boolean = TRUE);
	var
		ind, cohortWoman, cohortWomanInd, ageUnionWoman, ageUnionWomanInd: longint;

	begin
		with getWomanFromBigArray (womanInd, arrayMothers) do begin
			cohortWoman := cohort;
			if (cohortWoman >= gFirstCohortBrides) and (cohortWoman <= gLastCohortBrides) then begin
				cohortWomanInd := cohortWoman - gFirstCohortBrides;
				for ind := 1 to unionStates.nbUnions do begin
					ageUnionWoman := trunc ( unionStates.Unions [ind - 1].ages[le_union, woman] );
					ageUnionWomanInd := ageUnionWoman - kMinAgeUnion_women;
					
					if g_RangeBridesNb[cohortWomanInd, ageUnionWomanInd] >= length(g_RangeBridesInfo[cohortWomanInd, ageUnionWomanInd]) then
						setLength (g_RangeBridesInfo[cohortWomanInd, ageUnionWomanInd], length(g_RangeBridesInfo[cohortWomanInd, ageUnionWomanInd]) + kSetLengthBrides);
					g_RangeBridesInfo[cohortWomanInd, ageUnionWomanInd, g_RangeBridesNb[cohortWomanInd, ageUnionWomanInd]] := womanInd;
					
					Inc (g_RangeBridesNb[cohortWomanInd, ageUnionWomanInd]);
				end;
			end;
		end;
	end;

	function yearFromDatePlusAge (dateBirth: DateOfBirthType; ageUnionWoman: double): longint;
	begin
		result := dateBirth.yearBirth + trunc (ageUnionWoman);
		result := result + trunc ( dateBirth.monthBirth / kNbLunarMonths + ageUnionWoman - trunc (ageUnionWoman) );
	end;

	procedure addUnionsInfo (womanInd: longint; arrayMothers: boolean = TRUE);
	// Take all the unions of women and store them in data structures indexed by year of union and age of man at union
	var
		n: longint;
		yearUnion, yearUnionInd: longint;
		ageUnionMan, ageUnionManInd: longint;
	begin
		with getWomanFromBigArray (womanInd, arrayMothers) do begin
			if unionStates.nbUnions = 0 then exit; // we keep track only of brides
			for n := 1 to unionStates.nbUnions do begin
				yearUnion := yearFromDatePlusAge (dateBirth, unionStates.Unions [n - 1].ages[le_union, woman]);
				ageUnionMan := max(kMinAgeUnion_men, trunc (unionStates.Unions [n - 1].ages[le_union, man]));
				yearUnionInd := yearUnion - gFirstYearUnions;
				ageUnionManInd := ageUnionMan - kMinAgeUnion_men;

				if (yearUnionInd < 0) or (yearUnionInd > (gLastYearUnions - gFirstYearUnions + 1)) then begin
					writeAndWait ('union year out of range. Not useful in addUnionInfo');
					break;
				end;
				
				if g_RangeYearUnionsNb [yearUnionInd, ageUnionManInd] >= length(g_RangeYearUnionsInfo[yearUnionInd, ageUnionManInd]) then
					setLength (g_RangeYearUnionsInfo[yearUnionInd, ageUnionManInd], length(g_RangeYearUnionsInfo[yearUnionInd, ageUnionManInd]) + kSetLengthUnions);
					g_RangeYearUnionsInfo[yearUnionInd, ageUnionManInd, g_RangeYearUnionsNb [yearUnionInd, ageUnionManInd]] := womanInd;
				
				Inc (g_RangeYearUnionsNb [yearUnionInd, ageUnionManInd]);
			end;
		end;
	end;

	procedure addChildrenInfo (randomGenerator: TRandomNumberGenerator; womanInd: longint);
	// Take all the children of a mother and store them in a data structure indexed by year of birth that will allow later to select
	// a mother, a grand mother, etc.
	// All the children will have a birth order
	// and mother's union number and age at childbearing as basic info.
	// Sex and age at death will be determined when included in ego's kinship (if the child is not ego)
	var
		pChild: pInfoChildType;
		n, indCohort: longint;
		nbChildrenTemp: longint;
	begin
		with getWomanFromBigArray (womanInd) do begin
			if nbChildren = 0 then exit; // we keep track only of mothers
			n := 0;
			pChild := pChildrenList;
			gotoToFirstLiveBornChild(pChild);
			while pChild <> nil do begin
				n := n + 1;
				calcDateBirth (randomGenerator, pChild^.dateBirth, getWomanFromBigArray (womanInd).dateBirth, 0, pChild^.ageMotherAtChildbirth);
				if (pChild^.dateBirth.yearBirth >= gFirstCohortAncestorsChildren) and (pChild^.dateBirth.yearBirth <= gLastCohortAncestorsChildren) then begin
					indCohort := pChild^.dateBirth.yearBirth - gFirstCohortAncestorsChildren;
					if g_RangeBirthsNb[indCohort] >= length(g_RangeBirthsInfo[indCohort]) then
						SetLength(g_RangeBirthsInfo[indCohort], length(g_RangeBirthsInfo[indCohort]) + kSetLengthBirths);
					g_RangeBirthsInfo[indCohort, g_RangeBirthsNb[indCohort]] := womanInd;
					Inc (g_RangeBirthsNb[indCohort]);

					if gCAMSIM_1993 then begin
						nbChildrenTemp := nbChildren;
						if nbChildrenTemp > kMaxNbChildrenCalc then
							nbChildrenTemp := kMaxNbChildrenCalc;
						if CAMSIM_RangeBirthsNb[nbChildrenTemp, indCohort] >= length(CAMSIM_RangeBirthsInfo[nbChildrenTemp, indCohort]) then
							SetLength(CAMSIM_RangeBirthsInfo[nbChildrenTemp, indCohort], length(CAMSIM_RangeBirthsInfo[nbChildrenTemp, indCohort]) + kSetLengthBirths);
						CAMSIM_RangeBirthsInfo[nbChildrenTemp, indCohort, CAMSIM_RangeBirthsNb[nbChildrenTemp, indCohort]] := womanInd;
						Inc (CAMSIM_RangeBirthsNb[nbChildrenTemp, indCohort]);
						Inc (CAMSIM_RangeBirthsNb[0, indCohort]);
					end;
				end;
				gotoToNextLiveBornChild(pChild);
			end;
			if n <> nbChildren then
				writeAndWait ('Mismatch in number of children added in Arrays, women: ' + IntToStr (idWoman));
		end;
	end;
	
	procedure addChildrenBACKFORInfo (randomGenerator: TRandomNumberGenerator; womanInd: longint);
	{Take all the children of a mother and store them in a data structure indexed by year of birth,
	age at union of mother
	that will allow later to select a mother, a grand mother, etc.
	All the children will have a birth order
	and we will have also mother's union number and age at childbearing as basic info.
	Sex and age at death will be determined when included in ego's kinship (if the child is not ego)}
	var
		pCh: pInfoChildType;
		n, indCohort: longint;
		ageUnionWomanInd, indUnionWoman: longint;
	begin
		
		with getWomanFromBigArray (womanInd) do begin
			if nbChildren = 0 then exit; // we keep track only of mothers
			n := 0;
			pCh := pChildrenList;
			gotoToFirstLiveBornChild(pCh);
			while pCh <> nil do begin
				n := n + 1;
				calcDateBirth (randomGenerator, pCh^.dateBirth, getWomanFromBigArray (womanInd).dateBirth, 0, pCh^.ageMotherAtChildbirth);
				indUnionWoman := pCh^.motherUnionNumber;
				ageUnionWomanInd := trunc (getWomanFromBigArray (womanInd).unionStates.Unions [indUnionWoman - 1].ages[le_union, woman]) - kMinAgeFert;
				if (pCh^.dateBirth.yearBirth >= gFirstCohortAncestorsChildren) and (pCh^.dateBirth.yearBirth <= gLastCohortAncestorsChildren) then begin
					indCohort := pCh^.dateBirth.yearBirth - gFirstCohortAncestorsChildren;
					if RangeBirthsBACKFORNb[indCohort, ageUnionWomanInd] >=
						length(RangeBirthsBACKFORInfo[indCohort, ageUnionWomanInd]) then
						SetLength(
							RangeBirthsBACKFORInfo[indCohort, ageUnionWomanInd],
							length(RangeBirthsBACKFORInfo[indCohort, ageUnionWomanInd]) + kSetLengthBirths);
					RangeBirthsBACKFORInfo[indCohort, ageUnionWomanInd, RangeBirthsBACKFORNb[indCohort, ageUnionWomanInd]] := womanInd;
					Inc (RangeBirthsBACKFORNb[indCohort, ageUnionWomanInd]);
				end;
				gotoToNextLiveBornChild(pCh);
			end;
			if n <> nbChildren then
				writeAndWait ('Mismatch in number of children added in Arrays, women: ' + IntToStr (idWoman));
		end;
	end;
	
	procedure writeAgeChildbearingStates;
	var
		f: TFileType; // Main thread only
		age: FecundAges;
		res: longint;
	begin
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + 'ageChildbearing.txt', res, 'WRITEAGECHILDBEARINGSTATES');
			if res <> 0 then begin
				f.Destroy;
				exit;
			end;
			f.aSync := false;
			for age := kMinAgeFert to kMaxAgeFert do
				bWrite (f, [tab, age]);
			cWriteLn (f);
			bWrite (f, ['gAgeChildbearing', tab]);
			for age := kMinAgeFert to kMaxAgeFert do
				bWrite (f, [gAgeChildbearing [age], tab]);
			cWriteLn (f);
			if gBACKFOR_mode or gBACKFOR_mode_pure then begin
				bWrite (f, ['gAgeChildbearingBACKFOR', tab]);
				for age := kMinAgeFert to kMaxAgeFert do
					bWrite (f, [gAgeChildbearingBACKFOR [age], tab]);
				cWriteLn (f);
				if gBACKFOR_mode_pure then begin
					bWrite (f, ['gAgeChildbearingBACKFOR_post', tab]);
					for age := kMinAgeFert to kMaxAgeFert do
						bWrite (f, [gAgeChildbearingBACKFOR_post [age], tab]);
					cWriteLn (f);
				end;
			end;
			f.Destroy;
		end;
	end;
	
	procedure writeInfoWomenBrides (
			firstCohort, lastCohort: longint;
			const womenPopNumbers: array of longint;
			fileName, fileInfo: string
	);
	var
		cohortWomen, cohortWomenInd: longint;
		f: TFileType; // Main thread only
		res: longint;
	begin
		if not g_GENPARAM.CHECK_DATASTRUCT.value then exit;
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + fileName, res, fileInfo);
			if res <> 0 then begin
				f.Destroy;
				exit;
			end;
			f.aSync := false;
			for cohortWomen := firstCohort to lastCohort do
				bWrite(f, [cohortWomen, tab]);
			cWriteLn (f);
			for cohortWomen := firstCohort to lastCohort do begin
				cohortWomenInd := cohortWomen - firstCohort;
				bWrite(f, [womenPopNumbers[cohortWomenInd], tab]);
			end;
			cWriteLn (f);
			f.Destroy;
		end;
	end;

	procedure writeInfoGrooms (table: array2OfLongint; s: string = '');
	var
		cohort, indCohort: longint;
		age, ageInd: longint;
		f: TFileType; // Main thread only
		res: longint;
	begin
		if not g_GENPARAM.CHECK_DATASTRUCT.value then exit;
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + 'Grooms.txt', res, 'WRITEINFOGROOMS');
			if res <> 0 then begin
				f.Destroy;
				exit;
			end;
			f.aSync := false;
			for age := kMinAgeUnion_men to kMaxAgeUnion_men do
				bWrite(f, [tab, age]);
			cWriteLn (f);
			for cohort := gFirstCohortGrooms to gLastCohortGrooms do begin
				indCohort := cohort - gFirstCohortGrooms;
				bWrite(f, [cohort, tab]);
				for age := kMinAgeUnion_men to kMaxAgeUnion_men do begin
					ageInd := age - kMinAgeUnion_men;
					bWrite(f, [table[indCohort, ageInd], tab]);
				end;
				cWriteLn(f);
			end;
			f.Destroy;
		end;
	end;
	
	procedure writeInfoBridesYear (table: array2OfLongint; s: string = '');
	var
		year, yearInd: longint;
		age, ageInd: longint;
		f: TFileType; // Main thread only
		res: longint;
	begin
		if not g_GENPARAM.CHECK_DATASTRUCT.value then exit;
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + 'unionsYear.txt', res, 'WRITEINFOBRIDESYEAR');
			if res <> 0 then begin
				f.Destroy;
				exit;
			end;
			f.aSync := false;
			for age := kMinAgeUnion_men to kMaxAgeUnion_men do
				bWrite(f, [tab, age]);
			cWriteLn (f);
			for year := gFirstYearUnions to gLastYearUnions do begin
				yearInd := year - gFirstYearUnions;
				bWrite(f, [year, tab]);
				for age := kMinAgeUnion_men to kMaxAgeUnion_men do begin
					ageInd := age - kMinAgeUnion_men;
					bWrite(f, [table[yearInd, ageInd], tab]);
				end;
				cWriteLn(f);
			end;
			f.Destroy;
		end;
	end;
	
	procedure writeInfoMenWomen;
	var
		cohort, indCohort: longint;
		ageMan, ageManInd: longint;
		ageWoman, ageWomanInd: longint;
		f: TFileType; // Main thread only
		res: longint;
	begin
		if not g_GENPARAM.CHECK_DATASTRUCT.value then exit;
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + 'MenWomen.txt', res, 'WRITEINFOMENWOMEN');
			if res <> 0 then begin
				f.Destroy;
				exit;
			end;
			f.aSync := false;
			bWriteLn (f, ['Cohort', tab, 'ageMan', tab, 'ageWoman', tab, 'Number']);
			for cohort := gFirstCohortGrooms to gLastCohortGrooms do begin
				indCohort := cohort - gFirstCohortGrooms;
				for ageMan := kMinAgeUnion_men to kMaxAgeUnion_men do begin
					ageManInd := ageMan - kMinAgeUnion_men;
					for ageWoman := kMinAgeUnion_women to kMaxAgeUnion_women do begin
						ageWomanInd := ageWoman - kMinAgeUnion_women;
{$IFDEF DEBUG}
if (ageMan < 0) or (ageWoman < 0) then
	writeAndWait ('age union bad for gMen_Women');
if (indCohort < 0) or (indCohort >= length(gMen_Women)) then
	writeAndWait ('Bad value for cohortMan in gMen_Women: ' + IntToStr (cohort));
if (ageManInd < kNotDefined) or (ageManInd >= length(gMen_Women[0])) then
	writeAndWait ('Bad value for ageUnionMan in gMen_Women: ' + IntToStr (ageMan));
if (ageWomanInd < kNotDefined) or (ageWomanInd >= length(gMen_Women[0, 0])) then
	writeAndWait ('Bad value for ageUnionWoman in gMen_Women: ' + IntToStr (ageWoman));
{$ENDIF}

						bWriteln(f, [cohort, tab, ageMan, tab, ageWoman, tab, gMen_Women[indCohort, ageManInd, ageWomanInd]]);
					end;
				end;
			end;
			f.Destroy;
		end;
	end;
	
	procedure writeState (s: string; table: arrayOfLongint; minY, maxY: longint);
	var
		index, indexInd, res: longint;
		f: TFileType; // Main thread only
	begin
		if not g_GENPARAM.CHECK_DATASTRUCT.value then exit;
		if checkDirResult () then begin
			f := TFileType.Create (gPathToResult + s + '.txt', res, 'WRITESTATE');
			f.aSync := false;
			if res = 0 then begin
				for index := minY - kStateRangeLengthLimit to maxY + kStateRangeLengthLimit do begin
					bWrite(f, [index, tab]);
				end;
				cWriteLn(f);
				for index := minY - kStateRangeLengthLimit to maxY + kStateRangeLengthLimit do begin
					indexInd := index - (minY - kStateRangeLengthLimit);
					bWrite(f, [trunc (table[indexInd]), tab]);
				end;
				cWriteLn(f);
			end;
			f.Destroy;
		end;
	end;
	
	procedure writeStates;
	begin
		if not g_GENPARAM.CHECK_DATASTRUCT.value then exit;
		writeState ('gStateChildren', gStateChildren, gFirstCohortAncestorsChildren, gLastCohortAncestorsChildren);
		//writeState ('gStateBrides', gStateBrides, gFirstCohortBrides, gLastCohortBrides);
		//writeState ('gStateMothers', gStateMothers, gFirstCohortWomen, gLastCohortWomen);
		writeState ('gStateGrooms', gStateGrooms, gFirstCohortGrooms, gLastCohortGrooms);
		//writeState ('gStateYearUnions', gStateYearUnions, gFirstYearUnions, gLastYearUnions);
	end;
	
	function getAgeChildbearing (pChildrenList: pInfoChildType; cohortChild: longint): double;
	begin
		result := kNotDefined;
		while pChildrenList <> nil do begin
			if pChildrenList^.dateBirth.yearBirth = cohortChild then begin
				result := pChildrenList^.ageMotherAtChildbirth;
				exit;
			end;
			pChildrenList := pChildrenList^.next;
		end;
		WriteAndWait ('Child not found in getAgeChildbearing');
	end;

	function CreateWomenSetForCohort(randomGenerator: TRandomNumberGenerator;
            				pData: pThreadCohortData;
							threadNumber: longint;
							var totalWomenBridesCreated: longint): boolean;
	var
		womanObj: TWomanMemoryBlock;
		unionStates: TUnionsType = nil;
		pChildrenList: pInfoChildType = nil;
		ageChildren: TabCompFertAge;
		indWoman, nbChildren, idWoman: longint;
		isThreaded: boolean;
	begin
		{We build the list of women possible mothers or brides
		We do it for each cohort separately. We have a number of women by cohort
		and for each one we select an age at first union in a random way.
		The latter is very important. The alternative way would be to iterate on the age at first union,
		for lower to higher ages, but this would have the undesired effect of having
		distributions of women ordered in a non stochastic way: first women with a lower union age and then
		higher fertility level}
		result := false;

		isThreaded := (threadNumber > 0);
		stdWriteLn(['Cohort: ', pData^.cohort, ', ', pData^.womenType, ': ', pData^.nWomen, ', thread: ', threadNumber]);

		for indWoman := 0 to pData^.nWomen - 1 do begin

	if not isThreaded then begin
	Inc (gIndMother);
	end;

	{$IFDEF DEBUG}
	if not isThreaded then begin
	if (gIndMother = 1803149) or (gIndMother = 135202) then
		gIndMother := gIndMother;
	end;
	{$ENDIF}
			// all the women should enter an union to be considered as possible bride or mother
			// this is controlled setting kNoSinglehood in calc_ageUnion...
			pChildrenList := nil;
{$IFDEF OLD_INITMOTHERHOOD}
{$ELSE}
{$ENDIF}

			if isThreaded then
				unionStates := TUnionsType.Create(pData^.pDemReg^.yearOfBirth.value * 100000 + indWoman, woman)
			else
				unionStates := TUnionsType.Create(gIndMother, woman);
			nbChildren := calcCompleteFertilityWoman(
								randomGenerator,
								pData^.pDemReg,
								kDeathOfMotherPossible,
								kDeathOfFatherPossible,
								calc_ageUnion(randomGenerator, kMinAgeUnion_women, kMaxAgeUnion_women,
									pData^.pDemReg^.pCurrUnionInfo^.prop_cel_women, kNoSinglehood),
								1,
								unionStates,
								ageChildren,
								pChildrenList,
								unionStates.fecundLife,
								nil,
								nil,
								kNewReproductiveLife,
								isThreaded
							);

			if g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_INITMOTHERHOOD.value and (gMaxThreads > 1) then begin
				idWoman := indWoman + 1;
			end else begin
				Inc (totalWomenBridesCreated);
				idWoman := totalWomenBridesCreated;
			end;

			if not pData^.womenCollection.addWoman (
						TWomanMemoryBlock.Create(
						// when in a thread, idWoman is specific for each cohort: important for multithreading
						randomGenerator, idWoman,
						pData^.cohort, nbChildren, unionStates, pChildrenList, nil)
					) then
				exit;

			disposeChild (pChildrenList);
	{$IFDEF OLD_INITMOTHERHOOD}
	{$ELSE}
	{$ENDIF}
			FreeAndNil (unionStates);
		end; {indWoman}
		result := true;
	end;

	Constructor TCohortWomenSet.Create(CreateSuspended : boolean; pData: pThreadCohortData; ind: longint);
	begin
		inherited Create(CreateSuspended);
		myData.pDemReg := pData^.pDemReg;
		myData.nWomen := pData^.nWomen;
		myData.cohort := pData^.cohort;
		myData.womenType := pData^.womenType;
		myData.womenCollection := pData^.womenCollection;
		myThreadNumber := ind;
		myRandomGenerator := TRandomNumberGenerator.Create(g_GENPARAM.INIT_RANDOM_NUMBERS.value);
		FAFinished := false;
	end;

	Destructor TCohortWomenSet.Destroy();
	begin
		myRandomGenerator.Destroy()
	end;
	
	procedure TCohortWomenSet.Execute;
	var
		dummy: longint = 0;
	begin
		FAFinished := false;
		CreateWomenSetForCohort (myRandomGenerator, @myData, myThreadNumber, dummy);
		FAFinished := true;
	end;

	Constructor TBigCohortsWomenSet.Create(CreateSuspended : boolean; pData: pThreadCohortDataArray; ind: longint);
	begin
		inherited Create(CreateSuspended);
		myData.arrayOfData := pData^.arrayOfData;
		myData.womenType := pData^.womenType;
		myData.womenCollection := pData^.womenCollection;
		myThreadNumber := ind;
		MyWomenCount := 0;
		myRandomGenerator := TRandomNumberGenerator.Create (g_GENPARAM.INIT_RANDOM_NUMBERS.value);
		FAFinished := false;
	end;

	Destructor TBigCohortsWomenSet.Destroy();
    begin
		myRandomGenerator.Destroy()
	end;

	procedure TBigCohortsWomenSet.Execute;
	var
		ind: longint;
		cohortData: ThreadCohortData;
	begin
		FAFinished := false;
		cohortData.womenType := myData.womenType;
		cohortData.womenCollection := myData.womenCollection;

		for ind := low(myData.arrayOfData) to high(myData.arrayOfData) do begin
			cohortData.pDemReg := myData.arrayOfData[ind].pDemReg;
			cohortData.nWomen := myData.arrayOfData[ind].nWomen;
			cohortData.cohort := myData.arrayOfData[ind].cohort;
			CreateWomenSetForCohort (myRandomGenerator, @cohortData, myThreadNumber, MyWomenCount);
		end;
		FAFinished := true;
	end;

	procedure initPopNumber (firstCohort, lastCohort: longint; r: double; var womenPopNumbers: array of longint);
	var
		cohort, indCohort: longint;
		pDemReg: pStructDemographicRegimeSettings;
	begin
		for cohort := firstCohort to lastCohort do begin
			pDemReg := getCohort_p (cohort);
			indCohort := cohort - firstCohort;
			// should be a number equivalent to births
			if StablePopulation() then begin
			// exponential growth of births, with the rate of the associated stable population
			// this is why we limit the value of r: if too high or too low, we reach very high values
				womenPopNumbers[indCohort] := trunc ( g_GENPARAM.RUNTIME[cmd_numberWomen].value * exp ( -r * ( lastCohort - cohort )) );
			end else begin
			// number of births read in the cohort file
				womenPopNumbers[indCohort] := pDemReg^.lp[nWomenPar].value;
			end;
		end; {cohort}
	end;

{$IFDEF OLD_INITMOTHERHOOD}
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
		tStart, tEnd, tDiff: TDateTime;  // Begin and end of measurement
		iHours, iMinutes, iSeconds, iMilliseconds: Word;  // Time components

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
		f.aSync := false;
		if res = 0 then
			cWriteLn (f, 'Bad brides! (no problem if this is the only line)');
		f.Destroy;
		f := TFileType.Create (gPathToResult + 'ProblemChildren.txt', res, 'PROBLEMCHILDREN');
		f.aSync := false;
		if res = 0 then
			cWriteLn (f, 'Bad chidren! (no problem if this is the only line)');
		f.Destroy;
	end;
end;
{$ENDIF}
		if gBACKFOR_mode then begin
			stdWriteLn (['Le Bras'' BACKFOR mode']);
		end;
		if gBACKFOR_mode_pure then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			stdWriteLn (['Le Bras'' pure BACKFOR mode']);
		end;
		if gCAMSIM_1987 then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			stdWriteLn (['CAMSIM 1987 mode']);
		end;
		if gCAMSIM_1993 then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			stdWriteLn (['CAMSIM 1993 mode']);
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
					stdWriteLn (['initMotherhood: stable population growth rate too low, limited to -0.02']);
				end;
				if (r > 0.02) then begin
					r := 0.02;
					stdWriteLn (['initMotherhood: stable population growth rate too high, limited to 0.02']);
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
		
		gThisIsNotanArrayOfBrides := true;
		gBig_ArrayWomen_NEW := TWomenMemoryManager.Create();
		SetLength (g_WomenPopNumbers, gLastCohortWomen - gFirstCohortWomen + 1);
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation() then begin
				gThisIsNotanArrayOfBrides := false;
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

		stdWriteLn(['============  Init cohort of women possible mothers and / or brides ========']);
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
					addBridesInfo (indBride, gThisIsNotanArrayOfBrides);
					addGroomsInfo (indBride, gThisIsNotanArrayOfBrides);
					addUnionsInfo (indBride, gThisIsNotanArrayOfBrides);
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

//if g_GENPARAM.CHECK_DATASTRUCT.value then begin
//writeInfoWomen;
//writeInfoBrides;
//writeInfoGrooms(g_RangeGroomsNb);
//writeInfoBridesYear(g_RangeYearUnionsNb);
//checkBrides ('End initMotherhood', gThisIsNotanArrayOfBrides);
//checkChildren ('End initMotherhood');
//end;
{$ENDIF}

        tEnd := Now();
		tDiff:= tEnd - tStart;  // Subtract higher from lower value
		DecodeTime( tDiff, iHours, iMinutes, iSeconds, iMilliseconds );  // Does not account for day changes when executing around midnight
		stdWriteLn( ['initMotherhood took: ', iHours, ' h, ', iMinutes, ' min, ', iSeconds, ' sec, ', iMilliseconds, ' msec '] );

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
			checkBrides ('disposeMotherhood', gThisIsNotanArrayOfBrides);
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

{$ELSE}
	procedure multiThreaded_initMotherhood (
				firstCohort, lastCohort: longint;
				r: double;
				womenBridesType: string;
				var womenPopNumbers: array of longint;
				var totalWomenBridesCreated: longint;
				var bigArrayWomen: TWomenMemoryManager);
	var
		threadNumber, ind: longint;
		indCohort, indWoman, cohort: longint;
		firstCohort_inter, lastCohort_inter, interCohorts: longint;
		numberWomenCollection: longint;
        nActiveThreads: longint;
		womanObj: TWomanMemoryBlock;
		cohortArrayOfWomen: array of TWomenMemoryManager;
		BigCohortWomenThreads: array of TBigCohortsWomenSet;
		cohortThreadDataArray: ThreadCohortDataArray;
	begin
		setLength (cohortArrayOfWomen{%H-}, gMaxThreads);
		setLength (BigCohortWomenThreads{%H-}, gMaxThreads);
		initPopNumber(firstCohort, lastCohort, r, womenPopNumbers);
		
		threadNumber := 0;
		setLength (BigCohortWomenThreads, gMaxThreads);
		interCohorts := trunc ((lastCohort - firstCohort + 1) / gMaxThreads);
		cohortThreadDataArray.womenType := womenBridesType;
		for ind := 1 to gMaxThreads do begin
			firstCohort_inter := firstCohort + (ind-1) * interCohorts;
			lastCohort_inter := firstCohort + (ind) * interCohorts;
			if ind = gMaxThreads then lastCohort_inter := lastCohort;
			setLength (cohortThreadDataArray.arrayOfData, lastCohort_inter - firstCohort_inter + 1);
			numberWomenCollection := 0;
			for indCohort := 0 to (lastCohort_inter - firstCohort_inter) do begin
				cohort := indCohort + firstCohort_inter;
				numberWomenCollection := numberWomenCollection + womenPopNumbers[cohort - firstCohort];
				cohortThreadDataArray.arrayOfData[indCohort].pDemReg := getCohort_p(cohort);
				cohortThreadDataArray.arrayOfData[indCohort].cohort := cohort;
				cohortThreadDataArray.arrayOfData[indCohort].nWomen := womenPopNumbers[cohort - firstCohort];
			end;
			cohortThreadDataArray.womenCollection := TWomenMemoryManager.Create (numberWomenCollection, false);
			cohortArrayOfWomen [ind-1] := cohortThreadDataArray.womenCollection;
			BigCohortWomenThreads[ind-1] := TBigCohortsWomenSet.Create(true, @cohortThreadDataArray, ind);
			setLength (cohortThreadDataArray.arrayOfData, 0);
		end;
		// multithreading loop
		nActiveThreads := 0;
		repeat
			for ind := Low(BigCohortWomenThreads) to High(BigCohortWomenThreads) do begin
				if BigCohortWomenThreads[ind].AFinished then begin
					Dec(nActiveThreads);
					BigCohortWomenThreads[ind].Terminate;
				end
				else if (nActiveThreads < gMaxThreads) then begin
					InterlockedIncrement (nActiveThreads);
					BigCohortWomenThreads[ind].start;
				end;
			end;
		until (nActiveThreads <= 0);
		for ind := Low(BigCohortWomenThreads) to High(BigCohortWomenThreads) do begin
			repeat until BigCohortWomenThreads[ind].AFinished;
			BigCohortWomenThreads[ind].Destroy;
		end;
		setLength (BigCohortWomenThreads, 0);

		// copy women of each cohort collection to the big table of women
		for ind := low(cohortArrayOfWomen) to high(cohortArrayOfWomen) do begin
			for indWoman := 1 to cohortArrayOfWomen [ind].numWomen() do begin
				Inc (totalWomenBridesCreated);
				womanObj := cohortArrayOfWomen [ind].getWoman (indWoman - 1);
				womanObj.idWoman := totalWomenBridesCreated;
				bigArrayWomen.addWoman (womanObj);
			end;
			cohortArrayOfWomen [ind].Destroy;
		end;
		setLength(cohortArrayOfWomen, 0);
	end;
	
	procedure nonMulti_initMotherhood (
                randomGenerator: TRandomNumberGenerator;
				firstCohort, lastCohort: longint;
				r: double;
				womenBridesType: string;
				var womenPopNumbers: array of longint;
				var totalWomenBridesCreated: longint;
				var bigArrayWomen: TWomenMemoryManager);
	var
		threadNumber: longint;
		cohort, indCohort: longint;
		pDemReg: pStructDemographicRegimeSettings;
		cohortThreadData: ThreadCohortData;
 	begin
		initPopNumber(firstCohort, lastCohort, r, womenPopNumbers);
		
		threadNumber := 0;
		for cohort := firstCohort to lastCohort do begin
			pDemReg := getCohort_p (cohort);
			indCohort := cohort - firstCohort;

			cohortThreadData.pDemReg := pDemReg;
			cohortThreadData.nWomen := womenPopNumbers[indCohort];
			cohortThreadData.cohort := cohort;
			cohortThreadData.womenType := womenBridesType;
			cohortThreadData.womenCollection := bigArrayWomen;
		
			CreateWomenSetForCohort(randomGenerator, @cohortThreadData, threadNumber, totalWomenBridesCreated);
		end; {cohort}
	end;
	
	procedure initMotherhood (randomGenerator: TRandomNumberGenerator);
	var
		cohort, age, indMother, indBride, indCohort: longint;
		{Number of women simulated in each cohort for the big array}
		womenPopNumbers: array of longint;
		bridesPopNumbers: array of longint;

		pDemReg: pStructDemographicRegimeSettings;
		indChild: longint;
		tStart, tEnd, tDiff: TDateTime;  // Begin and end of measurement
		iHours, iMinutes, iSeconds, iMilliseconds: Word;  // Time components
{==============================================}
        MULTITHREADING: boolean;
{==============================================}

		totalWomenBridesCreated: longint;
		r: double;
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
		f.aSync := false;
		if res = 0 then
			cWriteLn (f, 'Bad brides! (no problem if this is the only line)');
		f.Destroy;
		f := TFileType.Create (gPathToResult + 'ProblemChildren.txt', res, 'PROBLEMCHILDREN');
		f.aSync := false;
		if res = 0 then
			cWriteLn (f, 'Bad chidren! (no problem if this is the only line)');
		f.Destroy;
	end;
end;
{$ENDIF}
		if gBACKFOR_mode then begin
			stdWriteLn (['Le Bras'' BACKFOR mode']);
		end;
		if gBACKFOR_mode_pure then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			stdWriteLn (['Le Bras'' pure BACKFOR mode']);
		end;
		if gCAMSIM_1987 then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			stdWriteLn (['CAMSIM 1987 mode']);
		end;
		if gCAMSIM_1993 then begin
			gBACKFOR_women := 0;
			gBACKFOR_nTries := 0;
			stdWriteLn (['CAMSIM 1993 mode']);
		end;

		if StablePopulation() then begin
			gFirstCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
			gLastCohortAncestorsChildren := g_GENPARAM.RUNTIME[cmd_lastCohort].value;
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
					stdWriteLn (['initMotherhood: stable population growth rate too low, limited to -0.02']);
				end;
				if (r > 0.02) then begin
					r := 0.02;
					stdWriteLn (['initMotherhood: stable population growth rate too high, limited to 0.02']);
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
			// variable demographic regimes
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
		
		gThisIsNotanArrayOfBrides := true;
		gBig_ArrayWomen_NEW := TWomenMemoryManager.Create();
		SetLength (womenPopNumbers{%H-}, gLastCohortWomen - gFirstCohortWomen + 1);
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation() then begin
				gThisIsNotanArrayOfBrides := false;
				gBig_ArrayBrides_NEW := TWomenMemoryManager.Create();
				SetLength (bridesPopNumbers{%H-}, gLastCohortBrides - gFirstCohortBrides + 1);
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

		stdWriteLn(['============  Init cohort of women possible mothers and / or brides ========']);
		FlushIO ();
		totalWomenBridesCreated := 0;
		MULTITHREADING := g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_INITMOTHERHOOD.value and (gMaxThreads > 1);

		if MULTITHREADING then
			multiThreaded_initMotherhood (
				gFirstCohortWomen, gLastCohortWomen, r, 'women',
				womenPopNumbers, totalWomenBridesCreated,
				gBig_ArrayWomen_NEW)
		else
			nonMulti_initMotherhood (
				randomGenerator, gFirstCohortWomen, gLastCohortWomen, r, 'women',
				womenPopNumbers, totalWomenBridesCreated,
				gBig_ArrayWomen_NEW);

		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation() then begin
				if MULTITHREADING then
					multiThreaded_initMotherhood (
						gFirstCohortBrides, gLastCohortBrides, r, 'brides',
						bridesPopNumbers, totalWomenBridesCreated,
						gBig_ArrayBrides_NEW)
				else
					nonMulti_initMotherhood (
						randomGenerator, gFirstCohortBrides, gLastCohortBrides, r, 'brides',
						bridesPopNumbers, totalWomenBridesCreated,
						gBig_ArrayBrides_NEW);
			end; {StablePopulation}
		end;
		
		if StablePopulation() then begin
			if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
				for indMother := 0 to gBig_ArrayWomen_NEW.numWomen - 1 do begin
					// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
					// AFTER THE BIG ARRAY HAVE BEEN CREATED
					addChildrenInfo (randomGenerator, indMother);
					if gBACKFOR_mode then
						addChildrenBACKFORInfo (randomGenerator, indMother);
				end;
				for indBride := 0 to gBig_ArrayBrides_NEW.numWomen - 1 do begin
					// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
					// AFTER THE BIG ARRAY HAVE BEEN CREATED
					addBridesInfo (indBride, gThisIsNotanArrayOfBrides);
					addGroomsInfo (indBride, gThisIsNotanArrayOfBrides);
					addUnionsInfo (indBride, gThisIsNotanArrayOfBrides);
				end;
			end else begin
				for indMother := 0 to gBig_ArrayWomen_NEW.numWomen - 1 do begin
					// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
					// AFTER THE BIG ARRAY HAVE BEEN CREATED
					addBridesInfo (indMother);
					addGroomsInfo (indMother);
					addChildrenInfo (randomGenerator, indMother);
					if gBACKFOR_mode then
						addChildrenBACKFORInfo (randomGenerator, indMother);
					addUnionsInfo (indMother);
				end;
			end;
		end else begin
			for indMother := 0 to gBig_ArrayWomen_NEW.numWomen - 1 do begin
				// AS WE PARALLELIZE THE CREATION OF WOMAN OBJECTS, WE DO THAT OUT OF THIS LOOP
				// AFTER THE BIG ARRAY HAVE BEEN CREATED
				addBridesInfo (indMother);
				addGroomsInfo (indMother);
				addChildrenInfo (randomGenerator, indMother);
				if gBACKFOR_mode then
					addChildrenBACKFORInfo (randomGenerator, indMother);
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

if g_GENPARAM.CHECK_DATASTRUCT.value then begin
writeInfoWomenBrides (gFirstCohortWomen, gLastCohortWomen, womenPopNumbers, 'women.txt', 'WRITEINFOWOMEN');
writeInfoWomenBrides (gFirstCohortBrides, gLastCohortBrides, bridesPopNumbers, 'brides.txt', 'WRITEINFOBRIDES');
writeInfoGrooms(g_RangeGroomsNb);
writeInfoBridesYear(g_RangeYearUnionsNb);
checkBrides ('End initMotherhood', gThisIsNotanArrayOfBrides);
checkChildren ('End initMotherhood');
end;
{$ENDIF}

		SetLength (womenPopNumbers, 0);
		SetLength (bridesPopNumbers, 0);

        tEnd := Now();
		tDiff:= tEnd - tStart;  // Subtract higher from lower value
		DecodeTime( tDiff, iHours, iMinutes, iSeconds, iMilliseconds );  // Does not account for day changes when executing around midnight
		stdWriteLn( ['initMotherhood took: ', iHours, ' h, ', iMinutes, ' min, ', iSeconds, ' sec, ', iMilliseconds, ' msec '] );

        g_endInitMotherhood := true;

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
			checkBrides ('disposeMotherhood', gThisIsNotanArrayOfBrides);
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

{$ENDIF} // OLD_INITMOTHERHOOD

	procedure disposeMotherhood_DemReg;
	// This part is disposed of when the Demographic Regime Collection is destroyed
	begin
		SetLength (gMen_Women, 0);
		SetLength (gStateChildren, 0);
		SetLength (gStateMothers, 0);
		SetLength (gStateBrides, 0);
		SetLength (gStateGrooms, 0);
		SetLength (gStateYearUnions, 0);
	end;
	
	function openFileKinship (bootstrap_ind: longint): boolean;
	var
		mess: string;
	begin
		mess := g_FileName.value;
		openFileKinship := initAggrKinshipFile(mess, TRUE, bootstrap_ind);
	end;

	function getPartnershipStatus (pRelative: pRelativeType; isFirstUnion: boolean; ageRef: longint): PartnershipStatusesType;
	// No test for ageRef > age of death of pRelative
	begin
		if (pRelative^.typeOfKin in gKinsWithNoDescendance) then begin
			getPartnershipStatus := any;
			exit;
		end;
		if (pRelative^.nUnions = 0) then
			getPartnershipStatus := neverInUnion
		else begin
			if getAgeUnion (pRelative, 1) - pRelative^.ageAtBirthOfEgo < ageRef then
				getPartnershipStatus := neverInUnion
			else if getAgeEndUnion (pRelative, 1) - pRelative^.ageAtBirthOfEgo <= ageRef then
				getPartnershipStatus := firstUnion;
			if (getCauseEndUnion (pRelative, 1) = end_by_separation) then
				getPartnershipStatus := separated
			else
				getPartnershipStatus := widow;
		end;
		
	end;

	procedure copyWomanPartnershipInfoToManAsRelative (woman_unionStates: TUnionsType; woman_indUnion: longint; var pMan: pRelativeType);
	var
		ind: longint;
		durationUnionWoman, durationUnionMan: double;
	begin
		// we may have partial or incomplete union history for the man
		// so we need to be super cautious here and check everything
		with pMan^ do begin
			if ageDeath <= 0 then
				ageDeath := woman_unionStates.Unions [woman_indUnion - 1].ages[le_death, man];

			// first check whether there are already ages at union entered for that man
			ind := 0;
			while getAgeUnion (pMan, ind+1) > 0 do
				Inc (ind);
			// next we check that the last age at union is not the one for the current union
			if (ind >= 1) and (getAgeUnion (pMan, ind) = woman_unionStates.Unions [woman_indUnion - 1].ages[le_union, man]) then
				ind := ind - 1;
			// finally we set the union number to the correct position
			// if this is the first union for the man, than ind will be equal to 0
			// if there is already at least an age at union, ind will be equal to the number of previous Unions for the man
			// but if the last age at union is equal to the current one, than ind will be decreased by one
			nUnions := ind + 1;

			ind := nUnions;
			setAgeUnion (pMan, ind, woman_unionStates.Unions [woman_indUnion - 1].ages[le_union, man]);
			if 	(woman_unionStates.Unions [woman_indUnion - 1].ages[le_endUnion, man] > 0) then begin
				setAgeEndUnion (pMan, ind, woman_unionStates.Unions [woman_indUnion - 1].ages[le_endUnion, man]);
				setCauseEndUnion (pMan, ind, end_by_separation);
			end else begin
				durationUnionWoman := 	woman_unionStates.Unions [woman_indUnion - 1].ages[le_death, woman] -
										woman_unionStates.Unions [woman_indUnion - 1].ages[le_union, woman];
				durationUnionMan := 	woman_unionStates.Unions [woman_indUnion - 1].ages[le_death, man] -
										woman_unionStates.Unions [woman_indUnion - 1].ages[le_union, man];
				if durationUnionMan < durationUnionWoman then begin
					setAgeEndUnion (pMan, ind,
						woman_unionStates.Unions [woman_indUnion - 1].ages[le_death, man]);
					setCauseEndUnion (pMan, ind, end_by_death);
				end else begin
					setAgeEndUnion (pMan, ind,
						woman_unionStates.Unions [woman_indUnion - 1].ages[le_union, man] + durationUnionWoman);
					setCauseEndUnion (pMan, ind, end_by_widowhood);
				end;
			end;

			// references to partners should be added afterwards
			setPartner (pMan, ind, nil);

			// references to biological children should be added afterwards
			emptyRelativeChildList (pMan);
		end;
	end;

	procedure copyWomanPartnershipInfoToWomanAsRelative (unionStates: TUnionsType; var pWoman: pRelativeType);
	var
		ind: longint;
		durationUnionWoman, durationUnionMan: double;
	begin
		with pWoman^ do begin
			ageDeath := unionStates.Unions [0].ages[le_death, woman];
			nUnions := unionStates.nbUnions;
			for ind := 1 to nUnions do begin
				setAgeUnion (pWoman, ind, unionStates.Unions [ind - 1].ages[le_union, woman]);
				if 	(unionStates.Unions [ind - 1].ages[le_endUnion, woman] > 0) then begin
					setAgeEndUnion (pWoman, ind, unionStates.Unions [ind - 1].ages[le_endUnion, woman]);
					setCauseEndUnion (pWoman, ind, end_by_separation);
				end else begin
					durationUnionWoman := unionStates.Unions [ind - 1].ages[le_death, woman] - unionStates.Unions [ind - 1].ages[le_union, woman];
					durationUnionMan := unionStates.Unions [ind - 1].ages[le_death, man] - unionStates.Unions [ind - 1].ages[le_union, man];
					if durationUnionMan < durationUnionWoman then begin
						setAgeEndUnion (pWoman, ind, unionStates.Unions [ind - 1].ages[le_union, woman] + durationUnionMan);
						setCauseEndUnion (pWoman, ind, end_by_widowhood);
					end else begin
						setAgeEndUnion (pWoman, ind, unionStates.Unions [ind - 1].ages[le_death, woman]);
						setCauseEndUnion (pWoman, ind, end_by_death);
					end;
				end;
				// references to partners should be added afterwards
				setPartner (pWoman, ind, nil);
			end;
			// references to biological children should be added afterwards
			emptyRelativeChildList (pWoman);
		end;
	end;
	
	function calcAgeAtBirthOfEgo (pEgo, pRelative: pRelativeType): longint;
	var
		distanceInMonths, offset: longint;
	begin
{$IFDEF DEBUG}
if (pEgo^.dateBirth.yearBirth < 0) or (pEgo^.dateBirth.monthBirth < 0)
	or (pRelative^.dateBirth.yearBirth < 0) or (pRelative^.dateBirth.monthBirth < 0) then
	writeAndWait ('Problem dates in calcAgeAtBirthOfEgo');
{$ENDIF}
	{We compute age relative to ego in such a way that a person born at a distance of
	more or less 6 months is of the same age than ego. If the distance is higher than
	6 months, than that person will be at least 1 year older or younger (if the distance is negative)}
		distanceInMonths := ( pEgo^.dateBirth.yearBirth - pRelative^.dateBirth.yearBirth ) * kNbLunarMonths +
				( pEgo^.dateBirth.monthBirth - pRelative^.dateBirth.monthBirth );

		offset := 6;
		if distanceInMonths > 0 then begin
			distanceInMonths := distanceInMonths + offset;
		end else begin
			distanceInMonths := distanceInMonths - offset;
		end;
		result := trunc ( distanceInMonths / kNbLunarMonths );
	end;
	
{destiny of a newborn individual: normally it will be ego or a new born children}
	procedure destiny (randomGenerator: TRandomNumberGenerator;
                kinType: KinTypes;
                pRelative: pRelativeType;
                setSex: boolean = true);
	var
		cohortCurr: longint;
		pDemReg: pStructDemographicRegimeSettings;
		
	begin
		cohortCurr:= pRelative^.dateBirth.yearBirth;
		{change DemographicRegime for the cohort}
		pDemReg := getCohort_p (cohortCurr);
		with pRelative^ do
			begin
				typeOfKin := kinType;
				if kinType = kt_ego then
					ageAtBirthOfEgo := 0;
				if setSex then gender := sexAtBirth (randomGenerator, pDemReg, 0);
				cohort := cohortCurr;
				if kinType = kt_ego then begin
					if dateBirth.monthBirth < 0 then begin
						dateBirth.monthBirth := trunc (randomGenerator.alea (1, kNbLunarMonths + 0.9999999999));
						dateBirth.dayBirth := trunc (randomGenerator.alea (1, 30.9999999999));
					end;
					dateBirth.yearBirth := cohortCurr;
				end;
				cohortDemReg := pDemReg^.yearOfBirth.value;
				nUnions := 1;
				if gender = man then
					begin
						if getAgeUnion (pRelative, nUnions) < 0 then
							setAgeUnion (pRelative, nUnions,
								calc_ageUnion(randomGenerator, kMinAgeUnion_men, kMaxAgeUnion_men, pDemReg^.pCurrUnionInfo^.prop_cel_men));
						if ageDeath < 0 then
							ageDeath := calc_ageDeath(randomGenerator, 0, pDemReg^.mortalityInfo.survival_men);
					end
				else
					begin
						if getAgeUnion (pRelative, nUnions) < 0 then
							setAgeUnion (pRelative, nUnions,
								calc_ageUnion(randomGenerator, kMinAgeUnion_women, kMaxAgeUnion_women, pDemReg^.pCurrUnionInfo^.prop_cel_women));
						if ageDeath < 0 then
							ageDeath := calc_ageDeath(randomGenerator, 0, pDemReg^.mortalityInfo.survival_women);
					end;
				if getAgeUnion (pRelative, nUnions) = kNotDefined then nUnions := nUnions - 1;
				if (nUnions > 0) and (ageDeath <= getAgeUnion (pRelative, nUnions)) then begin
					setAgeUnion (pRelative, nUnions, kNotDefined);
					nUnions := 0;
				end;
			end;
	end;

	function CalcChildren (pEgo: pRelativeType): longint;
	var
		n: longint = 0;
		pRelative: pRelativeType;
	begin
		if pEgo^.typeOfKin <> kt_ego then exit;

		pRelative := pEgo;
		while pRelative <> nil do begin
			if (pRelative^.typeOfKin = kt_child) and (pRelative^.kinOf = pEgo) then n := n + 1;
			pRelative := pRelative^.nextRelative;
		end;
		if n <> getNumChildren (pEgo) then
			stdWriteLn(['nbChildren bad']);
		CalcChildren := n;
	end;
	
	function writeKinDemoCare (ageRefEgo, nbFamily: longint; pEgo: pRelativeType; pRelative: pRelativeType; checkLinks: boolean): boolean;
	var
		i: longint = 1;
		tickIn, tickOut: longint;
		tickIn2, tickOut2: longint;
		ageRel, ageTickIn, ageRel2: longint;
				ageDeathInt: longint;
		isEgo: boolean;
		pPartner: pRelativeType;
		rank: longint;
		nChildren: longint = 0;
		
	begin
		isEgo := ( pEgo = pRelative );
		
		if isEgo then begin
			nChildren := CalcChildren (pRelative);
			if ( nChildren <> getNumChildren (pEgo) ) then
				writeAndWait ('tontou!!!!');
		end;
		
		with pRelative^ do begin
			// ageRel: age of relative -relative- to ego, vary when ego ages
			ageRel := ageRefEgo + ageAtBirthOfEgo;
			// ageTickIn: age when the person enters ego's life, when ego has age 50
			ageTickIn := max(0, ageRel);
			ageDeathInt := trunc (ageDeath);
			if byUnion (pEgo, pRelative) then begin
				tickIn := max(0, trunc (getAgeUnion (pRelative, 1))-ageRel);
				tickOut := ageDeathInt-ageRel;
				if (tickIn > 0) then ageRel := trunc (getAgeUnion (pRelative, 1));
			end else begin
				if (ageRel >= 0) then
					tickIn := 0
				else
					tickIn := max(0, -ageRel);
				tickOut := ageDeathInt-ageRel;
			end;

			ageRel := max(0, ageRel);
			
			if byUnion (pEgo, pRelative) then
				ageRel2 := trunc (getAgeUnion (pRelative, 1))
			else
				ageRel2 := 0;
			
			tickIn2 := ageRel2 - ageRefEgo - ageAtBirthOfEgo;
			if (tickIn2 < 0) then begin
				ageRel2 := ageRel2 - tickIn2;
				tickIn2 := 0;
			end;
			tickOut2 := ageDeathInt - ageRefEgo - ageAtBirthOfEgo;
			ageRel2 := ageRel - tickIn;
			
			if checkLinks then begin
				if (tickOut < 0) then begin
				{case of relatives who died before ego reached reference age}
				{we drop them if they don't contribute a link to the kin network}
					if (typeOfKin = kt_partner) and (gender = man) then begin
						writeKinDemoCare := FALSE;
						exit;
					end;
					if (gender = woman) and (getNumChildren (pRelative) = 0) then begin
						writeKinDemoCare := FALSE;
						exit;
					end;
					if (nUnions = 0) then begin
						writeKinDemoCare := FALSE;
						exit;
					end;
				end;
			end else begin
				if RP.wKey then bWrite (gOutFileIndivKin, [RP.key, comma]);

				if g_GENPARAM.DUMPALL.value then begin
					bWriteLn(gOutFileIndivKin, [
						indNumber, comma,
						str_gender[gender], comma,
						ageRel, comma,
						ageDeathInt, comma,
						status, comma,
						tickIn, comma,
						tickOut, comma,
						//inKinSet, comma,
						isEgo, comma,
						//useful, comma,
						GetEnumName(TypeInfo(PartnershipStatusesType), Ord(getPartnershipStatus(pRelative, true, ageRefEgo))),
						comma,
						cohort, comma,
						cohortDemReg, comma,
						GetEnumName(TypeInfo(KinTypes), Ord(typeOfKin)), comma,
						GetEnumName(TypeInfo(boolean), Ord(byUnion (pEgo, pRelative))), comma,
						ageRel2, comma,
						nChildren
					]);
				end else begin
					bWriteLn(gOutFileIndivKin, [
						indNumber, comma,
						str_gender[gender], comma,
						ageRel, comma,
						ageDeathInt, comma,
						status, comma,
						tickIn, comma,
						tickOut, comma,
						//inKinSet, comma,
						isEgo
						//useful
					]);
				end;
			end;
			
			i := 1;
			while (i <= nUnions) and (getPartner (pRelative, i) <> nil) do begin
				if checkLinks then begin
					inKinSet := true;
					pPartner := getPartner (pRelative, i);
					pPartner^.inKinSet := true;
					setPartner (pRelative, i, pPartner);
				end else begin
					if RP.wKey then bWrite (gOutFileIndivKin_link, [RP.key, comma]);
					bWriteLn(gOutFileIndivKin_link, [indNumber, comma, getPartner (pRelative, i)^.indNumber, comma, 'M',comma, nbFamily]);
				end;
				i := i + 1;
			end;
			if (typeOfKin in [kt_child, kt_grandChild]) and not byUnion (pEgo, pRelative) then begin
				if checkLinks then begin
					mother^.inKinSet := true;
					inKinSet := true;
				end else begin
					if RP.wKey then bWrite (gOutFileIndivKin_link, [RP.key, comma]);
					bWriteLn(gOutFileIndivKin_link, [mother^.indNumber, comma, indNumber, comma, 'D',comma, nbFamily]);
				end;
			end;
		end; {with pRelative^ do}

		writeKinDemoCare := TRUE;
	end;

	procedure delLastChar (var s: string);
	begin
		s := Copy(s, 1, length(s)-1);
	end;
	
	function writeKinEgoGenealogy (nbFamily: longint; pEgo: pRelativeType; pRelative: pRelativeType; sep: char=comma): boolean;
	var
		idSpouses: string;
		str_AgeUnion, str_AgeEndUnion, str_causeEnd: string;
		str_heir, str_inheritance, str_share, str_isHeir: string;
		ind: longint;
		idEgo: longint = 0;
		idFather: longint = 0;
		idMother: longint = 0;
		idKin: longint = 0;

	begin
		result := False;
		if RP.wKey then bWrite (gOutFileIndivKin, [RP.key, sep]);
		
		idEgo := pEgo^.indNumber;
		with pRelative^ do begin
			if not (typeOfKin in g_GENPARAM.OUTPUT_KINTYPES.value) then exit;
			if nUnions > 0 then begin
				idSpouses := '';
				str_AgeUnion := '';
				str_AgeEndUnion := '';
				str_causeEnd := '';
				for ind := 1 to nUnions do begin
					if getPartner (pRelative, ind) <> nil then
						idSpouses := idSpouses + intToStr(getPartner (pRelative, ind)^.indNumber) + ';'
					else
						idSpouses := idSpouses + '-1;';
					str_AgeUnion := str_AgeUnion + str_float (getAgeUnion (pRelative, ind)) + ';';
					str_AgeEndUnion := str_AgeEndUnion + str_float (getAgeEndUnion (pRelative, ind)) + ';';
					str_causeEnd := str_causeEnd + str_endUnion [getCauseEndUnion (pRelative, ind)] + ';';
				end;
				delLastChar(idSpouses);
				delLastChar(str_AgeUnion);
				delLastChar(str_AgeEndUnion);
				delLastChar(str_causeEnd);
			end else begin
				idSpouses := '0';
				str_AgeUnion := '-1';
				str_AgeEndUnion := '-1';
				str_causeEnd := '';
			end;
			if nHeirs > 0 then begin
				str_heir := '';
				for ind := 1 to nHeirs do
					str_heir := str_heir + intToStr(heirs[ind-1]^.indNumber) + ';';
				delLastChar(str_heir);
			end else
				str_heir := '0';
			if nInheritances > 0 then begin
				str_inheritance := '';
				str_share  := '';
				str_isHeir := '';
				for ind := 1 to nInheritances do begin
					str_inheritance := str_inheritance + intToStr(inheritances[ind-1].pDeadRelative^.indNumber) + ';';
					str_share := str_share + str_float(inheritances[ind-1].share) + ';';
					if (inheritances[ind-1].isHeir) then
						str_isHeir := str_isHeir + '1;'
					else
						str_isHeir := str_isHeir + '0;';
				end;
				delLastChar(str_inheritance);
				delLastChar(str_share);
				delLastChar(str_isHeir);
			end else begin
				str_inheritance := '0';
				str_share  := '-1';
				str_isHeir := '0';
			end;
			if father <> nil then idFather := father^.indNumber;
			if mother <> nil then idMother := mother^.indNumber;
			idKin := kinOf^.indNumber;
			bWrite (gOutFileIndivKin, 	[nbFamily, sep, indNumber, sep, idKin, sep, str_kinship [typeOfKin], sep, str_kinship [kinOf^.typeOfKin],
										sep, str_gender [gender], sep, idEgo, sep, idFather, sep, idMother, sep, nUnions, sep, idSpouses]);
										
			if fieldEnabled (fn_yBirth) then bWrite (gOutFileIndivKin, [sep, dateBirth.yearBirth]);
			if fieldEnabled (fn_mBirth) then bWrite (gOutFileIndivKin, [sep, monthFromCDC (cdcBirth)]);
			if fieldEnabled (fn_cmcBirth) then bWrite (gOutFileIndivKin, [sep, CMCFromCDC (cdcBirth)]);
			if fieldEnabled (fn_cmcDeath) then bWrite (gOutFileIndivKin, [sep, CMCFromCDC (cdcDeath)]);
			if fieldEnabled (fn_nChildren) then bWrite (gOutFileIndivKin, [sep, getNumChildren (pRelative)]);
			if fieldEnabled (fn_birthOrder) then bWrite (gOutFileIndivKin, [sep, birthOrder]);
			if fieldEnabled (fn_ageRelEgo) then bWrite (gOutFileIndivKin, [sep, ageAtBirthOfEgo]);
			if fieldEnabled (fn_ageDeath) then bWrite (gOutFileIndivKin, [sep, ageDeath]);
			if fieldEnabled (fn_ageUnion) then bWrite (gOutFileIndivKin, [sep, str_AgeUnion]);
			if fieldEnabled (fn_ageEndUnion) then bWrite (gOutFileIndivKin, [sep, str_AgeEndUnion]);
			if fieldEnabled (fn_causeEnd) then bWrite (gOutFileIndivKin, [sep, str_causeEnd]);
			if fieldEnabled (fn_ageMotherAtChildbirth) then bWrite (gOutFileIndivKin, [sep, ageMotherAtChildbirth]);
			if fieldEnabled (fn_ageFatherAtChildbirth) then bWrite (gOutFileIndivKin, [sep, ageFatherAtChildbirth]);
			if fieldEnabled (fn_status) then bWrite (gOutFileIndivKin, [sep, status]);
			if fieldEnabled (fn_cohortDemReg) then bWrite (gOutFileIndivKin, [sep, cohortDemReg]);
			if fieldEnabled (fn_motherUnionNumber) then bWrite (gOutFileIndivKin, [sep, motherUnionNumber]);
			if fieldEnabled (fn_typeHeirs) then bWrite (gOutFileIndivKin, [sep, typeHeir]);
			//if fieldEnabled (fn_egoAsHeir) then bWrite (gOutFileIndivKin, [sep, str_egoHeir [egoAsHeir]]);
			if fieldEnabled (fn_heirs) then bWrite (gOutFileIndivKin, [sep, str_heir]);
			if fieldEnabled (fn_inheritances) then bWrite (gOutFileIndivKin, [sep, str_inheritance]);
			if fieldEnabled (fn_shares) then bWrite (gOutFileIndivKin, [sep, str_share]);
			if fieldEnabled (fn_isHeir) then bWrite (gOutFileIndivKin, [sep, str_isHeir]);
		
			bWriteLn (gOutFileIndivKin, []);

			result := True;
		end;
	end;

	function writeKinGEDCOM (nbFamily: longint; pEgo: pRelativeType; pRelative: pRelativeType): boolean;
	begin
		result := False;
	end;
	
	function writeKin (ageRefEgo, nbFamily: longint; pEgo: pRelativeType; pRelative: pRelativeType; checkLinks: boolean; fileFormat: Kinship_FileFormat): boolean;
	begin
		if fileFormat = out_DemoCare then
			writeKin := writeKinDemoCare (ageRefEgo, nbFamily, pEgo, pRelative, checkLinks)
		else if fileFormat = out_EgoGenealogy then
			writeKin := writeKinEgoGenealogy (nbFamily, pEgo, pRelative)
		else if fileFormat = out_GEDCOM then
			writeKin := writeKinGEDCOM (nbFamily, pEgo, pRelative)
	end;

	function byUnionOfKinInSet (pEgo, pRelative: pRelativeType; relativesSet: KinSetType): boolean;
	begin
		if byUnion (pEgo, pRelative) then
			result := (pRelative^.kinOf^.typeOfKin in relativesSet)
		else
			result := false;
	end;

	function includeKinInNetwork (pEgo, pRelative: pRelativeType; relativesSet: KinSetType; fileFormat: Kinship_FileFormat): boolean;
	var
		inKinSet, kinByUnion, acceptNonBioKins: boolean;
	begin
		inKinSet := (pRelative^.typeOfKin in relativesSet);
		kinByUnion := byUnionOfKinInSet (pEgo, pRelative, relativesSet);
		acceptNonBioKins := g_GENPARAM.NON_BIO_KIN.value;
		if fileFormat = out_DemoCare then
			result := inKinSet or kinByUnion
		else if (fileFormat = out_EgoGenealogy) or (fileFormat = out_GEDCOM) then
			if acceptNonBioKins then
				result := inKinSet or kinByUnion
			else
				result := inKinSet and not byUnion (pEgo, pRelative);
	end;

	function writeKinship (indFamily: longint; pEgo: pRelativeType;
							relativesSet: KinSetType; fileFormat: Kinship_FileFormat): longint;
	var
		pRelative: pRelativeType;
		nbRelatives: longint = 0;
		ageRefEgo: longint;

	begin
		result := 0;
		
		if not g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value then exit;

		if fileFormat = out_DemoCare then
			ageRefEgo := 50
		else if fileFormat = out_EgoGenealogy then
			ageRefEgo := 0
		else if fileFormat = out_GEDCOM then
			ageRefEgo := 0;

		pRelative := pEgo;
		while (pRelative <> nil) do begin
			pRelative^.inKinSet := false;
			if includeKinInNetwork (pEgo, pRelative, relativesSet, fileFormat) then
			begin
				nbRelatives := nbRelatives + 1;
				pRelative^.inKinSet := true;
				writeKin (ageRefEgo, indFamily, pEgo, pRelative, false, fileFormat);
			end;
			pRelative := pRelative^.nextRelative;
		end;
		result := nbRelatives;
	end;

	procedure addAllPartners (randomGenerator: TRandomNumberGenerator;
                            pPartnerWoman: pRelativeType; unionStates: TUnionsType;
							pMan: pRelativeType; indUnionWoman: longint;
							var pLastRelative: pRelativeType; var nbTotRelatives: longint);
	{Add all the partners referenced in unionStates.
	They all will be kin of type kt_partner of this woman, except for pMan who is already created as a biological kin of ego
	and is partner indUnionWoman of this woman}
	var
		indUnion: longint;
		pPartner: pRelativeType;
	begin
		for indUnion := 1 to unionStates.nbUnions do begin
			if indUnion = indUnionWoman then begin
			{This is the partner who is a biological kin of ego, already entered into his kinship
			and who has already this woman in his list of partners, so we don't enter her two times}
				pPartner := pMan;
			end else begin
				pLastRelative := newRelative (pLastRelative, pPartnerWoman, nbTotRelatives, kt_partner);
				pPartner := pLastRelative;
				with pPartner^ do begin
					gender := man;
					copyWomanPartnershipInfoToManAsRelative (unionStates, indUnion, pPartner);
					calcDateBirth(randomGenerator, dateBirth, pPartnerWoman^.dateBirth,
						unionStates.Unions [indUnion - 1].ages[le_union, man],
						unionStates.Unions [indUnion - 1].ages[le_union, woman]);
					ageAtBirthOfEgo := calcAgeAtBirthOfEgo (findEgo (pPartner), pPartner);
					cohort := dateBirth.yearBirth;
					cohortDemReg := getCohort_p(cohort)^.yearOfBirth.value;
				end;
				addLastPartner (pPartner, pPartnerWoman);
			end;
			addLastPartner (pPartnerWoman, pPartner);
		end;
	end;

	procedure copyInfoChildToRelative (aChild: pInfoChildType; pRelative: pRelativeType; destinyInfo: boolean = false);
	begin
		if destinyInfo then begin
		// this info will be changed later is destinyInfo is set to false
			pRelative^.gender := aChild^.sex;
			pRelative^.ageDeath := aChild^.ageDeath;
			pRelative^.dateBirth.monthBirth := aChild^.dateBirth.monthBirth;
			pRelative^.dateBirth.yearBirth := aChild^.dateBirth.yearBirth;
		end;
		pRelative^.birthOrder := aChild^.birthOrder;
		pRelative^.ageMotherAtChildbirth := aChild^.ageMotherAtChildbirth;
		pRelative^.ageFatherAtChildbirth := aChild^.ageFatherAtChildbirth;
		pRelative^.motherUnionNumber := aChild^.motherUnionNumber;
	end;

	function lookingForRefChild (randomGenerator: TRandomNumberGenerator;
                            	cohortChild: longint;
                                pChildrenList: pInfoChildType;
                                pRefChild: pRelativeType): longint;
	// We look for a child born in year 'cohortChild' in the set contained in 'pChildrenList' and return it in 'pRefChild'.
	// If two or more children are born this year, we return one of them chosen in a random way.
	// The result of the function is the resultant birth order of the selected child
	var
		nChildrenBorninYear: longint = 0; // number of children born in year cohortChild
		indRefChild: longint = 1;
		n: longint;
		pChild: pInfoChildType;
		found: boolean = false;
	begin
		// First we count the number of children born from that mother in year 'cohortChild'
		pChild := pChildrenList;
		gotoToFirstLiveBornChild (pChild);
		while (pChild <> nil) do begin
			if pChild^.dateBirth.yearBirth = cohortChild then
				nChildrenBorninYear := nChildrenBorninYear + 1;
			gotoToNextLiveBornChild (pChild);
		end;
		// we choose one of the children born that year
		if nChildrenBorninYear > 1 then
			indRefChild := trunc( randomGenerator.alea(1, nChildrenBorninYear+0.9999999999) );
		// now we select one of them
		n := 0;
		pChild := pChildrenList;
		gotoToFirstLiveBornChild (pChild);
		while (pChild <> nil) do begin
			if pChild^.dateBirth.yearBirth = cohortChild then
				n := n + 1;
			if indRefChild = n then begin
				copyInfoChildToRelative (pChild, pRefChild);
				found := true;
				result := pRefChild^.birthOrder;
				{pRefChild found, so we exit the function...}
				exit;
			end;
            gotoToNextLiveBornChild (pChild);
		end;
		if not found then begin
			result := 0;
			pChild := pChildrenList;
			nChildrenBorninYear := 0;
			while (pChild <> nil) do begin
				if pChild^.dateBirth.yearBirth = cohortChild then
					nChildrenBorninYear := nChildrenBorninYear + 1;
				pChild := pChild^.next;
			end;
			writeAndWait('Not found lookingForRefChild');
		end;
	end;
					
	procedure ageFatherAtUnionChild (pRefChild: pRelativeType);
	// statistics on age at death of father and age at union of his male children

		function goodSon (pSon: pRelativeType): boolean;
		begin
			result := (pSon^.gender = man) and (getAgeUnion (pSon, 1) > 0);
		end;
	var
		pFather, pChild: pRelativeType;
		ind: longint;
		dummy: longint;
		valAgeAtBirthFirst, valAgeAtBirthLast, valAgeDeathFather, valAgeAtUnionFirstChild, valAgeAtUnionLastChild: longint;
	begin
		pFather := pRefChild^.father;
		valAgeDeathFather := trunc(pFather^.ageDeath);
		valAgeAtBirthFirst := 0;
		valAgeAtBirthLast := 0;
		valAgeAtUnionFirstChild := 0;
		valAgeAtUnionLastChild := 0;
		for ind := 1 to getNumChildren (pFather) do begin
			pChild := getChildFromRelative (pFather, ind);
			if goodSon (pChild) then begin
				if valAgeAtBirthFirst = 0 then begin
					valAgeAtBirthFirst := trunc(pFather^.ageAtBirthOfEgo - pChild^.ageAtBirthOfEgo);
					valAgeAtUnionFirstChild := trunc((getAgeUnion (pChild, 1)));
				end;
				valAgeAtBirthLast := trunc(pFather^.ageAtBirthOfEgo - pChild^.ageAtBirthOfEgo);
				valAgeAtUnionLastChild := trunc((getAgeUnion (pChild, 1)));
			end;
		end;

		if valAgeAtBirthFirst > 0 then
			begin
				InterlockedIncrement (gAgeFatherAgeSon[numberCases]);
				dummy := InterlockedExchangeAdd(gAgeFatherAgeSon[ageAtBirthFirst], valAgeAtBirthFirst);
				dummy := InterlockedExchangeAdd(gAgeFatherAgeSon[ageAtBirthLast], valAgeAtBirthLast);
				dummy := InterlockedExchangeAdd(gAgeFatherAgeSon[ageDeathFather], valAgeDeathFather);
				dummy := InterlockedExchangeAdd(gAgeFatherAgeSon[ageAtUnionFirstChild], valAgeAtUnionFirstChild);
				dummy := InterlockedExchangeAdd(gAgeFatherAgeSon[ageAtUnionLastChild], valAgeAtUnionLastChild);
			end;
	end;

{we integrate the siblings of the pRefChild who has birth order 'birthOrder' into ego's kinship}
{as this individual can be either ego or one of his two parents, we take care not to add her/him twice in}
{ego's kinship, once as an ego and once as a brother, or once as a parent and once as an uncle...}
{the key variable is 'birthOrder'. If it is equal to 0, then all the children are added and pRefChild can be nil.
If 'birthOrder' is more than 0, then the individual pRefChild is not added and should not be nil}
	procedure calcSiblings (randomGenerator: TRandomNumberGenerator;
                            kinTypeChild: KinTypes;
							birthOrder: longint;
							pChildrenList: pInfoChildType;
							pEgo, pRefChild, pMother, pFatherBioKinOfEgo: pRelativeType;
							var pLastRelative: pRelativeType; var nbTotRelatives: longint);
	var

{$IFDEF DEBUG}
first: longint = 0;
last: longint = 0;
{$ENDIF}
		ind: longint = 0;
		pFather: pRelativeType = nil;
		pLastChild: pRelativeType = nil;
		pCh: pInfoChildType;

	begin
{$IFDEF VerboseProfiler} timeProfile_start_proc('calcSiblings'); {$ENDIF}
        pCh := pChildrenList;
		gotoToFirstLiveBornChild (pCh);
		while (pCh <> nil) do begin
			pFather := getPartner (pMother, pCh^.motherUnionNumber);
			ind := ind + 1;
			if ind = birthOrder then begin
			// this one is the reference child. We don't include it again in ego's kinship
{$IFDEF DEBUG}
if first = 0 then
	first := pRefChild^.ageAtBirthOfEgo;
last := pRefChild^.ageAtBirthOfEgo;
{$ENDIF}
			end else begin
			// other siblings
				pLastRelative := newRelative(pLastRelative, pEgo, nbTotRelatives, kt_child);
				pLastChild := pLastRelative;
				pLastChild^.mother := pMother;
				pLastChild^.father := pFather;
				if ( byUnion (pEgo, pMother) or (pMother^.typeOfKin = kt_partner) ) and (pFather <> pFatherBioKinOfEgo) then begin
					pLastChild^.typeOfKin := kt_child;
					pLastChild^.kinOf := pMother;
				end;
				copyInfoChildToRelative (pCh, pLastChild);
				// we compute date of birth of child (or sibling) pLastRelative based on mother's info
				calcDateBirth(randomGenerator, pLastChild^.dateBirth, pMother^.dateBirth, 0, pLastChild^.ageMotherAtChildbirth);
				pLastChild^.cohort := pLastChild^.dateBirth.yearBirth;
				pLastChild^.ageAtBirthOfEgo := calcAgeAtBirthOfEgo(pEgo, pLastChild);
				destiny(randomGenerator, kinTypeChild, pLastChild);
{$IFDEF DEBUG}
if first = 0 then
	first := pLastChild^.ageAtBirthOfEgo;
last := pLastChild^.ageAtBirthOfEgo;
{$ENDIF}
			end;
			gotoToNextLiveBornChild (pCh);
		end;
{$IFDEF DEBUG}
		if abs(last - first) > 40 then
			begin
				stdWriteLn([ProblemSiblings, ' in calcSiblings']);
				stdWriteLn(['mother: ', pMother^.indNumber,
					' ageRelEgoFirst: ', first,
					' ageRelEgoLast: ', last]);
			end;
		if pFather = nil then
			pFather := pFather;
{$ENDIF}
		if (ind > 0) and (pRefChild <> nil) and (pRefChild^.typeOfKin = kt_ego) then
			ageFatherAtUnionChild(pRefChild);
{$IFDEF VerboseProfiler} timeProfile_end_proc('calcSiblings'); {$ENDIF}
	end;

	function updateInfoMother (randomGenerator: TRandomNumberGenerator;
                            	womanObj: TWomanMemoryBlock;
                                pRefChild: pRelativeType;
                                offsetCohort: longint;
                                var pMother: pRelativeType): longint;
	var
		cohortChildInd: longint;
	begin
		pMother^.cohortDemReg := getCohort_p (womanObj.cohort)^.yearOfBirth.value;
		copyWomanPartnershipInfoToWomanAsRelative (womanObj.unionStates, pMother);
		// we look for a child of that mother born in adjusted-year-of-birth of the reference child
		// this will give us the birth order as the result of this function
		cohortChildInd := lookInChildrenRange (pRefChild^.dateBirth.yearBirth) + offsetCohort;
		result := lookingForRefChild (	randomGenerator,
        								cohortChildInd + gFirstCohortAncestorsChildren,
										womanObj.pChildrenList, pRefChild);
		// Important: now we adjust mother's date of birth using pRefChild's one
		calcDateBirth(randomGenerator, pMother^.dateBirth, pRefChild^.dateBirth, pRefChild^.ageMotherAtChildbirth, 0);
		pMother^.cohort := pMother^.dateBirth.yearBirth;
	end;
	
	function selectOneMother (randomGenerator: TRandomNumberGenerator;
                                cohortChild: longint;
                                var womanObj: TWomanMemoryBlock): longint;
	var
		cohortChildInd, offsetCohort, maxCohorts: longint;
		indMother: longint;
	begin
		// we use the available information,
		// so we always look for births in the range gFirstCohortAncestorsChildren to gLastCohortAncestorsChildren
		// even if the child was born outside of this range
		// the index starts at 0, so we adjust here and at the same time keep track of cohorts
		// that are out of range
		cohortChildInd := lookInChildrenRange (cohortChild);
		result := 0;
		// we randomly select a mother who had a birth in year cohortChild
		offsetCohort := 0;
		if g_RangeBirthsNb[cohortChildInd] = 0 then
        begin
			// no mother with a birth in year cohortChild. We need to find one with a birth in the closest year
			// to speed up things, we look upward for lower values of cohortChild, and downward for higher one
			// This can occur only with variable fertility, not a stable population setting
			if length(g_RangeBirthsNb) > 1 then begin
				maxCohorts := trunc (length(g_RangeBirthsNb) / 10);
				if cohortChildInd < (length(g_RangeBirthsNb) / 2) then begin
					// upward
					offsetCohort := 1;
					while ((g_RangeBirthsNb [cohortChildInd + offsetCohort] = 0) and (offsetCohort <= maxCohorts)) do
						Inc (offsetCohort);
				end else begin
					// downward
					offsetCohort := -1;
					while ((g_RangeBirthsNb [cohortChildInd + offsetCohort] = 0) and (offsetCohort >= -maxCohorts)) do
						Dec (offsetCohort);
				end;
				if (g_RangeBirthsNb [cohortChildInd + offsetCohort] = 0) then begin
					// we didn't found a mother
					if gRunFromIDE then
{$IFNDEF ARM}
						asm int 3 end;
{$ELSE}
						assert(true);
{$ENDIF}
					myHalt (['Bad, bad: no births in g_RangeBirthsInfo...'])
				end;
			end else begin
				// if we have births for only one year, we are in the stable population case
				// we should have births in g_RangeBirthsInfo, so there is an error somewhere
				if gRunFromIDE then
{$IFNDEF ARM}
					asm int 3 end;
{$ELSE}
					assert(true);
{$ENDIF}
				myHalt (['Bad, bad: no births in g_RangeBirthsInfo...'])
			end;
		end;
// DEBUG
		if offsetCohort <> 0 then
			offsetCohort := offsetCohort;
// DEBUG
		indMother := trunc ( randomGenerator.alea ( 0, g_RangeBirthsNb[cohortChildInd + offsetCohort] - 0.00000000001 ) );
		// we have one!
		womanObj := getWomanFromBigArray (g_RangeBirthsInfo[cohortChildInd + offsetCohort, indMother]);
		result := offsetCohort;
	end;
	
	{we determine the direct ancestry of pRefChild, and at the same time we will have all the siblings}
	function LookingForMother (randomGenerator: TRandomNumberGenerator;
                            	pRefChild: pRelativeType;
								var pMother: pRelativeType;
								var womanObj: TWomanMemoryBlock): longint;
	// new version of the algorithm: instead of selecting the mother by an age at childbearing
	// we choose directly from a set of mothers who had a son in the birth year of the pRefChild
	// this set of mothers was constructed at start and are stored in arrays g_RangeBirthsInfo and gBig_ArrayWomen
	var
		cohortChild, offsetCohort: longint;

	begin
		// year of birth of the child whose mother we are looking for
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation then
				// this is not necessary, but we still enforce it
				cohortChild := gFirstCohortAncestorsChildren
			else
				cohortChild := pRefChild^.dateBirth.yearBirth;
		end else begin
			cohortChild := pRefChild^.dateBirth.yearBirth;
		end;
		
		offsetCohort := selectOneMother (randomGenerator, cohortChild, womanObj);
		
		// we copy the information from that mother and determine the birth order of the reference child
		result := updateInfoMother (randomGenerator, womanObj, pRefChild, offsetCohort, pMother);

	end; {LookingForMother}

	function BACKFOR_MotherAgeChildbearing (randomGenerator: TRandomNumberGenerator; pRefChild: pRelativeType): longint;
	// We use our set of mothers to select an age at childbearing (will work both for stable and non-stable population simulation)
	var
		indMother, birthOrder, cohortChild, cohortChildInd, offsetCohort: longint;
        womanObj: TWomanMemoryBlock;
	begin
		// year of birth of the child whose mother we are looking for
		cohortChild := pRefChild^.dateBirth.yearBirth;
		offsetCohort := selectOneMother (randomGenerator, cohortChild, womanObj{%H-});
		// we select a child from that mother born in year cohortChild in order to obtain the age at childbearing
		cohortChildInd := lookInChildrenRange (cohortChild);
		birthOrder := lookingForRefChild (	randomGenerator,
        									cohortChildInd + gFirstCohortAncestorsChildren,
											womanObj.pChildrenList, pRefChild);
		// age at childbearing !
		result := trunc ( pRefChild^.ageMotherAtChildbirth );
{$IFDEF DEBUG}
Inc (gAgeChildbearingBACKFOR [result]);
{$ENDIF}
	end;
	
	function BACKFOR_MotherAgeUnion (randomGenerator: TRandomNumberGenerator; cohortMother, ageChildbearing: longint): longint;
	begin
		result := trunc (
			calc_ageUnion (
							randomGenerator,
                            kMinAgeUnion_women,
							ageChildbearing,
							getCohort_p(cohortMother)^.pCurrUnionInfo^.prop_cel_women,
							kNoSinglehood
						)
			);
	end;
	
	const kMaxTries = 10000;

	function CAMSIM_NumberChildren (randomGenerator: TRandomNumberGenerator; pRefChild: pRelativeType): longint;
	var
		cohortChild, cohortChildInd, indChild: longint;
		dummy, sum: double;
	begin
		result := 0;
		cohortChild := pRefChild^.dateBirth.yearBirth;
		cohortChildInd := lookInChildrenRange (cohortChild);
		dummy := randomGenerator.alea0;
		sum := 0;
		indChild := 1;
		while (dummy > sum) do begin
			sum := sum + CAMSIM_RangeBirthsNb[indChild, cohortChildInd] / CAMSIM_RangeBirthsNb[0, cohortChildInd];
			Inc (indChild);
		end;
		if indChild > kMaxNbChildrenCalc then
		indChild := kMaxNbChildrenCalc;
		result := indChild;
	end;

	function CAMSIM_MotherAgeChildbearing (randomGenerator: TRandomNumberGenerator;
                                			pRefChild: pRelativeType;
                                            numChildrenSelected: longint): longint;
	var
		indMother, womanInd, birthOrder, cohortChild, cohortChildInd: longint;
	begin
		cohortChild := pRefChild^.dateBirth.yearBirth;
		cohortChildInd := lookInChildrenRange (cohortChild);

		{We randomly select a mother who had a birth in year cohortChild, in order to obtain an age at childbearing }
		indMother := trunc ( randomGenerator.alea ( 0, CAMSIM_RangeBirthsNb[numChildrenSelected, cohortChildInd] - 0.00000000001 ) );
		// we have one!
		womanInd := CAMSIM_RangeBirthsInfo[numChildrenSelected, cohortChildInd, indMother];
		// we select a child from that mother born in year cohortChild in order to obtain the age at childbearing
		birthOrder := lookingForRefChild (	randomGenerator,
        									cohortChildInd + gFirstCohortAncestorsChildren,
											getWomanFromBigArray (womanInd).pChildrenList, pRefChild);
		// age at childbearing !
		result := trunc ( pRefChild^.ageMotherAtChildbirth );
	end;

	function infoRefChildToMotherAndSibling (
                                randomGenerator: TRandomNumberGenerator;
								dateBirthRefChildInd: DateOfBirthType;
								cohortWoman, nbChildren: longint;
								unionStates: TUnionsType;
								pChild: pInfoChildType;
								pRefChild: pRelativeType;
								var pMother: pRelativeType;
								out birthOrder: longint
							): TWomanMemoryBlock;
	var
		womanObj: TWomanMemoryBlock;
		pCh: pInfoChildType;
		
	begin
		// Create mother object
		womanObj := TWomanMemoryBlock.Create(
        							randomGenerator,
									0, cohortWoman,
									nbChildren,
									unionStates,
									pChild,
                                    nil,
									0);
		
		// update date of birth of mother based on refChild's info
		calcDateBirth (randomGenerator, womanObj.dateBirth, dateBirthRefChildInd, pRefChild^.ageMotherAtChildbirth, 0);
		calcDateBirth (randomGenerator, pMother^.dateBirth, dateBirthRefChildInd, pRefChild^.ageMotherAtChildbirth, 0);

		// update date of birth of siblings from date of birth of mother (will recopy the info to the refChild also!)
		pCh := womanObj.pChildrenList;
		gotoToFirstLiveBornChild(pCh);
		while pCh <> nil do begin
			calcDateBirth (randomGenerator, pCh^.dateBirth, womanObj.dateBirth, 0, pCh^.ageMotherAtChildbirth);
			gotoToNextLiveBornChild(pCh);
		end;

		// we copy the information from that mother and update the birth order of the reference child
		birthOrder := updateInfoMother (randomGenerator, womanObj, pRefChild, 0, pMother);

		result := womanObj;
	end;
	
	function LookingForMother_CAMSIM_1987 (
                                randomGenerator: TRandomNumberGenerator;
								pRefChild: pRelativeType;
								var pMother: pRelativeType;
								var womanObj: TWomanMemoryBlock
								): longint;
	{First version of CAMSIM:
	We look for a mother with at least one child
	Then we randomly select one of the children as ego}
	var
		birthOrderSelected: longint;
		cohortWoman, ageUnionWoman, nbChildren, n: longint;
		unionStates: TUnionsType = nil;
		ageChildren: TabCompFertAge;
		pChild: pInfoChildType = nil;
		pCh: pInfoChildType;
		dateBirthRefChildInd: DateOfBirthType;
		birthOrder: longint;
		nTries: longint = 0;
		motherFound: boolean = false;
	begin
		result := -1; {No child found}

		dateBirthRefChildInd.monthBirth := pRefChild^.dateBirth.monthBirth;
		dateBirthRefChildInd.yearBirth := lookInChildrenRange (pRefChild^.dateBirth.yearBirth) + gFirstCohortAncestorsChildren;
		// We don't have the age at childbearing, so we assign a year of birth for the mother equal to the ego's one
		cohortWoman := dateBirthRefChildInd.yearBirth;
		ageUnionWoman := BACKFOR_MotherAgeUnion (randomGenerator, cohortWoman, kMaxAgeUnion_women);
		while (not motherFound) do begin
		repeat
			FreeAndNil (unionStates);
			Inc (nTries);
			unionStates := TUnionsType.Create(0, woman);
			nbChildren := calcCompleteFertilityWoman (
							randomGenerator,
							getCohort_p (cohortWoman),
							kNoDeathOfMother,
							kDeathOfFatherPossible,
							ageUnionWoman,
							1,
							unionStates,
							ageChildren,
							pChild,
							unionStates.fecundLife,
							nil
						);
		until (nbChildren > 0) or (nTries > 10000);
		if (nTries > 10000) then begin
			ageUnionWoman := BACKFOR_MotherAgeUnion (randomGenerator, cohortWoman, kMaxAgeUnion_women);
			nTries := 0;
		end
		else
			motherFound := true;
		end;

		// looking for the refChild in the list of children to update her/his info
		birthOrderSelected := trunc (randomGenerator.alea (1, nbChildren + 0.9999999999999));
		pCh := pChild;
		gotoToFirstLiveBornChild(pCh);
		while pCh <> nil do begin
			Dec (birthOrderSelected);
				if (birthOrderSelected = 0) then begin
					pRefChild^.ageMotherAtChildbirth := pCh^.ageMotherAtChildbirth;
					pRefChild^.ageFatherAtChildbirth := pCh^.ageFatherAtChildbirth;
					break;
				end;
			gotoToNextLiveBornChild(pCh);
		end;
		cohortWoman := dateBirthRefChildInd.yearBirth - trunc (pRefChild^.ageMotherAtChildbirth);

		womanObj := infoRefChildToMotherAndSibling (
								randomGenerator,
                                dateBirthRefChildInd,
								cohortWoman, nbChildren,
								unionStates,
								pChild,
								pRefChild,
								pMother,
								birthOrder
							);

		disposeChild (pChild);
		FreeAndNil (unionStates);
		result := birthOrder;
	end;

	function LookingForMother_CAMSIM_1993 (
                                randomGenerator: TRandomNumberGenerator;
								pRefChild: pRelativeType;
								var pMother: pRelativeType;
								var womanObj: TWomanMemoryBlock;
								anyAgeAtUnion: boolean = TRUE { random drawing of an unbounded age at unionfor the woman (TRUE) or bounded by selected age at childbearing or ego (FALSE)}
								): longint;
	{CAMSIM 1993:
		First random drawing of a number of children
		Second random drawing of an age at childbearing A for women with this number of children
		Third look for a mother with that number of children (BACKFOR)
		Fourth select a birth order, which gives us a child and the corresponding age at childbearing B
		If A <> B then go back to Third
	}
	var
		numChildrenSelected, birthOrderSelected: longint;
		ageChildbearing, ageUnionWoman, cohortWoman, nbChildren, n: longint;
		unionStates: TUnionsType = nil;
		ageChildren: TabCompFertAge;
		pChild: pInfoChildType = nil;
		pCh: pInfoChildType;
		nTries: longint = 0;
		motherFound: boolean = FALSE;
		selectedChild: longint;
		dateBirthRefChildInd: DateOfBirthType;
		birthOrder: longint;
		fertFunctionRan, endClause: boolean;
	begin
		result := -1; {No child found}

		nTries := 0;
		numChildrenSelected := CAMSIM_NumberChildren (randomGenerator, pRefChild);
		ageChildbearing := CAMSIM_MotherAgeChildbearing (randomGenerator, pRefChild, numChildrenSelected);
		dateBirthRefChildInd.monthBirth := pRefChild^.dateBirth.monthBirth;
		dateBirthRefChildInd.yearBirth := lookInChildrenRange (pRefChild^.dateBirth.yearBirth) + gFirstCohortAncestorsChildren;
		cohortWoman := dateBirthRefChildInd.yearBirth - ageChildbearing;
		while not motherFound do begin
		fertFunctionRan := false;
		endClause := false;
		if (ageChildbearing < 13) or (ageChildbearing > 54) then begin
			// Hack to reshuffle things in case the value of ageChildbearing goes awry
			numChildrenSelected := CAMSIM_NumberChildren (randomGenerator, pRefChild);
			ageChildbearing := CAMSIM_MotherAgeChildbearing (randomGenerator, pRefChild, numChildrenSelected);
		end;
		if (anyAgeAtUnion) then
			ageUnionWoman := BACKFOR_MotherAgeUnion (randomGenerator, cohortWoman, kMaxAgeUnion_women)
		else
			ageUnionWoman := BACKFOR_MotherAgeUnion (randomGenerator, cohortWoman, ageChildbearing);

		// Sanity check: if the age at union of the woman is higher than the age at childbearing of ego, we try another woman...
		if ageUnionWoman > ageChildbearing then
			continue;

			repeat
				FreeAndNil (unionStates);
				Inc (nTries);
				fertFunctionRan := true;
				endClause := false;
				unionStates := TUnionsType.Create(0, woman);
				nbChildren := calcCompleteFertilityWoman (
								randomGenerator,
								getCohort_p (cohortWoman),
								kNoDeathOfMother,
								kDeathOfFatherPossible,
								ageUnionWoman,
								1,
								unionStates,
								ageChildren,
								pChild,
								unionStates.fecundLife,
								nil
							);
				if (nbChildren = 0) or (nbChildren > kMaxNbChildrenCalc) then begin
				fertFunctionRan := false;
				continue;
				end;
				birthOrderSelected := trunc (randomGenerator.alea (1, nbChildren + 0.9999999999999));
				//writeDebug ([IntToStr (ageChildbearing) + ' ' + IntToStr (birthOrderSelected)]);
				endClause := ( ageChildren [ageChildbearing, birthOrderSelected] > 0 );
			until (fertFunctionRan and endClause) or (nTries > kMaxTries);
			gBACKFOR_nTries := gBACKFOR_nTries + nTries;
			if nTries > kMaxTries then begin
				writeAndWait ('No women found at: ' + IntToStr (gBACKFOR_women + 1) + ' ageChildbearing: ' + FloatToStr (ageChildbearing) + ', ageUnion: ' + FloatToStr (ageUnionWoman));
				if ageChildbearing > 30 then begin
					Dec (ageChildbearing);
				end
				else begin
					Inc (ageChildbearing);
				end;
			end else
				motherFound := TRUE;
			nTries := 0;
		end;
		Inc (gBACKFOR_women);
		// update age at childbearing of mother for refChild
		pCh := pChild;
		gotoToFirstLiveBornChild(pCh);
		while pCh <> nil do begin
			Dec (birthOrderSelected);
				if (birthOrderSelected = 0) then begin
					pRefChild^.ageMotherAtChildbirth := pCh^.ageMotherAtChildbirth;
					pRefChild^.ageFatherAtChildbirth := pCh^.ageFatherAtChildbirth;
					break;
				end;
			gotoToNextLiveBornChild(pCh);
		end;
		
		womanObj := infoRefChildToMotherAndSibling (
								randomGenerator,
                                dateBirthRefChildInd,
								cohortWoman, nbChildren,
								unionStates,
								pChild,
								pRefChild,
								pMother,
								birthOrder
							);

		disposeChild (pChild);
		FreeAndNil (unionStates);
		result := birthOrder;
	end;
	
	function LookingForMother_RealBACKFOR (
                                randomGenerator: TRandomNumberGenerator;
								pRefChild: pRelativeType;
								var pMother: pRelativeType;
								var womanObj: TWomanMemoryBlock
								): longint;
	{Original version of Le Bras' BACKFOR: we select an age at childbearing by random drawing on the probability distribution of births by age of mothers,
	then we select an age at first union for the mother (inferior to the age at childbearing)
	and then an age at union of a men (that possibly will not be the father if there is a separation or widowhood followed by a second union).
	We simulate the life of women of these characteristics until we have one with a birth at the needed age at childbearing (this is the BACKFOR algorithm).
	Observe that age at childbearing and age at first union of the women do not change for each simulation, but the age at union of the man
	changes each time we apply the fertility model, as stated in Le Bras' description}
	var
		ageChildbearing, ageUnionWoman, cohortWoman, nbChildren, n: longint;
		unionStates: TUnionsType = nil;
		ageChildren: TabCompFertAge;
		pChild: pInfoChildType = nil;
		pCh: pInfoChildType;
		nTries: longint = 0;
		motherFound: boolean = FALSE;
		selectedChild: longint;
		dateBirthRefChildInd: DateOfBirthType;
		birthOrder: longint;
		
	begin
		result := -1; {No child found}
		dateBirthRefChildInd.monthBirth := pRefChild^.dateBirth.monthBirth;
		dateBirthRefChildInd.yearBirth := lookInChildrenRange (pRefChild^.dateBirth.yearBirth) + gFirstCohortAncestorsChildren;
		{1. Select an age at childbearing}
		ageChildbearing := BACKFOR_MotherAgeChildbearing (randomGenerator, pRefChild);
		repeat
			{2. Next, randomly select an age at union for the woman, lower or equal age at childbearing}
			cohortWoman := dateBirthRefChildInd.yearBirth - ageChildbearing;
			ageUnionWoman := BACKFOR_MotherAgeUnion (randomGenerator, cohortWoman, ageChildbearing);
			pMother^.cohort := cohortWoman;
		
			{3. We now simulate the reproductive life of a woman with these two characteristics until we have one with a birth at age ageChildbearing}
			repeat
				FreeAndNil (unionStates);
				Inc (nTries);
				unionStates := TUnionsType.Create (0, woman);
				nbChildren := calcCompleteFertilityWoman (
								randomGenerator,
								getCohort_p (cohortWoman),
								kNoDeathOfMother,
								kDeathOfFatherPossible,
								ageUnionWoman,
								1,
								unionStates,
								ageChildren,
								pChild,
								unionStates.fecundLife,
								nil
							);
			until (ageChildren [ageChildbearing, 0] > 0) or (nTries > kMaxTries);
			gBACKFOR_nTries := gBACKFOR_nTries + nTries;
			if nTries > kMaxTries then begin
				nTries := 0;
				writeAndWait ('No women found at: ' + IntToStr (gBACKFOR_women + 1) + ' ageChildbearing: ' + FloatToStr (ageChildbearing) + ', ageUnion: ' + FloatToStr (ageUnionWoman));
				if ageChildbearing > 30 then
					Dec (ageChildbearing)
				else
					Inc (ageChildbearing);
			end else
				motherFound := TRUE;
		until motherFound;
{$IFDEF DEBUG}
Inc (gAgeChildbearingBACKFOR_post [ageChildbearing]);
{$ENDIF}
		
		Inc (gBACKFOR_women);

		// looking for the refChild in the list of children to update her/his info
		selectedChild := trunc ( randomGenerator.alea (0, ageChildren [ageChildbearing, 0] - 0.00000000001) );
		pCh := pChild;
		gotoToFirstLiveBornChild(pCh);
		while pCh <> nil do begin
			if (trunc (pCh^.ageMotherAtChildbirth) = ageChildbearing) then begin
				if (selectedChild = 0) then begin
					pRefChild^.ageMotherAtChildbirth := pCh^.ageMotherAtChildbirth;
					pRefChild^.ageFatherAtChildbirth := pCh^.ageFatherAtChildbirth;
					break;
				end;
				Dec (selectedChild);
			end;
			gotoToNextLiveBornChild(pCh);
		end;
		
		womanObj := infoRefChildToMotherAndSibling (
								randomGenerator,
                                dateBirthRefChildInd,
								cohortWoman, nbChildren,
								unionStates,
								pChild,
								pRefChild,
								pMother,
								birthOrder
							);

		disposeChild (pChild);
		FreeAndNil (unionStates);
		result := birthOrder;
	end;
	
	function LookingForMotherBACKFOR (
                                randomGenerator: TRandomNumberGenerator;
								var pRefChild: pRelativeType;
								var pMother: pRelativeType;
								out womanObj: TWomanMemoryBlock): longint; {We return the birth order of pRefChild}
	{Adaptation of Le Bras' version of the algorithm:
	we choose from a set of mothers who had a son in the birth year of the pRefChild
	(which is similar to randomly selecting an age at childbearing)
	but we also randomly select an age at union for the mother instead of having it as a result as is the case in our version of the algorithm
	The difference from the algorithm we prefer is that age at union of mother
	will be 'correct' in a sense (closer to overall population values) but incorrect for ego,
	who have a higher probability of having a mother with higher fertility, so with an age at union younger than average.
	Note that in Le Bras' original algorithm, other parameters are age of union of father as well as having for him an age of death higher than age at fatherhood,
	but they are integrated here, as if the potential father dies too young, then we would not have a birth to begin with}
	var
		indMother, numMother, birthOrder: longint;
		cohortChild, cohortChildInd: longint;
		ageChildbearing: longint;
		ageUnionWoman, ageUnionWomanTemp, ageUnionWomanInd: longint;
		grow: boolean;

	begin
		{1. Select an age at childbearing}
		ageChildbearing := BACKFOR_MotherAgeChildbearing (randomGenerator, pRefChild);
		
		{2. Next, randomly select an age at union for woman, lower or equal the previous age at childbearing}
		ageUnionWoman := BACKFOR_MotherAgeUnion (randomGenerator, pRefChild^.dateBirth.yearBirth - ageChildbearing, ageChildbearing);
		ageUnionWomanInd := ageUnionWoman - kMinAgeUnion_women;
		
		{3. No we look for a suitable mother, based on the previous age at union, in the set of mother who had a child
		at age ageChildbearing the year cohortChild}
		cohortChild := pRefChild^.dateBirth.yearBirth;
		cohortChildInd := lookInChildrenRange (cohortChild);
		
		numMother := RangeBirthsBACKFORNb[cohortChildInd, ageUnionWomanInd];
		if numMother = 0 then begin
			grow := (ageUnionWoman < 20);
			ageUnionWomanTemp := ageUnionWoman;
			while (numMother = 0) and (ageUnionWomanTemp > kMinAgeUnion_women) and (ageUnionWomanTemp <  ageChildbearing) do begin
				if grow then
					Inc (ageUnionWomanTemp)
				else
					Dec (ageUnionWomanTemp);
				numMother := RangeBirthsBACKFORNb[cohortChildInd, ageUnionWomanTemp - kMinAgeUnion_women];
			end;
			if (numMother = 0) then begin
				grow := not grow;
				while (numMother = 0) and (ageUnionWomanTemp > kMinAgeUnion_women) and (ageUnionWomanTemp <  ageChildbearing) do begin
					if grow then
						Inc (ageUnionWomanTemp)
					else
						Dec (ageUnionWomanTemp);
					numMother := RangeBirthsBACKFORNb[cohortChildInd, ageUnionWomanTemp - kMinAgeUnion_women];
				end;
			end;
			ageUnionWomanInd := ageUnionWomanTemp - kMinAgeUnion_women;
		end;
		if (numMother = 0) then begin
			// Not found. We will use mother already found in previous step
			writeAndWait ('Mother not found in BACKFOR: ' + IntToStr (cohortChild) + ' ' + IntToStr (ageUnionWoman));
		end else begin
			indMother := trunc ( randomGenerator.alea ( 0, RangeBirthsBACKFORNb[cohortChildInd, ageUnionWomanInd] - 0.00000000001 ) );
			// we have one!
			womanObj := getWomanFromBigArray (RangeBirthsBACKFORInfo[cohortChildInd, ageUnionWomanInd, indMother]);
			// we select a child from that mother born in year cohortChild in order to obtain the correct age at childbearing
			birthOrder := lookingForRefChild (	randomGenerator, cohortChildInd + gFirstCohortAncestorsChildren,
									womanObj.pChildrenList, pRefChild);
		end;

		// we copy the information from that mother and determine the birth order of the reference child
		result := updateInfoMother (randomGenerator, womanObj, pRefChild, 0, pMother);

	end; {LookingForMotherBACKFOR}

	function tailOfRelativeList (pRelative: pRelativeType): pRelativeType;
	// last relative of the linked list
	begin
		while (pRelative^.nextRelative <> nil) do begin
			pRelative := pRelative^.nextRelative;
		end;
		result := pRelative;
	end;

{offspring of a female in lineage 'kinType' and whose children will have the degree 'kinTypeChild'}
{we also introduce by union the husband into ego's kinship}
	function calcStateWoman (randomGenerator: TRandomNumberGenerator;
                            kinType, kinTypeChild: KinTypes;
							pEgo: pRelativeType;
							arrayChildren: arrayOfInfoChild;
							var pLastRelative: pRelativeType; var nbTotRelatives: longint): boolean;
		var
			pWoman, pPartnerMan: pRelativeType;
			cohortMen: longint;
			pDemReg: pStructDemographicRegimeSettings;
			ageWoman, indUnion: longint;
			unionStates: TUnionsType = nil;
			ageChildren: TabCompFertAge;
			pChildrenList: pInfoChildType = nil;
			nbChildren: longint;

	begin
{$IFDEF VerboseProfiler} timeProfile_start_proc('calcStateWoman'); {$ENDIF}
		calcStateWoman := FALSE;
		pWoman := LookingForRelative(pEgo, kinType, woman);

		if (pWoman <> nil) then begin
			pDemReg := getCohort_p(pWoman^.cohort);
			if (pWoman^.nUnions > 0) then
			// that women entered at least one union so we reconstruct her partnership and fertile life cycle 
			begin
				unionStates := TUnionsType.Create(pWoman^.indNumber, woman);
				unionStates.Unions [0].ages[le_union, woman] := getAgeUnion (pWoman, 1);
				unionStates.Unions [0].ages[le_death, woman] := pWoman^.ageDeath;
				if (unionStates.Unions [0].ages[le_union, woman] < kMaxAgeSingle_women) and (unionStates.Unions [0].ages[le_death, woman] >= unionStates.Unions [0].ages[le_union, woman]) then
				begin
					// characteristics of male partners will be determined when reconstructing this woman life
					unionStates.Unions [0].ages[le_union, man] := kNotDefined;
					unionStates.Unions [0].ages[le_death, man] := kNotDefined;
					
					nbChildren := calcCompleteFertilityWoman(
													randomGenerator,
													pDemReg,
													kDeathOfMotherPossible,
													kDeathOfFatherPossible,
													getAgeUnion (pWoman, 1),
													1,
													unionStates,
													ageChildren,
													pChildrenList,
													unionStates.fecundLife,
													nil,
                                                    arrayChildren);

					copyWomanPartnershipInfoToWomanAsRelative (unionStates, pWoman);

					{we bring this woman's partners into the kinship}
					for indUnion := 1 to unionStates.nbUnions do begin
						pLastRelative := newRelative(pLastRelative, pWoman, nbTotRelatives, kt_partner);
						pPartnerMan := pLastRelative;
						// we compute date of birth of pLastRelative (who is a man) based on info of the woman and their respective age at union
						calcDateBirth (randomGenerator, pPartnerMan^.dateBirth, pWoman^.dateBirth,
									unionStates.Unions [indUnion - 1].ages[le_union, man],
									unionStates.Unions [indUnion - 1].ages[le_union, woman]);

						cohortMen := pPartnerMan^.dateBirth.yearBirth;
						pDemReg := getCohort_p (cohortMen);
						with pPartnerMan^ do
						begin
							gender := man;
							ageAtBirthOfEgo := calcAgeAtBirthOfEgo (pEgo, pPartnerMan);
							cohort := cohortMen;
							cohortDemReg := pDemReg^.yearOfBirth.value;
							// note that we don't have the full partnership history of these male partners,
							// only the part of their life they spent with this woman
							copyWomanPartnershipInfoToManAsRelative (unionStates, indUnion, pPartnerMan);
						end;
						addLastPartner (pWoman, pPartnerMan);
						addLastPartner (pPartnerMan, pWoman);
					end;
					unionStates.checkMe (pWoman);
					{and now the children of these couples}
					{as we introduce them all into ego's kinship, we set the birth order to 0}
					{observe that we will need to identify the biological father for each one of the children}
					calcSiblings(randomGenerator, kinTypeChild, 0, pChildrenList, pEgo, nil, pWoman, nil, pLastRelative, nbTotRelatives);
				end;
			end;
			disposeChild ( pChildrenList );
			FreeAndNil (unionStates);
			calcStateWoman := TRUE;
		end; // if (pWoman <> nil)
{$IFDEF VerboseProfiler} timeProfile_end_proc('calcStateWoman'); {$ENDIF}
	end; {calcStateWoman}

	function AnotherUnionPossible (unionAgeDur: UnionAgeDurationsType): boolean;
	var
		durationUnionWoman, durationUnionMan, ageEndUnion: double;

	begin
		result := false;
		if unionAgeDur.ages[le_endUnion, man] > 0 then begin
			ageEndUnion := unionAgeDur.ages[le_endUnion, man];
			result := TRUE;
		end
		else begin
			durationUnionWoman := unionAgeDur.ages[le_death, woman] - unionAgeDur.ages[le_union, woman];
			durationUnionMan := unionAgeDur.ages[le_death, man] - unionAgeDur.ages[le_union, man];
			ageEndUnion := unionAgeDur.ages[le_union, man] + durationUnionWoman;
			result := durationUnionMan > durationUnionWoman; // whether the woman died before
		end;
	end;
	
	function getNumUnionMan (bride: TWomanMemoryBlock; ageUnionWomanSelected: double): longint;
	// get the woman's partner order from an age at union
	var
		indUnion: longint;
	begin
		result := 0;
		for indUnion := 1 to bride.unionStates.nbUnions do begin
			if ageUnionWomanSelected = bride.unionStates.Unions [indUnion - 1].ages[le_union, woman] then begin
				result := indUnion;
				exit;
			end;
		end;
		writeAndWait('Not found partnership number for age at union: ' + FloatToStr(ageUnionWomanSelected));
	end;
	
	procedure calcAgeChildrenTable (pChildrenList: pInfoChildType; out ageChildren: TabCompFertAge);
	var
		age: FecundAges;
		indChild: DistribChildrenCalc;
		pChild: pInfoChildType;
		order: longint;

	begin
		for age := kMinAgeFert to kMaxAgeFert do
			for indChild := 0 to kMaxNbChildrenCalc do
				ageChildren[age, indChild] := 0;

		pChild := pChildrenList;
		gotoToFirstLiveBornChild (pChild);
		while pChild <> nil do begin
			age := trunc (pChild^.ageMotherAtChildbirth);
			order := min (kMaxNbChildrenCalc, pChild^.birthOrder);
			ageChildren[age, order] := ageChildren[age, order] + 1;
			gotoToNextLiveBornChild (pChild);
		end;
	end;

	procedure writeRelConsole (pRelative: pRelativeType);
	var
		egoId: longint = 0;
	begin
		if pRelative = nil then begin
			stdWriteLn(['Relative is NIL']);
			exit;
		end;
		if pRelative^.kinOf^.typeOfKin = kt_ego then
			egoId := pRelative^.kinOf^.indNumber;
		stdWriteln(['Problem with relative number ', pRelative^.indNumber, ' of sex ', str_gender[pRelative^.gender]]);
		if egoId = 0 then
			stdWriteLn([', relative of a partner'])
		else
			stdWriteLn([', ego number ', egoId]);
	end;
	
	procedure addGroomForComputing2WaysTableOfUnion (pGroom: pRelativeType);
	var
		pBride: pRelativeType;
		ageUnionMan, ageUnionWoman, cohortMan, cohortManInd: longint;
		indUnionWoman: longint;
		state: array of double;
	begin {addGroomForComputing2WaysTableOfUnion}
		if (pGroom^.nUnions = 0) then exit;
		pBride := getPartner (pGroom, 1);
		ageUnionMan := trunc (getAgeUnion (pGroom, 1));
		for indUnionWoman := 1 to pBride^.nUnions do begin
			if getPartner (pBride, indUnionWoman) = pGroom then break;
		end;
		if getPartner (pBride, indUnionWoman) <> pGroom then begin
			writeAndWait ('Groom and bride mismatch');
			writeRelConsole (pGroom);
			writeRelConsole (pBride);
			exit;
		end;
		ageUnionWoman := trunc (getAgeUnion (pBride, indUnionWoman));
		cohortMan := pGroom^.cohort;
{$IFDEF DEBUG}
if (ageUnionMan-kMinAgeUnion_men < kNotDefined) or (ageUnionMan-kMinAgeUnion_men >= length(gMen_Women[0])) then begin
	writeAndWait ('Bad value for ageUnionMan in gMen_Women: ' + IntToStr (ageUnionMan));
	writeRelConsole (pGroom);
	exit;
end;
if (ageUnionWoman-kMinAgeUnion_women < kNotDefined) or (ageUnionWoman-kMinAgeUnion_women >= length(gMen_Women[0, 0])) then begin
	writeAndWait ('Bad value for ageUnionWoman in gMen_Women: ' + IntToStr (ageUnionWoman));
	writeRelConsole (pBride);
	exit;
end;
{$ENDIF}
		ageUnionMan := max(kMinAgeUnion_men, ageUnionMan);
		ageUnionWoman := max(kMinAgeUnion_women, ageUnionWoman);
		cohortManInd := lookInGroomsRange (cohortMan);

		InterlockedIncrement (gMen_Women[cohortManInd, ageUnionMan-kMinAgeUnion_men, ageUnionWoman-kMinAgeUnion_women]);
	end; {addGroomForComputing2WaysTableOfUnion}

	procedure computeMenWomen2WaysTable;
	var
		pDemReg: pStructDemographicRegimeSettings;
		ageUnionMan, ageUnionWoman, cohortMan: longint;
		tot: double;
	begin
		for cohortMan := gFirstCohortGrooms to gLastCohortGrooms do begin
			pDemReg := getCohort_p (cohortMan);
			if pDemReg^.nuptialityInfo.nupt_men_women_init then begin
				for ageUnionWoman := kMinAgeUnion to kMaxAgeUnion do begin
					for ageUnionMan := kMinAgeUnion to kMaxAgeUnion do begin
						pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] := 0;
						pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, aggregated, ageUnionWoman] := 0;
					end;
				end;
				pDemReg^.nuptialityInfo.nupt_men_women_init := false;
			end;
			for ageUnionWoman := kMinAgeUnion_women to kMaxAgeUnion_women do begin
				for ageUnionMan := kMinAgeUnion_men to kMaxAgeUnion_men do begin
					pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] := 
						pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] +
						gMen_Women[cohortMan-gFirstCohortGrooms, ageUnionMan-kMinAgeUnion_men, ageUnionWoman-kMinAgeUnion_women];
				end;
			end;
		end;
		for cohortMan := gFirstCohortGrooms to gLastCohortGrooms do begin
			pDemReg := getCohort_p (cohortMan);
			if not pDemReg^.nuptialityInfo.nupt_men_women_init then begin
				for ageUnionMan := kMinAgeUnion_men to kMaxAgeUnion_men do begin
					tot := 0;
					for ageUnionWoman := kMinAgeUnion_women to kMaxAgeUnion_women do begin
						tot := tot + pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman];
					end;
					for ageUnionWoman := kMinAgeUnion_women to kMaxAgeUnion_women do begin
						if (tot > 0) then begin
							pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] :=
								pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] / tot;
						end else begin
							pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] := 0;
						end;
					end;
					pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, aggregated, kMinAgeUnion_women] :=
						pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, kMinAgeUnion_women];
					for ageUnionWoman := kMinAgeUnion_women + 1 to kMaxAgeUnion_women do begin
						pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, aggregated, ageUnionWoman] :=
							pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, normal, ageUnionWoman] +
							pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, aggregated, ageUnionWoman - 1];
					end;
					for ageUnionWoman := kMaxAgeUnion_women to kMaxAgeUnion do
						pDemReg^.nuptialityInfo.union_men_women[ageUnionMan, aggregated, ageUnionWoman] := 1.0;
				end;
				pDemReg^.nuptialityInfo.nupt_men_women_init := true;
			end;
		end;
	end;
	
// Incorrect way of doing it: we use a two-way table of men age at union BY women age at union
// that is totally independent from the reverse one for women
	procedure selectBrideByHerAgeAtUnion (	randomGenerator: TRandomNumberGenerator;
                            				pMan: pRelativeType;
											var manUnionInfo: UnionAgeDurationsType;
											var pLastRelative: pRelativeType;
											out ageUnionWomanSelected: double;
											out womanInd: longint;
											var nbTotRelatives: longint);
	var
		dummy: double;
		pDemReg: pStructDemographicRegimeSettings;

	begin
		pDemReg := getCohort_p (pMan^.cohort);
	{Age at union of the woman}
		dummy := randomGenerator.alea0;
		manUnionInfo.ages[le_union, woman] := kMinAgeUnion;
		while dummy > pDemReg^.pCurrUnionInfo^.union_men_women[
											trunc (manUnionInfo.ages[le_union, man]),
											aggregated,
											trunc (manUnionInfo.ages[le_union, woman])]
		do
			manUnionInfo.ages[le_union, woman] := manUnionInfo.ages[le_union, woman] + 1;
		manUnionInfo.ages[le_union, woman] := max (kMinAgeUnion, manUnionInfo.ages[le_union, woman] + randomGenerator.alea(0.0, 0.99999999) - 0.5);
	{we're introducing this woman into pEgo's kinship}				
		pLastRelative := newRelative(pLastRelative, pMan, nbTotRelatives, kt_partner);
		// we compute her date of birth based on info of the man and their respective ages at union
		calcDateBirth (randomGenerator, pLastRelative^.dateBirth, pMan^.dateBirth,
					manUnionInfo.ages[le_union, woman],
					manUnionInfo.ages[le_union, man]);
		pLastRelative^.cohort := pLastRelative^.dateBirth.yearBirth;
		{Looking in a random way for a woman who fits the 2 criteria: woman's birth cohort and union at the correct age}
		// the age at union for the woman can be slightly different than the one we looked for,
		// especially if the value is very low or very high (hopefully it will not choke with a previous partnership)
		womanInd := lookingForABrideByAgeAndCohort (randomGenerator, pLastRelative^.cohort, trunc(manUnionInfo.ages[le_union, woman]), ageUnionWomanSelected);
	end;

	// better way of doing it: everything is based 'in fine' on the two-way table of age at union of women BY age at union of men
	// as we use the man age at union to select a bride from a table of unions which took place a year equal to
	// man date of birth plus age at union
	procedure selectBrideByManAgeAtUnion (	randomGenerator: TRandomNumberGenerator;
                                            pMan: pRelativeType;
											var manUnionInfo: UnionAgeDurationsType;
											var pLastRelative: pRelativeType;
											var ageUnionWomanSelected: double;
											var womanInd: longint;
											var nbTotRelatives: longint);
	var
		yearUnion, yearUnionInd, yearUnionTemp: longint;
		ageUnion, ageUnionInd: longint;
		nUnions, indUnion: longint;
		grow: boolean;
	begin
		yearUnion := yearFromDatePlusAge (pMan^.dateBirth, manUnionInfo.ages[le_union, man]);
		yearUnionInd := lookInYearsUnionRange (yearUnion);
		ageUnion := trunc (manUnionInfo.ages[le_union, man]);
		ageUnionInd := ageUnion - kMinAgeUnion_men;
		nUnions := g_RangeYearUnionsNb[yearUnionInd, ageUnionInd];

		grow := ( yearUnionInd < (length (g_RangeYearUnionsNb) / 2) ) and ( ageUnion < 40 );
		yearUnionTemp := yearUnionInd;
		if nUnions = 0 then
		Inc (g_RangeYearUnionsNotFound [yearUnionInd, ageUnionInd]);

		while (nUnions = 0) and (yearUnionTemp > 0) and (yearUnionTemp < length (g_RangeYearUnionsNb)) do begin
			if grow then
				Inc (yearUnionTemp)
			else
				Dec (yearUnionTemp);
			nUnions := g_RangeYearUnionsNb[yearUnionTemp, ageUnionInd];
		end;
		if nUnions = 0 then begin
			grow := not grow;
			yearUnionTemp := yearUnionInd;
			while (nUnions = 0) and (yearUnionTemp > 0) and (yearUnionTemp < length (g_RangeYearUnionsNb)) do begin
				if grow then
					Inc (yearUnionTemp)
				else
					Dec (yearUnionTemp);
				nUnions := g_RangeYearUnionsNb[yearUnionTemp, ageUnionInd];
			end;
			if nUnions = 0 then
			writeAndWait ('Union not found in selectBrideByManAgeAtUnion!!');
		end else begin
			yearUnionInd := yearUnionTemp;
		end;

		indUnion := trunc ( randomGenerator.alea ( 0, nUnions - 0.00000000001 ) );
		womanInd := g_RangeYearUnionsInfo[yearUnionInd, ageUnionInd, indUnion];
		
		ageUnionWomanSelected := getAgeUnionSelected (randomGenerator, womanInd, kNotDefined, ageUnion, gThisIsNotanArrayOfBrides);
		manUnionInfo.ages[le_union, woman] := ageUnionWomanSelected;

	{we're introducing this woman into pEgo's kinship}				
		pLastRelative := newRelative(pLastRelative, pMan, nbTotRelatives, kt_partner);
		// we compute her date of birth based on info of the man and their respective ages at union
		calcDateBirth (randomGenerator, pLastRelative^.dateBirth, pMan^.dateBirth,
					manUnionInfo.ages[le_union, woman],
					manUnionInfo.ages[le_union, man]);
		pLastRelative^.cohort := pLastRelative^.dateBirth.yearBirth;

	end;

	{Best way of doing it: we use a table of brides classified by birth cohort of grooms and their age at union
	This way we can find an adequate bride for each groom, based on these two factors}
	procedure selectBrideByManCohortAndAgeAtUnion (
                                            randomGenerator: TRandomNumberGenerator;
											pMan: pRelativeType;
											var manUnionInfo: UnionAgeDurationsType;
											var pLastRelative: pRelativeType;
											var ageUnionWomanSelected: double;
											var womanInd: longint;
											var nbTotRelatives: longint);
	var
		cohortGroom, cohortGroomInd: longint;
		ageUnion, ageUnionInd, ageUnionIndTemp: longint;
		nUnions, indUnion: longint;
		grow: boolean;
	begin
		// groom's info: birth cohort and age at union
		if g_GENPARAM.NEW_INIT_MOTHERHOOD.value then begin
			if StablePopulation() then
				cohortGroom := gFirstCohortAncestorsChildren
			else
				cohortGroom := pMan^.cohort;
		end else begin
			cohortGroom := pMan^.cohort;
		end;

		cohortGroomInd := lookInGroomsRange (cohortGroom);
		ageUnion := trunc (manUnionInfo.ages[le_union, man]);

		// We check whether there are brides with corresponding age at union for the men
		ageUnionInd := ageUnion - kMinAgeUnion_men;
		nUnions := g_RangeGroomsNb[cohortGroomInd, ageUnionInd];

		grow := ( ageUnion < 30 );
		ageUnionIndTemp := ageUnionInd;
		if nUnions = 0 then
			// No bride for this age at union of the groom. We keep track of that
			Inc (g_RangeGroomsNotFound [cohortGroomInd, ageUnionInd]);

		while (nUnions = 0) and (ageUnionIndTemp < (kMaxAgeUnion_men - kMinAgeUnion_men)) do begin
			// if there is no bride, we change the men's age at union up or down, depending on its level
			if grow then
				Inc (ageUnionIndTemp)
			else
				Dec (ageUnionIndTemp);
			nUnions := g_RangeGroomsNb[cohortGroomInd, ageUnionIndTemp];
		end;
		if nUnions = 0 then begin
			// panic! No bride
			writeAndWait ('Union not found in selectBrideByManCohortAndAgeAtUnion!!');
		end else begin
			// We found brides at age 'ageUnionIndTemp'
			ageUnionInd := ageUnionIndTemp;
		end;

		indUnion := trunc ( randomGenerator.alea ( 0, nUnions - 0.00000000001 ) );
		womanInd := g_RangeGroomsInfo[cohortGroomInd, ageUnionInd, indUnion];
		
		ageUnionWomanSelected := getAgeUnionSelected (randomGenerator, womanInd, kNotDefined, ageUnionInd + kMinAgeUnion_men, gThisIsNotanArrayOfBrides);
		manUnionInfo.ages[le_union, woman] := ageUnionWomanSelected;

		{we're introducing this woman into pEgo's kinship}				
		pLastRelative := newRelative(pLastRelative, pMan, nbTotRelatives, kt_partner);
		// we compute her date of birth based on info of the man and their respective ages at union
		calcDateBirth (randomGenerator, pLastRelative^.dateBirth, pMan^.dateBirth,
					manUnionInfo.ages[le_union, woman],
					manUnionInfo.ages[le_union, man]);
		pLastRelative^.cohort := pLastRelative^.dateBirth.yearBirth;

	end;
	
{idem than calcStateWoman, but for a male relative of ego}
	function calcStateMan (	randomGenerator: TRandomNumberGenerator;
                            kinType, kinTypeChild: KinTypes;
							pEgo: pRelativeType;
							arrayChildren: arrayOfInfoChild;
							var pLastRelative: pRelativeType;
							var nbTotRelatives: longint): boolean;
		var
			unionStatesMan: TUnionsType;
			ageChildren: TabCompFertAge;
			nbChildren: longint;
			pMan, pPartnerWoman: pRelativeType;
			cohortMan, cohortWoman: longint;
			ageUnionWomanSelected: double;
			pDemReg: pStructDemographicRegimeSettings;
			ageWoman: longint;
			moreUnion: boolean = false;
			indUnionMan, indUnionWoman: longint;
			womanInd: longint;
			aNewBrideInfo: TWomanMemoryBlock;
			caseSelect: longint;
			ageNextUnion: double;
	begin
{$IFDEF VerboseProfiler} timeProfile_start_proc('calcStateMan'); {$ENDIF}
		calcStateMan := FALSE;
		pMan := LookingForRelative(pEgo, kinType, man);

		if (pMan <> nil) then begin
    		unionStatesMan := TUnionsType.Create(pMan^.indNumber, man);
			pDemReg := getCohort_p (pMan^.cohort);
			if (pMan^.nUnions > 0) then begin
				indUnionMan := 0;
				ageNextUnion := getAgeUnion (pMan, indUnionMan+1);
				// this man entered at least one union, so we reconstruct his partnership and fertile life cycles
				repeat
					indUnionMan := indUnionMan + 1;
					unionStatesMan.newUnion;
					cohortMan := pMan^.cohort;
					unionStatesMan.Unions [indUnionMan - 1].ages[le_union, man] := ageNextUnion;
					unionStatesMan.Unions [indUnionMan - 1].ages[le_death, man] := pMan^.ageDeath;
					setAgeUnion (pMan, indUnionMan, ageNextUnion);
					if 	(unionStatesMan.Unions [indUnionMan - 1].ages[le_union, man] < kMaxAgeSingle_men) and
							(unionStatesMan.Unions [indUnionMan - 1].ages[le_death, man] >= unionStatesMan.Unions [indUnionMan - 1].ages[le_union, man]) then
					begin
						caseSelect := 2;
						case caseSelect of
							 0: selectBrideByHerAgeAtUnion (randomGenerator, pMan, unionStatesMan.Unions [indUnionMan - 1], pLastRelative, ageUnionWomanSelected, womanInd, nbTotRelatives);
							 1: selectBrideByManAgeAtUnion (randomGenerator, pMan, unionStatesMan.Unions [indUnionMan - 1], pLastRelative, ageUnionWomanSelected, womanInd, nbTotRelatives);
							 2: selectBrideByManCohortAndAgeAtUnion (randomGenerator, pMan, unionStatesMan.Unions [indUnionMan - 1], pLastRelative, ageUnionWomanSelected, womanInd, nbTotRelatives);
						end;

						pPartnerWoman := pLastRelative;
						pDemReg := getCohort_p (pPartnerWoman^.cohort);
						cohortWoman := pPartnerWoman^.cohort;
				
						//==============
{$IFDEF DEBUG}
getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).CheckOwnChildrenList;
getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).CheckChildrenList(getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).nbChildren, getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).pChildrenList);
{$ENDIF}

						{The variable 'ageUnionWomenSelected' contains the actual age at union for the women selected,
						which can be slightly different from the age we computed at first}
						indUnionWoman := getNumUnionMan (getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides), ageUnionWomanSelected);

						unionStatesMan.Unions [indUnionMan - 1].ages[le_union, woman] := ageUnionWomanSelected;
						unionStatesMan.Unions [indUnionMan - 1].ages[le_death, woman] := getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).unionStates.Unions [indUnionWoman - 1].ages[le_death, woman];
						// actually we take the lifecycle of the women up to age ageUnionWomenSelected and the rest is truncated / discarded
						// we create for that a new 'bride' object, as we don't want to modify the original one
						aNewBrideInfo := TWomanMemoryBlock.Create(
											randomGenerator, 0,
											cohortWoman,
											getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).nbChildren,
											getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).unionStates,
											getWomanFromBigArray (womanInd, gThisIsNotanArrayOfBrides).pChildrenList,
                                            arrayChildren,
											ageUnionWomanSelected
										);

						// we substitute the information for the man in the woman's partnership history and put the correct values for union and death
						aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_union, man] := unionStatesMan.Unions [indUnionMan - 1].ages[le_union, man];
						aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_death, man] := unionStatesMan.Unions [indUnionMan - 1].ages[le_death, man];
						// now we reconstruct the lifecycle AFTER age ageUnionWomenSelected (by setting the last parameter of the procedure call to FALSE)
						calcAgeChildrenTable (aNewBrideInfo.pChildrenList, ageChildren);
						nbChildren := calcCompleteFertilityWoman(
											randomGenerator,
											pDemReg,
											kDeathOfMotherPossible,
											kDeathOfFatherPossible,
											ageUnionWomanSelected,
											indUnionWoman,
											aNewBrideInfo.unionStates, ageChildren,
											aNewBrideInfo.pChildrenList, aNewBrideInfo.unionStates.fecundLife,
											nil,
                                            arrayChildren,
											not kNewReproductiveLife
										);

						//The age at union of the man may have been modified by calcCompleteFertilityWomen function, so we update it here
						setAgeUnion (pMan, indUnionMan,
							aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_union, man]);
						unionStatesMan.Unions [indUnionMan - 1].ages[le_union, man] :=
                        	aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_union, man];
						//age at end of union copied from woman to man
                        unionStatesMan.Unions [indUnionMan - 1].ages[le_endUnion, man] := aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_endUnion, man];
                        unionStatesMan.Unions [indUnionMan - 1].ages[le_endUnion, woman] :=  aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_endUnion, woman];
						aNewBrideInfo.nbChildren := aNewBrideInfo.nbChildren + nbChildren;

{$IFDEF DEBUG}
if gRunFromIDE then begin
	aNewBrideInfo.CheckOwnUnionStates;
	aNewBrideInfo.CheckOwnChildrenList;
	unionStatesMan.checkMe (pMan);
end;
{$ENDIF}

						copyWomanPartnershipInfoToManAsRelative (aNewBrideInfo.unionStates, indUnionWoman, pMan);
						copyWomanPartnershipInfoToWomanAsRelative (aNewBrideInfo.unionStates, pPartnerWoman);

						with pPartnerWoman^ do
						begin
							gender := woman;
							ageAtBirthOfEgo := calcAgeAtBirthOfEgo (pEgo, pPartnerWoman);
                            // geUnion may had been modified before by calcCompleteFertilityWomen
                            // therefore recompute the date of birth of the woman to be on the safe side
                    		calcDateBirth (randomGenerator, dateBirth, pMan^.dateBirth,
                    					aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_union, woman],
                    					aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_union, man]);
							cohort := dateBirth.yearBirth;
							cohortDemReg := pDemReg^.yearOfBirth.value;
							{Age at death of the woman}
							unionStatesMan.Unions [indUnionMan - 1].ages[le_death, woman] := aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_death, woman];
							ageDeath := aNewBrideInfo.unionStates.Unions [indUnionWoman - 1].ages[le_death, woman];
						end;
						addLastPartner (pMan, pPartnerWoman);
						addAllPartners (randomGenerator, pPartnerWoman, aNewBrideInfo.unionStates, pMan, indUnionWoman, pLastRelative, nbTotRelatives);

						{and now the children of this couple}
						{as we introduce them all into ego's kinship, we set the birth order to 0.
						The biological father will be this man, but only for the children of his partnership with this woman}
						calcSiblings(randomGenerator, kinTypeChild, 0, aNewBrideInfo.pChildrenList, pEgo, nil, pPartnerWoman, pMan, pLastRelative, nbTotRelatives);
						aNewBrideInfo.destroy;
					end; {unionStatesMan.Unions [indUnionMan - 1] ...}
				
					{Is this the last union for this man? The man will possibly enter another union if there is a separation or he is a widower}
					pDemReg := getCohort_p (pMan^.cohort);
					moreUnion := AnotherUnionPossible (unionStatesMan.Unions [indUnionMan - 1]);
					if moreUnion then begin
						moreUnion := repartnering_duration (randomGenerator, man, unionStatesMan.Unions [indUnionMan - 1], ageNextUnion, pDemReg^.pCurrUnionInfo, nil);
					end;
				until not moreUnion;
			end; {(pMan^.nUnions > 0)}
			addGroomForComputing2WaysTableOfUnion (pMan);
			calcStateMan := TRUE;
    		unionStatesMan.destroy;
		end; {(pMan <> nil)}

{$IFDEF VerboseProfiler} timeProfile_end_proc('calcStateMan'); {$ENDIF}
	end; {calcStateMan}

{
Looking for parents of pRefChild (ancestors) and the offspring of the mother (in all her partnerships).
We DO NOT have the offspring of the father in other partnerships
The kin have pEgo as reference kin. This way, if the kin are not biological kin of ego, they can have
as reference kin any other kin of ego or kin of other relatives
(but all the kin are stored in the main kinship linked list, with ego as head of the list)
}
	procedure ancestorsAndTheirOffspring (
            randomGenerator: TRandomNumberGenerator;
			kinTypeAncestorMan, kinTypeAncestorWoman, kinTypeChild: KinTypes;
			pEgo: pRelativeType;
			pRefChild: pRelativeType;
			var pLastRelative: pRelativeType;
			var nbTotRelatives: longint);
		var
			pMother, pFather, pPartner: pRelativeType; // biological parents
			womanObj: TWomanMemoryBlock;
			destroyWomanObjOnExit: boolean = false;
			birthOrder: longint = 0; // birth order of pRefChild
			indUnion: longint;
	begin
{$IFDEF VerboseProfiler} timeProfile_start_proc('ancestorsAndTheirOffspring'); {$ENDIF}
	{ancestors}
	{mother}
		pLastRelative := newRelative(pLastRelative, pEgo, nbTotRelatives, kinTypeAncestorWoman);
		pMother := pLastRelative;
		// we look for a mother, equipped with a full union and birth history
		if gBACKFOR_mode then begin
			birthOrder := LookingForMotherBACKFOR(randomGenerator, pRefChild, pMother, womanObj);
		end else if gBACKFOR_mode_pure then begin
			birthOrder := LookingForMother_RealBACKFOR(randomGenerator, pRefChild, pMother, womanObj);
			destroyWomanObjOnExit := true;
		end else if gCAMSIM_1987 then begin
			birthOrder := LookingForMother_CAMSIM_1987(randomGenerator, pRefChild, pMother, womanObj);
			destroyWomanObjOnExit := true;
		end else if gCAMSIM_1993 then begin
			birthOrder := LookingForMother_CAMSIM_1993(randomGenerator, pRefChild, pMother, womanObj, gCAMSIM_1993_unbounded);
			destroyWomanObjOnExit := true;
		end else begin
			birthOrder := LookingForMother(randomGenerator, pRefChild, pMother, womanObj);
		end;
		
		pRefChild^.mother := pMother;
		with pMother^ do
		begin
			gender := woman;
			ageAtBirthOfEgo := calcAgeAtBirthOfEgo(pEgo, pMother);
		end;
	{partners and biological father}
		pFather := nil;
		for indUnion := 1 to pMother^.nUnions do begin
			pLastRelative := newRelative(pLastRelative, pEgo, nbTotRelatives, kinTypeAncestorMan);
			pPartner := pLastRelative;
			if indUnion = pRefChild^.motherUnionNumber then begin
				pFather := pPartner;
				pRefChild^.father := pFather;
			end;
			calcDateBirth(	randomGenerator,
            				pPartner^.dateBirth, pMother^.dateBirth,
							womanObj.unionStates.Unions [indUnion - 1].ages[le_union, man],
							womanObj.unionStates.Unions [indUnion - 1].ages[le_union, woman]
							);
			with pPartner^ do
			begin
				if pPartner <> pFather then begin
					typeOfKin := kt_partner;
					kinOf := pMother;
				end;
				gender := man;
				ageAtBirthOfEgo := calcAgeAtBirthOfEgo(pEgo, pPartner);
				cohort := dateBirth.yearBirth;
				cohortDemReg := getCohort_p (cohort)^.yearOfBirth.value;
				copyWomanPartnershipInfoToManAsRelative (womanObj.unionStates, indUnion, pPartner);
			end;
		
			addLastPartner (pMother, pPartner);
			addLastPartner (pPartner, pMother);
		end;
		
	{offspring of the woman}
		calcSiblings(randomGenerator, kinTypeChild, birthOrder, womanObj.pChildrenList, pEgo, pRefChild, pMother, pFather, pLastRelative, nbTotRelatives);
		
		if destroyWomanObjOnExit then
			FreeAndNil (womanObj);
{$IFDEF VerboseProfiler} timeProfile_end_proc('ancestorsAndTheirOffspring'); {$ENDIF}
	end;

	procedure calcFatherMother (randomGenerator: TRandomNumberGenerator; pEgo: pRelativeType; var nbTotRelatives: longint);
	var
		pRelative: pRelativeType;
	begin
		pRelative := pEgo;
		ancestorsAndTheirOffspring(randomGenerator, kt_father, kt_mother, kt_sibling, pEgo, pEgo, pRelative, nbTotRelatives);
	end;

	procedure linksParentsChildren (pEgo: pRelativeType);
	var
		pRelative: pRelativeType;
	begin
		pRelative := pEgo;
		while (pRelative <> nil) do begin
			if (pRelative^.mother <> nil) then addChild (pRelative^.mother, pRelative);
			if (pRelative^.father <> nil) then addChild (pRelative^.father, pRelative);
			pRelative := pRelative^.nextRelative;
		end;
	end;

	procedure giveEdStatus (randomGenerator: TRandomNumberGenerator;pEgo: pRelativeType);
	var
		pRelative: pRelativeType;
	begin
		pRelative := pEgo;
		while (pRelative <> nil) do begin
			pRelative^.status := edStatus (randomGenerator, getCohort_p(pRelative^.cohort), pRelative, g_GENPARAM.eduKind.value);
			pRelative := pRelative^.nextRelative;
		end;
	end;

	// check the kin network for completeness
	procedure checkRelatives (pRelative: pRelativeType; writeCounts: boolean = false);
	const
		bioKin = False; unionKin = True;
	type
		TListRelatives = record
			num: integer;
			table: array of pRelativeType;
		end;

		TCountOfKinType = array [KinTypes] of array[boolean] of TListRelatives;
		
	var
		ind, a, b: longint;
		countKinsNext, countKinsCheck: TCountOfKinType;
		aKinType: KinTypes;
		pEgo: pRelativeType;
		errorKin: boolean;
		
		procedure initCountOfKins (out c: TCountOfKinType);
		var
			aKinType: KinTypes;

		begin
			for aKinType := kt_none to kt_total do begin
				c[aKinType, bioKin].num := 0;
				c[aKinType, unionKin].num := 0;
				setLength (c[aKinType, bioKin].table, 100);
				setLength (c[aKinType, unionKin].table, 100);
			end;
		end;

		procedure addKinInCount (kt: KinTypes; isUnion: boolean; pRelative: pRelativeType; var c: TCountOfKinType; checkAlreadyInList: boolean = true);
		var
			aKinType: KinTypes;
			ind: longint;
		begin
			if checkAlreadyInList then
				// check first that kin is not already counted
				for aKinType := kt_none to kt_total do begin
					for ind := 0 to c[aKinType, isUnion].num - 1 do
						if (pRelative = c[aKinType, isUnion].table[ind]) then begin
							// we have found it!
							// we check it is in the correct kin category
							if (aKinType <> kt) then stdWriteLn(['Misclassified kin']);
							exit; 
						end;
				end;
			// then add it if not
			with (c [kt, isUnion]) do begin
 				Inc (num);
				if (num > length(table)) then
					setLength(table, length(table) + 100);
				table [num-1] := pRelative;
			end;
		end;

		procedure countKins (pEgo, pRelative: pRelativeType; var c: TCountOfKinType; checkAlreadyInList: boolean = true);
		begin
			while (pRelative <> nil) do begin
				addKinInCount (pRelative^.typeOfKin, byUnion(pEgo, pRelative), pRelative, c, checkAlreadyInList);
				pRelative := pRelative^.nextRelative;
			end;
		end;
		
		procedure writeGeoList (pRelative: pRelativeType; relCount: longint);
			procedure writeKinInfo (pRelative: pRelativeType; pos: longint);
				function writeKinString (pRelative: pRelativeType): string;
				begin
					if (pRelative <> nil) then
						result := str_kinship[pRelative^.typeOfKin] + '_' + IntToStr(pRelative^.indNumber)
					else
						result := 'nil';
				end;
			var
				parentsInfo, unionsInfo, childrenInfo: string;
				ind: longint;
			begin
				parentsInfo := writeKinString (pRelative^.father) + tab;
				parentsInfo := parentsInfo + writeKinString (pRelative^.mother);

				unionsInfo := '';
				for ind := 1 to pRelative^.nUnions do
					unionsInfo := unionsInfo + writeKinString (getPartner (pRelative, ind)) + tab;
				unionsInfo := copy (unionsInfo, 1, length(unionsInfo)-1);
				childrenInfo := '';
				for ind := 1 to getNumChildren (pRelative) do
					childrenInfo := childrenInfo + writeKinString (getChildFromRelative (pRelative, ind)) + tab;
				childrenInfo := copy (childrenInfo, 1, length(childrenInfo)-1);
				with pRelative^ do begin
				stdWriteLn([pos, tab, indNumber, tab, str_kinship[typeOfKin], tab, str_gender[gender], tab,
					str_kinship[kinOf^.typeOfKin], tab, parentsInfo, tab,
					'U:', nUnions, tab, unionsInfo, tab,
					'C:', getNumChildren (pRelative), tab, childrenInfo]);
				end;
			end;
		var
			pos: longint;
		begin
			stdWriteLn(['======= Ego Tree: ', relCount]);
			stdWriteLn(['Id', tab, 'kinType', tab, 'sex', tab, 'kinOf', tab, 'kinFather', tab, 'kinMother', tab, 'kinUnion', tab, 'kinChildren']);
			pos := 0;
			while (pRelative <> nil) do begin
				Inc (pos);
				writeKinInfo (pRelative, pos);
				pRelative := pRelative^.nextRelative;
			end;
		end;

		function childOutsideUnions (pRelative: pRelativeType): boolean;
		// test whether this is a child whose father and mother are both not biological kins of Ego
		// if this is the case, we have no info on their unions and children thereof
		begin
			result :=	(pRelative^.father <> nil) and (pRelative^.father^.typeOfKin = kt_partner) and
						(pRelative^.mother <> nil) and (pRelative^.mother^.typeOfKin = kt_partner)
		end;

		procedure checkInfoUnion (pRel: pRelativeType);
		// coherence of information about unions between partners
		var
           	pPartner: pRelativeType;
			pUnionInfo: pUnionInfoType;
			indUnion: longint;
		begin
		// we focus on ego
			if (pRel^.typeOfKin <> kt_ego) then exit;
			if pRel^.nUnions = 0 then exit;
			for indUnion := 1 to pRel^.nUnions do begin
				pUnionInfo := getUnionInfoByIndex (pRel, indUnion);
                pPartner := pUnionInfo^.partner;
				if (pRel^.cdcDeath < pUnionInfo^.cdcStartUnion) or (pUnionInfo^.partner^.cdcDeath < pUnionInfo^.cdcStartUnion) then begin
					if gRunFromIDE then
{$IFNDEF ARM}
						asm int 3 end;
{$ELSE}
						assert(true);
{$ENDIF}
					writeAndWait ('Ego and partner should have died after the start of union:' + IntToStr (gIndEgo));
				end;
				if (pUnionInfo^.cdcEndUnion < pUnionInfo^.cdcStartUnion) then begin
 					if gRunFromIDE then
{$IFNDEF ARM}
						asm int 3 end;
{$ELSE}
						assert(true);
{$ENDIF}
					writeAndWait ('End union should occur after start of union:' + IntToStr (gIndEgo));
				end;
				case pUnionInfo^.endOfPartnership of
					end_by_death:
						// ego should have died before the partner and on the date of end of union;
						if (pUnionInfo^.ageEndUnion <> pRel^.ageDeath) or
                            (pRel^.cdcDeath > pUnionInfo^.partner^.cdcDeath) then begin
							writeAndWait ('Partner should have died after ego:' + IntToStr (gIndEgo));
                         		   if gRunFromIDE then
							if gRunFromIDE then
{$IFNDEF ARM}
								asm int 3 end;
{$ELSE}
								assert(true);
{$ENDIF}
						end;
 					end_by_widowhood:
						// ego should have died after the partner;
						if (pRel^.cdcDeath < pUnionInfo^.partner^.cdcDeath) then begin
							writeAndWait ('Partner should have died before ego:' + IntToStr (gIndEgo));
                            if gRunFromIDE then
{$IFNDEF ARM}
                                asm int 3 end
{$ELSE}
       				assert(true);
{$ENDIF}
						end;
					end_by_separation:
						if (pRel^.cdcDeath < pUnionInfo^.cdcEndUnion) or (pUnionInfo^.partner^.cdcDeath < pUnionInfo^.cdcEndUnion) then begin
							if gRunFromIDE then
{$IFNDEF ARM}
							asm int 3 end;
{$ELSE}
							assert(true);
{$ENDIF}
                            pUnionInfo^.partner^.cdcDeath := pUnionInfo^.cdcEndUnion;
							writeAndWait ('Ego or partner should have died after the end of union:' + IntToStr (gIndEgo));
						end;
						// both ego and the partner should have died after the end of union;
				end;
			end;
		end;
			
	var
		pos: longint;
		
	begin {checkRelatives}
		pEgo := pRelative;
		
		checkInfoUnion (pEgo);
		
		// count kins in two ways and compare
		initCountOfKins (countKinsNext);
		countKins (pEgo, pEgo, countKinsNext, false);
		
		if writeCounts then begin
			bWriteLn(gDebugFile, ['ego number: ', tab, pEgo^.indNumber]);
			bWriteLn(gDebugFile, ['kinType', tab, 'byUnion', tab, 'bioKin']);
			for aKinType := kt_none to kt_total do begin
				bWriteLn(gDebugFile, [str_kinship[aKinType], tab, countKinsNext[aKinType, true].num, tab, countKinsNext[aKinType, false].num])
			end;
		end;
		
		initCountOfKins (countKinsCheck);
		addKinInCount (kt_ego, bioKin, pEgo, countKinsCheck);
		countKins (pEgo, pEgo^.father, countKinsCheck);
		countKins (pEgo, pEgo^.mother, countKinsCheck);
		for ind := 1 to pEgo^.nUnions do begin
			countKins (pEgo, getPartner (pEgo, ind), countKinsCheck);
		end;
		for ind := 1 to getNumChildren (pEgo) do begin
			countKins (pEgo, getChildFromRelative (pEgo, ind), countKinsCheck);
		end;
		// total
		for aKinType := kt_none to kt_nonBio do begin
			countKinsNext [kt_total, bioKin].num :=
						  countKinsNext [kt_total, bioKin].num +
						  countKinsNext [aKinType, bioKin].num;
			countKinsNext [kt_total, unionKin].num :=
						  countKinsNext [kt_total, unionKin].num +
						  countKinsNext [aKinType, unionKin].num;
			countKinsCheck [kt_total, bioKin].num :=
						  countKinsCheck [kt_total, bioKin].num +
						  countKinsCheck [aKinType, bioKin].num;
			countKinsCheck [kt_total, unionKin].num :=
						  countKinsCheck [kt_total, unionKin].num +
						  countKinsCheck [aKinType, unionKin].num;
		end;

		errorKin := false;
		for aKinType := kt_none to kt_total do begin
			a := countKinsNext [aKinType, bioKin].num;
			b := countKinsCheck [aKinType, bioKin].num;
			if (a <> b) then
				errorKin := true;
			a := countKinsNext [aKinType, unionKin].num;
			b := countKinsCheck [aKinType, unionKin].num;
			if (a <> b) then
				errorKin := true;
		end;

		InterlockedIncrement (gCheckRelativesCount);
		if (gCheckRelativesCount <= gCheckRelativesMax) or (errorKin) then begin
			//write info for the first kin trees
			stdWriteLn(['======= Ego: ', gCheckRelativesCount]);
			for aKinType := kt_none to kt_total do begin
				stdWriteLn([
							str_kinship[aKinType], ': ',
							countKinsNext [aKinType, bioKin].num, ' ', countKinsNext [aKinType, unionKin].num, ' ',
							countKinsCheck [aKinType, bioKin].num, ' ', countKinsCheck [aKinType, unionKin].num
					]);
			end;
			writeGeoList (pEgo, gCheckRelativesCount);			
		end;
		if (gCheckRelativesCount >= gViewFromEgo) and (gCheckRelativesCount <= gViewToEgo) then
			writeGeoList (pEgo, gCheckRelativesCount);
			
		// check consistency of info
		pos := 0;
		while (pRelative <> nil) do begin
			Inc (pos);
			with pRelative^ do begin
				if not childOutsideUnions (pRelative) then begin
					for ind := 1 to getNumChildren (pRelative) do begin
						if getChildFromRelative (pRelative, ind) = nil then
							stdWriteLn (['Missing child id: ', indNumber,
							' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
					end;
					for ind := 1 to nUnions do begin
						if (getPartner (pRelative, ind) = nil) and not (typeOfKin in gKinsWithNoDescendance) then
							stdWriteLn (['Missing partner individual: ', indNumber,
							' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
						if (getAgeUnion (pRelative, ind) < 0) then
							stdWriteLn (['Missing age at union individual: ', indNumber, ', union: ', ind,
							' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
						if (getAgeEndUnion (pRelative, ind) < 0) and not (typeOfKin in gKinsWithNoDescendance) then
							stdWriteLn (['Missing age at end union individual: ', indNumber, ', union: ', ind,
							' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
						if (ind >= 2) then begin
							if (getAgeUnion (pRelative, ind) < getAgeUnion (pRelative, ind - 1)) then
								stdWriteLn (['Current age at union lower than preceding one, individual: ', indNumber, ', union: ', ind,
								' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
							if (getAgeEndUnion (pRelative, ind) < getAgeEndUnion (pRelative, ind - 1)) then
								stdWriteLn (['Current age at end of union lower than preceding one, individual: ', indNumber, ', union: ', ind,
								' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
							if (getAgeUnion (pRelative, ind) < getAgeEndUnion (pRelative, ind - 1)) then
								stdWriteLn (['Current age at union lower than age at end of preceding union, individual: ', indNumber, ', union: ', ind,
								' at pos:', pos, ' kintype: ', str_kinship[typeOfKin], ' family: ', gCheckRelativesCount]);
						end;
					end;
				end;
			end;
			pRelative := pRelative^.nextRelative;
		end;
	end; {end checkRelatives}

	procedure setKinshipToSimulate (kinsToSimulate: KinSetType; writeIt: boolean = false);
	var
		aKin: KinTypes;
		arrayKinBranchUp: KinBranchType;	// kins that should be simulated if selected 'kin' is included
		arrayKinBranchDown: KinBranchType;	// descendance of selected 'kins' (to help construct gKinsWithNoDescendance)
		arrayIncludedKin: KinBranchType;	// kins that are automatically simulated when selected 'kin' is included
		
	begin
		for aKin := low(kinTypes) to high(kinTypes) do
			arrayKinBranchUp [aKin] := [];
			
		arrayKinBranchUp [kt_partner] := [kt_ego] + arrayKinBranchUp [kt_ego];
		arrayKinBranchUp [kt_child] := [kt_partner] + arrayKinBranchUp [kt_partner];
		arrayKinBranchUp [kt_grandChild] := [kt_child] + arrayKinBranchUp [kt_child];
		arrayKinBranchUp [kt_greatGrandChild] := [kt_grandChild] + arrayKinBranchUp [kt_grandChild];

		arrayKinBranchUp [kt_mother] := [kt_ego] + arrayKinBranchUp [kt_ego];
		arrayKinBranchUp [kt_father] := [kt_mother] + arrayKinBranchUp [kt_mother];
		arrayKinBranchUp [kt_sibling] := [kt_father] + arrayKinBranchUp [kt_father];
		arrayKinBranchUp [kt_nieceNephew] := [kt_sibling] + arrayKinBranchUp [kt_sibling];
		arrayKinBranchUp [kt_grandNieceNephew] := [kt_nieceNephew] + arrayKinBranchUp [kt_nieceNephew];
		arrayKinBranchUp [kt_greatGrandNieceNephew] := [kt_grandNieceNephew] + arrayKinBranchUp [kt_grandNieceNephew];

		arrayKinBranchUp [kt_grandMother] := arrayKinBranchUp [kt_father];
		arrayKinBranchUp [kt_grandFather] := [kt_grandMother] + arrayKinBranchUp [kt_father];
		arrayKinBranchUp [kt_auntUncle] := [kt_grandFather] + arrayKinBranchUp [kt_grandFather];
		arrayKinBranchUp [kt_cousin] := [kt_auntUncle] + arrayKinBranchUp [kt_auntUncle];
		arrayKinBranchUp [kt_cousin_removed] := [kt_cousin] + arrayKinBranchUp [kt_cousin];
		arrayKinBranchUp [kt_cousin_twice_removed] := [kt_cousin_removed] + arrayKinBranchUp [kt_cousin_removed];
		arrayKinBranchUp [kt_cousin_thrice_removed] := [kt_cousin_twice_removed] + arrayKinBranchUp [kt_cousin_twice_removed];

		arrayKinBranchUp [kt_greatGrandMother] := arrayKinBranchUp [kt_grandFather];
		arrayKinBranchUp [kt_greatGrandFather] := [kt_greatGrandMother] + arrayKinBranchUp [kt_greatGrandMother];
		arrayKinBranchUp [kt_grandAuntUncle] := [kt_greatGrandFather] + arrayKinBranchUp [kt_greatGrandFather];
		arrayKinBranchUp [kt_great_cousin_removed] := [kt_grandAuntUncle] + arrayKinBranchUp [kt_grandAuntUncle];
		arrayKinBranchUp [kt_second_cousin] := [kt_great_cousin_removed] + arrayKinBranchUp [kt_great_cousin_removed];
		arrayKinBranchUp [kt_second_cousin_removed] := [kt_second_cousin] + arrayKinBranchUp [kt_second_cousin];
		arrayKinBranchUp [kt_second_cousin_twice_removed] := [kt_second_cousin_removed] + arrayKinBranchUp [kt_second_cousin_removed];
		
		for aKin := low(kinTypes) to high(kinTypes) do
			arrayKinBranchDown [aKin] := [];
		
		arrayKinBranchDown [kt_ego] := [kt_child];
		arrayKinBranchDown [kt_child] := [kt_grandChild];
		arrayKinBranchDown [kt_grandChild] := [kt_greatGrandChild];
		arrayKinBranchDown [kt_mother] := [kt_ego];
		arrayKinBranchDown [kt_father] := [kt_ego];
		arrayKinBranchDown [kt_sibling] := [kt_nieceNephew];
		arrayKinBranchDown [kt_nieceNephew] := [kt_grandNieceNephew];
		arrayKinBranchDown [kt_grandNieceNephew] := [kt_greatGrandNieceNephew];
		arrayKinBranchDown [kt_grandMother] := [kt_auntUncle];
		arrayKinBranchDown [kt_grandFather] := [kt_auntUncle];
		arrayKinBranchDown [kt_auntUncle] := [kt_cousin];
		arrayKinBranchDown [kt_cousin] := [kt_cousin_twice_removed];
		arrayKinBranchDown [kt_cousin_twice_removed] := [kt_cousin_thrice_removed];
		arrayKinBranchDown [kt_greatGrandMother] := [kt_grandAuntUncle];
		arrayKinBranchDown [kt_greatGrandFather] := [kt_grandAuntUncle];
		arrayKinBranchDown [kt_grandAuntUncle] := [kt_great_cousin_removed];
		arrayKinBranchDown [kt_great_cousin_removed] := [kt_second_cousin];
		arrayKinBranchDown [kt_second_cousin] := [kt_second_cousin_removed];
		arrayKinBranchDown [kt_second_cousin_removed] := [kt_second_cousin_twice_removed];

		for aKin := low(kinTypes) to high(kinTypes) do
			arrayIncludedKin [aKin] := [];
		
		arrayIncludedKin [kt_mother] := [kt_sibling];
		arrayIncludedKin [kt_grandMother] := [kt_auntUncle];
		arrayIncludedKin [kt_greatGrandMother] := [kt_grandAuntUncle];

		gKinsToSimulate := [kt_ego];
		gKinsWithNoDescendance := [];
		for aKin := low(KinTypes) to high(KinTypes) do begin
			gKinsWithNoDescendance := gKinsWithNoDescendance + [aKin];
		end;
		gKinsWithNoDescendance := gKinsWithNoDescendance - [kt_none, kt_nonBio, kt_total];
		for aKin := low(KinTypes) to high(KinTypes) do begin
			if aKin in kinsToSimulate then begin
				gKinsToSimulate := gKinsToSimulate + [aKin] + arrayKinBranchUp[aKin];
				gKinsWithNoDescendance := gKinsWithNoDescendance - arrayKinBranchUp[aKin];
			end;
		end;

		gKinsWithNoDescendance := gKinsWithNoDescendance * gKinsToSimulate;

		for aKin := low(KinTypes) to high(KinTypes) do begin
			if (aKin in gKinsToSimulate) then
				if not (arrayIncludedKin[aKin] <= gKinsToSimulate) then
					gKinsWithNoDescendance := gKinsWithNoDescendance + arrayIncludedKin[aKin];
		end;

		for aKin := low(KinTypes) to high(KinTypes) do begin
			if (aKin in gKinsToSimulate) then
				if not (arrayKinBranchDown[aKin] <= gKinsToSimulate) then
					gKinsWithNoDescendance := gKinsWithNoDescendance + [aKin];
		end;

		if g_GENPARAM.NON_BIO_KIN.value then begin
			gKinsToSimulate := gKinsToSimulate + [kt_nonBio];
		end;

		if writeIt then begin
			stdWriteLn(['============  Selected kins ==================']);
			for aKin in kinsToSimulate do
				stdWriteLn([str_kinship[aKin]]);
			stdWriteLn(['============  Kins to be simulated ============']);
			for aKin in gKinsToSimulate do
				stdWriteLn([str_kinship[aKin]]);
			stdWriteLn(['============  Kins with no descendance ========']);
			for aKin in gKinsWithNoDescendance do
				stdWriteLn([str_kinship[aKin]]);
		end;
	end;

	procedure assignDestiny (randomGenerator: TRandomNumberGenerator; pRelative: pRelativeType);
	begin
		while (pRelative <> nil) do begin
			if (pRelative^.ageDeath = kNotDefined) then begin
				stdWrite ([str_kinship[pRelative^.TypeOfKin], ' age not defined']);
				destiny (randomGenerator, pRelative^.TypeOfKin, pRelative);
			end;
			pRelative := pRelative^.nextRelative;
		end;
	end;

	procedure ascendantsForLastPartner (randomGenerator: TRandomNumberGenerator; pEgo: pRelativeType; var pLastRelative: pRelativeType; var nbTotRelatives: longint);
	var
		pPartner, pMother, pFather: pRelativeType;
	begin
		if (pEgo^.nUnions = 0) then exit;
		pPartner := getPartner (pEgo, pEgo^.nUnions);
		ancestorsAndTheirOffspring(randomGenerator, kt_father, kt_mother, kt_sibling, pPartner, pPartner, pLastRelative, nbTotRelatives);
		pMother := LookingForRelative(pPartner, kt_mother, woman);
		if pMother = nil then
			writeAndWait(MotherNotFound);
		ancestorsAndTheirOffspring(randomGenerator, kt_grandFather, kt_grandMother, kt_auntUncle, pPartner, pMother, pLastRelative, nbTotRelatives);
		pFather := LookingForRelative(pPartner, kt_father, man);
		if pFather = nil then
			writeAndWait(FatherNotFound);
		ancestorsAndTheirOffspring(randomGenerator, kt_grandFather, kt_grandMother, kt_auntUncle, pPartner, pFather, pLastRelative, nbTotRelatives);
	end;
	
	procedure calcCountSize (pRel: pRelativeType; writeIt: boolean = false; onlyOne: boolean = false);
	var
		totRelatives: longint = 0;
		sizeOne: longint = 0;
		totSize: longint = 0;
	begin
		while pRel <> nil do begin
			Inc (totRelatives);
			sizeOne := sizeOfRelativeType (pRel);
			totSize := totSize + sizeOne;
			if onlyOne then
				pRel := nil
			else
				pRel := pRel^.nextRelative;
		end;
		if writeIt then
			stdWriteLn (['Count relatives: ', totRelatives, ', total size: ', totSize, ' bytes']);
	end;
	
	procedure calcKinship (randomGenerator: TRandomNumberGenerator; pEgo: pRelativeType; arrayChildren: arrayOfInfoChild; var nbTotRelatives: longint; relativeSet: KinSetType);
	var
		pMother, pFather, pGrandMother, pGrandFather, pGreatGrandParent, pLastRelative: pRelativeType;
		allKin: boolean = false;
		//for debugging purpose
		posInFamily, nbTotRelatives_init: longint;
	begin
		// we include all kin if relativeSet is empty
		allKin := relativeSet = [];
	{pEgo is always the start / head of the kinship linked list and pLastRelative is always the end / tail}
	{Observe that pEgo is normally the 'true' ego, but it can also be any other relative.
	In the case pEgo is not the 'true' ego, the kin will not be biological kin of ego and will not have
	pEgo as kinOf}
	
		pLastRelative := tailOfRelativeList (pEgo);

		nbTotRelatives_init := nbTotRelatives;
{$IFDEF VerboseProfiler} timeProfile_start_proc('calcKinship'); {$ENDIF}

		{partner and children of pEgo => DESCENDANCE}
		if allKin or (kt_partner in relativeSet) or (kt_child in relativeSet) then begin
			if not (calcStateMan(randomGenerator, pEgo^.typeOfKin, kt_child, pEgo, arrayChildren, pLastRelative, nbTotRelatives) or
				calcStateWoman(randomGenerator, pEgo^.typeOfKin, kt_child, pEgo, arrayChildren, pLastRelative, nbTotRelatives)) then
				{no union and so no children... we could prevent here to look for grand children...};
			posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
			{partners of children and grandchildren => DESCENDANCE 2}
			if allKin or (kt_grandChild in relativeSet) then begin
				while calcStateMan(randomGenerator, kt_child, kt_grandChild, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
					  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				while calcStateWoman(randomGenerator, kt_child, kt_grandChild, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
					  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				{partners of grandchildren and great-grandchildren => DESCENDANCE 3}
				if allKin or (kt_greatGrandChild in relativeSet) then begin
					while calcStateMan(randomGenerator, kt_grandChild, kt_greatGrandChild, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
						  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					while calcStateWoman(randomGenerator, kt_grandChild, kt_greatGrandChild, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
						  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				end;
			end;
		end;
		
		{parents and siblings of pEgo => ASCENDANCE 1}
		if allKin or (kt_father in relativeSet) or (kt_mother in relativeSet) or (kt_sibling in relativeSet) then begin
			ancestorsAndTheirOffspring(randomGenerator, kt_father, kt_mother, kt_sibling, pEgo, pEgo, pLastRelative, nbTotRelatives);
			posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;

			{partners of siblings and niece/nephews => LATERAL and DESCENDANCE 1}
			if allKin or (kt_nieceNephew in relativeSet) then begin
				while calcStateMan(randomGenerator, kt_sibling, kt_nieceNephew, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
					  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				while calcStateWoman(randomGenerator, kt_sibling, kt_nieceNephew, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
					  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				{grand niece/nephews => DESCENDANCE 2}
				if allKin or (kt_grandNieceNephew in relativeSet) then begin
					while calcStateMan(randomGenerator, kt_nieceNephew, kt_grandNieceNephew, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
						  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					while calcStateWoman(randomGenerator, kt_nieceNephew, kt_grandNieceNephew, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
						  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				end;
					{great grand niece/nephews => DESCENDANCE 3}
					if allKin or (kt_grandNieceNephew in relativeSet) then begin
						while calcStateMan(randomGenerator, kt_grandNieceNephew, kt_greatGrandNieceNephew, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
							  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
						while calcStateWoman(randomGenerator, kt_grandNieceNephew, kt_greatGrandNieceNephew, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
							  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					end;
			end;

			{grandparents and aunts/uncles => ASCENDANCE 2 AND DESCENDANCE 1}
			if allKin or (kt_grandFather in relativeSet) or (kt_grandMother in relativeSet) or (kt_auntUncle in relativeSet) then begin
				pMother := LookingForRelative(pEgo, kt_mother, woman);
				if pMother = nil then
					writeAndWait(MotherNotFound);
				ancestorsAndTheirOffspring(randomGenerator, kt_grandFather, kt_grandMother, kt_auntUncle, pEgo, pMother, pLastRelative, nbTotRelatives);
				posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				pFather := LookingForRelative(pEgo, kt_father, man);
				if pFather = nil then
					writeAndWait(FatherNotFound);
				ancestorsAndTheirOffspring(randomGenerator, kt_grandFather, kt_grandMother, kt_auntUncle, pEgo, pFather, pLastRelative, nbTotRelatives);
				posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
				{partners of biological aunt/uncle and cousins => LATERAL AND DESCENDANCE 2}
				if allKin or (kt_cousin in relativeSet) then begin
					while calcStateMan(randomGenerator, kt_auntUncle, kt_cousin, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
						  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					while calcStateWoman(randomGenerator, kt_auntUncle, kt_cousin, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
						  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					{partners of cousins and cousins once removed => DESCENDANCE 3}
					if allKin or (kt_cousin_removed in relativeSet) then begin
						while calcStateMan(randomGenerator, kt_cousin, kt_cousin_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
							  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
						while calcStateWoman(randomGenerator, kt_cousin, kt_cousin_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
							  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
						{partners of cousins once removed and cousins twice removed => DESCENDANCE 4}
						if allKin or (kt_cousin_twice_removed in relativeSet) then begin
							while calcStateMan(randomGenerator, kt_cousin_removed, kt_cousin_twice_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
								  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
							while calcStateWoman(randomGenerator, kt_cousin_removed, kt_cousin_twice_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
								  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
						end;
							{partners of cousins twice removed and cousins thrice removed => DESCENDANCE 5}
							if allKin or (kt_cousin_thrice_removed in relativeSet) then begin
								while calcStateMan(randomGenerator, kt_cousin_twice_removed, kt_cousin_thrice_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
									  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
								while calcStateWoman(randomGenerator, kt_cousin_twice_removed, kt_cousin_thrice_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
									  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
							end;
					end;
				end; {partners of biological aunt/uncle and cousins}
				
				{======}
				{great-grandparents and great-aunts/uncles => ASCENDANCE 3 AND DESCENDANCE 1}
				if allKin or (kt_greatGrandFather in relativeSet) or (kt_greatGrandMother in relativeSet) or (kt_grandAuntUncle in relativeSet) then begin
					{ASCENDANCE of grandMother 1}
					pGrandMother := LookingForRelative(pEgo, kt_grandMother, woman, pMother^.mother);
					if pGrandMother = nil then
						writeAndWait(MotherNotFound);
					ancestorsAndTheirOffspring(randomGenerator, kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle, pEgo, pGrandMother, pLastRelative, nbTotRelatives);
					posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					{ASCENDANCE of grandMother 2}
					pGrandMother := LookingForRelative(pEgo, kt_grandMother, woman, pFather^.mother);
					if pGrandMother = nil then
						writeAndWait(MotherNotFound);
					ancestorsAndTheirOffspring(randomGenerator, kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle, pEgo, pGrandMother, pLastRelative, nbTotRelatives);
					posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					{ASCENDANCE of grandFather 1}
					pGrandFather := LookingForRelative(pEgo, kt_grandFather, man, pMother^.father);
					if pGrandFather = nil then
						writeAndWait(FatherNotFound);
					ancestorsAndTheirOffspring(randomGenerator, kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle, pEgo, pGrandFather, pLastRelative, nbTotRelatives);
					posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					{ASCENDANCE of grandFather 2}
					pGrandFather := LookingForRelative(pEgo, kt_grandFather, man, pFather^.father);
					if pGrandFather = nil then
						writeAndWait(FatherNotFound);
					ancestorsAndTheirOffspring(randomGenerator, kt_greatGrandFather, kt_greatGrandMother, kt_grandAuntUncle, pEgo, pGrandFather, pLastRelative, nbTotRelatives);
					posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
					{partners of biological great aunts/uncles and (great) first cousins once removed => LATERAL AND DESCENDANCE 2}
					if allKin or (kt_great_cousin_removed in relativeSet) then begin
						while calcStateMan(randomGenerator, kt_grandAuntUncle, kt_great_cousin_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
							  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
						while calcStateWoman(randomGenerator, kt_grandAuntUncle, kt_great_cousin_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
							  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
						{partners of (great) first cousins once removed and second cousins => DESCENDANCE 3}
						if allKin or (kt_second_cousin in relativeSet) then begin
							while calcStateMan(randomGenerator, kt_great_cousin_removed, kt_second_cousin, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
								  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
							while calcStateWoman(randomGenerator, kt_great_cousin_removed, kt_second_cousin, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
								  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
							{partners of second cousins and second cousins once removed => DESCENDANCE 4}
							if allKin or (kt_second_cousin_removed in relativeSet) then begin
								while calcStateMan(randomGenerator, kt_second_cousin, kt_second_cousin_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
									  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
								while calcStateWoman(randomGenerator, kt_second_cousin, kt_second_cousin_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
									  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
								{partners of second cousins once removed and second cousins twice removed => DESCENDANCE 5}
								if allKin or (kt_second_cousin_twice_removed in relativeSet) then begin
									while calcStateMan(randomGenerator, kt_second_cousin_removed, kt_second_cousin_twice_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
										  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
									while calcStateWoman(randomGenerator, kt_second_cousin_removed, kt_second_cousin_twice_removed, pEgo, arrayChildren, pLastRelative, nbTotRelatives) do
										  posInFamily := pLastRelative^.indNumber - nbTotRelatives_init + 1;
								end;
							end;
						end;
					end; {partners of biological aunt/uncle and cousins}
				end; {grandparents and aunts/uncles}
				{======}
			end; {grandparents and aunts/uncles}

		end; {parents and siblings}
		{for all individuals: we create a link to their children.}
{$IFDEF VerboseProfiler} timeProfile_start_proc('linksParentsChildren'); {$ENDIF}
		linksParentsChildren (pEgo);
{$IFDEF VerboseProfiler} timeProfile_end_proc('linksParentsChildren'); {$ENDIF}
		// simulate ascendants (two generations) for ego's last partner
		//ascendantsForLastPartner (pEgo, pLastRelative, nbTotRelatives);
		{we assign an age at death and at union for kins who do not have one}
{$IFDEF VerboseProfiler} timeProfile_start_proc('assignDestiny'); {$ENDIF}
		assignDestiny (randomGenerator, pEgo);
{$IFDEF VerboseProfiler} timeProfile_end_proc('assignDestiny'); {$ENDIF}
		computeCDC (randomGenerator, pEgo);

{$IFDEF VerboseProfiler} timeProfile_end_proc('calcKinship'); {$ENDIF}

{$IFDEF VerboseProfiler} timeProfile_start_proc('checkRelatives'); {$ENDIF}
{$IFDEF DEBUG}
if gRunFromIDE and g_GENPARAM.CHECK_DATASTRUCT.value then begin
	checkRelatives (pEgo, g_GENPARAM.DEBUG.value);
end;
{$ENDIF}
{$IFDEF VerboseProfiler} timeProfile_end_proc('checkRelatives'); {$ENDIF}

{$IFDEF VerboseProfiler} timeProfile_start_proc('inheritance'); {$ENDIF}
		if (fn_typeHeirs in g_GENPARAM.OUTPUT_FIELDS.value) then begin
			lookForHeirs (pEgo);
			lookForInheritance (pEgo);
		end;
{$IFDEF VerboseProfiler} timeProfile_end_proc('inheritance'); {$ENDIF}

{$IFDEF VerboseProfiler} timeProfile_start_proc('endCalcKinship'); {$ENDIF}
		calcCountSize (pEgo, false);
		giveEdStatus (randomGenerator, pEgo);
{$IFDEF VerboseProfiler} timeProfile_end_proc('endCalcKinship'); {$ENDIF}
	end;

	procedure simulFatherMother (randomGenerator: TRandomNumberGenerator; ageEgo: agesLife; out ageFather, ageMother: agesLife);
		var
			pEgo, pRelative: pRelativeType;
			age: longint;
			nbTotRelatives: longint = 0;
	begin
		pEgo := initKinshipTree (nbTotRelatives);
		destiny(randomGenerator, kt_ego, pEgo);
		if pEgo^.ageDeath >= ageEgo then
			begin
				calcFatherMother(randomGenerator, pEgo, nbTotRelatives);
				pRelative := LookingForRelative(pEgo, kt_mother, woman);
				if pRelative = nil then
					writeAndWait(MotherNotFound);
				age := pRelative^.ageAtBirthOfEgo + ageEgo;
				if age <= pRelative^.ageDeath then
					ageMother := age
				else
					ageMother := 0;
				pRelative := LookingForRelative(pEgo, kt_father, man);
				if pRelative = nil then
					writeAndWait(FatherNotFound);
				age := pRelative^.ageAtBirthOfEgo + ageEgo;
				if age <= pRelative^.ageDeath then
					ageFather := age
				else
					ageFather := 0;
			end
		else
			writeAndWait(ProblemAgeDeathEgoLowerThanNeeded);

		disposeKinship(pEgo);
	end;

	procedure initDataKinship(setAgesEgo: setAges);
	var
		typeOfKin: KinTypes;
		ageEgoInd: longint;
		ageEgo, ind, nbRelatives: longint;
		sexT: SexTotal;
        indState: StateTypes;
	begin
		gAgeFatherAgeSon[ageAtBirthFirst] := 0;
		gAgeFatherAgeSon[ageDeathFather] := 0;
		gAgeFatherAgeSon[ageAtUnionFirstChild] := 0;
		gAgeFatherAgeSon[numberCases] := 0;

		setLength (g_TotalBornKinship, 0);
		if g_GENPARAM.outputs_opt[res_kin_totalNumbers].value then begin
			setLength (g_TotalBornKinship,
				ord(high(KinTypes)) - ord(low(KinTypes)) + 1,
				ord(high(SexTotal)) - ord(low(SexTotal)) + 1,
				kMaxNumRelatives_extended - kTotal + 1);
			// not necessary, but just in case...
			for typeOfKin := kFirstKinInEnum to kLastKinInEnum do
				for ind := kTotal to kMaxNumRelatives_extended do
					for sexT := low(SexTotal) to high(SexTotal) do
						g_TotalBornKinship[ord(typeOfKin), ord(sexT), ind-kTotal] := 0;
				for ind := kTotal to kMaxNumRelatives_extended do
					for sexT := low(SexTotal) to high(SexTotal) do
						g_TotalBornKinship[ord(kt_total), ord(sexT), ind-kTotal] := 0;
		end;
		
		ageEgoInd := -1;
		for ageEgo in setAgesEgo do
		begin
			ageEgoInd := ageEgoInd + 1;
			for typeOfKin := kFirstKinInEnum to kt_total do
			begin
				for indState := low(StateTypes) to high(StateTypes) do
					for sexT := low(SexTotal) to high(SexTotal) do
						g_momEcAge[sexT, ageEgoInd, typeOfKin, indState] := 0.0;
				for nbRelatives := 0 to kMaxNumRelatives do begin
					g_distribKins[ageEgoInd, nbRelatives, typeOfKin] := 0.0;
					for sexT := low(SexTotal) to high(SexTotal) do begin
						g_distribKins_SurvEgo[sexT, ageEgoInd, nbRelatives, typeOfKin] := 0.0;
						g_distribBornKins_SurvEgo[sexT, ageEgoInd, nbRelatives, typeOfKin] := 0.0;
					end;
				end;
			end; {for typeOfKin := kFirstKinInEnum to kLastKinInEnum do}
		end;
	end;
	
	function currPartner (pRelative: pRelativeType; ageEgoRef: longint): StatusUnion;
	// check whether partner pRelative is currently in union with ego or a biological kin of ego, at age ageRef
	var
		ind: longint;
		pPartner: pRelativeType;
		ageAtStartOfUnion, ageAtEndOfUnion: double;
	begin
		result := su_none;
		with pRelative^ do begin
			for ind := 1 to nUnions do begin
				pPartner := getPartner (pRelative, ind);
				if pPartner <> nil then begin
					if (getPartner (pRelative, ind)^.typeOfKin = kinOf^.typeOfKin) then begin
						// found ego or the biological kin of ego
						ageAtStartOfUnion := getAgeUnion (pRelative, ind);
						ageAtEndOfUnion := getAgeEndUnion (pRelative, ind);
						if (ageAtEndOfUnion = kNotDefined) then
							// problem no age at end of union
							ageAtEndOfUnion := ageAtEndOfUnion;
						result := su_before;
						if (ageEgoRef + ageAtBirthOfEgo >= ageAtStartOfUnion) and (ageEgoRef + ageAtBirthOfEgo <= ageAtEndOfUnion) then
							result := su_inUnion
						else if (ageEgoRef + ageAtBirthOfEgo > ageAtEndOfUnion) then
							result := su_after;
						exit;
					end;
				end;
			end;
		end;
		// problem not found
		ind := ind;
	end;
	
	procedure addToTableKinship (pEgo: pRelativeType;
								sa: setAges;
								var tabKinshipAgeEgo: AgeEgo_arrayKinshipStruct;
								var numKinsByAgeEgo: KinByAgeEgoStruct);
	var
		pRelative: pRelativeType;
		ageEgo, ageRef, ageEgoInd, ageDeathEgo, ageBirthRef, ageDeathRef: longint;
		ageInd: ageEgoInt;
		a: agesLife;
		aKinType: KinTypes;
		indCohort: longint;
		sexT: SexTotal;
		sexT_Ego: SexTotal;
        setSex: set of SexTotal;
        
		// kins by age and sex of ego
		nLivingKins: array [ageEgoInt, SexTotal, KinTypes] of longint;
		nBornKins: array [ageEgoInt, SexTotal, KinTypes] of longint;
		nBornKins_total: array [SexTotal, KinTypes] of longint;
		
		numKins_alive, numKins_born: longint;
		ageUnionStatus: StatusUnion;
		SelectAllKinsBorn: boolean = true;
		SelectKinsBornAndPossiblyAlive: boolean = false;

	begin
		for aKinType := low (KinTypes) to high (KinTypes) do
			for sexT := low (SexTotal) to high (SexTotal) do begin
				nBornKins_total [sexT, aKinType] := 0;
				for ageInd := low (ageEgoInt) to high (ageEgoInt) do begin
					nBornKins [ageInd, sexT, aKinType] := 0;
					nLivingKins [ageInd, sexT, aKinType] := 0;
				end;
			end;

		if pEgo^.gender = man then begin
			sexT_Ego := men;
{$IFDEF DEBUG}
Inc (gNumEgoMen);
gChildrenEgoMen := gChildrenEgoMen + getNumChildren (pEgo);
{$ENDIF}
		end else begin
			sexT_Ego := women;
{$IFDEF DEBUG}
Inc (gNumEgoWomen);
gChildrenEgoWomen := gChildrenEgoWomen + getNumChildren (pEgo);
{$ENDIF}
		end;

		ageDeathEgo := trunc (pEgo^.ageDeath);
		for a := 0 to ageDeathEgo do begin
			InterlockedIncrement (numKinsByAgeEgo[sexT_Ego, a, kt_ego]);
			InterlockedIncrement (numKinsByAgeEgo[all, a, kt_ego]);
		end;

		// add ego to born kins count
		if (SelectAllKinsBorn) then begin
			if g_GENPARAM.outputs_opt[res_kin_totalNumbers].value then begin
				InterlockedIncrement (g_TotalBornKinship[ord(kt_ego), ord(sexT_Ego), kTotal-kTotal]);
				InterlockedIncrement (g_TotalBornKinship[ord(kt_ego), ord(all), kTotal-kTotal]);
			end;
			Inc (nBornKins_total[sexT_Ego, kt_ego]);
			Inc (nBornKins_total[all, kt_ego]);
		end;
		
		pRelative := pEgo^.nextRelative;
		while (pRelative <> nil) do begin
			with pRelative^ do begin
				aKinType := typeOfKin;
				if kinOf <> pEgo then
					// partners of biological kins like aunts/uncles are classified as 'non-bio'
					aKinType := kt_nonBio;

				if (SelectAllKinsBorn) then begin
					if g_GENPARAM.outputs_opt[res_kin_totalNumbers].value then begin
						InterlockedIncrement (g_TotalBornKinship[ord(aKinType), ord(sexT_Ego), kTotal-kTotal]);
						InterlockedIncrement (g_TotalBornKinship[ord(aKinType), ord(all), kTotal-kTotal]);
					end;
					Inc (nBornKins_total[sexT_Ego, aKinType]);
					Inc (nBornKins_total[all, aKinType]);
				end;
			
				// ageBirthRef is age of ego at birth of relative or 0 if the relative is born before ego
				ageBirthRef := max (0, - ageAtBirthOfEgo);
				// ageDeathRef is age of ego at death of relative or age at death ƒof ego if the relative died after
				ageDeathRef := min (ageDeathEgo, trunc (ageDeath - ageAtBirthOfEgo));
				if (ageDeathRef >= 0) and (ageBirthRef <= ageDeathRef) then begin
					if (typeOfKin <> kt_partner) then begin
	 					for a := ageBirthRef to ageDeathRef do begin
								InterlockedIncrement (numKinsByAgeEgo[sexT_Ego, a, aKinType]);
								InterlockedIncrement (numKinsByAgeEgo[all, a, aKinType]);
						end;
				   	end else begin
						for a := ageBirthRef to ageDeathRef do begin
							ageUnionStatus := currPartner (pRelative, a);
							if ageUnionStatus = su_inUnion then begin
								InterlockedIncrement (numKinsByAgeEgo[sexT_Ego, a, aKinType]);
								InterlockedIncrement (numKinsByAgeEgo[all, a, aKinType]);
							end else if ageUnionStatus = su_after then
								break;
						end;
					end;
				end;
			end;
			pRelative := pRelative^.nextRelative;
		end;
		
		ageEgoInd := -1;
		for ageEgo in sa do begin
			ageEgoInd := ageEgoInd + 1;
			InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, sexT_Ego, born, kt_ego, ageEgo]);
			InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, all, born, kt_ego, ageEgo]);
			if pEgo^.ageDeath >= ageEgo then
			begin
				// add ego to living kins count
				Inc (nBornKins [ageEgoInd, sexT_Ego, kt_ego]);
				Inc (nBornKins [ageEgoInd, all, kt_ego]);
				Inc (nLivingKins [ageEgoInd, sexT_Ego, kt_ego]);
				Inc (nLivingKins [ageEgoInd, all, kt_ego]);
				InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, sexT_Ego, alive, kt_ego, ageEgo]);
				InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, all, alive, kt_ego, ageEgo]);
				
				pRelative := pEgo^.nextRelative;
				while (pRelative <> nil) do begin
					with pRelative^ do begin
						aKinType := typeOfKin;
						if kinOf <> pEgo then
							// partners of biological kins like aunts/uncles are classified as 'non-bio'
							aKinType := kt_nonBio;
							
						ageRef := ageAtBirthOfEgo + ageEgo;
						
						// We have two different options to select birth of kins:
						// 1. Only the kins which are born at current age of ego and possibly still alive
						SelectKinsBornAndPossiblyAlive := (ageRef >= kMinAgeLife) and (ageRef <= kMaxAgeLife);
						// 2. Or all the birth of kins, regardless of their ages or whether they are alive during ego's life
						SelectAllKinsBorn := true;
						
						if (typeOfKin = kt_partner) and not (currPartner (pRelative, ageRef) = su_inUnion) then begin
							// if the partner is not currently in union with ego or a biological kin
							// she/he should not be added to the count of living kins
							// but we add her/him to the count of born kins
							if (SelectKinsBornAndPossiblyAlive) then begin
								InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, sexT_Ego, born, aKinType, ageRef]);
								InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, all, born, aKinType, ageRef]);
							end;

							pRelative := pRelative^.nextRelative;
							continue;
						end;

						if (SelectAllKinsBorn) then begin						
							Inc (nBornKins [ageEgoInd, sexT_Ego, aKinType]);
							Inc (nBornKins [ageEgoInd, all, aKinType]);
						end;

						if (SelectKinsBornAndPossiblyAlive) then
						begin
							InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, sexT_Ego, born, aKinType, ageRef]);
							InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, all, born, aKinType, ageRef]);
							if ((ageRef >= 0) and (ageRef <= ageDeath)) then begin
								Inc (nLivingKins [ageEgoInd, sexT_Ego, aKinType]);
								Inc (nLivingKins [ageEgoInd, all, aKinType]);
								InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, sexT_Ego, alive, aKinType, ageRef]);
								InterlockedIncrement (tabKinshipAgeEgo[ageEgoInd, all, alive, aKinType, ageRef]);
							end;
						end;
					end;
					pRelative := pRelative^.nextRelative;
				end;
			end else {pEgo^.ageDeath >= ageEgo}
{$IFDEF DEBUG}
				if (ageEgo = 0) then
					ageEgoInd := ageEgoInd;
{$ENDIF}
		end; {ageEgo}

        setSex := [sexT_Ego, all];
		for aKinType := low (KinTypes) to high (KinTypes) do
			for sexT in setSex do begin
				numKins_born := min (kMaxNumRelatives_extended, nBornKins_total[sexT, aKinType]);
				if g_GENPARAM.outputs_opt[res_kin_totalNumbers].value then
					Inc (g_TotalBornKinship[ord(aKinType), ord(sexT), numKins_born-kTotal]);
			end;

		ageEgoInd := -1;
		for ageEgo in sa do begin
			ageEgoInd := ageEgoInd + 1;
			for aKinType := low (KinTypes) to high (KinTypes) do begin
				numKins_alive := min (kMaxNumRelatives, nLivingKins [ageEgoInd, all, aKinType]);
				g_distribKins [ageEgoInd, numKins_alive, aKinType] :=
					g_distribKins [ageEgoInd, numKins_alive, aKinType] + 1;
				if pEgo^.ageDeath >= ageEgo then begin
					numKins_alive := min (kMaxNumRelatives, nLivingKins [ageEgoInd, all, aKinType]);
					g_distribKins_SurvEgo [all, ageEgoInd, numKins_alive, aKinType] :=
						g_distribKins_SurvEgo [all, ageEgoInd, numKins_alive, aKinType] + 1;
					numKins_born := min (kMaxNumRelatives, nBornKins [ageEgoInd, all, aKinType]);
					g_distribBornKins_SurvEgo [all, ageEgoInd, numKins_born, aKinType] :=
						g_distribBornKins_SurvEgo [all, ageEgoInd, numKins_born, aKinType] + 1;
					if pEgo^.gender = man then begin
						numKins_alive := min (kMaxNumRelatives, nLivingKins [ageEgoInd, men, aKinType]);
						g_distribKins_SurvEgo [men, ageEgoInd, numKins_alive, aKinType] :=
							g_distribKins_SurvEgo [men, ageEgoInd, numKins_alive, aKinType] + 1;
						numKins_born := min (kMaxNumRelatives, nBornKins [ageEgoInd, men, aKinType]);
						g_distribBornKins_SurvEgo [men, ageEgoInd, numKins_born, aKinType] :=
							g_distribBornKins_SurvEgo [men, ageEgoInd, numKins_born, aKinType] + 1;
					end else begin
						numKins_alive := min (kMaxNumRelatives, nLivingKins [ageEgoInd, women, aKinType]);
						g_distribKins_SurvEgo [women, ageEgoInd, numKins_alive, aKinType] :=
							g_distribKins_SurvEgo [women, ageEgoInd, numKins_alive, aKinType] + 1;
						numKins_born := min (kMaxNumRelatives, nBornKins [ageEgoInd, women, aKinType]);
						g_distribBornKins_SurvEgo [women, ageEgoInd, numKins_born, aKinType] :=
							g_distribBornKins_SurvEgo [women, ageEgoInd, numKins_born, aKinType] + 1;
					end;
				end;
			end;
		end;
	end;
	
	// simulate the kinship of one ego
	function simulKinship (	randomGenerator: TRandomNumberGenerator;
                            yearOfBirthEgo: longint;
							arrayChildren: arrayOfInfoChild;
							var nbTotRelatives: longint ): pRelativeType;
	var
		pEgo: pRelativeType;

	begin
		result := nil;
		
		pEgo := initKinshipTree(nbTotRelatives);
		pEgo^.dateBirth.yearBirth := yearOfBirthEgo;
		destiny(randomGenerator, kt_ego, pEgo);
{$IFDEF VerboseProfiler} timeProfile_start_proc('calcKinship'); {$ENDIF}
		calcKinship(randomGenerator, pEgo, arrayChildren, nbTotRelatives, gKinsToSimulate);
{$IFDEF VerboseProfiler} timeProfile_end_proc('calcKinship'); {$ENDIF}

		result := pEgo;
	end;
	
	Constructor TSimulEgoTree.Create(pData: pEgoTreeData; ind: longint; maxNumTrees: longint);
	begin
		FreeOnTerminate := false; // we will free it ourself
		FAFinished := false;
		myExecuteIt := false; // this is the signal for real execution in procedure Execute
		myThreadNumber := ind;
		pMyData := pData;
		setLength (pMyEgos, maxNumTrees);
		CreateArrayChildren(arrayChildren);
		myNumTreesStored := 0;
		myRandomGenerator := TRandomNumberGenerator.Create (g_GENPARAM.INIT_RANDOM_NUMBERS.value);
		inherited Create(false); // we will start real execution all by ourselves, so start the Execute now!
	end;

	Destructor TSimulEgoTree.Destroy();
	var
		ind: longint;
	begin
		self.InitTrees (0);
		DestroyArrayChildren(arrayChildren);
		myRandomGenerator.Destroy();
		inherited Destroy;
	end;

	procedure TSimulEgoTree.InitTrees (num: longint);
	var
		ind: longint;
	begin
		for ind := 0 to myNumTreesStored - 1 do
			disposeKinship(pMyEgos[ind]);
		if (num > length (pMyEgos)) or (num = 0) then begin
			setLength (pMyEgos, num);
		end;
	end;
	
	procedure TSimulEgoTree.Terminate;
	begin
		// we have this in order to check in the debugger whether or not this procedure was correctly called,
		// even if we are computing in Execute
		inherited Terminate;
	end;
	
	function TSimulEgoTree.Simulate(numEgos: longint): boolean;
	begin
		result := false;
		if numEgos = 0 then begin
			FAFinished := true;
			result := true;
			exit;
		end;
		if FAFinished then begin
			myExecuteIt := true;
			FAFinished := false;
			myNumTreesStored := numEgos;
			result := true;
		end;
	end;
	
	procedure TSimulEgoTree.Execute;
	var
		ind: longint;
	begin
		FAFinished := true;
		while not terminated do begin // we end the thread calling procedure Terminate of this object
			if myExecuteIt then begin // this is the signal to start computing
 				myExecuteIt := false;
				myTotalKinCount := 0;
				self.initTrees (myNumTreesStored);
				for ind := 0 to myNumTreesStored - 1 do begin
					pMyEgos [ind] := simulKinship (myRandomGenerator, pMyData^.yearOfBirthEgo, arrayChildren, myTotalKinCount);
				end;
           		FAFinished := true;
			end;
 		end;
	end;
	
	function TSimulEgoTree.UpdateKinNumber (offsetNumber: longint): boolean;
	var
		pRelative: pRelativeType;
		ind, numRelatives: longint;
	begin
		result := false;
		if not FAFinished then exit;
		for ind := 0 to myNumTreesStored - 1 do begin
			pRelative := pMyEgos [ind];
			numRelatives := 1;
			while pRelative <> nil do begin
				Inc (numRelatives);
				pRelative^.indNumber := pRelative^.indNumber + offsetNumber;
				pRelative := pRelative^.nextRelative;
			end;
			offsetNumber := offsetNumber + numRelatives;
		end;
		result := true;
	end;

	function TSimulEgoTree.meanNumberOfKins: double;
	begin
		if myNumTreesStored > 0 then
			result := myTotalKinCount / myNumTreesStored
		else
			result := 0;
	end;

	procedure writeAgeFatherAgeSon;
	begin
		 if not g_GENPARAM.outputs_opt[res_kin_fathers_son].value then exit;
{age father, age child}
		bWriteLn (gOutFileKin, ['### Interesting relative ages of fathers and sons' +
				' (option ' + g_GENPARAM.outputs_opt[res_kin_fathers_son].name + ')']);

		if gAgeFatherAgeSon[numberCases] > 0.0 then
			begin
				gAgeFatherAgeSon[ageAtBirthFirst] := trunc (gAgeFatherAgeSon[ageAtBirthFirst] / gAgeFatherAgeSon[numberCases]);
				gAgeFatherAgeSon[ageAtBirthLast] := trunc (gAgeFatherAgeSon[ageAtBirthLast] / gAgeFatherAgeSon[numberCases]);
				gAgeFatherAgeSon[ageDeathFather] := trunc (gAgeFatherAgeSon[ageDeathFather] / gAgeFatherAgeSon[numberCases]);
				gAgeFatherAgeSon[ageAtUnionFirstChild] := trunc (gAgeFatherAgeSon[ageAtUnionFirstChild] / gAgeFatherAgeSon[numberCases]);
				gAgeFatherAgeSon[ageAtUnionLastChild] := trunc (gAgeFatherAgeSon[ageAtUnionLastChild] / gAgeFatherAgeSon[numberCases]);
				stdWriteLn([nbCases, gAgeFatherAgeSon[numberCases]]);
				stdWriteLn([fatherAatBofFirstSonToEnterUnion,
				gAgeFatherAgeSon[ageAtBirthFirst]]);
				stdWriteLn([fatherAatDwithAtleastOneSonToEnterUnion,
				gAgeFatherAgeSon[ageDeathFather]]);
				stdWriteLn([AoMFirstSonToEnterUnion,
				gAgeFatherAgeSon[ageAtUnionFirstChild]]);
				bWriteLn(gOutFileKin, [nbCases, tab, gAgeFatherAgeSon[numberCases]]);
				bWriteLn(gOutFileKin, [fatherAatBofFirstSonToEnterUnion, tab, gAgeFatherAgeSon[ageAtBirthFirst]]);
				bWriteLn(gOutFileKin, [fatherAatBofLastSonToEnterUnion, tab, gAgeFatherAgeSon[ageAtBirthLast]]);
				bWriteLn(gOutFileKin, [fatherAatDwithAtleastOneSonToEnterUnion, tab, gAgeFatherAgeSon[ageDeathFather]]);
				bWriteLn(gOutFileKin, [AatMFirstSonToEnterUnion, tab, gAgeFatherAgeSon[ageAtUnionFirstChild]]);
				bWriteLn(gOutFileKin, [AatMLastSonToEnterUnion, tab, gAgeFatherAgeSon[ageAtUnionLastChild]]);
			end;
	end;

	procedure survivalParents (randomGenerator: TRandomNumberGenerator; cohort: longint; writeAges, writeSurvival: boolean);
		var
			pDemReg: pStructDemographicRegimeSettings;
			ageSimpleEgo, ageFather, ageMother: agesLife;
			typeOfKin: KinTypes;
			individual, ind: longint;
			ageDiff: double;

			fatherMotherAgeDiff: array[kMinAgeLife..kMaxAgeLife, kt_father..kt_mother, 0..2] of double;
			LivingParents: array[kMinAgeLife..kMaxAgeLife, 0..2] of double;

	begin
		pDemReg := getCohort_p(cohort);
		
		if writeAges then
			begin
				gAgeFatherAgeSon[ageAtBirthFirst] := 0;
				gAgeFatherAgeSon[ageDeathFather] := 0;
				gAgeFatherAgeSon[ageAtUnionFirstChild] := 0;
				gAgeFatherAgeSon[numberCases] := 0;
			end;

		screenFileWriteLn(ParentsSurvival);
		for ageSimpleEgo := kMinAgeLife to kMaxAgeLife do
			begin
				stdWriteLn([EgoAge, ageSimpleEgo]);
				for ind := 0 to 2 do
					begin
						LivingParents[ageSimpleEgo, ind] := 0.0;
						for typeOfKin := kt_father to kt_mother do
							fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, ind] := 0.0;
					end;
				for individual := 1 to pDemReg^.lp[nEgoPar].value do
					begin
						ind := 0;
						simulFatherMother(randomGenerator, ageSimpleEgo, ageFather, ageMother);
						if ageFather > 0 then
							begin
								ind := ind + 1;
								ageDiff := ageFather - ageSimpleEgo;
								fatherMotherAgeDiff[ageSimpleEgo, kt_father, 0] := fatherMotherAgeDiff[ageSimpleEgo, kt_father, 0] + 1;
								fatherMotherAgeDiff[ageSimpleEgo, kt_father, 1] := fatherMotherAgeDiff[ageSimpleEgo, kt_father, 1] + ageDiff;
								fatherMotherAgeDiff[ageSimpleEgo, kt_father, 2] := fatherMotherAgeDiff[ageSimpleEgo, kt_father, 2] + ageDiff * ageDiff;
							end;
						if ageMother > 0 then
							begin
								ind := ind + 1;
								ageDiff := ageMother - ageSimpleEgo;
								fatherMotherAgeDiff[ageSimpleEgo, kt_mother, 0] := fatherMotherAgeDiff[ageSimpleEgo, kt_mother, 0] + 1;
								fatherMotherAgeDiff[ageSimpleEgo, kt_mother, 1] := fatherMotherAgeDiff[ageSimpleEgo, kt_mother, 1] + ageDiff;
								fatherMotherAgeDiff[ageSimpleEgo, kt_mother, 2] := fatherMotherAgeDiff[ageSimpleEgo, kt_mother, 2] + ageDiff * ageDiff;
							end;
						LivingParents[ageSimpleEgo, ind] := LivingParents[ageSimpleEgo, ind] + 1;
					end; {for individual := 1 to pDemReg^.lp[nEgoPar].value do}
				for typeOfKin := kt_father to kt_mother do
					begin
						if fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 0] > 0 then
							begin
								fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 1] := fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 1] / fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 0];
								fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 2] := sqrt(fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 2] / fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 0] - fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 1] * fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 1]);
								fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 0] := fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 0] / pDemReg^.lp[nEgoPar].value;
							end;
					end; {for typeOfKin := kt_father to kt_mother do}
				LivingParents[ageSimpleEgo, ind] := LivingParents[ageSimpleEgo, ind] / pDemReg^.lp[nEgoPar].value;
			end; {for ageSimpleEgo := kMinAgeLife to kMaxAgeLife do}

		if writeAges then
			writeAgeFatherAgeSon;

		if writeSurvival then
			begin
				cWriteLn(gOutFileKin, '### Statistics on kins');
				for typeOfKin := kt_father to kt_mother do
					begin
						bWriteLn(gOutFileKin, [str_kinship[typeOfKin], tab, meanNumber, tab, meanAgeDev, tab, sqAgeDev]);
						for ageSimpleEgo := kMinAgeLife to kMaxAgeLife do
							bWriteLn(gOutFileKin, [ageSimpleEgo, tab,
								fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 0], tab,
								fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 1], tab,
								fatherMotherAgeDiff[ageSimpleEgo, typeOfKin, 2]]);
					end;
				bWriteLn(gOutFileKin, [noLivRel, tab, oneLivRel, twoLivRel]);
				for ageSimpleEgo := kMinAgeLife to kMaxAgeLife do
					begin
						for ind := 0 to 2 do
							bWrite(gOutFileKin, [LivingParents[ageSimpleEgo, ind]]);
						cWriteLn(gOutFileKin);
					end;
			end;
	end;

	procedure writeTables (writeInfo: boolean);
	var
		ageEgoInd: longint;
		ageEgo: agesLife;
		age: longint;
		nbTotRelatives, nbRelatives, nbRelativesAge, nbRelativesBorn, nbRelativesBornAge: longint;
		ind: longint;
		typeOfKin: KinTypes;
		ageDiff: double;

		nEgos: array [SexTotal] of longint;
		aSexT: SexTotal;
		nbRelatives_calc: double = 0;
		tempDouble: double;
		relativeSet: kinSetType;
		
		outputTab: array of TVarRec;
		outputTabString: array of ShortString;
		lenOutputTab: longint;

	begin
		for ageEgo := kMinAgeLife to kMaxAgeLife do begin
			for aSexT := men to all do begin
				for typeOfKin in gKinsToSimulate do begin
					g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, kt_total] :=
						g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, kt_total] +
						g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, typeOfKin];
				end;
			end;
		end;

		ageEgoInd := -1;
		for ageEgo in kSetAgesEgo do
		begin
			ageEgoInd := ageEgoInd + 1;
			for typeOfKin in gKinsToSimulate do begin
				for aSexT := men to all do begin
					// total of each kin type for each reference age of ego
					for age := kMinAgeLife to kMaxAgeLife do begin
						gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, kMaxAgeLife + 1] :=
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, kMaxAgeLife + 1] +
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, age];
						gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, born, typeOfKin, kMaxAgeLife + 1] :=
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, born, typeOfKin, kMaxAgeLife + 1] +
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, born, typeOfKin, age];
					end;
					// total of kins for each age of life
					for age := kMinAgeLife to kMaxAgeLife + 1 do begin
						gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, kt_total, age] :=
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, kt_total, age] +
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, age];
						gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, born, kt_total, age] :=
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, born, kt_total, age] +
							gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, born, typeOfKin, age];
					end;
				end;
			end; {typeOfKin}

			for aSexT := low(SexTotal) to high(SexTotal) do begin
    			nEgos[aSexT] := gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, kt_ego, ageEgo];
				for typeOfKin := kFirstKinInEnum to kLastKinInEnum do
				begin
					for age := kMinAgeLife to kMaxAgeLife do
					begin
						nbRelativesAge := gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, age];
						if nbRelativesAge > 0 then
						begin
							ageDiff := age - ageEgo;
							g_momEcAge[aSexT, ageEgoInd, typeOfKin, number] := g_momEcAge[aSexT, ageEgoInd, typeOfKin, number] + nbRelativesAge;
							g_momEcAge[aSexT, ageEgoInd, typeOfKin, value] := g_momEcAge[aSexT, ageEgoInd, typeOfKin, value] + ageDiff * nbRelativesAge;
							g_momEcAge[aSexT, ageEgoInd, typeOfKin, valueSquared] := g_momEcAge[aSexT, ageEgoInd, typeOfKin, valueSquared] + ageDiff * ageDiff * nbRelativesAge;
						end; {if nbRelativesAge > 0 then}
					end; {for age := kMinAgeLife to kMaxAgeLife do}
				end; {for typeOfKin := kFirstKinInEnum to grandChild do}
			end; {sexT}

			for aSexT := low(SexTotal) to high(SexTotal) do begin
				for typeOfKin := kFirstKinInEnum to kLastKinInEnum do
				begin
					if g_momEcAge[aSexT, ageEgoInd, typeOfKin, number] > 0 then
					begin
						g_momEcAge[aSexT, ageEgoInd, typeOfKin, value] := g_momEcAge[aSexT, ageEgoInd, typeOfKin, value] / g_momEcAge[aSexT, ageEgoInd, typeOfKin, number];
						tempDouble := g_momEcAge[aSexT, ageEgoInd, typeOfKin, valueSquared] /
													g_momEcAge[aSexT, ageEgoInd, typeOfKin, number] -
													g_momEcAge[aSexT, ageEgoInd, typeOfKin, value] *
													g_momEcAge[aSexT, ageEgoInd, typeOfKin, value];
												
						if tempDouble > 0 then
							g_momEcAge[aSexT, ageEgoInd, typeOfKin, valueSquared] := sqrt(tempDouble)
						else
							g_momEcAge[aSexT, ageEgoInd, typeOfKin, valueSquared] := 0;
						
						g_momEcAge[aSexT, ageEgoInd, typeOfKin, number] := g_momEcAge[aSexT, ageEgoInd, typeOfKin, number] / nEgos[aSexT];
					end;
				end; {typeOfKin}
			end; {sexT}

			for typeOfKin := kFirstKinInEnum to kt_nonBio do
				for nbRelatives := 0 to kMaxNumRelatives do begin
					g_distribKins[ageEgoInd, nbRelatives, kt_total] :=
						g_distribKins[ageEgoInd, nbRelatives, kt_total] + 
						g_distribKins[ageEgoInd, nbRelatives, typeOfKin];
					for aSexT := low (SexTotal) to high (SexTotal) do begin
						g_distribKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, kt_total] :=
							g_distribKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, kt_total] + 
							g_distribKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, typeOfKin];
						g_distribBornKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, kt_total] :=
							g_distribBornKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, kt_total] + 
							g_distribBornKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, typeOfKin];
					end;
				end;
		end; {ageEgo}

		{moments of the distribution of surviving relatives according to ego age}
		if writeInfo and g_GENPARAM.outputs_opt[res_kin_stats].value then
        begin
			fileScreenWriteLn(gOutFileKin, ['### Statistics on kins' +
								 ' (option ' + g_GENPARAM.outputs_opt[res_kin_stats].name + ')']);
			for aSexT := low(SexTotal) to high(SexTotal) do
            begin
				fileScreenWriteLn(gOutFileKin, ['===> ', sSexTotal [aSexT]]);
				for typeOfKin := kt_ego to kt_total do
				begin
					if typeOfKin in gKinsToSimulate then begin
						fileScreenWriteLn(gOutFileKin, [str_kinship[typeOfKin], tab, meanNumber, tab,
								meanAgeDev, tab, sqAgeDev]);
						ageEgoInd := -1;
						for ageEgo in kSetAgesEgo do
						begin
							ageEgoInd := ageEgoInd + 1;
							fileScreenWriteLn(gOutFileKin, [ageEgo, tab,
								g_momEcAge[aSexT, ageEgoInd, typeOfKin, number], tab,
								g_momEcAge[aSexT, ageEgoInd, typeOfKin, value], tab,
								g_momEcAge[aSexT, ageEgoInd, typeOfKin, valueSquared]]);
						end;
					end;
				end;
			end; {aSexT}
		end;

		{age father, age child}
		writeAgeFatherAgeSon;

		{distribution of the size of total and surviving kinship groups according to ego age}
		if writeInfo and g_GENPARAM.outputs_opt[res_kin_dist].value then begin
			bWriteLn (gOutFileKin, ['### Distribution of living kin numbers for all egos, alive or dead, by ego''s age' +
					' (option ' + g_GENPARAM.outputs_opt[res_kin_dist].name + ')']);
			for typeOfKin := kt_ego to kt_total do
			begin
				if typeOfKin in gKinsToSimulate then begin
					bWrite(gOutFileKin, [nOf, str_kinship[typeOfKin]]);
					for ageEgo in kSetAgesEgo do
						bWrite(gOutFileKin, [tab, ageEgo]);
					cWriteLn(gOutFileKin);
					for nbRelatives := 0 to kMaxNumRelatives do
					begin
						bWrite(gOutFileKin, [nbRelatives]);
						for ageEgoInd := 0 to kMaxNbAgeEgo do
						begin
							bWrite(gOutFileKin, [tab, FloatToStrF (g_distribKins[ageEgoInd, nbRelatives, typeOfKin], ffFixed, 6, 0)]);
						end;
						cWriteLn(gOutFileKin);
					end; {for nbRelatives := 0 to kMaxNumRelatives do}
				end;
			end; {typeOfKin}
			
			cWriteLn (gOutFileKin, '### Distribution of living kin numbers for surviving egos, by ego''s age and sex');
			for aSexT := low(SexTotal) to high(SexTotal) do begin
				bWriteLn (gOutFileKin, ['===> ', sSexTotal [aSexT]]);
				for typeOfKin := kt_ego to kt_total do
				begin
					if typeOfKin in gKinsToSimulate then begin
						bWrite(gOutFileKin, [nOf, str_kinship[typeOfKin]]);
						for ageEgo in kSetAgesEgo do
							bWrite(gOutFileKin, [tab, ageEgo]);
						cWriteLn(gOutFileKin);
						for nbRelatives := 0 to kMaxNumRelatives do
						begin
							bWrite(gOutFileKin, [nbRelatives]);
							for ageEgoInd := 0 to kMaxNbAgeEgo do
							begin
								bWrite(gOutFileKin, [tab, FloatToStrF (g_distribKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, typeOfKin], ffFixed, 6, 0)]);
							end;
							cWriteLn(gOutFileKin);
						end; {for nbRelatives := 0 to kMaxNumRelatives do}
					end;
				end; {typeOfKin}
			end; {aSexT}

			cWriteLn (gOutFileKin, '### Distribution of born kin numbers for surviving egos, by ego''s age and sex');
			for aSexT := low(SexTotal) to high(SexTotal) do begin
				bWriteLn (gOutFileKin, ['===> ', sSexTotal [aSexT]]);
				for typeOfKin := kt_ego to kt_total do
				begin
					if typeOfKin in gKinsToSimulate then begin
						bWrite(gOutFileKin, [nOf, str_kinship[typeOfKin]]);
						for ageEgo in kSetAgesEgo do
							bWrite(gOutFileKin, [tab, ageEgo]);
						cWriteLn(gOutFileKin);
						for nbRelatives := 0 to kMaxNumRelatives do
						begin
							bWrite(gOutFileKin, [nbRelatives]);
							for ageEgoInd := 0 to kMaxNbAgeEgo do
							begin
								bWrite(gOutFileKin, [tab, FloatToStrF (g_distribBornKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, typeOfKin], ffFixed, 6, 0)]);
							end;
							cWriteLn(gOutFileKin);
						end; {for nbRelatives := 0 to kMaxNumRelatives do}
					end;
				end; {for typeOfKin := kt_father to kt_total do}
			end; {aSexT}
		end; {g_GENPARAM.outputs_opt[res_kin_dist]}

		if writeInfo and g_GENPARAM.outputs_opt[res_kin_reldist].value then begin
			bWriteLn (gOutFileKin, ['### Relative distribution of living kin numbers for surviving egos, by ego''s age' +
				 ' (option ' + g_GENPARAM.outputs_opt[res_kin_reldist].name + ')']);
				 
			for aSexT := low(SexTotal) to high(SexTotal) do begin
				bWriteLn (gOutFileKin, ['===> ', sSexTotal [aSexT]]);
				for typeOfKin := kt_partner to kt_total do
				begin
					if typeOfKin in gKinsToSimulate then begin
						bWrite(gOutFileKin, [nOf, str_kinship[typeOfKin]]);
						for ageEgo in kSetAgesEgo do
							bWrite(gOutFileKin, [tab, ageEgo]);
						cWriteLn(gOutFileKin);
						for nbRelatives := 0 to kMaxNumRelatives do
						begin
							bWrite(gOutFileKin, [nbRelatives]);
							for ageEgoInd := 0 to kMaxNbAgeEgo do
							begin
                                if (g_distribKins_SurvEgo[aSexT, ageEgoInd, 1, kt_ego] > 0) then
									bWrite(gOutFileKin, [tab,
										g_distribKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, typeOfKin] /
										g_distribKins_SurvEgo[aSexT, ageEgoInd, 1, kt_ego]])
                                else
                                    bWrite (gOutFileKin, [tab, 0.0]);
							end;
							cWriteLn(gOutFileKin);
						end; {for nbRelatives := 0 to kMaxNumRelatives do}
					end;
				end; {for typeOfKin := kt_father to kt_total do}
			end; {aSexT}
			
			bWriteLn (gOutFileKin, ['### Relative distribution of kins born among surviving egos, by ego''s age' +
				 ' (option ' + g_GENPARAM.outputs_opt[res_kin_reldist].name + ')']);
				 
			for aSexT := low(SexTotal) to high(SexTotal) do begin
				bWriteLn (gOutFileKin, ['===> ', sSexTotal [aSexT]]);
				for typeOfKin := kt_partner to kt_total do
				begin
					if typeOfKin in gKinsToSimulate then begin
						bWrite(gOutFileKin, [nOf, str_kinship[typeOfKin]]);
						for ageEgo in kSetAgesEgo do
							bWrite(gOutFileKin, [tab, ageEgo]);
						cWriteLn(gOutFileKin);
						for nbRelatives := 0 to kMaxNumRelatives do
						begin
							bWrite(gOutFileKin, [nbRelatives]);
							for ageEgoInd := 0 to kMaxNbAgeEgo do
							begin
								if (g_distribBornKins_SurvEgo[aSexT, ageEgoInd, 1, kt_ego] > 0) then begin
									bWrite(gOutFileKin, [tab,
										g_distribBornKins_SurvEgo[aSexT, ageEgoInd, nbRelatives, typeOfKin] /
										g_distribBornKins_SurvEgo[aSexT, ageEgoInd, 1, kt_ego]]);
								end else bWrite(gOutFileKin, [tab, 0.0]);
							end;
							cWriteLn(gOutFileKin);
						end; {for nbRelatives := 0 to kMaxNumRelatives do}
					end;
				end; {for typeOfKin := kt_father to kt_total do}
			end {aSexT}
		end; {g_GENPARAM.outputs_opt[res_kin_reldist]}
		
		{age distribution of surviving ego's relatives}
		if writeInfo and g_GENPARAM.outputs_opt[res_kin_agedist].value then begin
			bWriteLn (gOutFileKin, ['### Age distribution of surviving ego''s relatives' +
				' (option ' + g_GENPARAM.outputs_opt[res_kin_agedist].name + ')']);
			for aSexT := men to all do
			begin
				bWriteLn(gOutFileKin, ['### Number of biological kins of surviving ', aSexT]);

				for typeOfKin := kt_ego to kt_total do
				begin
					if typeOfKin in gKinsToSimulate then begin
						bWrite(gOutFileKin, ['age of ', str_kinship[typeOfKin]]);
						for ageEgo in kSetAgesEgo do
							bWrite(gOutFileKin, [tab, ageEgo]);
						cWriteLn(gOutFileKin);
						for age := kMinAgeLife to kMaxAgeLife do
						begin
							bWrite(gOutFileKin, [age]);
							for ageEgoInd := 0 to kMaxNbAgeEgo do
							begin
								bWrite(gOutFileKin, [tab, gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, age]]);
							end;
							cWriteLn(gOutFileKin);						
						end; {for age := kMinAgeLife to kMaxAgeLife do}
						cWrite(gOutFileKin, 'Total ');
						for ageEgoInd := 0 to kMaxNbAgeEgo do
						begin
							bWrite(gOutFileKin, [tab, gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd, aSexT, alive, typeOfKin, kMaxAgeLife + 1]]);
						end;
						cWriteLn(gOutFileKin);
					end;
				end; {for typeOfKin := kt_father to kt_grandChild do}

			end;
		end; {g_GENPARAM.outputs_opt[res_kin_agedist]}
		
		{Number of kins by age of ego}
		if writeInfo and g_GENPARAM.outputs_opt[res_kin_numByAge].value then begin
			bWriteLn (gOutFileKin, ['### Absolute numbers of kins by age of ego' +
				' (option ' + g_GENPARAM.outputs_opt[res_kin_numByAge].name + ')']);
			for aSexT := men to all do begin
				bWriteLn (gOutFileKin, ['For: ', aSexT]);
				bWrite (gOutFileKin, ['Age', tab]);
				for typeOfKin := kt_ego to kt_total do
					if typeOfKin in gKinsToSimulate then
						bWrite (gOutFileKin, [str_kinship[typeOfKin], tab]);
				cWriteLn (gOutFileKin);
				for ageEgo := kMinAgeLife to kMaxAgeLife do begin
					bWrite (gOutFileKin, [ageEgo, tab]);
					for typeOfKin := kt_ego to kt_total do
						if typeOfKin in gKinsToSimulate then
							bWrite (gOutFileKin, [g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, typeOfKin], tab]);
					cWriteLn (gOutFileKin);
				end;
			end;
			bWriteLn (gOutFileKin, ['### Mean number of kins by age of ego' +
				' (option ' + g_GENPARAM.outputs_opt[res_kin_numByAge].name + ')']);
			for aSexT := men to all do begin
				bWriteLn (gOutFileKin, ['For: ', aSexT]);
				bWrite (gOutFileKin, ['Age', tab]);
				for typeOfKin := kt_partner to kt_total do
					if typeOfKin in gKinsToSimulate then
						bWrite (gOutFileKin, [str_kinship[typeOfKin], tab]);
				cWriteLn (gOutFileKin);
				for ageEgo := kMinAgeLife to kMaxAgeLife do begin
					bWrite (gOutFileKin, [ageEgo, tab]);
					for typeOfKin := kt_partner to kt_total do
						if typeOfKin in gKinsToSimulate then begin
							if g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, kt_ego] > 0 then
								bWrite (gOutFileKin,
									[g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, typeOfKin] /
										g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1, aSexT, ageEgo, kt_ego]
									, tab])
							else
								bWrite (gOutFileKin, [0.0, tab]);
						end;
					cWriteLn (gOutFileKin);
				end;
			end;
		end; {g_GENPARAM.outputs_opt[res_kin_numByAge]}
		
		{born kinship}
		if writeInfo and g_GENPARAM.outputs_opt[res_kin_totalNumbers].value then begin
			lenOutputTab := (kMaxNumRelatives_extended + 1 + 2) * 2 - 1;
			SetLength (outputTab{%H-}, lenOutputTab);
			SetLength (outputTabString{%H-}, lenOutputTab);
			for ind := 0 to lenOutputTab - 1 do begin
				if (odd (ind)) then begin
					outputTab [ind].vtype := vtChar;
					outputTab [ind].vChar := tab;
				end else begin
					outputTab [ind].vtype := vtString;
					outputTab [ind].vString := @outputTabString [ind];
				end;
			end;
			outputTabString [0] := 'Kin' + copy(gBlanks, 1, 9);
			outputTabString [1] := tab;
			outputTabString [2] := ' Mean';
			outputTabString [3] := tab;
			for nbRelatives := 0 to kMaxNumRelatives_extended do begin
				if nbRelatives < 10 then
					outputTabString [4 + nbRelatives * 2] := copy(gBlanks, 1, 6) + IntToStr(nbRelatives)
				else
					outputTabString [4 + nbRelatives * 2] := copy(gBlanks, 1, 5) + IntToStr(nbRelatives);
				if (nbRelatives < kMaxNumRelatives_extended) then
					outputTabString [4 + nbRelatives * 2 + 1] := tab;
			end;

			fileScreenWriteLn (gOutFileKin, ['### Mean number and distribution of kins born, for all egos (alive or dead)']);
			fileScreenWriteLn (gOutFileKin, outputTab, col_header);

			for typeOfKin := kt_ego to kt_nonBio do
				if typeOfKin in gKinsToSimulate then
					for nbRelatives := kTotal to kMaxNumRelatives_extended do
						for aSexT := men to all do
							g_TotalBornKinship[ord(kt_total), ord(aSexT), nbRelatives-kTotal] :=
								g_TotalBornKinship[ord(kt_total), ord(aSexT), nbRelatives-kTotal] +
								g_TotalBornKinship[ord(typeOfKin), ord(aSexT), nbRelatives-kTotal];
		
			for aSexT := men to all do begin
				fileScreenWriteLn (gOutFileKin, ['===> ', sSexTotal [aSexT]]);
		
				for typeOfKin := kt_ego to kt_total do
				begin
					if (typeOfKin in gKinsToSimulate) then begin
						outputTabString [0] := str_kinship[typeOfKin];
						nbRelatives_calc := g_TotalBornKinship[ord(typeOfKin), ord(aSexT), kTotal-kTotal] / g_TotalBornKinship[ord(kt_ego), ord(aSexT), kTotal-kTotal];
						outputTabString [2] := FloatToStrF (nbRelatives_calc, fffixed, 6, 3);
						for nbRelatives := 0 to kMaxNumRelatives_extended do begin
							nbRelatives_calc := g_TotalBornKinship[ord(typeOfKin), ord(aSexT), nbRelatives-kTotal] / g_TotalBornKinship[ord(kt_ego), ord(aSexT), kTotal-kTotal];
							outputTabString [4 + nbRelatives * 2] := FloatToStrF (nbRelatives_calc, fffixed, 6, 3);
						end;
						fileScreenWriteLn (gOutFileKin, outputTab, col_table);
					end;
				end;
			end;
			SetLength (outputTab, 0);
			SetLength (outputTabString, 0);
		end;
	end;
	
	procedure header_democare;
	begin
		if RP.wKey then bWrite (gOutFileIndivKin, ['key', tab]);
		if RP.wKey then bWrite (gOutFileIndivKin_link, ['key', tab]);
		bWriteLn (gOutFileIndivKin_link, ['id', comma, 'idLink', comma, 'linkType', comma, 'idFamily']);
		if g_GENPARAM.DUMPALL.value then begin
			bWriteLn (gOutFileIndivKin, ['id', comma, 'sex', comma, 'age', comma, 'ageDef', comma,
			'status', comma, 'tickIn', comma, 'tickOut', comma, 'ego', comma, 'partnershipStatus',
			comma, 'cohort', comma, 'cohortRegDem', comma, 'relative', comma, 'byUnion',
			comma, 'ageAtTickZero', comma, 'nChildren']);
		end else begin
			bWriteLn (gOutFileIndivKin, ['id', comma, 'sex', comma, 'age', comma, 'ageDef', comma,
			'status', comma, 'tickIn', comma, 'tickOut', comma, 'ego']);
		end;
	end;
	
	procedure header_EgoGenealogy (sep: char=comma);
	begin
		if RP.wKey then bWrite (gOutFileIndivKin, ['nKey', sep]);
		
		bWrite (gOutFileIndivKin, 	['Family', sep, 'id', sep, 'kinOf', sep, 'kinType', sep, 'kinType_kinOf', sep, 'sex',
									sep, 'idEgo', sep, 'idFather', sep, 'idMother', sep, 'nUnion', sep, 'idPartners']);
									
		if fieldEnabled (fn_yBirth) then bWrite (gOutFileIndivKin, [sep, 'yBirth']);
		if fieldEnabled (fn_mBirth) then bWrite (gOutFileIndivKin, [sep, 'mBirth']);
		if fieldEnabled (fn_cmcBirth) then bWrite (gOutFileIndivKin, [sep, 'cmcBirth']);
		if fieldEnabled (fn_cmcDeath) then bWrite (gOutFileIndivKin, [sep, 'cmcDeath']);
		if fieldEnabled (fn_nChildren) then bWrite (gOutFileIndivKin, [sep, 'nChildren']);
		if fieldEnabled (fn_birthOrder) then bWrite (gOutFileIndivKin, [sep, 'birthOrder']);
		if fieldEnabled (fn_ageRelEgo) then bWrite (gOutFileIndivKin, [sep, 'ageRelEgo']);
		if fieldEnabled (fn_ageDeath) then bWrite (gOutFileIndivKin, [sep, 'ageDeath']);
		if fieldEnabled (fn_ageUnion) then bWrite (gOutFileIndivKin, [sep, 'ageUnion']);
		if fieldEnabled (fn_ageEndUnion) then bWrite (gOutFileIndivKin, [sep, 'ageEndUnion']);
		if fieldEnabled (fn_causeEnd) then bWrite (gOutFileIndivKin, [sep, 'causeEndUnion']);
		if fieldEnabled (fn_ageMotherAtChildbirth) then bWrite (gOutFileIndivKin, [sep, 'ageMotherAtChildbirth']);
		if fieldEnabled (fn_ageFatherAtChildbirth) then bWrite (gOutFileIndivKin, [sep, 'ageFatherAtChildbirth']);
		if fieldEnabled (fn_status) then bWrite (gOutFileIndivKin, [sep, 'status']);
		if fieldEnabled (fn_cohortDemReg) then bWrite (gOutFileIndivKin, [sep, 'cohortDemReg']);
		if fieldEnabled (fn_motherUnionNumber) then bWrite (gOutFileIndivKin, [sep, 'motherUnionNumber']);
		if fieldEnabled (fn_typeHeirs) then bWrite (gOutFileIndivKin, [sep, 'typeHeirs']);
		//if fieldEnabled (fn_egoAsHeir) then bWrite (gOutFileIndivKin, [sep, 'egoAsHeir']);
		if fieldEnabled (fn_heirs) then bWrite (gOutFileIndivKin, [sep, 'heirs']);
		if fieldEnabled (fn_inheritances) then bWrite (gOutFileIndivKin, [sep, 'inheritances']);
		if fieldEnabled (fn_shares) then bWrite (gOutFileIndivKin, [sep, 'shares']);
		if fieldEnabled (fn_isHeir) then bWrite (gOutFileIndivKin, [sep, 'isHeir']);
		
		bWriteLn (gOutFileIndivKin, []);
	end;

	procedure header_GEDCOM;
	begin
		if RP.wKey then bWrite (gOutFileIndivKin, ['key', tab]);		if RP.wKey then bWrite (gOutFileIndivKin_link, ['key', tab]);
	end;
	

	function individualKin_openFile (bootstrap_ind: longint; fileFormat: Kinship_FileFormat; var fname: string; openFile: boolean = true): KinSetType;
	const
		ftype_democare = '_indKin.txt';
		ftype_link_democare = '_indKin_link.txt';
		ftype_EgoGenealogy = '_EgoGenealogy.csv';
		ftype_GEDCOM = '.GEDCOM';
		
	var
		sNum: string;
		
		ftype, ftype_link: string;
		
	begin
		result := [kt_none];
		if not g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value then exit;

		if fileFormat = out_GEDCOM then begin
			stdWriteLn(['GEDCOM File Format not implemented -- Using EgoGenealogy instead']);
			fileFormat := out_EgoGenealogy;
		end;

		if ( g_GENPARAM.RUNTIME[gBootstrap_nRuns].value > 1 ) and g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value then
			sNum := '_' + IntToStr (bootstrap_ind)
		else
			sNum := '';
			
		if fileFormat = out_DemoCare then begin
			ftype := ftype_democare;
			ftype_link := ftype_link_democare;
		end else if fileFormat = out_EgoGenealogy then begin
			ftype := ftype_EgoGenealogy;
			ftype_link := '';
		end else if fileFormat = out_GEDCOM then begin
			ftype := ftype_GEDCOM;
			ftype_link := '';
		end;
		
		fname := g_FileName.value;
		fname := concat (fname, sNum, ftype);
		if openFile then begin 
			if ( not openFileOut(fname, 'gOUTFILEINDIVKIN', gOutFileIndivKin, kAsyncFalse) ) then
			begin
				screenFileWriteLn(concat('Problem opening file: ', fname));
				result := [kt_none];
				exit;
			end;
			if (fileFormat = out_DemoCare) then begin
				fname := g_FileName.value;
				fname := concat (fname, sNum, ftype_link);
				if ( not openFileOut(fname, 'gOUTFILEINDIVKIN_LINK', gOutFileIndivKin_link, kAsyncFalse) ) then
				begin
					screenFileWriteLn(concat('Problem opening file: ', fname));
					result := [kt_none];
					exit;
				end;
			end;
		end;
			
		if (fileFormat = out_DemoCare) then begin

			if openFile then header_democare;
			
			result := [kt_ego, kt_partner, kt_child, kt_grandChild];
			
		end else if fileFormat = out_EgoGenealogy then begin
		
			if openFile then header_EgoGenealogy;

			result := gKinsToSimulate;
			
		end else if fileFormat = out_GEDCOM then begin
		
			if openFile then header_GEDCOM;

			result := gKinsToSimulate;

		end;
	end {individualKin_openFile};

	function individualKin_init (bootstrap_ind: longint; fileFormat: Kinship_FileFormat; var fname: string; openFile: boolean = true): boolean;
	begin
		result := true;
		if not g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value then exit;
		result := false;
		gKinsToSimulate := individualKin_openFile(bootstrap_ind, fileFormat, fname, openFile);
		if (gKinsToSimulate = [kt_none]) then
			exit;
		stdWriteLn(['======================================================================']);
		stdWriteLn(['================== Writing individual genealogy file =================']);
		result := true;
	end;
	
	procedure individualKin_mid (indEgo, modEgo: longint; threadNum: longint; var stepEgos: longint);
	begin
		if not g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value then exit;
		while (indEgo >= stepEgos + modEgo) do begin
			stepEgos := stepEgos + modEgo;
			if (threadNum = 0) then
            	stdWriteLn([stepEgos, indivs])
            else
            	stdWriteLn([stepEgos, indivs, ' (Multithreaded)'])
		end;
		flushIO;
	end;

	procedure checkKinship (pRel: pRelativeType; nKinsInTree: longint);
	var
		nKins: longint = 0;
	begin
		while (pRel <> nil) do begin
			Inc (nKins);
			pRel := pRel^.nextRelative;
		end;
		if nKins <> nKinsInTree then
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(true);
{$ENDIF}
	end;
	
	procedure individualKin_end (fileFormat: Kinship_FileFormat; nbFamily, nIndividuals: longint; fname: string);
	var
		tStart, tEnd, tDiff: TDateTime;  // Begin and end of measurement, and difference
		iHours, iMinutes, iSeconds, iMilliseconds: Word;  // Time components

	begin
		if not g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value then exit;

		gOutFileIndivKin.finished;
		if (fileFormat = out_DemoCare) then
			gOutFileIndivKin_link.finished;
		stdWriteLn(['========== Num families written: ', nbFamily, ', num individuals: ', nIndividuals, ' ==========']);
		stdWriteLn(['======================================================================']);

		if (g_GENPARAM.ZIP_INDIVIDUAL.value) then
		begin
			tStart := Now();
			stdWriteLn( ['zipping genealogies file...'] );
			zipIt (gPathToResult + fname);
			tEnd := Now();
			tDiff:= tEnd - tStart;  // Subtract higher from lower value
			DecodeTime( tDiff, iHours, iMinutes, iSeconds, iMilliseconds );  // Does not account for day changes when executing around midnight
			stdWriteLn( ['zip genealogies file took: ', iHours, ' h, ', iMinutes, ' min, ', iSeconds, ' sec, ', iMilliseconds, ' msec '] );
		end;
	end;

	procedure simulateKinship (randomGenerator: TRandomNumberGenerator; cohort: longint; bootstrap_ind: longint; loopPhase: loopTypes);
	var
		pDemReg: pStructDemographicRegimeSettings;
		ageEgoInd: longint;
		ageEgo: agesLife;
		nbTotRelatives: longint = 0;
		nKinsInTree: longint = 0;
		ind, indEgo, stepEgos: longint;
        modEgo: longint = 1000;
		writeInfo: boolean;

        fname: string;
		pEgo: pRelativeType;
		nIndividuals: longint = 0;
		fileFormat: Kinship_FileFormat;

		arrayChildren: arrayOfInfoChild;
		
        indThread, numThreads: longint;
        egoData: EgoTreeData;
        allThreadTerminated: boolean;
        myThreadObjects: array of TSimulEgoTree; // for multithreading
        aThreadObject: TSimulEgoTree; // used for estimating the optimal number of genealogical trees to be simulated in each batch
        totalNumberOfEgosToSimulateInThisBatch, numberOfEgosToSimulateInNextThread: longint;
        optimalNumberOfTrees: longint = 100; // needs to be refined at runtime;
		tStart, tEnd, tDiff: TDateTime;  // Begin and end of measurement, and difference
		iHours, iMinutes, iSeconds, iMilliseconds: Word;  // Time components
		
		MULTITHREADING: boolean = false;
        
{$IFDEF DEBUG}
arr: array [0..1] of longint;
indEgoValues: longint;
{$ENDIF}

	begin
		tStart := Now();
        indThread := 0;
		MULTITHREADING := g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_SIMKIN.value and (gMaxThreads > 1);
		if g_GENPARAM.USE_ARRAY_CHILDREN.value then
			CreateArrayChildren(arrayChildren{%H-});

{$IFDEF VerboseProfiler}
timeProfile_init(1000);
timeProfile_talkative();
{$ENDIF}

{$IFDEF VerboseProfiler} timeProfile_start_proc('simulateKinship'); {$ENDIF}

{$IFDEF DEBUG}
gCheckRelativesCount := 0;
arr[0] := UtilesForm.FromFamily();
arr[1] := UtilesForm.ToFamily();
{$ENDIF}

		if MULTITHREADING then begin
			SetLength (myThreadObjects{%H-}, gMaxThreads);
			egoData.yearOfBirthEgo := cohort;
			// estimate the optimal number of genealogical trees for each thread object
			aThreadObject := TSimulEgoTree.Create(@egoData, 0, 20);
			repeat until aThreadObject.Simulate (20);
			repeat until aThreadObject.AFinished;
			optimalNumberOfTrees := min (optimalNumberOfTrees, trunc(150000 / aThreadObject.meanNumberOfKins));
			aThreadObject.Terminate;
			aThreadObject.Destroy;
			for indThread := 0 to gMaxThreads - 1 do begin
				myThreadObjects[indThread] := TSimulEgoTree.Create(@egoData, indThread, optimalNumberOfTrees);
			end;
   		end;
		pDemReg := getCohort_p (cohort);
		writeInfo := g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP.value;
		
		screenFileWriteLn('======================================================================');
		screenFileWriteLn(KinCohort + ' ' + intToStr(cohort));
		screenFileWriteLn(KinshipWithPossibleDeathMother + ' ' + intToStr(pDemReg^.lp[nEgoPar].value));

		initDataKinship (kSetAgesEgo);

		ageEgoInd := -1;
		for ageEgo in kSetAgesEgo do
		begin
			ageEgoInd := ageEgoInd + 1;

			zero_kinshipStruct ( gOut_totKinship[g_nRuns_aggrKinship-1, ageEgoInd] );
		end;
		zero_KinByAgeEgoStruct ( g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1] );
		
		nbTotRelatives := 0;
		
{$IFDEF DEBUG}
gNumEgoMen := 0; gNumEgoWomen := 0; gChildrenEgoMen := 0; gChildrenEgoWomen := 0;
gIndEgo := 0;
{$ENDIF}

		fileFormat := g_GENPARAM.kinIndFmt.value;
		
		if not individualKin_init (bootstrap_ind, fileFormat, fname{%H-}, ((loopPhase = k_onlyOne) or (loopPhase = k_first))) then
			exit;

		indEgo := 0;
		stepEgos := 0;
        //if gRunFromIDE then
			modEgo := g_GENPARAM.MODEGO.value;

		while indEgo < pDemReg^.lp[nEgoPar].value do
		begin

{$IFDEF DEBUG - NOT THREAD AWARE}
gIndEgo := indEgo + 1;
if (gIndEgo >= arr[0]) and (gIndEgo <= arr[1]) then
	// breakpoint
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
for indEgoValues := 0 to length (gViewEgos)-1 do
	if gIndEgo = gViewEgos[indEgoValues] then
		// breakpoint
     	   if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}

if g_GENPARAM.DEBUG.value then
	writeDebug([gIndEgo]);

//stdWriteLn([gIndEgo]);flushIO;
{$ENDIF}
			if MULTITHREADING then begin
				numThreads := 0;
        		totalNumberOfEgosToSimulateInThisBatch := 0;
				for indThread := 0 to gMaxThreads - 1 do begin
					if ( (indEgo + totalNumberOfEgosToSimulateInThisBatch + optimalNumberOfTrees - 1) <= pDemReg^.lp[nEgoPar].value) then
						numberOfEgosToSimulateInNextThread := optimalNumberOfTrees
					else
						numberOfEgosToSimulateInNextThread := pDemReg^.lp[nEgoPar].value - indEgo - totalNumberOfEgosToSimulateInThisBatch;
					totalNumberOfEgosToSimulateInThisBatch := totalNumberOfEgosToSimulateInThisBatch + numberOfEgosToSimulateInNextThread;
					if numberOfEgosToSimulateInNextThread > 0 then begin
						repeat until myThreadObjects[indThread].simulate(numberOfEgosToSimulateInNextThread);
						Inc (numThreads);
					end;
				end;
				allThreadTerminated := false;
				while not allThreadTerminated do begin
					allThreadTerminated := true;
					for indThread := 0 to numThreads - 1 do begin
						if not myThreadObjects[indThread].AFinished then allThreadTerminated := false;
					end;
				end;
				for indThread := 0 to numThreads - 1 do begin
					myThreadObjects[indThread].UpdateKinNumber (nbTotRelatives);
					nbTotRelatives := nbTotRelatives + myThreadObjects[indThread].myTotalKinCount;
					for ind := 0 to myThreadObjects[indThread].myNumTreesStored - 1 do begin
						pEgo := myThreadObjects[indThread].pMyEgos[ind];
						addToTableKinship(pEgo, kSetAgesEgo, gOut_totKinship[g_nRuns_aggrKinship-1], g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1]);
						addToStatesKinship(pEgo);
				
						Inc (indEgo);
						nIndividuals := nIndividuals + writeKinship (indEgo, pEgo, gKinsToSimulate, fileFormat);
						if (indEgo > stepEgos) then
							individualKin_mid(indEgo, modEgo, indThread + 1, stepEgos);
					end;
				end;
				
			end else begin
				nKinsInTree := nbTotRelatives;
				pEgo := simulKinship(randomGenerator, cohort, arrayChildren, nbTotRelatives);
				nKinsInTree := nbTotRelatives - nKinsInTree;

				addToTableKinship(pEgo, kSetAgesEgo, gOut_totKinship[g_nRuns_aggrKinship-1], g_NumKinsByAgeEgo[g_nRuns_aggrKinship-1]);
				addToStatesKinship(pEgo);
				
				inc (indEgo);
				nIndividuals := nIndividuals + writeKinship (indEgo, pEgo, gKinsToSimulate, fileFormat);
    			if (indEgo mod modEgo = 0) then
    				individualKin_mid(indEgo, modEgo, 0, stepEgos);
{				if gRunFromIDE then
					checkKinship (pEgo, nKinsInTree);
                stdWriteLn (['Tree with: ', nKinsInTree, ' kins']);
                flushIO();
}               
				disposeKinship(pEgo);
			end;

		end; {while indEgo < pDemReg^.lp[nEgoPar].value do}

		tEnd := Now();
		tDiff:= tEnd - tStart;  // Subtract higher from lower value
		DecodeTime( tDiff, iHours, iMinutes, iSeconds, iMilliseconds );  // Does not account for day changes when executing around midnight
		stdWriteLn( ['simulateKinship took: ', iHours, ' h, ', iMinutes, ' min, ', iSeconds, ' sec, ', iMilliseconds, ' msec '] );

{$IFDEF VerboseProfiler} timeProfile_start_proc('individualKin_end'); {$ENDIF}
		individualKin_end (fileFormat, indEgo, nIndividuals, fname);
{$IFDEF VerboseProfiler} timeProfile_end_proc('individualKin_end'); {$ENDIF}

try
{$IFDEF DEBUG}
if g_GENPARAM.CHECK_DATASTRUCT.value then begin
	checkBrides ('simulateKinship', gThisIsNotanArrayOfBrides);
	checkChildren ('simulateKinship');
end;
{$ENDIF}

{$IFDEF VerboseProfiler} timeProfile_start_proc('writeTables'); {$ENDIF}
		writeTables (writeInfo);
{$IFDEF VerboseProfiler} timeProfile_end_proc('writeTables'); {$ENDIF}
		
except
On E: Exception Do
if gRunFromIDE then
{$IFNDEF ARM}
	asm int 3 end;
{$ELSE}
	assert(true, E.Message);
{$ENDIF}
end;
{$IFDEF VerboseProfiler} timeProfile_end_proc('simulateKinship'); {$ENDIF}
if g_GENPARAM.MULTITHREADING.value and g_GENPARAM.MULTITHREADING_SIMKIN.value then begin
	for indThread := 0 to gMaxThreads - 1 do begin
		myThreadObjects[indThread].Destroy;
	end;
	SetLength (myThreadObjects, 0);
end;

		if g_GENPARAM.USE_ARRAY_CHILDREN.value then
				DestroyArrayChildren(arrayChildren);
	end; {simulateKinship}

end.
