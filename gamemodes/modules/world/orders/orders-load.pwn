stock Orders_SeedForage()
{
	new created = 0;

	for (new spot = 0;spot < ORDERS_SEED_FORAGE;spot++)
	{
		new kind = Work_FindKind(g_OrdersForageKinds[spot]);

		if (kind == -1 || (g_OrdersForageSpots[spot][0] == 0.0 && g_OrdersForageSpots[spot][1] == 0.0) || Work_FindNearestNode(g_OrdersForageSpots[spot][0],g_OrdersForageSpots[spot][1],g_OrdersForageSpots[spot][2],0,1.5) != -1)
		{
			continue;
		}

		Work_CreateNode(kind,g_OrdersForageSpots[spot][0],g_OrdersForageSpots[spot][1],g_OrdersForageSpots[spot][2],g_OrdersForageSpots[spot][3],0,0);
		created++;
	}

	return created;
}

forward Task:Orders_LoadCharacter(playerid,characterid);

#pragma warning push
#pragma warning disable 204
async Task:Orders_LoadCharacter(playerid,characterid)
{
	new token = Account_GetToken(playerid), ok = await Orders_LoadPlayer(playerid,characterid);

	if (ok)
	{
		ok = await Orders_LoadDuties(playerid,characterid);
	}

	if (ok)
	{
		ok = await Orders_LoadSteward(playerid,characterid);
	}

	if (ok)
	{
		ok = await Ledger_Load(playerid,characterid);
	}

	if (ok && IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Character_GetId(playerid) == characterid)
	{
		Orders_SetLoaded(playerid,true);
		pawn_call_public("Orders_OnLoaded","d",playerid);
	}

	return async ok;
}
#pragma warning pop

forward Task:Orders_BootTask();

#pragma warning push
#pragma warning disable 204
async Task:Orders_BootTask()
{
	Orders_PlaceOfficers();
	new orders = await Orders_Load();
	new contracts = await Contracts_Load();
	Log_Info("orders","%d errands, %d contracts, reeve %d, bailiff %d, %d forage spots",orders,contracts,Orders_GetReeve(),Orders_GetBailiff(),ORDERS_SEED_FORAGE);
	Boot_LoaderDone();
	SetTimer("Orders_AfterBoot",15000,false);
	return async orders;
}
#pragma warning pop

forward Orders_OnLoaded(playerid);

public Orders_OnLoaded(playerid)
{
	return 1;
}

forward Orders_LoadOnBoot();

public Orders_LoadOnBoot()
{
	Orders_BootTask();
	return 1;
}

forward Orders_AfterBoot();

public Orders_AfterBoot()
{
	new created = Orders_SeedForage();
	Orders_ExpireAll(Orders_Today());
	Contracts_ExpireAll(gettime());
	Log_Info("orders","%d errands posted after boot, %d forage nodes put back",Orders_RollAll(),created);
	return 1;
}
