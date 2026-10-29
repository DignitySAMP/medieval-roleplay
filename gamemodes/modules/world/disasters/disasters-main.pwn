#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"Are there storms and plagues?","~w~Rarely. The crier warns of the signs first: a storm, a flood, a drought or a sickness. Storms throw lightning at thatch and chill anyone out in them; floods turn the roads to mud; a drought makes food dear and fires fierce; in a sickness, crowds in the villages catch it.",true);
	Command_Describe("disaster","Staff: start or stop a storm, flood, drought or pestilence, strike lightning, sicken the villages.");
	SetTimer("Disasters_Tick",DISASTERS_TICK_MS,true);
	Boot_RegisterLoader("Disasters_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("disasters-1-disasters","CREATE TABLE IF NOT EXISTS disasters (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, county_id INT NULL, starts_at INT NOT NULL, ends_at INT NOT NULL DEFAULT 0, severity TINYINT NOT NULL DEFAULT 1, season TINYINT NOT NULL DEFAULT 0, ended TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Disasters_LoadOnBoot();

public Disasters_LoadOnBoot()
{
	new kind = await Disasters_Load(), name[20];
	Disasters_GetName(kind,name);
	Log_Info("disasters","%s %s",name,kind == -1 ? ("is under way") : (Disasters_IsWarned() ? ("is coming") : ("is under way")));
	Boot_LoaderDone();
	return 1;
}
