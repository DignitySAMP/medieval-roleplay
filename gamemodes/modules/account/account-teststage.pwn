stock Account_TestStageLevel(playerid,level)
{
	return IsPlayerNPC(playerid) || level >= ADMIN_LEVEL_MANAGER ? level : ADMIN_LEVEL_MANAGER;
}
