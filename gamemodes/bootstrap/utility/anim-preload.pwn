#define ANIMPRELOAD_MAX (96)
#define ANIMPRELOAD_LIB_LEN (20)

static s_AnimPreloadLibs[ANIMPRELOAD_MAX][ANIMPRELOAD_LIB_LEN];
static s_AnimPreloadCount;

static AnimPreload_Apply(playerid,const lib[])
{
	ApplyAnimation(playerid,lib,"null",0.0,false,false,false,false,0,SYNC_NONE);
}

stock AnimPreload_Register(const lib[])
{
	for (new i = 0;i < s_AnimPreloadCount;i++)
	{
		if (strcmp(s_AnimPreloadLibs[i],lib,true) == 0)
		{
			return;
		}
	}

	if (s_AnimPreloadCount >= ANIMPRELOAD_MAX)
	{
		Log_Error("animpreload","table full - '%s' not registered",lib);
		return;
	}

	strcopy(s_AnimPreloadLibs[s_AnimPreloadCount],lib);
	s_AnimPreloadCount++;

	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			AnimPreload_Apply(playerid,lib);
		}
	}
}

#include <pp-hooks>

hook OnPlayerSpawn(playerid)
{
	if (IsPlayerNPC(playerid))
	{
		return;
	}

	for (new i = 0;i < s_AnimPreloadCount;i++)
	{
		AnimPreload_Apply(playerid,s_AnimPreloadLibs[i]);
	}
}
