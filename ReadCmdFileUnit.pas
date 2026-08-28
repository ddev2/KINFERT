{$I Defines.pas}
unit ReadCmdFileUnit;

interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Math,
	Declarations, DemographicRegime, SpecialRuns, Fertility, Utilities,
	{$IFDEF VerboseProfiler}Profiler,{$ENDIF}
	Variants, RandomNumbers, Init, StringOfLib, SysUtils;
	
	function readCmdFile (filename: string; var numberOfSimulations: longint; readFile: boolean): boolean;
	function processLine (inFile: TFileType; var aLineReadString: string): longint;
	procedure initCmd (p: pStructDemographicRegimeSettings = nil);
    procedure initAdjustedValues;
    procedure saveAdjustedValues;
    function adjustedValuesSaved(): boolean;
	procedure init_runs;
	procedure defaultConfig ();
	procedure end_runs;
	procedure dumpConfigInfo (path, dumpFileName: string; forceSave: boolean = false; writeDemRegFile: boolean = false; writeDumpFile: boolean = true);
	function doIt ( filename: string; mode: DoItModes ): boolean;
	procedure commaToPeriod(var s: string);

implementation
	uses kinship, LazMain;
	
	type
		initType = record
			//name: string;
			min, max: longint;
			vartype: integer;
			d: array of double;
			l: array of longint;
			g: GenericName;
			g_created: boolean;
			//changed: boolean;
			//comment: string;
		end;
		
		initType2D = record
			//name: string;
			min1, max1: longint;
			min2, max2: longint;
			vartype: integer;
			d: array of array of double;
			l: array of array of longint;
			g: GenericName;
			g_created: boolean;
			//changed: boolean;
			//comment: string;
		end;

	const
		kMaxValueMain = 5;
		kMaxValueExtended = 8;
		kMaxValueInternals = 5;
		kMaxValueExtended2D = 1;
		
		defaultDumpFileName = 'KINFERT_DUMP.TXT';

		kNoCommand = 0;
		kComment = 1;
		kCommand = 2;
		kArrayValue = 3;
		kExternalCommandFile = 4;
		kDocumentation = 5;
		kEndDoc = '---';
		kEndDocShort = '---';
		
	var
		dumpFileName: string = defaultDumpFileName;
		gInitValues: boolean = false;
		gInitValueMain : array [0..kMaxValueMain-1] of initType;
		gInitValueExtended : array [0..kMaxValueExtended-1] of initType;
		gInitValueInternals : array [0..kMaxValueInternals-1] of initType;
		gInitValueExtended2D : array [0..kMaxValueExtended2D-1] of initType2D;
		gLineReadString_NotProcessed: string;
	
	procedure upCase (var s: string);
	var
		i, ls: integer;
	begin
		ls := length (s);
		for i := 1 to ls do
			if (s [i] >= 'a') and (s [i] <= 'z') then
				s [i] := char (integer (s[i]) - 32);
	end;

	procedure commaToPeriod(var s: string);
	var
		i: integer;
	begin
		while Pos (',', s) > 0 do begin
			i := Pos (',', s);
			s[i] := '.';
		end;
	end;
	
	procedure tabToBlank(var s: string);
	var
		i: integer;
	begin
		while Pos (tab, s) > 0 do begin
			i := Pos (tab, s);
			s[i] := ' ';
		end;
	end;
	
	procedure stripBlank(var s: string);
	var
		i, ls: integer;
		t: string;
	begin
		while Pos (' ', s) > 0 do begin
			i := Pos (' ', s);
			ls := length (s);
			if ( i = ls ) then
				t := copy (s, 1, i-1) 
			else
				t := copy (s, 1, i-1) + copy (s, i+1, ls-i);
			s := t;
		end;
	end;
	
	procedure stripBlankBeginEnd(var s: string);
	var
		i, ls: integer;
	begin
		{Begin}
		ls := length (s);
		for i := 1 to ls do
			if (s [i] <> ' ') then
				break;
		ls := ls - i + 1;
		s := RightStr (s, ls);
		{End}
		ls := length (s);
		for i := ls downto 1 do
			if (s [i] <> ' ') then
				break;
		ls := i;
		s := LeftStr (s, ls);
	end;
	
	function commentLine (aLine: string; includeBlankLine: boolean = true): boolean;
	var
		res: boolean;
	begin
		if (aLine = '') then res := includeBlankLine
				else
			res := (	(aLine[1] = '!') or
					(aLine[1] = '/') or
					(aLine[1] = '*') or
					(aLine[1] = '#') or
					(aLine = ' ' )
				);

		commentLine := res;
	end;
	
	procedure forgetCmd();
	var
		i: integer;
	begin
		if not gInitValues then exit;
		gInitValues := false;

		for i := 0 to kMaxValueMain-1 do
			if gInitValueMain[i].g_created then
				GenericName (gInitValueMain[i].g).Destroy;
		for i := 0 to kMaxValueExtended-1 do
			if gInitValueExtended[i].g_created then
				GenericName (gInitValueExtended[i].g).Destroy;
		for i := 0 to kMaxValueInternals-1 do
			if gInitValueInternals[i].g_created then
				GenericName (gInitValueInternals[i].g).Destroy;
		for i := 0 to kMaxValueExtended2D-1 do
			if gInitValueExtended2D[i].g_created then
				GenericName (gInitValueExtended2D[i].g).Destroy;

	end;
	
	procedure initCmd (p: pStructDemographicRegimeSettings = nil);
	// prepare the DemographicRegime settings to be read (in the case there is only ONE)
	// if the DemographicRegime can vary, the values will not be read in the
	// main config file, but in a cohort files, so this will not be used
		procedure initValueMain_value (ind: longint; iv: initType);
		begin
			gInitValueMain[ind] := iv;
		end;
		procedure initValueExtended_value (ind: longint; iv: initType);
		begin
			gInitValueExtended[ind] := iv;
		end;
		procedure initValueInternals_value (ind: longint; iv: initType);
		begin
			gInitValueInternals[ind] := iv;
		end;
		procedure initValueExtended2D_value (ind: longint; iv2D: initType2D);
		begin
			gInitValueExtended2D[ind] := iv2D;
		end;
		
		var
			iv: initType;
			iv2D: initType2D;
			
	begin
		if p = nil then
			p := DemRegimeCollection_first;
		if gInitValues then forgetCmd;
		gInitValues := true;
		
		with iv do begin
			min:= 0; max:= kMaxNbChildren; vartype:= vardouble; d := p^.aPrioriPPR.value; l:= NIL;
			g := p^.aPrioriPPR;
			g_created := false;
		end;
		initValueMain_value (0, iv);
		with iv do begin
			min:= 0; max:= kMaxIndBirthIntervals; vartype:= vardouble; d := p^.effStopping.value; l:= NIL;
			g := p^.effStopping;
			g_created := false;
		end;
		initValueMain_value (1, iv);
		with iv do begin
			min:= 0; max:= kMaxIndBirthIntervals; vartype:= vardouble; d := p^.effSpacing.value; l:= NIL;
			g := p^.effSpacing;
			g_created := false;
		end;
		initValueMain_value (2, iv);
		with iv do begin
			min:= 0; max:= kMaxIndBirthIntervals; vartype:= vardouble; d := p^.meanTimeSpacing.value; l:= NIL;
			g := p^.meanTimeSpacing;
			g_created := false;
		end;
		initValueMain_value (3, iv);
		with iv do begin
			min:= 0; max:= kMaxNbChildren; vartype:= vardouble; d := p^.aPrioriPPR_adjusted.value; l:= NIL;
			g := p^.aPrioriPPR_adjusted;
			g_created := false;
		end;
		initValueMain_value (4, iv);

		with iv do begin
			min:= kMinAgeLife; max:= kMaxAgeLife; vartype:= vardouble; d := p^.mortalityInfo.survival_men; l:= NIL; {survival_men}
			g := GenericName.Create ('SURVIVAL_MEN', 'Proportion surviving by age for men', nil);
			g_created := true;
		end;
		initValueExtended_value (0, iv);
		with iv do begin
			min:= kMinAgeLife; max:= kMaxAgeLife; vartype:= vardouble; d := p^.mortalityInfo.survival_women; l:= NIL; {survival_women}
			g := GenericName.Create ('SURVIVAL_WOMEN', 'Proportion surviving by age for women', nil);
			g_created := true;
		end;
		initValueExtended_value (1, iv);
		with iv do begin
			min:= kMinAgeFert; max:= kMaxAgeFert; vartype:= vardouble; d := gDefinitive_sterility; l:= NIL; {gDefinitive_sterility}
			g := GenericName.Create ('DEFINITIVE_STERILITY', 'Definitive sterility by age for women', nil);
			g_created := true;
		end;
		initValueExtended_value (2, iv);
		with iv do begin
			min:= kMinAgeFert; max:= kMaxAgeFert; vartype:= vardouble; d := gFecundability; l:= NIL; {fecundability}
			g := GenericName.Create ('FECUNDABILITY', 'Mean fecundability by age for women', nil);
			g_created := true;
		end;
		initValueExtended_value (3, iv);
		with iv do begin
			min:= kMinAgeFert; max:= kMaxAgeFert; vartype:= vardouble; d := gIntrauterine_mortality_risk; l:= NIL; {gIntrauterine_mortality_risk}
			g := GenericName.Create ('INTRAUTERINE_MORTALITY_RISK', 'Intrauterine mortality risk by age of women. Fecundability after the last age depend on the age at sterility (like Leridon 2004)', nil);
			g_created := true;
		end;
		initValueExtended_value (4, iv);
		with iv do begin
			min:= kMinAgeFert; max:= kMaxAgeFert; vartype:= vardouble; d := gStillbirth_mortality_risk; l:= NIL; {gStillbirth_mortality_risk}
			g := GenericName.Create ('LATE_FOETAL_DEATH', 'Mortality risk near or during the delivery, by age of women', nil);
			g_created := true;
		end;
		initValueExtended_value (5, iv);
		with iv do begin
			min:= 1; max:= 8; vartype:= vardouble; d := gDistrib_intrauterine_mortality_risk; l:= NIL; {gDistrib_intrauterine_mortality_risk}
			g := GenericName.Create ('DISTRIB_INTRAUTERINE_MORTALITY', 'Cumulative proportion of intrauterine death, by month during the pregnancy', nil);
			g_created := true;
		end;
		initValueExtended_value (6, iv);

		with iv do begin
			min:= 0; max:= kMaxDurationUnionInMonths; vartype:= vardouble; d := p^.separationInfo.monthly_risk_separation; l:= NIL; {p^.monthly_risk_separation}
			g := GenericName.Create ('SEPARATION_RISK', 'Monthly risk of separation since the start of the union for childless couples', nil);
			g_created := true;
		end;
		initValueExtended_value (7, iv);

		with iv do begin
			min:= kMinAgeSingle; max:= kMaxAgeSingle_women; vartype:= vardouble; d := p^.pCurrUnionInfo^.prop_cel_men; l:= NIL; {proportion single men}
			g := GenericName.Create ('PROP_SINGLE_MEN', 'Surviving proportion in singlehood state for men by age', nil);
			g_created := true;
		end;
		initValueInternals_value (0, iv);
		with iv do begin
			min:= kMinAgeSingle; max:= kMaxAgeSingle_men; vartype:= vardouble; d := p^.pCurrUnionInfo^.prop_cel_women; l:= NIL; {proportion single women}
			g := GenericName.Create ('PROP_SINGLE_WOMEN', 'Surviving proportion in singlehood state for women by age', nil);
			g_created := true;
		end;
		initValueInternals_value (1, iv);
		with iv do begin
			min:= 0; max:= kMaxDistribFecundability; vartype:= vardouble; d := gDistrib_fecundability; l:= NIL; {gDistrib_fecundability}
			g := GenericName.Create ('DISTRIB_FECUNDABILITY', 'Heterogeneity of fecundability between women. We map a scale of 0 to 1 to the following cumulative distribution', nil);
			g_created := true;
		end;
		initValueInternals_value (2, iv);
		with iv do begin
			min:= 0; max:= kMaxMonthTemporarySterility; vartype:= vardouble; d := p^.temporary_sterility; l:= NIL; {p^.temporary_sterility}
			g := GenericName.Create ('DISTRIB_AMENORRHEA', 'Cumulative distribution of women with amenorrhea, in lunar months after the delivery', nil);
			g_created := true;
		end;
		initValueInternals_value (3, iv);
		with iv do begin
			min:= 0; max:= kMaxDurationContraceptionUnionInMonths; vartype:= vardouble; d := p^.AccDurationContrAfterUnion; l:= NIL; {p^.AccDurationContrAfterUnion}
			g := GenericName.Create ('DURATION_CONTR_AFTER_UNION', 'Cumulative distribution of women who don''t practice contraception after the start of the union, in lunar months', nil);
			g_created := true;
		end;
		initValueInternals_value (4, iv);

		with iv2D do begin {IS THIS THE ONLY 2D INTERNAL TABLE? FOR THE MOMENT THEY ARE NOT READ AND SO NOR WRITTEN}
			min1:= 0; max1:= 1; min2:= kMinAgeUnion; max2:= kMaxAgeUnion; vartype:= vardouble; d := p^.pCurrUnionInfo^.prop_repartnering; l:= NIL; {p^.prop_repartnering}
			g := GenericName.Create ('REPARTNERING_PROP', 'Proportion entering another union by age at end of previous union (men=0, women=1)', nil);
			g_created := true;
		end;
		initValueExtended2D_value (0, iv2D);
	end;

	procedure assignTab (inp: variant; iv: initType);
	var
		i: longint;

	begin
		iv.g.changed := false;
		if iv.vartype = varint64 then begin
			for i := iv.min to iv.max do begin
				iv.g.changed := iv.g.changed or (iv.l[i] <> inp[i]);
				iv.l[i] := inp[i];
			end;
		end else if iv.vartype = vardouble then begin
			for i := iv.min to iv.max do begin
				iv.g.changed := iv.g.changed or (iv.d[i] <> inp[i]);
				iv.d[i] := inp[i];
			end;
		end
	end;
	
	procedure assignTab2D (inp: variant; iv: initType2D);
	begin
{		if iv.vartype = varint64 then begin
			for i := iv.min to iv.max do begin
				iv.l[i] := inp[i];
			end;
		end else if iv.vartype = vardouble then begin
			for i := iv.min to iv.max do begin
				iv.d[i] := inp[i];
			end;
		end}
	end;
	
	function ReadArrayOld (inFile: TFileType; iv: initType ): boolean;
	var
		i, i2: integer;
		ind: integer;
		a: variant;
		d: double;
	begin
		ReadArrayOld := FALSE;
		a:= VarArrayCreate([iv.min, iv.max], iv.vartype);
		for i := iv.min to iv.max do begin
			readln (inFile.fileHandle, ind, d);
			if ( ind < iv.min ) or ( ind > iv.max ) then begin
				writeAndWaitConst(['===> ERROR: error bad index ', iv.g.name]);
				exit;
			end;
			if ( d >= 0 ) then begin
				a [ind] := d;
				if (ind > i) then begin
					for i2 := i to ind-1 do begin
						if ( i > iv.min ) then begin
							a [i2] := a [i-1];
						end else begin
							a [i2] := a [ind];
						end;
					end;
				end;
			end else begin
				if ( ind > iv.min ) then begin
					for i2 := ind to iv.max do begin
						a [i2] := a [ind-1];
					end;
					break;
				end else begin
					writeAndWaitConst(['===> ERROR: error:', iv.g.name]);
					exit;
				end;
			end;
		end;
		
		assignTab (a, iv);
		VarClear (a);
		ReadArrayOld := true;
	end;
	
	procedure interpolateMissingValue(min, max: longint; var a: variant);
	var
		ind, i1, i2, i3: longint;
	begin
		ind := min;
		while (ind < max) do begin
			if a[ind] >= 0 then
				Inc ( ind )
			else begin
				{missing values}
				i1 := ind - 1;
				i2 := ind;
				while (a[i2] < 0) and (i2 < max) do
					Inc ( i2 );
				if i1 < min then begin
					{at the start of the array}
					for i1 := min to i2-1 do
						a[i1] := a[i2];
				end else if (i2 = max) and (a[i2] < 0) and (i1 >= min) then begin
					{at the end of the array}
					for i2 := i1+1 to max do
						a[i2] := a[i1];
				end else begin
					{we interpolate when the missing values are in the middle}
					for i3 := i1+1 to i2-1 do
						a[i3] := a[i1] + (a[i2]-a[i1]) * (i3-i1) / (i2-i1);
				end;
				ind := i2+1;
			end;
		end;
	end;

	function ReadArray (inFile: TFileType; iv: initType ): boolean;
	var
		i, highestInd: integer;
		ind: integer;
		a: variant;
		d: double;
		aLineReadString: string; {the last line read from the command file}
		
{$GOTO ON}
		label onExit;
	begin
	{two objectives: catch errors (e.g. a line does not contain numbers but text). For that use ReadLn, store in a string, check and use ReadStr
	allow for sparse and unordered information: indexed values that are not contiguous or incomplete like:
	1 10
	5 20
	3 8
	7 -1
	and interpolate the missing values (here at position 2 and 4), and repeat from position 5 until the end of the array}

		ReadArray := FALSE;
		highestInd := iv.min - 1;
		a:= VarArrayCreate([iv.min, iv.max], iv.vartype);
		for i := iv.min to iv.max do a[i] := -1;
		while true do begin
			readln(inFile.fileHandle, aLineReadString);
			if processLine (inFile, aLineReadString) <> kNoCommand then begin
				writeAndWaitConst(['===> ERROR: Problem while reading the values of array ', iv.g.name]);
				goto onExit;
			end;
			
			readStr (aLineReadString, ind, d);
			if ( ind < iv.min ) or ( ind > iv.max ) then begin
				writeAndWaitConst(['===> ERROR: error bad index ', iv.g.name]);
				goto onExit;
			end;
			if ( d >= 0 ) then begin
				{we read values}
				a [ind] := d;
				if ind > highestInd then highestInd := ind;
				if (ind = iv.max) then break;
			end else begin
				{negative value, so this is the end}
				{we recopy the last value we read up to the end}
				for i := highestInd+1 to iv.max do begin
					a [i] := a [highestInd];
				end;
				interpolateMissingValue(iv.min, iv.max, a);
				break;
			end;
		end;
		
		assignTab (a, iv);
		VarClear (a);
		ReadArray := true;
		onExit:
	end;

	function ReadArray2D (inFile: TFileType; iv: initType2D ): boolean; {à implémenter}
	var
		i, i2: integer;
		ind: integer;
		a: variant;
		d: double;
	begin
		ReadArray2D := FALSE;
		a:= VarArrayCreate([iv.min1, iv.max1, iv.min2, iv.max2], iv.vartype);
{		for i := iv.min to iv.max do begin
			readln (inFile.fileHandle, ind, d);
			if ( ind < iv.min ) or ( ind > iv.max ) then begin
				writeAndWaitConst(['===> ERROR: error bad index ', iv.name]);
				exit;
			end;
			if ( d >= 0 ) then begin
				a [ind] := d;
				if (ind > i) then begin
					for i2 := i to ind-1 do begin
						if ( i > iv.min ) then begin
							a [i2] := a [i-1];
						end else begin
							a [i2] := a [ind];
						end;
					end;
				end;
			end else begin
				if ( ind > iv.min ) then begin
					for i2 := ind to iv.max do begin
						a [i2] := a [ind-1];
					end;
					break;
				end else begin
					writeAndWaitConst(['===> ERROR: error:', iv.name]);
					exit;
				end;
			end;
		end;
}
		assignTab2D (a, iv);
		VarClear (a);
		ReadArray2D := true;
	end;
	
	function ReadValue (inFile: TFileType; aValueName: string ): boolean;
	var
		i: integer;

	begin		

		ReadValue := true;
		for i:=low(gInitValueMain) to high(gInitValueMain) do begin
			if ( aValueName = gInitValueMain [i].g.name ) then begin
				ReadValue := ReadArray ( inFile, gInitValueMain [i] );
				exit;
			end;
		end;
		for i:=low(gInitValueExtended) to high(gInitValueExtended) do begin
			if ( aValueName = gInitValueExtended [i].g.name ) then begin
				ReadValue := ReadArray ( inFile, gInitValueExtended [i] );
				exit;
			end;
		end;
		for i:=low(gInitValueInternals) to high(gInitValueInternals) do begin
			if ( aValueName = gInitValueInternals [i].g.name ) then begin
				ReadValue := ReadArray ( inFile, gInitValueInternals [i] );
				exit;
			end;
		end;
		ReadValue := FALSE;
	end;
	
	procedure writeValue (outFile: TFileType; iv: initType );
	var
		i, iE: longint;
		tmp: longint;
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not iv.g.changed then exit;

		if ( iv.vartype = varint64 ) then begin
			for iE := iv.max downto iv.min + 1 do begin
				if ( iv.l [iE] <> iv.l [iE-1] ) then begin
					break;
				end;
			end;
			for i := iv.min to iE do begin
				bWriteLn (outFile, [i, tab, iv.l[i]]);
			end;
			if iE < iv.max then begin
                tmp := iE+1;
				bWriteLn (outFile, [tmp, tab, -1]);
			end;
		end else if ( iv.vartype = vardouble ) then begin
			for iE := iv.max downto iv.min + 1 do begin
				if ( iv.d [iE] <> iv.d [iE-1] ) then begin
					break;
				end;
			end;
			for i := iv.min to iE do begin
				bWriteLn (outFile, [i, tab, doubleToMinString (iv.d [i])]);
			end;
			if iE < iv.max then begin
                tmp := iE+1;
				bWriteLn (outFile, [tmp, tab, -1]);
			end;
		end;
		
	end;
	
	procedure writeValue2D (outFile: TFileType; iv: initType2D ); {A TESTER}
	var
		i, j: longint;
		
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not iv.g.changed then exit;

		cWrite (outFile, 'Ind ');
		for i := iv.min1 to iv.max1 do bWrite (outFile, [i, tab]);
		cWriteln (outFile);
		if ( iv.vartype = varint64 ) then begin
			for i := iv.min2 to iv.max2 do begin
				bWrite (outFile, [i, tab]);
				for j := iv.min1 to iv.max1 do bWrite (outFile, [iv.l[j, i], tab]);
				cWriteln (outFile);
			end;
		end else if ( iv.vartype = vardouble ) then begin
			for i := iv.min2 to iv.max2 do begin
				bWrite (outFile, [i, tab]);
				for j := iv.min1 to iv.max1 do bWrite (outFile, [doubleToMinString (iv.d[j, i]), tab]);
				cWriteln (outFile);
			end;
		end;
		
	end;
	
	function valueName (inFile: TFileType; aLine: string ): boolean;
	var
		aValueName: string;
	begin
		valueName := FALSE;
		if (aLine [1] = '[') then begin
			aValueName := RightStr (aLine, length (aLine) - 1);
			aValueName := LeftStr (aValueName, length (aValueName) - 1);
		end else begin
			exit
		end;
		valueName := ReadValue ( inFile, aValueName );
	end;

	procedure writeBlankLine (outFile: TFileType);
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value then exit;
		cWriteln (outFile);
	end;
	
	procedure writeComment (outFile: TFileType; comment: string);
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value then exit;
		if comment = '' then exit;
		comment := substituteChar (LF, ' ', comment);
		comment := substituteChar (CR, ' ', comment);
		if commentLine (comment) then
			cWriteLn (outFile, comment)
		else
			bWriteLn (outFile, ['! ' + comment]);
	end;
	
	procedure writeON_OFF (outFile: TFileType; p: BooleanName; dumpFileName: string = '');
	begin
		writeComment (outFile, p.comment);
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not p.changed then exit;

		if (p.value) then begin
			if (dumpFileName = '') or (dumpFileName = defaultDumpFileName) then
				cWriteln (outFile, p.name + '=ON')
			else
				bWriteln (outFile, [p.name + '=', dumpFileName]);
		end else
			cWriteln (outFile, p.name + '=OFF');
	end;
	
	procedure writeBooleanValue (outFile: TFileType; val: BooleanName; GenComment: string = '');
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not val.changed then exit;
		writeComment (outFile, GenComment);
		writeComment (outFile, val.comment);
		bWriteln(outFile, [val.name, '=', val.value]);
	end;

	procedure writeDoubleValue (outFile: TFileType; val: DoubleName; GenComment: string = '');
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not val.changed then exit;
		writeComment (outFile, GenComment);
		writeComment (outFile, val.comment);
		bWriteln(outFile, [val.name, '=', doubleToMinString(val.value)]);
	end;

	procedure writeLongintValue (outFile: TFileType; val: LongintName; GenComment: string = '');
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not val.changed then exit;
		writeComment (outFile, GenComment);
		writeComment (outFile, val.comment);
		bWriteln(outFile, [val.name, '=', val.value]);
	end;

	procedure writeStringValue (outFile: TFileType; val: StringName; GenComment: string = '');
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not val.changed then exit;
		if (GenComment <> '') then writeComment (outFile, GenComment);
		writeComment (outFile, val.comment);
		bWriteln(outFile, [val.name, '=', val.value]);
	end;

	function readKinSet (s: string; var errCode: word): KinSetType;
	var
		A: TStringArray;
		ind: longint;
		kt: KinTypes;
	begin
		A := s.Split (',');
		errCode := 0;
		result := [];
		for ind := 0 to high(A) do begin
			for kt := kFirstKinInEnum to kLastKinInEnum do begin
				if A[ind] = str_kinship[kt] then begin
					result := result + [kt];
					errCode := 0;
					break;
				end else begin
					errCode := 1;
				end;
			end;
			if errCode <> 0 then begin
				memoWriteLn([A[ind], '===> ERROR: not a known kin type']);
				exit;
			end;
	   end;
	end;

	procedure writeKinSet (outFile: TFileType; val: KinListName);
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not val.changed then exit;
		writeComment (outFile, val.comment);
		bWriteln(outFile, [val.name, '=', kinSetToString (val.value)]);
	end;
	
	function readFieldSet (s: string; var errCode: word): FieldSetType;
	var
		A: TStringArray;
		ind: longint;
		fn: FieldNamesTypes;
	begin
		A := s.Split (',');
		errCode := 0;
		result := [];
		for ind := 0 to high(A) do begin
			for fn := low(FieldSetType) to high(FieldSetType) do begin
				if A[ind] = str_FieldNames[fn] then begin
					result := result + [fn];
					errCode := 0;
					break;
				end else begin
					errCode := 1;
				end;
			end;
			if errCode <> 0 then begin
				memoWriteLn([A[ind], '===> ERROR: not a known field type']);
				exit;
			end;
	   end;
	end;

	procedure writeFieldSet (outFile: TFileType; val: FieldListName);
	begin
		if g_GENPARAM.WRITE_ONLY_CHANGES.value and not val.changed then exit;
		writeComment (outFile, val.comment);
		bWriteln(outFile, [val.name, '=', fieldSetToString (val.value)]);
	end;
	
	procedure writeDoc (outFile: TFileType; s: string);
	var
		A: TStringArray;
		ind: longint;
	begin
		cWriteLn (outFile, 'DOCUMENTATION');
		A := s.Split(LineEnding);
		for ind := 0 to high(A) do begin
			bWriteLn (outFile, [A[ind]]);
		end;
		bWriteLn (outFile, [kEndDoc]);
	end;
	
	procedure DumpCmdFile ( path, filename: string; var outFile: TFileType; closeFile: boolean = true );
	var
		pd: paramDemReg_double;
		pl: runtimeParam_longint;
		fp: fixedParameterKind;
		res: outputKind_boolean;
		i, resFile: integer;
		
		noCohortFile: boolean = true; // information for one cohort only or for various cohorts in an external file
		currCohort: longint;
		cohorts: arrayOflongint;
		pDemReg: pStructDemographicRegimeSettings;
		
		label onExit;
		
	begin
        gWritingConfigFile := false;
		if checkDir (path) then begin
			outFile := TFileType.Create (path + filename, resFile, 'DUMPCMDFILE');
			if resFile <> 0 then
            	exit
		end else begin
			goto onExit;
		end;
		
		gWritingConfigFile := true; // this is a state variable: we are writing the config file...

		noCohortFile := g_FileName_DemographicRegime.value = '';
		currCohort := DemRegimeCollection_firstCohort;
		DemRegimeCollection_yearsReadInConfig (cohorts);
		pDemReg := getCohort_p (currCohort);
		
		if g_GENPARAM.DOCUMENTATION.Changed then begin
			writeDoc (outFile, g_GENPARAM.DOCUMENTATION.value);
		end else begin
			writeComment (outFile, '! KINFERT dump file');
			writeComment (outFile, dateAndTime());
			writeBlankLine (outFile);
			writeComment (outFile, '! You can use that file to check the value of all the input parameters as well as internal tables of the model');
			writeComment (outFile, '! Also you can use it as a basis for creating a command file');
			writeComment (outFile, '! (In that last case you only need to enter the values that DIFFER from the default ones)');
			writeComment (outFile, '* (Refer to the documentation for the choice of parameters for the command file)');
			writeComment (outFile, '# A comment line should have as first character either: !,*,/,#');
			writeComment (outFile, '/ Lines with no character or only space characters are ignored');

			writeBlankLine (outFile);
			writeComment (outFile, '! Logical values can be either ON / TRUE or OFF / FALSE');
			writeComment (outFile, '! Character case does not matter. Everything can be in Uppercase or Lowercase and mixing cases is allowed');
			writeBlankLine (outFile);
		end;
		
		writeComment (outFile, '! Main commands');
		writeBlankLine (outFile);
		
		//writeON_OFF (outFile, g_GENPARAM.DUMP, dumpFileName);
		//writeComment (outFile, 'Instead of ON/OFF, can be the name of the DUMP file  (default is KINFERT_DUMP.TXT)');
		writeON_OFF (outFile, g_GENPARAM.DUMPALL, dumpFileName);
		writeON_OFF (outFile, g_GENPARAM.SAVE_LOG);
		writeON_OFF (outFile, g_GENPARAM.TALKATIVE);
		writeON_OFF (outFile, g_GENPARAM.ZIP_INDIVIDUAL);
		writeON_OFF (outFile, g_GENPARAM.MULTITHREADING);
		writeON_OFF (outFile, g_GENPARAM.MULTITHREADING_INIT);
		writeON_OFF (outFile, g_GENPARAM.MULTITHREADING_INITMOTHERHOOD);
		writeON_OFF (outFile, g_GENPARAM.MULTITHREADING_SIMKIN);
		writeON_OFF (outFile, g_GENPARAM.FORCE_NUM_THREADS);
		//writeComment (outFile, 'Instead of ON/OFF, can be the name of the extended DUMP file  (default is KINFERT_DUMP.TXT)');
		writeON_OFF (outFile, g_GENPARAM.DUMPALLCOHORTS);
		writeON_OFF (outFile, g_GENPARAM.CREATE_COHORT_FILE);
		writeON_OFF (outFile, g_GENPARAM.DETAILED_COHORT_DATA);
		writeON_OFF (outFile, g_GENPARAM.WRITE_ADJUSTED_VALUES);
		writeON_OFF (outFile, g_GENPARAM.WRITE_ONLY_CHANGES);
		writeON_OFF (outFile, g_GENPARAM.WRITE_FOLDER);

		writeComment(outFile, '! Algorithm for ascribing an educational level for KINSHIP');
		writeComment(outFile, g_GENPARAM.eduKind.comment);
		if not (g_GENPARAM.WRITE_ONLY_CHANGES.value and not g_GENPARAM.eduKind.changed) then
			bWriteLn(outFile, [g_GENPARAM.eduKind.name, '=', ord(g_GENPARAM.eduKind.value)]);
		
		writeON_OFF (outFile, g_GENPARAM.FERTILITY);
		if noCohortFile then writeLongintValue (outFile, pDemReg^.lp[nWomenPar]);
		writeON_OFF (outFile, g_GENPARAM.KINSHIP);
		if noCohortFile then writeLongintValue (outFile, pDemReg^.lp[nEgoPar]);
		//writeON_OFF (outFile, g_GENPARAM.STABLE_POPULATION);
		writeON_OFF (outFile, g_GENPARAM.FIXED_FERTILITY);
		writeLongintValue (outFile, g_GENPARAM.FIXED_FERTILITY_VALUE);
		writeON_OFF (outFile, g_GENPARAM.PPR_TARGET);
		writeON_OFF (outFile, g_GENPARAM.FORCE_PPR_TARGET);
		writeON_OFF (outFile, g_GENPARAM.SEP_TARGET);
		writeON_OFF (outFile, g_GENPARAM.FORCE_SEP_ITER);
		writeON_OFF (outFile, g_GENPARAM.INIT_RANDOM_NUMBERS);
		writeON_OFF (outFile, g_GENPARAM.CHECK_DATASTRUCT);
		writeON_OFF (outFile, g_GENPARAM.DEBUG);
		writeON_OFF (outFile, g_GENPARAM.NEW_INIT_MOTHERHOOD);
		writeLongintValue (outFile, g_GENPARAM.MODEGO);
		writeLongintValue (outFile, g_GENPARAM.OPTIMAL_TREES);
		
		writeComment (outFile, g_FileName.comment);
		bWriteln (outFile, [g_FileName.name, '=', g_FileName.value]);
		writeStringValue (outFile, g_GENPARAM.OUTPUT_DIRECTORY);
		writeStringValue (outFile, g_FileName_DemographicRegime);
		writeStringValue (outFile, g_FileName_DemographicRegime_save);
		writeBlankLine (outFile);
		writeComment (outFile, '! Main parameters for the demographic regime');
		writeComment (outFile, '! (These values are taken into account if not read from cohorts file, i.e. if DEM_REG_FILENAME is left empty)');
		writeBlankLine (outFile);
		
		if noCohortFile then begin
			for pd := low(paramDemReg_double) to high(paramDemReg_double) do begin
				writeDoubleValue (outFile, pDemReg^.dp[pd]);
			end;
		
			for i:=low(gInitValueMain) to high(gInitValueMain) do begin
				if g_GENPARAM.WRITE_ONLY_CHANGES.value and (not gInitValueMain [i].g.changed) then continue;
				writeComment (outFile, gInitValueMain [i].g.comment);
				bWriteLn (outFile, ['[', gInitValueMain [i].g.name, ']']);
				writeValue (outFile, gInitValueMain [i]);
			end;
		end;
		
		writeBlankLine (outFile);
		writeComment (outFile, '! ==================== Runtime options ===============');
		writeBlankLine (outFile);
		for pl := low(runtimeParam_longint) to high(runtimeParam_longint) do begin
			writeLongintValue (outFile, g_GENPARAM.RUNTIME[pl]);
		end;
		
		writeBlankLine (outFile);
		writeComment (outFile, '! ==================== Low level options for the fertility model ===============');
		writeBlankLine (outFile);
		for fp := low(fixedParameterKind) to high(fixedParameterKind) do begin
			if g_GENPARAM.WRITE_ONLY_CHANGES.value and not g_GENPARAM.fixedParameters[fp].state.changed then continue;

			writeComment (outFile, g_GENPARAM.fixedParameters[fp].state.comment);
			if ( g_GENPARAM.fixedParameters[fp].state.value ) then begin
				if ( g_GENPARAM.fixedParameters[fp].param.value <> kNotUsed ) then begin
					bWriteLn (outFile, [g_GENPARAM.fixedParameters[fp].state.name, '=', doubleToMinString (g_GENPARAM.fixedParameters[fp].param.value)]);
				end else begin
					bWriteLn (outFile, [g_GENPARAM.fixedParameters[fp].state.name, '=', 'TRUE']);
				end;
			end else begin
				bWriteLn (outFile, [g_GENPARAM.fixedParameters[fp].state.name, '=', 'FALSE']);
			end;
		end;

		writeBlankLine (outFile);
		writeComment (outFile, '! ==================== Output Tables ===================');
		writeBlankLine (outFile);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO);
		writeON_OFF (outFile, g_GENPARAM.SURVIVALPARENTS);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_INDIVIDUAL_AGE_FLOAT);
		writeComment(outFile, g_GENPARAM.kinIndFmt.comment);
		if not (g_GENPARAM.WRITE_ONLY_CHANGES.value and not g_GENPARAM.kinIndFmt.changed) then
			bWriteLn(outFile, [g_GENPARAM.kinIndFmt.name, '=', ord(g_GENPARAM.kinIndFmt.value)]);
		writeComment(outFile, g_GENPARAM.countryInheritance.comment);
		if not (g_GENPARAM.WRITE_ONLY_CHANGES.value and not g_GENPARAM.countryInheritance.changed) then
			bWriteLn(outFile, [g_GENPARAM.countryInheritance.name, '=', ord(g_GENPARAM.countryInheritance.value)]);
		writeKinSet (outFile, g_GENPARAM.OUTPUT_KINTYPES);
		writeFieldSet (outFile, g_GENPARAM.OUTPUT_FIELDS);
		writeON_OFF (outFile, g_GENPARAM.DEMOCARE_LARGE_FIELDS);
		writeON_OFF (outFile, g_GENPARAM.NON_BIO_KIN);
		writeON_OFF (outFile, g_GENPARAM.INHERITANCE);
		writeKinSet (outFile, g_GENPARAM.HEIRS_KINTYPES);
		writeKinSet (outFile, g_GENPARAM.DECEDENTS_KINTYPES);
		writeON_OFF (outFile, g_GENPARAM.PARTNER_DECEDENT);
		writeON_OFF (outFile, g_GENPARAM.ALL_EGO_PARTNERS_GENEALOGY);
		writeON_OFF (outFile, g_GENPARAM.PARTNER_FIRST_HEIR);
		writeON_OFF (outFile, g_GENPARAM.PARTNER_FULL_HEIR);
		
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_EXCLUDE_ABORTION);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_FERT_SURVEY);
		writeON_OFF (outFile, g_GENPARAM.OUTPUT_SHORTFILENAME);

		writeBlankLine (outFile);
		writeComment (outFile, '! Other kind of results tables that can be written');
		writeBlankLine (outFile);
		
		for res := low (outputKind_boolean) to high(outputKind_boolean) do begin
			writeBooleanValue (outFile, g_GENPARAM.outputs_opt[res]);
		end;

		writeBlankLine (outFile);
		writeComment (outFile, '! Format of results');
		writeBlankLine (outFile);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_numUnion]);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_numBirths]);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_floatingNumberDigits]);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_floatingNumberPrecision]);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_fertSurvey_ageMin]);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_fertSurvey_ageMax]);
		writeLongintValue (outFile, g_GENPARAM.outputs_fmt[res_maxThreads]);
		
		if closeFile then
			outFile.Destroy;
		
	onExit:
		   gWritingConfigFile := false;
	end;
	
	procedure DumpAllCmdFile ( path, filename: string );
	var
		outFile: TFileType;
		i, resFile: integer;
		label onExit;
	begin
		DumpCmdFile ( path, filename, outFile, false );
		
		gWritingConfigFile := true;
		if checkDir (path) then begin
{			IOResult;
			outFile := TFileType.Create (path + filename, resFile, 'DUMPALLCMDFILE', f_append);
			if resFile <> 0 then exit;
}		end else begin
			goto onExit;
		end;
				
		writeBlankLine (outFile);
		writeComment (outFile, '! KINFERT extended config file');
		writeBlankLine (outFile);
		for i := low(gInitValueExtended) to high(gInitValueExtended) do begin
			if g_GENPARAM.WRITE_ONLY_CHANGES.value and (not gInitValueExtended [i].g.changed) then continue;
			writeComment (outFile, gInitValueExtended [i].g.comment);
			bWriteLn (outFile, ['[', gInitValueExtended [i].g.name, ']']);
			writeValue (outFile, gInitValueExtended [i]);
		end;
		writeBlankLine (outFile);
		writeComment (outFile, '! KINFERT internals array config file');
		writeBlankLine (outFile);
		for i:=low(gInitValueInternals) to high(gInitValueInternals) do begin
			if g_GENPARAM.WRITE_ONLY_CHANGES.value and (not gInitValueInternals [i].g.changed) then continue;
			writeComment (outFile, gInitValueInternals [i].g.comment);
			bWriteLn (outFile, ['[', gInitValueInternals [i].g.name, ']']);
			writeValue (outFile, gInitValueInternals [i]);
		end;
		// HERE WE DON'T WRITE 2D STRUCTURES AS AT THE MOMENT THE ROUTINE THAT READ THEM IS NOT IMPLEMENTED
		{
		for i:=low(gInitValueExtended2D) to high(gInitValueExtended2D) do begin
			writeComment (outFile, gInitValueExtended2D [i].g.comment);
			bWriteLn (outFile, ['[', gInitValueExtended2D [i].g.name, ']']);
			writeValue2D (outFile, gInitValueExtended2D [i]);
		end;
		}

		outFile.Destroy;
		
	onExit:
		gWritingConfigFile := false;

	end;
	
	function ProcessCommand ( aCommand: string; aBooleanState: boolean; aState, aState_NotProcessed: string ): boolean;
	var
		code: word;
		pfd: paramDemReg_double;
		pfl: paramDemReg_longint;
		pl: runtimeParam_longint;
		fp: fixedParameterKind;
		res: outputKind_boolean;
		fmt: outputKind_longint;
		dValue: double;
		
		pFirstDemReg: pStructDemographicRegimeSettings;
		
	begin
		ProcessCommand := true;
		code := 1;
		pFirstDemReg := DemRegimeCollection_first ();
		
		for pfd := low(paramDemReg_double) to high(paramDemReg_double) do begin
			if ( aCommand = pFirstDemReg^.dp[pfd].name ) then begin
				code := pFirstDemReg^.dp[pfd].readValue (aState);
				ProcessCommand := checkCode (  aCommand, code );
				exit;
			end;
		end;
		
		for pfl := low(paramDemReg_longint) to high(paramDemReg_longint) do begin
			if ( aCommand = pFirstDemReg^.lp[pfl].name ) then begin
				code := pFirstDemReg^.lp[pfl].readValue (aState);
				ProcessCommand := checkCode (  aCommand, code );
				exit;
			end;
		end;
		
		for pl := low(runtimeParam_longint) to high(runtimeParam_longint) do begin
			if ( aCommand = g_GENPARAM.RUNTIME[pl].name ) then begin
				code := g_GENPARAM.RUNTIME[pl].readValue (aState);
				ProcessCommand := checkCode (  aCommand, code );
				exit;
			end;
		end;
		
		for fp := low(fixedParameterKind) to high(fixedParameterKind) do begin
			if ( aCommand = g_GENPARAM.fixedParameters[fp].name ) then begin
				code := g_GENPARAM.fixedParameters[fp].readValue (aState, aBooleanState);
				ProcessCommand := checkCode (  aCommand, code );
				exit;
			end;
		end;
		
		for res := low (outputKind_boolean) to high(outputKind_boolean) do begin
			if aCommand = g_GENPARAM.outputs_opt[res].name then begin
				code := g_GENPARAM.outputs_opt[res].readValue (aBooleanState);
				ProcessCommand := checkCode (  aCommand, code );
				exit;
			end;
		end;

		for fmt := low(outputKind_longint) to high(outputKind_longint) do begin
			if ( aCommand = g_GENPARAM.outputs_fmt[fmt].name ) then begin
				code := g_GENPARAM.outputs_fmt[fmt].readValue (aState);
				ProcessCommand := checkCode (  aCommand, code );
				exit;
			end;
		end;
		
		if ( aCommand = g_FileName.name ) then begin
			g_FileName.value := aState_NotProcessed;
			g_FileName.readInConfigFile := true;
			exit;
		end else if ( aCommand = g_FileName_DemographicRegime.name ) then begin
			g_FileName_DemographicRegime.value := aState_NotProcessed;
			g_FileName_DemographicRegime.readInConfigFile := true;
			exit;
		end else if ( aCommand = g_FileName_DemographicRegime_save.name ) then begin
			g_FileName_DemographicRegime_save.value := aState_NotProcessed;
			g_FileName_DemographicRegime_save.readInConfigFile := true;
			exit;
		end;
		
		if ( aCommand = 'EDUCATION' ) then begin
			code := g_GENPARAM.eduKind.readValue (aState);
			ProcessCommand := checkCode (  aCommand, code );
			exit;
		end else if ( aCommand = 'KINSHIP_INDIV_FORMAT') then begin
			code := g_GENPARAM.kinIndFmt.readValue (aState);
			ProcessCommand := checkCode ( aCommand, code );
			exit;
		end else if ( aCommand = 'COUNTRY_INHERITANCE_RULES') then begin
			code := g_GENPARAM.countryInheritance.readValue (aState);
			ProcessCommand := checkCode ( aCommand, code );
			exit;
		end else if ( aCommand = 'HEIRS_KINTYPES') then begin
			g_GENPARAM.HEIRS_KINTYPES.value := readKinSet ( aState_NotProcessed, code );
			ProcessCommand := checkCode ( aCommand, code );
			if ProcessCommand then
				g_GENPARAM.HEIRS_KINTYPES.readInConfigFile := true;
			exit;
		end else if ( aCommand = 'DECEDENTS_KINTYPES') then begin
			g_GENPARAM.DECEDENTS_KINTYPES.value := readKinSet ( aState_NotProcessed, code );
			ProcessCommand := checkCode ( aCommand, code );
			if ProcessCommand then
				g_GENPARAM.DECEDENTS_KINTYPES.readInConfigFile := true;
			exit;
		end else if ( aCommand = 'OUTPUT_KINTYPES') then begin
			g_GENPARAM.OUTPUT_KINTYPES.value := readKinSet ( aState_NotProcessed, code );
			ProcessCommand := checkCode ( aCommand, code );
			if ProcessCommand then
				g_GENPARAM.OUTPUT_KINTYPES.readInConfigFile := true;
			exit;
		end else if ( aCommand = 'OUTPUT_FIELDS') then begin
			g_GENPARAM.OUTPUT_FIELDS.value := readFieldSet ( aState_NotProcessed, code );
			ProcessCommand := checkCode ( aCommand, code );
			if ProcessCommand then
				g_GENPARAM.OUTPUT_FIELDS.readInConfigFile := true;
			exit;
		end;

		memoWriteLn(['UNKNOWN COMMAND: ', aCommand]);
		ProcessCommand := FALSE;
	end;
			
	function command ( aLine: string ): boolean;
	var
		aCommand: string;
		aCommand_raw: string;	{throwaway: see the second extractCommand call}
		aState, aState_NotProcessed: string;
		aBooleanState: boolean;

		function dumpCommand (): boolean;
		begin
			if ( aBooleanState ) then begin
				dumpCommand := true;
				{dumpFileName := defaultDumpFileName;}
			end else begin
				aBooleanState := (aState = 'OFF') or (aState = 'FALSE');
				if ( aBooleanState ) then begin
					dumpCommand := FALSE;
				end else begin
					dumpCommand := true;
					dumpFileName := aState;
				end;
			end;
		end;
		
		function extractCommand (aLine: string; out c, s: string; var b: boolean; cleanLine: boolean = true): boolean;
		begin
			if (Pos ('=', aLine) > 0) then begin
				if cleanLine then StripBlank ( aLine );
				c := LeftStr ( aLine, Pos ('=', aLine) - 1);
				s := RightStr ( aLine, length (aLine) - Pos ('=', aLine));
				b := (aState = 'ON') or (aState = 'TRUE');
				extractCommand := true;
			end else begin
				extractCommand := FALSE;
			end;
		end;
		
	begin
		command := FALSE;
		if not extractCommand (aLine, aCommand, aState, aBooleanState) then exit;
		{a throwaway for the command name: this second call exists ONLY to recover the
		 VALUE in its original case. Passing aCommand here overwrote the clean upper-cased
		 name with the raw one, so a hand-written 'kinship=on' matched no branch.}
		extractCommand (gLineReadString_NotProcessed, aCommand_raw, aState_NotProcessed, aBooleanState, false);
		command := true;
		if ( aCommand = 'DUMPALL') then
			g_GENPARAM.DUMPALL.readValue (dumpCommand ())
		else if ( aCommand = 'DUMP') then
			g_GENPARAM.DUMP.readValue (dumpCommand ())
		else if ( aCommand = 'DUMPALLCOHORTS') then
			g_GENPARAM.DUMPALLCOHORTS.readValue (dumpCommand ())
		else if ( aCommand = 'CREATE_COHORT_FILE') then
			g_GENPARAM.CREATE_COHORT_FILE.readValue (dumpCommand ())
		else if ( aCommand = 'ZIP_INDIVIDUAL') then
			g_GENPARAM.ZIP_INDIVIDUAL.readValue (dumpCommand ())
		else if ( aCommand = 'SAVE_LOG') then
			g_GENPARAM.SAVE_LOG.readValue (dumpCommand ())
		else if ( aCommand = 'TALKATIVE') then
			g_GENPARAM.TALKATIVE.readValue (dumpCommand ())
		else if ( aCommand = 'MULTITHREADING') then
			g_GENPARAM.MULTITHREADING.readValue (dumpCommand ())
		else if ( aCommand = 'MULTITHREADING_INIT') then
			g_GENPARAM.MULTITHREADING_INIT.readValue (dumpCommand ())
		else if ( aCommand = 'MULTITHREADING_INITMOTHERHOOD') then
			g_GENPARAM.MULTITHREADING_INITMOTHERHOOD.readValue (dumpCommand ())
		else if ( aCommand = 'MULTITHREADING_SIMKIN') then
			g_GENPARAM.MULTITHREADING_SIMKIN.readValue (dumpCommand ())
		else if ( aCommand = 'FORCE_NUM_THREADS') then
			g_GENPARAM.FORCE_NUM_THREADS.readValue (dumpCommand ())
		else if ( aCommand = 'DETAILED_COHORT_DATA') then
			g_GENPARAM.DETAILED_COHORT_DATA.readValue (dumpCommand ())
		else if ( aCommand = 'WRITE_ADJUSTED_VALUES') then
			g_GENPARAM.WRITE_ADJUSTED_VALUES.readValue (dumpCommand ())
		else if ( aCommand = 'WRITE_ONLY_CHANGES') then
			g_GENPARAM.WRITE_ONLY_CHANGES.readValue (dumpCommand ())
		else if ( aCommand = 'WRITE_FOLDER') then
			g_GENPARAM.WRITE_FOLDER.readValue (dumpCommand ())
		else if ( aCommand = 'FERTILITY' ) then
			g_GENPARAM.FERTILITY.readValue (aBooleanState)
		else if ( aCommand = 'KINSHIP' ) then
			g_GENPARAM.KINSHIP.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_AGGREGATE_KINSHIP' ) then 
			g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_AGGREGATE_FERTILITY' ) then 
			g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY.readValue (aBooleanState)
		else if ( aCommand = 'SURVIVALPARENTS' ) then
			g_GENPARAM.SURVIVALPARENTS.readValue (aBooleanState)
		else if ( aCommand = 'FIXED_FERTILITY' ) then
			g_GENPARAM.FIXED_FERTILITY.readValue (aBooleanState)
		else if ( aCommand = 'FIXED_FERTILITY_VALUE' ) then
			g_GENPARAM.FIXED_FERTILITY_VALUE.readValue (aState_NotProcessed)
		else if ( aCommand = 'STABLE_POPULATION' ) then
			g_GENPARAM.STABLE_POPULATION.readValue (aBooleanState)
		else if ( aCommand = 'PPR_TARGET' ) then
			g_GENPARAM.PPR_TARGET.readValue (aBooleanState)
		else if ( aCommand = 'FORCE_PPR_TARGET' ) then
			g_GENPARAM.FORCE_PPR_TARGET.readValue (aBooleanState)
		else if ( aCommand = 'SEP_TARGET' ) then
			g_GENPARAM.SEP_TARGET.readValue (aBooleanState)
		else if ( aCommand = 'FORCE_SEP_ITER' ) then
			g_GENPARAM.FORCE_SEP_ITER.readValue (aBooleanState)
		else if ( aCommand = 'CHECK_DATASTRUCT' ) then
			g_GENPARAM.CHECK_DATASTRUCT.readValue (aBooleanState)
		else if ( aCommand = 'MODEGO' ) then
			g_GENPARAM.MODEGO.readValue (aState_NotProcessed)
		else if ( aCommand = 'OPTIMAL_TREES' ) then
			g_GENPARAM.OPTIMAL_TREES.readValue (aState_NotProcessed)
		else if ( aCommand = 'INIT_RANDOM_NUMBERS' ) then
			g_GENPARAM.INIT_RANDOM_NUMBERS.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_INDIVIDUAL_FERTILITY_INFO' ) then
			g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED' ) then
			g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_INDIVIDUAL_KINSHIP_INFO' ) then
			g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_INDIVIDUAL_AGE_FLOAT' ) then
			g_GENPARAM.OUTPUT_INDIVIDUAL_AGE_FLOAT.readValue (aBooleanState)
		else if ( aCommand = 'DEMOCARE_LARGE_FIELDS' ) then
			g_GENPARAM.DEMOCARE_LARGE_FIELDS.readValue (aBooleanState)
		else if ( aCommand = 'NON_BIO_KIN' ) then
			g_GENPARAM.NON_BIO_KIN.readValue (aBooleanState)
		else if ( aCommand = 'INHERITANCE' ) then
			g_GENPARAM.INHERITANCE.readValue (aBooleanState)
		else if ( aCommand = 'PARTNER_FIRST_HEIR' ) then
			g_GENPARAM.PARTNER_FIRST_HEIR.readValue (aBooleanState)
		else if ( aCommand = 'PARTNER_FULL_HEIR' ) then
			g_GENPARAM.PARTNER_FULL_HEIR.readValue (aBooleanState)
		else if ( aCommand = 'PARTNER_DECEDENT' ) then
			g_GENPARAM.PARTNER_DECEDENT.readValue (aBooleanState)
		else if ( aCommand = 'ALL_EGO_PARTNERS_GENEALOGY' ) then
			g_GENPARAM.ALL_EGO_PARTNERS_GENEALOGY.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES' ) then
			g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_EXCLUDE_ABORTION' ) then
			g_GENPARAM.OUTPUT_EXCLUDE_ABORTION.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_FERT_SURVEY' ) then
			g_GENPARAM.OUTPUT_FERT_SURVEY.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_SHORTFILENAME' ) then
			g_GENPARAM.OUTPUT_SHORTFILENAME.readValue (aBooleanState)
		else if ( aCommand = 'OUTPUT_DIRECTORY' ) then begin
			g_GENPARAM.OUTPUT_DIRECTORY.readValue (aState_NotProcessed);
		end else if ( aCommand = 'CHECK_DATASTRUCT' ) then
			g_GENPARAM.CHECK_DATASTRUCT.readValue (aBooleanState)
		else if ( aCommand = 'DEBUG' ) then
			g_GENPARAM.DEBUG.readValue (aBooleanState)
		else if ( aCommand = 'NEW_INIT_MOTHERHOOD' ) then
			g_GENPARAM.NEW_INIT_MOTHERHOOD.readValue (aBooleanState)
		else
			command := processCommand ( aCommand, aBooleanState, aState, aState_NotProcessed );
	end;
		
	function cmdFileName ( aLine: string ): boolean;
	var
		filename: string;
	begin
		cmdFileName := FALSE;
		if (Pos ('COMMANDFILE', aLine) > 0) and (Pos ('=', aLine) > 0) and (Pos ('=', aLine) > Pos ('COMMANDFILE', aLine)) then begin
			filename := RightStr ( aLine, length (aLine) - Pos ('=', aLine));
			stripBlankBeginEnd (filename);
{$IFDEF LAZARUS_GUI}
			setLength (gConfigFileCollection, length(gConfigFileCollection) + 1);
			gConfigFileCollection [length(gConfigFileCollection) - 1] := filename;
			memoWriteLn(['Command file: ', filename, ' added...']);
{$ELSE}
			DemRegimeCollection_destroy ();
			doIt ( filename, initAndReadFile );
{$ENDIF}
			cmdFileName := true;
		end;
	end;
	
	function processLine (inFile: TFileType; var aLineReadString: string): longint;		
	begin
		processLine := kNoCommand;
		gLineReadString_NotProcessed := aLineReadString;
		upCase (aLineReadString);
		tabToBlank (aLineReadString);
		commaToPeriod (aLineReadString);
		stripBlankBeginEnd (aLineReadString);
		if aLineReadString = 'DOCUMENTATION' then
			processLine := kDocumentation
		else if commentLine ( aLineReadString ) then
			processLine := kComment
		else if cmdFileName ( aLineReadString ) then
		begin
			{if we read an external command file, we will not execute any other commands beside running another command file}
			processLine := kExternalCommandFile
		end
		else if command ( aLineReadString ) then
			processLine := kCommand
		else if valueName ( inFile, aLineReadString ) then
			processLine := kArrayValue;
	end;
	
function readCmdFile (	filename: string;
                        var numberOfSimulations: longint;
                        readFile: boolean): boolean;
	var
		inFile: TFileType;
		aLineReadString: string;
		process, resFile: longint;

		label onExit;

	begin
		readCmdFile := FALSE;
		if (not readFile) then begin
			readCmdFile := true;
			exit;
		end;

		inFile := TFileType.Create (gPathToConfig + filename, resFile, 'READCMDFILE', f_reset);
		if (resFile <> 0) then begin
			if not DirectoryExists(gPathToConfig) then begin
				writeAndWait('ERROR ==>  directory not found: ' + gPathToConfig);
			end else begin
				memoWriteLn([gPathToConfig + filename + ' does not exist. Using DEFAULT values']);
			end;
			exit;
		end;

		while not Eof (inFile.fileHandle) do begin
			readLn (inFile.fileHandle, aLineReadString);
			process := processLine(inFile, aLineReadString);
			if (process = kExternalCommandFile) and readFile then begin
				{if we read an external command file, we will not execute any other commands beside running another command file}
				Inc (numberOfSimulations);
				readCmdFile := FALSE;
			end else if process = kDocumentation then begin
				g_GENPARAM.DOCUMENTATION.changed := true;
				g_GENPARAM.DOCUMENTATION.value := '';
				readLn (inFile.fileHandle, aLineReadString);
				while not Eof (inFile.fileHandle) and (copy (aLineReadString, 1, length (kEndDocShort)) <> kEndDocShort) do begin
					g_GENPARAM.DOCUMENTATION.value := g_GENPARAM.DOCUMENTATION.value + aLineReadString + LineEnding;
					readLn (inFile.fileHandle, aLineReadString);
				end;
			end else if process = kNoCommand then begin
				writeAndWaitConst(['===> ERROR: Problem with line ', aLineReadString]);
				FlushIO;
				goto onExit;
			end;
		end;
		
		if (g_FileName_DemographicRegime.value <> '') then begin
			if not DemRegimeCollection_readData (g_FileName_DemographicRegime.value) then
				goto onExit;
		end;
		DemRegimeCollection_SetChangedDefaultValues;
		GenParamSetChangedValues ();
		DemRegimeCollection_adjustData ();
		DemRegimeCollection_saveAdjustedValues ();

		readCmdFile := true;

	onExit:
{$I-}
		inFile.Destroy;
{$I+}
	end;
	
	procedure storeFileName ( filename: string );
	var
		s: string;
	begin
		upCase (g_FileName.value);
		upCase (filename);
		s := g_FileName.value;
		s := copy ( filename, 1, Pos ('.', fileName) - 1 );
		if not (filename = 'CONFIG.TXT' ) then begin
			if g_FileName.value = '' then g_FileName.value := s;
			dumpFileName := 'DUMP_' + filename;
		end;
	end;
	
	procedure initConfigValues;
	begin
		initGeneralCmd;
		initFixedParameters();
	end;
	
	procedure defaultConfig ();
	begin
		DemRegimeCollection_destroy ();
		DemRegimeCollection_create ();
		initConfigValues;
	end;

    procedure initAdjustedValues;
    begin
		DemRegimeCollection_initAdjustedValues;
	end;

    procedure saveAdjustedValues;
    begin
		DemRegimeCollection_saveAdjustedValues;
	end;
	
    function adjustedValuesSaved(): boolean;
    begin
		result := DemRegimeCollection_adjustedValuesSaved();
	end;

	procedure init_runs;
	begin
		initGeneral;
		initConfigValues;
		DemRegimeCollection_create ();
		initCmd();
	end;
	
	procedure end_runs;
	begin
		forgetCmd ();
		DemRegimeCollection_destroy ();
		closeAll;
	end;
	
	procedure dumpConfigInfo (path, dumpFileName: string; forceSave: boolean = false; writeDemRegFile: boolean = false; writeDumpFile: boolean = true);
	var
		outFile: TFileType;
	begin
		if writeDumpFile then begin
			GenParamSetChangedValues;
			if ( g_GENPARAM.DUMPALL.value ) and (length (dumpFileName) > 0) then begin
				DumpAllCmdFile ( path, dumpFileName );
			end else if ( g_GENPARAM.DUMP.value or forceSave ) and (length (dumpFileName) > 0) then begin
				DumpCmdFile ( path, dumpFileName, outFile );
			end;
		end;
		if (writeDemRegFile) then begin
			DemRegimeCollection_writeData (g_GENPARAM.DUMPALLCOHORTS.value, path + dumpFileName, not g_GENPARAM.WRITE_ADJUSTED_VALUES.value);
			DemRegimeCollection_writeData (g_GENPARAM.CREATE_COHORT_FILE.value, gPathToResult + g_FileName.value + '_DEM_REG_FILENAME.txt', not g_GENPARAM.WRITE_ADJUSTED_VALUES.value);
		end;

	end;
	
	function doIt ( filename: string; mode: DoItModes ): boolean;
	var
		numberOfSimulations:  longint;
		currCohort: longint;
		loopPhase: loopTypes;
		bootstrap_index: longint;
		nLOOPS: longint = 0;
		doInit, readFile, mem_bool: boolean;
		pDemReg: pStructDemographicRegimeSettings;
		// Measure execution time
		tStart: TDateTime;  // Begin and end of measurement, and difference
		outFile: TFileType;

		label error;

	begin
		result := false;
		
		tStart:= Now();  // Get date+time
		memoWriteLn(['*******************************************************']);
		memoWriteLn(['******************  S T A R T E D  ********************']);
		memoWriteLn(['*******************************************************']);
		memoWriteLn( ['Started: ', DateTimeToStr( tStart )] );
		
		case mode of
			initAndReadFile:
			begin
				doInit := true;
				readFile := true;
			end;
			initAndNoReadFile:
			begin
				doInit := true;
				readFile := false;
			end;
			noInitAndReadFile:
			begin
				doInit := false;
				readFile := true;
			end;
			noInitAndNoReadFile:
			begin
				doInit := false;
				readFile := false;
			end;
		end;
		
		initFiles;
		initResults (filename, g_nRuns);
		numberOfSimulations := 0;
		if doInit then begin
			init_runs;
		end;
		if readFile then
			storeFileName (filename);
		
		if readCmdFile ( filename, numberOfSimulations, readFile ) then begin
			if (readFile) then begin
                gPathToResult := gMainPathToResult;
 				memoWriteLn(['=============================================================']);
	            if checkDirResult () then begin
					memoWriteLn(['Running: ', filename]);
                end else begin
                    memoWriteLn(['Problem with output directory for: ', filename]);
                    exit;
                end;
			end;

    		if g_GENPARAM.MULTITHREADING.value then begin
    			if (g_GENPARAM.FORCE_NUM_THREADS.value) then
    			begin
    				gMaxThreads := g_GENPARAM.outputs_fmt[res_maxThreads].value;
    				memoWriteLn(['Using: ', gMaxThreads, ' threads for multithreading (max recommended number is: ', gNumLogicalThreadsForMultiThreading,')']);
    			end else
    				memoWriteLn(['Using: ', gMaxThreads, ' threads for multithreading']);
    		end;

			if g_GENPARAM.INIT_RANDOM_NUMBERS.value and runDrawsFromSeveralThreads then begin
				memoWriteLn (['=====================================================================']);
				memoWriteLn (['WARNING: INIT_RANDOM_NUMBERS (same random sequence) is ON but IGNORED,']);
				memoWriteLn (['because MULTITHREADING is ON. The order in which the threads draw']);
				memoWriteLn (['random numbers is not determined, so this run is NOT reproducible.']);
				memoWriteLn (['Set MULTITHREADING=OFF if you need the same sequence in every run.']);
				memoWriteLn (['=====================================================================']);
			end;
            if g_GENPARAM.INIT_RANDOM_NUMBERS.value and not runDrawsFromSeveralThreads then begin
				gRandomGenerator.init();
    			memoWriteLn (['First random number (fixed): ', floatToStr (gRandomGenerator.alea0)]);
			end
			else begin
				randomize;
				gRandomGenerator.initRandomized();
    			memoWriteLn (['First random number (variable): ', floatToStr (gRandomGenerator.alea0)]);
			end;
			FlushIO;

			if g_GENPARAM.KINSHIP.value then begin
				gCohortSet := [];
				currCohort := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
				while (currCohort <= g_GENPARAM.RUNTIME[cmd_lastCohort].value) do begin
					addToCohortSet (currCohort, gCohortSet);
					currCohort := currCohort + g_GENPARAM.RUNTIME[cmd_stepCohort].value;
				end;
				setInfoParents;
				initComputeStatesKinship (gCohortSet);
			end;

			openFileKeys (not g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value);
			for bootstrap_index := 1 to g_GENPARAM.RUNTIME[gBootstrap_nRuns].value do begin
				nLOOPS := 0;
				if (g_GENPARAM.RUNTIME[cmd_firstCohort].value = g_GENPARAM.RUNTIME[cmd_lastCohort].value) then
					loopPhase := k_onlyOne
				else
					loopPhase := k_first;
				openFileKeys (g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value, bootstrap_index);
				currCohort := g_GENPARAM.RUNTIME[cmd_firstCohort].value;
				while (currCohort <= g_GENPARAM.RUNTIME[cmd_lastCohort].value) do begin
					Inc (nLOOPS);
					if (nLOOPS > 1) then begin
						if (currCohort + g_GENPARAM.RUNTIME[cmd_stepCohort].value > g_GENPARAM.RUNTIME[cmd_lastCohort].value) then
							loopPhase := k_last
						else
							loopPhase := k_second;
					end;
					pDemReg := getCohort_p (currCohort);
					initCmd (pDemReg);
					memoWriteLn(['Cohort simulated: ', currCohort]);
// Calculating the actual time it took
// stopTime (tStart, '===== Init phase lasted: ');
					if
						not run_all (gRandomGenerator, currCohort, bootstrap_index * nLOOPS, loopPhase)
					then begin
						closeFileKeys (g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value);
						goto error;
					end;
// Calculating the actual time it took
stopTime (tStart, '***=====*** Total main computation lasted: ');
					currCohort := currCohort + g_GENPARAM.RUNTIME[cmd_stepCohort].value;
				end;
				closeFileKeys (g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value);
			end;			
			closeFileKeys (not g_GENPARAM.OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES.value);
			
//			mem_bool := g_GENPARAM.WRITE_ONLY_CHANGES.value;
//			g_GENPARAM.WRITE_ONLY_CHANGES.value := true;
			dumpConfigInfo (gPathToResult, g_FileName.value + '_CONFIG.TXT', false, false, true);
//			g_GENPARAM.WRITE_ONLY_CHANGES.value := mem_bool;
			dumpConfigInfo (gPathToResult, g_FileName.value + '_ALLCOHORTS.TXT', false, true, false);

			if	(g_GENPARAM.WRITE_ADJUSTED_VALUES.value) and
				(g_GENPARAM.PPR_TARGET.value or g_GENPARAM.SEP_TARGET.value) then
				DemRegimeCollection_writeAdjustedValues;

 			if g_GENPARAM.KINSHIP.value then begin
				computeStatesKinship;
				computeMenWomen2WaysTable;
			end;

		end else begin
			if (numberOfSimulations = 0) then DumpCmdFile ( gPathToResult, dumpFileName, outFile );
		end;

		result := true;
		
	error:
		if doInit then
			end_runs;

		AsyncCloseFiles ();
		// Calculating the actual time it took
		stopTime (tStart, '===== Post computation and cleanup phase lasted: ');

		memoWriteLn(['Finished: ', DateTimeToStr( Now() )]);
		memoWriteLn(['*******************************************************']);
		memoWriteLn(['****************** F I N I S H E D ********************']);
		memoWriteLn(['*******************************************************']);
		
	end ; // doIt

end.
