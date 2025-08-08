# Manufactured Housing HMDA Classifier - Build System
# This Makefile orchestrates the complete data pipeline from raw data retrieval
# to model training and evaluation.

# Configuration
SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:

# Directories
PROGRAM_DIR := program
DATA_DIR := data
DERIVED_DIR := derived
RESULTS_DIR := results
CROSSWALK_DIR := crosswalk

# Create necessary directories
$(DATA_DIR) $(DERIVED_DIR) $(RESULTS_DIR):
	mkdir -p $@

# Help target
.PHONY: help
help: ## Display this help message
	@echo "Manufactured Housing HMDA Classifier Build System"
	@echo "================================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Quick start:"
	@echo "  1. Set CENSUS_KEY environment variable"
	@echo "  2. Run 'make all' to build complete pipeline"

# Data retrieval (placeholder - user will implement)
.PHONY: data-retrieve
data-retrieve: ## Retrieve raw data (HMDA, CPI, lender data)
	@echo "Running automated data retrieval scripts..."
	@echo "Note: This target assumes data retrieval scripts are implemented"
	@echo "Expected downloads:"
	@echo "  - HMDA data (1990-2023) → $(DATA_DIR)/hmda/"
	@echo "  - CPI data → $(DATA_DIR)/cpi/"
	@echo "  - Manufactured lender data → $(DATA_DIR)/"
	@if [ ! -d "$(DATA_DIR)/hmda" ]; then echo "Warning: HMDA data directory not found"; fi

# Data processing pipeline
.PHONY: data-process
data-process: $(DERIVED_DIR) data-retrieve ## Process raw data into analysis-ready format
	@echo "Processing manufactured home lender data..."
	Rscript $(PROGRAM_DIR)/import-manufactured-lenders.R
	@echo "Downloading Census demographic data..."
	Rscript $(PROGRAM_DIR)/import-census.R
	@echo "Processing HMDA mortgage data..."
	Rscript $(PROGRAM_DIR)/import-hmda.R
	@echo "Building integrated dataset with features..."
	Rscript $(PROGRAM_DIR)/databuild.R
	@echo "Data processing complete."

# Model training and evaluation
.PHONY: model-train
model-train: data-process $(RESULTS_DIR) ## Train the manufactured housing classifier
	@echo "Training LightGBM classifier..."
	Rscript $(PROGRAM_DIR)/train-classifier.R
	@echo "Model training complete. Saved to $(DERIVED_DIR)/mfh-classifier.txt"

.PHONY: model-evaluate
model-evaluate: model-train ## Evaluate model performance and generate validation plots
	@echo "Applying classifier to historical data..."
	Rscript $(PROGRAM_DIR)/impute-mfh.R
	@echo "Evaluating classifier performance..."
	Rscript $(PROGRAM_DIR)/evaluate-classifier.R
	@echo "Model evaluation complete. Results in $(RESULTS_DIR)/"

# Documentation
.PHONY: docs
docs: ## Generate documentation (LaTeX to PDF)
	@if command -v pdflatex >/dev/null 2>&1; then \\
		echo "Compiling classifier documentation..."; \\
		pdflatex classifier-details.tex; \\
		echo "Documentation compiled to classifier-details.pdf"; \\
	else \\
		echo "Warning: pdflatex not found. Install TeX Live to compile documentation."; \\
	fi

# Complete pipeline
.PHONY: all
all: model-evaluate docs ## Run complete pipeline from data retrieval to evaluation
	@echo ""
	@echo "==============================================="
	@echo "Pipeline completed successfully!"
	@echo "==============================================="
	@echo "Outputs:"
	@echo "  - Trained classifier: $(DERIVED_DIR)/mfh-classifier.txt"
	@echo "  - Historical predictions: $(DERIVED_DIR)/hmda_1990-2003_imputed.Rds"
	@echo "  - Evaluation plots: $(RESULTS_DIR)/plots/"
	@echo "  - Model metrics: $(RESULTS_DIR)/tables/"
	@echo "  - Documentation: classifier-details.pdf"

# Data quality checks
.PHONY: check-data
check-data: ## Verify data integrity and completeness
	@echo "Checking data completeness..."
	@echo "HMDA files found: $$(find $(DATA_DIR)/hmda -name '*.csv' 2>/dev/null | wc -l)"
	@echo "Processed HMDA files: $$(find $(DERIVED_DIR) -name 'hmda_*.csv' 2>/dev/null | wc -l)"
	@echo "Census files (ACS): $$(find $(DERIVED_DIR)/acs -name '*.csv' 2>/dev/null | wc -l)"
	@echo "Census files (SF3): $$(find $(DERIVED_DIR)/sf3 -name '*.csv' 2>/dev/null | wc -l)"
	@if [ -f "$(DERIVED_DIR)/manufactured_lenders.Rds" ]; then \\
		echo "✓ Manufactured lenders data: Present"; \\
	else \\
		echo "✗ Manufactured lenders data: Missing"; \\
	fi
	@if [ -f "$(DERIVED_DIR)/mfh-classifier.txt" ]; then \\
		echo "✓ Trained classifier: Present"; \\
	else \\
		echo "✗ Trained classifier: Missing"; \\
	fi

# Environment setup
.PHONY: check-env
check-env: ## Check environment prerequisites
	@echo "Checking environment prerequisites..."
	@command -v R >/dev/null 2>&1 || { echo "✗ R not found. Please install R."; exit 1; }
	@echo "✓ R found: $$(R --version | head -n1)"
	@if [ -z "$$CENSUS_KEY" ]; then \\
		echo "✗ CENSUS_KEY environment variable not set"; \\
		echo "  Get a key at: https://api.census.gov/data/key_signup.html"; \\
		exit 1; \\
	else \\
		echo "✓ Census API key configured"; \\
	fi
	@echo "✓ Environment check passed"

# Install R dependencies
.PHONY: install-deps
install-deps: ## Install required R packages
	@echo "Installing R package dependencies..."
	Rscript -e "packages <- c('here', 'data.table', 'readxl', 'bit64', 'censusapi', 'lightgbm', 'pROC', 'caret', 'fixest', 'ggplot2', 'kableExtra'); install.packages(packages[!packages %in% installed.packages()[,'Package']], dependencies=TRUE)"
	@echo "Package installation complete."

# Testing
.PHONY: test
test: check-env check-data ## Run basic pipeline tests
	@echo "Running pipeline tests..."
	@echo "This is a placeholder for test implementation"
	@echo "Consider adding:"
	@echo "  - Data format validation"
	@echo "  - Model performance benchmarks"
	@echo "  - Output file integrity checks"

# Cleanup
.PHONY: clean
clean: ## Remove generated files (keep raw data)
	@echo "Cleaning generated files..."
	rm -rf $(DERIVED_DIR)/*
	rm -rf $(RESULTS_DIR)/*
	rm -f classifier-details.pdf classifier-details.aux classifier-details.log
	rm -f classifier-details.out classifier-details.synctex.gz
	rm -f classifier-log.txt impute-mfh.log
	rm -f .RData Rplots.pdf
	@echo "Cleanup complete."

.PHONY: clean-all
clean-all: clean ## Remove all generated files including raw data
	@echo "Removing all data files..."
	rm -rf $(DATA_DIR)/*
	@echo "Complete cleanup finished."

# Development targets
.PHONY: lint
lint: ## Check R code style (requires lintr package)
	@if Rscript -e "library(lintr)" 2>/dev/null; then \\
		echo "Running R code linting..."; \\
		Rscript -e "lintr::lint_dir('$(PROGRAM_DIR)')"; \\
	else \\
		echo "Warning: lintr package not installed. Install with: install.packages('lintr')"; \\
	fi

# Status reporting
.PHONY: status
status: ## Show pipeline status and file timestamps
	@echo "Pipeline Status Report"
	@echo "====================="
	@echo "Generated files:"
	@find $(DERIVED_DIR) $(RESULTS_DIR) -type f -exec ls -lh {} \\; 2>/dev/null || echo "  No generated files found"
	@echo ""
	@echo "Disk usage:"
	@du -sh $(DATA_DIR) $(DERIVED_DIR) $(RESULTS_DIR) 2>/dev/null || echo "  Unable to calculate disk usage"

# Mark all targets as phony to avoid conflicts with file names
.PHONY: data-retrieve data-process model-train model-evaluate docs all check-data check-env install-deps test clean clean-all lint status