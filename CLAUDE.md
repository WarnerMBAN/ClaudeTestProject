# Project: nycflights13 practice project

## Goal
Practice using Claude Code inside an RStudio project, using the nycflights13
package as the dataset. Practice only, not coursework.

## Ground rules
- Work only inside this project folder. Do not read, edit or delete anything outside it.
- Before creating or changing any file, or installing any package, describe the
  plan and wait for the user's approval.
- Explain what each script does in plain language before the user runs it.
- Flag any assumption or uncertainty instead of guessing.

## Folder layout
- data/    : saved data copies (raw data comes from the nycflights13 package)
- scripts/ : R scripts, numbered in run order (01_explore.R, 02_..., ...)
- outputs/ : tables and figures the scripts produce
- reports/ : Quarto reports

## Style guide
- Follow tidyverse conventions (https://style.tidyverse.org): snake_case names,
  the native pipe |>, two-space indents, lines of 80 characters or fewer.
- Use tidyverse packages (dplyr, tidyr, ggplot2, purrr, readr) over base R
  where they do the same job.
- Load all packages at the top of each script.
- Start each script with a header comment: purpose, inputs, outputs.
- Write a comment above each step explaining what it does and why.
- Scripts must run top to bottom in a fresh R session. Use relative paths
  (no setwd() or absolute paths).
