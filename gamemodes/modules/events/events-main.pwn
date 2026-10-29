#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I enter a tournament?","~w~When the lord proclaims one, the herald stands at the lists " EVENTS_LISTS_WHERE ". Sign up with him for the joust, the archery, the sword bout, the wrestling, the log toss or the drinking match, and be there when your name is called. Bring a horse for the joust.",true);
	new text[HELP_ANSWER_LEN];
	format(text,sizeof(text),"~w~Two fight at a time in the ring beside the lists, with blunted weapons. A blow hurts nobody but scores points. A weapon blow, punch or kick is 3, a hook 2, a shove 1, and a blow from behind counts double. Blocked blows score nothing. The first to %d points knocks the other down. Otherwise the herald calls time after %d seconds and the most points wins. Level points is a draw, settled by a coin toss. Press ~y~N~w~ twice to yield. If you stay outside the ring for %d seconds, you lose the bout.",EVENTS_FIGHT_POINTS,EVENTS_MELEE_MS / 1000,EVENTS_RING_GRACE_MS / 1000);
	Help_Register(HELP_SECTION_ROLEPLAY,"How does the sword bout work?",text,false);
	format(text,sizeof(text),"~w~Two wrestle at a time in the ring beside the lists, bare-handed. Blows score like in the sword bout. A punch or kick is 3 points, a hook 2, a shove 1, and a blow from behind counts double. The first to %d points throws the other. Otherwise the herald calls time after %d seconds and the most points wins. Take up a weapon in the wrestling and you're put out of it. Press ~y~N~w~ twice to yield.",EVENTS_FIGHT_POINTS,EVENTS_WRESTLE_MS / 1000);
	Help_Register(HELP_SECTION_ROLEPLAY,"How does the wrestling work?",text,false);
	format(text,sizeof(text),"~w~Press ~y~N~w~ during a bout in the ring, then press ~y~N~w~ again within %d seconds. Your opponent wins the bout.",EVENTS_YIELD_MS / 1000);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I yield a bout?",text,false);
	Help_Register(HELP_SECTION_ROLEPLAY,"Can I bet on a contest?","~w~Yes. The herald keeps the bookmaker's slate until a contest begins. Back a contestant with a stake; those who backed the winner share the pool, less a tenth for the host.",false);
	Help_Register(HELP_SECTION_ROLEPLAY,"When is the fair?","~w~Once a season, for a day, in Talmberg's square. Merchants from afar sell spices, dyes and fine cloth, and buy the county's surplus for more than the traders give.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"What festivals are there?","~w~The harvest festival on the first of the tenth month, with a contest for the best produce; fires on the village squares at midsummer and midwinter; and feast days when the duke decrees them.",false);
	Command_Describe("event","Admin: list events, declare a tournament, sign yourself up, stop or end one, open or close the market, open the fair, declare the harvest festival, light the bonfires.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Events_BarContext");
	Keys_RegisterContext(KEY_NO,KEYS_PRIO_SCENE,"Events_YieldContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Events_PracticeGateContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Events_PracticeContext");
	Keys_RegisterContext(KEY_CTRL_BACK,KEYS_PRIO_SCENE,"Events_PracticeContext");
	Help_Register(HELP_SECTION_ROLEPLAY,"How can I practise the joust?","~w~Bring a horse to the west gate of the lists. Press ~y~Y~w~ to practise at the quintain. Hold forward and gallop. Your horse keeps to its lane. Press ~y~Y~w~ to lower the lance and ~y~H~w~ to aim at the shield or helm. The lance takes 0.4 seconds to lower, stays steady for 0.8 seconds, then sags. A bad run at a walk lets the sandbag knock you off. Ride through the far gate or press ~y~F~w~ to leave practice.",true);
    Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Events_JoustContext");
    Keys_RegisterContext(KEY_CTRL_BACK,KEYS_PRIO_SCENE,"Events_JoustContext");
    Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Events_HeraldContext");
    Mount_SetDismountCheck("Events_JoustDismount");
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I joust?","~w~Sign up with the herald and bring a horse. Hold forward and gallop at your gate. Press ~y~Y~w~ to lower your lance about 15 m apart; ~y~H~w~ switches shield or helm aim. Your horse keeps to its lane. A shield hit scores 1 point, a steady galloping helm hit 2. Losing your seat loses the bout. Most points after three courses wins, with up to two extra courses for a tie. Press ~y~F~w~ twice within 3 seconds to forfeit.",true);
    Help_Register(HELP_SECTION_ROLEPLAY,"How can I be the herald?","~w~The tournament host appoints a nearby player through Hans Herold's menu. Stand on the herald's platform and press ~y~Y~w~ for the kit panel. Call the next pair, call time, accept a requested yield or stop a bout. Leave the stand or go idle for 2 minutes and Hans takes over.",false);
    Help_Register(HELP_SECTION_ROLEPLAY,"Can I joust against a sparring knight?","~w~If only one player enters the joust, the herald offers a bout against a sparring knight. Accept the panel within 60 seconds and bring your horse to the gate. The courses use the same lance and seat rules. There is no prize and tournament bets are returned.",false);
    SetTimer("Events_HeraldTick",1000,true);
	SetTimer("Events_PracticeTick",100,true);
	SetTimer("Events_Tick",EVENTS_TICK_MS,true);
    AnimPreload_Register("ON_LOOKERS");
    SetTimer("Events_SpectatorsTick",1000,true);
	SetTimer("Events_MinuteTick",EVENTS_MINUTE_MS,true);
	Boot_RegisterLoader("Events_LoadOnBoot");
}

hook Models_OnRegister()
{
	Models_AddObject(MODEL_TOURNEY_TILT,"tourney/tourney_tilt.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_TILT_END,"tourney/tourney_tilt_end.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_LISTS,"tourney/tourney_lists.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_LISTS_GATE,"tourney/tourney_lists_gate.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_LISTS_POST,"tourney/tourney_lists_post.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_BUTT,"tourney/tourney_butt.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_HERALD,"tourney/tourney_herald.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_SPLINTERS,"tourney/tourney_splinters.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_QUINTAIN,"tourney/tourney_quintain.dff","tourney/tourney.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_TOURNEY_QUINTAIN_ARM,"tourney/tourney_quintain_arm.dff","tourney/tourney.txd",MAP_BASE_STATIC);
}

hook OnMigrationRun()
{
	Migration_Add("events-1-events","CREATE TABLE IF NOT EXISTS events (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, host_character_id INT UNSIGNED NOT NULL DEFAULT 0, county_id INT NULL, place_key VARCHAR(32) NOT NULL DEFAULT '', starts_at INT NOT NULL, ends_at INT NOT NULL, purse INT NOT NULL DEFAULT 0, entry_fee INT NOT NULL DEFAULT 0, contests INT NOT NULL DEFAULT 0, fees INT NOT NULL DEFAULT 0, state TINYINT NOT NULL DEFAULT 0, decree_id INT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("events-2-entries","CREATE TABLE IF NOT EXISTS event_entries (event_id INT UNSIGNED NOT NULL, contest TINYINT NOT NULL, character_id INT UNSIGNED NOT NULL, score INT NOT NULL DEFAULT 0, placed TINYINT NOT NULL DEFAULT 0, item_param INT NOT NULL DEFAULT -1, item_stars TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (event_id, contest, character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("events-3-bets","CREATE TABLE IF NOT EXISTS event_bets (id INT UNSIGNED NOT NULL AUTO_INCREMENT, event_id INT UNSIGNED NOT NULL, contest TINYINT NOT NULL, bettor_character_id INT UNSIGNED NOT NULL, on_character_id INT UNSIGNED NOT NULL, stake INT NOT NULL, paid TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (id), KEY event_id (event_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("events-4-results","CREATE TABLE IF NOT EXISTS event_results (id INT UNSIGNED NOT NULL AUTO_INCREMENT, event_id INT UNSIGNED NOT NULL, contest TINYINT NOT NULL, first_character_id INT UNSIGNED NOT NULL DEFAULT 0, second_character_id INT UNSIGNED NOT NULL DEFAULT 0, third_character_id INT UNSIGNED NOT NULL DEFAULT 0, at INT NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Events_LoadOnBoot();

public Events_LoadOnBoot()
{
	new loaded = await Events_Load();
	await mysql_aquery_s(g_Mysql,str_format("SELECT place_key FROM events WHERE kind = %d ORDER BY id DESC LIMIT 1",EVENT_FAIR));

	if (cache_num_rows() > 0)
	{
		new key[32];
		cache_get_value_name(0,"place_key",key);

		if (!strcmp(key,"fair-",false,5))
		{
			Events_SetFairSeason(strval(key[5]));
		}
	}

	new pieces = Events_PlaceLists(), ringPieces = Events_PlaceRing();
	Log_Info("events","%d events open, last fair season %d, lists %s (%d pieces), ring %d pieces",loaded,Events_GetFairSeason(),g_EventsLists[0] != 0.0 ? ("placed") : ("missing"),pieces,ringPieces);
	Events_PlaceQuintain();
    Events_RefreshFair();
    Events_RefreshSpectators();
	Boot_LoaderDone();
	return 1;
}

hook OnGameModeExit()
{
    Events_ClearSpectators();
}
