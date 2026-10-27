-- ============================================================================
-- Rose AI: unit priorities and the AI-only unit modifiers (Prince and above,
-- through the base requirement set PLAYER_IS_HIGH_DIFFICULTY_AI).
-- AGENTS.md "## Current Features", "### economy/Rose_Units.sql".
-- ============================================================================

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
