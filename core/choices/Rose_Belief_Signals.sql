-- ============================================================================
-- Rose AI: the inactive choice-signal registry (RoseChoice* helper tables,
-- created here, so this file loads before Rose_Policy_Signals.sql) and its
-- belief entries, the scoring-only envoy modifier type and the hidden marker
-- buildings. Rose_Policy_Signals.sql emits every registered modifier.
-- AGENTS.md "### choices/Rose_Belief_Signals.sql", "### scripts/Rose_AI_ChoiceMarkers.lua".
-- ============================================================================

-- Registry of signals: one row per modifier, with its source and gate;
-- AGENTS.md "Inactive choice registry"
CREATE TABLE RoseChoiceBiases (
    BiasId     TEXT NOT NULL PRIMARY KEY,
    SourceKind TEXT NOT NULL,
    SourceType TEXT NOT NULL,
    Amount     INTEGER NOT NULL DEFAULT 1,
    GateType   TEXT NOT NULL DEFAULT 'ALWAYS',
    GateValue  TEXT,
    YieldType TEXT
);

CREATE TABLE RoseChoiceDistricts (
    BiasId TEXT NOT NULL,
    DistrictType TEXT NOT NULL,
    YieldType TEXT NOT NULL,
    PRIMARY KEY (BiasId, DistrictType)
);

CREATE TABLE RoseChoiceResolvedDistricts (
    BiasId TEXT NOT NULL,
    DistrictType TEXT NOT NULL,
    YieldType TEXT NOT NULL,
    PRIMARY KEY (BiasId, DistrictType)
);

-- Follower beliefs: per-city yield signals for a Holy Site (Work Ethic needs
-- its Faith adjacency); no founded religion required, since these beliefs are
-- also scored while founding; AGENTS.md "Follower-belief yield signals"
WITH ChoiceSources (BiasId, SourceType, Amount, GateType, YieldType) AS (VALUES
('ROSE_CHOICE_BELIEF_WORK_ETHIC', 'BELIEF_WORK_ETHIC', 3, 'ADJACENCY', 'YIELD_PRODUCTION'),
('ROSE_CHOICE_BELIEF_JESUIT_EDUCATION', 'BELIEF_JESUIT_EDUCATION', 1, 'HOLY_SITE', 'YIELD_SCIENCE'),
('ROSE_CHOICE_BELIEF_JESUIT_EDUCATION_CULTURE', 'BELIEF_JESUIT_EDUCATION', 1, 'HOLY_SITE', 'YIELD_CULTURE'),
('ROSE_CHOICE_BELIEF_CHORAL_MUSIC', 'BELIEF_CHORAL_MUSIC', 3, 'HOLY_SITE', 'YIELD_CULTURE'),
('ROSE_CHOICE_BELIEF_FEED_THE_WORLD', 'BELIEF_FEED_THE_WORLD', 1, 'HOLY_SITE', 'YIELD_FOOD'),
('ROSE_CHOICE_BELIEF_ZEN_MEDITATION', 'BELIEF_ZEN_MEDITATION', 1, 'HOLY_SITE', 'YIELD_FOOD'),
('ROSE_CHOICE_BELIEF_RELIGIOUS_COMMUNITY', 'BELIEF_RELIGIOUS_COMMUNITY', 1, 'HOLY_SITE', 'YIELD_GOLD')
)
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT b.BiasId, 'BELIEF', b.SourceType, b.Amount, b.GateType, b.YieldType
FROM ChoiceSources b
JOIN Beliefs source ON source.BeliefType = b.SourceType;

-- Crusade: one envoy signal in the Palace city of a military AI (the scorer
-- cannot read a leader-trait requirement, so a hidden marker building stands
-- in); AGENTS.md "Crusade", "AI scorer requirement rule"
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT 'ROSE_CHOICE_BELIEF_CRUSADE', 'BELIEF', BeliefType, 1, 'MILITARY_MARKER', NULL
FROM Beliefs WHERE BeliefType = 'BELIEF_JUST_WAR';

-- Defender of the Faith: one envoy signal in the Palace city of an AI at war
-- with a major (a separate war marker); AGENTS.md "Defender of the Faith"
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT 'ROSE_CHOICE_BELIEF_DEFENDER_OF_FAITH', 'BELIEF', BeliefType, 1, 'WAR_MARKER', NULL
FROM Beliefs WHERE BeliefType = 'BELIEF_DEFENDER_OF_FAITH';

-- City-scoped envoy modifier type: collection and effect are both registered
-- in the AI scorer, the no-match fallback adds no score, and the impossible
-- owner gate (Rose_Policy_Signals.sql) keeps it inactive; AGENTS.md "Crusade"
INSERT INTO Types (Type, Kind) VALUES
('MODIFIER_ROSE_CITIES_INACTIVE_ENVOY', 'KIND_MODIFIER');
INSERT INTO DynamicModifiers (ModifierType, CollectionType, EffectType) VALUES
('MODIFIER_ROSE_CITIES_INACTIVE_ENVOY', 'COLLECTION_PLAYER_CITIES',
 'EFFECT_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN');

-- The two hidden marker buildings, placed only by Rose_AI_ChoiceMarkers.lua:
-- an unassigned trait and InternalOnly prevent ordinary builds, and they carry
-- no effect at all; AGENTS.md "### scripts/Rose_AI_ChoiceMarkers.lua"
INSERT INTO Types (Type, Kind) VALUES
('TRAIT_ROSE_CHOICE_MARKER', 'KIND_TRAIT'),
('BUILDING_ROSE_MILITARY_CHOICE_MARKER', 'KIND_BUILDING'),
('BUILDING_ROSE_WAR_CHOICE_MARKER', 'KIND_BUILDING');
INSERT INTO Traits (TraitType, InternalOnly) VALUES ('TRAIT_ROSE_CHOICE_MARKER', 1);
INSERT INTO Buildings
    (BuildingType, Name, Cost, PrereqDistrict, InternalOnly, TraitType,
     Maintenance, Housing, Entertainment, CitizenSlots, Capital,
     DefenseModifier, OuterDefenseHitPoints, OuterDefenseStrength, RegionalRange)
VALUES ('BUILDING_ROSE_MILITARY_CHOICE_MARKER', 'Rose military choice marker',
        1, 'DISTRICT_CITY_CENTER', 1, 'TRAIT_ROSE_CHOICE_MARKER',
        0, 0, 0, 0, 0, 0, 0, 0, 0),
       ('BUILDING_ROSE_WAR_CHOICE_MARKER', 'Rose war choice marker',
        1, 'DISTRICT_CITY_CENTER', 1, 'TRAIT_ROSE_CHOICE_MARKER',
        0, 0, 0, 0, 0, 0, 0, 0, 0);

-- Holy Site gate of the follower beliefs: the stored yield is the adjacency
-- to test (Faith, even for Work Ethic's Production); presence-only gates
-- ignore it; AGENTS.md "Follower-belief yield signals"
INSERT INTO RoseChoiceDistricts (BiasId, DistrictType, YieldType)
SELECT BiasId, 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'
FROM RoseChoiceBiases
WHERE SourceKind = 'BELIEF' AND GateType IN ('ADJACENCY', 'HOLY_SITE');
