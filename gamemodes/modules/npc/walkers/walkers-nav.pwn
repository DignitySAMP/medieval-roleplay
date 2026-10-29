#define NAV_DEV_REACH (60.0)
#define NAV_DEV_ANIMAL_KIND (50)
#define NAV_DEV_FLEE_MS (12000)
#define NAV_CAM_MS (50)

static s_NavCamActor[MAX_PLAYERS] = {-1, ...};
static Float:s_NavCamLast[MAX_PLAYERS][2];
static Float:s_NavCamDir[MAX_PLAYERS][2];
static Float:s_NavCamBack[MAX_PLAYERS];
static Float:s_NavCamSide[MAX_PLAYERS];
static Float:s_NavCamUp[MAX_PLAYERS];

hook OnGameModeInit()
{
	Command_Describe("navwalk","Staff: send the nearest villager to x y z along the navmesh.");
	Command_Describe("navspawn","Staff: place a villager that stays (kind 2) at x y z, or beside you.");
	Command_Describe("navcls","Staff: push the chat window clear.");
	Command_Describe("navtalk","Staff: hold or release the nearest villager the way the talk menu does.");
	Command_Describe("navflee","Staff: scare the nearest animal away from you along its navmesh.");
	Command_Describe("navprobe","Staff: route length from you to x y z on a navmesh body (0 people, 1 deer, 2 sheep).");
	Command_Describe("navstats","Staff: print the pedestrian navmesh and crowd counters to the log.");
	Command_Describe("navcam","Staff: the camera follows a pedestrian (actor id, back, side, up), or off.");
	SetTimer("Nav_CamTick",NAV_CAM_MS,true);
}

hook OnPlayerConnect(playerid)
{
	s_NavCamActor[playerid] = -1;
}

forward Nav_CamTick();

public Nav_CamTick()
{
	foreach (new playerid : Player)
	{
		new actorid = s_NavCamActor[playerid];

		if (actorid == -1)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;

		if (IsValidPedestrian(actorid) != 1 || !GetPedestrianPos(actorid,x,y,z))
		{
			s_NavCamActor[playerid] = -1;
			SetCameraBehindPlayer(playerid);
			continue;
		}

		new Float:dx = x - s_NavCamLast[playerid][0], Float:dy = y - s_NavCamLast[playerid][1], Float:length = VectorSize(dx,dy,0.0);

		if (length > 0.02)
		{
			new Float:mx = s_NavCamDir[playerid][0] * 0.9 + dx / length * 0.1, Float:my = s_NavCamDir[playerid][1] * 0.9 + dy / length * 0.1, Float:size = VectorSize(mx,my,0.0);

			if (size > 0.001)
			{
				s_NavCamDir[playerid][0] = mx / size;
				s_NavCamDir[playerid][1] = my / size;
			}
		}

		s_NavCamLast[playerid][0] = x;
		s_NavCamLast[playerid][1] = y;
		new Float:fx = s_NavCamDir[playerid][0], Float:fy = s_NavCamDir[playerid][1];
		SetPlayerCameraPos(playerid,x - fx * s_NavCamBack[playerid] - fy * s_NavCamSide[playerid],y - fy * s_NavCamBack[playerid] + fx * s_NavCamSide[playerid],z + s_NavCamUp[playerid]);
		SetPlayerCameraLookAt(playerid,x + fx * 2.0,y + fy * 2.0,z + 0.7);
	}

	return 1;
}

hook OnPedestrianPathFailed(actorid)
{
	new Float:x, Float:y, Float:z;
	GetPedestrianPos(actorid,x,y,z);
	Log_Warn("walkers","no route on the mesh for pedestrian %d at %.1f %.1f %.1f; it stands",actorid,x,y,z);
	Walkers_StopRoute(actorid);
}

CMD<ADMIN_LEVEL_TRIAL>:navwalk(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new Float:x, Float:y, Float:z, Float:speed = WALKERS_HOME_SPEED;

	if (sscanf(params,"fff",x,y,z))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/navwalk x y z [speed] [actorid]");
		return 1;
	}

	sscanf(params,"{fff}F(1.4)",speed);
	new actorid = -1;
	sscanf(params,"{fffF}D(-1)",actorid);

	if (actorid == -1)
	{
		actorid = GetClosestPedestrianID(playerid);
	}

	if (actorid == INVALID_ACTOR_ID || actorid < 0 || IsValidPedestrian(actorid) != 1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No pedestrian near you.");
		return 1;
	}

	new Float:px, Float:py, Float:pz;
	GetPedestrianPos(actorid,px,py,pz);
	new bool:routed = Walkers_RouteTo(actorid,x,y,z,speed,true);
	printf("[navdev] navwalk %d routed %d",actorid,routed);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navspawn(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new Float:x, Float:y, Float:z;

	if (sscanf(params,"fff",x,y,z))
	{
		GetPlayerPos(playerid,x,y,z);
		z -= 1.0;
	}

	new kind = WALKERS_KIND_ACTOR, skin = 0;
	sscanf(params,"{fff}D(2)D(0)",kind,skin);
	new bool:animal = kind >= NAV_DEV_ANIMAL_KIND && kind < 100;
	new actorid = SpawnPedestrianAt(skin != 0 ? skin : (animal ? 1 : Skins_GetStarter(0,random(max(1,Skins_CountStarter(0))))),x,y,z + 1.0,0.0,kind);

	if (animal && actorid != INVALID_ACTOR_ID)
	{
		SetPedestrianBody(actorid,kind >= 55 && kind <= 57 ? PED_BODY_DEER : PED_BODY_SHEEP);
		StopPedestrian(actorid);
		ApplyPedestrianAnim(actorid,"PED","IDLE_stance",4.1,1,0,0,0,0);
	}

	printf("[navdev] spawned villager %d at %.1f %.1f %.1f",actorid,x,y,z);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navcls(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	for (new i = 0; i < 24; i++)
	{
		SendClientMessage(playerid,0xFFFFFFFF," ");
	}

	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navtalk(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new actorid = -1;
	sscanf(params,"D(-1)",actorid);

	if (actorid == -1)
	{
		actorid = GetClosestPedestrianID(playerid);
	}

	if (actorid == INVALID_ACTOR_ID || actorid < 0 || IsValidPedestrian(actorid) != 1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No pedestrian near you.");
		return 1;
	}

	new bool:hold = !Walkers_IsPaused(actorid);
	Walkers_SetTalkPaused(actorid,hold);
	printf("[navdev] navtalk %d hold %d",actorid,hold);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navflee(cmdid, playerid, params[])
{
	new Float:px, Float:py, Float:pz, best = -1, Float:bestDistance = NAV_DEV_REACH, only = -1;
	sscanf(params,"D(-1)",only);
	GetPlayerPos(playerid,px,py,pz);

	for (new actorid = 0; actorid < MAX_ACTORS; actorid++)
	{
		new Float:x, Float:y, Float:z;

		if (only != -1 && actorid != only)
		{
			continue;
		}

		if (IsValidPedestrian(actorid) != 1 || GetPedestrianKind(actorid) < NAV_DEV_ANIMAL_KIND || GetPedestrianKind(actorid) >= 100 || !GetPedestrianPos(actorid,x,y,z))
		{
			continue;
		}

		new Float:distance = VectorSize(x - px,y - py,0.0);

		if (distance < bestDistance)
		{
			bestDistance = distance;
			best = actorid;
		}
	}

	if (best == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No animal within 60 m.");
		return 1;
	}

	ResumePedestrian(best);
	SetPedestrianSpeed(best,6.0);
	ApplyPedestrianAnim(best,"PED","run_civi",4.1,1,1,1,0,0);
	PedestrianFleeFrom(best,px,py,pz,NAV_DEV_FLEE_MS);
	printf("[navdev] navflee %d body %d %.0f m",best,GetPedestrianBody(best),bestDistance);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navprobe(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new Float:x, Float:y, Float:z, body = 0, Float:px, Float:py, Float:pz, Float:length;

	if (sscanf(params,"fffD(0)",x,y,z,body))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/navprobe x y z [body]");
		return 1;
	}

	GetPlayerPos(playerid,px,py,pz);
	new corners = PedestrianPathProbe(body,px,py,pz - 1.0,x,y,z,length);
	SendClientMessage(playerid,0xFFFFFFFF,corners == -2 ? ("no mesh loaded for that body") : (corners < 0 ? ("no route") : sprintf("route: %d corners, %.1f m (straight %.1f m)",corners,length,VectorSize(x - px,y - py,0.0))));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navstats(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	Path_PrintNavStats();
	SendClientMessage(playerid,0xFFFFFFFF,"navmesh counters are in the server log");
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:navcam(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new actorid = -1, Float:back = 7.0, Float:side = 3.0, Float:up = 2.4;

	if (!strcmp(params,"off",true) || sscanf(params,"dF(7.0)F(3.0)F(2.4)",actorid,back,side,up))
	{
		s_NavCamActor[playerid] = -1;
		SetCameraBehindPlayer(playerid);
		return 1;
	}

	if (IsValidPedestrian(actorid) != 1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No such pedestrian.");
		return 1;
	}

	new Float:x, Float:y, Float:z;
	GetPedestrianPos(actorid,x,y,z);
	s_NavCamActor[playerid] = actorid;
	s_NavCamLast[playerid][0] = x;
	s_NavCamLast[playerid][1] = y;
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);
	new Float:length = VectorSize(x - px,y - py,0.0);
	s_NavCamDir[playerid][0] = length > 0.1 ? (x - px) / length : 0.0;
	s_NavCamDir[playerid][1] = length > 0.1 ? (y - py) / length : 1.0;
	s_NavCamBack[playerid] = back;
	s_NavCamSide[playerid] = side;
	s_NavCamUp[playerid] = up;
	return 1;
}
