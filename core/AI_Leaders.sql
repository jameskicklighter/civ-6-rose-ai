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
