if (!requireNamespace("microbenchmark", quietly = TRUE)) {
  install.packages("microbenchmark")
}

library(DBI)
library(RPostgres)
library(microbenchmark)

dir.create("data", showWarnings = FALSE)

# Prevents names such as 1e+05.
size_name <- function(x) {
  formatC(x, format = "f", digits = 0)
}

password <- rstudioapi::askForPassword("PostgreSQL password")

conn <- dbConnect(
  RPostgres::Postgres(),
  dbname = "indexing_project",
  host = "localhost",
  port = 5432,
  user = "postgres",
  password = password
)

sizes <- c(10000, 100000, 500000)

methods <- data.frame(
  method = c("No index", "B+ tree", "Hash"),
  suffix = c("noindex", "bplus", "hash"),
  stringsAsFactors = FALSE
)

# Warm-up queries: not saved as data.
for (size in sizes) {
  formatted_size <- size_name(size)

  for (suffix in methods$suffix) {
    table_name <- paste0("benchmark_", formatted_size, "_", suffix)

    warmup_sql <- paste0(
      "SELECT score FROM ", table_name,
      " WHERE lookup_key = 17"
    )

    dbGetQuery(conn, warmup_sql)
  }
}

measure_query <- function(table_name, lookup_key) {
  sql <- paste0(
    "SELECT score FROM ", table_name,
    " WHERE lookup_key = ", lookup_key
  )

  answer <- NULL

  timing <- microbenchmark(
    answer <- dbGetQuery(conn, sql),
    times = 1L
  )

  if (nrow(answer) != 1) {
    stop("Expected exactly one row but received ", nrow(answer))
  }

  list(
    response_time_ms = as.numeric(timing$time[1]) / 1000000,
    returned_rows = nrow(answer)
  )
}

set.seed(20261019)

results <- list()
result_number <- 1L

for (size in sizes) {
  formatted_size <- size_name(size)

  # Thirty lookup values for this table size.
  lookup_keys <- sample(seq_len(size), size = 30) * 10 + 7

  for (run_number in seq_along(lookup_keys)) {

    # Random order prevents the first method always receiving a cache advantage.
    random_order <- sample(seq_len(nrow(methods)))

    for (position in seq_along(random_order)) {

      method_row <- methods[random_order[position], ]

      table_name <- paste0(
        "benchmark_",
        formatted_size,
        "_",
        method_row$suffix
      )

      measurement <- measure_query(
        table_name = table_name,
        lookup_key = lookup_keys[run_number]
      )

      results[[result_number]] <- data.frame(
        table_size = size,
        index_method = method_row$method,
        run_number = run_number,
        block_id = paste(formatted_size, run_number, sep = "_"),
        execution_order = position,
        lookup_key = lookup_keys[run_number],
        response_time_ms = measurement$response_time_ms,
        returned_rows = measurement$returned_rows
      )

      result_number <- result_number + 1L
    }
  }
}

results <- do.call(rbind, results)

write.csv(
  results,
  "data/query_times.csv",
  row.names = FALSE
)

writeLines(
  c(
    paste("Run time:", Sys.time()),
    paste("R version:", R.version.string),
    paste("PostgreSQL version:", dbGetQuery(conn, "SELECT version();")[[1]])
  ),
  "data/run_information.txt"
)

dbDisconnect(conn)
rm(password)

print(table(results$table_size, results$index_method))
print(summary(results$response_time_ms))

cat("\nFinished: data/query_times.csv has been created.\n")