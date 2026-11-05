# 01_explore.R
# Purpose: First look at the five nycflights13 tables.
#          For each table, print the number of rows, the number of columns,
#          and the count of missing (NA) values in each column.
# Inputs:  nycflights13 package (no files read)
# Outputs: printed to the console only (no files written)

# Load packages ---------------------------------------------------------------
library(tidyverse)
library(nycflights13)

# Gather the five tables into a named list so we can treat them the same way
tables <- list(
  airlines = airlines,
  airports = airports,
  flights  = flights,
  planes   = planes,
  weather  = weather
)

# Summarise each table ----------------------------------------------------------
# For each table: print its size, then count NAs in every column
iwalk(tables, \(tbl, name) {
  cat("\n==== ", name, " ====\n", sep = "")
  cat("Rows:   ", nrow(tbl), "\n")
  cat("Columns:", ncol(tbl), "\n")

  # summarise(across(...)) counts NAs per column; pivot_longer turns the
  # one-row result into a two-column table (column name, NA count)
  missing <- tbl |>
    summarise(across(everything(), \(x) sum(is.na(x)))) |>
    pivot_longer(everything(), names_to = "column", values_to = "n_missing")

  print(missing, n = Inf)
})
