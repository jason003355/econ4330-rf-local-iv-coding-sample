read_analysis_data <- function(path) {
  if (!file.exists(path)) {
    stop("Input file does not exist: ", path, call. = FALSE)
  }

  extension <- tolower(tools::file_ext(path))
  data <- switch(
    extension,
    csv = readr::read_csv(path, show_col_types = FALSE),
    xls = readxl::read_excel(path),
    xlsx = readxl::read_excel(path),
    stop("Unsupported input file type: .", extension, call. = FALSE)
  )

  add_derived_outcomes(standardize_panel_schema(as.data.frame(data)))
}

standardize_panel_schema <- function(data) {
  out <- data

  if (!("firm_id" %in% names(out))) {
    if ("permno" %in% names(out)) {
      out$firm_id <- as.character(out$permno)
    } else if ("gvkey" %in% names(out)) {
      out$firm_id <- as.character(out$gvkey)
    }
  }

  if (!("BM" %in% names(out)) && "bm" %in% names(out)) {
    out$BM <- out$bm
  }

  out
}

add_derived_outcomes <- function(data) {
  out <- data

  if ("xrdq_change" %in% names(out) && !("rd_cut" %in% names(out))) {
    x <- safe_numeric(out$xrdq_change)
    out$rd_cut <- ifelse(is.finite(x), as.numeric(x < 0), NA_real_)
  }

  if ("d_xrdq_scaled" %in% names(out) && !("rd_scaled_cut" %in% names(out))) {
    x <- safe_numeric(out$d_xrdq_scaled)
    out$rd_scaled_cut <- ifelse(is.finite(x), as.numeric(x < 0), NA_real_)
  }

  out
}

select_covariates <- function(data, control_set = "core") {
  minimal_controls <- c("atq", "saleq", "seqq", "cheq", "leverage", "cf", "rd_intensity")
  core_controls <- c(minimal_controls, "sales_growth", "BM", "ROA", "cash_ratio")
  full_controls <- c(
    core_controls,
    "log_analyst_coverage", "net_income_q", "ROE", "stock_return_volatility",
    "surprise_eps", "numest", "past_3yr_miss_rate", "tech_dummy"
  )

  controls <- switch(
    control_set,
    minimal = minimal_controls,
    core = core_controls,
    full = c(full_controls, grep("^sic2_", names(data), value = TRUE), grep("^year_", names(data), value = TRUE)),
    stop("Unknown control set: ", control_set, call. = FALSE)
  )

  intersect(controls, names(data))
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
  if (!("r1000_dummy" %in% names(out))) {
    out$r1000_dummy <- as.numeric(index == "R1000")
  }
  r1000 <- safe_numeric(out$r1000_dummy)
  r1000 <- ifelse(is.finite(r1000), r1000, as.numeric(index == "R1000"))
  out$r1000_dummy <- r1000
  out$cutoff_running_rank <- ifelse(
    index == "R1000",
    rank,
    ifelse(index == "R2000", 1000 + rank, NA_real_)
  )
  out$distance_to_cutoff <- out$cutoff_running_rank - 1000
  out$distance_to_cutoff_sq <- out$distance_to_cutoff^2
  out$distance_x_r1000 <- out$distance_to_cutoff * r1000
  out$distance_sq_x_r1000 <- out$distance_to_cutoff_sq * r1000
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
