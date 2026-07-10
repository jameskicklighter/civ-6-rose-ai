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
-- 2. CONSIDER RELIGION STRATEGY (DISABLED)
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
