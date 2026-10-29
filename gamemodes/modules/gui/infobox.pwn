#define INFOBOX_WIDTH (200.0)
#define INFOBOX_ROWS (3)
#define INFOBOX_X (640.0 - 6.0 - INFOBOX_WIDTH)
#define INFOBOX_Y (112.0)
#define INFOBOX_REFUSED (-1)

#define INFOBOX_TARGET_MAX (4)
#define INFOBOX_TARGET_PRIORITY (KEYS_PRIO_MENU + 2)

enum E_INFOBOX_TARGET
{
    E_INFOBOX_TARGET_DISTANCE[32],
    E_INFOBOX_TARGET_REFRESH[32],
    E_INFOBOX_TARGET_CLEAR[32],
    E_INFOBOX_TARGET_PRIORITY,
    E_INFOBOX_TARGET_ACTOR,
}

static s_InfoboxTargets[INFOBOX_TARGET_MAX][E_INFOBOX_TARGET];
static s_InfoboxTargetCount;
static bool:s_InfoboxSelecting[MAX_PLAYERS];
static s_InfoboxTargetWinner[MAX_PLAYERS];

forward bool:Session_IsPlaying(playerid);

static s_InfoboxToken[MAX_PLAYERS];
static bool:s_InfoboxShown[MAX_PLAYERS];
static bool:s_InfoboxIsHint[MAX_PLAYERS];
static bool:s_InfoboxFootOnly[MAX_PLAYERS];
static s_InfoboxText[MAX_PLAYERS][128];
static s_InfoboxPressOwner[MAX_PLAYERS];
static bool:s_InfoboxPressing[MAX_PLAYERS];

stock bool:Infobox_RegisterTarget(const distancePublic[],const refreshPublic[],const clearPublic[],priority)
{
    if (s_InfoboxTargetCount >= INFOBOX_TARGET_MAX)
    {
        return false;
    }
    new target = s_InfoboxTargetCount++;
    strcopy(s_InfoboxTargets[target][E_INFOBOX_TARGET_DISTANCE],distancePublic,32);
    strcopy(s_InfoboxTargets[target][E_INFOBOX_TARGET_REFRESH],refreshPublic,32);
    strcopy(s_InfoboxTargets[target][E_INFOBOX_TARGET_CLEAR],clearPublic,32);
    s_InfoboxTargets[target][E_INFOBOX_TARGET_PRIORITY] = priority;
    s_InfoboxTargets[target][E_INFOBOX_TARGET_ACTOR] = -1;
    return true;
}

stock Infobox_SetTargetActor(const distancePublic[],actor)
{
    for (new target = 0; target < s_InfoboxTargetCount; target++)
    {
        if (!strcmp(s_InfoboxTargets[target][E_INFOBOX_TARGET_DISTANCE],distancePublic))
        {
            s_InfoboxTargets[target][E_INFOBOX_TARGET_ACTOR] = actor;
        }
    }
}

stock bool:Infobox_IsTargetActor(actor)
{
    for (new target = 0; actor != -1 && target < s_InfoboxTargetCount; target++)
    {
        if (s_InfoboxTargets[target][E_INFOBOX_TARGET_ACTOR] == actor)
        {
            return true;
        }
    }
    return false;
}

stock Infobox_FindTarget(playerid)
{
    if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid))
    {
        return -1;
    }
    if (s_InfoboxSelecting[playerid])
    {
        return s_InfoboxTargetWinner[playerid];
    }
    new winner = -1, Float:nearest = 10000.0;
    for (new target = 0; target < s_InfoboxTargetCount; target++)
    {
        new Float:distance = Float:pawn_call_public(s_InfoboxTargets[target][E_INFOBOX_TARGET_DISTANCE],"d",playerid);
        if (distance >= 0.0 && distance < nearest)
        {
            winner = target;
            nearest = distance;
        }
    }
    return winner;
}

stock bool:Infobox_IsTargetWinner(playerid,const distancePublic[])
{
    new winner = Infobox_FindTarget(playerid);
    return winner != -1 && !strcmp(s_InfoboxTargets[winner][E_INFOBOX_TARGET_DISTANCE],distancePublic);
}

stock Infobox_RefreshTargets(playerid)
{
    if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
    {
        return;
    }
    new winner = Infobox_FindTarget(playerid);
    s_InfoboxTargetWinner[playerid] = winner;
    s_InfoboxSelecting[playerid] = true;
    for (new target = 0; target < s_InfoboxTargetCount; target++)
    {
        if (target != winner)
        {
            pawn_call_public(s_InfoboxTargets[target][E_INFOBOX_TARGET_CLEAR],"d",playerid);
        }
    }
    if (winner != -1)
    {
        pawn_call_public(s_InfoboxTargets[winner][E_INFOBOX_TARGET_REFRESH],"d",playerid);
    }
    s_InfoboxSelecting[playerid] = false;
}

stock Infobox_Show(playerid,const title[],const text[],rows = INFOBOX_ROWS,seconds = 0,bool:isHint = false)
{
	if (!Util_IsValidPlayer(playerid) || IsPlayerNPC(playerid) || (isHint && s_InfoboxShown[playerid] && !s_InfoboxIsHint[playerid]))
	{
		return 0;
	}

	new Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_NOTICE);
	Kit_AddPanel(playerid,INFOBOX_X,INFOBOX_Y,INFOBOX_WIDTH,KIT_ROW * float(rows) + KIT_PANEL_EXTRA,title,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_ShowNotice(playerid);
	s_InfoboxShown[playerid] = true;
	s_InfoboxIsHint[playerid] = isHint;
    s_InfoboxFootOnly[playerid] = isHint;
	strcopy(s_InfoboxText[playerid],text);

	new token = ++s_InfoboxToken[playerid];

	if (seconds > 0)
	{
		SetTimerEx("Infobox_Expire",seconds * 1000,false,"dd",playerid,token);
	}

	return token;
}

static Infobox_PromptOwner(playerid)
{
	return s_InfoboxShown[playerid] && s_InfoboxIsHint[playerid] ? s_InfoboxToken[playerid] : 0;
}

forward Infobox_OnInteracting(playerid);

public Infobox_OnInteracting(playerid)
{
    return 1;
}

stock bool:Infobox_IsPromptBlocked(playerid,token)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return false;
	}

	new owner = s_InfoboxPressing[playerid] ? s_InfoboxPressOwner[playerid] : Infobox_PromptOwner(playerid);
	return owner != 0 && token != owner;
}

stock Infobox_ShowPrompt(playerid,token,const title[],const text[],rows = INFOBOX_ROWS,bool:allowMounted = false)
{
	if (Infobox_IsPromptBlocked(playerid,token))
	{
		return INFOBOX_REFUSED;
	}

	new shown = Infobox_Show(playerid,title,text,rows,0,true);
    if (shown != 0)
    {
        s_InfoboxFootOnly[playerid] = !allowMounted;
    }

	return shown == 0 ? INFOBOX_REFUSED : shown;
}

stock Infobox_Hide(playerid,token = 0)
{
	if (!s_InfoboxShown[playerid] || (token != 0 && token != s_InfoboxToken[playerid]))
	{
		return;
	}

	s_InfoboxToken[playerid]++;
	s_InfoboxShown[playerid] = false;
	Kit_HideNotice(playerid);
}

stock Infobox_GetText(playerid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Util_IsValidPlayer(playerid) && s_InfoboxShown[playerid])
	{
		strcat(dest,s_InfoboxText[playerid],size);
	}
}

stock bool:Infobox_IsShown(playerid,token = 0)
{
	return Util_IsValidPlayer(playerid) && s_InfoboxShown[playerid] && (token == 0 || token == s_InfoboxToken[playerid]);
}

forward Infobox_PressDone(playerid);

public Infobox_PressDone(playerid)
{
	s_InfoboxPressing[playerid] = false;
	return 1;
}

forward Infobox_Expire(playerid,token);

public Infobox_Expire(playerid,token)
{
	if (IsPlayerConnected(playerid))
	{
		Infobox_Hide(playerid,token);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_InfoboxToken[playerid]++;
	s_InfoboxShown[playerid] = false;
	s_InfoboxText[playerid][0] = EOS;
	s_InfoboxPressing[playerid] = false;
    s_InfoboxSelecting[playerid] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES))
	{
		return;
	}

    Infobox_RefreshTargets(playerid);
	s_InfoboxPressOwner[playerid] = Infobox_PromptOwner(playerid);
	s_InfoboxPressing[playerid] = true;
    if (s_InfoboxPressOwner[playerid] != 0 && s_InfoboxFootOnly[playerid])
    {
        pawn_call_public("Infobox_OnInteracting","d",playerid);
    }

	SetTimerEx("Infobox_PressDone",0,false,"d",playerid);
}

forward bool:Infobox_TargetContext(playerid);
public bool:Infobox_TargetContext(playerid)
{
    new winner = Infobox_FindTarget(playerid);
    return winner != -1 && s_InfoboxTargets[winner][E_INFOBOX_TARGET_PRIORITY] >= INFOBOX_TARGET_PRIORITY;
}

Timer_Declare(Infobox_TargetTick)
{
    foreach (new playerid : Player)
    {
        if (!IsPlayerNPC(playerid))
        {
            Infobox_RefreshTargets(playerid);
        }
    }
    return 1;
}

hook OnGameModeInit()
{
    Keys_RegisterContext(KEY_YES,INFOBOX_TARGET_PRIORITY,"Infobox_TargetContext");
    SetTimer("Infobox_TargetTick",500,true);
}
