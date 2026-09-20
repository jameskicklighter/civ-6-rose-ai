-- ============================================================================
-- Rose AI: Inactive belief choice signals and shared registry
-- ============================================================================
-- AI_Policies.sql emits all registered modifiers after adding policy/government
-- rows. Yield signals and city envoy signals have an impossible PLAYER owner gate and city
-- subject checks; they never grant gameplay yields. Belief-choice scoring still
-- needs its own runtime test. Do not require a religion already founded for the
-- Holy Site signals: these beliefs are also evaluated during religion founding.

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

-- Jesuit Science and Zen Food retain the proxies from the original belief
-- implementation (b94b5af). The other values are the current requested amounts.
-- Only Work Ethic requires adjacency; all other follower signals need a Holy
-- Site (including its unique replacement), without a building/adjacency check.
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

-- Crusade: the scorer cannot read a leader-trait requirement. A gameplay
-- helper maintains a zero-yield hidden marker for military AI leaders instead.
-- Its city-scoped envoy signal requires BOTH that marker and a Palace in the same city.
-- Only the Palace city contributes, so this preference does not grow per city.
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT 'ROSE_CHOICE_BELIEF_CRUSADE', 'BELIEF', BeliefType, 1, 'MILITARY_MARKER', NULL
FROM Beliefs WHERE BeliefType = 'BELIEF_JUST_WAR';

-- Defender of the Faith: any major AI currently fighting another major civ.
-- The temporary war marker is separate from Crusade's military-leader marker.
-- Palace + war marker gives one contribution; no religion/founder check needed.
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, YieldType)
SELECT 'ROSE_CHOICE_BELIEF_DEFENDER_OF_FAITH', 'BELIEF', BeliefType, 1, 'WAR_MARKER', NULL
FROM Beliefs WHERE BeliefType = 'BELIEF_DEFENDER_OF_FAITH';

-- Both collection and effect are registered in the AI scorer. Unlike the base
-- player-scoped envoy modifier, this enumerates cities before testing subjects.
-- The effect's no-match fallback adds no score. The impossible owner gate in
-- AI_Policies.sql prevents this scoring-only pairing from activating in gameplay.
INSERT INTO Types (Type, Kind) VALUES
('MODIFIER_ROSE_CITIES_INACTIVE_ENVOY', 'KIND_MODIFIER');
INSERT INTO DynamicModifiers (ModifierType, CollectionType, EffectType) VALUES
('MODIFIER_ROSE_CITIES_INACTIVE_ENVOY', 'COLLECTION_PLAYER_CITIES',
 'EFFECT_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN');

-- An unassigned trait prevents normal construction; Lua supplies the marker.
-- InternalOnly hides it from ordinary production. No BuildingModifiers, yields,
-- maintenance, housing, amenities, slots, defenses, or capital designation.
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

-- The tested adjacency yield is Faith, even when the advertised benefit is
-- Production. Presence-only Holy Site gates ignore this stored yield field.
INSERT INTO RoseChoiceDistricts (BiasId, DistrictType, YieldType)
SELECT BiasId, 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'
FROM RoseChoiceBiases
WHERE SourceKind = 'BELIEF' AND GateType IN ('ADJACENCY', 'HOLY_SITE');
