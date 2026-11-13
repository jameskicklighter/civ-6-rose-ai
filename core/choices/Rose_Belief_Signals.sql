-- ============================================================================
-- Rose AI: the inactive choice-signal registry (RoseChoice* helper tables,
-- created here, so this file loads before Rose_Policy_Signals.sql) and its
-- belief entries. Rose_Policy_Signals.sql emits every registered modifier.
-- AGENTS.md "### choices/Rose_Belief_Signals.sql".
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

-- Pantheons that work only through a Holy Site: each adjacency pantheon gets a
-- Faith penalty in the capital, cancelled when the capital holds its terrain
-- marker, which also adds a bonus (more with the strong marker), so the AI's
-- own terrain count decides; River Goddess the same with the Khmer marker, so
-- only Khmer take it; Initiation Rites is penalised for every AI;
-- AGENTS.md "Holy Site pantheon signals"
WITH Signals (Suffix, SourceType, Amount, GateType, Marker) AS (VALUES
('_PALACE',         'BELIEF_SACRED_PATH',         -500, 'PALACE',         NULL),
('_CAPITAL_MARKER', 'BELIEF_SACRED_PATH',          500, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_JUNGLE'),
('_BONUS',          'BELIEF_SACRED_PATH',           10, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_JUNGLE'),
('_BONUS_STRONG',   'BELIEF_SACRED_PATH',           10, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_JUNGLE_STRONG'),
('_PALACE',         'BELIEF_DESERT_FOLKLORE',     -500, 'PALACE',         NULL),
('_CAPITAL_MARKER', 'BELIEF_DESERT_FOLKLORE',      500, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_DESERT'),
('_BONUS',          'BELIEF_DESERT_FOLKLORE',       10, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_DESERT'),
('_BONUS_STRONG',   'BELIEF_DESERT_FOLKLORE',       10, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_DESERT_STRONG'),
('_PALACE',         'BELIEF_DANCE_OF_THE_AURORA', -500, 'PALACE',         NULL),
('_CAPITAL_MARKER', 'BELIEF_DANCE_OF_THE_AURORA',  500, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_TUNDRA'),
('_BONUS',          'BELIEF_DANCE_OF_THE_AURORA',   10, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_TUNDRA'),
('_BONUS_STRONG',   'BELIEF_DANCE_OF_THE_AURORA',   10, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_TUNDRA_STRONG'),
('_PALACE',         'BELIEF_RIVER_GODDESS',       -500, 'PALACE',         NULL),
('_CAPITAL_MARKER', 'BELIEF_RIVER_GODDESS',        500, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_KHMER'),
('_BONUS',          'BELIEF_RIVER_GODDESS',         20, 'CAPITAL_MARKER', 'BUILDING_ROSE_PANTHEON_MARKER_KHMER'),
('_CAPITAL',        'BELIEF_INITIATION_RITES',    -500, 'CAPITAL',        NULL)
)
INSERT INTO RoseChoiceBiases (BiasId, SourceKind, SourceType, Amount, GateType, GateValue, YieldType)
SELECT 'ROSE_CHOICE_' || s.SourceType || s.Suffix, 'BELIEF', s.SourceType, s.Amount, s.GateType, s.Marker, 'YIELD_FAITH'
FROM Signals s
JOIN Beliefs source ON source.BeliefType = s.SourceType;

-- The pantheon markers: hidden buildings with no effect, which the choice
-- scorer can read; scripts/Rose_AI_Choices.lua places them in an AI's capital
-- before its pantheon (terrain: 3 or more matching plots within 2 rings of a
-- city, strong: 6 or more; Khmer, for a Khmer leader who can build Holy
-- Sites). Their unassigned trait keeps anyone from building them and
-- InternalOnly hides them from the Civilopedia; the name is the tooltip line;
-- AGENTS.md "Holy Site pantheon signals"
CREATE TABLE RosePantheonMarkers (
    BuildingType TEXT NOT NULL PRIMARY KEY,
    Name TEXT NOT NULL
);
INSERT INTO RosePantheonMarkers (BuildingType, Name) VALUES
('BUILDING_ROSE_PANTHEON_MARKER_JUNGLE',        'Rose Pantheon Marker (Rainforest)'),
('BUILDING_ROSE_PANTHEON_MARKER_JUNGLE_STRONG', 'Rose Pantheon Marker (Rainforest, Strong)'),
('BUILDING_ROSE_PANTHEON_MARKER_DESERT',        'Rose Pantheon Marker (Desert)'),
('BUILDING_ROSE_PANTHEON_MARKER_DESERT_STRONG', 'Rose Pantheon Marker (Desert, Strong)'),
('BUILDING_ROSE_PANTHEON_MARKER_TUNDRA',        'Rose Pantheon Marker (Tundra)'),
('BUILDING_ROSE_PANTHEON_MARKER_TUNDRA_STRONG', 'Rose Pantheon Marker (Tundra, Strong)'),
('BUILDING_ROSE_PANTHEON_MARKER_KHMER',         'Rose Pantheon Marker (Khmer)');
INSERT INTO Types (Type, Kind)
SELECT 'TRAIT_ROSE_CHOICE_MARKER', 'KIND_TRAIT'
UNION ALL
SELECT BuildingType, 'KIND_BUILDING' FROM RosePantheonMarkers;
INSERT INTO Traits (TraitType, InternalOnly) VALUES ('TRAIT_ROSE_CHOICE_MARKER', 1);
INSERT INTO Buildings
    (BuildingType, Name, Cost, PrereqDistrict, InternalOnly, TraitType,
     Maintenance, Housing, Entertainment, CitizenSlots, Capital,
     DefenseModifier, OuterDefenseHitPoints, OuterDefenseStrength, RegionalRange)
SELECT BuildingType, Name, 1, 'DISTRICT_CITY_CENTER', 1, 'TRAIT_ROSE_CHOICE_MARKER',
       0, 0, 0, 0, 0, 0, 0, 0, 0
FROM RosePantheonMarkers;

-- Holy Site gate of the belief signals: the stored yield is the adjacency
-- to test (Faith, even for Work Ethic's Production); presence-only gates
-- ignore it; AGENTS.md "Follower-belief yield signals"
INSERT INTO RoseChoiceDistricts (BiasId, DistrictType, YieldType)
SELECT BiasId, 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'
FROM RoseChoiceBiases
WHERE SourceKind = 'BELIEF' AND GateType IN ('ADJACENCY', 'HOLY_SITE');
