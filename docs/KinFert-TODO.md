# KinFert: what still needs you

**13 September 2026.** Everything outstanding, in the order I would do it. The list of defects
in sections 3 and 3b was re-read against the source on 13 September; the rest carries the dates
of its own reading. The companion document
is `docs/KinFert-FIXED.md`, which is the record of what is already done and needs nothing. These
two are the only working documents: what was in `docs/archive` has been folded into one or the
other, and the manual is a separate deliverable at `docs/KinFert-Manual.md`.

**Line numbers.** Those in section 6 were read on 6 September. The rest were re-derived on
2 September, and the marked regions added since have moved many of them, by tens of lines in
`FertilityRuntime.pas` and `LazGraph.pas`. Run `tools/check-line-numbers.py` after any edit and it
prints the current numbers. **The routine name is the stable reference, the line number is not**:
every entry names the routine for that reason.

**Review markers.** Each region Claude changes in a source file is wrapped in two line comments:

```pascal
// >>> Claude 2026-09-06 start
// <<< Claude 2026-09-06 end
```

Read the marked regions, keep or undo what is inside them, and when a set is accepted remove the
markers with `python3 tools/strip-claude-marks.py`, optionally naming one date. The `--list`
option shows what is marked without changing anything. The markers are line comments, so they
cannot open or close a Pascal comment block and do not change what the compiler sees.

---

## 1. Before anything else

**Review the marked regions and commit.** `Fertility.pas` carries the fixed-parameter conflict
fix, the check of the fecundability heterogeneity model, the name of the sterility model in force
for the chart title, and the correction of the exact age at onset of sterility. `Verification.pas`
is new. `FertilityRuntime.pas`, `Nuptiality.pas` and `Kinship.pas` carry the 81 sites converted to
it, and `FertilityRuntime.pas` the family A counters and their report; `Kinship.pas` also carries
the thread lifetime fix in `multi_initMotherhood`. `Defines.pas`, `Declarations.pas`,
`SpecialRuns.pas`, `LazGraph.pas`, `LazMain.pas` and `Utilities.pas` carry the rest. Committed
already, in three commits: N2, the renaming of the three month counters, and the removal of the
`wt_currMonth` parameter.

**Build in Lazarus.** Nothing below is worth starting until this is done. The 23 units that do not
reach the LCL compile in a container, but not the `.lfm` binding, and not `LazMain`, `LazUtiles`
or `LazGraph`, which reach TAChart. `LazGraph.pas` and `LazMain.pas` are the two that changed.

**Check the debug checkbox works.** Main window, "Debug" button, tick "Activate debug", then run
*without* saving the configuration first. It should still be on when the run starts. Before this
week it was wiped twice per run.

---

## 2. Verify what has been fixed

Six rounds of fixes have never been run against a simulation. This is the largest block of work
and the most valuable.

| | what to check | what it tests |
|---|---|---|
| **V16b** | Léridon Table I: conception ending in a live birth within 12 months should be **75.4 per cent at age 30, 66.0 at 35, 44.3 at 40**; within 4 years 90.7, 83.9, 63.7. Median age at onset of sterility 44.7 years. The run now prints a check of the fecundability heterogeneity model to the memo: read the largest gap between the simulated and the theoretical distribution against the Kolmogorov-Smirnov band, and the mean of the theoretical grid against the parameters requested | the whole fecundability chain. **If too fecund**, the comment at the call site in `Fertility.pas` says what to change |
| **V14** | A two-step separation sweep: the `SEP` column must differ between steps and the second must not be zero | the sweep fix. Before, both were zero |
| **V14d** | Every `NSTEP_*` at 1, compared against the same run before the fix: must be **identical** | that ordinary runs were never affected, which is what lets you keep results you have already published |
| **V14b/c** | A three-step sweep of mean age at union must reach its High value; a three-step amenorrhea sweep must be evenly spaced | the other two halves of the sweep fix |
| **V15** | The distribution of age at end of union must not pile up at the oldest ages | `endUnion` |
| **V18** | `checkSumShareHeirs` must sum to 1 with two, three and four surviving grandparents | the ascendant share loop |
| **V20** | A cohort file with an explicit `NWOMEN` column, and one containing a blank line | the cohort file fixes |
| **V19** | A hand-written configuration file with lowercase names and trailing spaces must be accepted, and the file the program writes must carry a `FILENAME` line | the configuration round trip |
| **V4** | Write a DemoCare file and read it back, both layouts: kin types must survive, nobody twice in a union list | the DemoCare reader |
| **V9** | A multi-cohort run: every cohort present, family and individual numbers continuous and never repeated | the multi-cohort fix |
| **V10/V11** | A multithreaded run: no two genealogies identical; the same number of families with multithreading on and off | the seed race and the atomic counters |
| **V23** | Several cohorts with `MULTITHREADING` and `MULTITHREADING_INIT` on: no two cohorts with the same seed | N42, once fixed |
| **V17** | The mean birth interval after an infant death against the interval after a surviving child: the difference should be of the order of the shortening of breastfeeding, not of nine months | the N2 fix |
| **V21** | A cohort in which no woman is simulated must not raise a division by zero in `writeInfoParents` | the guarded divisions |
| **V22** | A run with a life expectancy outside the tabulated range, and one with an education status that is not B, M or A | the two silent-corruption fixes, and N14, which still does not clamp |
| **V8** | The same configuration run twice with multithreading off, compared byte for byte. Check also that the Config dialog leaves "Same Random Sequence" enabled when only `MULTITHREADING_SIMKIN` is off | reproducibility |
| **V2/V3/V5/V6/V7/V12/V13** | Column counts against headers; `partnershipStatus` showing `firstUnion` and `secondUnions`; no negative `tickOut`; grandparents-only selection; the `kt_total` row; `MULTITHREADING_SIMKIN` surviving a save; the "Use batches" checkbox gone | rounds 1 to 3 |


### What is not yet in the verification table

81 sites were converted: 66 in `Kinship.pas`, which is every live one there, 13 in
`FertilityRuntime.pas` and 2 in `Nuptiality.pas`. About 31 invariant sites are still written the
old way, as a `writeAndWait` followed by the debugger trap spelled out longhand. They are silent
in a batch run, they do not appear in the table, and a run that trips one of them still reports
that every check passed.

| unit | sites | what they watch |
|---|---|---|
| `Nuptiality.pas` | 6 | the union getters and setters, exactly the family in N28: a bad index is reported and then the phantom union is written anyway |
| `Fertility.pas` | 7 | the children list, the fixed-parameter names, the standard deviation of the heterogeneity, the age at sterility |
| `EducationalLevel.pas` | 5 | a nil relative, an unassigned cohort, a bad partner, a bad status |
| `inheritance.pas` | 4 | a decedent or an heir not found in the set, the count of heirs of degree 4, the unreachable arm of `checkHeirs` |
| `Parenthood.pas` | 4 | the four consistency tests of `checkChildrenList` |
| `Kinship.pas` | 5 | the five in the small helpers near the top of the unit, left when the 66 were done |

What should stay as it is, and why: the 13 sites inside `on E: Exception do` handlers, which report a
fault that has already happened rather than test a property; the 11 that report a bad cohort file, a
file that cannot be opened, or a life expectancy outside the tabulated range, which are messages to
the user about an input; and the handful marked WARNING, which describe a case the model handles and
the user may want to know about. `Declarations.pas` cannot be converted at all, since `Verification`
uses it.

**The dead ego breakpoints.** `gIndEgo` is set to 0 in `simulateKinship` and updated only inside a
block guarded by `{$IFDEF DEBUG - NOT THREAD AWARE}`. Free Pascal reads that as `{$IFDEF DEBUG}`
and ignores the rest of the line, and the `Debug` symbol was removed on 29 August, so the block is
dead. Six checks used to report `[gIndEgo]` as their context and therefore named ego 0 every time;
they now report `pEgo^.indNumber` or `pRel^.indNumber`, which are in scope at each site and are not
globals, so they are also safe under multithreading. What remains to decide is the block itself: it
holds the two breakpoints that stopped the run at a chosen ego, from `gViewEgos` and the Debug
dialog, and they have not worked since 29 August. Restore them under a live symbol, or remove them
and the dialog field with them.

**The exception handlers deserve one routine rather than a check each.** Thirteen of them repeat
`writeAndWaitConst(['===> ERROR: ', E.Message]); breakOnFailure;`, which writes to the memo, stops
the debugger, and leaves nothing in the verification table, so a run that swallowed an exception
in a worker still reports that every check passed. One `reportException (E, 'where')` in
`Verification.pas`, counting them and setting `gDebugError`, would put them in the table without
turning them into checks of the model.

**Forty traps have no check beside them**, counted on 6 September: 10 in `inheritance.pas`, 10 in
`FertilityRuntime.pas`, 9 in `Kinship.pas`, 7 in `Fertility.pas`, 4 in `Nuptiality.pas`. Thirteen
of those are the exception handlers above and two are the dead ego breakpoints; the rest are
invariants that stop the debugger and record nothing.

The debugger traps are no longer part of this: all 43 of them, in `Fertility.pas`,
`FertilityRuntime.pas`, `Kinship.pas`, `Nuptiality.pas` and `inheritance.pas`, are now
`breakOnFailure`, so converting a site is one line to change and not six.

### A second implementation, as a way of checking the first

`calcNbChildren` and the routines nested inside it share `currMonth`, `nbChildren`, `endUnion`,
`monthStart` and `pCurrChild` by scope rather than by argument, and every bug found in it this
year, N2, N5, N6, N6b and the vacuous checks, comes from that: a routine moves a variable that
another routine also moves, and nothing in the text says which one owns it. A second
implementation, written from the demographic description rather than transcribed from the code,
and run beside the first on the same woman, would settle whether the interval machinery does what
the model says. It is worth doing, on four conditions.

**The two must see the same random numbers.** Otherwise only distributions can be compared, over
many thousands of women, which finds a bias but not the woman it happens to. `TRandomNumberGenerator`
keeps its state in instance fields, so the cheapest arrangement is to copy the state before the
first call and restore it before the second, and compare the two women exactly.

**The comparison must be on the whole outcome.** The number of children is the weakest possible
test. Compare the month of every conception and every birth, the sex of each child, the month the
union ends and why, the month of stopping, and the non-susceptible period of each interval.

**The second must be a rewrite, not a copy.** If it is written by reading the old one line by line
it will reproduce its bugs, and the agreement will mean nothing. It should take its state in one
record passed explicitly, with no nested routine touching a variable it does not own.

**A difference does not say which one is wrong.** Each one is an investigation, and the answer
comes from the model, not from either program. That is the cost, and it is also the point.

Where it should live: its own unit, so that it cannot share a scope with the original, called from
the verification framework under a switch, on a sample of women rather than on all of them, with
the first differences reported in the verification table. Built in that order: one union with no
separation, then separation, then several unions, then stopping.

### How each of these can be decided

Three mechanisms now exist, and every item above falls to one of them. What is left over
is what genuinely needs your eye.

**Inside the run**, `Verification.pas`. A check has an identifier, is called from the
simulation, and appears in one table at the end of the run, in the memo and in
`<results>/verification.txt`. Three forms: `checkFalse` and `checkTrue` for a state that
cannot occur, `checkValue` for a quantity against a target with a tolerance,
`checkDistribution` for a simulated histogram against the probabilities it was drawn
from. Invariants always run, since a check that runs only in a debug session is a check
that never runs; only the breakpoint is conditional, and only on the first failure of
each check. The table is in a fixed order, so two runs can be compared with a diff, and
a check that was never reached is listed as such, which is how you find a check that
silently stopped being called.

**Between two runs**, `tools/compareruns.lpr`, a Free Pascal console program built with
`fpc -O2 compareruns.lpr`. Compares two results folders cell by cell, with an optional
tolerance, and reports the first differences per file. `-headers` checks that every data
row has as many columns as its header. Its exit code is 0 when the two folders agree, so
it can drive a script, and it uses the run-time library alone.

**Against published values**. Targets stated as constants next to the check that uses
them, compared with `checkValue`. This is the part that says the model is right rather
than merely self-consistent.

**Family A, done so far.** Five of the distributions the model draws from are now counted
during the run and read against their input at the end of it, by `reportFertilityChecks` in
`FertilityRuntime.pas`: the age at onset of sterility against whichever of the three models is
in force, the amenorrhea after a live birth against the Lesthaeghe and Page schedule, the month
a pregnancy is lost against Barrett, the spacing contraception of each birth interval against its
own waiting time distribution, and the proportion female at birth against the parameter. Four of
them also fill an observed curve that the graph window draws beside its input, on the charts for
the amenorrhea schedule, permanent sterility, the fecundability heterogeneity and the
intrauterine mortality distribution.

Two notes on what those comparisons mean. The spacing check counts the length each spell would
have had if nothing interrupted it, because the spells actually lived are cut short by the end
of the union and by stopping, and a censored distribution cannot be read against its input.
Parity 0 is left out of it, since the two calls made before the first birth read two different
inputs. Two more were added on 6 September, the intrauterine mortality risk and the stillbirth risk by the
mother's age at conception, each read against the schedule it is drawn from and each drawn beside
it. What remains in family A: the age at first union and the woman's life table, both needing a
counter where the draw is made.

**How several settings are handled.** A sweep, or a run of several cohorts, simulates more than one
setting, and four of these quantities are defined by the demographic regime and differ between
settings: the amenorrhea schedule, the distribution of the month a pregnancy is lost, the waiting
time of the spacing, and the proportion female at birth. Their counters are emptied at the start of
each setting, so the curve and the check describe the last one alone rather than a mixture of
inputs, and the legend says so. The others read tables that do not change between settings, so they
are counted over the whole run, which is more precise, and the legend says that instead. One
residue: the women created by `initMotherhood` are drawn once, under the first cohort, so in a
multi-cohort kinship run the last cohort's curves rest on its own genealogies alone.

**What family A has already found.** The check on the age at onset of sterility failed on its
first run, by about 0.17 at age 44, and the cause was in the interpolation of the exact age, which
read the fraction on the year above the one the cumulative risk crosses. Both that and N8 are now
fixed and are described in the companion document. This is the argument for the rest of family A:
the fault had been in the model for as long as the interpolation had, and no output table showed
it.

| item | mechanism | what to do |
|---|---|---|
| **V16b** | published values | Wire the proportions conceiving within 12 and 48 months at ages 30, 35 and 40, and the median age at onset of sterility, into `checkValue` against Léridon's 75.4, 66.0, 44.3 and 90.7, 83.9, 63.7 and 44.7. The quantities exist in the time-to-conception tables; they need to be read at the end of a run |
| **V14, V14b, V14c** | between two runs | Run the sweep, then compare the per-step output files: the swept column must differ between steps and must reach its High value |
| **V14d** | between two runs | Keep a results folder from before the sweep fix, run again with every `NSTEP_*` at 1, and `compareruns` must report no difference |
| **V15** | inside the run | A distribution check on age at end of union, or simply the existing table read once |
| **V18** | inside the run | `checkSumShareHeirs` in `Kinship.pas` becomes a `checkValue` against 1 with a tolerance of 0.01, instead of the line that assigns the variable to itself |
| **V19, V20, V4** | between two runs | Write the file, read it back, write it again, and compare the two written copies. A round trip that loses nothing produces two identical files |
| **V9** | between two runs | The individual file of a multi-cohort run, checked for continuity of the identifiers, which is a column test rather than a comparison: add it to `compareruns` |
| **V10, V11, V23** | between two runs | Two runs with multithreading on: the genealogies must differ, the counts must not. Compare the seeds written in the header |
| **V2, V3, V5, V6, V7, V12, V13** | between two runs | `compareruns -headers` decides the column counts; the rest are one look at a named column, which the comparison of a run before and after the fix also settles |
| **V17** | inside the run | A `checkValue` on the two mean intervals, or one reading of the interval table by whether the previous child survived |
| **V21, V22** | inside the run | Run each bad input once; the guard either holds or the run stops. V22 also needs N14 fixed, since an out-of-range life expectancy is still not clamped |
| **V8** | between two runs | `compareruns` with no tolerance on two runs of one configuration |
| **V16** | done | The realised moments of the fecundability multiplier are now printed by the check inside the run, and the simulated distribution is drawn beside the theoretical one. Nothing to dump from the individual file any more |

The first three checks to wire, in order: the Léridon targets, since they are the ones
that say whether the fertility model is right; `checkSumShareHeirs`, which is one line;
and a baseline folder kept from a single-threaded run with a fixed seed, which turns
every later change into a comparison rather than a judgement.

---

## 3. Results still wrong, in the order I would fix them

Re-read against the source on 13 September. These change simulated numbers. The right-hand
column says roughly how much, which is what decides the order.

### Education, the largest of them

| | where | what, and how much |
|---|---|---|
| **N20** | `EducationalLevel.pas:176`, `edStatusStocha` | With `EDU_STATUS` on the stochastic mode every person is drawn from a written-in 1/3, 1/3, 1/3 and the six `EDU_*` parameters are never read. **The whole education distribution**: ask for 60/30/10 and the run gives 33/33/33. Zero in the cohort mode, which reads `p^.eduEgo` correctly |
| **N18** | `EducationalLevel.pas:299` | The intra-family mode correlates four kin types out of twenty-seven and siblings are not among them. **Most of the simulated kin get no family correlation at all.** Blocked on Q5 |
| **N17** | `EducationalLevel.pas:263` | `p^.eduEgoPartner [eduLevelPartner, pRelative^.gender, ...]`: the first index is the partner's level and the second the sex of the person being assigned. **Only the sex asymmetry of assortment is lost**, since the matrix is strongly diagonal both ways: zero if it is symmetric, as large as the asymmetry otherwise. Settle the intended reading first, since the alternative is that the first index is the wrong one |
| **N19** | `DemographicRegime.pas:746` writer, `1812` header | The mode-to-table mapping is off by one, so the cohort file records a different education table from the one the run used. **Zero for the run that writes it, total for the next run that reads it.** Correcting it changes the cohort file format for all three modes |

### Fertility and nuptiality

| | where | what, and how much |
|---|---|---|
| **N32** | `Nuptiality.pas:1152` | After a range error on `monthly_risk_separation [durationUnion]` the handler writes a message and execution continues past the `try`, where two uninitialised doubles decide the separation. **Zero in a run where it never fires, arbitrary for the unions affected in one where it does.** It did not fire in the run of 11 September, which reported one problem only. The cause is the unbounded index, so it is also in 3b |
| **N4c** | `FertilityRuntime.pas:1135` | With `RESHUFFLED_FECUNDABILITY` on, the redraw after each birth rebuilds the age schedule from `gFecundability` and discards the Léridon taper. Off by default. With it on, fecundability in the 12.5 years before the woman's own age at sterility is too high by the whole taper: **at three years before sterility the correct factor is about 0.24 and the run uses 1.0**. It also turns between-woman heterogeneity into within-woman noise, which is a different model rather than a bug. **Decide which** |
| **N10** | `FertilityRuntime.pas:3187` | The net reproduction rate uses the constant 0.488 instead of `PROP_WOMEN_AT_BIRTH`. **Reporting only, the simulated population is unaffected. Zero at the default and in proportion to the ratio otherwise**: at 0.51 the reported rate is 4.5 per cent low. One line |

### Inheritance, all blocked on Q3 and Q4

| | where | what, and how much |
|---|---|---|
| **N22** | `inheritance.pas:1455` | A nearer ascendant does not exclude a remoter one: the paternal and maternal branches recurse independently. **Surviving grandparents share with great-grandparents, so every share in such an estate is diluted.** Contradicts the file's own header comment |
| **N24** | `inheritance.pas:895` | `commonAncestor` is computed and discarded at four of five call sites. **A maternal half-sibling with no blood link to the deceased takes an equal share** |
| **N25** | `inheritance.pas:2076` | `lookForDecedents_Spain` has an empty body and the `inher_Spain` / `inher_Other` choice is never consulted. **The country rule set has no effect**: both algorithms run unconditionally |
| **N26** | `inheritance.pas:2133` | `checkHeirs` reports agreement in exactly the case where the algorithms disagree, and its final `else` is unreachable. **No result changes, but the check that would catch N22 and N24 is inverted, so it hides them.** The list comparison is also order-sensitive |

### Threading, where it changes results

| | where | what, and how much |
|---|---|---|
| **N42, N43** | `DemographicRegime.pas:93, 1122` | The worker seeds itself inside `Execute`, which the warning in `RandomNumbers.pas` forbids, and the pool loop cannot exit on the flag it sets. **With `MULTITHREADING_INIT` and several cohorts, two cohorts can receive the same seed and therefore identical fertility schedules**, which makes them duplicates of each other. The constructor already seeds on the main thread, so the offending line can simply go. See also G11, which is the other half |

### Cohorts

| | where | what |
|---|---|---|
| **N11** | `Declarations.pas:1386` | Every cohort after the first loses its parameter list: `copyMeTo` sets `next := nil`, and the state copy starts with the field that *is* the head of the list. A GUI edit to cohort 2 is lost with no prompt |

---

## 3b. Missing guardrails against out-of-range values

These leave results untouched while every input and index stays inside its range. They decide
what happens when one does not, and today that is a range error, a wrong cell, or a hang. The
first row is the one I would take first: it holds the only entries in either section that can
corrupt memory silently with range checks off.

| | where | what is unguarded |
|---|---|---|
| **Index bounds, five of them** | `Kinship.pas`, verified 13 September | `addChildrenBACKFORInfo` at 2886 puts an age at union on a fertility-age axis (`- kMinAgeFert`); `addBridesInfo` at 2754 and 2757 and `addUnionsInfo` at 2788 compute indices with no test at either end; `addGroomsInfo` at 2687 has `max (0, ...)` and no high clamp; `getAgeUnionSelected` can reach `Unions [-1]`. **Blocked on Q6**, whose answer decides whether the fix is a clamp or a rejection, and it is the same answer for all five. The sixth, `lookingForABrideByAgeAndCohort`, is now bounded |
| **N29** | `Nuptiality.pas:651` | `scaleFactor := (mean - ageMin) / 11.37` with nothing keeping the mean above `ageMin`. The dialog allows a mean age at union of 10 while `kMinMeanAgeUnion` is 15, so the reachable range is wider than the model allows, and below it the schedule has densities of the wrong sign. Clamp here and give `MEAN_AGE_UNION` the same minimum in `LazConfig` |
| **N32**, the other half | `Nuptiality.pas:1152` | `durationUnion` is not bounded to the table it indexes. Bounding it is the correction; making the handler leave the function is the safety net |
| **Cohort file header** | `DemographicRegime.pas:1535` | Table indices taken from the cohort file header with no bounds check |
| **G2** | `LazConfig.pas:457` | `STEP_COHORT` is bound with no minimum and the dialog accepts 0, which makes `currCohort := currCohort + 0` an infinite loop at `ReadCmdFileUnit.pas:1599`. `FIRST_COHORT` and `LAST_COHORT` are unchecked the same way |
| **G3** | `LazOutput.pas:374` | `MAX_THREADS` accepts up to 999999, `ReadCmdFileUnit.pas:1571` copies it into `gMaxThreads` with no clamp, and that many threads are then created |
| **G15** | `LazUtiles.pas:121` | `StrToInt` on the raw text of three edit boxes inside `FormCloseQuery`, after `CanClose` is already true and one of the three globals has been updated |
| **N45** | `StringOfLib.pas:114` | The trailing-zero strip assumes a decimal point remains. The dialog clamps `FLOATING_POINT_DIGITS` to 1..10 but `LongintName.readValue` does not, so a configuration file can reach 0, where 100 is written as "1" and 0.23 raises a range error |
| **N37** | `Kinship.pas:3651` | `TPersonMemoryManager.Create()` with no argument takes the default size, about 800 MB, and two are created before anything is known about how many people the run needs. The count is available: pass it |
| **N49** | `FertilityRuntime.pas:749` | Not wrong today. `addChild` declares its table `out` and accumulates into it, which works only because FPC does not clear a plain array. It becomes a silent loss of every count the day the type changes. Should be `var` |

---

## 3c. A mechanism that was planned and never built

`Kinship.pas:400` declares

```pascal
gBig_ArrayGrooms: TPersonMemoryManager; // possible grooms // global used in MAIN THREAD only
```

and that identifier appears nowhere else in the program: never created, never filled, never
read. What exists is two pools, both of women, `gBig_ArrayWomen` for the possible mothers and
`gBig_ArrayBrides` for the possible brides, the second only under `NEW_INIT_MOTHERHOOD` with a
stable population. The groom index is not a third pool but a re-indexing of the second:
`g_RangeBridesForGrooms_Info [cohort, ageAtUnion]` holds bride indices, keyed by the cohort and
age at union that each bride's union *implies* for her partner.

A groom therefore has no simulated life. In the kinship tree a man enters as the partner of a
woman, `copyManPartnershipInfoToManAsRelative` gives him the one union he was created for, and
`calcStateMan` builds his history forward from it. Nothing before that union exists: no earlier
unions, no earlier children, and his age at first union is the one the match implied rather than
one drawn from the male celibacy schedule. The men's histories are left truncated.

This is a design decision rather than a defect to fix: building the pool means deciding whose
reproductive history is the master when two simulated people form a union, and today it is the
woman's throughout. One consequence for the diagnostics: on the bride side a shortage of
candidates is real and measurable, since the candidates are simulated women, while on the groom
side there is no pool to be short of, so the question reduces to whether the bride index holds a
cell for the cohort and age at union asked for.

---

## 4. Threading and object lifetime

Each needs a design decision and its own test. A wrong fix here is worse than the bug.

| | where | what |
|---|---|---|
| **N42** | `DemographicRegime.pas:97` | The seed race that was fixed in `Kinship.pas` survives here: the worker calls `initRandomized` from inside its own `Execute`, which the warning comment in `RandomNumbers.pas` forbids. Two cohorts can get identical fertility schedules. **The constructor already seeds on the main thread, so this line can simply be deleted.** Gated by `MULTITHREADING` and `MULTITHREADING_INIT` |
| **N43** | `DemographicRegime.pas:1094` | `allThreadsDead := false` sits inside the inner loop, so half the exit test is dead |
| **N44** | `DemographicRegime.pas:87` | `TDemRegInitThread.Destroy` has no `inherited Destroy` |
| **2.3** | `Kinship.pas:6642`, consumer at `6659` | The go-flag is published before the state the worker reads, with no event, lock or barrier. Apple Silicon is weakly ordered, so this is not theoretical on your machine |
| **2.4** | `Kinship.pas:2878, 7619, 7739`; `Utilities.pas:288` | Every wait is a hot spin with no yield |
| **2.5** | `Kinship.pas:7421, 7431`, caller at `7684` | The link file failing to open leaves the main file open, and the caller's bare `exit` skips `writeTables`, `DestroyArrayChildren` and all thread cleanup, leaving workers spinning |
| **N34** | `Parenthood.pas:77` | `distNbChildren` is incremented with a plain `Inc` from every worker into one shared record |
| **N36** | `Kinship.pas:2879` | `.Destroy` immediately after a spin, with no `WaitFor` and no `inherited` |
| **N38** | `Kinship.pas:2876` | `nActiveThreads` is not a count of running threads, so `.start` is called on threads already running |
| **N41** | `Kinship.pas:3175` | Bootstrap replicates reuse stale arrays. **Disappears if bootstrapping is removed**, and is that change's acceptance test |

---

## 5. Smaller things

Entries that moved out of this section on 13 September: `N28` and `N30` and `N31` are fixed;
`N29`, `N37`, `N45` and `N49` are now in 3b with the other guardrails; `Erlang` is fixed; the
`getPartner` guard now reads `kMaxNbUnion` rather than the literal 20.


| | where | what |
|---|---|---|
| **N32** | `Nuptiality.pas:1152` | The exception handler falls through and the separation is then decided by two uninitialised doubles. Full entry in section 3; the unbounded index behind it is in 3b |
| **N46** | `Nuptiality.pas:1024` | Four arguments to a three-argument procedure, inside `{$IFDEF DEBUG_SEPARATION}`. Harmless until someone turns that define on, which is exactly when they would |
| **Bride selection** | `Kinship.pas:5343` | `caseSelect` is assigned the constant 2 immediately above the `case` that reads it. The third algorithm is the right one and the other two are kept for comparison, which is deliberate. Worth a comment at that line saying so, since the two branches read as live code and their checks are reported as never run |
| **Arithmetic** | `FertilityRuntime.pas:2853, 2635, 2614`; `DemographicRegime.pas:1535` | Division by zero on an empty cohort; an extra `Inc` leaving a history slot unset on a warm start; a result read from an uninitialised record and printed; table indices taken from the cohort file header with no bounds check |
| **Index bounds** | `Kinship.pas`, `initMotherhood` | Five index computations with no bounds test: `addChildrenBACKFORInfo` indexes an age at union on a fertility-age axis; `addBridesInfo` and `addGroomsInfo` have no high clamp, the `max (0, ...)` guarding only the low end; `addUnionsInfo` is off by one; `lookingForABrideByAgeAndCohort` walks off both ends with no escape for an empty range; and `getAgeUnionSelected` can reach `Unions[-1]`. **Blocked on Q6**, since the answer decides whether the fix is a clamp or a rejection |
| **4.3** | `Kinship.pas:3879` | `writeKinship` counts every relative that passes `includeKinInNetwork`, whether or not `writeKin` wrote a row, so the reported individual count can exceed the rows in the file |
| **4.11** | `Kinship.pas:7870` | `stopTime` reads `tStart_interm` outside the `TALKATIVE` guard that surrounds both of its assignments |
| **5.2** | `Kinship.pas:3861` | `includeKinInNetwork` has no initialisation and no final `else` |
| **4.6** | `Kinship.pas:7334`, duplicate at `7342` | `heirs` emitted twice as a header, and the user-facing columns written from the second algorithm's variables |
| **4.7** | `Kinship.pas:3703` | Empty-value sentinels disagree: `''`, `'0'` and `'-1'` in the same row |
| **4.8** | `Kinship.pas:3539` | The ego children check is redundant; `CalcChildren` already reports it |
| **4.2** | `Kinship.pas:3633` | Link file: `M` rows in both directions |
| **5.6** | `Kinship.pas:7624` | Comment the deliberately commented-out `Destroy`, which would be a double free |
| **1.3** | `Kinship.pas:3834`, header at `7358` | GEDCOM is selectable and writes a header and no rows. Remove it from the combo until implemented |
| **3.b** | `Init.pas:516` | `USE_ARRAY_CHILDREN` is never written or read, and is constructed TRUE but defaulted FALSE |
| **3.d** | `ReadCmdFileUnit.pas:848, 876` | `DUMP` and `STABLE_POPULATION` have commented-out writers and live readers |
| **3.1** | `ReadCmdFileUnit.pas:1014` | `DUMPALL` writes a detailed file with no tables in it |
| **3.4** | `lazkinoutputfields.pas:84` | `fn_yDeathFloat` has no checkbox: 21 boxes for 22 enum members |
| **3.5** | `ReadCmdFileUnit.pas:1672`, discarded results at `1329` and `Simulxcode.pas:42` | The finished banner prints on the error path, and two of four call sites ignore whether the run succeeded |
| **6.4** | `Declarations.pas:1577` | `setChanged` requires a prior `setDefault`; add the comment saying so |
| **Dead code** | `Utilities.pas:1323`; `testThread.pas`; `mothersInfoList.pas` | `writeOneArrayOfDouble` has no callers; `testThread.pas` declares a unit name that does not match its file; **`mothersInfoList.pas` was reported deleted on 26 August but is still present and tracked** |

---

## 6. The GUI and the utility units, now read

Read on 6 September, in four passes: `LazMain`, `LazUtiles`, `LazLowlevel`, `Simulxcode`, `docform`;
`LazConfig`, `LazOutput`, `ComponentHelper`; `LazGraph` and the five small dialogs;
`NumCPULib`, `Profiler`, `TimeProfile`. Every item below was verified against the source, and in
three cases against the compiler. Nothing here has been changed yet.

### Results, hangs and crashes

| | where | what |
|---|---|---|
| **G1** | `LazMain.pas:706` | `MemoWriteLnExec` does `s := myLine + s` and never empties `myLine`, which only `ClearLog` and the constructor do. After any call of `memoWrite` without a line feed, and `Kinship.pas:6022` makes one on an ordinary path, every later line carries the same prefix, so the test `if (s = kEndThreadMessage)` can never match, `memoWriting` is never set false, and the worker thread spins for ever in `while (KinFertForm.memoWriting) do ;` at `LazMain.pas:856`. The run never finishes, one core stays at 100 per cent, `SaveLog` never runs and every button is dead, since each one begins `if gSimulationRunning then exit`. One line: `myLine := ''` after 706 |
| **G2** | `LazConfig.pas:457` | `STEP_COHORT` is bound with no minimum, so `TEditChange` sets `checkValue := false` and the dialog accepts 0. With KINSHIP on, `ReadCmdFileUnit.pas:1599` is `while currCohort <= last do ... currCohort := currCohort + 0`, an infinite loop, and the second loop at `1637` repeats one cohort for ever, rewriting its output. `FIRST_COHORT` and `LAST_COHORT` are unchecked in the same way |
| **G3** | `LazOutput.pas:374` | `MAX_THREADS` accepts up to 999999, `ReadCmdFileUnit.pas:1571` copies it into `gMaxThreads` with no clamp, and `Kinship.pas:7746-7758` then creates that many threads. The maximum should be of the order of `gNumLogicalThreadsForMultiThreading`, which the line below already prints as the recommended number |
| **G4** | `LazGraph.pas:196` | `SaveToFile` casts `ASeriesList.Items[0]` to `TChartSeries` with no test and reads `ListSource`. On "Outputs: Kinship" the first series is the `TConstantLine` added at `1137`, a sibling class with no such member, so "Save to file" there reads a wrong offset. The same routine has no guard for an empty list, so pressing the button before any run raises "List index (0) out of bounds" after creating a zero-byte file |
| **G5** | `LazGraph.pas:810` | "Waiting time after second birth" draws `AccDurationWaitingTime[1]`, which is the first birth interval, with the first interval's mean and proportion in the legend. It should be `[2]`, in all three places. The second interval cannot be inspected at all today |
| **G6** | `ComponentHelper.pas:388` | `aCompChange` is only assigned inside the class tests, so a component that matches none of them, a `TButton`, a `TLabel`, a `TShape`, leaves it holding a stack value, which is then written into `lastComponentChange.next` and becomes part of the chain that `ShowValue` walks. One rename away from a crash: `LazConfig.pas:537` already passes a name that resolves to nothing today. `aCompChange := nil` at entry and an exit before line 442 |
| **G7** | `ComponentHelper.pas:986, 1055` | `TCohortComboBoxChange.myGetValue` and `TFixedFertComboBoxChange.myGetValue` end with `ConfigForm.updateValues`, which frees the whole `TComponentChange` chain, including the object whose method is running. Control then returns into `TComponentChange.ReadValue` at `630`, a virtual call on freed memory. It survives only because the heap manager does not scrub the object. Set the existing `needToUpdate` flag instead |
| **G8** | `LazMain.pas:824, 832, 838, 860` | `SaveLog` is called from the worker thread and reaches `Log.Lines.SaveToFile` while the main thread is adding lines to the same `TStringList` from queued calls. With `SAVE_LOG` on this is a race on the memo. Queue it like every other GUI touch in the unit |
| **G9** | `LazMain.pas:801-862` | `TKinFertMainThread.Execute` has no `try ... except`. An exception inside a run reaches `TThread`, which still calls `OnTerminate`, so `endSimulation` reports "finished" with a green indicator while the output files were never closed and lost their tails. This is the same complaint as 3.5, from the other end |
| **G10** | `NumCPULib.pas:624` | `GetCPUCountUsingSysCtlByName` never initialises `Result` and ignores the return code of `fpsysctlbyname`, and it is the only implementation behind `GetPhysicalCPUCount` on macOS. On failure it returns whatever was on the stack, which `Init.pas:731` assigns to a longint under range checks |
| **G11** | `DemographicRegime.pas:1101` | The pool starts a thread on `myThreadState = thread_suspended`, but the worker only clears that state once the system has scheduled it, so a thread started in an earlier pass can be counted a second time. `nActiveThreads` then never returns to zero and the loop spins. The main thread should set the state before `start`, not the worker at `96`. This is the other half of N43 |
| **G12** | `LazConfig.pas:466, 537, 580` | `NWOMEN`, `CREATE_COHORT_FILE` and `STABLE_POPULATION` are bound to components that do not exist, `FindComponent` returns nil and `CreateComponentChange` exits with no message. `NWOMEN` is the substantive loss: it is a real parameter, read and written in the configuration file, and it drives the denominators in `FertilityRuntime.pas`, with no way to set it from the dialog |
| **G13** | `LazOutput.pas:186, 193, 206, 219` | Four lines read `OutputForm.ChangesMadeToDefaultValues` inside `TOutputForm`, which is the field being assigned: `x := x or x`. The heirs, decedents, kin selection and optional field dialogs each keep their own flag, and those are what should be read, as `LazConfig.pas:237` correctly does. A change made only in one of the four sub-dialogs leaves the "Edited values" indicator wrong |
| **G14** | `ComponentHelper.pas:1058` | `TFixedFertComboBoxChange.myCheckChanged` forces `myVal.changed := FALSE` with a comment copied from the cohort combo, where the object really is a dummy. Here it is `FIXED_FERTILITY_VALUE`, a live parameter, so changing it never marks the configuration as edited |
| **G15** | `LazUtiles.pas:121` | `FormCloseQuery` calls `StrToInt` on the raw text of three edit boxes. An empty or non-numeric box raises `EConvertError` out of the close handler, after `CanClose` has been set true and after one of the three globals has been updated. `TryStrToInt`, or validation in the OK handler |
| **G16** | `LazUtiles.pas:191` | `convToStr` returns `'0'` for an empty array, so opening the Debug dialog and pressing OK adds ego 0 to the view list that the user never asked for; and clearing the box cannot empty the list, because the length test short-circuits first |

### Leaks, hygiene, and one thing that reads as a bug and is not

| | where | what |
|---|---|---|
| **G17** | `LazGraph.pas`, every `Draw` | No `TDrawParameters` is ever freed: the destructor at `242` has no caller anywhere in the unit. One object per curve per redraw, and the union tables draw thirty curves at a time. A `try ... finally par.Free` around the body of `Draw` covers the two overloads as well |
| **G18** | `LazGraph.pas:535, 559` | A `TListChartSource` is created on every redraw that supplies axis labels, owned by the chart, and only the reference in `Marks.Source` is replaced. They accumulate until the program ends. Create them once, or free the previous one |
| **G19** | `ComponentHelper.pas:461` | `TComponentChange.Destroy` frees `next` and `disableAction` but not `uncheckList`, which is rebuilt on every `FormActivate` and every `updateValues` |
| **G20** | `Kinship.pas:7939` | `cleanUpThread` is created, terminated and waited for, and never freed. `FreeOnTerminate` is false for that class, so one thread object leaks per cohort per replicate |
| **G21** | `ComponentHelper.pas:293` | `strToDouble` sets `DefaultFormatSettings.DecimalSeparator := '.'` and restores it after the conversion. `StrToFloat` raises on a mistyped field, the restore is skipped, and the separator stays changed for the rest of the session. A `try ... finally` |
| **G22** | `LazLowlevel.pas:88` | `FormActivate` rebuilds the component list and calls `showValues` on every activation, which writes the stored value back into every edit box. A number typed and not yet committed, that is with no control having lost the focus, is silently replaced when the user switches away from the application and back |
| **G23** | `Profiler.pas:132, 154` | A dangling `else` makes the `setLevel` argument inoperative and can reset the depth to zero, and `timeProfile_end_proc` indexes the array with the `-1` that `posInsideProfile` returns on a miss. Both are inert today, since `VerboseProfiler` is undefined everywhere. `TimeProfile.pas` is worse: nothing includes it, and the two names it calls do not exist in `Profiler.pas`, so it could not compile if it were used. Delete it, and decide whether `Profiler.pas` and its forty call sites ship |
| **G24** | `LazOutput.pas:172` | `if res <> cmd_outputtomainfile then next;` looks like a loop continuation and is not: `next` resolves to `TCustomForm.Next`, an inherited method that moves the input focus, so the statement compiles, moves the focus once per enumerand, and falls through to the body. The ALL and NONE button does work. The statement should simply go |

Two claims from the same pass did not survive checking, and are recorded so that they are not
raised again. `FormCreate` does **not** run before the constructor body: the LCL fires it from
`AfterConstruction`, which I verified by running a small program against the same LCL, so
`myBufferStr` exists and the output directory read from the `.cfg` is not overwritten. And
`LazOutput.pas` does compile, for the reason given in G24.

Nothing in the tree is now wholly unread except the `.lfm` resources themselves, which only
Lazarus can check, and the parts of `NumCPULib.pas` that serve platforms KinFert does not target.

---

## 7. One deliberate change

**Remove bootstrapping.** You confirmed this. It touches `gBootstrap_nRuns`, the replicate loop
at `ReadCmdFileUnit.pas:1608`, `RP.indBootstrap`, and the `bootstrap_ind` parameter threaded
through `run_all`, `simulateKinship` and `individualKin_*`. N41 is its acceptance test.

**Keep `RP.wkey`.** `openFileKeys` at `Utilities.pas:762` turns keys on whenever any of the seven
step counts exceeds one, so a parameter sweep needs keys with no bootstrapping at all.

---

## 8. Questions only you can answer

| | question | blocks |
|---|---|---|
| **Q2** | Is `LivingBirth` counted from conception, so the correction adds the gestation to the death term rather than subtracting it from `month`? | N2 |
| **Q3** | How far should inheritance follow Spanish succession: does a nearer ascendant exclude a remoter one; are posthumous children heirs; what happens when no heir is found; is usufruct modelled; is per-capita competition at degree 4 deliberate? | N22, N24, N26 |
| **Q4** | Should `inher_Spain` / `inher_Other` select between rule sets, or is the parameter a leftover to remove? | N25 |
| **Q5** | Should education correlate between siblings? At present it does not | N18 |
| **Q6** | Can the repartnering model emit a union age above 74? | several index bounds, and the five in `initMotherhood` |
| **D3** | Should the key column be suppressed in a kinship-only stepped run? `writeKeys` has one call site, inside `FERTILITY_loops`, so with FERTILITY off `RP.key` is never incremented and the column is the constant 0 on every row | cosmetic, but it reaches the file format |
| **Q7** | Do `union_women_men` rows always reach 1.0? | an unguarded sampling loop |
| **N19** | Correcting the education dump changes the cohort file format. Before or after the release? | N19 |

Q1, the fecundability parameterisation, is closed: Léridon specifies a Gaussian, `N(0.23; 0.12)`.

---

## 9. Documentation and publication

**Documentation.** The manual is a first draft at `docs/KinFert-Manual.md`, and it is the third
document: neither this one nor the companion replaces it.

| | what |
|---|---|
| **M1** | Answer the ten questions in Appendix F: the conception model, the repartnering hazard, the mapping from life expectancy to survival, the B, M and A education levels, the default backward variant, the country inheritance rules, the exact file grammars, the drop-down values, and a worked regression example |
| **M2** | Bring the manual up to the work of this year: kin sets per output format, the DemoCare field dialog, `DEMOCARE_LARGE_FIELDS`, the `dead` and `secondUnions` values of `partnershipStatus`, relatives dead before the reference age now excluded from the DemoCare file, the `kt_total` row, and the removal of the BATCH option |
| **M3** | Document the DemoCare format and its link file |
| **M4** | Release notes: `DEMOCARE_LARGE_FIELDS` replaces the `DUMPALL` binding; an old DemoCare configuration carries a wide `OUTPUT_KINTYPES` that is now honoured; the DemoCare file no longer contains relatives dead before the reference age; BATCH is gone; `MULTITHREADING_SIMKIN` is now saved |
| **M5** | Fold the cleared findings, which are listed in the companion document, into developer notes, so that the reasoning survives the documents |
| **M6** | The model description, not only the code, changes with the fecundability parameterisation and with the effect of infant death on the birth interval. The manual must say what the code now does: a constant multiplier per woman, so the coefficient of variation is the same at every age by construction, and the realised rather than the nominal moments of that distribution |
| **M7** | Document the parameter sweep semantics: which parameters step, that steps and cohort sequences are mutually exclusive, that selecting both silently resets all seven step counts with a message, and what the KEYS file decodes |

**Publication.** The repository is already public at `github.com/ddev2/KINFERT`.

| | what |
|---|---|
| **P3** | `KinFert ConfigDir.cfg.example` and `KinFert OutputDir.cfg.example`. The real files are gitignored, so a fresh clone has nothing to start from |
| **P4** | Pin the versions. `kinfert.lpi` carries `Version Value="12"`; state the Lazarus version it was saved with and the FPC version it is known to build under. FPC 3.2.2 is verified for the engine |
| **P5** | Decide how the binaries are built and released. `KinFert`, `KinFert.exe` and `KinFert.app` are in the folder and gitignored, which is right; they belong in a Release built from a tagged commit |
| **P6** | A minimal regression test with a known output: one small configuration file, one expected output folder, and a note on how to compare. V14d is the natural candidate, and `compareruns` is the comparison |
| **P7** | Decide whether `CLAUDE.md`, `AGENTS.md` and these documents ship with the source |
| **P10** | Decide whether `testThread.pas` ships. It declares `unit testThreads` while the file is named `testThread.pas`, and nothing references it |
| **Line endings** | A `.gitattributes` with `*.pas text eol=lf`. `Fertility.pas` was converted from CR-only on 31 August, but `LazConfig.pas` is still CRLF, and mixed endings across two platforms produce whole-file diffs that hide the real change. One loose end from that conversion: it was made in the same working tree state as the fecundability fixes, so `git diff` shows the whole file and the content changes are invisible inside it |

**And the one that deserves real thought (P8):** what to say about results produced with earlier
versions. The sweeps, `endUnion`, the fecundability heterogeneity and now the age at onset of
sterility all changed simulated numbers, and the repository is public.
