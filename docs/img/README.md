# Manual screenshots

This folder contains the screenshots used by
[`../KinFert-Manual.md`](../KinFert-Manual.md). The manual already refers to each file
by name, so a PNG dropped here under the matching name appears by itself, on GitHub and
in a local Markdown preview. Until the file is there the manual shows a broken image,
which is the current state of most of this list.

## How to capture them

- **Format:** PNG, which keeps the text crisp.
- **Partial is fine.** Crop each shot to the window or the group of options named in the
  list, not the whole screen.
- **Keep the files small**, since they are committed to the repository. A shot that has
  to be scaled down in the manual can be referred to with an `<img width=...>` tag.
- **Naming:** lower case, hyphenated, exactly as the list gives it.
- The manual also carries, under each slot of chapters 13 and 14, an italic line saying
  what that capture must contain. Delete the line once the file is in place.
- The two guided chapters are written around their figures, and the shots of each one are
  most easily taken in one sitting while carrying out that chapter's worked example, in
  the order of the list.

## The list: 47 files, 47 still to make

In the order in which the manual uses them. Tick a line when the file is in this folder.

### Chapter 3: the main window

- [ ] **`main-window.png`** (§3.1): The main *Kinfert* window (Read config, Output directory, Edit config, run simulation, log).

### Chapter 4: the Config window

- [ ] **`config-overview.png`** (§4): The whole Config window.
- [ ] **`config-cohorts.png`** (§4.3): The *Cohort demographic regime* / *Cohorts simulated* area (First/Last/Step, Read/Create cohorts).
- [ ] **`config-mortality.png`** (§4.4): The *Mortality* group (e0 women, e0 men).
- [ ] **`config-fertility-apriori.png`** (§4.5): The *Union fertility (apriori)* group (PPR target, a-priori PPRs, CTFR).
- [ ] **`config-contraception.png`** (§4.6): The *Contraception use* group (efficacy, time/prop after union, stopping, spacing, waiting time).
- [ ] **`config-amenorrhea.png`** (§4.7): The *Amenorrhea* group (Lesthaeghe–Page α/β, fixed amenorrhea).
- [ ] **`config-nuptiality.png`** (§4.8): The *Union* group (women/men ages, separation, second unions, widowhood).

### Chapter 5: the LowLevel window

- [ ] **`lowlevel-window.png`** (§5): The LowLevel window (fecundability, sterility, kinship base numbers, fertility iteration).

### Chapter 6: the Outputs window

- [ ] **`outputs-window.png`** (§6): The Outputs window (fertility tables, general, kinship, inheritance, multithreading).
- [ ] **`kin-output-fields.png`** (§6.4.1): The *Select optional fields* dialog. Used again at §14.9.
- [ ] **`outputs-inheritance.png`** (§6.5): The *Inheritance* group of the Outputs window. Used again at §14.10.
- [ ] **`heirs-set.png`** (§6.5): The *Set of possible heirs* dialog (the *decedents* dialog is identical). Used again at §14.10.

### Chapter 7: the Graphs window

- [ ] **`graphs-window.png`** (§7): The Graphs window with its five tabs.

### Chapter 9: the kin taxonomy

- [ ] **`kin-selection.png`** (§9): The *Select kin to simulate* dialog (full kin-type list). Used again at §14.5.

### Chapter 13: experimenting with the fertility model

- [ ] **`fert-01-main-window.png`** (§13.2): The main window with an output directory chosen and no run yet made, so the log and the error indicator are empty.
- [ ] **`fert-02-model-type.png`** (§13.2): The *Model type* group of the Config window with **Fertility** ticked and **Kinship** cleared.
- [ ] **`fert-03-single-cohort.png`** (§13.2): The *Cohorts* group with First equal to Last, Step at 1, and no cohort file loaded.
- [ ] **`fert-04-outputs-minimal.png`** (§13.2): The Outputs window with only *Cohort TFR*, *Parity by age* and *General Fertility* ticked.
- [ ] **`fert-05-log-done.png`** (§13.2): The main window after a completed run, log scrolled to the closing lines, error indicator not red.
- [ ] **`fert-06-apriori-ppr.png`** (§13.3): The *Union fertility (apriori)* group with a set of PPRs entered and the implied CTFR beside them.
- [ ] **`fert-07-contraception.png`** (§13.3): The *Contraception use* group, filled as in the worked example of §13.11.
- [ ] **`fert-08-lowlevel-biology.png`** (§13.3): The fecundability and sterility groups of the LowLevel window.
- [ ] **`fert-09-nuptiality.png`** (§13.3): The *Union* group with the women's mean age at union, standard deviation and proportion ever in union.
- [ ] **`fert-10-targets.png`** (§13.4): *PPR values as target* together with *Separation freq. as target* and the SEPARATION_ADJUSTED field.
- [ ] **`fert-11-target-log.png`** (§13.4): The log of a run with both targets on: the separation trials and the PPR adjustment line for one cohort.
- [ ] **`fert-12-steps-fields.png`** (§13.5): The group holding the seven numbers of steps, with one of them set above 1.
- [ ] **`fert-13-low-high.png`** (§13.5): MEAN_AGE_UNION and MEAN_AGE_UNION_HIGH filled with different values, which defines the range of the first sweep.
- [ ] **`fert-14-graph-inputs-variation.png`** (§13.6): The *Inputs (variation)* tab of the Graphs window after a sweep.
- [ ] **`fert-15-graph-outputs-fertility.png`** (§13.6): The *Outputs: fertility* tab after the same sweep.
- [ ] **`fert-16-table-output.png`** (§13.7): One fertility result file open in a spreadsheet or text editor, showing the layout of a result table.
- [ ] **`fert-17-indiv-options.png`** (§13.8): The *Individual fertility microdata* group, with the extended file and survey options visible.
- [ ] **`fert-18-indiv-file.png`** (§13.8): The head of an individual fertility file, enough rows and columns to show the structure.
- [ ] **`fert-19-log-check.png`** (§13.10): A log containing one of the verification messages, with the error indicator red.

### Chapter 14: working with the kinship model

- [ ] **`kinship-01-network-example.png`** (§14.1): One ego's genealogy, drawn by hand or with a genealogy viewer reading the GEDCOM output.
- [ ] **`kinship-02-model-type.png`** (§14.3): The *Model type* group with both **Fertility** and **Kinship** ticked.
- [ ] **`kinship-03-sizes.png`** (§14.3): The *Number of Egos* field and the *Number of mothers / brides* field, composed into one image if possible.
- [ ] **`kinship-04-outputs.png`** (§14.3): The *Kinship* group of the Outputs window with *Kin Statistics* and *Kin Distribution* ticked.
- [ ] **`kinship-06-mother-algorithm.png`** (§14.6): The group of the Utiles window holding the five algorithm checkboxes and the unbounded age at union option.
- [ ] **`kinship-07-graph-child-groom.png`** (§14.7): The *Child / Groom* tab of the Graphs window after a kinship run, accessed range well inside the available one.
- [ ] **`kinship-08-coverage-report.png`** (§14.7): The index coverage lines of the log, from a run where some unions were not found, so the advice text is visible.
- [ ] **`kinship-09-table-output.png`** (§14.8): One kinship result file open in a spreadsheet, showing the layout and the header rows.
- [ ] **`kinship-10-graph-outputs.png`** (§14.8): The *Outputs: kinship* tab of the Graphs window.
- [ ] **`kinship-11-indiv-options.png`** (§14.9): The *Individual results* row of the Kinship group with the *File format* combo open, showing the three formats.
- [ ] **`kinship-13-indiv-file.png`** (§14.9): The head of an individual kinship file in the ego genealogy format, enough rows for two complete egos.
- [ ] **`kinship-16-multithreading.png`** (§14.11): The *Multithreading* group of the Outputs window.
- [ ] **`kinship-17-progress.png`** (§14.11): The main window during a kinship run, progress bar part way, log showing the running count of ego trees.

Four slots of chapter 14 deliberately reuse a capture listed earlier rather than asking
for a new one, which is why the numbering of the `kinship-` files has gaps at 05, 12, 14
and 15.
