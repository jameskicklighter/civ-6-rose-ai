-- ============================================================================
-- Rose AI: District Priorities
-- Generic era-linked and civ-wide district priorities only.
-- Leader-specific districts (Roosevelt, Hammurabi, Saladin, religious group)
-- live in AI_Leaders.sql. Strategy-linked districts live in AI_Strategies.sql.
-- ============================================================================

-- ============================================================================
-- 1. REMOVE BASE GAME CLASSICAL DISTRICT BIASES
-- The base game favors Campus and Theater Square in the Classical era.
-- We remove those so our mod controls district priorities cleanly.
-- ============================================================================

DELETE FROM AiFavoredItems
WHERE ListType = 'ClassicalDistricts'
  AND Item IN ('DISTRICT_CAMPUS', 'DISTRICT_THEATER');

-- ============================================================================
-- 2. DECLARE LISTS
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
-- Era-linked district lists
('RoseAncientDistricts'),
('RoseClassicalDistricts'),
('RoseMedievalDistricts'),
('RoseRenaissanceDistricts'),
-- This era or later (cumulative strategies, AI_Strategies.sql)
('RoseRenaissanceOnwardDistricts'),
('RoseModernOnwardDistricts'),
-- Always-on districts (all major civs)
('RoseMajorCivDistricts'),
-- Per-civilization unique district lists (separate names required —
-- each ListType can only map to one LeaderType in AiLists)
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

-- ============================================================================
-- 3. MAP TO SYSTEMS
-- ============================================================================

-- Era-linked
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientDistricts',      'Districts'),
('RoseClassicalDistricts',    'Districts'),
('RoseMedievalDistricts',     'Districts'),
('RoseRenaissanceDistricts',  'Districts'),
('RoseRenaissanceOnwardDistricts', 'Districts'),
('RoseModernOnwardDistricts', 'Districts');

-- Always-on — tied to TRAIT_LEADER_MAJOR_CIV
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivDistricts', 'TRAIT_LEADER_MAJOR_CIV', 'Districts');

-- Per-civilization — tied to each civ's unique-district trait
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

-- ============================================================================
-- 4. LINK ERA LISTS TO STRATEGIES
-- ============================================================================

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientDistricts'),
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalDistricts'),
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalDistricts'),
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceDistricts'),
-- Cumulative "era or later" strategies, defined in AI_Strategies.sql.
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'RoseRenaissanceOnwardDistricts'),
('STRATEGY_ROSE_MODERN_ONWARD',   'RoseModernOnwardDistricts');

-- ============================================================================
-- 5. POPULATE — Era-linked district priorities
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
-- Commercial Hub in Ancient/Classical/Medieval
('RoseAncientDistricts',    'DISTRICT_COMMERCIAL_HUB',  1, 100),
('RoseClassicalDistricts',  'DISTRICT_COMMERCIAL_HUB',  1, 100),
('RoseMedievalDistricts',   'DISTRICT_COMMERCIAL_HUB',  1, 100),
-- Industrial Zone in Medieval/Renaissance
('RoseMedievalDistricts',     'DISTRICT_INDUSTRIAL_ZONE', 1, 100),
('RoseRenaissanceDistricts',  'DISTRICT_INDUSTRIAL_ZONE', 1, 100),
-- Campus from the Renaissance era on (W26, 2026-10-10). The favored
-- districts above fill the early slots and section 1 drops the base Classical
-- Campus favor, so Rose AIs built Campuses in 3-4% of their district
-- contracts over three 174-199 turn games (vanilla 24%). The opening is left
-- growth-first; the second wave of districts should now include one. +50
-- gave 8% of district contracts in two games (12% in one), so round 9
-- (2026-10-18) sets +100, level with the other favored districts, together
-- with Great Scientist points +50 (AI_Yields.sql).
('RoseRenaissanceOnwardDistricts', 'DISTRICT_CAMPUS',     1, 100),
-- Aerodrome from the Modern era (Flight). No base list favors it; AIs chose
-- 2-4 per civ by turn 200, none for 2 of 8 (2026-10-09 test). Air combat
-- demand is raised on the same strategy (AI_Yields.sql).
('RoseModernOnwardDistricts', 'DISTRICT_AERODROME',       1, 100);

-- ============================================================================
-- 6. POPULATE — Always-on districts (all major civs, all eras)
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivDistricts', 'DISTRICT_GOVERNMENT', 1, 999),
('RoseMajorCivDistricts', 'DISTRICT_AQUEDUCT',   1, 50);

-- ============================================================================
-- 7. POPULATE — Unique districts per civilization (always favored)
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
-- Base game
('RoseGreeceDistricts',     'DISTRICT_ACROPOLIS',           1, 100),
('RoseRomeDistricts',       'DISTRICT_BATH',                1, 100),
('RoseGermanyDistricts',    'DISTRICT_HANSA',               1, 100),
('RoseRussiaDistricts',     'DISTRICT_LAVRA',               1, 100),
('RoseKongoDistricts',      'DISTRICT_MBANZA',              1, 100),
('RoseBrazilDistricts',     'DISTRICT_STREET_CARNIVAL',     1, 100),
('RoseEnglandDistricts',    'DISTRICT_ROYAL_NAVY_DOCKYARD', 1, 100),
-- Expansion 1
('RoseKoreaDistricts',      'DISTRICT_SEOWON',              1, 100),
('RoseZuluDistricts',       'DISTRICT_IKANDA',              1, 100),
-- Expansion 2
('RosePhoeniciaDistricts',  'DISTRICT_COTHON',              1, 100),
('RoseMaliDistricts',       'DISTRICT_SUGUBA',              1, 100),
-- DLC packs
('RoseByzantiumDistricts',  'DISTRICT_HIPPODROME',          1, 100),
('RoseGaulDistricts',       'DISTRICT_OPPIDUM',             1, 100),
('RoseVietnamDistricts',    'DISTRICT_THANH',               1, 100),
('RoseMayaDistricts',       'DISTRICT_OBSERVATORY',         1, 100);
