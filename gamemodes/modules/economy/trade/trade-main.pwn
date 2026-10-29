#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I trade with another player?","~w~Stand face to face with them and press ~y~Walk + Y~w~ (left Alt + Y). Once they agree, you both see your bag and what each of you gives.~n~~n~Click items in your bag to put them in and click them again to take them back. The coin buttons add pfennig. When you're both happy, you both press ~y~Accept~w~. Any change after that takes the accepts back, so nobody gets tricked at the last moment.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Trade_KeyContext");
	SetTimer("Trade_Tick",TRADE_TICK_MS,true);
}
