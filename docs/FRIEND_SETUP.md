# Setup Instructions for Another Computer

A live PostgreSQL database connection cannot be stored on GitHub. PostgreSQL
runs as a local service on each computer, and every user must use their own
local password. This repository contains the SQL, R scripts, saved real timing
data, graphs, and results needed to use or reproduce Version 1 safely.

## Option 1: View and rerun the saved analysis

This is the fastest option. PostgreSQL is not required because the repository
already contains the 270 real measurements in `data/query_times.csv`.

1. Install R and RStudio.
2. Clone or download this repository.
3. Open `DatabaseIndexingStatistics.Rproj` in RStudio.
4. Install the analysis packages once:

```r
install.packages(c(
  "dplyr",
  "ggplot2",
  "moments",
  "fitdistrplus"
))
```

5. Run the saved-data analysis in this order:

```r
source("00_Setup.R")
source("02_exploratory_analysis.R")
source("03_distribution_fits.R")
source("04_hypothesis_tests.R")
source("05_final_summary.R")
source("08_project_validation.R")
```

Do not run `01_collect_timings.R` unless a new timing experiment is intended.
The included results and graphs already come from the original real dataset.

## Option 2: Recreate the PostgreSQL database

Use this option when reproducing the complete database experiment.

1. Install PostgreSQL, pgAdmin, R, and RStudio.
2. Open pgAdmin and connect to the local PostgreSQL server.
3. Create a database named `indexing_project`.
4. Open the Query Tool for `indexing_project`.
5. Run `sql/01_create_benchmark_tables.sql`.

The SQL script recreates all nine tables:

- 10,000 rows: No index, B+ tree, and Hash
- 100,000 rows: No index, B+ tree, and Hash
- 500,000 rows: No index, B+ tree, and Hash

It also creates the B+ tree and Hash indexes and analyses the tables.

6. Run `sql/02_verify_execution_plans.sql` to check the intended scan types.
7. Install the database and analysis packages in R:

```r
install.packages(c(
  "DBI",
  "RPostgres",
  "microbenchmark",
  "rstudioapi",
  "dplyr",
  "ggplot2",
  "moments",
  "fitdistrplus"
))
```

8. Run the collection script:

```r
source("01_collect_timings.R")
```

9. Enter that computer's PostgreSQL password when RStudio asks for it. The
   password is held only for that R session and is not written to the project.
10. Run the remaining analysis scripts in numerical order.

## Expected differences on another computer

New response times will not exactly match the included results. Query timings
change with hardware, caching, PostgreSQL version, and background activity.
The experimental design remains the same: three sizes, three methods, and 30
matched searches per condition.

## Security rules

- Never write a password directly inside an R or SQL file.
- Never upload `.Renviron`, `.RData`, `.Rhistory`, or `.Rproj.user`.
- Each person should use their own local PostgreSQL credentials.
- The repository's `.gitignore` excludes common private session files.
