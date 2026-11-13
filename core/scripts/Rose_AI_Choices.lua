-- ============================================================================
-- Rose AI: the pantheon markers. The pantheon choice scorer reads
-- CITY_HAS_BUILDING, so the Holy Site pantheons carry an inactive Faith
-- signal that hidden marker buildings in the capital cancel or adjust. Sacred
-- Path, Desert Folklore and Dance of the Aurora read a terrain marker (plus a
-- strong one) for rainforest, desert and tundra; River Goddess reads the Khmer
-- marker the same way. A marker is placed in the capital of a religious AI (the
-- religious leader trait) that has no pantheon yet and is due it, and removed
-- everywhere else: after the pantheon, once no longer due, from another city,
-- from a non-religious AI, from a human, city-state or barbarian owner (a
-- captured or taken-over player), and when pillaged (then placed again). Runs
-- from PlayerTurnStarted through UpdatePantheonMarker; everything is read from
-- synchronized game state and re-derived each call, so no machine differs and
-- nothing is saved.
-- AGENTS.md "Holy Site pantheon signals".
-- ============================================================================

local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local PlayerHasLeaderTrait = RoseMod.PlayerHasLeaderTrait;

-- A terrain marker needs at least this many matching plots within this many rings of one city; the
-- strong marker needs the larger count.
local PANTHEON_TERRAIN_MIN = 3;
local PANTHEON_TERRAIN_STRONG = 6;
local PANTHEON_TERRAIN_RANGE = 2;

local HOLY_SITE_DISTRICT = "DISTRICT_HOLY_SITE";
local KHMER_CIVILIZATION = "CIVILIZATION_KHMER";
local tReligiousTraits = { "TRAIT_LEADER_RELIGIOUS_MAJOR_CIV" };

-- The terrains a terrain marker counts, by terrain type or by feature (rainforest is a feature; the
-- hills variants count, the mountains do not).
local tTerrainGroups = {
	{ Group = "JUNGLE", Features = { "FEATURE_JUNGLE" } },
	{ Group = "DESERT", Terrains = { "TERRAIN_DESERT", "TERRAIN_DESERT_HILLS" } },
	{ Group = "TUNDRA", Terrains = { "TERRAIN_TUNDRA", "TERRAIN_TUNDRA_HILLS" } },
};

-- The markers, in the order they are placed: a terrain marker is due when the best city has at
-- least Min matching plots of its Group; Khmer has a rule of its own.
local tMarkerDefs = {
	{ Label = "JUNGLE", Building = "BUILDING_ROSE_PANTHEON_MARKER_JUNGLE", Group = "JUNGLE", Min = PANTHEON_TERRAIN_MIN },
	{ Label = "JUNGLE_STRONG", Building = "BUILDING_ROSE_PANTHEON_MARKER_JUNGLE_STRONG", Group = "JUNGLE", Min = PANTHEON_TERRAIN_STRONG },
	{ Label = "DESERT", Building = "BUILDING_ROSE_PANTHEON_MARKER_DESERT", Group = "DESERT", Min = PANTHEON_TERRAIN_MIN },
	{ Label = "DESERT_STRONG", Building = "BUILDING_ROSE_PANTHEON_MARKER_DESERT_STRONG", Group = "DESERT", Min = PANTHEON_TERRAIN_STRONG },
	{ Label = "TUNDRA", Building = "BUILDING_ROSE_PANTHEON_MARKER_TUNDRA", Group = "TUNDRA", Min = PANTHEON_TERRAIN_MIN },
	{ Label = "TUNDRA_STRONG", Building = "BUILDING_ROSE_PANTHEON_MARKER_TUNDRA_STRONG", Group = "TUNDRA", Min = PANTHEON_TERRAIN_STRONG },
	{ Label = "KHMER", Building = "BUILDING_ROSE_PANTHEON_MARKER_KHMER", Kind = "KHMER" },
};

local tMarkers = nil; -- tMarkerDefs with Index (the building index, false when the row is missing)
local tTerrainSets = nil; -- tTerrainGroups resolved: { Group, tTerrains, tFeatures }
local tHolySiteDistricts = nil;
local tNoHolySiteTraits = nil; -- traits that exclude the Holy Site district
local tCivilizationTraits = nil; -- civilization type -> { trait type -> true }
local bMarkerPantheonWarned = false;
local bMarkerTerrainWarned = false;

-- The markers with their building indices, resolved once. Prints one line for each missing row;
-- that marker alone is then skipped.
local function GetMarkers()
	if tMarkers == nil then
		tMarkers = {};
		for _, kDef in ipairs(tMarkerDefs) do
			local kBuilding = GameInfo.Buildings[kDef.Building];
			local kMarker = { Label = kDef.Label, Group = kDef.Group, Min = kDef.Min, Kind = kDef.Kind, Index = false };
			if kBuilding == nil then
				print("Rose AI: Pantheon marker: no " .. kDef.Building .. " in GameInfo");
			else
				kMarker.Index = kBuilding.Index;
			end
			table.insert(tMarkers, kMarker);
		end
	end
	return tMarkers;
end

local function GetTerrainSets()
	if tTerrainSets == nil then
		tTerrainSets = {};
		for _, kDef in ipairs(tTerrainGroups) do
			local kSet = { Group = kDef.Group, tTerrains = {}, tFeatures = {} };
			for _, sTerrain in ipairs(kDef.Terrains or {}) do
				local kTerrain = GameInfo.Terrains[sTerrain];
				if kTerrain ~= nil then kSet.tTerrains[kTerrain.Index] = true; end
			end
			for _, sFeature in ipairs(kDef.Features or {}) do
				local kFeature = GameInfo.Features[sFeature];
				if kFeature ~= nil then kSet.tFeatures[kFeature.Index] = true; end
			end
			table.insert(tTerrainSets, kSet);
		end
	end
	return tTerrainSets;
end

-- District indices that count as a Holy Site: the district and its unique replacements.
local function GetHolySiteDistricts()
	if tHolySiteDistricts == nil then
		tHolySiteDistricts = {};
		local kHolySite = GameInfo.Districts[HOLY_SITE_DISTRICT];
		if kHolySite ~= nil then tHolySiteDistricts[kHolySite.Index] = true; end
		for kRow in GameInfo.DistrictReplaces() do
			if kRow.ReplacesDistrictType == HOLY_SITE_DISTRICT then
				local kUnique = GameInfo.Districts[kRow.CivUniqueDistrictType];
				if kUnique ~= nil then tHolySiteDistricts[kUnique.Index] = true; end
			end
		end
	end
	return tHolySiteDistricts;
end

-- Whether the player can build Holy Sites: no ExcludedDistricts row for the Holy Site names a trait
-- of its leader (following InheritFrom) or of its civilization.
local function CanBuildHolySites(iPlayerID)
	if tNoHolySiteTraits == nil then
		tNoHolySiteTraits = {};
		tCivilizationTraits = {};
		if GameInfo.ExcludedDistricts ~= nil then
			for kRow in GameInfo.ExcludedDistricts() do
				if kRow.DistrictType == HOLY_SITE_DISTRICT then table.insert(tNoHolySiteTraits, kRow.TraitType); end
			end
		end
		if #tNoHolySiteTraits > 0 and GameInfo.CivilizationTraits ~= nil then
			for kRow in GameInfo.CivilizationTraits() do
				local tSet = tCivilizationTraits[kRow.CivilizationType] or {};
				tSet[kRow.TraitType] = true;
				tCivilizationTraits[kRow.CivilizationType] = tSet;
			end
		end
	end
	if #tNoHolySiteTraits == 0 then return true; end
	if PlayerHasLeaderTrait(iPlayerID, tNoHolySiteTraits) then return false; end
	local pConfig = PlayerConfigurations[iPlayerID];
	local tSet = pConfig ~= nil and tCivilizationTraits[pConfig:GetCivilizationTypeName()] or nil;
	if tSet ~= nil then
		for _, sTrait in ipairs(tNoHolySiteTraits) do
			if tSet[sTrait] then return false; end
		end
	end
	return true;
end

-- The player's pantheon as a belief index, or nil when it has none. A failed read counts as none
-- and warns once.
local function ReadPantheon(pPlayer)
	local bRead, vBelief = pcall(function()
		local pReligion = pPlayer:GetReligion();
		return pReligion:GetPantheon();
	end);
	if not bRead then
		if not bMarkerPantheonWarned then
			bMarkerPantheonWarned = true;
			print("Rose AI: Pantheon marker cannot read the pantheon (" .. tostring(vBelief)
				.. "); treated as none");
		end
		return nil;
	end
	if type(vBelief) == "number" and vBelief >= 0 then return vBelief; end
	return nil;
end

-- For each terrain group (JUNGLE, DESERT, TUNDRA), the most matching plots any one of the player's
-- cities has: plots one to PANTHEON_TERRAIN_RANGE away, unowned or the player's own. Not a sum over
-- the cities. Plot terrain, feature and owner are synchronized game state.
local function GetPantheonTerrainCounts(pPlayer)
	local iPlayerID = pPlayer:GetID();
	local tSets = GetTerrainSets();
	local tCounts = {};
	for _, kSet in ipairs(tSets) do tCounts[kSet.Group] = 0; end
	for _, pCity in pPlayer:GetCities():Members() do
		local iX, iY = pCity:GetX(), pCity:GetY();
		local tHere = {};
		for _, kSet in ipairs(tSets) do tHere[kSet.Group] = 0; end
		for iDX = -PANTHEON_TERRAIN_RANGE, PANTHEON_TERRAIN_RANGE do
			for iDY = -PANTHEON_TERRAIN_RANGE, PANTHEON_TERRAIN_RANGE do
				local pPlot = Map.GetPlotXY(iX, iY, iDX, iDY);
				if pPlot ~= nil then
					local iDistance = Map.GetPlotDistance(iX, iY, pPlot:GetX(), pPlot:GetY());
					local iOwner = pPlot:GetOwner();
					if iDistance >= 1 and iDistance <= PANTHEON_TERRAIN_RANGE and (iOwner == -1 or iOwner == iPlayerID) then
						local iTerrain, iFeature = pPlot:GetTerrainType(), pPlot:GetFeatureType();
						for _, kSet in ipairs(tSets) do
							if kSet.tTerrains[iTerrain] == true or kSet.tFeatures[iFeature] == true then
								tHere[kSet.Group] = tHere[kSet.Group] + 1;
							end
						end
					end
				end
			end
		end
		for sGroup, iCount in pairs(tHere) do
			if iCount > tCounts[sGroup] then tCounts[sGroup] = iCount; end
		end
	end
	return tCounts;
end

-- Whether the marker is due in the capital of a player that passed the common base (a religious
-- eligible AI with a capital and no pantheon). bCanHolySite and bKhmer describe the player; tCounts is the
-- terrain counts, nil when they could not be read.
local function IsMarkerDue(kMarker, bCanHolySite, bKhmer, tCounts)
	if not bCanHolySite then return false; end
	if kMarker.Kind == "KHMER" then return bKhmer; end
	return tCounts ~= nil and tCounts[kMarker.Group] >= kMarker.Min;
end

-- Brings every city of the player in line: each marker the player is due in the capital, none in any
-- other city or for a player not due it.
local function UpdatePantheonMarker(iPlayerID)
	local tMarkerList = GetMarkers();
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	local pCities = pPlayer:GetCities();
	if pCities == nil then return; end
	local pCapital = pCities:GetCapitalCity();
	local bBase = pCapital ~= nil and IsEligibleAIPlayer(pPlayer) and ReadPantheon(pPlayer) == nil
		and PlayerHasLeaderTrait(iPlayerID, tReligiousTraits);
	local iCapitalID = pCapital ~= nil and pCapital:GetID() or nil;
	local bCanHolySite, bKhmer, tCounts = false, false, nil;
	if bBase then
		bCanHolySite = CanBuildHolySites(iPlayerID);
		local pConfig = PlayerConfigurations[iPlayerID];
		bKhmer = pConfig ~= nil and pConfig:GetCivilizationTypeName() == KHMER_CIVILIZATION;
		if bCanHolySite then
			for _, kMarker in ipairs(tMarkerList) do
				if kMarker.Group ~= nil and kMarker.Index ~= false then
					-- A failed count leaves the terrain markers out; the others carry on.
					local bCounted, vCounts = pcall(GetPantheonTerrainCounts, pPlayer);
					if bCounted then
						tCounts = vCounts;
					elseif not bMarkerTerrainWarned then
						bMarkerTerrainWarned = true;
						print("Rose AI: Pantheon marker cannot count terrain (" .. tostring(vCounts)
							.. "); terrain markers not placed");
					end
					break;
				end
			end
		end
	end
	for _, pCity in pCities:Members() do
		local iCityID = pCity:GetID();
		local pBuildings = pCity:GetBuildings();
		for _, kMarker in ipairs(tMarkerList) do
			local iIndex = kMarker.Index;
			if iIndex ~= false then
				local bDue = bBase and IsMarkerDue(kMarker, bCanHolySite, bKhmer, tCounts);
				local bHere = bDue and iCityID == iCapitalID;
				local bPresent = pBuildings:HasBuilding(iIndex);
				local bPillaged = bPresent and pBuildings:IsPillaged(iIndex);
				if bPresent and (not bHere or bPillaged) then
					pBuildings:RemoveBuilding(iIndex);
					pCity:GetBuildQueue():RemoveBuilding(iIndex);
					bPresent = false;
					print("Rose AI: Removed pantheon marker " .. kMarker.Label .. " player " .. iPlayerID .. " city " .. iCityID
						.. (bPillaged and " (pillaged)" or (bDue and " (not the capital)" or " (not due)")));
				end
				if bHere and not bPresent then
					-- Ordinary district buildings use (building, percent); only placed buildings need a plot.
					pCity:GetBuildQueue():CreateIncompleteBuilding(iIndex, 100);
					if pBuildings:HasBuilding(iIndex) then
						print("Rose AI: Added pantheon marker " .. kMarker.Label .. " player " .. iPlayerID .. " city " .. iCityID);
					else
						print("Rose AI ERROR: Pantheon marker " .. kMarker.Label .. " creation failed player " .. iPlayerID
							.. " city " .. iCityID);
					end
				end
			end
		end
	end
end

RoseMod.GetHolySiteDistricts = GetHolySiteDistricts;
RoseMod.CanBuildHolySites = CanBuildHolySites;
RoseMod.GetPantheonMarkers = GetMarkers;
RoseMod.GetPantheonTerrainCounts = GetPantheonTerrainCounts;
RoseMod.UpdatePantheonMarker = UpdatePantheonMarker;
