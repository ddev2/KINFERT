# KinFert: the verification plan

**29 September 2026.** What to run, what to look at, and what the answer must be, for every
change made this month. Tick a box when the check has been made and the answer was the one
written here. When it was not, write what you saw beside the box: a check that failed is worth
more than one that passed.

The plan has two parts. **Part A** verifies the changes, which is the work you asked for. **Part
B** is what still lies between the repository and a release you would defend, with the
inheritance module first, since that is the one you take up next month.

Three documents go with this one: `KinFert-FIXED.md` says what each change was and why,
`KinFert-TODO.md` carries what is still open, and `KinFert-Manual.md` is the manual. This one
replaces nothing in them; section 2 of the TODO is the older list of the same checks, by their V
numbers, and the last section here says which of those this plan covers.

---

## 0. Set-up, and it is most of the work

Almost every check below is "the same, or different in this one named way", so it needs a binary
built from the code as it stood before this month. That is one command: the working tree has 26
modified files and every one of them is this month's work, so `HEAD` is exactly the state before
it.

- [ ] **S1. Build in Lazarus.** Nothing else can start until this is done. The units that changed
      since your last build are `Declarations.pas`, `DemographicRegime.pas`, `EducationalLevel.pas`,
      `Fertility.pas`, `FertilityRuntime.pas`, `Init.pas`, `Kinship.pas`, `Nuptiality.pas`,
      `Parenthood.pas`, `ReadCmdFileUnit.pas`, `StringOfLib.pas`, `Verification.pas`, and on the
      form side `LazConfig.pas`, `LazOutput.pas`, `LazLowlevel.pas` and `LazLowlevel.lfm`. The
      three form units are the ones no container can compile, so they are the ones to watch in the
      messages window.
- [ ] **S2. Build the baseline.** Outside the Drive folder, so that git has no lock trouble:
      `git worktree add ~/kinfert-baseline HEAD`, open `kinfert.lpi` there, build, and keep the
      binary as `KinFert-baseline`. Everything in Part A section 1 is a comparison against it.
- [ ] **S3. Build the comparison tool once.** `cd tools && fpc -O2 compareruns.lpr`. Its README
      lists the options; the two used below are `-tol` and `-summary`.
- [ ] **S4. Fix one reference configuration and keep it.** The smallest one that still produces a
      kinship network: one cohort, `NWOMEN` and `NEGO` of about 10000, and these settings, which
      are what make the run comparable: `MULTITHREADING` off, `SAME_RANDOM_SEQUENCE` on, every
      `NSTEP_` at 1, `EDU_STATUS` on none, `MOTHER_ALGORITHM` on KINFERT,
      `RESHUFFLED_FECUNDABILITY` off, `FLOATING_POINT_DIGITS` at its default of 3. Run it with the
      baseline binary into a folder kept as `base/`, and with the new one into `new/`. This pair is
      also **P6**, the regression test the repository does not yet have.

---

## Part A, section 1. What must not change at all

Every item here is covered by one comparison, `compareruns base new`, with no tolerance. If that
reports no difference, all of it is verified at once. If it reports differences, the list below is
the order in which to look for the cause.

- [ ] **A1. The reference configuration, cell for cell.** `compareruns base new` must report no
      difference in any file. This covers, in one go: the trailing zero strip (**N45**), the input
      ranges and the new constants (**N50**), the three nuptiality guards (**N29**, **N53**,
      **N51**), the
      separation guard (**N32**), the person memory manager (**N37**), the parity counters made
      atomic (**N34**, which with multithreading off is the same arithmetic), the five education
      reports, which only fire on a fault, the whole of the alternate mother algorithm work, since
      `MOTHER_ALGORITHM` is on KINFERT, and the per-cycle fecundability draw (**N4c**), since its
      switch is off. If any of these changed an ordinary run, this is where it shows.
- [ ] **A2. Education, same distribution, different persons.** Repeat A1 with `EDU_STATUS` on the
      cohort mode and no cohort file, so the `EDU_` values are the shipped defaults. The education
      **column will differ** and that is not a regression: the parents-first pass of `giveEdStatus`
      changes which person receives which random number, while the number of draws and the
      distribution they come from are unchanged. What must be true is the marginal: the proportions of
      B, M and A over all simulated people must agree between `base` and `new` to within sampling
      error. `compareruns base new -only kin -summary` tells you how much of the file moved; the
      proportions are the check.
- [ ] **A3. The number format.** Run the reference configuration with `FLOATING_POINT_DIGITS` at 1
      and at 10, both binaries, and compare each pair. Both must be identical: **N45** only bit at
      0, which the dialog never offered and a configuration file can no longer reach.
- [ ] **A4. A configuration the dialog would refuse.** Take the reference configuration file, set
      `NWOMEN=50` by hand, and run it. The run must stop with a line naming `NWOMEN`, the value and
      the range, where before it ran with 50 women. Put the value back and confirm the run is
      accepted again. That is **N50** doing its work; the same test with `FLOATING_POINT_DIGITS=0`
      is **N45** and **N50** together.

---

## Part A, section 2. What must change, and what it must become

These are the fixes that were meant to alter results. For each one, the baseline binary is the
"before" and the new one the "after".

- [ ] **B1. The education probabilities of a cohort file now reach the people.** This is the
      largest defect found this month. Write a cohort file whose education columns ask for 0.60,
      0.30, 0.10 for both sexes, set `EDU_STATUS` on the cohort mode, and run it with both
      binaries. In `new`, the proportions of B, M and A among the simulated people must be about
      60, 30 and 10. In `base` they will be about 50, 40, 10 for men and 60, 35, 5 for women, the
      shipped defaults, whatever the file said. Read the proportions from the kinship individual
      file, or from the education columns of the fertility microdata if that is easier to
      tabulate.
- [ ] **B2. Family correlation, and what it does to the marginal.** Set `EDU_STATUS` on the
      intra-family mode and run. Cross-tabulate the level of ego against the level of one sibling
      in the kinship individual file. In `new` the table must show a positive association; in
      `base` the two are independent, because siblings took the cohort distribution. **Then look at
      the marginal distribution of ego**, which is the consequence you have to decide about: the
      `EDU_` proportions now bind only the people at the top of each line of descent, so the levels
      among egos are those the parent to child matrix implies and drift over the generations
      towards its stationary distribution. If that is not what you want, the matrix has to be
      rescaled so that each cohort keeps its own marginal, which is a change to the model and not a
      repair.
- [ ] **B3. The threads.** Three checks, and they are the old **V11** and **V23**. Run the
      reference configuration with `MULTITHREADING` on and off: the parity distribution must now be
      the same, where before the plain `Inc` lost counts (**N34**). Then a run of several cohorts
      with `MULTITHREADING` and `MULTITHREADING_INIT` both on: no two cohorts may share a seed, and
      no two cohorts may have identical fertility schedules (**N42**). And the run must end rather
      than spin, with each thread started once (**N43**).
- [ ] **B4. The cohort file round trip.** For each of the three education modes, write a cohort
      file, read it back, write it again, and compare the two written copies: nothing may be lost.
      The set of education columns now follows the mode, which is **N19**: none in the stochastic
      mode, `EDU_` in the cohort mode, and all three tables in the intra-family mode. A file written
      by the baseline binary must still read correctly in the new one, since the reader goes by the
      names in the header.
- [ ] **B5. The reshuffled fecundability, if you use it.** With `RESHUFFLED_FECUNDABILITY` on,
      two things must now be true that were not: conceptions must stop by each woman's own age at
      sterility, because her Léridon taper is no longer discarded after the first birth, and the
      spread of waiting times must narrow, because the multiplier is redrawn every cycle and the
      between-woman heterogeneity is gone by design. In `base`, with the switch on, women conceived
      at the plateau level right up to the age at sterility. The age at last birth and the
      distribution of the waiting time to the first conception are the two tables to read.
- [ ] **B6. The five mother-search algorithms.** One run per value of `MOTHER_ALGORITHM`, on the
      same configuration. KINFERT must match `base` exactly, which A1 already shows. For the other
      four, the test is the criterion of the annex: the mean number of children of the mothers of
      egos must equal `m + σ²/m` for the cohort, with the correction factor `e^(1.2 r)` where the
      population is growing. Report the four numbers beside the criterion; that comparison is the
      point of having the four.

---

## Part A, section 3. The verification table, after every run

- [ ] **C1. Read `verification.txt` at the end of each run above**, in the results folder. Every
      failure point must have recorded nothing, every invariant must have run, and every value
      check must have passed. The ids added this month, and what it means if one of them speaks:

      | id | if it fires |
      |---|---|
      | `eduRowSumsToOne` | a row of three education probabilities does not sum to one. A row summing to less gives the top level more than it asks for; a row summing to more never reaches the top level. Look at the cohort file |
      | `eduLevelName` | a status that is not B, M or A was read. With the parents-first pass this should be impossible; if it fires, tell me |
      | `eduRelativeMissing`, `eduCohortNotAssigned`, `eduParentStatusMissing` | a person, a partner or a parent was missing, or a cohort was unassigned. The person falls back to the cohort distribution and the run continues |
      | `separationIndex` | a union duration or a youngest child's age fell outside the separation tables. The dating of a union or a child is wrong upstream |
      | `scaleFactorTooLow` | the two mean ages at union are close enough, or crossed, that the schedule cannot be built. Expected on a configuration whose men marry about five years younger than the women |
      | `stdNuptTooLow` | the standard deviation of the schedule of ages at first union arrived at zero or below and the floor was used instead, which is N51. Expected in a stepped run over the mean age at union that uses Campbell and Wood and passes below 15.32 years, and it should be silent in any other run |
      | `everInUnionZero` | the proportion ever in union is zero, so nobody enters a union and there are no births. A legal configuration and almost certainly not the one you meant |
      | `meanAgeUnionRange`, `meanAgeUnionDiff` | a mean age at union outside its range, or a difference at or below minus five years |
      | `backforAgeChildbearing`, `backforAgeDrawnAgain`, `backforNoMother`, `camsimParityIndexEmpty` | only ever in a run using one of the four alternate algorithms. Silent in a KINFERT run |
      | `inhPartnerTestsDiffer` | the two heir searches do not agree on whether a person's surviving partner can inherit. They state the same condition in two ways, so this should be silent; if it speaks, one of the two readings of the end of a union is wrong |
      | `inhHeirsFoundByOneOnly` | one search found heirs for a person and the other found none. A real disagreement, and the first thing to look at in the inheritance results |
      | `inhHeirKinTypes` | the kin types of the heirs found by the second search fall outside the branch named by the first. **Expected on lateral heirs**, where the first search names one branch and the second applies the rule of the degree. On descendants, ascendants or the partner it is a real disagreement |
      | `inhHeirNotConfirmed` | an heir the first search listed is not among the heirs of the second. A real disagreement |
      | `inhAscendantsSameDegree` | the ascendants who inherit from one person do not all belong to the same generation, which is what N22 repaired. It should be silent; if it speaks, the loop over the generations in `AscendantHeirs_2` is not doing its work |
      | `inhNoCommonAncestor` | ego and a lateral relative of ego share no ancestor on either side of ego's family, which cannot be if that relative is of the kin type recorded. It should be silent; if it speaks, the kin type or the link that put that person in the network is wrong |

- [ ] **C2. One caveat worth knowing.** If `eduRelativeMissing` or `eduCohortNotAssigned` fires,
      the people it names are left without a status and are drawn again when another of their
      children is reached, so the run no longer makes exactly one education draw per person. Treat
      such a run as void for any education comparison and find the cause first.

---

## Part A, section 4. The older V list

Section 2 of `KinFert-TODO.md` carries the checks from the earlier rounds, by their V numbers. S2
and S3 above are what most of them were waiting for. The ones this plan already covers are
**V8** and **V14d** (A1), **V10**, **V11** and **V23** (B3), **V19**, **V20** and **V4** (B4), and
**V22** in part (C1). Still to do from that list, and none of them needs anything new:

- [ ] **V16b** Léridon's Table I: 75.4 per cent conceiving within twelve months at age 30, 66.0 at
      35, 44.3 at 40; 90.7, 83.9 and 63.7 within four years; median age at onset of sterility 44.7.
- [ ] **V14, V14b, V14c** the three parameter sweeps: the swept column must differ between steps,
      the mean age at union must reach its High value, the amenorrhea steps must be evenly spaced.
- [ ] **V15** the distribution of age at end of union must not pile up at the oldest ages.
- [ ] **V17** the mean birth interval after an infant death, against the interval after a
      surviving child: the difference must be of the order of the shortening of breastfeeding, not
      of nine months.
- [ ] **V18** `checkSumShareHeirs` must sum to one with two, three and four surviving grandparents.
- [ ] **V21** a cohort in which no woman is simulated must not raise a division by zero.
- [ ] **V9** a multi-cohort run: every cohort present, identifiers continuous and never repeated.
- [ ] **V2, V3, V5, V6, V7, V12, V13** the column counts, `compareruns base -headers`, and the
      named columns of the earlier rounds.

---

## Part B. What lies between here and a release

Nothing in the code stops a fresh clone from compiling: the repository is already public at
`github.com/ddev2/KINFERT`, and the one gap a newcomer meets is a chore rather than a defect,
**P4**, the Lazarus and FPC versions the project is known to build under. (**P3**, which asked for
two `.cfg.example` templates, was withdrawn on 1 October: the program writes those two files
itself.) What would make a release hard to defend is the list of defects that can
still change results. In the order I would take them:

### B.1 Inheritance, the module you take up next month

One defect is left, `N25`, which leaves the country rule set with no effect and waits on Q4.
`N22`, `N22b`, `N24` and `N26` were all fixed on 30 September, and reviewing them is the work
below. Three of the four change results, so review them before anything is built on them. The line
numbers are those after the changes.

- [x] **Q3, its first question, is answered**, 29 September: for ascendants and for lateral kin it
      is the degree that decides, an ascendant estate being divided by line at every generation,
      and lateral kin of the nearest degree taking equal shares. Descendants divide by lineage,
      with representation. The rest of Q3 can wait: posthumous children, what happens when no heir
      is found, usufruct.
- [ ] **Answer Q4**: is `inher_Spain` / `inher_Other` meant to select between rule sets, or is it a
      leftover to remove?
- [ ] **Review the N26 change, and run it.** `docs/KinFert-FIXED.md` has what was done. Read the
      new field `partnerCanInherit` in `Declarations.pas` and the line that fills it in
      `lookForHeirs`, the two partner tests at `inheritance.pas:237` and `254`, and the new
      `checkHeirs` at `2337`. Then run any configuration with `INHERITANCE` and `DEBUG` on, with a
      few thousand egos, and look at two things. In `<results>/verification.txt`:
      `inhPartnerTestsDiffer` should have recorded nothing, and `inhHeirsFoundByOneOnly` and
      `inhHeirNotConfirmed` should be rare or silent; `inhHeirKinTypes` is expected to speak on
      lateral heirs, for the reason given in `FIXED.md`. In the individual kinship file, the
      `checkHeirs` column should now hold 1 on most rows, -1 on the rows that only one of the two
      searches looked at, and 0 where the two answers really differ. Before the change that column
      was almost always 1, including on rows where the two searches disagreed, so a column that
      still reads 1 everywhere means the change is not in the binary.
- [ ] **Review the N24 change, and run it. It changes results.** `docs/KinFert-FIXED.md` has what
      was done, including why two of the five call sites of `commonAncestor` were left alone. Read
      the two repaired blocks of `checkEgoIsHeir`, the nieces and nephews at `inheritance.pas:947`
      and the grand nieces and nephews at `996`, against the first cousins block at `1091`, which
      is the model they were brought into line with. Then: (a) `verification.txt` must show
      `inhNoCommonAncestor` with nothing recorded, since a relative of those kin types must share
      an ancestor with ego on at least one side; (b) `V18`, the shares of an estate sum to one,
      must still pass; (c) against the binary of `HEAD`, the number of heirs of a dead niece or
      nephew must fall in the estates where ego is a half-sibling of the dead relative's parent,
      and the shares of the remaining heirs must rise. This belongs in the A2 comparison, with the
      N22 and N22b changes, and not in A1.
- [ ] **Review the N22 change, and run it. It changes results.** `docs/KinFert-FIXED.md` has what
      was done and the nine cases it was measured on. Read `AscendantHeirs_2` at
      `inheritance.pas:1660`, which is the only routine that changed, and the comment inside
      `exploreAscendantHeirsTree_2` at `1537`. Then: (a) `verification.txt` must show
      `inhAscendantsSameDegree` with nothing recorded, and `V18`, the check that the shares of an
      estate sum to one, must still pass; (b) in the individual kinship file of a run with
      `INHERITANCE` and `DEBUG` on, find a decedent with no descendant and no surviving parent
      whose heirs are ascendants, and confirm that they all belong to one generation, so no
      grandparent shares with a great-grandparent; (c) compare the mean share of an ascendant heir
      against the same configuration run with the binary of `HEAD`: it must rise, since estates
      that used to be split across two generations are no longer. This is the one change of the
      month in this module that moves numbers, so it belongs in the A2 comparison and not in A1.
- [ ] **Review the `N22b` change, which went in with N22 and also changes results.**
      `allocateShareAscendantsHeirs_2` now halves the estate between the two sides of the family
      and divides each half equally among the heirs of that side, where it used to give each line
      of descent an equal part. Read it with `sideOfAscendantHeir` above it. The check is the same
      `V18`, that the shares of an estate sum to one, plus a reading of a few ascendant estates in
      the individual kinship file: with heirs on both sides the shares of one side must add to
      exactly one half, and with heirs on one side only they must add to one.
- [ ] **N25, `inheritance.pas:2225`, blocked on Q4.** `lookForDecedents_Spain` has an empty body,
      and `COUNTRY_INHERITANCE_RULES` is created, saved, read and bound to a combo box, and never
      consulted: both algorithms run on every run, so the choice offered to the user does nothing.
      If the parameter selects between rule sets, this procedure is where the country branch
      belongs and the caller in `Kinship.pas` should run one algorithm rather than both. If it is a
      leftover, remove the parameter, its combo box, its reader, its writer and this stub together.
- [ ] **The three reports of the module**, at `1335`, `1387` and `2092`, still write to the memo
      and leave nothing in the verification table: a decedent not found, an heir not found, and a
      bad count of heirs of degree 4. The fourth, the arm of `checkHeirs` that could not be
      reached, is gone with N26. Converting the three is half an hour and it is what makes a run's
      inheritance results self-reporting. The warning at line `103`, about kin types missing from
      the set, is a message to the user and stays as it is.
- [ ] **V18**, above, is the numerical check of the module: the shares must sum to one.

### B.2 The rest, in the order I would take it

- [ ] **Threading, where it can change results or hang**: the go-flag published without a barrier
      (2.3), `.Destroy` after a spin with no `WaitFor` (N36), `nActiveThreads` not being a count of
      running threads (N38), bootstrap replicates reusing stale arrays (N41), and the hot spins
      with no yield (2.4).
- [ ] **The guardrails of section 3b**: the five index computations of `initMotherhood`, the table
      indices taken from a cohort file header with no bounds test, `FIRST_COHORT` accepting 0 and
      hanging the run (G2), and `MAX_THREADS` reaching `gMaxThreads` with no bound of its own (G3).
- [ ] **The GUI faults that can end a session**: the log line that grows without being emptied
      (G1), the chart cast with no test (G4), `SaveLog` called from the worker thread (G8),
      `Execute` with no exception handler (G9), `StrToInt` on raw edit boxes inside
      `FormCloseQuery` (G15), and the Debug dialog adding ego 0 to the view list (G16).
- [ ] **The release chores**: P3 the example `.cfg` files, P4 the pinned versions, P5 how the
      binaries are built and released, P6 the regression pair from S4 above, P7 whether the agent
      documents ship, P10 whether `testThread.pas` ships, and a `.gitattributes` with
      `*.pas text eol=lf`, since `LazConfig.pas` is still CRLF and mixed endings hide real changes.
- [ ] **P8, the one that deserves real thought**: what to say about results produced with earlier
      versions. The sweeps, `endUnion`, the fecundability heterogeneity, the age at onset of
      sterility and now the education distributions all changed simulated numbers, and the
      repository is public.
- [ ] **The manual**, M1 to M7 in the TODO. M1, the ten questions of Appendix F, is the one that
      needs you rather than me.
