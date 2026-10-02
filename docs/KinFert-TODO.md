# KinFert: what still needs you

**29 September 2026, restructured.** What is left to do, most urgent first. Three documents go
with it: `docs/KinFert-Verification-Plan.md`, which carries every check of the work done this month,
with a box beside each one; `docs/KinFert-FIXED.md`, the record of what is done and needs nothing;
and `docs/KinFert-Manual.md`, which is a deliverable of its own. What used to be section 2 of this
document, the list of checks by their V numbers and the note on how each one could be decided, is
now in the plan, which is where it belongs.

**30 September 2026.** The program builds and links, on macOS and on Windows, and `G1`, the one
defect that could hang an ordinary run, is fixed. The state of the work is: nothing known changes a
result on an ordinary run except the decision left at `Kinship.pas:5070`; everything else standing
is a guardrail against bad input, a fault on a path through the dialogs, a threading question, or a
decision. That is the basis on which the program is committed and published.

**1 October 2026, the manual.** Two pieces of it are new. The two target searches are
documented in §8.8 of `docs/KinFert-Manual.md`, in three subsections: what each one matches, how
the step is computed, when it stops, which pass or trial is kept, and how to read every line each
one prints in the log. And chapters 13 and 14, the two guided parts, are in place as a scaffold:
every heading, a note under each one saying what belongs there, and thirty-two figure slots with a
description of what each capture must show, registered in `docs/img/README.md`. The didactic text
is yours to write; `M8` below is what is left.

**1 October 2026, the two state files.** `P13` is done. `KinFert ConfigDir.cfg` and
`KinFert OutputDir.cfg` no longer sit next to the executable, where on macOS they fell inside the
application bundle and where a folder shared between a Mac and a Windows PC made each system
overwrite the other's paths. They are in the per-user state folder of each system now, under names
that say which system wrote them, and the first run after the change moves the old values across by
itself. The change is in `LazMain.pas`, it carries review markers, and `KinFert-FIXED.md` says what
was checked and what only a build in Lazarus can check.

**1 October 2026, the counts in the verification report.** One fault was being announced as three.
The groom cohort range was caught by its check, once per union, and summarised again through
`writeAndWait`, and the one line of the memo added the two kinds together while the table
subtracted them. The counts are now `verificationFailedChecks`, `verificationFailures` and
`verificationReports`, kept apart and documented, the memo line follows the table, and the groom
range summary is attached to its check as a note instead of being reported a second time. Two
lines of the same log that said something untrue went with it: the post-phase timer of
`simulateKinship`, which printed the time of day when `TALKATIVE` was off, and the explanation
under `Searches for a mother: none recorded`. `KinFert-FIXED.md` has the detail; the changes are
in `Verification.pas`, `Kinship.pas` and `LazMain.pas` and carry review markers.

**1 October 2026, the Children-Grooms tab.** A released build now offers only the first entry of
that tab, the unions produced by cohort of the groom, which describes a result; the rest describe
the machinery and appear only when the program runs from the IDE. The three charts that drew the
share of searches answered from another cell, and which in an ordinary run are an empty frame, are
joined by two maps of the pools themselves: one cell per cohort and year of age, blue where the
index has candidates nothing used, green where searches drew from it, red where a search asked and
found nothing. `KinFert-FIXED.md` has the detail. `LazGraph.pas` cannot be compiled outside
Lazarus, so that unit is the one piece of this audit that rests on reading alone: expect the
possibility of an ordinary compile error on the first build.

**1 October 2026, dead code.** Groups A and D of the inventory are gone or settled: the
grooms for brides arrays, the two lookup counters split by generation, the four ego counters, two
routines never called, and `cLabelsX` in `LazGraph.pas`; `gCheckRelativesMax`, a switch nothing
could set, is removed and its test says what it does; and the two child shortfall counters are
reported in the index coverage line where they mean something, which is under variable regimes.
The state arrays and `checkKinship` are kept, as you asked. One thing the inventory turned up is
not dead code at all and is now `N54` in section 7: the fertility of ego's partners is computed
from arrays that nothing fills, so those columns are zero in every run.

**1 October 2026, DemoCare.** Two faults from your reading of the DemoCare output. The status
column was empty in every row, because it carries the educational level and `EDUCATION` defaults to
none; the mode is now forced to stochastic when a DemoCare file is written with it unset, with a
line in the log saying so. And `Check DemoCare` failed with `fert is not a valid number`, because
the cohort of the egos was read from the fourth to the seventh character of the file name; it is
now the first four digits in the name that read as a year, and a name without one is reported
rather than raising. `KinFert-FIXED.md` has both, and §8.5 of the manual now describes the four
education modes, which answers one of the open questions of Appendix F.

**1 October 2026, a fourth education mode.** `eduStochasticFamily`, the three levels with equal
chances and the members of one family resembling one another, which is the one combination that was
missing and the only way to give a DemoCare file a plausible family structure without a cohort file
behind it. The four modes are renamed on screen so that they read as the square they are, with the
values in a configuration file unchanged, and §8.5 of the manual sets them out. The strength of the
association is a constant, `kEduFamilyCorrelation`, which is one line in `Init.pas` away from being a
parameter if you want to vary it.

**Review markers.** Done. You have read and accepted every marked region and the markers are
gone from the source. One deliberate marker is left, at `Kinship.pas:5070`, and it is a decision
rather than a change: item 6 of section 0 below, and the reasoning is in
`docs/KinFert-Alternate-Algorithms-Decisions.md`.

**Line numbers.** Every entry names its routine, and the routine name is the stable reference.
The numbers were last re-derived for sections 2 and 3 on 18 and 29 September and for section 8 on
6 September; `tools/check-line-numbers.py` prints the current ones after any edit.

---

## 0. Now, in order

1. **Commit, then cut the release.** The build is done on both platforms and the repository is
   ready: `.gitattributes` fixes the line endings, the working folders
   `JASS/`, `KINFERT_runs/` and `chatgpt/` are ignored, the README states the verification phase
   and pins Lazarus 4.6 with FPC 3.2.2, and `docs/KinFert-Verification-Plan.md` ships with the
   source. What is left of section 11 after the commit: tag it, attach the macOS and Windows
   binaries to the release with the note on Gatekeeper, and answer `P7`, `P8` and `P10`.
2. **Review `G1`, `LazMain.pas:706`**, fixed on 30 September and recorded in
   `docs/KinFert-FIXED.md`. `myLine` was never emptied, so after any `memoWrite` without a line
   feed the end of run message could never match and the worker thread spun for ever. One line.
3. **Do the set-up of the verification plan and its first comparison.** S1 to S4 build a binary
   from `HEAD` and the comparison tool; A1 then decides in one command whether a month of fixes
   left an ordinary run untouched. Until that is known, nothing built on top of it is safe.
4. **Answer what is left of Q3, and Q4**, in section 5. The part that mattered most is answered:
   descendants divide the estate by lineage, with representation, while ascendants and lateral kin
   are excluded by degree, an ascendant estate being divided by line at every generation and
   lateral kin of the nearest degree taking equal shares. That is what `N22` waited on. Still open
   in Q3: the posthumous child, the estate with no heir, and the usufruct. Q4 still blocks `N25`,
   and inheritance is the module you take up next month.
5. **Review the changes of 30 September**, recorded in `docs/KinFert-FIXED.md`. In inheritance:
   `N22` and `N22b`, the ascendants by degree and the shares by side of the family, and `N24`, the
   ancestor shared with a lateral relative, all three of which change results, and `N26`, the
   referee, which changes none. In nuptiality: `N51`. From the compile log: the check that could
   never fail in `FertilityRuntime.pas`, `init_waiting_time_distribution` turned into a procedure,
   `ageChildren` and two more parameters put in the right mode, and the nested comment in
   `Kinship.pas`. Nothing in the inheritance module is left that changes who inherits. `N25` is the
   one entry left and it waits on Q4.
6. **Decide the one marker left in the source**, `Kinship.pas:5070`: the mother found by the
   CAMSIM 1987 search is given the year of birth of her own child, so her reproductive life is
   simulated with the regime of the wrong generation. It is left as it is on purpose, since
   the correction changes results in that mode.
7. **The guardrails of section 3**, then the threading items of section 4. Neither changes a
   result today; both decide what happens when an input or a thread goes wrong.

---

## 1. What has to be verified

All of it is in **`docs/KinFert-Verification-Plan.md`**: the set-up that makes the checks
possible, one box per check with the run, the output file and the answer to expect, the table of
what each new verification id means if it speaks, and the older V numbers folded in. Nothing about
verification is kept here any longer, so that there is one place to tick things off.

Two things from that plan are worth repeating here, because they are decisions and not checks.
The first is **P6**: the reference configuration of S4, run with both binaries, is the regression
test the repository does not have. The second is in B2: with the new education rule, the `EDU_`
proportions of a cohort bind only the people at the top of each line of descent, so the levels
among egos are those the parent to child matrix implies. Whether that is what you want is a
modelling question, and it is the one open question left in the education module.

---

## 2. Results still wrong

Two defects of `inheritance.pas` change who inherits and by how much, and one more leaves the
country rule set with no effect. The referee that should have caught the first two, `N26`, is
fixed. Everything else that stood in this section is fixed.

### Inheritance, and it is next month's module

One entry is left, **N25**, at `2225`, and it waits on Q4. **N22**, **N22b**, **N24** and **N26**
were all fixed on 30 September. Nothing in the module now changes who inherits or by how much,
which means the three changes that move numbers, `N22`, `N22b` and `N24`, are the ones to review
before anything is built on them.

| | where | what, and how much |
|---|---|---|
| **N25** | `inheritance.pas:2225` | `lookForDecedents_Spain` has an empty body and the `inher_Spain` / `inher_Other` choice is never consulted. **The country rule set has no effect**: both algorithms run unconditionally |

### Everything else in this section is done

**Inheritance, the lateral relatives. `N24` is fixed on 30 September**, and the detail is in
`docs/KinFert-FIXED.md`. When a lateral relative of ego dies and the module collects the possible
heirs from ego's side of the family, it asked which of ego's parents is an ancestor of the dead
relative and then ignored the answer. It now uses it, as the first cousins block always did, so the
children of a parent of ego who is no relation of the dead person no longer take a share. Two of
the five call sites of `commonAncestor` were the faulty ones; at two others the answer is not
needed, because those collect the children of the dead relative's own parents, who are all blood
siblings of it, and the useless assignments there are gone with a comment saying why. **This one
changes results.**

**Inheritance, the ascendants. `N22` and `N22b` are fixed on 30 September**, and the detail is in
`docs/KinFert-FIXED.md`. The ascendants are now explored one generation at a time, and the first
generation that holds an heir is the only one that inherits, so a surviving grandmother excludes
every great-grandparent whichever side each of them is on. The estate is then halved between the
father's side of the family and the mother's side, and within a side the heirs of that side take
equal parts, a side with no heir leaving its half to the other, which is the rule you stated on
30 September. **These change results**, in the estates of people who leave no descendant and no
parent. Measured on a stub genealogy: a maternal grandmother who used to take one half of such an
estate, the other half going to a paternal great-grandfather, now takes the whole of it; and three
great-grandparents in three different lines, who used to take a third each, now take a quarter, a
quarter and a half.

**Inheritance, the referee. `N26` is fixed on 30 September**, and the detail is in
`docs/KinFert-FIXED.md`. In short: the first algorithm now records its own partner test for every
relative it examines, in one new field of the relative record, so a relative whose heirs are the
children is no longer prevented from also leaving a surviving partner who inherits. `checkHeirs`
compares the two answers without regard to the order of the two lists, takes account of
`PARTNER_FIRST_HEIR` and `PARTNER_FULL_HEIR`, says nothing when either algorithm did not look at
the relative, which is the difference of coverage that would otherwise read as a disagreement, and
records each kind of disagreement through four new verification ids. The branch that could not be
reached is gone. No simulated quantity changes.

**One limitation the referee now exposes, and it is not a fault of the referee.** The first
algorithm names one branch of the lateral tree, the sibling tree or the aunts and uncles or the
grand-aunts and grand-uncles, while the second applies the rule of the degree you stated, under
which every lateral relative of the nearest degree inherits together. A decedent with a living
first cousin and a living grand-aunt, both of degree 4, therefore receives two different answers,
and `inhHeirKinTypes` will say so. The second algorithm is the one that follows your rule. The
branch names of the first algorithm are also read as a gate in ten places of `checkEgoIsHeir`,
which is the question of whom ego inherits from, so this is not only a matter of reporting. Putting
it right changes results, so it is listed here rather than done.

**Education.** The cumulative distributions that were never rebuilt after a cohort file or
an interpolation, which was the largest defect of the week, `N17`, `N18` and `N20` are all fixed,
and the five `writeAndWait` sites of the unit are in the verification table. `Q5` is answered: a
person whose two parents are in the network takes the distribution conditional on the two of them.
What is left to do is to run it, which the verification plan covers, and to read what it produces: in the
intra-family mode the `EDU_` proportions of a cohort now bind only the people at the top of each
line of descent, so the levels among egos are those the parent to child matrix implies and no
longer the proportions asked for. If that is not wanted, the matrix has to be rescaled so that each
cohort keeps its own marginal distribution, which is a change to the model rather than a repair.

**Fertility and nuptiality.** `N32`, the exception that left the fate of a union to two undefined
values, `N29` and `N53`, the two nuptiality guards, `N4c`, the reshuffled fecundability, and `N10`,
the net reproduction rate, and `N51`, the standard deviation of the schedule of ages at first
union, are all fixed. Nothing is left on the fertility and nuptiality side.

**Threading.** `N34`, the parity counters, and `N42` and `N43`, the seed and the pool loop, are
fixed. What is left is not a wrong result but a wrong shape: section 4.

**Cohorts.** `N11` was read again on 29 September and is gone: `copyMeTo` no longer breaks the
chain, so an edit to the second cohort survives. I told you on 18 September that I had struck the
row and I had not; this is the correction.

---

## 3. Missing guardrails against out-of-range values

These leave results untouched while every input and index stays inside its range. They decide
what happens when one does not, and today that is a range error, a wrong cell, or a hang. The
first row is the one I would take first: it holds the only entries in either section that can
corrupt memory silently with range checks off.

Entries that left this section on 17 September: **N52**, which you did yourself by moving the
constant into `std_Logistic_Dani_2004` as a local named for what it does, and **N53**, fixed.

Entries that left it on 18 September: **N50**, fixed, and with it the duplication of the limits
between the dialog and the reader. And on 29 September **N49**, which you did yourself: `addChild`
declares its table `var` now that it accumulates into it, so the declaration no longer depends on
Free Pascal leaving an `out` array alone.

**N51 left this section on 30 September**, and `docs/KinFert-FIXED.md` has the account. It was the
last entry of the fertility and nuptiality side. The standard deviation of the schedule of ages at
first union now has a floor, `kMinStdNuptSchedule`, applied where `RodTrussFirstUnion` divides by
it, and a zero proportion ever in union no longer makes that routine evaluate `0.0/0.0`. Two of the
three routes to a zero had already been closed by N53 and N50; the one that was live is a stepped
run, where `SpecialRuns` takes the standard deviation from `std_Campbell_Wood_1988`, which is zero
for any mean at or below 15.32 years, and writes it into `dp[stdnupt].value` past the range test.
I had earlier described this entry as reachable only by hand editing the parameter, which was
wrong. Each of the four standard deviation functions now carries a note of its own domain. **No
result changes** in any run that completes today.

Every row below was read against the source again on 29 September, and the line numbers are of
that reading.

**The limits themselves are now a decision for you.** They sit in one block of `Declarations.pas`,
each with the value the dialog has always applied, and the lines below carry a `Claude suggestion`
saying what looks more defensible. None of them is applied. Changing one changes what a
configuration file is allowed to say, so each is yours to take or leave:

| parameter | applied now | suggestion, and why |
|---|---|---|
| `MEAN_AGE_UNION`, `MEAN_AGE_UNION_HIGH` | 10 to 59 | 15 to 40. These are means, not individual ages: below 13.64 `std_Coale_Rodriguez_Trussel` mirrors the mean and at 13.64 it returns zero, which `RodTrussFirstUnion` divides by, and no population has a mean age at first union above 40. It is the input form of what N53 applies to the schedule |
| `MEAN_AGE_UNION_MEN` | 10 to 69 | 15 to 40, for the same reasons |
| `STD_DEV_AGE_UNION` | 1 to 100 | 1 to 20. Observed standard deviations of the age at first union lie between about three and eight years, and a hundred years is longer than a life |
| `FERT_SURVEY_MIN`, `FERT_SURVEY_MAX` | 1 to 30 and 1 to 99 | `kMinAgeFert` to `kMaxAgeFert`, 10 to 59, the ages at which the model has any fertility to report |
| `MAX_THREADS` | 1 to 999999 | 1 to 1024. Nothing is gained above the number of logical processors, which is the default |
| `CTFR` (read only) | 0 to 100 | 0 to 50, which is `kMaxNbChildren`, one birth for each year of the fertile span, and a bound no mean completed fertility can pass. The field is computed and shown read only, so the limit never binds |
| `PROP_WOMEN_AT_BIRTH` | 0 to 1 | 0.45 to 0.55. A proportion female outside that is not a sex ratio at birth, and 0 or 1 makes a population of one sex. This one cannot be expressed while the two arguments of the dialog are `longint` |
| `FIXED_AGE_UNION` | 1 to 50 | `kMinAgeUnion` to `kMaxAgeUnion_women`, since the value is an age at union and is truncated to index the schedule. The dialog attaches this pair to the checkbox rather than to the value, where it decides nothing |

The four array fields, `APRIORI_PPR`, `EFF_STOPPING_CONTRACEP`, `PROP_USING_SPACING` and
`WAITING_TIME_SPACING`, take their pairs from the same block, but their readers take a whole row at
a time and test nothing, so for those four the limits still serve the dialog alone.

| | where | what is unguarded |
|---|---|---|
| **Index bounds, five of them** | `Kinship.pas`, verified 29 September | `addChildrenBACKFORInfo` at 2874 puts an age at union on a fertility-age axis (`- kMinAgeFert`); `addBridesInfo` at 2754 and 2757 and `addUnionsInfo` at 2788 compute indices with no test at either end; `addGroomsInfo` at 2687 has `max (0, ...)` and no upper bound; `getAgeUnionSelected` can reach `Unions [-1]`. **Blocked on Q6**, whose answer decides whether the fix is a bound or a rejection, and it is the same answer for all five. The sixth, `lookingForABrideByAgeAndCohort`, is now bounded |
| **Cohort file header** | `DemographicRegime.pas:1371` to `1459`, verified 29 September | The column position of each value is decoded from the header into `posValues[n].posTable`, by `ord` of an enumeration for the two parameter families and by reading one, two or three digits of the column name for the arrays and the education tables, with no test that the number the name carries is inside the array it will index. A hand-edited header reaches the assignment at `1535` and beyond with whatever it says |
| **G2** | `LazConfig.pas:452` and `457`, verified 29 September | Neither `FIRST_COHORT` nor `STEP_COHORT` is given a range at all, so neither is in the table of N50 and the dialog accepts 0. `STEP_COHORT` at 0 makes `currCohort := currCohort + 0` and the dialog accepts 0, which makes `currCohort := currCohort + 0` an infinite loop at `ReadCmdFileUnit.pas:1599`. `FIRST_COHORT` and `LAST_COHORT` are unchecked the same way |
| **G3** | `LazOutput.pas:374` | `MAX_THREADS` accepts up to 999999, and `ReadCmdFileUnit.pas:1591` copies it into `gMaxThreads` with no bound of its own. N50 now refuses 0 and a negative value from a configuration file, so what is left is the upper end, and that many threads are then created |
| **G15** | `LazUtiles.pas:118`, verified 29 September | `StrToInt` on the raw text of three edit boxes inside `FormCloseQuery`, after `CanClose` is already true and one of the three globals has been updated |

---

## 4. Threading and object lifetime

Each needs a design decision and its own test. A wrong fix here is worse than the bug.

| | where | what |
|---|---|---|
| **2.3** | `Kinship.pas:6642`, consumer at `6659` | The go-flag is published before the state the worker reads, with no event, lock or barrier. Apple Silicon is weakly ordered, so this is not theoretical on your machine |
| **2.4** | `Kinship.pas:2878, 7619, 7739`; `Utilities.pas:288` | Every wait is a hot spin with no yield |
| **2.5** | `Kinship.pas:7421, 7431`, caller at `7684` | The link file failing to open leaves the main file open, and the caller's bare `exit` skips `writeTables`, `DestroyArrayChildren` and all thread cleanup, leaving workers spinning |
| **N36** | `Kinship.pas:2879` | `.Destroy` immediately after a spin, with no `WaitFor` and no `inherited` |
| **N38** | `Kinship.pas:2876` | `nActiveThreads` is not a count of running threads, so `.start` is called on threads already running |
| **N41** | `Kinship.pas:3175` | Bootstrap replicates reuse stale arrays. **Disappears if bootstrapping is removed**, and is that change's acceptance test |

---

## 5. Questions only you can answer

| | question | blocks |
|---|---|---|
| **Q2** | Is `LivingBirth` counted from conception, so the correction adds the gestation to the death term rather than subtracting it from `month`? | N2 |
| **Q3** | Answered on the succession rules themselves, 29 and 30 September. **Answered:** descendants divide the estate by lineage, with representation, so the share of a dead child goes to that child's own children; ascendants and lateral kin are chosen by degree alone, the nearest degree excluding the rest; the estate of an ascendant heir is halved between the father's side of the family and the mother's side and divided equally within a side, with no further split between the two lines inside a side, and a side with no heir at that degree leaves its half to the other side; lateral kin of the nearest degree take equal shares, and the equal shares at degree 4 are deliberate. **Still open, and blocking nothing:** are posthumous children heirs; what happens when no heir is found; is usufruct modelled? | nothing today |
| **Q4** | Should `inher_Spain` / `inher_Other` select between rule sets, or is the parameter a leftover to remove? | N25 |
| **Q6** | Can the repartnering model emit a union age above 74? | several index bounds, and the five in `initMotherhood` |
| **D3** | Should the key column be suppressed in a kinship-only stepped run? `writeKeys` has one call site, inside `FERTILITY_loops`, so with FERTILITY off `RP.key` is never incremented and the column is the constant 0 on every row | cosmetic, but it reaches the file format |
| **Q7** | Do `union_women_men` rows always reach 1.0? | an unguarded sampling loop |

Q1, the fecundability parameterisation, is closed: Léridon specifies a Gaussian, `N(0.23; 0.12)`.

---

## 6. The reports that are not yet checks

81 sites were converted: 66 in `Kinship.pas`, which is every live one there, 13 in
`FertilityRuntime.pas` and 2 in `Nuptiality.pas`, and the 5 of `EducationalLevel.pas` on
18 September, which leaves that unit with none. About 26 invariant sites are still written the
old way, as a `writeAndWait` followed by the debugger trap spelled out longhand. They are silent
in a batch run, they do not appear in the table, and a run that trips one of them still reports
that every check passed.

| unit | sites | what they watch |
|---|---|---|
| `Nuptiality.pas` | 0 live | **Re-read on 30 September, and the earlier row was wrong.** The six sites in the union getters and setters all sit inside `{$IFDEF addOldUnionType}`, which `Defines.pas` explicitly undefines, and each of them compares the old array storage of the unions against the linked list that replaced it. They are the leftover cross-check of that migration, not the family of N28, and they are dead code. What they deserve is deletion, together with the define and the 16 conditional blocks it still guards in this unit; converting them to checks would keep code alive that nothing runs |
| `Fertility.pas` | 7 | the children list, the fixed-parameter names, the standard deviation of the heterogeneity, the age at sterility |
| `inheritance.pas` | 3 | a decedent or an heir not found in the set, at `1335` and `1387`, and the count of heirs of degree 4, at `2092`. The arm of `checkHeirs` that could not be reached is gone with N26 |
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

---

## 7. Smaller things

Entries that moved out of this section on 13 September: `N28` and `N30` and `N31` are fixed;
`N49` is fixed; `N19`, `N29`, `N32`, `N34`, `N37`, `N42`, `N43`, `N44`, `N45`, `N50` and `N53` are
fixed, `N44` by you;
`N10` was found already fixed on 18 September, the net reproduction rate now reading
`PROP_WOMEN_AT_BIRTH`; `N4c` is not a defect but a second model, and is now implemented as one;
`G11` was the other half of `N43` and went with it;
`Erlang` is fixed; the
`getPartner` guard now reads `kMaxNbUnion` rather than the literal 20.


| | where | what |
|---|---|---|
| **N54** | `Kinship.pas`, the ego loop that follows `egoAddPersonsAndBirths` | **The fertility of ego's partners is reported as zero in every run.** `egoPartnerAddPersonsAndBirths` fills `g_fertilityEgoPartners` and `g_NumChildrenEgoPartners`, from which `TFR_egoPartners`, `TFR_egoPartners_NC` and the sums beside them are computed and written out. Nothing calls it. The loop that walks ego's unions gets each partner and checks that it is not nil, and then does nothing with it, so those columns are all zeros and have been for as long as the routine has been there. It came to light while looking for dead code: the routine looked unused, and it is, but the fault is the missing call rather than the routine. The repair is one line in that loop, `egoPartnerAddPersonsAndBirths (partner, 50 or 60 by the partner's sex, indCohort)`, following what is done for ego two lines above, where a woman is followed to 50 and a man to 60. It changes results, in the sense that a column of zeros becomes a column of numbers, so it is yours to decide; the comparison between ego, ego's mother and ego's partner is the point of that table |
| **N46** | `Nuptiality.pas:1293` to `1314` | **Re-read on 30 September, and the earlier description was wrong: it is not the argument count.** The whole `{$IFDEF DEBUG_SEPARATION}` block is written against an earlier `TFileType`, which was a pointer to a record. `TFileType` is a class now, with a `Create` constructor, so `new (f)`, `f^.filenameWithPath`, `assignFile` and `rewrite` are all wrong and the unit will not compile with that define on. The file is never closed either, and the second block, which writes the table after it has been scaled, is not guarded by the `checkDirResult` test that the first one makes, so it would write to an unopened file. `DEBUG_SEPARATION` is not defined anywhere in `Defines.pas`, so this is harmless until someone turns it on to look at the separation tables, which is exactly when they would meet it. The repair is the pattern the rest of the unit uses: `openFileOut`, then `cWriteLn`, then `Destroy`, with one guard around both blocks |
| **Small things in `Nuptiality.pas`**, none of them affecting a result, found while tidying the documentation of the schedule on 30 September | | Three dead computations and one stale constant. `CoaleFirstUnion` accumulates `mean` over the schedule it builds and never reads it, and `RodTrussFirstUnion` does the same with `meanCalc`; both are useful in the debugger beside the mean that was asked for, and the second is now documented as such, but neither is used and a reader has to work that out. `calcNuptScaleFactorRT` has no caller, and `std_unionLinear` has none either. And `kCoaleStandardMean` is 11.37 while `std_Coale_Rodriguez_Trussel` divides by 11.36 and the header of `CoaleFirstUnion` says the scale factor corresponds to `(SMAM - kMinAgeUnion) / 11.36`: two values for the same quantity, one of them written out twice. Deciding which is right is a five minute job and it belongs with the 20 per cent discrepancy recorded in `docs/KinFert-FIXED.md` under N51, since both concern the same equivalence between the two parameterisations |
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
| **Dead code** | `Utilities.pas:1323`; `testThread.pas`; `mothersInfoList.pas` | `writeOneArrayOfDouble` has no callers; `testThread.pas` declares a unit name that does not match its file; **`mothersInfoList.pas` was reported deleted on 26 August but is still present and tracked**. Read through on 30 September, and what it is is now known: see the entry below |
| **What `mothersInfoList.pas` was**, read through on 30 September so that the decision to delete it can be made knowingly | `mothersInfoList.pas`, 221 lines | It is the earlier design of the pool of pre-simulated mothers that `initMotherhood` fills, and it is a fragment: no `unit` line, no `interface`, no `uses`, no `end.`, which is why `tools/check-line-numbers.py` reports ANCHOR NOT FOUND for it. Four classes. `TMotherMemoryBlock` is one simulated mother, her id, cohort, marriage states, her table of ages at childbearing and a copy of her children list. `TMotherInfo` wraps it with a reference count and an `assignMother` that hands the three pieces of data to the caller and then releases the block **without** freeing the children list, ownership of the list passing to the caller. `TLinkedListMothers` is a LIFO stack of mother ids, and `TListMotherInfo` holds one flat array of all the mothers kept plus **one stack for each fecund age**: `keepMother` pushes a mother onto the stack of every age at which she bore a child, and `motherFound (ageMother)` pops the top of that age's stack. The reference count exists for exactly that reason, since a woman who bore children at 22, 26 and 31 is a candidate for a reference child born at any of those three ages and can be used only once; when she is taken through one age her block is released and `cleanStack` walks the other stacks dropping references until the last one frees the wrapper. **It is cut off deliberately and not by accident**: both public entry points are disabled at their first statement, `keepMother` beginning with a bare `exit` and `motherFound` with `result := false; exit`, so everything below those two lines is unreachable. It could not be revived as it stands either, since `MarriagesType` and `kSetLengthMothers` exist nowhere else in the project, not even in `backup/`: `MarriagesType` was the union record before `TUnionsType`, so the file predates the rewrite of how unions are stored. **What does the job now**: `TPersonMemoryBlock` in `Parenthood.pas:15`, which is the direct descendant of `TMotherMemoryBlock` with `TUnionsType` in place of `MarriagesType` and no reference counting; `TPersonMemoryManager` at `Parenthood.pas:43`, which holds them in a three level array as `gBig_ArrayWomen` and `gBig_ArrayBrides`, reached through `getWomanFromBigArray`; and `g_RangeBirthsInfo`, filled by `addChildrenInfo` at `Kinship.pas:2793`, which is indexed **by the child's year of birth** rather than by the mother's age at childbearing, with `CAMSIM_RangeBirthsInfo` adding a parity dimension and `addChildrenBACKFORInfo` building a separate index by age at union. **The recommendation**: delete the file for the release. The one idea in it worth keeping is the reference-counted handover of the children list, which is the part to read if the mother pool is ever revisited, and it is described here so that deleting the file does not lose it |

---

## 8. The GUI and the utility units, read on 6 September

Read on 6 September, in four passes: `LazMain`, `LazUtiles`, `LazLowlevel`, `Simulxcode`, `docform`;
`LazConfig`, `LazOutput`, `ComponentHelper`; `LazGraph` and the five small dialogs;
`NumCPULib`, `Profiler`, `TimeProfile`. Every item below was verified against the source, and in
three cases against the compiler. Nothing here has been changed yet.

### Results, hangs and crashes

**`G1` left this section on 30 September**, fixed: `myLine := ''` in `MemoWriteLnExec`. It was
the only entry here that could stop an ordinary run. `docs/KinFert-FIXED.md` has the account.

| | where | what |
|---|---|---|
| **G2** | `LazConfig.pas:452` and `457`, verified 29 September | Neither `FIRST_COHORT` nor `STEP_COHORT` is given a range at all, so neither is in the table of N50 and the dialog accepts 0. `STEP_COHORT` at 0 makes `currCohort := currCohort + 0`, so `TEditChange` sets `checkValue := false` and the dialog accepts 0. With KINSHIP on, `ReadCmdFileUnit.pas:1599` is `while currCohort <= last do ... currCohort := currCohort + 0`, an infinite loop, and the second loop at `1637` repeats one cohort for ever, rewriting its output. `FIRST_COHORT` and `LAST_COHORT` are unchecked in the same way |
| **G3** | `LazOutput.pas:374` | `MAX_THREADS` accepts up to 999999, and `ReadCmdFileUnit.pas:1591` copies it into `gMaxThreads` with no bound of its own. N50 now refuses 0 and a negative value from a configuration file, so what is left is the upper end, and `Kinship.pas:7746-7758` then creates that many threads. The maximum should be of the order of `gNumLogicalThreadsForMultiThreading`, which the line below already prints as the recommended number |
| **G4** | `LazGraph.pas:196` | `SaveToFile` casts `ASeriesList.Items[0]` to `TChartSeries` with no test and reads `ListSource`. On "Outputs: Kinship" the first series is the `TConstantLine` added at `1137`, a sibling class with no such member, so "Save to file" there reads a wrong offset. The same routine has no guard for an empty list, so pressing the button before any run raises "List index (0) out of bounds" after creating a zero-byte file |
| **G5** | `LazGraph.pas:810` | "Waiting time after second birth" draws `AccDurationWaitingTime[1]`, which is the first birth interval, with the first interval's mean and proportion in the legend. It should be `[2]`, in all three places. The second interval cannot be inspected at all today |
| **G6** | `ComponentHelper.pas:388` | `aCompChange` is only assigned inside the class tests, so a component that matches none of them, a `TButton`, a `TLabel`, a `TShape`, leaves it holding a stack value, which is then written into `lastComponentChange.next` and becomes part of the chain that `ShowValue` walks. One rename away from a crash: `LazConfig.pas:537` already passes a name that resolves to nothing today. `aCompChange := nil` at entry and an exit before line 442 |
| **G7** | `ComponentHelper.pas:986, 1055` | `TCohortComboBoxChange.myGetValue` and `TFixedFertComboBoxChange.myGetValue` end with `ConfigForm.updateValues`, which frees the whole `TComponentChange` chain, including the object whose method is running. Control then returns into `TComponentChange.ReadValue` at `630`, a virtual call on freed memory. It survives only because the heap manager does not scrub the object. Set the existing `needToUpdate` flag instead |
| **G8** | `LazMain.pas:824, 832, 838, 860` | `SaveLog` is called from the worker thread and reaches `Log.Lines.SaveToFile` while the main thread is adding lines to the same `TStringList` from queued calls. With `SAVE_LOG` on this is a race on the memo. Queue it like every other GUI touch in the unit |
| **G9** | `LazMain.pas:801-862` | `TKinFertMainThread.Execute` has no `try ... except`. An exception inside a run reaches `TThread`, which still calls `OnTerminate`, so `endSimulation` reports "finished" with a green indicator while the output files were never closed and lost their tails. This is the same complaint as 3.5, from the other end |
| **G10** | `NumCPULib.pas:624` | `GetCPUCountUsingSysCtlByName` never initialises `Result` and ignores the return code of `fpsysctlbyname`, and it is the only implementation behind `GetPhysicalCPUCount` on macOS. On failure it returns whatever was on the stack, which `Init.pas:731` assigns to a longint under range checks |
| **G12** | `LazConfig.pas:466, 537, 580` | `NWOMEN`, `CREATE_COHORT_FILE` and `STABLE_POPULATION` are bound to components that do not exist, `FindComponent` returns nil and `CreateComponentChange` exits with no message. `NWOMEN` is the substantive loss: it is a real parameter, read and written in the configuration file, and it drives the denominators in `FertilityRuntime.pas`, with no way to set it from the dialog |
| **G13** | `LazOutput.pas:186, 193, 206, 219` | Four lines read `OutputForm.ChangesMadeToDefaultValues` inside `TOutputForm`, which is the field being assigned: `x := x or x`. The heirs, decedents, kin selection and optional field dialogs each keep their own flag, and those are what should be read, as `LazConfig.pas:237` correctly does. A change made only in one of the four sub-dialogs leaves the "Edited values" indicator wrong |
| **G14** | `ComponentHelper.pas:1058` | `TFixedFertComboBoxChange.myCheckChanged` forces `myVal.changed := FALSE` with a comment copied from the cohort combo, where the object really is a dummy. Here it is `FIXED_FERTILITY_VALUE`, a live parameter, so changing it never marks the configuration as edited |
| **G15** | `LazUtiles.pas:118`, verified 29 September | `FormCloseQuery` calls `StrToInt` on the raw text of three edit boxes. An empty or non-numeric box raises `EConvertError` out of the close handler, after `CanClose` has been set true and after one of the three globals has been updated. `TryStrToInt`, or validation in the OK handler |
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

## 9. One deliberate change

**Remove bootstrapping.** You confirmed this. It touches `gBootstrap_nRuns`, the replicate loop
at `ReadCmdFileUnit.pas:1608`, `RP.indBootstrap`, and the `bootstrap_ind` parameter threaded
through `run_all`, `simulateKinship` and `individualKin_*`. N41 is its acceptance test.

**Keep `RP.wkey`.** `openFileKeys` at `Utilities.pas:762` turns keys on whenever any of the seven
step counts exceeds one, so a parameter sweep needs keys with no bootstrapping at all.

---

## 10. Two things planned and never built

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

---

## 11. Documentation and publication

**Documentation.** The manual is a first draft at `docs/KinFert-Manual.md`, and it is the third
document: neither this one nor the companion replaces it.

| | what |
|---|---|
| **M1** | Answer the nine questions left in Appendix F: the conception model, the repartnering hazard, the mapping from life expectancy to survival, the country inheritance rules, the exact file grammars, the two remaining drop-down lists, and a worked regression example. The education levels and their four modes were settled on 1 October and are in §8.5 |
| **M2** | Bring the manual up to the work of this year: kin sets per output format, the DemoCare field dialog, `DEMOCARE_LARGE_FIELDS`, the `dead` and `secondUnions` values of `partnershipStatus`, relatives dead before the reference age now excluded from the DemoCare file, the `kt_total` row, and the removal of the BATCH option |
| **M3** | Document the DemoCare format and its link file |
| **M4** | Release notes: `DEMOCARE_LARGE_FIELDS` replaces the `DUMPALL` binding; an old DemoCare configuration carries a wide `OUTPUT_KINTYPES` that is now honoured; the DemoCare file no longer contains relatives dead before the reference age; BATCH is gone; `MULTITHREADING_SIMKIN` is now saved |
| **M5** | Fold the cleared findings, which are listed in `KinFert-FIXED.md`, into developer notes, so that the reasoning survives the documents |
| **M6** | The model description, not only the code, changes with the fecundability parameterisation and with the effect of infant death on the birth interval. The manual must say what the code now does: a constant multiplier per woman, so the coefficient of variation is the same at every age by construction, and the realised rather than the nominal moments of that distribution |
| **M7** | Done, in §13.5 and §13.6 of the manual: the seven sweeps in the order in which they nest, the range each one spans, the product of steps as the number of simulations, the two places where the step counts are reset and the fact that only one of them says so in the log, the step indices in the output names, and the KEYS file as the lookup table that joins the step values to the individual records. One thing the entry assumed is not so: the reset in `checkStepsAndStablePopulation` is silent, and the message is printed only by `openFileKeys`, that is only when an individual file was also requested |
| **M8** | Write the didactic text of chapters 13 and 14 and take the screenshots. The scaffold, the verified facts and the figure slots are in place since 1 October; every gap carries a note headed **To write** saying what belongs there, and `docs/img/README.md` lists each of the thirty-two new captures and what it must show. The two worked examples, one per chapter, are the pieces that matter most: each should name the numbers a reader must obtain, so that the manual doubles as the regression check asked for in `P6` |
| **M9** | Three things the documentation of the targets turned up, each of which is a decision rather than a defect. (a) `STABLE_POPULATION` is a configuration parameter with no control on any form and no reader anywhere in the simulation: it is set to false when a cohort file is read, it can be set from a command file, and nothing consults it. Retire it or give it back its meaning. (b) The on-screen help of `NSTEP_AMENORRHEA` says the sweep takes values "from 0 to the value in AMENO_ALPHA"; the code takes α to α + 2.4, and the default α is negative. One of the two is wrong. (c) With `SEP_TARGET` on and `FORCE_SEP_ITER` off, `SEPARATION_ADJUSTED` is applied without being checked; since that parameter is optional and defaults to zero, such a configuration switches separation off altogether while `SEPARATION` still shows a positive target. A zero could fall back to running the search, with a message |

**Publication.** The repository is already public at `github.com/ddev2/KINFERT`.

| | what |
|---|---|
| **P3** | Withdrawn on 1 October, and the two `.example` files with it. `KinFert ConfigDir.cfg` and `KinFert OutputDir.cfg` are not input: the program writes each of them itself, in `WriteStdPath`, whenever the matching folder is chosen in the interface, and a fresh installation having neither is the normal state. Shipping templates invited the user to create and edit files that are the program's own state, which is the opposite of what should happen. The README and §2.6 of the manual now say so |
| **P13** | Done on 1 October, and recorded in `KinFert-FIXED.md`. Both files now live in the folder each system sets aside for an application's own per-user state, `~/Library/Application Support/KinFert/` on macOS and `%APPDATA%\KinFert\` on Windows, and each carries the name of the system that wrote it, `ConfigDir-macOS.cfg` against `ConfigDir-Windows.cfg`, so that a shared folder cannot make one pass for the other. `ReadStdPath` falls back to the old file next to the executable and writes the new one at once, so the move is made on the first run and nothing has to be copied by hand. The change is in `LazMain.pas` and carries review markers. It cannot be compiled outside Lazarus, so it was checked by lifting the new routines out and compiling them against stubs in all three platform branches; what is left is to build it in Lazarus on each machine and confirm that the first run finds its two folders already set |
| **P4** | Pin the versions. `kinfert.lpi` carries `Version Value="12"`; state the Lazarus version it was saved with and the FPC version it is known to build under. FPC 3.2.2 is verified for the engine |
| **P5** | Decide how the binaries are built and released. `KinFert`, `KinFert.exe` and `KinFert.app` are in the folder and gitignored, which is right; they belong in a Release built from a tagged commit. Both platforms have to be there, since neither can be produced from the other without the matching toolchain. Two practical points: the macOS binary is unsigned and not notarised, so Gatekeeper refuses it on a first open and the release notes have to say how to allow it (right click, Open, or `xattr -d com.apple.quarantine`); and the Windows binary should say which Lazarus and FPC produced it, since nothing in the file does |
| **P11** | The macOS build instructions have to carry what was learnt on 30 September. FPC 3.2.2 emits Objective-C metadata that Apple's current linker rejects once the deployment target is macOS 11 or later, because that turns on chained fixups: `-WM11.0` produces `ld: malformed method list atom` in an LCL Cocoa unit. The build therefore leaves the deployment target at its default, and the several hundred `ld: warning: object file was built for newer macOS version (11.0) than being linked (10.15)` warnings, and the `-macosx_version_min has been renamed` line that Lazarus counts as an error, are cosmetic. A newer FPC is the proper fix and is worth doing before anyone else tries to build on a recent Mac |
| **P12** | Say in the published documentation that the program is in its verification phase: the results of a run are not to be taken as settled until the checks of `docs/KinFert-Verification-Plan.md` have been made and answered. Ship that document with the source, so that a reader can see what has been checked and what has not, and link it from the README beside the manual |
| **P6** | A minimal regression test with a known output: one small configuration file, one expected output folder, and a note on how to compare. V14d is the natural candidate, and `compareruns` is the comparison |
| **P7** | Decide whether `CLAUDE.md`, `AGENTS.md` and these documents ship with the source |
| **P10** | Decide whether `testThread.pas` ships. It declares `unit testThreads` while the file is named `testThread.pas`, and nothing references it |
| **Line endings** | A `.gitattributes` with `*.pas text eol=lf`. `Fertility.pas` was converted from CR-only on 31 August, but `LazConfig.pas` is still CRLF, and mixed endings across two platforms produce whole-file diffs that hide the real change. One loose end from that conversion: it was made in the same working tree state as the fecundability fixes, so `git diff` shows the whole file and the content changes are invisible inside it |

**And the one that deserves real thought (P8):** what to say about results produced with earlier
versions. The sweeps, `endUnion`, the fecundability heterogeneity and now the age at onset of
sterility all changed simulated numbers, and the repository is public.
