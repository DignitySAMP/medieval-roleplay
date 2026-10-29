#define SCREENFADE_WIDTH (640.0)
#define SCREENFADE_HEIGHT (480.0)
#define SCREENFADE_LETTER_HEIGHT (50.0)
#define SCREENFADE_CLEAR (0x00000000)

enum E_SCREENFADE
{
	E_SCREENFADE_STEPS,
	E_SCREENFADE_STEP,
	E_SCREENFADE_FROM,
	E_SCREENFADE_TO,
	E_SCREENFADE_TIMER,
}

static Text:s_ScreenFadeBox;
static s_ScreenFadeColour[MAX_PLAYERS];
static s_ScreenFade[MAX_PLAYERS][E_SCREENFADE];

static ScreenFade_Paint(playerid,colour)
{
	s_ScreenFadeColour[playerid] = colour;
	TextDrawBoxColour(s_ScreenFadeBox,colour);
	TextDrawShowForPlayer(playerid,s_ScreenFadeBox);
}

static ScreenFade_KillTimer(playerid)
{
	if (s_ScreenFade[playerid][E_SCREENFADE_TIMER] != -1)
	{
		KillTimer(s_ScreenFade[playerid][E_SCREENFADE_TIMER]);
		s_ScreenFade[playerid][E_SCREENFADE_TIMER] = -1;
	}
}

stock ScreenFade_GetColour(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_ScreenFadeColour[playerid] : SCREENFADE_CLEAR;
}

stock bool:ScreenFade_IsFading(playerid)
{
	return Util_IsValidPlayer(playerid) && s_ScreenFade[playerid][E_SCREENFADE_TIMER] != -1;
}

stock bool:ScreenFade_Set(playerid,colour)
{
	if (!Util_IsValidPlayer(playerid) || !IsPlayerConnected(playerid))
	{
		return false;
	}

	ScreenFade_KillTimer(playerid);
	ScreenFade_Paint(playerid,colour);
	return true;
}

stock bool:ScreenFade_Stop(playerid)
{
	if (!ScreenFade_IsFading(playerid))
	{
		return false;
	}

	ScreenFade_KillTimer(playerid);
	return true;
}

stock bool:ScreenFade_Start(playerid,colour,time,steps)
{
	if (!Util_IsValidPlayer(playerid) || !IsPlayerConnected(playerid) || steps < 1 || time < 0)
	{
		return false;
	}

	ScreenFade_KillTimer(playerid);
	s_ScreenFade[playerid][E_SCREENFADE_FROM] = s_ScreenFadeColour[playerid];
	s_ScreenFade[playerid][E_SCREENFADE_TO] = colour;
	s_ScreenFade[playerid][E_SCREENFADE_STEPS] = steps;
	s_ScreenFade[playerid][E_SCREENFADE_STEP] = 0;
	s_ScreenFade[playerid][E_SCREENFADE_TIMER] = SetTimerEx("ScreenFade_Tick",time / steps,true,"d",playerid);
	return true;
}

forward ScreenFade_OnComplete(playerid);

public ScreenFade_OnComplete(playerid)
{
	return 1;
}

forward ScreenFade_Tick(playerid);

public ScreenFade_Tick(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		ScreenFade_KillTimer(playerid);
		return 1;
	}

	if (s_ScreenFade[playerid][E_SCREENFADE_STEP] >= s_ScreenFade[playerid][E_SCREENFADE_STEPS])
	{
		ScreenFade_KillTimer(playerid);
		pawn_call_public("ScreenFade_OnComplete","d",playerid);
		return 1;
	}

	new Float:progress = float(s_ScreenFade[playerid][E_SCREENFADE_STEP] + 1) / float(s_ScreenFade[playerid][E_SCREENFADE_STEPS]);
	ScreenFade_Paint(playerid,InterpolateColours(s_ScreenFade[playerid][E_SCREENFADE_FROM],s_ScreenFade[playerid][E_SCREENFADE_TO],progress));
	s_ScreenFade[playerid][E_SCREENFADE_STEP]++;
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	s_ScreenFadeBox = TextDrawCreate(0.0,0.0,"_");
	TextDrawTextSize(s_ScreenFadeBox,SCREENFADE_WIDTH,SCREENFADE_HEIGHT);
	TextDrawLetterSize(s_ScreenFadeBox,0.0,SCREENFADE_LETTER_HEIGHT);
	TextDrawUseBox(s_ScreenFadeBox,true);
}

hook OnPlayerConnect(playerid)
{
	s_ScreenFade[playerid][E_SCREENFADE_TIMER] = -1;
	ScreenFade_Paint(playerid,SCREENFADE_CLEAR);
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	ScreenFade_KillTimer(playerid);
}
