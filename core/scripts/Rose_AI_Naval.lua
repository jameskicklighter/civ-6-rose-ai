-- ============================================================================
-- Rose AI: scripted naval superiority interception. From PlayerTurnStartComplete,
-- an AI with uncommitted combat ships near a visible at-war enemy combat ship
-- starts the "Naval Superiority" operation and adds a squadron of up to three
-- of them; an enemy ship near a war director army is chosen first (escort).
-- State: ROSE_NAVAL_SUPERIORITY_NEXT_ATTEMPT, ROSE_NAVAL_ESCORT_NEXT_ATTEMPT,
-- ROSE_NAVAL_SQUADRON. With ROSE_VERBOSE_LOGS it also prints a follow-up line
-- per start and the launcher's not-started reasons (print-only, kept in module
-- locals, not saved). AGENTS.md "Naval Superiority replacement", "Naval
-- superiority squadrons and director escorts".
-- ============================================================================

local ROSE_VERBOSE_LOGS = RoseMod.VerboseLogs; -- set in Rose_AI_Core
local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetAliveCityOwners = RoseMod.GetAliveCityOwners;
local GetUnitInfo = RoseMod.GetUnitInfo;
local GetUnitOperationName = RoseMod.GetUnitOperationName;
local IsUnitUncommitted = RoseMod.IsUnitUncommitted;
local NewReasonReporter = RoseMod.NewReasonReporter;
local Guard = RoseMod.Guard;
local Codec = RoseMod.Codec;

local NAVAL_SUPERIORITY_SUCCESS_COOLDOWN = 12;
local NAVAL_SUPERIORITY_FAILURE_RETRY = 4;
local NAVAL_SUPERIORITY_MAX_DISTANCE = 12;
local NAVAL_FOLLOW_UP_TURNS = 15;
-- The squadron: the team's MaxUnits and its melee and ranged maxima
-- (military/Operations.xml); damaged ships stay out, as in the war director.
local NAVAL_SQUADRON_SIZE = 3;
local NAVAL_SQUADRON_ROLE_MAX = 2;
local NAVAL_MAX_DAMAGE = 50;
-- The war director leaves a start's ships alone this long (an operation's life).
local NAVAL_SQUADRON_LOCK = 10;
-- Escort: an enemy ship this close to a unit of a live director order in its
-- first NAVAL_ESCORT_ORDER_TURNS (the march; a naval operation against the
-- order's enemy also reads as the order's operation in the director's end
-- signal, so escorts stop early); the check after a start or a refused start
-- (a live operation refuses the next).
local NAVAL_ESCORT_RADIUS = 5;
local NAVAL_ESCORT_ORDER_TURNS = 10;
local NAVAL_ESCORT_RETRY = 4;

local NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY = "ROSE_NAVAL_SUPERIORITY_NEXT_ATTEMPT";
local NAVAL_ESCORT_NEXT_ATTEMPT_PROPERTY = "ROSE_NAVAL_ESCORT_NEXT_ATTEMPT";
local NAVAL_SQUADRON_PROPERTY = "ROSE_NAVAL_SQUADRON";

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

-- The team role a squadron ship fills (Naval Superiority Force takes melee and
-- ranged ships, no nuclear delivery unit), or nil.
local function GetSquadronRole(pUnit)
	if not IsNavalCombatUnit(pUnit) or UnitHasAiType(pUnit, "UNITTYPE_NUCLEAR") then return nil; end
	if UnitHasAiType(pUnit, "UNITTYPE_MELEE") then return "MELEE"; end
	if UnitHasAiType(pUnit, "UNITTYPE_RANGED") then return "RANGED"; end
	return nil;
end

-- The water body (area) of a plot, or nil when it cannot be read; nil matches any.
local function GetPlotArea(iX, iY)
	local bOk, iArea = pcall(function() return Map.GetPlot(iX, iY):GetAreaID(); end);
	if bOk and type(iArea) == "number" then return iArea; end
	return nil;
end

local function SameWater(iArea, iOtherArea)
	return iArea == nil or iOtherArea == nil or iArea == iOtherArea;
end

-- Live (not ended) war director orders of the player, and those of them still
-- young enough to escort; the director module loads after this one, so its
-- reader is looked up at call time.
local function GetLiveDirectorOrders(pPlayer, iTurn)
	local tLive, tYoung = {}, {};
	local fnRead = RoseMod.ReadDirectorOrders;
	if fnRead == nil then return tLive, tYoung; end
	for _, kOrder in ipairs(fnRead(pPlayer)) do
		if not kOrder.Ended then
			table.insert(tLive, kOrder);
			if iTurn - kOrder.Turn < NAVAL_ESCORT_ORDER_TURNS then table.insert(tYoung, kOrder); end
		end
	end
	return tLive, tYoung;
end

-- Ships that may join a squadron: combat ships with no unit command, under
-- NAVAL_MAX_DAMAGE, not sent with a war director order (a ship the director
-- added this turn has no command yet). { Unit, ID, Role, X, Y, Area }.
local function GetAvailableShips(pPlayer, tReserved)
	local tShips = {};
	for _, pUnit in pPlayer:GetUnits():Members() do
		local sRole = GetSquadronRole(pUnit);
		if sRole ~= nil and IsUnitUncommitted(pUnit) and not tReserved[pUnit:GetID()]
			and (pUnit:GetDamage() or 0) < NAVAL_MAX_DAMAGE then
			local iX, iY = pUnit:GetX(), pUnit:GetY();
			table.insert(tShips, { Unit = pUnit, ID = pUnit:GetID(), Role = sRole, X = iX, Y = iY,
				Area = GetPlotArea(iX, iY) });
		end
	end
	return tShips;
end

-- Visible enemy combat ships of the players we are at war with, in player
-- order. Gameplay Lua can enumerate hidden enemy units; current visibility
-- lets the behavior tree's naval target selector recognize the same ship on
-- its first tick. { Unit, Owner, X, Y, Area }.
local function GetVisibleEnemyShips(iPlayerID, pVisibility)
	local pDiplomacy = Players[iPlayerID]:GetDiplomacy();
	local tEnemies = {};
	for _, pOther in ipairs(GetAliveCityOwners()) do
		local iOtherID = pOther:GetID();
		if iOtherID ~= iPlayerID and pDiplomacy:IsAtWarWith(iOtherID) then
			for _, pEnemyUnit in pOther:GetUnits():Members() do
				local iX, iY = pEnemyUnit:GetX(), pEnemyUnit:GetY();
				if IsNavalCombatUnit(pEnemyUnit) and pVisibility:IsVisible(iX, iY) then
					table.insert(tEnemies, { Unit = pEnemyUnit, Owner = iOtherID, X = iX, Y = iY,
						Area = GetPlotArea(iX, iY) });
				end
			end
		end
	end
	return tEnemies;
end

-- Our ship nearest the enemy ship within NAVAL_SUPERIORITY_MAX_DISTANCE in
-- the same water (ties: lower id), and its distance, or nil.
local function NearestShip(tShips, kEnemy)
	local kBest, iBest = nil, nil;
	for _, kShip in ipairs(tShips) do
		local iDistance = Map.GetPlotDistance(kShip.X, kShip.Y, kEnemy.X, kEnemy.Y);
		if iDistance <= NAVAL_SUPERIORITY_MAX_DISTANCE and SameWater(kShip.Area, kEnemy.Area)
			and (iBest == nil or iDistance < iBest or (iDistance == iBest and kShip.ID < kBest.ID)) then
			kBest, iBest = kShip, iDistance;
		end
	end
	return kBest, iBest;
end

-- Interception: the visible enemy ship nearest one of our ships (ties: owner,
-- then unit id). Enemy, seed ship.
local function IsEarlierEnemy(kEnemy, kOther)
	if kEnemy.Owner ~= kOther.Owner then return kEnemy.Owner < kOther.Owner; end
	return kEnemy.Unit:GetID() < kOther.Unit:GetID();
end

local function FindNavalSuperiorityTarget(tShips, tEnemies)
	local kBestEnemy, kBestShip, iBestDistance = nil, nil, nil;
	for _, kEnemy in ipairs(tEnemies) do
		local kShip, iDistance = NearestShip(tShips, kEnemy);
		if kShip ~= nil and (iBestDistance == nil or iDistance < iBestDistance
			or (iDistance == iBestDistance and IsEarlierEnemy(kEnemy, kBestEnemy))) then
			kBestEnemy, kBestShip, iBestDistance = kEnemy, kShip, iDistance;
		end
	end
	return kBestEnemy, kBestShip;
end

-- Escort: the visible enemy ship nearest a land unit of a live director order,
-- within NAVAL_ESCORT_RADIUS (ties: owner, then unit id), that one of our
-- ships can reach. Enemy, seed ship, the order and the threat distance.
local function FindEscortTarget(pPlayer, tOrders, tShips, tEnemies)
	local tOwn = {};
	for _, pUnit in pPlayer:GetUnits():Members() do tOwn[pUnit:GetID()] = pUnit; end
	local tThreats = {};
	for _, kOrder in ipairs(tOrders) do
		for _, iUnit in ipairs(kOrder.Units) do
			local pUnit = tOwn[iUnit];
			local kUnit = GetUnitInfo(pUnit);
			if kUnit ~= nil and kUnit.Domain == "DOMAIN_LAND" then
				for _, kEnemy in ipairs(tEnemies) do
					local iDistance = Map.GetPlotDistance(pUnit:GetX(), pUnit:GetY(), kEnemy.X, kEnemy.Y);
					if iDistance <= NAVAL_ESCORT_RADIUS then
						local kThreat = tThreats[kEnemy];
						if kThreat == nil or iDistance < kThreat.Distance then
							tThreats[kEnemy] = { Enemy = kEnemy, Order = kOrder, Distance = iDistance };
						end
					end
				end
			end
		end
	end
	local tSorted = {};
	for _, kThreat in pairs(tThreats) do table.insert(tSorted, kThreat); end
	table.sort(tSorted, function(a, b)
		if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
		return IsEarlierEnemy(a.Enemy, b.Enemy);
	end);
	for _, kThreat in ipairs(tSorted) do
		local kShip = NearestShip(tShips, kThreat.Enemy);
		if kShip ~= nil then return kThreat.Enemy, kShip, kThreat.Order, kThreat.Distance; end
	end
	return nil;
end

-- The seed ship, then the ships nearest the enemy ship within reach in the
-- same water (ties: lower id), up to NAVAL_SQUADRON_SIZE and
-- NAVAL_SQUADRON_ROLE_MAX of each role.
local function BuildSquadron(kSeed, kEnemy, tShips)
	local tSquadron = { kSeed };
	local tRoles = { [kSeed.Role] = 1 };
	local tOthers = {};
	for _, kShip in ipairs(tShips) do
		if kShip ~= kSeed and SameWater(kShip.Area, kEnemy.Area) then
			kShip.Distance = Map.GetPlotDistance(kShip.X, kShip.Y, kEnemy.X, kEnemy.Y);
			if kShip.Distance <= NAVAL_SUPERIORITY_MAX_DISTANCE then table.insert(tOthers, kShip); end
		end
	end
	table.sort(tOthers, function(a, b)
		if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
		return a.ID < b.ID;
	end);
	for _, kShip in ipairs(tOthers) do
		if #tSquadron >= NAVAL_SQUADRON_SIZE then break; end
		if (tRoles[kShip.Role] or 0) < NAVAL_SQUADRON_ROLE_MAX then
			table.insert(tSquadron, kShip);
			tRoles[kShip.Role] = (tRoles[kShip.Role] or 0) + 1;
		end
	end
	return tSquadron;
end

-- The ships of the last start while it may still run (NAVAL_SQUADRON_LOCK),
-- as a set of unit ids; the war director does not send them.
local function ReadNavalSquadronShips(pPlayer, iTurn)
	local tShips = {};
	local kSquadron = Codec.ReadNavalSquadron(pPlayer:GetProperty(NAVAL_SQUADRON_PROPERTY));
	if kSquadron ~= nil and iTurn - kSquadron.Turn < NAVAL_SQUADRON_LOCK then
		for _, iShip in ipairs(kSquadron.Ships) do tShips[iShip] = true; end
	end
	return tShips;
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

	-- Interception keeps its pace (NEXT_ATTEMPT); an escort is checked every
	-- turn while a director order is in its first NAVAL_ESCORT_ORDER_TURNS,
	-- after a start or refusal only from ROSE_NAVAL_ESCORT_NEXT_ATTEMPT.
	local iTurn = Game.GetCurrentGameTurn();
	local iNextAttempt = pPlayer:GetProperty(
		NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY);
	local bInterception = not (iNextAttempt ~= nil and iTurn < iNextAttempt);
	local iEscortNext = pPlayer:GetProperty(NAVAL_ESCORT_NEXT_ATTEMPT_PROPERTY);
	local tOrders, tYoungOrders = GetLiveDirectorOrders(pPlayer, iTurn);
	local bEscort = #tYoungOrders > 0 and not (iEscortNext ~= nil and iTurn < iEscortNext);
	if not bInterception and not bEscort then return; end

	local tReserved = {};
	for _, kOrder in ipairs(tOrders) do
		for _, iUnit in ipairs(kOrder.Units) do tReserved[iUnit] = true; end
	end
	local tShips = GetAvailableShips(pPlayer, tReserved);
	local iShips = #tShips;
	local pVisibility = PlayersVisibility ~= nil and PlayersVisibility[iPlayerID] or nil;
	local tEnemies = (iShips > 0 and pVisibility ~= nil) and GetVisibleEnemyShips(iPlayerID, pVisibility) or {};
	local kEnemy, kSeed, kEscortOrder, iThreatDistance = nil, nil, nil, nil;
	if bEscort then
		kEnemy, kSeed, kEscortOrder, iThreatDistance = FindEscortTarget(pPlayer, tYoungOrders, tShips, tEnemies);
	end
	if kEnemy == nil and bInterception then
		kEnemy, kSeed = FindNavalSuperiorityTarget(tShips, tEnemies);
	end
	if kEnemy == nil then
		if bInterception then
			pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
				iTurn + NAVAL_SUPERIORITY_FAILURE_RETRY);
			if ROSE_VERBOSE_LOGS then
				ReportNavalReason(iPlayerID, iShips == 0
					and "no uncommitted combat ship"
					or ("no visible at-war enemy combat ship within "
						.. NAVAL_SUPERIORITY_MAX_DISTANCE .. " tiles"));
			end
		end
		return;
	end
	if ROSE_VERBOSE_LOGS then ReportNavalReason(iPlayerID, nil); end
	local pShip, pTargetUnit, iTargetOwner = kSeed.Unit, kEnemy.Unit, kEnemy.Owner;
	local sMode = kEscortOrder ~= nil and "escort" or "interception";
	local pMilitaryAI = pPlayer:GetAi_Military();
	local pTargetPlot = Map.GetPlot(kEnemy.X, kEnemy.Y);
	local pRallyPlot = Map.GetPlot(pShip:GetX(), pShip:GetY());
	if pMilitaryAI == nil or pTargetPlot == nil or pRallyPlot == nil then return; end

	print("Rose AI: Attempting naval superiority for player " .. iPlayerID
		.. " against player " .. iTargetOwner
		.. " target plot " .. pTargetPlot:GetIndex()
		.. " target unit " .. pTargetUnit:GetID()
		.. " with ship " .. pShip:GetID()
		.. " mode " .. sMode
		.. " plot owner " .. tostring(pTargetPlot.GetOwner ~= nil and pTargetPlot:GetOwner() or "?"));
	local iOperationID = pMilitaryAI:StartScriptedOperationWithTargetAndRally(
		"Naval Superiority",
		iTargetOwner,
		pTargetPlot:GetIndex(),
		pRallyPlot:GetIndex());
	-- The DLL returns the operation id, or -1 (no slot) or 0 (an early refusal).
	if type(iOperationID) == "number" and iOperationID > 0 then
		pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
			iTurn + NAVAL_SUPERIORITY_SUCCESS_COOLDOWN);
		pPlayer:SetProperty(NAVAL_ESCORT_NEXT_ATTEMPT_PROPERTY, iTurn + NAVAL_ESCORT_RETRY);
		-- Recorded before the adds, so the director leaves them alone even if an add fails.
		local tSquadron = BuildSquadron(kSeed, kEnemy, tShips);
		local tIDs, tTypes = {}, {};
		for _, kShip in ipairs(tSquadron) do
			table.insert(tIDs, kShip.ID);
			table.insert(tTypes, GetUnitTypeName(kShip.Unit));
		end
		pPlayer:SetProperty(NAVAL_SQUADRON_PROPERTY, Codec.NavalSquadron(iTurn, tIDs));
		local bAdded = nil;
		for i, kShip in ipairs(tSquadron) do
			local bResult = pMilitaryAI:AddUnitToScriptedOperation(iOperationID, kShip.ID);
			if i == 1 then bAdded = bResult; end
		end
		print("Rose AI: Started naval superiority for player " .. iPlayerID
			.. " operation " .. iOperationID
			.. " assigned ship " .. pShip:GetID()
			.. " add result " .. tostring(bAdded)
			.. " unit operation " .. GetUnitOperationName(pShip)
			.. " mode " .. sMode
			.. " squadron " .. #tIDs .. " ship ids " .. table.concat(tIDs, ",")
			.. " types " .. table.concat(tTypes, ",")
			.. (kEscortOrder ~= nil and (" escorting the order of turn " .. kEscortOrder.Turn
				.. " against player " .. kEscortOrder.Enemy .. " plot (" .. kEscortOrder.X .. "," .. kEscortOrder.Y
				.. "), threat distance " .. iThreatDistance) or ""));
		if ROSE_VERBOSE_LOGS then
			Guard("Naval superiority start record", RememberNavalStart,
				iPlayerID, iOperationID, pShip, pTargetUnit, iTargetOwner, iTurn);
		end
	else
		-- A refused escort paces only the escort, so a refused target near the
		-- army cannot hold off interception, which tries again next turn.
		if kEscortOrder == nil then
			pPlayer:SetProperty(NAVAL_SUPERIORITY_NEXT_ATTEMPT_PROPERTY,
				iTurn + NAVAL_SUPERIORITY_FAILURE_RETRY);
		end
		pPlayer:SetProperty(NAVAL_ESCORT_NEXT_ATTEMPT_PROPERTY, iTurn + NAVAL_ESCORT_RETRY);
		print("Rose AI: Naval superiority start rejected for player "
			.. iPlayerID .. " result " .. tostring(iOperationID)
			.. " mode " .. sMode);
	end
end

RoseMod.TryStartNavalSuperiority = function(iPlayerID)
	Guard("Naval superiority", TryStartNavalSuperiority, iPlayerID);
end;
RoseMod.UpdateNavalSuperiorityFollowUp = UpdateNavalFollowUp;
RoseMod.ReadNavalSquadronShips = ReadNavalSquadronShips;
