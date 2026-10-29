#define YARD_REACH (1.7)
#define YARD_RIVER_REACH (2.5)
#define YARD_WASH_MS (4500)
#define YARD_RIVER_WASH (50)
#define YARD_SPRING_DRINK (25)
#define YARD_TUB_LEVELS (2)
#define YARD_PROMPT_MS (500)
#define YARD_LABEL_COLOUR (0xD8CCB2FF)
#define YARD_WELL_REACH (2.7)
#define YARD_WELL_HEIGHT (3.0)
#define YARD_WELL_DRINK (25)

enum
{
	YARD_KIND_WASHTUB,
	YARD_KIND_SPRING,
	YARD_KIND_STOUP,
	YARD_KIND_TROUGH,
}

enum
{
	YARD_PROMPT_NONE,
	YARD_PROMPT_NODE,
	YARD_PROMPT_RIVER,
	YARD_PROMPT_WELL,
}

enum E_YARD_WELL
{
	E_YARD_WELL_NAME[28],
	Float:E_YARD_WELL_POS[3],
}

static const s_YardWells[][E_YARD_WELL] = {
	{"the Talmberg well", {1007.0, -3401.5, 65.7}},
	{"the church village well", {1005.0, -3155.0, 34.0}}
};

static s_YardLevel[sizeof(g_YardDefs)];
static STREAMER_TAG_OBJECT:s_YardObjects[sizeof(g_YardDefs)];
static s_YardPrompt[MAX_PLAYERS];
static s_YardPromptNode[MAX_PLAYERS] = {-1, ...};
static s_YardPromptLevel[MAX_PLAYERS];
static s_YardInfobox[MAX_PLAYERS];
static bool:s_YardBusy[MAX_PLAYERS];

stock Yard_GetLevel(node)
{
	return node >= 0 && node < YARD_SEED_NODES ? s_YardLevel[node] : 0;
}

stock Yard_GetKind(node)
{
	return node >= 0 && node < YARD_SEED_NODES ? g_YardDefs[node][E_YARD_DEF_KIND] : -1;
}

stock Yard_FindKind(kind)
{
	for (new node = 0;node < YARD_SEED_NODES;node++)
	{
		if (g_YardDefs[node][E_YARD_DEF_KIND] == kind)
		{
			return node;
		}
	}

	return -1;
}

static Yard_Model(node)
{
	switch (g_YardDefs[node][E_YARD_DEF_KIND])
	{
		case YARD_KIND_WASHTUB: return s_YardLevel[node] >= 2 ? MODEL_YARD_WASHTUB_FULL : (s_YardLevel[node] == 1 ? MODEL_YARD_WASHTUB_HALF : MODEL_YARD_WASHTUB_EMPTY);
		case YARD_KIND_SPRING: return s_YardLevel[node] > 0 ? MODEL_YARD_SPRING_FULL : MODEL_YARD_SPRING_LOW;
		case YARD_KIND_STOUP: return MODEL_YARD_HOLY_STOUP;
	}

	return MODEL_YARD_TROUGH_WATER;
}

stock Yard_SetLevel(node,level)
{
	if (node < 0 || node >= YARD_SEED_NODES)
	{
		return;
	}

	new limit = g_YardDefs[node][E_YARD_DEF_KIND] == YARD_KIND_WASHTUB ? YARD_TUB_LEVELS : 1;
	level = clamp(level,0,limit);

	if (level == s_YardLevel[node] && s_YardObjects[node] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		return;
	}

	s_YardLevel[node] = level;

	if (s_YardObjects[node] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		DestroyDynamicObject(s_YardObjects[node]);
	}

	s_YardObjects[node] = CreateDynamicObject(Yard_Model(node),g_YardDefs[node][E_YARD_DEF_POS][0],g_YardDefs[node][E_YARD_DEF_POS][1],g_YardDefs[node][E_YARD_DEF_POS][2],0.0,0.0,g_YardDefs[node][E_YARD_DEF_POS][3],0,0,-1,120.0);
}

stock Yard_Place()
{
	for (new node = 0;node < YARD_SEED_NODES;node++)
	{
		s_YardObjects[node] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_YardLevel[node] = -1;
		Yard_SetLevel(node,g_YardDefs[node][E_YARD_DEF_KIND] == YARD_KIND_WASHTUB ? YARD_TUB_LEVELS : 1);

		if (g_YardDefs[node][E_YARD_DEF_KIND] == YARD_KIND_WASHTUB)
		{
			CreateDynamic3DTextLabel("Washing trough",YARD_LABEL_COLOUR,g_YardDefs[node][E_YARD_DEF_POS][0],g_YardDefs[node][E_YARD_DEF_POS][1],g_YardDefs[node][E_YARD_DEF_POS][2] + 1.0,6.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
		}
	}
}

stock Yard_FindNodeNear(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != 0)
	{
		return -1;
	}

	for (new node = 0;node < YARD_SEED_NODES;node++)
	{
		if (g_YardDefs[node][E_YARD_DEF_KIND] != YARD_KIND_TROUGH && IsPlayerInRangeOfPoint(playerid,YARD_REACH,g_YardDefs[node][E_YARD_DEF_STAND][0],g_YardDefs[node][E_YARD_DEF_STAND][1],g_YardDefs[node][E_YARD_DEF_STAND][2] + 1.0))
		{
			return node;
		}
	}

	return -1;
}

stock Yard_FindWellNear(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != 0)
	{
		return -1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new well = 0;well < sizeof(s_YardWells);well++)
	{
		if (floatabs(z - s_YardWells[well][E_YARD_WELL_POS][2]) < YARD_WELL_HEIGHT && VectorSize(x - s_YardWells[well][E_YARD_WELL_POS][0],y - s_YardWells[well][E_YARD_WELL_POS][1],0.0) <= YARD_WELL_REACH)
		{
			return well;
		}
	}

	return -1;
}

stock Float:Yard_GetWellDistance(playerid)
{
	new well = Yard_FindWellNear(playerid);

	if (well == -1)
	{
		return -1.0;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return VectorSize(x - s_YardWells[well][E_YARD_WELL_POS][0],y - s_YardWells[well][E_YARD_WELL_POS][1],0.0);
}

stock Yard_FindStartedSkin(playerid)
{
	new E_ITEM_KIND:kind, param, amount;

	for (new i = 0;i < Inventory_GetCount(playerid);i++)
	{
		if (Inventory_GetSlot(playerid,i,kind,param,amount) && kind == ITEM_KIND_DRINK && param == ITEM_WATER_SKIN && Inventory_GetSlotUsed(playerid,i) > 0)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Yard_DrawFromWell(playerid)
{
	new slot = Yard_FindStartedSkin(playerid);

	if (slot != -1)
	{
		return Inventory_RefillSlot(playerid,slot);
	}

	Needs_Feed(playerid,NEED_THIRST,YARD_WELL_DRINK);
	return true;
}

stock bool:Yard_IsAtRiver(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != 0)
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	for (new i = 0;i < sizeof(g_FishingWaterCells);i++)
	{
		if (floatabs(g_FishingWaterCells[i][E_FISHING_WATER_X] - x) < YARD_RIVER_REACH && floatabs(g_FishingWaterCells[i][E_FISHING_WATER_Y] - y) < YARD_RIVER_REACH && floatabs(g_FishingWaterCells[i][E_FISHING_WATER_Z] - z) < 2.5)
		{
			return true;
		}
	}

	return false;
}

stock bool:Yard_Wash(playerid,node)
{
	if (node >= 0)
	{
		if (g_YardDefs[node][E_YARD_DEF_KIND] != YARD_KIND_WASHTUB || s_YardLevel[node] <= 0)
		{
			return false;
		}

		Yard_SetLevel(node,s_YardLevel[node] - 1);
		Hygiene_Wash(playerid,HYGIENE_MAX);
		return true;
	}

    if (Seasons_IsWaterFrozen())
    {
        return false;
    }

	Hygiene_Wash(playerid,YARD_RIVER_WASH);
	return true;
}

static Yard_ClearPrompt(playerid)
{
	if (s_YardInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_YardInfobox[playerid]);
	}

	s_YardPrompt[playerid] = YARD_PROMPT_NONE;
	s_YardPromptNode[playerid] = -1;
	s_YardPromptLevel[playerid] = 0;
	s_YardInfobox[playerid] = 0;
}

static Yard_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || s_YardBusy[playerid] || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		Yard_ClearPrompt(playerid);
		return;
	}

	new node = Yard_FindNodeNear(playerid), kind = YARD_PROMPT_NONE, title[28], text[128];

	if (node != -1)
	{
		kind = YARD_PROMPT_NODE;

		switch (g_YardDefs[node][E_YARD_DEF_KIND])
		{
			case YARD_KIND_WASHTUB:
			{
				strcopy(title,"Washing trough");
				strcopy(text,s_YardLevel[node] > 0 ? ("Press ~y~Y~w~ to wash.") : ("The trough is empty. It fills up again over the hours."));
			}
			case YARD_KIND_SPRING:
			{
				strcopy(title,"Holy spring");
				strcopy(text,s_YardLevel[node] > 0 ? ("Press ~y~Y~w~ to drink the clean water.") : ("The spring is drawn down to a puddle. It fills again by and by."));
			}
			default:
			{
				strcopy(title,"Holy water");
				strcopy(text,"Press ~y~Y~w~ to dip your fingers and cross yourself.");
			}
		}
	}
	else if (Yard_FindWellNear(playerid) != -1 && Trader_FindNear(playerid,Yard_GetWellDistance(playerid)) == -1)
	{
		kind = YARD_PROMPT_WELL;
		node = Yard_FindWellNear(playerid);
		strcopy(title,"Well");
		strcopy(text,Yard_FindStartedSkin(playerid) != -1 ? ("Press ~y~Y~w~ to fill your water skin from the well.") : ("Press ~y~Y~w~ to drink from the well."));
	}
	else if (Hygiene_GetDirt(playerid) >= HYGIENE_GRIMY && Yard_IsAtRiver(playerid))
	{
		kind = YARD_PROMPT_RIVER;
		strcopy(title,"A body of water");
		strcopy(text,"Press ~y~Y~w~ to wash in the cold water.");
	}

	if (kind == YARD_PROMPT_NONE)
	{
		Yard_ClearPrompt(playerid);
		return;
	}

	new level = kind == YARD_PROMPT_WELL ? (Yard_FindStartedSkin(playerid) != -1 ? 1 : 0) : (node == -1 ? 0 : s_YardLevel[node]);

	if (kind == s_YardPrompt[playerid] && node == s_YardPromptNode[playerid] && level == s_YardPromptLevel[playerid] && Infobox_IsShown(playerid,s_YardInfobox[playerid]))
	{
		return;
	}

	Yard_ClearPrompt(playerid);
	s_YardPrompt[playerid] = kind;
	s_YardPromptNode[playerid] = node;
	s_YardPromptLevel[playerid] = level;
	s_YardInfobox[playerid] = Infobox_ShowPrompt(playerid,s_YardInfobox[playerid],title,text,3);
}

static Yard_Use(playerid,kind,node)
{
	if (kind == YARD_PROMPT_WELL)
	{
		new bool:isFilling = Yard_FindStartedSkin(playerid) != -1;

		if (!Yard_DrawFromWell(playerid))
		{
			return;
		}

		ApplyAnimation(playerid,"BAR","dnk_stndM_loop",4.1,false,false,false,false,0,SYNC_ALL);
		Chat_Speak(playerid,CHAT_ME,isFilling ? ("lowers a bucket into the well and fills their water skin.") : ("draws water from the well and drinks."));
		Gui_Notify(playerid,isFilling ? ("You fill your water skin from the well.") : ("You drink from the well."));
		return;
	}

	if (kind == YARD_PROMPT_RIVER)
	{
        if (Seasons_IsWaterFrozen())
        {
            Gui_Notify(playerid,"The water is frozen. You cannot wash through the ice.");
            return;
        }

		s_YardBusy[playerid] = true;
		ApplyAnimation(playerid,"BOMBER","BOM_Plant_Loop",4.1,true,false,false,false,0,SYNC_ALL);
		Chat_Speak(playerid,CHAT_ME,"kneels at the water and scrubs.");
		SetTimerEx("Yard_WashDone",YARD_WASH_MS,false,"dd",playerid,-1);
		return;
	}

	switch (g_YardDefs[node][E_YARD_DEF_KIND])
	{
		case YARD_KIND_WASHTUB:
		{
			if (s_YardLevel[node] <= 0)
			{
				return;
			}

			s_YardBusy[playerid] = true;
			ApplyAnimation(playerid,"INT_HOUSE","wash_up",4.1,true,false,false,false,0,SYNC_ALL);
			Chat_Speak(playerid,CHAT_ME,"strips to the waist and washes at the trough.");
			SetTimerEx("Yard_WashDone",YARD_WASH_MS,false,"dd",playerid,node);
		}
		case YARD_KIND_SPRING:
		{
			if (s_YardLevel[node] <= 0)
			{
				return;
			}

			Yard_SetLevel(node,0);
			Needs_Feed(playerid,NEED_THIRST,YARD_SPRING_DRINK);
			ApplyAnimation(playerid,"BAR","dnk_stndM_loop",4.1,false,false,false,false,0,SYNC_ALL);
			Chat_Speak(playerid,CHAT_ME,"cups water from the spring and drinks.");
		}
		case YARD_KIND_STOUP:
		{
			ApplyAnimation(playerid,"CAMERA","CAMCRCH_IDLELOOP",4.1,false,false,false,false,1500,SYNC_ALL);
			Chat_Speak(playerid,CHAT_ME,"dips their fingers in the holy water and crosses themselves.");
		}
	}
}

Timer_Declare(Yard_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Yard_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward Yard_WashDone(playerid,node);

public Yard_WashDone(playerid,node)
{
	if (!IsPlayerConnected(playerid) || !s_YardBusy[playerid])
	{
		return 1;
	}

	s_YardBusy[playerid] = false;
	ClearAnimations(playerid,SYNC_ALL);

	if (Yard_Wash(playerid,node))
	{
		Gui_Notify(playerid,node >= 0 ? ("You scrub yourself clean in the cold water.") : ("You wash off the worst of the dirt. A washtub would do better."));
	}

	return 1;
}

forward bool:Yard_PromptContext(playerid);

public bool:Yard_PromptContext(playerid)
{
	return s_YardPrompt[playerid] != YARD_PROMPT_NONE;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_YardPrompt[playerid] = YARD_PROMPT_NONE;
	s_YardPromptNode[playerid] = -1;
	s_YardPromptLevel[playerid] = 0;
	s_YardInfobox[playerid] = 0;
	s_YardBusy[playerid] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_YardPrompt[playerid] == YARD_PROMPT_NONE || Infobox_IsPromptBlocked(playerid,s_YardInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new kind = s_YardPrompt[playerid], node = s_YardPromptNode[playerid];
	Yard_ClearPrompt(playerid);
	Yard_Use(playerid,kind,node);
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour

	for (new node = 0;node < YARD_SEED_NODES;node++)
	{
		if (g_YardDefs[node][E_YARD_DEF_KIND] == YARD_KIND_WASHTUB || g_YardDefs[node][E_YARD_DEF_KIND] == YARD_KIND_SPRING)
		{
			Yard_SetLevel(node,s_YardLevel[node] + 1);
		}
	}
}
