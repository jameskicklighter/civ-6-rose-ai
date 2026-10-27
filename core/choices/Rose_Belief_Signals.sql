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

-- Holy Site gate of the follower beliefs: the stored yield is the adjacency
-- to test (Faith, even for Work Ethic's Production); presence-only gates
-- ignore it; AGENTS.md "Follower-belief yield signals"
INSERT INTO RoseChoiceDistricts (BiasId, DistrictType, YieldType)
SELECT BiasId, 'DISTRICT_HOLY_SITE', 'YIELD_FAITH'
FROM RoseChoiceBiases
WHERE SourceKind = 'BELIEF' AND GateType IN ('ADJACENCY', 'HOLY_SITE');
