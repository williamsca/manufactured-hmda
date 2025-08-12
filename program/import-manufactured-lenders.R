# This script imports HUD's list of lenders who specialize in manufactured housing loans.
# https://archives.huduser.gov/portal/datasets/manu.html

rm(list = ls())
library(here)
library(data.table)
library(readxl)

file_link <- "https://archives.huduser.gov/portal/datasets/manu/subprime_2006_distributed.xls"

if (!file.exists(here("data", "subprime_2006_distributed.xls"))) {
    download.file(file_link, here("data", "subprime_2006_distributed.xls"), mode = "wb")
}

# import ----
v_years <- 1993:2003

read_year <- function(year) {
    s_year <- as.character(year)
    data <- as.data.table(read_xls(
        here("data", "subprime_2006_distributed.xls"), sheet = s_year, skip = 2))

    data <- data[MH == 2] # 1 = subprime, 2 = manufactured housing
    data$MH <- NULL

    data$year <- year
    return(data)
}

dt <- rbindlist(lapply(v_years, read_year))

dt[, last_year := max(year), by = ID]
dt_last <- dt[year == last_year, .(ID, name = tolower(NAME))]

dt <- merge(dt, dt_last, by = "ID", all.x = TRUE)
dt <- dt[, .(
    respondent_id = ID, IDD, agency_code = as.integer(CODE), name, year)]

# sanity checks ----
if (uniqueN(dt[, .(respondent_id, year)]) != nrow(dt)) {
    stop("Duplicate ID/year combinations in manufactured lenders data.")
}

# NB: There are duplicate name/year combinations in manufactured lenders data.

# export ----
if (!dir.exists(here("derived"))) {
    cat("Creating derived directory...\n")
    dir.create(here("derived"), recursive = TRUE)
}

saveRDS(dt, here("derived", "manufactured_lenders.Rds"))


