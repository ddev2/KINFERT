{$I Defines.pas}
unit Parenthood;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
    Classes,
	Math, SysUtils, Typinfo,
	Declarations, RandomNumbers, DemographicRegime, Fertility, Nuptiality, Utilities;

type
	TPersonMemoryBlock = class
	public
		idPerson: longint;
		cohort: smallint;
		yearBirth: double;
		nbChildren: longint;
		unionStates: TUnionsType;
		arrayChildren: arrayOfInfoChild;
		pChildrenList: pInfoChildType;

		Constructor Create(randomGenerator: TRandomNumberGenerator;
						personId, cohortPerson, nC: longint;
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
	ArrayOfPersonMemoryBlock = array of TPersonMemoryBlock;
	
	TPersonMemoryManager = class
	private
		personList: array of array of array of TPersonMemoryBlock;
		nPersons: longint;
		countLevel1, countLevel2: longint;
		nw_level1, nw_level2, nw_level3: longint;
		destroyPersonsCollection: boolean;

	public
		Constructor Create (approxSize: longint = 0;
			destroyPersonObjOnExit: boolean = true);
		Destructor Destroy; override;
		function addPerson (aPersonObj: TPersonMemoryBlock): boolean;
		function getPerson (personInd: longint): TPersonMemoryBlock;
		function numPersons(): longint;
		procedure indexToArrayPos (personInd: longint; out ind1, ind2, ind3: longint);
		function arrayPosToIndex (ind1, ind2, ind3: longint): longint;
	end;

	procedure incrementNbChildren (var distNbChildren: arrayNbChildren; nbChildren, nbUnion: longint; ageDeathWoman, ageEndFirstUnion: double);
	procedure writeInfoParents (nameFile: string; parents: TPersonMemoryManager; minYear, maxYear: longint);

var
	gNilBlock: ArrayOfPersonMemoryBlock = nil;
	
implementation

	const
		kNumWomen_Level3 = 10000;
		kNumWomen_Level2 = 100;
		kNumWomen_Level1 = 100;
	
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
function TPersonMemoryBlock.hasChild (bornOnYear: longint): boolean;
var
	pChild: pInfoChildType;
	
begin
	result := false;
	pChild := pChildrenList;
	while pChild <> nil do begin
		if pChild^.livingAtBirth then begin
			if 	(trunc (pChild^.yearBirth) = bornOnYear) then
			begin
				result := true;
				break;
			end;
		end;
		pChild := pChild^.next;
	end;
end;

function TPersonMemoryBlock.checkOwnUnionStates: boolean;
begin
	result := checkUnionStates(unionStates);
end;

function TPersonMemoryBlock.checkUnionStates (ms: TUnionsType): boolean;
begin
	result := ms.checkMe(nil);
end;

function TPersonMemoryBlock.checkOwnChildrenList: boolean;
begin
	result := checkChildrenList(nbChildren, pChildrenList);
end;

function TPersonMemoryBlock.checkChildrenList (nC: longint; pChild: pInfoChildType): boolean;
var
	ind: longint;
begin
	ind := 0;
	result := true;
	while pChild <> nil do begin
		if pChild^.check <> kInfoChildCheck then begin
			writeAndWait ('ERROR ==> Bad pointer children list in checkChildrenList: ' + IntToStr (ind));
			exit;
		end;
		if pChild^.livingAtBirth then ind := ind + 1;
		if ind > nC then begin
			writeAndWait ('ERROR ==> Nil pointer masked mother in checkChildrenList: ' + IntToStr (ind));
			result := false;
			break;
		end;
		if pChild^.motherUnionNumber > 10 then begin
			writeAndWait ('ERROR ==> Too much mothers in checkChildrenList: ' + IntToStr (pChild^.motherUnionNumber));
			result := false;
			break;
		end;
		if pChild^.birthOrder > 35 then begin
			writeAndWait ('ERROR ==> Too much children in checkChildrenList: ' + IntToStr (pChild^.birthOrder));
			result := false;
			break;
		end;
		pChild := pChild^.next;
	end;
end;
{$ENDIF}

	// This object copy info from a bride and, if ageUnionTrunc > 0, prepare her for the current groom
	Constructor TPersonMemoryBlock.Create(randomGenerator: TRandomNumberGenerator;
        								personId, cohortPerson, nC: longint;
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
		idPerson := personId;
		cohort := cohortPerson;
		// the mother has a year of birth and we set a month of birth...
		yearBirth := cohort + randomGenerator.alea (0, 0.9999999999999999);
		nbChildren := nC;
		ms.copyMe (unionStates);
		arrayChildren := aC;
		if (arrayChildren = nil) or (length(arrayChildren) = 0) then
			// we do not use array of children and we copy the linked list
			pChildrenList := duplicateChildrenList (pCh)
        else
            // we have an arrayChildren and we use it to copy the childrenList
			pChildrenList := duplicateChildrenList_AC (pCh, arrayChildren);

		if (ageUnionTrunc <= 0) then
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

	Destructor TPersonMemoryBlock.Destroy;
	begin
		disposeChild (pChildrenList);
		FreeAndNil (unionStates);
		inherited Destroy;
	end;

	procedure TPersonMemoryBlock.truncateAtAge (ageUnionTrunc: double);
	var
		indUnion, indUnion2: longint;
		indUnionCurrent: longint;
		aSex: Sex;
		pChild: pInfoChildType;
		truncateIt: boolean;
		
	begin
	//eliminating unions and children which occurred after ageUnionTrunc
	//the current union which starts at ageUnionTrunc IS to be retained

		// Start with unions
		truncateIt := false;
		if unionStates.nbUnions = 0 then
			exit;
		indUnionCurrent := unionStates.nbUnions;
		for indUnion := 1 to unionStates.nbUnions do
			if unionStates.Unions [indUnion - 1].ages[le_union, woman] > ageUnionTrunc then begin
				truncateIt := true;
				indUnionCurrent := indUnion;
				break;
			end;
		indUnion := indUnionCurrent;

		if truncateIt then begin
			// the last union is to be truncated so we decrement indUnion to get to the current union
			indUnion := indUnion - 1;
		end;
		
		// Delete info for the union that starts at age 'ageUnionTrunc'
		// retaining only useful info for the woman
		if (indUnion > 0) then begin
			unionStates.Unions [indUnion - 1].ages[le_union, man] := kNotDefined;
			unionStates.Unions [indUnion - 1].ages[le_death, man] := kNotDefined;
			unionStates.Unions [indUnion - 1].ages[le_endUnion, man] := kNotDefined;
			unionStates.Unions [indUnion - 1].ages[le_endUnion, woman] := kNotDefined;
		end;
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

	function TPersonMemoryBlock.mySize: longint;
	begin
		result := 	sizeOf (idPerson) +
					sizeOf (cohort) +
					sizeOf (yearBirth) +
					sizeOf (nbChildren) +
					childInfoSizeOf (pChildrenList) +
					unionStates.mySize;
	end;

{$IFDEF CHANGE_IN_MAY2024}
	Constructor TPersonMemoryManager.Create (approxSize: longint = 0;
		destroyPersonObjOnExit: boolean = true);
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
		destroyPersonsCollection := destroyPersonObjOnExit;
		nPersons := 0;
		setLength (personList, nw_level1);
		countLevel1 := 1;
		setLength (personList[0], nw_level2);
		countLevel2 := 1;
		setLength (personList[0, 0], nw_level3);
	end;
{$ELSE}
	Constructor TPersonMemoryManager.Create (approxSize: longint = 0;
		destroyPersonObjOnExit: boolean = true);
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
		destroyPersonsCollection := destroyPersonObjOnExit;
		nPersons := 0;
		setLength (personList, nw_level1, nw_level2, nw_level3);
		countLevel1 := 1;
		countLevel2 := 1;
	end;
{$ENDIF}
	
	Destructor TPersonMemoryManager.Destroy;
	var
		ind: longint;
	begin
		if destroyPersonsCollection then
			for ind := 1 to nPersons do
				getPerson (ind - 1).Destroy;
		setLength (personList, 0);
	end;

{$IFDEF CHANGE_IN_MAY2024}
	function TPersonMemoryManager.addPerson (aPersonObj: TPersonMemoryBlock): boolean;
	var
		ind1, ind2, ind3: longint;
	begin
		result := false;
		Inc (nPersons);
		self.indexToArrayPos (nPersons - 1, ind1{%H-}, ind2, ind3{%H-});
		if (ind1 > nw_level1) then begin
			Inc (nw_level1);
			setLength (personList, nw_level1, nw_level2, nw_level3);
		end;
		if (ind1 > countLevel1 - 1) then begin
			Inc (countLevel1);
		end;
		if (ind2 > countLevel2 - 1) then begin
			Inc (countLevel2);
		end;
		personList [ind1, ind2, ind3] := aPersonObj;
		result := true;
	end;
{$ELSE}
	function TPersonMemoryManager.addPerson (aPersonObj: TPersonMemoryBlock): boolean;
	var
		ind1, ind2, ind3: longint;
	begin
		result := false;
		Inc (nPersons);
		self.indexToArrayPos (nPersons - 1, ind1{%H-}, ind2, ind3{%H-});
		if (ind1 > length (personList) - 1) then begin
		// Out of memory
			exit;
		end;
		if (ind1 > countLevel1 - 1) then begin
			Inc (countLevel1);
			setLength (personList[ind1], nw_level2);
			// ind2 should be equal to 0
			if (ind2 <> 0) then begin
				exit;
				//myHalt (['ind2 is not right in TPersonMemoryManager.addPerson. Stopping...']);
			end;
			setLength (personList[ind1, 0], nw_level3);
		end;
		if (ind2 > countLevel2 - 1) then begin
			Inc (countLevel2);
			// ind3 should be equal to 0
			if (ind3 <> 0) then begin
				exit;
				//myHalt (['ind3 is not right in TPersonMemoryManager.addPerson. Stopping...']);
			end;
			setLength (personList[ind1, ind2], nw_level3);
		end;
		personList [ind1, ind2, ind3] := aPersonObj;
		result := true;
	end;
{$ENDIF}

	function TPersonMemoryManager.getPerson (personInd: longint): TPersonMemoryBlock;
	// personInd is 0 based and the last woman is located at personInd = nPersons - 1
	var
		ind1, ind2, ind3: longint;
	begin
		self.indexToArrayPos (personInd, ind1, ind2, ind3);
		result := personList [ind1, ind2, ind3];
	end;

	function TPersonMemoryManager.numPersons: longint;
	begin
		result := nPersons;
	end;

	procedure TPersonMemoryManager.indexToArrayPos (personInd: longint; out ind1, ind2, ind3: longint);
	begin
		ind3 := (personInd) mod nw_level3;
		ind2 := trunc ( (personInd) / nw_level3 ) mod nw_level2;
		ind1 := trunc ( trunc ( (personInd) / nw_level3 ) / nw_level2 );
	end;

	function TPersonMemoryManager.arrayPosToIndex (ind1, ind2, ind3: longint): longint;
	begin
		result := ind1 * nw_level2 * nw_level3 + ind2 * nw_level3 + ind3 + 1;
	end;
	
	procedure writeInfoParents (nameFile: string; parents: TPersonMemoryManager; minYear, maxYear: longint);
	type
		InfoData = record
			yBirth: longint;
			nParents: longint;
			nChildren: longint;
			nChildless: longint;
			arr_nUnions: array [0..11] of longint;
		end;
	var
		f: TFileType;  // Main thread only
		arrayOfData: array of InfoData;
		indPar, indCohort, ind: longint;
		nUnions: longint = 0;
		ratioChildren, ratioChildless: double;
		human: TPersonMemoryBlock;
        res: longint;
	begin
		f := TFileType.Create (gPathToResult + nameFile, res, 'CHECKPARENTSARRAY', f_rewrite);
		if res <> 0 then begin
			f.Destroy;
			exit;
		end;
		setLength (arrayOfData{%H-}, maxYear-minYear+1);
		for indCohort := minYear to maxYear do
			with arrayOfData[indCohort-minYear] do begin
				yBirth := indCohort;
				nParents := 0;
				nChildren := 0;
				nChildless := 0;
				for ind := low (arr_nUnions) to high (arr_nUnions) do
					arr_nUnions [ind] := 0;
			end;
		for indPar := 0 to parents.numPersons-1 do begin
			human := parents.getPerson (indPar);
            if human <> nil then
			  with arrayOfData[human.cohort-minYear] do begin
				  Inc (nParents);
				  nChildren := nChildren + human.nbChildren;
				  if human.nbChildren = 0 then Inc (nChildless);
				  nUnions := min (10, human.unionStates.nbUnions);
				  Inc (arr_nUnions [nUnions]);
			  end
            else
            	human := human;
		end;
		bWrite (f,['cohort',comma,'nParents',comma,'TFR',comma,'childless',comma]);
		for ind := 0 to 11 do
			bWrite (f,['U', ind, comma]);
		bWriteLn(f, []);
		for indCohort := minYear to maxYear do begin
			with arrayOfData[indCohort-minYear] do begin
				if (nParents > 0) then begin
					ratioChildren := nChildren / nParents;
					ratioChildless := nChildless / nParents;
				end else begin
					ratioChildren := 0.0;
					ratioChildless := 0.0;
				end;
				bWrite (f, [
						indCohort, comma,
						nParents, comma,
						ratioChildren, comma,
						ratioChildless, comma]);
				for ind := low (arr_nUnions) to high (arr_nUnions) do
					bWrite (f,[arr_nUnions[ind], comma]);
			end;
			bWriteLn(f, []);
		end;
		setLength (arrayOfData, 0);
		f.Destroy;
	end;
end.
