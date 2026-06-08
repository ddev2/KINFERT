# KinFert — User and Reference Manual

*A kinship-network microsimulation program with a detailed fertility module.*

> **Draft status.** This is a **first draft**, reconstructed from the program's
> source code (treated as the specification) and its Lazarus form definitions.
> Sections that describe the *intended* demographic meaning of an option, or the
> exact grammar of a file, are marked **`[TODO: confirm]`** where the code alone
> does not settle the question. These are collected in
> [Appendix F — Open questions](#appendix-f--open-questions-for-the-author).
> Nothing here changes the program; it documents it.

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Installation and building](#2-installation-and-building)
3. [Getting started — the main window](#3-getting-started--the-main-window)
4. [Configuring a simulation — the Config window](#4-configuring-a-simulation--the-config-window)
5. [Low-level (biological) options — the LowLevel window](#5-low-level-biological-options--the-lowlevel-window)
6. [Outputs — the Outputs window](#6-outputs--the-outputs-window)
7. [Graphs](#7-graphs)
8. [The demographic model (methods)](#8-the-demographic-model-methods)
9. [Kin taxonomy reference](#9-kin-taxonomy-reference)
10. [Input file formats](#10-input-file-formats)
11. [Output file formats](#11-output-file-formats)
12. [Tutorial — a first simulation](#12-tutorial--a-first-simulation)
13. [Troubleshooting](#13-troubleshooting)
14. [Appendices](#14-appendices)

---

## 1. Introduction

### 1.1 What KinFert is

**KinFert** is a demographic **microsimulation** program. It simulates the
reproductive life of individual women month by month — taking into account
fecundability, sterility, postpartum amenorrhea, contraceptive behaviour, union
formation and dissolution, and mortality — and from these simulated life
histories it reconstructs the **kinship networks** of selected individuals
(called *egos*). On top of the kin networks it can also resolve **inheritance**:
who the heirs and decedents of an ego are, and what share of an estate each
receives, under selectable succession rules.

The program is written in **Free Pascal** and built with the **Lazarus** IDE
using the LCL widget set and the TAChart charting package. It runs as a desktop
application with a graphical interface on **macOS** and **Windows**.

### 1.2 What it produces

A run can produce any combination of:

- **Aggregate fertility tables** — completed fertility, parity distributions,
  parity progression ratios (PPRs), birth intervals, age at childbearing,
  cohort TFR, proportions single, fertility by union duration and union status,
  and more.
- **Aggregate kinship results** — counts and distributions of kin by type, by
  age of ego, ages of fathers and sons, union life tables, and totals.
- **Inheritance results** — heirs and decedents of egos and their shares.
- **Individual microdata files** — one record per simulated individual
  (fertility) or per kin (kinship), with a configurable set of fields, optionally
  compressed to ZIP.
- **In-application graphs** of selected inputs and outputs.

### 1.3 The modelling approach

KinFert combines two directions of simulation:

- **Forward** — a woman's reproductive life is played out in time from the start
  of her reproductive span, generating her children (with their birth months,
  parities, and intervals) inside her union history.
- **Backward** — to give an ego a complete kin network, the program reconstructs
  ego's ancestors. It works *upward* for two generations: ego's possible
  **mothers** generate ego (and ego's siblings), and the mothers' own possible
  **mothers** (ego's grandmothers) generate the parents' generation. This
  backward reconstruction follows the tradition of the **CAMSIM** and **BACKFOR**
  kinship-microsimulation models; the code retains several variants of these
  backward algorithms (see [§8.6](#86-the-kinship-algorithm)).

Each ego therefore ends up with a genealogical tree spanning descendants
(children, grandchildren, great-grandchildren), ancestors (parents, grandparents,
great-grandparents), and their collateral relatives (siblings, cousins, aunts and
uncles, nieces and nephews, and so on — see [§9](#9-kin-taxonomy-reference)).

### 1.4 Key concepts and terminology

| Term | Meaning in KinFert |
|---|---|
| **Ego** | An individual whose kin network is simulated and reported. |
| **Cohort** | A birth cohort (year of birth). A run simulates one cohort or a range of cohorts (First/Last/Step). |
| **Demographic regime** | The full set of fertility, nuptiality and mortality parameters that govern a cohort. Each cohort can have its own regime; see the cohort data file. |
| **Lunar month** | The internal time step. There are **12 lunar months per year** (constant `kNbLunarMonths`); fertility durations are counted in lunar months. |
| **Parity** | Number of children a woman has had. |
| **PPR** | *Parity progression ratio* — probability of having another child given current parity. KinFert can take PPRs as a *target* to reproduce. |
| **CTFR / cohort TFR** | Completed (cohort) total fertility — the mean number of children per woman at the end of reproductive life. |
| **Fecundability** | The monthly probability of conception for a non-pregnant, non-sterile woman exposed to risk. |
| **Sterility** | Permanent loss of the ability to conceive; modelled as a function of age (several models are available). |
| **Postpartum amenorrhea** | The non-susceptible period after a birth; modelled with the Lesthaeghe–Page formulation. |
| **Spacing / stopping** | The two contraceptive intentions: lengthening intervals between births (*spacing*) versus ending childbearing (*stopping*). |
| **Nuptiality** | Union formation and dissolution (first union, separation, repartnering, widowhood). |
| **Bootstrap** | Repeating a run many times (with resampling) to obtain variability of the results. |

### 1.5 How to read this manual

Chapters [3](#3-getting-started--the-main-window)–[7](#7-graphs) are a **user
guide**: they walk through every window and every option as it appears on screen,
giving the on-screen label, the internal parameter name, and what the option does.
Chapter [8](#8-the-demographic-model-methods) is a **methods reference** that
explains the underlying demographic model. Chapters
[10](#10-input-file-formats)–[11](#11-output-file-formats) describe the file
formats, and the [appendices](#14-appendices) provide a parameter glossary, the
key constants, a source-module map, and the list of open questions.

---

## 2. Installation and building

### 2.1 Requirements

To build KinFert from source you need:

- **Lazarus** (which bundles the **Free Pascal Compiler, FPC**). *`[TODO: confirm the
  exact Lazarus and FPC versions you build with — this is important for
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

- Optimisation level **0** and **DWARF 3** debug info — i.e. a *debug* build.
- Range checking (`-Cr`), I/O checking (`-Ci`) and overflow checking
  (`-Co`, `-CO`), and assertions (`-Sa`) **enabled**. These catch many errors at
  run time and are valuable while debugging; a release build would normally turn
  them off for speed.
- The conditional define **`LAZARUS_GUI`**.

*`[TODO: decide and document a separate "release" build mode for distribution —
optimisation on, range/overflow checks off — so published binaries run at full
speed.]`*

### 2.5 Running the prebuilt binaries

Prebuilt executables exist for **macOS** (the `KinFert` binary and the
`KinFert.app` bundle) and **Windows** (`KinFert.exe`). For publishing, these
should be distributed as **release downloads**, not committed to the source
repository (they are large). *`[TODO: when publishing, attach the macOS and
Windows binaries to a GitHub Release and note here which OS versions/architectures
they target — e.g. Apple Silicon vs Intel.]`*

### 2.6 Configuration and output directories

On first use you tell KinFert two folders:

- a **configuration directory** (where configuration/command files live), and
- an **output directory** (where results are written).

KinFert remembers them in two small text files next to the program,
**`KinFert ConfigDir.cfg`** and **`KinFert OutputDir.cfg`**. These hold absolute
paths specific to your machine, so they are **not** part of the repository; each
user sets their own on first run. *`[TODO: ship "KinFert ConfigDir.cfg.example"
templates so new users know the format.]`*

### 2.7 Platform notes

KinFert is developed on macOS (Apple Silicon) and also built for Windows. Paths in
configuration files are platform-specific; a config saved on one OS may need its
paths adjusted on another.

---

## 3. Getting started — the main window

When KinFert starts, the **main window** (titled *Kinfert*) is your control
centre. From here you load or edit a configuration, choose where output goes, run
the simulation, and inspect results.

### 3.1 The main window, control by control

| Control | On-screen label | What it does |
|---|---|---|
| `ChooseConfigButton` | **Read config file** | Load a saved configuration (a set of simulation parameters) from a file. The chosen file name appears in `ConfigFileName`. |
| `ConfigFileName` | *(label, shows "none")* | The currently loaded configuration file. |
| `OutputDirButton` | **Output directory** | Choose the folder where results are written. Shown in `OutputDirName`. |
| `OutputDirName` | *(label, shows "none")* | The current output directory. |
| `createConfigFile` | **Edit config** | Open the [Config window](#4-configuring-a-simulation--the-config-window) to enter or edit parameters. |
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

## 4. Configuring a simulation — the Config window

The **Config** window is where a simulation is defined. It is organised into
groups; this chapter follows those groups. For each option the tables give the
**label** you see, the **internal name** (useful when reading or editing a
configuration file — see [§10.1](#101-configuration-command-file)), and its
meaning.

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

| Option | Label | Meaning |
|---|---|---|
| `LIFE_EXPECTANCY_AT_BIRTH_WOMEN` | **e0 women** | Female life expectancy at birth, *e₀*. |
| `LIFE_EXPECTANCY_AT_BIRTH_MEN` | **e0 men** | Male life expectancy at birth, *e₀*. |

Mortality is applied through survival schedules derived from these life
expectancies (see [§8.4](#84-mortality)).

### 4.5 Union fertility (a priori)

This group defines the *target* fertility of a union before contraceptive
behaviour is applied.

| Option | Label | Meaning |
|---|---|---|
| `PPR_TARGET` | **PPR values as target** | Treat the a-priori PPRs as a target the simulation must reproduce (the program iterates to hit them). |
| `APRIORI_PPR` | *(value list)* | The a-priori parity progression ratios by parity. |
| `CTFR` | **CTFR** | Completed total fertility implied/targeted for the union. |
| `NSTEP_CONTRACEPTION` | **Contraception steps** | Number of iteration steps used when fitting contraception to the fertility target. |

### 4.6 Contraception use

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

Postpartum amenorrhea is modelled with the **Lesthaeghe–Page** formulation.

| Option | Label | Meaning |
|---|---|---|
| `AMENO_ALPHA` | **Alpha** | α parameter of the Lesthaeghe–Page amenorrhea model. |
| `AMENO_BETA` | **Beta** | β parameter of the Lesthaeghe–Page amenorrhea model. |
| `NSTEP_AMENORRHEA` | **NSteps** | Iteration steps for the amenorrhea fit. |
| `FIXED_AMENORRHEA` | **Same duration of amenorrhea for all** | Use a single fixed amenorrhea duration for every woman instead of the model. |
| `ZERO_FIXED_AMENORRHEA_` | **Duration amenorrhea** | The fixed amenorrhea duration (used when the box above is ticked). |

### 4.8 Nuptiality (unions)

**Women — first union**

| Option | Label | Meaning |
|---|---|---|
| `MEAN_AGE_UNION` | **Age first union** | Mean age at first union (women). |
| `STD_DEV_AGE_UNION` | **Std dev** | Standard deviation of age at first union. |
| `EVER_INUNION_PROP` | **Prop. ever in union** | Proportion of women ever entering a union. |
| `MEAN_AGE_UNION_HIGH`, `EVER_INUNION_PROP_HIGH` | **Max value** | Upper values used when a parameter is varied across its range. |

**Men — first union**

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
| `EDUCATION` | **EDUCATION** *(combo)* | Selects the education-status model. Education status is a categorical attribute (the code uses levels **B**, **M**, **A** — *`[TODO: confirm these stand for Basic / Medium / Advanced and document the available choices in the combo]`*). |

Education status is assigned to individuals and can be inherited/correlated
between parents and children (see [§8.5](#85-education)).

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
| `LowLevelOptions` | **Low Level Options** | Open the [LowLevel window](#5-low-level-biological-options--the-lowlevel-window). |
| `OutputOptions` | **Output Options** | Open the [Outputs window](#6-outputs--the-outputs-window). |

---

## 5. Low-level (biological) options — the LowLevel window

The **LowLevel** window holds the biological and performance options that most
users leave at their defaults. It is reached from **Low Level Options** on the
Config window.

### 5.1 Fecundability

These choose how *fecundability* (monthly conception probability) varies between
women. *`[TODO: confirm these are mutually exclusive — i.e. they behave as a radio
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

## 6. Outputs — the Outputs window

The **Outputs** window selects which results are produced. It is reached from
**Output Options** on the Config window. The **All / none** button toggles a
whole section at once.

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

The **Select optional fields** dialog toggles the columns written for each kin in
the kinship microdata file:

Year of birth (integer), Month of birth, Year of birth (float), Number of
children, Birth order, Age difference with ego, Age at death, Age at union(s), Age
at end of union(s), Cause of end of union(s), Age of mother at childbirth, Age of
father at childbirth, Educational status, Demographic-regime cohort, Mother union
index, Share of inheritance (heirs), Heirs, KinType of heirs, Decedents, Share
(decedents), KinType of decedents.

### 6.5 Inheritance

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

| Tab | Shows |
|---|---|
| **Child / Groom** | The cohort/age ranges of children and grooms accessed by the backward algorithm (a diagnostic that the year ranges are wide enough). |
| **Inputs** | The input schedules currently in effect. |
| **Inputs (variation)** | How inputs vary across the simulated range/cohorts. |
| **Outputs — fertility** | Fertility results from the completed run(s). |
| **Outputs — kinship** | Kinship results from the completed run(s). |

Graphs reflect the runs accumulated since the last **Reset run count**.
*`[TODO: detail exactly which series each tab draws.]`*

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

(See [Appendix B](#appendix-b--key-constants) for the full list.)

### 8.2 Fertility

A woman's reproductive life is simulated month by month inside her union history.
The core of each interval is a **conception → pregnancy → birth → postpartum
amenorrhea → return to susceptibility** cycle, recorded per child in the
`InfoChildType` structure (month of fecundation, month pregnancy ends, month of
the next ovulation, birth order, ages of mother and father, and — for a
spontaneous abortion or stillbirth — a non-positive age at death).

The biological and behavioural ingredients are:

- **Fecundability** — the monthly conception probability. It can be homogeneous
  across women, vary by drawing a relative level from a Gaussian/Beta law, or be
  reshuffled each interval (the choices in [§5.1](#51-fecundability)). Each woman
  carries an age schedule of fecundability and a relative level
  (`FecundLifeType.levelFecundabilityAge`, `.relativeFecundabilityLevel`).
- **Sterility** — a per-woman age of permanent sterility
  (`FecundLifeType.ageSterile`) drawn from the selected age schedule
  (Leridon 2008, KinFert's own, optionally zero before 25, optionally held
  constant after 25 — see [§5.2](#52-sterility)).
- **Postpartum amenorrhea** — the non-susceptible interval after a birth, from the
  **Lesthaeghe–Page** model with parameters α (`AMENO_ALPHA`) and β
  (`AMENO_BETA`), or a single fixed duration.
- **Contraception** — couples may use contraception **before** the first union,
  **after** the first union before the first wanted birth, to **space** births,
  and to **stop** childbearing. Spacing lengthens intervals (with a waiting time);
  stopping ends childbearing once desired family size is reached (the `stopping`
  flag in `FecundLifeType`).

The *a-priori* fertility of a union is built from the **parity progression
ratios** (`APRIORI_PPR`) — the program computes an a-priori distribution of
completed family size from the PPRs and the associated **CTFR**. When **PPR values
as target** (`PPR_TARGET`) is set, the program *iterates* (over `NSTEP_…` steps)
on contraceptive parameters until the simulated PPRs reproduce the target; the
fitted values are stored as **adjusted values** (see
[§8.8](#88-targets-iteration-and-adjusted-values)).

*`[TODO: confirm the conception model (e.g. whether intra-uterine mortality and
the waiting-time-to-conception distribution are Erlang/Poisson — the option
"waitingTimeErlangPoisson" exists in the code), and the exact role of the
"spacing/stopping/waiting-time" value lists.]`*

### 8.3 Nuptiality

Unions are governed by `NuptialitySettings` and `separationSettings`:

- **Entry into first union** — driven by the **mean age at union**, its **standard
  deviation**, and the **proportion ever in union**, separately for women and men.
  Setting **Same age at union for all** (`FIXED_AGE_UNION`) collapses the age
  distribution to a single value. A cross-tabulation
  (`union_women_men` / `union_men_women`) matches the ages of brides and grooms.
- **Separation** — a monthly separation risk built from a median and shape
  parameter (`separation_median`, `separation_shape`) and an overall frequency
  (`freqSeparation`); second and later unions carry a **relative risk**
  (`SECOND_SEPARATION_REL_RISK`), and the risk also depends on the number of
  children and the union duration.
- **Repartnering** — after **separation** and after **widowhood**, with
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

Each individual receives an **education status** — a categorical attribute stored
as a short string (the code uses levels **B**, **M**, **A**). Status can be drawn
stochastically, by cohort, or conditioned on the parents' education (the
`edStatus…` functions, including a parent→child transmission). *`[TODO: confirm the
meaning of B/M/A and the transmission model.]`*

### 8.6 The kinship algorithm

To give an **ego** a complete kin network, KinFert combines forward and backward
simulation:

1. **Backward (ancestors).** Ego is generated by a **possible mother** drawn from
   a pool of women (`NUMBER_WOMEN`); that mother is in turn generated by a
   **possible grandmother**. The program reconstructs ancestors **upward for two
   generations** (parents and grandparents), as described in the header of
   `Kinship.pas`. Several variants of this backward step exist —
   `gBACKFOR_mode`, `gCAMSIM_1987`, `gCAMSIM_1993` (and an *unbounded* 1993
   variant) — reflecting the **BACKFOR** and **CAMSIM** lineages of kinship
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

*`[TODO: confirm which backward variant is the current default
(`gCAMSIM_1993_unbounded` is initialised true in the code) and summarise the
differences between BACKFOR, CAMSIM-1987 and CAMSIM-1993.]`*

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

Several inputs can be supplied either directly or **as a target** to reproduce:

- **PPR target** (`PPR_TARGET`) — iterate contraception until the simulated PPRs
  match the a-priori PPRs.
- **Separation target** (`SEP_TARGET`) — iterate until the separation frequency
  matches.

The number of iteration steps is set by the various **NSteps** fields
(`NSTEP_CONTRACEPTION`, `NSTEP_AMENORRHEA`, `NSTEP_SEPARATION`, `NSTEP_UNION_*`).
The fitted results are the **adjusted values** and can be written out with **Write
adjusted values** ([§6.3](#63-general-output-options)). Parameters with **Low** and
**High** variants (e.g. `MEAN_AGE_UNION` / `MEAN_AGE_UNION_HIGH`) can be swept
across a range in the corresponding number of steps.

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

Three phases can run in parallel — demographic-regime initialisation, motherhood
initialisation, and kinship simulation — under the master `MULTITHREADING` switch,
with a configurable thread cap and optional batching ([§6.6](#66-multithreading)).

---

## 9. Kin taxonomy reference

KinFert recognises the following kin types (enumeration `KinTypes`, with the
display names from `str_kinship`). Ego's network is built from the subset you
choose under **Select kin to simulate**.

| Internal name | Display name | Branch |
|---|---|---|
| `kt_ego` | ego | — |
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
removed — i.e. the program does not extend descendants below these.

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
  [4](#4-configuring-a-simulation--the-config-window)–[6](#6-outputs--the-outputs-window)
  (e.g. `LIFE_EXPECTANCY_AT_BIRTH_WOMEN`, `MEAN_AGE_UNION`, `SEPARATION`).
- **Tabular parameters** — the value-list inputs such as the a-priori PPRs,
  stopping efficacy, spacing proportions and waiting times — are written as
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

- **Adjusted values** (`WRITE_ADJUSTED_VALUES`) — the fitted fertility and
  separation values from the target iterations ([§8.8](#88-targets-iteration-and-adjusted-values)).
- **Log** (`SAVE_LOG`, or **Save output log**) — the run log.

---

## 12. Tutorial — a first simulation

A minimal end-to-end run (generic; adapt the numbers to your study):

1. Start KinFert. On the main window click **Edit config**.
2. Under **Model type**, tick **Fertility** and **Kinship**.
3. Under **Cohorts simulated**, set **First**, **Last** and **Step** (for a single
   cohort, set First = Last).
4. Set **Mortality** (e0 women/men), the **a-priori PPRs** (or a **CTFR** with
   **PPR values as target**), and the **Union** parameters (mean age at union,
   proportion ever in union).
5. Set **Number of Egos** (start small, e.g. a few thousand, to test quickly).
6. Click **Output Options** and tick a few results — e.g. **Cohort TFR**, **Parity
   by age**, **Kin Statistics** — then **OK**.
7. **Save config file**, then **OK** to close the Config window.
8. On the main window click **Output directory** and choose a folder.
9. Click **run simulation**. Watch the log and progress bar.
10. When done, confirm the **error status** is not red, open **Graphs**, and find
    the result files in your output directory.

*`[TODO: replace this with a concrete worked example using a real configuration
file and expected output figures, so users can verify their build reproduces
known results — this also doubles as a regression test.]`*

---

## 13. Troubleshooting

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

## 14. Appendices

### Appendix A — Parameter glossary (demographic regime)

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

### Appendix B — Key constants

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

### Appendix C — Source-module map

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

### Appendix D — Glossary

*Fecundability, sterility, amenorrhea, parity, PPR, CTFR, nuptiality, spacing,
stopping, ego, cohort, demographic regime* — see [§1.4](#14-key-concepts-and-terminology).

### Appendix E — References

The model draws on established demographic methods named in the code:

- **CAMSIM** and **BACKFOR** — kinship microsimulation by backward projection.
- **Leridon (2008)** — age schedule of sterility.
- **Lesthaeghe–Page** — postpartum amenorrhea.

*`[TODO: add full bibliographic citations for these and any others (e.g. the
fecundability / waiting-time and union-formation models).]`*

### Appendix F — Open questions for the author

The following points need your confirmation to finish the manual:

1. Exact **Lazarus and FPC versions** for the build ([§2.1](#21-requirements)); a documented **release build mode** ([§2.4](#24-compiler-options-used)).
2. The **conception / waiting-time** model and the precise role of spacing/stopping/waiting-time value lists ([§8.2](#82-fertility)).
3. The **repartnering hazard** shape and age-versus-duration dependence ([§8.3](#83-nuptiality)).
4. The **e₀ → survival** mapping (model life-table family) ([§8.4](#84-mortality)).
5. The meaning of education levels **B / M / A** and the transmission model ([§8.5](#85-education)).
6. The current **default backward variant** and a summary of BACKFOR vs CAMSIM-1987 vs CAMSIM-1993 ([§8.6](#86-the-kinship-algorithm)).
7. The **country inheritance rule sets** and the share formula ([§6.5](#65-inheritance), [§8.7](#87-inheritance)).
8. Exact **file grammars**: configuration file lines and an example ([§10.1](#101-configuration-command-file)), cohort-file block layout ([§10.2](#102-cohort--demographic-regime-data-file)), and the column layouts of the aggregate tables and microdata files ([§11](#11-output-file-formats)).
9. The available **drop-down values**: education model, fixed-fertility value, kinship file format ([§4.10](#410-education), [§4.12](#412-model-options-and-other-options), [§6.4](#64-kinship-outputs)).
10. A concrete **worked example** with known outputs for the tutorial / regression test ([§12](#12-tutorial--a-first-simulation)).

---

*End of draft.*

