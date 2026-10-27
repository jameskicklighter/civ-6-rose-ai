-- ============================================================================
-- Rose AI: lists attached to leader and civilization traits (AiLists.LeaderType
-- holds the trait), and the leader-and-era lists, which carry no LeaderType and
-- sit on a leader era window strategy instead (Rose_Strategies.sql): a trait's
-- lists apply in every era and a strategy's lists to every player.
-- Trait membership is in Rose_Leader_Traits.sql.
-- AGENTS.md "## Current Features", "### leaders/ (Rose_Leader_Traits.sql, Rose_Leader_Lists.sql)".
-- ============================================================================

-- Religious leaders: Holy Site favored, Ancient and Classical eras; AGENTS.md "Religious leader Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousEarlyDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseReligiousEarlyDistricts',    'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',  'RoseReligiousEarlyDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousEarlyDistricts',    'DISTRICT_HOLY_SITE', 1, 100);

-- Religious leaders: Great Prophet points, Ancient and Classical eras; AGENTS.md "Religious leader Great Prophet pseudoyield"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousEarlyPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseReligiousEarlyPseudoYields', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RELIGIOUS_EARLY',  'RoseReligiousEarlyPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousEarlyPseudoYields', 'PSEUDOYIELD_GPP_PROPHET', 1, 100);

-- Saladin (both personas): a Holy Site before his free Prophet, Classical and Medieval eras; AGENTS.md "Saladin Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseSaladinHolySiteDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseSaladinHolySiteDistricts',   'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_SALADIN_HOLY_SITE', 'RoseSaladinHolySiteDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseSaladinHolySiteDistricts',   'DISTRICT_HOLY_SITE', 1, 50);

-- Avoid Early Holy Sites leaders: Holy Site disfavored, Ancient and Classical eras; AGENTS.md "Avoid Early Holy Sites trait created"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSEarlyDistricts');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAvoidHSEarlyDistricts',      'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_AVOID_HOLY_SITES_EARLY', 'RoseAvoidHSEarlyDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSEarlyDistricts',      'DISTRICT_HOLY_SITE', 0, -100);

-- Low religious preference: Stonehenge always disfavored (a Buildings list has no effect on a strategy); AGENTS.md "Stonehenge disfavored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseLowRelBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseLowRelBuildings',  'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE',    'Buildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseLowRelBuildings',  'BUILDING_STONEHENGE', 0, -100);

-- Avoid Early Holy Sites leaders: Stonehenge always disfavored; AGENTS.md "Stonehenge disfavored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAvoidHSBuildings', 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 'Buildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSBuildings', 'BUILDING_STONEHENGE', 0, -100);

-- Religious leaders: Stonehenge always favored (both Saladins are outside the
-- group); Theodora's base disfavor is removed so it does not cancel the favor;
-- AGENTS.md "Religious leader Stonehenge favored"
DELETE FROM AiFavoredItems
WHERE ListType = 'TheodoraWonders' AND Item = 'BUILDING_STONEHENGE';
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousBuildings', 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'Buildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousBuildings', 'BUILDING_STONEHENGE', 1, 100);

-- Naval-bias leaders: Harbor always favored (England and Dido have their
-- unique district list instead); AGENTS.md "Naval bias trait created"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseNavalBiasDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseNavalBiasDistricts', 'TRAIT_LEADER_ROSE_NAVAL_BIAS', 'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseNavalBiasDistricts', 'DISTRICT_HARBOR', 1, 50);

-- Original Harald: the engine's native Coastal Raid tactic (no tree node can
-- issue it); the alternate Harald lacks the ability; AGENTS.md "Original Harald raid support"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseHaraldRaidTactics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseHaraldRaidTactics',    'TRAIT_LEADER_MELEE_COASTAL_RAIDS', 'Tactics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseHaraldRaidTactics',    'Coastal Raid',                  1, 2);

-- Original Harald: naval melee production; AGENTS.md "Original Harald raid support"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseHaraldRaidUnitBuilds');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseHaraldRaidUnitBuilds', 'TRAIT_LEADER_MELEE_COASTAL_RAIDS', 'UnitPromotionClasses');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseHaraldRaidUnitBuilds', 'PROMOTION_CLASS_NAVAL_MELEE',   1, 15);

-- Basil: moderate cavalry preference; AGENTS.md "Basil religious-war support"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseBasilWarUnitBuilds');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseBasilWarUnitBuilds', 'TRAIT_LEADER_BASIL', 'UnitPromotionClasses');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseBasilWarUnitBuilds', 'PROMOTION_CLASS_HEAVY_CAVALRY', 1, 10),
('RoseBasilWarUnitBuilds', 'PROMOTION_CLASS_LIGHT_CAVALRY', 1, 8);

-- Basil: Holy War favored; AGENTS.md "Basil religious-war support"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseBasilWarDiplomacy');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseBasilWarDiplomacy',  'TRAIT_LEADER_BASIL', 'DiplomaticActions');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseBasilWarDiplomacy',  'DIPLOACTION_DECLARE_HOLY_WAR',  1, 40);

-- The four aggressive-military lists below are emptied before they are filled.
DELETE FROM AiFavoredItems
WHERE ListType IN (
    'RoseAggressiveMilitaryPseudoYields',
    'RoseAggressiveMilitaryDiplomacy',
    'RoseAggressiveMilitaryBuildings',
    'RoseAggressiveMilitaryTechs'
);

-- Aggressive military: friendship penalty, a standing army in every era and
-- nuclear device demand; AGENTS.md "Aggressive military diplomacy and army",
-- "Aggressive-military nuclear preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAggressiveMilitaryPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAggressiveMilitaryPseudoYields', 'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'PseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_DIPLOMATIC_BONUS',    1, -15),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',         1,  30),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER', 1, 20),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',  1, 15),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_NUCLEAR_WEAPON',      1,  20);

-- Aggressive military: formal and surprise war and nuclear use favored
-- ("Will use nukes" then passes without a negative war value); AGENTS.md
-- "Aggressive military diplomacy and army", "Aggressive-military nuclear preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAggressiveMilitaryDiplomacy');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAggressiveMilitaryDiplomacy',    'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'DiplomaticActions');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAggressiveMilitaryDiplomacy',    'DIPLOACTION_DECLARE_FORMAL_WAR',  1,   0),
('RoseAggressiveMilitaryDiplomacy',    'DIPLOACTION_DECLARE_SURPRISE_WAR', 1,  0),
('RoseAggressiveMilitaryDiplomacy',    'DIPLOACTION_USE_NUCLEAR_WEAPON',  1,   0);

-- Aggressive military: Grand Master's Chapel, so Faith can buy land units;
-- AGENTS.md "Aggressive military diplomacy and army"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAggressiveMilitaryBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAggressiveMilitaryBuildings',    'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'Buildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAggressiveMilitaryBuildings',    'BUILDING_GOV_FAITH',               1, 100);

-- Aggressive military: the techs to Uranium, devices, the Bomber and
-- thermonuclear devices, with their Modern/Atomic prerequisites (a tech list
-- acts only once a tech is available); AGENTS.md "Aggressive-military nuclear preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAggressiveMilitaryTechs');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAggressiveMilitaryTechs',        'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'Technologies');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAggressiveMilitaryTechs',        'TECH_STEEL',                       1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_COMBUSTION',                  1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_REPLACEABLE_PARTS',           1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_ADVANCED_BALLISTICS',         1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_COMBINED_ARMS',               1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_NUCLEAR_FISSION',             1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_ADVANCED_FLIGHT',             1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_NUCLEAR_FUSION',              1, 100);

-- Gandhi: Nuke Happy's device demand, permanent (base GandhiTechs and the
-- base agenda lists are untouched); AGENTS.md "Gandhi always nuclear-willing"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGandhiPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseGandhiPseudoYields', 'TRAIT_LEADER_SATYAGRAHA', 'PseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseGandhiPseudoYields', 'PSEUDOYIELD_NUCLEAR_WEAPON',     1, 20);

-- Gandhi: nuclear use favored; AGENTS.md "Gandhi always nuclear-willing"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGandhiDiplomacy');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseGandhiDiplomacy',    'TRAIT_LEADER_SATYAGRAHA', 'DiplomaticActions');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseGandhiDiplomacy',    'DIPLOACTION_USE_NUCLEAR_WEAPON', 1,  0);

-- Gandhi: the same eight techs as RoseAggressiveMilitaryTechs; AGENTS.md "Gandhi always nuclear-willing"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGandhiTechs');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseGandhiTechs',        'TRAIT_LEADER_SATYAGRAHA', 'Technologies');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseGandhiTechs',        'TECH_STEEL',                     1, 100),
('RoseGandhiTechs',        'TECH_COMBUSTION',                1, 100),
('RoseGandhiTechs',        'TECH_REPLACEABLE_PARTS',         1, 100),
('RoseGandhiTechs',        'TECH_ADVANCED_BALLISTICS',       1, 100),
('RoseGandhiTechs',        'TECH_COMBINED_ARMS',             1, 100),
('RoseGandhiTechs',        'TECH_NUCLEAR_FISSION',           1, 100),
('RoseGandhiTechs',        'TECH_ADVANCED_FLIGHT',           1, 100),
('RoseGandhiTechs',        'TECH_NUCLEAR_FUSION',            1, 100);

-- Bull Moose Roosevelt: Preserve always favored; AGENTS.md "Bull Moose Roosevelt Preserve favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRooseveltDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseRooseveltDistricts', 'TRAIT_LEADER_ANTIQUES_AND_PARKS',    'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRooseveltDistricts', 'DISTRICT_PRESERVE', 1, 100);

-- John Curtin: Preserve always favored; AGENTS.md "John Curtin Preserve favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseCurtinDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseCurtinDistricts',    'TRAIT_LEADER_CITADEL_CIVILIZATION',  'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseCurtinDistricts',    'DISTRICT_PRESERVE', 1, 100);

-- Maori (civilization trait, so any Maori leader): Preserve always favored; AGENTS.md "Maori Preserve favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMaoriDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMaoriDistricts',     'TRAIT_CIVILIZATION_MAORI_MANA',      'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMaoriDistricts',     'DISTRICT_PRESERVE', 1, 100);

-- Hammurabi: Theater Square always favored; AGENTS.md "Hammurabi Theater Square favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseHammurabiDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseHammurabiDistricts', 'TRAIT_LEADER_HAMMURABI',             'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseHammurabiDistricts', 'DISTRICT_THEATER',  1, 100);

-- Bull Moose Roosevelt: Mysticism (needed for Preserves) always favored (a Civics list has no effect on a strategy); AGENTS.md "Mysticism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRooseveltCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseRooseveltCivics', 'TRAIT_LEADER_ANTIQUES_AND_PARKS',   'Civics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRooseveltCivics', 'CIVIC_MYSTICISM', 1, 100);

-- John Curtin: Mysticism always favored; AGENTS.md "Mysticism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseCurtinCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseCurtinCivics',    'TRAIT_LEADER_CITADEL_CIVILIZATION', 'Civics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseCurtinCivics',    'CIVIC_MYSTICISM', 1, 100);
