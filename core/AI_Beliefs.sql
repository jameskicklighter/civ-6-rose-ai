-- ============================================================================
-- Rose AI: Dummy-Gold Belief Preferences
-- ============================================================================
-- RoseGoldBiases is the single source of truth for both the database modifiers
-- and the Lua treasury clawback. Belief bonuses are fixed, empire-wide Gold;
-- they apply only to an AI player that founded the religion containing them.
-- ============================================================================

CREATE TABLE IF NOT EXISTS RoseGoldBiases (
    BiasId     TEXT    NOT NULL PRIMARY KEY,
    SourceKind TEXT    NOT NULL,
    SourceType TEXT    NOT NULL,
    Amount     INTEGER NOT NULL,
    GateType   TEXT    NOT NULL DEFAULT 'ALWAYS',
    GateValue  TEXT
);

CREATE TABLE IF NOT EXISTS RoseGoldBiasDistricts (
    BiasId      TEXT NOT NULL,
    DistrictType TEXT NOT NULL,
    PRIMARY KEY (BiasId, DistrictType)
);

CREATE TABLE IF NOT EXISTS RoseGoldBiasResolvedDistricts (
    BiasId      TEXT NOT NULL,
    DistrictType TEXT NOT NULL,
    PRIMARY KEY (BiasId, DistrictType)
);

INSERT OR REPLACE INTO RoseGoldBiases
    (BiasId, SourceKind, SourceType, Amount, GateType) VALUES
('ROSE_GOLD_BELIEF_WORK_ETHIC',          'BELIEF', 'BELIEF_WORK_ETHIC',          20, 'FOUNDER'),
('ROSE_GOLD_BELIEF_JESUIT_EDUCATION',    'BELIEF', 'BELIEF_JESUIT_EDUCATION',    20, 'FOUNDER'),
('ROSE_GOLD_BELIEF_CHORAL_MUSIC',        'BELIEF', 'BELIEF_CHORAL_MUSIC',        20, 'FOUNDER'),
('ROSE_GOLD_BELIEF_FEED_THE_WORLD',      'BELIEF', 'BELIEF_FEED_THE_WORLD',      20, 'FOUNDER'),
('ROSE_GOLD_BELIEF_ZEN_MEDITATION',      'BELIEF', 'BELIEF_ZEN_MEDITATION',      20, 'FOUNDER'),
('ROSE_GOLD_BELIEF_RELIGIOUS_COMMUNITY', 'BELIEF', 'BELIEF_RELIGIOUS_COMMUNITY', 20, 'FOUNDER'),
-- Crusade's internal type remains BELIEF_JUST_WAR.
('ROSE_GOLD_BELIEF_CRUSADE',             'BELIEF', 'BELIEF_JUST_WAR',            20, 'FOUNDER');

INSERT OR IGNORE INTO RequirementSets
    (RequirementSetId, RequirementSetType) VALUES
('ROSE_GOLD_AI_RELIGION_FOUNDER', 'REQUIREMENTSET_TEST_ALL');

INSERT OR IGNORE INTO RequirementSetRequirements
    (RequirementSetId, RequirementId) VALUES
('ROSE_GOLD_AI_RELIGION_FOUNDER', 'REQUIRES_PLAYER_IS_AI'),
('ROSE_GOLD_AI_RELIGION_FOUNDER', 'REQUIRES_PLAYER_FOUNDED_RELIGION');

INSERT OR IGNORE INTO Modifiers
    (ModifierId, ModifierType, SubjectRequirementSetId)
SELECT b.BiasId,
       'MODIFIER_PLAYER_ADJUST_YIELD_CHANGE',
       'ROSE_GOLD_AI_RELIGION_FOUNDER'
FROM RoseGoldBiases b
JOIN Beliefs source ON source.BeliefType = b.SourceType
WHERE b.SourceKind = 'BELIEF';

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
SELECT b.BiasId, 'YieldType', 'YIELD_GOLD'
FROM RoseGoldBiases b
JOIN Beliefs source ON source.BeliefType = b.SourceType
WHERE b.SourceKind = 'BELIEF'
UNION ALL
SELECT b.BiasId, 'Amount', b.Amount
FROM RoseGoldBiases b
JOIN Beliefs source ON source.BeliefType = b.SourceType
WHERE b.SourceKind = 'BELIEF';

INSERT OR IGNORE INTO BeliefModifiers (BeliefType, ModifierId)
SELECT b.SourceType, b.BiasId
FROM RoseGoldBiases b
JOIN Beliefs source ON source.BeliefType = b.SourceType
WHERE b.SourceKind = 'BELIEF';
