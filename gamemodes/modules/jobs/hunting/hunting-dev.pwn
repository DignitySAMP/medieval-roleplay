CMD<ADMIN_LEVEL_ADMIN>:hunt(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], key[12], sex[8];

	if (sscanf(params,"s[12]S()[12]S()[8]",action,key,sex))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/hunt info | carcass <species> [female] (lies the way you face) | licence <hunting|woodcutting|mining> | trap <snare|foothold|pit> | traps clear");
		return 1;
	}

	if (!strcmp(action,"carcass",true))
	{
		new species = Animals_SpeciesFromKey(key), Float:x, Float:y, Float:z, Float:a;

		if (species == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No such species: /animals species.");
			return 1;
		}

		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		Hunting_CreateCarcass(species,x + floatsin(-a,degrees) * 2.0,y + floatcos(-a,degrees) * 2.0,z,Character_GetId(playerid),true,!strcmp(sex,"female",true) && sex[0] != EOS,a);
		SendClientMessage(playerid,0xFFFFFFFF,"A carcass lies in front of you.");
		return 1;
	}

	if (!strcmp(action,"licence",true))
	{
		for (new licence = 0;licence < HUNT_LICENCE_COUNT;licence++)
		{
			if (!strcmp(key,g_HuntLicenceNames[licence],true))
			{
				Hunting_SetLicence(playerid,licence,Hunting_HasLicence(playerid,licence) ? -1 : Hunting_SeasonIndex());
				SendClientMessage(playerid,0xFFFFFFFF,Hunting_HasLicence(playerid,licence) ? ("Licence granted for the season.") : ("Licence taken away."));
				return 1;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,"hunting, woodcutting or mining.");
		return 1;
	}

	if (!strcmp(action,"trap",true))
	{
		new kind = !strcmp(key,"snare",true) ? HUNT_TRAP_SNARE : (!strcmp(key,"pit",true) ? HUNT_TRAP_PIT : HUNT_TRAP_FOOTHOLD), Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		SendClientMessage(playerid,0xFFFFFFFF,Hunting_PlaceTrap(kind,x + floatsin(-a,degrees) * 2.0,y + floatcos(-a,degrees) * 2.0,z - 0.95,a,Character_GetId(playerid)) != -1 ? ("Trap set in front of you.") : ("No room for traps."));
		return 1;
	}

	if (!strcmp(action,"traps",true))
	{
		for (new trap = 0;trap < HUNTING_TRAPS_MAX;trap++)
		{
			Hunting_RemoveTrap(trap);
		}

		SendClientMessage(playerid,0xFFFFFFFF,"Every trap is taken up.");
		return 1;
	}

	new reason[48];
	Hunting_IsPoaching(playerid,ANIMAL_RED_DEER,reason);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d carcasses, %d traps. Your hunting licence: %s. Taking a red deer now: %s.",Hunting_CountCarcasses(),Hunting_CountTraps(),Hunting_HasLicence(playerid,HUNT_LICENCE_HUNT) ? ("held") : ("none"),reason[0] != EOS ? reason : ("lawful")));
	return 1;
}
