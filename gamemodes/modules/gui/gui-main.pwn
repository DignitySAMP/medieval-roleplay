#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("fx","Staff: test a screen effect, or hand it back.");
	Command_Describe("uidemo","Staff: show the UI kit demo.");
	Keys_RegisterContext(KEY_SECONDARY_ATTACK,KEYS_PRIO_MENU,"Gui_KeyContext");
	Keys_RegisterContext(KEY_SPRINT,KEYS_PRIO_MENU,"Gui_KeyContext");
	Keys_RegisterContext(KEY_JUMP,KEYS_PRIO_MENU,"Gui_KeyContext");
	Keys_RegisterContext(KEY_HANDBRAKE,KEYS_PRIO_MENU,"Gui_KeyContext");
	SetTimer("Animator_Process",ANIMATION_UPDATE_RATE,true);
	Log_Info("gui","dialogs, notices, fades and the temporary hud ready");
}
