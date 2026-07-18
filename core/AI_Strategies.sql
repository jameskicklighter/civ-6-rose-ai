-- ============================================================================
-- Rose AI: Custom Strategies
-- Defines custom AI strategies that don't exist in the base game.
-- Strategy-linked district/yield lists live here alongside their definitions.
-- ============================================================================

-- ============================================================================
-- 1. INFORMATION ERA STRATEGY
-- The base game defines era strategies for Classical through Modern but
-- omits the Information era. We create it here so other files can attach
-- lists to STRATEGY_INFORMATION_CHANGES.
-- ============================================================================

INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_INFORMATION_CHANGES', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_INFORMATION_CHANGES', 1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_INFORMATION_CHANGES', 'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction) VALUES
('STRATEGY_INFORMATION_CHANGES', 'Is Information');

-- ============================================================================
-- 2. DYNAMIC WAR SUSTAINMENT
--
-- These strategies are activated by Call Lua Function conditions implemented
-- in Rose_AI_Gameplay.lua. They respond only to wars against other major
-- civilizations; city-state wars do not redirect the entire economy.
--
-- At War maintains unit replacement and deemphasizes optional infrastructure.
-- Military Recovery stacks when our military is below 70% of the combined
-- opposing strength, trading one assault slot for defense and reconstruction.
-- War Advantage suppresses voluntary peace only while our military is at
-- least 125% of the combined opposing strength.
-- ============================================================================

INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_AT_WAR',            'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_WAR_ADVANTAGE',      'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_AT_WAR',            1),
('STRATEGY_ROSE_MILITARY_RECOVERY', 1),
('STRATEGY_ROSE_WAR_ADVANTAGE',     1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_AT_WAR',            'Is Not Major', 1),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'Is Not Major', 1),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue) VALUES
('STRATEGY_ROSE_AT_WAR',            'Call Lua Function', 'RoseActiveStrategyAtWar',            0),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'Call Lua Function', 'RoseActiveStrategyMilitaryRecovery', 70),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'Call Lua Function', 'RoseActiveStrategyWarAdvantage',     125);

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAtWarYields'),
('RoseAtWarPseudoYields'),
('RoseMilitaryRecoveryOperations'),
('RoseMilitaryRecoveryYields'),
('RoseMilitaryRecoveryPseudoYields'),
('RoseWarAdvantageDiplomacy');

INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAtWarYields',                    'Yields'),
('RoseAtWarPseudoYields',              'PseudoYields'),
('RoseMilitaryRecoveryOperations',     'AiOperationTypes'),
('RoseMilitaryRecoveryYields',         'Yields'),
('RoseMilitaryRecoveryPseudoYields',   'PseudoYields'),
('RoseWarAdvantageDiplomacy',          'DiplomaticActions');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarYields'),
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarPseudoYields'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryOperations'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryYields'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryPseudoYields'),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'RoseWarAdvantageDiplomacy');

INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
-- Sustained wartime production and replacement without adding assault slots.
('RoseAtWarYields',       'YIELD_PRODUCTION',                    1,  10),
('RoseAtWarYields',       'YIELD_GOLD',                          1,  10),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',             1,  20),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_UNIT_NAVAL_COMBAT',       1,  15),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER',    1,  10),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',     1,  10),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_DISTRICT',                1, -25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_IMPROVEMENT',             1, -25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_WONDER',                  1, -15),

-- Recovery stacks with At War and temporarily favors rebuilding over attack.
('RoseMilitaryRecoveryOperations',   'CITY_ASSAULT',                         1,  -1),
('RoseMilitaryRecoveryOperations',   'OP_DEFENSE',                           1,   2),
('RoseMilitaryRecoveryYields',       'YIELD_PRODUCTION',                     1,  25),
('RoseMilitaryRecoveryYields',       'YIELD_GOLD',                           1,  25),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',              1,  50),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_UNIT_NAVAL_COMBAT',        1,  40),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER',     1,  10),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',      1,  20),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_DISTRICT',                 1, -50),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_IMPROVEMENT',              1, -50),
('RoseMilitaryRecoveryPseudoYields', 'PSEUDOYIELD_WONDER',                   1, -25),

-- Strong AIs keep pressing; weak and evenly matched AIs retain normal peace logic.
('RoseWarAdvantageDiplomacy', 'DIPLOACTION_PROPOSE_PEACE_DEAL', 0, 0),
('RoseWarAdvantageDiplomacy', 'DIPLOACTION_MAKE_PEACE',         0, 0);

-- ============================================================================
-- 3. CONSIDER RELIGION STRATEGY (DISABLED)
-- Commented out — the Avoid Early Holy Sites trait in AI_Leaders.sql now
-- handles Holy Site spam more directly by disfavoring Holy Sites for
-- non-religious leaders in Ancient/Classical.
-- ============================================================================

-- INSERT OR IGNORE INTO Types (Type, Kind) VALUES
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'KIND_VICTORY_STRATEGY');
--
-- INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 1);
--
-- INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, Disqualifier) VALUES
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'Is Not Major',          1),
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'Cannot Found Religion', 1),
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'Religion Destroyed',    1),
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'Is Medieval',           1);
--
-- INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, ThresholdValue) VALUES
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'Good Faith City', 1);
--
-- INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
-- ('RoseConsiderReligionDistricts');
--
-- INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
-- ('RoseConsiderReligionDistricts', 'Districts');
--
-- INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
-- ('STRATEGY_ROSE_CONSIDER_RELIGION', 'RoseConsiderReligionDistricts');
--
-- INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
-- ('RoseConsiderReligionDistricts', 'DISTRICT_HOLY_SITE', 1, 0);
