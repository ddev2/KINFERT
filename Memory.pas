{$I Defines.pas}
unit Memory;
interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Utilities, SysUtils;

	type
		ptr = ^longint;

	procedure newPtr (p: ptr; name: string);
	procedure disposePtr (var p: ptr; name: string);
	procedure memoryLeak ();
	
implementation
{$IFDEF DebugMemory}
	type
		ptrName = record
			name: string;
			count: longint;
		end;
		
	var
		ptrList: array of ptrName;
	
	function ptrInList (name: string): longint;
	var ind, len: longint;
	begin
		len := high (ptrList);
		for ind := 0 to len do
			if (ptrList [ind].name = name) then begin
				ptrInList := ind;
				exit;
			end;
		ptrInList := -1;
	end;
{$ENDIF}
	
	procedure newPtr (p: ptr; name: string);
{$IFDEF DebugMemory}
	var pos: longint;
{$ENDIF}
	begin
		if p = nil then begin
			writeAndWaitConst(['===> ERROR: ', name, ' not allocated']);
			myHalt([name, ' not allocated']);
		end;
{$IFDEF DebugMemory}
		pos := ptrInList (name);
		if pos < 0 then begin
			setLength (ptrList, high(ptrList)+2);
			ptrList [high(ptrList)].name := name;
			ptrList [high(ptrList)].count := 1;
		end else begin
			Inc ( ptrList [pos].count );
		end;
{$ENDIF}
	end;

	procedure disposePtr (var p: ptr; name: string);
{$IFDEF DebugMemory}
	var
        pos: longint;
{$ENDIF}
    begin
		if (p = nil) then begin
			writeAndWaitConst(['===> ERROR: Pointer nil ', name]);
			myHalt(['Pointer nil ', name]);
		end;
		dispose (p);
		p := nil;
{$IFDEF DebugMemory}
		pos := ptrInList (name);
		if pos >= 0 then begin
			ptrList [pos].count := ptrList [pos].count - 1;
		end else begin
			setLength (ptrList, high(ptrList)+2);
			ptrList [high(ptrList)].name := name;
			ptrList [high(ptrList)].count := -1;
		end;
{$ENDIF}
	end;
	
	procedure memoryLeak();
{$IFDEF DebugMemory}
	var ind, len: longint;
{$ENDIF}
	begin
{$IFDEF DebugMemory}
		len := high (ptrList);
		for ind := 0 to len do
			with ptrList [ind] do
				if count > 0 then begin
					writeAndWaitConst(['===> ERROR: Not released ', name, ' count: ', count]);
				end else if count < 0 then begin
					writeAndWaitConst(['===> ERROR: Over released ', name, ' count: ', count]);
				end;
		setLength (ptrList, 0);
{$ENDIF}
	end;
end.
