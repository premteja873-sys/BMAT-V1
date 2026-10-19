# 08_project_validation.R
# Final project-quality check.
# Does not change the database or timing data.

dir.create("results", showWarnings = FALSE)

required_files <- c(
  "00_Setup.R",
  "01_collect_timings.R",
  "02_exploratory_analysis.R",
  "03_distribution_fits.R",
  "04_hypothesis_tests.R",
  "05_final_summary.R",
  "README.md",
  ".gitignore",
  "docs/methodology.md",
  "sql/01_create_benchmark_tables.sql",
  "sql/02_verify_execution_plans.sql",
  "data/query_times.csv",
  "data/run_information.txt",
  "results/descriptive_statistics.csv",
  "results/distribution_fit_results.csv",
  "results/paired_t_test_results.csv",
  "results/one_way_anova.txt",
  "results/two_way_anova_results.txt",
  "results/regression_results.txt",
  "results/chi_square_independence.txt",
  "results/final_mean_response_times.csv",
  "results/final_speedup_summary.csv",
  "results/conclusions_for_report.txt",
  "plots/final_response_time_comparison.png"
)

file_check <- data.frame(
  file = required_files,
  exists = file.exists(required_files)
)

timings <- read.csv("data/query_times.csv", stringsAsFactors = FALSE)

expected_sizes <- c(10000, 100000, 500000)
expected_methods <- c("No index", "B+ tree", "Hash")

condition_counts <- aggregate(
  response_time_ms ~ table_size + index_method,
  data = timings,
  FUN = length
)

names(condition_counts)[3] <- "observations"

expected_conditions <- expand.grid(
  table_size = expected_sizes,
  index_method = expected_methods,
  stringsAsFactors = FALSE
)

condition_check <- merge(
  expected_conditions,
  condition_counts,
  by = c("table_size", "index_method"),
  all.x = TRUE
)

condition_check$observations[
  is.na(condition_check$observations)
] <- 0

total_observations <- nrow(timings)

positive_times <- all(
  is.finite(timings$response_time_ms) &
    timings$response_time_ms > 0
)

correct_condition_counts <- all(
  condition_check$observations == 30
)

correct_total <- total_observations == 270

all_files_present <- all(file_check$exists)

validation_lines <- c(
  "FINAL PROJECT VALIDATION",
  "========================",
  "",
  paste(
    "Required project files present:",
    ifelse(all_files_present, "PASS", "CHECK REQUIRED")
  ),
  paste(
    "Total timing observations:",
    total_observations,
    ifelse(correct_total, "(PASS: expected 270)", "(CHECK REQUIRED)")
  ),
  paste(
    "Thirty observations in every condition:",
    ifelse(
      correct_condition_counts,
      "PASS",
      "CHECK REQUIRED"
    )
  ),
  paste(
    "All recorded response times are positive finite values:",
    ifelse(positive_times, "PASS", "CHECK REQUIRED")
  ),
  "",
  "Condition counts:",
  capture.output(print(condition_check, row.names = FALSE)),
  "",
  "Required-file check:",
  capture.output(print(file_check, row.names = FALSE)),
  "",
  "Manual evidence already verified in pgAdmin:",
  "- No-index plan: Seq Scan",
  "- B+ tree plan: Index Scan using benchmark_10000_bplus_lookup_idx",
  "- Hash plan: Index Scan using benchmark_10000_hash_lookup_idx"
)

writeLines(
  validation_lines,
  "results/project_validation.txt"
)

cat("\nFinal validation finished.\n")
cat("Created: results/project_validation.txt\n")

if (
  all_files_present &&
  correct_total &&
  correct_condition_counts &&
  positive_times
) {
  cat("Project validation status: PASS\n")
} else {
  cat("Project validation status: CHECK THE FILE\n")
}
