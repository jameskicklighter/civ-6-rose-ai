-- ============================================================================
-- Rose AI: lists attached to the war and austerity strategies
-- (defined in Rose_Strategies.sql). Values are percent changes of the defaults.
-- AGENTS.md "## Current Features", "### strategies/ (Rose_Strategies.sql, Rose_Strategy_Lists.sql)".
-- ============================================================================

-- At War: more Production and Gold for replacement units; AGENTS.md "STRATEGY_ROSE_AT_WAR"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAtWarYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAtWarYields',                    'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAtWarYields',       'YIELD_PRODUCTION',                    1,  10),
('RoseAtWarYields',       'YIELD_GOLD',                          1,  10);

-- At War: army demand up, optional infrastructure down, enemy cities valued
-- higher (a higher CITY_BASE also weakens the frontier-first defense terms);
-- AGENTS.md "STRATEGY_ROSE_AT_WAR", "Army size: militaristic leaders and wars"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAtWarPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAtWarPseudoYields',              'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarPseudoYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAtWarPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',             1,  50),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_UNIT_NAVAL_COMBAT',       1,  15),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER',    1,  30),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',     1,  25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_DISTRICT',                1, -25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_IMPROVEMENT',             1, -25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_WONDER',                  1, -15),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_CITY_DEFENDING_UNITS',    1, -40),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_CITY_BASE',               1,  75);

-- Military Recovery: no planned slot (the wartime slot stays), two more
-- City Defense slots; AGENTS.md "STRATEGY_ROSE_MILITARY_RECOVERY"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMilitaryRecoveryOperations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMilitaryRecoveryOperations',     'AiOperationTypes');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryOperations');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseMilitaryRecoveryOperations',   'CITY_ASSAULT',                         1,  -1),
('RoseMilitaryRecoveryOperations',   'OP_DEFENSE',                           1,   2);

-- Military Recovery: stronger Production and Gold; AGENTS.md "STRATEGY_ROSE_MILITARY_RECOVERY"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMilitaryRecoveryYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMilitaryRecoveryYields',         'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseMilitaryRecoveryYields',       'YIELD_PRODUCTION',                     1,  25),
('RoseMilitaryRecoveryYields',       'YIELD_GOLD',                           1,  25);

-- Military Recovery: rebuild the army, suppress optional infrastructure;
-- AGENTS.md "STRATEGY_ROSE_MILITARY_RECOVERY"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMilitaryRecoveryPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMilitaryRecoveryPseudoYields',   'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryPseudoYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',              1,  50),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_UNIT_NAVAL_COMBAT',        1,  40),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER',     1,  10),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',      1,  20),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_DISTRICT',                 1, -50),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_IMPROVEMENT',              1, -50),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_WONDER',                   1, -25);

-- Military Recovery: Grand Master's Chapel, so Faith can buy land units;
-- AGENTS.md "STRATEGY_ROSE_MILITARY_RECOVERY"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMilitaryRecoveryBuildings');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMilitaryRecoveryBuildings',      'Buildings');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryBuildings');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseMilitaryRecoveryBuildings',    'BUILDING_GOV_FAITH',                   1, 100);

-- The lists below keep the order they always loaded in: the engine reads the
-- lists of one system (Diplomatic actions, operation slots) in database order.

-- War Advantage: a clearly stronger AI does not propose or make peace;
-- AGENTS.md "STRATEGY_ROSE_WAR_ADVANTAGE"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseWarAdvantageDiplomacy');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseWarAdvantageDiplomacy',          'DiplomaticActions');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_WAR_ADVANTAGE',     'RoseWarAdvantageDiplomacy');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseWarAdvantageDiplomacy', 'DIPLOACTION_PROPOSE_PEACE_DEAL', 0, 0),
('RoseWarAdvantageDiplomacy', 'DIPLOACTION_MAKE_PEACE',         0, 0);

-- At War: no new city-state wars (diplomacy skips a disfavored action) and
-- every AI nuke-willing ("Will use nukes" passes on a favored action);
-- AGENTS.md "STRATEGY_ROSE_AT_WAR", 'Known engine behaviour: nuclear operations'
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAtWarDiplomacy');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAtWarDiplomacy',                 'DiplomaticActions');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarDiplomacy');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAtWarDiplomacy', 'DIPLOACTION_DECLARE_WAR_MINOR_CIV',      0,   0),
('RoseAtWarDiplomacy', 'DIPLOACTION_USE_NUCLEAR_WEAPON',         1,   0);

-- At War: no planned (CITY_ASSAULT) slot during a major war, leaving the one
-- wartime slot; a limit below zero blocks like zero, and running operations
-- are not cut (the limit is checked at start); AGENTS.md "City-assault concentration"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAtWarOperations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAtWarOperations',                'AiOperationTypes');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarOperations');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAtWarOperations', 'CITY_ASSAULT',                          1,  -1);

-- War Advantage: a second wartime assault slot; AGENTS.md "STRATEGY_ROSE_WAR_ADVANTAGE"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseWarAdvantageOperations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseWarAdvantageOperations',         'AiOperationTypes');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_WAR_ADVANTAGE',     'RoseWarAdvantageOperations');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseWarAdvantageOperations', 'ROSE_WARTIME_ASSAULT',          1, 1);

-- Austerity: Gold weight up; AGENTS.md "STRATEGY_ROSE_AUSTERITY / _AT_WAR"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAusterityYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAusterityYields',            'Yields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AUSTERITY',        'RoseAusterityYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAusterityYields',            'YIELD_GOLD',                       1,  30);

-- Austerity: Traders up, wonders down; AGENTS.md "STRATEGY_ROSE_AUSTERITY / _AT_WAR"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAusterityPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAusterityPseudoYields',      'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AUSTERITY',        'RoseAusterityPseudoYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAusterityPseudoYields',      'PSEUDOYIELD_UNIT_TRADE',           1,  50),
('RoseAusterityPseudoYields',      'PSEUDOYIELD_WONDER',               1, -25);

-- Austerity: Commercial Hub and Harbor favored; AGENTS.md "STRATEGY_ROSE_AUSTERITY / _AT_WAR"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAusterityDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAusterityDistricts',         'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AUSTERITY',        'RoseAusterityDistricts');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAusterityDistricts',         'DISTRICT_COMMERCIAL_HUB',          1,  50),
('RoseAusterityDistricts',         'DISTRICT_HARBOR',                  1,  50);

-- Austerity At War: trims part of At War's extra unit demand (it stays above
-- base); AGENTS.md "STRATEGY_ROSE_AUSTERITY / _AT_WAR"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAusterityAtWarPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAusterityAtWarPseudoYields', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AUSTERITY_AT_WAR', 'RoseAusterityAtWarPseudoYields');
INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAusterityAtWarPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',          1, -20),
('RoseAusterityAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER', 1, -10),
('RoseAusterityAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',  1, -10);
