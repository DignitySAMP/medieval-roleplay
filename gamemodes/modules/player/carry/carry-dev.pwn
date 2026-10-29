CMD<ADMIN_LEVEL_TRIAL>:carrydebug(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new line[96];
	Carry_Refresh(playerid);
	Carry_Describe(playerid,line);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Carrying %s. Band %d, bulky %d, load model %d, pace %d (0 free, 1 no sprint, 2 walk), winded %d.",line,Carry_GetBand(playerid),Inventory_CountBulky(playerid),Carry_GetLoad(playerid),Carry_GetPace(playerid),_:Carry_IsWinded(playerid)));
	return 1;
}
