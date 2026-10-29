#include <pp-hooks>

hook OnMigrationRun()
{
	Migration_Add("combat-1-hand-columns", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS hand_weapon SMALLINT NOT NULL DEFAULT -1, ADD COLUMN IF NOT EXISTS hand_shield SMALLINT NOT NULL DEFAULT -1");
}

hook OnGameModeInit()
{
    new answer[HELP_ANSWER_LEN];
    format(answer,sizeof(answer),"~w~Put your weapon or fists away with ~y~Y~w~, stand within %d metres of a downed player and press ~y~F~w~ to help them up. They regain some health. You can help someone who's down, but you can't revive a dead character.",floatround(COMBAT_REVIVE_RANGE));
    Help_Register(HELP_SECTION_COMBAT,"How do I help a fallen player?",answer,true);
    Help_Register(HELP_SECTION_COMBAT,"How do I block and dodge?","~w~In combat, hold ~y~right click~w~ to block. To dodge, release the mouse buttons and hold ~y~Sprint (Space)~w~ with ~y~back~w~ or a side. A sideways roll needs stamina and is unavailable with a shield unless you're using a great axe. Let your stamina recover between attacks.",false);
	Help_Register(HELP_SECTION_COMBAT,"How do I fight with a weapon?","~w~Press ~y~Y~w~ to draw your weapon and again to put it away.~n~~n~The direction you hold decides the swing. Hold ~y~forward~w~, ~y~back~w~, ~y~left~w~ or ~y~right~w~ and ~y~left click~w~ to swing that way. ~y~Right click~w~ blocks.");
	Help_Register(HELP_SECTION_COMBAT,"How do I fight with my fists?","~w~Your ~y~fists~w~ are always with you. With nothing in your hands, press ~y~Y~w~ to raise them. ~y~Left click~w~ to shove, hold ~y~forward~w~ and left click to punch, hold ~y~left or right~w~ to hook, and hold ~y~back~w~ for a kick. ~y~Right click~w~ blocks. Hold ~y~Sprint (Space)~w~ with back or a side to dodge.~n~~n~A ~y~kick~w~ knocks people down. Fists can knock someone out but never kill.");
	Character_RegisterBusyCheck("Combat_BusyCheck");
	Command_Describe("equip","Dev: equip any weapon by index.");
	Command_Describe("equipshield","Dev: equip any shield by index.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_ACTION,"Combat_KeyContext");
	Keys_RegisterContext(KEY_HANDBRAKE,KEYS_PRIO_ACTION,"Combat_KeyContext");
	Keys_RegisterContext(KEY_CTRL_BACK,KEYS_PRIO_ACTION,"Combat_KeyContext");
	AnimPreload_Register("SWORD");
	AnimPreload_Register("KNIFE");
	AnimPreload_Register("BASEBALL");
	AnimPreload_Register("DILDO");
	AnimPreload_Register("FIGHT_B");
	AnimPreload_Register("FIGHT_E");
	AnimPreload_Register("CRACK");
	AnimPreload_Register("CAMERA");
	Keys_RegisterContext(KEY_SECONDARY_ATTACK,KEYS_PRIO_ACTION,"Combat_KeyContext");
	Log_Info("combat","%d weapons, %d shields",WEAPON_COUNT,Shield_GetCount());
}
