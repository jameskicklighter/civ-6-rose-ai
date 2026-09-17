-- ============================================================================
-- Rose AI: Gameplay support
-- ============================================================================
-- 1. Government civics: When an AI player's prereqs for a government-unlocking
--    civic are met, grant it for free. Prevents AI from skipping government
--    upgrades because it beelined past side-branch civics.
--
-- 2. Tree-filling civics: When Guilds or Medieval Faires is completed, grant
--    Military Training, Theology, and their prereqs if missing. The AI often
--    ignores one or both edges of the early civic tree.
--
-- Grants cascade: granting one civic may satisfy another's prereqs.
--
-- 3. Dynamic war strategies: Lua conditions activate wartime replacement,
--    weak-army recovery, and strength-gated peace resistance database lists.
--
-- 4. Special operations:
--    - Any AI major can launch a small, cooldown-controlled naval interception
--      when an uncommitted melee ship is near an at-war enemy combat ship.
--
-- 5. Policy replacement guard: clear an AI's slotted predecessor policy as
--    soon as a newly completed civic unlocks its replacement. This avoids the
--    delayed-obsolescence rollover path that can suppress all policy effects.
--
-- 6. Dummy-Gold clawback: database modifiers give selected policies, beliefs,
--    and governments a visible AI valuation. A persistent turn ledger removes
--    the configured Gold amount before the AI acts on its next turn.
--    Serfdom's isolated experiment instead uses a capital marker's offset.
-- ============================================================================

print("Rose AI: Loading gameplay support script");

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

-- Cache policy predecessors by the civic which unlocks their replacement.
-- ObsoletePolicies is data-driven, so this also covers DLC policy chains.
local tPolicyReplacementsByCivic = {};
local tReplacementPolicyTypes = {};
for kObsoleteInfo in GameInfo.ObsoletePolicies() do
	if kObsoleteInfo.ObsoletePolicy ~= nil then
		local kOldPolicy = GameInfo.Policies[kObsoleteInfo.PolicyType];
		local kNewPolicy = GameInfo.Policies[kObsoleteInfo.ObsoletePolicy];
		if kOldPolicy ~= nil and kNewPolicy ~= nil then
			tReplacementPolicyTypes[kOldPolicy.PolicyType] = true;
			if kNewPolicy.PrereqCivic ~= nil then
				local kCivic = GameInfo.Civics[kNewPolicy.PrereqCivic];
				if kCivic ~= nil then
					local tReplacements = tPolicyReplacementsByCivic[kCivic.Index];
					if tReplacements == nil then
						tReplacements = {};
						tPolicyReplacementsByCivic[kCivic.Index] = tReplacements;
					end
					tReplacements[kOldPolicy.Index] = {
						oldPolicyType = kOldPolicy.PolicyType,
						newPolicyType = kNewPolicy.PolicyType,
					};
				end
			end
		end
	end
end

-- Cache the database-authored dummy-Gold ledger. Amounts deliberately live in
-- RoseGoldBiases rather than in Lua so modifier payouts and clawbacks cannot
-- drift apart when tuning values later.
local tGoldBiases = {};
local tGoldBiasDistricts = {};
local tGoldGateDistrictIndices = {};
local tGoldPolicyTypes = {};
local tGoldBeliefTypes = {};
if GameInfo.RoseGoldBiases ~= nil then
	for kBias in GameInfo.RoseGoldBiases() do
		local kEntry = {
			BiasId = kBias.BiasId,
			SourceKind = kBias.SourceKind,
			SourceType = kBias.SourceType,
			Amount = tonumber(kBias.Amount) or 0,
			GateType = kBias.GateType or "ALWAYS",
			GateValue = kBias.GateValue,
		};
		table.insert(tGoldBiases, kEntry);
		if kEntry.SourceKind == "POLICY" then
			tGoldPolicyTypes[kEntry.SourceType] = true;
		elseif kEntry.SourceKind == "BELIEF" then
			tGoldBeliefTypes[kEntry.SourceType] = true;
		end
	end
end
if GameInfo.RoseGoldBiasResolvedDistricts ~= nil then
	for kGate in GameInfo.RoseGoldBiasResolvedDistricts() do
		local tDistricts = tGoldBiasDistricts[kGate.BiasId];
		if tDistricts == nil then
			tDistricts = {};
			tGoldBiasDistricts[kGate.BiasId] = tDistricts;
		end
		tDistricts[kGate.DistrictType] = true;
		local kDistrict = GameInfo.Districts[kGate.DistrictType];
		if kDistrict ~= nil then tGoldGateDistrictIndices[kGate.DistrictType] = kDistrict.Index; end
	end
end

-- Cache static leader tags once. Rose's own LeaderTraits changes have already
-- been applied when this gameplay script is loaded.
local tLeaderTraits = {};
for kLeaderTrait in GameInfo.LeaderTraits() do
	local tTraits = tLeaderTraits[kLeaderTrait.LeaderType];
	if tTraits == nil then
		tTraits = {};
		tLeaderTraits[kLeaderTrait.LeaderType] = tTraits;
	end
	tTraits[kLeaderTrait.TraitType] = true;
end

local GOLD_SNAPSHOT_INITIALIZED_PROPERTY = "ROSE_GOLD_BIAS_SNAPSHOT_INITIALIZED";
local GOLD_SNAPSHOT_POLICIES_PROPERTY = "ROSE_GOLD_BIAS_SNAPSHOT_POLICIES";
local GOLD_SNAPSHOT_POLICIES_VALID_PROPERTY = "ROSE_GOLD_BIAS_SNAPSHOT_POLICIES_ACTIVE_VALID";
local GOLD_SNAPSHOT_GOVERNMENT_PROPERTY = "ROSE_GOLD_BIAS_SNAPSHOT_GOVERNMENT";
local GOLD_SNAPSHOT_GOVERNMENT_VALID_PROPERTY = "ROSE_GOLD_BIAS_SNAPSHOT_GOVERNMENT_VALID";
local GOLD_SNAPSHOT_BELIEFS_PROPERTY = "ROSE_GOLD_BIAS_SNAPSHOT_BELIEFS";
local GOLD_LAST_CLAWBACK_TURN_PROPERTY = "ROSE_GOLD_BIAS_LAST_CLAWBACK_TURN";
local GOLD_CLAWBACK_DEBT_PROPERTY = "ROSE_GOLD_BIAS_CLAWBACK_DEBT";
local GOLD_CUMULATIVE_EXPECTED_PROPERTY = "ROSE_GOLD_BIAS_CUMULATIVE_EXPECTED";
local GOLD_CUMULATIVE_DEDUCTED_PROPERTY = "ROSE_GOLD_BIAS_CUMULATIVE_DEDUCTED";

-- One database switch controls both the policy attachment and Lua accounting.
-- 0: baseline, 1: positive only, 2: building offset, 3: original clawback.
-- 4: inactive envoy scoring probe; no Serfdom Gold, marker, or clawback.
local kSerfdomMode = GameInfo.GlobalParameters["ROSE_SERFDOM_EXPERIMENT_MODE"];
local iSerfdomMode = kSerfdomMode ~= nil and tonumber(kSerfdomMode.Value) or 3;
local kSerfdomBuilding = GameInfo.Buildings["BUILDING_ROSE_SERFDOM_OFFSET"];
local iSerfdomBuilding = kSerfdomBuilding ~= nil and kSerfdomBuilding.Index or nil;
local tSerfdomSyncing = {};
local tSerfdomOffsetMeasured = {};
local tGovernmentBridgeWarningTurn = {};

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
-- Tree-filling civics: grant when ANY trigger civic is completed.
-- Fills in skipped branches so the AI has Military Training and Theology
-- (and their prereqs) by the time it reaches Medieval era.
-- ============================================================================
local iGuilds         = GameInfo.Civics["CIVIC_GUILDS"].Index;
local iMedievalFaires = GameInfo.Civics["CIVIC_MEDIEVAL_FAIRES"].Index;

-- Civics to grant (in dependency order — prereqs first so cascade works)
local tTreeFillCivics = {
	GameInfo.Civics["CIVIC_MYSTICISM"].Index,
	GameInfo.Civics["CIVIC_DRAMA_POETRY"].Index,
	GameInfo.Civics["CIVIC_THEOLOGY"].Index,
	GameInfo.Civics["CIVIC_MILITARY_TRADITION"].Index,
	GameInfo.Civics["CIVIC_GAMES_RECREATION"].Index,
	GameInfo.Civics["CIVIC_MILITARY_TRAINING"].Index,
};

-- Check all government civics and grant any whose prereqs are fully met.
-- Runs in a loop to handle cascades (e.g. Divine Right → Reformed Church).
function GrantReadyGovtCivics(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not pPlayer:IsMajor() then return; end
	if pPlayer:IsHuman() then return; end

	local pCulture = pPlayer:GetCulture();
	local bGrantedAny = true;

	-- Keep looping until no new civics are granted (handles cascades)
	while bGrantedAny do
		bGrantedAny = false;
		for _, entry in ipairs(tGovtCivics) do
			if not pCulture:HasCivic(entry.civic) then
				local bAllMet = true;
				for _, iPrereq in ipairs(entry.prereqs) do
					if not pCulture:HasCivic(iPrereq) then
						bAllMet = false;
						break;
					end
				end
				if bAllMet then
					pCulture:SetCivic(entry.civic, true);
					bGrantedAny = true;
					print("Rose AI: Granted civic index " .. entry.civic .. " to AI player " .. iPlayerID);
				end
			end
		end
	end
end

-- Grant tree-filling civics if the AI has completed Guilds or Medieval Faires.
-- These are early-tree civics the AI may have skipped entirely.
function GrantTreeFillCivics(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not pPlayer:IsMajor() then return; end
	if pPlayer:IsHuman() then return; end

	local pCulture = pPlayer:GetCulture();

	-- Only trigger once the AI has reached Guilds or Medieval Faires
	if not pCulture:HasCivic(iGuilds) and not pCulture:HasCivic(iMedievalFaires) then
		return;
	end

	for _, iCivic in ipairs(tTreeFillCivics) do
		if not pCulture:HasCivic(iCivic) then
			pCulture:SetCivic(iCivic, true);
			print("Rose AI: Tree-fill granted civic index " .. iCivic .. " to AI player " .. iPlayerID);
		end
	end
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

-- An unset Civ VI player property can return no Lua values rather than one nil
-- value. Passing that call directly to tonumber therefore becomes tonumber()
-- and raises an argument error. Capture it first so Lua normalizes the missing
-- return to nil, then apply the requested numeric default.
local function GetNumericPlayerProperty(pPlayer, sPropertyName, iDefault)
	local value = pPlayer:GetProperty(sPropertyName);
	if value == nil then return iDefault; end
	return tonumber(value) or iDefault;
end

local function SerializeStringSet(tValues)
	local tSorted = {};
	for sValue, bPresent in pairs(tValues) do
		if bPresent then table.insert(tSorted, sValue); end
	end
	table.sort(tSorted);
	return table.concat(tSorted, ",");
end

local function DeserializeStringSet(sValues)
	local tValues = {};
	if type(sValues) ~= "string" or sValues == "" then return tValues; end
	for sValue in string.gmatch(sValues, "[^,]+") do
		tValues[sValue] = true;
	end
	return tValues;
end

local function GetSlottedGoldPolicyTypes(pPlayer, bRequireActive)
	local tPolicies = {};
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return tPolicies; end
	for iSlot = 0, pCulture:GetNumPolicySlots() - 1 do
		local iPolicy = pCulture:GetSlotPolicy(iSlot);
		local kPolicy = iPolicy ~= nil and iPolicy >= 0
			and GameInfo.Policies[iPolicy] or nil;
		if kPolicy ~= nil and tGoldPolicyTypes[kPolicy.PolicyType]
			and (not bRequireActive or pCulture:IsPolicyActive(iPolicy)) then
			tPolicies[kPolicy.PolicyType] = true;
		end
	end
	return tPolicies;
end

-- Reconcile from actual slots, including after reload, obsolescence and capital
-- transfers. Remove stale copies first because each copy affects the player.
local function GetNetGoldYield(pPlayer)
	local pTreasury = pPlayer:GetTreasury();
	if pTreasury ~= nil and pTreasury.GetGoldYield ~= nil
		and pTreasury.GetTotalMaintenance ~= nil then
		return pTreasury:GetGoldYield() - pTreasury:GetTotalMaintenance();
	end
	return nil;
end

local function SyncSerfdomOffset(iPlayerID, bAudit, sPhase)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil or iSerfdomBuilding == nil or tSerfdomSyncing[iPlayerID] then return; end
	local pCities = pPlayer:GetCities();
	if pCities == nil then return; end
	tSerfdomSyncing[iPlayerID] = true;
	local bEligible = IsEligibleAIPlayer(pPlayer);
	local bSlotted = bEligible and GetSlottedGoldPolicyTypes(pPlayer)["POLICY_SERFDOM"] == true;
	-- A slot alone does not establish that the card is currently enabled.
	-- IsPolicyActive(index) is demonstrated in Firaxis' Black Death gameplay.
	local bActive = bSlotted and pPlayer:GetCulture():IsPolicyActive(
		GameInfo.Policies["POLICY_SERFDOM"].Index) == true;
	local pCapital = pCities:GetCapitalCity();
	local iWantedCity = iSerfdomMode == 2 and bActive and pCapital ~= nil
		and pCapital:GetID() or -1;
	local bChanged = false;
	local iNetGoldBefore = GetNetGoldYield(pPlayer);
	for _, pCity in pCities:Members() do
		local pBuildings = pCity:GetBuildings();
		if pCity:GetID() ~= iWantedCity and pBuildings:HasBuilding(iSerfdomBuilding) then
			pBuildings:RemoveBuilding(iSerfdomBuilding);
			bChanged = true;
		end
	end
	if iWantedCity >= 0 then
		local pBuildings = pCapital:GetBuildings();
		-- Recreate a pillaged marker using the same known create/remove APIs.
		if pBuildings:HasBuilding(iSerfdomBuilding) and pBuildings:IsPillaged(iSerfdomBuilding) then
			pBuildings:RemoveBuilding(iSerfdomBuilding);
			bChanged = true;
		end
		if not pBuildings:HasBuilding(iSerfdomBuilding) then
			local pPlot = Map.GetPlot(pCapital:GetX(), pCapital:GetY());
			if pPlot ~= nil then
				pCapital:GetBuildQueue():CreateIncompleteBuilding(iSerfdomBuilding, pPlot:GetIndex(), 100);
				bChanged = true;
			end
		end
	end
	-- One controlled measurement per player/session, at a turn boundary. No
	-- income tick occurs between removing and restoring this internal marker.
	-- Record observed values rather than assuming the engine refreshed yields.
	if bAudit and iWantedCity >= 0 and not tSerfdomOffsetMeasured[iPlayerID]
		and pCapital:GetBuildings():HasBuilding(iSerfdomBuilding) then
		local pPlot = Map.GetPlot(pCapital:GetX(), pCapital:GetY());
		local iWithMarker = GetNetGoldYield(pPlayer);
		if pPlot ~= nil and iWithMarker ~= nil then
			local iGoldBefore = pPlayer:GetTreasury():GetGoldBalance();
			pCapital:GetBuildings():RemoveBuilding(iSerfdomBuilding);
			local iWithoutMarker = GetNetGoldYield(pPlayer);
			pCapital:GetBuildQueue():CreateIncompleteBuilding(iSerfdomBuilding, pPlot:GetIndex(), 100);
			local iRestored = GetNetGoldYield(pPlayer);
			tSerfdomOffsetMeasured[iPlayerID] = pCapital:GetBuildings():HasBuilding(iSerfdomBuilding);
			bChanged = true;
			print("Rose AI: Serfdom offset measurement turn " .. Game.GetCurrentGameTurn()
				.. " player " .. iPlayerID .. " with " .. tostring(iWithMarker)
				.. " without " .. tostring(iWithoutMarker) .. " restored " .. tostring(iRestored)
				.. " marker_delta " .. tostring(iWithoutMarker ~= nil and iRestored ~= nil
					and iRestored - iWithoutMarker or nil)
				.. " treasury " .. iGoldBefore .. "->" .. pPlayer:GetTreasury():GetGoldBalance());
		end
	end
	local iMarkers = 0;
	for _, pCity in pCities:Members() do
		if pCity:GetBuildings():HasBuilding(iSerfdomBuilding) then iMarkers = iMarkers + 1; end
	end
	tSerfdomSyncing[iPlayerID] = nil;
	if iMarkers ~= (iWantedCity >= 0 and 1 or 0) then
		print("Rose AI ERROR: Serfdom offset marker mismatch player " .. iPlayerID
			.. " wanted_city " .. iWantedCity .. " markers " .. iMarkers);
	end
	if bChanged or (bAudit and bEligible and iSerfdomMode ~= 3) then
		local pTreasury = pPlayer:GetTreasury();
		local gold = pTreasury ~= nil and pTreasury:GetGoldBalance() or "unavailable";
		local gpt = GetNetGoldYield(pPlayer);
		local delta = gpt ~= nil and iNetGoldBefore ~= nil and gpt - iNetGoldBefore or nil;
		print("Rose AI: Serfdom experiment turn " .. Game.GetCurrentGameTurn()
			.. " player " .. iPlayerID .. " mode " .. iSerfdomMode
			.. " phase " .. (sPhase or "change")
			.. " slotted " .. tostring(bSlotted) .. " active " .. tostring(bActive)
			.. " wanted_city " .. iWantedCity
			.. " markers " .. iMarkers .. " gold " .. tostring(gold)
			.. " net_gpt " .. tostring(gpt)
			.. " marker_gpt_before " .. tostring(iNetGoldBefore)
			.. " marker_gpt_delta " .. tostring(delta));
	end
end

local function SyncAllSerfdomOffsets()
	for iPlayerID, _ in pairs(Players) do SyncSerfdomOffset(iPlayerID, false); end
end

-- Event payloads include extra positional values; do not treat them as bAudit.
local function OnSerfdomPolicyChanged(iPlayerID)
	SyncSerfdomOffset(iPlayerID, false);
end

local function OnSerfdomBuildingChanged(iPlayerID)
	-- Includes Palace relocation and marker pillage/recreation. The per-player
	-- guard prevents creation callbacks from recursively creating another copy.
	SyncSerfdomOffset(iPlayerID, false);
end

local function GetCurrentGovernmentType(iPlayerID)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil or kBridge.GetCurrentGovernment == nil then return nil; end
	local iGovernment = kBridge.GetCurrentGovernment(iPlayerID);
	if type(iGovernment) ~= "number" then return nil; end
	if iGovernment == -1 then return ""; end
	local kGovernment = GameInfo.Governments[iGovernment];
	return kGovernment ~= nil and kGovernment.GovernmentType or nil;
end

local function GetFoundedGoldBeliefTypes(iPlayerID)
	local tBeliefs = {};
	local bFounder = false;
	local pGameReligion = Game.GetReligion();
	if pGameReligion == nil or pGameReligion.GetReligions == nil then
		return tBeliefs, bFounder;
	end
	for _, kReligion in ipairs(pGameReligion:GetReligions()) do
		if kReligion.Founder == iPlayerID then
			bFounder = true;
			for _, iBelief in ipairs(kReligion.Beliefs or {}) do
				local kBelief = GameInfo.Beliefs[iBelief];
				if kBelief ~= nil and tGoldBeliefTypes[kBelief.BeliefType] then
					tBeliefs[kBelief.BeliefType] = true;
				end
			end
			break;
		end
	end
	return tBeliefs, bFounder;
end

local function GetOwnedDistrictTypes(pPlayer)
	local tDistricts = {};
	for _, pCity in pPlayer:GetCities():Members() do
		local pDistricts = pCity:GetDistricts();
		if pDistricts ~= nil then
			-- CityDistricts is not the iterable PlayerDistricts collection.
			-- Firaxis queries built districts with HasDistrict(index, true).
			if pDistricts.HasDistrict == nil then
				print("Rose AI WARNING: City district lookup unavailable; district-gated clawbacks omitted");
				return nil;
			end
			for sDistrictType, iDistrict in pairs(tGoldGateDistrictIndices) do
				if not tDistricts[sDistrictType] and pDistricts:HasDistrict(iDistrict, true) then
					tDistricts[sDistrictType] = true;
				end
			end
		end
	end
	return tDistricts;
end

local function GetPlayerLeaderTraits(iPlayerID)
	local kConfig = PlayerConfigurations[iPlayerID];
	if kConfig == nil then return {}; end
	local sLeaderType = kConfig:GetLeaderTypeName();
	return tLeaderTraits[sLeaderType] or {};
end

local function StoreGoldBiasSnapshot(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local tBeliefs = GetFoundedGoldBeliefTypes(iPlayerID);
	pPlayer:SetProperty(GOLD_SNAPSHOT_POLICIES_PROPERTY,
		SerializeStringSet(GetSlottedGoldPolicyTypes(pPlayer, true)));
	pPlayer:SetProperty(GOLD_SNAPSHOT_POLICIES_VALID_PROPERTY, 1);
	local sGovernment = GetCurrentGovernmentType(iPlayerID);
	pPlayer:SetProperty(GOLD_SNAPSHOT_GOVERNMENT_VALID_PROPERTY, sGovernment ~= nil and 1 or 0);
	if sGovernment ~= nil then
		pPlayer:SetProperty(GOLD_SNAPSHOT_GOVERNMENT_PROPERTY, sGovernment);
	elseif tGovernmentBridgeWarningTurn[iPlayerID] ~= Game.GetCurrentGameTurn() then
		tGovernmentBridgeWarningTurn[iPlayerID] = Game.GetCurrentGameTurn();
		print("Rose AI WARNING: Government bridge unavailable for player " .. iPlayerID
			.. "; government clawback omitted for this snapshot (other sources continue)");
	end
	pPlayer:SetProperty(GOLD_SNAPSHOT_BELIEFS_PROPERTY,
		SerializeStringSet(tBeliefs));
	pPlayer:SetProperty(GOLD_SNAPSHOT_INITIALIZED_PROPERTY, 1);
end

local function GoldBiasGatePasses(
	kBias, bFounder, tLeaderTags, tOwnedDistricts)
	if kBias.GateType == "ALWAYS" then return true; end
	if kBias.GateType == "FOUNDER" then return bFounder; end
	if kBias.GateType == "NON_FOUNDER" then return not bFounder; end
	if kBias.GateType == "LEADER_TRAIT" then
		return kBias.GateValue ~= nil and tLeaderTags[kBias.GateValue] == true;
	end
	if kBias.GateType == "DISTRICT_ANY" then
		local tQualifyingDistricts = tGoldBiasDistricts[kBias.BiasId];
		if tQualifyingDistricts == nil or tOwnedDistricts == nil then return false; end
		for sDistrictType, _ in pairs(tQualifyingDistricts) do
			if tOwnedDistricts[sDistrictType] then return true; end
		end
	end
	return false;
end

local function ApplyGoldBiasClawback(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	local iTurn = Game.GetCurrentGameTurn();
	if GetNumericPlayerProperty(
		pPlayer, GOLD_LAST_CLAWBACK_TURN_PROPERTY, -1) == iTurn then
		return;
	end

	-- An older save has no prior-turn snapshot. Capture the live state before
	-- Rose grants civics or clears obsolete policies, then account it once.
	if GetNumericPlayerProperty(
		pPlayer, GOLD_SNAPSHOT_INITIALIZED_PROPERTY, 0) ~= 1 then
		StoreGoldBiasSnapshot(iPlayerID);
		print("Rose AI: Initialized Gold-bias snapshot for AI player "
			.. iPlayerID .. " on turn " .. iTurn);
	end

	local tSnapshotPolicies = DeserializeStringSet(
		pPlayer:GetProperty(GOLD_SNAPSHOT_POLICIES_PROPERTY));
	-- Old snapshots recorded slots without checking whether their effects were
	-- active. Do not charge those unverified policy entries on migration.
	local bSnapshotPoliciesValid = GetNumericPlayerProperty(
		pPlayer, GOLD_SNAPSHOT_POLICIES_VALID_PROPERTY, 0) == 1;
	local sSnapshotGovernment =
		pPlayer:GetProperty(GOLD_SNAPSHOT_GOVERNMENT_PROPERTY) or "";
	local bSnapshotGovernmentValid = GetNumericPlayerProperty(
		pPlayer, GOLD_SNAPSHOT_GOVERNMENT_VALID_PROPERTY, 0) == 1;
	local tSnapshotBeliefs = DeserializeStringSet(
		pPlayer:GetProperty(GOLD_SNAPSHOT_BELIEFS_PROPERTY));
	local _, bFounder = GetFoundedGoldBeliefTypes(iPlayerID);
	local tLeaderTags = GetPlayerLeaderTraits(iPlayerID);
	local tOwnedDistricts = GetOwnedDistrictTypes(pPlayer);

	local iPolicyGold = 0;
	local iTier3GenericGold = 0;
	local iGovernmentSpecificGold = 0;
	local iBeliefGold = 0;
	for _, kBias in ipairs(tGoldBiases) do
		local bSourceActive = false;
		if kBias.SourceKind == "POLICY" then
			bSourceActive = bSnapshotPoliciesValid and tSnapshotPolicies[kBias.SourceType] == true;
			-- Only mode 3 charges Serfdom; all other modes, including 4, are exempt.
			-- Preserve pre-existing debt and every other source's accounting.
			if kBias.BiasId == "ROSE_GOLD_POLICY_SERFDOM" and iSerfdomMode ~= 3 then
				bSourceActive = false;
			end
		elseif kBias.SourceKind == "GOVERNMENT" then
			bSourceActive = bSnapshotGovernmentValid and sSnapshotGovernment == kBias.SourceType;
		elseif kBias.SourceKind == "BELIEF" then
			bSourceActive = tSnapshotBeliefs[kBias.SourceType] == true;
		end
		if bSourceActive and GoldBiasGatePasses(
			kBias, bFounder, tLeaderTags, tOwnedDistricts) then
			if kBias.SourceKind == "POLICY" then
				iPolicyGold = iPolicyGold + kBias.Amount;
			elseif kBias.SourceKind == "BELIEF" then
				iBeliefGold = iBeliefGold + kBias.Amount;
			elseif kBias.GateType == "ALWAYS"
				and (kBias.SourceType == "GOVERNMENT_COMMUNISM"
					or kBias.SourceType == "GOVERNMENT_DEMOCRACY"
					or kBias.SourceType == "GOVERNMENT_FASCISM") then
				iTier3GenericGold = iTier3GenericGold + kBias.Amount;
			else
				iGovernmentSpecificGold = iGovernmentSpecificGold + kBias.Amount;
			end
		end
	end

	local iNewExpected = iPolicyGold + iTier3GenericGold
		+ iGovernmentSpecificGold + iBeliefGold;
	local iPriorDebt = GetNumericPlayerProperty(
		pPlayer, GOLD_CLAWBACK_DEBT_PROPERTY, 0);
	local iTotalDue = iNewExpected + iPriorDebt;
	local iRemoved = 0;
	local iBalanceBefore = 0;
	local iBalanceAfter = 0;
	if iTotalDue > 0 then
		local pTreasury = pPlayer:GetTreasury();
		iBalanceBefore = pTreasury:GetGoldBalance();
		pTreasury:ChangeGoldBalance(-iTotalDue);
		iBalanceAfter = pTreasury:GetGoldBalance();
		iRemoved = iBalanceBefore - iBalanceAfter;
	end

	local iRemainingDebt = math.max(0, iTotalDue - iRemoved);
	local iCumulativeExpected = GetNumericPlayerProperty(
		pPlayer, GOLD_CUMULATIVE_EXPECTED_PROPERTY, 0)
		+ iNewExpected;
	local iCumulativeDeducted = GetNumericPlayerProperty(
		pPlayer, GOLD_CUMULATIVE_DEDUCTED_PROPERTY, 0)
		+ iRemoved;
	local iDiscrepancy = iCumulativeExpected
		- iCumulativeDeducted - iRemainingDebt;

	pPlayer:SetProperty(GOLD_CLAWBACK_DEBT_PROPERTY, iRemainingDebt);
	pPlayer:SetProperty(GOLD_CUMULATIVE_EXPECTED_PROPERTY, iCumulativeExpected);
	pPlayer:SetProperty(GOLD_CUMULATIVE_DEDUCTED_PROPERTY, iCumulativeDeducted);
	pPlayer:SetProperty(GOLD_LAST_CLAWBACK_TURN_PROPERTY, iTurn);

	if iTotalDue > 0 then
		print("Rose AI: Gold-bias clawback turn " .. iTurn
			.. " player " .. iPlayerID
			.. " policy " .. iPolicyGold
			.. " tier3_generic " .. iTier3GenericGold
			.. " government_specific " .. iGovernmentSpecificGold
			.. " belief " .. iBeliefGold
			.. " prior_debt " .. iPriorDebt
			.. " total_due " .. iTotalDue
			.. " removed " .. iRemoved
			.. " remaining_debt " .. iRemainingDebt
			.. " balance " .. iBalanceBefore .. "->" .. iBalanceAfter);
	end
	if math.abs(iDiscrepancy) > 0.001 then
		print("Rose AI ERROR: Gold-bias accounting discrepancy player "
			.. iPlayerID .. " turn " .. iTurn
			.. " expected " .. iCumulativeExpected
			.. " deducted " .. iCumulativeDeducted
			.. " debt " .. iRemainingDebt
			.. " discrepancy " .. iDiscrepancy);
	end
end

-- Clear policies which the just-completed civic replaces before the engine's
-- delayed rollover cleanup can remove them from an otherwise committed deck.
-- This deliberately does not force the replacement card; native CultureAI is
-- left to fill every newly open slot.
local function ClearPoliciesReplacedByCivic(iPlayerID, iCivicID)
	local tReplacements = tPolicyReplacementsByCivic[iCivicID];
	if tReplacements == nil then return false; end

	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return false; end

	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return false; end

	local bClearedAny = false;
	for iSlot = 0, pCulture:GetNumPolicySlots() - 1 do
		local iPolicy = pCulture:GetSlotPolicy(iSlot);
		local kReplacement = tReplacements[iPolicy];
		if kReplacement ~= nil then
			pCulture:ClearPolicySlot(iSlot);
			bClearedAny = true;
			print("Rose AI: Cleared replaced policy "
				.. kReplacement.oldPolicyType
				.. " from slot " .. iSlot
				.. " for AI player " .. iPlayerID
				.. " when replacement " .. kReplacement.newPolicyType
				.. " unlocked");
		end
	end

	if bClearedAny then
		-- Preserve the normal free policy-change state for this civic. This flag
		-- does not choose a card; an open slot still has to be filled by CultureAI.
		pCulture:SetCivicCompletedThisTurn(true);
	end
	return bClearedAny;
end

-- Safety net for a replacement policy which reached the next AI turn while
-- its obsolete predecessor still occupies a slot. Great-Person-only expiry is
-- intentionally left to the base game because it is unrelated to this bug.
local function ClearSlottedObsoleteReplacementPolicies(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return false; end

	local pCulture = pPlayer:GetCulture();
	if pCulture == nil then return false; end

	local bClearedAny = false;
	for iSlot = 0, pCulture:GetNumPolicySlots() - 1 do
		local iPolicy = pCulture:GetSlotPolicy(iSlot);
		local kPolicy = iPolicy ~= nil and iPolicy >= 0
			and GameInfo.Policies[iPolicy] or nil;
		if kPolicy ~= nil
			and tReplacementPolicyTypes[kPolicy.PolicyType] == true
			and pCulture:IsPolicyObsolete(kPolicy.Hash) then
			pCulture:ClearPolicySlot(iSlot);
			bClearedAny = true;
			print("Rose AI: Cleared stale obsolete replacement policy "
				.. kPolicy.PolicyType
				.. " from slot " .. iSlot
				.. " for AI player " .. iPlayerID);
		end
	end

	if bClearedAny then
		pCulture:SetCivicCompletedThisTurn(true);
	end
	return bClearedAny;
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

function RoseActiveStrategyMilitaryRecovery(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local iRecoveryThreshold = iThreshold or 70;
	local bActive = iWars > 0
		and bStrengthValid
		and iEnemyStrength > 0
		and iOurStrength * 100 < iEnemyStrength * iRecoveryThreshold;
	LogWarStrategyChange(iPlayerID, "MILITARY_RECOVERY", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
end

function RoseActiveStrategyWarAdvantage(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local iAdvantageThreshold = iThreshold or 125;
	local bActive = iWars > 0
		and bStrengthValid
		and iEnemyStrength > 0
		and iOurStrength * 100 >= iEnemyStrength * iAdvantageThreshold;
	LogWarStrategyChange(iPlayerID, "WAR_ADVANTAGE", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
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

-- Hook: fires whenever any player completes a civic (gameplay event).
function OnCivicCompleted(iPlayerID, iCivicID)
	ClearPoliciesReplacedByCivic(iPlayerID, iCivicID);
	GrantReadyGovtCivics(iPlayerID);
	GrantTreeFillCivics(iPlayerID);
	-- SetCivic grants are not guaranteed to emit another completion callback.
	ClearSlottedObsoleteReplacementPolicies(iPlayerID);
	SyncSerfdomOffset(iPlayerID, false);
end

-- Hook: fires at the start of each player's turn as a safety net.
function OnPlayerTurnStarted(iPlayerID)
	-- Keep the isolated experiment independent of unrelated ledger API errors.
	-- This touches only Serfdom's marker, not the previous source snapshot.
	SyncSerfdomOffset(iPlayerID, true, "turn_start");
	-- This run did not deliver AI OnPlayerTurnEnded callbacks. Refresh other
	-- players before the next actor starts, so their latest choices are captured
	-- before their own income rollover. Never overwrite this actor's old snapshot.
	for iOtherID, pOther in pairs(Players) do
		if iOtherID ~= iPlayerID and IsEligibleAIPlayer(pOther) then
			StoreGoldBiasSnapshot(iOtherID);
		end
	end
	-- Before civic changes: the ledger describes the income interval just ended.
	-- Civic grants and policy cleanup below may change next turn's snapshot.
	ApplyGoldBiasClawback(iPlayerID);
	GrantReadyGovtCivics(iPlayerID);
	GrantTreeFillCivics(iPlayerID);
	ClearSlottedObsoleteReplacementPolicies(iPlayerID);
	SyncSerfdomOffset(iPlayerID, false, "after_civics");
end

-- Snapshot choice-dependent sources after the AI has finished acting. The
-- next PlayerTurnStarted uses this immutable record for its Gold clawback.
function OnPlayerTurnEnded(iPlayerID)
	SyncSerfdomOffset(iPlayerID, true, "turn_end");
	StoreGoldBiasSnapshot(iPlayerID);
end

-- Firaxis' Nubia scenario starts scripted military operations from this hook.
-- Starting them inside PlayerTurnStarted can re-enter native AI initialization.
function OnPlayerTurnStartComplete(iPlayerID)
	TryStartNavalSuperiority(iPlayerID);
end

GameEvents.OnCivicCulturevated.Add(OnCivicCompleted);
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);
GameEvents.OnPlayerTurnEnded.Add(OnPlayerTurnEnded);
GameEvents.PlayerTurnStartComplete.Add(OnPlayerTurnStartComplete);
GameEvents.RoseActiveStrategyAtWar.Add(RoseActiveStrategyAtWar);
GameEvents.RoseActiveStrategyMilitaryRecovery.Add(RoseActiveStrategyMilitaryRecovery);
GameEvents.RoseActiveStrategyWarAdvantage.Add(RoseActiveStrategyWarAdvantage);

-- These gameplay hooks are demonstrated by Firaxis' Black Death and Nubia
-- scenario scripts. UI GovernmentPolicyChanged is not the gameplay hook.
GameEvents.PolicyChanged.Add(OnSerfdomPolicyChanged);
GameEvents.CityBuilt.Add(SyncAllSerfdomOffsets);
GameEvents.CityConquered.Add(SyncAllSerfdomOffsets);
GameEvents.BuildingConstructed.Add(OnSerfdomBuildingChanged);
GameEvents.BuildingPillageStateChanged.Add(OnSerfdomBuildingChanged);

-- Additional notifications vary by Lua context. They are optional safety nets;
-- gameplay hooks, initial reconciliation and turn boundaries stand on their own.
for _, sEvent in ipairs({ "CapitalCityChanged", "CityRemovedFromMap",
	"LoadComplete", "LoadScreenClose" }) do
	if Events ~= nil and Events[sEvent] ~= nil then
		Events[sEvent].Add(SyncAllSerfdomOffsets);
	end
end
SyncAllSerfdomOffsets();

print("Rose AI: Serfdom experiment mode " .. iSerfdomMode);

print("Rose AI: Gameplay support script loaded");
