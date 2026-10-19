# 04_hypothesis_tests.R
# Statistical tests, ANOVA, regression, and a growth graph
# Uses the REAL timings saved in data/query_times.csv

library(ggplot2)

# ---------- 1. Read and prepare data ----------

timings <- read.csv("data/query_times.csv", stringsAsFactors = FALSE)

dir.create("results", showWarnings = FALSE)
dir.create("plots", showWarnings = FALSE)

required_columns <- c(
  "table_size", "index_method", "response_time_ms", "block_id"
)

missing_columns <- setdiff(required_columns, names(timings))

if (length(missing_columns) > 0) {
  stop(
    paste(
      "These required columns are missing from query_times.csv:",
      paste(missing_columns, collapse = ", ")
    )
  )
}

timings$index_method <- factor(
  timings$index_method,
  levels = c("No index", "B+ tree", "Hash")
)

timings$size_factor <- factor(timings$table_size)
timings$log_time <- log(timings$response_time_ms)


# ---------- 2. Function to match measurements by block ----------

# A block means the same repetition / lookup-key situation.
# This lets us compare methods fairly within each repeated run.

get_pair_data <- function(size_value, first_method, second_method) {

  first <- timings[
    timings$table_size == size_value &
      timings$index_method == first_method,
    c("block_id", "response_time_ms")
  ]

  names(first)[2] <- "first_time"

  second <- timings[
    timings$table_size == size_value &
      timings$index_method == second_method,
    c("block_id", "response_time_ms")
  ]

  names(second)[2] <- "second_time"

  paired_data <- merge(first, second, by = "block_id")

  return(paired_data)
}


# ---------- 3. Paired t-tests, unpaired t-tests, and F-tests ----------

comparisons <- list(
  c("No index", "B+ tree"),
  c("No index", "Hash"),
  c("B+ tree", "Hash")
)

test_results <- list()
result_number <- 1

for (size_value in sort(unique(timings$table_size))) {

  for (comparison in comparisons) {

    first_method <- comparison[1]
    second_method <- comparison[2]

    paired_data <- get_pair_data(
      size_value,
      first_method,
      second_method
    )

    # F-test: compares variances.
    f_test <- var.test(
      paired_data$first_time,
      paired_data$second_time
    )

    # Unpaired Welch t-test: included for comparison only.
    unpaired_test <- t.test(
      paired_data$first_time,
      paired_data$second_time,
      paired = FALSE
    )

    # Primary test: paired t-test.
    # Appropriate because the same block_id is measured for both methods.
    paired_test <- t.test(
      paired_data$first_time,
      paired_data$second_time,
      paired = TRUE
    )

    # Log paired t-test.
    # Helpful because query-time data are positive and usually right-skewed.
    paired_log_test <- t.test(
      log(paired_data$first_time),
      log(paired_data$second_time),
      paired = TRUE
    )

    test_results[[result_number]] <- data.frame(
      table_size = size_value,
      comparison = paste(first_method, "-", second_method),
      paired_observations = nrow(paired_data),

      mean_first_method_ms = mean(paired_data$first_time),
      mean_second_method_ms = mean(paired_data$second_time),

      mean_difference_ms = mean(
        paired_data$first_time - paired_data$second_time
      ),

      raw_difference_ci_low = paired_test$conf.int[1],
      raw_difference_ci_high = paired_test$conf.int[2],
      paired_t_p_value = paired_test$p.value,

      time_ratio_first_over_second = exp(
        mean(
          log(paired_data$first_time) -
            log(paired_data$second_time)
        )
      ),

      ratio_ci_low = exp(paired_log_test$conf.int[1]),
      ratio_ci_high = exp(paired_log_test$conf.int[2]),
      paired_log_t_p_value = paired_log_test$p.value,

      f_test_p_value = f_test$p.value,
      unpaired_t_p_value = unpaired_test$p.value
    )

    result_number <- result_number + 1
  }
}

test_results <- do.call(rbind, test_results)

write.csv(
  test_results,
  "results/paired_t_test_results.csv",
  row.names = FALSE
)

print(test_results)


# ---------- 4. One-way ANOVA at each table size ----------

one_way_output <- capture.output({

  for (size_value in sort(unique(timings$table_size))) {

    cat("\n========================================\n")
    cat("ONE-WAY ANOVA: TABLE SIZE =", size_value, "\n")
    cat("========================================\n")

    size_data <- timings[timings$table_size == size_value, ]

    # Uses log times because raw response times are right-skewed.
    model <- aov(log_time ~ index_method, data = size_data)

    print(summary(model))

    cat("\nTukey multiple-comparison test:\n")
    print(TukeyHSD(model))
  }
})

writeLines(
  one_way_output,
  "results/one_way_anova.txt"
)


# ---------- 5. Two-way ANOVA ----------

# Tests:
# 1. Does indexing method affect query time?
# 2. Does table size affect query time?
# 3. Does the indexing effect change with table size?

two_way_model <- aov(
  log_time ~ index_method * size_factor,
  data = timings
)

two_way_output <- capture.output({

  cat("TWO-WAY ANOVA ON LOG RESPONSE TIME\n\n")

  print(summary(two_way_model))

  cat("\nResidual normality check (Shapiro-Wilk):\n")
  print(shapiro.test(residuals(two_way_model)))

  cat("\nImportant note:\n")
  cat(
    "ANOVA is applied to log(response time) because raw times are right-skewed.\n"
  )
  cat(
    "Repeated measurements and cache effects mean this is an experimental approximation,\n"
  )
  cat(
    "so conclusions should be supported by the paired tests as well.\n"
  )
})

writeLines(
  two_way_output,
  "results/two_way_anova_results.txt"
)


# ---------- 6. Regression ----------

# Shows how query time changes with table size
# and whether that growth differs by index method.

regression_model <- lm(
  log_time ~ log(table_size) * index_method,
  data = timings
)

regression_output <- capture.output({

  cat("REGRESSION MODEL\n")
  cat("Outcome: log(response_time_ms)\n")
  cat("Predictors: log(table_size), index method, and interaction\n\n")

  print(summary(regression_model))
})

writeLines(
  regression_output,
  "results/regression_results.txt"
)


# ---------- 7. Mean response-time growth graph ----------

mean_timings <- aggregate(
  response_time_ms ~ table_size + index_method,
  data = timings,
  FUN = mean
)

names(mean_timings)[3] <- "mean_response_time_ms"

growth_plot <- ggplot(
  mean_timings,
  aes(
    x = table_size,
    y = mean_response_time_ms,
    colour = index_method,
    group = index_method
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "Mean Query Response Time as Table Size Increases",
    subtitle = "Both axes use logarithmic scales",
    x = "Table size (rows)",
    y = "Mean response time (milliseconds)",
    colour = "Index method"
  ) +
  theme_minimal(base_size = 13)

ggsave(
  "plots/query_time_growth.png",
  growth_plot,
  width = 9,
  height = 6,
  dpi = 300
)


# ---------- 8. Chi-square test of independence ----------

# This is exploratory only.
# We split response times into four groups within each table size.
# Expected frequencies are printed so we can check the chi-square condition.

timings$time_band <- NA_integer_

for (size_value in sort(unique(timings$table_size))) {

  row_positions <- which(timings$table_size == size_value)

  timings$time_band[row_positions] <- cut(
    rank(timings$response_time_ms[row_positions], ties.method = "first"),
    breaks = 4,
    labels = FALSE
  )
}

chi_square <- chisq.test(
  table(timings$index_method, timings$time_band)
)

chi_square_output <- capture.output({

  cat("CHI-SQUARE TEST OF INDEPENDENCE\n\n")

  cat(
    "Question: Is index method associated with response-time category?\n\n"
  )

  print(chi_square)

  cat("\nExpected frequencies:\n")
  print(chi_square$expected)

  cat("\nCondition check:\n")

  if (all(chi_square$expected >= 5)) {
    cat(
      "All expected frequencies are at least 5. ",
      "The expected-frequency condition is satisfied.\n",
      sep = ""
    )
  } else {
    cat(
      "Some expected frequencies are below 5. ",
      "Interpret this chi-square test cautiously.\n",
      sep = ""
    )
  }

  cat("\nImportant limitation:\n")
  cat(
    "The timings are repeated measurements, so this chi-square result is exploratory.\n"
  )
  cat(
    "The paired t-tests are the main evidence for method comparisons.\n"
  )
})

writeLines(
  chi_square_output,
  "results/chi_square_independence.txt"
)


# ---------- 9. Finish ----------

cat("\nFinished successfully.\n")
cat("Created: results/paired_t_test_results.csv\n")
cat("Created: results/one_way_anova.txt\n")
cat("Created: results/two_way_anova_results.txt\n")
cat("Created: results/regression_results.txt\n")
cat("Created: results/chi_square_independence.txt\n")
cat("Created: plots/query_time_growth.png\n")