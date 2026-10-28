-- ============================================================================
-- Rose AI: the tech and civic priorities of every major (a Civics list has no
-- effect on a strategy, and a tech favor outlives its strategy until a reload),
-- and the dedication preferences.
-- AGENTS.md "## Current Features", "### economy/Rose_Techs_Civics.sql".
-- ============================================================================

-- All majors, all eras: Currency (earlier Commercial Hubs) and Engineering (the
-- first trainable wall-breaker for walled assaults); a tech favor is not cleared
-- when a strategy ends but is on reload, so it stays off strategies;
-- AGENTS.md "Currency tech prioritized", "Engineering prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivTechs');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivTechs', 'TRAIT_LEADER_MAJOR_CIV', 'Technologies');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMajorCivTechs', 'TECH_CURRENCY',    1),
('RoseMajorCivTechs', 'TECH_ENGINEERING', 1);

-- All majors, all eras: Political Philosophy (tier 1 governments) and Feudalism
-- (Serfdom, +2 Builder charges); the Lua grant gives the later government civics;
-- AGENTS.md "Government-unlocking civics prioritized", "Feudalism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivCivics', 'TRAIT_LEADER_MAJOR_CIV', 'Civics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMajorCivCivics', 'CIVIC_POLITICAL_PHILOSOPHY', 1),
('RoseMajorCivCivics', 'CIVIC_FEUDALISM',            1);

-- The victory strategies' favors of the four Classical-Medieval dedications are
-- removed, so only the lists below decide among them (the AI takes a favored
-- dedication first, then the best-scored); AGENTS.md "Religious dedication disfavored",
-- "Dedication preferences"
DELETE FROM AiFavoredItems
WHERE (ListType = 'ReligiousVictoryFavoredCommemorations'
       AND Item IN ('COMMEMORATION_RELIGIOUS', 'COMMEMORATION_INFRASTRUCTURE'))
   OR (ListType = 'MilitaryVictoryFavoredCommemorations' AND Item = 'COMMEMORATION_INFRASTRUCTURE')
   OR (ListType = 'ScienceVictoryFavoredCommemorations'  AND Item = 'COMMEMORATION_SCIENTIFIC')
   OR (ListType = 'CultureVictoryFavoredCommemorations'  AND Item = 'COMMEMORATION_CULTURAL');

-- All majors: Monumentality favored; the Pen, Brush and Voice disfavor row is
-- kept; inert while no other list favors it (a dedication disfavor only cancels
-- a favor); AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivCommemorations', 'TRAIT_LEADER_MAJOR_CIV', 'Commemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseMajorCivCommemorations', 'COMMEMORATION_CULTURAL',       0),
('RoseMajorCivCommemorations', 'COMMEMORATION_INFRASTRUCTURE', 1);

-- Religious leaders who founded a religion: Exodus of the Evangelists favored
-- beside Monumentality (the engine's score picks between them); AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseReligiousFoundedCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseReligiousFoundedCommemorations', 'Commemorations');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_RELIGIOUS_FOUNDED', 'RoseReligiousFoundedCommemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseReligiousFoundedCommemorations', 'COMMEMORATION_RELIGIOUS', 1);

-- Science leaders: Free Inquiry instead of Monumentality; AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseScienceLeaderCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseScienceLeaderCommemorations', 'TRAIT_LEADER_SCIENCE_MAJOR_CIV', 'Commemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseScienceLeaderCommemorations', 'COMMEMORATION_SCIENTIFIC',     1),
('RoseScienceLeaderCommemorations', 'COMMEMORATION_INFRASTRUCTURE', 0);

-- Science leaders from the Renaissance era, when Free Inquiry is no longer
-- offered: Monumentality favored again; AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseScienceLeaderLateCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseScienceLeaderLateCommemorations', 'Commemorations');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_SCIENCE_LEADER_LATE', 'RoseScienceLeaderLateCommemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseScienceLeaderLateCommemorations', 'COMMEMORATION_INFRASTRUCTURE', 1);

-- Golden Age in the Classical and Medieval eras, every major: Monumentality only
-- (Free Inquiry and Exodus cancelled to neutral, Monumentality favored for
-- science leaders too); AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGoldenClassicalCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseGoldenClassicalCommemorations', 'Commemorations');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_GOLDEN_CLASSICAL', 'RoseGoldenClassicalCommemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseGoldenClassicalCommemorations', 'COMMEMORATION_INFRASTRUCTURE', 1),
('RoseGoldenClassicalCommemorations', 'COMMEMORATION_SCIENTIFIC',     0),
('RoseGoldenClassicalCommemorations', 'COMMEMORATION_RELIGIOUS',      0);

INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGoldenMedievalCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseGoldenMedievalCommemorations', 'Commemorations');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_GOLDEN_MEDIEVAL', 'RoseGoldenMedievalCommemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseGoldenMedievalCommemorations', 'COMMEMORATION_INFRASTRUCTURE', 1),
('RoseGoldenMedievalCommemorations', 'COMMEMORATION_SCIENTIFIC',     0),
('RoseGoldenMedievalCommemorations', 'COMMEMORATION_RELIGIOUS',      0);

-- Golden Age in the Renaissance era, every major: Monumentality only (Exodus
-- cancelled, and Reform the Coinage cancelled once here and once in the next
-- list, since Science and Culture Victory each favor it); AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGoldenRenaissanceCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseGoldenRenaissanceCommemorations', 'Commemorations');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_GOLDEN_RENAISSANCE', 'RoseGoldenRenaissanceCommemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseGoldenRenaissanceCommemorations', 'COMMEMORATION_INFRASTRUCTURE', 1),
('RoseGoldenRenaissanceCommemorations', 'COMMEMORATION_RELIGIOUS',      0),
('RoseGoldenRenaissanceCommemorations', 'COMMEMORATION_ECONOMIC',       0);

-- The second Reform the Coinage cancel of a Renaissance Golden Age; AGENTS.md "Dedication preferences"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseGoldenRenaissanceEconomicCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, System) VALUES
('RoseGoldenRenaissanceEconomicCommemorations', 'Commemorations');
INSERT OR IGNORE INTO Strategy_Priorities (StrategyType, ListType) VALUES
('STRATEGY_ROSE_GOLDEN_RENAISSANCE', 'RoseGoldenRenaissanceEconomicCommemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored) VALUES
('RoseGoldenRenaissanceEconomicCommemorations', 'COMMEMORATION_ECONOMIC', 0);
