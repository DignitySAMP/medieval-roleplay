#define MOUNT_MODEL_BASE (-26000)
#define MOUNT_COAT_MODEL_BASE (-28100)
#define MOUNT_COAT_MODELS_PER_TYPE (150)
#define MOUNT_FIRST_COAT_TYPE (5)
#define MOUNT_MODELS_PER_TYPE (200)
#define MOUNT_TYPE_COUNT (15)
#define MOUNT_DONKEY_TYPE (4)
#define MOUNT_DONKEY_IDLE_FRAMES (1)
#define MOUNT_DONKEY_WALK_FRAMES (29)
#define MOUNT_DONKEY_SPRINT_FRAMES (20)
#define MOUNT_DONKEY_SPEED_FACTOR (0.7)
#define MOUNT_IDLE_FRAMES (57)
#define MOUNT_WALK_FRAMES (29)
#define MOUNT_GALLOP_FRAMES (17)
#define MOUNT_SPRINT_FRAMES (19)
#define MOUNT_GAIT_IDLE_OFFSET (0)
#define MOUNT_GAIT_WALK_OFFSET (60)
#define MOUNT_GAIT_GALLOP_OFFSET (100)
#define MOUNT_GAIT_SPRINT_OFFSET (130)
#define MOUNT_NAME_LEN (24)
#define MOUNT_STAMINA_MAX (100)
#define MOUNT_STAMINA_GALLOP_MIN (15)

enum E_MOUNT_GAIT
{
	MOUNT_GAIT_IDLE,
	MOUNT_GAIT_WALK,
	MOUNT_GAIT_GALLOP,
	MOUNT_GAIT_SPRINT,
}

static const s_MountTypeNames[MOUNT_TYPE_COUNT][MOUNT_NAME_LEN] = {
	"Chestnut Appaloosa", "Tennessee Walker", "Dapple Mustang", "Dutch Warmblood", "Donkey",
	"Bay", "Dark Bay", "Chestnut", "Black", "Flea-bitten Grey", "Dun", "Palomino Dun", "Piebald", "Blue Roan", "Strawberry Roan"
};

static const s_MountTypeTxd[MOUNT_TYPE_COUNT][40] = {
	"mounts/horses/horse_txd_a.txd", "mounts/horses/horse_txd_b.txd", "mounts/horses/horse_txd_c.txd", "mounts/horses/horse_txd_d.txd", "mounts/donkey/donkey.txd",
	"mounts/horses/horse_txd_e.txd", "mounts/horses/horse_txd_f.txd", "mounts/horses/horse_txd_g.txd", "mounts/horses/horse_txd_h.txd", "mounts/horses/horse_txd_i.txd",
	"mounts/horses/horse_txd_j.txd", "mounts/horses/horse_txd_k.txd", "mounts/horses/horse_txd_l.txd", "mounts/horses/horse_txd_m.txd", "mounts/horses/horse_txd_n.txd"
};

stock bool:Mount_IsValidType(type)
{
	return type >= 0 && type < MOUNT_TYPE_COUNT;
}

stock bool:Mount_TypeIsDonkey(type)
{
	return type == MOUNT_DONKEY_TYPE;
}

stock bool:Mount_TypeCanGallop(type)
{
	return Mount_IsValidType(type) && !Mount_TypeIsDonkey(type);
}

stock Float:Mount_TypeSpeedFactor(type)
{
	return Mount_TypeIsDonkey(type) ? MOUNT_DONKEY_SPEED_FACTOR : 1.0;
}

stock Mount_TypeGaitFrames(type,E_MOUNT_GAIT:gait)
{
	if (!Mount_TypeIsDonkey(type))
	{
		return Mount_GaitFrames(gait);
	}

	switch (gait)
	{
		case MOUNT_GAIT_WALK: return MOUNT_DONKEY_WALK_FRAMES;
		case MOUNT_GAIT_GALLOP, MOUNT_GAIT_SPRINT: return MOUNT_DONKEY_SPRINT_FRAMES;
		case MOUNT_GAIT_IDLE: return MOUNT_DONKEY_IDLE_FRAMES;
	}

	return MOUNT_DONKEY_IDLE_FRAMES;
}

stock Mount_TypeName(type,dest[],size = sizeof(dest))
{
	if (!Mount_IsValidType(type))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_MountTypeNames[type],size);
}

stock Mount_GaitFrames(E_MOUNT_GAIT:gait)
{
	switch (gait)
	{
		case MOUNT_GAIT_WALK: return MOUNT_WALK_FRAMES;
		case MOUNT_GAIT_GALLOP: return MOUNT_GALLOP_FRAMES;
		case MOUNT_GAIT_SPRINT: return MOUNT_SPRINT_FRAMES;
		case MOUNT_GAIT_IDLE: return MOUNT_IDLE_FRAMES;
	}

	return MOUNT_IDLE_FRAMES;
}

static Mount_GaitOffset(E_MOUNT_GAIT:gait)
{
	switch (gait)
	{
		case MOUNT_GAIT_WALK: return MOUNT_GAIT_WALK_OFFSET;
		case MOUNT_GAIT_GALLOP: return MOUNT_GAIT_GALLOP_OFFSET;
		case MOUNT_GAIT_SPRINT: return MOUNT_GAIT_SPRINT_OFFSET;
		case MOUNT_GAIT_IDLE: return MOUNT_GAIT_IDLE_OFFSET;
	}

	return MOUNT_GAIT_IDLE_OFFSET;
}

stock Mount_FrameModel(type,E_MOUNT_GAIT:gait,frame)
{
	if (!Mount_IsValidType(type))
	{
		type = 0;
	}

	if (Mount_TypeIsDonkey(type) && gait == MOUNT_GAIT_GALLOP)
	{
		gait = MOUNT_GAIT_SPRINT;
	}

	new frames = Mount_TypeGaitFrames(type,gait);
	if (frame < 0 || frame >= frames)
	{
		frame = 0;
	}

	if (type >= MOUNT_FIRST_COAT_TYPE)
	{
		return MOUNT_COAT_MODEL_BASE - ((type - MOUNT_FIRST_COAT_TYPE) * MOUNT_COAT_MODELS_PER_TYPE + Mount_GaitOffset(gait) + frame);
	}

	return MOUNT_MODEL_BASE - (type * MOUNT_MODELS_PER_TYPE + Mount_GaitOffset(gait) + frame);
}

stock Mount_StandingModel(type)
{
	return Mount_FrameModel(type,MOUNT_GAIT_IDLE,0);
}

#include <pp-hooks>

hook Models_OnRegister()
{
	new dff[48];
	for (new type = 0; type < MOUNT_TYPE_COUNT; type++)
	{
		if (Mount_TypeIsDonkey(type))
		{
			Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_IDLE,0),"mounts/donkey/donkey.dff",s_MountTypeTxd[type]);
			for (new i = 0; i < MOUNT_DONKEY_WALK_FRAMES; i++)
			{
				format(dff,sizeof(dff),"mounts/donkey/walking/%d.dff",MOUNT_DONKEY_WALK_FRAMES - i);
				Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_WALK,i),dff,s_MountTypeTxd[type]);
			}

			for (new i = 0; i < MOUNT_DONKEY_SPRINT_FRAMES; i++)
			{
				format(dff,sizeof(dff),"mounts/donkey/sprint/%d.dff",i + 1);
				Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_SPRINT,i),dff,s_MountTypeTxd[type]);
			}

			continue;
		}

		for (new i = 0; i < MOUNT_IDLE_FRAMES; i++)
		{
			format(dff,sizeof(dff),"mounts/horses/idle/%d.dff",i);
			Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_IDLE,i),dff,s_MountTypeTxd[type]);
		}

		for (new i = 0; i < MOUNT_WALK_FRAMES; i++)
		{
			format(dff,sizeof(dff),"mounts/horses/walk/%d.dff",i + 1);
			Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_WALK,i),dff,s_MountTypeTxd[type]);
		}

		for (new i = 0; i < MOUNT_GALLOP_FRAMES; i++)
		{
			format(dff,sizeof(dff),"mounts/horses/gallop/%d.dff",i + 1);
			Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_GALLOP,i),dff,s_MountTypeTxd[type]);
		}

		for (new i = 0; i < MOUNT_SPRINT_FRAMES; i++)
		{
			format(dff,sizeof(dff),"mounts/horses/sprint/%d.dff",i + 1);
			Models_AddObject(Mount_FrameModel(type,MOUNT_GAIT_SPRINT,i),dff,s_MountTypeTxd[type]);
		}
	}
}
