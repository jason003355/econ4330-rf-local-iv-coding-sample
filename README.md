# Passive Ownership and R&D Adjustment

This repository is a compact Predoc coding sample for an empirical finance question:
does passive mutual fund ownership predict smoother R&D adjustment among firms near the
Russell 1000/2000 assignment cutoff?

The public repository uses synthetic data with the same schema as the restricted
research panel. The original project used licensed WRDS data from Compustat, CRSP,
IBES, Thomson/Refinitiv 13F, CRSP Mutual Funds, and Russell index membership. Those
licensed data are not included.

## What This Demonstrates

- Firm-quarter panel cleaning with relative paths
- Construction of a Russell 1000/2000 near-cutoff sample
- Random-forest nuisance models with cross-fitting
- A local-IV final stage with random-forest residualization of outcome and treatment
- A transparent side-specific local linear IV and OLS specification grid with
  firm-clustered standard errors
- Firm-level Gaussian mixture clustering for exploratory heterogeneity
- Reproducible scripts, generated outputs, and CI checks

## Repository Structure

```text
.
|-- R/
|   |-- clustering.R
|   |-- data_prep.R
|   |-- linear_iv.R
|   |-- local_iv.R
|   |-- plots.R
|   `-- utils.R
|-- scripts/
|   |-- make_sample_data.R
|   |-- run_analysis.R
|   `-- run_specification_grid.R
|-- data/
|   `-- README.md
|-- docs/
|   |-- data_dictionary.md
|   `-- method_note.md
|-- tests/
|   `-- test_project_structure.py
|-- DESCRIPTION
`-- README.md
```

## Quick Start

Install the R packages listed in `DESCRIPTION`, then generate a local synthetic
panel and run the default analysis:

```bash
Rscript scripts/make_sample_data.R
Rscript scripts/run_analysis.R --input data/sample_panel.csv --output outputs/sample_run
```

The default analysis keeps observations within 150 ranks of the Russell cutoff. To
change the bandwidth:

```bash
Rscript scripts/run_analysis.R --input data/sample_panel.csv --output outputs/sample_run --bandwidth 100
```

The default control set is `core`. To run a sparse first-stage diagnostic
specification or the expanded control set:

```bash
Rscript scripts/run_analysis.R --input data/sample_panel.csv --output outputs/minimal_run --control-set minimal
Rscript scripts/run_analysis.R --input data/sample_panel.csv --output outputs/full_run --control-set full
```

For paper-style diagnostics across bandwidths, outcomes, and control sets:

```bash
Rscript scripts/run_specification_grid.R --input data/sample_panel.csv --output outputs/spec_grid
```

## Key Outputs

The analysis writes tables and figures under `outputs/sample_run/`:

- `tables/sample_summary.csv`: near-cutoff sample size, bandwidth, treatment-side
  counts, and mean passive ownership by side of the cutoff.
- `tables/main_near_cutoff_local_iv.csv`: main coefficient, an IV-moment robust
  standard error, and first-stage proxy diagnostics.
- `tables/cluster_local_iv.csv`: exploratory estimates by firm-level GMM cluster.
- `tables/local_linear_iv_grid.csv`: local OLS, reduced-form, first-stage, and IV
  estimates from `run_specification_grid.R`, with firm-clustered standard errors
  plus weak-first-stage and small-sample flags.
- `figures/passive_cutoff.png`: binned passive ownership around the Russell cutoff.
- `figures/importance_*.png`: random-forest variable-importance diagnostics.

The synthetic-data coefficient is a workflow check, not an empirical finding.

## Running On Real Data

Place a licensed local panel file at `data/raw/panel_real.csv` or
`data/raw/panel_real.xlsx` with the columns listed in `docs/data_dictionary.md`,
then run:

```bash
Rscript scripts/run_analysis.R --input data/raw/panel_real.csv --output outputs/real_run
Rscript scripts/run_specification_grid.R --input data/raw/panel_real.csv --output outputs/real_grid
```

The `data/raw/` directory, local Excel files, generated CSVs, and outputs are ignored
by Git to avoid publishing licensed WRDS data.

## Method Scope

This is a coding sample, not a public replication package. The main script estimates
a near-cutoff local-IV specification by residualizing the outcome and passive
ownership with random forests, linearly partialling out smooth running-variable
controls, and instrumenting residualized passive ownership with Russell 1000
assignment.

The identification claim should stay narrow in applications. The Russell design is
most credible close to the cutoff, so the default script filters to that sample and
controls for smooth distance-to-cutoff trends. The RF local-IV output is primarily
for coding-sample demonstration. The specification-grid script is the more
transparent place to evaluate paper-style first-stage strength, reduced-form
patterns, OLS associations, small-sample sensitivity, and firm-clustered
uncertainty. Optional subgroup rows are included only when the subgroup has enough
observations and differs from the full near-cutoff sample.

Cluster-level estimates are exploratory. They show how the workflow can be extended
to heterogeneity analysis, but small clusters can produce unstable coefficients.

## Source Note

This coding sample is adapted from an ECON 4330 empirical machine-learning project.
The repository keeps the core empirical workflow and removes rendered notebooks,
hard-coded absolute paths, local Excel files, and manual intermediate files.

## Tested Environment

- R version 4.5.1
- `dplyr` 1.1.4
- `ggplot2` 3.5.2
- `mclust` 6.1.2
- `randomForest` 4.7.1.2
- `readr` 2.1.5
- `readxl` 1.4.5
- `tidyr` 1.3.1
