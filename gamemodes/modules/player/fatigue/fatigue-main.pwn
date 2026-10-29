#include <pp-hooks>

hook OnGameModeInit()
{
    new answer[HELP_ANSWER_LEN];
    format(answer,sizeof(answer),"~w~Press ~y~Walk + N (left Alt + N)~w~, choose ~y~Lie down~w~ and click ~y~Sleep~w~. Stay still for %d seconds to sleep on the ground. Sleeping eases fatigue, but the ground leaves you less rested than a bed. Moving stops the animation.",FATIGUE_ROUGH_AFTER_MS / 1000);
    Help_Register(HELP_SECTION_SURVIVAL,"How do I sleep?",answer,true);
	Help_Register(HELP_SECTION_SURVIVAL,"Why am I tired?","~w~The day wears on you, more at night, in the saddle and at heavy work. Tired, you have a little less stamina and clumsier hands at work; exhausted, a little less again and a cold may find you. It never stops you doing anything.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"How do I rest?","~w~Sit down, sit by a ~y~fire~w~, sit in the inn, or eat: each eases it. Lie in a ~y~bed~w~ and you sleep and wake rested; your own bed is best, the bare ground worst, and worse still in the cold. Being away an hour or more counts as a night's sleep.",true);
	Command_Describe("fatigue","Staff: your fatigue, cap and work bands; /fatigue <0-100> sets it.");
	SetTimer("Fatigue_Tick",1000,true);
	SetTimer("Fatigue_SaveTick",300000,true);
}

hook OnMigrationRun()
{
	Migration_Add("fatigue-1","CREATE TABLE IF NOT EXISTS character_fatigue (character_id INT UNSIGNED NOT NULL PRIMARY KEY, fatigue FLOAT NOT NULL DEFAULT 0, updated_at INT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
