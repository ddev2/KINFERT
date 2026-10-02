# KinFert

A kinship-network microsimulation program with a detailed fertility module, written in Free Pascal and built with Lazarus.

KinFert simulates the reproductive life of individual women month by month, taking account of fecundability, permanent sterility, postpartum amenorrhea, contraceptive behaviour for spacing and for stopping, union formation and dissolution, and mortality. From those simulated life histories it reconstructs the kinship network of selected individuals, called egos, and can resolve inheritance over that network: who the heirs and decedents of an ego are, and what share of an estate each receives.

The kin network is built by combining two directions of simulation. Forward, a woman's reproductive life is played out from the start of her reproductive span, generating her children inside her union history. Backward, ego's ancestors are reconstructed two generations up: ego's possible mothers generate ego and ego's siblings, and the mothers' own possible mothers generate the parents' generation. The backward reconstruction follows the tradition of the CAMSIM and BACKFOR kinship microsimulation models, and the source retains several variants of those algorithms.

Each ego therefore ends with a genealogical tree spanning descendants, ancestors, and their collateral relatives.

## Documentation

**[The KinFert manual](docs/KinFert-Manual.md)** is the place to start. It describes every window
and every option, the demographic model behind them, the kin taxonomy and the file formats, and it
has two guided chapters on using the fertility model and the kinship model. It is a first draft
reconstructed from the source, and the points where the code alone does not settle the intended
demographic meaning are marked and collected in its Appendix F.

Two documents go with it, in [`docs/`](docs):

| Document | What it is |
|---|---|
| [`KinFert-Verification-Plan.md`](docs/KinFert-Verification-Plan.md) | What has to be verified: one entry per check, with the run to make, the file to look at and the answer to expect |
| [`KinFert-TODO.md`](docs/KinFert-TODO.md) | What is open and what is planned: the defects that can affect a result, the limits of the model that are by design, and what the documentation and the packaging still need |

## Status

**KinFert is in its verification phase. It is published so that the code, its documentation and
its results can be read and checked, not because the results are settled.** Nothing a run produces
should be treated as final until the checks collected in `docs/KinFert-Verification-Plan.md` have
been made and answered. That document is the list of what is checked, what is not, and how each
answer would be obtained.

The program has been used for research for many years. A systematic audit that began in August 2026
found a number of defects, and those that affect results have since been corrected: the
fecundability model, the birth interval and the effect of infant death on it, the parity
progression adjustment, the intrinsic rate and the net reproduction rate, the infant mortality age
correction and the life expectancy range, the education module, the lost unions and the union
setters, the schedule of ages at first union, and, on 30 September 2026, the inheritance rules for
ascendants and for lateral relatives.

What is still open is in [`docs/KinFert-TODO.md`](docs/KinFert-TODO.md). In summary:

| | |
|---|---|
| One deliberate decision | `Kinship.pas`, in the CAMSIM 1987 backward search: the mother is given the year of birth of her own child, so her reproductive life is simulated with the regime of the following generation. Correcting it would change what that algorithm is, so it is left as it stands and the comment at that line says so |
| One option with no effect | The country inheritance parameter never selects between the two rule sets. Both run unconditionally |
| Guardrails | Several parameters accept values the model cannot use, and a few indices are computed without bounds. None of them binds while the inputs are sensible |
| Threading | Questions of object lifetime and memory ordering |
| The dialogs | Faults reachable by clicking rather than by running |

A change that has not yet been reviewed is wrapped in the source between `// >>> Claude <date>
start` and `// <<< Claude <date> end`, so that it can be read in place; the markers are removed
once the change is accepted.

Results produced with earlier versions of the program are not comparable with results produced
today wherever one of the corrected defects was in play.

## Building from source

KinFert is a desktop application with a graphical interface. It is developed on macOS, including
Apple Silicon, and also targets Windows.

You need:

- **Lazarus 4.6**, which bundles the **Free Pascal Compiler**. The reference build uses
  **FPC 3.2.2**. Both were installed with fpcupdeluxe.
- The **LCL** package, which ships with Lazarus.
- The **TAChartLazarusPkg** package, which also ships with Lazarus and provides the charts on the
  Graphs window.

`kinfert.lpi` declares exactly those two packages. To build, open `kinfert.lpi` in Lazarus and
compile, or run `lazbuild kinfert.lpi` from a terminal.

Compile-time switches live in `Defines.pas`, which every unit includes with `{$I Defines.pas}`.
Range checking is on, and `ARM` is defined for `CPUAARCH64`. The `Debug` symbol was removed in
August 2026: it was defined in every build, so the blocks it guarded were never optional and are
now unconditional. Diagnostics are controlled at run time instead, by the `DEBUG` parameter and by
`gRunFromIDE`.

Compiled binaries and build artefacts are not stored in the repository.

### On macOS: leave the deployment target alone

Do not add `-WM11.0`, or any other macOS minimum version, to the compiler options. FPC 3.2.2 emits
Objective-C metadata that Apple's current linker rejects once the deployment target is macOS 11 or
later, because that turns on chained fixups, and the link then fails inside an LCL Cocoa unit with

```
ld: malformed method list atom 'ltmp5' (cocoawsextctrls.o), fixups found beyond the number of
method entries
```

With the target left at its default the program links. Two groups of messages are then expected and
harmless: several hundred lines of `ld: warning: object file ... was built for newer macOS version
(11.0) than being linked (10.15)`, and one line reading `-macosx_version_min has been renamed to
-macos_version_min`, which Lazarus counts as an error although the link succeeds. A newer Free
Pascal is the proper remedy and is on the list.

### The two configuration files

The program keeps two small text files of one line each: the folder configurations were last read
from, and the folder results were last written to. It writes them itself, the first whenever a
configuration file is read and the second whenever an output directory is chosen with the
**Output directory** button.

**They are the program's own state. They are not input, and are not meant to be created or edited
by hand.** A fresh installation has neither, which is not an error: the two paths start empty, and
the program writes the files as soon as the folders have been chosen in the interface.

Each system keeps them in the folder it sets aside for an application's per-user state, under a name
that says which system wrote it, so that a Mac and a Windows PC never overwrite each other's paths:

| System | Files |
|---|---|
| macOS | `~/Library/Application Support/KinFert/ConfigDir-macOS.cfg` and `OutputDir-macOS.cfg` |
| Windows | `%APPDATA%\KinFert\ConfigDir-Windows.cfg` and `OutputDir-Windows.cfg` |
| other Unix | `$XDG_CONFIG_HOME`, or `~/.config` when it is unset, then `KinFert/ConfigDir-Linux.cfg` and `OutputDir-Linux.cfg` |

Before 1 October 2026 both files sat next to the executable instead, which on macOS meant inside
the application bundle. A version from before that date leaves its two files there; the first run of
a later version reads them, writes the new ones, and from then on uses only the new ones. Nothing
has to be moved by hand, and the old files can be deleted once a run has been made.

## Binaries

Compiled programs for macOS and for Windows are attached to the releases rather than kept in the
repository, since neither can be produced from the other without the matching toolchain.

The macOS build is neither signed nor notarised, so on a first open macOS refuses it. Either open
it once from the Finder with a right click and the Open command, which offers the choice the
double click does not, or clear the quarantine attribute from a terminal:

```
xattr -d com.apple.quarantine /path/to/KinFert.app
```

## Repository layout

| Path | Contents |
|---|---|
| `*.pas`, `*.lfm` | The Pascal units and the Lazarus form definitions. |
| `kinfert.lpi`, `kinfert.lpr` | The Lazarus project. |
| `docs/KinFert-Manual.md` | User and reference manual: every window and option, the demographic model, the kin taxonomy, and the file formats. A first draft, with open questions collected in its Appendix F. |
| `docs/KinFert-Verification-Plan.md` | What has to be verified, one entry per check, with the run to make, the file to look at and the answer to expect. The program is in its verification phase and this is the record of it. |
| `docs/KinFert-TODO.md` | What is open and what is planned. |
| `tools/` | `compareruns.lpr`, which compares two results folders, and the small scripts described in `tools/README.md`. |

### The main units

| Unit | Role |
|---|---|
| `Kinship.pas` | The kinship engine: tree construction, the backward algorithms, threading, and the individual output files. |
| `Fertility.pas`, `FertilityRuntime.pas` | The fertility model and its month-by-month runtime. |
| `Nuptiality.pas` | Union formation, dissolution and repartnering. |
| `Mortality.pas` | Model life tables and survival. |
| `Parenthood.pas` | The person memory block and the parent-side bookkeeping. |
| `DemographicRegime.pas`, `StablePop.pas` | Per-cohort parameter sets, the cohort file, and the stable population. |
| `EducationalLevel.pas` | Assignment of educational level, with the three correlation modes. |
| `inheritance.pas` | Heirs, decedents and shares, under two algorithms. |
| `Declarations.pas`, `Init.pas` | Global types, the parameter objects, and their defaults. |
| `ReadCmdFileUnit.pas` | Reading and writing the configuration file. |
| `Utilities.pas`, `StringOfLib.pas` | File handling, formatting and messages. |
| `RandomNumbers.pas` | The random number generator, one instance per thread. |
| `Laz*.pas`, `lazkin*.pas` | The GUI windows and dialogs. |

## Citation

If you use KinFert in published work, please cite the program and the version you used. A formal citation entry is still to be added here.

## Licence

MIT. See `LICENSE`.

## Author

Daniel Devolder, Centre d'Estudis Demogràfics, Universitat Autònoma de Barcelona.
