-- Rose AI behavior-tree operation roles and limits.

-- Rebuild the derived trainable city-assault roles.
DELETE FROM OpTeamRequirements
WHERE AiType IN (
    'UNITTYPE_ROSE_CONTRACT_COMBAT',
    'UNITTYPE_ROSE_CONTRACT_MELEE',
    'UNITTYPE_ROSE_SIEGE_STRIKE'
);
DELETE FROM UnitAiInfos
WHERE AiType IN (
    'UNITTYPE_ROSE_CONTRACT_COMBAT',
    'UNITTYPE_ROSE_CONTRACT_MELEE',
    'UNITTYPE_ROSE_SIEGE_STRIKE'
);
DELETE FROM UnitAiTypes
WHERE AiType IN (
    'UNITTYPE_ROSE_CONTRACT_COMBAT',
    'UNITTYPE_ROSE_CONTRACT_MELEE',
    'UNITTYPE_ROSE_SIEGE_STRIKE'
);

INSERT OR IGNORE INTO UnitAiTypes (AiType) VALUES
('UNITTYPE_ROSE_CONTRACT_COMBAT'),
('UNITTYPE_ROSE_CONTRACT_MELEE'),
('UNITTYPE_ROSE_SIEGE_STRIKE');

-- Normal city assaults were repeatedly issuing impossible production
-- contracts for the faith-only Warrior Monk. Derive trainable combat/melee
-- roles that exclude faith/religion-only units. Owned Warrior Monks retain all
-- of their native tactical roles; they simply are not recruited into these
-- two production-contract-driven operation teams.
INSERT OR IGNORE INTO UnitAiInfos (UnitType, AiType)
SELECT DISTINCT Info.UnitType, 'UNITTYPE_ROSE_CONTRACT_COMBAT'
FROM UnitAiInfos AS Info
JOIN Units AS Unit ON Unit.UnitType = Info.UnitType
WHERE Info.AiType = 'UNITAI_COMBAT'
  AND Unit.FormationClass = 'FORMATION_CLASS_LAND_COMBAT'
  AND Unit.CanTrain = 1
  AND Unit.MustPurchase = 0
  AND Unit.EnabledByReligion = 0
  AND Unit.UnitType <> 'UNIT_WARRIOR_MONK';

INSERT OR IGNORE INTO UnitAiInfos (UnitType, AiType)
SELECT DISTINCT Info.UnitType, 'UNITTYPE_ROSE_CONTRACT_MELEE'
FROM UnitAiInfos AS Info
JOIN Units AS Unit ON Unit.UnitType = Info.UnitType
WHERE Info.AiType = 'UNITTYPE_MELEE'
  AND Unit.FormationClass = 'FORMATION_CLASS_LAND_COMBAT'
  AND Unit.CanTrain = 1
  AND Unit.MustPurchase = 0
  AND Unit.EnabledByReligion = 0
  AND Unit.UnitType <> 'UNIT_WARRIOR_MONK';

-- Walled-city assaults need one unit that can damage walls. Bombers can do this
-- in the Modern era and later; the base Siege City Assault tree already has
-- air-assault nodes for them. This derived role (ground siege plus bombers) is
-- the team's mandatory minimum; see AI_BehaviorTrees.xml. Bombers are not added
-- to UNITTYPE_SIEGE itself (RH's approach), so City Defense, the settle escort
-- and the unwalled Simple City Attack Force keep their current unit pools.
INSERT OR IGNORE INTO UnitAiInfos (UnitType, AiType)
SELECT DISTINCT Info.UnitType, 'UNITTYPE_ROSE_SIEGE_STRIKE'
FROM UnitAiInfos AS Info
JOIN Units AS Unit ON Unit.UnitType = Info.UnitType
WHERE Info.AiType IN ('UNITTYPE_SIEGE', 'UNITTYPE_AIR_SIEGE')
  AND Unit.CanTrain = 1
  AND Unit.MustPurchase = 0
  AND Unit.EnabledByReligion = 0;

DELETE FROM OpTeamRequirements
WHERE TeamName IN ('Simple City Attack Force', 'City Attack Force')
  AND AiType IN ('UNITAI_COMBAT', 'UNITTYPE_MELEE');

INSERT OR REPLACE INTO OpTeamRequirements
    (TeamName, AiType, MinNumber, MaxNumber) VALUES
('Simple City Attack Force', 'UNITTYPE_ROSE_CONTRACT_COMBAT', 5, 16),
('Simple City Attack Force', 'UNITTYPE_ROSE_CONTRACT_MELEE',  2, NULL),
('City Attack Force',        'UNITTYPE_ROSE_CONTRACT_COMBAT', 5, 16),
('City Attack Force',        'UNITTYPE_ROSE_CONTRACT_MELEE',  2, NULL);

-- The base military-victory strategy adds two CITY_ASSAULT slots on top of
-- the global and per-war allowances. Logs showed military leaders splitting
-- one army across as many as four targets, so retain one bonus slot instead.
UPDATE AiFavoredItems
SET Value = 1
WHERE ListType = 'MilitaryVictoryOperations'
  AND Item = 'CITY_ASSAULT';

-- Keep settlement concurrency at one. A second operation can compete for
-- escorts or select the same unreserved destination when a free Settler (for
-- example, from Religious Settlements) appears while another operation is
-- active. One operation is slower in the best case but avoids that contention.
UPDATE AiFavoredItems
SET Value = 1
WHERE ListType = 'BaseOperationsLimits'
  AND Item = 'OP_SETTLE';

-- Wartime city assaults get their own operation type and slots. Both assault
-- families used CITY_ASSAULT, and when both were evaluated on the same turn the
-- planned definition scored higher or tied 296 times in 307 (2026-10-04 test),
-- so planned attacks (half of them on city-states during major wars) held the
-- slots and majors started 5 wartime assaults against 225 planned. The DLL's
-- selection loop skips a candidate whose type is full and moves on, so separate
-- types let both start. For majors the per-war slot moves to the new type and
-- the total is unchanged: 1 planned (+1 with the military-victory strategy)
-- plus 1 wartime per war. The DLL looks up only the name CITY_ASSAULT, for
-- reactive starts against an observed foreign operation, which now use the
-- planned definitions; HasOperationAgainst (war declaration) ignores the type.
-- The definitions are retyped in AI_BehaviorTrees.xml. Military Recovery's -1
-- stays on CITY_ASSAULT only (AI_Strategies.sql), so a recovering AI keeps its
-- wartime slot against the war enemy.
-- The value is the next free one (base uses 0-6), as RH does for its own types.
INSERT INTO AiOperationTypes (OperationType, Value)
SELECT 'ROSE_WARTIME_ASSAULT', MAX(Value) + 1 FROM AiOperationTypes
WHERE NOT EXISTS (SELECT 1 FROM AiOperationTypes WHERE OperationType = 'ROSE_WARTIME_ASSAULT');

UPDATE AiFavoredItems
SET Value = 0
WHERE ListType = 'PerWarOperationsLimits'
  AND Item = 'CITY_ASSAULT';

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('PerWarOperationsLimits', 'ROSE_WARTIME_ASSAULT', 1, 1);

-- City-states started more wartime than planned assaults (8 and 6 against 1
-- and 0 in the last two tests) but had no per-war list, so without one they
-- could never start a wartime assault again. Attach the same per-war list to
-- them rather than a second base list: whether the engine adds two leader lists
-- of one system together is unverified, and a replaced base list would cost
-- them City Defense. They keep their planned slot, so a city-state gains one
-- wartime slot per war; they start planned assaults rarely (3, 1, 0 in three tests).
-- The Free Cities player is unaffected: its operation list holds only
-- "Free Cities Raid". Anything added to PerWarOperationsLimits later also
-- applies to city-states.
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('PerWarOperationsLimits', 'MINOR_CIV_DEFAULT_TRAIT', 'PerWarOperationTypes');

-- City Defense has no OperationType in base data, so nothing limited how many
-- ran at once: up to 12 per AI in the 2026-10-04 test, holding about a quarter
-- of a warring AI's land units. AI_BehaviorTrees.xml gives it OP_DEFENSE; the
-- base limit for that type (shared with city-states) rises from 1 to 3, and
-- Military Recovery's existing +2 now applies (5). City-states never ran more
-- than 3 at once in the last two tests. RH uses OP_DEFENSE with a limit of 2.
UPDATE AiFavoredItems
SET Value = 3
WHERE ListType = 'BaseOperationsLimits'
  AND Item = 'OP_DEFENSE';
