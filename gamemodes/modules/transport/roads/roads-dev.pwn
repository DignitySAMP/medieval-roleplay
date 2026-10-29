CMD<ADMIN_LEVEL_TRIAL>:roads(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], value;

	if (!sscanf(params,"s[12]D(-1)",action,value) && !strcmp(action,"bandits",true))
	{
		Bandits_SetForce(value);

		if (value == 1)
		{
			new Float:x, Float:y, Float:z, point = -1, Float:best = 100000.0;
			GetPlayerPos(playerid,x,y,z);

			for (new i = 0;i < ROADS_SEED_AMBUSHES;i++)
			{
				new Float:d = VectorSize(x - g_RoadsAmbushes[i][0],y - g_RoadsAmbushes[i][1],0.0);

				if (d < best)
				{
					best = d;
					point = i;
				}
			}

			if (point != -1 && Bandits_Start(playerid,point) != -1)
			{
				SendClientMessage(playerid,0xFFFFFFFF,"Bandits come for you now; every pass of a lonely stretch rolls an ambush until /roads bandits -1.");
				return 1;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Bandit force: %d.",value));
		return 1;
	}

	if (!sscanf(params,"s[12]D(-1)",action,value) && !strcmp(action,"mud",true))
	{
		Roads_SetMudOverride(value);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Mud override: %d (-1 follows the weather). Muddy now: %d.",value,Roads_IsMuddy()));
		return 1;
	}

	new Float:x, Float:y, Float:z, Float:distance;
	GetPlayerPos(playerid,x,y,z);
	new stone = Roads_NearestWaystone(x,y,distance);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("On a road: %d. Muddy: %d. Ride scale %.2f. Waystones %d, nearest %d at %.0f m. Coach line %d points, %d stops. Ambushes %d.",Roads_IsOnRoad(x,y,z - 1.0),Roads_IsMuddy(),Roads_GetScale(playerid),ROADS_SEED_WAYSTONES,stone,distance,ROADS_COACH_POINTS,ROADS_COACH_STOPS,ROADS_SEED_AMBUSHES));
	return 1;
}
