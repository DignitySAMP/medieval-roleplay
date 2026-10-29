native PlayerTextDrawSetString_s(playerid,PlayerText:textid,String:format,AnyTag:...) = PlayerTextDrawSetString;

stock PStr_Set(&Map:store,playerid,const text[])
{
	if (store == Map:0)
	{
		store = map_new();
	}

	if (text[0] == EOS)
	{
		map_remove(store,playerid);
		return;
	}

	map_set_str(store,playerid,text);
}

stock PStr_Get(Map:store,playerid,dest[],size = sizeof(dest))
{
	if (store == Map:0 || !map_has_key(store,playerid))
	{
		dest[0] = EOS;
		return;
	}

	map_get_str(store,playerid,dest,size);
}

stock bool:PStr_Has(Map:store,playerid)
{
	if (store == Map:0)
	{
		return false;
	}

	return map_has_key(store,playerid);
}

stock PStr_Clear(Map:store,playerid)
{
	if (store == Map:0)
	{
		return;
	}

	map_remove(store,playerid);
}

stock String:str_join_arr(const strings[][],const delim[],count = sizeof(strings))
{
	new List:partsList = list_new();
	for (new i = 0;i < count;++i)
	{
		if (strings[i][0])
		{
			list_add_str(partsList,strings[i]);
		}
	}

	new String:joined = str_join(partsList,delim);
	list_delete(partsList);
	return joined;
}

stock SendClientMessage_s(playerid,colour,String:message)
{
	new text[256];
	str_get(message,text);
	SendClientMessage(playerid,colour,text);
}
