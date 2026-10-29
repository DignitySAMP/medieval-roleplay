#define MAX_DROPPED_ITEMS (500)
#define DROP_PICKUP_RANGE (2.0)
#define DROP_LABEL_COLOUR (0xD17F5EFF)

enum E_DROP
{
	bool:E_DROP_USED,
	E_DROP_ROW,
	E_DROP_SERIAL,
	E_ITEM_KIND:E_DROP_KIND,
	E_DROP_PARAM,
	E_DROP_AMOUNT,
	E_DROP_STARS,
	E_DROP_FRESH_AT,
	E_DROP_WEAR,
	E_DROP_DATA,
	STREAMER_TAG_OBJECT:E_DROP_OBJECT,
	STREAMER_TAG_3D_TEXT_LABEL:E_DROP_LABEL,
	Float:E_DROP_X,
	Float:E_DROP_Y,
	Float:E_DROP_Z,
	E_DROP_WORLD,
	E_DROP_INTERIOR,
}

static s_Drops[MAX_DROPPED_ITEMS][E_DROP];
static s_DropSerial = 0;

static Drop_Place(dropid)
{
	new name[ITEM_NAME_LEN], label[64];
	Item_GetName(s_Drops[dropid][E_DROP_KIND],s_Drops[dropid][E_DROP_PARAM],name);
	if (s_Drops[dropid][E_DROP_AMOUNT] > 1)
	{
		format(label,sizeof(label),"%s x%d",name,s_Drops[dropid][E_DROP_AMOUNT]);
	}
	else
	{
		strcopy(label,name,sizeof(label));
	}

	s_Drops[dropid][E_DROP_OBJECT] = CreateDynamicObject(Item_GetModel(s_Drops[dropid][E_DROP_KIND],s_Drops[dropid][E_DROP_PARAM],s_Drops[dropid][E_DROP_DATA]),s_Drops[dropid][E_DROP_X],s_Drops[dropid][E_DROP_Y],s_Drops[dropid][E_DROP_Z] - 0.9,0.0,0.0,0.0,s_Drops[dropid][E_DROP_WORLD],s_Drops[dropid][E_DROP_INTERIOR]);
	s_Drops[dropid][E_DROP_LABEL] = CreateDynamic3DTextLabel(label,DROP_LABEL_COLOUR,s_Drops[dropid][E_DROP_X],s_Drops[dropid][E_DROP_Y],s_Drops[dropid][E_DROP_Z] - 0.5,8.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,0,s_Drops[dropid][E_DROP_WORLD],s_Drops[dropid][E_DROP_INTERIOR]);
}

static Drop_Lift(dropid)
{
	if (IsValidDynamicObject(s_Drops[dropid][E_DROP_OBJECT]))
	{
		DestroyDynamicObject(s_Drops[dropid][E_DROP_OBJECT]);
	}

	if (IsValidDynamic3DTextLabel(s_Drops[dropid][E_DROP_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Drops[dropid][E_DROP_LABEL]);
	}

	s_Drops[dropid][E_DROP_USED] = false;
}

stock bool:Drop_IsValid(dropid)
{
	return dropid >= 0 && dropid < MAX_DROPPED_ITEMS && s_Drops[dropid][E_DROP_USED];
}

stock STREAMER_TAG_OBJECT:Drop_GetObject(dropid)
{
    return Drop_IsValid(dropid) ? s_Drops[dropid][E_DROP_OBJECT] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock STREAMER_TAG_3D_TEXT_LABEL:Drop_GetLabel(dropid)
{
    return Drop_IsValid(dropid) ? s_Drops[dropid][E_DROP_LABEL] : STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock bool:Drop_IsInWorld(dropid,world,interior)
{
    return Drop_IsValid(dropid) && s_Drops[dropid][E_DROP_WORLD] == world && (s_Drops[dropid][E_DROP_INTERIOR] == -1 || s_Drops[dropid][E_DROP_INTERIOR] == interior);
}

stock bool:Drop_IsNear(playerid,dropid,Float:range = DROP_PICKUP_RANGE)
{
    return Drop_IsInWorld(dropid,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid)) && GetPlayerDistanceFromPoint(playerid,s_Drops[dropid][E_DROP_X],s_Drops[dropid][E_DROP_Y],s_Drops[dropid][E_DROP_Z]) <= range;
}

stock Drop_GetModel(dropid)
{
    return Drop_IsValid(dropid) && IsValidDynamicObject(s_Drops[dropid][E_DROP_OBJECT]) ? Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_Drops[dropid][E_DROP_OBJECT],E_STREAMER_MODEL_ID) : 0;
}

stock Drop_GetData(dropid)
{
    return Drop_IsValid(dropid) ? s_Drops[dropid][E_DROP_DATA] : 0;
}

stock Drop_Nearest(playerid,Float:range = DROP_PICKUP_RANGE)
{
	new Float:x, Float:y, Float:z, best = -1, Float:bestDistance = range, world = GetPlayerVirtualWorld(playerid), interior = GetPlayerInterior(playerid);
	GetPlayerPos(playerid,x,y,z);

	for (new i = 0; i < MAX_DROPPED_ITEMS; i++)
	{
		if (!Drop_IsInWorld(i,world,interior))
		{
			continue;
		}

		new Float:distance = Util_GetDistance3D(x,y,z,s_Drops[i][E_DROP_X],s_Drops[i][E_DROP_Y],s_Drops[i][E_DROP_Z]);
		if (distance <= bestDistance)
		{
			bestDistance = distance;
			best = i;
		}
	}

	return best;
}

static Drop_Free()
{
	for (new i = 0; i < MAX_DROPPED_ITEMS; i++)
	{
		if (!s_Drops[i][E_DROP_USED])
		{
			return i;
		}
	}

	return -1;
}

forward Task:Drop_InsertRow(dropid);

stock Drop_Create(E_ITEM_KIND:kind,param,amount,Float:x,Float:y,Float:z,world,stars = ITEM_STARS_MIN,row = 0,freshAt = ITEM_FRESH_NOW,wear = 0,data = 0,interior = 0)
{
	new dropid = Drop_Free();
	if (dropid == -1 || !Item_IsValid(kind,param) || !Item_IsValidStars(stars))
	{
		return -1;
	}

	s_Drops[dropid][E_DROP_USED] = true;
	s_Drops[dropid][E_DROP_ROW] = row;
	s_Drops[dropid][E_DROP_SERIAL] = ++s_DropSerial;
	s_Drops[dropid][E_DROP_KIND] = kind;
	s_Drops[dropid][E_DROP_PARAM] = param;
	s_Drops[dropid][E_DROP_AMOUNT] = amount;
	s_Drops[dropid][E_DROP_STARS] = stars;
	s_Drops[dropid][E_DROP_FRESH_AT] = Item_ResolveFresh(kind,param,freshAt);
	s_Drops[dropid][E_DROP_WEAR] = wear;
	s_Drops[dropid][E_DROP_DATA] = data;
	s_Drops[dropid][E_DROP_X] = x;
	s_Drops[dropid][E_DROP_Y] = y;
	s_Drops[dropid][E_DROP_Z] = z;
	s_Drops[dropid][E_DROP_WORLD] = world;
	s_Drops[dropid][E_DROP_INTERIOR] = interior;
	Drop_Place(dropid);

	if (row == 0)
	{
		Drop_InsertRow(dropid);
	}

	return dropid;
}

#pragma warning push
#pragma warning disable 204
async Task:Drop_InsertRow(dropid)
{
	new serial = s_Drops[dropid][E_DROP_SERIAL];
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO dropped_items (kind, param, amount, stars, fresh_at, wear, data, x, y, z, world, interior) VALUES (%d, %d, %d, %d, %d, %d, %d, %f, %f, %f, %d, %d)",_:s_Drops[dropid][E_DROP_KIND],s_Drops[dropid][E_DROP_PARAM],s_Drops[dropid][E_DROP_AMOUNT],s_Drops[dropid][E_DROP_STARS],s_Drops[dropid][E_DROP_FRESH_AT],s_Drops[dropid][E_DROP_WEAR],s_Drops[dropid][E_DROP_DATA],s_Drops[dropid][E_DROP_X],s_Drops[dropid][E_DROP_Y],s_Drops[dropid][E_DROP_Z],s_Drops[dropid][E_DROP_WORLD],s_Drops[dropid][E_DROP_INTERIOR]));

	new row = cache_insert_id();

	if (s_Drops[dropid][E_DROP_USED] && s_Drops[dropid][E_DROP_SERIAL] == serial && s_Drops[dropid][E_DROP_ROW] == 0)
	{
		s_Drops[dropid][E_DROP_ROW] = row;
	}
	else if (row > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM dropped_items WHERE id = %d",row));
	}

	return async row;
}
#pragma warning pop

stock Drop_Remove(dropid)
{
	if (!Drop_IsValid(dropid))
	{
		return;
	}

	if (s_Drops[dropid][E_DROP_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM dropped_items WHERE id = %d",s_Drops[dropid][E_DROP_ROW]));
	}

	Drop_Lift(dropid);
}

stock Drop_GetStars(dropid)
{
	return Drop_IsValid(dropid) ? s_Drops[dropid][E_DROP_STARS] : ITEM_STARS_ANY;
}

static Drop_PlayCrouch(playerid)
{
	if (!Character_IsBusy(playerid))
	{
		ApplyAnimation(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0,SYNC_ALL);
	}
}

stock bool:Inventory_Drop(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount, stars = Inventory_GetSlotStars(playerid,index);
	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || !Session_IsPlaying(playerid))
	{
		return false;
	}

	if (Inventory_GetSlotUsed(playerid,index) > 0 && --amount <= 0)
	{
		Inventory_NotifyStarted(playerid,kind,param);
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	Util_GetOffsetPoint(x,y,a,1.0,x,y);

	if (Drop_Create(kind,param,amount,x,y,z,GetPlayerVirtualWorld(playerid),stars,0,Inventory_GetSlotFresh(playerid,index),Inventory_GetSlotWear(playerid,index),Inventory_GetSlotData(playerid,index),GetPlayerInterior(playerid)) == -1)
	{
		return false;
	}

	Inventory_TakeSlot(playerid,index,amount);
	Drop_PlayCrouch(playerid);
	pawn_call_public("Inventory_OnDropped","ddd",playerid,_:kind,param);
	return true;
}

stock bool:Inventory_PickUp(playerid,dropid)
{
	if (!Drop_IsNear(playerid,dropid) || !Session_IsPlaying(playerid))
	{
		return false;
	}

	if (!Inventory_Give(playerid,s_Drops[dropid][E_DROP_KIND],s_Drops[dropid][E_DROP_PARAM],s_Drops[dropid][E_DROP_AMOUNT],s_Drops[dropid][E_DROP_STARS],s_Drops[dropid][E_DROP_FRESH_AT],s_Drops[dropid][E_DROP_WEAR],s_Drops[dropid][E_DROP_DATA]))
	{
		Gui_Notify(playerid,"Your bag is full. Make some room first.");
		return false;
	}

	Drop_Remove(dropid);
	Drop_PlayCrouch(playerid);
	pawn_call_public("Inventory_OnPickedUp","dd",playerid,dropid);
	return true;
}

forward bool:Trade_IsNear(playerid,otherid);

stock bool:Inventory_HandOver(playerid,index,targetid)
{
	new E_ITEM_KIND:kind, param, amount, stars = Inventory_GetSlotStars(playerid,index), name[ITEM_NAME_LEN], other[MAX_PLAYER_NAME * 2];
	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || kind == ITEM_KIND_COIN || !Session_IsPlaying(playerid) || !Inventory_IsLoaded(targetid))
	{
		return false;
	}

	Nametag_GetKnownName(playerid,targetid,other);
	Item_GetName(kind,param,name);
	name[0] = tolower(name[0]);
	Item_AppendStars(name,stars);

	if (!Trade_IsNear(playerid,targetid))
	{
		Gui_Notify(playerid,sprintf("%s is too far away to hand it to.",other));
		return false;
	}

	if (!Inventory_CanGive(targetid,kind,param,1,stars))
	{
		Gui_Notify(playerid,sprintf("%s can't carry any more. Their bag is full.",other));
		return false;
	}

	new used = Inventory_GetSlotUsed(playerid,index), freshAt = Inventory_GetSlotFresh(playerid,index), wear = Inventory_GetSlotWear(playerid,index), data = Inventory_GetSlotData(playerid,index);
	if (used > 0 && amount <= 1)
	{
		Gui_Notify(playerid,sprintf("You've already started the %s. Finish it before you hand it over.",name));
		return false;
	}

	new bool:isTaken = used > 0 ? Inventory_Take(playerid,kind,param,1,stars) : Inventory_TakeSlot(playerid,index,1);
	if (!isTaken)
	{
		return false;
	}

	if (freshAt <= 0)
	{
		freshAt = ITEM_FRESH_NOW;
	}

	Inventory_Give(targetid,kind,param,1,stars,freshAt,wear,data);
	Gui_Notify(playerid,sprintf("You gave the %s to %s.",name,other));
	Nametag_GetKnownName(targetid,playerid,other);
	Gui_Notify(targetid,sprintf("%s gave you the %s.",other,name));
	return true;
}

forward Drop_LoadOnBoot();

public Drop_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, param, amount, stars, fresh_at, wear, data, x, y, z, world, interior FROM dropped_items ORDER BY id"));

	new rows = cache_num_rows(), placed = 0;
	for (new r = 0; r < rows; r++)
	{
		new row, kind, param, amount, stars, freshAt, wear, data, Float:x, Float:y, Float:z, world, interior;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_int(r,"param",param);
		cache_get_value_name_int(r,"amount",amount);
		cache_get_value_name_int(r,"stars",stars);
		cache_get_value_name_int(r,"fresh_at",freshAt);
		cache_get_value_name_int(r,"wear",wear);
		cache_get_value_name_int(r,"data",data);
		cache_get_value_name_float(r,"x",x);
		cache_get_value_name_float(r,"y",y);
		cache_get_value_name_float(r,"z",z);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);
		if (Drop_Create(E_ITEM_KIND:kind,param,amount,x,y,z,world,stars,row,freshAt,wear,data,interior) != -1)
		{
			placed++;
		}
	}

	Log_Info("inventory","%d dropped item(s) restored",placed);
	Boot_LoaderDone();
}

forward Inventory_OnDropped(playerid,kind,param);

public Inventory_OnDropped(playerid,kind,param)
{
	return 1;
}

forward Inventory_OnPickedUp(playerid,dropid);

public Inventory_OnPickedUp(playerid,dropid)
{
	return 1;
}

forward bool:Drop_KeyContext(playerid);

public bool:Drop_KeyContext(playerid)
{
	return Drop_Nearest(playerid) != -1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0; i < MAX_DROPPED_ITEMS; i++)
	{
		s_Drops[i][E_DROP_USED] = false;
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_WALK) || (oldkeys & KEY_WALK) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid))
	{
		return;
	}

	new dropid = Drop_Nearest(playerid);
	if (dropid != -1)
	{
		Inventory_PickUp(playerid,dropid);
	}
}
