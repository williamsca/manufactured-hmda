# Manufactured Housing Classification in Historical HMDA Data

This repository contains documentation and output for a machine learning classifier that identifies mobile home loans in historical Home Mortgage Disclosure Act (HMDA) data from 1990-2003, when property type information was not collected. The data are available for public use and may be downloaded from Zenodo:

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.16848727.svg)](https://doi.org/10.5281/zenodo.16848727)

The imputed data highlight the massive collapse in the market for mobile home mortgages during the early 2000s. The collapse culminated in the [2002 bankruptcy of Conseco](https://www.nytimes.com/2002/12/19/business/conseco-files-for-bankruptcy-protection.html), an insurance and financial company with heavy exposure to the mobile home market. Originated loan volumes declined massively, both in levels and relative to site-built lending, and even by 2017 they remained at less than 50% of their 1998 peak.

![Mortgage Trends by House Type](https://github.com/williamsca/manufactured-hmda/blob/main/results/plots/originations_by_year.png?raw=true)

## Overview

### The Missing Data Problem

Prior to 2004, the Home Mortgage Disclosure Act (HMDA) did not require lenders to report property type information, creating a substantial gap in our understanding of manufactured home lending patterns during the 1990s and early 2000s. This period coincides with significant expansion in subprime lending and represents a crucial era for understanding housing finance in the sector.

The lack of property type data prevents researchers from analyzing manufactured home lending patterns, geographic concentration, and borrower characteristics during this formative period in manufactured housing finance.

### Solution: Machine Learning Classification

I employ a **Light Gradient Boosting Machine (LightGBM)** classifier to identify manufactured home loans in historical HMDA data. The model is trained on HMDA data from 2004-2013 (when property type was reported) and validated on 2014-2017 data. The LightGBM classifier helps to capture interactions between loan, lender, and geographic features and is especially effective for settings with high-dimensional categorical data.

## Data and Methodology

### Training Data Characteristics

The classifier uses multiple feature categories to distinguish manufactured from site-built home loans:

- **Loan characteristics**: Amount, loan-to-income ratio
- **Geographic features**: Rural status, tract-level housing composition 
- **Lender attributes**: Average loan size, lending volume, specialization
- **Borrower demographics**: Income relative to local median

There are stark differences between manufactured and site-built home loans in the training data:

</head>
<body>
<table style="NAborder-bottom: 0;">
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Mean (Std. Dev.)</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Variable </th>
   <th style="text-align:right;"> Site-Built </th>
   <th style="text-align:right;"> Manufactured </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Loan Amount ($1000s) </td>
   <td style="text-align:right;"> 208.5 (198.3) </td>
   <td style="text-align:right;"> 75.0 (182.4) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Income ($1000s) </td>
   <td style="text-align:right;"> 98.0 (127.5) </td>
   <td style="text-align:right;"> 50.9 (45.7) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Urban Area (%) </td>
   <td style="text-align:right;"> 90.6 (29.2) </td>
   <td style="text-align:right;"> 63.3 (48.2) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Mobile Home Share of All Housing (%) </td>
   <td style="text-align:right;"> 4.8 (8.6) </td>
   <td style="text-align:right;"> 23.0 (15.3) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Loan-to-Income Ratio </td>
   <td style="text-align:right;"> 2.5 (3.3) </td>
   <td style="text-align:right;"> 1.7 (3.7) </td>
  </tr>
</tbody>
<tfoot>
<tr><td style="padding: 0; " colspan="100%"><span style="font-style: italic;">Source:</span></td></tr>
<tr><td style="padding: 0; " colspan="100%">
<sup></sup> HMDA data on originated loans for the purchase of owner-occupied homes from 2004 to 2013.</td></tr>
<tr><td style="padding: 0; " colspan="100%">
<sup></sup> Standard deviations shown in parentheses. Nominal values are adjusted to 2010 dollars.</td></tr>
</tfoot>
</table>
</body>

*Note: Dollar amounts in 2010 dollars*

### Model Performance

The LightGBM classifier demonstrates excellent performance across training, validation, and test periods:

</head>
<body>
<table style="NAborder-bottom: 0;">
 <thead>
  <tr>
   <th style="text-align:left;"> Dataset </th>
   <th style="text-align:right;"> AUC </th>
   <th style="text-align:right;"> Accuracy </th>
   <th style="text-align:right;"> Sensitivity </th>
   <th style="text-align:right;"> Specificity </th>
   <th style="text-align:right;"> Precision </th>
   <th style="text-align:right;"> F1 </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Train (2004-2013) </td>
   <td style="text-align:right;"> 0.987 </td>
   <td style="text-align:right;"> 0.934 </td>
   <td style="text-align:right;"> 0.954 </td>
   <td style="text-align:right;"> 0.933 </td>
   <td style="text-align:right;"> 0.262 </td>
   <td style="text-align:right;"> 0.411 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Validation (2014-2015) </td>
   <td style="text-align:right;"> 0.985 </td>
   <td style="text-align:right;"> 0.932 </td>
   <td style="text-align:right;"> 0.944 </td>
   <td style="text-align:right;"> 0.932 </td>
   <td style="text-align:right;"> 0.248 </td>
   <td style="text-align:right;"> 0.393 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Test (2016-2017) </td>
   <td style="text-align:right;"> 0.979 </td>
   <td style="text-align:right;"> 0.915 </td>
   <td style="text-align:right;"> 0.931 </td>
   <td style="text-align:right;"> 0.914 </td>
   <td style="text-align:right;"> 0.208 </td>
   <td style="text-align:right;"> 0.340 </td>
  </tr>
</tbody>
</table>
</body>

**Key Performance Insights:**

- **Excellent Discrimination**: AUC values near 0.98 indicate the model reliably separates manufactured from site-built home loans
- **High Sensitivity**: The model successfully identifies 92-95% of actual manufactured home loans, crucial for research applications
- **Moderate Precision**: Reflects the challenge of the heavily imbalanced dataset where manufactured homes constitute a small fraction of total loans

The modest decline from training to test periods (AUC: 0.987 → 0.978, F1: 0.413 → 0.350) suggests some temporal drift but indicates the model remains robust for historical prediction.

### Model Validation

#### Loan Amount Distribution

The classifier does not rely solely on loan amounts to distinguish property types. Analysis of predicted loan amounts shows significant overlap between manufactured and site-built homes, especially in the $60,000-$100,000 range.

![Loan Amounts by Property Type](https://github.com/williamsca/manufactured-hmda/blob/main/results/plots/loan_amounts_by_imputed_type.png?raw=true)

#### External Validation Against Census Data

I validate the model's historical predictions against independent Census data on manufactured home placements. The model successfully captures the decline in manufactured housing that began in 1999, though origination patterns lag placement data. This lag is reasonable given the inherent difference between loan origination and actual home placement.

![Originations vs Placements](https://github.com/williamsca/manufactured-hmda/blob/main/results/plots/orig_tot-place_tot.png?raw=true)

## Repository Structure

```
manufactured-hmda/
├── program/                    # R scripts for data processing and modeling
│   ├── import-hmda.R          # HMDA data import and processing
│   ├── import-census.R        # Census demographic data via API
│   ├── import-manufactured-lenders.R  # HUD lender data processing
│   ├── databuild.R            # Feature engineering and data integration
│   ├── train-classifier.R     # LightGBM model training
│   ├── evaluate-classifier.R  # Model evaluation and validation
│   └── impute-mfh.R          # Apply classifier to historical data
├── crosswalk/                 # Geographic concordance files
├── results/                   # Generated tables and figures
│   ├── tables/               # LaTeX/PDF tables
│   └── plots/                # Validation plots
├── requirements.txt           # R package dependencies
├── Makefile                  # Build system for complete pipeline
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- **R** >= 4.0.0
- **System Requirements**: 32GB+ RAM, 8+ cores recommended for large datasets
- **Census API Key**: Register at https://api.census.gov/data/key_signup.html
- **HMDA Data**: Download raw HMDA files as described below

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/manufactured-hmda.git
   cd manufactured-hmda
   ```

2. **Set up environment:**
   ```bash
   # Set Census API key
   export CENSUS_KEY="your_api_key_here"
   
   # Check environment
   make check-env
   ```

3. **Install R dependencies:**
   ```bash
   make install-deps
   ```

### Data Preparation
1. Navigate to [OpenICPSR](https://www.openicpsr.org/openicpsr/project/151921/version/V1/view) to download historical HMDA data files (1990-2006) provided in a digital format by Andrew Forrester. Place the downloaded `.zip` files in the `data/hmda/` directory.
2. Navigate to [CFPB](https://www.consumerfinance.gov/data-research/hmda/historic-data/?geo=nationwide&records=originated-records&field_descriptions=codes) and download contemporary HMDA data (2007-2017) and save them in the same `data/hmda/` directory. Make sure to obtain all originated mortgages.

### Usage

#### Complete Pipeline

Run the full pipeline from data retrieval to model evaluation:

```bash
make all
```

This will:
1. Retrieve raw data (HMDA, Census, CPI)
2. Process and integrate datasets
3. Train the LightGBM classifier
4. Generate validation plots and tables
5. Apply classifier to historical data (1990-2003)

#### Individual Steps

```bash
# Data processing only
make data-process

# Model training only  
make model-train

# Model evaluation only
make model-evaluate

# Generate documentation
make docs
```

#### Check Pipeline Status

```bash
# Verify data completeness
make check-data

# Show file status and disk usage
make status
```

### Outputs

After running the complete pipeline:

- **Trained classifier**: `derived/mfh-classifier.txt`
- **Historical predictions**: `derived/hmda_1990-2003_imputed.Rds`
- **Validation plots**: `results/plots/`
- **Performance tables**: `results/tables/`

## Data Sources

This project integrates data from multiple sources:

- **HMDA Data**: Home Mortgage Disclosure Act loan-level data (1990-2017)
  - 1990-2006: https://doi.org/10.3886/E151921V1
  - 2007-2017: https://www.consumerfinance.gov/data-research/hmda/historic-data/
  
- **Census Data**: American Community Survey and Decennial Census
  - Tract-level demographics and housing characteristics
  - Retrieved via Census API
  
- **CPI Data**: Bureau of Labor Statistics Consumer Price Index
  - For inflation adjustment to 2010 dollars
  
- **Manufactured Home Lenders**: HUD list of specialized lenders
  - Historical lender classifications for feature engineering

## Imputed Data Access

**Placeholder**: Links to imputed HMDA data (1990-2003) will be provided upon publication. The dataset will include:
- All original HMDA variables
- Predicted manufactured home probability
- Binary classification (threshold = 0.5)
- Model confidence intervals

## Limitations and Considerations

- **Precision**: Around 25% precision means 1 in 4 predicted manufactured home loans is actually manufactured
- **Temporal Drift**: Model performance declines slightly over time, suggesting some structural changes in lending patterns
- **Geographic Bias**: Performance may vary in regions with substantially different lending patterns than training data
- **Class Imbalance**: Manufactured homes represent <3% of total loans, inherently challenging for classification

## Citation

If you use this classifier or the imputed data in your research, please cite:

```bibtex
@software{manufactured_hmda_classifier,
  title = {Manufactured Housing Classification in Historical HMDA Data},
  author = {[Colin Williams]},
  year = {2025},
  doi = {10.5281/zenodo.XXXXXXX},
  url = {https://github.com/yourusername/manufactured-hmda}
}
```

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

We welcome contributions to improve the classifier and extend the methodology. Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with tests and documentation

## Support

For questions about the methodology or implementation:
- Open an [issue](https://github.com/yourusername/manufactured-hmda/issues)
- Contact: [williams.colinandrew@gmail.com]

## Acknowledgments

- U.S. Census Bureau for demographic data access
- Consumer Financial Protection Bureau for HMDA data
- Department of Housing and Urban Development for manufactured home lender data
- Forrester, Andrew. Historical Home Mortgage Disclosure Act (HMDA) Data. Ann Arbor, MI: Inter-university Consortium for Political and Social Research [distributor], 2021-10-10. https://doi.org/10.3886/E151921V1
