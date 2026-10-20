-- ============================================================================
-- Rose AI: tech and civic priorities on the base era strategies
-- (and STRATEGY_INFORMATION_CHANGES, Rose_Strategies.sql).
-- AGENTS.md "## Current Features", "### economy/Rose_Techs_Civics.sql".
-- ============================================================================

-- Ancient techs: Currency (earlier Commercial Hubs) and Engineering (the first
-- trainable wall-breaker for walled assaults); AGENTS.md "Currency tech prioritized", "Engineering prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientTechs');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientTechs',   'Technologies');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',   'RoseAncientTechs');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientTechs',   'TECH_CURRENCY', 1, 100),
('RoseAncientTechs',   'TECH_ENGINEERING', 1, 50);

-- Classical techs: Currency and Engineering; AGENTS.md "Currency tech prioritized", "Engineering prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalTechs');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalTechs',  'Technologies');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES', 'RoseClassicalTechs');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseClassicalTechs', 'TECH_CURRENCY', 1, 100),
('RoseClassicalTechs', 'TECH_ENGINEERING', 1, 50);

-- Medieval techs: Currency; AGENTS.md "Currency tech prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalTechs');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalTechs',   'Technologies');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',  'RoseMedievalTechs');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalTechs',  'TECH_CURRENCY', 1, 100);

-- Ancient civics: Political Philosophy (tier 1 governments); AGENTS.md "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseAncientCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseAncientCivics',      'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ANCIENT_CHANGES',      'RoseAncientCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseAncientCivics',   'CIVIC_POLITICAL_PHILOSOPHY', 1, 100);

-- Classical civics: Feudalism (Serfdom, +2 Builder charges) and Political
-- Philosophy; AGENTS.md "Feudalism civic prioritized", "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseClassicalCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseClassicalCivics',    'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_CLASSICAL_CHANGES',    'RoseClassicalCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseClassicalCivics', 'CIVIC_FEUDALISM', 1, 100),
('RoseClassicalCivics', 'CIVIC_POLITICAL_PHILOSOPHY', 1, 100);

-- Medieval civics: Feudalism and the tier 2 government civics (Monarchy,
-- Theocracy, Merchant Republic); AGENTS.md "Feudalism civic prioritized", "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMedievalCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseMedievalCivics',     'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MEDIEVAL_CHANGES',     'RoseMedievalCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMedievalCivics',  'CIVIC_FEUDALISM', 1, 100),
('RoseMedievalCivics',     'CIVIC_DIVINE_RIGHT',     1, 100),
('RoseMedievalCivics',     'CIVIC_REFORMED_CHURCH',  1, 100),
('RoseMedievalCivics',     'CIVIC_EXPLORATION',      1, 100);

-- Renaissance civics: the tier 2 government civics; AGENTS.md "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseRenaissanceCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseRenaissanceCivics',  'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_RENAISSANCE_CHANGES',  'RoseRenaissanceCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseRenaissanceCivics',  'CIVIC_DIVINE_RIGHT',     1, 100),
('RoseRenaissanceCivics',  'CIVIC_REFORMED_CHURCH',  1, 100),
('RoseRenaissanceCivics',  'CIVIC_EXPLORATION',      1, 100);

-- Industrial civics: the tier 3 government civics (Fascism, Communism,
-- Democracy); AGENTS.md "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseIndustrialCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseIndustrialCivics',   'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_INDUSTRIAL_CHANGES',   'RoseIndustrialCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseIndustrialCivics', 'CIVIC_TOTALITARIANISM', 1, 100),
('RoseIndustrialCivics', 'CIVIC_CLASS_STRUGGLE',  1, 100),
('RoseIndustrialCivics', 'CIVIC_SUFFRAGE',        1, 100);

-- Modern civics: the tier 3 government civics; AGENTS.md "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseModernCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseModernCivics',       'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_MODERN_CHANGES',       'RoseModernCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseModernCivics',     'CIVIC_TOTALITARIANISM', 1, 100),
('RoseModernCivics',     'CIVIC_CLASS_STRUGGLE',  1, 100),
('RoseModernCivics',     'CIVIC_SUFFRAGE',        1, 100);

-- Information civics: the tier 4 government civics (Gathering Storm);
-- AGENTS.md "Government-unlocking civics prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseInformationCivics');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseInformationCivics',  'Civics');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_INFORMATION_CHANGES',  'RoseInformationCivics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseInformationCivics', 'CIVIC_CORPORATE_LIBERTARIANISM', 1, 100),
('RoseInformationCivics', 'CIVIC_DIGITAL_DEMOCRACY',        1, 100),
('RoseInformationCivics', 'CIVIC_SYNTHETIC_TECHNOCRACY',    1, 100);
