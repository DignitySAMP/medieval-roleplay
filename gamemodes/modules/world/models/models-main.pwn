#define MODEL_HUD_SPRITES (-29999)
#define MODEL_OBJECT_BASE (1923)
#define MODEL_SKIN_BASE (133)

static s_ModelObjects = 0;
static s_ModelSkins = 0;

stock Models_AddObject(modelid,const dff[],const txd[],base = MODEL_OBJECT_BASE)
{
	if (!AddSimpleModel(-1,base,modelid,dff,txd))
	{
		Log_Error("models","object %d (%s) was refused - id out of range, taken, or file missing",modelid,dff);
		return;
	}

	s_ModelObjects++;
}

stock Models_AddSkin(modelid,const dff[],const txd[],base = MODEL_SKIN_BASE)
{
	if (!AddCharModel(base,modelid,dff,txd))
	{
		Log_Error("models","skin %d (%s) was refused - id out of range, taken, or file missing",modelid,dff);
		return;
	}

	s_ModelSkins++;
}

stock Models_GetObjectCount()
{
	return s_ModelObjects;
}

stock Models_GetSkinCount()
{
	return s_ModelSkins;
}

forward Models_OnRegister();

public Models_OnRegister()
{
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	Models_AddObject(MODEL_HUD_SPRITES,"ui/sprite_model.dff","ui/sprite_model.txd");
	pawn_call_public("Models_OnRegister","");
	Log_Info("models","%d object model(s), %d skin(s) registered",s_ModelObjects,s_ModelSkins);
}
