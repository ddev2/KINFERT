# KinFert — instructions for Claude

Kinship-network microsimulation with a detailed fertility module (Free Pascal /
Lazarus, LCL + TAChart, macOS and Windows GUI app). Author: Daniel, demographer —
treat him as the domain expert; never explain demography basics.

## Project goals (in priority order)
1. Debug untested/old options, and hunt bugs in the normally-used paths that
   could affect results.
2. Write the manual (`docs/KinFert-Manual.md`) from scratch.
3. Publish on GitHub for a mixed audience: researchers who want binaries
   (assume no Lazarus experience) and developers who will rebuild/extend.

## How to work on the code
- Fix bugs directly and explain what changed; git makes it revertible.
- Do NOT refactor, restyle, or "improve" working code beyond what the task
  requires — this is a recurring correction.
- Match the surrounding unit's style exactly, inconsistencies included.
- Claude cannot compile LCL code. After edits, hand off: Daniel builds in the
  Lazarus IDE and reports errors back. Don't claim a change "works" — say it
  awaits a compile check.
- Git: stage changes and propose a commit message; Daniel commits himself.
- Sandbox cannot delete files here — call allow_cowork_file_delete first.

## Documentation policy
- The code is the specification. Document what it actually does; where
  demographic *intent* is uncertain, write `[TODO: confirm]` and add the
  question to Appendix F — don't guess, don't interrupt to ask.

## Layout notes (what's not obvious from a listing)
- Flat source tree; `kinfert.lpi` is the project, `kinfert_heapTrace.lpi` a
  debug variant. `oldInitMotherhood.p` is retired code kept for reference.
- `KinFert ConfigDir.cfg` / `OutputDir.cfg` are machine-specific (gitignored);
  test data lives outside the repo on Google Drive.
- Core simulation units: Kinship.pas (largest), Fertility.pas /
  FertilityRuntime.pas, DemographicRegime.pas, Mortality.pas, Nuptiality.pas,
  inheritance.pas. `Laz*.pas` + `.lfm` pairs are the GUI forms.
