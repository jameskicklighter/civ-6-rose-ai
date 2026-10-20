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
-- changes government at most once per turn. The civic the AI is researching,
-- or has started, is never granted: granting it froze the AI's civic research
-- for the rest of the game (HANDOFF W19). An AI found frozen that way (an
-- owned civic in progress, from an earlier save) is moved to another civic.
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
--    - An AI major that holds a nuclear device and has fought a major for a
--      few turns starts Rose's one-unit Nuclear Strike operation against an
--      enemy city in range of a delivery unit (HANDOFF Plan E, W20).
--
-- 5. Dead policy card repair: a base-game bug leaves slotted cards without
--    their effects. Slots holding such cards (found by the InGame audit) are
--    cleared at the AI's turn start, just before a civic completion that
--    makes CultureAI slot its cards again.
-- ============================================================================

print("Rose AI: Loading gameplay support script");

-- Per-turn diagnostic output (the stuck Trader lines). Off for release; errors,
-- grants, strategy and austerity changes and policy repairs always print.
local ROSE_VERBOSE_LOGS = true;

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

-- Government civics in tGovtCivics order that are missing and whose prereqs
-- are all owned. A grant made this turn may make the next entry ready (e.g.
-- Divine Right → Reformed Church); it is granted next turn.
local function GetReadyGovtCivics(pCulture)
	local tReady = {};
	for _, entry in ipairs(tGovtCivics) do
		if not pCulture:HasCivic(entry.civic) then
			local bAllMet = true;
			for _, iPrereq in ipairs(entry.prereqs) do
				if not pCulture:HasCivic(iPrereq) then
					bAllMet = false;
					break;
				end
			end
			if bAllMet then table.insert(tReady, entry.civic); end
		end
	end
	return tReady;
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
-- Never grant the civic in progress (HANDOFF W19). SetCivic on it leaves it
-- in progress although owned: its culture goes nowhere and the AI never
-- completes another civic. In .scratch/game-test-20261009 all eight AIs
-- stopped for good right after a grant: Mapuche at turn 50, the rest in the
-- tier-3 and tier-4 cascades, where the AI picks the next government civic
-- itself between two grants and the following grant lands on it. Nothing is
-- granted when the civic in progress cannot be read. Other civics with
-- culture in them are still granted: Inspirations add culture to civics not
-- in progress, and in that game the AIs given boosted Mysticism, Theology and
-- Divine Right kept researching.
--
-- Until 2026-10-09 a grant waited a turn when the AI's own civic completed
-- that turn, to spare CultureAI a second deck commit (HANDOFF W15). That
-- timed most grants just after the AI had picked its next civic, often the
-- one Rose was about to grant, and a frozen AI waited every turn (58 times
-- for Mongolia). It was removed; a grant and the AI's own completion can
-- again fall on one turn (2 such turns in 200 in that game).
-- ============================================================================
local CIVIC_GRANT_TURN_PROPERTY = "ROSE_CIVIC_GRANT_TURN";
local CIVIC_GRANT_SKIP_PROPERTY = "ROSE_CIVIC_GRANT_SKIP";
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

-- The civic in progress: its index, -1 or less when none, nil when it
-- cannot be read.
local function ReadProgressingCivic(pCulture)
	local bOk, iCivic = pcall(function() return pCulture:GetProgressingCivic(); end);
	if not bOk or type(iCivic) ~= "number" then return nil; end
	return iCivic;
end

-- True when the civic in progress is one the AI already owns (a repeatable
-- civic such as the Future Civic is owned while it is researched again).
local function IsOwnedCivicInProgress(pCulture, iCivic)
	if iCivic == nil or iCivic < 0 then return false; end
	local kCivic = GameInfo.Civics[iCivic];
	return kCivic ~= nil and not kCivic.Repeatable and pCulture:HasCivic(iCivic);
end

-- The civic in progress when it should complete this turn (one turn or less
-- to go, as the civics tree shows it; AI_GovtPolicies.csv shows 1 on the turn
-- before each completion), otherwise nil. Also nil when nothing is in
-- progress, when the civic in progress is already owned (it never completes)
-- or when the query fails; a failure of both queries is printed once, since
-- the repair then never runs on the AI's own civic.
local bCivicQueryWarned = false;
local function GetOwnCivicDueThisTurn(pCulture)
	local iCivic = nil;
	local bOk, iTurnsLeft = pcall(function()
		iCivic = pCulture:GetProgressingCivic();
		if type(iCivic) ~= "number" or iCivic < 0 then return nil; end
		if IsOwnedCivicInProgress(pCulture, iCivic) then return nil; end
		return pCulture:GetTurnsToProgressCivic(iCivic);
	end);
	if not bOk then
		bOk, iTurnsLeft = pcall(function() return pCulture:GetTurnsLeftOnCurrentCivic(); end);
		if not bOk and not bCivicQueryWarned then
			bCivicQueryWarned = true;
			print("Rose AI ERROR: Civic progress queries failed; the policy repair will not run on the AI's own civic: "
				.. tostring(iTurnsLeft));
		end
	end
	if not bOk or type(iTurnsLeft) ~= "number" or iTurnsLeft < 0 or iTurnsLeft > 1 then return nil; end
	if type(iCivic) ~= "number" or iCivic < 0 then return -1; end -- due, civic unknown (fallback)
	return iCivic;
end

-- The civic Rose would grant now and its kind, or nil; also the first civic
-- passed over (the civic in progress), its kind and why, for the log.
local function FindCivicToGrant(pCulture, iProgressing)
	local kSkip = nil;
	local function Allowed(iCivic, sKind)
		if iCivic ~= iProgressing then return true; end
		if kSkip == nil then kSkip = { Civic = iCivic, Kind = sKind, Reason = "in progress" }; end
		return false;
	end
	for _, iCivic in ipairs(GetReadyGovtCivics(pCulture)) do
		if Allowed(iCivic, "government") then return iCivic, "government", kSkip; end
	end
	-- Tree-fill civics are granted in prerequisite order, so a skipped one
	-- holds back the rest.
	local iCivic = FindTreeFillCivic(pCulture);
	if iCivic ~= nil and Allowed(iCivic, "tree-fill") then return iCivic, "tree-fill", kSkip; end
	return nil, nil, kSkip;
end

-- Prints a skipped grant when the skipped civic or the reason changes.
local function ReportGrantSkip(pPlayer, iPlayerID, iTurn, kSkip)
	local sState = kSkip ~= nil and (kSkip.Civic .. ":" .. kSkip.Reason) or "";
	if (pPlayer:GetProperty(CIVIC_GRANT_SKIP_PROPERTY) or "") == sState then return; end
	pPlayer:SetProperty(CIVIC_GRANT_SKIP_PROPERTY, sState);
	if kSkip ~= nil then
		print("Rose AI: Skipped " .. kSkip.Kind .. " civic " .. GetCivicTypeName(kSkip.Civic)
			.. " for AI player " .. iPlayerID .. " turn " .. iTurn .. ": " .. kSkip.Reason);
	end
end

local bProgressingWarned = false;
local function GrantOneCivic(iPlayerID)
	if bGrantingCivic then return false; end
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return false; end

	local iTurn = Game.GetCurrentGameTurn();
	if pPlayer:GetProperty(CIVIC_GRANT_TURN_PROPERTY) == iTurn then return false; end

	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return false; end

	local iProgressing = ReadProgressingCivic(pCulture);
	if iProgressing == nil then
		if not bProgressingWarned then
			bProgressingWarned = true;
			print("Rose AI ERROR: Civic in progress could not be read; no civic is granted");
		end
		return false;
	end

	local iCivic, sKind, kSkip = FindCivicToGrant(pCulture, iProgressing);
	ReportGrantSkip(pPlayer, iPlayerID, iTurn, kSkip);
	if iCivic == nil then return false; end

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
-- Frozen civic research (HANDOFF W19)
--
-- An AI given its civic in progress by an earlier Rose version keeps that
-- owned civic in progress and never completes another. Found that way on two
-- consecutive turn starts, the AI is moved to the cheapest civic it can
-- research (SetProgressingCivic, the gameplay call the Black Death scenario
-- uses for each player's starting civic, BlackDeathScenario.lua:189);
-- CultureAI chooses freely again once that civic completes (all eight frozen
-- AIs of the 20261009 save took it and kept researching, game 20261009b).
-- After CIVIC_UNFREEZE_MAX_ATTEMPTS turns on the same owned civic it gives up.
-- A civic in progress that stays due (one turn or less) without completing for
-- CIVIC_STALL_REPORT_TURNS turn starts is reported, not changed.
-- State in player properties: "civic@attempts@lastTurn" and
-- "civic@count@lastTurn".
-- ============================================================================
local CIVIC_UNFREEZE_MAX_ATTEMPTS = 3;
local CIVIC_STALL_REPORT_TURNS = 3;
local CIVIC_UNFREEZE_PROPERTY = "ROSE_CIVIC_UNFREEZE";
local CIVIC_STALL_PROPERTY = "ROSE_CIVIC_STALL";

local tCivicPrereqs = {};
for kRow in GameInfo.CivicPrereqs() do
	local kCivic = GameInfo.Civics[kRow.Civic];
	local kPrereq = GameInfo.Civics[kRow.PrereqCivic];
	if kCivic ~= nil and kPrereq ~= nil then
		local tList = tCivicPrereqs[kCivic.Index];
		if tList == nil then
			tList = {};
			tCivicPrereqs[kCivic.Index] = tList;
		end
		table.insert(tList, kPrereq.Index);
	end
end

-- The cheapest civic (base cost, then table order) the AI does not own and
-- whose prerequisites it owns, or nil.
local function FindCivicToResearch(pCulture)
	local iBest, iBestCost = nil, nil;
	for kCivic in GameInfo.Civics() do
		if not kCivic.Repeatable and not pCulture:HasCivic(kCivic.Index) then
			local bReady = true;
			for _, iPrereq in ipairs(tCivicPrereqs[kCivic.Index] or {}) do
				if not pCulture:HasCivic(iPrereq) then
					bReady = false;
					break;
				end
			end
			local iCost = kCivic.Cost or 0;
			if bReady and (iBestCost == nil or iCost < iBestCost) then
				iBest, iBestCost = kCivic.Index, iCost;
			end
		end
	end
	return iBest;
end

local function DescribeCivicProgress(pCulture, iCivic)
	local function Read(fnRead)
		local bOk, value = pcall(fnRead);
		return (bOk and value ~= nil) and tostring(value) or "?";
	end
	return "progress " .. Read(function() return pCulture:GetCulturalProgress(iCivic); end)
		.. "/" .. Read(function() return pCulture:GetCultureCost(iCivic); end)
		.. " turns " .. Read(function() return pCulture:GetTurnsToProgressCivic(iCivic); end)
		.. " culture " .. Read(function() return pCulture:GetCultureYield(); end);
end

local function ClearProperty(pPlayer, sProperty)
	if pPlayer:GetProperty(sProperty) ~= nil then pPlayer:SetProperty(sProperty, nil); end
end

-- Fields of a "a@b@c" property as numbers (missing fields are nil).
local function ReadNumberFields(value)
	local tFields = {};
	if type(value) == "string" then
		for sField in string.gmatch(value, "[^@]+") do table.insert(tFields, tonumber(sField)); end
	end
	return tFields;
end

local function UnfreezeCivicResearch(pPlayer, iPlayerID, pCulture, iTurn, iFrozen)
	local tState = ReadNumberFields(pPlayer:GetProperty(CIVIC_UNFREEZE_PROPERTY));
	if tState[1] == iFrozen and tState[3] == iTurn then return; end -- already handled this turn
	if tState[1] ~= iFrozen then
		-- First sighting: wait one turn start, in case the AI is only between
		-- a completion and its next pick. The record is cleared at any turn
		-- start that finds a civic the AI does not own in progress.
		pPlayer:SetProperty(CIVIC_UNFREEZE_PROPERTY, iFrozen .. "@0@" .. iTurn);
		return;
	end
	local iAttempts = tState[2] or 0;
	if iAttempts >= CIVIC_UNFREEZE_MAX_ATTEMPTS then return; end
	iAttempts = iAttempts + 1;
	pPlayer:SetProperty(CIVIC_UNFREEZE_PROPERTY, iFrozen .. "@" .. iAttempts .. "@" .. iTurn);

	local sHead = "Civic research frozen for AI player " .. iPlayerID .. " turn " .. iTurn
		.. ": " .. GetCivicTypeName(iFrozen) .. " in progress is already owned ("
		.. DescribeCivicProgress(pCulture, iFrozen) .. ")";
	local iNext = FindCivicToResearch(pCulture);
	if iNext == nil then
		pPlayer:SetProperty(CIVIC_UNFREEZE_PROPERTY, iFrozen .. "@" .. CIVIC_UNFREEZE_MAX_ATTEMPTS .. "@" .. iTurn);
		print("Rose AI: " .. sHead .. "; no civic left to research");
		return;
	end
	local bOk, sError = pcall(function() pCulture:SetProgressingCivic(iNext); end);
	local iNow = ReadProgressingCivic(pCulture);
	if bOk and iNow == iNext then
		print("Rose AI: " .. sHead .. "; set " .. GetCivicTypeName(iNext) .. " in progress");
		return;
	end
	print("Rose AI ERROR: " .. sHead .. "; setting " .. GetCivicTypeName(iNext)
		.. " in progress failed, attempt " .. iAttempts .. " of " .. CIVIC_UNFREEZE_MAX_ATTEMPTS .. ": "
		.. (bOk and ("in progress now " .. tostring(iNow)) or tostring(sError)));
end

local function ReportStalledCivic(pPlayer, iPlayerID, pCulture, iTurn, iCivic)
	local bOk, iTurnsLeft = pcall(function() return pCulture:GetTurnsToProgressCivic(iCivic); end);
	if not bOk or type(iTurnsLeft) ~= "number" or iTurnsLeft < 0 or iTurnsLeft > 1 then
		ClearProperty(pPlayer, CIVIC_STALL_PROPERTY);
		return;
	end
	local tState = ReadNumberFields(pPlayer:GetProperty(CIVIC_STALL_PROPERTY));
	local iCount = 1;
	if tState[1] == iCivic and tState[3] == iTurn then
		return; -- second turn start in the same turn
	elseif tState[1] == iCivic and tState[3] == iTurn - 1 then
		iCount = (tState[2] or 0) + 1;
	end
	pPlayer:SetProperty(CIVIC_STALL_PROPERTY, iCivic .. "@" .. iCount .. "@" .. iTurn);
	if iCount == CIVIC_STALL_REPORT_TURNS then
		print("Rose AI ERROR: Civic research stalled for AI player " .. iPlayerID .. " turn " .. iTurn
			.. ": " .. GetCivicTypeName(iCivic) .. " due on " .. iCount .. " turn starts without completing ("
			.. DescribeCivicProgress(pCulture, iCivic) .. ")");
	end
end

local function CheckCivicResearch(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local iCivic = ReadProgressingCivic(pCulture);
	if iCivic == nil or iCivic < 0 then
		ClearProperty(pPlayer, CIVIC_STALL_PROPERTY);
		return;
	end
	if IsOwnedCivicInProgress(pCulture, iCivic) then
		UnfreezeCivicResearch(pPlayer, iPlayerID, pCulture, iTurn, iCivic);
		return;
	end
	ClearProperty(pPlayer, CIVIC_UNFREEZE_PROPERTY);
	ReportStalledCivic(pPlayer, iPlayerID, pCulture, iTurn, iCivic);
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

-- Unfreeze civic research if needed, repair dead cards, then grant at most
-- one civic. The repair runs before the grant so that a grant's own deck
-- commit can refill the cleared slots; it is skipped when a government civic
-- is granted this turn (government changes are when cards die).
local function GrantCivicOrRepairPolicies(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();

	local bCheckOk, sCheckError = pcall(CheckCivicResearch, iPlayerID);
	if not bCheckOk then
		print("Rose AI ERROR: Civic research check failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sCheckError));
	end

	local iOwnCivic = GetOwnCivicDueThisTurn(pCulture);
	local bOwnCivicDue = iOwnCivic ~= nil;
	local iProgressing = ReadProgressingCivic(pCulture);
	local iGrant, sGrantKind = nil, nil;
	if iProgressing ~= nil then iGrant, sGrantKind = FindCivicToGrant(pCulture, iProgressing); end
	local bGrantDue = iGrant ~= nil and not bGrantingCivic
		and pPlayer:GetProperty(CIVIC_GRANT_TURN_PROPERTY) ~= iTurn;

	local sRefill = nil;
	if POLICY_REPAIR_ON_COMMIT_TURN then
		if bGrantDue and sGrantKind == "government" then
			-- No repair: the grant may change the government this turn.
		elseif bOwnCivicDue then
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

	local bOk, sError = pcall(GrantOneCivic, iPlayerID);
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
-- Scripted nuclear strike (HANDOFF Plan E, rebuilt for W20)
--
-- Starts Rose's own "Rose Nuclear Strike" operation (AI_BehaviorTrees.xml):
-- one delivery unit, no Recruit node, the target fixed. The engine's Nuclear
-- Assault fires every delivery unit its team holds, and its recruit pass
-- takes several (two devices on one city in one tick in the 20261009b game),
-- so each Rose order is one launch on a city Rose chose. The engine's
-- Nuclear Assault is off (it took the unit Rose had added in 20261009b;
-- AI_BehaviorTrees.xml). A scripted start only passes the OP_NUCLEAR slot
-- check (limit 2).
-- The sequence follows Firaxis' Nubia scenario (NubiaScenario.lua 628-658):
-- start the operation with the target owner, the target city's plot and a
-- rally plot, then add the delivery unit. The operation's tree tests "Will
-- use nukes" every turn and launches; the node passes for an enemy with a
-- negative war value, one that nuked us, or for an AI that favors the
-- use-nukes action (Gandhi, aggressive-military leaders, and every AI while
-- STRATEGY_ROSE_AT_WAR is active, W22); otherwise the operation ends on its
-- first turn (visible only in AI_Operation.csv). Lua cannot read the war
-- value, so enemies we already run an operation against (HasOperationAgainst,
-- the existence form since round 9) come first: both launches in 20261009b
-- matched one.
--
-- Gameplay Lua cannot read which AI operation holds a unit, an operation's
-- target, or whether it is still running (UnitManager.GetOperationTypeName
-- returns the unit's current command, not its AI operation). So:
-- - An order whose launch has not been seen blocks new orders for
--   NUCLEAR_PENDING_TURNS turns while its unit is alive (the operation may
--   still hold it). Every launch so far came on the order turn and the
--   operation's Turn Limiter ends it after about 2 turns, so an order with no
--   launch by the third turn start has failed: it is reported then and its
--   unit is free for the next order (W22; until then a failed order's unit
--   stayed out until a launch was seen, which locked out an AI whose only
--   delivery unit it was).
--   NUCLEAR_ATTEMPT_COOLDOWN follows any order or refused start; a launch on
--   the ordered plot replaces it with NUCLEAR_LAUNCH_COOLDOWN (other launches
--   only extend it); the OP_NUCLEAR limit caps the rest ("start rejected").
-- - An aircraft is used only while the AI holds NUCLEAR_MIN_AIRCRAFT
--   WMD-capable aircraft (counting that unit), because the one taken may
--   be a siege's only bomber (Nuclear Submarines never fill a siege's strike
--   role).
-- - The city our army is attacking is approximated by our land combat units
--   in a ring just outside the safety distance (below).
-- - Launches come from the engine's detonation event (a gameplay event); a
--   drop in the device count larger than the events seen is reported and
--   counted as well.
--
-- Gates (gameplay-side reads only, so every machine decides alike): an
-- eligible AI that holds a device, has been at war with a major for
-- NUCLEAR_MIN_WAR_TURNS turn starts, has no pending order and is past its
-- cooldown. Delivery: a WMD-capable unit within range of the target and
-- outside the blast: an aircraft's Units.Range (whether the operation's Move
-- node rebases aircraft is unverified); a Nuclear Submarine's Units.Range is
-- 2, so it uses the ICBM strike range of the largest device held (12 or 15,
-- unverified for submarines). Targets: revealed city centres of those
-- majors, never city-states; enemies with an operation of ours against them
-- first. The launch can come turns after the order, so the check keeps a
-- margin: no other unit of ours
-- within the blast radius of the largest device held plus
-- NUCLEAR_UNIT_MARGIN, and no city of ours or of anyone but a major we are at
-- war with inside the largest blast radius of any device type (a bigger
-- device may be ready by the launch). Among those cities, the one with the most
-- of our land combat units within NUCLEAR_SIEGE_RING tiles beyond the margin
-- comes first, then the most populous.
-- Pacing (2026-10-09): a refused or unfired order is not repeated for
-- NUCLEAR_ATTEMPT_COOLDOWN turns, a launch for NUCLEAR_LAUNCH_COOLDOWN (1: the
-- operation ends on its launch turn, so the next order may follow on the next
-- turn); the device count, the delivery rule, the slot limit, war weariness
-- and the World Congress do the rest. A city the AI itself nuked within
-- NUCLEAR_RECENT_TURNS turns is not a target, so a stockpile is spread over
-- the enemy's cities instead of landing twice on one (2026-10-09).
-- ============================================================================
local NUCLEAR_STRIKE_ENABLED = true;
local NUCLEAR_OPERATION_NAME = "Rose Nuclear Strike";
local NUCLEAR_MIN_WAR_TURNS = 5;
local NUCLEAR_ATTEMPT_COOLDOWN = 3;
local NUCLEAR_LAUNCH_COOLDOWN = 1;
local NUCLEAR_PENDING_TURNS = 3;
local NUCLEAR_REPORT_TURNS = 3;
local NUCLEAR_RECENT_TURNS = 10;
local NUCLEAR_MIN_AIRCRAFT = 2;
local NUCLEAR_UNIT_MARGIN = 2;
local NUCLEAR_SIEGE_RING = 2;

local NUCLEAR_WAR_SINCE_PROPERTY = "ROSE_NUCLEAR_WAR_SINCE";
local NUCLEAR_STRIKE_PROPERTY = "ROSE_NUCLEAR_STRIKE";
local NUCLEAR_NEXT_ATTEMPT_PROPERTY = "ROSE_NUCLEAR_NEXT_ATTEMPT";
local NUCLEAR_DEVICES_PROPERTY = "ROSE_NUCLEAR_DEVICES";
local NUCLEAR_DETONATIONS_PROPERTY = "ROSE_NUCLEAR_DETONATIONS";
local NUCLEAR_RECENT_PROPERTY = "ROSE_NUCLEAR_RECENT";

local tWMDTypes = {};
local iMaxBlastRadius = 0;
if GameInfo.WMDs ~= nil then
	for kWMD in GameInfo.WMDs() do
		table.insert(tWMDTypes, { Index = kWMD.Index, BlastRadius = kWMD.BlastRadius or 0,
			StrikeRange = kWMD.ICBMStrikeRange or 0 });
		iMaxBlastRadius = math.max(iMaxBlastRadius, kWMD.BlastRadius or 0);
	end
end

-- Bomber, Jet Bomber and Nuclear Submarine (Units.WMDCapable; the
-- ABILITY_WMD_STRIKE route exists only in the Civ Royale scenario), and the
-- land combat units that mark a besieged city.
local tWMDDeliveryUnits = {};
local tLandCombatUnits = {};
for kUnit in GameInfo.Units() do
	if kUnit.WMDCapable == true or kUnit.WMDCapable == 1 then
		tWMDDeliveryUnits[kUnit.Index] = {
			Range = kUnit.Range or 0,
			Air = kUnit.Domain == "DOMAIN_AIR",
			Naval = kUnit.Domain == "DOMAIN_SEA"
		};
	end
	if kUnit.Domain == "DOMAIN_LAND"
		and math.max(kUnit.Combat or 0, kUnit.RangedCombat or 0, kUnit.Bombard or 0) > 0 then
		tLandCombatUnits[kUnit.Index] = true;
	end
end

local tNuclearReason = {};

-- Devices held, the largest blast radius among them, and the ICBM strike
-- range of that largest device (the launch node fires the device with the
-- largest blast).
local function GetHeldDevices(pPlayer)
	if pPlayer.GetWMDs == nil then return 0, 0, 0; end
	local pWMDs = pPlayer:GetWMDs();
	if pWMDs == nil then return 0, 0, 0; end
	local iCount, iRadius, iStrikeRange = 0, 0, 0;
	for _, kWMD in ipairs(tWMDTypes) do
		local iHeld = pWMDs:GetWeaponCount(kWMD.Index) or 0;
		if iHeld > 0 then
			iCount = iCount + iHeld;
			if kWMD.BlastRadius >= iRadius then
				iRadius = kWMD.BlastRadius;
				iStrikeRange = kWMD.StrikeRange;
			end
		end
	end
	return iCount, iRadius, iStrikeRange;
end

local function ExtendNuclearCooldown(pPlayer, iUntil)
	local iNext = pPlayer:GetProperty(NUCLEAR_NEXT_ATTEMPT_PROPERTY);
	if type(iNext) ~= "number" or iNext < iUntil then
		pPlayer:SetProperty(NUCLEAR_NEXT_ATTEMPT_PROPERTY, iUntil);
	end
end

-- "enemyID=firstTurn" entries, sorted, for every major we are at war with:
-- the first turn start at which this hook saw the war.
local function UpdateNuclearWarSince(pPlayer, iTurn)
	local tOld = {};
	local sOld = pPlayer:GetProperty(NUCLEAR_WAR_SINCE_PROPERTY);
	if type(sOld) == "string" then
		for sID, sTurn in string.gmatch(sOld, "(%d+)=(%-?%d+)") do
			tOld[tonumber(sID)] = tonumber(sTurn);
		end
	end
	local tSince = {};
	local tParts = {};
	local pDiplomacy = pPlayer:GetDiplomacy();
	for _, pOther in ipairs(PlayerManager.GetAliveMajors()) do
		local iOtherID = pOther:GetID();
		if iOtherID ~= pPlayer:GetID() and pDiplomacy:IsAtWarWith(iOtherID) then
			tSince[iOtherID] = tOld[iOtherID] or iTurn;
			table.insert(tParts, iOtherID .. "=" .. tSince[iOtherID]);
		end
	end
	table.sort(tParts);
	local sValue = table.concat(tParts, ";");
	if (sOld or "") ~= sValue then
		pPlayer:SetProperty(NUCLEAR_WAR_SINCE_PROPERTY, sValue);
	end
	return tSince;
end

-- The last order as "operation@turn@unit@targetOwner@x@y@flags"; flags:
-- l = launch seen, r = missing launch reported.
local function ReadNuclearStrike(pPlayer)
	local sValue = pPlayer:GetProperty(NUCLEAR_STRIKE_PROPERTY);
	if type(sValue) ~= "string" then return nil; end
	local sOp, sTurn, sUnit, sOwner, sX, sY, sFlags = string.match(sValue,
		"^(%-?%d+)@(%-?%d+)@(%-?%d+)@(%-?%d+)@(%-?%d+)@(%-?%d+)@(%a*)$");
	if sOp == nil then return nil; end
	return {
		Operation = tonumber(sOp), Turn = tonumber(sTurn), Unit = tonumber(sUnit),
		Owner = tonumber(sOwner), X = tonumber(sX), Y = tonumber(sY),
		Launched = string.find(sFlags, "l", 1, true) ~= nil,
		Reported = string.find(sFlags, "r", 1, true) ~= nil
	};
end

local function WriteNuclearStrike(pPlayer, kStrike)
	local sValue = kStrike.Operation .. "@" .. kStrike.Turn .. "@" .. kStrike.Unit
		.. "@" .. kStrike.Owner .. "@" .. kStrike.X .. "@" .. kStrike.Y .. "@"
		.. (kStrike.Launched and "l" or "") .. (kStrike.Reported and "r" or "");
	if pPlayer:GetProperty(NUCLEAR_STRIKE_PROPERTY) ~= sValue then
		pPlayer:SetProperty(NUCLEAR_STRIKE_PROPERTY, sValue);
	end
end

-- Plots this player's own detonations hit within the last NUCLEAR_RECENT_TURNS
-- turns, as a list of { X, Y, Turn } read from sorted "x@y@turn" entries.
local function ReadRecentNukes(pPlayer, iTurn)
	local tRecent = {};
	local sValue = pPlayer:GetProperty(NUCLEAR_RECENT_PROPERTY);
	if type(sValue) == "string" then
		for sX, sY, sTurn in string.gmatch(sValue, "(%-?%d+)@(%-?%d+)@(%-?%d+)") do
			local iNuked = tonumber(sTurn);
			if iTurn - iNuked < NUCLEAR_RECENT_TURNS then
				table.insert(tRecent, { X = tonumber(sX), Y = tonumber(sY), Turn = iNuked });
			end
		end
	end
	return tRecent;
end

local function RecordRecentNuke(pPlayer, iX, iY, iTurn)
	local tParts = {};
	for _, kNuke in ipairs(ReadRecentNukes(pPlayer, iTurn)) do
		if kNuke.X ~= iX or kNuke.Y ~= iY then
			table.insert(tParts, kNuke.X .. "@" .. kNuke.Y .. "@" .. kNuke.Turn);
		end
	end
	table.insert(tParts, iX .. "@" .. iY .. "@" .. iTurn);
	table.sort(tParts);
	pPlayer:SetProperty(NUCLEAR_RECENT_PROPERTY, table.concat(tParts, ";"));
end

local function HasPlayerUnit(pPlayer, iUnitID)
	for _, pUnit in pPlayer:GetUnits():Members() do
		if pUnit:GetID() == iUnitID then return true; end
	end
	return false;
end

-- Cross-checks launches against the device count and reports an order with no
-- launch. Returns the last order, if any.
local function MonitorNuclearStrike(pPlayer, iTurn, iDevices)
	local iPlayerID = pPlayer:GetID();
	local iLastDevices = pPlayer:GetProperty(NUCLEAR_DEVICES_PROPERTY);
	if iLastDevices ~= iDevices then
		pPlayer:SetProperty(NUCLEAR_DEVICES_PROPERTY, iDevices);
	end
	local iSeen = pPlayer:GetProperty(NUCLEAR_DETONATIONS_PROPERTY);
	if type(iSeen) ~= "number" then iSeen = 0; end
	if iSeen ~= 0 then pPlayer:SetProperty(NUCLEAR_DETONATIONS_PROPERTY, 0); end
	local kStrike = ReadNuclearStrike(pPlayer);
	if type(iLastDevices) == "number" and iLastDevices - iDevices > iSeen then
		ExtendNuclearCooldown(pPlayer, iTurn + NUCLEAR_LAUNCH_COOLDOWN);
		local sOrder = "";
		if kStrike ~= nil and not kStrike.Launched then
			kStrike.Launched = true;
			sOrder = ", counted as the launch of strike operation " .. kStrike.Operation;
		end
		print("Rose AI: Nuclear devices of player " .. iPlayerID .. " fell "
			.. iLastDevices .. " -> " .. iDevices .. " by turn " .. iTurn
			.. " with " .. iSeen .. " detonation events seen" .. sOrder);
	end
	if kStrike == nil then return nil; end
	if not kStrike.Launched and not kStrike.Reported
		and iTurn - kStrike.Turn >= NUCLEAR_REPORT_TURNS then
		kStrike.Reported = true;
		print("Rose AI: Nuclear strike operation " .. kStrike.Operation
			.. " player " .. iPlayerID .. " no launch " .. (iTurn - kStrike.Turn)
			.. " turns after the order, delivery unit " .. kStrike.Unit
			.. (HasPlayerUnit(pPlayer, kStrike.Unit) and " still present" or " lost"));
	end
	WriteNuclearStrike(pPlayer, kStrike);
	return kStrike;
end

-- WMD-capable units; aircraft only while the AI holds NUCLEAR_MIN_AIRCRAFT
-- of them. A naval unit's range is iStrikeRange (the held device's ICBM
-- range), an aircraft's its Units.Range.
local function GetNuclearDeliveryUnits(pPlayer, iStrikeRange)
	local tUnits = {};
	local iAircraft = 0;
	for _, pUnit in pPlayer:GetUnits():Members() do
		local kDelivery = tWMDDeliveryUnits[pUnit:GetType()];
		if kDelivery ~= nil then
			if kDelivery.Air then iAircraft = iAircraft + 1; end
			table.insert(tUnits, { Unit = pUnit, Air = kDelivery.Air,
				Range = kDelivery.Naval and iStrikeRange or kDelivery.Range,
				Damage = pUnit.GetDamage ~= nil and (pUnit:GetDamage() or 0) or 0 });
		end
	end
	local tUsable = {};
	for _, kUnit in ipairs(tUnits) do
		if not kUnit.Air or iAircraft >= NUCLEAR_MIN_AIRCRAFT then
			table.insert(tUsable, kUnit);
		end
	end
	return tUsable, #tUnits, iAircraft;
end

local function CountPlotsWithin(tPlots, iX, iY, iDistance, iSkipID)
	local iCount = 0;
	for _, kPlot in ipairs(tPlots) do
		if (iSkipID == nil or kPlot.ID ~= iSkipID)
			and Map.GetPlotDistance(kPlot.X, kPlot.Y, iX, iY) <= iDistance then
			iCount = iCount + 1;
		end
	end
	return iCount;
end

-- Whether any live operation of ours (any type, scripted ones included)
-- targets iEnemyID: true, false, or nil when it cannot be read. The only
-- operation read gameplay Lua has. XP2 DLL binding (round 8 trace,
-- 2026-10-17): HasOperationAgainst(player, requireReady, maxDist,
-- teamPlotSlot); slot -1 is the existence test (the two-argument call reads
-- slot 0, "a team unit stands on the rally plot"). Confirmed at runtime in
-- 20261018: it reads yes from a director siege's order turn to the turn
-- after its "Operation complete" (7 of 7 conclusive orders). It cannot count:
-- one yes may be several operations.
local bOperationReadWarned = false;
local function ReadOperationExists(pPlayer, iEnemyID)
	local pMilitaryAI = pPlayer:GetAi_Military();
	if pMilitaryAI == nil then return nil; end
	local bOk, bHas = pcall(function() return pMilitaryAI:HasOperationAgainst(iEnemyID, false, 0, -1); end);
	if not bOk then
		if not bOperationReadWarned then
			bOperationReadWarned = true;
			print("Rose AI ERROR: HasOperationAgainst failed; nuclear targets, the war director and the city-state report ignore our operations: " .. tostring(bHas));
		end
		return nil;
	end
	if bHas == true or bHas == false then return bHas; end
	return nil;
end

local function HasOperationAgainst(pPlayer, iEnemyID)
	return ReadOperationExists(pPlayer, iEnemyID) == true;
end

-- Returns the chosen target { City, Owner, Delivery, Operation, Besiegers,
-- Population, Nearest } or nil and a reason.
local function FindNuclearTarget(pPlayer, tSince, iTurn, iRadius, iStrikeRange)
	local iPlayerID = pPlayer:GetID();
	local tEnemyIDs = {};
	for iOtherID, iSince in pairs(tSince) do
		if iTurn - iSince >= NUCLEAR_MIN_WAR_TURNS then
			table.insert(tEnemyIDs, iOtherID);
		end
	end
	if #tEnemyIDs == 0 then
		return nil, "no war with a major of " .. NUCLEAR_MIN_WAR_TURNS .. "+ turns";
	end
	table.sort(tEnemyIDs);
	local tDelivery, iDeliveryUnits, iAircraft = GetNuclearDeliveryUnits(pPlayer, iStrikeRange);
	if #tDelivery == 0 then
		if iDeliveryUnits == 0 then
			return nil, "no delivery unit";
		end
		return nil, "only " .. iAircraft .. " WMD aircraft (needs " .. NUCLEAR_MIN_AIRCRAFT .. ")";
	end
	local pVisibility = PlayersVisibility ~= nil and PlayersVisibility[iPlayerID] or nil;
	if pVisibility == nil then return nil, "no visibility data"; end

	-- Our units must stay clear of the blast with a margin; cities of ours and
	-- of anyone but a major we are at war with must stay outside the blast.
	local iUnitSafe = iRadius + NUCLEAR_UNIT_MARGIN;
	local iSiegeReach = iUnitSafe + NUCLEAR_SIEGE_RING;
	local tOwnUnits = {};
	local tLandUnits = {};
	for _, pUnit in pPlayer:GetUnits():Members() do
		local kPlot = { X = pUnit:GetX(), Y = pUnit:GetY(), ID = pUnit:GetID() };
		table.insert(tOwnUnits, kPlot);
		if tLandCombatUnits[pUnit:GetType()] then table.insert(tLandUnits, kPlot); end
	end
	local tProtectedCities = {};
	for _, pOther in ipairs(GetAliveCityOwners()) do
		if tSince[pOther:GetID()] == nil then
			for _, pCity in pOther:GetCities():Members() do
				table.insert(tProtectedCities, { X = pCity:GetX(), Y = pCity:GetY() });
			end
		end
	end

	-- Plots we nuked ourselves within NUCLEAR_RECENT_TURNS turns.
	local tRecent = {};
	for _, kNuke in ipairs(ReadRecentNukes(pPlayer, iTurn)) do
		tRecent[kNuke.X .. "," .. kNuke.Y] = true;
	end

	local kBest = nil;
	local iInRange, iRecentSkipped = 0, 0;
	for _, iOwner in ipairs(tEnemyIDs) do
		local pOwner = Players[iOwner];
		if pOwner ~= nil and pOwner:IsAlive() and pOwner:IsMajor() then
			local bOperation = HasOperationAgainst(pPlayer, iOwner);
			for _, pCity in pOwner:GetCities():Members() do
				local iX, iY = pCity:GetX(), pCity:GetY();
				-- Units in range that are themselves outside the blast: the least
				-- damaged first (W20 step 4; a damaged unit can still fire, so
				-- damage alone never rules one out), then the closest, then unit
				-- order.
				local tCandidates = {};
				if pVisibility:IsRevealed(iX, iY) then
					for iIndex, kDelivery in ipairs(tDelivery) do
						local iDistance = Map.GetPlotDistance(
							kDelivery.Unit:GetX(), kDelivery.Unit:GetY(), iX, iY);
						if iDistance <= kDelivery.Range and iDistance > iRadius then
							table.insert(tCandidates, { Delivery = kDelivery, Distance = iDistance, Index = iIndex });
						end
					end
				end
				table.sort(tCandidates, function(a, b)
					if a.Delivery.Damage ~= b.Delivery.Damage then return a.Delivery.Damage < b.Delivery.Damage; end
					if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
					return a.Index < b.Index;
				end);
				if #tCandidates > 0 then
					iInRange = iInRange + 1;
				end
				-- The first candidate whose launch leaves no other unit of ours
				-- inside the margin (the launcher is outside the blast).
				local kUnit = nil;
				if #tCandidates > 0 and not tRecent[iX .. "," .. iY]
					and CountPlotsWithin(tProtectedCities, iX, iY, iMaxBlastRadius) == 0 then
					for _, kCandidate in ipairs(tCandidates) do
						if CountPlotsWithin(tOwnUnits, iX, iY, iUnitSafe, kCandidate.Delivery.Unit:GetID()) == 0 then
							kUnit = kCandidate.Delivery;
							break;
						end
					end
				end
				if #tCandidates > 0 and tRecent[iX .. "," .. iY] then
					iRecentSkipped = iRecentSkipped + 1;
				elseif kUnit ~= nil then
					local iBesiegers = CountPlotsWithin(tLandUnits, iX, iY, iSiegeReach);
					local iPopulation = pCity:GetPopulation();
					if kBest == nil
						or (bOperation and not kBest.Operation)
						or (bOperation == kBest.Operation and (iBesiegers > kBest.Besiegers
							or (iBesiegers == kBest.Besiegers and iPopulation > kBest.Population))) then
						kBest = { City = pCity, Owner = iOwner, Delivery = kUnit, Operation = bOperation,
							Besiegers = iBesiegers, Population = iPopulation };
					end
				end
			end
		end
	end
	if kBest == nil then
		if iInRange == 0 then
			return nil, "no revealed enemy city in range of a delivery unit";
		end
		if iRecentSkipped == iInRange then
			return nil, "every enemy city in range was nuked within " .. NUCLEAR_RECENT_TURNS .. " turns";
		end
		return nil, "every enemy city in range has our units within " .. iUnitSafe
			.. " tiles or a protected city within " .. iMaxBlastRadius;
	end
	local iNearest = nil;
	local iDeliveryID = kBest.Delivery.Unit:GetID();
	for _, kPlot in ipairs(tOwnUnits) do
		if kPlot.ID ~= iDeliveryID then
			local iDistance = Map.GetPlotDistance(kPlot.X, kPlot.Y, kBest.City:GetX(), kBest.City:GetY());
			if iNearest == nil or iDistance < iNearest then iNearest = iDistance; end
		end
	end
	kBest.Nearest = iNearest;
	return kBest, nil;
end

local function ReportNuclearReason(iPlayerID, sReason)
	if tNuclearReason[iPlayerID] == sReason then return; end
	tNuclearReason[iPlayerID] = sReason;
	if sReason ~= nil then
		print("Rose AI: Nuclear strike not ordered for player " .. iPlayerID
			.. " turn " .. Game.GetCurrentGameTurn() .. ": " .. sReason);
	end
end

local function TryNuclearStrike(iPlayerID)
	if not NUCLEAR_STRIKE_ENABLED then return; end
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local tSince = UpdateNuclearWarSince(pPlayer, iTurn);
	local iDevices, iRadius, iStrikeRange = GetHeldDevices(pPlayer);
	local kLast = MonitorNuclearStrike(pPlayer, iTurn, iDevices);
	if iDevices <= 0 then
		ReportNuclearReason(iPlayerID, nil);
		return;
	end
	if kLast ~= nil and not kLast.Launched and iTurn - kLast.Turn < NUCLEAR_PENDING_TURNS
		and HasPlayerUnit(pPlayer, kLast.Unit) then
		ReportNuclearReason(iPlayerID, "waiting for strike operation " .. kLast.Operation
			.. " ordered turn " .. kLast.Turn);
		return;
	end
	local iNextAttempt = pPlayer:GetProperty(NUCLEAR_NEXT_ATTEMPT_PROPERTY);
	if type(iNextAttempt) == "number" and iTurn < iNextAttempt then
		ReportNuclearReason(iPlayerID, "cooldown until turn " .. iNextAttempt);
		return;
	end
	local kTarget, sReason = FindNuclearTarget(pPlayer, tSince, iTurn, iRadius, iStrikeRange);
	if kTarget == nil then
		ReportNuclearReason(iPlayerID, sReason);
		return;
	end
	ReportNuclearReason(iPlayerID, nil);

	local pUnit = kTarget.Delivery.Unit;
	local pCity = kTarget.City;
	local pMilitaryAI = pPlayer:GetAi_Military();
	local pTargetPlot = Map.GetPlot(pCity:GetX(), pCity:GetY());
	local pRallyPlot = Map.GetPlot(pUnit:GetX(), pUnit:GetY());
	if pMilitaryAI == nil or pTargetPlot == nil or pRallyPlot == nil then return; end
	ExtendNuclearCooldown(pPlayer, iTurn + NUCLEAR_ATTEMPT_COOLDOWN);
	local iOperationID = pMilitaryAI:StartScriptedOperationWithTargetAndRally(
		NUCLEAR_OPERATION_NAME, kTarget.Owner, pTargetPlot:GetIndex(), pRallyPlot:GetIndex());
	-- The DLL returns the operation id, or -1 (no slot or no operation) or 0
	-- (an early refusal); real ids are large (3407877 for a naval start).
	if type(iOperationID) ~= "number" or iOperationID <= 0 then
		print("Rose AI: Nuclear strike start rejected for player " .. iPlayerID
			.. " turn " .. iTurn .. " against player " .. kTarget.Owner
			.. " result " .. tostring(iOperationID));
		return;
	end
	-- Returns nothing (Nubia does not check it either).
	pMilitaryAI:AddUnitToScriptedOperation(iOperationID, pUnit:GetID());
	WriteNuclearStrike(pPlayer, { Operation = iOperationID, Turn = iTurn,
		Unit = pUnit:GetID(), Owner = kTarget.Owner, X = pCity:GetX(), Y = pCity:GetY() });
	local kUnitInfo = GetUnitInfo(pUnit);
	print("Rose AI: Nuclear strike ordered for player " .. iPlayerID
		.. " turn " .. iTurn
		.. " against player " .. kTarget.Owner
		.. " city " .. tostring(pCity:GetName())
		.. " plot (" .. pCity:GetX() .. "," .. pCity:GetY() .. ")"
		.. " population " .. kTarget.Population
		.. " besiegers " .. kTarget.Besiegers
		.. " our operation against them " .. (kTarget.Operation and "yes" or "no")
		.. " with unit " .. pUnit:GetID()
		.. " " .. (kUnitInfo ~= nil and kUnitInfo.UnitType or "?")
		.. " at (" .. pUnit:GetX() .. "," .. pUnit:GetY() .. ")"
		.. " damage " .. kTarget.Delivery.Damage
		.. " range " .. kTarget.Delivery.Range
		.. " operation " .. iOperationID
		.. " devices " .. iDevices .. " blast radius " .. iRadius
		.. " nearest own unit " .. tostring(kTarget.Nearest));
end

-- Any player's detonation: logged with who owns the plot and what of the
-- launcher's own lies inside the blast (survivors; the event comes after the
-- blast). For an eligible AI it also counts the launch for the cross-check and
-- starts the launch cooldown. It marks the open order launched only when it
-- hit the ordered plot (the Rose operation cannot retarget): the engine's own
-- Nuclear Assault launches too, sometimes with the unit Rose added
-- (20261009b, Arabia t209), and such a launch is not this order's.
local function OnNuclearWeaponDetonated(iPlayerID, iX, iY, iWMDType)
	if not NUCLEAR_STRIKE_ENABLED then return; end
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local kWMD = GameInfo.WMDs ~= nil and GameInfo.WMDs[iWMDType] or nil;
	local iRadius = kWMD ~= nil and (kWMD.BlastRadius or 0) or 0;
	local iOwnUnits = 0;
	for _, pUnit in pPlayer:GetUnits():Members() do
		if Map.GetPlotDistance(pUnit:GetX(), pUnit:GetY(), iX, iY) <= iRadius then
			iOwnUnits = iOwnUnits + 1;
		end
	end
	local iOwnCities = 0;
	for _, pCity in pPlayer:GetCities():Members() do
		if Map.GetPlotDistance(pCity:GetX(), pCity:GetY(), iX, iY) <= iRadius then
			iOwnCities = iOwnCities + 1;
		end
	end
	local pPlot = Map.GetPlot(iX, iY);
	local iPlotOwner = pPlot ~= nil and pPlot:GetOwner() or -1;
	local pPlotOwner = iPlotOwner >= 0 and Players[iPlotOwner] or nil;
	local sOrder = "";
	if IsEligibleAIPlayer(pPlayer) then
		local iSeen = pPlayer:GetProperty(NUCLEAR_DETONATIONS_PROPERTY);
		pPlayer:SetProperty(NUCLEAR_DETONATIONS_PROPERTY,
			(type(iSeen) == "number" and iSeen or 0) + 1);
		ExtendNuclearCooldown(pPlayer, iTurn + NUCLEAR_LAUNCH_COOLDOWN);
		RecordRecentNuke(pPlayer, iX, iY, iTurn);
		local kStrike = ReadNuclearStrike(pPlayer);
		if kStrike ~= nil then
			local bOrderPlot = kStrike.X == iX and kStrike.Y == iY;
			sOrder = " Rose order turn " .. kStrike.Turn .. " operation " .. kStrike.Operation
				.. " target plot (" .. kStrike.X .. "," .. kStrike.Y .. ") distance "
				.. Map.GetPlotDistance(kStrike.X, kStrike.Y, iX, iY)
				.. (kStrike.Launched and " (already launched)" or (bOrderPlot and "" or " (not this order)"));
			if bOrderPlot and not kStrike.Launched then
				kStrike.Launched = true;
				WriteNuclearStrike(pPlayer, kStrike);
				-- The order fired: its attempt cooldown (meant for refused orders)
				-- gives way to the launch cooldown.
				pPlayer:SetProperty(NUCLEAR_NEXT_ATTEMPT_PROPERTY, iTurn + NUCLEAR_LAUNCH_COOLDOWN);
			end
		end
	end
	print("Rose AI: Nuclear detonation by player " .. iPlayerID
		.. " turn " .. iTurn
		.. " at (" .. iX .. "," .. iY .. ") weapon "
		.. (kWMD ~= nil and kWMD.WeaponType or tostring(iWMDType))
		.. " plot owner " .. iPlotOwner
		.. ((pPlotOwner ~= nil and not pPlotOwner:IsMajor()) and " (minor)" or "")
		.. " own cities in blast " .. iOwnCities
		.. " own units in blast " .. iOwnUnits .. sOrder);
end
if GameEvents.OnNuclearWeaponDetonated ~= nil then
	GameEvents.OnNuclearWeaponDetonated.Add(function(iPlayerID, iX, iY, iWMDType)
		local bOk, sError = pcall(OnNuclearWeaponDetonated, iPlayerID, iX, iY, iWMDType);
		if not bOk then
			print("Rose AI ERROR: Nuclear detonation handler failed player "
				.. tostring(iPlayerID) .. ": " .. tostring(sError));
		end
	end);
end

-- The war director keeps its helpers and state inside one do-block: the main
-- chunk is near Lua 5.1's limit of 200 local variables. TryWarDirector and
-- ReadDirectorOrders (read by the operation read probe) are the exports.
local TryWarDirector, ReadDirectorOrders;
do

-- ============================================================================
-- Wartime war director (round 7, HANDOFF W10, 2026-10-15; fixed in round 8,
-- 2026-10-17; order rules and end signal in round 9, 2026-10-18)
--
-- The W10 doctrine (2026-10-15): one army, one target at a time; the target
-- is usually the enemy city closest to us that we can hold; keep attacking it
-- when it builds walls; keep going until we are at a disadvantage; with a
-- supreme advantage take city after city. The engine's wartime assaults did
-- none of this in the 2026-10-15 game (targets chosen by a value formula that
-- favors city-states and capitals, an unwalled attack ending the turn walls go
-- up, three assaults for a seven-unit army). Here an eligible AI at war with a
-- major for DIRECTOR_MIN_WAR_TURNS turn starts orders one siege itself: "Rose
-- Wartime Siege" (AI_BehaviorTrees.xml, Siege City Assault tree, Priority 4
-- so the AI's own planned sieges at 3 cannot take its units in assembly),
-- started with StartScriptedOperationWithTargetAndRally on the chosen city
-- with the rally at the sent unit nearest the target that stands on land at
-- least DIRECTOR_RALLY_MIN_DISTANCE tiles from it (round 8: with the rally at
-- our city, America's army walked back home under fire, 20261017 t66-71).
--
-- The army is chosen here. A scripted start marks the operation ready at once
-- (XP2 DLL 0x4D216C sets the flag IsReady 0x4DE580 returns first; 20261009b
-- logged a scripted team "Total: 0. Ready: YES"; SetScriptedOperationReady
-- 0x4D1030 can only set it), so team minimums are never enforced, the
-- assembly phase's Recruit and Contract Manager never run, and no production
-- contract is issued. So, as Firaxis' Nubia scenario does (NubiaScenario.lua
-- 639-653), units are added with AddUnitToScriptedOperation: siege units
-- first (at most DIRECTOR_MAX_STRIKE, nearest the target first): land bombard
-- units within DIRECTOR_GATHER_RADIUS tiles of the rally city, Battering Rams
-- and Siege Towers there only against Ancient or Medieval walls (round 9 item
-- 5), then bombers whose range reaches the target; then our other healthy
-- land combat units there, nearest the target first, up to DIRECTOR_MAX_UNITS.
-- Land units on one of our city centres (the garrisons), recon units and
-- units with DIRECTOR_MAX_DAMAGE damage or more stay home. The siege's later
-- Recruit nodes may still add units within 12 tiles and log production
-- contracts ("Contract for: UNIT_TREBUCHET / BOMBER / ARTILLERY" under the
-- director's operation in 20261017).
--
-- Target, among the revealed cities of majors we are at war with (never a
-- city-state): within DIRECTOR_REACH tiles of one of our cities
-- (DIRECTOR_REACH_ADVANTAGE while War Advantage is latched), nearest to our
-- nearest city first, then the most populous. A city whose defense strength
-- is more than DIRECTOR_DEFENSE_MARGIN above the best bombard strength of a
-- unit we own (aircraft included) or a land unit we can train is skipped,
-- under War Advantage too since round 9 (Beijing 77 and Constantinople 100
-- against bombard 55 were ordered under its waiver in 20261018 and failed).
-- Walls and defense are read from the city centre under pcall (gameplay
-- District table per the DLL; walls as outer defense hit points, the Pirates
-- scenario's call); if the defense read fails the rule is skipped (printed
-- once), if the walls read fails the city counts as walled.
--
-- Round 9 order rules (20261018: 4 of 18 orders took their city, all of
-- population 1-4; each refusal prints its rule):
-- - No order during Military Recovery ("until we are at a disadvantage"),
--   nor while an enemy major has DIRECTOR_THREAT_UNITS or more visible land
--   combat units on our land within DIRECTOR_THREAT_RADIUS tiles of one of
--   our cities: City Defense, at the same priority, took the armies of Khmer
--   (three times), China and Ethiopia the turn after their orders. Units in
--   their own territory do not count (round 9 decision, 2026-10-18: a border garrison
--   must not stop the war); units on the tiles of a city we just took do,
--   since those tiles become ours.
-- - For each candidate city, nearest first, the first that passes is
--   ordered: an army of DIRECTOR_MIN_UNITS land units; two siege units when
--   the city has walls or a defense of DIRECTOR_STRONG_DEFENSE or more, none
--   otherwise (round 9 decision, 2026-10-18: Sodo fell to an army without any); the rally
--   (the sent unit nearest the target) within DIRECTOR_MAX_ARMY_DISTANCE tiles
--   of the city (0 of 7 orders from 6 or more tiles succeeded, the captures
--   were at 3-5); and a land route: a path from the rally unit to a land plot
--   next to the city of at most DIRECTOR_PATH_FACTOR times the distance
--   (UnitManager.GetMoveToPath, gameplay table per the DLL; Mapuche's army
--   stood still 12 turns before Constantinople, Greece's walked around
--   Byzantium), or the same landmass when no path can be read.
--
-- An engine operation against the same enemy does not hold the director
-- (round 8's rule (d), dropped in round 9, 2026-10-18: with the
-- existence form it would have waited out every planned siege that declared
-- a war, Persia's against China from t80 to t110 in 20261018, and missed the
-- Guangzhou capture).
--
-- Pacing comes from the order record (player property, sorted
-- "enemy=turn@x@y@unitIDs" entries; "enemy=turn@x@y@e@endTurn" once ended). An
-- order locks its city and its units for DIRECTOR_ORDER_LOCK turns (a siege
-- can run about 45: 15 of assembly, 11 of siege phase, 20 of final assault),
-- until its city is no longer that enemy's (we took it: the capture event,
-- which also clears the pause below; or anyone else did, or it was razed) or
-- the war with that enemy is over, and since round 9 until no operation of
-- ours targets that enemy any more (HasOperationAgainst's existence form,
-- asked at each run for every enemy with a live order; read "no" one turn
-- after "Operation complete" in all 7 conclusive cases of 20261018, never
-- earlier; it cannot count, so two orders against one enemy end together,
-- and an engine operation against the same enemy keeps the order alive). An
-- ended order frees its units at once, keeps its city locked
-- DIRECTOR_FAILED_CITY_LOCK turns from its end (round 9 decision, 2026-10-18: otherwise
-- War Advantage, which has no pause, could restart a failed siege the next
-- turn), and still counts for the pause: one order per enemy per
-- DIRECTOR_ENEMY_COOLDOWN turns from the order, except under War Advantage
-- (its second slot). A refused start (-1 when the
-- ROSE_WARTIME_ASSAULT slot is full, 0 on an early refusal) waits
-- DIRECTOR_RETRY_TURNS. On the turn after an order the director prints how
-- many of the sent units still have no unit command. All state is in player
-- properties written from gameplay events, and every choice is ordered by
-- distance and ids, so every machine decides alike.
-- ============================================================================
local WAR_DIRECTOR_ENABLED = true;
local DIRECTOR_OPERATION_NAME = "Rose Wartime Siege";
local DIRECTOR_MIN_WAR_TURNS = 3;
local DIRECTOR_REACH = 12;
local DIRECTOR_REACH_ADVANTAGE = 16;
local DIRECTOR_DEFENSE_MARGIN = 10;
local DIRECTOR_RETRY_TURNS = 3;
local DIRECTOR_ENEMY_COOLDOWN = 25;
local DIRECTOR_GATHER_RADIUS = 10;
local DIRECTOR_MIN_UNITS = 6;
local DIRECTOR_MAX_UNITS = 12;
local DIRECTOR_MAX_STRIKE = 3;
local DIRECTOR_MAX_DAMAGE = 50;
local DIRECTOR_ORDER_LOCK = 40;
local DIRECTOR_FAILED_CITY_LOCK = 15;
local DIRECTOR_RALLY_MIN_DISTANCE = 3;
local DIRECTOR_MAX_ARMY_DISTANCE = 6;
local DIRECTOR_PATH_FACTOR = 2;
local DIRECTOR_THREAT_UNITS = 3;
local DIRECTOR_THREAT_RADIUS = 3;
local DIRECTOR_STRONG_DEFENSE = 40;
local DIRECTOR_ORDERS_PROPERTY = "ROSE_DIRECTOR_ORDERS";
local DIRECTOR_NEXT_ATTEMPT_PROPERTY = "ROSE_DIRECTOR_NEXT_ATTEMPT";

local iCityCenterDistrict = (GameInfo.Districts ~= nil and GameInfo.Districts["DISTRICT_CITY_CENTER"] ~= nil)
	and GameInfo.Districts["DISTRICT_CITY_CENTER"].Index or nil;
local iDirections = (DirectionTypes ~= nil and DirectionTypes.NUM_DIRECTION_TYPES) or 6;

-- Land units with a bombard strength that any civilization can train (unique
-- units count only when owned), with the tech that unlocks each; the land
-- units the director may send: land combat units other than recon (Siege when
-- they have a bombard strength; base siege units are
-- FORMATION_CLASS_LAND_COMBAT with PROMOTION_CLASS_SIEGE), plus the two
-- wall-breaking support units (Breaker); bombers (air units with a bombard
-- strength) with their range; and every land combat formation unit, for the
-- threat rule.
local tBombardUnits = {};
local tArmyUnits = {};
local tAirSiegeUnits = {};
local tLandCombatUnits = {};
for kUnit in GameInfo.Units() do
	if kUnit.Domain == "DOMAIN_LAND" and (kUnit.Bombard or 0) > 0 and kUnit.TraitType == nil
		and kUnit.CanTrain ~= false and kUnit.CanTrain ~= 0 then
		table.insert(tBombardUnits, { Bombard = kUnit.Bombard, Tech = kUnit.PrereqTech });
	end
	if kUnit.Domain == "DOMAIN_LAND" then
		local bBreaker = kUnit.UnitType == "UNIT_BATTERING_RAM" or kUnit.UnitType == "UNIT_SIEGE_TOWER";
		if bBreaker or (kUnit.FormationClass == "FORMATION_CLASS_LAND_COMBAT"
			and kUnit.PromotionClass ~= "PROMOTION_CLASS_RECON"
			and math.max(kUnit.Combat or 0, kUnit.RangedCombat or 0, kUnit.Bombard or 0) > 0) then
			tArmyUnits[kUnit.Index] = { Siege = not bBreaker and (kUnit.Bombard or 0) > 0, Breaker = bBreaker };
		end
		if kUnit.FormationClass == "FORMATION_CLASS_LAND_COMBAT" then tLandCombatUnits[kUnit.Index] = true; end
	elseif kUnit.Domain == "DOMAIN_AIR" and (kUnit.Bombard or 0) > 0 then
		tAirSiegeUnits[kUnit.Index] = { Range = kUnit.Range or 0, WMD = kUnit.WMDCapable == true or kUnit.WMDCapable == 1 };
	end
end

-- Renaissance Walls and their unique replacements (Georgia's Tsikhe): a
-- Battering Ram or Siege Tower counts as a siege unit only against lower
-- walls (round 9 item 5).
local tLateWalls = {};
if GameInfo.Buildings ~= nil and GameInfo.Buildings["BUILDING_STAR_FORT"] ~= nil then
	table.insert(tLateWalls, GameInfo.Buildings["BUILDING_STAR_FORT"].Index);
	if GameInfo.BuildingReplaces ~= nil then
		for kRow in GameInfo.BuildingReplaces() do
			if kRow.ReplacesBuildingType == "BUILDING_STAR_FORT" and GameInfo.Buildings[kRow.CivUniqueBuildingType] ~= nil then
				table.insert(tLateWalls, GameInfo.Buildings[kRow.CivUniqueBuildingType].Index);
			end
		end
	end
end

local tDirectorReason = {};
local bDefenseReadWarned = false;

local function ReportDirectorReason(iPlayerID, sReason)
	if tDirectorReason[iPlayerID] == sReason then return; end
	tDirectorReason[iPlayerID] = sReason;
	if sReason ~= nil then
		print("Rose AI: War director not ordered for player " .. iPlayerID
			.. " turn " .. Game.GetCurrentGameTurn() .. ": " .. sReason);
	end
end

-- Recorded orders, "enemyID=turn@x@y@unitIDs" entries (comma-separated unit
-- ids), "enemyID=turn@x@y@e@endTurn" once ended (round 7's "@e@unitIDs" meant
-- ended too; its end turn reads as the order turn), sorted (an enemy may have
-- two under War Advantage).
function ReadDirectorOrders(pPlayer)
	local tOrders = {};
	local sValue = pPlayer:GetProperty(DIRECTOR_ORDERS_PROPERTY);
	if type(sValue) == "string" then
		for sEntry in string.gmatch(sValue, "[^;]+") do
			local sID, sTurn, sX, sY, sFlag, sUnits = string.match(sEntry, "^(%d+)=(%-?%d+)@(%-?%d+)@(%-?%d+)@?(%a*)@?([%d,]*)$");
			if sID ~= nil then
				local kOrder = { Enemy = tonumber(sID), Turn = tonumber(sTurn), X = tonumber(sX), Y = tonumber(sY),
					Ended = sFlag == "e", Units = {} };
				if kOrder.Ended then
					kOrder.EndTurn = tonumber(sUnits) or kOrder.Turn;
				else
					for sUnit in string.gmatch(sUnits, "%d+") do table.insert(kOrder.Units, tonumber(sUnit)); end
				end
				table.insert(tOrders, kOrder);
			end
		end
	end
	return tOrders;
end

local function WriteDirectorOrders(pPlayer, tOrders)
	local tParts = {};
	for _, kOrder in ipairs(tOrders) do
		local tUnits = {};
		for _, iUnit in ipairs(kOrder.Units or {}) do table.insert(tUnits, tostring(iUnit)); end
		table.insert(tParts, kOrder.Enemy .. "=" .. kOrder.Turn .. "@" .. kOrder.X .. "@" .. kOrder.Y
			.. (kOrder.Ended and ("@e@" .. kOrder.EndTurn) or ("@" .. table.concat(tUnits, ","))));
	end
	table.sort(tParts);
	local sValue = table.concat(tParts, ";");
	local sOld = pPlayer:GetProperty(DIRECTOR_ORDERS_PROPERTY);
	if (type(sOld) == "string" and sOld or "") ~= sValue then
		pPlayer:SetProperty(DIRECTOR_ORDERS_PROPERTY, sValue);
	end
end

-- Keeps an order while we are still at war with its enemy and its city is
-- still that enemy's: DIRECTOR_ORDER_LOCK turns while live; once ended, while
-- it still counts for the pause (DIRECTOR_ENEMY_COOLDOWN turns from its order)
-- or still locks its city (DIRECTOR_FAILED_CITY_LOCK turns from its end). A
-- live order from an earlier turn ends when no operation of ours targets its
-- enemy any more (the existence form; an unreadable answer keeps it). Returns
-- the kept orders and each enemy's latest order turn (FindDirectorTargets
-- applies the pause and the city lock).
local function PruneDirectorOrders(pPlayer, iTurn, tSince)
	local tKept = {};
	local tLatest = {};
	local tExists = {};
	for _, kOrder in ipairs(ReadDirectorOrders(pPlayer)) do
		local pCity = CityManager.GetCityAt(kOrder.X, kOrder.Y);
		local bKeep = iTurn - kOrder.Turn < DIRECTOR_ORDER_LOCK;
		if kOrder.Ended then
			bKeep = iTurn - kOrder.Turn < DIRECTOR_ENEMY_COOLDOWN or iTurn - kOrder.EndTurn < DIRECTOR_FAILED_CITY_LOCK;
		end
		if bKeep and tSince[kOrder.Enemy] ~= nil
			and pCity ~= nil and pCity:GetOwner() == kOrder.Enemy then
			if not kOrder.Ended and kOrder.Turn < iTurn then
				if tExists[kOrder.Enemy] == nil then
					local bExists = ReadOperationExists(pPlayer, kOrder.Enemy);
					tExists[kOrder.Enemy] = bExists == nil and "?" or bExists;
				end
				if tExists[kOrder.Enemy] == false then
					kOrder.Ended = true;
					kOrder.EndTurn = iTurn;
					kOrder.Units = {};
					print("Rose AI: War director order of player " .. pPlayer:GetID() .. " turn " .. kOrder.Turn
						.. " against player " .. kOrder.Enemy .. " plot (" .. kOrder.X .. "," .. kOrder.Y .. ") ended by turn "
						.. iTurn .. ": no operation of ours against player " .. kOrder.Enemy .. "; its units are free, its city locked "
						.. DIRECTOR_FAILED_CITY_LOCK .. " turns");
				end
			end
			table.insert(tKept, kOrder);
			if tLatest[kOrder.Enemy] == nil or kOrder.Turn > tLatest[kOrder.Enemy] then
				tLatest[kOrder.Enemy] = kOrder.Turn;
			end
		end
	end
	WriteDirectorOrders(pPlayer, tKept);
	return tKept, tLatest;
end

-- On the turn after an order: how many of the units it sent still have no
-- unit command, how many have one, and how many are gone (print-only; a unit
-- command is not proof of which operation holds the unit).
local function ReportDirectorArmies(pPlayer, tOrders, iTurn)
	local tUnits = nil;
	for _, kOrder in ipairs(tOrders) do
		if kOrder.Turn == iTurn - 1 and not kOrder.Ended then
			if tUnits == nil then
				tUnits = {};
				for _, pUnit in pPlayer:GetUnits():Members() do tUnits[pUnit:GetID()] = pUnit; end
			end
			local iIdle, iBusy, iGone = 0, 0, 0;
			local tCommands = {};
			for _, iUnit in ipairs(kOrder.Units) do
				local pUnit = tUnits[iUnit];
				if pUnit == nil then
					iGone = iGone + 1;
				elseif IsUnitUncommitted(pUnit) then
					iIdle = iIdle + 1;
				else
					iBusy = iBusy + 1;
					local sCommand = GetUnitOperationName(pUnit);
					tCommands[sCommand] = (tCommands[sCommand] or 0) + 1;
				end
			end
			local tParts = {};
			for sCommand, iCount in pairs(tCommands) do table.insert(tParts, sCommand .. " x" .. iCount); end
			table.sort(tParts);
			print("Rose AI: War director army of player " .. pPlayer:GetID() .. " ordered turn " .. kOrder.Turn
				.. " against player " .. kOrder.Enemy .. " plot (" .. kOrder.X .. "," .. kOrder.Y .. ") on turn " .. iTurn
				.. ": " .. iIdle .. " of " .. #kOrder.Units .. " units with no unit command, "
				.. iBusy .. " with one, " .. iGone .. " gone (merged into a corps or army counts as gone)"
				.. (#tParts > 0 and (": " .. table.concat(tParts, ", ")) or ""));
		end
	end
end

-- The best bombard strength among units we own (aircraft included) and land
-- units we could train now (unlocking tech owned; strategic resources are not
-- checked).
local function GetBestBombard(pPlayer)
	local iBest = 0;
	for _, pUnit in pPlayer:GetUnits():Members() do
		local kUnit = GetUnitInfo(pUnit);
		if kUnit ~= nil and (kUnit.Bombard or 0) > iBest then iBest = kUnit.Bombard; end
	end
	local pTechs = pPlayer.GetTechs ~= nil and pPlayer:GetTechs() or nil;
	for _, kUnit in ipairs(tBombardUnits) do
		if kUnit.Bombard > iBest then
			local kTech = (kUnit.Tech ~= nil and GameInfo.Technologies ~= nil) and GameInfo.Technologies[kUnit.Tech] or nil;
			if kUnit.Tech == nil or (kTech ~= nil and pTechs ~= nil and pTechs:HasTech(kTech.Index)) then
				iBest = kUnit.Bombard;
			end
		end
	end
	return iBest;
end

-- The city centre district: by plot first, then by type.
local function GetCityCentre(pCity)
	local pDistricts = pCity:GetDistricts();
	local bOk, pDistrict = pcall(function() return pDistricts:GetDistrictAtLocation(pCity:GetX(), pCity:GetY()); end);
	if bOk and pDistrict ~= nil then return pDistrict; end
	return pDistricts:GetDistrict(iCityCenterDistrict);
end

-- The city centre's defense strength, or nil when it cannot be read.
local function ReadCityDefense(pCity)
	local bOk, iDefense = pcall(function() return GetCityCentre(pCity):GetDefenseStrength(); end);
	if bOk and type(iDefense) == "number" then return iDefense; end
	if not bDefenseReadWarned then
		bDefenseReadWarned = true;
		print("Rose AI: War director cannot read city defense (" .. tostring(iDefense)
			.. "); the defense rule is skipped");
	end
	return nil;
end

-- True when the city has walls (outer defense hit points), or when that
-- cannot be read.
local function CityHasWalls(pCity)
	local bOk, iWalls = pcall(function()
		return GetCityCentre(pCity):GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
	end);
	if bOk and type(iWalls) == "number" then return iWalls > 0; end
	return true;
end

-- True when the city has Renaissance Walls or a replacement, or when that
-- cannot be read.
local function HasLateWalls(pCity)
	local bOk, bLate = pcall(function()
		local pBuildings = pCity:GetBuildings();
		for _, iBuilding in ipairs(tLateWalls) do
			if pBuildings:HasBuilding(iBuilding) then return true; end
		end
		return false;
	end);
	return not bOk or bLate == true;
end

-- Siege units an order on this city needs (two when it has walls or a
-- defense of DIRECTOR_STRONG_DEFENSE or more, none otherwise: the brief's one
-- for weak cities would have refused Sodo, taken with none in 20261018; round 9
-- decision, 2026-10-18), whether it has walls, and whether a Battering Ram or Siege
-- Tower counts against them (only Ancient or Medieval walls).
local function SiegeNeeds(pCity, iDefense)
	local bWalls = CityHasWalls(pCity);
	local iNeed = (bWalls or (iDefense ~= nil and iDefense >= DIRECTOR_STRONG_DEFENSE)) and 2 or 0;
	return iNeed, bWalls, bWalls and not HasLateWalls(pCity);
end

-- The army for one city, from our healthy units not sent with a live order of
-- ours. Siege units first, at most DIRECTOR_MAX_STRIKE: land bombard units
-- within DIRECTOR_GATHER_RADIUS tiles of the rally city (plus Battering Rams
-- and Siege Towers there when bBreakers), nearest the target first, then
-- bombers whose range reaches the target; then the other land units there,
-- nearest the target first, up to DIRECTOR_MAX_UNITS. Land units on one of
-- our city centres (the garrisons) stay; aircraft are based there. While we
-- hold a nuclear device, WMD-capable aircraft (every bomber) are left to the
-- nuclear launcher, which runs first in the same hook and cannot see our
-- orders. Returns the army, its siege units and its land units.
local function GatherSiegeArmy(pPlayer, pRally, pTarget, tOwnCentres, tReserved, bBreakers)
	local tLandSiege, tAir, tOther = {}, {}, {};
	local bDevices = nil;
	local iTX, iTY = pTarget:GetX(), pTarget:GetY();
	for _, pUnit in pPlayer:GetUnits():Members() do
		local iType = pUnit:GetType();
		local kArmy, kAir = tArmyUnits[iType], tAirSiegeUnits[iType];
		if (kArmy ~= nil or kAir ~= nil) and not tReserved[pUnit:GetID()]
			and (pUnit:GetDamage() or 0) < DIRECTOR_MAX_DAMAGE then
			local iX, iY = pUnit:GetX(), pUnit:GetY();
			local kEntry = { Unit = pUnit, ID = pUnit:GetID(), Distance = Map.GetPlotDistance(iX, iY, iTX, iTY) };
			if kArmy ~= nil then
				if not tOwnCentres[iX .. "," .. iY] and (bBreakers or not kArmy.Breaker)
					and Map.GetPlotDistance(iX, iY, pRally:GetX(), pRally:GetY()) <= DIRECTOR_GATHER_RADIUS then
					table.insert((kArmy.Siege or kArmy.Breaker) and tLandSiege or tOther, kEntry);
				end
			elseif kEntry.Distance <= kAir.Range then
				if bDevices == nil then bDevices = GetHeldDevices(pPlayer) > 0; end
				if not (kAir.WMD and bDevices) then table.insert(tAir, kEntry); end
			end
		end
	end
	local function Nearer(a, b)
		if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
		return a.ID < b.ID;
	end
	table.sort(tLandSiege, Nearer);
	table.sort(tAir, Nearer);
	table.sort(tOther, Nearer);
	local tArmy, iLand = {}, 0;
	for _, kEntry in ipairs(tLandSiege) do
		if #tArmy >= DIRECTOR_MAX_STRIKE then break; end
		table.insert(tArmy, kEntry.Unit);
		iLand = iLand + 1;
	end
	for _, kEntry in ipairs(tAir) do
		if #tArmy >= DIRECTOR_MAX_STRIKE then break; end
		table.insert(tArmy, kEntry.Unit);
	end
	local iStrike = #tArmy;
	for _, kEntry in ipairs(tOther) do
		if #tArmy >= DIRECTOR_MAX_UNITS then break; end
		table.insert(tArmy, kEntry.Unit);
		iLand = iLand + 1;
	end
	return tArmy, iStrike, iLand;
end

-- The rally: the sent land unit nearest the target that stands on land at
-- least DIRECTOR_RALLY_MIN_DISTANCE tiles from it (the assembly Move holds the
-- team within 2 tiles of the rally, so not inside the city's strike range),
-- else the nearest sent land unit (ties: lower unit id), so the team
-- assembles where the army stands. Returns the unit and its distance.
local function ChooseRally(tArmy, pCity)
	local function Better(pUnit, iD, pBest, iBest)
		return iBest == nil or iD < iBest or (iD == iBest and pUnit:GetID() < pBest:GetID());
	end
	local pRallyUnit, iRallyDistance = nil, nil;
	local pAnyUnit, iAnyDistance = nil, nil;
	for _, pUnit in ipairs(tArmy) do
		if tArmyUnits[pUnit:GetType()] ~= nil then
			local iD = Map.GetPlotDistance(pUnit:GetX(), pUnit:GetY(), pCity:GetX(), pCity:GetY());
			if Better(pUnit, iD, pAnyUnit, iAnyDistance) then pAnyUnit, iAnyDistance = pUnit, iD; end
			local pPlot = Map.GetPlot(pUnit:GetX(), pUnit:GetY());
			local bWater = pPlot ~= nil and pPlot.IsWater ~= nil and pPlot:IsWater();
			if iD >= DIRECTOR_RALLY_MIN_DISTANCE and not bWater and Better(pUnit, iD, pRallyUnit, iRallyDistance) then
				pRallyUnit, iRallyDistance = pUnit, iD;
			end
		end
	end
	if pRallyUnit == nil then return pAnyUnit, iAnyDistance; end
	return pRallyUnit, iRallyDistance;
end

-- Whether the army can walk to the city: the shortest path from the rally
-- unit to a land plot next to the city (UnitManager.GetMoveToPath, gameplay
-- UnitManager table per the XP2 DLL, Pirates scenario precedent; it returns
-- the path's plots, an empty table when there is none; a path into the enemy
-- city plot itself depends on the unit's attacks left, so it is not asked)
-- must be at most DIRECTOR_PATH_FACTOR times the distance (+1 in case the
-- start plot is listed). Without a path query, the rally unit must stand on
-- the city's landmass. Returns true or false, the reason, and the path
-- length (nil when the landmass was used).
local bPathReadWarned = false;
local function CheckLandRoute(pUnit, pCity, iDistance)
	local iX, iY = pCity:GetX(), pCity:GetY();
	local iUX, iUY = pUnit:GetX(), pUnit:GetY();
	-- A rally unit next to the city is already there.
	if iDistance <= 1 then return true, nil, 1; end
	local fnPath = UnitManager ~= nil and UnitManager.GetMoveToPath or nil;
	if fnPath ~= nil then
		local iBest, sError = nil, nil;
		for iDirection = 0, iDirections - 1 do
			local pPlot = Map.GetAdjacentPlot(iX, iY, iDirection);
			if pPlot ~= nil and not pPlot:IsWater() then
				local bOk, tPath = pcall(fnPath, pUnit, pPlot:GetIndex());
				if not bOk or type(tPath) ~= "table" then
					sError = bOk and ("it returned " .. type(tPath)) or tostring(tPath);
					break;
				end
				if #tPath > 0 and (iBest == nil or #tPath < iBest) then iBest = #tPath; end
			end
		end
		if sError == nil then
			if iBest == nil then
				return false, "no land path from the army at (" .. iUX .. "," .. iUY .. ")", nil;
			end
			if iBest > DIRECTOR_PATH_FACTOR * iDistance + 1 then
				return false, "the land path from the army at (" .. iUX .. "," .. iUY .. ") is " .. iBest
					.. " plots for a distance of " .. iDistance .. " (at most " .. DIRECTOR_PATH_FACTOR .. "x)", iBest;
			end
			return true, nil, iBest;
		end
		if not bPathReadWarned then
			bPathReadWarned = true;
			print("Rose AI: War director cannot read land paths (" .. sError .. "); the landmass test is used");
		end
	end
	local bOk, bSame = pcall(function()
		return Map.GetPlot(iUX, iUY):GetAreaID() == Map.GetPlot(iX, iY):GetAreaID();
	end);
	if bOk and bSame == false then
		return false, "the army at (" .. iUX .. "," .. iUY .. ") is on another landmass", nil;
	end
	return true, nil, nil;
end

-- An enemy major with DIRECTOR_THREAT_UNITS or more visible land combat units
-- on our land (plots we own; units in their own territory do not count,
-- 2026-10-18; the tiles of a city just taken are ours, so units on them
-- count) within DIRECTOR_THREAT_RADIUS tiles of one of our
-- cities: the enemy, the city and the count (lowest enemy id first, then our
-- cities in order), or nil.
local function FindThreat(pPlayer, tSince)
	local iPlayerID = pPlayer:GetID();
	local pVisibility = PlayersVisibility ~= nil and PlayersVisibility[iPlayerID] or nil;
	local tCities = {};
	for _, pCity in pPlayer:GetCities():Members() do table.insert(tCities, pCity); end
	local tEnemyIDs = {};
	for iOtherID in pairs(tSince) do table.insert(tEnemyIDs, iOtherID); end
	table.sort(tEnemyIDs);
	for _, iOtherID in ipairs(tEnemyIDs) do
		local pOther = Players[iOtherID];
		if pOther ~= nil and pOther:IsAlive() and pOther:IsMajor() then
			local tCount = {};
			for _, pUnit in pOther:GetUnits():Members() do
				local iX, iY = pUnit:GetX(), pUnit:GetY();
				local pPlot = Map.GetPlot(iX, iY);
				if tLandCombatUnits[pUnit:GetType()] and pPlot ~= nil and pPlot:GetOwner() == iPlayerID
					and (pVisibility == nil or pVisibility:IsVisible(iX, iY)) then
					for i, pCity in ipairs(tCities) do
						if Map.GetPlotDistance(iX, iY, pCity:GetX(), pCity:GetY()) <= DIRECTOR_THREAT_RADIUS then
							tCount[i] = (tCount[i] or 0) + 1;
						end
					end
				end
			end
			for i, pCity in ipairs(tCities) do
				if (tCount[i] or 0) >= DIRECTOR_THREAT_UNITS then return iOtherID, pCity, tCount[i]; end
			end
		end
	end
	return nil;
end

-- Candidate cities in order, { City, Owner, Distance, Rally, Population,
-- Defense, Bombard }, or nil and a reason.
local function FindDirectorTargets(pPlayer, tSince, iTurn, tOrders, tLatest, bAdvantage)
	local iPlayerID = pPlayer:GetID();
	local tOwnCities = {};
	for _, pCity in pPlayer:GetCities():Members() do
		table.insert(tOwnCities, pCity);
	end
	if #tOwnCities == 0 then return nil, "no city of our own"; end
	local pVisibility = PlayersVisibility ~= nil and PlayersVisibility[iPlayerID] or nil;
	if pVisibility == nil then return nil, "no visibility data"; end
	local iReach = bAdvantage and DIRECTOR_REACH_ADVANTAGE or DIRECTOR_REACH;
	local iBombard = nil;

	-- Locked cities: those of live orders, and for DIRECTOR_FAILED_CITY_LOCK
	-- turns after its end, the city of an ended order.
	local tOrdered = {};
	for _, kOrder in ipairs(tOrders) do
		if not kOrder.Ended or iTurn - kOrder.EndTurn < DIRECTOR_FAILED_CITY_LOCK then
			tOrdered[kOrder.X .. "," .. kOrder.Y] = true;
		end
	end
	local tWarIDs = {};
	for iOtherID, iSince in pairs(tSince) do
		if iTurn - iSince >= DIRECTOR_MIN_WAR_TURNS then table.insert(tWarIDs, iOtherID); end
	end
	table.sort(tWarIDs);
	local tEnemyIDs = {};
	local iNextFree = nil;
	for _, iOtherID in ipairs(tWarIDs) do
		local iLatest = tLatest[iOtherID];
		if not bAdvantage and iLatest ~= nil and iTurn - iLatest < DIRECTOR_ENEMY_COOLDOWN then
			local iFree = iLatest + DIRECTOR_ENEMY_COOLDOWN;
			if iNextFree == nil or iFree < iNextFree then iNextFree = iFree; end
		else
			table.insert(tEnemyIDs, iOtherID);
		end
	end
	if #tEnemyIDs == 0 then
		if iNextFree ~= nil then
			return nil, "a siege was ordered against every enemy within " .. DIRECTOR_ENEMY_COOLDOWN
				.. " turns (next turn " .. iNextFree .. ")";
		end
		return nil, "no war with a major of " .. DIRECTOR_MIN_WAR_TURNS .. "+ turns";
	end

	local tCandidates = {};
	local iInReach, iTooStrong, iBusy = 0, 0, 0;
	local iWeakest = nil;
	for _, iOwner in ipairs(tEnemyIDs) do
		local pOwner = Players[iOwner];
		if pOwner ~= nil and pOwner:IsAlive() and pOwner:IsMajor() then
			for _, pCity in pOwner:GetCities():Members() do
				local iX, iY = pCity:GetX(), pCity:GetY();
				if pVisibility:IsRevealed(iX, iY) then
					local pRally, iDistance = nil, nil;
					for _, pOwn in ipairs(tOwnCities) do
						local iD = Map.GetPlotDistance(pOwn:GetX(), pOwn:GetY(), iX, iY);
						if iDistance == nil or iD < iDistance then pRally, iDistance = pOwn, iD; end
					end
					if iDistance <= iReach then
						iInReach = iInReach + 1;
						if tOrdered[iX .. "," .. iY] then
							iBusy = iBusy + 1;
						else
							local iDefense = ReadCityDefense(pCity);
							if iBombard == nil then iBombard = GetBestBombard(pPlayer); end
							if iDefense ~= nil and iDefense > iBombard + DIRECTOR_DEFENSE_MARGIN then
								iTooStrong = iTooStrong + 1;
								if iWeakest == nil or iDefense < iWeakest then iWeakest = iDefense; end
							else
								table.insert(tCandidates, { City = pCity, Owner = iOwner, Distance = iDistance,
									Rally = pRally, Population = pCity:GetPopulation(), Defense = iDefense,
									Bombard = iBombard, Order = #tCandidates });
							end
						end
					end
				end
			end
		end
	end
	if #tCandidates == 0 then
		if iInReach == 0 then
			return nil, "no revealed enemy city within " .. iReach .. " tiles of our cities";
		end
		if iTooStrong > 0 then
			return nil, iTooStrong .. " enemy cities within reach have defense above our best bombard "
				.. tostring(iBombard) .. " + " .. DIRECTOR_DEFENSE_MARGIN .. " (weakest " .. iWeakest .. ")"
				.. (iBusy > 0 and ", and our sieges hold the others or failed there within " .. DIRECTOR_FAILED_CITY_LOCK .. " turns" or "");
		end
		return nil, "every city within reach is under a siege we ordered or held one off within "
			.. DIRECTOR_FAILED_CITY_LOCK .. " turns";
	end
	table.sort(tCandidates, function(a, b)
		if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
		if a.Population ~= b.Population then return a.Population > b.Population; end
		return a.Order < b.Order;
	end);
	return tCandidates, nil;
end

function TryWarDirector(iPlayerID)
	if not WAR_DIRECTOR_ENABLED then return; end
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local tSince = UpdateNuclearWarSince(pPlayer, iTurn);
	local tOrders, tLatest = PruneDirectorOrders(pPlayer, iTurn, tSince);
	ReportDirectorArmies(pPlayer, tOrders, iTurn);
	if next(tSince) == nil then
		ReportDirectorReason(iPlayerID, nil);
		return;
	end
	if IsLatched(iPlayerID, RECOVERY_LATCH) then
		ReportDirectorReason(iPlayerID, "Military Recovery is latched");
		return;
	end
	local iNextAttempt = pPlayer:GetProperty(DIRECTOR_NEXT_ATTEMPT_PROPERTY);
	if type(iNextAttempt) == "number" and iTurn < iNextAttempt then
		ReportDirectorReason(iPlayerID, "retry after a refused start at turn " .. iNextAttempt);
		return;
	end
	-- Defend first: City Defense (Priority 4, like the director's siege) takes
	-- a recruiting siege's units when our own cities are threatened.
	local iThreat, pThreatened, iThreatUnits = FindThreat(pPlayer, tSince);
	if iThreat ~= nil then
		ReportDirectorReason(iPlayerID, "player " .. iThreat .. " has " .. iThreatUnits .. " land combat units on our land within "
			.. DIRECTOR_THREAT_RADIUS .. " tiles of our city " .. tostring(pThreatened:GetName()) .. " (defend first)");
		return;
	end
	local bAdvantage = IsLatched(iPlayerID, ADVANTAGE_LATCH);
	local tCandidates, sReason = FindDirectorTargets(pPlayer, tSince, iTurn, tOrders, tLatest, bAdvantage);
	if tCandidates == nil then
		ReportDirectorReason(iPlayerID, sReason);
		return;
	end

	-- The first city, nearest first, whose army passes every rule.
	local tOwnCentres = {};
	for _, pCity in pPlayer:GetCities():Members() do
		tOwnCentres[pCity:GetX() .. "," .. pCity:GetY()] = true;
	end
	local tReserved = {};
	for _, kOrder in ipairs(tOrders) do
		for _, iUnit in ipairs(kOrder.Units) do tReserved[iUnit] = true; end
	end
	local kTarget, tArmy, iStrike, iNeed, iLand, bWalls = nil, nil, 0, 0, 0, false;
	local pRallyUnit, iRallyDistance, iPath = nil, nil, nil;
	local tRefused = { army = 0, siege = 0, far = 0, route = 0 };
	local sFirstRefusal = nil;
	for _, kCandidate in ipairs(tCandidates) do
		local pCandidate = kCandidate.City;
		local iCandidateNeed, bCandidateWalls, bBreakers = SiegeNeeds(pCandidate, kCandidate.Defense);
		local tUnits, iUnitsStrike, iUnitsLand = GatherSiegeArmy(pPlayer, kCandidate.Rally, pCandidate, tOwnCentres, tReserved, bBreakers);
		local sRule, sWhy = nil, nil;
		local pUnit, iDistance, iPathLength = nil, nil, nil;
		if iUnitsLand < DIRECTOR_MIN_UNITS then
			sRule, sWhy = "army", "an army of " .. iUnitsLand .. " land units near our city "
				.. tostring(kCandidate.Rally:GetName()) .. " (needs " .. DIRECTOR_MIN_UNITS .. ")";
		elseif iUnitsStrike < iCandidateNeed then
			sRule, sWhy = "siege", iUnitsStrike .. " siege units in its army (needs " .. iCandidateNeed
				.. ": walls " .. (bCandidateWalls and "yes" or "no") .. " defense " .. tostring(kCandidate.Defense) .. ")";
		else
			pUnit, iDistance = ChooseRally(tUnits, pCandidate);
			if iDistance > DIRECTOR_MAX_ARMY_DISTANCE then
				sRule, sWhy = "far", "the army is " .. iDistance .. " tiles from it (needs " .. DIRECTOR_MAX_ARMY_DISTANCE .. ")";
			else
				local bRoute, sRoute;
				bRoute, sRoute, iPathLength = CheckLandRoute(pUnit, pCandidate, iDistance);
				if not bRoute then sRule, sWhy = "route", sRoute; end
			end
		end
		if sRule == nil then
			kTarget, tArmy, iStrike, iNeed, iLand, bWalls = kCandidate, tUnits, iUnitsStrike, iCandidateNeed, iUnitsLand, bCandidateWalls;
			pRallyUnit, iRallyDistance, iPath = pUnit, iDistance, iPathLength;
			break;
		end
		tRefused[sRule] = tRefused[sRule] + 1;
		if sFirstRefusal == nil then
			sFirstRefusal = "nearest " .. tostring(pCandidate:GetName()) .. " (" .. pCandidate:GetX() .. ","
				.. pCandidate:GetY() .. "): " .. sWhy;
		end
	end
	if kTarget == nil then
		ReportDirectorReason(iPlayerID, #tCandidates .. " enemy cities within reach, none ordered (army under "
			.. DIRECTOR_MIN_UNITS .. " units " .. tRefused.army .. ", too few siege units " .. tRefused.siege
			.. ", army over " .. DIRECTOR_MAX_ARMY_DISTANCE .. " tiles away " .. tRefused.far
			.. ", no land route " .. tRefused.route .. "); " .. sFirstRefusal);
		return;
	end
	ReportDirectorReason(iPlayerID, nil);

	local pCity = kTarget.City;
	local pMilitaryAI = pPlayer:GetAi_Military();
	local pTargetPlot = Map.GetPlot(pCity:GetX(), pCity:GetY());
	local pRallyPlot = Map.GetPlot(pRallyUnit:GetX(), pRallyUnit:GetY());
	if pMilitaryAI == nil or pTargetPlot == nil or pRallyPlot == nil then return; end
	local iOperationID = pMilitaryAI:StartScriptedOperationWithTargetAndRally(
		DIRECTOR_OPERATION_NAME, kTarget.Owner, pTargetPlot:GetIndex(), pRallyPlot:GetIndex());
	-- The DLL returns the operation id, or -1 (no slot or no operation) or 0
	-- (an early refusal).
	if type(iOperationID) ~= "number" or iOperationID <= 0 then
		pPlayer:SetProperty(DIRECTOR_NEXT_ATTEMPT_PROPERTY, iTurn + DIRECTOR_RETRY_TURNS);
		print("Rose AI: War director start rejected for player " .. iPlayerID
			.. " turn " .. iTurn .. " against player " .. kTarget.Owner
			.. " plot (" .. pCity:GetX() .. "," .. pCity:GetY() .. ")"
			.. " result " .. tostring(iOperationID));
		return;
	end
	-- AddUnitToScriptedOperation returns nothing (Nubia does not check it).
	local tUnitIDs = {};
	for _, pUnit in ipairs(tArmy) do
		pMilitaryAI:AddUnitToScriptedOperation(iOperationID, pUnit:GetID());
		table.insert(tUnitIDs, pUnit:GetID());
	end
	table.insert(tOrders, { Enemy = kTarget.Owner, Turn = iTurn, X = pCity:GetX(), Y = pCity:GetY(),
		Units = tUnitIDs });
	WriteDirectorOrders(pPlayer, tOrders);
	print("Rose AI: War director ordered for player " .. iPlayerID
		.. " turn " .. iTurn
		.. " against player " .. kTarget.Owner
		.. " city " .. tostring(pCity:GetName())
		.. " plot (" .. pCity:GetX() .. "," .. pCity:GetY() .. ")"
		.. " distance " .. kTarget.Distance
		.. " from our city " .. tostring(kTarget.Rally:GetName())
		.. " population " .. kTarget.Population
		.. " walls " .. (bWalls and "yes" or "no")
		.. " defense " .. tostring(kTarget.Defense)
		.. " bombard " .. tostring(kTarget.Bombard)
		.. " advantage " .. (bAdvantage and "yes" or "no")
		.. " units " .. #tArmy .. " siege " .. iStrike .. " needs " .. iNeed .. " land " .. iLand
		.. " rally (" .. pRallyUnit:GetX() .. "," .. pRallyUnit:GetY() .. ") distance " .. iRallyDistance
		.. " path " .. tostring(iPath or "landmass")
		.. " operation " .. iOperationID
		.. " unit ids " .. table.concat(tUnitIDs, ","));
end

-- Taking a city we ordered a siege on drops that order, so the next siege
-- against its old owner can be ordered at the next turn start (city after
-- city); other captures change nothing. Gameplay event: (capturer, previous
-- owner, city id, x, y), as in Firaxis' Nubia and Alexander scenarios.
local function OnDirectorCityConquered(iCapturerID, iOwnerID, iCityID, iX, iY)
	if not WAR_DIRECTOR_ENABLED then return; end
	local pPlayer = Players[iCapturerID];
	if not IsEligibleAIPlayer(pPlayer) or iOwnerID == nil or iOwnerID == iCapturerID then return; end
	local tOrders = ReadDirectorOrders(pPlayer);
	local tKept = {};
	for _, kOrder in ipairs(tOrders) do
		if not (kOrder.Enemy == iOwnerID and kOrder.X == iX and kOrder.Y == iY) then table.insert(tKept, kOrder); end
	end
	if #tKept == #tOrders then return; end
	WriteDirectorOrders(pPlayer, tKept);
	print("Rose AI: War director player " .. iCapturerID .. " took the city at ("
		.. tostring(iX) .. "," .. tostring(iY) .. ") from player " .. iOwnerID
		.. " turn " .. Game.GetCurrentGameTurn() .. "; the next siege against them may be ordered");
end
if GameEvents.CityConquered ~= nil then
	GameEvents.CityConquered.Add(function(iCapturerID, iOwnerID, iCityID, iX, iY)
		local bOk, sError = pcall(OnDirectorCityConquered, iCapturerID, iOwnerID, iCityID, iX, iY);
		if not bOk then
			print("Rose AI ERROR: War director capture handler failed player "
				.. tostring(iCapturerID) .. ": " .. tostring(sError));
		end
	end);
end

end -- the war director block

-- ============================================================================
-- Operations against city-states (round 7, W27, 2026-10-15). Print-only.
--
-- In the 2026-10-15 game 15 planned sieges assembled against a city-state the
-- attacker had 2 or more envoys in (Maori was suzerain of its target) and
-- waited at the walls for a war the diplomacy AI never declared, about 13
-- turns a cycle, then picked the same city again. For each eligible AI this
-- prints a line when an operation against a city-state appears or when that
-- city-state's envoys (ours), suzerain or war state change, and one when the
-- operation is gone. HasOperationAgainst is the only operation read gameplay
-- Lua has: it does not give the type or phase, so "at war no" marks the
-- undeclared case. Since round 9 it asks the existence form (any live
-- operation of ours against that city-state; until then the two-argument
-- form, which only saw a team mustering on its rally plot). Count siege
-- cycles from AI_Operation.csv. Envoys come from the InGame
-- bridge ("?" when it cannot answer); a minor that takes no envoys (Free
-- Cities) is skipped. Nothing is changed. The table is local and not saved,
-- so the lines repeat after a reload. Diagnostic games only (ROSE_VERBOSE_LOGS).
-- ============================================================================
local tCityStateOperations = {};

-- Envoys and suzerain; false for a minor that takes no envoys; nil when the
-- bridge cannot answer.
local function ReadEnvoys(iMinorID, iPlayerID)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil or kBridge.GetEnvoyInfo == nil then return nil; end
	local bOk, iEnvoys, iSuzerain = pcall(kBridge.GetEnvoyInfo, iMinorID, iPlayerID);
	if not bOk then return nil; end
	return iEnvoys, iSuzerain;
end

local function DescribeCapital(pPlayer)
	local pCity = pPlayer:GetCities():GetCapitalCity();
	if pCity == nil then return "none"; end
	return pCity:GetX() .. "," .. pCity:GetY();
end

local function UpdateCityStateOperations(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then
		tCityStateOperations[iPlayerID] = nil;
		return;
	end
	local iTurn = Game.GetCurrentGameTurn();
	local tOld = tCityStateOperations[iPlayerID] or {};
	local tNow = {};
	local pDiplomacy = pPlayer:GetDiplomacy();
	for _, pMinor in ipairs(PlayerManager.GetAliveMinors()) do
		local iMinorID = pMinor:GetID();
		if HasOperationAgainst(pPlayer, iMinorID) then
			local iEnvoys, iSuzerain = ReadEnvoys(iMinorID, iPlayerID);
			if iEnvoys ~= false then
				local sState = "envoys " .. tostring(iEnvoys or "?")
					.. " suzerain " .. tostring(iSuzerain or "?")
					.. " at war " .. (pDiplomacy:IsAtWarWith(iMinorID) and "yes" or "no");
				local kOld = tOld[iMinorID];
				local kNow = { State = sState, Since = (kOld ~= nil) and kOld.Since or iTurn };
				tNow[iMinorID] = kNow;
				if kOld == nil or kOld.State ~= sState then
					print("Rose AI: Operation against city-state for player " .. iPlayerID
						.. " turn " .. iTurn
						.. ": city-state " .. iMinorID
						.. " capital " .. DescribeCapital(pMinor)
						.. " " .. sState
						.. " since turn " .. kNow.Since);
				end
			end
		end
	end
	for iMinorID, kOld in pairs(tOld) do
		if tNow[iMinorID] == nil then
			print("Rose AI: Operation against city-state ended for player " .. iPlayerID
				.. " turn " .. iTurn
				.. ": city-state " .. iMinorID
				.. " since turn " .. kOld.Since);
		end
	end
	tCityStateOperations[iPlayerID] = tNow;
end

-- ============================================================================
-- Operation read probe (round 8, 2026-10-17). Print-only.
--
-- The round 8 DLL trace read the binding as HasOperationAgainst(player,
-- requireReady, maxDist, teamPlotSlot): the two-argument call Rose uses
-- elsewhere tests whether a unit of an operation's team stands on its rally
-- plot, and slot -1 makes it an existence test (any live operation of ours
-- against that player, scripted ones included; confirmed in 20261018, 7 of 7
-- conclusive director orders, and used by the director, the nuclear
-- preference and the city-state report since round 9). For the record of every
-- game, this asks, for each eligible AI and every other alive major
-- and city-state, the existence form (false, 0, -1) and the ready form (true,
-- 0, -1), and prints a line when either answer changes, with the two-argument
-- answer, the war state and our recorded director orders against that player.
-- The answer cannot count operations: an order is conclusive only when the
-- probe read "exists no" before it, since a planned siege that outlived its
-- declaration, a Military Victory slot, a reactive assault, a nuclear or naval
-- operation, or an earlier director order against the same player already
-- reads yes; check AI_Operation.csv. A failed read keeps the last state (the error prints
-- once). Nothing is changed; the table is local, so the lines repeat after a
-- reload. Diagnostic games only (ROSE_VERBOSE_LOGS).
-- ============================================================================
local tOperationProbe = {};
local bOperationProbeWarned = false;

-- "yes", "no", "?" when the call fails, otherwise the value returned. A nil
-- slot makes the two-argument call.
local function ReadOperationProbe(pMilitaryAI, iOtherID, bReady, iSlot)
	local bOk, value = pcall(function()
		if iSlot == nil then return pMilitaryAI:HasOperationAgainst(iOtherID, bReady); end
		return pMilitaryAI:HasOperationAgainst(iOtherID, bReady, 0, iSlot);
	end);
	if not bOk then
		if not bOperationProbeWarned then
			bOperationProbeWarned = true;
			print("Rose AI ERROR: Operation probe read failed: " .. tostring(value));
		end
		return "?";
	end
	if value == true then return "yes"; end
	if value == false then return "no"; end
	return tostring(value);
end

local function UpdateOperationProbe(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then
		tOperationProbe[iPlayerID] = nil;
		return;
	end
	local pMilitaryAI = pPlayer:GetAi_Military();
	if pMilitaryAI == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local pDiplomacy = pPlayer:GetDiplomacy();
	local tOrderTurns = {};
	for _, kOrder in ipairs(ReadDirectorOrders(pPlayer)) do
		tOrderTurns[kOrder.Enemy] = tOrderTurns[kOrder.Enemy] or {};
		table.insert(tOrderTurns[kOrder.Enemy], kOrder.Turn);
	end
	local tOthers = {};
	for _, pOther in ipairs(PlayerManager.GetAliveMajors()) do
		if pOther:GetID() ~= iPlayerID then table.insert(tOthers, { ID = pOther:GetID(), Kind = "major" }); end
	end
	for _, pOther in ipairs(PlayerManager.GetAliveMinors()) do
		table.insert(tOthers, { ID = pOther:GetID(), Kind = "city-state" });
	end
	local tOld = tOperationProbe[iPlayerID] or {};
	local tNow = {};
	for _, kOther in ipairs(tOthers) do
		local iOtherID = kOther.ID;
		local sOld = tOld[iOtherID] or "exists no ready no";
		local sExists = ReadOperationProbe(pMilitaryAI, iOtherID, false, -1);
		local sReady = ReadOperationProbe(pMilitaryAI, iOtherID, true, -1);
		if sExists == "?" or sReady == "?" then
			tNow[iOtherID] = tOld[iOtherID];
		else
			local sState = "exists " .. sExists .. " ready " .. sReady;
			tNow[iOtherID] = sState;
			if sState ~= sOld then
				local tTurns = tOrderTurns[iOtherID];
				if tTurns ~= nil then table.sort(tTurns); end
				print("Rose AI: Operation probe for player " .. iPlayerID
					.. " turn " .. iTurn
					.. " against " .. kOther.Kind .. " " .. iOtherID
					.. ": " .. sState .. " (was " .. sOld .. ")"
					.. " rally " .. ReadOperationProbe(pMilitaryAI, iOtherID, false, nil)
					.. " at war " .. (pDiplomacy:IsAtWarWith(iOtherID) and "yes" or "no")
					.. " director orders " .. (tTurns ~= nil and ("turn " .. table.concat(tTurns, ",")) or "none"));
			end
		end
	end
	tOperationProbe[iPlayerID] = tNow;
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
	local bOk, sError = pcall(TryNuclearStrike, iPlayerID);
	if not bOk then
		print("Rose AI ERROR: Nuclear strike failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
	bOk, sError = pcall(TryWarDirector, iPlayerID);
	if not bOk then
		print("Rose AI ERROR: War director failed player "
			.. tostring(iPlayerID) .. ": " .. tostring(sError));
	end
	if ROSE_VERBOSE_LOGS then
		bOk, sError = pcall(UpdateCityStateOperations, iPlayerID);
		if not bOk then
			print("Rose AI ERROR: City-state operation report failed player "
				.. tostring(iPlayerID) .. ": " .. tostring(sError));
		end
		bOk, sError = pcall(UpdateOperationProbe, iPlayerID);
		if not bOk then
			print("Rose AI ERROR: Operation probe failed player "
				.. tostring(iPlayerID) .. ": " .. tostring(sError));
		end
	end
	TryStartNavalSuperiority(iPlayerID);
end

GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);
GameEvents.PlayerTurnStartComplete.Add(OnPlayerTurnStartComplete);

print("Rose AI: Gameplay support script loaded");
