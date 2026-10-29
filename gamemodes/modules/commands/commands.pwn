#define COMMANDS_SUGGEST_MAX (3)
#define COMMANDS_SUGGEST_LEN (64)

stock bool:Commands_CanUse(playerid,level,cmdid)
{
	if (cmdid < 0 || cmdid >= GetTotalCommandCount() || !IsCommandEnabled(cmdid))
	{
		return false;
	}

	if (GetCommandFlags(cmdid) > ADMIN_LEVEL_NONE && level < GetCommandFlags(cmdid))
	{
		return false;
	}

	new name[COMMANDS_NAME_LEN];
	GetCommandName(cmdid,name);
	return Command_PassesGate(playerid,name);
}

static Commands_Distance(const a[],const b[])
{
	new lengthA = strlen(a), lengthB = strlen(b), previous[COMMANDS_NAME_LEN + 1], current[COMMANDS_NAME_LEN + 1];

	if (lengthA >= COMMANDS_NAME_LEN || lengthB >= COMMANDS_NAME_LEN)
	{
		return cellmax;
	}

	for (new j = 0;j <= lengthB;j++)
	{
		previous[j] = j;
	}

	for (new i = 1;i <= lengthA;i++)
	{
		current[0] = i;

		for (new j = 1;j <= lengthB;j++)
		{
			current[j] = min(min(previous[j] + 1,current[j - 1] + 1),previous[j - 1] + (tolower(a[i - 1]) == tolower(b[j - 1]) ? 0 : 1));
		}

		for (new j = 0;j <= lengthB;j++)
		{
			previous[j] = current[j];
		}
	}

	return previous[lengthB];
}

stock Commands_Suggest(playerid,level,const typed[],dest[],size = sizeof(dest))
{
	new found[COMMANDS_SUGGEST_MAX], scores[COMMANDS_SUGGEST_MAX], count = 0, name[COMMANDS_NAME_LEN], length = strlen(typed), limit = length <= 2 ? 0 : (length <= 4 ? 1 : 2);
	dest[0] = EOS;

	for (new cmdid = 0, total = GetTotalCommandCount();cmdid < total;cmdid++)
	{
		if (!Commands_CanUse(playerid,level,cmdid))
		{
			continue;
		}

		GetCommandName(cmdid,name);
		new bool:isPrefix = length >= 2 && strfind(name,typed,true) == 0, distance = Commands_Distance(typed,name);

		if (!isPrefix && distance > limit)
		{
			continue;
		}

		new score = isPrefix ? min(distance,1) : distance, slot = count;

		while (slot > 0 && scores[slot - 1] > score)
		{
			if (slot < COMMANDS_SUGGEST_MAX)
			{
				found[slot] = found[slot - 1];
				scores[slot] = scores[slot - 1];
			}

			slot--;
		}

		if (slot < COMMANDS_SUGGEST_MAX)
		{
			found[slot] = cmdid;
			scores[slot] = score;
			count = min(count + 1,COMMANDS_SUGGEST_MAX);
		}
	}

	for (new i = 0;i < count;i++)
	{
		GetCommandName(found[i],name);
		format(dest,size,"%s%s/%s",dest,i == 0 ? ("") : (i == count - 1 ? (" or ") : (", ")),name);
	}

	return count;
}

stock Commands_Find(playerid,level,const query[],results[],size = sizeof(results))
{
	new count = 0, name[COMMANDS_NAME_LEN], text[COMMANDS_TEXT_LEN];

	for (new cmdid = 0, total = GetTotalCommandCount();cmdid < total && count < size;cmdid++)
	{
		if (!Commands_CanUse(playerid,level,cmdid))
		{
			continue;
		}

		GetCommandName(cmdid,name);
		Command_GetDescription(name,text);

		if (query[0] != EOS && strfind(name,query,true) == -1 && strfind(text,query,true) == -1)
		{
			continue;
		}

		new slot = count++;

		while (slot > 0)
		{
			new other[COMMANDS_NAME_LEN];
			GetCommandName(results[slot - 1],other);

			if (strcmp(other,name) <= 0)
			{
				break;
			}

			results[slot] = results[slot - 1];
			slot--;
		}

		results[slot] = cmdid;
	}

	return count;
}

stock Commands_ReplyUnknown(playerid,const cmdtext[])
{
	new typed[COMMANDS_NAME_LEN], length = 0;

	for (new i = cmdtext[0] == '/' ? 1 : 0;cmdtext[i] > ' ' && length < COMMANDS_NAME_LEN - 1;i++)
	{
		typed[length++] = tolower(cmdtext[i]);
	}

	typed[length] = EOS;

	if (!strcmp(typed,"commands") || !strcmp(typed,"cmds"))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,COMMAND_REPLY_HELP);
		return;
	}

	new suggestions[COMMANDS_SUGGEST_LEN];

	if (length > 0 && Commands_Suggest(playerid,Account_GetAdminLevel(playerid),typed,suggestions) > 0)
	{
		SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf(COMMAND_REPLY_DID_YOU_MEAN,typed,suggestions));
		return;
	}

	SendClientMessage(playerid,COMMAND_COLOUR_HINT,sprintf(COMMAND_REPLY_UNKNOWN,typed));
}

public OnPlayerCommandReceived(cmdid, playerid, cmdtext[])
{
	if (IsPlayerNPC(playerid))
	{
		return 0;
	}

	Session_MarkActive(playerid);

	if (!Session_IsAuthenticated(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,COMMAND_REPLY_NOT_LOGGED_IN);
		return 0;
	}

	if (cmdid == INVALID_COMMAND_ID || !Commands_CanUse(playerid,Account_GetAdminLevel(playerid),cmdid))
	{
		Commands_ReplyUnknown(playerid,cmdtext);
		return 0;
	}

	return 1;
}

public OnPlayerCommandPerformed(cmdid, playerid, cmdtext[], success)
{
	if (cmdid == INVALID_COMMAND_ID)
	{
		return 1;
	}

	return success;
}
