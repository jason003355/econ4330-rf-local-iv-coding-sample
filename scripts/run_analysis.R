source("R/utils.R")
check_packages()

source("R/local_iv.R")
source("R/clustering.R")
source("R/plots.R")

args <- parse_cli_args()
ensure_dir(args$output)
ensure_dir(file.path(args$output, "tables"))
ensure_dir(file.path(args$output, "figures"))

data <- read_analysis_data(args$input)
analysis_data <- filter_near_cutoff(data, bandwidth = args$bandwidth)

covariates <- select_covariates(analysis_data, args$control_set)
linear_controls <- c("distance_to_cutoff", "distance_to_cutoff_sq")

readr::write_csv(
  cutoff_sample_summary(analysis_data, bandwidth = args$bandwidth),
  file.path(args$output, "tables", "sample_summary.csv")
)

fit <- fit_rf_local_iv(
  data = analysis_data,
  outcome = "xrdq_change",
  treatment = "passive_pct_float",
  instrument = "r1000_dummy",
  covariates = covariates,
  linear_controls = linear_controls,
  nfolds = 5,
  ntree = args$ntree,
  seed = 4330
)

readr::write_csv(fit$estimate, file.path(args$output, "tables", "main_near_cutoff_local_iv.csv"))
readr::write_csv(fit$predictions, file.path(args$output, "tables", "crossfit_predictions.csv"))
readr::write_csv(fit$importance_y, file.path(args$output, "tables", "importance_y_given_x.csv"))
readr::write_csv(fit$importance_d_x, file.path(args$output, "tables", "importance_d_given_x.csv"))

plot_outcome_distribution(analysis_data, file.path(args$output, "figures", "outcome_distribution.png"))
plot_passive_cutoff(data, file.path(args$output, "figures", "passive_cutoff.png"), bandwidth = args$bandwidth)
plot_importance(fit$importance_y, file.path(args$output, "figures", "importance_y_given_x.png"), "E[Y | X]")
plot_importance(fit$importance_d_x, file.path(args$output, "figures", "importance_d_given_x.png"), "E[D | X]")

cluster_features <- intersect(
  c(
    "crsp_mktcap", "leverage", "ROA", "cf", "rd_intensity", "sales_growth",
    "BM", "cash_ratio", "stock_return_volatility", "log_analyst_coverage"
  ),
  names(data)
)

if (length(cluster_features) >= 4) {
  clusters <- fit_gmm_clusters(analysis_data, features = cluster_features, groups = 4, seed = 4330, unit_id = "firm_id")
  readr::write_csv(clusters$summary, file.path(args$output, "tables", "gmm_cluster_summary.csv"))

  cluster_results <- run_cluster_local_iv(
    data = clusters$data,
    cluster_col = "gmm_cluster",
    outcome = "xrdq_change",
    treatment = "passive_pct_float",
    instrument = "r1000_dummy",
    covariates = covariates,
    linear_controls = linear_controls,
    min_n = 75,
    nfolds = 5,
    ntree = args$ntree,
    seed = 5000
  )
  readr::write_csv(cluster_results, file.path(args$output, "tables", "cluster_local_iv.csv"))
}

message("Analysis complete. Outputs written to: ", args$output)
