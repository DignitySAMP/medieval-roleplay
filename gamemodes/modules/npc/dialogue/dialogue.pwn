#define DIALOGUE_CONFIG_FILE "dialogue.ini"
#define DIALOGUE_URL_LEN (192)
#define DIALOGUE_REACH (6.0)
#define DIALOGUE_IDLE_SECONDS (180)
#define DIALOGUE_GAP_SECONDS (3)
#define DIALOGUE_REQUESTS (32)
#define DIALOGUE_MEMORY_LEN (512)
#define DIALOGUE_BODY_LEN (3072)
#define DIALOGUE_TIMEOUT_SECONDS (15)
#define DIALOGUE_CANNED_MS (1400)
#define DIALOGUE_TICK_MS (1000)
#define DIALOGUE_ACTION_NONE (0)
#define DIALOGUE_ACTION_WORK (1)
#define DIALOGUE_ACTION_MEAL (2)
#define DIALOGUE_ACTION_TRADE (3)

enum E_DIALOGUE_REQUEST
{
	bool:E_DIALOGUE_REQUEST_USED,
	E_DIALOGUE_REQUEST_PLAYER,
	E_DIALOGUE_REQUEST_ACTOR,
	E_DIALOGUE_REQUEST_AT,
	E_DIALOGUE_REQUEST_TOPIC,
	E_DIALOGUE_REQUEST_EXTRA,
}

enum
{
	DIALOGUE_STAT_SENT,
	DIALOGUE_STAT_MODEL,
	DIALOGUE_STAT_CANNED,
	DIALOGUE_STAT_FAILED,
	DIALOGUE_STAT_COUNT,
}

enum
{
	DIALOGUE_TOPIC_HELLO,
	DIALOGUE_TOPIC_NAME,
	DIALOGUE_TOPIC_THANKS,
	DIALOGUE_TOPIC_WORK,
	DIALOGUE_TOPIC_ERRAND,
	DIALOGUE_TOPIC_MEAL,
	DIALOGUE_TOPIC_FAMILY,
	DIALOGUE_TOPIC_NEWS,
	DIALOGUE_TOPIC_WEATHER,
	DIALOGUE_TOPIC_INN,
	DIALOGUE_TOPIC_CHURCH,
	DIALOGUE_TOPIC_ROADS,
	DIALOGUE_TOPIC_THIEVES,
	DIALOGUE_TOPIC_GOODS,
	DIALOGUE_TOPIC_PRICE,
	DIALOGUE_TOPIC_TRADE,
	DIALOGUE_TOPIC_ROLE,
	DIALOGUE_TOPIC_TABLE,
	DIALOGUE_TOPIC_PLAN,
	DIALOGUE_TOPIC_TRADEROW,
	DIALOGUE_TOPIC_WHERE,
	DIALOGUE_TOPIC_COUNT,
}

static s_DialogueUrl[DIALOGUE_URL_LEN];
static bool:s_DialogueEnabled;
static bool:s_DialogueStaffOnly = true;
static s_DialogueActor[MAX_PLAYERS] = {-1, ...};
static s_DialogueLastAt[MAX_PLAYERS];
static s_DialogueSeenAt[MAX_PLAYERS];
static s_DialogueMemory[MAX_PLAYERS][DIALOGUE_MEMORY_LEN];
static s_DialogueRequests[DIALOGUE_REQUESTS][E_DIALOGUE_REQUEST];
static s_DialogueLastError[64];
static s_DialogueStats[DIALOGUE_STAT_COUNT];

forward bool:Dialogue_IsPanelOpen(playerid);
forward Dialogue_PausePanel(playerid,bool:paused);
forward Dialogue_ReframeCamera(playerid);

forward Task:Dialogue_FetchMemory(playerid,actor,actorid,characterid);

stock Dialogue_LoadConfig()
{
	s_DialogueUrl[0] = EOS;
	s_DialogueEnabled = false;
	s_DialogueStaffOnly = true;

	new File:handle = fopen(DIALOGUE_CONFIG_FILE,io_read), line[DIALOGUE_URL_LEN + 16];

	if (!handle)
	{
		return 0;
	}

	while (fread(handle,line))
	{
		new length = strlen(line);

		while (length > 0 && (line[length - 1] == '\r' || line[length - 1] == '\n' || line[length - 1] == ' '))
		{
			line[--length] = EOS;
		}

		new equals = strfind(line,"=");

		if (line[0] == '#' || equals <= 0)
		{
			continue;
		}

		if (!strcmp(line,"url=",false,4))
		{
			strcopy(s_DialogueUrl,line[4]);
		}
		else if (!strcmp(line,"enabled=",false,8))
		{
			s_DialogueEnabled = strval(line[8]) != 0;
		}
		else if (!strcmp(line,"staff_only=",false,11))
		{
			s_DialogueStaffOnly = strval(line[11]) != 0;
		}
	}

	fclose(handle);
	return 1;
}

stock bool:Dialogue_IsTalking(playerid)
{
	return Util_IsValidPlayer(playerid) && s_DialogueActor[playerid] != -1;
}

stock Dialogue_GetActor(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_DialogueActor[playerid] : -1;
}

stock bool:Dialogue_UsesModel(playerid)
{
	return s_DialogueEnabled && s_DialogueUrl[0] != EOS && (!s_DialogueStaffOnly || Account_GetAdminLevel(playerid) > 0);
}

stock Dialogue_GetStat(stat)
{
	return stat >= 0 && stat < DIALOGUE_STAT_COUNT ? s_DialogueStats[stat] : 0;
}

stock Dialogue_GetMemory(playerid,dest[],size = sizeof(dest))
{
	strcopy(dest,Util_IsValidPlayer(playerid) ? s_DialogueMemory[playerid] : (""),size);
}

stock Dialogue_LastError()
{
	new text[64];
	strcopy(text,s_DialogueLastError[0] != EOS ? s_DialogueLastError : ("none"));
	return text;
}

stock s_DialogueEnabledText()
{
	new text[48];
	strcopy(text,!s_DialogueEnabled ? ("the service is off") : (s_DialogueUrl[0] == EOS ? ("no service address") : ("the service is on")));
	return text;
}

stock s_DialogueStaffOnlyText()
{
	new text[24];
	strcopy(text,s_DialogueStaffOnly ? ("staff only") : ("everyone"));
	return text;
}

stock Dialogue_SetStaffOnly(bool:staffOnly)
{
	s_DialogueStaffOnly = staffOnly;
}

stock Dialogue_Start(playerid,actor)
{
	if (!Actors_IsOpen(actor))
	{
		return 0;
	}

	if (Families_IsGuest(playerid))
	{
		Gui_Notify(playerid,"You are at the table. There is no chatting with the family during the meal. Get up first.");
		return 0;
	}

	if (s_DialogueActor[playerid] != -1)
	{
		Dialogue_End(playerid,false);
	}

	new name[ACTORS_NAME_LEN], text[144];
	Actors_GetFirstName(actor,name);
	s_DialogueActor[playerid] = actor;
	Actors_SetTalking(playerid,actor);
	Actors_ClearPrompt(playerid);
	s_DialogueSeenAt[playerid] = gettime();
	s_DialogueLastAt[playerid] = 0;
	s_DialogueMemory[playerid][0] = EOS;
	format(text,sizeof(text),"Talking with %s. Choose what to say from the conversation panel. Press ESC or choose Goodbye to stop.",name);
	Gui_Notify(playerid,text);
	Dialogue_LoadMemory(playerid,actor);
	pawn_call_public("Dialogue_OnStart","dd",playerid,actor);
	return 1;
}

stock Dialogue_End(playerid,bool:notify = true)
{
	if (s_DialogueActor[playerid] == -1)
	{
		return;
	}

	new actor = s_DialogueActor[playerid];
	s_DialogueActor[playerid] = -1;
	Actors_ReleasePrompt(playerid,actor);
	Actors_SetTalking(playerid,-1);

	if (notify)
	{
		Gui_Notify(playerid,"You end the conversation.");
	}

	pawn_call_public("Dialogue_OnEnd","dd",playerid,actor);
}

static Dialogue_LoadMemory(playerid,actor)
{
	new actorid = Actors_GetDbId(actor), characterid = Character_GetId(playerid);

	if (actorid <= 0 || characterid <= 0)
	{
		return;
	}

	Dialogue_FetchMemory(playerid,actor,actorid,characterid);
}

#pragma warning push
#pragma warning disable 204
async Task:Dialogue_FetchMemory(playerid,actor,actorid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT summary FROM actor_memory WHERE actor_id = %d AND character_id = %d",actorid,characterid));

	if (s_DialogueActor[playerid] == actor && Character_GetId(playerid) == characterid && cache_num_rows() > 0)
	{
		cache_get_value_name(0,"summary",s_DialogueMemory[playerid],DIALOGUE_MEMORY_LEN);
	}

	return async 1;
}
#pragma warning pop

static Dialogue_Remember(playerid,actor,const note[])
{
	new actorid = Actors_GetDbId(actor), characterid = Character_GetId(playerid);

	if (note[0] == EOS || actorid <= 0 || characterid <= 0)
	{
		return;
	}

	new length = strlen(s_DialogueMemory[playerid]), add = strlen(note) + 1;

	if (length + add >= DIALOGUE_MEMORY_LEN)
	{
		new cut = length + add - DIALOGUE_MEMORY_LEN + 1, space = strfind(s_DialogueMemory[playerid]," ",false,cut);
		strdel(s_DialogueMemory[playerid],0,space == -1 ? cut : space + 1);
	}

	if (s_DialogueMemory[playerid][0] != EOS)
	{
		strcat(s_DialogueMemory[playerid]," ");
	}

	strcat(s_DialogueMemory[playerid],note);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO actor_memory (actor_id, character_id, summary, updated_at) VALUES (%d, %d, '%e', %d) ON DUPLICATE KEY UPDATE summary = VALUES(summary), updated_at = VALUES(updated_at)",actorid,characterid,s_DialogueMemory[playerid],gettime()));
}

stock Dialogue_JsonEscape(const source[],dest[],size = sizeof(dest))
{
	new out = 0;

	for (new i = 0;source[i] != EOS && out < size - 2;i++)
	{
		new c = source[i];

		if (c == '"' || c == '\\')
		{
			dest[out++] = '\\';
			dest[out++] = c;
		}
		else if (c < 32)
		{
			dest[out++] = ' ';
		}
		else
		{
			dest[out++] = c;
		}
	}

	dest[out] = EOS;
}

static Dialogue_WeatherWords(dest[],size = sizeof(dest))
{
	new weather = Calendar_GetWeather();

	if (Weather_IsSnowing())
	{
		strcopy(dest,"snowing",size);
	}
	else if (weather == 8 || weather == 16)
	{
		strcopy(dest,"raining",size);
	}
	else if (weather == 9)
	{
		strcopy(dest,"foggy",size);
	}
	else
	{
		strcopy(dest,"dry",size);
	}
}

stock Dialogue_BuildBody(playerid,actor,const line[],dest[],size = sizeof(dest))
{
	new key[ACTORS_KEY_LEN], name[ACTORS_NAME_LEN], title[ACTORS_TITLE_LEN], player[MAX_PLAYER_NAME], speaker[MAX_PLAYER_NAME + 16];
	new date[64], hour[12], season[CALENDAR_NAME_LEN], weather[16], place[48], escaped[3][160], memory[DIALOGUE_MEMORY_LEN + 32];
	Actors_GetKey(actor,key);
	Actors_GetName(actor,name);
	Actors_GetTitle(actor,title);
	Character_GetName(playerid,player);
	Calendar_FormatDate(date);
	Routine_GetHourName(Routine_GetHour(),hour);
	Calendar_SeasonName(Calendar_GetSeason(),season);
	Dialogue_WeatherWords(weather);
	strcopy(speaker,"a stranger");

	new member = Families_GetMemberOfActor(actor);

	if (member != -1)
	{
		new family = Families_GetMemberFamily(member);
		strcopy(place,g_HouseDefs[Families_GetHouse(family)][E_HOUSE_DEF_NAME]);

		if (Families_GetFavour(playerid,family) >= FAMILY_FAVOUR_NAME)
		{
			strcopy(speaker,player);
		}
	}
	else
	{
		strcopy(place,"in the village");
	}

	if (Actors_GetWorld(actor) == 0 && member != -1)
	{
		format(place,sizeof(place),"outside, near %s",g_HouseDefs[Families_GetHouse(Families_GetMemberFamily(member))][E_HOUSE_DEF_NAME]);
	}

	Dialogue_JsonEscape(line,escaped[0]);
	Dialogue_JsonEscape(name,escaped[1]);
	Dialogue_JsonEscape(speaker,escaped[2]);
	Dialogue_JsonEscape(s_DialogueMemory[playerid],memory);
	format(dest,size,"{\"actor_key\":\"%s\",\"name\":\"%s\",\"title\":\"%s\",\"role\":\"%s\",\"character_id\":%d,\"player\":\"%s\",\"speaker\":\"%s\",\"speaker_sex\":\"%s\",\"line\":\"%s\",\"memory\":\"%s\",",
		key,escaped[1],title,g_ActorRoleNames[Actors_GetRole(actor)],Character_GetId(playerid),player,escaped[2],Character_GetSex(playerid) ? ("a woman") : ("a man"),escaped[0],memory);
	format(dest,size,"%s\"context\":{\"date\":\"%s\",\"hour\":\"%s\",\"season\":\"%s\",\"weather\":\"%s\",\"place\":\"%s\",\"smell\":\"%s\"}}",dest,date,hour,season,weather,place,Hygiene_IsReeking(playerid) ? ("the visitor reeks of filth; you can hardly stand near them") : (Hygiene_IsStinking(playerid) ? ("the visitor stinks of sweat and dirt and has flies about them") : ("")));
}

static Dialogue_FreeSlot()
{
	for (new slot = 0;slot < DIALOGUE_REQUESTS;slot++)
	{
		if (!s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED])
		{
			return slot;
		}
	}

	return -1;
}

stock bool:Dialogue_IsReady(playerid)
{
    return Dialogue_IsTalking(playerid) && gettime() - s_DialogueLastAt[playerid] >= DIALOGUE_GAP_SECONDS;
}

stock Dialogue_Hear(playerid,topic,extra,const line[])
{
	new actor = s_DialogueActor[playerid], now = gettime();

	if (actor == -1 || line[0] == EOS || topic < 0 || topic >= DIALOGUE_TOPIC_COUNT)
	{
		return 0;
	}

	if (now - s_DialogueLastAt[playerid] < DIALOGUE_GAP_SECONDS)
	{
		Gui_Notify(playerid,"Give them a moment to answer.");
		return 0;
	}

	s_DialogueLastAt[playerid] = now;
	s_DialogueSeenAt[playerid] = now;
	s_DialogueStats[DIALOGUE_STAT_SENT]++;

	if (!Dialogue_UsesModel(playerid) || ((topic == DIALOGUE_TOPIC_WORK || topic == DIALOGUE_TOPIC_ERRAND) && Families_GetErrand(playerid) != -1))
	{
		Dialogue_QueueCanned(playerid,actor,topic,extra);
		return 1;
	}

	new slot = Dialogue_FreeSlot();

	if (slot == -1)
	{
		Dialogue_QueueCanned(playerid,actor,topic,extra);
		return 1;
	}

	new body[DIALOGUE_BODY_LEN];
	Dialogue_BuildBody(playerid,actor,line,body);
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED] = true;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_PLAYER] = playerid;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_ACTOR] = actor;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_AT] = now;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_TOPIC] = topic;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_EXTRA] = extra;

	if (!HTTP(slot,HTTP_POST,s_DialogueUrl,body,"Dialogue_OnResponse"))
	{
		s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED] = false;
		strcopy(s_DialogueLastError,"the request couldn't be sent");
		Dialogue_QueueCanned(playerid,actor,topic,extra);
	}

	return 1;
}

static Dialogue_QueueCanned(playerid,actor,topic,extra)
{
	new slot = Dialogue_FreeSlot();

	if (slot == -1)
	{
		SetTimerEx("Dialogue_CannedNowDeferred",0,false,"dddd",playerid,actor,topic,extra);
		return;
	}

	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED] = true;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_PLAYER] = playerid;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_ACTOR] = actor;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_AT] = 0;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_TOPIC] = topic;
	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_EXTRA] = extra;
	SetTimerEx("Dialogue_CannedDeferred",DIALOGUE_CANNED_MS,false,"d",slot);
}

stock bool:Dialogue_AnswerTakenWork(playerid,actor,topic)
{
    if ((topic != DIALOGUE_TOPIC_WORK && topic != DIALOGUE_TOPIC_ERRAND) || Families_GetErrand(playerid) == -1)
    {
        return false;
    }
    Actors_Say(actor,"You've already taken an errand. Finish that one first.");
    return true;
}

stock Dialogue_Canned(playerid,actor,topic,extra)
{
	if (!Actors_IsPlaced(actor) || s_DialogueActor[playerid] != actor)
	{
		return;
	}

	s_DialogueStats[DIALOGUE_STAT_CANNED]++;

    if (Dialogue_AnswerTakenWork(playerid,actor,topic))
    {
        return;
    }

	if (Hygiene_IsStinking(playerid) && random(3) == 0)
	{
		Actors_Say(actor,Hygiene_IsReeking(playerid) ? ("I can't think with that smell. Go and wash, then we'll talk.") : ("You smell like a midden, you know that?"));
		return;
	}

	new text[144], action = Dialogue_FormatAnswer(actor,topic,extra,text);

	if (text[0] != EOS)
	{
		Actors_Say(actor,text);
	}

	if (action > DIALOGUE_ACTION_NONE)
	{
		Dialogue_ActionDeferred(playerid,actor,action);
	}
}

stock Dialogue_Apply(playerid,actor,const intent[],const say[],const note[])
{
    if (intent[0] != EOS && !strcmp(intent,"work") && Dialogue_AnswerTakenWork(playerid,actor,DIALOGUE_TOPIC_WORK))
    {
        return;
    }

	Actors_Say(actor,say);
	s_DialogueStats[DIALOGUE_STAT_MODEL]++;
	Dialogue_Remember(playerid,actor,note);
	pawn_call_public("Dialogue_OnReply","dds",playerid,actor,say);
	pawn_call_public("Dialogue_OnAction","dds",playerid,actor,intent);

	new member = Families_GetMemberOfActor(actor);

	if (!strcmp(intent,"work") && member != -1)
	{
		SetTimerEx("Dialogue_ActionDeferred",DIALOGUE_CANNED_MS,false,"ddd",playerid,actor,DIALOGUE_ACTION_WORK);
	}
	else if (!strcmp(intent,"meal") && member != -1)
	{
		SetTimerEx("Dialogue_ActionDeferred",DIALOGUE_CANNED_MS,false,"ddd",playerid,actor,DIALOGUE_ACTION_MEAL);
	}
	else if (!strcmp(intent,"sell"))
	{
		SetTimerEx("Dialogue_ActionDeferred",DIALOGUE_CANNED_MS,false,"ddd",playerid,actor,DIALOGUE_ACTION_TRADE);
	}
	else if (!strcmp(intent,"guard"))
	{
		new name[ACTORS_NAME_LEN], text[96];
		Actors_GetFirstName(actor,name);
		format(text,sizeof(text),"%s looks ready to shout for the guard.",name);
		Gui_Notify(playerid,text);
	}
	else if (!strcmp(intent,"farewell"))
	{
		Dialogue_End(playerid);
	}
}

stock Dialogue_ParseResponse(const data[],intent[],say[],note[],intentSize = sizeof(intent),saySize = sizeof(say),noteSize = sizeof(note))
{
	new first = strfind(data,"\t");

	intent[0] = EOS;
	say[0] = EOS;
	note[0] = EOS;

	if (first == -1)
	{
		return 0;
	}

	strmid(intent,data,0,first,intentSize);
	new second = strfind(data,"\t",false,first + 1);

	if (second == -1)
	{
		strmid(say,data,first + 1,strlen(data),saySize);
		return 1;
	}

	strmid(say,data,first + 1,second,saySize);
	strmid(note,data,second + 1,strlen(data),noteSize);
	return 1;
}

Timer_Declare(Dialogue_Tick)
{
	new now = gettime();

	for (new slot = 0;slot < DIALOGUE_REQUESTS;slot++)
	{
		if (s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED] && s_DialogueRequests[slot][E_DIALOGUE_REQUEST_AT] > 0 && now - s_DialogueRequests[slot][E_DIALOGUE_REQUEST_AT] > DIALOGUE_TIMEOUT_SECONDS)
		{
			s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED] = false;
			s_DialogueStats[DIALOGUE_STAT_FAILED]++;
			strcopy(s_DialogueLastError,"the service didn't answer in time");
			Dialogue_Canned(s_DialogueRequests[slot][E_DIALOGUE_REQUEST_PLAYER],s_DialogueRequests[slot][E_DIALOGUE_REQUEST_ACTOR],s_DialogueRequests[slot][E_DIALOGUE_REQUEST_TOPIC],s_DialogueRequests[slot][E_DIALOGUE_REQUEST_EXTRA]);
		}
	}

	foreach (new playerid : Player)
	{
		new actor = s_DialogueActor[playerid];

		if (actor == -1)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Actors_GetPos(actor,x,y,z);

		if (!Actors_IsOpen(actor) || !Actors_IsPlaced(actor) || Actors_GetWorld(actor) != GetPlayerVirtualWorld(playerid) || !IsPlayerInRangeOfPoint(playerid,DIALOGUE_REACH * 1.5,x,y,z))
		{
			Dialogue_End(playerid);
			continue;
		}

		if (now - s_DialogueSeenAt[playerid] > DIALOGUE_IDLE_SECONDS)
		{
			Dialogue_End(playerid);
			continue;
		}

		Dialogue_ReframeCamera(playerid);
	}

	return 1;
}

forward Dialogue_OnResponse(index,response_code,const data[]);

public Dialogue_OnResponse(index,response_code,const data[])
{
	if (index < 0 || index >= DIALOGUE_REQUESTS || !s_DialogueRequests[index][E_DIALOGUE_REQUEST_USED])
	{
		return 1;
	}

	new playerid = s_DialogueRequests[index][E_DIALOGUE_REQUEST_PLAYER], actor = s_DialogueRequests[index][E_DIALOGUE_REQUEST_ACTOR], topic = s_DialogueRequests[index][E_DIALOGUE_REQUEST_TOPIC], extra = s_DialogueRequests[index][E_DIALOGUE_REQUEST_EXTRA];
	s_DialogueRequests[index][E_DIALOGUE_REQUEST_USED] = false;

	if (!IsPlayerConnected(playerid) || s_DialogueActor[playerid] != actor)
	{
		return 1;
	}

    if (Dialogue_AnswerTakenWork(playerid,actor,topic))
    {
        return 1;
    }

	new intent[16], say[160], note[220];

	if (response_code != 200 || !Dialogue_ParseResponse(data,intent,say,note) || say[0] == EOS || !strcmp(intent,"capped") || !strcmp(intent,"limited") || !strcmp(intent,"error"))
	{
		if (response_code != 200)
		{
			format(s_DialogueLastError,sizeof(s_DialogueLastError),"the service answered %d",response_code);
			s_DialogueStats[DIALOGUE_STAT_FAILED]++;
		}
		else if (intent[0] != EOS)
		{
			format(s_DialogueLastError,sizeof(s_DialogueLastError),"the service said %s",intent);
		}

		Dialogue_Canned(playerid,actor,topic,extra);
		return 1;
	}

	Dialogue_Apply(playerid,actor,intent,say,note);
	return 1;
}

forward Dialogue_CannedDeferred(slot);

public Dialogue_CannedDeferred(slot)
{
	if (slot < 0 || slot >= DIALOGUE_REQUESTS || !s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED])
	{
		return 1;
	}

	s_DialogueRequests[slot][E_DIALOGUE_REQUEST_USED] = false;

	if (IsPlayerConnected(s_DialogueRequests[slot][E_DIALOGUE_REQUEST_PLAYER]))
	{
		Dialogue_Canned(s_DialogueRequests[slot][E_DIALOGUE_REQUEST_PLAYER],s_DialogueRequests[slot][E_DIALOGUE_REQUEST_ACTOR],s_DialogueRequests[slot][E_DIALOGUE_REQUEST_TOPIC],s_DialogueRequests[slot][E_DIALOGUE_REQUEST_EXTRA]);
	}

	return 1;
}

forward Dialogue_CannedNowDeferred(playerid,actor,topic,extra);

public Dialogue_CannedNowDeferred(playerid,actor,topic,extra)
{
	if (IsPlayerConnected(playerid))
	{
		Dialogue_Canned(playerid,actor,topic,extra);
	}

	return 1;
}

static Dialogue_OpenTrade(playerid,actor)
{
    new trader = Actors_GetOwner(actor);

    if (!Trader_IsPresent(trader) || !Trader_IsOpen())
    {
        Actors_Say(actor,"My stall is shut for now. Come back when it's open.");
        return;
    }

    if (!Trader_IsNear(playerid,trader,TRADER_REACH + 1.0))
    {
        Actors_Say(actor,"Come a little closer, I can't weigh anything from over there.");
        return;
    }

    Trader_RunPanel(playerid,trader);
}

forward Dialogue_ActionDeferred(playerid,actor,action);

public Dialogue_ActionDeferred(playerid,actor,action)
{
    yield 1;
	if (!IsPlayerConnected(playerid) || s_DialogueActor[playerid] != actor || (Gui_IsBusy(playerid) && !Dialogue_IsPanelOpen(playerid)))
	{
		return 1;
	}

    Dialogue_PausePanel(playerid,true);

    if (Dialogue_IsPanelOpen(playerid))
    {
        Kit_Close(playerid);
    }

	new member = Families_GetMemberOfActor(actor);

	switch (action)
	{
		case DIALOGUE_ACTION_WORK: if (member != -1) Families_OpenWork(playerid,member);
		case DIALOGUE_ACTION_MEAL: if (member != -1) Families_OpenMealOffer(playerid,member);
		case DIALOGUE_ACTION_TRADE: Dialogue_OpenTrade(playerid,actor);
	}

    if (s_DialogueActor[playerid] == actor)
    {
        Dialogue_PausePanel(playerid,false);
    }

	return 1;
}

forward Dialogue_MenuStart(playerid,index,data);

public Dialogue_MenuStart(playerid,index,data)
{
	#pragma unused data

	if (IsPlayerConnected(playerid))
	{
		Dialogue_Start(playerid,index);
	}

	return 1;
}

forward Dialogue_MenuEnd(playerid,index,data);

public Dialogue_MenuEnd(playerid,index,data)
{
	#pragma unused index, data

	if (IsPlayerConnected(playerid))
	{
		Dialogue_End(playerid);
	}

	return 1;
}

forward Dialogue_OnStart(playerid,actor);

public Dialogue_OnStart(playerid,actor)
{
	return 1;
}

forward Dialogue_OnEnd(playerid,actor);

public Dialogue_OnEnd(playerid,actor)
{
	return 1;
}

forward Dialogue_OnReply(playerid,actor,const text[]);

public Dialogue_OnReply(playerid,actor,const text[])
{
	return 1;
}

forward Dialogue_OnAction(playerid,actor,const action[]);

public Dialogue_OnAction(playerid,actor,const action[])
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_DialogueActor[playerid] = -1;
	s_DialogueLastAt[playerid] = 0;
	s_DialogueMemory[playerid][0] = EOS;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_DialogueActor[playerid] = -1;
	Actors_SetTalking(playerid,-1);
	Actors_SetMenuTalking(playerid,-1);
}

hook Actors_OnMenuBuild(playerid,index)
{
	if (s_DialogueActor[playerid] == index)
	{
		Actors_MenuAdd(playerid,"End the conversation","Dialogue_MenuEnd",0,KIT_COLOUR_MUTED);
	}
	else
	{
		Actors_MenuAdd(playerid,Actors_GetSex(index) == 1 ? ("Talk with her") : ("Talk with him"),"Dialogue_MenuStart",0,KIT_COLOUR_ACCENT);
	}
}

hook Actors_OnRemoved(index)
{
    foreach (new playerid : Player)
    {
        if (s_DialogueActor[playerid] == index)
        {
            Dialogue_End(playerid,false);
        }
    }
}

hook Actors_OnKilled(index,killerid)
{
	#pragma unused killerid

	foreach (new playerid : Player)
	{
		if (s_DialogueActor[playerid] == index)
		{
			Dialogue_End(playerid,false);
		}
	}
}
