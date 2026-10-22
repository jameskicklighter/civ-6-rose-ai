-- ============================================================================
-- Rose AI InGame UI bridge: military strength, net Gold income, envoys, Trader
-- details and dead policy slots for the gameplay scripts (ExposedMembers.RoseAI),
-- plus the policy-modifier audit behind the dead slots. These getters and
-- GameEffects are unavailable in the gameplay context. Hooks: Events.TurnBegin,
-- the civic/government/policy events and GameCoreEventPublishComplete; no saved
-- state. AGENTS.md "Rose_AI_InGame.lua / Rose_AI_InGame.xml".
-- ============================================================================

print("Rose_AI_InGame: Rose AI: Loading InGame military-strength bridge");

if ExposedMembers.RoseAI == nil then ExposedMembers.RoseAI = {}; end
local RoseAI = ExposedMembers.RoseAI;

-- Per-turn diagnostic output (policy decks, slot lines, audit class changes).
-- Off for release; the standalone Rose Policy Audit (DIAG) mod is the test
-- instrument. Errors always print.
local ROSE_VERBOSE_LOGS = true;

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

-- Envoys iMajorID has in city-state iMinorID and its suzerain (-1 for none),
-- as Firaxis UI scripts read them; false when iMinorID cannot receive envoys
-- (such as the Free Cities); nil on any failure.
function RoseGetEnvoyInfo(iMinorID, iMajorID)
	local bOk, iTokens, iSuzerain = pcall(function()
		local pMinor = Players[iMinorID];
		if pMinor == nil then return nil; end
		local pInfluence = pMinor:GetInfluence();
		if pInfluence == nil then return nil; end
		if not pInfluence:CanReceiveInfluence() then return false; end
		return pInfluence:GetTokensReceived(iMajorID), pInfluence:GetSuzerain();
	end);
	if not bOk then return nil; end
	if iTokens == false then return false; end
	if type(iTokens) ~= "number" then return nil; end
	return iTokens, iSuzerain;
end

RoseAI.GetEnvoyInfo = RoseGetEnvoyInfo;

-- Stuck Trader diagnostic details, from route and unit queries Firaxis calls
-- in UI scripts. Each part is queried separately; a failed part prints "?".
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

-- ============================================================================
-- Policy-modifier audit: for each major, every modifier row of its slotted
-- policies and government (except Rose's ROSE_CHOICE_* signals) is matched by
-- ModifierId and owner against live instances: OK (active with subjects), NOSUBJ
-- (active, no subjects), INACTIVE or MISSING (no instance). It records the dead
-- slots (a card with a MISSING modifier) for RoseAI.GetDeadPolicySlots; with
-- ROSE_VERBOSE_LOGS it prints deck changes and class changes. AGENTS.md
-- "Policy-modifier audit".
-- ============================================================================
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
	-- ROSE_CHOICE_ (the belief and policy signal SQL). Read the table when it is
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
	-- Slot check: each slot's type against its card's, and whether the card is
	-- obsolete, to tell a card the engine will not attach from one it lost.
	-- Printed as a separate "Policy slots" line with the deck.
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

-- ============================================================================
-- Adjacency signal values (verbose only, print-only): what the AI card scorer
-- is shown for each adjacency card. The signals are ten inactive +5 tiers per
-- card (ROSE_CHOICE_POLICY_<CARD>_ADJ<n>, each gated by a
-- REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT of adjacency n or more), so a
-- card's value is 5 per adjacency point per city, up to 10 points. Read from
-- the player's completed districts, as value/qualifying cities per card (cards
-- at 0 left out), printed when the text changes. AGENTS.md "Adjacency cards".
-- ============================================================================
local ADJACENCY_TIER_PATTERN = "^ROSE_CHOICE_POLICY_(.+)_ADJ(%d+)$";
local ADJACENCY_REQUIREMENT_TYPE = "REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT";
-- Built once from GameInfo: card name -> { Tiers = { { Amount, Gates = { { District, Yield, Amount } } } } },
-- the district types and the yield indices the gates read.
local tAdjacencyCards = nil;
local tAdjacencyDistricts = nil;
local tAdjacencyYields = nil;
local tAdjacencyText = {};
local bAdjacencyErrorPrinted = false;

local function BuildAdjacencyTables()
	if tAdjacencyCards ~= nil then return; end
	local tTiers = {};
	local tPolicyOf = {};
	for row in GameInfo.PolicyModifiers() do
		if string.match(row.ModifierId, ADJACENCY_TIER_PATTERN) ~= nil then
			tPolicyOf[row.ModifierId] = row.PolicyType;
		end
	end
	local tTiersOfSet = {};
	for row in GameInfo.Modifiers() do
		local sCard = string.match(row.ModifierId, ADJACENCY_TIER_PATTERN);
		if sCard ~= nil and row.SubjectRequirementSetId ~= nil then
			local sPolicy = tPolicyOf[row.ModifierId];
			if sPolicy ~= nil then sCard = string.gsub(sPolicy, "^POLICY_", ""); end
			local kTier = { Card = sCard, Amount = 0, Gates = {} };
			tTiers[row.ModifierId] = kTier;
			tTiersOfSet[row.SubjectRequirementSetId] = tTiersOfSet[row.SubjectRequirementSetId] or {};
			table.insert(tTiersOfSet[row.SubjectRequirementSetId], kTier);
		end
	end
	for row in GameInfo.ModifierArguments() do
		local kTier = tTiers[row.ModifierId];
		if kTier ~= nil and row.Name == "Amount" then kTier.Amount = tonumber(row.Value) or 0; end
	end
	-- Requirement ID -> { Tiers, District, Yield, Amount } for the high-adjacency requirements.
	local tGates = {};
	for row in GameInfo.RequirementSetRequirements() do
		local tSetTiers = tTiersOfSet[row.RequirementSetId];
		if tSetTiers ~= nil then
			local kRequirement = GameInfo.Requirements[row.RequirementId];
			if kRequirement ~= nil and kRequirement.RequirementType == ADJACENCY_REQUIREMENT_TYPE then
				tGates[row.RequirementId] = { Tiers = tSetTiers };
			end
		end
	end
	for row in GameInfo.RequirementArguments() do
		local kGate = tGates[row.RequirementId];
		if kGate ~= nil then
			if row.Name == "DistrictType" then kGate.District = row.Value; end
			if row.Name == "YieldType" then kGate.Yield = row.Value; end
			if row.Name == "Amount" then kGate.Amount = tonumber(row.Value); end
		end
	end
	local tCards = {};
	local tDistricts = {};
	local tYields = {};
	for _, kGate in pairs(tGates) do
		local kYield = kGate.Yield ~= nil and GameInfo.Yields[kGate.Yield] or nil;
		if kGate.District ~= nil and kGate.Amount ~= nil and kYield ~= nil then
			-- The yield index is the Yields row's own (Food 0), as GetAdjacencyYield takes it.
			for _, kTier in ipairs(kGate.Tiers) do
				table.insert(kTier.Gates, { District = kGate.District, Yield = kYield.Index, Amount = kGate.Amount });
			end
			tDistricts[kGate.District] = true;
			tYields[kYield.Index] = true;
		end
	end
	for _, kTier in pairs(tTiers) do
		if #kTier.Gates > 0 and kTier.Amount > 0 then
			local kCard = tCards[kTier.Card];
			if kCard == nil then
				kCard = { Tiers = {} };
				tCards[kTier.Card] = kCard;
			end
			table.insert(kCard.Tiers, kTier);
		end
	end
	tAdjacencyDistricts = tDistricts;
	tAdjacencyYields = tYields;
	tAdjacencyCards = tCards;
end

-- "CARD value/cities ..." in card name order; "none" when every card is at 0.
local function ReadAdjacencySignals(pPlayer)
	BuildAdjacencyTables();
	local tValue = {};
	local tCities = {};
	for _, pCity in pPlayer:GetCities():Members() do
		-- Best adjacency of a completed district of each gate type, per yield.
		local tAdjacency = {};
		for _, pDistrict in pCity:GetDistricts():Members() do
			local kDistrict = GameInfo.Districts[pDistrict:GetType()];
			local bComplete = true;
			if pDistrict.IsComplete ~= nil then bComplete = pDistrict:IsComplete(); end
			if bComplete and kDistrict ~= nil and tAdjacencyDistricts[kDistrict.DistrictType] then
				local tByYield = tAdjacency[kDistrict.DistrictType];
				if tByYield == nil then
					tByYield = {};
					tAdjacency[kDistrict.DistrictType] = tByYield;
				end
				for iYield in pairs(tAdjacencyYields) do
					local iAdjacency = pDistrict:GetAdjacencyYield(iYield) or 0;
					if iAdjacency > (tByYield[iYield] or 0) then tByYield[iYield] = iAdjacency; end
				end
			end
		end
		for sCard, kCard in pairs(tAdjacencyCards) do
			local iCityValue = 0;
			for _, kTier in ipairs(kCard.Tiers) do
				for _, kGate in ipairs(kTier.Gates) do
					local tByYield = tAdjacency[kGate.District];
					if tByYield ~= nil and (tByYield[kGate.Yield] or 0) >= kGate.Amount then
						iCityValue = iCityValue + kTier.Amount;
						break;
					end
				end
			end
			if iCityValue > 0 then
				tValue[sCard] = (tValue[sCard] or 0) + iCityValue;
				tCities[sCard] = (tCities[sCard] or 0) + 1;
			end
		end
	end
	local tNames = {};
	for sCard in pairs(tValue) do table.insert(tNames, sCard); end
	table.sort(tNames);
	local tParts = {};
	for _, sCard in ipairs(tNames) do
		table.insert(tParts, sCard .. " " .. tValue[sCard] .. "/" .. tCities[sCard]);
	end
	if #tParts == 0 then return "none"; end
	return table.concat(tParts, " ");
end

local function ReportAdjacencySignals(iPlayerID, iTurn)
	local bOk, sText = pcall(function()
		local pPlayer = Players[iPlayerID];
		if pPlayer == nil or pPlayer:IsHuman() then return nil; end
		return ReadAdjacencySignals(pPlayer);
	end);
	if not bOk then
		if not bAdjacencyErrorPrinted then
			bAdjacencyErrorPrinted = true;
			print("Rose_AI_InGame: Rose AI ERROR: Adjacency signals: " .. tostring(sText));
		end
		return;
	end
	if sText == nil or tAdjacencyText[iPlayerID] == sText then return; end
	-- Nothing to report until a card first rises above 0.
	if tAdjacencyText[iPlayerID] == nil and sText == "none" then
		tAdjacencyText[iPlayerID] = sText;
		return;
	end
	tAdjacencyText[iPlayerID] = sText;
	print("Rose_AI_InGame: Rose AI: Adjacency signals turn " .. iTurn
		.. " player " .. iPlayerID .. ": " .. sText);
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

	-- One pass over live instances, each in its own pcall. Every relevant
	-- instance is also counted game-wide by owner (printed on MISSING rows), so
	-- an instance under an unresolved owner points at the owner matching.
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

		-- Dead cards for the repair: a slotted policy with an audited modifier
		-- that has no instance at all. After instance query errors an uncounted
		-- modifier would read MISSING, so that audit publishes no dead list.
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

		if ROSE_VERBOSE_LOGS then ReportAdjacencySignals(iPlayerID, iTurn); end
	end
end

local function RunPolicyAudit(tOnly)
	local bOk, sError = pcall(AuditPolicyModifiers, tOnly);
	if not bOk then print("Rose_AI_InGame: Rose AI ERROR: Policy audit: " .. tostring(sError)); end
end

-- Dead policy slots of one player, a fresh array of { Slot, PolicyType, Missing },
-- from this turn's audit (one audit of every major first when there is none);
-- nil when the audit could not run or skipped instances after query errors.
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
