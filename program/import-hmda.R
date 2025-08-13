# This script imports Home Mortgage Disclosure Act data
# and filters to home purchase loans for owner-occupied units.
# It also drops many columns to reduce the size of the data on disk.

# NB: The HMDA data do not explicitly designate manufactured housing until 2004.

# Downloaded from
# (2007-2017)
# https://www.consumerfinance.gov/data-research/hmda/historic-data/
# and (1990-2006)
# https://doi.org/10.3886/E151921V1

rm(list = ls())
library(here)
library(data.table)

# Import ----
# filter to reduce size on disk
v_keep <- c(
    "sequence_number",

    "year",

    # loan characteristics
    "loan_type", "loan_amount",

    # geography
    "state_code", "county_code", "census_tract", "is_urban",

    # lender characteristics
    "agency_code", "respondent_id", "purchaser_type",

    # applicant characteristics
    "income", "applicant_race_1", "applicant_sex",
    "co_applicant_race_1", "co_applicant_sex"
)

# 1990 - 2006
read_hmda_old <- function(year) {

    input_file <- here("data", "hmda", paste0("HMDA_LAR_", year, ".zip"))

    if (!file.exists(input_file)) {
        stop("HMDA file for year ", year,
        " not found. Refer to README.md for download instructions.\n")
        return(NULL)
    }

    data <- fread(cmd = sprintf("unzip -p %s", input_file))

    if (uniqueN(data[, .(sequence_number, respondent_id, agency_code)]) != nrow(data)) {
        stop("Duplicate records found in HMDA data for year ", year)
    }

    setnames(data,
        c("occupancy_type", "activity_year"),
        c("owner_occupancy", "as_of_year"),
        skip_absent = TRUE)
    setnames(data, "occupancy", "owner_occupancy", skip_absent = TRUE)
    setnames(data, "as_of_year", "year")

    data <- data[
        loan_purpose == 1 & # home purchases
        action_taken == 1 & # loan originated
        owner_occupancy == 1 & # owner-occupied
        !is.na(income) & income != "" & # not missing income
        !is.na(loan_amount) & loan_amount != "" & # not missing loan amount
        !is.na(state_code) & state_code != "" # not missing state
    ]

    data[, is_urban := !is.na(msamd)]
    data[, income := as.integer(income)]
    data[, loan_amount := as.integer(loan_amount)]

    if (year >= 2004) {
        v_keep <- c(v_keep, "property_type") # mfh indicator
    }

    data <- data[, ..v_keep]
    
    # Save processed data with error handling
    output_file <- here("data", "hmda", paste0("hmda_", year, ".csv"))
    tryCatch({
        fwrite(data, output_file)
        cat("Saved processed HMDA data for", year, "to", basename(output_file), "\n")
    }, error = function(e) {
        stop("Error saving HMDA data for ", year, ": ", e$message)
    })
}

# 2007-2017: CFPB format
read_hmda <- function(year) {
    cat("Processing HMDA data for year", year, "\n")
    
    # Load raw data with error handling
    input_file <- here("data", "hmda", paste0(
            "hmda_", year,
            "_nationwide_originated-records_codes.zip"))
    if (!file.exists(input_file)) {
        stop("Raw HMDA file not found: ", basename(input_file),
        "\nRefer to README.md for download instructions.")
    }
    
    tryCatch({
        data <- fread(cmd = sprintf("unzip -p %s", input_file))
    }, error = function(e) {
        stop("Error reading HMDA file for ", year, ": ", e$message)
    })

    if (any(data$action_taken != 1)) {
        stop("Unexpected action taken code in 2007-2017 HMDA data.")
    }

    # 2017 data is missing the sequence number
    if (year < 2017 & uniqueN(data[, .(sequence_number, respondent_id, agency_code)]) != nrow(data)) {
        stop("Duplicate records found in HMDA data for year ", year)
    }    

    # home purchases
    data <- data[
        loan_purpose == 1 & # home purchases
        !is.na(applicant_income_000s) &
        applicant_income_000s != "" &
        !is.na(loan_amount_000s) & loan_amount_000s != "" &
        !is.na(state_code) & state_code != "" &
        owner_occupancy == 1 # owner-occupied
    ]
    data[, is_urban := !is.na(msamd)]

    setnames(
        data,
        c(
            "as_of_year", "loan_amount_000s", "census_tract_number",
            "applicant_income_000s"
        ),
        c("year", "loan_amount", "census_tract", "income")
    )

    v_keep <- c(v_keep, "property_type")

    data <- data[, ..v_keep]
    
    output_file <- here("data", "hmda", paste0("hmda_", year, ".csv"))

    tryCatch({
        fwrite(data, output_file)
        cat("Saved processed HMDA data for", year, "to", basename(output_file), "\n")
    }, error = function(e) {
        stop("Error saving HMDA data for ", year, ": ", e$message)
    })
}

# Process all years in each time period
cat("Processing historical HMDA data (1990-2006)...\n")
lapply(1990:2006, read_hmda_old)

cat("Processing CFPB-era HMDA data (2007-2017)...\n")
lapply(2007:2017, read_hmda)

cat("HMDA data processing complete.\n")
