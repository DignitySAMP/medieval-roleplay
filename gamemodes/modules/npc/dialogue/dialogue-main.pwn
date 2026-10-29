#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I use the talk panel?","~w~Walk up to a villager, press ~y~Y~w~ and pick ~y~Talk with him~w~ or ~y~Talk with her~w~. Choose a topic, then click the line you want to say. Use ~y~Next~w~ to see more questions.~n~~n~Villagers answer the choices in this panel. Press ~y~ESC~w~ or choose ~y~Goodbye~w~ to stop.");
	Help_Register(HELP_SECTION_ROLEPLAY,"What can I ask a villager?","~w~The conversation panel has ~y~Greeting~w~, ~y~Work~w~, ~y~Family~w~, ~y~Village~w~ and ~y~Their trade~w~. Ask for work or a meal through those rows. Household members also have questions about things they say at their table.",false);
	new whereHelp[HELP_ANSWER_LEN];
	format(whereHelp,sizeof(whereHelp),"~w~Ask someone who lives in the same village. Under ~y~Village~w~ there are questions like ~y~Where can I find the smith?~w~ for up to %d of the village trades. If the trade you want isn't there, ask someone else.~n~~n~They tell you where that person is now, until which bell, and where they usually go after that. The bell hour shows beside the date at the top of your screen.",DIALOGUE_WHERE_MAX);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I find a villager?",whereHelp,false);
	Command_Describe("dialogue","Staff: see whether the dialogue service answers, reload its settings, open it to everyone, read what they remember about you.");
	Dialogue_LoadConfig();
	SetTimer("Dialogue_Tick",DIALOGUE_TICK_MS,true);
}
