![licence](https://img.shields.io/badge/Licence-GPL--4-blue.svg)
![Github](https://img.shields.io/badge/Github-1.0.0-green.svg)

# **Increased deforestation and forest degradation in 2022 jeopardize Brazil’s REDD+ results**

## Code for Analysis of Emissions in Brazil's National FREL
This repository contains the code used to replicate the method of Brazil's National Forest Reference Emission Level (FREL) modified and analyze greenhouse gas emissions from deforestation and forest degradation for the years 2022 and 2023. The code supports the study:

## Objective

The primary goal is to estimate carbon emissions related to deforestation and forest degradation (fire and unplanned selective logging) and assess their impact on Brazil's REDD+ results using Brazil's National FREL methodology.

## Data Used

The following datasets were used:

- [**Deforestation:**](https://terrabrasilis.dpi.inpe.br/downloads/) Data from PRODES (INPE) for annual monitoring of native vegetation suppression.
- [**Forest Degradation:**](https://terrabrasilis.dpi.inpe.br/downloads/) Data from DETER (INPE) for daily monitoring.
- **Carbon Stock:** Map from the EBA/INPE Project (Amazon biome) and the 4th National Greenhouse Gas Communication (other biomes).
- **Official References:** Brazil's National FREL documents.


### How to use
1. [Create an account](https://signup.earthengine.google.com/) in the Google Earth Engine platform.

2. Download or clone this repository to your local workspace .EE.

## Repository Structure

- `🗃️data/`: Contains input files (Google Earth Engine Assets).
- `🛢codes/`: Includes the main scripts for analysis, including data processing in Google Earth Engine.
- `🔎results/`: Stores generated outputs such as charts.

## Requirements

- **Google Earth Engine:** Scripts are executed in this cloud-based geospatial analysis platform.

### GitClone - Earth Engine (.js)
- **User with access to the repository* can add it to the Code Editor Earth Engine using:
  Accept Repository .EE (Spatial analyses)
  Clone the gitRe by running the following command in a terminal: git clone

### Reporting Issues
For clarification or an issue/bug report, please write to <celso.junior@ipam.org.br> and/or <edriano.souza@ipam.org.br> 
    
