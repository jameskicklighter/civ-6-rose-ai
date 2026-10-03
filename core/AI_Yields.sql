-- ============================================================================
-- Rose AI: Yields & PseudoYields
-- Generic era-linked yield biases and pseudoyield boosts only, including the
-- late-era military demand and attack-target valuation in section 7.
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
-- PseudoYield lists (this era or later; cumulative)
('RoseRenaissanceOnwardPseudoYields'),
('RoseIndustrialOnwardPseudoYields'),
('RoseModernOnwardPseudoYields'),
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
('RoseRenaissancePseudoYields',   'PseudoYields'),
('RoseRenaissanceOnwardPseudoYields', 'PseudoYields'),
('RoseIndustrialOnwardPseudoYields',  'PseudoYields'),
('RoseModernOnwardPseudoYields',      'PseudoYields');

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
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissancePseudoYields'),
-- Cumulative "era or later" strategies, defined in AI_Strategies.sql.
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'RoseRenaissanceOnwardPseudoYields'),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'RoseIndustrialOnwardPseudoYields'),
('STRATEGY_ROSE_MODERN_ONWARD',      'RoseModernOnwardPseudoYields');

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

-- ============================================================================
-- 7. LATE-ERA OFFENSE — army size and attack-target valuation
--
-- Base data adds no military demand after the early eras, and every city
-- assault uses the same team sizes in every era. Logs (2026-10-03 multiplayer)
-- showed mid/late AI armies too small to fill attack teams, and well-defended
-- major-civ cities valued at or near zero, so planned wars went to city-states.
--
-- PSEUDOYIELD_CITY_DEFENSES (base 200) is the penalty a target city's defenses
-- apply to its attack value; base data only lowers it for attackers (Aggressive
-- and Military Victory, -25 each). Values here are percent changes, like those
-- base lists. These lists sit on cumulative "era or later" strategies, so the
-- cuts add up: Renaissance -25, Industrial -40, Modern and later -50. The -50
-- total keeps the weight at or above zero even with both -25 attacker lists.
-- RH (default 57) and Real Strategy (40) lower it further, globally; Rose
-- leaves the early eras alone.
-- ============================================================================

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceOnwardPseudoYields', 'PSEUDOYIELD_CITY_DEFENSES',        1, -25),
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_CITY_DEFENSES',        1, -15),
('RoseModernOnwardPseudoYields',      'PSEUDOYIELD_CITY_DEFENSES',        1, -10),
-- Larger standing armies from the Industrial era on (RH uses about +11 to +20
-- standing army and +12 combat in Industrial-Atomic). Rose's At War strategy
-- adds its own wartime demand on top.
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_STANDING_ARMY_NUMBER', 1,  15),
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_STANDING_ARMY_VALUE',  1,  15),
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_UNIT_COMBAT',          1,  10);
