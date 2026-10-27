-- ============================================================================
-- Rose AI: repairs to base-game AI list data (misspelled items, lists on the
-- wrong leader or agenda, items in the wrong list, a missing attachment), so
-- the lists the base game wrote actually reach their leaders. Overlaps
-- the Real Fixes mod; safe to run alongside it (every statement matches the
-- old value or checks that its target is missing, so it is a no-op when Real
-- Fixes already ran). Inserts check that their targets exist, so a ruleset
-- without a DLC loads cleanly.
-- AGENTS.md "## Current Features", "Base-game AI list fixes".
-- ============================================================================

-- Misspelled civic, tech and building items in the AI lists are corrected; a
-- row whose correct item is already in the same list is dropped instead;
-- AGENTS.md "Base-game AI list fixes"
UPDATE AiFavoredItems SET Item = 'CIVIC_NAVAL_TRADITION'
WHERE Item = 'CIVIC_NAVAL_TRADITIION'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'CIVIC_NAVAL_TRADITION');
DELETE FROM AiFavoredItems WHERE Item = 'CIVIC_NAVAL_TRADITIION'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'CIVIC_NAVAL_TRADITION');

UPDATE AiFavoredItems SET Item = 'TECH_SAILING'
WHERE Item = 'TECH_SALING'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'TECH_SAILING');
DELETE FROM AiFavoredItems WHERE Item = 'TECH_SALING'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'TECH_SAILING');

UPDATE AiFavoredItems SET Item = 'TECH_REPLACEABLE_PARTS'
WHERE Item = 'TECH_REPLACABLE_PARTS'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'TECH_REPLACEABLE_PARTS');
DELETE FROM AiFavoredItems WHERE Item = 'TECH_REPLACABLE_PARTS'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'TECH_REPLACEABLE_PARTS');

UPDATE AiFavoredItems SET Item = 'TECH_GUNPOWDER'
WHERE Item = 'TECH_GUNPOWER'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'TECH_GUNPOWDER');
DELETE FROM AiFavoredItems WHERE Item = 'TECH_GUNPOWER'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'TECH_GUNPOWDER');

UPDATE AiFavoredItems SET Item = 'BUILDING_VENETIAN_ARSENAL'
WHERE Item = 'BUILDING_VENTIAN_ARSENAL'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'BUILDING_VENETIAN_ARSENAL');
DELETE FROM AiFavoredItems WHERE Item = 'BUILDING_VENTIAN_ARSENAL'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'BUILDING_VENETIAN_ARSENAL');

UPDATE AiFavoredItems SET Item = 'CIVIC_DRAMA_POETRY'
WHERE Item = 'CIVIC_DRAMA_AND_POETRY'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'CIVIC_DRAMA_POETRY');
DELETE FROM AiFavoredItems WHERE Item = 'CIVIC_DRAMA_AND_POETRY'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'CIVIC_DRAMA_POETRY');

UPDATE AiFavoredItems SET Item = 'CIVIC_CLASS_STRUGGLE'
WHERE Item = 'CIVIC_CLASS_STRUGLE'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'CIVIC_CLASS_STRUGGLE');
DELETE FROM AiFavoredItems WHERE Item = 'CIVIC_CLASS_STRUGLE'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = AiFavoredItems.ListType AND b.Item = 'CIVIC_CLASS_STRUGGLE');

-- Lists written on the wrong leader trait are moved to the leader they name;
-- AGENTS.md "Base-game AI list fixes"
UPDATE AiLists SET LeaderType = 'TRAIT_LEADER_SUNDIATA_KEITA'
WHERE ListType IN ('KeitaCivics', 'KeitaTechs', 'KeitaWonders')
  AND LeaderType = 'TRAIT_LEADER_SAHEL_MERCHANTS';
UPDATE AiLists SET LeaderType = 'TRAIT_LEADER_SUNDIATA_KEITA'
WHERE ListType = 'KeitaGreatWorks'
  AND LeaderType = 'TRAIT_LEADER_ELEANOR_LOYALTY';
UPDATE AiLists SET LeaderType = 'TRAIT_LEADER_RAMSES'
WHERE ListType = 'RamsesTechs'
  AND LeaderType = 'TRAIT_LEADER_MEDITERRANEAN';
UPDATE AiLists SET LeaderType = 'TRAIT_LEADER_CLEOPATRA_ALT'
WHERE ListType = 'CleopatraAltTechs'
  AND LeaderType = 'TRAIT_LEADER_MEDITERRANEAN';
UPDATE AiLists SET LeaderType = 'CULTURE_KILLS_TRAIT'
WHERE ListType IN ('GorgoWonders', 'GorgoCivics', 'GorgoTechs')
  AND LeaderType = 'TRAIT_AGENDA_WITH_SHIELD';

-- Theodora's civic, tech and wonder lists have items but no attachment, so
-- they never applied; AGENTS.md "Base-game AI list fixes"
INSERT INTO AiLists (ListType, LeaderType, System)
SELECT 'TheodoraCivics', 'TRAIT_LEADER_THEODORA', 'Civics'
WHERE EXISTS (SELECT 1 FROM Types WHERE Type = 'TRAIT_LEADER_THEODORA')
  AND EXISTS (SELECT 1 FROM AiListTypes WHERE ListType = 'TheodoraCivics')
  AND NOT EXISTS (SELECT 1 FROM AiLists WHERE ListType = 'TheodoraCivics');
INSERT INTO AiLists (ListType, LeaderType, System)
SELECT 'TheodoraTechs', 'TRAIT_LEADER_THEODORA', 'Technologies'
WHERE EXISTS (SELECT 1 FROM Types WHERE Type = 'TRAIT_LEADER_THEODORA')
  AND EXISTS (SELECT 1 FROM AiListTypes WHERE ListType = 'TheodoraTechs')
  AND NOT EXISTS (SELECT 1 FROM AiLists WHERE ListType = 'TheodoraTechs');
INSERT INTO AiLists (ListType, LeaderType, System)
SELECT 'TheodoraWonders', 'TRAIT_LEADER_THEODORA', 'Buildings'
WHERE EXISTS (SELECT 1 FROM Types WHERE Type = 'TRAIT_LEADER_THEODORA')
  AND EXISTS (SELECT 1 FROM AiListTypes WHERE ListType = 'TheodoraWonders')
  AND NOT EXISTS (SELECT 1 FROM AiLists WHERE ListType = 'TheodoraWonders');

-- Agenda lists written in the leader column, or naming a misspelled agenda
-- trait, are put on the agenda that exists; AGENTS.md "Base-game AI list fixes"
UPDATE AiLists SET LeaderType = NULL, AgendaType = 'TRAIT_AGENDA_BACKSTABBER'
WHERE ListType = 'CyrusPreferBackstabbing'
  AND LeaderType = 'TRAIT_AGENDA_BACKSTABBER';
UPDATE AiLists SET LeaderType = NULL, AgendaType = 'TRAIT_AGENDA_LION_OF_MALI'
WHERE ListType = 'LionOfMaliPseudoYields'
  AND LeaderType = 'TRAIT_AGENDA_LION_OF_MALI';
UPDATE AiLists SET LeaderType = NULL, AgendaType = 'TRAIT_AGENDA_ETHIOPIAN_HIGHLANDS'
WHERE ListType = 'PreferHills'
  AND LeaderType = 'AGENDA_ETHIOPIAN_HIGHLANDS';
UPDATE AiLists SET AgendaType = 'TRAIT_AGENDA_DELIAN_LEAGUE'
WHERE ListType IN ('DelianLeagueDiscussions', 'DelianLeagueResolutions')
  AND AgendaType = 'TRAIT_AGENDA_DELAIN_LEAGUE';
UPDATE AiLists SET AgendaType = 'TRAIT_AGENDA_INDUSTRIAL_REVOLUTION'
WHERE ListType = 'IndustrialRevolutionPreference'
  AND AgendaType = 'TRAIT_AGENDA_PREFER_INDUSTRIAL_REVOLUTION';
UPDATE AiLists SET AgendaType = 'TRAIT_AGENDA_WITH_SHIELD'
WHERE ListType = 'WithYourShieldOrOnItDiscussions'
  AND AgendaType = 'TRAIT_AGENDA_WITH_YOUR_SHIELD_OR_ON_IT';

-- Items in the wrong list for their kind (a pseudoyield in a Buildings list,
-- civics in Technologies or Buildings lists) are moved to the matching list;
-- AGENTS.md "Base-game AI list fixes"
UPDATE AiLists SET System = 'PseudoYields'
WHERE ListType = 'SuliemanGovernor'
  AND System = 'Buildings';
UPDATE AiFavoredItems SET ListType = 'SuliemanCivics'
WHERE ListType = 'SuliemanTechs' AND Item = 'CIVIC_GAMES_RECREATION'
  AND EXISTS (SELECT 1 FROM AiListTypes WHERE ListType = 'SuliemanCivics')
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'SuliemanCivics' AND b.Item = 'CIVIC_GAMES_RECREATION');
DELETE FROM AiFavoredItems
WHERE ListType = 'SuliemanTechs' AND Item = 'CIVIC_GAMES_RECREATION'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'SuliemanCivics' AND b.Item = 'CIVIC_GAMES_RECREATION');
UPDATE AiFavoredItems SET ListType = 'NzingaCivics'
WHERE ListType = 'NzingaWonders' AND Item = 'CIVIC_DRAMA_POETRY'
  AND EXISTS (SELECT 1 FROM AiListTypes WHERE ListType = 'NzingaCivics')
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'NzingaCivics' AND b.Item = 'CIVIC_DRAMA_POETRY');
DELETE FROM AiFavoredItems
WHERE ListType = 'NzingaWonders' AND Item = 'CIVIC_DRAMA_POETRY'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'NzingaCivics' AND b.Item = 'CIVIC_DRAMA_POETRY');
UPDATE AiFavoredItems SET ListType = 'NzingaCivics'
WHERE ListType = 'NzingaWonders' AND Item = 'CIVIC_GUILDS'
  AND EXISTS (SELECT 1 FROM AiListTypes WHERE ListType = 'NzingaCivics')
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'NzingaCivics' AND b.Item = 'CIVIC_GUILDS');
DELETE FROM AiFavoredItems
WHERE ListType = 'NzingaWonders' AND Item = 'CIVIC_GUILDS'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'NzingaCivics' AND b.Item = 'CIVIC_GUILDS');

-- Matthias favors the Research Alliance under its real ID;
-- AGENTS.md "Base-game AI list fixes"
UPDATE AiFavoredItems SET Item = 'ALLIANCE_RESEARCH'
WHERE ListType = 'MatthiasAlliances' AND Item = 'ALLIANCE_SCIENTIFIC'
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'MatthiasAlliances' AND b.Item = 'ALLIANCE_RESEARCH');
DELETE FROM AiFavoredItems
WHERE ListType = 'MatthiasAlliances' AND Item = 'ALLIANCE_SCIENTIFIC'
  AND EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = 'MatthiasAlliances' AND b.Item = 'ALLIANCE_RESEARCH');

-- The Science victory lists drop the two techs that no longer lead to the Mars
-- projects and favor the current late techs and the two laser projects;
-- AGENTS.md "Base-game AI list fixes"
DELETE FROM AiFavoredItems
WHERE ListType = 'ScienceVictoryTechs'
  AND Item IN ('TECH_NUCLEAR_FUSION', 'TECH_ROBOTICS');
INSERT INTO AiFavoredItems (ListType, Item)
SELECT v.ListType, v.Item
FROM (SELECT 'ScienceVictoryTechs' AS ListType, 'TECH_SMART_MATERIALS' AS Item
      UNION ALL SELECT 'ScienceVictoryTechs', 'TECH_OFFWORLD_MISSION'
      UNION ALL SELECT 'ScienceVictoryProjects', 'PROJECT_ORBITAL_LASER'
      UNION ALL SELECT 'ScienceVictoryProjects', 'PROJECT_TERRESTRIAL_LASER') v
WHERE EXISTS (SELECT 1 FROM AiListTypes t WHERE t.ListType = v.ListType)
  AND EXISTS (SELECT 1 FROM Types t WHERE t.Type = v.Item)
  AND NOT EXISTS (SELECT 1 FROM AiFavoredItems b WHERE b.ListType = v.ListType AND b.Item = v.Item);
