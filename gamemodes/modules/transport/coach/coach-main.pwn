#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"How do I take the coach?","~w~By day a coach runs the road between Talmberg, the church village and the guardhouse, stopping a while at each. Stand by it and press ~y~Y~w~ to buy a seat: 2 pfennig a stop, plus the county's toll when the coach passes the toll bar; the coachman pays it for you there. You're set down where you asked. A coach or wagon of your own can have a hired coachman drive you to Talmberg, the church village, the guardhouse, the monastery road or the castle for 6 pfennig; you pay any toll on the way yourself. He keeps to the road, and once you have climbed down he takes the cart back to where it stood.",true);
	Keys_RegisterContext(KEY_YES,INFOBOX_TARGET_PRIORITY,"Coach_PromptContext");
    Infobox_RegisterTarget("Coach_TargetDistance","Coach_TargetRefresh","Coach_TargetClear",INFOBOX_TARGET_PRIORITY);
	SetTimer("Coach_Tick",COACH_TICK_MS,true);
	SetTimer("Coach_PromptTick",500,true);
	Boot_RegisterLoader("Coach_LoadOnBoot");
}

forward Coach_LoadOnBoot();

public Coach_LoadOnBoot()
{
	new started = Coach_Start();
	Log_Info("coach","public coach %s on %d points, %d stops",started ? ("running") : ("not started"),ROADS_COACH_POINTS,ROADS_COACH_STOPS);
	Boot_LoaderDone();
	return 1;
}
