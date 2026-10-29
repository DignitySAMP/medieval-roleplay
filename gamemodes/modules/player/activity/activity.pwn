#define ACTIVITY_EMOTE_RANGE (5.0)
#define ACTIVITY_RESTFUL_EVERY (30)

static s_ActivitySeconds[MAX_PLAYERS];

stock bool:Activity_IsRestfulPlace(playerid)
{
	new house = Houses_GetInside(playerid);

	if (house == -1)
	{
		return false;
	}

	return Houses_HoldsRoomIn(playerid,house) || Fatigue_IsLying(playerid);
}

static bool:Activity_HasCompany(playerid,Float:range)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach(new i : Player)
	{
		if (i != playerid && Session_IsPlaying(i) && GetPlayerVirtualWorld(i) == GetPlayerVirtualWorld(playerid) && IsPlayerInRangeOfPoint(i,range,x,y,z))
		{
			return true;
		}
	}

	return false;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_ActivitySeconds[playerid] = 0;
}

hook OnPlayerText(playerid,text[])
{
	#pragma unused text
	Session_MarkActive(playerid);
}

hook Kit_OnPicked(playerid,value)
{
	#pragma unused value
	Session_MarkActive(playerid);
}

hook Work_OnStageStarting(playerid,recipe,stage)
{
	#pragma unused recipe, stage
	Session_MarkActive(playerid);
}

hook Combat_OnSwing(playerid,anim)
{
	#pragma unused anim
	Session_MarkActive(playerid);
}

hook Emotes_OnPlay(playerid,emote)
{
	#pragma unused emote

	if (Activity_HasCompany(playerid,ACTIVITY_EMOTE_RANGE))
	{
		Session_MarkActive(playerid);
	}
}

hook Emotes_OnPair(playerid,partnerid,kind)
{
	#pragma unused kind
	Session_MarkActive(playerid);
	Session_MarkActive(partnerid);
}

hook Faith_OnPrayer(playerid,spot)
{
	#pragma unused spot
	Session_MarkActive(playerid);
}

hook Faith_OnBlessed(playerid,isLed)
{
	#pragma unused isLed
	Session_MarkActive(playerid);
}

hook Session_OnAway(playerid)
{
	Nametag_SetCue(playerid,NAMETAG_CUE_AWAY,"(away)");
}

hook Session_OnBack(playerid)
{
	Nametag_SetCue(playerid,NAMETAG_CUE_AWAY,"");
}

hook Tick_OnPlayerSecond(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	if (Work_IsWorking(playerid))
	{
		Session_MarkActive(playerid);
	}

	if (++s_ActivitySeconds[playerid] % ACTIVITY_RESTFUL_EVERY == 0)
	{
		Session_SetRestful(playerid,Activity_IsRestfulPlace(playerid));
	}
}
