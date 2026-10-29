#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"Who rules here?","~w~The duke rules the duchy and the count rules the county within the duke's bounds: taxes, rents, fines, tolls, the light law and the rest. With no count, or one gone a week, the duke's steward holds the county. The steward at the castle shows the decrees and the county's policy; every change is posted on the notice boards.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"How are taxes collected?","~w~Rents, tolls and taxes pile up as dues in each village. A sworn guard collects them at the village's collection point and carries the coin to the steward at the castle. Coin on the road can be robbed.",false);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I get past the toll bar?","~w~The county keeps a toll bar in the hollow way, the sunken forest road south of Talmberg past the monastery. Stand by the bar and press ~y~Y~w~ to pay the toll keeper: the bar goes up and you have a minute to pass. Slipping round the bar or over it without paying is toll evasion. The keeper sees it and the guards are told. Guards and the county's rulers pass free, and coach passengers pay the toll with their fare.",true);
	Command_Describe("realm","Manager: fill the duke's, count's or regent's office, set a policy, add dues, see the county.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Realm_PromptContext");
	SetTimer("Realm_Tick",500,true);

	for (new toll = 0;toll < REALM_SEED_TOLLS;toll++)
	{
		Work_KeepSpotsClear(g_RealmTollDefs[toll][4],g_RealmTollDefs[toll][5],g_RealmTollDefs[toll][6],REALM_TOLL_CLEAR_SPOTS);
	}

	SetTimer("Realm_WatchTick",REALM_WATCH_MS,true);
	Boot_RegisterLoader("Realm_LoadSeatOnBoot");
}

forward Realm_LoadSeatOnBoot();

public Realm_LoadSeatOnBoot()
{
	new steward = Realm_PlaceSteward(), tolls = Realm_PlaceTolls();
	Log_Info("realm","steward %d, %d collection points, %d toll gates",steward,REALM_SEED_POINTS,tolls);
	Boot_LoaderDone();
	return 1;
}
