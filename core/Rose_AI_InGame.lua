-- Rose AI InGame UI bridge for military strength, plus a print-only test log.
-- This getter is unavailable in the gameplay context.

print("Rose_AI_InGame: Rose AI: Loading InGame military-strength bridge");

if ExposedMembers.RoseAI == nil then ExposedMembers.RoseAI = {}; end
local RoseAI = ExposedMembers.RoseAI;

function RoseGetMilitaryStrength(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return nil; end
	local pStats = pPlayer:GetStats();
	if pStats == nil then return nil; end
	return pStats:GetMilitaryStrengthWithoutTreasury();
end

RoseAI.GetMilitaryStrength = RoseGetMilitaryStrength;

-- Test log for the early AI patronage block (AI_Units.sql): at each turn start,
-- print when an AI major's Gold/Faith patronage block changes. The query is
-- only available here, as in Firaxis's GreatPeoplePopup. Print-only, so it
-- cannot affect multiplayer synchronization.
local tPatronageBlock = {};
local function LogPatronageBlocks()
	local iGold = GameInfo.Yields["YIELD_GOLD"].Index;
	local iFaith = GameInfo.Yields["YIELD_FAITH"].Index;
	for _, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do
		if not pPlayer:IsHuman() then
			local pPoints = pPlayer:GetGreatPeoplePoints();
			if pPoints ~= nil then
				local iPlayerID = pPlayer:GetID();
				local sState = "gold " .. tostring(pPoints:IsNoPatronageWith(iGold))
					.. " faith " .. tostring(pPoints:IsNoPatronageWith(iFaith));
				if tPatronageBlock[iPlayerID] ~= sState then
					tPatronageBlock[iPlayerID] = sState;
					print("Rose_AI_InGame: Rose AI: Patronage blocked player " .. iPlayerID
						.. " turn " .. Game.GetCurrentGameTurn() .. " " .. sState);
				end
			end
		end
	end
end

Events.TurnBegin.Add(function()
	local bOk, sError = pcall(LogPatronageBlocks);
	if not bOk then print("Rose_AI_InGame: Rose AI ERROR: Patronage log: " .. tostring(sError)); end
end);

print("Rose_AI_InGame: Rose AI: InGame military-strength bridge loaded");
