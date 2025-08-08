# Repository Preparation Todo List

## Overview
This repository contains scripts and documentation for a machine learning classifier that imputes whether loans are for manufactured homes in historical HMDA data (1990-2003). The goal is to clean up the code for public release and transfer documentation from LaTeX to README.md format.

## Current Repository State
- **Main scripts**: 7 R files in `/program/` directory for data import, processing, training, and evaluation
- **Documentation**: Currently in `classifier-details.tex` with tables and figures referenced but not present
- **Data structure**: Raw data in `/data/` directory that needs to be removed
- **Dependencies**: Uses R with lightgbm, data.table, ggplot2, and other packages
- **Missing components**: No requirements.txt, trained classifier model not saved, Makefile needs updating

## Key Tasks to Complete

### 1. Code Cleanup and Documentation
- [x] **Clean up R scripts** - Remove hardcoded paths, add error handling, improve comments
- [x] **Update data paths** - Modify scripts to assume automated data retrieval scripts exist
- [x] **Create requirements.txt** - Document R package dependencies
- [x] **Update Makefile** - Create comprehensive build system for data pipeline and documentation
- [ ] **Add citation information** - Details on citing the classifier and data. Use Zenodo with Github integration. (User will do this.)

### 2. Documentation Transfer
- [x] **Convert LaTeX to Markdown** - Transfer content from `classifier-details.tex` to `README.md`
- [x] **Generate PDF from LaTeX tables** - Compile tables (`sum-stats.tex`, `model_metrics.tex`, `orig_tot-place_tot.tex`) as PDFs using kableExtra
- [x] **Create figures for README** - Convert/save plots referenced in LaTeX as images for markdown
- [x] **Structure README** - Organize with proper sections: Overview, Placeholder link to imputed data, Methodology, Results, Usage

### 3. Model and Data Management  
- [ ] **Save trained classifier** - Ensure model is saved and can be loaded for inference
- [ ] **Remove raw data** - Clean out `/data/` directory contents 
- [ ] **Create data download scripts** - Placeholder/documentation for HMDA, CPI, and lender data retrieval
- [ ] **Document data requirements** - Specify what data needs to be downloaded and where

### 4. Repository Structure
- [ ] **Organize outputs** - Create `/results/` directory structure for tables, figures, and model outputs
- [ ] **Update .gitignore** - Exclude data files, logs, and temporary files appropriately  
- [ ] **Add example usage** - Create simple example of how to run the full pipeline
- [ ] **License and attribution** - Ensure proper licensing and citation information

### 5. Technical Requirements
- [ ] **Error handling** - Add proper error checking in R scripts
- [ ] **Reproducibility** - Ensure scripts can run in correct order with proper dependencies
- [ ] **Cross-platform compatibility** - Test that scripts work across different environments
- [ ] **Performance documentation** - Document computational requirements and runtime expectations

## Files Requiring Attention

### R Scripts (in `/program/`)
- `databuild.R` - Main data assembly script
- `import-hmda.R` - HMDA data import (needs data retrieval integration) 
- `import-census.R` - Census data import
- `import-manufactured-lenders.R` - Lender data import
- `train-classifier.R` - Model training script (needs model saving)
- `evaluate-classifier.R` - Model evaluation 
- `impute-mfh.R` - Apply classifier to historical data

### Documentation Files
- `classifier-details.tex` - Source documentation to be converted
- `README.md` - Target for comprehensive documentation
- `Makefile` - Needs complete rewrite for new pipeline

### Data Structure
- Remove contents of `/data/acs/`, `/data/hmda/`, `/derived/` directories
- Keep crosswalk files in `/crosswalk/` as they appear to be reference data
- Preserve CPI files or document how to obtain them

## Success Criteria
1. Repository can be cloned and run by external users with proper R environment
2. README.md provides comprehensive documentation with embedded tables/figures  
3. All scripts reference data retrieval rather than pre-existing data files
4. Trained classifier model is saved and can be loaded for inference
5. Full pipeline can be executed via Makefile
6. Code follows best practices for reproducible research

## Questions for User
- Should the crosswalk files in `/crosswalk/` be kept or also made downloadable? These will be made downloadable.
- Are there specific R package version requirements that should be documented? No.
- Should the repository include example/sample data for testing the pipeline? No.
- What level of computational resources should be documented as requirements? 128GB RAM, 8 cores, 1TB SSD