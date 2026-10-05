# Wildfire Risk Analysis (Alpes-Maritimes, Summer 2023)

Analysis of wildfire occurrences and meteorological risk factors across 8 communes in the Alpes-Maritimes region (Côte d'Azur) during summer 2023. The project combines historical fire records with weather observations to evaluate risk factors, train a classification model, and map spatial hazard levels.

## Overview
This repository contains the R scripts, dataset, and generated figures for analyzing local wildfire drivers. The analysis is structured into three main parts:
1. Exploratory analysis of weather metrics (temperature, wind speed, Fire Weather Index) relative to fire events.
2. Wildfire risk classification using a Random Forest model in `tidymodels`.
3. Spatial mapping of high-risk communes using `leaflet`.

## Data Sources
- **Prométhée Fire Database:** Historical wildfire occurrences recorded in southeastern France during summer 2023.
- **Météo-France (SAFRAN):** Daily meteorological data per commune, including maximum temperature (°C), maximum wind speed (km/h), and calculated Fire Weather Index (FWI).

## Methodology
- Data cleaning and integration of weather logs with fire records (`tidyverse`).
- FWI distribution analysis and timeline plotting of daily temperature against fire dates (`ggplot2`).
- Random Forest model training (`ranger`, `vip`) to identify critical risk conditions (FWI >= 30) and extract variable importance ratings.
- GIS visualization with dynamic weather popups (`leaflet`, `mapview`).

## Main Findings
- Coastal communes (Cannes, Menton, Valbonne) recorded the highest concentration of critical risk days (FWI >= 30), mostly driven by higher daily peak temperatures.
- Higher-altitude inland communes (Tende, Vence) maintained moderate to low hazard levels across the summer period.
- Feature importance analysis confirmed daily maximum temperature and the FWI index as the primary predictors of wildfire danger in the study area.

## Visualizations Included
- `wildfire_risk_map.png`: Spatial hazard ratings and commune breakdown.
- `fwi_wildfire_distribution.png`: FWI value ranges across the 8 communes.
- `temperature_fire_timeline_faceted.png`: Daily maximum temperature timeline with fire event indicators.

## How to Run
```R
# Clone the repository
git clone [https://github.com/thaylamaciel/project_eco_analysis.git](https://github.com/thaylamaciel/project_eco_analysis.git)

# Execute the complete pipeline in R / RStudio
source("script.R")
