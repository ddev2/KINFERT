{$I Defines.pas}
unit StringOfLib;

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, SysUtils, Math;
	
type
	inColumnType = (col_none, col_header, col_table);

	function cStringOf (const Args: Array of const; colType: inColumnType = col_none; minFloatDigitsInFile: longint = 0): string;
	function doubleToMinStringHelper (d: double; digits: longint = 3; precision: longint = 15; minFloatDigitsInFile: longint = 0): string;
	function doubleToMinString (d: double; minFloatDigitsInFile : longint = 0): string;

	
var
	g_lnColumns: array of longint;
	
implementation

	function convertTabFn (sIn: string; convertTab: boolean): string;
	begin
		result := sIn;
		if (convertTab and (sIn = tab)) then
			result := ' ';
	end;

	function adjustLength (sIn: string; colType: inColumnType; var indHeader: longint): string;
	var
		ln, lgField: longint;
	begin
		result := sIn;
		ln := length(sIn);
		if (colType = col_header) then begin
			g_lnColumns[indHeader] := ln;
			Inc (indHeader);
		end else if (colType = col_table) then begin
			lgField := g_lnColumns[indHeader];
			if (lgField > 0) and (ln < lgField) then
				if (indHeader = 0) then
					// the first field is left-centered (normally a string)
					result := (sIn + copy(gBlanks, 1, lgField - ln))
				else
					// starting with the second field we right-center (normally a number)
					result := (copy(gBlanks, 1, lgField - ln) + sIn);
			Inc (indHeader);
		end;
	end;
	
	function cStringOf (const Args: Array of const; colType: inColumnType = col_none; minFloatDigitsInFile: longint = 0): string;
		var
			i: longint;
			sep: string;
			s: string;
			indHeader: longint = 0;
	begin
		s := '';
		if High(Args) = 0 then sep := '' else sep := tab;
		For i:= 0 to High(Args) do
		begin
			case Args[i].vType of 
				vtInteger :
					s := s + adjustLength(intToStr (args[i].vInteger), colType, indHeader);
// >>> Claude 2026-09-11 start
				{An integer EXPRESSION handed to one of these calls, 'a - b' for instance, does
				 not arrive as vtInteger: FPC widens the arithmetic and passes it as vtInt64.
				 Without this case it fell to the else below and the value was dropped from the
				 line without a trace, which is how a count can silently come out as an empty
				 space in the memo or in a results file. vtQWord is here for the same reason.}
				vtInt64 :
					s := s + adjustLength(intToStr (args[i].vInt64^), colType, indHeader);
				vtQWord :
					s := s + adjustLength(intToStr (args[i].vQWord^), colType, indHeader);
// <<< Claude 2026-09-11 end
				vtBoolean :
					if ( args[i].vBoolean = true ) then begin
						s := s + 'TRUE';
					end else begin
						s := s + 'FALSE';
					end;
				vtChar : 
					s := s + convertTabFn(args[i].vchar, (colType <> col_none)); 
				vtExtended : 
					s := s + adjustLength(doubleToMinString (args[i].vExtended^, minFloatDigitsInFile), colType, indHeader);
				vtString :
					s := s + adjustLength(args[i].vString^, colType, indHeader);
				vtPointer : 
					s := s; 
				vtPChar : 
					s := s; 
				vtObject : 
					s := s; 
				vtClass : 
					s := s; 
				vtAnsiString : 
					s := s + adjustLength(AnsiString(Args[I].VAnsiString), colType, indHeader); 
				else
					s := s;
				s := s + sep;
			end; 
		end;
		cStringOf := s;
	end;
	
	{create a string from a double with the minimum number of characters}
	function doubleToMinStringHelper (d: double; digits: longint = 3; precision: longint = 15; minFloatDigitsInFile: longint = 0): string;
	begin
		Result := floatToStrF (d, ffFixed, precision, max(digits, minFloatDigitsInFile), gFormatSettings);

// BUG  **N45**  the trailing zero strip has no guard that a decimal point remains
// The loop removes trailing zeros from a string that may have no decimal point at all, and no
// test stops it when the string becomes empty. With FLOATING_POINT_DIGITS at its shipped value
// of 3 the behaviour is correct, since floatToStrF always writes a point. At 0 it is
// destructive, verified by running FPC 3.2.2: **100 is written as "1"** and 20 as "2", and both
// 0.23 and 0.0 raise ERangeError under the range checks of Defines.pas, because Result becomes
// empty and Result[0] is read.
// It is reachable: LongintName.readValue does no range check at all, so a hand-written or
// hand-edited configuration file can set FLOATING_POINT_DIGITS to 0 or to a negative number.
// The GUI clamps it to 1 to 10, which is why this has never been seen.
// Proposed fix: strip only while the string still contains a decimal point,
//     while (Pos ('.', Result) > 0) and (Result [length (Result)] = '0') do ...
// and, separately, range check LongintName.readValue, since every longint parameter read from a
// file shares this exposure.
		// delete trailing 0s
		while (Result[length(Result)] = '0') do begin
			Result := Copy(Result, 1, length(Result)-1);
		end;
		if Result[length(Result)] = '.' then Result := Copy(Result, 1, length(Result)-1);
// END BUG
	end;

	function doubleToMinString (d: double; minFloatDigitsInFile: longint = 0): string;
	{Same reason as str_float in Utilities.pas: the format parameters are nil until
	 initGeneralCmd has run, and cStringOf reaches this for every double, including the ones
	 writeAndWaitConst is given.}
	begin
		if gWritingConfigFile then
			Result := doubleToMinStringHelper (d, 10, outputFloatingPrecision)
		else
			Result := doubleToMinStringHelper (d, outputFloatingDigits, outputFloatingPrecision, minFloatDigitsInFile);
		end;
	end.
