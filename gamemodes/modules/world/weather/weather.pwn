#define WEATHER_SNOW_MODEL (18863)
#define WEATHER_SNOW_TICK_MS (250)
#define WEATHER_SNOW_FOLLOW (1.5)
#define WEATHER_SNOW_RANGE (300.0)
#define WEATHER_SNOW_START_CHANCE (30)
#define WEATHER_SNOW_MIN_MINUTES (15)
#define WEATHER_SNOW_MAX_MINUTES (45)

enum E_WEATHER_SNOW_MODE
{
	WEATHER_SNOW_AUTO,
	WEATHER_SNOW_ON,
	WEATHER_SNOW_OFF,
}

#define WEATHER_SNOW_ARCS (1)
#define WEATHER_SHELTER_MAX (8)

static const Float:s_WeatherSnowOffsets[WEATHER_SNOW_ARCS][4] = {
	{31.45, 4.6, -3.0, 0.0}
};

static Float:s_WeatherShelters[WEATHER_SHELTER_MAX][6];
static s_WeatherShelterCount;

static E_WEATHER_SNOW_MODE:s_WeatherSnowMode = WEATHER_SNOW_AUTO;
static bool:s_WeatherSnowing;
static s_WeatherSnowMinutesLeft;
static STREAMER_TAG_OBJECT:s_WeatherSnow[MAX_PLAYERS][WEATHER_SNOW_ARCS];
static Float:s_WeatherSnowAnchor[MAX_PLAYERS][3];

stock bool:Weather_IsSnowing()
{
	return s_WeatherSnowing;
}

stock bool:Weather_HasSnow(playerid)
{
	return Util_IsValidPlayer(playerid) && IsValidDynamicObject(s_WeatherSnow[playerid][0]);
}

static Weather_ClearSnow(playerid)
{
	for (new i = 0;i < WEATHER_SNOW_ARCS;i++)
	{
		if (IsValidDynamicObject(s_WeatherSnow[playerid][i]))
		{
			DestroyDynamicObject(s_WeatherSnow[playerid][i]);
		}

		s_WeatherSnow[playerid][i] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

stock Weather_AddShelter(Float:minX,Float:minY,Float:minZ,Float:maxX,Float:maxY,Float:maxZ)
{
	if (s_WeatherShelterCount >= WEATHER_SHELTER_MAX)
	{
		return -1;
	}

	s_WeatherShelters[s_WeatherShelterCount][0] = minX;
	s_WeatherShelters[s_WeatherShelterCount][1] = minY;
	s_WeatherShelters[s_WeatherShelterCount][2] = minZ;
	s_WeatherShelters[s_WeatherShelterCount][3] = maxX;
	s_WeatherShelters[s_WeatherShelterCount][4] = maxY;
	s_WeatherShelters[s_WeatherShelterCount][5] = maxZ;
	return s_WeatherShelterCount++;
}

stock bool:Weather_IsSheltered(Float:x,Float:y,Float:z)
{
	for (new i = 0;i < s_WeatherShelterCount;i++)
	{
		if (x >= s_WeatherShelters[i][0] && y >= s_WeatherShelters[i][1] && z >= s_WeatherShelters[i][2] && x <= s_WeatherShelters[i][3] && y <= s_WeatherShelters[i][4] && z <= s_WeatherShelters[i][5])
		{
			return true;
		}
	}

	return false;
}

static bool:Weather_WantsSnow(playerid)
{
	if (!s_WeatherSnowing || !Session_IsPlaying(playerid) || GetPlayerInterior(playerid) != 0 || Scene_IsActive(playerid))
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return !Weather_IsSheltered(x,y,z);
}

static Weather_PlaceSnow(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerCameraPos(playerid,x,y,z);

	if (!Weather_HasSnow(playerid))
	{
		for (new i = 0;i < WEATHER_SNOW_ARCS;i++)
		{
			s_WeatherSnow[playerid][i] = CreateDynamicObject(WEATHER_SNOW_MODEL,x + s_WeatherSnowOffsets[i][0],y + s_WeatherSnowOffsets[i][1],z + s_WeatherSnowOffsets[i][2],0.0,0.0,s_WeatherSnowOffsets[i][3],-1,-1,playerid,WEATHER_SNOW_RANGE,WEATHER_SNOW_RANGE);
		}

		Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
	}
	else
	{
		new Float:dx = x - s_WeatherSnowAnchor[playerid][0], Float:dy = y - s_WeatherSnowAnchor[playerid][1], Float:dz = z - s_WeatherSnowAnchor[playerid][2], Float:moved = VectorSize(dx,dy,dz);

		if (moved < WEATHER_SNOW_FOLLOW)
		{
			return;
		}

		for (new i = 0;i < WEATHER_SNOW_ARCS;i++)
		{
			MoveDynamicObject(s_WeatherSnow[playerid][i],x + s_WeatherSnowOffsets[i][0],y + s_WeatherSnowOffsets[i][1],z + s_WeatherSnowOffsets[i][2],moved / (float(WEATHER_SNOW_TICK_MS) / 1000.0));
		}
	}

	s_WeatherSnowAnchor[playerid][0] = x;
	s_WeatherSnowAnchor[playerid][1] = y;
	s_WeatherSnowAnchor[playerid][2] = z;
}

static Weather_SetSnowing(bool:isSnowing)
{
	if (s_WeatherSnowing == isSnowing)
	{
		return;
	}

	s_WeatherSnowing = isSnowing;
	pawn_call_public("Weather_OnSnowChanged","d",isSnowing);
}

stock Weather_SetSnowMode(E_WEATHER_SNOW_MODE:mode)
{
	s_WeatherSnowMode = mode;
	s_WeatherSnowMinutesLeft = mode == WEATHER_SNOW_ON ? WEATHER_SNOW_MIN_MINUTES : 0;

	switch (mode)
	{
		case WEATHER_SNOW_ON: Weather_SetSnowing(true);
		case WEATHER_SNOW_OFF: Weather_SetSnowing(false);
		default:
		{
			s_WeatherSnowMinutesLeft = 0;
			Weather_SetSnowing(false);
		}
	}
}

stock E_WEATHER_SNOW_MODE:Weather_GetSnowMode()
{
	return s_WeatherSnowMode;
}

forward Weather_OnSnowChanged(isSnowing);

public Weather_OnSnowChanged(isSnowing)
{
	return 1;
}

forward Weather_SnowTick();

public Weather_SnowTick()
{
	foreach (new playerid : Player)
	{
		if (Weather_WantsSnow(playerid))
		{
			Weather_PlaceSnow(playerid);
		}
		else if (Weather_HasSnow(playerid))
		{
			Weather_ClearSnow(playerid);
		}
	}

	return 1;
}

stock Weather_RunMinute()
{
	if (s_WeatherSnowMode == WEATHER_SNOW_ON)
	{
		if (--s_WeatherSnowMinutesLeft <= 0)
		{
			Weather_SetSnowMode(WEATHER_SNOW_AUTO);
		}

		return 1;
	}

	if (s_WeatherSnowMode != WEATHER_SNOW_AUTO)
	{
		return 1;
	}

	if (Calendar_GetSeason() != SEASON_WINTER)
	{
		Weather_SetSnowing(false);
		return 1;
	}

	if (s_WeatherSnowing)
	{
		if (--s_WeatherSnowMinutesLeft <= 0)
		{
			Weather_SetSnowing(false);
		}

		return 1;
	}

	if (random(WEATHER_SNOW_START_CHANCE) == 0)
	{
		s_WeatherSnowMinutesLeft = WEATHER_SNOW_MIN_MINUTES + random(WEATHER_SNOW_MAX_MINUTES - WEATHER_SNOW_MIN_MINUTES + 1);
		Weather_SetSnowing(true);
	}

	return 1;
}

forward Weather_MinuteTick();

public Weather_MinuteTick()
{
	return Weather_RunMinute();
}

CMD<ADMIN_LEVEL_TRIAL>:snow(cmdid, playerid, params[])
{
	if (params[0] == EOS || !strcmp(params,"on",true))
	{
		Weather_SetSnowMode(WEATHER_SNOW_ON);
	}
	else if (!strcmp(params,"off",true))
	{
		Weather_SetSnowMode(WEATHER_SNOW_OFF);
	}
	else if (!strcmp(params,"auto",true))
	{
		Weather_SetSnowMode(WEATHER_SNOW_AUTO);
	}
	else
	{
		Command_Usage(playerid,cmdid,"<on|off|auto>");
		return 1;
	}

	if (s_WeatherSnowMode == WEATHER_SNOW_ON)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("Snow will fall for %d minutes, then return to automatic winter weather.",WEATHER_SNOW_MIN_MINUTES));
	}
	else
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,s_WeatherSnowMode == WEATHER_SNOW_OFF ? ("Snow is off.") : ("Snow is on auto."));
	}
	return 1;
}

#include <pp-hooks>

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Weather_ClearSnow(playerid);
}
