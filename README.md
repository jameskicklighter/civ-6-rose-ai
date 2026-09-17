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

Policy, belief, and government preferences use a separate dummy-Gold system. Selected choices temporarily advertise fixed Gold-per-turn modifiers to the AI evaluator, while gameplay Lua removes the corresponding Gold from the AI treasury at the start of its next turn. Serfdom currently uses the separate building experiment described below. The other signals still inflate projected Gold-per-turn while active.

- Selected policy cards advertise +20 or +40 Gold; adjacency cards require a matching district.
- Seven highlighted religious beliefs advertise +20 Gold each to their AI religion founder.
- Tier 2 governments advertise +40 according to religion-founder status.
- Tier 3 governments advertise +50 generically, with another +60 for matching science, culture, or aggressive-military leader tags.
- Tier 4 governments advertise +80.

Policy and belief signals use fixed player-level Gold. Government signals use a flat capital-city Gold modifier so the government chooser sees a city-scoped benefit without nominal empire-size scaling. Lua reads the configured amounts from the shared ledger and claws back that nominal total, excluding Serfdom in the experimental modes.

The capital-city government signal is experimental. City-wide percentage modifiers, including the capital's amenity yield modifier, can scale its actual contribution; Civ VI exposes no reliable gameplay-Lua API for isolating that marginal amount. The clawback therefore remains exact for player-level policy and belief signals but can differ from the realized government payout by the capital's active percentage modifiers. Clawback logs expose the nominal government amount for testing.

Human players receive neither these modifiers nor their Lua clawbacks.

### Serfdom scoring experiments

`ROSE_SERFDOM_EXPERIMENT_MODE` near the top of `core/AI_Policies.sql` selects the test. The current setting is **4**, an inactive envoy-effect scoring probe. Serfdom retains its native Builder charges, but has no experimental Gold attachment, capital offset, or Serfdom Lua deduction. Other cards, beliefs, governments, and existing ledger debt are unchanged. Modes 0–3 remain available as controls.

Mode 4 borrows the modifier type used by RH's `ENC_POLICY_RH`, which is gated behind AI/Future Civic requirements. Rose adds an inverse Future Civic requirement to the same `TEST_ALL` set: the player must both have and lack the civic, so the envoy effect cannot activate. The hypothesis is that the AI may still score the disabled effect; this has not been demonstrated. Public Works is outside this isolated probe and retains its existing Gold/clawback behavior.

| Mode | Serfdom signal | Offset |
| --- | --- | --- |
| 0 | None | None (baseline) |
| 1 | +40 Gold | None (intentional positive-only control) |
| 2 | +40 Gold | −40 player Gold from the capital marker |
| 3 | +40 Gold | Original next-turn treasury clawback |
| 4 | Envoy-effect probe with an unsatisfiable requirement | None; actual envoy effect gated off |

For mode 4, restart the game and replay the original pre-Feudalism turn-46 save through approximately turn 60. Check `AI_GovtPolicies.csv` for Serfdom's candidate score and selection, including Greece's government change. `Lua.log` must report mode 4 and zero Serfdom markers. Serfdom must contribute no Gold or Lua deduction. A higher score would support the hypothesis; database validation alone cannot establish scoring behavior. Do not use a save where the earlier Gold signal was already active, because saved modifier instances made previous comparisons ambiguous.

In mode 2, Lua places `BUILDING_ROSE_SERFDOM_OFFSET` in the AI capital while Serfdom is both slotted and reported active. It subtracts 40 player Gold to offset the card's +40 signal. Only mode 3 includes Serfdom in Lua's clawback. Other policy snapshots require active status; old slot-only snapshots are skipped rather than treated as proof of an earned bonus.

The marker is internal, has an unassigned trait to prevent normal construction, and has no maintenance or city yield. Lua reconciles policy changes, obsolescence, capital/city changes, loading, and both turn boundaries, removing stale copies before adding a new one. This is an experiment: database validity and Lua tests do not prove that the engine resolves this building's modifier to the player or preserves the policy score.

To test, copy the selected SQL mode to the active mod and fully reload the game database for each run. Use separate copies of the same pre-choice save (preferably before Feudalism unlocks), then compare modes 0, 1, and 2. Ignore the first income interval when switching an existing save between accounting modes; old debt is deliberately retained. Archive logs after each run before restarting.

Check `Database.log` and `Modding.log` for clean loading, then compare Serfdom scores in `AI_GovtPolicies.csv`. Mode 2 should retain mode 1's attractive score while its net GPT and passive treasury gain match mode 0. `Lua.log` lines beginning `Rose AI: Serfdom experiment` report mode, slots, marker count, treasury and net GPT (when exposed to gameplay). Other cards/governments, maintenance, trades, spending, and clawbacks must be held constant or accounted for. Verify unslotting/obsolescence removes the marker, reloading does not duplicate it, and changing or capturing the capital leaves exactly one marker for a qualifying AI and none for a human. Switch to mode 3 to restore the previous behavior; keep the marker definition installed until saved copies have been cleaned up.

The first runtime test retained Serfdom's score of 294 and all eight major AIs selected it, but the Gold audit was interrupted by a gameplay-only API error: `GetCurrentGovernment()` requires the InGame UI bridge. That getter now uses the bridge; an unavailable bridge is logged and skips only the unverified government charge. Snapshots also refresh for other AIs when each player starts a turn, because this test delivered no observable AI end-turn callbacks. The current actor's previous snapshot is preserved for its income accounting.

For the next test, `Serfdom offset measurement` logs once per qualifying AI per session at a turn boundary. It briefly removes and restores only the internal marker, without an income tick between, and records GPT with/without/restored plus treasury before/after. An observed `marker_delta -40`, restored GPT equal to the initial value, and unchanged treasury support correct compensation. Zero or another delta needs investigation; the logger does not assume modifier recalculation is immediate. This checks the marker's contribution, while a separate comparison against modes 0/1 is still needed to prove the full policy-plus-marker net effect.

A saved-game continuation through turns 65–74 loaded the updated scripts and observed marker changes of exactly +40 on removal and −40 on addition. Ethiopia's turn-73 re-slot also showed an intervening +40 GPT rise, consistent with the positive policy signal; other cards were changing too, so that rise is not an isolated measurement of Serfdom's positive modifier. A second API error (`CityDistricts:Members()`) still blocked the generic ledger; district gates now query only the relevant district types with `HasDistrict(index, true)`, and an unavailable query skips those gates with a warning. The Serfdom audit now runs before the unrelated ledger. Logs distinguish `slotted` from `active`; the active check is a necessary guard, not proof that every native modifier attachment is correct after a government transition. A fresh continuation is still needed to verify uninterrupted bookkeeping.

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
  AI_Beliefs.sql               Shared dummy-Gold ledger and belief preferences
  AI_Policies.sql              Policy and government dummy-Gold preferences
  AI_BehaviorTreeOps.sql        Operation roles and concurrency limits
  AI_BehaviorTrees.xml          Operation-team and behavior-tree tuning
  Rose_AI_Gameplay.lua         Civic grants, Gold clawback, war and naval logic
  Rose_AI_InGame.lua/.xml      Military-strength bridge
```

Rose AI is under active development. Results should be evaluated across multiple games and seeds because Civ VI's AI choices remain situational and probabilistic.
