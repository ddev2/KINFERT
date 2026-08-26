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
	uses Kinship, Nuptiality;
	
	const
		k_isHeir = true;
		k_isNotHeir = false;

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
	
// --- CLAUDE 2026-08-26 [4.9] begin -------------------------------------------------
// The warning had no exit, so it fired once per MISSING kin type, not once per run.
// gMinKinSetforEgoInheritance has 25 members; with the DemoCare set of four types 21 of
// them are missing, so 21 messages, and checkInheritanceStatus is called from run_all,
// that is once per cohort and once per replicate. It now reports once, listing what is
// missing. gMinKinSetforEgoInheritance is deliberately NOT reduced: it states which kin
// an inheritance calculation needs in order to be correct, and Spanish succession reaches
// collaterals of the fourth degree, so a smaller set would produce wrong shares silently
// instead of warning that it cannot produce right ones.
// Two questions are left open for the author: whether this should latch gDebugError at
// all, since it is a configuration mismatch and not a program fault; and whether the
// inheritance computation should simply be skipped when the kin set cannot support it.
// was:
//	procedure checkInheritanceStatus();
//	var
//		aKin: KinTypes;
//	begin
//		if g_GENPARAM.INHERITANCE.value then
//			// check whether we are going to simulate enough kin types in order to study inheritance
//			for aKin in gMinKinSetforEgoInheritance do
//				if not (aKin in gKinToSimulate) then begin
//				// 	not enough kin: we deactivate the options to study inheritance
//	{				if (fn_typeHeirs in g_GENPARAM.OUTPUT_FIELDS.value) or
//						(fn_heirs in g_GENPARAM.OUTPUT_FIELDS.value) then begin
//						Exclude (g_GENPARAM.OUTPUT_FIELDS.value, fn_typeHeirs);
//						Exclude (g_GENPARAM.OUTPUT_FIELDS.value, fn_heirs);
//						Exclude (g_GENPARAM.OUTPUT_FIELDS.value, fn_inheritances);
//						Exclude (g_GENPARAM.OUTPUT_FIELDS.value, fn_shares);
//						Exclude (g_GENPARAM.OUTPUT_FIELDS.value, fn_isHeir);
//					end;
//	}
//					writeAndWait('Warning: ' + str_kinship[akin] + ' not in the set of kin to simulate, when needed for studying inheritance');
//				end;
//	end;
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
// --- CLAUDE 2026-08-26 [4.9] end ---------------------------------------------------
	
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
	
	function partnerHeir (pRelative: pRelativeType): boolean;
	var
		pPartner: pRelativeType;
		ageEndUnion: double;
	begin
		result := false;
		ageEndUnion := getAgeEndUnion (pRelative, pRelative^.nUnions);
		if (ageEndUnion = pRelative^.ageDeath) then begin
			pPartner := getPartner (pRelative, pRelative^.nUnions);
			if possible_heirFound (pRelative, pPartner) then begin
				pRelative^.typeHeir := th_partner;
				exit (true);
			end else // debug (normally cases where both partners die in the same month)
				pRelative := pRelative;
		end;
	end;
	
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
 		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
		if gRunFromIDE then
{$IFNDEF ARM}
			asm int 3 end;
{$ELSE}
			assert(true);
{$ENDIF}
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
				if gRunFromIDE then
{$IFNDEF ARM}
					asm int 3 end;
{$ELSE}
					assert(true);
{$ENDIF}
			end;
		end;
		
		// NIECES and NEPHEWS
		if (pDeadRelative^.typeOfKin = kt_nieceNephew) and (pDeadRelative^.typeHeir in [th_doNotApply, th_none, th_auntUncleTree]) then begin
		// if we come here, the niece or nephew has no living descendant or ascendant, nor a living partner
		// all aunts and uncles (including ego) can therefore be heirs
			numOfPossibleHeirs := 0;
// --- CLAUDE 2026-08-26 [N23] begin --------------------------------------------------
// was:
//			if heirFound_add (pDeadRelative, pDeadRelative^.father, 1) or heirFound_add (pDeadRelative, pDeadRelative^.father, 1) then begin
// The father was tested twice and the mother never, although the comment on the next
// line says "either the father or the mother". The second call was also a guaranteed
// no-op, because heirFound_add exits early on an heir already found. A dead niece or
// nephew whose mother was alive therefore had the estate distributed to the grandparents
// and the aunts and uncles. Short-circuit evaluation is kept, so the mother is tested
// only when the father is not an heir, which is the intended reading.
			if heirFound_add (pDeadRelative, pDeadRelative^.father, 1) or heirFound_add (pDeadRelative, pDeadRelative^.mother, 1) then begin
// --- CLAUDE 2026-08-26 [N23] end ----------------------------------------------------
				// bad as either the father or the mother are alive...
				if gRunFromIDE then
{$IFNDEF ARM}
					asm int 3 end;
{$ELSE}
					assert(true);
{$ENDIF}
			end else begin
				if 	heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [man, man]), 2) or
					heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [man, woman]), 2) or
					heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [woman, man]), 2) or
					heirFound_add (pDeadRelative, getAscendant (pDeadRelative, [woman, woman]), 2) then begin
						// bad as at least one of the grand parents are alive...
					 if gRunFromIDE then
					 {$IFNDEF ARM}
							asm int 3 end
					 {$ENDIF}
					 		;
				end else begin
					// aunts and uncles
					numOfPossibleHeirs := 0;
					degree := 3;
					nSiblings := 0;
					setLength (SIBLINGS, 0);
					// children of all the common ancestors, including ego
					pAncestor := commonAncestor ([pEgo^.father], [getAscendant (pDeadRelative, [man, man]), getAscendant (pDeadRelative, [woman, man])]);
					getSiblings (pEgo^.father, nSiblings, SIBLINGS);
					pAncestor := commonAncestor ([pEgo^.mother], [getAscendant (pDeadRelative, [man, woman]), getAscendant (pDeadRelative, [woman,woman])]);
					getSiblings (pEgo^.mother, nSiblings, SIBLINGS);
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
			pAncestor := commonAncestor ([pEgo^.father], [	getAscendant (pDeadRelative, [man, man, man]),
															getAscendant (pDeadRelative, [man, woman, man]),
															getAscendant (pDeadRelative, [woman, man, man]),
															getAscendant (pDeadRelative, [woman, woman, man])]);
			getSiblings (pEgo^.father, nSiblings, SIBLINGS);
			pAncestor := commonAncestor ([pEgo^.mother], [	getAscendant (pDeadRelative, [man, man, woman]),
															getAscendant (pDeadRelative, [man, woman, woman]),
															getAscendant (pDeadRelative, [woman, man, woman]),
															getAscendant (pDeadRelative, [woman, woman, woman])]);
			getSiblings (pEgo^.mother, nSiblings, SIBLINGS);
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
			pAncestor := commonAncestor ([pDeadRelative^.father], [	pEgo^.father^.father,
																	pEgo^.mother^.father]);
			getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
			pAncestor := commonAncestor ([pDeadRelative^.mother], [	pEgo^.father^.mother,
																	pEgo^.mother^.mother]);
			getSiblings (pDeadRelative^.mother, nSiblings, SIBLINGS, pDeadRelative);
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
			pAncestor := commonAncestor ([pDeadRelative^.father],
										[getAscendant (pEgo, [man, man, man]), getAscendant (pEgo, [man, woman, man]),
										getAscendant (pEgo, [woman, man, man]), getAscendant (pEgo, [woman, woman, man])]);
			getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
			pAncestor := commonAncestor ([pDeadRelative^.mother],
										[getAscendant (pEgo, [man, man, woman]), getAscendant (pEgo, [man, woman, woman]),
										getAscendant (pEgo, [woman, man, woman]), getAscendant (pEgo, [woman, woman, woman])]);
			getSiblings (pDeadRelative^.mother, nSiblings, SIBLINGS, pDeadRelative);

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
		nParentsInLineage: integer; // can be either 1 or 2
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
		share: double;
	begin
		result := false;
		pPartner := getLastPartner (pDecedent);
		if (pPartner = nil) then exit;
		if getCauseEndLastUnion(pDecedent) <> end_by_death then exit;
		result := possible_heirFound (pDecedent, pPartner);
		if not result then
			exit;
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
	
	procedure allocateShareAscendantsHeirs_2 (
								pDecedent: pRelativeType;
								nHeirs: integer;
								arrHeirs: arrayAscendants;
								shareInheritance: double
							);
	var
		nLineages: integer = 0;
		indHeir, indHeir2: integer;
	begin
		if nHeirs = 1 then
			addHeir_2 (
						pDecedent,
						arrHeirs[0].heir,
						arrHeirs[0].kinType,
						shareInheritance
					)
		else if nHeirs = 2 then begin
			{ if there are two heirs, they can either be the two parents
			  or two grandparents or two great-grandparents. In the latter case
			  it does not matter if they are for the same lineage or a different one
			  and they will get the same share of inheritance
			}
			addHeir_2 (
						pDecedent,
						arrHeirs[0].heir,
						arrHeirs[0].kinType,
						shareInheritance / 2
					);
			addHeir_2 (
						pDecedent,
						arrHeirs[1].heir,
						arrHeirs[1].kinType,
						shareInheritance / 2
					);
		end else begin
			{if there at at least 3, they can be either grandparents or great-grandparents.
			 We need to take into account the lineage
			}
			nLineages := nHeirs;
			for indHeir := 1 to (nHeirs-1) do
				for indHeir2 := indHeir+1 to nHeirs do
					if AreArraysEqual_Sex(arrHeirs[indHeir-1].lineage, arrHeirs[indHeir2-1].lineage) then begin
						Dec (nLineages);
						arrHeirs[indHeir-1].nParentsInLineage := 2;
						arrHeirs[indHeir2-1].nParentsInLineage := 2;
					end;
			// Now we can allocate the share to each relative
// --- CLAUDE 2026-08-26 [N21] begin --------------------------------------------------
// was:
//			for indHeir := 1 to (nHeirs-1) do
// The loop is already zero-based through arrHeirs[indHeir-1], so the bound nHeirs-1
// dropped the last ascendant heir while the shares that were paid had been computed
// assuming it would receive one. Four surviving grandparents therefore shared 0.75 of
// the estate and three shared 0.5. The pairing loop just above keeps nHeirs-1, which is
// correct there because it pairs indHeir with indHeir2 running from indHeir+1 to nHeirs.
			for indHeir := 1 to nHeirs do
// --- CLAUDE 2026-08-26 [N21] end ----------------------------------------------------
				addHeir_2 (
							pDecedent,
							arrHeirs[indHeir-1].heir,
							arrHeirs[indHeir-1].kinType,
							shareInheritance / (nLineages * arrHeirs[indHeir-1].nParentsInLineage)
						);
		end
	end;

	function AscendantHeirs_2 (pDecedent: pRelativeType; var shareInheritance: double; arrHeirs: arrayAscendants): boolean;
	var
		arrAscendantsType: arrayKinSexTypes;
		degree, currDegree: integer;
		nHeirs: integer = 0;
		currLineage: arrayOfSex;
	begin
		result := false;
		setLength(arrAscendantsType[man], 3);
		setLength(arrAscendantsType[woman], 3);
		arrAscendantsType[man] := [kt_father, kt_grandFather, kt_greatGrandFather];
		arrAscendantsType[woman] := [kt_mother, kt_grandMother, kt_greatGrandMother];
		degree := 3;
		currDegree := 1;
		setLength(currLineage, 0);
		exploreAscendantHeirsTree_2 (pDecedent, pDecedent, degree, currDegree, arrAscendantsType, arrHeirs, nHeirs, currLineage);
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
	
	procedure lookForDecedents_Spain (pEgo: pRelativeType);
	begin
	end;

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

	function checkHeirs (pRelative: pRelativeType): integer;
	var
		ind: integer;
	begin
		result := 1;
		with pRelative^ do begin
			if (nHeirs = 0) and (nHeirs_2 > 0) then begin
				// there are heirs, but the first algorithm possibly only returns a generic information, like 'childrenTree'
				// typeOfHeirs = (th_doNotApply, th_none, th_childrenTree, th_ascendantsTree,
				// th_partner, th_siblingsTree, th_auntUncleTree, th_grandAuntUncleTree);
				case typeHeir of
					th_doNotApply: ;
					th_none: ;
					th_childrenTree:
						if not heirsInKinSet (heirs_2, nHeirs_2, [kt_child, kt_grandChild, kt_greatGrandChild]) then
							result := 0;
					th_ascendantsTree:
						if not heirsInKinSet (heirs_2, nHeirs_2, [
													kt_father, kt_mother,
													kt_grandFather, kt_grandMother,
													kt_greatGrandFather, kt_greatGrandMother
											]) then
							result := 0;
					th_partner:
						if not heirsInKinSet (heirs_2, nHeirs_2, [kt_partner]) then
							result := 0;
					th_siblingsTree:
						if not heirsInKinSet (heirs_2, nHeirs_2, [kt_sibling, kt_nieceNephew, kt_grandNieceNephew]) then
							result := 0;
					th_auntUncleTree:
						if not heirsInKinSet (heirs_2, nHeirs_2, [kt_auntUncle, kt_cousin]) then
							result := 0;
					th_grandAuntUncleTree: if not heirsInKinSet (heirs_2, nHeirs_2, [kt_grandAuntUncle]) then
						result := 0;
				end; 
			end else if (nHeirs <> nHeirs_2) then begin
				// the first algorithm has a heirs list, but the number is not equal to the second algorithm
				result := 0;
				exit;
			end else if (nHeirs = nHeirs_2) then begin
				// we check the list of heirs returned by both algorithms (this includes the case where the number is 0 for both)
				for ind := 1 to nHeirs do
					if heirs[ind-1] <> heirs_2[ind-1].heir then begin
						result := 0;
						break;
					end;
			end else begin
				// which cases do we have here? In principle none
				result := 0;
				writeAndWait ('ERROR ==> checkHeirs case not caught, with number of heirs' + intToStr (nHeirs) + ' and ' + intToStr (nHeirs_2));
			end;
		end;
	end;
	
end.
