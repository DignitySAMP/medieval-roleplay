#include <pp-hooks>

hook OnGameModeInit()
{
	Timer_Start(Vitals_Tick,VITALS_TICK_MS);
}
