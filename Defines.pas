{$UNDEF VerboseProfiler}
// {$define Debug} removed 29 Aug 2026: it was defined in every build, so the ~70
// {$IFDEF DEBUG} blocks were always compiled. They are now unconditional; the runtime
// switch g_GENPARAM.DEBUG gates the diagnostics that should be optional.
{$UNDEF DebugMemory}
//{$define NewStablePop_Motherhood}
{$UNDEF addOldUnionType}
{$UNDEF OLDCHILDRENLIST}
{$UNDEF UnionStatesType}
{$rangeChecks on}
{$define kinfertVersionDate:='29 October 2022'}
{$IFDEF DARWIN}
  {$DEFINE IS_MACOS}
{$ENDIF}
{$IFDEF CPUAARCH64}
	{$define ARM}
{$ELSE}
	{$AsmMode intel}
{$ENDIF}
{ breakOnFailure stops the debugger at the line that failed, so that the Locals window
  shows the variables of that routine rather than those of the checking code. Written as a
  macro because the trap has to be compiled in place; macros are on, the flags carry -Sm.
  Use it with the checking functions of Verification.pas, which return true on the first
  failure of each check:

      if checkFalse (chk_something, badCondition, ['woman ', idWoman]) then breakOnFailure;

  The test on gRunFromIDE is inside the macro, so an ordinary run never reaches an int 3. }
{$IFNDEF ARM}
	{$define breakOnFailure:=if gRunFromIDE then asm int 3 end}
{$ELSE}
	{$define breakOnFailure:=if gRunFromIDE then assert(false)}
{$ENDIF}
{$define OLD_INFOCHILDTYPE} // if not defined, uses a dynamic array with a constant size for storing the linked list of child info records
							// instead of creating child info records on the fly with 'new'
							// unfortunately using a dynamic array is too slow if we have to create a lot of them and can not reuse them
							// This could be useful if we can create the dynamic array one time and reuse it for a lot of women
{$undef CHANGE_IN_MAY2024}
