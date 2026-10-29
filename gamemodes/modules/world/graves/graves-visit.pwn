enum
{
	GRAVES_PROMPT_NONE,
	GRAVES_PROMPT_GRAVE,
	GRAVES_PROMPT_NICHE,
	GRAVES_PROMPT_DOOR,
	GRAVES_PROMPT_EXIT,
}

static s_GravesPromptKind[MAX_PLAYERS];
static s_GravesPromptTarget[MAX_PLAYERS];
static s_GravesPromptInfobox[MAX_PLAYERS];

static Graves_ClearPrompt(playerid)
{
	if (s_GravesPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_GravesPromptInfobox[playerid]);
	}

	s_GravesPromptKind[playerid] = GRAVES_PROMPT_NONE;
	s_GravesPromptTarget[playerid] = -1;
	s_GravesPromptInfobox[playerid] = 0;
}

static Graves_SetPrompt(playerid,kind,target,const title[],const text[],rows)
{
	if (s_GravesPromptKind[playerid] == kind && s_GravesPromptTarget[playerid] == target && Infobox_IsShown(playerid,s_GravesPromptInfobox[playerid]))
	{
		return;
	}

	s_GravesPromptKind[playerid] = kind;
	s_GravesPromptTarget[playerid] = target;
	s_GravesPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_GravesPromptInfobox[playerid],title,text,rows);
}

stock Graves_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || Wounds_IsDown(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Graves_ClearPrompt(playerid);
		return;
	}

	new target, text[256];

	if ((target = Crypt_FindExitNear(playerid)) != -1)
	{
		Graves_SetPrompt(playerid,GRAVES_PROMPT_EXIT,target,"Crypt","Press ~y~Y~w~ to climb the stairs out.",1);
		return;
	}

	if ((target = Crypt_FindDoorNear(playerid)) != -1)
	{
		Graves_SetPrompt(playerid,GRAVES_PROMPT_DOOR,target,"Crypt","Press ~y~Y~w~ to go down into the crypt.",1);
		return;
	}

	if ((target = Crypt_FindNicheNear(playerid,CRYPT_SLAB_REACH)) != -1)
	{
		Crypt_FormatInscription(target,text);
		strcat(text,"~n~~n~Press ~y~Y~w~ to pay your respects.");
		Graves_SetPrompt(playerid,GRAVES_PROMPT_NICHE,target,"Niche",text,5);
		return;
	}

	if ((target = Grave_FindForPlayer(playerid,GRAVES_REACH,true)) != -1)
	{
		Grave_FormatInscription(target,text);
		strcat(text,"~n~~n~Press ~y~Y~w~ to pay your respects.");
		Graves_SetPrompt(playerid,GRAVES_PROMPT_GRAVE,target,"Grave",text,5);
		return;
	}

	Graves_ClearPrompt(playerid);
}

static bool:Graves_LightCandleAt(playerid,kind,target)
{
	new candle = Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE_WAX) > 0 ? ITEM_CANDLE_WAX : ITEM_CANDLE;

	if (Inventory_Count(playerid,ITEM_KIND_MATERIAL,candle) == 0)
	{
		Gui_Notify(playerid,"You have no candle.");
		return false;
	}

	if (!Light_CanKindle(playerid))
	{
		Gui_Notify(playerid,"You need a flame to light it: flint in your bag, a fire, or someone's torch close by.");
		return false;
	}

	new bool:isPlaced;

	if (kind == GRAVES_PROMPT_GRAVE)
	{
		isPlaced = Grave_LightCandle(target,candle == ITEM_CANDLE_WAX);
	}
	else
	{
		new Float:x, Float:y, Float:z, Float:rz, world;
		Crypt_GetNicheWorldPos(target,x,y,z,rz,world);
		isPlaced = Light_PlaceCandle(candle == ITEM_CANDLE_WAX,x + 0.12 * floatsin(rz,degrees),y - 0.12 * floatcos(rz,degrees),z - 0.02,rz,world,CRYPT_INTERIOR) != -1;
	}

	if (!isPlaced)
	{
		Gui_Notify(playerid,"There's no room for another candle right now.");
		return false;
	}

	Inventory_Take(playerid,ITEM_KIND_MATERIAL,candle,1);
	Gui_Notify(playerid,"You light a candle for them.");
	return true;
}

stock Graves_OpenRespects(playerid,kind,target)
{
	new epoch = Gui_BeginFlow(playerid), name[GRAVES_NAME_LEN];

	if (kind == GRAVES_PROMPT_GRAVE)
	{
		Grave_GetName(target,name);
	}
	else
	{
		Crypt_GetNicheName(target,name);
	}

	for (;;)
	{
		new Float:x, Float:y, Float:width, rows = 0, title[GRAVES_NAME_LEN + 4];
		strcopy(title,name);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GRAVES_PANEL_WIDTH,3.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,"Light a candle",GRAVES_PICK_CANDLE);

		if (kind == GRAVES_PROMPT_GRAVE)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,"Lay flowers",GRAVES_PICK_FLOWERS,Grave_HasLaidFlowers(target,Character_GetId(playerid)) ? KIT_COLOUR_MUTED : KIT_COLOUR_TEXT);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,"Say a prayer for them",GRAVES_PICK_PRAY);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 3.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case GRAVES_PICK_CANDLE:
			{
				Kit_Close(playerid);
				Graves_LightCandleAt(playerid,kind,target);
				return;
			}
			case GRAVES_PICK_FLOWERS:
			{
				if (!Grave_LayFlowers(target,Character_GetId(playerid)))
				{
					Gui_Notify(playerid,"You've already laid flowers here today.");
					continue;
				}

				Kit_Close(playerid);
				Anim_Apply(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0);
				Gui_Notify(playerid,"You lay a posy of wildflowers on the grave.");
				return;
			}
			case GRAVES_PICK_PRAY:
			{
				new line[GRAVES_NAME_LEN + 32];
				Kit_Close(playerid);
				format(line,sizeof(line),"kneels and prays for %s.",name);
				Chat_Speak(playerid,CHAT_ME,line);
				ApplyAnimation(playerid,"CAMERA","CAMCRCH_IDLELOOP",4.1,false,false,false,false,4000,SYNC_ALL);
				return;
			}
		}
	}
}

Timer_Declare(Graves_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Graves_UpdatePrompt(playerid);
		}
	}

	return 1;
}

Timer_Declare(Graves_Tick)
{
	Grave_SettleTick();
	Funeral_Tick();
	return 1;
}

forward Graves_RespectsDeferred(playerid,kind,target);

public Graves_RespectsDeferred(playerid,kind,target)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Graves_OpenRespects(playerid,kind,target);
	}

	return 1;
}

forward bool:Graves_PromptContext(playerid);

public bool:Graves_PromptContext(playerid)
{
	return s_GravesPromptKind[playerid] != GRAVES_PROMPT_NONE && !Combat_IsInMode(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_GravesPromptKind[playerid] = GRAVES_PROMPT_NONE;
	s_GravesPromptTarget[playerid] = -1;
	s_GravesPromptInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_GravesPromptKind[playerid] == GRAVES_PROMPT_NONE || Infobox_IsPromptBlocked(playerid,s_GravesPromptInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new kind = s_GravesPromptKind[playerid], target = s_GravesPromptTarget[playerid];
	Graves_ClearPrompt(playerid);

	switch (kind)
	{
		case GRAVES_PROMPT_DOOR: Crypt_Enter(playerid,target);
		case GRAVES_PROMPT_EXIT: Crypt_Leave(playerid,target);
		case GRAVES_PROMPT_GRAVE, GRAVES_PROMPT_NICHE: SetTimerEx("Graves_RespectsDeferred",0,false,"ddd",playerid,kind,target);
	}
}
