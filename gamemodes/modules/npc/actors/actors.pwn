enum E_ACTOR
{
	bool:E_ACTOR_USED,
	E_ACTOR_KEY[ACTORS_KEY_LEN],
	E_ACTOR_ROLE:E_ACTOR_ROLE_ID,
	E_ACTOR_KIND:E_ACTOR_KIND_ID,
	E_ACTOR_SEX,
	E_ACTOR_SKIN,
	E_ACTOR_NAME[ACTORS_NAME_LEN],
	E_ACTOR_TITLE[ACTORS_TITLE_LEN],
	E_ACTOR_PERSONA,
	E_ACTOR_OWNER,
	E_ACTOR_DB_ID,
	Float:E_ACTOR_POS[4],
	E_ACTOR_WORLD,
	E_ACTOR_INTERIOR,
	E_ACTOR_ANIM_LIB[16],
	E_ACTOR_ANIM_NAME[24],
	bool:E_ACTOR_ANIM_LOOP,
	bool:E_ACTOR_PLACED,
	bool:E_ACTOR_STAY,
	E_ACTOR_BODY,
	bool:E_ACTOR_IS_PED,
    bool:E_ACTOR_EXTERNAL,
    bool:E_ACTOR_IS_RIDER,
	bool:E_ACTOR_WALKING,
    bool:E_ACTOR_DIRECT,
	Float:E_ACTOR_GOAL[4],
	E_ACTOR_FLEE_UNTIL,
	STREAMER_TAG_3D_TEXT_LABEL:E_ACTOR_LABEL,
	STREAMER_TAG_3D_TEXT_LABEL:E_ACTOR_BUBBLE,
	E_ACTOR_BUBBLE_UNTIL,
	Float:E_ACTOR_HEALTH,
	bool:E_ACTOR_HURT,
	E_ACTOR_DEAD_UNTIL,
	E_ACTOR_CORPSE_UNTIL,
	bool:E_ACTOR_OPEN,
	bool:E_ACTOR_CAN_ACT,
	bool:E_ACTOR_INVULNERABLE,
}

enum E_ACTOR_ROW
{
	E_ACTOR_ROW_ID,
	E_ACTOR_ROW_KEY[ACTORS_KEY_LEN],
	E_ACTOR_ROW_SKIN,
	E_ACTOR_ROW_NAME[ACTORS_NAME_LEN],
	E_ACTOR_ROW_DEAD_UNTIL,
	bool:E_ACTOR_ROW_CAN_ACT,
}

static s_Actors[ACTORS_MAX][E_ACTOR];
static s_ActorOfBody[MAX_ACTORS] = {-1, ...};
static s_ActorRows[ACTORS_MAX][E_ACTOR_ROW];
static s_ActorRowCount;
static s_ActorTalkTargets[MAX_PLAYERS] = {-1, ...};
static s_ActorMenuTargets[MAX_PLAYERS] = {-1, ...};
static s_ActorApproachTargets[MAX_PLAYERS] = {-1, ...};

stock bool:Actors_IsValid(index)
{
	return index >= 0 && index < ACTORS_MAX && s_Actors[index][E_ACTOR_USED];
}

stock Actors_FindByKey(const key[])
{
	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (s_Actors[i][E_ACTOR_USED] && !strcmp(s_Actors[i][E_ACTOR_KEY],key))
		{
			return i;
		}
	}

	return -1;
}

stock Actors_FindByBody(body)
{
	if (body < 0 || body >= MAX_ACTORS)
	{
		return -1;
	}

	return s_ActorOfBody[body];
}

stock Actors_Count()
{
	new count = 0;

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (s_Actors[i][E_ACTOR_USED])
		{
			count++;
		}
	}

	return count;
}

stock Actors_GetName(index,dest[],size = sizeof(dest))
{
	if (!Actors_IsValid(index))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Actors[index][E_ACTOR_NAME],size);
}

static const s_ActorHonorifics[][8] = {"Brother", "Sister", "Father", "Mother", "Friar", "Abbot", "Abbess", "Prior"};

stock Actors_GetFirstName(index,dest[],size = sizeof(dest))
{
	Actors_GetName(index,dest,size);
	new space = strfind(dest," ");

	if (space == -1)
	{
		return;
	}

	for (new i = 0;i < sizeof(s_ActorHonorifics);i++)
	{
		if (space == strlen(s_ActorHonorifics[i]) && !strcmp(dest,s_ActorHonorifics[i],false,space))
		{
			new second = strfind(dest," ",false,space + 1);

			if (second != -1)
			{
				dest[second] = EOS;
			}

			return;
		}
	}

	dest[space] = EOS;
}

stock Actors_GetTitle(index,dest[],size = sizeof(dest))
{
	if (!Actors_IsValid(index))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Actors[index][E_ACTOR_TITLE],size);
}

stock Actors_GetKey(index,dest[],size = sizeof(dest))
{
	if (!Actors_IsValid(index))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Actors[index][E_ACTOR_KEY],size);
}

stock E_ACTOR_ROLE:Actors_GetRole(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_ROLE_ID] : ACTOR_ROLE_VILLAGER;
}

stock Actors_GetSex(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_SEX] : 0;
}

stock Actors_GetSkin(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_SKIN] : 0;
}

stock Actors_GetOwner(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_OWNER] : -1;
}

stock Actors_GetPersona(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_PERSONA] : 0;
}

stock Actors_GetDbId(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_DB_ID] : 0;
}

stock Actors_GetWorld(index)
{
    if (Actors_IsPlaced(index) && s_Actors[index][E_ACTOR_IS_RIDER])
    {
        return GetPlayerVirtualWorld(s_Actors[index][E_ACTOR_BODY]);
    }

	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_WORLD] : 0;
}

stock Actors_GetBody(index)
{
	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_PLACED] ? s_Actors[index][E_ACTOR_BODY] : INVALID_ACTOR_ID;
}

stock bool:Actors_GetAnimation(index,library[],librarySize,name[],nameSize,&bool:loop)
{
    library[0] = EOS;
    name[0] = EOS;
    loop = false;
    if (!Actors_IsValid(index) || s_Actors[index][E_ACTOR_IS_RIDER])
    {
        return false;
    }

    if (!Actors_IsPlaced(index))
    {
        strcopy(library,s_Actors[index][E_ACTOR_ANIM_LIB],librarySize);
        strcopy(name,s_Actors[index][E_ACTOR_ANIM_NAME],nameSize);
        loop = s_Actors[index][E_ACTOR_ANIM_LOOP];
        return library[0] != EOS && name[0] != EOS;
    }

    new Float:delta;
    return GetActorAnimation(s_Actors[index][E_ACTOR_BODY],library,librarySize,name,nameSize,delta,loop);
}

stock bool:Actors_IsPlaced(index)
{
    if (Actors_IsValid(index) && s_Actors[index][E_ACTOR_IS_RIDER])
    {
        return s_Actors[index][E_ACTOR_PLACED] && Rider_IsValid(s_Actors[index][E_ACTOR_BODY]);
    }

	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_PLACED] && (!s_Actors[index][E_ACTOR_EXTERNAL] || (IsValidActor(s_Actors[index][E_ACTOR_BODY]) && (!s_Actors[index][E_ACTOR_IS_PED] || IsValidPedestrian(s_Actors[index][E_ACTOR_BODY]) == 1)));
}

stock bool:Actors_IsWalking(index)
{
	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_WALKING];
}

stock bool:Actors_IsDead(index)
{
	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_DEAD_UNTIL] > 0;
}

stock bool:Actors_IsOpen(index)
{
    if (Actors_IsValid(index) && s_Actors[index][E_ACTOR_IS_RIDER] && Rider_IsMoving(s_Actors[index][E_ACTOR_BODY]))
    {
        return false;
    }

	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_OPEN] && s_Actors[index][E_ACTOR_DEAD_UNTIL] == 0;
}

stock Actors_SetOpen(index,bool:isOpen)
{
	if (Actors_IsValid(index))
	{
		s_Actors[index][E_ACTOR_OPEN] = isOpen;
	}
}

stock Actors_SetInvulnerable(index,bool:isInvulnerable)
{
	if (Actors_IsValid(index))
	{
		s_Actors[index][E_ACTOR_INVULNERABLE] = isInvulnerable;
	}
}

stock bool:Actors_IsInvulnerable(index)
{
	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_INVULNERABLE];
}

stock bool:Actors_CanAct(index)
{
	return Actors_IsValid(index) && s_Actors[index][E_ACTOR_CAN_ACT];
}

stock Float:Actors_GetHealth(index)
{
	return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_HEALTH] : 0.0;
}

stock Actors_GetByRole(E_ACTOR_ROLE:role,countyid = 0)
{
	#pragma unused countyid

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (s_Actors[i][E_ACTOR_USED] && s_Actors[i][E_ACTOR_ROLE_ID] == role && s_Actors[i][E_ACTOR_DEAD_UNTIL] == 0)
		{
			return i;
		}
	}

	return -1;
}

stock Actors_RestoreInterior(playerid)
{
    if (!Util_IsInteriorReady(playerid))
    {
        return 0;
    }

    new world, interior, restored, Float:destinationX, Float:destinationY, Float:destinationZ;

    if (!Util_GetTeleportDestination(playerid,destinationX,destinationY,destinationZ,world,interior))
    {
        return 0;
    }

    for (new i = 0;i < ACTORS_MAX;i++)
    {
        if (!Actors_IsPlaced(i) || s_Actors[i][E_ACTOR_IS_RIDER] || s_Actors[i][E_ACTOR_WORLD] != world || s_Actors[i][E_ACTOR_INTERIOR] != interior)
        {
            continue;
        }

        new body = Actors_GetBody(i), Float:x, Float:y, Float:z;

        if (!IsValidActor(body))
        {
            continue;
        }

        if (s_Actors[i][E_ACTOR_IS_PED] || s_Actors[i][E_ACTOR_EXTERNAL])
        {
            GetActorPos(body,x,y,z);
        }
        else
        {
            x = s_Actors[i][E_ACTOR_POS][0];
            y = s_Actors[i][E_ACTOR_POS][1];
            z = s_Actors[i][E_ACTOR_POS][2];
        }

        if (VectorSize(x - destinationX,y - destinationY,z - destinationZ) <= 200.0 && SetActorPos(body,x,y,z))
        {
            Actors_SyncLabels(i);
            restored++;
        }
    }

    return restored;
}

stock bool:Actors_GetPos(index,&Float:x,&Float:y,&Float:z,&Float:a = 0.0)
{
	if (!Actors_IsValid(index))
	{
		return false;
	}

    if (s_Actors[index][E_ACTOR_IS_RIDER])
    {
        return Rider_GetPos(s_Actors[index][E_ACTOR_BODY],x,y,z,a);
    }

	if (s_Actors[index][E_ACTOR_PLACED] && s_Actors[index][E_ACTOR_IS_PED] && IsValidPedestrian(s_Actors[index][E_ACTOR_BODY]) == 1)
	{
		GetPedestrianPos(s_Actors[index][E_ACTOR_BODY],x,y,z);
		a = GetPedestrianFacingAngle(s_Actors[index][E_ACTOR_BODY]);
		return true;
	}

	if (s_Actors[index][E_ACTOR_PLACED] && IsValidActor(s_Actors[index][E_ACTOR_BODY]))
	{
		GetActorPos(s_Actors[index][E_ACTOR_BODY],x,y,z);
		GetActorFacingAngle(s_Actors[index][E_ACTOR_BODY],a);
		return true;
	}

	x = s_Actors[index][E_ACTOR_POS][0];
	y = s_Actors[index][E_ACTOR_POS][1];
	z = s_Actors[index][E_ACTOR_POS][2];
	a = s_Actors[index][E_ACTOR_POS][3];
	return true;
}

stock Actors_CountRows()
{
	return s_ActorRowCount;
}

static Actors_FindRow(const key[])
{
	for (new i = 0;i < s_ActorRowCount;i++)
	{
		if (!strcmp(s_ActorRows[i][E_ACTOR_ROW_KEY],key))
		{
			return i;
		}
	}

	return -1;
}

forward Task:Actors_LoadRows();
#pragma warning push
#pragma warning disable 204
async Task:Actors_LoadRows()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, actor_key, skin, name, can_act, IFNULL(dead_until, 0) AS dead_until FROM actors ORDER BY id"));
	new rows = cache_num_rows();
	s_ActorRowCount = 0;

	for (new row = 0;row < rows && s_ActorRowCount < ACTORS_MAX;row++)
	{
		new canAct;
		cache_get_value_name_int(row,"id",s_ActorRows[s_ActorRowCount][E_ACTOR_ROW_ID]);
		cache_get_value_name(row,"actor_key",s_ActorRows[s_ActorRowCount][E_ACTOR_ROW_KEY],ACTORS_KEY_LEN);
		cache_get_value_name_int(row,"skin",s_ActorRows[s_ActorRowCount][E_ACTOR_ROW_SKIN]);
		cache_get_value_name(row,"name",s_ActorRows[s_ActorRowCount][E_ACTOR_ROW_NAME],ACTORS_NAME_LEN);
		cache_get_value_name_int(row,"can_act",canAct);
		cache_get_value_name_int(row,"dead_until",s_ActorRows[s_ActorRowCount][E_ACTOR_ROW_DEAD_UNTIL]);
		s_ActorRows[s_ActorRowCount][E_ACTOR_ROW_CAN_ACT] = canAct != 0;
		s_ActorRowCount++;
	}

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (s_Actors[i][E_ACTOR_USED] && s_Actors[i][E_ACTOR_DB_ID] == 0)
		{
			new row = Actors_FindRow(s_Actors[i][E_ACTOR_KEY]);

			if (row != -1)
			{
				s_Actors[i][E_ACTOR_DB_ID] = s_ActorRows[row][E_ACTOR_ROW_ID];
			}
		}
	}

	return async s_ActorRowCount;
}
#pragma warning pop

stock Actors_Register(const key[],E_ACTOR_ROLE:role,E_ACTOR_KIND:kind,sex,skin,const name[],const title[] = "",persona = 0,owner = -1,bool:persistent = true)
{
	new index = Actors_FindByKey(key);

	if (index == -1)
	{
		for (new i = 0;i < ACTORS_MAX;i++)
		{
			if (!s_Actors[i][E_ACTOR_USED])
			{
				index = i;
				break;
			}
		}
	}

	if (index == -1)
	{
		Log_Error("actors","registry full, '%s' not registered",key);
		return -1;
	}

	if (s_Actors[index][E_ACTOR_PLACED])
	{
		Actors_Remove(index);
	}

	s_Actors[index][E_ACTOR_USED] = true;
	strcopy(s_Actors[index][E_ACTOR_KEY],key,ACTORS_KEY_LEN);
	s_Actors[index][E_ACTOR_ROLE_ID] = role;
	s_Actors[index][E_ACTOR_KIND_ID] = kind;
	s_Actors[index][E_ACTOR_SEX] = sex;
	s_Actors[index][E_ACTOR_SKIN] = skin;
	strcopy(s_Actors[index][E_ACTOR_NAME],name,ACTORS_NAME_LEN);
	strcopy(s_Actors[index][E_ACTOR_TITLE],title[0] != EOS ? title : g_ActorRoleNames[role],ACTORS_TITLE_LEN);
	s_Actors[index][E_ACTOR_PERSONA] = persona;
	s_Actors[index][E_ACTOR_OWNER] = owner;
	s_Actors[index][E_ACTOR_DB_ID] = 0;
	s_Actors[index][E_ACTOR_ANIM_LIB][0] = EOS;
	s_Actors[index][E_ACTOR_ANIM_NAME][0] = EOS;
	s_Actors[index][E_ACTOR_PLACED] = false;
	s_Actors[index][E_ACTOR_STAY] = false;
	s_Actors[index][E_ACTOR_BODY] = INVALID_ACTOR_ID;
	s_Actors[index][E_ACTOR_IS_PED] = false;
    s_Actors[index][E_ACTOR_EXTERNAL] = false;
    s_Actors[index][E_ACTOR_IS_RIDER] = false;
	s_Actors[index][E_ACTOR_WALKING] = false;
	s_Actors[index][E_ACTOR_FLEE_UNTIL] = 0;
	s_Actors[index][E_ACTOR_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	s_Actors[index][E_ACTOR_BUBBLE] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	s_Actors[index][E_ACTOR_HEALTH] = ACTORS_HEALTH;
	s_Actors[index][E_ACTOR_HURT] = false;
	s_Actors[index][E_ACTOR_DEAD_UNTIL] = 0;
	s_Actors[index][E_ACTOR_CORPSE_UNTIL] = 0;
	s_Actors[index][E_ACTOR_OPEN] = true;
	s_Actors[index][E_ACTOR_CAN_ACT] = true;
	s_Actors[index][E_ACTOR_INVULNERABLE] = false;

	new row = persistent ? Actors_FindRow(key) : -1;

	if (row != -1)
	{
		s_Actors[index][E_ACTOR_DB_ID] = s_ActorRows[row][E_ACTOR_ROW_ID];
		s_Actors[index][E_ACTOR_CAN_ACT] = s_ActorRows[row][E_ACTOR_ROW_CAN_ACT];

		if (s_ActorRows[row][E_ACTOR_ROW_SKIN] > 0)
		{
			s_Actors[index][E_ACTOR_SKIN] = s_ActorRows[row][E_ACTOR_ROW_SKIN];
		}

		if (s_ActorRows[row][E_ACTOR_ROW_DEAD_UNTIL] > gettime())
		{
			s_Actors[index][E_ACTOR_DEAD_UNTIL] = s_ActorRows[row][E_ACTOR_ROW_DEAD_UNTIL];
		}
	}
	else if (persistent && IsDatabaseReady())
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO actors (actor_key, role, kind, skin, name, home_place_key, schedule, persona, can_act) VALUES ('%e', %d, %d, %d, '%e', '', 0, %d, 1)",key,_:role,_:kind,skin,name,persona));
	}

	return index;
}

stock Actors_RegisterBody(const key[],body,sex,const name[],const title[],world = -1,interior = 0,const roleName[] = "villager",owner = -1)
{
    if (!IsValidActor(body))
    {
        return -1;
    }

    new existing = Actors_FindByBody(body);

    if (existing != -1)
    {
        return existing;
    }

    new E_ACTOR_ROLE:role = ACTOR_ROLE_VILLAGER;

    for (new i = 0;i < _:ACTOR_ROLE_COUNT;i++)
    {
        if (!strcmp(roleName,g_ActorRoleNames[i],true))
        {
            role = E_ACTOR_ROLE:i;
            break;
        }
    }

    new index = Actors_Register(key,role,ACTOR_KIND_STATIC,sex,GetActorSkin(body),name,title,0,owner,false);

    if (index == -1)
    {
        return -1;
    }

    s_Actors[index][E_ACTOR_EXTERNAL] = true;
    s_Actors[index][E_ACTOR_IS_PED] = IsValidPedestrian(body) == 1;
    s_Actors[index][E_ACTOR_BODY] = body;
    s_Actors[index][E_ACTOR_PLACED] = true;
    s_Actors[index][E_ACTOR_WORLD] = world == -1 ? GetActorVirtualWorld(body) : world;
    s_Actors[index][E_ACTOR_INTERIOR] = interior;
    s_ActorOfBody[body] = index;
    return index;
}

#define ACTORS_WALKER_KINDS (16)

enum E_ACTOR_WALKER_KIND
{
    E_ACTOR_WALKER_KIND_ID,
    E_ACTOR_ROLE:E_ACTOR_WALKER_ROLE,
    E_ACTOR_WALKER_NAME[ACTORS_NAME_LEN],
    E_ACTOR_WALKER_TITLE[ACTORS_TITLE_LEN],
}

static s_ActorWalkerKinds[ACTORS_WALKER_KINDS][E_ACTOR_WALKER_KIND];
static s_ActorWalkerKindCount;

stock bool:Actors_RegisterWalkerKind(kind,E_ACTOR_ROLE:role,const name[],const title[])
{
    new slot = Actors_FindWalkerKind(kind);
    if (slot == -1)
    {
        if (s_ActorWalkerKindCount == ACTORS_WALKER_KINDS)
        {
            return false;
        }
        slot = s_ActorWalkerKindCount++;
    }
    s_ActorWalkerKinds[slot][E_ACTOR_WALKER_KIND_ID] = kind;
    s_ActorWalkerKinds[slot][E_ACTOR_WALKER_ROLE] = role;
    strcopy(s_ActorWalkerKinds[slot][E_ACTOR_WALKER_NAME],name,ACTORS_NAME_LEN);
    strcopy(s_ActorWalkerKinds[slot][E_ACTOR_WALKER_TITLE],title,ACTORS_TITLE_LEN);
    return true;
}

stock Actors_FindWalkerKind(kind)
{
    for (new i = 0; i < s_ActorWalkerKindCount; i++)
    {
        if (s_ActorWalkerKinds[i][E_ACTOR_WALKER_KIND_ID] == kind)
        {
            return i;
        }
    }
    return -1;
}

stock Actors_EnsureWalker(body)
{
    if (IsValidPedestrian(body) != 1 || GetPedestrianHealth(body) <= 0.0)
    {
        return -1;
    }
    new pedestrianKind = GetPedestrianKind(body);
    new existing = Actors_FindByBody(body);
    if (existing != -1)
    {
        return existing;
    }
    new kind = Actors_FindWalkerKind(pedestrianKind);
    if (kind == -1)
    {
        return -1;
    }
    return Actors_RegisterBody(sprintf("walker:%d",body),body,GetPedestrianSex(body) == 2 ? 1 : 0,s_ActorWalkerKinds[kind][E_ACTOR_WALKER_NAME],s_ActorWalkerKinds[kind][E_ACTOR_WALKER_TITLE],-1,0,g_ActorRoleNames[_:s_ActorWalkerKinds[kind][E_ACTOR_WALKER_ROLE]]);
}

stock Actors_RegisterRider(const key[],riderid,const name[],const title[])
{
    if (!Rider_IsValid(riderid))
    {
        return -1;
    }

    new index = Actors_Register(key,ACTOR_ROLE_VILLAGER,ACTOR_KIND_STATIC,0,GetPlayerCustomSkin(riderid) > 0 ? GetPlayerCustomSkin(riderid) : GetPlayerSkin(riderid),name,title,0,-1,false);

    if (index != -1)
    {
        s_Actors[index][E_ACTOR_EXTERNAL] = true;
        s_Actors[index][E_ACTOR_IS_RIDER] = true;
        s_Actors[index][E_ACTOR_BODY] = riderid;
        s_Actors[index][E_ACTOR_PLACED] = true;
        s_Actors[index][E_ACTOR_WORLD] = GetPlayerVirtualWorld(riderid);
    }

    return index;
}

stock Actors_UnregisterBody(body)
{
    new index = Actors_FindByBody(body);

    if (index != -1)
    {
        Actors_Unregister(index);
    }
}

stock Actors_Unregister(index)
{
	if (!Actors_IsValid(index))
	{
		return;
	}

	pawn_call_public("Actors_OnRemoved","d",index);

    foreach (new playerid : Player)
    {
        Actors_ForgetReleasedPrompt(playerid,index);
        if (s_ActorTalkTargets[playerid] == index)
        {
            s_ActorTalkTargets[playerid] = -1;
        }

        if (s_ActorApproachTargets[playerid] == index)
        {
            s_ActorApproachTargets[playerid] = -1;
        }

        if (s_ActorMenuTargets[playerid] == index)
        {
            s_ActorMenuTargets[playerid] = -1;
        }
    }

	Actors_Remove(index);
	s_Actors[index][E_ACTOR_USED] = false;
	s_Actors[index][E_ACTOR_KEY][0] = EOS;
}

stock STREAMER_TAG_3D_TEXT_LABEL:Actors_GetLabel(index)
{
    return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_LABEL] : STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock STREAMER_TAG_3D_TEXT_LABEL:Actors_GetBubble(index)
{
    return Actors_IsValid(index) ? s_Actors[index][E_ACTOR_BUBBLE] : STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
}

stock Actors_SyncLabels(index)
{
    if (!Actors_IsPlaced(index))
    {
        return;
    }

    new Float:x, Float:y, Float:z;
    Actors_GetPos(index,x,y,z);
    if (s_Actors[index][E_ACTOR_IS_PED])
    {
        z += ACTORS_PED_LIFT;
    }

    new STREAMER_TAG_3D_TEXT_LABEL:labels[2];
    labels[0] = Actors_GetLabel(index);
    labels[1] = Actors_GetBubble(index);
    for (new i = 0;i < sizeof(labels);i++)
    {
        if (!IsValidDynamic3DTextLabel(labels[i]))
        {
            continue;
        }

        if (Streamer_GetIntData(STREAMER_TYPE_3D_TEXT_LABEL,labels[i],E_STREAMER_WORLD_ID) != s_Actors[index][E_ACTOR_WORLD])
        {
            Streamer_SetIntData(STREAMER_TYPE_3D_TEXT_LABEL,labels[i],E_STREAMER_WORLD_ID,s_Actors[index][E_ACTOR_WORLD]);
        }
        if (Streamer_GetIntData(STREAMER_TYPE_3D_TEXT_LABEL,labels[i],E_STREAMER_INTERIOR_ID) != s_Actors[index][E_ACTOR_INTERIOR])
        {
            Streamer_SetIntData(STREAMER_TYPE_3D_TEXT_LABEL,labels[i],E_STREAMER_INTERIOR_ID,s_Actors[index][E_ACTOR_INTERIOR]);
        }

        new Float:height = i == 0 ? Actors_GetLabelZ(index) : ACTORS_BUBBLE_Z + 0.25;
        new Float:oldX, Float:oldY, Float:oldZ;
        Streamer_GetItemPos(STREAMER_TYPE_3D_TEXT_LABEL,labels[i],oldX,oldY,oldZ);
        if (oldX != x || oldY != y || oldZ != z + height)
        {
            Streamer_SetItemPos(STREAMER_TYPE_3D_TEXT_LABEL,labels[i],x,y,z + height);
            Nearby_QueueStream(STREAMER_TYPE_3D_TEXT_LABEL,x,y,z,s_Actors[index][E_ACTOR_WORLD],s_Actors[index][E_ACTOR_INTERIOR],-1,STREAMER_3D_TEXT_LABEL_SD);
        }
    }
}

stock Actors_SetPlace(index,Float:x,Float:y,Float:z,Float:a,world = 0,interior = 0)
{
	if (!Actors_IsValid(index))
	{
		return;
	}

	s_Actors[index][E_ACTOR_POS][0] = x;
	s_Actors[index][E_ACTOR_POS][1] = y;
	s_Actors[index][E_ACTOR_POS][2] = z;
	s_Actors[index][E_ACTOR_POS][3] = a;
	s_Actors[index][E_ACTOR_WORLD] = world;
	s_Actors[index][E_ACTOR_INTERIOR] = interior;
}

static Actors_ApplyAnim(index)
{
	if (!s_Actors[index][E_ACTOR_PLACED] || s_Actors[index][E_ACTOR_IS_PED] || s_Actors[index][E_ACTOR_IS_RIDER] || !IsValidActor(s_Actors[index][E_ACTOR_BODY]))
	{
		return;
	}

	if (s_Actors[index][E_ACTOR_ANIM_LIB][0] == EOS)
	{
		ClearActorAnimations(s_Actors[index][E_ACTOR_BODY]);
		return;
	}

	ApplyActorAnimation(s_Actors[index][E_ACTOR_BODY],s_Actors[index][E_ACTOR_ANIM_LIB],s_Actors[index][E_ACTOR_ANIM_NAME],4.1,s_Actors[index][E_ACTOR_ANIM_LOOP],false,false,true,0);
}

stock Actors_SetAnim(index,const lib[],const name[],bool:loop = true)
{
	if (!Actors_IsValid(index))
	{
		return;
	}

	strcopy(s_Actors[index][E_ACTOR_ANIM_LIB],lib,16);
	strcopy(s_Actors[index][E_ACTOR_ANIM_NAME],name,24);
	s_Actors[index][E_ACTOR_ANIM_LOOP] = loop;

	if (lib[0] != EOS)
	{
		AnimPreload_Register(lib);
	}

	Actors_ApplyAnim(index);

	if (s_Actors[index][E_ACTOR_LABEL] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID && !s_Actors[index][E_ACTOR_IS_PED])
	{
        Actors_SyncLabels(index);
	}
}

stock Float:Actors_GetLabelZ(index)
{
	if (!Actors_IsValid(index))
	{
		return ACTORS_LABEL_Z;
	}

	if (!strcmp(s_Actors[index][E_ACTOR_ANIM_NAME],"BED_",false,4))
	{
		return ACTORS_LABEL_LYING_Z;
	}

	if (strfind(s_Actors[index][E_ACTOR_ANIM_NAME],"Sit",true) != -1 || strfind(s_Actors[index][E_ACTOR_ANIM_NAME],"CRCH",true) != -1 || !strcmp(s_Actors[index][E_ACTOR_ANIM_NAME],"BOM_Plant",true,9))
	{
		return ACTORS_LABEL_LOW_Z;
	}

	return ACTORS_LABEL_Z;
}

static Actors_FormatLabel(index,dest[],size = sizeof(dest))
{
	format(dest,size,"%s\n{9C8D74}%s",s_Actors[index][E_ACTOR_NAME],s_Actors[index][E_ACTOR_TITLE]);
}

static Actors_MakeLabel(index,Float:x,Float:y,Float:z)
{
	if (s_Actors[index][E_ACTOR_LABEL] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
	{
		DestroyDynamic3DTextLabel(s_Actors[index][E_ACTOR_LABEL]);
	}

	new text[ACTORS_NAME_LEN + ACTORS_TITLE_LEN + 16];
	Actors_FormatLabel(index,text);
	s_Actors[index][E_ACTOR_LABEL] = CreateDynamic3DTextLabel(text,ACTORS_LABEL_COLOUR,x,y,z + Actors_GetLabelZ(index),ACTORS_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,s_Actors[index][E_ACTOR_WORLD],s_Actors[index][E_ACTOR_INTERIOR]);
}

static Actors_DropLabels(index)
{
	if (s_Actors[index][E_ACTOR_LABEL] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
	{
		DestroyDynamic3DTextLabel(s_Actors[index][E_ACTOR_LABEL]);
		s_Actors[index][E_ACTOR_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	}

	if (s_Actors[index][E_ACTOR_BUBBLE] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
	{
		DestroyDynamic3DTextLabel(s_Actors[index][E_ACTOR_BUBBLE]);
		s_Actors[index][E_ACTOR_BUBBLE] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	}
}

static Actors_DropBody(index)
{
	new body = s_Actors[index][E_ACTOR_BODY];

    if (s_Actors[index][E_ACTOR_IS_RIDER])
    {
        s_Actors[index][E_ACTOR_BODY] = INVALID_ACTOR_ID;
        return;
    }

	if (body != INVALID_ACTOR_ID && body >= 0 && body < MAX_ACTORS)
	{
		if (s_Actors[index][E_ACTOR_EXTERNAL])
        {
            Walkers_SetTalkPaused(body,false);
        }
        else if (s_Actors[index][E_ACTOR_IS_PED])
		{
			Walkers_StopRoute(body);

			if (IsValidPedestrian(body) == 1)
			{
				DespawnPedestrian(body);
			}
		}
		else if (IsValidActor(body))
		{
			DestroyActor(body);
		}

		if (s_ActorOfBody[body] == index)
		{
			s_ActorOfBody[body] = -1;
		}
	}

	s_Actors[index][E_ACTOR_BODY] = INVALID_ACTOR_ID;
	s_Actors[index][E_ACTOR_IS_PED] = false;
}

static bool:Actors_MakeStatic(index)
{
	new body = CreateActor(s_Actors[index][E_ACTOR_SKIN],s_Actors[index][E_ACTOR_POS][0],s_Actors[index][E_ACTOR_POS][1],s_Actors[index][E_ACTOR_POS][2],s_Actors[index][E_ACTOR_POS][3]);

	if (body == INVALID_ACTOR_ID || body < 0 || body >= MAX_ACTORS)
	{
		return false;
	}

	SetActorVirtualWorld(body,s_Actors[index][E_ACTOR_WORLD]);
	SetActorInvulnerable(body,false);
	SetActorHealth(body,ACTORS_HEALTH);
	s_ActorOfBody[body] = index;
	s_Actors[index][E_ACTOR_BODY] = body;
	s_Actors[index][E_ACTOR_IS_PED] = false;
	s_Actors[index][E_ACTOR_PLACED] = true;
	Actors_ApplyAnim(index);
	Actors_MakeLabel(index,s_Actors[index][E_ACTOR_POS][0],s_Actors[index][E_ACTOR_POS][1],s_Actors[index][E_ACTOR_POS][2]);
	return true;
}

stock bool:Actors_Place(index)
{
	if (!Actors_IsValid(index))
	{
		return false;
	}

	if (s_Actors[index][E_ACTOR_DEAD_UNTIL] > 0)
	{
		s_Actors[index][E_ACTOR_STAY] = true;
		return false;
	}

	if (s_Actors[index][E_ACTOR_PLACED])
	{
		Actors_Remove(index);
	}

	s_Actors[index][E_ACTOR_STAY] = true;
	return Actors_MakeStatic(index);
}

stock Actors_Remove(index)
{
	if (!Actors_IsValid(index))
	{
		return;
	}

	Actors_DropBody(index);
	Actors_DropLabels(index);
	s_Actors[index][E_ACTOR_PLACED] = false;
	s_Actors[index][E_ACTOR_STAY] = false;
	s_Actors[index][E_ACTOR_WALKING] = false;
	s_Actors[index][E_ACTOR_FLEE_UNTIL] = 0;
}

stock Actors_MoveTo(index,Float:x,Float:y,Float:z,Float:a,world = 0,interior = 0)
{
	if (!Actors_IsValid(index))
	{
		return;
	}

	new bool:wasPlaced = s_Actors[index][E_ACTOR_PLACED];
	Actors_SetPlace(index,x,y,z,a,world,interior);

	if (wasPlaced)
	{
        new STREAMER_TAG_3D_TEXT_LABEL:bubble = Actors_GetBubble(index);
        s_Actors[index][E_ACTOR_BUBBLE] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
        if (Actors_Place(index))
        {
            s_Actors[index][E_ACTOR_BUBBLE] = bubble;
            Actors_SyncLabels(index);
        }
        else if (IsValidDynamic3DTextLabel(bubble))
        {
            DestroyDynamic3DTextLabel(bubble);
        }
	}
}

stock Actors_ResetTalkHolds(playerid)
{
    new approached = s_ActorApproachTargets[playerid], menu = s_ActorMenuTargets[playerid], talking = s_ActorTalkTargets[playerid];
    s_ActorApproachTargets[playerid] = -1;
    s_ActorMenuTargets[playerid] = -1;
    s_ActorTalkTargets[playerid] = -1;
    Actors_UpdateTalking(approached);
    Actors_UpdateTalking(menu);
    Actors_UpdateTalking(talking);
}

stock Actors_SetApproached(playerid,index)
{
    if (Util_IsValidPlayer(playerid) && s_ActorApproachTargets[playerid] != index)
    {
        new previous = s_ActorApproachTargets[playerid];
        s_ActorApproachTargets[playerid] = index;
        Actors_UpdateTalking(previous);
        Actors_UpdateTalking(index,playerid);
    }
}

stock Actors_SetTalking(playerid,index)
{
    if (Util_IsValidPlayer(playerid))
    {
        new previous = s_ActorTalkTargets[playerid];
        s_ActorTalkTargets[playerid] = index;
        Actors_UpdateTalking(previous);
        Actors_UpdateTalking(index,playerid);
    }
}

stock Actors_SetMenuTalking(playerid,index)
{
    if (Util_IsValidPlayer(playerid))
    {
        new previous = s_ActorMenuTargets[playerid];
        s_ActorMenuTargets[playerid] = index;
        Actors_UpdateTalking(previous);
        Actors_UpdateTalking(index,playerid);
    }
}

stock bool:Actors_IsTalkingTo(index)
{
    foreach (new playerid : Player)
    {
        if ((s_ActorTalkTargets[playerid] == index || s_ActorMenuTargets[playerid] == index || s_ActorApproachTargets[playerid] == index) && Session_IsPlaying(playerid))
        {
            return true;
        }
    }

    return false;
}

stock Actors_UpdateTalking(index,playerid = INVALID_PLAYER_ID)
{
    if (!Actors_IsPlaced(index))
    {
        return;
    }

    if (s_Actors[index][E_ACTOR_IS_PED] && s_Actors[index][E_ACTOR_FLEE_UNTIL] == 0)
    {
        Walkers_SetTalkPaused(s_Actors[index][E_ACTOR_BODY],Actors_IsTalkingTo(index));
        if (!s_Actors[index][E_ACTOR_EXTERNAL])
        {
            Walkers_SetPaused(s_Actors[index][E_ACTOR_BODY],!s_Actors[index][E_ACTOR_WALKING]);
        }
    }

    if (Util_IsValidPlayer(playerid) && s_Actors[index][E_ACTOR_FLEE_UNTIL] == 0 && s_Actors[index][E_ACTOR_IS_PED] && (s_Actors[index][E_ACTOR_EXTERNAL] || s_Actors[index][E_ACTOR_WALKING] || s_Actors[index][E_ACTOR_KIND_ID] == ACTOR_KIND_WALKER))
    {
        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid,x,y,z);
        Actors_FaceTowards(index,x,y);
    }
}

stock Actors_FaceTowards(index,Float:x,Float:y)
{
	if (!Actors_IsPlaced(index))
	{
		return;
	}

    if (s_Actors[index][E_ACTOR_IS_RIDER])
    {
        return;
    }

	new Float:ax, Float:ay, Float:az, Float:a;
	Actors_GetPos(index,ax,ay,az,a);
    if (s_Actors[index][E_ACTOR_IS_PED])
    {
        SetPedestrianFacingAngle(s_Actors[index][E_ACTOR_BODY],Util_NormalizeAngle(atan2(ax - x,y - ay)));
    }
    else
    {
        SetActorFacingAngle(s_Actors[index][E_ACTOR_BODY],Util_NormalizeAngle(atan2(ax - x,y - ay)));
    }
}

static Actors_FinishWalk(index)
{
	if (!s_Actors[index][E_ACTOR_WALKING])
	{
		return;
	}

    if (s_Actors[index][E_ACTOR_KIND_ID] == ACTOR_KIND_WALKER && s_Actors[index][E_ACTOR_IS_PED] && IsValidPedestrian(s_Actors[index][E_ACTOR_BODY]) == 1)
    {
        s_Actors[index][E_ACTOR_WALKING] = false;
        Walkers_StopRoute(s_Actors[index][E_ACTOR_BODY]);
        Walkers_SetPaused(s_Actors[index][E_ACTOR_BODY],true);
        pawn_call_public("Actors_OnArrived","d",index);
        return;
    }

	s_Actors[index][E_ACTOR_WALKING] = false;
	Actors_DropBody(index);
	Actors_DropLabels(index);
	s_Actors[index][E_ACTOR_PLACED] = false;
	Actors_SetPlace(index,s_Actors[index][E_ACTOR_GOAL][0],s_Actors[index][E_ACTOR_GOAL][1],s_Actors[index][E_ACTOR_GOAL][2],s_Actors[index][E_ACTOR_GOAL][3],0,0);

	if (s_Actors[index][E_ACTOR_DEAD_UNTIL] == 0)
	{
		Actors_MakeStatic(index);
	}

	pawn_call_public("Actors_OnArrived","d",index);
}

stock bool:Actors_GetWalkTarget(index,&Float:x,&Float:y,&Float:z)
{
    if (!Actors_IsWalking(index))
    {
        return false;
    }
    x = s_Actors[index][E_ACTOR_GOAL][0];
    y = s_Actors[index][E_ACTOR_GOAL][1];
    z = s_Actors[index][E_ACTOR_GOAL][2];
    return true;
}

stock bool:Actors_WalkTo(index,Float:x,Float:y,Float:z,Float:a,Float:speed = ACTORS_WALK_SPEED,bool:direct = false)
{
	if (!Actors_IsValid(index) || s_Actors[index][E_ACTOR_DEAD_UNTIL] > 0)
	{
		return false;
	}

	s_Actors[index][E_ACTOR_GOAL][0] = x;
	s_Actors[index][E_ACTOR_GOAL][1] = y;
	s_Actors[index][E_ACTOR_GOAL][2] = z;
	s_Actors[index][E_ACTOR_GOAL][3] = a;

	new Float:fromX, Float:fromY, Float:fromZ, Float:fromA;
    s_Actors[index][E_ACTOR_DIRECT] = direct;
	Actors_GetPos(index,fromX,fromY,fromZ,fromA);

	if (!s_Actors[index][E_ACTOR_PLACED] || s_Actors[index][E_ACTOR_WORLD] != 0)
	{
		Actors_MoveTo(index,x,y,z,a,0,0);
		pawn_call_public("Actors_OnArrived","d",index);
		return false;
	}

	if (!s_Actors[index][E_ACTOR_IS_PED])
	{
		Actors_DropBody(index);
		new ped = SpawnPedestrianAt(s_Actors[index][E_ACTOR_SKIN],fromX,fromY,fromZ,fromA,WALKERS_KIND_ACTOR);

		if (ped < 0 || ped >= MAX_ACTORS || IsValidPedestrian(ped) != 1)
		{
			s_Actors[index][E_ACTOR_PLACED] = false;
			Actors_DropLabels(index);
			Actors_MoveTo(index,x,y,z,a,0,0);
			Actors_MakeStatic(index);
			pawn_call_public("Actors_OnArrived","d",index);
			return false;
		}

		SetPedestrianBody(ped,PED_BODY_PEOPLE);
		SetPedestrianKind(ped,WALKERS_KIND_ACTOR);
		SetPedestrianHealth(ped,1000.0);
		s_ActorOfBody[ped] = index;
		s_Actors[index][E_ACTOR_BODY] = ped;
		s_Actors[index][E_ACTOR_IS_PED] = true;
	}

	s_Actors[index][E_ACTOR_WALKING] = true;

	if (!Walkers_RouteTo(s_Actors[index][E_ACTOR_BODY],x,y,z,speed,direct,Actors_GetRole(index) != ACTOR_ROLE_GUARD))
	{
		Actors_FinishWalk(index);
		return false;
	}

    Walkers_SetPaused(s_Actors[index][E_ACTOR_BODY],false);
    Walkers_SetTalkPaused(s_Actors[index][E_ACTOR_BODY],Actors_IsTalkingTo(index));

    if (!Walkers_IsPaused(s_Actors[index][E_ACTOR_BODY]))
    {
        ApplyPedestrianAnim(s_Actors[index][E_ACTOR_BODY],"PED",Actors_GetSex(index) == 1 ? "WOMAN_walknorm" : "WALK_civi",4.1,true,true,true,false,0);
    }

    Actors_SyncLabels(index);
	return true;
}

stock Actors_Say(index,const text[])
{
	if (!Actors_IsPlaced(index))
	{
		return;
	}

	new Float:x, Float:y, Float:z, line[176];
	Actors_GetPos(index,x,y,z);
	format(line,sizeof(line),"%s says: %s",s_Actors[index][E_ACTOR_NAME],text);
	Chat_FromPoint(x,y,z,s_Actors[index][E_ACTOR_WORLD],s_Actors[index][E_ACTOR_INTERIOR],ACTORS_SPEECH_RANGE,CHAT_COLOUR_SAY,line);

	new bubble[144];
	strcopy(bubble,text);
	Actors_WrapBubble(bubble);
	if (IsValidDynamic3DTextLabel(s_Actors[index][E_ACTOR_BUBBLE]))
	{
		UpdateDynamic3DTextLabelText(s_Actors[index][E_ACTOR_BUBBLE],ACTORS_BUBBLE_COLOUR,bubble);
		Streamer_SetItemPos(STREAMER_TYPE_3D_TEXT_LABEL,s_Actors[index][E_ACTOR_BUBBLE],x,y,z + ACTORS_BUBBLE_Z + 0.25);
	}
	else
	{
		s_Actors[index][E_ACTOR_BUBBLE] = CreateDynamic3DTextLabel(bubble,ACTORS_BUBBLE_COLOUR,x,y,z + ACTORS_BUBBLE_Z + 0.25,ACTORS_SPEECH_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,s_Actors[index][E_ACTOR_WORLD],s_Actors[index][E_ACTOR_INTERIOR]);
	}
	s_Actors[index][E_ACTOR_BUBBLE_UNTIL] = gettime() + ACTORS_BUBBLE_SECONDS;
    Actors_SyncLabels(index);
}

static Actors_WrapBubble(text[],size = sizeof(text))
{
	new column = 0;

	for (new i = 0;i < size && text[i] != EOS;i++)
	{
		if (++column > 36 && text[i] == ' ')
		{
			text[i] = '\n';
			column = 0;
		}
	}
}

stock Actors_Do(index,const text[])
{
	if (!Actors_IsPlaced(index))
	{
		return;
	}

	new Float:x, Float:y, Float:z, line[176];
	Actors_GetPos(index,x,y,z);
	format(line,sizeof(line),"* %s %s",s_Actors[index][E_ACTOR_NAME],text);
	Chat_FromPoint(x,y,z,s_Actors[index][E_ACTOR_WORLD],s_Actors[index][E_ACTOR_INTERIOR],ACTORS_SPEECH_RANGE,CHAT_COLOUR_ACTION,line);
}

stock Actors_FindNear(playerid,Float:range = ACTORS_REACH,bool:aliveOnly = true)
{
	new best = -1, Float:bestDistance = range, world = GetPlayerVirtualWorld(playerid), Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (!Actors_IsPlaced(i) || Actors_GetWorld(i) != world || (aliveOnly && s_Actors[i][E_ACTOR_DEAD_UNTIL] > 0))
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Actors_GetPos(i,x,y,z);
		new Float:distance = VectorSize(x - px,y - py,z - pz);

		if (distance < bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

stock Actors_CountWitnesses(Float:x,Float:y,Float:z,world,Float:range = ACTORS_WITNESS_RANGE,exclude = -1)
{
	new count = 0;

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (i == exclude || !s_Actors[i][E_ACTOR_USED] || !s_Actors[i][E_ACTOR_PLACED] || s_Actors[i][E_ACTOR_DEAD_UNTIL] > 0 || s_Actors[i][E_ACTOR_WORLD] != world)
		{
			continue;
		}

		new Float:ax, Float:ay, Float:az;
		Actors_GetPos(i,ax,ay,az);

		if (VectorSize(ax - x,ay - y,az - z) > range)
		{
			continue;
		}

		new Float:hx, Float:hy, Float:hz;

		if (world == 0 && CA_RayCastLine(ax,ay,az + 0.6,x,y,z + 0.6,hx,hy,hz) != 0)
		{
			continue;
		}

		count++;
	}

	return count;
}

static Actors_Blood(index)
{
	new Float:x, Float:y, Float:z;
	Actors_GetPos(index,x,y,z);

	if (!s_Actors[index][E_ACTOR_PLACED] || !s_Actors[index][E_ACTOR_IS_PED] || IsValidPedestrian(s_Actors[index][E_ACTOR_BODY]) != 1)
	{
		z -= ACTORS_PED_LIFT;
	}

	Wounds_SpillBlood(x,y,z,s_Actors[index][E_ACTOR_WORLD]);
}

static Actors_Flee(index,playerid)
{
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid,px,py,pz);

	if (s_Actors[index][E_ACTOR_WORLD] != 0)
	{
		if (!s_Actors[index][E_ACTOR_IS_PED] && IsValidActor(s_Actors[index][E_ACTOR_BODY]))
		{
			ApplyActorAnimation(s_Actors[index][E_ACTOR_BODY],"PED","cower",4.1,true,false,false,false,0);
			SetTimerEx("Actors_EndCower",ACTORS_COWER_MS,false,"d",index);
		}

		return;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Actors_GetPos(index,x,y,z,a);

	if (!s_Actors[index][E_ACTOR_IS_PED])
	{
		s_Actors[index][E_ACTOR_GOAL][0] = s_Actors[index][E_ACTOR_POS][0];
		s_Actors[index][E_ACTOR_GOAL][1] = s_Actors[index][E_ACTOR_POS][1];
		s_Actors[index][E_ACTOR_GOAL][2] = s_Actors[index][E_ACTOR_POS][2];
		s_Actors[index][E_ACTOR_GOAL][3] = s_Actors[index][E_ACTOR_POS][3];
		Actors_DropBody(index);
		new ped = SpawnPedestrianAt(s_Actors[index][E_ACTOR_SKIN],x,y,z,a,WALKERS_KIND_ACTOR);

		if (ped < 0 || ped >= MAX_ACTORS || IsValidPedestrian(ped) != 1)
		{
			Actors_MakeStatic(index);
			return;
		}

		SetPedestrianBody(ped,PED_BODY_PEOPLE);
		SetPedestrianKind(ped,WALKERS_KIND_ACTOR);
		SetPedestrianHealth(ped,1000.0);
		s_ActorOfBody[ped] = index;
		s_Actors[index][E_ACTOR_BODY] = ped;
		s_Actors[index][E_ACTOR_IS_PED] = true;
		s_Actors[index][E_ACTOR_WALKING] = true;
	}

	Walkers_StopRoute(s_Actors[index][E_ACTOR_BODY]);
    Walkers_SetPaused(s_Actors[index][E_ACTOR_BODY],false);
	PedestrianFleeFrom(s_Actors[index][E_ACTOR_BODY],px,py,pz,ACTORS_FLEE_SECONDS * 1000);
	s_Actors[index][E_ACTOR_FLEE_UNTIL] = gettime() + ACTORS_FLEE_SECONDS;
}

stock bool:Actors_DamageByBody(actorid,playerid,Float:amount)
{
    new index = Actors_FindByBody(actorid);

    if (!Actors_IsValid(index))
    {
        return false;
    }

    if (!s_Actors[index][E_ACTOR_EXTERNAL])
    {
        Actors_Damage(index,playerid,amount);
    }

    return true;
}

stock Actors_Damage(index,playerid,Float:amount)
{
	if (!Actors_IsValid(index) || s_Actors[index][E_ACTOR_DEAD_UNTIL] > 0 || amount <= 0.0 || s_Actors[index][E_ACTOR_INVULNERABLE])
	{
		return;
	}

	s_Actors[index][E_ACTOR_HEALTH] -= amount;
	Actors_Blood(index);

	if (s_Actors[index][E_ACTOR_HEALTH] <= 0.0)
	{
		Actors_Kill(index,playerid);
		return;
	}

	if (Util_IsValidPlayer(playerid) && !s_Actors[index][E_ACTOR_HURT])
	{
		new Float:x, Float:y, Float:z;
		Actors_GetPos(index,x,y,z);
		s_Actors[index][E_ACTOR_HURT] = true;
		Law_Commit(playerid,LAW_CRIME_ASSAULT,INVALID_PLAYER_ID,Actors_CountWitnesses(x,y,z,s_Actors[index][E_ACTOR_WORLD],ACTORS_WITNESS_RANGE,-1));
	}

	if (Util_IsValidPlayer(playerid))
	{
		Actors_Flee(index,playerid);
	}

	pawn_call_public("Actors_OnHarmed","dd",index,playerid);
}

stock Actors_Kill(index,killerid = INVALID_PLAYER_ID)
{
	if (!Actors_IsValid(index) || s_Actors[index][E_ACTOR_DEAD_UNTIL] > 0)
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:a, now = gettime();
	Actors_GetPos(index,x,y,z,a);
	s_Actors[index][E_ACTOR_HEALTH] = 0.0;
	s_Actors[index][E_ACTOR_DEAD_UNTIL] = now + ACTORS_RESPAWN_SECONDS;
	s_Actors[index][E_ACTOR_CORPSE_UNTIL] = now + ACTORS_CORPSE_SECONDS;
	s_Actors[index][E_ACTOR_WALKING] = false;
	s_Actors[index][E_ACTOR_FLEE_UNTIL] = 0;

	new bool:wasPlaced = s_Actors[index][E_ACTOR_PLACED];
	Actors_DropBody(index);
	Actors_DropLabels(index);
	s_Actors[index][E_ACTOR_PLACED] = false;

	if (wasPlaced)
	{
		new body = CreateActor(s_Actors[index][E_ACTOR_SKIN],x,y,z,a);

		if (body != INVALID_ACTOR_ID && body >= 0 && body < MAX_ACTORS)
		{
			SetActorVirtualWorld(body,s_Actors[index][E_ACTOR_WORLD]);
			ApplyActorAnimation(body,"PED","KO_shot_front",4.1,false,false,false,true,0);
			s_ActorOfBody[body] = index;
			s_Actors[index][E_ACTOR_BODY] = body;
			s_Actors[index][E_ACTOR_PLACED] = true;
		}
	}

	if (Util_IsValidPlayer(killerid))
	{
		Law_Commit(killerid,LAW_CRIME_MURDER,INVALID_PLAYER_ID,Actors_CountWitnesses(x,y,z,s_Actors[index][E_ACTOR_WORLD],ACTORS_WITNESS_RANGE,index));
	}

	if (s_Actors[index][E_ACTOR_DB_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE actors SET dead_until = %d WHERE id = %d",s_Actors[index][E_ACTOR_DEAD_UNTIL],s_Actors[index][E_ACTOR_DB_ID]));
	}

	pawn_call_public("Actors_OnKilled","dd",index,killerid);
}

stock Actors_Respawn(index)
{
	if (!Actors_IsValid(index))
	{
		return;
	}

	new bool:stay = s_Actors[index][E_ACTOR_STAY];
	Actors_Remove(index);

	if (s_Actors[index][E_ACTOR_DEAD_UNTIL] > 0)
	{
		new count = Skins_CountStarter(s_Actors[index][E_ACTOR_SEX]);

		if (count > 0)
		{
			s_Actors[index][E_ACTOR_SKIN] = Skins_GetStarter(s_Actors[index][E_ACTOR_SEX],random(count));
		}
	}

	s_Actors[index][E_ACTOR_HEALTH] = ACTORS_HEALTH;
	s_Actors[index][E_ACTOR_HURT] = false;
	s_Actors[index][E_ACTOR_DEAD_UNTIL] = 0;
	s_Actors[index][E_ACTOR_CORPSE_UNTIL] = 0;
	s_Actors[index][E_ACTOR_OPEN] = true;

	if (s_Actors[index][E_ACTOR_DB_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE actors SET dead_until = NULL, skin = %d WHERE id = %d",s_Actors[index][E_ACTOR_SKIN],s_Actors[index][E_ACTOR_DB_ID]));
	}

	if (stay)
	{
		Actors_Place(index);
	}

	pawn_call_public("Actors_OnRespawn","d",index);
}

Timer_Declare(Actors_Tick)
{
	new now = gettime();

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (!s_Actors[i][E_ACTOR_USED])
		{
			continue;
		}

        if (s_Actors[i][E_ACTOR_EXTERNAL] && !Actors_IsPlaced(i))
        {
            Actors_Unregister(i);
            continue;
        }

		if (s_Actors[i][E_ACTOR_BUBBLE] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID && now >= s_Actors[i][E_ACTOR_BUBBLE_UNTIL])
		{
			DestroyDynamic3DTextLabel(s_Actors[i][E_ACTOR_BUBBLE]);
			s_Actors[i][E_ACTOR_BUBBLE] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
		}

        Actors_SyncLabels(i);

        if (s_Actors[i][E_ACTOR_EXTERNAL])
        {
            continue;
        }

		if (s_Actors[i][E_ACTOR_DEAD_UNTIL] > 0)
		{
			if (s_Actors[i][E_ACTOR_PLACED] && now >= s_Actors[i][E_ACTOR_CORPSE_UNTIL])
			{
				Actors_DropBody(i);
				s_Actors[i][E_ACTOR_PLACED] = false;
			}

			if (now >= s_Actors[i][E_ACTOR_DEAD_UNTIL])
			{
				Actors_Respawn(i);
			}

			continue;
		}

		if (!s_Actors[i][E_ACTOR_IS_PED] || !s_Actors[i][E_ACTOR_PLACED])
		{
			continue;
		}

		new body = s_Actors[i][E_ACTOR_BODY];

		if (IsValidPedestrian(body) != 1)
		{
			s_Actors[i][E_ACTOR_WALKING] = true;
			Actors_FinishWalk(i);
			continue;
		}

		if (s_Actors[i][E_ACTOR_FLEE_UNTIL] > 0 && now >= s_Actors[i][E_ACTOR_FLEE_UNTIL])
		{
			s_Actors[i][E_ACTOR_FLEE_UNTIL] = 0;
            Actors_WalkTo(i,s_Actors[i][E_ACTOR_GOAL][0],s_Actors[i][E_ACTOR_GOAL][1],s_Actors[i][E_ACTOR_GOAL][2],s_Actors[i][E_ACTOR_GOAL][3],ACTORS_WALK_SPEED,s_Actors[i][E_ACTOR_DIRECT]);
		}

	}

	return 1;
}

forward Actors_EndCower(index);

public Actors_EndCower(index)
{
	if (Actors_IsValid(index) && s_Actors[index][E_ACTOR_DEAD_UNTIL] == 0)
	{
		Actors_ApplyAnim(index);
	}

	return 1;
}

forward Actors_OnArrived(index);

public Actors_OnArrived(index)
{
	return 1;
}

forward Actors_OnHarmed(index,playerid);

public Actors_OnHarmed(index,playerid)
{
	return 1;
}

forward Actors_OnKilled(index,killerid);

public Actors_OnKilled(index,killerid)
{
	return 1;
}

forward Actors_OnRespawn(index);

public Actors_OnRespawn(index)
{
	return 1;
}

#include <pp-hooks>

forward Actors_OnRemoved(index);

public Actors_OnRemoved(index)
{
    return 1;
}

hook Walkers_OnSpawn(actorid,nodeid)
{
    #pragma unused nodeid

    new existing = Actors_FindByBody(actorid);

    if (existing != -1 && s_Actors[existing][E_ACTOR_EXTERNAL])
    {
        Actors_Unregister(existing);
    }
}

hook Walkers_OnArrive(actorid)
{
	new index = Actors_FindByBody(actorid);

	if (index != -1 && !s_Actors[index][E_ACTOR_EXTERNAL] && s_Actors[index][E_ACTOR_IS_PED] && s_Actors[index][E_ACTOR_FLEE_UNTIL] == 0)
	{
		Actors_FinishWalk(index);
	}
}

hook Walkers_OnRouteFailed(actorid)
{
	new index = Actors_FindByBody(actorid);

	if (index != -1 && !s_Actors[index][E_ACTOR_EXTERNAL] && s_Actors[index][E_ACTOR_IS_PED] && s_Actors[index][E_ACTOR_FLEE_UNTIL] == 0)
	{
		Actors_FinishWalk(index);
	}
}

hook OnPedestrianReachTarget(actorid)
{
	new index = Actors_FindByBody(actorid);

	if (index != -1 && s_Actors[index][E_ACTOR_WALKING] && !Walkers_IsRouting(actorid) && s_Actors[index][E_ACTOR_FLEE_UNTIL] == 0)
	{
		new Float:x, Float:y, Float:z;
		GetPedestrianPos(actorid,x,y,z);

		if (VectorSize(x - s_Actors[index][E_ACTOR_GOAL][0],y - s_Actors[index][E_ACTOR_GOAL][1],0.0) < 2.5)
		{
			Actors_FinishWalk(index);
		}
	}
}

hook OnPlayerGiveDamageActor(playerid,damaged_actorid,Float:amount,WEAPON:weaponid,bodypart)
{
	#pragma unused weaponid, bodypart

	if (IsValidPedestrian(damaged_actorid) == 1)
	{
		return;
	}

	new index = Actors_FindByBody(damaged_actorid);

	if (index != -1 && !s_Actors[index][E_ACTOR_EXTERNAL])
	{
		Actors_Damage(index,playerid,amount);
	}
}

hook OnPedestrianGetDamage(pedestrianid,playerid,weaponid,Float:amount)
{
	#pragma unused weaponid

	new index = Actors_FindByBody(pedestrianid);

	if (index != -1 && !s_Actors[index][E_ACTOR_EXTERNAL])
	{
		SetPedestrianHealth(pedestrianid,1000.0);
		Actors_Damage(index,playerid,amount);
	}
}

hook OnPedestrianDeath(actorid,killerid,reason)
{
	#pragma unused reason

	new index = Actors_FindByBody(actorid);

	if (index != -1)
	{
        if (s_Actors[index][E_ACTOR_EXTERNAL])
        {
            Actors_Unregister(index);
            return;
        }

		Actors_Kill(index,killerid);
	}
}

hook Combat_OnNpcSeek(playerid)
{
	new world = GetPlayerVirtualWorld(playerid);

	for (new i = 0;i < ACTORS_MAX;i++)
	{
		if (!Actors_IsPlaced(i) || s_Actors[i][E_ACTOR_IS_RIDER] || s_Actors[i][E_ACTOR_DEAD_UNTIL] > 0 || Actors_GetWorld(i) != world || s_Actors[i][E_ACTOR_BODY] == INVALID_ACTOR_ID)
		{
			continue;
		}

		new Float:x, Float:y, Float:z, Float:a;
		Actors_GetPos(i,x,y,z,a);
		Combat_OfferNpc(s_Actors[i][E_ACTOR_BODY],x,y,s_Actors[i][E_ACTOR_IS_PED] ? z + ACTORS_PED_LIFT : z,a);
	}
}

hook Law_OnSeekWitnesses(offenderid,Float:x,Float:y,Float:z,world)
{
	#pragma unused offenderid
	Law_AddWitnesses(Actors_CountWitnesses(x,y,z,world));
}

hook Combat_OnHitNpc(attackerid,actorid,weapon,Float:damage)
{
	#pragma unused weapon

	new index = Actors_FindByBody(actorid);

	if (index != -1 && !s_Actors[index][E_ACTOR_EXTERNAL])
	{
		Actors_Damage(index,attackerid,damage);
	}
}

hook Util_OnInteriorReady(playerid)
{
    Actors_RestoreInterior(playerid);
}
