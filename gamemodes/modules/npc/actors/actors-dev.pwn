CMD<ADMIN_LEVEL_TRIAL>:actor(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[96];

	if (sscanf(params,"s[12]S()[96]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/actor list | info | kill | revive | say [text] | go [key]");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new placed = 0, walking = 0, dead = 0, total = Actors_Count();

		for (new i = 0;i < ACTORS_MAX;i++)
		{
			if (!Actors_IsValid(i))
			{
				continue;
			}

			if (Actors_IsDead(i))
			{
				dead++;
			}
			else if (Actors_IsWalking(i))
			{
				walking++;
			}
			else if (Actors_IsPlaced(i))
			{
				placed++;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Actors: %d registered, %d standing, %d walking, %d dead.",total,placed,walking,dead));
		return 1;
	}

	if (!strcmp(action,"go",true))
	{
		new index = Actors_FindByKey(rest), Float:x, Float:y, Float:z;

		if (index == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No actor with that key.");
			return 1;
		}

		Actors_GetPos(index,x,y,z);
		SetPlayerVirtualWorld(playerid,Actors_GetWorld(index));
		SetPlayerPos(playerid,x + 1.0,y,z);
		return 1;
	}

	new index = Actors_FindNear(playerid,6.0,false);

	if (index == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No actor near you.");
		return 1;
	}

	if (!strcmp(action,"info",true))
	{
		new key[ACTORS_KEY_LEN], name[ACTORS_NAME_LEN], title[ACTORS_TITLE_LEN];
		Actors_GetKey(index,key);
		Actors_GetName(index,name);
		Actors_GetTitle(index,title);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s (%s), key %s, role %s, skin %d, db %d, health %.0f, %s%s",name,title,key,g_ActorRoleNames[Actors_GetRole(index)],Actors_GetSkin(index),Actors_GetDbId(index),Actors_GetHealth(index),Actors_IsDead(index) ? ("dead") : ("alive"),Actors_IsOpen(index) ? (", open") : ("")));
	}
	else if (!strcmp(action,"kill",true))
	{
		Actors_Kill(index);
	}
	else if (!strcmp(action,"revive",true))
	{
		Actors_Respawn(index);
	}
	else if (!strcmp(action,"say",true))
	{
		Actors_Say(index,rest);
	}

	return 1;
}
