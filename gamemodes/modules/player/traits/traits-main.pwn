#include <pp-hooks>

hook OnGameModeInit()
{
	Log_Info("traits","%d trait effects in play",Traits_CountEffects());
	Help_Register(HELP_SECTION_START,"What do my traits do?","~w~Your two ~y~traits~w~ and your ~y~Willpower~w~ change how fast you get hungry, how the cold gets to you, and how you fight and work.~n~~n~Every one that does something is listed under your character (~y~Sprint + Walk~w~) > ~y~Buffs~w~, with what it does for you.");
}
