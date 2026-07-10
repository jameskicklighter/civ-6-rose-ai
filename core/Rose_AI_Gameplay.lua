-- ============================================================================
-- Rose AI: Free Civics for AI Players
-- ============================================================================
-- 1. Government civics: When an AI player's prereqs for a government-unlocking
--    civic are met, grant it for free. Prevents AI from skipping government
--    upgrades because it beelined past side-branch civics.
--
-- 2. Tree-filling civics: When Guilds or Medieval Faires is completed, grant
--    Military Training, Theology, and their prereqs if missing. The AI often
--    ignores one or both edges of the early civic tree.
--
-- Grants cascade: granting one civic may satisfy another's prereqs.
-- ============================================================================

print("Rose AI: Loading Free Civics script");

-- ============================================================================
-- Government civics table: grant when all prereqs are met
-- ============================================================================
local tGovtCivics = {
	-- Tier 2
	{ civic = GameInfo.Civics["CIVIC_DIVINE_RIGHT"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_CIVIL_SERVICE"].Index,
	              GameInfo.Civics["CIVIC_THEOLOGY"].Index } },
	{ civic = GameInfo.Civics["CIVIC_EXPLORATION"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_MERCENARIES"].Index,
	              GameInfo.Civics["CIVIC_MEDIEVAL_FAIRES"].Index } },
	{ civic = GameInfo.Civics["CIVIC_REFORMED_CHURCH"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_GUILDS"].Index,
	              GameInfo.Civics["CIVIC_DIVINE_RIGHT"].Index } },
	-- Tier 3
	{ civic = GameInfo.Civics["CIVIC_SUFFRAGE"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_IDEOLOGY"].Index } },
	{ civic = GameInfo.Civics["CIVIC_TOTALITARIANISM"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_IDEOLOGY"].Index } },
	{ civic = GameInfo.Civics["CIVIC_CLASS_STRUGGLE"].Index,
	  prereqs = { GameInfo.Civics["CIVIC_IDEOLOGY"].Index } },
};

-- Tier 4 civics only exist with Gathering Storm
if GameInfo.Civics["CIVIC_CORPORATE_LIBERTARIANISM"] then
	table.insert(tGovtCivics, {
		civic = GameInfo.Civics["CIVIC_CORPORATE_LIBERTARIANISM"].Index,
		prereqs = { GameInfo.Civics["CIVIC_GLOBALIZATION"].Index,
		            GameInfo.Civics["CIVIC_SOCIAL_MEDIA"].Index } });
	table.insert(tGovtCivics, {
		civic = GameInfo.Civics["CIVIC_DIGITAL_DEMOCRACY"].Index,
		prereqs = { GameInfo.Civics["CIVIC_GLOBALIZATION"].Index,
		            GameInfo.Civics["CIVIC_SOCIAL_MEDIA"].Index } });
	table.insert(tGovtCivics, {
		civic = GameInfo.Civics["CIVIC_SYNTHETIC_TECHNOCRACY"].Index,
		prereqs = { GameInfo.Civics["CIVIC_GLOBALIZATION"].Index,
		            GameInfo.Civics["CIVIC_SOCIAL_MEDIA"].Index } });
end

-- ============================================================================
-- Tree-filling civics: grant when ANY trigger civic is completed.
-- Fills in skipped branches so the AI has Military Training and Theology
-- (and their prereqs) by the time it reaches Medieval era.
-- ============================================================================
local iGuilds         = GameInfo.Civics["CIVIC_GUILDS"].Index;
local iMedievalFaires = GameInfo.Civics["CIVIC_MEDIEVAL_FAIRES"].Index;

-- Civics to grant (in dependency order — prereqs first so cascade works)
local tTreeFillCivics = {
	GameInfo.Civics["CIVIC_MYSTICISM"].Index,
	GameInfo.Civics["CIVIC_DRAMA_POETRY"].Index,
	GameInfo.Civics["CIVIC_THEOLOGY"].Index,
	GameInfo.Civics["CIVIC_MILITARY_TRADITION"].Index,
	GameInfo.Civics["CIVIC_GAMES_RECREATION"].Index,
	GameInfo.Civics["CIVIC_MILITARY_TRAINING"].Index,
};

-- Check all government civics and grant any whose prereqs are fully met.
-- Runs in a loop to handle cascades (e.g. Divine Right → Reformed Church).
function GrantReadyGovtCivics(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not pPlayer:IsMajor() then return; end
	if pPlayer:IsHuman() then return; end

	local pCulture = pPlayer:GetCulture();
	local bGrantedAny = true;

	-- Keep looping until no new civics are granted (handles cascades)
	while bGrantedAny do
		bGrantedAny = false;
		for _, entry in ipairs(tGovtCivics) do
			if not pCulture:HasCivic(entry.civic) then
				local bAllMet = true;
				for _, iPrereq in ipairs(entry.prereqs) do
					if not pCulture:HasCivic(iPrereq) then
						bAllMet = false;
						break;
					end
				end
				if bAllMet then
					pCulture:SetCivic(entry.civic, true);
					bGrantedAny = true;
					print("Rose AI: Granted civic index " .. entry.civic .. " to AI player " .. iPlayerID);
				end
			end
		end
	end
end

-- Grant tree-filling civics if the AI has completed Guilds or Medieval Faires.
-- These are early-tree civics the AI may have skipped entirely.
function GrantTreeFillCivics(iPlayerID)
	local pPlayer = Players[iPlayerID];
	if pPlayer == nil then return; end
	if not pPlayer:IsMajor() then return; end
	if pPlayer:IsHuman() then return; end

	local pCulture = pPlayer:GetCulture();

	-- Only trigger once the AI has reached Guilds or Medieval Faires
	if not pCulture:HasCivic(iGuilds) and not pCulture:HasCivic(iMedievalFaires) then
		return;
	end

	for _, iCivic in ipairs(tTreeFillCivics) do
		if not pCulture:HasCivic(iCivic) then
			pCulture:SetCivic(iCivic, true);
			print("Rose AI: Tree-fill granted civic index " .. iCivic .. " to AI player " .. iPlayerID);
		end
	end
end

-- Hook: fires whenever any player completes a civic (gameplay event).
function OnCivicCompleted(iPlayerID, iCivicID)
	GrantReadyGovtCivics(iPlayerID);
	GrantTreeFillCivics(iPlayerID);
end

-- Hook: fires at the start of each player's turn as a safety net.
function OnPlayerTurnStarted(iPlayerID)
	GrantReadyGovtCivics(iPlayerID);
	GrantTreeFillCivics(iPlayerID);
end

GameEvents.OnCivicCulturevated.Add(OnCivicCompleted);
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);

print("Rose AI: Free Civics script loaded");
