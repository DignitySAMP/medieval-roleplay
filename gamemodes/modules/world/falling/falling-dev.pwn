CMD<ADMIN_LEVEL_TRIAL>:falltest(cmdid, playerid, params[])
{
	new Float:drop = 30.0;

	if (params[0] != EOS && sscanf(params,"f",drop))
	{
		Command_Usage(playerid,cmdid,"[drop, default 30]");
		return 1;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	SetPlayerPos(playerid,x,y,z - drop);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Dropped %.0f under the ground. Two seconds of falling puts you back where you last stood.",drop));
	return 1;
}
