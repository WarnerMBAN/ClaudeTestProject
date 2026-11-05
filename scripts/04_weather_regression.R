# 04_weather_regression.R
# Purpose: Separate the associations of precipitation, visibility and wind
#          with departure delays and cancellations, holding the other weather
#          measures (and then season, time of day and airport) constant.
# Inputs:  nycflights13::flights, nycflights13::weather
# Outputs: console tables, plus
#          outputs/04_regression_delay_coefs.csv
#          outputs/04_regression_cancel_odds.csv
#          outputs/04_regression_delay.png

# Load packages ---------------------------------------------------------------
library(tidyverse)
library(nycflights13)
library(broom)      # turns model results into tidy tables
library(sandwich)   # clustered standard errors
library(lmtest)     # applies those standard errors to the model

# Step 1: Rebuild the flight + weather data (same rules as 03) ----------------
weather_clean <- weather |>
  mutate(wind_speed = if_else(wind_speed > 100, NA, wind_speed)) |>
  select(origin, time_hour, precip, visib, wind_speed) |>
  distinct(origin, time_hour, .keep_all = TRUE)

model_data <- flights |>
  left_join(weather_clean, by = c("origin", "time_hour"),
            relationship = "many-to-one") |>
  # Hour 1 has a single flight; drop it so it doesn't get its own estimate
  filter(hour >= 5) |>
  mutate(
    cancelled = is.na(dep_time),
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
    ) |>
      fct_relevel("10 mi (clear)"),   # make clear visibility the baseline
    wind_group = cut(
      wind_speed, breaks = c(-Inf, 10, 20, Inf), right = FALSE,
      labels = c("Under 10 mph", "10-20 mph", "20+ mph")
    ),
    # Treat month, hour and airport as categories, not numbers
    month  = factor(month, levels = 1:12, labels = month.abb),
    hour   = factor(hour),
    origin = factor(origin),
    # Flights at the same airport in the same hour share the same weather;
    # this ID lets the standard errors account for that
    weather_hour = paste(origin, time_hour)
  ) |>
  # Keep only flights with all three weather measures recorded
  drop_na(precip_group, visib_group, wind_group)

cat("Flights used in the cancellation model:", nrow(model_data), "\n")

# Flights that actually departed, for the delay models
departed <- model_data |>
  filter(!cancelled)

cat("Flights used in the delay models:", nrow(departed), "\n")

# Step 2: Fit the three models ------------------------------------------------
# Model 1: weather only
m1_weather <- lm(
  dep_delay ~ precip_group + visib_group + wind_group,
  data = departed
)

# Model 2: weather + season, time of day and airport
m2_controls <- lm(
  dep_delay ~ precip_group + visib_group + wind_group +
    month + hour + origin,
  data = departed
)

# Model 3: probability of cancellation (logistic regression)
m3_cancel <- glm(
  cancelled ~ precip_group + visib_group + wind_group +
    month + hour + origin,
  family = binomial,
  data   = model_data
)

# How much of the variation in delays each model explains (0 to 1)
cat("\nR-squared, Model 1 (weather only):     ",
    round(summary(m1_weather)$r.squared, 3), "\n")
cat("R-squared, Model 2 (weather + controls):",
    round(summary(m2_controls)$r.squared, 3), "\n")

# Step 3: Helpers to extract the weather results ------------------------------
# Standard errors clustered by airport-hour, then a tidy table with 95% CIs
tidy_clustered <- function(model, cluster_id) {
  coeftest(model, vcov. = vcovCL(model, cluster = cluster_id)) |>
    tidy(conf.int = TRUE)
}

# Keep only the weather terms and split them into measure + condition
weather_terms <- function(tidy_df) {
  tidy_df |>
    filter(str_detect(term, "_group")) |>
    mutate(
      measure = case_when(
        str_starts(term, "precip") ~ "Precipitation",
        str_starts(term, "visib")  ~ "Visibility",
        .default                   = "Wind speed"
      ),
      condition = str_remove(term, "^(precip|visib|wind)_group"),
      .before = 1
    ) |>
    select(measure, condition, estimate, conf.low, conf.high, p.value)
}

# Step 4: Delay results: extra minutes compared with good weather -------------
delay_coefs <- bind_rows(
  "Weather only" =
    tidy_clustered(m1_weather, departed$weather_hour) |> weather_terms(),
  "Weather + season, hour, airport" =
    tidy_clustered(m2_controls, departed$weather_hour) |> weather_terms(),
  .id = "model"
) |>
  mutate(across(c(estimate, conf.low, conf.high), \(x) round(x, 1)),
         p.value = signif(p.value, 2))

cat("\n==== Extra departure delay (minutes) vs good weather ====\n")
print(delay_coefs, n = Inf, width = Inf)

# Step 5: Cancellation results as odds ratios ---------------------------------
# An odds ratio of 3 means the odds of cancellation are 3 times higher than
# in good weather, holding everything else in the model constant.
cancel_odds <- tidy_clustered(m3_cancel, model_data$weather_hour) |>
  weather_terms() |>
  mutate(across(c(estimate, conf.low, conf.high), \(x) round(exp(x), 2)),
         p.value = signif(p.value, 2)) |>
  rename(odds_ratio = estimate)

cat("\n==== Cancellation odds ratios vs good weather ====\n")
print(cancel_odds, n = Inf, width = Inf)

# Step 6: Save the result tables ----------------------------------------------
write_csv(delay_coefs, "outputs/04_regression_delay_coefs.csv")
write_csv(cancel_odds, "outputs/04_regression_cancel_odds.csv")

# Step 7: Chart: delay estimates from Models 1 and 2 side by side -------------
# Each dot is the estimated extra delay vs good weather; the line through it
# is the 95% confidence interval. Two models, so two colours plus a legend.
delay_plot <- delay_coefs |>
  mutate(
    condition = fct_rev(fct_inorder(condition)),  # list top-to-bottom
    model = fct_inorder(model)
  ) |>
  ggplot(aes(x = estimate, y = condition, colour = model)) +
  geom_vline(xintercept = 0, colour = "#c3c2b7", linewidth = 0.4) +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high),
                  position = position_dodge(width = 0.6),
                  size = 0.4, linewidth = 0.7) +
  facet_grid(measure ~ ., scales = "free_y", space = "free_y") +
  scale_colour_manual(values = c("#2a78d6", "#eb6834")) +
  labs(
    title    = "Extra departure delay compared with good weather",
    subtitle = paste0("Minutes, with 95% confidence intervals. Good weather = ",
                      "no precipitation,\n10 mi visibility, wind under 10 mph"),
    x        = "Extra minutes of departure delay",
    y        = NULL,
    colour   = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "top",
    panel.grid.minor = element_blank(),
    plot.background  = element_rect(fill = "white", colour = NA),
    plot.title       = element_text(colour = "#0b0b0b"),
    plot.subtitle    = element_text(colour = "#52514e"),
    axis.text        = element_text(colour = "#52514e"),
    strip.text.y     = element_text(colour = "#0b0b0b", face = "bold",
                                    angle = 0, hjust = 0)
  )

ggsave("outputs/04_regression_delay.png", delay_plot,
       width = 8, height = 5.5, dpi = 150)
