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

		// delete trailing 0s
		while (Result[length(Result)] = '0') do begin
			Result := Copy(Result, 1, length(Result)-1);
		end;
		if Result[length(Result)] = '.' then Result := Copy(Result, 1, length(Result)-1);
	end;

	function doubleToMinString (d: double; minFloatDigitsInFile: longint = 0): string;
	begin
		if gWritingConfigFile then
			Result := doubleToMinStringHelper (d, 10, g_GENPARAM.outputs_fmt[res_floatingNumberPrecision].value)
		else
			Result := doubleToMinStringHelper (d, g_GENPARAM.outputs_fmt[res_floatingNumberDigits].value, g_GENPARAM.outputs_fmt[res_floatingNumberPrecision].value, minFloatDigitsInFile);
		end;
	end.
