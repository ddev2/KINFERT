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
| **The education probabilities of a cohort file never reached the distribution anyone was drawn from** | `initEduStatus` and the new `cumulateEduStatus`, `EducationalLevel.pas`; the call for every cohort in `DemRegimeCollection_init` | The three sampling routines read `cumulValue`, and `cumulValue` was computed once, when the cohort object was created, from the built-in defaults of 0.5, 0.4, 0.1 for men and 0.6, 0.35, 0.05 for women. The cohort file reader and the interpolation between cohorts write `.value` only, so in the cohort and the intra-family modes every person was drawn from those defaults while `_ALLCOHORTS.TXT`, which dumps `.value`, echoed faithfully what had been asked for. Wrong numbers, no warning, and a dump that agreed with the input | The three cumulation loops are now one routine, `cumulateEduStatus`, called on a cohort object as it is created and again for every cohort at the start of a run, after the cohort file has been read and the missing cohorts interpolated, which is the one place every route passes through. Each row is checked to sum to one, as `eduRowSumsToOne`, which catches a cohort file whose three probabilities do not: a row summing to less than one gives the top level more than it asks for and a row summing to more never reaches the top level at all. Demonstrated on this build: with a cohort asking 0.60, 0.30, 0.10, the cumulative values still read 0.500 and 0.900 before the call and 0.600 and 0.900 after it, and a row of 0.60, 0.30, 0.20 is reported |
| **N20, the stochastic education mode was silent about reading none of the parameters** | `edStatusStocha`, `EducationalLevel.pas`; the notice in `initParams` | The mode gives every person an equal chance of the three levels. That is what it is for, a uniform test distribution, but nothing said so, and a run made with `EDU_STATUS` on it looked as though the six `EDU_` parameters had been used | The thirds stay, by your decision of 18 September, and are now declared in the source. `initParams` writes one line in the memo at the start of such a run saying that the mode reads none of the `EDU_` parameters and which modes do |
| **N18, the intra-family mode correlated four kin types out of twenty-seven, and siblings were not among them** | `edStatusIntraFamily`, `EducationalLevel.pas`; `giveEdStatus`, `Kinship.pas` | Only ego, the partner, the children and the grandchildren were correlated. Everyone else, siblings included, was drawn from the cohort distribution with no family link, in a mode whose name promises one | The rule now names no kin type, by your answer to Q5: whoever has both parents in the network, with a status already drawn, takes the distribution conditional on the two of them, which covers the siblings, the nephews and nieces, the cousins and ego itself, and whoever is left keeps the cohort distribution. The partner stays a case of its own. `giveEdStatus` draws the parents before their children, by climbing to them first, where before it walked the list in the order the network was built and a child could be reached before its mother. One draw per person either way, so the random stream keeps its length; which person takes which number changes, so the education of a run differs from before even where the distributions do not. **The consequence to weigh:** the `EDU_` proportions of a cohort now bind only the people at the top of each line of descent, and the levels among egos are those the parent to child matrix implies rather than the proportions asked for |
| **The five reports of `EducationalLevel.pas` did not stop what they reported** | `edStatusCohort`, `edStatusChild`, `edStatusPartner`, `eduLevel` | A nil person was reported and then dereferenced; an unassigned cohort was reported and then handed to `getCohort_p`, which answers with the nearest cohort it has, so the person was drawn from another cohort's distribution; a nil partner was reported and then dereferenced; a partner with no status was read before the test; and a bad or empty status became the lowest level in silence | All five go through the verification table, as `eduRelativeMissing`, `eduCohortNotAssigned`, `eduParentStatusMissing` and `eduLevelName`, and each one now leaves the routine or falls back to the distribution of the cohort, which is what a person with no partner or no known parents should have |
| **N34. The parity distribution was counted with a plain `Inc` from every worker thread** | `incrementNbChildren`, `Parenthood.pas` | `distNbChildren` belongs to the demographic regime, one record shared by every thread, and both callers, `egoAddPersonsAndBirths` in `Kinship.pas` and `addPerson` in `Parenthood.pas`, run inside the workers. `Inc` is a read, add, write sequence, so two threads incrementing the same cell at the same moment lost one of the two counts. Nothing crashed and no message appeared: the table was simply short by an unpredictable number, so a multithreaded run and a single threaded one of the same configuration did not agree. The three cells now use `InterLockedIncrement`, which is what the BACKFOR counters and the family A counters already use, at a cost paid once per woman. Test it with V11: the same configuration with multithreading on and off must give the same parity distribution |
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

### `RESHUFFLED_FECUNDABILITY` now reshuffles the multiplier and nothing else (N4c, 17 September)

The switch was listed as defect N4c and is not one: it selects a second model of heterogeneity,
in which the multiplier varies within a woman instead of between women. What was wrong was the
implementation. The redraw sat inside `pregnancy`, so it happened once per conception rather than
once per cycle, and it rebuilt the whole array as `relativeFecundabilityLevel * gFecundability
[age]`, which put the woman back on the general schedule by age and discarded her own: the
Léridon taper over the 12.5 years before her age at sterility, and the shortening of that period
when her age at sterility falls below 33. Since `gFecundability` is flat from age 21 upward under
the Léridon schedule, and flat from 33 under `HIGH_LOW_FECUNDABILITY`, that taper is the only
decline in fecundability the model has at the ages where it matters, so after her first
conception a woman ran at her plateau level up to the month she became sterile. Three years
before her age at sterility her own schedule asks for about 0.29 of the plateau, 0.24 on the
continuous taper the whole-year arithmetic approximates, and the rebuild gave her 1.0.

The model is now what it says. The rebuild is gone. `initFecundLife` stores the reciprocal of the
multiplier its schedule was built with, in the new field `invRelativeFecundabilityLevel` of
`FecundLifeType`, and the test in the month loop of `calcNbChildren` reads

```pascal
if g_GENPARAM.fixedParameters [reshuffledFecundability].state.value then
    fecundabilityThisCycle := fecundabilityLevel (randomGenerator)
            * fecundLife.invRelativeFecundabilityLevel
            * fecundLife.levelFecundabilityAge [currAge]
else
    fecundabilityThisCycle := fecundLife.levelFecundabilityAge [currAge];
```

so the multiplier the schedule carries is taken out, the woman's own age schedule and taper are
left exactly as `initFecundLife` built them, and a newly drawn multiplier is applied to that, once
per cycle of exposure. The months of a non susceptible period, which the loop steps over, draw
nothing. The woman's `relativeFecundabilityLevel` is no longer overwritten, so the individual
fecundability output again reports the level she was given rather than the one last drawn.

With the switch off, which is the default, the expression is the same value as before and no draw
is added, so the random stream and every result are unchanged. With it on, two things follow from
the model rather than from the code, and belong in the manual: the between-woman variance the
Léridon parameterisation asks for is absent, and with it the selection by which the most fecund
conceive first, so waiting times and parity progression differ from a run with the switch off; and
the histogram `gCount_fecundability_draws` then counts cycles rather than women, which the
distribution check still passes because the draws themselves are correct.

**Not done, and it is a decision:** `fecundabilityLevel` finds its multiplier by walking the
cumulative distribution cell by cell, and `kMaxDistribFecundability` is 300, so a call averages
about 150 iterations. Once per birth interval that cost is nothing; once per cycle of exposure it
sits in the innermost loop of the program. A precomputed inverse table, or a binary search, brings
it to one lookup, but a table indexed by the draw does not reproduce the scan exactly, so it would
change results with the switch on.

## Inheritance: the ascendants, by degree and by side of the family (N22 and N22b, 30 September)

**This one changes results.** It is the only change of the month in the inheritance module that
does, and it needs your review before anything is built on top of it.

**What was wrong.** When a person leaves no descendant, the estate goes to the ascendants, and
`exploreAscendantHeirsTree_2` looked for them by recursion: if neither parent was alive at the
death, it explored the father's own ascendants and then the mother's own ascendants, in two calls
that knew nothing of each other. Each line was therefore free to stop at a different generation. A
man dies with no children and no parent; his maternal grandmother is alive and so is a
great-grandfather on his father's side; the two searches put both of them in the heir list and they
took one half each. The rule, in the header of the file, in the Spanish code and in your own words,
is that the nearest degree excludes the rest, so the grandmother should have taken the whole
estate. The fault only showed when one side found nobody at a generation while the other found
somebody, which is why it survived: with a paternal grandfather and a maternal grandmother both
alive, the two searches stop at the same generation and the old code was right.

**What was done.** `AscendantHeirs_2` now asks for one generation at a time. It calls the search
with `degree` set to the parents, then to the grandparents, then to the great-grandparents, and
keeps the first generation that holds an heir. The search itself and the division of the shares are
untouched: a pass that asks for a generation the two lines have not reached adds nothing, because
the test at the top of the search refuses the call, so the heirs of the pass that answers all
belong to the one nearest generation. The three generations are named by one constant,
`kNbGenerationsAscendantHeirs`, which is also the length of the two lists of kin types the routine
builds. A new failure point, `inhAscendantsSameDegree`, states the property that the heirs found
all belong to one generation, which the length of the recorded lineage shows.

**Measured, on a stub genealogy compiled outside the project with the real routines.** Nine cases,
and the shares sum to one in every one of them. Two parents alive: one half each. One parent: the
whole estate. The case above, a maternal grandmother and a paternal great-grandfather: the
grandmother now takes 1.0000 where she used to take 0.5000, the other half having gone to the
great-grandfather. Four grandparents: one quarter each. Two paternal grandparents and one maternal
grandmother: 0.2500, 0.2500, 0.5000. Eight great-grandparents: one eighth each. No ascendant alive:
no heir, and the search moves on to the partner and the lateral kin as before.

**The division of the shares, which the repair brought into view, and which you settled the same
day (`N22b`).** Your rule: the estate is halved between the father's side of the family and the
mother's side, and within a side the heirs of that side take equal parts. A side with no heir at
that degree leaves its half to the other side. Your two examples: with three of the four
grandparents alive, the two on one side take a quarter each and the one on the other side takes a
half; with seven of the eight great-grandparents alive, the four on one side take an eighth each
and the three on the other take a sixth each. The two lines within a side, the father's father's
line and the father's mother's line, are not distinguished, and the choice of the heirs remains a
matter of the degree alone.

`allocateShareAscendantsHeirs_2` used to count the distinct lines of descent present, two at the
grandparents and four at the great-grandparents, and give each line an equal part. It now counts
the heirs on each side and divides accordingly, through a small `sideOfAscendantHeir`, which reads
the side from the first step of the recorded lineage, or from the sex of the parent when the heirs
are the parents. The two rules agree whenever the two sides hold the same number of lines, which is
why the difference showed only in the rarer shapes of estate: three great-grandparents in three
different lines used to take a third each and now take a quarter, a quarter and a half. The field
`nParentsInLineage` of the heir record now holds the number of heirs on the same side, which is
what the share is divided by; nothing reads it, so it is there to be looked at in the debugger, and
its comment in `Declarations.pas` says so.

**Measured, thirteen cases in all, shares summing to one in every one.** Both of your examples come
out as you stated them: three grandparents give 0.2500, 0.2500, 0.5000, and seven great-grandparents
split four and three give 0.1250 four times and 0.1667 three times. Four great-grandparents on the
maternal side alone take a quarter each, the paternal side being empty. Two cases changed with the
new rule: three great-grandparents in three different lines, from a third each to 0.2500, 0.2500,
0.5000, and one paternal line of one plus one of two against a single maternal survivor, from
0.3333, 0.1667, 0.1667, 0.3333 to 0.1667 three times and 0.5000.

**Files touched.** `inheritance.pas`, `AscendantHeirs_2`, `allocateShareAscendantsHeirs_2` and one
constant, with the new `sideOfAscendantHeir` and the explanatory comment inside
`exploreAscendantHeirsTree_2`; `Declarations.pas`, the comment on one field; `Verification.pas`,
one identifier. The module has not been built in Lazarus.

## Inheritance: the referee of the two heir searches (N26, 30 September)

The module answers the question "who are this person's heirs" twice, by two searches written years
apart, and `checkHeirs` is the routine that compares the two answers. Its verdict goes to one
column of the individual kinship file in a run with `INHERITANCE` and `DEBUG` both on, and it is
the instrument for the two defects that are left, `N22` and `N24`. It was reporting agreement in
the one case that is plainly a disagreement, so it was hiding them.

**What was wrong, in five parts.**

1. The comparison started from agreement and contradicted itself only when the kin types of the
   second search fell outside the branch the first had named. The case where the first search
   found nobody and the second found heirs was therefore reported as agreement.
2. The two lists of heirs were compared by position, so the same heirs found in a different order
   counted as different.
3. The final branch could not be reached: the three tests before it, no heirs in the first and
   some in the second, then unequal counts, then equal counts, cover every case, so the message
   it wrote could never appear.
4. The first search answers with one branch of the kinship tree in `typeHeir`, and the partner is
   one of those branches, so a person whose heirs are the children could not at the same time be
   recorded as leaving a surviving partner who inherits. The succession rules the second search
   applies do give the partner a share alongside the descendants or the ascendants, according to
   `PARTNER_FIRST_HEIR` and `PARTNER_FULL_HEIR`. The two answers were therefore not comparable
   from `typeHeir` alone, which is the part of the fault you identified.
5. The two searches do not look at the same people. The first goes through the relatives of
   `gPossibleHeirs` who are kin of ego; the second looks at ego and at the kin types of
   `HEIRS_KINTYPES`. Every relative that only one of them examined was reported as a
   disagreement, which is a difference of coverage and not a difference of opinion.

**What was done.** One boolean field, `partnerCanInherit`, was added to the relative record beside
`typeHeir`, initialised in `Init.pas` where `typeHeir` is, and filled in `lookForHeirs` for every
relative that routine examines, before it enters the chain of branches. It holds the first
search's own partner test, so the partner is now reported whatever branch `typeHeir` ends up
naming, which is the smallest change that makes the two answers comparable. Nothing reads the field
except `checkHeirs`, so no simulated quantity changes.

The partner test of each search was taken out into a function of its own, `partnerCanBeHeir_1` and
`partnerCanBeHeir_2`, with the conditions unchanged: the first asks whether the last union ended at
the person's own age at death and the partner of that union was alive then, the second asks whether
the last union ended by the person's own death and the partner was alive then. The two state the
same condition in two ways, so `lookForHeirs` now reports a case where they disagree, as
`inhPartnerTestsDiffer`. `partnerHeir` and `partnerIsHeir_2` call these functions and behave as
before.

**Why the two partner tests were kept apart, and what the exact comparison rests on.** Traced on
30 September, so that it does not have to be traced again. When a union ends by the person's own
death, `copyWomanPartnershipInfoToWomanAsRelative` and
`copyWomanPartnershipInfoToManAsRelative` in `Kinship.pas`, at `4000` and `3947`, write the age at the end of that union
from the same stored value as the age at death, by assignment and with no arithmetic, and the age
at death is copied forward unchanged from one union record to the next in `FertilityRuntime.pas`.
The equality the first test makes is therefore exact, not an accident of rounding. Arithmetic does
enter the widowhood branch, where the age at the end of the union is the age at union plus the
duration of the partner's union, and a partner who died a moment before could in principle produce
a sum that rounds to the person's own age at death. In that case the first test's second
condition, that the partner was alive at the death, refuses it, which is what the comment on the
old dead branch of `partnerHeir` was about. So the two tests should agree everywhere, and
`inhPartnerTestsDiffer` should stay silent.

The reason for keeping both was not the comparison but the gates: the answer of the first search
goes into `typeHeir`, which `checkEgoIsHeir` reads as a condition in ten places, so replacing that
test could change results with nothing to say whether the change was right. Once a run of a few
thousand egos leaves `inhPartnerTestsDiffer` silent, the two can be collapsed into one, which is a
two line change.

`checkHeirs` was rewritten. It returns `kNotDefined` when either search did not look at the
relative, 1 when the two answers are compatible and 0 when they are not. It compares the heirs by
the identity of the person rather than by position; the set the second search's heirs must lie in
comes from a new `kinSetOfBranch`, widened by the partner when `PARTNER_FIRST_HEIR` and
`PARTNER_FULL_HEIR` say the partner shares with the descendants or the ascendants, or narrowed to
the partner alone when the partner takes everything. The list of the first search is checked as a
part of the list of the second and not as its equal, since the first fills its list only for the
relatives from whom ego inherits, and only with ego and, in one case, one of ego's parents. Each
kind of disagreement is now a check of its own: `inhHeirsFoundByOneOnly`, `inhHeirKinTypes` and
`inhHeirNotConfirmed`. The branch that could not be reached is gone, and with it one of the four
`writeAndWait` sites of the module.

**Files touched.** `Declarations.pas`, the field and its byte count; `Init.pas`, one line;
`Verification.pas`, four identifiers with their names, their descriptions and their kind, all four
failure points; `inheritance.pas`, `lookForHeirs`, `partnerHeir`, `partnerIsHeir_2` and
`checkHeirs`, with three new functions and `Verification` added to the implementation's `uses`.
The logic of the new routines was compiled and exercised on its own outside the project, with the
eight cases of the comparison, before delivery; the module itself has not been built in Lazarus.

**What to expect when you run it.** `inhHeirKinTypes` will speak on lateral heirs, and that is not
a fault of the referee: the first search names one branch of the lateral tree while the second
applies the rule of the degree, under which every lateral relative of the nearest degree inherits
together. A decedent with a living first cousin and a living grand-aunt gets two different answers.
The second search is the one that follows the rule. The `TODO` records what follows from that.

## Inheritance: the ancestor shared with a lateral relative (N24, 30 September)

**This one changes results.** It is the second of the two changes of the month in the inheritance
module that do.

**What was wrong.** When a lateral relative of ego dies, the module collects the people who could
be that person's heirs, and for some of those relatives it collects them from ego's side of the
family. It first asks the right question, through `commonAncestor`: which of ego's own parents is
an ancestor of the dead relative? It then threw the answer away and collected the children of both
of ego's parents whatever the answer had been.

The case that makes it wrong. A niece dies with no descendant, no living parent and no living
grandparent, so her aunts and uncles inherit, and they are the children of her grandparents. Ego is
one of them, so one of ego's parents is a grandparent of the niece. Not necessarily both: if ego
and the niece's father share only their father, then ego's mother is no relation of the niece at
all, and the children she had with another man share no blood with the niece under any rule set.
Those people were collected all the same, entered the heir list on the same footing as the true
aunts and uncles, and took an equal share of the estate. The same fault sat in the block for a dead
grand niece or grand nephew.

**What was done.** The answer of `commonAncestor` is now used, exactly as the first cousins block
of the same routine already used it: a side of ego's family with no ancestor in common with the
dead relative contributes nobody, and the children collected are those of the ancestor the two
actually share. A nil parent of ego is refused by the same test. One new failure point,
`inhNoCommonAncestor`, states the property that at least one of the two sides must answer, since
ego would not be a lateral relative of that kin type otherwise.

**The three call sites where the answer was not needed, and why they were left alone.** Of the five
places that call `commonAncestor`, only two collected from ego's side. The first cousins block, at
`inheritance.pas:1091`, always used the answer and is untouched. The aunts and uncles block, at
`1058`, and the grand aunts and grand uncles block, at `1148`, collect the children of the dead
relative's own parents, and every child of a parent of the dead relative shares a parent with it
and is therefore a blood sibling of it, the half-siblings included. No side has to be excluded
there, so applying the same filter would have wrongly dropped the half-siblings on the side ego
does not share. Those two blocks assigned the answer and never read it, which is what made the
whole thing hard to see, so the useless assignments are gone and a comment says why the list needs
no filter. Nothing about those two blocks changed for the simulation.

**Measured on a stub genealogy compiled outside the project with the real code of the four sites.**
With ego and the niece's father full siblings, both of ego's parents are grandparents of the niece
and both sides contribute, as before. With ego and the niece's father sharing only their father,
one side contributes where two used to, which is the repair. The two blocks that collect from the
dead relative's own parents still collect both of them.

**Files touched.** `inheritance.pas`, four blocks of `checkEgoIsHeir` and one new local;
`Verification.pas`, one identifier. The module has not been built in Lazarus.

## Nuptiality: the standard deviation of the schedule of ages at first union (N51, 30 September)

`RodTrussFirstUnion` builds the schedule of ages at first union and divides by the standard
deviation twice, and it recomputes the mean of the schedule it has just built by dividing by the
proportion ever in union. Either divisor could be exactly zero, and a zero raises `EInvalidOp`
under the range checks of `Defines.pas`.

**Where a zero could come from, and what was left of it.** Two of the three routes had already
been closed by earlier work. N53 holds both mean ages at first union at or above 14.64, one year
above the mean at which `std_Coale_Rodriguez_Trussel` returns exactly zero, so the function that
turns a mean into a standard deviation can no longer hand one over. N50 gave
`STD_DEV_AGE_UNION` a lower limit of 1, in the dialog and in the reader of a configuration file
alike, so the parameter cannot carry one either.

The route that was left is a stepped run, and it is live. `SpecialRuns` builds the standard
deviation itself, from `std_Logistic_Dani_2004` or `std_Campbell_Wood_1988` according to the fixed
parameter `stdUnionDanielOrCampbellWood`, halves it at the first step of a sweep over the standard
deviation, and writes it straight into `dp[stdnupt].value` in its innermost block, where no range
test stands in front of it. `std_Campbell_Wood_1988` is exactly zero for every mean at or below
about 15.32 years, while N53 holds the mean only at or above 14.64. A sweep over the mean age at
union that passes through the interval between those two therefore wrote a standard deviation of
exactly zero and divided by it. I had first described this entry as reachable only by hand editing
`STD_NUPT`; that was wrong, and the stepped run is the real case.

The second divisor, the proportion ever in union, is admitted as zero by the dialog and by the
reader, since `kMinEverInUnionProp` is zero. That is a modelling choice rather than an oversight: a
population in which nobody ever enters a union has no births either. The arithmetic still has to
survive it.

**What was done.** A floor, `kMinStdNuptSchedule`, declared beside `kMinNuptScaleFactor` at the top
of `Nuptiality.pas`, and a guard at the head of `RodTrussFirstUnion` that reports through
`stdNuptTooLow` and substitutes the floor when the standard deviation arrives at zero or below. The
guard sits at the division rather than at the places the value comes from, for the same reason the
guard of N29 sits in `CoaleFirstUnion`: this is the one routine every route passes through, its
four callers being `initStandardNuptiality` by way of `calcCelibacy_RT_woman` and
`calcCelibacy_RT_man`, `calcRepartnering`, and `calcNuptScaleFactorRT`. The standard deviation is a
value parameter, so the substitution is local to the call. A small but positive standard deviation
is left as the user asked for it: it builds a schedule concentrated on a few ages, which
`adjustTabNupt` then rescales, and that is a configuration to think about rather than an arithmetic
fault.

The floor is the companion of `kMinNuptScaleFactor`. The header of `RodTrussFirstUnion` records
that its parameters (1, 21.36, 6.583312236) build the same schedule as `CoaleFirstUnion` (10, 1, 1),
so a scale factor of one is a standard deviation of 6.583312236 years and the two are
proportional; the floor is that value taken at `kMinNuptScaleFactor`, which is 0.579 years, the
schedule whose mean lies one year above its starting age.

For the proportion ever in union: a zero is reported through `everInUnionZero`, the recomputation
of the mean is skipped rather than evaluating `0.0/0.0`, and the two rescalings that follow, in
`calcCelibacy_RT_woman` and `calcCelibacy_RT_man`, are skipped as well, since the table they would
rescale is all zeros and is already what it should be.

Each of the four functions that can produce a standard deviation now carries a note of its own
domain, which is what the entry asked for, since no single limit on the mean covers them all: the
Coale and Rodriguez and Trussell function is zero at 13.64 and mirrored below it by its absolute
value; Campbell and Wood is zero at and below 15.32 and bounded inside itself below that; the
logistic has no zero in the mean but is zero when its final level is zero; and `std_unionLinear`
returns whatever the two standard deviations the user gives interpolate to, zero included, and is
the one of the four with no caller.

**Measured, six cases, with the real `RodTrussFirstUnion` and `adjustTabNupt` compiled outside the
project.** An ordinary schedule, mean 21.36 and 95 per cent ever in union, gives densities summing
to 0.950000 and a recovered mean of 21.361, with nothing reported, which is the case that must not
change. Campbell and Wood at a mean of 15, standard deviation zero, now reports once and builds a
schedule summing to 0.950000 with a mean of 15.16 instead of stopping the run; the same halved at
the first step of a sweep behaves identically. A zero proportion ever in union leaves the densities
at zero, reports once, and divides by nothing. Both faults at once report both and do not stop. A
standard deviation of 0.9, small but positive, is left untouched and reports nothing.

**One thing noticed in passing, and not changed.** At the mean of the Coale standard, 21.36 years,
`std_Coale_Rodriguez_Trussel` returns 5.43, whereas the equivalence in the header of
`RodTrussFirstUnion` puts the standard deviation of that same standard schedule at 6.583312236, a
difference of about 20 per cent. The two are different parameterisations of the same family and
they ought to agree at the standard. It affects no result today, since only the function is used to
set a standard deviation from a mean, and the floor is insensitive to which of the two constants it
is derived from, but it is worth a look when you next read that routine.

**Files touched.** `Nuptiality.pas`, three constants, the head of `RodTrussFirstUnion`, the two
rescalings, and a note beside each of the four standard deviation functions; `Verification.pas`,
two identifiers. The unit has not been built in Lazarus.

**The documentation of the schedule was reorganised at the same time, on your instruction.** The
explanations of the schedule of ages at first union had grown up one repair at a time, each
carrying the number of the entry it came from, so they read as a record of the work rather than as
an account of the model. They are now one block at the top of the implementation of
`Nuptiality.pas`, headed "The schedule of ages at first union", which sets out what the table is,
the two parameterisations of the Coale and McNeil curve and how they meet, where each of the three
quantities comes from and what it has to satisfy, where the three guards sit and why, and the
domain of each of the four standard deviation functions. The constants below it carry one or two
lines each. Every routine that had a long comment, `boundMeanAgeUnion`, the difference between the
two mean ages, `CoaleFirstUnion` and `RodTrussFirstUnion`, keeps what is didactic about its own
arithmetic, most of all the account in `CoaleFirstUnion` of how a negative scale factor produces a
table that passes every test and is nonsense, and points at the overview for the rest. No entry
number is left anywhere in the unit. The constant block was recompiled outside the project after
the rewrite: every constant keeps its value and the three behaviours of the schedule are
unchanged. One comment in `Declarations.pas`, on `kMaxMeanAgeUnion`, still explains the zero of the
standard deviation function; it names no entry number and is left as it is.

## Four things the compiler had been saying all along (30 September)

The compile log of the whole project was read once, message by message. Most of what it reports
is either the ordinary noise of a large program (a unit in a `uses` clause for one type, a
parameter kept for the sake of a shared signature) or the deliberate consequence of a switch.
Four messages were not noise.

**A check that could never fail.** `FertilityRuntime.pas`, in `calcNbChildren`, read the woman's
age at the current cycle into `currAge`, whose type `FecundAges` is the subrange
`kMinAgeFert..kMaxAgeFert`, and then tested whether `currAge` was outside that same subrange. The
test could not report anything: with range checking on, which is how the project is built, an age
outside the bounds raises a range error on the assignment before the test is reached, and with
range checking off the two comparisons are constantly false. The age is now read into a plain
`longint`, `ageThisCycle`; the test is made on that; and the value is brought inside the bounds
afterwards, so that a run which is not stopped at the failure carries on with a legal index into
the fecundability tables rather than failing on the assignment. The check `chk_currAgeInFecundRange`
can now actually fire. On a correct run it does not fire, because the index was already inside the
bounds; what changes is that the guard is real.

**A function that never set its result.** `init_waiting_time_distribution` in `Fertility.pas` was
declared to return the median of the distribution (`): double; // return median value`) and never
assigned it, so a caller that read the value would have read whatever the return register held.
None of the six call sites read it: four in `DemographicRegime.pas` and two in `Nuptiality.pas`,
all of them statements. It is now a procedure, and its two unused local variables, `ind` and
`median`, are gone. The median can be recovered from `arrayDurationAcc`, which holds the
accumulated distribution, if it is ever wanted.

**`out` where the routine reads what it was given.** `ageChildren`, the table of children by age
of the mother and by order, was declared `out` in three places: the interface and the
implementation of `calcCompleteFertilityWoman`, and `fixedNumChildren`. The declaration was wrong
in each. `calcCompleteFertilityWoman` zeroes the table only when `param_newPartnershipLife` is
true; otherwise it keeps the counts of the earlier unions and adds to them, and `addChild` adds
to the cell rather than setting it. For an unmanaged array of `longint` the two modes generate the
same code, so no result changes, but `out` tells the compiler and the reader that the caller's
value is not used, which is the opposite of what happens. The three are now `var`, each with a
line saying why. `calcAgeChildrenTable` in `Kinship.pas` keeps `out`, because it does fill its
table completely.

**A directive inside a comment.** `Kinship.pas`, in the explanation above `individualKin_end`, had
the words "swallowed by `{$I-}`" written inside a brace comment, so the compiler saw a nested
comment and reported "Comment level 2 found". The braces are dropped from the quotation. Nothing
else changes; the message was harmless, but it is one line of noise fewer in the log.

**Two more parameters in the wrong mode.** `TUnionsType.copyMe` and `DumpCmdFile` both declared
`var` where the routine creates the thing it is asked for and never reads what the caller passed.
`copyMe` begins with `o := TUnionsType.Create`, and `DumpCmdFile` begins with
`outFile := TFileType.Create`. Both are now `out`. For a class reference the two modes generate
the same code, so nothing moves, and four "does not seem to be initialized" hints go with the
change: one in `FertilityRuntime.pas` and three in `ReadCmdFileUnit.pas`. The callers were checked
first: all four pass a local or a field that is unset at the point of the call, so no live object
is overwritten.

Also from the log, and not a code change: the Lazarus build was asked for `-vn-`, `-vh-` and
`-vi-`, which remove the notes, the hints and the informational lines, leaving the warnings and
the errors visible. The macOS minimum version, `-WM11.0`, was verified to be rejected as an
illegal parameter on a non-Darwin target, so it belongs in a macOS build mode or on the
Conditionals page rather than in the options shared by the three platforms.


## The inheritance module, documented (1 October)

`inheritance.pas` carried its own repair history. Every change of 30 September was still wrapped
in review markers, and the comments inside them were written for the reviewer of a bug rather than
for a reader of the program: they said what the code used to do and why that was wrong, which is
of no use once the fix is accepted. The same was true of the `// BUG` block on `N25`. All of it is
replaced by documentation of what the unit does.

**A unit header.** The module now opens with an account of what it is for: the two questions it
answers, the two algorithms that answer each of them and why both are kept, the order of
preference each applies, the succession rules as settled on 29 and 30 September with article 810
among them, which fields of the relative record each algorithm writes, what the two referees do,
and what is not modelled. The note on the English rules of intestacy that stood at the head of the
file is kept below it, marked as the source material it is, since it is the list the module was
first written against.

**Every routine.** All 87 of them carry a comment saying what they do, and the ones whose logic is
not evident from their name carry more: `possible_heirFound` and the year comparison it rests on,
`lookForChildHeir` and why it cannot go more than three generations down, the pair
`findHeir_childTree` and `findHeir_descendancy` as the place where representation is implemented,
`computeShareInheritanceTree` as the chain of multipliers that carries a share down a line,
`commonAncestor` and what a nil answer means, `checkEgoIsHeir` and the shape its blocks share, the
explore and allocate pairs of the second algorithm, and `Colaterals_2` and the rule of the degree.
Four section banners separate the first algorithm, the shared bookkeeping, the second algorithm
and the referees.

**The places where a bug was fixed** now say what the code does and why, with no reference to what
it did before. Where the reasoning is worth keeping, it is kept as reasoning: why only the side of
ego's family that has an ancestor in common with a dead collateral relative contributes heirs, why
the blocks that collect the dead person's own brothers and sisters need no such filter, and why
the ascendants are explored one generation at a time.

**`N25`** keeps its substance and loses its form. The comment above `lookForDecedents_Spain` now
documents an empty routine and a parameter that selects nothing, and points at the TODO for the
decision, instead of proposing a fix in place.

The markers are gone from the unit. Since the change is entirely in comments, it was checked
mechanically rather than by eye: both versions were stripped of comments, with string literals and
compiler directives preserved, and the remaining token streams are identical, 6576 tokens each.

## The two state files, moved out of the program's folder (1 October)

KinFert remembers two folders from one session to the next, the folder configuration files were
last read from and the folder results were last written to, in a text file of one line each. Both
sat next to the executable, as `KinFert ConfigDir.cfg` and `KinFert OutputDir.cfg`. `ReadStdPath`
and `WriteStdPath` in `LazMain.pas` were the only two places that computed the location, as
`ExtractFilePath (Application.ExeName)`.

**Why that was the wrong place.** On macOS the two files fell inside
`KinFert.app/Contents/MacOS/`. An application bundle is meant to be read only and signed:
replacing the bundle with a new build loses the two paths, and an application installed in a folder
the user cannot write to cannot save them at all. On Windows they sat in the folder of the program
itself, in plain view and of interest to nobody. And when that folder is shared between machines,
which is how this project is kept in step between a Mac and a Windows PC, each system overwrote the
other's file with a path that means nothing on the other.

**Where they are now.** In the folder each system sets aside for an application's own per-user
state, under a name that says which system wrote it:

| System | File |
|---|---|
| macOS | `~/Library/Application Support/KinFert/ConfigDir-macOS.cfg` |
| Windows | `%APPDATA%\KinFert\ConfigDir-Windows.cfg` |
| other Unix | `$XDG_CONFIG_HOME`, or `~/.config` when it is unset, then `KinFert/ConfigDir-Linux.cfg` |

and the same three with `OutputDir` in place of `ConfigDir`. Two files written by different systems
can therefore never be taken for one another, even if the state folder itself were ever put in a
synchronised location.

**What changed in the source.** Three functions new to the implementation of `LazMain.pas`:
`kinFertStateDir`, which computes the folder for the platform from the environment variable, with a
fallback for the case where it is unset; `stateFilePath`, which adds the base name and the platform
name; and `legacyStateFilePath`, which gives the old location. Two constants, `kStateConfigDir` and
`kStateOutputDir`, replace the four literal file names at the call sites, so the names now exist in
one place. `ReadStdPath` and `WriteStdPath` take a base name rather than a file name, and
`WriteStdPath` creates the folder on first use with `ForceDirectories`.

**Nothing has to be copied by hand.** When the new file is absent, `ReadStdPath` reads the old one
next to the executable and writes the new one at once, so the move is made on the first run after
this change and made only once. The old file is left where it is, and is never written again.

**Two incidental corrections.** The old `ReadStdPath` read straight into its `var` parameter, so a
file that existed but was empty replaced whatever the caller had already put there; and `readLn` on
an empty file was an unguarded input error. It now reads into a local variable, tests for the end of
the file first, and leaves the caller's value alone unless it has something to put in its place.

**How it was checked.** `LazMain.pas` cannot be compiled outside Lazarus, since TAChart reaches
`IDEOptionsIntf`. The three new functions and the two rewritten procedures were therefore lifted out
verbatim and compiled under FPC 3.2.2 against stubs for `TFileType` and `Application.ExeName`, in
the macOS, the Windows and the Unix branch in turn: no warnings and no hints in any of the three.
Run against those stubs they produce the paths in the table above, create
`Library/Application Support/KinFert` where neither level existed, read a legacy file and write its
path to the new place, and leave the caller's path untouched when there is no file or the file is
empty. Two things that check cannot reach, because only Lazarus can link the unit: that it still
compiles in place, and that `IS_MACOS` and `WINDOWS` are defined as expected in your project. On
each machine the first run after the change should find its two folders already set, which is the
sign that the migration worked.

## One fault counted three times, and two misleading lines (1 October)

A run of 1 October reported **3 verification failures** on the one line of the memo, while the
table at the end of the same run said **30 checks ran, 1 of them failed, 2 failures in all** and
**1 problem was reported through writeAndWait**. Behind all of those numbers there was one fault:
the range of groom birth cohorts was six years too narrow, and two unions of 518419 fell outside
it.

**Where the three came from.** The fault was caught twice over, by design, and then added up
once too often.

- `chk_kin_groomCohortRange`, in `addGroomsInfo`, sees each union whose implied groom cohort falls
  outside the range, so it counted two failures, one per union. That is right for an invariant:
  the report names the first cases and counting occurrences is how a reader judges the size of
  the fault.
- `reportIndexCoverage`, at the end of `initMotherhood`, summarises the same unions and says which
  constant to widen and by how much. It wrote that through `writeAndWait`, which records the
  message in the verification table under `chk_reportedProblem`. One more count, for the same
  two unions.
- `verificationFailures` then summed every entry of the table, `chk_reportedProblem` among them,
  giving 2 + 1 = 3, and the one line of the memo printed that. The table, meanwhile, subtracted
  the reported problems and showed them apart. The two disagreed by construction.

**What changed.** Three things, none of which removes information.

- `verificationFailures` now counts the checks only. Two new functions stand beside it:
  `verificationFailedChecks`, the number of checks with at least one failure, and
  `verificationReports`, the number of messages that came through `writeAndWait`. The three are
  documented together in the interface of `Verification.pas`, with the reason they are kept apart.
- The one line of the memo is built from those and follows the table exactly. It counts checks and
  not occurrences, since one invariant that failed twice is one problem: the run above now says
  **1 check failed (2 cases)**. A run with both kinds says `2 checks failed (5 cases) and 1 problem
  reported`.
- The groom range summary no longer goes through `writeAndWait`. It is written to the memo as an
  ordinary warning, with the same text, and the same text is attached to
  `chk_kin_groomCohortRange` as its note, through a new `setCheckNote`, so it appears in
  `verification.txt` under the check and beside the two cases the check kept. The red indicator is
  lit by the check, which is where the fault was seen, so nothing is lost by not routing the
  summary through `writeAndWait`. In the report a note is now labelled *note* rather than
  *measured* unless the check is a quantity against a target, where *measured* is what it is.

**Two lines of the same log that said something untrue.**

- `===== post-phase of simulateKinship lasted: 14 h, 35 min, 21 sec` in a run of one minute
  fifty-eight. Every other interim timer of `simulateKinship` is printed only when `TALKATIVE` is
  on, and `tStart_interm` is set only then as well; this one call was not guarded, so with
  `TALKATIVE` off it measured from an unset `TDateTime`, that is from 30 December 1899, and
  `stopTime` prints the hours, minutes and seconds of the difference. The result was the time of
  day. The call is now guarded like the others.
- `Searches for a mother: none recorded. These counts are filled while the kinship is built, so a
  run that built no kinship leaves them empty`, printed by a run that built ten thousand trees.
  The reason was the wrong one: the selected kin were ego, partner, children and grandchildren, so
  the run asked for no ancestors and never looked for a mother. The line now gives both reasons.

**How it was checked.** `Kinship.pas` and `Verification.pas` compile under FPC 3.2.2 with the
flags of `kinfert.lpi`, in the session container, with `Forms`, `Dialogs`, `LazFileUtils`,
`LazMain` and `LazUtiles` replaced by stubs, since this container's LCL is missing
`FastHTMLParser`, which `Clipbrd` needs. No diagnostic falls on any line written for this change
except four of the 836 instances of `Type size mismatch, possible loss of data`, a class this
project produces throughout under `-Cr`; a two-line test program shows the identical expression
shape produced the same warning before the change. `LazMain.pas` cannot be compiled outside
Lazarus, so the new block of `endSimulation` was lifted out and compiled against stubs of the
three counting functions, then run over six combinations of counts to read the line it builds in
each.

## The Children-Grooms tab: two maps of the pools, and a released build that says less (1 October)

Four entries of that tab drew the same measure, the share of searches answered from a cell other
than the one asked for. In an ordinary run that share is of the order of a twentieth of one per
cent, so three of the four charts were an empty frame with a sentence in the title, and one of
them, the mother search, had nothing to draw at all whenever the selected kin include no
ascendants. The one entry that carried information was the fourth, the unions the simulation
produced by cohort of the groom.

**What a released build now shows.** The first entry only. It describes what the pre-simulation
built, which is a result: a user who widens a cohort range reads it to see what the change did.
The rest describe the machinery, so they are offered only when `gRunFromIDE` is true, the same
test the debugger traps and the dump files use. The entries of the list are now identified by a
number of their own rather than by their position, since the list is shorter outside the IDE.

**Two maps, in place of the three charts that said nothing.** The two indexes the kinship
reconstruction draws on are now drawn cell by cell, a cell being one cohort by one year of age:
the age of the mother at that birth for the birth index, the man's age at union for the bride
index. Three exclusive colours: blue where the index has candidates no search ever used, green
where searches drew from it, with the shade saying how often, and red where a search asked for a
cell and found it empty. The shade is logarithmic within each colour, so that a cell with one
candidate is visible beside one with ten thousand. The picture answers the question the tab exists
for, and the earlier charts answered only as a percentage: where the model went looking for
someone, was there anyone there.

The mother map has no red by construction. The birth index is keyed by the year of the birth
alone, so a search that finds nothing moves to a neighbouring cohort rather than to another cell
of the same column, and that move is already counted by cohort.

**The data.** Five arrays in `Kinship.pas`, each a cohort by age table of longints, some tens of
kilobytes each. The supply cells are filled in the main thread as the indexes are built; the
chosen and the missed cells are filled from the worker threads while the kinship is built, so they
are incremented atomically through one bounds-checking helper, `countPoolCell`. They are
statistics and nothing reads them back into the model. They outlive the indexes themselves, which
are freed at the end of the run, because the graph window is opened afterwards.

**The drawing.** A `TUserDrawnSeries`, which hands a canvas and leaves the drawing to the unit, so
one pass over the cells fills one rectangle each. Such a series carries no points, so the extent
of the chart comes from an `OnGetBounds` handler rather than from the data.

**What could not be checked.** `Kinship.pas` compiles with the new counters, under FPC 3.2.2 with
the flags of `kinfert.lpi` and the stubs described above, and adds no diagnostic of its own beyond
three more instances of the `Type size mismatch` class this project produces throughout under
`-Cr`. `LazGraph.pas` cannot be compiled outside Lazarus at all, since TAChart reaches
`IDEOptionsIntf`, so the drawing is the first change of this audit that rests on reading alone.
Every symbol it uses was checked against the installed TAChart and LCL sources: `TUserDrawnSeries`
and its two events, `TDoubleRect` and its fields, `GraphToImage`, `RGBToColor` and the four
argument form of `FillRect`. The counts of `begin` and `end` match, fifteen of each. What remains
possible is a compile error of the ordinary kind on the first build in the IDE.

## Dead code removed, and two switches that could not be turned on (1 October)

Everything below was found by counting references: every global declared in `Kinship.pas` and
every routine of `Kinship.pas` and `LazGraph.pas` was looked up across all the live sources, with
comments and string literals stripped so that prose could not pass for a use.

**Removed because nothing reads them.**

| | |
|---|---|
| `g_RangeGroomsForBrides_Nb`, `_Info`, `_NotFound` | Grooms classified by the bride's cohort and age at union, the mirror image of the index that is in use. Declared with a comment and touched nowhere. The compiler had been saying so, with three notes a build |
| `gChildLookupsSeenByGen`, `gChildLookupsClampedByGen` | The lookups for a mother split by generation: two declarations, four atomic increments in `lookInChildrenRange` and a reset loop. They fed the per-generation lookup charts, which went when the Children-Grooms tab was rebuilt. The three scalars beside them, `gChildLookupsSeen`, `gChildLookupsClamped` and `gChildClampWorst`, are reported and stay |
| `gNumEgoMen`, `gNumEgoWomen`, `gChildrenEgoMen`, `gChildrenEgoWomen` | Four counters incremented as each ego tree is built and zeroed at the start of a run, read nowhere. They were also incremented without an atomic operation from the worker threads, so they were a race as well as a waste |
| `aliveAtAgeWithPartner`, `scanChildrenList` | Two routines never called. The second says in its own comment that it is for looking at a children list in the debugger, and it is still in the history if that is ever wanted |
| `cLabelsX`, in `LazGraph.pas` | The axis label helper of the removed charts, nineteen lines. `cLabelsXSpan`, which replaced it, is the one in use, and its comment no longer refers to a function that is not there |

**Two switches that could not be turned on, now settled.**

`gCheckRelativesMax` was never assigned anywhere, so `gCheckRelativesCount <= gCheckRelativesMax`
was false from the first ego and the block it guards, which dumps a tree and its kin counts, was
reached only when the consistency test above it had already failed. The variable is gone and the
test now reads `if errorKin then`. Nothing is lost: the two lines below it dump the trees of a
range of egos chosen in the Utiles window, which is the same facility with a way of setting it.

`gChildShortfallBelow` and `gChildShortfallAbove` were accumulated and never reported, which is
what made them look like dead counters. They are reported now, in the index coverage line, and
only where they mean something. Under a stable population the birth index covers one cohort on
purpose and almost every child is born outside it, so the share says nothing and the line says so,
as before. Under variable regimes a child born outside the range is a child the kinship
reconstruction can never pick, and the line now says by how many years the range would have to
widen, below and above, to take them all.

**What was left alone.** `gStateBrides`, `gStateMothers` and `gStateYearUnions` are filled on every
lookup and read only by two commented-out lines of `writeStates`, and `lookInMothersRange`, which
is never called, is the only thing that ever read the second of them. `checkKinship`, which counts
the relatives on a tree and compares the total with the count the caller holds, has its only call
inside a commented-out block. Both are kept at your request: the first could be drawn again, and
the second is a real invariant better revived as a check than deleted. `g_RangeYearUnions*`,
`g_RangeBrides*` and `CAMSIM_RangeBirths*` are not dead at all; they belong to the alternate bride
and mother algorithms that `MOTHER_ALGORITHM` reaches.

**How it was checked.** `Kinship.pas` compiles under FPC 3.2.2 with the flags of `kinfert.lpi` and
the stubs described above. The removal subtracts diagnostics and adds none: four notes and two
warnings fewer than before it, and the one note it did create, an unused local left behind by the
reset loop, was removed with it. The deletions carry no review markers, since a marker has nowhere
to sit once the code is gone; the two changed regions carry them as usual, and this entry is the
record of what went.

## DemoCare: an empty status column, and a reader that fell over a file name (1 October)

**The status column was empty in every row.** A DemoCare file carries the educational level in its
`status` column, and `EDUCATION` defaults to none, under which `edStatus` returns an empty string
for everyone. A file written that way is of no use to DemoCare, and nothing said what was missing.

The mode is now forced to **stochastic** when, and only when, the individual kinship file is on,
its format is DemoCare, and `EDUCATION` is none. The stochastic mode is the right one to force
because it is the only one that needs no input of its own: the other two read the `EDU_` and
`EDUPARTNER_` distributions by cohort from the cohort file, and a run without such a file would
either draw every person from a neighbouring cohort's distribution or leave the status empty after
all. A mode the user chose is never overridden, and a line in the log says what happened and how
to choose a better one, so a run cannot change the meaning of its own output in silence. The test
sits in `initGeneral`, beside the line that already names the stochastic mode when it is in force,
so it covers a run started from a command file as well as one started from the window.

**`Check DemoCare` failed with 'fert is not a valid number'.** `lookForCohortInName` read the
birth cohort of the egos from the fourth to the seventh character of the file name, which assumes
that every name begins with exactly three characters and then the year. Any other name reached
`StrToInt` with something that is not a number: a file called `V14fert2000.txt` failed on the word
`fert`, and the window reported the exception with no hint of what was wrong.

It now takes the first run of exactly four digits that reads as a year, wherever it sits in the
name, and returns `kNotDefined` when there is none. The caller says so instead of stopping, and
what it says depends on the layout, because the cohort is needed only by the short one: the
extended layout carries a cohort column and a name without a year costs nothing there, while the
short layout has none, so the read goes on with the default cohort and the log says that the ages
and the distances between generations are right while the absolute years are wrong by the
difference.

**Also settled on the way.** The three educational levels are `B`, `M` and `A`, from the lowest to
the highest, the initials of the Spanish words, and every mode uses the same three, so the status
column means the same thing whichever mode wrote it. The difference between the modes called
*Individual* and *Intrafamily* on screen is the family and nothing else: both draw from the
distributions observed by cohort and sex, and only the second lets the level of one member of a
family depend on another's. That was one of the ten open questions of the manual and it is now
§8.5, with a table of the four modes and what each one needs as input.

**One thing that does not exist and might be wanted.** There is no correlated mode that works
without observed data. A family correlation needs modes 2 or 3, which need the `EDU_` columns in a
cohort file; the mode that needs nothing, the stochastic one, draws every person independently. A
fourth mode, a family correlation on top of a uniform distribution, would be a small addition if
the DemoCare files are to carry a plausible family structure of education without a cohort file
behind them.

## A fourth education mode, and names that say what the modes are (1 October)

The education mode answers two questions at once, and the list of four on screen said only half of
each. The level comes either from the three levels with equal chances, which needs no input, or
from the distribution observed for the person's cohort and sex, which has to be in the cohort file.
Separately, the family is either taken into account or not. Written as a square:

| | the family does not count | the family counts |
|---|---|---|
| **equal chances** | 1, stochastic | 4, stochastic with family |
| **observed levels** | 2, observed by cohort | 3, observed with family |

The fourth corner did not exist, so a run without a cohort file could have no family correlation at
all. That is the corner a DemoCare file wants most: the levels inside one family should resemble one
another even when there is no observed distribution to draw them from.

**`eduStochasticFamily`, value 4.** With probability `kEduFamilyCorrelation` a person takes a level
already in the family, and otherwise one of the three levels with equal chances. The level taken is
the partner's for a partner, and the level of one of the two parents, chosen at random, for a person
whose parents are both in the network with a status of their own. Anyone else, which means a person
at the top of a line of descent, is drawn with equal chances.

The marginal distribution is exactly uniform in every generation whatever the correlation, since
copying a uniform level and drawing one with equal chances both give a uniform level. The mode
therefore adds association inside families and changes nothing else, so a departure from a third in
the totals of a run is sampling noise rather than an effect of the mode. At the default correlation
of one half, a child carries the level of one of its parents two times in three, against one time in
three under independence. The correlation between partners is weaker than the one between parent and
child, because `giveEdStatus` gives a person's two parents a level before the person but does not do
the same for a partner: when the partner is reached first there is nothing to copy. Making the two
symmetric would change `eduIntraFamily` as well, so it is left as it is and said in the comment.

`kEduFamilyCorrelation` is a constant in `Declarations.pas` rather than a parameter, because the mode
exists to give a file a plausible family structure and not to reproduce a measured association.
Promoting it is one entry in `Init.pas` and one line in the configuration reader.

**The names on screen.** *Individual* and *Intrafamily* became *Observed by cohort* and *Observed,
with family*, beside *Stochastic* and the new *Stochastic, with family*, so that the four read as the
square they are. The values a configuration file carries are unchanged, so an existing file reads as
it did.

**The DemoCare default.** The mode forced when a DemoCare file is written with the education mode
unset is now the new one rather than plain stochastic, since a plausible family structure is the
point of forcing anything at all. The log line says which mode was set and why.

**How it was checked.** `Declarations.pas`, `EducationalLevel.pas` and `Init.pas` compile with the
flags of `kinfert.lpi` and the stubs described above, and the diagnostics are identical to the build
before them. `ComponentHelper.pas` reaches the LCL and is not in that set: its two changes are a
fifth entry in the list of the combo and a fifth case label beside it.

## Crashes, hangs and dead ends

| | |
|---|---|
| **G1. The log window could hang a whole run, on an ordinary path.** `MemoWriteLnExec` in `LazMain.pas` began `s := myLine + s` and never emptied `myLine`, which only the constructor and `ClearLog` do. After any `memoWrite` without a line feed, and `Kinship.pas:6022` makes one on a normal run, every later line carried the same prefix. The test `if (s = kEndThreadMessage)` could then never match, so `memoWriting` was never set false and the worker thread spun for ever in `while (KinFertForm.memoWriting) do ;` at `LazMain.pas:856`. The run never finished, one core stayed at 100 per cent, `SaveLog` never ran, and every button was dead, since each begins `if gSimulationRunning then exit` | `myLine := ''` immediately after the line that consumes it. `myLine` is written in exactly two other places, the constructor and `ClearLog`, and accumulated in one, `MemoWriteExec`, so the clear belongs at the point of consumption and nowhere else. Nothing else in the unit reads it | 
| **N42. Each init thread seeded its own generator from inside `Execute`.** `initRandomized` goes through the run-time library's `random()` and so through the global `RandSeed`, with no lock, which the comment on that routine in `RandomNumbers.pas` forbids from a worker. Two threads seeding in the same moment could be handed the same seed, and two cohorts then received the same fertility schedule, which made them duplicates of each other. Reached with `MULTITHREADING` and `MULTITHREADING_INIT` both on | Seeded in `TDemRegInitThread.Create` instead, with `initWithSeed (nextThreadSeed)`. That constructor runs on the main thread, since the pool loop creates every init thread before starting any of them, and `nextThreadSeed` hands out one distinct seed per call. It is the correction already made in `Kinship.pas` in round 3, now in the one place that still had the old form. Test it with V23: no two cohorts may share a seed |
| **N43. The thread pool loop could not end on the flag it set, and started a thread twice.** `allThreadsDead` was set true before the loop over the threads and false on its first pass whatever the state of that thread, so `until (nActiveThreads <= 0) or (allThreadsDead)` could only end through the count. And a thread was started when its state was `thread_suspended`, while the state became `thread_active` inside `Execute`, that is only once the system had scheduled it: a thread started on one pass and not yet scheduled was still `thread_suspended` on the next, was started a second time and counted twice, so `nActiveThreads` could not return to zero and the loop spun. `G11` was the same fault seen from the other side | `allThreadsDead` is now set false only for a thread that is not dead, which makes that half of the exit test work, and the state is set to `thread_active` by the pool loop itself, on the main thread, immediately before `start`. The field then has one writer instead of two, and `nActiveThreads` stays equal to the number of occupied slots, which is what the search for a free slot below it assumes. The line in `Execute` is gone. The `WaitFor` and `Free` loop after the pool loop is unchanged. The loop still waits by spinning rather than sleeping, as it was written |
| **N45. The trailing zero strip could eat a whole number, or read past the end of the string.** `doubleToMinStringHelper` removed trailing zeros with no test that a decimal point remained. At the shipped `FLOATING_POINT_DIGITS` of 3 nothing was wrong, since `floatToStrF` then always writes a point. At 0, verified by running FPC 3.2.2: 100 was written as `1`, 1000 as `1`, 20 as `2`, and 0.23, 0.1 and 0.0, all written as `0`, left the string empty and then read `Result [0]`, which raises `ERangeError` under the range checks of `Defines.pas`. The dialog offers 1 to 10, so a value of 0 or below reached the program only from a configuration file, whose reader applied no range test of its own until N50 was fixed on the same day | The strip now runs only while the string still contains a decimal point, and the test that removes a trailing point also covers an empty string. Verified against the old form over 100, 20, 1000, 12.34, 1.5, 0.23, 0.1, 0.0 and -0.5 at 0, 1 and 3 digits: identical at 1 and 3, which is the whole range the dialog allows, and correct rather than destructive at 0. The separator is the point and not the one of the locale, since `Declarations` and `Init` both set `gFormatSettings.DecimalSeparator` to `'.'` |
| A fallback thread-cleanup loop that **could never exit** and read fields of objects the RTL may already have freed | Deleted. `TSimulEgoTreeCleanUp` already does the work on the normal path, and a fallback that hangs the program is worse than none |
| **46 debugger traps that never fired.** The idiom falls back to `assert(true, ...)` on ARM, and `Assert` raises only when its condition is false | On your Apple Silicon Mac every one of them was a silent no-op, including several in exception handlers that swallow the exception and fall through. Now `assert(false, ...)` |
| **Division by zero** in `writeInfoParents` for a cohort in which no woman was simulated | Guarded |
| **One blank line rejected a whole cohort file**, although the first pass over the same file tolerates blanks | Fixed |
| The inheritance warning fired **once per missing kin type**, up to 21 times per cohort per replicate | One message now lists them |
| **N32. An exception in `endBySeparation` left the fate of a union to two undefined values.** `aleaSeparation` and `separationRisk` were assigned inside a `try`, and the handler reported the exception and then let execution continue past the end of the block, where the two are compared to decide whether the union ends. If the exception fired before or during those assignments, both held whatever was on the stack. The likely source was the index: `monthly_risk_separation` runs from 0 to `kMaxDurationUnionInMonths` and the duration was not bounded, and `relRisk_separation_children_duration` runs from -11 months, the age of a child conceived before the union, and the age of the youngest child was not bounded either | Both variables are now set before anything can go wrong, to the pair that means the union does not end, a risk of zero against a draw of one; the handler leaves the function instead of falling through; and both indices are brought to the nearest cell the table holds, reported as `separationIndex`. Reproduced at reduced scale: with a true separation risk of 0.10 and an out of range duration, the old shape separated 1000 unions out of 1000, the new shape none, and both agree on every duration inside the table. No draw is added or removed on either path, so the sequence of random numbers is unchanged |
| **N37. The person memory manager allocated about 800 MB before anything was known about the run.** `TPersonMemoryManager` stores people in a three level array so that it can grow a chunk at a time instead of resizing one large block. The constructor did not do that: it called `setLength (personList, nw_level1, nw_level2, nw_level3)`, which allocates every sub-array of all three dimensions at once and zero fills them, so with no argument it took 100 x 100 x 10000 references, about 800 MB on a 64 bit build, resident rather than reserved because the zero fill writes every page. Two managers were created this way in `initMotherhood` before the number of people was known. Two other variants stood in the file under `CHANGE_IN_MAY2024`, undefined in `Defines.pas`, and could not be used: the define paired the constructor that allocates only `personList[0,0]` with the `addPerson` that allocates only when the first index passes `nw_level1`, so nothing ever created `personList[0,1]` and the ten thousand and first person wrote into a zero length array. Pairing that constructor with the other `addPerson` instead, which is what appears to have been intended, fails later for a second reason: `countLevel2` is never reset when the first index advances, so the first chunk of the second block is the last one allocated. Both failures were reproduced at reduced scale, at exactly the predicted persons | The constructor now allocates nothing, and `addPerson` creates each level the first time a person falls in it, reading the lengths of the arrays rather than keeping counters beside them. `countLevel1`, `countLevel2` and `nw_level1` are gone, the first dimension grows without limit so nothing can be lost, and `nPersons` is incremented after the person is stored rather than before. `approxSize` no longer sets a capacity, only the chunk size, and the two calls in `initMotherhood` therefore need no count. The `CHANGE_IN_MAY2024` branches are removed. A manager now costs one chunk per `nw_level3` people and nothing else |
| **N29. The scale factor of the standard nuptiality schedule could be zero or negative.** `CoaleFirstUnion` at `Nuptiality.pas:840` divides by it three times in one expression. Its four callers in `initNuptiality`, at lines 657, 661, 679 and 683, compute it as `(mean - ageMin) / 11.37`, and nothing keeps `mean` above `ageMin`: a configuration in which men enter unions on average about five years younger than women makes it zero or negative. At zero this raised `EZeroDivide`. Below zero every density comes out negative, and so does their sum, so `adjustTabNupt` divides the total wanted by a negative sum and the two negatives cancel: the table ends up entirely non-negative and summing to exactly the total asked for, passing every test that could be made of it, with all of the mass on the first age of the schedule. At a factor of minus one year the table is 1.0 at `kMinAgeUnion` and zero everywhere else, that is, every woman enters a union at the youngest age the model allows. Verified numerically | Guarded in `CoaleFirstUnion` itself, which `calcNuptScaleFactor` and `calcCelibacy` are the only two callers of, so one test covers every route to the division. A factor of zero or below is reported as `scaleFactorTooLow` and replaced by `kMinNuptScaleFactor`, the factor of a schedule whose mean lies one year above its starting age. The test was first written as a floor at that same one year, which was wrong: `mean` is a double, so the four sites can legitimately produce any positive value, and a configuration whose two mean ages at union differ by a little over four years reports a factor of 0.073 on every call. The test is now on zero and below only, which is what N29 was about. A small positive factor builds a schedule that is computable but heavily compressed, and distorted by being read at whole years: at a factor of one year the integer ages already hold 0.87 of the mass and at half that 0.29, the rest falling between the years, so `adjustTabNupt` rescales a near spike. Bounding the two means so that this cannot arise is N53, done on 17 September |
| **N53. Neither mean age at first union had a range of its own.** The two means arrive in `initStandardNuptiality` from the demographic regime and the whole nuptiality schedule is built from them at once. The only range applied to them was the one the dialog applies at `LazConfig.pas:489` and `506`, which is the range of an individual age at union, 10 to 59 for women and 10 to 69 for men. That range is deliberate and stays as it is, but a mean cannot take the whole of it. `std_Coale_Rodriguez_Trussel`, the function that turns each mean into the standard deviation of its schedule, is `sqrt (43.34 * abs (mean - 13.64) / 11.36)`: it returns exactly zero at a mean of 13.64, which `RodTrussFirstUnion` then divides by twice, and below that the `abs` mirrors the mean, so a mean of 12 silently takes the standard deviation of a mean of 15.28. A second route, found on 17 September: the difference between the two means, men less women, is the whole of the scale factor of the schedule of ages at union of men, which is `(meanDiffSex + 5) / 11.37` for every age at union of women above 19. At a difference of -4 years that factor is 0.088, at -5 exactly zero, and below that negative | Each mean is now tested where it is set, at all four sites, before anything is computed from it, against `kMinMeanAgeUnionSchedule` to `kMaxMeanAgeUnionSchedule`. The lower end, 14.64, is one year above the zero of the standard deviation function, where that function returns 1.95 years; the upper end, 40, is a modelling judgement rather than a property of the schedule, set in one place so it can be changed in one place, and it keeps the two fixed age paths inside the arrays they index with `trunc (mean)`. A mean outside the range is brought to the nearest end and reported as `meanAgeUnionRange`. The difference between the two means is reported as `meanAgeUnionDiff` when it is at or below -5, and is otherwise left exactly as the two parameters make it: at and below -5 the arithmetic is already caught downstream by the guard of N29, so repairing it a second time here would put two different substitutions on one fault. The literal 13.64 inside the standard deviation function is now the constant that sets the lower end, with the same value, so the two cannot drift apart. `LazConfig` is untouched. Neither check fires on a configuration whose means lie inside the range, so no result changes; your own configuration, whose two means differ by about 4.2 years, triggers neither |

## Output and configuration

| | |
|---|---|
| **N50. The limits the dialog applies never reached a run started from a configuration file.** `LazConfig`, `LazOutput` and `LazLowlevel` pass the acceptable range of each field to `CreateComponentChange` as bare arguments, for example `kIsInteger, 100, 1000000` for `NWOMEN`, and none of it reached `readValue`, which accepted whatever `val` could parse. A configuration file could therefore set `FLOATING_POINT_DIGITS` to 0, which N45 shows writing 100 as `1`, `NWOMEN` to 50, `PROP_WOMEN_AT_BIRTH` to 1.2, and so on, every one of them refused by the dialog | The range now sits on the parameter object. `GenericName` carries `hasRange`, `minValue` and `maxValue` with a `setRange` that only stores a range whose ends are in order, and `LongintName.readValue`, `DoubleName.readValue` and `DoubleCumulName.readValue` test the value against it: an out of range value is reported by name, with the value and the range, the parameter keeps its default, and a non zero code is returned, so `checkCode` refuses the file exactly as it refuses a malformed value. The ranges come from one table, `kParameterRange` in `Declarations.pas`, holding the 41 parameters that have a range in the dialog and that are read as a single value, transcribed from those `CreateComponentChange` calls and checked name by name against the parameters they name. `applyParameterRanges` gives them out at the end of `initCmd`, which every path calls before a configuration file is read, and at the end of `DemographicRegimeSettings_initialState`, so that a cohort created while a cohort file is read carries its ranges too; under `TALKATIVE` a name in the table that no parameter answers to is reported. Tested with a small program on this build: in range accepted, out of range and malformed both refused with the default restored, and a parameter the table does not name read as before. `LazConfig` is untouched and keeps its own copy of the numbers for now, which is where a range is stated to the user; four fields whose dialog range covers a whole array, `APRIORI_PPR`, `EFF_STOPPING_CONTRACEP`, `PROP_USING_SPACING` and `WAITING_TIME_SPACING`, have readers that take a row at a time and are not covered | **Completed on 18 September, one set of numbers.** Every limit is now a named constant in a new block of `Declarations.pas`, headed by a note saying that these bound an input and are not axis bounds, so a constant that sizes an array is never used as an input limit and the reverse. `kParameterRange` names those constants, and so do all 47 `CreateComponentChange` calls of `LazConfig`, `LazOutput` and `LazLowlevel`, which no longer carry a number of their own: 43 of them passed the limits as their last two arguments and four array fields passed them before `maxValueShown` and `maxValueDataset`. Every value is the one the dialog applied before, so the dialog and a configuration file refuse exactly what they refused, and a disagreement between the two is no longer possible to write. Where a different limit looks more defensible the line carries a **Claude suggestion** and nothing is changed; those are listed in the TODO. One rename came with it: the local constant of `std_Logistic_Dani_2004` in `Nuptiality.pas`, which you had moved into that function under the name `kMinMeanAgeUnion`, is now `kCentringMeanLogistic`, since it is the mean the logistic is centred on and would otherwise hide the new limit of the same name. The three dialog units compile only in Lazarus, so that part is unverified here; `Declarations.pas` and `Nuptiality.pas` compile clean, and the reader was tested again afterwards |
| **N19. The education columns of the cohort file described tables the run did not use.** The three tests that choose which table to dump were shifted by one: `eduEgo` was written for `EDU_STATUS` stochastic, `eduEgoPartner` for the cohort mode and `eduEgoPartnerChildren` for the intra-family mode, while what the modes read in `EducationalLevel.pas` is no table at all for stochastic, which draws a third for each level (N20), `eduEgo` for the cohort mode, and all three for the intra-family mode. The file stayed self-describing, since the header repeated the same tests and the reader matches by column name, so values read back into the table their name gives; what was wrong is that a cohort file never carried the parameters of the run that wrote it | Both writers now follow the modes: nothing for stochastic, `eduEgo` for the cohort mode, and `eduEgo`, `eduEgoPartner` and `eduEgoPartnerChildren` for the intra-family mode, with the header in the same order. **The column set of the cohort file changes for all three modes.** A file written by an earlier version still reads correctly, because the reader goes by the names in its header. A file written in one mode and read in another now carries only the columns the writing mode used, which for the stochastic mode is none, where before it carried `eduEgo`; if you would rather the file always held all three tables, which would make its format independent of the mode, that is a one line change in each of the two writers |
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

**N10, the net reproduction rate (18 September).** The entry reported the rate computed with the
constant 0.488 in place of `PROP_WOMEN_AT_BIRTH`. `FertilityRuntime.pas:3187` now reads
`tnr := tnr + Total_NetFertility * pDemReg^.dp[propWomenAtBirth].value`, so the defect is gone. The
only other 0.488 left in the program are the parameter's own default, in `DemographicRegime.pas:145`,
and a local initialisation in `sexAtBirth` at `Mortality.pas:414` that the next line overwrites with
the parameter, so neither is a second copy of the fault.

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
