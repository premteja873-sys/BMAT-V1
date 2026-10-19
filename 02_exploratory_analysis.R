library(dplyr)
library(ggplot2)
library(moments)

dir.create("plots", showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)

# Read the real timing data collected from PostgreSQL.
timings <- read.csv("data/query_times.csv")

timings$index_method <- factor(
  timings$index_method,
  levels = c("No index", "B+ tree", "Hash")
)

timings$table_size_label <- factor(
  timings$table_size,
  levels = c(10000, 100000, 500000),
  labels = c("10,000 rows", "100,000 rows", "500,000 rows")
)

# Numerical summary for every one of the nine conditions.
summary_table <- timings %>%
  group_by(table_size, index_method) %>%
  summarise(
    observations = n(),
    mean_ms = mean(response_time_ms),
    median_ms = median(response_time_ms),
    variance_ms2 = var(response_time_ms),
    standard_deviation_ms = sd(response_time_ms),
    minimum_ms = min(response_time_ms),
    maximum_ms = max(response_time_ms),
    skewness = moments::skewness(response_time_ms),
    kurtosis = moments::kurtosis(response_time_ms),
    .groups = "drop"
  )

print(summary_table)

write.csv(
  summary_table,
  "results/descriptive_statistics.csv",
  row.names = FALSE
)

# Histogram: shape of the timings in every condition.
histogram_plot <- ggplot(
  timings,
  aes(x = response_time_ms, fill = index_method)
) +
  geom_histogram(bins = 20, colour = "white") +
  facet_grid(table_size_label ~ index_method, scales = "free") +
  labs(
    title = "Distribution of Query Response Times",
    x = "Response time (milliseconds)",
    y = "Number of queries"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(
  "plots/histograms_by_condition.png",
  histogram_plot,
  width = 12,
  height = 9,
  dpi = 300
)

# Boxplot: compare medians, spread, and outliers.
boxplot_plot <- ggplot(
  timings,
  aes(x = index_method, y = response_time_ms, fill = index_method)
) +
  geom_boxplot() +
  facet_wrap(~ table_size_label, scales = "free_y") +
  labs(
    title = "Query Response Time by Indexing Method",
    x = "Indexing method",
    y = "Response time (milliseconds)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(
  "plots/boxplots_by_condition.png",
  boxplot_plot,
  width = 12,
  height = 6,
  dpi = 300
)

# Check whether running first/second/third changes the timing.
order_plot <- ggplot(
  timings,
  aes(x = factor(execution_order), y = response_time_ms)
) +
  geom_boxplot(fill = "#5B8FF9") +
  labs(
    title = "Check for Query-Order Effects",
    x = "Position within randomized block",
    y = "Response time (milliseconds)"
  ) +
  theme_minimal()

ggsave(
  "plots/query_order_effect.png",
  order_plot,
  width = 8,
  height = 5,
  dpi = 300
)

cat("\nFinished.\n")
cat("Created results/descriptive_statistics.csv\n")
cat("Created three graphs in the plots folder.\n")