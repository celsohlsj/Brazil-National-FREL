# ============================================================
# Brazil National FREL — Figure 1 Generator
#
# Reads:  data/fig1_data.csv
# Writes: figures/fig1_emissions_overview.svg
#
# Run from repository root:
#   Rscript codes/generate_fig1_svg.R
#
# The SVG is also regenerated automatically by GitHub Actions
# whenever data/fig1_data.csv is pushed (.github/workflows/update_fig1.yml).
#
# To add a new year: append a row to data/fig1_data.csv with the
# appropriate type ("Official" or "Estimated") and push.
# ============================================================

if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(ggplot2, svglite, dplyr, readr, scales)

# ── Load data ─────────────────────────────────────────────────
data <- read_csv("data/fig1_data.csv", show_col_types = FALSE) %>%
  mutate(type = factor(type, levels = c("Official", "Estimated")))

frel_mt      <- data$frel_Mt[1]
frel_rounded <- round(frel_mt)

# ── Dynamic y-axis (scales to the series max so no bar is ever clipped) ──
y_max        <- max(data$emission_Mt, na.rm = TRUE)
y_upper      <- ceiling(y_max * 1.08 / 100) * 100
label_offset <- y_upper * 0.0224

# ── Palettes ──────────────────────────────────────────────────
# Okabe-Ito colour-blind-safe palette, matching manuscript Figure 1
fill_pal  <- c("Official" = "#0072B2", "Estimated" = "#E69F00")
label_pal <- c("Official" = "#FFFFFF", "Estimated" = "#1A1A1A")

# ── Footnote ──────────────────────────────────────────────────
caption_text <- paste0(
  "* Official National FREL = ",
  format(round(frel_mt * 1e6), big.mark = ",", scientific = FALSE),
  " t CO\u2082eq yr\u207b\u00b9 (average 2017\u20132021, submitted to UNFCCC)"
)

# ── Plot ──────────────────────────────────────────────────────
p <- ggplot(data, aes(x = factor(year), y = emission_Mt, fill = type)) +

  geom_col(width = 0.70) +

  geom_text(
    aes(label = round(emission_Mt), color = type),
    angle    = 90,
    size     = 3.8,
    position = position_stack(vjust = 0.5)
  ) +

  # FREL reference line (shown in legend via linetype aesthetic)
  geom_hline(
    data      = data.frame(y = frel_mt, lab = "Official National FREL"),
    aes(yintercept = y, linetype = lab),
    color     = "#000000",
    linewidth = 0.75
  ) +

  # "674*" annotation above the FREL line
  annotate(
    "text",
    x        = 0.6,
    y        = frel_mt + label_offset,
    label    = paste0(frel_rounded, "*"),
    hjust    = 0,
    size     = 3.8,
    fontface = "bold",
    color    = "#1a1a1a"
  ) +

  scale_fill_manual(name = NULL, values = fill_pal) +
  scale_color_manual(name = NULL, values = label_pal, guide = "none") +
  scale_linetype_manual(name = NULL, values = c("Official National FREL" = "solid")) +

  scale_y_continuous(
    name   = "Millions of t CO\u2082eq",
    limits = c(0, y_upper),
    breaks = pretty_breaks(n = 6),
    labels = comma,
    expand = c(0, 0)
  ) +
  scale_x_discrete(name = NULL) +

  labs(caption = caption_text) +

  guides(
    fill     = guide_legend(order = 1),
    linetype = guide_legend(order = 2)
  ) +

  theme_minimal(base_size = 13) +
  theme(
    legend.position    = "right",
    legend.text        = element_text(size = 11),
    legend.key.width   = unit(1.2, "cm"),
    legend.key.height  = unit(0.7, "cm"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_line(color = "#ececec", linewidth = 0.5),
    axis.line.x.bottom = element_line(color = "#bbbbbb", linewidth = 0.5),
    axis.text          = element_text(color = "#333333", size = 11),
    axis.title.y       = element_text(size = 11, color = "#555555"),
    plot.caption       = element_text(size = 9, color = "#777777",
                                      hjust = 0, margin = margin(t = 8))
  )

# ── Export ────────────────────────────────────────────────────
dir.create("figures", showWarnings = FALSE)
svglite("figures/fig1_emissions_overview.svg", width = 9.5, height = 5.5)
print(p)
dev.off()

cat("SVG written to: figures/fig1_emissions_overview.svg\n")
