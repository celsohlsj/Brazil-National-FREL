// ============================================================
// BRAZIL NATIONAL FREL — Unified GEE Script (v1)
//
// Reference:
//   Silva-Junior, C. H. L. et al. (2026). Increased deforestation
//   and forest degradation jeopardize Brazil's REDD+ results in 2022.
//   Nature Communications.
//
// Description:
//   Calculates greenhouse gas emissions from deforestation and
//   forest degradation across all six Brazilian biomes using the
//   National FREL methodology. Exports one CSV per combination of
//   biome / disturbance type / gas / year.
//
// Export file naming convention:
//   {biome}_{emission}_{disturbance}_{gas}_{year}.csv
//   Example: amz_emission_fire_co2_2022.csv
//
// Biome codes:  amz | cerr | pan | pam | caa | ma
// Disturbances: def (deforestation) | fire | sl (selective logging)
// Gases:        co2 | ch4 | n2o
// ============================================================

// ====================================================================
//  CONFIGURATION — Edit only this section to change the analysis
// ====================================================================

var START_YEAR     = 2017;        // First year of analysis (inclusive)
var END_YEAR       = 2023;        // Last year of analysis  (inclusive)
var EXPORT_FOLDER  = 'Results_V1'; // Destination folder in Google Drive

// PRODES dataset encoding: pixel_value = year - 2000.
// Extend PRODES_END if a newer annual PRODES asset becomes available.
var PRODES_START   = 2016;
var PRODES_END     = 2023;

// Conversion factors — IPCC AR5 (do not change without updating methodology)
var C_TO_CO2       = 44 / 12;    // Carbon to CO2
var GWP_CH4        = 28;         // CH4 100-yr global warming potential
var GWP_N2O        = 265;        // N2O 100-yr global warming potential
var SPATIAL_SCALE  = 30;         // Pixel resolution (metres)

// ====================================================================
//  END OF CONFIGURATION
// ====================================================================

// ---------------------------------------------------------------------------
// Build PRODES remap arrays from configuration so the script adapts
// automatically when PRODES_START / PRODES_END are updated.
// ---------------------------------------------------------------------------
var PRODES_FROM = [], PRODES_TO = [];
for (var _y = PRODES_START; _y <= PRODES_END; _y++) {
  PRODES_FROM.push(_y - 2000); // encoded pixel value inside the GEE asset
  PRODES_TO.push(_y);          // actual calendar year
}

// =================== SHARED ASSETS ===================

var prodesGreaterThan625ha = ee.Image('projects/ee-ipam/assets/REDD/prodes_brasil_2023');
var prodesLessThan625ha    = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/yearly_deforestation_smaller_than_625ha_biome');
var managedLandAmazon      = ee.Image('projects/ee-ipam/assets/Managed_Land_Brazil').unmask(0);

// Forest vegetation mask (QCN v2) — shared across all biomes
var vegetationMask = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/UKPact_MRV/brazil_pret_vegetation_qcn_v2')
                       .unmask(0)
                       .remap([1, 2], [1, 1], 0);

var carbonStock = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1');
var biomesBound = ee.FeatureCollection('projects/mapbiomas-workspace/AUXILIAR/biomas_IBGE_250mil');
var statesFC    = ee.FeatureCollection('projects/ee-ipam/assets/BR_UF_Biomas');

// =================== SHARED EXPORT HELPER ===================
// Converts carbon density (tC/ha) to total CO2e (tonnes), aggregates
// by state × biome, and exports the result as CSV to Google Drive.

function exportEmission(image, regions, description) {
  var result = image
    .multiply(ee.Image.pixelArea().multiply(0.0001)) // m² to ha
    .reduceRegions({
      collection: regions,
      reducer: ee.Reducer.sum(),
      scale: SPATIAL_SCALE
    })
    .select(['.*'], null, false); // drop .geo column

  Export.table.toDrive({
    collection: result,
    folder: EXPORT_FOLDER,
    description: description,
    fileFormat: 'CSV'
  });
}

// ============================================================
//  AMAZON  |  prefix: amz
//
//  Disturbances : fire (CO2, CH4, N2O)
//                 selective logging / sl (CO2)
//                 deforestation / def (CO2, CH4, N2O)
//
//  Carbon stocks : agb, bgb, dw, litter
//                  QCN blended with EBA/INPE maps (30 m)
//                  Stocks updated annually: fire → sl → def
//
//  Combustion fraction : 0.368
//  CH4 / N2O base      : 1 / 0.47
// ============================================================

function processAmazon() {

  var biomeFC = biomesBound.filter(ee.Filter.eq('Bioma', 'Amazônia'));
  var regions = statesFC.filter(ee.Filter.eq('Bioma', 'Amazônia'));
  var prefix  = 'amz';

  var forests = vegetationMask.clip(biomeFC);
  var zeros   = ee.Image(0).clip(biomeFC);

  // PRODES: merge large (>625 ha) and small (<625 ha) deforestation patches
  var prodes625 = prodesGreaterThan625ha
    .unmask(0)
    .remap(PRODES_FROM, PRODES_TO, 0)
    .clip(biomeFC);

  var prodesDeforestation = prodes625
    .blend(prodesLessThan625ha.clip(biomeFC))
    .remap(PRODES_TO, PRODES_TO, 0) // identity remap to zero out non-year values
    .clip(biomeFC);

  // Carbon stocks: QCN blended with EBA/INPE high-resolution maps
  var agb1    = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_AB_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_AB_30m').gte(0));
  var bgb1    = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_BB_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_BB_30m').gte(0));
  var dw1     = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_DW_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_DW_30m').gte(0));
  var litter1 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_LI_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_LI_30m').gte(0));

  var agb    = carbonStock.select('cagb').mosaic().blend(agb1).multiply(forests).clip(biomeFC);
  var bgb    = carbonStock.select('cbgb').mosaic().blend(bgb1).multiply(forests).clip(biomeFC);
  var dw     = carbonStock.select('cdw').mosaic().blend(dw1).multiply(forests).clip(biomeFC);
  var litter = carbonStock.select('clitter').mosaic().blend(litter1).multiply(forests).clip(biomeFC);
  var agbDwL = agb.add(dw).add(litter);

  // Selective logging base layer: t0 = START_YEAR
  var slLayer = zeros.blend(
    ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_'
             + START_YEAR + '_cs_disordered')
      .multiply(forests)
      .clip(biomeFC)
  ).clip(biomeFC);

  function iterate(year) {
    if (year > END_YEAR) return;

    // ---- Fire ----
    var fireLayer = zeros.blend(
      ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_'
               + year + '_fire')
        .multiply(forests)
        .multiply(managedLandAmazon)
        .clip(biomeFC)
    );

    var fireCO2 = agbDwL.multiply(fireLayer).multiply(0.368);
    var fireCH4 = agbDwL.multiply(fireLayer).multiply(1 / 0.47).multiply(0.368).multiply(6.8).multiply(0.001);
    var fireN2O = agbDwL.multiply(fireLayer).multiply(1 / 0.47).multiply(0.368).multiply(0.2).multiply(0.001);

    // Update stocks after fire
    agb    = agb.subtract(agb.multiply(fireLayer).multiply(0.368));
    dw     = dw.subtract(dw.multiply(fireLayer).multiply(0.368));
    litter = litter.subtract(litter.multiply(fireLayer).multiply(0.368));

    exportEmission(fireCO2.multiply(C_TO_CO2), regions, prefix + '_emission_fire_co2_' + year);
    exportEmission(fireCH4.multiply(GWP_CH4),  regions, prefix + '_emission_fire_ch4_' + year);
    exportEmission(fireN2O.multiply(GWP_N2O),  regions, prefix + '_emission_fire_n2o_' + year);

    // ---- Selective Logging ----
    var slFactor = slLayer.remap(
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      [0, 0.29, 0.27, 0.26, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22]
    );
    var slCO2 = agb.multiply(slFactor);

    // Advance selective logging disturbance layer to next year
    var slNext = zeros.blend(
      ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_'
               + (year + 1) + '_cs_disordered')
        .unmask(0)
        .multiply(forests)
        .clip(biomeFC)
    );
    slLayer = slLayer.add(slNext).multiply(slNext).multiply(forests).clip(biomeFC);

    // Update stocks after selective logging
    agb    = agb.subtract(slCO2);
    agbDwL = agb.add(dw).add(litter);

    exportEmission(slCO2.multiply(C_TO_CO2), regions, prefix + '_emission_sl_co2_' + year);

    // ---- Deforestation ----
    var defMask = prodesDeforestation.eq(year);
    var defCO2  = agbDwL.add(bgb).multiply(defMask);
    var defCH4  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.368).multiply(6.8).multiply(0.001);
    var defN2O  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.368).multiply(0.2).multiply(0.001);

    // Update stocks after deforestation
    agbDwL = agbDwL.multiply(defMask.neq(1));
    agb    = agb.multiply(defMask.neq(1));
    bgb    = bgb.multiply(defMask.neq(1));

    exportEmission(defCO2.multiply(C_TO_CO2), regions, prefix + '_emission_def_co2_' + year);
    exportEmission(defCH4.multiply(GWP_CH4),  regions, prefix + '_emission_def_ch4_' + year);
    exportEmission(defN2O.multiply(GWP_N2O),  regions, prefix + '_emission_def_n2o_' + year);

    iterate(year + 1);
  }

  iterate(START_YEAR);
}

processAmazon();

// ============================================================
//  CERRADO  |  prefix: cerr
//
//  Disturbances : deforestation / def (CO2, CH4, N2O)
//
//  Carbon stocks : agb, bgb, dw, litter — QCN only (no EBA blend)
//
//  Combustion fraction : 0.379 (Cerrado-specific)
//  CH4 / N2O base      : 1 / 0.47
// ============================================================

function processCerrado() {

  var biomeFC = biomesBound.filter(ee.Filter.eq('Bioma', 'Cerrado'));
  var regions = statesFC.filter(ee.Filter.eq('Bioma', 'Cerrado'));
  var prefix  = 'cerr';

  var forests = vegetationMask.clip(biomeFC);

  var prodesDeforestation = prodesGreaterThan625ha
    .unmask(0)
    .remap(PRODES_FROM, PRODES_TO, 0)
    .clip(biomeFC);

  var agb    = carbonStock.select('cagb').mosaic().unmask(0).multiply(forests).clip(biomeFC);
  var bgb    = carbonStock.select('cbgb').mosaic().unmask(0).multiply(forests).clip(biomeFC);
  var dw     = carbonStock.select('cdw').mosaic().unmask(0).multiply(forests).clip(biomeFC);
  var litter = carbonStock.select('clitter').mosaic().unmask(0).multiply(forests).clip(biomeFC);

  var agbDwL      = agb.add(dw).add(litter);
  var totalCarbon = agb.add(bgb).add(dw).add(litter);

  function iterate(year) {
    if (year > END_YEAR) return;

    var defMask = prodesDeforestation.eq(year);
    var defCO2  = totalCarbon.multiply(defMask);
    var defCH4  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.379).multiply(6.8).multiply(0.001);
    var defN2O  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.379).multiply(0.2).multiply(0.001);

    exportEmission(defCO2.multiply(C_TO_CO2), regions, prefix + '_emission_def_co2_' + year);
    exportEmission(defCH4.multiply(GWP_CH4),  regions, prefix + '_emission_def_ch4_' + year);
    exportEmission(defN2O.multiply(GWP_N2O),  regions, prefix + '_emission_def_n2o_' + year);

    iterate(year + 1);
  }

  iterate(START_YEAR);
}

processCerrado();

// ============================================================
//  SIMPLE BIOMES — Pantanal | Pampa | Caatinga | Atlantic Forest
//
//  Disturbances : deforestation / def (CO2 only)
//
//  Carbon stocks : QCN band 'total' (agb + bgb + dw + litter
//                  pre-summed in the asset)
//
//  Forest mask applied to PRODES before remap (biome-specific
//  approach consistent with the original per-biome scripts)
//
//  Biome name        | prefix
//  ------------------|-------
//  Pantanal          | pan
//  Pampa             | pam
//  Caatinga          | caa
//  Mata Atlântica    | ma
// ============================================================

function processSimpleBiome(biomeName, prefix) {

  var biomeFC = biomesBound.filter(ee.Filter.eq('Bioma', biomeName));
  var regions = statesFC.filter(ee.Filter.eq('Bioma', biomeName));

  var forests = vegetationMask.clip(biomeFC);

  var prodesDeforestation = prodesGreaterThan625ha
    .unmask(0)
    .multiply(forests)          // apply forest mask before remap
    .remap(PRODES_FROM, PRODES_TO, 0)
    .clip(biomeFC);

  var totalCarbon = carbonStock.select('total').mosaic().unmask(0).multiply(forests).clip(biomeFC);

  function iterate(year) {
    if (year > END_YEAR) return;

    var defMask = prodesDeforestation.eq(year);
    var defCO2  = totalCarbon.multiply(defMask);

    exportEmission(defCO2.multiply(C_TO_CO2), regions, prefix + '_emission_def_co2_' + year);

    iterate(year + 1);
  }

  iterate(START_YEAR);
}

processSimpleBiome('Pantanal',       'pan');
processSimpleBiome('Pampa',          'pam');
processSimpleBiome('Caatinga',       'caa');
processSimpleBiome('Mata Atlântica', 'ma');
