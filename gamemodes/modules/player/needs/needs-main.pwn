#include <pp-hooks>

hook OnGameModeInit()
{
    Help_Register(HELP_SECTION_SURVIVAL,"What do the survival bars mean?","~w~The bars in the bottom right show ~y~Health~w~, ~y~Stamina~w~, ~y~Hunger~w~, ~y~Thirst~w~ and ~y~Warmth~w~. Eat and drink from your bag (~y~N~w~) before Hunger or Thirst empties. Empty food and drink bars cost health. Wear warm clothes or stand near a fire when Warmth falls. Stamina recovers when you're resting between actions.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"How do I stay fed and warm?","~w~You need ~y~food~w~, ~y~drink~w~ and ~y~warmth~w~. The ~y~bars in the bottom right~w~ show how you're doing. Winter nights are cold. Wear warm clothes or stay near a fire.~n~~n~During your first hour of playtime, ~y~newcomer's warmth~w~ keeps the cold off. The ~y~bar next to the map~w~ shows how long it has left.");
	Help_Register(HELP_SECTION_SURVIVAL,"How do I eat?","~w~Raw fish has to be cooked before you can eat it. ~y~Cooked food~w~ fills you up the most.~n~~n~Eat from your ~y~bag (N)~w~ when your ~y~food bar~w~ gets low. If it empties, you lose health.");
	Character_RegisterBusyCheck("Needs_BusyCheck");
	AnimPreload_Register("FOOD");
	AnimPreload_Register("VENDING");
}

hook OnMigrationRun()
{
	Migration_Add("needs-1-columns", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS hunger INT NOT NULL DEFAULT 100000, ADD COLUMN IF NOT EXISTS thirst INT NOT NULL DEFAULT 100000");
}
