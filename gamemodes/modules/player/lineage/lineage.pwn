#define LINEAGE_CAUSE_LEN (24)
#define LINEAGE_AILMENT_COST (2)
#define LINEAGE_DEFAULT_COST (1)
#define LINEAGE_MARK_KEY "marked"
#define LINEAGE_RITES_KEY "rites"
#define LINEAGE_FAREWELL_MS (4000)
#define LINEAGE_DAY_MINUTES (1440)
#define LINEAGE_RESPAWN_NEED (50)
#define LINEAGE_RESPAWN_NOTICE_MS (3500)
#define LINEAGE_RETIRED_CAUSE "old age"

static const Float:s_LineageChapels[][4] = {
	{714.5767, -3627.9961, 18.3047, 38.5884}
};

static bool:s_LineageLoaded[MAX_PLAYERS];
static s_LineageClock[MAX_PLAYERS];
static s_LineageBornDay[MAX_PLAYERS];
static s_LineageHeld[MAX_PLAYERS];
static s_LineageBonus[MAX_PLAYERS];
static bool:s_LineageRites[MAX_PLAYERS];
static s_LineageAge[MAX_PLAYERS];
static s_LineageCause[MAX_PLAYERS][LINEAGE_CAUSE_LEN];
static bool:s_LineageRespawn[MAX_PLAYERS];
static Float:s_LineageDeathPos[MAX_PLAYERS][2];

static Lineage_Today()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Calendar_DaysSinceEpoch(day,month,year);
}

stock bool:Lineage_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_LineageLoaded[playerid];
}

stock Lineage_GetAge(playerid)
{
	if (!Lineage_IsLoaded(playerid))
	{
		return Character_GetAge(playerid);
	}

	return Character_GetAge(playerid) + max((Lineage_Today() - s_LineageBornDay[playerid]) * LINEAGE_DAY_MINUTES - s_LineageHeld[playerid],0) / (CALENDAR_DAYS_PER_MONTH * LINEAGE_DAY_MINUTES);
}

stock Lineage_GetHeldMinutes(playerid)
{
	return Lineage_IsLoaded(playerid) ? s_LineageHeld[playerid] : 0;
}

stock bool:Lineage_HoldBackAge(playerid,minutes)
{
	if (!Lineage_IsLoaded(playerid) || minutes <= 0)
	{
		return false;
	}

	s_LineageHeld[playerid] += minutes;
	Lineage_Persist(playerid);
	pawn_call_public("Lineage_OnAgeHeld","dd",playerid,minutes);
	return true;
}

stock Lineage_GetLifeClock(playerid)
{
	return Lineage_IsLoaded(playerid) ? s_LineageClock[playerid] : 0;
}

stock bool:Lineage_IsMarked(playerid)
{
	return Lineage_IsLoaded(playerid) && s_LineageClock[playerid] <= 0;
}

stock Lineage_CauseCost(const cause[])
{
	new name[AILMENT_NAME_LEN];

	for (new ailment = 0;ailment < AILMENT_COUNT;ailment++)
	{
		Ailment_GetName(ailment,name);

		if (name[0] != EOS && !strcmp(name,cause,true))
		{
			return LINEAGE_AILMENT_COST;
		}
	}

	return LINEAGE_DEFAULT_COST;
}

static Lineage_EngineCause(WEAPON:reason,dest[],size = sizeof(dest))
{
	switch (reason)
	{
		case WEAPON_COLLISION: strcopy(dest,"a fall",size);
		case WEAPON_DROWN: strcopy(dest,"drowning",size);
		default: strcopy(dest,"unknown",size);
	}
}

static Lineage_Persist(playerid)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE characters SET life_clock = %d, born_day = %d, age_held_minutes = %d WHERE id = %d",s_LineageClock[playerid],s_LineageBornDay[playerid],s_LineageHeld[playerid],Character_GetId(playerid)));
}

static Lineage_ShowMark(playerid)
{
	if (Lineage_IsMarked(playerid))
	{
		Buff_Set(playerid,LINEAGE_MARK_KEY,"Marked by death","Your life clock is spent. Your next death is your last.");
	}
	else
	{
		Buff_Clear(playerid,LINEAGE_MARK_KEY);
	}

	if (s_LineageRites[playerid])
	{
		Buff_Set(playerid,LINEAGE_RITES_KEY,"Last rites","You've been anointed and have made a last confession. If you die now, you die absolved.");
	}
	else
	{
		Buff_Clear(playerid,LINEAGE_RITES_KEY);
	}
}

static Lineage_Reset(playerid)
{
	s_LineageLoaded[playerid] = false;
	s_LineageClock[playerid] = 0;
	s_LineageBornDay[playerid] = 0;
	s_LineageHeld[playerid] = 0;
	s_LineageBonus[playerid] = 0;
	s_LineageRites[playerid] = false;
	s_LineageAge[playerid] = 0;
	s_LineageCause[playerid][0] = EOS;
	s_LineageRespawn[playerid] = false;
}

static Lineage_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT IFNULL(life_clock, -1) AS life_clock, IFNULL(born_day, -1) AS born_day, age_held_minutes, life_bonus, last_rites FROM characters WHERE id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid || cache_num_rows() == 0)
	{
		return;
	}

	new clock, bornDay;
	cache_get_value_name_int(0,"life_clock",clock);
	cache_get_value_name_int(0,"born_day",bornDay);
	cache_get_value_name_int(0,"age_held_minutes",s_LineageHeld[playerid]);
	cache_get_value_name_int(0,"life_bonus",s_LineageBonus[playerid]);

	new rites;
	cache_get_value_name_int(0,"last_rites",rites);
	s_LineageRites[playerid] = rites != 0;

	if (clock < 0)
	{
		clock = Creator_LifeClockAt(Character_GetAge(playerid),Character_GetAttribute(playerid,_:ATTR_WILLPOWER)) + s_LineageBonus[playerid];
	}

	if (bornDay < 0)
	{
		bornDay = Lineage_Today();
	}

	s_LineageClock[playerid] = clock;
	s_LineageBornDay[playerid] = bornDay;
	s_LineageLoaded[playerid] = true;
	s_LineageAge[playerid] = Lineage_GetAge(playerid);
	Lineage_Persist(playerid);
	Lineage_ShowMark(playerid);
}

static Lineage_CheckBirthday(playerid)
{
	new age = Lineage_GetAge(playerid);

	if (age <= s_LineageAge[playerid])
	{
		return;
	}

	s_LineageAge[playerid] = age;
	s_LineageClock[playerid] = min(s_LineageClock[playerid],Creator_LifeClockAt(age,Character_GetAttribute(playerid,_:ATTR_WILLPOWER)) + s_LineageBonus[playerid]);
	Lineage_Persist(playerid);
	Lineage_ShowMark(playerid);
	Gui_Notify(playerid,sprintf("Another year has passed. You're %d now.",age));
	pawn_call_public("Lineage_OnBirthday","dd",playerid,age);
}

static Lineage_NearestChapel(Float:x,Float:y)
{
	new best = 0, Float:bestDistance = 0.0;

	for (new i = 0;i < sizeof(s_LineageChapels);i++)
	{
		new Float:distance = VectorSize(s_LineageChapels[i][0] - x,s_LineageChapels[i][1] - y,0.0);

		if (i == 0 || distance < bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock bool:Lineage_HasLastRites(playerid)
{
	return Lineage_IsLoaded(playerid) && s_LineageRites[playerid];
}

stock bool:Lineage_SetLastRites(playerid,bool:isAnointed)
{
	if (!Lineage_IsLoaded(playerid))
	{
		return false;
	}

	s_LineageRites[playerid] = isAnointed;
	mysql_tquery_s(g_Mysql,str_format("UPDATE characters SET last_rites = %d WHERE id = %d",_:isAnointed,Character_GetId(playerid)));
	Lineage_ShowMark(playerid);
	return true;
}

stock bool:Lineage_SetLifeClock(playerid,clock)
{
	if (!Lineage_IsLoaded(playerid))
	{
		return false;
	}

	s_LineageClock[playerid] = max(clock,0);
	Lineage_Persist(playerid);
	Lineage_ShowMark(playerid);
	return true;
}

stock bool:Lineage_Retire(playerid)
{
	if (!Lineage_IsMarked(playerid) || !Session_IsPlaying(playerid))
	{
		return false;
	}

	SetTimerEx("Lineage_RetireDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
	return true;
}

static Lineage_DieForGood(playerid,const cause[],bool:isRetired = false)
{
	yield 1;

	new token = Account_GetToken(playerid), characterid = Character_GetId(playerid), age = Lineage_GetAge(playerid), slot = Character_GetSlot(playerid), coin = Economy_Worth(playerid), name[CHARACTER_NAME_MAX * 2 + 2];
	Character_GetName(playerid,name);
	Session_SetState(playerid,SESSION_DECEASED);
	Character_SetAlive(playerid,false);
	s_LineageClock[playerid] = 0;
	mysql_tquery_s(g_Mysql,str_format("UPDATE characters SET alive = 0, slot = NULL, life_clock = 0, died_at = NOW(), death_cause = '%e', died_age = %d, died_day = %d, retired = %d WHERE id = %d",cause,age,Lineage_Today(),_:isRetired,characterid));
	Family_SettleEstate(characterid,coin,isRetired);
	pawn_call_public("Lineage_OnDeceased","d",characterid);
	Log_Info("lineage","character %d (%s) %s at %d: %s",characterid,name,isRetired ? ("retired") : ("died for good"),age,cause);

	if (!isRetired)
	{
		await task_ms(LINEAGE_FAREWELL_MS);
	}

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	new text[320];

	if (isRetired)
	{
		format(text,sizeof(text),"~y~%s~w~ lays down their work at %d years old and lives out their days in peace.~n~~n~Their story ends here. The slot is free for a new character, and they rest in the ~y~Graveyard~w~ on your character list.",name,age);
		Gui_ShowMessage(playerid,"At rest",text,"Continue",300.0);
	}
	else
	{
		format(text,sizeof(text),"~y~%s~w~ died at %d years old. Their life clock was spent, so this death is the last.~n~~n~Their story ends here. The slot is free for a new character, and they rest in the ~y~Graveyard~w~ on your character list.",name,age);
		Gui_ShowMessage(playerid,"A life ends",text,"Continue",300.0);
	}

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	new heirid = FamilyGui_OfferHeir(playerid,characterid,slot);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	Character_Unload(playerid);

	if (heirid > 0)
	{
		Character_Load(playerid,heirid);
		return;
	}

	Character_ShowSelect(playerid);
}

forward Lineage_OnDeath(playerid,remaining);

public Lineage_OnDeath(playerid,remaining)
{
	return 1;
}

forward Lineage_OnBirthday(playerid,age);

public Lineage_OnBirthday(playerid,age)
{
	return 1;
}

forward Lineage_OnDeceased(characterid);

public Lineage_OnDeceased(characterid)
{
	return 1;
}

forward Lineage_LoadDeferred(playerid,token);

public Lineage_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Lineage_Load(playerid,token);
	}

	return 1;
}

forward Lineage_OnAgeHeld(playerid,minutes);

public Lineage_OnAgeHeld(playerid,minutes)
{
	return 1;
}

forward Lineage_RetireDeferred(playerid,token);

public Lineage_RetireDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Lineage_IsMarked(playerid) && Session_IsPlaying(playerid))
	{
		Lineage_DieForGood(playerid,LINEAGE_RETIRED_CAUSE,true);
	}

	return 1;
}

forward Lineage_RespawnNotice(playerid,token);

public Lineage_RespawnNotice(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_IsPlaying(playerid))
	{
		Gui_Notify(playerid,"You come to at the chapel, weak and hungry.");
	}

	return 1;
}

forward Lineage_GraveyardDeferred(playerid,token);

public Lineage_GraveyardDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_GetState(playerid) == SESSION_CHARACTER_SELECT)
	{
		LineageGui_ShowGraveyard(playerid);
	}

	return 1;
}

forward Lineage_DieDeferred(playerid,token);

public Lineage_DieDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Lineage_DieForGood(playerid,s_LineageCause[playerid][0] != EOS ? s_LineageCause[playerid] : ("unknown"));
	}

	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:lifeclock(cmdid, playerid, params[])
{
	new targetid, clock;

	if (sscanf(params,"ui",targetid,clock) || !Lineage_SetLifeClock(targetid,clock))
	{
		Command_Usage(playerid,cmdid,"<player> <deaths left>");
		return 1;
	}

	SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("Life clock set to %d.",max(clock,0)));
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Lineage_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Lineage_Reset(playerid);
	SetTimerEx("Lineage_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Buff_Clear(playerid,LINEAGE_MARK_KEY);
	Lineage_Reset(playerid);
}

hook Character_OnSpawning(playerid)
{
	if (!s_LineageRespawn[playerid])
	{
		return;
	}

	s_LineageRespawn[playerid] = false;
	new chapel = Lineage_NearestChapel(s_LineageDeathPos[playerid][0],s_LineageDeathPos[playerid][1]);
	Character_SetNextSpawn(playerid,s_LineageChapels[chapel][0],s_LineageChapels[chapel][1],s_LineageChapels[chapel][2],s_LineageChapels[chapel][3],0,0);
	Needs_Set(playerid,NEED_HUNGER,LINEAGE_RESPAWN_NEED);
	Needs_Set(playerid,NEED_THIRST,LINEAGE_RESPAWN_NEED);
	Warmth_Set(playerid,0);
	SetTimerEx("Lineage_RespawnNotice",LINEAGE_RESPAWN_NOTICE_MS,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnGraveyard(playerid)
{
	SetTimerEx("Lineage_GraveyardDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Vitals_OnDepleted(playerid,const source[])
{
	strcopy(s_LineageCause[playerid],source[0] != EOS ? source : ("unknown"),LINEAGE_CAUSE_LEN);
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid

	if (IsPlayerNPC(playerid) || !Session_HasCharacter(playerid) || !Lineage_IsLoaded(playerid))
	{
		return;
	}

	if (s_LineageCause[playerid][0] == EOS)
	{
		Lineage_EngineCause(reason,s_LineageCause[playerid],LINEAGE_CAUSE_LEN);
	}

	if (s_LineageClock[playerid] <= 0)
	{
		SetTimerEx("Lineage_DieDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
		return;
	}

	s_LineageClock[playerid] = max(s_LineageClock[playerid] - Lineage_CauseCost(s_LineageCause[playerid]),0);
	s_LineageCause[playerid][0] = EOS;
	Lineage_Persist(playerid);

	if (s_LineageRites[playerid])
	{
		Lineage_SetLastRites(playerid,false);
	}

	Lineage_ShowMark(playerid);

	new Float:z, line[160];
	GetPlayerPos(playerid,s_LineageDeathPos[playerid][0],s_LineageDeathPos[playerid][1],z);
	s_LineageRespawn[playerid] = true;

	if (s_LineageClock[playerid] == 0)
	{
		strcopy(line,"Your life clock is spent. You're marked by death: the next time you die, you won't come back.");
	}
	else
	{
		format(line,sizeof(line),"Your life clock has %d %s left.",s_LineageClock[playerid],s_LineageClock[playerid] == 1 ? ("death") : ("deaths"));
	}

	Gui_Notify(playerid,line);

	pawn_call_public("Lineage_OnDeath","dd",playerid,s_LineageClock[playerid]);
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year

	foreach (new playerid : Player)
	{
		if (Lineage_IsLoaded(playerid))
		{
			Lineage_CheckBirthday(playerid);
		}
	}
}
