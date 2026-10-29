enum E_CART
{
	bool:E_CART_USED,
	E_CART_ROW,
	E_CART_KIND:E_CART_KIND_ID,
	E_CART_OWNER,
	E_CART_CONTAINER,
	Float:E_CART_POS[4],
	Float:E_CART_PITCH,
    Float:E_CART_ROLL,
	bool:E_CART_LOCKED,
	STREAMER_TAG_OBJECT:E_CART_BODY,
	STREAMER_TAG_OBJECT:E_CART_WHEELS[4],
	STREAMER_TAG_OBJECT:E_CART_LOAD,
	E_CART_LOAD_MODEL,
	E_CART_MOVER,
	bool:E_CART_HITCHED,
	Float:E_CART_SPIN,
	E_CART_SAVED_AT,
	Float:E_CART_PULLER[2],
	bool:E_CART_PULLER_SEEN,
	bool:E_CART_SERVICE,
    bool:E_CART_DRIVEN,
}

static s_Carts[CARTS_MAX][E_CART];
static s_CartOfPlayer[MAX_PLAYERS] = {-1, ...};
static s_CartThief[MAX_PLAYERS] = {-1, ...};
static s_CartSeated[CARTS_MAX][CARTS_SEATS_MAX];
static s_PlayerSeat[MAX_PLAYERS] = {-1, ...};
static s_SitterPoseTick[MAX_PLAYERS];
static s_SitterMovedTick[MAX_PLAYERS];

stock bool:Carts_IsValid(cart)
{
	return cart >= 0 && cart < CARTS_MAX && s_Carts[cart][E_CART_USED];
}

stock Carts_GetMover(cart)
{
	return Carts_IsValid(cart) ? s_Carts[cart][E_CART_MOVER] : INVALID_PLAYER_ID;
}

stock Carts_GetOfPlayer(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CartOfPlayer[playerid] : -1;
}

stock E_CART_KIND:Carts_GetKind(cart)
{
	return Carts_IsValid(cart) ? s_Carts[cart][E_CART_KIND_ID] : CART_KIND_COUNT;
}

stock Carts_GetContainer(cart)
{
	return Carts_IsValid(cart) ? s_Carts[cart][E_CART_CONTAINER] : INVALID_CONTAINER_ID;
}

stock Carts_GetOwner(cart)
{
	return Carts_IsValid(cart) ? s_Carts[cart][E_CART_OWNER] : 0;
}

stock bool:Carts_IsLocked(cart)
{
	return Carts_IsValid(cart) && s_Carts[cart][E_CART_LOCKED];
}

stock bool:Carts_GetPos(cart,&Float:x,&Float:y,&Float:z,&Float:a)
{
	if (!Carts_IsValid(cart))
	{
		return false;
	}

	x = s_Carts[cart][E_CART_POS][0];
	y = s_Carts[cart][E_CART_POS][1];
	z = s_Carts[cart][E_CART_POS][2];
	a = s_Carts[cart][E_CART_POS][3];
	return true;
}

stock Float:Carts_GetSpin(cart)
{
	return Carts_IsValid(cart) ? s_Carts[cart][E_CART_SPIN] : 0.0;
}

stock Float:Carts_GetGround(Float:x,Float:y,Float:z)
{
	new Float:hx, Float:hy, Float:hz;

	if (CA_RayCastLine(x,y,z + 1.0,x,y,z - 6.0,hx,hy,hz) != 0)
	{
		return hz;
	}

	return z;
}

stock Carts_GetSlopePose(Float:front,Float:back,Float:left,Float:right,&Float:pitch,&Float:roll)
{
    pitch = atan2(front - back,2.0);
    roll = atan2((left - right) * floatcos(pitch,degrees),2.0);
}

static Carts_GroundPose(Float:x,Float:y,Float:z,Float:angle,&Float:ground,&Float:pitch,&Float:roll)
{
    new Float:forwardX = -floatsin(angle,degrees), Float:forwardY = floatcos(angle,degrees);
    new Float:sideX = floatcos(angle,degrees), Float:sideY = floatsin(angle,degrees);
    ground = Carts_GetGround(x,y,z);
    Carts_GetSlopePose(Carts_GetGround(x + forwardX,y + forwardY,z),Carts_GetGround(x - forwardX,y - forwardY,z),Carts_GetGround(x - sideX,y - sideY,z),Carts_GetGround(x + sideX,y + sideY,z),pitch,roll);
}

stock Carts_GetPartOffset(Float:offsetX,Float:offsetY,Float:offsetZ,Float:pitch,Float:roll,Float:angle,&Float:x,&Float:y,&Float:z)
{
    new Float:rolledX = offsetX * floatcos(roll,degrees) + offsetZ * floatsin(roll,degrees);
    new Float:rolledZ = -offsetX * floatsin(roll,degrees) + offsetZ * floatcos(roll,degrees);
    new Float:pitchedY = offsetY * floatcos(pitch,degrees) - rolledZ * floatsin(pitch,degrees);
    z = offsetY * floatsin(pitch,degrees) + rolledZ * floatcos(pitch,degrees);
    x = rolledX * floatcos(angle,degrees) - pitchedY * floatsin(angle,degrees);
    y = rolledX * floatsin(angle,degrees) + pitchedY * floatcos(angle,degrees);
}

stock Carts_GetWheelRotation(Float:pitch,Float:roll,Float:spin,Float:angle,&Float:rotationX,&Float:rotationY,&Float:rotationZ)
{
    new Float:pitchSin = floatsin(pitch,degrees), Float:pitchCos = floatcos(pitch,degrees);
    new Float:rollSin = floatsin(roll,degrees), Float:rollCos = floatcos(roll,degrees);
    new Float:spinSin = floatsin(spin,degrees), Float:spinCos = floatcos(spin,degrees);
    new Float:vertical = pitchSin * spinCos + pitchCos * rollCos * spinSin;
    if (vertical > 1.0)
    {
        vertical = 1.0;
    }
    else if (vertical < -1.0)
    {
        vertical = -1.0;
    }
    rotationX = asin(vertical);
    rotationY = atan2(pitchCos * rollSin,pitchCos * rollCos * spinCos - pitchSin * spinSin);
    rotationZ = angle + atan2(-rollSin * spinSin,pitchCos * spinCos - pitchSin * rollCos * spinSin);
}

static Carts_PartPos(cart,Float:ox,Float:oy,Float:oz,&Float:x,&Float:y,&Float:z)
{
    Carts_GetPartOffset(ox,oy,oz,s_Carts[cart][E_CART_PITCH],s_Carts[cart][E_CART_ROLL],s_Carts[cart][E_CART_POS][3],x,y,z);
    x += s_Carts[cart][E_CART_POS][0];
    y += s_Carts[cart][E_CART_POS][1];
    z += s_Carts[cart][E_CART_POS][2];
}

static Carts_PlaceParts(cart)
{
	new E_CART_KIND:kind = s_Carts[cart][E_CART_KIND_ID], Float:x, Float:y, Float:z;
    new Float:rotationX, Float:rotationY, Float:rotationZ;
    Carts_GetWheelRotation(s_Carts[cart][E_CART_PITCH],s_Carts[cart][E_CART_ROLL],s_Carts[cart][E_CART_SPIN],s_Carts[cart][E_CART_POS][3],rotationX,rotationY,rotationZ);

	for (new w = 0;w < g_CartDefs[kind][E_CART_DEF_WHEELS];w++)
	{
		if (s_Carts[cart][E_CART_WHEELS][w] == STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
		{
			continue;
		}

		Carts_PartPos(cart,g_CartDefs[kind][E_CART_DEF_WHEEL_POS][w * 3],g_CartDefs[kind][E_CART_DEF_WHEEL_POS][w * 3 + 1],g_CartDefs[kind][E_CART_DEF_WHEEL_POS][w * 3 + 2],x,y,z);
		SetDynamicObjectPos(s_Carts[cart][E_CART_WHEELS][w],x,y,z);
		SetDynamicObjectRot(s_Carts[cart][E_CART_WHEELS][w],rotationX,rotationY,rotationZ);
	}

	if (s_Carts[cart][E_CART_LOAD] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		Carts_PartPos(cart,g_CartDefs[kind][E_CART_DEF_BED][0],g_CartDefs[kind][E_CART_DEF_BED][1],g_CartDefs[kind][E_CART_DEF_BED][2],x,y,z);
		SetDynamicObjectPos(s_Carts[cart][E_CART_LOAD],x,y,z);
		SetDynamicObjectRot(s_Carts[cart][E_CART_LOAD],s_Carts[cart][E_CART_PITCH],s_Carts[cart][E_CART_ROLL],s_Carts[cart][E_CART_POS][3]);
	}
}

stock Carts_LoadModelFor(containerid)
{
	if (containerid == INVALID_CONTAINER_ID)
	{
		return 0;
	}

	if (Container_Count(containerid,Item_GetDefKind(ITEM_LOG_OAK),ITEM_LOG_OAK) + Container_Count(containerid,Item_GetDefKind(ITEM_LOG_SOFTWOOD),ITEM_LOG_SOFTWOOD) + Container_Count(containerid,Item_GetDefKind(ITEM_BEAM),ITEM_BEAM) >= CARTS_LOAD_SHOW)
	{
		return MODEL_CARTS_LOAD_LOGS;
	}

	if (Container_Count(containerid,Item_GetDefKind(ITEM_STONE_BLOCK),ITEM_STONE_BLOCK) >= CARTS_LOAD_SHOW)
	{
		return MODEL_CARTS_LOAD_STONE;
	}

	if (Container_Count(containerid,Item_GetDefKind(ITEM_BARREL),ITEM_BARREL) + Container_Count(containerid,Item_GetDefKind(ITEM_BARREL_ALE),ITEM_BARREL_ALE) >= 2)
	{
		return MODEL_CARTS_LOAD_BARRELS;
	}

	new sacks = Container_Count(containerid,Item_GetDefKind(ITEM_SACK),ITEM_SACK) + Container_Count(containerid,Item_GetDefKind(ITEM_WHEAT),ITEM_WHEAT) + Container_Count(containerid,Item_GetDefKind(ITEM_BARLEY),ITEM_BARLEY) + Container_Count(containerid,Item_GetDefKind(ITEM_RYE),ITEM_RYE) + Container_Count(containerid,Item_GetDefKind(ITEM_OATS),ITEM_OATS) + Container_Count(containerid,Item_GetDefKind(ITEM_FLOUR),ITEM_FLOUR);
	return sacks >= CARTS_LOAD_SHOW ? MODEL_CARTS_LOAD_SACKS : 0;
}

stock Carts_RefreshLoad(cart)
{
	if (!Carts_IsValid(cart) || g_CartDefs[s_Carts[cart][E_CART_KIND_ID]][E_CART_DEF_BED][2] == 0.0)
	{
		return;
	}

	new model = Carts_LoadModelFor(s_Carts[cart][E_CART_CONTAINER]);

	if (model == s_Carts[cart][E_CART_LOAD_MODEL])
	{
		return;
	}

	if (s_Carts[cart][E_CART_LOAD] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		DestroyDynamicObject(s_Carts[cart][E_CART_LOAD]);
		s_Carts[cart][E_CART_LOAD] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	s_Carts[cart][E_CART_LOAD_MODEL] = model;

	if (model != 0)
	{
		s_Carts[cart][E_CART_LOAD] = CreateDynamicObject(model,s_Carts[cart][E_CART_POS][0],s_Carts[cart][E_CART_POS][1],s_Carts[cart][E_CART_POS][2],0.0,0.0,0.0,0,0,-1,CARTS_STREAM);
		Carts_PlaceParts(cart);
	}
}

static Carts_Spawn(cart)
{
	new E_CART_KIND:kind = s_Carts[cart][E_CART_KIND_ID];
	s_Carts[cart][E_CART_BODY] = CreateDynamicObject(g_CartDefs[kind][E_CART_DEF_BODY],s_Carts[cart][E_CART_POS][0],s_Carts[cart][E_CART_POS][1],s_Carts[cart][E_CART_POS][2],s_Carts[cart][E_CART_PITCH],s_Carts[cart][E_CART_ROLL],s_Carts[cart][E_CART_POS][3],0,0,-1,CARTS_STREAM);

	for (new w = 0;w < 4;w++)
	{
		s_Carts[cart][E_CART_WHEELS][w] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

		if (w < g_CartDefs[kind][E_CART_DEF_WHEELS])
		{
			s_Carts[cart][E_CART_WHEELS][w] = CreateDynamicObject(g_CartDefs[kind][E_CART_DEF_WHEEL],s_Carts[cart][E_CART_POS][0],s_Carts[cart][E_CART_POS][1],s_Carts[cart][E_CART_POS][2],0.0,0.0,0.0,0,0,-1,CARTS_STREAM);
		}
	}

	s_Carts[cart][E_CART_LOAD] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Carts[cart][E_CART_LOAD_MODEL] = 0;
	Carts_PlaceParts(cart);
	Carts_RefreshLoad(cart);
}

static Carts_Despawn(cart)
{
	if (s_Carts[cart][E_CART_LOAD] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		DestroyDynamicObject(s_Carts[cart][E_CART_LOAD]);
	}

	for (new w = 0;w < 4;w++)
	{
		if (s_Carts[cart][E_CART_WHEELS][w] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
		{
			DestroyDynamicObject(s_Carts[cart][E_CART_WHEELS][w]);
		}
	}

	if (s_Carts[cart][E_CART_BODY] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		DestroyDynamicObject(s_Carts[cart][E_CART_BODY]);
	}
}

static Carts_Store(row,E_CART_KIND:kind,owner,containerid,Float:x,Float:y,Float:z,Float:a,bool:locked)
{
	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (s_Carts[cart][E_CART_USED])
		{
			continue;
		}

		s_Carts[cart][E_CART_USED] = true;
		s_Carts[cart][E_CART_ROW] = row;
		s_Carts[cart][E_CART_KIND_ID] = kind;
		s_Carts[cart][E_CART_OWNER] = owner;
		s_Carts[cart][E_CART_CONTAINER] = containerid;
		s_Carts[cart][E_CART_POS][0] = x;
		s_Carts[cart][E_CART_POS][1] = y;
        Carts_GroundPose(x,y,z,a,s_Carts[cart][E_CART_POS][2],s_Carts[cart][E_CART_PITCH],s_Carts[cart][E_CART_ROLL]);
		s_Carts[cart][E_CART_POS][3] = a;
		s_Carts[cart][E_CART_LOCKED] = locked;
		s_Carts[cart][E_CART_MOVER] = INVALID_PLAYER_ID;
		s_Carts[cart][E_CART_HITCHED] = false;
		s_Carts[cart][E_CART_SPIN] = 0.0;
		s_Carts[cart][E_CART_SAVED_AT] = 0;
		s_Carts[cart][E_CART_PULLER_SEEN] = false;
		s_Carts[cart][E_CART_SERVICE] = false;
        s_Carts[cart][E_CART_DRIVEN] = false;

		for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
		{
			s_CartSeated[cart][seat] = INVALID_PLAYER_ID;
		}

		Carts_Spawn(cart);
		return cart;
	}

	return -1;
}

forward Task:Carts_Create(E_CART_KIND:kind,owner,Float:x,Float:y,Float:z,Float:a);
#pragma warning push
#pragma warning disable 204
async Task:Carts_Create(E_CART_KIND:kind,owner,Float:x,Float:y,Float:z,Float:a)
{
	new label[32];
	format(label,sizeof(label),"The %s",g_CartDefs[kind][E_CART_DEF_NAME]);
	new containerid = await Container_Create(CONTAINER_OWNER_CART,owner,g_CartDefs[kind][E_CART_DEF_SLOTS],label);
    z = Carts_GetGround(x,y,z);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO carts (kind, owner_character_id, container_id, x, y, z, a, locked, hitched_mount_id) VALUES (%d, %d, %d, %f, %f, %f, %f, 0, NULL)",_:kind,owner,containerid,x,y,z,a));
	new row = cache_insert_id();
	return async Carts_Store(row,kind,owner,containerid,x,y,z,a,false);
}
#pragma warning pop

stock Carts_CreateTransient(E_CART_KIND:kind,owner,Float:x,Float:y,Float:z,Float:a)
{
	new cart = Carts_Store(0,kind,owner,INVALID_CONTAINER_ID,x,y,z,a,true);

	if (cart != -1)
	{
		s_Carts[cart][E_CART_SERVICE] = true;
	}

	return cart;
}

stock bool:Carts_IsService(cart)
{
	return Carts_IsValid(cart) && s_Carts[cart][E_CART_SERVICE];
}

stock bool:Carts_IsDriven(cart)
{
    return Carts_IsValid(cart) && s_Carts[cart][E_CART_DRIVEN];
}

stock Carts_SetDriven(cart,bool:isDriven)
{
    if (Carts_IsValid(cart))
    {
        s_Carts[cart][E_CART_DRIVEN] = isDriven;
    }
}

stock Carts_Save(cart)
{
	if (!Carts_IsValid(cart) || s_Carts[cart][E_CART_ROW] <= 0)
	{
		return;
	}

	s_Carts[cart][E_CART_SAVED_AT] = GetTickCount();
	mysql_tquery_s(g_Mysql,str_format("UPDATE carts SET x = %f, y = %f, z = %f, a = %f, locked = %d WHERE id = %d",s_Carts[cart][E_CART_POS][0],s_Carts[cart][E_CART_POS][1],s_Carts[cart][E_CART_POS][2],s_Carts[cart][E_CART_POS][3],s_Carts[cart][E_CART_LOCKED] ? 1 : 0,s_Carts[cart][E_CART_ROW]));
}

stock Carts_Remove(cart)
{
	if (!Carts_IsValid(cart))
	{
		return;
	}

	Carts_UnseatAll(cart);
	Carts_Release(cart);
	Carts_Despawn(cart);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM carts WHERE id = %d",s_Carts[cart][E_CART_ROW]));
	s_Carts[cart][E_CART_USED] = false;
}

stock Carts_SetLocked(cart,bool:locked)
{
	if (Carts_IsValid(cart))
	{
		s_Carts[cart][E_CART_LOCKED] = locked;
		Carts_Save(cart);
	}
}

stock Carts_FindNear(playerid,Float:reach = CARTS_REACH)
{
	new best = -1, Float:bestDistance = reach;

	if (GetPlayerVirtualWorld(playerid) != 0)
	{
		return -1;
	}

	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (!s_Carts[cart][E_CART_USED] || s_Carts[cart][E_CART_SERVICE])
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(playerid,s_Carts[cart][E_CART_POS][0],s_Carts[cart][E_CART_POS][1],s_Carts[cart][E_CART_POS][2] + 1.0);

		if (distance < bestDistance)
		{
			best = cart;
			bestDistance = distance;
		}
	}

	return best;
}

stock Carts_ShaftPoint(cart,&Float:x,&Float:y)
{
	new Float:a = s_Carts[cart][E_CART_POS][3];
	x = s_Carts[cart][E_CART_POS][0] + floatsin(a,degrees) * CARTS_HITCH;
	y = s_Carts[cart][E_CART_POS][1] - floatcos(a,degrees) * CARTS_HITCH;
}

stock bool:Carts_MayHandle(playerid,cart)
{
	if (!Carts_IsValid(cart))
	{
		return false;
	}

	if (s_Carts[cart][E_CART_OWNER] == 0)
	{
		return Law_IsGuard(playerid);
	}

	return s_Carts[cart][E_CART_OWNER] == Character_GetId(playerid);
}

static Carts_TakeHold(playerid,cart)
{
	if (!Carts_MayHandle(playerid,cart) && s_CartThief[playerid] != s_Carts[cart][E_CART_ROW])
	{
		s_CartThief[playerid] = s_Carts[cart][E_CART_ROW];
		Law_Commit(playerid,LAW_CRIME_THEFT);
	}

	s_Carts[cart][E_CART_MOVER] = playerid;
	s_Carts[cart][E_CART_PULLER_SEEN] = false;
	s_CartOfPlayer[playerid] = cart;
}

stock bool:Carts_Push(playerid,cart)
{
	if (!Carts_IsValid(cart) || s_Carts[cart][E_CART_MOVER] != INVALID_PLAYER_ID || g_CartDefs[s_Carts[cart][E_CART_KIND_ID]][E_CART_DEF_HITCHED] || s_CartOfPlayer[playerid] != -1)
	{
		return false;
	}

	Carts_TakeHold(playerid,cart);
	s_Carts[cart][E_CART_HITCHED] = false;
	return true;
}

stock bool:Carts_Hitch(playerid,cart)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return false;
    }

    if (!Carts_IsValid(cart))
    {
        Gui_Notify(playerid,"The cart is no longer here.");
        return false;
    }

    if (Carts_IsService(cart) || Carts_IsDriven(cart))
    {
        Gui_Notify(playerid,"This coach has a coachman. You can't hitch your horse to it.");
        return false;
    }

    if (Carts_GetMover(cart) != INVALID_PLAYER_ID)
    {
        Gui_Notify(playerid,"Someone is already pulling this cart. Wait until they unhitch it.");
        return false;
    }

    if (!g_CartDefs[Carts_GetKind(cart)][E_CART_DEF_HITCHED])
    {
        Gui_Notify(playerid,"This handcart must be pulled on foot.");
        return false;
    }

    if (!Mount_IsRiding(playerid) || Carts_GetSeat(playerid) != -1)
    {
        Gui_Notify(playerid,"Ride your horse up to the cart's shafts first.");
        return false;
    }

    if (Carts_GetOfPlayer(playerid) != -1)
    {
        Gui_Notify(playerid,"Unhitch your current cart before taking another.");
        return false;
    }

    new Float:shaftX, Float:shaftY, Float:x, Float:y, Float:z, Float:angle;
    Carts_ShaftPoint(cart,shaftX,shaftY);
    Carts_GetPos(cart,x,y,z,angle);

    if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || !IsPlayerInRangeOfPoint(playerid,CARTS_SHAFT_REACH,shaftX,shaftY,z + 1.5))
    {
        Gui_Notify(playerid,"Ride closer to the cart's shafts to hitch your horse.");
        return false;
    }

	Carts_TakeHold(playerid,cart);
	s_Carts[cart][E_CART_HITCHED] = true;
	return true;
}

stock Carts_Release(cart)
{
	if (!Carts_IsValid(cart))
	{
		return;
	}

	new playerid = s_Carts[cart][E_CART_MOVER];

	if (playerid != INVALID_PLAYER_ID && playerid < MAX_PLAYERS)
	{
		s_CartOfPlayer[playerid] = -1;
	}

	s_Carts[cart][E_CART_MOVER] = INVALID_PLAYER_ID;
	s_Carts[cart][E_CART_HITCHED] = false;
	Carts_Save(cart);
}

stock Carts_Follow(cart,Float:px,Float:py,Float:pz,Float:facing)
{
	new E_CART_KIND:kind = s_Carts[cart][E_CART_KIND_ID], Float:x, Float:y, Float:a;

	if (g_CartDefs[kind][E_CART_DEF_HITCHED])
	{
		x = px + floatsin(facing,degrees) * CARTS_HITCH;
		y = py - floatcos(facing,degrees) * CARTS_HITCH;
		a = facing + 180.0;
	}
	else
	{
		new Float:behindX = floatsin(facing,degrees), Float:behindY = -floatcos(facing,degrees);
		new Float:awayX = s_Carts[cart][E_CART_POS][0] - px, Float:awayY = s_Carts[cart][E_CART_POS][1] - py, Float:gap = VectorSize(awayX,awayY,0.0);

		if (gap < 0.05)
		{
			awayX = behindX;
			awayY = behindY;
		}
		else
		{
			awayX /= gap;
			awayY /= gap;
		}

		new bool:still = !s_Carts[cart][E_CART_PULLER_SEEN] || VectorSize(px - s_Carts[cart][E_CART_PULLER][0],py - s_Carts[cart][E_CART_PULLER][1],0.0) < CARTS_STILL;
		s_Carts[cart][E_CART_PULLER][0] = px;
		s_Carts[cart][E_CART_PULLER][1] = py;
		s_Carts[cart][E_CART_PULLER_SEEN] = true;

		if (!still || awayX * behindX + awayY * behindY > 0.0)
		{
			new Float:swing = atan2(awayX * behindY - awayY * behindX,awayX * behindX + awayY * behindY);

			if (swing > CARTS_SWING)
			{
				swing = CARTS_SWING;
			}
			else if (swing < -CARTS_SWING)
			{
				swing = -CARTS_SWING;
			}

			new Float:turnedX = awayX * floatcos(swing,degrees) - awayY * floatsin(swing,degrees);
			awayY = awayX * floatsin(swing,degrees) + awayY * floatcos(swing,degrees);
			awayX = turnedX;
		}

		x = px + awayX * CARTS_PULL;
		y = py + awayY * CARTS_PULL;
		a = atan2(-awayX,awayY);
	}

    new Float:z, Float:pitch, Float:roll;
    Carts_GroundPose(x,y,pz,a,z,pitch,roll);
	new Float:stepX = x - s_Carts[cart][E_CART_POS][0], Float:stepY = y - s_Carts[cart][E_CART_POS][1], Float:moved = VectorSize(stepX,stepY,0.0);

	if (moved < 0.02 && floatabs(a - s_Carts[cart][E_CART_POS][3]) < 0.5 && floatabs(z - s_Carts[cart][E_CART_POS][2]) < 0.01 && floatabs(pitch - s_Carts[cart][E_CART_PITCH]) < 0.1 && floatabs(roll - s_Carts[cart][E_CART_ROLL]) < 0.1)
	{
		return;
	}

	s_Carts[cart][E_CART_POS][0] = x;
	s_Carts[cart][E_CART_POS][1] = y;
	s_Carts[cart][E_CART_POS][2] = z;
	s_Carts[cart][E_CART_POS][3] = a;
	s_Carts[cart][E_CART_PITCH] = pitch;
    s_Carts[cart][E_CART_ROLL] = roll;
	SetDynamicObjectPos(s_Carts[cart][E_CART_BODY],x,y,z);
	SetDynamicObjectRot(s_Carts[cart][E_CART_BODY],pitch,roll,a);
	s_Carts[cart][E_CART_SPIN] -= ((stepX * -floatsin(a,degrees) + stepY * floatcos(a,degrees)) / g_CartDefs[kind][E_CART_DEF_RADIUS]) * 57.2958;

	if (s_Carts[cart][E_CART_SPIN] > 360.0 || s_Carts[cart][E_CART_SPIN] < -360.0)
	{
		s_Carts[cart][E_CART_SPIN] = floatfract(s_Carts[cart][E_CART_SPIN] / 360.0) * 360.0;
	}

	Carts_PlaceParts(cart);
	Carts_UpdateSeats(cart);

	if (GetTickCount() - s_Carts[cart][E_CART_SAVED_AT] > CARTS_SAVE_MS)
	{
		Carts_Save(cart);
	}
}

stock Float:Carts_SpeedFactor(cart)
{
	if (!Carts_IsValid(cart))
	{
		return 1.0;
	}

	new Float:factor = g_CartPull[s_Carts[cart][E_CART_KIND_ID]], containerid = s_Carts[cart][E_CART_CONTAINER];

	if (containerid != INVALID_CONTAINER_ID && Container_GetSlots(containerid) > 0 && Container_GetCount(containerid) * 2 > Container_GetSlots(containerid))
	{
		factor *= 0.9;
	}

	return factor;
}

stock bool:Carts_SeatIsChair(E_CART_KIND:kind,seat)
{
    return g_CartSeats[kind][seat * 4 + 2] >= 1.0;
}

stock Float:Carts_GetSeatLift(E_CART_KIND:kind,seat)
{
    return Carts_SeatIsChair(kind,seat) ? CARTS_SEAT_LIFT_CHAIR : CARTS_SEAT_LIFT_GROUND;
}

stock Carts_GetSeatOffset(E_CART_KIND:kind,seat,Float:pitch,Float:roll,Float:angle,&Float:x,&Float:y,&Float:z,&Float:facing)
{
    Carts_GetPartOffset(g_CartSeats[kind][seat * 4],g_CartSeats[kind][seat * 4 + 1],g_CartSeats[kind][seat * 4 + 2],pitch,roll,angle,x,y,z);
    z += Carts_GetSeatLift(kind,seat);
    facing = angle + g_CartSeats[kind][seat * 4 + 3];
}

stock Carts_SeatWorld(cart,seat,&Float:x,&Float:y,&Float:z,&Float:facing)
{
	new E_CART_KIND:kind = s_Carts[cart][E_CART_KIND_ID], Float:a = s_Carts[cart][E_CART_POS][3];
    Carts_GetSeatOffset(kind,seat,s_Carts[cart][E_CART_PITCH],s_Carts[cart][E_CART_ROLL],a,x,y,z,facing);
    x += s_Carts[cart][E_CART_POS][0];
    y += s_Carts[cart][E_CART_POS][1];
    z += s_Carts[cart][E_CART_POS][2];
}

stock Carts_BenchWorld(cart,&Float:x,&Float:y,&Float:z,&Float:facing)
{
	new E_CART_KIND:kind = s_Carts[cart][E_CART_KIND_ID], Float:a = s_Carts[cart][E_CART_POS][3];
    Carts_PartPos(cart,g_CartBench[kind][0],g_CartBench[kind][1],g_CartBench[kind][2],x,y,z);
    z += CARTS_SEAT_LIFT_CHAIR;
	facing = a + 180.0;
}

stock Carts_GetSeat(playerid)
{
	return Util_IsValidPlayer(playerid) && s_PlayerSeat[playerid] != -1 ? s_PlayerSeat[playerid] / CARTS_SEATS_MAX : -1;
}

stock bool:Carts_IsPrisonerSeated(playerid)
{
	new cart = Carts_GetSeat(playerid);
	return cart != -1 && g_CartSeatPrisoner[s_Carts[cart][E_CART_KIND_ID]];
}

stock Carts_FreeSeat(cart)
{
	if (!Carts_IsValid(cart))
	{
		return -1;
	}

	for (new seat = 0;seat < g_CartSeatCount[s_Carts[cart][E_CART_KIND_ID]];seat++)
	{
		if (s_CartSeated[cart][seat] == INVALID_PLAYER_ID)
		{
			return seat;
		}
	}

	return -1;
}

stock Carts_CountSeated(cart)
{
	new count = 0;

	for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
	{
		if (Carts_IsValid(cart) && s_CartSeated[cart][seat] != INVALID_PLAYER_ID)
		{
			count++;
		}
	}

	return count;
}

stock Carts_GetSeated(cart,seat)
{
	return Carts_IsValid(cart) && seat >= 0 && seat < CARTS_SEATS_MAX ? s_CartSeated[cart][seat] : INVALID_PLAYER_ID;
}

stock bool:Carts_GetSeatAnimation(E_CART_KIND:kind,seat,sex,library[],librarySize,name[],nameSize,&bool:freeze)
{
    if (kind < CART_KIND_HANDCART || kind >= CART_KIND_COUNT || seat < 0 || seat >= g_CartSeatCount[kind])
    {
        return false;
    }

    freeze = false;

    if (Carts_SeatIsChair(kind,seat))
    {
        strcopy(library,"INT_OFFICE",librarySize);
        strcopy(name,"OFF_Sit_Idle_Loop",nameSize);
    }
    else if (kind == CART_KIND_WAGON || kind == CART_KIND_COACH || kind == CART_KIND_PUBLIC_COACH)
    {
        freeze = true;
        strcopy(library,"BEACH",librarySize);
        strcopy(name,sex == 1 ? ("ParkSit_W_loop") : ("ParkSit_M_loop"),nameSize);
    }
    else
    {
        strcopy(library,"BEACH",librarySize);
        strcopy(name,"ParkSit_M_loop",nameSize);
    }

    return true;
}

static bool:Carts_SitterPoseHolds(playerid,cart,seat)
{
	new library[16], name[24], bool:freeze, playing[16], playingName[24];
	Carts_GetSeatAnimation(s_Carts[cart][E_CART_KIND_ID],seat,Character_GetSex(playerid),library,sizeof(library),name,sizeof(name),freeze);
	GetAnimationName(GetPlayerAnimationIndex(playerid),playing,sizeof(playing),playingName,sizeof(playingName));
	return !strcmp(library,playing,true) && !strcmp(name,playingName,true);
}

static Carts_ApplySitterPose(playerid,cart,seat)
{
	s_SitterPoseTick[playerid] = GetTickCount();
	new library[16], name[24], bool:freeze;
	Carts_GetSeatAnimation(s_Carts[cart][E_CART_KIND_ID],seat,Character_GetSex(playerid),library,sizeof(library),name,sizeof(name),freeze);
	ApplyAnimation(playerid,library,name,4.1,true,false,false,freeze,0,SYNC_ALL);
}

static Carts_PlaceSitter(playerid,cart,seat,bool:board = false)
{
	new Float:x, Float:y, Float:z, Float:facing;
	Carts_SeatWorld(cart,seat,x,y,z,facing);
	SetPlayerPos(playerid,x,y,z);
	SetPlayerFacingAngle(playerid,facing);

	new tick = GetTickCount();
	s_SitterMovedTick[playerid] = tick;

	if (board || (tick - s_SitterPoseTick[playerid] >= CARTS_POSE_RETRY_MS && !Carts_SitterPoseHolds(playerid,cart,seat)) || tick - s_SitterPoseTick[playerid] >= CARTS_POSE_RESYNC_MS)
	{
		Carts_ApplySitterPose(playerid,cart,seat);
	}
}

static Carts_SettleSitters()
{
	new tick = GetTickCount();

	for (new playerid = 0;playerid < MAX_PLAYERS;playerid++)
	{
		if (s_PlayerSeat[playerid] == -1 || s_SitterMovedTick[playerid] == 0 || tick - s_SitterMovedTick[playerid] < CARTS_POSE_SETTLE_MS || !IsPlayerConnected(playerid))
		{
			continue;
		}

		s_SitterMovedTick[playerid] = 0;
		new cart = s_PlayerSeat[playerid] / CARTS_SEATS_MAX;

		if (Carts_IsValid(cart))
		{
			Carts_ApplySitterPose(playerid,cart,s_PlayerSeat[playerid] % CARTS_SEATS_MAX);
		}
	}
}

stock bool:Carts_Sit(playerid,cart,seat)
{
	if (!Carts_IsValid(cart) || seat < 0 || seat >= g_CartSeatCount[s_Carts[cart][E_CART_KIND_ID]] || s_CartSeated[cart][seat] != INVALID_PLAYER_ID || s_PlayerSeat[playerid] != -1 || s_CartOfPlayer[playerid] != -1 || Mount_IsRiding(playerid))
	{
		return false;
	}

	s_CartSeated[cart][seat] = playerid;
	s_PlayerSeat[playerid] = cart * CARTS_SEATS_MAX + seat;
	TogglePlayerControllable(playerid,false);
	Carts_PlaceSitter(playerid,cart,seat,true);

	return true;
}

stock Carts_Stand(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_PlayerSeat[playerid] == -1)
	{
		return;
	}

	new cart = s_PlayerSeat[playerid] / CARTS_SEATS_MAX, seat = s_PlayerSeat[playerid] % CARTS_SEATS_MAX;
	s_PlayerSeat[playerid] = -1;

	if (Carts_IsValid(cart))
	{
		s_CartSeated[cart][seat] = INVALID_PLAYER_ID;
		new Float:x, Float:y, Float:z, Float:facing, Float:side = g_CartSeats[s_Carts[cart][E_CART_KIND_ID]][seat * 4] < 0.0 ? -1.0 : 1.0, Float:a = s_Carts[cart][E_CART_POS][3];
		Carts_SeatWorld(cart,seat,x,y,z,facing);
		x += side * 1.4 * floatcos(a,degrees);
		y += side * 1.4 * floatsin(a,degrees);
		SetPlayerPos(playerid,x,y,s_Carts[cart][E_CART_POS][2] + 1.0);
	}

	TogglePlayerControllable(playerid,true);
	ApplyAnimation(playerid,"PED","IDLE_stance",4.1,false,false,false,false,0,SYNC_ALL);
	ClearAnimations(playerid,SYNC_ALL);
	SetTimerEx("Carts_StandNudge",CARTS_STAND_NUDGE_MS,false,"d",playerid);
}

forward Carts_StandNudge(playerid);
public Carts_StandNudge(playerid)
{
	if (IsPlayerConnected(playerid) && s_PlayerSeat[playerid] == -1)
	{
		SetPlayerVelocity(playerid,0.0,0.0,CARTS_STAND_NUDGE);
	}

	return 1;
}

stock Carts_UnseatAll(cart)
{
	for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
	{
		new playerid = s_CartSeated[cart][seat];

		if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
		{
			Carts_Stand(playerid);
		}

		s_CartSeated[cart][seat] = INVALID_PLAYER_ID;
	}
}

stock Carts_UpdateSeats(cart)
{
	for (new seat = 0;seat < g_CartSeatCount[s_Carts[cart][E_CART_KIND_ID]];seat++)
	{
		new playerid = s_CartSeated[cart][seat];

		if (playerid == INVALID_PLAYER_ID)
		{
			continue;
		}

		if (!IsPlayerConnected(playerid))
		{
			s_CartSeated[cart][seat] = INVALID_PLAYER_ID;
			continue;
		}

		Carts_PlaceSitter(playerid,cart,seat);
	}
}

stock Carts_FindByRow(row)
{
	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (s_Carts[cart][E_CART_USED] && s_Carts[cart][E_CART_ROW] == row)
		{
			return cart;
		}
	}

	return -1;
}

stock Carts_GetRow(cart)
{
	return Carts_IsValid(cart) ? s_Carts[cart][E_CART_ROW] : 0;
}

Timer_Declare(Carts_Tick)
{
	Carts_SettleSitters();

	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (!s_Carts[cart][E_CART_USED] || s_Carts[cart][E_CART_MOVER] == INVALID_PLAYER_ID)
		{
			continue;
		}

		new playerid = s_Carts[cart][E_CART_MOVER];

		if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0)
		{
			Carts_Release(cart);
			continue;
		}

		new Float:px, Float:py, Float:pz, Float:facing;
		GetPlayerPos(playerid,px,py,pz);
		GetPlayerFacingAngle(playerid,facing);

		if (s_Carts[cart][E_CART_HITCHED])
		{
			if (!Mount_IsRiding(playerid))
			{
				Carts_Release(cart);
				Gui_Notify(playerid,"You get down and leave the cart standing.");
				continue;
			}
		}
		else
		{
			new Float:vx, Float:vy, Float:vz;
			GetPlayerVelocity(playerid,vx,vy,vz);

			if (VectorSize(vx,vy,0.0) > CARTS_RUN_SPEED || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || Mount_IsRiding(playerid))
			{
				Carts_Release(cart);
				Gui_Notify(playerid,"You can't run with a handcart. You let go of it.");
				continue;
			}

			if (VectorSize(px - s_Carts[cart][E_CART_POS][0],py - s_Carts[cart][E_CART_POS][1],0.0) > CARTS_PULL + CARTS_LEASH)
			{
				Carts_Release(cart);
				continue;
			}
		}

		Carts_Follow(cart,px,py,pz,facing);
	}

	return 1;
}

forward Task:Carts_LoadAll();
#pragma warning push
#pragma warning disable 204
async Task:Carts_LoadAll()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, owner_character_id, container_id, x, y, z, a, locked FROM carts ORDER BY id"));
	new rows = cache_num_rows(), loaded = 0;

	for (new row = 0;row < rows;row++)
	{
		new id, kind, owner, containerid, locked, Float:x, Float:y, Float:z, Float:a;
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name_int(row,"kind",kind);
		cache_get_value_name_int(row,"owner_character_id",owner);
		cache_get_value_name_int(row,"container_id",containerid);
		cache_get_value_name_float(row,"x",x);
		cache_get_value_name_float(row,"y",y);
		cache_get_value_name_float(row,"z",z);
		cache_get_value_name_float(row,"a",a);
		cache_get_value_name_int(row,"locked",locked);

		if (kind >= 0 && kind < _:CART_KIND_COUNT && Carts_Store(id,E_CART_KIND:kind,owner,containerid,x,y,z,a,locked != 0) != -1)
		{
			loaded++;
		}
	}

	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (s_Carts[cart][E_CART_USED] && s_Carts[cart][E_CART_CONTAINER] != INVALID_CONTAINER_ID)
		{
			await Container_Load(s_Carts[cart][E_CART_CONTAINER]);
			Carts_RefreshLoad(cart);
		}
	}

	return async loaded;
}
#pragma warning pop

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CartOfPlayer[playerid] = -1;
	s_CartThief[playerid] = -1;
	s_PlayerSeat[playerid] = -1;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_CartOfPlayer[playerid] != -1)
	{
		Carts_Release(s_CartOfPlayer[playerid]);
	}

	if (s_PlayerSeat[playerid] != -1)
	{
		new cart = s_PlayerSeat[playerid] / CARTS_SEATS_MAX;

		if (Carts_IsValid(cart))
		{
			s_CartSeated[cart][s_PlayerSeat[playerid] % CARTS_SEATS_MAX] = INVALID_PLAYER_ID;
		}

		s_PlayerSeat[playerid] = -1;
	}
}
