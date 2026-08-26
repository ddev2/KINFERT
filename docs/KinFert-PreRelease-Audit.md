# KinFert pre-release audit: the individual-file output path

Date: 24 August 2026. Reviewed at commit state of the working tree (uncommitted changes from the DemoCare kin-set and field-list work included).

## Scope and method

The review covers the path that produces individual genealogy files: format selection, kin-set selection, field-set selection, the three writers and their headers, the DemoCare link file and reader, file lifecycle across cohorts and bootstrap replicates, the settings-file round trip for every output option, and the thread safety of the code that produces and writes the trees.

Six independent reviews were run over the same snapshot, each on a different dimension. Every finding below was then re-read against the source by hand before being written down; anything that could not be confirmed that way is marked as such. Two questions that depended on compiler semantics were settled by downloading Free Pascal 3.2.2 and running test programs rather than by reasoning.

Files reviewed: `Kinship.pas`, `Declarations.pas`, `Init.pas`, `ReadCmdFileUnit.pas`, `SpecialRuns.pas`, `Utilities.pas`, `inheritance.pas`, `ComponentHelper.pas`, `LazOutput.pas`, the four selection dialog units, `kinfert.lpr`, `kinfert.lpi`, `Defines.pas`.

Files **not** reviewed because they were not part of the snapshot: `RandomNumbers.pas`, `Memory.pas`, `StringOfLib.pas`, `DemographicRegime.pas`, `Fertility.pas`, `Nuptiality.pas`. Section 6 lists what remains unanswered because of that.

---

## Status as of 24 August 2026 (second pass)

Fixed in the working tree, all verified by re-reading the changed regions:

| Item | What changed |
|---|---|
| 0.1 | `TKinFmtComboBoxChange.mySetValue` restored |
| 1.2 | key field moved after the `OUTPUT_KINTYPES` filter in `writeKinEgoGenealogy` |
| 1.4 | `getPartnershipStatus`: comparison direction corrected, missing `else` added |
| 1.5 | `readDemocareFile`: `DemocareTypes` aligned with the written columns, header sentinel and `offset_idFamily` corrected, sex column offset added, nil dereference after "Link not found" removed, handle leak on the early exit closed |
| 1.6 | DemoCare `nChildren` now written for every relative, not only ego |
| 1.7 | bootstrap replicates sharing one file are appended, header written once |
| 1.8 | the DemoCare link file no longer overwrites `fname`, so zipping targets the main file |
| 1.10 | DemoCare key column header separator changed from tab to comma |
| 1.11 | `arrayKinBranchUp` for grandmother and great-grandmother now keep the male ancestor |
| 1.12 | `getAncestry` great-grand-niece block now guards on `kt_greatGrandNieceNephew` |
| 1.13 | `kt_total` row enabled in 11 of the 12 printing loops |
| 1.14 | `g_InfoParents` replaced by `setInfoParents`, called before the arrays are sized; the three parent/partner divisions are guarded against a zero denominator |
| 1.15 | `gChildren` (x2), `g_RangeYearUnionsNotFound` and `g_RangeBridesForGrooms_NotFound` now use `InterlockedIncrement`; the two stale "MAIN THREAD only" comments corrected |
| 1.16 | off-by-one removed from both ego-budget conditions |

Partly addressed: **1.9**. The underlying behaviour is unchanged, because a fixed sequence genuinely cannot be reproduced while several threads draw in an order that is not determined. What changed is that the program now says so instead of ignoring the option silently: the "Same Random Sequence" checkbox in the Config dialog is disabled and relabelled when MULTITHREADING is on, with an explanatory hint, and a warning block is written to the log at run time when a configuration file asks for both.

Not fixed, by decision: 1.1 (Daniel is reviewing it), 1.3 (GEDCOM to be implemented later), and the rest of section 2.

Open decisions recorded during the fixes:

- **`getPartnershipStatus` and `end_by_death`.** A union always ends, by separation, by the relative's own death, or by widowhood. The corrected function returns `widow` for both widowhood and the relative's own death, which is what the old code effectively did. A relative whose union ended by their own death is not alive at the reference age at all, so a distinct value may be wanted.
- **`secondUnions` and `everInUnion` are never returned** by `getPartnershipStatus`, in the old code or the new one. Only the first union is examined.
- **`kt_total` in the "Statistics on kin" table.** That table reads `g_momEcAge`, which is the one array with no `kt_total` bucket accumulated. Enabling the row there would print zeros, so that loop was left alone. Adding a genuine total would mean deciding what the mean age of "all kin together" should be.
- **Keys are not only a bootstrap mechanism** (see the note on finding 1.10 below), so removing bootstrapping will not remove them.

---

## 0. Build blocker, introduced during this session and already fixed

**0.1 `TKinFmtComboBoxChange.mySetValue` had been deleted.**
`ComponentHelper.pas:180` declares it `override`, and the base class declares it `virtual; abstract` at line 93, but the implementation was gone. FPC would have refused to compile the unit. The `git diff` shows the whole procedure was removed when the duplicate `myGetValue` was cleaned up. That was my mistake: I identified the duplicate block correctly but did not notice that `mySetValue` had gone with it. I have restored it verbatim at `ComponentHelper.pas:848`.

Worth knowing what it does, because it matters for two findings below: `mySetValue` is what fills the format combo box and pushes the stored parameter value into the widget, and it is the only place that calls `selectFields` at form-load time. Without it, a configuration loaded from file would not be shown correctly in the Output dialog.

---

## 1. Wrong or lost output

These change what a user gets, silently. I would treat all of them as release blockers.

**1.1 Multi-cohort runs keep only the first cohort, and with zipping on they keep nothing.**
`individualKin_init` opens the file only on the first cohort, which is correct: `Kinship.pas:7739` passes `openFile` as `(loopPhase = k_onlyOne) or (loopPhase = k_first)`. But `individualKin_end` at `Kinship.pas:7902` is called at the end of **every** `simulateKinship` call with no phase guard, and it closes the file at `7490`. `TFileType.myCloseFile` does not clear `fileOpenToWrite`, and `cWrite` only tests that flag, so writes for cohorts 2..N go to a closed handle, fail with IO error 103, and are swallowed by `{$I-}`. No message appears.

With `ZIP_INDIVIDUAL` on it is worse. `zipIt` deletes the target `.zip` before creating it and deletes the source afterwards, so cohort 2's `individualKin_end` destroys cohort 1's archive and then fails to build a new one because the source is gone. Final state: no genealogy output at all, and the run reports success.

Trigger: any run where first cohort differs from last cohort, with individual kinship output on.

**1.2 A stray key field is written before the kin-type filter, corrupting the CSV.**
`Kinship.pas:3658` writes `RP.key` and its separator, then `Kinship.pas:3662` exits without a newline if the relative is not in `OUTPUT_KINTYPES`.

```pascal
result := False;
if RP.wKey then bWrite (gOutFileIndivKin, [RP.key, sep]);
idEgo := pEgo^.indNumber;
with pRelative^ do begin
    if not (typeOfKin in g_GENPARAM.OUTPUT_KINTYPES.value) then exit;
```

That exit fires routinely, because `writeKinship` admits relatives using `gKinToSimulate`, which `setKinshipToSimulate` builds as a strict superset of `OUTPUT_KINTYPES`. Select only children, and `gKinToSimulate` also contains ego and partner; both write a bare `key,` fragment that is then glued to the front of the next real row, shifting every column on it.

`RP.wKey` is true for any parameter-step run or for bootstrap into a single file. The sibling writer `writeKinDemoCare` gets the order right, writing the key at `3563` after its early exits, which suggests this is an ordering slip rather than intent. The fix is to move line 3658 down, inside the `with`, after the guard.

**1.3 Choosing GEDCOM produces a file with a header and no data, and reports success.**
`Kinship.pas:7364-7367` substitutes ego genealogy, but `fileFormat` is a by-value parameter of `individualKin_openFile` and `individualKin_init`, so the substitution is local. The caller's variable, set at `7734`, is still `out_GEDCOM` when it reaches `writeKinship` at `7589`, `7849` and `7869`, which dispatches to `writeKinGEDCOM`, whose entire body is `result := False`. The header is written, no rows are, and the log still prints a non-zero individual count. GEDCOM is selectable in the combo box, so a user can pick it and get a plausible empty file.

**1.4 The DemoCare `partnershipStatus` column is wrong for every relative who has been in a union.**
`Kinship.pas:3285-3296`. The final `if` has no `else` in front of it, so it unconditionally overwrites whatever the preceding `if / else if` assigned:

```pascal
if getAgeUnion (pRelative, 1) - pRelative^.ageAtBirthOfEgo < ageRef then
    getPartnershipStatus := neverInUnion
else if getAgeEndUnion (pRelative, 1) - pRelative^.ageAtBirthOfEgo <= ageRef then
    getPartnershipStatus := firstUnion;
if (getCauseEndUnion (pRelative, 1) = end_by_separation) then
    getPartnershipStatus := separated
else
    getPartnershipStatus := widow;
```

Every relative with `nUnions > 0` comes out as `separated` or `widow`; `firstUnion` is unreachable. Separately, the comparison at the first line looks inverted: a relative's age at ego's reference age is `ageRef + ageAtBirthOfEgo`, so a union that has already happened by the reference satisfies `ageUnion - ageAtBirthOfEgo < ageRef`, and the code returns `neverInUnion` for exactly those. The `isFirstUnion` parameter is never read in the body.

**1.5 `readDemocareFile` cannot read the files KinFert writes.**
Three separate faults, all in `Kinship.pas:1877-1890`.

The header sentinel tests `Header[5] <> 'tickIn'`, but `header_democare` writes `idFamily,id,sex,age,ageDef,status,tickIn,...`, so `Header[5]` is `status` and `Header[6]` is `tickIn`. Every file this program writes is rejected with "Not a Democare Kinship file". The check matches only the legacy header still recorded in the comment at `1886-1888`, from before `idFamily` was added.

The `offset_idFamily` detection tests `Header[1]`, but `idFamily` is `Header[0]`. For a file that does contain `idFamily`, `Header[1]` is `id`, so the offset is set to 1, the opposite of what is intended. The offset is also applied with inconsistent sign: subtracted at `1890`, added at `1757-1760`. And `Kinship.pas:1766` omits the offset entirely where every neighbouring line applies it.

`DemocareTypes` at `Kinship.pas:224` is stale. It still contains `dt_linked` and `dt_useful`, which correspond to the two writes commented out at `3575` and `3577`, so it has 18 members against 16 written columns. It is used as a positional index, and it is correct for ordinals 0 to 7, off by one from `dt_ego`, and off by two from `dt_partnershipStatus` onward. `dt_alliance` is also written under the header name `byUnion`.

Also on the `exit` at `1879`, `f.Destroy` is skipped, leaking the handle.

**1.6 `nChildren` is 0 on every non-ego row of the extended DemoCare file.**
`Kinship.pas:3501` initialises it to 0, `3506-3507` assigns it only inside `if isEgo`, and `3585` writes it for every row. A relative with four children is indistinguishable from a childless one.

**1.7 Bootstrap replicates overwrite each other when the multiple-files option is off.**
`Kinship.pas:7369-7372` sets the numeric suffix only when `OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES` is on. With it off, every replicate reopens the same name, and `openFileOut` defaults to `f_rewrite`, so it truncates. Only the last replicate survives. That is precisely the configuration the key column exists to support, a single file whose rows carry a run tag, so the intent was clearly to accumulate. The previous `TFileType` object is also leaked on each reopen.

**1.8 With DemoCare and zipping, the wrong file is compressed and deleted.**
`fname` is a `var` parameter. At `Kinship.pas:7394-7396` it is overwritten with the `_link` file name, and that is the value that reaches `individualKin_end` and `zipIt` at `7500`. The small link file is zipped and deleted; the large `_indKin.txt` is left alone.

**1.9 Results are not reproducible whenever multithreading is on.**
`ReadCmdFileUnit.pas:1577` reads

```pascal
if g_GENPARAM.INIT_RANDOM_NUMBERS.value and not g_GENPARAM.MULTITHREADING.value then
```

so the deterministic seed path is skipped entirely when multithreading is enabled, and `1582-1583` calls `randomize` plus `initRandomized`. Each worker then re-seeds itself from entropy at `Kinship.pas:6655`, inside the work-item branch, so it re-seeds on every batch rather than once. The same pattern appears in the motherhood threads at `2730` and `2765`.

There is no master seed, no derivation of per-thread seeds, and no seed written to the log. Two runs of the same configuration file give different genealogies and different aggregate tables. For a program about to be published this is the finding I would fix first: the results in a paper cannot be regenerated, not even by you.

A second layer sits underneath it. Even with fixed seeds, the mapping from ego to random stream depends on `optimalNumberOfTrees`, which is derived at `Kinship.pas:7658` from a 20-tree stochastic pilot run, and on `gMaxThreads`, which is the machine's core count. So an 8-core and a 32-core machine would still diverge. A design that survives this needs the stream derived per ego, something like `f(masterSeed, cohort, egoIndex)`, so that it is independent of how the work is scheduled.

**1.10 The key column separator differs between header and rows in both DemoCare files.**
`Kinship.pas:7280-7281` writes `['key', tab]`; the rows at `3563`, `3612` and `3622` write `[RP.key, comma]`. Everything else in both files is comma separated, so with keys on the header parses as one field fewer than the body. `header_EgoGenealogy` gets this right at `7296`.

**1.11 Selecting a grandparent does not bring the intervening male ancestor into the simulation.**
`Kinship.pas:5815` and `5823`:

```pascal
arrayKinBranchUp [kt_grandMother] := arrayKinBranchUp [kt_father];
...
arrayKinBranchUp [kt_greatGrandMother] := arrayKinBranchUp [kt_grandFather];
```

Every other line in that table has the form `X := [predecessor] + up[predecessor]`, for instance `kt_sibling := [kt_father] + up[kt_father]`. These two drop the predecessor itself, so `up[kt_grandMother]` is `{kt_ego, kt_mother}` with no `kt_father`, and `up[kt_greatGrandMother]` omits both `kt_father` and `kt_grandFather`. Because `up[kt_grandFather]` is built from `up[kt_father]` rather than from `up[kt_grandMother]`, selecting a grandfather does not pull in the father either. Meanwhile `ancestorsAndTheirOffspring` creates those men regardless, so they exist in the tree but are excluded from `gKinToSimulate`, from the output file and from the aggregate totals.

I flag this as a probable copy-paste slip rather than a certainty, because only you can say whether the demographic intent was to treat the grandmother as reachable without the father. The asymmetry with the sibling line is what makes me think it was not.

**1.12 A guard in `getAncestry` tests the wrong kin type.**
`Kinship.pas:6013`:

```pascal
{great grand niece/nephews => DESCENDANCE 3}
if allKin or (kt_grandNieceNephew in relativeSet) then begin
    while calcStateMan(randomGenerator, kt_grandNieceNephew, kt_greatGrandNieceNephew, ...
```

Every parallel block guards on the type it produces; this one guards on the type it starts from, and the block immediately above at `6006` already uses that same guard for grand-nieces. Select grand-nieces without great-grand-nieces and the latter are generated anyway. They consume random numbers, which shifts the stream for every later ego, and they are counted by `addToTableKinship`, which walks the whole relative list with no kin-set filter, yet they are excluded from the totals because they are not in `gKinToSimulate`.

**1.13 The "total" row is missing from every kinship table.**
The printing loops run `for typeOfKin := kt_ego to kt_total do` and then test `if (typeOfKin in gKinToSimulate)`. `kt_total` can never be in that set: `kLastKinInEnum = kt_nonBio` (`Declarations.pas:88`), the kin-selection dialog gives `kt_total` an empty name, and `readKinSet` stops at `kLastKinInEnum`. So the accumulated total is computed and never printed, in every run. This affects at least eleven printing loops in `Kinship.pas` between lines 6984 and 7261.

Two consistency problems sit alongside it. The total is summed over `gKinToSimulate` while the counts are accumulated over every relative in the list, so any kin created as a by-product of findings 1.11 and 1.12 appears in its own column but not in the total. And `addToTableKinship` re-labels every relative whose `kinOf` is not ego as `kt_nonBio` regardless of the `NON_BIO_KIN` option, while `kt_nonBio` only joins `gKinToSimulate` when that option is on, so two different totals in the same output disagree.

**1.14 `g_InfoParents` is a one-way latch, and the second run in a session accumulates on stale arrays.**
Declared `true` at `Kinship.pas:241`, assigned `false` at `1867` and `7737`, never assigned `true` anywhere. It gates the `SetLength` and the zeroing of `g_fertilityEgoMothers`, `g_NumChildrenEgoMothers` and `g_UnionTableEgoParents` at `728-768`, and their release at `1738`.

The allocation happens in `initComputeStatesKinship`, called once per run before the cohort loop; the latch flips later, inside `simulateKinship`. So a first DemoCare run allocates and zeroes, then flips the latch, then skips the release. A second run in the same session skips allocation **and zeroing**, while the writers at `1009` and `1013` are not guarded, so run 2's counts pile onto run 1's. `TFR_egoMothers_NC` is then computed from the contaminated totals and written to the aggregate table. If run 2 uses more cohorts than run 1, the index goes past the stale array length; with `{$rangeChecks on}` in `Defines.pas` that raises rather than corrupting memory, which is at least a loud failure.

**1.15 Three counters are incremented non-atomically from worker threads.**
`gChildren` at `Kinship.pas:4808-4809`, `g_RangeYearUnionsNotFound` at `5083`, and `g_RangeBridesForGrooms_NotFound` at `5161`, all reached from `calcKinship` on every worker. Plain `Inc` on a shared `longint`, so increments are lost non-deterministically. The code uses `InterlockedIncrement` elsewhere for exactly this, so the fix is mechanical.

`gChildren` matters most because it feeds a reported number: `Kinship.pas:7971-7974` computes the cohort total fertility at 50 from it, and numerator and denominator lose counts independently, so the ratio is biased rather than merely noisy. The two "not found" counters are the diagnostic a referee would use to judge the bride-matching quality of the model, and they under-report.

Note the comment at `Kinship.pas:298-311` marks the last two as "global used in MAIN THREAD only". That comment is wrong. The author's own marker at `Declarations.pas:1162` asks for exactly this audit to be done.

**1.16 The multithreaded path can simulate one ego more than requested.**
`Kinship.pas:7544` and `7814` both read

```pascal
if ( (indEgo + totalNumberOfEgosToSimulateInThisBatch + optimalNumberOfTrees - 1) <= pDemReg^.lp[nEgoPar].value) then
```

The `- 1` lets one chunk too many through when the remaining budget is exactly `optimalNumberOfTrees - 1`. With 999 egos and 8 threads the chunk size is 125 and the eighth thread is still given a full chunk, so 1000 families are written where 999 were asked for. The single-threaded branch writes 999. Condition: `nEgoPar` congruent to -1 modulo the chunk size.

---

## 2. Crashes, hangs and leaks

**2.1 Division by zero in the progress reporting, outside the exception handler.**
`Kinship.pas:7454` divides by `msElapsed`, which is integral milliseconds and is 0 whenever less than one millisecond has passed. `Kinship.pas:7605-7607` does the same three times over, and there it is not merely a timing race: `writeTreesToFile` iterates the whole batch range while `startBatchOfThreads` only dispatches threads with work, so a thread given zero egos has `tCompute = 0` and `myNumTreesStored = 0`, giving 0/0. No `SetExceptionMask` call exists anywhere in the project, and this code sits before the `try` block that starts at `7917`, so the exception unwinds out of `simulateKinship` with the output file still open.

**2.2 The BATCH path is not in a releasable state.**
Four separate faults, all triggered by the BATCH checkbox.

`Kinship.pas:7803` calls `Destroy` on thread objects created with `FreeOnTerminate := true` at `6581`. FPC frees such a thread itself when `Execute` returns, so this is a double free.

`CleanUp` is never called on the BATCH path, and `TSimulEgoTree.Destroy` frees nothing (its body is just `inherited Destroy` plus an unused local). So every tree, every per-thread `arrayChildren` and every per-thread random generator leaks. For a large run that is the dominant allocation of the whole program.

The sizing arithmetic at `7675-7679` provisions for `gNumThreadsUsed * opt * nBatches` egos but each thread is used once per pass, so one pass produces about half of `nEgoPar`. The outer `while` at `7751` then re-enters and calls `simulate` on the objects destroyed at `7803`.

`Kinship.pas:7687-7699`: the non-BATCH arm clamps `gNumThreadsUsed := gMaxThreads`, the BATCH arm does not, leaving it at `ceil(nEgoPar / optimalNumberOfTrees)`. With a million egos and a chunk size of 1500 that is 667 OS threads created at `7705`, each spinning at full speed.

My recommendation is to disable the BATCH option for this release and fix it afterwards, rather than to try to repair it under release pressure.

**2.3 The thread handshake is unsynchronised and published in the wrong order.**
`FAFinished`, `myExecuteIt` and `myNumTreesStored` are plain fields with no event, no critical section and no barrier. In `Simulate` at `6633-6638` the go-flag is set **before** the busy-flag is cleared and **before** the tree count is published:

```pascal
if FAFinished then begin
    myExecuteIt := true;
    FAFinished := false;
    myNumTreesStored := numEgos;
```

If the main thread is preempted after the first line, the worker can finish and set `FAFinished := true`, which the main thread then clobbers, and both spin loops wait forever with no timeout. The worker can also read the previous `myNumTreesStored`; on a first use that is 0, which makes `meanNumberOfKin` return 0 and the next line, `trunc(600000 / meanNumberOfKin)` at `7658`, raise.

The absence of a memory barrier matters on your own hardware: `Defines.pas` defines `ARM` for `CPUAARCH64`, so the Apple Silicon build runs on a weakly ordered machine where the main thread can observe `FAFinished = true` before the writes to `pMyEgos` are visible.

**2.4 Every wait is a hot spin with no yield.**
`Kinship.pas:6647` in the worker, `7550` and `7824` in the dispatcher, `7563` and `7830` in the main thread, `Utilities.pas:276` in the file class. Idle workers stay alive for the whole cohort and burn a core each. On a laptop that means throttling and a wall-clock time that can be worse than single-threaded. `Simulate` also calls `Now()` on every spin iteration at `6626`, racing the worker's own write to the same 8-byte field.

**2.5 A file-open failure leaks the open main file, all threads, and skips the aggregate tables.**
`Kinship.pas:7397-7402` returns after the link file fails to open, leaving `gOutFileIndivKin`, opened four lines earlier, open. `simulateKinship` then does a bare `exit` at `7740`, which skips `writeTables`, skips `DestroyArrayChildren`, and skips all thread cleanup, leaving the workers spinning for the rest of the process. The same call also assigns `[kt_none]` into the global `gKinToSimulate` at `7432`, so the kin set is invalid until the next `run_all` rebuilds it.

Trigger is ordinary: output directory read-only, disk full, or the file open in Excel.

**2.6 An unconditional infinite loop, currently unreachable.**
`Kinship.pas:7955-7958`. `allThreadsTerminated` starts false and the body is `allThreadsTerminated := allThreadsTerminated and ...`, so it can never become true. It also dereferences objects that were just terminated and are `FreeOnTerminate`. It is dead today because `allThreadsCleanedUp` is set at `7913`, but it will hang the program the first time that changes.

---

## 3. Settings file round trip

A parameter that is saved but not reloaded means a user cannot reproduce their own run from their own configuration file. For a published tool that is worth the same attention as a wrong number.

| Parameter | Constructed | Default set | Written | Read | Effect |
|---|---|---|---|---|---|
| `OUTPUT_KINTYPES_STD` | yes | yes | **no** | **no** | per-format kin memory resets at restart |
| `OUTPUT_KINTYPES_DEMOCARE` | yes | yes | **no** | **no** | same |
| `MULTITHREADING_SIMKIN` | yes | yes | **no** | **no** | has a GUI checkbox; changes whether the run is threaded |
| `USE_ARRAY_CHILDREN` | yes | yes | **no** | **no** | changes the child-storage path |
| `DUMP` | yes | yes | **commented out** | yes | settable only by hand editing |
| `STABLE_POPULATION` | yes | yes | **commented out** | yes | settable only by hand editing |
| `FILENAME` | yes | yes | flag never set | yes | dropped under the default `WRITE_ONLY_CHANGES` |
| `MAX_THREADS` | yes | yes | skipped as unchanged | yes | default is the machine core count, so never saved |

The `MULTITHREADING_SIMKIN` case is the sharpest. A user who unticks it to get a deterministic single-threaded run, saves, and reloads, gets it ticked again with no warning. Combined with finding 1.9 that is a quiet path back to irreproducible output.

`OUTPUT_KINTYPES_STD` and `OUTPUT_KINTYPES_DEMOCARE` are the two you decided not to save. Worth reconsidering in the light of the above: as it stands, loading a saved configuration and then touching the format dropdown replaces the loaded kin selection with the compiled-in default for the other format.

Four more in the same area:

**3.1 `DUMPALL` writes an almost empty "detailed" file under default settings.** `ReadCmdFileUnit.pas:1016-1021` and `1026` skip every array whose `changed` flag is false, and those flags are set only when the array was present in the input file. With `WRITE_ONLY_CHANGES` defaulting to true, the file the user asked for to inspect the model's internal tables contains the two headers and no tables.

**3.2 Hand-edited lowercase commands are rejected, contradicting the file's own instructions.** `ReadCmdFileUnit.pas:1206` passes `aCommand` a second time as the `out` parameter, this time from the raw un-upcased line, so `aCommand` ends up holding the original text. A user writing `kinship=on` gets `UNKNOWN COMMAND` and the whole file is abandoned, while `ReadCmdFileUnit.pas:841` writes a comment into every generated file promising that case does not matter. One-line fix: give that second call a throwaway variable.

**3.3 Duplicate `CHECK_DATASTRUCT` branch** at `1265` and `1305`. Identical bodies, so harmless, but the second is dead and editing it would have no effect.

**3.4 `fn_yDeathFloat` has no checkbox.** `lazkinoutputfields.pas:81` lists it and `Init.pas:470` puts it in the default field set, but the `.lfm` has 21 checkboxes for 22 enum members and `yDeathFloatSelect` is the missing one. The column is written into every genealogy file and cannot be switched off from the GUI.

**3.5 Misspelled commands are reported but the batch exit code still says success.** `readCmdFile` returns false and the run is abandoned, yet the caller still prints the finished banner and returns true, so a scripted caller sees success for a configuration that never ran.

---

## 4. Output hygiene and dead code

**4.1** `writeKinDemoCare` is called with `checkLinks = false` from the only call site, `Kinship.pas:3881`, so the block at `3545-3561` never runs. Its comment says it drops relatives who died before ego's reference age. That filtering therefore never happens, and the DemoCare file contains those relatives carrying a negative `tickOut`. Decide whether the filter was meant to be active; if not, delete the block and the `checkLinks` parameter.

**4.2** The link file has structural gaps. Marriage rows can name an id that was never written to the main file, because the row is emitted for every partner of a written relative while inclusion in the main file is decided separately. Descent rows are written only for `kt_child` and `kt_grandChild` that are not by-union, so no ascending link is ever recorded, and since the reader types every non-ego row as `kt_nonBio` and rebuilds structure solely from the link file, the ascending half of the network cannot be recovered. Marriage rows are also emitted twice, once from each partner, and the reader overwrites `typeOfKin` on the reverse row. After "Link not found" at `1934` the code falls through and dereferences a nil pointer.

**4.3** `writeKinship` at `3879` counts every relative that passes `includeKinInNetwork`, ignoring whether `writeKin` actually wrote a row, so the reported individual count exceeds the rows in the file whenever finding 1.2 fires.

**4.4** Family and individual ids restart at 1 for every cohort, at `Kinship.pas:7727` and `7742`, while the file is meant to span cohorts. Currently masked by finding 1.1; fixing 1.1 without fixing this gives a file with duplicate ids and cross-referencing that silently joins the wrong people.

**4.5** `header_GEDCOM` at `7343-7344` writes to `gOutFileIndivKin_link`, which is only ever opened for DemoCare. Unreachable today, but it is a write to a stale handle waiting to happen. Delete the three dead GEDCOM branches or implement the format.

**4.6** The header name `heirs` appears twice when the debug block is on, and the user-facing `heirs`, `decedents` and `share inheritances` columns are written from the second-algorithm variables `str_heirs_2`, `str_decedents_2`, `str_shareDecs_2`, which is also what the debug columns named `heirs_2` and so on contain. R and pandas will silently rename the duplicate, and a user selecting `heirs` gets the second algorithm while believing otherwise.

**4.7** Empty-value sentinels are inconsistent across the multi-value fields: `0` for no partners, `-1` for a nil partner, `-1` for no inheritance shares, and empty strings for the second-algorithm heir columns. Downstream numeric conversion sees a mixture of 0, -1, empty and NA for the same "nothing here" state.

**4.8** `'ERROR ==> tontou!!!!'` at `Kinship.pas:3509`. The condition behind it is real, and it is already reported one line earlier inside `CalcChildren`, so the message is redundant as well as unshippable. Note that in the GUI build `writeAndWait` no longer shows a dialog, but it does latch `gDebugError`, which makes the run finish in the error state.

**4.9** `checkInheritanceStatus` in `inheritance.pas:82-97` has no `exit` after the first warning, so it fires once per missing kin type, up to 21 times per cohort per bootstrap replicate, and each one latches `gDebugError`. In a console build `writeAndWait` waits on `readLn`, so a batch run blocks. This fires more often now that DemoCare narrows the kin set.

**4.10** The four selection dialogs never free the `BooleanName` objects created in `componentsInfoCreate`, leaking 16 to 24 objects per open. Worth fixing because the project runs with `useHeapTrace` and this will bury real leaks.

**4.11** `tStart_interm` is read at `Kinship.pas:7968` but assigned only inside `if TALKATIVE`, so with that option off the reported duration is garbage. Every other call site is guarded.

---

## 5. Cleared: things that look wrong but are not

I checked these because they were raised during the review and would have been serious. Recording them so they are not re-investigated later.

**5.1 Initialized local variables are reset on every call.** This was the one that mattered most, because the code uses `n: longint = 0` inside procedures throughout, including `idFather`, `idMother`, `nbRelatives`, `nIndividuals` and `checkSumShareHeirs`. The classic Free Pascal documentation describes initialized locals as static, which would have made `idFather` carry the previous relative's value whenever a father was nil, fabricating parent links across the whole genealogy.

I downloaded FPC 3.2.2 and tested it, both in `objfpc` mode and default mode, with optimisation off:

```pascal
procedure p(k: longint);
var n: longint = 0;
begin n := n + k; writeln('n=', n); end;
```

printed `n=1` three times, not 1, 2, 3. They are re-initialized per call. All findings that depended on the static reading are withdrawn.

**5.2 `includeKinInNetwork` and `writeKin` do assign their result on every path.** Neither has a final `else`, but `Kinship_FileFormat` is the subrange `out_EgoGenealogy..out_GEDCOM` and all three values are handled. It becomes an uninitialized boolean the moment a fourth format is added, so add the `else` when you add GEDCOM.

**5.3 The output file is written only from the main thread.** I traced the full call graph: `writeKin` has one caller, `writeKinship` has three, all in the body of `simulateKinship`. No worker touches the file, and the file is opened non-async so writes are direct. Record order is deterministic given the partition. The `indThread` parameter threaded through `writeKinship` and `writeKin` is unused.

**5.4 Logging from worker threads is correctly marshalled.** `memoWriteLn`, `flushIO` and `writeAndWait` all go through `Application.QueueAsyncCall`, which is thread-safe in the LCL, and the debug file is guarded by a critical section. The queue is unbounded, so a very long run grows the heap, but there is no GUI access off the main thread.

**5.5 `nThreadsInBatch := round(gNumThreadsUsed / nBatches)` cannot divide by zero.** The branch conditions force `nBatches >= 1`. It is an accident of the arithmetic rather than a designed invariant, so a `max(1, ...)` guard would be cheap insurance.

**5.6 The calibration thread object is correctly not destroyed.** `Kinship.pas:7661` has `Destroy` commented out, which looks like an oversight but is right: `CleanUp` plus `Terminate` plus `FreeOnTerminate` handles it, and uncommenting the line would create the double free described in 2.2. Worth a comment saying so.

---

## 6. Open questions, needing files not in the snapshot

**6.1 `RandomNumbers.pas`.** Does `TRandomNumberGenerator` keep all state in instance fields, or does it touch the RTL `RandSeed`? `ReadCmdFileUnit.pas:1582` calls the bare RTL `randomize` immediately before `gRandomGenerator.initRandomized()`, which is what you would write if the class wrapped the global. If it does, all workers share one stream and the draws are correlated, which is a second and independent reproducibility failure. This is the single most important thing left to check. Note that finding 1.9 does not depend on the answer.

**6.2 `Memory.pas`.** Do `newPtr` and `disposePtr` maintain a global allocation registry? If so, every allocation in the worker path is an unguarded shared-state mutation.

**6.3 `StringOfLib.pas`.** How does `cStringOf` render a `boolean` and a `double`? Two things hang on it. If booleans render as `1`/`0` rather than `True`/`False`, then all 27 result-table switches silently reload as false, because the reader accepts only `ON` and `TRUE`. And if doubles are rendered with `DefaultFormatSettings` rather than `gFormatSettings`, then on a Spanish or French locale the five raw double columns in the genealogy file emit a decimal comma into a comma-separated file. Five minutes with a real dump file would settle both.

**6.4 `DemographicRegime.pas`.** Is `ArrayOfDoubleName.setDefault` ever called? It is not called anywhere in the files I read, and `default` is left nil by the constructor, yet `setChanged` and `myCheckChanged` both index it. With range checking on that raises; the consequence would be that `APRIORI_PPR`, `EFF_STOPPING`, `EFF_SPACING` and `MEAN_TIME_SPACING` are randomly present or absent from saved configurations.

**6.5 `Fertility.pas`.** `calcCompleteFertilityWoman` is called from every worker, right beside the `gChildren` race in finding 1.15. It has not been audited for global writes.

**6.6 `initMotherhood`'s own threading** (`Kinship.pas:2685-3106`) was outside the scope I was given, but it uses the same `FAFinished` pattern and the same `initRandomized` calls, and it runs before `simulateKinship` and produces the shared arrays every tree is built from. Findings 1.9, 2.3 and 2.4 very likely apply there verbatim.

---

## Suggested order of work

1. **Reproducibility.** Findings 1.9 and 6.1. Introduce a master seed, write it to the log, derive each ego's stream from it independently of thread count. Acceptance test: run the same configuration at 1, 2, 4 and 8 threads and compare the genealogy files byte for byte. Today they differ in content, in order and, because of 1.16, in row count.
2. **Silent data loss.** Findings 1.1, 1.7, 1.8. A run that reports success must produce the file it claims.
3. **File corruption.** Findings 1.2 and 1.10, both one-line fixes.
4. **Wrong columns.** Findings 1.4 and 1.6, both small and both affecting DemoCare analyses directly.
5. **Races.** Finding 1.15, mechanical.
6. **GEDCOM.** Finding 1.3: either implement it or remove it from the combo box. Shipping a format that silently produces nothing is worse than not offering it.
7. **BATCH.** Finding 2.2: disable for this release.
8. **Kin-set correctness.** Findings 1.11, 1.12, 1.13. These need your judgement on demographic intent before any code changes.
9. **Round trip.** Section 3, in the order of the table.
10. **Reader and link file.** Findings 1.5 and 4.2, which together decide whether the DemoCare format is a round-trippable interchange format or a one-way export. That is a design question worth settling before the documentation is written.
11. Everything in section 4.

Items 8 and 10 are the two where I would not change anything without your decision, because they turn on what the model is meant to represent rather than on what the code says.
