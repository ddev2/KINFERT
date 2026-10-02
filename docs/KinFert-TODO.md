# KinFert: what is open

**This is not a change log.** It is what the author knows to be open, and what is planned, for a
reader deciding whether to use KinFert or to build on it. The program is in its verification phase:
until the checks collected in [`KinFert-Verification-Plan.md`](KinFert-Verification-Plan.md) have
been made and answered, no run should be treated as settled.

Last reviewed: 2 October 2026.

---

## What can affect a result

| | |
|---|---|
| **The country inheritance rules have no effect** | The parameter that selects between the two sets of succession rules is never consulted, and both algorithms run unconditionally. Results for heirs and shares are therefore those of one rule set whatever is chosen |
| **The fertility of ego's partners is reported as zero** | The tables that compare ego, ego's mother and ego's partner are computed from arrays that nothing fills, so the partner column is empty in every run. The repair is one call and is pending a decision, since it turns a column of zeros into a column of numbers |
| **One deliberate decision, in the CAMSIM 1987 backward search** | The mother found by that search is given the year of birth of her own child, so her reproductive life is simulated with the regime of the following generation. Correcting it would change what that algorithm is, so it is left unchanged and the comment at that line says so. It does not touch the default algorithm |

## Limits of the model, by design rather than by oversight

- **A groom has no simulated life of his own.** Men enter a kin network as the partner of a
  simulated woman, with the one union they were created for; nothing before that union exists, and
  a man's age at first union is the one the match implied rather than one drawn from the male
  schedule. Building a pool of men means deciding whose reproductive history is the master when two
  simulated people form a union, and today it is the woman's throughout.
- **The pool of brides exists only under a stable population**, to save memory. Under regimes that
  vary by cohort the brides are drawn from the pool of women instead.
- **The two education modes that follow observed levels fall back to values built into the program**
  for any distribution the cohort file does not supply. A run in one of those modes says in its log
  whether the file supplied them.

## Robustness

- Several parameters accept values the model cannot use, and a few indices are computed without
  bounds. None of them binds while the inputs are sensible, and the guardrails are being added.
- Object lifetime and memory ordering under multithreading are not settled. A multithreaded run is
  not reproducible even with the same random sequence, which the program says at the start of such
  a run.
- Some faults are reachable by clicking through the dialogs rather than by running a simulation.

## Documentation

- The manual is a first draft, reconstructed from the source. Chapters 13 and 14, the two guided
  chapters on experimenting with the fertility model and on the kinship model, are a scaffold:
  every heading and every figure slot is in place and the text is not.
- Forty-seven screenshots are listed in [`img/README.md`](img/README.md) and none has been made.
- Nine questions are open in Appendix F of the manual, chiefly the conception model, the
  repartnering hazard, the mapping from life expectancy to survival, the country inheritance rules,
  and the grammars of the input and output files.
- There is no worked example with known outputs, which would also serve as a regression test.

## Packaging and release

- Binaries for macOS and Windows are attached to the releases. The macOS build is neither signed
  nor notarised, so Gatekeeper refuses it on a first open; the README says how to allow it.
- The Lazarus and FPC versions the program is known to build under are in the README. A documented
  release build mode is still to come.
- A minimal regression test, one small configuration file with an expected output folder and a note
  on how to compare, is planned.

## Planned changes

- **Bootstrapping will be removed.** The parameter sweeps cover what it was for, and the two
  mechanisms cannot be combined in one run.
- A second implementation of parts of the model, as a way of checking the first, is under
  consideration.
