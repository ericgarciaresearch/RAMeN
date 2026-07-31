#!/usr/bin/env Rscript

#----------------------------------#
#--- summarize_rainbow_output.R ---#
#----------------------------------#

# ---- Packages and Libraries ----
# Set working directory to script location (works in RStudio only)
if (interactive()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}
#getwd()

# Load required libraries
if (!requireNamespace("tidyverse", quietly = TRUE)) {
  install.packages("tidyverse", repos = "http://cran.us.r-project.org")
}
if (!requireNamespace("tidyverse", quietly = TRUE)) install.packages("tidyverse")
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")
if (!requireNamespace("readr", quietly = TRUE)) install.packages("readr")
if (!requireNamespace("patchwork", quietly = TRUE)) install.packages("patchwork")
if (!requireNamespace("scales", quietly = TRUE)) install.packages("scales")
if (!requireNamespace("reshape2", quietly = TRUE)) install.packages("reshape2")
if (!requireNamespace("viridis", quietly = TRUE)) install.packages("viridis")


library(tidyverse)
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(patchwork)
library(scales)  # for label_comma()
library(reshape2)
library(viridis)

# ---- Global ggplot Theme ----
global_theme <- theme_minimal() +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 28, color = "black", face = "bold"),
    axis.text = element_text(size = 20, color = "black"),
    axis.title = element_text(size = 22, color = "black"),
    plot.background = element_rect(fill = "transparent", color = NA),
    panel.background = element_rect(fill = "transparent", color = NA)
  )
theme_set(global_theme)

# ---- Load Data ----

# Load the updated TSV file with raw_F, raw_R, and %_loss_ columns
zotu <- read_tsv("zotu_table.tsv")
lulu <- read_tsv("lulu_zotu_table.tsv")
blast <- read_tsv("blast_result_merged.tsv")
lca_int <- read_tsv("lca_intermediate.tsv")
lca_tax <- read_tsv("lca_taxonomy.tsv")
final <- read_tsv("zotu_table_final_curated.tsv")
reads <- read_tsv("summary-readcount_preprocess.tsv")

# Add column names to blast table
colnames(blast) <- c(
  "zotu", "seqid", "taxid", "blast_species", "common_name", "sskingdom",
  "pident", "length", "qlen", "slen", "mismatch", "gapopen", "gaps",
  "qstart", "qend", "sstart", "send", "stitle", "evalue", "bitscore",
  "qcovs", "qcovhsp"
)

# ---- Review Final Table ----

# Extract fish group with missing data, labels, etc. (NAs) into table
fish_classes <- c("Actinopteri", "Cladistia", "Actinopterygii", "Chondrichthyes", "Myxini", "Hyperoartia") # classes or sub-classes depending on classification

incomplete_taxonomies <- final %>% 
  filter(!if_all(everything(), ~ !is.na(.))) %>%   # rows containing ANY blanks/NA
  filter(class %in% fish_classes) # and any fish (sub)classes

# Save table
write.table(incomplete_taxonomies, file = "incomplete_taxonomies.tsv", sep = "\t", row.names = TRUE, quote = FALSE, na = "NA")

### Example of how to populate missing orders based on a defined family:
final$order[final$family == "Pomacentridae"] <- "Blenniiformes"
#final$order[final$family == "Polynemidae"] <- "Carangiformes"
#final$order[final$family == "Pomacanthidae"] <- "Acanthuriformes"
#final$order[final$family == "Sphyraenidae"] <- "Carangiformes"
final$order[final$family == "Centropomidae"] <- "Carangiformes"

# ---- Plot 1: Sample Plot ----

# Match final sample names to reads$sample
final_sample_names <- colnames(zotu)[-1]
reads$sample <- as.character(reads$sample)
final_match_indices <- match(final_sample_names, reads$sample)
final_reads <- reads$relabeled[final_match_indices]

# Initial reads (raw)
initial_reads <- reads$raw_F
initial_df <- data.frame(
  sample = reads$sample,
  reads = initial_reads,
  group = "Initial Samples"
)

# Final reads (raw, matched and removing NAs)
final_df <- data.frame(
  sample = final_sample_names,
  reads = final_reads,
  group = "Final Samples"
) %>% filter(!is.na(reads))

# Combine and tag for raw plot
sampleplot_df_raw <- rbind(initial_df, final_df)
sampleplot_df_raw$group <- factor(sampleplot_df_raw$group, levels = c("Initial Samples", "Final Samples"))

n_initial <- nrow(initial_df)
n_final <- nrow(final_df)

# Raw plot
p_raw <- ggplot(sampleplot_df_raw, aes(x = group, y = reads)) +
  geom_boxplot(width = 0.5, fill = "gray70", color = "gray40") +
  geom_text(data = data.frame(
    group = c("Initial Samples", "Final Samples"),
    reads = c(
      max(initial_df$reads, na.rm = TRUE),
      max(final_df$reads, na.rm = TRUE)
    ),
    label = c(n_initial,n_final)
  ),
  aes(x = group, y = reads, label = label),
  vjust = -0.5,
  size = 7
  ) +
  ylab("# Reads") +
  xlab("") +
  scale_y_continuous(labels = label_comma()) +
  ggtitle("Raw Read Counts") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


# Log10 plot
sampleplot_df_log <- sampleplot_df_raw %>%
  mutate(log_reads = log10(reads + 1))  # +1 to avoid log(0)

p_log <- ggplot(sampleplot_df_log, aes(x = group, y = log_reads)) +
  geom_boxplot(width = 0.5, fill = "gray70", color = "gray40") +
  geom_text(data = data.frame(
    group = c("Initial Samples", "Final Samples"),
    log_reads = c(
      max(log10(initial_df$reads + 1), na.rm = TRUE),
      max(log10(final_df$reads + 1), na.rm = TRUE)
    ),
    label = c(n_initial, n_final)
  ),
  aes(x = group, y = log_reads, label = label),
  vjust = -0.5,
  size = 7
  ) +
  scale_y_continuous(
    breaks = function(x) floor(min(x)):ceiling(max(x)),
    labels = function(breaks) format(10^breaks, scientific = FALSE, big.mark = ",")
  ) +
  ylab("log10(# Reads)") +
  xlab("") +
  ggtitle("Log10 Raw Read Counts") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


# Combine plots
p1 <- p_raw + p_log
p1 <- p1 & theme(plot.background = element_rect(fill = "transparent", color = NA))

ggsave("p1_reads_per_init-final_samples.png", plot = p1, width = 10, height = 12, dpi = 300, bg = "transparent")

# ---- Plot 2: Hits Plot ----

# Count hits per Zotu for both datasets
blast_counts <- as.data.frame(table(blast$zotu))
lca_int_counts <- as.data.frame(table(lca_int$zotu))

# Add a column indicating the group
blast_counts$group <- "Blast"
lca_int_counts$group <- "LCA_intermediate"

# Rename count column for consistency
colnames(blast_counts)[2] <- "hits"
colnames(lca_int_counts)[2] <- "hits"

# Combine into one data frame
hits_df <- bind_rows(blast_counts, lca_int_counts)

# Plot the boxplot
p2<- ggplot(hits_df, aes(x = group, y = hits)) +
  geom_boxplot(width = 0.5, fill = "gray70", color = "gray40") +
  ylab("# of Hits") +
  xlab("") +
  scale_y_log10(labels = scales::label_comma()) +
  theme(legend.position = "none") +
  ggtitle("Hits per zOTU") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("p2_number_of_hits.png", plot = p2, width = 10, height = 12, dpi = 300, bg = "transparent")


# ---- Plots 3-4: evalue, pident, qcov plots ----

# Create data frames for each group
blast_ev <- data.frame(evalue = blast$evalue, group = "Blast")
lca_ev   <- data.frame(evalue = lca_int$evalue, group = "LCA_intermediate")

# Combine the data
evalue_df <- bind_rows(blast_ev, lca_ev)

# Plot the boxplot
p3 <- ggplot(evalue_df, aes(x = group, y = evalue)) +
  geom_boxplot(width = 0.5, fill = "gray70", color = "gray40") +
  ylab("E-value") +
  xlab("") +
  scale_y_log10(labels = scales::label_scientific()) +
  theme(legend.position = "none") +
  ggtitle("E-value of Hits")+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("p3_eval_before_after_filters.png", plot = p3, width = 10, height = 12, dpi = 300)

# Create data frames for each metric and group
blast_pident <- data.frame(value = blast$pident, group = "Blast pident")
lca_pident   <- data.frame(value = lca_int$pident, group = "LCA_int pident")
blast_qcov   <- data.frame(value = blast$qcovs, group = "Blast qcov")
lca_qcov     <- data.frame(value = lca_int$qcov, group = "LCA_int qcov")

# Combine all into one data frame
percent_df <- bind_rows(blast_pident, lca_pident, blast_qcov, lca_qcov)

# Set factor levels to ensure correct order on x-axis
percent_df$group <- factor(percent_df$group, levels = c("Blast pident", "LCA_int pident", "Blast qcov", "LCA_int qcov"))

# Plot
p4 <-ggplot(percent_df, aes(x = group, y = value)) +
  geom_boxplot(width = 0.5, fill = "gray70", color = "gray40") +
  ylab("Percent (%)") +
  xlab("") +
  theme(legend.position = "none") +
  ggtitle("Percent Identity and Query Coverage of Hits")+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("p4_pident_qcov.png", plot = p4, width = 10, height = 12, dpi = 300)



# ---- Plot 5: Zotus plot ----

# Compute the counts
zotu_zotu_count      <- nrow(zotu)
lulu_zotu_count      <- nrow(lulu)
blast_zotu_count     <- length(unique(blast$zotu))
lca_tax_zotu_count   <- nrow(lca_tax)
final_zotu_count     <- nrow(final)

# Create a data frame with labels and counts
zotu_stats <- data.frame(
  stage = factor(c("Zotu Table", "Lulu Table", "Blast", "LCA Taxonomy", "Final Curated"),
                 levels = c("Zotu Table", "Lulu Table", "Blast", "LCA Taxonomy", "Final Curated")),
  zotu_count = c(zotu_zotu_count, lulu_zotu_count, blast_zotu_count, lca_tax_zotu_count, final_zotu_count)
)

# Create bar plot
p5 <-ggplot(zotu_stats, aes(x = stage, y = zotu_count)) +
  geom_col(width = 0.6, fill = "gray70", color = "gray40") +
  ylab("# zOTUs") +
  xlab("") +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  geom_text(aes(label = zotu_count), vjust = -0.5, size=7) +
  ggtitle("Number of zOTUs per Stage")

ggsave("p5_number_of_zotus.png", plot = p5, width = 10, height = 12, dpi = 300)


# ---- Plot 6: LCA dropped ----

# Count "LCA_dropped" in each taxonomic level including Family
lca_dropped_counts <- data.frame(
  Level = c("Domains", "Kingdoms", "Phyla", "Classes", "Orders", "Families", "Genera", "Species"),
  Number = c(
    sum(final$domain == "LCA_dropped", na.rm = TRUE),
    sum(final$kingdom == "LCA_dropped", na.rm = TRUE),
    sum(final$phylum == "LCA_dropped", na.rm = TRUE),
    sum(final$class == "LCA_dropped", na.rm = TRUE),
    sum(final$order == "LCA_dropped", na.rm = TRUE),
    sum(final$family == "LCA_dropped", na.rm = TRUE),
    sum(final$genus == "LCA_dropped", na.rm = TRUE),
    sum(final$species == "LCA_dropped", na.rm = TRUE)
  )
)

# Preserve the original order for the plot
lca_dropped_counts$Level <- factor(lca_dropped_counts$Level, levels = lca_dropped_counts$Level)

# Plot with counts on top
p6 <- ggplot(lca_dropped_counts, aes(x = Level, y = Number)) +
  geom_bar(stat = "identity", width = 0.7, fill = "gray70", color = "gray40") +
  geom_text(aes(label = Number), vjust = -0.5, size = 7) +
  ylab("Number") +
  xlab("") +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  ggtitle("Ambiguous Assigments (LCA drops) per Level")

# Save plot
ggsave("p6_number_of_lca_drops.png", plot = p6, width = 10, height = 12, dpi = 300)


# ---- Plot 7: Final taxonomic diversity plot ----

# Remove LCA_dropped species
filtered_species <- final$species[final$species != "LCA_dropped"]

# Create data frame with counts of unique values per taxonomic level
taxonomy_counts <- data.frame(
  Level = c("Domains", "Kingdoms", "Phyla", "Classes", "Orders", "Families", "Genera", "Species"),
  zotu_count = c(
    length(unique(final$domain)),
    length(unique(final$kingdom)),
    length(unique(final$phylum)),
    length(unique(final$class)),
    length(unique(final$order)),
    length(unique(final$family)),
    length(unique(final$genus)),
    length(unique(filtered_species))
  )
)

# Preserve original order for plotting
taxonomy_counts$Level <- factor(taxonomy_counts$Level, levels = taxonomy_counts$Level)

# Plot with counts on top
p7 <- ggplot(taxonomy_counts, aes(x = Level, y = zotu_count)) +
  geom_bar(stat = "identity", width = 0.7, fill = "gray70", color = "gray40") +
  geom_text(aes(label = zotu_count), vjust = -0.5, size = 7) +
  ylab("Number") +
  xlab("") +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  ggtitle("Taxonomic Diversity")

# Save the plot
ggsave("p7_final_taxonomic_diversity.png", plot = p7, width = 10, height = 12, dpi = 300)

# ---- Plot 8: Spread of Taxonomic Diversity  ----

# Helper function to count unique taxa per group while ignoring "LCA_dropped" at the child level
count_per_group <- function(data, parent_col, child_col) {
  data_filtered <- data %>%
    filter(.data[[child_col]] != "LCA_dropped") %>%
    group_by(.data[[parent_col]]) %>%
    summarise(count = n_distinct(.data[[child_col]])) %>%
    pull(count)
  return(data_filtered)
}

# Species per Genus (ignore "LCA_dropped" in species)
species_per_genus <- count_per_group(final, "genus", "species")

# Genera per Family (ignore "LCA_dropped" in genus)
genera_per_family <- count_per_group(final, "family", "genus")

# Families per Order (ignore "LCA_dropped" in family)
families_per_order <- count_per_group(final, "order", "family")

# Orders per Class (ignore "LCA_dropped" in order)
orders_per_class <- count_per_group(final, "class", "order")

# Classes per Phylum (ignore "LCA_dropped" in class)
classes_per_phylum <- count_per_group(final, "phylum", "class")

# Phyla per Kingdom (ignore "LCA_dropped" in phylum)
phyla_per_kingdom <- count_per_group(final, "kingdom", "phylum")

# Kingdoms per Domain (ignore "LCA_dropped" in kingdom)
kingdoms_per_domain <- count_per_group(final, "domain", "kingdom")

# ZOTUs per Species (ignore "LCA_dropped" in species)
zotus_per_species <- final %>%
  filter(species != "LCA_dropped") %>%
  group_by(species) %>%
  summarise(count = n()) %>%
  pull(count)

# Combine all into a single dataframe for plotting
boxplot_data <- data.frame(
  group = rep(c(
    "Kingdoms per Domain",
    "Phyla per Kingdom",
    "Classes per Phylum",
    "Orders per Class",
    "Families per Order",
    "Genera per Family",
    "Species per Genus",
    "zOTUs per Species"
  ), times = c(
    length(kingdoms_per_domain),
    length(phyla_per_kingdom),
    length(classes_per_phylum),
    length(orders_per_class),
    length(families_per_order),
    length(genera_per_family),
    length(species_per_genus),
    length(zotus_per_species)
  )),
  Number = c(
    kingdoms_per_domain,
    phyla_per_kingdom,
    classes_per_phylum,
    orders_per_class,
    families_per_order,
    genera_per_family,
    species_per_genus,
    zotus_per_species
  )
)

# Set the order of groups on the x-axis
boxplot_data$group <- factor(boxplot_data$group, levels = unique(boxplot_data$group))

# Create the boxplot
p8 <- ggplot(boxplot_data, aes(x = group, y = Number)) +
  geom_boxplot(width = 0.6, fill = "gray70", color = "gray40") +
  ylab("Number") +
  xlab("") +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none"
  ) +
  ggtitle("Spread of Diversity")

ggsave("p8_spread_taxonomic_diversity.png", plot = p8, width = 10, height = 12, dpi = 300)

# ---- Plots 9-14: Dominant Groups - Top 10s ----

# Helper function to extract top 10 most abundant taxa
get_top10_plot <- function(data, col, title) {
  top_taxa <- data %>%
    filter(.data[[col]] != "LCA_dropped", !is.na(.data[[col]])) %>%
    count(.data[[col]]) %>%
    top_n(10, n) %>%
    arrange(desc(n)) %>%
    rename(Taxon = 1, Count = n)
  
  top_taxa$Taxon <- factor(top_taxa$Taxon, levels = rev(top_taxa$Taxon))
  
  ggplot(top_taxa, aes(x = Taxon, y = Count)) +
    geom_bar(stat = "identity", width = 0.7, fill = "gray70", color = "gray40") +
    geom_text(aes(label = Count), vjust = -0.5, size = 5) +
    ylab("Number") +
    xlab("") +
    ggtitle(title) +
    theme(
      legend.position = "none",
      axis.text.x = element_text(angle = 45, hjust = 1, size=11),
      plot.title = element_text(size = 14, face = "bold")
    )
}

# Generate the four plots
p9  <- get_top10_plot(final, "species", "Top 10 Most Abundant Species")
p10 <- get_top10_plot(final, "genus",   "Top 10 Most Abundant Genera")
p11 <- get_top10_plot(final, "family",  "Top 10 Most Abundant Families")
p12 <- get_top10_plot(final, "order",   "Top 10 Most Abundant Orders")
#p12c <- get_top10_plot(final, "class",   "Top Most Abundant Classes")
#p12p <- get_top10_plot(final, "phylum",  "Top Most Abundant Phyla")

# For p13 – Top Most Abundant Classes
top_taxa_13 <- final %>%
  filter(class != "LCA_dropped", !is.na(class)) %>%
  count(class) %>%
  top_n(10, n) %>%
  arrange(desc(n)) %>%
  rename(Taxon = 1, Count = n)
top_taxa_13$Taxon <- factor(top_taxa_13$Taxon, levels = rev(top_taxa_13$Taxon))

p13 <- ggplot(top_taxa_13, aes(x = Taxon, y = Count)) +
  geom_bar(stat = "identity", width = 0.7, fill = "gray70", color = "gray40") +
  geom_text(aes(label = Count), vjust = -0.5, size = 8) +
  ylab("Number") +
  xlab("") +
  ggtitle("Top Most Abundant Classes") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1, size = 22),
    plot.title = element_text(size = 28, face = "bold")
  )

# For p14 – Top Most Abundant Phyla
top_taxa_14 <- final %>%
  filter(phylum != "LCA_dropped", !is.na(phylum)) %>%
  count(phylum) %>%
  top_n(10, n) %>%
  arrange(desc(n)) %>%
  rename(Taxon = 1, Count = n)
top_taxa_14$Taxon <- factor(top_taxa_14$Taxon, levels = rev(top_taxa_14$Taxon))

p14 <- ggplot(top_taxa_14, aes(x = Taxon, y = Count)) +
  geom_bar(stat = "identity", width = 0.7, fill = "gray70", color = "gray40") +
  geom_text(aes(label = Count), vjust = -0.5, size = 8) +
  ylab("Number") +
  xlab("") +
  ggtitle("Top Most Abundant Phyla") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1, size = 22),
    plot.title = element_text(size = 28, face = "bold")
  )

# Save each plot
ggsave("p9_top10_species.png",  plot = p9,  width = 10, height = 8, dpi = 300)
ggsave("p10_top10_genera.png",  plot = p10, width = 10, height = 8, dpi = 300)
ggsave("p11_top10_families.png",plot = p11, width = 10, height = 8, dpi = 300)
ggsave("p12_top10_orders.png",  plot = p12, width = 10, height = 8, dpi = 300)
ggsave("p13_top10_classes.png", plot = p13, width = 10, height = 8, dpi = 300)
ggsave("p14_top10_phyla.png",   plot = p14, width = 10, height = 8, dpi = 300)

# ---- Summarize Sample Results ----
#
#sample_composition <- final %>%
#  select(-unique_hits) %>%
#  mutate(taxid = as.character(taxid),
#         across(where(is.character), 
#                ~if_else(. == 'LCA_dropped', NA_character_, .))) %>%
#  group_by(across(domain:species)) %>%
#  summarise(across(where(is.numeric), sum),
#            across(c(zotu, taxid), ~unique(.) %>% str_c(collapse = '; ')),
#            .groups = 'drop') %>% 
#  mutate(lowest_level = case_when(!is.na(species) ~ str_c('s_', species),
#                                  !is.na(genus) ~ str_c('g_', genus),
#                                  !is.na(family) ~ str_c('f_', family),
#                                  !is.na(order) ~ str_c('o_', order),
#                                  !is.na(class) ~ str_c('c_', class),
#                                  !is.na(phylum) ~ str_c('p_', phylum),
#                                  !is.na(kingdom) ~ str_c('k_', kingdom),
#                                  !is.na(domain) ~ str_c('d_', domain),
#                                  TRUE ~ 'Unknown'),
#         .after = species) %>%
#  pivot_longer(cols = any_of(samples$sample_id),
#               names_to = 'sample_id',
#               values_to = 'n_reads') %>%
#  filter(n_reads > 0) 

# ---- Plot 15: Glancing the Number of Reads ----

# Select only sample columns (columns 12 to end)
sample_data <- final[, 12:ncol(final)]

# Convert to a numeric vector
read_counts <- unlist(sample_data)

# Define bins
bin_labels <- c("0", "1–10", "11–100", "101–1,000", "1,001–10,000", ">10,000")
read_bins <- cut(
  read_counts,
  breaks = c(-1, 0, 10, 100, 1000, 10000, Inf),
  labels = bin_labels,
  right = TRUE
)

# Count how many values fall in each bin
bin_counts <- as.data.frame(table(read_bins))
colnames(bin_counts) <- c("Bin", "Count")

# Create the barplot
p15 <- ggplot(bin_counts, aes(x = Bin, y = Count)) +
  geom_col(width = 0.7, fill = "gray70", color = "gray40") +
  geom_text(aes(label = Count), vjust = -0.5, size = 5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) + # Adds 15% empty space to the top 
  ylab("Frequency") +
  xlab("Read Count Bin") +
  ggtitle("Distribution of Read Counts per zOTU–Sample Observation") +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(size = 11))

#print(p15)
# Savep15# Save the plot
ggsave("p15_read_count_bins_barplot.png", plot = p15, width = 8, height = 5, dpi = 300)

# ---- Plot16: Glancing Reads Counts Groups by Species ----

# Step 1: Subset species and sample columns
df_species_sum <- final[, c(11, 12:ncol(final))]  # species and sample columns

# Step 2: Group by species and sum read counts across samples
df_species_summed <- df_species_sum %>%
  group_by(across(1)) %>%  # group by species
  summarise(across(everything(), sum, na.rm = TRUE)) %>%
  ungroup()

# Step 3: Flatten all read counts into a numeric vector
read_counts_summed <- unlist(df_species_summed[, -1])  # exclude species column

# Step 4: Bin the values
bin_labels <- c("0", "1–10", "11–100", "101–1,000", "1,001–10,000", ">10,000")
read_bins <- cut(
  read_counts_summed,
  breaks = c(-1, 0, 10, 100, 1000, 10000, Inf),
  labels = bin_labels,
  right = TRUE
)

# Step 5: Count bin frequencies
bin_counts <- as.data.frame(table(read_bins))
colnames(bin_counts) <- c("Bin", "Count")

# Step 6: Make the barplot
p16 <- ggplot(bin_counts, aes(x = Bin, y = Count)) +
  geom_col(width = 0.7, fill = "gray70", color = "gray40") +
  geom_text(aes(label = Count), vjust = -0.5, size = 5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) + # Adds 15% empty space to the top
  ylab("Frequency") +
  xlab("Read Count Bin (Summed per Species)") +
  ggtitle("Distribution of Read Counts per Species") +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(size = 11))

# Step 7: Save plot
ggsave("p16_read_count_bins_species_summed.png", plot = p16, width = 8, height = 5, dpi = 300)



# ---- Plot 17: Heat Map per species ----

# Create df_spHeat from columns 11 to the last
df_spHeat <- final %>%
  filter(species != "LCA_dropped") %>%
  select(species, 11:ncol(.))

# Sum duplicate species rows
df_spHeat_summarized <- df_spHeat %>%
  group_by(species) %>%
  summarise(across(everything(), sum, na.rm = TRUE)) %>%
  ungroup()

# Reshape to long format
df_spHeat_long <- df_spHeat_summarized %>%
  pivot_longer(cols = -species, names_to = "sample", values_to = "reads")

# Bin read counts into 5 bins + zero
df_spHeat_long <- df_spHeat_long %>%
  mutate(
    read_bin = case_when(
      reads == 0 ~ "0",
      reads > 0 & reads <= 10    ~ "1–10",
      reads > 10 & reads <= 100  ~ "11–100",
      reads > 100 & reads <= 1000 ~ "101–1,000",
      reads > 1000 & reads <= 10000 ~ "1,001–10,000",
      reads > 10000 ~ ">10,000"
    ),
    read_bin = factor(read_bin, levels = c("0", "1–10", "11–100", "101–1,000", "1,001–10,000", ">10,000"))
  )

# Define colors for bins
bin_colors <- c(
  "0" = "lightcoral",
  "1–10" = "#c6dbef",
  "11–100" = "#9ecae1",
  "101–1,000" = "#6baed6",
  "1,001–10,000" = "#3182bd",
  ">10,000" = "#08519c"
)

# Plot
p17 <- ggplot(df_spHeat_long, aes(x = sample, y = species, fill = read_bin)) +
  geom_tile(color = "white") +
  scale_fill_manual(values = bin_colors, name = "Read Count Bin") +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    axis.text.y = element_text(size = 8),
    panel.grid = element_blank()
  ) +
  labs(
    x = "Sample",
    y = "Species",
    title = "Binned Species Read Count Heatmap"
  )

#print(p15)
ggsave("p17_species_heatmap.png", plot = p17, width = 12, height = 36, dpi = 300)

# ---- Plot 18: Heat Map per Genus ----

# Create df_genHeat from genus and read count columns
df_genHeat <- final %>%
  filter(genus != "LCA_dropped") %>%
  select(genus, 12:ncol(.))  # 12 = first sample column

# Sum duplicate genus rows
df_genHeat_summarized <- df_genHeat %>%
  group_by(genus) %>%
  summarise(across(everything(), sum, na.rm = TRUE)) %>%
  ungroup()

# Reshape to long format
df_genHeat_long <- df_genHeat_summarized %>%
  pivot_longer(cols = -genus, names_to = "sample", values_to = "reads")

# Bin reads
df_genHeat_long <- df_genHeat_long %>%
  mutate(
    read_bin = case_when(
      reads == 0 ~ "0",
      reads > 0 & reads <= 10 ~ "1–10",
      reads > 10 & reads <= 100 ~ "11–100",
      reads > 100 & reads <= 1000 ~ "101–1,000",
      reads > 1000 & reads <= 10000 ~ "1,001–10,000",
      reads > 10000 ~ ">10,000"
    ),
    read_bin = factor(read_bin, levels = c("0", "1–10", "11–100", "101–1,000", "1,001–10,000", ">10,000"))
  )

# Plot
p18 <- ggplot(df_genHeat_long, aes(x = sample, y = genus, fill = read_bin)) +
  geom_tile(color = "white") +
  scale_fill_manual(values = bin_colors, name = "Read Count Bin") +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    axis.text.y = element_text(size = 8),
    panel.grid = element_blank()
  ) +
  labs(
    x = "Sample",
    y = "Genus",
    title = "Binned Genus Read Count Heatmap"
  )

#print(p18)
ggsave("p18_genus_heatmap.png", plot = p18, width = 12, height = 36, dpi = 300)

# ---- Plot: Heat Map per Family ----

# Create df_famHeat from family and read count columns
df_famHeat <- final %>%
  filter(family != "LCA_dropped") %>%
  select(family, 12:ncol(.))

# Sum duplicate family rows
df_famHeat_summarized <- df_famHeat %>%
  group_by(family) %>%
  summarise(across(everything(), sum, na.rm = TRUE)) %>%
  ungroup()

# Reshape to long format
df_famHeat_long <- df_famHeat_summarized %>%
  pivot_longer(cols = -family, names_to = "sample", values_to = "reads")

# Bin reads
df_famHeat_long <- df_famHeat_long %>%
  mutate(
    read_bin = case_when(
      reads == 0 ~ "0",
      reads > 0 & reads <= 10 ~ "1–10",
      reads > 10 & reads <= 100 ~ "11–100",
      reads > 100 & reads <= 1000 ~ "101–1,000",
      reads > 1000 & reads <= 10000 ~ "1,001–10,000",
      reads > 10000 ~ ">10,000"
    ),
    read_bin = factor(read_bin, levels = c("0", "1–10", "11–100", "101–1,000", "1,001–10,000", ">10,000"))
  )

# Plot
p19 <- ggplot(df_famHeat_long, aes(x = sample, y = family, fill = read_bin)) +
  geom_tile(color = "white") +
  scale_fill_manual(values = bin_colors, name = "Read Count Bin") +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    axis.text.y = element_text(size = 8),
    panel.grid = element_blank()
  ) +
  labs(
    x = "Sample",
    y = "Family",
    title = "Binned Family Read Count Heatmap"
  )

#print(p19)
ggsave("p19_family_heatmap.png", plot = p19, width = 12, height = 36, dpi = 300)

# ============================================================
# Display plots interactively when running in an R session.
# ============================================================

if (interactive()) {
  print(p1)
  print(p2)
  print(p3)
  print(p4)
  print(p5)
  print(p6)
  print(p7)
  print(p8)
  print(p9)
  print(p10)
  print(p11)
  print(p12)
  print(p13)
  print(p14)
  print(p15)
  print(p16)
  print(p17)
  print(p18)
  print(p19)
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

# Separately installing tinytex. Restart R once only.
install.packages("tinytex")

# 1. Manually set the path for the current R session
options(tinytex.tlmgr.path = "~/Library/TinyTeX/bin/universal-darwin/tlmgr")

# 2. Verify that R can now "see" it
tinytex::is_tinytex()

# then generate the report with:
rmarkdown::render("pipeline_metabarcoding_report.Rmd", output_format = "pdf_document")

# (or from Terminal)
# Rscript -e "rmarkdown::render('pipeline_preprocess_report.Rmd')"

