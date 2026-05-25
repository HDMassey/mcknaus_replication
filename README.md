# Replication of Knaus (2022) Table 4

This repository replicates Table 4, Group Average Treatment Effects, from Michael C. Knaus (2022), "Double machine learning-based programme evaluation under unconfoundedness," published in *The Econometrics Journal*. The result uses double machine learning to estimate treatment-effect heterogeneity for Swiss active labor market programs.

## Original paper

Knaus, Michael C. 2022. "Double machine learning-based programme evaluation under unconfoundedness." *The Econometrics Journal* 25(3): 602-627.

Paper URL: https://academic.oup.com/ectj/article-abstract/25/3/602/6596870?redirectedFrom=fulltext

## Result replicated

The target result is Table 4, which reports group average treatment effects for four programs relative to no program: job search, vocational training, computer training, and language courses. The table reports heterogeneity by female, foreigner status, and employability.

## Repository structure

```text
input/             Restricted raw data instructions and data dictionary
code/              R preprocessing and analysis scripts
output/figures/    Generated figures consumed by the paper
output/tables/     Generated LaTeX fragments and CSV tables consumed by the paper
temp/              Regenerable intermediate files; not tracked
paper/             LaTeX paper and compiled PDF
Makefile           End-to-end build pipeline
run_all.sh         Convenience wrapper
```

## Data

The raw data are restricted-use Swiss ALMP data from SwissUbase/FORSbase, so they are not committed to this repository. To reproduce:

1. Request access through SwissUbase/FORSbase.
2. Download `swissubase_1203_1_0.zip`.
3. Place the zip file in `input/`, or unzip it and place `1203_ALMP_Data_E_v1.0.0.csv` in `input/`.
4. Run `make`.

See `input/README.md` for details.

## Prerequisites

R packages:

```r
install.packages(c("dplyr", "grf", "lmtest", "sandwich", "glmnet", "policytree"))
# causalDML is installed from GitHub if needed:
# devtools::install_github("MCKnaus/causalDML", upgrade = "never")
```

You also need a working LaTeX installation with `pdflatex` to build `paper/paper.pdf`.

## Reproduce everything

```bash
git clone <REPO-URL>
cd <REPO-NAME>
# Place the restricted data file in input/
make
```

A convenience wrapper is also provided:

```bash
./run_all.sh
```

## Results summary

The replication matches the structure, signs, and broad magnitudes of Knaus Table 4. The results are not expected to match exactly because this replication uses fixed-parameter generalized random forests to keep runtime feasible, while the paper uses fully tuned honest random forests. The cleaned sample size also differs slightly because the no-program group requires a simulated pseudo-start date.
