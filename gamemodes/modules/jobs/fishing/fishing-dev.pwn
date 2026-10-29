static Fishing_DevPlaceSpot(playerid,Float:fromX,Float:fromY,Float:x,Float:y,Float:level,Float:angle,type)
{
	yield 1;

	new nodeid = await Work_CreateNode(Work_FindKind(FISHING_NODE_KIND),x,y,level,angle,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid)), water[FISHING_WATER_NAME_LEN];

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	Fishing_GetWaterName(type,water);
	SendClientMessage(playerid,0xFFFFFFFF,nodeid == -1 ? ("The fishing spot couldn't be saved.") : sprintf("Fishing spot placed on the %s, %.1f m out.",water,VectorSize(x - fromX,y - fromY,0.0)));
}

CMD<ADMIN_LEVEL_TRIAL>:fishspot(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	new Float:x, Float:y, Float:z, Float:angle, Float:waterX, Float:waterY, Float:level;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,angle);
	new type = Fishing_FindWaterAhead(x,y,angle,waterX,waterY,level);

	if (type == FISHING_WATER_NONE)
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("There's no water in front of you within %.0f m.",FISHING_CAST_MAX));
		return 1;
	}

	Fishing_DevPlaceSpot(playerid,x,y,waterX,waterY,level,angle,type);
	return 1;
}
