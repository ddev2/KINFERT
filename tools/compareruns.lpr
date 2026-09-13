program compareruns;

{$mode objfpc}{$H+}

{ ----------------------------------------------------------------------------------
  compareruns: compare two results folders of KinFert, or check one of them

  The out-of-process half of verification. Verification.pas decides what can be checked
  from inside a single run. This decides what needs two runs, or a run against a folder
  kept from an earlier one: that a change left ordinary runs untouched, that two steps of
  a sweep really differ, that two multithreaded runs do not repeat a genealogy, that a
  data row has as many columns as its header.

  Build it once, in the tools folder:

      fpc -O2 compareruns.lpr

  Then:

      compareruns A B                 every file, cell by cell
      compareruns A B -tol 1e-9       numbers within that relative distance count as equal
      compareruns A B -only fec       only files whose name contains fec
      compareruns A B -summary        one line per file
      compareruns A B -max 5          at most five differences listed per file
      compareruns A -headers          column counts against the header row

  The exit code is 0 when the two folders agree and 1 when they do not, so it can be used
  from a script. A file present in one folder only counts as a difference.

  Columns are separated by tabs, which is what the program writes.
  ---------------------------------------------------------------------------------- }

uses
	SysUtils, Classes, Math;

const
	kTab = #9;

var
	tolerance: double = 0.0;
	onlyPart: string = '';
	summaryOnly: boolean = false;
	headersOnly: boolean = false;
	maxReport: longint = 20;
	folderA, folderB: string;
	nDiffering: longint = 0;

	procedure splitLine (const s: string; cells: TStringList);
	var
		i, start: longint;
	begin
		cells.Clear;
		start := 1;
		for i := 1 to length (s) do
			if (s[i] = kTab) then begin
				cells.Add (copy (s, start, i - start));
				start := i + 1;
			end;
		cells.Add (copy (s, start, length (s) - start + 1));
	end;

	function sameNumber (const a, b: string): boolean;
	var
		x, y, scale: double;
	begin
		sameNumber := false;
		if (tolerance <= 0.0) then exit;
		if not TryStrToFloat (a, x) then exit;
		if not TryStrToFloat (b, y) then exit;
		if (x = y) then begin
			sameNumber := true;
			exit;
		end;
		scale := max (max (abs (x), abs (y)), 1.0);
		sameNumber := abs (x - y) <= tolerance * scale;
	end;

	{Lists the plain files of a folder, sorted}
	procedure filesOf (const folder: string; names: TStringList);
	var
		info: TSearchRec;
	begin
		names.Clear;
		if (FindFirst (IncludeTrailingPathDelimiter (folder) + '*', faAnyFile, info) = 0) then begin
			repeat
				if ((info.Attr and faDirectory) = 0) and (info.Name <> '') and (info.Name[1] <> '.') then
					names.Add (info.Name);
			until FindNext (info) <> 0;
			FindClose (info);
		end;
		names.Sort;
	end;

	{Compares two files and writes the first differences. Returns true when they differ.}
	function compareFile (const pathA, pathB, name: string): boolean;
	var
		fa, fb: TextFile;
		lineA, lineB: string;
		cellsA, cellsB: TStringList;
		row, col, reported: longint;
		differ, endA, endB: boolean;

		procedure report (const s: string);
		begin
			if (reported = 0) then
				writeln (format ('%-40s differs', [name]));
			Inc (reported);
			if (reported <= maxReport) and (not summaryOnly) then
				writeln ('    ', s)
			else if (reported = maxReport + 1) and (not summaryOnly) then
				writeln ('    ... further differences not listed');
		end;

	begin
		differ := false;
		reported := 0;
		row := 0;
		cellsA := TStringList.Create;
		cellsB := TStringList.Create;
		assignFile (fa, pathA); assignFile (fb, pathB);
		{$I-} reset (fa); reset (fb); {$I+}
		if (IOResult <> 0) then begin
			writeln (format ('%-40s could not be read', [name]));
			cellsA.Free; cellsB.Free;
			compareFile := true;
			exit;
		end;
		while true do begin
			endA := eof (fa);
			endB := eof (fb);
			if endA and endB then break;
			Inc (row);
			lineA := ''; lineB := '';
			if not endA then readln (fa, lineA);
			if not endB then readln (fb, lineB);
			if endA or endB then begin
				differ := true;
				report (format ('row %d: one file ends before the other', [row]));
				break;
			end;
			if (lineA = lineB) then continue;
			splitLine (lineA, cellsA);
			splitLine (lineB, cellsB);
			if (cellsA.Count <> cellsB.Count) then begin
				differ := true;
				report (format ('row %d: %d columns against %d', [row, cellsA.Count, cellsB.Count]));
				continue;
			end;
			for col := 0 to cellsA.Count - 1 do
				if (cellsA[col] <> cellsB[col]) and not sameNumber (cellsA[col], cellsB[col]) then begin
					differ := true;
					report (format ('row %d column %d: %s against %s', [row, col + 1, cellsA[col], cellsB[col]]));
				end;
		end;
		closeFile (fa); closeFile (fb);
		cellsA.Free; cellsB.Free;
		if differ and (reported > maxReport) and (not summaryOnly) then
			writeln (format ('    %d differences in all', [reported]));
		if (not differ) and summaryOnly then
			writeln (format ('%-40s equal', [name]));
		compareFile := differ;
	end;

	{Every data row must have as many columns as the header row of its file}
	function checkHeaders (const folder: string): longint;
	var
		names, cells: TStringList;
		i, row, width: longint;
		f: TextFile;
		line: string;
		bad: boolean;
	begin
		result := 0;
		names := TStringList.Create;
		cells := TStringList.Create;
		filesOf (folder, names);
		for i := 0 to names.Count - 1 do begin
			if (onlyPart <> '') and (pos (onlyPart, names[i]) = 0) then continue;
			assignFile (f, IncludeTrailingPathDelimiter (folder) + names[i]);
			{$I-} reset (f); {$I+}
			if (IOResult <> 0) then continue;
			width := -1;
			row := 0;
			bad := false;
			while not eof (f) and not bad do begin
				readln (f, line);
				Inc (row);
				if (trim (line) = '') then continue;
				splitLine (line, cells);
				if (width < 0) then
					width := cells.Count
				else if (cells.Count <> width) then begin
					writeln (format ('%-40s row %d: %d columns against %d in the header',
									[names[i], row, cells.Count, width]));
					Inc (result);
					bad := true;
				end;
			end;
			closeFile (f);
		end;
		cells.Free;
		names.Free;
	end;

	procedure usage;
	begin
		writeln ('compareruns A B [-tol x] [-only text] [-summary] [-max n]');
		writeln ('compareruns A -headers [-only text]');
		writeln;
		writeln ('Compares two results folders cell by cell, or checks the column counts of one.');
		writeln ('Exit code 0 when they agree, 1 when they do not.');
		Halt (2);
	end;

	procedure readArguments;
	var
		i: longint;
		s: string;
		positional: TStringList;
	begin
		positional := TStringList.Create;
		i := 1;
		while (i <= ParamCount) do begin
			s := ParamStr (i);
			if (s = '-headers') then headersOnly := true
			else if (s = '-summary') then summaryOnly := true
			else if (s = '-tol') then begin
				Inc (i);
				if (i > ParamCount) or not TryStrToFloat (ParamStr (i), tolerance) then usage;
			end
			else if (s = '-only') then begin
				Inc (i);
				if (i > ParamCount) then usage;
				onlyPart := ParamStr (i);
			end
			else if (s = '-max') then begin
				Inc (i);
				if (i > ParamCount) or not TryStrToInt (ParamStr (i), maxReport) then usage;
			end
			else if (copy (s, 1, 1) = '-') then usage
			else positional.Add (s);
			Inc (i);
		end;
		if (positional.Count < 1) then usage;
		folderA := positional[0];
		if (positional.Count > 1) then folderB := positional[1] else folderB := '';
		positional.Free;
		if (not headersOnly) and (folderB = '') then usage;
	end;

var
	namesA, namesB: TStringList;
	i: longint;
	name: string;

begin
	DefaultFormatSettings.DecimalSeparator := '.';
	readArguments;

	if not DirectoryExists (folderA) then begin
		writeln ('no such folder: ', folderA);
		Halt (2);
	end;

	if headersOnly then begin
		i := checkHeaders (folderA);
		writeln (i, ' files where a data row does not match its header');
		if (i > 0) then Halt (1) else Halt (0);
	end;

	if not DirectoryExists (folderB) then begin
		writeln ('no such folder: ', folderB);
		Halt (2);
	end;

	namesA := TStringList.Create;
	namesB := TStringList.Create;
	filesOf (folderA, namesA);
	filesOf (folderB, namesB);

	for i := 0 to namesA.Count - 1 do begin
		name := namesA[i];
		if (onlyPart <> '') and (pos (onlyPart, name) = 0) then continue;
		if (namesB.IndexOf (name) < 0) then begin
			writeln (format ('%-40s only in %s', [name, folderA]));
			Inc (nDiffering);
		end;
	end;
	for i := 0 to namesB.Count - 1 do begin
		name := namesB[i];
		if (onlyPart <> '') and (pos (onlyPart, name) = 0) then continue;
		if (namesA.IndexOf (name) < 0) then begin
			writeln (format ('%-40s only in %s', [name, folderB]));
			Inc (nDiffering);
		end;
	end;

	for i := 0 to namesA.Count - 1 do begin
		name := namesA[i];
		if (onlyPart <> '') and (pos (onlyPart, name) = 0) then continue;
		if (namesB.IndexOf (name) < 0) then continue;
		if compareFile (IncludeTrailingPathDelimiter (folderA) + name,
						IncludeTrailingPathDelimiter (folderB) + name, name) then
			Inc (nDiffering);
	end;

	namesA.Free;
	namesB.Free;

	writeln (nDiffering, ' files differ');
	if (nDiffering > 0) then Halt (1) else Halt (0);
end.
