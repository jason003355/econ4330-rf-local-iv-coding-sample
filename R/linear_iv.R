residualize_linear <- function(x, controls) {
  x <- safe_numeric(x)
  if (is.null(controls) || ncol(controls) == 0) {
    return(x - mean(x, na.rm = TRUE))
  }

  controls <- as.data.frame(controls)
  for (v in names(controls)) {
    controls[[v]] <- safe_numeric(controls[[v]])
  }
  design <- stats::model.matrix(~ ., data = controls)
  as.numeric(stats::lm.fit(x = design, y = x)$residuals)
}

cluster_slope_se <- function(y, x, cluster_id) {
  keep <- is.finite(y) & is.finite(x) & !is.na(cluster_id)
  y <- y[keep]
  x <- x[keep]
  cluster_id <- as.character(cluster_id[keep])
  n <- length(y)
  denominator <- sum(x * x)
  if (n < 3 || abs(denominator) <= .Machine$double.eps) {
    return(data.frame(estimate = NA_real_, std_error = NA_real_, t_stat = NA_real_, p_value = NA_real_, n = n))
  }

  beta <- sum(x * y) / denominator
  resid <- y - beta * x
  score <- x * resid
  cluster_score <- rowsum(score, cluster_id, reorder = FALSE)
  g <- nrow(cluster_score)
  correction <- if (g > 1) (g / (g - 1)) * ((n - 1) / max(n - 2, 1)) else 1
  variance <- correction * sum(cluster_score[, 1]^2) / denominator^2
  se <- sqrt(variance)
  t_stat <- beta / se
  p_value <- 2 * stats::pt(abs(t_stat), df = max(g - 1, 1), lower.tail = FALSE)

  data.frame(estimate = beta, std_error = se, t_stat = t_stat, p_value = p_value, n = n)
}

cluster_iv_se <- function(y, d, z, cluster_id) {
  keep <- is.finite(y) & is.finite(d) & is.finite(z) & !is.na(cluster_id)
  y <- y[keep]
  d <- d[keep]
  z <- z[keep]
  cluster_id <- as.character(cluster_id[keep])
  n <- length(y)
  denominator <- sum(z * d)
  if (n < 3 || abs(denominator) <= .Machine$double.eps) {
    return(data.frame(estimate = NA_real_, std_error = NA_real_, t_stat = NA_real_, p_value = NA_real_, n = n))
  }

  beta <- sum(z * y) / denominator
  resid <- y - beta * d
  score <- z * resid
  cluster_score <- rowsum(score, cluster_id, reorder = FALSE)
  g <- nrow(cluster_score)
  correction <- if (g > 1) (g / (g - 1)) * ((n - 1) / max(n - 2, 1)) else 1
  variance <- correction * sum(cluster_score[, 1]^2) / denominator^2
  se <- sqrt(variance)
  t_stat <- beta / se
  p_value <- 2 * stats::pt(abs(t_stat), df = max(g - 1, 1), lower.tail = FALSE)

  data.frame(estimate = beta, std_error = se, t_stat = t_stat, p_value = p_value, n = n)
}

fit_local_linear_iv <- function(data,
                                outcome,
                                treatment = "passive_pct_float",
                                instrument = "r1000_dummy",
                                covariates = character(),
                                linear_controls = c("distance_to_cutoff", "distance_x_r1000"),
                                cluster = "firm_id",
                                winsor_probs = c(0.01, 0.99)) {
  all_vars <- unique(c(outcome, treatment, instrument, covariates, linear_controls, cluster))
  missing <- setdiff(all_vars, names(data))
  if (length(missing) > 0) {
    stop("Missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  model_data <- data[, all_vars, drop = FALSE]
  numeric_vars <- setdiff(all_vars, cluster)
  for (v in numeric_vars) {
    model_data[[v]] <- safe_numeric(model_data[[v]])
  }

  finite_rows <- stats::complete.cases(model_data[, numeric_vars, drop = FALSE]) &
    Reduce(`&`, lapply(model_data[, numeric_vars, drop = FALSE], is.finite)) &
    !is.na(model_data[[cluster]])
  model_data <- model_data[finite_rows, , drop = FALSE]

  if (nrow(model_data) < 30) {
    stop("Too few complete observations for local linear IV: ", nrow(model_data), call. = FALSE)
  }

  y <- model_data[[outcome]]
  if (!outcome %in% c("rd_cut", "rd_scaled_cut")) {
    q <- stats::quantile(y, probs = winsor_probs, na.rm = TRUE, type = 7)
    y <- winsorize_to_thresholds(y, q[[1]], q[[2]])
  }

  controls <- model_data[, unique(c(covariates, linear_controls)), drop = FALSE]
  y_resid <- residualize_linear(y, controls)
  d_resid <- residualize_linear(model_data[[treatment]], controls)
  z_resid <- residualize_linear(model_data[[instrument]], controls)
  cluster_id <- model_data[[cluster]]

  first_stage <- cluster_slope_se(d_resid, z_resid, cluster_id)
  reduced_form <- cluster_slope_se(y_resid, z_resid, cluster_id)
  ols <- cluster_slope_se(y_resid, d_resid, cluster_id)
  iv <- cluster_iv_se(y_resid, d_resid, z_resid, cluster_id)

  data.frame(
    outcome = outcome,
    n = iv$n,
    n_clusters = length(unique(cluster_id)),
    ols_estimate = ols$estimate,
    ols_std_error = ols$std_error,
    ols_t_stat = ols$t_stat,
    ols_p_value = ols$p_value,
    ols_per_10pp = 0.1 * ols$estimate,
    ols_se_per_10pp = 0.1 * ols$std_error,
    first_stage = first_stage$estimate,
    first_stage_se = first_stage$std_error,
    first_stage_f = first_stage$t_stat^2,
    reduced_form = reduced_form$estimate,
    reduced_form_se = reduced_form$std_error,
    reduced_form_t_stat = reduced_form$t_stat,
    reduced_form_p_value = reduced_form$p_value,
    iv_estimate = iv$estimate,
    iv_std_error = iv$std_error,
    iv_t_stat = iv$t_stat,
    iv_p_value = iv$p_value,
    iv_per_10pp = 0.1 * iv$estimate,
    iv_se_per_10pp = 0.1 * iv$std_error
  )
}
