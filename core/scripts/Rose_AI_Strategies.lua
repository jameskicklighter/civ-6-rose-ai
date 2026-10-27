-- ============================================================================
-- Rose AI: the war, austerity and era window strategy conditions and the
-- latches. Defines the five RoseActiveStrategy* globals and fills the
-- RoseForbidStrategy* callbacks; latches are written only from
-- PlayerTurnStarted, the era windows keep no state. State:
-- ROSE_MILITARY_RECOVERY_LATCH, ROSE_WAR_ADVANTAGE_LATCH, ROSE_AUSTERITY_LATCH,
-- ROSE_AUSTERITY_NEG_TURNS/_POS_TURNS/_TURN. AGENTS.md "Dynamic war-strategy
-- conditions", "Austerity latch", "Era window strategies".
-- ============================================================================

local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetMajorsAtWar = RoseMod.GetMajorsAtWar;
local Guard = RoseMod.Guard;
local GetMilitaryStrength = RoseMod.GetMilitaryStrength;
local GetNetGoldIncome = RoseMod.GetNetGoldIncome;
local tForbidStrategy = RoseMod.ForbidStrategy;
local PlayerHasLeaderTrait = RoseMod.PlayerHasLeaderTrait;
local GetPlayerEraIndex = RoseMod.GetPlayerEraIndex;

-- ============================================================================
-- Dynamic major-war strategy conditions. "Call Lua Function" conditions call
-- the matching GameEvents callback with (player ID, threshold). The war
-- context is read fresh each time: strengths are relayed player properties, and
-- a Lua-side cache would differ on a machine that rejoined mid-turn.
-- ============================================================================

local tWarStrategyState = {};

local function GetMajorWarContext(iPlayerID)
	local pPlayer = Players[iPlayerID];
	local iWars = 0;
	local iEnemyStrength = 0;
	local iOurStrength, bStrengthValid = GetMilitaryStrength(pPlayer);
	if IsEligibleAIPlayer(pPlayer) then
		for _, pOther in ipairs(GetMajorsAtWar(pPlayer)) do
			iWars = iWars + 1;
			local iOtherStrength, bOtherStrengthValid =
				GetMilitaryStrength(pOther);
			iEnemyStrength = iEnemyStrength + iOtherStrength;
			bStrengthValid = bStrengthValid and bOtherStrengthValid;
		end
	end

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

-- ============================================================================
-- Strength latches: each strength strategy enters at its threshold and releases
-- at a looser band (a released strategy cannot return for 20 turns); the bands
-- do not overlap, so Recovery and Advantage are never both active. The latch is
-- a saved player property written only from PlayerTurnStarted; an invalid
-- strength reading leaves it unchanged. The entry values match the SQL
-- ThresholdValue columns. AGENTS.md "STRATEGY_ROSE_MILITARY_RECOVERY".
-- ============================================================================
local RECOVERY_ENTER_PERCENT = 70;
local RECOVERY_RELEASE_PERCENT = 85;
local ADVANTAGE_ENTER_PERCENT = 125;
local ADVANTAGE_RELEASE_PERCENT = 110;
local RECOVERY_LATCH = "ROSE_MILITARY_RECOVERY_LATCH";
local ADVANTAGE_LATCH = "ROSE_WAR_ADVANTAGE_LATCH";

local function SetLatch(pPlayer, sProperty, bActive)
	local bWasActive = pPlayer:GetProperty(sProperty) == 1;
	if bActive ~= bWasActive then
		pPlayer:SetProperty(sProperty, bActive and 1 or 0);
	end
end

local function UpdateLatch(pPlayer, sProperty, bEnter, bHold)
	local bWasActive = pPlayer:GetProperty(sProperty) == 1;
	SetLatch(pPlayer, sProperty, bEnter or (bWasActive and bHold));
end

local function UpdateWarStrategyLatches(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not IsEligibleAIPlayer(pPlayer) then
		-- Clear any latch left from a period when this slot was an eligible AI.
		SetLatch(pPlayer, RECOVERY_LATCH, false);
		SetLatch(pPlayer, ADVANTAGE_LATCH, false);
		return;
	end
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	if iWars == 0 then
		SetLatch(pPlayer, RECOVERY_LATCH, false);
		SetLatch(pPlayer, ADVANTAGE_LATCH, false);
		return;
	end
	if not bStrengthValid then return; end
	if iEnemyStrength <= 0 then
		-- Opposing armies are gone: not weaker. Advantage keeps its state
		-- because a ratio cannot be computed.
		SetLatch(pPlayer, RECOVERY_LATCH, false);
		return;
	end
	local iOurScaled = iOurStrength * 100;
	UpdateLatch(pPlayer, RECOVERY_LATCH,
		iOurScaled < iEnemyStrength * RECOVERY_ENTER_PERCENT,
		iOurScaled < iEnemyStrength * RECOVERY_RELEASE_PERCENT);
	UpdateLatch(pPlayer, ADVANTAGE_LATCH,
		iOurScaled >= iEnemyStrength * ADVANTAGE_ENTER_PERCENT,
		iOurScaled >= iEnemyStrength * ADVANTAGE_RELEASE_PERCENT);
end

local function IsLatched(iPlayerID, sProperty)
	local pPlayer = Players[iPlayerID];
	return pPlayer ~= nil and pPlayer:GetProperty(sProperty) == 1;
end

function RoseActiveStrategyMilitaryRecovery(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0 and IsLatched(iPlayerID, RECOVERY_LATCH);
	LogWarStrategyChange(iPlayerID, "MILITARY_RECOVERY", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
end

function RoseActiveStrategyWarAdvantage(iPlayerID, iThreshold)
	local iWars, iOurStrength, iEnemyStrength, bStrengthValid =
		GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0 and IsLatched(iPlayerID, ADVANTAGE_LATCH);
	LogWarStrategyChange(iPlayerID, "WAR_ADVANTAGE", bActive,
		iWars, iOurStrength, iEnemyStrength, bStrengthValid);
	return bActive;
end

-- The SQL conditions are Forbidden rows, so these callbacks answer "block this
-- strategy now?". With no positive condition, a failed check would leave the
-- strategy allowed, so any error forbids instead, as does a missing Core.
local function ForbidUnlessActive(fnActive, iPlayerID, iThreshold)
	if Guard == nil then return true; end
	local bOk, bActive = Guard("Strategy check", fnActive, iPlayerID, iThreshold);
	if not bOk then return true; end
	return bActive ~= true;
end

-- Filled in only after everything above has loaded; see RegisterForbidCallback.
tForbidStrategy.RoseForbidStrategyAtWar = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyAtWar, iPlayerID, iThreshold);
end
tForbidStrategy.RoseForbidStrategyMilitaryRecovery = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyMilitaryRecovery, iPlayerID, iThreshold);
end
tForbidStrategy.RoseForbidStrategyWarAdvantage = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyWarAdvantage, iPlayerID, iThreshold);
end

-- ============================================================================
-- Austerity latch: a low Gold balance with negative income enables two
-- strategies that shift priorities toward income (never units, operations or
-- the treasury). Same layout as the strength latches; net income comes from the
-- InGame bridge, and an invalid reading changes nothing. The turn property
-- stops one game turn counting twice. AGENTS.md "Austerity latch".
-- ============================================================================
local AUSTERITY_ENTER_BALANCE = 30;      -- enter below this balance
local AUSTERITY_ENTER_NEG_TURNS = 2;     -- after this many negative-income turns
local AUSTERITY_RELEASE_BALANCE = 100;   -- release above this balance
local AUSTERITY_RELEASE_POS_TURNS = 3;   -- after this many positive-income turns
-- An AI that keeps spending its Gold may never bank 100; sustained positive
-- income alone also releases, so the latch cannot stay on for good.
local AUSTERITY_RELEASE_SUSTAINED_POS_TURNS = 10;
local AUSTERITY_LATCH = "ROSE_AUSTERITY_LATCH";
local AUSTERITY_NEG_TURNS = "ROSE_AUSTERITY_NEG_TURNS";
local AUSTERITY_POS_TURNS = "ROSE_AUSTERITY_POS_TURNS";
local AUSTERITY_TURN = "ROSE_AUSTERITY_TURN";

local function SetCounter(pPlayer, sProperty, iValue)
	local iOld = pPlayer:GetProperty(sProperty);
	if iOld ~= iValue and not (iOld == nil and iValue == 0) then
		pPlayer:SetProperty(sProperty, iValue);
	end
end

local function UpdateAusterityLatch(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not IsEligibleAIPlayer(pPlayer) then
		-- Clear any state left from a period when this slot was an eligible AI.
		SetLatch(pPlayer, AUSTERITY_LATCH, false);
		SetCounter(pPlayer, AUSTERITY_NEG_TURNS, 0);
		SetCounter(pPlayer, AUSTERITY_POS_TURNS, 0);
		return;
	end

	local iTurn = Game.GetCurrentGameTurn();
	if pPlayer:GetProperty(AUSTERITY_TURN) == iTurn then return; end

	local pTreasury = pPlayer:GetTreasury();
	local iBalance = pTreasury ~= nil and pTreasury:GetGoldBalance() or nil;
	local iIncome = GetNetGoldIncome(iPlayerID);
	if type(iBalance) ~= "number" or iIncome == nil then return; end

	local iNeg = iIncome < 0 and (pPlayer:GetProperty(AUSTERITY_NEG_TURNS) or 0) + 1 or 0;
	local iPos = iIncome > 0 and (pPlayer:GetProperty(AUSTERITY_POS_TURNS) or 0) + 1 or 0;
	pPlayer:SetProperty(AUSTERITY_TURN, iTurn);
	SetCounter(pPlayer, AUSTERITY_NEG_TURNS, iNeg);
	SetCounter(pPlayer, AUSTERITY_POS_TURNS, iPos);

	local bWasActive = pPlayer:GetProperty(AUSTERITY_LATCH) == 1;
	local bActive = bWasActive;
	if not bWasActive then
		bActive = iBalance < AUSTERITY_ENTER_BALANCE
			and iNeg >= AUSTERITY_ENTER_NEG_TURNS;
	else
		bActive = not ((iBalance > AUSTERITY_RELEASE_BALANCE
				and iPos >= AUSTERITY_RELEASE_POS_TURNS)
			or iPos >= AUSTERITY_RELEASE_SUSTAINED_POS_TURNS);
	end
	if bActive ~= bWasActive then
		SetLatch(pPlayer, AUSTERITY_LATCH, bActive);
		print("Rose AI: Austerity latch " .. (bActive and "entered" or "released")
			.. " player " .. iPlayerID
			.. " turn " .. iTurn
			.. " balance " .. math.floor(iBalance)
			.. " income " .. string.format("%.1f", iIncome)
			.. " negTurns " .. iNeg
			.. " posTurns " .. iPos);
	end
end

local tAusterityStrategyState = {};
local function LogAusterityStrategyChange(iPlayerID, sStrategy, bActive, iWars)
	local sKey = tostring(iPlayerID) .. ":" .. sStrategy;
	if tAusterityStrategyState[sKey] == bActive then return; end
	tAusterityStrategyState[sKey] = bActive;
	local pPlayer = Players[iPlayerID];
	print("Rose AI: Austerity strategy " .. sStrategy
		.. " player " .. iPlayerID
		.. " active " .. tostring(bActive)
		.. (iWars ~= nil and (" wars " .. iWars) or "")
		.. " latch " .. tostring(IsLatched(iPlayerID, AUSTERITY_LATCH))
		.. " negTurns " .. tostring(pPlayer ~= nil and pPlayer:GetProperty(AUSTERITY_NEG_TURNS) or nil)
		.. " posTurns " .. tostring(pPlayer ~= nil and pPlayer:GetProperty(AUSTERITY_POS_TURNS) or nil));
end

function RoseActiveStrategyAusterity(iPlayerID, iThreshold)
	local bActive = IsLatched(iPlayerID, AUSTERITY_LATCH);
	LogAusterityStrategyChange(iPlayerID, "AUSTERITY", bActive, nil);
	return bActive;
end

function RoseActiveStrategyAusterityAtWar(iPlayerID, iThreshold)
	local iWars = GetMajorWarContext(iPlayerID);
	local bActive = iWars > 0 and IsLatched(iPlayerID, AUSTERITY_LATCH);
	LogAusterityStrategyChange(iPlayerID, "AUSTERITY_AT_WAR", bActive, iWars);
	return bActive;
end

-- Filled in only after everything above has loaded; see RegisterForbidCallback.
tForbidStrategy.RoseForbidStrategyAusterity = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyAusterity, iPlayerID, iThreshold);
end
tForbidStrategy.RoseForbidStrategyAusterityAtWar = function(iPlayerID, iThreshold)
	return ForbidUnlessActive(RoseActiveStrategyAusterityAtWar, iPlayerID, iThreshold);
end

-- ============================================================================
-- Era windows: the base era strategies never end once adopted, so per-era
-- lists sit on these instead. Each is on while the player's era lies in its
-- range and, for a leader window, the leader has one of its traits. Trait and
-- era are synchronized game state, so every machine agrees. AGENTS.md "Era
-- window strategies", "Leader era window strategies".
-- ============================================================================
local tEraWindows = {
	{ sCallback = "AncientEra",     sFirst = "ERA_ANCIENT",     sLast = "ERA_ANCIENT" },
	{ sCallback = "ClassicalEra",   sFirst = "ERA_CLASSICAL",   sLast = "ERA_CLASSICAL" },
	{ sCallback = "MedievalEra",    sFirst = "ERA_MEDIEVAL",    sLast = "ERA_MEDIEVAL" },
	{ sCallback = "RenaissanceEra", sFirst = "ERA_RENAISSANCE", sLast = "ERA_RENAISSANCE" },
	{ sCallback = "ReligiousEarly", sFirst = "ERA_ANCIENT",     sLast = "ERA_CLASSICAL",
		tTraits = { "TRAIT_LEADER_RELIGIOUS_MAJOR_CIV" } },
	{ sCallback = "SaladinHolySite", sFirst = "ERA_CLASSICAL",  sLast = "ERA_MEDIEVAL",
		tTraits = { "TRAIT_LEADER_RIGHTEOUSNESS_OF_FAITH", "TRAIT_LEADER_SALADIN_ALT" } },
	{ sCallback = "AvoidHolySitesEarly", sFirst = "ERA_ANCIENT", sLast = "ERA_CLASSICAL",
		tTraits = { "TRAIT_LEADER_ROSE_AVOID_EARLY_HOLY_SITES" } },
};

local tEraWindowState = {};

local function GetEraIndex(sEra)
	local kEra = GameInfo.Eras[sEra];
	return kEra ~= nil and kEra.Index or nil;
end

local function IsEraWindowActive(iPlayerID, kWindow)
	local pPlayer = Players[iPlayerID];
	local bActive = false;
	local iEra = nil;
	if IsEligibleAIPlayer(pPlayer)
		and (kWindow.tTraits == nil or PlayerHasLeaderTrait(iPlayerID, kWindow.tTraits)) then
		iEra = GetPlayerEraIndex(pPlayer);
		local iFirst = GetEraIndex(kWindow.sFirst);
		local iLast = GetEraIndex(kWindow.sLast);
		bActive = iEra ~= nil and iFirst ~= nil and iLast ~= nil
			and iEra >= iFirst and iEra <= iLast;
	end
	local sKey = tostring(iPlayerID) .. ":" .. kWindow.sCallback;
	if (tEraWindowState[sKey] or false) ~= bActive then
		tEraWindowState[sKey] = bActive;
		print("Rose AI: Era window " .. kWindow.sCallback
			.. " player " .. iPlayerID
			.. " active " .. tostring(bActive)
			.. " era " .. tostring(iEra));
	end
	return bActive;
end

-- Filled in only after everything above has loaded; see RegisterForbidCallback.
for _, kWindow in ipairs(tEraWindows) do
	local function IsActive(iPlayerID, iThreshold)
		return IsEraWindowActive(iPlayerID, kWindow);
	end
	tForbidStrategy["RoseForbidStrategy" .. kWindow.sCallback] = function(iPlayerID, iThreshold)
		return ForbidUnlessActive(IsActive, iPlayerID, iThreshold);
	end
end

RoseMod.UpdateWarStrategyLatches = UpdateWarStrategyLatches;
RoseMod.UpdateAusterityLatch = UpdateAusterityLatch;
RoseMod.IsLatched = IsLatched;
RoseMod.RECOVERY_LATCH = RECOVERY_LATCH;
RoseMod.ADVANTAGE_LATCH = ADVANTAGE_LATCH;
