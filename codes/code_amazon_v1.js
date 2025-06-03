// Import Datasets
var prodesGreaterThan625ha = ee.Image("projects/ee-ipam/assets/REDD/prodes_brasil_2023"),
    prodesLessThan625ha = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/PRODES/yearly_deforestation_smaller_than_625ha_biome");

var managedLand = ee.Image("projects/ee-ipam/assets/Managed_Land_Brazil").unmask(0);

var amazonia = ee.FeatureCollection('projects/mapbiomas-workspace/AUXILIAR/biomas_IBGE_250mil')
                .filter(ee.Filter.eq('Bioma', 'Amazônia'));

var brazilForests = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/UKPact_MRV/brazil_pret_vegetation_qcn_v2")
                    .unmask(0)
                    .remap([1, 2], [1, 1], 0)
                    .clip(amazonia);

// Filtering PRODES for forest areas (according to the 4th National GEE Inventory)
var mask = ee.Image(0).clip(amazonia);

prodesGreaterThan625ha = prodesGreaterThan625ha
                            .unmask(0)
                            .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
                            .clip(amazonia);
                      
prodesLessThan625ha = prodesLessThan625ha
                        .clip(amazonia);

var prodesDeforestation = prodesGreaterThan625ha
                            .blend(prodesLessThan625ha)
                            .remap([2016,2017,2018,2019,2020,2021,2022,2023], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
                            .clip(amazonia);

Map.addLayer(prodesDeforestation, {}, "prodesDeforestation"); 

// Carbon Map from FREL National (Amazon EBA/INPE Map)
var agb1 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_AB_30m');
agb1 = agb1.updateMask(agb1.gte(0));

var bgb1 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_BB_30m');
bgb1 = bgb1.updateMask(bgb1.gte(0));

var dw1 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_DW_30m');
dw1 = dw1.updateMask(dw1.gte(0));

var litter1 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_LI_30m');
litter1 = litter1.updateMask(litter1.gte(0));

// Carbon Map from FREL National
var agb = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1').select('cagb').mosaic()
          .blend(agb1)
          .multiply(brazilForests)
          .clip(amazonia);
    
var bgb = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1').select('cbgb').mosaic()
          .blend(bgb1)
          .multiply(brazilForests)
          .clip(amazonia);
    
var dw = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1').select('cdw').mosaic()
          .blend(dw1)
          .multiply(brazilForests)
          .clip(amazonia);
    
var litter = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1').select('clitter').mosaic()
          .blend(litter1)
          .multiply(brazilForests)
          .clip(amazonia);

var agbDwL = agb.add(dw).add(litter);

Map.addLayer(agb, {}, "agb_initial");
Map.addLayer(agbDwL, {}, "agbDwL_initial");

////////////////////////////////////////////////////////////
/// Calculating GEE Emissions in CO2eq /////////////////////
////////////////////////////////////////////////////////////

// Selective Logging t0 (2017)
var selectiveLoggingYear = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_2017_cs_disordered")
                          .multiply(brazilForests)
                          .clip(amazonia);
selectiveLoggingYear = mask.blend(selectiveLoggingYear).clip(amazonia);

Map.addLayer(selectiveLoggingYear, {}, "selectiveLoggingYear_2017");

function calculateCO2Emissions(year) {
  var aoi = ee.FeatureCollection('projects/ee-ipam/assets/BR_UF_Biomas')
                    .filter(ee.Filter.eq('Bioma', 'Amazônia'));
  
  // Fire Emissions
  var fireYear = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_' + year + '_fire')
                  .multiply(brazilForests)
                  .multiply(managedLand)
                  .clip(amazonia);
  fireYear = mask.blend(fireYear);
      
  var fireCO2 = agbDwL.multiply(fireYear).multiply(0.368);
  var fireCH4 = agbDwL.multiply(fireYear).multiply(1/0.47).multiply(0.368).multiply(6.8).multiply(0.001);
  var fireN2O = agbDwL.multiply(fireYear).multiply(1/0.47).multiply(0.368).multiply(0.2).multiply(0.001);
  
  // Updating carbon stock (Fire)
    agb = agb.subtract(agb.multiply(fireYear).multiply(0.368));
    dw = dw.subtract(dw.multiply(fireYear).multiply(0.368));
    litter = litter.subtract(litter.multiply(fireYear).multiply(0.368));
    
  // Selective Logging Emissions
  var slFactorYear = selectiveLoggingYear.remap([0,1,2,3,4,5,6,7,8,9,10], [0,0.29,0.27,0.26,0.22,0.22,0.22,0.22,0.22,0.22,0.22]);
  
  var slCO2 = agb.multiply(slFactorYear);
  var selectiveLoggingYear2 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_' + (year + 1) + '_cs_disordered')
      .unmask(0)
      .multiply(brazilForests)
      .clip(amazonia);
  selectiveLoggingYear2 = mask.blend(selectiveLoggingYear2);
  
  selectiveLoggingYear = selectiveLoggingYear.add(selectiveLoggingYear2).multiply(selectiveLoggingYear2).multiply(brazilForests).clip(amazonia);
  
  // Updating carbon stock (Selective Logging)
    agb = agb.subtract(slCO2);
    agbDwL = agb.add(dw).add(litter);
  
  // Deforestation Emissions
  var deforestationYear = prodesDeforestation.eq(year);
  
  var total = agbDwL.add(bgb);
  
  var defCO2 = total.multiply(deforestationYear);
  var defCH4 = agbDwL.multiply(deforestationYear).multiply(1/0.47).multiply(0.368).multiply(6.8).multiply(0.001);
  var defN2O = agbDwL.multiply(deforestationYear).multiply(1/0.47).multiply(0.368).multiply(0.2).multiply(0.001);
  
  // Updating carbon stock (Deforestation)
  agbDwL = agbDwL.multiply(deforestationYear.neq(1));
  agb = agb.multiply(deforestationYear.neq(1));
  bgb = bgb.multiply(deforestationYear.neq(1));

  // Export GEE Emissions as Table (.csv)
  // Fire
  var emissionFireCO2 = fireCO2.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(44/12); // "44/12" - C to CO2
  var emissionFireCH4 = fireCH4.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(28); // 28 - CH4 to CO2 factor (IPCC, 2013 – AR5)
  var emissionFireN2O = fireN2O.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(265); // 265 - N2O to CO2 factor (IPCC, 2013 – AR5)
  
  var ufEmissionFireCO2 = emissionFireCO2.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionFireCO2,
    folder: 'Results_V1', 
    description: 'amz_emission_fire_co2_' + year,
    fileFormat: 'CSV'
  });
  
  var ufEmissionFireCH4 = emissionFireCH4.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionFireCH4,
    folder: 'Results_V1', 
    description: 'amz_emission_fire_ch4_' + year,
    fileFormat: 'CSV'
  });
  
  var ufEmissionFireN2O = emissionFireN2O.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionFireN2O,
    folder: 'Results_V1', 
    description: 'amz_emission_fire_n2o_' + year,
    fileFormat: 'CSV'
  });
  
  // Selective Logging
  var emissionSlCO2 = slCO2.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(44/12); // "44/12" - C to CO2
  
  var ufEmissionSlCO2 = emissionSlCO2.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionSlCO2,
    folder: 'Results_V1', 
    description: 'amz_emission_sl_co2_' + year,
    fileFormat: 'CSV'
  });
   
  // Deforestation
  var emissionDefCO2 = defCO2.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(44/12); // "44/12" - C to CO2
  var emissionDefCH4 = defCH4.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(28); // 28 - CH4 to CO2 factor (IPCC, 2013 – AR5)
  var emissionDefN2O = defN2O.multiply(ee.Image.pixelArea().multiply(0.0001)).multiply(265); // 265 - N2O to CO2 factor (IPCC, 2013 – AR5)
  
  var ufEmissionDefCO2 = emissionDefCO2.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionDefCO2,
    folder: 'Results_V1', 
    description: 'amz_emission_def_co2_' + year,
    fileFormat: 'CSV'
  });
  
  var ufEmissionDefCH4 = emissionDefCH4.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionDefCH4,
    folder: 'Results_V1', 
    description: 'amz_emission_def_ch4_' + year,
    fileFormat: 'CSV'
  });
  
  var ufEmissionDefN2O = emissionDefN2O.reduceRegions({
    collection: aoi,
    reducer: ee.Reducer.sum(),
    scale: 30
  }).select(['.*'], null, false);
  Export.table.toDrive({
    collection: ufEmissionDefN2O,
    folder: 'Results_V1', 
    description: 'amz_emission_def_n2o_' + year,
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
