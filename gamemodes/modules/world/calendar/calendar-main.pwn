#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("setdate","Dev: set the date, hour and minute.");
	Command_Describe("skiphours","Dev: move the calendar on by hours.");
	Boot_RegisterLoader("Calendar_LoadOnBoot");
	Timer_Start(Calendar_Tick,CALENDAR_TICK_MS);
}

hook OnMigrationRun()
{
	Migration_Add("calendar-1-world-calendar", "CREATE TABLE IF NOT EXISTS world_calendar (id TINYINT UNSIGNED NOT NULL, day TINYINT NOT NULL, month TINYINT NOT NULL, year SMALLINT NOT NULL, minute_of_day SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
