#define SKIN_NAME_LEN (24)
#define SKIN_LOOK_LEN (44)

enum E_SKIN_KIND
{
	SKIN_STARTER,
	SKIN_ROLE,
	SKIN_CHILD,
}

enum E_SKIN_ROW
{
	E_SKIN_MODEL,
	E_SKIN_BASE,
	E_SKIN_DFF[SKIN_NAME_LEN],
	E_SKIN_TXD[SKIN_NAME_LEN],
	E_SKIN_SEX,
	E_SKIN_KIND:E_SKIN_TYPE,
	E_SKIN_LOOK[SKIN_LOOK_LEN],
}

static const s_Skins[][E_SKIN_ROW] = {
	{20159, 133, "peasent41", "peasent41", 0, SKIN_STARTER, "in a grey striped tunic"},
	{20001, 133, "peasent42", "peasent42", 0, SKIN_STARTER, "in a long brown robe"},
	{20002, 133, "peasent2", "peasent2", 0, SKIN_STARTER, "in a fur jerkin"},
	{20003, 133, "peasent3", "peasent3", 0, SKIN_STARTER, "in a pale quilted coat"},
	{20004, 133, "peasent5", "peasent5", 0, SKIN_STARTER, "in a grey tunic with a red capelet"},
	{20005, 133, "peasent6", "peasent6", 0, SKIN_STARTER, "in a dark brown padded jacket"},
	{20006, 133, "peasent8", "peasent8", 0, SKIN_STARTER, "in a green vest and a black cap"},
	{20007, 133, "peasent9", "peasent9", 0, SKIN_STARTER, "in a green chequered tunic"},
	{20008, 133, "peasent10", "peasent10", 0, SKIN_STARTER, "in a blue tunic and a green hood"},
	{20009, 133, "peasent11", "peasent11", 0, SKIN_STARTER, "in a long black coat"},
	{20010, 133, "peasent13", "peasent13", 0, SKIN_STARTER, "in an ochre robe and a red mantle"},
	{20011, 133, "peasent14", "peasent14", 0, SKIN_STARTER, "in a white embroidered tunic"},
	{20012, 133, "fuckinpeasent", "fuckinpeasent", 0, SKIN_ROLE, "in a red tunic and a brown cap"},
	{20013, 133, "oldasfuckpeasent", "oldasfuckpeasent", 0, SKIN_ROLE, "in a long drab coat and a hood"},
	{20014, 133, "peasent16", "peasent16", 0, SKIN_STARTER, "in a fur jerkin and blue breeches"},
	{20015, 133, "peasent17", "peasent17", 0, SKIN_STARTER, "with fair hair, in a fur jerkin"},
	{20016, 133, "naked1", "naked1", 0, SKIN_ROLE, "stripped to the waist"},
	{20017, 133, "peasent22", "peasent22", 0, SKIN_STARTER, "in a leather apron"},
	{20019, 133, "peasent24", "peasent24", 0, SKIN_STARTER, "in a plain grey tunic"},
	{20020, 133, "peasent25", "peasent25", 0, SKIN_STARTER, "in a green tunic"},
	{20021, 133, "peasent26", "peasent26", 0, SKIN_STARTER, "with a beard, in a long drab coat"},
	{20022, 133, "peasent27", "peasent27", 0, SKIN_STARTER, "with long fair hair, in a red tunic"},
	{20023, 133, "peasent28", "peasent28", 0, SKIN_STARTER, "in a mail hood and a long coat"},
	{20024, 133, "kidpeasent", "kidpeasent", 0, SKIN_CHILD, "in a yellow smock"},
	{20025, 133, "kidpeasent2", "kidpeasent2", 0, SKIN_CHILD, "in a green shirt"},
	{20026, 133, "kidgirlpeasent1", "kidgirlpeasent1", 1, SKIN_CHILD, "in a green dress and a white apron"},
	{20027, 133, "kidgirlpeasent2", "kidgirlpeasent2", 1, SKIN_CHILD, "in a lilac dress and a white apron"},
	{20028, 133, "peasent29", "peasent29", 0, SKIN_STARTER, "in a blue quilted tunic"},
	{20029, 133, "peasent30", "peasent30", 0, SKIN_STARTER, "in black with a red shoulder cloak"},
	{20030, 133, "peasent31", "peasent31", 0, SKIN_STARTER, "in a leather apron and a white cap"},
	{20031, 133, "survivor1", "survivor1", 0, SKIN_ROLE, "in a brown tunic and a green scarf"},
	{20032, 133, "survivor2", "survivor2", 0, SKIN_ROLE, "in a drab green tabard"},
	{20033, 133, "peasent32", "peasent32", 0, SKIN_STARTER, "in a blue tabard"},
	{20034, 133, "peasent33", "peasent33", 0, SKIN_STARTER, "in a red jerkin over a white shirt"},
	{20035, 133, "peasent34", "peasent34", 0, SKIN_STARTER, "in a green jerkin over a white shirt"},
	{20036, 133, "peasent35", "peasent35", 0, SKIN_STARTER, "in a fur-trimmed dark coat"},
	{20037, 133, "peasent36", "peasent36", 0, SKIN_STARTER, "in a black hooded robe"},
	{20038, 133, "peasent37", "peasent37", 0, SKIN_STARTER, "with a fair moustache, in a blue tunic"},
	{20039, 133, "peasent38", "peasent38", 0, SKIN_STARTER, "in a long olive coat"},
	{20040, 133, "peasent39", "peasent39", 0, SKIN_STARTER, "in a white robe and a black cowl"},
	{20041, 133, "peasent40", "peasent40", 0, SKIN_STARTER, "in a dark blue padded jacket"},
	{20042, 133, "peasent43", "peasent43", 0, SKIN_STARTER, "in a tan padded jacket"},
	{20043, 133, "peasent44", "peasent44", 0, SKIN_STARTER, "in a brown hooded robe"},
	{20044, 133, "peasent45", "peasent45", 0, SKIN_STARTER, "with a red beard, in a green tunic"},
	{20045, 133, "peasent46", "peasent46", 0, SKIN_STARTER, "with red hair, in a brown tunic"},
	{20046, 133, "peasent47", "peasent47", 0, SKIN_STARTER, "with a fair beard, in a grey tunic"},
	{20047, 133, "peasent48", "peasent48", 0, SKIN_STARTER, "in a blue tunic and a red cloak"},
	{20048, 133, "viking1", "viking1", 0, SKIN_ROLE, "stripped to the waist, with a fair beard"},
	{20049, 133, "viking2", "viking2", 0, SKIN_ROLE, "with long fair hair, in a mail shirt"},
	{20050, 133, "viking3", "viking3", 0, SKIN_ROLE, "in a brown leather vest"},
	{20051, 133, "viking4", "viking4", 0, SKIN_ROLE, "with long fair hair, in a quilted vest"},
	{20052, 133, "viking5", "viking5", 0, SKIN_ROLE, "with a shaved head, in a mail shirt"},
	{20053, 133, "norman", "norman", 0, SKIN_ROLE, "in a short mail shirt"},
	{20054, 133, "norman2", "norman2", 0, SKIN_ROLE, "in a striped surcoat with a black cross"},
	{20055, 133, "norman3", "norman3", 0, SKIN_ROLE, "in a red surcoat with a gold lion"},
	{20056, 133, "norman4", "norman4", 0, SKIN_ROLE, "in a mail coat and a white skirt"},
	{20057, 133, "norman5", "norman5", 0, SKIN_ROLE, "in a mail shirt with red sleeves"},
	{20058, 133, "norman6", "norman6", 0, SKIN_ROLE, "in a studded black jerkin"},
	{20059, 133, "saxon1", "saxon1", 0, SKIN_ROLE, "in mail over a green tunic"},
	{20060, 133, "saxon2", "saxon2", 0, SKIN_ROLE, "in a dark green tunic"},
	{20061, 133, "saxon3", "saxon3", 0, SKIN_ROLE, "in a brown vest over a green tunic"},
	{20062, 133, "saxon4", "saxon4", 0, SKIN_ROLE, "in a mail shirt and a green kilt"},
	{20063, 133, "saxon5", "saxon5", 0, SKIN_ROLE, "with long red hair, in a green tunic"},
	{20064, 133, "turkic", "turkic", 0, SKIN_ROLE, "in lamellar armour and a red sash"},
	{20065, 133, "turkic2", "turkic2", 0, SKIN_ROLE, "in scale armour and a green robe"},
	{20066, 133, "turkic3", "turkic3", 0, SKIN_ROLE, "in a pale fur-lined robe"},
	{20067, 133, "turkic4", "turkic4", 0, SKIN_ROLE, "in a blue scale vest"},
	{20068, 133, "turkic5", "turkic5", 0, SKIN_ROLE, "in a hooded brown coat"},
	{20069, 133, "turkic6", "turkic6", 0, SKIN_ROLE, "in a brown jerkin and dark breeches"},
	{20070, 133, "priest", "priest", 0, SKIN_ROLE, "in a black cap and a grey habit"},
	{20071, 133, "priest2", "priest2", 0, SKIN_ROLE, "in a grey habit with a cross"},
	{20072, 133, "priest3", "priest3", 0, SKIN_ROLE, "in a brown habit with a cross"},
	{20073, 133, "priest4", "priest4", 0, SKIN_ROLE, "in a black cloak and an embroidered stole"},
	{20080, 193, "woman1", "woman1", 1, SKIN_STARTER, "in a brown hooded dress"},
	{20081, 193, "woman2", "woman2", 1, SKIN_STARTER, "with fair hair, in a green dress"},
	{20082, 191, "woman3", "woman3", 1, SKIN_STARTER, "in a pink dress and a white apron"},
	{20083, 191, "woman4", "woman4", 1, SKIN_STARTER, "in a green dress with a blue collar"},
	{20084, 191, "woman5", "woman5", 1, SKIN_STARTER, "in a grey tunic and boots"},
	{20085, 130, "woman6", "woman6", 1, SKIN_STARTER, "in a red skirt and a blue blouse"},
	{20086, 193, "woman7", "woman7", 1, SKIN_STARTER, "in a blue tunic and boots"},
	{20087, 193, "woman8", "woman8", 1, SKIN_STARTER, "in a gold bodice and a dark skirt"},
	{20088, 133, "childboy1", "childboy1", 0, SKIN_CHILD, "in a russet smock"},
	{20089, 133, "childboy2", "childboy2", 0, SKIN_CHILD, "in a blue shirt and dark breeches"},
	{20090, 133, "childgirl1", "childgirl1", 1, SKIN_CHILD, "in a red dress and a white apron"},
	{20091, 133, "childgirl2", "childgirl2", 1, SKIN_CHILD, "in a blue dress and a white apron"},
	{20092, 130, "elderwoman1", "elderwoman1", 1, SKIN_ROLE, "with grey hair, in a russet kirtle"},
	{20093, 130, "elderwoman2", "elderwoman2", 1, SKIN_ROLE, "in a linen coif and a faded blue kirtle"},
	{20094, 130, "elderwoman3", "elderwoman3", 1, SKIN_ROLE, "in a linen kerchief and grey-brown wool"},
	{20100, 133, "kingovernment", "kingovernment", 0, SKIN_ROLE, "in a long patterned robe"},
	{20101, 133, "king2", "king2", 0, SKIN_ROLE, "in a pale quilted robe and a red cloak"},
	{20102, 133, "pope", "pope", 0, SKIN_ROLE, "in white robes and a mitre"},
	{20110, 133, "bandit1", "bandit1", 0, SKIN_ROLE, "in a shaggy fur tunic"},
	{20111, 133, "bandit2", "bandit2", 0, SKIN_ROLE, "with long fair hair, in a grey tunic"},
	{20112, 133, "bandit3", "bandit3", 0, SKIN_ROLE, "with red hair, in a fur vest"},
	{20113, 133, "bandit4", "bandit4", 0, SKIN_ROLE, "stripped to the waist, with a black beard"},
	{20114, 133, "bandit5", "bandit5", 0, SKIN_ROLE, "with red hair, stripped to the waist"},
	{20115, 133, "peasent49", "peasent49", 0, SKIN_STARTER, "with a fair beard, in a long brown tunic"},
	{20116, 133, "peasent50", "peasent50", 0, SKIN_STARTER, "in a brown tunic and a blue cloak"},
	{20117, 193, "womanpeasent9", "womanpeasent9", 1, SKIN_STARTER, "in a long red dress"},
	{20119, 133, "peasent51", "peasent51", 0, SKIN_STARTER, "with a grey beard, in a leather apron"},
	{20120, 133, "peasent52", "peasent52", 0, SKIN_STARTER, "with long brown hair, in a leather apron"},
	{20121, 133, "peasent53", "peasent53", 0, SKIN_STARTER, "in a plain white tunic"},
	{20122, 133, "peasent54", "peasent54", 0, SKIN_STARTER, "in a long black robe"},
	{20123, 133, "peasent55", "peasent55", 0, SKIN_STARTER, "in a long drab vest"},
	{20124, 133, "turkic7", "turkic7", 0, SKIN_ROLE, "in a long brown coat with silver discs"},
	{20125, 133, "turkic8", "turkic8", 0, SKIN_ROLE, "in an ochre robe"},
	{20126, 133, "byz2", "byz2", 0, SKIN_ROLE, "in scale armour and a red skirt"},
	{20127, 133, "byz3", "byz3", 0, SKIN_ROLE, "in a pale padded vest"},
	{20128, 133, "byz4", "byz4", 0, SKIN_ROLE, "in white scale armour"},
	{20129, 133, "byz5", "byz5", 0, SKIN_ROLE, "in a red and brown patterned tunic"},
	{20130, 133, "byz6", "byz6", 0, SKIN_ROLE, "in a brown tunic and a red sash"},
	{20131, 133, "arab1", "arab1", 0, SKIN_ROLE, "in a green striped robe and a veil"},
	{20132, 133, "arab2", "arab2", 0, SKIN_ROLE, "in a long purple robe"},
	{20133, 133, "arab3", "arab3", 0, SKIN_ROLE, "in a grey robe and a white cap"},
	{20134, 133, "arab4", "arab4", 0, SKIN_ROLE, "in a striped brown robe"},
	{20135, 133, "Arab6", "Arab6", 0, SKIN_ROLE, "in a long white coat"},
	{20136, 133, "Arab7", "Arab7", 0, SKIN_ROLE, "in a long green coat"},
	{20137, 133, "Arab8", "Arab8", 0, SKIN_ROLE, "in a scale shirt and a dark skirt"},
	{20138, 133, "arab9", "arab9", 0, SKIN_ROLE, "in bronze scale armour"},
	{20139, 133, "arab10", "arab10", 0, SKIN_ROLE, "in a white robe and a red sash"},
	{20140, 133, "arab11", "arab11", 0, SKIN_ROLE, "in a long black coat with gold trim"},
	{20141, 133, "nwarlord", "nwarlord", 0, SKIN_ROLE, "in a black surcoat with a gold lion"},
	{20142, 133, "knight1", "knight1", 0, SKIN_ROLE, "in a red surcoat with white crosses"},
	{20143, 133, "knight2", "knight2", 0, SKIN_ROLE, "in a black surcoat with a white cross"},
	{20144, 133, "knight3", "knight3", 0, SKIN_ROLE, "in a white surcoat with a black cross"},
	{20145, 133, "knight4", "knight4", 0, SKIN_ROLE, "in a red surcoat with gold lions"},
	{20146, 133, "knight4helmet", "knight4", 0, SKIN_ROLE, "in a great helm and a red surcoat"},
	{20147, 133, "knight5", "knight5", 0, SKIN_ROLE, "in a white surcoat with a gold cross"},
	{20148, 133, "gaelic1", "gaelic1", 0, SKIN_ROLE, "in a pale surcoat over mail"},
	{20149, 133, "gaelic3", "gaelic3", 0, SKIN_ROLE, "in a studded brown coat"},
	{20150, 133, "gaelic4", "gaelic4", 0, SKIN_ROLE, "with red hair, in a plaid kilt"},
	{20151, 133, "gaelic5", "gaelic5", 0, SKIN_ROLE, "with fair hair, in a plaid kilt"},
	{20152, 133, "gaelic6", "gaelic6", 0, SKIN_ROLE, "with long dark hair, in a plaid kilt"},
	{20153, 133, "gaelic7", "gaelic7", 0, SKIN_ROLE, "in a long blue tunic and a plaid sash"},
	{20154, 133, "viking7", "viking7", 0, SKIN_ROLE, "stripped to the waist, in furs"},
	{20155, 133, "set1", "set1", 0, SKIN_ROLE, "in mail with a brown fur collar"},
	{20156, 133, "set2", "set2", 0, SKIN_ROLE, "in mail with red sleeves"},
	{20157, 133, "set11", "set11", 0, SKIN_ROLE, "in mail with a grey fur collar"},
	{20158, 133, "set22", "set22", 0, SKIN_ROLE, "in mail with blue sleeves"},
	{21200, 193, "survivorgirl", "survivorgirl", 1, SKIN_ROLE, "in a long black coat"}
};

static const s_SkinsRetired[][2] = {
	{20018, 20045},
	{20103, 20009},
	{20104, 20021},
	{21201, 20121}
};

stock Skins_GetCount()
{
	return sizeof(s_Skins);
}

stock Skins_GetModel(index)
{
	if (index < 0 || index >= sizeof(s_Skins))
	{
		return 0;
	}

	return s_Skins[index][E_SKIN_MODEL];
}

stock Skins_Resolve(modelid)
{
	for (new i = 0; i < sizeof(s_SkinsRetired); i++)
	{
		if (s_SkinsRetired[i][0] == modelid)
		{
			return s_SkinsRetired[i][1];
		}
	}

	return modelid;
}

stock Skins_GetGuard()
{
    return 20146;
}

stock Skins_GetRetiredCount()
{
	return sizeof(s_SkinsRetired);
}

stock Skins_GetRetired(index)
{
	return index >= 0 && index < sizeof(s_SkinsRetired) ? s_SkinsRetired[index][0] : 0;
}

stock Skins_AddRetireMigration()
{
	new sql[320], ids[64], part[32];
	strcopy(sql,"UPDATE characters SET skin = CASE skin");

	for (new i = 0; i < sizeof(s_SkinsRetired); i++)
	{
		format(part,sizeof(part)," WHEN %d THEN %d",s_SkinsRetired[i][0],s_SkinsRetired[i][1]);
		strcat(sql,part);
		format(part,sizeof(part),"%s%d",i > 0 ? (",") : (""),s_SkinsRetired[i][0]);
		strcat(ids,part);
	}

	format(part,sizeof(part)," END WHERE skin IN (");
	strcat(sql,part);
	strcat(sql,ids);
	strcat(sql,")");
	Migration_Add("character-skins-retired-1",sql);
}

stock bool:Skins_IsModel(modelid)
{
	for (new i = 0; i < sizeof(s_Skins); i++)
	{
		if (s_Skins[i][E_SKIN_MODEL] == modelid)
		{
			return true;
		}
	}

	return false;
}

stock bool:Skins_GetLook(modelid,dest[],size = sizeof(dest))
{
	modelid = Skins_Resolve(modelid);

	for (new i = 0; i < sizeof(s_Skins); i++)
	{
		if (s_Skins[i][E_SKIN_MODEL] == modelid)
		{
			strcopy(dest,s_Skins[i][E_SKIN_LOOK],size);
			return true;
		}
	}

	dest[0] = EOS;
	return false;
}

stock bool:Skins_IsStarter(modelid,sex)
{
	for (new i = 0; i < sizeof(s_Skins); i++)
	{
		if (s_Skins[i][E_SKIN_MODEL] == modelid)
		{
			return s_Skins[i][E_SKIN_TYPE] == SKIN_STARTER && s_Skins[i][E_SKIN_SEX] == sex;
		}
	}

	return false;
}

stock Skins_GetStarter(sex,nth)
{
	new seen = 0;
	for (new i = 0; i < sizeof(s_Skins); i++)
	{
		if (s_Skins[i][E_SKIN_TYPE] != SKIN_STARTER || s_Skins[i][E_SKIN_SEX] != sex)
		{
			continue;
		}

		if (seen++ == nth)
		{
			return s_Skins[i][E_SKIN_MODEL];
		}
	}

	return 0;
}

stock Skins_CountStarter(sex)
{
	new count = 0;
	for (new i = 0; i < sizeof(s_Skins); i++)
	{
		if (s_Skins[i][E_SKIN_TYPE] == SKIN_STARTER && s_Skins[i][E_SKIN_SEX] == sex)
		{
			count++;
		}
	}

	return count;
}

#include <pp-hooks>

hook Models_OnRegister()
{
	new dff[40], txd[40];
	for (new i = 0; i < sizeof(s_Skins); i++)
	{
		format(dff,sizeof(dff),"peds/%s.dff",s_Skins[i][E_SKIN_DFF]);
		format(txd,sizeof(txd),"peds/%s.txd",s_Skins[i][E_SKIN_TXD]);
		Models_AddSkin(s_Skins[i][E_SKIN_MODEL],dff,txd,s_Skins[i][E_SKIN_BASE]);
	}

	for (new r = 0; r < sizeof(s_SkinsRetired); r++)
	{
		for (new i = 0; i < sizeof(s_Skins); i++)
		{
			if (s_Skins[i][E_SKIN_MODEL] == s_SkinsRetired[r][1])
			{
				format(dff,sizeof(dff),"peds/%s.dff",s_Skins[i][E_SKIN_DFF]);
				format(txd,sizeof(txd),"peds/%s.txd",s_Skins[i][E_SKIN_TXD]);
				Models_AddSkin(s_SkinsRetired[r][0],dff,txd,s_Skins[i][E_SKIN_BASE]);
			}
		}
	}
}
