enum E_REALM_DECREE
{
	bool:E_RD_USED,
	E_RD_ROW,
	E_RD_KIND,
	E_RD_TEXT[REALM_DECREE_TEXT],
	E_RD_STARTS,
	E_RD_ENDS,
	E_RD_BY,
}

static s_RealmPolicy[REALM_POLICY_COUNT];
static s_RealmBounds[REALM_POLICY_COUNT][2];
static s_RealmCount;
static s_RealmRegent;
static s_RealmDuke;
static s_RealmCountSeen;
static s_RealmTreasury = INVALID_CONTAINER_ID;
static s_RealmDuchyTreasury = INVALID_CONTAINER_ID;
static s_RealmDues[REALM_VILLAGES];
static s_RealmDecrees[REALM_DECREES_MAX][E_REALM_DECREE];
static bool:s_RealmLoaded;

stock bool:Realm_IsLoaded()
{
	return s_RealmLoaded;
}

stock bool:Realm_GetVillageName(village,dest[],size = sizeof(dest))
{
	if (village < 0 || village >= REALM_VILLAGES)
	{
		dest[0] = EOS;
		return false;
	}

	strcopy(dest,g_RealmVillageNames[village],size);
	return true;
}

stock Realm_FindPolicy(const key[])
{
	for (new policy = 0;policy < REALM_POLICY_COUNT;policy++)
	{
		if (!strcmp(g_RealmPolicyDefs[policy][E_RP_KEY],key,true))
		{
			return policy;
		}
	}

	return -1;
}

stock Realm_GetPolicy(county,policy)
{
	#pragma unused county

	if (policy < 0 || policy >= REALM_POLICY_COUNT)
	{
		return 0;
	}

	return s_RealmLoaded ? s_RealmPolicy[policy] : g_RealmPolicyDefs[policy][E_RP_DEFAULT];
}

stock Realm_GetBound(policy,bool:upper)
{
	if (policy < 0 || policy >= REALM_POLICY_COUNT)
	{
		return 0;
	}

	return s_RealmBounds[policy][upper ? 1 : 0];
}

stock Realm_SetPolicy(county,policy,value,byCharacter)
{
	if (policy < 0 || policy >= REALM_POLICY_COUNT)
	{
		return 0;
	}

	new clamped = Util_ClampInt(value,s_RealmBounds[policy][0],s_RealmBounds[policy][1]), old = s_RealmPolicy[policy];
	s_RealmPolicy[policy] = clamped;
	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO county_policy (county_id, policy_key, value, set_by, set_at) VALUES (%d, '%e', %d, %d, %d)",county,g_RealmPolicyDefs[policy][E_RP_KEY],clamped,byCharacter,gettime()));

	if (clamped != old)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO realm_log (at, actor_character_id, what) VALUES (%d, %d, '%e')",gettime(),byCharacter,sprintf("%s: %d to %d",g_RealmPolicyDefs[policy][E_RP_KEY],old,clamped)));
		pawn_call_public("Realm_OnPolicyChanged","dddd",county,policy,old,clamped);
	}

	return clamped;
}

stock Realm_SetBound(policy,minValue,maxValue,byCharacter)
{
	if (policy < 0 || policy >= REALM_POLICY_COUNT || minValue > maxValue)
	{
		return;
	}

	s_RealmBounds[policy][0] = minValue;
	s_RealmBounds[policy][1] = maxValue;
	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO duchy_bounds (policy_key, min_value, max_value) VALUES ('%e', %d, %d)",g_RealmPolicyDefs[policy][E_RP_KEY],minValue,maxValue));
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO realm_log (at, actor_character_id, what) VALUES (%d, %d, '%e')",gettime(),byCharacter,sprintf("bounds %s: %d to %d",g_RealmPolicyDefs[policy][E_RP_KEY],minValue,maxValue)));

	if (s_RealmPolicy[policy] < minValue || s_RealmPolicy[policy] > maxValue)
	{
		Realm_SetPolicy(REALM_COUNTY,policy,s_RealmPolicy[policy],byCharacter);
	}
}

stock Realm_GetCountyAt(Float:x,Float:y)
{
	#pragma unused x, y
	return REALM_COUNTY;
}

stock Realm_VillageAt(Float:x,Float:y)
{
	new best = 0, Float:bestDistance = 100000.0;

	for (new village = 0;village < REALM_VILLAGES;village++)
	{
		new Float:d = VectorSize(x - g_RealmVillagePos[village][0],y - g_RealmVillagePos[village][1],0.0);

		if (d < bestDistance)
		{
			best = village;
			bestDistance = d;
		}
	}

	return best;
}

stock bool:Realm_InTown(Float:x,Float:y,Float:range = 90.0)
{
	new village = Realm_VillageAt(x,y);
	return VectorSize(x - g_RealmVillagePos[village][0],y - g_RealmVillagePos[village][1],0.0) <= range;
}

stock bool:Realm_PathEntersTown(Float:fromX,Float:fromY,Float:toX,Float:toY,Float:range = 90.0)
{
    new Float:dx = toX - fromX, Float:dy = toY - fromY, Float:lengthSquared = dx * dx + dy * dy;

    for (new village = 0; village < REALM_VILLAGES; village++)
    {
        new Float:along = 0.0;

        if (lengthSquared > 0.0)
        {
            along = ((g_RealmVillagePos[village][0] - fromX) * dx + (g_RealmVillagePos[village][1] - fromY) * dy) / lengthSquared;
            if (along < 0.0)
            {
                along = 0.0;
            }
            else if (along > 1.0)
            {
                along = 1.0;
            }
        }

        if (VectorSize(fromX + along * dx - g_RealmVillagePos[village][0],fromY + along * dy - g_RealmVillagePos[village][1],0.0) <= range)
        {
            return true;
        }
    }

    return false;
}

stock Realm_GetCount()
{
	return s_RealmCount;
}

stock Realm_GetDuke()
{
	return s_RealmDuke;
}

stock Realm_GetRegent()
{
	return s_RealmRegent;
}

stock Realm_GetTreasury()
{
	return s_RealmTreasury;
}

stock Realm_GetDuchyTreasury()
{
	return s_RealmDuchyTreasury;
}

stock bool:Realm_IsVacant()
{
	if (s_RealmRegent > 0)
	{
		return false;
	}

	return s_RealmCount <= 0 || gettime() - s_RealmCountSeen > REALM_VACANT_DAYS * 86400;
}

stock Realm_GetRuler()
{
	if (s_RealmRegent > 0)
	{
		return s_RealmRegent;
	}

	return Realm_IsVacant() ? s_RealmDuke : s_RealmCount;
}

stock bool:Realm_IsRuler(playerid)
{
	new characterid = Character_GetId(playerid);
	return characterid > 0 && (characterid == Realm_GetRuler() || characterid == s_RealmDuke);
}

stock bool:Realm_IsDuke(playerid)
{
	return Character_GetId(playerid) > 0 && Character_GetId(playerid) == s_RealmDuke;
}

stock Realm_SetOffice(office,characterid)
{
	switch (office)
	{
		case 0:
		{
			s_RealmDuke = characterid;
			mysql_tquery_s(g_Mysql,str_format("UPDATE duchy SET duke_character_id = NULLIF(%d, 0) WHERE id = 1",characterid));
		}
		case 1:
		{
			new wasVacant = Realm_IsVacant();
			s_RealmCount = characterid;
			s_RealmCountSeen = gettime();
			mysql_tquery_s(g_Mysql,str_format("UPDATE counties SET count_character_id = NULLIF(%d, 0), count_seen_at = %d WHERE id = %d",characterid,s_RealmCountSeen,REALM_COUNTY));

			if (wasVacant != _:Realm_IsVacant())
			{
				pawn_call_public("Realm_OnVacancy","dd",REALM_COUNTY,Realm_IsVacant() ? 1 : 0);
			}
		}
		case 2:
		{
			s_RealmRegent = characterid;
			mysql_tquery_s(g_Mysql,str_format("UPDATE counties SET regent_character_id = NULLIF(%d, 0) WHERE id = %d",characterid,REALM_COUNTY));
		}
	}
}

stock Realm_GetDues(village)
{
	return village >= 0 && village < REALM_VILLAGES ? s_RealmDues[village] : 0;
}

stock Realm_GetDuesTotal()
{
	new total = 0;

	for (new village = 0;village < REALM_VILLAGES;village++)
	{
		total += s_RealmDues[village];
	}

	return total;
}

stock Realm_AddDues(county,village,coin)
{
	if (village < 0 || village >= REALM_VILLAGES || coin == 0)
	{
		return;
	}

	s_RealmDues[village] = max(s_RealmDues[village] + coin,0);
	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO dues_owed (county_id, village_key, coin, updated_at) VALUES (%d, '%e', %d, %d)",county,g_RealmVillageKeys[village],s_RealmDues[village],gettime()));
}

stock Realm_TakeDues(village)
{
	new coin = Realm_GetDues(village);

	if (coin > 0)
	{
		Realm_AddDues(REALM_COUNTY,village,-coin);
	}

	return coin;
}

stock bool:Realm_IsDecreeActive(kind)
{
	new now = gettime();

	for (new i = 0;i < REALM_DECREES_MAX;i++)
	{
		if (s_RealmDecrees[i][E_RD_USED] && s_RealmDecrees[i][E_RD_KIND] == kind && now >= s_RealmDecrees[i][E_RD_STARTS] && now < s_RealmDecrees[i][E_RD_ENDS])
		{
			return true;
		}
	}

	return false;
}

stock Realm_CountDecrees()
{
	new count = 0, now = gettime();

	for (new i = 0;i < REALM_DECREES_MAX;i++)
	{
		if (s_RealmDecrees[i][E_RD_USED] && now < s_RealmDecrees[i][E_RD_ENDS])
		{
			count++;
		}
	}

	return count;
}

stock Realm_GetDecree(index,&kind,text[],&starts,&ends,size = sizeof(text))
{
	if (index < 0 || index >= REALM_DECREES_MAX || !s_RealmDecrees[index][E_RD_USED])
	{
		return 0;
	}

	kind = s_RealmDecrees[index][E_RD_KIND];
	starts = s_RealmDecrees[index][E_RD_STARTS];
	ends = s_RealmDecrees[index][E_RD_ENDS];
	strcopy(text,s_RealmDecrees[index][E_RD_TEXT],size);
	return s_RealmDecrees[index][E_RD_ROW];
}

forward Task:Realm_IssueDecree(kind,const text[],starts,ends,byCharacter);
#pragma warning push
#pragma warning disable 204
async Task:Realm_IssueDecree(kind,const text[],starts,ends,byCharacter)
{
	new slot = -1, now = gettime();

	for (new i = 0;i < REALM_DECREES_MAX;i++)
	{
		if (!s_RealmDecrees[i][E_RD_USED] || now >= s_RealmDecrees[i][E_RD_ENDS])
		{
			slot = i;
			break;
		}
	}

	if (slot == -1 || kind < 0 || kind >= REALM_DECREE_KINDS || ends <= starts)
	{
		wait_ticks(1);
		return async -1;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO decrees (kind, text, params, starts_at, ends_at, issued_by) VALUES (%d, '%e', '', %d, %d, %d)",kind,text,starts,ends,byCharacter));
	s_RealmDecrees[slot][E_RD_USED] = true;
	s_RealmDecrees[slot][E_RD_ROW] = cache_insert_id();
	s_RealmDecrees[slot][E_RD_KIND] = kind;
	s_RealmDecrees[slot][E_RD_STARTS] = starts;
	s_RealmDecrees[slot][E_RD_ENDS] = ends;
	s_RealmDecrees[slot][E_RD_BY] = byCharacter;
	strcopy(s_RealmDecrees[slot][E_RD_TEXT],text,REALM_DECREE_TEXT);
	pawn_call_public("Realm_OnDecree","dds",s_RealmDecrees[slot][E_RD_ROW],kind,text);
	return async s_RealmDecrees[slot][E_RD_ROW];
}
#pragma warning pop

stock bool:Realm_CancelDecree(row)
{
	for (new i = 0;i < REALM_DECREES_MAX;i++)
	{
		if (s_RealmDecrees[i][E_RD_USED] && s_RealmDecrees[i][E_RD_ROW] == row)
		{
			s_RealmDecrees[i][E_RD_ENDS] = gettime();
			mysql_tquery_s(g_Mysql,str_format("UPDATE decrees SET ends_at = %d WHERE id = %d",gettime(),row));
			return true;
		}
	}

	return false;
}

forward Task:Realm_Load();
#pragma warning push
#pragma warning disable 204
async Task:Realm_Load()
{
	for (new policy = 0;policy < REALM_POLICY_COUNT;policy++)
	{
		s_RealmPolicy[policy] = g_RealmPolicyDefs[policy][E_RP_DEFAULT];
		s_RealmBounds[policy][0] = g_RealmPolicyDefs[policy][E_RP_MIN];
		s_RealmBounds[policy][1] = g_RealmPolicyDefs[policy][E_RP_MAX];
	}

	await mysql_aquery_s(g_Mysql,str_new("INSERT IGNORE INTO duchy (id) VALUES (1)"));
	await mysql_aquery_s(g_Mysql,str_format("INSERT IGNORE INTO counties (id, name) VALUES (%d, 'Talmberg')",REALM_COUNTY));
	await mysql_aquery_s(g_Mysql,str_new("SELECT COALESCE(duke_character_id, 0) AS duke, COALESCE(treasury_container_id, 0) AS treasury FROM duchy WHERE id = 1"));
	cache_get_value_name_int(0,"duke",s_RealmDuke);
	new duchyTreasury;
	cache_get_value_name_int(0,"treasury",duchyTreasury);
	await mysql_aquery_s(g_Mysql,str_format("SELECT COALESCE(count_character_id, 0) AS c, COALESCE(regent_character_id, 0) AS r, COALESCE(treasury_container_id, 0) AS t, count_seen_at FROM counties WHERE id = %d",REALM_COUNTY));
	new treasury;
	cache_get_value_name_int(0,"c",s_RealmCount);
	cache_get_value_name_int(0,"r",s_RealmRegent);
	cache_get_value_name_int(0,"t",treasury);
	cache_get_value_name_int(0,"count_seen_at",s_RealmCountSeen);
	await mysql_aquery_s(g_Mysql,str_new("SELECT policy_key, min_value, max_value FROM duchy_bounds"));

	for (new r = 0;r < cache_num_rows();r++)
	{
		new key[REALM_KEY_LEN], lo, hi;
		cache_get_value_name(r,"policy_key",key);
		cache_get_value_name_int(r,"min_value",lo);
		cache_get_value_name_int(r,"max_value",hi);
		new policy = Realm_FindPolicy(key);

		if (policy != -1)
		{
			s_RealmBounds[policy][0] = lo;
			s_RealmBounds[policy][1] = hi;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT policy_key, value FROM county_policy WHERE county_id = %d",REALM_COUNTY));

	for (new r = 0;r < cache_num_rows();r++)
	{
		new key[REALM_KEY_LEN], value;
		cache_get_value_name(r,"policy_key",key);
		cache_get_value_name_int(r,"value",value);
		new policy = Realm_FindPolicy(key);

		if (policy != -1)
		{
			s_RealmPolicy[policy] = Util_ClampInt(value,s_RealmBounds[policy][0],s_RealmBounds[policy][1]);
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT village_key, coin FROM dues_owed WHERE county_id = %d",REALM_COUNTY));

	for (new r = 0;r < cache_num_rows();r++)
	{
		new key[16], coin;
		cache_get_value_name(r,"village_key",key);
		cache_get_value_name_int(r,"coin",coin);

		for (new village = 0;village < REALM_VILLAGES;village++)
		{
			if (!strcmp(key,g_RealmVillageKeys[village]))
			{
				s_RealmDues[village] = coin;
			}
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, text, starts_at, ends_at, issued_by FROM decrees WHERE ends_at > %d ORDER BY starts_at LIMIT %d",gettime(),REALM_DECREES_MAX));

	for (new r = 0;r < cache_num_rows();r++)
	{
		cache_get_value_name_int(r,"id",s_RealmDecrees[r][E_RD_ROW]);
		cache_get_value_name_int(r,"kind",s_RealmDecrees[r][E_RD_KIND]);
		cache_get_value_name(r,"text",s_RealmDecrees[r][E_RD_TEXT],REALM_DECREE_TEXT);
		cache_get_value_name_int(r,"starts_at",s_RealmDecrees[r][E_RD_STARTS]);
		cache_get_value_name_int(r,"ends_at",s_RealmDecrees[r][E_RD_ENDS]);
		cache_get_value_name_int(r,"issued_by",s_RealmDecrees[r][E_RD_BY]);
		s_RealmDecrees[r][E_RD_USED] = true;
	}

	if (treasury <= 0)
	{
		treasury = await Container_Create(CONTAINER_OWNER_TREASURY,REALM_COUNTY,30,"The county treasury");
		mysql_tquery_s(g_Mysql,str_format("UPDATE counties SET treasury_container_id = %d WHERE id = %d",treasury,REALM_COUNTY));
	}
	else
	{
		await Container_Load(treasury);
	}

	if (duchyTreasury <= 0)
	{
		duchyTreasury = await Container_Create(CONTAINER_OWNER_TREASURY,0,30,"The duchy treasury");
		mysql_tquery_s(g_Mysql,str_format("UPDATE duchy SET treasury_container_id = %d WHERE id = 1",duchyTreasury));
	}
	else
	{
		await Container_Load(duchyTreasury);
	}

	s_RealmTreasury = treasury;
	s_RealmDuchyTreasury = duchyTreasury;
	s_RealmLoaded = true;
	return async 1;
}
#pragma warning pop

forward Realm_OnPolicyChanged(county,policy,oldValue,newValue);

public Realm_OnPolicyChanged(county,policy,oldValue,newValue)
{
	return 1;
}

forward Realm_OnDecree(row,kind,const text[]);

public Realm_OnDecree(row,kind,const text[])
{
	return 1;
}

forward Realm_OnVacancy(county,vacant);

public Realm_OnVacancy(county,vacant)
{
	return 1;
}

#include <pp-hooks>

hook Character_OnLoaded(playerid,characterid)
{
	if (characterid > 0 && characterid == s_RealmCount)
	{
		new wasVacant = Realm_IsVacant();
		s_RealmCountSeen = gettime();
		mysql_tquery_s(g_Mysql,str_format("UPDATE counties SET count_seen_at = %d WHERE id = %d",s_RealmCountSeen,REALM_COUNTY));

		if (wasVacant)
		{
			pawn_call_public("Realm_OnVacancy","dd",REALM_COUNTY,0);
		}
	}
}
