required_packages <- c("dplyr", "ggplot2", "mclust", "randomForest", "readr", "tidyr")

check_packages <- function(packages = required_packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      "Missing R packages: ",
      paste(missing, collapse = ", "),
      ". Install them before running the analysis.",
      call. = FALSE
    )
  }

  suppressPackageStartupMessages(
    invisible(lapply(packages, library, character.only = TRUE))
  )
}

safe_numeric <- function(x) {
  if (is.numeric(x)) {
    return(x)
  }
  suppressWarnings(as.numeric(x))
}

winsorize_to_thresholds <- function(x, q_low, q_high) {
  pmin(pmax(x, q_low), q_high)
}

make_folds <- function(n, nfolds, seed) {
  if (n <= 1) {
    stop("Need at least two observations for cross-fitting.", call. = FALSE)
  }
  nfolds_eff <- min(nfolds, n)
  set.seed(seed)
  shuffled <- sample(seq_len(n))
  folds <- integer(n)
  folds[shuffled] <- rep(seq_len(nfolds_eff), length.out = n)
  folds
}

parse_cli_args <- function(default_input = "data/sample_panel.csv",
                           default_output = "outputs/sample_run") {
  args <- commandArgs(trailingOnly = TRUE)
  out <- list(input = default_input, output = default_output, ntree = 150, bandwidth = 150)

  i <- 1
  while (i <= length(args)) {
    if (args[[i]] == "--input" && i < length(args)) {
      out$input <- args[[i + 1]]
      i <- i + 2
    } else if (args[[i]] == "--output" && i < length(args)) {
      out$output <- args[[i + 1]]
      i <- i + 2
    } else if (args[[i]] == "--ntree" && i < length(args)) {
      out$ntree <- as.integer(args[[i + 1]])
      if (!is.finite(out$ntree) || out$ntree < 10) {
        stop("--ntree must be an integer of at least 10.", call. = FALSE)
      }
      i <- i + 2
    } else if (args[[i]] == "--bandwidth" && i < length(args)) {
      out$bandwidth <- as.numeric(args[[i + 1]])
      if (!is.finite(out$bandwidth) || out$bandwidth <= 0) {
        stop("--bandwidth must be a positive number.", call. = FALSE)
      }
      i <- i + 2
    } else {
      stop("Unknown or incomplete argument: ", args[[i]], call. = FALSE)
    }
  }

  out
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
}

required_columns <- function(base_controls, data) {
  c(
    "xrdq_change",
    "passive_pct_float",
    "r1000_dummy",
    base_controls,
    grep("^sic2_", names(data), value = TRUE),
    grep("^year_", names(data), value = TRUE)
  )
}

construct_cutoff_running <- function(data) {
  required <- c("russell_index", "rank_mktcap")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop("Missing cutoff columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  out <- data
  index <- as.character(out$russell_index)
  rank <- safe_numeric(out$rank_mktcap)
  out$cutoff_running_rank <- ifelse(
    index == "R1000",
    rank,
    ifelse(index == "R2000", 1000 + rank, NA_real_)
  )
  out$distance_to_cutoff <- out$cutoff_running_rank - 1000
  out$distance_to_cutoff_sq <- out$distance_to_cutoff^2
  out
}

filter_near_cutoff <- function(data, bandwidth = 150) {
  if (!is.finite(bandwidth) || bandwidth <= 0) {
    stop("bandwidth must be a positive number.", call. = FALSE)
  }

  out <- construct_cutoff_running(data)
  out <- out[
    is.finite(out$distance_to_cutoff) &
      abs(out$distance_to_cutoff) <= bandwidth,
    ,
    drop = FALSE
  ]

  if (nrow(out) < 30) {
    stop("Too few observations inside cutoff bandwidth: ", nrow(out), call. = FALSE)
  }
  out
}

cutoff_sample_summary <- function(data, bandwidth) {
  data.frame(
    bandwidth = bandwidth,
    n_obs = nrow(data),
    n_firms = if ("firm_id" %in% names(data)) length(unique(data$firm_id)) else NA_integer_,
    n_r1000 = sum(data$r1000_dummy == 1, na.rm = TRUE),
    n_r2000 = sum(data$r1000_dummy == 0, na.rm = TRUE),
    min_distance = min(data$distance_to_cutoff, na.rm = TRUE),
    max_distance = max(data$distance_to_cutoff, na.rm = TRUE),
    passive_mean_r1000 = mean(data$passive_pct_float[data$r1000_dummy == 1], na.rm = TRUE),
    passive_mean_r2000 = mean(data$passive_pct_float[data$r1000_dummy == 0], na.rm = TRUE),
    outcome_mean = mean(data$xrdq_change, na.rm = TRUE)
  )
}
