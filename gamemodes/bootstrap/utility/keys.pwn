#define KEYS_HOLD_MS (500)
#define KEYS_MAX_CONTEXTS (192)
#define KEYS_CHECK_LEN (32)

#define KEYS_PRIO_AMBIENT (0)
#define KEYS_PRIO_WORLD (10)
#define KEYS_PRIO_ACTION (20)
#define KEYS_PRIO_MENU (30)
#define KEYS_PRIO_SCENE (40)

#define KEYS_MAX_CHORDS (8)

enum E_KEY_CONTEXT
{
	KEY:E_KEY_CONTEXT_KEY,
	E_KEY_CONTEXT_PRIORITY,
	E_KEY_CONTEXT_CHECK[KEYS_CHECK_LEN],
}

enum E_KEY_CHORD
{
	KEY:E_KEY_CHORD_FIRST_KEY,
	KEY:E_KEY_CHORD_SECOND_KEY,
	E_KEY_CHORD_PRIORITY,
	E_KEY_CHORD_CHECK[KEYS_CHECK_LEN],
}

new g_KeyContexts[KEYS_MAX_CONTEXTS][E_KEY_CONTEXT];
new g_KeyContextCount;
new g_KeyChords[KEYS_MAX_CHORDS][E_KEY_CHORD];
new g_KeyChordCount;

stock bool:Keys_RegisterContext(KEY:key, priority, const checkPublic[])
{
	if (g_KeyContextCount >= KEYS_MAX_CONTEXTS)
	{
		Log_Error("keys","context table full - '%s' not registered",checkPublic);
		return false;
	}

	g_KeyContexts[g_KeyContextCount][E_KEY_CONTEXT_KEY] = key;
	g_KeyContexts[g_KeyContextCount][E_KEY_CONTEXT_PRIORITY] = priority;
	format(g_KeyContexts[g_KeyContextCount][E_KEY_CONTEXT_CHECK],KEYS_CHECK_LEN,"%s",checkPublic);
	g_KeyContextCount++;

	return true;
}

stock bool:Keys_RegisterChord(KEY:firstKey, KEY:secondKey, priority, const checkPublic[])
{
	if (g_KeyChordCount >= KEYS_MAX_CHORDS)
	{
		Log_Error("keys","chord table full - '%s' not registered",checkPublic);
		return false;
	}

	g_KeyChords[g_KeyChordCount][E_KEY_CHORD_FIRST_KEY] = firstKey;
	g_KeyChords[g_KeyChordCount][E_KEY_CHORD_SECOND_KEY] = secondKey;
	g_KeyChords[g_KeyChordCount][E_KEY_CHORD_PRIORITY] = priority;
	format(g_KeyChords[g_KeyChordCount][E_KEY_CHORD_CHECK],KEYS_CHECK_LEN,"%s",checkPublic);
	g_KeyChordCount++;

	return true;
}

stock bool:Keys_IsChord(KEY:newkeys, KEY:oldkeys, KEY:firstKey, KEY:secondKey)
{
	return ((newkeys & firstKey) && (newkeys & secondKey) && !((oldkeys & firstKey) && (oldkeys & secondKey)));
}

stock bool:Keys_IsBusy(playerid, KEY:key, abovePriority = KEYS_PRIO_AMBIENT)
{
	for (new i = 0;i < g_KeyContextCount;i++)
	{
		if (g_KeyContexts[i][E_KEY_CONTEXT_KEY] != key || g_KeyContexts[i][E_KEY_CONTEXT_PRIORITY] <= abovePriority)
		{
			continue;
		}

		if (pawn_call_public(g_KeyContexts[i][E_KEY_CONTEXT_CHECK],"d",playerid))
		{
			return true;
		}
	}

	for (new i = 0;i < g_KeyChordCount;i++)
	{
		if (g_KeyChords[i][E_KEY_CHORD_PRIORITY] <= abovePriority)
		{
			continue;
		}

		new KEY:other;

		if (g_KeyChords[i][E_KEY_CHORD_FIRST_KEY] == key)
		{
			other = g_KeyChords[i][E_KEY_CHORD_SECOND_KEY];
		}
		else if (g_KeyChords[i][E_KEY_CHORD_SECOND_KEY] == key)
		{
			other = g_KeyChords[i][E_KEY_CHORD_FIRST_KEY];
		}
		else
		{
			continue;
		}

		new KEY:keys, updown, leftright;
		GetPlayerKeys(playerid,keys,updown,leftright);

		if (!(keys & other))
		{
			continue;
		}

		if (pawn_call_public(g_KeyChords[i][E_KEY_CHORD_CHECK],"d",playerid))
		{
			return true;
		}
	}

	return false;
}
