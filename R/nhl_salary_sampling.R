############################################################
# MATH 3430 PROJECT
# NHL Salaries: Pre-Tax and After-Tax Sampling Analysis
# Sheet: "Data Set w Income Tax"
# Methods: SRSWOR, Proportional Stratified, Neyman Stratified
#
# Set the working directory to the repository root, then
# run: source("R/nhl_salary_sampling.R", echo = TRUE)
############################################################

# ----------------------------------------------------------
# 1. LOAD PACKAGES
# ----------------------------------------------------------
library(readxl)
library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)
options(scipen = 999)

# ----------------------------------------------------------
# 2. READ DATA
# ----------------------------------------------------------
# The workbook is not distributed with this repository.
# See data/README.md for the expected layout.
data_path <- "data/nhl_salaries.xlsx"

df <- read_excel(
  data_path,
  sheet = "Data Set w Income Tax"
)
names(df)[1:6] <- c("Team", "Country", "Player", "Position",
                    "SalaryPreTax", "SalaryAfterTax")

# ----------------------------------------------------------
# 3. CLEAN DATA
# ----------------------------------------------------------
df <- df %>%
  mutate(
    Team           = trimws(as.character(Team)),
    Country        = trimws(as.character(Country)),
    Player         = trimws(as.character(Player)),
    Position       = trimws(as.character(Position)),
    SalaryPreTax   = as.numeric(SalaryPreTax),
    SalaryAfterTax = as.numeric(SalaryAfterTax)
  ) %>%
  filter(
    !is.na(Team), !is.na(Country), !is.na(Player),
    !is.na(Position), !is.na(SalaryPreTax), !is.na(SalaryAfterTax)
  ) %>%
  mutate(Position = ifelse(Position == "C", "F", Position)) %>%
  filter(
    Position %in% c("F", "D", "G"),
    Country  %in% c("C", "U")
  ) %>%
  mutate(
    Region  = ifelse(Country == "C", "Canada", "United States"),
    TaxLost = SalaryPreTax - SalaryAfterTax
  )

N <- nrow(df)   # 787
n <- 120        # total sample size

# ----------------------------------------------------------
# 4. HELPER: INTEGER ALLOCATION SUMMING TO n
#    Largest-remainder (Hamilton) method
# ----------------------------------------------------------
fix_allocation <- function(raw_alloc, Nh, n_total) {
  alloc_floor <- floor(raw_alloc)
  remainder   <- n_total - sum(alloc_floor)
  frac_part   <- raw_alloc - alloc_floor
  alloc       <- alloc_floor

  if (remainder > 0) {
    add_order <- order(frac_part, decreasing = TRUE)
    i <- 1
    while (remainder > 0 && i <= length(add_order)) {
      idx <- add_order[i]
      if (alloc[idx] < Nh[idx]) {
        alloc[idx] <- alloc[idx] + 1
        remainder  <- remainder - 1
      }
      i <- i + 1
      if (i > length(add_order) && remainder > 0) i <- 1
    }
  }
  if (remainder < 0) {
    sub_order <- order(frac_part, decreasing = FALSE)
    i <- 1
    while (remainder < 0 && i <= length(sub_order)) {
      idx <- sub_order[i]
      if (alloc[idx] > 1) {
        alloc[idx] <- alloc[idx] - 1
        remainder  <- remainder + 1
      }
      i <- i + 1
      if (i > length(sub_order) && remainder < 0) i <- 1
    }
  }
  return(alloc)
}

# ----------------------------------------------------------
# 5. SRSWOR SAMPLE (shared for both salary variables)
# ----------------------------------------------------------
set.seed(123)
srs_sample <- df %>% slice_sample(n = n, replace = FALSE)

# ----------------------------------------------------------
# 6. PROPORTIONAL ALLOCATION BY POSITION
# ----------------------------------------------------------
prop_info <- df %>%
  group_by(Position) %>%
  summarise(Nh = n(), .groups = "drop") %>%
  arrange(Position) %>%
  mutate(
    Wh       = Nh / N,
    nh_raw   = n * Nh / N,
    nh_alloc = fix_allocation(nh_raw, Nh, n)
  )
# Result: D=41, F=68, G=11

set.seed(123)
prop_sample_list <- list()
for (i in 1:nrow(prop_info)) {
  h_position <- prop_info$Position[i]
  h_n        <- prop_info$nh_alloc[i]
  prop_sample_list[[i]] <- df %>%
    filter(Position == h_position) %>%
    slice_sample(n = h_n, replace = FALSE)
}
prop_sample <- bind_rows(prop_sample_list)

# ----------------------------------------------------------
# 7. NEYMAN ALLOCATION AND SAMPLING FUNCTION
# ----------------------------------------------------------
draw_neyman_sample <- function(data_full, salary_var,
                               total_n, seed = 123) {
  N_total <- nrow(data_full)
  neyman_info <- data_full %>%
    group_by(Position) %>%
    summarise(
      Nh = n(),
      Sh = sd(.data[[salary_var]]),
      .groups = "drop"
    ) %>%
    arrange(Position) %>%
    mutate(
      Wh       = Nh / N_total,
      NhSh     = Nh * Sh,
      nh_raw   = total_n * NhSh / sum(NhSh),
      nh_alloc = fix_allocation(nh_raw, Nh, total_n)
    )
  set.seed(seed)
  neyman_sample_list <- list()
  for (i in 1:nrow(neyman_info)) {
    h_position <- neyman_info$Position[i]
    h_n        <- neyman_info$nh_alloc[i]
    neyman_sample_list[[i]] <- data_full %>%
      filter(Position == h_position) %>%
      slice_sample(n = h_n, replace = FALSE)
  }
  neyman_sample <- bind_rows(neyman_sample_list)
  list(neyman_info = neyman_info, neyman_sample = neyman_sample)
}

# ----------------------------------------------------------
# 8. STRATIFIED ESTIMATOR FUNCTION
# ----------------------------------------------------------
compute_stratified_results <- function(data_full, strat_data,
                                       strata_pop, salary_var) {
  N_total <- nrow(data_full)
  sample_stats <- strat_data %>%
    group_by(Position) %>%
    summarise(
      nh_sample = n(),
      ybar_h    = mean(.data[[salary_var]]),
      s2_h      = var(.data[[salary_var]]),
      .groups   = "drop"
    ) %>%
    arrange(Position)

  stratum_stats <- left_join(strata_pop, sample_stats,
                             by = "Position") %>%
    mutate(
      fh            = nh_sample / Nh,
      Wh_ybarh      = Wh * ybar_h,
      var_component = Wh^2 * (1 - fh) * s2_h / nh_sample
    )

  ybar_st     <- sum(stratum_stats$Wh_ybarh)
  var_ybar_st <- sum(stratum_stats$var_component)
  se_ybar_st  <- sqrt(var_ybar_st)
  t_hat_st    <- N_total * ybar_st
  se_t_st     <- N_total * se_ybar_st

  list(
    ybar_st       = ybar_st,
    var_ybar_st   = var_ybar_st,
    se_ybar_st    = se_ybar_st,
    ci_lower      = ybar_st - 1.96 * se_ybar_st,
    ci_upper      = ybar_st + 1.96 * se_ybar_st,
    t_hat_st      = t_hat_st,
    se_t_st       = se_t_st,
    stratum_stats = stratum_stats
  )
}

# ----------------------------------------------------------
# 9. PRE-TAX SALARY ANALYSIS
# ----------------------------------------------------------
# SRSWOR
ybar_srs_pre <- mean(srs_sample$SalaryPreTax)
s2_srs_pre   <- var(srs_sample$SalaryPreTax)
var_srs_pre  <- (1 - n / N) * s2_srs_pre / n
se_srs_pre   <- sqrt(var_srs_pre)
# Results: mean=4170330, SE=251076, CI=(3678222, 4662439)

# Proportional
prop_pre <- compute_stratified_results(df, prop_sample,
              prop_info, "SalaryPreTax")
# Results: mean=3362231, SE=233777, CI=(2904028, 3820434)

# Neyman
ney_draw_pre <- draw_neyman_sample(df, "SalaryPreTax", n)
neyman_pre   <- compute_stratified_results(
                  df, ney_draw_pre$neyman_sample,
                  ney_draw_pre$neyman_info, "SalaryPreTax")
# Results: mean=3349263, SE=231276, CI=(2895962, 3802563)

# Relative efficiency
RE_prop_pre   <- var_srs_pre / prop_pre$var_ybar_st   # 1.1535
RE_neyman_pre <- var_srs_pre / neyman_pre$var_ybar_st # 1.1786

# ----------------------------------------------------------
# 10. AFTER-TAX SALARY ANALYSIS
# ----------------------------------------------------------
# SRSWOR
ybar_srs_after <- mean(srs_sample$SalaryAfterTax)
s2_srs_after   <- var(srs_sample$SalaryAfterTax)
var_srs_after  <- (1 - n / N) * s2_srs_after / n
se_srs_after   <- sqrt(var_srs_after)
# Results: mean=1899015, SE=118662, CI=(1666438, 2131592)

# Proportional
prop_after <- compute_stratified_results(df, prop_sample,
               prop_info, "SalaryAfterTax")
# Results: mean=1540873, SE=111886, CI=(1321575, 1760170)

# Neyman
ney_draw_after <- draw_neyman_sample(df, "SalaryAfterTax", n)
neyman_after   <- compute_stratified_results(
                    df, ney_draw_after$neyman_sample,
                    ney_draw_after$neyman_info, "SalaryAfterTax")
# Results: mean=1535275, SE=110892, CI=(1317927, 1752623)

# Relative efficiency
RE_prop_after   <- var_srs_after / prop_after$var_ybar_st   # 1.1248
RE_neyman_after <- var_srs_after / neyman_after$var_ybar_st # 1.1450

# ----------------------------------------------------------
# 11. POPULATION COMPARISON: PRE-TAX VS AFTER-TAX
# ----------------------------------------------------------
comparison_by_position_region <- df %>%
  group_by(Position, Region) %>%
  summarise(
    Count        = n(),
    MeanPreTax   = mean(SalaryPreTax),
    MeanAfterTax = mean(SalaryAfterTax),
    MeanTaxLost  = mean(TaxLost),
    .groups      = "drop"
  )

# ----------------------------------------------------------
# 12. SELECTED VISUALISATIONS
# ----------------------------------------------------------

# Distribution of pre-tax salaries
ggplot(df, aes(x = SalaryPreTax)) +
  geom_histogram(bins = 30, fill = "grey40", color = "black") +
  scale_x_continuous(labels = comma) +
  labs(title = "Distribution of Pre-Tax Salaries",
       x = "Pre-Tax Salary", y = "Frequency")

# Mean salary by position: pre-tax vs after-tax
mean_long <- bind_rows(
  df %>% group_by(Position) %>%
    summarise(MeanSalary = mean(SalaryPreTax), .groups = "drop") %>%
    mutate(Type = "Pre-Tax"),
  df %>% group_by(Position) %>%
    summarise(MeanSalary = mean(SalaryAfterTax), .groups = "drop") %>%
    mutate(Type = "After-Tax")
)
ggplot(mean_long, aes(x = Position, y = MeanSalary, fill = Type)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("Pre-Tax" = "#1f5cb6", "After-Tax" = "grey50")) +
  scale_y_continuous(labels = comma) +
  labs(title = "Mean Salary by Position: Pre-Tax vs After-Tax",
       x = "Position", y = "Mean Salary", fill = "Salary Type")

# SE comparison across methods
se_df <- data.frame(
  Method = rep(c("SRSWOR", "Proportional", "Neyman"), 2),
  SE = c(se_srs_pre,   prop_pre$se_ybar_st,   neyman_pre$se_ybar_st,
         se_srs_after, prop_after$se_ybar_st, neyman_after$se_ybar_st),
  Type = rep(c("Pre-Tax", "After-Tax"), each = 3)
)
ggplot(se_df, aes(x = Method, y = SE, fill = Type)) +
  geom_col(position = "dodge") +
  labs(title = "Comparison of Standard Errors by Sampling Method",
       x = "Method", y = "SE of Estimated Mean", fill = "Salary Type")
