static s_LettersInkUses[MAX_PLAYERS];
static s_LettersWaxUses[MAX_PLAYERS];

stock bool:Letters_CanRead(playerid)
{
	return Util_IsValidPlayer(playerid);
}

stock bool:Letters_IsLetter(param)
{
	return param == ITEM_LETTER || param == ITEM_LETTER_SEALED || param == ITEM_LETTER_OPENED;
}

stock bool:Letters_HasWritingKit(playerid,bool:notify = false)
{
	new missing[64];
	missing[0] = EOS;

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_PARCHMENT),ITEM_PARCHMENT) < 1)
	{
		strcat(missing,"a parchment sheet");
	}

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_INK),ITEM_INK) < 1)
	{
		strcat(missing,missing[0] != EOS ? (", ink") : ("ink"));
	}

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_QUILL),ITEM_QUILL) < 1)
	{
		strcat(missing,missing[0] != EOS ? (" and a quill") : ("a quill"));
	}

	if (missing[0] == EOS)
	{
		return true;
	}

	if (notify)
	{
		new text[128];
		format(text,sizeof(text),"To write a letter you need parchment, ink and a quill. You're missing %s.",missing);
		Gui_Notify(playerid,text);
	}

	return false;
}

forward Task:Letters_Save(characterid,const to[],const body[]);
#pragma warning push
#pragma warning disable 204
async Task:Letters_Save(characterid,const to[],const body[])
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO writings (author_character_id, kind, title, body, seal_broken, created_at) VALUES (%d, %d, '%e', '%e', 0, %d)",characterid,WRITING_KIND_LETTER,to,body,gettime()));
	return async cache_insert_id();
}
#pragma warning pop

stock Letters_GiveLetter(playerid,param,writing)
{
	if (!Inventory_Give(playerid,Item_GetDefKind(param),param,1,ITEM_STARS_MIN,ITEM_FRESH_NOW,0,writing))
	{
		Claims_Give(Character_GetId(playerid),Item_GetDefKind(param),param,1,ITEM_STARS_MIN,"letter",ITEM_FRESH_NOW,0,writing);
		Gui_Notify(playerid,"Your bag is full. The letter waits for you under Claims.");
	}
}

static bool:Letters_AskLine(playerid,token,const title[],const prompt[],dest[],maxLength,size = sizeof(dest))
{
	new response[DIALOG_RESPONSE], body[320];
	format(body,sizeof(body),GUI_TEXT "%s\n\n" GUI_MUTED "At most %d letters. Leave it empty to clear the line.",prompt,maxLength);
	await_arr(response) ShowAsyncDialog(playerid,DIALOG_STYLE_INPUT,title,body,GUI_BUTTON_OKAY,GUI_BUTTON_BACK);

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !response[DIALOG_RESPONSE_RESPONSE])
	{
		return false;
	}

	strcopy(dest,response[DIALOG_RESPONSE_INPUTTEXT],size);

	if (strlen(dest) > maxLength)
	{
		dest[maxLength] = EOS;
		Gui_Notify(playerid,"That line was too long for the page. The end of it was cut.");
	}

	for (new i = 0;dest[i] != EOS;i++)
	{
		if (dest[i] == '~' || dest[i] == '{' || dest[i] == '}')
		{
			dest[i] = ' ';
		}
	}

	return true;
}

stock Letters_Write(playerid)
{
	if (!Letters_HasWritingKit(playerid,true))
	{
		return;
	}

	if (!Letters_CanRead(playerid))
	{
		Gui_Notify(playerid,"You can't write. Someone who can will have to write it for you.");
		return;
	}

	new token = Account_GetToken(playerid), to[LETTERS_TO_LEN], lines[LETTERS_LINES][LETTERS_LINE_LEN];
	to[0] = EOS;

	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, used = 0;

		for (new i = 0;i < LETTERS_LINES;i++)
		{
			if (lines[i][0] != EOS)
			{
				used = i + 1;
			}
		}

		Kit_Begin(playerid,KIT_LAYER_SCREEN,"A letter");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LETTERS_PANEL_WIDTH,float(LETTERS_LINES + 4) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"A letter",x,y,width);
		Kit_AddChoice(playerid,x,y,width,to[0] != EOS ? to : ("To whom? (click to address it)"),LETTERS_PICK_TO,to[0] != EOS ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);

		for (new i = 0;i < LETTERS_LINES;i++)
		{
			new label[LETTERS_LINE_LEN + 8];

			if (lines[i][0] != EOS)
			{
				strcopy(label,lines[i]);
			}
			else
			{
				format(label,sizeof(label),i <= used ? ("line %d: click to write") : ("line %d"),i + 1);
			}

			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1) + 4.0,width,label,i,lines[i][0] != EOS ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(LETTERS_LINES + 2),width,"Fold the letter",LETTERS_PICK_FOLD,used > 0 && to[0] != EOS ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(LETTERS_LINES + 3),width,"Tear it up",LETTERS_PICK_TEAR,KIT_COLOUR_BAD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(LETTERS_LINES + 4) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick == LETTERS_PICK_TEAR || !IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
		{
			if (pick == LETTERS_PICK_TEAR)
			{
				Gui_Notify(playerid,"You tear the page up. The parchment is still good for another try.");
			}

			return;
		}

		if (pick == LETTERS_PICK_TO)
		{
			Letters_AskLine(playerid,token,"Address","Who is the letter for? Write it the way you'd address it, for example: Jakub Brabec, Talmberg.",to,LETTERS_TO_LEN - 1);
			continue;
		}

		if (pick >= 0 && pick < LETTERS_LINES)
		{
			new prompt[48];
			format(prompt,sizeof(prompt),"Line %d of the letter.",pick + 1);
			Letters_AskLine(playerid,token,"A letter",prompt,lines[pick],LETTERS_LINE_LEN - 1);
			continue;
		}

		if (pick != LETTERS_PICK_FOLD)
		{
			continue;
		}

		if (to[0] == EOS || used == 0)
		{
			Gui_Notify(playerid,"Address the letter and write at least one line before you fold it.");
			continue;
		}

		break;
	}

	if (!Letters_HasWritingKit(playerid,true))
	{
		return;
	}

	new body[LETTERS_BODY_LEN];
	body[0] = EOS;

	for (new i = 0;i < LETTERS_LINES;i++)
	{
		if (i > 0)
		{
			strcat(body,"|");
		}

		strcat(body,lines[i]);
	}

	new writing = await Letters_Save(Character_GetId(playerid),to,body);

	if (writing <= 0 || !IsPlayerConnected(playerid))
	{
		return;
	}

	Inventory_Take(playerid,Item_GetDefKind(ITEM_PARCHMENT),ITEM_PARCHMENT,1);

	if (++s_LettersInkUses[playerid] >= LETTERS_INK_EVERY)
	{
		s_LettersInkUses[playerid] = 0;
		Inventory_Take(playerid,Item_GetDefKind(ITEM_INK),ITEM_INK,1);
		Gui_Notify(playerid,"Your ink pot runs dry.");
	}

	Letters_GiveLetter(playerid,ITEM_LETTER,writing);
	Gui_Notify(playerid,"You fold the letter. Seal it with a signet ring and wax, hand it over or give it to a courier.");
	pawn_call_public("Letters_OnWritten","dd",playerid,writing);
}

stock bool:Letters_Seal(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || param != ITEM_LETTER)
	{
		return false;
	}

	if (Inventory_Count(playerid,Item_GetDefKind(ITEM_SEAL_RING),ITEM_SEAL_RING) < 1 || Inventory_Count(playerid,Item_GetDefKind(ITEM_WAX),ITEM_WAX) < 1)
	{
		Gui_Notify(playerid,"To seal a letter you need a signet ring and a cake of wax.");
		return false;
	}

	new writing = Inventory_GetSlotData(playerid,index);
	Inventory_TakeSlot(playerid,index,1);

	if (++s_LettersWaxUses[playerid] >= LETTERS_WAX_EVERY)
	{
		s_LettersWaxUses[playerid] = 0;
		Inventory_Take(playerid,Item_GetDefKind(ITEM_WAX),ITEM_WAX,1);
	}

	Letters_GiveLetter(playerid,ITEM_LETTER_SEALED,writing);
	mysql_tquery_s(g_Mysql,str_format("UPDATE writings SET sealed_by = %d, seal_broken = 0 WHERE id = %d",Character_GetId(playerid),writing));
	Gui_Notify(playerid,"You drip wax on the flap and press your signet into it. Whoever opens it will break your seal.");
	return true;
}

stock bool:Letters_BreakSeal(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || param != ITEM_LETTER_SEALED)
	{
		return false;
	}

	new writing = Inventory_GetSlotData(playerid,index);
	Inventory_TakeSlot(playerid,index,1);
	Letters_GiveLetter(playerid,ITEM_LETTER_OPENED,writing);
	mysql_tquery_s(g_Mysql,str_format("UPDATE writings SET seal_broken = 1 WHERE id = %d",writing));
	return true;
}

static s_FetchedTo[LETTERS_TO_LEN];
static s_FetchedBody[LETTERS_BODY_LEN];
static s_FetchedAuthor[48];
static s_FetchedSealer[48];
static s_FetchedBroken;

forward Task:Letters_Fetch(writing);
#pragma warning push
#pragma warning disable 204
async Task:Letters_Fetch(writing)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT w.title, w.body, w.seal_broken, IFNULL(CONCAT(a.name, ' ', a.surname), '') AS author, IFNULL(CONCAT(s.name, ' ', s.surname), '') AS sealer FROM writings w LEFT JOIN characters a ON a.id = w.author_character_id LEFT JOIN characters s ON s.id = w.sealed_by WHERE w.id = %d",writing));

	if (cache_num_rows() == 0)
	{
		return async 0;
	}

	cache_get_value_name(0,"title",s_FetchedTo,LETTERS_TO_LEN);
	cache_get_value_name(0,"body",s_FetchedBody,LETTERS_BODY_LEN);
	cache_get_value_name(0,"author",s_FetchedAuthor,sizeof(s_FetchedAuthor));
	cache_get_value_name(0,"sealer",s_FetchedSealer,sizeof(s_FetchedSealer));
	cache_get_value_name_int(0,"seal_broken",s_FetchedBroken);
	return async 1;
}
#pragma warning pop

stock Letters_TakeFetched(to[],body[],author[],sealer[],&broken,toSize = sizeof(to),bodySize = sizeof(body),authorSize = sizeof(author),sealerSize = sizeof(sealer))
{
	strcopy(to,s_FetchedTo,toSize);
	strcopy(body,s_FetchedBody,bodySize);
	strcopy(author,s_FetchedAuthor,authorSize);
	strcopy(sealer,s_FetchedSealer,sealerSize);
	broken = s_FetchedBroken;
}

stock Letters_SplitLines(const text[],lines[][],maxLines,lineSize)
{
	new count = 0, start = 0, length = strlen(text);

	for (new i = 0;i <= length && count < maxLines;i++)
	{
		if (text[i] == '|' || text[i] == EOS)
		{
			strmid(lines[count],text,start,i,lineSize);
			count++;
			start = i + 1;
		}
	}

	while (count > 0 && lines[count - 1][0] == EOS)
	{
		count--;
	}

	return count;
}

stock Letters_Read(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || !Letters_IsLetter(param))
	{
		return;
	}

	new writing = Inventory_GetSlotData(playerid,index), bool:wasSealed = param == ITEM_LETTER_SEALED;

	if (!Letters_CanRead(playerid))
	{
		Gui_Notify(playerid,"You can't read. Ask someone who can to read it out to you.");
		return;
	}

	if (wasSealed)
	{
		Letters_BreakSeal(playerid,index);
		Gui_Notify(playerid,"You break the seal.");
	}

	new to[LETTERS_TO_LEN], body[LETTERS_BODY_LEN], author[48], sealer[48], broken;

	if (!(await Letters_Fetch(writing)) || !IsPlayerConnected(playerid))
	{
		Gui_Notify(playerid,"The ink has run. You can't make out a word.");
		return;
	}

	Letters_TakeFetched(to,body,author,sealer,broken);

	new lines[LETTERS_LINES][LETTERS_LINE_LEN + 8], count = Letters_SplitLines(body,lines,sizeof(lines),sizeof(lines[])), seal[96], Float:x, Float:y, Float:width;

	if (sealer[0] != EOS)
	{
		format(seal,sizeof(seal),wasSealed ? ("You broke the seal of %s.") : ("The seal of %s is broken."),sealer);
	}
	else
	{
		strcopy(seal,"It was never sealed.");
	}

	new epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,to);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LETTERS_PANEL_WIDTH,float(count + 4) * KIT_ROW + 6.0 + KIT_ROW + 12.0,to,x,y,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * float(i),lines[i]);
	}

	if (author[0] != EOS)
	{
		new signed[64];
		format(signed,sizeof(signed),"- %s",author);
		Kit_AddText(playerid,x,y + KIT_ROW * float(count + 1),signed,KIT_COLOUR_ACCENT);
	}

	Kit_AddText(playerid,x,y + KIT_ROW * float(count + 2),seal,KIT_COLOUR_MUTED);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count + 4) * KIT_ROW + 8.0,80.0,"Fold it",KIT_BACK);
	await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

stock Letters_OpenLetterMenu(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || !Letters_IsLetter(param))
	{
		return;
	}

	if (param != ITEM_LETTER)
	{
		Letters_Read(playerid,index);
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Letter");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,200.0,2.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Letter",x,y,width);
	Kit_AddChoice(playerid,x,y,width,"Read it",1);
	Kit_AddChoice(playerid,x,y + KIT_ROW,width,"Seal it with your signet",2);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 2.0 * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return;
	}

	if (pick == 1)
	{
		Letters_Read(playerid,index);
	}
	else
	{
		Letters_Seal(playerid,index);
	}
}

forward Letters_WriteDeferred(playerid);

public Letters_WriteDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Letters_Write(playerid);
	}

	return 1;
}

forward Letters_MenuDeferred(playerid,index);

public Letters_MenuDeferred(playerid,index)
{
	if (IsPlayerConnected(playerid))
	{
		Letters_OpenLetterMenu(playerid,index);
	}

	return 1;
}

forward Letters_OnWritten(playerid,writing);

public Letters_OnWritten(playerid,writing)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LettersInkUses[playerid] = 0;
	s_LettersWaxUses[playerid] = 0;
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars, kind

	if (param == ITEM_PARCHMENT && E_ITEM_KIND:kind == Item_GetDefKind(ITEM_PARCHMENT))
	{
		Inventory_CloseBagAfterUse(playerid);
		SetTimerEx("Letters_WriteDeferred",0,false,"d",playerid);
		return;
	}

	if (Letters_IsLetter(param) && E_ITEM_KIND:kind == Item_GetDefKind(param))
	{
		Inventory_CloseBagAfterUse(playerid);
		SetTimerEx("Letters_MenuDeferred",0,false,"dd",playerid,index);
	}
}
