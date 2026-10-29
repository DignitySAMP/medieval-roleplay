#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("near","Staff: list the map objects nearest to you.");
	Command_Describe("cols","Staff: list the collision pieces around you.");
	Command_Describe("hide","Staff: hide collision pieces by id from /cols.");
	Command_Describe("ray","Staff: cast a ray down to check the ground.");
	Command_Describe("raydump","Staff: ray down at every probe in scriptfiles/mapq/probes.txt, for mapq.py parity.");
	Command_Describe("fw","Staff: nudge yourself forward.");
	Command_Describe("up","Staff: nudge yourself up.");
	Command_Describe("dn","Staff: nudge yourself down.");
	Command_Describe("walllog","Staff: log invisible walls you push into.");
	Command_Describe("flymode","Staff: fly the camera around the map.");
	Command_Describe("pos","Staff: print your position or the camera.");
	Command_Describe("mapzones","Staff: switch the drawn radar map on or off.");
	Streamer_VisibleItems(STREAMER_TYPE_OBJECT,MAP_VISIBLE_OBJECTS);
	CA_RemoveBuilding(-1,0.0,0.0,0.0,MAP_STRIP_RADIUS);
	CA_RemoveBuilding(-1,MAP_EDGE_STRIP_X,MAP_EDGE_STRIP_Y,MAP_EDGE_STRIP_Z,MAP_EDGE_STRIP_RADIUS);

	if (!CA_Init())
	{
		Log_Error("map","ColAndreas has no collision data, rays answer nothing");
	}

	Timer_Start(Map_WallCheck,MAP_WALL_CHECK_MS);
	Boot_RegisterLoader("Map_BuildRadarOnBoot");
}
