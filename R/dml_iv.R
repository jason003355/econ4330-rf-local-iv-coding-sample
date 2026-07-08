average_importance <- function(importance_list) {
  non_null <- Filter(Negate(is.null), importance_list)
  if (length(non_null) == 0) {
    return(data.frame(variable = character(), importance = numeric()))
  }

  frames <- lapply(non_null, function(mat) {
    mat <- as.data.frame(mat)
    mat$variable <- rownames(mat)
    score_col <- if ("%IncMSE" %in% names(mat)) "%IncMSE" else names(mat)[1]
    data.frame(variable = mat$variable, importance = mat[[score_col]])
  })

  dplyr::bind_rows(frames) |>
    dplyr::group_by(.data$variable) |>
    dplyr::summarise(importance = mean(.data$importance, na.rm = TRUE), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(abs(.data$importance)))
}

hc1_no_intercept <- function(y, x) {
  keep <- is.finite(y) & is.finite(x)
  y <- y[keep]
  x <- x[keep]
  n <- length(y)
  if (n < 3 || sum(x^2) <= 0) {
    return(data.frame(estimate = NA_real_, std_error = NA_real_, t_stat = NA_real_, p_value = NA_real_, n = n))
  }

  beta <- sum(x * y) / sum(x^2)
  resid <- y - beta * x
  meat <- sum((x^2) * (resid^2))
  bread <- sum(x^2)
  variance <- (n / (n - 1)) * meat / (bread^2)
  se <- sqrt(variance)
  t_stat <- beta / se
  p_value <- 2 * stats::pt(abs(t_stat), df = n - 1, lower.tail = FALSE)

  data.frame(estimate = beta, std_error = se, t_stat = t_stat, p_value = p_value, n = n)
}

fit_rf_dml_iv <- function(data,
                          outcome,
                          treatment,
                          instrument,
                          covariates,
                          nfolds = 5,
                          ntree = 500,
                          seed = 1,
                          winsor_probs = c(0.01, 0.99)) {
  all_vars <- unique(c(outcome, treatment, instrument, covariates))
  missing <- setdiff(all_vars, names(data))
  if (length(missing) > 0) {
    stop("Missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  model_data <- data[, all_vars, drop = FALSE]
  for (v in all_vars) {
    model_data[[v]] <- safe_numeric(model_data[[v]])
  }
  model_data <- model_data[stats::complete.cases(model_data), , drop = FALSE]

  n <- nrow(model_data)
  if (n < 30) {
    stop("Too few complete observations for DML-IV: ", n, call. = FALSE)
  }
  if (length(unique(model_data[[instrument]])) < 2) {
    stop("Instrument has insufficient variation.", call. = FALSE)
  }

  folds <- make_folds(n, nfolds, seed)
  e_y_x <- rep(NA_real_, n)
  e_d_x <- rep(NA_real_, n)
  e_d_xz <- rep(NA_real_, n)
  y_winsor <- rep(NA_real_, n)

  importance_y <- vector("list", max(folds))
  importance_d_x <- vector("list", max(folds))
  importance_d_xz <- vector("list", max(folds))

  for (fold in seq_len(max(folds))) {
    test_idx <- which(folds == fold)
    train_idx <- which(folds != fold)
    train <- model_data[train_idx, , drop = FALSE]
    test <- model_data[test_idx, , drop = FALSE]

    q <- stats::quantile(train[[outcome]], probs = winsor_probs, na.rm = TRUE, type = 7)
    train_y <- winsorize_to_thresholds(train[[outcome]], q[[1]], q[[2]])
    test_y <- winsorize_to_thresholds(test[[outcome]], q[[1]], q[[2]])
    y_winsor[test_idx] <- test_y

    rf_y <- randomForest::randomForest(
      x = train[, covariates, drop = FALSE],
      y = train_y,
      ntree = ntree,
      importance = TRUE
    )
    e_y_x[test_idx] <- stats::predict(rf_y, newdata = test[, covariates, drop = FALSE])
    importance_y[[fold]] <- randomForest::importance(rf_y)

    rf_d_x <- randomForest::randomForest(
      x = train[, covariates, drop = FALSE],
      y = train[[treatment]],
      ntree = ntree,
      importance = TRUE
    )
    e_d_x[test_idx] <- stats::predict(rf_d_x, newdata = test[, covariates, drop = FALSE])
    importance_d_x[[fold]] <- randomForest::importance(rf_d_x)

    covariates_z <- unique(c(instrument, covariates))
    rf_d_xz <- randomForest::randomForest(
      x = train[, covariates_z, drop = FALSE],
      y = train[[treatment]],
      ntree = ntree,
      importance = TRUE
    )
    e_d_xz[test_idx] <- stats::predict(rf_d_xz, newdata = test[, covariates_z, drop = FALSE])
    importance_d_xz[[fold]] <- randomForest::importance(rf_d_xz)
  }

  resid_y <- y_winsor - e_y_x
  delta <- e_d_xz - e_d_x
  estimate <- hc1_no_intercept(resid_y, delta)

  first_stage <- stats::lm(model_data[[treatment]] ~ delta)
  first_stage_summary <- summary(first_stage)
  estimate$first_stage_slope <- unname(stats::coef(first_stage)[["delta"]])
  estimate$first_stage_f <- unname(first_stage_summary$fstatistic[["value"]])
  estimate$mean_abs_delta <- mean(abs(delta), na.rm = TRUE)
  estimate$sd_delta <- stats::sd(delta, na.rm = TRUE)

  predictions <- data.frame(
    y_winsor = y_winsor,
    e_y_x = e_y_x,
    e_d_x = e_d_x,
    e_d_xz = e_d_xz,
    resid_y = resid_y,
    delta = delta
  )

  list(
    estimate = estimate,
    predictions = predictions,
    importance_y = average_importance(importance_y),
    importance_d_x = average_importance(importance_d_x),
    importance_d_xz = average_importance(importance_d_xz),
    n_complete = n
  )
}
