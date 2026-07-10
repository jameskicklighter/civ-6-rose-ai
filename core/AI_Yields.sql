-- ============================================================================
-- Rose AI: Yields & PseudoYields
-- Generic era-linked yield biases and pseudoyield boosts only.
-- Leader-specific pseudoyields (Great Prophet for religious civs) live in
-- AI_Leaders.sql.
-- ============================================================================

-- ============================================================================
-- 1. DECLARE LISTS
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
-- Yield lists (per era)
('RoseAncientYields'),
('RoseClassicalYields'),
('RoseMedievalYields'),
('RoseRenaissanceYields'),
-- PseudoYield lists (per era)
('RoseAncientPseudoYields'),
('RoseClassicalPseudoYields'),
('RoseMedievalPseudoYields'),
('RoseRenaissancePseudoYields'),
-- Always-on pseudoyields (all major civs, all eras)
('RoseMajorCivPseudoYields');

-- ============================================================================
-- 2. MAP TO SYSTEMS
-- ============================================================================

-- Era-linked yield lists
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientYields',    'Yields'),
('RoseClassicalYields',  'Yields'),
('RoseMedievalYields',   'Yields'),
('RoseRenaissanceYields', 'Yields');

-- Era-linked pseudoyield lists
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientPseudoYields',       'PseudoYields'),
('RoseClassicalPseudoYields',     'PseudoYields'),
('RoseMedievalPseudoYields',      'PseudoYields'),
('RoseRenaissancePseudoYields',   'PseudoYields');

-- Always-on — tied to TRAIT_LEADER_MAJOR_CIV
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivPseudoYields', 'TRAIT_LEADER_MAJOR_CIV', 'PseudoYields');

-- ============================================================================
-- 3. LINK TO ERA STRATEGIES
-- ============================================================================

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientYields'),
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientPseudoYields'),
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalYields'),
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalPseudoYields'),
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalYields'),
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalPseudoYields'),
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceYields'),
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissancePseudoYields');

-- ============================================================================
-- 4. YIELD BIASES — Food +25, Production +25, Culture +10, Science -10
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
-- Ancient
('RoseAncientYields', 'YIELD_FOOD',       1, 25),
('RoseAncientYields', 'YIELD_PRODUCTION', 1, 25),
('RoseAncientYields', 'YIELD_CULTURE',    1, 10),
('RoseAncientYields', 'YIELD_SCIENCE',    1, -10),
-- Classical
('RoseClassicalYields', 'YIELD_FOOD',       1, 25),
('RoseClassicalYields', 'YIELD_PRODUCTION', 1, 25),
('RoseClassicalYields', 'YIELD_CULTURE',    1, 10),
('RoseClassicalYields', 'YIELD_SCIENCE',    1, -10),
-- Medieval
('RoseMedievalYields', 'YIELD_FOOD',       1, 25),
('RoseMedievalYields', 'YIELD_PRODUCTION', 1, 25),
-- Renaissance
('RoseRenaissanceYields', 'YIELD_FOOD',       1, 25),
('RoseRenaissanceYields', 'YIELD_PRODUCTION', 1, 25);

-- ============================================================================
-- 5. PSEUDOYIELD BOOSTS — Merchants, Districts, Population, Engineers
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
-- Ancient:
('RoseAncientPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',        1, 50),
('RoseAncientPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',     1, 10),
-- Classical:
('RoseClassicalPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',      1, 50),
('RoseClassicalPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',   1, 10),
-- Medieval:
('RoseMedievalPseudoYields', 'PSEUDOYIELD_DISTRICT',           1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',    1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',       1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_GPP_ENGINEER',       1, 100),
-- Renaissance:
('RoseRenaissancePseudoYields', 'PSEUDOYIELD_GPP_ENGINEER',    1, 100);

-- ============================================================================
-- 6. TRADERS ALWAYS FAVORED (all major civs, all eras)
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivPseudoYields', 'PSEUDOYIELD_UNIT_TRADE', 1, 100);
