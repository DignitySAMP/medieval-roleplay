enum _:E_MOVE_STATE
{
	MOVE_STATE_UNKNOWN = 0,
	MOVE_STATE_IDLE,
	MOVE_STATE_SITTING,
	MOVE_STATE_CROUCHING,
	MOVE_STATE_JUMPING,
	MOVE_STATE_WALKING,
	MOVE_STATE_RUNNING,
	MOVE_STATE_STOPPING,
	MOVE_STATE_SPRINTING,
	MOVE_STATE_CLIMBING,
	MOVE_STATE_FALLING,
	MOVE_STATE_LANDING,
	MOVE_STATE_SWIMMING,
	MOVE_STATE_DIVING
}

static const s_MoveStateNames[E_MOVE_STATE][12] = {
	"unknown",
	"idle",
	"sitting",
	"crouching",
	"jumping",
	"walking",
	"running",
	"stopping",
	"sprinting",
	"climbing",
	"falling",
	"landing",
	"swimming",
	"diving"
};

stock Movement_GetState(playerid)
{
	new animidx = GetPlayerAnimationIndex(playerid);

	switch (animidx)
	{
		case 1189:
		{
			return MOVE_STATE_IDLE;
		}
		case 43:
		{
			return MOVE_STATE_SITTING;
		}
		case 1159, 1274:
		{
			return MOVE_STATE_CROUCHING;
		}
		case 1195, 1197, 1198:
		{
			return MOVE_STATE_JUMPING;
		}
		case 1231:
		{
			new t_KEY:keys, updown, leftright;

			GetPlayerKeys(playerid,keys,updown,leftright);

			if (keys & KEY_WALK)
			{
				return MOVE_STATE_WALKING;
			}

			if (keys & KEY_SPRINT)
			{
				return MOVE_STATE_SPRINTING;
			}

			if (keys & KEY_JUMP)
			{
				return MOVE_STATE_JUMPING;
			}

			return MOVE_STATE_RUNNING;
		}
		case 1234, 1235:
		{
			return MOVE_STATE_STOPPING;
		}
		case 1196, 1266:
		{
			return MOVE_STATE_SPRINTING;
		}
		case 1061 .. 1067:
		{
			return MOVE_STATE_CLIMBING;
		}
		case 1130, 1132, 1250:
		{
			return MOVE_STATE_FALLING;
		}
		case 1129, 1133, 1208:
		{
			return MOVE_STATE_LANDING;
		}
		case 1538, 1539, 1542:
		{
			return MOVE_STATE_SWIMMING;
		}
		case 1540, 1541, 1544:
		{
			return MOVE_STATE_DIVING;
		}
	}

	return MOVE_STATE_UNKNOWN;
}

stock bool:Movement_IsInWaterState(playerid)
{
	new moveState = Movement_GetState(playerid);

	return moveState == MOVE_STATE_SWIMMING || moveState == MOVE_STATE_DIVING;
}

stock bool:Movement_IsPlayerInWater(playerid)
{
	return Movement_IsInWaterState(playerid);
}

stock Movement_GetStateName(moveState,dest[],size = sizeof (dest))
{
	if (moveState < 0 || moveState >= E_MOVE_STATE)
	{
		moveState = MOVE_STATE_UNKNOWN;
	}

	strcopy(dest,s_MoveStateNames[moveState],size);
}
