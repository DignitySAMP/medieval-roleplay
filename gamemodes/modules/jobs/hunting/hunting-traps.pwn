#define HUNTING_PIT_MODEL (-3322)

enum E_HUNT_TRAP
{
	bool:E_HT_USED,
	E_HT_ROW,
	E_HT_KIND,
	Float:E_HT_POS[4],
	E_HT_OWNER,
	bool:E_HT_ARMED,
	bool:E_HT_BAITED,
	E_HT_ANIMAL,
	E_HT_PLAYER,
	E_HT_PLAYER_UNTIL,
	STREAMER_TAG_OBJECT:E_HT_OBJECT,
	STREAMER_TAG_OBJECT:E_HT_BAIT,
	STREAMER_TAG_3D_TEXT_LABEL:E_HT_LABEL,
}

static s_Traps[HUNTING_TRAPS_MAX][E_HUNT_TRAP];
static s_Trapped[MAX_PLAYERS] = {-1, ...};
static s_Setting[MAX_PLAYERS][4];
static s_TrapPrompt[MAX_PLAYERS] = {-1, ...};
static s_TrapInfobox[MAX_PLAYERS];

forward Task:Hunting_LoadTraps();
forward Task:Hunting_InsertTrap(trap);

stock bool:Hunting_IsTrap(trap)
{
	return trap >= 0 && trap < HUNTING_TRAPS_MAX && s_Traps[trap][E_HT_USED];
}

stock Hunting_GetTrapOwner(trap)
{
	return Hunting_IsTrap(trap) ? s_Traps[trap][E_HT_OWNER] : 0;
}

stock Hunting_GetTrapKind(trap)
{
	return Hunting_IsTrap(trap) ? s_Traps[trap][E_HT_KIND] : -1;
}

stock bool:Hunting_IsTrapArmed(trap)
{
	return Hunting_IsTrap(trap) && s_Traps[trap][E_HT_ARMED];
}

stock bool:Hunting_IsTrapBaited(trap)
{
	return Hunting_IsTrap(trap) && s_Traps[trap][E_HT_BAITED];
}

stock Hunting_GetTrapAnimal(trap)
{
	return Hunting_IsTrap(trap) ? s_Traps[trap][E_HT_ANIMAL] : -1;
}

stock Hunting_GetTrapped(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Trapped[playerid] : -1;
}

stock Hunting_CountTraps(owner = 0)
{
	new count = 0;

	for (new trap = 0;trap < HUNTING_TRAPS_MAX;trap++)
	{
		if (s_Traps[trap][E_HT_USED] && (owner == 0 || s_Traps[trap][E_HT_OWNER] == owner))
		{
			count++;
		}
	}

	return count;
}

stock Hunting_FindTrap(Float:x,Float:y,Float:z,Float:range)
{
	new best = -1, Float:bestDistance = range;

	for (new trap = 0;trap < HUNTING_TRAPS_MAX;trap++)
	{
		if (!s_Traps[trap][E_HT_USED])
		{
			continue;
		}

		new Float:d = VectorSize(s_Traps[trap][E_HT_POS][0] - x,s_Traps[trap][E_HT_POS][1] - y,s_Traps[trap][E_HT_POS][2] - z);

		if (d <= bestDistance)
		{
			bestDistance = d;
			best = trap;
		}
	}

	return best;
}

static Hunting_TrapModel(trap)
{
	switch (s_Traps[trap][E_HT_KIND])
	{
		case HUNT_TRAP_SNARE: return s_Traps[trap][E_HT_ARMED] ? MODEL_TOOLS_SNARE_SET : MODEL_TOOLS_SNARE_SPRUNG;
		case HUNT_TRAP_FOOTHOLD: return MODEL_TOOLS_FOOTHOLD_TRAP;
	}

	return HUNTING_PIT_MODEL;
}

stock Hunting_RefreshTrap(trap)
{
	if (IsValidDynamicObject(s_Traps[trap][E_HT_OBJECT]))
	{
		DestroyDynamicObject(s_Traps[trap][E_HT_OBJECT]);
	}

	if (IsValidDynamicObject(s_Traps[trap][E_HT_BAIT]))
	{
		DestroyDynamicObject(s_Traps[trap][E_HT_BAIT]);
	}

	if (IsValidDynamic3DTextLabel(s_Traps[trap][E_HT_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Traps[trap][E_HT_LABEL]);
	}

	s_Traps[trap][E_HT_BAIT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Traps[trap][E_HT_OBJECT] = CreateDynamicObject(Hunting_TrapModel(trap),s_Traps[trap][E_HT_POS][0],s_Traps[trap][E_HT_POS][1],s_Traps[trap][E_HT_POS][2],0.0,0.0,s_Traps[trap][E_HT_POS][3],0,0,-1,60.0,60.0);

	if (s_Traps[trap][E_HT_BAITED])
	{
		s_Traps[trap][E_HT_BAIT] = CreateDynamicObject(MODEL_PRODUCE_HUNT_BAIT,s_Traps[trap][E_HT_POS][0] + 0.4,s_Traps[trap][E_HT_POS][1],s_Traps[trap][E_HT_POS][2],0.0,0.0,0.0,0,0,-1,60.0,60.0);
	}

	new text[48];

	if (s_Traps[trap][E_HT_ANIMAL] != -1 || s_Traps[trap][E_HT_PLAYER] != INVALID_PLAYER_ID)
	{
		format(text,sizeof(text),"Something is caught in the %s",g_HuntTrapNames[s_Traps[trap][E_HT_KIND]]);
	}
	else
	{
		format(text,sizeof(text),"A %s %s",s_Traps[trap][E_HT_ARMED] ? ("set") : ("sprung"),g_HuntTrapNames[s_Traps[trap][E_HT_KIND]]);
	}

	s_Traps[trap][E_HT_LABEL] = CreateDynamic3DTextLabel(text,HUNTING_LABEL_COLOUR,s_Traps[trap][E_HT_POS][0],s_Traps[trap][E_HT_POS][1],s_Traps[trap][E_HT_POS][2] + 0.4,4.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
}

static Hunting_SaveTrap(trap)
{
	if (s_Traps[trap][E_HT_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE traps SET armed = %d, baited = %d WHERE id = %d",_:s_Traps[trap][E_HT_ARMED],_:s_Traps[trap][E_HT_BAITED],s_Traps[trap][E_HT_ROW]));
	}
}

stock Hunting_PlaceTrap(kind,Float:x,Float:y,Float:z,Float:a,owner,bool:isArmed = true,bool:isBaited = false,row = 0)
{
	new trap = -1;

	for (new i = 0;i < HUNTING_TRAPS_MAX;i++)
	{
		if (!s_Traps[i][E_HT_USED])
		{
			trap = i;
			break;
		}
	}

	if (trap == -1)
	{
		return -1;
	}

	s_Traps[trap][E_HT_USED] = true;
	s_Traps[trap][E_HT_ROW] = row;
	s_Traps[trap][E_HT_KIND] = kind;
	s_Traps[trap][E_HT_POS][0] = x;
	s_Traps[trap][E_HT_POS][1] = y;
	s_Traps[trap][E_HT_POS][2] = z;
	s_Traps[trap][E_HT_POS][3] = a;
	s_Traps[trap][E_HT_OWNER] = owner;
	s_Traps[trap][E_HT_ARMED] = isArmed;
	s_Traps[trap][E_HT_BAITED] = isBaited;
	s_Traps[trap][E_HT_ANIMAL] = -1;
	s_Traps[trap][E_HT_PLAYER] = INVALID_PLAYER_ID;
	s_Traps[trap][E_HT_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Traps[trap][E_HT_BAIT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Traps[trap][E_HT_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	Hunting_RefreshTrap(trap);

	if (row == 0)
	{
		Hunting_InsertTrap(trap);
	}

	return trap;
}

#pragma warning push
#pragma warning disable 204
async Task:Hunting_InsertTrap(trap)
{
	new owner = s_Traps[trap][E_HT_OWNER];
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO traps (kind, x, y, z, a, owner_character_id, armed, baited, caught_species, set_at) VALUES (%d, %f, %f, %f, %f, %d, %d, %d, -1, %d)",s_Traps[trap][E_HT_KIND],s_Traps[trap][E_HT_POS][0],s_Traps[trap][E_HT_POS][1],s_Traps[trap][E_HT_POS][2],s_Traps[trap][E_HT_POS][3],owner,_:s_Traps[trap][E_HT_ARMED],_:s_Traps[trap][E_HT_BAITED],gettime()));
	new row = cache_insert_id();

	if (s_Traps[trap][E_HT_USED] && s_Traps[trap][E_HT_OWNER] == owner && s_Traps[trap][E_HT_ROW] == 0)
	{
		s_Traps[trap][E_HT_ROW] = row;
	}
	else if (row > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM traps WHERE id = %d",row));
	}

	return async row;
}
#pragma warning pop

stock Hunting_RemoveTrap(trap)
{
	if (!Hunting_IsTrap(trap))
	{
		return;
	}

	Hunting_TrapLetGo(trap);

	if (IsValidDynamicObject(s_Traps[trap][E_HT_OBJECT]))
	{
		DestroyDynamicObject(s_Traps[trap][E_HT_OBJECT]);
	}

	if (IsValidDynamicObject(s_Traps[trap][E_HT_BAIT]))
	{
		DestroyDynamicObject(s_Traps[trap][E_HT_BAIT]);
	}

	if (IsValidDynamic3DTextLabel(s_Traps[trap][E_HT_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Traps[trap][E_HT_LABEL]);
	}

	if (s_Traps[trap][E_HT_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM traps WHERE id = %d",s_Traps[trap][E_HT_ROW]));
	}

	s_Traps[trap][E_HT_USED] = false;
}

stock Hunting_TrapLetGo(trap)
{
	if (!Hunting_IsTrap(trap))
	{
		return;
	}

	new animal = s_Traps[trap][E_HT_ANIMAL], playerid = s_Traps[trap][E_HT_PLAYER];
	s_Traps[trap][E_HT_ANIMAL] = -1;
	s_Traps[trap][E_HT_PLAYER] = INVALID_PLAYER_ID;
	s_Traps[trap][E_HT_ARMED] = false;

	if (animal != -1 && Animals_IsValid(animal) && Animals_GetHeldBy(animal) == trap)
	{
		Animals_Hold(animal,-1);
	}

	if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid) && s_Trapped[playerid] == trap)
	{
		s_Trapped[playerid] = -1;
		TogglePlayerControllable(playerid,true);
		ClearAnimations(playerid);
		Gui_Notify(playerid,"The jaws open and you pull your leg free.");
	}

	Hunting_RefreshTrap(trap);
	Hunting_SaveTrap(trap);
}

stock bool:Hunting_ArmTrap(trap)
{
	if (!Hunting_IsTrap(trap) || s_Traps[trap][E_HT_ARMED] || s_Traps[trap][E_HT_ANIMAL] != -1 || s_Traps[trap][E_HT_PLAYER] != INVALID_PLAYER_ID)
	{
		return false;
	}

	s_Traps[trap][E_HT_ARMED] = true;
	Hunting_RefreshTrap(trap);
	Hunting_SaveTrap(trap);
	return true;
}

stock bool:Hunting_BaitTrap(playerid,trap)
{
	if (!Hunting_IsTrap(trap) || s_Traps[trap][E_HT_BAITED] || !Inventory_Take(playerid,Item_GetDefKind(ITEM_BAIT),ITEM_BAIT,1))
	{
		return false;
	}

	s_Traps[trap][E_HT_BAITED] = true;
	Hunting_RefreshTrap(trap);
	Hunting_SaveTrap(trap);
	return true;
}

stock bool:Hunting_CatchPlayer(trap,playerid)
{
	if (!Hunting_IsTrap(trap) || !s_Traps[trap][E_HT_ARMED] || s_Traps[trap][E_HT_KIND] != HUNT_TRAP_FOOTHOLD || s_Trapped[playerid] != -1)
	{
		return false;
	}

	s_Traps[trap][E_HT_ARMED] = false;
	s_Traps[trap][E_HT_PLAYER] = playerid;
	s_Traps[trap][E_HT_PLAYER_UNTIL] = GetTickCount() + HUNTING_HELD_MS;
	s_Trapped[playerid] = trap;
	TogglePlayerControllable(playerid,false);
	ApplyAnimation(playerid,"PED","KO_skid_front",4.1,false,false,false,true,0,SYNC_ALL);
	Vitals_Damage(playerid,HUNTING_TRAP_DAMAGE,"a trap");
	Gui_Notify(playerid,"Iron jaws snap shut on your leg. Someone has to prise them open, or you work free in a few minutes.");
	Chat_Annotate(playerid,"steps into a hidden trap and goes down with a cry.");
	Hunting_RefreshTrap(trap);
	return true;
}

stock bool:Hunting_CatchAnimal(trap,animal)
{
	if (!Hunting_IsTrap(trap) || !s_Traps[trap][E_HT_ARMED])
	{
		return false;
	}

	if (s_Traps[trap][E_HT_KIND] == HUNT_TRAP_SNARE)
	{
		s_Traps[trap][E_HT_ARMED] = false;
		Hunting_SaveTrap(trap);
		Animals_Kill(animal,INVALID_PLAYER_ID);
		Hunting_RefreshTrap(trap);
		return true;
	}

	if (!Animals_Hold(animal,trap))
	{
		return false;
	}

	s_Traps[trap][E_HT_ARMED] = false;
	s_Traps[trap][E_HT_ANIMAL] = animal;
	Hunting_SaveTrap(trap);
	Hunting_RefreshTrap(trap);
	return true;
}

stock Hunting_TrapStep(trap)
{
	if (!Hunting_IsTrap(trap))
	{
		return;
	}

	new tick = GetTickCount(), playerid = s_Traps[trap][E_HT_PLAYER];

	if (playerid != INVALID_PLAYER_ID && (!IsPlayerConnected(playerid) || tick >= s_Traps[trap][E_HT_PLAYER_UNTIL]))
	{
		Hunting_TrapLetGo(trap);
		return;
	}

	if (s_Traps[trap][E_HT_ANIMAL] != -1 && (!Animals_IsValid(s_Traps[trap][E_HT_ANIMAL]) || Animals_GetHeldBy(s_Traps[trap][E_HT_ANIMAL]) != trap))
	{
		s_Traps[trap][E_HT_ANIMAL] = -1;
		Hunting_RefreshTrap(trap);
	}

	if (!s_Traps[trap][E_HT_ARMED])
	{
		return;
	}

	new Float:x = s_Traps[trap][E_HT_POS][0], Float:y = s_Traps[trap][E_HT_POS][1], Float:z = s_Traps[trap][E_HT_POS][2], kind = s_Traps[trap][E_HT_KIND];

	if (kind == HUNT_TRAP_FOOTHOLD)
	{
		foreach (new other : Player)
		{
			if (Session_IsPlaying(other) && !IsPlayerNPC(other) && GetPlayerVirtualWorld(other) == 0 && GetPlayerState(other) == PLAYER_STATE_ONFOOT && Character_GetId(other) != s_Traps[trap][E_HT_OWNER] && IsPlayerInRangeOfPoint(other,HUNTING_PLAYER_CATCH,x,y,z + 0.9))
			{
				Hunting_CatchPlayer(trap,other);
				return;
			}
		}
	}

	new Float:distance, animal = Animals_FindNear(x,y,z,HUNTING_CATCH_RANGE + 1.0,g_HuntTrapMasks[kind],distance);

	if (animal != -1 && Animals_GetHeldBy(animal) == -1)
	{
		Hunting_CatchAnimal(trap,animal);
		return;
	}

	if (s_Traps[trap][E_HT_BAITED])
	{
		animal = Animals_FindNear(x,y,z,HUNTING_BAIT_RANGE,g_HuntTrapMasks[kind],distance);

		if (animal != -1 && Animals_GetState(animal) == ANIMAL_STATE_WANDER)
		{
			Animals_Lure(animal,x,y,z);
		}
	}
}

stock bool:Hunting_BeginSetting(playerid,kind)
{
	new characterid = Character_GetId(playerid);

	if (Hunting_GetTrapped(playerid) != -1 || s_Setting[playerid][0] != 0 || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		return false;
	}

	if (Hunting_CountTraps(characterid) >= HUNTING_TRAPS_EACH)
	{
		Gui_Notify(playerid,sprintf("You can keep %d traps set at once. Take one up first.",HUNTING_TRAPS_EACH));
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	if (Hunting_FindTrap(x,y,z,4.0) != -1)
	{
		Gui_Notify(playerid,"There's a trap set right here already.");
		return false;
	}

	s_Setting[playerid][0] = kind + 1;
	s_Setting[playerid][1] = Account_GetToken(playerid);
	s_Setting[playerid][2] = floatround(x * 10.0);
	s_Setting[playerid][3] = floatround(y * 10.0);
	ApplyAnimation(playerid,"BOMBER","BOM_Plant_Loop",4.1,true,false,false,false,0,SYNC_ALL);
	Chat_Annotate(playerid,kind == HUNT_TRAP_PIT ? ("digs a pit and covers it over with branches.") : (kind == HUNT_TRAP_SNARE ? ("kneels and sets a snare in the grass.") : ("pries open an iron trap and buries it in the leaves.")));
	SetTimerEx("Hunting_SetDone",kind == HUNT_TRAP_PIT ? HUNTING_PIT_MS : HUNTING_SET_MS,false,"dd",playerid,Account_GetToken(playerid));
	return true;
}

stock Hunting_OpenTrap(playerid,trap)
{
	new characterid = Character_GetId(playerid), bool:mine = s_Traps[trap][E_HT_OWNER] == characterid, epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, rows = 0, picks[5], labels[5][40], title[24], line[96];
	format(title,sizeof(title),"A %s",g_HuntTrapNames[s_Traps[trap][E_HT_KIND]]);
	format(line,sizeof(line),"%s %s, %s%s.",mine ? ("Your") : ("Someone's"),g_HuntTrapNames[s_Traps[trap][E_HT_KIND]],s_Traps[trap][E_HT_ARMED] ? ("set") : ("sprung"),s_Traps[trap][E_HT_BAITED] ? (", baited") : (""));

	if (s_Traps[trap][E_HT_PLAYER] != INVALID_PLAYER_ID && s_Traps[trap][E_HT_PLAYER] != playerid)
	{
		picks[rows] = 1;
		labels[rows++] = "Prise the jaws open";
	}

	if (!s_Traps[trap][E_HT_ARMED] && s_Traps[trap][E_HT_ANIMAL] == -1 && s_Traps[trap][E_HT_PLAYER] == INVALID_PLAYER_ID)
	{
		picks[rows] = 2;
		labels[rows++] = "Set it again";
	}
	else if (s_Traps[trap][E_HT_ARMED])
	{
		picks[rows] = 3;
		labels[rows++] = "Spring it";
	}

	if (!s_Traps[trap][E_HT_BAITED] && Inventory_Count(playerid,Item_GetDefKind(ITEM_BAIT),ITEM_BAIT) > 0)
	{
		picks[rows] = 4;
		labels[rows++] = "Bait it";
	}

	if (s_Traps[trap][E_HT_PLAYER] == INVALID_PLAYER_ID)
	{
		picks[rows] = 5;
		labels[rows++] = s_Traps[trap][E_HT_KIND] == HUNT_TRAP_PIT ? ("Fill it in") : ("Take it up");
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HUNTING_PANEL_WIDTH,KIT_ROW * 2.0 + float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	for (new i = 0;i < rows;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(2 + i),width,labels[i],picks[i],KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * float(2 + rows) + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Hunting_IsTrap(trap))
	{
		return;
	}

	switch (pick)
	{
		case 1: Hunting_TrapLetGo(trap);
		case 2: Hunting_ArmTrap(trap);
		case 3:
		{
			Hunting_TrapLetGo(trap);

			if (!mine)
			{
				Law_Commit(playerid,LAW_CRIME_THEFT);
			}
		}
		case 4: Hunting_BaitTrap(playerid,trap);
		case 5:
		{
			new kind = s_Traps[trap][E_HT_KIND];
			Hunting_RemoveTrap(trap);

			if (kind != HUNT_TRAP_PIT)
			{
				Inventory_Give(playerid,Item_GetDefKind(kind == HUNT_TRAP_SNARE ? ITEM_SNARE : ITEM_TRAP),kind == HUNT_TRAP_SNARE ? ITEM_SNARE : ITEM_TRAP,1);
			}

			if (!mine)
			{
				Law_Commit(playerid,LAW_CRIME_THEFT);
			}
		}
	}
}

static Hunting_ClearTrapPrompt(playerid)
{
	if (s_TrapInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_TrapInfobox[playerid]);
	}

	s_TrapPrompt[playerid] = -1;
	s_TrapInfobox[playerid] = 0;
}

#pragma warning push
#pragma warning disable 204
async Task:Hunting_LoadTraps()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, x, y, z, a, owner_character_id, armed, baited FROM traps"));
	new count = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new id, kind, owner, armed, baited, Float:x, Float:y, Float:z, Float:a;
		cache_get_value_name_int(r,"id",id);
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_float(r,"x",x);
		cache_get_value_name_float(r,"y",y);
		cache_get_value_name_float(r,"z",z);
		cache_get_value_name_float(r,"a",a);
		cache_get_value_name_int(r,"owner_character_id",owner);
		cache_get_value_name_int(r,"armed",armed);
		cache_get_value_name_int(r,"baited",baited);

		if (kind >= 0 && kind < HUNT_TRAP_KINDS && Hunting_PlaceTrap(kind,x,y,z,a,owner,armed != 0,baited != 0,id) != -1)
		{
			count++;
		}
	}

	return async count;
}
#pragma warning pop

Timer_Declare(Hunting_TrapTick)
{
	for (new trap = 0;trap < HUNTING_TRAPS_MAX;trap++)
	{
		Hunting_TrapStep(trap);
	}

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		new trap = -1;

		if (Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && GetPlayerVirtualWorld(playerid) == 0 && s_Setting[playerid][0] == 0)
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid,x,y,z);
			trap = Hunting_FindTrap(x,y,z - 0.9,HUNTING_TRAP_REACH);

			if (trap != -1 && s_Trapped[playerid] == trap)
			{
				trap = -1;
			}
		}

		if (trap == -1)
		{
			Hunting_ClearTrapPrompt(playerid);
			continue;
		}

		if (trap == s_TrapPrompt[playerid] && Infobox_IsShown(playerid,s_TrapInfobox[playerid]))
		{
			continue;
		}

		new title[24];
		format(title,sizeof(title),"A %s",g_HuntTrapNames[s_Traps[trap][E_HT_KIND]]);
		s_TrapPrompt[playerid] = trap;
		s_TrapInfobox[playerid] = Infobox_Show(playerid,title,"Press ~y~Y~w~ to see to the trap.",3,0,true);
	}

	return 1;
}

forward Hunting_SetDone(playerid,token);

public Hunting_SetDone(playerid,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || s_Setting[playerid][0] == 0)
	{
		return 1;
	}

	new kind = s_Setting[playerid][0] - 1, Float:x, Float:y, Float:z, Float:a;
	s_Setting[playerid][0] = 0;
	ClearAnimations(playerid);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);

	if (VectorSize(x - float(s_Setting[playerid][2]) / 10.0,y - float(s_Setting[playerid][3]) / 10.0,0.0) > 2.0)
	{
		Gui_Notify(playerid,"You moved off before it was set.");
		return 1;
	}

	new item = kind == HUNT_TRAP_SNARE ? ITEM_SNARE : (kind == HUNT_TRAP_FOOTHOLD ? ITEM_TRAP : -1);

	if (item != -1 && !Inventory_Take(playerid,Item_GetDefKind(item),item,1))
	{
		return 1;
	}

	x += floatsin(-a,degrees) * 1.0;
	y += floatcos(-a,degrees) * 1.0;
	new Float:hx, Float:hy, Float:hz;

	if (CA_RayCastLine(x,y,z + 1.0,x,y,z - 4.0,hx,hy,hz) != 0)
	{
		z = hz;
	}
	else
	{
		z -= 0.95;
	}

	if (Hunting_PlaceTrap(kind,x,y,z,a,Character_GetId(playerid)) == -1)
	{
		if (item != -1)
		{
			Inventory_Give(playerid,Item_GetDefKind(item),item,1);
		}

		Gui_Notify(playerid,"There's no room for another trap in the county.");
		return 1;
	}

	Work_AddPractice(playerid,TRADE_HUNTING,WORK_PRACTICE_PER_STAR);
	Gui_Notify(playerid,sprintf("The %s is set. Bait draws game to it from afar.",g_HuntTrapNames[kind]));
	return 1;
}

forward bool:Hunting_TrapContext(playerid);

public bool:Hunting_TrapContext(playerid)
{
	return s_TrapPrompt[playerid] != -1;
}

forward Hunting_OpenTrapDeferred(playerid,trap);

public Hunting_OpenTrapDeferred(playerid,trap)
{
	if (IsPlayerConnected(playerid) && Hunting_IsTrap(trap))
	{
		Hunting_OpenTrap(playerid,trap);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Trapped[playerid] = -1;
	s_Setting[playerid][0] = 0;
	s_TrapPrompt[playerid] = -1;
	s_TrapInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_Trapped[playerid] != -1)
	{
		Hunting_TrapLetGo(s_Trapped[playerid]);
	}

	s_Trapped[playerid] = -1;
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars, index

	if (E_ITEM_KIND:kind == Item_GetDefKind(ITEM_SNARE) && param == ITEM_SNARE)
	{
		Hunting_BeginSetting(playerid,HUNT_TRAP_SNARE);
	}
	else if (E_ITEM_KIND:kind == Item_GetDefKind(ITEM_TRAP) && param == ITEM_TRAP)
	{
		Hunting_BeginSetting(playerid,HUNT_TRAP_FOOTHOLD);
	}
	else if (E_ITEM_KIND:kind == Item_GetDefKind(ITEM_SHOVEL) && param == ITEM_SHOVEL && GetPlayerVirtualWorld(playerid) == 0)
	{
		Hunting_BeginSetting(playerid,HUNT_TRAP_PIT);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || (newkeys & KEY_WALK) || s_TrapPrompt[playerid] == -1 || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new trap = s_TrapPrompt[playerid];
	Hunting_ClearTrapPrompt(playerid);

	if (Hunting_IsTrap(trap))
	{
		SetTimerEx("Hunting_OpenTrapDeferred",0,false,"dd",playerid,trap);
	}
}
