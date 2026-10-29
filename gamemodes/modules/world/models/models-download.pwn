static bool:s_ModelsReady[MAX_PLAYERS];

stock bool:Models_IsPlayerReady(playerid)
{
	return Util_IsValidPlayer(playerid) && s_ModelsReady[playerid];
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_ModelsReady[playerid] = IsPlayerNPC(playerid);

	if (!s_ModelsReady[playerid])
	{
		Streamer_ToggleItemUpdate(playerid,STREAMER_TYPE_OBJECT,false);
	}
}

hook OnPlayerFinishedDownloading(playerid,virtualworld)
{
	#pragma unused virtualworld

	if (s_ModelsReady[playerid])
	{
		return;
	}

	s_ModelsReady[playerid] = true;
	Streamer_DestroyAllVisibleItems(playerid,STREAMER_TYPE_OBJECT,0);
	Streamer_ToggleItemUpdate(playerid,STREAMER_TYPE_OBJECT,true);
	Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
}
