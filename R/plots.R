plot_outcome_distribution <- function(data, output_path) {
  x <- safe_numeric(data$xrdq_change)
  x <- x[is.finite(x)]
  q <- stats::quantile(x, probs = c(0.01, 0.99), na.rm = TRUE)
  df <- data.frame(xrdq_change = winsorize_to_thresholds(x, q[[1]], q[[2]]))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$xrdq_change)) +
    ggplot2::geom_histogram(ggplot2::aes(y = ggplot2::after_stat(density)), bins = 40) +
    ggplot2::geom_density() +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed") +
    ggplot2::labs(x = "R&D cut ratio", y = "Density") +
    ggplot2::theme_minimal()

  ggplot2::ggsave(output_path, p, width = 7, height = 4.5)
}

plot_passive_cutoff <- function(data, output_path, bandwidth = 250, bin_width = 25) {
  if (!all(c("russell_index", "rank_mktcap", "passive_pct_float") %in% names(data))) {
    warning("Skipping cutoff plot because required columns are missing.")
    return(invisible(NULL))
  }

  data_rd <- construct_cutoff_running(data) |>
    dplyr::mutate(
      passive_pct_float = safe_numeric(.data$passive_pct_float)
    ) |>
    dplyr::filter(
      is.finite(.data$cutoff_running_rank),
      is.finite(.data$passive_pct_float),
      abs(.data$distance_to_cutoff) <= bandwidth
    ) |>
    dplyr::mutate(bin = floor(.data$cutoff_running_rank / bin_width) * bin_width) |>
    dplyr::group_by(.data$bin) |>
    dplyr::summarise(
      running_mid = mean(.data$cutoff_running_rank, na.rm = TRUE),
      passive_mean = mean(.data$passive_pct_float, na.rm = TRUE),
      n = dplyr::n(),
      .groups = "drop"
    )

  p <- ggplot2::ggplot(data_rd, ggplot2::aes(x = .data$running_mid, y = 100 * .data$passive_mean)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(
      data = data_rd[data_rd$running_mid <= 1000, ],
      method = "lm",
      se = FALSE
    ) +
    ggplot2::geom_smooth(
      data = data_rd[data_rd$running_mid > 1000, ],
      method = "lm",
      se = FALSE
    ) +
    ggplot2::geom_vline(xintercept = 1000, linetype = "dashed") +
    ggplot2::labs(x = "Market-cap rank running variable", y = "Average passive share (%)") +
    ggplot2::theme_minimal()

  ggplot2::ggsave(output_path, p, width = 7, height = 4.5)
}

plot_importance <- function(importance, output_path, title, top_n = 20) {
  if (nrow(importance) == 0) {
    return(invisible(NULL))
  }

  df <- importance |>
    dplyr::slice_head(n = top_n) |>
    dplyr::mutate(variable = stats::reorder(.data$variable, .data$importance))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$variable, y = .data$importance)) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "Average random-forest importance", title = title) +
    ggplot2::theme_minimal()

  ggplot2::ggsave(output_path, p, width = 7, height = 5)
}
