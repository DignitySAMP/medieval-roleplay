#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"Where can I wash?","~w~At the ~y~washing troughs~w~ by the Talmberg market, the church village and the guardhouse: stand by one and press ~y~Y~w~. Each wash draws the water down and the trough fills again over the hours. You can also wash in a river, though it won't get you as clean.",false);
	Help_Register(HELP_SECTION_SURVIVAL,"Where can I get drinking water?","~w~Stand by a well, such as the Talmberg well or the church village well, and press ~y~Y~w~. If your water skin is partly empty it is filled again, otherwise you drink from the well. Wells never freeze or run dry. The monastery spring and the market traders also give water.",false);
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Yard_PromptContext");
	SetTimer("Yard_PromptTick",YARD_PROMPT_MS,true);
	Yard_Place();
}
