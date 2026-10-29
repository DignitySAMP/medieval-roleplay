#define HOUSE_PIECES (5)

static STREAMER_TAG_OBJECT:s_HousePieces[HOUSE_SEED_COUNT][HOUSE_PIECES];
static STREAMER_TAG_3D_TEXT_LABEL:s_HouseDoorLabels[HOUSE_SEED_COUNT];
static bool:s_HouseFireLit[HOUSE_SEED_COUNT];
static s_HouseFireForced[HOUSE_SEED_COUNT] = {-1, ...};
static s_HouseUnbarredUntil[HOUSE_SEED_COUNT];
static bool:s_HouseGutted[HOUSE_SEED_COUNT];
static s_HouseCandleSources[HOUSE_SEED_LIGHTS] = {-1, ...};
static PlayerText:s_HouseDark[MAX_PLAYERS] = {PlayerText:INVALID_TEXT_DRAW, ...};

stock bool:Houses_IsOpen()
{
	new hour = Calendar_GetHour();
	return hour >= HOUSE_OPEN_HOUR && hour < HOUSE_CLOSE_HOUR;
}

stock Houses_GetInside(playerid)
{
	new house = GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE;
	return Houses_IsValid(house) && GetPlayerInterior(playerid) == HOUSE_INTERIOR ? house : -1;
}

stock bool:Houses_IsInside(playerid)
{
	return Houses_GetInside(playerid) != -1;
}

stock bool:Houses_IsFireLit(house)
{
	return Houses_IsValid(house) && s_HouseFireLit[house];
}

stock Houses_SetFireForced(house,mode)
{
	if (Houses_IsValid(house))
	{
		s_HouseFireForced[house] = mode;
		Houses_RefreshFire(house);
	}
}

stock Houses_RefreshFire(house)
{
	new hour = Calendar_GetHour(), bool:isLit = s_HouseFireForced[house] == -1 ? (hour >= HOUSE_FIRE_FROM && hour < HOUSE_FIRE_UNTIL) : s_HouseFireForced[house] == 1;
	new model = g_HouseDefs[house][E_HOUSE_DEF_MODELS][3];

	if (isLit == s_HouseFireLit[house] && (!isLit || IsValidDynamicObject(s_HousePieces[house][3])))
	{
		return;
	}

	s_HouseFireLit[house] = isLit;

	if (IsValidDynamicObject(s_HousePieces[house][3]))
	{
		DestroyDynamicObject(s_HousePieces[house][3]);
	}

	s_HousePieces[house][3] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	Light_Unfollow(LIGHT_FOLLOW_HOUSE_FIRE,house);

	if (isLit && model != 0)
	{
		new Float:x, Float:y, Float:z;
		Houses_LocalToWorld(0.0,0.0,0.0,x,y,z);
		s_HousePieces[house][3] = CreateDynamicObject(model,x,y,z,0.0,0.0,0.0,Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
		Light_FollowModel(LIGHT_FOLLOW_HOUSE_FIRE,house,model,x,y,z,0.0,Houses_GetWorld(house),HOUSE_INTERIOR);
	}
}

stock Houses_Build()
{
	new Float:x, Float:y, Float:z;
	Houses_LocalToWorld(0.0,0.0,0.0,x,y,z);

	for (new house = 0;house < HOUSE_SEED_COUNT;house++)
	{
		for (new piece = 0;piece < HOUSE_PIECES;piece++)
		{
			new model = g_HouseDefs[house][E_HOUSE_DEF_MODELS][piece];
			s_HousePieces[house][piece] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

			if (model != 0 && piece != 3)
			{
				s_HousePieces[house][piece] = CreateDynamicObject(model,x,y,z,0.0,0.0,0.0,Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
				if (piece == 0)
				{
					Util_WatchInteriorShell(s_HousePieces[house][piece]);
				}

				Light_FollowModel(LIGHT_FOLLOW_HOUSE,house,model,x,y,z,0.0,Houses_GetWorld(house),HOUSE_INTERIOR);
			}
		}

		s_HouseFireLit[house] = false;
		Houses_RefreshFire(house);

		new label[48];
		format(label,sizeof(label),"%s",g_HouseDefs[house][E_HOUSE_DEF_NAME]);
		label[0] = toupper(label[0]);
		s_HouseDoorLabels[house] = CreateDynamic3DTextLabel(label,0xD8CCB2AA,g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2] + 2.2,6.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,true,0,0);
	}

	Houses_PlaceWoodpiles();
	Houses_PlaceLetBeds();
}

stock Houses_FindDoorNear(playerid,Float:range = HOUSE_DOOR_REACH)
{
	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		return -1;
	}

	for (new house = 0;house < HOUSE_SEED_COUNT;house++)
	{
		if (IsPlayerInRangeOfPoint(playerid,range,g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2] + 1.0))
		{
			return house;
		}
	}

	return -1;
}

stock bool:Houses_IsAtExit(playerid)
{
	new house = Houses_GetInside(playerid), Float:x, Float:y, Float:z;

	if (house == -1)
	{
		return false;
	}

	Houses_LocalToWorld(g_HouseDefs[house][E_HOUSE_DEF_EXIT][0],g_HouseDefs[house][E_HOUSE_DEF_EXIT][1],g_HouseDefs[house][E_HOUSE_DEF_EXIT][2],x,y,z);
	return IsPlayerInRangeOfPoint(playerid,g_HouseDefs[house][E_HOUSE_DEF_EXIT][3] + 0.6,x,y,z);
}

stock bool:Houses_IsBarredFor(playerid,house)
{
	return !Houses_IsOpen() && !Houses_HoldsRoomIn(playerid,house) && gettime() >= s_HouseUnbarredUntil[house];
}

forward bool:Houses_IsGutted(house);

stock bool:Houses_CanEnter(playerid,house)
{
	return !Houses_IsGutted(house) && (!Houses_IsBarredFor(playerid,house) || Account_GetAdminLevel(playerid) >= ADMIN_LEVEL_TRIAL);
}

stock bool:Houses_IsGutted(house)
{
	return Houses_IsValid(house) && s_HouseGutted[house];
}

stock Houses_SetGutted(house,bool:isGutted)
{
	if (!Houses_IsValid(house))
	{
		return;
	}

	s_HouseGutted[house] = isGutted;

	if (!isGutted)
	{
		return;
	}

	foreach (new playerid : Player)
	{
		if (Houses_GetInside(playerid) == house)
		{
			Houses_Leave(playerid);
		}
	}
}

stock Houses_Enter(playerid,house)
{
	new Float:x, Float:y, Float:z;
	Houses_LocalToWorld(g_HouseDefs[house][E_HOUSE_DEF_SPAWN][0],g_HouseDefs[house][E_HOUSE_DEF_SPAWN][1],g_HouseDefs[house][E_HOUSE_DEF_SPAWN][2] + 1.0,x,y,z);
	Util_SafeTeleport(playerid,x,y,z,g_HouseDefs[house][E_HOUSE_DEF_SPAWN][3],Houses_GetWorld(house),HOUSE_INTERIOR);
	pawn_call_public("Houses_OnEntered","dd",playerid,house);
}

stock Houses_Leave(playerid)
{
	new house = Houses_GetInside(playerid);

	if (house == -1)
	{
		return;
	}

	new Float:a = g_HouseDefs[house][E_HOUSE_DEF_DOOR][3], Float:x = g_HouseDefs[house][E_HOUSE_DEF_DOOR][0] - 0.8 * floatsin(a,degrees), Float:y = g_HouseDefs[house][E_HOUSE_DEF_DOOR][1] + 0.8 * floatcos(a,degrees), Float:z = g_HouseDefs[house][E_HOUSE_DEF_DOOR][2] + 1.0;
	Util_SafeTeleport(playerid,x,y,z,a,0,0);
	Streamer_UpdateEx(playerid,x,y,z,0,0,STREAMER_TYPE_OBJECT,HOUSE_DOOR_PRELOAD_MS,1);
	Houses_HideDark(playerid);
	pawn_call_public("Houses_OnLeft","dd",playerid,house);
}

stock Houses_Knock(playerid,house)
{
	new name[28], text[96];
	Houses_GetName(house,name);
	format(text,sizeof(text),"Someone knocks at the door. A tenant can unbar it at the door inside.");

	foreach (new i : Player)
	{
		if (Houses_GetInside(i) == house)
		{
			Gui_Notify(i,text);
		}
	}

	Chat_Speak(playerid,CHAT_ME,"knocks at the door.");
}

stock Houses_Unbar(house)
{
	s_HouseUnbarredUntil[house] = gettime() + 60;
}

stock bool:Houses_IsUnbarred(house)
{
	return gettime() < s_HouseUnbarredUntil[house];
}

stock Houses_FindCandleSlot(playerid,Float:range)
{
	new house = Houses_GetInside(playerid), best = -1, Float:bestDistance = range;

	if (house == -1)
	{
		return -1;
	}

	for (new i = 0;i < HOUSE_SEED_LIGHTS;i++)
	{
		if (floatround(g_HouseCandleDefs[i][0]) != house)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Houses_LocalToWorld(g_HouseCandleDefs[i][1],g_HouseCandleDefs[i][2],g_HouseCandleDefs[i][3],x,y,z);
		new Float:distance = GetPlayerDistanceFromPoint(playerid,x,y,z);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock bool:Houses_IsCandleLit(slot)
{
	new source = s_HouseCandleSources[slot];

	if (source == -1 || !Light_IsSourceLit(source))
	{
		return false;
	}

	new Float:x, Float:y, Float:z, world, Float:slotX, Float:slotY, Float:slotZ;
	Light_GetSourcePos(source,x,y,z,world);
	Houses_LocalToWorld(g_HouseCandleDefs[slot][1],g_HouseCandleDefs[slot][2],g_HouseCandleDefs[slot][3],slotX,slotY,slotZ);
	return world == Houses_GetWorld(floatround(g_HouseCandleDefs[slot][0])) && Util_GetDistance3D(x,y,z,slotX,slotY,slotZ) < 0.2;
}

stock bool:Houses_LightCandle(playerid,slot)
{
	if (Houses_IsCandleLit(slot))
	{
		Gui_Notify(playerid,"That candle is already burning.");
		return false;
	}

	new candle = Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE_WAX) > 0 ? ITEM_CANDLE_WAX : ITEM_CANDLE;

	if (Inventory_Count(playerid,ITEM_KIND_MATERIAL,candle) == 0)
	{
		Gui_Notify(playerid,"You have no candle.");
		return false;
	}

	if (!Light_CanKindle(playerid) && !Houses_IsFireLit(floatround(g_HouseCandleDefs[slot][0])))
	{
		Gui_Notify(playerid,"You need a flame to light it: the hearth fire, flint, or someone's light.");
		return false;
	}

	new house = floatround(g_HouseCandleDefs[slot][0]), Float:x, Float:y, Float:z;
	Houses_LocalToWorld(g_HouseCandleDefs[slot][1],g_HouseCandleDefs[slot][2],g_HouseCandleDefs[slot][3],x,y,z);
	new source = Light_PlaceCandle(candle == ITEM_CANDLE_WAX,x,y,z,0.0,Houses_GetWorld(house),HOUSE_INTERIOR);

	if (source == -1)
	{
		return false;
	}

	s_HouseCandleSources[slot] = source;
	Inventory_Take(playerid,ITEM_KIND_MATERIAL,candle,1);
	Gui_Notify(playerid,"You light a candle.");
	return true;
}

stock bool:Houses_IsLitInside(house)
{
	if (Houses_IsFireLit(house))
	{
		return true;
	}

	for (new i = 0;i < HOUSE_SEED_LIGHTS;i++)
	{
		if (floatround(g_HouseCandleDefs[i][0]) == house && Houses_IsCandleLit(i))
		{
			return true;
		}
	}

	return false;
}

stock Houses_ShowDark(playerid)
{
	if (s_HouseDark[playerid] != PlayerText:INVALID_TEXT_DRAW)
	{
		return;
	}

	s_HouseDark[playerid] = CreatePlayerTextDraw(playerid,0.0,0.0,"_");
	PlayerTextDrawUseBox(playerid,s_HouseDark[playerid],true);
	PlayerTextDrawBoxColour(playerid,s_HouseDark[playerid],HOUSE_DARK_ALPHA);
	PlayerTextDrawTextSize(playerid,s_HouseDark[playerid],640.0,0.0);
	PlayerTextDrawLetterSize(playerid,s_HouseDark[playerid],0.0,50.0);
	PlayerTextDrawShow(playerid,s_HouseDark[playerid]);
}

stock bool:Houses_IsDarkShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HouseDark[playerid] != PlayerText:INVALID_TEXT_DRAW;
}

stock Houses_HideDark(playerid)
{
	if (s_HouseDark[playerid] == PlayerText:INVALID_TEXT_DRAW)
	{
		return;
	}

	PlayerTextDrawDestroy(playerid,s_HouseDark[playerid]);
	s_HouseDark[playerid] = PlayerText:INVALID_TEXT_DRAW;
}

stock Houses_UpdateDark(playerid)
{
	new house = Houses_GetInside(playerid);

	if (house == -1 || !Calendar_IsNight() || Houses_IsLitInside(house) || Light_HasLight(playerid))
	{
		Houses_HideDark(playerid);
		return;
	}

	if (Kit_IsOpen(playerid) && !Houses_IsDarkShown(playerid))
	{
		return;
	}

	Houses_ShowDark(playerid);
}

forward Houses_OnEntered(playerid,house);

public Houses_OnEntered(playerid,house)
{
	return 1;
}

forward Houses_OnLeft(playerid,house);

public Houses_OnLeft(playerid,house)
{
	return 1;
}

Timer_Declare(Houses_DarkTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Houses_UpdateDark(playerid);
		}
	}

	for (new house = 0;house < HOUSE_SEED_COUNT;house++)
	{
		Houses_RefreshFire(house);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HouseDark[playerid] = PlayerText:INVALID_TEXT_DRAW;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_HouseDark[playerid] = PlayerText:INVALID_TEXT_DRAW;
}
