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
  out <- list(input = default_input, output = default_output, ntree = 150)

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
