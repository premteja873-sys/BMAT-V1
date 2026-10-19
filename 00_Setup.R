# Create the folders used by the reproducible experiment.
folders <- c("data", "plots", "results", "docs", "sql")

for (folder in folders) {
  dir.create(folder, showWarnings = FALSE)
}

cat("Project folders are ready.\n")
cat("Working directory:", getwd(), "\n")
