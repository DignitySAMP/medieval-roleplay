enum E_INV_SLOT
{
	E_INV_ROW,
	E_INV_SERIAL,
	E_ITEM_KIND:E_INV_KIND,
	E_INV_PARAM,
	E_INV_AMOUNT,
	E_INV_STARS,
	E_INV_USED,
	E_INV_FRESH_AT,
	E_INV_WEAR,
	E_INV_DATA,
}

static s_Inventory[MAX_PLAYERS][INVENTORY_SLOTS][E_INV_SLOT];
static s_InventoryCount[MAX_PLAYERS];
new g_InventorySerial;
static bool:s_InventoryLoaded[MAX_PLAYERS];

stock bool:Inventory_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_InventoryLoaded[playerid];
}

stock Inventory_GetCount(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_InventoryCount[playerid] : 0;
}

stock bool:Inventory_GetSlot(playerid,index,&E_ITEM_KIND:kind,&param,&amount)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid])
	{
		return false;
	}

	kind = s_Inventory[playerid][index][E_INV_KIND];
	param = s_Inventory[playerid][index][E_INV_PARAM];
	amount = s_Inventory[playerid][index][E_INV_AMOUNT];
	return true;
}

stock Inventory_GetSlotUsed(playerid,index)
{
	return Util_IsValidPlayer(playerid) && index >= 0 && index < s_InventoryCount[playerid] ? s_Inventory[playerid][index][E_INV_USED] : 0;
}

stock Inventory_GetSlotFresh(playerid,index)
{
	return Util_IsValidPlayer(playerid) && index >= 0 && index < s_InventoryCount[playerid] ? s_Inventory[playerid][index][E_INV_FRESH_AT] : 0;
}

stock Inventory_GetSlotWear(playerid,index)
{
	return Util_IsValidPlayer(playerid) && index >= 0 && index < s_InventoryCount[playerid] ? s_Inventory[playerid][index][E_INV_WEAR] : 0;
}

stock Inventory_GetSlotData(playerid,index)
{
	return Util_IsValidPlayer(playerid) && index >= 0 && index < s_InventoryCount[playerid] ? s_Inventory[playerid][index][E_INV_DATA] : 0;
}

stock Inventory_SetSlotData(playerid,index,data)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid])
	{
		return;
	}

	s_Inventory[playerid][index][E_INV_DATA] = data;
	Inventory_Persist(playerid,index);
}

stock Inventory_FormatWearToData(dest[],const table[],const params[],count,size = sizeof(dest))
{
	format(dest,size,"UPDATE %s SET data = wear, wear = 0 WHERE data = 0 AND wear > 0 AND param IN (",table);

	for (new i = 0;i < count;i++)
	{
		format(dest,size,"%s%s%d",dest,i == 0 ? ("") : (", "),params[i]);
	}

	strcat(dest,")",size);
}

stock Inventory_SetSlotWear(playerid,index,wear)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid])
	{
		return;
	}

	s_Inventory[playerid][index][E_INV_WEAR] = Util_ClampInt(wear,0,ITEM_WEAR_MAX);
	Inventory_Persist(playerid,index);
}

stock Inventory_GetSlotStars(playerid,index)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid])
	{
		return ITEM_STARS_ANY;
	}

	return s_Inventory[playerid][index][E_INV_STARS];
}

static bool:Inventory_SlotMatches(playerid,index,E_ITEM_KIND:kind,param,stars)
{
	return s_Inventory[playerid][index][E_INV_KIND] == kind && s_Inventory[playerid][index][E_INV_PARAM] == param && (stars == ITEM_STARS_ANY || s_Inventory[playerid][index][E_INV_STARS] == stars);
}

stock Inventory_Find(playerid,E_ITEM_KIND:kind,param,stars = ITEM_STARS_ANY)
{
	for (new i = 0; i < s_InventoryCount[playerid]; i++)
	{
		if (Inventory_SlotMatches(playerid,i,kind,param,stars))
		{
			return i;
		}
	}

	return -1;
}

stock Inventory_OldestFresh(playerid,E_ITEM_KIND:kind,param,stars = ITEM_STARS_ANY)
{
	new freshAt = 0;

	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_InventoryCount[playerid];i++)
	{
		if (Inventory_SlotMatches(playerid,i,kind,param,stars))
		{
			freshAt = Item_OlderFresh(freshAt,s_Inventory[playerid][i][E_INV_FRESH_AT]);
		}
	}

	return freshAt;
}

stock Inventory_Count(playerid,E_ITEM_KIND:kind,param,stars = ITEM_STARS_ANY)
{
	new total = 0;
	for (new i = 0; i < s_InventoryCount[playerid]; i++)
	{
		if (Inventory_SlotMatches(playerid,i,kind,param,stars))
		{
			total += s_Inventory[playerid][i][E_INV_AMOUNT];
		}
	}

	return total;
}

stock Inventory_Room(playerid,E_ITEM_KIND:kind,param,stars = ITEM_STARS_MIN)
{
	if (!Util_IsValidPlayer(playerid) || !s_InventoryLoaded[playerid] || !Item_IsValid(kind,param))
	{
		return 0;
	}

	new stackMax = Item_GetStackMax(kind,param), room = (INVENTORY_SLOTS - s_InventoryCount[playerid]) * stackMax;
	if (stackMax > 1)
	{
		for (new i = 0; i < s_InventoryCount[playerid]; i++)
		{
			if (Inventory_SlotMatches(playerid,i,kind,param,stars))
			{
				room += stackMax - s_Inventory[playerid][i][E_INV_AMOUNT];
			}
		}
	}

	return room;
}

stock bool:Inventory_CanGive(playerid,E_ITEM_KIND:kind,param,amount = 1,stars = ITEM_STARS_MIN)
{
	if (amount != 1 && !Item_Stacks(kind,param))
	{
		return false;
	}

	return amount > 0 && Item_IsValidStars(stars) && Inventory_Room(playerid,kind,param,stars) >= amount;
}

static Inventory_Persist(playerid,index)
{
	if (s_Inventory[playerid][index][E_INV_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE character_items SET amount = %d, used = %d, fresh_at = %d, wear = %d, data = %d WHERE id = %d",s_Inventory[playerid][index][E_INV_AMOUNT],s_Inventory[playerid][index][E_INV_USED],s_Inventory[playerid][index][E_INV_FRESH_AT],s_Inventory[playerid][index][E_INV_WEAR],s_Inventory[playerid][index][E_INV_DATA],s_Inventory[playerid][index][E_INV_ROW]));
		return;
	}

	if (s_Inventory[playerid][index][E_INV_ROW] == INVENTORY_ROW_PENDING)
	{
		return;
	}

	s_Inventory[playerid][index][E_INV_ROW] = INVENTORY_ROW_PENDING;
	SetTimerEx("Inventory_InsertDeferred",0,false,"dddddddd",playerid,s_Inventory[playerid][index][E_INV_SERIAL],Account_GetToken(playerid),Character_GetId(playerid),_:s_Inventory[playerid][index][E_INV_KIND],s_Inventory[playerid][index][E_INV_PARAM],s_Inventory[playerid][index][E_INV_AMOUNT],s_Inventory[playerid][index][E_INV_STARS]);
}

static Inventory_FindSerial(playerid,serial)
{
	for (new i = 0; i < s_InventoryCount[playerid]; i++)
	{
		if (s_Inventory[playerid][i][E_INV_SERIAL] == serial)
		{
			return i;
		}
	}

	return -1;
}

static Inventory_InsertRow(playerid,serial,token,characterid,kind,param,amount,stars)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO character_items (character_id, kind, param, amount, stars) VALUES (%d, %d, %d, %d, %d)",characterid,kind,param,amount,stars));

	new row = cache_insert_id();

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new slot = Inventory_FindSerial(playerid,serial);

	if (slot == -1)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_items WHERE id = %d",row));
		return;
	}

	s_Inventory[playerid][slot][E_INV_ROW] = row;

	if (s_Inventory[playerid][slot][E_INV_AMOUNT] != amount || s_Inventory[playerid][slot][E_INV_USED] != 0 || s_Inventory[playerid][slot][E_INV_FRESH_AT] != 0 || s_Inventory[playerid][slot][E_INV_WEAR] != 0 || s_Inventory[playerid][slot][E_INV_DATA] != 0)
	{
		Inventory_Persist(playerid,slot);
	}
}

static Inventory_RemoveAt(playerid,index)
{
	if (s_Inventory[playerid][index][E_INV_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_items WHERE id = %d",s_Inventory[playerid][index][E_INV_ROW]));
	}

	for (new i = index; i < s_InventoryCount[playerid] - 1; i++)
	{
		s_Inventory[playerid][i] = s_Inventory[playerid][i + 1];
	}

	s_InventoryCount[playerid]--;
}

static Inventory_OpenSlot(playerid,E_ITEM_KIND:kind,param,amount,stars,freshAt = 0,wear = 0,data = 0)
{
	new slot = s_InventoryCount[playerid]++;
	s_Inventory[playerid][slot][E_INV_ROW] = 0;
	s_Inventory[playerid][slot][E_INV_SERIAL] = ++g_InventorySerial;
	s_Inventory[playerid][slot][E_INV_KIND] = kind;
	s_Inventory[playerid][slot][E_INV_PARAM] = param;
	s_Inventory[playerid][slot][E_INV_AMOUNT] = amount;
	s_Inventory[playerid][slot][E_INV_STARS] = stars;
	s_Inventory[playerid][slot][E_INV_USED] = 0;
	s_Inventory[playerid][slot][E_INV_FRESH_AT] = freshAt;
	s_Inventory[playerid][slot][E_INV_WEAR] = wear;
	s_Inventory[playerid][slot][E_INV_DATA] = data;
	Inventory_Persist(playerid,slot);
	return slot;
}

stock bool:Inventory_Give(playerid,E_ITEM_KIND:kind,param,amount = 1,stars = ITEM_STARS_MIN,freshAt = ITEM_FRESH_NOW,wear = 0,data = 0)
{
	if (!Inventory_CanGive(playerid,kind,param,amount,stars))
	{
		return false;
	}

	freshAt = Item_ResolveFresh(kind,param,freshAt);

	new stackMax = Item_GetStackMax(kind,param), left = amount;
	if (stackMax > 1 && data == 0)
	{
		for (new i = 0; i < s_InventoryCount[playerid] && left > 0; i++)
		{
			if (!Inventory_SlotMatches(playerid,i,kind,param,stars) || s_Inventory[playerid][i][E_INV_AMOUNT] >= stackMax || s_Inventory[playerid][i][E_INV_DATA] != 0)
			{
				continue;
			}

			new fill = stackMax - s_Inventory[playerid][i][E_INV_AMOUNT];
			if (fill > left)
			{
				fill = left;
			}

			s_Inventory[playerid][i][E_INV_AMOUNT] += fill;
			s_Inventory[playerid][i][E_INV_FRESH_AT] = Item_OlderFresh(s_Inventory[playerid][i][E_INV_FRESH_AT],freshAt);
			left -= fill;
			Inventory_Persist(playerid,i);
		}
	}

	while (left > 0)
	{
		new fill = left > stackMax ? stackMax : left;
		Inventory_OpenSlot(playerid,kind,param,fill,stars,freshAt,wear,data);
		left -= fill;
	}

	pawn_call_public("Inventory_OnChanged","d",playerid);
	return true;
}

static Inventory_TakeAt(playerid,index,amount)
{
	new E_ITEM_KIND:kind = s_Inventory[playerid][index][E_INV_KIND], param = s_Inventory[playerid][index][E_INV_PARAM];
	if (s_Inventory[playerid][index][E_INV_AMOUNT] == amount)
	{
		if (kind == ITEM_KIND_WEAPON && Combat_GetWeapon(playerid) == param && Inventory_Count(playerid,kind,param) == amount)
		{
			Combat_Unequip(playerid);
		}
		else if (kind == ITEM_KIND_SHIELD && Combat_GetShield(playerid) == param && Inventory_Count(playerid,kind,param) == amount)
		{
			Combat_UnequipShield(playerid);
		}

		Inventory_RemoveAt(playerid,index);
		return;
	}

	s_Inventory[playerid][index][E_INV_AMOUNT] -= amount;
	Inventory_Persist(playerid,index);
}

stock bool:Inventory_TakeSlot(playerid,index,amount)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid] || amount <= 0 || amount > s_Inventory[playerid][index][E_INV_AMOUNT])
	{
		return false;
	}

	Inventory_TakeAt(playerid,index,amount);
	pawn_call_public("Inventory_OnChanged","d",playerid);
	return true;
}

stock Inventory_UsePortion(playerid,index,portions)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid])
	{
		return 0;
	}

	if (++s_Inventory[playerid][index][E_INV_USED] < portions)
	{
		Inventory_Persist(playerid,index);
		pawn_call_public("Inventory_OnChanged","d",playerid);
		return portions - s_Inventory[playerid][index][E_INV_USED];
	}

	s_Inventory[playerid][index][E_INV_USED] = 0;
	Inventory_TakeAt(playerid,index,1);
	pawn_call_public("Inventory_OnChanged","d",playerid);
	return 0;
}

stock bool:Inventory_RefillSlot(playerid,index)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid] || s_Inventory[playerid][index][E_INV_USED] <= 0)
	{
		return false;
	}

	s_Inventory[playerid][index][E_INV_USED] = 0;
	Inventory_Persist(playerid,index);
	pawn_call_public("Inventory_OnChanged","d",playerid);
	return true;
}

stock Inventory_CountStarted(playerid,E_ITEM_KIND:kind,param,stars = ITEM_STARS_ANY)
{
	new count = 0;

	for (new i = 0; Util_IsValidPlayer(playerid) && i < s_InventoryCount[playerid]; i++)
	{
		if (Inventory_SlotMatches(playerid,i,kind,param,stars) && s_Inventory[playerid][i][E_INV_USED] > 0)
		{
			count++;
		}
	}

	return count;
}

stock bool:Inventory_Take(playerid,E_ITEM_KIND:kind,param,amount = 1,stars = ITEM_STARS_ANY)
{
	if (!Util_IsValidPlayer(playerid) || !s_InventoryLoaded[playerid] || amount <= 0 || Inventory_Count(playerid,kind,param,stars) < amount)
	{
		return false;
	}

	new left = amount;
	for (new i = 0; i < s_InventoryCount[playerid] && left > 0; i++)
	{
		new whole = s_Inventory[playerid][i][E_INV_AMOUNT] - (s_Inventory[playerid][i][E_INV_USED] > 0 ? 1 : 0);

		if (!Inventory_SlotMatches(playerid,i,kind,param,stars) || whole <= 0)
		{
			continue;
		}

		new take = whole > left ? left : whole, before = s_InventoryCount[playerid];
		left -= take;
		Inventory_TakeAt(playerid,i,take);
		if (s_InventoryCount[playerid] < before)
		{
			i--;
		}
	}

	for (new i = 0; i < s_InventoryCount[playerid] && left > 0; i++)
	{
		if (!Inventory_SlotMatches(playerid,i,kind,param,stars))
		{
			continue;
		}

		new take = s_Inventory[playerid][i][E_INV_AMOUNT] > left ? left : s_Inventory[playerid][i][E_INV_AMOUNT], before = s_InventoryCount[playerid];
		left -= take;
		Inventory_TakeAt(playerid,i,take);
		if (s_InventoryCount[playerid] < before)
		{
			i--;
		}
	}

	pawn_call_public("Inventory_OnChanged","d",playerid);
	return true;
}

stock Inventory_CountGroup(playerid,group,stars = ITEM_STARS_ANY)
{
	new total = 0;

	for (new nth = 0, member;(member = Item_GetGroupMember(group,nth)) != -1;nth++)
	{
		total += Inventory_Count(playerid,Item_GetDefKind(member),member,stars);
	}

	return total;
}

stock bool:Inventory_TakeGroup(playerid,group,amount,stars = ITEM_STARS_ANY)
{
	if (amount <= 0 || Inventory_CountGroup(playerid,group,stars) < amount)
	{
		return false;
	}

	for (new nth = 0, member;amount > 0 && (member = Item_GetGroupMember(group,nth)) != -1;nth++)
	{
		new E_ITEM_KIND:kind = Item_GetDefKind(member), take = min(amount,Inventory_Count(playerid,kind,member,stars));

		if (take > 0 && Inventory_Take(playerid,kind,member,take,stars))
		{
			amount -= take;
		}
	}

	return amount <= 0;
}

stock bool:Inventory_Use(playerid,index)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_InventoryCount[playerid] || !Session_IsPlaying(playerid))
	{
		return false;
	}

	new E_ITEM_KIND:kind = s_Inventory[playerid][index][E_INV_KIND], param = s_Inventory[playerid][index][E_INV_PARAM], stars = s_Inventory[playerid][index][E_INV_STARS];
	switch (kind)
	{
		case ITEM_KIND_COIN:
		{
			return false;
		}
		case ITEM_KIND_CONTAINER:
		{
			ContainerGui_Show(playerid,param);
			return true;
		}
		case ITEM_KIND_WEAPON:
		{
			new weaponName[ITEM_NAME_LEN];
			Weapon_GetName(param,weaponName);

			if (Combat_GetWeapon(playerid) == param)
			{
				Combat_Unequip(playerid);
				Gui_Notify(playerid,sprintf("You put the %s away.",weaponName));
				return true;
			}

			if (!Combat_Equip(playerid,param))
			{
				return false;
			}

			if (Weapon_IsRanged(param))
			{
				Gui_Notify(playerid,sprintf("You carry the %s at your side. Press Y to draw it, then left click to ready it. Shooting uses ammunition from your bag.",weaponName));
			}
			else
			{
				Gui_Notify(playerid,sprintf("You carry the %s at your side. Press Y to draw it.",weaponName));
			}

			return true;
		}
		case ITEM_KIND_SHIELD:
		{
			if (Combat_GetShield(playerid) == param)
			{
				Combat_UnequipShield(playerid);
				return true;
			}

			return Combat_EquipShield(playerid,param);
		}
	}

	pawn_call_public("Inventory_OnUse","ddddd",playerid,_:kind,param,stars,index);
	return true;
}

Inventory_Reset(playerid)
{
	s_InventoryCount[playerid] = 0;
	s_InventoryLoaded[playerid] = false;
}

static Inventory_RestoreHand(playerid)
{
	if (!s_InventoryLoaded[playerid] || !Session_HasCharacter(playerid))
	{
		return;
	}

	new weapon = Character_GetStoredHand(playerid,false), shield = Character_GetStoredHand(playerid,true);
	if (weapon != INVALID_WEAPON_INDEX && Combat_GetWeapon(playerid) != weapon)
	{
		if (Inventory_Find(playerid,ITEM_KIND_WEAPON,weapon) != -1)
		{
			Combat_Equip(playerid,weapon);
		}
		else
		{
			Character_SetStoredHand(playerid,false,INVALID_WEAPON_INDEX);
		}
	}

	if (shield != INVALID_SHIELD_INDEX && Combat_GetShield(playerid) != shield)
	{
		if (Inventory_Find(playerid,ITEM_KIND_SHIELD,shield) != -1)
		{
			Combat_EquipShield(playerid,shield);
		}
		else
		{
			Character_SetStoredHand(playerid,true,INVALID_SHIELD_INDEX);
		}
	}
}

static Inventory_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, param, amount, stars, used, fresh_at, wear, data FROM character_items WHERE character_id = %d ORDER BY id LIMIT %d",characterid,INVENTORY_SLOTS));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new rows = cache_num_rows();
	s_InventoryCount[playerid] = 0;
	for (new r = 0; r < rows && s_InventoryCount[playerid] < INVENTORY_SLOTS; r++)
	{
		new kind, slot = s_InventoryCount[playerid];
		cache_get_value_name_int(r,"id",s_Inventory[playerid][slot][E_INV_ROW]);
		s_Inventory[playerid][slot][E_INV_SERIAL] = 0;
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_int(r,"param",s_Inventory[playerid][slot][E_INV_PARAM]);
		cache_get_value_name_int(r,"amount",s_Inventory[playerid][slot][E_INV_AMOUNT]);
		cache_get_value_name_int(r,"stars",s_Inventory[playerid][slot][E_INV_STARS]);
		cache_get_value_name_int(r,"used",s_Inventory[playerid][slot][E_INV_USED]);
		cache_get_value_name_int(r,"fresh_at",s_Inventory[playerid][slot][E_INV_FRESH_AT]);
		cache_get_value_name_int(r,"wear",s_Inventory[playerid][slot][E_INV_WEAR]);
		cache_get_value_name_int(r,"data",s_Inventory[playerid][slot][E_INV_DATA]);
		s_Inventory[playerid][slot][E_INV_KIND] = E_ITEM_KIND:kind;
		if (!Item_IsValid(E_ITEM_KIND:kind,s_Inventory[playerid][slot][E_INV_PARAM]) || !Item_IsValidStars(s_Inventory[playerid][slot][E_INV_STARS]))
		{
			continue;
		}

		s_InventoryCount[playerid]++;
	}

	s_InventoryLoaded[playerid] = true;
	Inventory_RestoreHand(playerid);
	pawn_call_public("Inventory_OnLoaded","d",playerid);
}

forward Inventory_OnLoaded(playerid);

public Inventory_OnLoaded(playerid)
{
	return 1;
}

forward Inventory_OnChanged(playerid);

public Inventory_OnChanged(playerid)
{
	return 1;
}

forward Inventory_OnUse(playerid,kind,param,stars,index);

public Inventory_OnUse(playerid,kind,param,stars,index)
{
	return 1;
}

forward Inventory_InsertDeferred(playerid,serial,token,characterid,kind,param,amount,stars);

public Inventory_InsertDeferred(playerid,serial,token,characterid,kind,param,amount,stars)
{
	yield 1;

	if (characterid > 0)
	{
		Inventory_InsertRow(playerid,serial,token,characterid,kind,param,amount,stars);
	}
}

forward Inventory_LoadDeferred(playerid,token);

public Inventory_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Inventory_Load(playerid,token);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Inventory_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Inventory_Reset(playerid);
	SetTimerEx("Inventory_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Inventory_Reset(playerid);
}
