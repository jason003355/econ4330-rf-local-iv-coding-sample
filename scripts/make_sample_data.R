set.seed(4330)

if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Package 'readr' is required to write the sample CSV.", call. = FALSE)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

n_firms <- 320
years <- 1996:2019
quarters <- 1:4
firm_ids <- seq_len(n_firms)

panel <- expand.grid(firm_id = firm_ids, year = years, quarter = quarters)
panel <- panel[sample(seq_len(nrow(panel)), size = 2500), ]
panel <- panel[order(panel$firm_id, panel$year, panel$quarter), ]
panel$permno <- 10000 + panel$firm_id
panel$qdate <- as.Date(sprintf("%d-%02d-28", panel$year, panel$quarter * 3))

firm_size <- rlnorm(n_firms, meanlog = 7.5, sdlog = 0.8)
firm_growth <- rnorm(n_firms, mean = 0, sd = 0.08)
firm_rd <- pmax(0.01, rbeta(n_firms, 2, 10))
firm_industry <- sample(c(1, 10, 13, 14, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 48, 49, 50, 51, 59, 73, 78, 79, 80, 82, 87, 99), n_firms, replace = TRUE)

panel$crsp_mktcap <- firm_size[panel$firm_id] * exp(rnorm(nrow(panel), 0, 0.2))
panel$r1000_dummy <- rbinom(nrow(panel), size = 1, prob = 0.5)
panel$russell_index <- ifelse(panel$r1000_dummy == 1, "R1000", "R2000")
panel$rank_mktcap <- ifelse(
  panel$r1000_dummy == 1,
  sample(751:1000, nrow(panel), replace = TRUE),
  sample(1:250, nrow(panel), replace = TRUE)
)
panel$cutoff_running_rank <- ifelse(panel$r1000_dummy == 1, panel$rank_mktcap, 1000 + panel$rank_mktcap)
panel$distance_to_cutoff <- panel$cutoff_running_rank - 1000
panel$distance_to_cutoff_sq <- panel$distance_to_cutoff^2

year_trend <- (panel$year - min(years)) / (max(years) - min(years))
panel$atq <- panel$crsp_mktcap / runif(nrow(panel), 1.5, 3.5)
panel$saleq <- panel$atq * runif(nrow(panel), 0.15, 0.65)
panel$seqq <- panel$atq * runif(nrow(panel), 0.25, 0.85)
panel$cheq <- panel$atq * runif(nrow(panel), 0.02, 0.35)
panel$leverage <- pmin(pmax(rbeta(nrow(panel), 2, 6) + 0.05 * rnorm(nrow(panel)), 0), 1)
panel$cf <- panel$atq * rnorm(nrow(panel), 0.04, 0.08)
panel$rd_intensity <- pmax(0.001, firm_rd[panel$firm_id] + rnorm(nrow(panel), 0, 0.01))
panel$sales_growth <- firm_growth[panel$firm_id] + rnorm(nrow(panel), 0, 0.08)
panel$log_analyst_coverage <- log1p(pmax(0, round(rpois(nrow(panel), 4 + 4 * year_trend))))
panel$BM <- pmax(0.05, rlnorm(nrow(panel), -0.2, 0.5))
panel$net_income_q <- panel$atq * rnorm(nrow(panel), 0.015, 0.05)
panel$ROA <- panel$net_income_q / panel$atq
panel$ROE <- panel$net_income_q / pmax(panel$seqq, 1)
panel$cash_ratio <- panel$cheq / panel$atq
panel$stock_return_volatility <- pmax(0.05, rlnorm(nrow(panel), -2.1, 0.45))

panel$passive_pct_float <- pmin(
  pmax(
      0.02 +
      0.18 * year_trend -
      0.055 * panel$r1000_dummy +
      0.015 * panel$distance_to_cutoff / 250 +
      0.03 * log1p(panel$crsp_mktcap) / 10 +
      rnorm(nrow(panel), 0, 0.02),
    0
  ),
  0.65
)

true_effect <- -0.55
panel$xrdq_change <- 0.04 +
  true_effect * panel$passive_pct_float +
  0.25 * panel$leverage -
  0.30 * panel$cash_ratio -
  0.15 * panel$rd_intensity +
  0.05 * panel$stock_return_volatility +
  rnorm(nrow(panel), 0, 0.08)

for (sic in sort(unique(firm_industry))) {
  panel[[paste0("sic2_", sic)]] <- as.integer(firm_industry[panel$firm_id] == sic)
}
for (year in years) {
  panel[[paste0("year_", year)]] <- as.integer(panel$year == year)
}

readr::write_csv(panel, "data/sample_panel.csv")
message("Wrote data/sample_panel.csv with ", nrow(panel), " rows.")
