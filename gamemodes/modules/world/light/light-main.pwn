#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"How do I light my way at night?","~w~Carry a ~y~torch~w~ and click it in your bag to light it. It sits in your left hand and burns for about twenty minutes. You need a flame: ~y~flint~w~ in your bag, a fire close by, or someone else's torch.~n~~n~Click the lit torch in your bag to put it out or plant it in the ground. A torch you put out keeps what's left of it.");
	Help_Register(HELP_SECTION_SURVIVAL,"How does a lantern work?","~w~A ~y~lantern~w~ hangs from your belt and leaves your hands free. It burns a ~y~candle~w~: a tallow candle lasts half an hour, a wax candle an hour.~n~~n~Click the lantern in your bag to light it. Click a candle to put it in the lantern or to set it down lit.");
	Help_Register(HELP_SECTION_SURVIVAL,"How do I keep a brazier or bonfire going?","~w~Stand next to it and press ~y~Y~w~ to add fuel. A brazier takes ~y~charcoal~w~ (two hours) or ~y~firewood~w~ (one hour). A bonfire takes firewood, twenty minutes a log.~n~~n~A cold one needs a flame to get it going.",false);
	Command_Describe("light","Staff: place braziers and bonfires, fuel them, tune the torch grip, check the moon.");
	Light_InitFollows();
	Boot_RegisterLoader("Light_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Light_PromptContext");
	AnimPreload_Register("BOMBER");
	SetTimer("Light_Tick",LIGHT_TICK_MS,true);
	SetTimer("Light_PromptTick",LIGHT_PROMPT_MS,true);
	SetTimer("Light_MoonTick",LIGHT_MOON_MS,true);
}

hook Models_OnRegister()
{
	Models_AddObject(MODEL_LIGHT_GLOW_S,"light/glow_s.dff","light/light.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_LIGHT_GLOW_M,"light/glow_m.dff","light/light.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_LIGHT_GLOW_L,"light/glow_l.dff","light/light.txd",MAP_BASE_STATIC);
}

hook OnMigrationRun()
{
	Migration_Add("light-1-sources", "CREATE TABLE IF NOT EXISTS light_sources (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, fuel INT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
