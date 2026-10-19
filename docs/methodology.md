# Methodology

## Why three table sizes?

The sizes 10,000, 100,000, and 500,000 rows show how query response time
changes as the database grows. A single table size could not show whether
the benefit of indexing becomes larger for larger datasets.

## Why nine tables?

Each table size has three equivalent copies: one with no index, one with
a B+ tree index, and one with a Hash index. This keeps the data structure
and query logic comparable while changing only the indexing method.

## Why 30 repetitions?

One query timing can be unusual because of caching or other computer work.
Thirty repeated timings provide a sample distribution that can be studied
using descriptive statistics, confidence intervals, and hypothesis tests.

## Primary statistical evidence

The same repeated-run block was compared across indexing methods. Therefore,
paired t-tests were treated as the main comparison test. Because response
times were positive and right-skewed, paired tests on log response times
were also calculated.

## Additional analysis

- Histograms and boxplots describe timing distributions.
- Gamma, Weibull, and Exponential fits explore the distribution shape.
- ANOVA compares method and table-size effects.
- Regression models the relationship between table size and response time.
- Chi-square analysis is exploratory because repeated measurements are not
  fully independent.

## System controls

- All methods used the same lookup-query form.
- The benchmark tables contained equivalent generated data.
- Warm-up queries were performed before timing collection.
- Method order was randomised during repeated measurements.
- The benchmark used a local PostgreSQL server on the same computer.

## Reproducibility

To repeat the project, create the PostgreSQL tables and indexes, use the
same R scripts in the documented order, and record a new timing dataset.
A new run may produce slightly different times because computer conditions
and caching can change.
