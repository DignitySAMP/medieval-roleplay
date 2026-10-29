#define HORSES_HUD_COLOUR_LOW (0xB5543CFF)

static s_HorseHudHorse[MAX_PLAYERS] = {INVALID_HORSE_ID, ...};

stock Horses_Mood(horseid,playerid,dest[],size = sizeof(dest))
{
	if (Horses_GetHunger(horseid) < HORSES_HUNGRY_BAND)
	{
		strcopy(dest,"Hungry",size);
	}
	else if (Mount_GetHorse(playerid) == horseid && Mount_GetStamina(playerid) * 100 < Mount_GetStaminaMax(playerid) * 30)
	{
		strcopy(dest,"Tired",size);
	}
	else if (Horses_GetTier(horseid) <= HORSES_TIER_WARY)
	{
		strcopy(dest,"Nervous",size);
	}
	else if (Horses_GetThirst(horseid) < HORSES_THIRSTY_BAND || Horses_IsSick(horseid))
	{
		strcopy(dest,"Restless",size);
	}
	else
	{
		strcopy(dest,"Calm",size);
	}
}

stock Horses_StatusLine(horseid,playerid,dest[],size = sizeof(dest))
{
	Horses_Mood(horseid,playerid,dest,size);

	if (Horses_GetThirst(horseid) < HORSES_THIRSTY_BAND)
	{
		strcat(dest,", thirsty",size);
	}

	if (Calendar_GetSeason() == SEASON_WINTER && Calendar_IsNight() && Horses_GetLocation(horseid) == HORSES_PLACE_WORLD)
	{
		strcat(dest,", cold",size);
	}

	if (Horses_IsLame(horseid))
	{
		strcat(dest,", lame",size);
	}

	if (Horses_IsSick(horseid))
	{
		strcat(dest,", sick",size);
	}

	if (Horses_IsInFoal(horseid))
	{
		format(dest,size,"%s, in foal %dd",dest,Horses_DaysToFoal(horseid));
	}

	if (Horses_CannotGallop(horseid) && !Horses_IsFoal(horseid))
	{
		strcat(dest,", won't gallop",size);
	}
}

stock Horses_HudHorseFor(playerid)
{
	new horseid = Mount_GetHorse(playerid);

	if (Horses_IsOwned(horseid) && Horses_MayRide(playerid,horseid))
	{
		return horseid;
	}

	if (GetPlayerVirtualWorld(playerid) != 0)
	{
		return INVALID_HORSE_ID;
	}

	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	for (new i = 0;i < MAX_HORSES;i++)
	{
		if (!Horses_IsOwner(playerid,i) || Horse_GetRider(i) != INVALID_PLAYER_ID)
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:a;
		Horse_GetPos(i,x,y,z,a);

		if (VectorSize(px - x,py - y,pz - z) <= HORSES_HUD_RANGE)
		{
			return i;
		}
	}

	return INVALID_HORSE_ID;
}

stock Horses_HudUpdate(playerid)
{
	new horseid = Horses_HudHorseFor(playerid);

	if (horseid == INVALID_HORSE_ID || !Hud_IsShown(playerid) || Hud_IsSuspended(playerid) || Gui_IsBusy(playerid))
	{
		Hud_HideHorse(playerid);
		s_HorseHudHorse[playerid] = INVALID_HORSE_ID;
		return;
	}

	if (s_HorseHudHorse[playerid] != horseid)
	{
		Hud_HideHorse(playerid);
		s_HorseHudHorse[playerid] = horseid;
	}

	Hud_ShowHorse(playerid);
	new name[HORSES_NAME_LEN], text[64];
	Horses_GetHorseName(horseid,name);
	format(text,sizeof(text),"%s, %s",name,g_HorsesTierNames[Horses_GetTier(horseid)]);
	Hud_SetHorseText(playerid,HUD_HORSE_NAME,text);
	new Float:stamina = 100.0;

	if (Mount_GetHorse(playerid) == horseid)
	{
		stamina = float(Mount_GetStamina(playerid)) * 100.0 / float(max(Mount_GetStaminaMax(playerid),1));
	}

	new Float:hunger = Horses_GetHunger(horseid);
	Hud_SetHorseBar(playerid,HUD_HORSE_STAMINA,stamina);
	Hud_SetHorseBar(playerid,HUD_HORSE_HUNGER,hunger,hunger < HORSES_HUNGRY_BAND ? HORSES_HUD_COLOUR_LOW : 0);
	Hud_SetHorseBar(playerid,HUD_HORSE_CONDITION,Horses_GetCondition(horseid));
	Horses_StatusLine(horseid,playerid,text);
	Hud_SetHorseText(playerid,HUD_HORSE_STATUS,text);
}

Timer_Declare(Horses_HudTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid))
		{
			Horses_HudUpdate(playerid);
		}
		else if (Hud_IsHorseShown(playerid))
		{
			Hud_HideHorse(playerid);
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HorseHudHorse[playerid] = INVALID_HORSE_ID;
}
