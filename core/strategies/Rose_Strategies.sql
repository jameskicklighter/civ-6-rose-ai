-- ============================================================================
-- Rose AI: strategy definitions (Types, Strategies, StrategyConditions).
-- Their lists live in Rose_Strategy_Lists.sql (war and austerity strategies)
-- and with their subject under Economy/ (the era-onward strategies).
-- AGENTS.md "## Current Features", "### strategies/ (Rose_Strategies.sql, Rose_Strategy_Lists.sql)".
-- ============================================================================

-- Information era strategy, which the base game omits; kept; inert while no
-- list is attached to it; AGENTS.md "STRATEGY_INFORMATION_CHANGES"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_INFORMATION_CHANGES', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_INFORMATION_CHANGES', 1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_INFORMATION_CHANGES', 'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction) VALUES
('STRATEGY_INFORMATION_CHANGES', 'Is Information');

-- Cumulative "this era or later" strategies: an era condition never turns
-- false once reached, so once adopted they never end and their lists add up;
-- AGENTS.md 'Cumulative "era or later" strategies'
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MODERN_ONWARD',      'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 1),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  1),
('STRATEGY_ROSE_MODERN_ONWARD',      1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'Is Not Major', 1),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'Is Not Major', 1),
('STRATEGY_ROSE_MODERN_ONWARD',      'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, ThresholdValue) VALUES
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'Is Renaissance', 1),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'Is Industrial',  1),
('STRATEGY_ROSE_MODERN_ONWARD',      'Is Modern',      1);

-- War strategies (major wars only): At War, Military Recovery (below 70% of
-- the combined enemy strength) and War Advantage (125% or more); AGENTS.md
-- "STRATEGY_ROSE_AT_WAR", "STRATEGY_ROSE_MILITARY_RECOVERY", "STRATEGY_ROSE_WAR_ADVANTAGE"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_AT_WAR',            'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_WAR_ADVANTAGE',      'KIND_VICTORY_STRATEGY');

-- No positive condition and one Forbidden Lua check each: the engine keeps an
-- adopted strategy 20 turns unless a Forbidden condition turns true, so this
-- ends it the turn after its state ends; AGENTS.md "Engine strategy hold"
INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_AT_WAR',            0),
('STRATEGY_ROSE_MILITARY_RECOVERY', 0),
('STRATEGY_ROSE_WAR_ADVANTAGE',     0);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_AT_WAR',            'Is Not Major', 1),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'Is Not Major', 1),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'Is Not Major', 1);

-- ThresholdValue is documentation only: the entry/release percentages are Lua
-- constants in the gameplay scripts (70/85 and 125/110). Change them there.
INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_AT_WAR',            'Call Lua Function', 'RoseForbidStrategyAtWar',            0,   1),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'Call Lua Function', 'RoseForbidStrategyMilitaryRecovery', 70,  1),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'Call Lua Function', 'RoseForbidStrategyWarAdvantage',     125, 1);

-- Austerity (a broke AI) and Austerity At War (also at war with a major), latched
-- by the gameplay scripts; same Forbidden layout, ThresholdValue documentation only;
-- AGENTS.md "STRATEGY_ROSE_AUSTERITY / _AT_WAR"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_AUSTERITY',        'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_AUSTERITY_AT_WAR', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_AUSTERITY',        0),
('STRATEGY_ROSE_AUSTERITY_AT_WAR', 0);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_AUSTERITY',        'Is Not Major', 1),
('STRATEGY_ROSE_AUSTERITY_AT_WAR', 'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_AUSTERITY',        'Call Lua Function', 'RoseForbidStrategyAusterity',      30, 1),
('STRATEGY_ROSE_AUSTERITY_AT_WAR', 'Call Lua Function', 'RoseForbidStrategyAusterityAtWar', 30, 1);

-- "This era only" windows: the base era strategies never end, so per-era lists
-- go here; same Forbidden layout, the Lua check reads the player's era;
-- AGENTS.md "Era window strategies"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_CLASSICAL_ERA',   'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MEDIEVAL_ERA',    'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_RENAISSANCE_ERA', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     0),
('STRATEGY_ROSE_CLASSICAL_ERA',   0),
('STRATEGY_ROSE_MEDIEVAL_ERA',    0),
('STRATEGY_ROSE_RENAISSANCE_ERA', 0);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     'Is Not Major', 1),
('STRATEGY_ROSE_CLASSICAL_ERA',   'Is Not Major', 1),
('STRATEGY_ROSE_MEDIEVAL_ERA',    'Is Not Major', 1),
('STRATEGY_ROSE_RENAISSANCE_ERA', 'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     'Call Lua Function', 'RoseForbidStrategyAncientEra',     0, 1),
('STRATEGY_ROSE_CLASSICAL_ERA',   'Call Lua Function', 'RoseForbidStrategyClassicalEra',   0, 1),
('STRATEGY_ROSE_MEDIEVAL_ERA',    'Call Lua Function', 'RoseForbidStrategyMedievalEra',    0, 1),
('STRATEGY_ROSE_RENAISSANCE_ERA', 'Call Lua Function', 'RoseForbidStrategyRenaissanceEra', 0, 1);

-- Leader windows: a trait and an era range together, which no list can express
-- (a strategy's lists reach every player, a trait's lists every era); same
-- layout; AGENTS.md "Leader era window strategies"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        0),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      0),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 0);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        'Is Not Major', 1),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      'Is Not Major', 1),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        'Call Lua Function', 'RoseForbidStrategyReligiousEarly',      0, 1),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      'Call Lua Function', 'RoseForbidStrategySaladinHolySite',     0, 1),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'Call Lua Function', 'RoseForbidStrategyAvoidHolySitesEarly', 0, 1);
