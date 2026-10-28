-- ============================================================================
-- Rose AI: generic yield and pseudoyield lists on the Rose era window
-- strategies, the cumulative era-onward strategies (Rose_Strategies.sql) and
-- all majors.
-- Values are percent changes of the defaults. Leader lists: Leaders/.
-- AGENTS.md "## Current Features", "### economy/Rose_Yields.sql".
-- ============================================================================

-- Ancient yields: growth first; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientYields',    'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',      'RoseAncientYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientYields', 'YIELD_FOOD',       1, 25),
('RoseAncientYields', 'YIELD_PRODUCTION', 1, 25),
('RoseAncientYields', 'YIELD_CULTURE',    1, 10),
('RoseAncientYields', 'YIELD_SCIENCE',    1, -10);

-- Ancient pseudoyields: population; AGENTS.md "Population priority boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientPseudoYields',       'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',      'RoseAncientPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',     1, 10);

-- Classical yields: growth first; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalYields',  'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_CLASSICAL_ERA',    'RoseClassicalYields');
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
('STRATEGY_ROSE_CLASSICAL_ERA',    'RoseClassicalPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseClassicalPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',      1, 50),
('RoseClassicalPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',   1, 10);

-- Medieval yields: Food and Production; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalYields',   'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_ERA',     'RoseMedievalYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalYields', 'YIELD_FOOD',       1, 25),
('RoseMedievalYields', 'YIELD_PRODUCTION', 1, 25);

-- Medieval pseudoyields: population, Great Merchants and Engineers; AGENTS.md
-- "Population priority boosted", "Great Merchant points boosted", "Great Engineer points boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalPseudoYields',      'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_ERA',     'RoseMedievalPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalPseudoYields', 'PSEUDOYIELD_CITY_POPULATION',    1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_GPP_MERCHANT',       1, 50),
('RoseMedievalPseudoYields', 'PSEUDOYIELD_GPP_ENGINEER',       1, 100);

-- Medieval to Industrial: districts and improvements (Builder demand, with
-- Serfdom's extra charges) while cities fill out; AGENTS.md "District pseudoyield increased", "Builders favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalToIndustrialPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalToIndustrialPseudoYields', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_TO_INDUSTRIAL', 'RoseMedievalToIndustrialPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalToIndustrialPseudoYields', 'PSEUDOYIELD_DISTRICT',    1, 50),
('RoseMedievalToIndustrialPseudoYields', 'PSEUDOYIELD_IMPROVEMENT', 1, 100);

-- Medieval to Industrial: Science weight (the city-build evaluator probably
-- reads Yields lists); AGENTS.md "Science from the Medieval to the Industrial era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalToIndustrialYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalToIndustrialYields', 'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MEDIEVAL_TO_INDUSTRIAL', 'RoseMedievalToIndustrialYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalToIndustrialYields', 'YIELD_SCIENCE', 1, 30);

-- Renaissance yields: Food and Production; AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceYields', 'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ERA',  'RoseRenaissanceYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceYields', 'YIELD_FOOD',       1, 25),
('RoseRenaissanceYields', 'YIELD_PRODUCTION', 1, 25);

-- Renaissance pseudoyields: Great Engineers; AGENTS.md "Great Engineer points boosted"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissancePseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissancePseudoYields',   'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ERA',  'RoseRenaissancePseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissancePseudoYields', 'PSEUDOYIELD_GPP_ENGINEER',    1, 100);

-- Renaissance onward: a target's defenses count less (the cuts add up with the
-- later lists: -25, -40, -50) and Great Scientist points; AGENTS.md "Late-era offense",
-- "Great Scientist points from the Renaissance era"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceOnwardPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceOnwardPseudoYields', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'RoseRenaissanceOnwardPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceOnwardPseudoYields', 'PSEUDOYIELD_CITY_DEFENSES',        1, -25),
('RoseRenaissanceOnwardPseudoYields', 'PSEUDOYIELD_GPP_SCIENTIST',        1,  50);

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

-- Industrial onward: Production, so with the stacked base era lists (+20 from
-- the Medieval era) it stays where the Renaissance window left it;
-- AGENTS.md "Growth-focused yield adjustments"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseIndustrialOnwardYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseIndustrialOnwardYields', 'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_INDUSTRIAL_ONWARD', 'RoseIndustrialOnwardYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseIndustrialOnwardYields', 'YIELD_PRODUCTION', 1, 25);

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
