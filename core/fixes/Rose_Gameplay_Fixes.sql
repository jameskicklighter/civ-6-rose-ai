-- ============================================================================
-- Rose AI: repairs to base-game gameplay bugs that hit every player, human and
-- AI alike (Alpine Training, Hagia Sophia, Strategic Air Force, Great General
-- auras on all-era units, Arrow Storm and Urban Raider, Babylon Great Works,
-- Ibn Khaldun). Overlaps the Real Fixes mod; safe to run alongside it (every
-- statement matches the old value or checks that its target is missing, so it
-- is a no-op when Real Fixes already ran). Inserts check that their targets
-- exist, so a ruleset without a DLC loads cleanly.
-- AGENTS.md "## Current Features", "Base-game gameplay fixes".
-- ============================================================================

-- Alpine Training also covers War-Carts and Warrior Monks;
-- AGENTS.md "Base-game gameplay fixes"
INSERT OR IGNORE INTO TypeTags (Type, Tag)
SELECT 'ABILITY_ALPINE_TRAINING', 'CLASS_HEAVY_CHARIOT'
WHERE EXISTS (SELECT 1 FROM Types WHERE Type = 'ABILITY_ALPINE_TRAINING')
  AND EXISTS (SELECT 1 FROM Tags WHERE Tag = 'CLASS_HEAVY_CHARIOT');
INSERT OR IGNORE INTO TypeTags (Type, Tag)
SELECT 'ABILITY_ALPINE_TRAINING', 'CLASS_WARRIOR_MONK'
WHERE EXISTS (SELECT 1 FROM Types WHERE Type = 'ABILITY_ALPINE_TRAINING')
  AND EXISTS (SELECT 1 FROM Tags WHERE Tag = 'CLASS_WARRIOR_MONK');

-- Hagia Sophia's extra religious charges apply only to Missionaries and
-- Apostles, not to every unit; AGENTS.md "Base-game gameplay fixes"
INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType)
SELECT 'ROSE_HAGIA_SOPHIA_UNITS', 'REQUIREMENTSET_TEST_ANY'
WHERE EXISTS (SELECT 1 FROM Modifiers WHERE ModifierId = 'HAGIA_SOPHIA_ADJUST_RELIGIOUS_CHARGES' AND SubjectRequirementSetId IS NULL)
  AND EXISTS (SELECT 1 FROM Requirements WHERE RequirementId = 'REQUIRES_UNIT_IS_MISSIONARY')
  AND EXISTS (SELECT 1 FROM Requirements WHERE RequirementId = 'REQUIRES_UNIT_IS_APOSTLE');
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_HAGIA_SOPHIA_UNITS', r.RequirementId
FROM Requirements r
WHERE r.RequirementId IN ('REQUIRES_UNIT_IS_MISSIONARY', 'REQUIRES_UNIT_IS_APOSTLE')
  AND EXISTS (SELECT 1 FROM RequirementSets WHERE RequirementSetId = 'ROSE_HAGIA_SOPHIA_UNITS');
UPDATE Modifiers SET SubjectRequirementSetId = 'ROSE_HAGIA_SOPHIA_UNITS'
WHERE ModifierId = 'HAGIA_SOPHIA_ADJUST_RELIGIOUS_CHARGES'
  AND SubjectRequirementSetId IS NULL
  AND EXISTS (SELECT 1 FROM RequirementSets WHERE RequirementSetId = 'ROSE_HAGIA_SOPHIA_UNITS');

-- Strategic Air Force loses its Atomic-era carrier bonus and its Information-era
-- bonuses lose their era restriction (only with Gathering Storm, which adds the Dam);
-- AGENTS.md "Base-game gameplay fixes"
DELETE FROM ModifierArguments WHERE ModifierId = 'STRATEGICAIRFORCE_ATOMIC_NAVALCARRIER_PRODUCTION'
  AND EXISTS (SELECT 1 FROM Types WHERE Type = 'DISTRICT_DAM');
DELETE FROM PolicyModifiers WHERE PolicyType = 'POLICY_STRATEGIC_AIR_FORCE' AND ModifierId = 'STRATEGICAIRFORCE_ATOMIC_NAVALCARRIER_PRODUCTION'
  AND EXISTS (SELECT 1 FROM Types WHERE Type = 'DISTRICT_DAM');
DELETE FROM Modifiers WHERE ModifierId = 'STRATEGICAIRFORCE_ATOMIC_NAVALCARRIER_PRODUCTION'
  AND EXISTS (SELECT 1 FROM Types WHERE Type = 'DISTRICT_DAM');
UPDATE ModifierArguments SET Value = 'NO_ERA'
WHERE Name = 'EraType' AND Value <> 'NO_ERA'
  AND ModifierId IN (SELECT ModifierId FROM PolicyModifiers WHERE PolicyType = 'POLICY_STRATEGIC_AIR_FORCE')
  AND EXISTS (SELECT 1 FROM Types WHERE Type = 'DISTRICT_DAM');

-- Great General and Admiral auras reach units that belong to every era, such as
-- the Warrior Monk; AGENTS.md "Base-game gameplay fixes"
INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType)
SELECT 'ROSE_AOE_REQUIRES_ALL_ERAS_UNIT', 'REQUIREMENT_UNIT_TAG_MATCHES'
WHERE EXISTS (SELECT 1 FROM Tags WHERE Tag = 'CLASS_ALL_ERAS')
  AND NOT EXISTS (SELECT 1 FROM Requirements WHERE RequirementId = 'AOE_REQUIRES_ALL_ERAS_UNIT');
INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value)
SELECT 'ROSE_AOE_REQUIRES_ALL_ERAS_UNIT', 'Tag', 'CLASS_ALL_ERAS'
WHERE EXISTS (SELECT 1 FROM Requirements WHERE RequirementId = 'ROSE_AOE_REQUIRES_ALL_ERAS_UNIT');
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT s.RequirementSetId, 'ROSE_AOE_REQUIRES_ALL_ERAS_UNIT'
FROM RequirementSets s
WHERE s.RequirementSetId IN ('AOE_CLASSICAL_REQUIREMENTS', 'AOE_MEDIEVAL_REQUIREMENTS', 'AOE_RENAISSANCE_REQUIREMENTS',
                             'AOE_INDUSTRIAL_REQUIREMENTS', 'AOE_MODERN_REQUIREMENTS', 'AOE_ATOMIC_REQUIREMENTS',
                             'AOE_INFORMATION_REQUIREMENTS')
  AND EXISTS (SELECT 1 FROM Requirements WHERE RequirementId = 'ROSE_AOE_REQUIRES_ALL_ERAS_UNIT')
  AND NOT EXISTS (SELECT 1 FROM RequirementSetRequirements x WHERE x.RequirementSetId = s.RequirementSetId AND x.RequirementId = 'AOE_REQUIRES_ALL_ERAS_UNIT');
INSERT OR IGNORE INTO TypeTags (Type, Tag)
SELECT 'UNIT_WARRIOR_MONK', 'CLASS_ALL_ERAS'
WHERE EXISTS (SELECT 1 FROM Types WHERE Type = 'UNIT_WARRIOR_MONK')
  AND EXISTS (SELECT 1 FROM Tags WHERE Tag = 'CLASS_ALL_ERAS');

-- Arrow Storm and Urban Raider no longer apply against districts;
-- AGENTS.md "Base-game gameplay fixes"
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT s.RequirementSetId, 'OPPONENT_IS_NOT_DISTRICT'
FROM RequirementSets s
WHERE s.RequirementSetId IN ('ARROW_STORM_REQUIREMENTS', 'URBAN_RAIDER_REQUIREMENTS')
  AND EXISTS (SELECT 1 FROM Requirements WHERE RequirementId = 'OPPONENT_IS_NOT_DISTRICT');

-- The Babylon Great Works of art and writing yield 2 Tourism, and the writing
-- ones 2 Culture (writing: Gathering Storm values only); AGENTS.md "Base-game gameplay fixes"
UPDATE GreatWorks SET Tourism = 2
WHERE GreatWorkObjectType IN ('GREATWORKOBJECT_LANDSCAPE', 'GREATWORKOBJECT_PORTRAIT')
  AND Image LIKE 'ICON_GREATWORK_BABYLON%'
  AND Tourism = 4;
UPDATE GreatWorks SET Tourism = 2
WHERE GreatWorkObjectType = 'GREATWORKOBJECT_WRITING'
  AND GreatWorkType LIKE 'GREATWORK_BABYLON%'
  AND Tourism = 4
  AND EXISTS (SELECT 1 FROM Types WHERE Type = 'DISTRICT_DAM');
UPDATE GreatWork_YieldChanges SET YieldChange = 2
WHERE YieldType = 'YIELD_CULTURE'
  AND YieldChange = 4
  AND GreatWorkType LIKE 'GREATWORK_BABYLON%'
  AND GreatWorkType IN (SELECT GreatWorkType FROM GreatWorks WHERE GreatWorkObjectType = 'GREATWORKOBJECT_WRITING')
  AND EXISTS (SELECT 1 FROM Types WHERE Type = 'DISTRICT_DAM');

-- Ibn Khaldun's Happy and Ecstatic empire yields double (2 to 4, 4 to 8);
-- AGENTS.md "Base-game gameplay fixes"
UPDATE ModifierArguments SET Value = '4'
WHERE Name = 'Amount' AND Value = '2'
  AND ModifierId LIKE 'GREAT_PERSON_INDIVIDUAL_IBN_KHALDUN_EMPIRE_HAPPY_%';
UPDATE ModifierArguments SET Value = '8'
WHERE Name = 'Amount' AND Value = '4'
  AND ModifierId LIKE 'GREAT_PERSON_INDIVIDUAL_IBN_KHALDUN_EMPIRE_ECSTATIC_%';
