-- ============================================================================
-- Rose AI: Dummy-Gold Policy and Government Preferences
-- ============================================================================
-- These Gold-per-turn modifiers exist only to make the native chooser value
-- selected cards and governments. Rose_AI_Gameplay.lua reads the same
-- RoseGoldBiases rows and removes each configured nominal amount next turn.
-- Serfdom has separate experimental modes, including a disabled-effect probe.
-- ============================================================================

-- Remove the completed native Policies-list probe. It loaded successfully but
-- did not give zero-value cards such as Serfdom a usable candidate score.
DELETE FROM AiFavoredItems WHERE ListType = 'RosePolicyPreferencesProbe';
DELETE FROM AiLists        WHERE ListType = 'RosePolicyPreferencesProbe';
DELETE FROM AiListTypes    WHERE ListType = 'RosePolicyPreferencesProbe';

-- ============================================================================
-- 1. POLICY BIASES
-- ============================================================================

-- Serfdom experiment: 0 = no signal; 1 = +Gold only (intentional test payout);
-- 2 = +Gold with a separate capital marker's player-level negative Gold;
-- 3 = original +Gold / next-turn Lua clawback;
-- 4 = permanently gated envoy scoring probe, no Serfdom Gold or deduction.
-- Restart/reload after changing; use a save from before Serfdom was equipped.
INSERT OR REPLACE INTO GlobalParameters (Name, Value)
VALUES ('ROSE_SERFDOM_EXPERIMENT_MODE', '4');

INSERT OR REPLACE INTO RoseGoldBiases
    (BiasId, SourceKind, SourceType, Amount, GateType) VALUES
('ROSE_GOLD_POLICY_NATURAL_PHILOSOPHY',  'POLICY', 'POLICY_NATURAL_PHILOSOPHY',  20, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_SCRIPTURE',           'POLICY', 'POLICY_SCRIPTURE',           20, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_GRAND_OPERA',         'POLICY', 'POLICY_GRAND_OPERA',         20, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_TOWN_CHARTERS',       'POLICY', 'POLICY_TOWN_CHARTERS',       20, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_NAVAL_INFRASTRUCTURE','POLICY', 'POLICY_NAVAL_INFRASTRUCTURE',20, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_CRAFTSMEN',           'POLICY', 'POLICY_CRAFTSMEN',           20, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_FIVE_YEAR_PLAN',      'POLICY', 'POLICY_FIVE_YEAR_PLAN',      40, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_ECONOMIC_UNION',      'POLICY', 'POLICY_ECONOMIC_UNION',      40, 'DISTRICT_ANY'),
('ROSE_GOLD_POLICY_SERFDOM',             'POLICY', 'POLICY_SERFDOM',             40, 'ALWAYS'),
('ROSE_GOLD_POLICY_PUBLIC_WORKS',        'POLICY', 'POLICY_PUBLIC_WORKS',        40, 'ALWAYS');

INSERT OR REPLACE INTO RoseGoldBiasDistricts (BiasId, DistrictType) VALUES
('ROSE_GOLD_POLICY_NATURAL_PHILOSOPHY',   'DISTRICT_CAMPUS'),
('ROSE_GOLD_POLICY_SCRIPTURE',            'DISTRICT_HOLY_SITE'),
('ROSE_GOLD_POLICY_GRAND_OPERA',          'DISTRICT_THEATER'),
('ROSE_GOLD_POLICY_TOWN_CHARTERS',        'DISTRICT_COMMERCIAL_HUB'),
('ROSE_GOLD_POLICY_NAVAL_INFRASTRUCTURE', 'DISTRICT_HARBOR'),
('ROSE_GOLD_POLICY_CRAFTSMEN',            'DISTRICT_INDUSTRIAL_ZONE'),
('ROSE_GOLD_POLICY_FIVE_YEAR_PLAN',       'DISTRICT_CAMPUS'),
('ROSE_GOLD_POLICY_FIVE_YEAR_PLAN',       'DISTRICT_INDUSTRIAL_ZONE'),
('ROSE_GOLD_POLICY_ECONOMIC_UNION',       'DISTRICT_COMMERCIAL_HUB'),
('ROSE_GOLD_POLICY_ECONOMIC_UNION',       'DISTRICT_HARBOR');

-- Expand every base district gate to include all unique replacements present
-- in the active ruleset. This covers both the player's own uniques and
-- captured districts belonging to another civilization.
INSERT OR IGNORE INTO RoseGoldBiasResolvedDistricts (BiasId, DistrictType)
SELECT BiasId, DistrictType
FROM RoseGoldBiasDistricts;

INSERT OR IGNORE INTO RoseGoldBiasResolvedDistricts (BiasId, DistrictType)
SELECT gate.BiasId, replacement.CivUniqueDistrictType
FROM RoseGoldBiasDistricts gate
JOIN DistrictReplaces replacement
  ON replacement.ReplacesDistrictType = gate.DistrictType;

INSERT OR IGNORE INTO RequirementSets
    (RequirementSetId, RequirementSetType)
SELECT 'ROSE_GOLD_GATE_' || b.BiasId, 'REQUIREMENTSET_TEST_ANY'
FROM RoseGoldBiases b
WHERE b.SourceKind = 'POLICY'
  AND b.GateType = 'DISTRICT_ANY';

INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType)
SELECT 'ROSE_GOLD_REQ_' || gate.BiasId || '_' || gate.DistrictType,
       'REQUIREMENT_PLAYER_HAS_DISTRICT'
FROM RoseGoldBiasResolvedDistricts gate;

INSERT OR IGNORE INTO RequirementArguments
    (RequirementId, Name, Value)
SELECT 'ROSE_GOLD_REQ_' || gate.BiasId || '_' || gate.DistrictType,
       'DistrictType', gate.DistrictType
FROM RoseGoldBiasResolvedDistricts gate;

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_GOLD_GATE_' || gate.BiasId,
       'ROSE_GOLD_REQ_' || gate.BiasId || '_' || gate.DistrictType
FROM RoseGoldBiasResolvedDistricts gate;

INSERT OR IGNORE INTO Modifiers
    (ModifierId, ModifierType, OwnerRequirementSetId, SubjectRequirementSetId)
SELECT b.BiasId,
       'MODIFIER_PLAYER_ADJUST_YIELD_CHANGE',
       CASE WHEN b.GateType = 'DISTRICT_ANY' THEN 'PLAYER_IS_AI' END,
       CASE WHEN b.GateType = 'DISTRICT_ANY'
            THEN 'ROSE_GOLD_GATE_' || b.BiasId
            ELSE 'PLAYER_IS_AI'
       END
FROM RoseGoldBiases b
JOIN Policies source ON source.PolicyType = b.SourceType
WHERE b.SourceKind = 'POLICY';

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
SELECT b.BiasId, 'YieldType', 'YIELD_GOLD'
FROM RoseGoldBiases b
JOIN Policies source ON source.PolicyType = b.SourceType
WHERE b.SourceKind = 'POLICY'
UNION ALL
SELECT b.BiasId, 'Amount', b.Amount
FROM RoseGoldBiases b
JOIN Policies source ON source.PolicyType = b.SourceType
WHERE b.SourceKind = 'POLICY';

INSERT OR IGNORE INTO PolicyModifiers (PolicyType, ModifierId)
SELECT b.SourceType, b.BiasId
FROM RoseGoldBiases b
JOIN Policies source ON source.PolicyType = b.SourceType
WHERE b.SourceKind = 'POLICY';

-- ============================================================================
-- 1a. SERFDOM COMPENSATION EXPERIMENT
-- ============================================================================
-- Keep the marker registered in every mode so Lua can clean up saved markers.
-- The unassigned trait prevents ordinary construction; Lua places it directly.
-- Capital=0: this marker must never acquire the Palace's capital designation.
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('TRAIT_ROSE_INTERNAL_BUILDING', 'KIND_TRAIT'),
('BUILDING_ROSE_SERFDOM_OFFSET', 'KIND_BUILDING');
INSERT OR IGNORE INTO Traits (TraitType) VALUES ('TRAIT_ROSE_INTERNAL_BUILDING');
INSERT OR IGNORE INTO Buildings
    (BuildingType, Name, Cost, PrereqDistrict, InternalOnly,
     MaxPlayerInstances, TraitType) VALUES
('BUILDING_ROSE_SERFDOM_OFFSET', 'Rose Serfdom test offset', 1,
 'DISTRICT_CITY_CENTER', 1, 1, 'TRAIT_ROSE_INTERNAL_BUILDING');

-- Deliberately not a city yield or maintenance cost: those can be scaled.
-- Building ownership resolution and negative player yields need runtime proof.
INSERT OR IGNORE INTO Modifiers
    (ModifierId, ModifierType, SubjectRequirementSetId) VALUES
('ROSE_SERFDOM_BUILDING_OFFSET', 'MODIFIER_PLAYER_ADJUST_YIELD_CHANGE', 'PLAYER_IS_AI');
INSERT OR REPLACE INTO ModifierArguments (ModifierId, Name, Value)
SELECT 'ROSE_SERFDOM_BUILDING_OFFSET', 'Amount',
       CASE WHEN (SELECT Value FROM GlobalParameters
                  WHERE Name = 'ROSE_SERFDOM_EXPERIMENT_MODE') = '2'
            THEN -Amount ELSE 0 END
FROM RoseGoldBiases WHERE BiasId = 'ROSE_GOLD_POLICY_SERFDOM';
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_SERFDOM_BUILDING_OFFSET', 'YieldType', 'YIELD_GOLD');
INSERT OR IGNORE INTO BuildingModifiers (BuildingType, ModifierId) VALUES
('BUILDING_ROSE_SERFDOM_OFFSET', 'ROSE_SERFDOM_BUILDING_OFFSET');

DELETE FROM PolicyModifiers
WHERE PolicyType = 'POLICY_SERFDOM' AND ModifierId = 'ROSE_GOLD_POLICY_SERFDOM'
  AND (SELECT Value FROM GlobalParameters
       WHERE Name = 'ROSE_SERFDOM_EXPERIMENT_MODE') IN ('0', '4');

-- RH attaches this envoy effect to Serfdom behind an AI/Future Civic gate.
-- Test whether the chooser values the effect even when gameplay cannot enable
-- it. Requiring BOTH Future Civic and its inverse makes the TEST_ALL gate false
-- forever, rather than allowing an unintended envoy bonus in the late game.
-- This is an unproven scoring probe, not a validated AI preference mechanism.
INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES
('ROSE_SERFDOM_PROBE_NEVER_ACTIVE', 'REQUIREMENTSET_TEST_ALL');
INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType, Inverse) VALUES
('ROSE_SERFDOM_PROBE_IS_AI', 'REQUIREMENT_PLAYER_IS_HUMAN', 1),
('ROSE_SERFDOM_PROBE_HAS_FUTURE', 'REQUIREMENT_PLAYER_HAS_CIVIC', 0),
('ROSE_SERFDOM_PROBE_LACKS_FUTURE', 'REQUIREMENT_PLAYER_HAS_CIVIC', 1);
INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value) VALUES
('ROSE_SERFDOM_PROBE_HAS_FUTURE', 'CivicType', 'CIVIC_FUTURE_CIVIC'),
('ROSE_SERFDOM_PROBE_LACKS_FUTURE', 'CivicType', 'CIVIC_FUTURE_CIVIC');
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES
('ROSE_SERFDOM_PROBE_NEVER_ACTIVE', 'ROSE_SERFDOM_PROBE_IS_AI'),
('ROSE_SERFDOM_PROBE_NEVER_ACTIVE', 'ROSE_SERFDOM_PROBE_HAS_FUTURE'),
('ROSE_SERFDOM_PROBE_NEVER_ACTIVE', 'ROSE_SERFDOM_PROBE_LACKS_FUTURE');
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId) VALUES
('ROSE_SERFDOM_INACTIVE_ENVOY_PROBE',
 'MODIFIER_PLAYER_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN',
 'ROSE_SERFDOM_PROBE_NEVER_ACTIVE');
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_SERFDOM_INACTIVE_ENVOY_PROBE', 'Amount', 1);

-- Remove the probe attachment when returning to any of the earlier controls.
DELETE FROM PolicyModifiers
WHERE PolicyType = 'POLICY_SERFDOM'
  AND ModifierId = 'ROSE_SERFDOM_INACTIVE_ENVOY_PROBE';
INSERT INTO PolicyModifiers (PolicyType, ModifierId)
SELECT 'POLICY_SERFDOM', 'ROSE_SERFDOM_INACTIVE_ENVOY_PROBE'
WHERE (SELECT Value FROM GlobalParameters
       WHERE Name = 'ROSE_SERFDOM_EXPERIMENT_MODE') = '4';

-- ============================================================================
-- 2. GOVERNMENT BIASES
-- ============================================================================
-- Tier 2 is exclusive: religion founders see Theocracy +40, while players
-- without a founded religion see Monarchy and Merchant Republic +40.
-- Every Tier 3 government gets +50; matching leader tags add another +60.
-- Every available Tier 4 government gets +80. Government signals use a flat
-- capital-city yield so the chooser sees a city-scoped benefit without making
-- the nominal payout scale with empire size.
-- ============================================================================

INSERT OR REPLACE INTO RoseGoldBiases
    (BiasId, SourceKind, SourceType, Amount, GateType, GateValue) VALUES
('ROSE_GOLD_GOV_MONARCHY_NON_FOUNDER',
 'GOVERNMENT', 'GOVERNMENT_MONARCHY', 40, 'NON_FOUNDER', NULL),
('ROSE_GOLD_GOV_MERCHANT_REPUBLIC_NON_FOUNDER',
 'GOVERNMENT', 'GOVERNMENT_MERCHANT_REPUBLIC', 40, 'NON_FOUNDER', NULL),
('ROSE_GOLD_GOV_THEOCRACY_FOUNDER',
 'GOVERNMENT', 'GOVERNMENT_THEOCRACY', 40, 'FOUNDER', NULL),

('ROSE_GOLD_GOV_COMMUNISM_GENERIC',
 'GOVERNMENT', 'GOVERNMENT_COMMUNISM', 50, 'ALWAYS', NULL),
('ROSE_GOLD_GOV_DEMOCRACY_GENERIC',
 'GOVERNMENT', 'GOVERNMENT_DEMOCRACY', 50, 'ALWAYS', NULL),
('ROSE_GOLD_GOV_FASCISM_GENERIC',
 'GOVERNMENT', 'GOVERNMENT_FASCISM', 50, 'ALWAYS', NULL),
('ROSE_GOLD_GOV_COMMUNISM_SCIENCE',
 'GOVERNMENT', 'GOVERNMENT_COMMUNISM', 60, 'LEADER_TRAIT', 'TRAIT_LEADER_SCIENCE_MAJOR_CIV'),
('ROSE_GOLD_GOV_DEMOCRACY_CULTURE',
 'GOVERNMENT', 'GOVERNMENT_DEMOCRACY', 60, 'LEADER_TRAIT', 'TRAIT_LEADER_CULTURAL_MAJOR_CIV'),
('ROSE_GOLD_GOV_FASCISM_MILITARY',
 'GOVERNMENT', 'GOVERNMENT_FASCISM', 60, 'LEADER_TRAIT', 'TRAIT_LEADER_AGGRESSIVE_MILITARY'),

('ROSE_GOLD_GOV_CORPORATE_LIBERTARIANISM',
 'GOVERNMENT', 'GOVERNMENT_CORPORATE_LIBERTARIANISM', 80, 'ALWAYS', NULL),
('ROSE_GOLD_GOV_DIGITAL_DEMOCRACY',
 'GOVERNMENT', 'GOVERNMENT_DIGITAL_DEMOCRACY', 80, 'ALWAYS', NULL),
('ROSE_GOLD_GOV_SYNTHETIC_TECHNOCRACY',
 'GOVERNMENT', 'GOVERNMENT_SYNTHETIC_TECHNOCRACY', 80, 'ALWAYS', NULL);

INSERT OR IGNORE INTO RequirementSets
    (RequirementSetId, RequirementSetType)
SELECT 'ROSE_GOLD_GATE_' || b.BiasId, 'REQUIREMENTSET_TEST_ALL'
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType <> 'ALWAYS';

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_GOLD_GATE_' || b.BiasId, 'REQUIRES_PLAYER_IS_AI'
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType <> 'ALWAYS';

-- Founder-gated governments can reuse the base-game founder requirement.
INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_GOLD_GATE_' || b.BiasId, 'REQUIRES_PLAYER_FOUNDED_RELIGION'
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType = 'FOUNDER';

-- Non-founder and leader-trait gates require one generated requirement each.
INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType, Inverse)
SELECT 'ROSE_GOLD_REQ_' || b.BiasId,
       'REQUIREMENT_PLAYER_IS_RELIGION_FOUNDER',
       1
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType = 'NON_FOUNDER';

INSERT OR IGNORE INTO Requirements
    (RequirementId, RequirementType)
SELECT 'ROSE_GOLD_REQ_' || b.BiasId,
       'REQUIREMENT_PLAYER_HAS_CIVILIZATION_OR_LEADER_TRAIT'
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
JOIN Traits trait ON trait.TraitType = b.GateValue
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType = 'LEADER_TRAIT';

INSERT OR IGNORE INTO RequirementArguments
    (RequirementId, Name, Value)
SELECT 'ROSE_GOLD_REQ_' || b.BiasId, 'TraitType', b.GateValue
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
JOIN Traits trait ON trait.TraitType = b.GateValue
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType = 'LEADER_TRAIT';

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId)
SELECT 'ROSE_GOLD_GATE_' || b.BiasId,
       'ROSE_GOLD_REQ_' || b.BiasId
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND b.GateType IN ('NON_FOUNDER', 'LEADER_TRAIT');

INSERT OR IGNORE INTO Modifiers
    (ModifierId, ModifierType, SubjectRequirementSetId)
SELECT b.BiasId,
       'MODIFIER_PLAYER_CAPITAL_CITY_ADJUST_CITY_YIELD_CHANGE',
       CASE WHEN b.GateType = 'ALWAYS'
            THEN 'PLAYER_IS_AI'
            ELSE 'ROSE_GOLD_GATE_' || b.BiasId
       END
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND (b.GateType <> 'LEADER_TRAIT'
       OR EXISTS (SELECT 1 FROM Traits trait WHERE trait.TraitType = b.GateValue));

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
SELECT b.BiasId, 'YieldType', 'YIELD_GOLD'
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND (b.GateType <> 'LEADER_TRAIT'
       OR EXISTS (SELECT 1 FROM Traits trait WHERE trait.TraitType = b.GateValue))
UNION ALL
SELECT b.BiasId, 'Amount', b.Amount
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND (b.GateType <> 'LEADER_TRAIT'
       OR EXISTS (SELECT 1 FROM Traits trait WHERE trait.TraitType = b.GateValue));

INSERT OR IGNORE INTO GovernmentModifiers (GovernmentType, ModifierId)
SELECT b.SourceType, b.BiasId
FROM RoseGoldBiases b
JOIN Governments source ON source.GovernmentType = b.SourceType
WHERE b.SourceKind = 'GOVERNMENT'
  AND (b.GateType <> 'LEADER_TRAIT'
       OR EXISTS (SELECT 1 FROM Traits trait WHERE trait.TraitType = b.GateValue));
