// Import Datasets
var brazilForests = ee.Image("projects/ee-celsojunior/assets/brazil_forest_pret_4Inv_v1"),
    managedLand = ee.Image("projects/ee-ipam/assets/Managed_Land_Para_Final_Raster"),
    prodesGreaterThan625ha = ee.Image("projects/ee-ipam/assets/REDD/prodes_brasil_2023");

///// 2017-2023 ///////////
// Pampa Biome Delimitation
var pampa = ee.FeatureCollection('projects/mapbiomas-workspace/AUXILIAR/biomas_IBGE_250mil')
  .filter(ee.Filter.eq('Bioma', 'Pampa'));
  
var brazilForests = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/UKPact_MRV/brazil_pret_vegetation_qcn_v2")
                    .unmask(0)
                    .remap([1, 2], [1, 1], 0)
                    .clip(pampa);
Map.addLayer(brazilForests, {}, "brazil_forests");

var prodesDeforestation = prodesGreaterThan625ha
                          .unmask(0)
                          .multiply(brazilForests)
                          .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
                          .clip(pampa);

// Carbon Map from FREL National
var totalCarbon = ee.Image('projects/ee-ipam/assets/IPAM/QCN/1_Asset_v0-2_img')
                  .select('TOTAL')
                  //.mosaic()
                  .unmask(0)
                  .multiply(brazilForests)
                  .clip(pampa);

///////////////////////////////////////////////////////////
//////////// Calculating GEE Emissions in CO2eq /////////////
///////////////////////////////////////////////////////////

function calculateCO2Emissions(year) {
  
  var regions = ee.FeatureCollection('projects/ee-ipam/assets/BR_UF_Biomas')
                .filter(ee.Filter.eq('Bioma', 'Pampa')); 
  
  /////// Deforestation emissions
  var deforestationMask = prodesDeforestation.eq(year);
  var deforestationCO2 = totalCarbon.multiply(deforestationMask);
  
  // Deforestation
  var emissionDefCO2 = deforestationCO2.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(44/12); // "44/12" - C to CO2
  
  var regionalEmissionDefCO2 = emissionDefCO2.reduceRegions({
    collection: regions,
    reducer: ee.Reducer.sum(), 
    scale: 30
  }).select(['.*'], null, false); // Exclude the .geo column

  Export.table.toDrive({
    collection: regionalEmissionDefCO2,
    folder:'Results_V1', 
    description: 'pam_emission_def_co2_' + year,
    fileFormat: 'CSV'
  });

  return year + 1; // Returns the next year
}

// Function to iterate through the years
function iterateYears(startYear, endYear) {
  if (startYear < endYear) {
    var nextYear = calculateCO2Emissions(startYear); 
    iterateYears(nextYear, endYear);
  }
}
// Calling the function to calculate CO2 emissions for the period from 2017 to 2023
iterateYears(2017, 2024); // The end year is exclusive, so this range covers 2017 to 2023.
