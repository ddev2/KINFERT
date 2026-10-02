{$I Defines.pas}
unit EducationalLevel;

interface
	uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
Declarations, DemographicRegime, RandomNumbers, Utilities, Verification;

procedure initEduStatus(p: pStructDemographicRegimeSettings);
{Rebuilds the cumulative distributions the three sampling routines read, for one cohort, from the
 probabilities the parameters carry. It has to be called after anything that changes a value:
 initEduStatus calls it on the object it has just created, and DemRegimeCollection_init calls it
 for every cohort at the start of a run, after the cohort file has been read and the cohorts
 between the ones read have been interpolated. Each row is checked to sum to one.}
procedure cumulateEduStatus (p: pStructDemographicRegimeSettings);
procedure destroyEduStatus(p: pStructDemographicRegimeSettings);
function edStatus(randomGenerator: TRandomNumberGenerator;
				  p: pStructDemographicRegimeSettings;
				  pRelative: pRelativeType;
				  eduStatusKind: EduStatusKinds): string;
{Says once, at the start of a run, where the educational distributions come from, and warns when a
 mode meant to follow observed levels is drawing from the values built into the program. Called
 after the cohort file has been read and the cohorts between the ones read have been interpolated.}
procedure reportEduDataSource;

implementation

	const
		{How far the three probabilities of one row may depart from a total of one before
		 chk_edu_rowSumsToOne counts it a failure. The rows are read as a cumulative distribution
		 whose last step is compared with a draw, so a row that sums to less than one gives the
		 top level more than it asks for and a row that sums to more never reaches the top level
		 at all. Neither is detectable in the results, which is why it is tested here.}
		kEduSumTolerance = 0.0001;

	procedure initEduStatus(p: pStructDemographicRegimeSettings);
	var
		edLevel, edLevelIn, edLevelOut, edLevelMen, edLevelWomen: EduLevels;	{edLevelChild was unused}
		vSex: Sex;
	begin
		{educational level of men and women}
		with p^ do begin
			eduEgo[eduLow, man] := DoubleCumulName.Create (0.5, '', '', p^.listOfParams);
			eduEgo[eduMedium, man] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgo[eduHigh, man] := DoubleCumulName.Create (0.1, '', '', p^.listOfParams);
			eduEgo[eduLow, woman] := DoubleCumulName.Create (0.6, '', '', p^.listOfParams);
			eduEgo[eduMedium, woman] := DoubleCumulName.Create (0.35, '', '', p^.listOfParams);
			eduEgo[eduHigh, woman] := DoubleCumulName.Create (0.05, '', '', p^.listOfParams);
		
			for edLevel := eduLow to eduHigh do
				for vSex := man to woman do
					eduEgo [edLevel, vSex].name := 'EDU_' + strEduLevels [edLevel] + '_' + sSex [vSex];

			{for educational level of a person (man of woman), what is the educational level of her/his partner}
			eduEgoPartner [eduLow, man, eduLow] := DoubleCumulName.Create (0.8, '', '', p^.listOfParams);
			eduEgoPartner [eduLow, man, eduMedium] := DoubleCumulName.Create (0.19, '', '', p^.listOfParams);
			eduEgoPartner [eduLow, man, eduHigh] := DoubleCumulName.Create (0.01, '', '', p^.listOfParams);
			eduEgoPartner [eduMedium, man, eduLow] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartner [eduMedium, man, eduMedium] := DoubleCumulName.Create (0.55, '', '', p^.listOfParams);
			eduEgoPartner [eduMedium, man, eduHigh] := DoubleCumulName.Create (0.05, '', '', p^.listOfParams);
			eduEgoPartner [eduHigh, man, eduLow] := DoubleCumulName.Create (0.3, '', '', p^.listOfParams);
			eduEgoPartner [eduHigh, man, eduMedium] := DoubleCumulName.Create (0.3, '', '', p^.listOfParams);
			eduEgoPartner [eduHigh, man, eduHigh] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartner [eduLow, woman, eduLow] := DoubleCumulName.Create (0.6, '', '', p^.listOfParams);
			eduEgoPartner [eduLow, woman, eduMedium] := DoubleCumulName.Create (0.3, '', '', p^.listOfParams);
			eduEgoPartner [eduLow, woman, eduHigh] := DoubleCumulName.Create (0.1, '', '', p^.listOfParams);
			eduEgoPartner [eduMedium, woman, eduLow] := DoubleCumulName.Create (0.3, '', '', p^.listOfParams);
			eduEgoPartner [eduMedium, woman, eduMedium] := DoubleCumulName.Create (0.5, '', '', p^.listOfParams);
			eduEgoPartner [eduMedium, woman, eduHigh] := DoubleCumulName.Create (0.2, '', '', p^.listOfParams);
			eduEgoPartner [eduHigh, woman, eduLow] := DoubleCumulName.Create (0.1, '', '', p^.listOfParams);
			eduEgoPartner [eduHigh, woman, eduMedium] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartner [eduHigh, woman, eduHigh] := DoubleCumulName.Create (0.5, '', '', p^.listOfParams);
		
			for edLevelIn := eduLow to eduHigh do
				for vSex := man to woman do
					for edLevelOut := eduLow to eduHigh do
						eduEgoPartner [edLevelIn, vSex, edLevelOut].name := 'EDUPARTNER_' + strEduLevels [edLevelIn] +
						'_' + sSex [vSex] + '_' + strEduLevels [edLevelOut];


			{for the educational level of a woman and the educational level of her partner, what is the educational level of their children}
			eduEgoPartnerChildren [eduLow, eduLow, eduLow] := DoubleCumulName.Create (0.8, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduLow, eduMedium] := DoubleCumulName.Create (0.15, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduLow, eduHigh] := DoubleCumulName.Create (0.05, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduMedium, eduLow] := DoubleCumulName.Create (0.6, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduMedium, eduMedium] := DoubleCumulName.Create (0.3, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduMedium, eduHigh] := DoubleCumulName.Create (0.1, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduHigh, eduLow] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduHigh, eduMedium] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduLow, eduHigh, eduHigh] := DoubleCumulName.Create (0.2, '', '', p^.listOfParams);

			eduEgoPartnerChildren [eduMedium, eduLow, eduLow] := DoubleCumulName.Create (0.7, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduLow, eduMedium] := DoubleCumulName.Create (0.22, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduLow, eduHigh] := DoubleCumulName.Create (0.08, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduMedium, eduLow] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduMedium, eduMedium] := DoubleCumulName.Create (0.45, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduMedium, eduHigh] := DoubleCumulName.Create (0.15, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduHigh, eduLow] := DoubleCumulName.Create (0.35, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduHigh, eduMedium] := DoubleCumulName.Create (0.4, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduMedium, eduHigh, eduHigh] := DoubleCumulName.Create (0.25, '', '', p^.listOfParams);

			eduEgoPartnerChildren [eduHigh, eduLow, eduLow] := DoubleCumulName.Create (0.2, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduLow, eduMedium] := DoubleCumulName.Create (0.3, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduLow, eduHigh] := DoubleCumulName.Create (0.5, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduMedium, eduLow] := DoubleCumulName.Create (0.15, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduMedium, eduMedium] := DoubleCumulName.Create (0.25, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduMedium, eduHigh] := DoubleCumulName.Create (0.6, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduHigh, eduLow] := DoubleCumulName.Create (0.1, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduHigh, eduMedium] := DoubleCumulName.Create (0.2, '', '', p^.listOfParams);
			eduEgoPartnerChildren [eduHigh, eduHigh, eduHigh] := DoubleCumulName.Create (0.7, '', '', p^.listOfParams);

			for edLevelWomen := eduLow to eduHigh do
				for edLevelMen := eduLow to eduHigh do
					for edLevelOut := eduLow to eduHigh do
						eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].name :=
						'EDUPARTNERCHILDREN_' +
						 strEduLevels [edLevelWomen] + '_' +
						 strEduLevels [edLevelMen] + '_' +
						 strEduLevels [edLevelOut]
						 ;

		end;
		{The three cumulation loops that stood here, the last of them with two leftover assignments
		 to a debug variable, are now in cumulateEduStatus below, which this calls on the object it
		 has just built and which the start of a run calls again for every cohort. Before that, the
		 cumulative values were computed once, here, from the built-in defaults, and nothing
		 recomputed them after a cohort file or an interpolation had changed the probabilities: the
		 dump echoed what was asked for while every person was drawn from the defaults.}
		cumulateEduStatus (p);
	end;

	procedure cumulateEduStatus (p: pStructDemographicRegimeSettings);
	var
		edLevel, edLevelIn, edLevelOut, edLevelMen, edLevelWomen: EduLevels;
		vSex: Sex;
	begin
		with p^ do begin
			{the distribution of the level of one person, by sex}
			for vSex := man to woman do begin
				eduEgo [eduLow, vSex].cumulValue := eduEgo [eduLow, vSex].value;
				for edLevel := eduMedium to eduHigh do
					eduEgo [edLevel, vSex].cumulValue := eduEgo [edLevel, vSex].value
							+ eduEgo [Pred (edLevel), vSex].cumulValue;
				checkValue (chk_edu_rowSumsToOne, eduEgo [eduHigh, vSex].cumulValue, 1.0, kEduSumTolerance);
			end;

			{the distribution of the level of a partner, given the level and the sex of the person
			 already assigned}
			for edLevelIn := eduLow to eduHigh do
				for vSex := man to woman do begin
					eduEgoPartner [edLevelIn, vSex, eduLow].cumulValue := eduEgoPartner [edLevelIn, vSex, eduLow].value;
					for edLevelOut := eduMedium to eduHigh do
						eduEgoPartner [edLevelIn, vSex, edLevelOut].cumulValue := eduEgoPartner [edLevelIn, vSex, edLevelOut].value
								+ eduEgoPartner [edLevelIn, vSex, Pred (edLevelOut)].cumulValue;
					checkValue (chk_edu_rowSumsToOne, eduEgoPartner [edLevelIn, vSex, eduHigh].cumulValue, 1.0, kEduSumTolerance);
				end;

			{the distribution of the level of a child, given the levels of its mother and father}
			for edLevelWomen := eduLow to eduHigh do
				for edLevelMen := eduLow to eduHigh do begin
					eduEgoPartnerChildren [edLevelWomen, edLevelMen, eduLow].cumulValue :=
							eduEgoPartnerChildren [edLevelWomen, edLevelMen, eduLow].value;
					for edLevelOut := eduMedium to eduHigh do
						eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].cumulValue :=
								eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].value
								+ eduEgoPartnerChildren [edLevelWomen, edLevelMen, Pred (edLevelOut)].cumulValue;
					checkValue (chk_edu_rowSumsToOne,
							eduEgoPartnerChildren [edLevelWomen, edLevelMen, eduHigh].cumulValue, 1.0, kEduSumTolerance);
				end;
		end;
	end;

	procedure destroyEduStatus(p: pStructDemographicRegimeSettings);
	var
		edLevel, edLevelIn, edLevelOut, edLevelMen, edLevelWomen: EduLevels;	{edLevelChild was unused}
		vSex: Sex;
	begin
		{educational level of men and women}
		with p^ do begin		
			for edLevel := eduLow to eduHigh do
				for vSex := man to woman do
					eduEgo [edLevel, vSex].Destroy;

			for edLevelIn := eduLow to eduHigh do
				for vSex := man to woman do
					for edLevelOut := eduLow to eduHigh do
						eduEgoPartner [edLevelIn, vSex, edLevelOut].Destroy;


			for edLevelWomen := eduLow to eduHigh do
				for edLevelMen := eduLow to eduHigh do
					for edLevelOut := eduLow to eduHigh do
						eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].Destroy;
		end;

	end;
	
	function eduLevel (s: string): EduLevels;
	begin
		eduLevel := eduLow;	{ defined default: any status that is not B, M or A }
		if (s = 'B') then
			eduLevel := eduLow
		else if (s = 'M') then
			eduLevel := eduMedium
		else if (s = 'A') then
			eduLevel := eduHigh
		else
			{the status of a person who has one is B, M or A. An empty string means the person was
			 reached before a status was given, which is what the parents first pass of giveEdStatus
			 in Kinship now prevents, and any other string means the status was corrupted.}
			if reportFailure (chk_edu_levelName, ['status read ', s]) then breakOnFailure;
	end;
	
	{
	 This mode gives every person an equal chance of each of the three levels, which is a uniform
	 test distribution and not the distribution of any population. It does not read the six EDU_*
	 parameters, and it is not meant to: the mode that reads them is the cohort mode, and the
	 intra-family mode reads them as well. What was wrong was that nothing said so, so a run made
	 with EDU_STATUS on this mode looked as though the parameters had been used. initParams now
	 writes one line in the memo at the start of such a run, and the manual says the same.}
	function edStatusStocha (randomGenerator: TRandomNumberGenerator): string;
	var
		dummy: double;
	begin
		dummy := randomGenerator.alea0;
		if (dummy < 1/3) then
			edStatusStocha := 'B'
		else if (dummy < 2/3) then
			edStatusStocha := 'M'
		else
			edStatusStocha := 'A';
	end;
	
	function edStatusCohort (randomGenerator: TRandomNumberGenerator; pRelative: pRelativeType): string;
	var
		dummy: double;
		p: pStructDemographicRegimeSettings;
	begin
		result := '';
		dummy := randomGenerator.alea0;
		{The two tests are the ones that were here, reported through the verification unit so that
		 they are counted and printed at the end of a run instead of appearing once in the memo.
		 Both now leave the function: the second did not, and the cohort it had just called
		 unassigned was then handed to getCohort_p, whose answer for a year the collection does not
		 carry is the nearest cohort it does carry, so the person was drawn from another cohort's
		 distribution with nothing to show it. The person is left without a status, which
		 giveEdStatus reports through eduLevel the moment anything reads it.}
		if (pRelative = nil) then begin
			if reportFailure (chk_edu_relativeMissing, ['no person given to edStatusCohort']) then breakOnFailure;
			exit;
		end;
		if (pRelative^.cohort <= 0) then begin
			if reportFailure (chk_edu_cohortNotAssigned, ['cohort ', pRelative^.cohort]) then breakOnFailure;
			exit;
		end;
		
		p := getCohort_p (pRelative^.cohort);
		
		if (dummy < p^.eduEgo [eduLow, pRelative^.gender].cumulValue) then
			edStatusCohort := 'B'
		else if (dummy < p^.eduEgo [eduMedium, pRelative^.gender].cumulValue) then
			edStatusCohort := 'M'
		else
			edStatusCohort := 'A';
	end;
	
	function edStatusChild (randomGenerator: TRandomNumberGenerator;
							p: pStructDemographicRegimeSettings;
							pRelative: pRelativeType): string;
	var
		eduLevelFather, eduLevelMother: EduLevels;
		dummy: double;
		
	begin
		{The two parents are read here, so both must be present and both must already have a status.
		 Neither was tested: a person whose father or mother is not in the network brought the run
		 down on a nil pointer, and a parent not yet assigned gave an empty status, which eduLevel
		 turned into the lowest level without saying so. The case is reported and the person takes
		 the distribution of the cohort instead, which is what the kin with no known parents get.}
		if (pRelative^.father = nil) or (pRelative^.mother = nil) then begin
			if reportFailure (chk_edu_relativeMissing,
					['a parent of the person is not in the network, kin type ', ord (pRelative^.typeOfKin)]) then breakOnFailure;
			result := edStatusCohort (randomGenerator, pRelative);
			exit;
		end;
		if (pRelative^.father^.status = '') or (pRelative^.mother^.status = '') then begin
			if reportFailure (chk_edu_parentStatusMissing,
					['kin type ', ord (pRelative^.typeOfKin), ', father ', pRelative^.father^.status,
					 ', mother ', pRelative^.mother^.status]) then breakOnFailure;
			result := edStatusCohort (randomGenerator, pRelative);
			exit;
		end;
		eduLevelFather := eduLevel (pRelative^.father^.status);
		eduLevelMother := eduLevel (pRelative^.mother^.status);
		dummy := randomGenerator.alea0;
		
		if (dummy < p^.eduEgoPartnerChildren [eduLevelMother, eduLevelFather, eduLow].cumulValue) then
			edStatusChild := 'B'
		else if (dummy < p^.eduEgoPartnerChildren [eduLevelMother, eduLevelFather, eduMedium].cumulValue) then
			edStatusChild := 'M'
		else
			edStatusChild := 'A';
	end;

	function edStatusPartner (	randomGenerator: TRandomNumberGenerator;
								p: pStructDemographicRegimeSettings;
								pRelative: pRelativeType): string;
	var
		dummy: double;
		eduLevelPartner: EduLevels;
		pPartner: pRelativeType;
		rank: longint;
		
	begin
		dummy := randomGenerator.alea0;
		pPartner := findPartner(pRelative, false, rank);
		{The person takes the distribution of the cohort, which is what a
		 person with no partner to condition on should have, and the case is counted.}
		if (pPartner = nil) then begin
			if reportFailure (chk_edu_relativeMissing, ['no partner found for a person of kin type ',
					ord (pRelative^.typeOfKin)]) then breakOnFailure;
			result := edStatusCohort (randomGenerator, pRelative);
			exit;
		end;
		if (pPartner^.status = '') then begin
			if reportFailure (chk_edu_parentStatusMissing, ['the partner has no status yet, kin type ',
					ord (pRelative^.typeOfKin)]) then breakOnFailure;
			result := edStatusCohort (randomGenerator, pRelative);
			exit;
		end;
		eduLevelPartner := eduLevel (pPartner^.status);
		
		{eduEgoPartner is declared [EduLevels, Sex, EduLevels]. The comment where it is built
		 says "for educational level of a person (man or woman), what is the educational level of
		 her/his partner", and the parameter names are written in the same order,
		 EDUPARTNER_<level of the known person>_<sex of the known person>_<level drawn>. The
		 first two indices therefore describe the person already assigned, and the third is the
		 one being drawn.

		 Here the person already assigned is pPartner, and the person being drawn is pRelative.
		 The first index was right, and the second named the sex of the person being drawn
		 instead of the sex of the one conditioning the draw, so a row for the other
		 configuration was read.

		 It matters because the matrix is not symmetric between the sexes. For a man of low
		 education the shipped distribution is 0.8, 0.19, 0.01; for a woman of low education it
		 is 0.6, 0.3, 0.1. The correlation stayed positive either way, which is why it passed
		 inspection, but the sex asymmetry of educational assortment was the thing the sex index
		 exists to carry, and it was inverted.}
		if (dummy < p^.eduEgoPartner [eduLevelPartner, pPartner^.gender, eduLow].cumulValue) then
			edStatusPartner := 'B'
		else if (dummy < p^.eduEgoPartner [eduLevelPartner, pPartner^.gender, eduMedium].cumulValue) then
			edStatusPartner := 'M'
		else
			edStatusPartner := 'A';
	end;
	
	{The routine used to name four kin types, ego, the partner, the
	 children and the grandchildren, and sent every other type to the distribution of the cohort,
	 with no family link at all. Siblings went that way too, although they share both parents with
	 ego and are the kin for which the correlation is best documented, so in a mode whose name
	 promises a family correlation most of a network of twenty-seven kin types was drawn
	 independently.
	 The rule is now the one the answer to Q5 asks for, and it names no kin type: whoever has both
	 parents in the network, with a status already drawn, takes the distribution conditional on the
	 two of them, which is what edStatusChild does. That covers the children and the grandchildren
	 as before, and now the siblings, the nephews and nieces, the cousins, ego's parents when the
	 grandparents are in the network, and ego itself, whose parents a kin network carries. Whoever is
	 left, which means the person at the top of each line of descent the network reaches, keeps the
	 distribution of the cohort. The partner stays a case of its own, since assortment is a
	 different table. It needs the parents to be assigned first, which giveEdStatus in Kinship
	 now does.

	 One consequence to keep in mind, and it is a property of the rule rather than of the code. The
	 EDU_ distribution of a cohort now binds only the people at the top of each line of descent.
	 Everyone below them, ego included, has the distribution the parent to child matrix implies,
	 so the levels among egos are no longer the EDU_ proportions asked for and drift over the
	 generations towards the stationary distribution of that matrix. Before this change ego alone
	 was drawn from the cohort distribution, which kept the ego sample on the parameters while its
	 siblings were not. Holding both at once would mean rescaling the matrix so that each cohort
	 keeps its marginal distribution, which is a change to the model and not a repair.}
	function bothParentsAssigned (pRelative: pRelativeType): boolean;
	begin
		result := (pRelative <> nil)
				and (pRelative^.father <> nil) and (pRelative^.mother <> nil)
				and (pRelative^.father^.status <> '') and (pRelative^.mother^.status <> '');
	end;

	function edStatusIntraFamily (randomGenerator: TRandomNumberGenerator;
									p: pStructDemographicRegimeSettings;
									pRelative: pRelativeType): string;
	begin
		if (pRelative^.typeOfKin = kt_partner) then
			edStatusIntraFamily := edStatusPartner (randomGenerator, p, pRelative)
		else if bothParentsAssigned (pRelative) then
			edStatusIntraFamily := edStatusChild (randomGenerator, p, pRelative)
		else {the person at the top of a line of descent, whose parents the network does not carry}
			edStatusIntraFamily := edStatusCohort (randomGenerator, pRelative);
	end;
	
	procedure reportEduDataSource;
	{Every one of the 51 probabilities the two observed modes read has a value built into the
	 program, a plausible set written when the module was made. A cohort file can replace any of
	 them, column by column, and each value it supplies is marked as read from the file.

	 Nothing ever checked whether any of them had been. A run with EDUCATION set to one of the two
	 observed modes and a cohort file with no EDU_ column drew every person from the built-in
	 values, and its output looked exactly like a run that followed observed data. There was no
	 error at any point, because there is no missing value to trip over: the defaults are always
	 there. That silence is what this ends.

	 Supplying part of a family and not the rest is worse than supplying none, since the row then
	 mixes two sources, so that case is named separately. The report is made through writeAndWait,
	 which lights the error indicator and keeps the message in verification.txt: a run whose
	 education does not come from where the user thinks it comes from is worth stopping to read,
	 but it is a fault in the inputs and not in the program, so the run goes on.}
	var
		pDemReg: pStructDemographicRegimeSettings;
		indCohort, nOwn, nPartner, nChildren: longint;
		edLevel, edLevelIn, edLevelOut, edLevelMen, edLevelWomen: EduLevels;
		vSex: Sex;
		fromFile: boolean;

		function partly (got, wanted: longint; columns, what: string): boolean;
		{true when the run can be left alone, that is when every column of the family is there}
		begin
			result := (got = wanted);
			if result then exit;
			if (got = 0) then
				writeAndWait ('===> WARNING: EDUCATION is set to a mode that draws from observed ' +
						'educational levels, but the cohort file carries none of the ' +
						IntToStr (wanted) + ' ' + columns + ' columns, which hold ' + what +
						'. The values built into the program are used instead, so this run does ' +
						'NOT follow observed data. Add those columns to the cohort file, or set ' +
						'EDUCATION to one of the two modes that give the three levels equal ' +
						'chances, which claim nothing about observed levels.')
			else
				writeAndWait ('===> WARNING: the cohort file carries ' + IntToStr (got) + ' of the ' +
						IntToStr (wanted) + ' ' + columns + ' columns, which hold ' + what +
						'. The rest keep the values built into the program, so the distributions ' +
						'this run uses mix two sources and do not sum to what was intended. Supply ' +
						'the whole family of columns or none of it.');
		end;

	begin
		if (g_GENPARAM.eduKind.value <> eduCohort) and
			(g_GENPARAM.eduKind.value <> eduIntraFamily) then exit;
		if (g_pCOHORT_COLLECTION = nil) then exit;

		{the first cohort the file supplied, since the flags are set on those rows; with no file
		 there is one regime and none of its values is marked}
		pDemReg := nil;
		for indCohort := 0 to g_pCOHORT_COLLECTION^.nCohorts do
			if (g_pCOHORT_COLLECTION^.data [indCohort] <> nil) and
				(g_pCOHORT_COLLECTION^.data [indCohort]^.readInConfig) then begin
				pDemReg := g_pCOHORT_COLLECTION^.data [indCohort];
				break;
			end;
		if (pDemReg = nil) then pDemReg := g_pCOHORT_COLLECTION^.data [0];
		if (pDemReg = nil) then exit;

		nOwn := 0;
		for edLevel := eduLow to eduHigh do
			for vSex := man to woman do
				if pDemReg^.eduEgo [edLevel, vSex].readInConfigFile then Inc (nOwn);
		nPartner := 0;
		for edLevelIn := eduLow to eduHigh do
			for vSex := man to woman do
				for edLevelOut := eduLow to eduHigh do
					if pDemReg^.eduEgoPartner [edLevelIn, vSex, edLevelOut].readInConfigFile then
						Inc (nPartner);
		nChildren := 0;
		for edLevelWomen := eduLow to eduHigh do
			for edLevelMen := eduLow to eduHigh do
				for edLevelOut := eduLow to eduHigh do
					if pDemReg^.eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].readInConfigFile then
						Inc (nChildren);

		fromFile := partly (nOwn, 6, 'EDU_<level>_<sex>',
					'the level of a person of that sex, by cohort');
		if (g_GENPARAM.eduKind.value = eduIntraFamily) then begin
			if not partly (nPartner, 18, 'EDUPARTNER_<level>_<sex>_<level>',
					'the level of the partner of a person of that level and sex') then
				fromFile := false;
			if not partly (nChildren, 27, 'EDUPARTNERCHILDREN_<level>_<level>_<level>',
					'the level of a child of a mother and a father of those two levels') then
				fromFile := false;
		end;
		if fromFile then
			memoWriteLn (['Education: the distributions of this run are read from the cohort file, ',
					'as the mode asks.']);
	end;

	function edStatusStochaFamily (randomGenerator: TRandomNumberGenerator;
									pRelative: pRelativeType): string;
	{Equal chances for the three levels, with the family taken into account. It is the only mode
	 that makes the members of a family resemble one another without observed data behind it,
	 which is what a DemoCare file wants when there is no cohort file carrying the EDU_
	 distributions.

	 The rule is one line. With probability kEduFamilyCorrelation a person takes a level that is
	 already in the family, and otherwise the level is drawn from the three with equal chances.
	 The level taken is the partner's for a partner, and the level of one of the two parents,
	 chosen at random, for a person whose parents are both in the network with a status of their
	 own. Anyone else, which is a person at the top of a line of descent, is drawn with equal
	 chances.

	 The marginal distribution stays exactly uniform at every generation, whatever the value of
	 the correlation: copying a level that is uniform, and drawing one with equal chances, both
	 give a uniform level. The mode therefore adds association inside families and changes nothing
	 else, which is what makes its output readable: a departure from a third in the totals is
	 sampling noise and not an effect of the mode.

	 One asymmetry is worth knowing. giveEdStatus assigns the two parents of a person before the
	 person, so a child always has its parents' levels to copy, but it does not do the same for a
	 partner: when the partner is reached first there is nothing to copy yet and the level is drawn
	 with equal chances. The correlation between partners is therefore weaker than the one between
	 parent and child. Making the two symmetric would mean assigning a person before the partner in
	 giveEdStatus, which would change eduIntraFamily as well.}
	var
		pSource, pPartner: pRelativeType;
		rank: longint;
	begin
		pSource := nil;
		if (pRelative^.typeOfKin = kt_partner) then begin
			pPartner := findPartner (pRelative, false, rank);
			if (pPartner <> nil) and (pPartner^.status <> '') then
				pSource := pPartner;
		end else if bothParentsAssigned (pRelative) then begin
			if (randomGenerator.alea0 < 0.5) then
				pSource := pRelative^.father
			else
				pSource := pRelative^.mother;
		end;
		if (pSource = nil) then
			exit (edStatusStocha (randomGenerator));
		if (randomGenerator.alea0 < kEduFamilyCorrelation) then
			result := pSource^.status
		else
			result := edStatusStocha (randomGenerator);
	end;

	function edStatus(randomGenerator: TRandomNumberGenerator;
					  p: pStructDemographicRegimeSettings;
					  pRelative: pRelativeType;
					  eduStatusKind: EduStatusKinds): string;
	begin
		case eduStatusKind of
			eduNone: edStatus := '';
			eduStochastic: edStatus := edStatusStocha(randomGenerator);
			eduCohort: edStatus := edStatusCohort(randomGenerator, pRelative);
			eduIntraFamily: edStatus := edStatusIntraFamily(randomGenerator, p, pRelative);
			eduStochasticFamily: edStatus := edStatusStochaFamily(randomGenerator, pRelative);
		end;
	end;

end.
