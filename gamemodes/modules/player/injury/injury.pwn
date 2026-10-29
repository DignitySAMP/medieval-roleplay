#define INJURY_PUDDLE_MODEL (19836)
#define INJURY_PUDDLES (25)
#define INJURY_PUDDLE_DROP (0.99)
#define INJURY_BLEED_SECONDS (60)

enum E_INJURY
{
	bool:E_INJURY_BLEEDING,
	E_INJURY_BLEED_LEFT,
	E_INJURY_NEXT_PUDDLE,
	E_INJURY_PUDDLE_COUNT,
	E_INJURY_PUDDLE_HEAD,
}

static s_Injury[MAX_PLAYERS][E_INJURY];
static STREAMER_TAG_OBJECT:s_Puddle[MAX_PLAYERS][INJURY_PUDDLES];

stock bool:Injury_IsBleeding(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Injury[playerid][E_INJURY_BLEEDING];
}

stock Injury_GetPuddleCount(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Injury[playerid][E_INJURY_PUDDLE_COUNT] : 0;
}

stock bool:Injury_StartBleeding(playerid)
{
	if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid))
	{
		return false;
	}

	s_Injury[playerid][E_INJURY_BLEED_LEFT] = INJURY_BLEED_SECONDS;
	if (s_Injury[playerid][E_INJURY_BLEEDING])
	{
		return true;
	}

	s_Injury[playerid][E_INJURY_BLEEDING] = true;
	s_Injury[playerid][E_INJURY_NEXT_PUDDLE] = 1;
	return true;
}

stock Injury_StopBleeding(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Injury[playerid][E_INJURY_BLEEDING] = false;
	s_Injury[playerid][E_INJURY_BLEED_LEFT] = 0;
	s_Injury[playerid][E_INJURY_NEXT_PUDDLE] = 0;
	Injury_ClearPuddles(playerid);
}

static Injury_DropPuddle(playerid)
{
	new Float:x, Float:y, Float:z, slot;
	GetPlayerPos(playerid,x,y,z);

	if (s_Injury[playerid][E_INJURY_PUDDLE_COUNT] < INJURY_PUDDLES)
	{
		slot = s_Injury[playerid][E_INJURY_PUDDLE_COUNT]++;
	}
	else
	{
		slot = s_Injury[playerid][E_INJURY_PUDDLE_HEAD];
		s_Injury[playerid][E_INJURY_PUDDLE_HEAD] = (slot + 1) % INJURY_PUDDLES;
		if (IsValidDynamicObject(s_Puddle[playerid][slot]))
		{
			DestroyDynamicObject(s_Puddle[playerid][slot]);
		}
	}

	s_Puddle[playerid][slot] = CreateDynamicObject(INJURY_PUDDLE_MODEL,x,y,z - INJURY_PUDDLE_DROP,0.0,0.0,float(random(360)),GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));
}

static Injury_ClearPuddles(playerid)
{
	for (new i = 0; i < INJURY_PUDDLES; i++)
	{
		if (IsValidDynamicObject(s_Puddle[playerid][i]))
		{
			DestroyDynamicObject(s_Puddle[playerid][i]);
		}

		s_Puddle[playerid][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	s_Injury[playerid][E_INJURY_PUDDLE_COUNT] = 0;
	s_Injury[playerid][E_INJURY_PUDDLE_HEAD] = 0;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Injury[playerid][E_INJURY_BLEEDING] = false;
	s_Injury[playerid][E_INJURY_BLEED_LEFT] = 0;
	s_Injury[playerid][E_INJURY_NEXT_PUDDLE] = 0;
	s_Injury[playerid][E_INJURY_PUDDLE_COUNT] = 0;
	s_Injury[playerid][E_INJURY_PUDDLE_HEAD] = 0;
	for (new i = 0; i < INJURY_PUDDLES; i++)
	{
		s_Puddle[playerid][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Injury_StopBleeding(playerid);
}

hook Combat_OnRevived(playerid,helperid)
{
	#pragma unused helperid

	Injury_StopBleeding(playerid);
}

hook Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[])
{
	#pragma unused before, after

	if (!strcmp(source,"bandage"))
	{
		Injury_StopBleeding(playerid);
	}
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		Injury_StopBleeding(playerid);
	}
}

hook Tick_OnPlayerSecond(playerid)
{
	if (!s_Injury[playerid][E_INJURY_BLEEDING])
	{
		return;
	}

	if (!Combat_IsStruckDown(playerid) && --s_Injury[playerid][E_INJURY_BLEED_LEFT] <= 0)
	{
		Injury_StopBleeding(playerid);
		return;
	}

	if (--s_Injury[playerid][E_INJURY_NEXT_PUDDLE] <= 0)
	{
		Injury_DropPuddle(playerid);
		s_Injury[playerid][E_INJURY_NEXT_PUDDLE] = 1 + random(3);
	}
}
