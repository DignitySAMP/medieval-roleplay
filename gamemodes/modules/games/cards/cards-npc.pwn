static Cards_ScheduleNpc(table)
{
	SetTimerEx("Cards_NpcStep",CARDS_NPC_THINK_MS,false,"ddd",table,Table_GetSerial(table),Cards_GetTurns(table));
}

forward Cards_NpcStep(table,serial,turns);

public Cards_NpcStep(table,serial,turns)
{
	if (!Cards_IsRunning(table) || Table_GetSerial(table) != serial || Cards_GetTurns(table) != turns)
	{
		return 1;
	}

	new seat = Cards_GetActor(table);

	if (!Table_IsSeatRegular(table,seat))
	{
		return 1;
	}

	new style = Table_GetRegularStyle(Table_GetSeatRegular(table,seat)), owed = Cards_GetOwed(table,seat);

	if (owed > 0)
	{
		Cards_Act(table,Cards_NpcShouldMeet(style,Table_GetSeatPaid(table,seat),owed) ? CARDS_ACT_MEET : CARDS_ACT_FOLD);
		return 1;
	}

	if (Cards_CanRaise(table,seat) && Cards_NpcShouldRaise(style,random(100)) && Cards_Act(table,CARDS_ACT_RAISE))
	{
		return 1;
	}

	Cards_Act(table,CARDS_ACT_STAY);
	return 1;
}

#include <pp-hooks>

hook Cards_OnTurn(table,seat)
{
	if (Table_IsSeatRegular(table,seat))
	{
		Cards_ScheduleNpc(table);
	}
}
