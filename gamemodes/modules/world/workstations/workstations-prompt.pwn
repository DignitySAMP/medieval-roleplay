#define WORK_PROMPT_MS (400)
#define WORK_STATION_RANGE (2.5)
#define WORK_NODE_RANGE (2.5)

static s_WorkPromptType[MAX_PLAYERS];
static s_WorkPromptTarget[MAX_PLAYERS];
static s_WorkPromptInfobox[MAX_PLAYERS];
static bool:s_WorkPromptForeign[MAX_PLAYERS];

stock Work_GetPromptTarget(playerid,&targetType)
{
	targetType = s_WorkPromptType[playerid];
	return s_WorkPromptTarget[playerid];
}

static Work_ClearPrompt(playerid)
{
	if (s_WorkPromptType[playerid] == WORK_TARGET_NONE)
	{
		return;
	}

	s_WorkPromptType[playerid] = WORK_TARGET_NONE;
	s_WorkPromptTarget[playerid] = -1;
	s_WorkPromptForeign[playerid] = false;
	if (s_WorkPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_WorkPromptInfobox[playerid]);
	}

	s_WorkPromptInfobox[playerid] = 0;
}

stock Work_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Work_IsWorking(playerid) || Gui_IsBusy(playerid) || Combat_IsInMode(playerid) || Mount_IsRiding(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		Work_ClearPrompt(playerid);
		return;
	}

	new Float:x, Float:y, Float:z, world = GetPlayerVirtualWorld(playerid), targetType = WORK_TARGET_NONE, target = -1;
	GetPlayerPos(playerid,x,y,z);

	new Float:distance, stationid = Work_FindNearestStation(x,y,z,world,WORK_STATION_RANGE,distance,true);

	if (stationid != -1)
	{
		targetType = WORK_TARGET_STATION;
		target = stationid;
	}
	else
	{
		new nodeid = Work_FindNearestNode(x,y,z,world,WORK_NODE_RANGE);

		if (nodeid == -1)
		{
			nodeid = Work_FindReachNode(playerid,x,y,z,world);
		}

		if (nodeid != -1 && Work_CountRecipesForKind(g_WorkNodes[nodeid][E_WORK_NODE_KIND]) > 0)
		{
			targetType = WORK_TARGET_NODE;
			target = nodeid;
		}
	}

	if (targetType == WORK_TARGET_NONE)
	{
		Work_ClearPrompt(playerid);
		return;
	}

	if (targetType == s_WorkPromptType[playerid] && target == s_WorkPromptTarget[playerid] && Infobox_IsShown(playerid,s_WorkPromptInfobox[playerid]) && s_WorkPromptForeign[playerid] == (targetType == WORK_TARGET_STATION && !Work_CanUseStation(playerid,target)))
	{
		return;
	}

	new kind = Work_GetTargetKind(targetType,target), name[WORK_KIND_NAME_LEN], verb[WORK_KIND_VERB_LEN], text[96], bool:isForeign = targetType == WORK_TARGET_STATION && !Work_CanUseStation(playerid,target);
	Work_GetKindVerb(kind,verb);

	if (targetType == WORK_TARGET_NODE)
	{
		Work_GetNodeName(playerid,target,name);
	}
	else
	{
		Work_GetKindName(kind,name);
	}

	if (isForeign)
	{
		strcopy(text,"This station belongs to someone else. Ask the owner to invite you if you want to use it.");
	}
	else if (targetType == WORK_TARGET_STATION && Work_GetStationOwner(target) == Character_GetId(playerid))
	{
		new remaining[16];
		Work_FormatRemaining(Work_GetStationRemaining(target),remaining);
		format(text,sizeof(text),Work_IsFireKind(kind) ? ("Press Y to %s. Fuel for %s.") : ("Press Y to %s. Kept up for %s."),verb,remaining);
	}
	else
	{
		format(text,sizeof(text),"Press Y to %s.",verb);
	}

	s_WorkPromptForeign[playerid] = isForeign;
	s_WorkPromptType[playerid] = targetType;
	s_WorkPromptTarget[playerid] = target;
	s_WorkPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_WorkPromptInfobox[playerid],name,text,1);
}

stock Work_OpenRecipes(playerid,targetType,target)
{

	new kind = Work_GetTargetKind(targetType,target), recipes[WORK_MENU_MAX], count = Work_GetRecipesForKind(kind,recipes);

	if (count == 0)
	{
		Gui_Notify(playerid,"There's nothing you can make here yet.");
		return;
	}

	if (count == 1)
	{
		Work_Start(playerid,targetType,target,recipes[0]);
		return;
	}

	new epoch = Gui_BeginFlow(playerid), title[WORK_KIND_NAME_LEN], name[RECIPE_NAME_LEN], detail[32], reason[WORK_REASON_LEN], Float:x, Float:y, Float:width;
	Work_GetKindName(kind,title);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new bool:canStart = Work_CheckStart(playerid,targetType,target,recipes[i],reason), level = Recipe_GetLevel(recipes[i]);
		Recipe_GetName(recipes[i],name);
		if (level > Work_GetLevel(playerid,Recipe_GetTrade(recipes[i])))
		{
			format(detail,sizeof(detail),"level %d",level);
		}
		else
		{
			strcopy(detail,canStart ? ("") : ("missing things"));
		}

		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,recipes[i],canStart ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,detail,KIT_COLOUR_MUTED,0.55);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return;
	}

	for (new i = 0;i < count;i++)
	{
		if (recipes[i] == pick)
		{
			Work_Start(playerid,targetType,target,pick);
			return;
		}
	}
}

Timer_Declare(Work_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Work_UpdatePrompt(playerid);
		}
	}
}

forward Work_OpenRecipesDeferred(playerid,targetType,target);

public Work_OpenRecipesDeferred(playerid,targetType,target)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid))
	{
		return;
	}

	if (targetType == WORK_TARGET_STATION && Work_IsValidStation(target) && Work_GetStationOwner(target) > 0 && Work_GetStationOwner(target) == Character_GetId(playerid))
	{
		Work_OpenOwnerPanel(playerid,target);
		return;
	}

	Work_OpenRecipes(playerid,targetType,target);
}

forward bool:Work_KeyContext(playerid);

public bool:Work_KeyContext(playerid)
{
	return s_WorkPromptType[playerid] != WORK_TARGET_NONE && !s_WorkPromptForeign[playerid] && !Combat_IsInMode(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_WorkPromptType[playerid] = WORK_TARGET_NONE;
	s_WorkPromptTarget[playerid] = -1;
	s_WorkPromptInfobox[playerid] = 0;
	s_WorkPromptForeign[playerid] = false;
}

hook Combat_OnModeChanged(playerid,enabled)
{
	#pragma unused enabled
	Work_UpdatePrompt(playerid);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_WorkPromptType[playerid] == WORK_TARGET_NONE || s_WorkPromptForeign[playerid] || Infobox_IsPromptBlocked(playerid,s_WorkPromptInfobox[playerid]) || Gui_IsBusy(playerid) || Work_IsWorking(playerid) || Combat_IsInMode(playerid))
	{
		return;
	}

	SetTimerEx("Work_OpenRecipesDeferred",0,false,"ddd",playerid,s_WorkPromptType[playerid],s_WorkPromptTarget[playerid]);
}
