#define HOUSE_PICK_PIECE (200)

enum E_HOUSE_PIECE
{
	bool:E_HOUSE_PIECE_USED,
	E_HOUSE_PIECE_ROW,
	E_HOUSE_PIECE_ROOM,
	E_HOUSE_PIECE_ITEM,
	STREAMER_TAG_OBJECT:E_HOUSE_PIECE_OBJECT,
}

static s_HouseFurniture[HOUSE_FURNITURE_MAX][E_HOUSE_PIECE];

new const g_HouseFurnitureItems[] = {
	ITEM_CHAIR,
	ITEM_TABLE,
	ITEM_BED,
	ITEM_CHEST,
	ITEM_BARREL,
	ITEM_TUB,
	ITEM_STORAGE_JAR
};

stock Houses_CountPieces(room)
{
	new count = 0;

	for (new i = 0;i < HOUSE_FURNITURE_MAX;i++)
	{
		if (s_HouseFurniture[i][E_HOUSE_PIECE_USED] && s_HouseFurniture[i][E_HOUSE_PIECE_ROOM] == room)
		{
			count++;
		}
	}

	return count;
}

static Houses_AddPiece(row,room,item,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz)
{
	for (new i = 0;i < HOUSE_FURNITURE_MAX;i++)
	{
		if (s_HouseFurniture[i][E_HOUSE_PIECE_USED])
		{
			continue;
		}

		new house = g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE];
		s_HouseFurniture[i][E_HOUSE_PIECE_USED] = true;
		s_HouseFurniture[i][E_HOUSE_PIECE_ROW] = row;
		s_HouseFurniture[i][E_HOUSE_PIECE_ROOM] = room;
		s_HouseFurniture[i][E_HOUSE_PIECE_ITEM] = item;
		s_HouseFurniture[i][E_HOUSE_PIECE_OBJECT] = CreateDynamicObject(Item_GetModel(Item_GetDefKind(item),item),x,y,z,rx,ry,rz,Houses_GetWorld(house),HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE,HOUSE_STREAM_RANGE);
		return i;
	}

	return -1;
}

static Houses_RemovePiece(piece)
{
	if (IsValidDynamicObject(s_HouseFurniture[piece][E_HOUSE_PIECE_OBJECT]))
	{
		DestroyDynamicObject(s_HouseFurniture[piece][E_HOUSE_PIECE_OBJECT]);
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM home_furniture WHERE id = %d",s_HouseFurniture[piece][E_HOUSE_PIECE_ROW]));
	s_HouseFurniture[piece][E_HOUSE_PIECE_USED] = false;
}

stock Houses_ReturnFurniture(room,holder)
{
	for (new i = 0;i < HOUSE_FURNITURE_MAX;i++)
	{
		if (s_HouseFurniture[i][E_HOUSE_PIECE_USED] && s_HouseFurniture[i][E_HOUSE_PIECE_ROOM] == room)
		{
			new item = s_HouseFurniture[i][E_HOUSE_PIECE_ITEM];
			Claims_Give(holder,Item_GetDefKind(item),item,1,ITEM_STARS_MIN,"furniture from your room");
			Houses_RemovePiece(i);
		}
	}
}

stock Houses_TakeUpNearest(playerid,room)
{
	new best = -1, Float:bestDistance = 2.5;

	for (new i = 0;i < HOUSE_FURNITURE_MAX;i++)
	{
		if (!s_HouseFurniture[i][E_HOUSE_PIECE_USED] || s_HouseFurniture[i][E_HOUSE_PIECE_ROOM] != room)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetDynamicObjectPos(s_HouseFurniture[i][E_HOUSE_PIECE_OBJECT],x,y,z);
		new Float:distance = GetPlayerDistanceFromPoint(playerid,x,y,z);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	if (best == -1)
	{
		Gui_Notify(playerid,"Stand next to the piece you want to take up.");
		return;
	}

	new item = s_HouseFurniture[best][E_HOUSE_PIECE_ITEM];

	if (!Inventory_Give(playerid,Item_GetDefKind(item),item))
	{
		Gui_Notify(playerid,"There's no room in your bag for it.");
		return;
	}

	Houses_RemovePiece(best);
	Gui_Notify(playerid,"You take it up and put it in your bag.");
}

static Houses_PickFurniture(playerid,epoch)
{
	new Float:x, Float:y, Float:width, count = 0, items[sizeof(g_HouseFurnitureItems)];

	for (new i = 0;i < sizeof(g_HouseFurnitureItems);i++)
	{
		if (Inventory_Count(playerid,Item_GetDefKind(g_HouseFurnitureItems[i]),g_HouseFurnitureItems[i]) > 0)
		{
			items[count++] = g_HouseFurnitureItems[i];
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"You carry no furniture: a chair, table, bed, chest, barrel, tub or storage jar.");
		return -1;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Furnish the room");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HOUSE_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Furnish the room",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[ITEM_NAME_LEN];
		Item_GetName(Item_GetDefKind(items[i]),items[i],name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,HOUSE_PICK_PIECE + items[i]);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return -1;
	}

	return pick - HOUSE_PICK_PIECE;
}

stock Houses_FurnishFlow(playerid,room)
{
	new epoch = Gui_BeginFlow(playerid);

	if (Houses_CountPieces(room) >= HOUSE_FURNITURE_PER_ROOM)
	{
		Gui_Notify(playerid,"The room can't hold any more furniture.");
		return;
	}

	new item = Houses_PickFurniture(playerid,epoch);

	if (item == -1)
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a, house = g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE];
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x -= 1.2 * floatsin(a,degrees);
	y += 1.2 * floatcos(a,degrees);
	z -= 1.0;

	new STREAMER_TAG_OBJECT:ghost = CreateDynamicObject(Item_GetModel(Item_GetDefKind(item),item),x,y,z,0.0,0.0,a,Houses_GetWorld(house),HOUSE_INTERIOR,playerid);
	Gui_Notify(playerid,"Drag the arrows to move it, then click the save icon. Press ESC to cancel.");

	for (;;)
	{
		new bool:isSaved = bool:await Placement_Edit(playerid,ghost);

		if (!Gui_IsFlowCurrent(playerid,epoch) || !isSaved || !Houses_IsRoomOf(room,Character_GetId(playerid)))
		{
			DestroyDynamicObject(ghost);
			return;
		}

		new Float:rx, Float:ry, Float:rz, Float:localX, Float:localY, Float:localZ;
		Placement_GetPose(playerid,x,y,z,rx,ry,rz);
		Houses_WorldToLocal(x,y,z,localX,localY,localZ);

		if (!Houses_IsInRoomBox(room,localX,localY,localZ,true))
		{
			Gui_Notify(playerid,"It has to stand in the free part of your room.");
			continue;
		}

		DestroyDynamicObject(ghost);

		if (!Inventory_Take(playerid,Item_GetDefKind(item),item,1))
		{
			Gui_Notify(playerid,"It isn't in your bag any more.");
			return;
		}

		if ((await Houses_PlaceFurniture(room,item,x,y,z,rx,ry,rz)) == -1)
		{
			Inventory_Give(playerid,Item_GetDefKind(item),item);
			Gui_Notify(playerid,"It can't go there.");
			return;
		}

		Gui_Notify(playerid,"You set it in place.");
		return;
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Houses_PlaceFurniture(room,item,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz)
{
	new Float:localX, Float:localY, Float:localZ, roomKey[48];
	Houses_WorldToLocal(x,y,z,localX,localY,localZ);

	if (room < 0 || room >= HOUSE_SEED_ROOMS || !Houses_IsInRoomBox(room,localX,localY,localZ,true) || Houses_CountPieces(room) >= HOUSE_FURNITURE_PER_ROOM)
	{
		wait_ticks(1);
		return async -1;
	}

	Houses_RoomKey(room,roomKey);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO home_furniture (room_key, item, x, y, z, rx, ry, rz) VALUES ('%e', %d, %f, %f, %f, %f, %f, %f)",roomKey,item,x,y,z,rx,ry,rz));
	return async Houses_AddPiece(cache_insert_id(),room,item,x,y,z,rx,ry,rz);
}

async Task:Houses_LoadFurniture()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, room_key, item, x, y, z, rx, ry, rz FROM home_furniture ORDER BY id"));

	new placed = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, key[48], item, Float:pos[6];
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"room_key",key);
		cache_get_value_name_int(r,"item",item);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"rx",pos[3]);
		cache_get_value_name_float(r,"ry",pos[4]);
		cache_get_value_name_float(r,"rz",pos[5]);

		new room = Houses_FindRoomByKey(key);

		if (room != -1 && Houses_AddPiece(row,room,item,pos[0],pos[1],pos[2],pos[3],pos[4],pos[5]) != -1)
		{
			placed++;
		}
	}

	return async placed;
}
#pragma warning pop
