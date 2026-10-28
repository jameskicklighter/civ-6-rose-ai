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
('STRATEGY_ROSE_MEDIEVAL_ONWARD',    'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MODERN_ONWARD',      'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_MEDIEVAL_ONWARD',    1),
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 1),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  1),
('STRATEGY_ROSE_MODERN_ONWARD',      1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_MEDIEVAL_ONWARD',    'Is Not Major', 1),
('STRATEGY_ROSE_RENAISSANCE_ONWARD', 'Is Not Major', 1),
('STRATEGY_ROSE_INDUSTRIAL_ONWARD',  'Is Not Major', 1),
('STRATEGY_ROSE_MODERN_ONWARD',      'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions (StrategyType, ConditionFunction, ThresholdValue) VALUES
('STRATEGY_ROSE_MEDIEVAL_ONWARD',    'Is Medieval',    1),
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

-- "This era only" windows (and one Medieval-to-Industrial range): the base era
-- strategies never end, so per-era lists go here; same Forbidden layout, the Lua
-- check reads the player's era; AGENTS.md "Era window strategies"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_CLASSICAL_ERA',   'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MEDIEVAL_ERA',    'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_RENAISSANCE_ERA', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MEDIEVAL_TO_INDUSTRIAL', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     0),
('STRATEGY_ROSE_CLASSICAL_ERA',   0),
('STRATEGY_ROSE_MEDIEVAL_ERA',    0),
('STRATEGY_ROSE_RENAISSANCE_ERA', 0),
('STRATEGY_ROSE_MEDIEVAL_TO_INDUSTRIAL', 0);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     'Is Not Major', 1),
('STRATEGY_ROSE_CLASSICAL_ERA',   'Is Not Major', 1),
('STRATEGY_ROSE_MEDIEVAL_ERA',    'Is Not Major', 1),
('STRATEGY_ROSE_RENAISSANCE_ERA', 'Is Not Major', 1),
('STRATEGY_ROSE_MEDIEVAL_TO_INDUSTRIAL', 'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_ANCIENT_ERA',     'Call Lua Function', 'RoseForbidStrategyAncientEra',     0, 1),
('STRATEGY_ROSE_CLASSICAL_ERA',   'Call Lua Function', 'RoseForbidStrategyClassicalEra',   0, 1),
('STRATEGY_ROSE_MEDIEVAL_ERA',    'Call Lua Function', 'RoseForbidStrategyMedievalEra',    0, 1),
('STRATEGY_ROSE_RENAISSANCE_ERA', 'Call Lua Function', 'RoseForbidStrategyRenaissanceEra', 0, 1),
('STRATEGY_ROSE_MEDIEVAL_TO_INDUSTRIAL', 'Call Lua Function', 'RoseForbidStrategyMedievalToIndustrial', 0, 1);

-- Leader windows: a trait and an era range together, which no list can express
-- (a strategy's lists reach every player, a trait's lists every era); same
-- layout; AGENTS.md "Leader era window strategies"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_RELIGIOUS_HOLY_SITE',    'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_SCIENCE_LEADER_LATE',    'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_CULTURE_LEADER_LATE',    'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_GOLDEN_CLASSICAL',       'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_GOLDEN_MEDIEVAL',        'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_GOLDEN_RENAISSANCE',     'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_RELIGIOUS_FOUNDED',       'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded) VALUES
('STRATEGY_ROSE_GOLDEN_CLASSICAL',       0),
('STRATEGY_ROSE_GOLDEN_MEDIEVAL',        0),
('STRATEGY_ROSE_GOLDEN_RENAISSANCE',     0),
('STRATEGY_ROSE_RELIGIOUS_FOUNDED',       0),
('STRATEGY_ROSE_RELIGIOUS_EARLY',        0),
('STRATEGY_ROSE_RELIGIOUS_HOLY_SITE',    0),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      0),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 0),
('STRATEGY_ROSE_SCIENCE_LEADER_LATE',    0),
('STRATEGY_ROSE_CULTURE_LEADER_LATE',    0);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, Disqualifier) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        'Is Not Major', 1),
('STRATEGY_ROSE_RELIGIOUS_HOLY_SITE',    'Is Not Major', 1),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      'Is Not Major', 1),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'Is Not Major', 1),
('STRATEGY_ROSE_SCIENCE_LEADER_LATE',    'Is Not Major', 1),
('STRATEGY_ROSE_CULTURE_LEADER_LATE',    'Is Not Major', 1),
('STRATEGY_ROSE_GOLDEN_CLASSICAL',       'Is Not Major', 1),
('STRATEGY_ROSE_GOLDEN_MEDIEVAL',        'Is Not Major', 1),
('STRATEGY_ROSE_GOLDEN_RENAISSANCE',     'Is Not Major', 1),
('STRATEGY_ROSE_RELIGIOUS_FOUNDED',       'Is Not Major', 1);

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',        'Call Lua Function', 'RoseForbidStrategyReligiousEarly',      0, 1),
('STRATEGY_ROSE_RELIGIOUS_HOLY_SITE',    'Call Lua Function', 'RoseForbidStrategyReligiousHolySite',   0, 1),
('STRATEGY_ROSE_SALADIN_HOLY_SITE',      'Call Lua Function', 'RoseForbidStrategySaladinHolySite',     0, 1),
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'Call Lua Function', 'RoseForbidStrategyAvoidHolySitesEarly', 0, 1),
('STRATEGY_ROSE_SCIENCE_LEADER_LATE',    'Call Lua Function', 'RoseForbidStrategyScienceLeaderLate',   0, 1),
('STRATEGY_ROSE_CULTURE_LEADER_LATE',    'Call Lua Function', 'RoseForbidStrategyCultureLeaderLate',   0, 1),
('STRATEGY_ROSE_GOLDEN_CLASSICAL',       'Call Lua Function', 'RoseForbidStrategyGoldenClassical',     0, 1),
('STRATEGY_ROSE_GOLDEN_MEDIEVAL',        'Call Lua Function', 'RoseForbidStrategyGoldenMedieval',      0, 1),
('STRATEGY_ROSE_GOLDEN_RENAISSANCE',     'Call Lua Function', 'RoseForbidStrategyGoldenRenaissance',   0, 1),
('STRATEGY_ROSE_RELIGIOUS_FOUNDED',       'Call Lua Function', 'RoseForbidStrategyReligiousFounded',    0, 1);

-- Golden Age flag: the player property ROSE_GOLDEN_AGE, held while the base
-- PLAYER_HAS_GOLDEN_AGE requirement is (Heroic Ages included), for the Golden
-- Age windows to read, since gameplay Lua has no age read; AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
SELECT 'ROSE_GOLDEN_AGE_FLAG', 'MODIFIER_PLAYER_ADJUST_PROPERTY', 'PLAYER_HAS_GOLDEN_AGE'
WHERE EXISTS (SELECT 1 FROM RequirementSets WHERE RequirementSetId = 'PLAYER_HAS_GOLDEN_AGE');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
SELECT 'ROSE_GOLDEN_AGE_FLAG', 'Key', 'ROSE_GOLDEN_AGE'
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = 'ROSE_GOLDEN_AGE_FLAG')
UNION ALL
SELECT 'ROSE_GOLDEN_AGE_FLAG', 'Amount', 1
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = 'ROSE_GOLDEN_AGE_FLAG');

INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId)
SELECT 'TRAIT_LEADER_MAJOR_CIV', 'ROSE_GOLDEN_AGE_FLAG'
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = 'ROSE_GOLDEN_AGE_FLAG');

-- Religious Victory needs all three of its conditions (religious leaders two,
-- through their base -1), so a founded religion is one of them for every other
-- leader: its Faith city and unconverted-cities conditions hold from the start;
-- AGENTS.md "Religious Victory needs a religion"
UPDATE Strategies SET NumConditionsNeeded = 3
WHERE StrategyType = 'VICTORY_STRATEGY_RELIGIOUS_VICTORY' AND NumConditionsNeeded = 2;

-- Focus strategies: copies of the base Science and Culture Victory strategies
-- (conditions needed and every non-Exclusive condition row, read from the base
-- rows) that a Forbidden Lua check holds off before the Renaissance era, since
-- no list can be both strategy- and era-limited; AGENTS.md "Focus strategies"
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_SCIENCE_FOCUS', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_CULTURE_FOCUS', 'KIND_VICTORY_STRATEGY');

INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded)
SELECT 'STRATEGY_ROSE_SCIENCE_FOCUS', NumConditionsNeeded FROM Strategies
WHERE StrategyType = 'VICTORY_STRATEGY_SCIENCE_VICTORY';
INSERT OR IGNORE INTO Strategies (StrategyType, NumConditionsNeeded)
SELECT 'STRATEGY_ROSE_CULTURE_FOCUS', NumConditionsNeeded FROM Strategies
WHERE StrategyType = 'VICTORY_STRATEGY_CULTURAL_VICTORY';

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden, Disqualifier, Exclusive)
SELECT 'STRATEGY_ROSE_SCIENCE_FOCUS', ConditionFunction, StringValue, ThresholdValue, Forbidden, Disqualifier, Exclusive
FROM StrategyConditions
WHERE StrategyType = 'VICTORY_STRATEGY_SCIENCE_VICTORY' AND Exclusive = 0;
INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden, Disqualifier, Exclusive)
SELECT 'STRATEGY_ROSE_CULTURE_FOCUS', ConditionFunction, StringValue, ThresholdValue, Forbidden, Disqualifier, Exclusive
FROM StrategyConditions
WHERE StrategyType = 'VICTORY_STRATEGY_CULTURAL_VICTORY' AND Exclusive = 0;

INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_SCIENCE_FOCUS', 'Call Lua Function', 'RoseForbidStrategyRenaissanceOnward', 0, 1),
('STRATEGY_ROSE_CULTURE_FOCUS', 'Call Lua Function', 'RoseForbidStrategyRenaissanceOnward', 0, 1);

-- Flat Earther agenda: the Science focus copy barred, as the base agenda list
-- bars Science Victory (a Strategies Value adds to the conditions needed);
-- AGENTS.md "Focus strategies"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseFlatEartherFocus');
INSERT OR IGNORE INTO AiLists (ListType, AgendaType, System) VALUES
('RoseFlatEartherFocus', 'TRAIT_AGENDA_FLAT_EARTHER', 'Strategies');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseFlatEartherFocus', 'STRATEGY_ROSE_SCIENCE_FOCUS', 1, 5);
