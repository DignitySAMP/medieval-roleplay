#define CRYPT_NICHE_SLOTS (512)

enum E_CRYPT
{
	bool:E_CRYPT_USED,
	E_CRYPT_ROW,
	E_CRYPT_KEY[GRAVES_KEY_LEN],
	Float:E_CRYPT_DOOR[4],
	E_CRYPT_DOOR_WORLD,
	E_CRYPT_DOOR_INTERIOR,
	E_CRYPT_CHAMBERS,
	E_CRYPT_PIECE_COUNT,
}

static s_Crypts[CRYPT_MAX][E_CRYPT];
static STREAMER_TAG_OBJECT:s_CryptPieces[CRYPT_MAX][CRYPT_PIECES_MAX];

enum E_CRYPT_NICHE
{
	bool:E_CRYPT_NICHE_USED,
	E_CRYPT_NICHE_ROW,
	E_CRYPT_NICHE_CRYPT,
	E_CRYPT_NICHE_INDEX,
	E_CRYPT_NICHE_CHARACTER,
	E_CRYPT_NICHE_NAME[GRAVES_NAME_LEN],
	E_CRYPT_NICHE_BORN_DAY,
	E_CRYPT_NICHE_DIED_DAY,
	E_CRYPT_NICHE_AGE,
	E_CRYPT_NICHE_CAUSE[GRAVES_CAUSE_LEN],
	STREAMER_TAG_OBJECT:E_CRYPT_NICHE_SLAB,
	STREAMER_TAG_3D_TEXT_LABEL:E_CRYPT_NICHE_LABEL,
}

static s_CryptNiches[CRYPT_NICHE_SLOTS][E_CRYPT_NICHE];

stock bool:Crypt_IsValid(crypt)
{
	return crypt >= 0 && crypt < CRYPT_MAX && s_Crypts[crypt][E_CRYPT_USED];
}

stock Crypt_GetWorld(crypt)
{
	return Crypt_IsValid(crypt) ? CRYPT_WORLD_BASE + s_Crypts[crypt][E_CRYPT_ROW] : -1;
}

stock Crypt_GetChambers(crypt)
{
	return Crypt_IsValid(crypt) ? s_Crypts[crypt][E_CRYPT_CHAMBERS] : 0;
}

stock Crypt_GetKey(crypt,dest[],size = sizeof(dest))
{
	if (!Crypt_IsValid(crypt))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Crypts[crypt][E_CRYPT_KEY],size);
}

stock Crypt_GetRow(crypt)
{
	return Crypt_IsValid(crypt) ? s_Crypts[crypt][E_CRYPT_ROW] : 0;
}

stock Crypt_FindByRow(row)
{
	for (new i = 0;i < CRYPT_MAX;i++)
	{
		if (s_Crypts[i][E_CRYPT_USED] && s_Crypts[i][E_CRYPT_ROW] == row)
		{
			return i;
		}
	}

	return -1;
}

stock Crypt_FindByWorld(world)
{
	for (new i = 0;i < CRYPT_MAX;i++)
	{
		if (s_Crypts[i][E_CRYPT_USED] && CRYPT_WORLD_BASE + s_Crypts[i][E_CRYPT_ROW] == world)
		{
			return i;
		}
	}

	return -1;
}

stock Crypt_ToWorld(Float:localX,Float:localY,Float:localZ,&Float:x,&Float:y,&Float:z)
{
	x = CRYPT_SKY_X + localX;
	y = CRYPT_SKY_Y + localY;
	z = CRYPT_SKY_Z + localZ;
}

stock Float:Crypt_ChamberCentreY(chamber)
{
	return -14.0 - 16.0 * float(chamber);
}

stock Crypt_GetBankPose(chamber,bank,&Float:x,&Float:y,&Float:rz)
{
	new Float:cy = Crypt_ChamberCentreY(chamber), Float:along = (bank % 2) == 0 ? -3.925 : 3.925;

	switch (bank / 2)
	{
		case 0: { x = -5.6; y = cy + along; rz = 90.0; }
		case 1: { x = 5.6; y = cy + along; rz = 270.0; }
		case 2: { x = along; y = cy + 5.6; rz = 0.0; }
		default: { x = along; y = cy - 5.6; rz = 180.0; }
	}
}

stock Crypt_GetSlabPose(niche,&Float:x,&Float:y,&Float:z,&Float:rz)
{
	new chamber = niche / CRYPT_NICHES_PER_CHAMBER, bank = (niche % CRYPT_NICHES_PER_CHAMBER) / CRYPT_NICHES_PER_BANK, cell = niche % CRYPT_NICHES_PER_BANK;
	new Float:bankX, Float:bankY, Float:column = g_CryptSlabColumns[cell % 3];
	Crypt_GetBankPose(chamber,bank,bankX,bankY,rz);
	x = bankX + column * floatcos(rz,degrees) + 0.5 * floatsin(rz,degrees);
	y = bankY + column * floatsin(rz,degrees) - 0.5 * floatcos(rz,degrees);
	z = g_CryptSlabRows[cell / 3];
}

static Crypt_AddPiece(crypt,model,Float:localX,Float:localY,Float:localZ,Float:rz)
{
	if (s_Crypts[crypt][E_CRYPT_PIECE_COUNT] >= CRYPT_PIECES_MAX)
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	Crypt_ToWorld(localX,localY,localZ,x,y,z);
	s_CryptPieces[crypt][s_Crypts[crypt][E_CRYPT_PIECE_COUNT]++] = CreateDynamicObject(model,x,y,z,0.0,0.0,rz,Crypt_GetWorld(crypt),CRYPT_INTERIOR,-1,CRYPT_STREAM_RANGE,CRYPT_STREAM_RANGE);
	Util_WatchInteriorShell(s_CryptPieces[crypt][s_Crypts[crypt][E_CRYPT_PIECE_COUNT] - 1]);
	Light_FollowModel(LIGHT_FOLLOW_CRYPT,crypt,model,x,y,z,rz,Crypt_GetWorld(crypt),CRYPT_INTERIOR);
}

static Crypt_ClearPieces(crypt)
{
	for (new i = 0;i < s_Crypts[crypt][E_CRYPT_PIECE_COUNT];i++)
	{
		if (IsValidDynamicObject(s_CryptPieces[crypt][i]))
		{
			Util_WatchInteriorShell(s_CryptPieces[crypt][i],false);
			DestroyDynamicObject(s_CryptPieces[crypt][i]);
		}
	}

	s_Crypts[crypt][E_CRYPT_PIECE_COUNT] = 0;
	Light_Unfollow(LIGHT_FOLLOW_CRYPT,crypt);
}

stock Crypt_Build(crypt)
{
	if (!Crypt_IsValid(crypt))
	{
		return;
	}

	Crypt_ClearPieces(crypt);
	Crypt_AddPiece(crypt,MODEL_CRYPT_ENTRANCE,0.0,0.0,0.0,0.0);
	Crypt_AddPiece(crypt,MODEL_CRYPT_CORRIDOR,0.0,-6.0,0.0,0.0);

	new chambers = max(s_Crypts[crypt][E_CRYPT_CHAMBERS],1);

	for (new k = 0;k < chambers;k++)
	{
		new Float:cy = Crypt_ChamberCentreY(k);

		if (k > 0)
		{
			Crypt_AddPiece(crypt,MODEL_CRYPT_CORRIDOR,0.0,cy + 8.0,0.0,0.0);
		}

		Crypt_AddPiece(crypt,MODEL_CRYPT_CHAMBER_S,0.0,cy,0.0,0.0);
		Crypt_AddPiece(crypt,MODEL_CRYPT_ENDCAP,-6.0,cy,0.0,270.0);
		Crypt_AddPiece(crypt,MODEL_CRYPT_ENDCAP,6.0,cy,0.0,90.0);

		for (new bank = 0;bank < CRYPT_BANKS_PER_CHAMBER;bank++)
		{
			new Float:x, Float:y, Float:rz;
			Crypt_GetBankPose(k,bank,x,y,rz);
			Crypt_AddPiece(crypt,MODEL_CRYPT_NICHE_WALL,x,y,0.0,rz);
		}

		if (k == chambers - 1)
		{
			Crypt_AddPiece(crypt,MODEL_CRYPT_ENDCAP,0.0,cy - 6.0,0.0,180.0);
		}
	}

	new Float:x, Float:y, Float:z;
	Crypt_ToWorld(0.0,-14.0,0.0,x,y,z);
	Nearby_StreamObjectsAt(x,y,z,Crypt_GetWorld(crypt),CRYPT_INTERIOR,200.0);
}

stock Crypt_Add(row,const key[],Float:doorX,Float:doorY,Float:doorZ,Float:doorA,world,interior,chambers)
{
	for (new i = 0;i < CRYPT_MAX;i++)
	{
		if (s_Crypts[i][E_CRYPT_USED])
		{
			continue;
		}

		s_Crypts[i][E_CRYPT_USED] = true;
		s_Crypts[i][E_CRYPT_ROW] = row;
		strcopy(s_Crypts[i][E_CRYPT_KEY],key,GRAVES_KEY_LEN);
		s_Crypts[i][E_CRYPT_DOOR][0] = doorX;
		s_Crypts[i][E_CRYPT_DOOR][1] = doorY;
		s_Crypts[i][E_CRYPT_DOOR][2] = doorZ;
		s_Crypts[i][E_CRYPT_DOOR][3] = doorA;
		s_Crypts[i][E_CRYPT_DOOR_WORLD] = world;
		s_Crypts[i][E_CRYPT_DOOR_INTERIOR] = interior;
		s_Crypts[i][E_CRYPT_CHAMBERS] = Util_ClampInt(chambers,1,CRYPT_CHAMBERS_MAX);
		s_Crypts[i][E_CRYPT_PIECE_COUNT] = 0;
		Crypt_Build(i);
		return i;
	}

	return -1;
}

stock Crypt_Remove(crypt)
{
	if (!Crypt_IsValid(crypt))
	{
		return;
	}

	Crypt_ClearPieces(crypt);

	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (s_CryptNiches[i][E_CRYPT_NICHE_USED] && s_CryptNiches[i][E_CRYPT_NICHE_CRYPT] == crypt)
		{
			Crypt_ClearNiche(i);
			s_CryptNiches[i][E_CRYPT_NICHE_USED] = false;
		}
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM crypts WHERE id = %d",s_Crypts[crypt][E_CRYPT_ROW]));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM crypt_niches WHERE crypt_id = %d",s_Crypts[crypt][E_CRYPT_ROW]));
	s_Crypts[crypt][E_CRYPT_USED] = false;
}

stock bool:Crypt_Grow(crypt)
{
	if (!Crypt_IsValid(crypt) || s_Crypts[crypt][E_CRYPT_CHAMBERS] >= CRYPT_CHAMBERS_MAX)
	{
		return false;
	}

	s_Crypts[crypt][E_CRYPT_CHAMBERS]++;
	mysql_tquery_s(g_Mysql,str_format("UPDATE crypts SET chambers = %d WHERE id = %d",s_Crypts[crypt][E_CRYPT_CHAMBERS],s_Crypts[crypt][E_CRYPT_ROW]));
	Crypt_Build(crypt);
	pawn_call_public("Crypt_OnGrown","dd",crypt,s_Crypts[crypt][E_CRYPT_CHAMBERS]);
	return true;
}

stock bool:Crypt_IsNicheValid(entry)
{
	return entry >= 0 && entry < CRYPT_NICHE_SLOTS && s_CryptNiches[entry][E_CRYPT_NICHE_USED];
}

stock Crypt_GetNicheCrypt(entry)
{
	return Crypt_IsNicheValid(entry) ? s_CryptNiches[entry][E_CRYPT_NICHE_CRYPT] : -1;
}

stock Crypt_GetNicheRow(entry)
{
	return Crypt_IsNicheValid(entry) ? s_CryptNiches[entry][E_CRYPT_NICHE_ROW] : 0;
}

stock Crypt_GetNicheIndex(entry)
{
	return Crypt_IsNicheValid(entry) ? s_CryptNiches[entry][E_CRYPT_NICHE_INDEX] : -1;
}

stock Crypt_GetNicheName(entry,dest[],size = sizeof(dest))
{
	if (!Crypt_IsNicheValid(entry))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_CryptNiches[entry][E_CRYPT_NICHE_NAME],size);
}

stock Crypt_FormatInscription(entry,dest[],size = sizeof(dest))
{
	if (!Crypt_IsNicheValid(entry))
	{
		dest[0] = EOS;
		return;
	}

	new born[24], died[24];
	Calendar_FormatDay(s_CryptNiches[entry][E_CRYPT_NICHE_BORN_DAY],born);
	Calendar_FormatDay(s_CryptNiches[entry][E_CRYPT_NICHE_DIED_DAY],died);

	if (s_CryptNiches[entry][E_CRYPT_NICHE_CAUSE][0] != EOS)
	{
		format(dest,size,"Here lies ~y~%s~w~.~n~Born %s, died %s at %d.~n~Taken by %s.",s_CryptNiches[entry][E_CRYPT_NICHE_NAME],born,died,s_CryptNiches[entry][E_CRYPT_NICHE_AGE],s_CryptNiches[entry][E_CRYPT_NICHE_CAUSE]);
	}
	else
	{
		format(dest,size,"Here lies ~y~%s~w~.~n~Born %s, died %s at %d.",s_CryptNiches[entry][E_CRYPT_NICHE_NAME],born,died,s_CryptNiches[entry][E_CRYPT_NICHE_AGE]);
	}
}

stock Crypt_GetNicheWorldPos(entry,&Float:x,&Float:y,&Float:z,&Float:rz,&world)
{
	new Float:localX, Float:localY, Float:localZ;
	Crypt_GetSlabPose(s_CryptNiches[entry][E_CRYPT_NICHE_INDEX],localX,localY,localZ,rz);
	Crypt_ToWorld(localX,localY,localZ,x,y,z);
	world = Crypt_GetWorld(s_CryptNiches[entry][E_CRYPT_NICHE_CRYPT]);
}

stock Crypt_ClearNiche(entry)
{
	if (IsValidDynamicObject(s_CryptNiches[entry][E_CRYPT_NICHE_SLAB]))
	{
		DestroyDynamicObject(s_CryptNiches[entry][E_CRYPT_NICHE_SLAB]);
	}

	if (IsValidDynamic3DTextLabel(s_CryptNiches[entry][E_CRYPT_NICHE_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_CryptNiches[entry][E_CRYPT_NICHE_LABEL]);
	}

	s_CryptNiches[entry][E_CRYPT_NICHE_SLAB] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_CryptNiches[entry][E_CRYPT_NICHE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock Crypt_RefreshNiche(entry)
{
	if (!Crypt_IsNicheValid(entry))
	{
		return;
	}

	Crypt_ClearNiche(entry);

	new Float:x, Float:y, Float:z, Float:rz, world, plaque[GRAVES_NAME_LEN + 24];
	Crypt_GetNicheWorldPos(entry,x,y,z,rz,world);
	s_CryptNiches[entry][E_CRYPT_NICHE_SLAB] = CreateDynamicObject(MODEL_CRYPT_NICHE_SLAB,x,y,z,0.0,0.0,rz,world,CRYPT_INTERIOR,-1,CRYPT_STREAM_RANGE,CRYPT_STREAM_RANGE);
	format(plaque,sizeof(plaque),"%s\n%d",s_CryptNiches[entry][E_CRYPT_NICHE_NAME],CALENDAR_EPOCH_YEAR + s_CryptNiches[entry][E_CRYPT_NICHE_DIED_DAY] / (CALENDAR_MONTHS * CALENDAR_DAYS_PER_MONTH));
	SetDynamicObjectMaterialText(s_CryptNiches[entry][E_CRYPT_NICHE_SLAB],1,plaque,_:OBJECT_MATERIAL_SIZE_256x128,"Times New Roman",20,1,0xFF2B2219,0,_:OBJECT_MATERIAL_TEXT_ALIGN_CENTER);

	s_CryptNiches[entry][E_CRYPT_NICHE_LABEL] = CreateDynamic3DTextLabel(s_CryptNiches[entry][E_CRYPT_NICHE_NAME],GRAVES_LABEL_COLOUR,x + 0.1 * floatsin(rz,degrees),y - 0.1 * floatcos(rz,degrees),z + 0.25,2.5,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,true,world,CRYPT_INTERIOR);
}

stock Crypt_AddNiche(row,crypt,niche,characterid,const name[],bornDay,diedDay,age,const cause[])
{
	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (s_CryptNiches[i][E_CRYPT_NICHE_USED])
		{
			continue;
		}

		s_CryptNiches[i][E_CRYPT_NICHE_USED] = true;
		s_CryptNiches[i][E_CRYPT_NICHE_ROW] = row;
		s_CryptNiches[i][E_CRYPT_NICHE_CRYPT] = crypt;
		s_CryptNiches[i][E_CRYPT_NICHE_INDEX] = niche;
		s_CryptNiches[i][E_CRYPT_NICHE_CHARACTER] = characterid;
		strcopy(s_CryptNiches[i][E_CRYPT_NICHE_NAME],name,GRAVES_NAME_LEN);
		strcopy(s_CryptNiches[i][E_CRYPT_NICHE_CAUSE],cause,GRAVES_CAUSE_LEN);
		s_CryptNiches[i][E_CRYPT_NICHE_BORN_DAY] = bornDay;
		s_CryptNiches[i][E_CRYPT_NICHE_DIED_DAY] = diedDay;
		s_CryptNiches[i][E_CRYPT_NICHE_AGE] = age;
		s_CryptNiches[i][E_CRYPT_NICHE_SLAB] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_CryptNiches[i][E_CRYPT_NICHE_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
		Crypt_RefreshNiche(i);
		return i;
	}

	return -1;
}

stock Crypt_RemoveNiche(entry)
{
	if (!Crypt_IsNicheValid(entry))
	{
		return;
	}

	Crypt_ClearNiche(entry);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM crypt_niches WHERE id = %d",s_CryptNiches[entry][E_CRYPT_NICHE_ROW]));
	s_CryptNiches[entry][E_CRYPT_NICHE_USED] = false;
}

stock Crypt_FindNicheByCharacter(characterid)
{
	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (s_CryptNiches[i][E_CRYPT_NICHE_USED] && s_CryptNiches[i][E_CRYPT_NICHE_CHARACTER] == characterid)
		{
			return i;
		}
	}

	return -1;
}

stock Crypt_FindNicheByRow(row)
{
	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (s_CryptNiches[i][E_CRYPT_NICHE_USED] && s_CryptNiches[i][E_CRYPT_NICHE_ROW] == row)
		{
			return i;
		}
	}

	return -1;
}

stock Crypt_CountNiches(crypt)
{
	new count = 0;

	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (s_CryptNiches[i][E_CRYPT_NICHE_USED] && s_CryptNiches[i][E_CRYPT_NICHE_CRYPT] == crypt)
		{
			count++;
		}
	}

	return count;
}

stock bool:Crypt_IsNicheTaken(crypt,niche)
{
	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (s_CryptNiches[i][E_CRYPT_NICHE_USED] && s_CryptNiches[i][E_CRYPT_NICHE_CRYPT] == crypt && s_CryptNiches[i][E_CRYPT_NICHE_INDEX] == niche)
		{
			return true;
		}
	}

	return false;
}

stock Crypt_FindFreeNiche(crypt)
{
	for (new niche = 0, total = Crypt_GetChambers(crypt) * CRYPT_NICHES_PER_CHAMBER;niche < total;niche++)
	{
		if (!Crypt_IsNicheTaken(crypt,niche))
		{
			return niche;
		}
	}

	return -1;
}

stock Crypt_FindNicheNear(playerid,Float:range)
{
	new world = GetPlayerVirtualWorld(playerid), crypt = Crypt_FindByWorld(world), best = -1, Float:bestDistance = range;

	if (crypt == -1)
	{
		return -1;
	}

	for (new i = 0;i < CRYPT_NICHE_SLOTS;i++)
	{
		if (!s_CryptNiches[i][E_CRYPT_NICHE_USED] || s_CryptNiches[i][E_CRYPT_NICHE_CRYPT] != crypt)
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:rz, nicheWorld;
		Crypt_GetNicheWorldPos(i,x,y,z,rz,nicheWorld);
		new Float:distance = GetPlayerDistanceFromPoint(playerid,x + 0.6 * floatsin(rz,degrees),y - 0.6 * floatcos(rz,degrees),z + 0.6);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Crypt_FindDoorNear(playerid,Float:range = CRYPT_DOOR_REACH)
{
	new world = GetPlayerVirtualWorld(playerid);

	for (new i = 0;i < CRYPT_MAX;i++)
	{
		if (s_Crypts[i][E_CRYPT_USED] && s_Crypts[i][E_CRYPT_DOOR_WORLD] == world && IsPlayerInRangeOfPoint(playerid,range,s_Crypts[i][E_CRYPT_DOOR][0],s_Crypts[i][E_CRYPT_DOOR][1],s_Crypts[i][E_CRYPT_DOOR][2]))
		{
			return i;
		}
	}

	return -1;
}

stock Crypt_FindExitNear(playerid,Float:range = CRYPT_DOOR_REACH)
{
	new crypt = Crypt_FindByWorld(GetPlayerVirtualWorld(playerid)), Float:x, Float:y, Float:z;

	if (crypt == -1)
	{
		return -1;
	}

	Crypt_ToWorld(0.0,3.4,3.0,x,y,z);
	return IsPlayerInRangeOfPoint(playerid,range + 1.0,x,y,z + 1.0) ? crypt : -1;
}

stock Crypt_Enter(playerid,crypt)
{
	if (!Crypt_IsValid(crypt))
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	Crypt_ToWorld(0.0,3.0,3.0,x,y,z);
	Util_SafeTeleport(playerid,x,y,z + 1.0,180.0,Crypt_GetWorld(crypt),CRYPT_INTERIOR);
	Gui_Notify(playerid,"You go down the stairs into the crypt. It's cold and quiet.");
}

stock bool:Crypt_GetDoorPose(crypt,&Float:x,&Float:y,&Float:z,&Float:angle)
{
    if (!Crypt_IsValid(crypt))
    {
        return false;
    }
    x = s_Crypts[crypt][E_CRYPT_DOOR][0];
    y = s_Crypts[crypt][E_CRYPT_DOOR][1];
    z = s_Crypts[crypt][E_CRYPT_DOOR][2];
    angle = s_Crypts[crypt][E_CRYPT_DOOR][3];
    return true;
}

stock bool:Crypt_GetExitPose(crypt,&Float:x,&Float:y,&Float:z,&Float:angle)
{
    if (!Crypt_GetDoorPose(crypt,x,y,z,angle))
    {
        return false;
    }
    x -= 1.2 * floatsin(angle,degrees);
    y += 1.2 * floatcos(angle,degrees);
    if (s_Crypts[crypt][E_CRYPT_DOOR_WORLD] == 0 && s_Crypts[crypt][E_CRYPT_DOOR_INTERIOR] == 0)
    {
        new Float:hitX, Float:hitY, Float:ground;
        if (CA_RayCastLine(x,y,z + 3.0,x,y,z - 10.0,hitX,hitY,ground) != 0)
        {
            z = ground;
        }
    }
    z += 1.0;
    return true;
}

stock Crypt_Leave(playerid,crypt)
{
	if (!Crypt_IsValid(crypt))
	{
		return;
	}

    new Float:x, Float:y, Float:z, Float:angle;
    if (Crypt_GetExitPose(crypt,x,y,z,angle))
    {
        Util_SafeTeleport(playerid,x,y,z,angle,s_Crypts[crypt][E_CRYPT_DOOR_WORLD],s_Crypts[crypt][E_CRYPT_DOOR_INTERIOR]);
    }
}

#pragma warning push
#pragma warning disable 204
forward Task:Crypt_Create(const key[],Float:x,Float:y,Float:z,Float:a,world,interior);

async Task:Crypt_Create(const key[],Float:x,Float:y,Float:z,Float:a,world,interior)
{
	new keyCopy[GRAVES_KEY_LEN];
	strcopy(keyCopy,key);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO crypts (crypt_key, door_x, door_y, door_z, door_a, door_world, door_interior, chambers) VALUES ('%e', %f, %f, %f, %f, %d, %d, 1)",keyCopy,x,y,z,a,world,interior));

	new row = cache_insert_id();
	return async row > 0 ? Crypt_Add(row,keyCopy,x,y,z,a,world,interior,1) : -1;
}

async Task:Crypt_Inter(characterid,const name[],bornDay,diedDay,age,const cause[])
{
	new nameCopy[GRAVES_NAME_LEN], causeCopy[GRAVES_CAUSE_LEN], crypt = -1, niche = -1;
	strcopy(nameCopy,name);
	strcopy(causeCopy,cause);

	for (new i = 0;i < CRYPT_MAX && niche == -1;i++)
	{
		if (!s_Crypts[i][E_CRYPT_USED])
		{
			continue;
		}

		niche = Crypt_FindFreeNiche(i);

		if (niche == -1 && Crypt_Grow(i))
		{
			niche = Crypt_FindFreeNiche(i);
		}

		if (niche != -1)
		{
			crypt = i;
		}
	}

	if (crypt == -1)
	{
		wait_ticks(1);
		return async -1;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO crypt_niches (crypt_id, niche, character_id) VALUES (%d, %d, %d)",s_Crypts[crypt][E_CRYPT_ROW],niche,characterid));

	new row = cache_insert_id(), entry = row > 0 ? Crypt_AddNiche(row,crypt,niche,characterid,nameCopy,bornDay,diedDay,age,causeCopy) : -1;

	if (entry != -1)
	{
		Funeral_Schedule(characterid,0,row,nameCopy,s_Crypts[crypt][E_CRYPT_KEY]);
		pawn_call_public("Crypt_OnInterred","dd",characterid,entry);
	}

	return async entry;
}
#pragma warning pop

forward Crypt_OnGrown(crypt,chambers);

public Crypt_OnGrown(crypt,chambers)
{
	return 1;
}

forward Crypt_OnInterred(characterid,entry);

public Crypt_OnInterred(characterid,entry)
{
	return 1;
}

forward Crypt_LoadOnBoot();

public Crypt_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, crypt_key, door_x, door_y, door_z, door_a, door_world, door_interior, chambers FROM crypts ORDER BY id"));

	new crypts = 0, niches = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, key[GRAVES_KEY_LEN], Float:door[4], world, interior, chambers;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"crypt_key",key);
		cache_get_value_name_float(r,"door_x",door[0]);
		cache_get_value_name_float(r,"door_y",door[1]);
		cache_get_value_name_float(r,"door_z",door[2]);
		cache_get_value_name_float(r,"door_a",door[3]);
		cache_get_value_name_int(r,"door_world",world);
		cache_get_value_name_int(r,"door_interior",interior);
		cache_get_value_name_int(r,"chambers",chambers);

		if (Crypt_Add(row,key,door[0],door[1],door[2],door[3],world,interior,chambers) != -1)
		{
			crypts++;
		}
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT n.id, n.crypt_id, n.niche, n.character_id, IFNULL(c.name, '') AS name, IFNULL(c.surname, '') AS surname, IFNULL(c.born_day, 0) AS born_day, IFNULL(c.died_day, 0) AS died_day, IFNULL(c.died_age, 0) AS died_age, IFNULL(c.death_cause, '') AS death_cause FROM crypt_niches n LEFT JOIN characters c ON c.id = n.character_id ORDER BY n.id"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, cryptRow, niche, characterid, first[24], surname[24], name[GRAVES_NAME_LEN], cause[GRAVES_CAUSE_LEN], bornDay, diedDay, age;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name_int(r,"crypt_id",cryptRow);
		cache_get_value_name_int(r,"niche",niche);
		cache_get_value_name_int(r,"character_id",characterid);
		cache_get_value_name(r,"name",first);
		cache_get_value_name(r,"surname",surname);
		cache_get_value_name_int(r,"born_day",bornDay);
		cache_get_value_name_int(r,"died_day",diedDay);
		cache_get_value_name_int(r,"died_age",age);
		cache_get_value_name(r,"death_cause",cause);
		format(name,sizeof(name),"%s %s",first,surname);

		new crypt = Crypt_FindByRow(cryptRow);

		if (crypt != -1 && Crypt_AddNiche(row,crypt,niche,characterid,name,bornDay,diedDay,age,cause) != -1)
		{
			niches++;
		}
	}

	Log_Info("graves","%d crypt(s), %d niche(s) sealed",crypts,niches);
	Boot_LoaderDone();
}
