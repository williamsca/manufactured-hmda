# This script evaluates the performance of the light gbm model
# by comparing its historical predictions to Census data.

# NB: 'countyfp' is converted to a factor in the imputation script,
# so it does not correspond to an actual county FIPS code.

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)
library(fixest)

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E460")

if (!dir.exists(here("results", "plots"))) {
    dir.create(here("results", "plots"), recursive = TRUE)
}

# import ----
dt <- readRDS(here("derived", "hmda_1990_2017_imputed.Rds"))

dt[, is_mfh_pred_bin := as.factor(fifelse(is_mfh_pred > 0.3, 1, 0))]

dt_state <- dt[, .(
    loan_amount = mean(loan_amount),
    income = mean(income),
    n_originations = .N
),
by = .(is_mfh = is_mfh_pred_bin, state_code, year)
]

dt_mhs <- readRDS(here("derived", "mhs.Rds"))
dt_mhs_yr <- dt_mhs[, .(count = sum(place_tot, na.rm = TRUE)), by = year]

dt_states <- fread(here("crosswalk", "states.txt"), keepLeadingZeros = TRUE)

dt_mhs <- merge(
    dt_mhs, dt_states[, .(state_code = statefp, state_name)],
    by = "state_name", all.x = TRUE
)

# merge HMDA and Census data
dt_state <- merge(
    dt_state, dt_mhs[, .(state_code, year, place_tot)],
    by = c("state_code", "year"), all.x = TRUE
)

dt_yr <- dt_state[,
    .(
        loan_amount = mean(loan_amount),
        income = mean(income),
        n_originations = sum(n_originations),
        place_tot = sum(place_tot, na.rm = TRUE)
    ),
    by = .(is_mfh = as.factor(is_mfh), year)
]

dt_yr[, n_orig_index := 100 * n_originations / n_originations[year == 1998], by = .(is_mfh)]

# densities of loan amounts by imputed property type
dt[, is_mfh := fifelse(is_mfh_pred > 0.3, "Manufactured", "Site-Built")]

ggplot(dt,
    aes(x = loan_amount, color = is_mfh, group = is_mfh, after_stat(density))) +
    geom_freqpoly(bins = 30) +
    scale_color_manual(values = v_palette) +
    scale_x_continuous(limits = c(0, 300)) +
    labs(
        x = "Loan Amount ($1000s)",
        y = "Density",
        color = "" # Imputed Property Type
    ) +
    scale_y_continuous(labels = scales::comma) +
    theme_classic(base_size = 14) +
    theme(legend.position = "bottom")
# Save both PDF and PNG versions for different uses
ggsave(here("results", "plots", "loan_amounts_by_imputed_type.pdf"),
    width = 8, height = 5, device = "pdf")
ggsave(here("results", "plots", "loan_amounts_by_imputed_type.png"),
    width = 8, height = 5, device = "png", dpi = 300)

# compare site-built and manufactured home loans
# originations
ggplot(dt_yr,
    aes(x = year, y = n_orig_index, color = is_mfh, group = is_mfh)) +
    geom_line(linetype = "dashed") +
    scale_x_continuous(breaks = seq(1990, 2003, 2)) +
    geom_point() +
    scale_color_manual(
        values = v_palette,
        labels = c("Site-Built", "Manufactured")) +
    labs(
        x = "",
        y = "Number of originations\n(1998 = 100)",
        color = ""
    ) +
    theme_classic(base_size = 14) +
    theme(legend.position = "bottom")
ggsave(here("results", "plots", "originations_by_year.pdf"),
    width = 8, height = 5, device = "pdf")
ggsave(here("results", "plots", "originations_by_year.png"),
    width = 8, height = 5, device = "png", dpi = 300)

# loam amounts
ggplot(dt_yr,
    aes(x = year, y = loan_amount, color = is_mfh, group = is_mfh)) +
    geom_line(linetype = "dashed") +
    geom_point() +
        scale_x_continuous(breaks = seq(1990, 2003, 2)) +
    geom_point() +
    scale_color_manual(
        values = v_palette,
        labels = c("Site-Built", "Manufactured")) +
    labs(
        x = "",
        y = "Loan amount\n($1000s)",
        color = ""
    ) +
    theme_classic(base_size = 14) +
    theme(legend.position = "bottom")

# compare mfh originations to placement data
dt_yr[, n_originations := as.numeric(n_originations)]
dt_yr <- melt(dt_yr[is_mfh == 1], id.vars = c("year", "is_mfh"),
    measure.vars = c("n_originations", "place_tot"),
    variable.name = "type", value.name = "count"
)

dt_yr[, index := 100 * count / count[year == 1998], by = .(type)]

ggplot(dt_yr,
        aes(
            x = year, y = index, color = type, group = type,
            linetype = type)
) +
    geom_hline(yintercept = seq(0, 100, 25), linetype = "dotted", color = "gray") +
    geom_line(linewidth = 1.5) +
    scale_x_continuous(breaks = seq(1990, 2003, 2), limits = c(1990, 2003)) +
    scale_color_manual(
        values = v_palette,
        labels = c(
            "Total Placements (Census)",
            "Imputed Originations (HMDA)"
        )
    ) +
    scale_linetype_manual(
        values = c("solid", "dashed"),
        labels = c(
            "Total Placements (Census)",
            "Imputed Originations (HMDA)"
        )
    ) +
    labs(
        x = "",
        y = "Quantity Index\n(1998 = 100)",
        color = "",
        linetype = ""
    ) +
    theme_classic(base_size = 14) +
    theme(legend.position = "bottom")
ggsave(here("results", "plots", "orig_tot-place_tot.pdf"),
    width = 8, height = 5, device = "pdf")
ggsave(here("results", "plots", "orig_tot-place_tot.png"),
    width = 8, height = 5, device = "png", dpi = 300)