# Method Note

The empirical target is the effect of passive ownership on firms' R&D cuts when firms
face short-term pressure. The original project used the Russell 1000/2000 cutoff as an
instrument for passive mutual fund ownership.

The implementation follows a cross-fitted DML-IV workflow. Let `Y` be the R&D cut
measure, `D` be passive ownership, `Z` be the Russell assignment instrument, and `X`
be firm controls plus industry and year dummies. The target is the local effect of
passive ownership for the variation in `D` induced by `Z` near the Russell cutoff.

The score implemented here uses the random-forest estimate of the conditional first
stage,

```text
Delta(X, Z) = E[D | X, Z] - E[D | X],
```

as the instrument-induced component of passive ownership. The final coefficient is
estimated from the no-intercept moment

```text
E[(Y - E[Y | X] - beta * Delta(X, Z)) * Delta(X, Z)] = 0.
```

This is a compact implementation suitable for a coding sample. A paper-grade version
would report a fuller DML-IV specification, sensitivity to alternative learners, and
firm-clustered or two-way clustered inference.

Workflow:

1. Split the sample into folds.
2. Fit a random forest for the outcome using controls only, producing `E[Y | X]`.
3. Fit a random forest for passive ownership using controls only, producing `E[D | X]`.
4. Fit a random forest for passive ownership using controls and the instrument,
   producing `E[D | X, Z]`.
5. Regress the residualized outcome `Y - E[Y | X]` on
   `E[D | X, Z] - E[D | X]` without an intercept.

The cluster extension first aggregates firm-quarter characteristics to the firm level,
groups firms with a Gaussian mixture model, maps the firm labels back to firm-quarter
observations, and then runs the same RF-DML-IV procedure within each cluster. These
cluster-level estimates should be interpreted as exploratory heterogeneity analysis,
especially when a cluster has a small sample size.

The code writes first-stage proxy diagnostics alongside the treatment-effect estimate:
the slope and F-statistic from `D ~ Delta`, plus the mean and standard deviation of
`Delta`.
