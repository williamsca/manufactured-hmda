# This script creates a detection error tradeoff plot showing false positive
# rate and false negative rate as a function of the classification threshold
# on the test set (2016-2017).
#
# FPR = P(classified MH | truly not MH)  -- contamination of MH sample
# FNR = P(classified not MH | truly MH)  -- missed MH loans

rm(list = ls())
library(here)
library(data.table)
library(lightgbm)
library(ggplot2)

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")
v_lines <- c("solid", "dashed")

# import ----
v_train <- 2004:2013
v_test <- 2016:2017

read_hmda <- function(year) {
    fread(
        here("derived", paste0("hmda_", year, ".csv")), keepLeadingZeros = TRUE,
        drop = c("oo_value_tot"))
}

dt_train <- rbindlist(lapply(v_train, read_hmda), use.names = TRUE)
dt_test <- rbindlist(lapply(v_test, read_hmda), use.names = TRUE)

# preprocessing (must match train-classifier.R) ----
selected_features <- c(
    "loan_type", "loan_amount", "loan_to_income",
    "is_urban", "rural_loan",
    "oo_value_avg", "mfh_value_avg", "mfh_pct",
    "sfd_pct", "mfh_oo_pct",
    "tr2010ge", "countyfp", "loan_to_value",
    "loan_to_mfh_value",
    "agency_code", "respondent_id", "purchaser_type",
    "lender_avg_loan", "lender_loan_count", "lender_avg_inc",
    "property_type_imp", "loan_bin",
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

for (col in categorical_features) {
    if (!is.factor(dt_train[[col]])) {
        dt_train[[col]] <- as.factor(dt_train[[col]])
        dt_test[[col]] <- factor(dt_test[[col]], levels = levels(dt_train[[col]]))
    }
    dt_train[[col]] <- as.integer(dt_train[[col]]) - 1
    dt_test[[col]] <- as.integer(dt_test[[col]]) - 1
}

rm(dt_train)
gc()

dt_test[, (numeric_features) := lapply(.SD, function(x) {
    fifelse(is.na(x), median(x, na.rm = TRUE), x)
}), .SDcols = numeric_features, by = "state_code"]

feature_names <- c(categorical_features, numeric_features)
test_x <- as.matrix(dt_test[, ..feature_names])
test_y <- dt_test$is_manufactured

# load model and predict ----
lgb_model <- lgb.load(here("derived", "mfh-classifier.txt"))
test_pred <- predict(lgb_model, test_x)

# compute error rates across thresholds ----
thresholds <- seq(0, 1, by = 0.005)

dt_errors <- rbindlist(lapply(thresholds, function(t) {
    pred_pos <- test_pred >= t
    tp <- sum(pred_pos & test_y == 1)
    fp <- sum(pred_pos & test_y == 0)
    fn <- sum(!pred_pos & test_y == 1)
    tn <- sum(!pred_pos & test_y == 0)
    data.table(
        threshold = t,
        fpr = fp / (fp + tn),
        fnr = fn / (fn + tp)
    )
}))

# Youden's J optimal threshold
dt_errors[, j := (1 - fpr) + (1 - fnr) - 1]
optimal_t <- dt_errors[which.max(j)]

# plot ----
dt_plot <- melt(dt_errors,
    id.vars = "threshold",
    measure.vars = c("fpr", "fnr"),
    variable.name = "error_type", value.name = "rate"
)

dt_plot[, error_type := factor(error_type,
    levels = c("fpr", "fnr"),
    labels = c("False Positive Rate", "False Negative Rate")
)]

ggplot(dt_plot, aes(x = threshold, y = rate,
        color = error_type, linetype = error_type)) +
    geom_line(linewidth = 1) +
    geom_vline(xintercept = optimal_t$threshold,
        linetype = "dotted", color = "black") +
    annotate("text",
        x = optimal_t$threshold + 0.02, y = 0.85,
        label = paste0("Optimal threshold\n(t = ",
            round(optimal_t$threshold, 2), ")"),
        hjust = 0, size = 3.5, color = "gray40", family = "serif") +
    scale_color_manual(values = v_palette) +
    scale_linetype_manual(values = v_lines) +
    scale_x_continuous(breaks = seq(0, 1, 0.1)) +
    scale_y_continuous(labels = scales::percent_format()) +
    labs(
        x = "Classification threshold",
        y = "Error rate",
        color = "",
        linetype = ""
    ) +
    theme_classic(base_size = 14) +
    theme(
        text = element_text(family = "serif"),
        legend.position = "right"
    )

ggsave(here("results", "plots", "det_threshold.pdf"),
    width = 9, height = 5)
