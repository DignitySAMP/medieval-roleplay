static s_LanguageSpoken[MAX_PLAYERS];

stock Language_GetSpoken(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_LanguageSpoken[playerid] : LANGUAGE_COMMON;
}

stock bool:Language_SetSpoken(playerid,language)
{
	if (!Util_IsValidPlayer(playerid) || !Language_IsKnown(playerid,language))
	{
		return false;
	}

	s_LanguageSpoken[playerid] = language;
	return true;
}

stock bool:Language_IsKnown(playerid,language)
{
	return language == LANGUAGE_COMMON || (Session_HasCharacter(playerid) && language == Language_GetNative(Character_GetCulture(playerid)));
}

static bool:Language_IsLetter(character)
{
	return (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z');
}

stock Language_Scramble(const text[],dest[],size = sizeof(dest))
{
	strcopy(dest,text,size);

	new length = strlen(dest), start = 0;

	while (start < length)
	{
		while (start < length && !Language_IsLetter(dest[start]))
		{
			start++;
		}

		new finish = start;

		while (finish < length && Language_IsLetter(dest[finish]))
		{
			finish++;
		}

		for (new i = finish - 1;i > start;i--)
		{
			new j = start + random(i - start + 1), letter = dest[i];
			dest[i] = dest[j];
			dest[j] = letter;
		}

		start = finish;
	}
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LanguageSpoken[playerid] = LANGUAGE_COMMON;
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	s_LanguageSpoken[playerid] = LANGUAGE_COMMON;
}

CMD<ADMIN_LEVEL_NONE>:language(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	SetTimerEx("CultureGui_LanguageDeferred",0,false,"d",playerid);
	return 1;
}
