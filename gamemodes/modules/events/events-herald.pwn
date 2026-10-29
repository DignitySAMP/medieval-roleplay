static s_PlayerHerald = INVALID_PLAYER_ID;
static s_PlayerHeraldCharacter;
static s_PlayerHeraldEvent = -1;
static s_PlayerHeraldActiveAt;
static s_PlayerHeraldFlow;
static s_HeraldPrompts[MAX_PLAYERS];

stock bool:Events_IsAtHeraldStand(playerid)
{
    new Float:positionX, Float:positionY, Float:positionZ;
    if (!Util_IsValidPlayer(playerid) || !Events_GetHeraldDeck(positionX,positionY,positionZ))
    {
        return false;
    }
    return Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && GetPlayerInterior(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,4.0,positionX,positionY,positionZ + 1.0);
}

stock Events_GetPlayerHerald()
{
    return s_PlayerHerald;
}

stock bool:Events_HasPlayerHerald()
{
    return s_PlayerHerald != INVALID_PLAYER_ID;
}

stock Events_SetHeraldFlow(epoch)
{
    s_PlayerHeraldFlow = epoch;
}

stock Events_ReleaseHerald()
{
    new playerid = s_PlayerHerald;
    s_PlayerHerald = INVALID_PLAYER_ID;
    s_PlayerHeraldCharacter = 0;
    s_PlayerHeraldEvent = -1;
    if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
    {
        if (s_HeraldPrompts[playerid] > 0)
        {
            Infobox_Hide(playerid,s_HeraldPrompts[playerid]);
            s_HeraldPrompts[playerid] = 0;
        }
        if (s_PlayerHeraldFlow != 0 && Gui_IsFlowCurrent(playerid,s_PlayerHeraldFlow))
        {
            Kit_Close(playerid);
        }
        Gui_Notify(playerid,"Hans Herold takes the stand again. Your turn as herald has ended.");
    }
    s_PlayerHeraldFlow = 0;
    Events_RefreshHerald();
}

stock bool:Events_CanAppointHerald(playerid,event)
{
    return Session_IsPlaying(playerid) && Events_IsValid(event) && Events_GetState(event) != EVENT_DONE && (Events_GetHost(event) == Character_GetId(playerid) || (Events_GetHost(event) == 0 && (Realm_IsRuler(playerid) || Realm_IsDuke(playerid))));
}

stock bool:Events_AppointHerald(hostid,playerid,event)
{
    if (!Events_CanAppointHerald(hostid,event) || !Events_IsAtHeraldStand(hostid) || !Events_IsAtHeraldStand(playerid) || Mount_IsRiding(playerid) || Character_IsBusy(playerid))
    {
        return false;
    }
    if (Events_HasPlayerHerald())
    {
        Events_ReleaseHerald();
    }
    s_PlayerHerald = playerid;
    s_PlayerHeraldCharacter = Character_GetId(playerid);
    s_PlayerHeraldEvent = event;
    s_PlayerHeraldActiveAt = GetTickCount();
    Events_RemoveHerald();
    Gui_Notify(playerid,"You've been appointed herald. Press ~y~Y~w~ on the stand to open the herald's panel. Hans takes over after 2 minutes idle.");
    return true;
}

stock bool:Events_HeraldAction(playerid,action)
{
    if (s_PlayerHerald != playerid || Character_GetId(playerid) != s_PlayerHeraldCharacter || !Events_IsAtHeraldStand(playerid) || !Events_IsValid(s_PlayerHeraldEvent))
    {
        return false;
    }
    s_PlayerHeraldActiveAt = GetTickCount();
    new running = Events_GetRunningEvent();
    if (running != -1 && running != s_PlayerHeraldEvent)
    {
        return false;
    }
    switch (action)
    {
        case 0: return Events_HeraldAdvance(s_PlayerHeraldEvent);
        case 1: return Events_CallTime();
        case 2: return Events_HeraldYield();
        case 3:
        {
            if (running == -1)
            {
                return false;
            }
            Events_Say("The herald throws down his staff. The bout is stopped; its scores are set aside.");
            Events_StopContest();
            return true;
        }
        case 4:
        {
            Events_ReleaseHerald();
            return true;
        }
    }
    return false;
}

forward bool:Events_HeraldContext(playerid);
public bool:Events_HeraldContext(playerid)
{
    return s_PlayerHerald == playerid && Events_IsAtHeraldStand(playerid) && !Infobox_IsPromptBlocked(playerid,s_HeraldPrompts[playerid]);
}

stock Events_HeraldStep(tick)
{
    if (s_PlayerHerald != INVALID_PLAYER_ID && (!IsPlayerConnected(s_PlayerHerald) || !Session_IsPlaying(s_PlayerHerald) || Character_GetId(s_PlayerHerald) != s_PlayerHeraldCharacter || !Events_IsAtHeraldStand(s_PlayerHerald) || !Events_IsValid(s_PlayerHeraldEvent) || Events_GetState(s_PlayerHeraldEvent) == EVENT_DONE || tick - s_PlayerHeraldActiveAt >= 120000))
    {
        Events_ReleaseHerald();
    }
    if (s_PlayerHerald != INVALID_PLAYER_ID)
    {
        new playerid = s_PlayerHerald;
        if (Gui_IsBusy(playerid))
        {
            if (s_HeraldPrompts[playerid] > 0)
            {
                Infobox_Hide(playerid,s_HeraldPrompts[playerid]);
                s_HeraldPrompts[playerid] = 0;
            }
        }
        else
        {
            s_HeraldPrompts[playerid] = Infobox_ShowPrompt(playerid,s_HeraldPrompts[playerid],"The herald's stand","Press ~y~Y~w~ to call the next pair, call time or stop the bout.",2);
        }
    }
}

forward Events_HeraldTick();
public Events_HeraldTick()
{
    Events_HeraldStep(GetTickCount());
    return 1;
}

#include <pp-hooks>

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !Gui_IsBusy(playerid) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU) && Events_HeraldContext(playerid))
    {
        SetTimerEx("Events_HeraldDeferred",0,false,"d",playerid);
    }
}

hook OnPlayerDisconnect(playerid,reason)
{
    #pragma unused reason
    if (s_PlayerHerald == playerid)
    {
        Events_ReleaseHerald();
    }
    s_HeraldPrompts[playerid] = 0;
}
