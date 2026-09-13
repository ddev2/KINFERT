# KinFert: handover for a second reader

**13 September 2026.** This document exists so that another reviewer can pick up the work
without reading the conversation it came from. It states what KinFert is, what was changed
between 8 and 13 September and why, what is known to be still wrong, and the six questions where
a second opinion would be worth most. It is written to be read on its own.

The two standing documents remain `docs/KinFert-TODO.md`, which is what still needs doing, and
`docs/KinFert-FIXED.md`, which is the record of what is done. This one is the bridge between
them and a reader who has seen neither.

---

## 1. What the program is

KinFert is a microsimulation of kinship networks, written in Free Pascal and built with Lazarus.
It simulates the reproductive and union histories of women, then reconstructs, for a set of
individuals called egos, the kin who surround them: parents, grandparents, great grandparents,
siblings, children, grandchildren, cousins, and the partners of each. It is used for demographic
research on kin availability, and a separate module distributes inheritances over the kin it
builds.

The parts that matter for what follows:

- **`Fertility.pas`** and **`FertilityRuntime.pas`** hold the fertility model: fecundability
  with between-woman heterogeneity after Léridon, intrauterine mortality, stillbirth,
  post-partum amenorrhea, spacing contraception and stopping, and the parity progression
  ratios the model is calibrated on.
- **`Nuptiality.pas`** holds unions: the age at first union, separation, repartnering, and the
  union records attached to each simulated person.
- **`Mortality.pas`** holds the life tables.
- **`Kinship.pas`** is the largest unit. `initMotherhood` builds the pools of simulated women
  that the reconstruction draws from, and the rest of the unit walks the kinship tree.
- **`Verification.pas`** is new this month: a table of named checks, called from the simulation,
  reported in the memo and in `<results>/verification.txt` at the end of every run.
- **`LazMain`, `LazConfig`, `LazOutput`, `LazGraph`, `LazLowlevel`** are the GUI.

**The central mechanism to understand.** The kinship reconstruction does not simulate a
population forward. It pre-simulates a pool of women, indexes them, and then, for each person it
needs, looks the person up in an index. Two searches carry the whole reconstruction:

1. **The search for a mother.** A child, or an ascendant of a child, asks the birth index for a
   woman who gave birth in the child's own birth cohort. `selectOneMother` in `Kinship.pas`.
2. **The search for a bride.** A man asks the bride index for a woman of the cohort and age at
   union that his own cohort and age imply. Three algorithms exist; the third,
   `selectBrideByGroomCohortAndAgeAtUnion`, is the one in force.

When the cell asked for is empty, the search moves to a neighbouring one. A relative is still
produced, but from a different cohort or a different age at union than the model called for.
Under a stable population that substitution costs nothing, since every cohort has the same
regime. Under variable rates it draws the relative from a different regime, and the distance in
years is the size of the error. Measuring that distance is what most of the new diagnostic work
is about.

---

## 2. What changed between 8 and 13 September

Every change is wrapped in `// >>> Claude <date> start` and `// <<< Claude <date> end`, so a
reviewer can find them with grep. Daniel strips the markers with
`python3 tools/strip-claude-marks.py` once he has accepted a set, so their absence means
accepted, not absent.

### Defects that changed simulated numbers

| | unit | what it was |
|---|---|---|
| **N13** | `Mortality.pas` | The first year of life had no mortality of its own: `calc_ageDeath` drew a uniform fraction of a year at every age including zero, and the two Coale and Demeny branches of the infant correction were inverted. Now inside `calc_ageDeath`, which takes the sex as a fourth argument, with the moment within the first year drawn from `F(t) = t^k`, `k = a / (1 - a)`, whose mean is exactly the Coale and Demeny separation factor |
| **N52** | `Fertility.pas` | Barrett's distribution of the month a pregnancy is lost was written from index 1, while his months run 2 to 8. Mean 2.155 against Barrett's 3.114 lunar months |
| **N7** | `FertilityRuntime.pas` | The parity progression adjustment replaced a zero denominator by 0.00001, which told the model that progression at a parity nobody reached is all but certain, and propagated that factor to parities 16 to 50 |
| **Erlang** | `Fertility.pas` | The waiting time distribution ignored the rate when setting the shape, so the two repartnering calls delivered a mean 3.33 times the value asked for. It also summed a density over whole months as though it were a sum of probabilities |
| **N35** | `Kinship.pas` | `addGroomsInfo` used `exit` where it needed `continue`, so a woman whose first union implied a groom outside the cohort range lost all her later unions |
| **N28** | `Nuptiality.pas` | The six union setters created a union when handed an index that named none, which turned a broken reciprocal link between partners into an extra union |
| **N31** | `Nuptiality.pas` | `ageWomenEndUnion` used the sentinel `kNotDefined` as an age, and compared the separation against the partner's death alone |
| **N9, N30, N14** | `StablePop.pas`, `Nuptiality.pas`, `Mortality.pas` | The intrinsic growth rate omitted the proportion female at birth; `std_Campbell_Wood_1988` took the square root of a negative number; a life expectancy read from a cohort file was not clamped |

### Diagnostics, which change no results

- **`verification.txt` rearranged by outcome**: what failed, what was reported through
  `writeAndWait`, what passed, the failure points that recorded nothing, and the checks that did
  not run. It used to be one table in the order of the enumeration.
- **The two searches instrumented.** `gMotherSearch`, `gMotherSearchMiss`, `gMotherSearchYears`
  and the three bride equivalents, each indexed by generation and by cohort, count every search,
  every search answered from another cell, and the distance in years. Reported at the end of the
  run and drawn on the Children-Grooms tab.
- **The diagnostic arrays kept by generation**, from the great grandchildren to the great
  grandparents, through `kinGeneration` and `kinGenerationRow` in `Declarations.pas`. The
  ascendants are looked up in cohorts one, two and three mean ages at childbearing before ego's,
  so pooling the generations made the charts unreadable.
- **`writeAndWait` routed into the verification table** through a procedure variable
  `gProblemReporter`, which covers all 85 call sites without changing any of them.
- **`cStringOf` given a `vtInt64` case.** FPC widens an integer expression such as `a - b` to
  `vtInt64`, which had no case, so it fell to the `else` and the value vanished from the line.

---

## 3. What is known to be still wrong

The full list with line numbers is in `docs/KinFert-TODO.md`, sections 3 and 3b. In summary:

**Changes results.** Three education defects (`N20` the stochastic mode ignores its six
parameters and draws a flat third; `N18` the intra-family mode correlates four kin types out of
twenty-seven; `N17` the partner correlation matrix is indexed with the wrong sex), `N19` the
cohort file records a different education table from the one used, `N32` an exception handler
that falls through and leaves the separation to two uninitialised doubles, `N4c` a redraw that
discards the Léridon taper when `RESHUFFLED_FECUNDABILITY` is on, `N10` a hardcoded sex ratio in
the reported net reproduction rate, four inheritance defects (`N22`, `N24`, `N25`, `N26`), and
`N42` with `N43`, where two cohorts can be given the same seed.

**Missing guardrails.** Five index computations in `Kinship.pas` with no bounds test, `N29` a
scale factor that can go to zero or negative, the unbounded duration index behind `N32`, cohort
file header indices, and four GUI fields that accept values the code cannot survive
(`STEP_COHORT` at zero gives an infinite loop, `MAX_THREADS` accepts 999999).

---

## 4. The six questions where a second opinion is worth most

1. **The groom pool that was planned and never built.** `Kinship.pas:400` declares
   `gBig_ArrayGrooms`, and the identifier appears nowhere else. Two pools exist, both of women:
   possible mothers and possible brides. The groom index is a re-indexing of the brides by the
   cohort and age at union their unions imply for a partner. A man therefore has no simulated
   life before the union at which he appears: no earlier unions, no earlier children, and his
   age at first union is the one the match implied rather than one drawn from the male schedule.
   Is a left-truncated male history acceptable for the quantities KinFert reports, and if not,
   whose reproductive history is the master when two simulated people form a union?

2. **`N17`, which index is wrong.** `eduEgoPartner` is declared `[EduLevels, Sex, EduLevels]`.
   The call reads `[eduLevelPartner, pRelative^.gender, ...]`, that is the partner's level with
   the sex of the person being assigned. Either the second index should be the partner's sex, or
   the matrix is meant as `[ego's level, ego's sex, partner's level]` and the first index is the
   one to change. The two readings give different results and the cohort file is filled in one
   of them.

3. **`N4c`, a bug or a different model.** With `RESHUFFLED_FECUNDABILITY` on, drawing a new
   fecundability level after every birth turns between-woman heterogeneity into within-woman
   variation. That is a different model of heterogeneity rather than a wrong version of the
   Léridon one. Should the switch be corrected to keep the taper, or documented as what it is?

4. **The five unguarded index computations.** Should an index outside its range be clamped, which
   keeps the run going with a substituted value, or refused, which stops the run? The answer is
   the same for all five and has been blocked on that decision since 2 September.

5. **The second implementation of `calcNbChildren`.** The routine and the procedures nested in
   it share `currMonth`, `nbChildren`, `endUnion`, `monthStart` and `pCurrChild` by scope rather
   than by argument, and every bug found in it this year comes from that. A second
   implementation, written from the demographic description rather than transcribed, run beside
   the first on the same woman with the same random numbers, would settle whether the interval
   machinery does what the model says. Is that worth its cost?

6. **What the Children-Grooms diagnostics should measure.** The tab now answers one question:
   of the searches the reconstruction made, how many found the cell they asked for. Is that the
   right question, and is the share by cohort and generation the right way to see it?

---

## 5. How to work on it

- **Build.** Lazarus, `kinfert.lpi`. The flags are `-Mobjfpc -Sh -Sm -Sa -Ci -Co -CO -Cr -O-`.
  Range and overflow checks are on, which matters for several of the defects above.
- **Build without the GUI.** The units that do not reach the LCL compile under FPC alone. The
  three that do, `LazMain`, `LazUtiles` and `LazGraph`, need TAChart and cannot.
- **`breakOnFailure`** in `Defines.pas` is `asm int 3` on Intel and `assert(false)` on ARM. It is
  for an invariant the code should never break, not for a condition the user can cause.
- **Check the line numbers** with `tools/check-line-numbers.py` after any edit. The routine name
  is the stable reference, the line number is not.
- **Two runs can be compared** with `tools/compareruns.lpr`, cell by cell, with an optional
  tolerance and an exit code that can drive a script.
- **Nothing in the last six rounds has been run against a simulation in Lazarus.** That is the
  first item in the TODO and the largest single risk to everything above.
