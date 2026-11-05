# 02_delays.R
# Purpose: Describe arrival delays in nycflights13: overall, and broken down
#          by airline, origin airport, month and scheduled departure hour.
# Inputs:  nycflights13::flights, nycflights13::airlines
# Outputs: console summaries, plus
#          outputs/02_delays_by_carrier.csv
#          outputs/02_delay_by_hour.png

# Load packages ---------------------------------------------------------------
library(tidyverse)
library(nycflights13)

# Step 1: Label each flight's status ------------------------------------------
# Assumption: no dep_time = cancelled; departed but no arr_delay = diverted or
# incomplete record. Both are excluded from the delay summaries below.
flight_status <- flights |>
  mutate(status = case_when(
    is.na(dep_time)  ~ "cancelled",
    is.na(arr_delay) ~ "no arrival data",
    .default         = "completed"
  ))

# Show how many flights fall in each group, and what share of the total
flight_status |>
  count(status) |>
  mutate(pct = round(n / sum(n) * 100, 1)) |>
  print()

# Keep only completed flights for the delay analysis
completed <- flight_status |>
  filter(status == "completed")

# Step 2: A reusable summary function -----------------------------------------
# Groups the data by whatever columns are passed in (or none), then computes
# the same delay statistics for every group, rounded to 1 decimal place.
# "Late" = arrived more than 15 minutes after schedule (the FAA's definition).
summarise_delays <- function(data, ...) {
  data |>
    group_by(...) |>
    summarise(
      n_flights        = n(),
      mean_arr_delay   = mean(arr_delay),
      median_arr_delay = median(arr_delay),
      pct_late_15      = mean(arr_delay > 15) * 100,
      .groups = "drop"
    ) |>
    mutate(across(where(is.double), \(x) round(x, 1)))
}

# Step 3: Overall delay picture -----------------------------------------------
cat("\n==== All completed flights ====\n")
summarise_delays(completed) |> print()

# Step 4: By airline (with full airline names), worst average delay first -----
by_carrier <- summarise_delays(completed, carrier) |>
  left_join(airlines, by = "carrier") |>
  relocate(name, .after = carrier) |>
  arrange(desc(mean_arr_delay))

cat("\n==== By airline ====\n")
print(by_carrier, n = Inf)

# Step 5: By origin airport ---------------------------------------------------
cat("\n==== By origin airport ====\n")
summarise_delays(completed, origin) |> print()

# Step 6: By month ------------------------------------------------------------
cat("\n==== By month ====\n")
summarise_delays(completed, month) |> print(n = Inf)

# Step 7: By scheduled departure hour -----------------------------------------
# Hours with fewer than 100 flights are dropped so one or two unusual flights
# don't distort the picture.
by_hour <- summarise_delays(completed, hour) |>
  filter(n_flights >= 100)

cat("\n==== By scheduled departure hour ====\n")
print(by_hour, n = Inf)

# Step 8: Save the airline table ----------------------------------------------
write_csv(by_carrier, "outputs/02_delays_by_carrier.csv")

# Step 9: Plot average delay by hour and save it ------------------------------
# One series, so one colour and no legend; the title names what's shown.
# A light reference line at 0 separates "early on average" from "late".
delay_plot <- ggplot(by_hour, aes(x = hour, y = mean_arr_delay)) +
  geom_hline(yintercept = 0, colour = "#c3c2b7", linewidth = 0.4) +
  geom_line(colour = "#2a78d6", linewidth = 0.8) +
  geom_point(colour = "#2a78d6", size = 2.5) +
  scale_x_continuous(breaks = seq(5, 23, by = 2)) +
  labs(
    title    = "Average arrival delay by scheduled departure hour",
    subtitle = "Flights departing NYC in 2013, completed flights only",
    x        = "Scheduled departure hour (24-hour clock)",
    y        = "Mean arrival delay (minutes)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.background  = element_rect(fill = "#fcfcfb", colour = NA),
    plot.title       = element_text(colour = "#0b0b0b"),
    plot.subtitle    = element_text(colour = "#52514e"),
    axis.text        = element_text(colour = "#52514e")
  )

ggsave("outputs/02_delay_by_hour.png", delay_plot,
       width = 8, height = 5, dpi = 150)
