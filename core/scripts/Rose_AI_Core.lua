-- ============================================================================
-- Rose AI: shared core, included first by Rose_AI_Gameplay.lua.
-- The log switch, player and unit helpers, the pcall guard, the report-on-
-- change helper, the property codec (the stored form of every ROSE_* list or
-- record), the bridge relay store and the InGame bridge access, and the
-- operation read. No hooks and no game state beyond the relay records (only
-- print-once flags); everything is exported through RoseMod.
-- AGENTS.md "Rose_AI_Gameplay.lua".
-- ============================================================================

-- Per-turn diagnostic output; off for release. Errors, grants, strategy and
-- austerity changes and policy repairs always print.
local ROSE_VERBOSE_LOGS = true;

-- ============================================================================
-- Players and units
-- ============================================================================

local function IsEligibleAIPlayer(pPlayer)
	return pPlayer ~= nil
		and pPlayer:IsAlive()
		and pPlayer:IsMajor()
		and not pPlayer:IsHuman();
end

-- Alive majors, then alive minors.
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

-- The other alive majors pPlayer is at war with, in GetAliveMajors order.
local function GetMajorsAtWar(pPlayer)
	local tMajors = {};
	local iPlayerID = pPlayer:GetID();
	local pDiplomacy = pPlayer:GetDiplomacy();
	for _, pOther in ipairs(PlayerManager.GetAliveMajors()) do
		local iOtherID = pOther:GetID();
		if iOtherID ~= iPlayerID and pDiplomacy:IsAtWarWith(iOtherID) then
			table.insert(tMajors, pOther);
		end
	end
	return tMajors;
end

local function GetUnitInfo(pUnit)
	if pUnit == nil then return nil; end
	return GameInfo.Units[pUnit:GetType()];
end

-- The unit's current command (not its AI operation, which Lua cannot read);
-- "" when there is none. AGENTS.md "Known engine behaviour: gameplay-context Lua".
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

-- Whether the player's leader has any of tTraits (a list of TraitType strings),
-- following Leaders.InheritFrom as the engine's AI-list query does. Built once
-- from static data, so every machine gives the same answer.
local tTraitsByLeader = nil;
local function PlayerHasLeaderTrait(iPlayerID, tTraits)
	if tTraitsByLeader == nil then
		tTraitsByLeader = {};
		for row in GameInfo.LeaderTraits() do
			local tSet = tTraitsByLeader[row.LeaderType] or {};
			tSet[row.TraitType] = true;
			tTraitsByLeader[row.LeaderType] = tSet;
		end
	end
	local pConfig = PlayerConfigurations[iPlayerID];
	if pConfig == nil then return false; end
	local sLeaderType = pConfig:GetLeaderTypeName();
	local tSeen = {};
	while sLeaderType ~= nil and not tSeen[sLeaderType] do
		local tSet = tTraitsByLeader[sLeaderType];
		if tSet ~= nil then
			for _, sTrait in ipairs(tTraits) do
				if tSet[sTrait] then return true; end
			end
		end
		tSeen[sLeaderType] = true;
		local kLeader = GameInfo.Leaders[sLeaderType];
		sLeaderType = kLeader ~= nil and kLeader.InheritFrom or nil;
	end
	return false;
end

-- The player's era index (the base era strategies switch per player); the
-- world era if Player:GetEra is unavailable. Prints the source when it changes.
local sEraSource = nil;
local function GetPlayerEraIndex(pPlayer)
	local bOk, iEra = pcall(function() return pPlayer:GetEra(); end);
	local sSource = "player";
	if not bOk or type(iEra) ~= "number" then
		iEra = Game.GetEras():GetCurrentEra();
		sSource = "world";
	end
	if sEraSource ~= sSource then
		sEraSource = sSource;
		print("Rose AI: era windows read the " .. sSource .. " era");
	end
	return iEra;
end

-- ============================================================================
-- Error guard and change reports
-- ============================================================================

-- Calls fn(...) under pcall. On an error prints "Rose AI ERROR: <sWhat> failed
-- player <first argument>: <error>". Returns pcall's status and first result.
local function Guard(sWhat, fn, ...)
	local bOk, sError = pcall(fn, ...);
	if not bOk then
		print("Rose AI ERROR: " .. sWhat .. " failed player " .. tostring((...)) .. ": " .. tostring(sError));
	end
	return bOk, sError;
end

-- A function(iPlayerID, sReason) that prints "<sHead><player> turn <turn>:
-- <reason>" when that player's reason changes; nil clears it silently.
local function NewReasonReporter(sHead)
	local tReason = {};
	return function(iPlayerID, sReason)
		if tReason[iPlayerID] == sReason then return; end
		tReason[iPlayerID] = sReason;
		if sReason ~= nil then
			print(sHead .. iPlayerID .. " turn " .. Game.GetCurrentGameTurn() .. ": " .. sReason);
		end
	end;
end

-- ============================================================================
-- Property codec
--
-- A record joins its fields with "@"; a list joins its entries with ";",
-- sorted so every machine stores the same string. Each reader accepts exactly
-- the strings its pattern matches and skips the rest.
-- ============================================================================
local Codec = {};

-- Sorts the entries in place and joins them with ";".
local function JoinSorted(tParts)
	table.sort(tParts);
	return table.concat(tParts, ";");
end

-- "civic@count@turn" (ROSE_CIVIC_UNFREEZE, ROSE_CIVIC_STALL): its numeric
-- fields in order; a field that is not a number is left out.
function Codec.ReadNumbers(value)
	local tFields = {};
	if type(value) == "string" then
		for sField in string.gmatch(value, "[^@]+") do table.insert(tFields, tonumber(sField)); end
	end
	return tFields;
end

function Codec.Numbers(iCivic, iCount, iTurn)
	return iCivic .. "@" .. iCount .. "@" .. iTurn;
end

-- ROSE_POLICY_REPAIR_ATTEMPTS: "POLICY_X=attempts@lastTurn" entries, "!" once
-- the pause was printed; read as { [PolicyType] = { Attempts, LastTurn, Reported } }.
function Codec.ReadPolicyAttempts(value)
	local tAttempts = {};
	if type(value) == "string" then
		for sType, sCount, sLast, sFlag in string.gmatch(value, "([%w_]+)=(%d+)@(%-?%d+)(!?)") do
			tAttempts[sType] = { Attempts = tonumber(sCount), LastTurn = tonumber(sLast), Reported = sFlag == "!" };
		end
	end
	return tAttempts;
end

function Codec.PolicyAttempts(tAttempts)
	local tParts = {};
	for sType, kTry in pairs(tAttempts) do
		table.insert(tParts, sType .. "=" .. kTry.Attempts .. "@" .. kTry.LastTurn
			.. (kTry.Reported and "!" or ""));
	end
	return JoinSorted(tParts);
end

-- ROSE_NUCLEAR_WAR_SINCE: "enemyID=firstTurn" entries; read as { [enemyID] = firstTurn }.
function Codec.ReadWarSince(value)
	local tSince = {};
	if type(value) == "string" then
		for sID, sTurn in string.gmatch(value, "(%d+)=(%-?%d+)") do
			tSince[tonumber(sID)] = tonumber(sTurn);
		end
	end
	return tSince;
end

function Codec.WarSince(tSince)
	local tParts = {};
	for iOtherID, iTurn in pairs(tSince) do
		table.insert(tParts, iOtherID .. "=" .. iTurn);
	end
	return JoinSorted(tParts);
end

-- ROSE_NUCLEAR_STRIKE, the last order: "operation@turn@unit@targetOwner@x@y@flags";
-- flags l = launch seen, r = missing launch reported. nil when malformed.
function Codec.ReadNuclearStrike(value)
	if type(value) ~= "string" then return nil; end
	local sOp, sTurn, sUnit, sOwner, sX, sY, sFlags = string.match(value,
		"^(%-?%d+)@(%-?%d+)@(%-?%d+)@(%-?%d+)@(%-?%d+)@(%-?%d+)@(%a*)$");
	if sOp == nil then return nil; end
	return {
		Operation = tonumber(sOp), Turn = tonumber(sTurn), Unit = tonumber(sUnit),
		Owner = tonumber(sOwner), X = tonumber(sX), Y = tonumber(sY),
		Launched = string.find(sFlags, "l", 1, true) ~= nil,
		Reported = string.find(sFlags, "r", 1, true) ~= nil
	};
end

function Codec.NuclearStrike(kStrike)
	return kStrike.Operation .. "@" .. kStrike.Turn .. "@" .. kStrike.Unit
		.. "@" .. kStrike.Owner .. "@" .. kStrike.X .. "@" .. kStrike.Y .. "@"
		.. (kStrike.Launched and "l" or "") .. (kStrike.Reported and "r" or "");
end

-- ROSE_NUCLEAR_RECENT: "x@y@turn" entries; read as a list of { X, Y, Turn }.
function Codec.ReadRecentNukes(value)
	local tNukes = {};
	if type(value) == "string" then
		for sX, sY, sTurn in string.gmatch(value, "(%-?%d+)@(%-?%d+)@(%-?%d+)") do
			table.insert(tNukes, { X = tonumber(sX), Y = tonumber(sY), Turn = tonumber(sTurn) });
		end
	end
	return tNukes;
end

function Codec.RecentNukes(tNukes)
	local tParts = {};
	for _, kNuke in ipairs(tNukes) do
		table.insert(tParts, kNuke.X .. "@" .. kNuke.Y .. "@" .. kNuke.Turn);
	end
	return JoinSorted(tParts);
end

-- ROSE_DIRECTOR_ORDERS: "enemyID=turn@x@y@unitIDs" entries (comma-separated
-- ids), "enemyID=turn@x@y@e@endTurn" once ended; the older "@e@unitIDs" form
-- reads as ended at its order turn. Read as a list of { Enemy, Turn, X, Y, Ended, EndTurn, Units }.
function Codec.ReadDirectorOrders(value)
	local tOrders = {};
	if type(value) == "string" then
		for sEntry in string.gmatch(value, "[^;]+") do
			local sID, sTurn, sX, sY, sFlag, sUnits = string.match(sEntry, "^(%d+)=(%-?%d+)@(%-?%d+)@(%-?%d+)@?(%a*)@?([%d,]*)$");
			if sID ~= nil then
				local kOrder = { Enemy = tonumber(sID), Turn = tonumber(sTurn), X = tonumber(sX), Y = tonumber(sY),
					Ended = sFlag == "e", Units = {} };
				if kOrder.Ended then
					kOrder.EndTurn = tonumber(sUnits) or kOrder.Turn;
				else
					for sUnit in string.gmatch(sUnits, "%d+") do table.insert(kOrder.Units, tonumber(sUnit)); end
				end
				table.insert(tOrders, kOrder);
			end
		end
	end
	return tOrders;
end

function Codec.DirectorOrders(tOrders)
	local tParts = {};
	for _, kOrder in ipairs(tOrders) do
		local tUnits = {};
		for _, iUnit in ipairs(kOrder.Units or {}) do table.insert(tUnits, tostring(iUnit)); end
		table.insert(tParts, kOrder.Enemy .. "=" .. kOrder.Turn .. "@" .. kOrder.X .. "@" .. kOrder.Y
			.. (kOrder.Ended and ("@e@" .. kOrder.EndTurn) or ("@" .. table.concat(tUnits, ","))));
	end
	return JoinSorted(tParts);
end

-- The bridge relay message fields (Rose_AI_InGame.lua builds them): "id=value"
-- entries; read as { [id] = value string } for the values sPattern matches.
local RELAY_NUMBER_PATTERN = "^%-?%d+%.?%d*$";
local RELAY_DEAD_PATTERN = "^[%w_:,]*$";
function Codec.ReadRelayField(value, sPattern)
	local tValues = {};
	if type(value) == "string" then
		for sEntry in string.gmatch(value, "[^;]+") do
			local sID, sValue = string.match(sEntry, "^(%d+)=(.*)$");
			if sID ~= nil and string.match(sValue, sPattern) ~= nil then
				tValues[tonumber(sID)] = sValue;
			end
		end
	end
	return tValues;
end

-- ROSE_BRIDGE_RELAY, a player's latest relayed reading: "turn@strength@income@dead",
-- an empty strength or income when unreadable, dead "?" without a valid audit,
-- else "slot:POLICY:missing" entries joined by ",". Read as { Turn, Strength,
-- Income, Dead = { { Slot, PolicyType, Missing } } or nil }; nil when malformed.
function Codec.ReadBridgeRelay(value)
	if type(value) ~= "string" then return nil; end
	local sTurn, sStrength, sIncome, sDead = string.match(value, "^(%-?%d+)@([^@]*)@([^@]*)@([^@]*)$");
	if sTurn == nil then return nil; end
	local kRelay = { Turn = tonumber(sTurn), Strength = tonumber(sStrength), Income = tonumber(sIncome) };
	if sDead ~= "?" then
		kRelay.Dead = {};
		for sSlot, sType, sMissing in string.gmatch(sDead, "(%d+):([%w_]+):(%d+)") do
			table.insert(kRelay.Dead, { Slot = tonumber(sSlot), PolicyType = sType, Missing = tonumber(sMissing) });
		end
	end
	return kRelay;
end

-- The fields are the message's own strings, so every machine stores the same text.
function Codec.BridgeRelay(iTurn, sStrength, sIncome, sDead)
	return string.format("%d@%s@%s@%s", iTurn, sStrength or "", sIncome or "", sDead or "?");
end

-- The relay message's Check field: the byte lengths of Strength, Income and Dead.
function Codec.RelayCheck(sStrength, sIncome, sDead)
	local function Length(s) return type(s) == "string" and #s or 0; end
	return string.format("%d:%d:%d", Length(sStrength), Length(sIncome), Length(sDead));
end

-- ============================================================================
-- Engine and InGame bridge access
--
-- Strength, income and dead policy slots come from the bridge relay: the host's
-- InGame script reads them and sends them to every machine as one player
-- operation, and StoreBridgeRelay saves them as player properties, so every
-- machine decides from the same numbers. A machine's own bridge can differ
-- from the others' and is read directly only in a game with one machine, when
-- no fresh relay reading exists. AGENTS.md "Bridge relay".
-- ============================================================================

-- A function the InGame bridge (ExposedMembers.RoseAI, Rose_AI_InGame.lua)
-- exports, or nil before the bridge has loaded.
local function GetBridgeFunction(sName)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil then return nil; end
	return kBridge[sName];
end

local BRIDGE_RELAY = "ROSE_BRIDGE_RELAY";

-- Stores a RoseBridgeRelay message (sent by Rose_AI_InGame.lua): one
-- ROSE_BRIDGE_RELAY record per player it names. A record from a later turn is
-- kept; one from the same turn is replaced (a resend after a deck change). A
-- message from a future turn is ignored, so it cannot block the ones after it,
-- and one whose field lengths differ from its Check (cut short) is rejected.
local bRelayFirstPrinted = false;
local function StoreBridgeRelay(iSender, kParams)
	if type(kParams) ~= "table" then return; end
	local iTurn = tonumber(kParams.Turn);
	if iTurn == nil or iTurn ~= math.floor(iTurn) or iTurn > Game.GetCurrentGameTurn() then return; end
	local sCheck = Codec.RelayCheck(kParams.Strength, kParams.Income, kParams.Dead);
	if kParams.Check ~= sCheck then
		print("Rose AI: Bridge relay turn " .. iTurn .. " from player " .. tostring(iSender)
			.. " rejected: field lengths " .. sCheck .. ", sent " .. tostring(kParams.Check));
		return;
	end
	local tStrength = Codec.ReadRelayField(kParams.Strength, RELAY_NUMBER_PATTERN);
	local tIncome = Codec.ReadRelayField(kParams.Income, RELAY_NUMBER_PATTERN);
	local tDead = Codec.ReadRelayField(kParams.Dead, RELAY_DEAD_PATTERN);
	local tIDs = {};
	local tSeen = {};
	for _, tField in ipairs({ tStrength, tIncome, tDead }) do
		for iPlayerID in pairs(tField) do
			if not tSeen[iPlayerID] then
				tSeen[iPlayerID] = true;
				table.insert(tIDs, iPlayerID);
			end
		end
	end
	table.sort(tIDs);
	local iStored = 0;
	for _, iPlayerID in ipairs(tIDs) do
		local pPlayer = Players[iPlayerID];
		if pPlayer ~= nil then
			local kOld = Codec.ReadBridgeRelay(pPlayer:GetProperty(BRIDGE_RELAY));
			if kOld == nil or kOld.Turn <= iTurn then
				pPlayer:SetProperty(BRIDGE_RELAY,
					Codec.BridgeRelay(iTurn, tStrength[iPlayerID], tIncome[iPlayerID], tDead[iPlayerID]));
				iStored = iStored + 1;
			end
		end
	end
	if not bRelayFirstPrinted or ROSE_VERBOSE_LOGS then
		bRelayFirstPrinted = true;
		print("Rose AI: Bridge relay turn " .. iTurn .. " from player " .. tostring(iSender)
			.. " stored for " .. iStored .. " players");
	end
end

-- The player's relayed reading when it is from this turn or the last one, else
-- nil. Prints when a player's reading becomes missing or stale and when it is
-- fresh again, so a relay that stopped shows in the release log.
local tRelayFresh = {};
local function ReadFreshRelay(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return nil; end
	local kRelay = Codec.ReadBridgeRelay(pPlayer:GetProperty(BRIDGE_RELAY));
	local iTurn = Game.GetCurrentGameTurn();
	local bFresh = kRelay ~= nil and kRelay.Turn >= iTurn - 1 and kRelay.Turn <= iTurn;
	if tRelayFresh[iPlayerID] ~= bFresh then
		if not bFresh then
			print("Rose AI: Bridge relay reading for player " .. iPlayerID .. " missing or stale turn " .. iTurn
				.. " (record turn " .. tostring(kRelay ~= nil and kRelay.Turn or nil) .. ")");
		elseif tRelayFresh[iPlayerID] == false then
			print("Rose AI: Bridge relay reading for player " .. iPlayerID .. " fresh again turn " .. iTurn);
		end
		tRelayFresh[iPlayerID] = bFresh;
	end
	if not bFresh then return nil; end
	return kRelay;
end

-- Whether this is a network game, from the game configuration (the same on
-- every machine); nil while neither the gameplay API nor the bridge answers.
local bNetworkGame = nil;
local function IsNetworkGame()
	if bNetworkGame ~= nil then return bNetworkGame; end
	local sSource = "GameConfiguration";
	local bOk, bResult = pcall(function() return GameConfiguration.IsNetworkMultiplayer(); end);
	if not bOk or type(bResult) ~= "boolean" then
		sSource = "the InGame bridge";
		local fnNetwork = GetBridgeFunction("IsNetworkGame");
		if fnNetwork == nil then return nil; end
		bOk, bResult = pcall(fnNetwork);
		if not bOk or type(bResult) ~= "boolean" then return nil; end
	end
	bNetworkGame = bResult;
	print("Rose AI: Bridge relay mode network " .. tostring(bResult) .. " via " .. sSource);
	return bResult;
end

-- Whether a missing relay reading may be read from this machine's bridge:
-- only in a game known to have one machine. Printed once per kind.
local tFallbackPrinted = {};
local function MayReadLocalBridge(sKind, iPlayerID)
	if IsNetworkGame() ~= false then return false; end
	if not tFallbackPrinted[sKind] then
		tFallbackPrinted[sKind] = true;
		print("Rose AI: Bridge relay fallback: no fresh relayed " .. sKind .. " for player "
			.. iPlayerID .. " turn " .. Game.GetCurrentGameTurn() .. "; reading the local bridge (single machine)");
	end
	return true;
end

-- Dead policy slots of the player's latest valid audit, or nil.
local function GetDeadPolicySlots(iPlayerID)
	local kRelay = ReadFreshRelay(iPlayerID);
	if kRelay ~= nil and kRelay.Dead ~= nil then return kRelay.Dead; end
	if not MayReadLocalBridge("dead policy slots", iPlayerID) then return nil; end
	local fnDead = GetBridgeFunction("GetDeadPolicySlots");
	if fnDead == nil then return nil; end
	local bOk, tDead = pcall(fnDead, iPlayerID);
	if not bOk or type(tDead) ~= "table" then return nil; end
	return tDead;
end

-- Military strength and whether it was readable (UI-only in the engine).
local function GetMilitaryStrength(pPlayer)
	if pPlayer == nil then return 0, false; end
	local iPlayerID = pPlayer:GetID();
	local kRelay = ReadFreshRelay(iPlayerID);
	if kRelay ~= nil and kRelay.Strength ~= nil then return math.max(0, kRelay.Strength), true; end
	if not MayReadLocalBridge("strength", iPlayerID) then return 0, false; end
	local fnStrength = GetBridgeFunction("GetMilitaryStrength");
	if fnStrength == nil then
		return 0, false;
	end
	local iStrength = fnStrength(iPlayerID);
	if type(iStrength) ~= "number" then return 0, false; end
	return math.max(0, iStrength), true;
end

-- Gold per turn after maintenance, or nil when unreadable.
local function GetNetGoldIncome(iPlayerID)
	local kRelay = ReadFreshRelay(iPlayerID);
	if kRelay ~= nil and kRelay.Income ~= nil then return kRelay.Income; end
	if not MayReadLocalBridge("income", iPlayerID) then return nil; end
	local fnIncome = GetBridgeFunction("GetNetGoldIncome");
	if fnIncome == nil then return nil; end
	local iIncome = fnIncome(iPlayerID);
	if type(iIncome) ~= "number" or iIncome ~= iIncome then return nil; end
	return iIncome;
end

-- Envoys and suzerain; false for a minor that takes no envoys; nil when the
-- bridge cannot answer.
local function ReadEnvoys(iMinorID, iPlayerID)
	local fnEnvoys = GetBridgeFunction("GetEnvoyInfo");
	if fnEnvoys == nil then return nil; end
	local bOk, iEnvoys, iSuzerain = pcall(fnEnvoys, iMinorID, iPlayerID);
	if not bOk then return nil; end
	return iEnvoys, iSuzerain;
end

local function GetTraderBridgeDetails(iPlayerID, iUnitID, iX, iY)
	local fnDetails = GetBridgeFunction("GetTraderDiagnostics");
	if fnDetails == nil then return "bridge n/a"; end
	local bOk, sDetails = pcall(fnDetails, iPlayerID, iUnitID, iX, iY);
	if not bOk then return "bridge error " .. tostring(sDetails); end
	return tostring(sDetails);
end

-- Whether any live operation of ours (scripted ones included) targets
-- iEnemyID: true, false, or nil when unreadable. Slot -1 makes the call an
-- existence test; it cannot count. AGENTS.md "`HasOperationAgainst` Lua signature".
local bOperationReadWarned = false;
local function ReadOperationExists(pPlayer, iEnemyID)
	local pMilitaryAI = pPlayer:GetAi_Military();
	if pMilitaryAI == nil then return nil; end
	local bOk, bHas = pcall(function() return pMilitaryAI:HasOperationAgainst(iEnemyID, false, 0, -1); end);
	if not bOk then
		if not bOperationReadWarned then
			bOperationReadWarned = true;
			print("Rose AI ERROR: HasOperationAgainst failed; nuclear targets, the war director and the city-state report ignore our operations: " .. tostring(bHas));
		end
		return nil;
	end
	if bHas == true or bHas == false then return bHas; end
	return nil;
end

local function HasOperationAgainst(pPlayer, iEnemyID)
	return ReadOperationExists(pPlayer, iEnemyID) == true;
end

RoseMod.VerboseLogs = ROSE_VERBOSE_LOGS;
RoseMod.IsEligibleAIPlayer = IsEligibleAIPlayer;
RoseMod.GetAliveCityOwners = GetAliveCityOwners;
RoseMod.GetMajorsAtWar = GetMajorsAtWar;
RoseMod.GetUnitInfo = GetUnitInfo;
RoseMod.GetUnitOperationName = GetUnitOperationName;
RoseMod.IsUnitUncommitted = IsUnitUncommitted;
RoseMod.PlayerHasLeaderTrait = PlayerHasLeaderTrait;
RoseMod.GetPlayerEraIndex = GetPlayerEraIndex;
RoseMod.Guard = Guard;
RoseMod.NewReasonReporter = NewReasonReporter;
RoseMod.Codec = Codec;
RoseMod.StoreBridgeRelay = StoreBridgeRelay;
RoseMod.GetDeadPolicySlots = GetDeadPolicySlots;
RoseMod.GetMilitaryStrength = GetMilitaryStrength;
RoseMod.GetNetGoldIncome = GetNetGoldIncome;
RoseMod.ReadEnvoys = ReadEnvoys;
RoseMod.GetTraderBridgeDetails = GetTraderBridgeDetails;
RoseMod.ReadOperationExists = ReadOperationExists;
RoseMod.HasOperationAgainst = HasOperationAgainst;
