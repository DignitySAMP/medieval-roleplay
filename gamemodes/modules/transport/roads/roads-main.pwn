#include <pp-hooks>

hook OnGameModeInit()
{
    Help_Register(HELP_SECTION_SURVIVAL,"How do I read a waystone?","~w~Each ~y~waystone~w~ board points along a road and names the place it leads to. Read either side of the board for the destination and distance.",false);
	Help_Register(HELP_SECTION_SURVIVAL,"Why does my horse go faster here?","~w~On the road a horse keeps a better pace than over fields and through woods. A cart behind it slows it down, a heavy load more, and off the road in rain or snow the wheels sink in the mud. ~y~Waystones~w~ at the crossroads point the way.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"What happens if bandits stop me?","~w~On the lonely roads at night, more in winter, bandits may bar your way and ask for part of your purse. Press ~y~Y~w~ to pay or refuse, or ride for it. Refuse and they fight: they beat you down and cut your purse, but they don't kill. The ~y~road wardens~w~ keep the main road; bandits won't strike near them.",true);
	Command_Describe("roads","Staff: are you on a road, is it muddy, your ride pace; /roads mud 1/0/-1 forces the mud; /roads bandits 1/-1 forces ambushes.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Bandits_KeyContext");
	SetTimer("Roads_Tick",ROADS_TICK_MS,true);
	SetTimer("Bandits_Tick",BANDITS_TICK_MS,true);
	Boot_RegisterLoader("Roads_LoadOnBoot");
}

forward Roads_LoadOnBoot();

public Roads_LoadOnBoot()
{
	new stones = Roads_PlaceWaystones(), cart = await Roads_EnsureCountyCart(), patrols = Roads_PlacePatrols();
	Log_Info("roads","%d waystones, %d road wardens, %d ambush stretches, county prisoner cart %d",stones,patrols,ROADS_SEED_AMBUSHES,cart);
	Boot_LoaderDone();
	return 1;
}
