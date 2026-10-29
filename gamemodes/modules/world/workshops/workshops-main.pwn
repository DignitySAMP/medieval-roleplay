#include <pp-hooks>

hook Models_OnRegister()
{
	Workshops_Place();
}

hook OnGameModeInit()
{
	SetTimer("Workshops_Tick",WORKSHOPS_TICK_MS,true);
}
