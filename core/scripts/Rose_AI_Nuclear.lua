-- ============================================================================
-- Rose AI: scripted nuclear strike. From PlayerTurnStartComplete, an AI that
-- holds a device and has fought a major for NUCLEAR_MIN_WAR_TURNS turn starts
-- orders "Rose Nuclear Strike" (one delivery unit, one launch) on a revealed
-- enemy major's city clear of our units and of protected cities; detonations
-- are counted from OnNuclearWeaponDetonated. State: the ROSE_NUCLEAR_* keys
-- below. AGENTS.md "Scripted nuclear strike", "Rose Nuclear Strike operation".
-- ============================================================================

local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetAliveCityOwners = RoseMod.GetAliveCityOwners;
local GetMajorsAtWar = RoseMod.GetMajorsAtWar;
local GetUnitInfo = RoseMod.GetUnitInfo;
local HasOperationAgainst = RoseMod.HasOperationAgainst;
local Guard = RoseMod.Guard;
local NewReasonReporter = RoseMod.NewReasonReporter;
local Codec = RoseMod.Codec;

-- Lua cannot see which operation holds a unit or whether one still runs, so an
-- unlaunched order blocks new ones for NUCLEAR_PENDING_TURNS while its unit
-- lives, and the cooldowns pace the rest (a launch on the ordered plot: 1 turn).
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

-- For every major we are at war with, the first turn start at which this hook
-- saw the war (also read by the war director).
local function UpdateNuclearWarSince(pPlayer, iTurn)
	local sOld = pPlayer:GetProperty(NUCLEAR_WAR_SINCE_PROPERTY);
	local tOld = Codec.ReadWarSince(sOld);
	local tSince = {};
	for _, pOther in ipairs(GetMajorsAtWar(pPlayer)) do
		local iOtherID = pOther:GetID();
		tSince[iOtherID] = tOld[iOtherID] or iTurn;
	end
	local sValue = Codec.WarSince(tSince);
	if (sOld or "") ~= sValue then
		pPlayer:SetProperty(NUCLEAR_WAR_SINCE_PROPERTY, sValue);
	end
	return tSince;
end

-- The last order { Operation, Turn, Unit, Owner, X, Y, Launched, Reported }, or nil.
local function ReadNuclearStrike(pPlayer)
	return Codec.ReadNuclearStrike(pPlayer:GetProperty(NUCLEAR_STRIKE_PROPERTY));
end

local function WriteNuclearStrike(pPlayer, kStrike)
	local sValue = Codec.NuclearStrike(kStrike);
	if pPlayer:GetProperty(NUCLEAR_STRIKE_PROPERTY) ~= sValue then
		pPlayer:SetProperty(NUCLEAR_STRIKE_PROPERTY, sValue);
	end
end

-- Plots this player's own detonations hit within the last NUCLEAR_RECENT_TURNS
-- turns, as a list of { X, Y, Turn }.
local function ReadRecentNukes(pPlayer, iTurn)
	local tRecent = {};
	for _, kNuke in ipairs(Codec.ReadRecentNukes(pPlayer:GetProperty(NUCLEAR_RECENT_PROPERTY))) do
		local iNuked = kNuke.Turn;
		if iTurn - iNuked < NUCLEAR_RECENT_TURNS then
			table.insert(tRecent, kNuke);
		end
	end
	return tRecent;
end

local function RecordRecentNuke(pPlayer, iX, iY, iTurn)
	local tNukes = {};
	for _, kNuke in ipairs(ReadRecentNukes(pPlayer, iTurn)) do
		if kNuke.X ~= iX or kNuke.Y ~= iY then
			table.insert(tNukes, kNuke);
		end
	end
	table.insert(tNukes, { X = iX, Y = iY, Turn = iTurn });
	pPlayer:SetProperty(NUCLEAR_RECENT_PROPERTY, Codec.RecentNukes(tNukes));
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
				-- damaged first (damage never rules one out), then the closest,
				-- then unit order.
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

local ReportNuclearReason = NewReasonReporter("Rose AI: Nuclear strike not ordered for player ");

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
	-- (an early refusal).
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

-- Any player's detonation is logged (plot owner, the launcher's survivors in
-- the blast). For an eligible AI it counts the launch and starts the launch
-- cooldown; it marks the open order launched only on the ordered plot.
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
		Guard("Nuclear detonation handler", OnNuclearWeaponDetonated, iPlayerID, iX, iY, iWMDType);
	end);
end

RoseMod.TryNuclearStrike = TryNuclearStrike;
RoseMod.UpdateNuclearWarSince = UpdateNuclearWarSince;
RoseMod.GetHeldDevices = GetHeldDevices;
