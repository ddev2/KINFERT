{$WARN 4048 off : Type size mismatch, possible loss of data / range check error}
{$I Defines.pas}
unit Profiler;

interface
uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Declarations, Utilities, SysUtils;

{$IFDEF VerboseProfiler}
	procedure timeProfile_initProc();
	procedure timeProfile_init(writeCounter: longint);
	procedure timeProfile_silent();
	procedure timeProfile_talkative();
	procedure timeProfile_start();
	procedure timeProfile_end();
	procedure timeProfile_start_proc(procName: string; setLevel: longint = 0);
	procedure timeProfile_end_proc(procName: string);
	procedure timeProfile_print_proc();
{$ENDIF}


implementation
{$IFDEF VerboseProfiler}
type
		profileInfo = record
			name: string;
			level: longint;
			time: TDateTime;
			startTime: TDateTime;
			num: Double;
		end;
var
		lTimeStart, lTimeTotal: TDateTime;
		lTimeWriteCounter, lTimeCount, lTimeTotalCount: longint;
		lTimeSilent: boolean = true;
		procName_array: array of profileInfo;
		numProc: longint;
		gLevelProc: longint = 0;
		gVP_CriticalSection: TRTLCriticalSection;
		gCriticalSectionAlreadyExists: longint = 0;
        gBigProcNumber: longint = 0123456789;

	procedure timeProfile_initProc();
	begin
		setLength(procName_array, 0);
		numProc := 0;
		gLevelProc := 0;
		setLength(procName_array, 100);
	end;
	
	procedure timeProfile_init(writeCounter: longint);
	begin
		lTimeStart := Now();
		lTimeTotal := Now() - Now();
		lTimeCount := 0;
		lTimeWriteCounter := writeCounter;
 	end;

	procedure timeProfile_silent();
	begin
		lTimeSilent := true;
	end;

	procedure timeProfile_talkative();
	begin
		lTimeSilent := false;
	end;

	procedure timeProfile_start();
	begin
		lTimeStart := Now();
		if gCriticalSectionAlreadyExists <> gBigProcNumber then
			InitCriticalSection(gVP_CriticalSection);
		gCriticalSectionAlreadyExists := gBigProcNumber;
	end;

	procedure timeProfile_end();
 	begin
		lTimeTotal := lTimeTotal + Now() - lTimeStart;
		lTimeStart := Now();
 		lTimeCount := lTimeCount + 1;
		lTimeTotalCount := lTimeTotalCount + 1;
 		if lTimeCount > lTimeWriteCounter then begin
		if not lTimeSilent then
			memoWriteLn(['Duration: ', DateTimeToMilliseconds(lTimeTotal), ' ms (', lTimeTotalCount, ')']);
		timeProfile_init (lTimeWriteCounter);
		end;
		DoneCriticalSection(gVP_CriticalSection);
		gCriticalSectionAlreadyExists := 0;
	end;
	
	function posInsideProfile (procName: string): longint;
	var
		pos: longint;
	begin
		posInsideProfile := -1;
		for pos := 0 to numProc-1 do begin
			if comparestr (procName_array[pos].name, procName) = 0 then
			begin
				posInsideProfile := pos;
				exit;
			end;
		end;
	end;
	
	function appendProc (procName: string): longint;
	begin
		if numProc = length(procName_array) then
		begin
			setLength(procName_array, length(procName_array) + 100);
		end;
		numProc := numProc + 1;
		with procName_array [numProc-1] do begin
			name := procName;
			time := 0;
			num := 0;
		end;
		appendProc := numProc - 1;
	end;
	
	procedure timeProfile_start_proc(procName: string; setLevel: longint = 0);
	var
		pos: longint;
	begin
		// we don't know whether a call to Now() is thread safe
		// so we don't use 'InterlockedExchangeAdd' or 'InterlockedIncrement' here
		EnterCriticalSection (gVP_CriticalSection);
		pos := posInsideProfile (procName);
		if setLevel = 0 then
        	if gLevelProc < gBigProcNumber then
				gLevelProc := gLevelProc + 1
        else
        	gLevelProc := setLevel;
		if pos < 0 then begin
			// not inside
			pos := appendProc (procName);
			procName_array [pos].level := gLevelProc;
		end;
		procName_array [pos].startTime := Now();
		LeaveCriticalSection (gVP_CriticalSection);
	end;
	
 	procedure timeProfile_end_proc(procName: string);
	var
		pos: longint;
		oldTime: TDateTime;
 	begin
		// we don't know whether a call to Now() is thread safe
		// so we don't use 'InterlockedExchangeAdd' or 'InterlockedIncrement' here
		EnterCriticalSection (gVP_CriticalSection);
 		pos := posInsideProfile (procName);
		gLevelProc := gLevelProc - 1;
 		with procName_array [pos] do begin
			time := time + Now() - startTime;
			num := num + 1;
		end;
		LeaveCriticalSection (gVP_CriticalSection);
 	end;

 	procedure timeProfile_print_proc();
	var
		pos: longint;
 	begin
		if not lTimeSilent then begin
			for pos := 0 to numProc-1 do
				with procName_array [pos] do begin
					if num > 4000 then begin
						memoWriteLn([name, ', level: ', level, ', total: ', IntToStr (DateTimeToMilliseconds(time)), ' ms, 1000 each: ',
						IntToStr (trunc (1000*DateTimeToMilliseconds(time)/num)), ' ms, count: ', num]);
					end else begin
						memoWriteLn([name, ', level: ', level, ', total: ', IntToStr (DateTimeToMilliseconds(time)), ' ms, count: ', num]);
					end;
				end;
		end;
		setLength(procName_array, 0);
 	end;


{$ENDIF}
end.
