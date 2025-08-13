# This script uses a light gbm model to impute the property type for
# HMDA loans in the 1990-2003 HMDA data.

rm(list = ls())
library(here)
library(data.table)
library(lightgbm)

sink("impute-mfh.log")

# import ----
v_hist <- 1990:2017
v_train <- 2004:2013

read_hmda <- function(year) {
    fread(
        here("derived", paste0("hmda_", year, ".csv")),
        keepLeadingZeros = TRUE, drop = c("oo_value_tot"))
}

dt <- rbindlist(lapply(v_hist, read_hmda), use.names = TRUE, fill = TRUE)
dt_train <- rbindlist(lapply(v_train, read_hmda), use.names = TRUE)

lgb_model <- lgb.load(here("derived", "mfh-classifier.txt"))

selected_features <- c(
    # loan characteristics
    "loan_type", "loan_amount", "loan_to_income",

    # geography
    "is_urban", "rural_loan",
    "oo_value_avg", "mfh_value_avg", "mfh_pct",
    "sfd_pct", "mfh_oo_pct",
    "tr2010ge", "countyfp", "loan_to_value",
    "loan_to_mfh_value",

    # lender characteristics
    "agency_code", "respondent_id", "purchaser_type",
    "lender_avg_loan", "lender_loan_count", "lender_avg_inc",
    "property_type_imp", "loan_bin",

    # applicant characteristics
    "income", "income_to_local", "applicant_race_1", "applicant_sex",
    "co_applicant_race_1", "co_applicant_sex"
)

numeric_features <- c(
    "loan_amount", "loan_to_income", "oo_value_avg",
    "mfh_value_avg", "sfd_pct", "mfh_oo_pct", "mfh_pct",
    "loan_to_value",
    "lender_avg_loan", "lender_loan_count", "lender_avg_inc",
    "income", "income_to_local", "rural_loan"
)

categorical_features <- setdiff(selected_features, numeric_features)

dt[, respondent_id_tmp := respondent_id]
dt[, agency_code_tmp := agency_code]

for (col in categorical_features) {
    if (!is.factor(dt_train[[col]])) {
        dt_train[[col]] <- as.factor(dt_train[[col]])
        dt[[col]] <- factor(dt[[col]], levels = levels(dt_train[[col]]))
    }

    # Convert factors to integers starting from 0 (LightGBM requirement)
    dt[[col]] <- as.integer(dt[[col]]) - 1
}

# impute missing values with state medians
dt[, (numeric_features) := lapply(.SD, function(x) {
    fifelse(is.na(x), median(x, na.rm = TRUE), x)
}), .SDcols = numeric_features, by = "state_code"]

# convert to LightGBM format
feature_names <- c(categorical_features, numeric_features)
hist_x <- as.matrix(dt[, ..feature_names])

categorical_indices <- match(
    categorical_features, feature_names
) - 1

# assess model performance on historical data
dt$is_mfh_pred <- predict(lgb_model, hist_x)

dt[, c("respondent_id", "agency_code") := NULL]

dt <- dt[, .(
    sequence_number, respondent_id = respondent_id_tmp,
    agency_code = agency_code_tmp, loan_amount, income, is_mfh_pred,
    state_code, county_code, year)]

# export ----
saveRDS(dt, here("derived", "hmda_1990_2017_imputed.Rds"))

fwrite(dt[, .(sequence_number, agency_code, respondent_id, year, is_mfh_pred)],
       here("derived", "hmda_1990_2017_imputed.csv"))

sink()


