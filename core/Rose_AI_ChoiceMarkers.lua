-- The belief scorer understands CITY_HAS_BUILDING, but not the required leader
-- or general-war checks. Crusade uses military markers; Defender of the Faith
-- uses temporary major-war markers. Each signal also requires a Palace. Markers stay
-- in all eligible cities so native Palace movement needs no special Lua hook.
-- This helper never modifies beliefs, yields, policy slots, or envoy balances.

local marker = GameInfo.Buildings["BUILDING_ROSE_MILITARY_CHOICE_MARKER"];
local markerIndex = marker ~= nil and marker.Index or nil;
local warMarker = GameInfo.Buildings["BUILDING_ROSE_WAR_CHOICE_MARKER"];
local warMarkerIndex = warMarker ~= nil and warMarker.Index or nil;
local militaryLeaders = {};
for row in GameInfo.LeaderTraits() do
    if row.TraitType == "TRAIT_LEADER_AGGRESSIVE_MILITARY" then
        militaryLeaders[row.LeaderType] = true;
    end
end

local function IsEligibleAI(player)
    return player ~= nil and player:IsAlive() and player:IsMajor() and not player:IsHuman();
end

local function IsMilitaryAI(playerID, player)
    if not IsEligibleAI(player) then return false; end
    local config = PlayerConfigurations[playerID];
    if config == nil then return false; end
    local leaderType = config:GetLeaderTypeName();
    local seen = {};
    while leaderType ~= nil and not seen[leaderType] do
        if militaryLeaders[leaderType] then return true; end
        seen[leaderType] = true;
        local leader = GameInfo.Leaders[leaderType];
        leaderType = leader ~= nil and leader.InheritFrom or nil;
    end
    return false;
end

local function IsAtMajorWar(playerID, player)
    if not IsEligibleAI(player) then return false; end
    local diplomacy = player:GetDiplomacy();
    if diplomacy == nil then return false; end
    -- Read current diplomacy rather than the strategy's per-turn strength cache:
    -- a declaration or peace agreement can change the answer during the turn.
    for _, other in ipairs(PlayerManager.GetAliveMajors()) do
        local otherID = other:GetID();
        if otherID ~= playerID and diplomacy:IsAtWarWith(otherID) then return true; end
    end
    return false;
end

local function SyncCityMarker(playerID, city, index, label, eligible)
    if index == nil then return; end
    local buildings = city:GetBuildings();
    local present = buildings:HasBuilding(index);
    if present and (not eligible or buildings:IsPillaged(index)) then
        buildings:RemoveBuilding(index);
        city:GetBuildQueue():RemoveBuilding(index);
        present = false;
        print("Rose AI: Removed " .. label .. " choice marker player "
            .. playerID .. " city " .. city:GetID());
    end
    if eligible and not present then
        -- Ordinary district buildings use (building, percent), as
        -- in Firaxis's City tuner. Only placed buildings need a plot.
        city:GetBuildQueue():CreateIncompleteBuilding(index, 100);
        if buildings:HasBuilding(index) then
            print("Rose AI: Added " .. label .. " choice marker player "
                .. playerID .. " city " .. city:GetID());
        else
            print("Rose AI ERROR: " .. label .. " choice marker creation failed player "
                .. playerID .. " city " .. city:GetID());
        end
    end
end

local function SyncMarkers()
    -- Reconcile every owner so captured/traded markers cannot survive merely
    -- because their new owner is human, a city-state, or a nonmilitary AI.
    for playerID, player in pairs(Players) do
        local cities = player:GetCities();
        if cities ~= nil then
            local military = IsMilitaryAI(playerID, player);
            local atWar = IsAtMajorWar(playerID, player);
            for _, city in cities:Members() do
                SyncCityMarker(playerID, city, markerIndex, "military", military);
                SyncCityMarker(playerID, city, warMarkerIndex, "war", atWar);
            end
        end
    end
end

local syncing = false;
local function ReconcileMarkers()
    if (markerIndex == nil and warMarkerIndex == nil) or syncing then return; end
    syncing = true;
    local ok, err = pcall(SyncMarkers);
    -- A failed native call must not disable all future reconciliation hooks.
    syncing = false;
    if not ok then print("Rose AI ERROR: Choice marker reconciliation: " .. tostring(err)); end
end

-- These gameplay hooks are used by Firaxis scenario scripts. Reconciliation
-- also runs after loading, before AI choices on the next player's turn.
GameEvents.PlayerTurnStarted.Add(ReconcileMarkers);
GameEvents.PlayerTurnStartComplete.Add(ReconcileMarkers);
GameEvents.CityBuilt.Add(ReconcileMarkers);
GameEvents.CityConquered.Add(ReconcileMarkers);

-- These Events are used by Firaxis UI scripts. Listen when exposed here, but
-- retain turn hooks because availability in the gameplay context is unverified.
if Events ~= nil then
    if Events.CityTransfered ~= nil then Events.CityTransfered.Add(ReconcileMarkers); end
    if Events.DiplomacyDeclareWar ~= nil then Events.DiplomacyDeclareWar.Add(ReconcileMarkers); end
    if Events.DiplomacyMakePeace ~= nil then Events.DiplomacyMakePeace.Add(ReconcileMarkers); end
end

print("Rose AI: Military and war choice marker helper loaded");
