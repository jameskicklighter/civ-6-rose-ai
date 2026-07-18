-- Rose AI behavior-tree operation roles and limits.

-- Rebuild the derived trainable city-assault roles.
DELETE FROM OpTeamRequirements
WHERE AiType IN ('UNITTYPE_ROSE_CONTRACT_COMBAT', 'UNITTYPE_ROSE_CONTRACT_MELEE');
DELETE FROM UnitAiInfos
WHERE AiType IN (
    'UNITTYPE_ROSE_CONTRACT_COMBAT',
    'UNITTYPE_ROSE_CONTRACT_MELEE'
);
DELETE FROM UnitAiTypes
WHERE AiType IN (
    'UNITTYPE_ROSE_CONTRACT_COMBAT',
    'UNITTYPE_ROSE_CONTRACT_MELEE'
);

INSERT OR IGNORE INTO UnitAiTypes (AiType) VALUES
('UNITTYPE_ROSE_CONTRACT_COMBAT'),
('UNITTYPE_ROSE_CONTRACT_MELEE');

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
