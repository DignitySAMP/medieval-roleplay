#define WARMTH_BREATH_MODEL (18696)
#define WARMTH_BREATH_BONE (2)
#define WARMTH_BREATH_CELSIUS (5.0)
#define WARMTH_BREATH_SECONDS (3)

enum
{
	WARMTH_BREATH_AUTO,
	WARMTH_BREATH_ALWAYS,
	WARMTH_BREATH_OFF,
}

static s_WarmthBreathMode[MAX_PLAYERS];
static s_WarmthBreathTick[MAX_PLAYERS];
static bool:s_WarmthBreathShown[MAX_PLAYERS];

stock Warmth_SetBreathMode(playerid,mode)
{
	if (Util_IsValidPlayer(playerid) && mode >= WARMTH_BREATH_AUTO && mode <= WARMTH_BREATH_OFF)
	{
		s_WarmthBreathMode[playerid] = mode;
		Warmth_UpdateBreath(playerid);
	}
}

stock bool:Warmth_IsBreathShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WarmthBreathShown[playerid];
}

stock bool:Warmth_ShouldBreathShow(playerid)
{
	if (s_WarmthBreathMode[playerid] == WARMTH_BREATH_OFF || !Session_IsPlaying(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		return false;
	}

	if (s_WarmthBreathMode[playerid] == WARMTH_BREATH_ALWAYS)
	{
		return true;
	}

	new Float:x, Float:y, Float:z, interior = GetPlayerInterior(playerid);
	GetPlayerPos(playerid,x,y,z);
	return interior == 0 && Calendar_GetTemperature(x,y,z,interior) < WARMTH_BREATH_CELSIUS;
}

static Warmth_HideBreath(playerid)
{
	if (s_WarmthBreathShown[playerid])
	{
		RemovePlayerAttachedObject(playerid,ATTACH_SLOT_BREATH);
		s_WarmthBreathShown[playerid] = false;
	}
}

stock Warmth_UpdateBreath(playerid)
{
	if (Attach_IsEditing(playerid))
	{
		s_WarmthBreathShown[playerid] = false;
		return;
	}

	if (!Warmth_ShouldBreathShow(playerid))
	{
		Warmth_HideBreath(playerid);
		return;
	}

	RemovePlayerAttachedObject(playerid,ATTACH_SLOT_BREATH);
	SetPlayerAttachedObject(playerid,ATTACH_SLOT_BREATH,WARMTH_BREATH_MODEL,WARMTH_BREATH_BONE,0.0,0.1,-0.2,-25.5,0.0,0.0,0.10,0.3,0.15);
	s_WarmthBreathShown[playerid] = true;
}

CMD<ADMIN_LEVEL_TRIAL>:breath(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	static const modes[][] = {"automatic (below 5 C, outdoors)", "always on", "off"};
	s_WarmthBreathMode[playerid] = (s_WarmthBreathMode[playerid] + 1) % sizeof(modes);
	Warmth_UpdateBreath(playerid);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Cold breath: %s.",modes[s_WarmthBreathMode[playerid]]));
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_WarmthBreathMode[playerid] = WARMTH_BREATH_AUTO;
	s_WarmthBreathTick[playerid] = 0;
	s_WarmthBreathShown[playerid] = false;
}

hook Tick_OnPlayerSecond(playerid)
{
	if (++s_WarmthBreathTick[playerid] % WARMTH_BREATH_SECONDS == 0)
	{
		Warmth_UpdateBreath(playerid);
	}
}
