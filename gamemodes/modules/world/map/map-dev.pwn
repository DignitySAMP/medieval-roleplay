#define MAP_WALL_CHECK_MS (200)
#define MAP_WALL_TICKS (3)
#define MAP_WALL_DEDUPE (3.0)
#define MAP_WALL_MAX (256)
#define MAP_NEAR_COUNT (8)
#define MAP_COLS_MAX (32)
#define MAP_HIDE_OFFSET (1000.0)
#define MAP_RAY_REACH (100.0)
#define MAP_RAY_LIST (8)
#define MAP_RAYDUMP_FILE "mapq/probes.txt"
#define MAP_RAYDUMP_TOP (1000.0)
#define MAP_RAYDUMP_BOTTOM (-100.0)
#define MAP_RAYDUMP_LINE (64)
#define MAP_RAYDUMP_OUT (512)

static bool:s_MapWallLog[MAX_PLAYERS];
static s_MapWallStuck[MAX_PLAYERS];
static s_MapWallCount = 0;
static Float:s_MapWallSeen[MAP_WALL_MAX][3];

stock Map_RayDump(const file[])
{
	if (!fexist(file))
	{
		return -1;
	}

	new File:handle = fopen(file,io_read),line[MAP_RAYDUMP_LINE],count = 0;

	if (!handle)
	{
		return -1;
	}

	while (fread(handle,line))
	{
		new Float:x,Float:y;

		if (sscanf(line,"ff",x,y))
		{
			continue;
		}

		new Float:hitX[MAX_MULTICAST_SIZE],Float:hitY[MAX_MULTICAST_SIZE],Float:hitZ[MAX_MULTICAST_SIZE],Float:hitDist[MAX_MULTICAST_SIZE],hitModel[MAX_MULTICAST_SIZE];
		new hits = CA_RayCastMultiLine(x,y,MAP_RAYDUMP_TOP,x,y,MAP_RAYDUMP_BOTTOM,hitX,hitY,hitZ,hitDist,hitModel),out[MAP_RAYDUMP_OUT];

		for (new i = 0;i < hits;i++)
		{
			new piece[24];
			format(piece,sizeof(piece)," %.3f:%d",hitZ[i],hitModel[i]);
			strcat(out,piece);
		}

		printf("[raydump] %.2f %.2f |%s",x,y,out);
		count++;
	}

	fclose(handle);
	return count;
}

#include <pp-hooks>

hook OnPlayerDisconnect(playerid,reason)
{
	s_MapWallLog[playerid] = false;
	s_MapWallStuck[playerid] = 0;
}

Timer_Declare(Map_WallCheck)
{
	foreach (new playerid : Player)
	{
		if (!s_MapWallLog[playerid] || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
		{
			s_MapWallStuck[playerid] = 0;
			continue;
		}

		new KEY:keys,updown,leftright,Float:vx,Float:vy,Float:vz;
		GetPlayerKeys(playerid,keys,updown,leftright);
		GetPlayerVelocity(playerid,vx,vy,vz);

		if ((updown == 0 && leftright == 0) || VectorSize(vx,vy,0.0) > 0.01 || floatabs(vz) > 0.01)
		{
			s_MapWallStuck[playerid] = 0;
			continue;
		}

		if (++s_MapWallStuck[playerid] != MAP_WALL_TICKS)
		{
			continue;
		}

		new Float:x,Float:y,Float:z,Float:a,Float:cx,Float:cy,Float:cz,bool:known = false;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		GetPlayerCameraFrontVector(playerid,cx,cy,cz);

		for (new i = 0;i < s_MapWallCount && i < MAP_WALL_MAX;i++)
		{
			if (VectorSize(x - s_MapWallSeen[i][0],y - s_MapWallSeen[i][1],z - s_MapWallSeen[i][2]) < MAP_WALL_DEDUPE)
			{
				known = true;
				break;
			}
		}

		if (known)
		{
			continue;
		}

		if (s_MapWallCount < MAP_WALL_MAX)
		{
			s_MapWallSeen[s_MapWallCount][0] = x;
			s_MapWallSeen[s_MapWallCount][1] = y;
			s_MapWallSeen[s_MapWallCount][2] = z;
		}

		s_MapWallCount++;
		Log_Info("map","[wall] %d: %.3f, %.3f, %.3f facing %.1f keys %d %d cam %.3f %.3f %.3f",s_MapWallCount,x,y,z,a,updown,leftright,cx,cy,cz);
		SendClientMessage(playerid,0xAAAAAAFF,sprintf("blocked spot #%d logged",s_MapWallCount));
	}
}

CMD<ADMIN_LEVEL_ADMIN>:mapzones(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	Map_ToggleRadar(playerid);
	SendClientMessage(playerid,0xFFFFFFFF,Map_IsRadarShown(playerid) ? sprintf("The map is drawn on your radar again (%d gangzones).",Map_GetRadarZoneCount()) : ("The gangzone map is off. You see San Andreas' own radar."));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:near(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new Float:px,Float:py,Float:pz,best[MAP_NEAR_COUNT] = {-1, ...},Float:bestd[MAP_NEAR_COUNT];
	GetPlayerPos(playerid,px,py,pz);

	for (new i = 0;i < MAP_NEAR_COUNT;i++)
	{
		bestd[i] = 999999.0;
	}

	for (new id = 1,last = Streamer_GetUpperBound(STREAMER_TYPE_OBJECT);id <= last;id++)
	{
		if (!IsValidDynamicObject(DynamicObject:id))
		{
			continue;
		}

		new Float:ox,Float:oy,Float:oz;
		GetDynamicObjectPos(DynamicObject:id,ox,oy,oz);

		if (oz < -500.0)
		{
			oz += MAP_HIDE_OFFSET;
		}

		new Float:d = VectorSize(ox - px,oy - py,oz - pz);

		for (new k = 0;k < MAP_NEAR_COUNT;k++)
		{
			if (d < bestd[k])
			{
				for (new j = MAP_NEAR_COUNT - 1;j > k;j--)
				{
					bestd[j] = bestd[j - 1];
					best[j] = best[j - 1];
				}

				bestd[k] = d;
				best[k] = id;
				break;
			}
		}
	}

	SendClientMessage(playerid,0xFFFFFFFF,"nearest map objects (model id, distance to its origin):");

	for (new k = 0;k < MAP_NEAR_COUNT && best[k] != -1;k++)
	{
		new Float:ox,Float:oy,Float:oz;
		GetDynamicObjectPos(DynamicObject:best[k],ox,oy,oz);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("  %d  %.0fm%s",Streamer_GetIntData(STREAMER_TYPE_OBJECT,best[k],E_STREAMER_MODEL_ID),bestd[k],oz < -500.0 ? (" (hidden)") : ("")));
	}

	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:cols(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new Float:px,Float:py,Float:pz,msg[144],idx[MAP_COLS_MAX],Float:vol[MAP_COLS_MAX],n = 0;
	GetPlayerPos(playerid,px,py,pz);

	for (new i = 0;i < MAP_COL_COUNT && n < MAP_COLS_MAX;i++)
	{
		if (px < gMapColBox[i][0] - 0.5 || px > gMapColBox[i][3] + 0.5 || py < gMapColBox[i][1] - 0.5 || py > gMapColBox[i][4] + 0.5 || pz < gMapColBox[i][2] - 2.0 || pz > gMapColBox[i][5] + 2.0)
		{
			continue;
		}

		new Float:v = (gMapColBox[i][3] - gMapColBox[i][0]) * (gMapColBox[i][4] - gMapColBox[i][1]),k = n++;

		while (k > 0 && vol[k - 1] > v)
		{
			vol[k] = vol[k - 1];
			idx[k] = idx[k - 1];
			k--;
		}

		vol[k] = v;
		idx[k] = i;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d map models have collision here (smallest box first):",n));

	for (new k = 0;k < n;k++)
	{
		format(msg,sizeof(msg),"%s %d",msg,gMapColModel[idx[k]]);

		if (strlen(msg) > 120 || k == n - 1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,msg);
			msg[0] = EOS;
		}
	}

	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:ray(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new Float:px,Float:py,Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	new Float:hitX[MAX_MULTICAST_SIZE],Float:hitY[MAX_MULTICAST_SIZE],Float:hitZ[MAX_MULTICAST_SIZE],Float:hitDist[MAX_MULTICAST_SIZE],hitModel[MAX_MULTICAST_SIZE];
	new hits = CA_RayCastMultiLine(px,py,pz + MAP_RAY_REACH,px,py,pz - MAP_RAY_REACH,hitX,hitY,hitZ,hitDist,hitModel);

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("down from %.1f: %d hit(s), you stand at z %.2f",pz + MAP_RAY_REACH,hits < 0 ? MAX_MULTICAST_SIZE : hits,pz));

	for (new i = 0;i < hits && i < MAP_RAY_LIST;i++)
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("  z %.2f  model %d%s",hitZ[i],hitModel[i],hitModel[i] == WATER_OBJECT ? (" (water)") : ("")));
	}

	new Float:cx,Float:cy,Float:cz,Float:fx,Float:fy,Float:fz,Float:hx,Float:hy,Float:hz;
	GetPlayerCameraPos(playerid,cx,cy,cz);
	GetPlayerCameraFrontVector(playerid,fx,fy,fz);

	new model = CA_RayCastLine(cx,cy,cz,cx + fx * MAP_RAY_REACH,cy + fy * MAP_RAY_REACH,cz + fz * MAP_RAY_REACH,hx,hy,hz);

	if (model == 0)
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("camera: nothing within %.0fm",MAP_RAY_REACH));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("camera: model %d at %.2f, %.2f, %.2f (%.1fm)",model,hx,hy,hz,VectorSize(hx - cx,hy - cy,hz - cz)));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:raydump(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new count = Map_RayDump(MAP_RAYDUMP_FILE);

	if (count < 0)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No probe file at scriptfiles/mapq/probes.txt. Write one with mrp-infra/scripts/mapq.py probes.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d probe(s) written to the server log as [raydump] lines.",count));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:hide(cmdid, playerid, params[])
{
	new pos = 0,len = strlen(params),bool:any = false;

	while (pos < len)
	{
		while (pos < len && (params[pos] == ' ' || params[pos] == ','))
		{
			pos++;
		}

		if (pos >= len)
		{
			break;
		}

		new model = strval(params[pos]),bool:found = false;

		while (pos < len && params[pos] != ' ' && params[pos] != ',')
		{
			pos++;
		}

		any = true;

		for (new id = 1,last = Streamer_GetUpperBound(STREAMER_TYPE_OBJECT);id <= last;id++)
		{
			if (!IsValidDynamicObject(DynamicObject:id) || Streamer_GetIntData(STREAMER_TYPE_OBJECT,id,E_STREAMER_MODEL_ID) != model)
			{
				continue;
			}

			new Float:ox,Float:oy,Float:oz;
			GetDynamicObjectPos(DynamicObject:id,ox,oy,oz);
			SetDynamicObjectPos(DynamicObject:id,ox,oy,oz < -500.0 ? oz + MAP_HIDE_OFFSET : oz - MAP_HIDE_OFFSET);

			if (!found)
			{
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("model %d %s",model,oz < -500.0 ? ("shown") : ("hidden")));
			}

			found = true;
		}

		if (!found)
		{
			SendClientMessage(playerid,0xFFFFFFFF,sprintf("no map object with model %d",model));
		}
	}

	if (!any)
	{
		Command_Usage(playerid,cmdid,"<id> [<id> ...]");
		return 1;
	}

	Streamer_Update(playerid);
	return 1;
}

static Float:Map_GetNudgeStep(const params[])
{
	new Float:step = params[0] == EOS ? 1.0 : floatstr(params);
	return step <= 0.0 ? 1.0 : step;
}

static Map_Nudge(playerid,Float:ahead,Float:upward)
{
	new Float:x, Float:y, Float:z, Float:angle;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,angle);
	SetPlayerPos(playerid,x + ahead * floatsin(-angle,degrees),y + ahead * floatcos(-angle,degrees),z + upward);
}

CMD<ADMIN_LEVEL_TRIAL>:fw(cmdid, playerid, params[])
{
	#pragma unused cmdid

	Map_Nudge(playerid,Map_GetNudgeStep(params),0.0);
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:up(cmdid, playerid, params[])
{
	#pragma unused cmdid

	Map_Nudge(playerid,0.0,Map_GetNudgeStep(params));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:dn(cmdid, playerid, params[])
{
	#pragma unused cmdid

	Map_Nudge(playerid,0.0,-Map_GetNudgeStep(params));
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:walllog(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	s_MapWallLog[playerid] = !s_MapWallLog[playerid];
	s_MapWallStuck[playerid] = 0;
	SendClientMessage(playerid,0xFFFFFFFF,s_MapWallLog[playerid] ? ("Wall logger on: stand pushing into a blocked spot to log it.") : ("Wall logger off."));
	return 1;
}
