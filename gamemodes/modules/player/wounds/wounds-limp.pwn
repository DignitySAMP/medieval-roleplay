static bool:s_WoundsLame[MAX_PLAYERS];
static bool:s_WoundsLimping[MAX_PLAYERS];
static s_WoundsRunSince[MAX_PLAYERS];
static s_WoundsDownUntil[MAX_PLAYERS];
static s_WoundsStumbles[MAX_PLAYERS];
static s_WoundsStumblesToFall[MAX_PLAYERS];

stock bool:Wounds_IsLame(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WoundsLame[playerid];
}

stock bool:Wounds_IsLimping(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WoundsLimping[playerid];
}

stock bool:Wounds_IsDown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WoundsDownUntil[playerid] != 0;
}

stock Wounds_GetStumbles(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_WoundsStumbles[playerid] : 0;
}

static bool:Wounds_CanLimp(playerid)
{
	return Session_IsPlaying(playerid) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT && !Combat_IsInMode(playerid) && !Combat_IsKnockedDown(playerid) && !Combat_IsStruckDown(playerid) && !Work_IsWorking(playerid) && !Vitals_IsBusy(playerid) && !Mount_IsRiding(playerid);
}

static Wounds_StopLimp(playerid,bool:isClearing)
{
	if (!s_WoundsLimping[playerid])
	{
		return;
	}

	s_WoundsLimping[playerid] = false;

	if (isClearing)
	{
		ClearAnimations(playerid,SYNC_ALL);
	}
}

stock Wounds_SetLame(playerid,bool:isLame)
{
	if (!Util_IsValidPlayer(playerid) || s_WoundsLame[playerid] == isLame)
	{
		return;
	}

	s_WoundsLame[playerid] = isLame;
	s_WoundsRunSince[playerid] = 0;

	if (!isLame)
	{
		Wounds_StopLimp(playerid,Wounds_CanLimp(playerid));
	}
}

static Wounds_Fall(playerid)
{
	s_WoundsLimping[playerid] = false;
	s_WoundsRunSince[playerid] = 0;
	s_WoundsDownUntil[playerid] = GetTickCount() + WOUND_FALL_DOWN_MS;
	ApplyAnimation(playerid,"PED","KO_SKID_FRONT",4.1,false,false,false,true,0,SYNC_ALL);
	SetTimerEx("Wounds_GetUp",WOUND_FALL_DOWN_MS,false,"dd",playerid,Account_GetToken(playerid));
	Gui_Notify(playerid,"Your broken leg gives way. Hold ~k~~SNEAK_ABOUT~ to limp along, or splint it.");
}

static Wounds_TickRunning(playerid)
{
	new now = GetTickCount();

	if (s_WoundsRunSince[playerid] == 0)
	{
		s_WoundsRunSince[playerid] = now;
		s_WoundsStumbles[playerid] = 0;
		s_WoundsStumblesToFall[playerid] = 1 + random(WOUND_STUMBLE_MAX);
		return;
	}

	if (now - s_WoundsRunSince[playerid] < WOUND_STUMBLE_FIRST_MS + s_WoundsStumbles[playerid] * WOUND_STUMBLE_EVERY_MS)
	{
		return;
	}

	if (s_WoundsStumbles[playerid] < s_WoundsStumblesToFall[playerid])
	{
		s_WoundsStumbles[playerid]++;
		ApplyAnimation(playerid,"PED","HIT_WALK",4.1,false,true,true,false,0,SYNC_ALL);
		return;
	}

	Wounds_Fall(playerid);
}

static Wounds_TickLimp(playerid)
{
	if (!s_WoundsLame[playerid] || s_WoundsDownUntil[playerid] != 0)
	{
		return;
	}

	if (!Wounds_CanLimp(playerid))
	{
		Wounds_StopLimp(playerid,false);
		s_WoundsRunSince[playerid] = 0;
		return;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);

	if (updown == 0 && leftright == 0)
	{
		Wounds_StopLimp(playerid,true);
		s_WoundsRunSince[playerid] = 0;
		return;
	}

	if (keys & KEY_WALK)
	{
		s_WoundsRunSince[playerid] = 0;

		if (!s_WoundsLimping[playerid])
		{
			s_WoundsLimping[playerid] = true;
			ApplyAnimation(playerid,WOUND_LIMP_LIB,WOUND_LIMP_ANIM,4.1,true,true,true,true,1,SYNC_ALL);
		}

		return;
	}

	s_WoundsLimping[playerid] = false;
	Wounds_TickRunning(playerid);
}

forward Wounds_GetUp(playerid,token);

public Wounds_GetUp(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && s_WoundsDownUntil[playerid] != 0)
	{
		s_WoundsDownUntil[playerid] = 0;

		if (Session_IsPlaying(playerid) && !Combat_IsKnockedDown(playerid) && !Combat_IsStruckDown(playerid))
		{
			ApplyAnimation(playerid,"PED","GETUP_FRONT",4.1,false,false,false,false,0,SYNC_ALL);
		}
	}

	return 1;
}

forward bool:Wounds_BusyCheck(playerid);

public bool:Wounds_BusyCheck(playerid)
{
	return Wounds_IsDown(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_WoundsLame[playerid] = false;
	s_WoundsLimping[playerid] = false;
	s_WoundsRunSince[playerid] = 0;
	s_WoundsDownUntil[playerid] = 0;
	s_WoundsStumbles[playerid] = 0;
}

hook Character_OnUnloaded(playerid)
{
	s_WoundsLame[playerid] = false;
	s_WoundsLimping[playerid] = false;
	s_WoundsRunSince[playerid] = 0;
	s_WoundsDownUntil[playerid] = 0;
	s_WoundsStumbles[playerid] = 0;
}

hook OnPlayerUpdate(playerid)
{
	Wounds_TickLimp(playerid);
}
