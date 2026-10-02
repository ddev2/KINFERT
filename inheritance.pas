{
	INHERITANCE: WHO INHERITS FROM WHOM, AND WHAT SHARE OF THE ESTATE

	The unit answers two questions about the people in an ego's kinship tree.

	  1. When a relative dies, who are the heirs?
	  2. Of which estates is ego one of the heirs, and what part does ego take?

	Each question is answered twice, by two algorithms written at different times and kept side
	by side on purpose, so that each can be checked against the other. Kinship calls both, and
	neither reads what the other wrote.

	THE FIRST ALGORITHM names a branch of the tree. For each relative it goes down a fixed order
	of preference and stops at the first branch that contains someone who was alive at the death:
	descendants, then ascendants, then the partner, then the siblings and their descendants, then
	the aunts and uncles with their children, then the grand-aunts and grand-uncles. The answer is
	written to the relative's typeHeir field, one value of typeOfHeirs, which names the branch and
	not the persons in it. lookForHeirs makes that pass. checkEgoIsHeir then takes each relative in
	turn, decides whether ego is among the heirs of that branch, and computes ego's share; it
	fills the inheritances list of ego and the heirs list of the dead relative. The arithmetic of
	the shares is in the findHeir_ and computeShare routines.

	THE SECOND ALGORITHM lists the heirs themselves, each with the share it takes, and fills
	heirs_2 and inheritances_2. Its routines carry the suffix _2, its entry point for one relative
	is checkTreeForHeirs_2, and lookForHeirs_Spain walks the tree calling it. It applies the order
	of preference as rules about degree and lineage rather than as a walk through named branches,
	which is why the two can differ over collateral kin while agreeing about the rest.

	THE RULES OF SUCCESSION both algorithms are meant to apply, as stated by the author on 29 and
	30 September 2026, following the Spanish civil code:

	  Descendants take by lineage, with representation. The share of a child who died before the
	  decedent passes to that child's own children, and what a line receives does not depend on
	  the number of people in it.

	  Ascendants and collateral kin are chosen by degree alone. The nearest degree excludes every
	  more distant one, whatever line it belongs to: one surviving grandmother excludes all eight
	  great-grandparents.

	  The estate of a person whose heirs are ascendants is halved between the father's side of the
	  family and the mother's side, and divided equally by head within a side, with no further
	  division between the two lines inside one side. A side with no heir of that degree leaves
	  its half to the other side. This is article 810 of the civil code.

	  Collateral kin of the nearest degree take equal shares. A half-sibling takes half of what a
	  full sibling takes. At degree four the shares are equal, and that is deliberate.

	  The partner's place is set by two parameters. PARTNER_FIRST_HEIR puts the partner before the
	  other kin, and PARTNER_FULL_HEIR then decides whether the partner takes the whole estate or
	  half of it. With PARTNER_FIRST_HEIR off, the partner receives only what the descendants and
	  the ascendants leave.

	WHAT A RELATIVE CARRIES. Each algorithm writes its own pair of lists in the relative record of
	Declarations: heirs and inheritances for the first, heirs_2 and inheritances_2 for the second,
	with nHeirs, nInheritances, nHeirs_2 and nInheritances_2 their lengths. An entry of an
	inheritances list names the decedent and what this person receives from that estate; an entry
	of an heirs list names an heir of this person. The first algorithm also writes typeHeir, the
	branch, and partnerCanInherit, its own answer to the partner question.

	THE REFEREES. checkInheritances and checkHeirs compare the two answers for one relative and
	return 1 when they agree, 0 when they do not, and kNotDefined when neither algorithm looked at
	that relative. Kinship calls them only when INHERITANCE and DEBUG are both set, and writes
	their answers to two columns of the individual kinship file. They decide nothing in a run.

	WHAT IS NOT MODELLED. Whether a posthumous child inherits, what becomes of an estate that has
	no heir, and usufruct, are open questions. COUNTRY_INHERITANCE_RULES does not yet select
	anything: see lookForDecedents_Spain at the end of the unit.
}

{
	A note kept from the sources, on the English rules of intestacy. The program applies the
	Spanish rules set out above, and the two orders of preference are close without being the
	same. It is kept because it is the list the module was first written against.

	The rules of intestacy consist of a hierarchy which gives preference to the closest blood
	relatives of the deceased, as follows: spouse or civil partner; children; grandchildren;
	great-grandchildren; parents; siblings; nephews and nieces; half siblings; half nephews and
	nieces; grandparents; uncles and aunts; first cousins; first cousins once removed; half uncles
	and aunts; half cousins.

	An estranged spouse is still entitled. It does not matter whether children are illegitimate.
	Issue automatically inherit in place of siblings, uncles, aunts or cousins who are deceased.
	Uncles and aunts by marriage are not entitled, nor are brothers and sisters-in-law. A first
	cousin once removed is a child of the deceased's cousin, removed meaning only that they are
	not of the same generation. If there are none of the above, the Crown takes the estate.

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
		
	{ ============================================================================
	  THE FIRST ALGORITHM, FIRST QUESTION: which branch of the tree holds the heirs
	  ============================================================================ }

	{Walks up from a relative along a named path of parents and returns the ancestor it
	 reaches, or nil if any step of the path is missing from the simulated tree. The array
	 names the sex of the parent at each step, read from the relative upwards:
	   [man, woman] is the mother of the father, one of the two grandmothers,
	   [woman, woman, man] is the father of the mother of the mother, one of the four
	   great-grandfathers.}
	function getAscendant (pRelative: pRelativeType; const sexParents: array of Sex): pRelativeType;
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
	
	{Warns, once at the start of a run, that the simulation will not produce every kin type the
	 inheritance rules need. The module can only find an heir among the relatives the run
	 actually builds, so a kin type left out of KIN_TO_SIMULATE silently removes a whole class
	 of possible heirs and moves the estate to the next branch. gMinKinSetforEgoInheritance is
	 the set that has to be there.}
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
	
	{The test every branch of both algorithms rests on: a person can inherit only if alive at
	 the moment of the death. The relative must exist, must not be the dead person, and must
	 have been born before and died after the year of the death. A person born in the same
	 year as the death, or dying in it, is refused, which is the price of comparing years
	 rather than months.}
	function possible_heirFound (pDeadRelative, pPossibleHeir: pRelativeType): boolean;
	begin
		if (pPossibleHeir = nil) or (pDeadRelative = pPossibleHeir) then
			exit (false);
		result := (pDeadRelative^.yearDeath > pPossibleHeir^.yearBirth) and (pDeadRelative^.yearDeath < pPossibleHeir^.yearDeath)
	end;
	
	{Is there anyone alive among the descendants of pOtherRelative, down to downLevel
	 generations, who could inherit from pRelative? It answers yes or no and names nobody.
	 With pOtherRelative equal to pRelative it searches the dead person's own children,
	 grandchildren and great-grandchildren; with a different pOtherRelative it searches that
	 person's descendants, which is how the nieces and nephews, or the first cousins, are
	 reached. The three generations are written out as three nested loops rather than as a
	 recursion, which is why downLevel cannot exceed three.}
	function lookForChildHeir (pRelative, pOtherRelative: pRelativeType; downLevel: longint): boolean;
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
		
	{The descendants branch. True when the relative has a living descendant, and then typeHeir
	 becomes th_childrenTree. How far down it looks depends on how far down the tree the
	 relative itself sits: the tree is built to a fixed depth around ego, so a grandchild of
	 ego has only one generation of its own below it inside the simulated tree, and a child
	 has two.}
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
	
	{The father or the mother of pParent, or nil. A step of one generation upwards, written so
	 that the caller can choose the sex at the call site.}
	function grandParent (pParent: pRelativeType; aSex: Sex): pRelativeType;
	begin
		result := nil;
		if pParent <> nil then
			if aSex = man then
				result := pParent^.father
			else
				result := pParent^.mother
	end;
	
	{The father or the mother of pGrandParent, or nil. pParent is read only as a guard: if the
	 intermediate generation is missing from the tree the answer is nil, whatever the
	 grandparent pointer says.}
	function greatGrandParent (pParent, pGrandParent: pRelativeType; aSex: Sex): pRelativeType;
	begin
		result := nil;
		if pParent <> nil then
			result := grandParent (pGrandParent, aSex)
	end;
	
	{The ascendants branch. True when the relative has a living parent, grandparent or
	 great-grandparent, and then typeHeir becomes th_ascendantsTree. As with the descendants,
	 how far up it may look depends on where the relative sits in the simulated tree: a
	 great-grandparent of ego has no ascendant in the tree at all, a grandparent has one
	 generation above it, a parent has two. The partner is excluded because a partner's own
	 parents are not part of ego's tree.
	 The nested routine tests one generation at a time, parents first, and the eight calls
	 written out at the third level are the eight great-grandparents.}
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
	
	{THE PARTNER BRANCH, and the two tests behind it.
	
	 Each algorithm asks in its own way whether the last union ended at the relative's death
	 with the partner still alive, which is the condition for a widow or widower to inherit.
	 The two tests are kept apart and both are made for every relative, so that lookForHeirs
	 can compare them and checkHeirs can ask the question without adding an heir.
	
	 partnerCanBeHeir_1 compares the age at the end of the last union with the age at death.
	 partnerCanBeHeir_2 asks the union itself why it ended.
	
	 They are two ways of asking one question and are expected to agree; lookForHeirs reports
	 chk_inh_partnerTestsDiffer when they do not. The one case where both are true and the
	 partner still cannot inherit is a partner who died in the same month as the relative,
	 which possible_heirFound refuses.}

	function partnerCanBeHeir_1 (pRelative: pRelativeType): boolean;
	{The first algorithm's test: the last union ended at the relative's own death, and the
	 partner of that union was alive at that moment.}
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

	{The second algorithm's test: the relative had a last partner, the last union ended by a
	 death, and that partner was alive at the relative's death.}
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
	{The branch itself, as it appears in the chain of branches of lookForHeirs. It reads the
	 answer that lookForHeirs recorded before entering the chain rather than testing again,
	 so that the question is asked once per relative and the answer is available to the
	 referee even for a relative whose estate goes to an earlier branch.}
	begin
		result := pRelative^.partnerCanInherit;
		if result then
			pRelative^.typeHeir := th_partner;
	end;
	
	{The siblings branch. True when a sibling of the relative, or a descendant of a sibling, was
	 alive at the death, and then typeHeir becomes th_siblingsTree. The search runs over the
	 children of the mother and then over the children of the father, so that half-siblings are
	 not missed; most of the two lists are the same people, and the repetition is deliberate.
	 How far down a dead sibling's own line it looks again depends on where the relative sits in
	 the simulated tree.}
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
	
	{One side of the aunts and uncles branch. It climbs from the relative along the path of
	 parents named by sexParentsTree to reach one grandparent or great-grandparent, then looks
	 among that ancestor's children, which are the aunts and uncles of the relative, and among
	 their descendants down to downLevel. The relative's own parents are skipped, since they
	 belong to the ascendants branch, which has already been tried. The branch to record in
	 typeHeir is passed in, because the same routine answers for the aunts and uncles and for the
	 grand-aunts and grand-uncles.}
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
	
	{The aunts and uncles branch, with their children. The four calls are the four grandparents,
	 that is the two sides of each parent. Relatives for whom this branch cannot apply, because
	 the tree around them does not reach that far, leave at once.}
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
	
	{The grand-aunts and grand-uncles branch, the last one tried. The eight calls are the eight
	 great-grandparents. downLevel is zero, so only the grand-aunts and grand-uncles themselves
	 are considered and not their descendants. Only ego, a sibling of ego and a cousin have
	 great-grandparents in the simulated tree, which is why the rest leave at once.}
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
	
	{No branch answered: the relative dies without an heir in the simulated tree. This is a
	 statement about the tree and not about the world, since the tree is built to a fixed depth
	 around ego and stops there.}
	procedure noHeirs (pRelative: pRelativeType);
	begin
		pRelative^.typeHeir := th_none;
	end;
	
	{THE FIRST ALGORITHM, PASS ONE. For each relative of ego's tree, the branch that contains the
	 heirs, recorded in typeHeir.
	
	 The chain of if statements is the order of preference, and the first branch that answers
	 stops it. Only relatives from whom ego could inherit are examined, that is ego itself and the
	 kin types of gPossibleHeirs that are kin of ego directly, which is what the test on kinOf
	 says: the partner of a relative other than ego is not followed.
	
	 Before entering the chain, the two partner tests are made and compared, and the answer of the
	 first is stored in partnerCanInherit so that the partner branch and the referee can read it
	 later.}
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

	{ ====================================================================
	  Shared bookkeeping: the two lists each relative carries, and how the
	  first algorithm writes to them
	  ==================================================================== }
	
	{Is this person already recorded as receiving something from that estate? It reads the
	 inheritances list of the possible heir.}
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
	
	{The same question as isAnHeir, asked where the caller is about to add an entry rather than
	 to read one.}
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
	
	{The same question from the other side: is this person already in the dead relative's list of
	 heirs?}
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

	{Adds one entry to the inheritances list of pHeir, naming the estate it comes from. The list
	 grows ten entries at a time rather than one, to keep the heap from fragmenting.
	 isHeir false records a person who does not inherit but through whom a share passes, which is
	 how a dead child between the decedent and a living grandchild is kept in the chain so that
	 the share can be traced down it. The share itself is left at zero here and filled later.}
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
	
	{Adds one person to the dead relative's list of heirs, growing it ten entries at a time. The
	 companion of addInheritance: the pair of them records the same fact on both sides.}
	procedure addHeir (pDeadRelative, pHeir: pRelativeType);
	begin
		Inc (pDeadRelative^.nHeirs);
		if pDeadRelative^.nHeirs > length(pDeadRelative^.heirs) then
			setLength (pDeadRelative^.heirs, length(pDeadRelative^.heirs) + 10);
		pDeadRelative^.heirs [pDeadRelative^.nHeirs - 1] := pHeir;
	end;
	
	{Tests a candidate and, if it can inherit and is not already recorded, writes it on both
	 sides. The return value is what the branches above read: true means this person is an heir
	 and was added now.}
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

	{Writes the share into an entry that already exists. The trap at the end fires if the entry is
	 not there, which would mean the caller computed a share for an estate it never recorded.}
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
	
	{Records how many people share this estate at this level and sets the share to one over that
	 number. Used where the heirs are siblings of one another and take equal parts.}
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
	
	{Applies updateSibling to every child of pParent that inherits, so that the whole group of
	 brothers and sisters is given the same divisor once their number is known.}
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
	
	{The same, over an explicit list of siblings rather than over the children of a parent. The
	 list is the one getSiblings built, with the lines that produced no heir set to nil.}
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
	
	{Writes every field of an existing entry at once. The trap at the end has the same meaning as
	 in updateShareInheritance.}
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
	
	{Is this relative in the list of people the caller wants left out of a search?}
	function kinToAvoid (const kinToAvoidArray: arrayOfRelatives; aKin: pRelativeType): boolean;
	var
		ind: longint;
	begin
		for ind := 1 to length(kinToAvoidArray) do
			if aKin = kinToAvoidArray [ind-1] then
				exit (true);
		exit (false);
	end;
	
	{One line of descent, taken down as far as it has to go, and the heirs in it recorded.
	
	 If the relative at the head of the line was alive at the death it is an heir and the line
	 stops there. If not, the same question is asked of each of its children, one degree further
	 down, as far as maxLevel. A line that produces at least one heir keeps the dead relative at
	 its head in the inheritances list with isHeir false, so that the share can later be traced
	 down through it; a line that produces none reduces the count of lines that share the estate,
	 which is what nLivingSiblingsTree carries back to the caller.
	
	 This is representation, or inheritance by lineage: what a line takes does not depend on how
	 many people are in it. The return value is 1 if this line produced an heir and 0 if it did
	 not.}
	function findHeir_childTree (pDeadRelative, pRelative: pRelativeType; maxLevel: longint; var degree: longint; var nLivingSiblingsTree: longint): longint;
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
	
	{The descendants of one person, line by line. It applies findHeir_childTree to each child of
	 pParent and counts the lines that produced an heir, which is the number the estate is divided
	 by. Children named in kinToAvoidArray are skipped, and skipping one also removes its line
	 from the count unless it is ego.}
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

	{The same walk as findHeir_childTree, over the line of descent of one sibling of the dead
	 person rather than of one of its children, and answering true or false rather than counting.
	 The entry trap at the top fires if the line was already recorded, which would mean the
	 caller reached the same person twice.}
	function findHeir_SiblingTree (pDeadRelative, pRelative: pRelativeType; maxLevel: longint; var degree: longint; nSiblings: longint): boolean;
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
	
	{The collateral counterpart of findHeir_descendancy: every line of the list of siblings is
	 taken down in turn, the lines that produced an heir are counted, and the lines that produced
	 none are set to nil so that the division at the end passes over them.}
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

	{Collects the children of one parent into a list, without repeating anyone already in it. It
	 is called twice, once for each parent, so that half-siblings are included and full siblings
	 are not counted twice. pSiblingToAvoid leaves one person out, normally the dead relative
	 itself.}
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

	{The share already recorded for this person in this estate. The trap at the end fires if there
	 is no such entry.}
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
	
	{The part of an estate that reaches a descendant through the people above it in its line.
	 Starting from a person, it climbs to whichever parent is recorded as receiving a share
	 without being an heir in its own right, that is a parent who died before the decedent, and
	 multiplies the shares as it goes. One generation at a time, for at most degree generations.
	 When no such parent is found the chain is complete and the factor is one.}
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

	{The share a person finally takes: its own recorded share multiplied by the factor the line
	 above it contributes.}
	function computeShareInheritance (pDeadRelative, pRelative: pRelativeType; var degree: longint): double;
	begin
		result := getShare (pDeadRelative, pRelative);
		if degree > 0 then
			result := result * computeShareInheritanceTree (pDeadRelative, pRelative, degree);
	end;

	{The first person present in both lists, or nil. It is used to ask which of ego's own parents
	 or grandparents is also an ancestor of a dead collateral relative, which is how a side of
	 ego's family that has no blood tie with that relative is kept out of its list of heirs. Note
	 that two nil entries do not match as a found ancestor, because a nil in the first list is
	 compared only with the entries of the second and the routine returns the entry itself, which
	 is then tested against nil by the caller.}
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
	
	{ ==========================================================================
	  THE FIRST ALGORITHM, SECOND QUESTION: is ego an heir, and of what share
	  ========================================================================== }
	
	{One estate and one possible heir. Given a dead relative whose branch of heirs lookForHeirs
	 has already named, decide whether ego is among those heirs and what part of the estate ego
	 takes, and record it on both sides.
	
	 Three tests at the top remove the estates ego cannot receive anything from: ego must have
	 been alive at the death, the relative must not be ego's kin only by a union of someone else,
	 and its kin type must be one the user asked for in DECEDENTS_KINTYPES.
	
	 What follows is one block per kin type of the dead relative, each guarded by the branch that
	 lookForHeirs recorded, so that a block runs only when the estate really did fall to the
	 branch that block is about. Each block collects the people who share the estate with ego,
	 counts them in numOfPossibleHeirs, and lets the division at the foot of the routine give ego
	 one part in that number. The blocks that reach ego through other people rather than directly,
	 the grandparents, the grand-nieces and nephews, the aunts and uncles, the cousins and the
	 great-grandparents, compute ego's share themselves with computeShareInheritance and then set
	 numOfPossibleHeirs to zero to switch the division at the foot off.
	
	 The traps written as breakOnFailure mark states the branch order should have made impossible,
	 for instance a living parent found in the block for a dead sibling. They fire only in a run
	 started from the IDE.
	
	 A note on the blocks that collect collateral kin. Where ego is a collateral relative of the
	 dead person, ego's own two parents are not necessarily both related to it. The side of ego's
	 family that has no ancestor in common with the dead relative contributes nobody, and
	 commonAncestor is what decides which side that is. Where instead the heirs collected are the
	 dead person's own brothers and sisters, every one of them shares a parent with it by
	 construction and no side has to be excluded.}
	procedure checkEgoIsHeir (pEgo, pDeadRelative: pRelativeType);
	var
		numOfPossibleHeirs: longint = 0;
		indSibling: longint;
		pSibling, pAncestor: pRelativeType;
		foundCommonAncestor: boolean;	{has one of ego's two parents an ancestor
					 in common with the dead collateral relative?}
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
					{The aunts and uncles of the dead niece or nephew are the children of its
					 grandparents, and ego is one of them, so one of ego's own parents is a grandparent
					 of the dead relative. Not necessarily both: if ego is a half-sibling of the dead
					 relative's father, sharing only the father, then ego's mother is no relation of the
					 dead relative and her children by another man share no blood with it. commonAncestor
					 answers which of ego's two parents is a grandparent of the dead relative, and only
					 the children of that one enter the list. A parent of ego that is nil is refused by
					 the same test.}
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
			{The same shape one generation higher. Ego is a grand-aunt or grand-uncle of the dead
			 relative, so one of ego's parents is one of its great-grandparents, and the other side
			 of ego's family may be no relation of it. Only the side with an ancestor in common
			 contributes its children.}
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
			{What is collected here are the heirs of the dead aunt or uncle, and those are the
			 children of the dead relative's own parents. Every one of them shares a parent with the
			 dead relative, the half-siblings included, so every one is a blood sibling of it and no
			 side has to be excluded. Ego reaches this estate through its own parent, who is one of
			 these siblings, and ego's share is computed below.}
			getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
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
			{Ego and the dead cousin share a grandparent. Which one, on which side, is what the two
			 calls below settle: the first asks it of the grandfathers and the second of the
			 grandmothers, and the children of the grandparent that answers are the heirs, that is
			 the dead cousin's own parent's brothers and sisters together with ego's parent.}
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
			{As in the aunts and uncles block, the heirs of the dead grand-aunt or grand-uncle are
			 the children of its own parents, so every one of them is a blood sibling of it.}
			getSiblings (pDeadRelative^.father, nSiblings, SIBLINGS, pDeadRelative);
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

	{THE FIRST ALGORITHM, PASS TWO. Every relative of ego in turn, asking of each whether ego is
	 one of its heirs. lookForHeirs must have run first, since checkEgoIsHeir reads the branch it
	 recorded. Ego itself is skipped, the walk starting at the next relative.}
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
		nParentsInLineage: integer;	{the number of ascendant heirs on the same side of
					 the family as this one, which is the number the share
					 of that side is divided by. Written by
					 allocateShareAscendantsHeirs_2 and read by nothing, so
					 it is there to be looked at in the debugger}
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

	{ =========================================================
	  THE SECOND ALGORITHM: the heirs themselves, and the shares
	  ========================================================= }
	
	{The kin type seen from the other end of the relation. If the decedent is the father of the
	 heir then the heir is a child of the decedent, and so on. It is needed because every fact is
	 recorded twice, once in the decedent's list of heirs and once in the heir's list of
	 inheritances, and the kin type has to be turned round between the two. The gender argument is
	 the decedent's, which is what decides between father and mother. The mapping is incomplete
	 for the more distant collateral kin, which is what the original note meant.}
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
	
	{Records, in the heir's list of inheritances, that it receives a share of this estate. With
	 addShare true it adds to an entry that must already be there, which is how a partner that
	 took half the estate first can be given the rest later. Called only by addHeir_2.}
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

	{A diagnostic: a relative that counts inheritances while its array has never been allocated
	 would mean the counter and the array have come apart.}
	procedure checkCoherencyDebug (pRel: pRelativeType);
	begin
		if (pRel <> nil) and (pRel^.nInheritances_2 > 0) and (length (pRel^.Inheritances_2) = 0) then
			memoWriteLn (['Big problem inheritance ', pRel^.indNumber]);
	end;
	
	{A place to put a breakpoint while following one relative through the second algorithm. The
	 commented body is kept as a worked example of how to catch a single individual.}
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

	{The one place where the second algorithm records an heir. It writes the heir and its share in
	 the decedent's list, then calls addDecedent_2 to write the same fact the other way round,
	 with the kin type reversed. Every branch of the second algorithm ends here.}
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
	{The partner branch. It asks partnerCanBeHeir_2 and, if the answer is yes, gives the partner
		 the share the caller decided on. checkTreeForHeirs_2 calls it twice: once before the other
		 branches when PARTNER_FIRST_HEIR is set, and once after the descendants and the ascendants
		 with whatever is left.}
		pPartner := getLastPartner (pDecedent);
		result := partnerCanBeHeir_2 (pDecedent);
		if not result then
			exit;
		addHeir_2 (pDecedent, pPartner, kt_partner, aShare, addShare);
	end;

	{The descendants of the decedent, explored and counted but not yet given anything.
	
	 It fills a tree of HeirsTree records parallel to the family tree: at each node, nChildren is
	 the number of children of that person, heirs holds the ones that were alive at the death, and
	 branches holds the sub-trees of the ones that were not. nHeirs counts the lines of that node
	 that produced at least one heir, directly or further down, and is the number the share
	 arriving at that node will be divided by. A line that produced nothing is not counted, which
	 is what makes the division by lineage come out right. The recursion stops at degree
	 generations below the decedent.}
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
	
	{The second pass over the tree exploreDescendantHeirsTree_2 built: it walks the same nodes and
	 hands out the shares. At each node the share arriving there is divided by nHeirs, the number
	 of lines that produced an heir, and each living child is given one part while each line with
	 no living child at this level passes its part down to be divided again. descendantsTypes
	 names the kin type to record at each generation.}
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
	{The descendants branch: explore, and if anything was found, allocate. True when the estate
	 was given away here, and then nothing is left for the branches below.}
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
	{The ascendants of the decedent, one generation at a time.
		
		 Called with degree set to the one generation to reach, it tests the two parents at that level
		 and, if neither can inherit, goes on up both lines. The lineage array records the path taken
		 from the decedent, one entry per step, so that the caller can tell which side of the family
		 an ascendant belongs to: an empty lineage is a parent, one step a grandparent, two steps a
		 great-grandparent, and the first step is always the parent of the decedent through whom that
		 ascendant is reached.
		
		 The generation is chosen by the caller and not here, which is what keeps all the heirs of one
		 pass in the same generation. A call that asks for a generation the lines have not reached
		 adds nothing, because the test at the top refuses it.}
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
	
	{The side of the family an ascendant heir belongs to. The first step of its lineage records
	 it; a parent has no lineage, and then its own sex gives the side.}
	function sideOfAscendantHeir (const aHeir: AscendantHeir): Sex;
	begin
		if length (aHeir.lineage) > 0 then
			result := aHeir.lineage [0]
		else if (aHeir.kinType = kt_mother) then
			result := woman
		else
			result := man;
	end;

	{The share each ascendant heir takes.
	
	 The estate is halved between the father's side of the family and the mother's side, and
	 within a side the heirs of that side take equal parts. A side with no heir at this degree
	 leaves its half to the other side. The heirs are all of one degree, which AscendantHeirs_2
	 sees to, so no further division by generation enters: with seven great-grandparents alive,
	 four on one side and three on the other, the four take an eighth each and the three take a
	 sixth each, and the two lines inside one side are not distinguished. This is article 810 of
	 the Spanish civil code.}
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
	{The ascendants branch. One pass for each generation in turn, and the first generation that
	 contains an heir is the only one that inherits: a surviving grandmother excludes every
	 great-grandparent, whichever line each of them belongs to. Within that generation the shares
	 are given out by allocateShareAscendantsHeirs_2, by side of the family.

	 The two lists of kin types, one per sex, name what to record at each generation: parent,
	 grandparent, great-grandparent. kNbGenerationsAscendantHeirs is their length and the number
	 of generations the branch can reach.}
	function AscendantHeirs_2 (pDecedent: pRelativeType; var shareInheritance: double; arrHeirs: arrayAscendants): boolean;
	var
		arrAscendantsType: arrayKinSexTypes;
		degree, currDegree: integer;
		nHeirs: integer = 0;
		currLineage: arrayOfSex;
		indHeir: integer;
	begin
		result := false;
		setLength(arrAscendantsType[man], kNbGenerationsAscendantHeirs);
		setLength(arrAscendantsType[woman], kNbGenerationsAscendantHeirs);
		arrAscendantsType[man] := [kt_father, kt_grandFather, kt_greatGrandFather];
		arrAscendantsType[woman] := [kt_mother, kt_grandMother, kt_greatGrandMother];
	{One generation at a time, stopping at the first that answers. The check inside confirms what
		 that gives: every heir of the pass that answered belongs to the same generation, which is
		 what the length of its lineage records.}
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
		if nHeirs > 0 then begin
			allocateShareAscendantsHeirs_2 (pDecedent, nHeirs, arrHeirs, shareInheritance);
			result := true;
			shareInheritance := 0;
		end;
		setLength(arrAscendantsType[man], 0);
		setLength(arrAscendantsType[woman], 0);
		setLength(currLineage, 0);
	end;

	{Adds one collateral relative to the pool, with its kin type and its degree, unless it is
	 already there. It does not check that the relative really is a collateral: the callers do
	 that by construction.}
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
	
	{The living children of one niece or nephew, added to the pool at degree four. They are only
	 ever reached when every sibling tree is empty.}
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
	
	{One dead sibling and its children. If any of them was alive at the death, the sibling is put
	 in the pool of siblings as a line that inherits by representation rather than as an heir, and
	 all its living children are listed under it. The grandchildren of the sibling are collected
	 in any case into the pool of collaterals, where they will matter only if no sibling tree
	 produces an heir.}
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
	
	{One sibling of the decedent, full or half. A living sibling enters the pool as an heir; a
	 dead one is passed to addNiecesNephewsToPool_2, which decides whether its children stand in
	 its place. The order of preference among collateral kin is the one set out at the head of
	 the unit: living siblings first, then nieces and nephews, then aunts and uncles, then the
	 rest of degree four together.}
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
	
	{Every child of one parent except the decedent itself. Called once for the father and once
	 for the mother, so that half-siblings are reached; addSiblingToPool_2 refuses the repeats.}
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

	{The shares of the siblings and of the nieces and nephews who stand in their place.

	 A full sibling counts one share and a half-sibling half a share, which is what nShares adds
	 up. A living sibling takes its own share. The children of a dead sibling divide that
	 sibling's share between them while at least one sibling is still alive; once every sibling is
	 dead the nieces and nephews stop representing their parents and take equal parts of the whole
	 estate, which is why the two cases are computed differently.}
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

	{The siblings branch: collect both sides, then allocate. False when there is no sibling tree
	 at all, and then the estate passes to the collateral branch.}
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

	{How many relatives of one kin type are in the pool.}
	function countKinPool_2 (aKinType: KinTypes; poolOfColaterals: pColaterals): integer;
	var
		ind: integer;
	begin
		result := 0;
		for ind := 1 to poolOfColaterals^.nColaterals do
			if poolOfColaterals^.arrayRel[ind-1].kinType = aKinType then
				result := result + 1;
	end;
	
	{The children of one grandparent, which are the decedent's aunts and uncles on that side, and
	 where one of them is dead, its own children, which are first cousins of the decedent. The
	 decedent's own parents are skipped. Aunts and uncles are degree three, first cousins degree
	 four.}
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
	
	{The same over all four grandparents.}
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
	
	{The children of one great-grandparent, which are the decedent's grand-aunts and grand-uncles
	 on that side. Degree four.}
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
	
	{The same over all eight great-grandparents.}
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

	{The collateral branch beyond the siblings, where the rule is the degree and not the kind of
	 relation.

	 Aunts and uncles are of degree three and exclude everyone else. Failing them, the relatives
	 of degree four take equal parts, and those are the first cousins, the grand-nieces and
	 grand-nephews collected earlier by the sibling branch, and the grand-aunts and grand-uncles,
	 which are only looked for when no aunt or uncle survived. Being full or half kin makes no
	 difference at this distance.}
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

	{THE SECOND ALGORITHM, for one relative: the whole order of preference, in order, until a
	 branch takes the estate.

	 The partner comes first when PARTNER_FIRST_HEIR is set, taking either the whole estate or
	 half of it according to PARTNER_FULL_HEIR. Then the descendants, then the ascendants, then
	 the partner again with whatever is left, then the siblings and their children, then the rest
	 of the collateral kin. shareInheritance carries what is still unallocated from one branch to
	 the next. The message at the foot reports a decedent that reached the end with heirs already
	 recorded, which would mean a branch gave something away and did not say so.}
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

	{A place to stop the debugger on one named individual. It computes nothing.}
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

	{ ----- the working memory of the second algorithm ----- }

	{Allocates the array of ascendant heirs once per walk of the tree, at its largest useful size:
	 eight, which is reached when all the great-grandparents are alive and the parents and
	 grandparents are all dead. The arrays are reused from one decedent to the next rather than
	 allocated again, which is what the memory manager record is for.}
	procedure initInheritance(pMemData: pMemoryManagerHeirs);
	begin
		setLength(pMemData^.arrayAscendants, 8); // 8 is the maximum if all great granparents are alive when parents and grandparents are dead!
		// in Spain the ascendants get all the inheritance if there is no descendant alive
	end;

	{Releases the tree of descendants, branch by branch.}
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
		
	{Releases everything initInheritance and the branches allocated.}
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

{THE SECOND ALGORITHM, entry point. Every relative of ego's tree, ego included, for which the
 user asked, gets its heirs and their shares. HEIRS_KINTYPES is what the user asked for.}
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
	
	{The second half of the second algorithm, and it does nothing.

	 Kinship calls this procedure after lookForHeirs_Spain, as the counterpart that would list the
	 decedents of each heir. The body is empty, and the decedents of the second algorithm are in
	 fact produced by checkTreeForHeirs_2 alone, which records every fact on both sides as it
	 goes.

	 The parameter COUNTRY_INHERITANCE_RULES, whose values are inher_Spain and inher_Other, is
	 created in Init, saved and read by ReadCmdFileUnit and bound to a combo box in LazOutput, and
	 nothing anywhere reads its value. Both algorithms run on every run, so the choice offered to
	 the user has no effect. Whether the parameter is meant to select between rule sets, in which
	 case this is where the country branch belongs, or is a leftover to be removed with its combo
	 box and its reader, is an open question for the author. See N25 and Q4 in the TODO.}
	procedure lookForDecedents_Spain (pEgo: pRelativeType);
	begin
	end;

	{ ==========================================================
	  THE REFEREES: do the two algorithms give the same answer?
	  ========================================================== }

	{Are all the heirs the second algorithm found of kin types inside the given set?}
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
	
	{The referee of the two answers to the second question, from whom does ego inherit. It
	 compares the two lists of inheritances of one relative and returns 1 when they agree, 0 when
	 they do not, and kNotDefined for a relative that is not ego, since the first algorithm fills
	 that list for ego alone.

	 The comparison is by position as well as by content, so two lists with the same decedents in
	 a different order are reported as a disagreement. Comparing by identity, as checkHeirs does,
	 would be the better test and is on the list.}
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

	{The kin types a branch of the first algorithm covers. That algorithm answers with a branch
	 of the kinship tree and not with a list of persons, so this is the set the heirs found by
	 the second algorithm have to belong to.}
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

	{Is every heir the first algorithm listed also one of the heirs of the second? The
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

	{The referee of the two answers to the first question, who inherits from a relative. It
	 returns kNotDefined when neither algorithm looked at this relative, 1 when the two
	 answers are compatible and 0 when they are not, and it records each kind of
	 disagreement as a check of its own. Kinship calls it only when INHERITANCE and DEBUG
	 are both set, and its value is written to one column of the individual kinship file.

	 What is compared, given that the first algorithm names a branch of the tree while the
	 second lists the heirs and their shares:
	   whether both found heirs or both found none,
	   whether the kin types of the heirs of the second lie in the branch named by the first,
	   whether the heirs the first listed are among the heirs of the second.
	 The branch named by the first algorithm is widened by the partner when the succession rules
	 give the partner a share alongside the descendants or the ascendants, which is what
	 PARTNER_FIRST_HEIR and PARTNER_FULL_HEIR decide. This is what the partnerCanInherit field
	 of the relative record is for: the branch the first algorithm records names the partner
	 only when no descendant and no ascendant inherits, so the question has to be asked
	 separately.

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
	
end.
