-- ============================================================================
-- Rose AI: lists attached to leader and civilization traits (AiLists.LeaderType
-- holds the trait), some also tied to an era strategy (Strategy_Priorities).
-- Trait membership is in Rose_Leader_Traits.sql.
-- AGENTS.md "## Current Features", "### leaders/ (Rose_Leader_Traits.sql, Rose_Leader_Lists.sql)".
-- ============================================================================

-- Religious leaders: Holy Site favored in the Ancient era; AGENTS.md "Religious leader Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousAncientDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousAncientDistricts',   'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseReligiousAncientDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousAncientDistricts',   'DISTRICT_HOLY_SITE', 1, 100);

-- Religious leaders: Holy Site favored in the Classical era; AGENTS.md "Religious leader Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousClassicalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousClassicalDistricts', 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseReligiousClassicalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousClassicalDistricts', 'DISTRICT_HOLY_SITE', 1, 100);

-- Religious leaders: Great Prophet points in the Ancient era; AGENTS.md "Religious leader Great Prophet pseudoyield"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousAncientPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousAncientPseudoYields',   'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseReligiousAncientPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousAncientPseudoYields',   'PSEUDOYIELD_GPP_PROPHET', 1, 100);

-- Religious leaders: Great Prophet points in the Classical era; AGENTS.md "Religious leader Great Prophet pseudoyield"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousClassicalPseudoYields');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousClassicalPseudoYields', 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'PseudoYields');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseReligiousClassicalPseudoYields');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousClassicalPseudoYields', 'PSEUDOYIELD_GPP_PROPHET', 1, 100);

-- Saladin: a Holy Site before his free Prophet, Classical era; AGENTS.md "Saladin Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseSaladinClassicalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseSaladinClassicalDistricts',    'TRAIT_LEADER_RIGHTEOUSNESS_OF_FAITH', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseSaladinClassicalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseSaladinClassicalDistricts',    'DISTRICT_HOLY_SITE', 1, 50);

-- Saladin: Holy Site, Medieval era; AGENTS.md "Saladin Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseSaladinMedievalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseSaladinMedievalDistricts',     'TRAIT_LEADER_RIGHTEOUSNESS_OF_FAITH', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',  'RoseSaladinMedievalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseSaladinMedievalDistricts',     'DISTRICT_HOLY_SITE', 1, 50);

-- Saladin (Vizier, his own unique trait): Holy Site, Classical era; AGENTS.md "Saladin Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseSaladinAltClassicalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseSaladinAltClassicalDistricts', 'TRAIT_LEADER_SALADIN_ALT',            'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseSaladinAltClassicalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseSaladinAltClassicalDistricts', 'DISTRICT_HOLY_SITE', 1, 50);

-- Saladin (Vizier): Holy Site, Medieval era; AGENTS.md "Saladin Holy Site favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseSaladinAltMedievalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseSaladinAltMedievalDistricts',  'TRAIT_LEADER_SALADIN_ALT',            'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',  'RoseSaladinAltMedievalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseSaladinAltMedievalDistricts',  'DISTRICT_HOLY_SITE', 1, 50);

-- Avoid Early Holy Sites leaders: Holy Site disfavored, Ancient era; AGENTS.md "Avoid Early Holy Sites trait created"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSAncientDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAvoidHSAncientDistricts',   'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseAvoidHSAncientDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSAncientDistricts',   'DISTRICT_HOLY_SITE', 0, -100);

-- Avoid Early Holy Sites leaders: Holy Site disfavored, Classical era; AGENTS.md "Avoid Early Holy Sites trait created"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSClassicalDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAvoidHSClassicalDistricts', 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 'Districts');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseAvoidHSClassicalDistricts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSClassicalDistricts', 'DISTRICT_HOLY_SITE', 0, -100);

-- Low religious preference: Stonehenge (a Buildings item) disfavored, Ancient era; AGENTS.md "Stonehenge disfavored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseLowRelAncientBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseLowRelAncientBuildings',    'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE',       'Buildings');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseLowRelAncientBuildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseLowRelAncientBuildings',    'BUILDING_STONEHENGE', 0, -100);

-- Low religious preference: Stonehenge disfavored, Classical era; AGENTS.md "Stonehenge disfavored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseLowRelClassicalBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseLowRelClassicalBuildings',  'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE',       'Buildings');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseLowRelClassicalBuildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseLowRelClassicalBuildings',  'BUILDING_STONEHENGE', 0, -100);

-- Avoid Early Holy Sites leaders: Stonehenge disfavored, Ancient era; AGENTS.md "Stonehenge disfavored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSAncientBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAvoidHSAncientBuildings',   'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES',   'Buildings');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseAvoidHSAncientBuildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSAncientBuildings',   'BUILDING_STONEHENGE', 0, -100);

-- Avoid Early Holy Sites leaders: Stonehenge disfavored, Classical era; AGENTS.md "Stonehenge disfavored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSClassicalBuildings');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAvoidHSClassicalBuildings', 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES',   'Buildings');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseAvoidHSClassicalBuildings');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSClassicalBuildings', 'BUILDING_STONEHENGE', 0, -100);

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

-- Hammurabi: Theater Square always favored; AGENTS.md "Hammurabi Theater Square favored"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseHammurabiDistricts');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseHammurabiDistricts', 'TRAIT_LEADER_HAMMURABI',             'Districts');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseHammurabiDistricts', 'DISTRICT_THEATER',  1, 100);

-- Bull Moose Roosevelt: Mysticism (needed for Preserves), Ancient era; AGENTS.md "Mysticism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRooseveltAncientCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseRooseveltAncientCivics',   'TRAIT_LEADER_ANTIQUES_AND_PARKS',    'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseRooseveltAncientCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRooseveltAncientCivics',   'CIVIC_MYSTICISM', 1, 100);

-- Bull Moose Roosevelt: Mysticism, Classical era; AGENTS.md "Mysticism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRooseveltClassicalCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseRooseveltClassicalCivics', 'TRAIT_LEADER_ANTIQUES_AND_PARKS',    'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseRooseveltClassicalCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRooseveltClassicalCivics', 'CIVIC_MYSTICISM', 1, 100);

-- John Curtin: Mysticism, Ancient era; AGENTS.md "Mysticism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseCurtinAncientCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseCurtinAncientCivics',      'TRAIT_LEADER_CITADEL_CIVILIZATION',  'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseCurtinAncientCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseCurtinAncientCivics',      'CIVIC_MYSTICISM', 1, 100);

-- John Curtin: Mysticism, Classical era; AGENTS.md "Mysticism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseCurtinClassicalCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseCurtinClassicalCivics',    'TRAIT_LEADER_CITADEL_CIVILIZATION',  'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseCurtinClassicalCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseCurtinClassicalCivics',    'CIVIC_MYSTICISM', 1, 100);
