# Method Note

The empirical question is whether passive ownership predicts smaller R&D cuts among
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
The final IV moment partials out `distance_to_cutoff` and `distance_to_cutoff_sq`
linearly. The random-forest nuisance models use firm controls, industry dummies, and
year dummies.

## Local IV Moment

Let `Y` be the R&D cut measure, `D` be passive ownership, `Z` be the Russell 1000
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

## Scope And Limits

This compact implementation is designed for a coding sample. A paper-grade empirical
analysis should report sensitivity to alternative bandwidths, alternative learners,
clustered or two-way clustered inference, and a fuller IV specification.

The cluster extension aggregates firm-quarter characteristics to the firm level,
groups firms with a Gaussian mixture model, maps firm labels back to firm-quarter
observations, and runs the same near-cutoff procedure within each cluster. These
cluster-level estimates should be interpreted as exploratory heterogeneity analysis.
