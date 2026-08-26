# KinFert pre-release audit, second pass: the demographic engine

Date: 25 August 2026. Companion to `KinFert-PreRelease-Audit.md`, which covered the individual-file output path. This pass covers the units that were not read then.

## Scope and method

Units read in full: `DemographicRegime.pas`, `StablePop.pas`, `Fertility.pas`, `FertilityRuntime.pas`, `Nuptiality.pas`, `Parenthood.pas`, `Mortality.pas`, `EducationalLevel.pas`, `inheritance.pas`, `RandomNumbers.pas`, `Memory.pas`, `mothersInfoList.pas`, and the `initMotherhood` phase of `Kinship.pas`.

Six independent reviews, one per area. Seven of the highest-impact findings were then re-read against the source by hand and are marked **verified**. The rest carry the reviewer's own rating. Anything a reviewer could not trace is stated as such rather than asserted.

This pass found substantially more than the first one, and several findings affect published results rather than convenience. The three I would act on first are N1, N3 and N4.

---

## 1. Results that are wrong today

### N1. Parameter sweeps do not sweep. **Verified.**
`SpecialRuns.pas:53-176`.

Two independent defects in the same loop nest.

The stepped value is computed from `RP.indAgeUnion`, which is assigned nine lines later:

```pascal
for indAgeUnion := 1 to g_GENPARAM.RUNTIME[nStepsUnion_mean].value do
begin
    ...
        mean := (pDemReg^.dp[meanAgeUnionWomenLow].value) +
            ( RP.indAgeUnion - 1) * (...High - ...Low) / ( ...value - 1 );
    ...
    RP.indAgeUnion := indAgeUnion;          {  <- assigned only here  }
```

Every step therefore uses the previous iteration's index, and on the first iteration whatever was left from the enclosing loop. The same pattern at lines 78/82, 90/94, 112/116 and 128/132. Only the amenorrhea loop assigns before it reads.

Worse, the multiplicative steps read their base from the parameter that the previous step already overwrote, because the restore from `pDemReg_mem` happens in the innermost loop, after the outer loops have read. For separation, step 1 computes `base × 0 = 0` and writes 0 back; step 2 then reads 0. **The separation sweep and the contraception-after-union sweep collapse to zero after the first step and never recover.** The amenorrhea sweep accumulates its increments instead.

Consequence: anyone who has run `NSTEP_SEPARATION` or `NSTEP_CONTRACEPTION_AFTER_UNION` has been comparing identical parameterisations. This is the finding I would fix first, because it silently invalidates a whole class of results rather than perturbing them.

### N2. Infant death shortens the birth interval by roughly a whole gestation.
`FertilityRuntime.pas:773-828`.

`month` is counted from conception; it is seeded at 10, that is 9 gestational months plus one, and its return value is added to the month of conception. `maxMonthDeathChild` is the child's age counted from birth. The two are combined directly:

```pascal
LivingBirth := min (month, maxMonthDeathChild + 1);
```

so quantities whose origins are nine months apart are compared. The correct form adds the gestation: `min(month, kLivingBirth_durationPregnancyInMonths + maxMonthDeathChild + 1)`.

A child who dies at one month gives `LivingBirth = 3`, while `monthEndPregnancy` was set to conception + 9. The mother returns to the susceptible state six months before the child she is carrying is born, and the next live-birth interval can be six months.

This matters demographically because it is exactly the mechanism the model exists to represent: death of the suckling, early resumption of ovulation, shorter interval. In a natural-fertility high-mortality regime 15 to 25 per cent of births are followed by an infant death, so the effect is not rare. Simulated fertility is biased upward and the birth-interval distribution gains a spurious mode.

Degenerate case: `ageDeathChild = 0.0` exactly returns -1 from `ageToLunarMonths`, giving `LivingBirth = 1`, and that child's `monthFecundation`, `ageMotherAtFecundation` and `monthNewOvulation` are never assigned.

### N3. `endUnion` is never set to TRUE, so the age at end of union records the last separation drawn, not the first. **Verified.**
`FertilityRuntime.pas:639, 701, 910, 941, 1099, 1118`.

The flag is declared, initialised to FALSE twice, tested in three loops, and assigned TRUE nowhere in the unit. I grepped for every form. The loops that were meant to stop at union dissolution never stop.

The damage is at line 646:

```pascal
ageDurationEvents.ages[le_endUnion, woman] := lunarMonthsToAge (currMonth);
```

an unconditional overwrite, unlike the sibling assignments which use `min`. Because the loop keeps running, a separation is drawn every month until the end, and each success rewrites the age at end of union to a later date. One loop runs from the end of fecund life to the death of the man, so 40 or more years of monthly draws.

Downstream: the recorded age at separation is systematically too late; it feeds the individual file, `finalPartnershipStatus`, and the child-pruning loop, so children conceived between the first and last "separation" survive the prune and inflate fertility for separated women.

### N4. Heterogeneity in fecundability is applied as a 12 per cent coefficient of variation instead of a standard deviation of 0.12. **Verified.**
`Fertility.pas:340-371`.

```pascal
gMean_fecundability := mean;
gStdDev_fecundability := 0.12;          {  overwrites the stdDev argument  }
...
gDistrib_fecundability [i] := exp( -0.5 * power ( ( val / gMean_fecundability ) / gStdDev_fecundability, 2 ) ) / ...
```

The `stdDev` parameter is dead, and the normal is centred on `val = 0` and scaled by `mean × 0.12`, so the implemented distribution is N(0, mean·0.12) rather than N(mean, 0.12). The reviewer reproduced the array numerically: the sampled multiplier has mean 1.0217 and standard deviation 0.1226, a coefficient of variation of 12.0 per cent. Léridon's N(0.23, 0.12) has a coefficient of variation of 52.2 per cent.

The parameter's own description string claims "distributed as a normal mean 0.23, std dev 0.12, like Leridon [2004]", and `NORMAL_HETEROGENEITY_FECUNDABILITY` defaults to TRUE, so this is the shipped behaviour.

This is a modelling error, not only a coding one. Heterogeneity in fecundability is what generates the long right tail of the waiting-time distribution, the apparent subfecund fraction, and the decline of apparent fecundability with marital duration through selection. Shrinking the coefficient of variation from 52 to 12 per cent removes almost all of it.

### N5. `monthIncrement` keeps a stale value on the stopping path.
`FertilityRuntime.pas:963-978, 994`.

```pascal
if not fecundLife.stopping then
    monthIncrement := pregnancy (...)
else begin
    if effectivenessContraceptionStopping(...) < randomGenerator.alea0 then
        monthIncrement := pregnancy (...);
end;
```

There is no `else monthIncrement := 1`. With the default `EFF_STOPPING_CONTRACEP = 1.0` the inner test never fires, so after a birth sets `monthIncrement` to about 20, every later stopping month reuses 20: the block at 996-1010 writes conception fields into the previously born child's record, repeatedly, and `currMonth` advances 20 months at a time.

### N6. The contraceptive spacing wait is applied twice.
`FertilityRuntime.pas:859-864, 1019-1031`. `wt_currMonth` is a `var` parameter aliasing `currMonth`; `waiting_time_contraception` increments it in place and also returns the wait, and the caller then advances `currMonth` again by the whole increment. Every birth interval containing spacing is lengthened by the spacing duration a second time. Line 859 also joins two side-effecting calls with `+`, whose evaluation order Pascal does not define, so the birth may additionally be dated late depending on the compiler.

### N7. The PPR target adjustment sets progression to near-certainty where the simulation reached nobody.
`FertilityRuntime.pas:2758-2813`. When no simulated woman reached parity `ind`, `b` is forced to 1e-5, the ratio is on the order of 1e4, and the adjusted probability is clamped to 0.99999. The last such factor is then propagated to every parity from 16 to 50. There is no convergence test at all across the four passes, no fallback to the best iterate, and `adjustedValues` is set true unconditionally. Contrast `findCorrectPropSeparation`, which does keep the best value and does report non-convergence.

### N8. Women in the most fecund tail are made sterile at age 10.
`Fertility.pas:1288-1296`. The `else` conflates "the loop never advanced" with "the loop ran to the maximum", and assigns `ageSterile := kMinAgeFert` in both cases. With the fallback Pittinger and Wood schedule that is 2.8 per cent of women, given essentially zero exposure and zero children. The model therefore carries a floor of permanent childlessness drawn from the most fecund women, which the PPR calibration of N7 then absorbs.

### N9. The intrinsic growth rate omits the proportion female at birth. **Verified (structure).**
`StablePop.pas:44` solves `Σ e^{-rx} l(x) m(x) = 1` with `m(x)` taken from `pGenFert`, which is all births per woman. The only other consumer of the same array, `FertilityRuntime.pas:2857`, multiplies by 0.488 to obtain a net reproduction rate, which confirms it is all-sex. At replacement level the solver therefore returns roughly `ln(2.05)/28 ≈ +0.026` instead of about 0. `r` is not cosmetic: it weights the stable age distribution of mothers, so the sampled maternal age distribution is shifted.

### N10. The net reproduction rate hard-codes 0.488 and ignores `PROP_WOMEN_AT_BIRTH`.
`FertilityRuntime.pas:2857`, while `Mortality.pas:397` correctly reads the parameter. Set the sex ratio at birth to anything else and two different values are in force in the same run.

### N11. Every cohort after the first loses its parameter list.
`Declarations.pas:1390`, `GenericName.copyMeTo` does `toObj.next := nil`. `DemographicRegimeSettings_copyState` copies `yearOfBirth` first, and that object *is* the head of the list, so the destination's list collapses to one node. `copyState` runs for every cohort after the first. Consequence: `changed` is never recomputed for those cohorts, so the unsaved-changes check reports nothing changed and a GUI edit to cohort 2 is lost without a prompt.

### N12. A `NWOMEN` column in the cohort file is always discarded.
`DemographicRegime.pas:1569`. The guard tests `readInConfigFile`, which is set only inside the `readValue` methods, but `processValuesLine` assigns straight to `.value`. So the per-cohort sample size is silently replaced by `NEGO` for every cohort read from the file, while cohort 0 keeps its own value.

### N13. The infant-mortality age correction is inverted and has almost no effect.
`Mortality.pas:300-305`. Three defects: the Coale and Demeny branches are the wrong way round (constant at low mortality, linear at high, when it should be the reverse); `a` exceeds 1 for `q0 >= 0.183`, which is impossible for a mean of years lived within a one-year interval; and the rescaling touches only the lower endpoint, so the reviewer's simulation shows the mean moving from 0.536 to 0.576 years while `a` sweeps from 0.34 to 1.34. There is also a floor at one month, so no infant can die in the neonatal period.

### N14. An e0 outside the tabulated range is warned about but not clamped.
`Mortality.pas:333-345`. `writeAndWait` does not halt. The reviewer ran the shipped table: at e0 = 15 the interpolated `lx` is non-monotone with a minimum of -3.3e-7; at e0 = 10, -0.0091. The 20 to 112 bounds exist only in the GUI widget, so a value from a configuration file or from cohort interpolation reaches the routine unchecked.

### N15. `ind_max` is read after a `for` loop that can finish without `break`.
`Mortality.pas:336-338`. If e0 exceeds the last tabulated value the loop falls through and the counter is undefined. The life table is passed **by value**, so the out-of-range read lands in adjacent stack memory: silent corruption rather than a crash.

### N16. `eduLevel` returns garbage for any status that is not B, M or A. **Verified.**
`EducationalLevel.pas:169-179`. `EduLevels` is an integer subrange, so nothing initialises the result, `writeAndWaitConst` does not halt, and both callers use the value immediately as an array index into a table of `DoubleCumulName` **objects**. A garbage index yields a garbage class reference. The obvious trigger is the empty string, which is what an unassigned relative still holds while `giveEdStatus` walks the list.

### N17. The partner correlation matrix is indexed with the wrong sex.
`EducationalLevel.pas:263-265`. The first index is the level of the already-assigned partner, but the second is `pRelative^.gender`, the sex of the person being assigned, that is the other person. The correlation stays positive, so it passes a smoke test, but the wrong sex's conditional distribution is imposed.

### N18. "Intra-family" education correlates four kin types out of twenty-seven, and does not correlate siblings.
`EducationalLevel.pas:281-288`. `kt_sibling` is routed to the unconditional cohort draw, and everything outside ego, partner, child and grandchild falls to the same default. In a kin-network model this is far weaker than the mode name implies.

### N19 and N20. The education parameter dump names the wrong table for each mode, and the stochastic mode ignores all six `EDU_*` parameters.
`DemographicRegime.pas:733-746` shifts the mode-to-table mapping by one, so a run under `eduCohort` records `EDUPARTNER_*` values while having used `EDU_*`. And `EducationalLevel.pas:181-192` hardcodes 1/3 and 2/3. The combination means a user reasonably believes the dumped values were used.

### N21. The ascendant heir share loop drops the last heir. **Verified.**
`inheritance.pas:1565-1572`:

```pascal
for indHeir := 1 to (nHeirs-1) do
    addHeir_2 (..., shareInheritance / (nLineages * arrHeirs[indHeir-1].nParentsInLineage));
```

The loop is already zero-based through `arrHeirs[indHeir-1]`, so the bound drops the last ascendant, while the shares that are paid were computed assuming it would be. Four surviving grandparents give shares summing to 0.75; three give 0.5. This is the largest single source of the `checkSumShareHeirs` deviation the author instrumented.

### N22. A nearer ascendant does not exclude a remoter one.
`inheritance.pas:1491-1515`. The paternal and maternal branches recurse independently, so `arrHeirs` can mix degrees: a surviving maternal grandmother sharing with two paternal great-grandparents. Every rule set in the file's own header comment, and Spanish CC art. 921, say the nearest degree excludes the rest. `AscendantHeirs_2` hardcodes `degree := 3` with no way to restrict it.

### N23. In the niece and nephew block the father is tested twice and the mother never.
`inheritance.pas:919`. The comment says "either the father or the mother"; `pDeadRelative^.mother` does not appear. The second call is also a guaranteed no-op because `heirFound_add` exits early on an already-found heir. So a person whose mother is alive has their estate distributed to grandparents and aunts.

### N24. `commonAncestor` is computed and discarded at four of five call sites.
`inheritance.pas:945-948, 963-972, 1005-1010, 1085-1092`. `pAncestor` is assigned and immediately overwritten, and the code unconditionally collects the children of both of ego's parents. A maternal half-sibling with no blood relation to the dead niece is given an equal share and inflates the denominator of ego's own share.

### N25. The country rule set is never consulted, and one algorithm entry point is an empty stub.
`inher_Spain` and `inher_Other` are declared, parameterised, saved, read and bound to a control, and referenced nowhere in `inheritance.pas`. Both algorithms run unconditionally on every run. `lookForDecedents_Spain` at line 2098 has an empty body.

### N26. `checkHeirs` reports agreement in exactly the case where the two algorithms disagree.
`inheritance.pas:2141-2149`. When algorithm 1 concludes `th_none` (no heirs) and algorithm 2 found some, the case arms are empty and the result stays at 1, "good". The final `else` is unreachable because the third condition is the exact complement of the second. And the list comparison is order-sensitive, so equal sets in different insertion order are reported as a mismatch.

### N27. `getPartner` returns an uninitialised pointer on its guard path. **Verified.**
`Nuptiality.pas:264-276`. `result` is assigned only inside `{$IFDEF addOldUnionType}`, which is not defined anywhere in the tree. `writeAndWaitConst` does not halt, so the caller receives whatever is in the return register and dereferences it. The bound in the guard is the literal 20 while `kMaxNbUnion` is 30.

### N28. The union setters fabricate a phantom union when the index is out of range.
`Nuptiality.pas:174-190` and five siblings. `getUnionInfoByIndex` returns nil for any index below 1 or above `nUnions`, and the setters treat that as "append a new union", incrementing the person's union count and writing the value to the wrong union. `Kinship.pas:477` passes the result of `getIndUnion`, which returns `kNotDefined` precisely when the reciprocal link is missing, that is in the situation the consistency check exists to detect.

### N29 to N32. Union model: four unguarded numerical paths.
`scaleFactor` can be zero or negative in `initStandardNuptiality` (`Nuptiality.pas:611-616`), giving a division by zero or negative densities that are then renormalised. `std_Campbell_Wood_1988` (`1230-1237`) takes the square root of a negative number for any mean below 15.32, which is inside the accepted range. `ageWomenEndUnion` (`1524-1545`) never tests `kNotDefined` and can return a negative age labelled `widow`. And `endBySeparation` (`1062-1114`) assigns its two decision variables inside a `try` whose handler falls through, so a swallowed exception leaves the separation decision to two uninitialised doubles.

### N33. `truncateAtAge` reads a `for` loop variable after normal completion.
`Parenthood.pas:232-262`. FPC leaves it undefined. One of the two plausible values writes four fields past the end of the `Unions` array and leaves `nbUnions` one too high. If the first union starts after the truncation age, the index becomes 0 and it writes before the array.

### N34 to N38. The `initMotherhood` phase.
`distNbChildren` is incremented with a plain `Inc` from every worker into one shared per-cohort record, and in a stable population every year clamps to `data[0]`, so all threads collide on the same counters. `addGroomsInfo` uses `exit` where it needs `continue`, so a woman whose first union falls outside the groom cohort range loses all her unions including in-range later ones. The thread `Destroy` runs immediately after the finish flag with no `WaitFor` and no `inherited Destroy`, so the RTL is still touching the instance after it is freed. `TPersonMemoryManager.Create()` with no argument allocates a 100 × 100 × 10000 array of references, about 800 MB, and two of them are created unconditionally. And the scheduling loop's `nActiveThreads` is not a count of running threads, so it calls `.start` repeatedly on threads that are already running.

### N39. `mothersInfoList.pas` is dead code that cannot compile.
No unit header, nothing includes it, and it uses a constant that is not defined anywhere in the tree. Both of its public entry points begin with `exit`. It should not ship.

### N40. Two more counters incremented non-atomically from worker threads.
`Kinship.pas:4576, 4589, 4676, 4691`: `gBACKFOR_nTries` and `gBACKFOR_women`, written from the CAMSIM-1993 and real-BACKFOR mother searches, which run on every worker. Same class as the three fixed in the first pass. `gBACKFOR_nTries` needs `InterlockedExchangeAdd`.

### N41. Bootstrap replicates reuse stale arrays.
`gMen_Women` and the five `gState*` arrays are freed only in `disposeMotherhood_DemReg`, which runs once per session, while `initMotherhood` runs once per replicate. `SetLength` to the same dimensions is a no-op and does not zero. Contrast `gAllBirths` thirteen lines earlier, which is correctly cleared by setting the length to 0 first.

---

## 2. Crashes and unguarded arithmetic

Recorded compactly; all carry file and line in the reviewers' output and none is a results bug on its own.

- `FertilityRuntime.pas:2862, 2871-2876`: division by zero when a cohort produces no births, then a `while` with no lower bound that walks below `kMinAgeFert`.
- `FertilityRuntime.pas:2552, 2568`: two unguarded divisions in the separation Newton step; the denominator is zero whenever two consecutive iterations give the same simulated proportion, which is ordinary for a coarse ratio of counts.
- `FertilityRuntime.pas:2651`: an extra `Inc` leaves `history[·,1]` uninitialised when the user supplies a warm start.
- `FertilityRuntime.pas:2626`: `freqSeparation_result` read from an uninitialised record and then printed as the `SEP_RESULT` column.
- `DemographicRegime.pas:1508-1525`: parity and interval indices taken from the cohort file header with no bounds check.
- `DemographicRegime.pas:1625-1628`: one blank line in the cohort file rejects the whole file, while the first pass over the same file explicitly tolerates blanks.
- `Fertility.pas:198-230`: the Erlang waiting-time distribution takes `power(0, k-1)` at `i = 0`, is never normalised, and sets `k` independently of `lambda`, so `Nuptiality.pas:856` requests a mean that is delivered 3.33 times too large.
- `Kinship.pas` `initMotherhood`: five index computations without bounds (`addChildrenBACKFORInfo` indexing an age at union on a fertility-age axis; `addBridesInfo` and `addGroomsInfo` with no high clamp; `addUnionsInfo` off by one; `lookingForABrideByAgeAndCohort` walking off both ends with no empty-range escape; `getAgeUnionSelected` reaching `Unions[-1]`).
- `Parenthood.pas:487-488`: division by zero in `writeInfoParents` for any empty cohort.

---

## 3. What the reviewers could not settle

- Whether the cumulative `gMen_Women` across bootstrap replicates is intended.
- Whether the repartnering model can emit a union age above 74, which decides whether N-class index bounds are reachable.
- Whether `union_women_men` rows always reach 1.0, which bounds an unguarded sampling loop.
- ~~Whether `DebugMemory` is ever defined in a configuration that also enables threading; if so, `ptrList` in `Memory.pas` is an unlocked shared dynamic array resized from several threads.~~ **Settled**: `DebugMemory` is never defined anywhere in the tree, so the standard memory manager is in force and the unlocked `ptrList` is unreachable.
- Several questions of legal intent in the inheritance module: posthumous children, escheat when no heir is found, usufruct, and whether grand-nieces competing per capita with grand-aunts at degree 4 is deliberate.

---

## 4. Suggested order

1. **N1**, the parameter sweeps. It invalidates a class of results outright and the fix is small.
2. **N3** and **N5**, both single missing assignments with large downstream effects.
3. **N4**, the fecundability heterogeneity, which is a modelling decision as much as a fix: confirm the intended parameterisation first.
4. **N2** and **N6**, the two time-origin errors in the birth interval.
5. **N21**, **N23** and **N24** in inheritance, all small and all producing wrong shares.
6. **N16** and **N27**, the two functions that return garbage and are then used as an index or dereferenced.
7. **N13**, **N14**, **N15** in mortality.
8. **N9** and **N10**, the growth rate and the net reproduction rate.
9. Everything in section 2.
10. **N39**, delete the dead unit before publication.
