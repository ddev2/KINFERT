# Annex. The five algorithms for building ascendant genealogies implemented in KINFERT

*Draft for the methodological annex. [REF] marks the places where the published source should be
cited. The algorithm names are those used in the program and in its output files.*

## The problem the backward step has to solve

A kinship microsimulation that starts from a reference individual, ego, has to construct
ascendants rather than descendants. The forward direction is straightforward: given a woman, a
date of birth and a set of rates, her union and reproductive history can be simulated month by
month. The backward direction is not. Given an individual born in year *t*, the model must supply
a mother whose history is consistent with a birth in that year, and must do so with the right
probability. The mother of a given individual is not a randomly chosen woman of the preceding
generation: an individual is more likely to have been born to a woman with many children than to a
woman with few, so the selection has to be proportional to births and not to women. The five
algorithms below are five answers to that requirement. KINFERT implements all five, one of which
is chosen for a run, so that one configuration can be simulated five times and compared.

## KINFERT

A pre-simulation stage builds a pool of women by birth cohort, each with a complete union and
reproductive history, and indexes every live birth by its year of occurrence. To find the mother
of an individual born in year *t*, one birth is drawn from the index cell for *t* and the woman
who bore it becomes the mother. Since the index holds one entry per birth, a woman is drawn with
probability proportional to the number of births she had in year *t*, which is the weighting the
backward step requires; no correction is needed and none is applied. The birth drawn is then
identified with the reference individual, and that single draw fixes the mother's age at
childbearing, her year of birth, her whole sequence of unions with the ages at union of both
partners, and the complete set of the individual's siblings. Nothing is rejected and nothing is
re-simulated, so one ascendant costs one draw and one traversal of a list of children. The same
pool serves every generation of ascendants and every ego, which is what makes genealogies three
generations deep affordable.

## BACKFOR (Le Bras) [REF]

The backward-forward method answers the backward question by forward simulation and rejection. An
age at childbearing *a* is drawn, which fixes the mother's cohort at *t* − *a*; an age at first
union *u* ≤ *a* is drawn from the proportions single by age of that cohort; then the complete
reproductive life of a woman of that cohort entering a first union at *u* is simulated repeatedly
until one such life contains a birth at exactly age *a*. That woman becomes the mother and the
birth at age *a* becomes the reference individual. The age at union of her partner is redrawn at
every trial, so it is a result rather than an input, as in the original description. In KINFERT
the distribution from which *a* is drawn is not a tabulated schedule but the pool itself: a birth
of year *t* is drawn and the age of its mother taken, which is the empirical distribution of ages
of mothers at the births of that year.

## BACKFOR mixed

This variant keeps the first two steps of BACKFOR, the age at childbearing and the independent
draw of an age at first union, and then takes the mother from the pre-simulated pool rather than
simulating until a match. A second index is built for it, keyed on the child's year of birth and
on the mother's age at union in the union in which that child was born. The variant is therefore
KINFERT's pool combined with BACKFOR's independent draw of the age at union, and the comparison
between the two isolates the effect of that single difference. The effect is not neutral. An age
at union drawn from the proportions single of the cohort is correct for the female population but
not for the mothers of egos, who are more often women of high fertility and therefore women who
entered a union younger than average. KINFERT obtains the age at union as a property of a woman
selected in proportion to her births, so it carries that association; BACKFOR mixed removes it.

## CAMSIM 1987 [REF]

The first CAMSIM procedure draws no age at childbearing. The reproductive life of a woman is
simulated until she has at least one live birth, and one of her children is then drawn at random
and identified with the reference individual, so the age at childbearing is an output rather than
an input and the mother's year of birth is set from it afterwards. The consequence for the
weighting is the reverse of the one just described: each simulated mother contributes exactly one
reference child whatever her parity, so mothers are drawn with equal probability instead of in
proportion to their births, and the parity distribution of the mothers of egos reproduces that of
all mothers rather than the birth-weighted distribution the backward step requires. In the KINFERT
implementation the woman is simulated with the rates of her own child's cohort, since her cohort
is not known beforehand; under a stable population this has no effect, and the comparison runs are
stable population runs.

## CAMSIM 1993 [REF]

The revised procedure restores the parity weighting in three stages. A number of children *n* is
drawn from a distribution of births by parity of the mother, which is birth-weighted by
construction; an age at childbearing *a* is drawn from the mothers of parity *n*; and a mother is
then sought by simulation, as in BACKFOR, among women with a birth at age *a*, a birth order being
drawn within her children at each trial. It therefore combines a birth-weighted selection on
parity with a rejection loop on the age at childbearing, at the cost of two nested sources of
rejection.

## What the comparison measures

The five differ in one respect that reaches every kinship measure: how the mother is selected from
the women of the preceding generation, and therefore which associations between fertility, parity
and age at union are transmitted into the genealogy. KINFERT selects in proportion to births and
carries those associations. CAMSIM 1987 selects uniformly over mothers and carries neither.
CAMSIM 1993 restores the weighting on parity but not the association with the age at union.
BACKFOR mixed keeps the pool but breaks that association. BACKFOR reconstructs a mother by
rejection. Run on one configuration file with one random seed, the differences between their
outputs measure the effect of the selection rule and of nothing else.

## Implementation status, September 2026

| Algorithm | Selection of the mother | Pre-simulated pool | State |
| --- | --- | --- | --- |
| KINFERT | proportional to births of the year | yes | in use; the published results rest on it |
| BACKFOR | rejection on the age at childbearing | for the age at childbearing only | repaired, compiles, not yet run |
| BACKFOR mixed | pool, age at union drawn independently | yes, second index | repaired, compiles, not yet run |
| CAMSIM 1987 | uniform over simulated mothers | no | repaired, compiles, not yet run |
| CAMSIM 1993 | parity first, then rejection | yes, parity index | repaired, compiles, not yet run |

The four alternates had fallen out of use and none was in working order before September 2026.
Each held at least one loop without an upper bound or one index that could leave its array, and
two of them drew from a distribution other than the one intended. All four have now been repaired
and all four compile, but none has yet been run on a full configuration, so the last four rows
should be read as provisional until the five-way comparison has been carried out.
