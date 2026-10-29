#define CARRY_PACE_GRACE_MS (600)
#define CARRY_PACE_WINDED_MS (1500)
#define CARRY_PACE_NOTICE_MS (15000)
#define CARRY_PACE_JOG_SPEED (0.06)
#define CARRY_PACE_SPRINT_SPEED (0.1)
#define CARRY_PACE_WALK_LIB "PED"
#define CARRY_PACE_WALK_ANIM "WALK_fatold"
#define CARRY_SHOULDER_LIB "ROCKET"
#define CARRY_SHOULDER_IDLE "idle_rocket"
#define CARRY_SHOULDER_WALK "walk_rocket"

enum
{
	CARRY_HOLD_NONE,
	CARRY_HOLD_STILL,
	CARRY_HOLD_MOVING,
	CARRY_HOLD_SHOULDER,
	CARRY_HOLD_SHOULDER_WALK,
	CARRY_HOLD_SHOULDER_JOG,
}

enum
{
	CARRY_PACE_FREE,
	CARRY_PACE_NO_SPRINT,
	CARRY_PACE_WALK,
}

static s_CarryPace[MAX_PLAYERS];
static s_CarryBreachSince[MAX_PLAYERS];
static s_CarryWindedUntil[MAX_PLAYERS];
static s_CarryNoticeAt[MAX_PLAYERS];
static bool:s_CarryTrudging[MAX_PLAYERS];
static s_CarryGrip[MAX_PLAYERS];
static s_CarryHold[MAX_PLAYERS];

stock Carry_PaceFor(band,bulky)
{
	if (band == CARRY_OVERLOADED || bulky > 1)
	{
		return CARRY_PACE_WALK;
	}

	return band == CARRY_HEAVY || bulky > 0 ? CARRY_PACE_NO_SPRINT : CARRY_PACE_FREE;
}

stock Carry_GetPace(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CarryPace[playerid] : CARRY_PACE_FREE;
}

stock bool:Carry_IsWinded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_CarryWindedUntil[playerid] != 0;
}

stock bool:Carry_BreaksPace(pace,KEY:keys,updown,leftright,Float:speed)
{
	if (pace == CARRY_PACE_FREE || (updown == 0 && leftright == 0) || (keys & KEY_WALK))
	{
		return false;
	}

	if (pace == CARRY_PACE_WALK)
	{
		return speed > CARRY_PACE_JOG_SPEED;
	}

	return (keys & KEY_SPRINT) && speed > CARRY_PACE_SPRINT_SPEED;
}

stock Carry_SetPace(playerid,pace)
{
	if (!Util_IsValidPlayer(playerid) || s_CarryPace[playerid] == pace)
	{
		return;
	}

	s_CarryPace[playerid] = pace;
	s_CarryBreachSince[playerid] = 0;

	if (pace != CARRY_PACE_WALK)
	{
		Carry_StopTrudge(playerid,true);
	}
}

static bool:Carry_CanPace(playerid)
{
	return Session_IsPlaying(playerid) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT && !Mount_IsRiding(playerid) && !Combat_IsInMode(playerid) && !Combat_IsKnockedDown(playerid) && !Combat_IsStruckDown(playerid) && !Work_IsWorking(playerid) && !Vitals_IsBusy(playerid) && !Wounds_IsLame(playerid) && !Wounds_IsDown(playerid);
}

stock bool:Carry_GetHoldAnim(mode,lib[],name[],libSize = sizeof(lib),nameSize = sizeof(name))
{
	switch (mode)
	{
		case CARRY_HOLD_STILL:
		{
			strcopy(lib,"CARRY",libSize);
			strcopy(name,"crry_prtial",nameSize);
		}
		case CARRY_HOLD_SHOULDER:
		{
			strcopy(lib,CARRY_SHOULDER_LIB,libSize);
			strcopy(name,CARRY_SHOULDER_IDLE,nameSize);
		}
		case CARRY_HOLD_SHOULDER_WALK:
		{
			strcopy(lib,CARRY_SHOULDER_LIB,libSize);
			strcopy(name,CARRY_SHOULDER_WALK,nameSize);
		}
		default:
		{
			lib[0] = EOS;
			name[0] = EOS;
			return false;
		}
	}

	return true;
}

stock Carry_HoldFor(grip,KEY:keys,updown,leftright)
{
	if (grip == CARRY_GRIP_NONE)
	{
		return CARRY_HOLD_NONE;
	}

	new bool:isMoving = updown != 0 || leftright != 0;

	if (grip == CARRY_GRIP_ARMS)
	{
		return isMoving ? CARRY_HOLD_MOVING : CARRY_HOLD_STILL;
	}

	if (!isMoving)
	{
		return CARRY_HOLD_SHOULDER;
	}

	return (keys & KEY_WALK) ? CARRY_HOLD_SHOULDER_WALK : CARRY_HOLD_SHOULDER_JOG;
}

stock Carry_GetHold(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CarryHold[playerid] : CARRY_HOLD_NONE;
}

static bool:Carry_IsHoldAnim(playerid,mode)
{
	new lib[16], name[24], want[16], wantName[24];

	if (!Carry_GetHoldAnim(mode,want,wantName))
	{
		return false;
	}

	GetAnimationName(GetPlayerAnimationIndex(playerid),lib,sizeof(lib),name,sizeof(name));
	return !strcmp(lib,want,true) && !strcmp(name,wantName,true);
}

static Carry_SetHold(playerid,mode)
{
	if (Fly_IsActive(playerid))
	{
		s_CarryHold[playerid] = mode;
		return;
	}

	new old = s_CarryHold[playerid], lib[16], name[24];

	if (old == CARRY_HOLD_MOVING && mode != CARRY_HOLD_MOVING)
	{
		SetPlayerSpecialAction(playerid,SPECIAL_ACTION_NONE);
	}

	if (!Carry_GetHoldAnim(mode,lib,name) && ((old == CARRY_HOLD_SHOULDER_WALK && mode != CARRY_HOLD_SHOULDER_JOG) || Carry_IsHoldAnim(playerid,old)))
	{
		ClearAnimations(playerid,SYNC_ALL);
	}

	switch (mode)
	{
		case CARRY_HOLD_STILL, CARRY_HOLD_SHOULDER: ApplyAnimation(playerid,lib,name,4.1,true,true,true,false,0,SYNC_ALL);
		case CARRY_HOLD_SHOULDER_WALK: ApplyAnimation(playerid,lib,name,4.1,true,true,true,true,1,SYNC_ALL);
		case CARRY_HOLD_MOVING: SetPlayerSpecialAction(playerid,SPECIAL_ACTION_CARRY);
	}

	s_CarryHold[playerid] = mode;
}

stock Carry_HoldPose(playerid,grip)
{
	s_CarryGrip[playerid] = grip;

	if (grip == CARRY_GRIP_NONE)
	{
		Carry_SetHold(playerid,CARRY_HOLD_NONE);
	}
}

static Carry_TickHold(playerid)
{
	if (s_CarryGrip[playerid] == CARRY_GRIP_NONE)
	{
		return;
	}

	if (!Carry_CanPace(playerid) || Character_IsBusy(playerid))
	{
		if (s_CarryHold[playerid] != CARRY_HOLD_NONE && !Carry_CanPace(playerid))
		{
			Carry_SetHold(playerid,CARRY_HOLD_NONE);
		}

		return;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);
	new mode = Carry_HoldFor(s_CarryGrip[playerid],keys,updown,leftright);

	if (mode != s_CarryHold[playerid])
	{
		Carry_SetHold(playerid,mode);
	}
}

static Carry_StopTrudge(playerid,bool:isClearing)
{
	if (!s_CarryTrudging[playerid])
	{
		return;
	}

	s_CarryTrudging[playerid] = false;

	if (isClearing && Carry_CanPace(playerid))
	{
		ClearAnimations(playerid,SYNC_ALL);
	}
}

static Carry_Wind(playerid)
{
	new now = GetTickCount();
	s_CarryBreachSince[playerid] = 0;
	s_CarryWindedUntil[playerid] = now + CARRY_PACE_WINDED_MS;
	s_CarryTrudging[playerid] = false;
	Carry_SetHold(playerid,CARRY_HOLD_NONE);
	ApplyAnimation(playerid,"PED","IDLE_tired",4.1,false,false,false,false,CARRY_PACE_WINDED_MS,SYNC_ALL);

	if (s_CarryNoticeAt[playerid] == 0 || now - s_CarryNoticeAt[playerid] > CARRY_PACE_NOTICE_MS)
	{
		s_CarryNoticeAt[playerid] = now;

		if (s_CarryPace[playerid] == CARRY_PACE_WALK)
		{
			Gui_Notify(playerid,"You're carrying too much to run. Hold ~k~~SNEAK_ABOUT~ to walk, or leave something behind.");
		}
		else
		{
			Gui_Notify(playerid,"You're carrying too much to sprint. Jog or walk, or leave something behind.");
		}
	}
}

static Carry_TickPace(playerid)
{
	if (s_CarryPace[playerid] == CARRY_PACE_FREE)
	{
		return;
	}

	if (s_CarryWindedUntil[playerid] != 0)
	{
		if (GetTickCount() - s_CarryWindedUntil[playerid] < 0)
		{
			return;
		}

		s_CarryWindedUntil[playerid] = 0;
	}

	if (!Carry_CanPace(playerid))
	{
		Carry_StopTrudge(playerid,false);
		s_CarryBreachSince[playerid] = 0;
		return;
	}

	new KEY:keys, updown, leftright, Float:vx, Float:vy, Float:vz;
	GetPlayerKeys(playerid,keys,updown,leftright);
	GetPlayerVelocity(playerid,vx,vy,vz);

	if (updown == 0 && leftright == 0)
	{
		Carry_StopTrudge(playerid,true);
		s_CarryBreachSince[playerid] = 0;
		return;
	}

	if ((keys & KEY_WALK) && s_CarryPace[playerid] == CARRY_PACE_WALK && Carry_GetLoad(playerid) == CARRY_LOAD_NONE)
	{
		if (!s_CarryTrudging[playerid])
		{
			s_CarryTrudging[playerid] = true;
			ApplyAnimation(playerid,CARRY_PACE_WALK_LIB,CARRY_PACE_WALK_ANIM,4.1,true,true,true,true,1,SYNC_ALL);
		}

		s_CarryBreachSince[playerid] = 0;
		return;
	}

	Carry_StopTrudge(playerid,true);

	if (!Carry_BreaksPace(s_CarryPace[playerid],keys,updown,leftright,VectorSize(vx,vy,0.0)))
	{
		s_CarryBreachSince[playerid] = 0;
		return;
	}

	new now = GetTickCount();

	if (s_CarryBreachSince[playerid] == 0)
	{
		s_CarryBreachSince[playerid] = now;
		return;
	}

	if (now - s_CarryBreachSince[playerid] >= CARRY_PACE_GRACE_MS)
	{
		Carry_Wind(playerid);
	}
}

forward bool:Carry_BusyCheck(playerid);

public bool:Carry_BusyCheck(playerid)
{
	return Carry_IsWinded(playerid) || (Util_IsValidPlayer(playerid) && s_CarryTrudging[playerid]);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CarryPace[playerid] = CARRY_PACE_FREE;
	s_CarryBreachSince[playerid] = 0;
	s_CarryWindedUntil[playerid] = 0;
	s_CarryNoticeAt[playerid] = 0;
	s_CarryTrudging[playerid] = false;
	s_CarryGrip[playerid] = CARRY_GRIP_NONE;
	s_CarryHold[playerid] = CARRY_HOLD_NONE;
}

hook OnPlayerUpdate(playerid)
{
	Carry_TickPace(playerid);
	Carry_TickHold(playerid);
}

hook Tick_OnPlayerSecond(playerid)
{
	if (Fly_IsActive(playerid))
	{
		return;
	}

	new mode = s_CarryHold[playerid], lib[16], name[24];

	if ((mode == CARRY_HOLD_STILL || mode == CARRY_HOLD_SHOULDER) && !Carry_IsHoldAnim(playerid,mode) && !Character_IsBusy(playerid) && Carry_GetHoldAnim(mode,lib,name))
	{
		ApplyAnimation(playerid,lib,name,4.1,true,true,true,false,0,SYNC_ALL);
	}
	else if (mode == CARRY_HOLD_MOVING && GetPlayerSpecialAction(playerid) != SPECIAL_ACTION_CARRY)
	{
		SetPlayerSpecialAction(playerid,SPECIAL_ACTION_CARRY);
	}
}
