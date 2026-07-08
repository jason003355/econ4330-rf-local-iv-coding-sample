# Passive Ownership and R&D Cuts

This repository is a cleaned coding sample adapted from an ECON 4330 empirical machine
learning project. The analysis asks whether passive mutual fund ownership mitigates
R&D cuts when firms face short-term earnings pressure.

The original project used WRDS data from Compustat, CRSP, IBES, Thomson/Refinitiv
13F, CRSP Mutual Funds, and Russell index membership. Those data are licensed and
are not included in this repository. To keep the workflow runnable, the repository
includes a synthetic data generator with the same schema used by the empirical code.

## What This Demonstrates

- Panel data cleaning for firm-quarter observations
- A Russell 1000/2000 cutoff design for passive ownership
- Random-forest nuisance models with cross-fitting
- A DML-IV style final stage using orthogonalized outcome variation
- Gaussian mixture clustering for heterogeneous effects
- Reproducible project structure with relative paths and generated outputs

## Repository Structure

```text
.
|-- R/
|   |-- clustering.R
|   |-- dml_iv.R
|   |-- plots.R
|   `-- utils.R
|-- scripts/
|   |-- make_sample_data.R
|   `-- run_analysis.R
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

Install the R packages listed in `DESCRIPTION`, then run:

```bash
Rscript scripts/make_sample_data.R
Rscript scripts/run_analysis.R --input data/sample_panel.csv --output outputs/sample_run
```

The analysis writes tables and figures under `outputs/sample_run/`.

## Running On Real Data

Place a licensed local panel file at `data/raw/panel_real.csv` with the columns listed
in `docs/data_dictionary.md`, then run:

```bash
Rscript scripts/run_analysis.R --input data/raw/panel_real.csv --output outputs/real_run
```

The `data/raw/` directory and Excel files are ignored by Git to avoid publishing
licensed WRDS data.

## Coding Sample Notes

This version is intentionally narrower than the original course folder. It keeps the
core empirical workflow and removes hard-coded absolute paths, rendered notebook
artifacts, local Excel files, and manual intermediate files. The goal is to show a
reviewable implementation rather than a complete public replication package.

The identification argument should be presented carefully in applications: the Russell
cutoff design is credible only near the cutoff and conditional on the stated controls.
The cluster-level estimates are exploratory because small clusters can produce unstable
coefficients.

The reported standard errors are observation-level HC1 standard errors. A production
paper version should add firm-level or two-way clustered inference for a firm-quarter
panel.
