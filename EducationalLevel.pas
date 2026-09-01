{$I Defines.pas}
unit EducationalLevel;

interface
	uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
Declarations, DemographicRegime, RandomNumbers, Utilities;

procedure initEduStatus(p: pStructDemographicRegimeSettings);
procedure destroyEduStatus(p: pStructDemographicRegimeSettings);
function edStatus(randomGenerator: TRandomNumberGenerator;
				  p: pStructDemographicRegimeSettings;
				  pRelative: pRelativeType;
				  eduStatusKind: EduStatusKinds): string;

implementation

	procedure initEduStatus(p: pStructDemographicRegimeSettings);
	var
		edLevel, edLevelIn, edLevelOut, edLevelMen, edLevelWomen, edLevelChild: EduLevels;
		vSex: Sex;
temp: double;
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

			{cumulative function}
			for vSex := man to woman do begin
				eduEgo [eduLow, vSex].cumulValue := eduEgo [eduLow, vSex].value;
				for edLevel := eduMedium to eduHigh do begin
					eduEgo [edLevel, vSex].cumulValue := eduEgo [edLevel, vSex].value + eduEgo [Pred(edLevel), vSex].cumulValue;
				end;
			end;
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

			{cumulative function}
			for edLevelIn := eduLow to eduHigh do
				for vSex := man to woman do begin
					eduEgoPartner [edLevelIn, vSex, eduLow].cumulValue := eduEgoPartner [edLevelIn, vSex, eduLow].value;
					for edLevelOut := eduMedium to eduHigh do
						eduEgoPartner [edLevelIn, vSex, edLevelOut].cumulValue := eduEgoPartner [edLevelIn, vSex, edLevelOut].value + eduEgoPartner [edLevelIn, vSex, Pred(edLevelOut)].cumulValue;
				end;

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

			{cumulative function}
			for edLevelWomen := eduLow to eduHigh do
				for edLevelMen := eduLow to eduHigh do begin
					eduEgoPartnerChildren [edLevelWomen, edLevelMen, eduLow].cumulValue := eduEgoPartnerChildren [edLevelWomen, edLevelMen, eduLow].value;
					for edLevelOut := eduMedium to eduHigh do
					begin
	temp := eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].value;
						eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].cumulValue :=
						eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].value +
						eduEgoPartnerChildren [edLevelWomen, edLevelMen, Pred(edLevelOut)].cumulValue;
	temp := eduEgoPartnerChildren [edLevelWomen, edLevelMen, edLevelOut].cumulValue;
					end;
				end;
		end;

	end;

	procedure destroyEduStatus(p: pStructDemographicRegimeSettings);
	var
		edLevel, edLevelIn, edLevelOut, edLevelMen, edLevelWomen, edLevelChild: EduLevels;
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
			writeAndWaitConst(['===> ERROR: bad eduLevel: ', s]){bad thing};
	end;
	
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
		dummy := randomGenerator.alea0;
if (pRelative = nil) then begin
	writeAndWait('===> ERROR: Nil pRelative in edStatusCohort');
	exit;
end
else if (pRelative^.cohort <= 0) then
	writeAndWait('===> ERROR: cohort value not assigned for relative in edStatusCohort');
		
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
if pPartner = nil then begin
	writeAndWait ('===> ERROR: partner bad in edStatusPartner');
end;
		eduLevelPartner := eduLevel (pPartner^.status);
if pPartner^.status = '' then begin
	writeAndWait ('===> ERROR: EdStatus bad in edStatusPartner');
end;
		
		if (dummy < p^.eduEgoPartner [eduLevelPartner, pRelative^.gender, eduLow].cumulValue) then
			edStatusPartner := 'B'
		else if (dummy < p^.eduEgoPartner [eduLevelPartner, pRelative^.gender, eduMedium].cumulValue) then
			edStatusPartner := 'M'
		else
			edStatusPartner := 'A';		
	end;
	
	function edStatusIntraFamily (randomGenerator: TRandomNumberGenerator;
									p: pStructDemographicRegimeSettings;
									pRelative: pRelativeType): string;
	begin
		if (pRelative^.typeOfKin = kt_ego) then
			edStatusIntraFamily := edStatusCohort (randomGenerator, pRelative)
		else if (pRelative^.typeOfKin = kt_partner) then
		begin
			edStatusIntraFamily := edStatusPartner (randomGenerator, p, pRelative);
		end else begin
			if (pRelative^.typeOfKin = kt_sibling) then
				edStatusIntraFamily := edStatusCohort (randomGenerator, pRelative)
			else if (pRelative^.typeOfKin = kt_child) then
				edStatusIntraFamily := edStatusChild (randomGenerator, p, pRelative)
			else if (pRelative^.typeOfKin = kt_grandChild) then
				edStatusIntraFamily := edStatusChild (randomGenerator, p, pRelative)
			else {for other relatives we apply the distribution for the whole cohort}
				edStatusIntraFamily := edStatusCohort (randomGenerator, pRelative);
		end
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
		end;
	end;

end.
