-- ============================================================================
-- Rose AI: Belief Yield Boosts
-- Belief selection is hardcoded — there's no AiLists system for beliefs.
-- Instead, we add AI-only yield bonuses via BeliefModifiers so that when
-- the AI picks these beliefs, it gains extra value on top of the base effect.
-- NOTE: These are ADDITIONAL yields stacked on the belief's normal effect.
-- ============================================================================

-- ============================================================================
-- 1. MODIFIERS — AI-only yield bonuses
-- ============================================================================

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId) VALUES
('ROSE_BELIEF_WORK_ETHIC_BOOST',        'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_BELIEF_JESUIT_EDUCATION_BOOST',  'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_BELIEF_CHORAL_MUSIC_BOOST',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_BELIEF_FEED_THE_WORLD_BOOST',    'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_BELIEF_ZEN_MEDITATION_BOOST',    'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_BELIEF_RELIGIOUS_COMMUNITY_BOOST','MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_BELIEF_CRUSADE_BOOST',           'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_BELIEF_WORK_ETHIC_BOOST',       'YieldType', 'YIELD_PRODUCTION'),
('ROSE_BELIEF_WORK_ETHIC_BOOST',       'Amount',    1),
('ROSE_BELIEF_JESUIT_EDUCATION_BOOST', 'YieldType', 'YIELD_SCIENCE'),
('ROSE_BELIEF_JESUIT_EDUCATION_BOOST', 'Amount',    1),
('ROSE_BELIEF_CHORAL_MUSIC_BOOST',     'YieldType', 'YIELD_CULTURE'),
('ROSE_BELIEF_CHORAL_MUSIC_BOOST',     'Amount',    1),
('ROSE_BELIEF_FEED_THE_WORLD_BOOST',   'YieldType', 'YIELD_FOOD'),
('ROSE_BELIEF_FEED_THE_WORLD_BOOST',   'Amount',    1),
('ROSE_BELIEF_ZEN_MEDITATION_BOOST',   'YieldType', 'YIELD_FOOD'),
('ROSE_BELIEF_ZEN_MEDITATION_BOOST',   'Amount',    1),
('ROSE_BELIEF_RELIGIOUS_COMMUNITY_BOOST','YieldType', 'YIELD_GOLD'),
('ROSE_BELIEF_RELIGIOUS_COMMUNITY_BOOST','Amount',    1),
('ROSE_BELIEF_CRUSADE_BOOST',          'YieldType', 'YIELD_GOLD'),
('ROSE_BELIEF_CRUSADE_BOOST',          'Amount',    1);

-- ============================================================================
-- 2. BELIEF → MODIFIER LINKS
-- ============================================================================

INSERT OR IGNORE INTO BeliefModifiers (BeliefType, ModifierId) VALUES
('BELIEF_WORK_ETHIC',        'ROSE_BELIEF_WORK_ETHIC_BOOST'),
('BELIEF_JESUIT_EDUCATION',  'ROSE_BELIEF_JESUIT_EDUCATION_BOOST'),
('BELIEF_CHORAL_MUSIC',      'ROSE_BELIEF_CHORAL_MUSIC_BOOST'),
('BELIEF_FEED_THE_WORLD',    'ROSE_BELIEF_FEED_THE_WORLD_BOOST'),
('BELIEF_ZEN_MEDITATION',    'ROSE_BELIEF_ZEN_MEDITATION_BOOST'),
('BELIEF_RELIGIOUS_COMMUNITY','ROSE_BELIEF_RELIGIOUS_COMMUNITY_BOOST'),
('BELIEF_JUST_WAR',          'ROSE_BELIEF_CRUSADE_BOOST');
