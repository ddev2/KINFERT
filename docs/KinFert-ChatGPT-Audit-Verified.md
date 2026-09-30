# Verification of the second reviewer's guardrails audit

15 September 2026. Every claim in `chatgpt/guardrails-audit.md` and
`chatgpt/parameter-catalogue.md` was checked against the current source. Nothing was changed in
the source for this document. Where a question turned on Free Pascal semantics rather than on
reading, a small program was compiled to settle it.

## 1. Two facts that decide several claims at once

`Defines.pas:10` contains `{$rangeChecks on}`, and `Defines.pas` is included at the head of every
unit, so range checking is compiled into every build, release as well as debug. Every
out-of-bounds array access the audit describes therefore ends the run with a controlled range
error. None of them is memory corruption, and the audit's phrase "without range checking this is
memory corruption" does not apply to KINFERT as it is built.

Free Pascal leaves the floating point exceptions unmasked here: a compiled test confirms that
`0.0/0.0` raises `EInvalidOp`, `x/0.0` raises `EZeroDivide` and integer `mod 0` raises
`EDivByZero`. The divisions by zero the audit lists end the run with a visible error; they do not
produce silent NaN values that propagate into results.

## 2. The finding that matters most, and it is a real one

**Education probabilities read from a cohort file never reach the distribution the model samples
from.** `cumulValue` is written in four places only: the three cumulation loops of `initEduStatus`
(`EducationalLevel.pas:41-43`, `75-77`, `124-131`) and `DoubleCumulName.copyMeTo`
(`Declarations.pas:1753`). `initEduStatus` runs once per regime object, at
`DemographicRegime.pas:290`, immediately after the objects are created with their built-in
defaults. The cohort file reader then writes only `.value` (`DemographicRegime.pas:1589-1599`),
and cohort interpolation likewise (`DemographicRegime.pas:655-671`). All three sampling routines
read `cumulValue` (`EducationalLevel.pas:215-217`, `235-237`, `284-286`).

So in `eduCohort` or `eduIntraFamily` mode the probabilities asked for are echoed faithfully in
`_ALLCOHORTS.TXT`, which dumps `.value`, while every individual is drawn from the shipped
defaults: 0.5, 0.4 and 0.1 for men, 0.6, 0.35 and 0.05 for women. Wrong numbers, no warning, and
a dump that agrees with the input. This one deserves to be fixed before release.

One part of that claim does not hold. The audit adds that the main configuration file reaches the
same defect through `DoubleCumulName.readValue`. It does not: `ProcessCommand` has no dispatch
for the education arrays, and `DoubleCumulName.readValue` has no caller anywhere in the project.
The affected routes are the cohort file and cohort interpolation only.

## 3. Confirmed, and able to change results

- **`parameterStateName.readValue` zeroes the number whenever the token is a word**
  (`Declarations.pas:2084-2095`). `val` sets its destination to zero when the conversion fails,
  and the code then reports success. The parameter's own comment invites the input that triggers
  it: "enter TRUE or parameter value". With `FIXED_DEFINITIVE_STERILITY=TRUE` the sterility age
  becomes 0, `fixParameter` sets sterility to 1.0 at every age (`Fertility.pas:1365-1368`), and
  the run produces no births at all. `FIXED_AMENORRHEA=TRUE` silently sets the fixed amenorrhoea
  duration to zero rather than to the documented 2. Reading back a configuration KINFERT wrote
  itself, with `=FALSE`, silently resets the stored age from 50 to 0. This is more serious than
  the audit says, and it is the one I would fix second.
- **An invalid `FIXED_FERTILITY_VALUE` leaves the schedule unset** (`Init.pas:695-737`, no `else`
  arm). The consequence is not the array access the audit expects: every woman enters a union at
  age 0, bears no children, and `writeSMAM` reports a mean age at union of 0. Silently wrong, not
  a crash.
- **The male and female detailed singlehood ranges are exchanged**
  (`ReadCmdFileUnit.pas:298-308`). `PROP_SINGLE_MEN` carries the female bound of 75 and
  `PROP_SINGLE_WOMEN` the male bound of 80. A round trip truncates the male schedule at 75 and
  writes five meaningless female ages. Both arrays are allocated to 81, so nothing goes out of
  bounds.
- **Misspelled logical values read as false** (`ReadCmdFileUnit.pas:1211`). `KINSHIP=TREU`
  disables kinship silently. On the file-name-capable commands the grammar is the other way
  round: `DUMP=TREU` turns dumping on and writes to a file called TREU.
- **The enum readers assign before reporting the error**, in `EduStatusName`, `KinFileFmtName` and
  `CountryInheritanceName` (`Declarations.pas:1845`, `1952`, `2048`). The new
  `MotherAlgorithmName.readValue` added on 14 September does not have the defect: a rejected
  token leaves the object untouched, so it is the pattern to copy into the other three. The
  audit's reasoning that the cast itself traps under range checking is wrong; a compiled test
  shows an out-of-range ordinal cast to an enumerated type does not raise. The consequence is a
  mutated parameter, not an exception.
- **Cohort integer fields truncate decimals silently** (`DemographicRegime.pas:1552`, `1561`).
- **Detailed input arrays receive no scientific validation** (`ReadArray`,
  `ReadCmdFileUnit.pas:445-500`, which tests only the index bounds). No finiteness, probability
  bound, monotonicity or endpoint check on any of the nineteen tables, and the negative-value
  terminator makes a negative scientific value unrepresentable.
- **Reversed cohort bounds simulate nothing and report as though finished**
  (`ReadCmdFileUnit.pas:1616`, `1633`). To this I would add something the audit does not say:
  `getCohort_p` (`DemographicRegime.pas:1901-1916`) brings a year below the first cohort to the
  first regime and a year above the last to the last, with no message, so asking for cohorts
  outside the collection silently reuses a regime rather than failing. That strengthens the
  audit's recommendation.
- **Reversed survey bounds are accepted** (`FertilityRuntime.pas:2001-2004`), silently reversing
  the survey window.
- **`ADJUSTED_PPR` cell zero is a presence sentinel** (`DemographicRegime.pas:535`), so a
  legitimate zero first-parity value cannot be distinguished from a missing table.
- **Negative separation proportions mean "no separation"** and values above one are brought back
  to one (`Nuptiality.pas:1033`, `1069-1070`).
- **The beta fecundability normalisation adds the penultimate cell twice**
  (`Fertility.pas:602-605`). The diagnosis is exactly right. The magnitude is not: with the
  shipped shape the penultimate density is of order 1e-19 against a total of order one, and the
  two shape parameters cannot be set from a configuration file at all, so this is worth fixing
  for correctness and not for results.

## 4. Confirmed, missing guardrails only

These end the run or hang it. None of them alters published numbers quietly.

- **`MODEGO <= 0`**: `EDivByZero` at `Kinship.pas:8786` in the single threaded path, and a loop
  that cannot terminate at `Kinship.pas:8500-8501` in the multithreaded reporting path. The hang
  needs `OUTPUT_INDIVIDUAL_KINSHIP_INFO` on; the division by zero does not. No bounds in the
  dialog or in parsing.
- **`STEP_COHORT` at zero or negative**: neither cohort loop advances (`ReadCmdFileUnit.pas:1615`,
  `1632`). With kinship on the hang is immediate; with kinship off the whole simulation repeats
  for ever.
- **Zero ever-in-union probability**: `0.0/0.0` at `Nuptiality.pas:835`. **A mean age at union of
  exactly 13.64**: `std_Coale_Rodriguez_Trussel` returns zero (`Nuptiality.pas:1329`) and
  `RodTrussFirstUnion` then divides by it twice. Both values are admitted by the dialog. The R
  reference implementation quoted in the source states both preconditions and the code does not
  enforce them.
- **Non-positive population counts**: `NWOMEN` at zero gives `0.0/0.0` at
  `FertilityRuntime.pas:1601`, and `NUMBER_WOMEN` at zero divides by zero at
  `DemographicRegime.pas:1062`. `NUMBER_WOMEN` has no dialog bounds while `NWOMEN` and `NEGO`
  have 100 to 1 000 000.
- **`ReadArray` is not transactional, and an empty array is indexed below its lower bound**
  (`ReadCmdFileUnit.pas:465`, `489`), which a compiled test confirms raises
  `EVariantBadIndexError`.
- **`readStr` has no conversion status argument** (`ReadCmdFileUnit.pas:475`), so a malformed row
  raises `EInOutError` rather than returning the failure the function's shape promises.
- **`MAX_THREADS` has no upper bound** with `FORCE_NUM_THREADS` on: the dialog permits 999 999 and
  that many thread objects are created (`Kinship.pas:8642-8657`).
- **Out-of-range fixed sterility age**: real, but the window is not the one stated. The array is
  allocated to 60 entries indexed 0 to 59 (`Init.pas:54`), so writing above it needs a value of
  61 or more, and reading below it needs a negative value. Values from 0 to 25 stay in bounds and
  are silently wrong, which is the `=TRUE` case above.

## 5. What to discount before acting on the review

- **`MAX_THREADS` at zero is not a defect.** The multithreaded block is entered only when
  `gMaxThreads > 1` (`Kinship.pas:8607`, and three other sites), so zero, one and negative values
  route the run to the single threaded path. Only the upper bound needs a guard. Note also that
  `MAX_THREADS` is read at all only when `FORCE_NUM_THREADS` is on.
- **`PROP_WOMEN_AT_BIRTH` and the intrinsic growth rate is not a validation gap.** The lines the
  audit cites, `StablePop.pas:120-122`, are inside the review comment block for bug N9, and the
  line that would use the parameter is commented out as a proposed fix. This is N9, already on
  the list.
- **`AMENO_ALPHA` and `AMENO_BETA` do not overflow.** At the widest values the dialog admits, the
  largest argument of `exp` is about 650, and the expression is a saturating logistic; a compiled
  test at more extreme arguments returned 1.0. What does stand in that bullet is that nothing
  checks the sign of beta or the shape of the curve built from it, so a negative beta silently
  inverts the intended amenorrhoea schedule. It is a shape check on a derived curve, not an
  overflow.
- **`adjustTabNupt` does not divide by a zero total** on the path described: the division at
  `Nuptiality.pas:773` is guarded, and when the ever-union probability is zero both quantities are
  zero so the division is skipped. A defensive test there is still worth having.
- **Zero or negative `NSTEP_*` is narrower than stated.** `checkStepsAndStablePopulation`
  (`FertilityRuntime.pas:485-498`) forces all seven counts to 1 outside stable population mode, so
  the silent no-simulation case arises only in stable population mode without
  `OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES`. Kinship still runs either way.
- **`OPTIMAL_TREES` at zero is largely masked** at `Kinship.pas:8632`, which raises it to at least
  `600000` divided by the mean number of kin. It would divide by zero only if that floor were
  also zero, needing a mean kin count above 600 000. The split default is real: the constructor
  uses 1000 and `initGeneralCmd_values` resets to 200.

One item the two documents do not mention: `EFF_STOPPING_CONTRACEP` and `PROP_USING_SPACING` are
registered as integers (`LazConfig.pas:528-529`) although both are probabilities bounded by zero
and one.

## 6. On the architectural recommendation

The recommendation of one validation stage shared by the dialog, the configuration file, the
cohort file and interpolation, running before any derived table, allocation, output file or
worker thread is created, is the right shape, and section 2 above is the argument for it: the
education defect is precisely a derived table that is built once and never rebuilt when its
inputs change. A validation stage alone would not have caught it, though. What catches that class
of defect is a rule that no derived table is built at load time, but on first use from the values
in force, or else that every writer of a `.value` also calls the routine that rebuilds what
depends on it. Worth settling before writing the validation stage, because it decides where the
stage sits.
