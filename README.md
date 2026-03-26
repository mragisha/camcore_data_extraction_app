# Climate Data Extraction Tool

A RShiny application for extracting bioclimatic variables and elevation from WorldClim 2.1 climate data based on geographic coordinates.

## Overview

This tool allows researchers and analysts to extract 19 bioclimatic variables plus elevation for any location on Earth using historical data (1981-2024) or future climate projections (2021-2100) under different emissions scenarios.

Future climate data is streamed directly from the [WorldClim / UC Davis geodata server](https://geodata.ucdavis.edu) — no large raster files need to be stored locally.

---

## Features

- **Multiple input methods** — manual coordinate entry or CSV file upload
- **Historical data (1981-2024)** — loaded from local files (EC-Earth3-Veg, fixed 10 arc-min resolution)
- **Future projections (2021-2100)** — downloaded on demand via the `geodata` package
- **13 CMIP6 models** available for future scenarios
- **4 SSP emissions scenarios** for future projections
- **Selectable resolution** for future data (2.5, 5, or 10 arc-minutes)
- **Elevation extraction** alongside bioclimatic variables
- **Interactive map** showing extraction locations
- **CSV download** of all results

---

## Installation

### Prerequisites

- **R** version 4.0 or higher
- **RStudio** (recommended)
- Internet connection (required for future climate data and elevation downloads)

### Install Required R Packages

```r
install.packages(c("shiny", "dplyr", "terra", "geodata", "DT", "leaflet"))
```

---

## Project Structure

```
camcore_data_extraction_app/
├── app.R                   # Main Shiny application
├── README.md               # This file
└── data/
    └── EC-Earth3-Veg/
        └── WorldClim_Data_1981_2024/
            ├── BIO1_WORLD_TCgrid__CHIRPSppt_1981_2024.tif
            ├── BIO2_WORLD_TCgrid__CHIRPSppt_1981_2024.tif
            └── ... (BIO3 through BIO19)
```

> Future climate files and elevation are downloaded automatically on first use and cached locally. No manual download is needed.

---

## How to Run

1. Open RStudio and set the working directory to the project folder:
   ```r
   setwd("path/to/camcore_data_extraction_app")
   ```
2. Run the app:
   ```r
   shiny::runApp("app.R")
   ```
3. The app opens in your default web browser.

---

## Step-by-Step Usage

### Step 1 — Provide Coordinates

Choose how to enter your locations:

**Option A: Manual entry**
1. Select **"Enter manually"**
2. Type a latitude value (between -90 and 90)
3. Type a longitude value (between -180 and 180)
4. Click **Add** — the coordinate appears in the table below
5. Repeat for as many locations as needed
6. Use **Clear All** to start over

**Option B: Upload a CSV file**
1. Select **"Upload CSV file"**
2. Your CSV must have at least two columns:
   - One starting with `lat` (e.g., `lat`, `latitude`, `lat_dd`)
   - One starting with `lon` (e.g., `lon`, `longitude`, `lon_dd`)
3. Any additional columns (e.g., site ID, species name) are preserved in the output
4. Click **Browse** and select your file

---

### Step 2 — Select Climate Data

**Time Period** — choose one:
| Option | Period | Data source |
|---|---|---|
| Historical | 1981–2024 | Local files (EC-Earth3-Veg) |
| Near Future | 2021–2040 | Downloaded via geodata |
| Mid Future | 2041–2060 | Downloaded via geodata |
| Late Future | 2061–2080 | Downloaded via geodata |
| End Century | 2081–2100 | Downloaded via geodata |

**For future periods, two additional options appear:**

**Model** — select one of 13 CMIP6 models:
- ACCESS-CM2, ACCESS-ESM1-5, BCC-CSM2-MR, CanESM5
- CNRM-CM6-1, CNRM-ESM2-1, EC-Earth3-Veg, GFDL-ESM4
- INM-CM5-0, IPSL-CM6A-LR, MIROC6, MPI-ESM1-2-HR, MRI-ESM2-0

**Resolution** — spatial resolution of the output (default: 5 arc-minutes):
| Resolution | Approx. grid size | File size | Note |
|---|---|---|---|
| 2.5 arc-minutes | ~5 km | Large | Not available for all models |
| 5 arc-minutes | ~10 km | Medium | Recommended default |
| 10 arc-minutes | ~20 km | Small | Fastest download |

> If a model is not available at 2.5 arc-minutes, the app will show an error suggesting you switch to 5 or 10 arc-minutes.

**SSP Scenario** (future only) — select one:
| Scenario | Description |
|---|---|
| SSP1-2.6 | Low emissions — sustainable development pathway |
| SSP2-4.5 | Medium emissions — middle-of-the-road pathway |
| SSP3-7.0 | High emissions — regional rivalry pathway |
| SSP5-8.5 | Very high emissions — fossil-fueled development |

---

### Step 3 — Extract Bioclimatic Variables

Click **Extract Bio Variables**.

- A progress bar tracks extraction across all 19 variables plus elevation
- On the first run for a new model/scenario/resolution combination, the raster file is downloaded from WorldClim (~30–50 MB) and cached for future use
- Subsequent runs with the same selection load instantly from cache

---

### Step 4 — Review and Download Results

Once extraction is complete:
1. An **interactive map** shows all your locations (blue = data extracted, red = no data / ocean)
2. Click any marker to see its coordinates, elevation, and extraction status
3. A **data preview table** shows all extracted values
4. Click **Download CSV** to save the full results

---

## Output Format

The downloaded CSV includes all columns from your input file (if uploaded) plus:

| Column | Description |
|---|---|
| id | Auto-generated site ID (Site_1, Site_2, ...) — only added if your CSV had no ID column |
| lat | Latitude |
| lon | Longitude |
| elevation | Elevation in metres (from WorldClim) |
| bio1–bio19 | 19 bioclimatic variables (see table below) |

> Rows where all bio variables are NA (e.g., ocean or outside raster extent) are automatically removed from the output.

---

## Bioclimatic Variables

| Variable | Description | Units |
|---|---|---|
| bio1 | Annual Mean Temperature | °C |
| bio2 | Mean Diurnal Range | °C |
| bio3 | Isothermality (bio2/bio7 × 100) | % |
| bio4 | Temperature Seasonality | °C × 100 |
| bio5 | Max Temperature of Warmest Month | °C |
| bio6 | Min Temperature of Coldest Month | °C |
| bio7 | Temperature Annual Range (bio5–bio6) | °C |
| bio8 | Mean Temperature of Wettest Quarter | °C |
| bio9 | Mean Temperature of Driest Quarter | °C |
| bio10 | Mean Temperature of Warmest Quarter | °C |
| bio11 | Mean Temperature of Coldest Quarter | °C |
| bio12 | Annual Precipitation | mm |
| bio13 | Precipitation of Wettest Month | mm |
| bio14 | Precipitation of Driest Month | mm |
| bio15 | Precipitation Seasonality (CV) | % |
| bio16 | Precipitation of Wettest Quarter | mm |
| bio17 | Precipitation of Driest Quarter | mm |
| bio18 | Precipitation of Warmest Quarter | mm |
| bio19 | Precipitation of Coldest Quarter | mm |
