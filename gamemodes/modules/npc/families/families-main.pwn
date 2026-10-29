#include <pp-hooks>

hook OnGameModeInit()
{
    new library[20], name[20];
    for (new E_FAMILY_ACT:act = FAMILY_ACT_STAND;act < FAMILY_ACT_COUNT;act++)
    {
        if (Families_GetActivityAnimation(act,library,sizeof(library),name,sizeof(name)))
        {
            AnimPreload_Register(library);
        }
    }
    AnimPreload_Register("INT_OFFICE");
    AnimPreload_Register("BOMBER");
    Help_Register(HELP_SECTION_ROLEPLAY,"Where do villagers go during the day?","~w~Every villager has a day of their own. Craftsfolk work at their trade while farmers go out to the fields. Wives fetch water at the well and spin with the neighbours. Children play on the green. Nearly everyone goes to mass on Sunday. On Saturday the sellers go to ~y~Talmberg market~w~. Rain and snow keep most of them indoors.~n~~n~To hear what someone is doing, press ~y~Y~w~, choose ~y~Talk with them~w~, then ~y~Work~w~ > ~y~What are you up to?~w~.",false);
    Help_Register(HELP_SECTION_ROLEPLAY,"What is the spinning circle?","~w~On most afternoons after ~y~Nones~w~, wives from neighbouring houses sit by one house's door and spin together. Each wife joins every other day, at a different house each time. In rain or snow they spin at home instead.",false);
    Help_Register(HELP_SECTION_ROLEPLAY,"Why is a villager in bed during the day?","~w~They're ill. Now and then a villager falls sick and stays in bed for one to three days. Someone from the household sits with them at ~y~Terce~w~, after ~y~Nones~w~ and before ~y~Vespers~w~. If you ask what they're up to, they'll tell you they're ill.",false);

	Help_Register(HELP_SECTION_ROLEPLAY,"Who are the families in the villages?","~w~Every house has a family. They work by day: in the fields, the yard, the forest, at the market or at the hearth. When the bell rings for ~y~Sext~w~ and ~y~Vespers~w~ they go home and eat, and at ~y~Compline~w~ they go to bed.~n~~n~Walk up to one of them and press ~y~Y~w~ to talk, ask for work or ask to eat with them.");
    new mealHelp[HELP_ANSWER_LEN];
    format(mealHelp,sizeof(mealHelp),"~w~Ask one of them if you can eat with them before the meal starts. A poor house asks a coin for the pot, once. If you rent a room in their house you're always welcome.~n~~n~Meals start %d minutes after Sext and Vespers. Come in after the bell and stand by a free seat. If they haven't asked you yet, ~y~Y~w~ asks if you can eat with them. Once you're welcome, ~y~Y~w~ sits you down. After the grace, press ~y~Y~w~ to take a bite. They'll talk to you between bites: answer before you take the next one. Clean your plate and they'll like you better, and you leave ~y~Well fed~w~. Getting up early is rude.",FAMILY_MEAL_WINDOW);
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I eat with a family?",mealHelp);
	Help_Register(HELP_SECTION_ROLEPLAY,"What are errands?","~w~Ask a villager if there's work. They might want firewood, fish or salt brought to them, or a parcel carried to someone in another house. You're paid a little coin and the family thinks better of you.~n~~n~Families who like you greet you by name and feed you for free.",false);
	new answer[HELP_ANSWER_LEN];
	format(answer,sizeof(answer),"~w~Until you've played ~y~%d hours~w~, family errands pay you double coin. A 4 pfennig errand pays you 8.~n~~n~The ~y~Newcomer's wages~w~ bar next to the map shows how long it has left. You'll get a message when it ends.",FAMILY_NEWCOMER_MINUTES / 60);
	Help_Register(HELP_SECTION_START,"Why do errands pay me double?",answer,true);
	Timer_Start(Families_NewcomerTick,FAMILY_NEWCOMER_TICK_MS);
	Command_Describe("family","Staff: list the households, read the one you're in or near, start or end its meal, set your favour or its stores, clear your errands, freeze or refresh where people stand.");
	Command_Describe("days","Staff: show today's kind of day, who is where and why, mark someone sick, or switch the workshops.");
	Keys_RegisterContext(KEY_YES,FAMILY_SEAT_KEY_PRIO,"Families_PromptContext");
	SetTimer("Families_Tick",FAMILY_TICK_MS * 2,true);
	SetTimer("Families_MealTimer",FAMILY_TICK_MS,true);
	SetTimer("Families_PromptTick",FAMILY_PROMPT_MS,true);
	Boot_RegisterLoader("Families_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("npc_households","CREATE TABLE IF NOT EXISTS households (id INT UNSIGNED NOT NULL PRIMARY KEY, house_key VARCHAR(16) NOT NULL UNIQUE, name VARCHAR(32) NOT NULL, wealth TINYINT NOT NULL DEFAULT 1, trade TINYINT NULL, piety TINYINT NOT NULL DEFAULT 1, stores SMALLINT NOT NULL DEFAULT 100) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("npc_household_members","CREATE TABLE IF NOT EXISTS household_members (id INT UNSIGNED NOT NULL PRIMARY KEY, household_id INT UNSIGNED NOT NULL, actor_id INT UNSIGNED NULL, name VARCHAR(16) NOT NULL, role TINYINT NOT NULL, age_band TINYINT NOT NULL DEFAULT 2, skin SMALLINT NOT NULL DEFAULT 0, persona SMALLINT NOT NULL DEFAULT 0, seat SMALLINT NOT NULL DEFAULT -1, bed SMALLINT NOT NULL DEFAULT -1, married_to_character_id INT UNSIGNED NULL, KEY household (household_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("npc_errand_progress","CREATE TABLE IF NOT EXISTS errand_progress (character_id INT UNSIGNED NOT NULL, errand_key VARCHAR(32) NOT NULL, state TINYINT NOT NULL DEFAULT 0, taken_at INT NOT NULL DEFAULT 0, done_at INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id, errand_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("npc_household_favour","CREATE TABLE IF NOT EXISTS household_favour (household_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL, favour SMALLINT NOT NULL DEFAULT 0, last_meal_at INT NOT NULL DEFAULT 0, PRIMARY KEY (household_id, character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Families_AddSkinMigration();
}
