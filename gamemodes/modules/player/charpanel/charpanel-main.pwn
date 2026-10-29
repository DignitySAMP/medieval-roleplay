#include <pp-hooks>

hook OnGameModeInit()
{
    Help_Register(HELP_SECTION_START,"How do I open my character panel?","~w~Press ~y~Sprint + Walk (Space + left Alt)~w~ while on foot, out of combat and away from work. You can also open your bag (~y~N~w~) > Character. The panel shows your character's details and condition. Press ~y~ESC~w~ to go back.",true);
	Inventory_AddMenuButton("Character","CharPanel_OpenDeferred");
}
