#!/usr/bin/env Rscript

# ============================================================
# Setup
# Install and load required packages for data processing and plotting.
# ============================================================

if (interactive()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

if (!requireNamespace("tidyverse", quietly = TRUE)) {
  install.packages("tidyverse", repos = "http://cran.us.r-project.org")
}

library(tidyverse)

# ============================================================
# Global plot theme
# Apply a consistent theme across all figures.
# ============================================================

theme_set(
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(size = 14),
      legend.position = "none"
    )
)

# ============================================================
# Load read count preprocessing summary data.
# ============================================================

readcount <- read_tsv("summary-readcount_preprocess.tsv")

# ============================================================
# Compute mean raw reads and reshape dataset to long format.
# ============================================================

readcount <- readcount %>%
  mutate(raw = rowMeans(select(., raw_F, raw_R))) %>%
  select(sample, raw, trim_merge, ngsfilter, l_filtered, relabeled)

readcount_long <- readcount %>%
  pivot_longer(-sample, names_to = "stage", values_to = "reads")

readcount_long$stage <- factor(
  readcount_long$stage,
  levels = c("raw","trim_merge","ngsfilter","l_filtered","relabeled")
)

# ============================================================
# Plot 1: Total reads retained at each preprocessing stage.
# ============================================================

stage_totals <- readcount_long %>%
  group_by(stage) %>%
  summarise(total_reads = sum(reads, na.rm = TRUE)) %>%
  arrange(stage)

pre1 <- ggplot(stage_totals, aes(stage, total_reads, fill = stage)) +
  geom_col() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Total Reads per Preprocessing Stage",
    x = "Stage",
    y = "Total Reads"
  )

ggsave("pre1_barplot_preprocess_read_summary.png", pre1, width = 6, height = 4, dpi = 300)

# ============================================================
# Plot 2: Distribution of read counts across samples by stage.
# ============================================================

pre2 <- ggplot(readcount_long, aes(stage, reads, fill = stage)) +
  geom_boxplot(outlier.size = 0.5) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Distribution of Read Counts by Preprocessing Stage",
    x = "Preprocessing Stage",
    y = "Read Count"
  )

ggsave("pre2_boxplot_preprocess_read_summary.png", pre2, width = 6, height = 4, dpi = 300)

# ============================================================
# Calculate absolute read loss between preprocessing stages.
# ============================================================

readcount_loss_abs <- readcount %>%
  mutate(
    loss_trim_merge = raw - trim_merge,
    loss_ngsfilter = trim_merge - ngsfilter,
    loss_l_filtered = ngsfilter - l_filtered,
    loss_relabeled = l_filtered - relabeled
  ) %>%
  pivot_longer(starts_with("loss_"),
               names_to = "stage",
               values_to = "read_loss") %>%
  mutate(stage = factor(str_remove(stage,"loss_"),
                        levels=c("trim_merge","ngsfilter","l_filtered","relabeled")))

stage_loss_totals <- readcount_loss_abs %>%
  group_by(stage) %>%
  summarise(total_read_loss = sum(read_loss, na.rm = TRUE))

# ============================================================
# Plot 3: Total reads lost at each preprocessing stage.
# ============================================================

pre3 <- ggplot(stage_loss_totals, aes(stage,total_read_loss,fill=stage)) +
  geom_col() +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Total Read Loss per Preprocessing Stage",
    x = "Stage",
    y = "Total Read Loss"
  )

ggsave("pre3_total_read_loss_per_stage.png", pre3, width = 6, height = 4, dpi = 300)

# ============================================================
# Plot 4: Percent of total reads lost at each stage.
# ============================================================

total_raw_reads <- sum(readcount$raw, na.rm = TRUE)

stage_loss_percent <- stage_loss_totals %>%
  mutate(percent_total_loss = total_read_loss / total_raw_reads * 100)

pre4 <- ggplot(stage_loss_percent,
               aes(stage, percent_total_loss, fill = stage)) +
  geom_col() +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(
    title = "Percent Total Read Loss per Preprocessing Stage",
    x = "Stage",
    y = "Percent of Total Reads Lost"
  )

ggsave("pre4_percent_total_read_loss_per_stage.png", pre4, width = 6, height = 4, dpi = 300)

# ============================================================
# Plot 7: Reads per sample with mean read count per stage.
# ============================================================

mean_reads <- readcount_long %>%
  group_by(stage) %>%
  summarise(mean_reads = mean(reads, na.rm = TRUE),
            label = scales::comma(round(mean_reads)))

pre7 <- ggplot(readcount_long, aes(sample, reads)) +
  geom_col(fill = "#2c7fb8") +
  geom_hline(data = mean_reads,
             aes(yintercept = mean_reads),
             linetype="dashed",
             color="red",
             linewidth=0.6,
             inherit.aes = FALSE) +
  geom_label(data = mean_reads,
             aes(x = 1, y = mean_reads, label = label),
             hjust=0,
             size=4,
             label.size=0.25,
             fill="white",
             color="red",
             inherit.aes=FALSE) +
  facet_wrap(~stage, ncol = 1, scales="free_y") +
  labs(
    title = "Read Counts per Sample by Preprocessing Stage",
    x = "Sample",
    y = "Read Count"
  ) +
  theme(axis.text.x = element_text(angle = 90, size = 6),
        strip.text = element_text(size = 11))

ggsave("pre7_reads_per_sample.png", pre7, width = 10, height = 12, dpi = 300)

# ============================================================
# Plot 8: Percent read loss per sample relative to previous step.
# ============================================================

readcount_loss_long <- read_tsv("summary-readcount_preprocess.tsv") %>%
  select(sample, starts_with("%_loss_")) %>%
  pivot_longer(-sample,
               names_to="stage",
               values_to="percent_loss") %>%
  mutate(stage = factor(str_remove(stage,"%_loss_"),
                        levels=c("trim_merge","ngsfilter","l_filtered","relabeled")))

mean_loss <- readcount_loss_long %>%
  group_by(stage) %>%
  summarise(mean_loss = mean(percent_loss, na.rm = TRUE),
            label = paste0(round(mean_loss,1),"%"))

pre8 <- ggplot(readcount_loss_long, aes(sample, percent_loss)) +
  geom_col(fill="#d95f02") +
  geom_hline(data=mean_loss,
             aes(yintercept=mean_loss),
             linetype="dashed",
             color="red",
             linewidth=0.6,
             inherit.aes=FALSE) +
  geom_label(data=mean_loss,
             aes(x=1,y=mean_loss,label=label),
             hjust=0,
             size=4,
             label.size=0.25,
             fill="white",
             color="red",
             inherit.aes=FALSE) +
  facet_wrap(~stage, ncol=1, scales="free_y") +
  labs(
    title="Read Loss per Sample by Preprocessing Stage",
    x="Sample",
    y="Percent Read Loss"
  ) +
  theme(axis.text.x = element_text(angle = 90, size = 6),
        strip.text = element_text(size = 11))

ggsave("pre8_read_loss_per_sample.png", pre8, width = 10, height = 12, dpi = 300)

# ============================================================
# Load read length summary data for preprocessing steps.
# ============================================================

readL_step <- read_tsv("summary-readL_preprocess.tsv")

ave_readL <- readL_step %>%
  group_by(step) %>%
  summarise(ave_read_l = round(mean(length, na.rm = TRUE),0))

step_levels <- c("raw","trim_merge","ngsfilter","length_filtered","relabeled","merged")

ave_readL$step <- factor(ave_readL$step, levels = step_levels)
readL_step$step <- factor(readL_step$step, levels = step_levels)

# ============================================================
# Plot 5: Average read length across preprocessing steps.
# ============================================================

pre5 <- ggplot(ave_readL, aes(step, ave_read_l, fill = step)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = ave_read_l), vjust = -0.5, size = 3.5) +
  labs(
    title = "Average Read Length Across Preprocessing Steps",
    x = "Preprocessing Step",
    y = "Average Read Length (bp)"
  ) +
  ylim(0, max(ave_readL$ave_read_l) * 1.1)

ggsave("pre5_average_read_length_barplot.png", pre5, width = 6, height = 4, dpi = 300)

# Plot 9: Read length distribution across preprocessing steps.
# ============================================================

summary_readL_step <- readL_step %>%
  group_by(step) %>%
  summarise(mean_length = mean(length))

pre9 <- ggplot(readL_step, aes(length)) +
  geom_histogram(binwidth = 5, fill="#2c7fb8", alpha=0.7) +
  facet_wrap(~step, ncol=1, scales="free_y") +
  geom_vline(data = summary_readL_step,
             aes(xintercept = mean_length),
             color="red",
             linetype="dashed",
             linewidth=0.8) +
  labs(
    title="Read Length Distributions and Mean Length per Preprocessing Step",
    x="Read Length (bp)",
    y="Count"
  ) +
  theme(strip.text = element_text(size = 11))

ggsave("pre9_read_length_distribution_per_step.png", pre9, width = 10, height = 12, dpi = 300)

# ============================================================
# Plot 6: Read alignment summary for trim_merge.
# ============================================================

readalign <- read_tsv("summary-readalign_trim_merge.tsv", show_col_types = FALSE)

total_val <- readalign %>% filter(read_type == "total") %>% pull(number)
components <- readalign %>% filter(read_type != "total")

rounded_total <- round(total_val)

components <- components %>%
  mutate(
    floor_val = floor(number),
    remainder = number - floor_val
  )

current_sum <- sum(components$floor_val)
difference <- rounded_total - current_sum

if (difference > 0) {
  components <- components %>%
    arrange(desc(remainder)) %>%
    mutate(
      floor_val = ifelse(row_number() <= difference,
                         floor_val + 1,
                         floor_val)
    )
}

components <- components %>%
  select(read_type, number = floor_val)

custom_levels <- c(
  "unaligned",
  "aligned_full-L_collapsed",
  "aligned_trunc_collapsed",
  "aligned_not-collapsed"
)

components$read_type <- factor(components$read_type, levels = custom_levels)

components <- components %>%
  arrange(read_type) %>%
  mutate(percent = round(number / rounded_total * 100, 1))

legend_labels <- setNames(
  paste0(custom_levels, " (", components$percent, "%)"),
  custom_levels
)

pre6 <- ggplot(components, aes(x = 1, y = number, fill = read_type)) +
  geom_bar(stat="identity", width=1, color="white") +
  coord_polar(theta="y") +
  xlim(0.5,1.5) +
  ylim(0,rounded_total) +
  theme_void() +
  ggtitle("Read Alignment in trim_merge") +
  annotate("text",
           x=1,
           y=rounded_total/2,
           label=paste0("Total Reads\n",format(rounded_total,big.mark=",")),
           size=5) +
  scale_fill_discrete(labels = legend_labels) +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    legend.text = element_text(size = 12),
    legend.key.size = unit(1,"cm"),
    legend.title = element_blank()
  )

ggsave("pre6_read_alignment.png", pre6, width = 6, height = 4, dpi = 300)

# ============================================================
# Display plots interactively when running in an R session.
# ============================================================

if (interactive()) {
  print(pre1)
  print(pre2)
  print(pre3)
  print(pre4)
  print(pre5)
  print(pre6)
  print(pre7)
  print(pre8)
  print(pre9)
}

# ============================================================
# Generate PDF report using R Markdown
# ============================================================

# Install packages as needed
packages <- c("kableExtra", "rmarkdown", "knitr")
installed <- rownames(installed.packages())
to_install <- setdiff(packages, installed)

if (length(to_install) > 0) {
  install.packages(to_install)
}

# Separately installing tinytex
install.packages("tinytex")

# 1. Manually set the path for the current R session
options(tinytex.tlmgr.path = "~/Library/TinyTeX/bin/universal-darwin/tlmgr")

# 2. Verify that R can now "see" it
tinytex::is_tinytex()

# then generate the report with:
rmarkdown::render("pipeline_preprocess_report.Rmd", output_format = "pdf_document")

# (or from Terminal)
# Rscript -e "rmarkdown::render('pipeline_preprocess_report.Rmd')"
