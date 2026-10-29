forward Task:Groups_SignContract(group,clientid,const terms[],pay);

#pragma warning push
#pragma warning disable 204
async Task:Groups_SignContract(group,clientid,const terms[],pay)
{
	new upfront = pay / 2;

	if (!Groups_IsValid(group) || pay <= 0 || (upfront > 0 && Economy_Pay(clientid,upfront,Groups_GetTreasury(group),"contract") != PAY_OK))
	{
		wait_ticks(1);
		return async 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO contracts (group_id, client_character_id, terms, pay, upfront, state, created_at, settled_at) VALUES (%d, %d, '%e', %d, %d, %d, %d, 0)",Groups_GetId(group),Character_GetId(clientid),terms,pay,upfront,GROUP_CONTRACT_SIGNED,gettime()));
	new id = cache_insert_id();
	Groups_Log(group,Character_GetId(clientid),sprintf("signed contract %d for %d pf",id,pay));
	return async id;
}
#pragma warning pop

stock Groups_SetContractState(contractid,contractState)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE contracts SET state = %d, settled_at = %d WHERE id = %d",contractState,gettime(),contractid));
}

static Groups_OfferContract(playerid,group)
{
	new nearby[8], count = Groups_Nearby(playerid,nearby), clients[8], clientCount = 0;

	for (new i = 0;i < count;i++)
	{
		if (!Groups_IsMember(nearby[i],group))
		{
			clients[clientCount++] = nearby[i];
		}
	}

	if (clientCount == 0)
	{
		Gui_Notify(playerid,"Have the one who'd hire you stand beside you.");
		return;
	}

	new clientid = Groups_PickNearby(playerid,"Who hires you?",clients,clientCount), terms[GROUPS_TERMS_LEN], payText[12];

	if (clientid == INVALID_PLAYER_ID || !Groups_AskText(playerid,"The terms","Write the terms: what the band does, where and until when.",terms,sizeof(terms)) || strlen(terms) < 8)
	{
		return;
	}

	if (!Groups_AskText(playerid,"The pay","How many pfennig in all? Half is paid on signing.",payText,sizeof(payText)))
	{
		return;
	}

	new pay = strval(payText);

	if (pay < 2 || pay > 48000)
	{
		Gui_Notify(playerid,"Name a pay between 2 pfennig and 200 gulden.");
		return;
	}

	new name[GROUPS_NAME_LEN], money[24], half[24], text[256];
	Groups_GetName(group,name);
	Economy_Format(pay,money);
	Economy_Format(pay / 2,half);
	format(text,sizeof(text),"%s offer a contract: %s~n~~n~Pay %s, %s of it now.",name,terms,money,half);

	if (!IsPlayerConnected(clientid) || !Groups_AskConsent(clientid,"A contract",text,"Sign","Refuse"))
	{
		Gui_Notify(playerid,"They don't sign.");
		return;
	}

	new id = await Groups_SignContract(group,clientid,terms,pay);

	if (id > 0)
	{
		Gui_Notify(playerid,sprintf("The contract is signed and %s is in the treasury.",half));
		Gui_Notify(clientid,"You sign and pay the first half.");
	}
	else
	{
		Gui_Notify(playerid,"They can't pay the first half.");
	}
}

static Groups_SettleContract(playerid,group,contractid,clientCharacter,pay,upfront)
{
	new clientid = Groups_PlayerByCharacter(clientCharacter);

	if (!Groups_IsBeside(playerid,clientid))
	{
		Gui_Notify(playerid,"The client must stand beside you to settle.");
		return;
	}

	new rest = pay - upfront, money[24], text[160];
	Economy_Format(rest,money);
	format(text,sizeof(text),"The band says the work is done. Pay the rest, %s, as agreed? If you refuse, the matter goes to the staff.",money);

	if (!Groups_AskConsent(clientid,"Settle the contract",text,"Pay","Refuse"))
	{
		Groups_SetContractState(contractid,GROUP_CONTRACT_DISPUTED);
		Groups_Log(group,clientCharacter,sprintf("disputed contract %d",contractid));
		Gui_Notify(playerid,"They refuse to pay. The contract is disputed; the staff will look at it.");
		return;
	}

	if (rest > 0 && Economy_Pay(clientid,rest,Groups_GetTreasury(group),"contract") != PAY_OK)
	{
		Gui_Notify(playerid,"They can't pay the rest now.");
		return;
	}

	Groups_SetContractState(contractid,GROUP_CONTRACT_FULFILLED);
	Groups_Log(group,clientCharacter,sprintf("settled contract %d",contractid));
	Gui_Notify(playerid,"The contract is settled and paid.");
}

static Groups_ReleaseContract(playerid,group,contractid,clientCharacter,upfront)
{
	new clientid = Groups_PlayerByCharacter(clientCharacter);

	if (upfront > 0 && !Groups_IsBeside(playerid,clientid))
	{
		Gui_Notify(playerid,"To release a client, hand back what they paid: they must stand beside you.");
		return;
	}

	if (upfront > 0 && !Groups_PayOut(group,clientid,upfront,"contract released"))
	{
		Gui_Notify(playerid,"The treasury can't give back what was paid.");
		return;
	}

	Groups_SetContractState(contractid,GROUP_CONTRACT_CANCELLED);
	Groups_Log(group,clientCharacter,sprintf("released contract %d",contractid));
	Gui_Notify(playerid,"The client is released and paid back.");
}

stock Groups_OpenContracts(playerid,group)
{
	for (;;)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT k.id, k.client_character_id, k.terms, k.pay, k.upfront, k.state, CONCAT(c.name, ' ', c.surname) AS client FROM contracts k LEFT JOIN characters c ON c.id = k.client_character_id WHERE k.group_id = %d ORDER BY (k.state = %d) DESC, k.id DESC LIMIT 6",Groups_GetId(group),GROUP_CONTRACT_SIGNED));

		if (!IsPlayerConnected(playerid))
		{
			return;
		}

		new rows = cache_num_rows(), ids[6], clients[6], pays[6], upfronts[6], states[6], labels[6][GROUPS_TERMS_LEN], names[6][44];

		for (new r = 0;r < rows && r < 6;r++)
		{
			cache_get_value_name_int(r,"id",ids[r]);
			cache_get_value_name_int(r,"client_character_id",clients[r]);
			cache_get_value_name(r,"terms",labels[r]);
			cache_get_value_name_int(r,"pay",pays[r]);
			cache_get_value_name_int(r,"upfront",upfronts[r]);
			cache_get_value_name_int(r,"state",states[r]);
			cache_get_value_name(r,"client",names[r]);
		}

		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, lines = rows * 2 + 2;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Contracts");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,GROUPS_PANEL_WIDTH + 80.0,float(lines) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Contracts",x,y,width);

		for (new r = 0;r < rows && r < 6;r++)
		{
			new money[24], line[96];
			Economy_Format(pays[r],money);
			format(line,sizeof(line),"%s, %s, %s",names[r],money,g_GroupContractStates[Util_ClampInt(states[r],0,GROUP_CONTRACT_STATES - 1)]);
			Kit_AddText(playerid,x,y + KIT_ROW * float(r * 2),labels[r],KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

			if (states[r] == GROUP_CONTRACT_SIGNED)
			{
				Kit_AddText(playerid,x,y + KIT_ROW * float(r * 2 + 1),line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width * 0.5);
				Kit_AddButton(playerid,x + width * 0.52,y + KIT_ROW * float(r * 2 + 1),width * 0.23,"Settle",100 + r,KIT_COLOUR_GOOD);
				Kit_AddButton(playerid,x + width * 0.77,y + KIT_ROW * float(r * 2 + 1),width * 0.23,"Release",200 + r,KIT_COLOUR_BAD);
			}
			else
			{
				Kit_AddText(playerid,x,y + KIT_ROW * float(r * 2 + 1),line,KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
			}
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows * 2),width,"Offer a contract to someone beside you",1,KIT_COLOUR_GOOD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(lines) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Groups_HasPerm(playerid,group,GROUP_PERM_CONTRACTS))
		{
			return;
		}

		if (pick == 1)
		{
			Groups_OfferContract(playerid,group);
		}
		else if (pick >= 100 && pick < 100 + rows)
		{
			Groups_SettleContract(playerid,group,ids[pick - 100],clients[pick - 100],pays[pick - 100],upfronts[pick - 100]);
		}
		else if (pick >= 200 && pick < 200 + rows)
		{
			Groups_ReleaseContract(playerid,group,ids[pick - 200],clients[pick - 200],upfronts[pick - 200]);
		}
	}
}
