{$I Defines.pas}
unit Utilities;

interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Forms, // this includes the LCL widgetset
	Declarations, StringOfLib, Math, SysUtils
{$IFDEF LAZARUS_GUI}
	, Dialogs, Classes, zipper, FileUtil, LazFileUtils
{$ENDIF}
;

function checkDebugLongint(a, min, max: longint): boolean;
	procedure DumpExceptionCallStack(E: Exception);

const
	kAsyncFalse = false;
	
type
	fileModes = (f_none, f_rewrite, f_append, f_reset);
	SetChars = Set of Char;
	
	TFileType = class
		fileNameWithPath: string;
		fileHandle: TextFile;
		fileOpenToWrite: boolean;
		writtenTo: boolean; // whether we have written something in that file
		aSync: boolean;
		indThread: longint;
		nameObject: string;
		FAFinished: boolean;
		lastIOResult: longint;
		IOMode: fileModes;
		
		constructor Create (fileName: string; out res: longint; name: string; mode: fileModes = f_rewrite; ind: longint = kNotDefined); overload;
		destructor Destroy; override;
		procedure myFlush;
		procedure myCloseFile;
		procedure finished;
		function messageEnd: string;
		function hasError: boolean;
	end;

	TStoreFiles = class
		nFiles: longint;
		files: array of TFileType;
		
		constructor Create();
		destructor Destroy(); override;
		function new (fileName: string; mode: fileModes = f_rewrite): longint;
		function get (ind: longint): TFileType;
	end;
	
var
	gMainOutFile: TFileType; {When we use only one output file}
	gOutFilePPR: TFileType;
	gOutFileFec: TFileType;
	gOutFileAgeMat: TFileType;
	gOutFileKin: TFileType;
	gOutFileIndivFec: TFileType;
	gOutFileIndivKin: TFileType;
	gOutFileIndivKin_link: TFileType;
	gOutFileIndivKeys: TFileType;
	gDebugFile: TFileType;
	gDebugError: boolean = false;
	gDebugFertFile: TFileType;
	//gFiles: TStoreFiles;

	procedure initFiles;
	
	function AreArraysEqual_Sex(const A, B: arrayOfSex): Boolean;

{$IFDEF LAZARUS_GUI}
	function zipIt (filenameWithPath: string): boolean;
{$ENDIF}

	procedure stopTime (var tStart: TDateTime; message:string);
	function dateAndTime: string;
	
	function yearTrunc (year: double; nDec: longint = 5): double;
	
	function stringConcatenate_sep (const a, b, sep: string): string;
	function checkChangedDefaultValues: boolean;
	function myCheckChangedDefaultValues (listOfParams: GenericName): boolean;
	
	function lengthSet (aSet: SetChars): longint;
	function elementInArray (const a: array of longint; elt: longint): boolean;
	function elementInSet (aSet: SetChars; index: longint): Char;
	function kinSetToString (kinSet: KinSetType): string;
	function fieldSetToString (fieldSet: FieldSetType): string;
	function findPartner (pRelative: pRelativeType; firstUnion: boolean; out rank: longint): pRelativeType;

	function substituteChar(c1, c2: char; s: string): string;
	function stripChar (c: char; s: string): string;

	function checkCode ( aCommand: string; code: word ): boolean;
	function checkDir ( sDir: string ): boolean;
	function checkDirResult (): boolean;
	function fileExist ( s: string; writeState: boolean ): boolean;

	function openFileRead ( s: ansistring; name: string; out f: TFileType ): boolean;
	function openFileWriteConfig ( s: ansistring; name: string; out f: TFileType): boolean;	
	function initDebugFile: boolean;

	function openFileOut(sFichOut: string; name: string; out outFile: TFileType; aSync: boolean = true; mode: fileModes = f_rewrite): boolean;
	function openFileOutWithPath(sFichOut: string; name: string; out outFile: TFileType; aSync: boolean = true; mode: fileModes = f_rewrite): boolean;
	function initSpecificFileOut(sFichOut: string; bootstrap_ind: longint): boolean;
	function initAggrKinshipFile (s: string; checkFileExists: boolean; bootstrap_ind: longint): boolean;

	procedure AsyncCloseFiles;
	procedure closeAllFiles;

	procedure writeDebugOld (const Args: Array of const);
	procedure writeAndWait (s: string);
	procedure writeAndWaitConst (const Args: Array of const);
	procedure myHalt (const Args: Array of const);
	procedure fileScreenWrite (outFile: TFileType; const Args: Array of const; writeToFile: boolean = true);
	procedure fileScreenWriteLn (outFile: TFileType; const Args: Array of const;
		colType: inColumnType = col_none; writeToFile: boolean = true; writeToScreen: boolean = true);
	procedure EndTableWithHeader;
	procedure aWriteAll (s: string);
	procedure aWriteLnAll (s: string);
	procedure multWrite (const outs: Array of const; const Args: Array of const);
	procedure multWriteLn (const outs: Array of const; const Args: Array of const);
	procedure aWrite (outFile: TFileType; const Args: Array of const; forceFile: boolean = false);
	procedure aWriteLn (outFile: TFileType; const Args: Array of const; forceFile: boolean = false);
	procedure bWrite (outFile: TFileType; const Args: Array of const; minFloatDigitsInFile: longint = 5);
	procedure bWriteLn (outFile: TFileType; const Args: Array of const; minFloatDigitsInFile: longint = 5);
	procedure cWrite (outFile: TFileType; s: string = '');
	procedure cWriteLn (outFile: TFileType; s: string = '');
	procedure memoWrite (const Args: Array of const);
	procedure memoWriteLn (const Args: Array of const);
	procedure FlushIO;

	function str_float (float: double; minFloatDigitsInFile: longint = 0): string;
	procedure writeArrayOfDouble (outFile: TFileType; sep: string; const ad: Array of double);
	procedure writeLnArrayOfDouble (outFile: TFileType; sep: string; const ad: Array of double);
	procedure writeArrayOfDoubleOffset (outFile: TFileType; sep: string; const ad: Array of double; offset: longint);
	procedure writeLnArrayOfDoubleOffset (outFile: TFileType; sep: string; const ad: Array of double; offset: longint);
	procedure writeOneArrayOfDouble (fileName: string; const ad: Array of double);

	{dumpArray writes one array to <results>/<name>.txt as two tab separated rows, the
	 indices then the values, so the file opens directly in a spreadsheet. Intended for
	 inspection while debugging. See the implementation for the notes on firstIndex.}
	procedure dumpArray (name: string; const a: Array of double;  firstIndex: longint = 0); overload;
	procedure dumpArray (name: string; const a: Array of longint; firstIndex: longint = 0); overload;
	procedure dumpArray (name: string; const a: Array of boolean; firstIndex: longint = 0); overload;
	procedure dumpArray (name: string; const a: Array of char;    firstIndex: longint = 0); overload;
	procedure dumpArray (name: string; const a: Array of string;  firstIndex: longint = 0); overload;

	procedure writeLnArrayOfLongint (outFile: TFileType; sep: string; const al: Array of longint);
	procedure writeArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	procedure writeLnArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	procedure write_Name_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	procedure writeLn_Name_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	procedure write_Value_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	procedure writeLn_Value_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	procedure writeArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	procedure writeLnArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	procedure write_Name_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	procedure writeLn_Name_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	procedure write_Value_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	procedure writeLn_Value_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);

	function openFileKeys (oneFile: boolean; bootstrap_ind: longint = 0): boolean;
	procedure writeKeys;
	procedure closeFileKeys (doIt: boolean);

	procedure screenFileWrite (s: string; forceWrite: boolean = false);
	procedure screenFileWriteLn (s: string; forceWrite: boolean = false);

	procedure noMemory (s: string);
	function SetLengthDoubleZero (n: longint): arraydoubletype;
	function SetLengthDouble (n: longint; value: double): arraydoubletype;

	function isInteger (num: double): boolean;
	function min_real (a, b: double): double;
	function max_real (a, b: double): double;
	//function min (a, b: longint): longint;
	//function max (a, b: longint): longint;
	function dPos (r: longint; pos: longint): longint;
	function interpole (a1, a2: double; i, n: longint): double;
	
	function toAgeQuinq (age: longint): ageQuinq;
	function ageQuinqToStr (ageQ: ageQuinq): string;
{$IFDEF UnionStatesType}
	function UnionStateToStr (s: UnionStatesType): string;
{$ENDIF}
	function runDrawsFromSeveralThreads: boolean;
	function PartnershipStatusToStr (s: PartnershipStatusesType): string;
	
	function writeResults (res: outputKind_boolean): boolean;
	
	var
		// when g_silentMode is true, we compute only, without any outputs,
		// neither on the screen or in files
		g_silentMode: boolean = false;
		
implementation

uses DemographicRegime, Nuptiality
{$IFDEF LAZARUS_GUI}
, LazMain
{$ENDIF}
;

var
	g_CriticalSection: TRTLCriticalSection;
  
	function AreArraysEqual_Sex(const A, B: arrayOfSex): Boolean;
	var
	  i: Integer;
	begin
	  if Length(A) <> Length(B) then
		Exit(False);
	  for i := 0 to High(A) do
		if A[i] <> B[i] then
		  Exit(False);
	  Result := True;
	end;

	constructor TFileType.Create (fileName: string; out res: longint; name: string; mode: fileModes = f_rewrite; ind: longint = kNotDefined);
	begin
		inherited Create();
		fileNameWithPath := fileName;
		fileOpenToWrite := false;
		writtenTo := false;
		aSync := false;
		FAFinished := false;
		nameObject := name;
		indThread := ind;
		lastIOResult := 0;
		IOMode := mode;
		
		res := 0;
		IOResult;

{$I-}
		if (mode <> f_none) then
			assign (fileHandle, fileNameWithPath);
		if (mode = f_reset) then
			reset (fileHandle)
		else if (mode = f_rewrite) then
			rewrite (fileHandle)
		else if (mode = f_append) then
			append (fileHandle);
{$I+}
		lastIOResult := IOResult;
		fileOpenToWrite := ((lastIOResult = 0) and ((mode = f_rewrite) or (mode = f_append)));
		res := lastIOResult;
	end;
	
	destructor TFileType.Destroy;
	begin
		myCloseFile;
		inherited;
	end;

	procedure TFileType.myFlush;
	begin
{$I-}
		IOResult;
		flush (fileHandle);
        lastIOResult := IOResult;
{$I+}
	end;

	procedure TFileType.myCloseFile;
	begin
		finished;
{$I-}
		IOResult;
		if (IOMode = f_append) or (IOMode = f_rewrite) then
			flush (fileHandle);
		closeFile (fileHandle);
        lastIOResult := IOResult;
{$I+}
	end;
	
	procedure TFileType.finished;
	begin
		if aSync and writtenTo and not FAFinished then begin
			cWrite (self, self.messageEnd);
			repeat
			until FAFinished;
		end;
	end;

	function TFileType.hasError: boolean;
	begin
		result := lastIOResult <> 0;
	end;
	
	function TFileType.messageEnd: string;
	begin
		result := nameObject + ' finished';
	end;

	constructor TStoreFiles.Create();
	begin
		inherited;
		nFiles := 0;
		setLength (files, 5);
	end;
	
	destructor TStoreFiles.Destroy();
	var
		ind: longint;
	begin
		for ind := 0 to nFiles-1 do
			files[ind].Destroy;
		setLength (files, 0);
		inherited;
	end;

	function TStoreFiles.new (fileName: string; mode: fileModes = f_rewrite): longint;
	var
		ind, res: longint;
	begin
		if (fileName <> '') then
			for ind := 0 to nFiles-1 do
				if files [ind].fileNameWithPath = fileName then
					exit (ind);
		if nFiles >= length(files) then
			setLength (files, length(files) + 5);
		Inc (nFiles);
		files [nFiles-1] := TFileType.Create(fileName, res, 'STOREFILE_' + IntToStr(nFiles), mode);
		if res = 0 then
			result := nFiles - 1
		else begin
			result := kNotDefined;
			files [nFiles-1].Destroy;
			Dec (nFiles)
		end;
	end;

	function TStoreFiles.get (ind: longint): TFileType;
	begin
		result := files [ind-1];
	end;

	procedure initFiles;
	begin
		//gFiles := TStoreFiles.Create();
	end;

{$IFDEF LAZARUS_GUI}
	function zipIt (filenameWithPath: string): boolean;
	const
  		MB = 1024*1024;
	var
		zip: TZipper;
		error: string = '';
		fileNameForZip, filenameToZipWithPath, fileNameToZipWithoutPath: RawByteString;
	begin
		result := false;
		zip := TZipper.Create;
		zip.BufferSize := 1 * MB;
		zip.InMemSize := 16 * MB;
		zip.OnProgress := @KinFertForm.ZipProgressHandler;
 		zip.UseLanguageEncoding := true;
		filenameToZipWithPath := filenameWithPath;
		try
			try
				fileNameForZip := ExtractFileNameWithoutExt (filenameWithPath) + '.zip';
				fileNameForZip := filenameWithPath + '.zip';
				DeleteFile(fileNameForZip);
				zip.FileName := fileNameForZip;
				fileNameToZipWithoutPath := ExtractFileName(filenameWithPath);
				zip.Entries.AddFileEntry(filenameToZipWithPath, fileNameToZipWithoutPath);
				zip.ZipAllFiles;
			except
				on E: EZipError do
				begin
					zip.Free; error := 'Error 1 ' + E.Message;
				end;
				on E: Exception do  {all other Exceptions: }
				begin
					zip.Free; error := 'Error 2 ' + E.Message;
				end;
			end;
		finally
            if (error = '') then begin
    			result := true;
    			zip.Free;
    			DeleteFile(filenameWithPath);
            end else begin
       			result := true;
                memoWriteLn ([error]);
            end;
        end;
	end;
{$ENDIF}

	procedure stopTime (var tStart: TDateTime; message:string);
	var
		tEnd, tDiff: TDateTime;  // Begin and end of measurement, and difference
		iHours, iMinutes, iSeconds, iMilliseconds: Word;  // Time components
	begin
		tEnd := Now();
		tDiff:= tEnd - tStart;  // Subtract higher from lower value
		DecodeTime( tDiff, iHours, iMinutes, iSeconds, iMilliseconds );  // Does not account for day changes when executing around midnight
		memoWriteLn( [message, iHours, ' h, ', iMinutes, ' min, ', iSeconds, ' sec, ', iMilliseconds, ' msec '] );
		tStart := Now();
	end;
	
	function dateAndTime: string;
	var
		YY,MM,DD : Word;
	begin
		DecodeDate (Date,YY,MM,DD);
		result := 'The date (DD/MM/YY) and time are: ' + format ('%d/%d/%d ',[dd,mm,yy]) + TimeToStr(Time);
	end;

	procedure DumpExceptionCallStack(E: Exception);
	var
		I: Integer;
		Frames: PPointer;
		Report: string;
	begin
		Report := 'Program exception! ' + LineEnding +
		'Stacktrace:' + LineEnding + LineEnding;
		if E <> nil then begin
			Report := Report + 'Exception class: ' + E.ClassName + LineEnding +
			'Message: ' + E.Message + LineEnding;
		end;
		Report := Report + BackTraceStrFunc(ExceptAddr);
		Frames := ExceptFrames;
		for I := 0 to ExceptFrameCount - 1 do
			Report := Report + LineEnding + BackTraceStrFunc(Frames[I]);
{$IFDEF LAZARUS_GUI}
		ShowMessage(Report);
{$ENDIF}
		Halt; // End of program execution
	end;

function checkDebugLongint(a, min, max: longint): boolean;
begin
	result := (a >= min) and (a <= max);
end;

	function yearTrunc (year: double; nDec: longint = 5): double;
	begin
		result := trunc (year * power (10, nDec)) / power (10, nDec);
	end;
	
	function stringConcatenate_sep (const a, b, sep: string): string;
	// concatenate a and b, checking whether a ends with sep:
	// add it only between a and b if a does not terminate with sep
	var
		lgSep, lga: longint;
	begin
		lgSep := length (sep);
		lga := length (a);
		if (lgSep < lga) and (copy (a, lga - lgSep + 1, lga) = sep) then
			result := a + b
		else
			result := a + sep + b;
	end;
	
	function myCheckChangedDefaultValues (listOfParams: GenericName): boolean;
	{Traverse the linked list checking whether at least one parameter value has changed
	and is different from the default value}
	begin
		while listOfParams <> nil do begin
			if listOfParams.changed then begin
				{At least one parameter value has changed so we exit the function
				returning true}
				result := true;
				exit;
			end;
			listOfParams := listOfParams.next;
		end;
		result := false;
	end;

	function checkChangedDefaultValues: boolean;
	begin
		result := DemRegimeCollection_CheckChangedDefaultValues() or myCheckChangedDefaultValues(g_GENPARAM.listOfParams);
	end;

function lengthSet (aSet: SetChars): longint;
var
	aChar: Char;
	i: longint = 0;
begin
	for aChar in aSet do
		inc(i);
	result := i;
end;

function elementInArray (const a: array of longint; elt: longint): boolean;
var
	i: longint;
begin
	result := false;
	for i := low(a) to high (a) do
		if a[i] = elt then begin
			result := true;
			exit;
		end;
end;

function elementInSet (aSet: SetChars; index: longint): Char;
var
	aChar: Char;
	i: longint = -1;
begin
	for aChar in aSet do begin
		inc (i);
		if i = index then begin
			result := aChar;
			exit;
		end;
	end;
end;

	function kinSetToString (kinSet: KinSetType): string;
	var
		s: string;
		rel: KinTypes;
	begin
		s := '';
		for rel := kFirstKinInEnum to kLastKinInEnum do
			if rel in kinSet then
				if length (s) = 0 then
					s := str_kinship[rel]
				else
					s := s + ',' + str_kinship[rel];
		result := s;
	end;
	
	function fieldSetToString (fieldSet: FieldSetType): string;
	var
		s: string;
		fd: FieldNamesTypes;
	begin
		s := '';
		for fd := low(FieldSetType) to high(FieldSetType) do
			if fd in fieldSet then
				if length (s) = 0 then
					s := str_FieldNames[fd]
				else
					s := s + ',' + str_FieldNames[fd];
		result := s;
	end;
	
	function findPartner (pRelative: pRelativeType; firstUnion: boolean; out rank: longint): pRelativeType;
	var
		i: longint = 1;
	begin
		if firstUnion then begin
			findPartner := getPartner (pRelative, 1);
			rank := 1;
		end else begin
		// last partner
			findPartner := nil;
			while (i < kMaxNbUnion) and (getPartner (pRelative, i + 1) <> nil) do
				i := i + 1;
			if (i >= 1) then
				findPartner := getPartner (pRelative, i);
			rank := i;
		end;
		
	end;

	function initDebugFile: boolean;
	begin
		initDebugFile := true;
		if gRunFromIDE then
		begin
			initDebugFile := false;
			if openFileOut('debugFile.txt', 'gDEBUGFILE', gDebugFile, kAsyncFalse) then
			begin
				initDebugFile := true;
				if not openFileOut('debugFertilityFile.txt', 'gDEBUGFERTFILE', gDebugFertFile, kAsyncFalse) then begin
					writeAndWaitConst(['===> ERROR: Error opening debugFertilityFile']);
					exit;
				end;
			end
			else begin
				writeAndWaitConst(['===> ERROR: Error opening debug file. Stopping...']);
				exit;
			end;
		end;
	end;

	function substituteChar(c1, c2: char; s: string): string;
	var
		i: integer;
	begin
		while Pos (c1, s) > 0 do begin
			i := Pos (c1, s);
			s[i] := c2;
		end;
		substituteChar := s;
	end;

	function stripChar (c: char; s: string): string;
	var
		i, ls: integer;
	begin
		while Pos (c, s) > 0 do begin
			i := Pos (c, s);
			ls := length (s);
			if ( i = ls ) then begin
				s := copy (s, 1, i-1);
			end
			else begin
				s := copy (s, 1, i-1) + copy (s, i+1, ls-i);
			end;
		end;
		stripChar := s;
	end;
	
	function checkCode ( aCommand: string; code: word ): boolean;
	begin
		if code <> 0 then begin
			writeAndWaitConst(['===> ERROR: Error ', aCommand, ' ', code]);
			checkCode := FALSE;
		end else
			checkCode := TRUE;
	end;
	
	function checkDir ( sDir: string ): boolean;
	begin
		checkDir := true;
		If Not DirectoryExists(sDir) then
			If Not CreateDir (sDir) Then
				checkDir := false;
	end;
	
	function checkDirResult (): boolean;
	begin
		if g_GENPARAM.WRITE_FOLDER.value and (gMainPathToResult = gPathToResult) then begin
			gPathToResult := gPathToResult + g_FileName.value + '_results' + pathDelim ;
		end;
		checkDirResult := checkDir (gPathToResult);
	end;

	function fileExist ( s: string; writeState: boolean ): boolean;
	var
		f: TextFile; {this function is normally called only by the main thread.
						If this is not the case, it should be made thread protected, or used
						in an async call}
						
	begin
		if ( s = '' ) then begin
			fileExist := false;
			exit;
		end;
{$I-}
		if ( writeState ) then begin
			if checkDirResult () then begin
				IOResult;
				assignFile (f, gPathToResult + s);
			end else begin
				fileExist := false;
				exit;
			end;
		end else begin
			IOResult;
			assignFile (f, gPathToConfig + s);
		end;
		
		reset(f);
{$I+}

		if ( IOResult = 0 ) then begin
			fileExist := true;
			close(f);
		end else fileExist := false;
	end;

	procedure writeKeysHeader;
	var
		mess: string;
	begin
		if not RP.wkey then
			exit;
		mess := 'nKey' + tab;
		if RP.wKeyBootstrap then
			mess := mess + 'indBootStrap' + tab;
		if RP.wKeyAgeUnion then begin
			mess := mess + 'indAgeUnion' + tab;
			mess := mess + 'valAgeUnion' + tab;
		end;
		if RP.wKeyCelibacy then begin
			mess := mess + 'indCelibacy' + tab;
			mess := mess + 'valCelibacy' + tab;
		end;
		if RP.wKeyStdCel then begin
			mess := mess + 'indStdCel' + tab;
			mess := mess + 'valStdCel' + tab;
		end;
		if RP.wKeyFertAmeno then begin
			mess := mess + 'indFertAmeno' + tab;
			mess := mess + 'valFertAmeno' + tab;
		end;
		if RP.wKeyFertControl then begin
			mess := mess + 'indFertControl' + tab;
			mess := mess + 'valFertControl' + tab;
		end;
		if RP.wKeyFertSeparation then begin
			mess := mess + 'indFertSeparation' + tab;
			mess := mess + 'valFertSeparation' + tab;
		end;
		if RP.wKeyFertContrUseAfterUnion then begin
			mess := mess + 'indFertContrUseAfterUnion' + tab;
			mess := mess + 'valFertContrUseAfterUnion' + tab;
		end;
		// strip last tab
		Mess := Copy(Mess, 1, length(Mess)-1);
		aWriteLn(gOutFileIndivKeys, [Mess]);
	end;
	
	procedure writeKeys;
	var
		mess: string;
	begin
		if not RP.wkey then exit;
		RP.key := RP.key + 1;
		mess := IntToStr(RP.key) + tab;
		if RP.wKeyBootstrap then
			mess := mess + IntToStr(RP.indBootstrap) + tab;
		if RP.wKeyAgeUnion then begin
			mess := mess + IntToStr(RP.indAgeUnion) + tab;
			mess := mess + FloatToStr(RP.valAgeUnion) + tab;
		end;
		if RP.wKeyCelibacy then begin
			mess := mess + IntToStr(RP.indCelibacy) + tab;
			mess := mess + FloatToStr(RP.valCelibacy) + tab;
		end;
		if RP.wKeyStdCel then begin
			mess := mess + IntToStr(RP.indStdCel) + tab;
			mess := mess + FloatToStr(RP.valStdCel) + tab;
		end;
		if RP.wKeyFertAmeno then begin
			mess := mess + IntToStr(RP.indFertAmeno) + tab;
			mess := mess + FloatToStr(RP.valFertAmeno) + tab;
		end;
		if RP.wKeyFertControl then begin
			mess := mess + IntToStr(RP.indFertControl) + tab;
			mess := mess + FloatToStr(RP.valFertControl) + tab;
		end;
		if RP.wKeyFertSeparation then begin
			mess := mess + IntToStr(RP.indFertSeparation) + tab;
			mess := mess + FloatToStr(RP.valFertSeparation) + tab;
		end;
		if RP.wKeyFertContrUseAfterUnion then begin
			mess := mess + IntToStr(RP.indFertContrUseAfterUnion) + tab;
			mess := mess + FloatToStr(RP.valFertContrUseAfterUnion) + tab;
		end;
		// strip last tab
		Mess := Copy(Mess, 1, length(Mess)-1);
		aWriteLn(gOutFileIndivKeys, [Mess]);
	end;
	
	function openFileKeys (oneFile: boolean; bootstrap_ind: longint = 0): boolean;
	var
		needsKeys: boolean = FALSE;
		stepsKeys: boolean = FALSE;
		bootStrapping: boolean;
		fileName: string;
	begin
		openFileKeys := FALSE;
		
		needsKeys := g_GENPARAM.OUTPUT_INDIVIDUAL_FERTILITY_INFO.value or g_GENPARAM.OUTPUT_INDIVIDUAL_KINSHIP_INFO.value;
		bootStrapping := (g_GENPARAM.RUNTIME[gBootstrap_nRuns].value > 1);
		RP.wKeyAgeUnion := ( g_GENPARAM.RUNTIME[nStepsUnion_mean].value > 1 );
		RP.wKeyCelibacy := ( g_GENPARAM.RUNTIME[nStepsUnion_prop].value > 1 );
		RP.wKeyStdCel := ( g_GENPARAM.RUNTIME[nStepsUnion_Dev].value > 1 );
		RP.wKeyFertAmeno := ( g_GENPARAM.RUNTIME[nStepsAmeno].value > 1 );
		RP.wKeyFertControl := ( g_GENPARAM.RUNTIME[nStepsContrFert].value > 1 );
		RP.wKeyFertSeparation := ( g_GENPARAM.RUNTIME[nStepsSeparation].value > 1 );
		RP.wKeyFertContrUseAfterUnion := ( g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value > 1 );
		RP.wKeyBootstrap := oneFile and bootStrapping;

		stepsKeys := 	RP.wKeyAgeUnion or RP.wKeyCelibacy or RP.wKeyStdCel or RP.wKeyFertAmeno or
						RP.wKeyFertControl or RP.wKeyFertSeparation or RP.wKeyFertContrUseAfterUnion;

		if DemRegimeCollection_VariousCohorts and stepsKeys then begin
			memoWriteLn (['Loops on AgeUnion or freqCel or stdDevUnion or Ameno or ContrFert or Separation or ContrUseAfterUnion...']);
			memoWriteLn (['... are allowed ONLY when there is one set of fertility and union formation parameters (only one cohort demographic regime)']);
			
			g_GENPARAM.RUNTIME[nStepsUnion_mean].value := 1;
			g_GENPARAM.RUNTIME[nStepsUnion_prop].value:= 1;
			g_GENPARAM.RUNTIME[nStepsUnion_Dev].value:= 1;
			g_GENPARAM.RUNTIME[nStepsAmeno].value:= 1;
			g_GENPARAM.RUNTIME[nStepsContrFert].value:= 1;
			g_GENPARAM.RUNTIME[nStepsSeparation].value:= 1;
			g_GENPARAM.RUNTIME[nStepsContrUseAfterUnion].value:= 1;
			stepsKeys := False;
		end;
			
		RP.wkey := needsKeys and (stepsKeys or RP.wKeyBootstrap);
		
		if RP.wkey then begin
			fileName := stringConcatenate_sep (g_FileName.value, 'KEYS', '_');
			if bootStrapping then begin
				if oneFile then begin
					if (bootstrap_ind > 0) then exit;
				end else begin
					if (bootstrap_ind = 0) then exit;
					fileName := stringConcatenate_sep (fileName, intToStr(bootstrap_ind), '_');
				end;
			end else begin
			if (bootstrap_ind > 0) then exit;
			end;
			fileName := fileName + '.txt';
			if not openFileOut (fileName, 'gOUTFILEINDIVKEYS', gOutFileIndivKeys, kAsyncFalse) then begin
				exit;
			end;
			RP.key := 0;
			writeKeysHeader;
		end;
		if (bootstrap_ind > 0) then RP.indBootstrap := bootstrap_ind;
		openFileKeys := TRUE;
	end;
	
	procedure closeFileKeys (doIt: boolean);
	begin
		if doIt and RP.wkey then gOutFileIndivKeys.Destroy;
	end;
	
	function openFileRead ( s: ansistring; name: string; out f: TFileType ): boolean;
	var
		res: longint;
	begin
		if ( s = '' ) then begin
			openFileRead := false;
			exit;
		end;
		f := TFileType.Create (gPathToConfig + s, res, name, f_reset);
		f.aSync := false;
		
		if ( res = 0 ) then
			openFileRead := true
		else
			openFileRead := false;
	end;
	
	function openFileWriteConfig ( s: ansistring; name: string; out f: TFileType): boolean;
	var
		res: longint;
	begin
		openFileWriteConfig := false;
		if ( s = '' ) then begin
			exit;
		end;
		f := TFileType.Create (gPathToConfig + s, res, name);
		f.aSync := false;
		
		if ( res = 0 ) then
			openFileWriteConfig := true;
	end;
	
	function initAggrKinshipFile (s: string; checkFileExists: boolean; bootstrap_ind: longint): boolean;
	var
		res: longint;
	begin
		initAggrKinshipFile := false;
					
		res := 0;

		s := stringConcatenate_sep (s, 'SIM', '_');
		if ( g_GENPARAM.RUNTIME[gBootstrap_nRuns].value > 1 ) then
			s := stringConcatenate_sep (s, IntToStr (bootstrap_ind), '_');
		s := concat(s, '.TXT');
		
		if openFileOut(s, 'gOUTFILEKIN', gOutFileKin, kAsyncFalse) then begin
 			initAggrKinshipFile := true;
		end;
	end;

	function openFileOut(sFichOut: string; name: string; out outFile: TFileType; aSync: boolean = true; mode: fileModes = f_rewrite): boolean;
	// openAndClose will be true for multithreading, when read / write ops will be made async and each ops will open and close the file
	begin
		result := false;
		if not checkDirResult () then begin
			memoWriteLn(['Result directory for: ' + sFichOut + 'does not exist']);
			exit;
		end;

		result := openFileOutWithPath (gPathToResult + sFichOut, name, outFile, aSync, mode);
		if result and (name = 'gDEBUGFILE') then
			InitCriticalSection(g_CriticalSection);
	end;
	
	function openFileOutWithPath(sFichOut: string; name: string; out outFile: TFileType; aSync: boolean = true; mode: fileModes = f_rewrite): boolean;
	var
		res: longint;
	begin
		result := false;
		outFile := TFileType.Create (sFichOut, res, name, mode);
		if ( res = 0 ) then
		begin
			outFile.aSync := aSync;
			result := true;
			if aSync and g_GENPARAM.MULTITHREADING.value then
				// we close the file but don't dispose of the file object
				// because we are in multithreading, so all read / write ops
				// will be made in async calls, and each op will open and close the file
				closeFile (outFile.fileHandle);
			exit;
		end;
		outFile.Destroy;
		outFile := nil;
		
		writeAndWaitConst(['===> ERROR: Error, problem writing to: ' + sFichOut]);
	end;
	
	function initSpecificFileOut(sFichOut: string; bootstrap_ind: longint): boolean;
	var
		sEnd: string;

	begin
		result := false;

		if ( g_GENPARAM.RUNTIME[gBootstrap_nRuns].value > 1 ) then
			sEnd := '_' + IntToStr (bootstrap_ind) + '.txt'
		else
			sEnd := '.txt';

		if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value then begin
			if ( not openFileOut(sFichOut + '_FERT' + sEnd, 'gMAINOUTFILE', gMainOutFile, kAsyncFalse) ) then
				exit;
		end else begin
			if ( not openFileOut(sFichOut + '_PPR' + sEnd, 'gOUTFILEPPR', gOutFilePPR, kAsyncFalse) ) then
				exit;
			if ( not openFileOut(sFichOut + '_Fec' + sEnd, 'gOUTFILEFEC', gOutFileFec, kAsyncFalse) ) then
				exit;
			if ( not openFileOut(sFichOut + '_AgeMat' + sEnd, 'gOUTFILEAGEMAT', gOutFileAgeMat, kAsyncFalse) ) then
				exit;
		end;			
						
		result := true;
	end;

	procedure closeAllFiles;
		procedure destroyIt (var aFileHandler: TFileType);
		begin
			if aFileHandler <> nil then
				aFileHandler.Destroy;
			aFileHandler := nil;
		end;
	begin
{$I-}
		if (not Application.Terminated) then
		begin
			destroyIt (gOutFileKin);
			destroyIt (gOutFileIndivFec);
			destroyIt (gOutFileIndivKin);
			destroyIt (gOutFileIndivKin_link);
			destroyIt (gMainOutFile);
			destroyIt (gOutFilePPR);
			destroyIt (gOutFileFec);
			destroyIt (gOutFileAgeMat);
			if gRunFromIDE then begin
				DoneCriticalSection(g_CriticalSection);
				destroyIt (gDebugFile);
				destroyIt (gDebugFertFile);
			end;
			//gFiles.Destroy;
			//gFiles := nil;
		end;
{$I+}
	end;

	procedure AsyncCloseFiles;
	begin
		Application.QueueAsyncCall(@KinFertForm.myCloseFiles, {%H-}PtrInt(nil));
	end;

	procedure writeDebugOld (const Args: Array of const);
	var
		f: TFileType;
		res: longint;
		fileName: string;
	begin
		fileName := gPathToResult + 'debugFile.txt';
		if checkDirResult () then begin
			if FileExists(fileName) then
				f := TFileType.Create (fileName, res, 'DEBUG_FILE', f_append)
			else
				f := TFileType.Create (fileName, res, 'DEBUG_FILE', f_rewrite);
			f.aSync := false;
			if res <> 0 then
				bWriteLn (f, Args);

			f.Destroy;
		end;
	end;

	procedure writeAndWaitConst (const Args: Array of const);
	begin
		writeAndWait(cStringOf(Args));
	end;
	
	procedure writeAndWait (s: string);
	begin
{$IFDEF LAZARUS_GUI}
		//ShowMessage(s);
		memoWriteLn([s]);
		if gRunFromIDE then
			if gDebugFile <> nil then begin
				EnterCriticalSection (g_CriticalSection);
				bWriteLn (gDebugFile, [s]);
				LeaveCriticalSection (g_CriticalSection);
			end;
		gDebugError := TRUE;
{$ELSE}
		memoWriteLn([s]);
		write ('Press RETURN to keep processing...');
		readLn(temp);
{$ENDIF}
	end;

	procedure fileScreenWrite (outFile: TFileType; const Args: Array of const; writeToFile: boolean = true);
	var
		s: string;
	begin
		if (g_silentMode) then exit;
		
		s := cStringOf(Args);
		memoWrite ([s]);
		if (writeToFile) then
			cWrite (outFile, s);
	end;
	
	procedure fileScreenWriteLn (
					outFile: TFileType;
					const Args: Array of const;
					colType: inColumnType = col_none;
					writeToFile: boolean = true;
					writeToScreen: boolean = true);
	var
		s: string;
	begin
		if (g_silentMode) then exit;
		
		if (colType = col_header) then
			SetLength (g_lnColumns, 100);
		
		if writeToScreen then begin
			// format for screen writing
			s := cStringOf(Args, colType);
			memoWriteLn ([s]);
		end;
		if (writeToFile) then begin
			// file writing does not need formatting
			s := cStringOf(Args);
		{$I-}
			cWriteLn (outFile, s);
		{$I+}
		end;
	end;
	
	procedure EndTableWithHeader;
	begin
		SetLength (g_lnColumns, 0)
	end;
	
	procedure cWrite (outFile: TFileType; s: string = '');
	begin
		if (outFile = nil) or (not outFile.fileOpenToWrite) then exit;
		if s <> '' then outFile.writtenTo := true;
		if g_GENPARAM.MULTITHREADING.value and outFile.aSync then begin
			KinFertForm.myWrite (outFile, s)
		end else
		{$I-}
			write (outFile.fileHandle, s);
		{$I+}
	end;
	
	procedure cWriteLn (outFile: TFileType; s: string = '');
	begin
		if (outFile = nil) or (not outFile.fileOpenToWrite) then exit;
		if s <> '' then outFile.writtenTo := true;
		if g_GENPARAM.MULTITHREADING.value and outFile.aSync then begin
			KinFertForm.myWriteLn (outFile, s)
		end else
		{$I-}
			writeLn (outFile.fileHandle, s);
		{$I+}
	end;
	
	procedure bWrite (outFile: TFileType; const Args: Array of const; minFloatDigitsInFile: longint = 5);
	// minFloatDigitsInFile is the minimum value of digits for the fractional part in a file
	// the value can be incremented using the FLOATING_POINT_PRECISION parameter in OUTPUT pane
	var
		s: string;
	begin
		s := cStringOf(Args, col_none, minFloatDigitsInFile);
		cWrite (outFile, s);
	end;
	
	procedure bWriteLn (outFile: TFileType; const Args: Array of const; minFloatDigitsInFile: longint = 5);
	// minFloatDigitsInFile is the minimum value of digits for the fractional part in a file
	// the value can be incremented using the FLOATING_POINT_PRECISION parameter in OUTPUT pane
	var
		s: string;
	begin
		s := cStringOf(Args, col_none, minFloatDigitsInFile);
		cWriteLn (outFile, s);
	end;
	
	procedure aWriteAll (s: string);
	begin
		if (g_silentMode) then exit;
		
		if g_GENPARAM.FERTILITY.value then begin
			if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value then begin
				cWrite (gMainOutFile, s);
			end else begin
				cWrite (gOutFilePPR, s);
				cWrite (gOutFileFec, s);
				cWrite (gOutFileAgeMat, s);
			end;
		end;
		if g_GENPARAM.KINSHIP.value and g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP.value then
			cWrite (gOutFileKin, s);
	end;
	
	procedure aWriteLnAll (s: string);
	begin
		if (g_silentMode) then exit;

		if g_GENPARAM.FERTILITY.value then begin
			if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value then begin
				cWriteLn (gMainOutFile, s);
			end else begin
				cWriteLn (gOutFilePPR, s);
				cWriteLn (gOutFileFec, s);
				cWriteLn (gOutFileAgeMat, s);
			end;
		end;
		if g_GENPARAM.KINSHIP.value and g_GENPARAM.OUTPUT_AGGREGATE_KINSHIP.value then
			cWriteLn (gOutFileKin, s);
	end;
	
	procedure multWrite (const outs: Array of const; const Args: Array of const);
	var
		i: longint;
		nf: longint = 1;
	begin
		if (g_silentMode) then exit;

		if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value then
		begin
			aWrite(gMainOutFile, Args); 
		end else begin
			for i:=0 to High(outs) do 
			begin
				case outs[i].vType of 
					vtPointer :
						begin
							//nf := gFiles.new ('');
							if (nf >= 0) then begin
								//gFiles.get (nf).fileHandle := TextFile(outs[i].vPointer^);
								//aWrite(gFiles.get (nf), Args);
								aWrite(TFileType(outs[i].vPointer^), Args);
							end;
						end;
					else
						;
				end;
			end;
		end;
	end;

	procedure multWriteLn (const outs: Array of const; const Args: Array of const);
	var
		i: longint;
		nf: longint = 1;
	begin
		if (g_silentMode) then exit;

		if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value then
		begin
			aWriteLn(gMainOutFile, Args); 
		end else begin
			for i:=0 to High(outs) do 
			begin
				case outs[i].vType of 
					vtPointer :
						begin
							//nf := gFiles.new ('');
							if (nf >= 0) then begin
								//gFiles.get (nf).fileHandle := TextFile(outs[i].vPointer^);
								//aWriteLn(gFiles.get (nf), Args);
								aWriteLn(TFileType(outs[i].vPointer^), Args);
							end;
						end;
					else
						;
				end;
			end;
		end;
	end;
	
	procedure aWrite (outFile: TFileType; const Args: Array of const; forceFile: boolean = false);
	var
		s: string;
	begin
		if ( (g_silentMode) or (g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY.value = false) ) and not forceFile then exit;

		s := cStringOf(Args);
		if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value and not forceFile then
		begin
			cWrite (gMainOutFile, s);
		end else
		begin
			cWrite (outFile, s);
		end;
	end;
	
	procedure aWriteLn (outFile: TFileType; const  Args: Array of const; forceFile: boolean = false);
	var
		s: string;
	begin
		if ( (g_silentMode) or (g_GENPARAM.OUTPUT_AGGREGATE_FERTILITY.value = false) ) and not forceFile then exit;

		s := cStringOf(Args);
		if g_GENPARAM.outputs_opt[cmd_outputtomainfile].value and not forceFile then
		begin
			cWriteLn (gMainOutFile, s);
		end else
		begin
			cWriteLn (outFile, s);
		end;
	end;
	

	procedure myHalt (const Args: Array of const);
	var
			s: string;
	begin
		s := cStringOf(Args);
		if s = '' then
			s := 'Error, halting the program'
		else
			s := 'Error, halting the program: ' + s;
{$IFDEF LAZARUS_GUI}
		memoWriteLn([s]);
{$ELSE}
		writeAndWait (s);
{$ENDIF}
		halt;
	end;

	procedure memoWrite (const Args: Array of const);
	begin
{$IFDEF LAZARUS_GUI}
		KinFertForm.doMemoWrite(cStringOf(Args));
{$ELSE}
		write (cStringOf(Args));
{$ENDIF}
	end;

	procedure memoWriteLn (const Args: Array of const);
	begin
{$IFDEF LAZARUS_GUI}
		KinFertForm.doMemoWriteLn(cStringOf(Args));
{$ELSE}
		writeLn (cStringOf(Args));
{$ENDIF}
	end;

	procedure FlushIO;
	begin
{$IFDEF LAZARUS_GUI}
		KinFertForm.AsyncFlushString;
{$ENDIF}
	end;

	function str_float (float: double; minFloatDigitsInFile: longint = 0): string;
	begin
		if g_GENPARAM.OUTPUT_INDIVIDUAL_AGE_FLOAT.value then
			result := FloatToStrF(	float, ffFixed,
									g_GENPARAM.outputs_fmt[res_floatingNumberPrecision].value,
									max (minFloatDigitsInFile, g_GENPARAM.outputs_fmt[res_floatingNumberDigits].value),
									gFormatSettings)
		else
			result := IntToStr (trunc (float));
	end;

	procedure writeArrayOfDouble (outFile: TFileType; sep: string; const ad: Array of double);
	var
		ind, len: longint;
	begin
		len := length (ad) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			bWrite(outFile, [ad[ind], sep])
	end;

	procedure writeLnArrayOfDouble (outFile: TFileType; sep: string; const ad: Array of double);
	begin
		writeArrayOfDouble (outFile, sep, ad);
		cWriteLn(outFile)
	end;
	
	procedure writeArrayOfDoubleOffset (outFile: TFileType; sep: string; const ad: Array of double; offset: longint);
	var
		ind, len: longint;
	begin
		len := length (ad) - 1 - offset;
		if len = 0 then sep := '';
		for ind := 0 to len do
			bWrite(outFile, [ad[ind + offset], sep])
	end;

	procedure writeLnArrayOfDoubleOffset (outFile: TFileType; sep: string; const ad: Array of double; offset: longint);
	begin
		writeArrayOfDoubleOffset (outFile, sep, ad, offset);
		cWriteLn(outFile)
	end;
	
	procedure writeOneArrayOfDouble (fileName: string; const ad: Array of double);
	var
		f: TFileType;
        res: longint;
	begin
		if checkDirResult () then begin
            f := TFileType.Create (gPathToResult + fileName, res, 'NONAME');
            f.aSync := false;
			if (res = 0) then writeLnArrayOfDouble (f, tab, ad);
			f.Destroy;
		end;
	end;
	
	{ --------------------------------------------------------------------------------
	  dumpArray

	  A debugging convenience. Writes one array to <results>/<name>.txt as two tab
	  separated rows: the indices on the first, the values on the second. The file
	  opens directly in a spreadsheet and is rewritten on every call.

	  firstIndex labels the first column. An open array parameter always starts at 0
	  inside the procedure, whatever the caller's declaration, so for a static array
	  over a subrange pass its low bound:
	      dumpArray ('gFecundability', gFecundability, kMinAgeFert);
	      dumpArray ('gDistrib_fecundability', gDistrib_fecundability);

	  Doubles are written at full precision with a decimal POINT, because Init.pas
	  sets gFormatSettings.DecimalSeparator to '.'. A spreadsheet configured for a
	  decimal comma has to be told so on import.

	  Main thread only, like writeState: it opens its own file with aSync false.
	  Tabs inside string values are replaced by spaces so the columns stay aligned.
	  -------------------------------------------------------------------------------- }
	procedure dumpArray_strings (name: string; const s: Array of string; firstIndex: longint);
	var
		ind, res: longint;
		f: TFileType;
	begin
		if length (s) = 0 then begin
			memoWriteLn (['dumpArray: ', name, ' has no elements, nothing written']);
			exit;
		end;
		if not checkDirResult () then exit;
		f := TFileType.Create (gPathToResult + name + '.txt', res, 'DUMPARRAY');
		if (res = 0) then begin
			f.aSync := false;
			bWrite (f, ['index', tab]);
			for ind := 0 to length (s) - 1 do
				bWrite (f, [firstIndex + ind, tab]);
			cWriteLn (f);
			bWrite (f, [name, tab]);
			for ind := 0 to length (s) - 1 do
				bWrite (f, [s[ind], tab]);
			cWriteLn (f);
		end;
		f.Destroy;
	end;

	procedure dumpArray (name: string; const a: Array of double; firstIndex: longint = 0);
	var
		s: Array of string;
		ind: longint;
	begin
		setLength (s, length (a));
		for ind := 0 to length (a) - 1 do
			s[ind] := floatToStrF (a[ind], ffGeneral, 15, 0, gFormatSettings);
		dumpArray_strings (name, s, firstIndex);
	end;

	procedure dumpArray (name: string; const a: Array of longint; firstIndex: longint = 0);
	var
		s: Array of string;
		ind: longint;
	begin
		setLength (s, length (a));
		for ind := 0 to length (a) - 1 do
			s[ind] := intToStr (a[ind]);
		dumpArray_strings (name, s, firstIndex);
	end;

	procedure dumpArray (name: string; const a: Array of boolean; firstIndex: longint = 0);
	var
		s: Array of string;
		ind: longint;
	begin
		setLength (s, length (a));
		for ind := 0 to length (a) - 1 do
			if a[ind] then s[ind] := 'TRUE' else s[ind] := 'FALSE';
		dumpArray_strings (name, s, firstIndex);
	end;

	procedure dumpArray (name: string; const a: Array of char; firstIndex: longint = 0);
	var
		s: Array of string;
		ind: longint;
	begin
		setLength (s, length (a));
		for ind := 0 to length (a) - 1 do
			s[ind] := a[ind];
		dumpArray_strings (name, s, firstIndex);
	end;

	procedure dumpArray (name: string; const a: Array of string; firstIndex: longint = 0);
	var
		s: Array of string;
		ind: longint;
	begin
		setLength (s, length (a));
		for ind := 0 to length (a) - 1 do
			s[ind] := substituteChar (tab, ' ', a[ind]);
		dumpArray_strings (name, s, firstIndex);
	end;

	procedure writeArrayOfLongint (outFile: TFileType; sep: string; const al: Array of longint);
	var
		ind, len: longint;
	begin
		len := length (al) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do begin
			bWrite(outFile, [al[ind], sep]);
		end;
	end;

	procedure writeLnArrayOfLongint (outFile: TFileType; sep: string; const al: Array of longint);
	begin
		writeArrayOfLongint (outFile, sep, al);
		cWriteLn(outFile);
	end;

	procedure writeArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	var
		ind, len: longint;
	begin
		len := length (ad) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			with ad[ind] do begin
				if not removeOptional or not optional then begin
					bWrite(outFile, [name, sep]);
					bWrite(outFile, [value, sep]);
				end;
			end;
	end;

	procedure writeLnArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	begin
		writeArrayOfDoubleName (outFile, sep, ad, removeOptional);
		cWriteln(outFile);
	end;
	
	procedure write_Name_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	var
		ind, len: longint;
	begin
		len := length (ad) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			with ad[ind] do begin
				if not removeOptional or not optional then
					bWrite(outFile, [name, sep]);
			end;
	end;

	procedure writeLn_Name_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	begin
		write_Name_ArrayOfDoubleName (outFile, sep, ad, removeOptional);
		cWriteln(outFile);
	end;
	
	procedure write_Value_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	var
		ind, len: longint;
	begin
		len := length (ad) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			with ad[ind] do begin
				if not removeOptional or not optional then
					bWrite(outFile, [value, sep]);
			end;
	end;

	procedure writeLn_Value_ArrayOfDoubleName (outFile: TFileType; sep: string; const ad: Array of doubleName; removeOptional: boolean = false);
	begin
		write_Value_ArrayOfDoubleName (outFile, sep, ad, removeOptional);
		cWriteln(outFile);
	end;
	

	procedure writeArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	var
		ind, len: longint;
	begin
		len := length (al) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			with al[ind] do begin
				if not removeOptional or not optional then begin
					bWrite(outFile, [name, sep]);
					bWrite(outFile, [value, sep]);
				end;
			end;
	end;

	procedure writeLnArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	begin
		writeArrayOfLongintName (outFile, sep, al, removeOptional);
		cWriteln(outFile);
	end;
	

	procedure write_Name_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	var
		ind, len: longint;
	begin
		len := length (al) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			with al[ind] do begin
				if not removeOptional or not optional then
					bWrite(outFile, [name, sep]);
			end;
	end;

	procedure writeLn_Name_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	begin
		write_Name_ArrayOfLongintName (outFile, sep, al, removeOptional);
		cWriteln(outFile);
	end;
	
	procedure write_Value_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	var
		ind, len: longint;
	begin
		len := length (al) - 1;
		if len = 0 then sep := '';
		for ind := 0 to len do
			with al[ind] do begin
				if not removeOptional or not optional then
					bWrite(outFile, [value, sep]);
			end;
	end;

	procedure writeLn_Value_ArrayOfLongintName (outFile: TFileType; sep: string; const al: Array of longintName; removeOptional: boolean = false);
	begin
		write_Value_ArrayOfLongintName (outFile, sep, al, removeOptional);
		cWriteln(outFile);
	end;
	
	function isInteger (num: double): boolean;
	begin
		isInteger := num = trunc (num);
	end;
	
	procedure screenFileWrite (s: string; forceWrite: boolean = false);
	begin
		if (g_silentMode and not forceWrite) then exit;
		memoWrite([s]);
	end;

	procedure screenFileWriteLn (s: string; forceWrite: boolean = false);
	begin
		if (g_silentMode and not forceWrite) then exit;
		memoWriteLn([s]);
	end;

	procedure noMemory (s: string);
	begin
		writeAndWait(concat('Not enough memory creating the space for: ', s));
	end;

	function SetLengthDoubleZero (n: longint): arraydoubletype;
	var
		i: longint;
		a: arraydoubletype;
	begin
		SetLength (a{%H-}, n);
		for i := 0 to (n-1) do
			a[i] := 0.0;
		SetLengthDoubleZero := a;
	end;

	function SetLengthDouble (n: longint; value: double): arraydoubletype;
	var
		i: longint;
		a: arraydoubletype;
	begin
		SetLength (a{%H-}, n);
		for i := 0 to (n-1) do
			a[i] := value;
		SetLengthDouble := a;
	end;

	function min_real (a, b: double): double;
	begin
		if a < b then
			min_real := a
		else
			min_real := b;
	end;

	function max_real (a, b: double): double;
	begin
		if a > b then
			max_real := a
		else
			max_real := b;
	end;

	function min (a, b: longint): longint;
	begin
		if a < b then
			min := a
		else
			min := b;
	end;

	function max (a, b: longint): longint;
	begin
		if a > b then
			max := a
		else
			max := b;
	end;

	// Isolate digit at position pos of number r
	// Example: dPos (81231, 3) returns 2
	// last digit is at position 1, so dPos (81231, 1) returns 1
	// pos should be > 0
	function dPos (r: longint; pos: longint): longint;
	var
		maskHigh: longint;
	begin
		maskHigh := trunc ( trunc (r / power(10, pos)) * power(10, pos) );
		dPos := trunc ( (r - maskHigh) / power(10, pos-1) );
	end;
	
	function interpole (a1, a2: double; i, n: longint): double;
	begin
		interpole := a1 + ( a2 - a1 ) * i / n;
	end;
		
	function toAgeQuinq (age: longint): ageQuinq;
	begin
		case age of
			10, 11, 12, 13, 14: toAgeQuinq := f1014;
			15, 16, 17, 18, 19: toAgeQuinq := f1519;
			20, 21, 22, 23, 24: toAgeQuinq := f2024;
			25, 26, 27, 28, 29: toAgeQuinq := f2529;
			30, 31, 32, 33, 34: toAgeQuinq := f3034;
			35, 36, 37, 38, 39: toAgeQuinq := f3539;
			40, 41, 42, 43, 44: toAgeQuinq := f4044;
			45, 46, 47, 48, 49: toAgeQuinq := f4549;
			50, 51, 52, 53, 54: toAgeQuinq := f5054;
			55, 56, 57, 58, 59: toAgeQuinq := f5559;
		end;
	end;
	
	function ageQuinqToStr (ageQ: ageQuinq): string;
	begin
		case ageQ of
			f1014: ageQuinqToStr := '10-14 years';
			f1519: ageQuinqToStr := '15-19 years';
			f2024: ageQuinqToStr := '20-24 years';
			f2529: ageQuinqToStr := '25-29 years';
			f3034: ageQuinqToStr := '30-34 years';
			f3539: ageQuinqToStr := '35-39 years';
			f4044: ageQuinqToStr := '40-44 years';
			f4549: ageQuinqToStr := '45-49 years';
			f5054: ageQuinqToStr := '50-54 years';
			f5559: ageQuinqToStr := '55-59 years';
			ftotal: ageQuinqToStr := 'All ages';
		end;
	end;
	
{$IFDEF UnionStatesType}
	function UnionStateToStr (s: UnionStatesType): string;
	begin
		case s of
			ongoing_union: UnionStateToStr := 'union';
			ended_separation: UnionStateToStr := 'separation';
			ended_widowhood: UnionStateToStr := 'death husband';
		end;
	end;
{$ENDIF}

	function runDrawsFromSeveralThreads: boolean;
	{TRUE when at least one phase that draws random numbers runs on several threads.
	 Only such a run cannot repeat the same random sequence: the order in which the
	 threads draw is not determined. A run whose threaded phases are all switched off
	 is single threaded for the random numbers and CAN be reproduced.}
	begin
		result := g_GENPARAM.MULTITHREADING.value and
				  ( g_GENPARAM.MULTITHREADING_SIMKIN.value or
					g_GENPARAM.MULTITHREADING_INITMOTHERHOOD.value ) and
				  (gMaxThreads > 1);
	end;

	function PartnershipStatusToStr (s: PartnershipStatusesType): string;
	begin
		case s of
			neverInUnion: PartnershipStatusToStr := 'never in union';
			firstUnion: PartnershipStatusToStr := 'first union';
			secondUnions: PartnershipStatusToStr := 'second or more union';
			widow: PartnershipStatusToStr := 'widow';
			separated: PartnershipStatusToStr := 'separated';
			everInUnion: PartnershipStatusToStr := 'ever in union';
			any: PartnershipStatusToStr := 'any';
			dead: PartnershipStatusToStr := 'dead';
		end;
	end;
	
	function writeResults (res: outputKind_boolean): boolean;
	begin
		writeResults := g_GENPARAM.outputs_opt [res].value;
	end;
end.
