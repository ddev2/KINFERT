# KinFert: User and Reference Manual

*A kinship-network microsimulation program with a detailed fertility module.*

> **Draft status.** This is a **first draft**, reconstructed from the program's
> source code (treated as the specification) and its Lazarus form definitions.
> Sections that describe the *intended* demographic meaning of an option, or the
> exact grammar of a file, are marked **`[TODO: confirm]`** where the code alone
> does not settle the question. These are collected in
> [Appendix F: Open questions](#appendix-f-open-questions-for-the-author).
> Nothing here changes the program; it documents it.
>
> **Verification phase.** The program itself is in its verification phase. The defects found in
> the audit that began in August 2026 are recorded in `KinFert-FIXED.md`, and what is still open
> is in `KinFert-TODO.md`, but no run should be treated as settled until the checks collected in
> `KinFert-Verification-Plan.md` have been made and answered. That document lists what is checked,
> what is not, and how each answer would be obtained.

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Installation and building](#2-installation-and-building)
3. [Getting started: the main window](#3-getting-started-the-main-window)
4. [Configuring a simulation: the Config window](#4-configuring-a-simulation-the-config-window)
5. [Low-level (biological) options: the LowLevel window](#5-low-level-biological-options-the-lowlevel-window)
6. [Outputs: the Outputs window](#6-outputs-the-outputs-window)
7. [Graphs](#7-graphs)
8. [The demographic model (methods)](#8-the-demographic-model-methods)
9. [Kin taxonomy reference](#9-kin-taxonomy-reference)
10. [Input file formats](#10-input-file-formats)
11. [Output file formats](#11-output-file-formats)
12. [Tutorial: a first simulation](#12-tutorial-a-first-simulation)
13. [Experimenting with the fertility model](#13-experimenting-with-the-fertility-model)
14. [Working with the kinship model](#14-working-with-the-kinship-model)
15. [Troubleshooting](#15-troubleshooting)
16. [Appendices](#16-appendices)

---

## 1. Introduction

### 1.1 What KinFert is

**KinFert** is a demographic **microsimulation** program. It simulates the
reproductive life of individual women month by month, taking into account
fecundability, sterility, postpartum amenorrhea, contraceptive behaviour, union
formation and dissolution, and mortality, and from these simulated life
histories it reconstructs the **kinship networks** of selected individuals
(called *egos*). On top of the kin networks it can also resolve **inheritance**:
who the heirs and decedents of an ego are, and what share of an estate each
receives, under selectable succession rules.

The program is written in **Free Pascal** and built with the **Lazarus** IDE
using the LCL widget set and the TAChart charting package. It runs as a desktop
application with a graphical interface on **macOS** and **Windows**.

### 1.2 What it produces

A run can produce any combination of:

- **Aggregate fertility tables**: completed fertility, parity distributions,
  parity progression ratios (PPRs), birth intervals, age at childbearing,
  cohort TFR, proportions single, fertility by union duration and union status,
  and more.
- **Aggregate kinship results**: counts and distributions of kin by type, by
  age of ego, ages of fathers and sons, union life tables, and totals.
- **Inheritance results**: heirs and decedents of egos and their shares.
- **Individual microdata files**: one record per simulated individual
  (fertility) or per kin (kinship), with a configurable set of fields, optionally
  compressed to ZIP.
- **In-application graphs** of selected inputs and outputs.

### 1.3 The modelling approach

KinFert combines two directions of simulation:

- **Forward**: a woman's reproductive life is played out in time from the start
  of her reproductive span, generating her children (with their birth months,
  parities, and intervals) inside her union history.
- **Backward**: to give an ego a complete kin network, the program reconstructs
  ego's ancestors. It works *upward* for two generations: ego's possible
  **mothers** generate ego (and ego's siblings), and the mothers' own possible
  **mothers** (ego's grandmothers) generate the parents' generation. This
  backward reconstruction follows the tradition of the **CAMSIM** and **BACKFOR**
  kinship-microsimulation models; the code retains several variants of these
  backward algorithms (see [§8.6](#86-the-kinship-algorithm)).

Each ego therefore ends up with a genealogical tree spanning descendants
(children, grandchildren, great-grandchildren), ancestors (parents, grandparents,
great-grandparents), and their collateral relatives (siblings, cousins, aunts and
uncles, nieces and nephews, and so on, see [§9](#9-kin-taxonomy-reference)).

### 1.4 Key concepts and terminology

| Term | Meaning in KinFert |
|---|---|
| **Ego** | An individual whose kin network is simulated and reported. |
| **Cohort** | A birth cohort (year of birth). A run simulates one cohort or a range of cohorts (First/Last/Step). |
| **Demographic regime** | The full set of fertility, nuptiality and mortality parameters that govern a cohort. Each cohort can have its own regime; see the cohort data file. |
| **Lunar month** | The internal time step. There are **12 lunar months per year** (constant `kNbLunarMonths`); fertility durations are counted in lunar months. |
| **Parity** | Number of children a woman has had. |
| **PPR** | *Parity progression ratio*: the probability of having another child given current parity. KinFert can take PPRs as a *target* to reproduce. |
| **CTFR / cohort TFR** | Completed (cohort) total fertility, the mean number of children per woman at the end of reproductive life. |
| **Fecundability** | The monthly probability of conception for a non-pregnant, non-sterile woman exposed to risk. |
| **Sterility** | Permanent loss of the ability to conceive; modelled as a function of age (several models are available). |
| **Postpartum amenorrhea** | The non-susceptible period after a birth; modelled with the Lesthaeghe–Page formulation. |
| **Spacing / stopping** | The two contraceptive intentions: lengthening intervals between births (*spacing*) versus ending childbearing (*stopping*). |
| **Nuptiality** | Union formation and dissolution (first union, separation, repartnering, widowhood). |
| **Bootstrap** | Repeating a run many times (with resampling) to obtain variability of the results. |

### 1.5 How to read this manual

Chapters [3](#3-getting-started-the-main-window) to [7](#7-graphs) are a **user
guide**: they walk through every window and every option as it appears on screen,
giving the on-screen label, the internal parameter name, and what the option does.
Chapter [8](#8-the-demographic-model-methods) is a **methods reference** that
explains the underlying demographic model. Chapters
[10](#10-input-file-formats) and [11](#11-output-file-formats) describe the file
formats.

Chapters [13](#13-experimenting-with-the-fertility-model) and
[14](#14-working-with-the-kinship-model) are different in kind. They are the
**guided parts**, written for someone who has a research question and needs to know
what to set, in what order, what to look at, and how to recognise a result that
cannot be trusted. Chapter 13 takes the fertility model on its own, in a single
stable population, which is the setting in which one parameter at a time can be
moved and the effect read off. Chapter 14 takes the kinship model, its options and
its output. Both are being written, and both carry notes marking what is still
missing.

The [appendices](#16-appendices) provide a parameter glossary, the key constants, a
source-module map, and the list of open questions.

---

## 2. Installation and building

### 2.1 Requirements

To build KinFert from source you need:

- **Lazarus** (which bundles the **Free Pascal Compiler, FPC**). *`[TODO: confirm the
  exact Lazarus and FPC versions you build with; this is important for
  reproducibility and should be stated here and in the README.]`*
- The **LCL** package (ships with Lazarus).
- The **TAChartLazarusPkg** package (ships with Lazarus; provides the charts on
  the Graphs window).

The project file declares exactly these two required packages
(`TAChartLazarusPkg`, `LCL`).

### 2.2 Getting the source

The repository contains the Pascal units (`*.pas`), the Lazarus form files
(`*.lfm`), and the project files (`kinfert.lpi`, `kinfert.lpr`). Compiled
binaries and build artifacts are **not** stored in the repository; see
[§2.5](#25-running-the-prebuilt-binaries).

### 2.3 Building in the Lazarus IDE

1. Open **`kinfert.lpi`** in Lazarus.
2. Make sure the required packages are installed (Lazarus will prompt if
   `TAChartLazarusPkg` is missing).
3. Choose **Run ▸ Build** (or **Compile**).

The compiler writes unit output to `lib/$(TargetCPU)-$(TargetOS)/` and produces an
executable named **`KinFert`**.

### 2.4 Compiler options used

The project is configured (in `kinfert.lpi`) with:

- Optimisation level **0** and **DWARF 3** debug info, i.e. a *debug* build.
- Range checking (`-Cr`), I/O checking (`-Ci`) and overflow checking
  (`-Co`, `-CO`), and assertions (`-Sa`) **enabled**. These catch many errors at
  run time and are valuable while debugging; a release build would normally turn
  them off for speed.
- The conditional define **`LAZARUS_GUI`**.

*`[TODO: decide and document a separate "release" build mode for distribution
(optimisation on, range/overflow checks off), so published binaries run at full
speed.]`*

### 2.5 Running the prebuilt binaries

Prebuilt executables exist for **macOS** (the `KinFert` binary and the
`KinFert.app` bundle) and **Windows** (`KinFert.exe`). For publishing, these
should be distributed as **release downloads**, not committed to the source
repository (they are large). *`[TODO: when publishing, attach the macOS and
Windows binaries to a GitHub Release and note here which OS versions/architectures
they target, e.g. Apple Silicon vs Intel.]`*

### 2.6 Configuration and output directories

On first use you tell KinFert two folders:

- a **configuration directory**, where configuration (command) files are kept, and
- an **output directory**, where results are written.

Both are chosen in the interface, the first by reading a configuration file and the
second with the **Output directory** button on the main window
([§3.1](#31-the-main-window-control-by-control)). KinFert then remembers them from
one session to the next in two small text files of one line each, which it writes
itself, **`ConfigDir`** and **`OutputDir`**, with the extension `.cfg` and the name of
the system in between.

> **These two files are the program's own state.** You do not need to create them,
> and you should not edit them: the program rewrites each one every time the
> corresponding folder is chosen. A fresh installation has neither, which is normal.

Each system keeps them in the folder it sets aside for an application's per-user
state, and the name of each file says which system wrote it. The paths inside are
specific to the machine, so a file written on one system means nothing on another, and
the names keep the two apart even when the folder itself is shared:

| System | Files |
|---|---|
| macOS | `~/Library/Application Support/KinFert/ConfigDir-macOS.cfg` and `OutputDir-macOS.cfg` |
| Windows | `%APPDATA%\KinFert\ConfigDir-Windows.cfg` and `OutputDir-Windows.cfg` |
| other Unix | `$XDG_CONFIG_HOME`, or `~/.config` when it is unset, then `KinFert/ConfigDir-Linux.cfg` and `OutputDir-Linux.cfg` |

Before 1 October 2026 both files sat next to the program instead, under the names
`KinFert ConfigDir.cfg` and `KinFert OutputDir.cfg`, which on macOS put them inside
the application bundle. If you have used an earlier version, its two files are still
there: the first run of a later version reads them, writes the new ones, and from then
on uses only the new ones. You do not have to move anything, and the two old files can
be deleted once you have made one run.

### 2.7 Platform notes

KinFert is developed on macOS (Apple Silicon) and also built for Windows. Paths in
configuration files are platform-specific; a config saved on one OS may need its
paths adjusted on another.

---

## 3. Getting started: the main window

When KinFert starts, the **main window** (titled *Kinfert*) is your control
centre. From here you load or edit a configuration, choose where output goes, run
the simulation, and inspect results.

### 3.1 The main window, control by control

![KinFert main window](img/main-window.png)

*The main window: load or build a configuration, choose the output directory, run, and read results.*

| Control | On-screen label | What it does |
|---|---|---|
| `ChooseConfigButton` | **Read config file** | Load a saved configuration (a set of simulation parameters) from a file. The chosen file name appears in `ConfigFileName`. |
| `ConfigFileName` | *(label, shows "none")* | The currently loaded configuration file. |
| `OutputDirButton` | **Output directory** | Choose the folder where results are written. Shown in `OutputDirName`. |
| `OutputDirName` | *(label, shows "none")* | The current output directory. |
| `createConfigFile` | **Edit config** | Open the [Config window](#4-configuring-a-simulation-the-config-window) to enter or edit parameters. |
| `runSimul` | **run simulation** | Run the simulation with the current parameters. |
| `status` | **status** | Shows what the program is doing. |
| `Log` | *(memo)* | The running log of the simulation. |
| `GraphsBtn` | **Graphs** | Open the [Graphs window](#7-graphs). |
| `Reset_nRuns` | **Reset run count** | Reset the count of completed simulations (useful before drawing graphs). |
| `SaveOutput` | **Save output log** | Save the contents of the log to a file. |
| `UtilesBtn` | **Debug** | Open the *Utiles* window of debug options (mainly for internal debugging). |
| `errorShape` + `errorStatusLab` | **error status:** | The shape turns **red** if the last run produced errors. |
| `ProgressBar`, `ZipLab` | *(progress bars)* | Run progress and ZIP-compression progress. |
| `VersionString` | *(label)* | The program version. |
| `QuitBtn` | **Quit** | Exit the program. |
| Menu **File** | *Open Config File…*, *Quit* | Same as the buttons above. |

### 3.2 The basic workflow

1. **Read config file** (load an existing configuration) **or** click **Edit
   config** to build one from scratch.
2. Click **Output directory** and choose where results should go.
3. Optionally open **Edit config** to review or change parameters and select
   outputs.
4. Click **run simulation**. Watch **status**, the **Log**, and the progress bar.
5. When it finishes, check the **error status** indicator, open **Graphs**, and/or
   **Save output log**. Results files are written to the output directory.

> **Tip.** If you intend to compare runs on the **Graphs** window, use **Reset run
> count** between independent experiments.

---

## 4. Configuring a simulation: the Config window

The **Config** window is where a simulation is defined. It is organised into
groups; this chapter follows those groups. For each option the tables give the
**label** you see, the **internal name** (useful when reading or editing a
configuration file, see [§10.1](#101-configuration-command-file)), and its
meaning.

![The Config window](img/config-overview.png)

*The Config window, where a simulation is defined.*

### 4.1 Top-level actions

| Button / option | Label | What it does |
|---|---|---|
| `writeConfigFile` | **Save config file** | Save the current parameters to a configuration file. |
| `readConfigFile` | **Read config file** | Load parameters from a file. |
| `DefaultValues` | **Reset to default** | Reset every parameter to its built-in default. |
| `Cancel` | **Ok** | Close the window, keeping the current values. |
| `CommentBtn` | **Documentation** | Open the free-text [Documentation](#411-config-info-and-output-file-naming) note stored with the configuration. |
| `WRITE_ONLY_CHANGES` | **Save only non-default values** | When saving, write only the parameters that differ from the defaults (shorter, more readable files). |
| `DUMPALL` | **Write detailed config file** | When saving, write a fully detailed configuration (all values, including internal ones). |
| `NO_CHANGES_SHAPE` | *(indicator)* | Shows whether the configuration differs from the defaults. |

### 4.2 Model type

Two independent switches decide *what* is simulated:

| Option | Label | Meaning |
|---|---|---|
| `FERTILITY` | **Fertility** | Simulate fertility (reproductive life histories). |
| `KINSHIP` | **Kinship** | Simulate kinship networks (requires the fertility machinery underneath). |

### 4.3 Cohorts

![Config window: cohort settings](img/config-cohorts.png)

A run covers either a single birth cohort or a range.

| Option | Label | Meaning |
|---|---|---|
| `FIRST_COHORT` | **First** | First birth cohort (year) simulated. |
| `LAST_COHORT` | **Last** | Last birth cohort simulated. |
| `STEP_COHORT` | **Step** | Step between cohorts (e.g. every 5 years). |
| `COHORTS` | **Cohort** | Selects the cohort whose demographic regime you are currently editing. |
| `ReadCohortFile` | **Read Cohorts** | Read a file giving data for several cohorts (a multi-cohort demographic regime). |
| `CohortsFilename` | *(label)* | The cohort file currently loaded. |
| `CreateCohortFile` | **Create cohort file** | Write a cohort file pre-filled with default values for the current cohort. |
| `DUMPALLCOHORTS` | **Write complete cohort file** | Write the full set of cohorts (not only changed values). |
| `DETAILED_COHORT_DATA` | **Write detailed cohort data** | Include detailed per-cohort data in the file. |

When several cohorts are simulated, each can have its own **demographic regime**
(its own fertility, nuptiality and mortality parameters), supplied through the
cohort file. See [§10.2](#102-cohort--demographic-regime-data-file).

### 4.4 Mortality

![Config window: Mortality group](img/config-mortality.png)

| Option | Label | Meaning |
|---|---|---|
| `LIFE_EXPECTANCY_AT_BIRTH_WOMEN` | **e0 women** | Female life expectancy at birth, *e₀*. |
| `LIFE_EXPECTANCY_AT_BIRTH_MEN` | **e0 men** | Male life expectancy at birth, *e₀*. |

Mortality is applied through survival schedules derived from these life
expectancies (see [§8.4](#84-mortality)).

### 4.5 Union fertility (a priori)

![Config window: Union fertility, a priori](img/config-fertility-apriori.png)

This group defines the *target* fertility of a union before contraceptive
behaviour is applied.

| Option | Label | Meaning |
|---|---|---|
| `PPR_TARGET` | **PPR values as target** | Treat the a-priori PPRs as a target the simulation must reproduce (the program iterates to hit them). |
| `APRIORI_PPR` | *(value list)* | The a-priori parity progression ratios by parity. |
| `CTFR` | **CTFR** | Completed total fertility implied/targeted for the union. |
| `NSTEP_CONTRACEPTION` | **Contraception steps** | Number of iteration steps used when fitting contraception to the fertility target. |

### 4.6 Contraception use

![Config window: Contraception use](img/config-contraception.png)

| Option | Label | Meaning |
|---|---|---|
| `EFF_CONTRACEP_BEFORE_UNION` | **Efficacy before first union** | Effectiveness of contraception used before the first union. |
| `CONTRACEP_TIME_AFTER_FIRST_UNION` | **Length of time (years)** | Duration of contraceptive use after the first union (before the first wanted birth). |
| `PROP_CONTRACEP_AFTER_FIRST_UNION` | **Prop. waiting** | Proportion of couples who wait (use contraception) after the first union. |
| `NSTEP_CONTRACEP_BEFORE_FIRST_CHILD` | **NSteps** | Iteration steps for contraception before the first child. |
| `EFF_STOPPING_CONTRACEP` | **STOPPING** *(value list)* | Effectiveness of contraception used to *stop* childbearing, by parity. |
| `PROP_USING_SPACING` | **SPACING** *(value list)* | Proportion of couples using contraception to *space* births, by interval. |
| `WAITING_TIME_SPACING` | **WAITING TIME** *(value list)* | Waiting time associated with spacing, by interval. |

*Spacing* lengthens the interval to the next birth; *stopping* ends childbearing
altogether. See [§8.2](#82-fertility).

### 4.7 Amenorrhea

![Config window: Amenorrhea group](img/config-amenorrhea.png)

Postpartum amenorrhea is modelled with the **Lesthaeghe–Page** formulation.

| Option | Label | Meaning |
|---|---|---|
| `AMENO_ALPHA` | **Alpha** | α parameter of the Lesthaeghe–Page amenorrhea model. |
| `AMENO_BETA` | **Beta** | β parameter of the Lesthaeghe–Page amenorrhea model. |
| `NSTEP_AMENORRHEA` | **NSteps** | Iteration steps for the amenorrhea fit. |
| `FIXED_AMENORRHEA` | **Same duration of amenorrhea for all** | Use a single fixed amenorrhea duration for every woman instead of the model. |
| `ZERO_FIXED_AMENORRHEA_` | **Duration amenorrhea** | The fixed amenorrhea duration (used when the box above is ticked). |

### 4.8 Nuptiality (unions)

![Config window: Union (nuptiality) group](img/config-nuptiality.png)

**Women: first union**

| Option | Label | Meaning |
|---|---|---|
| `MEAN_AGE_UNION` | **Age first union** | Mean age at first union (women). |
| `STD_DEV_AGE_UNION` | **Std dev** | Standard deviation of age at first union. |
| `EVER_INUNION_PROP` | **Prop. ever in union** | Proportion of women ever entering a union. |
| `MEAN_AGE_UNION_HIGH`, `EVER_INUNION_PROP_HIGH` | **Max value** | Upper values used when a parameter is varied across its range. |

**Men: first union**

| Option | Label | Meaning |
|---|---|---|
| `MEAN_AGE_UNION_MEN` | **Age first union** | Mean age at first union (men). |
| `EVER_INUNION_PROP_MEN` | **Prop. ever in union** | Proportion of men ever entering a union. |

**Separation, second unions, widowhood**

| Option | Label | Meaning |
|---|---|---|
| `SEPARATION` | **Frequency separation** | Frequency (risk) of union separation. |
| `SECOND_SEPARATION_REL_RISK` | **2nd Sep. Rel. Risk** | Relative risk of separation for second and later unions. |
| `SEPARATION_ADJUSTED` | **Iteration value** | The separation frequency after iterative adjustment (an *adjusted value*). |
| `REPARTNERING_WOMEN`, `REPARTNERING_MEN` | **Freq women / Freq men** (Separ.) | Repartnering frequency after **separation**, by sex. |
| `REPARTNERING_WID_WOMEN`, `REPARTNERING_WID_MEN` | **Freq women / Freq men** (Widow.) | Repartnering frequency after **widowhood**, by sex. |

**Switches and iteration steps**

| Option | Label | Meaning |
|---|---|---|
| `FIXED_AGE_UNION` | **Same age at union for all women and all men** | Give everyone the same age at union (disables the age distribution). |
| `SEP_TARGET` | **Separation freq. as target** | Treat the separation frequency as a target to reproduce by iteration. |
| `NSTEP_UNION_MEAN`, `NSTEP_UNION_PROP`, `NSTEP_UNION_STDDEV` | **NSteps** | Iteration steps when varying mean age, proportion ever, and standard deviation. |
| `NSTEP_SEPARATION` | **NSteps** | Iteration steps for separation. |

### 4.9 Egos and sex ratio at birth

| Option | Label | Meaning |
|---|---|---|
| `NEGO` | **Number of Egos in the Kinship model** | How many egos to simulate (the sample size of the kinship study). |
| `PROP_WOMEN_AT_BIRTH` | **P. women at birth** | Proportion of girls among births (the complement of the sex ratio at birth). |

### 4.10 Education

| Option | Label | Meaning |
|---|---|---|
| `EDUCATION` | **EDUCATION** *(combo)* | Selects the education-status model: **None**, **Stochastic**, **Observed by cohort**, **Observed, with family** or **Stochastic, with family**, which are values 0 to 4 in a configuration file. |

The status is one of three levels, **B**, **M** and **A**, from the lowest to the
highest. The mode answers two questions at once, where the level comes from and
whether the family counts; [§8.5](#85-education) sets them out and says what each
mode needs as input. Writing a DemoCare individual file with the mode set to **None**
would leave its status column empty, so the program moves it to **Stochastic, with
family**, the mode that needs no input and still makes the members of a family
resemble one another, and says so in the log.

### 4.11 Config info and output file naming

| Option | Label | Meaning |
|---|---|---|
| `FILENAME` | **Root of output files name** | Base name used for all output files of the run. |
| `DEM_REG_FILENAME` | **File name for cohorts** | Name of the demographic-regime (cohort) file. |
| `BOOTSTRAP_NRUNS` | **Boostrapping** | Number of bootstrap repetitions (1 = a single run). |
| `OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES` | **Mult. files** | Write a separate individual-data file per bootstrap replicate. |
| `DOCUMENTATION` | *(memo, via **Documentation** button)* | A free-text note saved with the configuration. |

### 4.12 Model options and other options

| Option | Label | Meaning |
|---|---|---|
| `INIT_RANDOM_NUMBERS` | **Same Random Sequence** | Re-seed the generator identically each run, so results are reproducible. |
| `FIXED_FERTILITY` | **Fixed fertility** | Use a fixed fertility level instead of the full model. |
| `FIXED_FERTILITY_VALUE` | *(combo)* | The fixed fertility level to use. *`[TODO: list the available values.]`* |
| `LowLevelOptions` | **Low Level Options** | Open the [LowLevel window](#5-low-level-biological-options-the-lowlevel-window). |
| `OutputOptions` | **Output Options** | Open the [Outputs window](#6-outputs-the-outputs-window). |

---

## 5. Low-level (biological) options: the LowLevel window

The **LowLevel** window holds the biological and performance options that most
users leave at their defaults. It is reached from **Low Level Options** on the
Config window.

![The LowLevel window](img/lowlevel-window.png)

*The LowLevel window: advanced biological and performance options.*

### 5.1 Fecundability

These choose how *fecundability* (monthly conception probability) varies between
women. *`[TODO: confirm these are mutually exclusive, i.e. whether they behave as a radio
choice of fecundability model.]`*

| Option | Label | Meaning |
|---|---|---|
| `HOMOGENEOUS_FECUNDABILITY` | **Homogeneous fecundability** | Every woman has the same fecundability (no heterogeneity). |
| `RESHUFFLED_FECUNDABILITY` | **Relative fecundability level change for each interval** | A woman's relative fecundability is redrawn for each birth interval. |
| `NORMAL_HETEROGENEITY_FECUNDABILITY` | **Relative fecundability level follows a Gauss or a Beta law** | Relative fecundability is drawn from a Gaussian or Beta distribution. |

### 5.2 Sterility

These choose the age pattern of permanent sterility.

| Option | Label | Meaning |
|---|---|---|
| `LERIDON_STERILITY` | **Leridon (2008) Sterility by age model** | Use Leridon's 2008 age schedule of sterility. |
| `KINFERT_STERILITY` | **KINFERT Sterility by age model** | Use KinFert's own age schedule of sterility. |
| `NO_INITIAL_STERILITY` | **Sterility null up to age 25** | Force zero sterility below age 25. |
| `FIXED_DEFINITIVE_STERILITY` | **Sterility constant from its level at age 25 up to age:** | Hold sterility constant at its age-25 level up to the age set below. |
| `AGE_FIXED_DEFINITIVE_STERILITY_` | *(age edit)* | The age up to which sterility is held constant. |

### 5.3 Kinship base numbers

| Option | Label | Meaning |
|---|---|---|
| `NUMBER_WOMEN` | **Number of mothers / brides for the kinship model** | Size of the pool of women (potential mothers/brides) used by the backward kinship algorithm. |
| `MODEGO` | **modEgo (for showing current count of ego trees)** | How often (every *modEgo* egos) the running count of ego trees is reported. |
| `OPTIMAL_TREES` | **Optimal number of trees per thread in multithreading** | Target number of ego trees per worker thread. |

### 5.4 Fertility iteration controls

| Option | Label | Meaning |
|---|---|---|
| `FORCE_PPR_TARGET` | **Force computation of Fertility PPR target iterations** | Always run the PPR-target iteration even when it might be skipped. |
| `USE_ARRAY_CHILDREN` | **use ARRAYCHILDREN data structure** | Use the array-based children data structure (a performance/representation choice). |
| `FORCE_SEP_ITER` | **Force computation of separation iterations** | Always run the separation-adjustment iteration. |

---

## 6. Outputs: the Outputs window

The **Outputs** window selects which results are produced. It is reached from
**Output Options** on the Config window. The **All / none** button toggles a
whole section at once.

![The Outputs window](img/outputs-window.png)

*The Outputs window: selects which results are produced.*

### 6.1 Fertility result tables

| Option | Label | Produces |
|---|---|---|
| `GENERAL_FERTILITY` | **General Fertility** | General fertility summary. |
| `INTERVAL_TABLE` | **Interval Table** | Birth-interval table. |
| `INTERVAL_CONCEPTION_UNION_TABLE` | **Intervals conc. union** | Intervals from union to conception. |
| `LAST_BIRTH` | **Last birth** | Distribution of age at last birth. |
| `DURATION_TABLE` | **Duration table** | Durations table (since previous event). |
| `PARITY_AGE_TABLE` | **Parity by age** | Parity distribution by age. |
| `REPARTNERING_STATE_TABLE` | **Repartnering state** | Repartnering states. |
| `COHORT_TFR` | **Cohort TFR** | Completed (cohort) total fertility. |
| `AGE_CHILDBEARING` | **Age at childbearing** | Mean age at childbearing. |
| `COHORT_FERTILITY_TABLE` | **Cohort fertility** | Cohort fertility table. |
| `PROP_CELIBACY` | **Proportion single** | Proportion never in union. |
| `NO_FECUNDATION` | **No fecundation** | Women who wanted but did not achieve a conception within set durations. |
| `DUMP_UNION_TABLE` | **Dump union table** | Raw dump of the union table. |
| `INUNION_STATE_TABLE` | **Union states** | Distribution of union states. |
| `FERTILITY_BY_UNION_DURATION` | **Fertility by union duration** | Fertility rates by union duration. |
| `FERTILITY_BY_UNION_STATUS` | **Fertility by union status** | Fertility rates by union status. |
| `PPRS_BY_UNION_STATUS` | **PPRs by union status** | Parity progression ratios by union status. |
| `PARITY_BY_AGE_AT_UNION` | **Parity by age at first union** | Parity by age at first union. |

### 6.2 Individual fertility microdata

| Option | Label | Meaning |
|---|---|---|
| `OUTPUT_INDIVIDUAL_FERTILITY_INFO` | **Individual results (microdata file)** | Write one record per simulated woman. |
| `OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED` | **Extended file** | Add the extended set of fields. |
| `OUTPUT_EXCLUDE_ABORTION` | **Exclude abortion** | Omit spontaneous abortions/stillbirths from the file. |
| `OUTPUT_AGGREGATE_FERTILITY` | **Aggregate results for fertility** | Also write aggregate fertility results. |
| `OUTPUT_FERT_SURVEY` | **Fertility survey** | Emit a synthetic "survey" extract; `FERT_SURVEY_MIN`/`FERT_SURVEY_MAX` set the **Age min/max**. |

### 6.3 General output options

| Option | Label | Meaning |
|---|---|---|
| `OUTPUT_INDIVIDUAL_AGE_FLOAT` | **Ages in individual file show in float** | Write ages as decimals rather than integers. |
| `FLOATING_POINT_PRECISION` | **Numbers: precision** | Floating-point precision in output. |
| `FLOATING_POINT_DIGITS` | **Numbers: digits** | Number of digits shown. |
| `OUTPUT_MAXNUMUNION` | **Output: max unions** | Maximum number of unions written per individual. |
| `OUTPUT_MAXNUMBIRTHS` | **Output: max births** | Maximum number of births written per individual. |
| `ZIP_INDIVIDUAL` | **Compress (ZIP) microdata files** | ZIP the (potentially large) microdata files. |
| `SAVE_LOG` | **Save output log at the end of simul.** | Automatically save the log when the run ends. |
| `WRITE_FOLDER` | **Write results in folder** | Write results into a dedicated sub-folder. |
| `WRITE_ADJUSTED_VALUES` | **Write adjusted values (fert. & sep.)** | Write the iteratively adjusted fertility and separation values. |

### 6.4 Kinship outputs

| Option | Label | Produces |
|---|---|---|
| `OUTPUT_INDIVIDUAL_KINSHIP_INFO` | **Individual results (microdata file)** | One record per kin; `KINSHIP_INDIV_FORMAT` sets the **File format**. *`[TODO: list the available formats.]`* |
| `KIN_STATISTICS` | **Kin Statistics** | Summary statistics on kin. |
| `KIN_FATHERS_SONS` | **Ages Fathers and Sons** | Ages of fathers and sons. |
| `KIN_DISTRIBUTION` | **Kin Distribution** | Distribution of kin by type. |
| `KIN_RELATIVE_DISTRIBUTION` | **Kin Relative Distribution** | Relative distribution of kin. |
| `KIN_AGE_DISTRIBUTION` | **Kin Age Distribution** | Distribution of kin by age. |
| `NUM_KIN_AGE` | **Nb of kins by age of ego** | Number of kin by age of ego. |
| `UNION_TABLE` | **Union life table** | Union life table. |
| `KIN_TOTAL_NUMBERS` | **Total number of kins** | Totals across kin types. |
| `OUTPUT_AGGREGATE_KINSHIP` | **Aggregate results by age of Ego** | Aggregate kin results by age of ego. |
| `KinSelectionBtn` | **Select kin to simulate** | Choose which kin types to simulate (see [§9](#9-kin-taxonomy-reference)). |
| `optionalFieldsBtn` | **Select optional fields in output file** | Choose the optional per-kin fields (see [§6.4.1](#641-optional-per-kin-fields)). |

#### 6.4.1 Optional per-kin fields

![Select optional fields dialog](img/kin-output-fields.png)

The **Select optional fields** dialog toggles the columns written for each kin in
the kinship microdata file:

Year of birth (integer), Month of birth, Year of birth (float), Number of
children, Birth order, Age difference with ego, Age at death, Age at union(s), Age
at end of union(s), Cause of end of union(s), Age of mother at childbirth, Age of
father at childbirth, Educational status, Demographic-regime cohort, Mother union
index, Share of inheritance (heirs), Heirs, KinType of heirs, Decedents, Share
(decedents), KinType of decedents.

### 6.5 Inheritance

![Outputs window: Inheritance group](img/outputs-inheritance.png)

| Option | Label | Meaning |
|---|---|---|
| `INHERITANCE` | **Find heirs and decedents** | Run the inheritance resolution. |
| `heirsSetBtn` | **Select possible heirs set** | Choose which kin types may be heirs (see below). |
| `decedentsSetBtn` | **Select possible decedents set** | Choose which kin types may be decedents. |
| `PARTNER_DECEDENT` | **Egos' partner can be decedent** | Allow ego's partner to be a decedent. |
| `PARTNER_FIRST_HEIR` | **Partner first heir** | Partner inherits first. |
| `PARTNER_FULL_HEIR` | **Partner full heir** | Partner inherits the whole estate. |
| `COUNTRY_INHERITANCE_RULES` | **Inheritance rules** | Select the national succession rule set. *`[TODO: list the available countries/rule sets.]`* |
| `NON_BIO_KIN` | **Include non bio kin** | Include non-biological kin. |
| `ALL_EGO_PARTNERS_GENEALOGY` | **Simulate egos' partner genealogy** | Also build the genealogy of ego's partner(s). |

![Set of possible heirs dialog (the decedents dialog is identical)](img/heirs-set.png)

The **heirs set** and **decedents set** dialogs offer the same kin-type list:
Partner, Child, Grandchild, Great-grandchild, Father, Mother, Grandfather,
Grandmother, Great-grandfather, Great-grandmother, Sibling, Niece-nephew,
Grand-niece-nephew, Aunt-uncle, First cousin, Grand-aunt-uncle.

### 6.6 Multithreading

| Option | Label | Meaning |
|---|---|---|
| `MULTITHREADING` | **MULTITHREADING** | Master switch for parallel execution. |
| `MULTITHREADING_INIT` | **Init DemReg** | Parallelise demographic-regime initialisation. |
| `MULTITHREADING_INITMOTHERHOOD` | **Init Motherhood** | Parallelise the motherhood initialisation. |
| `MULTITHREADING_SIMKIN` | **Simulate kinship** | Parallelise kinship simulation. |
| `MAX_THREADS` | **Max number of threads** | Upper bound on worker threads. |
| `FORCE_NUM_THREADS` | **Force max number of threads** | Always use the maximum rather than auto-detecting. |
| `BATCH` | **Use batches** | Process egos in batches. |
| `TALKATIVE` | **More feedback in multithreading** | Verbose progress messages while threaded. |

> **Reproducibility note.** Combining multithreading with **Same Random Sequence**
> ([§4.12](#412-model-options-and-other-options)) needs care: thread scheduling can
> change the order in which random numbers are consumed. *`[TODO: confirm how
> per-thread seeding guarantees (or does not guarantee) identical results across
> thread counts.]`*

---

## 7. Graphs

The **Graphs** window (opened from the main window) plots inputs and outputs using
TAChart. It is organised into tabs:

![The Graphs window](img/graphs-window.png)

*The Graphs window and its tabs.*

| Tab | Shows |
|---|---|
| **Child / Groom** | What the pre-simulation built for the kinship reconstruction to draw on, and whether it was enough (see below). |
| **Inputs** | The input schedules currently in effect. |
| **Inputs (variation)** | How inputs vary across the simulated range/cohorts. |
| **Outputs: fertility** | Fertility results from the completed run(s). |
| **Outputs: kinship** | Kinship results from the completed run(s). |

Graphs reflect the runs accumulated since the last **Reset run count**.
*`[TODO: detail exactly which series each tab draws, for the four tabs other than
Child / Groom.]`*

### 7.1 The Child / Groom tab

A relative is not simulated out of nothing: the kinship reconstruction asks the
pre-simulation for one. Two indexes answer. A child, or an ascendant of a child,
asks the **birth index** for a woman who gave birth in the child's own year. A man
asks the **bride index** for a woman who entered a union with a man of his cohort,
at his age at union. This tab describes those two indexes and what was asked of
them.

**Unions produced, by groom cohort.** The number of unions the simulation produced
for each birth cohort of grooms, with the bounds of the index drawn as two vertical
lines. A curve that stays well inside them is the sign to look for. The title says
how many unions, if any, fell outside the index and could not be held at all.

**The pool of mothers, as a map** and **the pool of brides, as a map.** The same two
indexes seen cell by cell, a cell being one cohort by one year of age: the age of
the mother at that birth, or the man's age at union. Three colours, chosen so that
nothing is hidden under anything else:

| Colour | Meaning |
|---|---|
| Blue | The index has candidates in this cell and no search ever used them. This is the part of the pool the run paid for and did not need. |
| Green | The index has candidates here and searches drew from them. The shade says how often. |
| Red | A search asked for this cell and found it empty, so the bride had to be taken from a neighbouring age at union. |

The shade within each colour is on a logarithmic scale, so a cell holding one
candidate is still visible beside one holding ten thousand. The mother map has no
red: the birth index is keyed by the year of the birth alone, so a search that
finds nothing moves to a neighbouring cohort rather than to another cell of the
same column, and that move is counted by cohort instead.

**Three further entries** report, by cohort and by generation, the share of searches
that had to be answered from a cell other than the one asked for.

> **Only the first entry appears in a released build.** The maps and the three search
> reports describe the machinery rather than the population, so they are offered only
> when the program runs from the Lazarus IDE.

---

## 8. The demographic model (methods)

> This chapter explains *how* KinFert generates its results. It is reconstructed
> from the source and is the part most in need of the author's review; passages
> that infer intent are flagged.

### 8.1 Time, ages and the lunar-month clock

KinFert advances in **lunar months**, 12 per year (`kNbLunarMonths = 12`).
Reproductive events (conception, pregnancy, amenorrhea, intervals) are counted in
lunar months and converted to years for reporting. The age bounds built into the
program are:

| Quantity | Constant | Range |
|---|---|---|
| Life span | `kMinAgeLife … kMaxAgeLife` | 0 – 130 |
| Reproductive ages | `kMinAgeFert … kMaxAgeFert` | 10 – 59 |
| Ages at union | `kMinAgeUnion … kMaxAgeUnion` | 10 – 79 |

(See [Appendix B](#appendix-b-key-constants) for the full list.)

### 8.2 Fertility

A woman's reproductive life is simulated month by month inside her union history.
The core of each interval is a **conception → pregnancy → birth → postpartum
amenorrhea → return to susceptibility** cycle, recorded per child in the
`InfoChildType` structure (month of fecundation, month pregnancy ends, month of
the next ovulation, birth order, ages of mother and father, and, for a
spontaneous abortion or stillbirth, a non-positive age at death).

The biological and behavioural ingredients are:

- **Fecundability**: the monthly conception probability. It can be homogeneous
  across women, vary by drawing a relative level from a Gaussian/Beta law, or be
  reshuffled each interval (the choices in [§5.1](#51-fecundability)). Each woman
  carries an age schedule of fecundability and a relative level
  (`FecundLifeType.levelFecundabilityAge`, `.relativeFecundabilityLevel`).
- **Sterility**: a per-woman age of permanent sterility
  (`FecundLifeType.ageSterile`) drawn from the selected age schedule
  (Leridon 2008, KinFert's own, optionally zero before 25, optionally held
  constant after 25, see [§5.2](#52-sterility)).
- **Postpartum amenorrhea**: the non-susceptible interval after a birth, from the
  **Lesthaeghe–Page** model with parameters α (`AMENO_ALPHA`) and β
  (`AMENO_BETA`), or a single fixed duration.
- **Contraception**: couples may use contraception **before** the first union,
  **after** the first union before the first wanted birth, to **space** births,
  and to **stop** childbearing. Spacing lengthens intervals (with a waiting time);
  stopping ends childbearing once desired family size is reached (the `stopping`
  flag in `FecundLifeType`).

The *a-priori* fertility of a union is built from the **parity progression
ratios** (`APRIORI_PPR`): the program computes an a-priori distribution of
completed family size from the PPRs and the associated **CTFR**. When **PPR values
as target** (`PPR_TARGET`) is set, the program *iterates* (over `NSTEP_…` steps)
on contraceptive parameters until the simulated PPRs reproduce the target; the
fitted values are stored as **adjusted values** (see
[§8.8](#88-targets-iteration-and-adjusted-values)).

*`[TODO: confirm the conception model (e.g. whether intra-uterine mortality and
the waiting-time-to-conception distribution are Erlang/Poisson; the option
"waitingTimeErlangPoisson" exists in the code), and the exact role of the
"spacing/stopping/waiting-time" value lists.]`*

### 8.3 Nuptiality

Unions are governed by `NuptialitySettings` and `separationSettings`:

- **Entry into first union**: driven by the **mean age at union**, its **standard
  deviation**, and the **proportion ever in union**, separately for women and men.
  Setting **Same age at union for all** (`FIXED_AGE_UNION`) collapses the age
  distribution to a single value. A cross-tabulation
  (`union_women_men` / `union_men_women`) matches the ages of brides and grooms.
- **Separation**: a monthly separation risk built from a median and shape
  parameter (`separation_median`, `separation_shape`) and an overall frequency
  (`freqSeparation`); second and later unions carry a **relative risk**
  (`SECOND_SEPARATION_REL_RISK`), and the risk also depends on the number of
  children and the union duration.
- **Repartnering**: after **separation** and after **widowhood**, with
  sex-specific frequencies and a duration profile (`prop_repartnering*`). The code
  notes a log-logistic form. *`[TODO: confirm the repartnering hazard shape and the
  remark in the code that risk depends on age rather than time since
  separation/widowhood.]`*

When **Separation freq. as target** (`SEP_TARGET`) is set, the separation
frequency is fitted by iteration and the result stored as `SEPARATION_ADJUSTED`.

### 8.4 Mortality

Mortality is applied through survival schedules (`mortalitySettings.survival_men`,
`.survival_women`) derived from the life expectancies **e₀ women** and **e₀ men**.
Adult survival over the union ages is held separately for efficiency.
*`[TODO: state which model life-table family or formula maps e₀ to the survival
curve.]`*

### 8.5 Education

Each individual receives an **education status**, one of three levels written as a
single letter: **B** for the lowest, **M** for the middle, **A** for the highest.
The letters are the initials of the Spanish words and the mapping is in `eduLevel`
in `EducationalLevel.pas`. The same three letters are used by every mode, so the
status column of an output file means the same thing whichever mode produced it.

**Two questions, asked separately.** The mode is a choice on two axes, and reading it
as one list of four is what makes it hard to remember.

The first question is *where the level comes from*: from the three levels with equal
chances, which needs no input at all, or from the distribution observed for that
person's own birth cohort and sex, which has to be supplied in the cohort file.

The second is *whether the family counts*: either every person is drawn on their own,
so that no two members of a family are related in any way, or a person's level is
drawn in the light of the levels already in the family, so that children resemble
their parents and partners resemble each other.

The four combinations are the four modes:

| | the family does not count | the family counts |
|---|---|---|
| **equal chances** | 1, *Stochastic* | 4, *Stochastic, with family* |
| **observed levels** | 2, *Observed by cohort* | 3, *Observed, with family* |

and 0, *None*, assigns nothing at all. The numbers are what a configuration file
carries, and the order of the list on screen follows them.

| Value | On screen | What it does | What it needs |
|---|---|---|---|
| 0 | **None** | No status is assigned. Every person carries an empty status, and the status column of an individual file is empty. | nothing |
| 1 | **Stochastic** | One of the three levels with probability one third each, drawn independently for every person. | nothing |
| 2 | **Observed by cohort** | The level is drawn from the distribution observed for that person's own birth cohort and sex, independently for every person. | the `EDU_<level>_<sex>` distributions, by cohort, in the cohort file |
| 3 | **Observed, with family** | The same observed distributions, with the family taken into account. A person whose parents are both in the network is drawn from the distribution of children of parents with those two levels; a partner is drawn from the distribution of partners of a person of that level; a person at the top of a line of descent, whose parents the network does not carry, falls back to mode 2. | the `EDU_`, `EDUPARTNER_` and parent-to-child distributions, by cohort, in the cohort file |
| 4 | **Stochastic, with family** | With probability one half a person takes a level already in the family, and otherwise one of the three levels with equal chances. The level taken is the partner's for a partner, and the level of one of the two parents, chosen at random, for a person whose parents are both in the network. | nothing |

Modes 2 and 3 were called *Individual* and *Intrafamily* on screen before 1 October
2026. The values in a configuration file have not changed.

**What mode 4 does and does not claim.** Its marginal distribution is exactly one
third at each level, in every generation and whatever the correlation, since copying
a level that is uniform and drawing one with equal chances both give a uniform level.
It therefore adds association inside families and changes nothing else, and any
departure from a third in the totals of a run is sampling noise. With the correlation
at one half, a child carries the level of one of its parents two times in three,
against one time in three when the draws are independent. The correlation between
partners is weaker than the one between parent and child, because a person's parents
are always given a level before the person while a partner is not: when the partner
is reached first there is nothing to copy and the level is drawn with equal chances.
The strength of the association is the constant `kEduFamilyCorrelation` in
`Declarations.pas`, one half, and it is a constant rather than a parameter because
the mode exists to give a file a plausible family structure rather than to reproduce
a measured association.

**With no cohort file**, or with one that carries no `EDU_` columns, modes 2 and 3
have nothing to draw from: they report a failed check and leave the status empty.
Modes 1 and 4 need nothing and always work.

Status is assigned once the kin network is complete, by `giveEdStatus`, which gives
the parents of a person a status before the person, so that the intrafamily mode
always has the two parental levels in hand.

> **DemoCare files.** The `status` column of a DemoCare individual file is this
> educational level. A run that writes one with `EDUCATION` set to **None** would
> leave the column empty in every row, so the program sets the mode to **Stochastic**
> in that case and says so in the log. A mode you have chosen yourself is never
> overridden.

### 8.6 The kinship algorithm

To give an **ego** a complete kin network, KinFert combines forward and backward
simulation:

1. **Backward (ancestors).** Ego is generated by a **possible mother** drawn from
   a pool of women (`NUMBER_WOMEN`); that mother is in turn generated by a
   **possible grandmother**. The program reconstructs ancestors **upward for two
   generations** (parents and grandparents), as described in the header of
   `Kinship.pas`. Several variants of this backward step exist,
   `gBACKFOR_mode`, `gCAMSIM_1987`, `gCAMSIM_1993` (and an *unbounded* 1993
   variant), reflecting the **BACKFOR** and **CAMSIM** lineages of kinship
   microsimulation.
2. **Forward (descendants).** Each woman's reproductive life (§8.2) produces her
   children; iterating the fertility process over generations yields grandchildren
   and great-grandchildren.
3. **Collaterals.** Siblings, aunts/uncles, cousins, nieces/nephews, etc. are
   obtained from shared ancestors (e.g. ego's grandmother's other descendants).

The result is, per ego, a genealogical tree of `RelativeType` nodes linked by
`father`/`mother` and sibling pointers, each tagged with a `KinTypes` value
(see [§9](#9-kin-taxonomy-reference)). Diagnostic **state arrays**
(`gStateChildren`, `gStateGrooms`) track the span of birth years and grooms' ages
actually accessed, so you can check that the configured year ranges are wide
enough (this is what the **Child/Groom** graph tab shows).

The algorithm that chooses a reference child's mother is selected by
`MOTHER_ALGORITHM`, whose default is KinFert's own; the four alternates exist so
that the five can be run on one configuration and compared. The five are listed in
[§14.6](#146-the-backward-algorithm-and-when-the-choice-matters).
*`[TODO: summarise, in demographic terms, how BACKFOR, BACKFOR_MIXED, CAMSIM-1987
and CAMSIM-1993 differ from the KinFert algorithm.]`*

### 8.7 Inheritance

When **Find heirs and decedents** (`INHERITANCE`) is on, KinFert resolves, for each
ego, who inherits from whom and in what share, restricted to the chosen **heirs
set** and **decedents set** ([§6.5](#65-inheritance)) and according to the selected
**country rules**.

The model distinguishes a relative who **is** an heir (alive at the decedent's
death, with a positive `share`) from one who died earlier but whose own heirs
receive the share (`inheritanceType.isHeir`, `.degree`, `.nLivingSiblings`,
`.share`). Two algorithms coexist: a first one with complete information only for
ego, and a second that attempts full heir resolution for all relatives with a
complete tree (`heirs_2`, `inheritances_2`). The partner can be given priority
(**Partner first heir**) or the whole estate (**Partner full heir**).
*`[TODO: document each country rule set and the share formula.]`*

### 8.8 Targets, iteration and adjusted values

Most entries of a demographic regime are *a priori* values: the simulation applies
them as they are given. Two of them can instead be read as **targets**, that is as
properties the finished cohort should reproduce. The program then searches for the
a priori value that produces the requested result, and the value it settles on is
called an **adjusted value**.

A search is needed because the quantity asked for and the quantity the model
consumes are not the same thing. A parity progression ratio describes a completed
reproductive life. What the model acts on, month by month, is contraceptive
behaviour. Between the two lie sterility, the waiting time to conception,
postpartum amenorrhea, union formation and dissolution, and mortality, each of
which keeps some women from a birth that the ratios alone would have given them. A
set of ratios used directly as behaviour therefore produces a cohort with fewer
children than the ratios describe, so the a priori behaviour has to be placed above
the target to compensate. The same argument applies to separation, since unions are
also ended by death.

| Target | Switch | What is compared | Adjusted value | Limit | Tolerance |
|---|---|---|---|---|---|
| Parity progression ratios | `PPR_TARGET` | the cohort total fertility implied by the simulated ratios, against the one implied by `APRIORI_PPR` | `ADJUSTED_PPR` | 4 passes | 0.01 children |
| Proportion separating | `SEP_TARGET` | the simulated proportion of first unions ending in separation, against `SEPARATION` | `SEPARATION_ADJUSTED` | 20 trials | 0.003 in absolute terms, or 1.5 per cent in relative terms |

> **The `NSTEP_` fields are not the iteration counts of these searches.** They set
> how many values a parameter takes when a run sweeps it across a range
> ([§13.5](#135-sweeping-parameters-over-a-range-of-steps)). Each search has its own
> fixed limit, given in the table above. The one place where a sweep and a target
> meet is contraception, as described in the next section.

#### 8.8.1 The parity progression ratio target

**The three sets of ratios.** For each cohort the program keeps three arrays with
one value per parity side by side:

| Array in the source | Configuration name | Meaning |
|---|---|---|
| `aPrioriPPR` | `APRIORI_PPR` | what the user asks for. With `PPR_TARGET` on this is the target, and the search never changes it. |
| `aPrioriPPR_adjusted` | `ADJUSTED_PPR` | the working values, which the search moves. They begin as a copy of the target. |
| `aPrioriPPR_result` | written as `PPR_RESULT_` *i* | the ratios the last simulation produced, among women ever in a union. |

The single number used to judge a fit is the cohort total fertility implied by a
set of ratios, a sum of cumulative products:

    CTFR  =  PPR(0) + PPR(0)·PPR(1) + PPR(0)·PPR(1)·PPR(2) + …

computed by `computeTFRfromPPRs` and rounded to three decimals.

**How an adjusted ratio reaches the simulation.** The ratios are not applied as
probabilities of a further birth. `adjustContraception` turns them into the
per-parity intention to stop childbearing:

    curr_contracepStopping[i]  =  1 − (1 − ADJUSTED_PPR[i]) × f

where *f* = (*s* − 1)/(*n* − 1) for contraception step *s* out of *n*
(`NSTEP_CONTRACEPTION`), and *f* = 1 when *n* = 1. At *f* = 0 nobody stops, which is
natural fertility; at *f* = 1 the adjusted ratio is itself the probability of not
stopping at parity *i*. A sweep over contraception steps is thus a sweep from
natural fertility to the full adjusted schedule, and the target adjustment fixes
the schedule that sits at the end of that sweep.

**One pass.** For every parity *i* from 0 to `kMaxNbChildrenCalc` (15), the pass
reads the target *c*, the current adjusted value *a*, and the ratio *b* that the
previous simulation produced, and then:

- if *b* = 0, nobody in the simulation reached parity *i*. There is nothing to
  compare, so *a* is left as it is and the parity is counted in this pass's tally
  of skipped parities;
- otherwise *a* is multiplied by *c*/*b*, which raises it when the simulation fell
  short of the target and lowers it when the simulation overshot, with the result
  capped at 0.99999.

Parities above `kMaxNbChildrenCalc` carry no information of their own and are
multiplied by the factor of the last parity that was reached, or left alone if no
parity was reached at all. The adjusted ratios are then turned into contraceptive
stopping, the a priori desired family size is recomputed, and the cohort is
simulated again. The source also carries the same adjustment written on the odds
scale, which keeps the result inside the unit interval without a cap; it is not in
use (`useOdds` is false).

**Which pass is kept.** At most four passes are made. After each one the program
measures the distance between the cohort total fertility implied by the simulated
ratios and the one implied by the target, keeps the pass with the smallest
distance, and leaves the loop as soon as a distance of 0.01 children is reached. If
the best pass was not the last, the adjusted ratios of the best pass are put back
and the cohort is simulated once more from them, so that the tables the run reports
and the adjusted values it writes belong to the same pass.

**The line in the log.** Each cohort prints one line, for example:

```
PPR adjustment, cohort 1950: pass 2 of 4 kept, cohort total fertility 0.007 from the target of 2.145. Parities skipped for want of anyone reaching them: 9
```

It reads: of the four passes allowed, pass 2 was the closest and is the one in
force; the adjusted ratios imply a cohort total fertility 0.007 children away from
the 2.145 implied by the target ratios; and in that pass 9 of the 16 parities were
reached by no simulated woman, so their adjusted ratios were left untouched. The
last figure describes the fertility level of the cohort and is not a fault: with a
mean near two children the high parities are empty by construction. It is worth
attention only when it covers parities one expected to be populated, since those
parities then keep their target values and contribute nothing to the fit. Ticking
**More feedback** (`TALKATIVE`) adds, for every pass and every parity, the target,
the adjusted and the simulated ratio.

**What the fit does and does not guarantee.** Three limits should be kept in mind
when reporting results obtained with this option:

- the agreement is judged on one summary number, the implied cohort total
  fertility, and not parity by parity. A set of adjusted ratios can match the total
  while placing the births at the wrong parities;
- four passes is a small number and nothing guarantees convergence. The distance
  printed in the log is the honest measure of how far the run landed from the
  target;
- a parity that nobody reached keeps its target value as its adjusted value, which
  is a statement about an unobserved quantity and should not be read as a fitted
  one.

#### 8.8.2 The separation target

**The quantities.** `SEPARATION` (`freqSeparation`) is the target: the proportion of
unions that end in separation. What is searched for is the level handed to
`calcSeparation`, which builds the schedule of monthly separation risks by duration
of union. That schedule is a generalized log-logistic cumulative in duration, with
median `separation_median` and shape `separation_shape`, normalized so that it
reaches 1 at sixty years of union duration and then scaled down to the level
supplied. The level is therefore the proportion that would separate over a complete
union if nothing else ended it.

What is measured after each trial is `separationFinalProp`, computed from the
simulated union table as a single-decrement life-table proportion over first
unions: at each duration the separation rate takes as its denominator the unions
still intact less half of the exits by other causes, and the proportion separating
is one minus the product of the complements. It is thus a proportion net of
widowhood and of the woman's own death, which is what makes it comparable with the
target.

**The search.** A secant rule on the pair (level tried, proportion obtained). With
*a* for a level and *r* for the proportion it produced,

    α  =  (r(n−2) − target) / (r(n−2) − r(n−1)),   with α held at 0.01 or above
    a(n)  =  a(n−2) − α · ( a(n−2) − a(n−1) )

The first guess is placed above the target, by a factor of 1.1 plus the a priori
desired family size divided by 30, because the measured proportion comes out below
the level supplied. When the secant step falls outside the open interval (0, 1),
two fallbacks are used: if the last two results lie on the same side of the target,
the smaller level is rescaled in proportion, as *a* × target / *r*; otherwise the
midpoint of the last two levels is taken.

Each trial costs a complete fertility simulation of the cohort. It is run with
`NUMBER_WOMEN` women rather than the configured number of egos, and with the
individual microdata file switched off, so a trial is cheaper than a full run but
not cheap.

**Stopping.** A trial is accepted when the difference from the target is below
0.003 in absolute terms, or below 1.5 per cent in relative terms, and in any case
after twenty trials. The trial with the smallest absolute difference is kept, the
risk schedule is rebuilt from it, and the level is stored in `SEPARATION_ADJUSTED`,
with the proportion it produced stored beside it. When twenty trials pass without
reaching the tolerance the log says so, on a line beginning `No convergence:`.

The search is skipped entirely when the target is 0 or 1, when `SEP_TARGET` is off,
and when separation is set to be homogeneous.

**The lines in the log.** One line per trial:

```
1950: iterating propSeparation: 3 objective: 0.28 apriori prop: 0.372 approximation: 0.2731
```

where *objective* is the target, *apriori prop* the level being tried, and
*approximation* the proportion that level produced.

#### 8.8.3 Adjusted values, and reusing them

Both searches cost several complete simulations of every cohort, so with a long
series of cohorts they can dominate the running time of a run. The adjusted values
are therefore written out and can be read back.

- **Writing.** **Write adjusted values** (`WRITE_ADJUSTED_VALUES`,
  [§6.3](#63-general-output-options)) produces `<root>_target.txt`, one line per
  cohort, with `SEPARATION`, `SEPARATION_ADJUSTED` and the proportion obtained,
  then the target, adjusted and simulated parity progression ratios.
- **Reading back.** A cohort file that carries adjusted values marks the cohort as
  adjusted, and the parity progression search is then skipped. **Force computation
  of Fertility PPR target iterations** (`FORCE_PPR_TARGET`,
  [§5.4](#54-fertility-iteration-controls)) makes the search run anyway.
- **The separation value.** A positive `SEPARATION_ADJUSTED` is taken as the first
  guess of the search, which usually brings the number of trials down to one or
  two. **Force computation of separation iterations** (`FORCE_SEP_ITER`) decides
  whether the search runs at all: with it on, the search runs; with it off, the
  stored value is applied as it is and no trial is made.

> **A trap to avoid.** With `SEP_TARGET` on and `FORCE_SEP_ITER` off, the program
> applies `SEPARATION_ADJUSTED` without checking it. Since that parameter is
> optional and defaults to zero, a configuration that turns `FORCE_SEP_ITER` off
> without supplying an adjusted value builds a schedule from a level of zero, which
> switches separation off altogether while `SEPARATION` still shows a positive
> target. The default for `FORCE_SEP_ITER` is on, so this bites only when it has
> been turned off deliberately. *`[TODO: decide whether a zero adjusted value
> should fall back to running the search, with a message, rather than suppressing
> separation.]`*

### 8.9 Bootstrapping and stable populations

`BOOTSTRAP_NRUNS` repeats the simulation to obtain sampling variability;
`OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES` writes one microdata file per replicate.
The program can also compute a **stable population** (`StablePopulation`).
*`[TODO: describe what the stable-population mode produces and when it is used.]`*

### 8.10 Randomness and reproducibility

Random draws come from a `TRandomNumberGenerator`. Ticking **Same Random
Sequence** (`INIT_RANDOM_NUMBERS`) re-initialises the generator identically so a
run can be reproduced exactly (subject to the multithreading caveat in
[§6.6](#66-multithreading)).

### 8.11 Multithreading

Three phases can run in parallel (demographic-regime initialisation, motherhood
initialisation, and kinship simulation) under the master `MULTITHREADING` switch,
with a configurable thread cap and optional batching ([§6.6](#66-multithreading)).

---

## 9. Kin taxonomy reference

KinFert recognises the following kin types (enumeration `KinTypes`, with the
display names from `str_kinship`). Ego's network is built from the subset you
choose under **Select kin to simulate**.

![Select kin to simulate dialog](img/kin-selection.png)

| Internal name | Display name | Branch |
|---|---|---|
| `kt_ego` | ego | none |
| `kt_partner` | partner | partner |
| `kt_child` | child | descendants |
| `kt_grandChild` | grand child | descendants |
| `kt_greatGrandChild` | great grand child | descendants (no further descent) |
| `kt_father`, `kt_mother` | father, mother | ascendants (1) |
| `kt_grandFather`, `kt_grandMother` | grand father, grand mother | ascendants (2) |
| `kt_greatGrandFather`, `kt_greatGrandMother` | great grand father/mother | ascendants (3) |
| `kt_sibling` | sibling | collateral (0) |
| `kt_nieceNephew` | niece-nephew | collateral via siblings |
| `kt_grandNieceNephew` | grand niece-nephew | collateral via siblings |
| `kt_greatGrandNieceNephew` | great grand niece-nephew | collateral (no further descent) |
| `kt_auntUncle` | aunt-uncle | collateral (1 up) |
| `kt_grandAuntUncle` | grand aunt-uncle | collateral (2 up) |
| `kt_cousin` | first cousin | collateral |
| `kt_cousin_removed` | first cousin once removed | collateral |
| `kt_cousin_twice_removed` | first cousin twice removed | collateral |
| `kt_cousin_thrice_removed` | first cousin thrice removed | collateral (no further descent) |
| `kt_great_cousin_removed` | great first cousin once removed | collateral |
| `kt_second_cousin` | second cousin | collateral |
| `kt_second_cousin_removed` | second cousin once removed | collateral |
| `kt_second_cousin_twice_removed` | second cousin twice removed | collateral |
| `kt_nonBio` | non-bio | non-biological kin |
| `kt_total` | total | (aggregate row, not a real kin) |

**Default set simulated** (`gKinToSimulate`): ego, partner, father, mother,
sibling, grandfather, grandmother, aunt-uncle, child, grandchild.

**Kin with no further descendance** (`gKinWithNoDescendance`): great-grandchild,
great-grand-niece-nephew, first cousin thrice removed, second cousin twice
removed, i.e. the program does not extend descendants below these.

The **heirs/decedents** dialogs expose a subset of this list
([§6.5](#65-inheritance)); the kinship **output** range runs from `kt_ego` to
`kt_second_cousin_twice_removed`.

---

## 10. Input file formats

### 10.1 Configuration (command) file

A configuration file is a **tab-delimited text file** created by **Save config
file** and read by **Read config file**. Its conventions are:

- **Comment lines** begin with `#` and are ignored; blank lines are ignored too.
- Fields on a line are separated by **tabs**.
- **Decimal commas are accepted** and converted internally to decimal points, so
  files saved under a European locale load correctly.
- **Scalar parameters** are stored under the internal names listed in chapters
  [4](#4-configuring-a-simulation-the-config-window)–[6](#6-outputs-the-outputs-window)
  (e.g. `LIFE_EXPECTANCY_AT_BIRTH_WOMEN`, `MEAN_AGE_UNION`, `SEPARATION`).
- **Tabular parameters**, the value-list inputs such as the a-priori PPRs,
  stopping efficacy, spacing proportions and waiting times, are written as
  indexed rows (`index <tab> value`), with `-1` used as a row sentinel.
- **Save only non-default values** (`WRITE_ONLY_CHANGES`) shortens the file to
  just the parameters that differ from the defaults; **Write detailed config
  file** (`DUMPALL`) writes everything.

*`[TODO: confirm the exact keyword/grammar for each scalar line (token order and
separator) and add a short annotated example file here. The reader currently has
to rely on the parameter-name tables in chapters 4–6.]`*

### 10.2 Cohort / demographic-regime data file

When a run spans several cohorts, their demographic regimes are supplied in a
**cohort file** (named in `DEM_REG_FILENAME`, loaded with **Read Cohorts**). Use
**Create cohort file** to generate one pre-filled with defaults for the current
cohort; **Write complete cohort file** (`DUMPALLCOHORTS`) writes the full set, and
**Write detailed cohort data** (`DETAILED_COHORT_DATA`) adds detail.

*`[TODO: document the per-cohort block layout (one block per cohort, which
parameters appear, and how cohorts are keyed by year).]`*

---

## 11. Output file formats

### 11.1 Output location and file naming

Results are written under the **output directory** (set on the main window). All
files of a run share the **root file name** (`FILENAME`); the program appends tags
identifying the table or content (built by the internal `outputFileNameHeader`
routine). **Write results in folder** (`WRITE_FOLDER`) places them in a dedicated
sub-folder.

### 11.2 Aggregate result tables

Each ticked output in [§6.1](#61-fertility-result-tables) and
[§6.4](#64-kinship-outputs) produces a corresponding tab-delimited table file
(e.g. cohort TFR, parity by age, kin distribution). *`[TODO: list the file-name tag
and column layout for each table.]`*

### 11.3 Individual microdata files

With **Individual results** ticked, KinFert writes one record per individual
(fertility) or per kin (kinship):

- The **fertility** file has a base set of fields, extended by **Extended file**
  (`OUTPUT_INDIVIDUAL_FERTILITY_INFO_EXTENDED`); abortions can be excluded
  (`OUTPUT_EXCLUDE_ABORTION`); ages can be integer or decimal
  (`OUTPUT_INDIVIDUAL_AGE_FLOAT`); the number of unions/births per record is capped
  by `OUTPUT_MAXNUMUNION` / `OUTPUT_MAXNUMBIRTHS`.
- The **kinship** file's columns are chosen in **Select optional fields**
  ([§6.4.1](#641-optional-per-kin-fields)); its layout follows
  `KINSHIP_INDIV_FORMAT`.
- Both can be ZIP-compressed (`ZIP_INDIVIDUAL`), and one file per bootstrap
  replicate can be written (`OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES`).

*`[TODO: give the exact column order of the base and extended fertility records.]`*

### 11.4 Other files

- **Adjusted values** (`WRITE_ADJUSTED_VALUES`): the fitted fertility and
  separation values from the target iterations ([§8.8](#88-targets-iteration-and-adjusted-values)).
- **Log** (`SAVE_LOG`, or **Save output log**): the run log.

---

## 12. Tutorial: a first simulation

A minimal end-to-end run (generic; adapt the numbers to your study):

1. Start KinFert. On the main window click **Edit config**.
2. Under **Model type**, tick **Fertility** and **Kinship**.
3. Under **Cohorts simulated**, set **First**, **Last** and **Step** (for a single
   cohort, set First = Last).
4. Set **Mortality** (e0 women/men), the **a-priori PPRs** (or a **CTFR** with
   **PPR values as target**), and the **Union** parameters (mean age at union,
   proportion ever in union).
5. Set **Number of Egos** (start small, e.g. a few thousand, to test quickly).
6. Click **Output Options** and tick a few results (for example **Cohort TFR**,
   **Parity by age**, **Kin Statistics**), then **OK**.
7. **Save config file**, then **OK** to close the Config window.
8. On the main window click **Output directory** and choose a folder.
9. Click **run simulation**. Watch the log and progress bar.
10. When done, confirm the **error status** is not red, open **Graphs**, and find
    the result files in your output directory.

*`[TODO: replace this with a concrete worked example using a real configuration
file and expected output figures, so users can verify their build reproduces
known results; this also doubles as a regression test.]`*

---

## 13. Experimenting with the fertility model

> **Status of this chapter.** The skeleton, the verified facts and the figure slots
> are in place; the didactic text is still to be written. Each section carries a
> note headed **To write** saying what belongs there, and each figure slot names the
> file to drop into `docs/img/` and what the capture should show. The register of
> every expected screenshot is in [`docs/img/README.md`](img/README.md).

This chapter and the next are the two guided parts of the manual. Chapters 3 to 7
say what every control is; chapter 8 says how the model works. These two chapters
say how to *use* the program for a piece of research: what to set, in what order,
what to look at, and how to recognise a result that cannot be trusted. This one
takes the fertility model on its own, in the setting where it is easiest to
understand and to experiment with, a single stable population. The next takes the
kinship model.

### 13.1 Why experiment in a stable population

> **To write.** The argument for starting here: with one demographic regime and no
> cohort file, every individual the program simulates, of whatever generation, lives
> under the same fertility, nuptiality and mortality conditions. A change in a
> result then comes from the parameter that was changed and from nothing else. Say plainly what this buys (interpretability, speed, comparability with
> analytical results) and what it costs (no cohort change, so nothing about real
> populations in transition).

**What "stable population" means in the program.** It is not an option to tick. A
run is a stable population run when no cohort file has been read, so that the
collection of demographic regimes contains a single regime (`nCohorts = 0`, which is
what the function `StablePopulation` tests). Reading a cohort file ends it; every
individual then takes the regime of her own birth cohort, with the one exception
noted in [§8.6](#86-the-kinship-algorithm). Two consequences follow, and both
matter in practice:

- the **sweeps** of [§13.5](#135-sweeping-parameters-over-a-range-of-steps) are
  allowed only in a stable population. If a cohort file is loaded, every `NSTEP_`
  value is silently reset to 1 and the sweep does not happen;
- in a stable population the program builds the **pools of mothers and brides** used
  by the backward kinship algorithm, which are not built when regimes change by
  cohort. This is a difference in memory and in the internal path, not in the
  demographic meaning.

*`[TODO: the configuration parameter STABLE_POPULATION is read from a configuration
file and has no control on any form, and nothing in the simulation consults it. It
should either be given its meaning back or be retired.]`*

### 13.2 A minimal fertility-only run

> **To write.** The shortest path from starting the program to a first set of
> fertility tables, in numbered steps, with the figures below taken in sequence so
> that a reader can follow along on screen. Keep it to one cohort, a few thousand
> women, two or three tables, and no kinship, so that it finishes in seconds. End
> with what the output directory now contains.

![Figure 13-1. The main window before a run](img/fert-01-main-window.png)

> *Figure 13-1 to capture: the main window with an output directory chosen and no
> run yet made, so the log and the error indicator are empty.*

![Figure 13-2. Model type set to fertility only](img/fert-02-model-type.png)

> *Figure 13-2 to capture: the Model type group of the Config window with
> **Fertility** ticked and **Kinship** cleared.*

![Figure 13-3. A single cohort](img/fert-03-single-cohort.png)

> *Figure 13-3 to capture: the Cohorts group with First equal to Last, Step at 1,
> and no cohort file loaded (the cohort file label empty).*

![Figure 13-4. The fertility tables chosen for a first run](img/fert-04-outputs-minimal.png)

> *Figure 13-4 to capture: the Outputs window with only Cohort TFR, Parity by age
> and General Fertility ticked.*

![Figure 13-5. The log of a completed run](img/fert-05-log-done.png)

> *Figure 13-5 to capture: the main window after the run, with the log scrolled to
> the closing lines and the error indicator not red.*

### 13.3 The a priori inputs, group by group

> **To write.** One short subsection per group of the Config and LowLevel windows,
> each answering the same three questions: what the parameter means
> demographically, what a plausible range of values is, and what in the output
> moves when it is changed. The reference tables in chapters 4 and 5 already give
> the labels and internal names, so do not repeat them; point to them and spend the
> space on interpretation. Suggested order: the level of fertility (a priori parity
> progression ratios and the implied cohort total fertility), the biological floor
> (fecundability, sterility, amenorrhea), the behavioural layer (contraception for
> spacing and for stopping, and the waiting time), and the exposure layer
> (nuptiality: age at first union, proportion ever in union, separation,
> repartnering).

![Figure 13-6. The a priori parity progression ratios](img/fert-06-apriori-ppr.png)

> *Figure 13-6 to capture: the Union fertility (apriori) group with a set of ratios
> entered and the implied cohort total fertility shown beside them.*

![Figure 13-7. The contraception group](img/fert-07-contraception.png)

> *Figure 13-7 to capture: the Contraception use group, with the spacing and
> stopping fields filled as in the worked example of §13.11.*

![Figure 13-8. The biological options](img/fert-08-lowlevel-biology.png)

> *Figure 13-8 to capture: the fecundability and sterility groups of the LowLevel
> window.*

![Figure 13-9. The union group](img/fert-09-nuptiality.png)

> *Figure 13-9 to capture: the Union group of the Config window, with the women's
> mean age at union, the standard deviation and the proportion ever in union
> visible.*

### 13.4 Asking for a level, or asking for a target

> **To write.** The practical consequence of [§8.8](#88-targets-iteration-and-adjusted-values)
> for someone designing an experiment: when to treat the parity progression ratios
> and the proportion separating as behaviour to impose, and when to treat them as
> results to reproduce. Explain that a target costs several complete simulations per
> cohort, that the adjusted values can be saved and read back, and how to read the
> two reports the searches print. Say which of the two settings an experiment on
> the *shape* of fertility should use, and which an experiment on its *level*
> should use.

![Figure 13-10. The two target switches](img/fert-10-targets.png)

> *Figure 13-10 to capture: PPR values as target on the Config window, together with
> the Separation freq. as target switch and the SEPARATION_ADJUSTED field.*

![Figure 13-11. The report of the two searches in the log](img/fert-11-target-log.png)

> *Figure 13-11 to capture: the log of a run with both targets on, showing the
> separation trials and the PPR adjustment line for one cohort.*

### 13.5 Sweeping parameters over a range of steps

A run can repeat a complete simulation over a range of values of one parameter, or
over the Cartesian product of ranges of several. This is the main way of
experimenting with the fertility model: instead of editing a parameter and running
again, one run produces the whole series.

**How a range is declared.** Each sweep has a **number of steps** parameter. A
value of 1 means no sweep. A value above 1 means that many simulations, with the
swept parameter taking equally spaced values over the range given in the third
column below. Ranges run from 1 to 50 steps.

| Order | Steps parameter | On screen | What is swept | From, at step 1 | To, at the last step |
|---|---|---|---|---|---|
| 1 (outermost) | `NSTEP_UNION_MEAN` | *Steps: mean age at union* | mean age at first union of women | `MEAN_AGE_UNION` | `MEAN_AGE_UNION_HIGH` |
| 2 | `NSTEP_UNION_PROP` | *Steps: prop. ever in union* | proportion ever in union by the end of the union ages | `EVER_INUNION_PROP_HIGH` | `EVER_INUNION_PROP` |
| 3 | `NSTEP_UNION_STDDEV` | *Steps: std dev. age at union* | standard deviation of the age at first union | 0.5 times its current value | 1.5 times its current value |
| 4 | `NSTEP_CONTRACEPTION` | *Steps: contraception* | the intention to stop childbearing, through the factor *f* of [§8.8.1](#881-the-parity-progression-ratio-target) | *f* = 0, nobody stops: natural fertility | *f* = 1, the adjusted ratios in full |
| 5 | `NSTEP_SEPARATION` | *Steps: separation* | proportion of unions ending in separation | 0, no separation | `SEPARATION` |
| 6 | `NSTEP_CONTRACEP_BEFORE_FIRST_CHILD` | *Steps: contracep. before first child* | mean time of contraceptive use in the first union before the first wanted birth | 0 | `CONTRACEP_TIME_AFTER_FIRST_UNION` |
| 7 (innermost) | `NSTEP_AMENORRHEA` | *Steps: amenorrhea* | the Lesthaeghe and Page parameter α | `AMENO_ALPHA` | `AMENO_ALPHA` + 2.4 |

Three points about this table are easy to get wrong:

- **the second sweep runs downward.** Step 1 takes the *high* value of the
  proportion ever in union and the last step takes the low one, the reverse of the
  first sweep. The source is explicit about it;
- **the third sweep is relative**, not absolute. It takes the standard deviation in
  force and spans half to one and a half times it. When the first sweep is also
  active the standard deviation is recomputed from each mean age at union before
  being scaled, by the relation chosen in the fixed-parameter options (a logistic
  form, or Campbell and Wood 1988);
- **the seventh sweep adds to α**, it does not run from zero to α. The on-screen
  help for `NSTEP_AMENORRHEA` says values are taken "from 0 to the value in
  AMENO_ALPHA", which the code does not do: it takes α to α + 2.4, and the default
  α is negative. *`[TODO: decide which of the two is intended and correct the other.]`*

**What a sweep costs.** The seven loops are nested, so the number of simulations is
the product of the seven numbers of steps, and each one is a complete simulation of
the cohort. Five steps on two parameters is twenty-five simulations, not ten.

**When a sweep is refused.** Every number of steps is reset to 1 when the run is not
a stable population ([§13.1](#131-why-experiment-in-a-stable-population)), and also
when **Mult. files** (`OUTPUT_BOOTSTRAP_MULTIPLE_INDIV_FILES`) is on: a sweep and a
per-replicate microdata file cannot be had in the same run. The reset is made in two
places, and only one of them says so. When an individual file was also requested the
log carries two lines beginning *Loops on AgeUnion or freqCel...*; when no individual
file was requested the reset is made without a message, and the only sign of it is
that the run produces one set of results where several were expected. Check the
number of simulations before reading the output of what was meant to be a sweep.

> **To write.** The reader's checklist for designing a sweep: choose one parameter
> to move and keep the rest fixed, decide the number of steps from the resolution needed
> rather than from curiosity, estimate the running time from a single-step run
> before launching a large product, and keep the configuration file with the
> results.

![Figure 13-12. The steps fields](img/fert-12-steps-fields.png)

> *Figure 13-12 to capture: the group of the Config window holding the seven numbers
> of steps, with one of them set above 1.*

![Figure 13-13. A low and high pair](img/fert-13-low-high.png)

> *Figure 13-13 to capture: MEAN_AGE_UNION and MEAN_AGE_UNION_HIGH filled with
> different values, which is what defines the range of the first sweep.*

### 13.6 Reading the results of a sweep

**How the steps are identified in the output.** As soon as one number of steps is
above 1, the root name of the output of each simulation carries the seven step
indices, in the order of the table above, joined by dollar signs. A run named
`test` with five steps on the mean age at union produces `test1$1$1$1$1$1$1`,
`test2$1$1$1$1$1$1`, and so on. The header line written before each simulation
repeats the indices together with the value each swept parameter took, which is
what makes the series readable afterwards.

**The KEYS file, which is the table of the sweep.** When an individual file is
requested and at least one sweep is active, the run also writes `<root>_KEYS.txt`:
one row per simulation, with a key number in the first column, then, for every sweep
that is active and for no other, the index of the step and the value the parameter
took. Bootstrapping adds its replicate index in the same way. The first field of
every record of the individual fertility and kinship files is that same key number,
so the KEYS file is the lookup table that turns a set of microdata into an analysis
by parameter value: read it, read the individual file, and join them on the key.
Without an individual file no KEYS file is written, and the step indices in the
output names together with the header lines are then the only record of what each
simulation was.

> **To write.** How to turn that series into an analysis: which tables accumulate
> across steps and which are written once per step, a worked join of the KEYS file
> to an individual file in a statistical package, and the recommended way of reading
> a whole set of aggregate tables at once. A short example of a table of results by
> step, with the parameter value as the first column, belongs here.

![Figure 13-14. A sweep in the Graphs window](img/fert-14-graph-inputs-variation.png)

> *Figure 13-14 to capture: the Inputs (variation) tab of the Graphs window after a
> sweep, showing the swept parameter across steps.*

![Figure 13-15. Fertility results across the steps of a sweep](img/fert-15-graph-outputs-fertility.png)

> *Figure 13-15 to capture: the Outputs: fertility tab after the same sweep.*

### 13.7 Choosing the aggregate tables

> **To write.** The aggregate fertility tables of [§6.1](#61-fertility-result-tables)
> grouped by the question they answer, rather than by their position in the window:
> the level of fertility (cohort TFR, cohort fertility, general fertility); the
> parity distribution (parity by age, PPRs by union status, parity by age at first
> union); the timing (intervals, intervals from union to conception, age at
> childbearing, age at last birth, durations); exposure (proportion single, union
> states, repartnering state, union life table); and the diagnostics (no
> fecundation, dump of the union table). For each group, say what a sound result
> looks like and what an implausible one looks like. State which tables are the ones
> to check first after any change of parameters.

![Figure 13-16. A cohort fertility table as written](img/fert-16-table-output.png)

> *Figure 13-16 to capture: one of the result files open in a spreadsheet or a text
> editor, so the layout of a result table is visible.*

### 13.8 The individual file for analysis

> **To write.** When aggregate tables are not enough and one record per simulated
> woman is needed. Cover: what a record contains and the effect of **Extended
> file**; the fields that depend on the options of
> [§6.3](#63-general-output-options) (ages as decimals, the precision fields, the
> caps on unions and births written per record); the effect of **Exclude abortion**;
> the size of the file and when to compress it; and the synthetic survey extract
> (**Fertility survey**, with its age bounds) and what it is for, namely producing
> data with the shape of a real fertility survey. Finish with a worked read of the
> file into a statistical package and one or two checks that the file agrees with
> the aggregate tables of the same run.

![Figure 13-17. The individual fertility options](img/fert-17-indiv-options.png)

> *Figure 13-17 to capture: the Individual fertility microdata group of the Outputs
> window, with the extended file and the survey options visible.*

![Figure 13-18. The first records of an individual file](img/fert-18-indiv-file.png)

> *Figure 13-18 to capture: the head of an individual fertility file, enough rows
> and columns to show the structure.*

### 13.9 Repeating a run: bootstrapping

> **To write.** What `BOOTSTRAP_NRUNS` repeats and what it does not, how to read the
> spread across replicates as the sampling variability of a result, how many
> replicates are enough for what purpose, and the interaction with **Same Random
> Sequence** and with multithreading. State plainly that a sweep and per-replicate
> microdata files cannot be combined ([§13.5](#135-sweeping-parameters-over-a-range-of-steps)).

### 13.10 Reading the log of a fertility run

> **To write.** A walk through the log of the worked example, line by line, naming
> the lines that are ordinary progress, the lines that report the two target
> searches ([§8.8](#88-targets-iteration-and-adjusted-values)), the lines that report
> a verification check, and the lines that mean the run should be discarded. The
> verification messages are listed in
> [`docs/KinFert-Verification-Plan.md`](KinFert-Verification-Plan.md).

![Figure 13-19. A log with a verification message](img/fert-19-log-check.png)

> *Figure 13-19 to capture: a log containing one of the verification messages, with
> the error indicator red.*

### 13.11 A worked experiment from beginning to end

> **To write.** One experiment carried through completely, with the configuration
> file printed, the figures above taken from it, and the result discussed: for
> example the effect of the mean age at first union on completed fertility, in ten
> steps, in a stable population, with everything else held. Give the numbers the
> reader should obtain, so the example doubles as a check that a fresh build
> reproduces known results. The configuration file belongs in the repository beside
> the manual.

### 13.12 Checklist before trusting a fertility result

> **To write.** A short list, each item a question with a way of answering it: is
> the run a stable population run, and was that intended; did every sweep actually
> happen, or were the steps reset; did the target searches converge, and how far did
> they land; are the parities with no women where they are expected; is the number
> of women large enough for the quantity being read; was the random sequence fixed;
> and does the individual file agree with the aggregate tables.

---

## 14. Working with the kinship model

> **Status of this chapter.** As in chapter 13, the skeleton, the verified facts and
> the figure slots are in place and the didactic text is still to be written. Each
> section carries a note headed **To write**, and each figure slot names the file to
> drop into `docs/img/` and what the capture should show.

### 14.1 What the kinship model produces

> **To write.** What a reader gets at the end of a kinship run, stated before any
> option is described: for every ego, a genealogical tree of relatives, each with a
> kin type, a date of birth, a date of death where applicable, a union history and
> a number of children; and from those trees, either aggregate tables (how many kin
> of each type an ego has, at each age, and their characteristics) or one record per
> kin. Make the point that the kin network is a by-product of the fertility
> histories and inherits all their properties, so a question about kin is always
> also a question about fertility, nuptiality and mortality.

![Figure 14-1. A simulated kin network](img/kinship-01-network-example.png)

> *Figure 14-1 to capture: a small genealogy taken from an individual kinship file,
> drawn by hand or with a genealogy viewer reading the GEDCOM output, to show what
> one ego's tree looks like.*

### 14.2 What the kinship model needs from the fertility model

> **To write.** That **Kinship** cannot be run without the fertility machinery
> underneath ([§4.2](#42-model-type)), and what that means in practice: every
> parameter of chapter 13 is still in force and still shapes the result. Name the
> parameters whose effect on kin counts is largest, with the mechanism in one line
> each: the level of fertility (the number of siblings, children and cousins), the
> mean age at first union and the age pattern of childbearing (the age gaps between
> generations, so whether grandparents are alive), mortality (the survival of every
> ascendant), and separation and repartnering (half-siblings and step-kin).

### 14.3 Setting up a kinship run

> **To write.** The ordered path from a working fertility configuration to a working
> kinship configuration, with the figures below taken in sequence. State explicitly
> that it is better to settle the fertility side first, as in chapter 13, and only
> then turn kinship on, because a kinship run is far slower and a parameter mistake
> is much more expensive to discover.

![Figure 14-2. Model type with kinship on](img/kinship-02-model-type.png)

> *Figure 14-2 to capture: the Model type group with both Fertility and Kinship
> ticked.*

![Figure 14-3. The kinship population sizes](img/kinship-03-sizes.png)

> *Figure 14-3 to capture: the Number of Egos field on the Config window together
> with the Number of mothers / brides field on the LowLevel window, in one composed
> image if possible.*

![Figure 14-4. The kinship outputs chosen for a first run](img/kinship-04-outputs.png)

> *Figure 14-4 to capture: the Kinship group of the Outputs window with Kin
> Statistics and Kin Distribution ticked.*

### 14.4 The three population sizes

Three separate numbers decide how much is simulated. Confusing them is the commonest
way of producing a run that is either far too slow or too small to interpret.

| Parameter | On screen | Where | What it sizes |
|---|---|---|---|
| `NEGO` | **Number of Egos in the Kinship model** | Config window, per cohort | How many egos get a kin network. This is the sample size of every kinship result. |
| `NWOMEN` | *(number of women)* | Config window, per cohort | How many women the fertility model simulates for that cohort's aggregate fertility tables. |
| `NUMBER_WOMEN` | **Number of mothers / brides for the kinship model** | LowLevel window, for the run | The size of the pools of possible mothers and possible brides from which the backward algorithm draws. It also sets the number of women used inside the separation search ([§8.8.2](#882-the-separation-target)). |

> **To write.** How to choose each of the three: what precision `NEGO` buys for a
> rare kin type as against a common one, why the pool size matters for the
> independence of the drawn ancestors, and the running time and memory each one
> costs. Give a small table of sensible starting values for a first exploratory run,
> for a working run, and for a run intended for publication.

### 14.5 Choosing which kin to simulate

> **To write.** The kin-type list of [§9](#9-kin-taxonomy-reference) and the dialog
> that selects from it: what is gained by restricting the set (speed, memory,
> smaller output files) and what is lost (a kin type not simulated is absent from
> every table and from the inheritance resolution, not merely unreported). Note that
> the selection interacts with the inheritance sets of
> [§6.5](#65-inheritance), which can only ever be subsets of what was simulated.

![Figure 14-5. The kin selection dialog](img/kin-selection.png)

> *Figure 14-5: the Select kin to simulate dialog. This is the same capture as the
> one listed for §9 in the screenshot register.*

### 14.6 The backward algorithm, and when the choice matters

The kin network is built by reconstructing ego's ancestors, and five algorithms for
choosing a reference child's mother are available. They are selected by
`MOTHER_ALGORITHM` in the configuration file, or by the checkboxes of the Utiles
window when the configuration file is silent; the configuration file wins when it
names one.

| Value | Name in a configuration file | What it is |
|---|---|---|
| 0 | `KINFERT` | KinFert's own algorithm, the default, and the one the published results rest on. |
| 1 | `BACKFOR` | Le Bras's original algorithm. |
| 2 | `BACKFOR_MIXED` | The same, with the mother taken from the pool of mothers rather than simulated afresh. |
| 3 | `CAMSIM_1987` | The first published CAMSIM algorithm. |
| 4 | `CAMSIM_1993` | The second, with `CAMSIM_1993_ANY_AGE_UNION` deciding whether the mother's age at union is drawn without an upper bound (the default) or bounded by the age at childbearing already selected. |

The four alternates exist so that the five can be run on one configuration and
compared. The comparison already made is recorded in
[`docs/KinFert-Annex-Mother-Algorithms.md`](KinFert-Annex-Mother-Algorithms.md) and
the decisions taken in
[`docs/KinFert-Alternate-Algorithms-Decisions.md`](KinFert-Alternate-Algorithms-Decisions.md).

> **To write.** For a reader who has to choose: what the five differ in, in
> demographic terms rather than in code; which results are sensitive to the choice
> and which are not; and the recommendation, which is to use `KINFERT` unless the
> point of the exercise is the comparison itself.

![Figure 14-6. The algorithm checkboxes](img/kinship-06-mother-algorithm.png)

> *Figure 14-6 to capture: the group of the Utiles window holding the five
> algorithm checkboxes and the unbounded age at union option.*

### 14.7 Cohorts, and checking that the ranges are wide enough

> **To write.** Why a kinship run reaches well outside the cohorts asked for: ego's
> grandparents were born two generations before ego and ego's great-grandchildren
> two generations after, so the program must index birth years and grooms' ages over
> a much wider span than First to Last. Explain the two diagnostics, what a
> complaint from either one means, and what to do about it. The coverage report is
> the authority: in a stable population run it names the two constants that size the
> bride and groom pools, and in a run with regimes by cohort a failure means the
> range computed in `initMotherhood` is wrong rather than a constant being too
> small.

![Figure 14-7. The child and groom coverage graph](img/kinship-07-graph-child-groom.png)

> *Figure 14-7 to capture: the Child / Groom tab of the Graphs window after a
> kinship run, with the accessed range well inside the available one.*

![Figure 14-8. The coverage report in the log](img/kinship-08-coverage-report.png)

> *Figure 14-8 to capture: the index coverage lines of the log, from a run where
> some unions were not found, so the advice text is visible.*

### 14.8 The aggregate kinship tables

> **To write.** The tables of [§6.4](#64-kinship-outputs) grouped by the question
> they answer: how many kin of each type (Kin Statistics, Kin Distribution, Kin
> Relative Distribution, number of kin by age of ego); how old they are (Kin Age
> Distribution, Ages Fathers and Sons); and the union life table. For each, the
> layout of the file, the unit of observation, the denominator, and one worked
> reading of a few cells. Say which tables are the ones to check first, and what an
> implausible value looks like in each.

![Figure 14-9. A kin distribution table as written](img/kinship-09-table-output.png)

> *Figure 14-9 to capture: one kinship result file open in a spreadsheet, showing
> the layout and the header rows.*

![Figure 14-10. Kinship results in the Graphs window](img/kinship-10-graph-outputs.png)

> *Figure 14-10 to capture: the Outputs: kinship tab of the Graphs window.*

### 14.9 The individual kinship file and its three formats

One record per kin can be written instead of, or beside, the aggregate tables. The
format is chosen with **File format** (`KINSHIP_INDIV_FORMAT`):

| Value | Format | Intended use |
|---|---|---|
| 0 | ego genealogy | KinFert's own layout, one row per kin of each ego, with the optional fields of [§6.4.1](#641-optional-per-kin-fields). The usual choice for statistical analysis. |
| 1 | DemoCare | The layout expected by DemoCare. |
| 2 | GEDCOM | The genealogical interchange format, readable by genealogy software. |

> **To write.** Which format to choose for which purpose, and what each one keeps
> and drops. For the ego genealogy format: how the rows of one ego hang together,
> how to identify ego's own row, and how to join the file to the fertility
> microdata of the same run. For DemoCare and GEDCOM: what the receiving program
> expects and what is lost in the conversion. Then the practical matters: the
> optional per-kin fields and the cost of each, the caps on unions and births per
> record, the size of the files, and compression. Finish with a worked read into a
> statistical package and a check against the aggregate tables of the same run.

![Figure 14-11. The individual kinship options](img/kinship-11-indiv-options.png)

> *Figure 14-11 to capture: the Individual results row of the Kinship group with the
> File format combo open, showing the three formats.*

![Figure 14-12. The optional per-kin fields](img/kin-output-fields.png)

> *Figure 14-12: the Select optional fields dialog. This is the same capture as the
> one listed for §6.4.1 in the screenshot register.*

![Figure 14-13. The first records of an individual kinship file](img/kinship-13-indiv-file.png)

> *Figure 14-13 to capture: the head of an individual kinship file in the ego
> genealogy format, enough rows to show two complete egos.*

### 14.10 Inheritance

> **To write.** Inheritance as a use of the kin network rather than a separate
> model: the two questions the module answers (who inherits from a given relative,
> and from whom does ego inherit), the succession rules applied, and the two sets
> that restrict the answer. Explain the three partner options and what each does to
> the shares. Say what the output looks like, both in the aggregate and in the
> per-kin fields. The rules as implemented are documented in the header of
> `inheritance.pas` and mapped in
> [`docs/KinFert-Inheritance-Map.md`](KinFert-Inheritance-Map.md); summarise them
> here rather than repeating them. State plainly which parts are verified and which
> are not, with a pointer to the verification plan.

![Figure 14-14. The inheritance options](img/outputs-inheritance.png)

> *Figure 14-14: the Inheritance group of the Outputs window. This is the same
> capture as the one listed for §6.5 in the screenshot register.*

![Figure 14-15. The set of possible heirs](img/heirs-set.png)

> *Figure 14-15: the Set of possible heirs dialog. Same capture as for §6.5.*

### 14.11 Multithreading and running time

> **To write.** What a kinship run spends its time on, which phases can be run in
> parallel ([§6.6](#66-multithreading)), and what to expect from more threads. The
> reproducibility question belongs here too: say clearly what is guaranteed and what
> is not when **Same Random Sequence** and multithreading are combined, and advise
> running single-threaded for any result that has to be reproduced exactly. Give
> rough timings from a real machine, with the machine named, for a small, a medium
> and a large run.

![Figure 14-16. The multithreading options](img/kinship-16-multithreading.png)

> *Figure 14-16 to capture: the Multithreading group of the Outputs window.*

![Figure 14-17. Progress during a long kinship run](img/kinship-17-progress.png)

> *Figure 14-17 to capture: the main window during a kinship run, with the progress
> bar part way and the log showing the running count of ego trees.*

### 14.12 A worked kinship experiment from beginning to end

> **To write.** One experiment carried through completely, with the configuration
> file printed and the figures taken from it: for example the number of living
> grandparents at age 10 under two mortality levels, with everything else held. Give
> the numbers the reader should obtain, so that the example doubles as a check on a
> fresh build. The configuration file belongs in the repository beside the manual.

### 14.13 Checklist before trusting a kinship result

> **To write.** A short list, each item a question with a way of answering it: did
> the coverage report and the Child / Groom graph show the ranges to be wide enough;
> was every kin type the result depends on actually in the simulated set; is `NEGO`
> large enough for the rarest kin type being reported; which mother algorithm ran,
> and was that intended; was the run multithreaded, and does the result need to be
> reproducible; do the aggregate tables and the individual file agree; and did the
> fertility side of the same run pass the checklist of
> [§13.12](#1312-checklist-before-trusting-a-fertility-result).

---

## 15. Troubleshooting

- **The error indicator is red after a run.** The last run logged errors; read the
  **Log** and **Save output log** for details.
- **A range-check / overflow / I-O error stops the run.** The shipped build has
  range, overflow and I/O checks enabled ([§2.4](#24-compiler-options-used)), so
  bad input or an out-of-range year often surfaces as an exception rather than a
  silent wrong number. Check the cohort/year ranges and the parameter values.
- **The Child/Groom graph shows the range being hit at its edges.** The configured
  span of birth years or grooms' ages is too narrow for the backward algorithm;
  widen the cohort range. (This is exactly what the state arrays in
  [§8.6](#86-the-kinship-algorithm) monitor.)
- **No output appears.** Make sure an **Output directory** is set and at least one
  output is ticked in the Outputs window.
- **Microdata files are huge.** Tick **Compress (ZIP) microdata files**, reduce
  **Number of Egos**, or cap unions/births per record.

---

## 16. Appendices

### Appendix A: Parameter glossary (demographic regime)

The per-cohort regime scalars (enumeration `paramDemReg_double`) map to the Config
labels as follows:

| Internal regime name | Config name | Label |
|---|---|---|
| `e0_women`, `e0_men` | `LIFE_EXPECTANCY_AT_BIRTH_WOMEN/MEN` | e0 women / men |
| `propFinalCelibacyLow`, `…High` | `EVER_INUNION_PROP`, `…_HIGH` | Prop. ever in union (women) |
| `propFinalCelibacyMen` | `EVER_INUNION_PROP_MEN` | Prop. ever in union (men) |
| `meanAgeUnionWomenLow`, `…High` | `MEAN_AGE_UNION`, `…_HIGH` | Age first union (women) |
| `meanAgeUnionMen` | `MEAN_AGE_UNION_MEN` | Age first union (men) |
| `stdnupt` | `STD_DEV_AGE_UNION` | Std dev age at union |
| `effContBeforeUnion` | `EFF_CONTRACEP_BEFORE_UNION` | Efficacy before first union |
| `meanTimeContraceptionAfterUnionHigh` | `CONTRACEP_TIME_AFTER_FIRST_UNION` | Contraception time after union |
| `propContraceptionAfterUnion` | `PROP_CONTRACEP_AFTER_FIRST_UNION` | Prop. waiting |
| `freqSeparation` | `SEPARATION` | Frequency separation |
| `rel_risk_2Separation` | `SECOND_SEPARATION_REL_RISK` | 2nd-union separation rel. risk |
| `repartnering_men_par`, `…_women_par` | `REPARTNERING_MEN/WOMEN` | Repartnering after separation |
| `repartnering_wid_men_par`, `…_women_par` | `REPARTNERING_WID_MEN/WOMEN` | Repartnering after widowhood |
| `amenorrhea_alpha`, `amenorrhea_beta` | `AMENO_ALPHA/BETA` | Lesthaeghe–Page α, β |
| `propWomenAtBirth` | `PROP_WOMEN_AT_BIRTH` | Proportion girls at birth |

Iteration-step and run counts (`runtimeParam_longint`): `nStepsUnion_mean/prop/Dev`,
`nStepsAmeno`, `nStepsContrFert`, `nStepsSeparation`, `nStepsContrUseAfterUnion`,
`gBootstrap_nRuns`, and the cohort range / number of women.

### Appendix B: Key constants

From `Declarations.pas` (defaults built into the program):

| Constant | Value | Meaning |
|---|---|---|
| `kNbLunarMonths` | 12 | Lunar months per year (the time step). |
| `kMinAgeLife … kMaxAgeLife` | 0 … 130 | Age span of life. |
| `kMinAgeFert … kMaxAgeFert` | 10 … 59 | Reproductive ages. |
| `kMinAgeUnion … kMaxAgeUnion` | 10 … 79 | Ages at union. |
| `kMinAgeUnion_men` | 14 | Minimum age at union for men (= women + 4). |
| `kMaxParityInput` | 9 | Maximum input parity for PPRs. |
| `kMaxShownDurationUnion` | 49 | Max union duration shown in tables. |
| `kMaxDurationContraceptionUnionInMonths` | 120 | 10 years, in lunar months. |

*`[TODO: extend with kMaxNbChildren, kMaxNbUnion and any other limits users may
hit.]`*

### Appendix C: Source-module map

**Simulation core**

| Unit | Responsibility |
|---|---|
| `Kinship.pas` | Main engine: builds ego kin networks (forward + backward). |
| `Fertility.pas` / `FertilityRuntime.pas` | Fertility declarations and the runtime fertility algorithm. |
| `Nuptiality.pas` | Union formation, separation, repartnering. |
| `Mortality.pas` | Survival / life tables. |
| `DemographicRegime.pas` | Per-cohort regime collection; read/adjust/write. |
| `inheritance.pas` | Heirs, decedents and shares. |
| `EducationalLevel.pas` | Education status assignment/transmission. |
| `Parenthood.pas` | Parent–child relationships. |
| `StablePop.pas` | Stable-population computations. |
| `Init.pas` | Initialisation, memory, kinship-tree structures. |
| `Declarations.pas` | Global constants and types. |
| `RandomNumbers.pas` | Random number generator (threaded). |
| `ReadCmdFileUnit.pas` | Reads/writes configuration (command) files. |
| `SpecialRuns.pas`, `Utilities.pas`, `NumCPULib.pas`, `Memory.pas`, `Profiler.pas` | Special run modes, helpers, CPU detection, memory, profiling. |

**Graphical interface**

| Unit | Form / role |
|---|---|
| `LazMain.pas` | Main window (`KinFertForm`). |
| `LazConfig.pas` | Config window. |
| `LazLowlevel.pas` | LowLevel options window. |
| `LazOutput.pas` | Outputs window. |
| `LazGraph.pas` | Graphs window (TAChart). |
| `LazUtiles.pas` | Debug/utility window. |
| `docform.pas` | Documentation note. |
| `lazkinselection.pas` | Select kin to simulate. |
| `lazkinoutputfields.pas` | Optional per-kin output fields. |
| `lazkinheirset.pas`, `lazkindecedentset.pas` | Heirs / decedents sets. |
| `ComponentHelper.pas` | Binds form controls to parameters. |

### Appendix D: Glossary

*Fecundability, sterility, amenorrhea, parity, PPR, CTFR, nuptiality, spacing,
stopping, ego, cohort, demographic regime*, see [§1.4](#14-key-concepts-and-terminology).

### Appendix E: References

The model draws on established demographic methods named in the code:

- **CAMSIM** and **BACKFOR**: kinship microsimulation by backward projection.
- **Leridon (2008)**: age schedule of sterility.
- **Lesthaeghe–Page**: postpartum amenorrhea.

*`[TODO: add full bibliographic citations for these and any others (e.g. the
fecundability / waiting-time and union-formation models).]`*

### Appendix F: Open questions for the author

The following points need your confirmation to finish the manual:

1. Exact **Lazarus and FPC versions** for the build ([§2.1](#21-requirements)); a documented **release build mode** ([§2.4](#24-compiler-options-used)).
2. The **conception / waiting-time** model and the precise role of spacing/stopping/waiting-time value lists ([§8.2](#82-fertility)).
3. The **repartnering hazard** shape and age-versus-duration dependence ([§8.3](#83-nuptiality)).
4. The **e₀ → survival** mapping (model life-table family) ([§8.4](#84-mortality)).
5. The current **default backward variant** and a summary of BACKFOR vs CAMSIM-1987 vs CAMSIM-1993 ([§8.6](#86-the-kinship-algorithm)).
6. The **country inheritance rule sets** and the share formula ([§6.5](#65-inheritance), [§8.7](#87-inheritance)).
7. Exact **file grammars**: configuration file lines and an example ([§10.1](#101-configuration-command-file)), cohort-file block layout ([§10.2](#102-cohort--demographic-regime-data-file)), and the column layouts of the aggregate tables and microdata files ([§11](#11-output-file-formats)).
8. The available **drop-down values** for the fixed-fertility value and the kinship file format ([§4.12](#412-model-options-and-other-options), [§6.4](#64-kinship-outputs)). The education model is now documented in [§8.5](#85-education).
9. A concrete **worked example** with known outputs for the tutorial / regression test ([§12](#12-tutorial-a-first-simulation)).

---

*End of draft.*

