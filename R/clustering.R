fit_gmm_clusters <- function(data, features, groups = 4, seed = 1, unit_id = "firm_id") {
  missing <- setdiff(features, names(data))
  if (length(missing) > 0) {
    stop("Missing clustering features: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  if (unit_id %in% names(data)) {
    cluster_source <- data |>
      dplyr::mutate(dplyr::across(dplyr::all_of(features), safe_numeric)) |>
      dplyr::group_by(.data[[unit_id]]) |>
      dplyr::summarise(dplyr::across(dplyr::all_of(features), ~ mean(.x, na.rm = TRUE)), .groups = "drop")
  } else {
    cluster_source <- data[, features, drop = FALSE]
    cluster_source$row_id_for_clustering <- seq_len(nrow(cluster_source))
    unit_id <- "row_id_for_clustering"
  }

  cluster_data <- cluster_source[, features, drop = FALSE]
  for (v in features) {
    cluster_data[[v]] <- safe_numeric(cluster_data[[v]])
  }

  keep <- stats::complete.cases(cluster_data)
  x <- scale(as.matrix(cluster_data[keep, , drop = FALSE]))
  x[!is.finite(x)] <- 0

  if (nrow(x) < groups * 10) {
    stop("Too few complete observations for GMM clustering.", call. = FALSE)
  }

  set.seed(seed)
  fit <- mclust::Mclust(x, G = groups, verbose = FALSE)
  cluster_source$gmm_cluster <- NA_integer_
  cluster_source$gmm_cluster[which(keep)] <- fit$classification

  if (unit_id %in% names(data)) {
    out <- dplyr::left_join(data, cluster_source[, c(unit_id, "gmm_cluster")], by = unit_id)
  } else {
    out <- data
    out$gmm_cluster <- cluster_source$gmm_cluster
  }

  summary <- out |>
    dplyr::filter(!is.na(.data$gmm_cluster)) |>
    dplyr::group_by(.data$gmm_cluster) |>
    dplyr::summarise(
      n = dplyr::n(),
      dplyr::across(dplyr::all_of(features), ~ mean(safe_numeric(.x), na.rm = TRUE)),
      .groups = "drop"
    )

  list(data = out, summary = summary, model = fit)
}

run_cluster_local_iv <- function(data,
                                 cluster_col,
                                 outcome,
                                 treatment,
                                 instrument,
                                 covariates,
                                 linear_controls = character(),
                                 min_n = 75,
                                 nfolds = 5,
                                 ntree = 500,
                                 seed = 100) {
  clusters <- sort(unique(stats::na.omit(data[[cluster_col]])))
  rows <- list()

  for (cluster_id in clusters) {
    data_k <- data[data[[cluster_col]] == cluster_id, , drop = FALSE]
    complete_n <- sum(stats::complete.cases(data_k[, unique(c(outcome, treatment, instrument, covariates, linear_controls)), drop = FALSE]))
    if (complete_n < min_n || length(unique(stats::na.omit(data_k[[instrument]]))) < 2) {
      rows[[as.character(cluster_id)]] <- data.frame(
        cluster = cluster_id,
        estimate = NA_real_,
        std_error = NA_real_,
        t_stat = NA_real_,
        p_value = NA_real_,
        n = complete_n,
        note = "Skipped: too few complete observations or no instrument variation"
      )
      next
    }

    fit <- fit_rf_local_iv(
      data = data_k,
      outcome = outcome,
      treatment = treatment,
      instrument = instrument,
      covariates = covariates,
      linear_controls = linear_controls,
      nfolds = nfolds,
      ntree = ntree,
      seed = seed + as.integer(cluster_id)
    )

    est <- fit$estimate
    rows[[as.character(cluster_id)]] <- data.frame(
      cluster = cluster_id,
      estimate = est$estimate,
      std_error = est$std_error,
      t_stat = est$t_stat,
      p_value = est$p_value,
      n = est$n,
      note = "Estimated"
    )
  }

  dplyr::bind_rows(rows)
}
