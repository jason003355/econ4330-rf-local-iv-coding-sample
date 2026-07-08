source("R/utils.R")
check_packages()

source("R/dml_iv.R")
source("R/clustering.R")
source("R/plots.R")

args <- parse_cli_args()
ensure_dir(args$output)
ensure_dir(file.path(args$output, "tables"))
ensure_dir(file.path(args$output, "figures"))

data <- readr::read_csv(args$input, show_col_types = FALSE)

base_controls <- c(
  "atq", "saleq", "seqq", "cheq", "leverage", "cf", "rd_intensity",
  "sales_growth", "log_analyst_coverage", "BM", "net_income_q",
  "ROA", "ROE", "cash_ratio", "stock_return_volatility"
)
covariates <- setdiff(required_columns(base_controls, data), c("xrdq_change", "passive_pct_float", "r1000_dummy"))

fit <- fit_rf_dml_iv(
  data = data,
  outcome = "xrdq_change",
  treatment = "passive_pct_float",
  instrument = "r1000_dummy",
  covariates = covariates,
  nfolds = 5,
  ntree = args$ntree,
  seed = 4330
)

readr::write_csv(fit$estimate, file.path(args$output, "tables", "full_sample_dml_iv.csv"))
readr::write_csv(fit$predictions, file.path(args$output, "tables", "crossfit_predictions.csv"))
readr::write_csv(fit$importance_y, file.path(args$output, "tables", "importance_y_given_x.csv"))
readr::write_csv(fit$importance_d_x, file.path(args$output, "tables", "importance_d_given_x.csv"))
readr::write_csv(fit$importance_d_xz, file.path(args$output, "tables", "importance_d_given_xz.csv"))

plot_outcome_distribution(data, file.path(args$output, "figures", "outcome_distribution.png"))
plot_passive_cutoff(data, file.path(args$output, "figures", "passive_cutoff.png"))
plot_importance(fit$importance_y, file.path(args$output, "figures", "importance_y_given_x.png"), "E[Y | X]")
plot_importance(fit$importance_d_x, file.path(args$output, "figures", "importance_d_given_x.png"), "E[D | X]")
plot_importance(fit$importance_d_xz, file.path(args$output, "figures", "importance_d_given_xz.png"), "E[D | X, Z]")

cluster_features <- intersect(
  c(
    "crsp_mktcap", "leverage", "ROA", "cf", "rd_intensity", "sales_growth",
    "BM", "cash_ratio", "stock_return_volatility", "log_analyst_coverage"
  ),
  names(data)
)

if (length(cluster_features) >= 4) {
  clusters <- fit_gmm_clusters(data, features = cluster_features, groups = 4, seed = 4330, unit_id = "firm_id")
  readr::write_csv(clusters$summary, file.path(args$output, "tables", "gmm_cluster_summary.csv"))

  cluster_results <- run_cluster_dml(
    data = clusters$data,
    cluster_col = "gmm_cluster",
    outcome = "xrdq_change",
    treatment = "passive_pct_float",
    instrument = "r1000_dummy",
    covariates = covariates,
    min_n = 75,
    nfolds = 5,
    ntree = args$ntree,
    seed = 5000
  )
  readr::write_csv(cluster_results, file.path(args$output, "tables", "cluster_dml_iv.csv"))
}

message("Analysis complete. Outputs written to: ", args$output)
