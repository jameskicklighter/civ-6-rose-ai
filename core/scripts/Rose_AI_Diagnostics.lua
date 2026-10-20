-- ============================================================================
-- Rose AI: print-only diagnostics, silent unless ROSE_VERBOSE_LOGS. From
-- PlayerTurnStartComplete: the city-state operation report and the operation
-- read probe; at both turn hooks: the stuck Trader lines. They change nothing
-- and keep no saved state (lines repeat after a reload). AGENTS.md
-- "City-state operation report", "Operation read probe", "Stuck Trader diagnostic".
-- ============================================================================

local ROSE_VERBOSE_LOGS = RoseMod.VerboseLogs; -- set in Rose_AI_Core
local IsEligibleAIPlayer = RoseMod.IsEligibleAIPlayer;
local GetUnitOperationName = RoseMod.GetUnitOperationName;
local HasOperationAgainst = RoseMod.HasOperationAgainst;
local ReadEnvoys = RoseMod.ReadEnvoys;
local GetTraderBridgeDetails = RoseMod.GetTraderBridgeDetails;
local ReadDirectorOrders = RoseMod.ReadDirectorOrders;
local Guard = RoseMod.Guard;

-- ============================================================================
-- Operations against city-states: a line when an operation of ours against a
-- city-state appears or its envoys (ours), suzerain or war state change, and
-- one when it is gone; "at war no" marks a siege waiting for a declaration.
-- ============================================================================
local tCityStateOperations = {};

local function DescribeCapital(pPlayer)
	local pCity = pPlayer:GetCities():GetCapitalCity();
	if pCity == nil then return "none"; end
	return pCity:GetX() .. "," .. pCity:GetY();
end

local function UpdateCityStateOperations(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then
		tCityStateOperations[iPlayerID] = nil;
		return;
	end
	local iTurn = Game.GetCurrentGameTurn();
	local tOld = tCityStateOperations[iPlayerID] or {};
	local tNow = {};
	local pDiplomacy = pPlayer:GetDiplomacy();
	for _, pMinor in ipairs(PlayerManager.GetAliveMinors()) do
		local iMinorID = pMinor:GetID();
		if HasOperationAgainst(pPlayer, iMinorID) then
			local iEnvoys, iSuzerain = ReadEnvoys(iMinorID, iPlayerID);
			if iEnvoys ~= false then
				local sState = "envoys " .. tostring(iEnvoys or "?")
					.. " suzerain " .. tostring(iSuzerain or "?")
					.. " at war " .. (pDiplomacy:IsAtWarWith(iMinorID) and "yes" or "no");
				local kOld = tOld[iMinorID];
				local kNow = { State = sState, Since = (kOld ~= nil) and kOld.Since or iTurn };
				tNow[iMinorID] = kNow;
				if kOld == nil or kOld.State ~= sState then
					print("Rose AI: Operation against city-state for player " .. iPlayerID
						.. " turn " .. iTurn
						.. ": city-state " .. iMinorID
						.. " capital " .. DescribeCapital(pMinor)
						.. " " .. sState
						.. " since turn " .. kNow.Since);
				end
			end
		end
	end
	for iMinorID, kOld in pairs(tOld) do
		if tNow[iMinorID] == nil then
			print("Rose AI: Operation against city-state ended for player " .. iPlayerID
				.. " turn " .. iTurn
				.. ": city-state " .. iMinorID
				.. " since turn " .. kOld.Since);
		end
	end
	tCityStateOperations[iPlayerID] = tNow;
end

-- ============================================================================
-- Operation read probe: for every other major and city-state, the existence
-- (false, 0, -1) and ready (true, 0, -1) forms of HasOperationAgainst, printed
-- when either changes with the two-argument (rally) answer, the war state and
-- our director orders; a failed read keeps the last state. AGENTS.md
-- "`HasOperationAgainst` Lua signature".
-- ============================================================================
local tOperationProbe = {};
local bOperationProbeWarned = false;

-- "yes", "no", "?" when the call fails, otherwise the value returned. A nil
-- slot makes the two-argument call.
local function ReadOperationProbe(pMilitaryAI, iOtherID, bReady, iSlot)
	local bOk, value = pcall(function()
		if iSlot == nil then return pMilitaryAI:HasOperationAgainst(iOtherID, bReady); end
		return pMilitaryAI:HasOperationAgainst(iOtherID, bReady, 0, iSlot);
	end);
	if not bOk then
		if not bOperationProbeWarned then
			bOperationProbeWarned = true;
			print("Rose AI ERROR: Operation probe read failed: " .. tostring(value));
		end
		return "?";
	end
	if value == true then return "yes"; end
	if value == false then return "no"; end
	return tostring(value);
end

local function UpdateOperationProbe(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then
		tOperationProbe[iPlayerID] = nil;
		return;
	end
	local pMilitaryAI = pPlayer:GetAi_Military();
	if pMilitaryAI == nil then return; end
	local iTurn = Game.GetCurrentGameTurn();
	local pDiplomacy = pPlayer:GetDiplomacy();
	local tOrderTurns = {};
	for _, kOrder in ipairs(ReadDirectorOrders(pPlayer)) do
		tOrderTurns[kOrder.Enemy] = tOrderTurns[kOrder.Enemy] or {};
		table.insert(tOrderTurns[kOrder.Enemy], kOrder.Turn);
	end
	local tOthers = {};
	for _, pOther in ipairs(PlayerManager.GetAliveMajors()) do
		if pOther:GetID() ~= iPlayerID then table.insert(tOthers, { ID = pOther:GetID(), Kind = "major" }); end
	end
	for _, pOther in ipairs(PlayerManager.GetAliveMinors()) do
		table.insert(tOthers, { ID = pOther:GetID(), Kind = "city-state" });
	end
	local tOld = tOperationProbe[iPlayerID] or {};
	local tNow = {};
	for _, kOther in ipairs(tOthers) do
		local iOtherID = kOther.ID;
		local sOld = tOld[iOtherID] or "exists no ready no";
		local sExists = ReadOperationProbe(pMilitaryAI, iOtherID, false, -1);
		local sReady = ReadOperationProbe(pMilitaryAI, iOtherID, true, -1);
		if sExists == "?" or sReady == "?" then
			tNow[iOtherID] = tOld[iOtherID];
		else
			local sState = "exists " .. sExists .. " ready " .. sReady;
			tNow[iOtherID] = sState;
			if sState ~= sOld then
				local tTurns = tOrderTurns[iOtherID];
				if tTurns ~= nil then table.sort(tTurns); end
				print("Rose AI: Operation probe for player " .. iPlayerID
					.. " turn " .. iTurn
					.. " against " .. kOther.Kind .. " " .. iOtherID
					.. ": " .. sState .. " (was " .. sOld .. ")"
					.. " rally " .. ReadOperationProbe(pMilitaryAI, iOtherID, false, nil)
					.. " at war " .. (pDiplomacy:IsAtWarWith(iOtherID) and "yes" or "no")
					.. " director orders " .. (tTurns ~= nil and ("turn " .. table.concat(tTurns, ",")) or "none"));
			end
		end
	end
	tOperationProbe[iPlayerID] = tNow;
end

-- ============================================================================
-- Stuck Trader diagnostic: an AI Trader on one plot for TRADER_STREAK_REPORT
-- consecutive turn starts gets a line per hook call (moves, city, InGame route
-- details), and one when the streak ends. AGENTS.md "Known engine behaviour: AI trade routes".
-- ============================================================================
local TRADER_STREAK_REPORT = 3;
local tTraderUnitTypes = {};
for kUnit in GameInfo.Units() do
	if kUnit.MakeTradeRoute == true or kUnit.MakeTradeRoute == 1 then
		tTraderUnitTypes[kUnit.Index] = true;
	end
end
local tTraderStreaks = {};

local function DescribePlotCity(iX, iY)
	local pCity = CityManager.GetCityAt(iX, iY);
	if pCity == nil then return "none"; end
	return tostring(pCity:GetOwner()) .. "/" .. tostring(pCity:GetID())
		.. "/" .. tostring(pCity:GetName());
end

local function LogTraderStreak(iPlayerID, iTurn, sHook, pUnit, kStreak)
	local iX, iY = pUnit:GetX(), pUnit:GetY();
	print("Rose AI: Trader stuck player " .. iPlayerID
		.. " turn " .. iTurn
		.. " hook " .. sHook
		.. " unit " .. pUnit:GetID()
		.. " plot " .. iX .. "," .. iY
		.. " city " .. DescribePlotCity(iX, iY)
		.. " moves " .. tostring(pUnit:GetMovesRemaining())
		.. "/" .. tostring(pUnit:GetMaxMoves())
		.. " streak " .. kStreak.Streak
		.. " operation " .. GetUnitOperationName(pUnit)
		.. " " .. GetTraderBridgeDetails(iPlayerID, pUnit:GetID(), iX, iY));
end

local function LogTraderStreakEnd(iPlayerID, iTurn, sHook, iUnitID, kStreak, sReason)
	print("Rose AI: Trader streak ended player " .. iPlayerID
		.. " turn " .. iTurn
		.. " hook " .. sHook
		.. " unit " .. iUnitID
		.. " plot " .. kStreak.X .. "," .. kStreak.Y
		.. " streak " .. kStreak.Streak
		.. " reason " .. sReason);
end

local function UpdateTraderStreaks(iPlayerID, sHook)
	local pPlayer = Players[iPlayerID];
	if not IsEligibleAIPlayer(pPlayer) then
		tTraderStreaks[iPlayerID] = nil;
		return;
	end
	local iTurn = Game.GetCurrentGameTurn();
	local tStreaks = tTraderStreaks[iPlayerID];
	if tStreaks == nil then
		tStreaks = {};
		tTraderStreaks[iPlayerID] = tStreaks;
	end

	local tSeen = {};
	for _, pUnit in pPlayer:GetUnits():Members() do
		if tTraderUnitTypes[pUnit:GetType()] == true then
			local iUnitID = pUnit:GetID();
			local iX, iY = pUnit:GetX(), pUnit:GetY();
			tSeen[iUnitID] = true;
			local kStreak = tStreaks[iUnitID];
			if kStreak ~= nil and (kStreak.X ~= iX or kStreak.Y ~= iY) then
				if kStreak.Streak >= TRADER_STREAK_REPORT then
					LogTraderStreakEnd(iPlayerID, iTurn, sHook, iUnitID, kStreak, "moved");
				end
				kStreak = nil;
			end
			if kStreak == nil then
				kStreak = { X = iX, Y = iY, Streak = 1, Turn = iTurn, Printed = {} };
				tStreaks[iUnitID] = kStreak;
			elseif kStreak.Turn ~= iTurn then
				-- Count each game turn once, however many hooks fire in it.
				kStreak.Streak = kStreak.Streak + 1;
				kStreak.Turn = iTurn;
			end
			if kStreak.Streak >= TRADER_STREAK_REPORT and kStreak.Printed[sHook] ~= iTurn then
				kStreak.Printed[sHook] = iTurn;
				LogTraderStreak(iPlayerID, iTurn, sHook, pUnit, kStreak);
			end
		end
	end
	for iUnitID, kStreak in pairs(tStreaks) do
		if not tSeen[iUnitID] then
			if kStreak.Streak >= TRADER_STREAK_REPORT then
				LogTraderStreakEnd(iPlayerID, iTurn, sHook, iUnitID, kStreak, "gone");
			end
			tStreaks[iUnitID] = nil;
		end
	end
end

local function RunTraderDiagnostic(iPlayerID, sHook)
	if not ROSE_VERBOSE_LOGS then return; end
	Guard("Trader diagnostic", UpdateTraderStreaks, iPlayerID, sHook);
end

RoseMod.RunTraderDiagnostic = RunTraderDiagnostic;
RoseMod.UpdateCityStateOperations = UpdateCityStateOperations;
RoseMod.UpdateOperationProbe = UpdateOperationProbe;
