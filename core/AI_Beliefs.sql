-- ============================================================================
-- Rose AI: Scoring-only belief choice signals
-- ============================================================================
-- Beliefs do not use a founded-religion gate here: the chooser evaluates
-- beliefs before the religion exists.  The signal modifiers are registered by
-- AI_Policies.sql with an AI-only owner gate and a permanently false subject
-- gate, so they contribute context to AI choice scoring without changing
-- gameplay yields or influence tokens.
-- ============================================================================

CREATE TABLE IF NOT EXISTS RoseChoiceBiases (
    BiasId     TEXT NOT NULL PRIMARY KEY,
    SourceKind TEXT NOT NULL,
    SourceType TEXT NOT NULL,
    Amount     INTEGER NOT NULL DEFAULT 1,
    GateType   TEXT NOT NULL DEFAULT 'ALWAYS',
    GateValue  TEXT
);

CREATE TABLE IF NOT EXISTS RoseChoiceDistricts (
    BiasId      TEXT NOT NULL,
    DistrictType TEXT NOT NULL,
    YieldType   TEXT NOT NULL,
    PRIMARY KEY (BiasId, DistrictType)
);

CREATE TABLE IF NOT EXISTS RoseChoiceResolvedDistricts (
    BiasId      TEXT NOT NULL,
    DistrictType TEXT NOT NULL,
    YieldType   TEXT NOT NULL,
    PRIMARY KEY (BiasId, DistrictType)
);

-- Remove the previous dummy-Gold attachments while preserving unrelated Rose
-- modifiers. Zero any legacy amounts still present in the database. Saved
-- modifier instances can persist separately, so validation needs a fresh game.
DELETE FROM PolicyModifiers
WHERE ModifierId GLOB 'ROSE_GOLD_*';
DELETE FROM GovernmentModifiers
WHERE ModifierId GLOB 'ROSE_GOLD_*';
DELETE FROM BeliefModifiers
WHERE ModifierId GLOB 'ROSE_GOLD_*';
DELETE FROM PolicyModifiers
WHERE ModifierId = 'ROSE_SERFDOM_INACTIVE_ENVOY_PROBE';

UPDATE ModifierArguments
SET Value = 0
WHERE ModifierId GLOB 'ROSE_GOLD_*'
  AND Name = 'Amount';
UPDATE ModifierArguments
SET Value = 0
WHERE ModifierId = 'ROSE_SERFDOM_BUILDING_OFFSET'
  AND Name = 'Amount';
DELETE FROM BuildingModifiers
WHERE BuildingType = 'BUILDING_ROSE_SERFDOM_OFFSET'
   OR ModifierId = 'ROSE_SERFDOM_BUILDING_OFFSET';
DELETE FROM GlobalParameters
WHERE Name = 'ROSE_SERFDOM_EXPERIMENT_MODE';

DROP TABLE IF EXISTS RoseGoldBiasResolvedDistricts;
DROP TABLE IF EXISTS RoseGoldBiasDistricts;
DROP TABLE IF EXISTS RoseGoldBiases;

-- Clear any previous run of the scoring-only registry and its attachments.
DELETE FROM PolicyModifiers
WHERE ModifierId GLOB 'ROSE_CHOICE_*';
DELETE FROM GovernmentModifiers
WHERE ModifierId GLOB 'ROSE_CHOICE_*';
DELETE FROM BeliefModifiers
WHERE ModifierId GLOB 'ROSE_CHOICE_*';
DELETE FROM RoseChoiceResolvedDistricts;
DELETE FROM RoseChoiceDistricts;
DELETE FROM RoseChoiceBiases;

-- Belief targets mirror the former preference set.  Crusade remains
-- warmonger-specific; all other beliefs are available to every AI chooser.
INSERT OR REPLACE INTO RoseChoiceBiases
    (BiasId, SourceKind, SourceType, Amount, GateType, GateValue) VALUES
('ROSE_CHOICE_BELIEF_WORK_ETHIC',
 'BELIEF', 'BELIEF_WORK_ETHIC', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_BELIEF_JESUIT_EDUCATION',
 'BELIEF', 'BELIEF_JESUIT_EDUCATION', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_BELIEF_CHORAL_MUSIC',
 'BELIEF', 'BELIEF_CHORAL_MUSIC', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_BELIEF_FEED_THE_WORLD',
 'BELIEF', 'BELIEF_FEED_THE_WORLD', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_BELIEF_ZEN_MEDITATION',
 'BELIEF', 'BELIEF_ZEN_MEDITATION', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_BELIEF_RELIGIOUS_COMMUNITY',
 'BELIEF', 'BELIEF_RELIGIOUS_COMMUNITY', 1, 'ALWAYS', NULL),
('ROSE_CHOICE_BELIEF_CRUSADE',
 'BELIEF', 'BELIEF_JUST_WAR', 1, 'LEADER_TRAIT',
 'TRAIT_LEADER_AGGRESSIVE_MILITARY');
