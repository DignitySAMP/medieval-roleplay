#define PLAYERSTATE_NAME_LENGTH (24)

stock PlayerState_GetName(PLAYER_STATE:playerState,dest[],size = sizeof (dest))
{
	switch (playerState)
	{
		case PLAYER_STATE_NONE:
		{
			strcopy(dest,"none",size);
		}
		case PLAYER_STATE_ONFOOT:
		{
			strcopy(dest,"on foot",size);
		}
		case PLAYER_STATE_DRIVER:
		{
			strcopy(dest,"driving",size);
		}
		case PLAYER_STATE_PASSENGER:
		{
			strcopy(dest,"passenger",size);
		}
		case PLAYER_STATE_EXIT_VEH:
		{
			strcopy(dest,"exiting vehicle",size);
		}
		case PLAYER_STATE_WASTED:
		{
			strcopy(dest,"wasted",size);
		}
		case PLAYER_STATE_SPAWNED:
		{
			strcopy(dest,"spawned",size);
		}
		case PLAYER_STATE_SPECTATING:
		{
			strcopy(dest,"spectating",size);
		}
		default:
		{
			strcopy(dest,"unknown",size);
		}
	}
}

stock PlayerState_GetCameraModeName(CAM_MODE:cameraMode,dest[],size = sizeof (dest))
{
	switch (cameraMode)
	{
		case CAM_MODE_NONE:
		{
			strcopy(dest,"none",size);
		}
		case CAM_MODE_BEHINDCAR:
		{
			strcopy(dest,"behind car",size);
		}
		case CAM_MODE_FOLLOWPED:
		{
			strcopy(dest,"follow ped",size);
		}
		case CAM_MODE_SNIPER:
		{
			strcopy(dest,"sniper scope",size);
		}
		case CAM_MODE_ROCKETLAUNCHER:
		{
			strcopy(dest,"rocket scope",size);
		}
		case CAM_MODE_FIXED:
		{
			strcopy(dest,"fixed",size);
		}
		case CAM_MODE_1STPERSON:
		{
			strcopy(dest,"first person",size);
		}
		case CAM_MODE_CAM_ON_A_STRING:
		{
			strcopy(dest,"vehicle chase",size);
		}
		case CAM_MODE_BEHINDBOAT:
		{
			strcopy(dest,"behind boat",size);
		}
		case CAM_MODE_CAMERA:
		{
			strcopy(dest,"camera weapon",size);
		}
		case CAM_MODE_ROCKETLAUNCHER_HS:
		{
			strcopy(dest,"heatseeker scope",size);
		}
		case CAM_MODE_AIMWEAPON:
		{
			strcopy(dest,"aiming",size);
		}
		case CAM_MODE_AIMWEAPON_FROMCAR:
		{
			strcopy(dest,"aiming in vehicle",size);
		}
		case CAM_MODE_DW_HELI_CHASE:
		{
			strcopy(dest,"helicopter chase",size);
		}
		default:
		{
			strcopy(dest,"unknown",size);
		}
	}
}

stock PlayerState_GetSpecialActionName(SPECIAL_ACTION:specialAction,dest[],size = sizeof (dest))
{
	switch (specialAction)
	{
		case SPECIAL_ACTION_NONE:
		{
			strcopy(dest,"none",size);
		}
		case SPECIAL_ACTION_DUCK:
		{
			strcopy(dest,"ducking",size);
		}
		case SPECIAL_ACTION_USEJETPACK:
		{
			strcopy(dest,"jetpack",size);
		}
		case SPECIAL_ACTION_ENTER_VEHICLE:
		{
			strcopy(dest,"entering vehicle",size);
		}
		case SPECIAL_ACTION_EXIT_VEHICLE:
		{
			strcopy(dest,"exiting vehicle",size);
		}
		case SPECIAL_ACTION_DANCE1 .. SPECIAL_ACTION_DANCE4:
		{
			strcopy(dest,"dancing",size);
		}
		case SPECIAL_ACTION_HANDSUP:
		{
			strcopy(dest,"hands up",size);
		}
		case SPECIAL_ACTION_USECELLPHONE:
		{
			strcopy(dest,"on the phone",size);
		}
		case SPECIAL_ACTION_SITTING:
		{
			strcopy(dest,"sitting",size);
		}
		case SPECIAL_ACTION_STOPUSECELLPHONE:
		{
			strcopy(dest,"putting phone away",size);
		}
		case SPECIAL_ACTION_DRINK_BEER:
		{
			strcopy(dest,"drinking beer",size);
		}
		case SPECIAL_ACTION_SMOKE_CIGGY:
		{
			strcopy(dest,"smoking",size);
		}
		case SPECIAL_ACTION_DRINK_WINE:
		{
			strcopy(dest,"drinking wine",size);
		}
		case SPECIAL_ACTION_DRINK_SPRUNK:
		{
			strcopy(dest,"drinking sprunk",size);
		}
		case SPECIAL_ACTION_CUFFED:
		{
			strcopy(dest,"cuffed",size);
		}
		case SPECIAL_ACTION_CARRY:
		{
			strcopy(dest,"carrying",size);
		}
		case SPECIAL_ACTION_PISSING:
		{
			strcopy(dest,"pissing",size);
		}
		default:
		{
			strcopy(dest,"unknown",size);
		}
	}
}

stock PlayerState_GetWeaponStateName(WEAPONSTATE:weaponState,dest[],size = sizeof (dest))
{
	switch (weaponState)
	{
		case WEAPONSTATE_NO_BULLETS:
		{
			strcopy(dest,"empty",size);
		}
		case WEAPONSTATE_LAST_BULLET:
		{
			strcopy(dest,"last bullet",size);
		}
		case WEAPONSTATE_MORE_BULLETS:
		{
			strcopy(dest,"loaded",size);
		}
		case WEAPONSTATE_RELOADING:
		{
			strcopy(dest,"reloading",size);
		}
		default:
		{
			strcopy(dest,"unknown",size);
		}
	}
}

stock bool:PlayerState_IsInVehicle(playerid)
{
	new PLAYER_STATE:playerState = GetPlayerState(playerid);

	return playerState == PLAYER_STATE_DRIVER || playerState == PLAYER_STATE_PASSENGER;
}

stock bool:PlayerState_IsAiming(playerid)
{
	new CAM_MODE:cameraMode = GetPlayerCameraMode(playerid);

	return cameraMode == CAM_MODE_AIMWEAPON || cameraMode == CAM_MODE_AIMWEAPON_FROMCAR || cameraMode == CAM_MODE_SNIPER || cameraMode == CAM_MODE_ROCKETLAUNCHER || cameraMode == CAM_MODE_ROCKETLAUNCHER_HS;
}
