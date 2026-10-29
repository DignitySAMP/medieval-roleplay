#define FAITH_MODEL_MISSAL_CLOSED (-3901)
#define FAITH_MODEL_MISSAL_OPEN (-3902)
#define FAITH_MODEL_ASPERGILLUM (-3903)
#define FAITH_MODEL_PAIL (-3904)
#define FAITH_MODEL_FONT (-3905)
#define FAITH_MODEL_KNEELER (-3906)
#define FAITH_MODEL_RACK_EMPTY (-3907)
#define FAITH_MODEL_RACK_SOME (-3908)
#define FAITH_MODEL_RACK_FULL (-3909)
#define FAITH_MODEL_BED (-3910)
#define FAITH_MODEL_TXD "faith/faith.txd"
#define FAITH_PROP_RANGE (60.0)
#define FAITH_ALTAR_TOP_Z (19.29)
#define FAITH_ALTAR_TOP_MIN_X (716.77)
#define FAITH_ALTAR_TOP_MAX_X (718.63)
#define FAITH_ALTAR_TOP_MIN_Y (-3606.35)
#define FAITH_ALTAR_TOP_MAX_Y (-3603.65)

enum E_FAITH_MODEL
{
	E_FAITH_MODEL_ID,
	E_FAITH_MODEL_DFF[32],
	E_FAITH_MODEL_BASE,
}

static const s_FaithModels[][E_FAITH_MODEL] = {
	{FAITH_MODEL_MISSAL_CLOSED, "faith/missal_closed.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_MISSAL_OPEN, "faith/missal_open.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_ASPERGILLUM, "faith/aspergillum.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_PAIL, "faith/pail.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_FONT, "faith/font.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_KNEELER, "faith/kneeler.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_RACK_EMPTY, "faith/rack_empty.dff", MAP_BASE_STATIC},
	{FAITH_MODEL_RACK_SOME, "faith/rack_some.dff", MAP_BASE_BLEND},
	{FAITH_MODEL_RACK_FULL, "faith/rack_full.dff", MAP_BASE_BLEND},
	{FAITH_MODEL_BED, "faith/bed.dff", MAP_BASE_STATIC}
};

enum E_FAITH_PROP
{
	E_FAITH_PROP_MODEL,
	Float:E_FAITH_PROP_POS[4],
}

static const s_FaithProps[][E_FAITH_PROP] = {
	{FAITH_MODEL_FONT, {681.8, -3603.7, 17.507, 0.0}},
	{FAITH_MODEL_PAIL, {682.8, -3603.0, 17.803, 0.0}},
	{FAITH_MODEL_KNEELER, {714.6, -3601.3, 17.507, 270.0}},
	{FAITH_MODEL_KNEELER, {714.6, -3604.7, 17.507, 270.0}},
	{FAITH_MODEL_MISSAL_OPEN, {717.75, -3604.3, 19.38, 270.0}},
	{FAITH_MODEL_ASPERGILLUM, {717.2, -3605.5, 19.324, 0.0}}
};

static STREAMER_TAG_OBJECT:s_FaithPropObjects[sizeof(s_FaithProps)];

static bool:Faith_IsModelPlaced(modelid)
{
	if (modelid == FAITH_MODEL_BED)
	{
		return true;
	}

	for (new i = 0;i < sizeof(s_FaithProps);i++)
	{
		if (s_FaithProps[i][E_FAITH_PROP_MODEL] == modelid)
		{
			return true;
		}
	}

	return false;
}

stock Faith_RegisterModels()
{
	for (new i = 0;i < sizeof(s_FaithModels);i++)
	{
		if (!Faith_IsModelPlaced(s_FaithModels[i][E_FAITH_MODEL_ID]))
		{
			continue;
		}

		Models_AddObject(s_FaithModels[i][E_FAITH_MODEL_ID],s_FaithModels[i][E_FAITH_MODEL_DFF],FAITH_MODEL_TXD,s_FaithModels[i][E_FAITH_MODEL_BASE]);
	}
}

stock Faith_PlaceProps()
{
	for (new i = 0;i < sizeof(s_FaithProps);i++)
	{
		s_FaithPropObjects[i] = CreateDynamicObject(s_FaithProps[i][E_FAITH_PROP_MODEL],s_FaithProps[i][E_FAITH_PROP_POS][0],s_FaithProps[i][E_FAITH_PROP_POS][1],s_FaithProps[i][E_FAITH_PROP_POS][2],0.0,0.0,s_FaithProps[i][E_FAITH_PROP_POS][3],0,0,-1,FAITH_PROP_RANGE,FAITH_PROP_RANGE);
	}
}

stock bool:Faith_GetPropPos(modelid,&Float:x,&Float:y,&Float:z,&Float:a = 0.0)
{
	for (new i = 0;i < sizeof(s_FaithProps);i++)
	{
		if (s_FaithProps[i][E_FAITH_PROP_MODEL] == modelid)
		{
			x = s_FaithProps[i][E_FAITH_PROP_POS][0];
			y = s_FaithProps[i][E_FAITH_PROP_POS][1];
			z = s_FaithProps[i][E_FAITH_PROP_POS][2];
			a = s_FaithProps[i][E_FAITH_PROP_POS][3];
			return true;
		}
	}

	return false;
}

stock Faith_CountProps()
{
	new count = 0;

	for (new i = 0;i < sizeof(s_FaithProps);i++)
	{
		if (IsValidDynamicObject(s_FaithPropObjects[i]))
		{
			count++;
		}
	}

	return count;
}

#include <pp-hooks>

hook Models_OnRegister()
{
	Faith_RegisterModels();
}
