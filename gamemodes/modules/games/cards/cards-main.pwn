#include <pp-hooks>

hook OnGameModeInit()
{
	new answer[HELP_ANSWER_LEN];
	format(answer,sizeof(answer),"~w~Carry a ~y~deck of cards~w~, open your bag and press ~y~Games~w~. Everyone puts the stake in the pot and gets one card, face up.~n~~n~Each round you stay, raise by the stake or fold. Three cards then go to the discard pile and one card is turned in the middle. If the middle card has the same value as yours, you win the pot. Two matches share it.~n~~n~If the deck runs out, the highest card wins. Nobody puts in more than %d pfennig.",TABLE_STAKE_MAX);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I play Lansquenet?",answer);
	Help_Register(HELP_SECTION_ROLEPLAY,"Which Lansquenet card is highest?","~w~The Queen is highest, then the King and the Farmer, then 7 down to 1. On equal cards, Leaves beat Hearts, Hearts beat Bells and Bells beat Acorns.",false);
	Table_RegisterGame(TABLE_GAME_CARDS,"Lansquenet",CARDS_ITEM_KIND,ITEM_CARDS,"Match the middle card with yours to take the pot.");
	Command_Describe("cards","Staff: give yourself a deck of cards.");
	SetTimer("Cards_Tick",CARDS_TICK_MS,true);
}
