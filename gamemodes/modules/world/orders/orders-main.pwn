#include <pp-hooks>

hook OnGameModeInit()
{
	Boot_RegisterLoader("Orders_LoadOnBoot");
	Command_Describe("orders","Staff: list, roll, expire or clear errands, set goodwill, daily duties, duties and warrants.");
	SetTimer("Contracts_Tick",60000,true);
	Help_Register(HELP_SECTION_WORK,"How do I find work when nobody else is around?","~w~The village always needs hands. The ~y~innkeeper~w~, the ~y~priest~w~, a ~y~yard master~w~, the ~y~reeve~w~ in Talmberg and the ~y~bailiff~w~ at the fortress post errands at dawn: walk up and pick ~y~Errands~w~, or read the ~y~Work~w~ tab of any notice board. Take up to three, bring the goods to whoever asked, and you're paid about three quarters of their worth from the county treasury.");
	Help_Register(HELP_SECTION_WORK,"Why can't I take some errands?","~w~Some errands go only to hands a giver knows. Every errand you bring them builds ~y~goodwill~w~ with that giver, more for goods well above the stars asked, and better errands open. Six deliveries a day at most.",false);
	Help_Register(HELP_SECTION_WORK,"What are the season's duties?","~w~Each season the village asks something of every hand: seed and fences for the reeve in spring, hay and moon-picked herbs in summer, harvest days and the ~y~tithe~w~ in autumn, firewood for the chapel and the gaol in winter, and bread for the priest on feast days. They pay a little from the county treasury and earn goodwill; the tithe is a tax and pays nothing. Miss one and the giver remembers; miss the tithe and it stands as a ~y~debt~w~ you can still pay.");
	Help_Register(HELP_SECTION_WORK,"How do I ask other players for goods?","~w~On the ~y~Work~w~ tab of a notice board, pick ~y~Post a contract~w~: name the goods, how many, the stars and your pay. The coin leaves your purse at once and the board holds it. Whoever takes it delivers at any board: the goods come to you and the coin goes to them. If nobody delivers in four days, you get your coin back.");
	Help_Register(HELP_SECTION_START,"Where can I see the tasks I've accepted?","~w~Open your character panel and click ~y~Ledger > Your tasks~w~. Your accepted errands, family parcels and contracts appear there with their destination, reward and time left. Click a task for details or to give it up.");
	Help_Register(HELP_SECTION_WORK,"How do I find suggested tasks?","~w~Open ~y~Ledger > Suggested~w~ for open errands within 200 metres, contracts and seasonal duties. Click a row to see how to take it. Family errands start by speaking to the giver with ~y~Y~w~.");
	Help_Register(HELP_SECTION_START,"Can I write my own goals in the Ledger?","~w~Click ~y~Your goals > Write a goal~w~ in the Ledger. You can keep eight goals, give them a date and tick them off. Completed goals stay under Your goals, where you can remove them. Suggestions you've been given can be kept as goals or dismissed.",false);
	Help_Register(HELP_SECTION_WORK,"Can I become a craftsman without a count?","~w~While the county has no count, the ~y~steward~w~ at the ducal fortress grants a ~y~craftsman's warrant~w~ by trial: three errands of one trade delivered at three stars or better in one season, level five in the trade, and the petition fee.",false);
	Help_Register(HELP_SECTION_WORK,"Is there anything to gather on the road?","~w~Yes. Berry bushes, herb patches, windfalls and digging ground line the road from Talmberg to the monastery. Each takes a short scene and refills with time.",false);
}

hook OnMigrationRun()
{
	Migration_Add("orders_v1","CREATE TABLE IF NOT EXISTS orders (id INT AUTO_INCREMENT PRIMARY KEY, giver_key VARCHAR(32) NOT NULL, def INT NOT NULL, item INT NOT NULL, qty INT NOT NULL, min_stars TINYINT NOT NULL DEFAULT 1, pay INT NOT NULL, posted_day INT NOT NULL, expires_day INT NOT NULL, taken_by INT NULL, KEY (giver_key), KEY (taken_by))");
	Migration_Add("order_goodwill_v1","CREATE TABLE IF NOT EXISTS order_goodwill (character_id INT NOT NULL, giver_key VARCHAR(32) NOT NULL, goodwill INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id, giver_key))");
	Migration_Add("order_daily_v1","CREATE TABLE IF NOT EXISTS order_daily (character_id INT NOT NULL PRIMARY KEY, day INT NOT NULL, count INT NOT NULL DEFAULT 0)");
	Migration_Add("order_duty_marks_v1","CREATE TABLE IF NOT EXISTS order_duty_marks (character_id INT NOT NULL, season_key INT NOT NULL, duty INT NOT NULL, state TINYINT NOT NULL, PRIMARY KEY (character_id, season_key, duty))");
	Migration_Add("order_contracts_v1","CREATE TABLE IF NOT EXISTS order_contracts (id INT AUTO_INCREMENT PRIMARY KEY, poster_id INT NOT NULL, poster_name VARCHAR(32) NOT NULL, item INT NOT NULL, qty INT NOT NULL, min_stars TINYINT NOT NULL DEFAULT 1, pay INT NOT NULL, expires_at INT NOT NULL, taken_by INT NULL, KEY (poster_id))");
	Migration_Add("order_trials_v1","CREATE TABLE IF NOT EXISTS order_trials (character_id INT NOT NULL, trade INT NOT NULL, season_key INT NOT NULL, count INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id, trade, season_key))");
	Migration_Add("order_warrants_v1","CREATE TABLE IF NOT EXISTS order_warrants (character_id INT NOT NULL, trade INT NOT NULL, granted_by VARCHAR(16) NOT NULL, granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (character_id, trade))");
	Migration_Add("ledger_goals_v1","CREATE TABLE IF NOT EXISTS ledger_goals (id INT AUTO_INCREMENT PRIMARY KEY, character_id INT NOT NULL, kind TINYINT NOT NULL DEFAULT 0, text VARCHAR(80) NOT NULL, due_day INT NULL, done TINYINT NOT NULL DEFAULT 0, KEY (character_id))");
}

hook Character_OnLoaded(playerid,characterid)
{
	Orders_LoadCharacter(playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Orders_ResetPlayer(playerid);
	Orders_ResetDuties(playerid);
	Orders_ResetSteward(playerid);
	Ledger_Reset(playerid);
}

hook OnPlayerConnect(playerid)
{
	Orders_ResetPlayer(playerid);
	Orders_ResetDuties(playerid);
	Orders_ResetSteward(playerid);
	Ledger_Reset(playerid);
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year
	SetTimer("Orders_DayDeferred",0,false);
}

hook Calendar_OnSeason(season)
{
	SetTimerEx("Orders_SeasonDeferred",0,false,"ddd",Orders_SeasonKey() - 1,(season + _:SEASON_COUNT - 1) % _:SEASON_COUNT,season);
}

hook Tutorial_OnFinished(playerid)
{
	SetTimerEx("Orders_TutorialTipDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}
