-- ============================================================================
-- Rose AI: civic grants, frozen civic research and the dead policy card repair.
-- Runs from PlayerTurnStarted through GrantCivicOrRepairPolicies: research
-- check, then repair, then at most one civic grant per AI player per turn.
-- State: ROSE_CIVIC_GRANT_TURN, ROSE_CIVIC_GRANT_SKIP, ROSE_CIVIC_UNFREEZE,
-- ROSE_CIVIC_STALL, ROSE_POLICY_REPAIR_CLEAR_TURN, ROSE_POLICY_REPAIR_ATTEMPTS.
-- AGENTS.md "Government civic auto-grant", "Dead policy card repair".
-- ============================================================================

local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetDeadPolicySlots = RoseMod.GetDeadPolicySlots;
local Guard = RoseMod.Guard;
local Codec = RoseMod.Codec;

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
-- Civic grants: one per eligible AI player per game turn, from turn start only.
-- SetCivic completes the civic synchronously (its callbacks run before it
-- returns), so grants never run from a civic callback; bGrantingCivic and the
-- turn property stop re-entry and a second grant in one player-turn. The civic
-- in progress is never granted (that freezes the AI's civic research), and
-- nothing is granted when it cannot be read. AGENTS.md "Government civic auto-grant".
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

-- The civic in progress when it is due this turn (one turn or less to go),
-- else nil; also nil when none is in progress, it is already owned or both
-- queries fail (printed once). -1 when due but unidentified (fallback query).
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
-- Frozen civic research: an AI with an owned civic in progress (granted by an
-- older Rose) never completes another. Seen on two consecutive turn starts it
-- is moved to the cheapest civic it can research (SetProgressingCivic, as the
-- Black Death scenario does), at most CIVIC_UNFREEZE_MAX_ATTEMPTS times. A due
-- civic that does not complete for CIVIC_STALL_REPORT_TURNS turn starts is
-- only reported. AGENTS.md "Government civic auto-grant".
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

local function UnfreezeCivicResearch(pPlayer, iPlayerID, pCulture, iTurn, iFrozen)
	local tState = Codec.ReadNumbers(pPlayer:GetProperty(CIVIC_UNFREEZE_PROPERTY));
	if tState[1] == iFrozen and tState[3] == iTurn then return; end -- already handled this turn
	if tState[1] ~= iFrozen then
		-- First sighting: wait one turn start, in case the AI is only between
		-- a completion and its next pick. The record is cleared at any turn
		-- start that finds a civic the AI does not own in progress.
		pPlayer:SetProperty(CIVIC_UNFREEZE_PROPERTY, Codec.Numbers(iFrozen, 0, iTurn));
		return;
	end
	local iAttempts = tState[2] or 0;
	if iAttempts >= CIVIC_UNFREEZE_MAX_ATTEMPTS then return; end
	iAttempts = iAttempts + 1;
	pPlayer:SetProperty(CIVIC_UNFREEZE_PROPERTY, Codec.Numbers(iFrozen, iAttempts, iTurn));

	local sHead = "Civic research frozen for AI player " .. iPlayerID .. " turn " .. iTurn
		.. ": " .. GetCivicTypeName(iFrozen) .. " in progress is already owned ("
		.. DescribeCivicProgress(pCulture, iFrozen) .. ")";
	local iNext = FindCivicToResearch(pCulture);
	if iNext == nil then
		pPlayer:SetProperty(CIVIC_UNFREEZE_PROPERTY, Codec.Numbers(iFrozen, CIVIC_UNFREEZE_MAX_ATTEMPTS, iTurn));
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
	local tState = Codec.ReadNumbers(pPlayer:GetProperty(CIVIC_STALL_PROPERTY));
	local iCount = 1;
	if tState[1] == iCivic and tState[3] == iTurn then
		return; -- second turn start in the same turn
	elseif tState[1] == iCivic and tState[3] == iTurn - 1 then
		iCount = (tState[2] or 0) + 1;
	end
	pPlayer:SetProperty(CIVIC_STALL_PROPERTY, Codec.Numbers(iCivic, iCount, iTurn));
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
-- Dead policy card repair: slots the InGame audit reports holding a card with
-- no modifiers (a base-game bug) are cleared just before a deck commit (the AI's
-- own civic due, or a granted tree-fill civic), never before a government
-- civic; CultureAI refills them at the commit. POLICY_REPAIR_ON_COMMIT_TURN =
-- false clears on a turn without a commit instead. A card is cleared at most
-- POLICY_REPAIR_MAX_ATTEMPTS times in a row, then left POLICY_REPAIR_BACKOFF_TURNS
-- turns. AGENTS.md "Dead policy card repair".
-- ============================================================================
local POLICY_REPAIR_ON_COMMIT_TURN = true;
local POLICY_REPAIR_MAX_ATTEMPTS = 3;
local POLICY_REPAIR_BACKOFF_TURNS = 10;
local POLICY_REPAIR_CLEAR_TURN = "ROSE_POLICY_REPAIR_CLEAR_TURN";
local POLICY_REPAIR_ATTEMPTS = "ROSE_POLICY_REPAIR_ATTEMPTS";

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

	local tAttempts = Codec.ReadPolicyAttempts(pPlayer:GetProperty(POLICY_REPAIR_ATTEMPTS));
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
	pPlayer:SetProperty(POLICY_REPAIR_ATTEMPTS, Codec.PolicyAttempts(tAttempts));
	if iCleared == 0 then return false; end

	pPlayer:SetProperty(POLICY_REPAIR_CLEAR_TURN, iTurn);
	print("Rose AI: Policy repair for AI player " .. iPlayerID .. " turn " .. iTurn
		.. " cleared " .. iCleared .. " slots, refill by " .. sRefill);
	return true;
end

-- Unfreeze civic research if needed, repair dead cards, then grant at most one
-- civic. The repair runs first so a grant's own deck commit refills the slots;
-- it is skipped when a government civic is granted (cards die on those turns).
local function GrantCivicOrRepairPolicies(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();

	Guard("Civic research check", CheckCivicResearch, iPlayerID);

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
		Guard("Policy repair", RepairDeadPolicies, iPlayerID, sRefill);
	end

	Guard("Civic grant", GrantOneCivic, iPlayerID);
end

RoseMod.GrantCivicOrRepairPolicies = GrantCivicOrRepairPolicies;
