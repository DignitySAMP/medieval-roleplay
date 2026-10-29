enum E_NOTICE
{
	bool:E_NOTICE_USED,
	E_NOTICE_ID,
	E_NOTICE_TAB:E_NOTICE_TAB_ID,
	E_NOTICE_AUTHOR,
	E_NOTICE_TITLE[NOTICES_TITLE_LEN],
	E_NOTICE_TEXT[NOTICES_TEXT_LEN],
	E_NOTICE_STARTS,
	E_NOTICE_EXPIRES,
	E_NOTICE_CRIED,
}

static s_Notices[NOTICES_MAX][E_NOTICE];
static s_NoticeQueue[NOTICES_MAX];
static s_NoticeQueueCount;
static STREAMER_TAG_OBJECT:s_NoticeBoards[sizeof(g_NoticeBoardDefs)];
static STREAMER_TAG_3D_TEXT_LABEL:s_NoticeBoardLabels[sizeof(g_NoticeBoardDefs)];
static bool:s_NoticeBoardPosted[sizeof(g_NoticeBoardDefs)];
static s_NoticeCrier = -1;

stock Notices_Count(E_NOTICE_TAB:tab = NOTICE_TAB_COUNT)
{
	new count = 0, now = gettime();

	for (new i = 0;i < NOTICES_MAX;i++)
	{
		if (s_Notices[i][E_NOTICE_USED] && s_Notices[i][E_NOTICE_EXPIRES] > now && (tab == NOTICE_TAB_COUNT || s_Notices[i][E_NOTICE_TAB_ID] == tab))
		{
			count++;
		}
	}

	return count;
}

stock Notices_CountOnBoard()
{
	new count = 0;

	for (new E_NOTICE_TAB:tab = NOTICE_TAB_REALM;tab < NOTICE_TAB_COUNT;tab++)
	{
		if (tab != NOTICE_TAB_WORK)
		{
			count += Notices_Count(tab);
		}
	}

	return count;
}

stock Notices_FindSlot(id)
{
	for (new i = 0;i < NOTICES_MAX;i++)
	{
		if (s_Notices[i][E_NOTICE_USED] && s_Notices[i][E_NOTICE_ID] == id)
		{
			return i;
		}
	}

	return -1;
}

stock Notices_FindSlotPublic(id)
{
	return Notices_FindSlot(id);
}

stock Notices_GetExpires(id)
{
	new slot = Notices_FindSlot(id);
	return slot == -1 ? 0 : s_Notices[slot][E_NOTICE_EXPIRES];
}

stock Notices_GetStarts(id)
{
	new slot = Notices_FindSlot(id);
	return slot == -1 ? 0 : s_Notices[slot][E_NOTICE_STARTS];
}

stock Notices_GetText(id,dest[],size = sizeof(dest))
{
	new slot = Notices_FindSlot(id);

	if (slot == -1)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Notices[slot][E_NOTICE_TEXT],size);
}

stock E_NOTICE_TAB:Notices_GetTab(id)
{
	new slot = Notices_FindSlot(id);
	return slot == -1 ? NOTICE_TAB_COUNT : s_Notices[slot][E_NOTICE_TAB_ID];
}

stock bool:Notices_IsActive(id)
{
	new slot = Notices_FindSlot(id);
	return slot != -1 && s_Notices[slot][E_NOTICE_EXPIRES] > gettime();
}

stock bool:Notices_IsPermanent(id)
{
    return Notices_IsActive(id) && Notices_GetExpires(id) == NOTICES_PERMANENT;
}

stock bool:Notices_CanAnnounce(id)
{
    new slot = Notices_FindSlot(id);
    return slot != -1 && Notices_IsActive(id) && !Notices_IsPermanent(id) && s_Notices[slot][E_NOTICE_CRIED] < NOTICES_CRY_MAX;
}

static Notices_Queue(id)
{
    new count = 0, bool:queued = false;
    for (new i = 0; i < s_NoticeQueueCount; i++)
    {
        new pending = s_NoticeQueue[i];
        if (!Notices_CanAnnounce(pending))
        {
            continue;
        }
        new bool:duplicate = false;
        for (new previous = 0; previous < count; previous++)
        {
            if (s_NoticeQueue[previous] == pending)
            {
                duplicate = true;
                break;
            }
        }
        if (duplicate)
        {
            continue;
        }
        s_NoticeQueue[count++] = pending;
        if (pending == id)
        {
            queued = true;
        }
    }
    s_NoticeQueueCount = count;
    if (!queued && Notices_CanAnnounce(id) && s_NoticeQueueCount < NOTICES_MAX)
    {
        s_NoticeQueue[s_NoticeQueueCount++] = id;
    }
}

stock Notices_GetAnnouncedCount(id)
{
    new slot = Notices_FindSlot(id);
    return slot == -1 ? 0 : s_Notices[slot][E_NOTICE_CRIED];
}

stock Notices_GetTitle(id,dest[],size = sizeof(dest))
{
	new slot = Notices_FindSlot(id);

	if (slot == -1)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Notices[slot][E_NOTICE_TITLE],size);
}

static Notices_Store(id,E_NOTICE_TAB:tab,author,const title[],const text[],startsAt,expiresAt,cried)
{
	new slot = -1, oldest = -1, now = gettime();

	for (new i = 0;i < NOTICES_MAX;i++)
	{
		if (!s_Notices[i][E_NOTICE_USED] || s_Notices[i][E_NOTICE_EXPIRES] <= now)
		{
			slot = i;
			break;
		}

		if (oldest == -1 || s_Notices[i][E_NOTICE_ID] < s_Notices[oldest][E_NOTICE_ID])
		{
			oldest = i;
		}
	}

	if (slot == -1)
	{
		slot = oldest;
	}

	s_Notices[slot][E_NOTICE_USED] = true;
	s_Notices[slot][E_NOTICE_ID] = id;
	s_Notices[slot][E_NOTICE_TAB_ID] = tab;
	s_Notices[slot][E_NOTICE_AUTHOR] = author;
	strcopy(s_Notices[slot][E_NOTICE_TITLE],title,NOTICES_TITLE_LEN);
	strcopy(s_Notices[slot][E_NOTICE_TEXT],text,NOTICES_TEXT_LEN);
	s_Notices[slot][E_NOTICE_STARTS] = startsAt;
	s_Notices[slot][E_NOTICE_EXPIRES] = expiresAt;
	s_Notices[slot][E_NOTICE_CRIED] = cried;
	return slot;
}

forward Task:Notices_Post(E_NOTICE_TAB:tab,author,const title[],const text[],startsAt,expiresAt);
#pragma warning push
#pragma warning disable 204
async Task:Notices_Post(E_NOTICE_TAB:tab,author,const title[],const text[],startsAt,expiresAt)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO notices (county_id, tab, author_character_id, title, text, starts_at, expires_at, fee_paid, announced_count, created_at) VALUES (NULL, %d, %s, '%e', '%e', %d, %d, %d, 0, %d)",_:tab,author > 0 ? sprintf("%d",author) : ("NULL"),title,text,startsAt,expiresAt,tab == NOTICE_TAB_PLAYERS ? NOTICES_FEE : 0,gettime()));
	new id = cache_insert_id();

	if (id <= 0)
	{
		return async 0;
	}

	Notices_Store(id,tab,author,title,text,startsAt,expiresAt,0);

    Notices_Queue(id);

	Notices_RefreshBoards();
	pawn_call_public("Crier_OnPosted","d",id);
	return async id;
}
#pragma warning pop

stock Notices_Cancel(id)
{
	new slot = Notices_FindSlot(id);

	if (slot != -1)
	{
		s_Notices[slot][E_NOTICE_USED] = false;
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE notices SET expires_at = %d WHERE id = %d",gettime(),id));
	Notices_RefreshBoards();
}

stock Notices_TakeDown(E_NOTICE_TAB:tab,const title[],const text[] = "")
{
	new taken = 0, now = gettime();

	for (new i = 0;i < NOTICES_MAX;i++)
	{
		if (!s_Notices[i][E_NOTICE_USED] || s_Notices[i][E_NOTICE_EXPIRES] <= now || s_Notices[i][E_NOTICE_TAB_ID] != tab || strcmp(s_Notices[i][E_NOTICE_TITLE],title) != 0 || strlen(s_Notices[i][E_NOTICE_TITLE]) != strlen(title))
		{
			continue;
		}

		if (text[0] != EOS && (strcmp(s_Notices[i][E_NOTICE_TEXT],text) != 0 || strlen(s_Notices[i][E_NOTICE_TEXT]) != strlen(text)))
		{
			continue;
		}

		Notices_Cancel(s_Notices[i][E_NOTICE_ID]);
		taken++;
	}

	return taken;
}

stock Notices_List(E_NOTICE_TAB:tab,ids[],max = sizeof(ids),skip = 0)
{
	new sorted[NOTICES_MAX], total = 0, count = 0, now = gettime();

	for (new pass = 0;pass < 2;pass++)
	{
		new first = total;

		for (new i = 0;i < NOTICES_MAX;i++)
		{
			if (!s_Notices[i][E_NOTICE_USED] || s_Notices[i][E_NOTICE_EXPIRES] <= now || s_Notices[i][E_NOTICE_TAB_ID] != tab || (pass == 0) == (s_Notices[i][E_NOTICE_STARTS] > now))
			{
				continue;
			}

			new id = s_Notices[i][E_NOTICE_ID], at = total++;

			while (at > first && sorted[at - 1] < id)
			{
				sorted[at] = sorted[at - 1];
				at--;
			}

			sorted[at] = id;
		}
	}

	for (new i = skip > 0 ? skip : 0;i < total && count < max;i++)
	{
		ids[count++] = sorted[i];
	}

	return count;
}

stock Notices_RefreshBoards()
{
	new bool:posted = Notices_Count() > 0;

	for (new board = 0;board < NOTICE_SEED_BOARDS;board++)
	{
		if (s_NoticeBoards[board] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID && s_NoticeBoardPosted[board] == posted)
		{
			continue;
		}

		if (s_NoticeBoards[board] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
		{
			DestroyDynamicObject(s_NoticeBoards[board]);
		}

		s_NoticeBoards[board] = CreateDynamicObject(posted ? MODEL_WRITING_NOTICE_BOARD_POSTED : MODEL_WRITING_NOTICE_BOARD,g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][0],g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][1],g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][2],0.0,0.0,g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][3],0,0,-1,150.0);
		s_NoticeBoardPosted[board] = posted;

		if (s_NoticeBoardLabels[board] == STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
		{
			new text[64];
			format(text,sizeof(text),"Notice board\n{9C8D74}%s",g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_NAME]);
			s_NoticeBoardLabels[board] = CreateDynamic3DTextLabel(text,NOTICES_LABEL_COLOUR,g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][0],g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][1],g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][2] + 2.6,10.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
		}
	}
}

stock bool:Notices_IsBoardPosted(board)
{
	return board >= 0 && board < NOTICE_SEED_BOARDS && s_NoticeBoardPosted[board];
}

stock Notices_FindBoardNear(playerid)
{
	for (new board = 0;board < NOTICE_SEED_BOARDS;board++)
	{
		new Float:a = g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][3];
		new Float:x = g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][0] + floatsin(a,degrees) * 1.2, Float:y = g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][1] - floatcos(a,degrees) * 1.2;

		if (GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,NOTICES_REACH,x,y,g_NoticeBoardDefs[board][E_NOTICE_BOARD_DEF_POS][2] + 1.0))
		{
			return board;
		}
	}

	return -1;
}

stock E_NOTICE_TAB:Notices_TabOfKind(const kind[])
{
	if (!strcmp(kind,"faith"))
	{
		return NOTICE_TAB_CHURCH;
	}

	if (!strcmp(kind,"event") || !strcmp(kind,"weather") || !strcmp(kind,"outbreak"))
	{
		return NOTICE_TAB_EVENTS;
	}

	return NOTICE_TAB_REALM;
}

static Notices_JoinLines(const title[],const text[],chars,dest[],size = sizeof(dest))
{
	new bool:withTitle = title[0] != EOS && strfind(text,title,true) != 0;
	new budget = chars - (withTitle ? strlen(title) + 2 : 0), body[NOTICES_TEXT_LEN + 8], length = 0, c = 0;

	for (;text[c] != EOS && length < budget;c++)
	{
		if (text[c] != '|')
		{
			body[length++] = text[c];
			continue;
		}

		while (length > 0 && body[length - 1] == ' ')
		{
			length--;
		}

		new last = length > 0 ? body[length - 1] : '.';

		if (last != '.' && last != '!' && last != '?' && last != ',' && last != ';' && last != ':')
		{
			body[length++] = '.';
		}

		body[length++] = ' ';
	}

	if (text[c] != EOS)
	{
		new hard = length;

		while (length > 0 && body[length - 1] != ' ')
		{
			length--;
		}

		if (length == 0)
		{
			length = hard;
		}

		while (length > 0 && (body[length - 1] == ' ' || body[length - 1] == ',' || body[length - 1] == '.'))
		{
			length--;
		}

		body[length] = EOS;
		strcat(body,"...");
	}
	else
	{
		while (length > 0 && body[length - 1] == ' ')
		{
			length--;
		}

		body[length] = EOS;
	}

	if (!withTitle)
	{
		format(dest,size,"%s",body);
		return;
	}

	if (body[0] == EOS)
	{
		format(dest,size,"%s",title);
		return;
	}

	format(dest,size,"%s. %s",title,body);
}

stock Notices_FormatCry(const title[],const text[],dest[],size = sizeof(dest))
{
	new body[NOTICES_CRY_CHARS + 8];
	Notices_JoinLines(title,text,NOTICES_CRY_CHARS,body);
	format(dest,size,"Hear ye! %s",body);
}

stock Notices_FormatCall(const title[],const text[],dest[],size = sizeof(dest))
{
	new body[NOTICES_CALL_CHARS + 8];
	Notices_JoinLines(title,text,NOTICES_CALL_CHARS,body);
	format(dest,size,"{B89A72}The crier calls in Talmberg: {D8CCB2}%s",body);
}

static Notices_Cry(id)
{
	new slot = Notices_FindSlot(id);

	if (!Notices_CanAnnounce(id))
	{
		return;
	}

	s_Notices[slot][E_NOTICE_CRIED]++;
	mysql_tquery_s(g_Mysql,str_format("UPDATE notices SET announced_count = %d WHERE id = %d",s_Notices[slot][E_NOTICE_CRIED],id));

	if (Actors_IsPlaced(s_NoticeCrier))
	{
		new line[176];
		Notices_FormatCry(s_Notices[slot][E_NOTICE_TITLE],s_Notices[slot][E_NOTICE_TEXT],line);
		new body_actor = Actors_GetBody(s_NoticeCrier);

		if (body_actor != INVALID_ACTOR_ID && IsValidActor(body_actor))
		{
			ApplyActorAnimation(body_actor,"ON_LOOKERS","shout_01",4.1,false,false,false,false,0);
		}

		Actors_Say(s_NoticeCrier,line);
	}

	if (s_Notices[slot][E_NOTICE_CRIED] == 1)
	{
		new text[NOTICES_CALL_CHARS + 64];
		Notices_FormatCall(s_Notices[slot][E_NOTICE_TITLE],s_Notices[slot][E_NOTICE_TEXT],text);

		foreach (new playerid : Player)
		{
			if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid))
			{
				SendClientMessage(playerid,-1,text);
			}
		}
	}

	pawn_call_public("Crier_OnAnnounce","d",id);
}

stock Notices_PlaceCrier()
{
	new Float:a = g_NoticeBoardDefs[0][E_NOTICE_BOARD_DEF_POS][3];
	new Float:x = g_NoticeBoardDefs[0][E_NOTICE_BOARD_DEF_POS][0] + floatsin(a,degrees) * 1.6 + floatcos(a,degrees) * 1.4;
	new Float:y = g_NoticeBoardDefs[0][E_NOTICE_BOARD_DEF_POS][1] - floatcos(a,degrees) * 1.6 + floatsin(a,degrees) * 1.4;
	new count = Skins_CountStarter(0);
	s_NoticeCrier = Actors_Register("crier:talmberg",ACTOR_ROLE_CRIER,ACTOR_KIND_STATIC,0,count > 0 ? Skins_GetStarter(0,3 % count) : 1,"Vavrinec Hlasatel","crier");

	if (s_NoticeCrier != -1)
	{
		Actors_SetPlace(s_NoticeCrier,x,y,g_NoticeBoardDefs[0][E_NOTICE_BOARD_DEF_POS][2] + 1.0,a + 180.0,0,0);
		Actors_SetAnim(s_NoticeCrier,"COP_AMBIENT","Coplook_loop",true);
		Actors_Place(s_NoticeCrier);
	}
}

stock Notices_GetCrier()
{
	return s_NoticeCrier;
}

forward Task:Notices_Load();
#pragma warning push
#pragma warning disable 204
async Task:Notices_Load()
{
	for (new i = 0;i < NOTICES_MAX;i++)
	{
		s_Notices[i][E_NOTICE_USED] = false;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, tab, IFNULL(author_character_id, 0) AS author, title, text, IFNULL(starts_at, 0) AS starts_at, expires_at, announced_count FROM notices WHERE expires_at > %d ORDER BY id DESC LIMIT %d",gettime(),NOTICES_MAX));

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new id, tab, author, startsAt, expiresAt, cried, title[NOTICES_TITLE_LEN], text[NOTICES_TEXT_LEN];
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name_int(row,"tab",tab);
		cache_get_value_name_int(row,"author",author);
		cache_get_value_name(row,"title",title);
		cache_get_value_name(row,"text",text);
		cache_get_value_name_int(row,"starts_at",startsAt);
		cache_get_value_name_int(row,"expires_at",expiresAt);
		cache_get_value_name_int(row,"announced_count",cried);
		Notices_Store(id,E_NOTICE_TAB:clamp(tab,0,_:NOTICE_TAB_COUNT - 1),author,title,text,startsAt,expiresAt,cried);
	}

	return async Notices_Count();
}
#pragma warning pop

stock Notices_AnnounceNext()
{
	if (s_NoticeQueueCount > 0)
	{
		new id = s_NoticeQueue[0];

		for (new i = 1;i < s_NoticeQueueCount;i++)
		{
			s_NoticeQueue[i - 1] = s_NoticeQueue[i];
		}

		s_NoticeQueueCount--;
		Notices_Cry(id);
	}

	return 1;
}

Timer_Declare(Notices_CryTick)
{
    return Notices_AnnounceNext();
}

forward Crier_OnPosted(noticeid);

public Crier_OnPosted(noticeid)
{
	return 1;
}

forward Crier_OnAnnounce(noticeid);

public Crier_OnAnnounce(noticeid)
{
	return 1;
}

#include <pp-hooks>

hook Crier_OnNews(const kind[],const title[],const body[])
{
	new now = gettime(), short[NOTICES_TITLE_LEN];
	strcopy(short,title);
	Notices_Post(Notices_TabOfKind(kind),0,short,body,now,now + NOTICES_NEWS_DAYS * NOTICES_DAY_SECONDS);
}

hook Routine_OnKeyframe(hour,E_HOUR_NAME:name)
{
	#pragma unused hour

	if (name != HOUR_TERCE && name != HOUR_VESPERS)
	{
		return;
	}

	for (new i = 0;i < NOTICES_MAX;i++)
	{
		if (s_Notices[i][E_NOTICE_USED] && Notices_CanAnnounce(s_Notices[i][E_NOTICE_ID]))
		{
            Notices_Queue(s_Notices[i][E_NOTICE_ID]);
		}
	}
}

hook OnGameModeInit()
{
	for (new board = 0;board < sizeof(g_NoticeBoardDefs);board++)
	{
		s_NoticeBoards[board] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		s_NoticeBoardLabels[board] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	}
}
