#define LETTERS_TABLE_REACH (1.6)

static s_LettersTableTokens[MAX_PLAYERS];

stock Letters_FindFacedTable(playerid,&Float:distance)
{
    distance = LETTERS_TABLE_REACH + 1.0;
    if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Mount_IsRiding(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
    {
        return -1;
    }
    new Float:x, Float:y, Float:z, Float:angle;
    new nearest = -1;
    GetPlayerPos(playerid,x,y,z);
    GetPlayerFacingAngle(playerid,angle);
    for (new post = 0; post < LETTERS_SEED_POSTS; post++)
    {
        new Float:tableX = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][0], Float:tableY = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][1], Float:tableZ = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][2] + 1.0;
        new Float:tableDistance = VectorSize(tableX - x,tableY - y,tableZ - z);
        if (tableDistance <= LETTERS_TABLE_REACH && tableDistance < distance && Actors_IsFacing(x,y,angle,tableX,tableY))
        {
            nearest = post;
            distance = tableDistance;
        }
    }
    return nearest;
}

stock bool:Letters_GetTablePose(post,&Float:x,&Float:y,&Float:z,&Float:angle)
{
    if (post < 0 || post >= LETTERS_SEED_POSTS)
    {
        return false;
    }
    x = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][0];
    y = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][1];
    z = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][2];
    angle = g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][3];
    return true;
}

stock Letters_ClearTablePrompt(playerid)
{
    if (s_LettersTableTokens[playerid] > 0)
    {
        Infobox_Hide(playerid,s_LettersTableTokens[playerid]);
    }
    s_LettersTableTokens[playerid] = 0;
}

forward Float:Letters_TableDistance(playerid);
public Float:Letters_TableDistance(playerid)
{
    new Float:distance;
    return Letters_FindFacedTable(playerid,distance) != -1 ? distance : -1.0;
}

forward Letters_TableRefresh(playerid);
public Letters_TableRefresh(playerid)
{
    if (!Infobox_IsShown(playerid,s_LettersTableTokens[playerid]))
    {
        s_LettersTableTokens[playerid] = Infobox_ShowPrompt(playerid,s_LettersTableTokens[playerid],"Courier's table","Press ~y~Y~w~ to write a letter. You need parchment, ink and a quill.",3);
    }
    return 1;
}

forward Letters_TableClear(playerid);
public Letters_TableClear(playerid)
{
    Letters_ClearTablePrompt(playerid);
    return 1;
}

forward Letters_TableDeferred(playerid);
public Letters_TableDeferred(playerid)
{
    if (IsPlayerConnected(playerid) && Infobox_IsTargetWinner(playerid,"Letters_TableDistance"))
    {
        Letters_Write(playerid);
    }
    return 1;
}

forward bool:Letters_TableContext(playerid);
public bool:Letters_TableContext(playerid)
{
    return Infobox_IsTargetWinner(playerid,"Letters_TableDistance");
}

#include <pp-hooks>
hook OnGameModeInit()
{
    Infobox_RegisterTarget("Letters_TableDistance","Letters_TableRefresh","Letters_TableClear",INFOBOX_TARGET_PRIORITY);
    Keys_RegisterContext(KEY_YES,INFOBOX_TARGET_PRIORITY,"Letters_TableContext");
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && Infobox_IsTargetWinner(playerid,"Letters_TableDistance") && !Infobox_IsPromptBlocked(playerid,s_LettersTableTokens[playerid]) && !Keys_IsBusy(playerid,KEY_YES,INFOBOX_TARGET_PRIORITY))
    {
        Letters_ClearTablePrompt(playerid);
        SetTimerEx("Letters_TableDeferred",0,false,"d",playerid);
    }
}

hook OnPlayerConnect(playerid)
{
    s_LettersTableTokens[playerid] = 0;
}

hook ResetPlayerVariables(playerid)
{
    Letters_ClearTablePrompt(playerid);
}
