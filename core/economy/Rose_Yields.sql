-- ============================================================================
-- Rose AI: generic yield and pseudoyield lists on the era strategies, the
-- cumulative era-onward strategies (Rose_Strategies.sql) and all majors.
-- Values are percent changes of the defaults. Leader lists: Leaders/.
-- AGENTS.md "## Current Features", "### economy/Rose_Yields.sql".
-- ============================================================================

-- Ancient yields: growth first; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientYields',    'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientYields', 'YIELD_FOOD',       1, 25),
('RoseAncientYields', 'YIELD_PRODUCTION', 1, 25),
('RoseAncientYields', 'YIELD_CULTURE',    1, 10),
('RoseAncientYields', 'YIELD_SCIENCE',    1, -10);

-- Ancient pseudoyields: Great Merchants and population; AGENTS.md "Great Merchant points boosted", "Population priority boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientPseudoYields',       'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',        1, 50),
('RoseAncientPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',     1, 10);

-- Classical yields: growth first; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalYields',  'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseClassicalYields', 'YIELD_FOOD',       1, 25),
('RoseClassicalYields', 'YIELD_PRODUCTION', 1, 25),
('RoseClassicalYields', 'YIELD_CULTURE',    1, 10),
('RoseClassicalYields', 'YIELD_SCIENCE',    1, -10);

-- Classical pseudoyields: Great Merchants and population; AGENTS.md "Great Merchant points boosted", "Population priority boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalPseudoYields',     'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseClassicalPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',      1, 50),
('RoseClassicalPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',   1, 10);

-- Medieval yields: Food and Production; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalYields',   'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalYields', 'YIELD_FOOD',       1, 25),
('RoseMedievalYields', 'YIELD_PRODUCTION', 1, 25);

-- Medieval pseudoyields: districts, population, Great Merchants and Engineers;
-- AGENTS.md "District pseudoyield increased", "Population priority boosted", "Great Engineer points boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalPseudoYields',      'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalPseudoYields', 'PSEUDOYIELD_DISTRICT',           1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',    1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',       1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_GPP_ENGINEER',       1, 100);

-- Renaissance yields: Food and Production; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceYields', 'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceYields', 'YIELD_FOOD',       1, 25),
('RoseRenaissanceYields', 'YIELD_PRODUCTION', 1, 25);

-- Renaissance pseudoyields: Great Engineers; AGENTS.md "Great Engineer points boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissancePseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissancePseudoYields',   'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissancePseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissancePseudoYields', 'PSEUDOYIELD_GPP_ENGINEER',    1, 100);

-- Renaissance onward: a target's defenses count less (the cuts add up with the
-- later lists: -25, -40, -50) and Great Scientist points; AGENTS.md "Late-era offense",
-- "Campuses by pseudoyield and Science from the Renaissance era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceOnwardPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceOnwardPseudoYields', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'RoseRenaissanceOnwardPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceOnwardPseudoYields', 'PSEUDOYIELD_CITY_DEFENSES',        1, -25),
('RoseRenaissanceOnwardPseudoYields', 'PSEUDOYIELD_GPP_SCIENTIST',        1,  50);

-- Renaissance onward: Science weight (the city-build evaluator probably reads
-- Yields lists); AGENTS.md "Campuses by pseudoyield and Science from the Renaissance era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceOnwardYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceOnwardYields', 'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'RoseRenaissanceOnwardYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceOnwardYields', 'YIELD_SCIENCE', 1, 30);

-- Industrial onward: defenses count less again, larger standing armies;
-- AGENTS.md "Late-era offense"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseIndustrialOnwardPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseIndustrialOnwardPseudoYields',  'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'RoseIndustrialOnwardPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_CITY_DEFENSES',        1, -15),
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_STANDING_ARMY_NUMBER', 1,  15),
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_STANDING_ARMY_VALUE',  1,  15),
('RoseIndustrialOnwardPseudoYields',  'PSEUDOYIELD_UNIT_COMBAT',          1,  10);

-- Modern onward: defenses count less again, air power; AGENTS.md "Late-era offense",
-- "Air power from the Modern era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseModernOnwardPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseModernOnwardPseudoYields',      'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MODERN_ONWARD',      'RoseModernOnwardPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseModernOnwardPseudoYields',      'PSEUDOYIELD_CITY_DEFENSES',        1, -10),
('RoseModernOnwardPseudoYields',      'PSEUDOYIELD_UNIT_AIR_COMBAT',      1,  25);

-- All majors, all eras: Traders always favored; AGENTS.md "Trader units always favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivPseudoYields', 'TRAIT_LEADER_MAJOR_CIV', 'PseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivPseudoYields', 'PSEUDOYIELD_UNIT_TRADE', 1, 100);
