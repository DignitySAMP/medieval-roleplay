#define HOUSE_BED_PED_Z (0.0)
#define HOUSE_SLEEP_LIB "CRACK"
#define HOUSE_SLEEP_ANIM "crckidle2"
#define HOUSE_SEASON_SECONDS ((CALENDAR_DAY_REAL_MS + CALENDAR_NIGHT_REAL_MS) / 1000 * CALENDAR_DAYS_PER_MONTH * 3)
#define HOUSE_PICK_ROOM (100)
#define HOUSE_PICK_TAKE (1)
#define HOUSE_PICK_PAY (2)
#define HOUSE_PICK_LEAVE (3)
#define HOUSE_PICK_SHARE (4)
#define HOUSE_PICK_UNSHARE (5)
#define HOUSE_PICK_FURNISH (6)
#define HOUSE_PICK_UNFURNISH (7)
#define HOUSE_PICK_CHEST (8)
#define HOUSE_PICK_BED (9)

enum E_HOUSE_HOLD
{
	E_HOUSE_HOLD_ROW,
	E_HOUSE_HOLD_HOLDER,
	E_HOUSE_HOLD_CO,
	E_HOUSE_HOLD_PAID_UNTIL,
	E_HOUSE_HOLD_ACTIVE_AT,
	E_HOUSE_HOLD_CHEST,
}

static s_HouseHolds[HOUSE_SEED_ROOMS][E_HOUSE_HOLD];
static bool:s_HouseLying[MAX_PLAYERS];
static Float:s_HouseLyingFrom[MAX_PLAYERS][4];

stock Houses_GetRoomHouse(room)
{
	return room >= 0 && room < HOUSE_SEED_ROOMS ? g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE] : -1;
}

stock Houses_RoomKey(room,dest[],size = sizeof(dest))
{
	format(dest,size,"%s:%s",g_HouseDefs[g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE]][E_HOUSE_DEF_KEY],g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_NAME]);
}

stock Houses_FindRoomByKey(const key[])
{
	for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
	{
		new roomKey[48];
		Houses_RoomKey(room,roomKey);

		if (!strcmp(roomKey,key,true))
		{
			return room;
		}
	}

	return -1;
}

stock Houses_RoomRent(room)
{
	return HOUSE_RENT_BASE + g_HouseDefs[g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE]][E_HOUSE_DEF_WEALTH] * 15;
}

stock Houses_FormatRoomName(room,dest[],size = sizeof(dest))
{
	new name[28], roomName[16];
	Houses_GetName(g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE],name);
	strcopy(roomName,g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_NAME]);

	for (new i = 0;roomName[i] != EOS;i++)
	{
		if (roomName[i] == '_')
		{
			roomName[i] = ' ';
		}
	}

	format(dest,size,strfind(roomName,"room ") == 0 ? ("%s, %s") : ("%s, the %s"),name,roomName);
	dest[0] = toupper(dest[0]);
}

stock Houses_FormatRegisterName(room,dest[],size = sizeof(dest))
{
	new name[64], villageName[28], house = Houses_GetRoomHouse(room);
	Houses_FormatRoomName(room,name);

	if (Realm_GetVillageName(g_HouseDefs[house][E_HOUSE_DEF_VILLAGE],villageName))
	{
		villageName[0] = toupper(villageName[0]);
		name[0] = tolower(name[0]);
		format(dest,size,"%s: %s",villageName,name);
	}
	else
	{
		strcopy(dest,name,size);
	}
}

stock bool:Houses_IsRoomHeld(room)
{
	return room >= 0 && room < HOUSE_SEED_ROOMS && s_HouseHolds[room][E_HOUSE_HOLD_HOLDER] != 0;
}

stock Houses_GetRoomHolder(room)
{
	return Houses_IsRoomHeld(room) ? s_HouseHolds[room][E_HOUSE_HOLD_HOLDER] : 0;
}

stock Houses_GetRoomChest(room)
{
	return Houses_IsRoomHeld(room) ? s_HouseHolds[room][E_HOUSE_HOLD_CHEST] : INVALID_CONTAINER_ID;
}

stock Houses_GetRoomPaidUntil(room)
{
	return Houses_IsRoomHeld(room) ? s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL] : 0;
}

stock bool:Houses_IsRoomOf(room,characterid)
{
	return characterid > 0 && Houses_IsRoomHeld(room) && (s_HouseHolds[room][E_HOUSE_HOLD_HOLDER] == characterid || s_HouseHolds[room][E_HOUSE_HOLD_CO] == characterid);
}

stock Houses_FindRoomOf(characterid)
{
	for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
	{
		if (Houses_IsRoomOf(room,characterid))
		{
			return room;
		}
	}

	return -1;
}

stock bool:Houses_HoldsRoomIn(playerid,house)
{
	new room = Houses_FindRoomOf(Character_GetId(playerid));
	return room != -1 && g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE] == house;
}

stock Houses_CountRentable()
{
	new count = 0;

	for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
	{
		if (g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_RENTABLE])
		{
			count++;
		}
	}

	return count;
}

stock Houses_FindRoomAt(playerid)
{
	new house = Houses_GetInside(playerid), Float:x, Float:y, Float:z, Float:localX, Float:localY, Float:localZ;

	if (house == -1)
	{
		return -1;
	}

	GetPlayerPos(playerid,x,y,z);
	Houses_WorldToLocal(x,y,z - (s_HouseLying[playerid] ? HOUSE_BED_PED_Z : 1.0),localX,localY,localZ);

	for (new room = g_HouseDefs[house][E_HOUSE_DEF_FIRST][0], last = room + g_HouseDefs[house][E_HOUSE_DEF_COUNT][0];room < last;room++)
	{
		if (g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_RENTABLE] && Houses_IsInRoomBox(room,localX,localY,localZ))
		{
			return room;
		}
	}

	return -1;
}

stock bool:Houses_GetRoomChestPos(room,&Float:x,&Float:y,&Float:z)
{
	new house = g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE];

	for (new i = g_HouseDefs[house][E_HOUSE_DEF_FIRST][4], last = i + g_HouseDefs[house][E_HOUSE_DEF_COUNT][4];i < last;i++)
	{
		if (Houses_IsInRoomBox(room,g_HouseChestDefs[i][E_HOUSE_CHEST_DEF_POS][0],g_HouseChestDefs[i][E_HOUSE_CHEST_DEF_POS][1],g_HouseChestDefs[i][E_HOUSE_CHEST_DEF_POS][2]))
		{
			Houses_LocalToWorld(g_HouseChestDefs[i][E_HOUSE_CHEST_DEF_POS][0],g_HouseChestDefs[i][E_HOUSE_CHEST_DEF_POS][1],g_HouseChestDefs[i][E_HOUSE_CHEST_DEF_POS][2],x,y,z);
			return true;
		}
	}

	Houses_LocalToWorld((g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_FREE][0] + g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_FREE][3]) / 2.0,(g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_FREE][1] + g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_FREE][4]) / 2.0,g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_FREE][2],x,y,z);
	return false;
}

stock Houses_FindRoomBed(room)
{
	new house = g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_HOUSE];

	for (new i = g_HouseDefs[house][E_HOUSE_DEF_FIRST][1], last = i + g_HouseDefs[house][E_HOUSE_DEF_COUNT][1];i < last;i++)
	{
		if (Houses_IsInRoomBox(room,g_HouseBedDefs[i][E_HOUSE_POSE_DEF_POS][0],g_HouseBedDefs[i][E_HOUSE_POSE_DEF_POS][1],g_HouseBedDefs[i][E_HOUSE_POSE_DEF_POS][2]))
		{
			return i;
		}
	}

	return Houses_FindRoomLetBed(room);
}

stock bool:Houses_IsLying(playerid)
{
	return Util_IsValidPlayer(playerid) && s_HouseLying[playerid];
}

stock Houses_LieDown(playerid,bed)
{
	new Float:x, Float:y, Float:z, Float:localX, Float:localY, Float:localZ, Float:a, style[12];

	if (!Houses_GetBedPose(bed,localX,localY,localZ,a))
	{
		return;
	}

	GetPlayerPos(playerid,s_HouseLyingFrom[playerid][0],s_HouseLyingFrom[playerid][1],s_HouseLyingFrom[playerid][2]);
	GetPlayerFacingAngle(playerid,s_HouseLyingFrom[playerid][3]);
	Houses_LocalToWorld(localX,localY,localZ + HOUSE_BED_PED_Z,x,y,z);
	Houses_GetBedStyle(bed,style);
	SetPlayerPos(playerid,x,y,z);
	SetPlayerFacingAngle(playerid,a + 180.0);
	ApplyAnimation(playerid,HOUSE_SLEEP_LIB,HOUSE_SLEEP_ANIM,4.1,false,false,false,false,0,SYNC_ALL);
	s_HouseLying[playerid] = true;
	Gui_Notify(playerid,"You lie down. Press ~y~Y~w~ or ~y~N~w~ to get up.");
	pawn_call_public("Houses_OnLieDown","ddd",playerid,bed,_:Houses_IsRoomOf(Houses_FindRoomAt(playerid),Character_GetId(playerid)));
}

stock Houses_GetUp(playerid)
{
	if (!s_HouseLying[playerid])
	{
		return;
	}

	s_HouseLying[playerid] = false;
	ClearAnimations(playerid,SYNC_ALL);
	SetPlayerPos(playerid,s_HouseLyingFrom[playerid][0],s_HouseLyingFrom[playerid][1],s_HouseLyingFrom[playerid][2]);
	SetPlayerFacingAngle(playerid,s_HouseLyingFrom[playerid][3]);
	pawn_call_public("Houses_OnGetUp","d",playerid);
}

static Houses_SaveHold(room)
{
	if (s_HouseHolds[room][E_HOUSE_HOLD_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE home_holds SET co_character_id = %d, paid_until = %d, active_at = %d, chest_id = %d WHERE id = %d",s_HouseHolds[room][E_HOUSE_HOLD_CO],s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL],s_HouseHolds[room][E_HOUSE_HOLD_ACTIVE_AT],s_HouseHolds[room][E_HOUSE_HOLD_CHEST],s_HouseHolds[room][E_HOUSE_HOLD_ROW]));
	}
}

stock Houses_SetHold(room,row,holder,co,paidUntil,activeAt,chest)
{
	s_HouseHolds[room][E_HOUSE_HOLD_ROW] = row;
	s_HouseHolds[room][E_HOUSE_HOLD_HOLDER] = holder;
	s_HouseHolds[room][E_HOUSE_HOLD_CO] = co;
	s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL] = paidUntil;
	s_HouseHolds[room][E_HOUSE_HOLD_ACTIVE_AT] = activeAt;
	s_HouseHolds[room][E_HOUSE_HOLD_CHEST] = chest;
}

stock bool:Houses_PayRent(playerid,room)
{
	new rent = Houses_RoomRent(room), money[24], text[128];
	Economy_Format(rent,money);

	if (Economy_Pay(playerid,rent,INVALID_CONTAINER_ID,"rent") != PAY_OK)
	{
		format(text,sizeof(text),"A season's rent is %s. You don't have it.",money);
		Gui_Notify(playerid,text);
		return false;
	}

	s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL] = max(s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL],gettime()) + HOUSE_SEASON_SECONDS;
	Houses_SaveHold(room);
	format(text,sizeof(text),"You pay %s, a season's rent, to the county.",money);
	Gui_Notify(playerid,text);
	pawn_call_public("Houses_OnRentPaid","ddd",playerid,room,rent);
	return true;
}

stock Houses_TakeRoom(playerid,room)
{
	yield 1;

	new characterid = Character_GetId(playerid), rent = Houses_RoomRent(room), roomKey[48], name[64];

	if (Houses_IsRoomHeld(room) || Houses_FindRoomOf(characterid) != -1)
	{
		Gui_Notify(playerid,"You can only hold one room, and that one is taken.");
		return;
	}

	if (Economy_Pay(playerid,rent,INVALID_CONTAINER_ID,"rent") != PAY_OK)
	{
		new money[24], text[96];
		Economy_Format(rent,money);
		format(text,sizeof(text),"A season's rent is %s. You don't have it.",money);
		Gui_Notify(playerid,text);
		return;
	}

	Houses_RoomKey(room,roomKey);
	Houses_FormatRoomName(room,name);
	new now = gettime();
	Houses_SetHold(room,0,characterid,0,now + HOUSE_SEASON_SECONDS,now,INVALID_CONTAINER_ID);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO home_holds (room_key, character_id, co_character_id, since, paid_until, active_at, chest_id) VALUES ('%e', %d, 0, %d, %d, %d, 0)",roomKey,characterid,now,now + HOUSE_SEASON_SECONDS,now));

	new row = cache_insert_id();

	if (Houses_GetRoomHolder(room) != characterid)
	{
		return;
	}

	s_HouseHolds[room][E_HOUSE_HOLD_ROW] = row;
	new chest = await Container_Create(CONTAINER_OWNER_CHEST,row,0,"Your chest");

	if (Houses_GetRoomHolder(room) == characterid)
	{
		s_HouseHolds[room][E_HOUSE_HOLD_CHEST] = chest;
		Houses_SaveHold(room);
	}

	if (IsPlayerConnected(playerid))
	{
		new text[160];
		name[0] = tolower(name[0]);
		format(text,sizeof(text),"The steward grants you %s for a season. It has a chest and a bed, and the door opens for you at night.",name);
		Gui_Notify(playerid,text);
	}

	pawn_call_public("Houses_OnRented","dd",playerid,room);
}

stock Houses_Vacate(room,const why[])
{
	if (!Houses_IsRoomHeld(room))
	{
		return;
	}

	new holder = s_HouseHolds[room][E_HOUSE_HOLD_HOLDER], chest = s_HouseHolds[room][E_HOUSE_HOLD_CHEST];

	if (chest != INVALID_CONTAINER_ID && Container_IsLoaded(chest))
	{
		for (new slot = 0, slots = Container_GetSlots(chest);slot < slots;slot++)
		{
			new E_ITEM_KIND:kind, param, amount, stars, freshAt, wear;

			if (Container_GetSlot(chest,slot,kind,param,amount,stars) && amount > 0)
			{
				Container_GetSlotState(chest,slot,freshAt,wear);
				Claims_Give(holder,kind,param,amount,stars,"left in your room",freshAt,wear,Container_GetSlotData(chest,slot));
			}
		}

		Container_Delete(chest);
	}

	Houses_ReturnFurniture(room,holder);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM home_holds WHERE id = %d",s_HouseHolds[room][E_HOUSE_HOLD_ROW]));
	Houses_SetHold(room,0,0,0,0,0,INVALID_CONTAINER_ID);
	Log_Info("houses","room %d vacated: %s",room,why);
	pawn_call_public("Houses_OnVacated","ds",room,why);
}

stock Houses_EvictTick()
{
	new now = gettime();

	for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
	{
		if (!Houses_IsRoomHeld(room))
		{
			continue;
		}

		if (s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL] < now)
		{
			Houses_Vacate(room,"rent unpaid");
		}
		else if (now - s_HouseHolds[room][E_HOUSE_HOLD_ACTIVE_AT] > HOUSE_INACTIVE_DAYS * 86400)
		{
			Houses_Vacate(room,"inactive");
		}
	}
}

stock Houses_OpenRegister(playerid)
{
	new epoch = Gui_BeginFlow(playerid), characterid = Character_GetId(playerid);

	for (;;)
	{
		new rows = 0, Float:x, Float:y, Float:width, title[] = "County register";
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HOUSE_PANEL_WIDTH + 60.0,float(Houses_CountRentable()) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

		for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
		{
			if (!g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_RENTABLE])
			{
				continue;
			}

			new name[64], label[96], money[24], colour = KIT_COLOUR_TEXT;
			Houses_FormatRegisterName(room,name);
			Economy_Format(Houses_RoomRent(room),money);

			if (Houses_IsRoomOf(room,characterid))
			{
				format(label,sizeof(label),"%s: yours, %d days paid",name,max(Houses_GetRoomPaidUntil(room) - gettime(),0) / 86400);
				colour = KIT_COLOUR_GOOD;
			}
			else if (Houses_IsRoomHeld(room))
			{
				format(label,sizeof(label),"%s: let",name);
				colour = KIT_COLOUR_MUTED;
			}
			else
			{
				format(label,sizeof(label),"%s: %s a season",name,money);
			}

			Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,label,HOUSE_PICK_ROOM + room,colour);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		new room = pick - HOUSE_PICK_ROOM;

		if (room < 0 || room >= HOUSE_SEED_ROOMS)
		{
			continue;
		}

		if (Houses_IsRoomOf(room,characterid))
		{
			Houses_PayRent(playerid,room);
			continue;
		}

		if (Houses_IsRoomHeld(room))
		{
			Gui_Notify(playerid,"That room is let to someone else.");
			continue;
		}

		Kit_Close(playerid);
		Houses_TakeRoom(playerid,room);
		return;
	}
}

stock Houses_OpenRoom(playerid,room)
{
	new epoch = Gui_BeginFlow(playerid), characterid = Character_GetId(playerid);

	for (;;)
	{
		if (!Houses_IsRoomOf(room,characterid))
		{
			Kit_Close(playerid);
			return;
		}

		new picks[8], labels[8][64], count = 0, money[24], name[64];
		Economy_Format(Houses_RoomRent(room),money);
		Houses_FormatRoomName(room,name);
		strcopy(labels[count],"Open your chest",64);
		picks[count++] = HOUSE_PICK_CHEST;

		if (Houses_FindRoomBed(room) != -1)
		{
			strcopy(labels[count],"Lie down on the bed",64);
			picks[count++] = HOUSE_PICK_BED;
		}

		strcopy(labels[count],"Furnish the room",64);
		picks[count++] = HOUSE_PICK_FURNISH;
		strcopy(labels[count],"Take up a piece of furniture",64);
		picks[count++] = HOUSE_PICK_UNFURNISH;

		if (s_HouseHolds[room][E_HOUSE_HOLD_HOLDER] == characterid)
		{
			if (s_HouseHolds[room][E_HOUSE_HOLD_CO] == 0)
			{
				strcopy(labels[count],"Share the room with someone here",64);
				picks[count++] = HOUSE_PICK_SHARE;
			}
			else
			{
				strcopy(labels[count],"Stop sharing the room",64);
				picks[count++] = HOUSE_PICK_UNSHARE;
			}
		}

		format(labels[count],64,"Pay another season (%s)",money);
		picks[count++] = HOUSE_PICK_PAY;
		strcopy(labels[count],"Give up the room",64);
		picks[count++] = HOUSE_PICK_LEAVE;

		new Float:x, Float:y, Float:width;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HOUSE_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);

		for (new i = 0;i < count;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i],picks[i] == HOUSE_PICK_LEAVE ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case HOUSE_PICK_CHEST:
			{
				Kit_Close(playerid);

				if (Houses_GetRoomChest(room) == INVALID_CONTAINER_ID)
				{
					Gui_Notify(playerid,"The chest isn't ready yet. Try again in a moment.");
					return;
				}

				ContainerGui_Show(playerid,Houses_GetRoomChest(room));
				return;
			}
			case HOUSE_PICK_BED:
			{
				Kit_Close(playerid);
				Houses_LieDown(playerid,Houses_FindRoomBed(room));
				return;
			}
			case HOUSE_PICK_FURNISH:
			{
				Kit_Close(playerid);
				Houses_FurnishFlow(playerid,room);
				return;
			}
			case HOUSE_PICK_UNFURNISH:
			{
				Houses_TakeUpNearest(playerid,room);
			}
			case HOUSE_PICK_SHARE:
			{
				new other = Util_GetClosestPlayer(playerid,3.0);

				if (other == INVALID_PLAYER_ID || Houses_GetInside(other) != Houses_GetInside(playerid) || !Houses_ShareRoom(room,Character_GetId(other)))
				{
					Gui_Notify(playerid,"Stand next to the person you want to share with. They can't hold another room.");
					continue;
				}

				Gui_Notify(playerid,"You share the room. They can use the chest and come and go at night.");
				Gui_Notify(other,"You're given a share of the room: its chest and the door at night.");
			}
			case HOUSE_PICK_UNSHARE:
			{
				Houses_UnshareRoom(room);
				Gui_Notify(playerid,"The room is yours alone again.");
			}
			case HOUSE_PICK_PAY:
			{
				Houses_PayRent(playerid,room);
			}
			case HOUSE_PICK_LEAVE:
			{
				if (s_HouseHolds[room][E_HOUSE_HOLD_HOLDER] != characterid)
				{
					s_HouseHolds[room][E_HOUSE_HOLD_CO] = 0;
					Houses_SaveHold(room);
					Kit_Close(playerid);
					Gui_Notify(playerid,"You give up your share of the room.");
					return;
				}

				Kit_Close(playerid);
				Houses_Vacate(room,"given up");
				Gui_Notify(playerid,"You give up the room. Anything you left in it waits for you under Claims in your bag.");
				return;
			}
		}
	}
}

stock Houses_SetRoomTimes(room,paidUntil,activeAt)
{
	if (!Houses_IsRoomHeld(room))
	{
		return;
	}

	s_HouseHolds[room][E_HOUSE_HOLD_PAID_UNTIL] = paidUntil;
	s_HouseHolds[room][E_HOUSE_HOLD_ACTIVE_AT] = activeAt;
	Houses_SaveHold(room);
}

stock bool:Houses_ShareRoom(room,characterid)
{
	if (!Houses_IsRoomHeld(room) || s_HouseHolds[room][E_HOUSE_HOLD_CO] != 0 || characterid <= 0 || Houses_FindRoomOf(characterid) != -1)
	{
		return false;
	}

	s_HouseHolds[room][E_HOUSE_HOLD_CO] = characterid;
	Houses_SaveHold(room);
	return true;
}

stock Houses_UnshareRoom(room)
{
	if (Houses_IsRoomHeld(room))
	{
		s_HouseHolds[room][E_HOUSE_HOLD_CO] = 0;
		Houses_SaveHold(room);
	}
}

stock Houses_TouchHold(playerid)
{
	new room = Houses_FindRoomOf(Character_GetId(playerid));

	if (room != -1)
	{
		s_HouseHolds[room][E_HOUSE_HOLD_ACTIVE_AT] = gettime();
		Houses_SaveHold(room);
	}
}

forward Houses_OnRentPaid(playerid,room,rent);

public Houses_OnRentPaid(playerid,room,rent)
{
	return 1;
}

forward Houses_OnLieDown(playerid,bed,ownBed);

public Houses_OnLieDown(playerid,bed,ownBed)
{
	return 1;
}

forward Houses_OnGetUp(playerid);

public Houses_OnGetUp(playerid)
{
	return 1;
}

forward Houses_OnRented(playerid,room);

public Houses_OnRented(playerid,room)
{
	return 1;
}

forward Houses_OnVacated(room,const why[]);

public Houses_OnVacated(room,const why[])
{
	return 1;
}

forward Houses_LoadOnBoot();

public Houses_LoadOnBoot()
{
	yield 1;

	Houses_Build();
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, room_key, character_id, co_character_id, paid_until, active_at, chest_id FROM home_holds ORDER BY id"));

	new held = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, key[48], holder, co, paidUntil, activeAt, chest;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"room_key",key);
		cache_get_value_name_int(r,"character_id",holder);
		cache_get_value_name_int(r,"co_character_id",co);
		cache_get_value_name_int(r,"paid_until",paidUntil);
		cache_get_value_name_int(r,"active_at",activeAt);
		cache_get_value_name_int(r,"chest_id",chest);

		new room = Houses_FindRoomByKey(key);

		if (room != -1)
		{
			Houses_SetHold(room,row,holder,co,paidUntil,activeAt,chest);
			held++;
		}
	}

	for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
	{
		if (Houses_IsRoomHeld(room) && s_HouseHolds[room][E_HOUSE_HOLD_CHEST] != INVALID_CONTAINER_ID)
		{
			await Container_Load(s_HouseHolds[room][E_HOUSE_HOLD_CHEST]);
		}
	}

	await Houses_LoadFurniture();
	Log_Info("houses","%d houses built, %d of %d rooms to let are held",HOUSE_SEED_COUNT,held,Houses_CountRentable());
	Boot_LoaderDone();
}

Timer_Declare(Houses_Tick)
{
	Houses_EvictTick();
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_HouseLying[playerid] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (s_HouseLying[playerid] && (((newkeys & KEY_YES) && !(oldkeys & KEY_YES)) || ((newkeys & KEY_NO) && !(oldkeys & KEY_NO))))
	{
		Houses_GetUp(playerid);
	}
}
