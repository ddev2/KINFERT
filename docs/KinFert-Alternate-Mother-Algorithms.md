# The four alternate mother-search algorithms: state and how to rescue them

Report of 14 September 2026. No code was changed for this report.

## 1. What the report answers

`KINFERT` builds an ascendant genealogy by finding, for a reference child, a mother
who actually had a child in the reference child's year of birth. That is
`LookingForMother`, and it draws on the pool of mothers built by `initMotherhood`.

Four other algorithms are present in `Kinship.pas`:

| Function | Line | Flag | Label in the output |
| --- | --- | --- | --- |
| `LookingForMotherBACKFOR` | 5305 | `gBACKFOR_mode` | `BACKFOR_mixed` |
| `LookingForMother_RealBACKFOR` | 5201 | `gBACKFOR_mode_pure` | `BACKFOR` |
| `LookingForMother_CAMSIM_1987` | 4988 | `gCAMSIM_1987` | `CAMSIM_1987` |
| `LookingForMother_CAMSIM_1993` | 5076 | `gCAMSIM_1993` | `CAMSIM_1993` |

The report says, for each of them, what is broken, what a rescue would require, and
whether the rescue can be done without touching anything that `LookingForMother` uses.

## 2. Two facts that make a rescue safe in principle

**The alternate code cannot run unless a box is ticked.** The four flags are declared
at `Kinship.pas:34-38` and all four are initialised to `false`. The only place that
writes them is the Utiles form (`LazUtiles.pas:126-240`), where five checkboxes
(`BACKFOR`, `RealBACKFOR`, `CAMSIM1987`, `CAMSIM1993`,
`CAMSIM1993_AgeUnionUnbounded`) set them and clear one another, so at most one
algorithm is active at a time. There is no command-file key and no command-line
switch. With every box left unticked, the dispatcher at `Kinship.pas:6085-6098`
falls through to `LookingForMother`, and not one line of the alternate code is
executed. Repairs confined to the four functions and to the helpers listed in
section 3 therefore cannot change the current results of the model, whatever they
do.

**The flags are read twice, at two different moments.** `gBACKFOR_mode` gates the
allocation of `RangeBirthsBACKFORNb` and `RangeBirthsBACKFORInfo`
(`Kinship.pas:3680-3687`) and their filling through `addChildrenBACKFORInfo`
(`3726`, `3743`, `3755`), all inside `initMotherhood`. `gCAMSIM_1993` gates the
allocation of `CAMSIM_RangeBirthsNb` and `CAMSIM_RangeBirthsInfo` (`3644-3649`) and
their filling inside `addChildrenInfo` (`2846-2855`). Both are then read again
during the kinship stage. A box ticked after the pre-simulation has run leaves the
matching index at length zero, and the first lookup is an index error. Any rescue
should either disable the checkboxes once `initMotherhood` has run, or force the
pre-simulation to be repeated when a box changes. This is the first thing to settle,
because it makes the difference between an algorithm that fails on the first ego and
one that can be tested at all.

## 3. What a rescue may touch and what it may not

Shared with `LookingForMother`, therefore not to be modified:

- `selectOneMother` (`4769`) and `updateInfoMother` (`4748`);
- `lookingForRefChild` (`4584`), `lookInChildrenRange`, `calcCompleteFertilityWoman`,
  `calcSiblings`, `infoRefChildToMotherAndSibling` (`4945`);
- the main birth index `g_RangeBirthsNb` and `g_RangeBirthsInfo`, and
  `addChildrenInfo` apart from the block already gated by `gCAMSIM_1993`;
- `ancestorsAndTheirOffspring` (`6065`), except for the dispatcher branches
  themselves.

Reached only when one of the four flags is true, therefore free to be modified:

- `BACKFOR_MotherAgeChildbearing` (`4870`), `BACKFOR_MotherAgeUnion` (`4889`),
  `CAMSIM_NumberChildren` (`4904`), `CAMSIM_MotherAgeChildbearing` (`4924`);
- `addChildrenBACKFORInfo` (`2864`) and the `RangeBirthsBACKFOR*` arrays;
- the `gCAMSIM_1993` block inside `addChildrenInfo` and the `CAMSIM_RangeBirths*`
  arrays;
- `gAgeChildbearingBACKFOR`, `gAgeChildbearingBACKFOR_post`, `gBACKFOR_women`,
  `gBACKFOR_nTries` and the parts of `writeAgeChildbearingStates` that report them.

One item sits between the two lists. `infoRefChildToMotherAndSibling` is used by
three of the four alternate functions and by nothing else, but it calls
`updateInfoMother`, which is shared. The function itself can be changed; the call
into `updateInfoMother` should be left as it is.

## 4. `LookingForMotherBACKFOR` (`gBACKFOR_mode`)

### State

This is the only one of the four that crashes on a path that will certainly be taken.

**The not-found path passes an unassigned object.** When no mother is found the
function reports `chk_kin_motherFoundBACKFOR` and then falls through to
`result := updateInfoMother (randomGenerator, womanObj, pRefChild, 0, pMother)` at
line 5377. `womanObj` is an `out` parameter that was never assigned; the caller's
variable (`ancestorsAndTheirOffspring`, line 6074) has no initial value, and an
`out` parameter of a class type is not cleared by the compiler. The first statement
of `updateInfoMother` dereferences it (`womanObj.cohort`). The comment at line 5365,
"we will use mother already found in previous step", describes an intention that was
never carried out: the mother found in step 1 was a local variable inside
`BACKFOR_MotherAgeChildbearing` and was discarded when that function returned. Lines
6116 and 6137 dereference the same object again.

**The two-sided fallback cannot run.** Lines 5342-5363 are meant to look at
neighbouring ages at union when the requested cell is empty, first in one direction
and then in the other. Both loops carry the same pair of bounds,
`ageUnionWomanTemp > kMinAgeUnion_women` and `ageUnionWomanTemp < ageChildbearing`.
The first loop only stops when one of those bounds is reached, and the second loop
starts from the value the first loop left, so the bound that stopped the first loop
also blocks the second at once. The second loop therefore never executes a single
iteration, and the search covers one side only. This is the same defect that was
found and repaired in the bride search in
`selectBrideByGroomCohortAndAgeAtUnion`. Reversing the direction requires resetting
`ageUnionWomanTemp` to `ageUnionWoman` before the second loop, as the bride search
now does.

**A latent inconsistency between the writer and the reader.**
`addChildrenBACKFORInfo` writes at `trunc (age at union) - kMinAgeFert` (line 2886)
into an array whose second dimension is `kMaxAgeFert - kMinAgeFert + 1` (line 3683).
`LookingForMotherBACKFOR` reads at `ageUnionWoman - kMinAgeUnion_women` (line 5334).
The two offsets are numerically equal today, because `kMinAgeFert = 10` and
`kMinAgeUnion_women = kMinAgeUnion = 10`, so the code works by coincidence rather
than by construction. The extents do not agree: the index is dimensioned on the
fertile age span, which ends at 59, while an age at union for a woman may reach
`kMaxAgeUnion_women`, which is 74. The writer stays inside the array because it only
stores the union in which a birth occurred, so the age at union it records cannot
exceed the age at childbearing. A rescue should give the array one axis with one
name, and state in a comment that the axis is the age at union of the union in which
the birth occurred, bounded above by `kMaxAgeFert`.

**An index that can go negative through a failed helper.** `ageChildbearing` comes
from `BACKFOR_MotherAgeChildbearing`, which sets `pRefChild^.ageMotherAtChildbirth`
through `lookingForRefChild` and then returns `trunc` of it. When
`lookingForRefChild` finds nothing it returns zero and leaves
`ageMotherAtChildbirth` untouched, so `ageChildbearing` can be zero or any leftover
value. It is then passed to `BACKFOR_MotherAgeUnion` as the upper age, and
`calc_ageUnion` assigns `round (ageMax)` to a variable of type
`agesSingle = 10..80`. With a zero upper age that assignment is a range error under
`-Cr`. With a small positive upper age the function returns that value and the index
`ageUnionWoman - kMinAgeUnion_women` is negative.

### Rescue

Four changes, all inside the function and its own helpers:

1. On the not-found path, obtain a mother instead of using an unassigned reference.
   The cleanest form is to have `BACKFOR_MotherAgeChildbearing` return the woman it
   used, through an extra `out` parameter, and to use her when the age-at-union
   lookup fails. That keeps the intention stated in the comment and calls no shared
   routine that is not already called on the same path.
2. Reset `ageUnionWomanTemp` before the second loop so that both directions are
   examined, and bound each loop on both sides, as the bride search now does.
3. Refuse an `ageChildbearing` outside `kMinAgeFert..kMaxAgeFert` before it is used
   as an upper age or as an index, and report it through the verification unit.
4. Give the index one named axis and use the same offset in the writer and in the
   reader.

Effort: about half a day. Risk to `LookingForMother`: none, provided the extra
parameter is added to `BACKFOR_MotherAgeChildbearing`, which no other path calls,
and not to `selectOneMother`.

## 5. `LookingForMother_RealBACKFOR` (`gBACKFOR_mode_pure`)

### State

This is the original Le Bras algorithm: draw an age at childbearing, draw an age at
first union below it, then simulate complete fertility histories until one of them
contains a birth at the drawn age at childbearing.

**The retreat on failure is unbounded.** When `kMaxTries` simulations have failed
(line 5259) the function reports `chk_kin_womenFoundInBackfor` and then moves
`ageChildbearing` by one year, downwards if it is above 30 and upwards otherwise,
with no lower or upper bound. The outer `repeat` has no cap of its own, so the walk
continues indefinitely. `ageChildren [ageChildbearing, 0]` at line 5257 is indexed
by `FecundAges`, that is 10 to 59, so a walk that reaches 9 or 60 is a range error.
Ten thousand failed fertility simulations per step make this slow as well as
unsafe.

**A draw from a possibly empty count.** Line 5274 draws
`trunc (alea (0, ageChildren [ageChildbearing, 0] - 1e-11))`. The loop above it can
be left either because a birth at that age was found or because `nTries` ran out,
and in the second case the count is zero. The draw then returns zero, the search
through the children list finds no child at that age, and
`pRefChild^.ageMotherAtChildbirth` keeps the value it had before.

**The same failed-helper path as section 4.** `ageChildbearing` comes from
`BACKFOR_MotherAgeChildbearing`, with the consequences described there.

### Rescue

1. Bound the retreat: keep `ageChildbearing` inside `kMinAgeFert..kMaxAgeFert`, and
   when the bound is reached, either reverse the direction once or give up on this
   reference child and report it.
2. Give the outer `repeat` a cap on the number of retreats, so that a configuration
   in which no suitable mother exists ends with a reported failure rather than an
   unbounded run.
3. Take the draw at line 5274 only when `motherFound` is true and the count is
   positive.

Effort: two to three hours. Risk to `LookingForMother`: none. This is the algorithm
whose behaviour is best documented in the literature, so it is the most useful of the
four to have working as a comparison.

## 6. `LookingForMother_CAMSIM_1987` (`gCAMSIM_1987`)

### State

**The mother's fertility is simulated with the wrong cohort.** Line 5015 sets
`cohortWoman := trunc (yearBirthRefChildInd)`, that is the reference child's own year
of birth, with the comment "We don't have the age at childbearing, so we assign a
year of birth for the mother equal to the ego's one". That value is then passed to
`getCohort_p (cohortWoman)` at line 5024, so the whole reproductive life of the
mother is drawn from the fertility, nuptiality and mortality of her child's cohort,
one generation too late. Only at line 5058, after the simulation, is the mother's
cohort corrected to `trunc (yearBirthRefChildInd - ageMotherAtChildbirth)`, and that
corrected value is what `infoRefChildToMotherAndSibling` then uses to create the
object. The result is a mother whose history belongs to one cohort and whose
identity belongs to another. This is a modelling error rather than a crash, and it is
the reason the algorithm would give results that cannot be compared with the others
even once it runs.

**The outer loop has no cap.** Lines 5017-5043: the inner `repeat` stops after
10 000 tries, and the outer `while (not motherFound)` then draws another age at
union, resets `nTries` to zero and starts again, without limit. A configuration in
which no woman of that cohort ever has a child gives a run that never ends.

**The literal 10 000 is written out twice** (lines 5036 and 5037) although
`kMaxTries` is declared at line 4902 with the same value.

**A draw from a count that may be zero.** Line 5046 draws a birth order in
`1..nbChildren`. The loop above guarantees `nbChildren > 0` on the normal path, so
this one is safe as long as the outer loop keeps its current shape.

### Rescue

1. Draw the age at childbearing before the fertility simulation instead of after it,
   so that the mother's cohort is known before `getCohort_p` is called. The simplest
   form uses the same helper as the other algorithms,
   `BACKFOR_MotherAgeChildbearing`, and then keeps the drawn value.
2. Cap the outer loop and report the failure.
3. Replace the two literals with `kMaxTries`.

Point 1 changes what the algorithm does, not only whether it runs. That is
unavoidable: as written, the algorithm does not do what its own comment says. The
change should be recorded in the documentation, since a reader comparing KINFERT with
the published CAMSIM results will want to know which variant was run.

Effort: half a day, most of it in deciding point 1 rather than in writing it.
Risk to `LookingForMother`: none.

## 7. `LookingForMother_CAMSIM_1993` (`gCAMSIM_1993`)

### State

This one has the largest number of separate defects, spread over the function and its
two helpers.

In `CAMSIM_NumberChildren` (`4904`):

- line 4916 divides by `CAMSIM_RangeBirthsNb[0, cohortChildInd]`, the number of
  births recorded for that cohort, with no test for zero. A cohort cell that holds no
  births gives a division by zero.
- the `while (dummy > sum)` loop at line 4915 has no upper bound on `indChild`. The
  parity shares do sum to one in exact arithmetic, because line 2854 increments the
  total in step with every parity cell, so the loop normally stops at parity 15 at
  the latest. It is the rounding of fifteen divisions that is not guaranteed: a sum
  that ends at one part in 10^16 below `dummy` sends the loop to `indChild = 16` and
  the array read is out of range. The correction to `kMaxNbChildrenCalc` at lines
  4919-4920 is applied after the loop, so it does not protect the read.

In `CAMSIM_MotherAgeChildbearing` (`4924`):

- line 4934 draws `alea (0, CAMSIM_RangeBirthsNb[numChildrenSelected, cohortChildInd]
  - 1e-11)` with no test that the count is positive. An empty cell gives an index of
  zero into a row that was allocated but never filled, so `womanInd` is zero and the
  woman returned is the first woman in the array, who has no reason to have had a
  birth in that year. `lookingForRefChild` then reports
  `chk_kin_foundLookingForRefChild` and leaves `ageMotherAtChildbirth` unchanged, and
  the function returns `trunc` of whatever that was.

In `LookingForMother_CAMSIM_1993` itself:

- `cohortWoman` is computed once at line 5112, from the age at childbearing drawn
  before the loop. Inside the loop, lines 5116-5120 may redraw the age at childbearing
  and lines 5161-5166 may move it by a year, but `cohortWoman` is never recomputed.
  The fertility simulation at line 5138 therefore uses a cohort that does not
  correspond to the age at childbearing being sought.
- the reshuffle at lines 5116-5120 redraws once and does not check the result, so
  `ageChildbearing` can still be outside 13 to 54 when it is used at line 5156 to
  index `ageChildren`, whose first axis is `FecundAges`, 10 to 59. A value of zero,
  which `CAMSIM_MotherAgeChildbearing` can return as described above, is a range
  error.
- the retreat at lines 5161-5166 has the same unbounded shape as in
  `LookingForMother_RealBACKFOR`, and the outer `while not motherFound` has no cap.
- `birthOrderSelected` is assigned at line 5154 inside the inner `repeat`. If that
  `repeat` is left through the `continue` at line 5152 on its last iteration, the
  variable is used at line 5176 without having been assigned in that pass.
- the `continue` at line 5128, when the drawn age at union exceeds the age at
  childbearing, returns to the top of the outer `while` without redrawing
  `ageChildbearing` or `cohortWoman`, so with an unlucky pair of values it can spin.

### Rescue

1. In `CAMSIM_NumberChildren`, test the total before dividing, and bound the loop by
   `kMaxNbChildrenCalc` inside the condition rather than after it.
2. In `CAMSIM_MotherAgeChildbearing`, return a clear "not found" when the cell is
   empty, and let the caller redraw or report.
3. Recompute `cohortWoman` from `ageChildbearing` at the top of the outer loop.
4. Repeat the reshuffle at lines 5116-5120 until the value is inside the accepted
   range, or report a failure, rather than redrawing once.
5. Bound the retreat and cap the outer loop, as in section 5.
6. Set `birthOrderSelected` to zero at the top of each pass and treat zero as a
   failed pass.

Effort: one day. Risk to `LookingForMother`: none, since both helpers and the CAMSIM
index are reached only under this flag.

## 8. Defects common to all four

**Every one of them takes the reference child's cohort at face value.** All four
compute the cohort as `trunc (pRefChild^.yearBirth)` and then pass it through
`lookInChildrenRange`, which brings a cohort outside the index range back to the
nearest cohort the index holds. `LookingForMother` does the same, so the treatment is
consistent, but the four alternates were written before the range bookkeeping was
added and none of them records the displacement. If they are to be compared with
`LookingForMother`, they should call `lookInChildrenRange` with the type of kin, as
`LookingForMother` now does, so that the diagnostic counts by ascendant generation
cover them too. Three of the four already pass `pRefChild^.typeOfKin`; this should be
checked once more after any edit.

**The three that create a mother object inflate a shared table.** The constructor
`TPersonMemoryBlock.Create` calls `incrementNbChildren` on
`getCohort_p (cohort)^.distNbChildren` whenever `ageUnionTrunc` is not positive
(`Parenthood.pas:193-199`). `infoRefChildToMotherAndSibling` passes zero, so every
mother retro-simulated by `LookingForMother_RealBACKFOR`,
`LookingForMother_CAMSIM_1987` and `LookingForMother_CAMSIM_1993` adds one
observation to the cohort parity distribution of the demographic regime. That table
is then reported as if it described the pre-simulated population. This affects only
runs with one of those three flags set, but it should be fixed at the same time,
either by passing a flag through the constructor or by using a separate table for
retro-simulated mothers.

**Copies rather than references.** One thing that is right and worth recording,
because it looks wrong on a first reading: the three algorithms that simulate a
mother call `disposeChild (pChild)` and `FreeAndNil (unionStates)` immediately after
`infoRefChildToMotherAndSibling` returns. That is safe, because the constructor copies
both (`ms.copyMe (unionStates)` and `duplicateChildrenList (pCh)`). The retry loops
are also free of leaks, because `calcCompleteFertilityWoman` calls
`disposeChild (pChild)` and zeroes `ageChildren` at entry when
`param_newPartnershipLife` is true, which is the default and what all four pass.

**Nothing reports how often each fallback was used.** `gBACKFOR_women` and
`gBACKFOR_nTries` count women and tries, and `gAgeChildbearingBACKFOR` and
`gAgeChildbearingBACKFOR_post` hold the distribution of ages at childbearing before
and after the search. There is no count of empty cells, of neighbouring cells used,
or of reference children abandoned. The counters written for the main mother and
bride searches, `gMotherSearch`, `gMotherSearchMiss` and `gMotherSearchYears`, could
be reused without change, since they are indexed by ascendant generation and cohort
and are filled by one recorder, `countSearch`.

## 9. Suggested order

1. Settle the flag timing described in section 2. Without it, nothing can be tested.
2. Repair `LookingForMother_RealBACKFOR` (section 5). It is the smallest piece of
   work, it is the published algorithm, and it needs no index of its own.
3. Repair `LookingForMotherBACKFOR` (section 4). It is the one that crashes first,
   and the repair of its two-sided fallback follows a pattern that is already in the
   code.
4. Decide what to do about `LookingForMother_CAMSIM_1987` (section 6). The cohort
   question is a choice about the model, not a repair, and it should be recorded in
   the manual.
5. Repair `LookingForMother_CAMSIM_1993` (section 7), or set it aside. It carries the
   most defects and the least independent value, since CAMSIM 1987 and the BACKFOR
   variants already give three points of comparison.

An alternative is worth stating plainly: if the four alternates are kept only so that
the published algorithms can be compared with KINFERT's own, then repairing two of
them and removing the other two would leave less code to maintain and less to
document before release. Whichever is chosen, the four should not be left in the
published version in their present state without a line in the manual saying that the
checkboxes are not supported.

## 10. What was not done

No source file was changed for this report. No verification identifier was added. The
line numbers refer to `Kinship.pas` as of 14 September 2026, after the repairs of
round 7.
