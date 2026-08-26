# KinFert: open work before release

Last updated 26 August 2026, fourth round. Two audit documents hold the evidence: `docs/KinFert-PreRelease-Audit.md` for the individual-file output path, and `docs/KinFert-PreRelease-Audit-2.md` for the demographic engine. This file is the working list and carries the line numbers you asked for.

**Line numbers are current** as of this update, after the BATCH removal, which moved roughly 100 lines in `Kinship.pas`. They will move again with the next edit; procedure names are the stable reference.

**Nothing has been compiled.** Every change was verified by re-reading it and by checking that the `begin`/`end` balance of each edited unit is unchanged. See V1.

**What changed in this round.** The units that had never been read are now read: `DemographicRegime.pas`, `StablePop.pas`, `Fertility.pas`, `FertilityRuntime.pas`, `Nuptiality.pas`, `Parenthood.pas`, `Mortality.pas`, `EducationalLevel.pas`, `inheritance.pas`, `Memory.pas`, `mothersInfoList.pas` and the `initMotherhood` phase of `Kinship.pas`. That pass produced 41 findings, N1 to N41, and it found more that affects published results than the first pass did. They are in section 2E below, and section 8 gives the order I would work in.

---

## 1. Explanations you asked for

### D4. Why keys are not only a bootstrapping matter

A key is a run identifier written as the first column of the individual files, with a companion `X_KEYS.txt` file decoding it. `openFileKeys` in `Utilities.pas:755` computes

```pascal
RP.wkey := needsKeys and (stepsKeys or RP.wKeyBootstrap);
```

`RP.wKeyBootstrap` is the bootstrapping half. `stepsKeys` is the other half, and it is true whenever **any** of the seven parameter-step counts exceeds one: `nStepsUnion_mean`, `nStepsUnion_prop`, `nStepsUnion_Dev`, `nStepsAmeno`, `nStepsContrFert`, `nStepsSeparation`, `nStepsContrUseAfterUnion`. So a parameter sweep needs keys even with no bootstrapping at all, which is why removing bootstrapping must not remove `RP.wkey`, `openFileKeys`, the KEYS file or the key column.

Two related facts. Steps and cohort sequences are mutually exclusive: `openFileKeys` detects `DemRegimeCollection_VariousCohorts and stepsKeys` and forcibly resets all seven step counts to 1, with a message. And `writeKeys` has exactly one call site, `SpecialRuns.pas:146`, inside `FERTILITY_loops`, which runs only when FERTILITY is on. You said keys make sense for fertility and not for kinship, and the code agrees: in a kinship-only stepped run `RP.key` is never incremented, so the key column would be the constant 0 on every row. Whether to suppress the column in that case is still open.

**New, and important**: the same loop nest in `SpecialRuns.pas` that produces those keys is broken. See N1. The keys are correct; the parameter values they label are not.

### D5b. What the reader loses, and why D5a follows from it

`readDemocareFile` rebuilds a tree in two steps. First it walks the main file: a row whose `ego` column is TRUE becomes an ego, and **every other row is created as `kt_nonBio`** at `Kinship.pas:1918`. Then it walks the link file and uses only that to rebuild structure: an `M` row calls `addLastPartner` and types the second party `kt_partner`; a `D` row calls `addChildToParent` and sets the mother.

So the kin taxonomy is not restored. A person who was written as `kt_child` or `kt_grandChild` comes back as `kt_nonBio`, or as `kt_partner` if a link row happens to name them. The extended DemoCare layout already writes the true kin type in the `relative` column, and the reader ignores it. That is D5b: read that column when the extended layout is present, and the types come back. **Fixed in round 3**, using `GetEnumValue (TypeInfo(KinTypes), ...)` guarded by the header length and the column count, so a short-layout file still reads as before.

D5a only matters once D5b is done, and you are right that it is not about different trees. It is inside one tree. Ego's child C has a partner P; both are written. The loop writes a marriage row for every partner of every written relative, so it writes `(C, P, 'M')` when it processes C and `(P, C, 'M')` when it processes P. On read-back the first row types P as C's partner, correctly, and the second row types **C** as P's partner, overwriting C. Before D5b that cost nothing because C was `kt_nonBio` anyway. After D5b it would undo the type just restored. **Fixed in round 3** by re-typing only when the target is still `kt_nonBio`. Worth checking at the same time: `addLastPartner` also runs in both directions, so the union list may gain the same partner twice. That check is V4 below.

### 2.6. The "just in case" cleanup loop

`Kinship.pas:7925`:

```pascal
allThreadsTerminated := false;
while not allThreadsTerminated do
    for indThread := 0 to gNumThreadsUsed - 1 do
        allThreadsTerminated := allThreadsTerminated and gMyThreadObjects[indThread].Terminated;
```

`allThreadsTerminated` starts `false`, and `false and anything` is `false`, so the inner loop can never make it true and the outer loop never ends. The flag has to be reset to `true` **inside** the outer loop, before the inner one, not once before it. Compare the correct version of the same idiom at `Kinship.pas:7805-7809`, which does reset it each time round.

Second problem: the objects have `FreeOnTerminate := true` and `Terminate` was called just above, so `.Terminated` may be read from an object the RTL has already freed.

It is unreachable today because `allThreadsCleanedUp` is set on the normal path. The risk is precisely that it is a fallback: the day the normal path does not run, the program hangs at 100% CPU instead of cleaning up.

**My recommendation: delete the loop.** Two reasons. It cannot do the job it was written for, since it cannot exit; and even a corrected version would be reading fields of objects the RTL is entitled to have freed, which is a use-after-free that no amount of looping makes safe. `TSimulEgoTreeCleanUp` already performs the cleanup on the normal path, and a fallback that hangs the program is worse than no fallback, because a missing cleanup leaks at exit while a hang loses the run. If you want to keep a diagnostic, replace it with a bounded wait that gives up: a loop with a `Sleep(1)` and a counter, logging a warning after, say, five seconds, and then continuing.

### 4.9. Why the inheritance warning can fire 21 times, and what to do

`inheritance.pas:96` sits inside

```pascal
for aKin in gMinKinSetforEgoInheritance do
    if not (aKin in gKinToSimulate) then begin
        ... writeAndWait('Warning: ' + str_kinship[akin] + ' not in the set of kin to simulate ...');
    end;
```

with no `exit`, so it warns once **per missing kin type**. `gMinKinSetforEgoInheritance` (`Declarations.pas:110`) has 25 members, everything up to second cousins twice removed. With the DemoCare kin set of four types, 21 of the 25 are missing, hence 21 messages. With `gStdKinSet` (12 types) it is 13 messages. And `checkInheritanceStatus` is called from `run_all`, so that is per cohort and, until bootstrapping goes, per replicate. Each call also latches `gDebugError`, so the run finishes showing an error state.

**My recommendation: do not shrink `gMinKinSetforEgoInheritance`.** That set is not a display convenience, it is the demographic statement of which kin an inheritance calculation needs in order to be correct. Spanish succession can reach collaterals to the fourth degree, so a set that stops earlier would make the module quietly produce wrong shares instead of warning that it cannot produce right ones. Shrinking it to silence a message would convert a loud, correct complaint into a silent, incorrect result.

Fix the message instead. Collect the missing types into one set, and emit a single line: `Inheritance: N of the 25 kin types it needs are not simulated (list). Shares will be incomplete.` One message per run rather than 21 per cohort per replicate. Two further points worth deciding at the same time:

- Whether this should latch `gDebugError` at all. It is a configuration mismatch, not a program fault, and latching it makes every DemoCare run end in an error state.
- Whether inheritance should simply be skipped, with one message, when the kin set cannot support it. That is arguably the honest behaviour: the alternative is to write share columns that are known to be wrong.

### 3.e. What FILENAME is for

`g_FileName.value` is the root of every output name of the run. Examples: the configuration echo `X_CONFIG.TXT` and `X_ALLCOHORTS.TXT` (`ReadCmdFileUnit.pas:1636`), the genealogy files `X_EgoGenealogy.csv` / `X_indKin.txt` / `X_indKin_link.txt`, the keys file `X_KEYS.txt`, `X_INDIVIDUAL_FERTILITY_INFO.CSV` (`FertilityRuntime.pas:1722`), `X_UNION_TABLE.TXT` (`:1994`), `X_statusTable.txt` (`:2511`), `X_target.txt` (`DemographicRegime.pas:1682`) and `DUMP_COHORTS_X.txt` (`:1731`). In practice it is the study name, and it is also what distinguishes one run's outputs from another's in the same results folder.

The bug is that its `changed` flag is only ever set from the Config dialog. `g_FileName` is created at `Init.pas:380` with no default in its parameter list, so under the default `WRITE_ONLY_CHANGES` the writer guard at `ReadCmdFileUnit.pas:709` skips it unless something marked it changed. A run that never opened the Config dialog therefore writes a configuration file with **no `FILENAME` line at all**. Re-running that configuration file gives every output the fallback root, `KINFERT_*`, so the second run's files do not overwrite the first run's and do not carry its name. You get two sets of outputs under two different names from what you believe is the same study, and the connection between them is lost.

Two ways to fix it. Either set `changed` when the value differs from the fallback, or, simpler and safer, always write `FILENAME` regardless of `WRITE_ONLY_CHANGES`, on the grounds that a configuration file without a study name is not reproducible.

### 3.2. What aCommand is

A configuration line is `NAME=VALUE`. `extractCommand` (`ReadCmdFileUnit.pas:1191`) splits it and returns the name in its `out c` parameter and the value in `out s`. It is called twice:

```pascal
extractCommand (aLine, aCommand, aState, aBooleanState);                                    // 1205
extractCommand (gLineReadString_NotProcessed, aCommand, aState_NotProcessed, aBooleanState, false);  // 1207
```

The first call works on the cleaned, upper-cased line, so `aCommand` correctly receives `KINSHIP`. The second call exists only to recover the **value** in its original case, into `aState_NotProcessed`, which matters for paths and for kin-type names. But it passed `aCommand` again as the `out c` parameter, this time fed the raw line, so `aCommand` was overwritten with the un-upcased, un-trimmed name. A hand-written `kinship=on` then matched no branch, `UNKNOWN COMMAND` was printed and the whole file abandoned, even though the file the program itself writes promises at `ReadCmdFileUnit.pas:841` that case does not matter. **Fixed in round 3** with a throwaway `aCommand_raw`.

### On the remaining "bootstrap" identifiers

You asked whether the roughly 80 remaining occurrences of the word are harmful. They are not harmful today, and they are not urgent. They fall into three groups.

1. **Live and doing work.** `gBootstrap_nRuns`, the replicate loop in `ReadCmdFileUnit.pas:1599`, `RP.indBootstrap`, `RP.wKeyBootstrap`, and the `bootstrap_ind` parameter threaded through `run_all` / `simulateKinship` / `individualKin_*`. With `gBootstrap_nRuns = 1`, which is the default, the loop runs once, `indBootstrap` stays 1 and every branch that tests it takes the single-replicate path. Nothing is wrong, it is simply a loop of length one.
2. **Load-bearing for something else.** `RP.wkey` and the KEYS machinery, as in D4. This must survive B1.
3. **Genuinely inert.** `OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES` and its GUI binding, and the `sharedBootstrapFile` / `openMode` path I added in round 1 to fix the append (item B3).

The one real cost of leaving them is N41: `gMen_Women` and the five `gState*` arrays are freed once per session but `initMotherhood` runs once per replicate, so with `gBootstrap_nRuns > 1` the replicates share stale arrays. That is a bug only for someone who turns bootstrapping on. If B1 lands, N41 goes with it and no separate fix is needed. So: leave the identifiers alone, do B1 as one deliberate change, and treat N41 as B1's acceptance test rather than as a separate item.

---

## 2. Open bugs, with line numbers

### 2A. Results correctness, output path

| ID | What | Where |
|---|---|---|
| 1.3 / B4 | GEDCOM is selectable and writes a header and no rows. To be implemented later; until then either remove it from the combo or make the format substitution reach the caller | substitution `Kinship.pas:7463`; empty writer `writeKinGEDCOM` |
| D5b | ~~The reader types every non-ego row `kt_nonBio` and ignores the `relative` column~~ | **Fixed round 3.** `Kinship.pas:1918`. Verify with V4 |
| D5a | ~~Marriage rows are written in both directions; matters once D5b is done~~ | **Fixed round 3.** Writer `Kinship.pas:3667`; reader `Kinship.pas:1946-1955`. The duplicate `addLastPartner` remains to be checked, V4 |

### 2B. Crashes, hangs and leaks

| ID | What | Where |
|---|---|---|
| 2.1 | ~~`nEgosPerSecond := 1000 * nEgosSimulatedInTimeSlot / msElapsed` with `msElapsed` in whole milliseconds, so 0 whenever less than a millisecond has passed~~ | **Fixed round 3** with a `msElapsed > 0` guard. `Kinship.pas:7547-7548`, in `individualKin_mid` |
| 2.3 | The go-flag is published before the busy-flag is cleared and before the tree count, with no event, lock or barrier | `TSimulEgoTree.Simulate`, `Kinship.pas:6711-6716`; the consumer is `TSimulEgoTree.Execute`, `Kinship.pas:6722` onward |
| 2.5 | The link file failing to open leaves the main file open, and the caller's bare `exit` skips `writeTables`, `DestroyArrayChildren` and all thread cleanup, leaving the workers spinning | open failure `Kinship.pas:7483` and `7493`; the bare `exit` at `Kinship.pas:7746-7747` |
| 2.4 | Every wait is a hot spin with no yield | worker `Kinship.pas:6707`; dispatcher `Kinship.pas:7802`; main thread `Kinship.pas:7805-7809`; file class `Utilities.pas:276` |
| 2.6 | The fallback cleanup loop that can never exit, on freed objects | `Kinship.pas:7925-7928`. Recommendation above: delete it |

### 2C. Settings file round trip

| ID | Parameter | Where | Your note |
|---|---|---|---|
| 3.b | `USE_ARRAY_CHILDREN` never written or read; also constructed `TRUE` but defaulted `FALSE` | used at `Kinship.pas:7704` and `7938`; constructed `Init.pas:518`, defaulted `Init.pas:417` | You think it is deprecated. Decide and either remove it or make it saveable |
| 3.c | `OUTPUT_KINTYPES_STD`, `OUTPUT_KINTYPES_DEMOCARE` not saved | writer `ReadCmdFileUnit.pas:953` | **By design.** Closed |
| 3.d | `DUMP`, `STABLE_POPULATION` writer commented out, reader live | `ReadCmdFileUnit.pas:848` and `875`; readers at `1211` and `1255` | `DUMP`/`DUMPALL` are runtime choices, so not saving them is deliberate: the dead reader branches should go, or the comment should say why. `STABLE_POPULATION` you believe deprecated, since stability follows from having a single demographic regime |
| 3.e | `FILENAME` dropped under the default `WRITE_ONLY_CHANGES` | created with no parameter list at `Init.pas:380`; writer guard `ReadCmdFileUnit.pas:709` | Explained above. Worth fixing: it silently changes where a re-run writes |
| 3.f | `MAX_THREADS` not saved because its default is the core count | `Init.pas:367` | **Intended.** Closed |
| 3.1 | `DUMPALL` writes a detailed file with no tables in it | `ReadCmdFileUnit.pas:1016-1021` and `1026` | Open |
| 3.2 | ~~`aCommand` overwritten from the raw line~~ | `ReadCmdFileUnit.pas:1207` | **Fixed round 3** with `aCommand_raw` |
| 3.3 | Duplicate `CHECK_DATASTRUCT` branch, the second unreachable | `ReadCmdFileUnit.pas:1265` and `ReadCmdFileUnit.pas:1305` | Open |
| 3.4 | `fn_yDeathFloat` has no checkbox: the name is listed at `lazkinoutputfields.pas:84` and the field is in the default set at `Init.pas:469`, but `lazkinoutputfields.lfm` has 21 checkboxes for 22 enum members | `lazkinoutputfields.lfm` | Open. The column cannot be switched off from the GUI |
| 3.5 | A rejected configuration file still prints the finished banner and returns success | `ReadCmdFileUnit.pas:1674` | Open |
| 6.4 | `ArrayOfDoubleName.setDefault` is never called anywhere read so far, yet `setChanged` indexes `default`, which the constructor leaves nil | `setChanged` at `Declarations.pas:1581`, `setDefault` at `Declarations.pas:1632` | Still open after reading `DemographicRegime.pas`: no `setDefault` call was found there either. Related to N11 |
| N12 | A `NWOMEN` column in the cohort file is always discarded, because the guard tests `readInConfigFile` which `processValuesLine` never sets | `DemographicRegime.pas:1569` | New. Per-cohort sample sizes are silently replaced by `NEGO` |
| N19 | The education parameter dump names the wrong table for each mode: the mode-to-table mapping is shifted by one | `DemographicRegime.pas:733-746` | New. A run under `eduCohort` records `EDUPARTNER_*` values while having used `EDU_*` |

### 2D. Output hygiene and dead code

| ID | What | Where |
|---|---|---|
| 4.2 | Link file: `M` rows in both directions, `D` rows only for `kt_child` and `kt_grandChild` that are not by-union. For the DemoCare kin set the descent links are complete | `Kinship.pas:3667` and `3674`. D5a and D5b now fixed |
| 4.6 | `heirs` is emitted twice as a header name when the debug block is on, and the user-facing `heirs`, `decedents`, `share inheritances` columns are written from the second-algorithm variables | header `Kinship.pas:7394`, `7395`, `7397`, and the duplicate at `7402`; row values `Kinship.pas:3859-3863` |
| 4.7 | Empty-value sentinels disagree: `str_causeEnd := ''` at `3722` and `3740`, `idSpouses := '0'` at `3737`, `str_AgeUnion := '-1'` at `3738`, `str_AgeEndUnion := '-1'` at `3739`, `str_share := '-1'` at `3766`, and empty strings for the second-algorithm heir columns | `Kinship.pas:3722-3766` |
| 4.8 | The ego children check is redundant: `CalcChildren` already reports the same condition one line earlier | check `Kinship.pas:3574`; the earlier report is inside `CalcChildren` |
| 4.9 | The inheritance warning fires once per missing kin type | `inheritance.pas:96`. See the recommendation above |
| 4.11 | `tStart_interm` read but assigned only inside `if TALKATIVE` | `Kinship.pas:7938` |
| 5.2 | Add the final `else` when GEDCOM lands, or the result is uninitialised | `writeKin` at `Kinship.pas:3873`, `includeKinInNetwork` at `Kinship.pas:3895` |
| 5.6 | Comment the deliberately commented-out `Destroy`, which would be a double free if uncommented | `Kinship.pas:7684` |
| N39 | `mothersInfoList.pas` is dead code that cannot compile: no unit header, nothing includes it, it uses an undefined constant, and both entry points begin with `exit` | Delete before publication |
| N25 | `inher_Spain` and `inher_Other` are declared, parameterised, saved, read and bound to a control, and referenced nowhere. Both algorithms run unconditionally. `lookForDecedents_Spain` at `inheritance.pas:2098` has an empty body | Either wire the rule set up or remove the parameter |

### 2E. The demographic engine, second pass

Full evidence in `docs/KinFert-PreRelease-Audit-2.md`. **Verified** means I re-read the source myself rather than relying on the reviewer.

#### Highest priority: results are wrong today

| ID | What | Where |
|---|---|---|
| N1 | **Parameter sweeps do not sweep. Verified.** Two defects in one loop nest. The stepped value is computed from `RP.indAgeUnion` nine lines before that variable is assigned, so every step uses the previous iteration's index. And the multiplicative steps read their base from the parameter the previous step already overwrote, because the restore from `pDemReg_mem` happens in the innermost loop. Separation step 1 computes `base × 0 = 0` and writes 0 back; step 2 reads 0. **`NSTEP_SEPARATION` and `NSTEP_CONTRACEPTION_AFTER_UNION` collapse to zero after the first step.** Amenorrhea accumulates instead | `SpecialRuns.pas:53-176`; the read/assign pairs at 61/70, 78/82, 90/94, 112/116, 128/132 |
| N3 | **`endUnion` is never assigned TRUE. Verified.** Declared, initialised FALSE twice, tested in three loops, assigned nowhere. The loops meant to stop at dissolution never stop, and line 646 overwrites the age at end of union unconditionally, so it records the **last** separation drawn rather than the first. One loop runs from the end of fecund life to the death of the man, 40 years of monthly draws. Feeds the individual file, `finalPartnershipStatus`, and the child-pruning loop | `FertilityRuntime.pas:639, 646, 701, 910, 941, 1099, 1118` |
| N4 | **Fecundability heterogeneity is a 12 per cent coefficient of variation, not a standard deviation of 0.12. Verified.** `gStdDev_fecundability := 0.12;` overwrites the `stdDev` argument, and the normal is centred on 0 and scaled by `mean × 0.12`. Reproduced numerically: mean 1.0217, sd 0.1226, CV 12.0 per cent. Léridon's N(0.23, 0.12) has CV 52.2 per cent. The parameter description claims Léridon and `NORMAL_HETEROGENEITY_FECUNDABILITY` defaults TRUE, so this is shipped behaviour. **A modelling decision as much as a fix**: heterogeneity is what generates the right tail of the waiting time, the apparent subfecund fraction, and the decline of apparent fecundability with duration | `Fertility.pas:340-371`, the overwrite at `349` |
| N5 | `monthIncrement` keeps a stale value on the stopping path: no `else monthIncrement := 1`. With the default `EFF_STOPPING_CONTRACEP = 1.0` the inner test never fires, so after a birth every later stopping month reuses about 20, writing conception fields into the previously born child's record and advancing `currMonth` 20 months at a time | `FertilityRuntime.pas:963-978, 994` |
| N2 | Infant death shortens the birth interval by a whole gestation: `min (month, maxMonthDeathChild + 1)` compares a quantity counted from conception with one counted from birth. Should be `min(month, kLivingBirth_durationPregnancyInMonths + maxMonthDeathChild + 1)`. A child dying at one month lets the mother return to susceptibility six months before that child is born. Also `ageDeathChild = 0.0` returns -1 and leaves three fields unassigned | `FertilityRuntime.pas:773-828`, the combination at `815` |
| N6 | The contraceptive spacing wait is applied twice: `wt_currMonth` is a `var` alias for `currMonth`, `waiting_time_contraception` increments it in place **and** returns the wait, and the caller advances again. Line 859 also joins two side-effecting calls with `+`, whose evaluation order Pascal does not define | `FertilityRuntime.pas:859-864, 1019-1031` |
| N21 | **The ascendant heir share loop drops the last heir. Verified.** `for indHeir := 1 to (nHeirs-1)` over a zero-based `arrHeirs[indHeir-1]`. Four surviving grandparents give shares summing to 0.75; three give 0.5. Largest single source of the `checkSumShareHeirs` deviation you instrumented | `inheritance.pas:1565-1572` |
| N23 | In the niece and nephew block the father is tested twice and the mother never; `pDeadRelative^.mother` does not appear. The second call is a guaranteed no-op because `heirFound_add` exits early. A person whose mother is alive has their estate distributed to grandparents and aunts | `inheritance.pas:919` |
| N22 | A nearer ascendant does not exclude a remoter one: the paternal and maternal branches recurse independently, so a surviving grandmother can share with great-grandparents. Contradicts the file's own header comment and Spanish CC art. 921. `AscendantHeirs_2` hardcodes `degree := 3` | `inheritance.pas:1491-1515` |
| N24 | `commonAncestor` is computed and discarded at four of five call sites, and the code collects the children of both of ego's parents unconditionally. A maternal half-sibling with no blood relation to the dead niece is given an equal share | `inheritance.pas:945-948, 963-972, 1005-1010, 1085-1092` |
| N26 | `checkHeirs` reports agreement in exactly the case where the algorithms disagree: when algorithm 1 concludes `th_none` and algorithm 2 found heirs, the case arms are empty and the result stays "good". The final `else` is unreachable. The list comparison is also order-sensitive | `inheritance.pas:2141-2149` |
| N8 | Women in the most fecund tail are made sterile at `kMinAgeFert`: the `else` conflates "the loop never advanced" with "the loop ran to the maximum". With the fallback Pittinger and Wood schedule that is 2.8 per cent of women, zero exposure and zero children. A floor of permanent childlessness drawn from the most fecund women, which the PPR calibration then absorbs | `Fertility.pas:1288-1296` |
| N7 | The PPR target adjustment sets progression to near-certainty where the simulation reached nobody: `b` forced to 1e-5, ratio about 1e4, clamped to 0.99999, and that factor propagated to parities 16 to 50. No convergence test across the four passes, no fallback to the best iterate, `adjustedValues` set true unconditionally. Contrast `findCorrectPropSeparation`, which does keep the best value | `FertilityRuntime.pas:2758-2813` |
| N9 | **The intrinsic growth rate omits the proportion female at birth. Verified (structure).** `StablePop.pas:44` solves the Lotka equation with `m(x)` from `pGenFert`, which is all births per woman; the only other consumer, `FertilityRuntime.pas:2857`, multiplies by 0.488. At replacement the solver returns about +0.026 rather than 0, and `r` weights the stable age distribution of mothers | `StablePop.pas:44` |
| N10 | The net reproduction rate hard-codes 0.488 and ignores `PROP_WOMEN_AT_BIRTH`, while `Mortality.pas:397` correctly reads the parameter. Two different sex ratios in force in one run | `FertilityRuntime.pas:2857` |
| N13 | The infant-mortality age correction is inverted: the Coale and Demeny branches are the wrong way round, `a` exceeds 1 for `q0 >= 0.183`, and the rescaling touches only the lower endpoint, so the mean moves from 0.536 to 0.576 while `a` sweeps 0.34 to 1.34. A floor at one month also means no infant can die in the neonatal period | `Mortality.pas:300-305` |
| N16 | **`eduLevel` returns garbage for any status that is not B, M or A. Verified.** `EduLevels` is an integer subrange so nothing initialises the result, `writeAndWaitConst` does not halt, and both callers use the value as an index into a table of **objects**, so a garbage index yields a garbage class reference. Triggered by the empty string, which an unassigned relative still holds while `giveEdStatus` walks the list | `EducationalLevel.pas:169-179` |
| N27 | **`getPartner` returns an uninitialised pointer on its guard path. Verified.** `result` is assigned only inside `{$IFDEF addOldUnionType}`, which is not defined anywhere in the tree. `writeAndWaitConst` does not halt, so the caller dereferences the return register. The guard also uses the literal 20 while `kMaxNbUnion` is 30 | `Nuptiality.pas:264-276` |
| N28 | The union setters fabricate a phantom union when the index is out of range: `getUnionInfoByIndex` returns nil, and the setters read that as "append", incrementing the union count and writing to the wrong union. `Kinship.pas:477` passes `getIndUnion`, which returns `kNotDefined` exactly when the reciprocal link is missing, that is in the case the consistency check exists to detect | `Nuptiality.pas:174-190` and five siblings |
| N17 | The partner correlation matrix is indexed with the wrong sex: the second index is `pRelative^.gender`, the person being assigned, where it should be the partner's. The correlation stays positive so it passes a smoke test | `EducationalLevel.pas:263-265` |
| N11 | Every cohort after the first loses its parameter list: `GenericName.copyMeTo` does `toObj.next := nil`, and `DemographicRegimeSettings_copyState` copies `yearOfBirth` first, which **is** the head of the list. `changed` is never recomputed for those cohorts, so a GUI edit to cohort 2 is lost with no prompt | `Declarations.pas:1390` |
| N33 | `truncateAtAge` reads a `for` loop variable after normal completion, which FPC leaves undefined. One plausible value writes four fields past the end of `Unions` and leaves `nbUnions` one too high; if the first union starts after the truncation age the index becomes 0 and it writes before the array | `Parenthood.pas:232-262` |
| N40 | Two more counters incremented non-atomically from worker threads: `gBACKFOR_nTries` and `gBACKFOR_women`, from the CAMSIM-1993 and real-BACKFOR mother searches. Same class as the three fixed in round 1. `gBACKFOR_nTries` needs `InterlockedExchangeAdd` | `Kinship.pas:4576, 4589, 4676, 4691` |

#### Lower priority within the second pass

| ID | What | Where |
|---|---|---|
| N14 | An e0 outside the tabulated range is warned about but not clamped, and `writeAndWait` does not halt. At e0 = 15 the interpolated `lx` is non-monotone with a minimum of -3.3e-7; at e0 = 10, -0.0091. The 20 to 112 bounds exist only in the GUI, so a configuration file or a cohort interpolation reaches the routine unchecked | `Mortality.pas:333-345` |
| N15 | `ind_max` is read after a `for` loop that can finish without `break`. The life table is passed **by value**, so the out-of-range read lands in adjacent stack memory: silent corruption, not a crash | `Mortality.pas:336-338` |
| N18 | "Intra-family" education correlates four kin types out of twenty-seven and does not correlate siblings: `kt_sibling` goes to the unconditional cohort draw, as does everything outside ego, partner, child and grandchild | `EducationalLevel.pas:281-288` |
| N20 | The stochastic education mode ignores all six `EDU_*` parameters and hardcodes 1/3 and 2/3. With N19 the user reasonably believes the dumped values were used | `EducationalLevel.pas:181-192` |
| N29 | `scaleFactor` can be zero or negative in `initStandardNuptiality`: division by zero, or negative densities that are then renormalised | `Nuptiality.pas:611-616` |
| N30 | `std_Campbell_Wood_1988` takes the square root of a negative number for any mean below 15.32, which is inside the accepted range | `Nuptiality.pas:1230-1237` |
| N31 | `ageWomenEndUnion` never tests `kNotDefined` and can return a negative age labelled `widow` | `Nuptiality.pas:1524-1545` |
| N32 | `endBySeparation` assigns its two decision variables inside a `try` whose handler falls through, so a swallowed exception leaves the separation decision to two uninitialised doubles | `Nuptiality.pas:1062-1114` |
| N34 | `distNbChildren` is incremented with a plain `Inc` from every worker into one shared per-cohort record, and in a stable population every year clamps to `data[0]`, so all threads collide on the same counters | `initMotherhood` in `Kinship.pas` |
| N35 | `addGroomsInfo` uses `exit` where it needs `continue`, so a woman whose first union falls outside the groom cohort range loses all her unions including in-range later ones | `initMotherhood` |
| N36 | The thread `Destroy` runs immediately after the finish flag with no `WaitFor` and no `inherited Destroy`, so the RTL is still touching the instance after it is freed | `initMotherhood` |
| N37 | `TPersonMemoryManager.Create()` with no argument allocates a 100 × 100 × 10000 array of references, about 800 MB, and two are created unconditionally | `initMotherhood` |
| N38 | The scheduling loop's `nActiveThreads` is not a count of running threads, so `.start` is called repeatedly on threads already running | `initMotherhood` |
| N41 | Bootstrap replicates reuse stale arrays: `gMen_Women` and the five `gState*` arrays are freed once per session in `disposeMotherhood_DemReg` while `initMotherhood` runs once per replicate, and `SetLength` to the same dimensions does not zero. Contrast `gAllBirths` thirteen lines earlier. **Disappears with B1** | `initMotherhood` |

#### Unguarded arithmetic and bounds, second pass

None of these is a results bug on its own; each is a crash or a silent corruption waiting for an unusual input.

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

## 3. Questions for you

These the reviewers could not settle, and they are matters of intent rather than of code.

| ID | Question |
|---|---|
| Q1 | N4: is the intended parameterisation N(0.23, 0.12) as the description string says, that is a coefficient of variation of 52 per cent, or the 12 per cent the code produces? The fix is trivial either way; what it changes is the published fertility |
| Q2 | N2: confirm that `LivingBirth` is meant to be counted from conception, so the correction is to add the gestation to the death term rather than to subtract it from `month` |
| Q3 | N22 to N26: how far the inheritance module is meant to follow Spanish succession. Specifically: does a nearer ascendant exclude a remoter one; are posthumous children heirs; what happens when no heir is found; is usufruct modelled; and is grand-nieces competing per capita with grand-aunts at degree 4 deliberate |
| Q4 | N25: should `inher_Spain` / `inher_Other` select between rule sets, or is the parameter a leftover to remove |
| Q5 | N18: is education meant to correlate between siblings? At present it does not |
| Q6 | Whether the repartnering model can emit a union age above 74, which decides whether several index bounds are reachable |
| Q7 | Whether `union_women_men` rows always reach 1.0, which bounds an unguarded sampling loop |

---

## 4. Changes you have announced

| ID | What | State |
|---|---|---|
| B1 | Remove bootstrapping | Confirmed. Touches `gBootstrap_nRuns`, `OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES`, `RP.indBootstrap`, the loop in `ReadCmdFileUnit.pas:1599`, and the `bootstrap_ind` parameter threaded through `run_all` / `simulateKinship` / `individualKin_*`. Also resolves N41 |
| B2 | Keep `RP.wkey` for fertility | Confirmed. See D4 |
| B3 | Retire the bootstrap-only append fix when B1 lands | `sharedBootstrapFile` and `openMode` in `individualKin_openFile`, and possibly the `mode` parameter added to `openFileOut` |
| B4 | GEDCOM later | The one real bug in that area is fixed: `header_GEDCOM` wrote to `gOutFileIndivKin_link`, a file only opened for DemoCare. If the GEDCOM writer ever needs a second file it must be opened in `individualKin_openFile` first |

---

## 5. Code review coverage

| ID | Unit | State |
|---|---|---|
| R1 | `RandomNumbers.pas` | **Read**, 6.1a fixed |
| R2 | `Fertility.pas`, `FertilityRuntime.pas` | **Read.** N2 to N8, and six arithmetic items |
| R3 | `DemographicRegime.pas`, `StablePop.pas` | **Read.** N9, N11, N12, N19, and two arithmetic items. Does not resolve 6.4 |
| R4 | `Nuptiality.pas`, `Parenthood.pas` | **Read.** N27 to N33 |
| R5 | `Mortality.pas`, `EducationalLevel.pas`, `inheritance.pas` | **Read.** N13 to N18, N21 to N26 |
| R6 | `Memory.pas` | **Closed.** `DebugMemory` is never defined, so the standard memory manager is used and the unlocked `ptrList` is unreachable |
| R7 | `initMotherhood` threading | **Read.** N34 to N38, N41 |
| R8 | `StringOfLib.pas` | **Closed** |
| R9 | `SpecialRuns.pas` | **Read.** N1 |
| R10 | `mothersInfoList.pas` | **Read.** Dead and uncompilable, N39. Delete |
| R11 | The Laz\* GUI units beyond `LazOutput`, `LazConfig`, `lazkinoutputfields` | Not read. Low risk for results, but they are what a new user sees first |

---

## 6. Documentation

| ID | What |
|---|---|
| M1 | The ten questions in Appendix F of `docs/KinFert-Manual.md` |
| M2 | Update the manual for this session: per-format kin sets, the DemoCare field dialog, `DEMOCARE_LARGE_FIELDS`, the new `partnershipStatus` values including `dead` and `secondUnions`, relatives dead before the reference age now excluded, the `kt_total` row, and the removal of the BATCH option |
| M3 | Document the DemoCare format and its link file, now that D5a and D5b are fixed |
| M4 | Release notes: `DEMOCARE_LARGE_FIELDS` replaces the `DUMPALL` binding; old DemoCare configurations carry a wide `OUTPUT_KINTYPES` that is now honoured; the DemoCare file no longer contains relatives dead before the reference age; the BATCH option is gone; `MULTITHREADING_SIMKIN` is now saved |
| M5 | Fold the audits' cleared findings into the developer notes |
| M6 | **New.** Whatever is decided on N4 and N2 changes the model description, not only the code. The manual's account of fecundability heterogeneity and of the effect of infant death on the birth interval must match what the code does after the fix |

---

## 7. Publication on GitHub

`P1` README. `P2` LICENSE. `P3` `*.cfg.example` templates. `P4` pin the Lazarus and FPC versions. `P5` decide the binaries and how they are built. `P6` a minimal regression test with a known output. `P7` decide whether `CLAUDE.md` and the audits ship with the source. `P8` decide what to say about results produced with the versions that carried N1, N3 and N4.

---

## 8. Suggested order of work

1. **V1, compile.** Nothing since 24 August has been built. Everything else waits on this.
2. **N1**, the parameter sweeps. It invalidates a class of results outright and the fix is small.
3. **N3** and **N5**, both single missing assignments with large downstream effects.
4. **N4**, after you answer Q1.
5. **N2** and **N6**, the two time-origin errors in the birth interval, after Q2.
6. **N21**, **N23**, **N24** in inheritance: small fixes, wrong shares.
7. **N16** and **N27**, the two functions that return garbage and are then used as an index or dereferenced.
8. **N8**, **N7**: the sterility floor and the PPR adjustment, which interact.
9. **N13**, **N14**, **N15** in mortality.
10. **N9**, **N10**, the growth rate and the net reproduction rate.
11. **N11**, **N12**: cohort parameter lists and `NWOMEN`.
12. **B1**, bootstrapping, as one deliberate change. **N41** is its acceptance test.
13. The open items of sections 2B, 2C, 2D.
14. Everything in the arithmetic list.
15. **N39**, delete the dead unit; **N25**, decide the rule-set parameter.
16. Documentation, then publication.

---

## 9. Verification

| ID | What |
|---|---|
| V1 | **Compile.** Nothing in this session has been built |
| V2 | One ego-genealogy run and one DemoCare run: check the column count against the header, with and without the extended DemoCare set |
| V3 | `partnershipStatus` shows `firstUnion` and `secondUnions`, not only `separated` and `widow`; `nChildren` is non-zero for relatives who have children |
| V4 | **Write a DemoCare file and read it back with `readDemocareFile`**, both layouts. It should no longer be refused as "Not a Democare Kinship file"; kin types should come back as written (**D5b**); no person should appear twice in another's union list (**D5a**, the duplicate `addLastPartner`) |
| V5 | No row in the DemoCare file has a negative `tickOut`, and no link row names an id absent from the main file |
| V6 | Only grandparents selected: the fathers and grandfathers appear |
| V7 | The `kt_total` row appears and equals the sum of the rows above it |
| V8 | With multithreading off, the same configuration twice, compared byte for byte. The Config dialog leaves "Same Random Sequence" enabled when only `MULTITHREADING_SIMKIN` is off (**D6, to be checked**) |
| V9 | **A multi-cohort run**: every cohort present in the file, family and individual numbers continuous and never repeated, and the closing message reporting the totals for the whole file (**W2, to be checked**) |
| V10 | **A multithreaded run**: no two genealogies identical, which was possible while the threads could draw the same seed (**6.1a, to be checked**) |
| V11 | A run with multithreading on and off produces the same number of families |
| V12 | `MULTITHREADING_SIMKIN` survives a save and a reload (**3.a, to be checked**) |
| V13 | The Outputs dialog no longer shows the "Use batches" checkbox and nothing references it (**W1, to be checked**) |
| V14 | **New, for N1.** A two-step separation sweep: the `SEP` column of the two runs must differ, and the second must not be zero |
| V15 | **New, for N3.** The distribution of age at end of union must not pile up at the oldest ages, and it must be consistent with the age at the first separation drawn |
| V16 | **New, for N4.** The realised distribution of the fecundability multiplier: its coefficient of variation must match whichever parameterisation you choose in Q1 |
| V17 | **New, for N2.** Mean birth interval following an infant death compared with the interval following a surviving child. The difference should be of the order of the shortening of breastfeeding, not of nine months |
| V18 | **New, for N21.** `checkSumShareHeirs` must report shares summing to 1 for a decedent with two, three and four surviving grandparents |
| V19 | **New, for a configuration file.** Hand-write a file with lowercase names and trailing spaces; it must be accepted (**3.2**), and the file the program writes must carry a `FILENAME` line (**3.e**, once fixed) |
| V20 | **New, for N12.** A cohort file with an explicit `NWOMEN` column: each cohort must use its own value, not `NEGO` |

---

## Appendix: fixed in this working tree

Not compiled, not committed.

**Round 1 (24 August).** 0.1 `mySetValue` restored; 1.2 key written after the kin filter; 1.4 `partnershipStatus` comparison and missing `else`; 1.5 `readDemocareFile` enum, sentinel, offset, sex column, nil dereference, handle leak; 1.6 DemoCare `nChildren` for every relative; 1.7 bootstrap append; 1.8 the link file no longer overwrites `fname`; 1.10 DemoCare key separator; 1.11 grandparent chains keep the male ancestor; 1.12 great-grand-niece guard; 1.13 `kt_total` in 11 of 12 loops; 1.14 `setInfoParents` and guarded divisions; 1.15 `InterlockedIncrement` on three counters; 1.16 the ego-budget off-by-one; 1.9 partial.

**Round 2 (25 August).** D1 `dead` status; D2 `secondUnions` and the last-union logic; D6 `runDrawsFromSeveralThreads`; D7 relatives dead before the reference age dropped and link rows never naming them, `checkLinks` removed; 3.a `MULTITHREADING_SIMKIN` saved and read; 4.3 counts only what was written; 4.10 the four dialogs free their `BooleanName` objects.

**Round 3 (25 August).**

- **W1, BATCH removed.** The three nested batch procedures deleted from `simulateKinship`, the `BATCH` local and its assignment, the six `if BATCH then` branches, `nBatches`, `indBatch`, `nThreadsInBatch` and the batch-only locals; the checkbox and its binding in `LazOutput.pas` and the object in `LazOutput.lfm`; the writer and reader in `ReadCmdFileUnit.pas`; the default and constructor in `Init.pas`; the record field in `Declarations.pas`. This also removes audit 2.2 entirely and three of the four 2.1 division sites.
- **W2, multi-cohort output.** `individualKin_end` takes a `closeIt` parameter and closes and zips only on `k_onlyOne` or `k_last`, so the file stays open across cohorts. Family and individual numbers now continue across the cohorts that share one file, through `gFirstFamilyInFile`, `gFirstRelativeInFile` and `gIndividualsInFile`, reset only when a new file is opened. `indEgo` stays the per-cohort counter, because the main loop tests it against `nEgoPar`; the file-wide family number is `gFirstFamilyInFile + indEgo`. The closing message reports the totals for the whole file.
- **6.1a, the seed race.** `initRandomized` used the RTL `random()`, which is not thread-safe, and every worker called it from its own thread, so two threads could receive the same seed and generate identical genealogies. Seeding now happens in the three thread constructors, on the main thread, through the new `initWithSeed` and `nextThreadSeed` in `RandomNumbers.pas`. The three re-seeds inside the thread bodies are gone, so a thread also keeps one continuous stream instead of restarting it on every batch.
- **B4.** `header_GEDCOM` no longer writes to the DemoCare-only link file, and uses a comma like every other header.
- **3.2.** A throwaway `aCommand_raw` in `function command`, so the second `extractCommand` call no longer overwrites the command name with the raw text.
- **2.1.** A `msElapsed > 0` guard before the egos-per-second division in `individualKin_mid`.
- **D5b.** `readDemocareFile` reads the `relative` column through `GetEnumValue (TypeInfo(KinTypes), ...)` when the extended layout is present, so kin types survive the round trip.
- **D5a.** The reverse marriage row re-types the second party only when it is still `kt_nonBio`, so it cannot undo what D5b restored.

**Before the audit.** Per-format kin sets with the swap in `TKinFmtComboBoxChange.myGetValue`; the hardcoded DemoCare kin set removed; `DEMOCARE_LARGE_FIELDS` replacing the `DUMPALL` binding; the `LazDemoCareFields` dialog; the per-format dispatch of the optional-fields button.
