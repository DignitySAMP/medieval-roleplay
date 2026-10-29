#define WORK_DRESS_PER_STATION (8)
#define WORK_DRESS_STREAM (60.0)
#define WORK_DRESS_PRIORITY (1)
#define WORK_DRESS_CLEAR_SIDE (0.55)
#define WORK_DRESS_CLEAR_BEHIND (0.6)
#define WORK_DRESS_CLEAR_AHEAD (0.3)
#define WORK_DRESS_CLEAR_GRACE (0.02)
#define WORK_DRESS_RAY_UP (1.2)
#define WORK_DRESS_RAY_REACH (2.7)
#define WORK_DRESS_MAX_RISE (0.6)
#define WORK_DRESS_MAX_DROP (0.9)
#define WORK_DRESS_MAX_TILT (20.0)
#define WORK_DRESS_MAX_BUMP (0.12)
#define WORK_DRESS_INSET (0.8)
#define WORK_DRESS_SIGHT (0.5)
#define WORK_DRESS_EDGE_SIGHT (0.25)
#define WORK_DRESS_SETTING "workshop_props"

enum E_WORK_DRESS_RESULT
{
	WORK_DRESS_NONE,
	WORK_DRESS_PLACED,
	WORK_DRESS_IN_THE_WAY,
	WORK_DRESS_BLOCKED,
	WORK_DRESS_NO_GROUND,
	WORK_DRESS_NO_CARRIER,
}

enum E_WORK_DRESS_POSE
{
	Float:E_WORK_DRESS_POSE_POS[3],
	Float:E_WORK_DRESS_POSE_NORMAL[3],
}

static STREAMER_TAG_OBJECT:s_WorkDressObjects[WORK_MAX_STATIONS][WORK_DRESS_PER_STATION];
static E_WORK_DRESS_RESULT:s_WorkDressResults[WORK_MAX_STATIONS][WORK_DRESS_PER_STATION];
static bool:s_WorkDressHidden[MAX_PLAYERS];

stock Work_FindDressKind(kind)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);

	for (new i = 0;key[0] != EOS && i < WORK_DRESS_KIND_COUNT;i++)
	{
		if (!strcmp(g_WorkDressKindDefs[i][E_WORK_DRESS_KIND_DEF_KIND],key))
		{
			return i;
		}
	}

	return -1;
}

stock Work_GetDressCount(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return 0;
	}

	new entry = Work_FindDressKind(g_WorkStations[stationid][E_WORK_STATION_KIND]);
	return entry == -1 ? 0 : min(g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_COUNT],WORK_DRESS_PER_STATION);
}

stock STREAMER_TAG_OBJECT:Work_GetDressObject(stationid,slot)
{
	return Work_IsValidStation(stationid) && slot >= 0 && slot < WORK_DRESS_PER_STATION ? s_WorkDressObjects[stationid][slot] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock E_WORK_DRESS_RESULT:Work_GetDressResult(stationid,slot)
{
	return Work_IsValidStation(stationid) && slot >= 0 && slot < WORK_DRESS_PER_STATION ? s_WorkDressResults[stationid][slot] : WORK_DRESS_NONE;
}

stock Work_GetDressDef(stationid,slot)
{
	if (!Work_IsValidStation(stationid) || slot < 0 || slot >= Work_GetDressCount(stationid))
	{
		return -1;
	}

	return g_WorkDressKindDefs[Work_FindDressKind(g_WorkStations[stationid][E_WORK_STATION_KIND])][E_WORK_DRESS_KIND_DEF_FIRST] + slot;
}

stock bool:Work_IsDressShown(playerid)
{
	return Util_IsValidPlayer(playerid) && !s_WorkDressHidden[playerid];
}

static Float:Work_DressMin(Float:a,Float:b)
{
	return a < b ? a : b;
}

static Float:Work_DressMax(Float:a,Float:b)
{
	return a > b ? a : b;
}

static Work_ClearDress(stationid)
{
	for (new slot = 0;slot < WORK_DRESS_PER_STATION;slot++)
	{
		if (IsValidDynamicObject(s_WorkDressObjects[stationid][slot]))
		{
			DestroyDynamicObject(s_WorkDressObjects[stationid][slot]);
		}

		s_WorkDressObjects[stationid][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_WorkDressResults[stationid][slot] = WORK_DRESS_NONE;
	}
}

static Work_ToLocal(Float:x,Float:y,Float:a,Float:wx,Float:wy,&Float:lx,&Float:ly)
{
	new Float:dx = wx - x, Float:dy = wy - y;
	lx = dx * floatcos(a,degrees) + dy * floatsin(a,degrees);
	ly = -dx * floatsin(a,degrees) + dy * floatcos(a,degrees);
}

static Work_DressCorners(def,Float:x,Float:y,Float:a,Float:scale,Float:corners[4][2])
{
	new Float:turn = g_WorkDressDefs[def][E_WORK_DRESS_DEF_TURN], Float:ox = g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][0], Float:oy = g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][1];
	new Float:minX = g_WorkDressDefs[def][E_WORK_DRESS_DEF_FOOT][0], Float:minY = g_WorkDressDefs[def][E_WORK_DRESS_DEF_FOOT][1], Float:maxX = g_WorkDressDefs[def][E_WORK_DRESS_DEF_FOOT][2], Float:maxY = g_WorkDressDefs[def][E_WORK_DRESS_DEF_FOOT][3];
	new Float:midX = (minX + maxX) / 2.0, Float:midY = (minY + maxY) / 2.0, Float:local[4][2];
	local[0][0] = minX; local[0][1] = minY;
	local[1][0] = maxX; local[1][1] = minY;
	local[2][0] = maxX; local[2][1] = maxY;
	local[3][0] = minX; local[3][1] = maxY;

	for (new i = 0;i < 4;i++)
	{
		new Float:px = midX + (local[i][0] - midX) * scale, Float:py = midY + (local[i][1] - midY) * scale;
		new Float:sx = ox + px * floatcos(turn,degrees) - py * floatsin(turn,degrees), Float:sy = oy + px * floatsin(turn,degrees) + py * floatcos(turn,degrees);
		Work_OffsetFrom(x,y,a,sx,sy,corners[i][0],corners[i][1]);
	}
}

static bool:Work_QuadsSeparate(const Float:a[4][2],const Float:b[4][2],Float:grace)
{
	for (new pass = 0;pass < 2;pass++)
	{
		for (new edge = 0;edge < 2;edge++)
		{
			new Float:ex, Float:ey;

			if (pass == 0)
			{
				ex = a[edge + 1][0] - a[edge][0];
				ey = a[edge + 1][1] - a[edge][1];
			}
			else
			{
				ex = b[edge + 1][0] - b[edge][0];
				ey = b[edge + 1][1] - b[edge][1];
			}

			new Float:length = floatsqroot(ex * ex + ey * ey);

			if (length < 0.0001)
			{
				continue;
			}

			new Float:nx = -ey / length, Float:ny = ex / length, Float:minA = 99999.0, Float:maxA = -99999.0, Float:minB = 99999.0, Float:maxB = -99999.0;

			for (new i = 0;i < 4;i++)
			{
				new Float:pa = a[i][0] * nx + a[i][1] * ny, Float:pb = b[i][0] * nx + b[i][1] * ny;
				minA = Work_DressMin(minA,pa);
				maxA = Work_DressMax(maxA,pa);
				minB = Work_DressMin(minB,pb);
				maxB = Work_DressMax(maxB,pb);
			}

			if (maxA - grace <= minB || maxB - grace <= minA)
			{
				return true;
			}
		}
	}

	return false;
}

static Float:Work_DressZoneReach(stationid,entry)
{
	new Float:x = g_WorkStations[stationid][E_WORK_STATION_POS][0], Float:y = g_WorkStations[stationid][E_WORK_STATION_POS][1], Float:a = g_WorkStations[stationid][E_WORK_STATION_POS][3];
	new Float:standA = g_WorkStations[stationid][E_WORK_STATION_STAND][3], Float:lx, Float:ly;
	Work_ToLocal(x,y,a,g_WorkStations[stationid][E_WORK_STATION_STAND][0],g_WorkStations[stationid][E_WORK_STATION_STAND][1],lx,ly);

	new Float:fx = -floatsin(standA - a,degrees), Float:fy = floatcos(standA - a,degrees);
	new Float:minX = g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_BODY][0], Float:minY = g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_BODY][1], Float:maxX = g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_BODY][2], Float:maxY = g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_BODY][3];

	if (lx > minX && lx < maxX && ly > minY && ly < maxY)
	{
		return WORK_DRESS_CLEAR_AHEAD;
	}

	new Float:enter = 0.0, Float:leave = 99999.0, Float:origin[2], Float:dir[2], Float:low[2], Float:high[2];
	origin[0] = lx; origin[1] = ly;
	dir[0] = fx; dir[1] = fy;
	low[0] = minX; low[1] = minY;
	high[0] = maxX; high[1] = maxY;

	for (new axis = 0;axis < 2;axis++)
	{
		if (floatabs(dir[axis]) < 0.0001)
		{
			if (origin[axis] < low[axis] || origin[axis] > high[axis])
			{
				return WORK_DRESS_CLEAR_AHEAD;
			}

			continue;
		}

		new Float:t1 = (low[axis] - origin[axis]) / dir[axis], Float:t2 = (high[axis] - origin[axis]) / dir[axis];
		enter = Work_DressMax(enter,Work_DressMin(t1,t2));
		leave = Work_DressMin(leave,Work_DressMax(t1,t2));
	}

	return enter <= leave ? enter : WORK_DRESS_CLEAR_AHEAD;
}

stock bool:Work_IsDressInTheWay(stationid,def)
{
	new entry = Work_FindDressKind(g_WorkStations[stationid][E_WORK_STATION_KIND]);

	if (entry == -1)
	{
		return false;
	}

	new Float:standX = g_WorkStations[stationid][E_WORK_STATION_STAND][0], Float:standY = g_WorkStations[stationid][E_WORK_STATION_STAND][1], Float:standA = g_WorkStations[stationid][E_WORK_STATION_STAND][3];
	new Float:reach = Work_DressZoneReach(stationid,entry), Float:zone[4][2], Float:prop[4][2];
	Work_OffsetFrom(standX,standY,standA,-WORK_DRESS_CLEAR_SIDE,-WORK_DRESS_CLEAR_BEHIND,zone[0][0],zone[0][1]);
	Work_OffsetFrom(standX,standY,standA,WORK_DRESS_CLEAR_SIDE,-WORK_DRESS_CLEAR_BEHIND,zone[1][0],zone[1][1]);
	Work_OffsetFrom(standX,standY,standA,WORK_DRESS_CLEAR_SIDE,reach,zone[2][0],zone[2][1]);
	Work_OffsetFrom(standX,standY,standA,-WORK_DRESS_CLEAR_SIDE,reach,zone[3][0],zone[3][1]);
	Work_DressCorners(def,g_WorkStations[stationid][E_WORK_STATION_POS][0],g_WorkStations[stationid][E_WORK_STATION_POS][1],g_WorkStations[stationid][E_WORK_STATION_POS][3],1.0,prop);
	return !Work_QuadsSeparate(zone,prop,WORK_DRESS_CLEAR_GRACE);
}

static bool:Work_DressSight(Float:fromX,Float:fromY,Float:fromZ,Float:toX,Float:toY,Float:toZ)
{
	new Float:hx, Float:hy, Float:hz;
	return CA_RayCastLine(fromX,fromY,fromZ,toX,toY,toZ,hx,hy,hz) == 0;
}

static E_WORK_DRESS_RESULT:Work_DressGround(def,Float:x,Float:y,Float:z,Float:a,Float:px,Float:py,pose[E_WORK_DRESS_POSE])
{
	new Float:corners[4][2], Float:samples[5][3], Float:found;
	Work_DressCorners(def,x,y,a,WORK_DRESS_INSET,corners);
	samples[0][0] = (corners[0][0] + corners[2][0]) / 2.0;
	samples[0][1] = (corners[0][1] + corners[2][1]) / 2.0;

	for (new i = 0;i < 4;i++)
	{
		samples[i + 1][0] = corners[i][0];
		samples[i + 1][1] = corners[i][1];
	}

	new hits = 0;

	for (new i = 0;i < 5;i++)
	{
		if (Placement_FindSurface(samples[i][0],samples[i][1],z + WORK_DRESS_RAY_UP,WORK_DRESS_RAY_REACH,found))
		{
			samples[i][2] = found;
			hits++;
		}
		else
		{
			samples[i][2] = -99999.0;
		}
	}

	new Float:lift = g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][2];

	if (hits == 0)
	{
		pose[E_WORK_DRESS_POSE_POS][0] = px;
		pose[E_WORK_DRESS_POSE_POS][1] = py;
		pose[E_WORK_DRESS_POSE_POS][2] = z + lift;
		pose[E_WORK_DRESS_POSE_NORMAL][0] = 0.0;
		pose[E_WORK_DRESS_POSE_NORMAL][1] = 0.0;
		pose[E_WORK_DRESS_POSE_NORMAL][2] = 1.0;
		return WORK_DRESS_PLACED;
	}

	if (hits < 5)
	{
		return WORK_DRESS_NO_GROUND;
	}

	new Float:meanX = 0.0, Float:meanY = 0.0, Float:meanZ = 0.0;

	for (new i = 0;i < 5;i++)
	{
		meanX += samples[i][0];
		meanY += samples[i][1];
		meanZ += samples[i][2];
	}

	meanX /= 5.0;
	meanY /= 5.0;
	meanZ /= 5.0;

	new Float:sxx = 0.0, Float:sxy = 0.0, Float:syy = 0.0, Float:sxz = 0.0, Float:syz = 0.0;

	for (new i = 0;i < 5;i++)
	{
		new Float:dx = samples[i][0] - meanX, Float:dy = samples[i][1] - meanY, Float:dz = samples[i][2] - meanZ;
		sxx += dx * dx;
		sxy += dx * dy;
		syy += dy * dy;
		sxz += dx * dz;
		syz += dy * dz;
	}

	new Float:det = sxx * syy - sxy * sxy, Float:gx = 0.0, Float:gy = 0.0;

	if (floatabs(det) > 0.000001)
	{
		gx = (sxz * syy - syz * sxy) / det;
		gy = (syz * sxx - sxz * sxy) / det;
	}

	for (new i = 0;i < 5;i++)
	{
		if (floatabs(samples[i][2] - (meanZ + gx * (samples[i][0] - meanX) + gy * (samples[i][1] - meanY))) > WORK_DRESS_MAX_BUMP)
		{
			return WORK_DRESS_NO_GROUND;
		}
	}

	new Float:length = floatsqroot(gx * gx + gy * gy + 1.0), Float:nx = -gx / length, Float:ny = -gy / length, Float:nz = 1.0 / length;

	if (acos(nz) > WORK_DRESS_MAX_TILT)
	{
		return WORK_DRESS_NO_GROUND;
	}

	new Float:groundZ = meanZ + gx * (px - meanX) + gy * (py - meanY), Float:centreZ = meanZ + gx * (samples[0][0] - meanX) + gy * (samples[0][1] - meanY);

	if (groundZ > z + WORK_DRESS_MAX_RISE || groundZ < z - WORK_DRESS_MAX_DROP)
	{
		return WORK_DRESS_NO_GROUND;
	}

	for (new i = 0;i < 4;i++)
	{
		new Float:edgeZ = meanZ + gx * (corners[i][0] - meanX) + gy * (corners[i][1] - meanY);

		if (!Work_DressSight(samples[0][0],samples[0][1],centreZ + WORK_DRESS_EDGE_SIGHT,corners[i][0],corners[i][1],edgeZ + WORK_DRESS_EDGE_SIGHT))
		{
			return WORK_DRESS_BLOCKED;
		}
	}

	pose[E_WORK_DRESS_POSE_POS][0] = px + nx * lift;
	pose[E_WORK_DRESS_POSE_POS][1] = py + ny * lift;
	pose[E_WORK_DRESS_POSE_POS][2] = groundZ + nz * lift;
	pose[E_WORK_DRESS_POSE_NORMAL][0] = nx;
	pose[E_WORK_DRESS_POSE_NORMAL][1] = ny;
	pose[E_WORK_DRESS_POSE_NORMAL][2] = nz;

	if (!Work_DressSight(x,y,z + WORK_DRESS_SIGHT,px,py,groundZ + WORK_DRESS_SIGHT))
	{
		return WORK_DRESS_BLOCKED;
	}

	return WORK_DRESS_PLACED;
}

static Work_TiltVector(const Float:normal[3],Float:vx,Float:vy,Float:vz,&Float:outX,&Float:outY,&Float:outZ)
{
	new Float:kx = -normal[1], Float:ky = normal[0], Float:sine = floatsqroot(kx * kx + ky * ky), Float:cosine = normal[2];

	if (sine < 0.000001)
	{
		outX = vx;
		outY = vy;
		outZ = vz;
		return;
	}

	kx /= sine;
	ky /= sine;

	new Float:dot = kx * vx + ky * vy;
	outX = vx * cosine + (ky * vz) * sine + kx * dot * (1.0 - cosine);
	outY = vy * cosine + (-kx * vz) * sine + ky * dot * (1.0 - cosine);
	outZ = vz * cosine + (kx * vy - ky * vx) * sine;
}

stock Work_DressRotation(const Float:normal[3],Float:yaw,&Float:rx,&Float:ry)
{
	new Float:lx = normal[0] * floatcos(yaw,degrees) + normal[1] * floatsin(yaw,degrees);
	new Float:ly = -normal[0] * floatsin(yaw,degrees) + normal[1] * floatcos(yaw,degrees);
	ry = asin(Util_Clamp(lx,-1.0,1.0));
	rx = atan2(-ly,normal[2]);
}

stock Work_BuildDress(stationid)
{
	Work_ClearDress(stationid);

	new entry = Work_FindDressKind(g_WorkStations[stationid][E_WORK_STATION_KIND]);

	if (entry == -1)
	{
		return;
	}

	new Float:x = g_WorkStations[stationid][E_WORK_STATION_POS][0], Float:y = g_WorkStations[stationid][E_WORK_STATION_POS][1], Float:z = g_WorkStations[stationid][E_WORK_STATION_POS][2], Float:a = g_WorkStations[stationid][E_WORK_STATION_POS][3];
	new world = g_WorkStations[stationid][E_WORK_STATION_WORLD], interior = g_WorkStations[stationid][E_WORK_STATION_INTERIOR];
	new first = g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_FIRST], count = min(g_WorkDressKindDefs[entry][E_WORK_DRESS_KIND_DEF_COUNT],WORK_DRESS_PER_STATION);
	new poses[WORK_DRESS_PER_STATION][E_WORK_DRESS_POSE];

	for (new slot = 0;slot < count;slot++)
	{
		new def = first + slot, carrier = g_WorkDressDefs[def][E_WORK_DRESS_DEF_CARRIER], Float:px, Float:py, E_WORK_DRESS_RESULT:result = WORK_DRESS_PLACED;
		Work_OffsetFrom(x,y,a,g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][0],g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][1],px,py);

		if (Work_IsDressInTheWay(stationid,def))
		{
			result = WORK_DRESS_IN_THE_WAY;
		}
		else if (carrier == WORK_DRESS_CARRIER_GROUND)
		{
			result = Work_DressGround(def,x,y,z,a,px,py,poses[slot]);
		}
		else if (carrier == WORK_DRESS_CARRIER_BODY)
		{
			poses[slot][E_WORK_DRESS_POSE_POS][0] = px;
			poses[slot][E_WORK_DRESS_POSE_POS][1] = py;
			poses[slot][E_WORK_DRESS_POSE_POS][2] = z + g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][2];
			poses[slot][E_WORK_DRESS_POSE_NORMAL][0] = 0.0;
			poses[slot][E_WORK_DRESS_POSE_NORMAL][1] = 0.0;
			poses[slot][E_WORK_DRESS_POSE_NORMAL][2] = 1.0;

			if (!Work_DressSight(x,y,z + WORK_DRESS_SIGHT,px,py,poses[slot][E_WORK_DRESS_POSE_POS][2] + WORK_DRESS_EDGE_SIGHT))
			{
				result = WORK_DRESS_BLOCKED;
			}
		}
		else if (carrier < 0 || carrier >= slot || s_WorkDressResults[stationid][carrier] != WORK_DRESS_PLACED)
		{
			result = WORK_DRESS_NO_CARRIER;
		}
		else
		{
			new carrierDef = first + carrier, Float:dx = g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][0] - g_WorkDressDefs[carrierDef][E_WORK_DRESS_DEF_OFFSET][0], Float:dy = g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][1] - g_WorkDressDefs[carrierDef][E_WORK_DRESS_DEF_OFFSET][1];
			new Float:dz = g_WorkDressDefs[def][E_WORK_DRESS_DEF_OFFSET][2] - g_WorkDressDefs[carrierDef][E_WORK_DRESS_DEF_OFFSET][2], Float:wx = dx * floatcos(a,degrees) - dy * floatsin(a,degrees), Float:wy = dx * floatsin(a,degrees) + dy * floatcos(a,degrees);
			new Float:normal[3], Float:tx, Float:ty, Float:tz;

			for (new i = 0;i < 3;i++)
			{
				normal[i] = poses[carrier][E_WORK_DRESS_POSE_NORMAL][i];
				poses[slot][E_WORK_DRESS_POSE_NORMAL][i] = normal[i];
			}

			Work_TiltVector(normal,wx,wy,dz,tx,ty,tz);
			poses[slot][E_WORK_DRESS_POSE_POS][0] = poses[carrier][E_WORK_DRESS_POSE_POS][0] + tx;
			poses[slot][E_WORK_DRESS_POSE_POS][1] = poses[carrier][E_WORK_DRESS_POSE_POS][1] + ty;
			poses[slot][E_WORK_DRESS_POSE_POS][2] = poses[carrier][E_WORK_DRESS_POSE_POS][2] + tz;
		}

		s_WorkDressResults[stationid][slot] = result;

		if (result != WORK_DRESS_PLACED)
		{
			continue;
		}

		new Float:yaw = Util_NormalizeAngle(a + g_WorkDressDefs[def][E_WORK_DRESS_DEF_TURN]), Float:normal[3], Float:rx, Float:ry;

		for (new i = 0;i < 3;i++)
		{
			normal[i] = poses[slot][E_WORK_DRESS_POSE_NORMAL][i];
		}

		Work_DressRotation(normal,yaw,rx,ry);

		new STREAMER_TAG_OBJECT:objectid = CreateDynamicObject(g_WorkDressDefs[def][E_WORK_DRESS_DEF_MODEL],poses[slot][E_WORK_DRESS_POSE_POS][0],poses[slot][E_WORK_DRESS_POSE_POS][1],poses[slot][E_WORK_DRESS_POSE_POS][2],rx,ry,yaw,world,interior,-1,WORK_DRESS_STREAM,WORK_DRESS_STREAM,STREAMER_TAG_AREA:-1,WORK_DRESS_PRIORITY);
		s_WorkDressObjects[stationid][slot] = objectid;

		foreach (new playerid : Player)
		{
			if (s_WorkDressHidden[playerid])
			{
				Streamer_RemoveArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_PLAYER_ID,playerid);
			}
		}
	}
}

static Work_ApplyDressFor(playerid,bool:show,bool:isStreamed)
{
	for (new stationid = 0;stationid < WORK_MAX_STATIONS;stationid++)
	{
		for (new slot = 0;slot < WORK_DRESS_PER_STATION;slot++)
		{
			new STREAMER_TAG_OBJECT:objectid = s_WorkDressObjects[stationid][slot];

			if (!IsValidDynamicObject(objectid))
			{
				continue;
			}

			if (show)
			{
				Streamer_AppendArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_PLAYER_ID,playerid);
			}
			else
			{
				Streamer_RemoveArrayData(STREAMER_TYPE_OBJECT,objectid,E_STREAMER_PLAYER_ID,playerid);
			}
		}
	}

	if (isStreamed && Nearby_CanStreamObjects(playerid))
	{
		Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
	}
}

stock Work_SetDressShown(playerid,bool:show,bool:isSaved = true)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_WorkDressHidden[playerid] = !show;
	Work_ApplyDressFor(playerid,show,true);

	new accountid = Account_GetId(playerid);

	if (isSaved && accountid > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("REPLACE INTO account_settings (account_id, setting, value) VALUES (%d, '%e', %d)",accountid,WORK_DRESS_SETTING,show ? 1 : 0));
	}
}

forward Work_LoadDressSetting(playerid,token);

public Work_LoadDressSetting(playerid,token)
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_format("SELECT value FROM account_settings WHERE account_id = %d AND setting = '%e'",Account_GetId(playerid),WORK_DRESS_SETTING));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || cache_num_rows() == 0)
	{
		return;
	}

	new value;
	cache_get_value_name_int(0,"value",value);

	if (value == 0)
	{
		Work_SetDressShown(playerid,false,false);
	}
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new stationid = 0;stationid < WORK_MAX_STATIONS;stationid++)
	{
		for (new slot = 0;slot < WORK_DRESS_PER_STATION;slot++)
		{
			s_WorkDressObjects[stationid][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
			s_WorkDressResults[stationid][slot] = WORK_DRESS_NONE;
		}
	}

	Help_Register(HELP_SECTION_WORK,"Can I hide the props around stations?","~w~Stations come with a few props around them: firewood by a hearth, sacks by the millstones, a bucket by the anvil. If you'd rather not see them, open your bag (~y~N~w~) > Crafting > Stations and click ~y~Props around stations~w~. It only changes what you see, and you can turn them back on the same way.",false);
}

hook Models_OnRegister()
{
	for (new i = 0;i < WORK_DRESS_MODEL_COUNT;i++)
	{
		Models_AddObject(g_WorkDressModelDefs[i][E_WORK_DRESS_MODEL_DEF_MODEL],g_WorkDressModelDefs[i][E_WORK_DRESS_MODEL_DEF_DFF],WORK_PART_TXD,MAP_BASE_STATIC);
	}
}

hook Work_OnStationVisuals(stationid,bool:isShown)
{
	if (isShown)
	{
		Work_BuildDress(stationid);
	}
	else
	{
		Work_ClearDress(stationid);
	}
}

hook Account_OnAuthenticated(playerid,accountid)
{
	#pragma unused accountid

	SetTimerEx("Work_LoadDressSetting",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook OnPlayerConnect(playerid)
{
	s_WorkDressHidden[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_WorkDressHidden[playerid])
	{
		s_WorkDressHidden[playerid] = false;
		Work_ApplyDressFor(playerid,true,false);
	}
}
