# Census Data Import via API
#
# This script downloads tract-level demographic and housing data from:
# - American Community Survey (ACS) 5-year estimates
# - 2000 Decennial Census Summary File 3 (SF3)
#
# The data provides essential features for the manufactured housing classifier:
# - Housing unit counts by type (manufactured vs site-built)
# - Median household income
# - Owner-occupied housing statistics
# - Aggregate property values
#
# API Documentation: https://api.census.gov/data/2009/acs/acs5/variables.html
# Note: 2013 ACS was the first year with block group data availability

# Clean environment and load required packages
rm(list = ls())

required_packages <- c("here", "data.table", "censusapi")
for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE)) {
        stop(paste("Required package", pkg, "is not installed. Please install it with: install.packages('", pkg, "')"))
    }
}

# Verify Census API key is available
api_key <- Sys.getenv("CENSUS_KEY")
if (api_key == "") {
    stop("Census API key not found. Please set CENSUS_KEY environment variable.\nGet a key at: https://api.census.gov/data/key_signup.html")
}
cat("Using Census API key:", substr(api_key, 1, 8), "...\n")

# Create output directories
if (!dir.exists(here("derived", "acs"))) {
    dir.create(here("derived", "acs"), recursive = TRUE)
    cat("Created ACS output directory.\n")
}
if (!dir.exists(here("derived", "sf3"))) {
    dir.create(here("derived", "sf3"), recursive = TRUE)
    cat("Created SF3 output directory.\n")
}

dt_states <- fread(here("crosswalk", "states.txt"))

# API wrapper functions with error handling
# Download decennial census data (SF3)
getDec <- function(year, state, variable_codes, region = "tract") {
    tryCatch({
        df <- getCensus(
            name = "dec/sf3",
            vintage = year,
            region = paste0(region, ":*"),
            regionin = paste0("state:", state),
            vars = variable_codes
        )
        df$year <- year
        return(as.data.table(df))
    }, error = function(e) {
        stop("Error downloading Census SF3 data for state ", state, ", year ", year, ": ", e$message)
    })
}

# Download ACS 5-year estimates
getACS <- function(year, state, variable_codes, region = "tract") {
    tryCatch({
        df <- getCensus(
            name = "acs/acs5",
            vintage = year,
            region = paste0(region, ":*"),
            regionin = paste0("state:", state),
            vars = variable_codes
        )
        df$year <- year
        return(as.data.table(df))
    }, error = function(e) {
        stop("Error downloading ACS data for state ", state, ", year ", year, ": ", e$message)
    })
}

# Import ----

# SF3 variables
v_sf3 <- c(
    "H030001", # total housing units
    "H030010", # mobile homes
    "H030002", # single family detached
    "H032011", # mobile homes (owner-occupied)
    "H032003", # single family detached (owner-occupied)
    "H079007", # aggregate value of owner-occupied mobile homes
    "H079001", # aggregate value of owner-occupied housing
    "HCT012001" # median household income in 1999
)

v_names_sf3 <- c(
    "housing_units_tot",
    "mfh_tot",
    "sfd_tot",
    "oo_tot",
    "mfh_oo_tot",
    "mfh_value_tot",
    "oo_value_tot",
    "inc_hh_median"
)

# ACS variables to download (see API documentation for more details)
v_codes <- c(
    "B25024_010E", # mobiles homes
    "B25024_001E", # total housing units
    "B25024_002E", # single family detached
    "B25080_007E", # aggregate value for mobile homes
    "B25080_001E", # aggregate value for all housing
    "B25032_011E", # mobile homes (owner-occupied)
    "B25033_002E", # total housing units (owner-occupied)
    "B19013_001E" # median household income (2010 dollars)
)
v_names <- c(
    "mfh_tot",
    "housing_units_tot",
    "sfd_tot",
    "mfh_value_tot",
    "oo_value_tot",
    "mfh_oo_tot",
    "oo_tot",
    "inc_hh_median"
)

dt_states <- dt_states[statefp < 60]
dt_states[, statefp := fifelse(
    statefp < 10, paste0("0", statefp), as.character(statefp))]
v_states <- dt_states$statefp

year_acs <- c(2009, 2019)
s_region <- "tract"

# Download ACS data for each state
for (year in year_acs) {
    cat("Downloading ACS", year, "data for", length(v_states), "states...\n")

    for (state in v_states) {
        output_file <- here("derived", "acs",
            paste0("acs_", s_region, "_", year, "_", state, ".csv"))
        
        if (file.exists(output_file)) {
            cat("State", state, "already downloaded, skipping.\n")
            next
        }

        cat("Downloading ACS data for state:", state, "\n")
        dt <- getACS(year, state, v_codes, region = s_region)

        setnames(dt, v_codes, v_names)

        # impute missing values with county medians
        if (s_region == "tract") {
            dt[, (v_names) := lapply(.SD, as.numeric), .SDcols = v_names]
            dt[, (v_names) := lapply(.SD, function(x) {
                ifelse(x < 0, NA, x)
            }), .SDcols = v_names]
            dt[, (v_names) := lapply(.SD, function(x) {
                ifelse(is.na(x), median(x, na.rm = TRUE), x)
            }), .SDcols = v_names, by = .(state, county)]
        }

        # Save data with error handling
        tryCatch({
            fwrite(dt, output_file)
            cat("Saved ACS data for state", state, "to", basename(output_file), "\n")
        }, error = function(e) {
            stop("Error saving ACS data for state ", state, ": ", e$message)
        })
        
        # Rate limit API calls
        Sys.sleep(5)
    }

}

year_sf3 <- 2000

# Download SF3 data for each state
cat("Downloading SF3", year_sf3, "data for", length(v_states), "states...\n")

for (state in v_states) {
    output_file <- here("derived", "sf3",
        paste0("sf3_tract_", year_sf3, "_", state, ".csv"))
    
    if (file.exists(output_file)) {
        cat("State", state, "SF3 data already downloaded, skipping.\n")
        next
    }

    cat("Downloading SF3 data for state:", state, "\n")
    dt <- getDec(year_sf3, state, v_sf3)

    setnames(dt, v_sf3, v_names_sf3)

    # Save data with error handling
    tryCatch({
        fwrite(dt, output_file)
        cat("Saved SF3 data for state", state, "to", basename(output_file), "\n")
    }, error = function(e) {
        stop("Error saving SF3 data for state ", state, ": ", e$message)
    })
    
    # Rate limit API calls
    Sys.sleep(5)
}
