#include <pp-hooks>

hook OnGameModeInit()
{
    Actors_RegisterWalkerKind(WALKERS_KIND_ACTOR,ACTOR_ROLE_VILLAGER,"Villager","Villager");
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I talk to the villagers?","~w~Walk up to someone and press ~y~Y~w~. Pick ~y~Talk with him~w~ or ~y~Talk with her~w~ and click a line in the conversation panel. Ask for a meal or work from the conversation panel.~n~~n~Hurting or killing a villager is a crime like any other, and the people nearby see it.");
	Command_Describe("actor","Staff: list the actors, read or kill or revive the one near you, make them speak, go to one by key.");
	Keys_RegisterContext(KEY_YES,ACTORS_KEY_PRIO,"Actors_PromptContext");
	SetTimer("Actors_Tick",ACTORS_TICK_MS,true);
	SetTimer("Actors_PromptTick",ACTORS_TICK_MS,true);
	Boot_RegisterLoader("Actors_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("npc_actors","CREATE TABLE IF NOT EXISTS actors (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, actor_key VARCHAR(32) NOT NULL UNIQUE, role TINYINT NOT NULL, kind TINYINT NOT NULL DEFAULT 0, skin INT NOT NULL, name VARCHAR(32) NOT NULL, home_place_key VARCHAR(32) NOT NULL DEFAULT '', workplace_id INT NULL, schedule SMALLINT NOT NULL DEFAULT 0, persona SMALLINT NULL, can_act TINYINT NOT NULL DEFAULT 1, dead_until INT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("npc_actor_memory","CREATE TABLE IF NOT EXISTS actor_memory (actor_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL, summary VARCHAR(512) NOT NULL DEFAULT '', updated_at INT NOT NULL DEFAULT 0, PRIMARY KEY (actor_id, character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Actors_LoadOnBoot();

public Actors_LoadOnBoot()
{
	await Actors_LoadRows();
	Log_Info("actors","%d actor rows",Actors_CountRows());
	Boot_LoaderDone();
	return 1;
}
