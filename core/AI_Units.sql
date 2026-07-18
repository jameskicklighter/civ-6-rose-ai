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
