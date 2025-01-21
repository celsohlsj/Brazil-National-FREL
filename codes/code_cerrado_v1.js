// Import Datasets
var brazilForests = ee.Image("projects/ee-celsojunior/assets/brazil_forest_pret_4Inv_v1"),
    managedLand = ee.Image("projects/ee-ipam/assets/Managed_Land_Para_Final_Raster"),
    prodesGreaterThan625ha = ee.Image("projects/ee-ipam/assets/REDD/prodes_brasil_2023");

///// 2017-2023 ///////////
// Cerrado Biome Delimitation
var cerrado = ee.FeatureCollection('projects/mapbiomas-workspace/AUXILIAR/biomas_IBGE_250mil')
  .filter(ee.Filter.eq('Bioma', 'Cerrado'));

brazilForests = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/UKPact_MRV/brazil_pret_vegetation_qcn_v2")
                  .unmask(0)
                  .remap([1, 2], [1, 1], 0)
                  .clip(cerrado);

var prodesDeforestation = prodesGreaterThan625ha
                          .unmask(0)
                          .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
                          .clip(cerrado);

// Carbon Map from FREL National
var agb = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1')
          .select('cagb')
          .mosaic()
          .unmask(0)
          .multiply(brazilForests)
          .clip(cerrado);

var bgb = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1')
          .select('cbgb')
          .mosaic()
          .unmask(0)
          .multiply(brazilForests)
          .clip(cerrado);

var dw = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1')
          .select('cdw')
          .mosaic()
          .unmask(0)
          .multiply(brazilForests)
          .clip(cerrado);

var litter = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1')
              .select('clitter')
              .mosaic()
              .unmask(0)
              .multiply(brazilForests)
              .clip(cerrado);

var agbDwL = agb.add(dw).add(litter);
var totalCarbon = agb.add(bgb).add(dw).add(litter);

////////////////////////////////////////////////////////////
// Calculating GEE Emissions in CO2eq //////////////////////
///////////////////////////////////////////////////////////

function calculateCO2Emissions(year) {
  
  var regions = ee.FeatureCollection('projects/ee-ipam/assets/BR_UF_Biomas')
                .filter(ee.Filter.eq('Bioma', 'Cerrado')); 
  
  // Deforestation Emissions
  var deforestationMask = prodesDeforestation.eq(year);
  
  var deforestationCO2 = totalCarbon.multiply(deforestationMask);
  var deforestationCH4 = agbDwL.multiply(deforestationMask)
                                  .multiply(1 / 0.47)
                                  .multiply(0.379)
                                  .multiply(6.8)
                                  .multiply(0.001);
  var deforestationN2O = agbDwL.multiply(deforestationMask)
                                  .multiply(1 / 0.47)
                                  .multiply(0.379)
                                  .multiply(0.2)
                                  .multiply(0.001);

  // Export GEE emissions as Table (.csv)
  // Deforestation CO2 Emissions
  var emissionDefCO2 = deforestationCO2
                        .multiply(ee.Image.pixelArea().multiply(0.0001))
                        .multiply(44 / 12); // Conversion from C to CO2

  var regionalEmissionDefCO2 = emissionDefCO2.reduceRegions({
    collection: regions,
    reducer: ee.Reducer.sum(), 
    scale: 30
  }).select(['.*'], null, false); // Exclude the .geo column

  Export.table.toDrive({
    collection: regionalEmissionDefCO2,
    folder: 'Results_V1', 
    description: 'cerr_emission_def_co2_' + year,
    fileFormat: 'CSV'
  });

  // Deforestation CH4 Emissions
  var emissionDefCH4 = deforestationCH4
                        .multiply(ee.Image.pixelArea().multiply(0.0001))
                        .multiply(28); // CH4 to CO2 factor (IPCC, 2013 – AR5)

  var regionalEmissionDefCH4 = emissionDefCH4.reduceRegions({
    collection: regions,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false); // Exclude the .geo column

  Export.table.toDrive({
    collection: regionalEmissionDefCH4,
    folder: 'Results_V1', 
    description: 'cerr_emission_def_ch4_' + year,
    fileFormat: 'CSV'
  });

  // Deforestation N2O Emissions
  var emissionDefN2O = deforestationN2O
                        .multiply(ee.Image.pixelArea().multiply(0.0001))
                        .multiply(265); // N2O to CO2 factor (IPCC, 2013 – AR5)

  var regionalEmissionDefN2O = emissionDefN2O.reduceRegions({
    collection: regions,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false); // Exclude the .geo column

  Export.table.toDrive({
    collection: regionalEmissionDefN2O,
    folder: 'Results_V1', 
    description: 'cerr_emission_def_n2o_' + year,
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
iterateYears(2017, 2024); // The end year is exclusive, covering 2017 to 2023.