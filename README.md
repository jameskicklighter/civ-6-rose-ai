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

### Inactive choice signals (experimental)

The former policy, government, and belief yield bonuses and treasury clawbacks have been replaced with 29 inactive scoring signals. Each uses the envoy-effect parameter `Amount=1`, gated by mutually contradictory Future Civic requirements. No new Gold, Food, Science, Faith, Culture, Production, or envoys are intended to be granted by these signals. Native effects of every source remain unchanged.

An isolated Serfdom run showed useful scores of 300-464 on first selection and retained scoring after government changes with this impossible gate. The broader government/belief test is not yet runtime-validated. Amount is not a fixed score, and the old +20/+40/+50/+60/+80 Gold weights are not equivalent to these new values. Matching Tier 3 leader traits receive a separate additional signal; initial values can be tuned after collecting scores.

The configured eligibility checks are separate owner requirements; the impossible subject requirements disable gameplay effects independently:

- Natural Philosophy, Scripture, Grand Opera, Town Charters, Naval Infrastructure, and Craftsmen require at least one owned city with a matching district meeting the game's high-adjacency check at +3. Base and unique replacements are included.
- Five-Year Plan accepts a qualifying Campus or Industrial Zone; Economic Union accepts a qualifying Commercial Hub or Harbor. `ROSE_CHOICE_MIN_ADJACENCY` in `AI_Policies.sql` controls the threshold.
- Serfdom and Public Works have no district gate.
- Monarchy and Merchant Republic target non-founders; Theocracy targets religion founders.
- Communism, Democracy, and Fascism receive generic signals plus an extra for matching science, culture, or aggressive-military leader traits. The three Tier 4 governments receive generic signals; Tier 1 is untouched.
- Work Ethic, Jesuit Education, Choral Music, Feed the World, Zen Meditation, and Religious Community target AI belief choices. Crusade (`BELIEF_JUST_WAR`) additionally requires the aggressive-military leader trait. Belief choice does not require a religion to have already been founded.

**Eligibility scoring still needs verification.** The native chooser demonstrably ignores the impossible subject gate for Serfdom; whether it honors the distinct owner requirements must be tested with qualified and unqualified players. SQL checks cannot prove that adjacency, founder, or personality conditions change the native score. Human owners fail the eligibility gates, and the envoy effect is blocked for everyone regardless of eligibility.

The general Food/Science/Gold weights in `AI_Yields.sql` and wartime strategies remain: those are AI valuation weights, not resources granted to players. The former Gold ledger is removed, so old debt properties are inert and no longer collected. The old internal Serfdom building remains registered only so gameplay Lua can remove saved copies; no new copies are created and no modifier is attached to it.

For this full migration, restart Civ VI and start a **fresh game**. The old turn-46 save already contains other Rose policy/belief signals even though Serfdom was not yet unlocked; saved modifier instances have persisted across prior SQL changes. Marker cleanup does not guarantee removal of every serialized old yield effect.

Verify clean gameplay database loading, then inspect native policy/government/belief scores and choices. `Lua.log` lines beginning `Rose AI: Choice signals` report government, slotted policies and active flags, founded beliefs, Gold balance, and net GPT without changing the treasury. Collect examples with and without good-adjacency districts and aggressive-military traits before treating the eligibility gates as proven. Archives of the previous Gold and Serfdom-only experiments remain under the workspace scratch directory.

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
