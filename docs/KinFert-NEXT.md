# KinFert: what to do next

**31 August 2026.** A short, ordered action list. The reasoning, the line numbers and the
full catalogue of findings are in `docs/KinFert-Status.md`; this file exists so that you can
open one page and know what to do this morning without reading the other one.

Rule of thumb for this list: **nothing below step 3 is worth starting until steps 1 to 3 are
done.** Two rounds of fixes have never been run, and a fix you cannot test is not a fix.

---

## Right now

### 1. Commit. Ten minutes.

Sixteen source files and two documents are modified and uncommitted, including everything from
this session. Commit before touching anything else, so the state that compiles is recoverable
on its own.

In GitHub Desktop, Summary: `Debug-switch consolidation; fecundability heterogeneity fixes`.
If it refuses with a lock-file message, that is the stale `.git/index.lock` problem again.

### 2. Build in Lazarus. This is V1, and it gates everything.

Eighteen units compile under FPC 3.2.2 with the Lazarus 3.0 LCL in a container, using your own
flags from `kinfert.lpi`. What that check cannot cover is the `.lfm` resource binding and the
three GUI units that reach TAChart: `LazMain`, `LazUtiles`, `LazGraph`. Those only build in
Lazarus on your machine.

Expect to have to look at `LazUtiles.pas`, since the Utiles form is the one that changed
(`gDebugSession` in `DEBUGChange`).

### 3. Check the debug switch actually works now.

Tick **Activate debug** on the Utiles form (main window, the "Debug" button), then run without
saving the configuration first. `DEBUG` should still be on when the run starts. Before this
session it was wiped twice per run. If it is off, look at `Init.pas` `initGeneralCmd_values`
first.

While you are there, confirm a `dumpArray` call produces its file in the results folder.

---

## Then, in this order

### 4. Verify the fecundability work against Léridon's own numbers. V16b.

This is the first substantive test and it exercises N4, N4b, N4d, N8 and N13 together. Léridon
(2004) Table I, for conception ending in a live birth:

| | age 30 | age 35 | age 40 |
|---|---|---|---|
| within 12 months | 75.4% | 66.0% | 44.3% |
| within 4 years | 90.7% | 83.9% | 63.7% |

Median age at onset of sterility 44.7 years, against 50.5 for menopause and 41.2 for the last
birth.

**If you come out too fecund**, the truncation is the likely reason and the comment at the call
site in `Fertility.pas` tells you what to change (`N(0.2133, 0.1350)` instead of the nominal
`N(0.23, 0.12)`). **If you come out close**, leave it and record the realised moments, 0.2381
and 0.1118, in the manual rather than the nominal ones.

Also dump `gDistrib_fecundability` and check that the cumulative reaches 0.5 near index 69,
which is where the multiplier equals 1.

### 5. Run the tests that have never been run. V2 to V15, V20 to V23.

Three rounds of fixes are sitting untested. `docs/KinFert-Status.md` section 7 lists them with
what each one is checking. The two that matter most:

- **V14 and V14d**, the parameter sweeps. V14 tells you the N1 fix works; V14d tells you that
  ordinary single-parameterisation runs are byte-identical to before, which is what lets you
  keep every non-stepped result you have already published.
- **V23**, for N42: several cohorts with multithreading and `MULTITHREADING_INIT` on, checking
  that no two cohorts got the same random seed.

### 6. Answer Q2, then apply N2 and N6.

The two time-origin errors in the birth interval. Q2 is one sentence: is `LivingBirth` counted
from conception, so that the correction is to add the gestation to the death term rather than
subtract it from `month`? Verify with V17.

### 7. N8 and N7 together.

The sterility floor and the PPR target adjustment. They interact: a wrong sterility floor is
absorbed by the PPR calibration, so fixing one without the other moves the error rather than
removing it. N8 is one line and ready.

### 8. N9 and N10.

The growth rate and the net reproduction rate, both about the proportion female at birth. Small
and self-contained.

### 9. N13 and N14, mortality.

The inverted infant-mortality correction, and whether an out-of-range life expectancy should be
clamped.

### 10. Answer Q3 and Q4, then the inheritance module.

N22, N24, N25, N26. This is the largest single block of unfixed results-affecting work, and it
is blocked entirely on your decisions about Spanish succession. Verify with V18.

### 11. Education: N17, N19, N20, and Q5 for N18.

Four separate decisions rather than one fix. N19 changes the cohort file format, so decide
whether that happens before or after the release.

---

## After the results are right

12. **N11**, cohort parameter lists, and the `setChanged` comment for 6.4.
13. **Tier C**, one item at a time with its own test: 2.3, 2.4, 2.5, N34, N35, N36, N37, N38,
    N42, N43, N44. Each needs a design decision; a wrong fix here is worse than the bug.
14. **B1**, removing bootstrapping, as one deliberate change, with N41 as its acceptance test.
15. The remaining settings, output-hygiene and bounds items: sections 3, 4 and 5 of the status
    document. N45 and N46 are in there and are both small.
16. **N39**: `mothersInfoList.pas` is still present despite a commit message saying otherwise.
    Delete it properly this time.

---

## Publication, once the results are settled

17. ~~**P9**~~ **done 31 August**: `Fertility.pas` converted to LF. Consider a `.gitattributes`
    with `*.pas text eol=lf`, since `LazConfig.pas` is still CRLF and mixed endings across two
    platforms produce spurious whole-file diffs.
18. **P3** `*.cfg.example` templates, **P4** pin the Lazarus and FPC versions, **P5** decide how
    binaries are built and released, **P6** a minimal regression test.
19. **P8**, decide what to say about results produced with the versions that carried N1, N3 and
    N4. This one deserves thought: N4 changed fertility, and the repository is public.
20. Documentation, M1 to M7. M6 in particular: whatever you settled on fecundability changes the
    model description, not only the code.

---

## Decisions only you can make, and what each one blocks

| | question | blocks |
|---|---|---|
| **Q2** | Is `LivingBirth` counted from conception? | N2, step 6 |
| **Q3** | How far should inheritance follow Spanish succession: does a nearer ascendant exclude a remoter one, are posthumous children heirs, what happens when no heir is found, is usufruct modelled, is per-capita competition at degree 4 deliberate? | N22, N24, N26, step 10 |
| **Q4** | Should `inher_Spain` / `inher_Other` select between rule sets, or is the parameter a leftover? | N25, step 10 |
| **Q5** | Should education correlate between siblings? At present it does not. | N18, step 11 |
| **Q6** | Can the repartnering model emit a union age above 74? | several index bounds |
| **Q7** | Do `union_women_men` rows always reach 1.0? | an unguarded sampling loop |
| **N19** | Correcting the education dump changes the cohort file format. Before or after the release? | step 11, M3 |

Q1 is closed: Léridon (2004) p. 1550 and Figure 1 specify a Gaussian, `Fmax = N(0.23; 0.12)`,
with the standard deviation in fecundability units.
