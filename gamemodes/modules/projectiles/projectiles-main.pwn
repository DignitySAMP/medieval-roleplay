#include <pp-hooks>

hook OnGameModeInit()
{
	new text[HELP_ANSWER_LEN];
	format(text,sizeof(text),"~w~Press ~y~Y~w~ to draw the crossbow. A slack crossbow has to be cranked before it can shoot. ~y~Left click~w~ to start cranking. It takes about %d seconds, and if someone hits you, you lose your grip and have to start again.~n~~n~When it's spanned, ~y~left click~w~ to lay a bolt on it. Then ~y~left click~w~ once more to shoot where the crosshair points. A bolt hits harder than an arrow and flies flatter, and every shot uses one bolt from your bag.",PROJECTILE_CRANK_MS / 1000);
	Help_Register(HELP_SECTION_COMBAT,"How do I use a crossbow?",text);
	Help_Register(HELP_SECTION_COMBAT,"How do I use a sling?","~w~Press ~y~Y~w~ to draw the sling. ~y~Left click~w~ to load a stone from your bag. Loading takes under a second. Then ~y~left click~w~ again to swing the sling and shoot where the crosshair points.~n~~n~A sling does less damage than a bow, but stones are cheap. You can gather them at a rock outcrop, and a stone that misses lies where it landed so you can pick it up again.");
	AnimPreload_Register("GRENADE");
	Log_Info("projectiles","range %.0fm, %d in flight at most",PROJECTILE_RANGE,MAX_PROJECTILES);
}
