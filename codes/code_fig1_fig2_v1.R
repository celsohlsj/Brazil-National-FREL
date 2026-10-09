# =============================================================================
# Increased deforestation and forest degradation counteract Brazil's REDD+
# results in 2022 — NCOMMS-25-40335
#
# Figure 2: bootstrap deviation test
# Figure 3: BSTS probabilistic counterfactual reconstruction
#
# Revision R2: figures recoloured with the Okabe-Ito colour-blind-safe palette.
# Categorical distinctions are encoded redundantly by hue, line type and line
# width, so that no information depends on colour discrimination alone.
# =============================================================================

## ---- Packages ---------------------------------------------------------------
pkgs <- c("ggplot2", "gridExtra", "scales", "bsts", "ragg", "systemfonts")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

library(ggplot2)
library(gridExtra)
library(scales)
library(bsts)
library(ragg)

DPI <- 600

# If showtext was enabled earlier in this R session it keeps intercepting text
# measurement, and ragg then draws glyphs at a different scale than the space
# reserved for them (axis titles drift far from the panel). Disable it.
if (isNamespaceLoaded("showtext")) showtext::showtext_auto(FALSE)

## ---- Font -------------------------------------------------------------------
# ragg reads system fonts directly, so no showtext hook is needed. This matters
# because gridExtra::arrangeGrob() measures text when the grob is BUILT, using
# the active graphics device; with showtext that device is often not hooked,
# grid falls back to the PostScript font database, and label metrics come out
# wrong (overlapping titles and axis labels).
#
# Montserrat must be installed at the operating-system level:
#   https://fonts.google.com/specimen/Montserrat  ->  install the .ttf files
FONT <- "Montserrat"
if (!FONT %in% systemfonts::system_fonts()$family) {
  warning("Font '", FONT, "' not installed on this system; falling back to the ",
          "default sans-serif. Install Montserrat to reproduce the published ",
          "figures exactly.", call. = FALSE)
  FONT <- "sans"
}


## ---- Colour-blind-safe palette (Okabe & Ito 2008) ---------------------------
# Roles are encoded by hue AND line type AND line width (redundant coding).
COL_MEAN <- "#000000"   # black      | mean of the bootstrap distribution
COL_CI   <- "#0072B2"   # blue       | 95% confidence interval bounds
COL_OBS  <- "#D55E00"   # vermillion | observed emission / reference at dE = 0
COL_BAR  <- "#D9D9D9"   # light grey | histogram fill
COL_BARO <- "#8C8C8C"   # mid grey   | histogram outline (was black: it competed
#              with the black long-dashed mean line)
COL_TEXT <- "#333333"   # dark grey  | all text

LTY_MEAN <- "longdash"
LTY_CI   <- "dotted"
LTY_OBS  <- "solid"

LWD_MEAN <- 0.8
LWD_CI   <- 0.8
LWD_OBS  <- 1.2         # observed line is thickest: survives greyscale printing


## ---- Shared theme -----------------------------------------------------------
# Subtitle kept as a single-colour element_text (as in the original script) to
# avoid text collisions. Line identity is given in the figure caption.
theme_fig <- function() {
  theme_minimal(base_size = 8, base_family = FONT) +
    theme(
      plot.title    = element_text(size = 9, face = "bold", colour = COL_TEXT,
                                   margin = margin(b = 4)),
      plot.subtitle = element_text(size = 8, colour = COL_TEXT, lineheight = 1.1,
                                   margin = margin(b = 8)),
      axis.title.x  = element_text(size = 8, colour = COL_TEXT,
                                   margin = margin(t = 2)),
      axis.title.y  = element_text(size = 8, colour = COL_TEXT,
                                   margin = margin(r = 2)),
      axis.text     = element_text(size = 7, colour = COL_TEXT),
      panel.grid.minor = element_blank(),
      plot.margin   = margin(10, 12, 8, 10)
    )
}

fmt <- function(x) format(round(x), big.mark = ",", scientific = FALSE)


## ---- Data (t CO2 eq) --------------------------------------------------------
years     <- 2017:2023
emissions <- c(558574035, 535565170, 712722888,
               728472868, 832227808, 920000849,
               656934444)

ref_years <- years[years <= 2021]
ref_emiss <- emissions[years <= 2021]
obs_years <- years[years >= 2022]
obs_emiss <- emissions[years >= 2022]
h         <- length(obs_years)

N_BOOT_DEV  <- 1000   # Figure 2 — bootstrap deviation test
N_BOOT_BSTS <- 1000    # Figure 3 — BSTS reconstruction
ALPHA       <- 0.05


# =============================================================================
# FIGURE 2 — Bootstrap deviation test (dE = E_simulated-reference - E_observed)
# =============================================================================
set.seed(42)

results  <- data.frame(Year = obs_years, MeanDiff = NA_real_,
                       CI_lower = NA_real_, CI_upper = NA_real_)
plots_f2 <- vector("list", h)

for (i in seq_along(obs_years)) {
  E_obs <- obs_emiss[i]
  
  diffs <- replicate(N_BOOT_DEV, {
    mean(sample(ref_emiss, length(ref_emiss), replace = TRUE)) - E_obs
  })
  
  m  <- mean(diffs)
  ci <- quantile(diffs, probs = c(ALPHA / 2, 1 - ALPHA / 2))
  
  results$MeanDiff[i] <- m
  results$CI_lower[i] <- ci[1]
  results$CI_upper[i] <- ci[2]
  
  df <- data.frame(deltaE = diffs)
  
  plots_f2[[i]] <- ggplot(df, aes(x = deltaE,
                                  y = after_stat(count) / sum(after_stat(count)))) +
    geom_histogram(bins = 30, fill = COL_BAR, colour = COL_BARO, linewidth = 0.3) +
    # 95% CI bounds — blue, dotted
    geom_vline(xintercept = ci, colour = COL_CI,
               linetype = LTY_CI, linewidth = LWD_CI) +
    # mean dE — black, long-dashed
    geom_vline(xintercept = m, colour = COL_MEAN,
               linetype = LTY_MEAN, linewidth = LWD_MEAN) +
    # reference at dE = 0 — vermillion, solid, thickest (drawn last, on top)
    geom_vline(xintercept = 0, colour = COL_OBS,
               linetype = LTY_OBS, linewidth = LWD_OBS) +
    scale_x_continuous(labels = function(x) comma(x / 1e6), n.breaks = 6) +
    scale_y_continuous(labels = percent_format(accuracy = 1),
                       expand = expansion(mult = c(0, 0.05))) +
    labs(
      title    = paste("Bootstrap \u0394E for", obs_years[i]),
      subtitle = paste0("Mean \u0394E: ", fmt(m)),
      # Full definition (dE = E_simulated-reference - E_observed) is given in
      # the figure caption; keeping the axis title short prevents clipping.
      x = expression(Delta * E ~ "(million t " * CO[2] * " eq)"),
      y = "Frequency (%)"
    ) +
    theme_fig()
}

fig2 <- arrangeGrob(grobs = plots_f2, ncol = h)
ggsave("Fig2.png", plot = fig2, width = 18, height = 9, units = "cm",
       dpi = DPI, device = ragg::agg_png)
print(results)


# =============================================================================
# FIGURE 3 — BSTS probabilistic counterfactual reconstruction
# ---------------------------------------------------------------------------
# The reference period has only 5 years, so a resample with replacement can
# draw the same year five times (probability (1/5)^4 = 0.16%). The resulting
# series has zero variance, the local linear trend model is undefined, and
# bsts() fails when building the prior for sigma. Such resamples are rejected
# and redrawn. At N_BOOT_BSTS = 1,000 no rejection occurs, so the random
# number stream — and therefore the results — are identical to a run without
# this guard.
# =============================================================================
set.seed(42)

boot_preds <- matrix(NA_real_, nrow = N_BOOT_BSTS, ncol = h,
                     dimnames = list(NULL, as.character(obs_years)))

draw_valid_resample <- function(x, max_try = 1000) {
  for (k in seq_len(max_try)) {
    idx <- sample(seq_along(x), length(x), replace = TRUE)
    if (stats::sd(x[idx]) > 0) return(list(idx = idx, rejected = k - 1L))
  }
  stop("No non-degenerate resample drawn after ", max_try, " attempts.")
}

n_rejected <- 0L
n_failed   <- 0L

pb <- txtProgressBar(min = 0, max = N_BOOT_BSTS, style = 3)
for (b in seq_len(N_BOOT_BSTS)) {
  draw       <- draw_valid_resample(ref_emiss)
  n_rejected <- n_rejected + draw$rejected
  y_ts       <- ts(ref_emiss[draw$idx], start = min(ref_years), frequency = 1)
  
  ss   <- AddLocalLinearTrend(list(), y_ts)
  fit  <- tryCatch(bsts(y_ts, state.specification = ss, niter = 1000, ping = 0),
                   error = function(e) NULL)
  
  if (is.null(fit)) {
    n_failed <- n_failed + 1L          # left as NA, excluded from summaries
  } else {
    pred <- predict(fit, horizon = h, burn = 200)
    boot_preds[b, ] <- pred$mean
  }
  setTxtProgressBar(pb, b)
}
close(pb)

message("Degenerate resamples rejected and redrawn: ", n_rejected)
message("BSTS fits that failed for other reasons: ", n_failed)

mean_proj <- colMeans(boot_preds, na.rm = TRUE)
ci_bounds <- apply(boot_preds, 2, quantile,
                   probs = c(ALPHA / 2, 1 - ALPHA / 2), na.rm = TRUE)
ci_lower  <- ci_bounds[1, ]
ci_upper  <- ci_bounds[2, ]

results_bsts_boot <- data.frame(
  Year     = obs_years,
  Observed = obs_emiss,
  MeanProj = mean_proj,
  CI_lower = ci_lower,
  CI_upper = ci_upper,
  WithinCI = obs_emiss >= ci_lower & obs_emiss <= ci_upper
)

plots_f3 <- lapply(seq_len(h), function(i) {
  df       <- data.frame(forecast = boot_preds[, i])
  mean_val <- mean_proj[i]
  
  ggplot(df, aes(x = forecast,
                 y = after_stat(count) / sum(after_stat(count)))) +
    geom_histogram(bins = 30, fill = COL_BAR, colour = COL_BARO, linewidth = 0.3) +
    # 95% CI bounds — blue, dotted
    geom_vline(xintercept = c(ci_lower[i], ci_upper[i]), colour = COL_CI,
               linetype = LTY_CI, linewidth = LWD_CI) +
    # mean projected emission — black, long-dashed
    geom_vline(xintercept = mean_val, colour = COL_MEAN,
               linetype = LTY_MEAN, linewidth = LWD_MEAN) +
    # observed emission — vermillion, solid, thickest (drawn last, on top).
    # In the 2023 panel observed and mean nearly coincide; contrasting hue
    # plus line type keeps them separable.
    geom_vline(xintercept = obs_emiss[i], colour = COL_OBS,
               linetype = LTY_OBS, linewidth = LWD_OBS) +
    scale_x_continuous(labels = function(x) comma(x / 1e6), n.breaks = 6) +
    scale_y_continuous(labels = percent_format(accuracy = 1),
                       expand = expansion(mult = c(0, 0.05))) +
    labs(
      title    = paste("Bootstrap BSTS Forecast for", obs_years[i]),
      subtitle = paste0("Observed: ", fmt(obs_emiss[i]),
                        "\nMean Bootstrap: ", fmt(mean_val)),
      x = expression(paste("Forecasted Emission (million t ", CO[2], " eq)")),
      y = "Frequency (%)"
    ) +
    theme_fig()
})

fig3 <- arrangeGrob(grobs = plots_f3, ncol = h)
ggsave("Fig3.png", plot = fig3, width = 18, height = 9, units = "cm",
       dpi = DPI, device = ragg::agg_png)
print(results_bsts_boot)


# =============================================================================
# Colour-vision-deficiency verification (evidence for the point-by-point)
# =============================================================================
if (requireNamespace("colorBlindness", quietly = TRUE)) {
  colorBlindness::cvdPlot(plots_f2[[1]])
  colorBlindness::cvdPlot(plots_f3[[1]])
}

# Record the computational environment (required for Code Availability)
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")