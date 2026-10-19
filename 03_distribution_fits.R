library(dplyr)
library(ggplot2)
library(fitdistrplus)

timings <- read.csv("data/query_times.csv")

dir.create("plots", showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)

size_name <- function(x) formatC(x, format = "f", digits = 0)

# Fits one distribution and performs a chi-square goodness-of-fit check.
fit_one_distribution <- function(x, distribution_name) {

  fit <- fitdist(x, distribution_name)
  parameters <- fit$estimate
  number_of_parameters <- length(parameters)

  quantile_function <- switch(
    distribution_name,
    "exp" = qexp,
    "gamma" = qgamma,
    "weibull" = qweibull
  )

  # Five fitted-distribution bins: expected frequency is 30/5 = 6 per bin.
  probabilities <- c(0.2, 0.4, 0.6, 0.8)

  cut_points <- do.call(
    quantile_function,
    c(list(p = probabilities), as.list(parameters))
  )

  observed <- hist(
    x,
    breaks = c(-Inf, cut_points, Inf),
    plot = FALSE
  )$counts

  expected <- rep(length(x) / 5, 5)

  chi_square <- sum((observed - expected)^2 / expected)
  degrees_freedom <- 5 - 1 - number_of_parameters
  p_value <- pchisq(chi_square, df = degrees_freedom, lower.tail = FALSE)

  list(
    fit = fit,
    parameters = parameters,
    chi_square = chi_square,
    degrees_freedom = degrees_freedom,
    p_value = p_value
  )
}

all_results <- list()
all_qq_data <- list()

result_number <- 1
qq_number <- 1

for (table_size in sort(unique(timings$table_size))) {
  for (method in unique(timings$index_method)) {

    x <- timings %>%
      filter(table_size == !!table_size, index_method == !!method) %>%
      pull(response_time_ms)

    for (distribution_name in c("exp", "gamma", "weibull")) {

      fitted <- fit_one_distribution(x, distribution_name)

      all_results[[result_number]] <- data.frame(
        table_size = table_size,
        index_method = method,
        distribution = distribution_name,
        AIC = fitted$fit$aic,
        BIC = fitted$fit$bic,
        chi_square = fitted$chi_square,
        degrees_freedom = fitted$degrees_freedom,
        chi_square_p_value = fitted$p_value
      )

      quantile_function <- switch(
        distribution_name,
        "exp" = qexp,
        "gamma" = qgamma,
        "weibull" = qweibull
      )

      theoretical <- do.call(
        quantile_function,
        c(
          list(p = ppoints(length(x))),
          as.list(fitted$parameters)
        )
      )

      all_qq_data[[qq_number]] <- data.frame(
        table_size = size_name(table_size),
        index_method = method,
        distribution = distribution_name,
        theoretical_quantile = theoretical,
        sample_quantile = sort(x)
      )

      result_number <- result_number + 1
      qq_number <- qq_number + 1
    }
  }
}

distribution_results <- do.call(rbind, all_results)
qq_data <- do.call(rbind, all_qq_data)

write.csv(
  distribution_results,
  "results/distribution_fit_results.csv",
  row.names = FALSE
)

print(distribution_results)

for (distribution_name in c("exp", "gamma", "weibull")) {

  qq_plot <- qq_data %>%
    filter(distribution == distribution_name) %>%
    ggplot(
      aes(
        x = theoretical_quantile,
        y = sample_quantile
      )
    ) +
    geom_point(colour = "#276FBF") +
    geom_abline(
      intercept = 0,
      slope = 1,
      colour = "red",
      linetype = "dashed"
    ) +
    facet_grid(table_size ~ index_method, scales = "free") +
    labs(
      title = paste(
        "Q-Q Plots:",
        distribution_name,
        "Distribution"
      ),
      x = "Theoretical quantiles",
      y = "Observed query-time quantiles"
    ) +
    theme_minimal()

  ggsave(
    paste0("plots/qq_", distribution_name, ".png"),
    qq_plot,
    width = 12,
    height = 9,
    dpi = 300
  )
}

cat("\nFinished.\n")
cat("Created results/distribution_fit_results.csv\n")
cat("Created three Q-Q plot images in the plots folder.\n")