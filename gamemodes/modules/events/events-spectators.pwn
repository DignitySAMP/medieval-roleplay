#define EVENTS_SPECTATORS (10)
#define EVENTS_SPECTATOR_KIND (WALKERS_KIND_ACTOR)
#define EVENTS_SPECTATOR_HOME_MS (600000)
#define EVENTS_SPECTATOR_CHEER_MS (2500)

enum E_EVENT_SPECTATOR
{
    E_SPECTATOR_BODY,
    E_SPECTATOR_STATE,
    E_SPECTATOR_ROUTE_STAGE,
    Float:E_SPECTATOR_HOME[3],
    E_SPECTATOR_DEADLINE,
    E_SPECTATOR_CHEER_UNTIL,
}

static s_EventSpectators[EVENTS_SPECTATORS][E_EVENT_SPECTATOR];
static bool:s_EventSpectatorsActive;

stock Events_GetSpectatorBody(index)
{
    return index >= 0 && index < EVENTS_SPECTATORS && s_EventSpectators[index][E_SPECTATOR_STATE] != 0 ? s_EventSpectators[index][E_SPECTATOR_BODY] : INVALID_ACTOR_ID;
}

stock Events_GetSpectatorKind(index)
{
    new body = Events_GetSpectatorBody(index);
    return body != INVALID_ACTOR_ID && IsValidPedestrian(body) ? GetPedestrianKind(body) : -1;
}

stock Events_GetSpectatorState(index)
{
    return index >= 0 && index < EVENTS_SPECTATORS ? s_EventSpectators[index][E_SPECTATOR_STATE] : 0;
}

stock Events_CountSpectators()
{
    new count;
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        if (Events_GetSpectatorBody(i) != INVALID_ACTOR_ID && IsValidPedestrian(Events_GetSpectatorBody(i)))
        {
            count++;
        }
    }
    return count;
}

stock bool:Events_GetSpectatorSpot(index,&Float:x,&Float:y,&Float:z,&Float:a)
{
    if (index < 0 || index >= EVENTS_SPECTATORS)
    {
        return false;
    }
    new Float:side = index < EVENTS_SPECTATORS / 2 ? -1.0 : 1.0;
    Events_ListsToWorld(-12.0 + float(index % (EVENTS_SPECTATORS / 2)) * 6.0,side * 8.5,x,y);
    z = Events_ListsGroundAt(x,y) + 1.0;
    a = Util_NormalizeAngle(Events_ListsFrameAngle() + (side < 0.0 ? 0.0 : 180.0));
    return true;
}

stock Events_GetSpectatorRouteStage(index)
{
    return index >= 0 && index < EVENTS_SPECTATORS ? s_EventSpectators[index][E_SPECTATOR_ROUTE_STAGE] : 0;
}

stock bool:Events_GetSpectatorRoad(&Float:x,&Float:y,&Float:z)
{
    new area, node;
    if (!Paths_ClosestNode(PATHS_LAYER_PED,g_EventsLists[0],g_EventsLists[1],g_EventsLists[2],area,node,WALKERS_ROAD_REACH) || !Paths_NodePos(PATHS_LAYER_PED,area,node,x,y,z))
    {
        return false;
    }
    z += 1.0;
    return true;
}

stock bool:Events_RouteSpectatorToRoad(index,bool:direct = false)
{
    new Float:x, Float:y, Float:z;
    if (!Events_GetSpectatorRoad(x,y,z))
    {
        return false;
    }
    s_EventSpectators[index][E_SPECTATOR_ROUTE_STAGE] = 1;
    return Walkers_RouteTo(Events_GetSpectatorBody(index),x,y,z,WALKERS_HOME_SPEED,direct);
}

stock Events_RemoveSpectator(index)
{
    new body = Events_GetSpectatorBody(index);
    if (body != INVALID_ACTOR_ID)
    {
        Walkers_StopRoute(body);
        Walkers_SetPaused(body,false);
        Actors_UnregisterBody(body);
        DespawnPedestrian(body);
    }
    s_EventSpectators[index][E_SPECTATOR_STATE] = 0;
    s_EventSpectators[index][E_SPECTATOR_ROUTE_STAGE] = 0;
    s_EventSpectators[index][E_SPECTATOR_BODY] = INVALID_ACTOR_ID;
}

stock Events_ClearSpectators()
{
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        Events_RemoveSpectator(i);
    }
    s_EventSpectatorsActive = false;
}

stock Events_StartSpectators()
{
    s_EventSpectatorsActive = true;
    new skins = Skins_CountStarter(0);
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        if (Events_GetSpectatorState(i) != 0)
        {
            continue;
        }
        new village = i % REALM_SEED_POINTS, home = Walkers_FindHome(g_RealmPointDefs[village][E_REALM_POINT_DEF_POS][0],g_RealmPointDefs[village][E_REALM_POINT_DEF_POS][1]), Float:x, Float:y, Float:z;
        if (!Walkers_GetHome(home,x,y,z))
        {
            continue;
        }
        new body = SpawnPedestrianAt(skins > 0 ? Skins_GetStarter(0,i % skins) : 1,x,y,z + 1.0,0.0,EVENTS_SPECTATOR_KIND);
        if (body == INVALID_ACTOR_ID)
        {
            continue;
        }
        SetPedestrianBody(body,PED_BODY_PEOPLE);
        if (Actors_RegisterBody(sprintf("events:spectator%d",i),body,0,"Villager","Tournament spectator") == -1)
        {
            DespawnPedestrian(body);
            continue;
        }
        s_EventSpectators[i][E_SPECTATOR_BODY] = body;
        s_EventSpectators[i][E_SPECTATOR_STATE] = 1;
        s_EventSpectators[i][E_SPECTATOR_HOME][0] = x;
        s_EventSpectators[i][E_SPECTATOR_HOME][1] = y;
        s_EventSpectators[i][E_SPECTATOR_HOME][2] = z + 1.0;
        s_EventSpectators[i][E_SPECTATOR_DEADLINE] = GetTickCount() + EVENTS_SPECTATOR_HOME_MS;
        if (!Events_RouteSpectatorToRoad(i))
        {
            Events_RemoveSpectator(i);
        }
    }
}

stock Events_SendSpectatorsHome()
{
    s_EventSpectatorsActive = false;
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        new body = Events_GetSpectatorBody(i);
        if (body == INVALID_ACTOR_ID || s_EventSpectators[i][E_SPECTATOR_STATE] == 3)
        {
            continue;
        }
        new bool:onRoadJourney = s_EventSpectators[i][E_SPECTATOR_STATE] == 1 && s_EventSpectators[i][E_SPECTATOR_ROUTE_STAGE] == 1;
        s_EventSpectators[i][E_SPECTATOR_STATE] = 3;
        s_EventSpectators[i][E_SPECTATOR_DEADLINE] = GetTickCount() + EVENTS_SPECTATOR_HOME_MS;
        Walkers_SetPaused(body,false);
        if (onRoadJourney)
        {
            s_EventSpectators[i][E_SPECTATOR_ROUTE_STAGE] = 2;
            if (!Walkers_RouteTo(body,s_EventSpectators[i][E_SPECTATOR_HOME][0],s_EventSpectators[i][E_SPECTATOR_HOME][1],s_EventSpectators[i][E_SPECTATOR_HOME][2]))
            {
                Events_RemoveSpectator(i);
            }
        }
        else if (!Events_RouteSpectatorToRoad(i,true))
        {
            Events_RemoveSpectator(i);
        }
    }
}

stock Events_SpectatorArrive(body)
{
    if (body == INVALID_ACTOR_ID || !IsValidPedestrian(body))
    {
        return;
    }
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        if (Events_GetSpectatorBody(i) != body)
        {
            continue;
        }
        if (s_EventSpectators[i][E_SPECTATOR_STATE] == 2)
        {
            return;
        }
        if (s_EventSpectators[i][E_SPECTATOR_ROUTE_STAGE] == 1)
        {
            s_EventSpectators[i][E_SPECTATOR_ROUTE_STAGE] = 2;
            if (s_EventSpectators[i][E_SPECTATOR_STATE] == 3)
            {
                if (!Walkers_RouteTo(body,s_EventSpectators[i][E_SPECTATOR_HOME][0],s_EventSpectators[i][E_SPECTATOR_HOME][1],s_EventSpectators[i][E_SPECTATOR_HOME][2]))
                {
                    Events_RemoveSpectator(i);
                }
            }
            else
            {
                new Float:x, Float:y, Float:z, Float:a;
                Events_GetSpectatorSpot(i,x,y,z,a);
                if (!Walkers_RouteTo(body,x,y,z,WALKERS_HOME_SPEED,true))
                {
                    Events_RemoveSpectator(i);
                }
            }
            return;
        }
        if (s_EventSpectators[i][E_SPECTATOR_STATE] == 3)
        {
            Events_RemoveSpectator(i);
            return;
        }
        new Float:x, Float:y, Float:z, Float:a;
        Events_GetSpectatorSpot(i,x,y,z,a);
        Walkers_StopRoute(body);
        s_EventSpectators[i][E_SPECTATOR_STATE] = 2;
        s_EventSpectators[i][E_SPECTATOR_CHEER_UNTIL] = 0;
        Walkers_SetPaused(body,true);
        SetPedestrianFacingAngle(body,a);
        StopPedestrian(body);
        ApplyPedestrianAnim(body,"PED","IDLE_CHAT",4.1,true,false,false,false,0);
        return;
    }
}

stock Events_SpectatorRouteFailed(body)
{
    if (body == INVALID_ACTOR_ID)
    {
        return;
    }
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        if (Events_GetSpectatorBody(i) == body)
        {
            Events_RemoveSpectator(i);
            return;
        }
    }
}

stock bool:Events_IsSpectatorCheering(index)
{
    return index >= 0 && index < EVENTS_SPECTATORS && s_EventSpectators[index][E_SPECTATOR_STATE] == 2 && s_EventSpectators[index][E_SPECTATOR_CHEER_UNTIL] != 0;
}

stock Events_CheerSpectators()
{
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        if (s_EventSpectators[i][E_SPECTATOR_STATE] != 2 || !IsValidPedestrian(Events_GetSpectatorBody(i)))
        {
            continue;
        }
        s_EventSpectators[i][E_SPECTATOR_CHEER_UNTIL] = GetTickCount() + EVENTS_SPECTATOR_CHEER_MS;
        ApplyPedestrianAnim(Events_GetSpectatorBody(i),"ON_LOOKERS","shout_01",4.1,false,false,false,false,EVENTS_SPECTATOR_CHEER_MS);
    }
}

stock Events_RefreshSpectators()
{
    new bool:active;
    for (new event = 0; event < EVENTS_MAX; event++)
    {
        if (Events_IsValid(event) && Events_GetKind(event) == EVENT_TOURNAMENT && Events_GetState(event) != EVENT_DONE && gettime() < Events_GetEnds(event))
        {
            active = true;
        }
    }
    if (active && !s_EventSpectatorsActive)
    {
        Events_ClearSpectators();
        Events_StartSpectators();
    }
    else if (!active && s_EventSpectatorsActive)
    {
        Events_SendSpectatorsHome();
    }
    new now = GetTickCount();
    for (new i = 0; i < EVENTS_SPECTATORS; i++)
    {
        if (Events_GetSpectatorState(i) == 0)
        {
            continue;
        }
        new body = Events_GetSpectatorBody(i);
        if (!IsValidPedestrian(body) || GetPedestrianHealth(body) <= 0.0 || (Events_GetSpectatorState(i) != 2 && now - s_EventSpectators[i][E_SPECTATOR_DEADLINE] >= 0))
        {
            Events_RemoveSpectator(i);
        }
        else if (Events_GetSpectatorState(i) == 2 && s_EventSpectators[i][E_SPECTATOR_CHEER_UNTIL] != 0 && now - s_EventSpectators[i][E_SPECTATOR_CHEER_UNTIL] >= 0)
        {
            s_EventSpectators[i][E_SPECTATOR_CHEER_UNTIL] = 0;
            ApplyPedestrianAnim(body,"PED","IDLE_CHAT",4.1,true,false,false,false,0);
        }
    }
}

Timer_Declare(Events_SpectatorsTick)
{
    Events_RefreshSpectators();
    return 1;
}

#include <pp-hooks>
hook Events_OnDeclared(event,kind)
{
    #pragma unused event, kind
    Events_RefreshSpectators();
}

hook Events_OnEnded(event,kind)
{
    #pragma unused event, kind
    Events_RefreshSpectators();
}

hook Walkers_OnArrive(actorid)
{
    Events_SpectatorArrive(actorid);
}

hook Walkers_OnRouteFailed(actorid)
{
    Events_SpectatorRouteFailed(actorid);
}

hook Events_OnCourse(winnerid,loserid,result)
{
    #pragma unused winnerid, loserid
    if (result > 0)
    {
        Events_CheerSpectators();
    }
}
