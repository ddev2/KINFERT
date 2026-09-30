# KINFERT: state of play, 15 September 2026

Written so that this week's work survives a compaction or a new session. It supersedes
`KinFert-Handover-2026-09-13.md` for everything after 13 September. Read it together with:

- `docs/KinFert-TODO.md` and `docs/KinFert-FIXED.md`, the standing lists
- `docs/KinFert-Alternate-Mother-Algorithms.md`, the state of the four alternates before repair
- `docs/KinFert-Alternate-Algorithms-Decisions.md`, what was repaired and what Daniel must decide
- `docs/KinFert-ChatGPT-Audit-Verified.md`, the second reviewer's audit checked claim by claim
- `JASS/KINFERT annex - backward algorithms and criterion.docx`, the annex for the paper

## 1. What changed in the source, 14 and 15 September

All of it is inside `// >>> Claude 2026-09-14` or `// >>> Claude 2026-09-15` markers. The headless
build compiles with no errors. Nothing on `LookingForMother`'s own path was modified, so with
`MOTHER_ALGORITHM=KINFERT` the sequence of random draws is unchanged.

Files touched: `Kinship.pas`, `Verification.pas`, `Declarations.pas`, `Init.pas`,
`ReadCmdFileUnit.pas`, and `LazLowlevel.lfm` (two lines, no marker possible in an LFM).

**The algorithm is now chosen from the configuration file.** New parameter `MOTHER_ALGORITHM`,
which accepts a name or a number: `KINFERT` (0), `BACKFOR` (1), `BACKFOR_MIXED` (2),
`CAMSIM_1987` (3), `CAMSIM_1993` (4), plus the boolean `CAMSIM_1993_ANY_AGE_UNION`. A new
parameter class `MotherAlgorithmName` in `Declarations.pas` holds it; unlike the three older enum
readers it does not mutate the value before reporting an invalid one. `applyMotherAlgorithm` in
`Kinship.pas` is called at the top of `initMotherhood`, before anything is allocated: the
configuration file wins when it named an algorithm, the Utiles checkboxes when it did not, and in
the second case the parameter is set from the checkboxes so a dumped configuration records what
actually ran. This removes the timing hazard, since the flags decide whether the index each
alternate reads is built at all.

**The four alternates were repaired.** Each had at least one unbounded loop or one index that
could leave its array. Two of them drew from the wrong distribution:

- `CAMSIM_NumberChildren` returned the parity above the one drawn. Parity one was never drawn at
  all. Demonstrated with a test program: over 100 000 draws from a distribution of 40, 30, 20, 7
  and 3 per cent, the old loop gave 0.00, 40.07, 29.96, 19.87, 7.05; the corrected loop gives
  40.07, 29.96, 19.87, 7.05, 3.05.
- The two-sided sweep over neighbouring ages at union in `LookingForMotherBACKFOR` never ran in
  its second direction, because both loops carried the same bounds and the second started where
  the first stopped. Same defect as the bride search. It now walks outwards on both sides,
  through the nested function `nearestAgeAtUnionHeld`.

`LookingForMotherBACKFOR` also called `updateInfoMother` with a `womanObj` that was never
assigned on its not-found path, which is why it could not run at all.

New check ids: `chk_kin_backforAgeChildbearing`, `chk_kin_backforAgeDrawnAgain`,
`chk_kin_backforNoMother`, `chk_kin_camsimParityIndexEmpty`. New bounds, next to `kMaxTries`:
`kMaxRetreatsBACKFOR = 20`, `kMaxPassesBACKFOR = 40`, `kMaxDrawsBACKFOR = 10`,
`kMinAgeChildbearingCAMSIM = 13`, `kMaxAgeChildbearingCAMSIM = 54`.

**The one-year move of the age at childbearing is a documented device, not an accident.** The note
to Table 2 of `JASS/Kinship Micro2.docx` says that when no couple with a birth at the selected age
is found after 10 000 tries, that age is increased or decreased by one year until an adequate
couple is found, and that the reported mean numbers of tries are underestimates because of it. I
had removed it from CAMSIM_1993 and put it back on 15 September, bounded on both sides, with a
redraw of the parity and the age only after twenty moves have failed. `LookingForMother_RealBACKFOR`
already had that shape.

## 2. What Daniel still has to decide

1. **CAMSIM 1987 simulates the mother with her own child's cohort.** Left as it stands, with a
   comment marking the decision. Under a stable population it makes no difference, and the
   comparison runs are stable population runs, so saying so in the manual is the cheap option.
2. **CAMSIM 1993 does not enforce the parity it drew.** Paragraph 3.35 of the paper says the woman
   must have the number of children drawn in the first step; the code tests only the age at
   childbearing and accepts any parity up to fifteen.
3. **CAMSIM 1993 redraws the birth order at every trial.** Paragraph 3.34 says it is drawn once,
   in the first step.
4. **The parity table is inflated by the retro-simulated mothers.** `TPersonMemoryBlock.Create`
   calls `incrementNbChildren` on `getCohort_p(cohort)^.distNbChildren` whenever the truncation
   age is not positive, and `infoRefChildToMotherAndSibling` passes zero, so every mother the
   three simulating alternates create adds an observation to the cohort parity distribution. This
   is the one repair that would touch a constructor `LookingForMother` also calls; the safe form
   is a parameter with a default value.

## 3. How to verify, and what to expect

Single threaded, `INIT_RANDOM_NUMBERS` on, a small cohort range, five runs of one configuration
file changing only `MOTHER_ALGORITHM`.

The KINFERT run is the control: compare its output folder against a run from before 14 September,
file by file. The only expected difference is in `verification.txt`, which gains four failure
points that recorded nothing: `backforAgeChildbearing`, `backforAgeDrawnAgain`, `backforNoMother`,
`camsimParityIndexEmpty`. Anything else differing means something shared was touched.

For the four alternates, the criterion is equation [5] of the paper:

    m1_egos = m + variance(m) / m

the fertility of the mothers of egos computed from the genealogies equals the fertility of female
egos plus the variance of their number of children over its mean, after the correction factor
exp(1.2 r) for a growing population. The published comparison found that CAMSIM_87 recovers
exactly `m1_mothers`, that is low by variance over mean; Le Bras' BACKFOR and CAMSIM_93 overshoot,
because the age at union is drawn conditional only on being below the age at maternity; KINFERT
recovers the correct value at every fertility level. **The repaired CAMSIM_87 should still land on
`m1_mothers`.** If it lands anywhere else, the repair changed the algorithm and that is the first
thing to investigate.

## 4. Open items not related to the alternates

- The education defect, the most consequential thing found this week: `cumulValue` is built once
  in `initEduStatus` and the cohort reader and interpolation write only `.value`, so in
  `eduCohort` or `eduIntraFamily` mode the probabilities asked for are echoed in the dump while
  every individual is drawn from the shipped defaults. Not yet fixed.
- `parameterStateName.readValue` zeroes the numeric value whenever the token is a word, and the
  parameter's own comment invites `FIXED_DEFINITIVE_STERILITY=TRUE`, which sets sterility to one
  at every age and produces a run with no births. Not yet fixed.
- The vocabulary pass replacing "clamp" in 35 places in the source and 17 in the documents.
  Agreed scheme: "bounded" for a loop that cannot run past a limit, "constrained to the range" or
  "brought back to the nearest cohort the index holds" for a cohort outside the range, "answered
  from a neighbouring cohort" for an empty cell inside the range, "substitution" as the umbrella.
- `git push -u origin review/2026-09-13` from the Mac. The device shell has no GitHub credentials.
- Not built in Lazarus since round 6. Review markers are still in place throughout; they are
  stripped with `python3 tools/strip-claude-marks.py` after Daniel accepts them.

## 5. Working rules that must survive any compaction

- Every source change is wrapped in `// >>> Claude YYYY-MM-DD start` and
  `// <<< Claude YYYY-MM-DD end`, one pair per changed region. Daniel reviews and accepts, then
  strips the markers himself. An applied edit is not settled until he has looked at it.
- Writing style for anything in English: plain formal register for an academic demography
  readership, never an em dash, and avoid the list of words he keeps.
- The live project is at
  `/Users/daniel/My Drive (ddevolder@ced.uab.es)/Documents/Claude/Projects/KINFERT`. Google Drive
  blocks `unlink`, so every git command leaves a stale `.git/index.lock`; move it into
  `_to_delete/` before each git command.
- The headless build lives in the container scratchpad and uses LCL stubs for `LazUtiles.pas` and
  `LazMain.pas`. Command line:
  `fpc -Mobjfpc -Sh -Sm -Sa -Ci -Co -CO -Cr -O- -dLAZARUS_GUI Simulxcode.pas`.
  `LazGraph.pas` cannot be compiled there; it is syntax-checked by extracting routines into stub
  programs. The "Type size mismatch" warnings are produced by the flag set for every
  `longint := longint - longint` in the project and are not introduced by any edit.
