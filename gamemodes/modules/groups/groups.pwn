enum E_GROUP
{
	bool:E_GROUP_USED,
	E_GROUP_ID,
	E_GROUP_KIND,
	E_GROUP_NAME[GROUPS_NAME_LEN],
	E_GROUP_FOUNDER,
	E_GROUP_LIVERY,
	E_GROUP_FEATURES,
	E_GROUP_TREASURY,
	E_GROUP_STORE,
	bool:E_GROUP_CHARTERED,
	bool:E_GROUP_REVIEWED,
	E_GROUP_TRADE,
	E_GROUP_MIN_STARS,
	E_GROUP_FLOOR,
	E_GROUP_CEILING,
	bool:E_GROUP_HAS_HALL,
	Float:E_GROUP_HALL[4],
	E_GROUP_HALL_WORLD,
	E_GROUP_HALL_INTERIOR,
	E_GROUP_HIDEOUT,
	E_GROUP_MEMBERS,
	E_GROUP_CREATED,
	STREAMER_TAG_3D_TEXT_LABEL:E_GROUP_LABEL,
}

static s_Groups[GROUPS_MAX][E_GROUP];
static STREAMER_TAG_OBJECT:s_GroupsHideoutFires[GROUPS_SEED_HIDEOUTS];
static s_GroupRoll[GROUPS_MAX][GROUPS_ROLL_MAX];
static s_GroupRankNames[GROUPS_MAX][GROUPS_RANKS][GROUPS_RANK_NAME_LEN];
static s_GroupRankPerms[GROUPS_MAX][GROUPS_RANKS];
static s_Member[MAX_PLAYERS][GROUPS_PER_CHARACTER][3];
static bool:s_MembersLoaded[MAX_PLAYERS];
static s_ChatGroup[MAX_PLAYERS] = {GROUP_INVALID, ...};
static bool:s_GroupsLoaded;

forward Task:Groups_Create(kind,const name[],founder,trade);
forward Task:Groups_Load();
forward Task:Groups_LoadMember(playerid,characterid);
forward Task:Groups_AddMember(group,characterid,rank);

stock bool:Groups_IsLoaded()
{
	return s_GroupsLoaded;
}

stock bool:Groups_IsValid(group)
{
	return group >= 0 && group < GROUPS_MAX && s_Groups[group][E_GROUP_USED];
}

stock Groups_GetId(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_ID] : 0;
}

stock Groups_FindById(id)
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && s_Groups[group][E_GROUP_ID] == id)
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

stock Groups_FindByName(const name[])
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && !strcmp(s_Groups[group][E_GROUP_NAME],name,true))
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

stock Groups_FindKind(kind)
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && s_Groups[group][E_GROUP_KIND] == kind)
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

stock Groups_FindGuild(trade)
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && s_Groups[group][E_GROUP_KIND] == GROUP_KIND_GUILD && s_Groups[group][E_GROUP_TRADE] == trade && s_Groups[group][E_GROUP_CHARTERED])
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

stock Groups_Count()
{
	new count = 0;

	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED])
		{
			count++;
		}
	}

	return count;
}

stock Groups_GetKind(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_KIND] : -1;
}

stock Groups_GetName(group,dest[],size = sizeof(dest))
{
	if (!Groups_IsValid(group))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Groups[group][E_GROUP_NAME],size);
}

stock bool:Groups_IsSystem(group)
{
	return Groups_IsValid(group) && (s_Groups[group][E_GROUP_KIND] == GROUP_KIND_GUARD || s_Groups[group][E_GROUP_KIND] == GROUP_KIND_CHURCH);
}

stock Groups_GetFeatures(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_FEATURES] : 0;
}

stock bool:Groups_HasFeature(group,feature)
{
	return Groups_IsValid(group) && (s_Groups[group][E_GROUP_FEATURES] & feature) != 0;
}

stock Groups_SetFeature(group,feature,bool:isOn)
{
	if (!Groups_IsValid(group))
	{
		return;
	}

	if (isOn)
	{
		s_Groups[group][E_GROUP_FEATURES] |= feature;
	}
	else
	{
		s_Groups[group][E_GROUP_FEATURES] &= ~feature;
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET features = %d WHERE id = %d",s_Groups[group][E_GROUP_FEATURES],s_Groups[group][E_GROUP_ID]));
	pawn_call_public("Groups_OnFeatures","d",group);
}

stock Groups_GetLivery(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_LIVERY] : 0;
}

stock Groups_SetLivery(group,livery)
{
	if (!Groups_IsValid(group) || livery < 0 || livery >= GROUPS_LIVERY_COUNT)
	{
		return;
	}

	s_Groups[group][E_GROUP_LIVERY] = livery;
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET livery = %d WHERE id = %d",livery,s_Groups[group][E_GROUP_ID]));
	pawn_call_public("Groups_OnFeatures","d",group);
}

stock Groups_GetTreasury(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_TREASURY] : INVALID_CONTAINER_ID;
}

stock Groups_GetStore(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_STORE] : INVALID_CONTAINER_ID;
}

stock bool:Groups_IsChartered(group)
{
	return Groups_IsValid(group) && s_Groups[group][E_GROUP_CHARTERED];
}

stock Groups_SetChartered(group,bool:isChartered)
{
	if (!Groups_IsValid(group))
	{
		return;
	}

	s_Groups[group][E_GROUP_CHARTERED] = isChartered;
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET chartered = %d WHERE id = %d",_:isChartered,s_Groups[group][E_GROUP_ID]));
	pawn_call_public("Groups_OnFeatures","d",group);
}

stock bool:Groups_IsReviewed(group)
{
	return Groups_IsValid(group) && s_Groups[group][E_GROUP_REVIEWED];
}

stock Groups_SetReviewed(group,bool:isReviewed)
{
	if (!Groups_IsValid(group))
	{
		return;
	}

	s_Groups[group][E_GROUP_REVIEWED] = isReviewed;
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET reviewed = %d WHERE id = %d",_:isReviewed,s_Groups[group][E_GROUP_ID]));
}

stock Groups_GetTrade(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_TRADE] : -1;
}

stock Groups_GetRules(group,&minStars,&floorPercent,&ceilingPercent)
{
	minStars = Groups_IsValid(group) ? s_Groups[group][E_GROUP_MIN_STARS] : ITEM_STARS_MAX;
	floorPercent = Groups_IsValid(group) ? s_Groups[group][E_GROUP_FLOOR] : 0;
	ceilingPercent = Groups_IsValid(group) ? s_Groups[group][E_GROUP_CEILING] : 0;
}

stock Groups_SetRules(group,minStars,floorPercent,ceilingPercent)
{
	if (!Groups_IsValid(group))
	{
		return;
	}

	s_Groups[group][E_GROUP_MIN_STARS] = Util_ClampInt(minStars,ITEM_STARS_MIN,ITEM_STARS_MAX);
	s_Groups[group][E_GROUP_FLOOR] = Util_ClampInt(floorPercent,50,100);
	s_Groups[group][E_GROUP_CEILING] = Util_ClampInt(ceilingPercent,100,200);
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET min_stars = %d, price_floor = %d, price_ceiling = %d WHERE id = %d",s_Groups[group][E_GROUP_MIN_STARS],s_Groups[group][E_GROUP_FLOOR],s_Groups[group][E_GROUP_CEILING],s_Groups[group][E_GROUP_ID]));
	pawn_call_public("Groups_OnFeatures","d",group);
}

stock Groups_GetMemberCount(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_MEMBERS] : 0;
}

stock Groups_GetCap(group)
{
	if (!Groups_IsValid(group))
	{
		return 0;
	}

	if (!s_Groups[group][E_GROUP_REVIEWED])
	{
		return GROUPS_REVIEW_MEMBERS;
	}

	return s_Groups[group][E_GROUP_KIND] == GROUP_KIND_GUILD ? GROUPS_GUILD_CAP : GROUPS_CAP;
}

stock Groups_GetRankName(group,rank,dest[],size = sizeof(dest))
{
	if (!Groups_IsValid(group) || rank < 0 || rank >= GROUPS_RANKS)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_GroupRankNames[group][rank],size);
}

stock Groups_SetRankName(group,rank,const name[])
{
	if (!Groups_IsValid(group) || rank < 0 || rank >= GROUPS_RANKS)
	{
		return;
	}

	strcopy(s_GroupRankNames[group][rank],name,GROUPS_RANK_NAME_LEN);
	Groups_SaveRank(group,rank);
}

stock Groups_GetRankPerms(group,rank)
{
	if (!Groups_IsValid(group) || rank < 0 || rank >= GROUPS_RANKS)
	{
		return 0;
	}

	return rank == 0 ? GROUP_PERM_ALL : s_GroupRankPerms[group][rank];
}

stock Groups_SetRankPerms(group,rank,perms)
{
	if (!Groups_IsValid(group) || rank <= 0 || rank >= GROUPS_RANKS)
	{
		return;
	}

	s_GroupRankPerms[group][rank] = perms & GROUP_PERM_ALL;
	Groups_SaveRank(group,rank);
}

stock Groups_CountRanks(group)
{
	new count = 0;

	for (new rank = 0;Groups_IsValid(group) && rank < GROUPS_RANKS;rank++)
	{
		if (s_GroupRankNames[group][rank][0] != EOS)
		{
			count = rank + 1;
		}
	}

	return max(count,2);
}

static Groups_SaveRank(group,rank)
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO group_ranks (group_id, `rank`, name, perms) VALUES (%d, %d, '%e', %d) ON DUPLICATE KEY UPDATE name = VALUES(name), perms = VALUES(perms)",s_Groups[group][E_GROUP_ID],rank,s_GroupRankNames[group][rank],s_GroupRankPerms[group][rank]));
}

stock Groups_GetRank(playerid,group)
{
	if (!Util_IsValidPlayer(playerid) || !Groups_IsValid(group))
	{
		return -1;
	}

	switch (s_Groups[group][E_GROUP_KIND])
	{
		case GROUP_KIND_GUARD:
		{
			new rank = Law_GetRank(playerid);
			return rank <= LAW_RANK_NONE ? -1 : LAW_RANK_SERGEANT - rank;
		}
		case GROUP_KIND_CHURCH:
		{
			switch (Clergy_GetRank(playerid))
			{
				case CLERGY_ABBOT: return 0;
				case CLERGY_PRIOR: return 1;
				case CLERGY_PRIEST: return 2;
				case CLERGY_DEACON: return 3;
				case CLERGY_BROTHER: return 4;
				case CLERGY_LAY, CLERGY_NOVICE: return 5;
				default: return -1;
			}
		}
	}

	for (new i = 0;i < GROUPS_PER_CHARACTER;i++)
	{
		if (s_Member[playerid][i][0] == group)
		{
			return s_Member[playerid][i][1];
		}
	}

	return -1;
}

stock bool:Groups_IsMember(playerid,group)
{
	return Groups_GetRank(playerid,group) != -1;
}

stock bool:Groups_HasPerm(playerid,group,perm)
{
	new rank = Groups_GetRank(playerid,group);
	return rank != -1 && (Groups_GetRankPerms(group,rank) & perm) != 0;
}

stock bool:Groups_IsHead(playerid,group)
{
	return Groups_GetRank(playerid,group) == 0;
}

stock Groups_GetMine(playerid,list[],size = sizeof(list))
{
	new count = 0;

	for (new group = 0;group < GROUPS_MAX && count < size;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && Groups_IsMember(playerid,group))
		{
			list[count++] = group;
		}
	}

	return count;
}

stock Groups_CountRolled(playerid)
{
	new count = 0;

	for (new i = 0;Util_IsValidPlayer(playerid) && i < GROUPS_PER_CHARACTER;i++)
	{
		if (s_Member[playerid][i][0] != GROUP_INVALID)
		{
			count++;
		}
	}

	return count;
}

stock Groups_FindMineOfKind(playerid,kind)
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && s_Groups[group][E_GROUP_KIND] == kind && Groups_IsMember(playerid,group))
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

stock bool:Groups_WantsHallSpawn(playerid,group)
{
	for (new i = 0;Util_IsValidPlayer(playerid) && i < GROUPS_PER_CHARACTER;i++)
	{
		if (s_Member[playerid][i][0] == group)
		{
			return s_Member[playerid][i][2] != 0;
		}
	}

	return false;
}

stock Groups_SetHallSpawn(playerid,group,bool:isOn)
{
	for (new i = 0;Util_IsValidPlayer(playerid) && i < GROUPS_PER_CHARACTER;i++)
	{
		if (s_Member[playerid][i][0] == group)
		{
			for (new other = 0;other < GROUPS_PER_CHARACTER;other++)
			{
				if (isOn && other != i && s_Member[playerid][other][2] != 0)
				{
					s_Member[playerid][other][2] = 0;
					mysql_tquery_s(g_Mysql,str_format("UPDATE group_members SET spawn_hall = 0 WHERE group_id = %d AND character_id = %d",Groups_GetId(s_Member[playerid][other][0]),Character_GetId(playerid)));
				}
			}

			s_Member[playerid][i][2] = _:isOn;
			mysql_tquery_s(g_Mysql,str_format("UPDATE group_members SET spawn_hall = %d WHERE group_id = %d AND character_id = %d",_:isOn,Groups_GetId(group),Character_GetId(playerid)));
			return;
		}
	}
}

stock Groups_GetChatGroup(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return GROUP_INVALID;
	}

	if (Groups_IsMember(playerid,s_ChatGroup[playerid]))
	{
		return s_ChatGroup[playerid];
	}

	new list[GROUPS_PER_CHARACTER + 2];
	return Groups_GetMine(playerid,list) > 0 ? list[0] : GROUP_INVALID;
}

stock Groups_SetChatGroup(playerid,group)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_ChatGroup[playerid] = group;
	}
}

stock Groups_PlayerByCharacter(characterid)
{
	if (characterid <= 0)
	{
		return INVALID_PLAYER_ID;
	}

	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == characterid && Session_IsPlaying(playerid))
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Groups_Log(group,characterid,const text[])
{
	if (Groups_IsValid(group))
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO group_log (group_id, character_id, what, at) VALUES (%d, %d, '%e', %d)",s_Groups[group][E_GROUP_ID],characterid,text,gettime()));
	}
}

stock Groups_Tell(group,const text[],except = INVALID_PLAYER_ID)
{
	foreach (new playerid : Player)
	{
		if (playerid != except && Session_IsPlaying(playerid) && Groups_IsMember(playerid,group))
		{
			Gui_Notify(playerid,text);
		}
	}
}

stock Groups_TreasuryWorth(group)
{
	new treasury = Groups_GetTreasury(group), coin = 0;

	if (treasury == INVALID_CONTAINER_ID || !Container_IsLoaded(treasury))
	{
		return 0;
	}

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		coin += Container_Count(treasury,ITEM_KIND_COIN,tier) * Item_CoinWorth(tier);
	}

	return coin;
}

stock bool:Groups_PayOut(group,playerid,amount,const source[])
{
	new treasury = Groups_GetTreasury(group), take[COIN_TIER_COUNT], left = amount;

	if (amount <= 0 || treasury == INVALID_CONTAINER_ID || Groups_TreasuryWorth(group) < amount || !Util_IsValidPlayer(playerid))
	{
		return false;
	}

	for (new tier = COIN_TIER_COUNT - 1;tier >= COIN_PFENNIG;tier--)
	{
		take[tier] = min(left / Item_CoinWorth(tier),Container_Count(treasury,ITEM_KIND_COIN,tier));
		left -= take[tier] * Item_CoinWorth(tier);
	}

	if (left != 0)
	{
		return false;
	}

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (take[tier] > 0)
		{
			Container_TakeStars(treasury,ITEM_KIND_COIN,tier,take[tier],ITEM_STARS_MIN);
		}
	}

	if (!Economy_Give(playerid,amount,source))
	{
		for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
		{
			if (take[tier] > 0)
			{
				Container_Add(treasury,ITEM_KIND_COIN,tier,take[tier]);
			}
		}

		return false;
	}

	return true;
}

stock bool:Groups_GetSeat(group,&Float:x,&Float:y,&Float:z,&world = 0)
{
	world = 0;

	if (!Groups_IsValid(group))
	{
		return false;
	}

	if (s_Groups[group][E_GROUP_HAS_HALL])
	{
		x = s_Groups[group][E_GROUP_HALL][0];
		y = s_Groups[group][E_GROUP_HALL][1];
		z = s_Groups[group][E_GROUP_HALL][2];
		world = s_Groups[group][E_GROUP_HALL_WORLD];
		return true;
	}

	new hideout = s_Groups[group][E_GROUP_HIDEOUT];

	if (s_Groups[group][E_GROUP_KIND] == GROUP_KIND_OUTLAW && hideout >= 0 && hideout < GROUPS_SEED_HIDEOUTS)
	{
		x = g_GroupsHideouts[hideout][0];
		y = g_GroupsHideouts[hideout][1];
		z = g_GroupsHideouts[hideout][2];
		return true;
	}

	if (s_Groups[group][E_GROUP_KIND] == GROUP_KIND_ORDER || s_Groups[group][E_GROUP_KIND] == GROUP_KIND_CHURCH)
	{
		x = g_GroupsChurchDoor[0];
		y = g_GroupsChurchDoor[1];
		z = g_GroupsChurchDoor[2];
		return true;
	}

	return Actors_GetPos(Realm_GetSteward(),x,y,z);
}

stock bool:Groups_IsAtSeat(playerid,group)
{
	new Float:x, Float:y, Float:z, world;

	if (!Groups_GetSeat(group,x,y,z,world))
	{
		return false;
	}

	return GetPlayerVirtualWorld(playerid) == world && IsPlayerInRangeOfPoint(playerid,s_Groups[group][E_GROUP_HAS_HALL] ? GROUPS_HALL_REACH + 1.5 : GROUPS_SEAT_REACH,x,y,z);
}

stock bool:Groups_HasHall(group)
{
	return Groups_IsValid(group) && s_Groups[group][E_GROUP_HAS_HALL];
}

stock bool:Groups_GetHall(group,&Float:x,&Float:y,&Float:z,&Float:a,&world,&interior)
{
	if (!Groups_HasHall(group))
	{
		return false;
	}

	x = s_Groups[group][E_GROUP_HALL][0];
	y = s_Groups[group][E_GROUP_HALL][1];
	z = s_Groups[group][E_GROUP_HALL][2];
	a = s_Groups[group][E_GROUP_HALL][3];
	world = s_Groups[group][E_GROUP_HALL_WORLD];
	interior = s_Groups[group][E_GROUP_HALL_INTERIOR];
	return true;
}

stock Groups_SetHall(group,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	if (!Groups_IsValid(group))
	{
		return;
	}

	s_Groups[group][E_GROUP_HAS_HALL] = true;
	s_Groups[group][E_GROUP_HALL][0] = x;
	s_Groups[group][E_GROUP_HALL][1] = y;
	s_Groups[group][E_GROUP_HALL][2] = z;
	s_Groups[group][E_GROUP_HALL][3] = a;
	s_Groups[group][E_GROUP_HALL_WORLD] = world;
	s_Groups[group][E_GROUP_HALL_INTERIOR] = interior;
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET hall_x = %f, hall_y = %f, hall_z = %f, hall_a = %f, hall_world = %d, hall_interior = %d WHERE id = %d",x,y,z,a,world,interior,s_Groups[group][E_GROUP_ID]));
	Groups_PlaceLabel(group);
}

stock Groups_GetHideout(group)
{
	return Groups_IsValid(group) ? s_Groups[group][E_GROUP_HIDEOUT] : -1;
}

stock Groups_HideoutHolder(hideout)
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (s_Groups[group][E_GROUP_USED] && s_Groups[group][E_GROUP_KIND] == GROUP_KIND_OUTLAW && s_Groups[group][E_GROUP_HIDEOUT] == hideout)
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

stock Groups_PlaceLabel(group)
{
	if (IsValidDynamic3DTextLabel(s_Groups[group][E_GROUP_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Groups[group][E_GROUP_LABEL]);
	}

	s_Groups[group][E_GROUP_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

	if (!s_Groups[group][E_GROUP_HAS_HALL] || !Groups_HasFeature(group,GROUP_FEATURE_HALL))
	{
		return;
	}

	new text[64];
	format(text,sizeof(text),"The hall of %s",s_Groups[group][E_GROUP_NAME]);
	s_Groups[group][E_GROUP_LABEL] = CreateDynamic3DTextLabel(text,0xD8CCB2FF,s_Groups[group][E_GROUP_HALL][0],s_Groups[group][E_GROUP_HALL][1],s_Groups[group][E_GROUP_HALL][2] + 0.6,10.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,s_Groups[group][E_GROUP_HALL_WORLD],s_Groups[group][E_GROUP_HALL_INTERIOR]);
}

stock Groups_RefreshPlayer(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	new list[GROUPS_PER_CHARACTER + 2], count = Groups_GetMine(playerid,list), text[CHARPANEL_GROUPS_LEN];

	for (new i = 0;i < count;i++)
	{
		if (text[0] != EOS)
		{
			strcat(text,", ");
		}

		strcat(text,s_Groups[list[i]][E_GROUP_NAME]);
	}

	CharPanel_SetGroups(playerid,text);
	pawn_call_public("Groups_OnRefreshed","d",playerid);
}

static Groups_Slot()
{
	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (!s_Groups[group][E_GROUP_USED])
		{
			return group;
		}
	}

	return GROUP_INVALID;
}

static Groups_Store(group,id,kind,const name[],founder,livery,features,treasury,store,bool:chartered,bool:reviewed,trade,minStars,floorPercent,ceilingPercent,hideout,created)
{
	s_Groups[group][E_GROUP_USED] = true;
	s_Groups[group][E_GROUP_ID] = id;
	s_Groups[group][E_GROUP_KIND] = Util_ClampInt(kind,0,GROUP_KIND_COUNT - 1);
	strcopy(s_Groups[group][E_GROUP_NAME],name,GROUPS_NAME_LEN);
	s_Groups[group][E_GROUP_FOUNDER] = founder;
	s_Groups[group][E_GROUP_LIVERY] = Util_ClampInt(livery,0,GROUPS_LIVERY_COUNT - 1);
	s_Groups[group][E_GROUP_FEATURES] = features;
	s_Groups[group][E_GROUP_TREASURY] = treasury;
	s_Groups[group][E_GROUP_STORE] = store;
	s_Groups[group][E_GROUP_CHARTERED] = chartered;
	s_Groups[group][E_GROUP_REVIEWED] = reviewed;
	s_Groups[group][E_GROUP_TRADE] = trade;
	s_Groups[group][E_GROUP_MIN_STARS] = minStars;
	s_Groups[group][E_GROUP_FLOOR] = floorPercent;
	s_Groups[group][E_GROUP_CEILING] = ceilingPercent;
	s_Groups[group][E_GROUP_HAS_HALL] = false;
	s_Groups[group][E_GROUP_HIDEOUT] = hideout;
	s_Groups[group][E_GROUP_MEMBERS] = 0;
	s_Groups[group][E_GROUP_CREATED] = created;
	s_Groups[group][E_GROUP_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

	for (new rank = 0;rank < GROUPS_RANKS;rank++)
	{
		strcopy(s_GroupRankNames[group][rank],g_GroupDefaultRanks[s_Groups[group][E_GROUP_KIND]][rank],GROUPS_RANK_NAME_LEN);
		s_GroupRankPerms[group][rank] = g_GroupDefaultPerms[rank];
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Groups_Create(kind,const name[],founder,trade)
{
	new group = Groups_Slot();

	if (group == GROUP_INVALID || kind < 0 || kind >= GROUP_KIND_COUNT || Groups_FindByName(name) != GROUP_INVALID)
	{
		wait_ticks(1);
		return async GROUP_INVALID;
	}

	new now = gettime(), features = g_GroupKindFeatures[kind], bool:chartered = kind == GROUP_KIND_GUILD;
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO `groups` (kind, name, county_id, founder_character_id, livery, features, chartered, reviewed, trade, min_stars, price_floor, price_ceiling, hideout, created_at) VALUES (%d, '%e', %d, %d, 0, %d, %d, %d, %d, 4, 80, 150, -1, %d)",kind,name,REALM_COUNTY,founder,features,_:chartered,_:(kind == GROUP_KIND_GUARD || kind == GROUP_KIND_CHURCH),trade,now));
	new id = cache_insert_id();

	if (id <= 0 || s_Groups[group][E_GROUP_USED])
	{
		return async GROUP_INVALID;
	}

	Groups_Store(group,id,kind,name,founder,0,features,INVALID_CONTAINER_ID,INVALID_CONTAINER_ID,chartered,kind == GROUP_KIND_GUARD || kind == GROUP_KIND_CHURCH,trade,4,80,150,-1,now);

	for (new rank = 0;rank < GROUPS_RANKS;rank++)
	{
		Groups_SaveRank(group,rank);
	}

	new label[CONTAINER_LABEL_LEN];
	format(label,sizeof(label),"%.24s's treasury",name);
	new treasury = await Container_Create(CONTAINER_OWNER_GROUP_TREASURY,id,0,label);
	format(label,sizeof(label),"%.24s's storehouse",name);
	new store = await Container_Create(CONTAINER_OWNER_GROUP_STORE,id,0,label);

	if (!s_Groups[group][E_GROUP_USED] || s_Groups[group][E_GROUP_ID] != id)
	{
		return async GROUP_INVALID;
	}

	s_Groups[group][E_GROUP_TREASURY] = treasury;
	s_Groups[group][E_GROUP_STORE] = store;
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET treasury_container_id = %d, store_container_id = %d WHERE id = %d",treasury,store,id));

	if (treasury != INVALID_CONTAINER_ID)
	{
		await Container_Load(treasury);
	}

	if (store != INVALID_CONTAINER_ID)
	{
		await Container_Load(store);
	}

	Groups_Log(group,founder,"founded");
	pawn_call_public("Groups_OnFounded","d",group);
	return async group;
}

static Groups_RollFind(group,characterid)
{
	for (new i = 0, n = min(s_Groups[group][E_GROUP_MEMBERS],GROUPS_ROLL_MAX);i < n;i++)
	{
		if (s_GroupRoll[group][i] == characterid)
		{
			return i;
		}
	}

	return -1;
}

static Groups_RollAppend(group,characterid)
{
	if (s_Groups[group][E_GROUP_MEMBERS] < GROUPS_ROLL_MAX)
	{
		s_GroupRoll[group][s_Groups[group][E_GROUP_MEMBERS]] = characterid;
	}
	else
	{
		Log_Warn("groups","group %d has more members than its roll holds (%d)",s_Groups[group][E_GROUP_ID],GROUPS_ROLL_MAX);
	}

	s_Groups[group][E_GROUP_MEMBERS]++;
}

stock bool:Groups_IsOnRoll(group,characterid)
{
	return Groups_IsValid(group) && characterid > 0 && Groups_RollFind(group,characterid) != -1;
}

async Task:Groups_AddMember(group,characterid,rank)
{
	if (!Groups_IsValid(group) || Groups_IsSystem(group) || characterid <= 0)
	{
		wait_ticks(1);
		return async 0;
	}

	new id = s_Groups[group][E_GROUP_ID];
	await mysql_aquery_s(g_Mysql,str_format("INSERT IGNORE INTO group_members (group_id, character_id, `rank`, joined_at, spawn_hall) VALUES (%d, %d, %d, %d, 0)",id,characterid,Util_ClampInt(rank,0,GROUPS_RANKS - 1),gettime()));

	if (cache_affected_rows() <= 0 || !Groups_IsValid(group) || s_Groups[group][E_GROUP_ID] != id)
	{
		return async 0;
	}

	Groups_RollAppend(group,characterid);
	new playerid = Groups_PlayerByCharacter(characterid);

	if (playerid != INVALID_PLAYER_ID)
	{
		for (new i = 0;i < GROUPS_PER_CHARACTER;i++)
		{
			if (s_Member[playerid][i][0] == GROUP_INVALID)
			{
				s_Member[playerid][i][0] = group;
				s_Member[playerid][i][1] = Util_ClampInt(rank,0,GROUPS_RANKS - 1);
				s_Member[playerid][i][2] = 0;
				break;
			}
		}

		Groups_RefreshPlayer(playerid);
	}

	Groups_Log(group,characterid,sprintf("joined as rank %d",rank));
	pawn_call_public("Groups_OnJoined","ddd",playerid,group,rank);
	return async 1;
}
#pragma warning pop

stock bool:Groups_RemoveMember(group,characterid)
{
	new at = Groups_IsValid(group) && !Groups_IsSystem(group) && characterid > 0 ? Groups_RollFind(group,characterid) : -1;

	if (at == -1)
	{
		return false;
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_members WHERE group_id = %d AND character_id = %d",s_Groups[group][E_GROUP_ID],characterid));
	new last = min(s_Groups[group][E_GROUP_MEMBERS],GROUPS_ROLL_MAX) - 1;
	s_GroupRoll[group][at] = s_GroupRoll[group][last];
	s_Groups[group][E_GROUP_MEMBERS]--;
	new playerid = Groups_PlayerByCharacter(characterid);

	if (playerid != INVALID_PLAYER_ID)
	{
		for (new i = 0;i < GROUPS_PER_CHARACTER;i++)
		{
			if (s_Member[playerid][i][0] == group)
			{
				s_Member[playerid][i][0] = GROUP_INVALID;
				s_Member[playerid][i][1] = 0;
				s_Member[playerid][i][2] = 0;
			}
		}

		pawn_call_public("Groups_OnLeft","dd",playerid,group);
		Groups_RefreshPlayer(playerid);
	}

	Groups_Log(group,characterid,"left the roll");
	return true;
}

stock bool:Groups_SetMemberRank(group,characterid,rank)
{
	if (!Groups_IsValid(group) || Groups_IsSystem(group) || characterid <= 0 || rank < 0 || rank >= Groups_CountRanks(group))
	{
		return false;
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE group_members SET `rank` = %d WHERE group_id = %d AND character_id = %d",rank,s_Groups[group][E_GROUP_ID],characterid));
	new playerid = Groups_PlayerByCharacter(characterid);

	if (playerid != INVALID_PLAYER_ID)
	{
		for (new i = 0;i < GROUPS_PER_CHARACTER;i++)
		{
			if (s_Member[playerid][i][0] == group)
			{
				s_Member[playerid][i][1] = rank;
			}
		}

		pawn_call_public("Groups_OnRankChanged","ddd",playerid,group,rank);
		Groups_RefreshPlayer(playerid);
	}

	Groups_Log(group,characterid,sprintf("made rank %d",rank));
	return true;
}

stock bool:Groups_Disband(group)
{
	if (!Groups_IsValid(group) || Groups_IsSystem(group))
	{
		return false;
	}

	if (Container_GetCount(s_Groups[group][E_GROUP_TREASURY]) > 0 || Container_GetCount(s_Groups[group][E_GROUP_STORE]) > 0)
	{
		return false;
	}

	new id = s_Groups[group][E_GROUP_ID];

	foreach (new playerid : Player)
	{
		for (new i = 0;i < GROUPS_PER_CHARACTER;i++)
		{
			if (s_Member[playerid][i][0] == group)
			{
				s_Member[playerid][i][0] = GROUP_INVALID;
				pawn_call_public("Groups_OnLeft","dd",playerid,group);
			}
		}
	}

	pawn_call_public("Groups_OnDisbanded","d",group);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_members WHERE group_id = %d",id));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_ranks WHERE group_id = %d",id));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM group_kits WHERE group_id = %d",id));
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET disbanded_at = %d, name = LEFT(CONCAT(id, '~', name), 32) WHERE id = %d",gettime(),id));
	Container_Delete(s_Groups[group][E_GROUP_TREASURY]);
	Container_Delete(s_Groups[group][E_GROUP_STORE]);

	if (IsValidDynamic3DTextLabel(s_Groups[group][E_GROUP_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Groups[group][E_GROUP_LABEL]);
	}

	new hideout = s_Groups[group][E_GROUP_HIDEOUT];
	s_Groups[group][E_GROUP_USED] = false;
	s_Groups[group][E_GROUP_ID] = 0;
	Groups_RefreshHideout(hideout);

	foreach (new playerid : Player)
	{
		Groups_RefreshPlayer(playerid);
	}

	return true;
}

stock Groups_ClaimHideout(group,hideout)
{
	if (!Groups_IsValid(group))
	{
		return;
	}

	s_Groups[group][E_GROUP_HIDEOUT] = hideout;
	mysql_tquery_s(g_Mysql,str_format("UPDATE `groups` SET hideout = %d WHERE id = %d",hideout,s_Groups[group][E_GROUP_ID]));
	Groups_RefreshHideout(hideout);
}

stock bool:Groups_IsHideoutLit(hideout)
{
	return hideout >= 0 && hideout < GROUPS_SEED_HIDEOUTS && Groups_HideoutHolder(hideout) != GROUP_INVALID;
}

stock STREAMER_TAG_OBJECT:Groups_GetHideoutFire(hideout)
{
	return hideout >= 0 && hideout < GROUPS_SEED_HIDEOUTS ? s_GroupsHideoutFires[hideout] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock Groups_RefreshHideout(hideout)
{
	if (hideout < 0 || hideout >= GROUPS_SEED_HIDEOUTS)
	{
		return;
	}

	if (IsValidDynamicObject(s_GroupsHideoutFires[hideout]))
	{
		DestroyDynamicObject(s_GroupsHideoutFires[hideout]);
	}

	Light_Unfollow(LIGHT_FOLLOW_HIDEOUT,hideout);

	new bool:isLit = Groups_IsHideoutLit(hideout), Float:x = g_GroupsHideouts[hideout][0], Float:y = g_GroupsHideouts[hideout][1], Float:z = g_GroupsHideouts[hideout][2], Float:a = g_GroupsHideouts[hideout][3];
	s_GroupsHideoutFires[hideout] = CreateDynamicObject(isLit ? GROUPS_HIDEOUT_FIRE_LIT : GROUPS_HIDEOUT_FIRE_COLD,x,y,z,0.0,0.0,a,0,0,-1,GROUPS_HIDEOUT_STREAM,GROUPS_HIDEOUT_STREAM);

	if (isLit)
	{
		Light_FollowModel(LIGHT_FOLLOW_HIDEOUT,hideout,GROUPS_HIDEOUT_FIRE_LIT,x,y,z,a,0,0);
	}

	Nearby_StreamObjectsAt(x,y,z,0,0,GROUPS_HIDEOUT_STREAM);
	Groups_ForgetHideoutPrompt(hideout);
}

stock Groups_ClearPlayer(playerid)
{
	for (new i = 0;i < GROUPS_PER_CHARACTER;i++)
	{
		s_Member[playerid][i][0] = GROUP_INVALID;
		s_Member[playerid][i][1] = 0;
		s_Member[playerid][i][2] = 0;
	}

	s_MembersLoaded[playerid] = false;
	s_ChatGroup[playerid] = GROUP_INVALID;
	CharPanel_SetGroups(playerid,"");
}

stock bool:Groups_AreMembersLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_MembersLoaded[playerid];
}

#pragma warning push
#pragma warning disable 204
async Task:Groups_LoadMember(playerid,characterid)
{
	Groups_ClearPlayer(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT group_id, `rank`, spawn_hall FROM group_members WHERE character_id = %d LIMIT %d",characterid,GROUPS_PER_CHARACTER));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	new count = 0;

	for (new r = 0, rows = cache_num_rows();r < rows && count < GROUPS_PER_CHARACTER;r++)
	{
		new id, rank, spawn;
		cache_get_value_name_int(r,"group_id",id);
		cache_get_value_name_int(r,"rank",rank);
		cache_get_value_name_int(r,"spawn_hall",spawn);
		new group = Groups_FindById(id);

		if (group != GROUP_INVALID && !Groups_IsSystem(group))
		{
			s_Member[playerid][count][0] = group;
			s_Member[playerid][count][1] = Util_ClampInt(rank,0,GROUPS_RANKS - 1);
			s_Member[playerid][count][2] = spawn;
			count++;
		}
	}

	s_MembersLoaded[playerid] = true;
	Groups_RefreshPlayer(playerid);
	pawn_call_public("Groups_OnMemberLoaded","d",playerid);
	return async count;
}

async Task:Groups_Load()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, name, founder_character_id, livery, features, treasury_container_id, store_container_id, chartered, reviewed, trade, min_stars, price_floor, price_ceiling, hall_x, hall_y, hall_z, hall_a, hall_world, hall_interior, hideout, created_at FROM `groups` WHERE disbanded_at IS NULL ORDER BY id"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new group = Groups_Slot();

		if (group == GROUP_INVALID)
		{
			Log_Warn("groups","no room for more than %d groups",GROUPS_MAX);
			break;
		}

		new id, kind, name[GROUPS_NAME_LEN], founder, livery, features, treasury, store, chartered, reviewed, trade, minStars, floorPercent, ceilingPercent, hideout, created, Float:hall[4], world, interior;
		cache_get_value_name_int(r,"id",id);
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name(r,"name",name);
		cache_get_value_name_int(r,"founder_character_id",founder);
		cache_get_value_name_int(r,"livery",livery);
		cache_get_value_name_int(r,"features",features);
		cache_get_value_name_int(r,"treasury_container_id",treasury);
		cache_get_value_name_int(r,"store_container_id",store);
		cache_get_value_name_int(r,"chartered",chartered);
		cache_get_value_name_int(r,"reviewed",reviewed);
		cache_get_value_name_int(r,"trade",trade);
		cache_get_value_name_int(r,"min_stars",minStars);
		cache_get_value_name_int(r,"price_floor",floorPercent);
		cache_get_value_name_int(r,"price_ceiling",ceilingPercent);
		cache_get_value_name_int(r,"hideout",hideout);
		cache_get_value_name_int(r,"created_at",created);
		cache_get_value_name_float(r,"hall_x",hall[0]);
		cache_get_value_name_float(r,"hall_y",hall[1]);
		cache_get_value_name_float(r,"hall_z",hall[2]);
		cache_get_value_name_float(r,"hall_a",hall[3]);
		cache_get_value_name_int(r,"hall_world",world);
		cache_get_value_name_int(r,"hall_interior",interior);
		Groups_Store(group,id,kind,name,founder,livery,features,treasury <= 0 ? INVALID_CONTAINER_ID : treasury,store <= 0 ? INVALID_CONTAINER_ID : store,chartered != 0,reviewed != 0,trade,minStars,floorPercent,ceilingPercent,hideout,created);

		if (hall[0] != 0.0 || hall[1] != 0.0)
		{
			s_Groups[group][E_GROUP_HAS_HALL] = true;
			s_Groups[group][E_GROUP_HALL][0] = hall[0];
			s_Groups[group][E_GROUP_HALL][1] = hall[1];
			s_Groups[group][E_GROUP_HALL][2] = hall[2];
			s_Groups[group][E_GROUP_HALL][3] = hall[3];
			s_Groups[group][E_GROUP_HALL_WORLD] = world;
			s_Groups[group][E_GROUP_HALL_INTERIOR] = interior;
		}
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT group_id, `rank`, name, perms FROM group_ranks"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new id, rank, name[GROUPS_RANK_NAME_LEN], perms;
		cache_get_value_name_int(r,"group_id",id);
		cache_get_value_name_int(r,"rank",rank);
		cache_get_value_name(r,"name",name);
		cache_get_value_name_int(r,"perms",perms);
		new group = Groups_FindById(id);

		if (group != GROUP_INVALID && rank >= 0 && rank < GROUPS_RANKS)
		{
			strcopy(s_GroupRankNames[group][rank],name,GROUPS_RANK_NAME_LEN);
			s_GroupRankPerms[group][rank] = perms;
		}
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT group_id, character_id FROM group_members"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new id, characterid;
		cache_get_value_name_int(r,"group_id",id);
		cache_get_value_name_int(r,"character_id",characterid);
		new group = Groups_FindById(id);

		if (group != GROUP_INVALID && Groups_RollFind(group,characterid) == -1)
		{
			Groups_RollAppend(group,characterid);
		}
	}

	for (new group = 0;group < GROUPS_MAX;group++)
	{
		if (!s_Groups[group][E_GROUP_USED])
		{
			continue;
		}

		if (s_Groups[group][E_GROUP_TREASURY] != INVALID_CONTAINER_ID)
		{
			await Container_Load(s_Groups[group][E_GROUP_TREASURY]);
		}

		if (s_Groups[group][E_GROUP_STORE] != INVALID_CONTAINER_ID)
		{
			await Container_Load(s_Groups[group][E_GROUP_STORE]);
		}

		Groups_PlaceLabel(group);
	}

	if (Groups_FindKind(GROUP_KIND_GUARD) == GROUP_INVALID)
	{
		await Groups_Create(GROUP_KIND_GUARD,"The county guard",0,-1);
	}

	if (Groups_FindKind(GROUP_KIND_CHURCH) == GROUP_INVALID)
	{
		await Groups_Create(GROUP_KIND_CHURCH,"The church of Talmberg",0,-1);
	}

	s_GroupsLoaded = true;
	return async Groups_Count();
}
#pragma warning pop

forward Groups_OnFounded(group);

public Groups_OnFounded(group)
{
	return 1;
}

forward Groups_OnDisbanded(group);

public Groups_OnDisbanded(group)
{
	return 1;
}

forward Groups_OnJoined(playerid,group,rank);

public Groups_OnJoined(playerid,group,rank)
{
	return 1;
}

forward Groups_OnLeft(playerid,group);

public Groups_OnLeft(playerid,group)
{
	return 1;
}

forward Groups_OnRankChanged(playerid,group,rank);

public Groups_OnRankChanged(playerid,group,rank)
{
	return 1;
}

forward Groups_OnFeatures(group);

public Groups_OnFeatures(group)
{
	return 1;
}

forward Groups_OnRefreshed(playerid);

public Groups_OnRefreshed(playerid)
{
	return 1;
}

forward Groups_OnMemberLoaded(playerid);

public Groups_OnMemberLoaded(playerid)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Groups_ClearPlayer(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	Groups_LoadMember(playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Groups_ClearPlayer(playerid);
}

hook Groups_OnFeatures(group)
{
	Groups_PlaceLabel(group);

	foreach (new playerid : Player)
	{
		if (Groups_IsMember(playerid,group))
		{
			Groups_RefreshPlayer(playerid);
		}
	}
}

hook Law_OnDuty(playerid,isOn)
{
	#pragma unused isOn
	Groups_RefreshPlayer(playerid);
}

hook Law_OnAppointed(playerid,rank)
{
	#pragma unused rank
	Groups_RefreshPlayer(playerid);
}

hook Clergy_OnRankChanged(playerid,before,after)
{
	#pragma unused before, after
	Groups_RefreshPlayer(playerid);
}
