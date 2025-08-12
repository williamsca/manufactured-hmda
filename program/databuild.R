# HMDA Data Integration and Feature Engineering
#
# This script combines HMDA mortgage data with:
# - Manufactured home lender information from HUD
# - Census tract-level demographic and housing features from ACS and decennial census
# - Consumer Price Index data for inflation adjustment
# - Geographic concordances for tract harmonization across decades
#
# The result is a comprehensive dataset for training a manufactured housing classifier.
#
# Data sources:
# - HMDA: Retrieved via automated download scripts
# - Census tract concordances: IPUMS NHGIS (https://www.nhgis.org/geographic-crosswalks)
# - CPI: Bureau of Labor Statistics
#
# Note: Requires automated data retrieval scripts to populate input directories

# Clean environment and load required packages
rm(list = ls())

# Load required packages with error checking
required_packages <- c("here", "data.table", "readxl", "bit64")
for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE)) {
        stop(paste("Required package", pkg, "is not installed. Please install it with: install.packages('", pkg, "')"))
    }
}

# Verify directory structure
if (!dir.exists(here("data", "hmda"))) {
    stop("HMDA data directory not found. Please download HMDA data as per README instructions.")
}
if (!dir.exists(here("derived"))) {
    dir.create(here("derived"), recursive = TRUE)
    cat("Created derived directory for processed data.\n")
}

# Data Import ----
# Import HMDA files
l_hmda <- list.files(
    here("data", "hmda"),
    pattern = "hmda_\\d{4}\\.csv", full.names = TRUE
)
if (length(l_hmda) == 0) {
    stop("No HMDA files found. Please download HMDA data.")
}
cat("Found", length(l_hmda), "HMDA data files.\n")

# Load manufactured home lender data
lender_file <- here("derived", "manufactured_lenders.Rds")
if (!file.exists(lender_file)) {
    stop("Manufactured lenders data not found. Please run import-manufactured-lenders.R first.")
}
dt_lenders <- readRDS(lender_file)
dt_lenders <- unique(dt_lenders[, .(agency_code, respondent_id, name)])
cat("Loaded", nrow(dt_lenders), "manufactured home lenders.\n")

dt_states <- fread(here("crosswalk", "states.txt"))
dt_states <- dt_states[statefp <= 56]
dt_states[, state_code := sprintf("%02d", statefp)]

# Load CPI data for inflation adjustment
cpi_files <- list.files(here("crosswalk", "cpi"), pattern = "\\.xlsx$", full.names = TRUE)
if (length(cpi_files) == 0) {
    stop("CPI data not found. Please run data retrieval scripts to download CPI data.")
}
# Use the most recent CPI file
cpi_file <- cpi_files[length(cpi_files)]
cat("Loading CPI data from:", basename(cpi_file), "\n")
dt_cpi <- as.data.table(read_xlsx(cpi_file, skip = 11))
dt_cpi[, c("Annual", "HALF1", "HALF2") := NULL]
dt_cpi <- melt(
    dt_cpi,
    id.vars = "Year", variable.name = "Month", value.name = "Annual"
)
dt_cpi <- dt_cpi[, .(Annual = mean(Annual)), by = .(year = Year)]
dt_cpi[, Annual := Annual / Annual[year == 2010]]

# Load tract-level demographic features from ACS
acs_dir <- here("derived", "acs")
if (!dir.exists(acs_dir)) {
    stop("ACS data directory not found. Please run import-census.R first.")
}
l_acs_tr <- list.files(acs_dir, pattern = "acs_tract", full.names = TRUE)
if (length(l_acs_tr) == 0) {
    stop("No ACS tract data found. Please run import-census.R first.")
}
dt_acs_tr <- rbindlist(
    lapply(l_acs_tr, fread, keepLeadingZeros = TRUE),
    fill = TRUE, use.names = TRUE
)
cat("Loaded ACS data for", nrow(dt_acs_tr), "tract-years.\n")

# Load tract-level features from 2000 Census SF3
sf3_dir <- here("derived", "sf3")
if (!dir.exists(sf3_dir)) {
    stop("SF3 data directory not found. Please run import-census.R first.")
}
l_sf3_tr <- list.files(sf3_dir, full.names = TRUE)
if (length(l_sf3_tr) == 0) {
    stop("No SF3 tract data found. Please run import-census.R first.")
}
dt_sf3_tr <- rbindlist(
    lapply(l_sf3_tr, fread, keepLeadingZeros = TRUE),
    fill = TRUE, use.names = TRUE
)
cat("Loaded SF3 data for", nrow(dt_sf3_tr), "tract-years.\n")

dt_census <- rbind(dt_acs_tr, dt_sf3_tr, use.names = TRUE)

dt_census[nchar(tract) == 4, tract := paste0(tract, "00")]
dt_census[, countyfp := paste0(state, county)]
dt_census[, census_tract := paste0(state, county, tract)]
dt_census[, decade := ceiling(year / 10) * 10 - 10]

# Load tract concordances for harmonizing geography across decades
# These map tract boundaries to 2010 Census tract definitions
cat("Loading tract concordance files...\n")
tryCatch({
    dt_1990 <- fread(here(
        "crosswalk", "nhgis_tr1990_tr2010", "nhgis_tr1990_tr2010.csv"),
        select = c("tr1990ge", "tr2010ge", "wt_hu"),
        keepLeadingZeros = TRUE)
    dt_2000 <- fread(here(
        "crosswalk", "nhgis_tr2000_tr2010", "nhgis_tr2000_tr2010.csv"),
        select = c("tr2000ge", "tr2010ge", "wt_hu"),
        keepLeadingZeros = TRUE)
    dt_2020 <- fread(here(
        "crosswalk", "nhgis_tr2020_tr2010", "nhgis_tr2020_tr2010.csv"),
        select = c("tr2020ge", "tr2010ge", "wt_hu"),
        keepLeadingZeros = TRUE)
}, error = function(e) {
    stop("Error loading tract concordance files: ", e$message, "\nPlease ensure crosswalk files are available.")
})
setnames(dt_1990, "tr1990ge", "census_tract")
dt_1990[, decade := 1990]
setnames(dt_2000, "tr2000ge", "census_tract")
dt_2000[, decade := 2000]
setnames(dt_2020, "tr2020ge", "census_tract")
dt_2020[, decade := 2020]

dt_cw <- rbind(
    dt_1990, dt_2000, dt_2020,
    use.names = TRUE, fill = TRUE
)

# force unique mapping by largest weight
dt_cw[, max_wt_hu := max(wt_hu), by = .(census_tract, decade)]
dt_cw <- dt_cw[wt_hu == max_wt_hu & wt_hu > 0]

dt_cw[, min_target := min(tr2010ge), by = .(census_tract, decade)]
dt_cw <- dt_cw[tr2010ge == min_target]

if (nrow(dt_cw) != uniqueN(dt_cw[, .(census_tract, decade)])) {
    stop("Multiple tracts match 2010 tract")
}

dt_cw[decade == 1990 & nchar(census_tract) == 9,
    census_tract := paste0(census_tract, "00")]

if (nrow(dt_cw[nchar(census_tract) != 11]) > 0) {
    stop("Some census tracts are not 11 characters long")
}

dt_census <- merge(
    dt_census, dt_cw[decade == 2000, .(census_tract, tr2010ge)],
    by = c("census_tract"), all.x = TRUE)
dt_census[decade == 2010, tr2010ge := census_tract] # 2019 ACS
dt_census <- dt_census[!is.na(tr2010ge)] # drops about 100 unmatched tracts

dt_census[, c(
    "census_tract", "state", "county", "tract", "year", "countyfp") := NULL]

# aggregate to 2010 tracts
v_medians <- grep("median", names(dt_census), value = TRUE)
v_counts <- setdiff(
    names(dt_census), c(v_medians, "tr2010ge", "decade"))

dt_census_counts <- dt_census[,
    lapply(.SD, function(x) sum(x, na.rm = TRUE)),
    by = .(tr2010ge, decade),
    .SDcols = c(
        v_counts
    )
]
dt_census_medians <- dt_census[,
    lapply(.SD, function(x) median(x, na.rm = TRUE)),
    by = .(tr2010ge, decade),
    .SDcols = c(
        v_medians
    )
]
dt_census <- merge(
    dt_census_counts, dt_census_medians,
    by = c("tr2010ge", "decade"), all.x = TRUE
)

# county medians for observations w/o tract data
dt_census[, countyfp := substr(tr2010ge, 1, 5)]

dt_census_co_medians <- dt_census[,
    lapply(.SD, function(x) median(as.numeric(x), na.rm = TRUE)),
    by = .(countyfp, decade),
    .SDcols = c(
        v_medians, v_counts
    )
]

# merge ----
# Main data processing function
# Processes each year of HMDA data by merging with census and lender information
build_data <- function(path) {
    cat("Processing", basename(path), "\n")
    
    # Skip if output already exists
    output_file <- here("derived", basename(path))
    if (file.exists(output_file)) {
        cat("File already exists, skipping.\n")
        return(NULL)
    }
    
    # Load HMDA data with error handling
    tryCatch({
        dt <- fread(path)
    }, error = function(e) {
        stop("Error reading HMDA file ", basename(path), ": ", e$message)
    })

    data_year <- as.integer(gsub("hmda_|\\.csv", "", basename(path)))

    dt <- dt[!is.na(county_code)]

    if (data_year <= 2017) {
        if (class(dt$state_code) != "character") {
            dt[, state_code := sprintf("%02d", as.integer(state_code))]
        }
        if (class(dt$county_code) != "character") {
            dt[, county_code := sprintf("%03d", as.integer(county_code))]
        }
        if (class(dt$census_tract) != "character") {
            dt[, census_tract := sprintf("%06d", as.integer(census_tract * 100))]
        }
    } else {
        if (class(dt$census_tract) != "character") {
            dt[, census_tract := sprintf("%011s", as.character(census_tract))]
            dt[, census_tract := gsub(" ", "0", census_tract)]
        }
        dt[, state_code := substr(census_tract, 1, 2)]
        dt[, county_code := substr(census_tract, 3, 5)]
    }

    dt <- dt[state_code %in% dt_states$state_code] # remove PR

    dt[, countyfp := paste0(state_code, county_code)]

    # manufactured home lenders
    dt[, agency_code := as.integer(agency_code)]
    dt <- merge(dt, dt_lenders,
        by = c("agency_code", "respondent_id"),
        all.x = TRUE
    )

    # implied property type is 2 (manufactured) if lender is in the
    # HUD list of manufactured lenders
    dt[, property_type_imp := fifelse(!is.na(name), 2, 1)]
    dt[, name := NULL]

    # compare implied and actual property types for 2004-2005
    # result: large majority of mfh loans (4/5) are from non-specialized lenders
    # table(dt[year %in% c(2004, 2005), .(property_type, property_type_imp)])

    if (data_year <= 2017) {
        dt[, census_tract := paste0(
        state_code, county_code, gsub("\\.", "", census_tract)
    )]
        dt <- dt[nchar(census_tract) == 11 | nchar(census_tract) == 5]
    }

    if (data_year <= 2002) {
        dt <- merge(
            dt, dt_cw[decade == 1990, .(census_tract, tr2010ge)],
            by = "census_tract", all.x = TRUE)
    } else if (data_year <= 2011) {
        dt <- merge(
            dt, dt_cw[decade == 2000, .(census_tract, tr2010ge)],
            by = "census_tract", all.x = TRUE)
    } else if (data_year <= 2021) {
        dt[, tr2010ge := census_tract]
    } else if (data_year <= 2023) {
        dt <- merge(
            dt, dt_cw[decade == 2020, .(census_tract, tr2010ge)],
            by = "census_tract", all.x = TRUE)
    } else {
        stop("Data year not supported")
    }

    setnames(dt, "census_tract", "tr_original")

    cat(
        data_year, "HMDA to 2010 tract conversion rate:",
        100 * nrow(dt[!is.na(tr2010ge) & nchar(tr_original) == 11]) /
        nrow(dt[nchar(tr_original) == 11]),
        "%\n"
    )

    # Census
    dt[, decade := fcase(
        between(year, 1990, 1999), 1990, # 2000 decennial census
        between(year, 2000, 2009), 2000, # 2009 ACS
        between(year, 2010, 2023), 2010, # 2019 ACS
        default = NA_integer_
    )]
    dt <- merge(
        dt, dt_census, by = c("tr2010ge", "decade", "countyfp"), all.x = TRUE)
    cat(
        data_year, "HMDA to Census tract covariates match rate:",
        100 * nrow(dt[!is.na(inc_hh_median) & nchar(tr2010ge) == 11]) /
            nrow(dt[nchar(tr2010ge) == 11]), "%\n"
    )

    # apply county medians to unmatched tracts
    dt_co <- dt[is.na(inc_hh_median)]
    dt <- dt[!is.na(inc_hh_median)]

    v_acs <- setdiff(names(dt_census_co_medians), c("countyfp", "decade"))
    dt_co[, (v_acs) := NULL]

    dt_co <- merge(
        dt_co, dt_census_co_medians, by = c("countyfp", "decade"), all.x = TRUE)
    cat(
        data_year, "HMDA to ACS county covariates match rate:",
        100 * nrow(dt_co[!is.na(inc_hh_median)]) /
            nrow(dt_co), "%\n"
    )

    # drop any remaining unmatched observations
    dt_co <- dt_co[!is.na(inc_hh_median)]

    dt <- rbind(dt, dt_co)

    # cpi
    # deflate to 2010 dollars
    v_nom <- c("income", "loan_amount", "mfh_value_tot", "oo_value_tot")
    dt <- merge(dt, dt_cpi, by = "year", all.x = TRUE)

    dt[, (v_nom) := lapply(.SD, function(x) x / Annual), .SDcols = v_nom]

    dt$Annual <- NULL

    # feature engineering ----
    dt[, oo_value_avg := oo_value_tot / oo_tot]
    dt[, mfh_value_avg := mfh_value_tot / mfh_tot]

    dt[, mfh_value_avg := mfh_value_tot / mfh_tot]
    dt[, loan_to_income := loan_amount / income]
    dt[, loan_to_value := loan_amount / oo_value_avg]
    dt[, loan_to_mfh_value := loan_amount / mfh_value_avg]
    dt[, income_to_local := income / inc_hh_median]

    dt[, mfh_pct := mfh_tot / housing_units_tot]
    dt[, sfd_pct := sfd_tot / housing_units_tot]

    dt[, mfh_oo_pct := mfh_oo_tot / mfh_tot]

    if (data_year >= 2004) {
        dt[, is_manufactured := ifelse(property_type == 2, 1, 0)]
    }

    dt[, loan_bin := cut(
        loan_amount,
        breaks = c(0, 20000, 50000, 100000, 200000, Inf)
    )]
    dt[, lender_avg_loan := mean(loan_amount),
        by = .(respondent_id)
    ]
    dt[, lender_loan_count := .N,
        by = .(respondent_id)
    ]
    dt[, lender_avg_inc := mean(income),
        by = .(respondent_id)
    ]
    dt[, rural_loan := loan_amount * (1 - is_urban)]

    # Save processed data
    tryCatch({
        fwrite(dt, output_file)
        cat("Saved processed data to", basename(output_file), "\n")
    }, error = function(e) {
        stop("Error saving processed data: ", e$message)
    })
}

# export ----
lapply(l_hmda, build_data)

# superseded ----
# convert ACS to 2010 tracts using housing unit weights
weighted_agg <- function() {
    v_geo <- c(
        "tr2000ge", "tr2010ge", "state", "county", "tract", "wt_hu",
        "year"
    )
    v_val <- setdiff(names(dt_census), v_geo)

    dt_census[,
        (v_val) := lapply(.SD, function(x) x * wt_hu),
        .SDcols = v_val
    ]
    dt_census <- dt_census[,
        lapply(.SD, sum),
        by = .(tr2010ge, state, county, tract, year),
        .SDcols = v_val
    ]
}

tract_concordance <- function() {
    dt_1990[, max_wt_hu := max(wt_hu), by = tr1990ge]
    dt_1990 <- dt_1990[wt_hu == max_wt_hu & wt_hu > 0]

    dt_1990[, min_target := min(tr2010ge), by = tr1990ge]
    dt_1990 <- dt_1990[tr2010ge == min_target]

    if (nrow(dt_1990) != uniqueN(dt_1990$tr1990ge)) {
        stop("Multiple 1990 tracts match 2010 tract")
    }

    dt_2000[, max_wt_hu := max(wt_hu), by = tr2000ge]
    dt_2000 <- dt_2000[wt_hu == max_wt_hu & wt_hu > 0]
    dt_2000[, min_target := min(tr2010ge), by = tr2000ge]
    dt_2000 <- dt_2000[tr2010ge == min_target]

    if (nrow(dt_2000) != uniqueN(dt_2000$tr2000ge)) {
        stop("Multiple 2000 tracts match 2010 tract")
    }

}
