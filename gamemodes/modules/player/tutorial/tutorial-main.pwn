#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_START,"Where do I start?","~w~From here on, nobody tells you what to do next. These help while you find your feet.~n~~n~Most ~y~village families~w~ feed a guest for free. Press ~y~Y~w~ on one of them before the noon or evening bell (Sext or Vespers) and ask to eat with them. Pick ~y~Ask if there's work~w~ for an ~y~errand~w~ that pays coin. For your first ~y~2 hours~w~ of playtime, errands pay double.~n~~n~~y~Bohuslav~w~, the trader at Talmberg market, buys what you gather. He also sells rope, parchment and a halter for a horse. For a pfennig he fills your water skin. The ~y~notice boards~w~ at the market and in the church village list paid work and news.");
	Command_Describe("tutskip","Dev: skip the tutorial.");
	TutorialIsland_Create();
	Timer_Start(Tutorial_BoonTick,TUTORIAL_BOON_TICK_MS);
}
