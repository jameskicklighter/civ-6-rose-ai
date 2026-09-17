-- Rose AI InGame UI bridge for military strength and current government.
-- These getters are unavailable in the gameplay context.

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

function RoseGetCurrentGovernment(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return nil; end
	local pCulture = pPlayer:GetCulture();
	if pCulture == nil or pCulture.GetCurrentGovernment == nil then return nil; end
	return pCulture:GetCurrentGovernment();
end

RoseAI.GetCurrentGovernment = RoseGetCurrentGovernment;

print("Rose_AI_InGame: Rose AI: InGame military-strength bridge loaded");
