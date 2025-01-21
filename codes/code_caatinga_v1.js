// Import Datasets
var brazilForests = ee.Image("projects/ee-celsojunior/assets/brazil_forest_pret_4Inv_v1"),
    managedLand = ee.Image("projects/ee-ipam/assets/Managed_Land_Para_Final_Raster"),
    prodesGreaterThan625ha = ee.Image("projects/ee-ipam/assets/REDD/prodes_brasil_2023");

// Caatinga Biome Delimitation
var caatinga = ee.FeatureCollection('projects/mapbiomas-workspace/AUXILIAR/biomas_IBGE_250mil')
  .filter(ee.Filter.eq('Bioma', 'Caatinga'));

brazilForests = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/UKPact_MRV/brazil_pret_vegetation_qcn_v2")
                  .unmask(0)
                  .remap([1, 2], [1, 1], 0)
                  .clip(caatinga);

var prodesDeforestation = prodesGreaterThan625ha
                            .unmask(0)
                            .multiply(brazilForests)
                            .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
                            .clip(caatinga);

// Carbon Map from FREL National
var totalCarbon = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1')
                  .select('total')
                  .mosaic()
                  .unmask(0)
                  .multiply(brazilForests)
                  .clip(caatinga);

////////////////////////////////////////////////////////////
////////// Calculating GEE Emissions in CO2eq //////////////
////////////////////////////////////////////////////////////

function calculateCO2Emissions(year) {
  var regions = ee.FeatureCollection('projects/ee-ipam/assets/BR_UF_Biomas')
                .filter(ee.Filter.eq('Bioma', 'Caatinga')); 
  
  // Deforestation Emissions
  var deforestationMask = prodesDeforestation.eq(year);
  var deforestationCO2 = totalCarbon.multiply(deforestationMask);
  
  // Calculate CO2 Emissions from Deforestation
  var emissionDefCO2 = deforestationCO2
                        .multiply(ee.Image.pixelArea().multiply(0.0001))
                        .multiply(44 / 12); // Conversion from C to CO2
  
  // Summarize Emissions by Region
  var regionalEmissionDefCO2 = emissionDefCO2.reduceRegions({
    collection: regions,
    reducer: ee.Reducer.sum(), 
    scale: 30
  }).select(['.*'], null, false); // Exclude the .geo column

  // Export Deforestation CO2 Emissions to Google Drive
  Export.table.toDrive({
    collection: regionalEmissionDefCO2,
    folder: 'Results_V1', 
    description: 'caa_emission_def_co2_' + year,
    fileFormat: 'CSV'
  });

  return year + 1; // Returns the next year
}

// Function to Iterate Through the Years
function iterateYears(startYear, endYear) {
  if (startYear < endYear) {
    var nextYear = calculateCO2Emissions(startYear); 
    iterateYears(nextYear, endYear);
  }
}

// Calling the Function to Calculate CO2 Emissions for the Period from 2017 to 2023
iterateYears(2017, 2024); // The end year is exclusive, covering 2017 to 2023