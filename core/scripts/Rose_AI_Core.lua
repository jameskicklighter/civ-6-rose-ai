-- ============================================================================
-- Rose AI: shared core, included first by Rose_AI_Gameplay.lua.
-- The log switch, player and unit helpers, the pcall guard, the report-on-
-- change helper, the property codec (the stored form of every ROSE_* list or
-- record), the InGame bridge access and the operation read. No hooks and no
-- state of its own; everything is exported through RoseMod.
-- AGENTS.md "Rose_AI_Gameplay.lua".
-- ============================================================================

-- Per-turn diagnostic output; off for release. Errors, grants, strategy and
-- austerity changes and policy repairs always print.
local ROSE_VERBOSE_LOGS = false;

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

-- ============================================================================
-- Engine and InGame bridge access
-- ============================================================================

-- A function the InGame bridge (ExposedMembers.RoseAI, Rose_AI_InGame.lua)
-- exports, or nil before the bridge has loaded.
local function GetBridgeFunction(sName)
	local kBridge = ExposedMembers.RoseAI;
	if kBridge == nil then return nil; end
	return kBridge[sName];
end

-- The InGame audit's dead policy slots for the player, or nil.
local function GetDeadPolicySlots(iPlayerID)
	local fnDead = GetBridgeFunction("GetDeadPolicySlots");
	if fnDead == nil then return nil; end
	local bOk, tDead = pcall(fnDead, iPlayerID);
	if not bOk or type(tDead) ~= "table" then return nil; end
	return tDead;
end

-- Military strength and whether it was readable (UI-only in the engine).
local function GetMilitaryStrength(pPlayer)
	if pPlayer == nil then return 0, false; end
	local fnStrength = GetBridgeFunction("GetMilitaryStrength");
	if fnStrength == nil then
		return 0, false;
	end
	local iStrength = fnStrength(pPlayer:GetID());
	if type(iStrength) ~= "number" then return 0, false; end
	return math.max(0, iStrength), true;
end

-- Gold per turn after maintenance, or nil when unreadable.
local function GetNetGoldIncome(iPlayerID)
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
RoseMod.Guard = Guard;
RoseMod.NewReasonReporter = NewReasonReporter;
RoseMod.Codec = Codec;
RoseMod.GetDeadPolicySlots = GetDeadPolicySlots;
RoseMod.GetMilitaryStrength = GetMilitaryStrength;
RoseMod.GetNetGoldIncome = GetNetGoldIncome;
RoseMod.ReadEnvoys = ReadEnvoys;
RoseMod.GetTraderBridgeDetails = GetTraderBridgeDetails;
RoseMod.ReadOperationExists = ReadOperationExists;
RoseMod.HasOperationAgainst = HasOperationAgainst;
