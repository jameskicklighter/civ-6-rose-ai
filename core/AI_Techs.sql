-- ============================================================================
-- Rose AI: Tech + Civic Priorities
-- Favors Currency tech in Ancient/Classical/Medieval eras so the AI unlocks
-- Commercial Hub districts earlier. Favors Feudalism civic and all
-- government-unlocking civics across every era.
-- ============================================================================

-- ============================================================================
-- 1. TECH PRIORITIES — Currency
-- ============================================================================

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientTechs'),
('RoseClassicalTechs'),
('RoseMedievalTechs');

INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientTechs',   'Technologies'),
('RoseClassicalTechs',  'Technologies'),
('RoseMedievalTechs',   'Technologies');

INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseAncientTechs'),
('STRATEGY_CLASSICAL_CHANGES', 'RoseClassicalTechs'),
('STRATEGY_MEDIEVAL_CHANGES',  'RoseMedievalTechs');

INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientTechs',   'TECH_CURRENCY', 1, 100),
('RoseClassicalTechs', 'TECH_CURRENCY', 1, 100),
('RoseMedievalTechs',  'TECH_CURRENCY', 1, 100);

-- ============================================================================
-- 2. CIVIC PRIORITIES — Feudalism + Government-unlocking civics
-- ============================================================================

-- Declare all civic list types
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientCivics'),
('RoseClassicalCivics'),
('RoseMedievalCivics'),
('RoseRenaissanceCivics'),
('RoseIndustrialCivics'),
('RoseModernCivics'),
('RoseInformationCivics');

-- Map all to Civics system
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientCivics',      'Civics'),
('RoseClassicalCivics',    'Civics'),
('RoseMedievalCivics',     'Civics'),
('RoseRenaissanceCivics',  'Civics'),
('RoseIndustrialCivics',   'Civics'),
('RoseModernCivics',       'Civics'),
('RoseInformationCivics',  'Civics');

-- Link all to era strategies
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientCivics'),
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalCivics'),
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalCivics'),
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceCivics'),
('STRATEGY_INDUSTRIAL_CHANGES',   'RoseIndustrialCivics'),
('STRATEGY_MODERN_CHANGES',       'RoseModernCivics'),
('STRATEGY_INFORMATION_CHANGES',  'RoseInformationCivics');

-- Populate all civic favorites
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
-- Feudalism (unlocks Serfdom — +2 Builder charges)
('RoseClassicalCivics', 'CIVIC_FEUDALISM', 1, 100),
('RoseMedievalCivics',  'CIVIC_FEUDALISM', 1, 100),
-- Political Philosophy → Tier 1 governments (Autocracy, Oligarchy, Classical Republic)
('RoseAncientCivics',   'CIVIC_POLITICAL_PHILOSOPHY', 1, 100),
('RoseClassicalCivics', 'CIVIC_POLITICAL_PHILOSOPHY', 1, 100),
-- Divine Right → Monarchy
('RoseMedievalCivics',     'CIVIC_DIVINE_RIGHT',     1, 100),
('RoseRenaissanceCivics',  'CIVIC_DIVINE_RIGHT',     1, 100),
-- Reformed Church → Theocracy
('RoseMedievalCivics',     'CIVIC_REFORMED_CHURCH',  1, 100),
('RoseRenaissanceCivics',  'CIVIC_REFORMED_CHURCH',  1, 100),
-- Exploration → Merchant Republic
('RoseMedievalCivics',     'CIVIC_EXPLORATION',      1, 100),
('RoseRenaissanceCivics',  'CIVIC_EXPLORATION',      1, 100),
-- Totalitarianism → Fascism
('RoseIndustrialCivics', 'CIVIC_TOTALITARIANISM', 1, 100),
('RoseModernCivics',     'CIVIC_TOTALITARIANISM', 1, 100),
-- Class Struggle → Communism
('RoseIndustrialCivics', 'CIVIC_CLASS_STRUGGLE',  1, 100),
('RoseModernCivics',     'CIVIC_CLASS_STRUGGLE',  1, 100),
-- Suffrage → Democracy
('RoseIndustrialCivics', 'CIVIC_SUFFRAGE',        1, 100),
('RoseModernCivics',     'CIVIC_SUFFRAGE',        1, 100),
-- Tier 4 governments (Gathering Storm)
('RoseInformationCivics', 'CIVIC_CORPORATE_LIBERTARIANISM', 1, 100),
('RoseInformationCivics', 'CIVIC_DIGITAL_DEMOCRACY',        1, 100),
('RoseInformationCivics', 'CIVIC_SYNTHETIC_TECHNOCRACY',    1, 100);

-- ============================================================================
-- 3. CIVIC PREREQUISITE ADDITIONS
-- ============================================================================
-- Removed: Previously forced AI down side branches by adding prereqs to
-- Mercantilism, The Enlightenment, and Cold War. Now handled by the Lua
-- gameplay script (Rose_AI_Gameplay.lua) which grants government civics
-- directly when their base-game prereqs are met.
-- ============================================================================
