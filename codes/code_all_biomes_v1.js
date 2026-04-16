// ============================================================
// FREL Nacional do Brasil — Script GEE Unificado (v1)
// 6 Biomas: Amazônia, Cerrado, Pantanal, Pampa, Caatinga,
//           Mata Atlântica
// Saídas por: bioma / tipo_distúrbio / gás / ano (2017–2023)
//
// Nomenclatura dos arquivos exportados (CSV):
//   {bioma}_emission_{disturbio}_{gas}_{ano}.csv
//   Ex.: amz_emission_fire_co2_2022.csv
//
// Referência: Silva-Junior et al. (2025) Nature Climate Change
// ============================================================

// =================== DATASETS COMPARTILHADOS ===================

var prodesGreaterThan625ha = ee.Image("projects/ee-ipam/assets/REDD/prodes_brasil_2023");
var prodesLessThan625ha    = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/PRODES/yearly_deforestation_smaller_than_625ha_biome");

// Máscara de terra manejada — utilizada apenas na Amazônia (fogo)
var managedLandAmazon = ee.Image("projects/ee-ipam/assets/Managed_Land_Brazil").unmask(0);

// Máscara de vegetação florestal (QCN v2) — compartilhada entre todos os biomas
var vegetationRaw = ee.Image("projects/ee-ipam/assets/CCAL/DATASETS/UKPact_MRV/brazil_pret_vegetation_qcn_v2")
                      .unmask(0)
                      .remap([1, 2], [1, 1], 0);

var qcn       = ee.ImageCollection('projects/mapbiomas-workspace/SEEG/2022/QCN/QCN_30m_BR_v2_0_1');
var biomesFC  = ee.FeatureCollection('projects/mapbiomas-workspace/AUXILIAR/biomas_IBGE_250mil');
var regionsFC = ee.FeatureCollection('projects/ee-ipam/assets/BR_UF_Biomas');

// Fatores de conversão (IPCC AR5)
var C_TO_CO2 = 44 / 12; // carbono → CO₂
var GWP_CH4  = 28;       // CH₄ → CO₂e (GWP 100 anos)
var GWP_N2O  = 265;      // N₂O → CO₂e (GWP 100 anos)

var SCALE  = 30;         // resolução espacial (metros)
var FOLDER = 'Results_V1';

// =================== FUNÇÃO AUXILIAR DE EXPORTAÇÃO ===================
// Converte de tC/ha para tCO₂e totais, agrega por estado×bioma e
// exporta como CSV para o Google Drive.

function exportEmission(image, regions, description) {
  var result = image
    .multiply(ee.Image.pixelArea().multiply(0.0001)) // m² → ha
    .reduceRegions({
      collection: regions,
      reducer: ee.Reducer.sum(),
      scale: SCALE
    })
    .select(['.*'], null, false); // exclui coluna .geo

  Export.table.toDrive({
    collection: result,
    folder: FOLDER,
    description: description,
    fileFormat: 'CSV'
  });
}

// ============================================================
// AMAZÔNIA  (prefixo: amz)
//
// Distúrbios e gases exportados:
//   fogo              → CO₂, CH₄, N₂O
//   exploração selet. → CO₂
//   desmatamento      → CO₂, CH₄, N₂O
//
// Carbono: agb + bgb + dw + litter
//          QCN blendado com mapa EBA/INPE (resolução 30 m)
// Estoques atualizados a cada ano (fogo → ES → desmat.)
// Fração de combustão: 0.368 | base CH₄/N₂O: 1/0.47
// ============================================================

function processAmazonia() {

  var biomeFC = biomesFC.filter(ee.Filter.eq('Bioma', 'Amazônia'));
  var regions = regionsFC.filter(ee.Filter.eq('Bioma', 'Amazônia'));
  var prefix  = 'amz';

  var brazilForests = vegetationRaw.clip(biomeFC);
  var mask          = ee.Image(0).clip(biomeFC);

  // PRODES: combina desmatamentos >625 ha e <625 ha
  var prodes625 = prodesGreaterThan625ha
    .unmask(0)
    .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
    .clip(biomeFC);

  var prodesDeforestation = prodes625
    .blend(prodesLessThan625ha.clip(biomeFC))
    .remap([2016,2017,2018,2019,2020,2021,2022,2023], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
    .clip(biomeFC);

  // Estoques de carbono: QCN blendado com EBA/INPE
  var agb1    = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_AB_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_AB_30m').gte(0));
  var bgb1    = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_BB_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_BB_30m').gte(0));
  var dw1     = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_DW_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_DW_30m').gte(0));
  var litter1 = ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_LI_30m')
                  .updateMask(ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/FREL/EBA_LI_30m').gte(0));

  var agb    = qcn.select('cagb').mosaic().blend(agb1).multiply(brazilForests).clip(biomeFC);
  var bgb    = qcn.select('cbgb').mosaic().blend(bgb1).multiply(brazilForests).clip(biomeFC);
  var dw     = qcn.select('cdw').mosaic().blend(dw1).multiply(brazilForests).clip(biomeFC);
  var litter = qcn.select('clitter').mosaic().blend(litter1).multiply(brazilForests).clip(biomeFC);
  var agbDwL = agb.add(dw).add(litter);

  // Exploração seletiva — ano-base t₀ = 2017
  var slYear = mask.blend(
    ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_2017_cs_disordered')
      .multiply(brazilForests)
      .clip(biomeFC)
  ).clip(biomeFC);

  function iterate(year) {
    if (year >= 2024) return;

    // ---- Fogo ----
    var fireImg = mask.blend(
      ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_' + year + '_fire')
        .multiply(brazilForests)
        .multiply(managedLandAmazon)
        .clip(biomeFC)
    );

    var fireCO2 = agbDwL.multiply(fireImg).multiply(0.368);
    var fireCH4 = agbDwL.multiply(fireImg).multiply(1 / 0.47).multiply(0.368).multiply(6.8).multiply(0.001);
    var fireN2O = agbDwL.multiply(fireImg).multiply(1 / 0.47).multiply(0.368).multiply(0.2).multiply(0.001);

    // Atualiza estoques após fogo
    agb    = agb.subtract(agb.multiply(fireImg).multiply(0.368));
    dw     = dw.subtract(dw.multiply(fireImg).multiply(0.368));
    litter = litter.subtract(litter.multiply(fireImg).multiply(0.368));

    exportEmission(fireCO2.multiply(C_TO_CO2), regions, prefix + '_emission_fire_co2_' + year);
    exportEmission(fireCH4.multiply(GWP_CH4),  regions, prefix + '_emission_fire_ch4_' + year);
    exportEmission(fireN2O.multiply(GWP_N2O),  regions, prefix + '_emission_fire_n2o_' + year);

    // ---- Exploração Seletiva ----
    var slFactor = slYear.remap(
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      [0, 0.29, 0.27, 0.26, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22]
    );
    var slCO2 = agb.multiply(slFactor);

    // Avança mapa de distúrbio seletivo para o próximo ano
    var slNext = mask.blend(
      ee.Image('projects/ee-ipam/assets/CCAL/DATASETS/PRODES/PRODES_ANO_CIVIL/DeterAnoProdes_' + (year + 1) + '_cs_disordered')
        .unmask(0)
        .multiply(brazilForests)
        .clip(biomeFC)
    );
    slYear = slYear.add(slNext).multiply(slNext).multiply(brazilForests).clip(biomeFC);

    // Atualiza estoques após exploração seletiva
    agb    = agb.subtract(slCO2);
    agbDwL = agb.add(dw).add(litter);

    exportEmission(slCO2.multiply(C_TO_CO2), regions, prefix + '_emission_sl_co2_' + year);

    // ---- Desmatamento ----
    var defMask = prodesDeforestation.eq(year);
    var defCO2  = agbDwL.add(bgb).multiply(defMask);
    var defCH4  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.368).multiply(6.8).multiply(0.001);
    var defN2O  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.368).multiply(0.2).multiply(0.001);

    // Atualiza estoques após desmatamento
    agbDwL = agbDwL.multiply(defMask.neq(1));
    agb    = agb.multiply(defMask.neq(1));
    bgb    = bgb.multiply(defMask.neq(1));

    exportEmission(defCO2.multiply(C_TO_CO2), regions, prefix + '_emission_def_co2_' + year);
    exportEmission(defCH4.multiply(GWP_CH4),  regions, prefix + '_emission_def_ch4_' + year);
    exportEmission(defN2O.multiply(GWP_N2O),  regions, prefix + '_emission_def_n2o_' + year);

    iterate(year + 1);
  }

  iterate(2017);
}

processAmazonia();

// ============================================================
// CERRADO  (prefixo: cerr)
//
// Distúrbios e gases exportados:
//   desmatamento → CO₂, CH₄, N₂O
//
// Carbono: agb + bgb + dw + litter — QCN (sem blend EBA)
// Fração de combustão: 0.379 (específico para o Cerrado)
// ============================================================

function processCerrado() {

  var biomeFC = biomesFC.filter(ee.Filter.eq('Bioma', 'Cerrado'));
  var regions = regionsFC.filter(ee.Filter.eq('Bioma', 'Cerrado'));
  var prefix  = 'cerr';

  var brazilForests = vegetationRaw.clip(biomeFC);

  var prodesDeforestation = prodesGreaterThan625ha
    .unmask(0)
    .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
    .clip(biomeFC);

  var agb    = qcn.select('cagb').mosaic().unmask(0).multiply(brazilForests).clip(biomeFC);
  var bgb    = qcn.select('cbgb').mosaic().unmask(0).multiply(brazilForests).clip(biomeFC);
  var dw     = qcn.select('cdw').mosaic().unmask(0).multiply(brazilForests).clip(biomeFC);
  var litter = qcn.select('clitter').mosaic().unmask(0).multiply(brazilForests).clip(biomeFC);

  var agbDwL      = agb.add(dw).add(litter);
  var totalCarbon = agb.add(bgb).add(dw).add(litter);

  function iterate(year) {
    if (year >= 2024) return;

    var defMask = prodesDeforestation.eq(year);
    var defCO2  = totalCarbon.multiply(defMask);
    var defCH4  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.379).multiply(6.8).multiply(0.001);
    var defN2O  = agbDwL.multiply(defMask).multiply(1 / 0.47).multiply(0.379).multiply(0.2).multiply(0.001);

    exportEmission(defCO2.multiply(C_TO_CO2), regions, prefix + '_emission_def_co2_' + year);
    exportEmission(defCH4.multiply(GWP_CH4),  regions, prefix + '_emission_def_ch4_' + year);
    exportEmission(defN2O.multiply(GWP_N2O),  regions, prefix + '_emission_def_n2o_' + year);

    iterate(year + 1);
  }

  iterate(2017);
}

processCerrado();

// ============================================================
// BIOMAS SIMPLES: Pantanal, Pampa, Caatinga, Mata Atlântica
//
// Distúrbios e gases exportados:
//   desmatamento → CO₂ apenas
//
// Carbono: QCN banda 'total' (agb+bgb+dw+litter pré-somados)
// Máscara florestal aplicada ao PRODES antes do remap
//
// Prefixos:
//   Pantanal       → pan
//   Pampa          → pam
//   Caatinga       → caa
//   Mata Atlântica → ma
// ============================================================

function processSimpleBiome(biomeName, prefix) {

  var biomeFC = biomesFC.filter(ee.Filter.eq('Bioma', biomeName));
  var regions = regionsFC.filter(ee.Filter.eq('Bioma', biomeName));

  var brazilForests = vegetationRaw.clip(biomeFC);

  var prodesDeforestation = prodesGreaterThan625ha
    .unmask(0)
    .multiply(brazilForests) // máscara florestal antes do remap
    .remap([16,17,18,19,20,21,22,23], [2016,2017,2018,2019,2020,2021,2022,2023], 0)
    .clip(biomeFC);

  var totalCarbon = qcn.select('total').mosaic().unmask(0).multiply(brazilForests).clip(biomeFC);

  function iterate(year) {
    if (year >= 2024) return;

    var defMask = prodesDeforestation.eq(year);
    var defCO2  = totalCarbon.multiply(defMask);

    exportEmission(defCO2.multiply(C_TO_CO2), regions, prefix + '_emission_def_co2_' + year);

    iterate(year + 1);
  }

  iterate(2017);
}

processSimpleBiome('Pantanal',       'pan');
processSimpleBiome('Pampa',          'pam');
processSimpleBiome('Caatinga',       'caa');
processSimpleBiome('Mata Atlântica', 'ma');
