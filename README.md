![licence](https://img.shields.io/badge/Licence-GPL--4-blue.svg)
![Github](https://img.shields.io/badge/Github-1.0.0-green.svg)

# Code for Analysis of Emissions in Brazil's National FREL

This repository contains the code used to replicate the method of Brazil's National Forest Reference Emission Level (FREL) and analyze greenhouse gas emissions from deforestation and forest degradation for the years 2022 and 2023. The code supports the study:

**"Increased deforestation and forest degradation in 2022 jeopardize Brazil’s REDD+ results"**

## Objective

The primary goal is to estimate carbon emissions related to deforestation and forest degradation (fire and unplanned selective logging) and assess their impact on Brazil's REDD+ results using Brazil's National FREL methodology.

## Data Used

The following datasets were used:

- **Deforestation:** Data from PRODES (INPE) for annual monitoring of native vegetation suppression.
- **Forest Degradation:** Data from DETER (INPE) for daily monitoring.
- **Carbon Stock:** Map from the EBA/INPE Project (Amazon biome) and the 4th National Greenhouse Gas Communication (other biomes).
- **Official References:** Brazil's National FREL documents.

## Repository Structure

- `data/`: Contains example input files (vector and raster formats).
- `scripts/`: Includes the main scripts for analysis, including data processing in Google Earth Engine.
- `results/`: Stores generated outputs such as maps and emission charts.

## Key Features

1. Estimates emissions from deforestation and degradation by biome.
2. Adjusts results to align with Brazil's official FREL values.
3. Generates maps and charts of annual emissions.
4. Simulates a modified FREL, incorporating emissions from fires outside managed forest lands and geometric selective logging.

## Requirements

- **Google Earth Engine:** Scripts are executed in this cloud-based geospatial analysis platform.
