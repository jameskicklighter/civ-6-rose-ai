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
-- AI unit upgrade discount (Prince difficulty and above)
-- AI armies kept obsolete units (Trebuchets beside Field Cannons, Crossbowmen
-- beside Line Infantry in 2026-10 logs). Upgrades cost 35% less Gold and 35%
-- fewer strategic resources, as in RH (LAI_Main3.sql). Stacks with Professional
-- Army (50%). The AI still upgrades only when its Upgrade Units tree runs.
-- Same requirement set as the barbarian bonus above (AI + Prince or higher).
-- The resource discount is Gathering Storm only and is skipped without it.
-- ============================================================================

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId) VALUES
('ROSE_AI_UPGRADE_GOLD_DISCOUNT', 'MODIFIER_PLAYER_ADJUST_UNIT_UPGRADE_DISCOUNT_PERCENT', 'PLAYER_IS_HIGH_DIFFICULTY_AI');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_AI_UPGRADE_GOLD_DISCOUNT', 'Amount', 35);

INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId) VALUES
('TRAIT_LEADER_MAJOR_CIV', 'ROSE_AI_UPGRADE_GOLD_DISCOUNT');

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId)
SELECT 'ROSE_AI_UPGRADE_RESOURCE_DISCOUNT', 'MODIFIER_PLAYER_ADJUST_UNIT_UPGRADE_RESOURCE_COST_MODIFIER', 'PLAYER_IS_HIGH_DIFFICULTY_AI'
WHERE EXISTS (SELECT 1 FROM DynamicModifiers
              WHERE ModifierType = 'MODIFIER_PLAYER_ADJUST_UNIT_UPGRADE_RESOURCE_COST_MODIFIER');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
SELECT 'ROSE_AI_UPGRADE_RESOURCE_DISCOUNT', 'Amount', 35
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = 'ROSE_AI_UPGRADE_RESOURCE_DISCOUNT');

INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId)
SELECT 'TRAIT_LEADER_MAJOR_CIV', 'ROSE_AI_UPGRADE_RESOURCE_DISCOUNT'
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = 'ROSE_AI_UPGRADE_RESOURCE_DISCOUNT');
