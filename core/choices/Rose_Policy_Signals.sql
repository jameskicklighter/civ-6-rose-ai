-- ============================================================================
-- Rose AI: policy and government entries of the inactive choice-signal
-- registry (Rose_Belief_Signals.sql), then every registered signal's
-- requirements, modifier and attachment. The AI choice scorer reads only
-- SubjectRequirementSetId and only its registered requirement types; the
-- impossible owner gates keep every signal inactive in gameplay.
-- AGENTS.md "### choices/Rose_Policy_Signals.sql", "AI scorer requirement rule".
-- ============================================================================

-- Adjacency cards: +5 of the card's yield per point of the district's
-- adjacency yield in each city, up to 10 points, as ten +5 tiers (adjacency
-- 1 or more, 2 or more, ... 10 or more; the tier is GateValue); combined
-- cards get tiers per district (both add up);
-- AGENTS.md "Adjacency cards", "Inclusive OR replacements"
WITH AdjacencyCards (CardId, SourceType, YieldType) AS (VALUES
('ROSE_CHOICE_POLICY_NATURAL_PHILOSOPHY', 'POLICY_NATURAL_PHILOSOPHY', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_SCRIPTURE', 'POLICY_SCRIPTURE', 'YIELD_FAITH'),
('ROSE_CHOICE_POLICY_AESTHETICS', 'POLICY_AESTHETICS', 'YIELD_CULTURE'),
('ROSE_CHOICE_POLICY_TOWN_CHARTERS', 'POLICY_TOWN_CHARTERS', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_NAVAL_INFRASTRUCTURE', 'POLICY_NAVAL_INFRASTRUCTURE', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_CRAFTSMEN', 'POLICY_CRAFTSMEN', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_SCIENCE', 'POLICY_FIVE_YEAR_PLAN', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_PRODUCTION', 'POLICY_FIVE_YEAR_PLAN', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_COMMERCIAL', 'POLICY_ECONOMIC_UNION', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_HARBOR', 'POLICY_ECONOMIC_UNION', 'YIELD_GOLD')
),
Tiers (Tier) AS (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10))
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, GateValue, YieldType)
SELECT c.CardId || '_ADJ' || t.Tier, 'POLICY', c.SourceType, 5, 'ADJACENCY', t.Tier, c.YieldType
FROM AdjacencyCards c
CROSS JOIN Tiers t
JOIN Policies source ON source.PolicyType = c.SourceType;

-- Serfdom and Public Works: one player envoy signal each, sized to keep the
-- Builder charge card slotted against the adjacency cards;
-- AGENTS.md "Serfdom/Public Works"
WITH ChoiceSources (BiasId, SourceType, Amount, GateType, YieldType) AS (VALUES
('ROSE_CHOICE_POLICY_SERFDOM', 'POLICY_SERFDOM', 3, 'ALWAYS', NULL),
('ROSE_CHOICE_POLICY_PUBLIC_WORKS', 'POLICY_PUBLIC_WORKS', 5, 'ALWAYS', NULL)
)
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT b.BiasId, 'POLICY', b.SourceType, b.Amount, b.GateType, b.YieldType
FROM ChoiceSources b
JOIN Policies source ON source.PolicyType = b.SourceType;

-- Government envoy signals: Theocracy for religion founders, Monarchy and
-- Merchant Republic for the others, tier 3 generic and leader-specific, tier 4;
-- the owner conditions are not proven chooser gates; AGENTS.md "Government signals unchanged"
WITH ChoiceSources (BiasId, SourceKind, SourceType, Amount, GateType, GateValue) AS (VALUES
('ROSE_CHOICE_GOV_MONARCHY_NON_FOUNDER',
 'GOVERNMENT', 'GOVERNMENT_MONARCHY', 1, 'NON_FOUNDER', NULL),
('ROSE_CHOICE_GOV_MERCHANT_REPUBLIC_NON_FOUNDER',
 'GOVERNMENT', 'GOVERNMENT_MERCHANT_REPUBLIC', 1, 'NON_FOUNDER', NULL),
('ROSE_CHOICE_GOV_THEOCRACY_FOUNDER',
 'GOVERNMENT', 'GOVERNMENT_THEOCRACY', 1, 'FOUNDER', NULL),
('ROSE_CHOICE_GOV_COMMUNISM_GENERIC',
 'GOVERNMENT', 'GOVERNMENT_COMMUNISM', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_GOV_DEMOCRACY_GENERIC',
 'GOVERNMENT', 'GOVERNMENT_DEMOCRACY', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_GOV_FASCISM_GENERIC',
 'GOVERNMENT', 'GOVERNMENT_FASCISM', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_GOV_COMMUNISM_SCIENCE',
 'GOVERNMENT', 'GOVERNMENT_COMMUNISM', 1, 'LEADER_TRAIT',
 'TRAIT_LEADER_SCIENCE_MAJOR_CIV'),
('ROSE_CHOICE_GOV_DEMOCRACY_CULTURE',
 'GOVERNMENT', 'GOVERNMENT_DEMOCRACY', 1, 'LEADER_TRAIT',
 'TRAIT_LEADER_CULTURAL_MAJOR_CIV'),
('ROSE_CHOICE_GOV_FASCISM_MILITARY',
 'GOVERNMENT', 'GOVERNMENT_FASCISM', 1, 'LEADER_TRAIT',
 'TRAIT_LEADER_AGGRESSIVE_MILITARY'),
('ROSE_CHOICE_GOV_CORPORATE_LIBERTARIANISM',
 'GOVERNMENT', 'GOVERNMENT_CORPORATE_LIBERTARIANISM', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_GOV_DIGITAL_DEMOCRACY',
 'GOVERNMENT', 'GOVERNMENT_DIGITAL_DEMOCRACY', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_GOV_SYNTHETIC_TECHNOCRACY',
 'GOVERNMENT', 'GOVERNMENT_SYNTHETIC_TECHNOCRACY', 1, 'ALWAYS', NULL)
)
INSERT INTO RoseChoiceBiases
    (BiasId, SourceKind, SourceType, Amount, GateType, GateValue)
SELECT b.* FROM ChoiceSources b
WHERE ((b.SourceKind = 'POLICY' AND EXISTS
        (SELECT 1 FROM Policies WHERE PolicyType = b.SourceType))
    OR (b.SourceKind = 'GOVERNMENT' AND EXISTS
        (SELECT 1 FROM Governments WHERE GovernmentType = b.SourceType)))
  AND (b.GateType <> 'LEADER_TRAIT' OR EXISTS
       (SELECT 1 FROM Traits WHERE TraitType = b.GateValue));

-- Minimum adjacency of an adjacency gate without a tier of its own (Work
-- Ethic); AGENTS.md "Follower-belief yield signals"
INSERT INTO GlobalParameters (Name, Value) VALUES
('ROSE_CHOICE_MIN_ADJACENCY', '3');

-- District gates of the cards (the yield is the adjacency to test), one per
-- tier, then resolved to the districts present; AGENTS.md "Adjacency cards"
WITH DistrictGates (CardId, DistrictType, YieldType) AS (VALUES
('ROSE_CHOICE_POLICY_NATURAL_PHILOSOPHY', 'DISTRICT_CAMPUS', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_SCRIPTURE', 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'),
('ROSE_CHOICE_POLICY_AESTHETICS', 'DISTRICT_THEATER', 'YIELD_CULTURE'),
('ROSE_CHOICE_POLICY_TOWN_CHARTERS', 'DISTRICT_COMMERCIAL_HUB', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_NAVAL_INFRASTRUCTURE', 'DISTRICT_HARBOR', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_CRAFTSMEN', 'DISTRICT_INDUSTRIAL_ZONE', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_SCIENCE', 'DISTRICT_CAMPUS', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_PRODUCTION', 'DISTRICT_INDUSTRIAL_ZONE', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_COMMERCIAL', 'DISTRICT_COMMERCIAL_HUB', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_HARBOR', 'DISTRICT_HARBOR', 'YIELD_GOLD')
)
INSERT INTO RoseChoiceDistricts (BiasId, DistrictType, YieldType)
SELECT b.BiasId, d.DistrictType, d.YieldType FROM DistrictGates d
JOIN RoseChoiceBiases b ON b.BiasId = d.CardId || '_ADJ' || b.GateValue;

-- Base districts only: the scorer's district requirements also match their
-- unique replacements; AGENTS.md "Card value shown by Extended Policy Cards"
INSERT INTO RoseChoiceResolvedDistricts (BiasId, DistrictType, YieldType)
SELECT gate.* FROM RoseChoiceDistricts gate
JOIN Districts d ON d.DistrictType = gate.DistrictType;

-- A district signal without its district would have a gate the scorer sees
-- empty, which passes every city: drop it; AGENTS.md "AI scorer requirement rule"
DELETE FROM RoseChoiceBiases
WHERE GateType IN ('ADJACENCY', 'HOLY_SITE')
  AND BiasId NOT IN (SELECT BiasId FROM RoseChoiceResolvedDistricts);

-- City subject gates: TEST_ALL of the high-adjacency or presence requirement
-- and "has Future Civic" (added below). The scorer drops the unregistered civic
-- requirement and sees the district test alone; Real Modifier Analysis
-- (Extended Policy Cards' card values) fails it and leaves the signal out;
-- AGENTS.md "Adjacency cards", "Follower-belief yield signals",
-- "Card value shown by Extended Policy Cards"
INSERT INTO RequirementSets (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId, 'REQUIREMENTSET_TEST_ALL'
FROM RoseChoiceBiases WHERE GateType IN ('ADJACENCY', 'HOLY_SITE');

INSERT INTO Requirements (RequirementId, RequirementType)
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       CASE WHEN b.GateType = 'ADJACENCY' THEN 'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'
            ELSE 'REQUIREMENT_CITY_HAS_DISTRICT' END
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId;

INSERT INTO RequirementArguments (RequirementId, Name, Value)
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'DistrictType', gate.DistrictType
FROM RoseChoiceResolvedDistricts gate
UNION ALL
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'YieldType', gate.YieldType
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId WHERE b.GateType = 'ADJACENCY'
UNION ALL
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'Amount', COALESCE(b.GateValue,
           (SELECT Value FROM GlobalParameters WHERE Name = 'ROSE_CHOICE_MIN_ADJACENCY'))
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId WHERE b.GateType = 'ADJACENCY';

INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId,
       'ROSE_CHOICE_REQ_DISTRICT_' || BiasId || '_' || DistrictType
FROM RoseChoiceResolvedDistricts;

-- Government owner eligibility (founder, non-founder, leader trait), kept
-- although the scorer skips owner requirements; AGENTS.md "Government signals unchanged"
INSERT INTO Requirements (RequirementId, RequirementType, Inverse)
SELECT 'ROSE_CHOICE_REQ_GATE_' || BiasId, 'REQUIREMENT_PLAYER_IS_RELIGION_FOUNDER',
       CASE WHEN GateType = 'FOUNDER' THEN 0 ELSE 1 END
FROM RoseChoiceBiases WHERE GateType IN ('FOUNDER', 'NON_FOUNDER');

INSERT INTO Requirements (RequirementId, RequirementType)
SELECT 'ROSE_CHOICE_REQ_GATE_' || BiasId, 'REQUIREMENT_PLAYER_HAS_CIVILIZATION_OR_LEADER_TRAIT'
FROM RoseChoiceBiases WHERE GateType = 'LEADER_TRAIT';

INSERT INTO RequirementArguments (RequirementId, Name, Value)
SELECT 'ROSE_CHOICE_REQ_GATE_' || BiasId, 'TraitType', GateValue
FROM RoseChoiceBiases WHERE GateType = 'LEADER_TRAIT';

-- Owner sets: AI only, the eligibility above, and for yield signals both
-- having and lacking Future Civic (TEST_ALL: no player passes);
-- AGENTS.md "Inactive preference signals"
INSERT INTO Requirements (RequirementId, RequirementType, Inverse) VALUES
('ROSE_CHOICE_REQ_AI', 'REQUIREMENT_PLAYER_IS_HUMAN', 1),
('ROSE_CHOICE_HAS_FUTURE_CIVIC', 'REQUIREMENT_PLAYER_HAS_CIVIC', 0),
('ROSE_CHOICE_LACKS_FUTURE_CIVIC', 'REQUIREMENT_PLAYER_HAS_CIVIC', 1);

INSERT INTO RequirementArguments (RequirementId, Name, Value) VALUES
('ROSE_CHOICE_HAS_FUTURE_CIVIC', 'CivicType', 'CIVIC_FUTURE_CIVIC'),
('ROSE_CHOICE_LACKS_FUTURE_CIVIC', 'CivicType', 'CIVIC_FUTURE_CIVIC');

INSERT INTO RequirementSets (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'REQUIREMENTSET_TEST_ALL' FROM RoseChoiceBiases;

INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_REQ_AI' FROM RoseChoiceBiases
UNION ALL
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_REQ_GATE_' || BiasId
FROM RoseChoiceBiases WHERE GateType IN ('FOUNDER', 'NON_FOUNDER', 'LEADER_TRAIT')
UNION ALL
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_HAS_FUTURE_CIVIC'
FROM RoseChoiceBiases WHERE YieldType IS NOT NULL
UNION ALL
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_LACKS_FUTURE_CIVIC'
FROM RoseChoiceBiases WHERE YieldType IS NOT NULL;

-- The same contradiction as a subject set for the envoy signals, whose
-- impossible gate sits on the subject (PLAYER_HAS_CIVIC is unregistered in the
-- scorer, so it still scores them); AGENTS.md "Government signals unchanged"
INSERT INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES
('ROSE_CHOICE_NEVER_ACTIVE', 'REQUIREMENTSET_TEST_ALL');
INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES
('ROSE_CHOICE_NEVER_ACTIVE', 'ROSE_CHOICE_HAS_FUTURE_CIVIC'),
('ROSE_CHOICE_NEVER_ACTIVE', 'ROSE_CHOICE_LACKS_FUTURE_CIVIC');

-- The second requirement of the city district gates (above);
-- AGENTS.md "Card value shown by Extended Policy Cards"
INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId, 'ROSE_CHOICE_HAS_FUTURE_CIVIC'
FROM RoseChoiceBiases WHERE GateType IN ('ADJACENCY', 'HOLY_SITE');

-- One modifier per signal with its arguments, attached to its policy,
-- government or belief; AGENTS.md "Inactive choice registry"
INSERT INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId, SubjectRequirementSetId)
SELECT BiasId,
       CASE WHEN YieldType IS NOT NULL THEN 'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE'
            ELSE 'MODIFIER_PLAYER_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN' END,
       'ROSE_CHOICE_OWNER_' || BiasId,
       CASE WHEN GateType IN ('ADJACENCY', 'HOLY_SITE') THEN 'ROSE_CHOICE_CITY_GATE_' || BiasId
            ELSE 'ROSE_CHOICE_NEVER_ACTIVE' END
FROM RoseChoiceBiases;

INSERT INTO ModifierArguments (ModifierId, Name, Value)
SELECT BiasId, 'Amount', Amount FROM RoseChoiceBiases
UNION ALL
SELECT BiasId, 'YieldType', YieldType FROM RoseChoiceBiases WHERE YieldType IS NOT NULL;

INSERT INTO PolicyModifiers (PolicyType, ModifierId)
SELECT SourceType, BiasId FROM RoseChoiceBiases WHERE SourceKind = 'POLICY';
INSERT INTO GovernmentModifiers (GovernmentType, ModifierId)
SELECT SourceType, BiasId FROM RoseChoiceBiases WHERE SourceKind = 'GOVERNMENT';
INSERT INTO BeliefModifiers (BeliefType, ModifierId)
SELECT SourceType, BiasId FROM RoseChoiceBiases WHERE SourceKind = 'BELIEF';
