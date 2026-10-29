#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"How does a turn at dice go?","~w~Roll all six dice. Click the dice that score to keep them, then ~y~Bank~w~ the points or ~y~Roll the rest~w~ for more. If a roll has nothing that scores, you lose everything from that turn.~n~~n~Keep all six and you roll all six again. The first to reach the agreed score wins the pot. If you don't move within 30 seconds, the game banks your best dice for you.");
	Help_Register(HELP_SECTION_ROLEPLAY,"What scores at dice?","~w~A single 1 is worth 100 and a single 5 is worth 50. Three of a kind is worth the face times 100, and three 1s are worth 1000. Each extra die of the same face doubles that.~n~~n~A run of 1 to 5 is worth 500, 2 to 6 is worth 750 and 1 to 6 is worth 1500.",false);
	Help_Register(HELP_SECTION_ROLEPLAY,"What do the special dice do?","~w~Special dice in your bag play in place of plain ones, up to six. A ~y~weighted die~w~ lands on 1 more often and a ~y~heavy die~w~ on 5. A ~y~devil's die~w~ counts a 6 as a 1. A ~y~lucky die~w~ saves you from one bust per game by rolling the dice again.~n~~n~Everyone at the table can see which dice you play with.",false);
	Table_RegisterGame(TABLE_GAME_DICE,"dice",DICE_ITEM_KIND,ITEM_DICE,"The first to reach %s takes the pot.","Play to","1500 points|3000 points|5000 points");
	Command_Describe("dice","Staff: give dice or rig the next roll at your table.");
	SetTimer("Dice_Tick",DICE_TICK_MS,true);
}
