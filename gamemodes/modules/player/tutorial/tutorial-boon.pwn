#define TUTORIAL_BOON_MINUTES (60)
#define TUTORIAL_BOON_TICK_MS (15000)
#define TUTORIAL_BOON_KEY "newcomer_warmth"

static Tutorial_UpdateBoon(playerid)
{
	if (!Session_IsPlaying(playerid) || !Talent_IsLoaded(playerid))
	{
		return;
	}

	new left = TUTORIAL_BOON_MINUTES - Talent_GetActiveMinutes(playerid);

	if (left > 0)
	{
		Warmth_SetBoon(playerid,true);
		Buff_Set(playerid,TUTORIAL_BOON_KEY,"Newcomer's warmth","You won't get cold during your first hour of playtime.",left * 60,TUTORIAL_BOON_MINUTES * 60);
		return;
	}

	if (Warmth_HasBoon(playerid))
	{
		Warmth_SetBoon(playerid,false);
		Buff_Clear(playerid,TUTORIAL_BOON_KEY);
		Gui_Notify(playerid,"Your newcomer's warmth has worn off. Dress for the weather from now on.");
	}
}

Timer_Declare(Tutorial_BoonTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Tutorial_UpdateBoon(playerid);
		}
	}
}

#include <pp-hooks>

hook Talent_OnLoaded(playerid)
{
	Tutorial_UpdateBoon(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		Warmth_SetBoon(playerid,false);
		Buff_Clear(playerid,TUTORIAL_BOON_KEY);
	}
}
