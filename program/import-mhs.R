# This script downloads data from the Census Mobile Home Survey

rm(list = ls())
library(here)
library(data.table)
library(readxl)

# Import ----
file_link <- "https://www2.census.gov/programs-surveys/mhs/tables/time-series/place_hist.xlsx"

if (!file.exists(here("data", "place_hist.xlsx"))) {
    download.file(file_link, here("data", "place_hist.xlsx"), mode = "wb")
}

dt <- as.data.table(read_xlsx(
        here("data", "place_hist.xlsx"),
        skip = 2, col_names = FALSE))

v_types <- c("tot", "single", "double")
v_years <- seq(2013, 1980, -1)

v_names <- as.vector(outer(v_years, v_types, paste, sep = "_"))
v_names <- v_names[order(v_names, decreasing = TRUE)]
v_names <- c("region", "state_name", v_names)

setnames(dt, v_names)

# Clean ----
v_divisions <- c(
    "New England", "Middle Atlantic", "East North Central",
    "West North Central", "South Atlantic", "East South Central",
    "West South Central", "Mountain", "Pacific"
)
dt <- dt[
    !is.na(state_name) & !(state_name %in% v_divisions) & !is.na(`2013_tot`)
]
dt$region <- NULL

dt <- melt(
    dt,
    id.vars = "state_name", variable.name = "year_type",
    value.name = "value"
)

dt[, value := 1000 * as.integer(value)]

dt[, c("year", "type") := tstrsplit(year_type, "_", fixed = TRUE)]

dt <- dcast(dt, state_name + year ~ type, value.var = "value")
setnames(dt, v_types, paste0("place", "_", v_types))

dt[, year := as.integer(year)]

# Export ----
saveRDS(dt, here("derived", "mhs.Rds"))
