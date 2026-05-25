# Presentation notes: explaining the replication and DML

## One-sentence summary

I replicate Table 4 from Knaus (2022), which uses double machine learning to estimate how Swiss labor market programs affect employment differently for women, foreigners, and workers with different employability ratings.

## What the paper is doing

The paper evaluates active labor market programs in Switzerland. The treatment is not just binary; there are multiple possible programs: no program, job search training, vocational training, computer training, and language courses. The outcome is the total number of months employed after the program starts.

The key challenge is selection. People are not randomly assigned to programs. For example, people assigned to language courses may differ from people assigned to computer courses. To make the comparison credible, the paper assumes unconfoundedness: after conditioning on observed covariates, program assignment is as good as random.

## How this connects to DML from class

In class, DML had two main steps:

1. Estimate nuisance functions using machine learning.
2. Use an orthogonal or doubly robust score to estimate a causal effect.

Here the nuisance functions are:

- Outcome model: mu(w, X) = E[Y | W = w, X]
- Propensity score: e_w(X) = P(W = w | X)

The DML score is:

Gamma_hat(i,w) = mu_hat(w, X_i) + D_i(w) * (Y_i - mu_hat(w, X_i)) / e_hat_w(X_i)

This is called doubly robust because it combines outcome regression and inverse-propensity weighting. If one nuisance model is imperfect, the score can still behave well if the other is good enough. It is also Neyman-orthogonal, meaning small first-stage prediction errors have only second-order effects on the final causal estimate.

## What Table 4 is doing

For each program, I compare that program to no program. First I construct treatment-effect pseudo-outcomes:

Delta_hat(i,w,no program) = Gamma_hat(i,w) - Gamma_hat(i,no program)

Then I run simple regressions of this pseudo-outcome on subgroup variables. For example, Panel A uses:

Delta_hat = beta_0 + beta_1 Female + error

The constant is the estimated effect for men. The female coefficient is how much the effect differs for women.

## What my code does

### preprocess.R

- Loads the restricted Swiss ALMP data.
- Keeps German-speaking cantons.
- Drops employment and personality programs to match the five-treatment setup.
- Builds the 45 covariates.
- Predicts pseudo-start timing for the no-program group.
- Drops people already employed before the relevant start date.
- Creates the outcome: total months employed over 31 months.
- Saves analysis-ready objects to temp/clean_data.RData.

### analysis.R

- Loads temp/clean_data.RData.
- Runs DML_aipw using generalized random forests as nuisance learners.
- Extracts DML pseudo-outcomes for treatment effects vs. no program.
- Runs subgroup regressions for female, foreigner, and employability.
- Saves a PNG of the replicated Table 4 and a LaTeX fragment that includes the PNG.

### paper.tex

- Explains the paper, the target result, the method, and what I learned.
- Inputs the generated Table 4 figure from output/.

## Why my results may not be exact

The results are close, but not identical. Main reasons:

1. The original paper used fully tuned honest random forests; I use fixed 500-tree generalized random forests to keep runtime feasible.
2. The no-program group requires simulated pseudo-start dates, so the sample can differ slightly.
3. The original full data-cleaning script was not available, so some cleaning decisions had to be reconstructed.

## How to present the result

I would say:

"The main takeaway is that the replication captures the same qualitative pattern as the paper. Job search training is mostly negative relative to no program, while vocational, computer, and language programs are mostly positive. The subgroup results also line up: women do relatively better in computer programs and worse in language courses; foreigners do worse in language courses; and low-employability workers tend to benefit more from hard-skill programs."

## Questions I might get

### Why use machine learning if the final table uses OLS?

The OLS is not run on the raw outcome. It is run on the DML pseudo-outcome. Machine learning is used first to adjust for confounding flexibly. OLS is then used only as a summary tool for treatment-effect heterogeneity.

### Is this causal machine learning?

Yes. The machine learning part estimates nuisance functions, but the final target is causal: treatment effects of labor market programs.

### Why does unconfoundedness matter?

Without unconfoundedness, differences in outcomes could reflect selection into programs rather than causal program effects. Unconfoundedness says the observed covariates are rich enough to control for this selection.

### Why not match the paper exactly?

Exact replication would require the original full preprocessing script and fully tuned forests, which are computationally expensive. This replication prioritizes a reproducible pipeline and close qualitative replication.
