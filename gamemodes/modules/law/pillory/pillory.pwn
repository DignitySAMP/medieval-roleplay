#define PILLORY_MAX (8)
#define PILLORY_REACH (2.6)
#define PILLORY_STREAM_RANGE (80.0)
#define PILLORY_THROW_SPEED (11.0)
#define PILLORY_THROW_RANGE (12.0)
#define PILLORY_SPLAT_DAMAGE (1.0)
#define PILLORY_SPLAT_FLOOR (20.0)
#define PILLORY_WATER_SIP (13)
#define PILLORY_PICK_THROW (1)
#define PILLORY_PICK_JEER (2)
#define PILLORY_PICK_WATER (3)
#define PILLORY_PICK_FREE (4)
#define PILLORY_THROWS_MAX (16)

enum E_PILLORY
{
	bool:E_PILLORY_USED,
	E_PILLORY_ROW,
	E_PILLORY_KIND,
	Float:E_PILLORY_POS[4],
	E_PILLORY_WORLD,
	E_PILLORY_INTERIOR,
	E_PILLORY_PRISONER,
	STREAMER_TAG_OBJECT:E_PILLORY_OBJECT,
}

static s_Pillories[PILLORY_MAX][E_PILLORY];
static s_PilloryOf[MAX_PLAYERS] = {-1, ...};
static s_PilloryPrompt[MAX_PLAYERS] = {-1, ...};
static s_PilloryPromptInfobox[MAX_PLAYERS];

enum E_PILLORY_THROW
{
	bool:E_PILLORY_THROW_USED,
	E_PILLORY_THROW_FROM,
	E_PILLORY_THROW_TO,
	STREAMER_TAG_OBJECT:E_PILLORY_THROW_OBJECT,
}

static s_PilloryThrows[PILLORY_THROWS_MAX][E_PILLORY_THROW];

stock bool:Pillory_IsValid(device)
{
	return device >= 0 && device < PILLORY_MAX && s_Pillories[device][E_PILLORY_USED];
}

stock bool:Pillory_IsLocked(playerid)
{
	return Util_IsValidPlayer(playerid) && s_PilloryOf[playerid] != -1;
}

stock Pillory_GetDevice(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_PilloryOf[playerid] : -1;
}

stock Pillory_CountDevices()
{
	new count = 0;

	for (new i = 0;i < PILLORY_MAX;i++)
	{
		if (s_Pillories[i][E_PILLORY_USED])
		{
			count++;
		}
	}

	return count;
}

stock Pillory_FindFree(bool:isStocks)
{
	for (new i = 0;i < PILLORY_MAX;i++)
	{
		if (s_Pillories[i][E_PILLORY_USED] && s_Pillories[i][E_PILLORY_KIND] == (isStocks ? LAW_DEVICE_STOCKS : LAW_DEVICE_PILLORY) && s_Pillories[i][E_PILLORY_PRISONER] == INVALID_PLAYER_ID)
		{
			return i;
		}
	}

	return -1;
}

stock Pillory_FindNear(Float:x,Float:y,Float:z,world,Float:range)
{
	new best = -1, Float:bestDistance = range;

	for (new i = 0;i < PILLORY_MAX;i++)
	{
		if (!s_Pillories[i][E_PILLORY_USED] || s_Pillories[i][E_PILLORY_WORLD] != world)
		{
			continue;
		}

		new Float:distance = Util_GetDistance3D(x,y,z,s_Pillories[i][E_PILLORY_POS][0],s_Pillories[i][E_PILLORY_POS][1],s_Pillories[i][E_PILLORY_POS][2]);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Pillory_Add(row,kind,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	for (new i = 0;i < PILLORY_MAX;i++)
	{
		if (s_Pillories[i][E_PILLORY_USED])
		{
			continue;
		}

		s_Pillories[i][E_PILLORY_USED] = true;
		s_Pillories[i][E_PILLORY_ROW] = row;
		s_Pillories[i][E_PILLORY_KIND] = kind;
		s_Pillories[i][E_PILLORY_POS][0] = x;
		s_Pillories[i][E_PILLORY_POS][1] = y;
		s_Pillories[i][E_PILLORY_POS][2] = z;
		s_Pillories[i][E_PILLORY_POS][3] = a;
		s_Pillories[i][E_PILLORY_WORLD] = world;
		s_Pillories[i][E_PILLORY_INTERIOR] = interior;
		s_Pillories[i][E_PILLORY_PRISONER] = INVALID_PLAYER_ID;
		s_Pillories[i][E_PILLORY_OBJECT] = CreateDynamicObject(kind == LAW_DEVICE_STOCKS ? MODEL_VILLAGE_STOCKS : MODEL_VILLAGE_PILLORY,x,y,z,0.0,0.0,a,world,interior,-1,PILLORY_STREAM_RANGE,PILLORY_STREAM_RANGE);
		return i;
	}

	return -1;
}

stock Pillory_Remove(device)
{
	if (!Pillory_IsValid(device))
	{
		return;
	}

	if (s_Pillories[device][E_PILLORY_PRISONER] != INVALID_PLAYER_ID)
	{
		Law_Release(s_Pillories[device][E_PILLORY_PRISONER],"device removed");
	}

	if (IsValidDynamicObject(s_Pillories[device][E_PILLORY_OBJECT]))
	{
		DestroyDynamicObject(s_Pillories[device][E_PILLORY_OBJECT]);
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM law_devices WHERE id = %d",s_Pillories[device][E_PILLORY_ROW]));
	s_Pillories[device][E_PILLORY_USED] = false;
}

stock Pillory_GetPrisonerPose(device,&Float:x,&Float:y,&Float:z,&Float:a)
{
	new Float:rz = s_Pillories[device][E_PILLORY_POS][3], Float:localY = s_Pillories[device][E_PILLORY_KIND] == LAW_DEVICE_STOCKS ? 0.19 : 0.25;
	new Float:localZ = s_Pillories[device][E_PILLORY_KIND] == LAW_DEVICE_STOCKS ? 0.46 : 0.14;
	x = s_Pillories[device][E_PILLORY_POS][0] - localY * floatsin(rz,degrees);
	y = s_Pillories[device][E_PILLORY_POS][1] + localY * floatcos(rz,degrees);
	z = s_Pillories[device][E_PILLORY_POS][2] + localZ + 1.0;
	a = Util_NormalizeAngle(rz + 180.0);
}

static Pillory_ApplyPose(playerid,device)
{
	if (s_Pillories[device][E_PILLORY_KIND] == LAW_DEVICE_STOCKS)
	{
		ApplyAnimation(playerid,"PED","SEAT_idle",4.1,true,false,false,true,0,SYNC_ALL);
	}
	else
	{
		ApplyAnimation(playerid,"PED","IDLE_tired",4.1,true,false,false,true,0,SYNC_ALL);
	}
}

stock bool:Pillory_Lock(playerid,device,bool:isStocks)
{
	if (!Pillory_IsValid(device) || s_Pillories[device][E_PILLORY_PRISONER] != INVALID_PLAYER_ID || (s_Pillories[device][E_PILLORY_KIND] == LAW_DEVICE_STOCKS) != isStocks)
	{
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Pillory_GetPrisonerPose(device,x,y,z,a);
	s_Pillories[device][E_PILLORY_PRISONER] = playerid;
	s_PilloryOf[playerid] = device;
	Util_SafeTeleport(playerid,x,y,z,a,s_Pillories[device][E_PILLORY_WORLD],s_Pillories[device][E_PILLORY_INTERIOR]);
	TogglePlayerControllable(playerid,false);
	Pillory_ApplyPose(playerid,device);
	return true;
}

stock Pillory_Unlock(playerid)
{
	new device = Pillory_GetDevice(playerid);

	if (device == -1)
	{
		return;
	}

	s_Pillories[device][E_PILLORY_PRISONER] = INVALID_PLAYER_ID;
	s_PilloryOf[playerid] = -1;

	if (IsPlayerConnected(playerid))
	{
		TogglePlayerControllable(playerid,true);
		ClearAnimations(playerid,SYNC_ALL);
	}
}

stock Pillory_HoldTick()
{
	for (new i = 0;i < PILLORY_MAX;i++)
	{
		new prisoner = s_Pillories[i][E_PILLORY_PRISONER];

		if (!s_Pillories[i][E_PILLORY_USED] || prisoner == INVALID_PLAYER_ID || !IsPlayerConnected(prisoner))
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:a;
		Pillory_GetPrisonerPose(i,x,y,z,a);

		if (!IsPlayerInRangeOfPoint(prisoner,1.2,x,y,z))
		{
			SetPlayerPos(prisoner,x,y,z);
			SetPlayerFacingAngle(prisoner,a);
			TogglePlayerControllable(prisoner,false);
		}

		Pillory_ApplyPose(prisoner,i);
	}
}

static Pillory_ClearPrompt(playerid)
{
	if (s_PilloryPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_PilloryPromptInfobox[playerid]);
	}

	s_PilloryPrompt[playerid] = -1;
	s_PilloryPromptInfobox[playerid] = 0;
}

stock Pillory_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Law_IsServing(playerid) || Law_IsBound(playerid) || Combat_IsInMode(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Pillory_ClearPrompt(playerid);
		return;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	new device = Pillory_FindNear(x,y,z - 0.9,GetPlayerVirtualWorld(playerid),PILLORY_REACH + 1.5);

	if (device == -1 || s_Pillories[device][E_PILLORY_PRISONER] == INVALID_PLAYER_ID)
	{
		Pillory_ClearPrompt(playerid);
		return;
	}

	if (device == s_PilloryPrompt[playerid] && Infobox_IsShown(playerid,s_PilloryPromptInfobox[playerid]))
	{
		return;
	}

	new known[LAW_DESCRIPTION_LEN + 8], text[200];
	Law_GetKnownOrLook(playerid,s_Pillories[device][E_PILLORY_PRISONER],known,sizeof(known),true);
	format(text,sizeof(text),"%s is locked in the %s.~n~Press ~y~Y~w~ to throw, jeer, give water or set them free.",known,s_Pillories[device][E_PILLORY_KIND] == LAW_DEVICE_STOCKS ? ("stocks") : ("pillory"));
	s_PilloryPrompt[playerid] = device;
	s_PilloryPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_PilloryPromptInfobox[playerid],s_Pillories[device][E_PILLORY_KIND] == LAW_DEVICE_STOCKS ? ("The stocks") : ("The pillory"),text,3);
}

stock bool:Pillory_Throw(playerid,targetid)
{
	if (!Inventory_Take(playerid,ITEM_KIND_MISC,ITEM_ROTTEN_CABBAGE,1))
	{
		Gui_Notify(playerid,"You have nothing rotten to throw. Traders at the market sell spoiled cabbages for a pfennig.");
		return false;
	}

	new slot = -1;

	for (new i = 0;i < PILLORY_THROWS_MAX;i++)
	{
		if (!s_PilloryThrows[i][E_PILLORY_THROW_USED])
		{
			slot = i;
			break;
		}
	}

	if (slot == -1)
	{
		Inventory_Give(playerid,ITEM_KIND_MISC,ITEM_ROTTEN_CABBAGE,1);
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a, Float:tx, Float:ty, Float:tz;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	GetPlayerPos(targetid,tx,ty,tz);
	Util_FacePoint(playerid,tx,ty);
	ApplyAnimation(playerid,"GRENADE","WEAPON_throwu",4.1,false,false,false,false,0,SYNC_ALL);
	s_PilloryThrows[slot][E_PILLORY_THROW_USED] = true;
	s_PilloryThrows[slot][E_PILLORY_THROW_FROM] = playerid;
	s_PilloryThrows[slot][E_PILLORY_THROW_TO] = targetid;
	s_PilloryThrows[slot][E_PILLORY_THROW_OBJECT] = CreateDynamicObject(MODEL_VILLAGE_ROTTEN_FOOD,x,y,z + 0.6,0.0,0.0,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid),-1,60.0,60.0);
	Nearby_StreamObjectsAt(x,y,z,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid),60.0);
	MoveDynamicObject(s_PilloryThrows[slot][E_PILLORY_THROW_OBJECT],tx,ty,tz + 0.7,PILLORY_THROW_SPEED,float(random(360)),float(random(360)),float(random(360)));

	new thrower[24], target[24], line[128];
	Nametag_Token(playerid,thrower);
	Nametag_Token(targetid,target);
	format(line,sizeof(line),"* %s throws a rotten cabbage at %s.",thrower,target);
	Chat_FromPoint(x,y,z,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid),20.0,CHAT_COLOUR_ACTION,line);
	return true;
}

static Pillory_Splat(slot)
{
	new targetid = s_PilloryThrows[slot][E_PILLORY_THROW_TO];

	if (IsValidDynamicObject(s_PilloryThrows[slot][E_PILLORY_THROW_OBJECT]))
	{
		DestroyDynamicObject(s_PilloryThrows[slot][E_PILLORY_THROW_OBJECT]);
	}

	s_PilloryThrows[slot][E_PILLORY_THROW_USED] = false;

	if (!IsPlayerConnected(targetid) || !Pillory_IsLocked(targetid))
	{
		return;
	}

	if (Vitals_GetHealth(targetid) > PILLORY_SPLAT_FLOOR)
	{
		Vitals_Damage(targetid,PILLORY_SPLAT_DAMAGE,"rotten food");
	}

	Hygiene_AddDirt(targetid,HYGIENE_PELTED);
	GameTextForPlayer(targetid,"~y~splat",800,4);
}

stock Pillory_OpenCrowd(playerid,device)
{
	new epoch = Gui_BeginFlow(playerid);

	for (;;)
	{
		if (!Pillory_IsValid(device) || s_Pillories[device][E_PILLORY_PRISONER] == INVALID_PLAYER_ID)
		{
			Kit_Close(playerid);
			return;
		}

		new prisoner = s_Pillories[device][E_PILLORY_PRISONER], known[MAX_PLAYER_NAME + 8], title[MAX_PLAYER_NAME + 16], rotten = Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_ROTTEN_CABBAGE), throwLabel[48];
		Nametag_GetKnownName(playerid,prisoner,known);
		format(title,sizeof(title),"%s",known);
		format(throwLabel,sizeof(throwLabel),"Throw a rotten cabbage (%d)",rotten);

		new Float:x, Float:y, Float:width;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LAW_PANEL_WIDTH,4.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddChoice(playerid,x,y,width,throwLabel,PILLORY_PICK_THROW,rotten > 0 ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED);
		Kit_AddChoice(playerid,x,y + KIT_ROW,width,"Jeer at them",PILLORY_PICK_JEER);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width,"Give them a drink of water",PILLORY_PICK_WATER,Inventory_Find(playerid,ITEM_KIND_DRINK,ITEM_WATER_SKIN) != -1 ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,Law_IsGuard(playerid) ? ("Release them early") : ("Set them free (a crime)"),PILLORY_PICK_FREE,Law_IsGuard(playerid) ? KIT_COLOUR_TEXT : KIT_COLOUR_BAD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 4.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Pillory_IsValid(device) || s_Pillories[device][E_PILLORY_PRISONER] != prisoner)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case PILLORY_PICK_THROW:
			{
				new Float:px, Float:py, Float:pz;
				GetPlayerPos(prisoner,px,py,pz);

				if (!IsPlayerInRangeOfPoint(playerid,PILLORY_THROW_RANGE,px,py,pz))
				{
					Gui_Notify(playerid,"You're too far away to throw.");
					continue;
				}

				Kit_Close(playerid);
				Pillory_Throw(playerid,prisoner);
				return;
			}
			case PILLORY_PICK_JEER:
			{
				Kit_Close(playerid);
				Chat_Speak(playerid,CHAT_ME,"jeers at the one in the pillory.");
				return;
			}
			case PILLORY_PICK_WATER:
			{
				new index = Inventory_Find(playerid,ITEM_KIND_DRINK,ITEM_WATER_SKIN);

				if (index == -1)
				{
					Gui_Notify(playerid,"You have no water skin.");
					continue;
				}

				Inventory_UsePortion(playerid,index,Item_GetPortions(ITEM_KIND_DRINK,ITEM_WATER_SKIN));
				Needs_Feed(prisoner,NEED_THIRST,PILLORY_WATER_SIP);
				Kit_Close(playerid);
				Chat_Speak(playerid,CHAT_ME,"holds a water skin to the prisoner's lips.");
				Gui_Notify(prisoner,"Someone gives you a drink of water.");
				return;
			}
			case PILLORY_PICK_FREE:
			{
				Kit_Close(playerid);

				if (!Law_IsGuard(playerid))
				{
					Law_Commit(playerid,LAW_CRIME_FREEING,prisoner);
				}

				Law_Release(prisoner,Law_IsGuard(playerid) ? ("released") : ("freed"));
				Gui_Notify(prisoner,"You're let out.");
				return;
			}
		}
	}
}

Timer_Declare(Pillory_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Pillory_UpdatePrompt(playerid);
		}
	}

	return 1;
}

Timer_Declare(Pillory_Tick)
{
	Pillory_HoldTick();
	return 1;
}

forward Pillory_CrowdDeferred(playerid,device);

public Pillory_CrowdDeferred(playerid,device)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Pillory_OpenCrowd(playerid,device);
	}

	return 1;
}

forward bool:Pillory_PromptContext(playerid);

public bool:Pillory_PromptContext(playerid)
{
	return s_PilloryPrompt[playerid] != -1;
}

forward Pillory_LoadOnBoot();

public Pillory_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT 1 FROM seeders WHERE seeder_key = 'law-map-1'"));

	if (!cache_num_rows())
	{
		new String:devices = str_new("INSERT INTO law_devices (kind, x, y, z, a) VALUES ");

		for (new i = 0;i < LAW_SEED_DEVICES;i++)
		{
			str_append_format(devices,"%s(%d, %f, %f, %f, %f)",i == 0 ? ("") : (", "),g_LawSeedDevices[i][E_LAW_SEED_DEVICE_KIND],g_LawSeedDevices[i][E_LAW_SEED_DEVICE_POS][0],g_LawSeedDevices[i][E_LAW_SEED_DEVICE_POS][1],g_LawSeedDevices[i][E_LAW_SEED_DEVICE_POS][2],g_LawSeedDevices[i][E_LAW_SEED_DEVICE_POS][3]);
		}

		await mysql_aquery_s(g_Mysql,devices);
		await mysql_aquery_s(g_Mysql,str_new("INSERT IGNORE INTO seeders (seeder_key) VALUES ('law-map-1')"));
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, x, y, z, a, world, interior FROM law_devices ORDER BY id"));

	new placed = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, kind, Float:pos[4], world, interior;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);

		if (Pillory_Add(row,kind,pos[0],pos[1],pos[2],pos[3],world,interior) != -1)
		{
			placed++;
		}
	}

	Log_Info("law","%d pillory and stocks placed",placed);
	Boot_LoaderDone();
}

#pragma warning push
#pragma warning disable 204
forward Task:Pillory_Create(kind,Float:x,Float:y,Float:z,Float:a,world,interior);

async Task:Pillory_Create(kind,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO law_devices (kind, x, y, z, a, world, interior) VALUES (%d, %f, %f, %f, %f, %d, %d)",kind,x,y,z,a,world,interior));

	new row = cache_insert_id();
	return async row > 0 ? Pillory_Add(row,kind,x,y,z,a,world,interior) : -1;
}
#pragma warning pop

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_PilloryOf[playerid] = -1;
	s_PilloryPrompt[playerid] = -1;
	s_PilloryPromptInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	new device = s_PilloryOf[playerid];

	if (device != -1)
	{
		s_Pillories[device][E_PILLORY_PRISONER] = INVALID_PLAYER_ID;
		s_PilloryOf[playerid] = -1;
	}
}

hook OnDynamicObjectMoved(STREAMER_TAG_OBJECT:objectid)
{
	for (new i = 0;i < PILLORY_THROWS_MAX;i++)
	{
		if (s_PilloryThrows[i][E_PILLORY_THROW_USED] && s_PilloryThrows[i][E_PILLORY_THROW_OBJECT] == objectid)
		{
			Pillory_Splat(i);
			break;
		}
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && s_PilloryPrompt[playerid] != -1 && !Infobox_IsPromptBlocked(playerid,s_PilloryPromptInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		new device = s_PilloryPrompt[playerid];
		Pillory_ClearPrompt(playerid);
		SetTimerEx("Pillory_CrowdDeferred",0,false,"dd",playerid,device);
	}
}
