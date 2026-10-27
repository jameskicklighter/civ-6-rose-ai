-- ============================================================================
-- Rose AI: generic district priorities on the Rose era window strategies, the
-- era-onward strategies (Rose_Strategies.sql), all majors and each
-- civilization's unique district. Leader-specific districts: Leaders/Rose_Leader_Lists.sql.
-- AGENTS.md "## Current Features", "### economy/Rose_Districts.sql".
-- ============================================================================

-- The base Classical Campus and Theater Square favors are removed;
-- AGENTS.md "Classical district biases removed"
DELETE FROM AiFavoredItems
WHERE ListType = 'ClassicalDistricts'
  AND Item IN ('DISTRICT_CAMPUS', 'DISTRICT_THEATER');

-- Ancient: Commercial Hub; AGENTS.md "Commercial Hub district favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientDistricts',      'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',      'RoseAncientDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientDistricts',    'DISTRICT_COMMERCIAL_HUB',  1, 100);

-- Classical: Commercial Hub; AGENTS.md "Commercial Hub district favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalDistricts',    'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_CLASSICAL_ERA',    'RoseClassicalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseClassicalDistricts',  'DISTRICT_COMMERCIAL_HUB',  1, 100);

-- Medieval: Commercial Hub and Industrial Zone; AGENTS.md "Commercial Hub district favored", "Industrial Zone favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalDistricts',     'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_ERA',     'RoseMedievalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalDistricts',   'DISTRICT_COMMERCIAL_HUB',  1, 100),
('RoseMedievalDistricts',     'DISTRICT_INDUSTRIAL_ZONE', 1, 100);

-- Renaissance: Industrial Zone; AGENTS.md "Industrial Zone favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceDistricts',  'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ERA',  'RoseRenaissanceDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceDistricts',  'DISTRICT_INDUSTRIAL_ZONE', 1, 100);

-- Renaissance onward: Campus, level with the other favored districts;
-- AGENTS.md "Campus from the Renaissance era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceOnwardDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceOnwardDistricts', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'RoseRenaissanceOnwardDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceOnwardDistricts', 'DISTRICT_CAMPUS',     1, 100);

-- Modern onward: Aerodrome (no base list favors it); AGENTS.md "Aerodrome from the Modern era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseModernOnwardDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseModernOnwardDistricts', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MODERN_ONWARD',   'RoseModernOnwardDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseModernOnwardDistricts', 'DISTRICT_AERODROME',       1, 100);

-- All majors, all eras: Government Plaza and Aqueduct; AGENTS.md "Government Plaza always favored", "Aqueducts always favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivDistricts', 'TRAIT_LEADER_MAJOR_CIV', 'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivDistricts', 'DISTRICT_GOVERNMENT', 1, 999),
('RoseMajorCivDistricts', 'DISTRICT_AQUEDUCT',   1, 50);

-- The Preserve takes a specialty-district slot but is priced like an Aqueduct;
-- give it the specialty-district cost model and discount (all players);
-- AGENTS.md "Preserve priced as a specialty district"
UPDATE Districts
SET CostProgressionModel = 'COST_PROGRESSION_NUM_UNDER_AVG_PLUS_TECH',
    CostProgressionParam1 = 40
WHERE DistrictType = 'DISTRICT_PRESERVE';

-- All majors, all eras: Grove and Sanctuary, which no base list favors, so
-- built Preserves are not left empty; AGENTS.md "Preserve buildings favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivBuildings', 'TRAIT_LEADER_MAJOR_CIV', 'Buildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value)
SELECT 'RoseMajorCivBuildings', BuildingType, 1, 50
FROM Buildings
WHERE BuildingType IN ('BUILDING_GROVE', 'BUILDING_SANCTUARY');

-- Each civilization's unique district, always favored: one list per civ,
-- since a ListType maps to one LeaderType (trait) in AiLists;
-- AGENTS.md "Unique district per civ always favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGreeceDistricts'),
('RoseRomeDistricts'),
('RoseGermanyDistricts'),
('RoseRussiaDistricts'),
('RoseKongoDistricts'),
('RoseBrazilDistricts'),
('RoseEnglandDistricts'),
('RoseKoreaDistricts'),
('RoseZuluDistricts'),
('RosePhoeniciaDistricts'),
('RoseMaliDistricts'),
('RoseByzantiumDistricts'),
('RoseGaulDistricts'),
('RoseVietnamDistricts'),
('RoseMayaDistricts');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseGreeceDistricts',     'TRAIT_CIVILIZATION_DISTRICT_ACROPOLIS',   'Districts'),
('RoseRomeDistricts',       'TRAIT_CIVILIZATION_DISTRICT_BATH',        'Districts'),
('RoseGermanyDistricts',    'TRAIT_CIVILIZATION_DISTRICT_HANSA',       'Districts'),
('RoseRussiaDistricts',     'TRAIT_CIVILIZATION_DISTRICT_LAVRA',       'Districts'),
('RoseKongoDistricts',      'TRAIT_CIVILIZATION_MBANZA',               'Districts'),
('RoseBrazilDistricts',     'TRAIT_CIVILIZATION_STREET_CARNIVAL',      'Districts'),
('RoseEnglandDistricts',    'TRAIT_CIVILIZATION_ROYAL_NAVY_DOCKYARD',  'Districts'),
('RoseKoreaDistricts',      'TRAIT_CIVILIZATION_DISTRICT_SEOWON',      'Districts'),
('RoseZuluDistricts',       'TRAIT_CIVILIZATION_DISTRICT_IKANDA',      'Districts'),
('RosePhoeniciaDistricts',  'TRAIT_CIVILIZATION_DISTRICT_COTHON',      'Districts'),
('RoseMaliDistricts',       'TRAIT_CIVILIZATION_DISTRICT_SUGUBA',      'Districts'),
('RoseByzantiumDistricts',  'TRAIT_CIVILIZATION_DISTRICT_HIPPODROME',  'Districts'),
('RoseGaulDistricts',       'TRAIT_CIVILIZATION_DISTRICT_OPPIDUM',     'Districts'),
('RoseVietnamDistricts',    'TRAIT_CIVILIZATION_DISTRICT_THANH',       'Districts'),
('RoseMayaDistricts',       'TRAIT_CIVILIZATION_DISTRICT_OBSERVATORY', 'Districts');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseGreeceDistricts',     'DISTRICT_ACROPOLIS',           1, 100),
('RoseRomeDistricts',       'DISTRICT_BATH',                1, 100),
('RoseGermanyDistricts',    'DISTRICT_HANSA',               1, 100),
('RoseRussiaDistricts',     'DISTRICT_LAVRA',               1, 100),
('RoseKongoDistricts',      'DISTRICT_MBANZA',              1, 100),
('RoseBrazilDistricts',     'DISTRICT_STREET_CARNIVAL',     1, 100),
('RoseEnglandDistricts',    'DISTRICT_ROYAL_NAVY_DOCKYARD', 1, 100),
('RoseKoreaDistricts',      'DISTRICT_SEOWON',              1, 100),
('RoseZuluDistricts',       'DISTRICT_IKANDA',              1, 100),
('RosePhoeniciaDistricts',  'DISTRICT_COTHON',              1, 100),
('RoseMaliDistricts',       'DISTRICT_SUGUBA',              1, 100),
('RoseByzantiumDistricts',  'DISTRICT_HIPPODROME',          1, 100),
('RoseGaulDistricts',       'DISTRICT_OPPIDUM',             1, 100),
('RoseVietnamDistricts',    'DISTRICT_THANH',               1, 100),
('RoseMayaDistricts',       'DISTRICT_OBSERVATORY',         1, 100);
