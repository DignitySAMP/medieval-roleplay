#define COMMANDS_MAX_DESCRIBED (384)
#define COMMANDS_NAME_LEN (32)
#define COMMANDS_TEXT_LEN (128)
#define COMMANDS_CATEGORY_LEN (24)
#define COMMANDS_CATEGORY_STAFF "Staff tools"
#define COMMANDS_CATEGORY_OTHER "Other"
#define COMMAND_COLOUR_HINT (0xC8C8C8FF)

#define COMMAND_REPLY_NOT_LOGGED_IN "You must be logged in to use commands."
#define COMMAND_REPLY_NOT_SPAWNED "You can use that once you've spawned."
#define COMMAND_REPLY_NOT_ONLINE "That player isn't online."
#define COMMAND_REPLY_UNKNOWN "There's no /%s. Type /help to find a command, or /help and a word, like /help whisper."
#define COMMAND_REPLY_DID_YOU_MEAN "There's no /%s. Did you mean %s?"
#define COMMAND_REPLY_HELP "Type /help to browse answers and commands, or /help and a word to search, like /help whisper."
#define COMMAND_REPLY_NOTHING_FOUND "Nothing in the help matches \"%s\". Type /help on its own to browse it."

enum E_COMMAND_INFO
{
	E_COMMAND_INFO_NAME[COMMANDS_NAME_LEN],
	E_COMMAND_INFO_TEXT[COMMANDS_TEXT_LEN],
	E_COMMAND_INFO_GATE[COMMANDS_NAME_LEN],
	E_COMMAND_INFO_CATEGORY[COMMANDS_CATEGORY_LEN],
}

new g_CommandInfo[COMMANDS_MAX_DESCRIBED][E_COMMAND_INFO];
new g_CommandInfoCount;

stock bool:Command_Describe(const name[],const text[],const gatePublic[] = "",const category[] = "")
{
	if (g_CommandInfoCount >= COMMANDS_MAX_DESCRIBED)
	{
		Log_Error("commands","description table full - '%s' not described",name);
		return false;
	}

	strcopy(g_CommandInfo[g_CommandInfoCount][E_COMMAND_INFO_NAME],name,COMMANDS_NAME_LEN);
	strcopy(g_CommandInfo[g_CommandInfoCount][E_COMMAND_INFO_TEXT],text,COMMANDS_TEXT_LEN);
	strcopy(g_CommandInfo[g_CommandInfoCount][E_COMMAND_INFO_GATE],gatePublic,COMMANDS_NAME_LEN);

	if (category[0] != EOS)
	{
		strcopy(g_CommandInfo[g_CommandInfoCount][E_COMMAND_INFO_CATEGORY],category,COMMANDS_CATEGORY_LEN);
	}
	else if (!strcmp(text,"Staff",false,5) || !strcmp(text,"Dev:",false,4))
	{
		strcopy(g_CommandInfo[g_CommandInfoCount][E_COMMAND_INFO_CATEGORY],COMMANDS_CATEGORY_STAFF,COMMANDS_CATEGORY_LEN);
	}
	else
	{
		strcopy(g_CommandInfo[g_CommandInfoCount][E_COMMAND_INFO_CATEGORY],COMMANDS_CATEGORY_OTHER,COMMANDS_CATEGORY_LEN);
	}

	g_CommandInfoCount++;
	return true;
}

stock bool:Command_GetDescription(const name[],dest[],size = sizeof(dest))
{
	for (new i = 0;i < g_CommandInfoCount;i++)
	{
		if (!strcmp(g_CommandInfo[i][E_COMMAND_INFO_NAME],name,true))
		{
			strcopy(dest,g_CommandInfo[i][E_COMMAND_INFO_TEXT],size);
			return true;
		}
	}

	dest[0] = EOS;
	return false;
}

stock bool:Command_GetCategory(const name[],dest[],size = sizeof(dest))
{
	for (new i = 0;i < g_CommandInfoCount;i++)
	{
		if (!strcmp(g_CommandInfo[i][E_COMMAND_INFO_NAME],name,true))
		{
			strcopy(dest,g_CommandInfo[i][E_COMMAND_INFO_CATEGORY],size);
			return true;
		}
	}

	strcopy(dest,COMMANDS_CATEGORY_OTHER,size);
	return false;
}

stock bool:Command_PassesGate(playerid,const name[])
{
	for (new i = 0;i < g_CommandInfoCount;i++)
	{
		if (!strcmp(g_CommandInfo[i][E_COMMAND_INFO_NAME],name,true))
		{
			return g_CommandInfo[i][E_COMMAND_INFO_GATE][0] == EOS || (playerid != INVALID_PLAYER_ID && CallLocalFunction(g_CommandInfo[i][E_COMMAND_INFO_GATE],"d",playerid) != 0);
		}
	}

	return true;
}

stock Command_Usage(playerid,cmdid,const syntax[])
{
	new name[COMMANDS_NAME_LEN], text[COMMANDS_TEXT_LEN];
	GetCommandName(cmdid,name);
	SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf("Usage: /%s %s",name,syntax));

	if (Command_GetDescription(name,text))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,text);
	}

	return 1;
}
