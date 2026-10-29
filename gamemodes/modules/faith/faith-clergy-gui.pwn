#define CLERGY_GUI_ADMIT (1)
#define CLERGY_GUI_RECEIVE (2)
#define CLERGY_GUI_DISMISS (3)
#define CLERGY_GUI_LEAVE (4)
#define CLERGY_GUI_NEARBY (8)

static bool:ClergyGui_Confirm(playerid,const title[],const text[],const button[])
{
	new Float:x, Float:y, Float:width, Float:textHeight = Gui_TextHeight(text,300.0);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,300.0,textHeight + KIT_ROW + 10.0,title,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x,y + textHeight + 8.0,width * 0.45,button,1,KIT_COLOUR_ACCENT);
	Kit_AddButton(playerid,x + width * 0.55,y + textHeight + 8.0,width * 0.45,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick == 1;
}

static ClergyGui_PickPlayer(playerid,const title[],const candidates[],count)
{
	new Float:x, Float:y, Float:width, name[CHARACTER_NAME_MAX * 2 + 2], rank[CLERGY_TITLE_LEN];
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(max(count,1)) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	if (count == 0)
	{
		Kit_AddText(playerid,x,y,"Nobody fits here.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	for (new i = 0;i < count;i++)
	{
		new known[NAMETAG_LEN];
		Nametag_GetKnownName(playerid,candidates[i],known);
		format(name,sizeof(name),"%s (%d)",known,candidates[i]);
		Clergy_RankTitle(Clergy_GetRank(candidates[i]),Character_GetSex(candidates[i]),rank);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,name,i,KIT_COLOUR_TEXT,rank,KIT_COLOUR_MUTED,0.6);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(max(count,1)) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick >= 0 && pick < count ? candidates[pick] : INVALID_PLAYER_ID;
}

static ClergyGui_Nearby(playerid,candidates[CLERGY_GUI_NEARBY],bool:members)
{
	new count = 0, Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new i : Player)
	{
		if (count >= CLERGY_GUI_NEARBY)
		{
			break;
		}

		if (i == playerid || !Session_IsPlaying(i) || !Clergy_IsLoaded(i))
		{
			continue;
		}

		if (members)
		{
			if (Clergy_GetRank(i) != CLERGY_NONE && Clergy_GetRank(i) < Clergy_GetRank(playerid))
			{
				candidates[count++] = i;
			}
		}
		else if (Clergy_GetRank(i) == CLERGY_NONE && IsPlayerInRangeOfPoint(i,CLERGY_ADMIT_RANGE,x,y,z))
		{
			candidates[count++] = i;
		}
	}

	return count;
}

static E_CLERGY_RANK:ClergyGui_PickRank(playerid,targetid)
{
	new Float:x, Float:y, Float:width, title[CLERGY_TITLE_LEN], E_CLERGY_RANK:ranks[3] = {CLERGY_NOVICE, CLERGY_LAY, CLERGY_BROTHER};
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Their place");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,200.0,float(sizeof(ranks)) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Their place",x,y,width);

	for (new i = 0;i < sizeof(ranks);i++)
	{
		Clergy_RankTitle(ranks[i],Character_GetSex(targetid),title);
		Kit_AddChoice(playerid,x,y + float(i) * KIT_ROW,width,title,i,ranks[i] == Clergy_GetRank(targetid) ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(sizeof(ranks)) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);
	return pick >= 0 && pick < sizeof(ranks) ? ranks[pick] : CLERGY_RANK_COUNT;
}

stock ClergyGui_Open(playerid,epoch)
{
	new token = Account_GetToken(playerid);

	for (;;)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT m.church_rank, c.name, c.surname, c.sex FROM church_members m JOIN characters c ON c.id = m.character_id WHERE c.alive = 1 ORDER BY m.church_rank DESC, c.name LIMIT %d",CLERGY_ROSTER_ROWS));

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		new rows = cache_num_rows(), names[CLERGY_ROSTER_ROWS][CHARACTER_NAME_MAX * 2 + 2], titles[CLERGY_ROSTER_ROWS][CLERGY_TITLE_LEN];

		for (new r = 0;r < rows;r++)
		{
			new rank, sex, name[CHARACTER_NAME_MAX + 1], surname[CHARACTER_NAME_MAX + 1];
			cache_get_value_name_int(r,"church_rank",rank);
			cache_get_value_name_int(r,"sex",sex);
			cache_get_value_name(r,"name",name);
			cache_get_value_name(r,"surname",surname);
			format(names[r],sizeof(names[]),"%s %s",name,surname);
			Clergy_RankTitle(E_CLERGY_RANK:rank,sex,titles[r]);
		}

		new Float:x, Float:y, Float:width, bool:canAdmit = Clergy_CanAdmit(playerid), buttons = canAdmit ? 4 : 1, Float:footY;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"The Church");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,280.0,float(max(rows,1)) * KIT_ROW + 6.0 + float(buttons) * (KIT_ROW + 4.0) + KIT_ROW + 12.0,"The Church",x,y,width);

		for (new r = 0;r < rows;r++)
		{
			Kit_AddText(playerid,x,y + float(r) * KIT_ROW,titles[r],KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.38);
			Kit_AddText(playerid,x + width * 0.38,y + float(r) * KIT_ROW,names[r],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.62);
		}

		footY = y + float(max(rows,1)) * KIT_ROW + 8.0;

		if (canAdmit)
		{
			Kit_AddButton(playerid,x,footY,width,"Admit a novice beside you",CLERGY_GUI_ADMIT,KIT_COLOUR_ACCENT);
			Kit_AddButton(playerid,x,footY + (KIT_ROW + 4.0),width,"Set someone's place",CLERGY_GUI_RECEIVE,KIT_COLOUR_TEXT);
			Kit_AddButton(playerid,x,footY + (KIT_ROW + 4.0) * 2.0,width,"Send someone away",CLERGY_GUI_DISMISS,KIT_COLOUR_TEXT);
			footY += (KIT_ROW + 4.0) * 3.0;
		}

		Kit_AddButton(playerid,x,footY,width * 0.45,"Leave the Church",CLERGY_GUI_LEAVE,KIT_COLOUR_BAD);
		Kit_AddButton(playerid,x + width * 0.55,footY,width * 0.45,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0)
		{
			return;
		}

		new candidates[CLERGY_GUI_NEARBY], count, targetid;

		switch (pick)
		{
			case CLERGY_GUI_ADMIT:
			{
				count = ClergyGui_Nearby(playerid,candidates,false);
				targetid = ClergyGui_PickPlayer(playerid,"Admit a novice",candidates,count);

				if (targetid != INVALID_PLAYER_ID && Clergy_Offer(targetid,playerid))
				{
					Gui_Notify(playerid,"You ask them to enter the Church.");
				}
			}
			case CLERGY_GUI_RECEIVE:
			{
				count = ClergyGui_Nearby(playerid,candidates,true);
				targetid = ClergyGui_PickPlayer(playerid,"Set a place",candidates,count);

				if (targetid != INVALID_PLAYER_ID)
				{
					new E_CLERGY_RANK:rank = ClergyGui_PickRank(playerid,targetid);

					if (rank != CLERGY_RANK_COUNT && Clergy_GetRank(targetid) < Clergy_GetRank(playerid))
					{
						Clergy_SetRank(targetid,rank,Character_GetId(playerid));
					}
				}
			}
			case CLERGY_GUI_DISMISS:
			{
				count = ClergyGui_Nearby(playerid,candidates,true);
				targetid = ClergyGui_PickPlayer(playerid,"Send away",candidates,count);

				if (targetid != INVALID_PLAYER_ID && Clergy_GetRank(targetid) < Clergy_GetRank(playerid) && ClergyGui_Confirm(playerid,"Send away","They leave the monastery and lose their place in the Church.","Send away"))
				{
					Clergy_SetRank(targetid,CLERGY_NONE,Character_GetId(playerid));
				}
			}
			case CLERGY_GUI_LEAVE:
			{
				if (ClergyGui_Confirm(playerid,"Leave the Church","You give up your habit and your place in the Church. Coming back means starting as a novice again.","Leave"))
				{
					Clergy_SetRank(playerid,CLERGY_NONE);
					return;
				}
			}
		}

		if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}
	}
}
