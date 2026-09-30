# The four alternate mother searches: what was repaired, and the four decisions left to you

15 September 2026. Companion to `KinFert-Alternate-Mother-Algorithms.md`, which described the
state of the four before any change. This document records what has been changed in the source
and what has deliberately not been, because the answer is yours rather than mine.

Everything changed is inside `// >>> Claude 2026-09-14` or `// >>> Claude 2026-09-15` markers in
`Kinship.pas` and `Verification.pas`. The headless build compiles with no errors. No routine on
`LookingForMother`'s own path was modified, so with `MOTHER_ALGORITHM=KINFERT` the sequence of
random draws is unchanged and so are the results.

## 1. Two defects that changed numbers, with the evidence

Both were found while repairing `LookingForMother_CAMSIM_1993` and `LookingForMotherBACKFOR`,
and both were tested in isolation with a small program rather than argued from reading.

**The parity draw in `CAMSIM_NumberChildren` was shifted by one parity.** The loop added the
share of parity `indChild`, incremented `indChild`, and then tested, so a number drawn inside
the share of parity one came back as parity two. With a made up distribution of 40, 30, 20, 7
and 3 per cent over parities one to five, and 100 000 draws:

| parity | wanted | old loop | corrected loop |
| --- | --- | --- | --- |
| 1 | 40.00 | 0.00 | 40.07 |
| 2 | 30.00 | 40.07 | 29.96 |
| 3 | 20.00 | 29.96 | 19.87 |
| 4 | 7.00 | 19.87 | 7.05 |
| 5 | 3.00 | 7.05 | 3.05 |
| 6 | 0.00 | 3.05 | 0.00 |

Parity one was never drawn at all. The loop is now the standard inverse distribution form,
incrementing before adding, and it is bounded by `kMaxNbChildrenCalc` inside its own condition
rather than after it, which also removes the one in 10^16 chance of reading past the end of the
parity axis.

**The two sided sweep over neighbouring ages at union never ran in the second direction.** Both
loops carried the same pair of bounds and the second started from the value the first had left,
so the bound that stopped the first blocked the second at its own first test. Over an index row
holding mothers only at ages at union 22 and 23, with an age at childbearing of 30:

| age at union asked | corrected sweep answers at | original sweep |
| --- | --- | --- |
| 10 | 22 | nothing found |
| 11 to 19 | 22 | 22 |
| 20 | 22 | nothing found |
| 21 | 22 | nothing found |
| 22 | 22 | 22 |
| 23 to 29 | 23 | 23 |
| 30 | 23 | nothing found |

The failures at 20 and 21 come from the direction rule `grow := (ageUnionWoman < 20)`, which
sends the search downwards from 20, and the failures at 10 and 30 from the bounds blocking both
loops at once. This is the same defect that was repaired in the bride search in
`selectBrideByGroomCohortAndAgeAtUnion`, and it is now written as one nested function,
`nearestAgeAtUnionHeld`, which walks outwards on both sides.

## 2. What else was repaired, by function

**`LookingForMotherBACKFOR`**, the one that could not run at all. Its not-found path called
`updateInfoMother` with a `womanObj` that was never assigned: the comment said the mother found
in the previous step would be used, but that mother was a local variable inside
`BACKFOR_MotherAgeChildbearing` and was gone when it returned. An `out` parameter of a class
type is not cleared by the compiler and the caller's variable has no initial value either, so
the first line of `updateInfoMother` dereferenced whatever the stack held. The sweep now covers
every age at union the index could answer, and when the row is empty the age at childbearing is
drawn again, since a larger age at childbearing is what widens the range of ages at union
allowed. When that is spent the run stops with the reason. A displacement between the age at
union asked for and the one used is reported through `motherFoundBACKFOR`, so it can be counted.
One redundant call to `lookingForRefChild` was dropped: its result was assigned to a variable
that was never read, and it repeated the search `updateInfoMother` performs immediately
afterwards, walking the same children list twice for every reference child.

**`LookingForMother_CAMSIM_1987`**, two guardrails. The outer loop had no cap, so a cohort in
which no woman ever bears a child gave a run that never ends; it now stops after
`kMaxPassesBACKFOR` passes with the reason. The two literal 10000 were replaced by `kMaxTries`,
which is declared above with the same value.

**`LookingForMother_CAMSIM_1993`**, five repairs. `cohortWoman` was computed once before the
loop although the age at childbearing it follows from changes inside the loop, so the mother was
simulated with the rates of a cohort that did not match the age being sought; it is recomputed
on every pass. The reshuffle of an out of range age at childbearing drew once and did not check
what came back, so a value of zero could still index `ageChildren`; it now draws until the pair
holds or the draws are spent. The unbounded one year move of the age at childbearing is gone
altogether, for the reason given in decision 2 below. The `continue` taken when the age at union
exceeds the age at childbearing now passes through the pass cap, so a pair of values that can
never agree no longer spins. `CAMSIM_MotherAgeChildbearing` refuses a parity the index cannot
answer, and parity zero, which is the total cell and not a parity, instead of drawing from an
empty count and reading an unrelated woman.

One item from the earlier report was wrong and is withdrawn: `birthOrderSelected` cannot be used
unassigned. It is read only when `motherFound` is true, which requires the iteration that
assigned it to have completed.

## 3. The four decisions

### Decision 1. The cohort CAMSIM 1987 simulates the mother with

`LookingForMother_CAMSIM_1987` sets the mother's cohort to her own child's year of birth and
simulates her whole reproductive life with the fertility, nuptiality and mortality of that
cohort, one generation too late. Her cohort is corrected afterwards from the age at childbearing
that came out of the simulation, so the woman ends with the history of one cohort and the
identity of another. The line is left as it stands, with a comment marking the decision, because
the original comment says that the age at childbearing is not known at that point, which is true
of the algorithm as published, so changing it changes what the algorithm is rather than repairing
it.

Three options:

1. Draw the age at childbearing first, with `BACKFOR_MotherAgeChildbearing`, derive her cohort
   from it, and simulate with that. The mother is then internally consistent, and CAMSIM 1987
   becomes closer to BACKFOR than the published description is.
2. Leave it, and say in the manual that the variant implemented simulates the mother with her
   child's cohort. Under a stable population, where every cohort has the same rates, this makes
   no difference at all, and the comparison you want to run is a stable population comparison.
3. Iterate: simulate with the child's cohort, take the age at childbearing that results, and
   simulate again with the corrected cohort until the cohort stops moving. Faithful and slow.

Option 2 costs nothing and is honest, provided the comparison runs are stable population runs.
That is what I would choose, but it is your reading of CAMSIM that should settle it.

### Decision 2. Whether CAMSIM 1993 should keep the parity and the age at childbearing together

In CAMSIM 1993 the age at childbearing is drawn from the mothers of the parity drawn just
before, so the two belong together. The old code, on failing to find a mother, moved the age at
childbearing by one year and kept the parity, which breaks that pair. I have replaced the move
with a redraw of both, using the function the algorithm already has for it. That follows the
description at the head of the function, and it is what I did in `LookingForMother_RealBACKFOR`,
so the two are consistent.

If you read the published method as moving the age while holding the parity, tell me and I will
put the bounded move back instead. Nothing else in the repair depends on the choice.

### Decision 3. Whether CAMSIM 1993 should require the parity it drew

The description at the head of the function says "look for a mother with that number of
children". The code does not do that: it accepts any simulated woman whose parity is at most
`kMaxNbChildrenCalc` and who has a birth at the age at childbearing sought, without requiring
her parity to equal `numChildrenSelected`. Enforcing the parity would make the algorithm
faithful to its own description and to CAMSIM 1993 as published, and would make the search much
more expensive, since it adds a second condition to a rejection loop that already costs up to
`kMaxTries` complete fertility histories. I have not changed it, because it is a choice about
what the algorithm is.

### Decision 4. The parity distribution inflated by the retro-simulated mothers

The three alternates that simulate a mother create her with `TPersonMemoryBlock.Create`, whose
constructor calls `incrementNbChildren` on `getCohort_p (cohort)^.distNbChildren` whenever the
truncation age is not positive (`Parenthood.pas:193-199`), and
`infoRefChildToMotherAndSibling` passes zero. Every retro-simulated mother therefore adds an
observation to the cohort parity distribution of the demographic regime, which is then reported
as though it described the pre-simulated population.

This is the one repair that would touch a routine `LookingForMother` also calls. The safe form
is a parameter with a default value on the constructor, so that the existing call sites compile
and behave identically, but it is still an edit inside shared code and I would rather you decide
whether to make it now or after the four algorithms have been seen to run.

## 4. How to test

The five algorithms are now selected from the configuration file, so the comparison is five runs
of one file. Single threaded, `INIT_RANDOM_NUMBERS` on, a small cohort range first:

```
MOTHER_ALGORITHM=KINFERT
MOTHER_ALGORITHM=BACKFOR
MOTHER_ALGORITHM=BACKFOR_MIXED
MOTHER_ALGORITHM=CAMSIM_1987
MOTHER_ALGORITHM=CAMSIM_1993
```

The first of the five is the control: compare its output folder against a run from before these
changes, file by file. The only expected difference is in `verification.txt`, which now holds
four more failure points that recorded nothing: `backforAgeChildbearing`,
`backforAgeDrawnAgain`, `backforNoMother` and `camsimParityIndexEmpty`.

For the other four, `verification.txt` is where to look first. `backforAgeChildbearing` and
`camsimParityIndexEmpty` should record nothing; if either fires, the pool of mothers cannot
answer the question the algorithm is asking and the cohort range is the first thing to check.
`womenFoundInBackfor` and `backforAgeDrawnAgain` are expected to fire sometimes, and their counts
are the useful measure of how hard the search is working. `gAgeChildbearingBACKFOR` and
`gAgeChildbearingBACKFOR_post`, written by `writeAgeChildbearingStates`, show the distribution
of ages at childbearing before and after the search, and the two should now agree closely.
