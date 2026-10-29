static STREAMER_TAG_OBJECT:s_DiceObjects[TABLE_MAX][DICE_COUNT];
static s_DiceObjectsSerial[TABLE_MAX];
static s_DiceObjectsRolls[TABLE_MAX];
static s_DiceObjectsTurns[TABLE_MAX];

static Dice_LocalToWorld(table,Float:right,Float:ahead,&Float:x,&Float:y,&Float:z,&Float:angle)
{
	Table_LocalToWorld(table,right,ahead,x,y,z,angle);
	z += DICE_REST_Z;
}

static Dice_DestroyObjects(table)
{
	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (IsValidDynamicObject(s_DiceObjects[table][die]))
		{
			DestroyDynamicObject(s_DiceObjects[table][die]);
		}

		s_DiceObjects[table][die] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	s_DiceObjectsSerial[table] = 0;
}

static Dice_CreateObjects(table)
{
	new Float:x, Float:y, Float:z, Float:angle;
	Dice_DestroyObjects(table);

	for (new die = 0;die < DICE_COUNT;die++)
	{
		Dice_LocalToWorld(table,(float(die) - 2.5) * DICE_ROW_GAP,0.0,x,y,z,angle);
		s_DiceObjects[table][die] = CreateDynamicObject(g_DiceKindModels[DICE_KIND_PLAIN],x,y,z,g_DiceFaceRotations[die + 1][0],g_DiceFaceRotations[die + 1][1],angle,Table_GetWorld(table),Table_GetInterior(table),-1,DICE_STREAM,DICE_STREAM);
	}

	Nearby_StreamObjectsAt(x,y,z,Table_GetWorld(table),Table_GetInterior(table),DICE_STREAM);

	s_DiceObjectsSerial[table] = Table_GetSerial(table);
	s_DiceObjectsRolls[table] = 0;
	s_DiceObjectsTurns[table] = 0;
}

static Dice_SetDie(table,die,Float:right,Float:ahead,face,Float:yaw,bool:isHop)
{
	new Float:x, Float:y, Float:z, Float:angle;
	Dice_LocalToWorld(table,right,ahead,x,y,z,angle);

	if (!IsValidDynamicObject(s_DiceObjects[table][die]))
	{
		return;
	}

	new kind = Dice_GetDieKind(table,Dice_GetTurn(table),die), model = g_DiceKindModels[kind >= 0 && kind < DICE_KIND_COUNT ? kind : DICE_KIND_PLAIN];

	if (Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_DiceObjects[table][die],E_STREAMER_MODEL_ID) != model)
	{
		Streamer_SetIntData(STREAMER_TYPE_OBJECT,s_DiceObjects[table][die],E_STREAMER_MODEL_ID,model);
	}

	if (isHop)
	{
		SetDynamicObjectPos(s_DiceObjects[table][die],x,y,z + DICE_HOP);
		MoveDynamicObject(s_DiceObjects[table][die],x,y,z,DICE_HOP_SPEED,g_DiceFaceRotations[face][0],g_DiceFaceRotations[face][1],angle + yaw);
		return;
	}

	SetDynamicObjectPos(s_DiceObjects[table][die],x,y,z);
	SetDynamicObjectRot(s_DiceObjects[table][die],g_DiceFaceRotations[face][0],g_DiceFaceRotations[face][1],angle + yaw);
}

stock Dice_UpdateObjects(table)
{
	if (!Dice_IsRunning(table))
	{
		return;
	}

	if (s_DiceObjectsSerial[table] != Table_GetSerial(table))
	{
		Dice_CreateObjects(table);
	}

	new rolls = Dice_GetRolls(table), turns = Dice_GetTurns(table), aside = Dice_GetAside(table), asideCount = 0, bool:isNewRoll = rolls != s_DiceObjectsRolls[table];

	if (!Dice_HasRolled(table))
	{
		if (turns != s_DiceObjectsTurns[table])
		{
			for (new die = 0;die < DICE_COUNT;die++)
			{
				Dice_SetDie(table,die,(float(die) - 2.5) * DICE_ROW_GAP,0.0,Dice_GetFace(table,die),0.0,false);
			}
		}

		s_DiceObjectsTurns[table] = turns;
		return;
	}

	if (!isNewRoll)
	{
		return;
	}

	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (aside & (1 << die))
		{
			Dice_SetDie(table,die,(float(asideCount++) - 2.5) * DICE_ROW_GAP,-DICE_SPREAD - 0.08,Dice_GetFace(table,die),0.0,false);
			continue;
		}

		Dice_SetDie(table,die,(float(random(1000)) / 1000.0 - 0.5) * 2.0 * DICE_SPREAD,(float(random(1000)) / 1000.0 - 0.5) * 2.0 * DICE_SPREAD,Dice_GetFace(table,die),float(random(360)),true);
	}

	s_DiceObjectsRolls[table] = rolls;
	s_DiceObjectsTurns[table] = turns;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new table = 0;table < TABLE_MAX;table++)
	{
		for (new die = 0;die < DICE_COUNT;die++)
		{
			s_DiceObjects[table][die] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		}
	}
}

hook Dice_OnChanged(table)
{
	Dice_UpdateObjects(table);
}

hook Dice_OnEnded(table,winner)
{
	#pragma unused winner

	Dice_DestroyObjects(table);
}
