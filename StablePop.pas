unit StablePop;
interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	SysUtils, Math, Declarations;

	function intrinsicRate(pDemReg: pStructDemographicRegimeSettings; objUnionTable: TUnionTable): double;

implementation
const
	EPSILON = 1e-9;
	MAX_ITER = 1000;

var
	r: double;
	MaxAge: integer;
	lx: arrayOfDouble;

{ Calculate cumulative survival probability to age x }
procedure CumulativeSurvival (Survival: arrayOfDouble);
var
	i: Integer;
begin
	SetLength (lx, MaxAge + 1);
	lx[0] := 1.0;
	for i := 1 to MaxAge do
		lx[i] := lx[i-1] * Survival[i];
end;

{ Evaluate the Euler-Lotka equation: sum(e^(-r*x) * l(x) * m(x)) = 1 }
function EulerLotka(r_val: double; Fertility: arrayOfDouble): double;
var
	x: Integer;
	sum: double;
begin
	sum := 0.0;
	for x := 0 to MaxAge do
	begin
		if Fertility[x] > 0 then
		begin
			sum := sum + Exp(-r_val * x) * lx[x] * Fertility[x];
		end;
	end;
	EulerLotka := sum - 1.0;
end;

{ Derivative of Euler-Lotka equation for Newton-Raphson }
function EulerLotkaDerivative(r_val: double; Fertility: arrayOfDouble): double;
var
	x: Integer;
	sum: double;
begin
	sum := 0.0;
	for x := 0 to MaxAge do
	begin
		if Fertility[x] > 0 then
		begin
			sum := sum - x * Exp(-r_val * x) * lx[x] * Fertility[x];
		end;
	end;
	EulerLotkaDerivative := sum;
end;

{ Newton-Raphson method to solve for r }
function SolveForR (Fertility, Survival: arrayOfDouble; survivalIsYearlyProb: boolean = false): double;
// Fertility and Survival should have the same length
// Survival is of type lx. If survivalIsYearlyProb is true, then it is of type px
var
	r_old, r_new, f_val, df_val: double;
	iter: Integer;
begin
	r_old := 0.0;	{ Initial guess }
	iter := 0;
	MaxAge := length(Survival) - 1;
    lx := Copy (Survival);
 	if survivalIsYearlyProb then
       CumulativeSurvival (Survival);

	repeat
		f_val := EulerLotka(r_old, Fertility);
		df_val := EulerLotkaDerivative(r_old, Fertility);
		
		if Abs(df_val) < EPSILON then
		begin
			//WriteLn('Error: Derivative too small');
			SolveForR := r_old;
			Exit;
		end;
		
		r_new := r_old - f_val / df_val;
		
		if Abs(r_new - r_old) < EPSILON then
		begin
			SolveForR := r_new;
			Exit;
		end;
		
		r_old := r_new;
		Inc(iter);
		
	until iter >= MAX_ITER;
	
	//WriteLn('Warning: Maximum iterations reached');
	SolveForR := r_new;
    SetLength (lx, 0);
end;

function intrinsicRate(pDemReg: pStructDemographicRegimeSettings; objUnionTable: TUnionTable): double;
var
	Fertility, Survival: arrayOfDouble;
	ageWomen: FecundAges;
begin
	Survival := Copy (pDemReg^.mortalityInfo.survival_women);
	SetLength(Fertility, length (Survival));
	Move(objUnionTable.pGenFert^[0, any, endedAge50, kMinAgeFert], Fertility[kMinAgeFert], Length(objUnionTable.pGenFert^[0, any, endedAge50]) * SizeOf(Double));
	intrinsicRate := SolveForR (Fertility, Survival);
end;

end.
