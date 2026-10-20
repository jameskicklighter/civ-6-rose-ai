-- ============================================================================
-- Rose AI: unit priorities and the AI-only unit modifiers (Prince and above,
-- through the base requirement set PLAYER_IS_HIGH_DIFFICULTY_AI).
-- AGENTS.md "## Current Features", "### economy/Rose_Units.sql".
-- ============================================================================

-- Medieval: Builders, with Serfdom's extra charges; AGENTS.md "Builders favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalUnits');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalUnits',     'Units');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalUnits');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalUnits',     'UNIT_BUILDER', 1, 100);

-- Renaissance: Builders; AGENTS.md "Builders favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceUnits');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceUnits',  'Units');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceUnits');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceUnits',  'UNIT_BUILDER', 1, 100);

-- +5 combat strength against barbarians for AI majors; AGENTS.md "Anti-barbarian combat bonus"
INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId) VALUES
('TRAIT_LEADER_MAJOR_CIV', 'ROSE_BARB_COMBAT_AI');

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId) VALUES
('ROSE_BARB_COMBAT_AI', 'MODIFIER_PLAYER_UNITS_ADJUST_BARBARIAN_COMBAT', 'PLAYER_IS_HIGH_DIFFICULTY_AI');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_BARB_COMBAT_AI', 'Amount', 5);

-- AI upgrades cost 35% less Gold and 35% fewer strategic resources (the
-- resource modifier exists only with Gathering Storm and is skipped without
-- it); AGENTS.md "AI upgrade discount"
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
