CMD<ADMIN_LEVEL_TRIAL>:hours(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	new name[12], hour = Calendar_GetHour();
	Routine_GetHourName(Routine_GetHour(),name);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("It is %02d:%02d, the hour of %s%s. The keyframe fires again now.",hour,Calendar_GetMinuteOfDay() % 60,name,Routine_IsWinter() ? (" (winter hours)") : ("")));
	pawn_call_public("Routine_OnKeyframe","dd",hour,_:Routine_GetHour());
	return 1;
}
