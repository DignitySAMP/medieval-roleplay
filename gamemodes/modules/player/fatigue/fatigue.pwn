#define FATIGUE_MAX (100.0)
#define FATIGUE_TIRED (50.0)
#define FATIGUE_EXHAUSTED (80.0)
#define FATIGUE_HOUR_DAY (2.5)
#define FATIGUE_HOUR_NIGHT (3.5)
#define FATIGUE_HOUR_RIDING (1.0)
#define FATIGUE_WORK (3.0)
#define FATIGUE_BLOW (0.5)
#define FATIGUE_BLOWS_PER_HOUR (6)
#define FATIGUE_SIT (2.0)
#define FATIGUE_HEAT (2.0)
#define FATIGUE_INN (1.0)
#define FATIGUE_MEAL (3.0)
#define FATIGUE_REST_TICK_MS (60000)
#define FATIGUE_SLEEP_AFTER_MS (8000)
#define FATIGUE_ROUGH_AFTER_MS (30000)
#define FATIGUE_FADE_MS (2500)
#define FATIGUE_CAP_TIRED (85.0)
#define FATIGUE_CAP_EXHAUSTED (70.0)
#define FATIGUE_BAND_TIRED (90)
#define FATIGUE_BAND_EXHAUSTED (80)
#define FATIGUE_ILL_PERCENT (1)
#define FATIGUE_AWAY_SECONDS (3600)

enum
{
	FATIGUE_RESTED,
	FATIGUE_BAND_TIRED_ID,
	FATIGUE_BAND_EXHAUSTED_ID,
}

enum
{
	FATIGUE_BED_OWN,
	FATIGUE_BED_GUEST,
	FATIGUE_BED_STRAW,
	FATIGUE_BED_GROUND,
}

new const Float:g_FatigueBedFloor[4] = {0.0, 10.0, 25.0, 40.0};
new const g_FatigueBedNames[4][16] = {"your own bed", "a borrowed bed", "the straw", "the bare ground"};

enum E_FATIGUE
{
	bool:E_FATIGUE_LOADED,
	Float:E_FATIGUE_VALUE,
	E_FATIGUE_BAND,
	E_FATIGUE_LYING_AT,
	E_FATIGUE_LYING_BED,
	bool:E_FATIGUE_LYING_OWN,
	bool:E_FATIGUE_SLEPT,
	E_FATIGUE_BLOWS,
	E_FATIGUE_REST_AT,
}

static s_Fatigue[MAX_PLAYERS][E_FATIGUE];

stock bool:Fatigue_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Fatigue[playerid][E_FATIGUE_LOADED];
}

stock Float:Fatigue_Get(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Fatigue[playerid][E_FATIGUE_VALUE] : 0.0;
}

stock Fatigue_BandOf(Float:value)
{
	if (value >= FATIGUE_EXHAUSTED)
	{
		return FATIGUE_BAND_EXHAUSTED_ID;
	}

	return value >= FATIGUE_TIRED ? FATIGUE_BAND_TIRED_ID : FATIGUE_RESTED;
}

stock Fatigue_GetBand(playerid)
{
	return Fatigue_BandOf(Fatigue_Get(playerid));
}

stock Float:Fatigue_HourGain(bool:night,bool:riding)
{
	return (night ? FATIGUE_HOUR_NIGHT : FATIGUE_HOUR_DAY) + (riding ? FATIGUE_HOUR_RIDING : 0.0);
}

stock Float:Fatigue_SleepFloor(bed,bool:coldOrWet)
{
	new Float:floor = g_FatigueBedFloor[Util_ClampInt(bed,FATIGUE_BED_OWN,FATIGUE_BED_GROUND)];

	if (coldOrWet && bed >= FATIGUE_BED_STRAW)
	{
		floor += 10.0;
	}

	return floor;
}

stock Fatigue_Describe(playerid,dest[],size = sizeof(dest))
{
	switch (Fatigue_GetBand(playerid))
	{
		case FATIGUE_BAND_EXHAUSTED_ID: strcopy(dest,"exhausted: rest by a fire, or sleep",size);
		case FATIGUE_BAND_TIRED_ID: strcopy(dest,"tired: a sit by the fire or a bed would help",size);
		default: strcopy(dest,"rested",size);
	}
}

static Fatigue_Apply(playerid)
{
	new band = Fatigue_GetBand(playerid), old = s_Fatigue[playerid][E_FATIGUE_BAND];

	switch (band)
	{
		case FATIGUE_BAND_EXHAUSTED_ID:
		{
			Vitals_SetStaminaFatigueCap(playerid,FATIGUE_CAP_EXHAUSTED);
			Work_SetBandScale(playerid,FATIGUE_BAND_EXHAUSTED);
			Buff_Set(playerid,"fatigue","Exhausted","Less stamina, clumsier work and a chance to fall ill. Rest by a fire or sleep in a bed.");
		}
		case FATIGUE_BAND_TIRED_ID:
		{
			Vitals_SetStaminaFatigueCap(playerid,FATIGUE_CAP_TIRED);
			Work_SetBandScale(playerid,FATIGUE_BAND_TIRED);
			Buff_Set(playerid,"fatigue","Tired","A little less stamina and a little clumsier at work. Sit down, eat, or sleep.");
		}
		default:
		{
			Vitals_SetStaminaFatigueCap(playerid,VITALS_MAX);
			Work_SetBandScale(playerid,100);
			Buff_Clear(playerid,"fatigue");
		}
	}

	if (band != old)
	{
		s_Fatigue[playerid][E_FATIGUE_BAND] = band;
		pawn_call_public("Fatigue_OnBand","ddd",playerid,old,band);

		if (band > old)
		{
			Gui_Notify(playerid,band == FATIGUE_BAND_EXHAUSTED_ID ? ("You're bone tired. A bed, a fire or a sit would do you good.") : ("You're getting tired. A sit or a meal helps; a bed helps most."));
		}
	}
}

stock Fatigue_Set(playerid,Float:value)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Fatigue[playerid][E_FATIGUE_VALUE] = Util_Clamp(value,0.0,FATIGUE_MAX);
	Fatigue_Apply(playerid);
}

stock Fatigue_Add(playerid,Float:amount)
{
	if (Fatigue_IsLoaded(playerid))
	{
		Fatigue_Set(playerid,s_Fatigue[playerid][E_FATIGUE_VALUE] + amount);
	}
}

stock Fatigue_Save(playerid)
{
	new characterid = Character_GetId(playerid);

	if (!Fatigue_IsLoaded(playerid) || characterid <= 0)
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO character_fatigue (character_id, fatigue, updated_at) VALUES (%d, %f, %d) ON DUPLICATE KEY UPDATE fatigue = VALUES(fatigue), updated_at = VALUES(updated_at)",characterid,s_Fatigue[playerid][E_FATIGUE_VALUE],gettime()));
}

forward Task:Fatigue_Load(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Fatigue_Load(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT fatigue, updated_at FROM character_fatigue WHERE character_id = %d",characterid));
	new Float:value = 0.0, updated = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_float(0,"fatigue",value);
		cache_get_value_name_int(0,"updated_at",updated);
	}

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	if (updated > 0 && gettime() - updated >= FATIGUE_AWAY_SECONDS)
	{
		value = 0.0;
	}

	s_Fatigue[playerid][E_FATIGUE_LOADED] = true;
	s_Fatigue[playerid][E_FATIGUE_BAND] = FATIGUE_RESTED;
	Fatigue_Set(playerid,value);
	return async 1;
}
#pragma warning pop

static bool:Fatigue_AnimIs(playerid,const lib[],const name[] = "")
{
	new animlib[32], animname[32];
	GetAnimationName(GetPlayerAnimationIndex(playerid),animlib,sizeof(animlib),animname,sizeof(animname));

	if (strcmp(animlib,lib,true) != 0)
	{
		return false;
	}

	return name[0] == EOS || strfind(animname,name,true) != -1;
}

stock bool:Fatigue_IsSitting(playerid)
{
	return Fatigue_AnimIs(playerid,"PED","SEAT") || Fatigue_AnimIs(playerid,"BEACH","ParkSit") || Fatigue_AnimIs(playerid,"INT_HOUSE","LOU_") || Fatigue_AnimIs(playerid,"JST_BUISNESS","girl_02") || Fatigue_AnimIs(playerid,"FOOD","FF_Sit") || Fatigue_AnimIs(playerid,"INT_OFFICE","OFF_Sit") || Fatigue_AnimIs(playerid,"MISC","SEAT");
}

stock bool:Fatigue_IsLying(playerid)
{
	return Fatigue_AnimIs(playerid,"BEACH","bather") || Fatigue_AnimIs(playerid,"BEACH","Lay_Bac") || Fatigue_AnimIs(playerid,"INT_HOUSE","BED_") || Fatigue_AnimIs(playerid,"CRACK","crckidle");
}

stock Fatigue_Sleep(playerid,bed)
{
	new Float:x, Float:y, Float:z, interior = GetPlayerInterior(playerid);
	GetPlayerPos(playerid,x,y,z);
	new bool:cold = interior == 0 && (Calendar_GetTemperature(x,y,z,interior) < 5.0 || Weather_IsSnowing() || Calendar_GetWeather() == 8 || Calendar_GetWeather() == 16);
	new Float:floor = Fatigue_SleepFloor(bed,cold);

	s_Fatigue[playerid][E_FATIGUE_SLEPT] = true;
	ScreenFade_Set(playerid,0x000000FF);
	SetTimerEx("Fatigue_Wake",FATIGUE_FADE_MS,false,"ddfd",playerid,Character_GetId(playerid),floor,bed);

	if (bed <= FATIGUE_BED_GUEST)
	{
		Ailment_MarkRested(playerid);
	}

	pawn_call_public("Fatigue_OnSlept","dd",playerid,bed);
}

static Float:Fatigue_PlayerSpeed(playerid)
{
	new Float:vx, Float:vy, Float:vz;
	GetPlayerVelocity(playerid,vx,vy,vz);
	return VectorSize(vx,vy,vz) * 50.0;
}

static Fatigue_RestTick(playerid)
{
	new Float:x, Float:y, Float:z, Float:ease = 0.0, world = GetPlayerVirtualWorld(playerid);
	GetPlayerPos(playerid,x,y,z);

	if (Fatigue_IsSitting(playerid) || Fatigue_IsLying(playerid))
	{
		ease += FATIGUE_SIT;

		if (Light_IsHeatNear(x,y,z,world,4.0))
		{
			ease += FATIGUE_HEAT;
		}

		if (world != 0)
		{
			ease += FATIGUE_INN;
		}
	}
	else if (Light_IsHeatNear(x,y,z,world,3.0) && Fatigue_PlayerSpeed(playerid) < 0.5)
	{
		ease += FATIGUE_HEAT / 2.0;
	}

	if (ease > 0.0)
	{
		Fatigue_Add(playerid,-ease);
	}
}

Timer_Declare(Fatigue_Tick)
{
	new tick = GetTickCount();

	foreach (new playerid : Player)
	{
		if (!Fatigue_IsLoaded(playerid) || !Session_IsPlaying(playerid))
		{
			continue;
		}

		if (tick - s_Fatigue[playerid][E_FATIGUE_REST_AT] >= FATIGUE_REST_TICK_MS)
		{
			s_Fatigue[playerid][E_FATIGUE_REST_AT] = tick;
			Fatigue_RestTick(playerid);
		}

		new bool:lying = Fatigue_IsLying(playerid) || s_Fatigue[playerid][E_FATIGUE_LYING_BED] != -1;

		if (!lying)
		{
			s_Fatigue[playerid][E_FATIGUE_LYING_AT] = 0;
			s_Fatigue[playerid][E_FATIGUE_SLEPT] = false;
			continue;
		}

		if (s_Fatigue[playerid][E_FATIGUE_LYING_AT] == 0)
		{
			s_Fatigue[playerid][E_FATIGUE_LYING_AT] = tick;
		}

		if (s_Fatigue[playerid][E_FATIGUE_SLEPT] || Fatigue_GetBand(playerid) == FATIGUE_RESTED && Fatigue_Get(playerid) < 10.0)
		{
			continue;
		}

		new bed = s_Fatigue[playerid][E_FATIGUE_LYING_BED] != -1 ? (s_Fatigue[playerid][E_FATIGUE_LYING_OWN] ? FATIGUE_BED_OWN : FATIGUE_BED_GUEST) : FATIGUE_BED_GROUND;
		new after = bed <= FATIGUE_BED_GUEST ? FATIGUE_SLEEP_AFTER_MS : FATIGUE_ROUGH_AFTER_MS;

		if (tick - s_Fatigue[playerid][E_FATIGUE_LYING_AT] >= after)
		{
			Fatigue_Sleep(playerid,bed);
		}
	}

	return 1;
}

Timer_Declare(Fatigue_SaveTick)
{
	foreach (new playerid : Player)
	{
		Fatigue_Save(playerid);
	}

	return 1;
}

forward Fatigue_OnBand(playerid,oldBand,newBand);

public Fatigue_OnBand(playerid,oldBand,newBand)
{
	return 1;
}

forward Fatigue_OnSlept(playerid,bed);

public Fatigue_OnSlept(playerid,bed)
{
	return 1;
}

forward Fatigue_Wake(playerid,characterid,Float:floor,bed);

public Fatigue_Wake(playerid,characterid,Float:floor,bed)
{
	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return 1;
	}

	ScreenFade_Stop(playerid);

	if (Fatigue_Get(playerid) > floor)
	{
		Fatigue_Set(playerid,floor);
	}

	new where[16];
	strcopy(where,g_FatigueBedNames[Util_ClampInt(bed,FATIGUE_BED_OWN,FATIGUE_BED_GROUND)]);

	if (floor <= 10.0)
	{
		Gui_Notify(playerid,sprintf("You wake rested from %s.",where));
	}
	else
	{
		Gui_Notify(playerid,sprintf("You wake stiff from %s. A bed would have been better.",where));
	}

	Fatigue_Save(playerid);
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Fatigue[playerid][E_FATIGUE_LOADED] = false;
	s_Fatigue[playerid][E_FATIGUE_VALUE] = 0.0;
	s_Fatigue[playerid][E_FATIGUE_BAND] = FATIGUE_RESTED;
	s_Fatigue[playerid][E_FATIGUE_LYING_AT] = 0;
	s_Fatigue[playerid][E_FATIGUE_LYING_BED] = -1;
	s_Fatigue[playerid][E_FATIGUE_SLEPT] = false;
	s_Fatigue[playerid][E_FATIGUE_BLOWS] = 0;
	s_Fatigue[playerid][E_FATIGUE_REST_AT] = 0;
}

hook Character_OnLoaded(playerid,characterid)
{
	Fatigue_Load(playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Fatigue_Save(playerid);
	s_Fatigue[playerid][E_FATIGUE_LOADED] = false;
	Work_SetBandScale(playerid,100);
	Vitals_SetStaminaFatigueCap(playerid,VITALS_MAX);
	Buff_Clear(playerid,"fatigue");
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour

	new bool:night = Calendar_IsNight();

	foreach (new playerid : Player)
	{
		if (!Fatigue_IsLoaded(playerid) || !Session_IsPlaying(playerid) || s_Fatigue[playerid][E_FATIGUE_LYING_BED] != -1)
		{
			continue;
		}

		s_Fatigue[playerid][E_FATIGUE_BLOWS] = 0;
		Fatigue_Add(playerid,Fatigue_HourGain(night,Mount_IsRiding(playerid)));

		if (Fatigue_GetBand(playerid) == FATIGUE_BAND_EXHAUSTED_ID && random(100) < FATIGUE_ILL_PERCENT && !Ailment_Has(playerid,AILMENT_COLD))
		{
			Ailment_Give(playerid,AILMENT_COLD,"exhaustion");
		}
	}
}

hook Work_OnFinished(playerid,recipe,stars)
{
	#pragma unused recipe, stars
	Fatigue_Add(playerid,FATIGUE_WORK);
}

hook Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[])
{
	#pragma unused source

	if (after < before && s_Fatigue[playerid][E_FATIGUE_BLOWS] < FATIGUE_BLOWS_PER_HOUR)
	{
		s_Fatigue[playerid][E_FATIGUE_BLOWS]++;
		Fatigue_Add(playerid,FATIGUE_BLOW);
	}
}

hook Needs_OnFed(playerid,need,amount)
{
	#pragma unused need, amount
	Fatigue_Add(playerid,-FATIGUE_MEAL);
}

hook Houses_OnLieDown(playerid,bed,ownBed)
{
	s_Fatigue[playerid][E_FATIGUE_LYING_BED] = bed;
	s_Fatigue[playerid][E_FATIGUE_LYING_OWN] = ownBed != 0;
	s_Fatigue[playerid][E_FATIGUE_LYING_AT] = GetTickCount();
	s_Fatigue[playerid][E_FATIGUE_SLEPT] = false;
}

hook Houses_OnGetUp(playerid)
{
	s_Fatigue[playerid][E_FATIGUE_LYING_BED] = -1;
	s_Fatigue[playerid][E_FATIGUE_LYING_AT] = 0;
}
