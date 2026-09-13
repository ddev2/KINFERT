# KINFERT: the fertility functions against the current literature

A review of the empirical basis of the model's biological components, and of the
heterogeneity mechanisms it does not represent.

Prepared 8 September 2026. Four separate literature searches: fecundability and the
age decline, postpartum amenorrhoea, intrauterine mortality and fetal loss, and
omitted heterogeneity mechanisms.

A note on completeness. The fecundability and amenorrhoea searches were run first and
their full text was lost when this conversation was compacted. Sections 1 and 2 below
are therefore condensed from the findings and citations that survived. Sections 3 and 4
are complete. If either of the first two sections needs its full detail restored, the
searches can be re-run.

---

## Summary of what should change

Ranked by effect on simulated output relative to the work involved.

| Rank | Change | Section | Effort |
|---|---|---|---|
| 1 | Replace the Léridon cubic for intrauterine risk by age with the Magnus 2019 schedule | 3.1 | one table |
| 2 | Give the stillbirth age curve a J shape instead of a straight line | 3.4 | one table |
| 3 | Relabel the amenorrhoea default: the value is right for Europe, the word "weak" is not | 2 | a label |
| 4 | Verify which basis the fecundability parameter is on, and align the loss basis to it | 3.7 | reading only |
| 5 | Add lineage correlation on age at sterility, twinning and loss propensity | 4.5 | mid-parent regression |
| 6 | Add acquired and infection-driven secondary sterility | 4.3 | competing hazard |
| 7 | Woman-level frailty on postpartum amenorrhoea; interrupt it on infant death | 4.9 | one draw, one rule |
| 8 | Woman-level frailty on fetal loss, calibrated to the 10.8 / 1.9 / 0.7 triple | 3.5 | one draw plus calibration |
| 9 | Male age multiplier and couple-level fecundability | 4.2 | one factor |
| 10 | Month-of-gestation-at-loss distribution: cosmetic only, see the correction below | 3.3 | one vector |

**Correction, 9 September 2026.** The first draft of this document ranked the month-of-loss
distribution first and recommended lengthening the amenorrhoea default. Both were wrong, and
both were corrected after reading the code rather than assuming what it contained.

On the month of loss: KINFERT's table is not Shapiro-type. It puts 84 per cent of losses in
the first three months, against a modern 85 to 90, so the first-trimester split is already
right. Its mean is 2.155 months from conception against about 2.29 for the modern data, and
the mean is the only feature that reaches fertility, through the non-susceptible period. The
difference is a tenth of a month per loss, which is negligible. The table is in fact an exact
geometric series with ratio 0.55 truncated at eight months, so it assumes a constant monthly
hazard where the real hazard falls by more than an order of magnitude across the first
trimester, and its mode is month 1 where the data put it in month 2. That affects the shape of
the plotted curve, not the simulated fertility.

On amenorrhoea: the default alpha of -1.18174164 solves to a median of exactly 5.0 months and
a mean of 7.33 on the standard the code ships, which by Bongaarts and Potter corresponds to
about 12 months of breastfeeding. That is the western European mainstream and it should not be
changed. The earlier recommendation compared a sub-Saharan mean with a European median, and
imported a breastfeeding regime that is not the European pattern. What is wrong is only the
label: "weak" in the Lesthaeghe and Page sense means a median of 1.5 to 3 months. See section 2.

On the age schedules: the Léridon cubic has no minimum, runs about 35 per cent above the
observed level through the twenties, and understates the rise after 38 (0.315 against 0.536 at
age 45). That is the change that matters, and it is now first.

Three things the review says **not** to do: do not add an effect of the preceding
interval on loss risk (the meta-analytic association runs the other way); do not add an
explicit parity effect alongside a frailty term (the frailty generates it by selection);
do not import the day-specific fertile-window literature into a monthly model.

---

## 1. Fecundability and the age decline

### What the model does

A truncated-normal multiplier drawn once per woman and held for life, combined with an
age threshold, and a deterministic taper over 12.5 years before sterility. Three
alternative sterility tables: Pittinger and Wood, Leridon, and the model's own.

### What the literature says

**The multiplier's distribution.** The truncated normal has no empirical warrant. The
current standard is an age-varying zero-inflated beta, which separates a point mass of
sterile or effectively sterile women from a beta-distributed fecundability among the
rest. Konishi, Iwata and colleagues published α, β and the zero-inflation probability q
by age group, fitted to Japanese time-to-pregnancy data:

> Konishi S, et al. (2021) Fecundability and sterility by age: estimates using time to
> pregnancy data of Japanese couples trying to conceive their first child with and
> without fertility treatment. *International Journal of Environmental Research and
> Public Health* 18(10): 5486. doi:10.3390/ijerph18105486

A beta distribution is a better fit than a truncated normal on first principles as well,
since fecundability is a probability bounded on (0,1) and the empirical distribution is
right-skewed.

**The sterility schedule.** Refit to Eijkemans and colleagues, who used 58,051 women
from six historical natural-fertility populations to construct the distribution of age
at last birth. Of women reaching age 20, about 98 per cent had at least one child. The
cumulative proportion reaching the end of fertility was 4.5 per cent by age 25, 7 per
cent by 30, 12 per cent by 35, 20 per cent by 38, about 50 per cent by 41, almost 90 per
cent by 45, approaching 100 per cent by 50.

> Eijkemans MJC, van Poppel F, Habbema DF, Smith KR, Leridon H, te Velde ER (2014) Too
> old to have children? Lessons from natural fertility populations. *Human Reproduction*
> 29(6): 1304-1312. doi:10.1093/humrep/deu056

Note that age at last birth convolutes falling fecundability with the censoring of
exposure, so it is a target for the joint action of fecundability, sterility and fetal
loss, not for the sterility table alone.

**Drop the deterministic 12.5-year taper.** Dunson, Baird and Colombo found baseline
sterility of about 1 per cent regardless of age up to 40, while twelve-cycle infertility
rose from 8 per cent at ages 19 to 26, to 13 or 14 per cent at 27 to 34, to 18 per cent
at 35 to 39. The age effect is on the level of fecundability, not on a march toward
absolute sterility.

> Dunson DB, Baird DD, Colombo B (2004) Increased infertility with age in men and women.
> *Obstetrics and Gynecology* 103(1): 51-56.

**Keep Léridon's absolute level.** Nothing in the modern literature displaces it for a
natural-fertility population.

**Validation target.** Time to pregnancy can be checked against current-duration
estimates, which avoid the recall and selection problems of retrospective TTP.

> Slama R, et al. (2012) Estimation of the frequency of involuntary infertility on a
> nation-wide basis. *Human Reproduction* 27(5): 1489-1498.

**What not to import.** The day-specific fertile-window literature does not belong in a
monthly model. Near-perfect timing of intercourse is worth a fecundability ratio of only
1.25 to 1.48, so the whole of the timing dimension is bounded well inside the variance
the monthly multiplier already carries.

> Stanford JB, et al. (2019) Fecundability in relation to use of fertility awareness
> indicators in a North American preconception cohort study. *Fertility and Sterility*
> 112(5): 892-899.

---

## 2. Postpartum amenorrhoea

### What the model does

The Lesthaeghe and Page relational logit,
`temp := alpha + beta * 0.5 * ln(S/(1-S)); p := exp(2*temp)/(1+exp(2*temp))`,
with AMENO_ALPHA = -1.18174164 and AMENO_BETA = 1.0, described in the code as
"Weak: median month between 5 and 6 months".

### What the literature says

**Keep the functional form.** Nothing has superseded the relational logit as a compact
one-parameter representation of the amenorrhoea survival curve. This part of the model
needs no structural change.

**Recalibrate alpha.** Three separate reasons converge on the same conclusion, that the
default is too short:

1. The Bongaarts and Potter relationship between breastfeeding duration and amenorrhoea,
   from which many defaults descend, overstates amenorrhoea by a median of about 7 months
   in Asian settings.

   > Todd N, Lerch M (2021) Socioeconomic development predicts a stronger contraceptive
   > effect of breastfeeding. *Proceedings of the National Academy of Sciences*
   > 118(21): e2025348118. doi:10.1073/pnas.2025348118

2. Contemporary sub-Saharan DHS data give a mean duration of amenorrhoea of about 11
   months, against the model's 5 to 6 month default. For a natural-fertility application
   the 5 to 6 month figure is short by a factor of roughly two, and since amenorrhoea is
   the largest single component of the non-susceptible period, this propagates directly
   into birth intervals and completed fertility.

3. The DHS estimator is a current-status one. To compare the model against DHS figures,
   the current-status estimator must be reproduced on simulated output rather than read
   off the simulated survival curve. Comparing a mean duration from the model against a
   current-status mean from a survey is not a like-for-like comparison.

**A possible refinement: subfecundity after the return of menses.** The model treats the
return of menses as the return of full fecundability. It is not. Of women resuming
cycles postpartum, about two thirds ovulate before their first menses, but only about
half of those cycles have an adequate luteal phase.

> Bouchard T, Fehring RJ, Schneider M (2013) Efficacy of a new postpartum transition
> protocol for avoiding pregnancy. *Journal of the American Board of Family Medicine*
> 26(1): 35-44.

A short ramp of reduced fecundability over the first two or three cycles after menses
return would represent this. The calibration target is the Cochrane estimate of the
six-month pregnancy rate under the lactational amenorrhoea method, 0.5 to 2.5 per cent.

---

## 3. Intrauterine mortality and fetal loss

### 3.0 Three denominators, which must not be mixed

Published figures for "risk of fetal loss" differ by a factor of two or three depending
on the denominator:

- **All conceptions.** Roughly 40 to 60 per cent lost between fertilisation and birth
  (Jarvis 2016, *F1000Research* 5:2765). The frequently repeated figures of 70 per cent
  or more are not supported.
- **hCG-detected pregnancies.** Wilcox and colleagues followed 221 women with daily
  urinary hCG. Of 198 detected pregnancies, 31 per cent were lost in total; 22 per cent
  ended before clinical recognition; of the 155 reaching clinical recognition, 12 per
  cent were lost.

  > Wilcox AJ, Weinberg CR, O'Connor JF, et al. (1988) Incidence of early loss of
  > pregnancy. *New England Journal of Medicine* 319(4): 189-194.
- **Clinically recognised or registered pregnancies.** The 10 to 20 per cent range that
  dominates the modern literature.

### 3.1 Loss by maternal age: the schedule to adopt

The best single source is the Norwegian register: all 421,201 pregnancies 2009 to 2013,
linking the Medical Birth Register, the Patient Register and the induced abortion
register. Overall risk after correction for induced abortion, 12.8 per cent.

> Magnus MC, Wilcox AJ, Morken N-H, Weinberg CR, Håberg SE (2019) Role of maternal age
> and pregnancy history in risk of miscarriage: prospective register based study.
> *BMJ* 364: l869. doi:10.1136/bmj.l869

| Maternal age | Risk of miscarriage |
|---|---|
| Under 20 | 15.8% |
| 20 to 24 | about 11.2% |
| 25 to 29 | 9.8% |
| 27 (the minimum) | 9.5% |
| 30 to 34 | about 10.8% |
| 35 to 39 | about 16.7% |
| 40 to 44 | about 32.2% |
| 45 and over | 53.6% |

Values in the "about" rows are read from the paper's Figure 2 rather than stated in the
text. The curve is J-shaped: elevated below 20, a flat minimum from about 25 to 32, then
a rise close to exponential from the mid-thirties.

The correction for induced abortion is irrelevant in a natural-fertility application,
which is convenient: the uncorrected register risks are the ones that correspond to a
population with no induced abortion.

Two cross-checks. Quenby and colleagues pool across studies with earlier ascertainment
and report a higher level with the same shape: 12.1 per cent at 20 to 24, 11.9 at 25 to
29, 14.4 at 30 to 34, 17.9 at 35 to 39, 36.8 at 40 to 44, 65.2 at 45 and over, overall
15.3 per cent.

> Quenby S, Gallos ID, Dhillon-Smith RK, et al. (2021) Miscarriage matters: the
> epidemiological, physical, psychological, and economic costs of early pregnancy loss.
> *Lancet* 397(10285): 1658-1667. doi:10.1016/S0140-6736(21)00682-6

Nybo Andersen and colleagues (*BMJ* 2000;320:1708-1712) give 74.7 per cent at 45 and
over. That figure rests on small numbers and should not be used; Magnus, with better
denominator ascertainment, gives 53.6 per cent.

**Do not use the US survey-based schedules** (Rossen, Ahrens and Branum 2018,
*Paediatr Perinat Epidemiol* 32:19-29; Forrest et al. 2025). Their level is inflated and
their age gradient flattened by self-report. They are useful for time trend, not for
shape.

### 3.2 The age gradient is mostly aneuploidy

Aneuploidy occurs in an estimated 20 to 40 per cent of all human conceptions, with errors
almost always arising in the oocyte and an exponential rise in error rate from the
mid-thirties (Nagaoka, Hassold and Hunt 2012, *Nature Reviews Genetics* 13:493-504).

Karyotyping of 7,118 miscarriages found 67.25 per cent abnormal overall, rising from 55.4
to 69.5 per cent across ages 23 to 37 (a mean rise of 0.70 percentage points per year of
maternal age), a step to 79.0 per cent at age 38, then a rise to about 94 per cent by age
44 (2.10 points per year).

> Pendina AA, Krapivin MI, Chiryaeva OG, et al. (2025) Chromosomal abnormalities in
> miscarriages and maternal age: new insights from the study of 7118 cases.
> *Cells* 14(1): 8. doi:10.3390/cells14010008

Embryo-level screening of 15,169 biopsies gives a U-shaped age curve with a minimum
around ages 26 to 30: about 20 per cent aneuploid at 29, 30 at 31, 35 at 35, 42 at 37, 60
at 40, 90 at 44 (Franasiak et al. 2014, *Fertility and Sterility* 101:656-663).

**Functional form.** There is no single convention. Three options, in increasing order of
fidelity:

1. Two-piece linear in log-odds with a knot near age 30. Directly estimated in the China
   Birth Cohort: the odds change by a factor of 0.97 per year below the knot at 29.68
   years (not significant) and 1.25 per year above it (95 per cent CI 1.18 to 1.31).
2. Quadratic in age on the logit scale. Adequate for the broad shape, understates the
   acceleration after 40.
3. **The Wood and Boklage mixture.** Model a proportion p(a) of conceptions as
   chromosomally abnormal with a near-certain and early loss hazard, and the remainder
   with a low, age-invariant hazard. Wood's fit to Bangladeshi data put about 29 per cent
   of conceptuses in the abnormal group with 99.8 per cent mortality, against 3.4 per cent
   in the normal group.

   > Wood JW (1994) *Dynamics of Human Reproduction: Biology, Biometry, Demography*.
   > New York: Aldine de Gruyter.

Option 3 is the recommendation. It costs about the same to implement as a lookup table,
and it makes the gestational-timing distribution age-dependent automatically, which is a
real empirical feature.

### 3.3 The month of gestation at loss: the single most useful fix

Weekly hazards exceed 20 miscarriages per 1,000 woman-weeks at every week before week 13,
then fall below 10 per 1,000 from week 14 onwards.

> Ammon Avalos L, Galindo C, Li D-K (2012) A systematic review to calculate background
> miscarriage rates using life table analysis. *Birth Defects Research Part A*
> 94(6): 417-423. doi:10.1002/bdra.23014

First-trimester losses have a mean gestational age of 7.5 weeks (SD 1.7) (Essers et al.
2023, *Nature Medicine*, doi:10.1038/s41591-023-02645-5). Conditional risk falls very
steeply once a heartbeat is seen: roughly 9.4 per cent when seen at 6 weeks, 4.2 per cent
at 7, 1.5 per cent at 8, 0.5 to 0.7 per cent at 9 to 10 weeks.

A serviceable synthesis for a monthly model, as shares of **clinically recognised** losses:

| Gestational month (from LMP) | Share of recognised losses |
|---|---|
| 2 (weeks 5 to 8) | 55 to 65% |
| 3 (weeks 9 to 12) | 20 to 25% |
| 4 (weeks 13 to 16) | 6 to 9% |
| 5 (weeks 17 to 20) | 4 to 6% |
| 6 and later | 3 to 5% |

If the model instead tracks all hCG-detected pregnancies, add a first bin at month 1
carrying roughly 40 per cent of all losses, since pre-clinical losses outnumber clinical
ones.

**Is Barrett's distribution still defensible?** Partly. The schedules used in the 1970s
and 1980s microsimulations descend from Shapiro, Jones and Densen (1962, *Milbank
Memorial Fund Quarterly* 40:7-45, 6,844 pregnancies) and French and Bierman (1962, the
Kauai study).

What still holds: the overall level for recognised pregnancies, around 12 to 15 per cent;
the direction and rough size of the age gradient below 40; the monotonically declining
within-pregnancy hazard; the non-susceptible period after a loss.

What does not hold, and this is the point that matters most for KINFERT:

- **The share of losses assigned to the second trimester is far too high.** Shapiro and
  colleagues put roughly a third of losses at 12 to 19 weeks. The modern estimate is
  closer to 10 to 15 per cent. Those cohorts enrolled women at the first antenatal visit,
  typically after 10 weeks, so they missed most early losses while capturing later ones
  completely. Any distribution inherited from that literature places too much mass in
  gestational months 4 and 5. In a monthly-step model this lengthens the mean
  non-susceptible cost of each loss, which lengthens birth intervals and depresses
  completed fertility. This is a first-order bias, not a cosmetic one.
- **The acceleration after 40 is badly understated.** Shapiro's 219 per 1,000 for the
  whole 35-and-over group is far below the 33 to 37 per cent at 40 to 44 and 54 to 65 per
  cent at 45 and over that modern sources report.
- **The distributions were treated as age-invariant.** They are not. Older women's losses
  occur at earlier gestational ages, because the excess is aneuploid and aneuploid
  conceptuses fail early (Holman, Wood and Campbell 2000).

### 3.4 Stillbirth by maternal age

Definitions differ: 20 weeks or more (United States), 24 weeks (England and Wales), 28
weeks (WHO). This must be matched to the threshold the model uses.

United States 2023, fetal deaths at 20 weeks or more per 1,000 live births plus fetal
deaths (NCHS, *Fetal Mortality: United States, 2023*, NVSR 74(8)):

| Maternal age | Rate per 1,000 |
|---|---|
| Under 15 | 12.86 |
| 15 to 19 | 6.91 |
| 20 to 24 | 5.51 |
| 25 to 29 | 5.07 |
| 30 to 34 | 5.15 |
| 35 to 39 | 5.86 |
| 40 to 44 | 8.36 |
| 45 and over | 13.25 |
| All ages | 5.53 |

Pooled odds ratio for stillbirth at maternal age 35 or over, across 44 studies,
44,723,207 births and 185,384 stillbirths: 1.75 (95 per cent CI 1.62 to 1.89).

> Lean SC, Derricott H, Jones RL, Heazell AEP (2017) Advanced maternal age and adverse
> pregnancy outcomes: a systematic review and meta-analysis. *PLoS ONE* 12(10): e0186287.

**The key structural point.** The stillbirth age curve is J-shaped like the miscarriage
curve but far flatter. Between the minimum (ages 25 to 34) and ages 40 to 44, stillbirth
rises by a factor of about 1.6, against about 3.5 for miscarriage. A model that reuses
the miscarriage age gradient for stillbirth will badly overstate late loss at older ages.
The age *pattern* transfers to a historical population; the *level* does not, since the
absolute level would plausibly have been 25 to 40 per 1,000 rather than 5.

### 3.5 Recurrence: where independent draws fail

Magnus and colleagues, adjusted for maternal age:

| Prior consecutive miscarriages | Adjusted odds ratio (95% CI) |
|---|---|
| 1 | 1.54 (1.48 to 1.60) |
| 2 | 2.21 (2.03 to 2.41) |
| 3 or more | 3.97 (3.29 to 4.78) |

Quenby and colleagues, absolute risks: 11.3 per cent with no previous loss, 20.4 after
one, 28.3 after two, 42.1 after three or more.

**The calibration target.** Quenby gives the population prevalences: 10.8 per cent of
women have had one miscarriage, 1.9 per cent two, 0.7 per cent three or more.

This is the decisive arithmetic. Under independent draws with a per-pregnancy probability
around 0.15 and a realistic parity distribution, the predicted prevalence of three or more
losses in a lifetime is on the order of 0.1 to 0.2 per cent. The observed figure is 0.7
per cent, three to seven times higher. Independent draws substantially understate the
concentration of losses in a minority of women. Reproducing the 10.8 / 1.9 / 0.7 triple,
jointly with the mean, is the right test of any heterogeneity specification.

**Is the recurrence aneuploidy or maternal frailty?** Mostly frailty, which is what makes
it representable as a fixed woman-level effect. A PGT-A study of women under 38 with
recurrent loss found no association between the number of prior miscarriages and embryonic
aneuploidy (adjusted RR 0.999, 95 per cent CI 0.984 to 1.015), with aneuploidy at 26.0 per
cent in controls against 26.7 per cent in the recurrent-loss group.

This maps cleanly onto the Wood and Boklage structure: the abnormal-conceptus proportion
carries the age gradient and is close to independent across pregnancies; the
normal-conceptus hazard carries a woman-level frailty multiplier and is age-invariant.

**A caution from the demographic side.** Weinstein, Wood and Greenfield (1993, *Social
Biology* 40:106-130) conclude that heterogeneity in fetal loss affects mainly the tail of
the waiting-time distribution and explains little of the observed variation in first-birth
intervals below age 35. Heterogeneity in loss matters greatly for the distribution of
losses across women and for the tail of birth intervals; it should not be expected to move
mean fecundability or mean intervals much.

### 3.6 Paternal age, parity, preceding interval

**Paternal age: real, modest, cheap to add.** Ten studies, about 67,000 pregnancies, all
adjusted for maternal age, reference category 25 to 29:

| Paternal age | Pooled odds ratio (95% CI) |
|---|---|
| 30 to 34 | 1.04 (0.90 to 1.21) |
| 35 to 39 | 1.15 (0.92 to 1.43) |
| 40 to 44 | 1.23 (1.06 to 1.43) |
| 45 and over | 1.43 (1.13 to 1.81) |

> du Fossé NA, van der Hoorn M-LP, van Lith JMM, le Cessie S, Lashley EELO (2020)
> Advanced paternal age is associated with an increased risk of spontaneous miscarriage:
> a systematic review and meta-analysis. *Human Reproduction Update* 26(5): 650-669.
> doi:10.1093/humupd/dmaa010

The mechanism is not aneuploidy: across 10,830 embryos from young donor oocytes, the odds
ratio for aneuploidy was 0.97 per decade of paternal age (95 per cent CI 0.91 to 1.03).
Paternal age acts through sperm DNA fragmentation and de novo point mutation.

**Parity: do not add it separately.** The association largely disappears once maternal age
and prior-loss history are controlled, and it is contaminated by reproductive selection.
A frailty term generates the parity association endogenously; adding both double-counts.

**Preceding interval: do not add it.** Across 7 studies and 977,972 women, an
interpregnancy interval under 6 months after a miscarriage was associated with a *lower*
risk of further loss, RR 0.82 (95 per cent CI 0.78 to 0.86). This is almost certainly
selection on underlying fecundity, but either way there is no warrant for an interval
effect, and the sign of the observed association is opposite to the one usually assumed.

> Kangatharan C, Labram S, Bhattacharya S (2017) Interpregnancy interval following
> miscarriage and adverse pregnancy outcomes: systematic review and meta-analysis.
> *Human Reproduction Update* 23(2): 221-231.

**Return of ovulation after loss.** Donnet and colleagues (1990) followed 18 women and
found ovulation in every case before the first menses, at a mean of 29 days after the loss
(range 13 to 103). For a monthly time step, a non-susceptible period of one month after an
early loss and two months after a mid-trimester loss is consistent with the evidence, and
close to what Léridon assumed. This part of the older parameterisation stands up.

### 3.7 Which basis should the model use?

This is the question that matters most, and it costs nothing to answer.

A monthly-step natural-fertility model works with a fecundability parameter conventionally
defined as the monthly probability of a **recognisable conception**, because that is what
the classical estimates (Barrett and Marshall 1969; Léridon 1977) were fitted to. If
KINFERT's fecundability is on that basis, then the loss probabilities applied to it must
also be on that basis, that is, clinically recognised pregnancies, around 12 to 15 per
cent. Applying a 31 per cent hCG-based loss probability to a recognition-based
fecundability double-counts the pre-clinical losses, because those are already netted out
of the fecundability parameter, where they appear as apparently infertile cycles.

Three recommendations:

1. **Use the clinically recognised basis** unless fecundability has been deliberately
   re-estimated on a conception basis. Target an overall loss probability of 12 to 15 per
   cent, with the Magnus 2019 age schedule.
2. **State the basis explicitly** in the documentation and in the parameter file. The 31,
   21 and 13 per cent figures are all correct and all in current use; the errors come
   entirely from mixing them.
3. **Note that the recognition threshold has moved.** Wilcox's "clinical recognition" in
   1982 to 1986 meant a missed period plus symptoms, roughly week 6. Home tests now move
   recognition to week 4. The Norwegian register figure of 12.8 per cent is closer to the
   historically appropriate value than the pooled 15.3 per cent.

**A second, subtler point, and one to check before steepening anything.** Because older
women's losses are disproportionately early and pre-clinical, the recognised loss curve
understates the true age gradient in conception loss. Holman, Wood and Campbell argue that
most of the age-related decline in apparent fecundability *is* early fetal loss rather
than a decline in true fecundability. If KINFERT already has an age-declining fecundability
schedule fitted to observed conception data, then part of the age effect on loss is already
inside it, and adding the full modern loss gradient on top would double-count the same
biological process.

---

## 4. Heterogeneity mechanisms the model does not represent

The model carries all persistent between-woman variation in a single scalar, drawn
independently across women, orthogonal to age, parity, partner, lineage and calendar time.
The literature identifies at least sixteen further sources. They fall into three groups by
their consequence for a kinship model: those that change the mean and variance of family
size without inducing correlation between individuals; those that change the age pattern
and the timing of the end of reproduction; and those that induce correlation between
related individuals. The third group is the one that matters most for a model whose output
is a network of relatives rather than a set of period rates.

### 4.1 Coital frequency: safe to omit

The fertile window is six days and the mapping from acts per month to monthly conception
probability saturates quickly. Colombo and Masarotto found intercourse frequency not
significantly associated with fecundability once reproductive history was accounted for.
Deliberate, near-optimal timing buys a fecundability ratio of only 1.25 to 1.48 (Stanford
et al. 2019), which bounds from above what random variation in frequency can contribute in
a population where nobody is timing.

Brewis and Meyer, across 91,744 married women in nineteen countries, found the decline in
marital coital frequency with duration to be general, but that once duration is controlled,
frequency often rises as wives move into their thirties. Wood's synthesis reaches the same
conclusion: the decline is not large enough to account for more than a small part of the
age decline in fecundability.

Verdict: safe to omit. The mean is already inside the calibrated multiplier. Simulating
individual acts at a daily step would multiply computational cost by roughly thirty for no
gain. The one qualification: if the model is used to compare marriage regimes with very
different union durations at a given maternal age, add a duration multiplier on
fecundability rather than an act process.

### 4.2 Male age: worth adding

Three studies converge on a male age effect that is real, independent of female age, and
roughly a third to a half the size of the female effect over the same range. In ALSPAC
(8,515 planned pregnancies, adjusted for maternal age, parity, smoking, BMI and coital
frequency) the odds of conception within twelve months relative to men under 25 were 0.62
at ages 30 to 34, 0.50 at 35 to 39, 0.51 at 40 and over (Ford et al. 2000, *Human
Reproduction* 15:1703-1708). Dunson, Colombo and Baird, in the cleanest design (782 couples,
5,860 cycles with daily records), found fertility significantly reduced for men over 35
after controlling for the woman's age, and that the six-day window does not shorten with
age in either sex.

**Why this matters for a kinship model specifically.** Fecundability is currently a
property of the woman alone. In a population with a large and variable spousal age gap,
which is the norm historically, the model misallocates fertility: young wives of old
husbands get too high a fecundability, and the fertility of remarried older men is
overstated. The model therefore cannot generate the correct joint distribution of maternal
and paternal age at birth. Since paternal age determines the survival of grandfathers, the
age gap between paternal and maternal kin, and the length of the male generation, a model
with no male age effect systematically compresses the paternal lineage relative to the
maternal one.

Implementation: a multiplicative male-age factor on the couple's monthly conception
probability, plus a male sterility schedule. A defensible parameterisation is 1.0 to age
34, declining to about 0.6 by 45 and 0.4 by 55. Fecundability then becomes a product of a
woman-level draw and a man-level draw, which also improves remarriage: a woman leaving a
subfecund union should draw a new partner effect.

### 4.3 Acquired and infection-driven secondary sterility: the largest single omission

Frank's estimates for sub-Saharan Africa remain the reference: across eighteen countries,
infertility accounted for roughly 60 per cent of the variation in overall fertility rates
and represented an average loss of about one child per woman, with gonococcal tubal
occlusion the major cause (Frank 1983, *Population and Development Review* 9:137-144).

Larsen separates the components using DHS data: primary infertility exceeded 3 per cent in
fewer than a third of twenty-eight African countries, while secondary infertility among
women aged 20 to 44 ranged from 5 per cent in Togo to 23 per cent in the Central African
Republic. Secondary, not primary, infertility is the demographically important quantity
(Larsen 2000, *International Journal of Epidemiology* 29:285-291).

The aetiology is settled: over 85 per cent of infertile African women had a diagnosis
attributable to infection, against 33 per cent globally (Cates, Farley and Rowe 1985,
*Lancet* 326:596-598), about 70 per cent of the underlying pelvic infection from sexually
transmitted organisms and about 30 per cent from pregnancy-related sepsis.

The demographic signature is unlike a smooth age schedule in four ways. It is acquired, so
its hazard depends on exposure time and parity rather than age alone. It is partly
iatrogenic on childbearing itself, since postpartum sepsis makes each delivery a risk
factor for subsequent sterility. It is transmitted through sexual networks, so it clusters
within communities. And it is historically variable on a timescale of decades, which is the
timescale on which a kinship simulation runs.

**What its absence does.** A pure age schedule generates almost no primary childlessness
among women who marry young, and parity-specific stopping that is smooth in age. Acquired
sterility generates a fat tail of women stopping at parities two, three and four for
reasons unrelated to age, and covariance between siblings and between spouses. For kinship,
the simulated sibship-size distribution is too narrow and too unimodal, and the number of
individuals with no living descendants too small.

Implementation: a competing hazard with two components, a per-delivery hazard for
postpartum sepsis and a per-month-of-exposure hazard for sexually transmitted infection,
the latter scaled by a community-level or partner-level risk parameter to induce clustering.
For a strictly western European historical application this drops to "worth adding if
cheap", but even there the per-delivery sepsis component alone produces the parity
dependence that a pure age schedule cannot.

### 4.4 Correlation between successive intervals

The direct evidence is thinner than the question deserves. The best study is Larsen and
Vaupel's frailty analysis of 406 Hutterite women contributing 3,206 births, which finds
that effective fecundability declines with age *and with parity*, net of age, and that
women differ persistently in their level (Larsen and Vaupel 1993, *Demography*). The parity
effect net of age means successive intervals are not exchangeable given the woman's frailty
and current age: the third interval is longer than the second in a way the model will not
generate. Some of this is parity-varying amenorrhoea, which the Lesthaeghe-Page schedule
may or may not capture.

Verdict: worth adding, taken from Larsen and Vaupel directly rather than as a free
autocorrelation parameter, and added after the mechanisms in 4.3 and 4.9 so as not to
double-count.

### 4.5 Lineage correlation: the top-ranked addition for a kinship model

The literature is more divided than is usually acknowledged, and the division points to a
specific implementation.

**Age at menopause is substantially heritable.** In 932 women in extended Framingham
families, multivariable-adjusted correlations were 0.21 mother to daughter, 0.22 between
sisters, 0.12 aunt to niece, with heritability of 0.49 (95 per cent CI 0.37 to 0.61)
(Murabito et al. 2005, *JCEM* 90:3427-3430). Twin studies give 31 to 53 per cent,
sister-pair studies 70 to 85 per cent. A working figure of about 0.5 is defensible.

**Family size shows weak intergenerational correlation in contemporary populations.**
Beaujouan and Solaz report about 0.12 to 0.15 in the French Family Survey (2019,
*Demography* 56:595-619). Kolk finds associations not only with parents' fertility but
independently with grandparents' and with parents' siblings', which is a genuinely
multigenerational structure that a parent-child correlation alone will not reproduce (2014,
*Population Studies* 68:111-129).

**But the classic historical result is a null.** Langford and Wilson examined 10,931
mother-daughter pairs from English parish-register reconstitutions, sixteenth to nineteenth
centuries, and found no association between the fecundity of daughters and of their mothers
(1985, *Journal of Biosocial Science* 17:437-443). This is the single most relevant study
for a historical natural-fertility application. The reconciliation is probably that the
heritable component sits in reproductive ageing and in pathology rather than in fecundability
during the prime reproductive years.

**What its absence does.** Independent draws mean zero correlation between the completed
fertility of a mother and her daughter, and zero between sisters. The variance of the number
of descendants at generation three and beyond is too small, and the concentration of
descendants in a minority of founding lineages too weak. Since the number of cousins a person
has is a function of the fertility of their grandparents' several children, independent
sibling fertilities produce a cousin-count distribution far too concentrated around its mean.
If sibling fertilities are independent, the variance of cousin count grows like the number of
parental siblings times V; if correlated at even 0.15, it grows like the square of that
number times the correlated component.

Implementation: replace the independent draw with one that regresses on the mother's value,
and do the same for age at sterility. Kolk's finding of independent grandparental and
avuncular associations argues for a heritable latent trait rather than a lag-one correlation,
which costs nothing extra.

**One caution, and it is important for KINFERT's likely applications.** The Langford and
Wilson null means that for a strictly historical natural-fertility calibration the correlation
on fecundability itself should be set low or to zero. The transmitted component should be
placed on age at sterility, on twinning propensity and on fetal-loss propensity, where the
evidence is positive. Setting a large fecundability correlation on the strength of
contemporary intergenerational studies would import a largely behavioural mechanism into a
model that has no behavioural fertility.

### 4.6 Ovarian reserve and AMH: omit, but note what the null implies

Steiner and colleagues ran the definitive test: 750 women aged 30 to 44 with no infertility
history, trying to conceive for three months or less. Women with low AMH did not differ
significantly from women with normal AMH, 65 per cent against 62 per cent conceiving by six
cycles and 84 against 75 per cent by twelve. High FSH and inhibin B showed the same absence
of association (2017, *JAMA* 318:1367-1376). A meta-analysis of eleven studies and 4,388
women gives a pooled AUC of 0.5932 for AMH predicting spontaneous pregnancy, barely better
than chance.

The null is informative for the model's structure. If ovarian reserve predicts menopause but
not fecundability, the two are governed by partly separate processes, which supports treating
a woman's age at sterility and her fecundability level as two draws with a **weak** rather
than a strong correlation, not as two expressions of one latent "reproductive quality"
variable.

### 4.7 Twinning

Dizygotic twinning rises with maternal age and parity and is familial. Small aggregate
effect, distinctive effect on sibship structure at the tails, very cheap to add. Worth adding
if cheap, and it is one of the traits on which the lineage correlation of 4.5 should be
placed.

### 4.8 Seasonality: safe to omit

Operates entirely within the year. No effect on completed fertility, sibship size or kin
counts.

### 4.9 Amenorrhoea heterogeneity and its interruption by infant death: worth adding

Two changes, both cheap, and jointly ranked third overall.

**The persistent component.** A woman-level multiplier on the duration of amenorrhoea, drawn
at birth and applied to the location parameter of the relational logit. This is probably the
largest single source of persistent between-woman variance in birth intervals under natural
fertility, and it is entirely absent from a fixed schedule. Give it a parent-offspring
correlation, since breastfeeding practice is transmitted.

**The infant-death interruption.** On the death of an infant, terminate amenorrhoea after a
short fixed lag of one to three months rather than at the scheduled duration. This reproduces
the observed shortening of the subsequent interval, on the order of 30 per cent, and restores
the coupling between child mortality and the pace of childbearing. Without it, a kinship model
in a high-mortality regime misstates the joint distribution of surviving sibship size and
mortality experience. (KINFERT already shortens the non-susceptible period on early infant
death in `LivingBirth`, so part of this may be in place; the rule should be checked against
the one-to-three-month lag.)

### 4.10 Subfecundity before sterility: a recalibration, not a new module

The empirical consensus is unambiguous: the age effect operates through a declining level of
fecundability, not an abrupt transition to sterility, and the sterile proportion below the
late thirties is very small. Dunson, Baird and Colombo found baseline sterility of about 1 per
cent regardless of age up to 40 (see section 1).

The most interesting result is Holman and Wood's. In a one-year prospective study of rural
Bangladeshi women using hCG assays, total fecundability, meaning the monthly probability of a
detectable conception of any kind, was nearly constant from about age 20 to about 36, then
declined rapidly, approaching zero near 46. What changed with age was the fraction of
conceptuses that were abnormal and therefore lost: total conception loss rose from about 55
per cent at age 20 to about 84 per cent at 30 and about 96 per cent at 40. Maternal age
significantly affected the initial fraction of abnormal conceptuses but did not significantly
change the loss hazard within either subgroup.

> Holman DJ, Wood JW (2000) Pregnancy loss and fecundability in women. CSDE Working Paper
> 00-13, Center for Studies in Demography and Ecology, University of Washington.
>
> O'Connor KA, Holman DJ, Wood JW (1998) Declining fecundity and ovarian ageing in natural
> fertility populations. *Maturitas* 30(2): 127-136.

**What its absence does in KINFERT.** If the model imposes an age schedule of permanent
sterility while holding fecundability at the woman's lifelong multiplier, it forces all of the
age decline through the sterility hazard, producing a population in which women are fully
fecund until a discrete moment and then are not. The distribution of age at last birth then has
too little dispersion, and the model produces too few late births to old mothers and too few
very long terminal intervals. Since a woman's age at last birth determines the age gap between
her and her youngest child, and thereby whether she survives to see that child's own children,
this propagates directly into the kinship output, showing up as an understatement of the number
of children who lose their mother young.

Implementation: retain the sterility table, but multiply the woman's fixed fecundability by an
age function that is flat to about 30, declining to roughly 0.8 by 35, 0.5 by 40 and 0.2 by 45,
calibrated so that the joint action of that function, the sterility table and the intrauterine
mortality schedule reproduces the Eijkemans age-at-last-birth distribution.

**Check for double-counting first.** This is the same warning as section 3.7, from the other
side. If the intrauterine mortality schedule is already steep in age, the additional
fecundability decline should be correspondingly shallower. Pittinger and Wood's and Léridon's
schedules were both fitted with the age decline in fecundability in view, so a model using
either is not making a gross error at the aggregate level; the problem is at the individual
level and in the tails.

### 4.11 What the kinship literature says directly

Calderón-Bernal, Alburez-Gutierrez, Kolk and Zagheni compared SOCSIM-microsimulated kin counts
with register-based kin counts for Swedish birth cohorts 1915 to 2017. The result reads as a
diagnostic manual for the defects above: microsimulation reproduces **mean** kin counts well and
their **dispersion** badly, under-representing individuals with both the largest and the smallest
sets of kin. Multipartner fertility and remarriage after dissolution are identified as the
leading cause of under-counted siblings and of the near-total absence of half-kin in
microsimulated populations.

**A consequence for how KINFERT should be validated.** Every mechanism in the top tier acts on
dispersion, not on the mean. The diagnostic that will show whether these additions are working is
therefore not the mean number of cousins or of surviving siblings, but the **proportion of
simulated individuals with zero kin of a given type and the proportion in the upper decile**. If
those two move toward their empirical counterparts, the additions are earning their cost. If only
the means move, they are not.

---

## 5. Overall ranking for a kinship microsimulation

**Tier 1, change the structure of the simulated kin network:**

1. Lineage correlation in fertility and in reproductive ageing (4.5). The only mechanism that
   acts between individuals rather than within them. Place the transmitted component on age at
   sterility, twinning and loss propensity, not on fecundability.
2. Acquired and infection-driven secondary sterility (4.3). Largest effect on the tails of the
   sibship-size distribution.
3. Woman-level heterogeneity in postpartum amenorrhoea, and its interruption by infant death (4.9).
4. Male age, male sterility, and couple-level rather than woman-level fecundability (4.2).
5. Multipartner fertility and remarriage after dissolution (4.11).

**Tier 2, change the age pattern and the tails of individual fertility:**

6. Within-woman age decline in fecundability alongside the sterility schedule (4.10).
7. Parity effect on fecundability net of age (4.4).
8. Age- and parity-dependent, familially clustered dizygotic twinning (4.7).
9. Woman-level frailty on intrauterine mortality risk (3.5).

**Tier 3, real mechanisms with negligible effect on this model's outputs:**

Coital frequency (4.1), seasonality (4.8), ovarian reserve markers (4.6), adolescent
subfecundity, nutritional and workload effects, sex-preference stopping.

---

## 6. Where the model's older sources still hold

It is worth stating plainly, because the answer is mostly favourable.

- **Lesthaeghe and Page relational logit for amenorrhoea:** functional form unchallenged.
  Recalibrate alpha only.
- **Léridon's absolute level of fecundability:** stands.
- **The general architecture of the Barrett-era loss module** (conception, loss with a gestational
  duration, non-susceptible period, return to risk): nothing in the modern evidence overturns it.
- **The non-susceptible period after a loss**, one month early and two months late: confirmed by
  the modern ovulation-resumption studies.
- **The qualitative shape of the maternal-age curve for loss:** flat minimum in the late twenties,
  rise thereafter.

What does not survive is narrower and specific: the truncated-normal fecundability distribution,
the deterministic pre-sterility taper, the amenorrhoea alpha, the month-of-loss distribution, the
size of the post-40 acceleration in loss, the age-invariance of loss timing, and the assumption
that losses are independent across pregnancies within a woman.
