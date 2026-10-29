static s_LightPrompt[MAX_PLAYERS] = {-1, ...};
static s_LightPromptInfobox[MAX_PLAYERS];
static s_LightPromptSeconds[MAX_PLAYERS];

static Light_ClearPrompt(playerid)
{
	if (s_LightPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_LightPromptInfobox[playerid]);
	}

	s_LightPrompt[playerid] = -1;
	s_LightPromptInfobox[playerid] = 0;
	s_LightPromptSeconds[playerid] = -1;
}

static Light_FindFuel(playerid,kind)
{
	if (kind == LIGHT_SOURCE_BRAZIER && Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CHARCOAL) > 0)
	{
		return ITEM_CHARCOAL;
	}

	if (Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_FIREWOOD) > 0)
	{
		return ITEM_FIREWOOD;
	}

	return -1;
}

stock Light_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || Wounds_IsDown(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || Infobox_FindTarget(playerid) != -1)
	{
		Light_ClearPrompt(playerid);
		return;
	}

	new source = Light_FindSourceForPlayer(playerid,LIGHT_REACH);

	if (source == -1 || (Light_GetSourceKind(source) != LIGHT_SOURCE_POLE_TORCH && !g_LightKindDefs[Light_GetSourceKind(source)][E_LIGHT_KIND_DEF_IS_FUELLED]) || (Light_GetSourceKind(source) == LIGHT_SOURCE_POLE_TORCH && !Light_IsSourceLit(source)))
	{
		Light_ClearPrompt(playerid);
		return;
	}

	new minutes = Light_GetSourceSeconds(source) / 60;

	if (source == s_LightPrompt[playerid] && minutes == s_LightPromptSeconds[playerid] && Infobox_IsShown(playerid,s_LightPromptInfobox[playerid]))
	{
		return;
	}

	new kind = Light_GetSourceKind(source), name[LIGHT_NAME_LEN], text[160];
	Light_GetKindName(kind,name);

	if (kind == LIGHT_SOURCE_POLE_TORCH)
	{
		format(text,sizeof(text),"Press ~y~Y~w~ to take the torch out of the ground. It has about %d minutes left.",max(minutes,1));
	}
	else if (Light_IsSourceLit(source))
	{
		format(text,sizeof(text),"It burns for about %d more minutes.~n~Press ~y~Y~w~ to add %s.",max(minutes,1),kind == LIGHT_SOURCE_BRAZIER ? ("charcoal or firewood") : ("firewood"));
	}
	else
	{
		format(text,sizeof(text),"It's cold.~n~Press ~y~Y~w~ to light it with %s. You need a flame or flint.",kind == LIGHT_SOURCE_BRAZIER ? ("charcoal or firewood") : ("firewood"));
	}

	s_LightPrompt[playerid] = source;
	s_LightPromptSeconds[playerid] = minutes;
	s_LightPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_LightPromptInfobox[playerid],name,text,3);
}

stock bool:Light_UsePrompt(playerid)
{
	new source = s_LightPrompt[playerid];

	if (!Light_IsValidSource(source))
	{
		return false;
	}

	new kind = Light_GetSourceKind(source);

	if (kind == LIGHT_SOURCE_POLE_TORCH)
	{
		Light_ClearPrompt(playerid);
		return Light_TakePoleTorch(playerid,source);
	}

	new fuel = Light_FindFuel(playerid,kind);

	if (fuel == -1)
	{
		Gui_Notify(playerid,kind == LIGHT_SOURCE_BRAZIER ? ("You have no charcoal or firewood.") : ("You have no firewood."));
		return false;
	}

	if (!Light_IsSourceLit(source) && !Light_CanKindle(playerid))
	{
		Gui_Notify(playerid,"You need a flame to light it: flint in your bag, a fire, or someone's torch close by.");
		return false;
	}

	if (Light_GetSourceSeconds(source) + Light_GetFuelSeconds(kind,fuel) > LIGHT_FUEL_CAP_SECONDS)
	{
		Gui_Notify(playerid,"It's as full as it will go.");
		return false;
	}

	new bool:wasLit = Light_IsSourceLit(source);
	Inventory_Take(playerid,ITEM_KIND_MATERIAL,fuel,1);
	Light_SetSourceSeconds(source,Light_GetSourceSeconds(source) + Light_GetFuelSeconds(kind,fuel));
	Anim_Apply(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0);
	Gui_Notify(playerid,wasLit ? ("You feed the fire.") : ("You get the fire going."));
	s_LightPromptSeconds[playerid] = -1;
	return true;
}

Timer_Declare(Light_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Light_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward bool:Light_PromptContext(playerid);

public bool:Light_PromptContext(playerid)
{
	return s_LightPrompt[playerid] != -1 && !Combat_IsInMode(playerid) && Infobox_FindTarget(playerid) == -1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LightPrompt[playerid] = -1;
	s_LightPromptInfobox[playerid] = 0;
	s_LightPromptSeconds[playerid] = -1;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_LightPrompt[playerid] = -1;
	s_LightPromptInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && s_LightPrompt[playerid] != -1 && Infobox_FindTarget(playerid) == -1 && !Infobox_IsPromptBlocked(playerid,s_LightPromptInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		Light_UsePrompt(playerid);
	}
}
