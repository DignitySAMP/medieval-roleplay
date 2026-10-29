new const g_LettersCourierNames[][2][16] = {
	{"Vit", "Posel"},
	{"Hanka", "Poslova"}
};

static STREAMER_TAG_OBJECT:s_LettersPostTables[sizeof(g_LettersPostDefs)];
static s_LettersPostActors[sizeof(g_LettersPostDefs)] = {-1, ...};
static STREAMER_TAG_3D_TEXT_LABEL:s_LettersPostLabels[sizeof(g_LettersPostDefs)];

stock Letters_PlacePosts()
{
	for (new post = 0;post < LETTERS_SEED_POSTS;post++)
	{
		new key[ACTORS_KEY_LEN], name[ACTORS_NAME_LEN], sex = post % 2;
		s_LettersPostTables[post] = CreateDynamicObject(MODEL_WRITING_LEDGER_LECTERN,g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][0],g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][1],g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][2],0.0,0.0,g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][3],0,0,-1,120.0);
		s_LettersPostLabels[post] = CreateDynamic3DTextLabel("Courier's table\n{9C8D74}letters carried for 3 pfennig",0xD8CCB2FF,g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][0],g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][1],g_LettersPostDefs[post][E_LETTERS_POST_DEF_TABLE][2] + 1.7,8.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
		format(key,sizeof(key),"post:%d",post);
		format(name,sizeof(name),"%s %s",g_LettersCourierNames[post % sizeof(g_LettersCourierNames)][0],g_LettersCourierNames[post % sizeof(g_LettersCourierNames)][1]);
		new count = Skins_CountStarter(sex), actor = Actors_Register(key,ACTOR_ROLE_COURIER,ACTOR_KIND_STATIC,sex,count > 0 ? Skins_GetStarter(sex,(post * 5) % count) : 1,name,"courier");

		if (actor == -1)
		{
			continue;
		}

		s_LettersPostActors[post] = actor;
		Actors_SetPlace(actor,g_LettersPostDefs[post][E_LETTERS_POST_DEF_COURIER][0],g_LettersPostDefs[post][E_LETTERS_POST_DEF_COURIER][1],g_LettersPostDefs[post][E_LETTERS_POST_DEF_COURIER][2] + 1.0,g_LettersPostDefs[post][E_LETTERS_POST_DEF_COURIER][3],0,0);
		Actors_SetAnim(actor,"COP_AMBIENT","Coplook_loop",true);
		Actors_Place(actor);
	}
}

stock Letters_FindPostOfActor(actor)
{
	for (new post = 0;post < LETTERS_SEED_POSTS;post++)
	{
		if (s_LettersPostActors[post] == actor && actor != -1)
		{
			return post;
		}
	}

	return -1;
}

stock Letters_PlayerOfCharacter(characterid)
{
	foreach (new playerid : Player)
	{
		if (Character_GetId(playerid) == characterid)
		{
			return playerid;
		}
	}

	return INVALID_PLAYER_ID;
}

forward Task:Letters_FindCharacter(const fullName[]);
#pragma warning push
#pragma warning disable 204
async Task:Letters_FindCharacter(const fullName[])
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id FROM characters WHERE alive = 1 AND CONCAT(name, ' ', surname) = '%e' LIMIT 1",fullName));

	if (cache_num_rows() == 0)
	{
		return async 0;
	}

	new id;
	cache_get_value_name_int(0,"id",id);
	return async id;
}
#pragma warning pop

stock bool:Letters_Dispatch(playerid,index,toCharacter,delaySeconds = LETTERS_COURIER_SECONDS)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || !Letters_IsLetter(param) || toCharacter <= 0)
	{
		return false;
	}

	new writing = Inventory_GetSlotData(playerid,index);
	Inventory_TakeSlot(playerid,index,1);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO couriers (letter_writing_id, item, from_character_id, from_x, from_y, to_character_id, due_at, state) VALUES (%d, %d, %d, 0, 0, %d, %d, %d)",writing,param,Character_GetId(playerid),toCharacter,gettime() + delaySeconds,COURIER_STATE_ON_THE_ROAD));
	pawn_call_public("Letters_OnDispatched","ddd",playerid,writing,toCharacter);
	return true;
}

stock Letters_Deliver(writing,param,toCharacter)
{
	new playerid = Letters_PlayerOfCharacter(toCharacter);

	if (playerid != INVALID_PLAYER_ID && Session_IsPlaying(playerid))
	{
		Letters_GiveLetter(playerid,param,writing);
		Gui_Notify(playerid,"A courier finds you and hands you a letter. It's in your bag.");
		return;
	}

	Claims_Give(toCharacter,Item_GetDefKind(param),param,1,ITEM_STARS_MIN,"letter",ITEM_FRESH_NOW,0,writing);
}

forward Task:Letters_DeliverDue();
#pragma warning push
#pragma warning disable 204
async Task:Letters_DeliverDue()
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, letter_writing_id, item, to_character_id FROM couriers WHERE state = %d AND due_at <= %d ORDER BY due_at LIMIT 25",COURIER_STATE_ON_THE_ROAD,gettime()));
	new rows = cache_num_rows(), ids[25], writings[25], items[25], targets[25];

	for (new row = 0;row < rows && row < sizeof(ids);row++)
	{
		cache_get_value_name_int(row,"id",ids[row]);
		cache_get_value_name_int(row,"letter_writing_id",writings[row]);
		cache_get_value_name_int(row,"item",items[row]);
		cache_get_value_name_int(row,"to_character_id",targets[row]);
	}

	for (new row = 0;row < rows && row < sizeof(ids);row++)
	{
		await mysql_aquery_s(g_Mysql,str_format("UPDATE couriers SET state = %d WHERE id = %d AND state = %d",COURIER_STATE_DELIVERED,ids[row],COURIER_STATE_ON_THE_ROAD));

		if (cache_affected_rows() > 0 && Letters_IsLetter(items[row]))
		{
			Letters_Deliver(writings[row],items[row],targets[row]);
		}
	}

	return async rows;
}
#pragma warning pop

stock Letters_OpenSend(playerid,actor)
{
	new slots[16], writings[16], params[16], count = 0;

	for (new index = 0;index < INVENTORY_SLOTS && count < sizeof(slots);index++)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (Inventory_GetSlot(playerid,index,kind,param,amount) && Letters_IsLetter(param))
		{
			slots[count] = index;
			params[count] = param;
			writings[count++] = Inventory_GetSlotData(playerid,index);
		}
	}

	if (count == 0)
	{
		Actors_Say(actor,"You've no letter for me to carry. Write one first.");
		return;
	}

	new String:query = str_new("SELECT id, title FROM writings WHERE id IN (");

	for (new i = 0;i < count;i++)
	{
		str_append_format(query,"%s%d",i == 0 ? ("") : (", "),writings[i]);
	}

	str_append_format(query,")");
	await mysql_aquery_s(g_Mysql,query);
	new titles[16][LETTERS_TO_LEN];

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new id, title[LETTERS_TO_LEN];
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name(row,"title",title);

		for (new i = 0;i < count;i++)
		{
			if (writings[i] == id)
			{
				strcopy(titles[i],title);
			}
		}
	}

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), name[ACTORS_NAME_LEN], money[24], Float:x, Float:y, Float:width;
	Actors_GetName(actor,name);
	Economy_Format(LETTERS_COURIER_PRICE,money);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LETTERS_PANEL_WIDTH,float(count + 1) * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);

	new head[64];
	format(head,sizeof(head),"Which letter? Carrying it costs %s.",money);
	Kit_AddText(playerid,x,y,head,KIT_COLOUR_MUTED);

	for (new i = 0;i < count;i++)
	{
		new label[LETTERS_TO_LEN + 16];
		format(label,sizeof(label),"%s%s",titles[i][0] != EOS ? titles[i] : ("A letter"),params[i] == ITEM_LETTER_SEALED ? (" (sealed)") : (params[i] == ITEM_LETTER_OPENED ? (" (opened)") : ("")));
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1),width,label,i);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count + 1) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return;
	}

	new token = Account_GetToken(playerid), response[DIALOG_RESPONSE];
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,"The courier",GUI_TEXT "Who should the courier find? Give their full name.\n\n" GUI_MUTED "First name and family name, for example: Jakub Brabec.",GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE] || response[DIALOG_RESPONSE_INPUTTEXT][0] == EOS)
	{
		return;
	}

	new target = await Letters_FindCharacter(response[DIALOG_RESPONSE_INPUTTEXT]);

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	if (target <= 0)
	{
		Actors_Say(actor,"I don't know anyone by that name. Nobody does, I'd wager.");
		return;
	}

	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,slots[pick],kind,param,amount) || !Letters_IsLetter(param) || Inventory_GetSlotData(playerid,slots[pick]) != writings[pick])
	{
		Gui_Notify(playerid,"That letter isn't in your bag any more.");
		return;
	}

	if (Economy_Pay(playerid,LETTERS_COURIER_PRICE,INVALID_CONTAINER_ID,"courier") != PAY_OK)
	{
		Actors_Say(actor,"Three pfennig, friend. I don't walk for free.");
		return;
	}

	Letters_Dispatch(playerid,slots[pick],target);
	Actors_Say(actor,"I'll find them. It'll be in their hands within the hour.");
}

Timer_Declare(Letters_CourierTick)
{
	if (Boot_IsFinished())
	{
		Letters_DeliverDue();
	}

	return 1;
}

forward Letters_MenuSend(playerid,index,data);

public Letters_MenuSend(playerid,index,data)
{
	#pragma unused data

	if (IsPlayerConnected(playerid))
	{
		Letters_OpenSend(playerid,index);
	}

	return 1;
}

forward Letters_OnDispatched(playerid,writing,toCharacter);

public Letters_OnDispatched(playerid,writing,toCharacter)
{
	return 1;
}

#include <pp-hooks>

hook Actors_OnMenuBuild(playerid,index)
{
	if (Letters_FindPostOfActor(index) == -1)
	{
		return;
	}

	new label[48], money[24];
	Economy_Format(LETTERS_COURIER_PRICE,money);
	format(label,sizeof(label),"Send a letter (%s)",money);
	Actors_MenuAdd(playerid,label,"Letters_MenuSend",0,KIT_COLOUR_GOOD);
}
