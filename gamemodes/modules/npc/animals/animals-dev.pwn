stock Animals_SpawnAhead(species,count,Float:x,Float:y,Float:z,Float:a)
{
	new spawned = 0, herd = count > 1 ? Animals_NewHerd() : -1;

	for (new i = 0;i < Util_ClampInt(count,1,8);i++)
	{
		new Float:sx = x + floatsin(-a,degrees) * (8.0 + float(i) * 2.0), Float:sy = y + floatcos(-a,degrees) * (8.0 + float(i) * 2.0), Float:sz = z - 1.0, Float:hx, Float:hy, Float:hz;

		if (CA_RayCastLine(sx,sy,z + ANIMALS_DEV_RAY_UP,sx,sy,z - ANIMALS_DEV_RAY_DOWN,hx,hy,hz) != 0)
		{
			sz = hz;
		}

		if (Animals_Spawn(species,sx,sy,sz,-1,herd) != -1)
		{
			spawned++;
		}
	}

	return spawned;
}

CMD<ADMIN_LEVEL_ADMIN>:animals(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], key[12], count;

	if (sscanf(params,"s[12]S()[12]I(1)",action,key,count))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/animals list | wild 0|1 | spawn <species> [count] | clear | kill or hurt (the nearest) | species");
		return 1;
	}

	if (!strcmp(action,"wild",true))
	{
		Animals_SetWild(strval(key) != 0);
		SendClientMessage(playerid,0xFFFFFFFF,Animals_IsWild() ? ("Wild animals roam (placeholder bodies until the skins arrive).") : ("Wild animals are kept away."));
		return 1;
	}

	if (!strcmp(action,"species",true))
	{
		new line[144];

		for (new species = 0;species < ANIMAL_SPECIES_COUNT;species++)
		{
			format(line,sizeof(line),"%s%s%s",line,species > 0 ? (", ") : (""),g_AnimalDefs[species][E_ANIMAL_DEF_KEY]);
		}

		SendClientMessage(playerid,0xFFFFFFFF,line);
		return 1;
	}

	if (!strcmp(action,"spawn",true))
	{
		new species = Animals_SpeciesFromKey(key), Float:x, Float:y, Float:z, Float:a;

		if (species == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No such species: /animals species.");
			return 1;
		}

		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		new spawned = Animals_SpawnAhead(species,count,x,y,z,a);

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d %s in front of you.",spawned,g_AnimalDefs[species][E_ANIMAL_DEF_NAME]));
		return 1;
	}

	if (!strcmp(action,"clear",true))
	{
		Animals_Clear();
		SendClientMessage(playerid,0xFFFFFFFF,"Every animal is gone.");
		return 1;
	}

	if (!strcmp(action,"kill",true))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		new animal = Animals_FindNear(x,y,z,40.0);

		if (animal != -1)
		{
			Animals_Kill(animal,playerid);
		}

		SendClientMessage(playerid,0xFFFFFFFF,animal != -1 ? ("Killed, as by your hand.") : ("No animal within 40 m."));
		return 1;
	}

	if (!strcmp(action,"hurt",true))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		new animal = Animals_FindNear(x,y,z,40.0);

		if (animal != -1)
		{
			Animals_Damage(animal,playerid,1.0);
		}

		SendClientMessage(playerid,0xFFFFFFFF,animal != -1 ? ("Struck, as by your hand.") : ("No animal within 40 m."));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d animals alive (%d wolves, %d deer). Wild: %s. %d forest, %d meadow, %d water places, %d dens.",Animals_Count(),Animals_Count(ANIMAL_WOLF),Animals_Count(ANIMAL_RED_DEER) + Animals_Count(ANIMAL_ROE_DEER),Animals_IsWild() ? ("on") : ("off"),ANIMALS_SEED_FOREST,ANIMALS_SEED_MEADOW,ANIMALS_SEED_WATER,ANIMALS_SEED_DENS));
	return 1;
}
