# KinFert: what has been fixed

**13 September 2026.** Everything corrected since 24 August, when the pre-release audit started.
Nothing here needs your attention; it is the record of what changed and why, so that you can
answer "what did we do to this unit" without reading a diff.

The companion document is `docs/KinFert-TODO.md`, which is what still needs you.

**State.** HEAD is `1e5fc59`. Not committed yet: the fecundability heterogeneity check, the
fixed-parameter conflict fix, `Verification.pas` and the 81 sites converted to it, the family A
checks and the four charts that draw their results beside their inputs, the thread lifetime fix
in `multi_initMotherhood`, the correction of the exact age at onset of sterility, and these two
documents. The regions Claude changed carry review markers: see "Review markers" in
`docs/KinFert-TODO.md`. The 23 units that do not reach the LCL compile under FPC 3.2.2 with the
Lazarus 3.0 LCL, using the flags from `kinfert.lpi`; `LazGraph.pas` and `LazMain.pas` cannot be
compiled that way, because TAChart needs `IDEOptionsIntf`, which the packaged Lazarus does not
ship. **It has still not been built in Lazarus**, which is the first item in the TODO.

This document and `docs/KinFert-TODO.md` are the only two working documents. Everything that was
in `docs/archive` has been folded into one or the other, and the manual is a separate deliverable
at `docs/KinFert-Manual.md`.

---

## Results were wrong, and are now right

These changed simulated numbers. Anything you ran before 26 August carries them.

| what was wrong | where | effect |
|---|---|---|
| **Parameter sweeps did not sweep.** Each step read its value from an index assigned nine lines later, and each step's base came from the parameter the previous step had overwritten | `SpecialRuns.pas` | `NSTEP_SEPARATION` and `NSTEP_CONTRACEPTION_AFTER_UNION` collapsed to zero after step 1, so every step after the first simulated the same thing. Stepped means of age at union never reached their High value. Amenorrhea accumulated instead of stepping. **Single-parameterisation runs, every `NSTEP_*` at 1, were never affected** |
| **`endUnion` was never set true.** Declared, initialised false twice, tested in three loops, assigned nowhere | `FertilityRuntime.pas` | The loops meant to stop at dissolution never stopped, and the age at end of union recorded the **last** separation drawn rather than the first. One loop ran 40 years of monthly draws |
| **`monthIncrement` kept a stale value** on the stopping path, about twenty months | `FertilityRuntime.pas` | After a birth, conception fields were written into the previous child's record and the clock advanced twenty months at a time |
| **The ascendant share loop dropped the last heir**, running to `nHeirs-1` over a zero-based array | `inheritance.pas` | Four surviving grandparents shared 0.75 of an estate instead of 1.0. The largest single source of the `checkSumShareHeirs` deviation |
| **The niece and nephew block tested the father twice and the mother never** | `inheritance.pas` | A person whose mother was alive had their estate distributed to grandparents and aunts |
| **The spacing contraception wait was applied twice, and was added to the amenorrhea instead of overlapping it (N6).** `waiting_time_contraception` advanced `currMonth` month by month and also returned the count, which the caller added into the increment by which it advanced `currMonth` again | `FertilityRuntime.pas` | Every interval after a live birth in which spacing contraception was drawn lost twice the months of that spacing, and the spacing was placed at the month of conception rather than after the birth. The function now returns a count and touches no clock, and it takes the month at which the waiting begins so that its separation tests fall on the right dates. The interval after a live birth is now the later of the two spells that run from the same conception, the gestation followed by the amenorrhea, and the spacing that starts one month after the birth, rather than their sum. Two further effects: `monthFecundation` is again the month of conception, where before it was recorded after the clock had moved and could fall later than the end of the pregnancy; and the two calls are now separate statements, so the result no longer depends on the order in which the compiler evaluates the operands of `+`, which decided both the parity used for the spacing distribution and whether `LivingBirth` saw the advanced clock. `paramSeparation` now takes the month of the separation instead of reading `currMonth`. **Intervals after a live birth get shorter and fertility rises wherever spacing contraception is used** |
| **The women were created by threads that were freed before they had finished (crash on macOS).** The pool loop counted a finished thread again on every pass, so its count of running threads fell below zero and the loop could end while work was still running; it called `Start` a second time on a thread that was already running; it waited on `AFinished`, a flag `Execute` sets on its own last line, and freed the object there, while the system thread was still inside it; and neither thread destructor called `inherited Destroy`, which is what waits for the thread and releases it | `Kinship.pas`, `multi_initMotherhood` | The program stopped at the end of `initMotherhood` with `EXC_BAD_ACCESS` at address 0 on macOS, with multithreading on, and survived on Windows, where the same race is usually harmless. Every thread is now started, then waited for with `WaitFor` before its object is freed, and both destructors call `inherited Destroy` first. The number of threads was already capped where `numThreadsUsed` is computed, so the pool logic served no purpose |
| **Infant death shortened the birth interval by a whole gestation (N2).** `LivingBirth` returns a period counted from conception, `maxMonthDeathChild` counts the child's age at death from birth, and the two were compared directly | `FertilityRuntime.pas` | A child dying at one month returned the mother to susceptibility before that child was born. The gestation is now added to the death term. The amenorrhea loop also uses `kLivingBirth_durationPregnancyInMonths` in place of the literal 10, so the loop, the death term and `monthEndPregnancy` share one gestation: with `kNbLunarMonths` at 12 that is 9, and the non-susceptible period after a live birth is one lunar month shorter than before |
| **The first year of life had no mortality (N13).** `calc_ageDeath` drew a uniform fraction of a year at every age, including age 0, and the two Coale and Demeny branches of the infant correction were the wrong way round | `Mortality.pas` | An infant death could not fall in the neonatal period. The correction is now inside `calc_ageDeath`, which takes the sex as a fourth argument: a0 is 0.35 for women and 0.33 for men at q0 at or above 0.1, the linear form below it, and the moment within the year is drawn from the power law `F(t) = t^k` with `k = a / (1 - a)`, whose mean is exactly a. Agreement measured to four decimals |
| **A pregnancy could not be lost in the first month of gestation (N52).** Barrett's geometric series was written into the table from index 1, while his months run 2 to 8, losses in the first month being counted as reduced fecundability | `Fertility.pas`, `FertilityRuntime.pas` | The distribution of the month of loss was shifted down by one month: its mean went from 2.155 to 3.114 lunar months. The search in `FertilityRuntime` now starts at month 2 |
| **A life expectancy read from a cohort file was not clamped (N14)** | `Mortality.pas` | At e0 = 15 the interpolated `lx` was not monotone. The value is now clamped to the tabulated range and reported through `chk_mor_e0OutOfRange` |
| **A woman whose first union implied a groom outside the cohort range lost all her later unions (N35).** `addGroomsInfo` used `exit` where it needed `continue` | `Kinship.pas` | The first union is the one most often outside the range, so what was lost was mostly second and third unions, which biased the two-ways table of unions and the search for a bride by the groom's cohort. The unions are now counted and `initMotherhood` names the constant to widen and by how much |
| **The six union setters invented a union when the index named none (N28)** | `Nuptiality.pas` | `getUnionInfoByIndex` returns nil both for the next union, which is how every union is created, and for an index that means nothing, and the setters read both as an instruction to append. `checkEndUnions` takes its index from `getIndUnion`, which answers `kNotDefined` exactly when the reciprocal link between two partners is missing, so a broken link became an extra union and the count of unions of that person was wrong from then on. The cases are now separated by `unionRecordForSetter`, and both the bad index and the broken link are reported |
| **`ageWomenEndUnion` returned a negative age labelled widow (N31)** | `Nuptiality.pas` | The sentinel `kNotDefined` was used as an age. Daniel added the guard; the function now compares the three candidate ends uniformly, her death, his death on her age scale and the separation, and takes the earliest of those that are defined. Before, a partner with no date of death made every separation invisible, so a separated woman was counted as `everInUnion` and her union ran to her death |
| **The parity progression adjustment told the model that progression is near-certain at parities nobody reached (N7)** | `FertilityRuntime.pas` | A parity with no women gave b = 0, which the code replaced by 0.00001, so the factor became c times one hundred thousand and the adjusted ratio was clamped to 0.99999; the second loop then carried that factor to parities 16 to 50, where every ratio went to 1. Such a parity is now skipped, the factor extended to the higher parities comes only from a parity actually reached, and the passes keep the best iterate against the cohort total fertility asked for rather than the last one |
| **The Erlang waiting time was not the distribution it claimed to be** | `Fertility.pas` | Three faults. The shape ignored the rate, so the two repartnering calls, which pass lambda = 0.3, delivered a mean 3.33 times the value asked for: 5 years came out as 16.7. The first term called `power (0, k - 1)`. And the array summed a density over whole months, which is not a sum of probabilities: for a small shape it passed 1 before the end of the array, saturating the curve and killing the tail, so a mean of three months came out as three and a half. The array is now the distribution function itself, `gammaP (k, lambda * (i + 0.5))`, which needs no normalisation. `gammaP` was checked against three closed forms to twelve decimals. With lambda = 1 the two forms agree to 0.001 in the cumulative, so contraception and spacing barely move; repartnering moves by the factor of 3.33 |
| **The intrinsic growth rate omitted the proportion female at birth (N9)** | `StablePop.pas` | At replacement the solver returned about +0.026 rather than 0. `intrinsicRate` now multiplies the fertility schedule by `propWomenAtBirth` before solving |
| **`std_Campbell_Wood_1988` took the square root of a negative number (N30)** | `Nuptiality.pas` | For any mean below 15.32 years, which is inside the range the dialog allows. The variance is clamped at zero now rather than the mean, which keeps the real value for every mean above that point |
| **An integer expression handed to `memoWriteLn` or `bWriteLn` was dropped from the line** | `StringOfLib.pas` | `cStringOf` had no `vtInt64` case, and FPC widens an arithmetic expression such as `a - b` to `vtInt64`, so it fell to the `else` and vanished without a trace. Counts came out as blank spaces in the memo and in results files |
| **`eduLevel` returned an undefined value** for any status other than B, M or A | `EducationalLevel.pas` | Both callers use it as an index into a table of objects, so a garbage index gave a garbage class reference |
| **`ind_max` was read after a `for` loop** that can finish without `break`, and the life table is passed by value | `Mortality.pas` | The out-of-range read landed in adjacent stack memory: silent corruption, not a crash |
| **`truncateAtAge` read a loop counter after normal completion**, and could index `Unions[-1]` | `Parenthood.pas` | Wrote four fields past the end of the array, or before its start |
| **`getPartner` returned an uninitialised pointer** on its guard path | `Nuptiality.pas` | The caller dereferenced whatever was in the return register |
| **An explicit `NWOMEN` column in the cohort file was always discarded** and replaced by `NEGO` | `DemographicRegime.pas` | Per-cohort sample sizes were silently ignored |
| **Two thread counters incremented non-atomically** from workers | `Kinship.pas` | Lost counts under multithreading |
| **The random seed race**: workers called the RTL `random()` from their own threads | `Kinship.pas`, `RandomNumbers.pas` | Two threads could receive the same seed and generate identical genealogies |
| **The risk of separation was applied twice to the months of spacing contraception (N6b).** `waiting_time_contraception` tested separation on the months of the spell it drew, and the advance loop of `calcNbChildren` then walked those same months and tested it again | `FertilityRuntime.pas` | This was created by the N6 fix. Before it, the routine moved `currMonth` itself, so the months it tested were consumed and the caller went on from where it stopped: no month was tested twice, although the interval was too long by the length of the spacing and the hazard was applied over all of it. The routine now takes `testSeparationHere`, false for the call after a live birth, where the advance loop covers the same months, and true for the two calls made before the fertility loop, which advance the clock themselves and are walked by nothing else. **Unions last longer wherever spacing contraception is used, so fertility rises again a little** |
| **Women in the most fecund tail were made sterile at age 10 (N8).** The `else` of the interpolation conflated "already sterile at `kMinAgeFert`" with "still fecund at `kMaxAgeFert`" and assigned the minimum age to both | `Fertility.pas`, `initFecundLife` | About 2.8 per cent of women, those the search loop carried to the top of the table, were given zero exposure and zero children by a route unrelated to `gDefinitive_sterility`. Fixed by Daniel on 6 September: the boundary the loop reached is kept |
| **The exact age at onset of permanent sterility was interpolated on the wrong interval.** The search loop stops at the first age `a` with `dummy <= gDefinitive_sterility [a]`, so the onset lies between `a-1` and `a`, but the fraction was read on the interval above `a` and added to it. Since `dummy <= G [a]` wherever the loop stops, the term added is never positive, and its size uses the width of the wrong year | `Fertility.pas`, `initFecundLife` | Every woman was moved down by a year or more, and could be moved down by two where the year above is narrower than the year below, which is the case above the mode of the distribution. The simulated proportion sterile stood about 0.17 above the table at age 44 and about 0.03 through the thirties, so the fecund period was too short at every age and fertility too low. The fraction is now read on the year the cumulative risk crosses, and the ages drawn follow the table within the sampling band. Found by the family A check on the age at sterility, which is the first result-affecting bug the verification table found on its own |

## Fecundability: the Léridon model, corrected

Settled on 31 August against the source, Léridon (2004), *Human Reproduction* 19(7):1548-1553,
p. 1550 and Figure 1, which specify `Fmax = N(0.23; 0.12)`, a Gaussian with the standard
deviation **in fecundability units**, applied to the plateau.

Three separate bugs, all in `Fertility.pas`, which had to be fixed together because two of them
partly cancelled:

1. **The grid step.** `inc` worked out to `(1/K) x 46/47` instead of `1/K`, from a spurious `1 +`
   in its denominator. This inflated every multiplier by 2.17 per cent.
2. **The density was written in the wrong variable.** Dividing `val` by the mean made `stdDev`
   the standard deviation of the multiplier, not of fecundability, so passing Léridon's 0.12
   produced a coefficient of variation of 12 per cent instead of 52. At that width the
   heterogeneity did no demographic work at all: 4.4 per cent of women failing to conceive in
   twelve cycles, against 4.3 per cent with no heterogeneity whatever.
3. **The sampler was off by one.** `i := 0; while dummy > gDistrib[i+1]` returns the largest
   index *below* the draw, one less than the inverse-CDF index, for every draw. A systematic
   1.45 per cent shortfall, plus a multiplier of exactly zero for 0.19 per cent of women, who
   were then sterile from the start by a route unrelated to `gDefinitive_sterility`.

The realised distribution is now mean 0.2381 and standard deviation 0.1118. It is not exactly
0.23 and 0.12 because the grid truncates at zero, and the comment at the call site records what
to change if Léridon's Table I shows the model too fecund.

**Confirmed faithful to the same paper** while checking: `periodOfLowFecundability := 12.5`, the
adjustment when the age at sterility falls below 33, and the linear taper to zero at the
sterility age.

## Crashes, hangs and dead ends

| | |
|---|---|
| A fallback thread-cleanup loop that **could never exit** and read fields of objects the RTL may already have freed | Deleted. `TSimulEgoTreeCleanUp` already does the work on the normal path, and a fallback that hangs the program is worse than none |
| **46 debugger traps that never fired.** The idiom falls back to `assert(true, ...)` on ARM, and `Assert` raises only when its condition is false | On your Apple Silicon Mac every one of them was a silent no-op, including several in exception handlers that swallow the exception and fall through. Now `assert(false, ...)` |
| **Division by zero** in `writeInfoParents` for a cohort in which no woman was simulated | Guarded |
| **One blank line rejected a whole cohort file**, although the first pass over the same file tolerates blanks | Fixed |
| The inheritance warning fired **once per missing kin type**, up to 21 times per cohort per replicate | One message now lists them |

## Output and configuration

| | |
|---|---|
| `FILENAME` was omitted from the configuration file under the default `WRITE_ONLY_CHANGES` | Re-running a configuration gave every output the fallback name `KINFERT_*`, so two sets of outputs appeared under two names from what you believed was one study. Now always written |
| A hand-written `kinship=on` matched no branch and the whole file was abandoned, although the file the program writes promises that case does not matter | Fixed with a throwaway `aCommand_raw` |
| The DemoCare reader typed every non-ego row `kt_nonBio` and ignored the `relative` column | Kin types now survive the round trip |
| Marriage rows written in both directions undid the type just restored | The reverse row now re-types only a still-`kt_nonBio` target |
| Multi-cohort runs kept only the first cohort, and family and individual ids restarted per cohort | The file stays open across cohorts and the numbering continues |
| The BATCH option | Removed throughout: the nested procedures, the checkbox, the writer and reader, the defaults |

## Debug switches, consolidated

There were five overlapping switches and no way to tell which to use. There are now three.

- **`gRunFromIDE`** means a debugger is attached. It gates the 46 traps, the breakpoint anchors
  and the state snapshots. Unchanged at your request. Note it is really set by the `--GUI`
  command-line switch, not by Lazarus as such.
- **`g_GENPARAM.DEBUG`** means the user wants diagnostics. **It was previously impossible to set
  from the GUI**: every run wiped it, by two independent mechanisms. Now it survives.
- **`g_GENPARAM.TALKATIVE`** means timings and progress. Untouched.

Removed: `CHECK_DATASTRUCT`, which was saved to the configuration file, read back, and then
overwritten by `DEBUG` before every run, so its 13 gate sites now test `DEBUG` directly; and the
compile-time `{$define Debug}`, which was defined in every build, so its 70 `{$IFDEF DEBUG}`
blocks were never optional and are now unconditional. Neither removal changes behaviour.

**Fixed-parameter conflicts.** Several switches write the same table, and the applying loop ran
once through the enum, so whichever sat later silently won with no message. `LERIDON_STERILITY`
against `KINFERT_STERILITY`, and `HIGH_LOW_FECUNDABILITY` against
`NORMAL_HETEROGENEITY_FECUNDABILITY`, are now declared as exclusion groups and reported. Two
others, `NO_INITIAL_STERILITY` and `FIXED_STERILITY`, adjust the base table rather than replacing
it and were being overwritten by it; they now run in a second pass. **This is the one entry not
yet committed.**

## Fixed parameters could only be switched on, never off

`initFixedParameters` applies the switches on every run, from `initParams`, but
`initFertilityModel`, which builds the base tables they overwrite, ran only from
`initGeneral`, that is only at program start. So turning a switch **on** worked, and turning
it **off** left whatever the previous run had written, until the program was restarted.
It affected every switch that overwrites a table: `NORMAL_HETEROGENEITY_FECUNDABILITY` and
`HIGH_LOW_FECUNDABILITY` over `gFecundability`, `LERIDON_STERILITY` and `KINFERT_STERILITY`
over `gDefinitive_sterility`, and `FIXED_INTRAUTERINE` over the two mortality risks.
`initFixedParameters` now rebuilds the base tables first. `initFertilityModel` is a pure table
builder with no allocation and no I/O, so the call is safe and cheap.

Also corrected while there: the Hutterite beta was being called as `(3.14, 9.19)` rather than
`(3.4, 9.19)`, a slip introduced when the routine was parameterised. That gave mean 0.2547 and
a CV of 46.9 per cent instead of Majumdar and Sheps' 0.2701 and 44.6.

## Readability in the fertility loop, with no change to results

`month` was declared three times in nested scopes inside `calcNbChildren`, in the routine itself, in
`waiting_time_contraception` and in `LivingBirth`, so one name meant three quantities within forty
lines. They are now `monthsElapsed`, `monthsOfContraception` and `monthsNonSusceptible`, each with a
comment giving its origin, and a comment on `monthStart`, `monthEnd` and `currMonth` records that
those count lunar months since the woman's birth. The generated assembler for the unit is byte for
byte identical before and after, which is how the commit was checked.

The `wt_currMonth` parameter of `waiting_time_contraception` and `pregnancy` is gone. It was a `var`
alias for `currMonth`, which those routines already reach in the enclosing scope and already use
under its own name, so the same variable travelled under two names and the write to the clock inside
`waiting_time_contraception` was easy to miss. All five call sites passed `currMonth` itself, so the
removal changes nothing that runs. It is a separate commit from the renaming because the generated
code does change, the argument no longer being passed.

Neither commit touches N6, which is at the call site rather than in the signatures.

## New tools

`dumpArray` in `Utilities.pas`, five overloads for double, longint, boolean, char and string.
Writes any array to `<results>/<name>.txt` as an index row and a value row, which opens directly
in a spreadsheet. Pass the low bound for a static array over a subrange:

```pascal
dumpArray ('gFecundability', gFecundability, kMinAgeFert);
```

**`Verification.pas`**, new. One place where the checks the program makes are registered,
counted and reported, so a run ends with a verdict rather than with messages nobody sees.
`checkFalse` and `checkTrue` for invariants, `checkValue` for a quantity against a target,
`checkDistribution` for a histogram against the probabilities it was drawn from. The table
goes to the memo and to `<results>/verification.txt`, in a fixed order so two runs can be
compared with a diff, and checks that were never reached are listed by name.

A check that did not run is listed under one of two headings, according to its kind, because
the silence means opposite things. A failure point, that is a site converted with
`reportFailure`, is reached only when the code has already found something wrong, so its
silence is the good outcome: no failure of that kind was recorded. Any other check has to be
executed to test anything, so its silence means the code it watches was not reached and
nothing was tested, neither a pass nor a failure. `kCheckKindOf` declares the kind of each
check, and the 31 failure points of `Kinship.pas` are declared as such. Invariants

**Converted so far.** `FertilityRuntime.pas` 13 sites, `Nuptiality.pas` 2, `Kinship.pas` 66,
which is every live one in that unit: 77 checks in the table. What is left as it was, and why:
messages addressed to the user rather than to the code, marked WARNING or reporting a file that
cannot be read; exception handlers, which report a fault that already happened; and sites inside
`{$IFDEF addOldUnionType}` or `{$IFDEF OLDCHILDRENLIST}`, which this build does not compile.
`Declarations.pas` cannot be converted at all, since `Verification` uses it.

**Every debugger trap is now the macro.** The 43 places that spelled the trap out,

```pascal
			if gRunFromIDE then
{$IFNDEF ARM}
				asm int 3 end;
{$ELSE}
				assert(false);
{$ENDIF}
```

are one line, `breakOnFailure;`, in `Fertility.pas`, `FertilityRuntime.pas`, `Kinship.pas`,
`Nuptiality.pas` and `inheritance.pas`. The macro expands to exactly what those six lines said,
the `int 3` on Intel and `assert (false)` on Apple Silicon, with the test on `gRunFromIDE` inside
it, so nothing changes in what a run does. Three of them were malformed and are now regular: one
in `Kinship.pas` had `if gRunFromIDE then` twice over, one had no semicolon after the `end`, and
one in `inheritance.pas` had no `{$ELSE}` at all, so on Apple Silicon it compiled to an empty
statement and could never fire. What is lost is small and only on Apple Silicon: thirteen of the
sites, all inside exception handlers, passed `E.Message` to `assert`, and the macro takes no
argument. The message is still written to the log by the line above each of them. Both branches
of the macro were compiled to check this, the Intel one and, with `-dARM`, the one your Mac uses.

**The trap stays at the failing line.** `Defines.pas` defines `breakOnFailure`, a macro that
expands to the `int 3` under `gRunFromIDE`, and the checking functions return true on the first
failure of each check, so the site reads

```pascal
	if checkFalse (chk_kin_noMother, pMother = nil, ['ego ', gIndEgo]) then breakOnFailure;
```

and the debugger stops there, with that routine's own variables in the Locals window, once per
check rather than at every occurrence. `reportFailure` is the same thing for a point already
inside a failing branch, where the condition has been tested by the code above it.

**The red indicator.** `LazMain.pas` now reports how many checks failed and points at the
verification table rather than at the debug file.

always run: the fast path is a read of a flag and the comparison itself, with no shared
counter, because some of these sit in the monthly loop. Thirteen sites in
`FertilityRuntime.pas` were converted, including six that ran only under the IDE, and the
fecundability draws are checked with `checkDistribution`. `resetVerification` and
`verificationReport` are called from `run_all`.

Two of the fifteen sites first converted were dropped, because the property each asserted
was enforced by the line just above it and no state of the model could make it fail: a
check that cannot fail is worse than no check, since the table reports it as passing. A
third, on the length of a pregnancy, was failing in the wrong direction and now also tests
that a pregnancy does not end before it begins, which is what N6 produced. A fourth
compared the fractional age rather than the index used to read the fecundability tables,
and would have reported a failure for every woman still in a union at 59, whose fractional
age is 59.92.

**`tools/compareruns.lpr`**, new. A Free Pascal console program, built with
`fpc -O2 compareruns.lpr`, that compares two results folders cell by cell with an optional
tolerance, reports the first differences per file, and with `-headers` checks that every
data row has as many columns as its header. Exit code 0 when the folders agree, so it can
drive a script. It uses the run-time library alone, so anyone who can build KinFert can
build it. `tools/README.md` says what each file in that folder is for.

**Check of the fecundability heterogeneity model**, in `Fertility.pas`. Every draw made by
`fecundabilityLevel` is counted, in every run and not only in a debug session, and at the end of the run the
simulated distribution of individual levels is compared with the theoretical one. The counter is
emptied whenever `gDistrib_fecundability` is rebuilt, so it always refers to the distribution in
force, and the increment is atomic because the draws come from the cohort worker threads. The
report is written to the memo: number of draws, mean and standard deviation of the theoretical
grid and of the simulated women, the mean multiplier applied to `gFecundability`, and the largest
distance between the two cumulative distributions with the Kolmogorov-Smirnov band for that
number of draws. It also fills `gDistrib_fecundability_simulated`, which the graph window plots
against the theoretical curve under "fecundability heterogeneity: simulated against theoretical",
and, under `gRunFromIDE` alone, writes `fecundability_simulated.txt` and
`fecundability_theoretical.txt` to the results folder.

What it can show: an error in the inverse-CDF sampler or in the random number generator. What it
cannot show: an error in the formula that builds `gDistrib_fecundability`, since that array is at
once the source of the draws and the standard of comparison. For that, read the mean and standard
deviation of the grid against the parameters requested. A normal is truncated at zero, so a
requested 0.23 and 0.12 give a grid mean of about 0.238 and a standard deviation of about 0.112,
and a mean multiplier of about 1.036 rather than 1. A beta needs no truncation and should
reproduce its two moments to the precision of the grid.

## The amenorrhea chart drew the wrong schedule

Not a fault in the model. The amenorrhea is drawn from `temporary_sterility`, which each
demographic regime derives from `gSchedule_temporary_sterility` by the relational logit model of
Lesthaeghe and Page, with its own `AMENO_ALPHA` and `AMENO_BETA`. The chart drew the standard,
`gSchedule_temporary_sterility` itself, against what the run produced, and at the default alpha of
-1.18 the two are far apart: the odds of still being amenorrhoeic are multiplied by `exp (2 alpha)`,
that is by 0.094, which moves the median duration from about 15 lunar months to about 5.

The chart now draws three curves: the schedule of the cohort selected, what was simulated, and the
standard in black behind them. The first two are the pair that must agree; the third shows what the
two parameters did to the standard. The chart also moved, from "Inputs: fixed" to "Inputs:
variable", which is where it belongs: the standard is the same in every run, but the schedule that
matters is the one each regime derives from it, and the variable pane has the cohort selector. It
replaced the single-curve "Amenorrhea temporary sterility" entry there, which drew that same
schedule alone. The check itself always read the right schedule, which is why it passed while the
picture did not.

The default `AMENO_ALPHA` of -1.18 is deliberate: `initStandardAmenorrhea` describes it as a weak
amenorrhea with a median between five and six months, which is what the simulated curve shows.

Three things were fixed with it. **An observed curve is no longer drawn before there is anything to
draw.** Each observed curve now has a flag, set when the run fills it, and the graph window draws
the curve and its legend entry only then. Before this, opening the graphs before a run drew a flat
line at zero and named it "Simulated". **Two more quantities are checked and drawn**, the
intrauterine mortality risk by age and the stillbirth risk by age: every conception is counted by
the mother's age at conception, together with the outcome drawn for it, so the two risk schedules
can be read against the proportions the run produced. The verdict is one `checkValue` for each,
on the pooled proportion against the risk expected from the ages at which the conceptions actually
occurred. **And a crash was fixed**: `Draw` creates a series only when it is asked for the one just
after the last, so asking for series 3 with one series drawn raised "List index (2) out of bounds"
inside TAChart and left the input list unusable. The series are now numbered as they are added.

**One vocabulary on the charts.** The input curve is `Theoretical` on every chart that has one,
the observed curve is `Simulated`, and the title carries the pair only when there is a pair to
carry: before a run it names the input alone, "Stillbirth risk by age", and after one it reads
"Stillbirth risk by age: theoretical and simulated". `chartTitleFor` builds it. Two explanations
that had grown into the titles moved to the axis they belong to, so the titles stay short.

**Several settings in one run.** A sweep, or a run of several cohorts, simulates more than one
setting. Four of the quantities family A checks are defined by the demographic regime and differ
between settings: the amenorrhea schedule, the month a pregnancy is lost, the waiting time of the
spacing, and the proportion female at birth. Their counters are emptied at the start of each
setting, by `resetFertilityCountsThisSetting`, called from the innermost body of `FERTILITY_loops`
and at the start of the kinship phase of each cohort, so that the curve and the check describe one
setting and not a mixture of inputs. The other counters are left to accumulate over the whole run,
their tables being the same in every setting. The legend of each observed curve says which of the
two it is, "Simulated, last of 5 settings" against "Simulated, all 5 settings", and says neither
when only one setting ran. The memo repeats it in words after the count of draws.

## Looked at and cleared

Raised during the review, investigated, and found not to be faults. Recorded so that they are not
investigated again.

- **Initialised local variables are reset on every call.** This was the one that mattered most.
  The code writes `n: longint = 0` inside procedures throughout, including `idFather`, `idMother`,
  `nbRelatives`, `nIndividuals` and `checkSumShareHeirs`, and the older Free Pascal documentation
  describes such locals as static, which would have made `idFather` carry the previous relative's
  value whenever a father was nil and fabricate parent links across the genealogy. Tested under
  FPC 3.2.2, in `objfpc` mode and in default mode, with optimisation off: they are re-initialised
  at every call. Every finding that rested on the static reading was withdrawn.
- **The output file is written only from the main thread.** `writeKin` has one caller and
  `writeKinship` three, all in the body of `simulateKinship`. No worker touches the file, and it
  is opened non-async, so writes are direct and the record order is determined by the partition.
  The `indThread` parameter threaded through both is unused.
- **Logging from worker threads is marshalled correctly.** `memoWriteLn`, `flushIO` and
  `writeAndWait` all go through `Application.QueueAsyncCall`, which is thread-safe in the LCL, and
  the debug file is guarded by a critical section. The queue is unbounded, so a very long run
  grows the heap, but no GUI object is touched off the main thread.
- **The random number generator keeps its state in instance fields.** Only `initRandomized` and
  `nextThreadSeed` touch the run-time library's `RandSeed`. The one place that still calls
  `initRandomized` from inside a worker is N42, in the TODO.
- **`Memory.pas` is inert.** `DebugMemory` is defined nowhere, so the standard memory manager is
  used and the unlocked `ptrList` is unreachable.
- **The configuration round trip does not depend on the locale.** `cStringOf` renders booleans as
  `TRUE` and `FALSE` and doubles through `gFormatSettings`, so neither the boolean round trip nor
  a decimal comma can corrupt a saved file.
- **The calibration thread object is deliberately not destroyed.** The commented-out `Destroy` in
  `Kinship.pas` looks like an oversight and is right: `CleanUp`, `Terminate` and `FreeOnTerminate`
  do the work, and uncommenting it would create a double free. The TODO asks only for a comment
  saying so.
- **`nThreadsInBatch := round (gNumThreadsUsed / nBatches)` could not divide by zero**, since the
  branch conditions forced `nBatches >= 1`. The point is moot: the BATCH path is gone.
- **"Same Random Sequence" with several threads.** A fixed sequence cannot be reproduced while
  several threads draw in an order that is not determined. The behaviour is unchanged; what
  changed is that the program now says so instead of ignoring the option silently.

## How the units are checked outside Lazarus

FPC 3.2.2 and the Lazarus 3.0 LCL, on Linux, in the session container, with the flags from
`kinfert.lpi`. `LazMain` and `LazUtiles` are replaced by small stubs, because they reach TAChart,
whose `IDEOptionsIntf` dependency the packaged Lazarus ships only for design time; `LazGraph` is
therefore not checked either. Every other unit compiles, and the warning list is compared against
a baseline taken before the edits. Two things this cannot check: the `.lfm` resource binding, and
anything that only shows at run time. After a bulk edit the `begin` and `end` counts of each unit
are also compared with a snapshot taken before it, which is what caught a converter that had
eaten a procedure header.

## Also fixed, briefly

`mySetValue` restored; the key written after the kin filter; the `partnershipStatus` comparison
and a missing `else`; the DemoCare reader's enum, sentinel, offset, sex column, nil dereference
and handle leak; DemoCare `nChildren` for every relative; the bootstrap append; the link file no
longer overwriting `fname`; the DemoCare key separator; grandparent chains keeping the male
ancestor; the great-grand-niece guard; `kt_total` in 11 of 12 loops; `setInfoParents` and its
guarded divisions; the ego-budget off-by-one; the `dead` and `secondUnions` statuses; relatives
dead before the reference age dropped from the DemoCare file; `MULTITHREADING_SIMKIN` saved and
read; the four dialogs freeing their `BooleanName` objects; `header_GEDCOM` no longer writing to
a DemoCare-only file; the egos-per-second division guarded.

`mothersInfoList.pas` was reported as deleted on 26 August. **It was not**: the file is still
present and still tracked. That is in the TODO.

---

## The record by round, and the identifiers the earlier trackers used

The audits and the intermediate trackers labelled findings `N1`, `1.4`, `D7`, `W2`, `B4` and so
on, and those labels appear in commit messages. They are kept here so that a label can still be
resolved, now that the trackers themselves are gone. The line numbers those documents carried
were stale and are not reproduced: procedure names are the stable reference.

**Round 1, 24 August.** `0.1` `mySetValue` restored; `1.2` the key written after the kin filter;
`1.4` the `partnershipStatus` comparison and a missing `else`; `1.5` the DemoCare reader's enum,
sentinel, offset, sex column, nil dereference and handle leak; `1.6` DemoCare `nChildren` for
every relative; `1.7` the bootstrap append; `1.8` the link file no longer overwriting `fname`;
`1.10` the DemoCare key separator; `1.11` grandparent chains keeping the male ancestor; `1.12`
the great-grand-niece guard; `1.13` `kt_total` in 11 of 12 loops; `1.14` `setInfoParents` and its
guarded divisions; `1.15` `InterlockedIncrement` on three counters; `1.16` the ego-budget
off-by-one; `1.9` in part, the "Same Random Sequence" option now reported rather than ignored.

**Round 2, 25 August.** `D1` the `dead` status; `D2` `secondUnions` and the last-union logic;
`D6` `runDrawsFromSeveralThreads`; `D7` relatives dead before the reference age dropped and link
rows never naming them, with `checkLinks` removed, which also closes `4.1`; `3.a`
`MULTITHREADING_SIMKIN` saved and read; `4.3` counting only what was written; `4.10` the four
dialogs freeing their `BooleanName` objects.

**Round 3, 25 August.** `W1` BATCH removed throughout, which also closes `2.2`, three of the four
`2.1` division sites and `5.5`; `W2` multi-cohort output kept in one file with continuous family
and individual numbering, which closes `4.4` and is verified by V9; `6.1a` the seed race, seeding
moved into the three thread constructors through `initWithSeed` and `nextThreadSeed`; `B4`
`header_GEDCOM` no longer writing to the DemoCare-only link file, which closes `4.5`; `3.2`
`aCommand_raw`; `2.1` the `msElapsed` guard; `D5b` the `relative` column read back; `D5a` the
reverse marriage row re-typing only a still-`kt_nonBio` target.

**Round 4, 26 August**, commits `3ab5e7f`, `13e7a70` and `e4d8999`. Batch 1: `N1` the parameter
sweeps; `N3` `endUnion`; `N5` the missing `else` on `monthIncrement`; `N15` `ind_max`; `N16`
`eduLevel`; `N21` the ascendant share loop; `N23` the mother tested instead of the father twice;
`N27` `getPartner`; `N33` and `N33b` in `truncateAtAge`; `4.9` one inheritance message instead of
21. Batch 2: `N40` the two BACKFOR counters; `2.6` the fallback cleanup loop deleted; `3.e`
`FILENAME` always written; `A1` blank lines in the cohort file; `A2` the empty-cohort divisions.
`e4d8999`: `N12` `readInConfigFile` set in all ten branches of `processValuesLine`. `N39`
`mothersInfoList.pas` was reported deleted in that commit message and was not: see the note above.

**Round 5, 31 August.** `N48` the 46 traps that could not fire; `N47` and `3.3` the removal of
`CHECK_DATASTRUCT`; the compile-time `Debug` symbol removed, 142 directive lines with their
bodies kept; `dumpArray` added to `Utilities.pas`. Daniel separately made `DEBUG` survive a run
and set `gStdDev_fecundability := stdDev`, which is part of `N4`.

**Round 6, 31 August to 6 September.** `N4`, `N4b` and `N4d` the three fecundability bugs;
`N50` and `N51` the fixed-parameter conflicts and the tables that were never rebuilt; `N2` the
gestation in the infant-death term; `N6` the double spacing wait; `N8` the sterility floor and
the interpolation of the exact age; the thread lifetime fix in `multi_initMotherhood`;
`Verification.pas` and the 81 sites converted to it; family A. `P1` the README and `P2` the MIT
licence were done earlier, in `22ed060`; `P9`, the conversion of `Fertility.pas` to LF, on
31 August.

**Round 7, 8 to 13 September.** `N13` the first year of life; `N52` Barrett's month of loss;
`N14` the life expectancy clamp; `N35` the lost unions; `N28` the six union setters; `N31`
`ageWomenEndUnion`; `N7` the parity progression adjustment; the Erlang waiting time; `N9` the
intrinsic rate; `N30` the square root; the `vtInt64` case in `cStringOf`; `str_float` reading
through the nil-safe accessors, and `gFormatSettings` given a decimal point in an initialization
section; `writeAndWait` and `writeAndWaitConst` routed into the verification table through
`gProblemReporter`, which covers all 85 sites at once; the alternative age schedules for
intrauterine mortality (Léridon and Magnus) and for stillbirth (Barrett and US 2023) with their
two checkboxes, and the fecundability heterogeneity default moved from normal to beta.

Also in round 7, and not bug fixes. `verification.txt` is rearranged by outcome rather than by
the order of `TCheckId`, and the messages from `writeAndWait` have their own section instead of a
row in the table of checks with a property they were supposed to hold. The search for a mother
and the search for a bride are instrumented: the share of searches answered from a cell other
than the one asked for is counted by cohort and by generation, reported at the end of the run,
and drawn on the Children-Grooms tab, which went from nineteen entries to four. The diagnostic
arrays of `Kinship.pas` are kept by generation, from the great grandchildren to the great
grandparents, through `kinGeneration` and `kinGenerationRow` in `Declarations.pas`. Five new
check identifiers: `unionIndexInSetter`, `noReciprocalUnion`, `unionHasNoEnd`, `waitingTimeMean`
and `e0OutOfRange`.
