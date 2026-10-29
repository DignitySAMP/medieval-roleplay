#define CULTURE_NAME_LEN (24)
#define CULTURE_GROUP_COUNT (22)
#define CULTURE_COUNT (86)
#define CULTURE_DEFAULT (0)
#define LANGUAGE_COMMON (0)
#define LANGUAGE_COUNT (CULTURE_GROUP_COUNT + 1)
#define LANGUAGE_COMMON_COLOUR (0xD8CCB2FF)

enum E_CULTURE_GROUP_ROW
{
	E_CULTURE_GROUP_NAME[CULTURE_NAME_LEN],
	E_CULTURE_GROUP_COLOUR,
}

static const s_CultureGroups[CULTURE_GROUP_COUNT][E_CULTURE_GROUP_ROW] = {
	{"North Germanic", 0x3D6DBAFF},
	{"Central Germanic", 0x6E61BAFF},
	{"West Germanic", 0x9E3636FF},
	{"Latin", 0xBAA830FF},
	{"Iberian", 0xEBD444FF},
	{"Byzantine", 0xAC65DBFF},
	{"Celtic", 0x6DB2DEFF},
	{"Finno Ugric", 0x88D466FF},
	{"Baltic", 0xAFBF73FF},
	{"Altaic", 0xD1A952FF},
	{"Arabic", 0x48BD39FF},
	{"East Slavic", 0x8DAD63FF},
	{"West Slavic", 0x63AD75FF},
	{"South Slavic", 0xA16767FF},
	{"Magyar", 0x72A167FF},
	{"Iranian", 0x9BB531FF},
	{"African", 0x8E9963FF},
	{"Israelite", 0xC272B9FF},
	{"Indo Aryan", 0xB53512FF},
	{"Dravidian", 0xE3A92DFF},
	{"Tibeto Burman", 0xED7E1CFF},
	{"Chinese", 0xD93B3BFF}
};

enum E_CULTURE_ROW
{
	E_CULTURE_GROUP,
	E_CULTURE_NAME[CULTURE_NAME_LEN],
	E_CULTURE_COLOUR,
}

static const s_Cultures[CULTURE_COUNT][E_CULTURE_ROW] = {
	{0, "Swedish", 0x3D6DBAFF},
	{0, "Norwegian", 0x3662A7FF},
	{0, "Danish", 0x305794FF},
	{1, "German", 0x7C70C0FF},
	{2, "English", 0xB15E5EFF},
	{2, "Frisian", 0x8E3030FF},
	{2, "Dutch", 0x7E2B2BFF},
	{3, "French", 0xC7B959FF},
	{3, "Norman", 0xC0B044FF},
	{3, "Italian", 0xA7972BFF},
	{3, "Occitan", 0x948626FF},
	{3, "Roman", 0x827521FF},
	{4, "Basque", 0xF3E58EFF},
	{4, "Castilian", 0xEFDC69FF},
	{4, "Catalan", 0xEBD444FF},
	{4, "Portuguese", 0xD3BE3DFF},
	{5, "Armenian", 0xBC83E2FF},
	{5, "Greek", 0xB474DEFF},
	{5, "Alan", 0x9A5AC5FF},
	{5, "Georgian", 0x8950AFFF},
	{5, "Assyrian", 0x784699FF},
	{6, "Irish", 0x8AC1E4FF},
	{6, "Scottish", 0x7BB9E1FF},
	{6, "Welsh", 0x62A0C7FF},
	{6, "Breton", 0x578EB1FF},
	{7, "Finnish", 0x9FDC84FF},
	{7, "Sami", 0x93D875FF},
	{7, "Estonian", 0x7ABE5BFF},
	{7, "Komi", 0x6CA951FF},
	{7, "Khanty", 0x5F9447FF},
	{7, "Nenets", 0x517F3DFF},
	{7, "Mordvin", 0x446A33FF},
	{8, "Lettigallian", 0xAFBF73FF},
	{8, "Lithuanian", 0x9DAB67FF},
	{8, "Prussian", 0x8C985CFF},
	{9, "Turkish", 0xDEC285FF},
	{9, "Cuman", 0xD5B163FF},
	{9, "Bolghar", 0xBC9849FF},
	{9, "Karluk", 0x927639FF},
	{9, "Kirghiz", 0x8A7445FF},
	{9, "Uyghur", 0x7D6531FF},
	{9, "Mongol", 0x705A2CFF},
	{9, "Khitan", 0x645027FF},
	{9, "Jurchen", 0x574622FF},
	{10, "Bedouin", 0x6CCA60FF},
	{10, "Berber", 0x5AC34CFF},
	{10, "Levantine", 0x48BD39FF},
	{10, "Egyptian", 0x40AA33FF},
	{10, "Andalusian", 0x39972DFF},
	{11, "Russian", 0x98B572FF},
	{11, "Volhynian", 0x708A4FFF},
	{12, "Pomeranian", 0x82BD90FF},
	{12, "Bohemian", 0x72B582FF},
	{12, "Polish", 0x63AD75FF},
	{13, "Croatian", 0xAA7676FF},
	{13, "Serbian", 0xA16767FF},
	{13, "Vlach", 0x905C5CFF},
	{13, "Bulgarian", 0x805252FF},
	{14, "Hungarian", 0x72A167FF},
	{15, "Persian", 0xB9CB6EFF},
	{15, "Kurdish", 0x9BB531FF},
	{15, "Afghan", 0x8BA22CFF},
	{15, "Baloch", 0x7C9027FF},
	{16, "Ethiopian", 0x99A372FF},
	{16, "Somali", 0x8E9963FF},
	{16, "Nubian", 0x7F8959FF},
	{16, "Mande", 0x717A4FFF},
	{17, "Ashkenazi", 0xCE8EC7FF},
	{17, "Sephardi", 0xC272B9FF},
	{18, "Bengali", 0xD28570FF},
	{18, "Oriya", 0xCB7159FF},
	{18, "Assamese", 0xC35D41FF},
	{18, "Hindustani", 0xBC4929FF},
	{18, "Gujarati", 0xB53512FF},
	{18, "Panjabi", 0xA22F10FF},
	{18, "Rajput", 0x902A0EFF},
	{18, "Sindhi", 0x7E250CFF},
	{18, "Marathi", 0x6C1F0AFF},
	{18, "Sinhala", 0x5A1A09FF},
	{18, "Nepali", 0x481507FF},
	{19, "Tamil", 0xE5B142FF},
	{19, "Telugu", 0xE3A92DFF},
	{19, "Kannada", 0xCC9828FF},
	{20, "Bodpa", 0xEE8A32FF},
	{20, "Tangut", 0xED7E1CFF},
	{21, "Han", 0xD93B3BFF}
};

stock bool:Culture_IsValid(culture)
{
	return culture >= 0 && culture < CULTURE_COUNT;
}

stock bool:Culture_IsValidGroup(group)
{
	return group >= 0 && group < CULTURE_GROUP_COUNT;
}

stock Culture_GetGroup(culture)
{
	return Culture_IsValid(culture) ? s_Cultures[culture][E_CULTURE_GROUP] : 0;
}

stock Culture_GetName(culture,dest[],size = sizeof(dest))
{
	if (!Culture_IsValid(culture))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Cultures[culture][E_CULTURE_NAME],size);
}

stock Culture_GetColour(culture)
{
	return Culture_IsValid(culture) ? s_Cultures[culture][E_CULTURE_COLOUR] : LANGUAGE_COMMON_COLOUR;
}

stock Culture_GetGroupName(group,dest[],size = sizeof(dest))
{
	if (!Culture_IsValidGroup(group))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_CultureGroups[group][E_CULTURE_GROUP_NAME],size);
}

stock Culture_GetGroupColour(group)
{
	return Culture_IsValidGroup(group) ? s_CultureGroups[group][E_CULTURE_GROUP_COLOUR] : LANGUAGE_COMMON_COLOUR;
}

stock Culture_CountInGroup(group)
{
	new count = 0;

	for (new i = 0;i < CULTURE_COUNT;i++)
	{
		if (s_Cultures[i][E_CULTURE_GROUP] == group)
		{
			count++;
		}
	}

	return count;
}

stock Culture_GetFromGroup(group,index)
{
	for (new i = 0,seen = 0;i < CULTURE_COUNT;i++)
	{
		if (s_Cultures[i][E_CULTURE_GROUP] != group)
		{
			continue;
		}

		if (seen++ == index)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Language_IsValid(language)
{
	return language >= LANGUAGE_COMMON && language < LANGUAGE_COUNT;
}

stock Language_GetNative(culture)
{
	return Culture_GetGroup(culture) + 1;
}

stock Language_GetName(language,dest[],size = sizeof(dest))
{
	if (language == LANGUAGE_COMMON || !Language_IsValid(language))
	{
		strcopy(dest,"Common",size);
		return;
	}

	Culture_GetGroupName(language - 1,dest,size);
}

stock Language_GetColour(language)
{
	return (language == LANGUAGE_COMMON || !Language_IsValid(language)) ? LANGUAGE_COMMON_COLOUR : Culture_GetGroupColour(language - 1);
}
