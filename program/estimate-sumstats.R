# This script estimates summary statistics for manufactured vs site-built homes
# using HMDA data from 2004-2013.

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)

# import ----
if (!file.exists(here("results", "tables", "sum-stats.csv"))) {
    v_train <- 2004:2013

    read_hmda <- function(year) {
        fread(
            here("derived", paste0("hmda_", year, ".csv")), keepLeadingZeros = TRUE,
            drop = c("oo_value_tot"))
    }

    dt_train <- rbindlist(lapply(v_train, read_hmda), use.names = TRUE)

    v_hmda <- c("oo_value_avg")
    dt_train[, (v_hmda) := lapply(.SD, function(x) x / 1000), .SDcols = v_hmda]

    v_pct <- c("is_urban", "mfh_pct", "mfh_oo_pct")
    dt_train[, (v_pct) := lapply(.SD, function(x) x * 100), .SDcols = v_pct]

    # calculate summary statistics ----
    features <- c("loan_amount", "income", "is_urban", "mfh_pct",
                "loan_to_income")
    v_names <- c(
        "Loan Amount ($1000s)", "Income ($1000s)",
        "Urban Area (%)", "Mobile Home Share of All Housing (%)",
        "Loan-to-Income Ratio" # , "Owner-Occupied Share of Mobile Homes (%)"
    )
    setnames(dt_train, features, v_names)

    dt_train <- melt(dt_train, id.vars = "is_manufactured", measure.vars = v_names)
    dt_sum <- dt_train[, .(
        mean = mean(value, na.rm = TRUE),
        sd = sd(value, na.rm = TRUE),
        n = sum(!is.na(value))
    ), by = .(is_manufactured, variable)]

    dt_sum <- dcast(
        dt_sum, variable ~ is_manufactured, value.var = c("mean", "sd", "n"))

    # create formatted table ----
    dt_sum[, site_built := paste0(
        sprintf("%.1f", mean_0), " (", sprintf("%.1f", sd_0), ")")]
    dt_sum[, manufactured := paste0(
        sprintf("%.1f", mean_1), " (", sprintf("%.1f", sd_1), ")")]

    fwrite(dt_sum, here("results", "tables", "sum-stats.csv"))
} else {
    dt_sum <- fread(here("results", "tables", "sum-stats.csv"))
}

kbl_sum_stats <- kbl(
    dt_sum[, .(variable, site_built, manufactured)],
    col.names = c("Variable", "Site-Built", "Manufactured"),
    format = "latex",
    booktabs = TRUE,
    caption = "Summary Statistics for Key Features by Housing Type",
    label = "sum-stats",
    linesep = "",
    align = c("l", "r", "r")
) %>%
    add_header_above(c(" " = 1, "Mean (Std. Dev.)" = 2)) %>%
    kable_styling(latex_options = c("hold_position")) %>%
    footnote(
        general = "HMDA data on originated loans for the purchase of owner-occupied homes from 2004 to 2013. Standard deviations shown in parentheses. Nominal values adjusted to 2010 dollars using the CPI.",
        general_title = "Source:",
        footnote_as_chunk = TRUE,
        threeparttable = TRUE
    )

writeLines(kbl_sum_stats, here("results", "tables", "sum-stats.tex"))
save_kable(kbl_sum_stats, here("results", "tables", "sum-stats.pdf"))