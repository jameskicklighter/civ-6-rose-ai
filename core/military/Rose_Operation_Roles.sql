-- ============================================================================
-- Rose AI: derived unit AI roles, city-assault team rows, the wartime
-- operation type and operation slot limits. Loads before the military XML,
-- which uses UNITTYPE_ROSE_* and ROSE_WARTIME_ASSAULT.
-- AGENTS.md "### military/ (Rose_Operation_Roles.sql, Operations.xml, trees/)", 'Known engine behaviour: operation recruitment and slots'.
-- ============================================================================

-- The three derived roles are rebuilt from scratch.
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

-- Trainable combat and melee roles without faith-only units, so city assaults
-- stop contracting Warrior Monks (owned ones keep their native roles);
-- AGENTS.md "City-assault production-contract roles"
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

-- Wall-breaker role: trainable ground siege units and bombers, the walled
-- assault's mandatory minimum (bombers stay out of UNITTYPE_SIEGE, so other
-- teams keep their pools); AGENTS.md "Walled-city siege composition"
INSERT OR IGNORE INTO UnitAiInfos (UnitType, AiType)
SELECT DISTINCT Info.UnitType, 'UNITTYPE_ROSE_SIEGE_STRIKE'
FROM UnitAiInfos AS Info
JOIN Units AS Unit ON Unit.UnitType = Info.UnitType
WHERE Info.AiType IN ('UNITTYPE_SIEGE', 'UNITTYPE_AIR_SIEGE')
  AND Unit.CanTrain = 1
  AND Unit.MustPurchase = 0
  AND Unit.EnabledByReligion = 0;

-- City-assault teams recruit through the derived roles;
-- AGENTS.md "City-assault production-contract roles"
DELETE FROM OpTeamRequirements
WHERE TeamName IN ('Simple City Attack Force', 'City Attack Force')
  AND AiType IN ('UNITAI_COMBAT', 'UNITTYPE_MELEE');

INSERT OR REPLACE INTO OpTeamRequirements
    (TeamName, AiType, MinNumber, MaxNumber) VALUES
('Simple City Attack Force', 'UNITTYPE_ROSE_CONTRACT_COMBAT', 5, 16),
('Simple City Attack Force', 'UNITTYPE_ROSE_CONTRACT_MELEE',  2, NULL),
('City Attack Force',        'UNITTYPE_ROSE_CONTRACT_COMBAT', 5, 16),
('City Attack Force',        'UNITTYPE_ROSE_CONTRACT_MELEE',  2, NULL);

-- Military Victory adds one CITY_ASSAULT slot instead of two;
-- AGENTS.md "City-assault concentration"
UPDATE AiFavoredItems
SET Value = 1
WHERE ListType = 'MilitaryVictoryOperations'
  AND Item = 'CITY_ASSAULT';

-- One settle operation at a time (two competed for escorts and destinations);
-- AGENTS.md "Settlement operation concurrency"
UPDATE AiFavoredItems
SET Value = 1
WHERE ListType = 'BaseOperationsLimits'
  AND Item = 'OP_SETTLE';

-- Wartime assaults get their own operation type, so a full planned slot cannot
-- block them (the selection loop skips a full type and moves on); the value is
-- the next free one after the base 0-6; AGENTS.md "Wartime assault slots"
INSERT INTO AiOperationTypes (OperationType, Value)
SELECT 'ROSE_WARTIME_ASSAULT', MAX(Value) + 1 FROM AiOperationTypes
WHERE NOT EXISTS (SELECT 1 FROM AiOperationTypes WHERE OperationType = 'ROSE_WARTIME_ASSAULT');

-- No per-war planned slot; AGENTS.md "Wartime assault slots"
UPDATE AiFavoredItems
SET Value = 0
WHERE ListType = 'PerWarOperationsLimits'
  AND Item = 'CITY_ASSAULT';

-- One wartime slot in all, whatever the number of wars (the base list is
-- shared by majors and city-states); AGENTS.md "Wartime assault slots"
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('BaseOperationsLimits', 'ROSE_WARTIME_ASSAULT', 1, 1);

-- City Defense (typed OP_DEFENSE in Operations.xml): 3 at once, 5 under
-- Military Recovery; AGENTS.md "City Defense cap"
UPDATE AiFavoredItems
SET Value = 3
WHERE ListType = 'BaseOperationsLimits'
  AND Item = 'OP_DEFENSE';
