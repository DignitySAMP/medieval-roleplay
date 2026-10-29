static STREAMER_TAG_OBJECT:s_LightMoonObjects[MAX_PLAYERS] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static s_LightMoonModels[MAX_PLAYERS];
static bool:s_LightMoonHidden[MAX_PLAYERS];

stock bool:Light_GetMoonSky(&Float:azimuth,&Float:altitude)
{
	new E_MOON:moon = Calendar_GetMoon();
	new transit = (720 + _:moon * 1440 / CALENDAR_MOON_PHASES) % 1440;
	new Float:hourAngle = float((Calendar_GetMinuteOfDay() - transit + 2160) % 1440 - 720) * 360.0 / 1440.0;
	altitude = LIGHT_MOON_MAX_ALTITUDE * floatcos(hourAngle,degrees);
	azimuth = hourAngle;
	return altitude > 2.0;
}

stock Light_GetMoonModel()
{
	return g_LightMoonModels[_:Calendar_GetMoon() % CALENDAR_MOON_PHASES];
}

stock STREAMER_TAG_OBJECT:Light_GetMoonObject(playerid)
{
	return s_LightMoonObjects[playerid];
}

stock bool:Light_IsMoonShown(playerid)
{
	return bool:IsValidDynamicObject(s_LightMoonObjects[playerid]);
}

stock Light_SetMoonHidden(playerid,bool:isHidden)
{
	s_LightMoonHidden[playerid] = isHidden;
	Light_UpdateMoon(playerid);
}

static Light_ClearMoon(playerid)
{
	if (IsValidDynamicObject(s_LightMoonObjects[playerid]))
	{
		DestroyDynamicObject(s_LightMoonObjects[playerid]);
	}

	s_LightMoonObjects[playerid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_LightMoonModels[playerid] = 0;
}

stock Light_UpdateMoon(playerid)
{
	new Float:azimuth, Float:altitude;

	if (s_LightMoonHidden[playerid] || !Session_IsPlaying(playerid) || GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0 || !Calendar_IsNight() || !Light_GetMoonSky(azimuth,altitude))
	{
		Light_ClearMoon(playerid);
		return;
	}

	new Float:cameraX, Float:cameraY, Float:cameraZ;
	GetPlayerCameraPos(playerid,cameraX,cameraY,cameraZ);

	new Float:flat = floatcos(altitude,degrees);
	new Float:x = cameraX - floatsin(azimuth,degrees) * flat * LIGHT_MOON_DISTANCE;
	new Float:y = cameraY - floatcos(azimuth,degrees) * flat * LIGHT_MOON_DISTANCE;
	new Float:z = cameraZ + floatsin(altitude,degrees) * LIGHT_MOON_DISTANCE;
	new Float:yaw = atan2(cameraX - x,-(cameraY - y));
	new model = Light_GetMoonModel();

	if (model != s_LightMoonModels[playerid] || !IsValidDynamicObject(s_LightMoonObjects[playerid]))
	{
		Light_ClearMoon(playerid);
		s_LightMoonModels[playerid] = model;
		s_LightMoonObjects[playerid] = CreateDynamicObject(model,x,y,z,LIGHT_MOON_TILT_SIGN * altitude,0.0,yaw,0,0,playerid,LIGHT_MOON_DRAW,LIGHT_MOON_DRAW);
		Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
		return;
	}

	SetDynamicObjectPos(s_LightMoonObjects[playerid],x,y,z);
	SetDynamicObjectRot(s_LightMoonObjects[playerid],LIGHT_MOON_TILT_SIGN * altitude,0.0,yaw);
}

Timer_Declare(Light_MoonTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Light_UpdateMoon(playerid);
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LightMoonObjects[playerid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_LightMoonModels[playerid] = 0;
	s_LightMoonHidden[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Light_ClearMoon(playerid);
}
