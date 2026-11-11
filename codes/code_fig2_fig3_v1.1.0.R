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
#
# Version: 1.1.0 (2026-11-11)
# Changelog:
#   1.1.0 — BSTS made exactly reproducible: the C++ sampler of bsts() and
#           predict() is now seeded explicitly (seed = SEED_BSTS + b for
#           replicate b). Previously it was seeded from the system clock
#           (bsts default, seed = NULL), so each run gave slightly different
#           Monte Carlo draws even with set.seed(42), which controls only the
#           bootstrap resampling. The resampled series are unchanged.
#   1.0.1 — Reference R and package versions documented in the header and
#           checked at run time (check_environment()). No change to the
#           analysis or figures.
#   1.0.0 — Final release for NCOMMS-25-40335B (consolidates the development
#           versions listed below).
# Development history (pre-1.0.0):
#   1.4 — Working directory set automatically to the folder containing this
#         script (RStudio, source() or Rscript). No change to the analysis.
#   1.3 — Final editorial revision (Author Checklist, NCOMMS-25-40335B). No
#         change to the analysis (same seeds, data and models):
#         * panel labels a and b (bold, Nature artwork guide); panel titles
#           in plain font (no bold text in display items);
#         * subtitles in million t CO2 eq with two decimals, matching the
#           manuscript text; E in Delta-E typeset in italic (scalar variable);
#         * figures also exported as vector PDF (Fig2.pdf, Fig3.pdf);
#         * 10,000 replicates and summary statistics of Figs. 2 and 3 written
#           into Source_Data.xlsx (sheets Fig2 and Fig3) when that file is in
#           the working directory.
#   1.2 — Final summary block printed at the end of the script with the mean
#         and 95% CI of Figures 2 and 3 together (visible after the BSTS
#         progress bar). No change to the analysis.
#   1.1 — Console output of the mean and 95% confidence interval for Figure 2
#         (bootstrap dE) and Figure 3 (BSTS), in million t CO2 eq, in the
#         format used in the manuscript text. No change to the analysis.
#   1.0 — R2 version (Okabe-Ito palette, redundant line coding).
#
# Reference computational environment (results and figures in the paper):
#   R 4.6.0 (2026-04-24), aarch64-apple-darwin23, macOS 27.0
#   bsts 0.9.11 (Boom 0.9.16, BoomSpikeSlab 1.2.7), ggplot2 4.0.3, gridExtra 2.3,
#   scales 1.4.0, ragg 1.5.2, systemfonts 1.3.2, openxlsx 4.2.9, rstudioapi 0.18.0
# The script reports any difference from these versions when it runs.
# =============================================================================

## ---- Packages ---------------------------------------------------------------
pkgs <- c("ggplot2", "gridExtra", "scales", "bsts", "ragg", "systemfonts", "openxlsx",
          "rstudioapi")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

library(ggplot2)
library(gridExtra)
library(scales)
library(bsts)
library(ragg)

## ---- Check the computational environment ------------------------------------
# Versions used to produce the published figures. A different version is not an
# error, but it is reported because results may change slightly.
# Fig. 2 (bootstrap, base R, set.seed(42)) and Fig. 3 (BSTS, explicit C++
# seeds) are exactly reproducible with these versions. With other versions of
# bsts/Boom, the MCMC draws of Fig. 3 may differ slightly.
REF_R   <- "4.6.0"
REF_PKG <- c(bsts = "0.9.11", Boom = "0.9.16", BoomSpikeSlab = "1.2.7",
             ggplot2 = "4.0.3", gridExtra = "2.3", scales = "1.4.0",
             ragg = "1.5.2", systemfonts = "1.3.2", openxlsx = "4.2.9",
             rstudioapi = "0.18.0")
check_environment <- function(ref_r, ref_pkg) {
  same <- TRUE
  if (as.character(getRversion()) != ref_r) {
    message("R ", getRversion(), " (reference: R ", ref_r, ")"); same <- FALSE
  }
  for (p in names(ref_pkg)) {
    v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) "not installed")
    if (v != ref_pkg[[p]]) {
      message(sprintf("%-14s %-14s (reference: %s)", p, v, ref_pkg[[p]])); same <- FALSE
    }
  }
  if (same) {
    message("Computational environment identical to the reference.")
  } else {
    message("Environment differs from the reference (see above). The BSTS statistics of Fig. 3 may differ slightly from the paper.")
  }
  invisible(same)
}
check_environment(REF_R, REF_PKG)

## ---- Working directory = folder that contains this script -------------------
# Input files (CSV, Source_Data.xlsx) and outputs (figures) live next to the
# script, so the working directory is set automatically. Works with the
# RStudio "Source" button, source("script.R"), Rscript, and line-by-line runs
# in RStudio.
set_script_dir <- function() {
  path <- NULL
  # 1) Rscript script.R
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(f) == 1 && nzchar(f)) path <- f
  # 2) source("script.R") or the RStudio "Source" button
  if (is.null(path)) {
    for (i in rev(seq_len(sys.nframe()))) {
      of <- sys.frame(i)$ofile
      if (!is.null(of)) { path <- of; break }
    }
  }
  # 3) lines run interactively in RStudio
  if (is.null(path) && requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    p <- rstudioapi::getSourceEditorContext()$path
    if (!is.null(p) && nzchar(p)) path <- p
  }
  if (is.null(path)) {
    warning("Script folder not detected; using the current directory: ",
            getwd(), call. = FALSE)
    return(invisible(getwd()))
  }
  d <- dirname(normalizePath(path))
  setwd(d)
  message("Working directory: ", d)
  invisible(d)
}
set_script_dir()

if (!file.exists("Source_Data.xlsx"))
  warning("Source_Data.xlsx not found next to the script; Figs. 2-3 will be ",
          "produced but the replicates will not be exported.", call. = FALSE)

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
      plot.title    = element_text(size = 9, face = "plain", colour = COL_TEXT,
                                   margin = margin(b = 4)),
      plot.tag      = element_text(size = 10, face = "bold", colour = "#000000"),
      plot.tag.position = "topleft",
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

# Mean and 95% CI in million t CO2 eq, two decimals (manuscript format)
fmt_mt <- function(x) formatC(x / 1e6, format = "f", digits = 2, big.mark = ",")
print_ci <- function(label, years, mean, lower, upper, n_boot) {
  cat("\n", label, " (", format(n_boot, big.mark = ","), " bootstrap replicates; ",
      "95% CI = 2.5th-97.5th percentiles)\n", sep = "")
  for (i in seq_along(years)) {
    cat(sprintf("  %d: mean = %s million t CO2 eq (95%% CI: %s to %s)\n",
                years[i], fmt_mt(mean[i]), fmt_mt(lower[i]), fmt_mt(upper[i])))
  }
}


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

N_BOOT_DEV  <- 10000   # Figure 2 — bootstrap deviation test
N_BOOT_BSTS <- 10000    # Figure 3 — BSTS reconstruction
ALPHA       <- 0.05


# =============================================================================
# FIGURE 2 — Bootstrap deviation test (dE = E_simulated-reference - E_observed)
# =============================================================================
set.seed(42)

results  <- data.frame(Year = obs_years, MeanDiff = NA_real_,
                       CI_lower = NA_real_, CI_upper = NA_real_)
plots_f2 <- vector("list", h)
diffs_all <- matrix(NA_real_, nrow = N_BOOT_DEV, ncol = h,
                    dimnames = list(NULL, as.character(obs_years)))

for (i in seq_along(obs_years)) {
  E_obs <- obs_emiss[i]
  
  diffs <- replicate(N_BOOT_DEV, {
    mean(sample(ref_emiss, length(ref_emiss), replace = TRUE)) - E_obs
  })
  
  m  <- mean(diffs)
  ci <- quantile(diffs, probs = c(ALPHA / 2, 1 - ALPHA / 2))
  
  diffs_all[, i] <- diffs
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
      tag      = letters[i],
      title    = as.character(obs_years[i]),
      subtitle = bquote("Mean " * Delta * italic(E) * ": " * .(fmt_mt(m))),
      # Full definition (dE = E_simulated-reference - E_observed) is given in
      # the figure caption; keeping the axis title short prevents clipping.
      x = expression(Delta * italic(E) ~ "(million t " * CO[2] * " eq)"),
      y = "Frequency (%)"
    ) +
    theme_fig()
}

fig2 <- arrangeGrob(grobs = plots_f2, ncol = h)
ggsave("Fig2.png", plot = fig2, width = 18, height = 9, units = "cm",
       dpi = DPI, device = ragg::agg_png)
tryCatch(ggsave("Fig2.pdf", plot = fig2, width = 18, height = 9, units = "cm",
                device = cairo_pdf),
         error = function(e) message("Vector PDF not written (cairo unavailable): ",
                                     conditionMessage(e)))
print(results)
print_ci("Figure 2 — bootstrap dE (E_simulated-reference - E_observed)",
         results$Year, results$MeanDiff, results$CI_lower, results$CI_upper,
         N_BOOT_DEV)


# =============================================================================
# FIGURE 3 — BSTS probabilistic counterfactual reconstruction
# ---------------------------------------------------------------------------
# The reference period has only 5 years, so a resample with replacement can
# draw the same year five times (probability (1/5)^4 = 0.16%). The resulting
# series has zero variance, the local linear trend model is undefined, and
# bsts() fails when building the prior for sigma. Such resamples are rejected
# and redrawn.
#
# Reproducibility: set.seed(42) controls the bootstrap resampling (R random
# number generator). bsts() and predict() use their own C++ random number
# generator, which is seeded from the system clock unless a seed is given, so
# each replicate b receives the fixed seed SEED_BSTS + b. These seeds do not
# consume the R random number stream, so the resampled series are unchanged.
# =============================================================================
set.seed(42)
SEED_BSTS <- 4200000L   # base of the per-replicate C++ seeds (SEED_BSTS + b)

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
  fit  <- tryCatch(bsts(y_ts, state.specification = ss, niter = 1000, ping = 0,
                        seed = SEED_BSTS + b),
                   error = function(e) NULL)
  
  if (is.null(fit)) {
    n_failed <- n_failed + 1L          # left as NA, excluded from summaries
  } else {
    pred <- predict(fit, horizon = h, burn = 200, seed = SEED_BSTS + b)
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
      tag      = letters[i],
      title    = as.character(obs_years[i]),
      subtitle = paste0("Observed: ", fmt_mt(obs_emiss[i]),
                        "\nMean projected: ", fmt_mt(mean_val)),
      x = expression(paste("Forecasted Emission (million t ", CO[2], " eq)")),
      y = "Frequency (%)"
    ) +
    theme_fig()
})

fig3 <- arrangeGrob(grobs = plots_f3, ncol = h)
ggsave("Fig3.png", plot = fig3, width = 18, height = 9, units = "cm",
       dpi = DPI, device = ragg::agg_png)
tryCatch(ggsave("Fig3.pdf", plot = fig3, width = 18, height = 9, units = "cm",
                device = cairo_pdf),
         error = function(e) message("Vector PDF not written (cairo unavailable): ",
                                     conditionMessage(e)))
print(results_bsts_boot)
print_ci("Figure 3 — BSTS projected emission",
         results_bsts_boot$Year, results_bsts_boot$MeanProj,
         results_bsts_boot$CI_lower, results_bsts_boot$CI_upper, N_BOOT_BSTS)
cat(sprintf("  Observed: %s\n",
            paste(obs_years, "=", fmt_mt(obs_emiss), collapse = "; ")))


# =============================================================================
# Colour-vision-deficiency verification (evidence for the point-by-point)
# =============================================================================
if (requireNamespace("colorBlindness", quietly = TRUE)) {
  colorBlindness::cvdPlot(plots_f2[[1]])
  colorBlindness::cvdPlot(plots_f3[[1]])
}

# Record the computational environment (required for Code Availability)
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")

# =============================================================================
# SUMMARY — mean and 95% confidence interval of Figures 2 and 3
# (million t CO2 eq; 95% CI = 2.5th and 97.5th percentiles of the bootstrap
# distribution)
# =============================================================================
cat("\n=============================================================\n")
cat("SUMMARY — Figures 2 and 3 (million t CO2 eq)\n")
cat("=============================================================\n")
print_ci("Figure 2 — bootstrap dE (E_simulated-reference - E_observed)",
         results$Year, results$MeanDiff, results$CI_lower, results$CI_upper,
         N_BOOT_DEV)
print_ci("Figure 3 — BSTS projected emission",
         results_bsts_boot$Year, results_bsts_boot$MeanProj,
         results_bsts_boot$CI_lower, results_bsts_boot$CI_upper, N_BOOT_BSTS)
cat(sprintf("  Observed: %s\n",
            paste(obs_years, "=", fmt_mt(obs_emiss), collapse = "; ")))
cat("=============================================================\n")


# =============================================================================
# SOURCE DATA — write summaries and 10,000 replicates into Source_Data.xlsx
# (sheets Fig2 and Fig3; rows 15-17 = summary, row 20 onward = replicates)
# =============================================================================
if (file.exists("Source_Data.xlsx")) {
  wb <- openxlsx::loadWorkbook("Source_Data.xlsx")

  sum2 <- data.frame(Year = results$Year,
                     `Mean dE (t CO2 eq)` = results$MeanDiff,
                     `95% CI lower (t CO2 eq)` = results$CI_lower,
                     `95% CI upper (t CO2 eq)` = results$CI_upper,
                     check.names = FALSE)
  rep2 <- data.frame(Replicate = seq_len(N_BOOT_DEV),
                     `dE 2022 (t CO2 eq)` = diffs_all[, "2022"],
                     `dE 2023 (t CO2 eq)` = diffs_all[, "2023"],
                     check.names = FALSE)
  openxlsx::writeData(wb, "Fig2", sum2, startRow = 15, startCol = 1)
  openxlsx::writeData(wb, "Fig2", rep2, startRow = 20, startCol = 1)

  sum3 <- data.frame(Year = results_bsts_boot$Year,
                     `Observed emission (t CO2 eq)` = results_bsts_boot$Observed,
                     `Mean projected emission (t CO2 eq)` = results_bsts_boot$MeanProj,
                     `95% CI lower (t CO2 eq)` = results_bsts_boot$CI_lower,
                     `95% CI upper (t CO2 eq)` = results_bsts_boot$CI_upper,
                     check.names = FALSE)
  rep3 <- data.frame(Replicate = seq_len(N_BOOT_BSTS),
                     `Projected emission 2022 (t CO2 eq)` = boot_preds[, "2022"],
                     `Projected emission 2023 (t CO2 eq)` = boot_preds[, "2023"],
                     check.names = FALSE)
  openxlsx::writeData(wb, "Fig3", sum3, startRow = 15, startCol = 1)
  openxlsx::writeData(wb, "Fig3", rep3, startRow = 20, startCol = 1)

  openxlsx::saveWorkbook(wb, "Source_Data.xlsx", overwrite = TRUE)
  message("Source_Data.xlsx updated (sheets Fig2 and Fig3).")
} else {
  message("Source_Data.xlsx not found in the working directory; replicates not exported.")
}
