static STREAMER_TAG_OBJECT:s_TableCloths[TABLE_MAX];

stock bool:Table_HasCloth(table)
{
	return IsValidDynamicObject(s_TableCloths[table]) != 0;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new table = 0;table < TABLE_MAX;table++)
	{
		s_TableCloths[table] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

hook Table_OnStarted(table)
{
	new Float:x, Float:y, Float:z, Float:angle;
	Table_GetPos(table,x,y,z,angle);

	if (IsValidDynamicObject(s_TableCloths[table]))
	{
		DestroyDynamicObject(s_TableCloths[table]);
	}

	s_TableCloths[table] = CreateDynamicObject(MODEL_GAMES_CLOTH,x,y,z + TABLE_CLOTH_LIFT,0.0,0.0,angle,Table_GetWorld(table),Table_GetInterior(table),-1,TABLE_CLOTH_STREAM,TABLE_CLOTH_STREAM);
	Nearby_StreamObjectsAt(x,y,z,Table_GetWorld(table),Table_GetInterior(table),TABLE_CLOTH_STREAM);
}

hook Table_OnClosing(table,winner)
{
	#pragma unused winner

	if (IsValidDynamicObject(s_TableCloths[table]))
	{
		DestroyDynamicObject(s_TableCloths[table]);
	}

	s_TableCloths[table] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}
