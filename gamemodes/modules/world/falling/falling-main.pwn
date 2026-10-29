#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("stuck","Falling through the map or caught in the scenery? Puts you back where you last stood on solid ground.");
	Command_Describe("falltest","Staff: drop under the map to test the fall rescue.");
	Log_Info("falling","under-map guard on ColAndreas rays");
}
