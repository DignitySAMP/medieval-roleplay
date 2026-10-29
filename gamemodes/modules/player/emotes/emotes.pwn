enum E_EMOTE_STATE
{
	E_EM_EMOTE,
	E_EM_STEP,
	E_EM_TIMER,
	E_EM_FAVOURITES[EMOTE_FAVOURITES],
	bool:E_EM_LOADED,
}

static s_Emote[MAX_PLAYERS][E_EMOTE_STATE];

stock Emotes_Count()
{
	return sizeof(g_EmoteDefs);
}

stock bool:Emotes_IsValid(emote)
{
	return emote >= 0 && emote < sizeof(g_EmoteDefs);
}

stock Emotes_GetPlaying(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Emote[playerid][E_EM_EMOTE] : -1;
}

stock bool:Emotes_IsPlaying(playerid)
{
	return Emotes_GetPlaying(playerid) != -1;
}

stock Emotes_GetName(emote,dest[],size = sizeof(dest))
{
	if (Emotes_IsValid(emote))
	{
		strcopy(dest,g_EmoteDefs[emote][E_ED_NAME],size);
	}
	else
	{
		strcopy(dest,"?",size);
	}
}

stock Emotes_GetCommand(emote,dest[],size = sizeof(dest))
{
    dest[0] = EOS;

    if (Emotes_IsValid(emote))
    {
        strcopy(dest,g_EmoteDefs[emote][E_ED_COMMAND],size);
    }
}

stock Emotes_GetLabel(emote,dest[],size = sizeof(dest))
{
    dest[0] = EOS;

    if (Emotes_IsValid(emote))
    {
        new command[EMOTE_COMMAND_LEN];
        Emotes_GetCommand(emote,command);

        if (Emotes_GetCommandEntries(command) > 1)
        {
            format(dest,size,"%s (/%s %d)",g_EmoteDefs[emote][E_ED_NAME],command,Emotes_GetVariant(emote));
        }
        else
        {
            format(dest,size,"%s (/%s)",g_EmoteDefs[emote][E_ED_NAME],command);
        }
    }
}

stock Emotes_GetVariant(emote)
{
    return Emotes_IsValid(emote) ? g_EmoteDefs[emote][E_ED_VARIANT] : -1;
}

stock Emotes_GetCategory(emote)
{
    return Emotes_IsValid(emote) ? g_EmoteDefs[emote][E_ED_CAT] : -1;
}

stock Emotes_GetCategoryCount()
{
    return EMOTE_CAT_COUNT;
}

stock Emotes_GetCategoryName(category,dest[],size = sizeof(dest))
{
    dest[0] = EOS;

    if (category >= 0 && category < EMOTE_CAT_COUNT)
    {
        strcopy(dest,g_EmoteCategoryNames[category],size);
    }
}

stock bool:Emotes_GetStep(emote,step,data[E_EMOTE_STEP])
{
    if (!Emotes_IsValid(emote) || step < 0 || step >= g_EmoteDefs[emote][E_ED_STEPS])
    {
        return false;
    }

    new index = g_EmoteDefs[emote][E_ED_FIRST] + step;

    for (new field = 0;field < _:E_EMOTE_STEP;field++)
    {
        data[E_EMOTE_STEP:field] = g_EmoteSteps[index][E_EMOTE_STEP:field];
    }

    return true;
}

stock Emotes_FindCommand(const command[],variant)
{
    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        if (g_EmoteDefs[emote][E_ED_VARIANT] == variant && !strcmp(command,g_EmoteDefs[emote][E_ED_COMMAND],true))
        {
            return emote;
        }
    }

    return -1;
}

stock Emotes_GetCommandEntries(const command[])
{
    new count = 0;

    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        if (!strcmp(command,g_EmoteDefs[emote][E_ED_COMMAND],true))
        {
            count++;
        }
    }

    for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
    {
        if (!strcmp(command,g_EmotePairDefs[kind][E_EP_COMMAND],true))
        {
            count++;
        }
    }

    return count;
}

stock Emotes_GetCommandEntry(const command[],slot)
{
    if (slot < 0)
    {
        return -1;
    }

    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        if (!strcmp(command,g_EmoteDefs[emote][E_ED_COMMAND],true) && slot-- == 0)
        {
            return emote;
        }
    }

    for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
    {
        if (!strcmp(command,g_EmotePairDefs[kind][E_EP_COMMAND],true) && slot-- == 0)
        {
            return 5000 + kind;
        }
    }

    return -1;
}

stock Emotes_GetCommandMaximum(const command[])
{
    new maximum = 0;

    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        if (!strcmp(command,g_EmoteDefs[emote][E_ED_COMMAND],true))
        {
            maximum = max(maximum,g_EmoteDefs[emote][E_ED_VARIANT]);
        }
    }

    for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
    {
        if (!strcmp(command,g_EmotePairDefs[kind][E_EP_COMMAND],true))
        {
            maximum = max(maximum,g_EmotePairDefs[kind][E_EP_VARIANT]);
        }
    }

    return maximum;
}

stock bool:Emotes_HasVariant(const command[],variant)
{
    if (Emotes_FindCommand(command,variant) != -1)
    {
        return true;
    }

    for (new kind = 0;kind < EMOTE_PAIR_COUNT;kind++)
    {
        if (g_EmotePairDefs[kind][E_EP_VARIANT] == variant && !strcmp(command,g_EmotePairDefs[kind][E_EP_COMMAND],true))
        {
            return true;
        }
    }

    return false;
}

stock Emotes_FormatVariants(const command[],dest[],size = sizeof(dest))
{
    dest[0] = EOS;
    new maximum = Emotes_GetCommandMaximum(command);

    for (new variant = 1;variant <= maximum;variant++)
    {
        if (!Emotes_HasVariant(command,variant))
        {
            continue;
        }

        new first = variant;

        while (variant < maximum && Emotes_HasVariant(command,variant + 1))
        {
            variant++;
        }

        if (dest[0] != EOS)
        {
            strcat(dest,",",size);
        }

        if (first == variant)
        {
            strcat(dest,sprintf("%d",first),size);
        }
        else
        {
            strcat(dest,sprintf("%d-%d",first,variant),size);
        }
    }
}

stock Emotes_GetCategoryEntry(category,slot)
{
    if (category < 0 || category >= EMOTE_CAT_COUNT || slot < 0)
    {
        return -1;
    }

    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        if (g_EmoteDefs[emote][E_ED_CAT] != category)
        {
            continue;
        }

        new bool:isFirst = true;

        for (new other = 0;other < emote;other++)
        {
            if (g_EmoteDefs[other][E_ED_CAT] == category && !strcmp(g_EmoteDefs[other][E_ED_COMMAND],g_EmoteDefs[emote][E_ED_COMMAND]))
            {
                isFirst = false;
                break;
            }
        }

        if (isFirst && slot-- == 0)
        {
            return emote;
        }
    }

    return -1;
}

stock Emotes_GetCategoryEntries(category)
{
    new count = 0;

    for (new emote = 0;emote < Emotes_Count();emote++)
    {
        if (g_EmoteDefs[emote][E_ED_CAT] != category)
        {
            continue;
        }

        new bool:isFirst = true;

        for (new other = 0;other < emote;other++)
        {
            if (g_EmoteDefs[other][E_ED_CAT] == category && !strcmp(g_EmoteDefs[other][E_ED_COMMAND],g_EmoteDefs[emote][E_ED_COMMAND]))
            {
                isFirst = false;
                break;
            }
        }

        if (isFirst)
        {
            count++;
        }
    }

    return count;
}

stock Emotes_GetGroupLabel(emote,dest[],size = sizeof(dest))
{
    dest[0] = EOS;

    if (!Emotes_IsValid(emote))
    {
        return;
    }

    new name[EMOTE_NAME_LEN], command[EMOTE_COMMAND_LEN], variants[EMOTE_VARIANTS_LEN];
    Emotes_GetName(emote,name);
    Emotes_GetCommand(emote,command);

    for (new other = 0;other < Emotes_Count();other++)
    {
        if (g_EmoteDefs[other][E_ED_IMPORTED] && !strcmp(command,g_EmoteDefs[other][E_ED_COMMAND]))
        {
            Emotes_GetName(other,name);
            new suffix[8];
            format(suffix,sizeof(suffix)," %d",Emotes_GetVariant(other));
            new position = strfind(name,suffix);

            if (position != -1)
            {
                name[position] = EOS;
            }

            break;
        }
    }

    if (Emotes_GetCommandEntries(command) > 1)
    {
        Emotes_FormatVariants(command,variants);
        format(dest,size,"%s (/%s %s)",name,command,variants);
    }
    else
    {
        format(dest,size,"%s (/%s)",name,command);
    }
}

stock bool:Emotes_CanAct(playerid)
{
    return Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !Mount_IsRiding(playerid) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT && !Character_IsBusy(playerid) && Carts_GetSeat(playerid) == -1 && Carts_GetOfPlayer(playerid) == -1;
}

stock bool:Emotes_StopAll(playerid)
{
    if (!Emotes_CanAct(playerid))
    {
        return false;
    }

    Emotes_Stop(playerid);
    Emotes_EndPair(playerid);
    Emotes_Decline(playerid);
    return true;
}

static Emotes_KillTimer(playerid)
{
	if (s_Emote[playerid][E_EM_TIMER] != 0)
	{
		KillTimer(s_Emote[playerid][E_EM_TIMER]);
		s_Emote[playerid][E_EM_TIMER] = 0;
	}
}

static Emotes_PlayStep(playerid)
{
	new emote = s_Emote[playerid][E_EM_EMOTE], step = s_Emote[playerid][E_EM_STEP];

	if (!Emotes_IsValid(emote) || step >= g_EmoteDefs[emote][E_ED_STEPS])
	{
		Emotes_Stop(playerid,false);
		return;
	}

	new index = g_EmoteDefs[emote][E_ED_FIRST] + step, ms = g_EmoteSteps[index][E_ES_MS];
	if (g_EmoteSteps[index][E_ES_SPECIAL] != SPECIAL_ACTION_NONE)
    {
        SetPlayerSpecialAction(playerid,g_EmoteSteps[index][E_ES_SPECIAL]);
    }
    else
    {
        ApplyAnimation(playerid,g_EmoteSteps[index][E_ES_LIB],g_EmoteSteps[index][E_ES_ANIM],g_EmoteSteps[index][E_ES_SPEED],g_EmoteSteps[index][E_ES_LOOP],g_EmoteSteps[index][E_ES_LOCK_X],g_EmoteSteps[index][E_ES_LOCK_Y],g_EmoteSteps[index][E_ES_FREEZE],g_EmoteSteps[index][E_ES_TIME],g_EmoteSteps[index][E_ES_SYNC]);
    }

	if (ms > 0)
	{
		s_Emote[playerid][E_EM_TIMER] = SetTimerEx("Emotes_NextStep",ms,false,"dd",playerid,emote);
	}
}

stock bool:Emotes_Play(playerid,emote)
{
	if (!Emotes_IsValid(emote) || !Session_IsPlaying(playerid) || Mount_IsRiding(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || Character_IsBusy(playerid) || Carts_GetSeat(playerid) != -1 || Carts_GetOfPlayer(playerid) != -1)
	{
		return false;
	}

    if (Emotes_IsPlaying(playerid))
    {
        new current = s_Emote[playerid][E_EM_EMOTE], step = g_EmoteDefs[current][E_ED_FIRST] + min(s_Emote[playerid][E_EM_STEP],g_EmoteDefs[current][E_ED_STEPS] - 1);

        if (g_EmoteSteps[step][E_ES_SPECIAL] != SPECIAL_ACTION_NONE)
        {
            SetPlayerSpecialAction(playerid,SPECIAL_ACTION_NONE);
        }
    }

	Emotes_KillTimer(playerid);
	s_Emote[playerid][E_EM_EMOTE] = emote;
	s_Emote[playerid][E_EM_STEP] = 0;
	Emotes_PlayStep(playerid);
	pawn_call_public("Emotes_OnPlay","dd",playerid,emote);
	return true;
}

stock Emotes_Stop(playerid,bool:clear = true)
{
	if (!Util_IsValidPlayer(playerid) || s_Emote[playerid][E_EM_EMOTE] == -1)
	{
		return;
	}

    new emote = s_Emote[playerid][E_EM_EMOTE], step = g_EmoteDefs[emote][E_ED_FIRST] + min(s_Emote[playerid][E_EM_STEP],g_EmoteDefs[emote][E_ED_STEPS] - 1);

    if (step < sizeof(g_EmoteSteps) && g_EmoteSteps[step][E_ES_SPECIAL] != SPECIAL_ACTION_NONE)
    {
        SetPlayerSpecialAction(playerid,SPECIAL_ACTION_NONE);
    }

	Emotes_KillTimer(playerid);
	s_Emote[playerid][E_EM_EMOTE] = -1;

	if (clear)
	{
		ClearAnimations(playerid,SYNC_ALL);
	}

	pawn_call_public("Emotes_OnStop","d",playerid);
}

stock Emotes_GetFavourite(playerid,slot)
{
	return Util_IsValidPlayer(playerid) && slot >= 0 && slot < EMOTE_FAVOURITES ? s_Emote[playerid][E_EM_FAVOURITES][slot] : -1;
}

stock bool:Emotes_IsFavourite(playerid,emote)
{
	for (new slot = 0;slot < EMOTE_FAVOURITES;slot++)
	{
		if (s_Emote[playerid][E_EM_FAVOURITES][slot] == emote)
		{
			return true;
		}
	}

	return false;
}

stock bool:Emotes_ToggleFavourite(playerid,emote)
{
	new characterid = Character_GetId(playerid);

	if (!Emotes_IsValid(emote) || characterid <= 0)
	{
		return false;
	}

	for (new slot = 0;slot < EMOTE_FAVOURITES;slot++)
	{
		if (s_Emote[playerid][E_EM_FAVOURITES][slot] == emote)
		{
			s_Emote[playerid][E_EM_FAVOURITES][slot] = -1;
			mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_emote_slots WHERE character_id = %d AND slot = %d",characterid,slot));
			return true;
		}
	}

	for (new slot = 0;slot < EMOTE_FAVOURITES;slot++)
	{
		if (s_Emote[playerid][E_EM_FAVOURITES][slot] == -1)
		{
			s_Emote[playerid][E_EM_FAVOURITES][slot] = emote;
			mysql_tquery_s(g_Mysql,str_format("REPLACE INTO character_emote_slots (character_id, slot, emote) VALUES (%d, %d, %d)",characterid,slot,emote));
			return true;
		}
	}

	return false;
}

forward Task:Emotes_LoadFavourites(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Emotes_LoadFavourites(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT slot, emote FROM character_emote_slots WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new slot = 0;slot < EMOTE_FAVOURITES;slot++)
	{
		s_Emote[playerid][E_EM_FAVOURITES][slot] = -1;
	}

	new rows = cache_num_rows();

	for (new r = 0;r < rows;r++)
	{
		new slot, emote;
		cache_get_value_name_int(r,"slot",slot);
		cache_get_value_name_int(r,"emote",emote);

		if (slot >= 0 && slot < EMOTE_FAVOURITES && Emotes_IsValid(emote))
		{
			s_Emote[playerid][E_EM_FAVOURITES][slot] = emote;
		}
	}

	s_Emote[playerid][E_EM_LOADED] = true;
	return async rows;
}
#pragma warning pop

stock Emotes_OpenPanel(playerid,category = -1,bool:pinMode = false)
{
    new page = 0, selected = -1;

    while (Session_IsPlaying(playerid))
    {
        new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, rows = 0, title[EMOTE_LABEL_LEN] = "Emotes";
        new entries[COMMANDS_MAX_DESCRIBED], count = 0, command[EMOTE_COMMAND_LEN];

        if (selected != -1)
        {
            Emotes_GetCommand(selected,command);
            format(title,sizeof(title),"/%s",command);

            for (new slot = 0;slot < Emotes_GetCommandEntries(command);slot++)
            {
                entries[count++] = Emotes_GetCommandEntry(command,slot);
            }
        }
        else if (category != -1)
        {
            Emotes_GetCategoryName(category,title);
            entries[count++] = 4000;

            new entryCount = Emotes_GetCategoryEntries(category);

            for (new slot = 0;slot < entryCount;slot++)
            {
                entries[count++] = Emotes_GetCategoryEntry(category,slot);
            }
        }
        else
        {
            for (new slot = 0;slot < EMOTE_FAVOURITES;slot++)
            {
                new emote = Emotes_GetFavourite(playerid,slot);

                if (Emotes_IsValid(emote))
                {
                    entries[count++] = emote;
                }
            }

            for (new cat = 0;cat < EMOTE_CAT_COUNT;cat++)
            {
                entries[count++] = 1000 + cat;
            }

            entries[count++] = 2000;

            if (Emotes_IsPlaying(playerid) || Emotes_GetPartner(playerid) != INVALID_PLAYER_ID)
            {
                entries[count++] = 3000;
            }
        }

        if (pinMode)
        {
            strcat(title," (pick to pin)");
        }

        page = min(page,(count - 1) / EMOTE_PANEL_ROWS);
        Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
        Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,340.0,KIT_ROW * float(EMOTE_PANEL_ROWS) + 6.0 + KIT_ROW + 12.0,title,x,y,width);

        for (new slot = page * EMOTE_PANEL_ROWS;slot < count && rows < EMOTE_PANEL_ROWS;slot++)
        {
            new entry = entries[slot], label[EMOTE_LABEL_LEN], colour = KIT_COLOUR_TEXT;

            if (entry >= 1000 && entry < 1000 + EMOTE_CAT_COUNT)
            {
                Emotes_GetCategoryName(entry - 1000,label);
            }
            else if (entry == 2000)
            {
                strcopy(label,"With someone else");
                colour = KIT_COLOUR_GOOD;
            }
            else if (entry == 3000)
            {
                strcopy(label,"Stop");
                colour = KIT_COLOUR_BAD;
            }
            else if (entry == 4000)
            {
                strcopy(label,pinMode ? ("Done pinning") : ("Pin favourites"));
                colour = KIT_COLOUR_GOOD;
            }
            else if (entry >= 5000 && entry < 5000 + EMOTE_PAIR_COUNT)
            {
                Emotes_GetPairLabel(entry - 5000,label);
            }
            else
            {
                if (category != -1 && selected == -1)
                {
                    Emotes_GetGroupLabel(entry,label);
                }
                else
                {
                    Emotes_GetLabel(entry,label);
                }

                if (Emotes_IsFavourite(playerid,entry))
                {
                    colour = KIT_COLOUR_ACCENT;
                }
            }

            Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,label,entry,colour);
        }

        new Float:footerY = y + KIT_ROW * float(EMOTE_PANEL_ROWS) + 8.0;
        Kit_AddButton(playerid,x + width / 2.0 - 35.0,footerY,70.0,GUI_BUTTON_BACK,KIT_BACK);

        if (page > 0)
        {
            Kit_AddButton(playerid,x,footerY,70.0,"Previous",6000);
        }

        if ((page + 1) * EMOTE_PANEL_ROWS < count)
        {
            Kit_AddButton(playerid,x + width - 70.0,footerY,70.0,"Next",6001);
        }

        new pick = await Kit_Present(playerid);
        Kit_Close(playerid);

        if (!Gui_IsFlowCurrent(playerid,epoch))
        {
            return;
        }

        if (pick == 6000 || pick == 6001)
        {
            page += pick == 6000 ? -1 : 1;
            continue;
        }

        if (pick == KIT_BACK)
        {
            if (selected != -1)
            {
                selected = -1;
            }
            else if (category != -1)
            {
                category = -1;
                pinMode = false;
            }
            else
            {
                return;
            }

            page = 0;
            continue;
        }

        if (pick >= 1000 && pick < 1000 + EMOTE_CAT_COUNT)
        {
            category = pick - 1000;
            page = 0;
            continue;
        }

        if (pick == 2000)
        {
            Emotes_OpenPairs(playerid);
            return;
        }

        if (pick == 3000)
        {
            Emotes_StopAll(playerid);
            return;
        }

        if (pick == 4000)
        {
            pinMode = !pinMode;
            continue;
        }

        if (pick >= 5000 && pick < 5000 + EMOTE_PAIR_COUNT)
        {
            new kind = pick - 5000;
            Emotes_RunCommand(playerid,g_EmotePairDefs[kind][E_EP_COMMAND],g_EmotePairDefs[kind][E_EP_VARIANT]);
            return;
        }

        if (!Emotes_IsValid(pick))
        {
            return;
        }

        Emotes_GetCommand(pick,command);

        if (category != -1 && selected == -1 && Emotes_GetCommandEntries(command) > 1)
        {
            selected = pick;
            page = 0;
            continue;
        }

        if (pinMode)
        {
            if (!Emotes_ToggleFavourite(playerid,pick))
            {
                Gui_Notify(playerid,"Your quick slots are full. Unpin one first.");
            }

            continue;
        }

        Emotes_RunCommand(playerid,command,Emotes_GetVariant(pick));
        return;
    }
}

forward Emotes_OnPlay(playerid,emote);

public Emotes_OnPlay(playerid,emote)
{
	return 1;
}

forward Emotes_OnStop(playerid);

public Emotes_OnStop(playerid)
{
	return 1;
}

forward Emotes_NextStep(playerid,emote);

public Emotes_NextStep(playerid,emote)
{
	s_Emote[playerid][E_EM_TIMER] = 0;

	if (!IsPlayerConnected(playerid) || s_Emote[playerid][E_EM_EMOTE] != emote)
	{
		return 1;
	}

	s_Emote[playerid][E_EM_STEP]++;
	Emotes_PlayStep(playerid);
	return 1;
}

forward Emotes_PanelDeferred(playerid);

stock bool:Emotes_CanOpen(playerid)
{
	return Emotes_CanAct(playerid) && Emotes_GetAskedBy(playerid) == INVALID_PLAYER_ID && Emotes_GetPartner(playerid) == INVALID_PLAYER_ID;
}

stock bool:Emotes_Open(playerid)
{
	if (!Emotes_CanOpen(playerid))
	{
		return false;
	}

	SetTimerEx("Emotes_PanelDeferred",0,false,"d",playerid);
	return true;
}

public Emotes_PanelDeferred(playerid)
{
	if (Emotes_CanOpen(playerid))
	{
		Emotes_OpenPanel(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Emote[playerid][E_EM_EMOTE] = -1;
	s_Emote[playerid][E_EM_STEP] = 0;
	s_Emote[playerid][E_EM_TIMER] = 0;
	s_Emote[playerid][E_EM_LOADED] = false;

	for (new slot = 0;slot < EMOTE_FAVOURITES;slot++)
	{
		s_Emote[playerid][E_EM_FAVOURITES][slot] = -1;
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason
	Emotes_KillTimer(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	Emotes_LoadFavourites(playerid,characterid);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	if ((newkeys & KEY_NO) && (newkeys & KEY_WALK) && !((oldkeys & KEY_NO) && (oldkeys & KEY_WALK)) && !Gui_IsBusy(playerid) && Emotes_GetAskedBy(playerid) == INVALID_PLAYER_ID && Emotes_GetPartner(playerid) == INVALID_PLAYER_ID)
	{
		if (Emotes_IsPlaying(playerid))
		{
			Emotes_Stop(playerid);
			return;
		}

		Emotes_Open(playerid);
	}
}

hook OnPlayerUpdate(playerid)
{
	if (s_Emote[playerid][E_EM_EMOTE] == -1)
	{
		return;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);

	if (updown != 0 || leftright != 0 || (keys & KEY_JUMP) || (keys & KEY_SPRINT))
	{
		Emotes_Stop(playerid);
	}
}
