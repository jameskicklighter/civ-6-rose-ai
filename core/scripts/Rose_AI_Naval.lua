-- ============================================================================
-- Rose AI: scripted naval superiority interception. From PlayerTurnStartComplete,
-- an AI with an uncommitted melee ship near a visible at-war enemy combat ship
-- starts the "Naval Superiority" operation with that ship. State:
-- ROSE_NAVAL_SUPERIORITY_NEXT_ATTEMPT. With ROSE_VERBOSE_LOGS it also prints
-- a follow-up line per start and the launcher's not-started reasons (print-only,
-- kept in module locals, not saved). AGENTS.md "Naval Superiority replacement".
-- ============================================================================

local ROSE_VERBOSE_LOGS = RoseMod.VerboseLogs; -- set in Rose_AI_Core
local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetAliveCityOwners = RoseMod.GetAliveCityOwners;
local GetUnitInfo = RoseMod.GetUnitInfo;
local GetUnitOperationName = RoseMod.GetUnitOperationName;
local IsUnitUncommitted = RoseMod.IsUnitUncommitted;
local NewReasonReporter = RoseMod.NewReasonReporter;
local Guard = RoseMod.Guard;

local NAVAL_SUPERIORITY_SUCCESS_COOLDOWN = 12;
local NAVAL_SUPERIORITY_FAILURE_RETRY = 4;
local NAVAL_SUPERIORITY_MAX_DISTANCE = 12;
local NAVAL_FOLLOW_UP_TURNS = 15;

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

local function UnitHasAiType(pUnit, sAiType)
	local kUnit = GetUnitInfo(pUnit);
	if kUnit == nil then return false; end
	local tTypes = tUnitAiTypes[kUnit.UnitType];
	return tTypes ~= nil and tTypes[sAiType] == true;
end

local function IsNavalCombatUnit(pUnit)
	local kUnit = GetUnitInfo(pUnit);
	return kUnit ~= nil
		and kUnit.FormationClass == "FORMATION_CLASS_NAVAL"
		and UnitHasAiType(pUnit, "UNITTYPE_NAVAL")
		and math.max(kUnit.Combat or 0, kUnit.RangedCombat or 0, kUnit.Bombard or 0) > 0;
end

-- GetUnitOperationName gives the unit's current command, so this match
-- probably never fires. AGENTS.md "Known engine behaviour: gameplay-context Lua".
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
		return nil, nil, -1, nil, #tFriendlyShips;
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
	return pBestTargetPlot, pBestShip, iBestOwner, pBestTargetUnit, #tFriendlyShips;
end

-- ============================================================================
-- Verbose follow-up: what became of each start and why the launcher did not
-- start one. Print-only; the records are not saved, so a reload forgets them.
-- ============================================================================

-- player ID -> list of { Operation, Turn, Ship, ShipType, Target, TargetType,
-- TargetOwner } for the starts still followed.
local tNavalStarts = {};
local ReportNavalReason = NewReasonReporter("Rose AI: Naval superiority not started for player ");

local function GetUnitTypeName(pUnit)
	local kUnit = GetUnitInfo(pUnit);
	return kUnit ~= nil and kUnit.UnitType or "?";
end

local function RememberNavalStart(iPlayerID, iOperationID, pShip, pTargetUnit, iTargetOwner, iTurn)
	local tStarts = tNavalStarts[iPlayerID];
	if tStarts == nil then
		tStarts = {};
		tNavalStarts[iPlayerID] = tStarts;
	end
	table.insert(tStarts, {
		Operation = iOperationID, Turn = iTurn,
		Ship = pShip:GetID(), ShipType = GetUnitTypeName(pShip),
		Target = pTargetUnit:GetID(), TargetType = GetUnitTypeName(pTargetUnit),
		TargetOwner = iTargetOwner });
end

-- A unit's method value, or "?" when the call fails or gives nothing.
local function UnitValue(pUnit, sMethod)
	local bOk, value = pcall(function() return pUnit[sMethod](pUnit); end);
	if not bOk or value == nil then return "?"; end
	return value;
end

local function IsVisibleTo(iPlayerID, pUnit)
	local bOk, bVisible = pcall(function()
		return PlayersVisibility[iPlayerID]:IsVisible(pUnit:GetX(), pUnit:GetY());
	end);
	if not bOk then return "?"; end
	return bVisible and "yes" or "no";
end

local function DescribeNavalShip(kStart, pShip)
	local sHead = "ship " .. kStart.Ship .. " " .. kStart.ShipType;
	if pShip == nil then return sHead .. " gone"; end
	local sCommand = GetUnitOperationName(pShip);
	return sHead .. " plot " .. UnitValue(pShip, "GetX") .. "," .. UnitValue(pShip, "GetY")
		.. " damage " .. UnitValue(pShip, "GetDamage") .. "/" .. UnitValue(pShip, "GetMaxDamage")
		.. " command " .. (sCommand ~= "" and sCommand or "none");
end

local function DescribeNavalTarget(kStart, pTarget, iPlayerID)
	local sHead = "target " .. kStart.Target .. " " .. kStart.TargetType
		.. " owner " .. kStart.TargetOwner;
	if pTarget == nil then return sHead .. " gone"; end
	return sHead .. " plot " .. UnitValue(pTarget, "GetX") .. "," .. UnitValue(pTarget, "GetY")
		.. " damage " .. UnitValue(pTarget, "GetDamage") .. "/" .. UnitValue(pTarget, "GetMaxDamage")
		.. " visible " .. IsVisibleTo(iPlayerID, pTarget);
end

local function GetNavalDistance(pShip, pTarget)
	if pShip == nil or pTarget == nil then return "n/a"; end
	local bOk, iDistance = pcall(function()
		return Map.GetPlotDistance(pShip:GetX(), pShip:GetY(), pTarget:GetX(), pTarget:GetY());
	end);
	if not bOk or iDistance == nil then return "?"; end
	return iDistance;
end

local function FindUnit(iOwnerID, iUnitID)
	local pOwner = Players[iOwnerID];
	if pOwner == nil then return nil; end
	return pOwner:GetUnits():FindID(iUnitID);
end

-- One follow-up line for a remembered start, or its end line when the ship or
-- the target is gone or the start is old. Returns whether to keep following.
local function FollowNavalStart(iPlayerID, kStart, iTurn)
	local pShip = FindUnit(iPlayerID, kStart.Ship);
	local pTarget = FindUnit(kStart.TargetOwner, kStart.Target);
	local iElapsed = iTurn - kStart.Turn;
	local sEnd = nil;
	if pShip == nil and pTarget == nil then
		sEnd = "ship lost and target gone";
	elseif pShip == nil then
		sEnd = "ship lost";
	elseif pTarget == nil then
		sEnd = "target gone";
	elseif iElapsed >= NAVAL_FOLLOW_UP_TURNS then
		sEnd = NAVAL_FOLLOW_UP_TURNS .. " turns";
	end
	print("Rose AI: Naval superiority " .. (sEnd ~= nil and "ended" or "follow-up")
		.. " for player " .. iPlayerID .. " turn " .. iTurn
		.. " operation " .. kStart.Operation
		.. " started turn " .. kStart.Turn .. " (" .. iElapsed .. " turns in)"
		.. (sEnd ~= nil and (" reason " .. sEnd) or "")
		.. ": " .. DescribeNavalShip(kStart, pShip)
		.. "; " .. DescribeNavalTarget(kStart, pTarget, iPlayerID)
		.. "; distance " .. GetNavalDistance(pShip, pTarget));
	return sEnd == nil;
end

-- Follows each remembered start of the player. A start whose follow-up errors
-- prints one error line and is dropped; the others carry on.
local function UpdateNavalFollowUp(iPlayerID)
	local tStarts = tNavalStarts[iPlayerID];
	if tStarts == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local tKept = {};
	for _, kStart in ipairs(tStarts) do
		local bOk, bKeep = pcall(FollowNavalStart, iPlayerID, kStart, iTurn);
		if not bOk then
			print("Rose AI ERROR: Naval superiority follow-up for player " .. iPlayerID
				.. " operation " .. tostring(kStart.Operation) .. ": " .. tostring(bKeep));
		elseif bKeep then
			table.insert(tKept, kStart);
		end
	end
	if #tKept == 0 then
		tNavalStarts[iPlayerID] = nil;
	else
		tNavalStarts[iPlayerID] = tKept;
	end
end

local function TryStartNavalSuperiority(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then return; end
	if HasActiveNavalOperation(pPlayer) then
		if ROSE_VERBOSE_LOGS then
			ReportNavalReason(iPlayerID, "an earlier naval superiority still active");
		end
		return;
	end

	local iTurn = Game.GetCurrentGameTurn();
	local iNextAttempt = pPlayer:GetProperty(
		NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY);
	if iNextAttempt ~= nil and iTurn < iNextAttempt then return; end

	local pTargetPlot, pShip, iTargetOwner, pTargetUnit, iShips =
		FindNavalSuperiorityTarget(iPlayerID);
	if pTargetPlot == nil or pShip == nil or iTargetOwner < 0 or pTargetUnit == nil then
		pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
			iTurn + NAVAL_SUPERIORITY_FAILURE_RETRY);
		if ROSE_VERBOSE_LOGS then
			ReportNavalReason(iPlayerID, iShips == 0
				and "no uncommitted melee ship"
				or ("no visible at-war enemy combat ship within "
					.. NAVAL_SUPERIORITY_MAX_DISTANCE .. " tiles"));
		end
		return;
	end
	if ROSE_VERBOSE_LOGS then ReportNavalReason(iPlayerID, nil); end
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
		if ROSE_VERBOSE_LOGS then
			Guard("Naval superiority start record", RememberNavalStart,
				iPlayerID, iOperationID, pShip, pTargetUnit, iTargetOwner, iTurn);
		end
	else
		pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
			iTurn + NAVAL_SUPERIORITY_FAILURE_RETRY);
		print("Rose AI: Naval superiority start rejected for player "
			.. iPlayerID .. " result " .. tostring(iOperationID));
	end
end

RoseMod.TryStartNavalSuperiority = TryStartNavalSuperiority;
RoseMod.UpdateNavalSuperiorityFollowUp = UpdateNavalFollowUp;
