# Data

`scripts/make_sample_data.R` creates a local `data/sample_panel.csv` file with the
same schema expected by the analysis scripts. The generated CSV is ignored by Git.

Licensed WRDS-derived files should be stored locally under `data/raw/`. That directory
is intentionally excluded from Git.
