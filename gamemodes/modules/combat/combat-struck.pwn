#define COMBAT_STRUCK_THRESHOLD (15.0)
#define COMBAT_STRUCK_FLOOR (1.0)
#define COMBAT_EXECUTE_GRACE_MS (1500)
#define COMBAT_STRUCK_SECONDS (30)
#define COMBAT_REVIVE_RANGE (2.0)
#define COMBAT_REVIVE_HEALTH_MIN (30)
#define COMBAT_REVIVE_HEALTH_MAX (40)
#define COMBAT_STRUCK_COLOUR (0xB83D3DFF)
#define COMBAT_NAME_COLOUR (0xDEDEDEFF)

enum E_STRUCK
{
	bool:E_STRUCK_DOWN,
	bool:E_STRUCK_KNOCKOUT,
	E_STRUCK_LEFT,
	E_STRUCK_TOKEN,
	E_STRUCK_AT,
}

static s_Struck[MAX_PLAYERS][E_STRUCK];
static bool:s_Tourney[MAX_PLAYERS];

stock bool:Combat_IsStruckDown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Struck[playerid][E_STRUCK_DOWN];
}

stock bool:Combat_IsTourney(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Tourney[playerid];
}

stock Combat_SetTourney(playerid,bool:isOn)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_Tourney[playerid] = isOn;
	}
}

stock Float:Combat_CapToStrikeDown(targetid,Float:damage)
{
	new Float:health = Vitals_GetHealth(targetid);

	if (Combat_IsStruckDown(targetid) || !Session_IsPlaying(targetid) || damage < health)
	{
		return damage;
	}

	return health > COMBAT_STRUCK_FLOOR ? health - COMBAT_STRUCK_FLOOR : 0.0;
}

stock Combat_GetStruckSecondsLeft(playerid)
{
	if (!Combat_IsStruckDown(playerid))
	{
		return 0;
	}

	return s_Struck[playerid][E_STRUCK_LEFT];
}

stock bool:Combat_IsKnockedOut(playerid)
{
	return Combat_IsStruckDown(playerid) && s_Struck[playerid][E_STRUCK_KNOCKOUT];
}

stock Combat_GetStruckSeconds(playerid)
{
	return Traits_Scale(playerid,TRAIT_EFFECT_STRUCK,COMBAT_STRUCK_SECONDS);
}

stock bool:Combat_StrikeDown(playerid,seconds = COMBAT_STRUCK_SECONDS,bool:isKnockout = false)
{
	if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid) || s_Struck[playerid][E_STRUCK_DOWN])
	{
		return false;
	}

	if (s_Tourney[playerid])
	{
		isKnockout = true;
	}

	if (!isKnockout)
	{
		seconds = Traits_Scale(playerid,TRAIT_EFFECT_STRUCK,seconds);
	}

	Combat_SetMode(playerid,false);

	if (Mount_IsRiding(playerid))
	{
		Mount_Dismount(playerid);
	}

	s_Struck[playerid][E_STRUCK_DOWN] = true;
	s_Struck[playerid][E_STRUCK_KNOCKOUT] = isKnockout;
	s_Struck[playerid][E_STRUCK_LEFT] = seconds;
	s_Struck[playerid][E_STRUCK_TOKEN]++;
	s_Struck[playerid][E_STRUCK_AT] = GetTickCount();
	TogglePlayerControllable(playerid,false);
	ApplyAnimation(playerid,"CRACK","crckidle2",4.1,true,false,false,true,0,SYNC_ALL);
	SetPlayerColor(playerid,COMBAT_STRUCK_COLOUR);
	if (isKnockout)
	{
		Gui_Notify(playerid,sprintf("You're knocked out. You'll get up in %d seconds, or sooner if someone presses F next to you.",seconds));
	}
	else
	{
		Gui_Notify(playerid,sprintf("You've been struck down. If nobody helps you up within %d seconds, you'll die.",seconds));
	}
	SetTimerEx("Combat_StruckTick",1000,false,"dd",playerid,s_Struck[playerid][E_STRUCK_TOKEN]);
	pawn_call_public("Combat_OnStruckDown","d",playerid);
	return true;
}

static Combat_StruckClear(playerid)
{
	s_Struck[playerid][E_STRUCK_DOWN] = false;
	s_Struck[playerid][E_STRUCK_KNOCKOUT] = false;
	s_Struck[playerid][E_STRUCK_LEFT] = 0;
	s_Struck[playerid][E_STRUCK_TOKEN]++;
	SetPlayerColor(playerid,COMBAT_NAME_COLOUR);
}

stock bool:Combat_Revive(playerid,helperid = INVALID_PLAYER_ID)
{
	if (!Combat_IsStruckDown(playerid))
	{
		return false;
	}

	Combat_StruckClear(playerid);
	Combat_ClearAnimation(playerid);
	TogglePlayerControllable(playerid,true);
	SetCameraBehindPlayer(playerid);
	Vitals_SetHealth(playerid,VITALS_MAX * float(COMBAT_REVIVE_HEALTH_MIN + random(COMBAT_REVIVE_HEALTH_MAX - COMBAT_REVIVE_HEALTH_MIN + 1)) / 100.0,"revived");
	pawn_call_public("Combat_OnRevived","dd",playerid,helperid);
	return true;
}

stock Combat_ExecuteDowned(playerid,targetid)
{
	if (!Util_IsValidPlayer(playerid) || !Combat_IsInMode(playerid) || !Combat_IsStruckDown(targetid) || !Weapon_IsValid(Combat_GetWeapon(playerid)))
	{
		return 0;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(targetid,x,y,z);
	if (GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(targetid) || !IsPlayerInRangeOfPoint(playerid,COMBAT_REVIVE_RANGE,x,y,z))
	{
		return 0;
	}

	if (GetTickCount() - s_Struck[targetid][E_STRUCK_AT] < COMBAT_EXECUTE_GRACE_MS)
	{
		return 0;
	}

	Combat_StruckClear(targetid);
	Combat_ClearAnimation(targetid);
	TogglePlayerControllable(targetid,true);
	Vitals_SetHealth(targetid,0.0,"executed");
	Gui_Notify(playerid,"You finished them.");
	pawn_call_public("Combat_OnExecuted","dd",targetid,playerid);
	return 1;
}

forward Combat_StruckTick(playerid,token);

public Combat_StruckTick(playerid,token)
{
	if (!IsPlayerConnected(playerid) || !s_Struck[playerid][E_STRUCK_DOWN] || s_Struck[playerid][E_STRUCK_TOKEN] != token)
	{
		return 1;
	}

	if (--s_Struck[playerid][E_STRUCK_LEFT] > 0)
	{
		ApplyAnimation(playerid,"CRACK","crckidle2",4.1,true,false,false,true,0,SYNC_ALL);
		SetTimerEx("Combat_StruckTick",1000,false,"dd",playerid,token);
		return 1;
	}

	new bool:isKnockout = s_Struck[playerid][E_STRUCK_KNOCKOUT];
	Combat_StruckClear(playerid);
	Combat_ClearAnimation(playerid);
	TogglePlayerControllable(playerid,true);

	if (isKnockout)
	{
		SetCameraBehindPlayer(playerid);
		Vitals_SetHealth(playerid,COMBAT_STRUCK_THRESHOLD,"came to");
		Gui_Notify(playerid,"You wake up, aching all over.");
		pawn_call_public("Combat_OnRevived","dd",playerid,INVALID_PLAYER_ID);
		return 1;
	}

	Vitals_SetHealth(playerid,0.0,"bled out");
	return 1;
}

static Combat_FindDownedNear(playerid)
{
	new Float:x, Float:y, Float:z;
	foreach(new i : Player)
	{
		if (i == playerid || !s_Struck[i][E_STRUCK_DOWN] || GetPlayerVirtualWorld(i) != GetPlayerVirtualWorld(playerid))
		{
			continue;
		}

		GetPlayerPos(i,x,y,z);
		if (IsPlayerInRangeOfPoint(playerid,COMBAT_REVIVE_RANGE,x,y,z))
		{
			return i;
		}
	}

	return INVALID_PLAYER_ID;
}

forward Combat_OnStruckDown(playerid);

public Combat_OnStruckDown(playerid)
{
	return 1;
}

forward Combat_OnFelled(attackerid,targetid);

public Combat_OnFelled(attackerid,targetid)
{
	return 1;
}

forward Combat_OnRevived(playerid,helperid);

public Combat_OnRevived(playerid,helperid)
{
	return 1;
}

forward Combat_OnExecuted(playerid,executionerid);

public Combat_OnExecuted(playerid,executionerid)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Struck[playerid][E_STRUCK_DOWN] = false;
	s_Struck[playerid][E_STRUCK_LEFT] = 0;
	s_Struck[playerid][E_STRUCK_TOKEN]++;
}

hook Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[])
{
	#pragma unused before, source

	if (after > 0.0 && after < COMBAT_STRUCK_THRESHOLD && !s_Struck[playerid][E_STRUCK_DOWN] && Session_IsPlaying(playerid) && !Combat_IsTakingFistBlow(playerid))
	{
		Combat_StrikeDown(playerid);
	}
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to != SESSION_PLAYING && s_Struck[playerid][E_STRUCK_DOWN])
	{
		Combat_StruckClear(playerid);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
	{
		return;
	}

	if (!(newkeys & KEY_SECONDARY_ATTACK) || (oldkeys & KEY_SECONDARY_ATTACK) || Combat_IsInMode(playerid))
	{
		return;
	}

	new downed = Combat_FindDownedNear(playerid);
	if (downed == INVALID_PLAYER_ID)
	{
		return;
	}

	Combat_Revive(downed,playerid);
	Gui_Notify(playerid,"You helped them to their feet.");
	Gui_Notify(downed,"Someone helped you back to your feet.");
}
