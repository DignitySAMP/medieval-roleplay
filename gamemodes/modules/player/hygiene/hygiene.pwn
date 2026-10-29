#define HYGIENE_MAX (100)
#define HYGIENE_GRIMY (35)
#define HYGIENE_STINK (60)
#define HYGIENE_REEK (85)
#define HYGIENE_TIME_SECONDS (180)
#define HYGIENE_WORK (4)
#define HYGIENE_WOUND (3)
#define HYGIENE_PELTED (20)
#define HYGIENE_FLIES_MODEL (18698)
#define MODEL_HYGIENE_FLIES (-5329)
#define HYGIENE_FLIES_STINK (1)
#define HYGIENE_FLIES_MAX (3)
#define HYGIENE_FLIES_MS (250)
#define HYGIENE_FLIES_RANGE (60.0)
#define HYGIENE_CUE_STINK "{8DB05A}stinks"
#define HYGIENE_CUE_REEK "{8DB05A}reeks"
#define HYGIENE_TICK_MS (10000)
#define HYGIENE_SAVE_EVERY (6)

enum E_HYGIENE_LEVEL
{
	HYGIENE_LEVEL_CLEAN,
	HYGIENE_LEVEL_GRIMY,
	HYGIENE_LEVEL_STINKS,
	HYGIENE_LEVEL_REEKS,
}

new const g_HygieneLevelNames[E_HYGIENE_LEVEL][8] = {
	"clean",
	"grimy",
	"stinks",
	"reeks"
};

static s_HygieneDirt[MAX_PLAYERS];
static s_HygieneNextAt[MAX_PLAYERS];
static bool:s_HygieneLoaded[MAX_PLAYERS];
static bool:s_HygieneDirty[MAX_PLAYERS];
static STREAMER_TAG_OBJECT:s_HygieneFlies[MAX_PLAYERS][HYGIENE_FLIES_MAX];
static s_HygieneFliesCount[MAX_PLAYERS];

static const Float:s_HygieneFlySpots[HYGIENE_FLIES_MAX][3] = {
	{0.0, 0.0, 0.78},
	{0.08, -0.05, 0.6},
	{0.0, 0.0, -0.861}
};
static E_HYGIENE_LEVEL:s_HygieneShown[MAX_PLAYERS];
static s_HygieneSaveTicks;

stock Hygiene_GetDirt(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_HygieneDirt[playerid] : 0;
}

stock E_HYGIENE_LEVEL:Hygiene_LevelOf(dirt)
{
	if (dirt >= HYGIENE_REEK)
	{
		return HYGIENE_LEVEL_REEKS;
	}

	if (dirt >= HYGIENE_STINK)
	{
		return HYGIENE_LEVEL_STINKS;
	}

	return dirt >= HYGIENE_GRIMY ? HYGIENE_LEVEL_GRIMY : HYGIENE_LEVEL_CLEAN;
}

stock E_HYGIENE_LEVEL:Hygiene_GetLevel(playerid)
{
	return Hygiene_LevelOf(Hygiene_GetDirt(playerid));
}

stock Hygiene_IsStinking(playerid)
{
	return Hygiene_GetDirt(playerid) >= HYGIENE_STINK ? 1 : 0;
}

stock Hygiene_IsReeking(playerid)
{
	return Hygiene_GetDirt(playerid) >= HYGIENE_REEK ? 1 : 0;
}

stock Hygiene_Describe(playerid,dest[],size = sizeof(dest))
{
	switch (Hygiene_GetLevel(playerid))
	{
		case HYGIENE_LEVEL_CLEAN: strcopy(dest,"clean",size);
		case HYGIENE_LEVEL_GRIMY: strcopy(dest,"grimy: you could do with a wash",size);
		case HYGIENE_LEVEL_STINKS: strcopy(dest,"you stink, and people notice",size);
		default: strcopy(dest,"you reek: wash at a washtub",size);
	}
}

stock Hygiene_PriceFactor(playerid)
{
	switch (Hygiene_GetLevel(playerid))
	{
		case HYGIENE_LEVEL_STINKS: return 115;
		case HYGIENE_LEVEL_REEKS: return 130;
		default: return 100;
	}

	return 100;
}

static Hygiene_DropFlies(playerid)
{
	for (new i = 0;i < s_HygieneFliesCount[playerid];i++)
	{
		if (IsValidDynamicObject(s_HygieneFlies[playerid][i]))
		{
			DestroyDynamicObject(s_HygieneFlies[playerid][i]);
		}

		s_HygieneFlies[playerid][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	s_HygieneFliesCount[playerid] = 0;
}

static Hygiene_ShowFlies(playerid,count)
{
	if (count == s_HygieneFliesCount[playerid])
	{
		return;
	}

	Hygiene_DropFlies(playerid);

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new i = 0;i < count;i++)
	{
		s_HygieneFlies[playerid][i] = CreateDynamicObject(i < 2 ? MODEL_HYGIENE_FLIES : HYGIENE_FLIES_MODEL,x + s_HygieneFlySpots[i][0],y + s_HygieneFlySpots[i][1],z + s_HygieneFlySpots[i][2],0.0,0.0,0.0,-1,-1,-1,HYGIENE_FLIES_RANGE,HYGIENE_FLIES_RANGE);
	}

	s_HygieneFliesCount[playerid] = count;
	Nearby_StreamObjectsAt(x,y,z,GetPlayerVirtualWorld(playerid),-1,HYGIENE_FLIES_RANGE);
}

stock Hygiene_CountFlies(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_HygieneFliesCount[playerid] : 0;
}

static Hygiene_Show(playerid)
{
	new E_HYGIENE_LEVEL:level = Hygiene_GetLevel(playerid), E_HYGIENE_LEVEL:was = s_HygieneShown[playerid];

	if (level == was && (level < HYGIENE_LEVEL_STINKS || s_HygieneFliesCount[playerid] > 0))
	{
		return;
	}

	s_HygieneShown[playerid] = level;

	if (level >= HYGIENE_LEVEL_STINKS)
	{
		Nametag_SetCue(playerid,NAMETAG_CUE_STINK,level == HYGIENE_LEVEL_REEKS ? (HYGIENE_CUE_REEK) : (HYGIENE_CUE_STINK));
		Hygiene_ShowFlies(playerid,level == HYGIENE_LEVEL_REEKS ? HYGIENE_FLIES_MAX : HYGIENE_FLIES_STINK);
	}
	else
	{
		Nametag_SetCue(playerid,NAMETAG_CUE_STINK,"");
		Hygiene_DropFlies(playerid);
	}

	if (level != was)
	{
		if (level == HYGIENE_LEVEL_STINKS && was < level)
		{
			Gui_Notify(playerid,"You've started to stink. Flies follow you and people will notice. Wash at a washtub.");
		}
		else if (level == HYGIENE_LEVEL_REEKS && was < level)
		{
			Gui_Notify(playerid,"You reek. Shopkeepers charge you more and families won't seat you at their table.");
		}

		pawn_call_public("Hygiene_OnLevel","ddd",playerid,_:was,_:level);
	}
}

stock Hygiene_SetDirt(playerid,dirt)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_HygieneDirt[playerid] = clamp(dirt,0,HYGIENE_MAX);
	s_HygieneDirty[playerid] = true;
	Hygiene_Show(playerid);
}

stock Hygiene_AddDirt(playerid,amount)
{
	if (amount != 0)
	{
		Hygiene_SetDirt(playerid,Hygiene_GetDirt(playerid) + amount);
	}
}

stock Hygiene_Wash(playerid,amount = HYGIENE_MAX)
{
	new before = Hygiene_GetDirt(playerid);
	Hygiene_SetDirt(playerid,before - amount);
	Hygiene_Save(playerid);
	return before - Hygiene_GetDirt(playerid);
}

stock Hygiene_Save(playerid)
{
	new characterid = Character_GetId(playerid);

	if (!s_HygieneLoaded[playerid] || characterid <= 0)
	{
		return;
	}

	s_HygieneDirty[playerid] = false;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO hygiene (character_id, dirt, updated_at) VALUES (%d, %d, %d) ON DUPLICATE KEY UPDATE dirt = VALUES(dirt), updated_at = VALUES(updated_at)",characterid,s_HygieneDirt[playerid],gettime()));
}

forward Task:Hygiene_Load(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Hygiene_Load(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT dirt FROM hygiene WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	new dirt = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"dirt",dirt);
	}

	s_HygieneDirt[playerid] = clamp(dirt,0,HYGIENE_MAX);
	s_HygieneLoaded[playerid] = true;
	s_HygieneNextAt[playerid] = gettime() + HYGIENE_TIME_SECONDS;
	Hygiene_Show(playerid);
	return async 1;
}
#pragma warning pop

static Hygiene_Clear(playerid)
{
	Hygiene_DropFlies(playerid);

	s_HygieneDirt[playerid] = 0;
	s_HygieneLoaded[playerid] = false;
	s_HygieneDirty[playerid] = false;
	s_HygieneShown[playerid] = HYGIENE_LEVEL_CLEAN;
}

Timer_Declare(Hygiene_FliesTick)
{
	foreach (new playerid : Player)
	{
		if (s_HygieneFliesCount[playerid] == 0)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);

		for (new i = 0;i < s_HygieneFliesCount[playerid];i++)
		{
			SetDynamicObjectPos(s_HygieneFlies[playerid][i],x + s_HygieneFlySpots[i][0],y + s_HygieneFlySpots[i][1],z + s_HygieneFlySpots[i][2]);

			if (i < 2)
			{
				SetDynamicObjectRot(s_HygieneFlies[playerid][i],float(random(40) - 20),float(random(40) - 20),float(random(360)));
			}
		}
	}

	return 1;
}

Timer_Declare(Hygiene_Tick)
{
	new now = gettime(), bool:save = ++s_HygieneSaveTicks >= HYGIENE_SAVE_EVERY;

	if (save)
	{
		s_HygieneSaveTicks = 0;
	}

	foreach (new playerid : Player)
	{
		if (!s_HygieneLoaded[playerid] || !Session_IsPlaying(playerid))
		{
			continue;
		}

		if (now >= s_HygieneNextAt[playerid])
		{
			s_HygieneNextAt[playerid] = now + HYGIENE_TIME_SECONDS;
			Hygiene_AddDirt(playerid,1);
		}

		if (save && s_HygieneDirty[playerid])
		{
			Hygiene_Save(playerid);
		}
	}

	return 1;
}

forward Hygiene_OnLevel(playerid,oldLevel,newLevel);

public Hygiene_OnLevel(playerid,oldLevel,newLevel)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Hygiene_Clear(playerid);
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_HygieneDirty[playerid])
	{
		Hygiene_Save(playerid);
	}

	Hygiene_Clear(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	Hygiene_Clear(playerid);
	Hygiene_Load(playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	if (s_HygieneDirty[playerid])
	{
		Hygiene_Save(playerid);
	}

	Hygiene_Clear(playerid);
}

hook Work_OnFinished(playerid,recipe,stars)
{
	#pragma unused recipe, stars

	Hygiene_AddDirt(playerid,HYGIENE_WORK);
}

hook Wounds_OnWounded(playerid,part,kind,severity,const source[])
{
	#pragma unused part, kind, severity, source

	Hygiene_AddDirt(playerid,HYGIENE_WOUND);
}
