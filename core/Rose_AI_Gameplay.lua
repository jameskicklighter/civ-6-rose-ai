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
-- value, so enemies we already run an operation against (HasOperationAgainst)
-- come first: both launches in 20261009b matched one.
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
-- Pacing (James, 2026-10-09): a refused or unfired order is not repeated for
-- NUCLEAR_ATTEMPT_COOLDOWN turns, a launch for NUCLEAR_LAUNCH_COOLDOWN (1: the
-- operation ends on its launch turn, so the next order may follow on the next
-- turn); the device count, the delivery rule, the slot limit, war weariness
-- and the World Congress do the rest. A city the AI itself nuked within
-- NUCLEAR_RECENT_TURNS turns is not a target, so a stockpile is spread over
-- the enemy's cities instead of landing twice on one (James, 2026-10-09).
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

-- True when one of our operations targets iEnemyID (any operation type; the
-- only operation read gameplay Lua has). XP2 DLL binding: (player, bool, int,
-- int), the bool false asks only whether an operation targets that player.
local bOperationReadWarned = false;
local function HasOperationAgainst(pPlayer, iEnemyID)
	local pMilitaryAI = pPlayer:GetAi_Military();
	if pMilitaryAI == nil then return false; end
	local bOk, bHas = pcall(function() return pMilitaryAI:HasOperationAgainst(iEnemyID, false); end);
	if not bOk and not bOperationReadWarned then
		bOperationReadWarned = true;
		print("Rose AI ERROR: HasOperationAgainst failed; nuclear targets ignore our operations: " .. tostring(bHas));
	end
	return bOk and bHas == true;
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
	TryStartNavalSuperiority(iPlayerID);
end

GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);
GameEvents.PlayerTurnStartComplete.Add(OnPlayerTurnStartComplete);

print("Rose AI: Gameplay support script loaded");
