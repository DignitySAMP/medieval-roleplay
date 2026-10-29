#define WORK_OWNED_CAP (2)
#define WORK_GRACE_SECONDS (3600)
#define WORK_BURN_TICK_MS (60000)
#define WORK_BUILD_COOLDOWN_SECONDS (60)
#define WORK_SPACING (3.0)
#define WORK_PLACE_FEET_BELOW (1.0)
#define WORK_PLACE_DROP_MAX (1.5)
#define WORK_SPAWN_SPACING (8.0)
#define WORK_INVITE_RANGE (5.0)
#define WORK_PANEL_WORK (1)
#define WORK_PANEL_FUEL (2)
#define WORK_PANEL_INVITE (3)
#define WORK_PANEL_UNINVITE (4)
#define WORK_PANEL_PACK (5)

enum
{
	WORK_PACK_HAND,
	WORK_PACK_LAPSED,
	WORK_PACK_GRACE,
	WORK_PACK_STAFF,
}

static s_WorkBuildCooldown[MAX_PLAYERS];

forward Task:Work_BuildAt(playerid,kind,Float:x,Float:y,Float:z,Float:a);

stock Work_ResetBuildCooldown(playerid)
{
	s_WorkBuildCooldown[playerid] = 0;
}

stock Work_GetStationOwner(stationid)
{
	return Work_IsValidStation(stationid) ? g_WorkStations[stationid][E_WORK_STATION_OWNER] : 0;
}

stock bool:Work_IsInvited(stationid,characterid)
{
	if (!Work_IsValidStation(stationid) || characterid <= 0)
	{
		return false;
	}

	for (new i = 0;i < WORK_INVITES_MAX;i++)
	{
		if (g_WorkStations[stationid][E_WORK_STATION_INVITES][i] == characterid)
		{
			return true;
		}
	}

	return false;
}

stock bool:Work_CanUseStation(playerid,stationid)
{
	new owner = Work_GetStationOwner(stationid), characterid = Character_GetId(playerid);
	return owner == 0 || (characterid > 0 && (owner == characterid || Work_IsInvited(stationid,characterid)));
}

stock Work_FindOwnerPlayer(characterid)
{
	if (characterid <= 0)
	{
		return INVALID_PLAYER_ID;
	}

	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == characterid)
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Work_CountOwnedStations(characterid)
{
	new count = 0;

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED] && characterid > 0 && g_WorkStations[i][E_WORK_STATION_OWNER] == characterid)
		{
			count++;
		}
	}

	return count;
}

stock Work_GetStationRemaining(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return 0;
	}

	new kind = g_WorkStations[stationid][E_WORK_STATION_KIND], item = g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM];
	return max(g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS],0) + (item >= 0 ? g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS] * Work_GetFuelSeconds(kind,item) : 0);
}

stock Work_FormatRemaining(seconds,dest[],size = sizeof(dest))
{
	format(dest,size,"%dh %02dm",seconds / 3600,(seconds % 3600) / 60);
}

stock Work_InviteCharacter(stationid,characterid)
{
	if (!Work_AddInviteLocal(stationid,characterid))
	{
		return false;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO station_invites (station_id, character_id) VALUES (%d, %d)",g_WorkStations[stationid][E_WORK_STATION_ROW],characterid));
	return true;
}

stock Work_ClearInvites(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	for (new i = 0;i < WORK_INVITES_MAX;i++)
	{
		g_WorkStations[stationid][E_WORK_STATION_INVITES][i] = 0;
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM station_invites WHERE station_id = %d",g_WorkStations[stationid][E_WORK_STATION_ROW]));
}

stock Work_PackUpStation(stationid,reason)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	new owner = g_WorkStations[stationid][E_WORK_STATION_OWNER], kind = g_WorkStations[stationid][E_WORK_STATION_KIND];

	if (owner > 0)
	{
		for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
		{
			if (!Work_GetBuildMaterial(kind,i,item,amount))
			{
				continue;
			}

			Claims_Give(owner,Item_GetDefKind(item),item,reason == WORK_PACK_LAPSED ? (amount + 1) / 2 : amount,ITEM_STARS_MIN,"station packed up");
		}

		new fuel = g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM], units = g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS];

		if (reason != WORK_PACK_LAPSED && fuel >= 0 && units > 0)
		{
			Claims_Give(owner,Item_GetDefKind(fuel),fuel,units,ITEM_STARS_MIN,Work_IsFireKind(kind) ? ("unburnt fuel") : ("unused upkeep"));
		}

		new playerid = Work_FindOwnerPlayer(owner), name[WORK_KIND_NAME_LEN], message[128];

		if (playerid != INVALID_PLAYER_ID)
		{
			Work_GetKindName(kind,name);

			switch (reason)
			{
				case WORK_PACK_LAPSED: format(message,sizeof(message),Work_IsFireKind(kind) ? ("Your %s ran out of fuel and burnt out. You got half of its materials back.") : ("Your %s fell apart without upkeep. You got half of its materials back."),name);
				case WORK_PACK_STAFF: format(message,sizeof(message),"Staff took down your %s. Everything came back to you.",name);
				default: format(message,sizeof(message),Work_IsFireKind(kind) ? ("Your %s is packed up. Its materials and unburnt fuel came back to you.") : ("Your %s is packed up. Its materials and unused upkeep came back to you."),name);
			}

			Gui_Notify(playerid,message);
		}
	}

	pawn_call_public("Work_OnStationPackedUp","dd",stationid,reason);
	Work_DeleteStation(stationid);
}

stock Work_BurnStation(stationid,seconds)
{
	if (!Work_IsValidStation(stationid) || g_WorkStations[stationid][E_WORK_STATION_OWNER] == 0)
	{
		return;
	}

	new kind = g_WorkStations[stationid][E_WORK_STATION_KIND];
	g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS] -= seconds;

	while (g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS] <= 0 && g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS] > 0 && g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM] >= 0)
	{
		g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS]--;
		g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS] += Work_GetFuelSeconds(kind,g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM]);
	}

	if (g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS] <= 0)
	{
		Work_PackUpStation(stationid,WORK_PACK_LAPSED);
		return;
	}

	Work_SaveStationState(stationid);
}

stock bool:Work_AddFuel(playerid,stationid,item,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	if (!Work_IsValidStation(stationid))
	{
		return false;
	}

	new kind = g_WorkStations[stationid][E_WORK_STATION_KIND], seconds = Work_GetFuelSeconds(kind,item), current = g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM];

	if (seconds <= 0)
	{
		strcopy(reason,Work_IsFireKind(kind) ? ("That isn't fuel for this station.") : ("That isn't upkeep for this station."),size);
	}
	else if (current >= 0 && current != item && g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS] > 0)
	{
		strcopy(reason,Work_IsFireKind(kind) ? ("Let the fuel that's in it burn off before you switch to another kind.") : ("Let the upkeep that's in it run out before you switch to another kind."),size);
	}
	else if (Work_GetStationRemaining(stationid) + seconds > WORK_FUEL_CAP_SECONDS)
	{
		format(reason,size,Work_IsFireKind(kind) ? ("It can't hold more than %d hours of fuel.") : ("It can't take more than %d hours of upkeep."),WORK_FUEL_CAP_SECONDS / 3600);
	}
	else if (!Inventory_Take(playerid,Item_GetDefKind(item),item,1))
	{
		strcopy(reason,"You don't have any of that.",size);
	}

	if (reason[0] != EOS)
	{
		return false;
	}

	g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM] = item;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS]++;
	Work_SaveStationState(stationid);
	return true;
}

stock Work_BurnTickAll()
{
	new now = gettime();

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (!g_WorkStations[i][E_WORK_STATION_USED] || g_WorkStations[i][E_WORK_STATION_OWNER] == 0)
		{
			continue;
		}

		if (Work_FindOwnerPlayer(g_WorkStations[i][E_WORK_STATION_OWNER]) != INVALID_PLAYER_ID)
		{
			g_WorkStations[i][E_WORK_STATION_GRACE] = 0;
		}
		else if (g_WorkStations[i][E_WORK_STATION_GRACE] == 0)
		{
			g_WorkStations[i][E_WORK_STATION_GRACE] = now + WORK_GRACE_SECONDS;
		}
		else if (now >= g_WorkStations[i][E_WORK_STATION_GRACE])
		{
			Work_PackUpStation(i,WORK_PACK_GRACE);
			continue;
		}

		Work_BurnStation(i,WORK_BURN_TICK_MS / 1000);
	}
}

stock Work_FormatMaterials(playerid,kind,dest[],size = sizeof(dest),&bool:hasAll = false)
{
	new name[ITEM_NAME_LEN], part[48];
	dest[0] = EOS;
	hasAll = true;

	for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
	{
		if (!Work_GetBuildMaterial(kind,i,item,amount))
		{
			continue;
		}

		new have = Inventory_Count(playerid,Item_GetDefKind(item),item);
		Item_GetName(Item_GetDefKind(item),item,name);
		format(part,sizeof(part),"%s%s%d/%d %s",dest[0] == EOS ? ("") : ("~w~, "),have >= amount ? ("~g~") : ("~r~"),min(have,amount),amount,name);
		strcat(dest,part,size);

		if (have < amount)
		{
			hasAll = false;
		}
	}
}

stock bool:Work_CanPlaceKind(playerid,kind,reason[],size = sizeof(reason))
{
	new materials[160], bool:hasAll, key[WORK_KIND_KEY_LEN];
	reason[0] = EOS;
	Work_GetKindKey(kind,key);

	if (!Talent_OwnsKey(playerid,key))
	{
		strcopy(reason,"You haven't learned to build that yet. Learn it in Crafting > Talents.",size);
	}
	else if (Work_CountOwnedStations(Character_GetId(playerid)) >= WORK_OWNED_CAP)
	{
		format(reason,size,"You already have %d stations. Pack one up first.",WORK_OWNED_CAP);
	}
	else if (gettime() < s_WorkBuildCooldown[playerid])
	{
		strcopy(reason,"You have to wait a minute between builds.",size);
	}
	else
	{
		Work_FormatMaterials(playerid,kind,materials,sizeof(materials),hasAll);

		if (!hasAll)
		{
			strcopy(reason,"You don't have the materials for that.",size);
		}
	}

	return reason[0] == EOS;
}

stock bool:Work_CheckSpot(Float:x,Float:y,Float:z,world,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED] && g_WorkStations[i][E_WORK_STATION_WORLD] == world && Util_GetDistance3D(x,y,z,g_WorkStations[i][E_WORK_STATION_POS][0],g_WorkStations[i][E_WORK_STATION_POS][1],g_WorkStations[i][E_WORK_STATION_POS][2]) < WORK_SPACING)
		{
			format(reason,size,"That's too close to another station. Leave at least %.0f m between them.",WORK_SPACING);
			return false;
		}
	}

	if (world == 0 && Util_GetDistance2D(x,y,MAP_SPAWN_X,MAP_SPAWN_Y) < WORK_SPAWN_SPACING)
	{
		format(reason,size,"That's too close to the spawn point. Move at least %.0f m away.",WORK_SPAWN_SPACING);
		return false;
	}

	return true;
}

stock bool:Work_TakeMaterials(playerid,kind)
{
	new materials[160], bool:hasAll;
	Work_FormatMaterials(playerid,kind,materials,sizeof(materials),hasAll);

	if (!hasAll)
	{
		return false;
	}

	for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
	{
		if (Work_GetBuildMaterial(kind,i,item,amount))
		{
			Inventory_Take(playerid,Item_GetDefKind(item),item,amount);
		}
	}

	return true;
}

static bool:Work_PlaceGizmo(playerid,epoch,kind,&Float:x,&Float:y,&Float:z,&Float:a)
{
	new name[WORK_KIND_NAME_LEN], world = GetPlayerVirtualWorld(playerid);
	Work_GetKindName(kind,name);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x -= 1.5 * floatsin(a,degrees);
	y += 1.5 * floatcos(a,degrees);
	a = Util_NormalizeAngle(a + 180.0);
	Work_SnapKind(kind,x,y,z,a);
	Kit_Close(playerid);

	new model = Work_GetKindBodyModel(kind), STREAMER_TAG_OBJECT:ghost = CreateDynamicObject(model,x,y,z,0.0,0.0,a,world,GetPlayerInterior(playerid),playerid);

	if (model == WORK_PLACEHOLDER_MODEL)
	{
		SetDynamicObjectMaterialText(ghost,0,name,_:OBJECT_MATERIAL_SIZE_256x128,"Arial",28,1,WORK_BODY_TEXT_COLOUR,WORK_BODY_BACK_COLOUR,1);
	}
	Gui_Notify(playerid,"Drag the arrows to move it, then click the save icon. Press ESC to cancel.");
	pawn_call_public("Work_OnPlacementStarted","dd",playerid,kind);

	for (;;)
	{
		new bool:isSaved = bool:await Placement_Edit(playerid,ghost);

		if (!Gui_IsFlowCurrent(playerid,epoch) || !isSaved)
		{
			DestroyDynamicObject(ghost);
			return false;
		}

		new Float:rx, Float:ry, reason[64], Float:feetX, Float:feetY, Float:feetZ;
		Placement_GetPose(playerid,x,y,z,rx,ry,a);
		GetPlayerPos(playerid,feetX,feetY,feetZ);
		feetZ -= WORK_PLACE_FEET_BELOW;

		if (z < feetZ)
		{
			z = feetZ;
		}

		if (!Work_SnapKind(kind,x,y,z,a))
		{
			strcopy(reason,"There's no ground under it.");
		}
		else if (z < feetZ - WORK_PLACE_DROP_MAX)
		{
			strcopy(reason,"The ground gives way there. Try a step to the side.");
		}
		else
		{
			Work_CheckSpot(x,y,z,world,reason);
		}

		if (reason[0] == EOS)
		{
			DestroyDynamicObject(ghost);
			return true;
		}

		new message[96];
		format(message,sizeof(message),"You can't place it there. It's %s.",reason);
		Gui_Notify(playerid,message);
		SetDynamicObjectPos(ghost,x,y,z);
		SetDynamicObjectRot(ghost,0.0,0.0,a);
	}
}

stock Work_BuildFlow(playerid,epoch,kind)
{
	new reason[96];

	if (!Work_CanPlaceKind(playerid,kind,reason))
	{
		Kit_Close(playerid);
		Gui_Notify(playerid,reason);
		return;
	}

	new Float:px, Float:py, Float:pz, Float:pa;

	if (!Work_PlaceGizmo(playerid,epoch,kind,px,py,pz,pa))
	{
		pawn_call_public("Work_OnPlacementCancelled","dd",playerid,kind);
		return;
	}

	if ((await Work_BuildAt(playerid,kind,px,py,pz,pa)) == -1 && IsPlayerConnected(playerid))
	{
		pawn_call_public("Work_OnPlacementCancelled","dd",playerid,kind);
	}
}

#pragma warning push
#pragma warning disable 204

async Task:Work_BuildAt(playerid,kind,Float:x,Float:y,Float:z,Float:a)
{
	await task_ticks(1);

	new reason[96], world = GetPlayerVirtualWorld(playerid);

	if (!Work_CanPlaceKind(playerid,kind,reason))
	{
		Gui_Notify(playerid,reason);
		return async -1;
	}

	if (!Work_SnapKind(kind,x,y,z,a) || !Work_CheckSpot(x,y,z,world,reason) || !Work_TakeMaterials(playerid,kind))
	{
		Gui_Notify(playerid,reason[0] != EOS ? reason : "It can't stand there. Try flatter ground.");
		return async -1;
	}

	s_WorkBuildCooldown[playerid] = gettime() + WORK_BUILD_COOLDOWN_SECONDS;

	new characterid = Character_GetId(playerid), stationid = await Work_CreateStation(kind,x,y,z,a,world,GetPlayerInterior(playerid),characterid);

	if (stationid == -1)
	{
		for (new i = 0, item, amount;i < WORK_BUILD_MAX;i++)
		{
			if (Work_GetBuildMaterial(kind,i,item,amount))
			{
				Claims_Give(characterid,Item_GetDefKind(item),item,amount,ITEM_STARS_MIN,"build failed");
			}
		}

		if (IsPlayerConnected(playerid))
		{
			Gui_Notify(playerid,"It couldn't be built. Your materials are back in your bag.");
		}

		return async -1;
	}

	if (IsPlayerConnected(playerid))
	{
		new name[WORK_KIND_NAME_LEN], remaining[16], message[128];
		Work_GetKindName(kind,name);
		Work_FormatRemaining(Work_GetStationRemaining(stationid),remaining);
		format(message,sizeof(message),Work_IsFireKind(kind) ? ("Your %s is built. It lasts %s. Add fuel to keep it going longer.") : ("Your %s is built. It lasts %s. Maintain it to keep it going longer."),name,remaining);
		Gui_Notify(playerid,message);
		pawn_call_public("Work_OnStationPlaced","dd",playerid,stationid);
	}

	return async stationid;
}
#pragma warning pop

static Work_OwnerAddFuel(playerid,epoch,stationid)
{
	new kind = g_WorkStations[stationid][E_WORK_STATION_KIND], items[WORK_FUEL_MAX], count = 0, name[ITEM_NAME_LEN], detail[32], Float:x, Float:y, Float:width;

	for (new i = 0;i < WORK_FUEL_MAX;i++)
	{
		items[count++] = Work_GetFuelItem(kind,i);
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,Work_IsFireKind(kind) ? ("Add fuel") : ("Maintain"));
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,Work_IsFireKind(kind) ? ("Add fuel") : ("Maintain"),x,y,width);

	for (new i = 0;i < count;i++)
	{
		new have = Inventory_Count(playerid,Item_GetDefKind(items[i]),items[i]), minutes = Work_GetFuelSeconds(kind,items[i]) / 60;
		Item_GetName(Item_GetDefKind(items[i]),items[i],name);
		format(detail,sizeof(detail),"+%dh%02d, have %d",minutes / 60,minutes % 60,have);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,have > 0 ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,detail,KIT_COLOUR_MUTED,0.55);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= count || !Work_IsValidStation(stationid))
	{
		return;
	}

	new reason[64];

	if (!Work_AddFuel(playerid,stationid,items[pick],reason))
	{
		Gui_Notify(playerid,reason);
	}
}

static Work_OwnerInvite(playerid,epoch,stationid)
{
	new Float:px, Float:py, Float:pz, ids[8], count = 0, name[MAX_PLAYER_NAME + 16], Float:x, Float:y, Float:width;
	GetPlayerPos(playerid,px,py,pz);

	foreach (new other : Player)
	{
		if (other != playerid && count < sizeof(ids) && !IsPlayerNPC(other) && Session_IsPlaying(other) && IsPlayerInRangeOfPoint(other,WORK_INVITE_RANGE,px,py,pz))
		{
			ids[count++] = other;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"Nobody is close enough to invite.");
		return;
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Invite");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Invite",x,y,width);

	for (new i = 0;i < count;i++)
	{
		Nametag_GetKnownName(playerid,ids[i],name);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,KIT_COLOUR_TEXT,Work_IsInvited(stationid,Character_GetId(ids[i])) ? ("invited") : (""),KIT_COLOUR_MUTED,0.70);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick >= count || !IsPlayerConnected(ids[pick]) || !Work_IsValidStation(stationid))
	{
		return;
	}

	if (!Work_InviteCharacter(stationid,Character_GetId(ids[pick])))
	{
		Gui_Notify(playerid,"You can't invite anyone else. Clear your invites first.");
		return;
	}

	new kindName[WORK_KIND_NAME_LEN], message[96];
	Work_GetKindName(g_WorkStations[stationid][E_WORK_STATION_KIND],kindName);
	format(message,sizeof(message),"You can now work at this %s.",kindName);
	Gui_Notify(ids[pick],message);
	Gui_Notify(playerid,"Invited.");
}

stock Work_OpenOwnerPanel(playerid,stationid)
{
	new epoch = Gui_BeginFlow(playerid);

	for (;;)
	{
		if (!Work_IsValidStation(stationid) || Work_GetStationOwner(stationid) != Character_GetId(playerid))
		{
			Kit_Close(playerid);
			return;
		}

		new name[WORK_KIND_NAME_LEN], remaining[16], fuel[48], invites = 0, invitesLabel[32], Float:x, Float:y, Float:width;
		Work_GetKindName(g_WorkStations[stationid][E_WORK_STATION_KIND],name);
		Work_FormatRemaining(Work_GetStationRemaining(stationid),remaining);
		format(fuel,sizeof(fuel),Work_IsFireKind(g_WorkStations[stationid][E_WORK_STATION_KIND]) ? ("Add fuel (%s left)") : ("Maintain (%s left)"),remaining);

		for (new i = 0;i < WORK_INVITES_MAX;i++)
		{
			if (g_WorkStations[stationid][E_WORK_STATION_INVITES][i] != 0)
			{
				invites++;
			}
		}

		format(invitesLabel,sizeof(invitesLabel),"Clear invites (%d)",invites);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,220.0,5.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
		Kit_AddChoice(playerid,x,y,width,"Work here",WORK_PANEL_WORK);
		Kit_AddChoice(playerid,x,y + KIT_ROW,width,fuel,WORK_PANEL_FUEL);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width,"Invite someone nearby",WORK_PANEL_INVITE);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width,invitesLabel,WORK_PANEL_UNINVITE,invites > 0 ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width,"Pack it up",WORK_PANEL_PACK,KIT_COLOUR_BAD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 5.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Work_IsValidStation(stationid))
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case WORK_PANEL_WORK:
			{
				Kit_Close(playerid);
				Work_OpenRecipes(playerid,WORK_TARGET_STATION,stationid);
				return;
			}
			case WORK_PANEL_FUEL: Work_OwnerAddFuel(playerid,epoch,stationid);
			case WORK_PANEL_INVITE: Work_OwnerInvite(playerid,epoch,stationid);
			case WORK_PANEL_UNINVITE: Work_ClearInvites(stationid);
			case WORK_PANEL_PACK:
			{
				if (Work_IsValidStation(stationid) && g_WorkStations[stationid][E_WORK_STATION_WORKER] != INVALID_PLAYER_ID && g_WorkStations[stationid][E_WORK_STATION_WORKER] != playerid)
				{
					Gui_Notify(playerid,"Someone is working at it.");
					continue;
				}

				Kit_Close(playerid);
				Work_PackUpStation(stationid,WORK_PACK_HAND);
				return;
			}
		}

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}
	}
}

Timer_Declare(Work_BurnTick)
{
	Work_BurnTickAll();
}

forward Work_OnStationPlaced(playerid,stationid);

public Work_OnStationPlaced(playerid,stationid)
{
	return 1;
}

forward Work_OnPlacementStarted(playerid,kind);

public Work_OnPlacementStarted(playerid,kind)
{
	return 1;
}

forward Work_OnPlacementCancelled(playerid,kind);

public Work_OnPlacementCancelled(playerid,kind)
{
	return 1;
}

forward Work_OnStationPackedUp(stationid,reason);

public Work_OnStationPackedUp(stationid,reason)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_WorkBuildCooldown[playerid] = 0;
}

hook Character_OnLoaded(playerid,characterid)
{
	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED] && g_WorkStations[i][E_WORK_STATION_OWNER] == characterid && g_WorkStations[i][E_WORK_STATION_GRACE] != 0)
		{
			g_WorkStations[i][E_WORK_STATION_GRACE] = 0;
			Work_SaveStationState(i);
		}
	}
}

hook Character_OnUnloaded(playerid)
{
	new characterid = Character_GetId(playerid);

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED] && characterid > 0 && g_WorkStations[i][E_WORK_STATION_OWNER] == characterid)
		{
			g_WorkStations[i][E_WORK_STATION_GRACE] = gettime() + WORK_GRACE_SECONDS;
			Work_SaveStationState(i);
		}
	}
}
