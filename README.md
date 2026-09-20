# Rose AI

Rose AI is a standalone Civilization VI AI overhaul. It pushes major-civilization AI toward stronger economic development, timely government upgrades, more deliberate religious and leader-specific choices, and military operations that recover and concentrate more reliably.

This is not a map or starting-position mod. It is independent from the separate Rose Better Starts mod, and the two may be enabled together.

## Requirements

- Civilization VI for PC with the Gathering Storm ruleset is expected.
- The current leader tuning references content from Rise and Fall, New Frontier Pass, and Leader Pass. A complete official DLC installation is recommended.
- Every participant in a multiplayer game should use the same Rose AI version and the same enabled DLC and gameplay mods.

The manifest declares multiplayer support, but multiplayer behavior still depends on every participant loading identical data and scripts.

## What Rose AI changes

### Economy and development

- Favors Food and Production during the Ancient through Renaissance eras, with early Culture support and a reduced early Science bias.
- Raises priorities for population, Traders, Great Merchants, Great Engineers, and Medieval districts.
- Favors Commercial Hubs, Industrial Zones, Government Plazas, Aqueducts, and 15 explicitly supported unique districts.
- Prioritizes Currency, Feudalism, Political Philosophy, and the civics that unlock Tier 2 through Tier 4 governments.
- Favors Builders during the Medieval and Renaissance eras.

These are AI preference weights. They influence decisions but do not force a specific build order or guarantee that the AI will choose an item immediately.

### Government and civic progression

The gameplay script helps AI majors recover civic branches that the normal AI often skips:

- After their normal prerequisites are complete, the AI is granted the Tier 2 and Tier 3 government-unlocking civics it is missing.
- Gathering Storm Tier 4 government civics are granted after Globalization and Social Media are complete.
- Reaching Guilds or Medieval Faires fills six skipped early civics: Mysticism, Drama and Poetry, Theology, Military Tradition, Games and Recreation, and Military Training.

These grants apply only to non-human major civilizations. Rose AI does not rewrite the civic tree's prerequisite relationships.

### Dynamic war behavior

Rose AI adds three strategies for wars against other major civilizations:

- **At War** favors Production, Gold, combat units, naval units, and army replacement while temporarily reducing optional district, improvement, and wonder demand.
- **Military Recovery** stacks when the AI's military strength is below 70% of the combined opposing major armies. It adds defensive capacity, reduces one city-assault slot, and places a stronger emphasis on rebuilding.
- **War Advantage** discourages voluntary peace while the AI is at least 125% as strong as the combined opposing major armies.

The strength checks use an InGame UI bridge to read the engine's military-strength value. They fail closed when that value is unavailable, so the strength-gated recovery and advantage modes are not activated from incomplete data.

### Military operations and behavior trees

- Walled-city assaults require an actual bombard siege unit and may use a limited number of bombers.
- City-defense operations avoid consuming bombard siege units needed by assaults.
- City-assault production contracts exclude faith-only and otherwise untrainable units, preventing impossible Warrior Monk contracts.
- City-assault strength thresholds, recruitment ranges, phase limits, target distances, and operation concurrency are tuned to reduce premature attacks and army fragmentation.
- Settlement operations are limited to one at a time and retain a combat escort without recruiting siege or bomber roles.
- The Simple City Defense tree is replaced with a focused version.
- Naval Superiority is a small, Lua-started interception against a visible enemy combat ship within 12 tiles. It uses nearby existing ships, cannot create or steal units, and keeps a patrol fallback active while the target is reacquired.
- Barbarian-camp attack teams cannot recruit bombers that their ground-operation tree cannot use.

The operation limits and requested team maxima are instructions to the Civ VI AI system, not hard engine caps. The engine can occasionally exceed them.

### Leader, district, and diplomacy tuning

- Curates religious and low-religious leader traits.
- Discourages early Holy Sites and Stonehenge for leaders that should not spend an early district slot on religion.
- Gives religious leaders stronger early Holy Site and Great Prophet priorities, with separate treatment for both Saladin versions.
- Adds Harbor priorities for selected naval leaders and native coastal-raiding support for original Harald.
- Adds cavalry and Holy War preferences for Basil II.
- Adds expansionist behavior to Victoria and Philip II.
- Gives aggressive military leaders a stronger war preference and a moderate diplomatic-bonus penalty.
- Supports Preserve and Mysticism choices for Bull Moose Roosevelt and John Curtin, and Theater Squares for Hammurabi.

## Explicit AI-only bonuses

Rose AI gives non-human players +5 combat strength against barbarians on Prince difficulty and above, plus the civic grants described earlier.

### Inactive choice bias

The artificial yield signals influence AI evaluation while requiring both having and lacking Future Civic for gameplay activation. They do not pay out resources. Natural Philosophy's Prince control test changed Brazil's score from 114 to 58 when its artificial Science amount changed from 3 to 0, while recorded Science matched through turn 58. Its amount is restored to 3. The expanded cards and beliefs still need their own runtime tests.

Adjacency cards advertise **+3 matching yield per qualifying city**, using a direct city subject check at **at least +3 district adjacency**, including active unique district replacements:

| Policy | Inactive evaluation signal |
|---|---|
| Natural Philosophy | +3 Science for a qualifying Campus |
| Scripture | +3 Faith for a qualifying Holy Site |
| Grand Opera | +3 Culture for a qualifying Theater Square |
| Town Charters | +3 Gold for a qualifying Commercial Hub |
| Naval Infrastructure | +3 Gold for a qualifying Harbor |
| Craftsmen | +3 Production for a qualifying Industrial Zone |
| Five-Year Plan | Independent Campus Science and Industrial Zone Production components |
| Economic Union | Independent Commercial Hub and Harbor Gold components |

The combined cards use inclusive OR eligibility: either qualifying district contributes, and both contribute when both qualify, even in different cities. A city with both qualifying Economic Union districts contributes a hypothetical +6 Gold. Each unique district replacement satisfies the same component, without a duplicate bonus. Serfdom and Public Works retain one inactive **player-scoped** envoy signal each, with Amount=1; it does not scale per city.

Belief signals replace the former generic envoy bonuses:

| Belief | Inactive signal and qualifying scope |
|---|---|
| Work Ethic | +3 Production per owned city with a Holy Site at +3 Faith adjacency or higher |
| Jesuit Education | +1 Science and +1 Culture per owned city with a Holy Site |
| Choral Music | +3 Culture per owned city with a Holy Site |
| Feed the World | +1 Food per owned city with a Holy Site |
| Zen Meditation | +1 Food per owned city with a Holy Site, retaining the original growth proxy for amenities |
| Religious Community | +1 Gold per owned city with a Holy Site |
| Tithe | Native valuation retained; artificial signal deferred |
| Crusade | One inactive envoy signal (Amount=1) in a military AI Palace city; requires both Palace and military marker |
| Defender of the Faith | One inactive envoy signal (Amount=1) in an AI Palace city while at war with another major civilization; requires Palace and temporary war marker |

Only Work Ethic has an adjacency threshold among these follower-belief signals. The other Holy Site signals do not require Shrine/Temple construction or an already-founded religion. Jesuit Education's Science and Zen Meditation's Food proxies come from the original belief implementation in commit `b94b5af`.

Tithe's artificial signal is deferred. The traced city-religion handler treats an unset evaluation religion (-1) as matching every city; the founder handler also accepts that wildcard. A direct all-cities signal could therefore overvalue Tithe before founding. The native Tithe effects remain unchanged until strict religion scope can be established.

Crusade's former military-trait owner gate was not verified in a military/nonmilitary runtime comparison; the traced scorer skips owner gates and has no leader-trait requirement handler. `Rose_AI_ChoiceMarkers.lua` instead reads the existing `TRAIT_LEADER_AGGRESSIVE_MILITARY` classification (including inherited leader traits) and maintains an internal, unbuildable marker in those AI leaders' cities. The marker has no yields, maintenance, amenities, housing, defenses, or attached modifiers. The belief's TEST_ALL city subject requirements check both marker and Palace in the same city, while its contradictory owner requirements block the hypothetical envoy effect. Its custom modifier combines `COLLECTION_PLAYER_CITIES` with `EFFECT_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN`. The traced evaluator checks city subjects before adding score, and its no-match fallback adds none. This gives one contribution from the Palace city, not one per owned city; Amount=1 is not a fixed score. No religion/founder gate is added. Markers stay in all eligible cities so the SQL filter follows native Palace movement without special capital-transfer Lua. The helper removes markers from ineligible owners and reconciles founding, conquest, turn start, reload on the next turn, and optional transfer events; it does not assume the native grant effect cleans up captures. The helper uses Firaxis's ordinary-building creation call `(buildingIndex, 100)` and removes any marker queue entry during cleanup. This indirect scoring gate needs a fresh-game military/nonmilitary comparison.

Defender of the Faith uses a separate, zero-yield war marker for any alive major AI currently fighting another alive major civilization. Wars against humans count; wars only against city-states or barbarians do not. No military-leader or religion-founder condition is added. The helper reads current diplomacy on each reconciliation, keeps the marker while any qualifying war remains, and removes it after the last qualifying war ends. Turn-start hooks are the reliable refresh path; guarded declaration/peace Events request immediate refresh where exposed, but their gameplay delivery remains unverified. Without those events, changes are reflected at the next turn hook. Both envoy beliefs retain their native effects, and an already-chosen belief is never removed or changed.

Government signals remain the existing inactive envoy experiment: 12 components across nine governments, with unchanged founder and leader owner checks. Those owner checks are **not proven to restrict AI scoring**. No expanded policy or belief district eligibility relies on them.

The registry emits 33 components across 10 cards, nine governments, and eight beliefs. Native card, government, and belief effects remain intact. No Gold compensation, treasury accounting, or old-save migration is present. Start a **fresh game after restarting Civ VI** for this structural change. Check native AI choice logs, the loaded gameplay database, and `Rose AI: ... military/war choice marker` messages; compare actual yields against a control when testing new signal types.

## Compatibility

Rose AI changes AI lists, leader traits, strategies, operation teams, behavior trees, gameplay Lua, and an InGame UI context. Mods that replace the same records may overwrite Rose or be overwritten according to load order.

- **Rose Better Starts:** compatible. It runs only during map generation and does not touch Rose AI's systems.
- **AI+, RomanHoliday's AI, Real Strategy, and other broad AI overhauls:** not supported together. Their AI lists, strategies, operations, or behavior trees overlap substantially.
- **Map generators and start-balancing mods:** generally separate from Rose AI, subject to their own mutual compatibility rules.

For a clean test, enable only one copy of Rose AI. Do not keep both a Workshop copy and a local development copy active.

## Installation

1. Copy the complete `rose-ai-mod` folder into the Civ VI Mods directory, commonly:

   ```text
   %USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Mods\Rose AI
   ```

2. Confirm `Rose_AI.modinfo` is directly inside that folder.
3. Enable **Rose AI Mod** under Additional Content.
4. Start a new game. Database and behavior-tree changes are not reliably applied retroactively to an existing save.

## Verification and troubleshooting

The Civ VI logs are normally located at:

```text
%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs
```

For a fresh-game test:

1. In `Modding.log`, confirm that `ROSE_AI`, `ROSE_AI_INGAME_BRIDGE`, and `ROSE_AI_SCRIPTS` load.
2. In `Database.log`, look for Rose-related SQL/XML errors and confirm gameplay foreign-key validation passes.
3. In `Lua.log`, search for `Rose AI:` load, civic-grant, war-state, naval-operation, and runtime-error messages.
4. For military behavior, correlate `AI_Behavior_Trees.csv`, `AI_Operation.csv`, `AI_Operation_Eval.csv`, `AI_CityBuild.csv`, and `UnitOperations.log`.

A behavior-tree `SUCCESS` means that a node completed or accepted its task; it does not by itself prove that a unit carried out the intended map action. Confirm movement, attacks, and pillaging in `UnitOperations.log` or in-game observation.

## Project layout

```text
Rose_AI.modinfo                 Mod metadata and component load order
core/
  AI_Strategies.sql            Era and dynamic war strategies
  AI_Leaders.sql               Leader traits and leader-specific priorities
  AI_Techs.sql                 Technology and civic priorities
  AI_Yields.sql                Era yield and pseudoyield preferences
  AI_Districts.sql             District priorities
  AI_Units.sql                 Builder priorities and barbarian combat bonus
  AI_Beliefs.sql               Shared choice-signal registry and belief preferences
  AI_Policies.sql              Conditional inactive choice-signal modifiers
  AI_BehaviorTreeOps.sql        Operation roles and concurrency limits
  AI_BehaviorTrees.xml          Operation-team and behavior-tree tuning
  Rose_AI_Gameplay.lua         Civic grants, choice audits, war and naval logic
  Rose_AI_InGame.lua/.xml      Military-strength bridge
```

Rose AI is under active development. Results should be evaluated across multiple games and seeds because Civ VI's AI choices remain situational and probabilistic.
