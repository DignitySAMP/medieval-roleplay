#include <pp-hooks>

hook OnGameModeInit()
{
	SetTimer("Weather_SnowTick",WEATHER_SNOW_TICK_MS,true);
	SetTimer("Weather_MinuteTick",60000,true);
	Command_Describe("snow","Staff: start a short snowfall, stop it, or leave it to winter.");
}
