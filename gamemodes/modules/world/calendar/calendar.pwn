#define CALENDAR_DAYS_PER_MONTH (30)
#define CALENDAR_MONTHS (12)
#define CALENDAR_EPOCH_YEAR (1200)
#define CALENDAR_DAWN_HOUR (6)
#define CALENDAR_DUSK_HOUR (20)
#define CALENDAR_DAY_REAL_MS (180 * 60 * 1000)
#define CALENDAR_NIGHT_REAL_MS (120 * 60 * 1000)
#define CALENDAR_DAY_MS_PER_MINUTE (CALENDAR_DAY_REAL_MS / ((CALENDAR_DUSK_HOUR - CALENDAR_DAWN_HOUR) * 60))
#define CALENDAR_NIGHT_MS_PER_MINUTE (CALENDAR_NIGHT_REAL_MS / ((24 - CALENDAR_DUSK_HOUR + CALENDAR_DAWN_HOUR) * 60))
#define CALENDAR_TICK_MS (1000)
#define CALENDAR_PERSIST_MS (250)
#define CALENDAR_SYNODIC_CENTI (2953)
#define CALENDAR_SKY_SUNRISE (6 * 60)
#define CALENDAR_SKY_SUNSET (20 * 60 + 30)
#define CALENDAR_MOON_PHASES (8)
#define CALENDAR_NAME_LEN (16)

enum E_SEASON
{
	SEASON_WINTER,
	SEASON_SPRING,
	SEASON_SUMMER,
	SEASON_AUTUMN,
	SEASON_COUNT,
}

enum E_MOON
{
	MOON_NEW,
	MOON_WAXING_CRESCENT,
	MOON_FIRST_QUARTER,
	MOON_WAXING_GIBBOUS,
	MOON_FULL,
	MOON_WANING_GIBBOUS,
	MOON_LAST_QUARTER,
	MOON_WANING_CRESCENT,
}

static const s_MonthNames[CALENDAR_MONTHS][CALENDAR_NAME_LEN] = {
	"Wolf", "Snow", "Lenten", "Egg", "Milk", "Hay", "Mead", "Grain", "Harvest", "Hunter's", "Frost", "Yule"
};

static const s_SeasonNames[_:SEASON_COUNT][CALENDAR_NAME_LEN] = {"Winter", "Spring", "Summer", "Autumn"};

static const s_MoonNames[CALENDAR_MOON_PHASES][CALENDAR_NAME_LEN] = {
	"new", "waxing crescent", "first quarter", "waxing gibbous", "full", "waning gibbous", "last quarter", "waning crescent"
};

static const Float:s_SeasonBase[_:SEASON_COUNT] = {-5.0, 10.0, 24.0, 12.0};

static const s_SeasonWeather[_:SEASON_COUNT] = {4, 2, 1, 7};

static const s_SeasonSunrise[_:SEASON_COUNT] = {8 * 60, 6 * 60 + 30, 5 * 60, 7 * 60};

static const s_SeasonSunset[_:SEASON_COUNT] = {16 * 60 + 30, 19 * 60, 21 * 60, 18 * 60};

enum E_CALENDAR
{
	E_CAL_DAY,
	E_CAL_MONTH,
	E_CAL_YEAR,
	E_CAL_MINUTE,
	E_CAL_CARRY_MS,
	E_MOON:E_CAL_MOON,
	bool:E_CAL_LOADED,
	bool:E_CAL_DIRTY,
	bool:E_CAL_PERSIST_PENDING,
}

static s_Calendar[E_CALENDAR];
static s_CalendarWeatherOverride = -1;
static Float:s_CalendarChill;
static s_CalendarTitleSuffix[16];

static const s_MoonSprites[CALENDAR_MOON_PHASES][24] = {
	"moon_new",
	"moon_waxing_crescent",
	"moon_first_quarter",
	"moon_waxing_gibbous",
	"moon_full",
	"moon_waning_gibbous",
	"moon_last_quarter",
	"moon_waning_crescent"
};

static const s_SeasonSprites[SEASON_COUNT][16] = {
	"season_winter",
	"season_spring",
	"season_summer",
	"season_autumn"
};

stock Calendar_GetDate(&day,&month,&year)
{
	day = s_Calendar[E_CAL_DAY];
	month = s_Calendar[E_CAL_MONTH];
	year = s_Calendar[E_CAL_YEAR];
}

stock Calendar_GetHour()
{
	return s_Calendar[E_CAL_MINUTE] / 60;
}

stock Calendar_GetMinuteOfDay()
{
	return s_Calendar[E_CAL_MINUTE];
}

stock bool:Calendar_IsNight()
{
	new hour = Calendar_GetHour();
	return hour < CALENDAR_DAWN_HOUR || hour >= CALENDAR_DUSK_HOUR;
}

stock E_SEASON:Calendar_GetSeason()
{
	return Calendar_SeasonOfMonth(s_Calendar[E_CAL_MONTH]);
}

stock E_SEASON:Calendar_SeasonOfMonth(month)
{
	switch (month)
	{
		case 12, 1, 2: return SEASON_WINTER;
		case 3, 4, 5: return SEASON_SPRING;
		case 6, 7, 8: return SEASON_SUMMER;
	}

	return SEASON_AUTUMN;
}

stock Calendar_SeasonName(E_SEASON:season,dest[],size = sizeof(dest))
{
	if (season < SEASON_WINTER || season >= SEASON_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_SeasonNames[_:season],size);
}

stock Calendar_MonthName(month,dest[],size = sizeof(dest))
{
	if (month < 1 || month > CALENDAR_MONTHS)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_MonthNames[month - 1],size);
}

stock Calendar_GetMoonName(dest[],size = sizeof(dest))
{
	format(dest,size,"%s Moon",s_MonthNames[s_Calendar[E_CAL_MONTH] - 1]);
}

stock Calendar_DaysSinceEpoch(day,month,year)
{
	return (year - CALENDAR_EPOCH_YEAR) * CALENDAR_MONTHS * CALENDAR_DAYS_PER_MONTH + (month - 1) * CALENDAR_DAYS_PER_MONTH + (day - 1);
}

stock Calendar_FormatDay(days,dest[],size = sizeof(dest))
{
	new perYear = CALENDAR_MONTHS * CALENDAR_DAYS_PER_MONTH, into = max(days,0) % perYear;
	format(dest,size,"%d %s %d",into % CALENDAR_DAYS_PER_MONTH + 1,s_MonthNames[into / CALENDAR_DAYS_PER_MONTH],CALENDAR_EPOCH_YEAR + max(days,0) / perYear);
}

stock E_MOON:Calendar_MoonOf(day,month,year)
{
	new centiDays = Calendar_DaysSinceEpoch(day,month,year) * 100;
	new into = centiDays % CALENDAR_SYNODIC_CENTI;
	new phase = (into * CALENDAR_MOON_PHASES * 2 + CALENDAR_SYNODIC_CENTI) / (CALENDAR_SYNODIC_CENTI * 2);
	return E_MOON:(phase % CALENDAR_MOON_PHASES);
}

stock E_MOON:Calendar_GetMoon()
{
	return s_Calendar[E_CAL_MOON];
}

stock Calendar_MoonPhaseName(E_MOON:moon,dest[],size = sizeof(dest))
{
	strcopy(dest,s_MoonNames[_:moon % CALENDAR_MOON_PHASES],size);
}

stock Float:Calendar_MoonCropFactor()
{
	switch (s_Calendar[E_CAL_MOON])
	{
		case MOON_FULL: return 1.5;
		case MOON_WAXING_CRESCENT, MOON_FIRST_QUARTER, MOON_WAXING_GIBBOUS: return 1.2;
		case MOON_WANING_GIBBOUS, MOON_LAST_QUARTER, MOON_WANING_CRESCENT: return 0.8;
		case MOON_NEW: return 1.0;
	}

	return 1.0;
}

stock Calendar_FormatDate(dest[],size = sizeof(dest))
{
	new season[CALENDAR_NAME_LEN];
	Calendar_SeasonName(Calendar_GetSeason(),season);
	format(dest,size,"%d %s %d, %02d:%02d - %s",s_Calendar[E_CAL_DAY],s_MonthNames[s_Calendar[E_CAL_MONTH] - 1],s_Calendar[E_CAL_YEAR],Calendar_GetHour(),s_Calendar[E_CAL_MINUTE] % 60,season);
}

stock Float:Calendar_GetTemperature(Float:x,Float:y,Float:z,interior)
{
	#pragma unused x, y

	new Float:celsius = s_SeasonBase[_:Calendar_GetSeason()];
	new hour = Calendar_GetHour();

	if (hour >= 12 && hour < 15)
	{
		celsius += 4.0;
	}
	else if (hour >= 22 || hour < 5)
	{
		celsius -= 6.0;
	}
	else if (Calendar_IsNight())
	{
		celsius -= 3.0;
	}

	if (Calendar_GetSeason() == SEASON_WINTER)
	{
		celsius -= 2.0;
	}

	if (z > 300.0)
	{
		celsius -= (z - 300.0) / 100.0;
	}

	if (interior == 0)
	{
		celsius -= s_CalendarChill;
	}

	if (interior != 0)
	{
		celsius = Util_Clamp(celsius,12.0,18.0);
	}

	return celsius;
}

stock Calendar_GetSkyMinute()
{
	new season = _:Calendar_GetSeason(), sunrise = s_SeasonSunrise[season], sunset = s_SeasonSunset[season], minute = s_Calendar[E_CAL_MINUTE];

	if (minute >= sunrise && minute < sunset)
	{
		return CALENDAR_SKY_SUNRISE + (minute - sunrise) * (CALENDAR_SKY_SUNSET - CALENDAR_SKY_SUNRISE) / (sunset - sunrise);
	}

	new sinceSunset = (minute - sunset + 1440) % 1440;
	return (CALENDAR_SKY_SUNSET + sinceSunset * (1440 - CALENDAR_SKY_SUNSET + CALENDAR_SKY_SUNRISE) / (1440 - sunset + sunrise)) % 1440;
}

stock Calendar_GetWeather()
{
	return s_CalendarWeatherOverride != -1 ? s_CalendarWeatherOverride : s_SeasonWeather[_:Calendar_GetSeason()];
}

stock Calendar_SetWeatherOverride(weather,Float:chill = 0.0)
{
	s_CalendarWeatherOverride = weather;
	s_CalendarChill = weather == -1 ? 0.0 : chill;
	Calendar_ApplyWorld();
}

stock Calendar_GetWeatherOverride()
{
	return s_CalendarWeatherOverride;
}

stock Calendar_ApplyPlayer(playerid)
{
	if (!IsPlayerConnected(playerid) || Scene_IsActive(playerid))
	{
		return;
	}

	new sky = Calendar_GetSkyMinute();
	SetPlayerTime(playerid,sky / 60,sky % 60);
	SetPlayerWeather(playerid,Calendar_GetWeather());
}

static Calendar_ApplyWorld()
{
	foreach (new playerid : Player)
	{
		Calendar_ApplyPlayer(playerid);
	}

	Hud_SetDisc(HUD_DISC_MOON,s_MoonSprites[_:s_Calendar[E_CAL_MOON]]);
	Hud_SetDisc(HUD_DISC_SEASON,s_SeasonSprites[Calendar_GetSeason()]);

	new line[64];
	Calendar_FormatDate(line);

	if (s_CalendarTitleSuffix[0] != EOS)
	{
		strcat(line,", ");
		strcat(line,s_CalendarTitleSuffix);
	}

	Hud_SetTitle(line);
}

stock Calendar_SetTitleSuffix(const suffix[])
{
	strcopy(s_CalendarTitleSuffix,suffix);
	Calendar_ApplyWorld();
}

static Calendar_Persist()
{
	if (!s_Calendar[E_CAL_LOADED] || !IsDatabaseReady() || s_Calendar[E_CAL_PERSIST_PENDING])
	{
		return;
	}

	s_Calendar[E_CAL_PERSIST_PENDING] = true;
	SetTimer("Calendar_PersistNow",CALENDAR_PERSIST_MS,false);
}

forward Calendar_PersistNow();

public Calendar_PersistNow()
{
	s_Calendar[E_CAL_PERSIST_PENDING] = false;
	if (!s_Calendar[E_CAL_LOADED] || !IsDatabaseReady())
	{
		return 1;
	}

	s_Calendar[E_CAL_DIRTY] = false;
	mysql_tquery_s(g_Mysql,str_format("UPDATE world_calendar SET day = %d, month = %d, year = %d, minute_of_day = %d WHERE id = 1",s_Calendar[E_CAL_DAY],s_Calendar[E_CAL_MONTH],s_Calendar[E_CAL_YEAR],s_Calendar[E_CAL_MINUTE]));
	return 1;
}

static Calendar_RefreshMoon()
{
	new E_MOON:moon = Calendar_MoonOf(s_Calendar[E_CAL_DAY],s_Calendar[E_CAL_MONTH],s_Calendar[E_CAL_YEAR]);
	if (moon != s_Calendar[E_CAL_MOON])
	{
		s_Calendar[E_CAL_MOON] = moon;
		new name[CALENDAR_NAME_LEN + 6];
		Calendar_GetMoonName(name);
		pawn_call_public("Calendar_OnMoonPhase","ds",_:moon,name);
	}
}

static Calendar_AdvanceDay()
{
	new E_SEASON:before = Calendar_GetSeason();
	if (++s_Calendar[E_CAL_DAY] > CALENDAR_DAYS_PER_MONTH)
	{
		s_Calendar[E_CAL_DAY] = 1;
		if (++s_Calendar[E_CAL_MONTH] > CALENDAR_MONTHS)
		{
			s_Calendar[E_CAL_MONTH] = 1;
			s_Calendar[E_CAL_YEAR]++;
		}
	}

	pawn_call_public("Calendar_OnDay","ddd",s_Calendar[E_CAL_DAY],s_Calendar[E_CAL_MONTH],s_Calendar[E_CAL_YEAR]);
	Calendar_RefreshMoon();

	if (Calendar_GetSeason() != before)
	{
		pawn_call_public("Calendar_OnSeason","d",_:Calendar_GetSeason());
	}
}

stock Calendar_AdvanceMinutes(minutes)
{
	while (minutes-- > 0)
	{
		new hourBefore = Calendar_GetHour();
		if (++s_Calendar[E_CAL_MINUTE] >= 24 * 60)
		{
			s_Calendar[E_CAL_MINUTE] = 0;
			Calendar_AdvanceDay();
		}

		new hour = Calendar_GetHour();
		if (hour != hourBefore)
		{
			pawn_call_public("Calendar_OnHour","d",hour);
			if (hour == CALENDAR_DUSK_HOUR)
			{
				pawn_call_public("Calendar_OnNightfall","");
			}
			else if (hour == CALENDAR_DAWN_HOUR)
			{
				pawn_call_public("Calendar_OnDawn","");
			}

			s_Calendar[E_CAL_DIRTY] = true;
		}
	}

	Calendar_ApplyWorld();
	if (s_Calendar[E_CAL_DIRTY])
	{
		Calendar_Persist();
	}
}

stock bool:Calendar_SetDate(day,month,year,minuteOfDay)
{
	if (day < 1 || day > CALENDAR_DAYS_PER_MONTH || month < 1 || month > CALENDAR_MONTHS || year < CALENDAR_EPOCH_YEAR || minuteOfDay < 0 || minuteOfDay >= 24 * 60)
	{
		return false;
	}

	s_Calendar[E_CAL_DAY] = day;
	s_Calendar[E_CAL_MONTH] = month;
	s_Calendar[E_CAL_YEAR] = year;
	s_Calendar[E_CAL_MINUTE] = minuteOfDay;
	s_Calendar[E_CAL_CARRY_MS] = 0;
	s_Calendar[E_CAL_DIRTY] = true;
	Calendar_RefreshMoon();
	Calendar_ApplyWorld();
	Calendar_Persist();
	pawn_call_public("Calendar_OnSet","");
	return true;
}

stock Calendar_MsPerMinute()
{
	return Calendar_IsNight() ? CALENDAR_NIGHT_MS_PER_MINUTE : CALENDAR_DAY_MS_PER_MINUTE;
}

Timer_Declare(Calendar_Tick)
{
	if (!s_Calendar[E_CAL_LOADED])
	{
		return 1;
	}

	s_Calendar[E_CAL_CARRY_MS] += CALENDAR_TICK_MS;
	new minutes = 0;
	while (s_Calendar[E_CAL_CARRY_MS] >= Calendar_MsPerMinute())
	{
		s_Calendar[E_CAL_CARRY_MS] -= Calendar_MsPerMinute();
		minutes++;
	}

	if (minutes > 0)
	{
		Calendar_AdvanceMinutes(minutes);
	}

	return 1;
}

forward Calendar_LoadOnBoot();

public Calendar_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT day, month, year, minute_of_day FROM world_calendar WHERE id = 1"));

	if (cache_num_rows() == 0)
	{
		s_Calendar[E_CAL_DAY] = 1;
		s_Calendar[E_CAL_MONTH] = 1;
		s_Calendar[E_CAL_YEAR] = CALENDAR_EPOCH_YEAR;
		s_Calendar[E_CAL_MINUTE] = CALENDAR_DAWN_HOUR * 60;
		await mysql_aquery_s(g_Mysql,str_format("INSERT INTO world_calendar (id, day, month, year, minute_of_day) VALUES (1, %d, %d, %d, %d)",s_Calendar[E_CAL_DAY],s_Calendar[E_CAL_MONTH],s_Calendar[E_CAL_YEAR],s_Calendar[E_CAL_MINUTE]));
	}
	else
	{
		cache_get_value_name_int(0,"day",s_Calendar[E_CAL_DAY]);
		cache_get_value_name_int(0,"month",s_Calendar[E_CAL_MONTH]);
		cache_get_value_name_int(0,"year",s_Calendar[E_CAL_YEAR]);
		cache_get_value_name_int(0,"minute_of_day",s_Calendar[E_CAL_MINUTE]);
	}

	s_Calendar[E_CAL_LOADED] = true;
	s_Calendar[E_CAL_MOON] = E_MOON:-1;
	Calendar_RefreshMoon();
	Calendar_ApplyWorld();

	new line[64];
	Calendar_FormatDate(line);
	Log_Info("calendar","%s",line);
	Boot_LoaderDone();
}

stock bool:Calendar_IsLoaded()
{
	return s_Calendar[E_CAL_LOADED];
}

forward Calendar_OnSet();
public Calendar_OnSet() { return 1; }

forward Calendar_OnHour(hour);
public Calendar_OnHour(hour) { return 1; }

forward Calendar_OnDay(day,month,year);
public Calendar_OnDay(day,month,year) { return 1; }

forward Calendar_OnSeason(season);
public Calendar_OnSeason(season) { return 1; }

forward Calendar_OnMoonPhase(phase,const name[]);
public Calendar_OnMoonPhase(phase,const name[]) { return 1; }

forward Calendar_OnNightfall();
public Calendar_OnNightfall() { return 1; }

forward Calendar_OnDawn();
public Calendar_OnDawn() { return 1; }

CMD:setdate(cmdid, playerid, params[])
{
	new day, month, year, hour, minute;
	if (sscanf(params,"iiiiI(0)",day,month,year,hour,minute) || minute < 0 || minute > 59 || !Calendar_SetDate(day,month,year,hour * 60 + minute))
	{
		Command_Usage(playerid,cmdid,"<day 1-30> <month 1-12> <year> <hour 0-23> [minute 0-59]");
		return 1;
	}

	new line[64];
	Calendar_FormatDate(line);
	SendClientMessage(playerid,-1,line);
	return 1;
}

CMD:skiphours(cmdid, playerid, params[])
{
	new hours;
	if (sscanf(params,"i",hours) || hours < 1 || hours > 24 * 30)
	{
		Command_Usage(playerid,cmdid,"<1..720>");
		return 1;
	}

	Calendar_AdvanceMinutes(hours * 60);
	new line[64];
	Calendar_FormatDate(line);
	SendClientMessage(playerid,-1,line);
	return 1;
}
