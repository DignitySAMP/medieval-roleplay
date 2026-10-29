#include <pp-hooks>

hook OnGameModeInit()
{
	SetTimer("Buff_HudTick",BUFF_HUD_TICK_MS,true);
}
