#define MARKET_VISITORS_COUNT (6)
#define MARKET_VISITORS_KIND (WALKERS_KIND_ACTOR)
#define MARKET_VISITORS_TICK_MS (30000)
static s_MarketVisitorBodies[MARKET_VISITORS_COUNT] = {INVALID_ACTOR_ID, ...};

static bool:MarketVisitors_IsOurs(slot)
{
    new body = s_MarketVisitorBodies[slot];
    if (body == INVALID_ACTOR_ID || IsValidPedestrian(body) != 1 || GetPedestrianKind(body) != MARKET_VISITORS_KIND)
    {
        return false;
    }
    new actor = Actors_FindByBody(body);
    return actor != -1 && actor == Actors_FindByKey(sprintf("market:visitor%d",slot));
}

static MarketVisitors_Release(slot)
{
    new body = s_MarketVisitorBodies[slot];
    if (body == INVALID_ACTOR_ID)
    {
        return;
    }
    new bool:ours = MarketVisitors_IsOurs(slot);
    new actor = Actors_FindByKey(sprintf("market:visitor%d",slot));
    if (actor != -1 && Actors_FindByBody(body) == actor)
    {
        Actors_UnregisterBody(body);
    }
    if (ours)
    {
        DespawnPedestrian(body);
    }
    s_MarketVisitorBodies[slot] = INVALID_ACTOR_ID;
}

stock MarketVisitors_GetBody(slot)
{
    return slot >= 0 && slot < MARKET_VISITORS_COUNT ? s_MarketVisitorBodies[slot] : INVALID_ACTOR_ID;
}

stock MarketVisitors_Count()
{
    new count;
    for (new i = 0; i < MARKET_VISITORS_COUNT; i++)
    {
        if (MarketVisitors_IsOurs(i))
        {
            count++;
        }
    }
    return count;
}

stock MarketVisitors_Clear()
{
    for (new i = 0; i < MARKET_VISITORS_COUNT; i++)
    {
        MarketVisitors_Release(i);
    }
}

stock MarketVisitors_Place()
{
    if (!Market_IsOpen())
    {
        MarketVisitors_Clear();
        return;
    }
    new skins = Skins_CountStarter(0), Float:squareX, Float:squareY, Float:squareZ;
    Market_GetSquare(squareX,squareY,squareZ);
    for (new i = 0; i < MARKET_VISITORS_COUNT; i++)
    {
        if (MarketVisitors_IsOurs(i))
        {
            continue;
        }
        MarketVisitors_Release(i);
        new Float:a = float(i) * 60.0, Float:x = squareX + floatsin(a,degrees) * 10.0, Float:y = squareY + floatcos(a,degrees) * 10.0, Float:hx, Float:hy, Float:z;
        if (!CA_RayCastLine(x,y,squareZ + 10.0,x,y,squareZ - 10.0,hx,hy,z))
        {
            continue;
        }
        new body = SpawnPedestrianAt(skins > 0 ? Skins_GetStarter(0,i % skins) : 1,x,y,z + 1.0,a + 180.0,MARKET_VISITORS_KIND);
        if (body == INVALID_ACTOR_ID)
        {
            continue;
        }
        SetPedestrianBody(body,PED_BODY_PEOPLE);
        if (Actors_RegisterBody(sprintf("market:visitor%d",i),body,0,"Market visitor","Shopper") == -1)
        {
            DespawnPedestrian(body);
            continue;
        }
        s_MarketVisitorBodies[i] = body;
        Walkers_SetPaused(body,true);
    }
}
