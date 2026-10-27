-- ============================================================================
-- Rose AI: the tech and civic priorities of every major (a Civics list has no
-- effect on a strategy, and a tech favor outlives its strategy until a reload),
-- and the dedication disfavor.
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
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivTechs', 'TECH_CURRENCY',    1, 100),
('RoseMajorCivTechs', 'TECH_ENGINEERING', 1, 50);

-- All majors, all eras: Political Philosophy (tier 1 governments) and Feudalism
-- (Serfdom, +2 Builder charges); the Lua grant gives the later government civics;
-- AGENTS.md "Government-unlocking civics prioritized", "Feudalism civic prioritized"
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivCivics');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivCivics', 'TRAIT_LEADER_MAJOR_CIV', 'Civics');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivCivics', 'CIVIC_POLITICAL_PHILOSOPHY', 1, 100),
('RoseMajorCivCivics', 'CIVIC_FEUDALISM',            1, 100);

-- All majors: the religious dedication (Golden Age Great Prophet points)
-- disfavored, and the religious victory strategy's favor of it removed so the
-- two cannot cancel; AGENTS.md "Religious dedication disfavored"
DELETE FROM AiFavoredItems
WHERE ListType = 'ReligiousVictoryFavoredCommemorations'
  AND Item = 'COMMEMORATION_RELIGIOUS';
INSERT OR IGNORE INTO AiListTypes (ListType) VALUES
('RoseMajorCivCommemorations');
INSERT OR IGNORE INTO AiLists (ListType, LeaderType, System) VALUES
('RoseMajorCivCommemorations', 'TRAIT_LEADER_MAJOR_CIV', 'Commemorations');
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Favored, Value) VALUES
('RoseMajorCivCommemorations', 'COMMEMORATION_RELIGIOUS', 0, -100);
