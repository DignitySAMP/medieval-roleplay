#define WALKERS_GRAPH_FILE "paths/mrp-paths.txt"
#define WALKERS_MAX_HOMES (256)
#define WALKERS_HOME_LINE (48)
#define WALKERS_KIND_VILLAGER (1)
#define WALKERS_KIND_ACTOR (2)
#define WALKERS_POOL (60)
#define WALKERS_PER_PLAYER (8)
#define WALKERS_STREAM_DISTANCE (150.0)
#define WALKERS_DAY_DENSITY (0.0)
#define WALKERS_HOME_RANGE (250.0)
#define WALKERS_HOME_SPEED (1.2)
#define WALKERS_WALK_MAN (1)
#define WALKERS_WALK_WOMAN (10)
#define WALKERS_HOME_TRIES (3)
#define WALKERS_MESH_RANGE (300.0)
#define WALKERS_INTERIOR_Z (900.0)
#define WALKERS_LOCAL_RANGE (120.0)
#define WALKERS_GAP (2.0)
#define WALKERS_EDGE_MIN (1.5)
#define WALKERS_EDGE_MAX (3.0)
#define WALKERS_RADIUS (0.35)
#define WALKERS_ROAD_REACH (60.0)
#define WALKERS_ROAD_LEVEL (6.0)

enum E_WALKER_ROUTE
{
	E_WALKER_ROUTE_REQUEST,
	E_WALKER_ROUTE_PATH,
	E_WALKER_ROUTE_POINT,
	E_WALKER_ROUTE_COUNT,
	E_WALKER_ROUTE_TRIES,
	Float:E_WALKER_ROUTE_DISTANCE,
	bool:E_WALKER_ROUTE_KEEP,
	bool:E_WALKER_ROUTE_FINAL,
	Float:E_WALKER_ROUTE_GOAL[3],
	Float:E_WALKER_ROUTE_SPEED,
    Float:E_WALKER_ROUTE_TARGET[3],
    Float:E_WALKER_ROUTE_DIRECTION[2],
    bool:E_WALKER_ROUTE_TRAFFIC,
    bool:E_WALKER_ROUTE_ROADSIDE,
}

static Float:s_WalkerHomes[WALKERS_MAX_HOMES][3];
static s_WalkerHomeCount;
static s_WalkerNodeCount;
static bool:s_WalkersNight;
static s_WalkerRoutes[MAX_ACTORS][E_WALKER_ROUTE];
static s_WalkerLastFail = PATHS_OK;
static bool:s_WalkerPaused[MAX_ACTORS];
static bool:s_WalkerTalkPaused[MAX_ACTORS];

stock Walkers_GetNodeCount()
{
	return s_WalkerNodeCount;
}

stock Walkers_GetHomeCount()
{
	return s_WalkerHomeCount;
}

stock bool:Walkers_IsNight()
{
	return s_WalkersNight;
}

stock Walkers_GetLastRouteFail()
{
	return s_WalkerLastFail;
}

stock bool:Walkers_GetHome(index,&Float:x,&Float:y,&Float:z)
{
	if (index < 0 || index >= s_WalkerHomeCount)
	{
		return false;
	}

	x = s_WalkerHomes[index][0];
	y = s_WalkerHomes[index][1];
	z = s_WalkerHomes[index][2];
	return true;
}

stock bool:Walkers_IsRouting(actorid)
{
	return actorid >= 0 && actorid < MAX_ACTORS && (s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] > 0 || s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] != INVALID_PATH_ID || s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL]);
}

stock Walkers_GetRouteLeft(actorid)
{
	if (actorid < 0 || actorid >= MAX_ACTORS || s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] == INVALID_PATH_ID)
	{
		return -1;
	}

	return s_WalkerRoutes[actorid][E_WALKER_ROUTE_COUNT] - s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT];
}

static Walkers_ClearRoute(actorid)
{
	if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] != INVALID_PATH_ID)
	{
		NPC_DestroyPath(s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH]);
	}

	s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] = 0;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] = INVALID_PATH_ID;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT] = 0;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_COUNT] = 0;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRIES] = 0;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_DISTANCE] = 0.0;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_KEEP] = false;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL] = false;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRAFFIC] = false;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_ROADSIDE] = true;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_DIRECTION][0] = 0.0;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_DIRECTION][1] = 0.0;
}

static Walkers_GoInside(actorid)
{
	Walkers_ClearRoute(actorid);
	DespawnPedestrian(actorid);
}

static Walkers_DespawnAmbient()
{
	for (new actorid = 0;actorid < MAX_ACTORS;actorid++)
	{
		if (IsValidPedestrian(actorid) != 1)
		{
			continue;
		}

		new kind = GetPedestrianKind(actorid);

		if (kind == 0 || kind == WALKERS_KIND_VILLAGER)
		{
			Walkers_GoInside(actorid);
		}
	}
}

forward bool:Walkers_GetRoutePoint(actorid,point,&Float:x,&Float:y,&Float:z);
forward bool:Walkers_GetRoadNode(Float:x,Float:y,Float:z,&area,&node,&Float:roadX,&Float:roadY,&Float:roadZ);

stock Float:Walkers_RoadOffset(actorid,Float:clearance)
{
    new Float:offset = WALKERS_EDGE_MIN + float((actorid / 2) % 7) * 0.25;
    if (clearance <= WALKERS_RADIUS)
    {
        return 0.0;
    }
    if (offset > clearance - WALKERS_RADIUS)
    {
        offset = clearance - WALKERS_RADIUS;
    }
    return actorid % 2 == 0 ? offset : -offset;
}

stock bool:Walkers_ClearCorridor(Float:fromX,Float:fromY,Float:fromZ,Float:toX,Float:toY,Float:toZ)
{
    new Float:length = VectorSize(toX - fromX,toY - fromY,0.0);
    new steps = max(1,floatround(length / 1.0,floatround_ceil));
    new Float:dx = length > 0.01 ? (toX - fromX) / length : 1.0;
    new Float:dy = length > 0.01 ? (toY - fromY) / length : 0.0;
    new Float:lastX = fromX, Float:lastY = fromY, Float:lastZ, Float:hx, Float:hy, Float:ground;

    for (new step = 0; step <= steps; step++)
    {
        new Float:t = float(step) / float(steps);
        new Float:x = fromX + (toX - fromX) * t, Float:y = fromY + (toY - fromY) * t;
        new Float:z = fromZ + (toZ - fromZ) * t;
        if (!CA_RayCastLine(x,y,z + 0.8,x,y,z - 2.0,hx,hy,ground) || floatabs(ground - z) > 1.5)
        {
            return false;
        }

        for (new side = -1; side <= 1; side += 2)
        {
            new Float:edgeX = x - dy * WALKERS_RADIUS * float(side), Float:edgeY = y + dx * WALKERS_RADIUS * float(side), Float:edgeZ;
            if (!CA_RayCastLine(edgeX,edgeY,ground + 0.5,edgeX,edgeY,ground - 0.5,hx,hy,edgeZ) || floatabs(edgeZ - ground) > 0.3 || CA_RayCastLine(x,y,ground + 1.0,edgeX,edgeY,ground + 1.0,hx,hy,edgeZ))
            {
                return false;
            }
        }

        if (step > 0 && (floatabs(ground - lastZ) > 0.6 * VectorSize(x - lastX,y - lastY,0.0) + 0.15 || CA_RayCastLine(lastX,lastY,lastZ + 1.0,x,y,ground + 1.0,hx,hy,z)))
        {
            return false;
        }
        lastX = x;
        lastY = y;
        lastZ = ground;
    }
    return true;
}

stock bool:Walkers_IsRoadSurface(Float:x,Float:y,Float:z)
{
    new area, node, Float:roadX, Float:roadY, Float:roadZ;
    if (!Walkers_GetRoadNode(x,y,z,area,node,roadX,roadY,roadZ))
    {
        return false;
    }
    if (floatabs(roadZ - z) <= 1.5 && VectorSize(x - roadX,y - roadY,0.0) <= WALKERS_EDGE_MAX + WALKERS_RADIUS)
    {
        return true;
    }
    for (new link = 0, count = Paths_NodeLinkCount(PATHS_LAYER_PED,area,node); link < count; link++)
    {
        new toArea, toNode, Float:toX, Float:toY, Float:toZ;
        if (!Paths_NodeLink(PATHS_LAYER_PED,area,node,link,toArea,toNode) || !Paths_NodePos(PATHS_LAYER_PED,toArea,toNode,toX,toY,toZ))
        {
            continue;
        }
        new Float:dx = toX - roadX, Float:dy = toY - roadY, Float:lengthSquared = dx * dx + dy * dy;
        if (lengthSquared < 0.01)
        {
            continue;
        }
        new Float:t = ((x - roadX) * dx + (y - roadY) * dy) / lengthSquared;
        if (t < 0.0)
        {
            t = 0.0;
        }
        else if (t > 1.0)
        {
            t = 1.0;
        }
        if (floatabs(roadZ + (toZ - roadZ) * t - z) <= 1.5 && VectorSize(x - roadX - dx * t,y - roadY - dy * t,0.0) <= WALKERS_EDGE_MAX + WALKERS_RADIUS)
        {
            return true;
        }
    }
    return false;
}

stock bool:Walkers_CanWaitOffRoad(Float:x,Float:y,Float:z)
{
    if (!Walkers_ClearCorridor(x,y,z,x,y,z) || Walkers_IsRoadSurface(x,y,z))
    {
        return false;
    }
    new Float:hx, Float:hy, Float:hz;
    if (CA_RayCastLine(x,y,z + 0.2,x,y,z + 1.8,hx,hy,hz))
    {
        return false;
    }
    for (new side = 0; side < 4; side++)
    {
        new Float:angle = float(side * 90), Float:edgeX = x + floatcos(angle,degrees) * WALKERS_RADIUS, Float:edgeY = y + floatsin(angle,degrees) * WALKERS_RADIUS;
        if (Walkers_IsRoadSurface(edgeX,edgeY,z) || CA_RayCastLine(x,y,z + 1.0,edgeX,edgeY,z + 1.0,hx,hy,hz))
        {
            return false;
        }
    }
    return true;
}

stock Float:Walkers_MeshLength(Float:fromX,Float:fromY,Float:fromZ,Float:toX,Float:toY,Float:toZ)
{
    if (fromZ > WALKERS_INTERIOR_Z || toZ > WALKERS_INTERIOR_Z)
    {
        return -2.0;
    }

    new Float:length, corners = PedestrianPathProbe(PED_BODY_PEOPLE,fromX,fromY,fromZ,toX,toY,toZ,length);
    return corners == -2 ? -2.0 : (corners < 0 ? -1.0 : length);
}

stock bool:Walkers_ShouldGoDirect(Float:fromX,Float:fromY,Float:fromZ,Float:toX,Float:toY,Float:toZ)
{
    new Float:length = Walkers_MeshLength(fromX,fromY,fromZ,toX,toY,toZ);

    if (length == -2.0)
    {
        return VectorSize(toX - fromX,toY - fromY,0.0) <= WALKERS_LOCAL_RANGE && Walkers_ClearCorridor(fromX,fromY,fromZ,toX,toY,toZ);
    }

    return length >= 0.0 && length <= WALKERS_MESH_RANGE;
}

stock bool:Walkers_UsesRoadside(actorid)
{
    return actorid >= 0 && actorid < MAX_ACTORS && s_WalkerRoutes[actorid][E_WALKER_ROUTE_ROADSIDE];
}

stock bool:Walkers_GetTravelPoint(actorid,point,&Float:x,&Float:y,&Float:z)
{
    if (!Walkers_GetRoutePoint(actorid,point,x,y,z))
    {
        return false;
    }

    if (!Walkers_UsesRoadside(actorid))
    {
        return true;
    }

    new Float:fromX, Float:fromY, Float:fromZ, Float:toX, Float:toY, Float:toZ;
    if (!Walkers_GetRoutePoint(actorid,point + 1,toX,toY,toZ))
    {
        if (!Walkers_GetRoutePoint(actorid,point - 1,fromX,fromY,fromZ))
        {
            return true;
        }
        toX = x;
        toY = y;
        toZ = z;
    }
    else
    {
        fromX = x;
        fromY = y;
        fromZ = z;
    }
    new Float:dx = toX - fromX, Float:dy = toY - fromY, Float:length = VectorSize(dx,dy,0.0);
    if (length < 0.01)
    {
        return true;
    }
    dx /= length;
    dy /= length;
    new Float:offset = Walkers_RoadOffset(actorid,WALKERS_EDGE_MAX + WALKERS_RADIUS);
    while (floatabs(offset) > 0.01)
    {
        new Float:edgeX = x - dy * offset, Float:edgeY = y + dx * offset;
        if (Walkers_ClearCorridor(x,y,z,edgeX,edgeY,z) && Walkers_ClearCorridor(fromX - dy * offset,fromY + dx * offset,fromZ,toX - dy * offset,toY + dx * offset,toZ))
        {
            x = edgeX;
            y = edgeY;
            return true;
        }
        offset += offset > 0.0 ? -0.25 : 0.25;
    }
    return true;
}

static Walkers_Target(actorid,Float:x,Float:y,Float:z,Float:speed)
{
    new Float:fromX, Float:fromY, Float:fromZ;
    GetPedestrianPos(actorid,fromX,fromY,fromZ);
    new Float:length = VectorSize(x - fromX,y - fromY,0.0);
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_TARGET][0] = x;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_TARGET][1] = y;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_TARGET][2] = z;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_DIRECTION][0] = length > 0.01 ? (x - fromX) / length : 0.0;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_DIRECTION][1] = length > 0.01 ? (y - fromY) / length : 0.0;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRAFFIC] = false;
    SetPedestrianTarget(actorid,x,y,z,speed);
}

stock bool:Walkers_NeedsGap(actorid,other,Float:dx,Float:dy,Float:gapX,Float:gapY)
{
    new Float:ahead = gapX * dx + gapY * dy, Float:across = floatabs(gapX * dy - gapY * dx);
    return across < 0.8 && ahead < WALKERS_GAP + 0.3 && (ahead > 0.05 || (floatabs(ahead) <= 0.05 && actorid > other));
}

stock Walkers_UpdateTraffic()
{
    Walkers_DespawnAmbient();
    new bodies[WALKERS_POOL], count = 0, Float:positions[WALKERS_POOL][3];
    for (new actorid = 0; actorid < MAX_ACTORS && count < WALKERS_POOL; actorid++)
    {
        if (Walkers_IsRouting(actorid) && IsValidPedestrian(actorid) == 1 && GetPedestrianPos(actorid,positions[count][0],positions[count][1],positions[count][2]))
        {
            bodies[count++] = actorid;
        }
    }
    for (new i = 0; i < count; i++)
    {
        new actorid = bodies[i];
        if (!Walkers_UsesRoadside(actorid) || Walkers_IsPaused(actorid) || s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] > 0 || s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL] || s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT] <= 1)
        {
            continue;
        }
        new Float:dx = s_WalkerRoutes[actorid][E_WALKER_ROUTE_DIRECTION][0], Float:dy = s_WalkerRoutes[actorid][E_WALKER_ROUTE_DIRECTION][1], bool:blocked = false;
        for (new j = 0; j < count; j++)
        {
            new other = bodies[j];
            if (i != j && floatabs(positions[i][2] - positions[j][2]) < 1.5 && dx * s_WalkerRoutes[other][E_WALKER_ROUTE_DIRECTION][0] + dy * s_WalkerRoutes[other][E_WALKER_ROUTE_DIRECTION][1] > 0.8 && Walkers_NeedsGap(actorid,other,dx,dy,positions[j][0] - positions[i][0],positions[j][1] - positions[i][1]))
            {
                blocked = true;
                break;
            }
        }
        if (blocked != s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRAFFIC])
        {
            s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRAFFIC] = blocked;
            if (blocked)
            {
                StopPedestrian(actorid);
            }
            else
            {
                SetPedestrianTarget(actorid,s_WalkerRoutes[actorid][E_WALKER_ROUTE_TARGET][0],s_WalkerRoutes[actorid][E_WALKER_ROUTE_TARGET][1],s_WalkerRoutes[actorid][E_WALKER_ROUTE_TARGET][2],s_WalkerRoutes[actorid][E_WALKER_ROUTE_KEEP] ? s_WalkerRoutes[actorid][E_WALKER_ROUTE_SPEED] : WALKERS_HOME_SPEED);
                ApplyPedestrianAnim(actorid,"PED",GetPedestrianSex(actorid) == 2 ? "WOMAN_walknorm" : "WALK_civi",4.1,true,true,true,false,0);
            }
        }
    }
}

static Walkers_NextPoint(actorid)
{
    if (Walkers_IsPaused(actorid))
    {
        return;
    }

	new Float:x, Float:y, Float:z;

	if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL])
	{
		Walkers_ClearRoute(actorid);
		pawn_call_public("Walkers_OnArrive","d",actorid);
		return;
	}

	if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT] >= s_WalkerRoutes[actorid][E_WALKER_ROUTE_COUNT] || !Walkers_GetTravelPoint(actorid,s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT],x,y,z))
	{
		if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_KEEP])
		{
			s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL] = true;
			Walkers_Target(actorid,s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][0],s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][1],s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][2],s_WalkerRoutes[actorid][E_WALKER_ROUTE_SPEED]);
			return;
		}

		Walkers_GoInside(actorid);
		return;
	}

	s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT]++;
	Walkers_Target(actorid,x,y,z,s_WalkerRoutes[actorid][E_WALKER_ROUTE_KEEP] ? s_WalkerRoutes[actorid][E_WALKER_ROUTE_SPEED] : WALKERS_HOME_SPEED);
}

stock bool:Walkers_GetRoadNode(Float:x,Float:y,Float:z,&area,&node,&Float:roadX,&Float:roadY,&Float:roadZ)
{
    return Paths_ClosestNode(PATHS_LAYER_PED,x,y,z,area,node,WALKERS_ROAD_REACH) && Paths_NodePos(PATHS_LAYER_PED,area,node,roadX,roadY,roadZ) && floatabs(roadZ - z) <= WALKERS_ROAD_LEVEL;
}

stock bool:Walkers_GetRoutePoint(actorid,point,&Float:x,&Float:y,&Float:z)
{
    return actorid >= 0 && actorid < MAX_ACTORS && s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] != INVALID_PATH_ID && point >= 0 && point < s_WalkerRoutes[actorid][E_WALKER_ROUTE_COUNT] && NPC_GetPathPoint(s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH],point,x,y,z);
}

stock bool:Walkers_AreRoadLinked(fromArea,fromNode,toArea,toNode)
{
    if (fromArea == toArea && fromNode == toNode)
    {
        return true;
    }

    for (new link = 0, count = Paths_NodeLinkCount(PATHS_LAYER_PED,fromArea,fromNode);link < count;link++)
    {
        new area, node;

        if (Paths_NodeLink(PATHS_LAYER_PED,fromArea,fromNode,link,area,node) && area == toArea && node == toNode)
        {
            return true;
        }
    }

    return false;
}

stock Walkers_FindRoadPath(Float:fromX,Float:fromY,Float:fromZ,Float:toX,Float:toY,Float:toZ)
{
    new fromArea, fromNode, toArea, toNode, Float:roadFromX, Float:roadFromY, Float:roadFromZ, Float:roadToX, Float:roadToY, Float:roadToZ;

    if (!Walkers_GetRoadNode(fromX,fromY,fromZ,fromArea,fromNode,roadFromX,roadFromY,roadFromZ))
    {
        return -PATHS_NO_START_NODE;
    }

    if (!Walkers_GetRoadNode(toX,toY,toZ,toArea,toNode,roadToX,roadToY,roadToZ))
    {
        return -PATHS_NO_TARGET_NODE;
    }

    return Paths_Find(PATHS_LAYER_PED,roadFromX,roadFromY,roadFromZ,roadToX,roadToY,roadToZ);
}

stock bool:Walkers_RouteTo(actorid,Float:x,Float:y,Float:z,Float:speed = WALKERS_HOME_SPEED,bool:direct = false,bool:roadside = true)
{
	new Float:fromX, Float:fromY, Float:fromZ;

	if (actorid < 0 || actorid >= MAX_ACTORS || IsValidPedestrian(actorid) != 1 || !GetPedestrianPos(actorid,fromX,fromY,fromZ))
	{
		return false;
	}

	Walkers_ClearRoute(actorid);
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_KEEP] = true;
    s_WalkerRoutes[actorid][E_WALKER_ROUTE_ROADSIDE] = roadside;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][0] = x;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][1] = y;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][2] = z;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_SPEED] = speed;

	if (direct && Walkers_MeshLength(fromX,fromY,fromZ,x,y,z) == -1.0)
	{
		Log_Warn("walkers","no mesh route for pedestrian %d from %.1f %.1f %.1f to %.1f %.1f %.1f",actorid,fromX,fromY,fromZ,x,y,z);
		Walkers_ClearRoute(actorid);
		return false;
	}

	if (direct || Walkers_ShouldGoDirect(fromX,fromY,fromZ,x,y,z))
	{
		s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL] = true;
        if (!Walkers_IsPaused(actorid))
        {
            Walkers_Target(actorid,x,y,z,speed);
        }
		return true;
	}

    new request = Walkers_FindRoadPath(fromX,fromY,fromZ,x,y,z);

	if (request <= 0)
	{
		Walkers_ClearRoute(actorid);
		return false;
	}

	s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] = request;
    StopPedestrian(actorid);
	return true;
}

stock bool:Walkers_IsPaused(actorid)
{
    return actorid >= 0 && actorid < MAX_ACTORS && (s_WalkerPaused[actorid] || s_WalkerTalkPaused[actorid]);
}

stock Walkers_SetPaused(actorid,bool:paused)
{
    if (actorid < 0 || actorid >= MAX_ACTORS || IsValidPedestrian(actorid) != 1)
    {
        return;
    }

    new bool:wasPaused = Walkers_IsPaused(actorid);
    s_WalkerPaused[actorid] = paused;
    Walkers_UpdatePaused(actorid,wasPaused);
}

stock Walkers_SetTalkPaused(actorid,bool:paused)
{
    if (actorid < 0 || actorid >= MAX_ACTORS || IsValidPedestrian(actorid) != 1)
    {
        return;
    }

    new bool:wasPaused = Walkers_IsPaused(actorid);
    s_WalkerTalkPaused[actorid] = paused;
    Walkers_UpdatePaused(actorid,wasPaused);
}

static Walkers_UpdatePaused(actorid,bool:wasPaused)
{
    new bool:paused = Walkers_IsPaused(actorid);
    if (paused == wasPaused)
    {
        return;
    }

    if (paused)
    {
        StopPedestrian(actorid);
        return;
    }

    if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] > 0)
    {
        return;
    }

    ApplyPedestrianAnim(actorid,"PED",GetPedestrianSex(actorid) == 2 ? "WOMAN_walknorm" : "WALK_civi",4.1,true,true,true,false,0);

    if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL])
    {
        Walkers_Target(actorid,s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][0],s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][1],s_WalkerRoutes[actorid][E_WALKER_ROUTE_GOAL][2],s_WalkerRoutes[actorid][E_WALKER_ROUTE_SPEED]);
    }
    else if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] != INVALID_PATH_ID)
    {
        new point = s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT];

        if (point > 0)
        {
            s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT]--;
        }

        Walkers_NextPoint(actorid);
    }
    else
    {
        ResumePedestrian(actorid);
    }
}

stock Walkers_StopRoute(actorid)
{
	if (actorid >= 0 && actorid < MAX_ACTORS)
	{
		Walkers_ClearRoute(actorid);
	}
}

stock Walkers_FindHome(Float:x,Float:y,Float:beyond = -1.0,&Float:found = 0.0)
{
	new best = -1, Float:bestDistance = WALKERS_HOME_RANGE;

	for (new i = 0;i < s_WalkerHomeCount;i++)
	{
		new Float:distance = VectorSize(s_WalkerHomes[i][0] - x,s_WalkerHomes[i][1] - y,0.0);

		if (distance > beyond && distance < bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	found = bestDistance;
	return best;
}

stock Walkers_SendHome(actorid)
{
	new Float:x, Float:y, Float:z;

	if (IsValidPedestrian(actorid) != 1 || !GetPedestrianPos(actorid,x,y,z))
	{
		return;
	}

	new tries = s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRIES], Float:beyond = tries > 0 ? s_WalkerRoutes[actorid][E_WALKER_ROUTE_DISTANCE] : -1.0, Float:distance;
	Walkers_ClearRoute(actorid);
	new home = Walkers_FindHome(x,y,beyond,distance);

	if (home == -1 || tries >= WALKERS_HOME_TRIES)
	{
		Walkers_GoInside(actorid);
		return;
	}

	s_WalkerRoutes[actorid][E_WALKER_ROUTE_TRIES] = tries + 1;
	s_WalkerRoutes[actorid][E_WALKER_ROUTE_DISTANCE] = distance;

    new request = Walkers_FindRoadPath(x,y,z,s_WalkerHomes[home][0],s_WalkerHomes[home][1],s_WalkerHomes[home][2]);

	if (request <= 0)
	{
		Walkers_GoInside(actorid);
		return;
	}

	s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] = request;
}

static Walkers_SetNight(bool:isNight)
{
	s_WalkersNight = isNight;
	Path_SetSpawnDensity(WALKERS_DAY_DENSITY);
	Walkers_DespawnAmbient();
}

stock Walkers_FollowCalendar()
{
	if (s_WalkerNodeCount > 0 && Calendar_IsNight() != s_WalkersNight)
	{
		Walkers_SetNight(Calendar_IsNight());
	}
}

static Walkers_LoadHomes()
{
	new File:handle = fopen(WALKERS_GRAPH_FILE,io_read), line[WALKERS_HOME_LINE], area, node, Float:x, Float:y, Float:z;
	s_WalkerHomeCount = 0;

	if (!handle)
	{
		return;
	}

	while (fread(handle,line) && s_WalkerHomeCount < WALKERS_MAX_HOMES)
	{
		if (line[0] != 'H' || sscanf(line[1],"dd",area,node) || !Paths_NodePos(PATHS_LAYER_PED,area,node,x,y,z))
		{
			continue;
		}

		s_WalkerHomes[s_WalkerHomeCount][0] = x;
		s_WalkerHomes[s_WalkerHomeCount][1] = y;
		s_WalkerHomes[s_WalkerHomeCount][2] = z;
		s_WalkerHomeCount++;
	}

	fclose(handle);
}

stock Walkers_Setup()
{
	for (new actorid = 0;actorid < MAX_ACTORS;actorid++)
	{
		s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] = INVALID_PATH_ID;
		Walkers_ClearRoute(actorid);
	}

	Path_SetSpawnDensity(WALKERS_DAY_DENSITY);
	Walkers_DespawnAmbient();

	if (!Paths_LoadCustom(WALKERS_GRAPH_FILE))
	{
		Log_Error("walkers","no path graph at scriptfiles/%s, nobody walks",WALKERS_GRAPH_FILE);
		return;
	}

	s_WalkerNodeCount = Path_ReloadNodes();
	Walkers_LoadHomes();
	Path_SetUseColAndreas(true);
	TogglePedInInterior(false);
	Path_SetMaxActorsInPool(WALKERS_POOL);
	Path_SetMaxActorsPerPlayer(WALKERS_PER_PLAYER);
	Path_SetStreamingDistance(WALKERS_STREAM_DISTANCE);

	for (new sex = 0;sex < 2;sex++)
	{
		for (new nth = 0, count = Skins_CountStarter(sex);nth < count;nth++)
		{
			if (sex == 0)
			{
				Path_AddMaleSkin(Skins_GetStarter(sex,nth),WALKERS_WALK_MAN);
			}
			else
			{
				Path_AddFemaleSkin(Skins_GetStarter(sex,nth),WALKERS_WALK_WOMAN);
			}
		}
	}

	Walkers_SetNight(Calendar_IsNight());
	Log_Info("walkers","%d path nodes, %d homes",s_WalkerNodeCount,s_WalkerHomeCount);
}

CMD<ADMIN_LEVEL_TRIAL>:walkers(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new walking = 0, routing = 0;

	for (new actorid = 0;actorid < MAX_ACTORS;actorid++)
	{
		if (IsValidPedestrian(actorid) == 1)
		{
			walking++;

			if (Walkers_IsRouting(actorid))
			{
				routing++;
			}
		}
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Walkers: %d out, %d heading home. Graph: %d nodes, %d homes. %s, density %.2f.",walking,routing,s_WalkerNodeCount,s_WalkerHomeCount,s_WalkersNight ? ("Night") : ("Day"),Path_GetSpawnDensity()));
	return 1;
}

Timer_Declare(Walkers_TrafficTick)
{
    Walkers_UpdateTraffic();
    return 1;
}

forward Walkers_OnArrive(actorid);

public Walkers_OnArrive(actorid)
{
	return 1;
}

forward Walkers_OnRouteFailed(actorid);

public Walkers_OnRouteFailed(actorid)
{
	return 1;
}

forward Walkers_OnRouteReady(actorid);

public Walkers_OnRouteReady(actorid)
{
    return 1;
}

forward Walkers_OnSpawn(actorid,nodeid);

public Walkers_OnSpawn(actorid,nodeid)
{
    return 1;
}

public OnPedestrianSpawn(actorid,nodeid)
{
    if (actorid >= 0 && actorid < MAX_ACTORS)
    {
        s_WalkerPaused[actorid] = false;
        s_WalkerTalkPaused[actorid] = false;
        Walkers_ClearRoute(actorid);
    }

    pawn_call_public("Walkers_OnSpawn","dd",actorid,nodeid);
	return 1;
}

public OnPedestrianReachTarget(actorid)
{
	if (actorid >= 0 && actorid < MAX_ACTORS && (s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] != INVALID_PATH_ID || s_WalkerRoutes[actorid][E_WALKER_ROUTE_FINAL]))
	{
		Walkers_NextPoint(actorid);
	}

	return 1;
}

public OnPathsFound(requestid,pathid,bool:success,reason)
{
	for (new actorid = 0;actorid < MAX_ACTORS;actorid++)
	{
		if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] != requestid)
		{
			continue;
		}

		s_WalkerRoutes[actorid][E_WALKER_ROUTE_REQUEST] = 0;

		if (IsValidPedestrian(actorid) != 1)
		{
			if (success)
			{
				NPC_DestroyPath(pathid);
			}

			Walkers_ClearRoute(actorid);
			return 1;
		}

		if (!success)
		{
			s_WalkerLastFail = reason;

			if (s_WalkerRoutes[actorid][E_WALKER_ROUTE_KEEP])
			{
				Walkers_ClearRoute(actorid);
				pawn_call_public("Walkers_OnRouteFailed","d",actorid);
				return 1;
			}

			Walkers_SendHome(actorid);
			return 1;
		}

		s_WalkerRoutes[actorid][E_WALKER_ROUTE_PATH] = pathid;
		s_WalkerRoutes[actorid][E_WALKER_ROUTE_POINT] = 0;
		s_WalkerRoutes[actorid][E_WALKER_ROUTE_COUNT] = NPC_GetPathPointCount(pathid);
		Walkers_NextPoint(actorid);
        pawn_call_public("Walkers_OnRouteReady","d",actorid);
		return 1;
	}

	if (success)
	{
		NPC_DestroyPath(pathid);
	}

	return 1;
}

#include <pp-hooks>

hook Calendar_OnNightfall()
{
	Walkers_SetNight(true);
}

hook Calendar_OnDawn()
{
	Walkers_SetNight(false);
}

hook Calendar_OnSet()
{
	Walkers_FollowCalendar();
}

hook OnServerFinishLoading()
{
	Walkers_FollowCalendar();
}
