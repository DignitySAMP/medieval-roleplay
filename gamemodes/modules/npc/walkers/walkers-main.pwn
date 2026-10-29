#include <pp-hooks>

hook OnGameModeInit()
{
	Walkers_Setup();
    SetTimer("Walkers_TrafficTick",250,true);
	Command_Describe("walkers","Staff: how many villagers are out and the size of their path graph.");
	Help_Register(HELP_SECTION_ROLEPLAY,"Who are the people walking the roads?","~w~The people on the roads belong to the households of the realm and walk between their homes and their work.~n~~n~Walk up to someone and press Y when the talk prompt appears. They stop while you speak and carry on after goodbye.");
}
