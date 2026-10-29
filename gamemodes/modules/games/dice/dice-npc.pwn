static Dice_ScheduleNpc(table,ms)
{
	SetTimerEx("Dice_NpcStep",ms,false,"ddd",table,Table_GetSerial(table),Dice_GetTurns(table));
}

forward Dice_NpcStep(table,serial,turns);

public Dice_NpcStep(table,serial,turns)
{
	if (!Dice_IsRunning(table) || Table_GetSerial(table) != serial || Dice_GetTurns(table) != turns || Dice_IsBusted(table))
	{
		return 1;
	}

	new seat = Dice_GetTurn(table);

	if (!Table_IsSeatRegular(table,seat))
	{
		return 1;
	}

	if (!Dice_HasRolled(table))
	{
		Dice_Roll(table);
		Dice_ScheduleNpc(table,DICE_NPC_THINK_MS);
		return 1;
	}

	if (Dice_GetPicked(table) == 0)
	{
		Dice_SetPicked(table,Dice_BestPick(table));
		Dice_ScheduleNpc(table,DICE_NPC_THINK_MS);
		return 1;
	}

	new style = Table_GetRegularStyle(Table_GetSeatRegular(table,seat)), picked = Dice_GetPicked(table), turnTotal = Dice_GetTurnPoints(table) + Dice_PickScore(table), remaining = Dice_CountMask(Dice_FreeMask(table) & ~picked);

	if (Dice_NpcShouldBank(style,turnTotal,remaining,Dice_GetScore(table,seat),Dice_GetTarget(table)))
	{
		Dice_Bank(table);
		return 1;
	}

	Dice_Roll(table);
	Dice_ScheduleNpc(table,DICE_NPC_THINK_MS);
	return 1;
}

#include <pp-hooks>

hook Dice_OnTurn(table,seat)
{
	if (Table_IsSeatRegular(table,seat))
	{
		Dice_ScheduleNpc(table,DICE_NPC_THINK_MS);
	}
}
