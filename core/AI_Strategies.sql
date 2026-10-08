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
-- 1b. CUMULATIVE "ERA OR LATER" STRATEGIES
-- An era condition with ThresholdValue 1 means "this era or later" (base Science
-- Victory uses 'Is Renaissance' this way; RH uses the same form). Once adopted
-- these never end, so their lists add up as eras pass. Per-era strategies stay
-- active up to 20 turns after adoption, so they may overlap the start of the
-- next era; lists that must not stack (AI_Yields.sql section 7) use these.
-- ============================================================================

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

-- ============================================================================
-- 2. DYNAMIC WAR SUSTAINMENT
--
-- These strategies are controlled by Forbidden Call Lua Function conditions
-- implemented in Rose_AI_Gameplay.lua. They respond only to wars against other major
-- civilizations; city-state wars do not redirect the entire economy.
--
-- At War maintains unit replacement and deemphasizes optional infrastructure.
-- It adds no assault slot: an extra slot (tried 2026-10-03) let Gaul run five
-- assaults at once, mostly on city-states, with teams too small to take cities.
-- It also stops new city-state wars and values enemy cities more (see below).
-- Military Recovery stacks when our military is below 70% of the combined
-- opposing strength, trading one assault slot for defense and reconstruction.
-- War Advantage suppresses voluntary peace only while our military is at
-- least 125% of the combined opposing strength.
-- Austerity (section 2b) nudges a broke AI toward income without touching its
-- units or operations.
-- ============================================================================

INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('STRATEGY_ROSE_AT_WAR',            'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'KIND_VICTORY_STRATEGY'),
('STRATEGY_ROSE_WAR_ADVANTAGE',      'KIND_VICTORY_STRATEGY');

-- The engine keeps an adopted strategy for at least 20 turns unless a
-- Forbidden condition becomes true. Each strategy therefore needs no positive
-- condition and is blocked by one Forbidden Lua check whenever it should be
-- inactive, so it ends the turn after its war/strength state ends. A strategy
-- that stops still cannot be re-adopted for 20 turns (engine cooldown).
-- Verified with .scratch/strategy-probe (2026-09-26 test, probe B).
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
-- constants in Rose_AI_Gameplay.lua (70/85 and 125/110). Change them there.
INSERT OR IGNORE INTO StrategyConditions
    (StrategyType, ConditionFunction, StringValue, ThresholdValue, Forbidden) VALUES
('STRATEGY_ROSE_AT_WAR',            'Call Lua Function', 'RoseForbidStrategyAtWar',            0,   1),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'Call Lua Function', 'RoseForbidStrategyMilitaryRecovery', 70,  1),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'Call Lua Function', 'RoseForbidStrategyWarAdvantage',     125, 1);

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAtWarYields'),
('RoseAtWarPseudoYields'),
('RoseMilitaryRecoveryOperations'),
('RoseMilitaryRecoveryYields'),
('RoseMilitaryRecoveryPseudoYields'),
('RoseMilitaryRecoveryBuildings'),
('RoseWarAdvantageDiplomacy'),
('RoseAtWarDiplomacy');

INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAtWarYields',                    'Yields'),
('RoseAtWarPseudoYields',              'PseudoYields'),
('RoseMilitaryRecoveryOperations',     'AiOperationTypes'),
('RoseMilitaryRecoveryYields',         'Yields'),
('RoseMilitaryRecoveryPseudoYields',   'PseudoYields'),
('RoseMilitaryRecoveryBuildings',      'Buildings'),
('RoseWarAdvantageDiplomacy',          'DiplomaticActions'),
('RoseAtWarDiplomacy',                 'DiplomaticActions');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarYields'),
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarPseudoYields'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryOperations'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryYields'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryPseudoYields'),
('STRATEGY_ROSE_MILITARY_RECOVERY', 'RoseMilitaryRecoveryBuildings'),
('STRATEGY_ROSE_WAR_ADVANTAGE',     'RoseWarAdvantageDiplomacy'),
('STRATEGY_ROSE_AT_WAR',            'RoseAtWarDiplomacy');

INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
-- Sustained wartime production and replacement without adding assault slots.
-- Army demand was +20/+10/+10 until 2026-10-04: in that test AIs at war still
-- held 6-9 land units for 8-10 cities (Germany 7 in three wars at turn 100,
-- Sweden 6 with 3,849 Gold at turn 196), so it is raised to +50/+30/+25.
('RoseAtWarYields',       'YIELD_PRODUCTION',                    1,  10),
('RoseAtWarYields',       'YIELD_GOLD',                          1,  10),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',             1,  50),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_UNIT_NAVAL_COMBAT',       1,  15),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER',    1,  30),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',     1,  25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_DISTRICT',                1, -25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_IMPROVEMENT',             1, -25),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_WONDER',                  1, -15),
-- Attack-target value while fighting a major (percent of the defaults: defending
-- units 80, city base 450). Kept on At War so peacetime war desire is
-- unchanged. CITY_DEFENSES is not cut further, but a higher base lifts every
-- enemy city, so it also weakens the frontier-first effect of the defense
-- terms: at the zero clamp +75 acts roughly like a 40% cut to all subtracted
-- terms, and interior cities can score. Walled reach (16 planned, 22 wartime)
-- bounds that. Measure chosen targets' distance against the 2026-10-04 game.
('RoseAtWarPseudoYields', 'PSEUDOYIELD_CITY_DEFENDING_UNITS',    1, -40),
('RoseAtWarPseudoYields', 'PSEUDOYIELD_CITY_BASE',               1,  75),
-- No new city-state wars while fighting a major. Diplomacy skips disfavored
-- actions. Spain's war on Jerusalem (2026-10-04b, turn 45) cut its only trade
-- route and tied up a second assault for 79 turns. Side effect to watch: a
-- planned assault on a city-state we are not at war with can now never get its
-- declaration, so it fails its pre-war limiter and may restart on that target,
-- holding the planned slot (the wartime slot is unaffected).
('RoseAtWarDiplomacy', 'DIPLOACTION_DECLARE_WAR_MINOR_CIV',      0,   0),

-- Recovery stacks with At War and temporarily favors rebuilding over attack.
-- The -1 removes the planned (CITY_ASSAULT) slot; the wartime slot type
-- (ROSE_WARTIME_ASSAULT, AI_BehaviorTreeOps.sql) is left alone, so a
-- recovering AI with one war keeps one assault, now aimed at its war enemy.
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
-- Grand Master's Chapel (tier-2 government building) lets Faith buy land units.
-- Only the two AIs that had it bought armies with Faith in the 2026-10-04 test.
('RoseMilitaryRecoveryBuildings',    'BUILDING_GOV_FAITH',                   1, 100),

-- Strong AIs keep pressing; weak and evenly matched AIs retain normal peace logic.
('RoseWarAdvantageDiplomacy', 'DIPLOACTION_PROPOSE_PEACE_DEAL', 0, 0),
('RoseWarAdvantageDiplomacy', 'DIPLOACTION_MAKE_PEACE',         0, 0);

-- ============================================================================
-- 2b. AUSTERITY (income nudge for a broke AI)
--
-- Spain (2026-10-04b) built 22 land units, declared war on the city-state it
-- traded with, lost its only trade route, then sat at zero Gold for about 40
-- turns while its army shrank to 5. These strategies only shift priorities
-- toward income; they never disband units, change operations or slots, or
-- touch savings. Rose_AI_Gameplay.lua latches austerity when the Gold balance
-- is below 30 and income after maintenance has been negative for two turns,
-- and releases it when the balance is above 100 and income has been positive
-- for three turns, or after ten turns of positive income at any balance. Austerity At War applies only while also at war with a
-- major, and trims part of At War's extra unit demand (+50/+30/+25 becomes
-- +30/+20/+15), so demand stays above the base game's. Exception: if At War
-- is held off by the engine's 20-turn restart cooldown while Austerity At War
-- runs, the trim applies to base demand. Same Forbidden layout as section 2;
-- ThresholdValue is documentation only.
-- ============================================================================

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

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAusterityYields'),
('RoseAusterityPseudoYields'),
('RoseAusterityDistricts'),
('RoseAusterityAtWarPseudoYields');

INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAusterityYields',            'Yields'),
('RoseAusterityPseudoYields',      'PseudoYields'),
('RoseAusterityDistricts',         'Districts'),
('RoseAusterityAtWarPseudoYields', 'PseudoYields');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AUSTERITY',        'RoseAusterityYields'),
('STRATEGY_ROSE_AUSTERITY',        'RoseAusterityPseudoYields'),
('STRATEGY_ROSE_AUSTERITY',        'RoseAusterityDistricts'),
('STRATEGY_ROSE_AUSTERITY_AT_WAR', 'RoseAusterityAtWarPseudoYields');

INSERT OR REPLACE INTO AiFavoredItems
    (ListType, Item, Favored, Value) VALUES
('RoseAusterityYields',            'YIELD_GOLD',                       1,  30),
('RoseAusterityPseudoYields',      'PSEUDOYIELD_UNIT_TRADE',           1,  50),
('RoseAusterityPseudoYields',      'PSEUDOYIELD_WONDER',               1, -25),
('RoseAusterityDistricts',         'DISTRICT_COMMERCIAL_HUB',          1,  50),
('RoseAusterityDistricts',         'DISTRICT_HARBOR',                  1,  50),
('RoseAusterityAtWarPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',          1, -20),
('RoseAusterityAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER', 1, -10),
('RoseAusterityAtWarPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',  1, -10);

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
