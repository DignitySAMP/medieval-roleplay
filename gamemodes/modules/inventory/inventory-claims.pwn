#define CLAIM_DAYS (14)
#define CLAIM_WARN_DAYS (2)
#define CLAIM_LIST_MAX (24)
#define CLAIM_REASON_LEN (32)
#define CLAIM_TAKE_ALL (1000)

stock Claims_FindPlayer(characterid)
{
	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == characterid && Inventory_IsLoaded(playerid))
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

stock bool:Claims_Give(characterid,E_ITEM_KIND:kind,param,amount,stars,const reason[],freshAt = ITEM_FRESH_NOW,wear = 0,data = 0)
{
	if (characterid <= 0 || amount <= 0 || !Item_IsValid(kind,param))
	{
		return false;
	}

	new playerid = Claims_FindPlayer(characterid);
	freshAt = Item_ResolveFresh(kind,param,freshAt);

	if (playerid != INVALID_PLAYER_ID && Inventory_Give(playerid,kind,param,amount,stars,freshAt,wear,data))
	{
		return true;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO claims (character_id, kind, param, amount, stars, fresh_at, wear, data, reason, expires_at) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, '%e', DATE_ADD(NOW(), INTERVAL %d DAY))",characterid,_:kind,param,amount,stars,freshAt,wear,data,reason,CLAIM_DAYS));

	if (playerid != INVALID_PLAYER_ID)
	{
		new name[ITEM_NAME_LEN], message[128];
		Item_GetName(kind,param,name);
		format(message,sizeof(message),"Your bag is full! %d %s went to your Claims instead. Pick them up within %d days.",amount,name,CLAIM_DAYS);
		Gui_Notify(playerid,message);
	}

	return true;
}

static bool:Claims_TakeRow(playerid,row,E_ITEM_KIND:kind,param,amount,stars,freshAt = 0,wear = 0,data = 0)
{
	if (!Inventory_CanGive(playerid,kind,param,amount,stars))
	{
		return false;
	}

	await mysql_aquery_s(g_Mysql,str_format("DELETE FROM claims WHERE id = %d",row));

	if (cache_affected_rows() != 1 || !IsPlayerConnected(playerid))
	{
		return false;
	}

	Inventory_Give(playerid,kind,param,amount,stars,freshAt,wear,data);
	return true;
}

static Claims_Deliver(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, param, amount, stars, fresh_at, wear, data, DATEDIFF(expires_at, NOW()) AS days FROM claims WHERE character_id = %d AND expires_at > NOW() ORDER BY id LIMIT %d",characterid,CLAIM_LIST_MAX));

	new rows = cache_num_rows(), items[CLAIM_LIST_MAX][9];

	if (rows == 0)
	{
		return;
	}

	for (new r = 0;r < rows;r++)
	{
		cache_get_value_name_int(r,"id",items[r][0]);
		cache_get_value_name_int(r,"kind",items[r][1]);
		cache_get_value_name_int(r,"param",items[r][2]);
		cache_get_value_name_int(r,"amount",items[r][3]);
		cache_get_value_name_int(r,"stars",items[r][4]);
		cache_get_value_name_int(r,"days",items[r][5]);
		cache_get_value_name_int(r,"fresh_at",items[r][6]);
		cache_get_value_name_int(r,"wear",items[r][7]);
		cache_get_value_name_int(r,"data",items[r][8]);
	}

	new delivered = 0, waiting = 0, expiring = 0;

	for (new r = 0;r < rows;r++)
	{
		if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
		{
			return;
		}

		if (Claims_TakeRow(playerid,items[r][0],E_ITEM_KIND:items[r][1],items[r][2],items[r][3],items[r][4],items[r][6],items[r][7],items[r][8]))
		{
			delivered++;
			continue;
		}

		waiting++;

		if (items[r][5] <= CLAIM_WARN_DAYS)
		{
			expiring++;
		}
	}

	new message[144];

	if (delivered > 0 && waiting > 0)
	{
		format(message,sizeof(message),"%d claim%s went into your bag. %d are still waiting in Claims.",delivered,delivered == 1 ? ("") : ("s"),waiting);
	}
	else if (delivered > 0)
	{
		format(message,sizeof(message),"%d claim%s went into your bag.",delivered,delivered == 1 ? ("") : ("s"));
	}
	else
	{
		format(message,sizeof(message),"You have %d claim%s to collect. Open your bag (N) and click Claims.",waiting,waiting == 1 ? ("") : ("s"));
	}

	if (expiring > 0)
	{
		format(message,sizeof(message),"%s %d of them expire within %d days.",message,expiring,CLAIM_WARN_DAYS);
	}

	Gui_Notify(playerid,message);
}

static Claims_OpenMenu(playerid)
{
	new epoch = Gui_BeginFlow(playerid), characterid = Character_GetId(playerid);

	for (;;)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, param, amount, stars, fresh_at, wear, data, DATEDIFF(expires_at, NOW()) AS days FROM claims WHERE character_id = %d AND expires_at > NOW() ORDER BY id LIMIT %d",characterid,CLAIM_LIST_MAX));

		new rows = cache_num_rows(), items[CLAIM_LIST_MAX][9];

		for (new r = 0;r < rows;r++)
		{
			cache_get_value_name_int(r,"id",items[r][0]);
			cache_get_value_name_int(r,"kind",items[r][1]);
			cache_get_value_name_int(r,"param",items[r][2]);
			cache_get_value_name_int(r,"amount",items[r][3]);
			cache_get_value_name_int(r,"stars",items[r][4]);
			cache_get_value_name_int(r,"days",items[r][5]);
			cache_get_value_name_int(r,"fresh_at",items[r][6]);
			cache_get_value_name_int(r,"wear",items[r][7]);
			cache_get_value_name_int(r,"data",items[r][8]);
		}

		if (!Gui_IsFlowCurrent(playerid,epoch) || Character_GetId(playerid) != characterid)
		{
			return;
		}

		new name[ITEM_NAME_LEN], label[48], detail[16], Float:x, Float:y, Float:width, Float:contentHeight = float(max(rows,1)) * KIT_ROW + 6.0 + KIT_ROW + 12.0;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Claims");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,contentHeight,"Claims",x,y,width);

		if (rows == 0)
		{
			Kit_AddText(playerid,x,y,"Nothing to collect.",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		}

		for (new r = 0;r < rows;r++)
		{
			Item_GetName(E_ITEM_KIND:items[r][1],items[r][2],name);
			format(label,sizeof(label),"%d %s",items[r][3],name);
			Item_AppendStars(label,items[r][4]);
			format(detail,sizeof(detail),"%d day%s",items[r][5],items[r][5] == 1 ? ("") : ("s"));
			Kit_AddChoice(playerid,x,y + float(r) * KIT_ROW,width,label,r,KIT_COLOUR_TEXT,detail,items[r][5] <= CLAIM_WARN_DAYS ? KIT_COLOUR_BAD : KIT_COLOUR_MUTED,0.72);
		}

		new Float:buttonY = y + float(max(rows,1)) * KIT_ROW + 8.0;

		if (rows > 0)
		{
			Kit_AddButton(playerid,x,buttonY,90.0,"Take all",CLAIM_TAKE_ALL,KIT_COLOUR_ACCENT);
		}

		Kit_AddButton(playerid,x + width - 80.0,buttonY,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		new taken = 0, missed = 0;

		for (new r = 0;r < rows;r++)
		{
			if (pick != CLAIM_TAKE_ALL && pick != r)
			{
				continue;
			}

			if (Claims_TakeRow(playerid,items[r][0],E_ITEM_KIND:items[r][1],items[r][2],items[r][3],items[r][4],items[r][6],items[r][7],items[r][8]))
			{
				taken++;
			}
			else
			{
				missed++;
			}

			if (!Gui_IsFlowCurrent(playerid,epoch))
			{
				return;
			}
		}

		if (missed > 0)
		{
			Gui_Notify(playerid,taken > 0 ? ("Some of it didn't fit in your bag.") : ("That doesn't fit in your bag."));
		}
	}
}

forward Claims_OpenMenuDeferred(playerid);

public Claims_OpenMenuDeferred(playerid)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid))
	{
		Claims_OpenMenu(playerid);
	}
}

forward Claims_DeliverDeferred(playerid,characterid);

public Claims_DeliverDeferred(playerid,characterid)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid)
	{
		Claims_Deliver(playerid,characterid);
	}
}

forward Claims_Purge();

public Claims_Purge()
{
	mysql_tquery_s(g_Mysql,str_new("DELETE FROM claims WHERE expires_at <= NOW()"));
	return 1;
}

#include <pp-hooks>

hook Inventory_OnLoaded(playerid)
{
	new characterid = Character_GetId(playerid);

	if (characterid > 0)
	{
		SetTimerEx("Claims_DeliverDeferred",0,false,"dd",playerid,characterid);
	}
}

hook Calendar_OnDay(day,month,year)
{
	#pragma unused day, month, year
	Claims_Purge();
}
