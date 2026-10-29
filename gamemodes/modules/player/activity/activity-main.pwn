#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_START,"What happens if I stop playing for a while?","~w~After ~y~five minutes~w~ without moving somewhere, working, talking or using a panel, your name shows ~y~(away)~w~. Nobody can hit or shoot you while you're away, and you earn no talent time. After ~y~fifteen minutes~w~ idle you're logged out, or ~y~thirty~w~ in your rented room or lying in a bed. Anything you do brings you back.",false);
	Help_Register(HELP_SECTION_START,"Does walking in circles keep me active?","~w~No. Moving counts when you get somewhere: ~y~ten metres~w~ in five minutes. Talking, working, fighting, praying and using menus count too.",false);
}
