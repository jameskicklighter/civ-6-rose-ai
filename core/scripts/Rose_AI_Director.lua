-- ============================================================================
-- Rose AI: wartime war director. From PlayerTurnStartComplete, an AI at war
-- with a major orders a "Rose Wartime Siege" (a second one under War
-- Advantage) on the nearest enemy city it can take without marching past one
-- it waits on, and adds the army itself (a scripted operation never recruits);
-- CityConquered clears a taken city's
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
local ReadNavalSquadronShips = RoseMod.ReadNavalSquadronShips;
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
-- The wider margin for an army of DIRECTOR_WIDE_MARGIN_UNITS land units with
-- DIRECTOR_WIDE_MARGIN_SIEGE siege units.
local DIRECTOR_WIDE_DEFENSE_MARGIN = 20;
local DIRECTOR_WIDE_MARGIN_UNITS = 10;
local DIRECTOR_WIDE_MARGIN_SIEGE = 2;
-- Land units this close to another city of the target's owner, and nearer it
-- than the target, stay (they hold a siege of ours there).
local DIRECTOR_OTHER_CITY_RADIUS = 2;
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
-- Ranged ships for a coastal city: those within DIRECTOR_SHIP_RADIUS in water
-- that reaches within DIRECTOR_SHIP_FIRE_RANGE of it, at most DIRECTOR_MAX_SHIPS;
-- they do half a siege unit's wall damage, so DIRECTOR_SHIPS_PER_SIEGE count as
-- one, and only beside a land or air siege unit. AGENTS.md "Director ships for
-- coastal cities".
local DIRECTOR_SHIP_RADIUS = 10;
local DIRECTOR_SHIP_FIRE_RANGE = 2;
local DIRECTOR_MAX_SHIPS = 4;
local DIRECTOR_SHIPS_PER_SIEGE = 2;
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

-- Ranged ships of the derived role UNITTYPE_ROSE_NAVAL_SIEGE (military/
-- Rose_Operation_Roles.sql) with their ranged strength.
local tNavalSiegeUnits = {};
if GameInfo.UnitAiInfos ~= nil then
	for kRow in GameInfo.UnitAiInfos() do
		local kUnit = kRow.AiType == "UNITTYPE_ROSE_NAVAL_SIEGE" and GameInfo.Units[kRow.UnitType] or nil;
		if kUnit ~= nil then tNavalSiegeUnits[kUnit.Index] = { Ranged = kUnit.RangedCombat or 0 }; end
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

-- Our healthy ranged siege ships not held by an order or a naval superiority
-- squadron: { Unit, ID, X, Y, Ranged, Area } (Area nil when unreadable).
local function GatherShips(pPlayer, tReserved)
	local tShips = {};
	for _, pUnit in pPlayer:GetUnits():Members() do
		local kShip = tNavalSiegeUnits[pUnit:GetType()];
		if kShip ~= nil and not tReserved[pUnit:GetID()] and (pUnit:GetDamage() or 0) < DIRECTOR_MAX_DAMAGE then
			local iX, iY = pUnit:GetX(), pUnit:GetY();
			local bOk, iArea = pcall(function() return Map.GetPlot(iX, iY):GetAreaID(); end);
			table.insert(tShips, { Unit = pUnit, ID = pUnit:GetID(), X = iX, Y = iY, Ranged = kShip.Ranged,
				Area = (bOk and type(iArea) == "number") and iArea or nil });
		end
	end
	return tShips;
end

-- Whether the city is coastal (Plot:IsCoastalLand, else a water neighbour),
-- and the water bodies within DIRECTOR_SHIP_FIRE_RANGE of it as a set (nil
-- when an area cannot be read: any water body counts).
local function ReadCityWater(pCity)
	local iX, iY = pCity:GetX(), pCity:GetY();
	local pCityPlot = Map.GetPlot(iX, iY);
	local bOk, bCoastal = pcall(function() return pCityPlot:IsCoastalLand(); end);
	local tSeen, tFrontier, tAreas, bAnyArea = { [pCityPlot:GetIndex()] = true }, { pCityPlot }, {}, false;
	local bWaterNeighbour = false;
	for iRing = 1, DIRECTOR_SHIP_FIRE_RANGE do
		local tNext = {};
		for _, pPlot in ipairs(tFrontier) do
			for iDirection = 0, iDirections - 1 do
				local pNear = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), iDirection);
				if pNear ~= nil and not tSeen[pNear:GetIndex()] then
					tSeen[pNear:GetIndex()] = true;
					table.insert(tNext, pNear);
					if pNear:IsWater() then
						if iRing == 1 then bWaterNeighbour = true; end
						local bAreaOk, iArea = pcall(function() return pNear:GetAreaID(); end);
						if bAreaOk and type(iArea) == "number" then tAreas[iArea] = true; else bAnyArea = true; end
					end
				end
			end
		end
		tFrontier = tNext;
	end
	if bOk and type(bCoastal) == "boolean" then bWaterNeighbour = bCoastal; end
	return bWaterNeighbour, (not bAnyArea) and tAreas or nil;
end

-- The ships that can fire on a coastal city, nearest first (ties: lower id),
-- and the best ranged strength among them: { Coastal, Ships, Best }. An
-- unreadable coast counts as inland.
local bWaterReadWarned = false;
local function CityShips(pCity, tShips)
	local kInfo = { Coastal = false, Ships = {}, Best = 0 };
	local bOk, bCoastal, tAreas = pcall(ReadCityWater, pCity);
	if not bOk then
		if not bWaterReadWarned then
			bWaterReadWarned = true;
			print("Rose AI: War director cannot read the coast (" .. tostring(bCoastal) .. "); cities count as inland");
		end
		return kInfo;
	end
	kInfo.Coastal = bCoastal;
	if not bCoastal then return kInfo; end
	local iX, iY = pCity:GetX(), pCity:GetY();
	for _, kShip in ipairs(tShips) do
		local iDistance = Map.GetPlotDistance(kShip.X, kShip.Y, iX, iY);
		if iDistance <= DIRECTOR_SHIP_RADIUS and (tAreas == nil or kShip.Area == nil or tAreas[kShip.Area]) then
			table.insert(kInfo.Ships, { Ship = kShip, Distance = iDistance });
		end
	end
	table.sort(kInfo.Ships, function(a, b)
		if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
		return a.Ship.ID < b.Ship.ID;
	end);
	-- Only the ships an order would send.
	while #kInfo.Ships > DIRECTOR_MAX_SHIPS do table.remove(kInfo.Ships); end
	for _, kEntry in ipairs(kInfo.Ships) do
		if kEntry.Ship.Ranged > kInfo.Best then kInfo.Best = kEntry.Ship.Ranged; end
	end
	return kInfo;
end

-- The army for one city from our healthy, unreserved units near the rally city:
-- siege units first (land, then bombers in range; garrisons stay, land units at
-- another city of its owner, nearer it than the target, stay; bombers stay for
-- the nuclear launcher while we hold a device). Returns army, siege, land.
local function GatherSiegeArmy(pPlayer, pRally, pTarget, tOwnCentres, tReserved, bBreakers)
	local tLandSiege, tAir, tOther = {}, {}, {};
	local bDevices = nil;
	local iTX, iTY = pTarget:GetX(), pTarget:GetY();
	local tOtherCities = {};
	local pOwner = Players[pTarget:GetOwner()];
	local pVisibility = PlayersVisibility ~= nil and PlayersVisibility[pPlayer:GetID()] or nil;
	if pOwner ~= nil then
		for _, pCity in pOwner:GetCities():Members() do
			if (pCity:GetX() ~= iTX or pCity:GetY() ~= iTY)
				and (pVisibility == nil or pVisibility:IsRevealed(pCity:GetX(), pCity:GetY())) then
				table.insert(tOtherCities, pCity);
			end
		end
	end
	local function AtOtherCity(iX, iY, iToTarget)
		for _, pCity in ipairs(tOtherCities) do
			local iD = Map.GetPlotDistance(iX, iY, pCity:GetX(), pCity:GetY());
			if iD <= DIRECTOR_OTHER_CITY_RADIUS and iD < iToTarget then return true; end
		end
		return false;
	end
	for _, pUnit in pPlayer:GetUnits():Members() do
		local iType = pUnit:GetType();
		local kArmy, kAir = tArmyUnits[iType], tAirSiegeUnits[iType];
		if (kArmy ~= nil or kAir ~= nil) and not tReserved[pUnit:GetID()]
			and (pUnit:GetDamage() or 0) < DIRECTOR_MAX_DAMAGE then
			local iX, iY = pUnit:GetX(), pUnit:GetY();
			local kEntry = { Unit = pUnit, ID = pUnit:GetID(), Distance = Map.GetPlotDistance(iX, iY, iTX, iTY) };
			if kArmy ~= nil then
				if not tOwnCentres[iX .. "," .. iY] and (bBreakers or not kArmy.Breaker)
					and Map.GetPlotDistance(iX, iY, pRally:GetX(), pRally:GetY()) <= DIRECTOR_GATHER_RADIUS
					and not AtOtherCity(iX, iY, kEntry.Distance) then
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
-- Defense, Bombard, Ships }, the count of enemy cities within reach and the
-- cities waited on, { City, Owner, Distance, Rule } (an ended order's city for
-- DIRECTOR_FAILED_CITY_LOCK turns), or nil and a reason. A city under our live
-- order is neither. A coastal city's ships (CityShips) count in the defense rule.
local function FindDirectorTargets(pPlayer, tSince, iTurn, tOrders, tLatest, bAdvantage, tShips)
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

	-- Cities of live orders, and for DIRECTOR_FAILED_CITY_LOCK turns after its
	-- end, the city of an ended order.
	local tLive, tLocked, tLiveEnemy = {}, {}, {};
	for _, kOrder in ipairs(tOrders) do
		if not kOrder.Ended then
			tLive[kOrder.X .. "," .. kOrder.Y] = true;
			tLiveEnemy[kOrder.Enemy] = true;
		elseif iTurn - kOrder.EndTurn < DIRECTOR_FAILED_CITY_LOCK then
			tLocked[kOrder.X .. "," .. kOrder.Y] = true;
		end
	end
	local tWarIDs = {};
	for iOtherID, iSince in pairs(tSince) do
		if iTurn - iSince >= DIRECTOR_MIN_WAR_TURNS then table.insert(tWarIDs, iOtherID); end
	end
	table.sort(tWarIDs);
	-- Without War Advantage one siege per enemy: none within the pause from its
	-- last order, nor while that siege still runs (one army, one target).
	local tEnemyIDs = {};
	local iNextFree, iRunning = nil, 0;
	for _, iOtherID in ipairs(tWarIDs) do
		local iLatest = tLatest[iOtherID];
		if not bAdvantage and iLatest ~= nil and iTurn - iLatest < DIRECTOR_ENEMY_COOLDOWN then
			local iFree = iLatest + DIRECTOR_ENEMY_COOLDOWN;
			if iNextFree == nil or iFree < iNextFree then iNextFree = iFree; end
		elseif not bAdvantage and tLiveEnemy[iOtherID] then
			iRunning = iRunning + 1;
		else
			table.insert(tEnemyIDs, iOtherID);
		end
	end
	if #tEnemyIDs == 0 then
		if iNextFree ~= nil then
			return nil, "a siege was ordered against every enemy within " .. DIRECTOR_ENEMY_COOLDOWN
				.. " turns (next turn " .. iNextFree .. ")"
				.. (iRunning > 0 and ("; our siege still runs against " .. iRunning .. " more") or "");
		end
		if iRunning > 0 then
			return nil, "a siege of ours still runs against every enemy (" .. iRunning
				.. "); no second siege without War Advantage";
		end
		return nil, "no war with a major of " .. DIRECTOR_MIN_WAR_TURNS .. "+ turns";
	end

	local tCandidates, tWaited = {}, {};
	local iInReach = 0;
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
						if tLocked[iX .. "," .. iY] then
							table.insert(tWaited, { City = pCity, Owner = iOwner, Distance = iDistance, Rule = "locked" });
						elseif not tLive[iX .. "," .. iY] then
							if iBombard == nil then iBombard = GetBestBombard(pPlayer); end
							table.insert(tCandidates, { City = pCity, Owner = iOwner, Distance = iDistance,
								Rally = pRally, Population = pCity:GetPopulation(), Defense = ReadCityDefense(pCity),
								Bombard = iBombard, Ships = CityShips(pCity, tShips), Order = #tCandidates });
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
		return nil, "every enemy city within reach is under a siege we ordered or one ended there within "
			.. DIRECTOR_FAILED_CITY_LOCK .. " turns";
	end
	table.sort(tCandidates, function(a, b)
		if a.Distance ~= b.Distance then return a.Distance < b.Distance; end
		if a.Population ~= b.Population then return a.Population > b.Population; end
		return a.Order < b.Order;
	end);
	return tCandidates, nil, iInReach, tWaited;
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
	-- Units sent with a recorded order, and the ships of a naval superiority
	-- squadron that may still run, are not sent again.
	local tReserved = ReadNavalSquadronShips(pPlayer, iTurn);
	for _, kOrder in ipairs(tOrders) do
		for _, iUnit in ipairs(kOrder.Units) do tReserved[iUnit] = true; end
	end
	local tShips = GatherShips(pPlayer, tReserved);
	local bAdvantage = IsLatched(iPlayerID, ADVANTAGE_LATCH);
	local tCandidates, sReason, iInReach, tWaited = FindDirectorTargets(pPlayer, tSince, iTurn, tOrders, tLatest, bAdvantage, tShips);
	if tCandidates == nil then
		ReportDirectorReason(iPlayerID, sReason);
		return;
	end

	-- The first city, nearest first, whose army passes every rule and would not
	-- march past a nearer city of the same enemy that we wait on: one whose
	-- order ended recently or that a rule other than the land route refused,
	-- when half or more of the army's land units are no farther from it.
	local tOwnCentres = {};
	for _, pCity in pPlayer:GetCities():Members() do
		tOwnCentres[pCity:GetX() .. "," .. pCity:GetY()] = true;
	end
	local kTarget, tArmy, iStrike, iNeed, iLand, bWalls = nil, nil, 0, 0, 0, false;
	local pRallyUnit, iRallyDistance, iPath = nil, nil, nil;
	local tRefused = { defense = 0, army = 0, siege = 0, far = 0, nearer = 0, route = 0 };
	local sFirstRefusal = nil;
	for _, kCandidate in ipairs(tCandidates) do
		local pCandidate = kCandidate.City;
		local iCandidateNeed, bCandidateWalls, bBreakers = SiegeNeeds(pCandidate, kCandidate.Defense);
		local tUnits, iUnitsStrike, iUnitsLand = GatherSiegeArmy(pPlayer, kCandidate.Rally, pCandidate, tOwnCentres, tReserved, bBreakers);
		-- Ships add to a land or air siege unit, never replace the last one.
		local iShips = math.min(#kCandidate.Ships.Ships, DIRECTOR_MAX_SHIPS);
		local iShipCredit = iUnitsStrike > 0 and math.floor(iShips / DIRECTOR_SHIPS_PER_SIEGE) or 0;
		local sRule, sWhy = nil, nil;
		local pUnit, iDistance, iPathLength = nil, nil, nil;
		-- Defense against the better of our bombard and the ships' ranged
		-- strength, with a wider margin for a big army with its siege units.
		local iBest = math.max(kCandidate.Bombard, kCandidate.Ships.Best);
		local iMargin = (iUnitsLand >= DIRECTOR_WIDE_MARGIN_UNITS and iUnitsStrike + iShipCredit >= DIRECTOR_WIDE_MARGIN_SIEGE)
			and DIRECTOR_WIDE_DEFENSE_MARGIN or DIRECTOR_DEFENSE_MARGIN;
		if kCandidate.Defense ~= nil and kCandidate.Defense > iBest + iMargin then
			sRule, sWhy = "defense", "defense " .. kCandidate.Defense .. " above our best bombard " .. iBest .. " + " .. iMargin;
		elseif iUnitsLand < DIRECTOR_MIN_UNITS then
			sRule, sWhy = "army", "an army of " .. iUnitsLand .. " land units near our city "
				.. tostring(kCandidate.Rally:GetName()) .. " (needs " .. DIRECTOR_MIN_UNITS .. ")";
		elseif iUnitsStrike + iShipCredit < iCandidateNeed then
			sRule, sWhy = "siege", iUnitsStrike .. " siege units"
				.. (iShips > 0 and (" and " .. iShips .. " ranged ships") or "") .. " in its army (needs " .. iCandidateNeed
				.. (iShips > 0 and (", " .. DIRECTOR_SHIPS_PER_SIEGE .. " ships count as 1 beside a land or air siege unit") or "")
				.. ": walls " .. (bCandidateWalls and "yes" or "no") .. " defense " .. tostring(kCandidate.Defense) .. ")";
		else
			pUnit, iDistance = ChooseRally(tUnits, pCandidate);
			if iDistance > DIRECTOR_MAX_ARMY_DISTANCE then
				sRule, sWhy = "far", "the army is " .. iDistance .. " tiles from it (needs " .. DIRECTOR_MAX_ARMY_DISTANCE .. ")";
			else
				for _, kWait in ipairs(tWaited) do
					if kWait.Owner == kCandidate.Owner and kWait.Distance < kCandidate.Distance then
						local iWX, iWY = kWait.City:GetX(), kWait.City:GetY();
						local iLandSent, iAtWait = 0, 0;
						for _, pSent in ipairs(tUnits) do
							if tArmyUnits[pSent:GetType()] ~= nil then
								local iSX, iSY = pSent:GetX(), pSent:GetY();
								iLandSent = iLandSent + 1;
								if Map.GetPlotDistance(iSX, iSY, iWX, iWY)
									<= Map.GetPlotDistance(iSX, iSY, pCandidate:GetX(), pCandidate:GetY()) then
									iAtWait = iAtWait + 1;
								end
							end
						end
						if 2 * iAtWait >= iLandSent then
							sRule, sWhy = "nearer", iAtWait .. " of " .. iLandSent .. " land units of the army are no farther from "
								.. tostring(kWait.City:GetName()) .. " (" .. iWX .. "," .. iWY .. "), nearer and waited on ("
								.. kWait.Rule .. ")";
							break;
						end
					end
				end
			end
			if sRule == nil then
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
		if sRule ~= "route" and sRule ~= "nearer" then
			table.insert(tWaited, { City = pCandidate, Owner = kCandidate.Owner, Distance = kCandidate.Distance, Rule = sRule });
		end
		if sFirstRefusal == nil then
			sFirstRefusal = "nearest " .. tostring(pCandidate:GetName()) .. " (" .. pCandidate:GetX() .. ","
				.. pCandidate:GetY() .. "): " .. sWhy;
		end
	end
	if kTarget == nil then
		ReportDirectorReason(iPlayerID, #tCandidates .. " of " .. iInReach .. " enemy cities within reach, none ordered (defense above our bombard + margin "
			.. tRefused.defense .. ", army under "
			.. DIRECTOR_MIN_UNITS .. " units " .. tRefused.army .. ", too few siege units " .. tRefused.siege
			.. ", army over " .. DIRECTOR_MAX_ARMY_DISTANCE .. " tiles away " .. tRefused.far
			.. ", no land route " .. tRefused.route .. ", past a nearer city we wait on " .. tRefused.nearer .. "); " .. sFirstRefusal);
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
	-- The coastal city's ranged ships go to the team's naval row
	-- (IsCoastalTarget); recorded after the army.
	local kShips = kTarget.Ships;
	local tShipIDs = {};
	for i = 1, math.min(#kShips.Ships, DIRECTOR_MAX_SHIPS) do
		local iShip = kShips.Ships[i].Ship.ID;
		pMilitaryAI:AddUnitToScriptedOperation(iOperationID, iShip);
		table.insert(tShipIDs, iShip);
	end
	local tRecorded = {};
	for _, iUnit in ipairs(tUnitIDs) do table.insert(tRecorded, iUnit); end
	for _, iShip in ipairs(tShipIDs) do table.insert(tRecorded, iShip); end
	table.insert(tOrders, { Enemy = kTarget.Owner, Turn = iTurn, X = pCity:GetX(), Y = pCity:GetY(),
		Units = tRecorded });
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
		.. " unit ids " .. table.concat(tUnitIDs, ",")
		.. " coastal " .. (kShips.Coastal and "yes" or "no")
		.. " ships " .. #tShipIDs
		.. (#tShipIDs > 0 and (" credit " .. (iStrike > 0 and math.floor(#tShipIDs / DIRECTOR_SHIPS_PER_SIEGE) or 0)
			.. " best ranged " .. kShips.Best .. " ship ids " .. table.concat(tShipIDs, ",")) or ""));
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
