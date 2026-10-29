#define FAITH_PRAYER_LINE_MS (4000)
#define FAITH_PRAYER_RANGE (1.4)
#define FAITH_PRAYER_STRAY (1.5)
#define FAITH_PRAYER_PROMPT_MS (400)
#define FAITH_PRAYER_ROWS (5)
#define FAITH_BEADS (12)

enum E_FAITH_SPOT
{
	E_FAITH_SPOT_CHURCH,
	Float:E_FAITH_SPOT_POS[4],
	E_FAITH_SPOT_WORLD,
	E_FAITH_SPOT_INTERIOR,
}

static const s_FaithSpots[][E_FAITH_SPOT] = {
	{0, {714.05, -3601.3, 18.5, 270.0}, 0, 0},
	{0, {714.05, -3604.7, 18.5, 270.0}, 0, 0}
};

enum E_FAITH_PRAYER
{
	E_FAITH_PRAYER_SPOT,
	E_FAITH_PRAYER_BEAD,
	E_FAITH_PRAYER_LINE,
	E_FAITH_PRAYER_LINE_MS,
	E_FAITH_PRAYER_TOKEN,
	E_FAITH_PRAYER_INFOBOX,
	bool:E_FAITH_PRAYER_WAITING,
}

static s_FaithPrayer[MAX_PLAYERS][E_FAITH_PRAYER];
static s_FaithPrayerPrompt[MAX_PLAYERS];
static s_FaithPrayerPromptInfobox[MAX_PLAYERS];
static s_FaithPrayerTexts[3] = {-1, -1, -1};

stock Faith_CountPrayerSpots()
{
	return sizeof(s_FaithSpots);
}

stock bool:Faith_IsPraying(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FaithPrayer[playerid][E_FAITH_PRAYER_SPOT] != -1;
}

stock Faith_GetBead(playerid)
{
	return Faith_IsPraying(playerid) ? s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD] : -1;
}

stock bool:Faith_IsBeadWaiting(playerid)
{
	return Faith_IsPraying(playerid) && s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING];
}

stock Faith_FindPrayerSpot(playerid,Float:range = FAITH_PRAYER_RANGE)
{
	new world = GetPlayerVirtualWorld(playerid), interior = GetPlayerInterior(playerid);

	for (new i = 0;i < sizeof(s_FaithSpots);i++)
	{
		if (s_FaithSpots[i][E_FAITH_SPOT_WORLD] == world && s_FaithSpots[i][E_FAITH_SPOT_INTERIOR] == interior && IsPlayerInRangeOfPoint(playerid,range,s_FaithSpots[i][E_FAITH_SPOT_POS][0],s_FaithSpots[i][E_FAITH_SPOT_POS][1],s_FaithSpots[i][E_FAITH_SPOT_POS][2]))
		{
			return i;
		}
	}

	return -1;
}

static bool:Faith_IsSpotQuiet(spot)
{
	return !Faith_IsServiceRunning() || s_FaithSpots[spot][E_FAITH_SPOT_CHURCH] != Faith_GetServiceChurch();
}

static Faith_BeadText(bead)
{
	if (s_FaithPrayerTexts[0] == -1)
	{
		s_FaithPrayerTexts[0] = Faith_FindText("pater-noster");
		s_FaithPrayerTexts[1] = Faith_FindText("ave-maria-medieval");
		s_FaithPrayerTexts[2] = Faith_FindText("gloria-patri");
	}

	if (bead == 0)
	{
		return s_FaithPrayerTexts[0];
	}

	return bead == FAITH_BEADS - 1 ? s_FaithPrayerTexts[2] : s_FaithPrayerTexts[1];
}

static Faith_ShowBead(playerid,const latin[],const footer[])
{
	new title[40], text[FAITH_LINE_LEN * 2];
	format(title,sizeof(title),"Paternoster beads, %d of %d",s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD] + 1,FAITH_BEADS);
	format(text,sizeof(text),"~y~%s~n~~n~~w~%s",latin,footer);
	s_FaithPrayer[playerid][E_FAITH_PRAYER_INFOBOX] = Infobox_Show(playerid,title,text,FAITH_PRAYER_ROWS);
}

static Faith_ClearPrayerPrompt(playerid)
{
	if (s_FaithPrayerPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_FaithPrayerPromptInfobox[playerid]);
	}

	s_FaithPrayerPrompt[playerid] = -1;
	s_FaithPrayerPromptInfobox[playerid] = 0;
}

stock Faith_UpdatePrayerPrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Faith_IsPraying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || Wounds_IsDown(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Faith_ClearPrayerPrompt(playerid);
		return;
	}

	new spot = Faith_FindPrayerSpot(playerid);

	if (spot == -1 || !Faith_IsSpotQuiet(spot))
	{
		Faith_ClearPrayerPrompt(playerid);
		return;
	}

	if (spot == s_FaithPrayerPrompt[playerid] && Infobox_IsShown(playerid,s_FaithPrayerPromptInfobox[playerid]))
	{
		return;
	}

	s_FaithPrayerPrompt[playerid] = spot;
	s_FaithPrayerPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_FaithPrayerPromptInfobox[playerid],"Kneeler",Faith_HasPrayedToday(playerid) ? ("Press Y to kneel and pray the beads. You've already prayed a round today, so this one is for the soul alone.") : ("Press Y to kneel and pray the beads: a Pater Noster, ten Aves and a Gloria. The first round each day holds back your years a little."),3);
}

static Faith_SchedulePrayer(playerid)
{
	SetTimerEx("Faith_PrayerTick",s_FaithPrayer[playerid][E_FAITH_PRAYER_LINE_MS],false,"dd",playerid,s_FaithPrayer[playerid][E_FAITH_PRAYER_TOKEN]);
}

stock Faith_PrayerStep(playerid)
{
	if (!Faith_IsPraying(playerid) || s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING])
	{
		return;
	}

	new text = Faith_BeadText(s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD]), kind, season, count, bool:isBilingual, latin[FAITH_LINE_LEN], english[FAITH_LINE_LEN];

	if (!Faith_GetTextInfo(text,kind,season,count,isBilingual))
	{
		return;
	}

	#pragma unused kind, season
	new at = s_FaithPrayer[playerid][E_FAITH_PRAYER_LINE];

	if (at >= count)
	{
		s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING] = true;
		Faith_ShowBead(playerid,"Amen.",s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD] == FAITH_BEADS - 1 ? ("Press ~y~Y~w~ to move the last bead and rise.  ~y~N~w~ stands up.") : ("Press ~y~Y~w~ to move the bead.  ~y~N~w~ stands up."));
		return;
	}

	Faith_GetTextLine(text,at,latin);

	if (isBilingual)
	{
		Faith_GetTextLine(text,at + 1,english);
		Gui_Notify(playerid,english);
	}

	s_FaithPrayer[playerid][E_FAITH_PRAYER_LINE] = at + (isBilingual ? 2 : 1);
	Faith_ShowBead(playerid,latin,"~y~N~w~ stands up.");
	Faith_SchedulePrayer(playerid);
}

stock bool:Faith_StartPrayer(playerid,spot,lineMs = FAITH_PRAYER_LINE_MS)
{
	if (!Faith_IsLoaded(playerid) || !Session_IsPlaying(playerid) || Faith_IsPraying(playerid) || spot < 0 || spot >= sizeof(s_FaithSpots) || !Faith_IsSpotQuiet(spot))
	{
		return false;
	}

	Faith_ClearPrayerPrompt(playerid);
	SetPlayerPos(playerid,s_FaithSpots[spot][E_FAITH_SPOT_POS][0],s_FaithSpots[spot][E_FAITH_SPOT_POS][1],s_FaithSpots[spot][E_FAITH_SPOT_POS][2]);
	SetPlayerFacingAngle(playerid,s_FaithSpots[spot][E_FAITH_SPOT_POS][3]);
	ApplyAnimation(playerid,"CAMERA","CAMCRCH_IDLELOOP",4.1,true,false,false,true,0,SYNC_ALL);
	s_FaithPrayer[playerid][E_FAITH_PRAYER_SPOT] = spot;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD] = 0;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_LINE] = 0;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_LINE_MS] = max(lineMs,10);
	s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING] = false;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_TOKEN]++;
	Faith_PrayerStep(playerid);
	return true;
}

static Faith_EndPrayer(playerid)
{
	s_FaithPrayer[playerid][E_FAITH_PRAYER_SPOT] = -1;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING] = false;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_TOKEN]++;

	if (s_FaithPrayer[playerid][E_FAITH_PRAYER_INFOBOX] != 0)
	{
		Infobox_Hide(playerid,s_FaithPrayer[playerid][E_FAITH_PRAYER_INFOBOX]);
	}

	s_FaithPrayer[playerid][E_FAITH_PRAYER_INFOBOX] = 0;
}

stock Faith_StopPrayer(playerid,bool:quiet = false)
{
	if (!Faith_IsPraying(playerid))
	{
		return;
	}

	Faith_EndPrayer(playerid);

	if (!quiet)
	{
		ClearAnimations(playerid,SYNC_ALL);
		Gui_Notify(playerid,"You get up from the kneeler and put the beads away.");
	}
}

static Faith_FinishPrayer(playerid)
{
	new spot = s_FaithPrayer[playerid][E_FAITH_PRAYER_SPOT], bool:hadPrayed = Faith_HasPrayedToday(playerid);
	Faith_EndPrayer(playerid);
	ClearAnimations(playerid,SYNC_ALL);

	new minutes = hadPrayed ? 0 : Faith_PayShrine(playerid);

	if (minutes > 0)
	{
		Gui_Notify(playerid,"You move the last bead and rise. Your years pass a little more slowly for it.");
	}
	else if (hadPrayed)
	{
		Gui_Notify(playerid,"You move the last bead and rise. Only the first round each day holds back your years.");
	}
	else
	{
		Gui_Notify(playerid,"You move the last bead and rise. Your years already pass as slowly as devotion allows today.");
	}

	pawn_call_public("Faith_OnPrayer","dd",playerid,spot);
}

stock bool:Faith_MoveBead(playerid)
{
	if (!Faith_IsBeadWaiting(playerid))
	{
		return false;
	}

	if (s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD] >= FAITH_BEADS - 1)
	{
		Faith_FinishPrayer(playerid);
		return true;
	}

	s_FaithPrayer[playerid][E_FAITH_PRAYER_BEAD]++;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_LINE] = 0;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING] = false;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_TOKEN]++;
	Faith_PrayerStep(playerid);
	return true;
}

forward Faith_PrayerTick(playerid,token);

public Faith_PrayerTick(playerid,token)
{
	if (!IsPlayerConnected(playerid) || !Faith_IsPraying(playerid) || s_FaithPrayer[playerid][E_FAITH_PRAYER_TOKEN] != token)
	{
		return 1;
	}

	new spot = s_FaithPrayer[playerid][E_FAITH_PRAYER_SPOT];

	if (!IsPlayerInRangeOfPoint(playerid,FAITH_PRAYER_STRAY,s_FaithSpots[spot][E_FAITH_SPOT_POS][0],s_FaithSpots[spot][E_FAITH_SPOT_POS][1],s_FaithSpots[spot][E_FAITH_SPOT_POS][2]))
	{
		Faith_StopPrayer(playerid);
		return 1;
	}

	Faith_PrayerStep(playerid);
	return 1;
}

forward Faith_OnPrayer(playerid,spot);

public Faith_OnPrayer(playerid,spot)
{
	return 1;
}

forward Faith_PrayerPromptTick();

public Faith_PrayerPromptTick()
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Faith_UpdatePrayerPrompt(playerid);
			Faith_UpdateFontPrompt(playerid);
			Infirmary_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward bool:Faith_PrayerPromptContext(playerid);

public bool:Faith_PrayerPromptContext(playerid)
{
	return s_FaithPrayerPrompt[playerid] != -1 && !Faith_IsPraying(playerid) && !Combat_IsInMode(playerid);
}

forward bool:Faith_PrayerContext(playerid);

public bool:Faith_PrayerContext(playerid)
{
	return Faith_IsPraying(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_FaithPrayer[playerid][E_FAITH_PRAYER_SPOT] = -1;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_WAITING] = false;
	s_FaithPrayer[playerid][E_FAITH_PRAYER_INFOBOX] = 0;
	s_FaithPrayerPrompt[playerid] = -1;
	s_FaithPrayerPromptInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Faith_StopPrayer(playerid,true);
	s_FaithPrayerPrompt[playerid] = -1;
	s_FaithPrayerPromptInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (Faith_IsPraying(playerid))
	{
		if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES))
		{
			Faith_MoveBead(playerid);
		}
		else if ((newkeys & KEY_NO) && !(oldkeys & KEY_NO))
		{
			Faith_StopPrayer(playerid);
		}
	}
	else if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && s_FaithPrayerPrompt[playerid] != -1 && !Infobox_IsPromptBlocked(playerid,s_FaithPrayerPromptInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		Faith_StartPrayer(playerid,s_FaithPrayerPrompt[playerid]);
	}
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid, reason

	Faith_StopPrayer(playerid,true);
}

hook Combat_OnStruckDown(playerid)
{
	Faith_StopPrayer(playerid,true);
}

hook Combat_OnHit(attackerid,targetid,weapon,Float:damage)
{
	#pragma unused attackerid, weapon, damage

	Faith_StopPrayer(targetid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		Faith_StopPrayer(playerid,true);
	}
}
