-- ============================================================================
-- Rose AI: Scoring-only policy and government choice signals
-- ============================================================================
-- Each signal is an amount-one duplicate-influence-token modifier.  Its owner
-- requirement is AI-only and carries the contextual gate for the source.  Its
-- subject requirement is permanently false, so the modifier contributes no
-- influence, yield, food, science, production, or other gameplay effect.
-- The native chooser's interpretation of this context-owner arrangement is
-- an experiment and must be checked in a fresh game.
-- ============================================================================

-- Retain the retired marker's identity so Lua can remove saved instances.
-- It has no attached modifiers and its unassigned trait blocks construction.
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('TRAIT_ROSE_INTERNAL_BUILDING', 'KIND_TRAIT'),
('BUILDING_ROSE_SERFDOM_OFFSET', 'KIND_BUILDING');
INSERT OR IGNORE INTO Traits (TraitType) VALUES ('TRAIT_ROSE_INTERNAL_BUILDING');
INSERT OR IGNORE INTO Buildings
    (BuildingType, Name, Cost, PrereqDistrict, InternalOnly,
     MaxPlayerInstances, TraitType) VALUES
('BUILDING_ROSE_SERFDOM_OFFSET', 'Rose Serfdom test offset', 1,
 'DISTRICT_CITY_CENTER', 1, 1, 'TRAIT_ROSE_INTERNAL_BUILDING');

-- Remove the completed native Policies-list probe.
DELETE FROM AiFavoredItems WHERE ListType = 'RosePolicyPreferencesProbe';
DELETE FROM AiLists        WHERE ListType = 'RosePolicyPreferencesProbe';
DELETE FROM AiListTypes    WHERE ListType = 'RosePolicyPreferencesProbe';

-- The eight adjacency cards retain their former targets and gates.  Serfdom
-- and Public Works remain unconditional.  Every scoring signal is Amount=1.
INSERT OR REPLACE INTO RoseChoiceBiases
    (BiasId, SourceKind, SourceType, Amount, GateType, GateValue) VALUES
('ROSE_CHOICE_POLICY_NATURAL_PHILOSOPHY',
 'POLICY', 'POLICY_NATURAL_PHILOSOPHY', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_SCRIPTURE',
 'POLICY', 'POLICY_SCRIPTURE', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_GRAND_OPERA',
 'POLICY', 'POLICY_GRAND_OPERA', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_TOWN_CHARTERS',
 'POLICY', 'POLICY_TOWN_CHARTERS', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_NAVAL_INFRASTRUCTURE',
 'POLICY', 'POLICY_NAVAL_INFRASTRUCTURE', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_CRAFTSMEN',
 'POLICY', 'POLICY_CRAFTSMEN', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN',
 'POLICY', 'POLICY_FIVE_YEAR_PLAN', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION',
 'POLICY', 'POLICY_ECONOMIC_UNION', 1, 'ADJACENCY', NULL),
('ROSE_CHOICE_POLICY_SERFDOM',
 'POLICY', 'POLICY_SERFDOM', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_POLICY_PUBLIC_WORKS',
 'POLICY', 'POLICY_PUBLIC_WORKS', 1, 'ALWAYS', NULL),

-- Tier 2: religion founders receive Theocracy; non-founders receive the two
-- secular alternatives.  Tier 3 has generic and leader-specific signals.
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
 'GOVERNMENT', 'GOVERNMENT_SYNTHETIC_TECHNOCRACY', 1, 'ALWAYS', NULL);

-- Keep this experiment's registry valid across base, expansion, and optional
-- content.  Belief rows are inserted by AI_Beliefs.sql before this file.
DELETE FROM RoseChoiceBiases
WHERE (SourceKind = 'POLICY'
       AND NOT EXISTS (SELECT 1 FROM Policies p
                       WHERE p.PolicyType = RoseChoiceBiases.SourceType))
   OR (SourceKind = 'GOVERNMENT'
       AND NOT EXISTS (SELECT 1 FROM Governments g
                       WHERE g.GovernmentType = RoseChoiceBiases.SourceType))
   OR (SourceKind = 'BELIEF'
       AND NOT EXISTS (SELECT 1 FROM Beliefs b
                       WHERE b.BeliefType = RoseChoiceBiases.SourceType))
   OR (GateType = 'LEADER_TRAIT'
       AND NOT EXISTS (SELECT 1 FROM Traits t
                       WHERE t.TraitType = RoseChoiceBiases.GateValue));

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES
('ROSE_CHOICE_SIGNAL_VERSION', '1'),
('ROSE_CHOICE_MIN_ADJACENCY', '3');

-- Policy-to-district context.  YieldType is the yield read by the native
-- high-adjacency requirement, while the modifier itself has no yield effect.
INSERT OR REPLACE INTO RoseChoiceDistricts
    (BiasId, DistrictType, YieldType) VALUES
('ROSE_CHOICE_POLICY_NATURAL_PHILOSOPHY',
 'DISTRICT_CAMPUS', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_SCRIPTURE',
 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'),
('ROSE_CHOICE_POLICY_GRAND_OPERA',
 'DISTRICT_THEATER', 'YIELD_CULTURE'),
('ROSE_CHOICE_POLICY_TOWN_CHARTERS',
 'DISTRICT_COMMERCIAL_HUB', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_NAVAL_INFRASTRUCTURE',
 'DISTRICT_HARBOR', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_CRAFTSMEN',
 'DISTRICT_INDUSTRIAL_ZONE', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN',
 'DISTRICT_CAMPUS', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN',
 'DISTRICT_INDUSTRIAL_ZONE', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION',
 'DISTRICT_COMMERCIAL_HUB', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION',
 'DISTRICT_HARBOR', 'YIELD_GOLD');

DELETE FROM RoseChoiceResolvedDistricts;
INSERT OR IGNORE INTO RoseChoiceResolvedDistricts
    (BiasId, DistrictType, YieldType)
SELECT BiasId, DistrictType, YieldType
FROM RoseChoiceDistricts;

-- Include each active unique district replacement, but only when its district
-- definition exists in this ruleset.
INSERT OR IGNORE INTO RoseChoiceResolvedDistricts
    (BiasId, DistrictType, YieldType)
SELECT gate.BiasId,
       replacement.CivUniqueDistrictType,
       gate.YieldType
FROM RoseChoiceDistricts gate
JOIN DistrictReplaces replacement
  ON replacement.ReplacesDistrictType = gate.DistrictType
JOIN Districts uniqueDistrict
  ON uniqueDistrict.DistrictType = replacement.CivUniqueDistrictType;

-- Build one city-level TEST_ANY set for each adjacency-gated policy.
INSERT OR IGNORE INTO RequirementSets
    (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_CITY_GATE_' || b.BiasId,
       'REQUIREMENTSET_TEST_ANY'
FROM RoseChoiceBiases b
WHERE b.GateType = 'ADJACENCY';

INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType)
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId
WHERE b.GateType = 'ADJACENCY';

INSERT OR REPLACE INTO RequirementArguments (RequirementId, Name, Value)
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'DistrictType', gate.DistrictType
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId
WHERE b.GateType = 'ADJACENCY'
UNION ALL
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'YieldType', gate.YieldType
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId
WHERE b.GateType = 'ADJACENCY'
UNION ALL
SELECT 'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType,
       'Amount', (SELECT Value FROM GlobalParameters
                  WHERE Name = 'ROSE_CHOICE_MIN_ADJACENCY')
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId
WHERE b.GateType = 'ADJACENCY';

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_CITY_GATE_' || gate.BiasId,
       'ROSE_CHOICE_REQ_DISTRICT_' || gate.BiasId || '_' || gate.DistrictType
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId
WHERE b.GateType = 'ADJACENCY';

-- Lift the city test to the player so the owner gate asks whether any owned
-- city has the required high-adjacency district.
INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType)
SELECT 'ROSE_CHOICE_REQ_CITY_' || b.BiasId,
       'REQUIREMENT_COLLECTION_ANY_MET'
FROM RoseChoiceBiases b
WHERE b.GateType = 'ADJACENCY';

INSERT OR REPLACE INTO RequirementArguments (RequirementId, Name, Value)
SELECT 'ROSE_CHOICE_REQ_CITY_' || b.BiasId,
       'CollectionType', 'COLLECTION_PLAYER_CITIES'
FROM RoseChoiceBiases b
WHERE b.GateType = 'ADJACENCY'
UNION ALL
SELECT 'ROSE_CHOICE_REQ_CITY_' || b.BiasId,
       'RequirementSetId', 'ROSE_CHOICE_CITY_GATE_' || b.BiasId
FROM RoseChoiceBiases b
WHERE b.GateType = 'ADJACENCY';

-- The non-adjacency context gates are evaluated at the player level.
INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType, Inverse)
SELECT 'ROSE_CHOICE_REQ_GATE_' || b.BiasId,
       'REQUIREMENT_PLAYER_IS_RELIGION_FOUNDER',
       CASE WHEN b.GateType = 'FOUNDER' THEN 0 ELSE 1 END
FROM RoseChoiceBiases b
WHERE b.GateType IN ('FOUNDER', 'NON_FOUNDER');

INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType)
SELECT 'ROSE_CHOICE_REQ_GATE_' || b.BiasId,
       'REQUIREMENT_PLAYER_HAS_CIVILIZATION_OR_LEADER_TRAIT'
FROM RoseChoiceBiases b
WHERE b.GateType = 'LEADER_TRAIT';

INSERT OR REPLACE INTO RequirementArguments (RequirementId, Name, Value)
SELECT 'ROSE_CHOICE_REQ_GATE_' || b.BiasId,
       'TraitType', b.GateValue
FROM RoseChoiceBiases b
WHERE b.GateType = 'LEADER_TRAIT';

-- One owner TEST_ALL per source: all are AI-only, then the configured context
-- gate is added for adjacency, founder, non-founder, and trait signals.
INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType, Inverse) VALUES
('ROSE_CHOICE_REQ_AI', 'REQUIREMENT_PLAYER_IS_HUMAN', 1);

INSERT OR IGNORE INTO RequirementSets
    (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_OWNER_' || b.BiasId,
       'REQUIREMENTSET_TEST_ALL'
FROM RoseChoiceBiases b;

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_OWNER_' || b.BiasId,
       'ROSE_CHOICE_REQ_AI'
FROM RoseChoiceBiases b;

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_OWNER_' || b.BiasId,
       CASE WHEN b.GateType = 'ADJACENCY'
            THEN 'ROSE_CHOICE_REQ_CITY_' || b.BiasId
            ELSE 'ROSE_CHOICE_REQ_GATE_' || b.BiasId
       END
FROM RoseChoiceBiases b
WHERE b.GateType <> 'ALWAYS';

-- This subject gate contains both a civic and its inverse, making it
-- impossible forever.  The modifier is therefore context-only.
INSERT OR IGNORE INTO RequirementSets
    (RequirementSetId, RequirementSetType) VALUES
('ROSE_CHOICE_NEVER_ACTIVE', 'REQUIREMENTSET_TEST_ALL');
INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType, Inverse) VALUES
('ROSE_CHOICE_HAS_FUTURE_CIVIC', 'REQUIREMENT_PLAYER_HAS_CIVIC', 0),
('ROSE_CHOICE_LACKS_FUTURE_CIVIC', 'REQUIREMENT_PLAYER_HAS_CIVIC', 1);
INSERT OR REPLACE INTO RequirementArguments (RequirementId, Name, Value) VALUES
('ROSE_CHOICE_HAS_FUTURE_CIVIC', 'CivicType', 'CIVIC_FUTURE_CIVIC'),
('ROSE_CHOICE_LACKS_FUTURE_CIVIC', 'CivicType', 'CIVIC_FUTURE_CIVIC');
INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId) VALUES
('ROSE_CHOICE_NEVER_ACTIVE', 'ROSE_CHOICE_HAS_FUTURE_CIVIC'),
('ROSE_CHOICE_NEVER_ACTIVE', 'ROSE_CHOICE_LACKS_FUTURE_CIVIC');

-- The registry is the sole source for all 29 signal modifiers and their
-- policy, government, and belief attachments.
INSERT OR IGNORE INTO Modifiers
    (ModifierId, ModifierType, OwnerRequirementSetId, SubjectRequirementSetId)
SELECT b.BiasId,
       'MODIFIER_PLAYER_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN',
       'ROSE_CHOICE_OWNER_' || b.BiasId,
       'ROSE_CHOICE_NEVER_ACTIVE'
FROM RoseChoiceBiases b;

INSERT OR REPLACE INTO ModifierArguments (ModifierId, Name, Value)
SELECT b.BiasId, 'Amount', b.Amount
FROM RoseChoiceBiases b;

INSERT OR IGNORE INTO PolicyModifiers (PolicyType, ModifierId)
SELECT b.SourceType, b.BiasId
FROM RoseChoiceBiases b
WHERE b.SourceKind = 'POLICY';

INSERT OR IGNORE INTO GovernmentModifiers (GovernmentType, ModifierId)
SELECT b.SourceType, b.BiasId
FROM RoseChoiceBiases b
WHERE b.SourceKind = 'GOVERNMENT';

INSERT OR IGNORE INTO BeliefModifiers (BeliefType, ModifierId)
SELECT b.SourceType, b.BiasId
FROM RoseChoiceBiases b
WHERE b.SourceKind = 'BELIEF';
