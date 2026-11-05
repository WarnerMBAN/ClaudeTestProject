# 03_weather_delays.R
# Purpose: Explore how weather at the NYC origin airport relates to
#          cancellations and departure delays.
# Inputs:  nycflights13::flights, nycflights13::weather
# Outputs: console summaries, plus
#          outputs/03_weather_delay_summary.csv
#          outputs/03_weather_delay.png

# Load packages ---------------------------------------------------------------
library(tidyverse)
library(nycflights13)

# Step 1: Clean the weather table ---------------------------------------------
# Wind speeds above 100 mph are treated as recording errors and set to NA.
n_bad_wind <- sum(weather$wind_speed > 100, na.rm = TRUE)
cat("Implausible wind speeds set to NA:", n_bad_wind, "\n")

# Keep only the columns we need. If an airport has more than one reading for
# the same hour (possible around daylight-saving changes), keep the first one.
weather_clean <- weather |>
  mutate(wind_speed = if_else(wind_speed > 100, NA, wind_speed)) |>
  select(origin, time_hour, precip, visib, wind_speed)

n_dupes <- nrow(weather_clean) -
  nrow(distinct(weather_clean, origin, time_hour))
cat("Duplicate airport-hour weather readings removed:", n_dupes, "\n")

weather_clean <- weather_clean |>
  distinct(origin, time_hour, .keep_all = TRUE)

# Step 2: Match each flight to the weather at departure -----------------------
# time_hour in flights is the SCHEDULED departure hour, so this is the
# weather when the flight was due to leave, at its origin airport only.
flights_weather <- flights |>
  left_join(weather_clean, by = c("origin", "time_hour"),
            relationship = "many-to-one")

n_unmatched <- sum(is.na(flights_weather$visib))
cat("Flights with no matching weather reading:", n_unmatched, "\n")

# Step 3: Put each weather measure into readable groups -----------------------
# right = FALSE means each group includes its lower edge, e.g. "1-3 mi" is
# 1 up to (but not including) 3.
flights_binned <- flights_weather |>
  mutate(
    precip_group = case_when(
      is.na(precip)  ~ NA,
      precip == 0    ~ "None",
      precip <= 0.1  ~ "Light (up to 0.10 in)",
      .default       = "Heavier (over 0.10 in)"
    ) |>
      factor(levels = c("None", "Light (up to 0.10 in)",
                        "Heavier (over 0.10 in)")),
    visib_group = cut(
      visib, breaks = c(-Inf, 1, 3, 10, Inf), right = FALSE,
      labels = c("Under 1 mi", "1-3 mi", "3-10 mi", "10 mi (clear)")
    ),
    wind_group = cut(
      wind_speed, breaks = c(-Inf, 10, 20, Inf), right = FALSE,
      labels = c("Under 10 mph", "10-20 mph", "20+ mph")
    )
  )

# Step 4: A reusable summary function -----------------------------------------
# For one weather grouping: count flights, the share cancelled (no dep_time),
# and departure-delay statistics for flights that did leave.
summarise_by_weather <- function(data, group_col, variable_name) {
  data |>
    filter(!is.na({{ group_col }})) |>
    group_by(level = {{ group_col }}) |>
    summarise(
      n_flights        = n(),
      pct_cancelled    = mean(is.na(dep_time)) * 100,
      mean_dep_delay   = mean(dep_delay, na.rm = TRUE),
      median_dep_delay = median(dep_delay, na.rm = TRUE),
      pct_late_15      = mean(dep_delay > 15, na.rm = TRUE) * 100,
      .groups = "drop"
    ) |>
    mutate(variable = variable_name, level = as.character(level),
           .before = 1) |>
    mutate(across(where(is.double), \(x) round(x, 1)))
}

# Step 5: Summarise each weather measure and combine --------------------------
weather_summary <- bind_rows(
  summarise_by_weather(flights_binned, precip_group, "Precipitation"),
  summarise_by_weather(flights_binned, visib_group,  "Visibility"),
  summarise_by_weather(flights_binned, wind_group,   "Wind speed")
)

cat("\n==== Departure delays and cancellations by weather ====\n")
print(weather_summary, n = Inf, width = Inf)

# Step 6: Save the summary table ----------------------------------------------
write_csv(weather_summary, "outputs/03_weather_delay_summary.csv")

# Step 7: Chart: mean departure delay for each weather group ------------------
# One panel per weather measure; all panels share the same y-axis so bar
# heights are directly comparable. One colour, since bars are not series.
plot_data <- weather_summary |>
  mutate(level = fct_inorder(level))   # keep groups in their logical order

weather_plot <- ggplot(plot_data, aes(x = level, y = mean_dep_delay)) +
  geom_col(fill = "#2a78d6", width = 0.6) +
  geom_hline(yintercept = 0, colour = "#c3c2b7", linewidth = 0.4) +
  facet_wrap(~ variable, scales = "free_x") +
  labs(
    title    = "Mean departure delay by weather at the origin airport",
    subtitle = "NYC departures, 2013; weather at the scheduled departure hour",
    x        = NULL,
    y        = "Mean departure delay (minutes)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.background    = element_rect(fill = "#fcfcfb", colour = NA),
    plot.title         = element_text(colour = "#0b0b0b"),
    plot.subtitle      = element_text(colour = "#52514e"),
    axis.text          = element_text(colour = "#52514e"),
    axis.text.x        = element_text(angle = 30, hjust = 1),
    strip.text         = element_text(colour = "#0b0b0b", face = "bold")
  )

ggsave("outputs/03_weather_delay.png", weather_plot,
       width = 10, height = 5, dpi = 150)
