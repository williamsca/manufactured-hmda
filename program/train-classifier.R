# This script trains a LightGBM classifier on HMDA data for 2004-2017
# to predict whether a loan is for a manufactured home.

rm(list = ls())
library(here)
library(data.table)

library(lightgbm)
library(pROC)
library(caret)
library(kableExtra)

# import ----
v_train <- 2004:2013
v_valid <- 2014:2015
v_test <- 2016:2017

sink("log.txt")

read_hmda <- function(year) {
    fread(
        here("derived", paste0("hmda_", year, ".csv")), keepLeadingZeros = TRUE,
        drop = c("oo_value_tot"))
}

dt_train <- rbindlist(lapply(v_train, read_hmda), use.names = TRUE)
dt_valid <- rbindlist(lapply(v_valid, read_hmda), use.names = TRUE)
dt_test <- rbindlist(lapply(v_test, read_hmda), use.names = TRUE)

cat("Base rates for manufactured housing loans:\n")
cat("Train (2004-2013):", 100 * mean(dt_train$is_manufactured), "\n")
cat("Validation (2014-2015):", 100 * mean(dt_valid$is_manufactured), "\n")
cat("Test (2016-2017):", 100 * mean(dt_test$is_manufactured), "\n")

# data preprocessing ----

# feature selection and engineering
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

for (col in categorical_features) {
    if (!is.factor(dt_train[[col]])) {
        dt_train[[col]] <- as.factor(dt_train[[col]])
        dt_valid[[col]] <- factor(dt_valid[[col]], levels = levels(dt_train[[col]]))
        dt_test[[col]] <- factor(dt_test[[col]], levels = levels(dt_train[[col]]))
    }

    # Convert factors to integers starting from 0 (LightGBM requirement)
    dt_train[[col]] <- as.integer(dt_train[[col]]) - 1
    dt_valid[[col]] <- as.integer(dt_valid[[col]]) - 1
    dt_test[[col]] <- as.integer(dt_test[[col]]) - 1
}

# impute missing values with state medians
dt_train[, (numeric_features) := lapply(.SD, function(x) {
    fifelse(is.na(x), median(x, na.rm = TRUE), x)
}), .SDcols = numeric_features, by = "state_code"]

dt_test[, (numeric_features) := lapply(.SD, function(x) {
    fifelse(is.na(x), median(x, na.rm = TRUE), x)
}), .SDcols = numeric_features, by = "state_code"]

dt_valid[, (numeric_features) := lapply(.SD, function(x) {
    fifelse(is.na(x), median(x, na.rm = TRUE), x)
}), .SDcols = numeric_features, by = "state_code"]

# convert to LightGBM format
feature_names <- c(categorical_features, numeric_features)
train_x <- as.matrix(dt_train[, ..feature_names])
valid_x <- as.matrix(dt_valid[, ..feature_names])
test_x <- as.matrix(dt_test[, ..feature_names])

train_y <- dt_train$is_manufactured
valid_y <- dt_valid$is_manufactured
test_y <- dt_test$is_manufactured

# 0-based indexing for LightGBM
categorical_indices <- match(
    categorical_features, feature_names) - 1

if (
    any(is.na(categorical_indices)) ||
    any(categorical_indices >= ncol(train_x)) ||
    any(categorical_indices < 0)) {
    stop("Invalid categorical feature indices")
}

# train model ----
train_data <- lgb.Dataset(
    data = train_x,
    label = train_y,
    categorical_feature = categorical_indices
)

valid_data <- lgb.Dataset(
    data = valid_x,
    label = valid_y,
    categorical_feature = categorical_indices,
    reference = train_data
)

# set parameters
params <- list(
    objective = "binary",
    metric = "auc",
    scale_pos_weight = sum(train_y == 0) / sum(train_y == 1),
    learning_rate = 0.05,
    num_leaves = 31,
    feature_fraction = 0.8,
    bagging_fraction = 0.8,
    max_depth = -1,
    min_data_in_leaf = 20,
    max_bin = 3000,
    cat_smooth = 10
)

if (file.exists(here("derived", "mfh-classifier.txt"))) {
    lgb_model <- lgb.load(here("derived", "mfh-classifier.txt"))
    cat("Model loaded from file.\n")
} else {
    lgb_model <- lgb.train(
        params = params,
        data = train_data,
        valids = list(valid = valid_data),
        nrounds = 500,
        early_stopping_rounds = 50,
        verbose = 1
    )
    lgb.save(lgb_model, here("derived", "mfh-classifier.txt"))
}

# evaluate model; analyze temporal drift ----
train_pred <- predict(lgb_model, train_x)
valid_pred <- predict(lgb_model, valid_x)
test_pred <- predict(lgb_model, test_x)

evaluate_performance <- function(predictions, actual, dataset_name) {
    roc_obj <- roc(actual, predictions)
    auc_value <- auc(roc_obj)

    # Find optimal threshold using Youden's J statistic
    optimal_idx <- which.max(roc_obj$sensitivities + roc_obj$specificities - 1)
    optimal_threshold <- roc_obj$thresholds[optimal_idx]

    # Convert probabilities to binary predictions
    binary_preds <- as.factor(ifelse(predictions >= optimal_threshold, 1, 0))
    actual_factor <- as.factor(actual)

    # Confusion matrix and derived metrics
    cm <- confusionMatrix(binary_preds, actual_factor, positive = "1")

    # Return key metrics
    return(list(
        dataset = dataset_name,
        auc = auc_value,
        accuracy = cm$overall["Accuracy"],
        sensitivity = cm$byClass["Sensitivity"], # True positive rate / Recall
        specificity = cm$byClass["Specificity"], # True negative rate
        precision = cm$byClass["Pos Pred Value"],
        f1 = cm$byClass["F1"],
        threshold = optimal_threshold
    ))
}

train_metrics <- evaluate_performance(
    train_pred, dt_train$is_manufactured, "Train (2004-2013)")
valid_metrics <- evaluate_performance(
    valid_pred, dt_valid$is_manufactured, "Validation (2014-2015)")
test_metrics <- evaluate_performance(
    test_pred, dt_test$is_manufactured, "Test (2016-2017)")

all_metrics <- rbindlist(list(
    as.data.table(train_metrics),
    as.data.table(valid_metrics),
    as.data.table(test_metrics)
))

# inspect results ----
print(all_metrics)

# export model metrics table ----
metrics_table <- all_metrics[, .(
    Dataset = dataset,
    AUC = round(auc, 3),
    Accuracy = round(accuracy, 3),
    Sensitivity = round(sensitivity, 3),
    Specificity = round(specificity, 3),
    Precision = round(precision, 3),
    F1 = round(f1, 3)
)]

fwrite(metrics_table, here("results", "tables", "model_metrics.csv"))

kable(metrics_table,
      format = "latex",
      booktabs = TRUE,
      caption = "Light GBM Model Performance Metrics",
      label = "model_metrics") %>%
  kable_styling(latex_options = c("hold_position")) %>%
  footnote(general = "Metrics calculated using optimal threshold from Youden's J statistic. Training: 2004-2013, Validation: 2014-2015, Test: 2016-2017. Source: HMDA data.",
           threeparttable = TRUE) %>%
  writeLines(here("results", "tables", "model_metrics.tex")) %>%
  save_kable(here("results", "tables", "model_metrics.pdf"))

# feature importance analysis
importance <- lgb.importance(lgb_model)
print(importance)

# top 15 features
lgb.plot.importance(importance, top_n = 15)

sink()