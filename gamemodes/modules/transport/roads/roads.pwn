#define ROADS_REACH (4.5)
#define ROADS_BONUS (1.08)
#define ROADS_MUD (0.75)
#define ROADS_TICK_MS (500)
#define ROADS_SIGN_STREAM (150.0)
#define ROADS_SIGN_TEXT_COLOUR (0xFF2B1D0E)
#define ROADS_SIGN_BACK_COLOUR (0xFFA0815C)

static STREAMER_TAG_OBJECT:s_RoadsWaystones[ROADS_SEED_WAYSTONES + 1];
static bool:s_RoadsOnRoad[MAX_PLAYERS];
static Float:s_RoadsScale[MAX_PLAYERS];
static s_RoadsMudOverride = -1;

stock bool:Roads_IsOnRoad(Float:x,Float:y,Float:z)
{
	new area, node;
	return Paths_ClosestNode(PATHS_LAYER_PED,x,y,z,area,node,ROADS_REACH);
}

stock Roads_SetMudOverride(value)
{
	s_RoadsMudOverride = value;
}

stock bool:Roads_IsMuddy()
{
	if (s_RoadsMudOverride != -1)
	{
		return s_RoadsMudOverride == 1;
	}

	new weather = Calendar_GetWeather();
	return Weather_IsSnowing() || weather == 8 || weather == 16;
}

stock Float:Roads_RideScale(bool:onRoad,Float:cartPull,bool:hasCart,bool:muddy)
{
	new Float:scale = onRoad ? ROADS_BONUS : 1.0;

	if (hasCart)
	{
		scale *= cartPull;

		if (muddy && !onRoad)
		{
			scale *= ROADS_MUD;
		}
	}

	return scale;
}

stock bool:Roads_PlayerOnRoad(playerid)
{
	return Util_IsValidPlayer(playerid) && s_RoadsOnRoad[playerid];
}

stock Float:Roads_GetScale(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_RoadsScale[playerid] : 1.0;
}

stock Roads_UpdateRider(playerid)
{
	if (!Mount_IsRiding(playerid))
	{
		if (s_RoadsScale[playerid] != 1.0)
		{
			s_RoadsScale[playerid] = 1.0;
			Mount_SetSpeedScale(playerid,1.0);
		}

		return;
	}

	new Float:x, Float:y, Float:z, cart = Carts_GetOfPlayer(playerid);
	GetPlayerPos(playerid,x,y,z);
	s_RoadsOnRoad[playerid] = GetPlayerVirtualWorld(playerid) == 0 && Roads_IsOnRoad(x,y,z - 1.0);
	new Float:scale = Roads_RideScale(s_RoadsOnRoad[playerid],Carts_SpeedFactor(cart),cart != -1,Roads_IsMuddy());

	if (floatabs(scale - s_RoadsScale[playerid]) > 0.001)
	{
		s_RoadsScale[playerid] = scale;
		Mount_SetSpeedScale(playerid,scale);
	}
}

static Roads_PaintArm(STREAMER_TAG_OBJECT:objectid,first,const text[])
{
	if (text[0] == EOS)
	{
		return;
	}

	for (new face = 0;face < 2;face++)
	{
		SetDynamicObjectMaterialText(objectid,first + face,text,_:OBJECT_MATERIAL_SIZE_256x64,"Times New Roman",22,1,ROADS_SIGN_TEXT_COLOUR,ROADS_SIGN_BACK_COLOUR,_:OBJECT_MATERIAL_TEXT_ALIGN_CENTRE);
	}
}

stock Roads_WaystoneModel(index)
{
    if (index < 0 || index >= ROADS_SEED_WAYSTONES)
    {
        return MODEL_VILLAGE_SIGNPOST;
    }

    if (g_RoadsWaystoneDefs[index][E_ROADS_WAYSTONE_DEF_PLUS_X][0] == EOS)
    {
        return MODEL_VILLAGE_SIGN_NO_PLUS_X;
    }

    if (g_RoadsWaystoneDefs[index][E_ROADS_WAYSTONE_DEF_MINUS_X][0] == EOS)
    {
        return MODEL_VILLAGE_SIGN_NO_MINUS_X;
    }

    return MODEL_VILLAGE_SIGNPOST;
}

stock Roads_PlaceWaystones()
{
	new count = 0;

	for (new i = 0;i < ROADS_SEED_WAYSTONES;i++)
	{
        new STREAMER_TAG_OBJECT:objectid = CreateDynamicObject(Roads_WaystoneModel(i),g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_POS][0],g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_POS][1],g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_POS][2],0.0,0.0,g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_POS][3],0,0,-1,ROADS_SIGN_STREAM);
		s_RoadsWaystones[i] = objectid;
		Roads_PaintArm(objectid,0,g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_PLUS_X]);
		Roads_PaintArm(objectid,2,g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_MINUS_X]);
		Roads_PaintArm(objectid,4,g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_PLUS_Y]);
		count++;
	}

	return count;
}

stock Roads_NearestWaystone(Float:x,Float:y,&Float:distance)
{
	new best = -1;
	distance = 100000.0;

	for (new i = 0;i < ROADS_SEED_WAYSTONES;i++)
	{
		new Float:d = VectorSize(x - g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_POS][0],y - g_RoadsWaystoneDefs[i][E_ROADS_WAYSTONE_DEF_POS][1],0.0);

		if (d < distance)
		{
			distance = d;
			best = i;
		}
	}

	return best;
}

forward Task:Roads_EnsureCountyCart();
#pragma warning push
#pragma warning disable 204
async Task:Roads_EnsureCountyCart()
{
	if (g_RoadsCountyCart[0] == 0.0 && g_RoadsCountyCart[1] == 0.0)
	{
		wait_ticks(1);
		return async -1;
	}

	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (Carts_IsValid(cart) && Carts_GetKind(cart) == CART_KIND_PRISONER && Carts_GetOwner(cart) == 0)
		{
			wait_ticks(1);
			return async cart;
		}
	}

	return async await Carts_Create(CART_KIND_PRISONER,0,g_RoadsCountyCart[0],g_RoadsCountyCart[1],g_RoadsCountyCart[2],g_RoadsCountyCart[3]);
}
#pragma warning pop

Timer_Declare(Roads_Tick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Roads_UpdateRider(playerid);
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_RoadsOnRoad[playerid] = false;
	s_RoadsScale[playerid] = 1.0;
}
