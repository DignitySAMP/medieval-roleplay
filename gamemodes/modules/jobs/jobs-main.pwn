#include <pp-hooks>

hook OnGameModeInit()
{
	Recipe_RegisterSceneAnims();
	Log_Info("jobs","%d trade(s), %d occupation(s), %d recipe(s)",TRADE_COUNT,OCCUPATION_COUNT,Recipe_GetCount());
}
