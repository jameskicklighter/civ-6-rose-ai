-- Rose AI InGame UI bridge for military strength, net Gold income and dead
-- policy slots, plus the policy-modifier audit behind them. These getters and
-- GameEffects are unavailable in the gameplay context.

print("Rose_AI_InGame: Rose AI: Loading InGame military-strength bridge");

if ExposedMembers.RoseAI == nil then ExposedMembers.RoseAI = {}; end
local RoseAI = ExposedMembers.RoseAI;

-- Per-turn diagnostic output (policy decks, slot lines, audit class changes).
-- Off for release; the standalone Rose Policy Audit (DIAG) mod is the test
-- instrument. Errors always print.
local ROSE_VERBOSE_LOGS = false;

function RoseGetMilitaryStrength(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return nil; end
	local pStats = pPlayer:GetStats();
	if pStats == nil then return nil; end
	return pStats:GetMilitaryStrengthWithoutTreasury();
end

RoseAI.GetMilitaryStrength = RoseGetMilitaryStrength;

-- Net Gold per turn (gross yield minus total maintenance), as the top panel
-- computes it, for the gameplay austerity latch. nil on any failure.
function RoseGetNetGoldIncome(iPlayerID)
	local bOk, iIncome = pcall(function()
		local pPlayer = Players[iPlayerID];
		if pPlayer == nil then return nil; end
		local pTreasury = pPlayer:GetTreasury();
		if pTreasury == nil then return nil; end
		return pTreasury:GetGoldYield() - pTreasury:GetTotalMaintenance();
	end);
	if not bOk or type(iIncome) ~= "number" then return nil; end
	return iIncome;
end

RoseAI.GetNetGoldIncome = RoseGetNetGoldIncome;

-- Stuck Trader diagnostic details (print-only; called from the gameplay
-- script). Uses route and unit queries Firaxis calls from UI scripts
-- (TradeOverview, UnitPanel, WorldInput). Each part is queried separately so
-- one failure still leaves the others; a failed part prints "?".
function RoseGetTraderDiagnostics(iPlayerID, iUnitID, iX, iY)
	local function Try(fn)
		local bOk, value = pcall(fn);
		if not bOk then return "?"; end
		return tostring(value);
	end
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return "player n/a"; end
	local pUnit = UnitManager.GetUnit(iPlayerID, iUnitID);

	local sPlayerRoutes = Try(function()
		local pTrade = pPlayer:GetTrade();
		return pTrade:GetNumOutgoingRoutes() .. "/" .. pTrade:GetOutgoingRouteCapacity();
	end);
	local sCityRoutes = Try(function()
		local pCity = CityManager.GetCityAt(iX, iY);
		if pCity == nil then return "none"; end
		return #pCity:GetTrade():GetOutgoingRoutes();
	end);
	-- A Trader's route starts in one of its owner's cities.
	local sUnitRoute = Try(function()
		local sFound = "none";
		for _, pCity in pPlayer:GetCities():Members() do
			for _, kRoute in ipairs(pCity:GetTrade():GetOutgoingRoutes()) do
				if kRoute.TraderUnitID == iUnitID then
					sFound = tostring(pCity:GetID()) .. "->"
						.. tostring(kRoute.DestinationCityPlayer) .. "/"
						.. tostring(kRoute.DestinationCityID);
				end
			end
		end
		return sFound;
	end);
	local sActivity = Try(function()
		local iActivity = UnitManager.GetActivityType(pUnit);
		for sName, iValue in pairs(ActivityTypes) do
			if iValue == iActivity then return sName; end
		end
		return iActivity;
	end);
	local sReady = Try(function() return pUnit:IsReadyToMove(); end);
	local sQueued = Try(function() return UnitManager.GetQueuedDestination(pUnit); end);
	local sOperation = Try(function() return UnitManager.GetOperationTypeName(pUnit); end);
	return "playerRoutes " .. sPlayerRoutes
		.. " cityRoutes " .. sCityRoutes
		.. " unitRoute " .. sUnitRoute
		.. " activity " .. sActivity
		.. " readyToMove " .. sReady
		.. " queuedDest " .. sQueued
		.. " uiOperation " .. sOperation;
end

RoseAI.GetTraderDiagnostics = RoseGetTraderDiagnostics;

-- Policy-modifier audit (HANDOFF W13, W15). GameEffects is only available in
-- UI contexts. For each major (humans included), every PolicyModifiers row of
-- a slotted policy and every GovernmentModifiers row of the current
-- government, except Rose's inactive ROSE_CHOICE_* signals, is matched against
-- live modifier instances owned by that player:
--   OK       an active instance with at least one subject
--   NOSUBJ   active instances, none with subjects (not necessarily a bug)
--   INACTIVE instances exist, none active
--   MISSING  no instance
-- Each audit records the player's dead slots (a slotted card with a MISSING
-- modifier) for RoseAI.GetDeadPolicySlots. The gameplay script clears AI slots
-- from that result, so like the strength bridge this feeds synchronized state
-- from a UI reading. With ROSE_VERBOSE_LOGS on, the deck is printed when it
-- changes, and a row when its class changes since the previous audit of that
-- player; rows new to the deck (and every row on the first audit after load)
-- only when not OK. Instance matching is by ModifierId and owner player, so a
-- ModifierId shared by two sources reports the same counts for both.
-- Runs for all alive majors at TurnBegin, and for players marked dirty by civic,
-- government, or policy events once the engine finishes publishing the batch.
local AUDIT_SIGNAL_PREFIX = "ROSE_CHOICE_";
local tAuditModsBySource = nil;
local tAuditRelevant = nil;
local tAuditDeck = {};
local tAuditClass = {};
local tAuditDirty = {};
-- player ID -> { Turn, Slots = { { Slot, PolicyType, Missing } } } from the
-- latest audit of that player; read by RoseAI.GetDeadPolicySlots.
local tDeadPolicySlots = {};

local function BuildAuditTables()
	if tAuditModsBySource ~= nil then return; end
	-- The signals' ModifierIds are the RoseChoiceBiases BiasIds, all prefixed
	-- ROSE_CHOICE_ (AI_Policies.sql, AI_Beliefs.sql). Read the table when it is
	-- visible here and keep the prefix as a fallback.
	local tSignals = {};
	pcall(function()
		if GameInfo.RoseChoiceBiases ~= nil then
			for row in GameInfo.RoseChoiceBiases() do tSignals[row.BiasId] = true; end
		end
	end);
	local tBySource = {};
	local tRelevant = {};
	local function Add(sSource, sModifierId)
		if sSource == nil or sModifierId == nil then return; end
		if tSignals[sModifierId]
			or string.sub(sModifierId, 1, #AUDIT_SIGNAL_PREFIX) == AUDIT_SIGNAL_PREFIX then
			return;
		end
		local tMods = tBySource[sSource];
		if tMods == nil then
			tMods = {};
			tBySource[sSource] = tMods;
		end
		table.insert(tMods, sModifierId);
		tRelevant[sModifierId] = true;
	end
	for row in GameInfo.PolicyModifiers() do Add(row.PolicyType, row.ModifierId); end
	for row in GameInfo.GovernmentModifiers() do Add(row.GovernmentType, row.ModifierId); end
	tAuditModsBySource = tBySource;
	tAuditRelevant = tRelevant;
end

-- Returns the printable deck and the audited sources (government first).
local function ReadDeck(pPlayer)
	local pCulture = pPlayer:GetCulture();
	local tSources = {};
	local tPolicies = {};
	local sGovernment = "NONE";
	local iGovernment = pCulture:GetCurrentGovernment();
	local kGovernment = iGovernment ~= nil and iGovernment >= 0
		and GameInfo.Governments[iGovernment] or nil;
	if kGovernment ~= nil then
		sGovernment = kGovernment.GovernmentType;
		table.insert(tSources, sGovernment);
	end
	-- Slot check (2026-10-07): each slot's type against its card's type, and
	-- whether the card is obsolete, to tell a card the engine will not attach
	-- (wrong slot type after a government re-layout, or obsolete) from one it
	-- simply lost. Printed as a separate "Policy slots" line with the deck.
	local tSlots = {};
	local tSlotPolicies = {};
	for iSlot = 0, pCulture:GetNumPolicySlots() - 1 do
		local iPolicy = pCulture:GetSlotPolicy(iSlot);
		local kPolicy = iPolicy ~= nil and iPolicy >= 0 and GameInfo.Policies[iPolicy] or nil;
		local sSlotType = "?";
		pcall(function()
			local kSlot = GameInfo.GovernmentSlots[pCulture:GetSlotType(iSlot)];
			if kSlot ~= nil then sSlotType = kSlot.GovernmentSlotType; end
		end);
		if kPolicy ~= nil then
			table.insert(tPolicies, kPolicy.PolicyType);
			table.insert(tSources, kPolicy.PolicyType);
			table.insert(tSlotPolicies, { Slot = iSlot, PolicyType = kPolicy.PolicyType });
			local sFlags = "";
			if sSlotType ~= "?" and sSlotType ~= "SLOT_WILDCARD"
				and sSlotType ~= kPolicy.GovernmentSlotType then
				sFlags = sFlags .. "!MISMATCH";
			end
			pcall(function()
				if pCulture:IsPolicyObsolete(kPolicy.Hash) then sFlags = sFlags .. "!OBSOLETE"; end
			end);
			table.insert(tSlots, iSlot .. "=" .. sSlotType .. ":" .. kPolicy.PolicyType .. sFlags);
		else
			table.insert(tSlots, iSlot .. "=" .. sSlotType .. ":EMPTY");
		end
	end
	return "government " .. sGovernment .. " policies " .. table.concat(tPolicies, ","), tSources,
		table.concat(tSlots, " "), tSlotPolicies;
end

local function ClassifyAudit(tStat)
	if tStat == nil then return "MISSING"; end
	if tStat.Active == 0 then return "INACTIVE"; end
	if tStat.ActiveWithSubjects == 0 then return "NOSUBJ"; end
	return "OK";
end

local function GlobalSummary(tG)
	if tG == nil then return "0"; end
	local tParts = {};
	for sOwner, iCount in pairs(tG.Owners) do table.insert(tParts, sOwner .. "=" .. iCount); end
	table.sort(tParts);
	return tG.Total .. " (" .. table.concat(tParts, " ") .. ")";
end

-- tOnly: set of player IDs to audit, or nil for every AI major.
local function AuditPolicyModifiers(tOnly)
	BuildAuditTables();
	local iTurn = Game.GetCurrentGameTurn();
	local tTargets = {};
	local tTargetIDs = {};
	for _, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do
		local iPlayerID = pPlayer:GetID();
		if tOnly == nil or tOnly[iPlayerID] then
			local sDeck, tSources, sSlots, tSlotPolicies = ReadDeck(pPlayer);
			tTargets[iPlayerID] = { Deck = sDeck, Sources = tSources, Stats = {}, Slots = sSlots,
				SlotPolicies = tSlotPolicies };
			table.insert(tTargetIDs, iPlayerID);
		end
	end
	if #tTargetIDs == 0 then return; end
	table.sort(tTargetIDs);

	-- One pass over live instances; filter by owner first (cheap), then Id.
	-- Each instance is queried in its own pcall, so one bad instance (for
	-- example an owner that is not a player) cannot stop the whole audit.
	-- Self-check (2026-10-07): every relevant instance is also counted game-wide
	-- by resolved owner player, or by owner object when no player resolves, and
	-- the totals are printed on MISSING rows. If a MISSING card shows instances
	-- under an unresolved owner, the audit's owner matching is wrong, not the card.
	local tGlobal = {};
	local function CountInstance(iInstance)
		local iOwnerObject = GameEffects.GetModifierOwner(iInstance);
		local iOwnerPlayer = GameEffects.GetObjectsPlayerId(iOwnerObject);
		local kDefinition = GameEffects.GetModifierDefinition(iInstance);
		local sModifierId = kDefinition ~= nil and kDefinition.Id or nil;
		if sModifierId ~= nil and tAuditRelevant[sModifierId] then
			local tG = tGlobal[sModifierId];
			if tG == nil then tG = { Total = 0, Owners = {} }; tGlobal[sModifierId] = tG; end
			tG.Total = tG.Total + 1;
			local sOwner = (iOwnerPlayer ~= nil and iOwnerPlayer >= 0) and ("p" .. iOwnerPlayer)
				or ("obj:" .. tostring(iOwnerObject));
			tG.Owners[sOwner] = (tG.Owners[sOwner] or 0) + 1;
		end
		local tTarget = iOwnerPlayer ~= nil and tTargets[iOwnerPlayer] or nil;
		if tTarget ~= nil then
			if sModifierId ~= nil and tAuditRelevant[sModifierId] then
				local tStat = tTarget.Stats[sModifierId];
				if tStat == nil then
					tStat = { Instances = 0, Active = 0, ActiveWithSubjects = 0, Subjects = 0 };
					tTarget.Stats[sModifierId] = tStat;
				end
				tStat.Instances = tStat.Instances + 1;
				if GameEffects.GetModifierActive(iInstance) then
					tStat.Active = tStat.Active + 1;
					local tSubjects = GameEffects.GetModifierSubjects(iInstance);
					local iSubjects = type(tSubjects) == "table" and #tSubjects or 0;
					tStat.Subjects = tStat.Subjects + iSubjects;
					if iSubjects > 0 then
						tStat.ActiveWithSubjects = tStat.ActiveWithSubjects + 1;
					end
				end
			end
		end
	end
	local iInstanceErrors = 0;
	for _, iInstance in ipairs(GameEffects.GetModifiers()) do
		if not pcall(CountInstance, iInstance) then
			iInstanceErrors = iInstanceErrors + 1;
		end
	end
	if iInstanceErrors > 0 then
		print("Rose_AI_InGame: Rose AI: Policy audit skipped " .. iInstanceErrors
			.. " modifier instances after query errors turn " .. iTurn);
	end

	for _, iPlayerID in ipairs(tTargetIDs) do
		local tTarget = tTargets[iPlayerID];
		if tAuditDeck[iPlayerID] ~= tTarget.Deck then
			tAuditDeck[iPlayerID] = tTarget.Deck;
			if ROSE_VERBOSE_LOGS then
				print("Rose_AI_InGame: Rose AI: Policy deck turn " .. iTurn
					.. " player " .. iPlayerID .. " " .. tTarget.Deck);
				print("Rose_AI_InGame: Rose AI: Policy slots turn " .. iTurn
					.. " player " .. iPlayerID .. " " .. tTarget.Slots);
			end
		end
		local tOld = tAuditClass[iPlayerID] or {};
		local tNew = {};
		for _, sSource in ipairs(tTarget.Sources) do
			for _, sModifierId in ipairs(tAuditModsBySource[sSource] or {}) do
				local tStat = tTarget.Stats[sModifierId];
				local sClass = ClassifyAudit(tStat);
				local sKey = sSource .. " " .. sModifierId;
				local sOld = tOld[sKey];
				tNew[sKey] = sClass;
				if ROSE_VERBOSE_LOGS
					and ((sOld == nil and sClass ~= "OK") or (sOld ~= nil and sOld ~= sClass)) then
					local kModifier = GameInfo.Modifiers[sModifierId];
					print("Rose_AI_InGame: Rose AI: Policy audit turn " .. iTurn
						.. " player " .. iPlayerID
						.. " source " .. sSource
						.. " modifier " .. sModifierId
						.. " type " .. tostring(kModifier ~= nil and kModifier.ModifierType or nil)
						.. " class " .. sClass
						.. " was " .. tostring(sOld or "NEW")
						.. " instances " .. (tStat ~= nil and tStat.Instances or 0)
						.. " subjects " .. (tStat ~= nil and tStat.Subjects or 0)
						.. (sClass == "MISSING" and (" global " .. GlobalSummary(tGlobal[sModifierId])) or ""));
				end
			end
		end
		tAuditClass[iPlayerID] = tNew;

		-- Dead cards for the repair (HANDOFF W15): a slotted policy with at
		-- least one audited modifier that has no instance at all (MISSING).
		-- Policy modifiers have no owner requirements and none is RunOnce, so a
		-- slotted card always has its instances unless the engine lost them.
		-- After instance query errors an uncounted modifier would read MISSING,
		-- so that audit publishes no dead list (the bridge returns nil).
		local tDead = {};
		for _, kSlot in ipairs(tTarget.SlotPolicies) do
			local iMissing = 0;
			for _, sModifierId in ipairs(tAuditModsBySource[kSlot.PolicyType] or {}) do
				if tTarget.Stats[sModifierId] == nil then iMissing = iMissing + 1; end
			end
			if iMissing > 0 then
				table.insert(tDead, { Slot = kSlot.Slot, PolicyType = kSlot.PolicyType, Missing = iMissing });
			end
		end
		tDeadPolicySlots[iPlayerID] = { Turn = iTurn, Slots = iInstanceErrors == 0 and tDead or nil };
	end
end

local function RunPolicyAudit(tOnly)
	local bOk, sError = pcall(AuditPolicyModifiers, tOnly);
	if not bOk then print("Rose_AI_InGame: Rose AI ERROR: Policy audit: " .. tostring(sError)); end
end

-- Dead policy slots of one player for the gameplay repair (HANDOFF W15), as a
-- fresh array of { Slot, PolicyType, Missing }; empty when every slotted card
-- has its modifiers, nil when the audit could not run or skipped instances
-- after query errors. Uses this turn's audit
-- of the player when there is one, otherwise audits every major first (one
-- modifier pass per turn at most, shared with the TurnBegin audit). The
-- gameplay script re-checks each slot against its own data before clearing.
function RoseGetDeadPolicySlots(iPlayerID)
	local iTurn = Game.GetCurrentGameTurn();
	local kEntry = tDeadPolicySlots[iPlayerID];
	if kEntry == nil or kEntry.Turn ~= iTurn then
		RunPolicyAudit(nil);
		kEntry = tDeadPolicySlots[iPlayerID];
		if kEntry == nil or kEntry.Turn ~= iTurn then return nil; end
	end
	if kEntry.Slots == nil then return nil; end
	local tCopy = {};
	for i, kSlot in ipairs(kEntry.Slots) do
		tCopy[i] = { Slot = kSlot.Slot, PolicyType = kSlot.PolicyType, Missing = kSlot.Missing };
	end
	return tCopy;
end

RoseAI.GetDeadPolicySlots = RoseGetDeadPolicySlots;

Events.TurnBegin.Add(function()
	tAuditDirty = {};
	RunPolicyAudit(nil);
end);

-- These UI events carry the player ID first (Firaxis handlers filter it to the
-- local player). TurnBegin still audits everyone if they skip AI players.
local function MarkAuditDirty(iPlayerID)
	if type(iPlayerID) == "number" and iPlayerID >= 0 then tAuditDirty[iPlayerID] = true; end
end
for _, sEvent in ipairs({ "CivicCompleted", "GovernmentChanged",
	"GovernmentPolicyChanged", "GovernmentPolicyObsoleted" }) do
	local bOk, sError = pcall(function()
		if Events[sEvent] ~= nil then Events[sEvent].Add(MarkAuditDirty); end
	end);
	if not bOk then
		print("Rose_AI_InGame: Rose AI ERROR: Policy audit hook " .. sEvent .. ": " .. tostring(sError));
	end
end

-- Raised after each batch of game-core events, so a deck change is audited
-- once the batch that made it has been published.
if Events.GameCoreEventPublishComplete ~= nil then
	Events.GameCoreEventPublishComplete.Add(function()
		if next(tAuditDirty) == nil then return; end
		local tOnly = tAuditDirty;
		tAuditDirty = {};
		RunPolicyAudit(tOnly);
	end);
end

print("Rose_AI_InGame: Rose AI: InGame military-strength bridge loaded");
