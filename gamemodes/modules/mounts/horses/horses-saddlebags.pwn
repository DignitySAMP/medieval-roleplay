#define HORSES_SADDLEBAG_SLOTS (6)
#define HORSES_PANNIER_SLOTS (10)

forward Task:Horses_OpenSaddlebags(playerid,horseid);
#pragma warning push
#pragma warning disable 204
async Task:Horses_OpenSaddlebags(playerid,horseid)
{
	if (!Horses_IsOwned(horseid) || !Horses_MayRide(playerid,horseid))
	{
		wait_ticks(1);
		return async 0;
	}

	new containerid = Horses_GetSaddlebag(horseid);

	if (containerid == INVALID_CONTAINER_ID)
	{
		if (!Horses_IsOwner(playerid,horseid))
		{
			Gui_Notify(playerid,"It carries no saddlebags.");
			wait_ticks(1);
			return async 0;
		}

		new bool:donkey = Horse_GetType(horseid) == MOUNT_DONKEY_TYPE, label[12] = "Saddlebags";

		if (donkey)
		{
			label = "Panniers";
		}

		containerid = await Container_Create(CONTAINER_OWNER_SADDLEBAG,Horses_GetHid(horseid),donkey ? HORSES_PANNIER_SLOTS : HORSES_SADDLEBAG_SLOTS,label);

		if (!Horse_IsValid(horseid) || containerid == INVALID_CONTAINER_ID)
		{
			return async 0;
		}

		Horses_SetSaddlebag(horseid,containerid);
		Horses_Save(horseid);
		if (donkey)
		{
			Gui_Notify(playerid,"You sling a pair of panniers over the donkey.");
		}
		else
		{
			Gui_Notify(playerid,"You buckle a pair of saddlebags on.");
		}
	}

	if (!Container_IsLoaded(containerid))
	{
		await Container_Load(containerid);
	}

	if (!IsPlayerConnected(playerid) || !Horse_IsValid(horseid))
	{
		return async 0;
	}

	ContainerGui_ShowDeferred(playerid,containerid);
	wait_ticks(1);
	return async containerid;
}
#pragma warning pop

#include <pp-hooks>

hook Horses_OnSaddlebags(playerid,horseid)
{
	Horses_OpenSaddlebags(playerid,horseid);
}
