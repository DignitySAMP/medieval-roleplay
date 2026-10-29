forward Float:Actors_TargetDistance(playerid);
public Float:Actors_TargetDistance(playerid)
{
    new Float:nearest = ACTORS_ROAD_REACH + 1.0;
    if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
    {
        return -1.0;
    }
    for (new actor = 0; actor < ACTORS_MAX; actor++)
    {
        if (Infobox_IsTargetActor(actor) || !Actors_CanTalkTo(playerid,actor) || !Actors_IsFacedBy(playerid,actor))
        {
            continue;
        }
        new Float:x, Float:y, Float:z;
        Actors_GetTalkPos(actor,x,y,z);
        new Float:distance = GetPlayerDistanceFromPoint(playerid,x,y,z);
        if (distance < nearest)
        {
            nearest = distance;
        }
    }
    return nearest <= ACTORS_ROAD_REACH ? nearest : -1.0;
}

forward Actors_TargetRefresh(playerid);
public Actors_TargetRefresh(playerid)
{
    Actors_UpdatePrompt(playerid);
    return 1;
}

forward Actors_TargetClear(playerid);
public Actors_TargetClear(playerid)
{
    Actors_ClearPrompt(playerid);
    return 1;
}

#include <pp-hooks>
hook OnGameModeInit()
{
    Infobox_RegisterTarget("Actors_TargetDistance","Actors_TargetRefresh","Actors_TargetClear",ACTORS_KEY_PRIO);
}
