-- ============================================================================
-- Rose AI: Gameplay support
-- ============================================================================
-- 1. Government civics: When an AI player's prereqs for a government-unlocking
--    civic are met, grant it for free. Prevents AI from skipping government
--    upgrades because it beelined past side-branch civics.
--
-- 2. Tree-filling civics: Once Guilds or Medieval Faires is owned, grant
--    Military Training, Theology, and their prereqs if missing. The AI often
--    ignores one or both edges of the early civic tree.
--
-- Civic grants run only at the AI player's turn start, one civic per player
-- per game turn: the first ready government civic, otherwise the first
-- missing tree-fill civic. Remaining grants follow on later turns, so the AI
-- changes government at most once per turn. A grant waits a turn when the
-- AI's own civic completes this turn.
--
-- 3. Dynamic war strategies: Forbidden Lua conditions control wartime
--    replacement, weak-army recovery, and strength-gated peace resistance
--    database lists.
--
-- 3b. Austerity: a turn-start latch on Gold balance and net income drives two
--    Forbidden Lua conditions that shift priorities toward income. It never
--    touches units, operations, or the treasury.
--
-- 3c. Stuck Trader diagnostic: print-only lines for AI Traders that stay on
--    one plot for several turn starts (only with ROSE_VERBOSE_LOGS on).
--
-- 4. Special operations:
--    - Any AI major can launch a small, cooldown-controlled naval interception
--      when an uncommitted melee ship is near an at-war enemy combat ship.
--
-- 5. Dead policy card repair: a base-game bug leaves slotted cards without
--    their effects. Slots holding such cards (found by the InGame audit) are
--    cleared at the AI's turn start, just before a civic completion that
--    makes CultureAI slot its cards again.
-- ============================================================================

print("Rose AI: Loading gameplay support script");

-- Per-turn diagnostic output (the stuck Trader lines). Off for release; errors,
-- grants, strategy and austerity changes and policy repairs always print.
local ROSE_VERBOSE_LOGS = false;

-- War strategies use Forbidden Lua conditions with no positive condition, so
-- an unanswered check could leave them allowed. Register the callbacks first:
-- until the implementations below have loaded, each one forbids its strategy.
-- A load error anywhere later in this file therefore keeps them off.
local tForbidStrategy = {};
local function RegisterForbidCallback(sName)
	GameEvents[sName].Add(function(iPlayerID, iThreshold)
		local fnForbid = tForbidStrategy[sName];
		if fnForbid == nil then return true; end
		return fnForbid(iPlayerID, iThreshold);
	end);
end
RegisterForbidCallback("RoseForbidStrategyAtWar");
RegisterForbidCallback("RoseForbidStrategyMilitaryRecovery");
RegisterForbidCallback("RoseForbidStrategyWarAdvantage");
RegisterForbidCallback("RoseForbidStrategyAusterity");
RegisterForbidCallback("RoseForbidStrategyAusterityAtWar");

local NAVAL_SUPERIORITY_SUCCESS_COOLDOWN = 12;
local NAVAL_SUPERIORITY_FAILURE_RETRY = 4;
local NAVAL_SUPERIORITY_MAX_DISTANCE = 12;

local NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY = "ROSE_NAVAL_SUPERIORITY_NEXT_ATTEMPT";

-- Cache database AI roles once so unique naval units inherit their base roles.
local tUnitAiTypes = {};
for kUnitAiInfo in GameInfo.UnitAiInfos() do
	local tTypes = tUnitAiTypes[kUnitAiInfo.UnitType];
	if tTypes == nil then
		tTypes = {};
		tUnitAiTypes[kUnitAiInfo.UnitType] = tTypes;
	end
	tTypes[kUnitAiInfo.AiType] = true;
end

-- ============================================================================
-- Government civics table: grant when all prereqs are met
-- ============================================================================
local tGovtCivics = {
	-- Tier 2
	{ civic = GameInfo.Civics["CIVIC_DIVINE_RIGHT"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_CIVIL_SERVICE"].Index,
	              GameInfo.Civics["CIVIC_THEOLOGY"].Index } },
	{ civic = GameInfo.Civics["CIVIC_EXPLORATION"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_MERCENARIES"].Index,
	              GameInfo.Civics["CIVIC_MEDIEVAL_FAIRES"].Index } },
	{ civic = GameInfo.Civics["CIVIC_REFORMED_CHURCH"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_GUILDS"].Index,
	              GameInfo.Civics["CIVIC_DIVINE_RIGHT"].Index } },
	-- Tier 3
	{ civic = GameInfo.Civics["CIVIC_SUFFRAGE"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_IDEOLOGY"].Index } },
	{ civic = GameInfo.Civics["CIVIC_TOTALITARIANISM"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_IDEOLOGY"].Index } },
	{ civic = GameInfo.Civics["CIVIC_CLASS_STRUGGLE"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_IDEOLOGY"].Index } },
};

-- Tier 4 civics only exist with Gathering Storm
if GameInfo.Civics["CIVIC_CORPORATE_LIBERTARIANISM"] then
	table.insert(tGovtCivics, {
		civic = GameInfo.Civics["CIVIC_CORPORATE_LIBERTARIANISM"].Index,
		prereqs = { GameInfo.Civics["CIVIC_GLOBALIZATION"].Index,
		            GameInfo.Civics["CIVIC_SOCIAL_MEDIA"].Index } });
	table.insert(tGovtCivics, {
		civic = GameInfo.Civics["CIVIC_DIGITAL_DEMOCRACY"].Index,
		prereqs = { GameInfo.Civics["CIVIC_GLOBALIZATION"].Index,
		            GameInfo.Civics["CIVIC_SOCIAL_MEDIA"].Index } });
	table.insert(tGovtCivics, {
		civic = GameInfo.Civics["CIVIC_SYNTHETIC_TECHNOCRACY"].Index,
		prereqs = { GameInfo.Civics["CIVIC_GLOBALIZATION"].Index,
		            GameInfo.Civics["CIVIC_SOCIAL_MEDIA"].Index } });
end

-- ============================================================================
-- Tree-filling civics: grant once ANY trigger civic is owned.
-- Fills in skipped branches so the AI has Military Training and Theology
-- (and their prereqs) by the time it reaches Medieval era.
-- ============================================================================
local iGuilds         = GameInfo.Civics["CIVIC_GUILDS"].Index;
local iMedievalFaires = GameInfo.Civics["CIVIC_MEDIEVAL_FAIRES"].Index;

-- Civics to grant (in dependency order — prereqs first, one per turn)
local tTreeFillCivics = {
	GameInfo.Civics["CIVIC_MYSTICISM"].Index,
	GameInfo.Civics["CIVIC_DRAMA_POETRY"].Index,
	GameInfo.Civics["CIVIC_THEOLOGY"].Index,
	GameInfo.Civics["CIVIC_MILITARY_TRADITION"].Index,
	GameInfo.Civics["CIVIC_GAMES_RECREATION"].Index,
	GameInfo.Civics["CIVIC_MILITARY_TRAINING"].Index,
};

-- First government civic in tGovtCivics order that is missing and whose
-- prereqs are all owned, or nil. A grant made this turn may make the next
-- entry ready (e.g. Divine Right → Reformed Church); it is granted next turn.
local function FindReadyGovtCivic(pCulture)
	for _, entry in ipairs(tGovtCivics) do
		if not pCulture:HasCivic(entry.civic) then
			local bAllMet = true;
			for _, iPrereq in ipairs(entry.prereqs) do
				if not pCulture:HasCivic(iPrereq) then
					bAllMet = false;
					break;
				end
			end
			if bAllMet then return entry.civic; end
		end
	end
	return nil;
end

-- First missing tree-filling civic once the AI owns Guilds or Medieval Faires,
-- or nil. These are early-tree civics the AI may have skipped entirely.
local function FindTreeFillCivic(pCulture)
	if not pCulture:HasCivic(iGuilds) and not pCulture:HasCivic(iMedievalFaires) then
		return nil;
	end
	for _, iCivic in ipairs(tTreeFillCivics) do
		if not pCulture:HasCivic(iCivic) then return iCivic; end
	end
	return nil;
end

-- ============================================================================
-- Shared scripted-operation helpers
-- ============================================================================

local function IsEligibleAIPlayer(pPlayer)
	return pPlayer ~= nil
		and pPlayer:IsAlive()
		and pPlayer:IsMajor()
		and not pPlayer:IsHuman();
end

-- ============================================================================
-- Civic grants: one per eligible AI player per game turn, from turn start only
--
-- SetCivic fires GameEvents.OnCivicCulturevated synchronously, before it
-- returns. Granting from that callback nested every cascade inside the
-- previous grant, so the AI changed government several times in one turn
-- (three tier-3 civics printed in reverse order). Grants therefore run only
-- from PlayerTurnStarted. bGrantingCivic stops anything re-entered during a
-- grant from granting again, and the persisted turn property stops a second
-- PlayerTurnStarted for the same player-turn (or a reload) from doing so.
--
-- Every civic completion makes CultureAI commit its policy deck, and two
-- commits in one turn are a common point for cards to lose their effects
-- (HANDOFF W15). The AI's own civic completes later in its turn than this
-- hook (2026-10-06 AI_GovtPolicies.csv: Persia's granted Reformed Church is
-- logged before its researched Medieval Faires on turn 63), so the grant is
-- deferred when the civic in progress is due this turn.
-- ============================================================================
local CIVIC_GRANT_TURN_PROPERTY = "ROSE_CIVIC_GRANT_TURN";
local bGrantingCivic = false;

local function GetCivicTypeName(iCivic)
	local kCivic = GameInfo.Civics[iCivic];
	return kCivic ~= nil and kCivic.CivicType or ("index " .. tostring(iCivic));
end

-- Civics whose completion unlocks a government; CultureAI may change
-- government when one completes.
local tGovernmentCivics = {};
for kGovernment in GameInfo.Governments() do
	if kGovernment.PrereqCivic ~= nil then
		local kCivic = GameInfo.Civics[kGovernment.PrereqCivic];
		if kCivic ~= nil then tGovernmentCivics[kCivic.Index] = true; end
	end
end

-- The civic in progress when it should complete this turn (one turn or less
-- to go, as the civics tree shows it; AI_GovtPolicies.csv shows 1 on the turn
-- before each completion), otherwise nil. Also nil when nothing is in
-- progress or the query fails; a failure of both queries is printed once,
-- since grants then never wait and the repair never runs on the AI's own
-- civic.
local bCivicQueryWarned = false;
local function GetOwnCivicDueThisTurn(pCulture)
	local iCivic = nil;
	local bOk, iTurnsLeft = pcall(function()
		iCivic = pCulture:GetProgressingCivic();
		if type(iCivic) ~= "number" or iCivic < 0 then return nil; end
		return pCulture:GetTurnsToProgressCivic(iCivic);
	end);
	if not bOk then
		bOk, iTurnsLeft = pcall(function() return pCulture:GetTurnsLeftOnCurrentCivic(); end);
		if not bOk and not bCivicQueryWarned then
			bCivicQueryWarned = true;
			print("Rose AI ERROR: Civic progress queries failed; grants will not wait for the AI's own civic: "
				.. tostring(iTurnsLeft));
		end
	end
	if not bOk or type(iTurnsLeft) ~= "number" or iTurnsLeft < 0 or iTurnsLeft > 1 then return nil; end
	if type(iCivic) ~= "number" or iCivic < 0 then return -1; end -- due, civic unknown (fallback)
	return iCivic;
end

-- The civic Rose would grant now and its kind, or nil.
local function FindCivicToGrant(pCulture)
	local iCivic = FindReadyGovtCivic(pCulture);
	if iCivic ~= nil then return iCivic, "government"; end
	iCivic = FindTreeFillCivic(pCulture);
	if iCivic ~= nil then return iCivic, "tree-fill"; end
	return nil, nil;
end

local function GrantOneCivic(iPlayerID, bOwnCivicDue)
	if bGrantingCivic then return false; end
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return false; end

	local iTurn = Game.GetCurrentGameTurn();
	if pPlayer:GetProperty(CIVIC_GRANT_TURN_PROPERTY) == iTurn then return false; end

	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return false; end

	local iCivic, sKind = FindCivicToGrant(pCulture);
	if iCivic == nil then return false; end

	if bOwnCivicDue then
		print("Rose AI: Deferred " .. sKind .. " civic " .. GetCivicTypeName(iCivic)
			.. " for AI player " .. iPlayerID .. " turn " .. iTurn
			.. ": its own civic completes this turn");
		return false;
	end

	-- Record the turn before SetCivic so anything it re-enters sees it.
	pPlayer:SetProperty(CIVIC_GRANT_TURN_PROPERTY, iTurn);
	bGrantingCivic = true;
	local bOk, sError = pcall(function() pCulture:SetCivic(iCivic, true); end);
	bGrantingCivic = false;
	if not bOk then
		print("Rose AI ERROR: Civic grant failed player " .. iPlayerID
			.. " turn " .. iTurn .. " civic " .. GetCivicTypeName(iCivic)
			.. ": " .. tostring(sError));
		return false;
	end
	print("Rose AI: Granted " .. sKind .. " civic " .. GetCivicTypeName(iCivic)
		.. " to AI player " .. iPlayerID .. " turn " .. iTurn);
	return true;
end

-- ============================================================================
-- Dead policy card repair (HANDOFF W15)
--
-- A base-game bug leaves slotted policy cards without their modifiers, mostly
-- when CultureAI re-commits its deck on a government-change turn. The card
-- stays slotted and does nothing until a later deck change moves it to another
-- slot; re-committing it in place never revived one. 25% of AI card-turns
-- were dead in a game without Rose (.scratch/game-test-20261007-vanilla).
--
-- GameEffects is UI-only, so the InGame audit finds the dead cards and
-- RoseAI.GetDeadPolicySlots passes them here. Each slot still holding a dead
-- card is cleared, and CultureAI fills the open slots at its next deck commit.
-- It commits only when a civic completes (in three test games no AI slotted a
-- card on any other turn), so the repair clears just before one: on the turn
-- the AI's own civic is due, or before a granted tree-fill civic. It never
-- clears before a civic that unlocks a government (government changes are
-- when cards die). In the 2026-10-08 test, clearing on other turns cut dead
-- card-turns to 5% (from 22%), and the refilled cards were alive.
-- POLICY_REPAIR_ON_COMMIT_TURN = false restores that tested timing (clear on
-- a turn without a commit; the next civic refills), in case cards removed and
-- re-added in one turn die again.
-- A card is cleared at most POLICY_REPAIR_MAX_ATTEMPTS times in a row, then
-- left alone for POLICY_REPAIR_BACKOFF_TURNS turns. The repair state is in
-- player properties (sorted strings), so every machine decides alike; like
-- the strength latches, it writes synchronized state (slot contents) from a
-- UI-context reading.
-- ============================================================================
local POLICY_REPAIR_ON_COMMIT_TURN = true;
local POLICY_REPAIR_MAX_ATTEMPTS = 3;
local POLICY_REPAIR_BACKOFF_TURNS = 10;
local POLICY_REPAIR_CLEAR_TURN = "ROSE_POLICY_REPAIR_CLEAR_TURN";
local POLICY_REPAIR_ATTEMPTS = "ROSE_POLICY_REPAIR_ATTEMPTS";

local function GetDeadPolicySlots(iPlayerID)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil or kBridge.GetDeadPolicySlots == nil then return nil; end
	local bOk, tDead = pcall(kBridge.GetDeadPolicySlots, iPlayerID);
	if not bOk or type(tDead) ~= "table" then return nil; end
	return tDead;
end

-- Per-card attempts as "POLICY_X=attempts@lastTurn" entries, with a trailing
-- "!" once the pause was printed; written sorted so the value is identical on
-- every machine.
local function ReadRepairAttempts(pPlayer)
	local tAttempts = {};
	local sValue = pPlayer:GetProperty(POLICY_REPAIR_ATTEMPTS);
	if type(sValue) == "string" then
		for sType, sCount, sLast, sFlag in string.gmatch(sValue, "([%w_]+)=(%d+)@(%-?%d+)(!?)") do
			tAttempts[sType] = { Attempts = tonumber(sCount), LastTurn = tonumber(sLast), Reported = sFlag == "!" };
		end
	end
	return tAttempts;
end

local function WriteRepairAttempts(pPlayer, tAttempts)
	local tParts = {};
	for sType, kTry in pairs(tAttempts) do
		table.insert(tParts, sType .. "=" .. kTry.Attempts .. "@" .. kTry.LastTurn
			.. (kTry.Reported and "!" or ""));
	end
	table.sort(tParts);
	pPlayer:SetProperty(POLICY_REPAIR_ATTEMPTS, table.concat(tParts, ";"));
end

-- sRefill names what refills the slots, for the log.
local function RepairDeadPolicies(iPlayerID, sRefill)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return false; end
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return false; end
	local iTurn = Game.GetCurrentGameTurn();
	if pPlayer:GetProperty(POLICY_REPAIR_CLEAR_TURN) == iTurn then return false; end

	local tDead = GetDeadPolicySlots(iPlayerID);
	if tDead == nil then return false; end

	local tAttempts = ReadRepairAttempts(pPlayer);
	local tDeadNow = {};
	for _, kDead in ipairs(tDead) do tDeadNow[kDead.PolicyType] = true; end
	for sPolicyType in pairs(tAttempts) do
		if not tDeadNow[sPolicyType] then tAttempts[sPolicyType] = nil; end
	end

	local iCleared = 0;
	for _, kDead in ipairs(tDead) do
		local kPolicy = GameInfo.Policies[kDead.PolicyType];
		local kTry = tAttempts[kDead.PolicyType];
		if kTry ~= nil and kTry.Attempts >= POLICY_REPAIR_MAX_ATTEMPTS then
			if iTurn - kTry.LastTurn >= POLICY_REPAIR_BACKOFF_TURNS then
				kTry.Attempts = 0;
				kTry.Reported = false;
			elseif not kTry.Reported then
				kTry.Reported = true;
				print("Rose AI: Policy repair paused for " .. kDead.PolicyType
					.. " for AI player " .. iPlayerID .. " turn " .. iTurn
					.. " after " .. kTry.Attempts .. " attempts; next try turn "
					.. (kTry.LastTurn + POLICY_REPAIR_BACKOFF_TURNS));
			end
		end
		-- Re-check the slot against gameplay data: the reading comes from the
		-- UI context and may be from earlier in the turn.
		if kPolicy ~= nil and type(kDead.Slot) == "number"
			and (kTry == nil or kTry.Attempts < POLICY_REPAIR_MAX_ATTEMPTS)
			and pCulture:GetSlotPolicy(kDead.Slot) == kPolicy.Index then
			local bOk, sError = pcall(function() pCulture:ClearPolicySlot(kDead.Slot); end);
			if bOk then
				if kTry == nil then
					kTry = { Attempts = 0, Reported = false };
					tAttempts[kDead.PolicyType] = kTry;
				end
				kTry.Attempts = kTry.Attempts + 1;
				kTry.LastTurn = iTurn;
				kTry.Reported = false;
				iCleared = iCleared + 1;
				print("Rose AI: Policy repair cleared dead " .. kDead.PolicyType
					.. " from slot " .. kDead.Slot .. " for AI player " .. iPlayerID
					.. " turn " .. iTurn .. " attempt " .. kTry.Attempts
					.. " missing modifiers " .. tostring(kDead.Missing));
			else
				print("Rose AI ERROR: Policy repair could not clear " .. kDead.PolicyType
					.. " slot " .. kDead.Slot .. " player " .. iPlayerID .. ": " .. tostring(sError));
			end
		end
	end
	WriteRepairAttempts(pPlayer, tAttempts);
	if iCleared == 0 then return false; end

	pPlayer:SetProperty(POLICY_REPAIR_CLEAR_TURN, iTurn);
	print("Rose AI: Policy repair for AI player " .. iPlayerID .. " turn " .. iTurn
		.. " cleared " .. iCleared .. " slots, refill by " .. sRefill);
	return true;
end

-- Repair dead cards, then grant at most one civic. The repair runs first so
-- that a grant's own deck commit can refill the cleared slots.
local function GrantCivicOrRepairPolicies(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();

	local iOwnCivic = GetOwnCivicDueThisTurn(pCulture);
	local bOwnCivicDue = iOwnCivic ~= nil;
	local iGrant, sGrantKind = FindCivicToGrant(pCulture);
	local bGrantDue = iGrant ~= nil and not bOwnCivicDue and not bGrantingCivic
		and pPlayer:GetProperty(CIVIC_GRANT_TURN_PROPERTY) ~= iTurn;

	local sRefill = nil;
	if POLICY_REPAIR_ON_COMMIT_TURN then
		if bOwnCivicDue then
			-- An unknown civic (fallback query) might unlock a government.
			if iOwnCivic >= 0 and not tGovernmentCivics[iOwnCivic] then
				sRefill = "its own civic " .. GetCivicTypeName(iOwnCivic) .. " this turn";
			end
		elseif bGrantDue and sGrantKind == "tree-fill" then
			sRefill = "the granted civic " .. GetCivicTypeName(iGrant) .. " this turn";
		end
	elseif not bOwnCivicDue and not bGrantDue then
		sRefill = "its next civic";
	end
	if sRefill ~= nil then
		local bOk, sError = pcall(RepairDeadPolicies, iPlayerID, sRefill);
		if not bOk then
			print("Rose AI ERROR: Policy repair failed player "
				.. tostring(iPlayerID) .. ": " .. tostring(sError));
		end
	end

	local bOk, sError = pcall(GrantOneCivic, iPlayerID, bOwnCivicDue);
	if not bOk then
		print("Rose AI ERROR: Civic grant failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
end

-- ============================================================================
-- Dynamic major-war strategy conditions
--
-- AI strategy conditions with ConditionFunction="Call Lua Function" invoke
-- the matching GameEvents callback with (player ID, threshold). Cache the
-- military context for one game turn because three strategies consume it.
-- Firaxis exposes military strength only to the InGame UI context, so
-- Rose_AI_InGame publishes the value through ExposedMembers.RoseAI.
-- ============================================================================

local tWarStrengthCache = {};
local tWarStrategyState = {};

local function GetMilitaryStrength(pPlayer)
	if pPlayer == nil then return 0, false; end
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil or kBridge.GetMilitaryStrength == nil then
		return 0, false;
	end
	local iStrength = kBridge.GetMilitaryStrength(pPlayer:GetID());
	if type(iStrength) ~= "number" then return 0, false; end
	return math.max(0, iStrength), true;
end

local function GetMajorWarContext(iPlayerID)
	local iTurn = Game.GetCurrentGameTurn();
	local kCached = tWarStrengthCache[iPlayerID];
	if kCached ~= nil and kCached.Turn == iTurn then
		return kCached.Wars, kCached.OurStrength, kCached.EnemyStrength,
			kCached.StrengthValid;
	end

	local pPlayer = Players[iPlayerID];
	local iWars = 0;
	local iEnemyStrength = 0;
	local iOurStrength, bStrengthValid = GetMilitaryStrength(pPlayer);
	if IsEligibleAIPlayer(pPlayer) then
		local pDiplomacy = pPlayer:GetDiplomacy();
		for _, pOther in ipairs(PlayerManager.GetAliveMajors()) do
			local iOtherID = pOther:GetID();
			if iOtherID ~= iPlayerID and pDiplomacy:IsAtWarWith(iOtherID) then
				iWars = iWars + 1;
				local iOtherStrength, bOtherStrengthValid =
					GetMilitaryStrength(pOther);
				iEnemyStrength = iEnemyStrength + iOtherStrength;
				bStrengthValid = bStrengthValid and bOtherStrengthValid;
			end
		end
	end

	tWarStrengthCache[iPlayerID] = {
		Turn = iTurn,
		Wars = iWars,
		OurStrength = iOurStrength,
		EnemyStrength = iEnemyStrength,
		StrengthValid = bStrengthValid
	};
	return iWars, iOurStrength, iEnemyStrength, bStrengthValid;
end

local function LogWarStrategyChange(
	iPlayerID, sStrategy, bActive, iWars, iOurStrength, iEnemyStrength,
	bStrengthValid)
	local sKey = tostring(iPlayerID) .. ":" .. sStrategy;
	if tWarStrategyState[sKey] == bActive then return; end
	tWarStrategyState[sKey] = bActive;
	print("Rose AI: War strategy " .. sStrategy
		.. " player " .. iPlayerID
		.. " active " .. tostring(bActive)
		.. " wars " .. iWars
		.. " strength " .. iOurStrength .. "/" .. iEnemyStrength
		.. " valid " .. tostring(bStrengthValid));
end

function RoseActiveStrategyAtWar(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0;
	LogWarStrategyChange(iPlayerID, "AT_WAR", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
end

-- Strength readings fluctuate by several percent from turn to turn. A Forbidden
-- condition ends a strategy at once and the engine then blocks re-adoption for
-- 20 turns, so a one-turn dip across the entry threshold must not release it.
-- Each strength strategy therefore enters at its threshold and releases at a
-- looser band. The bands do not overlap (85 < 110), so Recovery and Advantage
-- can never both be active.
--
-- The latch is a player property, saved with the game and identical on every
-- multiplayer machine, including after a rejoin. It is written only from the
-- synchronized PlayerTurnStarted hook; the strategy condition callbacks only
-- read it. An invalid strength reading (for example before the InGame bridge
-- has loaded after a reload) leaves the latch unchanged. The entry values
-- match the ThresholdValue columns in AI_Strategies.sql (70 and 125).
local RECOVERY_ENTER_PERCENT = 70;
local RECOVERY_RELEASE_PERCENT = 85;
local ADVANTAGE_ENTER_PERCENT = 125;
local ADVANTAGE_RELEASE_PERCENT = 110;
local RECOVERY_LATCH = "ROSE_MILITARY_RECOVERY_LATCH";
local ADVANTAGE_LATCH = "ROSE_WAR_ADVANTAGE_LATCH";

local function SetLatch(pPlayer, sProperty, bActive)
	local bWasActive = pPlayer:GetProperty(sProperty) == 1;
	if bActive ~= bWasActive then
		pPlayer:SetProperty(sProperty, bActive and 1 or 0);
	end
end

local function UpdateLatch(pPlayer, sProperty, bEnter, bHold)
	local bWasActive = pPlayer:GetProperty(sProperty) == 1;
	SetLatch(pPlayer, sProperty, bEnter or (bWasActive and bHold));
end

local function UpdateWarStrategyLatches(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not IsEligibleAIPlayer(pPlayer) then
		-- Clear any latch left from a period when this slot was an eligible AI.
		SetLatch(pPlayer, RECOVERY_LATCH, false);
		SetLatch(pPlayer, ADVANTAGE_LATCH, false);
		return;
	end
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	if iWars == 0 then
		SetLatch(pPlayer, RECOVERY_LATCH, false);
		SetLatch(pPlayer, ADVANTAGE_LATCH, false);
		return;
	end
	if not bStrengthValid then return; end
	if iEnemyStrength <= 0 then
		-- Opposing armies are gone: not weaker. Advantage keeps its state
		-- because a ratio cannot be computed.
		SetLatch(pPlayer, RECOVERY_LATCH, false);
		return;
	end
	local iOurScaled = iOurStrength * 100;
	UpdateLatch(pPlayer, RECOVERY_LATCH,
		iOurScaled < iEnemyStrength * RECOVERY_ENTER_PERCENT,
		iOurScaled < iEnemyStrength * RECOVERY_RELEASE_PERCENT);
	UpdateLatch(pPlayer, ADVANTAGE_LATCH,
		iOurScaled >= iEnemyStrength * ADVANTAGE_ENTER_PERCENT,
		iOurScaled >= iEnemyStrength * ADVANTAGE_RELEASE_PERCENT);
end

local function IsLatched(iPlayerID, sProperty)
	local pPlayer = Players[iPlayerID];
	return pPlayer ~= nil and pPlayer:GetProperty(sProperty) == 1;
end

function RoseActiveStrategyMilitaryRecovery(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0 and IsLatched(iPlayerID, RECOVERY_LATCH);
	LogWarStrategyChange(iPlayerID, "MILITARY_RECOVERY", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
end

function RoseActiveStrategyWarAdvantage(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0 and IsLatched(iPlayerID, ADVANTAGE_LATCH);
	LogWarStrategyChange(iPlayerID, "WAR_ADVANTAGE", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
end

-- The SQL conditions are Forbidden rows, so these callbacks answer "block this
-- strategy now?". A Forbidden condition ends the engine's 20-turn minimum hold
-- on the next evaluation. With no positive condition, an unanswered or failed
-- check would leave the strategy allowed, so any error forbids instead.
local function ForbidUnlessActive(fnActive, iPlayerID, iThreshold)
	local bOk, bActive = pcall(fnActive, iPlayerID, iThreshold);
	if not bOk then
		print("Rose AI ERROR: Strategy check failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(bActive));
		return true;
	end
	return bActive ~= true;
end

-- Filled in only after everything above has loaded; see RegisterForbidCallback.
tForbidStrategy.RoseForbidStrategyAtWar = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyAtWar, iPlayerID, iThreshold);
end
tForbidStrategy.RoseForbidStrategyMilitaryRecovery = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyMilitaryRecovery, iPlayerID, iThreshold);
end
tForbidStrategy.RoseForbidStrategyWarAdvantage = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyWarAdvantage, iPlayerID, iThreshold);
end

-- ============================================================================
-- Austerity latch
--
-- A modest income nudge for an AI whose treasury is running dry. It only
-- enables two strategies whose lists shift priorities toward income; it never
-- touches units, operations, or the treasury. Same latch layout as the war
-- strategies: player properties written only from PlayerTurnStarted, read by
-- the Forbidden condition callbacks. Entry and release bands are far apart so
-- the strategy does not flap against the engine's 20-turn hold and cooldown.
--
-- The Gold balance is read in gameplay; net income (gross Gold yield minus
-- total maintenance, as the top panel shows it) only through the InGame
-- bridge. An invalid income reading leaves the latch and counters unchanged.
-- The turn property stops a second PlayerTurnStarted in one game turn from
-- counting the same turn twice.
-- ============================================================================
local AUSTERITY_ENTER_BALANCE = 30;      -- enter below this balance
local AUSTERITY_ENTER_NEG_TURNS = 2;     -- after this many negative-income turns
local AUSTERITY_RELEASE_BALANCE = 100;   -- release above this balance
local AUSTERITY_RELEASE_POS_TURNS = 3;   -- after this many positive-income turns
-- An AI that keeps spending its Gold may never bank 100; sustained positive
-- income alone also releases, so the latch cannot stay on for good.
local AUSTERITY_RELEASE_SUSTAINED_POS_TURNS = 10;
local AUSTERITY_LATCH = "ROSE_AUSTERITY_LATCH";
local AUSTERITY_NEG_TURNS = "ROSE_AUSTERITY_NEG_TURNS";
local AUSTERITY_POS_TURNS = "ROSE_AUSTERITY_POS_TURNS";
local AUSTERITY_TURN = "ROSE_AUSTERITY_TURN";

local function GetNetGoldIncome(iPlayerID)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil or kBridge.GetNetGoldIncome == nil then return nil; end
	local iIncome = kBridge.GetNetGoldIncome(iPlayerID);
	if type(iIncome) ~= "number" or iIncome ~= iIncome then return nil; end
	return iIncome;
end

local function SetCounter(pPlayer, sProperty, iValue)
	local iOld = pPlayer:GetProperty(sProperty);
	if iOld ~= iValue and not (iOld == nil and iValue == 0) then
		pPlayer:SetProperty(sProperty, iValue);
	end
end

local function UpdateAusterityLatch(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not IsEligibleAIPlayer(pPlayer) then
		-- Clear any state left from a period when this slot was an eligible AI.
		SetLatch(pPlayer, AUSTERITY_LATCH, false);
		SetCounter(pPlayer, AUSTERITY_NEG_TURNS, 0);
		SetCounter(pPlayer, AUSTERITY_POS_TURNS, 0);
		return;
	end

	local iTurn = Game.GetCurrentGameTurn();
	if pPlayer:GetProperty(AUSTERITY_TURN) == iTurn then return; end

	local pTreasury = pPlayer:GetTreasury();
	local iBalance = pTreasury ~= nil and pTreasury:GetGoldBalance() or nil;
	local iIncome = GetNetGoldIncome(iPlayerID);
	if type(iBalance) ~= "number" or iIncome == nil then return; end

	local iNeg = iIncome < 0 and (pPlayer:GetProperty(AUSTERITY_NEG_TURNS) or 0) + 1 or 0;
	local iPos = iIncome > 0 and (pPlayer:GetProperty(AUSTERITY_POS_TURNS) or 0) + 1 or 0;
	pPlayer:SetProperty(AUSTERITY_TURN, iTurn);
	SetCounter(pPlayer, AUSTERITY_NEG_TURNS, iNeg);
	SetCounter(pPlayer, AUSTERITY_POS_TURNS, iPos);

	local bWasActive = pPlayer:GetProperty(AUSTERITY_LATCH) == 1;
	local bActive = bWasActive;
	if not bWasActive then
		bActive = iBalance < AUSTERITY_ENTER_BALANCE
			and iNeg >= AUSTERITY_ENTER_NEG_TURNS;
	else
		bActive = not ((iBalance > AUSTERITY_RELEASE_BALANCE
				and iPos >= AUSTERITY_RELEASE_POS_TURNS)
			or iPos >= AUSTERITY_RELEASE_SUSTAINED_POS_TURNS);
	end
	if bActive ~= bWasActive then
		SetLatch(pPlayer, AUSTERITY_LATCH, bActive);
		print("Rose AI: Austerity latch " .. (bActive and "entered" or "released")
			.. " player " .. iPlayerID
			.. " turn " .. iTurn
			.. " balance " .. math.floor(iBalance)
			.. " income " .. string.format("%.1f", iIncome)
			.. " negTurns " .. iNeg
			.. " posTurns " .. iPos);
	end
end

local tAusterityStrategyState = {};
local function LogAusterityStrategyChange(iPlayerID, sStrategy, bActive, iWars)
	local sKey = tostring(iPlayerID) .. ":" .. sStrategy;
	if tAusterityStrategyState[sKey] == bActive then return; end
	tAusterityStrategyState[sKey] = bActive;
	local pPlayer = Players[iPlayerID];
	print("Rose AI: Austerity strategy " .. sStrategy
		.. " player " .. iPlayerID
		.. " active " .. tostring(bActive)
		.. (iWars ~= nil and (" wars " .. iWars) or "")
		.. " latch " .. tostring(IsLatched(iPlayerID, AUSTERITY_LATCH))
		.. " negTurns " .. tostring(pPlayer ~= nil and pPlayer:GetProperty(AUSTERITY_NEG_TURNS) or nil)
		.. " posTurns " .. tostring(pPlayer ~= nil and pPlayer:GetProperty(AUSTERITY_POS_TURNS) or nil));
end

function RoseActiveStrategyAusterity(iPlayerID, iThreshold)
	local bActive = IsLatched(iPlayerID, AUSTERITY_LATCH);
	LogAusterityStrategyChange(iPlayerID, "AUSTERITY", bActive, nil);
	return bActive;
end

function RoseActiveStrategyAusterityAtWar(iPlayerID, iThreshold)
	local iWars = GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0 and IsLatched(iPlayerID, AUSTERITY_LATCH);
	LogAusterityStrategyChange(iPlayerID, "AUSTERITY_AT_WAR", bActive, iWars);
	return bActive;
end

-- Filled in only after everything above has loaded; see RegisterForbidCallback.
tForbidStrategy.RoseForbidStrategyAusterity = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyAusterity, iPlayerID, iThreshold);
end
tForbidStrategy.RoseForbidStrategyAusterityAtWar = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyAusterityAtWar, iPlayerID, iThreshold);
end

local function GetAliveCityOwners()
	local tPlayers = {};
	for _, pOther in ipairs(PlayerManager.GetAliveMajors()) do
		table.insert(tPlayers, pOther);
	end
	for _, pOther in ipairs(PlayerManager.GetAliveMinors()) do
		table.insert(tPlayers, pOther);
	end
	return tPlayers;
end

local function GetUnitInfo(pUnit)
	if pUnit == nil then return nil; end
	return GameInfo.Units[pUnit:GetType()];
end

local function UnitHasAiType(pUnit, sAiType)
	local kUnit = GetUnitInfo(pUnit);
	if kUnit == nil then return false; end
	local tTypes = tUnitAiTypes[kUnit.UnitType];
	return tTypes ~= nil and tTypes[sAiType] == true;
end

local function GetUnitOperationName(pUnit)
	if pUnit == nil or UnitManager.GetOperationTypeName == nil then return ""; end
	local sOperationName = UnitManager.GetOperationTypeName(pUnit);
	if sOperationName == nil then return ""; end
	return tostring(sOperationName);
end

local function IsUnitUncommitted(pUnit)
	local sOperationName = string.upper(GetUnitOperationName(pUnit));
	return sOperationName == ""
		or sOperationName == "NONE"
		or sOperationName == "NO OPERATION"
		or sOperationName == "NO_OPERATION"
		or sOperationName == "-1";
end

local function IsNavalCombatUnit(pUnit)
	local kUnit = GetUnitInfo(pUnit);
	return kUnit ~= nil
		and kUnit.FormationClass == "FORMATION_CLASS_NAVAL"
		and UnitHasAiType(pUnit, "UNITTYPE_NAVAL")
		and math.max(kUnit.Combat or 0, kUnit.RangedCombat or 0, kUnit.Bombard or 0) > 0;
end

local function HasActiveNavalOperation(pPlayer)
	for _, pUnit in pPlayer:GetUnits():Members() do
		if IsNavalCombatUnit(pUnit) then
			local sOperationName = string.lower(GetUnitOperationName(pUnit));
			if string.find(sOperationName, "naval superiority", 1, true) ~= nil
				or string.find(sOperationName, "naval_superiority", 1, true) ~= nil then
				return true;
			end
		end
	end
	return false;
end

-- ============================================================================
-- Naval superiority preflight
-- ============================================================================

local function GetAvailableNavalMeleeCombatUnits(pPlayer)
	local tUnits = {};
	for _, pUnit in pPlayer:GetUnits():Members() do
		-- Naval Superiority Force has one mandatory generic melee role. Seed a
		-- ship that satisfies it so the preflight cannot create another empty
		-- Galley/Caravel recruitment loop.
		if IsNavalCombatUnit(pUnit)
			and UnitHasAiType(pUnit, "UNITTYPE_MELEE")
			and IsUnitUncommitted(pUnit) then
			table.insert(tUnits, pUnit);
		end
	end
	return tUnits;
end

local function FindNavalSuperiorityTarget(iPlayerID)
	local pPlayer = Players[iPlayerID];
	local pDiplomacy = pPlayer:GetDiplomacy();
	local pVisibility = PlayersVisibility ~= nil
		and PlayersVisibility[iPlayerID] or nil;
	local tFriendlyShips = GetAvailableNavalMeleeCombatUnits(pPlayer);
	if #tFriendlyShips == 0 or pVisibility == nil then
		return nil, nil, -1, nil;
	end

	local pBestTargetPlot = nil;
	local pBestShip = nil;
	local pBestTargetUnit = nil;
	local iBestOwner = -1;
	local iBestDistance = NAVAL_SUPERIORITY_MAX_DISTANCE + 1;
	for _, pOther in ipairs(GetAliveCityOwners()) do
		local iOtherID = pOther:GetID();
		if iOtherID ~= iPlayerID and pDiplomacy:IsAtWarWith(iOtherID) then
			for _, pEnemyUnit in pOther:GetUnits():Members() do
				-- Gameplay Lua can enumerate hidden enemy units. Require current
				-- visibility so the behavior tree's naval target selector can
				-- independently recognize the same ship on its first tick.
				if IsNavalCombatUnit(pEnemyUnit)
					and pVisibility:IsVisible(
						pEnemyUnit:GetX(), pEnemyUnit:GetY()) then
					for _, pShip in ipairs(tFriendlyShips) do
						local iDistance = Map.GetPlotDistance(
							pShip:GetX(), pShip:GetY(),
							pEnemyUnit:GetX(), pEnemyUnit:GetY());
						if iDistance < iBestDistance then
							iBestDistance = iDistance;
							pBestTargetPlot = Map.GetPlot(
								pEnemyUnit:GetX(), pEnemyUnit:GetY());
							pBestShip = pShip;
							pBestTargetUnit = pEnemyUnit;
							iBestOwner = iOtherID;
						end
					end
				end
			end
		end
	end
	return pBestTargetPlot, pBestShip, iBestOwner, pBestTargetUnit;
end

local function TryStartNavalSuperiority(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	if HasActiveNavalOperation(pPlayer) then return; end

	local iTurn = Game.GetCurrentGameTurn();
	local iNextAttempt = pPlayer:GetProperty(
		NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY);
	if iNextAttempt ~= nil and iTurn < iNextAttempt then return; end

	local pTargetPlot, pShip, iTargetOwner, pTargetUnit =
		FindNavalSuperiorityTarget(iPlayerID);
	if pTargetPlot == nil or pShip == nil or iTargetOwner < 0 or pTargetUnit == nil then
		pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
			iTurn + NAVAL_SUPERIORITY_FAILURE_RETRY);
		return;
	end
	local pMilitaryAI = pPlayer:GetAi_Military();
	local pRallyPlot = Map.GetPlot(pShip:GetX(), pShip:GetY());
	if pMilitaryAI == nil or pRallyPlot == nil then return; end

	print("Rose AI: Attempting naval superiority for player " .. iPlayerID
		.. " against player " .. iTargetOwner
		.. " target plot " .. pTargetPlot:GetIndex()
		.. " target unit " .. pTargetUnit:GetID()
		.. " with ship " .. pShip:GetID());
	local iOperationID = pMilitaryAI:StartScriptedOperationWithTargetAndRally(
		"Naval Superiority",
		iTargetOwner,
		pTargetPlot:GetIndex(),
		pRallyPlot:GetIndex());
	if iOperationID ~= nil and iOperationID >= 0 then
		pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
			iTurn + NAVAL_SUPERIORITY_SUCCESS_COOLDOWN);
		local bAdded = pMilitaryAI:AddUnitToScriptedOperation(
			iOperationID, pShip:GetID());
		print("Rose AI: Started naval superiority for player " .. iPlayerID
			.. " operation " .. iOperationID
			.. " assigned ship " .. pShip:GetID()
			.. " add result " .. tostring(bAdded)
			.. " unit operation " .. GetUnitOperationName(pShip));
	else
		pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
			iTurn + NAVAL_SUPERIORITY_FAILURE_RETRY);
		print("Rose AI: Naval superiority start rejected for player "
			.. iPlayerID .. " result " .. tostring(iOperationID));
	end
end

-- ============================================================================
-- Stuck Trader diagnostic (HANDOFF W14 item 2). Print-only.
--
-- AI Traders have sat in a city for many turns logging "Can't Start" on
-- MAKE_TRADE_ROUTE. The unit operation's CanStart also checks moves remaining
-- and the unit's operation queue, which the route planner skips. For each
-- eligible AI's Trader that has been on the same plot for at least
-- TRADER_STREAK_REPORT consecutive turn starts, print one line per hook call
-- with its moves and the city on its plot, plus route/activity details from
-- the InGame bridge (those queries are only verified in UI scripts). Print
-- once when such a streak ends. The streak table is local and is not saved,
-- so streaks restart after a reload.
-- ============================================================================
local TRADER_STREAK_REPORT = 3;
local tTraderUnitTypes = {};
for kUnit in GameInfo.Units() do
	if kUnit.MakeTradeRoute == true or kUnit.MakeTradeRoute == 1 then
		tTraderUnitTypes[kUnit.Index] = true;
	end
end
local tTraderStreaks = {};

local function DescribePlotCity(iX, iY)
	local pCity = CityManager.GetCityAt(iX, iY);
	if pCity == nil then return "none"; end
	return tostring(pCity:GetOwner()) .. "/" .. tostring(pCity:GetID())
		.. "/" .. tostring(pCity:GetName());
end

local function GetTraderBridgeDetails(iPlayerID, iUnitID, iX, iY)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil or kBridge.GetTraderDiagnostics == nil then return "bridge n/a"; end
	local bOk, sDetails = pcall(kBridge.GetTraderDiagnostics, iPlayerID, iUnitID, iX, iY);
	if not bOk then return "bridge error " .. tostring(sDetails); end
	return tostring(sDetails);
end

local function LogTraderStreak(iPlayerID, iTurn, sHook, pUnit, kStreak)
	local iX, iY = pUnit:GetX(), pUnit:GetY();
	print("Rose AI: Trader stuck player " .. iPlayerID
		.. " turn " .. iTurn
		.. " hook " .. sHook
		.. " unit " .. pUnit:GetID()
		.. " plot " .. iX .. "," .. iY
		.. " city " .. DescribePlotCity(iX, iY)
		.. " moves " .. tostring(pUnit:GetMovesRemaining())
		.. "/" .. tostring(pUnit:GetMaxMoves())
		.. " streak " .. kStreak.Streak
		.. " operation " .. GetUnitOperationName(pUnit)
		.. " " .. GetTraderBridgeDetails(iPlayerID, pUnit:GetID(), iX, iY));
end

local function LogTraderStreakEnd(iPlayerID, iTurn, sHook, iUnitID, kStreak, sReason)
	print("Rose AI: Trader streak ended player " .. iPlayerID
		.. " turn " .. iTurn
		.. " hook " .. sHook
		.. " unit " .. iUnitID
		.. " plot " .. kStreak.X .. "," .. kStreak.Y
		.. " streak " .. kStreak.Streak
		.. " reason " .. sReason);
end

local function UpdateTraderStreaks(iPlayerID, sHook)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then
		tTraderStreaks[iPlayerID] = nil;
		return;
	end
	local iTurn = Game.GetCurrentGameTurn();
	local tStreaks = tTraderStreaks[iPlayerID];
	if tStreaks == nil then
		tStreaks = {};
		tTraderStreaks[iPlayerID] = tStreaks;
	end

	local tSeen = {};
	for _, pUnit in pPlayer:GetUnits():Members() do
		if tTraderUnitTypes[pUnit:GetType()] == true then
			local iUnitID = pUnit:GetID();
			local iX, iY = pUnit:GetX(), pUnit:GetY();
			tSeen[iUnitID] = true;
			local kStreak = tStreaks[iUnitID];
			if kStreak ~= nil and (kStreak.X ~= iX or kStreak.Y ~= iY) then
				if kStreak.Streak >= TRADER_STREAK_REPORT then
					LogTraderStreakEnd(iPlayerID, iTurn, sHook, iUnitID, kStreak, "moved");
				end
				kStreak = nil;
			end
			if kStreak == nil then
				kStreak = { X = iX, Y = iY, Streak = 1, Turn = iTurn, Printed = {} };
				tStreaks[iUnitID] = kStreak;
			elseif kStreak.Turn ~= iTurn then
				-- Count each game turn once, however many hooks fire in it.
				kStreak.Streak = kStreak.Streak + 1;
				kStreak.Turn = iTurn;
			end
			if kStreak.Streak >= TRADER_STREAK_REPORT and kStreak.Printed[sHook] ~= iTurn then
				kStreak.Printed[sHook] = iTurn;
				LogTraderStreak(iPlayerID, iTurn, sHook, pUnit, kStreak);
			end
		end
	end
	for iUnitID, kStreak in pairs(tStreaks) do
		if not tSeen[iUnitID] then
			if kStreak.Streak >= TRADER_STREAK_REPORT then
				LogTraderStreakEnd(iPlayerID, iTurn, sHook, iUnitID, kStreak, "gone");
			end
			tStreaks[iUnitID] = nil;
		end
	end
end

local function RunTraderDiagnostic(iPlayerID, sHook)
	if not ROSE_VERBOSE_LOGS then return; end
	local bOk, sError = pcall(UpdateTraderStreaks, iPlayerID, sHook);
	if not bOk then
		print("Rose AI ERROR: Trader diagnostic failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
end

-- Update latches, then grant at most one ready civic or repair dead policy
-- cards.
function OnPlayerTurnStarted(iPlayerID)
	local bOk, sError = pcall(UpdateWarStrategyLatches, iPlayerID);
	if not bOk then
		print("Rose AI ERROR: War strategy latch update failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
	bOk, sError = pcall(UpdateAusterityLatch, iPlayerID);
	if not bOk then
		print("Rose AI ERROR: Austerity latch update failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
	bOk, sError = pcall(GrantCivicOrRepairPolicies, iPlayerID);
	if not bOk then
		print("Rose AI ERROR: Civic grant or policy repair failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
	RunTraderDiagnostic(iPlayerID, "PlayerTurnStarted");
end

-- Firaxis' Nubia scenario starts scripted military operations from this hook.
-- Starting them inside PlayerTurnStarted can re-enter native AI initialization.
function OnPlayerTurnStartComplete(iPlayerID)
	RunTraderDiagnostic(iPlayerID, "PlayerTurnStartComplete");
	TryStartNavalSuperiority(iPlayerID);
end

GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);
GameEvents.PlayerTurnStartComplete.Add(OnPlayerTurnStartComplete);

print("Rose AI: Gameplay support script loaded");
