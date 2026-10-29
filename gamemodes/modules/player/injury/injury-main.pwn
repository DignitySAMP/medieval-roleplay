#include <pp-hooks>

hook OnGameModeInit()
{
	Log_Info("injury","%d puddles, bleed %ds",INJURY_PUDDLES,INJURY_BLEED_SECONDS);
}
