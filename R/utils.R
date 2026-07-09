required_packages <- c("dplyr", "ggplot2", "mclust", "randomForest", "readr", "readxl", "tidyr")

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

finite_numeric <- function(x) {
  out <- safe_numeric(x)
  out[!is.finite(out)] <- NA_real_
  out
}

median_finite <- function(x) {
  x <- finite_numeric(x)
  if (all(is.na(x))) {
    return(NA_real_)
  }
  stats::median(x, na.rm = TRUE)
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
  out <- list(
    input = default_input,
    output = default_output,
    ntree = 150,
    bandwidth = 150,
    control_set = "core"
  )

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
    } else if (args[[i]] == "--control-set" && i < length(args)) {
      out$control_set <- args[[i + 1]]
      if (!out$control_set %in% c("minimal", "core", "full")) {
        stop("--control-set must be one of: minimal, core, full.", call. = FALSE)
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
