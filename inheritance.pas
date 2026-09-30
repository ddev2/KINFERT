{
How it works
The rules of intestacy consist of a hierarchy which gives preferences to the closest blood relatives of the deceased. This is as follows:

Spouse or Civil partner
Children
Grandchildren
Great-grandchildren
Parents
Siblings
Nephews/Nieces
Half Siblings
Half Nephew/Niece
Grandparents
Uncles & Aunts
First Cousins
First Cousin once removed
Half Uncle/Aunt
Half Cousins

Heir Tracing Notes
An estranged spouse is still entitled.
It does not matter whether children are illegitimate.
Issue (Offspring) automatically inherit in place of siblings/uncles/aunts/cousins who are deceased.
Uncles and aunts by marriage are not entitled, nor are brother/sisters-in-law.
The first cousin once removed refers to the children of the deceased’s cousin – ‘removed’ simply means they are not of the same generation.
If there are none of the above, the Crown gets it.

https://www.iwcprobateservices.co.uk/blog/heir-tracing-who-is-entitled-to-inherit/
}
{$I Defines.pas}
unit Inheritance;
interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	SysUtils, Declarations, Utilities;
	
	procedure checkInheritanceStatus();
	procedure lookForHeirs (pEgo: pRelativeType);
	procedure lookForInheritance (pEgo: pRelativeType);
	procedure lookForHeirs_Spain (pEgo: pRelativeType);
	procedure lookForDecedents_Spain (pEgo: pRelativeType);
	function checkInheritances (pRelative: pRelativeType): integer;
	function checkHeirs (pRelative: pRelativeType): integer;

implementation
	uses Kinship, Nuptiality, Verification;
	
	const
		k_isHeir = true;
		k_isNotHeir = false;
		{the number of generations of ascendants the second algorithm can reach, which is
		 the length of the two lists of kin types in AscendantHeirs_2: parents, grandparents,
		 great-grandparents}
		kNbGenerationsAscendantHeirs = 3;

	var
		gRelDebug: pRelativeType = nil;
		
	function getAscendant (pRelative: pRelativeType; const sexParents: array of Sex): pRelativeType;
	// sexParents := [man, woman] will get one of the two grand mothers
	// sexParents := [woman, woman, man] will get one of the four grand fathers
	var
		ind: longint;
	begin
		result := pRelative;
		for ind := 1 to length (sexParents) do begin
			if sexParents[ind-1] = man then begin
				if result^.father = nil then
					exit (nil);
				result := result^.father;
			end else begin
				if result^.mother = nil then
					exit (nil);
				result := result^.mother;
			end;
		end;
	end;
	
	procedure checkInheritanceStatus();
	var
		aKin: KinTypes;
		missingKin: string = '';
		nMissing: longint = 0;
	begin
		if g_GENPARAM.INHERITANCE.value then begin
			// check whether we are going to simulate enough kin types in order to study inheritance
			for aKin in gMinKinSetforEgoInheritance do
				if not (aKin in gKinToSimulate) then begin
					Inc (nMissing);
					if (missingKin = '') then
						missingKin := str_kinship[aKin]
					else
						missingKin := missingKin + ', ' + str_kinship[aKin];
				end;
			if (nMissing > 0) then
				writeAndWait ('Warning: ' + intToStr (nMissing) + ' kin types needed for studying inheritance are not in the set of kin to simulate: ' + missingKin);
		end;
	end;
	
	function possible_heirFound (pDeadRelative, pPossibleHeir: pRelativeType): boolean;
	// pPossibleHeir can be an heir if was alive at pDeadRelative's death
	begin
		if (pPossibleHeir = nil) or (pDeadRelative = pPossibleHeir) then
			exit (false);
		result := (pDeadRelative^.yearDeath > pPossibleHeir^.yearBirth) and (pDeadRelative^.yearDeath < pPossibleHeir^.yearDeath)
	end;
	
	function lookForChildHeir (pRelative, pOtherRelative: pRelativeType; downLevel: longint): boolean;
	// if pOtherRelative = pRelative, then we are looking for children and other descendants of pRelative
	// if pOtherRelative <> pRelative, then the descendants will be, for example, nieces/nephews or first cousins, etc. of pRelative)
	var
		indChild, indGrandChild, indGreatGrandChild: longint;
		pChild, pGrandChild, pGreatGrandChild: pRelativeType;
	begin
		result := false;
		if downLevel > 0 then
			for indChild := 1 to getNumChildren (pOtherRelative) do begin
				pChild := getChildFromRelative(pOtherRelative, indChild);
				if possible_heirFound (pRelative, pChild) then begin
					exit (true);
				end;
			end;
		if downLevel > 1 then
			for indChild := 1 to getNumChildren (pOtherRelative) do
				for indGrandChild := 1 to getNumChildren (getChildFromRelative(pOtherRelative, indChild)) do begin
					pGrandChild := getChildFromRelative(getChildFromRelative(pOtherRelative, indChild), indGrandChild);
					if possible_heirFound (pRelative, pGrandChild) then begin
						exit (true);
					end;
				end;
		if downLevel > 2 then
			for indChild := 1 to getNumChildren (pOtherRelative) do
				for indGrandChild := 1 to getNumChildren (getChildFromRelative (pOtherRelative, indChild)) do
					for indGreatGrandChild := 1 to getNumChildren (getChildFromRelative (getChildFromRelative (pOtherRelative, indChild), indGrandChild)) do begin
						pGreatGrandChild := getChildFromRelative (getChildFromRelative (getChildFromRelative (pOtherRelative, indChild), indGrandChild), indGreatGrandChild);
						if possible_heirFound (pRelative, pGreatGrandChild) then
							exit (true);
					end;
	end;
		
	function childHeirTree (pRelative: pRelativeType): boolean;
	var
		downLevel: longint = 3; // number of levels of descendence (3 means down to relative's great grand children)
		pChild: pRelativeType;
	begin
		result := false;
		if pRelative^.typeOfKin in [kt_grandChild, kt_grandNieceNephew] then
			// we only go one level down for those
			downLevel := 1;
		if pRelative^.typeOfKin in [kt_Child, kt_nieceNephew] then
			// we only go two levels down for those
			downLevel := 2;
		if lookForChildHeir (pRelative, pRelative, downLevel) then begin
			pRelative^.typeHeir := th_childrenTree;
			result := true;
			exit
		end;
	end;
	
	function grandParent (pParent: pRelativeType; aSex: Sex): pRelativeType;
	begin
		result := nil;
		if pParent <> nil then
			if aSex = man then
				result := pParent^.father
			else
				result := pParent^.mother
	end;
	
	function greatGrandParent (pParent, pGrandParent: pRelativeType; aSex: Sex): pRelativeType;
	begin
		result := nil;
		if pParent <> nil then
			result := grandParent (pGrandParent, aSex)
	end;
	
	function ascendantsHeirTree (pRelative: pRelativeType): boolean;
		function lookForAscendantHeir (pRelative: pRelativeType; upLevel: longint): boolean;
		begin
			result := false;
			if possible_heirFound (pRelative, pRelative^.father) or possible_heirFound (pRelative, pRelative^.mother) then begin
				pRelative^.typeHeir := th_ascendantsTree;
				exit (true);
			end;
			if upLevel > 1 then
				if 	possible_heirFound (pRelative, getAscendant (pRelative, [man, man])) or possible_heirFound (pRelative, getAscendant (pRelative, [man, woman])) or
				 	possible_heirFound (pRelative, getAscendant (pRelative, [woman, man])) or possible_heirFound (pRelative, getAscendant (pRelative, [woman, woman])) then
				begin
					pRelative^.typeHeir := th_ascendantsTree;
					exit (true);
				end;
			if upLevel > 2 then
				if
					possible_heirFound (pRelative, getAscendant (pRelative, [man, man, man])) or // greatGrandFather 1
					possible_heirFound (pRelative, getAscendant (pRelative, [man, man, woman])) or // greatGrandMother 1
					possible_heirFound (pRelative, getAscendant (pRelative, [man, woman, man])) or // greatGrandFather 2
					possible_heirFound (pRelative, getAscendant (pRelative, [man, woman, woman])) or // greatGrandMother 2
					possible_heirFound (pRelative, getAscendant (pRelative, [woman, man, man])) or // greatGrandFather 3
					possible_heirFound (pRelative, getAscendant (pRelative, [woman, man, woman])) or // greatGrandMother 3
					possible_heirFound (pRelative, getAscendant (pRelative, [woman, woman, man])) or // greatGrandFather 4
					possible_heirFound (pRelative, getAscendant (pRelative, [woman, woman, woman])) // greatGrandMother 4
				 then begin
					pRelative^.typeHeir := th_ascendantsTree;
					exit (true);
				end;
		end;

	var
		upLevel: longint = 3;
	begin
		result := false;

		if (pRelative^.typeOfKin = kt_partner) then exit;

		if pRelative^.typeOfKin in [kt_greatGrandFather, kt_greatGrandMother] then
			exit;
		if pRelative^.typeOfKin in [kt_grandFather, kt_grandMother, kt_grandAuntUncle] then
			upLevel := 1;
		if pRelative^.typeOfKin in [kt_father, kt_mother, kt_auntUncle, kt_great_cousin_removed] then
			upLevel := 2;
		
		result := lookForAscendantHeir (pRelative, upLevel);
	end;
	
// >>> Claude 2026-09-30 start
	{N26: the partner test of the first algorithm, taken out of partnerHeir so that it can be
	 recorded for every relative and not only for the relatives whose chain of branches reaches
	 the partner. The test itself is unchanged: the last union ended at the relative's own
	 death, and the partner of that union was alive at that moment.}
	function partnerCanBeHeir_1 (pRelative: pRelativeType): boolean;
	var
		pPartner: pRelativeType;
		ageEndUnion: double;
	begin
		result := false;
		ageEndUnion := getAgeEndUnion (pRelative, pRelative^.nUnions);
		if (ageEndUnion <> pRelative^.ageDeath) then
			exit;
		pPartner := getPartner (pRelative, pRelative^.nUnions);
		{a partner who is not a possible heir here is normally a partner who died in the same
		 month as the relative}
		result := possible_heirFound (pRelative, pPartner);
	end;

	{N26: the partner test of the second algorithm, taken out of partnerIsHeir_2 unchanged, so
	 that lookForHeirs and checkHeirs can ask the question without adding an heir.}
	function partnerCanBeHeir_2 (pDecedent: pRelativeType): boolean;
	var
		pPartner: pRelativeType;
	begin
		result := false;
		pPartner := getLastPartner (pDecedent);
		if (pPartner = nil) then
			exit;
		if (getCauseEndLastUnion (pDecedent) <> end_by_death) then
			exit;
		result := possible_heirFound (pDecedent, pPartner);
	end;

	function partnerHeir (pRelative: pRelativeType): boolean;
	{the partner branch of the first algorithm. The answer is the field that lookForHeirs filled
	 before it entered the chain of branches, so the test is made once for each relative.}
	begin
		result := pRelative^.partnerCanInherit;
		if result then
			pRelative^.typeHeir := th_partner;
	end;
// <<< Claude 2026-09-30 end
	
	function siblingsHeirTree (pRelative: pRelativeType): boolean;
	// siblings and descendance of siblings as heirs
	// we go through father's and mother's children in order not to forget half-kin
	// but obviously there is a lot of repetition here, as most of mother's children are father's ones
		function oneSiblingsHeirTree (pRelative, pParent: pRelativeType; downLevel: longint): boolean;
		var
			indSibling: longint;
			pSibling: pRelativeType;
		begin
			result := false;
			if pParent = nil then
				exit;
			for indSibling := 1 to getNumChildren (pParent) do begin
				pSibling := getChildFromRelative (pParent, indSibling);
				if pSibling <> pRelative then begin
					// the sibling is not the relative we are following here
					if possible_heirFound (pRelative, pSibling) then begin
						pRelative^.typeHeir := th_siblingsTree;
						exit (true);
					end;
					if lookForChildHeir (pRelative, pSibling, downLevel) then begin
						pRelative^.typeHeir := th_siblingsTree;
						exit (true);
					end;
				end;
			end;
		end;
		
	var
		downLevel: longint = 2;
	begin
		result := false;
		if (pRelative^.typeOfKin in [kt_greatGrandFather, kt_greatGrandMother]) then
			exit;
		if (pRelative^.typeOfKin in [kt_grandChild, kt_grandNieceNephew]) then
			downLevel := 1;
		if oneSiblingsHeirTree (pRelative, pRelative^.mother, downLevel) or oneSiblingsHeirTree (pRelative, pRelative^.father, downLevel) then
		begin
			result := true;
		end;
	end;
	
	function oneAuntUncleTreeFound (pRelative: pRelativeType; sexParentsTree: ArrayOfSex; heirTree: typeOfHeirs; downLevel: longint): boolean;
	var
		pGrandParent: pRelativeType;
		indAuntUncle, ind: longint;
		pAuntUncle: pRelativeType;
	begin
		result := false;
		pGrandParent := pRelative;
		for ind := 0 to length(sexParentsTree) - 1 do begin
			if sexParentsTree [ind] = man then
				pGrandParent := pGrandParent^.father
			else
				pGrandParent := pGrandParent^.mother;
			if pGrandParent = nil then
				exit (false);
		end;
		for indAuntUncle := 1 to getNumChildren (pGrandParent) do begin
			pAuntUncle := getChildFromRelative (pGrandParent, indAuntUncle);
			if (pAuntUncle <> pRelative^.father) and (pAuntUncle <> pRelative^.mother) then begin
				if possible_heirFound (pRelative, pAuntUncle) then begin
					pRelative^.typeHeir := heirTree;
					exit (true);
				end;
				if lookForChildHeir (pRelative, pAuntUncle, downLevel) then begin
					pRelative^.typeHeir := heirTree;
					exit (true);
				end;
			end;
		end;
	end;
	
	function auntUncleHeirTree (pRelative: pRelativeType): boolean;
	var
		downLevel: longint = 1;
	begin
		result := false;
		if (pRelative^.typeOfKin in [kt_greatGrandFather, kt_greatGrandMother, kt_grandFather, kt_grandMother, kt_child, kt_grandChild]) then
			exit (false);
		if oneAuntUncleTreeFound (pRelative, [woman, woman], th_auntUncleTree, downLevel) then exit (true);
		if oneAuntUncleTreeFound (pRelative, [woman, man], th_auntUncleTree, downLevel) then exit (true);
		if oneAuntUncleTreeFound (pRelative, [man, woman], th_auntUncleTree, downLevel) then exit (true);
		if oneAuntUncleTreeFound (pRelative, [man, man], th_auntUncleTree, downLevel) then exit (true);
	end;
	
	function grandAuntUncleHeirTree (pRelative: pRelativeType): boolean;
	var
		downLevel: longint = 0;
	begin
		result := false;
		if not (pRelative^.typeOfKin in [kt_ego, kt_sibling, kt_cousin]) then
			exit (false);
		if oneAuntUncleTreeFound (pRelative, [woman, woman, woman], th_grandAuntUncleTree, downLevel) then exit (true);
		if oneAuntUncleTreeFound (pRelative, [woman, woman, man], th_grandAuntUncleTree, downLevel)then exit (true);
		if oneAuntUncleTreeFound (pRelative, [woman, man, woman], th_grandAuntUncleTree, downLevel)then exit (true);
		if oneAuntUncleTreeFound (pRelative, [woman, man, man], th_grandAuntUncleTree, downLevel)then exit (true);
		if oneAuntUncleTreeFound (pRelative, [man, woman, woman], th_grandAuntUncleTree, downLevel) then exit (true);
		if oneAuntUncleTreeFound (pRelative, [man, woman, man], th_grandAuntUncleTree, downLevel) then exit (true);
		if oneAuntUncleTreeFound (pRelative, [man, man, woman], th_grandAuntUncleTree, downLevel)then exit (true);
		if oneAuntUncleTreeFound (pRelative, [man, man, man], th_grandAuntUncleTree, downLevel)then exit (true);
	end;
	
	procedure noHeirs (pRelative: pRelativeType);
	begin
		pRelative^.typeHeir := th_none;
	end;
	
	procedure lookForHeirs (pEgo: pRelativeType);
	var
		pRelative: pRelativetype;
	begin
		// we determine who are the heir(s) of each relative, limiting ourselves to kin from whom ego can inherit
		// this means that the information for egos will be complete, but not necessary for other kin
		pRelative := pEgo;
		while (pRelative <> nil) do begin
			// in case we have a partner: we consider only ego's partner
			// other relatives's partners have typeOfKin sets on these relatives
			if ((pRelative^.typeOfKin = kt_ego) or (pRelative^.typeOfKin in gPossibleHeirs)) and (pRelative^.kinOf^.typeOfKin = kt_ego) then begin
				pRelative^.partnerCanInherit := partnerCanBeHeir_1 (pRelative);
				if (pRelative^.partnerCanInherit <> partnerCanBeHeir_2 (pRelative)) then
					if reportFailure (chk_inh_partnerTestsDiffer,
							['relative ', pRelative^.indNumber, ', unions ', pRelative^.nUnions]) then
						breakOnFailure;
				if not childHeirTree (pRelative) then
					if not ascendantsHeirTree (pRelative) then
						if not partnerHeir (pRelative) then
							if not siblingsHeirTree (pRelative) then
								if not auntUncleHeirTree (pRelative) then
									if not grandAuntUncleHeirTree (pRelative) then
										noHeirs (pRelative);
			end;
			pRelative := pRelative^.nextRelative;
		end;
	end;

	function isAnHeir (pDeadRelative, pEgo : pRelativeType): boolean;
	var
		ind: longint = 1;
	begin
		result := false;
		while (ind <= pEgo^.nInheritances) do begin
			if pEgo^.inheritances [ind - 1].pDeadRelative = pDeadRelative then
				exit (true);
			Inc (ind);
		end;
	end;
	
	function inheritanceAlreadyFound (pDeadRelative, pRelative: pRelativeType): boolean;
	var
		ind: longint;
	begin
		result := false;
		// check whether the decedent is already in the list...
		if pRelative^.nInheritances > 0 then
			for ind := 0 to pRelative^.nInheritances - 1 do
				if (pRelative^.inheritances [ind].pDeadRelative = pDeadRelative) then
					exit (true);
	end;
	
	function heirAlreadyFound (pDeadRelative, pHeir: pRelativeType): boolean;
	var
		ind: longint;
	begin
		result := false;
		// check whether the heir is already in the list...
		if pDeadRelative^.nHeirs > 0 then
			for ind := 0 to pDeadRelative^.nHeirs - 1 do
				if pDeadRelative^.heirs [ind] = pHeir then
					exit (true);
	end;

{		inheritanceType = record
			degree: longint; // distance in the tree from the dead relative (if kNotDefined, then the person-heir is dead when pDeadRelative dies)
			nLivingSiblings: longint; 	// number of living siblings that will share the inheritance
										// (we set this value even if the relative is NOT an heir,
										// as this allows to trace back the share owned by all descendants)
			share: double;	// share that will receive the heir (we compute this only for ego)
			pDeadRelative: pRelativeType; // the person to be inherited (the decedent)
		end;
}

	procedure addInheritance (pDeadRelative, pHeir: pRelativeType; degree: longint; isHeir: boolean = true; nLivingSiblings: longint = kNotDefined);
	var
		indHeir: integer;
	begin
		if inheritanceAlreadyFound (pDeadRelative, pHeir) then
			exit;
		Inc (pHeir^.nInheritances);
		if pHeir^.nInheritances > length(pHeir^.inheritances) then
			setLength (pHeir^.inheritances, length(pHeir^.inheritances) + 10);
		pHeir^.inheritances [pHeir^.nInheritances - 1].isHeir := isHeir;
		pHeir^.inheritances [pHeir^.nInheritances - 1].degree := degree;
		if (nLivingSiblings <> kNotDefined) then
			pHeir^.inheritances [pHeir^.nInheritances - 1].nLivingSiblings := nLivingSiblings;
		pHeir^.inheritances [pHeir^.nInheritances - 1].share := 0;
		pHeir^.inheritances [pHeir^.nInheritances - 1].pDeadRelative := pDeadRelative;
	end;
	
	procedure addHeir (pDeadRelative, pHeir: pRelativeType);
	begin
		Inc (pDeadRelative^.nHeirs);
		if pDeadRelative^.nHeirs > length(pDeadRelative^.heirs) then
			setLength (pDeadRelative^.heirs, length(pDeadRelative^.heirs) + 10);
		pDeadRelative^.heirs [pDeadRelative^.nHeirs - 1] := pHeir;
	end;
	
	function heirFound_add (pDeadRelative, pPossibleHeir: pRelativeType; degree: longint = 1; nLivingSiblings: longint = 1): boolean;
	// if an heir is found, we add it to the list of heir-relatives
	begin
		if heirAlreadyFound (pDeadRelative, pPossibleHeir) then
			exit (false);
		if not possible_heirFound (pDeadRelative, pPossibleHeir) then
			exit (false);
		addHeir (pDeadRelative, pPossibleHeir);
		addInheritance (pDeadRelative, pPossibleHeir, degree, k_isHeir, nLivingSiblings);
		result := true;
	end;

	procedure updateShareInheritance (pDeadRelative, pHeir: pRelativeType; share: double);
	var
		ind: longint = 1;
	begin
		while (ind <= pHeir^.nInheritances) do begin
			if pHeir^.inheritances [ind - 1].pDeadRelative = pDeadRelative then begin
				pHeir^.inheritances [ind - 1].share := share;
				exit;
			end;
			Inc (ind);
		end;
		// we should not get there
		breakOnFailure;
	end;
	
	procedure updateSibling (pDeadRelative, pHeir: pRelativeType; nLivingSiblings: longint);
	var
		ind: longint = 1;
	begin
		while (ind <= pHeir^.nInheritances) do begin
			if pHeir^.inheritances [ind - 1].pDeadRelative = pDeadRelative then begin
				pHeir^.inheritances [ind - 1].nLivingSiblings := nLivingSiblings;
				pHeir^.inheritances [ind - 1].share := 1 / nLivingSiblings;
				exit;
			end;
			Inc (ind);
		end;
		// we should not get there
		breakOnFailure;
	end;
	
	procedure updateAllChildren (pDeadRelative, pParent: pRelativeType; nLivingSiblingsTree: longint);
	var
		indChild: longint;
		pChild: pRelativeType;
	begin
		for indChild := 1 to getNumChildren (pParent) do begin
			pChild := getChildFromRelative (pParent, indChild);
			if isAnHeir (pDeadRelative, pChild) then
				updateSibling (pDeadRelative, pChild, nLivingSiblingsTree);
		end;
	end;
	
	procedure updateAllSiblings (pDeadRelative: pRelativeType; nSiblings: longint; const SIBLINGS: arrayOfRelatives; nLivingSiblingsTree: longint);
	var
		indSibling: longint;
		pSibling: pRelativeType;
	begin
		for indSibling := 1 to nSiblings do begin
			pSibling := SIBLINGS [indSibling-1];
			if (pSibling <> nil) then
				updateSibling (pDeadRelative, pSibling, nLivingSiblingsTree);
		end;
	end;
	
	procedure setInheritanceInfo (pDeadRelative, pHeir: pRelativeType; degree: longint; share: double; nLivingSiblings: longint = kNotDefined; isHeir: boolean = true);
	var
		ind: longint = 1;
	begin
		while (ind <= pHeir^.nInheritances) do begin
			if pHeir^.inheritances [ind - 1].pDeadRelative = pDeadRelative then begin
				pHeir^.inheritances [ind - 1].isHeir := isHeir;
				pHeir^.inheritances [ind - 1].degree := degree;
				if (nLivingSiblings <> kNotDefined) then pHeir^.inheritances [ind - 1].nLivingSiblings := nLivingSiblings;
				pHeir^.inheritances [ind - 1].share := share;
				exit;
			end;
			Inc (ind);
		end;
		// we should not get there
		breakOnFailure;
	end;
	
	function kinToAvoid (const kinToAvoidArray: arrayOfRelatives; aKin: pRelativeType): boolean;
	var
		ind: longint;
	begin
		for ind := 1 to length(kinToAvoidArray) do
			if aKin = kinToAvoidArray [ind-1] then
				exit (true);
		exit (false);
	end;
	
	function findHeir_childTree (pDeadRelative, pRelative: pRelativeType; maxLevel: longint; var degree: longint; var nLivingSiblingsTree: longint): longint;
	// if pRelative is dead, we check whether at least one her/his children are alive
	// and if not we may go down up to maxLevel of descendance to find at least one heir
	var
		localDegree: longint;
		indChild: longint;
		pChild: pRelativeType;
		nLivingChildrenTree, nLivingChildrenTree_mem: longint;
	begin
		result := 0;
		localDegree := degree;
		if inheritanceAlreadyFound (pDeadRelative, pRelative) then
			exit (0);
		if heirFound_add (pDeadRelative, pRelative, degree, nLivingSiblingsTree) then begin
			exit (1);
		end else begin
			Inc (localDegree);
			if localDegree > maxLevel then
				exit (0);
			// We look at the children
			nLivingChildrenTree := getNumChildren (pRelative);
			nLivingChildrenTree_mem := nLivingChildrenTree;
			for indChild := 1 to getNumChildren (pRelative) do begin
				pChild := getChildFromRelative (pRelative, indChild);
				if findHeir_childTree (pDeadRelative, pChild, maxLevel, localDegree, nLivingChildrenTree) = 1 then
 					result := 1
			end;
			updateAllChildren (pDeadRelative, pRelative, nLivingChildrenTree);
			if result = 0 then
			//the descendants tree is empty
				Dec (nLivingSiblingsTree)
			else
				addInheritance (pDeadRelative, pRelative, degree, k_isNotHeir, nLivingSiblingsTree);
		end;
	end;
	
	procedure findHeir_descendancy (pDeadRelative, pParent: pRelativeType;
									const kinToAvoidArray: arrayOfRelatives;
									maxLevel, degree: longint;
									var numOfPossibleHeirs: longint);
	// if ego is one of the children, she/he is an heir of pDeadRelative and her/his share is (1 / numOfPossibleHeirs)
	// if ego is one of the grand children or great grand children, she/he is not necessarily an heir
	var
		indChild: longint;
		pChild: pRelativeType;
		nLivingSiblingsTree, nLivingSiblingsTree_mem: longint;
	begin
		nLivingSiblingsTree := getNumChildren (pParent);
		nLivingSiblingsTree_mem := nLivingSiblingsTree;
		for indChild := 1 to getNumChildren (pParent) do begin
			pChild := getChildFromRelative (pParent, indChild);
			if not kinToAvoid (kinToAvoidArray, pChild) then begin
				numOfPossibleHeirs := numOfPossibleHeirs +
					findHeir_childTree (pDeadRelative, pChild, maxLevel, degree, nLivingSiblingsTree);
			end else if (pChild^.typeOfKin <> kt_ego) then
				Dec (nLivingSiblingsTree);
		end;
		updateAllChildren (pDeadRelative, pParent, nLivingSiblingsTree);
	end;

	function findHeir_SiblingTree (pDeadRelative, pRelative: pRelativeType; maxLevel: longint; var degree: longint; nSiblings: longint): boolean;
	// if pRelative is dead, we check whether at least one her/his children are alive
	// and if not we may go down up to maxLevel of descendance to find at least one heir
	var
		atLeastOneAlive: boolean = false;
		localDegree: longint;
		indChild: longint;
		pChild: pRelativeType;
		nLivingChildrenTree, nLivingChildrenTree_all: longint;
	begin
		result := false;
		localDegree := degree;
		if inheritanceAlreadyFound (pDeadRelative, pRelative) then begin
 		breakOnFailure;
		end;
		if heirFound_add (pDeadRelative, pRelative, degree, nSiblings) then begin
{			if gRunFromIDE then asm int 3 end;
}
			exit (true);
		end else begin
			Inc (localDegree);
			if localDegree > maxLevel then
				exit (false);
			// We look at the children
			nLivingChildrenTree := getNumChildren (pRelative);
			nLivingChildrenTree_all := nLivingChildrenTree;
			result := false;
			for indChild := 1 to getNumChildren (pRelative) do begin
				pChild := getChildFromRelative (pRelative, indChild);
 				atLeastOneAlive := findHeir_SiblingTree (pDeadRelative, pChild, maxLevel, localDegree, nLivingChildrenTree_all);
 				if atLeastOneAlive then begin
					addInheritance (pDeadRelative, pRelative, degree, k_isNotHeir, nSiblings);
 				end else begin
 					Dec (nLivingChildrenTree);
 				end;
 				result := atLeastOneAlive or result;
			end;
			updateAllChildren (pDeadRelative, pRelative, nLivingChildrenTree);
		end;
	end;
	
	procedure findHeir_siblings (	pDeadRelative: pRelativeType;
									nSiblings: longint;
									var SIBLINGS: arrayOfRelatives;
									maxLevel, degree: longint;
									var numOfPossibleHeirs: longint);
	// if ego is one of the children, she/he is an heir of pDeadRelative and her/his share is (1 / numOfPossibleHeirs)
	// if ego is one of the grand children or great grand children, she/he is not necessarily an heir
	var
		indSibling: longint;
		pSibling: pRelativeType;
	begin
		for indSibling := 1 to nSiblings do begin
			pSibling := SIBLINGS [indSibling - 1];
			if findHeir_SiblingTree (pDeadRelative, pSibling, maxLevel, degree, nSiblings) then
				Inc (numOfPossibleHeirs)
			else
				SIBLINGS [indSibling - 1] := nil;
		end;
		updateAllSiblings (pDeadRelative, nSiblings, SIBLINGS, numOfPossibleHeirs);
	end;

	procedure getSiblings (pParent: pRelativeType; var nSiblings: longint; var SIBLINGS: arrayOfRelatives; pSiblingToAvoid: pRelativeType = nil);
	var
		indChild, indSibling: longint;
		pChild: pRelativeType;
		addIt: boolean;
	begin
		if pParent = nil then exit;
		for indChild := 1 to getNumChildren (pParent) do begin
			pChild := getChildFromRelative (pParent, indChild);
			if pChild = pSiblingToAvoid then
				continue;
			addIt := true;
			// does the child already in the siblings list?
			for indSibling := 1 to nSiblings do
				if SIBLINGS [indSibling-1] = pChild then begin
					addIt := false;
					break;
				end;
			if addIt then begin
				Inc (nSiblings);
				if (nSiblings > length(SIBLINGS)) then
					setLength (SIBLINGS, length(SIBLINGS) + 10);
				SIBLINGS [nSiblings-1] := pChild;
			end;
		end;
	end;

	function getShare (pDeadRelative, pHeir: pRelativeType): double;
	var
		ind: longint = 1;
	begin
		while (ind <= pHeir^.nInheritances) do begin
			if pHeir^.inheritances [ind - 1].pDeadRelative = pDeadRelative then begin
				exit (pHeir^.inheritances [ind - 1].share);
			end;
			Inc (ind);
		end;
		// we should not get there
		breakOnFailure;
	end;
	
	function computeShareInheritanceTree (pDeadRelative, pRelative: pRelativeType; var degree: longint): double;
	var
		share: double;
		localDegree: longint;
	begin
		localDegree := degree;
		Dec (localDegree);
		if isAnHeir (pDeadRelative, pRelative^.father) and not possible_heirFound (pDeadRelative, pRelative^.father) then begin
			result := getShare (pDeadRelative, pRelative^.father);
			if localDegree > 0 then
				result := result * computeShareInheritanceTree (pDeadRelative, pRelative^.father, localDegree);
		end else if isAnHeir (pDeadRelative, pRelative^.mother) and not possible_heirFound (pDeadRelative, pRelative^.mother) then begin
			result := getShare (pDeadRelative, pRelative^.mother);
			if localDegree > 0 then
				result := result * computeShareInheritanceTree (pDeadRelative, pRelative^.mother, localDegree);
		end else
			exit (1);
	end;

	function computeShareInheritance (pDeadRelative, pRelative: pRelativeType; var degree: longint): double;
	begin
		result := getShare (pDeadRelative, pRelative);
		if degree > 0 then
			result := result * computeShareInheritanceTree (pDeadRelative, pRelative, degree);
	end;

	function commonAncestor (const kinSet1, kinSet2: array of pRelativeType): pRelativeType;
	var
		ind1, ind2: longint;
	begin
		for ind1 := 1 to length (kinSet1) do
			for ind2 := 1 to length (kinSet2) do
				if kinSet1 [ind1 - 1] = kinSet2 [ind2 - 1] then
					exit (kinSet1 [ind1 - 1]);
		exit (nil);
	end;
	
	procedure checkEgoIsHeir (pEgo, pDeadRelative: pRelativeType);
	var
		numOfPossibleHeirs: longint = 0;
		indSibling: longint;
		pSibling, pAncestor: pRelativeType;
// >>> Claude 2026-09-30 start
		foundCommonAncestor: boolean;	{N24}
// <<< Claude 2026-09-30 end
		degree: longint; // ego's degree with the died relative
		SIBLINGS: arrayOfRelatives;
		nSiblings: longint;
		share: double;
	begin
{		inheritanceType = record
			isHeir: boolean; // this relative will be an heir if she/he is alive at death of the dead relative
			degree: longint; // distance in the tree from the dead relative
			nLivingSiblings: longint; 	// number of living siblings that will share the inheritance
										// (we set this value even if the relative is NOT an heir,
										// as this allows to trace down the share owned by all her/his descendants)
			share: double;	// share that will receive the heir (this is always computed for ego, not necessarily for all the rest of the heirs)
			pDeadRelative: pRelativeType; // the person to be inherited
		end;
}
		//pDeadRelative^.egoAsHeir := eh_doNotApply;
		if not possible_heirFound (pDeadRelative, pEgo) then 
			// ego was not alive when the relative died
			exit;
		if byUnion (pEgo, pDeadRelative) then
			// partners of other relatives
			exit;
		if not (pDeadRelative^.typeOfKin in g_GENPARAM.DECEDENTS_KINTYPES.value) then
			// ego can not be heir of the dead relative
			exit;		

		// ego as heir of her/his PARTNER
		if (pDeadRelative^.typeOfKin = kt_partner) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_partner]) then begin
			// if we arrive there, the couple had no children, but we have no information on partner's parents
			// so we don't know whether ego is an heir, nor if she/he is the only heir
			// we check anyway but do nothing
			degree := 1;
			if heirFound_add (pDeadRelative, pEgo, degree) then begin
				//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			end else
				// problem. We should not get here...
		breakOnFailure;
			numOfPossibleHeirs := 1;
		end;
		
		// ego as heir of a CHILD
		if (pDeadRelative^.typeOfKin = kt_child) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_ascendantsTree]) then begin
			// in principle the child has no living children or grand children of his own (should we check that??)...
			//pDeadRelative^.egoAsHeir := eh_directHeir;
			degree := 1;
			if	heirFound_add (pDeadRelative, pEgo, degree) and
				(
				((pEgo^.gender = man) and not heirFound_add (pDeadRelative, pDeadRelative^.mother, degree)) or
				((pEgo^.gender = woman) and not heirFound_add (pDeadRelative, pDeadRelative^.father, degree))
				)
			then begin
				// ego is either the father or the mother and her/his partner is dead, so ego is the unique heir
				numOfPossibleHeirs := 1;
		 	end else if (possible_heirFound (pDeadRelative, pDeadRelative^.mother) and possible_heirFound (pDeadRelative, pDeadRelative^.father)) then begin
				// both parents are alive at the child death, so they share the inheritance
				numOfPossibleHeirs := 2;
		 	end;
		end;
		
		// ego as heir of a GRAND CHILD
		if (pDeadRelative^.typeOfKin = kt_grandChild) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_ascendantsTree]) then begin
			numOfPossibleHeirs := 0;
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			degree := 1;
			if not heirFound_add (pDeadRelative, pDeadRelative^.mother, degree) and not heirFound_add (pDeadRelative, pDeadRelative^.father, degree) then
			begin
				// both parents of the grand child are dead so ego is an heir
				degree := 2;
				//pDeadRelative^.egoAsHeir := eh_directHeir;
				// we check whether one or various of the relative's grand parents (who include ego) are alive
				if (pDeadRelative^.mother <> nil) then begin
					if heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [woman, woman]), degree) then
						Inc (numOfPossibleHeirs);
					if heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [woman, man]), degree) then
						Inc (numOfPossibleHeirs);
				end;
				if (pDeadRelative^.father <> nil) then begin
					if heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [man, woman]), degree) then
						Inc (numOfPossibleHeirs);
					if heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [man, man]), degree) then
						Inc (numOfPossibleHeirs);
				end;
			end;
		end;
		
		// ego as heir of her/his FATHER or MOTHER
		if (pDeadRelative^.typeOfKin = kt_father) or (pDeadRelative^.typeOfKin = kt_mother) then begin
		 	//pDeadRelative^.egoAsHeir := eh_directHeir;
		 	// ego is alive when either the mother or father died, therefore she/he is an heir
		 	// The only competitors are the siblings or their descendants
			numOfPossibleHeirs := 0;
			degree := 1;
			findHeir_descendancy (pDeadRelative, pDeadRelative, [], 3, degree, numOfPossibleHeirs);
		end;
		
		// SIBLINGS (we need to check whether ego and the dead relative share the same father and/or the same mother, for the cases of half-siblings...)
		if (pDeadRelative^.typeOfKin = kt_sibling) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_siblingsTree]) then begin
			// both parents should be dead, but we check anyway...
			degree := 1;
			numOfPossibleHeirs := 0;
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			if not heirFound_add (pDeadRelative, pDeadRelative^.mother, degree) and not heirFound_add (pDeadRelative, pDeadRelative^.father, degree) then begin
				// both parents of the sibling are indeed dead
				// we check whether the sibling that just died had living kids or any other descendants..
				degree := 1;
				numOfPossibleHeirs := 0;
				findHeir_descendancy (pDeadRelative, pDeadRelative, [], 3, degree, numOfPossibleHeirs);
				if numOfPossibleHeirs >= 1 then begin
					// problem. We should not get here...
		breakOnFailure;
				end;
				
				nSiblings := 0;
				setLength (SIBLINGS{%H-}, 0);
				// mother's children...
				getSiblings (pDeadRelative^.mother, nSiblings, SIBLINGS, pDeadRelative);
				// father's children...
				getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
				degree := 2;
				numOfPossibleHeirs := 0;
				findHeir_siblings (pDeadRelative, nSiblings, SIBLINGS, 5, degree, numOfPossibleHeirs);
 				setLength (SIBLINGS, 0);
			end else begin
				// at least one of the parents is alive, so ego cannot be heir
				//pDeadRelative^.egoAsHeir := eh_doNotApply;
				// problem. We should not get here...
				breakOnFailure;
			end;
		end;
		
		// NIECES and NEPHEWS
		if (pDeadRelative^.typeOfKin = kt_nieceNephew) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_auntUncleTree]) then begin
		// if we come here, the niece or nephew has no living descendant or ascendant, nor a living partner
		// all aunts and uncles (including ego) can therefore be heirs
			numOfPossibleHeirs := 0;
			if heirFound_add (pDeadRelative, pDeadRelative^.father, 1) or heirFound_add (pDeadRelative, pDeadRelative^.mother, 1) then begin
				// bad as either the father or the mother are alive...
				breakOnFailure;
			end else begin
				if 	heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [man, man]), 2) or
					heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [man, woman]), 2) or
					heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [woman, man]), 2) or
					heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [woman, woman]), 2) then begin
						// bad as at least one of the grand parents are alive...
					 breakOnFailure;
				end else begin
					// aunts and uncles
					numOfPossibleHeirs := 0;
					degree := 3;
					nSiblings := 0;
					setLength (SIBLINGS, 0);
					// children of all the common ancestors, including ego
// >>> Claude 2026-09-30 start
					{N24: the aunts and uncles of the dead niece or nephew are the children of its
					 grandparents, and ego is one of them, so one of ego's own parents is a
					 grandparent of the dead relative. Not necessarily both: if ego is a half-sibling
					 of the dead relative's father, sharing only the father, then ego's mother is no
					 relation of the dead relative at all, and her children by another man share no
					 blood with it. commonAncestor answers which of ego's two parents is a
					 grandparent of the dead relative, and its answer used to be assigned and then
					 ignored, getSiblings being called on both of ego's parents whatever the answer
					 was. The children of the unrelated parent then entered the heir list on the
					 same footing as the true aunts and uncles and took an equal share of the
					 estate. The answer is now used, as it already was in the first cousins block
					 below: a side of ego's family with no ancestor in common with the dead relative
					 contributes nobody. A nil parent of ego is refused by the same test, since
					 commonAncestor then finds no match, or matches nil against nil and answers
					 nil.}
					foundCommonAncestor := false;
					pAncestor := commonAncestor ([pEgo^.father], [getAscendant (pDeadRelative, [man, man]), getAscendant (pDeadRelative, [woman, man])]);
					if (pAncestor <> nil) then begin
						foundCommonAncestor := true;
						getSiblings (pAncestor, nSiblings, SIBLINGS);
					end;
					pAncestor := commonAncestor ([pEgo^.mother], [getAscendant (pDeadRelative, [man, woman]), getAscendant (pDeadRelative, [woman,woman])]);
					if (pAncestor <> nil) then begin
						foundCommonAncestor := true;
						getSiblings (pAncestor, nSiblings, SIBLINGS);
					end;
					{ego is a sibling of one of the dead relative's parents, so at least one side
					 must have answered}
					if not foundCommonAncestor then
						if reportFailure (chk_inh_noCommonAncestor,
								['decedent ', pDeadRelative^.indNumber,
								', kin type ', str_kinship [pDeadRelative^.typeOfKin],
								', ego ', pEgo^.indNumber]) then
							breakOnFailure;
// <<< Claude 2026-09-30 end
					findHeir_siblings (pDeadRelative, nSiblings, SIBLINGS, 6, degree, numOfPossibleHeirs);
 					setLength (SIBLINGS, 0);
				end;
			end;
		end;
		
		// GRAND NIECES and NEPHEWS
		if (pDeadRelative^.typeOfKin = kt_grandNieceNephew) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_grandAuntUncleTree]) then begin
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			degree := 4;
			numOfPossibleHeirs := 0;
			nSiblings := 0;
			setLength (SIBLINGS, 0);
			// children of all the great grand parents, including ego
// >>> Claude 2026-09-30 start
			{N24, the same fault and the same repair as in the nieces and nephews block above. Ego
			 is a grand aunt or grand uncle of the dead relative, so one of ego's parents is one of
			 its great-grandparents, and the other side of ego's family may be no relation of it.
			 Only the side that has an ancestor in common contributes its children.}
			foundCommonAncestor := false;
			pAncestor := commonAncestor ([pEgo^.father], [	getAscendant (pDeadRelative, [man, man, man]),
															getAscendant (pDeadRelative, [man, woman, man]),
															getAscendant (pDeadRelative, [woman, man, man]),
															getAscendant (pDeadRelative, [woman, woman, man])]);
			if (pAncestor <> nil) then begin
				foundCommonAncestor := true;
				getSiblings (pAncestor, nSiblings, SIBLINGS);
			end;
			pAncestor := commonAncestor ([pEgo^.mother], [	getAscendant (pDeadRelative, [man, man, woman]),
															getAscendant (pDeadRelative, [man, woman, woman]),
															getAscendant (pDeadRelative, [woman, man, woman]),
															getAscendant (pDeadRelative, [woman, woman, woman])]);
			if (pAncestor <> nil) then begin
				foundCommonAncestor := true;
				getSiblings (pAncestor, nSiblings, SIBLINGS);
			end;
			if not foundCommonAncestor then
				if reportFailure (chk_inh_noCommonAncestor,
						['decedent ', pDeadRelative^.indNumber,
						', kin type ', str_kinship [pDeadRelative^.typeOfKin],
						', ego ', pEgo^.indNumber]) then
					breakOnFailure;
// <<< Claude 2026-09-30 end
			findHeir_siblings (pDeadRelative, nSiblings, SIBLINGS, 7, degree, numOfPossibleHeirs);				
				
			numOfPossibleHeirs := 0; // we block the computation of inheritance share below and compute it here...
			if isAnHeir (pDeadRelative, pEgo) then begin
				degree := 1;
				share := computeShareInheritance (pDeadRelative, pEgo, degree);
				updateShareInheritance (pDeadRelative, pEgo, share);
			end;
		end;
		
		// GRAND FATHER or GRAND MOTHER
		if (pDeadRelative^.typeOfKin = kt_grandFather) or (pDeadRelative^.typeOfKin = kt_grandMother) then begin
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			numOfPossibleHeirs := 0;
			degree := 1;
			findHeir_descendancy (pDeadRelative, pDeadRelative, [], 3, degree, numOfPossibleHeirs);
			// ego is direct heir if both her/his parents are dead. In that case ego will be a heir of pDeadRelative
			// we will only need to look at ego's and her/his ascendants' numbers of siblings in order to compute ego's share of the inheritance
			numOfPossibleHeirs := 0; // we block the computation of inheritance share below and compute it here...
			if isAnHeir (pDeadRelative, pEgo) then begin
				degree := 1;
				share := computeShareInheritance (pDeadRelative, pEgo, degree);
				updateShareInheritance (pDeadRelative, pEgo, share);
			end;
		end;
		
		// AUNTS and UNCLES
		if (pDeadRelative^.typeOfKin = kt_auntUncle) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_siblingsTree]) then begin
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;

			nSiblings := 0;
			setLength (SIBLINGS, 0);
// >>> Claude 2026-09-30 start
			{N24: the two calls to commonAncestor that stood here were assigned and never read, and
			 unlike the nieces and nephews block they were not needed. What is collected here are
			 the heirs of the dead aunt or uncle, and those are the children of the dead relative's
			 own parents: every one of them shares a parent with the dead relative, so every one of
			 them is a blood sibling of it, the half-siblings included. No side has to be excluded,
			 and the useless assignments are gone so that the two blocks are not read as the same
			 case. Ego reaches this estate through its own parent, who is one of these siblings,
			 and the share is computed below.}
			getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
			getSiblings (pDeadRelative^.mother, nSiblings, SIBLINGS, pDeadRelative);
// <<< Claude 2026-09-30 end
			numOfPossibleHeirs := 0;
			degree := 2;
			findHeir_siblings (pDeadRelative, nSiblings, SIBLINGS, 5, degree, numOfPossibleHeirs);
			setLength (SIBLINGS, 0);

			// ego is direct heir if both her/his parents are dead. In that case ego will be a heir of pDeadRelative
			// we will only need to look at pDeadRelative's heirs in order to compute ego's share of the inheritance
			numOfPossibleHeirs := 0; // we block the computation of inheritance share below and compute it here...
			if isAnHeir (pDeadRelative, pEgo) then begin
				degree := 1;
				share := computeShareInheritance (pDeadRelative, pEgo, degree);
				updateShareInheritance (pDeadRelative, pEgo, share);
			end;
		end;
		
		// FIRST COUSINS
		if (pDeadRelative^.typeOfKin = kt_cousin) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_auntUncleTree]) then begin
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			
			nSiblings := 0;
			setLength (SIBLINGS, 0);
// >>> Claude 2026-09-30 start
			{N24: this block is the one that always used the answer of commonAncestor, and it is
			 the model the two blocks above were brought into line with. Left as it was.}
// <<< Claude 2026-09-30 end
			pAncestor := commonAncestor ([pEgo^.father^.father, pEgo^.mother^.father],
										[getAscendant (pDeadRelative, [man, man]), getAscendant (pDeadRelative, [woman, man])]);
			if (pAncestor <> nil) then begin
				if pAncestor = pEgo^.father^.father then
					getSiblings (pEgo^.father^.father, nSiblings, SIBLINGS)
				else
					getSiblings (pEgo^.mother^.father, nSiblings, SIBLINGS);
			end;
			pAncestor := commonAncestor ([pEgo^.father^.mother, pEgo^.mother^.mother],
										[getAscendant (pDeadRelative, [man, woman]), getAscendant (pDeadRelative, [woman, woman])]);
			if (pAncestor <> nil) then begin
				if pAncestor = pEgo^.father^.mother then
					getSiblings (pEgo^.father^.mother, nSiblings, SIBLINGS)
				else
					getSiblings (pEgo^.mother^.mother, nSiblings, SIBLINGS);
			end;

			numOfPossibleHeirs := 0;
			degree := 3;
			findHeir_siblings (pDeadRelative, nSiblings, SIBLINGS, 7, degree, numOfPossibleHeirs);
			setLength (SIBLINGS, 0);
			// ego is direct heir if both her/his parents are dead. In that case ego will be a heir of pDeadRelative
			// we will only need to look at pDeadRelative's heirs in order to compute ego's share of the inheritance
			numOfPossibleHeirs := 0; // we block the computation of inheritance share below and compute it here...
			if isAnHeir (pDeadRelative, pEgo) then begin
				degree := 1;
				share := computeShareInheritance (pDeadRelative, pEgo, degree);
				updateShareInheritance (pDeadRelative, pEgo, share);
			end;
 		end;
		
		// GREAT GRAND FATHER or GREAT GRAND MOTHER
		if (pDeadRelative^.typeOfKin = kt_greatGrandFather) or (pDeadRelative^.typeOfKin = kt_greatGrandMother) then begin
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;
			numOfPossibleHeirs := 0;
			degree := 1;
			findHeir_descendancy (pDeadRelative, pDeadRelative, [], 3, degree, numOfPossibleHeirs);
			// ego is direct heir if her/his parents and grand parents are are all dead. In that case ego will be a heir of pDeadRelative
			// we will only need to look at pDeadRelative's heirs in order to compute ego's share of the inheritance
			numOfPossibleHeirs := 0; // we block the computation of inheritance share below and compute it here...
			if isAnHeir (pDeadRelative, pEgo) then begin
				degree := 2;
				share := computeShareInheritance (pDeadRelative, pEgo, degree);
				updateShareInheritance (pDeadRelative, pEgo, share);
			end;
		end;
		
		// grand aunts and uncles
		if (pDeadRelative^.typeOfKin = kt_grandAuntUncle) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_siblingsTree]) then begin
			//pDeadRelative^.egoAsHeir := eh_indirectHeir;

			nSiblings := 0;
			setLength (SIBLINGS, 0);
// >>> Claude 2026-09-30 start
			{N24: as in the aunts and uncles block, the two answers of commonAncestor were assigned
			 and never read and are not needed. These are the heirs of the dead grand aunt or grand
			 uncle, and they are the children of the dead relative's own parents, so every one of
			 them is a blood sibling of it.}
			getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
			getSiblings (pDeadRelative^.mother, nSiblings, SIBLINGS, pDeadRelative);
// <<< Claude 2026-09-30 end

			numOfPossibleHeirs := 0;
			degree := 2;
			findHeir_siblings (pDeadRelative, nSiblings, SIBLINGS, 5, degree, numOfPossibleHeirs);
			setLength (SIBLINGS, 0);

			numOfPossibleHeirs := 0; // we block the computation of inheritance share below and compute it here...
			if isAnHeir (pDeadRelative, pEgo) then begin
				degree := 2;
				share := computeShareInheritance (pDeadRelative, pEgo, degree);
				updateShareInheritance (pDeadRelative, pEgo, share);
			end;
		end;

		// we compute inheritance share here, unless numOfPossibleHeirs is zero and this share was computed above
		if (numOfPossibleHeirs = 1) then begin
			//pDeadRelative^.egoAsHeir := eh_onlyHeir;
			setInheritanceInfo (pDeadRelative, pEgo, degree, 1);
		end else if (numOfPossibleHeirs > 1) then begin
			//pDeadRelative^.egoAsHeir := eh_directHeir;
			setInheritanceInfo (pDeadRelative, pEgo, degree, 1 / numOfPossibleHeirs);
		end;
	end;

	procedure lookForInheritance (pEgo: pRelativeType);
	var
		pRelative: pRelativetype;
	begin
		// we check whether ego is heir (or the only heir) of her/his close kin
		// before arriving here, we have previously checked whether
		// the relative has at least one another heir that has preference over ego
		pRelative := pEgo^.nextRelative;
		while (pRelative <> nil) do begin
			checkEgoIsHeir (pEgo, pRelative);
			pRelative := pRelative^.nextRelative;
		end;
	end;

	// #### Second algorithm ####
	{
		// info for each RelativeType
		heirInfo = record
			heir: pRelativeType;
			share: double;
			kinType: KinTypes;
			isHeir: boolean;
		end;
		nHeirs_2: longint;
		heirs_2: array of HeirInfo;
		// in this second algorithm, we copy below the above information for the relatives who inherit
		inheritanceInfo = record
			decedent: pRelativeType;
			share: double;
			kinType: KinTypes;
		end;
		nInheritances_2: longint;
		inheritances_2: array of inheritanceInfo;
	}

	// we don't want to increase the array length by one, which will create
	// a lot of memory fragmentation and slow down the program a lot
const
	incArrHeirsTree = 5;
	
type
	arrayKinTypes = array of KinTypes;
	arrayKinSexTypes = array [Sex] of array of KinTypes;
	
	pHeirsTree = ^HeirsTree;
	HeirsTree = record
		nChildren, nHeirs: integer;
		heirs: arrayOfRelatives;
		branches: array of heirsTree;
	end;
	
	AscendantHeir = record
		kinType: KinTypes;
		heir: pRelativeType;
		lineage: arrayOfSex;	// if [], then we have a father or a mother
								// if ['woman'], then a grandparent is parent of the mother
								// if ['man','man'] we have a great-grandparent who is parent of a grandfather, who on turn is parent of the father
// >>> Claude 2026-09-30 start
		nParentsInLineage: integer;	// N22b: the number of ascendant heirs on the same side of the
									// family as this one, which is what the share is divided by. It
									// used to be the number of heirs in the same line of descent,
									// either 1 or 2. Written by allocateShareAscendantsHeirs_2 and
									// read by nothing, so it is there to be looked at in the debugger
// <<< Claude 2026-09-30 end
	end;
	arrayAscendants = array of AscendantHeir;

	SiblingInfo = record
		pSibling: pRelativeType;
		isHeir: boolean; // the sibling is heir?
		full: boolean; // whether the sibling has both ego's parents or only one (half sibling)
		// if isHeir = false, then we may have nieces and / or nephews as heirs
		nNiecesNephews: integer;
		arrNiecesNephews: arrayOfRelatives;
	end;
	arrayOfSiblings = array of SiblingInfo;
	
	ColateralInfo = record
		pCol: pRelativeType;
		kinType: KinTypes;
		degree: integer;
	end;
	arrayOfColaterals = array of ColateralInfo;

	pColaterals = ^ColateralList;
	ColateralList = record
		nColaterals: integer;
		arrayRel: arrayOfColaterals;
	end;

	pMemoryManagerHeirs = ^MemoryManagerHeirs;
	MemoryManagerHeirs = record
		poolOfColaterals: colateralList;
		heirsTree: HeirsTree;
		arrayAscendants: arrayAscendants;
		poolOfSiblings: arrayOfSiblings;
	end;
	
	{
		KinTypes = (kt_none, (kt_ego), (kt_partner), (kt_child), (kt_grandChild), (kt_greatGrandChild),
				(kt_father), (kt_mother), (kt_sibling), (kt_nieceNephew), (kt_grandNieceNephew), (kt_greatGrandNieceNephew),
				(kt_grandFather), (kt_grandMother), (kt_auntUncle), (kt_cousin), (kt_cousin_removed), (kt_cousin_twice_removed), (kt_cousin_thrice_removed),
				(kt_greatGrandFather), (kt_greatGrandMother), (kt_grandAuntUncle), (kt_great_cousin_removed), (kt_second_cousin), (kt_second_cousin_removed),
				(kt_second_cousin_twice_removed),
				kt_nonBio, kt_total);
	}

	function inverseKin (aKinType: KinTypes; gender: Sex): KinTypes;
	// not finished
	begin
		case aKinType of
			kt_ego, kt_partner, kt_sibling, kt_cousin, kt_cousin_removed: result := aKinType;
			kt_father, kt_mother: result := kt_child;
			kt_grandFather, kt_grandMother: result := kt_grandChild;
			kt_greatGrandFather, kt_greatGrandMother: result := kt_greatGrandChild;
			kt_child:
					if gender = man then
						result := kt_father
					else
						result := kt_mother;
			kt_grandChild:
					if gender = man then
						result := kt_grandFather
					else
						result := kt_grandMother;
			kt_greatGrandChild:
					if gender = man then
						result := kt_greatGrandFather
					else
						result := kt_greatGrandMother;
			kt_nieceNephew: result := kt_auntUncle;
			kt_grandNieceNephew: result := kt_grandAuntUncle;
			kt_greatGrandNieceNephew: result := kt_none;
			kt_auntUncle: result := kt_nieceNephew;
			kt_grandAuntUncle: result := kt_grandNieceNephew;
			kt_cousin_twice_removed, kt_cousin_thrice_removed,
				kt_great_cousin_removed, 
				kt_second_cousin,
				kt_second_cousin_removed,
				kt_second_cousin_twice_removed: result := aKinType;
		end;
	end;
	
	procedure addDecedent_2 (pHeir, pDecedent: pRelativeType; aKinType: KinTypes; aShare: double; addShare: boolean = false);
	var
		indHeir: integer = 0;
		found: boolean = false;
	begin
		if addShare then begin
			// add the share of inheritance received from an existing decedent
			for indHeir := low(pHeir^.Inheritances_2) to high (pHeir^.Inheritances_2) do
				if pHeir^.Inheritances_2 [indHeir].decedent = pDecedent then begin
					found := true;
					break;
				end;
			if not found then begin
				writeAndWait ('ERROR ==> Add share from decedent, not found, decedent: ' + str_kinship [aKinType]);
				exit;
			end;
			pHeir^.Inheritances_2 [indHeir].share := pHeir^.Inheritances_2 [indHeir].share + aShare;
		end else begin
			Inc (pHeir^.nInheritances_2);
			if length (pHeir^.Inheritances_2) < pHeir^.nInheritances_2 then begin
				setLength (pHeir^.Inheritances_2, length (pHeir^.Inheritances_2) + incArrHeirsTree);
			end;
			with pHeir^.Inheritances_2 [pHeir^.nInheritances_2 - 1] do begin
				decedent := pDecedent;
				share := aShare;
				kinType := aKinType;
			end;
		end;
	end;

	procedure checkCoherencyDebug (pRel: pRelativeType);
	begin
		if (pRel <> nil) and (pRel^.nInheritances_2 > 0) and (length (pRel^.Inheritances_2) = 0) then
			memoWriteLn (['Big problem inheritance ', pRel^.indNumber]);
	end;
	
	procedure checkRelDebug (pDecedent, pHeir: pRelativeType);
{	var
		tmp: integer = 0;
}	begin
{		if (pHeir <> nil) and (pHeir^.indNumber = 256640) then begin
			gRelDebug := pHeir;
			exit;
		end;
		if (gRelDebug <> nil) and (gRelDebug^.ageMotherAtChildbirth < 10) then begin
			tmp := tmp + 1;
		end;
		if tmp > 100000 then tmp := 0;
}		checkCoherencyDebug (pDecedent);
		checkCoherencyDebug (pHeir);
	end;

 procedure addHeir_2 (pDecedent, pHeir: pRelativeType; aKinType: KinTypes; aShare: double; addShare: boolean = false);
	var
		indHeir: integer = 0;
		found: boolean = false;
	begin
 		if addShare then begin
			// add the share of inheritance to an existing heir
			for indHeir := low(pDecedent^.Heirs_2) to high (pDecedent^.Heirs_2) do
				if pDecedent^.Heirs_2 [indHeir].heir = pHeir then begin
					found := true;
					break;
				end;
			if not found then begin
				writeAndWait ('ERROR ==> Add share to heir, not found, heir: ' + str_kinship [aKinType]);
				exit;
			end;
			pDecedent^.Heirs_2 [indHeir].share := pDecedent^.Heirs_2 [indHeir].share + aShare;
		end else begin
			Inc (pDecedent^.nHeirs_2);
			if length (pDecedent^.heirs_2) < pDecedent^.nHeirs_2 then begin
				setLength (pDecedent^.heirs_2, length (pDecedent^.heirs_2) + incArrHeirsTree);
			end;
			with pDecedent^.Heirs_2 [pDecedent^.nHeirs_2 - 1] do begin
				heir := pHeir;
				share := aShare;
				kinType := aKinType;
			end;
		end;
		checkRelDebug(pDecedent, pHeir);
		addDecedent_2 (pHeir, pDecedent, inverseKin (aKinType, pDecedent^.gender), aShare, addShare);
	end;

	function partnerIsHeir_2 (pDecedent: pRelativeType; aShare: double; addShare: boolean = false): boolean;
	var
		pPartner: pRelativeType;
	begin
// >>> Claude 2026-09-30 start
		{N26: the test is now partnerCanBeHeir_2, whose three conditions are the ones this
		 routine used to make itself, so that checkHeirs can ask the same question without
		 adding an heir}
		pPartner := getLastPartner (pDecedent);
		result := partnerCanBeHeir_2 (pDecedent);
		if not result then
			exit;
// <<< Claude 2026-09-30 end
		addHeir_2 (pDecedent, pPartner, kt_partner, aShare, addShare);
	end;

	function exploreDescendantHeirsTree_2 (
									pDecedent, pAscendant: pRelativeType;
									degree: integer;
									currDegree: integer;
									pTreeInfo: pHeirsTree
								): integer;
	var
		pChild: pRelativeType;
		indChild: integer;
		nSubHeirs: integer;
		pBranch: pHeirsTree;
	begin
		result := 0;
		if (currDegree > degree) then
			// currDegree is higher than the maximum degree of descendance
			// or the kin is not in the heirs set
			exit;
		Inc (currDegree);
		pTreeInfo^.nChildren := getNumChildren (pAscendant);
		pTreeInfo^.nHeirs := pTreeInfo^.nChildren;
		if pTreeInfo^.nChildren <= 0 then
			exit;
		while length (pTreeInfo^.branches) < pTreeInfo^.nChildren do begin
			setLength (pTreeInfo^.branches, length (pTreeInfo^.branches) + incArrHeirsTree);
			setLength (pTreeInfo^.heirs, length (pTreeInfo^.heirs) + incArrHeirsTree);
		end;
		
		for indChild := 1 to pTreeInfo^.nChildren do begin
			pChild := getChildFromRelative (pAscendant, indChild);
			if not possible_heirFound (pDecedent, pChild) then begin
				// pChild cannot be one of the decedent's heirs, probably because she/he was not alive at her/his death
				// we look for her/his own descendants down to (degree - currDegree + 1)
				pTreeInfo^.heirs[indChild-1] := nil;
				pBranch := @(pTreeInfo^.branches[indChild-1]);
				nSubHeirs := exploreDescendantHeirsTree_2 (pDecedent, pChild, degree, currDegree, pBranch);
				if nSubHeirs = 0 then
					// no further descendants found, so this branch will not receive a share
					Dec (pTreeInfo^.nHeirs);
			end else
				pTreeInfo^.heirs[indChild-1] := pChild;
		end;
		result := pTreeInfo^.nHeirs;
	end;
	
	procedure allocateShareDescendantHeirsTree_2 (
									pDecedent: pRelativeType;
									degree: integer;
									currDegree: integer;
									pTreeInfo: pHeirsTree;
									descendantsTypes: arrayKinTypes;
									share: double = -1
								);
	var
		indChild: integer;
 	begin
		if (currDegree > degree) then
			exit;
		Inc (currDegree);
		if pTreeInfo^.nChildren <= 0 then
			// we should not get there, as the case of a childless decedent should have been caught already
			// but just in case...
			exit;
		if share < 0 then
			exit;
		// allocate share
		for indChild := 1 to pTreeInfo^.nChildren do
			if pTreeInfo^.heirs[indChild-1] <> nil then
				addHeir_2 (
							pDecedent,
							pTreeInfo^.heirs[indChild-1],
							descendantsTypes[currDegree - 2],
							share / pTreeInfo^.nHeirs
						)
			else if (pTreeInfo^.branches[indChild-1].nHeirs > 0) then begin
 				allocateShareDescendantHeirsTree_2 (pDecedent,
													degree, currDegree,
													@(pTreeInfo^.branches[indChild-1]), descendantsTypes,
													share / pTreeInfo^.nHeirs
												);
			end;
	end;
	
	// explore the descendants tree and allocate shares of inheritance "por estirpe" (by descent)
	function DescendantHeirs_2 (
							pDecedent: pRelativeType;
							degree: integer;
							var shareInheritance: double;
							descendantsTypes: arrayKinTypes;
							pTreeInfo: pHeirsTree
							): boolean;
	var
		currDegree: integer;
		nShares: integer;
	begin
		result := false;
		
		currDegree := 1;
		nShares := exploreDescendantHeirsTree_2 (pDecedent, pDecedent,
									degree, currDegree,
									pTreeInfo
								);
		if nShares = 0 then
			exit;
		
		currDegree := 1;
		allocateShareDescendantHeirsTree_2 (pDecedent,
									degree, currDegree,
									pTreeInfo, descendantsTypes,
									shareInheritance
								);
		
		result := true;
		shareInheritance := 0; // nothing left
	end;

	procedure exploreAscendantHeirsTree_2 (
								pDecedent, pAscendant: pRelativeType;
								degree: integer; currDegree: integer;
								arrAscendantsType: arrayKinSexTypes;
								arrHeirs: arrayAscendants;
								var nHeirs: integer;
								var lineage: arrayOfSex
							);
	var
		pFather, pMother: pRelativeType;
		fatherHeir, motherHeir: boolean;
		currLineage: arrayOfSex;
 	begin
		if (currDegree > degree) then
			exit;
		Inc (currDegree);
		pFather := pAscendant^.father;
		pMother := pAscendant^.mother;
		if (pFather = nil) and (pMother = nil) then
			// this relative has no simulated parents
			exit;
		fatherHeir := possible_heirFound (pDecedent, pFather);
		motherHeir := possible_heirFound (pDecedent, pMother);
// >>> Claude 2026-09-30 start
		{N22: the two recursive calls below explore the father's line and the mother's line
		 independently, which is what used to let a grandparent on one side and a
		 great-grandparent on the other inherit together. The generation is now decided by the
		 caller: AscendantHeirs_2 asks for one generation at a time, in order, and keeps the
		 first one that answers. A pass that asks for a generation the two lines have not
		 reached adds nothing, because the test at the top of this routine refuses the call, so
		 the heirs of the pass that answers all belong to the one nearest generation. This
		 routine itself is unchanged.}
// <<< Claude 2026-09-30 end
 		if not fatherHeir and not motherHeir then begin
			// both parents at this level died before the decedent or are excluded, so we explore the parents' ascendants tree
        	if (length(lineage) > 0) then
               currLineage := copy(lineage, 0, length(lineage));
			setLength(currLineage, length(currLineage) + 1);
			currLineage[length(currLineage) - 1] := man;
			exploreAscendantHeirsTree_2 (pDecedent, pFather, degree, currDegree, arrAscendantsType, arrHeirs, nHeirs, currLineage);
			currLineage[length(currLineage) - 1] := woman;
 			exploreAscendantHeirsTree_2 (pDecedent, pMother, degree, currDegree, arrAscendantsType, arrHeirs, nHeirs, currLineage);
		end else if fatherHeir or motherHeir then begin
			if fatherHeir then begin
				Inc (nHeirs);
				arrHeirs[nHeirs-1].kinType := arrAscendantsType[man, currDegree-2];
				arrHeirs[nHeirs-1].heir := pFather;
				arrHeirs[nHeirs-1].lineage := copy (lineage, 0, length(lineage));
				arrHeirs[nHeirs-1].nParentsInLineage := 1;
			end;
			if motherHeir then begin
				Inc (nHeirs);
				arrHeirs[nHeirs-1].kinType := arrAscendantsType[woman, currDegree-2];
				arrHeirs[nHeirs-1].heir := pMother;
				arrHeirs[nHeirs-1].lineage := copy (lineage, 0, length(lineage));
				arrHeirs[nHeirs-1].nParentsInLineage := 1;
			end;
		end;
	end;
	
// >>> Claude 2026-09-30 start
	{N22b: the side of the family an ascendant heir belongs to. The first step of the lineage
	 records it: an empty lineage is a parent, whose own sex gives the side, a lineage of one
	 step is a grandparent and one of two steps a great-grandparent, and in both of those the
	 first step is the parent of the decedent through whom that ascendant is reached.}
	function sideOfAscendantHeir (const aHeir: AscendantHeir): Sex;
	begin
		if length (aHeir.lineage) > 0 then
			result := aHeir.lineage [0]
		else if (aHeir.kinType = kt_mother) then
			result := woman
		else
			result := man;
	end;

	{N22b: the estate of a person whose heirs are ascendants is halved between the father's side
	 and the mother's side of the family, and within a side the heirs of that side take equal
	 parts. A side with no heir at this degree leaves its half to the other side. The heirs are
	 all of one degree, which AscendantHeirs_2 sees to, so no further division by generation
	 enters: with seven great-grandparents alive, four on one side and three on the other, the
	 four take an eighth each and the three take a sixth each, and the two lines within a side
	 are not distinguished. Daniel's rule, 30 September, and the rule of article 810 of the
	 Spanish civil code.

	 The routine used to count the distinct lines of descent present, of which there are two at
	 the grandparents and four at the great-grandparents, and give each line an equal part. The
	 two rules agree whenever the two sides hold the same number of lines, which is why the
	 difference showed only in the rarer shapes of estate: three great-grandparents in three
	 different lines used to take a third each and now take a quarter, a quarter and a half.}
	procedure allocateShareAscendantsHeirs_2 (
								pDecedent: pRelativeType;
								nHeirs: integer;
								arrHeirs: arrayAscendants;
								shareInheritance: double
							);
	var
		indHeir: integer;
		nOnSide: array [Sex] of integer;
		shareOfSide: double;
		side: Sex;
	begin
		nOnSide [man] := 0;
		nOnSide [woman] := 0;
		for indHeir := 1 to nHeirs do
			Inc (nOnSide [sideOfAscendantHeir (arrHeirs[indHeir-1])]);
		if (nOnSide [man] > 0) and (nOnSide [woman] > 0) then
			shareOfSide := shareInheritance / 2
		else
			{only one side has an heir at this degree, and it takes the whole estate}
			shareOfSide := shareInheritance;
		for indHeir := 1 to nHeirs do begin
			side := sideOfAscendantHeir (arrHeirs[indHeir-1]);
			arrHeirs[indHeir-1].nParentsInLineage := nOnSide [side];
			addHeir_2 (
						pDecedent,
						arrHeirs[indHeir-1].heir,
						arrHeirs[indHeir-1].kinType,
						shareOfSide / nOnSide [side]
					);
		end;
	end;
// <<< Claude 2026-09-30 end

	function AscendantHeirs_2 (pDecedent: pRelativeType; var shareInheritance: double; arrHeirs: arrayAscendants): boolean;
	var
		arrAscendantsType: arrayKinSexTypes;
		degree, currDegree: integer;
		nHeirs: integer = 0;
		currLineage: arrayOfSex;
// >>> Claude 2026-09-30 start
		indHeir: integer;
// <<< Claude 2026-09-30 end
	begin
		result := false;
		setLength(arrAscendantsType[man], kNbGenerationsAscendantHeirs);
		setLength(arrAscendantsType[woman], kNbGenerationsAscendantHeirs);
		arrAscendantsType[man] := [kt_father, kt_grandFather, kt_greatGrandFather];
		arrAscendantsType[woman] := [kt_mother, kt_grandMother, kt_greatGrandMother];
// >>> Claude 2026-09-30 start
		{N22: one pass for each generation in turn, keeping the first generation that holds an
		 heir. The estate of a person with no descendant goes to the ascendants of the nearest
		 degree and to no other, so a surviving grandmother excludes every great-grandparent,
		 whichever line each of them belongs to. The exploration used to be made once, with
		 degree set to the last generation, and the father's line and the mother's line were
		 then free to stop at different generations: a grandparent on one side and a
		 great-grandparent on the other inherited together and every share came out too small.
		 Passing degree as the one generation to reach, and stopping at the first generation
		 that answers, leaves exploreAscendantHeirsTree_2 and the allocation of the shares
		 untouched: a pass that finds no heir at the generation asked for adds nothing, since
		 the recursion that would go further is refused by the test at the top of the routine.}
		for degree := 1 to kNbGenerationsAscendantHeirs do begin
			nHeirs := 0;
			currDegree := 1;
			setLength (currLineage, 0);
			exploreAscendantHeirsTree_2 (pDecedent, pDecedent, degree, currDegree, arrAscendantsType, arrHeirs, nHeirs, currLineage);
			if nHeirs > 0 then begin
				{the heirs of one pass all belong to the generation that pass asked for, which is
				 what the length of the lineage records. The property holds because the earlier
				 generations were asked for first and answered nothing, so it is worth stating}
				for indHeir := 2 to nHeirs do
					if (length (arrHeirs[indHeir-1].lineage) <> length (arrHeirs[0].lineage)) then
						if reportFailure (chk_inh_ascendantsSameDegree,
								['relative ', pDecedent^.indNumber, ', heirs ', nHeirs,
								', generation ', degree]) then
							breakOnFailure;
				break;
			end;
		end;
// <<< Claude 2026-09-30 end
		if nHeirs > 0 then begin
			allocateShareAscendantsHeirs_2 (pDecedent, nHeirs, arrHeirs, shareInheritance);
			result := true;
			shareInheritance := 0;
		end;
		setLength(arrAscendantsType[man], 0);
		setLength(arrAscendantsType[woman], 0);
		setLength(currLineage, 0);
	end;

	// add the relative to the pool of colaterals, preventing multiple inclusions
	// but does not check whether the relative is a colateral
	procedure addColateralToPool_2 (
							pRelative: pRelativeType;
							aKinType: KinTypes;
							degreeRel: integer;
							poolOfColaterals: pColaterals
						);
	var
		ind: integer;
	begin
		for ind := 1 to poolOfColaterals^.nColaterals do
			if poolOfColaterals^.arrayRel [ind - 1].pCol = pRelative then
				exit; // the relative is already in the pool!
		Inc(poolOfColaterals^.nColaterals);
		if (length(poolOfColaterals^.arrayRel) < poolOfColaterals^.nColaterals) then
			setLength(poolOfColaterals^.arrayRel, length(poolOfColaterals^.arrayRel) + incArrHeirsTree);
		with poolOfColaterals^.arrayRel [poolOfColaterals^.nColaterals - 1] do begin
			pCol := pRelative;
			kinType := aKinType;
			degree := degreeRel;
		end;
	end;
	
	procedure addGrandNiecesNephews_2 (pDecedent, pNieceNephew: pRelativeType; poolOfColaterals: pColaterals);
	var
		indChild: integer;
		pGrandNieceNephew: pRelativeType;
	begin
		if getNumChildren (pNieceNephew) <= 0 then exit;
		for indChild := 1 to getNumChildren (pNieceNephew) do begin
			pGrandNieceNephew := getChildFromRelative (pNieceNephew, indChild);
			if possible_heirFound (pDecedent, pGrandNieceNephew) then begin
				addColateralToPool_2 (pGrandNieceNephew, kt_grandNieceNephew, 4, poolOfColaterals);
			end;
		end;
	end;
	
	procedure addNiecesNephewsToPool_2 (
						pDecedent, pSib: pRelativeType;
						var poolOfSiblings: arrayOfSiblings;
						fullSib: boolean;
						var nSibTrees: integer;
						poolOfColaterals: pColaterals);
	var
		indChild: integer;
		pNieceNephew: pRelativeType;
		heirsInTree: boolean = false;
	begin
		if getNumChildren (pSib) <= 0 then exit;
		// first check whether we have nieces or nephews who are possible heirs
		for indChild := 1 to getNumChildren (pSib) do begin
			pNieceNephew := getChildFromRelative (pSib, indChild);
			if possible_heirFound (pDecedent, pNieceNephew) then begin
				heirsInTree := true;
				Inc (nSibTrees); // the sibling is dead, but she/he has at least one child that can be heir
				if length(poolOfSiblings) < nSibTrees then
					setLength(poolOfSiblings, length(poolOfSiblings) + incArrHeirsTree);
				with poolOfSiblings [nSibTrees-1] do begin
					pSibling := pSib;
					nNiecesNephews := 0;
					arrNiecesNephews := nil;
					isHeir := false;
					full := fullSib;
				end;
				break; // we have found one living niece-nephew. Exit the loop to add them all
			end;
		end;
		if heirsInTree then begin
			// add living nieces and nephews to the sibling tree
			for indChild := 1 to getNumChildren (pSib) do begin
				pNieceNephew := getChildFromRelative (pSib, indChild);
				if possible_heirFound (pDecedent, pNieceNephew) then begin
					with poolOfSiblings [nSibTrees-1] do begin
						Inc (nNiecesNephews);
						if length(arrNiecesNephews) < nNiecesNephews then
							setLength(arrNiecesNephews, length(arrNiecesNephews) + incArrHeirsTree);
						arrNiecesNephews[nNiecesNephews-1] := pNieceNephew;
					end;
                end;
            end;
        end;

		// check for grand nieces / nephews (we will have them in case all the sibling trees are empty)
		for indChild := 1 to getNumChildren (pSib) do begin
			pNieceNephew := getChildFromRelative (pSib, indChild);
			addGrandNiecesNephews_2 (pDecedent, pNieceNephew, poolOfColaterals);
        end;

    end;
	
	procedure addSiblingToPool_2 (
					pDecedent, pSib: pRelativeType;
					var poolOfSiblings: arrayOfSiblings;
					var nSibTrees: integer;
					poolOfColaterals: pColaterals);
	var
		indSib: integer;
		fullSib: boolean;
	begin
		// full and half siblings...
		// if at least one sibling is alive, then nieces and nephews inherit the share of their parent
		// if there are no sibling alive, living nieces and nephews inherit the same portion
		// if there are only grand nieces and nephews alive, living aunts and uncles (degree 3) have priority
		// if no aunt/uncle, grand nieces and nephews receive the same portion, together with any living first cousin or grand aunt/uncle (degree 4)
		if nSibTrees > 0 then
			for indSib := 1 to nSibTrees do
				if pSib = poolOfSiblings[indSib-1].pSibling then
					exit; // already in the pool
		fullSib := (pSib^.father = pDecedent^.father) and (pSib^.mother = pDecedent^.mother);
		if possible_heirFound (pDecedent, pSib) then begin
			Inc (nSibTrees);
			if length(poolOfSiblings) < nSibTrees then
				setLength(poolOfSiblings, length(poolOfSiblings) + incArrHeirsTree);
			with poolOfSiblings [nSibTrees-1] do begin
				pSibling := pSib;
				nNiecesNephews := 0;
				setLength(arrNiecesNephews, 0);
				isHeir := true;
				full := fullSib;
			end;
		end else begin
			addNiecesNephewsToPool_2 (pDecedent, pSib, poolOfSiblings, fullSib, nSibTrees, poolOfColaterals);
		end;
	end;
	
	procedure addSiblings_2 (
					pDecedent, pParent: pRelativeType;
					var poolOfSiblings: arrayOfSiblings;
					var nSibTrees: integer;
					poolOfColaterals: pColaterals
				);
	var
		indSib: integer;
		pSib: pRelativeType;
		nChildren: integer;
	begin
		if pParent = nil then exit;
		
		nChildren := getNumChildren (pParent);
		if nChildren = 1 then exit; // pDecedent is only child for this parent
		for indSib := 1 to nChildren do begin
			pSib := getChildFromRelative (pParent, indSib);
			if not (pSib = pDecedent) then
				addSiblingToPool_2 (pDecedent, pSib, poolOfSiblings, nSibTrees, poolOfColaterals);
		end;
	end;

	function allocateShareSiblingTreeHeirs_2 (
										pDecedent: pRelativeType;
										poolOfSiblings: arrayOfSiblings;
										nSibTrees: integer;
										shareInheritance: double
									): boolean;
	var
		indHeir, indHeir2, nSiblings, nNiecesNephews: integer;
		nPart, nShares, shareNieceNephew: double;
	begin
		result := false;
		// first determine the number of living siblings and if any, the number of shares
		// as well as the number of nieces and / or nephews who inherit their parent's share or an equal share if no sibling is living
		nShares := 0;
		nSiblings := 0;
		nNiecesNephews := 0;
		for indHeir := 1 to nSibTrees do begin
			if poolOfSiblings[indHeir-1].isHeir or (poolOfSiblings[indHeir-1].nNiecesNephews > 0) then begin
				if poolOfSiblings[indHeir-1].isHeir then
					Inc (nSiblings)
				else
					nNiecesNephews := nNiecesNephews + poolOfSiblings[indHeir-1].nNiecesNephews;
				if poolOfSiblings[indHeir-1].full then
					nShares := nShares + 1
				else
					nShares := nShares + 0.5;
			end;
		end;

		if (nSiblings > 0) or (nNiecesNephews > 0) then begin
			result := true;
			for indHeir := 1 to nSibTrees do begin
				if poolOfSiblings[indHeir-1].full then
					nPart := 1
				else
					nPart := 0.5;
				if poolOfSiblings[indHeir-1].isHeir then
					addHeir_2 (
						pDecedent,
						poolOfSiblings[indHeir-1].pSibling,
						kt_sibling,
						shareInheritance * nPart / nShares
					)
				else if poolOfSiblings[indHeir-1].nNiecesNephews > 0 then begin
					if nSiblings > 0 then
						// if at least one sibling is alive, nieces and nephews
						// share their parent's inheritance
						shareNieceNephew := (shareInheritance * nPart / nShares) / poolOfSiblings[indHeir-1].nNiecesNephews
					else
						// if all the siblings are dead, the nieces and nephews receive the same share
						shareNieceNephew := shareInheritance / nNiecesNephews;
					for indHeir2 := 1 to poolOfSiblings[indHeir-1].nNiecesNephews do
						addHeir_2 (
							  pDecedent,
							  poolOfSiblings[indHeir-1].arrNiecesNephews[indHeir2-1],
							  kt_nieceNephew,
							  shareNieceNephew
						  );
				end;
			end;
		end;
	end;

	function SiblingHeirs_2 (
					pDecedent: pRelativeType;
					shareInheritance: double;
					var poolOfSiblings: arrayOfSiblings;
					poolOfColaterals: pColaterals
					): boolean;
	var
		pParent: pRelativeType;
		nSibTrees: integer = 0;
	begin
		result := false;

        addSiblings_2 (pDecedent, pDecedent^.father, poolOfSiblings, nSibTrees, poolOfColaterals);
		addSiblings_2 (pDecedent, pDecedent^.mother, poolOfSiblings, nSibTrees, poolOfColaterals);
		if nSibTrees = 0 then
			exit;
		if allocateShareSiblingTreeHeirs_2 (pDecedent, poolOfSiblings, nSibTrees, shareInheritance) then
			result := true;
		setLength (poolOfSiblings, 0);
	end;

	function countKinPool_2 (aKinType: KinTypes; poolOfColaterals: pColaterals): integer;
	var
		ind: integer;
	begin
		result := 0;
		for ind := 1 to poolOfColaterals^.nColaterals do
			if poolOfColaterals^.arrayRel[ind-1].kinType = aKinType then
				result := result + 1;
	end;
	
	procedure addAuntUncleAndFirstCousins_2 (pDecedent, pGrandParent: pRelativeType; poolOfColaterals: pColaterals);
	var
		indChild, indCousin: integer;
		pRelative, pCousin: pRelativeType;
	begin
		if getNumChildren (pGrandParent) <= 0 then exit;
		for indChild := 1 to getNumChildren (pGrandParent) do begin
			pRelative := getChildFromRelative(pGrandParent, indChild);
			if (pRelative = pDecedent^.father) or (pRelative = pDecedent^.mother) then
				continue;
			if possible_heirFound (pDecedent, pRelative) then
				addColateralToPool_2 (pRelative, kt_auntUncle, 3, poolOfColaterals)
			else begin
				// the aunt or uncle is not an heir. We look at first cousins
				if getNumChildren (pRelative) <= 0 then continue;
				for indCousin := 1 to getNumChildren (pRelative) do begin
					pCousin := getChildFromRelative(pRelative, indCousin);
					if possible_heirFound (pDecedent, pCousin) then
						addColateralToPool_2 (pCousin, kt_cousin, 4, poolOfColaterals);
				end;
			end;
		end;
	end;
	
	procedure auntUnclesAndFirstCousins_2 (pDecedent: pRelativeType; poolOfColaterals: pColaterals);
	begin
		if pDecedent^.father <> nil then begin
			if pDecedent^.father^.father <> nil then
				addAuntUncleAndFirstCousins_2 (pDecedent, pDecedent^.father^.father, poolOfColaterals);
			if pDecedent^.father^.mother <> nil then
				addAuntUncleAndFirstCousins_2 (pDecedent, pDecedent^.father^.mother, poolOfColaterals);
		end;
		if pDecedent^.mother <> nil then begin
			if pDecedent^.mother^.father <> nil then
				addAuntUncleAndFirstCousins_2 (pDecedent, pDecedent^.mother^.father, poolOfColaterals);
			if pDecedent^.mother^.mother <> nil then
				addAuntUncleAndFirstCousins_2 (pDecedent, pDecedent^.mother^.mother, poolOfColaterals);
		end;
	end;
	
	procedure addGrandAuntUncle_2 (pDecedent, pParent: pRelativeType; poolOfColaterals: pColaterals);
	var
		indChild: integer;
		pRelative: pRelativeType;
	begin
		if pParent = nil then exit;
		if getNumChildren (pParent) <= 0 then exit;
		for indChild := 1 to getNumChildren (pParent) do begin
			pRelative := getChildFromRelative(pParent, indChild);
			if possible_heirFound (pDecedent, pRelative) then
				addColateralToPool_2 (pRelative, kt_grandAuntUncle, 4, poolOfColaterals);
		end;
	end;
	
	procedure grandAuntUncles_2 (pDecedent: pRelativeType; poolOfColaterals: pColaterals);
	begin
		if pDecedent^.father <> nil then begin
			if pDecedent^.father^.father <> nil then begin
				addGrandAuntUncle_2 (pDecedent, pDecedent^.father^.father^.father, poolOfColaterals);
				addGrandAuntUncle_2 (pDecedent, pDecedent^.father^.father^.mother, poolOfColaterals);
			end;
			if pDecedent^.father^.mother <> nil then begin
				addGrandAuntUncle_2 (pDecedent, pDecedent^.father^.mother^.father, poolOfColaterals);
				addGrandAuntUncle_2 (pDecedent, pDecedent^.father^.mother^.mother, poolOfColaterals);
			end;
		end;
		if pDecedent^.mother <> nil then begin
			if pDecedent^.mother^.father <> nil then begin
				addGrandAuntUncle_2 (pDecedent, pDecedent^.mother^.father^.father, poolOfColaterals);
				addGrandAuntUncle_2 (pDecedent, pDecedent^.mother^.father^.mother, poolOfColaterals);
			end;
			if pDecedent^.mother^.mother <> nil then begin
				addGrandAuntUncle_2 (pDecedent, pDecedent^.mother^.mother^.father, poolOfColaterals);
				addGrandAuntUncle_2 (pDecedent, pDecedent^.mother^.mother^.mother, poolOfColaterals);
			end;
		end;
	end;

	function Colaterals_2 (
					pDecedent: pRelativeType;
					shareInheritance: double;
					poolOfColaterals: pColaterals
					): boolean;
	var
		nAuntUncles: integer = 0;
		nFirstCousins: integer = 0;
		nGrandNiecesNephews: integer = 0;
		nGrandAuntUncles: integer = 0;
		nRelativesDegree4: integer = 0;
		pRelative: pRelativeType;
		indRel: integer;
		check_nCol: integer = 0;
		isEgo: boolean = false;
	begin
		result := false;
		if (pDecedent^.typeOfKin = kt_ego) then
			isEgo := true;
		// aunt-uncle and first cousin
		auntUnclesAndFirstCousins_2 (pDecedent, poolOfColaterals);
		nAuntUncles := countKinPool_2 (kt_auntUncle, poolOfColaterals);
		nFirstCousins := countKinPool_2 (kt_cousin, poolOfColaterals);
		nGrandNiecesNephews := countKinPool_2 (kt_grandNieceNephew, poolOfColaterals);
		// grand-aunt-uncle
		if (nAuntUncles = 0) then begin
			// aunts and uncles have degree 3 and inherit before grandAuntUncles
			grandAuntUncles_2 (pDecedent, poolOfColaterals);
			nGrandAuntUncles := countKinPool_2 (kt_grandAuntUncle, poolOfColaterals)
		end;
		nRelativesDegree4 := nGrandAuntUncles + nFirstCousins + nGrandNiecesNephews;
		if nAuntUncles > 0 then begin
			// aunt and uncles are degree 3 and receive the same share, even if "full" or "half"
			result := true;
			for indRel := 1 to poolOfColaterals^.nColaterals do
				if poolOfColaterals^.arrayRel[indRel-1].kinType = kt_auntUncle then
					addHeir_2 (
							pDecedent,
							poolOfColaterals^.arrayRel[indRel-1].pCol,
							kt_auntUncle,
							shareInheritance / nAuntUncles
						);
		end else begin
			// the rest of colaterals are degree 4 and receive the same share
			if nRelativesDegree4 > 0 then begin
				result := true;
				for indRel := 1 to poolOfColaterals^.nColaterals do begin
					Inc (check_nCol);
					addHeir_2 (
							pDecedent,
							poolOfColaterals^.arrayRel[indRel-1].pCol,
							poolOfColaterals^.arrayRel[indRel-1].kinType,
							shareInheritance / nRelativesDegree4
						);
				end;
				if check_nCol <> nRelativesDegree4 then
					writeAndWaitConst(['ERROR ==> bad count of heirs of degree 4'])
			end;
			
		end;
	end;

	procedure checkTreeForHeirs_2 (pDecedent: pRelativeType; pMemData: pMemoryManagerHeirs);
	var
		degree, currDegree: integer;
		shareInheritance: double = 1;
 	begin
		// If partner comes first, check she/he is an heir (partial or full)
		if g_GENPARAM.PARTNER_FIRST_HEIR.value then
			if g_GENPARAM.PARTNER_FULL_HEIR.value then begin
				if partnerIsHeir_2 (pDecedent, 1) then begin
					shareInheritance := 0;
					exit;
				end;
			end else
				if partnerIsHeir_2 (pDecedent, 0.5) then
					shareInheritance := 0.5;

		// Descendance
		degree := 3;
		pMemData^.heirsTree.nChildren := 0;
		pMemData^.heirsTree.nHeirs := 0;
		if DescendantHeirs_2 (pDecedent, degree, shareInheritance, [kt_child, kt_grandChild, kt_greatGrandChild], @(pMemData^.heirsTree)) then
			exit;
		
		// Ascendance
		if AscendantHeirs_2 (pDecedent, shareInheritance, pMemData^.arrayAscendants) then
			exit;
 
 		// Partner with what is left...
 		if partnerIsHeir_2 (pDecedent, shareInheritance, g_GENPARAM.PARTNER_FIRST_HEIR.value) then
			exit;

 		// Sibling trees
 		pMemData^.poolOfColaterals.nColaterals := 0;
 		if SiblingHeirs_2 (pDecedent, shareInheritance, pMemData^.poolOfSiblings, @(pMemData^.poolOfColaterals)) then
 			exit;
 		
 		// Rest of colaterals, including grand nieces-nephews:
 		// aunt-uncle, first cousin, grand-aunt-uncle: they receive the same share, but the degree counts
 		// therefore living aunt-uncles (of degree 3) exclude all other colateral heirs of degree 4
 		if Colaterals_2 (pDecedent, shareInheritance, @(pMemData^.poolOfColaterals)) then
 			exit;
 		
 		setLength (pMemData^.poolOfColaterals.arrayRel, 0);
 		// The decedent has no heirs...
 		if (pDecedent^.nHeirs_2 > 0) then
 			memoWriteLn (['Decedent should have no heir, but have: ', pDecedent^.nHeirs_2]);
	end;

	procedure breakPoint (pRel: pRelativeType; arrIndNumber: arrayOfLongint);
	var
		ind: integer;
		tmp: integer = 0;
	begin
		 for ind := low (arrIndNumber) to high (arrIndNumber) do begin
		 	 if (pRel^.indNumber <> arrIndNumber[ind]) then continue;
			 	 tmp := tmp + 1;
		 end;
	end;

	procedure initInheritance(pMemData: pMemoryManagerHeirs);
	begin
		setLength(pMemData^.arrayAscendants, 8); // 8 is the maximum if all great granparents are alive when parents and grandparents are dead!
		// in Spain the ascendants get all the inheritance if there is no descendant alive
	end;

	procedure cleanTreeInfo (pTreeInfo: pHeirsTree);
	var
		ind: integer;
		branch: heirsTree;
	begin
		for ind := 1 to pTreeInfo^.nChildren do
		begin
			if (pTreeInfo^.branches[ind-1].nChildren > 0) then begin
				branch := pTreeInfo^.branches[ind-1];
				cleanTreeInfo (@branch);
			end;
		end;
		setLength(pTreeInfo^.branches, 0);
		setLength(pTreeInfo^.heirs, 0);
	end;
		
	procedure endInheritance(pMemData: pMemoryManagerHeirs);
	var
		ind: integer;
	begin
		cleanTreeInfo (@(pMemData^.heirsTree));
		for ind := low (pMemData^.arrayAscendants) to high (pMemData^.arrayAscendants) do
			setLength (pMemData^.arrayAscendants[ind].lineage, 0);
		setLength (pMemData^.arrayAscendants, 0);
		for ind := low (pMemData^.poolOfSiblings) to high (pMemData^.poolOfSiblings) do
			setLength (pMemData^.poolOfSiblings[ind].arrNiecesNephews, 0);
		setLength (pMemData^.poolOfSiblings, 0);
		setLength (pMemData^.poolOfColaterals.arrayRel, 0);
	end;

 procedure lookForHeirs_Spain (pEgo: pRelativeType);
	var
		pDecedent: pRelativetype;
		dataHeirs: MemoryManagerHeirs;
	begin
		initInheritance (@dataHeirs);
		pDecedent := pEgo;
		while (pDecedent <> nil) do begin
			if gRunFromIDE then
				breakPoint (pDecedent, [5658389]);
			if (pDecedent^.typeOfKin = kt_ego) or (pDecedent^.typeOfKin in g_GENPARAM.HEIRS_KINTYPES.value) then
				checkTreeForHeirs_2 (pDecedent, @dataHeirs);
			pDecedent := pDecedent^.nextRelative;
		end;
		
		endInheritance (@dataHeirs);
		if gRelDebug <> nil then gRelDebug := nil;
	end;
	
// BUG  **N25**  the country rule set is never consulted, and this entry point is empty
// Two faults that belong together.
// (a) This procedure has an empty body, yet Kinship calls it after lookForHeirs_Spain as
//     the second half of the second algorithm. Whatever it was meant to do, the decedents
//     of the second algorithm are produced by checkTreeForHeirs_2 alone.
// (b) COUNTRY_INHERITANCE_RULES is a real parameter: it is created in Init with the default
//     inher_Spain, saved and read by ReadCmdFileUnit, and bound to a combo box in
//     LazOutput. Nothing reads its value. Both algorithms run unconditionally on every run,
//     so the choice offered to the user has no effect at all.
// Proposed fix: decide first what the parameter is for (**Q4**). If it selects between rule
// sets, then this procedure is where the country branch belongs, and the caller in Kinship
// should run one algorithm or the other rather than both. If it is a leftover, remove the
// parameter, its combo box, its reader and its writer, and delete this stub with them.
	procedure lookForDecedents_Spain (pEgo: pRelativeType);
	begin
	end;
// END BUG

	function heirsInKinSet (heirs: arrayHeirInfo; nHeirs: longint; ks: KinSetType): boolean;
	var
		ind: integer;
	begin
		result := true;
		for ind := 1 to nHeirs do
			if not (heirs[ind-1].kinType in ks) then begin
				result := false;
				break;
			end;
	end;
	
	function checkInheritances (pRelative: pRelativeType): integer;
	var
		ind: integer;
	begin
		result := kNotDefined;
		if pRelative^.typeOfKin <> kt_ego then exit;
		result := 1;
		with pRelative^ do begin
			if nInheritances <> nInheritances_2 then begin
				result := 0;
				exit;
			end;
			if nInheritances = nInheritances_2 then
				for ind := 1 to nInheritances do
					if inheritances[ind-1].pDeadRelative <> inheritances_2[ind-1].decedent then begin
						result := 0;
						exit;
					end;
		end;
	end;

// >>> Claude 2026-09-30 start
	{N26: the kin types the branch named by the first algorithm covers. That algorithm answers
	 with a branch of the kinship tree and not with a list of persons, so this is the set the
	 heirs found by the second algorithm must belong to.}
	function kinSetOfBranch (aTypeHeir: typeOfHeirs): KinSetType;
	begin
		case aTypeHeir of
			th_childrenTree:
				result := [kt_child, kt_grandChild, kt_greatGrandChild];
			th_ascendantsTree:
				result := [kt_father, kt_mother,
							kt_grandFather, kt_grandMother,
							kt_greatGrandFather, kt_greatGrandMother];
			th_partner:
				result := [kt_partner];
			th_siblingsTree:
				result := [kt_sibling, kt_nieceNephew, kt_grandNieceNephew];
			th_auntUncleTree:
				result := [kt_auntUncle, kt_cousin];
			th_grandAuntUncleTree:
				result := [kt_grandAuntUncle];
		else
			{th_doNotApply and th_none name no heir at all}
			result := [];
		end;
	end;

	{N26: every heir the first algorithm listed is also one of the heirs of the second. The
	 comparison is made on the identity of the person, so it does not depend on the order of
	 the two lists. It is a one way test: the first algorithm fills its list of heirs only for
	 the relatives from whom ego inherits, and only with ego and, in one case, with one of
	 ego's parents, so its list is a part of the list of the second algorithm and not the whole
	 of it.}
	function heirsConfirmed (const heirsOne: arrayOfRelatives; nOne: longint;
							const heirsTwo: arrayHeirInfo; nTwo: longint): boolean;
	var
		indOne, indTwo: longint;
		found: boolean;
	begin
		result := true;
		for indOne := 1 to nOne do begin
			found := false;
			for indTwo := 1 to nTwo do
				if (heirsTwo [indTwo - 1].heir = heirsOne [indOne - 1]) then begin
					found := true;
					break;
				end;
			if not found then
				exit (false);
		end;
	end;

	{N26: the referee of the two algorithms that look for the heirs of a relative. It returns
	 kNotDefined when neither algorithm looked at this relative, 1 when the two answers
	 are compatible and 0 when they are not, and it records each kind of disagreement as a
	 check of its own. Kinship calls it only when INHERITANCE and DEBUG are both set, and its
	 value is written to one column of the individual kinship file.

	 What is compared, given that the first algorithm names a branch of the tree while the
	 second lists the heirs and their shares:
	   whether both found heirs or both found none,
	   whether the kin types of the heirs of the second lie in the branch named by the first,
	   whether the heirs the first listed are among the heirs of the second.
	 The branch named by the first algorithm is widened by the partner when the succession rules
	 give the partner a share alongside the descendants or the ascendants, which is what
	 PARTNER_FIRST_HEIR and PARTNER_FULL_HEIR decide. This is the part of N26 that the partner
	 field of the relative record was added for: the first algorithm used to report the partner
	 only when no descendant and no ascendant inherited.

	 A disagreement over collateral heirs is expected as long as the two algorithms describe
	 them differently: the first names one branch, the sibling tree or the aunts and uncles or
	 the grand-aunts and grand-uncles, whereas the second applies the rule of the degree, under
	 which all collateral kin of the nearest degree inherit together. See the collateral item
	 of the TODO.}
	function checkHeirs (pRelative: pRelativeType): integer;
	var
		expectedKin: KinSetType;
	begin
		result := kNotDefined;
		with pRelative^ do begin
			if (typeHeir = th_doNotApply) then
				{the first algorithm did not look for this relative's heirs, so there is nothing to
				 compare}
				exit;
			if not ((typeOfKin = kt_ego) or (typeOfKin in g_GENPARAM.HEIRS_KINTYPES.value)) then
				{the second algorithm looks at ego and at the kin types of HEIRS_KINTYPES, so a
				 relative outside that set has no answer from the second algorithm to compare with.
				 The two algorithms do not cover the same relatives, and without this test the
				 difference of coverage is reported as a disagreement.}
				exit;
			result := 1;

			expectedKin := kinSetOfBranch (typeHeir);
			if partnerCanInherit and g_GENPARAM.PARTNER_FIRST_HEIR.value then
				if g_GENPARAM.PARTNER_FULL_HEIR.value then
					{the partner takes the whole estate, so no other kin inherits}
					expectedKin := [kt_partner]
				else
					{the partner takes a share alongside the branch named by the first algorithm}
					expectedKin := expectedKin + [kt_partner];

			if ((typeHeir = th_none) and (nHeirs_2 > 0))
					or ((typeHeir <> th_none) and (nHeirs_2 = 0)) then begin
				result := 0;
				if reportFailure (chk_inh_heirsFoundByOneOnly,
						['relative ', indNumber, ', branch ', str_typeOfHeirs [typeHeir],
						', heirs of the second algorithm ', nHeirs_2]) then
					breakOnFailure;
				exit;
			end;

			if not heirsInKinSet (heirs_2, nHeirs_2, expectedKin) then begin
				result := 0;
				if reportFailure (chk_inh_heirKinTypes,
						['relative ', indNumber, ', branch ', str_typeOfHeirs [typeHeir],
						', heirs of the second algorithm ', nHeirs_2]) then
					breakOnFailure;
			end;

			if not heirsConfirmed (heirs, nHeirs, heirs_2, nHeirs_2) then begin
				result := 0;
				if reportFailure (chk_inh_heirNotConfirmed,
						['relative ', indNumber, ', heirs of the first algorithm ', nHeirs,
						', of the second ', nHeirs_2]) then
					breakOnFailure;
			end;
		end;
	end;
// <<< Claude 2026-09-30 end
	
end.
