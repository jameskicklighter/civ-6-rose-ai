-- ============================================================================
-- Rose AI: gameplay entry script. Registers the strategy condition callbacks,
-- includes the modules (ImportFiles, shared through the one global RoseMod)
-- and runs them from two hooks: PlayerTurnStarted (war and austerity latches,
-- civic research check, policy repair, civic grant) and PlayerTurnStartComplete
-- (nuclear strike, war director, verbose reports, naval superiority); the
-- Trader diagnostic runs at both. AGENTS.md "Rose_AI_Gameplay.lua".
-- ============================================================================

print("Rose AI: Loading gameplay support script");

-- Forbidden conditions only: an unanswered check would allow a strategy. These
-- callbacks forbid until Rose_AI_Strategies fills tForbidStrategy, so a load
-- error in or before that module keeps the strategies off.
local tForbidStrategy = {};
local function RegisterForbidCallback(sName)
	GameEvents[sName].Add(function(iPlayerID, iThreshold)
		local fnForbid = tForbidStrategy[sName];
		if fnForbid == nil then return true; end
		return fnForbid(iPlayerID, iThreshold);
	end);
end
RegisterForbidCallback("RoseForbidStrategyAtWar");
RegisterForbidCallback("RoseForbidStrategyMilitaryRecovery");
RegisterForbidCallback("RoseForbidStrategyWarAdvantage");
RegisterForbidCallback("RoseForbidStrategyAusterity");
RegisterForbidCallback("RoseForbidStrategyAusterityAtWar");

-- The one table the modules share; everything else stays local to its file.
-- Rose_AI_Strategies fills tForbidStrategy once its checks have loaded.
RoseMod = { ForbidStrategy = tForbidStrategy };
include("Rose_AI_Core");
include("Rose_AI_Civics");
include("Rose_AI_Strategies");
include("Rose_AI_Naval");
include("Rose_AI_Nuclear");
include("Rose_AI_Director");
include("Rose_AI_Diagnostics");

local ROSE_VERBOSE_LOGS = RoseMod.VerboseLogs; -- set in Rose_AI_Core
local Guard = RoseMod.Guard;
local UpdateWarStrategyLatches = RoseMod.UpdateWarStrategyLatches;
local UpdateAusterityLatch = RoseMod.UpdateAusterityLatch;
local GrantCivicOrRepairPolicies = RoseMod.GrantCivicOrRepairPolicies;
local RunTraderDiagnostic = RoseMod.RunTraderDiagnostic;
local TryNuclearStrike = RoseMod.TryNuclearStrike;
local TryWarDirector = RoseMod.TryWarDirector;
local UpdateCityStateOperations = RoseMod.UpdateCityStateOperations;
local UpdateOperationProbe = RoseMod.UpdateOperationProbe;
local TryStartNavalSuperiority = RoseMod.TryStartNavalSuperiority;

-- Update latches, then grant at most one ready civic or repair dead policy
-- cards.
function OnPlayerTurnStarted(iPlayerID)
	Guard("War strategy latch update", UpdateWarStrategyLatches, iPlayerID);
	Guard("Austerity latch update", UpdateAusterityLatch, iPlayerID);
	Guard("Civic grant or policy repair", GrantCivicOrRepairPolicies, iPlayerID);
	RunTraderDiagnostic(iPlayerID, "PlayerTurnStarted");
end

-- Firaxis' Nubia scenario starts scripted military operations from this hook.
-- Starting them inside PlayerTurnStarted can re-enter native AI initialization.
function OnPlayerTurnStartComplete(iPlayerID)
	RunTraderDiagnostic(iPlayerID, "PlayerTurnStartComplete");
	Guard("Nuclear strike", TryNuclearStrike, iPlayerID);
	Guard("War director", TryWarDirector, iPlayerID);
	if ROSE_VERBOSE_LOGS then
		Guard("City-state operation report", UpdateCityStateOperations, iPlayerID);
		Guard("Operation probe", UpdateOperationProbe, iPlayerID);
	end
	TryStartNavalSuperiority(iPlayerID);
end

GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);
GameEvents.PlayerTurnStartComplete.Add(OnPlayerTurnStartComplete);

print("Rose AI: Gameplay support script loaded");
