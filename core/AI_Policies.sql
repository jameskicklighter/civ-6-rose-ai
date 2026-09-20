-- ============================================================================
-- Rose AI: Inactive policy, government, and belief choice signals
-- ============================================================================
-- Matching-yield signals use direct CITY subject checks supported by the AI.
-- Their impossible PLAYER owner gate prevents any actual yield. Serfdom and
-- Public Works retain one player-scoped envoy signal each, not one per city.
-- Government envoy signals and their unverified owner eligibility are unchanged.

-- Each component adds +3 of its yield per qualifying city. Combined cards use
-- independent components: either qualifying district contributes, and both
-- contribute when both qualify (including when they are in different cities).
WITH ChoiceSources (BiasId, SourceType, Amount, GateType, YieldType) AS (VALUES
('ROSE_CHOICE_POLICY_NATURAL_PHILOSOPHY', 'POLICY_NATURAL_PHILOSOPHY', 3, 'ADJACENCY', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_SCRIPTURE', 'POLICY_SCRIPTURE', 3, 'ADJACENCY', 'YIELD_FAITH'),
('ROSE_CHOICE_POLICY_GRAND_OPERA', 'POLICY_GRAND_OPERA', 3, 'ADJACENCY', 'YIELD_CULTURE'),
('ROSE_CHOICE_POLICY_TOWN_CHARTERS', 'POLICY_TOWN_CHARTERS', 3, 'ADJACENCY', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_NAVAL_INFRASTRUCTURE', 'POLICY_NAVAL_INFRASTRUCTURE', 3, 'ADJACENCY', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_CRAFTSMEN', 'POLICY_CRAFTSMEN', 3, 'ADJACENCY', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_SCIENCE', 'POLICY_FIVE_YEAR_PLAN', 3, 'ADJACENCY', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_PRODUCTION', 'POLICY_FIVE_YEAR_PLAN', 3, 'ADJACENCY', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_COMMERCIAL', 'POLICY_ECONOMIC_UNION', 3, 'ADJACENCY', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_HARBOR', 'POLICY_ECONOMIC_UNION', 3, 'ADJACENCY', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_SERFDOM', 'POLICY_SERFDOM', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_POLICY_PUBLIC_WORKS', 'POLICY_PUBLIC_WORKS', 1, 'ALWAYS', NULL)
)
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT b.BiasId, 'POLICY', b.SourceType, b.Amount, b.GateType, b.YieldType
FROM ChoiceSources b
JOIN Policies source ON source.PolicyType = b.SourceType;

WITH ChoiceSources (BiasId, SourceKind, SourceType, Amount, GateType, GateValue) AS (VALUES
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

INSERT INTO GlobalParameters (Name, Value) VALUES
('ROSE_CHOICE_MIN_ADJACENCY', '3');

-- The mapping yield is the district adjacency to test. Unique replacements
-- share a component's TEST_ANY gate and never create duplicate yield signals.
WITH DistrictGates (BiasId, DistrictType, YieldType) AS (VALUES
('ROSE_CHOICE_POLICY_NATURAL_PHILOSOPHY', 'DISTRICT_CAMPUS', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_SCRIPTURE', 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'),
('ROSE_CHOICE_POLICY_GRAND_OPERA', 'DISTRICT_THEATER', 'YIELD_CULTURE'),
('ROSE_CHOICE_POLICY_TOWN_CHARTERS', 'DISTRICT_COMMERCIAL_HUB', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_NAVAL_INFRASTRUCTURE', 'DISTRICT_HARBOR', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_CRAFTSMEN', 'DISTRICT_INDUSTRIAL_ZONE', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_SCIENCE', 'DISTRICT_CAMPUS', 'YIELD_SCIENCE'),
('ROSE_CHOICE_POLICY_FIVE_YEAR_PLAN_PRODUCTION', 'DISTRICT_INDUSTRIAL_ZONE', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_COMMERCIAL', 'DISTRICT_COMMERCIAL_HUB', 'YIELD_GOLD'),
('ROSE_CHOICE_POLICY_ECONOMIC_UNION_HARBOR', 'DISTRICT_HARBOR', 'YIELD_GOLD')
)
INSERT INTO RoseChoiceDistricts (BiasId, DistrictType, YieldType)
SELECT d.* FROM DistrictGates d
JOIN RoseChoiceBiases b ON b.BiasId = d.BiasId;

INSERT INTO RoseChoiceResolvedDistricts (BiasId, DistrictType, YieldType)
SELECT gate.* FROM RoseChoiceDistricts gate
JOIN Districts d ON d.DistrictType = gate.DistrictType
UNION
SELECT gate.BiasId, replacement.CivUniqueDistrictType, gate.YieldType
FROM RoseChoiceDistricts gate
JOIN DistrictReplaces replacement ON replacement.ReplacesDistrictType = gate.DistrictType
JOIN Districts d ON d.DistrictType = replacement.CivUniqueDistrictType;

INSERT INTO RequirementSets (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId, 'REQUIREMENTSET_TEST_ANY'
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
       'Amount', (SELECT Value FROM GlobalParameters WHERE Name = 'ROSE_CHOICE_MIN_ADJACENCY')
FROM RoseChoiceResolvedDistricts gate
JOIN RoseChoiceBiases b ON b.BiasId = gate.BiasId WHERE b.GateType = 'ADJACENCY';

INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId,
       'ROSE_CHOICE_REQ_DISTRICT_' || BiasId || '_' || DistrictType
FROM RoseChoiceResolvedDistricts;

INSERT INTO RequirementSets (RequirementSetId, RequirementSetType)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId, 'REQUIREMENTSET_TEST_ALL'
FROM RoseChoiceBiases WHERE GateType IN ('MILITARY_MARKER', 'WAR_MARKER');
INSERT INTO Requirements (RequirementId, RequirementType) VALUES
('ROSE_CHOICE_REQ_MILITARY_MARKER', 'REQUIREMENT_CITY_HAS_BUILDING'),
('ROSE_CHOICE_REQ_WAR_MARKER', 'REQUIREMENT_CITY_HAS_BUILDING'),
('ROSE_CHOICE_REQ_PALACE', 'REQUIREMENT_CITY_HAS_BUILDING');
INSERT INTO RequirementArguments (RequirementId, Name, Value) VALUES
('ROSE_CHOICE_REQ_MILITARY_MARKER', 'BuildingType', 'BUILDING_ROSE_MILITARY_CHOICE_MARKER'),
('ROSE_CHOICE_REQ_WAR_MARKER', 'BuildingType', 'BUILDING_ROSE_WAR_CHOICE_MARKER'),
('ROSE_CHOICE_REQ_PALACE', 'BuildingType', 'BUILDING_PALACE');
-- Both buildings must be in this city: the marker carries military or wartime eligibility,
-- while the Palace limits the signal to one city instead of scaling by empire.
INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId)
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId,
       CASE WHEN GateType = 'MILITARY_MARKER' THEN 'ROSE_CHOICE_REQ_MILITARY_MARKER'
            ELSE 'ROSE_CHOICE_REQ_WAR_MARKER' END
FROM RoseChoiceBiases WHERE GateType IN ('MILITARY_MARKER', 'WAR_MARKER')
UNION ALL
SELECT 'ROSE_CHOICE_CITY_GATE_' || BiasId, 'ROSE_CHOICE_REQ_PALACE'
FROM RoseChoiceBiases WHERE GateType IN ('MILITARY_MARKER', 'WAR_MARKER');

-- Existing government owner eligibility is preserved. It is NOT established as
-- a chooser gate: the traced scorer skips owner requirements. No policy or
-- belief relies on these conditions for district eligibility.
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
FROM RoseChoiceBiases WHERE YieldType IS NOT NULL OR GateType IN ('MILITARY_MARKER', 'WAR_MARKER')
UNION ALL
SELECT 'ROSE_CHOICE_OWNER_' || BiasId, 'ROSE_CHOICE_LACKS_FUTURE_CIVIC'
FROM RoseChoiceBiases WHERE YieldType IS NOT NULL OR GateType IN ('MILITARY_MARKER', 'WAR_MARKER');

-- TEST_ALL requires BOTH having and lacking Future Civic. No player can pass.
-- Yield signals and city envoy signals place this contradiction on their owner, leaving
-- city subject checks visible. Other envoy signals retain it on subjects.
INSERT INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES
('ROSE_CHOICE_NEVER_ACTIVE', 'REQUIREMENTSET_TEST_ALL');
INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES
('ROSE_CHOICE_NEVER_ACTIVE', 'ROSE_CHOICE_HAS_FUTURE_CIVIC'),
('ROSE_CHOICE_NEVER_ACTIVE', 'ROSE_CHOICE_LACKS_FUTURE_CIVIC');

INSERT INTO Modifiers (ModifierId, ModifierType, OwnerRequirementSetId, SubjectRequirementSetId)
SELECT BiasId,
       CASE WHEN GateType IN ('MILITARY_MARKER', 'WAR_MARKER') THEN 'MODIFIER_ROSE_CITIES_INACTIVE_ENVOY'
            WHEN YieldType IS NOT NULL THEN 'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE'
            ELSE 'MODIFIER_PLAYER_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN' END,
       'ROSE_CHOICE_OWNER_' || BiasId,
       CASE WHEN GateType IN ('ADJACENCY', 'HOLY_SITE', 'MILITARY_MARKER', 'WAR_MARKER') THEN 'ROSE_CHOICE_CITY_GATE_' || BiasId
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
