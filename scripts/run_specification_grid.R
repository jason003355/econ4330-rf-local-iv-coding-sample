source("R/utils.R")
check_packages()

source("R/data_prep.R")
source("R/linear_iv.R")

args <- parse_cli_args(default_output = "outputs/spec_grid")
ensure_dir(args$output)
ensure_dir(file.path(args$output, "tables"))

data <- read_analysis_data(args$input)

bandwidths <- c(100, 150, 200, 250)
control_sets <- c("minimal", "core", "full")
candidate_outcomes <- c("xrdq_change", "d_xrdq_scaled", "rd_cut", "rd_scaled_cut")
outcomes <- intersect(candidate_outcomes, names(data))

add_subgroup <- function(subgroups, name, mask, min_n = 30) {
  mask <- as.logical(mask)
  mask[is.na(mask)] <- FALSE
  if (sum(mask) >= min_n && sum(mask) < length(mask)) {
    subgroups[[name]] <- mask
  }
  subgroups
}

rows <- list()
idx <- 1
for (bandwidth in bandwidths) {
  bandwidth_data <- filter_near_cutoff(data, bandwidth = bandwidth)
  subgroups <- list(all = rep(TRUE, nrow(bandwidth_data)))
  if ("surprise_eps" %in% names(bandwidth_data)) {
    surprise <- safe_numeric(bandwidth_data$surprise_eps)
    subgroups <- add_subgroup(subgroups, "negative_surprise", is.finite(surprise) & surprise < 0)
  }
  if ("miss_dummy" %in% names(bandwidth_data)) {
    miss <- safe_numeric(bandwidth_data$miss_dummy)
    subgroups <- add_subgroup(subgroups, "earnings_miss", is.finite(miss) & miss == 1)
  }

  for (control_set in control_sets) {
    for (subgroup_name in names(subgroups)) {
      subgroup_data <- bandwidth_data[subgroups[[subgroup_name]], , drop = FALSE]
      if (nrow(subgroup_data) < 30) {
        next
      }
      covariates <- select_covariates(subgroup_data, control_set)
      for (outcome in outcomes) {
        result <- tryCatch(
          fit_local_linear_iv(
            data = subgroup_data,
            outcome = outcome,
            covariates = covariates
          ),
          error = function(e) {
            data.frame(
              outcome = outcome,
              n = NA_integer_,
              n_clusters = NA_integer_,
              ols_estimate = NA_real_,
              ols_std_error = NA_real_,
              ols_t_stat = NA_real_,
              ols_p_value = NA_real_,
              ols_per_10pp = NA_real_,
              ols_se_per_10pp = NA_real_,
              first_stage = NA_real_,
              first_stage_se = NA_real_,
              first_stage_f = NA_real_,
              reduced_form = NA_real_,
              reduced_form_se = NA_real_,
              reduced_form_t_stat = NA_real_,
              reduced_form_p_value = NA_real_,
              iv_estimate = NA_real_,
              iv_std_error = NA_real_,
              iv_t_stat = NA_real_,
              iv_p_value = NA_real_,
              iv_per_10pp = NA_real_,
              iv_se_per_10pp = NA_real_,
              note = e$message
            )
          }
        )
        if (!("note" %in% names(result))) {
          result$note <- "Estimated"
        }
        result$bandwidth <- bandwidth
        result$control_set <- control_set
        result$subgroup <- subgroup_name
        result$near_cutoff_n <- nrow(bandwidth_data)
        result$subgroup_n <- nrow(subgroup_data)
        result$weak_first_stage <- is.na(result$first_stage_f) | result$first_stage_f < 10
        result$small_sample <- is.na(result$n) | result$n < 250 | result$n_clusters < 100
        rows[[idx]] <- result
        idx <- idx + 1
      }
    }
  }
}

if (length(rows) == 0) {
  stop("No specification rows were estimated.", call. = FALSE)
}

output_columns <- c(
  "bandwidth",
  "control_set",
  "subgroup",
  "outcome",
  "near_cutoff_n",
  "subgroup_n",
  "n",
  "n_clusters",
  "ols_estimate",
  "ols_std_error",
  "ols_t_stat",
  "ols_p_value",
  "ols_per_10pp",
  "ols_se_per_10pp",
  "first_stage",
  "first_stage_se",
  "first_stage_f",
  "weak_first_stage",
  "small_sample",
  "reduced_form",
  "reduced_form_se",
  "reduced_form_t_stat",
  "reduced_form_p_value",
  "iv_estimate",
  "iv_std_error",
  "iv_t_stat",
  "iv_p_value",
  "iv_per_10pp",
  "iv_se_per_10pp",
  "note"
)

grid <- dplyr::bind_rows(rows) |>
  dplyr::select(dplyr::all_of(output_columns))

readr::write_csv(grid, file.path(args$output, "tables", "local_linear_iv_grid.csv"))

message("Specification grid complete. Outputs written to: ", args$output)
