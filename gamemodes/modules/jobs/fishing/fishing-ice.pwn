stock bool:Fishing_IsWaterFrozenAt(Float:x, Float:y)
{
    if (!Seasons_IsWaterFrozen())
    {
        return false;
    }

    new Float:level, type = Fishing_WaterAt(x, y, level);
    return type != FISHING_WATER_NONE && type != FISHING_WATER_SEA;
}

stock bool:Fishing_IsNodeFrozen(node)
{
    if (!Work_IsValidNode(node))
    {
        return false;
    }

    new Float:x, Float:y, Float:z;
    Work_GetNodePos(node, x, y, z);
    return Fishing_IsWaterFrozenAt(x, y);
}

#include <pp-hooks>

hook Seasons_OnWaterFrozen(frozen)
{
    if (frozen)
    {
        foreach (new playerid : Player)
        {
            if (Work_IsWorking(playerid) && Work_GetSceneRecipe(playerid) == Fishing_GetRecipe() && Fishing_IsNodeFrozen(Work_GetSceneTarget(playerid)))
            {
                Work_Abort(playerid);
                Gui_Notify(playerid,"The water has frozen. You must wait for the ice to thaw before fishing here.");
            }
        }
    }
}
