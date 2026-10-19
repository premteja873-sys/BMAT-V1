# 05_final_summary.R
# Creates final tables, a graph, and honest conclusions
# using only the real benchmark data and test results.

library(ggplot2)

dir.create("results", showWarnings = FALSE)
dir.create("plots", showWarnings = FALSE)

# ---------- 1. Read real saved results ----------

timings <- read.csv("data/query_times.csv", stringsAsFactors = FALSE)

paired_tests <- read.csv(
  "results/paired_t_test_results.csv",
  stringsAsFactors = FALSE
)

timings$index_method <- factor(
  timings$index_method,
  levels = c("No index", "B+ tree", "Hash")
)

# ---------- 2. Mean response-time summary ----------

mean_table <- aggregate(
  response_time_ms ~ table_size + index_method,
  data = timings,
  FUN = mean
)

names(mean_table)[3] <- "mean_response_time_ms"

mean_table$mean_response_time_ms <- round(
  mean_table$mean_response_time_ms,
  3
)

write.csv(
  mean_table,
  "results/final_mean_response_times.csv",
  row.names = FALSE
)

print(mean_table)

# ---------- 3. Speed-up summary ----------

sizes <- sort(unique(timings$table_size))

speedup_results <- data.frame()

for (size_value in sizes) {

  no_index_mean <- mean_table$mean_response_time_ms[
    mean_table$table_size == size_value &
      mean_table$index_method == "No index"
  ]

  bplus_mean <- mean_table$mean_response_time_ms[
    mean_table$table_size == size_value &
      mean_table$index_method == "B+ tree"
  ]

  hash_mean <- mean_table$mean_response_time_ms[
    mean_table$table_size == size_value &
      mean_table$index_method == "Hash"
  ]

  new_row <- data.frame(
    table_size = size_value,
    no_index_mean_ms = no_index_mean,
    bplus_mean_ms = bplus_mean,
    hash_mean_ms = hash_mean,
    bplus_speedup_vs_no_index = round(no_index_mean / bplus_mean, 2),
    hash_speedup_vs_no_index = round(no_index_mean / hash_mean, 2)
  )

  speedup_results <- rbind(speedup_results, new_row)
}

write.csv(
  speedup_results,
  "results/final_speedup_summary.csv",
  row.names = FALSE
)

print(speedup_results)

# ---------- 4. Final graph for report / PPT ----------

final_plot <- ggplot(
  mean_table,
  aes(
    x = factor(table_size),
    y = mean_response_time_ms,
    fill = index_method
  )
) +
  geom_col(
    position = position_dodge(width = 0.8),
    width = 0.7
  ) +
  scale_y_log10() +
  labs(
    title = "Average Query Response Time by Indexing Method",
    subtitle = "Logarithmic y-axis; lower bars mean faster queries",
    x = "Table size (number of rows)",
    y = "Mean response time in milliseconds (log scale)",
    fill = "Method"
  ) +
  theme_minimal(base_size = 13)

ggsave(
  "plots/final_response_time_comparison.png",
  final_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ---------- 5. Create report-ready conclusions ----------

format_size <- function(x) {
  format(x, big.mark = ",", scientific = FALSE)
}

format_p <- function(x) {
  format.pval(x, digits = 4, eps = 0.0001)
}

get_test_row <- function(size_value, comparison_name) {
  paired_tests[
    paired_tests$table_size == size_value &
      paired_tests$comparison == comparison_name,
  ]
}

report_lines <- c(
  "FINAL CONCLUSIONS: DATABASE INDEXING BENCHMARK",
  "================================================",
  "",
  "Data source:",
  "These conclusions are based only on the real PostgreSQL timings",
  "recorded in data/query_times.csv.",
  "",
  "Experimental design:",
  "Three table sizes were tested: 10,000, 100,000, and 500,000 rows.",
  "Each size used three conditions: No index, B+ tree, and Hash.",
  "Thirty repeated measurements were collected for every condition.",
  ""
)

for (size_value in sizes) {

  no_index_mean <- speedup_results$no_index_mean_ms[
    speedup_results$table_size == size_value
  ]

  bplus_mean <- speedup_results$bplus_mean_ms[
    speedup_results$table_size == size_value
  ]

  hash_mean <- speedup_results$hash_mean_ms[
    speedup_results$table_size == size_value
  ]

  bplus_speedup <- speedup_results$bplus_speedup_vs_no_index[
    speedup_results$table_size == size_value
  ]

  hash_speedup <- speedup_results$hash_speedup_vs_no_index[
    speedup_results$table_size == size_value
  ]

  no_bplus <- get_test_row(
    size_value,
    "No index - B+ tree"
  )

  no_hash <- get_test_row(
    size_value,
    "No index - Hash"
  )

  bplus_hash <- get_test_row(
    size_value,
    "B+ tree - Hash"
  )

  report_lines <- c(
    report_lines,
    paste0("Table size: ", format_size(size_value), " rows"),
    paste0(
      "Mean response times: No index = ", no_index_mean,
      " ms; B+ tree = ", bplus_mean,
      " ms; Hash = ", hash_mean, " ms."
    ),
    paste0(
      "B+ tree was ", bplus_speedup,
      " times faster than no index, based on mean response time."
    ),
    paste0(
      "Hash was ", hash_speedup,
      " times faster than no index, based on mean response time."
    ),
    paste0(
      "Paired log t-test, No index versus B+ tree: p = ",
      format_p(no_bplus$paired_log_t_p_value), "."
    ),
    paste0(
      "Paired log t-test, No index versus Hash: p = ",
      format_p(no_hash$paired_log_t_p_value), "."
    ),
    paste0(
      "Paired log t-test, B+ tree versus Hash: p = ",
      format_p(bplus_hash$paired_log_t_p_value), "."
    ),
    ""
  )
}

report_lines <- c(
  report_lines,
  "Overall conclusion:",
  "The benchmark provides evidence that indexing substantially reduced",
  "equality-query response time compared with no index. The performance",
  "advantage became much larger as table size increased.",
  "",
  "B+ tree versus Hash:",
  "The paired tests should be used to decide whether their difference is",
  "statistically significant for each size. In this experiment, do not claim",
  "one is always better unless the corresponding paired-test p-value is below 0.05.",
  "",
  "Statistical caution:",
  "Raw query times were right-skewed, especially for larger unindexed tables.",
  "Therefore, log-transformed paired t-tests are the main inferential evidence.",
  "ANOVA and regression support the broad pattern, but repeated timings, caching,",
  "background programs, and measurement order can affect benchmark results.",
  "",
  "Scope:",
  "These findings apply to equality lookups on this PostgreSQL database and",
  "this computer. PostgreSQL btree is used here as the practical implementation",
  "of the B+ tree concept. Hash indexing is suitable for equality searches,",
  "not range searches."
)

writeLines(
  report_lines,
  "results/conclusions_for_report.txt"
)

cat("\nFinished successfully.\n")
cat("Created: results/final_mean_response_times.csv\n")
cat("Created: results/final_speedup_summary.csv\n")
cat("Created: results/conclusions_for_report.txt\n")
cat("Created: plots/final_response_time_comparison.png\n")