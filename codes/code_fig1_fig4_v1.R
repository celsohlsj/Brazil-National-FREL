# =============================================================================
# Increased deforestation and forest degradation counteract Brazil's REDD+
# results in 2022 — NCOMMS-25-40335
#
# Figure 1: official (2017-2021) and estimated (2022-2023) FREL emissions
# Figure 4: simulated modified National FREL, by disturbance type
#
# Both figures are built directly from the Source Data CSV files, so the
# display items and the deposited data cannot drift apart.
#
# Revision R2: Okabe-Ito colour-blind-safe palette. Categories are encoded by
# hue (not by lightness of a single hue, as in the previous version), and
# in-bar label colour switches with fill luminance to keep WCAG contrast
# above 4.5:1.
# =============================================================================

## ---- Packages ---------------------------------------------------------------
pkgs <- c("ggplot2", "scales", "ragg", "systemfonts")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

library(ggplot2)
library(scales)
library(ragg)

DPI <- 600
# Plain-text Source Data. Emissions are in t CO2 eq; the figures plot millions.
CSV_F1 <- "fig1_data.csv"
CSV_F4 <- "fig4_data.csv"

if (isNamespaceLoaded("showtext")) showtext::showtext_auto(FALSE)

FONT <- "Montserrat"
if (!FONT %in% systemfonts::system_fonts()$family) {
  warning("Font '", FONT, "' not installed; falling back to default sans-serif.",
          call. = FALSE)
  FONT <- "sans"
}


## ---- Palette ----------------------------------------------------------------
COL_OFFICIAL   <- "#0072B2"   # blue       | official FREL emissions
COL_ESTIMATED  <- "#E69F00"   # orange     | emissions estimated in this study
COL_DEFOR      <- "#0072B2"   # blue       | emissions from deforestation
COL_DEGRAD     <- "#56B4E9"   # sky blue   | emissions from degradation
COL_SERIES     <- "#D55E00"   # vermillion | emissions series from Figure 1
COL_BASELINE   <- "#000000"   # black      | FREL baselines
COL_TEXT       <- "#333333"   # dark grey  | all text on white background
COL_ON_DARK    <- "#FFFFFF"   # white      | labels on dark fills  (5.19:1)
COL_ON_LIGHT   <- "#1A1A1A"   # near black | labels on light fills (7.5-7.7:1)

theme_fig <- function() {
  theme_classic(base_size = 8, base_family = FONT) +
    theme(
      axis.title.x     = element_blank(),
      axis.title.y     = element_text(size = 8, colour = COL_TEXT,
                                      margin = margin(r = 2)),
      axis.text        = element_text(size = 7, colour = COL_TEXT),
      axis.line        = element_line(colour = COL_TEXT, linewidth = 0.3),
      axis.ticks       = element_line(colour = COL_TEXT, linewidth = 0.3),
      legend.title     = element_blank(),
      legend.text      = element_text(size = 7, colour = COL_TEXT),
      legend.key.size  = unit(0.4, "cm"),
      legend.spacing.y = unit(0.05, "cm"),
      legend.margin    = margin(0, 0, 0, 0),
      legend.position  = "right",
      plot.margin      = margin(8, 8, 6, 8)
    )
}

M <- 1e6   # figures are plotted in million t CO2 eq


# =============================================================================
# FIGURE 1
# =============================================================================
f1 <- read.csv(CSV_F1, stringsAsFactors = FALSE)

FREL <- f1$official_frel_tco2eq[1]

f1$value  <- f1$emissions_tco2eq
f1$series <- factor(paste(f1$series, "FREL Emissions"),
                    levels = c("Official FREL Emissions",
                               "Estimated FREL Emissions"))
# Label colour follows fill luminance, not category
f1$lab_col <- ifelse(f1$series == "Official FREL Emissions",
                     COL_ON_DARK, COL_ON_LIGHT)

fig1 <- ggplot(f1, aes(x = factor(year), y = value / M, fill = series)) +
  geom_col(width = 0.65) +
  # In-bar value labels, centred vertically. Bar midpoints (280-460) sit far
  # below the FREL baseline (674), so no label can collide with it.
  geom_text(aes(y = value / (2 * M), label = comma(round(value / M)),
                colour = lab_col),
            angle = 90, hjust = 0.5, vjust = 0.5, size = 2.4, family = FONT,
            show.legend = FALSE) +
  # official National FREL baseline
  geom_hline(aes(yintercept = FREL / M, linetype = "Official National FREL"),
             colour = COL_BASELINE, linewidth = 0.5) +
  annotate("text", x = 0.7, y = FREL / M, vjust = -0.6, hjust = 0,
           label = paste0(comma(round(FREL / M)), "*"),
           colour = COL_TEXT, size = 2.6, family = FONT, fontface = "bold") +
  scale_fill_manual(values = c("Official FREL Emissions"  = COL_OFFICIAL,
                               "Estimated FREL Emissions" = COL_ESTIMATED)) +
  scale_colour_identity() +
  scale_linetype_manual(values = c("Official National FREL" = "solid")) +
  scale_y_continuous(labels = comma, limits = c(0, 1200),
                     breaks = seq(0, 1200, 200),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(y = expression("tons " * CO[2] * " eq (millions)")) +
  theme_fig()

ggsave("Fig1.png", fig1, width = 18, height = 10, units = "cm",
       dpi = DPI, device = ragg::agg_png)


# =============================================================================
# FIGURE 4
# =============================================================================
f4raw <- read.csv(CSV_F4, stringsAsFactors = FALSE)

f4 <- data.frame(
  year   = f4raw$year,
  defor  = f4raw$deforestation_tco2eq,
  degrad = f4raw$degradation_tco2eq,
  series = f4raw$emissions_fig1_tco2eq
)

FREL_MOD <- f4raw$modified_frel_tco2eq[1]
FREL_OFF <- f4raw$official_frel_tco2eq[1]

# consistency check against the tabulated stacked total
stopifnot(all(abs((f4$defor + f4$degrad) - f4raw$total_modified_tco2eq) < 1))

# long format for the stacked bars
f4_long <- rbind(
  data.frame(year = f4$year, value = f4$defor,
             component = "Emissions from Deforestation"),
  data.frame(year = f4$year, value = f4$degrad,
             component = "Emissions from Degradation")
)
f4_long$component <- factor(
  f4_long$component,
  levels = c("Emissions from Degradation", "Emissions from Deforestation")
)

f4$total <- f4$defor + f4$degrad

# ---------------------------------------------------------------------------
# Label placement for the degradation segment.
#
# That band is crossed by three elements (official FREL, modified FREL and the
# emissions series from Figure 1), and in some years the segment is too short
# to hold the label at all. Placement is therefore resolved per bar:
#
#   1. labels listed in FORCE_OUTSIDE are placed above the bar with a leader
#      line back to the segment they refer to;
#   2. the remaining labels are centred within the widest obstacle-free stretch
#      of their segment;
#   3. if that stretch is still too narrow for the label, it also moves out.
# ---------------------------------------------------------------------------
LAB_SIZE <- 2.4     # ggplot text size (mm of cap height)
Y_MAX    <- 1200    # y-axis range, in millions
PANEL_MM <- 83      # approximate panel height for an 18 x 10 cm figure
BUFFER   <- 4       # minimum gap, in millions, between label edge and any element

# Years whose degradation label is placed outside the bar with a leader line.
# 2017 keeps its label inside: its segment has a wide obstacle-free stretch.
FORCE_OUTSIDE <- 2018:2023

units_per_mm <- Y_MAX / PANEL_MM

# Rotated labels extend along y by their string width. Mean glyph width is
# ~0.6 of the nominal size; half of that is the clearance the label needs.
half_extent <- function(lab) nchar(lab) * 0.6 * LAB_SIZE / 2 * units_per_mm

# Centre of the widest obstacle-free stretch of a segment. Centring within the
# free stretch, rather than maximising distance to obstacles, keeps the label
# visually centred instead of pushing it against the segment boundary.
centre_of_widest_gap <- function(lo, hi, obstacles) {
  cuts  <- sort(c(lo, obstacles[obstacles > lo & obstacles < hi], hi))
  width <- diff(cuts)
  k     <- which.max(width)
  list(pos = mean(cuts[k:(k + 1)]), room = width[k])
}

f4$deg_label   <- comma(round(f4$degrad / M))
f4$deg_need    <- half_extent(f4$deg_label)
f4$deg_label_y <- NA_real_
f4$deg_inside  <- !(f4$year %in% FORCE_OUTSIDE)

f4$leader_y_start <- NA_real_
f4$leader_y_end   <- NA_real_

for (i in seq_len(nrow(f4))) {
  obst <- c(FREL_OFF, FREL_MOD, f4$series[i]) / M
  need <- f4$deg_need[i]
  top  <- f4$total[i] / M
  
  if (f4$deg_inside[i]) {
    gap <- centre_of_widest_gap(f4$defor[i] / M, top, obst)
    if (gap$room < 2 * need + 2 * BUFFER) {
      f4$deg_inside[i] <- FALSE          # would not fit after all
    } else {
      f4$deg_label_y[i] <- gap$pos
    }
  }
  
  if (!f4$deg_inside[i]) {
    # Sit just above the bar, then push further up only while the label span
    # would come within BUFFER of a baseline or of the emissions series. This
    # keeps leader lines short and of comparable length across years.
    y <- top + need + 2 * BUFFER
    while (any(obst > y - need - BUFFER & obst < y + need + BUFFER)) y <- y + BUFFER
    f4$deg_label_y[i]    <- y
    f4$leader_y_start[i] <- (f4$defor[i] / M + top) / 2   # centre of the segment
    f4$leader_y_end[i]   <- y - need - BUFFER / 2
  }
}

leaders <- f4[!f4$deg_inside, ]

message("Degradation labels with leader lines: ",
        paste(f4$year[!f4$deg_inside], collapse = ", "))

fig4 <- ggplot() +
  geom_col(data = f4_long,
           aes(x = factor(year), y = value / M, fill = component),
           width = 0.65) +
  # Deforestation labels: centred in the dark blue segment (midpoints 250-425,
  # far below every horizontal line and below the emissions series).
  geom_text(data = f4,
            aes(x = factor(year), y = defor / (2 * M),
                label = comma(round(defor / M))),
            angle = 90, hjust = 0.5, vjust = 0.5, size = LAB_SIZE,
            colour = COL_ON_DARK, family = FONT) +
  # Leader lines for labels that did not fit inside their segment
  geom_segment(data = leaders,
               aes(x = factor(year), xend = factor(year),
                   y = leader_y_start, yend = leader_y_end),
               colour = COL_DEGRAD, linewidth = 0.3) +
  # Degradation labels: inside the light blue segment where they fit, otherwise
  # above the bar at the end of a leader line. Colour follows the background:
  # near-black on light blue inside, dark grey on white outside.
  geom_text(data = f4,
            aes(x = factor(year), y = deg_label_y, label = deg_label),
            colour = ifelse(f4$deg_inside, COL_ON_LIGHT, COL_TEXT),
            angle = 90, hjust = 0.5, vjust = 0.5, size = LAB_SIZE,
            family = FONT) +
  # baselines
  geom_hline(aes(yintercept = FREL_MOD / M, linetype = "Modified National FREL"),
             colour = COL_BASELINE, linewidth = 0.5) +
  geom_hline(aes(yintercept = FREL_OFF / M, linetype = "Official National FREL"),
             colour = COL_BASELINE, linewidth = 0.5) +
  annotate("text", x = 0.7, y = FREL_MOD / M, vjust = -0.6, hjust = 0,
           label = paste0(comma(round(FREL_MOD / M)), "*"),
           colour = COL_TEXT, size = 2.6, family = FONT, fontface = "bold") +
  # emissions series carried over from Figure 1
  geom_line(data = f4,
            aes(x = factor(year), y = series / M, group = 1,
                colour = "Emissions from Figure 1"), linewidth = 0.6) +
  geom_point(data = f4,
             aes(x = factor(year), y = series / M,
                 colour = "Emissions from Figure 1"), size = 1.2) +
  scale_fill_manual(values = c("Emissions from Degradation"  = COL_DEGRAD,
                               "Emissions from Deforestation" = COL_DEFOR),
                    breaks = c("Emissions from Degradation",
                               "Emissions from Deforestation")) +
  scale_linetype_manual(values = c("Modified National FREL" = "dashed",
                                   "Official National FREL" = "solid")) +
  scale_colour_manual(values = c("Emissions from Figure 1" = COL_SERIES)) +
  scale_y_continuous(labels = comma, limits = c(0, 1200),
                     breaks = seq(0, 1200, 200),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(y = expression("tons " * CO[2] * " eq (millions)")) +
  theme_fig()

ggsave("Fig4.png", fig4, width = 18, height = 10, units = "cm",
       dpi = DPI, device = ragg::agg_png)


# =============================================================================
# Colour-vision-deficiency verification
# =============================================================================
if (requireNamespace("colorBlindness", quietly = TRUE)) {
  colorBlindness::cvdPlot(fig1)
  colorBlindness::cvdPlot(fig4)
}

writeLines(capture.output(sessionInfo()), "sessionInfo_Figs1_4.txt")