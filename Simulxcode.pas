{$I Defines.pas}
program simulxcode (input, output);

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}

	Declarations, ReadCmdFileUnit, Init, SysUtils, Profiler, Memory, Utilities,
	Kinship, Mortality, FertilityRuntime, Fertility,
	EducationalLevel, DemographicRegime;
		
var
	filename_param: string;

begin
 {THINGS TO DO}
 {	- integrate the kinship of second unions}
 {	- great-grandparents and great-grandchildren}
 {	- when a spouse is given to the mother, it must be taken into account that this spouse may be in his or her second (or more) union.}
 {	  to do that, find a way to see if this man ever had time before to have a wife who died...}
 {	  or separated from him}
 
	if (Paramstr (1) <> '') then begin
		filename_param := Paramstr (1);
	end else begin
		filename_param := 'CONFIG.TXT';
	end;
	
{$IFDEF VerboseProfiler}
timeProfile_initProc();
timeProfile_init(0);
timeProfile_silent();
{$ENDIF}

{$IFDEF VerboseProfiler} timeProfile_start(); {$ENDIF}

	memoWriteLn(['*******************************************************']);
	memoWriteLn(['******************  S T A R T E D  ********************']);
	memoWriteLn(['*******************************************************']);
	
	doIt ( filename_param, initAndReadFile );

	memoWriteLn(['*******************************************************']);
	memoWriteLn(['****************** F I N I S H E D ********************']);
	memoWriteLn(['*******************************************************']);
{$IFDEF VerboseProfiler}
timeProfile_talkative();
timeProfile_end();
timeProfile_print_proc ();
{$ENDIF}

	memoryLeak();
	writeAndWait('');
end.
