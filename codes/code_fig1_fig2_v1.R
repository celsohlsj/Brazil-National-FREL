# Load required packages (install if necessary)
if (!require(ggplot2))   install.packages("ggplot2")
if (!require(gridExtra)) install.packages("gridExtra")
if (!require(showtext))  install.packages("showtext")
if (!require(scales))    install.packages("scales")
if (!require(bsts))         install.packages("bsts")

library(ggplot2)
library(gridExtra)
library(showtext)
library(scales)
library(bsts)

# 0) Add Google font “Montserrat”
font_add_google("Montserrat", "Montserrat")
showtext_auto()

# 1) Real emissions data (tons CO₂ eq)
years     <- 2017:2023
emissions <- c(
  558574035, 535565170, 712722888,
  728472868, 832227808, 920000849,
  656934444
)

###########################################################################
#################        ANALYSIS OF FIGURE 1      ########################
###########################################################################
# 2) Define reference (2017–2021) and observed (2022–2023) periods
ref_emiss <- emissions[years <= 2021]
obs_years <- years[years >= 2022]
obs_emiss <- emissions[years >= 2022]
h         <- length(obs_years)

# 3) Bootstrap parameters
n_boot <- 10000
alpha  <- 0.05
set.seed(42)

# 4) Prepare results container
results <- data.frame(
  Year     = obs_years,
  MeanDiff = NA_real_,
  CI_lower = NA_real_,
  CI_upper = NA_real_
)
plots <- vector("list", h)

# 5) Bootstrap loop: compute ΔE and summary statistics
for (i in seq_along(obs_years)) {
  E_obs <- obs_emiss[i]
  
  # bootstrap ΔE = mean(ref_emiss) − E_obs
  diffs <- replicate(n_boot, {
    mean(sample(ref_emiss, length(ref_emiss), replace = TRUE)) - E_obs
  })
  
  # summarize
  m  <- mean(diffs)
  ci <- quantile(diffs, probs = c(alpha/2, 1 - alpha/2))
  
  results$MeanDiff[i] <- m
  results$CI_lower[i] <- ci[1]
  results$CI_upper[i] <- ci[2]
  
  # build histogram with % on y-axis
  df <- data.frame(deltaE = diffs)
  plots[[i]] <- ggplot(df, aes(x = deltaE, y = ..count../sum(..count..))) +
    geom_histogram(
      bins  = 30,
      fill  = "#CCCCCC",
      color = "black",
      alpha = 0.8
    ) +
    # observed ΔE = 0
    geom_vline(xintercept = 0,         color = "red", size = 1) +
    # mean ΔE (dashed red)
    geom_vline(xintercept = m,         linetype = "dashed", color = "red", size = 1) +
    # CI bounds (dashed blue)
    geom_vline(xintercept = ci,        linetype = "dashed", color = "blue", size = 1) +
    scale_x_continuous(
      labels = comma_format(big.mark = ",", decimal.mark = ".", accuracy = 1)
    ) +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      expand = expansion(mult = c(0, 0.05))
    ) +
    labs(
      title    = paste("Bootstrap ΔE for", obs_years[i]),
      subtitle = paste0(
        "Mean ΔE: ", format(m, big.mark = ",", decimal.mark = ".")
      ),
      x        = expression(Delta * E == E[simulated-reference] - E[observed]),
      y        = "Frequency (%)"
    ) +
    theme_minimal(base_family = "Montserrat") +
    theme(
      plot.title    = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 12, color = "red", lineheight = 0.9),
      axis.title    = element_text(size = 12),
      axis.text     = element_text(size = 10)
    )
}

# 6) Arrange and display histograms side by side
grid.arrange(grobs = plots, ncol = h)

# 7) Save Figure
combined_plots <- grid.arrange(grobs = plots, ncol = h)
ggsave(
  filename = "Fig2.png",
  plot     = combined_plots,
  width    = 30,       # width in cm
  height   = 15,       # height in cm
  units    = "cm",
  dpi      = 600
)

# 8) Print summary table
print(results)

###########################################################################
#################        ANALYSIS OF FIGURE 2      ########################
###########################################################################
# 2) Define reference (2017–2021) and observed (2022–2023) periods
ref_years <- years[years <= 2021]
ref_emiss <- emissions[years <= 2021]
obs_years <- years[years >= 2022]
obs_emiss <- emissions[years >= 2022]
h         <- length(obs_years)

# 3) Bootstrap parameters
n_boot <- 1000      # increase to 10000 for more precision
alpha  <- 0.05
set.seed(42)

# 4) Storage for bootstrap forecasts (one value per replicate)
boot_preds <- matrix(
  NA_real_,
  nrow = n_boot,
  ncol = h,
  dimnames = list(NULL, as.character(obs_years))
)

# 5) Bootstrap loop: resample, fit BSTS, forecast mean
for (b in seq_len(n_boot)) {
  # a) resample reference pairs
  idx    <- sample(seq_along(ref_years), length(ref_years), replace = TRUE)
  y_ts   <- ts(ref_emiss[idx], start = min(ref_years), frequency = 1)
  
  # b) specify and fit BSTS (local linear trend only)
  ss     <- AddLocalLinearTrend(list(), y_ts)
  fit    <- bsts(y_ts, state.specification = ss, niter = 1000, ping = 0)
  
  # c) forecast h steps ahead, drop burn-in
  pred   <- predict(fit, horizon = h, burn = 200)
  
  # d) extract the posterior predictive mean for each horizon
  boot_preds[b, ] <- pred$mean
}

# 6) Summarize bootstrap distribution for each year
mean_proj <- colMeans(boot_preds)
ci_bounds <- apply(boot_preds, 2, quantile, probs = c(alpha/2, 1 - alpha/2))
ci_lower  <- ci_bounds[1, ]
ci_upper  <- ci_bounds[2, ]

# 7) Build results table and check coverage
results_bsts_boot <- data.frame(
  Year     = obs_years,
  Observed = obs_emiss,
  MeanProj = mean_proj,
  CI_lower = ci_lower,
  CI_upper = ci_upper,
  WithinCI = obs_emiss >= ci_lower & obs_emiss <= ci_upper
)

# 8) Plot histograms with y axis in percent
library(scales)  # para percent_format()

plots <- lapply(seq_len(h), function(i) {
  df       <- data.frame(forecast = boot_preds[, i])
  mean_val <- mean_proj[i]
  
  ggplot(df, aes(x = forecast, y = ..count.. / sum(..count..))) +
    geom_histogram(
      bins  = 30,
      fill  = "#CCCCCC",
      color = "black",
      alpha = 0.8
    ) +
    # observed line (solid red)
    geom_vline(
      xintercept = obs_emiss[i],
      color      = "red",
      size       = 1
    ) +
    # mean line (dashed red)
    geom_vline(
      xintercept = mean_val,
      linetype   = "dashed",
      color      = "red",
      size       = 1
    ) +
    # CI lines (dashed blue)
    geom_vline(
      xintercept = c(ci_lower[i], ci_upper[i]),
      linetype   = "dashed",
      color      = "blue",
      size       = 1
    ) +
    scale_x_continuous(
      labels = comma_format(big.mark = ",", decimal.mark = ".", accuracy = 1)
    ) +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      expand = expansion(mult = c(0, 0.05))
    ) +
    labs(
      title    = paste("Bootstrap BSTS Forecast for", obs_years[i]),
      subtitle = paste0(
        "Observed: ", format(obs_emiss[i], big.mark = ",", decimal.mark = "."),
        "\nMean Bootstrap: ", format(mean_val, big.mark = ",", decimal.mark = ".")
      ),
      x        = expression(paste("Forecasted Emission (t ", CO[2], " eq)")),
      y        = "Frequency (%)"
    ) +
    theme_minimal(base_family = "Montserrat") +
    theme(
      plot.title    = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 12, color = "red", lineheight = 0.9),
      axis.title    = element_text(size = 12),
      axis.text     = element_text(size = 10)
    )
})

# 9) Arrange the histograms side by side
grid.arrange(grobs = plots, ncol = h)

# 10) Save Figure
combined_plots <- grid.arrange(grobs = plots, ncol = h)
ggsave(
  filename = "Fig2.png",
  plot     = combined_plots,
  width    = 30,       # width in cm
  height   = 15,       # height in cm
  units    = "cm",
  dpi      = 600
)

# 11) Print summary table
print(results_bsts_boot)