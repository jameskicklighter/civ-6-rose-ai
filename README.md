# Rose AI

Rose AI is a standalone Civilization VI AI overhaul for major civilizations. It pushes the AI toward stronger early growth and economy, timely government upgrades, more deliberate religious and leader-specific choices, and wars fought with one concentrated army at a time.

It is not a map or start-position mod. The separate Rose Better Starts mod can be enabled with it.

## Requirements

- Civilization VI for PC with the Gathering Storm ruleset.
- Leader tuning covers Rise and Fall, New Frontier Pass and Leader Pass content; a complete official DLC installation is recommended.
- In multiplayer, every participant needs the same Rose AI version and the same DLC and gameplay mods. Some war, economy and policy-card checks read values through an InGame UI bridge on each machine; identical game state should give identical readings, but this is not fully tested in multiplayer.

## What Rose AI changes

Most changes are AI preference weights: they make an option more or less attractive but do not force a build order. AI operation limits and team sizes are likewise requests to the Civ VI AI, which it occasionally exceeds.

### Economy and development

- Food and Production weighted up from the Ancient to the Renaissance era, with some early Culture and less early Science.
- Higher priority for population, Traders (always), Great Merchants, Great Engineers and Medieval districts.
- Favored districts: Commercial Hubs (Ancient to Medieval), Industrial Zones (Medieval and Renaissance), Government Plazas and Aqueducts (always), 15 civilizations' unique districts (always), Campuses from the Renaissance (with Great Scientist points and Science), and Aerodromes from the Modern era (with air units).
- Technology and civic priorities: Currency, Engineering (the first siege units), Feudalism, Political Philosophy and the civics that unlock Tier 2 to Tier 4 governments.
- Builders favored in the Medieval and Renaissance eras.

### Civics and policy cards

- **Government civics:** once their base-game prerequisites are met, AI players are granted the Tier 2 and Tier 3 government-unlocking civics they are missing, and with Gathering Storm the Tier 4 ones after Globalization and Social Media.
- **Skipped early civics:** after Guilds or Medieval Faires, the AI is granted any of Mysticism, Drama and Poetry, Theology, Military Tradition, Games and Recreation, and Military Training it skipped.
- Grants come one per turn, at the start of the AI's turn, and never touch the civic the AI is researching. If an AI's civic research is stuck on a civic it already owns, Rose sets a new one in progress.
- **Policy card repair:** the base game sometimes leaves a slotted card without its effect, mostly after a government change. Just before the AI's own civic completes (and before a granted early civic), Rose unslots those cards so the AI slots them again. It skips civics that unlock a government, gives no free policy changes, and retries a card at most three times in a row.
- Grants and repairs apply only to AI major civilizations. The civic tree itself is unchanged.

### War strategies

Rose adds strategies for wars against other major civilizations, plus an austerity mode:

- **At War:** more Production, Gold and army, naval units and replacements; less demand for optional districts, improvements and wonders; enemy cities valued more as targets. While it lasts, the AI starts no new wars on city-states and no planned attacks (a Military Victory AI keeps one), and is willing to use nuclear weapons.
- **Military Recovery:** while the AI's military strength is below 70% of its combined major-civilization enemies (until it recovers to 85%), it rebuilds harder, cuts optional infrastructure further, adds City Defense capacity, favors the Grand Master's Chapel and gives up its planned attack slot.
- **War Advantage:** while the AI is at least 125% as strong as its enemies (until it falls below 110%), it does not seek peace (it can still accept an offer) and gets a second wartime attack.
- **Austerity:** when the AI is nearly out of Gold and losing Gold each turn, it favors Gold, Traders, Commercial Hubs and Harbors and trims part of its extra wartime unit demand until the treasury recovers. It never disbands units or cancels attacks.

The strength checks use the engine's military-strength value through the InGame UI bridge and stay off when that value is unavailable.

### War director

While an AI has been at war with another major civilization for three turns, Rose's script picks one enemy city at a time and sends one army to take it:

- **Target:** the nearest revealed city of a major civilization it is at war with, within 12 tiles of its own cities (16 under War Advantage). City-states are never targets, and neither are cities whose defense is well above anything the AI can bombard with.
- **Army:** 6 to 12 nearby land units, including two siege units against walls or a strong defense, plus bombers in range. The army must be close to the city and have a land route to it. Against a coastal city the siege also asks for two to five ranged warships with a range of 2 or more (the Frigate and later).
- **Holds back** while three or more enemy units stand on the AI's land near its cities, during Military Recovery, or when no army can reach a city.
- After a capture, the next city can follow. The AI's own wartime attack operations are switched off, so this army has the wartime slot.

### Military operations

- **Walled-city sieges** need a unit that can damage walls: a bombard siege unit or a bomber. A siege that has not assembled after about 15 turns ends, and once the AI is already at war it skips the declaration wait. The final assault keeps attacking until the city falls or about 20 turns pass.
- **Reach:** walled-city attacks reach 16 tiles when planned and 22 during a war, so wars reach the enemy's cities instead of nearby city-states.
- **Army size:** aggressive military leaders keep a larger standing army in every era, at peace too. Other AIs build up when they go to war (At War above), and from the Industrial era every AI keeps a somewhat larger army. From the Renaissance, well-defended cities count as more worthwhile targets.
- **City Defense:** at most three operations at once (five during Military Recovery), each with up to three combat units and no bombard units, so assaults keep their siege units. Defenders attack nearby enemies instead of only garrisoning.
- **Recruitment:** operation teams ask cities only for units they can train, so the AI no longer orders faith-only Warrior Monks.
- **Barbarian camps:** an attack ends after about 10 turns of approach or 12 turns at the camp, and camp teams take no bombers.
- **Settlers** go out one operation at a time, with a combat escort.
- **Naval Superiority** is a small, script-started interception of a visible enemy warship within 12 tiles, using nearby ships only.
- A Military Victory strategy adds one planned attack slot instead of two.

### Nuclear weapons

The base game's nuclear operation could not order or keep a delivery unit, so the AI built devices and rarely used them. Rose switches that operation off and orders strikes from its script, one launch per order:

- An AI holding a device and at war with a major civilization for five turns launches a Bomber, Jet Bomber or Nuclear Submarine at a revealed city of that enemy within range.
- Never at a city-state, never where the blast could reach its own units or cities, or the cities of anyone it is not at war with, and not at the same city twice within ten turns.
- Aggressive military leaders and Gandhi research toward nuclear weapons earlier and are always willing to use them; other AIs are willing while At War is active. Gandhi's nuclear attitude is permanent instead of a random hidden agenda.

### Leaders

- Curated religious and low-religion leader groups; leaders who should not spend an early district slot on religion avoid early Holy Sites and Stonehenge, while religious leaders favor early Holy Sites and Great Prophets (both Saladin versions have their own tuning).
- Harbors for selected naval leaders, native coastal raids for original Harald, cavalry and Holy War for Basil II, and expansionist settling for Victoria and Philip II.
- Aggressive military leaders favor formal and surprise wars, value friendships less, and favor the Grand Master's Chapel (Faith purchases of land units).
- Preserves and Mysticism for Bull Moose Roosevelt and John Curtin, Theater Squares for Hammurabi.

### Choice signals

Some policy cards, beliefs and governments carry extra modifiers that the AI's choice scorer counts but that never take effect in play, so they steer picks without changing any real yield:

- **Adjacency cards** (Natural Philosophy, Scripture, Aesthetics, Town Charters, Naval Infrastructure, Craftsmen, Five-Year Plan, Economic Union) score +5 of their yield per point of the matching district's adjacency in each city, up to 10 points.
- **Follower beliefs** (Work Ethic, Jesuit Education, Choral Music, Feed the World, Zen Meditation, Religious Community) score a small yield per city with a Holy Site (Work Ethic: one with +3 adjacency or more).
- **Crusade** scores only for aggressive military leaders and **Defender of the Faith** only while the AI is at war with another major civilization. Hidden marker buildings with no effects tell the scorer which AIs qualify.
- Nine governments and Serfdom and Public Works carry a small envoy signal.

The native effects of these cards, beliefs and governments are unchanged.

## AI-only bonuses

On Prince difficulty and above, AI players get +5 combat strength against barbarians and pay 35% less Gold (and with Gathering Storm 35% fewer strategic resources) to upgrade units; this stacks with Professional Army. The civic grants above are also AI-only.

## Compatibility

- **Rose Better Starts:** compatible; it runs only during map generation.
- **AI+, RomanHoliday's AI, Real Strategy and other broad AI overhauls:** not supported together; they change the same AI lists, strategies, operations and behavior trees.
- **Map generators and start-balancing mods:** generally independent of Rose AI.

Enable only one copy of Rose AI at a time (not a Workshop copy and a local copy together).

## Installation

Subscribe on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3696783308), or copy this folder into the Civ VI Mods directory (commonly `%USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Mods\Rose AI`, with `Rose_AI.modinfo` directly inside). Enable **Rose AI Mod** under Additional Content and start a new game: database and behavior-tree changes do not reliably apply to an existing save.

## Checking that it loaded

The logs are in `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs`:

1. `Modding.log`: the `ROSE_AI`, `ROSE_AI_INGAME_BRIDGE` and `ROSE_AI_SCRIPTS` components load.
2. `Database.log`: no Rose SQL or XML errors, and gameplay validation passes.
3. `Lua.log`: `Rose AI:` lines for loading, civic grants, war strategies, the war director, nuclear strikes and errors. Per-turn diagnostics print only when `ROSE_VERBOSE_LOGS` is true at the top of `core/scripts/Rose_AI_Core.lua` and `core/scripts/Rose_AI_InGame.lua` (false in Workshop releases).
4. Military behavior: `AI_Operation.csv`, `AI_Behavior_Trees.csv`, `AI_CityBuild.csv` and `UnitOperations.log`. A behavior-tree `SUCCESS` means a node completed or accepted its task; confirm the actual moves and attacks in `UnitOperations.log`.

## Project layout

```text
Rose_AI.modinfo                Mod metadata; database files load by their Priority
core/
  strategies/                  Era-onward, war and austerity strategies and their lists
  leaders/                     Leader trait membership and leader-specific lists
  economy/                     Tech, civic, yield, district and unit priorities; AI-only bonuses
  choices/                     Belief, policy-card and government choice signals
  military/                    Operation roles, slots and teams; trees/ holds one behavior tree per file
  scripts/                     Gameplay Lua (entry script and modules), choice markers, InGame bridge
```

Rose AI is under active development. Judge its effects over several games and seeds: Civ VI's AI choices are situational and probabilistic.
