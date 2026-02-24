# Climate Data Extraction Tool

A RShiny application for extracting bioclimatic variables from WorldClim 2.1 climate data based on geographic coordinates.

## Overview

This tool allows researchers and analysts to extract 19 bioclimatic variables (temperature and precipitation data) for any location on Earth using historical data (1981-2024) or future climate projections (2021-2100) under different emissions scenarios.

## Features

- **Multiple Input Methods**
  - Manual coordinate entry (latitude/longitude)
  - CSV file upload with flexible column naming
  
- **Time Period Selection**
  - Historical: 1981-2024
  - Near Future: 2021-2040
  - Mid Future: 2041-2060
  - Late Future: 2061-2080
  - End Century: 2081-2100

- **Climate Scenarios (for future projections)**
  - SSP1-2.6: Low emissions pathway
  - SSP2-4.5: Medium emissions pathway
  - SSP3-7.0: High emissions pathway
  - SSP5-8.5: Very high emissions pathway

## Installation

### Prerequisites

1. **R** (version 4.0 or higher)
2. **RStudio** (recommended)

### Required R Packages

Install the required packages using:

```r
install.packages(c(
  "shiny",
  "dplyr",
  "terra",
  "DT"
))
```

### WorldClim Data Files

You'll need to download WorldClim 2.1 climate data files:

#### For Historical Data (1981-2024)
- Download individual bioclimatic variable files (BIO1-BIO19)
- Place in: `data/WorldClim_Data_1981_2024/`
- Files should be named: `BIO1_WORLD_*.tif`, `BIO2_WORLD_*.tif`, etc.

#### For Future Projections (2021-2100)
- Download from [WorldClim CMIP6 Downloads](https://www.worldclim.org/data/cmip6/cmip6_clim5m.html)
- Model: EC-Earth3-Veg
- Resolution: 5 arc-minutes (~9km at equator)
- Download all 4 SSP scenarios for each time period

**File Structure:**
```
data/
├── WorldClim_Data_1981_2024/
│   ├── BIO1_WORLD_TCgrid__CHIRPSppt_1981_2024.tif
│   ├── BIO2_WORLD_TCgrid__CHIRPSppt_1981_2024.tif
│   └── ... (BIO3 through BIO19)
│
├── WorldClim_Data_2021_2040/
│   ├── wc2.1_5m_bioc_EC-Earth3-Veg_ssp126_2021-2040.tif
│   ├── wc2.1_5m_bioc_EC-Earth3-Veg_ssp245_2021-2040.tif
│   ├── wc2.1_5m_bioc_EC-Earth3-Veg_ssp370_2021-2040.tif
│   └── wc2.1_5m_bioc_EC-Earth3-Veg_ssp585_2021-2040.tif
│
├── WorldClim_Data_2041_2060/
│   ├── wc2.1_5m_bioc_EC-Earth3-Veg_ssp126_2041-2060.tif
│   ├── wc2.1_5m_bioc_EC-Earth3-Veg_ssp245_2041-2060.tif
│   ├── wc2.1_5m_bioc_EC-Earth3-Veg_ssp370_2041-2060.tif
│   └── wc2.1_5m_bioc_EC-Earth3-Veg_ssp585_2041-2060.tif
│
├── WorldClim_Data_2061_2080/
│   └── (same pattern as above)
│
└── WorldClim_Data_2081_2100/
    └── (same pattern as above)
```

## Project Structure

```
your_project/
├── app.R                           # Main Shiny application
├── data/                           # WorldClim data files (see above)
├── diagnostic_script.R             # Diagnostic tool for troubleshooting
├── sample_coordinates.csv          # Sample input file
└── README.md                       # This file
```

## Usage

### Starting the Application

1. Open RStudio
2. Set your working directory to the project folder:
   ```r
   setwd("path/to/your/project")
   ```
3. Run the application:
   ```r
   shiny::runApp("app.R")
   ```
4. The app will open in your default web browser

### Step-by-Step Workflow

#### Step 1: Provide Coordinates

**Option A: Manual Entry**
1. Select "Enter manually"
2. Enter latitude (-90 to 90)
3. Enter longitude (-180 to 180)
4. Click "Add" to add to the table
5. Repeat for multiple coordinates
6. Use "Clear All" to reset if needed

**Option B: Upload CSV File**
1. Select "Upload CSV file"
2. Prepare a CSV with columns starting with:
   - `lat` (e.g., latitude, lat, lat_deg)
   - `lon` (e.g., longitude, lon, lon_deg)
3. Click "Browse" and select your file
4. The app automatically detects and uses the correct columns
5. All other columns are ignored

#### Step 2: Select Climate Data

1. **Time Period**: Choose from dropdown
   - Historical (1981-2024) - observed data
   - 2021-2040 / 2041-2060 / 2061-2080 / 2081-2100 - projections

2. **Model**: Currently EC-Earth3-Veg (default)

3. **Climate Scenario** (future periods only):
   - SSP1-2.6: Sustainable development, low emissions
   - SSP2-4.5: Middle-of-the-road scenario
   - SSP3-7.0: Regional rivalry, high emissions
   - SSP5-8.5: Fossil-fueled development, very high emissions

#### Step 3: Extract Data

1. Click "Extract Bio Variables"
2. Monitor progress bar
3. Wait for "Success!" message

#### Step 4: Review and Download

1. Review extracted data in the preview table
2. Check for any NA values (indicating water/ocean locations)
3. Click "Download CSV" to save results

### Output Format

The downloaded CSV contains:

| Column | Description |
|--------|-------------|
| id | Auto-generated site ID (Site_1, Site_2, etc.) |
| latitude | Input latitude |
| longitude | Input longitude |
| bio1-bio19 | Bioclimatic variables (see below) |

## Bioclimatic Variables

| Variable | Description | Units |
|----------|-------------|-------|
| bio1 | Annual Mean Temperature | °C × 10 |
| bio2 | Mean Diurnal Range | °C × 10 |
| bio3 | Isothermality (bio2/bio7 × 100) | % |
| bio4 | Temperature Seasonality (std dev × 100) | °C × 100 |
| bio5 | Max Temperature of Warmest Month | °C × 10 |
| bio6 | Min Temperature of Coldest Month | °C × 10 |
| bio7 | Temperature Annual Range (bio5-bio6) | °C × 10 |
| bio8 | Mean Temperature of Wettest Quarter | °C × 10 |
| bio9 | Mean Temperature of Driest Quarter | °C × 10 |
| bio10 | Mean Temperature of Warmest Quarter | °C × 10 |
| bio11 | Mean Temperature of Coldest Quarter | °C × 10 |
| bio12 | Annual Precipitation | mm |
| bio13 | Precipitation of Wettest Month | mm |
| bio14 | Precipitation of Driest Month | mm |
| bio15 | Precipitation Seasonality (CV) | % |
| bio16 | Precipitation of Wettest Quarter | mm |
| bio17 | Precipitation of Driest Quarter | mm |
| bio18 | Precipitation of Warmest Quarter | mm |
| bio19 | Precipitation of Coldest Quarter | mm |

