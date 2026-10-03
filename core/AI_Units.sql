-- ============================================================================
-- Rose AI: Unit Priorities
-- Builders favored in Medieval and Renaissance eras to coincide with Serfdom
-- policy (+2 Builder charges) and general improvement needs.
-- ============================================================================

-- Declare list types
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalUnits'),
('RoseRenaissanceUnits');

-- Map to Units system
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalUnits',     'Units'),
('RoseRenaissanceUnits',  'Units');

-- Link to era strategies
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalUnits'),
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceUnits');

-- Populate — Builders favored so AI invests in improvements
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalUnits',     'UNIT_BUILDER', 1, 100),
('RoseRenaissanceUnits',  'UNIT_BUILDER', 1, 100);

-- ============================================================================
-- AI Anti-Barbarian Combat Bonus (+5 strength, Prince difficulty and above)
-- Uses base game requirement set PLAYER_IS_HIGH_DIFFICULTY_AI which combines
-- REQUIRES_PLAYER_IS_AI + REQUIRES_HIGH_DIFFICULTY (Prince+)
-- ============================================================================

INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId) VALUES
('TRAIT_LEADER_MAJOR_CIV', 'ROSE_BARB_COMBAT_AI');

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId) VALUES
('ROSE_BARB_COMBAT_AI', 'MODIFIER_PLAYER_UNITS_ADJUST_BARBARIAN_COMBAT', 'PLAYER_IS_HIGH_DIFFICULTY_AI');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_BARB_COMBAT_AI', 'Amount', 5);

-- ============================================================================
-- No early Great Person patronage for AI (test, 2026-10-03)
-- AIs sometimes bought a Great Prophet outright with Faith or Gold early, even
-- without a Holy Site. No game effect blocks a single Great Person class (the
-- per-class ExcludedGreatPersonClasses would also remove points and religion
-- founding), so AI players may not patronize any Great Person with Gold or
-- Faith while the game era is Ancient or Classical. Great Person points still
-- accrue, so an AI with a Holy Site still earns its prophet. Humans are
-- unaffected (REQUIRES_PLAYER_IS_AI is the base "not human" requirement).
--
-- MODIFIER_PLAYER_DISABLE_PATRONAGE (Gathering Storm/Rise and Fall) is unused
-- by shipped data. Its effect reads 'Disable' (bool, default false) and
-- 'YieldType' (GameCore_XP2 0x7FE760), one currency per modifier. The rows are
-- skipped if the effect is missing. Rose_AI_InGame.lua logs each AI's block.
-- ============================================================================

INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType, Inverse) VALUES
('ROSE_REQ_GAME_ERA_BEFORE_MEDIEVAL', 'REQUIREMENT_GAME_ERA_ATLEAST_EXPANSION', 1);

INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value) VALUES
('ROSE_REQ_GAME_ERA_BEFORE_MEDIEVAL', 'EraType', 'ERA_MEDIEVAL');

INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES
('ROSE_AI_BEFORE_MEDIEVAL', 'REQUIREMENTSET_TEST_ALL');

INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES
('ROSE_AI_BEFORE_MEDIEVAL', 'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_BEFORE_MEDIEVAL', 'ROSE_REQ_GAME_ERA_BEFORE_MEDIEVAL');

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
SELECT Patronage.ModifierId, 'MODIFIER_PLAYER_DISABLE_PATRONAGE', 'ROSE_AI_BEFORE_MEDIEVAL'
FROM (SELECT 'ROSE_AI_NO_EARLY_PATRONAGE_GOLD' AS ModifierId
      UNION ALL SELECT 'ROSE_AI_NO_EARLY_PATRONAGE_FAITH') AS Patronage
WHERE EXISTS (SELECT 1 FROM DynamicModifiers
              WHERE ModifierType = 'MODIFIER_PLAYER_DISABLE_PATRONAGE');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
SELECT Args.ModifierId, Args.Name, Args.Value
FROM (SELECT 'ROSE_AI_NO_EARLY_PATRONAGE_GOLD' AS ModifierId, 'YieldType' AS Name, 'YIELD_GOLD' AS Value
      UNION ALL SELECT 'ROSE_AI_NO_EARLY_PATRONAGE_GOLD', 'Disable', 'true'
      UNION ALL SELECT 'ROSE_AI_NO_EARLY_PATRONAGE_FAITH', 'YieldType', 'YIELD_FAITH'
      UNION ALL SELECT 'ROSE_AI_NO_EARLY_PATRONAGE_FAITH', 'Disable', 'true') AS Args
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = Args.ModifierId);

INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId)
SELECT 'TRAIT_LEADER_MAJOR_CIV', ModifierId
FROM Modifiers
WHERE ModifierId IN ('ROSE_AI_NO_EARLY_PATRONAGE_GOLD', 'ROSE_AI_NO_EARLY_PATRONAGE_FAITH');
