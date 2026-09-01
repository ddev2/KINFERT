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
{$define OLD_INFOCHILDTYPE} // if not defined, uses a dynamic array with a constant size for storing the linked list of child info records
							// instead of creating child info records on the fly with 'new'
							// unfortunately using a dynamic array is too slow if we have to create a lot of them and can not reuse them
							// This could be useful if we can create the dynamic array one time and reuse it for a lot of women
{$undef CHANGE_IN_MAY2024}
