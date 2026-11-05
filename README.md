# NYC Flights 2013: Data, Delays and Weather

A practice project for learning to use [Claude Code](https://claude.com/claude-code)
inside an RStudio project. It explores the
[nycflights13](https://github.com/tidyverse/nycflights13) dataset — every flight
that left New York City's three main airports (JFK, LaGuardia, Newark) in 2013 —
looking at data quality, delay patterns, and how weather relates to delays and
cancellations.

This is a practice project, not coursework.

## Project structure

```
ClaudeTestProject/
├── ClaudeTestProject.Rproj    # open this in RStudio
├── CLAUDE.md                  # project rules and style guide for Claude Code
├── data/                      # (empty: data comes from the nycflights13 package)
├── scripts/
│   ├── 01_explore.R           # table sizes and missing values
│   ├── 02_delays.R            # arrival delays by airline, airport, month, hour
│   └── 03_weather_delays.R    # departure delays and cancellations by weather
├── outputs/                   # CSV tables and PNG charts from scripts 02-03
└── reports/
    ├── flights_report.qmd     # Quarto report combining all three analyses
    └── flights_report.pdf     # rendered report
```

## Requirements

- R (developed with 4.5.1)
- R packages: `tidyverse`, `nycflights13`, `knitr`, `rmarkdown`
- [Quarto](https://quarto.org) with a LaTeX distribution (e.g. TinyTeX) to
  render the PDF report

## How to run

1. Open `ClaudeTestProject.Rproj` in RStudio, so file paths work.
2. Run the scripts in order: open each one in `scripts/` and click **Source**.
   - `01_explore.R` prints to the console only.
   - `02_delays.R` and `03_weather_delays.R` also write files to `outputs/`.
3. To rebuild the report, open `reports/flights_report.qmd` and click
   **Render**, or run `quarto render reports/flights_report.qmd`.
   The report recalculates everything itself and does not use `outputs/`.

## Key findings

- **Most flights arrive early or on time.** The median arrival delay is −5
  minutes, but a minority of very late flights pull the mean up to about 7.
- **Time of day matters most.** Early-morning flights arrive early on average;
  delays build through the day and peak in the evening.
- **Delays are worst in June, July and December**, and lowest in September.
- **Precipitation has the strongest weather link** — departures in heavier rain
  or snow average about 41 minutes late versus 11 in dry weather — followed by
  low visibility, then wind.

## Caveats

- Findings are descriptive associations, not causes; weather measures overlap
  (rain often comes with low visibility and wind).
- Cancellations are inferred from a missing departure time — the data has no
  cancellation flag.
- Weather is matched at the origin airport only, at the scheduled departure hour.

## Built with Claude Code

The scripts, report and project setup were written with Claude Code, following
the rules in `CLAUDE.md`: every file change and package install was proposed
first and approved before it was made.
