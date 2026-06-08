{$I Defines.pas}
unit RandomNumbers;
// based on Numerical Recipes in Pascal
// For KinFert, ran3 is used: Donald Knuth's portable random generator algorithm based on subtractive method

interface
uses
	{$IFDEF UNIX}
	cthreads,
 	{$ENDIF}
	Declarations, Profiler, SysUtils;

const
	kRange = 10000;
var
	gCheckValueRange: array of double;
	gDebugRN: boolean = false;
	
type
	TRandomNumberGenerator = class
	private
		plix1, plix2, plix3: longint;
		plr: array[1..97] of double;

		pliy: longint;
		plir: array[1..97] of longint;

		plinext, plinextp: longint;
		plma: array[1..55] of longint;

		pliset: longint;
		plgset: double;
		pFirstRan: double;

		function ran1 (var idum: longint): double;
		function ran2 (var idum: longint): double;
		function ran3 (var idum: longint): double;
		function gasdev (var idum: longint): double;
		procedure addTableAlea (ran: double);
		
	public
		tableAlea: array of double;

		Constructor Create (sameRandomSequence: boolean = true); overload;
		Destructor Destroy; override;
		procedure init (dummy: longint = -1);
		procedure initRandomized();
		function alea0 (deterministic: boolean = false): double;
		function alea (min, max: double; deterministic: boolean = false): double;
	end;

	var
		gRandomGenerator: TRandomNumberGenerator;
		gRandomGeneratorAlreadyExists: longint = 0;
		
	procedure initRandomNumbers (dummy: longint = -1);
	procedure stopRandomNumbers;
	procedure RandomizeInitRandomNumbers;
	procedure initCheckRN;
	procedure stopCheckRN (nameFile: string);
	procedure addTableAlea (tableAlea: arraydoubletype);
	
{	function alea0: double;
	function alea (min, max: double): double;
}
implementation
	uses utilities;

{	var
		glix1, glix2, glix3: longint;
		glr: array[1..97] of double;

		gliy: longint;
		glir: array[1..97] of longint;

		glinext, glinextp: longint;
		glma: array[1..55] of longint;

		gliset: longint;
		glgset: double;
		
		gRN_CriticalSection: TRTLCriticalSection;
		gCriticalSectionAlreadyExists: longint = 0;
}

{	type
		gl64array = array[1..64] of longint;
		gl65reals = array[1..65] of double;}

{var
		glnewkey: longint;
		glinp, glkey: gl64array;
		glpow: gl65reals;}

	Constructor TRandomNumberGenerator.Create (sameRandomSequence: boolean = true); overload;
	begin
		inherited Create();
		if gDebugRN then
			setLength(tableAlea, kRange);
		if sameRandomSequence then begin
			self.init();
		end else begin
			self.initRandomized ();
		end;
		pFirstRan := self.alea0;
	end;
	
	Destructor TRandomNumberGenerator.Destroy;
	begin
		if gDebugRN then
			setLength(tableAlea, 0);
		inherited Destroy();
	end;
	
	function TRandomNumberGenerator.alea0 (deterministic: boolean = false): double;
	var
		dummy: longint;
	begin
		dummy := 1;
		result := self.ran3(dummy);
		if deterministic then
			result := 0.5;
	end;
	
	function TRandomNumberGenerator.alea (min, max: double; deterministic: boolean = false): double;
	var
		dummy: longint;
	begin
		dummy := 1;
		result := min + (max - min) * self.ran3(dummy);
		if deterministic then
			result := min + (max - min) * 0.5;
	end;
	
	function TRandomNumberGenerator.ran1 (var idum: longint): double;
	const
		m1 = 259200;
		ia1 = 7141;
		ic1 = 54773;
		rm1 = 3.8580247e-6;   (* 1.0/m1 *)
		m2 = 134456;
		ia2 = 8121;
		ic2 = 28411;
		rm2 = 7.4373773e-6;   (* 1.0/m2 *)
		m3 = 243000;
		ia3 = 4561;
		ic3 = 51349;
	var
		j: longint;
	begin
		if (idum < 0) then
			begin
				plix1 := (ic1 - idum) mod m1;
				plix1 := (ia1 * plix1 + ic1) mod m1;
				plix2 := plix1 mod m2;
				plix1 := (ia1 * plix1 + ic1) mod m1;
				plix3 := plix1 mod m3;
				for j := 1 to 97 do
					begin
						plix1 := (ia1 * plix1 + ic1) mod m1;
						plix2 := (ia2 * plix2 + ic2) mod m2;
						plr[j] := (plix1 + plix2 * rm2) * rm1
					end;
				idum := 1
			end;
		plix1 := (ia1 * plix1 + ic1) mod m1;
		plix2 := (ia2 * plix2 + ic2) mod m2;
		plix3 := (ia3 * plix3 + ic3) mod m3;
		j := 1 + (97 * plix3) div m3;
		if ((j > 97) or (j < 1)) then
			begin
				//memoWriteLn(['pause in routine RAN1']);
				//readln;
			end;
		ran1 := plr[j];
		plr[j] := (plix1 + plix2 * rm2) * rm1
	end;
	
	function TRandomNumberGenerator.ran2 (var idum: longint): double;
	const
		m = 714025;
		ia = 1366;
		ic = 150889;
		rm = 1.400512e-6;	  (* 1.0/m *)
	var
		j: longint;
	begin
		if (idum < 0) then
			begin
				idum := (ic - idum) mod m;
				for j := 1 to 97 do
					begin
						idum := (ia * idum + ic) mod m;
						plir[j] := idum
					end;
				idum := (ia * idum + ic) mod m;
				pliy := idum
			end;
		j := 1 + (97 * pliy) div m;
		if ((j > 97) or (j < 1)) then
			begin
				//memoWriteLn(['pause in routine RAN2']);
				//readln;
			end;
		pliy := plir[j];
		ran2 := pliy * rm;
		idum := (ia * idum + ic) mod m;
		plir[j] := idum;
	end;
	
	function TRandomNumberGenerator.ran3 (var idum: longint): double;
		const
			mbig = 1000000000;
			mseed = 161803398;
			mz = 0;
			fac = 1.0e-9;
		var
			i, ii, k: longint;
			mk, mj: longint;
	begin
		if (idum < 0) then
			begin
				mj := mseed + idum;
				mj := mj mod mbig;
				plma[55] := mj;
				mk := 1;
				for i := 1 to 54 do
					begin
						ii := 21 * i mod 55;
						plma[ii] := mk;
						mk := mj - mk;
						if (mk < mz) then
							mk := mk + mbig;
						mj := plma[ii]
					end;
				for k := 1 to 4 do
					begin
						for i := 1 to 55 do
							begin
								plma[i] := plma[i] - plma[1 + ((i + 30) mod 55)];
								if (plma[i] < mz) then
									plma[i] := plma[i] + mbig
							end
					end;
				plinext := 0;
				plinextp := 31;
				idum := 1
			end;
		plinext := plinext + 1;
		if (plinext = 56) then
			plinext := 1;
		plinextp := plinextp + 1;
		if (plinextp = 56) then
			plinextp := 1;
		mj := plma[plinext] - plma[plinextp];
		if (mj < mz) then
			mj := mj + mbig;
		plma[plinext] := mj;
		ran3 := mj * fac;
		if gDebugRN then
			self.addTableAlea (ran3);
	end;
	
	function TRandomNumberGenerator.gasdev (var idum: longint): double;
		var
			fac, r, v1, v2: double;
	begin
		if (pliset = 0) then
			begin
				repeat
					v1 := 2.0 * ran3(idum) - 1.0;
					v2 := 2.0 * ran3(idum) - 1.0;
					r := sqr(v1) + sqr(v2);
				until (r < 1.0);
				fac := sqrt(-2.0 * ln(r) / r);
				plgset := v1 * fac;
				gasdev := v2 * fac;
				pliset := 1
			end
		else
			begin
				gasdev := plgset;
				pliset := 0
			end
	end;

	procedure TRandomNumberGenerator.addTableAlea (ran: double);
    var
        ind: longint;
	begin
        ind := trunc (ran * kRange);
        if (ind < 0) or (ind >= kRange) then
            ind := ind;
		tableAlea [ind] := tableAlea [ind] + 1;
        if tableAlea [ind] > 1000000 then
            ind := ind;
	end;

	procedure TRandomNumberGenerator.init (dummy: longint = -1);
	begin
		pliset := 0;
		dummy := round(-10000.0 * self.ran1(dummy));
		dummy := round(-10000.0 * self.ran2(dummy));
		dummy := round(-10000.0 * self.ran3(dummy));
	end;

	procedure TRandomNumberGenerator.initRandomized();
	begin
		self.init (-random(DateTimeToMilliseconds(Now())));
	end;

	procedure initRandomNumbers (dummy: longint = -1);
	begin
{		if gCriticalSectionAlreadyExists <> 1234567890 then
			InitCriticalSection(gRN_CriticalSection);
		gCriticalSectionAlreadyExists := 1234567890;
}
		if gRandomGeneratorAlreadyExists <> 1234567890 then
			gRandomGenerator := TRandomNumberGenerator.Create();
		gRandomGeneratorAlreadyExists := 1234567890;
				
{		gliset := 0;
		dummy := round(-10000.0 * ran1(dummy));
		dummy := round(-10000.0 * ran2(dummy));
		dummy := round(-10000.0 * ran3(dummy));
}
	end;

	procedure stopRandomNumbers;
	begin
{		DoneCriticalSection(gRN_CriticalSection);
		gCriticalSectionAlreadyExists := 0;
}
		gRandomGenerator.Destroy();
		gRandomGeneratorAlreadyExists := 0;
	end;
	
	procedure RandomizeInitRandomNumbers;
	begin
		randomize;
		initRandomNumbers (-random(100000));
	end;

	procedure initCheckRN;
	begin
		setLength (gCheckValueRange, kRange);
		gDebugRN := true;
	end;
	procedure stopCheckRN (nameFile: string);
    var
		f: TFileType; // used in the main thread only
		res: longint;
		ind: longint;
	begin
		f := TFileType.Create (gPathToResult + nameFile, res, nameFile);
		if res = 0 then begin
			for ind := 0 to kRange-1 do
				cWriteLn (f, intToStr(trunc(gCheckValueRange[ind])));
		end;
		f.Destroy;
		setLength (gCheckValueRange, 0);
		gDebugRN := false;
	end;
	
	procedure addTableAlea (tableAlea: arraydoubletype);
	var
		ind: longint;
	begin
		for ind := 0 to kRange-1 do
			gCheckValueRange[ind] := gCheckValueRange[ind] + tableAlea[ind];
	end;

{	function ran1 (var idum: longint): double;
(* Programs using RAN1 must declare the following variables}
{VAR}
{   glix1,glix2,glix3: longint;}
{   glr: ARRAY [1..97] OF double;}
{in the main program. *)
		const
			m1 = 259200;
			ia1 = 7141;
			ic1 = 54773;
			rm1 = 3.8580247e-6;   (* 1.0/m1 *)
			m2 = 134456;
			ia2 = 8121;
			ic2 = 28411;
			rm2 = 7.4373773e-6;   (* 1.0/m2 *)
			m3 = 243000;
			ia3 = 4561;
			ic3 = 51349;
		var
			j: longint;
	begin
		if (idum < 0) then
			begin
				glix1 := (ic1 - idum) mod m1;
				glix1 := (ia1 * glix1 + ic1) mod m1;
				glix2 := glix1 mod m2;
				glix1 := (ia1 * glix1 + ic1) mod m1;
				glix3 := glix1 mod m3;
				for j := 1 to 97 do
					begin
						glix1 := (ia1 * glix1 + ic1) mod m1;
						glix2 := (ia2 * glix2 + ic2) mod m2;
						glr[j] := (glix1 + glix2 * rm2) * rm1
					end;
				idum := 1
			end;
		glix1 := (ia1 * glix1 + ic1) mod m1;
		glix2 := (ia2 * glix2 + ic2) mod m2;
		glix3 := (ia3 * glix3 + ic3) mod m3;
		j := 1 + (97 * glix3) div m3;
		if ((j > 97) or (j < 1)) then
			begin
				memoWriteLn(['pause in routine RAN1']);
				readln;
			end;
		ran1 := glr[j];
		glr[j] := (glix1 + glix2 * rm2) * rm1
	end;

	function ran2 (var idum: longint): double;
(* Programs using RAN2 must declare the following variables}
{VAR}
{   gliy: longint;}
{   glir: ARRAY [1..97] OF longint;}
{in the main program. *)
		const
			m = 714025;
			ia = 1366;
			ic = 150889;
			rm = 1.400512e-6;	  (* 1.0/m *)
		var
			j: longint;
	begin
		if (idum < 0) then
			begin
				idum := (ic - idum) mod m;
				for j := 1 to 97 do
					begin
						idum := (ia * idum + ic) mod m;
						glir[j] := idum
					end;
				idum := (ia * idum + ic) mod m;
				gliy := idum
			end;
		j := 1 + (97 * gliy) div m;
		if ((j > 97) or (j < 1)) then
			begin
				memoWriteLn(['pause in routine RAN2']);
				readln;
			end;
		gliy := glir[j];
		ran2 := gliy * rm;
		idum := (ia * idum + ic) mod m;
		glir[j] := idum
	end;

	function ran3 (var idum: longint): double;
(* Programs using RAN3 must declare the following variables}
{VAR}
{  glinext,glinextp: longint;}
{   glma: ARRAY [1..55] OF longint;}
{in the main routine.*)
		const
			mbig = 1000000000;
			mseed = 161803398;
			mz = 0;
			fac = 1.0e-9;
		var
			i, ii, k: longint;
			mk, mj: longint;
	begin
		EnterCriticalSection (gRN_CriticalSection);
		if (idum < 0) then
			begin
				mj := mseed + idum;
				mj := mj mod mbig;
				glma[55] := mj;
				mk := 1;
				for i := 1 to 54 do
					begin
						ii := 21 * i mod 55;
						glma[ii] := mk;
						mk := mj - mk;
						if (mk < mz) then
							mk := mk + mbig;
						mj := glma[ii]
					end;
				for k := 1 to 4 do
					begin
						for i := 1 to 55 do
							begin
								glma[i] := glma[i] - glma[1 + ((i + 30) mod 55)];
								if (glma[i] < mz) then
									glma[i] := glma[i] + mbig
							end
					end;
				glinext := 0;
				glinextp := 31;
				idum := 1
			end;
		glinext := glinext + 1;
		if (glinext = 56) then
			glinext := 1;
		glinextp := glinextp + 1;
		if (glinextp = 56) then
			glinextp := 1;
		mj := glma[glinext] - glma[glinextp];
		if (mj < mz) then
			mj := mj + mbig;
		glma[glinext] := mj;
		ran3 := mj * fac;
		LeaveCriticalSection (gRN_CriticalSection);
	end;

	function gasdev (var idum: longint): double;
(* Programs using GASDEV must declare the variables}
{VAR}
{   gliset: longint;}
{   glgset: double;}
{in the main routine and must intialize gliset to}
{   gliset := 0;   *)
		var
			fac, r, v1, v2: double;
	begin
		if (gliset = 0) then
			begin
				repeat
					v1 := 2.0 * ran3(idum) - 1.0;
					v2 := 2.0 * ran3(idum) - 1.0;
					r := sqr(v1) + sqr(v2);
				until (r < 1.0);
				fac := sqrt(-2.0 * ln(r) / r);
				glgset := v1 * fac;
				gasdev := v2 * fac;
				gliset := 1
			end
		else
			begin
				gasdev := glgset;
				gliset := 0
			end
	end;

    	function alea0 (deterministic: boolean = false): double;
	var
		dummy: longint;
	begin
		dummy := 0;
		alea0 := ran3(dummy);
		if deterministic then
			alea := 0.5;
	end;

	function alea (min, max: double; deterministic: boolean = false): double;
	var
		dummy: longint;
	begin
		dummy := 0;
		alea := min + (max - min) * ran3(dummy);
		if deterministic then
			min + (max - min) * 0.5;
	end;

}
end.
