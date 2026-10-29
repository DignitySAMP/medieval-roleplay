forward Task:Staff_FileTicket(playerid,targetid,const text[]);

stock bool:Staff_AskText(playerid,const title[],const prompt[],dest[],size)
{
	new token = Account_GetToken(playerid), response[DIALOG_RESPONSE], body[256];
	format(body,sizeof(body),GUI_TEXT "%s",prompt);
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,title,body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
	{
		return false;
	}

	strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);
	return true;
}

#pragma warning push
#pragma warning disable 204
async Task:Staff_FileTicket(playerid,targetid,const text[])
{
	new accountid = Account_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM tickets WHERE reporter_account_id = %d AND state < %d",accountid,STAFF_TICKET_CLOSED));
	new open = 0;
	cache_get_value_name_int(0,"n",open);

	if (open > 0)
	{
		if (IsPlayerConnected(playerid))
		{
			Gui_Notify(playerid,"You have a report open already; the staff will answer it.");
		}

		return async 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO tickets (reporter_account_id, target_account_id, text, state, claimed_by, created_at, closed_at) VALUES (%d, %s, '%e', %d, NULL, %d, NULL)",accountid,IsPlayerConnected(targetid) && targetid != playerid ? sprintf("%d",Account_GetId(targetid)) : ("NULL"),text,STAFF_TICKET_OPEN,gettime()));
	new id = cache_insert_id(), name[64], line[200];

	if (!IsPlayerConnected(playerid))
	{
		return async id;
	}

	Staff_TargetName(playerid,name);
	format(line,sizeof(line),"[Report %d] %s: %s",id,name,text);
	Staff_Broadcast(line);
	Gui_Notify(playerid,"Your report is with the staff. Someone will answer you here.");
	return async id;
}
#pragma warning pop

stock Staff_AskStaff(playerid)
{
	new text[STAFF_TICKET_LEN], about[8], targetid = INVALID_PLAYER_ID;

	if (!Staff_AskText(playerid,"Ask the staff","What's wrong, or what do you need? Out of character.",text,sizeof(text)) || strlen(text) < 4)
	{
		return;
	}

	if (Staff_AskText(playerid,"About someone?","If it's about another player, their id (shown by their name). Leave it empty if not.",about,sizeof(about)) && about[0] != EOS)
	{
		targetid = strval(about);
	}

	Staff_FileTicket(playerid,targetid,text);
}

stock Staff_ClaimTicket(staffid,ticket)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE tickets SET state = %d, claimed_by = %d WHERE id = %d AND state = %d",STAFF_TICKET_CLAIMED,Account_GetId(staffid),ticket,STAFF_TICKET_OPEN));
	Staff_Log(staffid,"claim",sprintf("report %d",ticket));
}

stock Staff_CloseTicket(staffid,ticket)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE tickets SET state = %d, closed_at = %d WHERE id = %d",STAFF_TICKET_CLOSED,gettime(),ticket));
	Staff_Log(staffid,"close",sprintf("report %d",ticket));
}

stock Staff_FindAccount(accountid)
{
	foreach (new playerid : Player)
	{
		if (Account_GetId(playerid) == accountid)
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Staff_OpenTicket(staffid,ticket,reporter,const text[])
{
	for (;;)
	{
		new reporterid = Staff_FindAccount(reporter), epoch = Gui_BeginFlow(staffid), Float:x, Float:y, Float:width, title[24];
		format(title,sizeof(title),"Report %d",ticket);
		Kit_Begin(staffid,KIT_LAYER_SCREEN,title);
		Kit_OpenPanel(staffid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH + 60.0,KIT_ROW * 7.0 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
		Kit_AddText(staffid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		Kit_AddChoice(staffid,x,y + KIT_ROW * 3.0,width,"Claim it",1,KIT_COLOUR_TEXT);
		Kit_AddChoice(staffid,x,y + KIT_ROW * 4.0,width,"Answer the player",2,reporterid == INVALID_PLAYER_ID ? KIT_COLOUR_MUTED : KIT_COLOUR_TEXT,reporterid == INVALID_PLAYER_ID ? ("not online") : (""),KIT_COLOUR_MUTED);
		Kit_AddChoice(staffid,x,y + KIT_ROW * 5.0,width,"Go to the player",3,reporterid == INVALID_PLAYER_ID ? KIT_COLOUR_MUTED : KIT_COLOUR_TEXT);
		Kit_AddChoice(staffid,x,y + KIT_ROW * 6.0,width,"Close it",4,KIT_COLOUR_GOOD);
		Kit_AddButton(staffid,x + width / 2.0 - 40.0,y + KIT_ROW * 7.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(staffid);
		Kit_Close(staffid);

		if (!Gui_IsFlowCurrent(staffid,epoch) || pick == KIT_BACK)
		{
			return;
		}

		switch (pick)
		{
			case 1: Staff_ClaimTicket(staffid,ticket);
			case 2:
			{
				new answer[STAFF_TICKET_LEN], account[MAX_PLAYER_NAME];

				if (reporterid != INVALID_PLAYER_ID && Staff_AskText(staffid,"Answer","Your answer, out of character.",answer,sizeof(answer)) && answer[0] != EOS && IsPlayerConnected(reporterid))
				{
					Account_GetName(staffid,account);
					SendClientMessage(reporterid,STAFF_CHAT_COLOUR,sprintf("(( Staff %s on your report: %s ))",account,answer));
					SendClientMessage(staffid,STAFF_CHAT_COLOUR,"Answer sent.");
					Staff_Log(staffid,"answer",sprintf("report %d",ticket),answer);
				}
			}
			case 3:
			{
				if (reporterid != INVALID_PLAYER_ID)
				{
					Staff_Goto(staffid,reporterid);
					return;
				}
			}
			case 4:
			{
				Staff_CloseTicket(staffid,ticket);

				if (reporterid != INVALID_PLAYER_ID)
				{
					SendClientMessage(reporterid,STAFF_CHAT_COLOUR,"(( Your report is closed. ))");
				}

				return;
			}
		}
	}
}

stock Staff_OpenReports(staffid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT t.id, t.reporter_account_id, t.text, t.state, a.name FROM tickets t LEFT JOIN accounts a ON a.id = t.reporter_account_id WHERE t.state < %d ORDER BY t.id LIMIT %d",STAFF_TICKET_CLOSED,STAFF_TICKETS_SHOWN));

	if (!IsPlayerConnected(staffid))
	{
		return;
	}

	new rows = min(cache_num_rows(),STAFF_TICKETS_SHOWN), ids[STAFF_TICKETS_SHOWN], reporters[STAFF_TICKETS_SHOWN], texts[STAFF_TICKETS_SHOWN][STAFF_TICKET_LEN], states[STAFF_TICKETS_SHOWN], names[STAFF_TICKETS_SHOWN][MAX_PLAYER_NAME];

	for (new r = 0;r < rows;r++)
	{
		cache_get_value_name_int(r,"id",ids[r]);
		cache_get_value_name_int(r,"reporter_account_id",reporters[r]);
		cache_get_value_name(r,"text",texts[r]);
		cache_get_value_name_int(r,"state",states[r]);
		cache_get_value_name(r,"name",names[r]);
	}

	new epoch = Gui_BeginFlow(staffid), Float:x, Float:y, Float:width, shown = max(rows,1);
	Kit_Begin(staffid,KIT_LAYER_SCREEN,"Reports");
	Kit_OpenPanel(staffid,KIT_ANCHOR_CENTRE,STAFF_PANEL_WIDTH + 80.0,float(shown) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Reports",x,y,width);

	if (rows == 0)
	{
		Kit_AddText(staffid,x,y,"No reports are open.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	for (new r = 0;r < rows;r++)
	{
		new label[64], detail[24];
		format(label,sizeof(label),"%d. %s: %.40s",ids[r],names[r],texts[r]);
		format(detail,sizeof(detail),"%s%s",g_StaffTicketStates[Util_ClampInt(states[r],0,2)],Staff_FindAccount(reporters[r]) == INVALID_PLAYER_ID ? (", away") : (""));
		Kit_AddChoice(staffid,x,y + KIT_ROW * float(r),width,label,r,states[r] == STAFF_TICKET_OPEN ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,detail,KIT_COLOUR_MUTED,0.25);
	}

	Kit_AddButton(staffid,x + width / 2.0 - 40.0,y + float(shown) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(staffid);
	Kit_Close(staffid);

	if (Gui_IsFlowCurrent(staffid,epoch) && pick >= 0 && pick < rows)
	{
		Staff_OpenTicket(staffid,ids[pick],reporters[pick],texts[pick]);
	}
}

forward Staff_AskStaffDeferred(playerid);

public Staff_AskStaffDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Staff_AskStaff(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook Help_OnAskStaff(playerid)
{
	SetTimerEx("Staff_AskStaffDeferred",0,false,"d",playerid);
}
