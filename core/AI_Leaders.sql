-- ============================================================================
-- Rose AI: Leader-Specific Changes
-- Trait additions/removals, plus leader-specific district and pseudoyield
-- priorities. Generic (non-leader) items belong in AI_Districts/AI_Yields.
-- ============================================================================

-- ============================================================================
-- 1. TRAIT ADDITIONS & REMOVALS
-- ============================================================================

-- Add religious trait to leaders who should prioritize religion
INSERT OR IGNORE INTO LeaderTraits (LeaderType, TraitType) VALUES
('LEADER_BASIL',          'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'),
('LEADER_GITARJA',        'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'),
('LEADER_MENELIK',        'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'),
('LEADER_MANSA_MUSA',     'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'),
('LEADER_SUNDIATA_KEITA', 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'),
('LEADER_HARDRADA',       'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'),
('LEADER_HARALD_ALT',     'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV');

-- Remove religious trait from both Saladins (gets last Prophet for free)
DELETE FROM LeaderTraits
WHERE TraitType = 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV'
  AND LeaderType IN ('LEADER_SALADIN', 'LEADER_SALADIN_ALT');

-- Reclassify Saladin Alt as aggressive military
INSERT OR IGNORE INTO LeaderTraits (LeaderType, TraitType) VALUES
('LEADER_SALADIN_ALT', 'TRAIT_LEADER_AGGRESSIVE_MILITARY');

-- Add expansionist trait to leaders who should settle aggressively
-- Base game effect: lower settlement thresholds, faster decay, cheaper city values.
INSERT OR IGNORE INTO LeaderTraits (LeaderType, TraitType) VALUES
('LEADER_VICTORIA',  'TRAIT_LEADER_EXPANSIONIST'),
('LEADER_PHILIP_II', 'TRAIT_LEADER_EXPANSIONIST');

-- Remove NONRELIGIOUS trait from Roosevelt (only leader with it, unnecessary)
DELETE FROM LeaderTraits
WHERE TraitType = 'TRAIT_LEADER_NONRELIGIOUS_MAJOR_CIV'
  AND LeaderType = 'LEADER_T_ROOSEVELT';

-- Clear all leaders from LOW_RELIGIOUS_PREFERENCE and re-add curated list.
-- Base game effect: -75 Great Prophet pseudoyield, -50 Faith yield bias.
DELETE FROM LeaderTraits
WHERE TraitType = 'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE';

INSERT OR IGNORE INTO LeaderTraits (LeaderType, TraitType) VALUES
('LEADER_ABRAHAM_LINCOLN',       'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_ALEXANDER',             'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_CYRUS',                 'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_DIDO',                  'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_ELIZABETH',             'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_GENGHIS_KHAN',          'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_GILGAMESH',             'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_JOAO_III',              'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_JULIUS_CAESAR',         'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_ROBERT_THE_BRUCE',      'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_SEJONG',                'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_SEONDEOK',              'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_SHAKA',                 'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_SULEIMAN',              'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_SULEIMAN_ALT',          'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_TOKUGAWA',              'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_TRAJAN',                'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_VICTORIA',              'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_VICTORIA_ALT',          'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE'),
('LEADER_T_ROOSEVELT_ROUGHRIDER','TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE');

-- Create new trait: leaders who should avoid Holy Sites in early eras.
-- Many of these leaders may still want faith later (cultural victory, etc.)
-- but shouldn't waste an early district slot on a Holy Site.
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 'KIND_TRAIT');

INSERT OR IGNORE INTO Traits (TraitType, InternalOnly) VALUES
('TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 1);

INSERT OR IGNORE INTO LeaderTraits (LeaderType, TraitType) VALUES
('LEADER_ABRAHAM_LINCOLN',        'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_ALEXANDER',              'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_AMBIORIX',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_CATHERINE_DE_MEDICI',    'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_CATHERINE_DE_MEDICI_ALT','TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_CYRUS',                  'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_DIDO',                   'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_ELIZABETH',              'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_BARBAROSSA',             'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_GENGHIS_KHAN',           'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_GILGAMESH',              'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_GORGO',                  'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_HAMMURABI',              'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_JOAO_III',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_JOHN_CURTIN',            'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_JULIUS_CAESAR',          'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_LADY_SIX_SKY',           'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_MATTHIAS_CORVINUS',      'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_MONTEZUMA',              'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_NADER_SHAH',             'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_PERICLES',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_POUNDMAKER',             'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_QIN',                    'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_QIN_ALT',                'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_ROBERT_THE_BRUCE',       'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_SEJONG',                 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_SEONDEOK',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_SHAKA',                  'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_SULEIMAN',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_SULEIMAN_ALT',           'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_SIMON_BOLIVAR',          'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_TOKUGAWA',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_TRAJAN',                 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_VICTORIA',               'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_VICTORIA_ALT',           'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_LAURIER',                'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_WILHELMINA',             'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_WU_ZETIAN',              'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES'),
('LEADER_T_ROOSEVELT_ROUGHRIDER', 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES');

-- Create new trait: naval-biased leaders who should prioritize Harbors.
INSERT OR IGNORE INTO Types (Type, Kind) VALUES
('TRAIT_LEADER_ROSE_NAVAL_BIAS', 'KIND_TRAIT');

INSERT OR IGNORE INTO Traits (TraitType, InternalOnly) VALUES
('TRAIT_LEADER_ROSE_NAVAL_BIAS', 1);

INSERT OR IGNORE INTO LeaderTraits (LeaderType, TraitType) VALUES
('LEADER_WILHELMINA', 'TRAIT_LEADER_ROSE_NAVAL_BIAS'),
('LEADER_GITARJA',    'TRAIT_LEADER_ROSE_NAVAL_BIAS'),
('LEADER_KUPE',       'TRAIT_LEADER_ROSE_NAVAL_BIAS'),
('LEADER_HARDRADA',   'TRAIT_LEADER_ROSE_NAVAL_BIAS'),
('LEADER_HARALD_ALT', 'TRAIT_LEADER_ROSE_NAVAL_BIAS'),
('LEADER_JOAO_III',   'TRAIT_LEADER_ROSE_NAVAL_BIAS'),
('LEADER_PHILIP_II',  'TRAIT_LEADER_ROSE_NAVAL_BIAS');

-- ============================================================================
-- 2. RELIGIOUS LEADER DISTRICTS — Holy Site (Ancient/Classical)
-- Leaders with TRAIT_LEADER_RELIGIOUS_MAJOR_CIV get Holy Site +100.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousAncientDistricts'),
('RoseReligiousClassicalDistricts');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousAncientDistricts',   'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'Districts'),
('RoseReligiousClassicalDistricts', 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'Districts');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseReligiousAncientDistricts'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseReligiousClassicalDistricts');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousAncientDistricts',   'DISTRICT_HOLY_SITE', 1, 100),
('RoseReligiousClassicalDistricts', 'DISTRICT_HOLY_SITE', 1, 100);

-- ============================================================================
-- 3. RELIGIOUS LEADER PSEUDOYIELDS — Great Prophet (Ancient/Classical)
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousAncientPseudoYields'),
('RoseReligiousClassicalPseudoYields');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseReligiousAncientPseudoYields',   'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'PseudoYields'),
('RoseReligiousClassicalPseudoYields', 'TRAIT_LEADER_RELIGIOUS_MAJOR_CIV', 'PseudoYields');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseReligiousAncientPseudoYields'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseReligiousClassicalPseudoYields');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseReligiousAncientPseudoYields',   'PSEUDOYIELD_GPP_PROPHET', 1, 100),
('RoseReligiousClassicalPseudoYields', 'PSEUDOYIELD_GPP_PROPHET', 1, 100);

-- ============================================================================
-- 4. SALADIN — Holy Site (Classical/Medieval)
-- Saladin gets the last Great Prophet for free, so he doesn't need the full
-- religious-group boost — but he MUST build a Holy Site before the Prophet
-- arrives. Each Saladin version has a different unique trait.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseSaladinClassicalDistricts'),
('RoseSaladinMedievalDistricts'),
('RoseSaladinAltClassicalDistricts'),
('RoseSaladinAltMedievalDistricts');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseSaladinClassicalDistricts',    'TRAIT_LEADER_RIGHTEOUSNESS_OF_FAITH', 'Districts'),
('RoseSaladinMedievalDistricts',     'TRAIT_LEADER_RIGHTEOUSNESS_OF_FAITH', 'Districts'),
('RoseSaladinAltClassicalDistricts', 'TRAIT_LEADER_SALADIN_ALT',            'Districts'),
('RoseSaladinAltMedievalDistricts',  'TRAIT_LEADER_SALADIN_ALT',            'Districts');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseSaladinClassicalDistricts'),
('STRATEGY_MEDIEVAL_CHANGES',  'RoseSaladinMedievalDistricts'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseSaladinAltClassicalDistricts'),
('STRATEGY_MEDIEVAL_CHANGES',  'RoseSaladinAltMedievalDistricts');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseSaladinClassicalDistricts',    'DISTRICT_HOLY_SITE', 1, 50),
('RoseSaladinMedievalDistricts',     'DISTRICT_HOLY_SITE', 1, 50),
('RoseSaladinAltClassicalDistricts', 'DISTRICT_HOLY_SITE', 1, 50),
('RoseSaladinAltMedievalDistricts',  'DISTRICT_HOLY_SITE', 1, 50);

-- ============================================================================
-- 5. AVOID EARLY HOLY SITES — Disfavor Holy Sites (Ancient/Classical)
-- Leaders with TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES get Holy Site
-- unfavored with -100 value in Ancient and Classical eras.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAvoidHSAncientDistricts'),
('RoseAvoidHSClassicalDistricts');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAvoidHSAncientDistricts',   'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 'Districts'),
('RoseAvoidHSClassicalDistricts', 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES', 'Districts');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseAvoidHSAncientDistricts'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseAvoidHSClassicalDistricts');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAvoidHSAncientDistricts',   'DISTRICT_HOLY_SITE', 0, -100),
('RoseAvoidHSClassicalDistricts', 'DISTRICT_HOLY_SITE', 0, -100);

-- ============================================================================
-- 5b. STONEHENGE DISFAVORED — Low-religious + Avoid-early-HS leaders
-- Both LOW_RELIGIOUS_PREFERENCE and AVOID_EARLY_HOLY_SITES leaders should
-- not waste production on Stonehenge in Ancient/Classical eras.
-- Uses System='Buildings' since Stonehenge is a wonder (BUILDING_STONEHENGE).
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseLowRelAncientBuildings'),
('RoseLowRelClassicalBuildings'),
('RoseAvoidHSAncientBuildings'),
('RoseAvoidHSClassicalBuildings');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseLowRelAncientBuildings',    'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE',       'Buildings'),
('RoseLowRelClassicalBuildings',  'TRAIT_LEADER_LOW_RELIGIOUS_PREFERENCE',       'Buildings'),
('RoseAvoidHSAncientBuildings',   'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES',   'Buildings'),
('RoseAvoidHSClassicalBuildings', 'TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES',   'Buildings');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseLowRelAncientBuildings'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseLowRelClassicalBuildings'),
('STRATEGY_ANCIENT_CHANGES',   'RoseAvoidHSAncientBuildings'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseAvoidHSClassicalBuildings');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseLowRelAncientBuildings',    'BUILDING_STONEHENGE', 0, -100),
('RoseLowRelClassicalBuildings',  'BUILDING_STONEHENGE', 0, -100),
('RoseAvoidHSAncientBuildings',   'BUILDING_STONEHENGE', 0, -100),
('RoseAvoidHSClassicalBuildings', 'BUILDING_STONEHENGE', 0, -100);

-- ============================================================================
-- 6. NAVAL BIAS — Harbor always favored
-- Leaders with TRAIT_LEADER_ROSE_NAVAL_BIAS get Harbor favored at +50.
-- England (Royal Navy Dockyard) and Dido (Cothon) are already covered
-- by the unique district list in AI_Districts.sql at +100.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseNavalBiasDistricts');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseNavalBiasDistricts', 'TRAIT_LEADER_ROSE_NAVAL_BIAS', 'Districts');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseNavalBiasDistricts', 'DISTRICT_HARBOR', 1, 50);

-- ============================================================================
-- 6b. HARALD COASTAL RAID SUPPORT
-- Original Harald alone has TRAIT_LEADER_MELEE_COASTAL_RAIDS. The alternate
-- Harald is intentionally excluded because he does not receive the coastal
-- raid ability. Base, RH, Real Strategy, and AI+ all rely on the engine's
-- native Coastal Raid tactical move; no behavior-tree node can issue the
-- actual unit operation, so Rose reinforces that native path instead.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseHaraldRaidTactics'),
('RoseHaraldRaidUnitBuilds');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseHaraldRaidTactics',    'TRAIT_LEADER_MELEE_COASTAL_RAIDS', 'Tactics'),
('RoseHaraldRaidUnitBuilds', 'TRAIT_LEADER_MELEE_COASTAL_RAIDS', 'UnitPromotionClasses');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseHaraldRaidTactics',    'Coastal Raid',                  1, 2),
('RoseHaraldRaidUnitBuilds', 'PROMOTION_CLASS_NAVAL_MELEE',   1, 15);

-- ============================================================================
-- 6c. BASIL RELIGIOUS WAR SUPPORT
-- Keep the static Basil changes moderate. Conversion-target pseudoyields and
-- custom religious operations are intentionally not added.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseBasilWarUnitBuilds'),
('RoseBasilWarDiplomacy');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseBasilWarUnitBuilds', 'TRAIT_LEADER_BASIL', 'UnitPromotionClasses'),
('RoseBasilWarDiplomacy',  'TRAIT_LEADER_BASIL', 'DiplomaticActions');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseBasilWarUnitBuilds', 'PROMOTION_CLASS_HEAVY_CAVALRY', 1, 10),
('RoseBasilWarUnitBuilds', 'PROMOTION_CLASS_LIGHT_CAVALRY', 1, 8),
('RoseBasilWarDiplomacy',  'DIPLOACTION_DECLARE_HOLY_WAR',  1, 40);

-- ============================================================================
-- 6d. AGGRESSIVE MILITARY DIPLOMACY
-- The base trait already favors denouncements, military production, and
-- vulnerable enemy cities. The first long-run test at -8 produced no voluntary
-- major-vs-major wars and no formal wars, while military leaders accumulated
-- broad friendship networks. Raise the persistent penalty to -15 and favor
-- both formal and surprise war. This remains below RH's -23 and leaves
-- friendship, trade, peace, and city-state-war preferences untouched. It is an
-- AI preference, not a visible unconditional opinion modifier, and stacks with
-- the military-victory strategy's existing -50 only while that strategy runs.
--
-- Standing army in every era, at peace too, so a military leader has an army
-- before it declares war (formal war needs an assembled attack force). Base
-- Aggressive already adds UNIT_COMBAT +25, yet Montezuma ended the 2026-10-04
-- test with 1 land unit in 10 cities. Other leaders get army demand only from
-- At War and the later-era lists (AI_Strategies.sql, AI_Yields.sql).
--
-- Nuclear weapons: the base Nuke Happy agenda's preferences (device demand
-- PSEUDOYIELD_NUCLEAR_WEAPON +20 and DIPLOACTION_USE_NUCLEAR_WEAPON favored,
-- base NukeLoverNukePreference / NukeLoverUseNukePreference), plus the four
-- techs that lead to Uranium, devices, the Bomber and thermonuclear devices.
-- "Will use nukes" passes when the use action is favored, so these leaders
-- strike without first needing a negative war value against the target.
-- Techs are favored only once available, so the tech list does nothing
-- before the Atomic era.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAggressiveMilitaryPseudoYields'),
('RoseAggressiveMilitaryDiplomacy'),
('RoseAggressiveMilitaryBuildings'),
('RoseAggressiveMilitaryTechs');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseAggressiveMilitaryPseudoYields', 'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'PseudoYields'),
('RoseAggressiveMilitaryDiplomacy',    'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'DiplomaticActions'),
('RoseAggressiveMilitaryBuildings',    'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'Buildings'),
('RoseAggressiveMilitaryTechs',        'TRAIT_LEADER_AGGRESSIVE_MILITARY', 'Technologies');

DELETE FROM AiFavoredItems
WHERE ListType IN (
    'RoseAggressiveMilitaryPseudoYields',
    'RoseAggressiveMilitaryDiplomacy',
    'RoseAggressiveMilitaryBuildings',
    'RoseAggressiveMilitaryTechs'
);

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_DIPLOMATIC_BONUS',    1, -15),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_UNIT_COMBAT',         1,  30),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_NUMBER', 1, 20),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_STANDING_ARMY_VALUE',  1, 15),
('RoseAggressiveMilitaryPseudoYields', 'PSEUDOYIELD_NUCLEAR_WEAPON',      1,  20),
('RoseAggressiveMilitaryDiplomacy',    'DIPLOACTION_DECLARE_FORMAL_WAR',  1,   0),
('RoseAggressiveMilitaryDiplomacy',    'DIPLOACTION_DECLARE_SURPRISE_WAR', 1,  0),
('RoseAggressiveMilitaryDiplomacy',    'DIPLOACTION_USE_NUCLEAR_WEAPON',  1,   0),
-- Grand Master's Chapel lets Faith buy land units; only the two AIs that had
-- it bought armies with Faith in the 2026-10-04 test, while four others banked
-- 600-3,600 Faith. Tier-2 government buildings exclude each other, so this is
-- for military leaders only (and Military Recovery, AI_Strategies.sql). RH and
-- Real Strategy favor government buildings the same way, by victory type.
('RoseAggressiveMilitaryBuildings',    'BUILDING_GOV_FAITH',               1, 100),
-- Combined Arms reveals Uranium; Nuclear Fission unlocks the Manhattan Project
-- and the device; Advanced Flight the Bomber; Nuclear Fusion (Information) the
-- thermonuclear device. Steel, Combustion, Replaceable Parts and Advanced
-- Ballistics are the Modern/Atomic prerequisites of that chain (Steel ->
-- Combustion -> Combined Arms; Replaceable Parts -> Advanced Ballistics; both
-- -> Nuclear Fission): in .scratch/game-test-20261009c the favored leaders
-- took them at t130-161 or not at all by t162, and Gandhi's Combined Arms goal
-- at Value 50 was displaced by Flight and Computers. Value 100 for all eight
-- (2026-10-09); the Value 50 ceiling on Engineering (AI_Techs.sql) is
-- about early competitors, which these late techs do not have.
('RoseAggressiveMilitaryTechs',        'TECH_STEEL',                       1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_COMBUSTION',                  1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_REPLACEABLE_PARTS',           1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_ADVANCED_BALLISTICS',         1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_COMBINED_ARMS',               1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_NUCLEAR_FISSION',             1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_ADVANCED_FLIGHT',             1, 100),
('RoseAggressiveMilitaryTechs',        'TECH_NUCLEAR_FUSION',              1, 100);

-- ============================================================================
-- 6e. GANDHI: ALWAYS NUCLEAR-WILLING
-- Base gives Gandhi Nuke Happy (AGENDA_NUKE_LOVER) as a hidden agenda 70% of
-- the time (AgendaPreferredLeaders). Rose makes the nuclear part permanent on
-- his leader trait and removes Nuke Happy from his hidden-agenda pool, so it
-- cannot roll on top (which would double the opinion modifiers below).
--  - Lists: the Nuke Happy preferences (device demand +20, use action
--    favored) and the same four nuclear techs as the aggressive-military
--    leaders. Base GandhiTechs already exists; these use new list names.
--  - Opinion: Nuke Happy's two opinion modifiers (likes civs that build and use
--    nukes, dislikes those that do not; both need Nuclear Fission for the owner).
--    The modifier type is the same one TRAIT_LEADER_MAJOR_CIV, a leader trait,
--    uses for its standard opinion modifiers. Both carry the HiddenAgenda
--    argument, as every random-agenda modifier does.
--  - ExclusiveAgendas: stored one way, historical agenda first, as base stores
--    Peacekeeper/Darwinist; the schema exposes both directions.
-- Only Gandhi has TRAIT_LEADER_SATYAGRAHA.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGandhiPseudoYields'),
('RoseGandhiDiplomacy'),
('RoseGandhiTechs');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseGandhiPseudoYields', 'TRAIT_LEADER_SATYAGRAHA', 'PseudoYields'),
('RoseGandhiDiplomacy',    'TRAIT_LEADER_SATYAGRAHA', 'DiplomaticActions'),
('RoseGandhiTechs',        'TRAIT_LEADER_SATYAGRAHA', 'Technologies');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseGandhiPseudoYields', 'PSEUDOYIELD_NUCLEAR_WEAPON',     1, 20),
('RoseGandhiDiplomacy',    'DIPLOACTION_USE_NUCLEAR_WEAPON', 1,  0),
-- The same eight techs at Value 100 as RoseAggressiveMilitaryTechs (see the
-- note there).
('RoseGandhiTechs',        'TECH_STEEL',                     1, 100),
('RoseGandhiTechs',        'TECH_COMBUSTION',                1, 100),
('RoseGandhiTechs',        'TECH_REPLACEABLE_PARTS',         1, 100),
('RoseGandhiTechs',        'TECH_ADVANCED_BALLISTICS',       1, 100),
('RoseGandhiTechs',        'TECH_COMBINED_ARMS',             1, 100),
('RoseGandhiTechs',        'TECH_NUCLEAR_FISSION',           1, 100),
('RoseGandhiTechs',        'TECH_ADVANCED_FLIGHT',           1, 100),
('RoseGandhiTechs',        'TECH_NUCLEAR_FUSION',            1, 100);

INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId) VALUES
('TRAIT_LEADER_SATYAGRAHA', 'AGENDA_HIGH_NUKE_LOVE'),
('TRAIT_LEADER_SATYAGRAHA', 'AGENDA_LOW_NUKE_LOVE');

DELETE FROM AgendaPreferredLeaders
WHERE LeaderType = 'LEADER_GANDHI'
  AND AgendaType = 'AGENDA_NUKE_LOVER';

INSERT OR IGNORE INTO ExclusiveAgendas (AgendaOne, AgendaTwo) VALUES
('AGENDA_PEACEKEEPER', 'AGENDA_NUKE_LOVER');

-- ============================================================================
-- 7. OTHER LEADER-SPECIFIC DISTRICTS
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRooseveltDistricts'),
('RoseCurtinDistricts'),
('RoseHammurabiDistricts');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseRooseveltDistricts', 'TRAIT_LEADER_ANTIQUES_AND_PARKS',    'Districts'),
('RoseCurtinDistricts',    'TRAIT_LEADER_CITADEL_CIVILIZATION',  'Districts'),
('RoseHammurabiDistricts', 'TRAIT_LEADER_HAMMURABI',             'Districts');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRooseveltDistricts', 'DISTRICT_PRESERVE', 1, 100),
('RoseCurtinDistricts',    'DISTRICT_PRESERVE', 1, 100),
('RoseHammurabiDistricts', 'DISTRICT_THEATER',  1, 100);

-- ============================================================================
-- 8. MYSTICISM CIVIC PRIORITY — Roosevelt (Bull Moose) + John Curtin
-- Both leaders want Preserves, which require the Mysticism civic.
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRooseveltAncientCivics'),
('RoseRooseveltClassicalCivics'),
('RoseCurtinAncientCivics'),
('RoseCurtinClassicalCivics');

INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseRooseveltAncientCivics',   'TRAIT_LEADER_ANTIQUES_AND_PARKS',    'Civics'),
('RoseRooseveltClassicalCivics', 'TRAIT_LEADER_ANTIQUES_AND_PARKS',    'Civics'),
('RoseCurtinAncientCivics',      'TRAIT_LEADER_CITADEL_CIVILIZATION',  'Civics'),
('RoseCurtinClassicalCivics',    'TRAIT_LEADER_CITADEL_CIVILIZATION',  'Civics');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseRooseveltAncientCivics'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseRooseveltClassicalCivics'),
('STRATEGY_ANCIENT_CHANGES',   'RoseCurtinAncientCivics'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseCurtinClassicalCivics');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRooseveltAncientCivics',   'CIVIC_MYSTICISM', 1, 100),
('RoseRooseveltClassicalCivics', 'CIVIC_MYSTICISM', 1, 100),
('RoseCurtinAncientCivics',      'CIVIC_MYSTICISM', 1, 100),
('RoseCurtinClassicalCivics',    'CIVIC_MYSTICISM', 1, 100);
