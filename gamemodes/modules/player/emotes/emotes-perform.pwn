#define PERFORM_TIP_RANGE (8.0)
#define PERFORM_INN_TICK_MS (120000)
#define PERFORM_INN_PURSE (1)
#define PERFORM_INN_DAY_CAP (20)
#define PERFORM_PROP_SLOT (ATTACH_SLOT_MEAL)

enum E_PERFORM
{
	E_PF_INSTRUMENT,
	E_PF_STARTED,
	E_PF_INN_AT,
	E_PF_INN_TODAY,
	E_PF_INN_DAY,
	E_PF_TIPS,
}

static s_Perform[MAX_PLAYERS][E_PERFORM];
static s_PerformPrompt[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};
static s_PerformInfobox[MAX_PLAYERS];
static bool:s_PerformProp[MAX_PLAYERS];

stock Perform_GetInstrument(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Perform[playerid][E_PF_INSTRUMENT] : 0;
}

stock bool:Perform_IsPlaying(playerid)
{
	return Perform_GetInstrument(playerid) != 0;
}

stock Perform_EmoteFor(item)
{
	new name[EMOTE_NAME_LEN];

	switch (item)
	{
		case ITEM_LUTE: name = "Play the lute";
		case ITEM_FLUTE: name = "Play the flute";
		case ITEM_DRUM: name = "Beat the drum";
		default: return -1;
	}

	for (new emote = 0;emote < sizeof(g_EmoteDefs);emote++)
	{
		if (!strcmp(g_EmoteDefs[emote][E_ED_NAME],name))
		{
			return emote;
		}
	}

	return -1;
}

stock Perform_InstrumentOf(emote)
{
	new items[3] = {ITEM_LUTE, ITEM_FLUTE, ITEM_DRUM};

	for (new i = 0;i < sizeof(items);i++)
	{
		if (emote != -1 && Perform_EmoteFor(items[i]) == emote)
		{
			return items[i];
		}
	}

	return 0;
}

stock Perform_PropPreset(item)
{
	switch (item)
	{
		case ITEM_LUTE: return Attach_FindPreset("lute");
		case ITEM_FLUTE: return Attach_FindPreset("flute");
		case ITEM_DRUM: return Attach_FindPreset("drum");
	}

	return -1;
}

stock Perform_LendAnimsToPresets()
{
	new items[3] = {ITEM_LUTE, ITEM_FLUTE, ITEM_DRUM};

	for (new i = 0;i < sizeof(items);i++)
	{
		new emote = Perform_EmoteFor(items[i]);

		if (emote != -1)
		{
			new step = g_EmoteDefs[emote][E_ED_FIRST] + g_EmoteDefs[emote][E_ED_STEPS] - 1;
			Attach_SetPresetAnim(Perform_PropPreset(items[i]),g_EmoteSteps[step][E_ES_LIB],g_EmoteSteps[step][E_ES_ANIM]);
		}
	}
}

stock bool:Perform_HasProp(playerid)
{
	return Util_IsValidPlayer(playerid) && s_PerformProp[playerid];
}

static Perform_HideProp(playerid)
{
	if (!s_PerformProp[playerid])
	{
		return;
	}

	s_PerformProp[playerid] = false;
	RemovePlayerAttachedObject(playerid,PERFORM_PROP_SLOT);
}

static Perform_ShowProp(playerid,item)
{
	new preset = Perform_PropPreset(item), model, bone, Float:pose[9];
	Perform_HideProp(playerid);

	if (preset == -1 || IsPlayerAttachedObjectSlotUsed(playerid,PERFORM_PROP_SLOT))
	{
		return;
	}

	Attach_GetPreset(preset,model,bone,pose);
	SetPlayerAttachedObject(playerid,PERFORM_PROP_SLOT,model,bone,pose[0],pose[1],pose[2],pose[3],pose[4],pose[5],pose[6],pose[7],pose[8]);
	s_PerformProp[playerid] = true;
}

stock bool:Perform_Start(playerid,item)
{
	new emote = Perform_EmoteFor(item);

	if (emote == -1 || !Emotes_Play(playerid,emote))
	{
		return false;
	}

	s_Perform[playerid][E_PF_INSTRUMENT] = item;
	s_Perform[playerid][E_PF_STARTED] = gettime();
	s_Perform[playerid][E_PF_INN_AT] = GetTickCount();
	s_Perform[playerid][E_PF_TIPS] = 0;
	Chat_Speak(playerid,CHAT_ME,item == ITEM_DRUM ? ("beats out a rhythm on the drum.") : (item == ITEM_FLUTE ? ("plays a tune on the flute.") : ("strikes up a tune on the lute.")));
	pawn_call_public("Perform_OnStart","dd",playerid,item);
	return true;
}

stock Perform_Stop(playerid)
{
	if (!Perform_IsPlaying(playerid))
	{
		return;
	}

	new tips = s_Perform[playerid][E_PF_TIPS];
	s_Perform[playerid][E_PF_INSTRUMENT] = 0;

	if (tips > 0)
	{
		new money[24];
		Economy_Format(tips,money);
		Gui_Notify(playerid,sprintf("You put the instrument away. The playing earned you %s.",money));
	}

	pawn_call_public("Perform_OnStop","dd",playerid,tips);
}

stock bool:Perform_Tip(tipper,musician,amount)
{
	if (!Perform_IsPlaying(musician) || tipper == musician || amount <= 0)
	{
		return false;
	}

	if (Economy_Pay(tipper,amount,INVALID_CONTAINER_ID,"tip") != PAY_OK)
	{
		return false;
	}

	Economy_GiveOrClaim(musician,Character_GetId(musician),amount,"tip");
	s_Perform[musician][E_PF_TIPS] += amount;
	new name[MAX_PLAYER_NAME], money[24];
	Character_GetName(tipper,name);
	Economy_Format(amount,money);
	Gui_Notify(musician,sprintf("%s tosses you %s.",name,money));
	return true;
}

stock Perform_InnTick(playerid)
{
	new house = Houses_GetInside(playerid), day = Ailment_CurrentTurn();

	if (house == -1 || !Houses_IsTavern(house))
	{
		return 0;
	}

	if (s_Perform[playerid][E_PF_INN_DAY] != day)
	{
		s_Perform[playerid][E_PF_INN_DAY] = day;
		s_Perform[playerid][E_PF_INN_TODAY] = 0;
	}

	if (s_Perform[playerid][E_PF_INN_TODAY] >= PERFORM_INN_DAY_CAP)
	{
		return 0;
	}

	s_Perform[playerid][E_PF_INN_TODAY] += PERFORM_INN_PURSE;
	s_Perform[playerid][E_PF_TIPS] += PERFORM_INN_PURSE;
	Economy_GiveOrClaim(playerid,Character_GetId(playerid),PERFORM_INN_PURSE,"inn purse");
	pawn_call_public("Perform_OnInnPlay","dd",playerid,house);
	return PERFORM_INN_PURSE;
}

static Perform_ClearPrompt(playerid)
{
	if (s_PerformInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_PerformInfobox[playerid]);
	}

	s_PerformPrompt[playerid] = INVALID_PLAYER_ID;
	s_PerformInfobox[playerid] = 0;
}

Timer_Declare(Perform_Tick)
{
	new tick = GetTickCount();

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		if (Perform_IsPlaying(playerid))
		{
			if (!Emotes_IsPlaying(playerid))
			{
				Perform_Stop(playerid);
			}
			else if (tick - s_Perform[playerid][E_PF_INN_AT] >= PERFORM_INN_TICK_MS)
			{
				s_Perform[playerid][E_PF_INN_AT] = tick;
				Perform_InnTick(playerid);
			}
		}

		new best = INVALID_PLAYER_ID;

		if (Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Perform_IsPlaying(playerid))
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid,x,y,z);

			foreach (new other : Player)
			{
				if (other != playerid && Perform_IsPlaying(other) && IsPlayerInRangeOfPoint(other,PERFORM_TIP_RANGE,x,y,z))
				{
					best = other;
					break;
				}
			}
		}

		if (best == INVALID_PLAYER_ID)
		{
			Perform_ClearPrompt(playerid);
		}
		else if (best != s_PerformPrompt[playerid] || !Infobox_IsShown(playerid,s_PerformInfobox[playerid]))
		{
			s_PerformPrompt[playerid] = best;
			s_PerformInfobox[playerid] = Infobox_ShowPrompt(playerid,s_PerformInfobox[playerid],"A musician","Press ~y~Y~w~ to tip them.",3);
		}
	}

	return 1;
}

forward Perform_OnStart(playerid,item);

public Perform_OnStart(playerid,item)
{
	return 1;
}

forward Perform_OnStop(playerid,tips);

public Perform_OnStop(playerid,tips)
{
	return 1;
}

forward Perform_OnInnPlay(playerid,house);

public Perform_OnInnPlay(playerid,house)
{
	return 1;
}

forward bool:Perform_PromptContext(playerid);

public bool:Perform_PromptContext(playerid)
{
	return s_PerformPrompt[playerid] != INVALID_PLAYER_ID;
}

forward Perform_TipDeferred(playerid,musician);

public Perform_TipDeferred(playerid,musician)
{
	if (!IsPlayerConnected(playerid) || !Perform_IsPlaying(musician))
	{
		return 1;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, amounts[3] = {1, 2, 5};
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Tip the musician");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,220.0,KIT_ROW * 3.0 + 6.0 + KIT_ROW + 12.0,"Tip the musician",x,y,width);

	for (new i = 0;i < 3;i++)
	{
		new money[24];
		Economy_Format(amounts[i],money);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,money,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 3.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick >= 0 && pick < 3 && !Perform_Tip(playerid,musician,amounts[pick]))
	{
		Gui_Notify(playerid,"You can't spare that.");
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Perform[playerid][E_PF_INSTRUMENT] = 0;
	s_Perform[playerid][E_PF_INN_DAY] = -1;
	s_Perform[playerid][E_PF_INN_TODAY] = 0;
	s_PerformPrompt[playerid] = INVALID_PLAYER_ID;
	s_PerformInfobox[playerid] = 0;
	s_PerformProp[playerid] = false;
}

hook Emotes_OnPlay(playerid,emote)
{
	new item = Perform_InstrumentOf(emote);

	if (item != 0 && Inventory_HasItem(playerid,item))
	{
		Perform_ShowProp(playerid,item);
	}
	else
	{
		Perform_HideProp(playerid);
	}
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars, index, kind

	if (param == ITEM_LUTE || param == ITEM_FLUTE || param == ITEM_DRUM)
	{
		Inventory_CloseBagAfterUse(playerid);

		if (!Perform_Start(playerid,param))
		{
			Gui_Notify(playerid,"You can't play here and now.");
		}
	}
}

hook Emotes_OnStop(playerid)
{
	Perform_HideProp(playerid);
	Perform_Stop(playerid);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !(newkeys & KEY_WALK) && s_PerformPrompt[playerid] != INVALID_PLAYER_ID && !Infobox_IsPromptBlocked(playerid,s_PerformInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		new musician = s_PerformPrompt[playerid];
		Perform_ClearPrompt(playerid);
		SetTimerEx("Perform_TipDeferred",0,false,"dd",playerid,musician);
	}
}
