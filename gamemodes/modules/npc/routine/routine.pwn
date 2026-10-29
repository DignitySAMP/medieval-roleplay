#define ROUTINE_BELL_RANGE (450.0)
#define ROUTINE_LATE_HOUR (23)

enum E_HOUR_NAME
{
	HOUR_NONE,
	HOUR_MATINS,
	HOUR_LAUDS,
	HOUR_PRIME,
	HOUR_TERCE,
	HOUR_SEXT,
	HOUR_NONES,
	HOUR_VESPERS,
	HOUR_COMPLINE,
	HOUR_LATE,
}

new const g_RoutineHourNames[E_HOUR_NAME][12] = {
	"",
	"Matins",
	"Lauds",
	"Prime",
	"Terce",
	"Sext",
	"Nones",
	"Vespers",
	"Compline",
	""
};

new const Float:g_RoutineBells[][3] = {
	{1035.0, -3144.9, 40.6},
	{707.0, -3603.0, 17.5}
};

forward E_HOUR_NAME:Routine_HourFor(hour);

stock bool:Routine_IsWinter()
{
	return Calendar_GetSeason() == SEASON_WINTER;
}

stock E_HOUR_NAME:Routine_HourAt(hour)
{
	if (Routine_IsWinter())
	{
		switch (hour)
		{
			case 2: return HOUR_MATINS;
			case 5: return HOUR_LAUDS;
			case 8: return HOUR_PRIME;
			case 12: return HOUR_SEXT;
			case 16: return HOUR_VESPERS;
			case 20: return HOUR_COMPLINE;
			case ROUTINE_LATE_HOUR: return HOUR_LATE;
		}

		return HOUR_NONE;
	}

	switch (hour)
	{
		case 2: return HOUR_MATINS;
		case 5: return HOUR_LAUDS;
		case 6: return HOUR_PRIME;
		case 9: return HOUR_TERCE;
		case 11: return HOUR_SEXT;
		case 13: return HOUR_NONES;
		case 18: return HOUR_VESPERS;
		case 20: return HOUR_COMPLINE;
		case ROUTINE_LATE_HOUR: return HOUR_LATE;
	}

	return HOUR_NONE;
}

stock E_HOUR_NAME:Routine_GetHour()
{
	return Routine_HourFor(Calendar_GetHour());
}

stock E_HOUR_NAME:Routine_HourFor(hour)
{
	for (new h = hour;h >= hour - 24;h--)
	{
		new E_HOUR_NAME:name = Routine_HourAt((h + 24) % 24);

		if (name != HOUR_NONE)
		{
			return name;
		}
	}

	return HOUR_COMPLINE;
}

stock Routine_GetHourName(E_HOUR_NAME:name,dest[],size = sizeof(dest))
{
	strcopy(dest,g_RoutineHourNames[name],size);
}

stock bool:Routine_IsMealHour()
{
	new E_HOUR_NAME:name = Routine_GetHour();
	return name == HOUR_SEXT || name == HOUR_VESPERS;
}

stock bool:Routine_IsBarred(hour)
{
	return hour >= 20 || hour < (Routine_IsWinter() ? 8 : 6);
}

static Routine_RingBells(E_HOUR_NAME:name)
{
	if (name == HOUR_LATE || name == HOUR_NONE)
	{
		return;
	}

	new text[64];
	format(text,sizeof(text),"The church bell rings for %s.",g_RoutineHourNames[name]);

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid))
		{
			continue;
		}

		for (new i = 0;i < sizeof(g_RoutineBells);i++)
		{
			if ((name == HOUR_MATINS || name == HOUR_LAUDS) && i == 0)
			{
				continue;
			}

			if (GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,ROUTINE_BELL_RANGE,g_RoutineBells[i][0],g_RoutineBells[i][1],g_RoutineBells[i][2]))
			{
				Gui_Notify(playerid,text);
				break;
			}
		}
	}
}

stock Routine_Refresh()
{
	new E_HOUR_NAME:name = Routine_GetHour();

	if (name == HOUR_LATE)
	{
		name = HOUR_COMPLINE;
	}

	new sprite[16];
	format(sprite,sizeof(sprite),"hour_%s",g_RoutineHourNames[name]);
	sprite[5] = tolower(sprite[5]);
	Hud_SetDisc(HUD_DISC_HOUR,sprite);
	Calendar_SetTitleSuffix(g_RoutineHourNames[name]);
}

forward Routine_OnKeyframe(hour,E_HOUR_NAME:name);

public Routine_OnKeyframe(hour,E_HOUR_NAME:name)
{
	return 1;
}

#include <pp-hooks>

hook Calendar_OnHour(hour)
{
	new E_HOUR_NAME:name = Routine_HourAt(hour);

	if (name == HOUR_NONE)
	{
		return;
	}

	Routine_Refresh();
	Routine_RingBells(name);
	pawn_call_public("Routine_OnKeyframe","dd",hour,_:name);
}

hook Calendar_OnSet()
{
	Routine_Refresh();
}

hook Calendar_OnSeason(season)
{
	#pragma unused season

	Routine_Refresh();
}
