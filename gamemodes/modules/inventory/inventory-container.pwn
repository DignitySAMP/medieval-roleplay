#define MAX_CONTAINERS (256)
#define CONTAINER_SLOTS_MAX (32)
#define CONTAINER_LABEL_LEN (64)
#define INVALID_CONTAINER_ID (0)

enum E_CONTAINER_OWNER
{
	CONTAINER_OWNER_NONE = 0,
	CONTAINER_OWNER_STORE,
	CONTAINER_OWNER_TILL,
	CONTAINER_OWNER_TREASURY,
	CONTAINER_OWNER_RESERVE,
	CONTAINER_OWNER_CHEST,
	CONTAINER_OWNER_PURSE,
	CONTAINER_OWNER_BAG,
	CONTAINER_OWNER_COFFER,
	CONTAINER_OWNER_CART,
	CONTAINER_OWNER_SADDLEBAG,
	CONTAINER_OWNER_CARRIED,
	CONTAINER_OWNER_GROUP_TREASURY,
	CONTAINER_OWNER_GROUP_STORE,
	CONTAINER_OWNER_SITE,
	CONTAINER_OWNER_COUNT,
}

enum E_CONTAINER
{
	E_CONTAINER_ID,
	E_CONTAINER_OWNER:E_CONTAINER_OWNER_TYPE,
	E_CONTAINER_OWNER_ID,
	E_CONTAINER_SLOTS,
	E_CONTAINER_LABEL[CONTAINER_LABEL_LEN],
	E_CONTAINER_COUNT,
	bool:E_CONTAINER_LOADED,
}

static s_Containers[MAX_CONTAINERS][E_CONTAINER];
static s_ContainerItems[MAX_CONTAINERS][CONTAINER_SLOTS_MAX][E_INV_SLOT];
static const s_ContainerDefaultSlots[E_CONTAINER_OWNER] = {0, 30, 10, 20, 12, 8, 3, 8, 30, 16, 6, 6, 12, 24, 16};

static Container_Index(containerid)
{
	if (containerid == INVALID_CONTAINER_ID)
	{
		return -1;
	}

	for (new i = 0; i < MAX_CONTAINERS; i++)
	{
		if (s_Containers[i][E_CONTAINER_LOADED] && s_Containers[i][E_CONTAINER_ID] == containerid)
		{
			return i;
		}
	}

	return -1;
}

static Container_Free()
{
	for (new i = 0; i < MAX_CONTAINERS; i++)
	{
		if (!s_Containers[i][E_CONTAINER_LOADED])
		{
			return i;
		}
	}

	return -1;
}

stock bool:Container_IsLoaded(containerid)
{
	return Container_Index(containerid) != -1;
}

stock Container_DefaultSlots(E_CONTAINER_OWNER:ownerType)
{
	if (ownerType <= CONTAINER_OWNER_NONE || ownerType >= CONTAINER_OWNER_COUNT)
	{
		return 0;
	}

	return s_ContainerDefaultSlots[ownerType];
}

stock bool:Container_IsCoinPurse(containerid)
{
	new index = Container_Index(containerid);
	return index != -1 && (s_Containers[index][E_CONTAINER_OWNER_TYPE] == CONTAINER_OWNER_PURSE || s_Containers[index][E_CONTAINER_OWNER_TYPE] == CONTAINER_OWNER_BAG);
}

stock Container_GetLabel(containerid,dest[],size = sizeof(dest))
{
	new index = Container_Index(containerid);
	if (index == -1)
	{
		strcopy(dest,"Container",size);
		return;
	}

	strcopy(dest,s_Containers[index][E_CONTAINER_LABEL],size);
}

stock Container_GetSlots(containerid)
{
	new index = Container_Index(containerid);
	return index == -1 ? 0 : s_Containers[index][E_CONTAINER_SLOTS];
}

stock Container_GetCount(containerid)
{
	new index = Container_Index(containerid);
	return index == -1 ? 0 : s_Containers[index][E_CONTAINER_COUNT];
}

stock E_CONTAINER_OWNER:Container_GetOwnerType(containerid)
{
	new index = Container_Index(containerid);
	return index == -1 ? CONTAINER_OWNER_NONE : s_Containers[index][E_CONTAINER_OWNER_TYPE];
}

stock Container_GetIcon(containerid,dest[],size = sizeof(dest))
{
	strcopy(dest,g_ContainerIcons[Container_GetOwnerType(containerid) == CONTAINER_OWNER_PURSE ? 0 : 1],size);
}

stock Container_GetOwnerId(containerid)
{
	new index = Container_Index(containerid);
	return index == -1 ? 0 : s_Containers[index][E_CONTAINER_OWNER_ID];
}

stock Container_FindByOwner(E_CONTAINER_OWNER:ownerType,ownerId)
{
	for (new i = 0; i < MAX_CONTAINERS; i++)
	{
		if (s_Containers[i][E_CONTAINER_LOADED] && s_Containers[i][E_CONTAINER_OWNER_TYPE] == ownerType && s_Containers[i][E_CONTAINER_OWNER_ID] == ownerId)
		{
			return s_Containers[i][E_CONTAINER_ID];
		}
	}

	return INVALID_CONTAINER_ID;
}

stock bool:Container_GetSlot(containerid,slot,&E_ITEM_KIND:kind,&param,&amount,&stars)
{
	new index = Container_Index(containerid);
	if (index == -1 || slot < 0 || slot >= s_Containers[index][E_CONTAINER_COUNT])
	{
		return false;
	}

	kind = s_ContainerItems[index][slot][E_INV_KIND];
	param = s_ContainerItems[index][slot][E_INV_PARAM];
	amount = s_ContainerItems[index][slot][E_INV_AMOUNT];
	stars = s_ContainerItems[index][slot][E_INV_STARS];
	return true;
}

static bool:Container_SlotMatches(index,slot,E_ITEM_KIND:kind,param,stars)
{
	return s_ContainerItems[index][slot][E_INV_KIND] == kind && s_ContainerItems[index][slot][E_INV_PARAM] == param && (stars == ITEM_STARS_ANY || s_ContainerItems[index][slot][E_INV_STARS] == stars);
}

stock Container_Count(containerid,E_ITEM_KIND:kind,param,minStars = ITEM_STARS_MIN)
{
	new index = Container_Index(containerid), total = 0;
	if (index == -1)
	{
		return 0;
	}

	for (new i = 0; i < s_Containers[index][E_CONTAINER_COUNT]; i++)
	{
		if (Container_SlotMatches(index,i,kind,param,ITEM_STARS_ANY) && s_ContainerItems[index][i][E_INV_STARS] >= minStars)
		{
			total += s_ContainerItems[index][i][E_INV_AMOUNT];
		}
	}

	return total;
}

stock Container_Room(containerid,E_ITEM_KIND:kind,param,stars = ITEM_STARS_MIN)
{
	new index = Container_Index(containerid);
	if (index == -1 || !Item_IsValid(kind,param))
	{
		return 0;
	}

	new stackMax = Item_GetStackMax(kind,param), room = (s_Containers[index][E_CONTAINER_SLOTS] - s_Containers[index][E_CONTAINER_COUNT]) * stackMax;
	if (stackMax > 1)
	{
		for (new i = 0; i < s_Containers[index][E_CONTAINER_COUNT]; i++)
		{
			if (Container_SlotMatches(index,i,kind,param,stars))
			{
				room += stackMax - s_ContainerItems[index][i][E_INV_AMOUNT];
			}
		}
	}

	return room;
}

stock bool:Container_Accepts(containerid,E_ITEM_KIND:kind,param)
{
	new index = Container_Index(containerid);

	if (index == -1 || s_Containers[index][E_CONTAINER_OWNER_TYPE] != CONTAINER_OWNER_CARRIED)
	{
		return true;
	}

	return Item_CarriedAccepts(s_Containers[index][E_CONTAINER_OWNER_ID],kind,param);
}

stock bool:Container_CanAdd(containerid,E_ITEM_KIND:kind,param,amount = 1,stars = ITEM_STARS_MIN)
{
	return amount > 0 && Item_IsValidStars(stars) && Container_Accepts(containerid,kind,param) && Container_Room(containerid,kind,param,stars) >= amount;
}

static Container_Persist(index,slot)
{
	if (s_ContainerItems[index][slot][E_INV_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE container_items SET amount = %d, fresh_at = %d, wear = %d, data = %d WHERE id = %d",s_ContainerItems[index][slot][E_INV_AMOUNT],s_ContainerItems[index][slot][E_INV_FRESH_AT],s_ContainerItems[index][slot][E_INV_WEAR],s_ContainerItems[index][slot][E_INV_DATA],s_ContainerItems[index][slot][E_INV_ROW]));
		return;
	}

	if (s_ContainerItems[index][slot][E_INV_ROW] == INVENTORY_ROW_PENDING)
	{
		return;
	}

	s_ContainerItems[index][slot][E_INV_ROW] = INVENTORY_ROW_PENDING;
	SetTimerEx("Container_InsertDeferred",0,false,"dddddd",s_Containers[index][E_CONTAINER_ID],s_ContainerItems[index][slot][E_INV_SERIAL],_:s_ContainerItems[index][slot][E_INV_KIND],s_ContainerItems[index][slot][E_INV_PARAM],s_ContainerItems[index][slot][E_INV_AMOUNT],s_ContainerItems[index][slot][E_INV_STARS]);
}

static Container_FindSerial(index,serial)
{
	for (new i = 0; i < s_Containers[index][E_CONTAINER_COUNT]; i++)
	{
		if (s_ContainerItems[index][i][E_INV_SERIAL] == serial)
		{
			return i;
		}
	}

	return -1;
}

static Container_InsertRow(containerid,serial,kind,param,amount,stars)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO container_items (container_id, kind, param, amount, stars) VALUES (%d, %d, %d, %d, %d)",containerid,kind,param,amount,stars));

	new row = cache_insert_id(), index = Container_Index(containerid);

	if (index == -1 || !s_Containers[index][E_CONTAINER_LOADED])
	{
		return;
	}

	new found = Container_FindSerial(index,serial);

	if (found == -1)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM container_items WHERE id = %d",row));
		return;
	}

	s_ContainerItems[index][found][E_INV_ROW] = row;

	if (s_ContainerItems[index][found][E_INV_AMOUNT] != amount || s_ContainerItems[index][found][E_INV_FRESH_AT] != 0 || s_ContainerItems[index][found][E_INV_WEAR] != 0 || s_ContainerItems[index][found][E_INV_DATA] != 0)
	{
		Container_Persist(index,found);
	}
}

static Container_RemoveAt(index,slot)
{
	if (s_ContainerItems[index][slot][E_INV_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM container_items WHERE id = %d",s_ContainerItems[index][slot][E_INV_ROW]));
	}

	for (new i = slot; i < s_Containers[index][E_CONTAINER_COUNT] - 1; i++)
	{
		s_ContainerItems[index][i] = s_ContainerItems[index][i + 1];
	}

	s_Containers[index][E_CONTAINER_COUNT]--;
}

stock bool:Container_Add(containerid,E_ITEM_KIND:kind,param,amount = 1,stars = ITEM_STARS_MIN,freshAt = ITEM_FRESH_NOW,wear = 0,data = 0)
{
	new index = Container_Index(containerid);
	if (index == -1 || !Container_CanAdd(containerid,kind,param,amount,stars))
	{
		return false;
	}

	freshAt = Item_ResolveFresh(kind,param,freshAt);

	new stackMax = Item_GetStackMax(kind,param), left = amount;
	if (stackMax > 1 && data == 0)
	{
		for (new i = 0; i < s_Containers[index][E_CONTAINER_COUNT] && left > 0; i++)
		{
			if (!Container_SlotMatches(index,i,kind,param,stars) || s_ContainerItems[index][i][E_INV_AMOUNT] >= stackMax || s_ContainerItems[index][i][E_INV_DATA] != 0)
			{
				continue;
			}

			new fill = stackMax - s_ContainerItems[index][i][E_INV_AMOUNT];
			if (fill > left)
			{
				fill = left;
			}

			s_ContainerItems[index][i][E_INV_AMOUNT] += fill;
			s_ContainerItems[index][i][E_INV_FRESH_AT] = Item_OlderFresh(s_ContainerItems[index][i][E_INV_FRESH_AT],freshAt);
			left -= fill;
			Container_Persist(index,i);
		}
	}

	while (left > 0)
	{
		new fill = left > stackMax ? stackMax : left, slot = s_Containers[index][E_CONTAINER_COUNT]++;
		s_ContainerItems[index][slot][E_INV_ROW] = 0;
		s_ContainerItems[index][slot][E_INV_SERIAL] = ++g_InventorySerial;
		s_ContainerItems[index][slot][E_INV_KIND] = kind;
		s_ContainerItems[index][slot][E_INV_PARAM] = param;
		s_ContainerItems[index][slot][E_INV_AMOUNT] = fill;
		s_ContainerItems[index][slot][E_INV_STARS] = stars;
		s_ContainerItems[index][slot][E_INV_FRESH_AT] = freshAt;
		s_ContainerItems[index][slot][E_INV_WEAR] = wear;
		s_ContainerItems[index][slot][E_INV_DATA] = data;
		Container_Persist(index,slot);
		left -= fill;
	}

	pawn_call_public("Container_OnChanged","d",containerid);
	return true;
}

static Container_TakeExact(index,E_ITEM_KIND:kind,param,amount,stars)
{
	new left = amount;
	for (new i = 0; i < s_Containers[index][E_CONTAINER_COUNT] && left > 0; i++)
	{
		if (!Container_SlotMatches(index,i,kind,param,stars))
		{
			continue;
		}

		new take = s_ContainerItems[index][i][E_INV_AMOUNT] > left ? left : s_ContainerItems[index][i][E_INV_AMOUNT];
		left -= take;
		if (s_ContainerItems[index][i][E_INV_AMOUNT] == take)
		{
			Container_RemoveAt(index,i);
			i--;
		}
		else
		{
			s_ContainerItems[index][i][E_INV_AMOUNT] -= take;
			Container_Persist(index,i);
		}
	}

	return amount - left;
}

stock bool:Container_Take(containerid,E_ITEM_KIND:kind,param,amount = 1,minStars = ITEM_STARS_MIN)
{
	new index = Container_Index(containerid);
	if (index == -1 || amount <= 0 || Container_Count(containerid,kind,param,minStars) < amount)
	{
		return false;
	}

	new left = amount;
	for (new stars = minStars; stars <= ITEM_STARS_MAX && left > 0; stars++)
	{
		left -= Container_TakeExact(index,kind,param,left,stars);
	}

	pawn_call_public("Container_OnChanged","d",containerid);
	return true;
}

stock bool:Container_TakeStars(containerid,E_ITEM_KIND:kind,param,amount,stars)
{
	new index = Container_Index(containerid);
	if (index == -1 || amount <= 0 || !Item_IsValidStars(stars))
	{
		return false;
	}

	new have = 0;
	for (new i = 0; i < s_Containers[index][E_CONTAINER_COUNT]; i++)
	{
		if (Container_SlotMatches(index,i,kind,param,stars))
		{
			have += s_ContainerItems[index][i][E_INV_AMOUNT];
		}
	}

	if (have < amount)
	{
		return false;
	}

	Container_TakeExact(index,kind,param,amount,stars);
	pawn_call_public("Container_OnChanged","d",containerid);
	return true;
}

stock Container_GetSlotData(containerid,slot)
{
	new index = Container_Index(containerid);
	return index == -1 || slot < 0 || slot >= s_Containers[index][E_CONTAINER_COUNT] ? 0 : s_ContainerItems[index][slot][E_INV_DATA];
}

stock bool:Container_GetSlotState(containerid,slot,&freshAt,&wear)
{
	new index = Container_Index(containerid);
	freshAt = 0;
	wear = 0;

	if (index == -1 || slot < 0 || slot >= s_Containers[index][E_CONTAINER_COUNT])
	{
		return false;
	}

	freshAt = s_ContainerItems[index][slot][E_INV_FRESH_AT];
	wear = s_ContainerItems[index][slot][E_INV_WEAR];
	return true;
}

stock Container_OldestFresh(containerid,E_ITEM_KIND:kind,param,stars,&wear)
{
	new index = Container_Index(containerid), freshAt = 0;
	wear = 0;

	for (new i = 0;index != -1 && i < s_Containers[index][E_CONTAINER_COUNT];i++)
	{
		if (Container_SlotMatches(index,i,kind,param,stars))
		{
			freshAt = Item_OlderFresh(freshAt,s_ContainerItems[index][i][E_INV_FRESH_AT]);
			wear = max(wear,s_ContainerItems[index][i][E_INV_WEAR]);
		}
	}

	return freshAt;
}

stock bool:Container_Move(fromid,toid,E_ITEM_KIND:kind,param,amount,stars)
{
	new wear, freshAt = Container_OldestFresh(fromid,kind,param,stars,wear);

	if (fromid == toid || !Container_CanAdd(toid,kind,param,amount,stars) || !Container_TakeStars(fromid,kind,param,amount,stars))
	{
		return false;
	}

	Container_Add(toid,kind,param,amount,stars,freshAt,wear);
	return true;
}

stock bool:Container_TakeToBag(playerid,containerid,slot,amount = 0)
{
	new E_ITEM_KIND:kind, param, have, stars, freshAt, wear;
	if (!Container_GetSlot(containerid,slot,kind,param,have,stars) || !Inventory_IsLoaded(playerid))
	{
		return false;
	}

	Container_GetSlotState(containerid,slot,freshAt,wear);

	new data = Container_GetSlotData(containerid,slot);

	if (amount <= 0 || amount > have)
	{
		amount = have;
	}

	if (!Inventory_CanGive(playerid,kind,param,amount,stars))
	{
		return false;
	}

	if (data != 0)
	{
		new index = Container_Index(containerid);

		if (amount != have)
		{
			return false;
		}

		Container_RemoveAt(index,slot);
		pawn_call_public("Container_OnChanged","d",containerid);
	}
	else if (!Container_TakeStars(containerid,kind,param,amount,stars))
	{
		return false;
	}

	Inventory_Give(playerid,kind,param,amount,stars,freshAt,wear,data);
	return true;
}

stock bool:Container_PutFromBag(playerid,containerid,bagIndex,amount = 0)
{
	new E_ITEM_KIND:kind, param, have, stars = Inventory_GetSlotStars(playerid,bagIndex);
	if (!Inventory_GetSlot(playerid,bagIndex,kind,param,have) || kind == ITEM_KIND_CONTAINER)
	{
		return false;
	}

	if (Inventory_GetSlotUsed(playerid,bagIndex) > 0 && --have <= 0)
	{
		Inventory_NotifyStarted(playerid,kind,param);
		return false;
	}

	if (amount <= 0 || amount > have)
	{
		amount = have;
	}

	new freshAt = Inventory_GetSlotFresh(playerid,bagIndex), wear = Inventory_GetSlotWear(playerid,bagIndex), data = Inventory_GetSlotData(playerid,bagIndex);

	if (!Container_CanAdd(containerid,kind,param,amount,stars) || !Inventory_TakeSlot(playerid,bagIndex,amount))
	{
		return false;
	}

	Container_Add(containerid,kind,param,amount,stars,freshAt,wear,data);
	return true;
}

stock Container_Unload(containerid)
{
	new index = Container_Index(containerid);
	if (index == -1)
	{
		return;
	}

	s_Containers[index][E_CONTAINER_LOADED] = false;
	s_Containers[index][E_CONTAINER_ID] = INVALID_CONTAINER_ID;
	s_Containers[index][E_CONTAINER_COUNT] = 0;
}

forward Task:Container_Load(containerid);

#pragma warning push
#pragma warning disable 204
async Task:Container_Load(containerid)
{
	if (containerid == INVALID_CONTAINER_ID)
	{
		wait_ticks(1);
		return async false;
	}

	if (Container_Index(containerid) != -1)
	{
		wait_ticks(1);
		return async true;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, owner_type, owner_id, slots, label FROM containers WHERE id = %d",containerid));
	if (!cache_num_rows() || Container_Index(containerid) != -1)
	{
		return async (Container_Index(containerid) != -1);
	}

	new index = Container_Free();
	if (index == -1)
	{
		Log_Warn("inventory","container %d not loaded - every slot in use",containerid);
		return async false;
	}

	new ownerType;
	cache_get_value_name_int(0,"owner_type",ownerType);
	cache_get_value_name_int(0,"owner_id",s_Containers[index][E_CONTAINER_OWNER_ID]);
	cache_get_value_name_int(0,"slots",s_Containers[index][E_CONTAINER_SLOTS]);
	cache_get_value_name(0,"label",s_Containers[index][E_CONTAINER_LABEL],CONTAINER_LABEL_LEN);
	s_Containers[index][E_CONTAINER_OWNER_TYPE] = E_CONTAINER_OWNER:ownerType;
	s_Containers[index][E_CONTAINER_ID] = containerid;
	s_Containers[index][E_CONTAINER_COUNT] = 0;
	s_Containers[index][E_CONTAINER_LOADED] = true;
	if (s_Containers[index][E_CONTAINER_SLOTS] > CONTAINER_SLOTS_MAX)
	{
		s_Containers[index][E_CONTAINER_SLOTS] = CONTAINER_SLOTS_MAX;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, param, amount, stars, fresh_at, wear, data FROM container_items WHERE container_id = %d ORDER BY id LIMIT %d",containerid,CONTAINER_SLOTS_MAX));
	if (!s_Containers[index][E_CONTAINER_LOADED] || s_Containers[index][E_CONTAINER_ID] != containerid)
	{
		return async false;
	}

	new rows = cache_num_rows();
	for (new r = 0; r < rows && s_Containers[index][E_CONTAINER_COUNT] < s_Containers[index][E_CONTAINER_SLOTS]; r++)
	{
		new kind, slot = s_Containers[index][E_CONTAINER_COUNT];
		cache_get_value_name_int(r,"id",s_ContainerItems[index][slot][E_INV_ROW]);
		s_ContainerItems[index][slot][E_INV_SERIAL] = 0;
		cache_get_value_name_int(r,"kind",kind);
		cache_get_value_name_int(r,"param",s_ContainerItems[index][slot][E_INV_PARAM]);
		cache_get_value_name_int(r,"amount",s_ContainerItems[index][slot][E_INV_AMOUNT]);
		cache_get_value_name_int(r,"stars",s_ContainerItems[index][slot][E_INV_STARS]);
		cache_get_value_name_int(r,"fresh_at",s_ContainerItems[index][slot][E_INV_FRESH_AT]);
		cache_get_value_name_int(r,"wear",s_ContainerItems[index][slot][E_INV_WEAR]);
		cache_get_value_name_int(r,"data",s_ContainerItems[index][slot][E_INV_DATA]);
		s_ContainerItems[index][slot][E_INV_KIND] = E_ITEM_KIND:kind;
		if (!Item_IsValid(E_ITEM_KIND:kind,s_ContainerItems[index][slot][E_INV_PARAM]) || !Item_IsValidStars(s_ContainerItems[index][slot][E_INV_STARS]))
		{
			continue;
		}

		s_Containers[index][E_CONTAINER_COUNT]++;
	}

	pawn_call_public("Container_OnLoaded","d",containerid);
	return async true;
}

#pragma warning pop

forward Task:Container_Create(E_CONTAINER_OWNER:ownerType,ownerId,slots,const label[]);

#pragma warning push
#pragma warning disable 204
async stock Task:Container_Create(E_CONTAINER_OWNER:ownerType,ownerId,slots,const label[])
{
	if (ownerType <= CONTAINER_OWNER_NONE || ownerType >= CONTAINER_OWNER_COUNT)
	{
		wait_ticks(1);
		return async INVALID_CONTAINER_ID;
	}

	if (slots <= 0)
	{
		slots = Container_DefaultSlots(ownerType);
	}

	if (slots > CONTAINER_SLOTS_MAX)
	{
		slots = CONTAINER_SLOTS_MAX;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO containers (owner_type, owner_id, slots, label) VALUES (%d, %d, %d, '%e')",_:ownerType,ownerId,slots,label));
	if (mysql_errno(g_Mysql) != 0)
	{
		return async INVALID_CONTAINER_ID;
	}

	new containerid = cache_insert_id();
	await Container_Load(containerid);
	return async containerid;
}

#pragma warning pop

forward Task:Container_LoadByOwner(E_CONTAINER_OWNER:ownerType,ownerId);

#pragma warning push
#pragma warning disable 204
async stock Task:Container_LoadByOwner(E_CONTAINER_OWNER:ownerType,ownerId)
{
	new containerid = Container_FindByOwner(ownerType,ownerId);
	if (containerid != INVALID_CONTAINER_ID)
	{
		wait_ticks(1);
		return async containerid;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT id FROM containers WHERE owner_type = %d AND owner_id = %d ORDER BY id LIMIT 1",_:ownerType,ownerId));
	if (!cache_num_rows())
	{
		return async INVALID_CONTAINER_ID;
	}

	cache_get_value_name_int(0,"id",containerid);
	new loaded = await Container_Load(containerid);
	if (!loaded)
	{
		return async INVALID_CONTAINER_ID;
	}

	return async containerid;
}

#pragma warning pop

stock Container_Delete(containerid)
{
	Container_Unload(containerid);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM container_items WHERE container_id = %d",containerid));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM containers WHERE id = %d",containerid));
}

forward Container_InsertDeferred(containerid,serial,kind,param,amount,stars);

public Container_InsertDeferred(containerid,serial,kind,param,amount,stars)
{
	yield 1;
	Container_InsertRow(containerid,serial,kind,param,amount,stars);
}

forward Container_OnLoaded(containerid);

public Container_OnLoaded(containerid)
{
	return 1;
}

forward Container_OnChanged(containerid);

public Container_OnChanged(containerid)
{
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0; i < MAX_CONTAINERS; i++)
	{
		s_Containers[i][E_CONTAINER_LOADED] = false;
		s_Containers[i][E_CONTAINER_ID] = INVALID_CONTAINER_ID;
		s_Containers[i][E_CONTAINER_COUNT] = 0;
	}
}

hook Inventory_OnLoaded(playerid)
{
	new count = Inventory_GetCount(playerid), E_ITEM_KIND:kind, param, amount;
	for (new i = 0; i < count; i++)
	{
		if (Inventory_GetSlot(playerid,i,kind,param,amount) && kind == ITEM_KIND_CONTAINER)
		{
			Container_Load(param);
		}
	}
}
