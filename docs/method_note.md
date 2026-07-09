# Method Note

The empirical question is whether passive ownership predicts smoother R&D adjustment among
firms close to the Russell 1000/2000 assignment cutoff. The design uses index
assignment as a source of variation in passive mutual fund ownership.

## Near-Cutoff Sample

The script constructs a running variable from the within-index market-cap rank:

```text
running = rank_mktcap                    for Russell 1000 observations
running = 1000 + rank_mktcap             for Russell 2000 observations
distance_to_cutoff = running - 1000
```

The default analysis keeps observations with `abs(distance_to_cutoff) <= 150`.
The final IV moment partials out `distance_to_cutoff` and
`distance_to_cutoff * R1000` linearly, allowing different local slopes on the two
sides of the cutoff. The default `core` specification uses firm-level accounting
and market controls. The expanded `full` specification also includes available
industry and year dummies.

## Local IV Moment

Let `Y` be the R&D adjustment measure, `D` be passive ownership, `Z` be the Russell 1000
assignment indicator, `X` be firm controls and fixed effects, and `S` be the smooth
running-variable controls. The implementation uses cross-fitted random forests to
estimate two nuisance functions:

```text
E[Y | X]
E[D | X]
```

The code first forms random-forest residuals:

```text
Y_star = Y - E[Y | X]
D_star = D - E[D | X].
```

It then linearly partials out the smooth running controls `S` from `Y_star`, `D_star`,
and `Z`, producing `Y_tilde`, `D_tilde`, and `Z_tilde`. The final coefficient solves
the IV moment

```text
E[Z_tilde * (Y_tilde - beta * D_tilde)] = 0.
```

Equivalently, the code instruments residualized passive ownership with the cutoff
assignment after removing smooth running-variable trends. The code does not use a
flexible learner to residualize the assignment indicator. In a cutoff design,
assignment is mechanically tied to the side of the running variable, so overfitting
`Z` can absorb the discontinuity that identifies the local first stage.

The output reports the coefficient, an observation-level robust standard error for
the IV moment, and first-stage proxy diagnostics from `D_tilde ~ Z_tilde`.

## Specification Grid

`scripts/run_specification_grid.R` complements the RF local-IV workflow with
paper-style diagnostics. It estimates side-specific local OLS, reduced-form,
first-stage, and IV specifications across bandwidths, outcome definitions, and
control sets. These estimates use firm-clustered standard errors and are intended
to make weak-instrument, small-sample, and robustness issues visible inside the
output table. The grid includes optional subgroup rows only when a subgroup has
enough observations and is not identical to the full near-cutoff sample.

## Scope And Limits

This compact implementation is designed for a coding sample. A paper-grade empirical
analysis should report sensitivity to alternative bandwidths, alternative learners,
clustered or two-way clustered inference, and first-stage strength.

The cluster extension aggregates firm-quarter characteristics to robust firm-level
median profiles, groups firms with a Gaussian mixture model, maps firm labels back
to firm-quarter observations, and runs the same near-cutoff procedure within each
cluster. These cluster-level estimates should be interpreted as exploratory
heterogeneity analysis.
