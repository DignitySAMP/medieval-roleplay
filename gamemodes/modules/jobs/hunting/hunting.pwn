#define HUNTING_CARCASS_SPECIES_MASK (255)
#define HUNTING_CARCASS_FEMALE (256)
#define HUNTING_CARCASS_CLEAN (512)
#define HUNTING_CARCASS_DATA_MASK (1023)

enum E_HUNT_CARCASS
{
	bool:E_HC_USED,
	E_HC_SPECIES,
	E_HC_KIND,
	bool:E_HC_FEMALE,
	Float:E_HC_POS[4],
	E_HC_KILLER,
	bool:E_HC_CLEAN,
	E_HC_NODE,
	E_HC_TOKEN,
	STREAMER_TAG_OBJECT:E_HC_OBJECT,
	STREAMER_TAG_3D_TEXT_LABEL:E_HC_LABEL,
	E_HC_CREATED,
	bool:E_HC_DRESSED,
	E_HC_GONE_AT,
}

static s_Carcasses[HUNTING_CARCASSES_MAX][E_HUNT_CARCASS];
static s_CarcassTokens;
static s_Licences[MAX_PLAYERS][HUNT_LICENCE_COUNT];
static s_DressRecipes[4] = {-1, ...};
static s_HuntPrompt[MAX_PLAYERS] = {-1, ...};
static s_HuntInfobox[MAX_PLAYERS];
static s_LicenceWarned[MAX_PLAYERS];

forward Task:Hunting_LoadLicences(playerid,characterid);
forward Task:Hunting_AttachNode(carcass,token,kind);

stock Hunting_SeasonIndex()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return year * 4 + _:Calendar_GetSeason();
}

stock bool:Hunting_HasLicence(playerid,licence)
{
	return Util_IsValidPlayer(playerid) && licence >= 0 && licence < HUNT_LICENCE_COUNT && s_Licences[playerid][licence] == Hunting_SeasonIndex();
}

stock Hunting_LicenceForTrade(trade)
{
	for (new licence = 0;licence < HUNT_LICENCE_COUNT;licence++)
	{
		if (g_HuntLicenceTrades[licence] == trade)
		{
			return licence;
		}
	}

	return -1;
}

stock Hunting_SetLicence(playerid,licence,seasonIndex)
{
	if (!Util_IsValidPlayer(playerid) || licence < 0 || licence >= HUNT_LICENCE_COUNT)
	{
		return;
	}

	s_Licences[playerid][licence] = seasonIndex;

	if (Character_GetId(playerid) > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO licences (character_id, licence, season_index) VALUES (%d, %d, %d) ON DUPLICATE KEY UPDATE season_index = VALUES(season_index)",Character_GetId(playerid),licence,seasonIndex));
	}
}

stock bool:Hunting_BuyLicence(playerid,licence)
{
	if (licence < 0 || licence >= HUNT_LICENCE_COUNT || Hunting_HasLicence(playerid,licence))
	{
		return false;
	}

	if (Economy_Pay(playerid,Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_LICENCE),Realm_GetTreasury(),"licence") != PAY_OK)
	{
		return false;
	}

	Hunting_SetLicence(playerid,licence,Hunting_SeasonIndex());
	return true;
}

#pragma warning push
#pragma warning disable 204
async Task:Hunting_LoadLicences(playerid,characterid)
{
	for (new licence = 0;licence < HUNT_LICENCE_COUNT;licence++)
	{
		s_Licences[playerid][licence] = -1;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT licence, season_index FROM licences WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new licence, season;
		cache_get_value_name_int(r,"licence",licence);
		cache_get_value_name_int(r,"season_index",season);

		if (licence >= 0 && licence < HUNT_LICENCE_COUNT)
		{
			s_Licences[playerid][licence] = season;
		}
	}

	return async 1;
}
#pragma warning pop

stock bool:Hunting_NeedsLicence(playerid,trade)
{
	new licence = Hunting_LicenceForTrade(trade);
	return licence != -1 && !Hunting_HasLicence(playerid,licence);
}

stock bool:Hunting_IsPoaching(playerid,species,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	if (species < 0 || species >= ANIMAL_SPECIES_COUNT || g_AnimalDefs[species][E_ANIMAL_DEF_GROUP] == ANIMAL_GROUP_HERD)
	{
		return false;
	}

	new bit = g_AnimalDefs[species][E_ANIMAL_DEF_PROTECT_BIT];

	if (bit != -1 && (Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_PROTECTED) & (1 << bit)))
	{
		format(reason,size,"the %s is protected by the count",g_AnimalDefs[species][E_ANIMAL_DEF_NAME]);
		return true;
	}

	if (g_AnimalDefs[species][E_ANIMAL_DEF_GROUP] != ANIMAL_GROUP_GAME)
	{
		return false;
	}

	if (Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_CLOSED_SEASONS) & (1 << _:Calendar_GetSeason()))
	{
		strcopy(reason,"the hunting season is closed",size);
		return true;
	}

	if (!Hunting_HasLicence(playerid,HUNT_LICENCE_HUNT))
	{
		strcopy(reason,"you have no hunting licence",size);
		return true;
	}

	return false;
}

stock bool:Hunting_YieldsItem(item)
{
	for (new species = 0;species < ANIMAL_SPECIES_COUNT;species++)
	{
		for (new slot = 0;slot < 3;slot++)
		{
			if (g_HuntLootDefs[species][E_HUNT_LOOT_ITEM][slot] == item)
			{
				return true;
			}
		}
	}

	return false;
}

stock Hunting_GetCarcassKind(species)
{
	return species >= 0 && species < ANIMAL_SPECIES_COUNT ? g_HuntLootDefs[species][E_HUNT_LOOT_CARCASS] : HUNT_CARCASS_SMALL;
}

stock bool:Hunting_IsCarcass(carcass)
{
	return carcass >= 0 && carcass < HUNTING_CARCASSES_MAX && s_Carcasses[carcass][E_HC_USED];
}

stock Hunting_GetCarcassSpecies(carcass)
{
	return Hunting_IsCarcass(carcass) ? s_Carcasses[carcass][E_HC_SPECIES] : -1;
}

stock Hunting_GetCarcassNode(carcass)
{
	return Hunting_IsCarcass(carcass) ? s_Carcasses[carcass][E_HC_NODE] : -1;
}

stock bool:Hunting_IsCarcassDressed(carcass)
{
	return Hunting_IsCarcass(carcass) && s_Carcasses[carcass][E_HC_DRESSED];
}

stock Hunting_GetCarcassSkinModel(carcass)
{
	new model = 0, txd[16], texture[24], colour;

	if (Hunting_IsCarcass(carcass) && IsValidDynamicObject(s_Carcasses[carcass][E_HC_OBJECT]))
	{
		GetDynamicObjectMaterial(s_Carcasses[carcass][E_HC_OBJECT],HUNTING_DRESSED_SLOT,model,txd,texture,colour);
	}

	return model;
}

stock Hunting_GetCarcassMsLeft(carcass)
{
	return Hunting_IsCarcass(carcass) ? s_Carcasses[carcass][E_HC_GONE_AT] - GetTickCount() : 0;
}

stock Hunting_GetCarcassModel(carcass)
{
	return Hunting_IsCarcass(carcass) && IsValidDynamicObject(s_Carcasses[carcass][E_HC_OBJECT]) ? Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_Carcasses[carcass][E_HC_OBJECT],E_STREAMER_MODEL_ID) : 0;
}

stock Hunting_CountCarcasses()
{
	new count = 0;

	for (new carcass = 0;carcass < HUNTING_CARCASSES_MAX;carcass++)
	{
		if (s_Carcasses[carcass][E_HC_USED])
		{
			count++;
		}
	}

	return count;
}

stock Hunting_FindCarcass(Float:x,Float:y,Float:z,Float:range,kind = -1)
{
	new best = -1, Float:bestDistance = range;

	for (new carcass = 0;carcass < HUNTING_CARCASSES_MAX;carcass++)
	{
		if (!s_Carcasses[carcass][E_HC_USED] || s_Carcasses[carcass][E_HC_DRESSED] || (kind != -1 && s_Carcasses[carcass][E_HC_KIND] != kind))
		{
			continue;
		}

		new Float:d = VectorSize(s_Carcasses[carcass][E_HC_POS][0] - x,s_Carcasses[carcass][E_HC_POS][1] - y,s_Carcasses[carcass][E_HC_POS][2] - z);

		if (d <= bestDistance)
		{
			bestDistance = d;
			best = carcass;
		}
	}

	return best;
}

stock Hunting_PackCarcass(species,bool:female,bool:isClean)
{
    if (species < 0 || species >= ANIMAL_SPECIES_COUNT)
    {
        return 0;
    }

    return (species + 1) | (female ? HUNTING_CARCASS_FEMALE : 0) | (isClean ? HUNTING_CARCASS_CLEAN : 0);
}

stock Hunting_UnpackCarcass(data)
{
    new species = (data & HUNTING_CARCASS_SPECIES_MASK) - 1;
    return data > 0 && (data & ~HUNTING_CARCASS_DATA_MASK) == 0 && species >= 0 && species < ANIMAL_SPECIES_COUNT ? species : -1;
}

stock Hunting_GetItemModel(data)
{
    new species = Hunting_UnpackCarcass(data);
    return species == -1 ? MODEL_PRODUCE_CARCASS_DEER : Hunting_CarcassModel(species,Hunting_GetCarcassKind(species),(data & HUNTING_CARCASS_FEMALE) != 0);
}

stock Hunting_PutDownCarcass(data,Float:x,Float:y,Float:z,Float:angle,killer)
{
    new species = Hunting_UnpackCarcass(data);

    if (species == -1)
    {
        return -1;
    }

    return Hunting_CreateCarcass(species,x,y,z,killer,(data & HUNTING_CARCASS_CLEAN) != 0,(data & HUNTING_CARCASS_FEMALE) != 0,angle);
}

static Hunting_CarcassModel(species,kind,bool:female)
{
	if (species == ANIMAL_RED_DEER)
	{
		return female ? MODEL_CARCASS_RED_HIND : MODEL_CARCASS_RED_STAG;
	}

	if (species == ANIMAL_ROE_DEER)
	{
		return female ? MODEL_CARCASS_ROE_DOE : MODEL_CARCASS_ROE_BUCK;
	}

	if (species == ANIMAL_BOAR)
	{
		return female ? MODEL_CARCASS_SOW : MODEL_CARCASS_BOAR;
	}

	if (species == ANIMAL_WOLF)
	{
		return female ? MODEL_CARCASS_SHE_WOLF : MODEL_CARCASS_WOLF;
	}

	if (species == ANIMAL_FOX)
	{
		return female ? MODEL_CARCASS_VIXEN : MODEL_CARCASS_FOX;
	}

	if (species == ANIMAL_BEAR)
	{
		return female ? MODEL_CARCASS_SHE_BEAR : MODEL_CARCASS_BEAR;
	}

	switch (species)
	{
		case ANIMAL_HARE: return MODEL_CARCASS_HARE;
		case ANIMAL_RABBIT: return MODEL_CARCASS_RABBIT;
		case ANIMAL_PHEASANT: return MODEL_CARCASS_PHEASANT;
		case ANIMAL_DUCK: return MODEL_CARCASS_DUCK;
		case ANIMAL_HERON: return MODEL_CARCASS_HERON;
		case ANIMAL_COW: return MODEL_CARCASS_COW;
		case ANIMAL_SHEEP: return MODEL_CARCASS_SHEEP;
		case ANIMAL_GOAT: return MODEL_CARCASS_GOAT;
		case ANIMAL_PIG: return MODEL_CARCASS_PIG;
		case ANIMAL_CHICKEN: return MODEL_CARCASS_HEN;
	}

	switch (kind)
	{
		case HUNT_CARCASS_SMALL: return MODEL_PRODUCE_CARCASS_SMALL;
		case HUNT_CARCASS_DEER: return MODEL_PRODUCE_CARCASS_DEER;
	}

	return MODEL_PRODUCE_CARCASS_BIG;
}

static Hunting_CarcassReach(model,&Float:halfX,&Float:halfY)
{
	switch (model)
	{
		case MODEL_CARCASS_RED_STAG:
		{
			halfX = 1.01;
			halfY = 1.16;
		}
		case MODEL_CARCASS_RED_HIND:
		{
			halfX = 0.77;
			halfY = 1.07;
		}
		case MODEL_CARCASS_WOLF:
		{
			halfX = 0.53;
			halfY = 0.69;
		}
		case MODEL_CARCASS_SHE_WOLF:
		{
			halfX = 0.48;
			halfY = 0.62;
		}
		case MODEL_CARCASS_FOX:
		{
			halfX = 0.3;
			halfY = 0.59;
		}
		case MODEL_CARCASS_VIXEN:
		{
			halfX = 0.27;
			halfY = 0.55;
		}
		case MODEL_CARCASS_BEAR:
		{
			halfX = 0.62;
			halfY = 0.97;
		}
		case MODEL_CARCASS_SHE_BEAR:
		{
			halfX = 0.52;
			halfY = 0.81;
		}
		case MODEL_CARCASS_ROE_BUCK:
		{
			halfX = 0.53;
			halfY = 0.69;
		}
		case MODEL_CARCASS_ROE_DOE:
		{
			halfX = 0.47;
			halfY = 0.65;
		}
		case MODEL_CARCASS_BOAR:
		{
			halfX = 0.57;
			halfY = 0.79;
		}
		case MODEL_CARCASS_SOW:
		{
			halfX = 0.45;
			halfY = 0.65;
		}
		case MODEL_CARCASS_HARE:
		{
			halfX = 0.43;
			halfY = 0.47;
		}
		case MODEL_CARCASS_RABBIT:
		{
			halfX = 0.31;
			halfY = 0.36;
		}
		case MODEL_CARCASS_PHEASANT:
		{
			halfX = 0.35;
			halfY = 0.48;
		}
		case MODEL_CARCASS_DUCK:
		{
			halfX = 0.34;
			halfY = 0.4;
		}
		case MODEL_CARCASS_HERON:
		{
			halfX = 0.69;
			halfY = 0.51;
		}
		case MODEL_CARCASS_COW:
		{
			halfX = 0.80;
			halfY = 1.14;
		}
		case MODEL_CARCASS_SHEEP:
		{
			halfX = 0.36;
			halfY = 0.58;
		}
		case MODEL_CARCASS_GOAT:
		{
			halfX = 0.52;
			halfY = 0.73;
		}
		case MODEL_CARCASS_PIG:
		{
			halfX = 0.45;
			halfY = 0.71;
		}
		case MODEL_CARCASS_HEN:
		{
			halfX = 0.22;
			halfY = 0.21;
		}
		case MODEL_PRODUCE_CARCASS_SMALL:
		{
			halfX = 0.3;
			halfY = 0.14;
		}
		case MODEL_PRODUCE_CARCASS_DEER:
		{
			halfX = 0.57;
			halfY = 0.33;
		}
		default:
		{
			halfX = 0.83;
			halfY = 0.48;
		}
	}

	halfX *= HUNTING_SAMPLE_SHARE;
	halfY *= HUNTING_SAMPLE_SHARE;
}

static bool:Hunting_SampleGround(Float:x,Float:y,Float:z,&Float:ground)
{
	new Float:hx, Float:hy;
	return CA_RayCastLine(x,y,z + HUNTING_SAMPLE_ABOVE,x,y,z - HUNTING_SAMPLE_BELOW,hx,hy,ground) != 0;
}

static Float:Hunting_AxisSlope(Float:x,Float:y,Float:z,Float:dirX,Float:dirY,Float:reach,&Float:ahead,&Float:behind)
{
	new bool:isAhead = Hunting_SampleGround(x + dirX * reach,y + dirY * reach,z,ahead), bool:isBehind = Hunting_SampleGround(x - dirX * reach,y - dirY * reach,z,behind), Float:slope = 0.0;

	if (isAhead && isBehind)
	{
		slope = (ahead - behind) / (reach * 2.0);
	}
	else if (isAhead)
	{
		slope = (ahead - z) / reach;
	}
	else if (isBehind)
	{
		slope = (z - behind) / reach;
	}

	if (!isAhead)
	{
		ahead = z + slope * reach;
	}

	if (!isBehind)
	{
		behind = z - slope * reach;
	}

	return Util_Clamp(slope,-HUNTING_SLOPE_MAX,HUNTING_SLOPE_MAX);
}

stock Hunting_FitToGround(model,Float:x,Float:y,&Float:z,Float:a,&Float:rx,&Float:ry)
{
	new Float:halfX, Float:halfY, Float:aheadX, Float:behindX, Float:aheadY, Float:behindY;
	Hunting_CarcassReach(model,halfX,halfY);

	new Float:cosine = floatcos(a,degrees), Float:sine = floatsin(a,degrees);
	new Float:slopeX = Hunting_AxisSlope(x,y,z,cosine,sine,halfX,aheadX,behindX), Float:slopeY = Hunting_AxisSlope(x,y,z,-sine,cosine,halfY,aheadY,behindY);
	new Float:gaps[4], Float:lowest = 0.0;
	gaps[0] = aheadX - (z + slopeX * halfX);
	gaps[1] = behindX - (z - slopeX * halfX);
	gaps[2] = aheadY - (z + slopeY * halfY);
	gaps[3] = behindY - (z - slopeY * halfY);

	for (new i = 0;i < sizeof(gaps);i++)
	{
		if (gaps[i] < lowest)
		{
			lowest = gaps[i];
		}
	}

	rx = atan(slopeY);
	ry = asin(-slopeX / floatsqroot(slopeX * slopeX + slopeY * slopeY + 1.0));
	z += lowest < -HUNTING_SINK_MAX ? -HUNTING_SINK_MAX : lowest;
}

stock bool:Hunting_GetCarcassPose(carcass,&Float:x,&Float:y,&Float:z,&Float:rx,&Float:ry,&Float:rz)
{
	if (!Hunting_IsCarcass(carcass) || !IsValidDynamicObject(s_Carcasses[carcass][E_HC_OBJECT]))
	{
		return false;
	}

	GetDynamicObjectPos(s_Carcasses[carcass][E_HC_OBJECT],x,y,z);
	GetDynamicObjectRot(s_Carcasses[carcass][E_HC_OBJECT],rx,ry,rz);
	return true;
}

stock Hunting_CreateCarcass(species,Float:x,Float:y,Float:z,killer,bool:isClean,bool:female = false,Float:angle = -1.0)
{
    if (species < 0 || species >= ANIMAL_SPECIES_COUNT)
    {
        return -1;
    }

	new carcass = -1;

	for (new i = 0;i < HUNTING_CARCASSES_MAX;i++)
	{
		if (!s_Carcasses[i][E_HC_USED])
		{
			carcass = i;
			break;
		}
	}

	if (carcass == -1)
	{
		new oldest = 0;

		for (new i = 1;i < HUNTING_CARCASSES_MAX;i++)
		{
			if (s_Carcasses[i][E_HC_CREATED] < s_Carcasses[oldest][E_HC_CREATED])
			{
				oldest = i;
			}
		}

		Hunting_RemoveCarcass(oldest);
		carcass = oldest;
	}

	new Float:hx, Float:hy, Float:hz, kind = Hunting_GetCarcassKind(species), Float:a = angle < 0.0 ? float(random(360)) : angle, label[64], model = Hunting_CarcassModel(species,kind,female), Float:rx = 0.0, Float:ry = 0.0, Float:objectZ;

	new Float:level, Float:fellZ = z;

	if (CA_RayCastLine(x,y,z + HUNTING_GROUND_ABOVE,x,y,z - HUNTING_GROUND_BELOW,hx,hy,hz) != 0)
	{
		z = hz;
	}

	objectZ = z;

	if (fellZ - z > HUNTING_FLOAT_ABOVE && Animals_WaterLevelNear(x,y,level) && level > z)
	{
		z = level;
		objectZ = level;
	}
	else
	{
		Hunting_FitToGround(model,x,y,objectZ,a,rx,ry);
	}

	s_Carcasses[carcass][E_HC_USED] = true;
	s_Carcasses[carcass][E_HC_SPECIES] = species;
	s_Carcasses[carcass][E_HC_KIND] = kind;
	s_Carcasses[carcass][E_HC_FEMALE] = female;
	s_Carcasses[carcass][E_HC_POS][0] = x;
	s_Carcasses[carcass][E_HC_POS][1] = y;
	s_Carcasses[carcass][E_HC_POS][2] = z;
	s_Carcasses[carcass][E_HC_POS][3] = a;
	s_Carcasses[carcass][E_HC_KILLER] = killer;
	s_Carcasses[carcass][E_HC_CLEAN] = isClean;
	s_Carcasses[carcass][E_HC_NODE] = -1;
	s_Carcasses[carcass][E_HC_TOKEN] = ++s_CarcassTokens;
	s_Carcasses[carcass][E_HC_CREATED] = GetTickCount();
	s_Carcasses[carcass][E_HC_DRESSED] = false;
	s_Carcasses[carcass][E_HC_GONE_AT] = s_Carcasses[carcass][E_HC_CREATED] + HUNTING_ROT_MS;
	s_Carcasses[carcass][E_HC_OBJECT] = CreateDynamicObject(model,x,y,objectZ,rx,ry,a,0,0,-1,120.0,120.0);

	if (kind == HUNT_CARCASS_SMALL)
	{
		format(label,sizeof(label),"A dead %s",g_AnimalDefs[species][E_ANIMAL_DEF_NAME]);
	}
	else
	{
		format(label,sizeof(label),"A dead %s\nWalk + Y to shoulder it",g_AnimalDefs[species][E_ANIMAL_DEF_NAME]);
	}

	s_Carcasses[carcass][E_HC_LABEL] = CreateDynamic3DTextLabel(label,HUNTING_LABEL_COLOUR,x,y,z + 0.6,8.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);

	if (g_HuntNodeKinds[kind][0] != EOS)
	{
		Hunting_AttachNode(carcass,s_Carcasses[carcass][E_HC_TOKEN],Work_FindKind(g_HuntNodeKinds[kind]));
	}

	pawn_call_public("Hunting_OnCarcass","dd",carcass,species);
	return carcass;
}

#pragma warning push
#pragma warning disable 204
async Task:Hunting_AttachNode(carcass,token,kind)
{
	if (kind == -1)
	{
		wait_ticks(1);
		return async -1;
	}

	new node = await Work_CreateNode(kind,s_Carcasses[carcass][E_HC_POS][0],s_Carcasses[carcass][E_HC_POS][1],s_Carcasses[carcass][E_HC_POS][2],s_Carcasses[carcass][E_HC_POS][3],0,0);

	if (!s_Carcasses[carcass][E_HC_USED] || s_Carcasses[carcass][E_HC_TOKEN] != token)
	{
		if (Work_IsValidNode(node))
		{
			Work_DeleteNode(node);
		}

		return async -1;
	}

	s_Carcasses[carcass][E_HC_NODE] = node;
	return async node;
}
#pragma warning pop

stock bool:Hunting_DressCarcass(carcass)
{
	if (!Hunting_IsCarcass(carcass) || s_Carcasses[carcass][E_HC_DRESSED] || s_Carcasses[carcass][E_HC_KIND] == HUNT_CARCASS_SMALL)
	{
		return false;
	}

	if (s_Carcasses[carcass][E_HC_NODE] != -1 && Work_IsValidNode(s_Carcasses[carcass][E_HC_NODE]))
	{
		Work_DeleteNode(s_Carcasses[carcass][E_HC_NODE]);
	}

	s_Carcasses[carcass][E_HC_NODE] = -1;
	s_Carcasses[carcass][E_HC_TOKEN] = ++s_CarcassTokens;
	s_Carcasses[carcass][E_HC_DRESSED] = true;
	s_Carcasses[carcass][E_HC_GONE_AT] = GetTickCount() + HUNTING_ROT_MS;

	if (IsValidDynamicObject(s_Carcasses[carcass][E_HC_OBJECT]))
	{
		SetDynamicObjectMaterial(s_Carcasses[carcass][E_HC_OBJECT],HUNTING_DRESSED_SLOT,HUNTING_DRESSED_MODEL,HUNTING_DRESSED_TXD,HUNTING_DRESSED_TEXTURE,0);
	}

	if (IsValidDynamic3DTextLabel(s_Carcasses[carcass][E_HC_LABEL]))
	{
		UpdateDynamic3DTextLabelText(s_Carcasses[carcass][E_HC_LABEL],HUNTING_LABEL_COLOUR,sprintf("What's left of a %s",g_AnimalDefs[s_Carcasses[carcass][E_HC_SPECIES]][E_ANIMAL_DEF_NAME]));
	}

	return true;
}

stock Hunting_RemoveCarcass(carcass)
{
	if (!Hunting_IsCarcass(carcass))
	{
		return;
	}

	if (IsValidDynamicObject(s_Carcasses[carcass][E_HC_OBJECT]))
	{
		DestroyDynamicObject(s_Carcasses[carcass][E_HC_OBJECT]);
	}

	if (IsValidDynamic3DTextLabel(s_Carcasses[carcass][E_HC_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Carcasses[carcass][E_HC_LABEL]);
	}

	if (s_Carcasses[carcass][E_HC_NODE] != -1 && Work_IsValidNode(s_Carcasses[carcass][E_HC_NODE]))
	{
		Work_DeleteNode(s_Carcasses[carcass][E_HC_NODE]);
	}

	s_Carcasses[carcass][E_HC_USED] = false;
	s_Carcasses[carcass][E_HC_NODE] = -1;
}

stock Hunting_GiveLoot(playerid,species,stars,bool:isClean)
{
	new given = 0, quality = Util_ClampInt(stars + (isClean ? 1 : 0),ITEM_STARS_MIN,ITEM_STARS_MAX);

	for (new i = 0;i < 3;i++)
	{
		new item = g_HuntLootDefs[species][E_HUNT_LOOT_ITEM][i], amount = g_HuntLootDefs[species][E_HUNT_LOOT_AMOUNT][i];

		if (item == -1 || amount <= 0)
		{
			continue;
		}

		new E_ITEM_KIND:kind = Item_GetDefKind(item);

		if (!Inventory_Give(playerid,kind,item,amount,quality))
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid,x,y,z);
			Drop_Create(kind,item,amount,x,y,z - 0.9,GetPlayerVirtualWorld(playerid),quality,.interior = GetPlayerInterior(playerid));
		}

		given += amount;
	}

	return given;
}

stock bool:Hunting_TakeSmall(playerid,carcass)
{
	if (!Hunting_IsCarcass(carcass) || s_Carcasses[carcass][E_HC_KIND] != HUNT_CARCASS_SMALL)
	{
		return false;
	}

	new species = s_Carcasses[carcass][E_HC_SPECIES], stars = 1 + Work_GetLevel(playerid,TRADE_HUNTING) / 3;
	Hunting_GiveLoot(playerid,species,stars,s_Carcasses[carcass][E_HC_CLEAN]);
	Work_AddPractice(playerid,TRADE_HUNTING,WORK_PRACTICE_PER_STAR);
	ApplyAnimation(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0,SYNC_ALL);
	Gui_Notify(playerid,sprintf("You take up the %s.",g_AnimalDefs[species][E_ANIMAL_DEF_NAME]));
	Hunting_RemoveCarcass(carcass);
	return true;
}

stock bool:Hunting_Shoulder(playerid,carcass)
{
	if (!Hunting_IsCarcass(carcass) || s_Carcasses[carcass][E_HC_KIND] == HUNT_CARCASS_SMALL || s_Carcasses[carcass][E_HC_DRESSED])
	{
		return false;
	}

	if (!Inventory_CanGive(playerid,ITEM_KIND_MATERIAL,ITEM_CARCASS,1))
	{
		Gui_Notify(playerid,"You can't carry that with what you've got on you.");
		return false;
	}

    new data = Hunting_PackCarcass(s_Carcasses[carcass][E_HC_SPECIES],s_Carcasses[carcass][E_HC_FEMALE],s_Carcasses[carcass][E_HC_CLEAN]);

    if (!Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_CARCASS,1,s_Carcasses[carcass][E_HC_CLEAN] ? 3 : 2,ITEM_FRESH_NOW,0,data))
    {
        return false;
    }
	ApplyAnimation(playerid,"CARRY","liftup",4.1,false,false,false,false,0,SYNC_ALL);
	Gui_Notify(playerid,"You heave the carcass onto your shoulders. A butcher joints it for the best cuts.");
	Hunting_RemoveCarcass(carcass);
	return true;
}

stock Hunting_ClaimBounty(playerid)
{
	new pelts = Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_PELT_WOLF), each = Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_WOLF_BOUNTY), money[24];

	if (pelts <= 0 || each <= 0)
	{
		Gui_Notify(playerid,each <= 0 ? ("The count pays no bounty on wolves now.") : ("Bring a wolf's pelt for the bounty."));
		return 0;
	}

	if (!Realm_PayFromTreasury(playerid,pelts * each,"wolf bounty",true))
	{
		Gui_Notify(playerid,"The steward shakes his head: there's no coin in the treasury for it now.");
		return 0;
	}

	Inventory_Take(playerid,ITEM_KIND_MATERIAL,ITEM_PELT_WOLF,pelts);
	Container_Add(Realm_GetTreasury(),ITEM_KIND_MATERIAL,ITEM_PELT_WOLF,pelts);
	Economy_Format(pelts * each,money);
	Gui_Notify(playerid,sprintf("The steward counts %d %s and pays you %s.",pelts,pelts == 1 ? ("pelt") : ("pelts"),money));
	return pelts;
}

stock Hunting_OpenLicences(playerid)
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, price[24];
	Economy_Format(Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_LICENCE),price);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Licences");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,HUNTING_PANEL_WIDTH,KIT_ROW * 5.0 + 6.0 + KIT_ROW + 12.0,"Licences",x,y,width);
	Kit_AddText(playerid,x,y,sprintf("A licence holds for this season and costs %s.",price),KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	for (new licence = 0;licence < HUNT_LICENCE_COUNT;licence++)
	{
		new bool:has = Hunting_HasLicence(playerid,licence), label[24];
		format(label,sizeof(label),"%s",g_HuntLicenceNames[licence]);
		label[0] = toupper(label[0]);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(licence + 2),width,label,licence,has ? KIT_COLOUR_MUTED : KIT_COLOUR_TEXT,has ? ("held") : price,has ? KIT_COLOUR_GOOD : KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 5.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= HUNT_LICENCE_COUNT)
	{
		return;
	}

	if (Hunting_HasLicence(playerid,pick))
	{
		Gui_Notify(playerid,"You hold that licence for this season.");
	}
	else if (Hunting_BuyLicence(playerid,pick))
	{
		Gui_Notify(playerid,sprintf("The steward writes out your %s licence for the season.",g_HuntLicenceNames[pick]));
	}
	else
	{
		Gui_Notify(playerid,"You can't pay for it.");
	}
}

static Hunting_ClearPrompt(playerid)
{
	if (s_HuntInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_HuntInfobox[playerid]);
	}

	s_HuntPrompt[playerid] = -1;
	s_HuntInfobox[playerid] = 0;
}

Timer_Declare(Hunting_Sweep)
{
	new tick = GetTickCount();

	for (new carcass = 0;carcass < HUNTING_CARCASSES_MAX;carcass++)
	{
		if (!s_Carcasses[carcass][E_HC_USED])
		{
			continue;
		}

		new node = s_Carcasses[carcass][E_HC_NODE];

		if (tick - s_Carcasses[carcass][E_HC_GONE_AT] >= 0)
		{
			Hunting_RemoveCarcass(carcass);
		}
		else if (node != -1 && (!Work_IsValidNode(node) || Work_GetNodeStock(node) <= 0))
		{
			Hunting_DressCarcass(carcass);
		}
	}

	return 1;
}

Timer_Declare(Hunting_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		new carcass = -1;

		if (Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Work_IsWorking(playerid) && GetPlayerVirtualWorld(playerid) == 0 && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid,x,y,z);
			carcass = Hunting_FindCarcass(x,y,z,HUNTING_REACH,HUNT_CARCASS_SMALL);
		}

		if (carcass == -1)
		{
			Hunting_ClearPrompt(playerid);
			continue;
		}

		if (carcass == s_HuntPrompt[playerid] && Infobox_IsShown(playerid,s_HuntInfobox[playerid]))
		{
			continue;
		}

		new title[24];
		strcopy(title,g_AnimalDefs[s_Carcasses[carcass][E_HC_SPECIES]][E_ANIMAL_DEF_NAME]);
		title[0] = toupper(title[0]);
		s_HuntPrompt[playerid] = carcass;
		s_HuntInfobox[playerid] = Infobox_Show(playerid,title,sprintf("Press ~y~Y~w~ to take up the %s.",g_AnimalDefs[s_Carcasses[carcass][E_HC_SPECIES]][E_ANIMAL_DEF_NAME]),3,0,true);
	}

	return 1;
}

forward bool:Hunting_PromptContext(playerid);

public bool:Hunting_PromptContext(playerid)
{
	return s_HuntPrompt[playerid] != -1;
}

forward Hunting_MenuLicences(playerid,index,data);

public Hunting_MenuLicences(playerid,index,data)
{
	Hunting_OpenLicences(playerid);
	return 1;
}

forward Hunting_MenuBounty(playerid,index,data);

public Hunting_MenuBounty(playerid,index,data)
{
	Hunting_ClaimBounty(playerid);
	return 1;
}

forward Hunting_OnCarcass(carcass,species);

public Hunting_OnCarcass(carcass,species)
{
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	s_DressRecipes[0] = Recipe_FindByName("Field-dress");
	s_DressRecipes[1] = Recipe_FindByName("Dress a boar");
	s_DressRecipes[2] = Recipe_FindByName("Skin a wolf");
	s_DressRecipes[3] = Recipe_FindByName("Dress a bear");
}

hook OnPlayerConnect(playerid)
{
	s_HuntPrompt[playerid] = -1;
	s_HuntInfobox[playerid] = 0;

	for (new licence = 0;licence < HUNT_LICENCE_COUNT;licence++)
	{
		s_Licences[playerid][licence] = -1;
	}
}

hook Character_OnLoaded(playerid,characterid)
{
	s_LicenceWarned[playerid] = 0;
	Hunting_LoadLicences(playerid,characterid);
}

hook Work_OnPoached(playerid,recipe)
{
	new trade = Recipe_GetTrade(recipe);

	if (trade == TRADE_HUNTING || !Hunting_NeedsLicence(playerid,trade))
	{
		return;
	}

	Law_Commit(playerid,LAW_CRIME_POACHING);

	if (gettime() - s_LicenceWarned[playerid] > 600)
	{
		s_LicenceWarned[playerid] = gettime();
		Gui_Notify(playerid,sprintf("You have no %s licence this season. If anyone saw, that's poaching: the steward in the ducal fortress sells them.",g_HuntLicenceNames[Hunting_LicenceForTrade(trade)]));
	}
}

hook Animals_OnKilled(animal,species,killerid,Float:x,Float:y,Float:z,hits,heldBy)
{
	new killer = 0, reason[48];

	if (IsPlayerConnected(killerid) && !IsPlayerNPC(killerid))
	{
		killer = Character_GetId(killerid);

		if (Hunting_IsPoaching(killerid,species,reason))
		{
			Law_Commit(killerid,LAW_CRIME_POACHING);
			Gui_Notify(killerid,sprintf("That's poaching: %s. If anyone saw, the law will hear of it.",reason));
		}

		Work_AddPractice(killerid,TRADE_HUNTING,WORK_PRACTICE_PER_STAR * (hits <= 1 ? 2 : 1));
	}
	else if (heldBy != -1)
	{
		killer = Hunting_GetTrapOwner(heldBy);
	}

	if (heldBy != -1)
	{
		Hunting_TrapLetGo(heldBy);
	}

	Hunting_CreateCarcass(species,x,y,z,killer,hits <= 1,Animals_IsFemale(animal));
}

hook Work_OnFinished(playerid,recipe,stars)
{
	new kind = -1;

	for (new i = 0;i < sizeof(s_DressRecipes);i++)
	{
		if (recipe != -1 && s_DressRecipes[i] == recipe)
		{
			kind = HUNT_CARCASS_DEER + i;
		}
	}

	if (kind == -1)
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	new carcass = Hunting_FindCarcass(x,y,z,HUNTING_DRESS_REACH,kind);

	if (carcass != -1)
	{
		Hunting_GiveLoot(playerid,s_Carcasses[carcass][E_HC_SPECIES],stars,s_Carcasses[carcass][E_HC_CLEAN]);
		Hunting_DressCarcass(carcass);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Work_IsWorking(playerid))
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	if (newkeys & KEY_WALK)
	{
		new carcass = Hunting_FindCarcass(x,y,z,HUNTING_REACH);

		if (carcass != -1 && s_Carcasses[carcass][E_HC_KIND] != HUNT_CARCASS_SMALL)
		{
			Hunting_Shoulder(playerid,carcass);
		}

		return;
	}

	if (s_HuntPrompt[playerid] != -1 && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		new carcass = s_HuntPrompt[playerid];
		Hunting_ClearPrompt(playerid);
		Hunting_TakeSmall(playerid,carcass);
	}
}

hook Actors_OnMenuBuild(playerid,index)
{
	if (index == -1 || index != Realm_GetSteward())
	{
		return;
	}

	Actors_MenuAdd(playerid,"Licences for the season","Hunting_MenuLicences");

	new pelts = Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_PELT_WOLF);

	if (pelts > 0)
	{
		Actors_MenuAdd(playerid,sprintf("Claim the wolf bounty (%d %s)",pelts,pelts == 1 ? ("pelt") : ("pelts")),"Hunting_MenuBounty",0,KIT_COLOUR_GOOD);
	}
}
