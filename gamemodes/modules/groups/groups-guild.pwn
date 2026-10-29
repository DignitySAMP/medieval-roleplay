static s_Training[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};

forward Task:Groups_PresentPiece(playerid,group,bagIndex);
forward Task:Groups_JudgePiece(playerid,group,pieceid,bool:passes);
forward Task:Groups_ReturnFailedPieces(playerid,characterid);

stock Groups_InitMarks()
{
	new count = 0;

	for (new recipe = 0, total = Recipe_GetCount();recipe < total;recipe++)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (Recipe_GetOutput(recipe,kind,param,amount) && Trader_GetItemTrade(kind,param) == -1 && kind != ITEM_KIND_WEAPON && kind != ITEM_KIND_SHIELD && kind != ITEM_KIND_COIN && kind != ITEM_KIND_CONTAINER)
		{
			Trader_SetItemTrade(param,Recipe_GetTrade(recipe));
			count++;
		}
	}

	return count;
}

stock Groups_UpdateMark(playerid)
{
	new guild = Groups_FindMineOfKind(playerid,GROUP_KIND_GUILD), minStars, floorPercent, ceilingPercent;

	if (guild == GROUP_INVALID || !Groups_IsChartered(guild) || !Groups_HasFeature(guild,GROUP_FEATURE_CHARTER))
	{
		Trader_SetMark(playerid,-1,0,0);
		return;
	}

	Groups_GetRules(guild,minStars,floorPercent,ceilingPercent);
	Trader_SetMark(playerid,Groups_GetTrade(guild),minStars,GROUPS_MARK_PERCENT);
}

stock Groups_FindTeacher(playerid)
{
	new guild = Groups_FindMineOfKind(playerid,GROUP_KIND_GUILD);

	if (guild == GROUP_INVALID || !Groups_IsChartered(guild))
	{
		return INVALID_PLAYER_ID;
	}

	new trade = Groups_GetTrade(guild), rank = Groups_GetRank(playerid,guild), level = Work_GetLevel(playerid,trade), Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new other : Player)
	{
		if (other == playerid || !Session_IsPlaying(other) || GetPlayerVirtualWorld(other) != GetPlayerVirtualWorld(playerid) || !IsPlayerInRangeOfPoint(other,GROUPS_TRAIN_RANGE,x,y,z))
		{
			continue;
		}

		new otherRank = Groups_GetRank(other,guild), otherLevel = Work_GetLevel(other,trade);

		if (otherRank != -1 && otherRank < rank && otherLevel > level && (otherLevel >= GROUPS_TRAIN_MASTER_LEVEL || Work_IsMastered(other,trade)))
		{
			return other;
		}
	}

	return INVALID_PLAYER_ID;
}

stock Groups_GetTeacher(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Training[playerid] : INVALID_PLAYER_ID;
}

stock bool:Groups_IsJudge(playerid,group)
{
	return Groups_GetKind(group) == GROUP_KIND_GUILD && Groups_HasPerm(playerid,group,GROUP_PERM_JUDGE) && (Work_IsMastered(playerid,Groups_GetTrade(group)) || Groups_IsHead(playerid,group));
}

stock bool:Groups_IsPieceOf(E_ITEM_KIND:kind,param,stars,trade)
{
	return stars >= GROUPS_MASTERPIECE_STARS && trade != -1 && kind == ITEM_KIND_MISC && Item_IsMasterpiece(param) && Trader_GetItemTrade(kind,param) == trade;
}

stock bool:Groups_CanPresent(playerid,trade)
{
	return Trade_IsValid(trade) && Trade_HasMasterpiece(trade) && !Work_IsMastered(playerid,trade) && Work_GetLevel(playerid,trade) >= WORK_LEVEL_UNMASTERED;
}

stock Groups_GrantMastery(characterid,trade)
{
	new playerid = Groups_PlayerByCharacter(characterid);

	if (playerid != INVALID_PLAYER_ID)
	{
		Work_SetMastered(playerid,trade,true);
		new name[32];
		Trade_GetName(trade,name);
		Gui_Notify(playerid,sprintf("Your masterpiece is passed. You're a master of the %s trade and may reach its tenth level.",name));
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO job_levels (character_id, trade, level, practice, mastered) VALUES (%d, %d, 1, 0, 1) ON DUPLICATE KEY UPDATE mastered = 1",characterid,trade));
}

#pragma warning push
#pragma warning disable 204
async Task:Groups_PresentPiece(playerid,group,bagIndex)
{
	new E_ITEM_KIND:kind, param, amount, stars = Inventory_GetSlotStars(playerid,bagIndex), trade = Groups_GetTrade(group), store = Groups_GetStore(group);

	if (!Inventory_GetSlot(playerid,bagIndex,kind,param,amount) || !Groups_IsPieceOf(kind,param,stars,trade) || !Groups_CanPresent(playerid,trade) || store == INVALID_CONTAINER_ID || !Container_CanAdd(store,kind,param,1,stars))
	{
		wait_ticks(1);
		return async 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT COUNT(*) AS n FROM group_masterpieces WHERE character_id = %d AND trade = %d AND state = %d",Character_GetId(playerid),trade,GROUP_PIECE_PENDING));
	new pending = 0;
	cache_get_value_name_int(0,"n",pending);

	if (pending > 0 || !IsPlayerConnected(playerid) || !Inventory_TakeSlot(playerid,bagIndex,1))
	{
		return async 0;
	}

	Container_Add(store,kind,param,1,stars);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO group_masterpieces (group_id, character_id, trade, kind, param, stars, state, votes_for, votes_against, voters, returned, created_at) VALUES (%d, %d, %d, %d, %d, %d, %d, 0, 0, ',', 0, %d)",Groups_GetId(group),Character_GetId(playerid),trade,_:kind,param,stars,GROUP_PIECE_PENDING,gettime()));
	new id = cache_insert_id(), name[MAX_PLAYER_NAME], item[ITEM_NAME_LEN];
	Character_GetName(playerid,name);
	Item_GetName(kind,param,item);
	Groups_Tell(group,sprintf("%s presents a masterpiece to the guild: %s. The masters judge it in the guild's panel.",name,item));
	Groups_Log(group,Character_GetId(playerid),sprintf("presented a masterpiece (%s)",item));
	return async id;
}

async Task:Groups_JudgePiece(playerid,group,pieceid,bool:passes)
{
	new characterid = playerid == INVALID_PLAYER_ID ? 0 : Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT character_id, trade, kind, param, stars, state, votes_for, votes_against, voters FROM group_masterpieces WHERE id = %d AND group_id = %d",pieceid,Groups_GetId(group)));

	if (cache_num_rows() == 0)
	{
		return async 0;
	}

	new maker, trade, kind, param, stars, pieceState, votesFor, votesAgainst, voters[96], mark[16];
	cache_get_value_name_int(0,"character_id",maker);
	cache_get_value_name_int(0,"trade",trade);
	cache_get_value_name_int(0,"kind",kind);
	cache_get_value_name_int(0,"param",param);
	cache_get_value_name_int(0,"stars",stars);
	cache_get_value_name_int(0,"state",pieceState);
	cache_get_value_name_int(0,"votes_for",votesFor);
	cache_get_value_name_int(0,"votes_against",votesAgainst);
	cache_get_value_name(0,"voters",voters);
	format(mark,sizeof(mark),",%d,",characterid);

	if (pieceState != GROUP_PIECE_PENDING)
	{
		return async 0;
	}

	if (playerid == INVALID_PLAYER_ID)
	{
		if (passes)
		{
			votesFor = GROUPS_MASTER_VOTES;
		}
		else
		{
			votesAgainst = GROUPS_MASTER_VOTES;
		}
	}
	else
	{
		if (maker == characterid || strfind(voters,mark) != -1 || !Groups_IsJudge(playerid,group))
		{
			return async 0;
		}

		if (passes)
		{
			votesFor++;
		}
		else
		{
			votesAgainst++;
		}

		format(voters,sizeof(voters),"%s%d,",voters,characterid);
	}

	if (votesFor >= GROUPS_MASTER_VOTES)
	{
		pieceState = GROUP_PIECE_PASSED;
	}
	else if (votesAgainst >= GROUPS_MASTER_VOTES)
	{
		pieceState = GROUP_PIECE_FAILED;
	}

	await mysql_aquery_s(g_Mysql,str_format("UPDATE group_masterpieces SET votes_for = %d, votes_against = %d, voters = '%e', state = %d WHERE id = %d",votesFor,votesAgainst,voters,pieceState,pieceid));

	if (pieceState == GROUP_PIECE_PASSED)
	{
		Groups_GrantMastery(maker,trade);
		Groups_Log(group,maker,"masterpiece passed");
	}
	else if (pieceState == GROUP_PIECE_FAILED)
	{
		Groups_Log(group,maker,"masterpiece failed");
		new makerid = Groups_PlayerByCharacter(maker);

		if (makerid != INVALID_PLAYER_ID)
		{
			Groups_ReturnFailedPieces(makerid,maker);
		}
	}

	return async pieceState;
}

async Task:Groups_ReturnFailedPieces(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, group_id, kind, param, stars FROM group_masterpieces WHERE character_id = %d AND state = %d AND returned = 0",characterid,GROUP_PIECE_FAILED));
	new rows = cache_num_rows(), ids[4], pieces[4][4];

	for (new r = 0;r < rows && r < sizeof(ids);r++)
	{
		cache_get_value_name_int(r,"id",ids[r]);
		cache_get_value_name_int(r,"group_id",pieces[r][0]);
		cache_get_value_name_int(r,"kind",pieces[r][1]);
		cache_get_value_name_int(r,"param",pieces[r][2]);
		cache_get_value_name_int(r,"stars",pieces[r][3]);
	}

	new returned = 0;

	for (new r = 0;r < rows && r < sizeof(ids) && IsPlayerConnected(playerid);r++)
	{
		new group = Groups_FindById(pieces[r][0]), store = Groups_GetStore(group), E_ITEM_KIND:kind = E_ITEM_KIND:pieces[r][1];

		if (store != INVALID_CONTAINER_ID && Inventory_CanGive(playerid,kind,pieces[r][2],1,pieces[r][3]) && Container_TakeStars(store,kind,pieces[r][2],1,pieces[r][3]))
		{
			Inventory_Give(playerid,kind,pieces[r][2],1,pieces[r][3]);
			returned++;
		}

		mysql_tquery_s(g_Mysql,str_format("UPDATE group_masterpieces SET returned = 1 WHERE id = %d",ids[r]));
	}

	if (returned > 0)
	{
		Gui_Notify(playerid,"The masters don't pass your masterpiece. It's handed back to you; try again when you're ready.");
	}

	return async returned;
}
#pragma warning pop

stock Groups_OpenRules(playerid,group)
{
	new minStars, floorPercent, ceilingPercent;
	Groups_GetRules(group,minStars,floorPercent,ceilingPercent);
	new bool:canEdit = Groups_IsHead(playerid,group);

	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, tradeName[32], line[96];
		Trade_GetName(Groups_GetTrade(group),tradeName);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"The guild's rules");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 40.0,KIT_ROW * 8.0 + 6.0 + KIT_ROW + 12.0,"The guild's rules",x,y,width);
		format(line,sizeof(line),"Goods of the %s trade sold under the mark fetch %d in a hundred more.",tradeName,GROUPS_MARK_PERCENT);
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 2.0,width * 0.6,"The mark's standard",0,KIT_COLOUR_TEXT,sprintf("%d stars",minStars),KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width * 0.6,"Members never sell below",0,KIT_COLOUR_TEXT,sprintf("%d%% of the trader's price",floorPercent),KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 4.0,width * 0.6,"Nor above",0,KIT_COLOUR_TEXT,sprintf("%d%%",ceilingPercent),KIT_COLOUR_ACCENT);

		if (canEdit)
		{
			Kit_AddButton(playerid,x + width * 0.62,y + KIT_ROW * 2.0,width * 0.18,"-",10,KIT_COLOUR_TEXT);
			Kit_AddButton(playerid,x + width * 0.82,y + KIT_ROW * 2.0,width * 0.18,"+",11,KIT_COLOUR_TEXT);
			Kit_AddButton(playerid,x + width * 0.62,y + KIT_ROW * 3.0,width * 0.18,"-",20,KIT_COLOUR_TEXT);
			Kit_AddButton(playerid,x + width * 0.82,y + KIT_ROW * 3.0,width * 0.18,"+",21,KIT_COLOUR_TEXT);
			Kit_AddButton(playerid,x + width * 0.62,y + KIT_ROW * 4.0,width * 0.18,"-",30,KIT_COLOUR_TEXT);
			Kit_AddButton(playerid,x + width * 0.82,y + KIT_ROW * 4.0,width * 0.18,"+",31,KIT_COLOUR_TEXT);
			Kit_AddChoice(playerid,x,y + KIT_ROW * 6.0,width,"Proclaim the rules to the guild",1,KIT_COLOUR_GOOD);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 8.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !canEdit || !Groups_IsHead(playerid,group))
		{
			return;
		}

		switch (pick)
		{
			case 10: minStars = max(minStars - 1,ITEM_STARS_MIN);
			case 11: minStars = min(minStars + 1,ITEM_STARS_MAX);
			case 20: floorPercent = max(floorPercent - 5,50);
			case 21: floorPercent = min(floorPercent + 5,100);
			case 30: ceilingPercent = max(ceilingPercent - 10,100);
			case 31: ceilingPercent = min(ceilingPercent + 10,200);
			case 1:
			{
				Groups_SetRules(group,minStars,floorPercent,ceilingPercent);
				format(line,sizeof(line),"The guild's mark for %d stars and up; prices between %d%% and %d%% of the trader's.",minStars,floorPercent,ceilingPercent);
				Groups_PostNotice(group,Character_GetId(playerid),line,false);
				Groups_Tell(group,line);
				return;
			}
		}
	}
}

stock Groups_OpenMasterpieces(playerid,group)
{
	for (;;)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT p.id, p.character_id, p.kind, p.param, p.stars, p.votes_for, p.votes_against, p.voters, CONCAT(c.name, ' ', c.surname) AS maker FROM group_masterpieces p LEFT JOIN characters c ON c.id = p.character_id WHERE p.group_id = %d AND p.state = %d ORDER BY p.id LIMIT 6",Groups_GetId(group),GROUP_PIECE_PENDING));

		if (!IsPlayerConnected(playerid))
		{
			return;
		}

		new rows = cache_num_rows(), ids[6], makers[6], labels[6][64], votedMark[16], bool:voted[6], trade = Groups_GetTrade(group);
		format(votedMark,sizeof(votedMark),",%d,",Character_GetId(playerid));

		for (new r = 0;r < rows && r < 6;r++)
		{
			new kind, param, stars, votesFor, votesAgainst, voters[96], maker[44], item[ITEM_NAME_LEN];
			cache_get_value_name_int(r,"id",ids[r]);
			cache_get_value_name_int(r,"character_id",makers[r]);
			cache_get_value_name_int(r,"kind",kind);
			cache_get_value_name_int(r,"param",param);
			cache_get_value_name_int(r,"stars",stars);
			cache_get_value_name_int(r,"votes_for",votesFor);
			cache_get_value_name_int(r,"votes_against",votesAgainst);
			cache_get_value_name(r,"voters",voters);
			cache_get_value_name(r,"maker",maker);
			Item_GetName(E_ITEM_KIND:kind,param,item);
			format(labels[r],64,"%s: %s (%d for, %d against)",maker,item,votesFor,votesAgainst);
			voted[r] = strfind(voters,votedMark) != -1;
		}

		new bool:judge = Groups_IsJudge(playerid,group), bool:canPresent = Groups_CanPresent(playerid,trade), epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, lines = max(rows,1) + 2;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Masterpieces");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 80.0,float(lines) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Masterpieces",x,y,width);

		if (rows == 0)
		{
			Kit_AddText(playerid,x,y,"No masterpiece waits for judgement.",KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		for (new r = 0;r < rows && r < 6;r++)
		{
			if (judge && !voted[r] && makers[r] != Character_GetId(playerid))
			{
				Kit_AddText(playerid,x,y + KIT_ROW * float(r),labels[r],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.6);
				Kit_AddButton(playerid,x + width * 0.62,y + KIT_ROW * float(r),width * 0.18,"Pass",100 + r,KIT_COLOUR_GOOD);
				Kit_AddButton(playerid,x + width * 0.82,y + KIT_ROW * float(r),width * 0.18,"Fail",200 + r,KIT_COLOUR_BAD);
			}
			else
			{
				Kit_AddText(playerid,x,y + KIT_ROW * float(r),labels[r],KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
			}
		}

		if (canPresent)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(max(rows,1) + 1),width,sprintf("Present your masterpiece (%d stars)",GROUPS_MASTERPIECE_STARS),1,KIT_COLOUR_GOOD);
		}
		else
		{
			Kit_AddText(playerid,x,y + KIT_ROW * float(max(rows,1) + 1),sprintf("At level %d, make the trade's masterpiece at %d stars and present it to two masters.",WORK_LEVEL_UNMASTERED,GROUPS_MASTERPIECE_STARS),KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(lines) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			return;
		}

		if (pick >= 100 && pick < 100 + rows)
		{
			await Groups_JudgePiece(playerid,group,ids[pick - 100],true);
			continue;
		}

		if (pick >= 200 && pick < 200 + rows)
		{
			await Groups_JudgePiece(playerid,group,ids[pick - 200],false);
			continue;
		}

		if (pick == 1)
		{
			new index = Groups_PickPiece(playerid,trade), row = 0;

			if (index != -1)
			{
				row = await Groups_PresentPiece(playerid,group,index);
			}

			if (row > 0)
			{
				Gui_Notify(playerid,"Your piece goes before the masters.");
			}
		}
	}
}

stock Groups_PickPiece(playerid,trade)
{
	new slots[8], count = 0;

	for (new index = 0, total = Inventory_GetCount(playerid);index < total && count < sizeof(slots);index++)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (Inventory_GetSlot(playerid,index,kind,param,amount) && Groups_IsPieceOf(kind,param,Inventory_GetSlotStars(playerid,index),trade))
		{
			slots[count++] = index;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,sprintf("You carry no masterpiece of the trade at %d stars. Make it at level %d: it's the longest recipe of the trade.",GROUPS_MASTERPIECE_STARS,WORK_LEVEL_UNMASTERED));
		return -1;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Which piece?");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Which piece?",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new E_ITEM_KIND:kind, param, amount, name[ITEM_NAME_LEN];
		Inventory_GetSlot(playerid,slots[i],kind,param,amount);
		Item_GetName(kind,param,name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return -1;
	}

	return slots[pick];
}

stock Groups_StewardJudges(playerid)
{
	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		if (!Groups_CanPresent(playerid,trade) || Groups_FindGuild(trade) != GROUP_INVALID)
		{
			continue;
		}

		for (new index = 0, total = Inventory_GetCount(playerid);index < total;index++)
		{
			new E_ITEM_KIND:kind, param, amount;

			if (Inventory_GetSlot(playerid,index,kind,param,amount) && Groups_IsPieceOf(kind,param,Inventory_GetSlotStars(playerid,index),trade))
			{
				new name[32];
				Trade_GetName(trade,name);
				Work_SetMastered(playerid,trade,true);
				Gui_Notify(playerid,sprintf("The steward turns the piece over and nods. With no guild of the %s trade here, his word makes you a master of it.",name));
				return 1;
			}
		}
	}

	Gui_Notify(playerid,sprintf("The steward judges a masterpiece made at %d stars by someone at level %d of a trade with no guild here.",GROUPS_MASTERPIECE_STARS,WORK_LEVEL_UNMASTERED));
	return 0;
}

stock bool:Groups_StewardWouldJudge(playerid)
{
	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		if (Groups_CanPresent(playerid,trade) && Groups_FindGuild(trade) == GROUP_INVALID)
		{
			return true;
		}
	}

	return false;
}

Timer_Declare(Groups_TrainTick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid))
		{
			continue;
		}

		new teacher = Groups_FindTeacher(playerid), guild = Groups_FindMineOfKind(playerid,GROUP_KIND_GUILD);

		if (teacher == INVALID_PLAYER_ID)
		{
			if (s_Training[playerid] != INVALID_PLAYER_ID)
			{
				s_Training[playerid] = INVALID_PLAYER_ID;
				Work_SetPracticeBonus(playerid,-1,0);
			}

			continue;
		}

		if (s_Training[playerid] != teacher)
		{
			new name[MAX_PLAYER_NAME];
			Nametag_GetKnownName(playerid,teacher,name);
			Gui_Notify(playerid,sprintf("Working beside %s, a master of your guild, you learn faster.",name));
		}

		s_Training[playerid] = teacher;
		Work_SetPracticeBonus(playerid,Groups_GetTrade(guild),GROUPS_TRAIN_PERCENT);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Training[playerid] = INVALID_PLAYER_ID;
}

hook Groups_OnRefreshed(playerid)
{
	Groups_UpdateMark(playerid);
}

hook Groups_OnMemberLoaded(playerid)
{
	Groups_ReturnFailedPieces(playerid,Character_GetId(playerid));
}
