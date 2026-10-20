-- ============================================================================
-- Rose AI: wartime war director. From PlayerTurnStartComplete, an AI at war
-- with a major orders a "Rose Wartime Siege" (a second one under War
-- Advantage) on the nearest enemy city it can take and adds the army itself
-- (a scripted operation never recruits); CityConquered clears a taken city's
-- order. State: ROSE_DIRECTOR_ORDERS, ROSE_DIRECTOR_NEXT_ATTEMPT. AGENTS.md
-- "Wartime war director", "Rose Wartime Siege operation".
-- ============================================================================

local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetUnitInfo = RoseMod.GetUnitInfo;
local GetUnitOperationName = RoseMod.GetUnitOperationName;
local IsUnitUncommitted = RoseMod.IsUnitUncommitted;
local ReadOperationExists = RoseMod.ReadOperationExists;
local UpdateNuclearWarSince = RoseMod.UpdateNuclearWarSince;
local GetHeldDevices = RoseMod.GetHeldDevices;
local IsLatched = RoseMod.IsLatched;
local Guard = RoseMod.Guard;
local NewReasonReporter = RoseMod.NewReasonReporter;
local Codec = RoseMod.Codec;
local RECOVERY_LATCH = RoseMod.RECOVERY_LATCH;
local ADVANTAGE_LATCH = RoseMod.ADVANTAGE_LATCH;

-- Every choice is ordered by distance and ids and all state is in player
-- properties written from gameplay events, so every machine decides alike.
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

-- Trainable land bombard units (not unique) with their tech; the land units the
-- director may send (land combat but not recon, Siege when they bombard, plus
-- the Ram and Tower as Breaker); bombers with their range; land combat units.
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

-- Renaissance Walls and their unique replacements (the Tsikhe): a Battering
-- Ram or Siege Tower counts as a siege unit only against lower walls.
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

local bDefenseReadWarned = false;

local ReportDirectorReason = NewReasonReporter("Rose AI: War director not ordered for player ");

-- Recorded orders (an enemy may have two under War Advantage); format in Rose_AI_Core's codec.
local function ReadDirectorOrders(pPlayer)
	return Codec.ReadDirectorOrders(pPlayer:GetProperty(DIRECTOR_ORDERS_PROPERTY));
end

local function WriteDirectorOrders(pPlayer, tOrders)
	local sValue = Codec.DirectorOrders(tOrders);
	local sOld = pPlayer:GetProperty(DIRECTOR_ORDERS_PROPERTY);
	if (type(sOld) == "string" and sOld or "") ~= sValue then
		pPlayer:SetProperty(DIRECTOR_ORDERS_PROPERTY, sValue);
	end
end

-- Keeps orders still at war with an enemy that still holds the city, within
-- their lock or pause; ends a live order once no operation of ours targets its
-- enemy (unreadable keeps it). Returns the orders and each enemy's latest turn.
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

-- Siege units an order on this city needs (two with walls or a defense of
-- DIRECTOR_STRONG_DEFENSE or more, else none), whether it has walls, and
-- whether a Battering Ram or Siege Tower counts (Ancient or Medieval walls only).
local function SiegeNeeds(pCity, iDefense)
	local bWalls = CityHasWalls(pCity);
	local iNeed = (bWalls or (iDefense ~= nil and iDefense >= DIRECTOR_STRONG_DEFENSE)) and 2 or 0;
	return iNeed, bWalls, bWalls and not HasLateWalls(pCity);
end

-- The army for one city from our healthy, unreserved units near the rally city:
-- siege units first (land, then bombers in range; garrisons stay, bombers stay
-- for the nuclear launcher while we hold a device). Returns army, siege, land.
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

-- The rally: the sent land unit nearest the target standing on land at least
-- DIRECTOR_RALLY_MIN_DISTANCE tiles from it, else the nearest sent land unit
-- (ties: lower id), so the team assembles where it stands. Unit and distance.
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

-- Whether the army can walk there: the shortest GetMoveToPath to a land plot
-- next to the city within DIRECTOR_PATH_FACTOR x distance + 1, else the same
-- landmass. AGENTS.md "Paths and areas in gameplay Lua". Ok, reason, length.
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

-- An enemy major with DIRECTOR_THREAT_UNITS or more visible land combat units on
-- plots we own within DIRECTOR_THREAT_RADIUS of one of our cities: the enemy, the
-- city and the count (lowest enemy id, then our cities in order), or nil.
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

local function TryWarDirector(iPlayerID)
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

-- Taking a city we ordered a siege on drops that order, so the next siege on
-- its old owner may follow next turn; other captures change nothing. Event
-- arguments (capturer, previous owner, city id, x, y), as in Firaxis' scenarios.
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
		Guard("War director capture handler", OnDirectorCityConquered, iCapturerID, iOwnerID, iCityID, iX, iY);
	end);
end

RoseMod.TryWarDirector = TryWarDirector;
RoseMod.ReadDirectorOrders = ReadDirectorOrders;
