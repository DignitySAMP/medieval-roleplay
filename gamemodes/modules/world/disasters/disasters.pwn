static s_DisasterKind = -1;
static s_DisasterSeverity;
static s_DisasterStartsAt;
static s_DisasterEndsAt;
static s_DisasterSeason = -1;
static s_DisasterRow;
static bool:s_DisasterActive;
static s_DisasterMinutes;
static s_DisasterRolledSeason = -1;

forward Task:Disasters_Load();
forward Task:Disasters_InsertTask(kind,severity,startsAt,endsAt,season);

stock Disasters_GetKind()
{
	return s_DisasterKind;
}

stock bool:Disasters_IsActive(kind)
{
	return s_DisasterActive && s_DisasterKind == kind;
}

stock bool:Disasters_IsWarned()
{
	return s_DisasterKind != -1 && !s_DisasterActive;
}

stock Disasters_GetSeverity()
{
	return s_DisasterKind == -1 ? 0 : s_DisasterSeverity;
}

stock Disasters_GetStartsAt()
{
	return s_DisasterStartsAt;
}

stock Disasters_GetEndsAt()
{
	return s_DisasterEndsAt;
}

stock Disasters_GetName(kind,dest[],size = sizeof(dest))
{
	if (kind < 0 || kind >= DISASTER_KIND_COUNT)
	{
		strcopy(dest,"Nothing",size);
		return;
	}

	strcopy(dest,g_DisasterDefs[kind][E_DISASTER_DEF_NAME],size);
}

stock Disasters_FindKind(const key[])
{
	for (new kind = 0;kind < DISASTER_KIND_COUNT;kind++)
	{
		if (!strcmp(g_DisasterDefs[kind][E_DISASTER_DEF_KEY],key,true))
		{
			return kind;
		}
	}

	return -1;
}

stock Disasters_RollSeverity()
{
	new roll = random(10);
	return roll == 0 ? 3 : (roll <= 3 ? 2 : 1);
}

static Disasters_Apply(bool:isOn)
{
	if (!isOn)
	{
		Calendar_SetWeatherOverride(-1);
		Fire_SetConditions(0,0,0);
		Trader_SetScarcity(0);
		return;
	}

	switch (s_DisasterKind)
	{
		case DISASTER_STORM:
		{
			Calendar_SetWeatherOverride(DISASTERS_STORM_WEATHER,4.0 + float(s_DisasterSeverity));
			Fire_SetConditions(0,1 + s_DisasterSeverity,2);
		}
		case DISASTER_FLOOD:
		{
			Calendar_SetWeatherOverride(DISASTERS_FLOOD_WEATHER,3.0);
			Fire_SetConditions(0,0,4);
		}
		case DISASTER_DROUGHT:
		{
			Fire_SetConditions(1 + s_DisasterSeverity,0,0);
			Trader_SetScarcity(DISASTERS_SCARCITY_STEP * s_DisasterSeverity);
		}
	}
}

stock bool:Disasters_Schedule(kind,severity,leadMinutes,minutes)
{
	if (s_DisasterKind != -1 || kind < 0 || kind >= DISASTER_KIND_COUNT)
	{
		return false;
	}

	new now = gettime();
	s_DisasterKind = kind;
	s_DisasterSeverity = Util_ClampInt(severity,1,3);
	s_DisasterStartsAt = now + max(leadMinutes,0) * 60;
	s_DisasterEndsAt = kind == DISASTER_DROUGHT ? s_DisasterStartsAt + DISASTERS_DROUGHT_DAYS * (CALENDAR_DAY_REAL_MS + CALENDAR_NIGHT_REAL_MS) / 1000 : s_DisasterStartsAt + max(minutes,1) * 60;
	s_DisasterSeason = _:Calendar_GetSeason();
	s_DisasterActive = false;
	s_DisasterMinutes = 0;
	s_DisasterRow = 0;
	Disasters_Insert();

	if (leadMinutes > 0)
	{
		Crier_Announce(DISASTERS_CRIER_KIND,"Signs in the sky",g_DisasterDefs[kind][E_DISASTER_DEF_SIGNS]);
		pawn_call_public("Disasters_OnWarned","dd",kind,s_DisasterSeverity);
	}
	else
	{
		Disasters_Begin();
	}

	return true;
}

static Disasters_Insert()
{
	Disasters_InsertTask(s_DisasterKind,s_DisasterSeverity,s_DisasterStartsAt,s_DisasterEndsAt,s_DisasterSeason);
}

#pragma warning push
#pragma warning disable 204
async Task:Disasters_InsertTask(kind,severity,startsAt,endsAt,season)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO disasters (kind, county_id, starts_at, ends_at, severity, season, ended) VALUES (%d, %d, %d, %d, %d, %d, 0)",kind,REALM_COUNTY,startsAt,endsAt,severity,season));

	if (s_DisasterKind == kind && s_DisasterStartsAt == startsAt)
	{
		s_DisasterRow = cache_insert_id();
	}

	return async s_DisasterRow;
}
#pragma warning pop

stock Disasters_Begin(bool:isQuiet = false)
{
	if (s_DisasterKind == -1 || s_DisasterActive)
	{
		return;
	}

	s_DisasterActive = true;
	Disasters_Apply(true);

	if (!isQuiet)
	{
		Crier_Announce(DISASTERS_CRIER_KIND,g_DisasterDefs[s_DisasterKind][E_DISASTER_DEF_NAME],g_DisasterDefs[s_DisasterKind][E_DISASTER_DEF_BEGINS]);
	}

	pawn_call_public("Disasters_OnBegin","dd",s_DisasterKind,s_DisasterSeverity);
}

stock Disasters_End()
{
	if (s_DisasterKind == -1)
	{
		return;
	}

	new kind = s_DisasterKind;

	if (s_DisasterActive)
	{
		Disasters_Apply(false);
		Crier_Announce(DISASTERS_CRIER_KIND,"It has passed",g_DisasterDefs[kind][E_DISASTER_DEF_ENDS]);
	}

	if (s_DisasterRow > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE disasters SET ends_at = %d, ended = 1 WHERE id = %d",gettime(),s_DisasterRow));
	}
	else
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE disasters SET ended = 1 WHERE kind = %d AND starts_at = %d",kind,s_DisasterStartsAt));
	}

	s_DisasterKind = -1;
	s_DisasterActive = false;
	s_DisasterRow = 0;
	s_DisasterEndsAt = 0;
	pawn_call_public("Disasters_OnEnd","d",kind);
}

stock Disasters_Strike()
{
	new start = random(FIRE_SEED_BUILDINGS);

	for (new i = 0;i < FIRE_SEED_BUILDINGS;i++)
	{
		new building = (start + i) % FIRE_SEED_BUILDINGS;

		if (Fire_GetState(building) != FIRE_STATE_SOUND || !Fire_Start(building,FIRE_CAUSE_LIGHTNING))
		{
			continue;
		}

		new name[28];
		Fire_GetName(building,name);

		foreach (new playerid : Player)
		{
			if (Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,250.0,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2]))
			{
				Gui_Notify(playerid,sprintf("Lightning strikes %s. The thatch is smoking.",name));
			}
		}

		return building;
	}

	return -1;
}

stock Disasters_Sicken()
{
	new count = 0;

	foreach (new playerid : Player)
	{
		if (!Session_IsPlaying(playerid) || IsPlayerNPC(playerid))
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);

		if (!Realm_InTown(x,y) || random(1000) >= DISASTERS_SICK_PERMILLE * s_DisasterSeverity)
		{
			continue;
		}

		new ailment = s_DisasterSeverity == 3 && random(4) == 0 ? AILMENT_PLAGUE : (random(2) == 0 ? AILMENT_FLUX : AILMENT_FEVER);

		if (Ailment_Give(playerid,ailment,"pestilence"))
		{
			count++;
		}
	}

	return count;
}

stock Disasters_Step()
{
	if (s_DisasterKind == -1)
	{
		return;
	}

	new now = gettime();

	if (!s_DisasterActive && now >= s_DisasterStartsAt)
	{
		Disasters_Begin();
	}

	if (!s_DisasterActive)
	{
		return;
	}

	if ((s_DisasterEndsAt != 0 && now >= s_DisasterEndsAt) || (s_DisasterKind == DISASTER_DROUGHT && _:Calendar_GetSeason() != s_DisasterSeason))
	{
		Disasters_End();
		return;
	}

	s_DisasterMinutes++;

	switch (s_DisasterKind)
	{
		case DISASTER_STORM:
		{
			if (random(100) < DISASTERS_LIGHTNING_PERCENT + s_DisasterSeverity)
			{
				Disasters_Strike();
			}
		}
		case DISASTER_PESTILENCE:
		{
			if (s_DisasterMinutes % DISASTERS_SICK_EVERY == 0)
			{
				Disasters_Sicken();
			}
		}
	}
}

stock Disasters_Roll()
{
	if (s_DisasterKind != -1)
	{
		return -1;
	}

	new season = _:Calendar_GetSeason(), bool:firstDawn = season != s_DisasterRolledSeason;
	s_DisasterRolledSeason = season;

	for (new kind = 0;kind < DISASTER_KIND_COUNT;kind++)
	{
		if ((kind == DISASTER_DROUGHT && !firstDawn) || random(1000) >= g_DisasterDefs[kind][E_DISASTER_DEF_ODDS][season])
		{
			continue;
		}

		new minutes = g_DisasterDefs[kind][E_DISASTER_DEF_MIN_MINUTES] + random(max(g_DisasterDefs[kind][E_DISASTER_DEF_MAX_MINUTES] - g_DisasterDefs[kind][E_DISASTER_DEF_MIN_MINUTES],0) + 1);
		Disasters_Schedule(kind,Disasters_RollSeverity(),DISASTERS_WARN_MINUTES,minutes);
		return kind;
	}

	return -1;
}

#pragma warning push
#pragma warning disable 204
async Task:Disasters_Load()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, starts_at, ends_at, severity, season FROM disasters WHERE ended = 0 ORDER BY id DESC LIMIT 1"));

	if (cache_num_rows() == 0)
	{
		return async -1;
	}

	new id, kind, startsAt, endsAt, severity, season;
	cache_get_value_name_int(0,"id",id);
	cache_get_value_name_int(0,"kind",kind);
	cache_get_value_name_int(0,"starts_at",startsAt);
	cache_get_value_name_int(0,"ends_at",endsAt);
	cache_get_value_name_int(0,"severity",severity);
	cache_get_value_name_int(0,"season",season);

	if (kind < 0 || kind >= DISASTER_KIND_COUNT || (endsAt != 0 && gettime() >= endsAt))
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE disasters SET ended = 1 WHERE id = %d",id));
		return async -1;
	}

	s_DisasterKind = kind;
	s_DisasterSeverity = Util_ClampInt(severity,1,3);
	s_DisasterStartsAt = startsAt;
	s_DisasterEndsAt = endsAt;
	s_DisasterSeason = season;
	s_DisasterRow = id;
	s_DisasterActive = false;

	if (gettime() >= startsAt)
	{
		Disasters_Begin(true);
	}

	return async kind;
}
#pragma warning pop

Timer_Declare(Disasters_Tick)
{
	Disasters_Step();
	return 1;
}

forward Disasters_OnWarned(kind,severity);

public Disasters_OnWarned(kind,severity)
{
	return 1;
}

forward Disasters_OnBegin(kind,severity);

public Disasters_OnBegin(kind,severity)
{
	return 1;
}

forward Disasters_OnEnd(kind);

public Disasters_OnEnd(kind)
{
	return 1;
}

#include <pp-hooks>

hook Calendar_OnDawn()
{
	Disasters_Roll();
}
