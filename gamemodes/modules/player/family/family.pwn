#define FAMILY_GROWTH (4)
#define FAMILY_GROWN_AGE (18)
#define FAMILY_MAX_CHILDREN (4)
#define FAMILY_ROWS (8)
#define FAMILY_TERM_DAYS (6)
#define FAMILY_MOTHER_MAX_AGE (45)
#define FAMILY_SPOUSE_DEATH_MIN (55)
#define FAMILY_SPOUSE_DEATH_SPREAD (21)
#define FAMILY_TRAIT_PASS (30)
#define FAMILY_ESTATE_SHARE (75)
#define FAMILY_NAME_LEN (CHARACTER_NAME_MAX + 1)
#define FAMILY_NAME_DELAY_MS (4000)
#define FAMILY_HEIR_AGE (18)

enum E_FAMILY_TRY
{
	FAMILY_TRY_OK,
	FAMILY_TRY_NOT_LOADED,
	FAMILY_TRY_NO_SPOUSE,
	FAMILY_TRY_EXPECTING,
	FAMILY_TRY_FULL,
	FAMILY_TRY_TOO_OLD,
}

enum E_FAMILY_SPOUSE
{
	E_FAMILY_SPOUSE_ID,
	E_FAMILY_SPOUSE_NAME[FAMILY_NAME_LEN],
	E_FAMILY_SPOUSE_SEX,
	E_FAMILY_SPOUSE_AGE_AT_WED,
	E_FAMILY_SPOUSE_WED_DAY,
	E_FAMILY_SPOUSE_DIES_AT,
	E_FAMILY_SPOUSE_DUE_DAY,
}

enum E_FAMILY_CHILD
{
	E_FAMILY_CHILD_ID,
	E_FAMILY_CHILD_NAME[FAMILY_NAME_LEN],
	E_FAMILY_CHILD_SEX,
	E_FAMILY_CHILD_BORN_DAY,
	bool:E_FAMILY_CHILD_GROWN,
	E_FAMILY_CHILD_ATTR[5],
	E_FAMILY_CHILD_TRAIT_A,
	E_FAMILY_CHILD_TRAIT_B,
	bool:E_FAMILY_CHILD_BAPTISED,
}

static bool:s_FamilyLoaded[MAX_PLAYERS];
static s_FamilySpouse[MAX_PLAYERS][E_FAMILY_SPOUSE];
static s_FamilyChildren[MAX_PLAYERS][FAMILY_ROWS][E_FAMILY_CHILD];
static s_FamilyChildCount[MAX_PLAYERS];
static bool:s_FamilyBusy[MAX_PLAYERS];
static bool:s_FamilyNaming[MAX_PLAYERS];

stock Family_Today()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Calendar_DaysSinceEpoch(day,month,year);
}

stock Family_ChildAge(bornDay,today)
{
	return min(max(today - bornDay,0) * FAMILY_GROWTH / CALENDAR_DAYS_PER_MONTH,FAMILY_GROWN_AGE);
}

stock Family_DaysToGrown(bornDay,today)
{
	return max(bornDay + (FAMILY_GROWN_AGE * CALENDAR_DAYS_PER_MONTH + FAMILY_GROWTH - 1) / FAMILY_GROWTH - today,0);
}

stock Family_AdultAge(ageThen,sinceDay,today)
{
	return ageThen + max(today - sinceDay,0) / CALENDAR_DAYS_PER_MONTH;
}

stock Family_RollAttribute(parent,spouse)
{
	return clamp((parent + spouse + 1) / 2 + random(3) - 1,CREATOR_ATTR_MIN,CREATOR_ATTR_MAX);
}

stock bool:Family_TraitsClash(a,b)
{
	if (a == b)
	{
		return true;
	}

	if (a > b)
	{
		new swap = a;
		a = b;
		b = swap;
	}

	return (a == _:TRAIT_GLUTTON && b == _:TRAIT_FRUGAL) || (a == _:TRAIT_EARLY_RISER && b == _:TRAIT_HEAVY_SLEEPER) || (a == _:TRAIT_SOFT_HEARTED && b == _:TRAIT_COLD_BLOODED);
}

stock Family_RollTraits(parentA,parentB,spouseTrait,&traitA,&traitB)
{
	new picked[2] = {_:TRAIT_COUNT, _:TRAIT_COUNT}, count = 0, candidates[3];
	candidates[0] = parentA;
	candidates[1] = parentB;
	candidates[2] = spouseTrait;

	for (new i = 0;i < sizeof(candidates) && count < 2;i++)
	{
		new trait = candidates[i];

		if (trait < 0 || trait >= _:TRAIT_COUNT || random(100) >= FAMILY_TRAIT_PASS || (count == 1 && Family_TraitsClash(picked[0],trait)))
		{
			continue;
		}

		picked[count++] = trait;
	}

	for (new tries = 0;count < 2 && tries < 64;tries++)
	{
		new trait = random(_:TRAIT_COUNT);

		if (count == 1 && Family_TraitsClash(picked[0],trait))
		{
			continue;
		}

		picked[count++] = trait;
	}

	traitA = picked[0];
	traitB = picked[1];
}

stock bool:Family_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FamilyLoaded[playerid];
}

stock bool:Family_HasSpouse(playerid)
{
	return Family_IsLoaded(playerid) && s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID] > 0;
}

stock Family_GetSpouseName(playerid,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Family_HasSpouse(playerid))
	{
		strcopy(dest,s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME],size);
	}
}

stock Family_GetSpouseSex(playerid)
{
	return Family_HasSpouse(playerid) ? s_FamilySpouse[playerid][E_FAMILY_SPOUSE_SEX] : -1;
}

stock Family_GetSpouseAge(playerid)
{
	if (!Family_HasSpouse(playerid))
	{
		return 0;
	}

	return Family_AdultAge(s_FamilySpouse[playerid][E_FAMILY_SPOUSE_AGE_AT_WED],s_FamilySpouse[playerid][E_FAMILY_SPOUSE_WED_DAY],Family_Today());
}

stock Family_GetDueDays(playerid)
{
	if (!Family_HasSpouse(playerid) || s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] <= 0)
	{
		return -1;
	}

	return max(s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] - Family_Today(),0);
}

stock Family_CountChildren(playerid)
{
	return Family_IsLoaded(playerid) ? s_FamilyChildCount[playerid] : 0;
}

stock bool:Family_GetChild(playerid,index,&childid,name[],&sex,&age,&bool:isGrown,nameSize = sizeof(name))
{
	if (!Family_IsLoaded(playerid) || index < 0 || index >= s_FamilyChildCount[playerid])
	{
		return false;
	}

	childid = s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ID];
	strcopy(name,s_FamilyChildren[playerid][index][E_FAMILY_CHILD_NAME],nameSize);
	sex = s_FamilyChildren[playerid][index][E_FAMILY_CHILD_SEX];
	isGrown = s_FamilyChildren[playerid][index][E_FAMILY_CHILD_GROWN];
	age = isGrown ? FAMILY_GROWN_AGE : Family_ChildAge(s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BORN_DAY],Family_Today());
	return true;
}

stock Family_GetChildDaysToGrown(playerid,index)
{
	if (!Family_IsLoaded(playerid) || index < 0 || index >= s_FamilyChildCount[playerid] || s_FamilyChildren[playerid][index][E_FAMILY_CHILD_GROWN])
	{
		return 0;
	}

	return Family_DaysToGrown(s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BORN_DAY],Family_Today());
}

stock bool:Family_GetChildStats(playerid,index,attributes[5],&traitA,&traitB)
{
	if (!Family_IsLoaded(playerid) || index < 0 || index >= s_FamilyChildCount[playerid] || !s_FamilyChildren[playerid][index][E_FAMILY_CHILD_GROWN])
	{
		return false;
	}

	for (new i = 0;i < 5;i++)
	{
		attributes[i] = s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ATTR][i];
	}

	traitA = s_FamilyChildren[playerid][index][E_FAMILY_CHILD_TRAIT_A];
	traitB = s_FamilyChildren[playerid][index][E_FAMILY_CHILD_TRAIT_B];
	return true;
}

stock bool:Family_IsChildBaptised(playerid,index)
{
	return Family_IsLoaded(playerid) && index >= 0 && index < s_FamilyChildCount[playerid] && s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BAPTISED];
}

stock bool:Family_MarkBaptised(playerid,index)
{
	if (!Family_IsLoaded(playerid) || index < 0 || index >= s_FamilyChildCount[playerid] || s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BAPTISED])
	{
		return false;
	}

	s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BAPTISED] = true;
	mysql_tquery_s(g_Mysql,str_format("UPDATE character_children SET baptised = 1 WHERE id = %d",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ID]));
	return true;
}

stock Family_FindUnnamed(playerid)
{
	for (new i = 0;i < Family_CountChildren(playerid);i++)
	{
		if (s_FamilyChildren[playerid][i][E_FAMILY_CHILD_NAME][0] == EOS)
		{
			return i;
		}
	}

	return -1;
}

stock Family_MotherAge(playerid)
{
	if (!Family_HasSpouse(playerid))
	{
		return 0;
	}

	return Character_GetSex(playerid) == 1 ? Lineage_GetAge(playerid) : Family_GetSpouseAge(playerid);
}

stock E_FAMILY_TRY:Family_CanTry(playerid)
{
	if (!Family_IsLoaded(playerid) || s_FamilyBusy[playerid])
	{
		return FAMILY_TRY_NOT_LOADED;
	}

	if (!Family_HasSpouse(playerid))
	{
		return FAMILY_TRY_NO_SPOUSE;
	}

	if (s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] > 0)
	{
		return FAMILY_TRY_EXPECTING;
	}

	if (s_FamilyChildCount[playerid] >= FAMILY_MAX_CHILDREN)
	{
		return FAMILY_TRY_FULL;
	}

	if (Family_MotherAge(playerid) > FAMILY_MOTHER_MAX_AGE)
	{
		return FAMILY_TRY_TOO_OLD;
	}

	return FAMILY_TRY_OK;
}

stock E_FAMILY_TRY:Family_TryForChild(playerid)
{
	new E_FAMILY_TRY:result = Family_CanTry(playerid);

	if (result != FAMILY_TRY_OK)
	{
		return result;
	}

	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] = Family_Today() + FAMILY_TERM_DAYS;
	mysql_tquery_s(g_Mysql,str_format("UPDATE character_spouses SET due_day = %d WHERE id = %d",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY],s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID]));
	return FAMILY_TRY_OK;
}

stock bool:Family_GrantSpouse(playerid,const name[],age)
{
	if (!Family_IsLoaded(playerid) || Family_HasSpouse(playerid) || s_FamilyBusy[playerid] || !Character_ValidateName(name))
	{
		return false;
	}

	new today = Family_Today(), sex = Character_GetSex(playerid) == 1 ? 0 : 1, diesAt = FAMILY_SPOUSE_DEATH_MIN + random(FAMILY_SPOUSE_DEATH_SPREAD);
	s_FamilyBusy[playerid] = true;
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID] = 0;
	strcopy(s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME],name,FAMILY_NAME_LEN);
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_SEX] = sex;
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_AGE_AT_WED] = clamp(age,16,60);
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_WED_DAY] = today;
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DIES_AT] = max(diesAt,s_FamilySpouse[playerid][E_FAMILY_SPOUSE_AGE_AT_WED] + 1);
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] = 0;
	SetTimerEx("Family_InsertSpouse",0,false,"ddd",playerid,Account_GetToken(playerid),Character_GetId(playerid));
	return true;
}

forward Family_InsertSpouse(playerid,token,characterid);

public Family_InsertSpouse(playerid,token,characterid)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new attributes[5], trait = random(_:TRAIT_COUNT);

	for (new i = 0;i < 5;i++)
	{
		attributes[i] = CREATOR_ATTR_MIN + random(CREATOR_ATTR_MAX - CREATOR_ATTR_MIN + 1);
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO character_spouses (character_id, name, sex, age_at_wed, wed_day, dies_at, willpower, craftmanship, intelligence, honor_grace, piety, trait) VALUES (%d, '%e', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)",
		characterid,s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME],s_FamilySpouse[playerid][E_FAMILY_SPOUSE_SEX],s_FamilySpouse[playerid][E_FAMILY_SPOUSE_AGE_AT_WED],s_FamilySpouse[playerid][E_FAMILY_SPOUSE_WED_DAY],s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DIES_AT],
		attributes[0],attributes[1],attributes[2],attributes[3],attributes[4],trait));

	new id = mysql_errno(g_Mysql) == 0 ? cache_insert_id() : 0;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID] = id;
	s_FamilyBusy[playerid] = false;

	if (id > 0)
	{
		Gui_Notify(playerid,sprintf("You're wed to %s. Look for your family on the Family page of your character panel.",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME]));
		pawn_call_public("Family_OnWed","dd",playerid,id);
	}
}

static Family_Clear(playerid)
{
	s_FamilyLoaded[playerid] = false;
	s_FamilyBusy[playerid] = false;
	s_FamilyNaming[playerid] = false;
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID] = 0;
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME][0] = EOS;
	s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] = 0;
	s_FamilyChildCount[playerid] = 0;
}

static Family_ReadChild(playerid,row,index)
{
	new grown;
	cache_get_value_name_int(row,"id",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ID]);
	cache_get_value_name(row,"name",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_NAME],FAMILY_NAME_LEN);
	cache_get_value_name_int(row,"sex",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_SEX]);
	cache_get_value_name_int(row,"born_day",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BORN_DAY]);
	cache_get_value_name_int(row,"grown",grown);
	cache_get_value_name_int(row,"willpower",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ATTR][0]);
	cache_get_value_name_int(row,"craftmanship",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ATTR][1]);
	cache_get_value_name_int(row,"intelligence",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ATTR][2]);
	cache_get_value_name_int(row,"honor_grace",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ATTR][3]);
	cache_get_value_name_int(row,"piety",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ATTR][4]);
	cache_get_value_name_int(row,"trait_a",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_TRAIT_A]);
	cache_get_value_name_int(row,"trait_b",s_FamilyChildren[playerid][index][E_FAMILY_CHILD_TRAIT_B]);
	s_FamilyChildren[playerid][index][E_FAMILY_CHILD_GROWN] = grown != 0;

	new baptised;
	cache_get_value_name_int(row,"baptised",baptised);
	s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BAPTISED] = baptised != 0;
}

static Family_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, name, sex, age_at_wed, wed_day, dies_at, IFNULL(due_day, 0) AS due_day FROM character_spouses WHERE character_id = %d AND ended_day IS NULL ORDER BY id DESC LIMIT 1",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"id",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID]);
		cache_get_value_name(0,"name",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME],FAMILY_NAME_LEN);
		cache_get_value_name_int(0,"sex",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_SEX]);
		cache_get_value_name_int(0,"age_at_wed",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_AGE_AT_WED]);
		cache_get_value_name_int(0,"wed_day",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_WED_DAY]);
		cache_get_value_name_int(0,"dies_at",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DIES_AT]);
		cache_get_value_name_int(0,"due_day",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY]);
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, name, sex, born_day, grown, baptised, willpower, craftmanship, intelligence, honor_grace, piety, trait_a, trait_b FROM character_children WHERE parent_character_id = %d AND heir_character_id IS NULL ORDER BY born_day, id LIMIT %d",characterid,FAMILY_ROWS));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	s_FamilyChildCount[playerid] = cache_num_rows();

	for (new r = 0;r < s_FamilyChildCount[playerid];r++)
	{
		Family_ReadChild(playerid,r,r);
	}

	s_FamilyLoaded[playerid] = true;
	Family_Update(playerid);
}

stock bool:Family_RollChild(childid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT c.grown, p.willpower AS pw, p.craftmanship AS pc, p.intelligence AS pi, p.honor_grace AS ph, p.piety AS pp, p.trait_a AS pta, p.trait_b AS ptb, s.willpower AS sw, s.craftmanship AS sc, s.intelligence AS si, s.honor_grace AS sh, s.piety AS sp, s.trait AS st FROM character_children c JOIN characters p ON p.id = c.parent_character_id JOIN character_spouses s ON s.id = c.spouse_id WHERE c.id = %d",childid));

	if (mysql_errno(g_Mysql) != 0 || cache_num_rows() == 0)
	{
		return false;
	}

	new grown;
	cache_get_value_name_int(0,"grown",grown);

	if (grown != 0)
	{
		return true;
	}

	new parent[5], spouse[5], parentA, parentB, spouseTrait, attributes[5], traitA, traitB;
	cache_get_value_name_int(0,"pw",parent[0]);
	cache_get_value_name_int(0,"pc",parent[1]);
	cache_get_value_name_int(0,"pi",parent[2]);
	cache_get_value_name_int(0,"ph",parent[3]);
	cache_get_value_name_int(0,"pp",parent[4]);
	cache_get_value_name_int(0,"pta",parentA);
	cache_get_value_name_int(0,"ptb",parentB);
	cache_get_value_name_int(0,"sw",spouse[0]);
	cache_get_value_name_int(0,"sc",spouse[1]);
	cache_get_value_name_int(0,"si",spouse[2]);
	cache_get_value_name_int(0,"sh",spouse[3]);
	cache_get_value_name_int(0,"sp",spouse[4]);
	cache_get_value_name_int(0,"st",spouseTrait);

	for (new i = 0;i < 5;i++)
	{
		attributes[i] = Family_RollAttribute(parent[i],spouse[i]);
	}

	Family_RollTraits(parentA,parentB,spouseTrait,traitA,traitB);
	await mysql_aquery_s(g_Mysql,str_format("UPDATE character_children SET grown = 1, willpower = %d, craftmanship = %d, intelligence = %d, honor_grace = %d, piety = %d, trait_a = %d, trait_b = %d WHERE id = %d AND grown = 0",attributes[0],attributes[1],attributes[2],attributes[3],attributes[4],traitA,traitB,childid));
	return mysql_errno(g_Mysql) == 0;
}

stock Family_Update(playerid)
{
	yield 1;

	if (!Family_IsLoaded(playerid) || s_FamilyBusy[playerid])
	{
		return;
	}

	new token = Account_GetToken(playerid), characterid = Character_GetId(playerid), today = Family_Today();
	s_FamilyBusy[playerid] = true;

	if (Family_HasSpouse(playerid) && s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] > 0 && today >= s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] && s_FamilyChildCount[playerid] < FAMILY_ROWS)
	{
		new sex = random(2), bornDay = s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY];
		s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] = 0;
		mysql_tquery_s(g_Mysql,str_format("UPDATE character_spouses SET due_day = NULL WHERE id = %d",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID]));
		await mysql_aquery_s(g_Mysql,str_format("INSERT INTO character_children (parent_character_id, spouse_id, sex, born_day) VALUES (%d, %d, %d, %d)",characterid,s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID],sex,bornDay));

		new id = mysql_errno(g_Mysql) == 0 ? cache_insert_id() : 0;

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
		{
			return;
		}

		if (id > 0)
		{
			new index = s_FamilyChildCount[playerid]++;
			s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ID] = id;
			s_FamilyChildren[playerid][index][E_FAMILY_CHILD_NAME][0] = EOS;
			s_FamilyChildren[playerid][index][E_FAMILY_CHILD_SEX] = sex;
			s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BORN_DAY] = bornDay;
			s_FamilyChildren[playerid][index][E_FAMILY_CHILD_GROWN] = false;
			s_FamilyChildren[playerid][index][E_FAMILY_CHILD_BAPTISED] = false;
			if (s_FamilySpouse[playerid][E_FAMILY_SPOUSE_SEX] == 1)
			{
				Gui_Notify(playerid,sprintf("%s has given birth to a healthy %s. Give the child a name.",s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME],sex == 1 ? ("daughter") : ("son")));
			}
			else
			{
				Gui_Notify(playerid,sprintf("You've given birth to a healthy %s. Give the child a name.",sex == 1 ? ("daughter") : ("son")));
			}

			pawn_call_public("Family_OnBirth","dd",playerid,id);
		}
	}

	if (Family_HasSpouse(playerid) && Family_GetSpouseAge(playerid) >= s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DIES_AT])
	{
		new name[FAMILY_NAME_LEN], age = Family_GetSpouseAge(playerid), bool:isWife = s_FamilySpouse[playerid][E_FAMILY_SPOUSE_SEX] == 1;
		strcopy(name,s_FamilySpouse[playerid][E_FAMILY_SPOUSE_NAME]);
		mysql_tquery_s(g_Mysql,str_format("UPDATE character_spouses SET ended_day = %d, due_day = NULL WHERE id = %d",today,s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID]));
		s_FamilySpouse[playerid][E_FAMILY_SPOUSE_ID] = 0;
		s_FamilySpouse[playerid][E_FAMILY_SPOUSE_DUE_DAY] = 0;
		Gui_Notify(playerid,sprintf("%s, your %s, has died of old age at %d. You may marry again.",name,isWife ? ("wife") : ("husband"),age));
	}

	for (new i = 0;i < s_FamilyChildCount[playerid];i++)
	{
		if (s_FamilyChildren[playerid][i][E_FAMILY_CHILD_GROWN] || Family_ChildAge(s_FamilyChildren[playerid][i][E_FAMILY_CHILD_BORN_DAY],today) < FAMILY_GROWN_AGE)
		{
			continue;
		}

		new childid = s_FamilyChildren[playerid][i][E_FAMILY_CHILD_ID];

		if (!Family_RollChild(childid))
		{
			continue;
		}

		await mysql_aquery_s(g_Mysql,str_format("SELECT id, name, sex, born_day, grown, baptised, willpower, craftmanship, intelligence, honor_grace, piety, trait_a, trait_b FROM character_children WHERE id = %d",childid));

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
		{
			return;
		}

		if (cache_num_rows() > 0 && i < s_FamilyChildCount[playerid] && s_FamilyChildren[playerid][i][E_FAMILY_CHILD_ID] == childid)
		{
			Family_ReadChild(playerid,0,i);

			new name[FAMILY_NAME_LEN];
			strcopy(name,s_FamilyChildren[playerid][i][E_FAMILY_CHILD_NAME]);

			if (name[0] == EOS)
			{
				strcopy(name,s_FamilyChildren[playerid][i][E_FAMILY_CHILD_SEX] == 1 ? ("Your daughter") : ("Your son"));
			}

			Gui_Notify(playerid,sprintf("%s has come of age. At eighteen, they can carry the family on if it comes to that.",name));
		}
	}

	s_FamilyBusy[playerid] = false;

	if (Family_FindUnnamed(playerid) != -1 && !s_FamilyNaming[playerid])
	{
		SetTimerEx("Family_AskNameDeferred",FAMILY_NAME_DELAY_MS,false,"dd",playerid,token);
	}
}

stock bool:Family_NameChild(playerid,index,const name[])
{
	if (!Family_IsLoaded(playerid) || index < 0 || index >= s_FamilyChildCount[playerid] || !Character_ValidateName(name))
	{
		return false;
	}

	strcopy(s_FamilyChildren[playerid][index][E_FAMILY_CHILD_NAME],name,FAMILY_NAME_LEN);
	mysql_tquery_s(g_Mysql,str_format("UPDATE character_children SET name = '%e' WHERE id = %d",name,s_FamilyChildren[playerid][index][E_FAMILY_CHILD_ID]));
	return true;
}

stock bool:Family_IsNameTaken(playerid,const name[])
{
	new surname[FAMILY_NAME_LEN];
	Character_GetSurname(playerid,surname);

	for (new i = 0;i < Family_CountChildren(playerid);i++)
	{
		if (!strcmp(s_FamilyChildren[playerid][i][E_FAMILY_CHILD_NAME],name,true) && s_FamilyChildren[playerid][i][E_FAMILY_CHILD_NAME][0] != EOS)
		{
			return true;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS taken FROM characters WHERE name = '%e' AND surname = '%e'",name,surname));

	new taken = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"taken",taken);
	}

	return taken > 0;
}

stock Family_SettleEstate(characterid,coin,bool:isRetired)
{
	new share = isRetired ? coin : coin * FAMILY_ESTATE_SHARE / 100;
	mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO character_estates (character_id, coin) VALUES (%d, %d)",characterid,max(share,0)));
	return share;
}

stock Family_CreateHeir(accountid,childid,deceasedid,slot)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT c.grown FROM character_children c JOIN characters p ON p.id = c.parent_character_id WHERE c.id = %d AND c.parent_character_id = %d AND c.heir_character_id IS NULL AND p.account_id = %d AND p.alive = 0",childid,deceasedid,accountid));

	if (mysql_errno(g_Mysql) != 0 || cache_num_rows() == 0)
	{
		return 0;
	}

	new grown;
	cache_get_value_name_int(0,"grown",grown);

	if (grown == 0 && !Family_RollChild(childid))
	{
		return 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT c.name, c.sex, c.born_day, c.baptised, c.willpower, c.craftmanship, c.intelligence, c.honor_grace, c.piety, c.trait_a, c.trait_b, p.surname, p.origin, p.culture, p.lifestyle, p.willpower AS pw, p.craftmanship AS pc, p.intelligence AS pi, p.honor_grace AS ph, p.piety AS pp FROM character_children c JOIN characters p ON p.id = c.parent_character_id WHERE c.id = %d",childid));

	if (mysql_errno(g_Mysql) != 0 || cache_num_rows() == 0)
	{
		return 0;
	}

	new name[FAMILY_NAME_LEN], surname[FAMILY_NAME_LEN], sex, bornDay, baptised, attributes[5], parent[5], traitA, traitB, origin, culture, lifestyle;
	cache_get_value_name_int(0,"baptised",baptised);
	cache_get_value_name(0,"name",name);
	cache_get_value_name(0,"surname",surname);
	cache_get_value_name_int(0,"sex",sex);
	cache_get_value_name_int(0,"born_day",bornDay);
	cache_get_value_name_int(0,"willpower",attributes[0]);
	cache_get_value_name_int(0,"craftmanship",attributes[1]);
	cache_get_value_name_int(0,"intelligence",attributes[2]);
	cache_get_value_name_int(0,"honor_grace",attributes[3]);
	cache_get_value_name_int(0,"piety",attributes[4]);
	cache_get_value_name_int(0,"trait_a",traitA);
	cache_get_value_name_int(0,"trait_b",traitB);
	cache_get_value_name_int(0,"origin",origin);
	cache_get_value_name_int(0,"culture",culture);
	cache_get_value_name_int(0,"lifestyle",lifestyle);
	cache_get_value_name_int(0,"pw",parent[0]);
	cache_get_value_name_int(0,"pc",parent[1]);
	cache_get_value_name_int(0,"pi",parent[2]);
	cache_get_value_name_int(0,"ph",parent[3]);
	cache_get_value_name_int(0,"pp",parent[4]);

	if (name[0] == EOS || Family_ChildAge(bornDay,Family_Today()) < FAMILY_GROWN_AGE)
	{
		return 0;
	}

	new best = 0;

	for (new i = 1;i < 5;i++)
	{
		if (parent[i] > parent[best])
		{
			best = i;
		}
	}

	attributes[best] = min(attributes[best] + 1,CREATOR_ATTR_MAX);

	new Float:spawn[4], skin = Skins_GetStarter(sex,random(max(Skins_CountStarter(sex),1)));
	Creator_GetLifestyleSpawn(E_LIFESTYLE:lifestyle,spawn[0],spawn[1],spawn[2],spawn[3]);

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO characters (account_id, slot, name, surname, sex, skin, age, origin, culture, willpower, craftmanship, intelligence, honor_grace, piety, trait_a, trait_b, lifestyle, pos_x, pos_y, pos_z, angle, tutorial_done, life_bonus) VALUES (%d, %d, '%e', '%e', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %f, %f, %f, %f, 1, %d)",
		accountid,slot,name,surname,sex,skin,FAMILY_HEIR_AGE,origin,culture,attributes[0],attributes[1],attributes[2],attributes[3],attributes[4],traitA,traitB,lifestyle,spawn[0],spawn[1],spawn[2],spawn[3],baptised != 0 ? 1 : 0));

	if (mysql_errno(g_Mysql) != 0)
	{
		return 0;
	}

	new heirid = cache_insert_id();
	await mysql_aquery_s(g_Mysql,str_format("UPDATE character_children SET heir_character_id = %d WHERE id = %d",heirid,childid));
	await mysql_aquery_s(g_Mysql,str_format("INSERT IGNORE INTO job_levels (character_id, trade, level, practice) SELECT %d, trade, GREATEST(level DIV 2, 1), 0 FROM job_levels WHERE character_id = %d",heirid,deceasedid));
	await mysql_aquery_s(g_Mysql,str_format("UPDATE character_estates SET heir_character_id = %d WHERE character_id = %d AND heir_character_id IS NULL",heirid,deceasedid));
	Log_Info("family","account %d: %s %s (child %d) is the heir of character %d, now character %d in slot %d",accountid,name,surname,childid,deceasedid,heirid,slot);
	pawn_call_public("Family_OnHeir","ddd",deceasedid,childid,heirid);
	return heirid;
}

stock Family_ClaimEstate(playerid)
{
	yield 1;

	new token = Account_GetToken(playerid), characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT e.character_id, e.coin, p.name, p.surname FROM character_estates e JOIN characters p ON p.id = e.character_id WHERE e.heir_character_id = %d AND e.claimed = 0 LIMIT 1",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid || cache_num_rows() == 0)
	{
		return;
	}

	new deceasedid, coin, name[FAMILY_NAME_LEN], surname[FAMILY_NAME_LEN], purse[48];
	cache_get_value_name_int(0,"character_id",deceasedid);
	cache_get_value_name_int(0,"coin",coin);
	cache_get_value_name(0,"name",name);
	cache_get_value_name(0,"surname",surname);
	await mysql_aquery_s(g_Mysql,str_format("UPDATE character_estates SET claimed = 1 WHERE character_id = %d AND claimed = 0",deceasedid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid || cache_affected_rows() == 0)
	{
		return;
	}

	if (coin > 0 && Economy_Give(playerid,coin,"inheritance"))
	{
		Economy_Format(coin,purse);
		Gui_Notify(playerid,sprintf("You inherit %s from %s %s, and the trades you learned at their side.",purse,name,surname));
	}
	else
	{
		Gui_Notify(playerid,sprintf("You carry on the name of %s %s, and the trades you learned at their side.",name,surname));
	}
}

forward Family_AskNameDeferred(playerid,token);

public Family_AskNameDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_IsPlaying(playerid) && !s_FamilyNaming[playerid] && Family_FindUnnamed(playerid) != -1)
	{
		if (Gui_IsBusy(playerid))
		{
			SetTimerEx("Family_AskNameDeferred",FAMILY_NAME_DELAY_MS,false,"dd",playerid,token);
			return 1;
		}

		FamilyGui_AskName(playerid,token);
	}

	return 1;
}

stock Family_BeginNaming(playerid)
{
	s_FamilyNaming[playerid] = true;
}

stock Family_EndNaming(playerid)
{
	s_FamilyNaming[playerid] = false;
}

forward Family_LoadDeferred(playerid,token);

public Family_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Family_Load(playerid,token);
	}

	return 1;
}

forward Family_ClaimDeferred(playerid,token);

public Family_ClaimDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Family_ClaimEstate(playerid);
	}

	return 1;
}

forward Family_UpdateDeferred(playerid,token);

public Family_UpdateDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Family_Update(playerid);
	}

	return 1;
}

forward Family_OnWed(playerid,spouseid);

public Family_OnWed(playerid,spouseid)
{
	return 1;
}

forward Family_OnBirth(playerid,childid);

public Family_OnBirth(playerid,childid)
{
	return 1;
}

forward Family_OnHeir(deceasedid,childid,heirid);

public Family_OnHeir(deceasedid,childid,heirid)
{
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:spouse(cmdid, playerid, params[])
{
	new targetid, name[FAMILY_NAME_LEN], age;

	if (sscanf(params,"us[21]I(20)",targetid,name,age) || !Util_IsValidPlayer(targetid))
	{
		Command_Usage(playerid,cmdid,"<player> <given name> [age]");
		return 1;
	}

	if (!Family_GrantSpouse(targetid,name,age))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,"They can't wed now: already married, not loaded yet, or that isn't a valid name.");
		return 1;
	}

	SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("%s is wed to them.",name));
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Family_Clear(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Family_Clear(playerid);
	SetTimerEx("Family_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Family_Clear(playerid);
}

hook Inventory_OnLoaded(playerid)
{
	SetTimerEx("Family_ClaimDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year

	foreach (new playerid : Player)
	{
		if (Family_IsLoaded(playerid))
		{
			SetTimerEx("Family_UpdateDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
		}
	}
}
