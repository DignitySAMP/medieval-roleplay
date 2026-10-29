stock Staff_PickPlayer(staffid)
{
	new text[8];

	if (!Staff_AskText(staffid,"Which player?","Their id.",text,sizeof(text)) || text[0] == EOS)
	{
		return INVALID_PLAYER_ID;
	}

	new targetid = strval(text);

	if (!IsPlayerConnected(targetid) || IsPlayerNPC(targetid))
	{
		SendClientMessage(staffid,COMMAND_COLOUR_ERROR,"Nobody with that id.");
		return INVALID_PLAYER_ID;
	}

	return targetid;
}

stock Staff_OpenPlayer(staffid,targetid)
{
	for (;;)
	{
		if (!IsPlayerConnected(targetid))
		{
			return;
		}

		new name[64], epoch = Gui_BeginFlow(staffid), Float:x, Float:y, Float:width, rows = 0, picks[10], labels[10][32], bool:admin = Staff_HasLevel(staffid,ADMIN_LEVEL_ADMIN);
		Staff_TargetName(targetid,name);
		picks[rows] = 1;
		labels[rows++] = "Inspect";
		picks[rows] = 2;
		labels[rows++] = "Watch";
		picks[rows] = 3;
		labels[rows++] = "Go to them";
		picks[rows] = 4;
		labels[rows++] = "Warn";

		if (admin)
		{
			picks[rows] = 5;
			labels[rows++] = "Bring them here";
			picks[rows] = 6;
			labels[rows++] = Staff_IsFrozen(targetid) ? ("Unfreeze") : ("Freeze");
			picks[rows] = 7;
			labels[rows++] = Staff_IsJailed(targetid) ? ("Let out of OOC jail") : ("OOC jail");
			picks[rows] = 8;
			labels[rows++] = "Kick";
			picks[rows] = 9;
			labels[rows++] = "Ban";
		}

		Kit_Begin(staffid,KIT_LAYER_SCREEN,"A player");
		Kit_OpenPanel(staffid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH,float(rows + 1) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"A player",x,y,width);
		Kit_AddText(staffid,x,y,name,KIT_COLOUR_ACCENT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new i = 0;i < rows;i++)
		{
			Kit_AddChoice(staffid,x,y + KIT_ROW * float(i + 1),width,labels[i],picks[i],picks[i] >= 8 ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
		}

		Kit_AddButton(staffid,x + width / 2.0 - 40.0,y + float(rows + 1) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(staffid);
		Kit_Close(staffid);

		if (!Gui_IsFlowCurrent(staffid,epoch) || pick == KIT_BACK || !IsPlayerConnected(targetid))
		{
			return;
		}

		new reason[96], number[8];

		switch (pick)
		{
			case 1: Staff_Inspect(staffid,targetid);
			case 2:
			{
				Staff_Spectate(staffid,targetid);
				return;
			}
			case 3:
			{
				Staff_Goto(staffid,targetid);
				return;
			}
			case 4:
			{
				if (Staff_AskText(staffid,"Warn","The reason, as it goes on their record.",reason,sizeof(reason)) && reason[0] != EOS)
				{
					Staff_Warn(staffid,targetid,reason);
				}
			}
			case 5: Staff_GetHere(staffid,targetid);
			case 6:
			{
				Staff_SetFrozen(targetid,!Staff_IsFrozen(targetid));
				Staff_Log(staffid,Staff_IsFrozen(targetid) ? ("freeze") : ("unfreeze"),name);
			}
			case 7:
			{
				if (Staff_IsJailed(targetid))
				{
					Staff_Unjail(staffid,targetid);
				}
				else if (Staff_AskText(staffid,"OOC jail","How many minutes?",number,sizeof(number)) && Staff_AskText(staffid,"OOC jail","The reason.",reason,sizeof(reason)) && reason[0] != EOS)
				{
					Staff_Jail(staffid,targetid,strval(number),reason);
				}
			}
			case 8:
			{
				if (Staff_AskText(staffid,"Kick","The reason.",reason,sizeof(reason)) && reason[0] != EOS)
				{
					Staff_Kick(staffid,targetid,reason);
					return;
				}
			}
			case 9:
			{
				if (Staff_AskText(staffid,"Ban","How many hours? 0 for good. Over a week needs a second member of staff.",number,sizeof(number)) && Staff_AskText(staffid,"Ban","The reason.",reason,sizeof(reason)) && reason[0] != EOS)
				{
					Staff_Ban(staffid,targetid,strval(number),reason);
					return;
				}
			}
		}
	}
}

stock Staff_OpenPanel(staffid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM tickets WHERE state < %d",STAFF_TICKET_CLOSED));
	new open = 0;
	cache_get_value_name_int(0,"n",open);

	if (!IsPlayerConnected(staffid))
	{
		return;
	}

	new lines[12][64], count = 0;

	foreach (new playerid : Player)
	{
		if (count < sizeof(lines) && !IsPlayerNPC(playerid) && Staff_IsStaff(playerid))
		{
			new account[MAX_PLAYER_NAME];
			Account_GetName(playerid,account);
			format(lines[count++],64,"%s (%d), %s%s",account,playerid,g_StaffLevelNames[Util_ClampInt(Account_GetAdminLevel(playerid),0,ADMIN_LEVEL_MANAGER)],Staff_IsOnDuty(playerid) ? (", on duty") : (""));
		}
	}

	new epoch = Gui_BeginFlow(staffid), Float:x, Float:y, Float:width, rows = count + 4;
	Kit_Begin(staffid,KIT_LAYER_SCREEN,"Staff");
	Kit_OpenPanel(staffid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH,float(rows) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Staff",x,y,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(staffid,x,y + KIT_ROW * float(i),lines[i],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddChoice(staffid,x,y + KIT_ROW * float(count + 1),width,"Reports",1,open > 0 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,sprintf("%d open",open),KIT_COLOUR_MUTED);
	Kit_AddChoice(staffid,x,y + KIT_ROW * float(count + 2),width,"A player...",2,KIT_COLOUR_TEXT);
	Kit_AddChoice(staffid,x,y + KIT_ROW * float(count + 3),width,Staff_IsOnDuty(staffid) ? ("Go off duty") : ("Go on duty"),3,KIT_COLOUR_TEXT);
	Kit_AddButton(staffid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW + 8.0,80.0,GUI_BUTTON_CLOSE,KIT_BACK);
	new pick = await Kit_Present(staffid);
	Kit_Close(staffid);

	if (!Gui_IsFlowCurrent(staffid,epoch))
	{
		return;
	}

	switch (pick)
	{
		case 1: Staff_OpenReports(staffid);
		case 2:
		{
			new targetid = Staff_PickPlayer(staffid);

			if (targetid != INVALID_PLAYER_ID)
			{
				Staff_OpenPlayer(staffid,targetid);
			}
		}
		case 3: Staff_SetDuty(staffid,!Staff_IsOnDuty(staffid));
	}
}

stock Staff_OpenLogs(staffid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT s.action, s.target, s.detail, s.at, a.name FROM staff_actions s LEFT JOIN accounts a ON a.id = s.staff_account_id ORDER BY s.id DESC LIMIT %d",STAFF_LOG_SHOWN));

	if (!IsPlayerConnected(staffid))
	{
		return;
	}

	new rows = min(cache_num_rows(),STAFF_LOG_SHOWN), lines[STAFF_LOG_SHOWN][112], now = gettime();

	for (new r = 0;r < rows;r++)
	{
		new action[32], target[64], detail[48], who[MAX_PLAYER_NAME], at;
		cache_get_value_name(r,"action",action);
		cache_get_value_name(r,"target",target);
		cache_get_value_name(r,"detail",detail);
		cache_get_value_name(r,"name",who);
		cache_get_value_name_int(r,"at",at);
		format(lines[r],112,"%dm ago, %s: %s %s %s",(now - at) / 60,who[0] != EOS ? who : ("the server"),action,target,detail);
	}

	new epoch = Gui_BeginFlow(staffid), Float:x, Float:y, Float:width, shown = max(rows,1);
	Kit_Begin(staffid,KIT_LAYER_SCREEN,"Staff log");
	Kit_OpenPanel(staffid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH + 160.0,float(shown) * KIT_ROW * 0.85 + 6.0 + KIT_ROW + 12.0,"Staff log",x,y,width);

	for (new r = 0;r < rows;r++)
	{
		Kit_AddText(staffid,x,y + KIT_ROW * 0.85 * float(r),lines[r],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	if (rows == 0)
	{
		Kit_AddText(staffid,x,y,"Nothing logged yet.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(staffid,x + width / 2.0 - 40.0,y + float(shown) * KIT_ROW * 0.85 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(staffid);

	if (Gui_IsFlowCurrent(staffid,epoch))
	{
		Kit_Close(staffid);
	}
}
