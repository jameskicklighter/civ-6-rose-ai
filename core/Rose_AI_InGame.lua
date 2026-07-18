-- Rose AI InGame UI bridge.
-- GetMilitaryStrengthWithoutTreasury is exposed only in the InGame UI
-- context. Publish the value through ExposedMembers so the gameplay strategy
-- callbacks can compare the armies of major civilizations at war.

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

print("Rose_AI_InGame: Rose AI: InGame military-strength bridge loaded");
