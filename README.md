# KinFert

A kinship-network microsimulation program with a detailed fertility module, written in Free Pascal and built with Lazarus.

KinFert simulates the reproductive life of individual women month by month, taking account of fecundability, permanent sterility, postpartum amenorrhea, contraceptive behaviour for spacing and for stopping, union formation and dissolution, and mortality. From those simulated life histories it reconstructs the kinship network of selected individuals, called egos, and can resolve inheritance over that network: who the heirs and decedents of an ego are, and what share of an estate each receives.

The kin network is built by combining two directions of simulation. Forward, a woman's reproductive life is played out from the start of her reproductive span, generating her children inside her union history. Backward, ego's ancestors are reconstructed two generations up: ego's possible mothers generate ego and ego's siblings, and the mothers' own possible mothers generate the parents' generation. The backward reconstruction follows the tradition of the CAMSIM and BACKFOR kinship microsimulation models, and the source retains several variants of those algorithms.

Each ego therefore ends with a genealogical tree spanning descendants, ancestors, and their collateral relatives.

## Status

**This is a pre-release. It is published so that the code and its documentation can be read and checked, not because it is finished.**

The program has been in use for research, but a systematic audit carried out in August 2026 found a number of defects that affect results. Some are fixed; several are not. Anyone using KinFert for substantive work should read `docs/KinFert-TODO.md` first, and in particular section 2E.

The findings that are **fixed** are listed in `docs/CHANGES-2026-08-26.md`, with the unit and line of every change. Each site is marked in the source with a `// --- CLAUDE 2026-08-26 [ID]` block that also carries the replaced code, commented out, so any change can be read in place.

The findings that are **still open and affect results** include, at the time of writing:

| ID | Effect |
|---|---|
| N4 | Heterogeneity in fecundability is applied as a 12 per cent coefficient of variation instead of the intended N(0.23, 0.12), so most of the heterogeneity is absent. |
| N2, N6 | Two time-origin errors in the birth interval: the effect of an infant death is overstated by about a gestation, and the contraceptive spacing wait is applied twice. |
| N7 | The parity progression target adjustment sets progression to near-certainty at parities the simulation never reached, with no convergence test. |
| N8 | Women who are still fecund at the top of the fertile age range are recorded as sterile at the bottom of it. |
| N9, N10 | The intrinsic growth rate omits the proportion female at birth, and the net reproduction rate hard-codes 0.488 rather than reading the parameter. |
| N13, N14 | The infant-mortality age correction is inverted, and a life expectancy outside the tabulated range is warned about but not clamped. |
| N22 to N26 | Several rules in the inheritance module do not match the succession rules stated in its own header comment. |

The two audit documents, `docs/KinFert-PreRelease-Audit.md` and `docs/KinFert-PreRelease-Audit-2.md`, give the evidence for each one.

## Building from source

KinFert is a desktop application with a graphical interface. It is developed on macOS, including Apple Silicon, and also targets Windows.

You need:

- **Lazarus**, which bundles the **Free Pascal Compiler**. The source is written for **FPC 3.2.2**. The exact Lazarus version used for the reference build is still to be pinned here.
- The **LCL** package, which ships with Lazarus.
- The **TAChartLazarusPkg** package, which also ships with Lazarus and provides the charts on the Graphs window.

`kinfert.lpi` declares exactly those two packages. To build, open `kinfert.lpi` in Lazarus and compile, or run `lazbuild kinfert.lpi` from a terminal.

Compile-time switches live in `Defines.pas`, which every unit includes with `{$I Defines.pas}`. Range checking is on, `Debug` is defined, and `ARM` is defined for `CPUAARCH64`.

Compiled binaries and build artefacts are not stored in the repository.

## Repository layout

| Path | Contents |
|---|---|
| `*.pas`, `*.lfm` | The Pascal units and the Lazarus form definitions. |
| `kinfert.lpi`, `kinfert.lpr` | The Lazarus project. |
| `docs/KinFert-Manual.md` | User and reference manual: every window and option, the demographic model, the kin taxonomy, and the file formats. A first draft, with open questions collected in its Appendix F. |
| `docs/KinFert-TODO.md` | The working list of what remains before a finished release. |
| `docs/KinFert-PreRelease-Audit.md` | Audit of the individual-file output path. |
| `docs/KinFert-PreRelease-Audit-2.md` | Audit of the demographic engine. |
| `docs/CHANGES-2026-08-26.md` | Index of the fixes applied on 26 August 2026. |

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

## Documentation

`docs/KinFert-Manual.md` is the place to start. It is a first draft reconstructed from the source, and the points where the code alone does not settle the intended demographic meaning are marked and collected in its Appendix F.

## Citation

If you use KinFert in published work, please cite the program and the version you used. A formal citation entry is still to be added here.

## Licence

MIT. See `LICENSE`.

## Author

Daniel Devolder, Centre d'Estudis Demogràfics, Universitat Autònoma de Barcelona.
