-- ============================================================================
-- Rose AI: generic district priorities on the Rose era window strategies, the
-- era-onward and focus strategies (Rose_Strategies.sql), Military Victory, all
-- majors and civilizations. Leader-specific districts: Leaders/Rose_Leader_Lists.sql.
-- AGENTS.md "## Current Features", "### economy/Rose_Districts.sql".
-- ============================================================================

-- The base Classical Campus and Theater Square favors are removed;
-- AGENTS.md "Classical district biases removed"
DELETE FROM AiFavoredItems
WHERE ListType = 'ClassicalDistricts'
  AND Item IN ('DISTRICT_CAMPUS', 'DISTRICT_THEATER');

-- Classical: Commercial Hub; AGENTS.md "Commercial Hub district favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalDistricts',    'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_CLASSICAL_ERA',    'RoseClassicalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseClassicalDistricts',  'DISTRICT_COMMERCIAL_HUB',  1);

-- Medieval: Commercial Hub; AGENTS.md "Commercial Hub district favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalDistricts',     'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_ERA',     'RoseMedievalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMedievalDistricts',   'DISTRICT_COMMERCIAL_HUB',  1);

-- Medieval onward: Industrial Zone; AGENTS.md "Industrial Zone favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalOnwardDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalOnwardDistricts', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_ONWARD',  'RoseMedievalOnwardDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMedievalOnwardDistricts', 'DISTRICT_INDUSTRIAL_ZONE', 1);

-- Renaissance onward, science leaders and players whose Science Victory
-- conditions hold: Campus; AGENTS.md "Campus and Theater Square by focus from the Renaissance era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseScienceLeaderDistricts'),
('RoseScienceFocusDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseScienceLeaderDistricts', 'Districts'),
('RoseScienceFocusDistricts',  'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_SCIENCE_LEADER_LATE', 'RoseScienceLeaderDistricts'),
('STRATEGY_ROSE_SCIENCE_FOCUS',       'RoseScienceFocusDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseScienceLeaderDistricts', 'DISTRICT_CAMPUS', 1),
('RoseScienceFocusDistricts',  'DISTRICT_CAMPUS', 1);

-- Renaissance onward, cultural leaders and players whose Culture Victory
-- conditions hold: Theater Square; AGENTS.md "Campus and Theater Square by focus from the Renaissance era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseCultureLeaderDistricts'),
('RoseCultureFocusDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseCultureLeaderDistricts', 'Districts'),
('RoseCultureFocusDistricts',  'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_CULTURE_LEADER_LATE', 'RoseCultureLeaderDistricts'),
('STRATEGY_ROSE_CULTURE_FOCUS',       'RoseCultureFocusDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseCultureLeaderDistricts', 'DISTRICT_THEATER', 1),
('RoseCultureFocusDistricts',  'DISTRICT_THEATER', 1);

-- Military Victory: Aerodrome (buildable from Flight only, so no era window);
-- the aggressive-military leaders' list is in Leaders/; AGENTS.md "Aerodrome for military leaders and Military Victory"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMilitaryVictoryDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMilitaryVictoryDistricts', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('VICTORY_STRATEGY_MILITARY_VICTORY', 'RoseMilitaryVictoryDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMilitaryVictoryDistricts', 'DISTRICT_AERODROME', 1);

-- All majors, all eras: Government Plaza, Aqueduct, Diplomatic Quarter and Dam;
-- AGENTS.md "Government Plaza always favored", "Aqueducts always favored",
-- "Diplomatic Quarter and Dam always favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivDistricts', 'TRAIT_LEADER_MAJOR_CIV', 'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMajorCivDistricts', 'DISTRICT_GOVERNMENT',         1),
('RoseMajorCivDistricts', 'DISTRICT_AQUEDUCT',           1),
('RoseMajorCivDistricts', 'DISTRICT_DIPLOMATIC_QUARTER', 1),
('RoseMajorCivDistricts', 'DISTRICT_DAM',                1);

-- Egypt (every leader): Dam disfavored against the all-majors favor. The base
-- Cleopatra disfavor moves to the civilization trait and a second Egypt list
-- adds one more, so the sum is -1 (one row in each of two lists); AGENTS.md
-- "Diplomatic Quarter and Dam always favored"
UPDATE AiLists SET LeaderType = 'TRAIT_CIVILIZATION_ITERU'
WHERE ListType = 'CleopatraDistricts' AND LeaderType = 'TRAIT_LEADER_MEDITERRANEAN';
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseEgyptDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseEgyptDistricts', 'TRAIT_CIVILIZATION_ITERU', 'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseEgyptDistricts', 'DISTRICT_DAM', 0);

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
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored)
SELECT 'RoseMajorCivBuildings', BuildingType, 1
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

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseGreeceDistricts',     'DISTRICT_ACROPOLIS',           1),
('RoseRomeDistricts',       'DISTRICT_BATH',                1),
('RoseGermanyDistricts',    'DISTRICT_HANSA',               1),
('RoseRussiaDistricts',     'DISTRICT_LAVRA',               1),
('RoseKongoDistricts',      'DISTRICT_MBANZA',              1),
('RoseBrazilDistricts',     'DISTRICT_STREET_CARNIVAL',     1),
('RoseEnglandDistricts',    'DISTRICT_ROYAL_NAVY_DOCKYARD', 1),
('RoseKoreaDistricts',      'DISTRICT_SEOWON',              1),
('RoseZuluDistricts',       'DISTRICT_IKANDA',              1),
('RosePhoeniciaDistricts',  'DISTRICT_COTHON',              1),
('RoseMaliDistricts',       'DISTRICT_SUGUBA',              1),
('RoseByzantiumDistricts',  'DISTRICT_HIPPODROME',          1),
('RoseGaulDistricts',       'DISTRICT_OPPIDUM',             1),
('RoseVietnamDistricts',    'DISTRICT_THANH',               1),
('RoseMayaDistricts',       'DISTRICT_OBSERVATORY',         1);

-- Scotland: the base Campus and Industrial Zone favors are removed and the
-- Entertainment Complex (amenities for its happy-city bonuses) is always
-- favored; AGENTS.md "Scotland Entertainment Complex favored"
DELETE FROM AiFavoredItems
WHERE ListType = 'ScottishEnlightnmentDistricts'
  AND Item IN ('DISTRICT_CAMPUS', 'DISTRICT_INDUSTRIAL_ZONE');
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseScotlandDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseScotlandDistricts', 'TRAIT_CIVILIZATION_SCOTTISH_ENLIGHTENMENT', 'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseScotlandDistricts', 'DISTRICT_ENTERTAINMENT_COMPLEX', 1);
