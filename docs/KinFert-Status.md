# KinFert: consolidated status and remaining work

**Last updated 31 August 2026.** This document replaces `docs/KinFert-TODO.md` as the working list.
It brings together the two audits, the Tier A change log, and the open questions into one place,
and every line number in it was re-checked against the working tree on this date.

**If you only want to know what to do next, read `docs/KinFert-NEXT.md` instead.** That is a
short ordered action list. This file is the reference behind it: every finding, every line
number, every decision.

Earlier documents remain useful as evidence and are not superseded as such:

- `docs/KinFert-PreRelease-Audit.md`: the individual-file output path, first pass.
- `docs/KinFert-PreRelease-Audit-2.md`: the demographic engine, second pass.
- `docs/CHANGES-2026-08-26.md`: the index of the Tier A edits.
- `docs/KinFert-TODO.md`: the previous working list. Its line numbers are now stale.

---

## 0. Where the project is today

**The Tier A fixes are in the tree and you have approved them.** All seventeen sites
(N1, N3, N5, N12, N15, N16, N21, N23, N27, N33, N33b, N40, 2.6, 3.e, 4.9, A1, A2) were
re-checked line by line: every corrected statement is present, and the
`// --- CLAUDE 2026-08-26 [ID]` comment blocks that carried the replaced code have been
removed. `SpecialRuns.pas` keeps its markers under the name `FIX`, and `Kinship.pas`
keeps two lines of the `[2.6]` marker. Nothing else carries a marker.

**Git.** Eight units are modified in the working tree and not committed:
`DemographicRegime.pas`, `EducationalLevel.pas`, `Kinship.pas`, `Mortality.pas`,
`Nuptiality.pas`, `Parenthood.pas`, `ReadCmdFileUnit.pas`, `inheritance.pas`.
The change is 10 insertions and 208 deletions, which is the removal of the comment
blocks. `git diff` will show it. HEAD is `e4d8999`.

**A commit is the first thing to do**, before any new edit, so that the reviewed state is
recoverable on its own. **The pending change is purely cosmetic**: the Tier A fixes
themselves were already committed in `3ab5e7f`, `13e7a70` and `e4d8999`. What is pending
is only the deletion of the review comments and of the trailing `{ N12 }` style tags.
Verified on 31 August by stripping every comment from both versions of all eight units and
comparing: the executable code is identical, line for line, in all of them (13,753
statement lines). Committing it therefore cannot change behaviour.

**Nothing has been built in Lazarus.** The container build covered every unit except
`LazMain`, `LazUtiles` and `LazGraph`, which reach TAChart. The `.lfm` binding can only
be checked by Lazarus itself. **V1 below is still the gate on everything else.**

### What changed in the findings themselves since the last list

Re-reading the current source corrected five entries. These are not new bugs; they are
old entries that were imprecise, and the correction changes what you would fix.

**This table is a summary, not a source.** Each of the five is also stated in full in
its own section below, with the same line numbers, so nothing is lost if you read the
sections and skip this table. It is here for you, because you knew these items in their
earlier and wrong form.

| ID | Correction |
|---|---|
| 6.4 | **Largely closed.** `setDefault` is called after all: `DemographicRegime.pas:180, 181, 182, 198, 212, 284`. Only `aPrioriPPR_result` (`DemographicRegime.pas:219`) still has a nil `default`, and it is created with an empty name and a nil list pointer, so nothing walks it and `setChanged` is never reached for it. Downgrade to a one-line comment |
| 5.2 | **The wrong routine was named.** `writeKin` (`Kinship.pas:3885-3897`) is safe: it assigns `False` at `3890` before the chain. The uninitialised result is in `includeKinInNetwork` (`Kinship.pas:3907-3921`), which has no initialisation and no final `else` |
| N32 | **The wrong variables were named.** `nbChildren_Alive` and `ageOfYoungerInMonths` are initialised at `Nuptiality.pas:1064-1065`, before the `try`. The variables at risk are `aleaSeparation` and `separationRisk`, assigned at `1085-1086` **inside** the `try` (`1066`) whose handler (`1095-1104`) falls through. The use at `1109` and the decision at `1111` then read two uninitialised doubles |
| 3.5 | **`doIt` does return false correctly.** The two real defects are the `F I N I S H E D` banner at `ReadCmdFileUnit.pas:1677-1680`, which prints on the error path as well, and two call sites that discard the return value entirely: `ReadCmdFileUnit.pas:1334` and `Simulxcode.pas:42` |
| 4.11 | **Confirmed and located.** `stopTime (tStart_interm, ...)` at `Kinship.pas:7965` is the only one of the nine calls not wrapped in `if g_GENPARAM.TALKATIVE.value`, while both assignments (`7666`, `7896`) are inside it. With TALKATIVE off it reads an uninitialised `TDateTime` and, since `stopTime` takes `var tStart`, writes to it |

Three findings are **new on 31 August**, in a class that no audit had covered: `R3` read
the demographic routines of `DemographicRegime.pas` but not the `TDemRegInitThread` class
at its top. They are **N42**, **N43** and **N44** in section 2. N42 is the one that
matters: the seed race that item 6.1a fixed in `Kinship.pas` is still present at
`DemographicRegime.pas:97`, and the warning comment that the 6.1a fix added to
`RandomNumbers.pas:312-315` describes precisely what that line does.

---

## 1. Tier B: results are wrong today

These change published numbers. Each needs either a decision from you or a modelling
judgement, which is why none was applied with Tier A. Ordered by the size of the effect
on results.

### 1.1 Fertility

| ID | Where | What is wrong | What the fix is |
|---|---|---|---|
| **N4** (FIXED 29 Aug) | `Fertility.pas`; the only call site is `736`; the sampler is `fecundabilityLevel` at `1092-1107`, read at `FertilityRuntime.pas:870` and multiplied into the age schedule at `873` | **Partly addressed 31 August.** Daniel replaced the hardcoded `gStdDev_fecundability := 0.12` with `:= stdDev`, so the argument is no longer discarded. **This is correct but changes no results**: the one and only caller, `Fertility.pas:736`, passes `normalHeterogeneityFecundability (0.23, 0.12)`, the same value that was hardcoded. The realised coefficient of variation is still 12 per cent, and **Q1 is still open** | Decide Q1. See the note below on why the stdDev argument alone cannot deliver Léridon |
| **N4c** | draw and application `Fertility.pas:1309-1313`; the Léridon decline at `1315-1325`; the redraw `FertilityRuntime.pas:858-865` | **New, 31 August.** With `RESHUFFLED_FECUNDABILITY` on (default FALSE), the multiplier is redrawn after each birth and the loop at `861-864` rewrites `levelFecundabilityAge[age] := multiplier * gFecundability[age]` for **every** age. That silently discards the Léridon pre-sterility decline that `initFecundLife` applied at `1319-1322`, so after her first birth a woman's fecundability no longer falls as she approaches sterility. Permanent sterility itself still holds, because the month loop is bounded by `monthOfEndOfFecundLife` (`FertilityRuntime.pas:874, 883`), but the taper is gone. The redraw should reapply the decline, or better, factor that block into a routine both call. Also note that reshuffling converts between-woman heterogeneity into within-woman noise, which removes the persistent subfecund group and therefore the long right tail of waiting times: it is a different model, not a variant of the same one |
| **N4d** | `fecundabilityLevel`, `Fertility.pas` | **New, 31 August. FIXED.** The inverse-CDF loop was `i := 0; while dummy > gDistrib_fecundability[i+1] do i := i + 1;`, which returns the largest index whose cumulative is **below** `dummy`, one less than the correct inverse-CDF index, for every draw. Two effects: a systematic shortfall of one cell, `1/(mean*K)` = 1.45 per cent, on every multiplier; and a multiplier of **exactly 0** for the lowest cell, 0.19 per cent of women, who are then sterile from the start by a route unrelated to `gDefinitive_sterility`. It also indexed `[i+1]` with no upper guard. Verified by simulating both loops on one random stream over 400,000 draws. **Note this partly cancelled N4b**: `inc` biased the multiplier up 2.17 per cent while this biased it down 1.45 per cent, so the two had to be fixed together or the mean would have moved the wrong way |
| **N4b** (FIXED 29 Aug) | `Fertility.pas`, the `inc` formula | **New, 31 August; root cause found 31 August.** The grid step is
`inc := 2*mean / ((1 + mean*200) * (K/100))`. Multiply out: that equals
`(1/K) * 200*mean / (1 + 200*mean)`, which is `(1/K) * 46/47` at mean 0.23. **It was meant to be
simply `1/K`**: the grid runs fecundability from 0 (at `val = -mean`) to 1 (at index K), and the
sampler at `1105` returns `i/(mean*K)`, which assumes exactly that. The spurious `1 +` in the
denominator makes the grid 46/47 as wide, so the density centre lands at index 70.5 while the
sampler puts multiplier 1 at index 69, and the realised mean multiplier is 47/46 = 1.0217 instead
of 1. **Fix: `inc := 1.0 / kMaxDistribFecundability;`** Verified numerically: the mean multiplier
becomes exactly 1.0000 and the maximum fecundability exactly 1.0000. One line, no decision needed,
independent of Q1 |
| **N2** | `FertilityRuntime.pas:829`, terms built at `796-801` | `LivingBirth := min (month, maxMonthDeathChild + 1)` compares a quantity counted from conception with one counted from birth. A child dying at one month returns the mother to susceptibility six months before that child is born. `ageDeathChild = 0.0` also returns -1 and leaves three fields unassigned | `min (month, kLivingBirth_durationPregnancyInMonths + maxMonthDeathChild + 1)`, subject to **Q2** |
| **N6** | `FertilityRuntime.pas:860-865`; routine at `684-717` | The contraceptive spacing wait is applied twice. `wt_currMonth` is a `var` alias for `currMonth`; `waiting_time_contraception` increments it in place at `714` **and** returns the wait at `717`, and the caller adds the return value again. Line `860` also joins two side-effecting calls with `+`, whose evaluation order Pascal does not define | Choose one mechanism: either the routine advances the month, or it returns the wait. Not both. Split the `+` into two statements whichever way you decide |
| **N8** | `Fertility.pas:1288-1296` | The `else` at `1295-1296` conflates "already sterile at `kMinAgeFert`" with "still fecund at `kMaxAgeFert`" and assigns `kMinAgeFert` to both. About 2.8 per cent of women, drawn from the most fecund tail, get zero exposure and zero children. Applied and then reverted on 26 August because it changes fertility | Keep whichever boundary the loop at `1281-1282` reached. One line. Decide together with N7 |
| **N7** | `FertilityRuntime.pas:2757-2815`; the forcing at `2772`, the clamps at `2781, 2783, 2792`, the propagation at `2798-2800` | The PPR target adjustment sets progression to near-certainty where the simulation reached nobody: `b` is forced to a floor at `2772`, the ratio reaches about 1e4, `a` is clamped to 0.99999, and that factor is propagated to parities 16 to 50 at `2798`. No convergence test across the four passes, no fallback to the best iterate, and `adjustedValues := true` at `2815` regardless | Contrast `findCorrectPropSeparation`, which does keep the best value. Add a convergence test and a best-iterate fallback, and do not mark the values adjusted when they did not converge |
| **N9** | `StablePop.pas:44`, consumer at `FertilityRuntime.pas:2861` | The intrinsic growth rate omits the proportion female at birth. `EulerLotka` at `44` uses `Fertility[x]` from `pGenFert`, which is all births per woman; the only other consumer multiplies by 0.488. At replacement the solver returns about +0.026 rather than 0, and `r` weights the stable age distribution of mothers at `FertilityRuntime.pas:2863` | Multiply `m(x)` by the proportion female inside the Lotka solver, or pass an already-female-only schedule |
| **N10** | `FertilityRuntime.pas:2861` | The net reproduction rate hard-codes `0.488` and ignores `PROP_WOMEN_AT_BIRTH`, while `Mortality.pas:394-397` correctly reads the parameter. Two different sex ratios are in force in one run | Read `dp[propWomenAtBirth]`, as `Mortality.pas:397` does |

**Q1 is closed: Léridon specifies a Gaussian.** The paper was read on 31 August. Section
"Estimating age at permanent sterility" and the preceding paragraph on p. 1550 state that 0.23 is
the mean of `F_max`, the plateau fecundability for ages 20 to 30, and that individual values are
"distributed according to a Gaussian distribution around this mean" with "a SD of 0.12". Figure 1
carries the label `Fmax = N(0.23; 0.12)`. The 0.12 is therefore in fecundability units, so the
target coefficient of variation is 52.2 per cent, and the distribution applies to the plateau,
which is exactly what `gMean_fecundability` and the multiplier scheme represent.

**So the N4 fix is determinate**: correct the density argument to `val / gStdDev_fecundability`,
fix `inc` to `1/kMaxDistribFecundability`, and keep the existing call
`normalHeterogeneityFecundability (0.23, 0.12)`. The beta remains available but is no longer the
recommendation, because the source specifies a normal. The one thing the paper does not address is
what to do with the 2.76 per cent of the Gaussian that falls below zero; the truncation the grid
performs is a reasonable reading, and the realised moments (mean 0.2381, sd 0.1118) should be
documented rather than the nominal ones.

**Other parts of the model confirmed faithful to the same paper.** `periodOfLowFecundability := 12.5`
at `Fertility.pas:1276` matches the paper's "the best estimate for z is 12.5 years"; the adjustment
when the age at sterility is below 33 (`1298-1305`) matches "a continuous process of declining
fecundity from an average age of 33 years"; and the linear taper to zero at the age of sterility
(`1319-1322`) matches Figure 1.

**Why N4 cannot be settled by changing the stdDev argument.** The density at `358` is
standardised as `(val / gMean_fecundability) / gStdDev_fecundability`, so the argument is a
standard deviation **of the multiplier**, not of fecundability. Léridon's N(0.23, 0.12) is a
standard deviation of 0.12 in fecundability units, which on the multiplier scale is
0.12 / 0.23 = 0.5217. Passing that does not give Léridon either, because the grid at `351`
runs `val` only from `-mean` to about `+0.749`, that is from `-1/sd` to `+3.255/sd`
standardised units. At sd = 0.12 the lower bound is -8.3 standard deviations and nothing is
lost. At sd = 0.5217 it is **-1.92 standard deviations**, so the left tail is cut off, and
the left tail is the low-fecundability women, which is the demographically interesting part.
Replicating the code exactly gives:

| stdDev passed | realised mean | realised sd | realised CV | not conceived by 12 cycles |
|---|---|---|---|---|
| no heterogeneity | 1 | 0 | 0 | 4.3 per cent |
| 0.12 (today) | 1.0217 | 0.1226 | 12.0 per cent | **4.4 per cent** |
| 0.5217 (Léridon on the multiplier scale) | 1.0575 | 0.4966 | **47.0** per cent | 10.5 per cent |
| 0.6326 (what it takes to reach Léridon's CV) | 1.1016 | 0.5748 | 52.2 per cent | 11.5 per cent |

The last column uses a base fecundability of 0.23 per cycle and shows the point plainly: at
the current 12 per cent the heterogeneity adds one tenth of a percentage point to
twelve-cycle infertility over the homogeneous case, so it is doing no demographic work.

So a truncated normal on this grid cannot represent the intended distribution without also
changing the grid. **The density argument, settled 31 August.** The formula at `Fertility.pas:358` is a correct
Gaussian; the normalising constant `/(sd * sqrt(2*pi))` is redundant because the loop at `362-363`
divides by `tot` anyway. What makes it a different model from the one the description claims is the
argument: `(val / gMean_fecundability) / gStdDev_fecundability` writes the normal in the
**multiplier**, so `stdDev` is the standard deviation of the multiplier. Writing it in
**fecundability** instead means dropping one division:

```pascal
gDistrib_fecundability [i] := exp ( -0.5 * sqr ( val / gStdDev_fecundability ) );
```

The two are mathematically equivalent, since `(val/mean)/0.5217` and `val/0.12` are the same number:
passing 0.5217 to the present code gives byte-identical results to passing 0.12 to the corrected
form. So this is a choice of convention, not an arithmetic correction, and the reason to prefer the
second is that it makes the argument mean what `NORMAL_HETEROGENEITY_FECUNDABILITY`'s description
says. Use `sqr` rather than `power(x, 2)`, and guard `stdDev <= 0`.

**Either way the normal is truncated.** Fecundability cannot be negative, so the grid cuts the left
tail at `-mean/sd` = -1.92 standard deviations. With the argument corrected and 0.12 passed, the
realised distribution is mean 0.2381, sd 0.1118, CV 47.0 per cent, not 0.23 / 0.12 / 52.2. The
discretisation agrees with the analytic truncated normal (0.2378, 0.1120, 47.1 per cent) to three
decimals, so this is the truncation and not a coding error. A normal on a bounded support cannot
deliver Léridon exactly.

**The cleanest answer to Q1 may be a re-parameterised beta.** Matching a beta to Léridon's
mean 0.23 and standard deviation 0.12 gives **alpha = 2.599, beta = 8.700**. Running that through
the existing `betaHeterogeneityFecundability` machinery reproduces the target exactly: multiplier
mean 1.0000, fecundability mean 0.2300, sd 0.1200, CV 52.2 per cent, and 11.9 per cent not
conceiving within 12 cycles. No truncation, because a beta lives on [0, 1] by construction, and no
change to the sampler. It is two constants at `Fertility.pas:405-406` plus turning
`NORMAL_HETEROGENEITY_FECUNDABILITY` off. The beta **as currently shipped**, alpha 3.4 and beta 9.19
(Hutterite, Majumdar and Sheps 1970), gives mean 0.2701, sd 0.1204, CV 44.6 per cent, which is
already far closer to Léridon than the normal path is.

**A third option is already in the code**: `betaHeterogeneityFecundability`
at `308-338`, the Hutterite beta of Majumdar and Sheps (1970) with alpha 3.4 and beta 9.19,
is set up unconditionally in `initFertilityModel` at `407` and is then overridden at `736`
only when `NORMAL_HETEROGENEITY_FECUNDABILITY` is on (`fixParameter`, `569-571`). A beta is
bounded on [0, 1] by construction, so it needs no truncation. Turning that switch off is a
one-click experiment, and it may be the better answer to Q1 than repairing the normal.

**What is actually distributed is a multiplier, not a fecundability.** `gDistrib_fecundability`
supplies `relativeFecundabilityLevel`, a single constant per woman, and
`Fertility.pas:1312` applies it to the whole age schedule:
`levelFecundabilityAge[age] := multiplier * gFecundability[age]`. Two consequences follow, and
every comparison in this section should be read with them in mind. First, the induced
distribution of fecundability is age-specific: it equals the multiplier distribution scaled by
`gFecundability[age]`, so the figures quoted below (mean 0.23, sd 0.12, and so on) are the
distribution **at the plateau**, ages 21 and over, where `gFecundability` equals
`gMean_fecundability`. At age 18 the same multipliers give a mean of 0.14. Second, because the
scaling is multiplicative and the multiplier is constant across ages, **the coefficient of
variation of fecundability is the same at every age by construction**, while the absolute
standard deviation follows the age curve. That is a modelling assumption, proportional
heterogeneity, and it should be stated in the manual rather than left implicit.

**The multiplier's ceiling, confirmed 31 August.** `fecundabilityLevel` (`Fertility.pas:1091-1107`)
returns `i / (gMean_fecundability * kMaxDistribFecundability)` with `i` in 0..300, so the
multiplier runs from 0 to `1 / gMean_fecundability` = 4.348. `initFecundability` sets the
plateau of `gFecundability` to `gMean_fecundability`, so the product has a maximum of
`(1/mean) * mean = 1` exactly: the ceiling is one conception per cycle, reached by
construction rather than by a clamp, and the mean cancels. The index is really a
probability, `p = i / 300`, and the multiplier is `p / mean`. **The beta path implements
this exactly** (`Fertility.pas:321` builds its density on `p := i / kMaxDistribFecundability`).
The normal path does not: its density sits on a different grid (`val` from `-mean` in steps
of `inc`), centred at index 70.5 while the multiplier reaches 1 at index 69. That mismatch
is N4b, and it is the whole of the 2.2 per cent bias.

Two consequences worth recording. `kNbLunarMonths` is **12**, so the
`gFecundability[i] * 12 / kNbLunarMonths` scaling at `Fertility.pas:305` is a no-op and a
"lunar month" in this code is a calendar month; `lunarToCalendarMonth` is correspondingly
the identity (`Fertility.pas:96`), and the `kNbLunarMonths = 13` branches at
`Nuptiality.pas:910, 930` and `Fertility.pas:92` are dead but each has a correct 12-month
`else`, which is why the compiler reports unreachable code there. And the ceiling holds
only because every hardcoded value of the age ramp (`Fertility.pas:288-298`, peaking at
0.22 for age 20) is at or below the mean. **Setting the mean below 0.22 would let ages 19
and 20 exceed 1**, saturating those women at certain conception with no warning. Guard this
if Q1 leads to a parameterised mean.

### 1.2 Mortality

| ID | Where | What is wrong |
|---|---|---|
| **N13** | `Mortality.pas:300-305` | The infant-mortality age correction is inverted: the two Coale and Demeny branches at `301-304` are the wrong way round, `a` exceeds 1 for `q0 >= 0.183`, and the rescaling at `305` touches only the lower endpoint, so the mean moves from 0.536 to 0.576 while `a` sweeps 0.34 to 1.34. The `max (1, ...)` at `305` also means no infant can die in the neonatal period |
| **N14** | `Mortality.pas:333-334`, interpolation at `349` | An e0 outside the tabulated range (`lifeTable_e0_min = 20` at `:30`) is warned about but not clamped, and `writeAndWait` does not halt. At e0 = 15 the interpolated `lx` is non-monotone with a minimum of -3.3e-7; at e0 = 10, -0.0091. The 20 to 112 bounds exist only in the GUI, so a configuration file or a cohort interpolation reaches the routine unchecked |

### 1.3 Inheritance

Answer **Q3** and **Q4** before touching any of these. They are one coherent question
about how far the module follows Spanish succession.

| ID | Where | What is wrong |
|---|---|---|
| **N22** | `inheritance.pas:1467-1516`, the recursion at `1490-1498`, entry at `1590` | A nearer ascendant does not exclude a remoter one. The test at `1490` is on one ascendant's own pair of parents, so when neither is an heir the paternal branch (`1496`) and the maternal branch (`1498`) recurse independently. Surviving paternal grandparents therefore share with maternal great-grandparents. This contradicts the file's own header comment and Spanish CC art. 921. `AscendantHeirs_2` (`1575`) also hardcodes the degree |
| **N24** | `inheritance.pas:944, 946, 962, 967, 1004, 1007, 1084, 1088` | `commonAncestor` (`752`) is computed and then discarded at four of five call sites, and the code collects the children of both of ego's parents unconditionally. A maternal half-sibling with no blood relation to the dead niece is given an equal share |
| **N25** | `inheritance.pas:2097-2099`; parameter declared at `44` | `lookForDecedents_Spain` has an empty body. `inher_Spain` and `inher_Other` are declared, parameterised, saved, read and bound to a control, and referenced nowhere: both algorithms run unconditionally |
| **N26** | `inheritance.pas:2134-2186` | `checkHeirs` reports agreement in exactly the case where the algorithms disagree. `result := 1` at `2138`; when algorithm 1 concludes `th_none` (`2146`) and algorithm 2 found heirs, the case arm is empty and the result stays good. The final `else` at `2180-2184` is unreachable, since `2140`, `2169` and `2173` already cover every case. The list comparison at `2175-2179` is also order-sensitive |

### 1.4 Education

Four separate decisions, not one fix. **Q5** governs N18.

| ID | Where | What is wrong |
|---|---|---|
| **N17** | `EducationalLevel.pas:264, 266` | The partner correlation matrix is indexed with the wrong sex. The second index is `pRelative^.gender`, the person being assigned, where it should be the partner's. The correlation stays positive, so it passes a smoke test |
| **N19** | writer `DemographicRegime.pas:733-746`, header `1765-1778` | The mode-to-table mapping is shifted by one: `eduStochastic` dumps `eduEgo`, `eduCohort` dumps `eduEgoPartner`, `eduIntraFamily` dumps `eduEgoPartnerChildren`. The header writer and the value writer agree with each other, so the file is self-describing and reads back correctly. What is wrong is that the mode in force dumps a different table from the one it uses. **Not applied**: correcting it changes the column set of the cohort file for all three modes, which is a file format decision |
| **N20** | `EducationalLevel.pas:182-193` | The stochastic mode ignores all six `EDU_*` parameters and hardcodes `1/3` at `187` and `2/3` at `189`. Combined with N19 the user reasonably believes the dumped values were used |
| **N18** | `EducationalLevel.pas:272-291` | Intra-family education correlates four kin types out of twenty-seven. `kt_sibling` at `282-283` goes to the unconditional cohort draw, as does everything outside ego, partner, child and grandchild |

### 1.5 Cohort parameter lists

| ID | Where | What is wrong |
|---|---|---|
| **N11** | `Declarations.pas:1387-1393`, the nil at `1393` | Every cohort after the first loses its parameter list. `GenericName.copyMeTo` sets `toObj.next := nil`, and `DemographicRegimeSettings_copyState` copies `yearOfBirth` first, which **is** the head of the list. `changed` is never recomputed for those cohorts (the walk is at `DemographicRegime.pas:317`), so a GUI edit to cohort 2 is lost with no prompt |

---

## 2. Tier C: threading, object lifetime and the error path

Each of these needs a design decision and a test. A wrong fix here is worse than the bug,
so do them after Tier B and one at a time.

| ID | Where | What is wrong |
|---|---|---|
| **2.3** | `TSimulEgoTree.Simulate`, `Kinship.pas:6714-6729`; consumer `TSimulEgoTree.Execute`, `6731` onward, the read at `6739` | The go-flag is published before the state the worker will read. `myExecuteIt := true` at `6724`, then `FAFinished := false` at `6725`, then `myNumTreesStored := numEgos` at `6726`. The worker's `while not terminated` at `6737` tests `myExecuteIt` at `6739`. There is no event, no lock and no barrier. `Defines.pas` defines `ARM` for CPUAARCH64, and Apple Silicon is weakly ordered, so this is not theoretical on your own machine |
| **2.4** | worker `Kinship.pas:2912`; `7694`, `7695`; dispatcher `7817`; file class `Utilities.pas:279-280` | Every wait is a hot spin with no yield: `repeat until ...` with an empty body. On a machine with fewer cores than threads this starves the thread being waited for |
| **2.5** | main file failure `Kinship.pas:7493` with `exit` at `7497`; link file failure `7503` with `exit` at `7507`; caller's bare `exit` at `7762-7763` | The link file failing to open leaves the main file open, and the caller's bare `exit` skips `writeTables`, `DestroyArrayChildren` and all thread cleanup, leaving the workers spinning |
| **N36** | `Kinship.pas:2911-2914` | `.Destroy` at `2913` runs immediately after the spin on `AFinished` at `2912`, with no `WaitFor` and no `inherited Destroy`, so the RTL may still be touching the instance after it is freed |
| **N37** | `Kinship.pas:3115` and `3120` | `TPersonMemoryManager.Create()` with no argument allocates a 100 x 100 x 10000 array of references, about 800 MB, and two are created unconditionally |
| **N38** | `Kinship.pas:2898-2910` | `nActiveThreads` is not a count of running threads: it is decremented at `2902` for every finished thread on every pass, and incremented at `2906` before `.start` at `2907`, which is called repeatedly on threads already running. The `until (nActiveThreads <= 0)` at `2910` therefore exits on an accounting artefact |
| **N34** | `Parenthood.pas:77-84`, call at `190` | `distNbChildren` is incremented with a plain `Inc` at `79, 82, 84` from every worker into one shared per-cohort record reached through `getCohort_p(cohort)^` at `190`. In a stable population every year clamps to the same cohort, so all threads collide on the same counters |
| **N35** | `Kinship.pas:2284` | `addGroomsInfo` uses `exit` where it needs `continue`: a woman whose first union falls outside the groom cohort range loses **all** her unions, including in-range later ones |
| **N49** | `FertilityRuntime.pas:515`, callers at `546` and `817` | **New, 31 August, found by the compiler.** `addChild` declares `out ageChildren: TabCompFertAge` but accumulates into it: `ageChildren[age, 0] := ageChildren[age, 0] + number`. `out` means the incoming value is not passed in. `TabCompFertAge` is a plain `array[FecundAges, DistribChildrenCalc] of longint`, and FPC does not reset non-managed types on `out`, so the accumulation works today by an implementation detail rather than by the language rule. FPC warns: "Variable ageChildren does not seem to be initialized". Change `out` to `var`. Low priority, but free |
| **N48** | 45 sites: `Fertility.pas` 866, 885, 910, 963, 1013, 1032, 1074; `FertilityRuntime.pas` 499, 678, 900, 934, 991, 1008, 1045, 1060, 1077, 1094, 1117, 1140, 1270; `Kinship.pas` 925, 4242, 4253, 5697, 5706, 5721, 5732, 5741, 7588, 7785, 7794, 7930; `Nuptiality.pas` 285, 1102, 1453, 1475, 1501; `inheritance.pas` 471, 492, 539, 630, 722, 808, 886, 908, 924 | **New, 31 August. Every debugger trap is a silent no-op on Apple Silicon.** The idiom is `if gRunFromIDE then {$IFNDEF ARM} asm int 3 end; {$ELSE} assert (true, E.Message) {$ENDIF}`. `Assert` raises only when its condition is **false**, so `assert (true)` never fires. `Defines.pas` defines `ARM` for `CPUAARCH64`, and Daniel's machine is arm64, so on his Mac all 45 traps take the dead branch. Assertions themselves are compiled in: `kinfert.lpi` passes `-Sa`, along with `-Ci -Co -CO -Cr`. The fix is `assert (false, ...)`, or better `assert (false, 'trap at <site>: ' + E.Message)` so the message says where. **This is not cosmetic**: several of these sit in exception handlers that swallow the exception and fall through, so the trap was the only thing that would have told him. `Nuptiality.pas:1095-1104` is exactly that case, and it is the handler behind N32 |
| **N42** | `DemographicRegime.pas:97`, in `TDemRegInitThread.Execute` | **New, 31 August. The seed race that 6.1a fixed survives here.** The worker calls `myRandomGenerator.initRandomized()` from inside its own `Execute`, which is exactly what `RandomNumbers.pas:312-315` warns against in a comment added by that very fix: `initRandomized` uses the RTL `random()`, which reads and writes the global `RandSeed` with no lock. The threads are started concurrently at `1108`, up to `nThreadsUsed` at a time, so two cohorts can be handed the same seed and get identical fertility schedules. The constructor at `84` already seeds the generator on the main thread through `TRandomNumberGenerator.Create (false)`, so **line `97` can simply be deleted**; if a distinct stream per thread is wanted, replace it with `initWithSeed (nextThreadSeed)` **in the constructor at `84`**, never in `Execute`. Gated by `MULTITHREADING`, `MULTITHREADING_INIT` and `not StablePopulation` at `1080` |
| **N43** | `DemographicRegime.pas:1091-1111`, the assignment at `1094` | **New, 31 August.** `allThreadsDead := false` sits inside the inner `for` and is re-executed on every element, so the flag can never survive a pass and the `allThreadsDead` half of the exit test at `1111` is dead. Only `nActiveThreads <= 0` can end the loop. This is the same shape as the fallback cleanup loop deleted as item 2.6, with the sense reversed: `1092` sets it true once per outer pass and `1094` immediately clears it. Move `1094` out of the inner loop or delete the flag |
| **N44** | `DemographicRegime.pas:87-90` | **New, 31 August.** `TDemRegInitThread.Destroy` frees `myRandomGenerator` and never calls `inherited Destroy`, so the `TThread` part is never torn down. Same class as N36. The objects are freed at `1116` after a proper `WaitFor` at `1115`, so the lifetime is safer here than in N36; the missing `inherited` is still a leak per thread |
| **N41** | allocation `Kinship.pas:3215-3220`, release `3310-3315` | Bootstrap replicates reuse stale arrays. `gMen_Women` and the five `gState*` arrays are freed once per session in `disposeMotherhood_DemReg` while `initMotherhood` runs once per replicate, and `SetLength` to the same dimensions does not zero. **Disappears with B1**, and is B1's acceptance test rather than a separate fix |
| **5.6** | `Kinship.pas:7700` | The deliberately commented-out `// aThreadObject.Destroy;` would be a double free if uncommented. Add the comment that says so |

---

## 3. Settings file round trip

| ID | Where | State |
|---|---|---|
| **3.b** | used `Kinship.pas:7671` and `7962`; constructed `Init.pas:517` with TRUE, defaulted `Init.pas:417` to FALSE; enum member `Declarations.pas:715` | `USE_ARRAY_CHILDREN` is never written to the configuration file and never read from it, and its constructed value contradicts its default. You believe it is deprecated. Decide: remove it, or make it saveable |
| **3.d** | writers commented out at `ReadCmdFileUnit.pas:848` (`DUMP`) and `876` (`STABLE_POPULATION`); readers live at `1216` and `1260-1261` | `DUMP` and `DUMPALL` are runtime choices, so not saving them is deliberate: either delete the dead reader branch or add a comment saying why it is there. `STABLE_POPULATION` you believe deprecated, since stability follows from having a single demographic regime |
| **3.1** | `ReadCmdFileUnit.pas:1008-1035` | `DUMPALL` writes a detailed file with no tables in it |
| ~~**3.3**~~ | | **CLOSED 31 August**: both `CHECK_DATASTRUCT` reader branches are gone with the parameter itself |
| ~~**N47**~~ | | **CLOSED 31 August**: `CHECK_DATASTRUCT` removed entirely, so nothing is saved, read and then clobbered |
| **3.4** | name listed `lazkinoutputfields.pas:84`; enum `Declarations.pas:125`; in the default set `Init.pas:469`; written `Kinship.pas:3836` with header at `7393` | `fn_yDeathFloat` has no checkbox. `lazkinoutputfields.lfm` has 21 `TCheckBox` objects for 22 enum members, confirmed by count. The column cannot be switched off from the GUI |
| **3.5** | banner `ReadCmdFileUnit.pas:1677-1680`; discarded results at `ReadCmdFileUnit.pas:1334` and `Simulxcode.pas:42`; error label `1669`, `goto` at `1638` | `doIt` itself returns false correctly (`result := false` at `1521`, `result := true` only at `1667`, skipped by the `goto error`). The banner prints on the failure path all the same, and two of the four call sites ignore the result. `LazMain.pas:805, 813, 819` do check it |
| **6.4** | `setChanged` `Declarations.pas:1584-1592`; `setDefault` `1635-1638`; callers `DemographicRegime.pas:180, 181, 182, 198, 212, 284`; the walk at `DemographicRegime.pas:317` | **Largely closed.** `setDefault` is called after all, at the six sites listed opposite, so the original report that it was never called anywhere is wrong. The one array left with a nil `default` is `aPrioriPPR_result`, created at `DemographicRegime.pas:219` with an empty name and a nil list pointer, so it never joins the walked list. A comment at `1588` saying that `setChanged` requires a prior `setDefault` would close it |

---

## 4. Output hygiene and dead code

| ID | Where | What |
|---|---|---|
| **1.3 / B4** | writer `Kinship.pas:3880`; dispatch `3895-3896`; header `7430`, called at `7526` | GEDCOM is selectable and writes a header and no rows. Until it is implemented, either remove it from the combo or make the format substitution reach the caller |
| **5.2** | `includeKinInNetwork`, `Kinship.pas:3907-3921` | No initialisation and no final `else`. A `fileFormat` that is neither DemoCare nor EgoGenealogy nor GEDCOM leaves `result` undefined. Add `result := false` after the `begin` at `3910`. `writeKin` at `3885-3897` is already safe |
| **4.2** | `Kinship.pas:3673-3688` | Link file: `M` rows in both directions (`3679`), `D` rows only for `kt_child` and `kt_grandChild` that are not by-union (`3683-3686`). For the DemoCare kin set the descent links are complete |
| **4.6** | header `Kinship.pas:7406, 7409, 7410`, duplicate at `7414`; row values `3850, 3853, 3864, 3867` | `heirs` is emitted twice as a header name when the debug block is on, and the user-facing `heirs`, `decedents` and `share inheritances` columns are written from the second-algorithm variables (`str_shareHeirs_2`, `str_shareDecs_2`) |
| **4.7** | `Kinship.pas:3731-3752` | Empty-value sentinels disagree: `''` at `3731-3734`, then `'0'` for `idSpouses` at `3749`, `'-1'` for `str_AgeUnion` at `3750` and `str_AgeEndUnion` at `3751`, `''` again for `str_causeEnd` at `3752`, and `'-1'` for `str_share` at `3778` against `''` for the second-algorithm heir columns at `3803` and `3820` |
| **4.8** | check `Kinship.pas:3585`; the earlier report is inside `CalcChildren`, `3542-3556` | The ego children check is redundant: `CalcChildren` already reports the same condition |
| **4.11** | read `Kinship.pas:7965`; assignments `7666` and `7896` | `stopTime (tStart_interm, ...)` at `7965` is the only one of the nine such calls in the routine not wrapped in `if g_GENPARAM.TALKATIVE.value`, while both assignments to the variable are inside that guard. With TALKATIVE off it therefore reads an uninitialised `TDateTime`, and since `stopTime` takes `var tStart` it writes to it as well. Either wrap `7965` like the other eight, or assign `tStart_interm` unconditionally |
| **Dead** | `writeOneArrayOfDouble`, `Utilities.pas` | Declared and implemented, no callers anywhere in the tree. It is the single-array file dump that `dumpArray` now supersedes. Remove it, or keep it and delete `dumpArray`'s double overload, but not both |
| **N39** | `testThread.pas` | `mothersInfoList.pas` is deleted. `testThread.pas` is the second candidate: it declares `unit testThreads` while the file is named `testThread.pas`, and nothing references it. Left for you to decide |

---

## 5. Unguarded arithmetic and bounds

None of these is a results bug on its own. Each is a crash or a silent corruption waiting
for an unusual input. Grouped by unit, with the current line numbers.

**`FertilityRuntime.pas`**

- `2861-2871`: division by zero when a cohort produces no births (`sum` is zero at `2866` and `2868`, and `1.0 / sum` at `2871`), then the `while` at `2876-2880` has no lower bound and walks below `kMinAgeFert`.
- `2556-2557` and `2561`: two unguarded divisions in the separation Newton step. The denominator at `2557` is zero whenever two consecutive iterations give the same simulated proportion, which is ordinary for a coarse ratio of counts.
- `2651-2655`: on the warm-start branch the `Inc (nIterSeparation)` at `2655` has no counterpart in the no-initial-value branch at `2658-2661`, so `history[., 1]` is never written while the loop at `2556-2557` reads `nIterSeparation-1`.
- `2630` and `2648`: `freqSeparation_result` read from an uninitialised record and then printed as the `SEP_RESULT` column.

**`Fertility.pas`** (note: this file has CR-only line endings, see section 8)

- `198-235`: the Erlang waiting-time distribution takes `power (i, k - 1)` at `222` with `i = 0`, is never normalised, and sets `k` independently of `lambda`, so the repartnering calls at `Nuptiality.pas:857-858`, which pass `lambda = 0.3`, request a mean that is delivered 3.33 times too large. The other five call sites are `DemographicRegime.pas:392, 396, 498, 504`.

**`Nuptiality.pas`**

- **N29**, `594`, `598`, `616`: `scaleFactor := (mean - ageMin) / 11.37` can be zero or negative in `initStandardNuptiality`, giving a division by zero inside `calcNuptScaleFactor` or negative densities that are then renormalised.
- **N30**, `1231-1238`: `std_Campbell_Wood_1988` takes `sqrt (107.0 * ln (mean) - 292.0)` at `1236-1237`, which is the square root of a negative number for any mean below 15.32, and 15.32 is inside the accepted range.
- **N31**, `1525-1546`: `ageWomenEndUnion` never tests `kNotDefined` on `ages[le_death, man]`, so `ageAtDeathPartner` at `1534` can be negative and the branch at `1535-1537` returns a negative age labelled `widow`.
- **N32**, `1066-1111`: the `try` at `1066` whose handler at `1095-1104` falls through, leaving `aleaSeparation` and `separationRisk` (assigned at `1085-1086`) undefined at the use on `1109` and the decision on `1111`. The most likely fault is the index `d.monthly_risk_separation [durationUnion]` at `1086`.
- `174-190` (`setAgeUnion`) and five siblings, `setYearUnion` at `192`, `setAgeEndUnion` at `235`, `setYearEndUnion` at `253`, `setPartner` at `309` and `setCauseEndUnion` at `352`: the union setters fabricate a phantom union. The `newUnionInfo (pRelative)` calls are at `183`, `198`, `244`, `259`, `318` and `361`. `getUnionInfoByIndex` (`Declarations.pas:1243`) returns nil for an out-of-range index, and the setters read nil as "append" (`182-184`), incrementing the union count and writing to the wrong union. `Kinship.pas:477` passes `getIndUnion`, which returns `kNotDefined` exactly when the reciprocal link is missing, that is in the case the consistency check exists to detect. This is **N28**.
- `264-276`: the `getPartner` guard uses the literal `20` while `kMaxNbUnion` is 30, so unions 21 to 30 are rejected with an error message. Noted in the source when N27 was fixed, not changed.

**`StringOfLib.pas`**

- **N45**, `99-108`, `doubleToMinStringHelper`. The trailing-zero strip is
  `while (Result[length(Result)] = '0') do Result := Copy (Result, 1, length(Result)-1);`
  with no guard that the string still has a decimal point, and no guard against emptying it.
  With the shipped `FLOATING_POINT_DIGITS` of 3 it behaves correctly. At 0 it is destructive,
  verified by running FPC 3.2.2: **100 is written as "1"** and 20 as "2", and 0.23 and 0.0
  both raise `ERangeError` under the `{$rangeChecks on}` of `Defines.pas`. Reachable because
  `LongintName.readValue` (`Declarations.pas`) does no range check at all, so a hand-written
  or hand-edited configuration file can set the value to 0 or a negative number; the GUI
  clamps it to 1 to 10 at `LazOutput.pas:356`, which is why this has never been seen. Guard
  the loop with a test that `Pos ('.', Result) > 0`, and consider range-checking
  `LongintName.readValue` in general, since every longint parameter shares this exposure

**`Nuptiality.pas`, debug-only code**

- **N46**, `1024`. `writeArrayOfDouble (f, tab, d.monthly_risk_separation, true)` passes four
  arguments to a procedure declared with three (`Utilities.pas:141`). It sits inside
  `{$IFDEF DEBUG_SEPARATION}`, which is defined nowhere, so the tree still builds. Turning
  that define on to investigate a separation problem, which is exactly when someone would,
  breaks the build instead

**`DemographicRegime.pas`**

- **Bounds**, `1500-1545`: parity and interval indices taken from the cohort file header with no bounds check. The `dPos (posValues [n].posTable, k)` expressions at `1535`, `1539` and `1543` are cast straight to `EduLevels` and `Sex`.

**`Kinship.pas`, `initMotherhood`**

- Five index computations without bounds: `addChildrenBACKFORInfo` (`2402`) indexing an age at union on a fertility-age axis; `addBridesInfo` (`2295`) and `addGroomsInfo` (`2271`) with no high clamp, the `max (0, ...)` at `2282` guarding only the low end; `addUnionsInfo` (`2324`) off by one; `lookingForABrideByAgeAndCohort` (`2242`) walking off both ends with no empty-range escape; `getAgeUnionSelected` (`2198`) reaching `Unions[-1]`.

---

## 6. Decisions only you can make

Nothing below is a coding question. Each answer determines which fix is correct, and
several of them change what the manual has to say.

| ID | Question | Blocks |
|---|---|---|
| ~~**Q1**~~ | **ANSWERED 31 August from the source.** Léridon (2004), *Human Reproduction* 19(7):1548-1553, p. 1550: "The 0.23 value was taken as a mean value (for the more fertile part of the reproductive period: F_max) and the individual values were presumed to be distributed according to a **Gaussian** distribution around this mean. According to various estimates of this distribution we took a **SD of 0.12**." Figure 1 is labelled `Fmax = N(0.23; 0.12)`. So: a normal, mean 0.23, standard deviation **0.12 in fecundability units**, applied to F_max, the plateau. The description string in the code was right all along and the implementation was wrong. **This makes N4 a determinate fix, not a decision**: correct the density argument and keep passing 0.12. Do not switch to the beta | closes N4 |
| **Q2** | N2: confirm that `LivingBirth` is meant to be counted from conception, so the correction is to add the gestation to the death term rather than to subtract it from `month` | N2, V17, M6 |
| **Q3** | N22 to N26: how far the inheritance module is meant to follow Spanish succession. Specifically: does a nearer ascendant exclude a remoter one; are posthumous children heirs; what happens when no heir is found; is usufruct modelled; and is grand-nieces competing per capita with grand-aunts at degree 4 deliberate | N22, N24, N26 |
| **Q4** | N25: should `inher_Spain` and `inher_Other` select between rule sets, or is the parameter a leftover to remove | N25 |
| **Q5** | N18: is education meant to correlate between siblings? At present it does not | N18 |
| **Q6** | Can the repartnering model emit a union age above 74? This decides whether several index bounds in section 5 are reachable | the `initMotherhood` bounds |
| **Q7** | Do `union_women_men` rows always reach 1.0? This bounds an unguarded sampling loop | `lookingForABrideByAgeAndCohort` |
| **D3** | Should the key column be suppressed in a kinship-only stepped run? `writeKeys` has one call site, `SpecialRuns.pas:238`, inside `FERTILITY_loops`, so with FERTILITY off `RP.key` is never incremented and the column is the constant 0 on every row | cosmetic, but it reaches the file format |
| **N19** | Correcting the education dump changes the column set of the cohort file for all three modes. Do you want that before the release, or after? | N19, M3 |
| **P8** | What to say about results already published with the versions that carried N1, N3 and N4 | the release notes |

### Changes you have announced

| ID | What | State |
|---|---|---|
| **B1** | Remove bootstrapping. Touches `gBootstrap_nRuns`, `OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES`, `RP.indBootstrap`, the loop at `ReadCmdFileUnit.pas:1613`, and the `bootstrap_ind` parameter threaded through `run_all` / `simulateKinship` / `individualKin_*`. Also resolves N41 | Confirmed, not started |
| **B2** (**D4**) | Keep `RP.wkey` for fertility. `openFileKeys` (`Utilities.pas:756`) computes `RP.wkey := needsKeys and (stepsKeys or RP.wKeyBootstrap)`, and `stepsKeys` (`776`) is true whenever any of the seven step counts exceeds one. So a parameter sweep needs keys with no bootstrapping at all: removing bootstrapping must not remove `RP.wkey`, `openFileKeys`, the KEYS file or the key column | Confirmed |
| **B3** | Retire the bootstrap-only append fix when B1 lands: `sharedBootstrapFile` and `openMode` in `individualKin_openFile` (`Kinship.pas:7440`), and possibly the `mode` parameter added to `openFileOut` | Waiting on B1 |
| **B4** | GEDCOM later. The one real bug in that area is fixed: `header_GEDCOM` no longer writes to `gOutFileIndivKin_link`, a file only opened for DemoCare. If the GEDCOM writer ever needs a second file it must be opened in `individualKin_openFile` first | Waiting |

---

## 7. Verification

**V1 gates everything else.** Items V2 to V13 test round 1 to round 3 work that has never
been run; V14 to V20 test the Tier A fixes you have just approved.

| ID | What | Tests |
|---|---|---|
| **V1** | **Build in Lazarus on your machine.** The container build covers the engine but not `LazGraph`, `LazMain` or `LazUtiles`, and not the `.lfm` binding | everything |
| **V2** | One ego-genealogy run and one DemoCare run: check the column count against the header, with and without the extended DemoCare set | round 1, round 3 |
| **V3** | `partnershipStatus` shows `firstUnion` and `secondUnions`, not only `separated` and `widow`; `nChildren` is non-zero for relatives who have children | D1, D2, 1.6 |
| **V4** | Write a DemoCare file and read it back with `readDemocareFile`, both layouts. It must not be refused as "Not a Democare Kinship file"; kin types must come back as written (**D5b**); no person may appear twice in another's union list (**D5a**, the duplicate `addLastPartner`) | 1.5, D5a, D5b |
| **V5** | No row in the DemoCare file has a negative `tickOut`, and no link row names an id absent from the main file | D7 |
| **V6** | Only grandparents selected: the fathers and grandfathers appear | 1.11 |
| **V7** | The `kt_total` row appears and equals the sum of the rows above it | 1.13 |
| **V8** | With multithreading off, the same configuration twice, compared byte for byte. Check that the Config dialog leaves "Same Random Sequence" enabled when only `MULTITHREADING_SIMKIN` is off | 1.9, D6 |
| **V9** | A multi-cohort run: every cohort present in the file, family and individual numbers continuous and never repeated, and the closing message reporting the totals for the whole file | W2 |
| **V10** | A multithreaded run: no two genealogies identical, which was possible while the threads could draw the same seed | 6.1a |
| **V11** | A run with multithreading on and off produces the same number of families | 1.15, N40 |
| **V12** | `MULTITHREADING_SIMKIN` survives a save and a reload | 3.a |
| **V13** | The Outputs dialog no longer shows the "Use batches" checkbox and nothing references it | W1 |
| **V14** | **The decisive test for N1.** A two-step separation sweep: the `SEP` column of the two steps must differ, and the second must not be zero. Before the fix both were zero. Do this early: it is also the cheapest way to find out which past stepped runs need repeating | N1 |
| **V14b** | A three-step sweep of the mean age at union from Low to High: the three simulated means must be Low, the midpoint, and High. Before the fix the last step never ran and the first used a stale index | N1 |
| **V14c** | A three-step amenorrhea sweep: the three values of `amenorrhea_alpha` must be evenly spaced from the original value. Before the fix the third was alpha + 3.6 rather than alpha + 2.4 | N1 |
| **V14d** | A run with every `NSTEP_*` at 1, compared against the same run before the fix. It must be **identical**: N1 lives entirely inside the `> 1` branches, and this confirms that ordinary single-parameterisation runs were never affected | N1 |
| **V15** | The distribution of age at end of union must not pile up at the oldest ages, and must be consistent with the age at the **first** separation drawn | N3 |
| **V16b** | **New, for N4, from Léridon Table I.** The paper's own model gives, for conception ending in a live birth within 12 months: **75.4 per cent at age 30, 66.0 at 35, 44.3 at 40**; within 4 years, 90.7, 83.9, 63.7. Median age at onset of sterility 44.7 years, against 50.5 for menopause and 41.2 for the last birth. Run the equivalent configuration and compare. This is a far better test than any waiting-time calculation done by hand, because it exercises fecundability, miscarriage and sterility together | N4, N8, N13 |
| **V16** | The realised distribution of the fecundability multiplier, dumped from `X_INDIVIDUAL_FERTILITY_INFO.CSV` (the column written at `FertilityRuntime.pas:1597`): its **mean must be 1.0** once N4b is fixed, and its coefficient of variation must match whichever parameterisation you choose in Q1. Today it is mean 1.0217, CV 12.0 per cent | N4, N4b |
| **V17** | Mean birth interval following an infant death compared with the interval following a surviving child. The difference should be of the order of the shortening of breastfeeding, not of nine months | N2, after the fix |
| **V18** | `checkSumShareHeirs` must report shares summing to 1 for a decedent with two, three and four surviving grandparents | N21 |
| **V19** | Hand-write a configuration file with lowercase names and trailing spaces: it must be accepted (**3.2**), and the file the program writes must carry a `FILENAME` line (**3.e**) | 3.2, 3.e |
| **V20** | A cohort file with an explicit `NWOMEN` column: each cohort must use its own value, not `NEGO`. Also a cohort file with a blank line in it, which must now be accepted | N12, A1 |
| **V21** | **New.** A cohort in which no woman is simulated must not raise a division by zero in `writeInfoParents` | A2 |
| **V23** | **New, for N42.** With `MULTITHREADING` and `MULTITHREADING_INIT` on and a non-stable population, run several cohorts whose parameters are read from a configuration file and compare their fertility schedules. No two cohorts should have identical draws. This is the cohort-level equivalent of V10 | N42 |
| **V22** | **New.** A run with an out-of-range life expectancy, and one with a bad education status string, must not corrupt the life table or the education index. These are the two silent-corruption fixes | N15, N16 |

---

## 8. Documentation

`docs/KinFert-Manual.md` is a first draft of about 1080 lines: main-window workflow, full
GUI reference with every parameter identifier, demographic model, kin taxonomy, file
formats, tutorial, appendices.

| ID | What |
|---|---|
| **M1** | Answer the ten questions in Appendix F of the manual: conception model, repartnering hazard, the e0 to survival mapping, B/M/A education, the default backward variant, country inheritance rules, the exact file grammars, drop-down values, and a worked regression example |
| **M2** | Update the manual for the work of this session: per-format kin sets, the DemoCare field dialog, `DEMOCARE_LARGE_FIELDS`, the new `partnershipStatus` values including `dead` and `secondUnions`, relatives dead before the reference age now excluded, the `kt_total` row, and the removal of the BATCH option |
| **M3** | Document the DemoCare format and its link file, now that D5a and D5b are fixed |
| **M4** | Release notes: `DEMOCARE_LARGE_FIELDS` replaces the `DUMPALL` binding; old DemoCare configurations carry a wide `OUTPUT_KINTYPES` that is now honoured; the DemoCare file no longer contains relatives dead before the reference age; the BATCH option is gone; `MULTITHREADING_SIMKIN` is now saved |
| **M5** | Fold the audits' cleared findings into developer notes, so the reasoning survives |
| **M6** | Whatever is decided on **Q1** and **Q2** changes the model description, not only the code. The manual's account of fecundability heterogeneity and of the effect of infant death on the birth interval must match what the code does after the fix |
| **M7** | **New.** Document the parameter sweep semantics: which parameters step, that steps and cohort sequences are mutually exclusive (`openFileKeys` at `Utilities.pas:779-790` silently resets all seven step counts to 1 with a message), and what the KEYS file decodes |

---

## 9. Publication on GitHub

`README.md` and `LICENSE` (MIT) are committed, and `.gitignore` already excludes the
binaries, `lib/`, `backup/`, `copy.zip`, `*.lps` and the two machine-specific `.cfg` files.

| ID | What | State |
|---|---|---|
| **P1** | README | Done, `22ed060`. Review once the version numbers of P4 are decided |
| **P2** | LICENSE | Done, MIT, `22ed060` |
| **P3** | `KinFert ConfigDir.cfg.example` and `KinFert OutputDir.cfg.example` templates. The real files are gitignored, so a fresh clone has nothing to start from | Open |
| **P4** | Pin the Lazarus and FPC versions. `kinfert.lpi` carries `Version Value="12"`, so state the Lazarus version it was saved with and the FPC version it is known to build under. FPC 3.2.2 is verified for the engine | Open |
| **P5** | Decide the binaries and how they are built. `KinFert`, `KinFert.exe` and `KinFert.app` exist in the folder and are gitignored, which is right; they should go to a Release, built from a tagged commit | Open |
| **P6** | A minimal regression test with a known output: one small configuration file, one expected output file, and a note on how to compare. V14d is a good candidate for the fixed baseline | Open |
| **P7** | Decide whether `CLAUDE.md`, `AGENTS.md` and the audit documents ship with the source | Open |
| **P8** | Decide what to say about results produced with the versions that carried N1, N3 and N4 | Open, see section 6 |
| **P9** | **DONE 31 August**, by Daniel: `Fertility.pas` converted from CR-only to LF. It was the only such file in the tree. **One loose end**: the conversion was made in the same working-tree state as the fecundability fixes, so `git diff` shows 1753 additions and 1 deletion and the content changes are invisible inside it. See the note below on splitting the commit. **Also new**: `LazConfig.pas` uses CRLF (645 CR, 645 LF) while every other unit is now LF. That is not a problem for git the way CR-only was, but a `.gitattributes` with `*.pas text eol=lf` would stop editors on two platforms producing spurious whole-file diffs |
| **P10** | **New.** Decide whether `testThread.pas` ships. It declares `unit testThreads` while the file is named `testThread.pas`, and nothing references it | Open |

---

## 10. Code review coverage

| ID | Unit | State |
|---|---|---|
| R1 | `RandomNumbers.pas` | Read, 6.1a fixed |
| R2 | `Fertility.pas`, `FertilityRuntime.pas` | Read. N2 to N8 and six arithmetic items |
| R3 | `DemographicRegime.pas`, `StablePop.pas` | Read. N9, N11, N12, N19 and two arithmetic items |
| R4 | `Nuptiality.pas`, `Parenthood.pas` | Read. N27 to N33 |
| R5 | `Mortality.pas`, `EducationalLevel.pas`, `inheritance.pas` | Read. N13 to N18, N21 to N26 |
| R6 | `Memory.pas` | Closed. `DebugMemory` is never defined, so the standard memory manager is used and the unlocked `ptrList` is unreachable |
| R7 | `initMotherhood` threading | Read. N34 to N38, N41 |
| R8 | `StringOfLib.pas` | Closed |
| R9 | `SpecialRuns.pas` | Read. N1 |
| R10 | `mothersInfoList.pas` | Deleted |
| **R11** | `LazMain.pas`, `LazConfig.pas`, `LazLowlevel.pas`, `LazGraph.pas`, `LazUtiles.pas`, `docform.pas` | **Not read.** Low risk for results, but this is what a new user sees first, and it is the part V1 will exercise |
| **R12** | `ComponentHelper.pas`, `NumCPULib.pas`, `Profiler.pas`, `TimeProfile.pas`, `Simulxcode.pas`, `StringResources.pas` | **Not read.** `Simulxcode.pas:42` already produced one finding (3.5), so it deserves a pass |
| **R13** | `TDemRegInitThread` in `DemographicRegime.pas:61-105` and its scheduling loop at `1078-1118` | **Read 31 August**, and it had never been covered: R3 read the unit's demographic routines but not its thread class. N42, N43, N44 |

---

## 11. The order I would work in

1. **Commit the accepted Tier A state**, before anything else. The reviewed tree is currently uncommitted.
2. **V1: build in Lazarus on your machine.** Nothing below should be trusted until the project builds and the `.lfm` files bind.
3. **V14 and V14d**, in that order. V14 tells you whether the sweep fix works; V14d tells you that ordinary runs are unchanged, which is what lets you keep every non-stepped result you have already published.
4. **N42**, which is a two-word deletion and removes a live source of identical cohorts, then **the rest of V2 to V13 and V20 to V23.** Two rounds of fixes have never been run. Do this before adding more changes on top.
5. **Answer Q1 and Q2**, then apply **N4**, **N2** and **N6**. These are the largest remaining effects on fertility. Verify with V16 and V17.
6. **N8** with **N7**: the sterility floor and the PPR adjustment interact, so decide them together.
7. **N9** and **N10**: the growth rate and the net reproduction rate, both about the proportion female at birth.
8. **N13** and **N14** in mortality.
9. **Answer Q3 and Q4**, then **N22**, **N24**, **N25**, **N26** in inheritance. Verify with V18.
10. **N17**, **N20**, **N18** and, if you decide for it, **N19** in education. Four separate decisions.
11. **N11**, the cohort parameter lists, and the `setChanged` comment for 6.4.
12. **Tier C**, one item at a time, each with its own test: 2.3, 2.4, 2.5, N34, N35, N36, N37, N38.
13. **B1**, bootstrapping, as one deliberate change, with **N41** as its acceptance test, then **B3**.
14. Sections 3, 4 and 5: the settings round trip, the output hygiene, and the remaining bounds.
15. **P9**, the line endings of `Fertility.pas`, in its own commit.
16. Documentation (section 8), then publication (section 9).

Steps 1 to 4 are the ones that make everything after them meaningful. Steps 5 to 10 are
where the published numbers change. Everything from 12 onwards can wait for a second
release if you want to publish sooner.

---

## Appendix: what is already fixed

Not yet compiled in Lazarus. All of it is in the working tree.

**Round 1, 24 August.** 0.1 `mySetValue` restored; 1.2 key written after the kin filter;
1.4 `partnershipStatus` comparison and the missing `else`; 1.5 `readDemocareFile` enum,
sentinel, offset, sex column, nil dereference and handle leak; 1.6 DemoCare `nChildren`
for every relative; 1.7 bootstrap append; 1.8 the link file no longer overwrites `fname`;
1.10 DemoCare key separator; 1.11 grandparent chains keep the male ancestor; 1.12
great-grand-niece guard; 1.13 `kt_total` in 11 of 12 loops; 1.14 `setInfoParents` and
guarded divisions; 1.15 `InterlockedIncrement` on three counters; 1.16 the ego-budget
off-by-one; 1.9 partial.

**Round 2, 25 August.** D1 `dead` status; D2 `secondUnions` and the last-union logic;
D6 `runDrawsFromSeveralThreads`; D7 relatives dead before the reference age dropped and
link rows never naming them, `checkLinks` removed; 3.a `MULTITHREADING_SIMKIN` saved and
read; 4.3 counts only what was written; 4.10 the four dialogs free their `BooleanName`
objects.

**Round 3, 25 August.** W1 BATCH removed throughout, which also removes audit 2.2 and
three of the four 2.1 division sites; W2 multi-cohort output kept in one file with
continuous family and individual numbering; 6.1a the seed race, seeding moved to the
three thread constructors through `initWithSeed` and `nextThreadSeed`; B4 `header_GEDCOM`
no longer writes to the DemoCare-only link file; 3.2 `aCommand_raw`; 2.1 the `msElapsed`
guard; D5b `readDemocareFile` reads the `relative` column; D5a the reverse marriage row
re-types only a still-`kt_nonBio` target.

**Round 4, 26 August, Tier A, commits `3ab5e7f` and `13e7a70`, plus `e4d8999`.**

- Batch 1: N1 the parameter sweeps; N3 `endUnion`; N5 the missing `else` on `monthIncrement`; N15 `ind_max`; N16 `eduLevel`; N21 the ascendant share loop; N23 the mother; N27 `getPartner`; N33 and N33b in `truncateAtAge`; 4.9 one inheritance message instead of 21.
- Batch 2: N40 the two BACKFOR counters; 2.6 the fallback cleanup loop deleted; 3.e `FILENAME` always written; A1 blank lines in the cohort file; A2 the empty-cohort divisions. **N39 `mothersInfoList.pas` was NOT deleted, contrary to what this appendix said until 31 August**: the file is still on disk and still tracked in HEAD. The sandbox could not unlink it (see the delete-permission note in the project memory), so the deletion never reached the commit even though the commit message claims it. Redo it.
- `e4d8999`: N12 `readInConfigFile` set in all ten branches of `processValuesLine`.
- Applied and reverted: N8, because it changes fertility and belongs with your decisions.
- Considered and not applied: N19, because correcting it changes the cohort file format.

### Cross-reference: the first audit's IDs

Findings that appear in `docs/KinFert-PreRelease-Audit.md` under their own numbers and
were closed under a different label, so that a reader working from that document can tell
they are done.

| Audit 1 | Closed by | Evidence in the tree today |
|---|---|---|
| **4.1** | D7, round 2 | `writeKinDemoCare` was called with `checkLinks = false`, so the block that drops relatives who died before ego's reference age never ran. The `checkLinks` parameter no longer exists anywhere in the tree, and the filtering is unconditional |
| **4.4** | W2, round 3 | Family and individual ids restarted at 1 for every cohort. `gFirstFamilyInFile`, `gFirstRelativeInFile` and `gIndividualsInFile` (`Kinship.pas:247-249`) now carry them across the cohorts that share a file, reset at `7746-7748` only when a new file opens, advanced at `7887`, and used at `7842` and `7862`. **Verify with V9** |
| **4.5** | B4, round 3 | `header_GEDCOM` wrote to `gOutFileIndivKin_link`, a handle only opened for DemoCare. The procedure now writes to `gOutFileIndivKin` alone, and `Kinship.pas:7432-7435` records why |
| **5.5** | W1, round 3 | `nThreadsInBatch := round(gNumThreadsUsed / nBatches)` cannot divide by zero any more because neither identifier exists: the BATCH path is gone |
| **5.1, 5.3, 5.4** | Cleared in the audit itself | Initialized locals are reset per call (confirmed by running FPC 3.2.2); the output file is written only from the main thread; logging from workers is marshalled through `Application.QueueAsyncCall`. Do not re-litigate these |
| **6.1** | R1, and 6.1a | Answered: `TRandomNumberGenerator` keeps its state in instance fields, and only `initRandomized` and `nextThreadSeed` touch the RTL `RandSeed`. **But see N42**: one worker still calls `initRandomized` from its own `Execute` |
| **6.2** | R6 | `Memory.pas` closed: `DebugMemory` is never defined, so the standard memory manager is used and the unlocked `ptrList` is unreachable |
| **6.3** | R8, and the FPC run | `cStringOf` renders booleans as `TRUE`/`FALSE` and doubles through `gFormatSettings`, so the boolean round-trip and the locale decimal-comma worry are both cleared |
| **6.5** | R2 | `Fertility.pas` and `FertilityRuntime.pas` read in full: N2 to N8 and six arithmetic items |
| **6.6** | R7 | `initMotherhood`'s threading read: N34 to N38 and N41 |

**Round 5, 31 August. Debug-switch consolidation, applied and compile-checked.**

- **N48**, the 46 `assert (true, ...)` traps changed to `assert (false, ...)` in `Fertility.pas`, `FertilityRuntime.pas`, `Kinship.pas`, `Nuptiality.pas` and `inheritance.pas`. Every one was inside the `if gRunFromIDE then {$IFNDEF ARM} asm int 3 {$ELSE} assert {$ENDIF}` idiom, checked site by site before the substitution. On Apple Silicon these now actually fire.
- **`CHECK_DATASTRUCT` removed.** The 13 gate sites (12 in `Kinship.pas`, 1 in `Nuptiality.pas`) now test `g_GENPARAM.DEBUG.value`. Removed: the enum member in `Declarations.pas`, the default and the `Create` in `Init.pas`, the `CHECK_DATASTRUCT := DEBUG` derivation at the old `Init.pas:750`, the config writer, and both reader branches. No behaviour change: the derivation meant the two were already equal wherever either was read. Closes **3.3** and **N47**.
- **The compile-time `Debug` symbol removed.** All 70 `{$IFDEF DEBUG}` blocks were unconditional in every build, since `Defines.pas` defined the symbol always. 142 directive lines deleted, bodies kept. Two blocks had an `{$ELSE}`, both the `GenericName.Create` signature with the extra `check` parameter; the `DEBUG` branch was kept. `{$define Debug}` in `Defines.pas` replaced by a comment explaining the removal. `DebugMemory` is a different symbol and is untouched. No behaviour change.
- **`dumpArray` added to `Utilities.pas`**, five overloads (double, longint, boolean, char, string) over a private `dumpArray_strings`, writing `<results>/<name>.txt` as an index row and a value row for spreadsheets. Gate call sites with `g_GENPARAM.DEBUG.value`.
- Daniel separately made `DEBUG` survive a run (`gDebugSession` in `Declarations.pas`, `Init.pas` restoring from it, the Utiles checkbox setting it) and set `gStdDev_fecundability := stdDev` in `Fertility.pas` (see N4).

**Verification of round 5.** FPC 3.2.2 with the Lazarus 3.0 LCL, in the session container, with `-Mobjfpc -Sh -Sm -Sa -Ci -Co -CO -Cr -O- -dLAZARUS_GUI` to match `kinfert.lpi`. All 18 non-GUI units compile: `Declarations`, `StringOfLib`, `RandomNumbers`, `Memory`, `StablePop`, `Mortality`, `Fertility`, `EducationalLevel`, `Nuptiality`, `Parenthood`, `inheritance`, `DemographicRegime`, `FertilityRuntime`, `Kinship`, `SpecialRuns`, `Init`, `ReadCmdFileUnit`, `Utilities`. `LazMain` and `LazUtiles` were replaced by small stubs, so the `.lfm` binding and the GUI units still need **V1** in Lazarus. The warning set is unchanged in kind: "Type size mismatch" throughout, three "Comment level 2", and five older warnings at `Nuptiality.pas:910, 930`, `Fertility.pas:92, 233`, `DemographicRegime.pas:1806` and `FertilityRuntime.pas:517`, the last of which is now logged as N49.

**Before the audit.** Per-format kin sets with the swap in `TKinFmtComboBoxChange.myGetValue`;
the hardcoded DemoCare kin set removed; `DEMOCARE_LARGE_FIELDS` replacing the `DUMPALL`
binding; the `LazDemoCareFields` dialog; the per-format dispatch of the optional-fields button.
