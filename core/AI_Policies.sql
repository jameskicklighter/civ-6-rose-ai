-- ============================================================================
-- Rose AI: Policy Card & Government Boosts
-- ============================================================================
-- PolicyModifiers fire ONLY while the card is actively slotted. Swap the card
-- out and the bonus vanishes. Each adjacency-doubling card gets +2 of its
-- matching yield per city, but only in cities where the relevant district has
-- at least +2 adjacency. This ensures the AI only values these cards when it
-- has well-placed districts.
--
-- GovernmentModifiers work the same way — bonuses active while adopted.
-- Tiered bonuses encourage upgrading governments as the game progresses.
-- ============================================================================

-- ============================================================================
-- 1. ADJACENCY REQUIREMENTS
-- ============================================================================
-- Each policy card bonus requires the city to have the matching district with
-- at least +2 adjacency yield (REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT).
-- Combined with REQUIRES_PLAYER_IS_AI so only the AI benefits.
-- ============================================================================

INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType) VALUES
('ROSE_REQ_CAMPUS_ADJ',     'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'),
('ROSE_REQ_HOLY_SITE_ADJ',  'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'),
('ROSE_REQ_THEATER_ADJ',    'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'),
('ROSE_REQ_COMMERCIAL_ADJ', 'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'),
('ROSE_REQ_HARBOR_ADJ',     'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT'),
('ROSE_REQ_INDUSTRIAL_ADJ', 'REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT');

INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value) VALUES
('ROSE_REQ_CAMPUS_ADJ',     'DistrictType', 'DISTRICT_CAMPUS'),
('ROSE_REQ_CAMPUS_ADJ',     'YieldType',    'YIELD_SCIENCE'),
('ROSE_REQ_CAMPUS_ADJ',     'Amount',       2),
('ROSE_REQ_HOLY_SITE_ADJ',  'DistrictType', 'DISTRICT_HOLY_SITE'),
('ROSE_REQ_HOLY_SITE_ADJ',  'YieldType',    'YIELD_FAITH'),
('ROSE_REQ_HOLY_SITE_ADJ',  'Amount',       2),
('ROSE_REQ_THEATER_ADJ',    'DistrictType', 'DISTRICT_THEATER'),
('ROSE_REQ_THEATER_ADJ',    'YieldType',    'YIELD_CULTURE'),
('ROSE_REQ_THEATER_ADJ',    'Amount',       2),
('ROSE_REQ_COMMERCIAL_ADJ', 'DistrictType', 'DISTRICT_COMMERCIAL_HUB'),
('ROSE_REQ_COMMERCIAL_ADJ', 'YieldType',    'YIELD_GOLD'),
('ROSE_REQ_COMMERCIAL_ADJ', 'Amount',       2),
('ROSE_REQ_HARBOR_ADJ',     'DistrictType', 'DISTRICT_HARBOR'),
('ROSE_REQ_HARBOR_ADJ',     'YieldType',    'YIELD_GOLD'),
('ROSE_REQ_HARBOR_ADJ',     'Amount',       2),
('ROSE_REQ_INDUSTRIAL_ADJ', 'DistrictType', 'DISTRICT_INDUSTRIAL_ZONE'),
('ROSE_REQ_INDUSTRIAL_ADJ', 'YieldType',    'YIELD_PRODUCTION'),
('ROSE_REQ_INDUSTRIAL_ADJ', 'Amount',       2);

INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES
('ROSE_AI_ADJ_CAMPUS',     'REQUIREMENTSET_TEST_ALL'),
('ROSE_AI_ADJ_HOLY_SITE',  'REQUIREMENTSET_TEST_ALL'),
('ROSE_AI_ADJ_THEATER',    'REQUIREMENTSET_TEST_ALL'),
('ROSE_AI_ADJ_COMMERCIAL', 'REQUIREMENTSET_TEST_ALL'),
('ROSE_AI_ADJ_HARBOR',     'REQUIREMENTSET_TEST_ALL'),
('ROSE_AI_ADJ_INDUSTRIAL', 'REQUIREMENTSET_TEST_ALL');

INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES
('ROSE_AI_ADJ_CAMPUS',     'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_ADJ_CAMPUS',     'ROSE_REQ_CAMPUS_ADJ'),
('ROSE_AI_ADJ_HOLY_SITE',  'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_ADJ_HOLY_SITE',  'ROSE_REQ_HOLY_SITE_ADJ'),
('ROSE_AI_ADJ_THEATER',    'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_ADJ_THEATER',    'ROSE_REQ_THEATER_ADJ'),
('ROSE_AI_ADJ_COMMERCIAL', 'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_ADJ_COMMERCIAL', 'ROSE_REQ_COMMERCIAL_ADJ'),
('ROSE_AI_ADJ_HARBOR',     'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_ADJ_HARBOR',     'ROSE_REQ_HARBOR_ADJ'),
('ROSE_AI_ADJ_INDUSTRIAL', 'REQUIRES_PLAYER_IS_AI'),
('ROSE_AI_ADJ_INDUSTRIAL', 'ROSE_REQ_INDUSTRIAL_ADJ');

-- ============================================================================
-- 2. MODIFIERS — AI-only yield bonuses gated by adjacency
-- ============================================================================

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId) VALUES
('ROSE_POLICY_ADJ_SCIENCE',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'ROSE_AI_ADJ_CAMPUS'),
('ROSE_POLICY_ADJ_FAITH',        'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'ROSE_AI_ADJ_HOLY_SITE'),
('ROSE_POLICY_ADJ_CULTURE',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'ROSE_AI_ADJ_THEATER'),
('ROSE_POLICY_ADJ_GOLD_COM',     'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'ROSE_AI_ADJ_COMMERCIAL'),
('ROSE_POLICY_ADJ_GOLD_HARBOR',  'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'ROSE_AI_ADJ_HARBOR'),
('ROSE_POLICY_ADJ_PRODUCTION',   'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'ROSE_AI_ADJ_INDUSTRIAL'),
-- Serfdom bonuses: per city, AI-only
('ROSE_POLICY_SERFDOM_FOOD',     'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_POLICY_SERFDOM_PROD',     'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
('ROSE_POLICY_ADJ_SCIENCE',      'YieldType', 'YIELD_SCIENCE'),
('ROSE_POLICY_ADJ_SCIENCE',      'Amount',    2),
('ROSE_POLICY_ADJ_FAITH',        'YieldType', 'YIELD_FAITH'),
('ROSE_POLICY_ADJ_FAITH',        'Amount',    2),
('ROSE_POLICY_ADJ_CULTURE',      'YieldType', 'YIELD_CULTURE'),
('ROSE_POLICY_ADJ_CULTURE',      'Amount',    2),
('ROSE_POLICY_ADJ_GOLD_COM',     'YieldType', 'YIELD_GOLD'),
('ROSE_POLICY_ADJ_GOLD_COM',     'Amount',    2),
('ROSE_POLICY_ADJ_GOLD_HARBOR',  'YieldType', 'YIELD_GOLD'),
('ROSE_POLICY_ADJ_GOLD_HARBOR',  'Amount',    2),
('ROSE_POLICY_ADJ_PRODUCTION',   'YieldType', 'YIELD_PRODUCTION'),
('ROSE_POLICY_ADJ_PRODUCTION',   'Amount',    2),
('ROSE_POLICY_SERFDOM_FOOD',     'YieldType', 'YIELD_FOOD'),
('ROSE_POLICY_SERFDOM_FOOD',     'Amount',    2),
('ROSE_POLICY_SERFDOM_PROD',     'YieldType', 'YIELD_PRODUCTION'),
('ROSE_POLICY_SERFDOM_PROD',     'Amount',    2);

-- ============================================================================
-- 3. POLICY → MODIFIER LINKS
-- ============================================================================

INSERT OR IGNORE INTO PolicyModifiers (PolicyType, ModifierId) VALUES
-- Campus: +100% adjacency → +2 Science (requires Campus adj >= 2)
('POLICY_NATURAL_PHILOSOPHY',  'ROSE_POLICY_ADJ_SCIENCE'),
-- Holy Site: +100% adjacency → +2 Faith (requires Holy Site adj >= 2)
('POLICY_SCRIPTURE',           'ROSE_POLICY_ADJ_FAITH'),
-- Theater Square: +100% adjacency → +2 Culture (requires Theater adj >= 2)
('POLICY_GRAND_OPERA',         'ROSE_POLICY_ADJ_CULTURE'),
-- Commercial Hub: +100% adjacency → +2 Gold (requires Commercial Hub adj >= 2)
('POLICY_TOWN_CHARTERS',      'ROSE_POLICY_ADJ_GOLD_COM'),
-- Harbor: +100% adjacency → +2 Gold (requires Harbor adj >= 2)
('POLICY_NAVAL_INFRASTRUCTURE','ROSE_POLICY_ADJ_GOLD_HARBOR'),
-- Industrial Zone: +100% adjacency → +2 Production (requires IZ adj >= 2)
('POLICY_CRAFTSMEN',           'ROSE_POLICY_ADJ_PRODUCTION'),
-- Serfdom: +2 Builder charges → +2 Food, +2 Production (AI-only, per city)
('POLICY_SERFDOM',             'ROSE_POLICY_SERFDOM_FOOD'),
('POLICY_SERFDOM',             'ROSE_POLICY_SERFDOM_PROD');

-- ============================================================================
-- 4. GOVERNMENT TIER BONUSES
-- ============================================================================
--   Tier 2: +1 Production (all), themed (+2 Gold/Faith/Food)
--   Tier 3: +3 Gold (all), themed (+3 Culture/Science/Production)
--   Tier 4: +5 of every yield
-- ============================================================================

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId) VALUES
-- Tier 2 common
('ROSE_GOV_TIER2_PROD',         'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
-- Tier 2 themed
('ROSE_GOV_MERCHANT_GOLD',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_THEOCRACY_FAITH',    'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_MONARCHY_FOOD',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
-- Tier 3 common
('ROSE_GOV_TIER3_GOLD',         'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
-- Tier 3 themed
('ROSE_GOV_DEMOCRACY_CULTURE',  'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_COMMUNISM_SCI',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_FASCISM_PROD',       'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
-- Tier 4 (every yield)
('ROSE_GOV_TIER4_SCIENCE',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_TIER4_CULTURE',      'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_TIER4_GOLD',         'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_TIER4_PROD',         'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_TIER4_FAITH',        'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI'),
('ROSE_GOV_TIER4_FOOD',         'MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE', 'PLAYER_IS_AI');

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value) VALUES
-- Tier 2 common
('ROSE_GOV_TIER2_PROD',         'YieldType', 'YIELD_PRODUCTION'),
('ROSE_GOV_TIER2_PROD',         'Amount',    1),
-- Tier 2 themed
('ROSE_GOV_MERCHANT_GOLD',      'YieldType', 'YIELD_GOLD'),
('ROSE_GOV_MERCHANT_GOLD',      'Amount',    2),
('ROSE_GOV_THEOCRACY_FAITH',    'YieldType', 'YIELD_FAITH'),
('ROSE_GOV_THEOCRACY_FAITH',    'Amount',    2),
('ROSE_GOV_MONARCHY_FOOD',      'YieldType', 'YIELD_FOOD'),
('ROSE_GOV_MONARCHY_FOOD',      'Amount',    2),
-- Tier 3 common
('ROSE_GOV_TIER3_GOLD',         'YieldType', 'YIELD_GOLD'),
('ROSE_GOV_TIER3_GOLD',         'Amount',    3),
-- Tier 3 themed
('ROSE_GOV_DEMOCRACY_CULTURE',  'YieldType', 'YIELD_CULTURE'),
('ROSE_GOV_DEMOCRACY_CULTURE',  'Amount',    3),
('ROSE_GOV_COMMUNISM_SCI',      'YieldType', 'YIELD_SCIENCE'),
('ROSE_GOV_COMMUNISM_SCI',      'Amount',    3),
('ROSE_GOV_FASCISM_PROD',       'YieldType', 'YIELD_PRODUCTION'),
('ROSE_GOV_FASCISM_PROD',       'Amount',    3),
-- Tier 4 (every yield at +5)
('ROSE_GOV_TIER4_SCIENCE',      'YieldType', 'YIELD_SCIENCE'),
('ROSE_GOV_TIER4_SCIENCE',      'Amount',    5),
('ROSE_GOV_TIER4_CULTURE',      'YieldType', 'YIELD_CULTURE'),
('ROSE_GOV_TIER4_CULTURE',      'Amount',    5),
('ROSE_GOV_TIER4_GOLD',         'YieldType', 'YIELD_GOLD'),
('ROSE_GOV_TIER4_GOLD',         'Amount',    5),
('ROSE_GOV_TIER4_PROD',         'YieldType', 'YIELD_PRODUCTION'),
('ROSE_GOV_TIER4_PROD',         'Amount',    5),
('ROSE_GOV_TIER4_FAITH',        'YieldType', 'YIELD_FAITH'),
('ROSE_GOV_TIER4_FAITH',        'Amount',    5),
('ROSE_GOV_TIER4_FOOD',         'YieldType', 'YIELD_FOOD'),
('ROSE_GOV_TIER4_FOOD',         'Amount',    5);

INSERT OR IGNORE INTO GovernmentModifiers (GovernmentType, ModifierId) VALUES
-- Tier 2: +1 Production (all) + themed
('GOVERNMENT_MONARCHY',                'ROSE_GOV_TIER2_PROD'),
('GOVERNMENT_MONARCHY',                'ROSE_GOV_MONARCHY_FOOD'),
('GOVERNMENT_THEOCRACY',               'ROSE_GOV_TIER2_PROD'),
('GOVERNMENT_THEOCRACY',               'ROSE_GOV_THEOCRACY_FAITH'),
('GOVERNMENT_MERCHANT_REPUBLIC',       'ROSE_GOV_TIER2_PROD'),
('GOVERNMENT_MERCHANT_REPUBLIC',       'ROSE_GOV_MERCHANT_GOLD'),
-- Tier 3: +3 Gold (all) + themed
('GOVERNMENT_FASCISM',                 'ROSE_GOV_TIER3_GOLD'),
('GOVERNMENT_FASCISM',                 'ROSE_GOV_FASCISM_PROD'),
('GOVERNMENT_COMMUNISM',               'ROSE_GOV_TIER3_GOLD'),
('GOVERNMENT_COMMUNISM',               'ROSE_GOV_COMMUNISM_SCI'),
('GOVERNMENT_DEMOCRACY',               'ROSE_GOV_TIER3_GOLD'),
('GOVERNMENT_DEMOCRACY',               'ROSE_GOV_DEMOCRACY_CULTURE'),
-- Tier 4: +5 of every yield
('GOVERNMENT_CORPORATE_LIBERTARIANISM','ROSE_GOV_TIER4_SCIENCE'),
('GOVERNMENT_CORPORATE_LIBERTARIANISM','ROSE_GOV_TIER4_CULTURE'),
('GOVERNMENT_CORPORATE_LIBERTARIANISM','ROSE_GOV_TIER4_GOLD'),
('GOVERNMENT_CORPORATE_LIBERTARIANISM','ROSE_GOV_TIER4_PROD'),
('GOVERNMENT_CORPORATE_LIBERTARIANISM','ROSE_GOV_TIER4_FAITH'),
('GOVERNMENT_CORPORATE_LIBERTARIANISM','ROSE_GOV_TIER4_FOOD'),
('GOVERNMENT_DIGITAL_DEMOCRACY',       'ROSE_GOV_TIER4_SCIENCE'),
('GOVERNMENT_DIGITAL_DEMOCRACY',       'ROSE_GOV_TIER4_CULTURE'),
('GOVERNMENT_DIGITAL_DEMOCRACY',       'ROSE_GOV_TIER4_GOLD'),
('GOVERNMENT_DIGITAL_DEMOCRACY',       'ROSE_GOV_TIER4_PROD'),
('GOVERNMENT_DIGITAL_DEMOCRACY',       'ROSE_GOV_TIER4_FAITH'),
('GOVERNMENT_DIGITAL_DEMOCRACY',       'ROSE_GOV_TIER4_FOOD'),
('GOVERNMENT_SYNTHETIC_TECHNOCRACY',   'ROSE_GOV_TIER4_SCIENCE'),
('GOVERNMENT_SYNTHETIC_TECHNOCRACY',   'ROSE_GOV_TIER4_CULTURE'),
('GOVERNMENT_SYNTHETIC_TECHNOCRACY',   'ROSE_GOV_TIER4_GOLD'),
('GOVERNMENT_SYNTHETIC_TECHNOCRACY',   'ROSE_GOV_TIER4_PROD'),
('GOVERNMENT_SYNTHETIC_TECHNOCRACY',   'ROSE_GOV_TIER4_FAITH'),
('GOVERNMENT_SYNTHETIC_TECHNOCRACY',   'ROSE_GOV_TIER4_FOOD');
