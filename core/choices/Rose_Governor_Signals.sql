-- ============================================================================
-- Rose AI: governor promotion entries of the inactive choice-signal registry
-- and their modifiers. The governor tables exist only in the Rise and Fall
-- and Gathering Storm rulesets, so the manifest loads this file in its own
-- component after the main one, whose files define the registry and the
-- never-active requirements reused here.
-- AGENTS.md "### choices/Rose_Governor_Signals.sql".
-- ============================================================================

-- Pingala: flat Science and Culture in his city on his base ability, which
-- the appointment score reads, and on his two citizen promotions; flat, so
-- every city gains the same and his native per-city scores still choose
-- where he goes; both the owner and the subject set contradict themselves,
-- so none applies in play; AGENTS.md "Pingala signals"
WITH Signals (Suffix, SourceType, Amount, YieldType) AS (VALUES
('_SCIENCE', 'GOVERNOR_PROMOTION_EDUCATOR_LIBRARIAN',   4, 'YIELD_SCIENCE'),
('_CULTURE', 'GOVERNOR_PROMOTION_EDUCATOR_LIBRARIAN',   4, 'YIELD_CULTURE'),
('',         'GOVERNOR_PROMOTION_EDUCATOR_CONNOISSEUR', 4, 'YIELD_CULTURE'),
('',         'GOVERNOR_PROMOTION_EDUCATOR_RESEARCHER',  4, 'YIELD_SCIENCE')
)
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT 'ROSE_CHOICE_' || s.SourceType || s.Suffix, 'GOVERNOR_PROMOTION', s.SourceType, s.Amount, 'ALWAYS', s.YieldType
FROM Signals s
JOIN GovernorPromotions source ON source.GovernorPromotionType = s.SourceType;

-- Owner sets: having and lacking Future Civic (TEST_ALL: nothing passes);
-- the subject set is the same contradiction (Rose_Policy_Signals.sql), which
-- the scorer reads as empty; AGENTS.md "Pingala signals"
INSERT INTO RequirementSets (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'REQUIREMENTSET_TEST_ALL'
FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION';

INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_HAS_FUTURE_CIVIC'
FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION'
UNION ALL
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_LACKS_FUTURE_CIVIC'
FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION';

-- One modifier per signal, a flat yield in the governor's city, attached to
-- its promotion; AGENTS.md "Pingala signals"
INSERT INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId, SubjectRequirementSetId)
SELECT BiasId, 'MODIFIER_SINGLE_CITY_ADJUST_YIELD_CHANGE',
       'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_NEVER_ACTIVE'
FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION';

INSERT INTO ModifierArguments (ModifierId, Name, Value)
SELECT BiasId, 'Amount', Amount FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION'
UNION ALL
SELECT BiasId, 'YieldType', YieldType FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION';

INSERT INTO GovernorPromotionModifiers (GovernorPromotionType, ModifierId)
SELECT SourceType, BiasId FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNOR_PROMOTION';
