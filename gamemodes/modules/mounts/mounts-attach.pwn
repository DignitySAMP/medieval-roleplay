enum
{
	MOUNT_ATTACH_X,
	MOUNT_ATTACH_Y,
	MOUNT_ATTACH_Z,
	MOUNT_ATTACH_RX,
	MOUNT_ATTACH_RY,
	MOUNT_ATTACH_RZ,
	MOUNT_ATTACH_COUNT,
}

#define MOUNT_GAIT_COUNT (4)

static const Float:s_MountDefaultStand[MOUNT_ATTACH_COUNT] = {0.0, 0.0, -0.14, 0.0, -90.0, -90.0};
static const Float:s_MountDonkeyStand[MOUNT_ATTACH_COUNT] = {0.0, 0.0, -0.349, 0.0, 0.4, 180.0};

static const Float:s_MountHorseAttach[MOUNT_GAIT_COUNT][MOUNT_ATTACH_COUNT] = {
	{-0.48, 0.448, -0.018, -92.4, 13.2, 1.0},
	{-0.441, 0.324, 0.0, -91.5, 16.8, 0.0},
	{-0.441, 0.324, 0.0, -91.5, 16.8, 0.0},
	{-0.479, 0.273, 0.0, -179.6, -2.5, 19.5}
};

static const Float:s_MountDonkeyAttach[MOUNT_GAIT_COUNT][MOUNT_ATTACH_COUNT] = {
	{-0.479, 0.448, -0.017, 93.5, 73.1, 89.1},
	{-0.641, 0.378, -0.022, -91.5, 16.7, 2.2},
	{-0.512, 0.420, -0.031, -93.4, 15.6, 1.3},
	{-0.512, 0.419, -0.025, -90.3, 15.1, 2.0}
};

static Float:s_MountSeat[MOUNT_TYPE_COUNT][MOUNT_GAIT_COUNT][MOUNT_ATTACH_COUNT];
static Float:s_MountStand[MOUNT_TYPE_COUNT][MOUNT_ATTACH_COUNT];

Mount_ResetPoses()
{
	for (new type = 0;type < MOUNT_TYPE_COUNT;type++)
	{
		for (new i = 0;i < MOUNT_ATTACH_COUNT;i++)
		{
			s_MountStand[type][i] = Mount_TypeIsDonkey(type) ? s_MountDonkeyStand[i] : s_MountDefaultStand[i];

			for (new gait = 0;gait < MOUNT_GAIT_COUNT;gait++)
			{
				s_MountSeat[type][gait][i] = Mount_TypeIsDonkey(type) ? s_MountDonkeyAttach[gait][i] : s_MountHorseAttach[gait][i];
			}
		}
	}
}

stock Mount_GetAttach(type,E_MOUNT_GAIT:gait,&Float:x,&Float:y,&Float:z,&Float:rx,&Float:ry,&Float:rz)
{
	new g = _:gait;

	if (!Mount_IsValidType(type))
	{
		type = 0;
	}

	if (g < 0 || g >= MOUNT_GAIT_COUNT)
	{
		g = 0;
	}

	x = s_MountSeat[type][g][MOUNT_ATTACH_X];
	y = s_MountSeat[type][g][MOUNT_ATTACH_Y];
	z = s_MountSeat[type][g][MOUNT_ATTACH_Z];
	rx = s_MountSeat[type][g][MOUNT_ATTACH_RX];
	ry = s_MountSeat[type][g][MOUNT_ATTACH_RY];
	rz = s_MountSeat[type][g][MOUNT_ATTACH_RZ];
}

stock Mount_SetAttach(type,E_MOUNT_GAIT:gait,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz,bool:isSaved = true)
{
	new g = _:gait;

	if (!Mount_IsValidType(type) || g < 0 || g >= MOUNT_GAIT_COUNT)
	{
		return;
	}

	s_MountSeat[type][g][MOUNT_ATTACH_X] = x;
	s_MountSeat[type][g][MOUNT_ATTACH_Y] = y;
	s_MountSeat[type][g][MOUNT_ATTACH_Z] = z;
	s_MountSeat[type][g][MOUNT_ATTACH_RX] = rx;
	s_MountSeat[type][g][MOUNT_ATTACH_RY] = ry;
	s_MountSeat[type][g][MOUNT_ATTACH_RZ] = rz;

	if (isSaved)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO mount_seats (type, gait, x, y, z, rx, ry, rz) VALUES (%d, %d, %f, %f, %f, %f, %f, %f) ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), rx = VALUES(rx), ry = VALUES(ry), rz = VALUES(rz)",type,g,x,y,z,rx,ry,rz));
	}
}

stock Mount_GetStandPose(type,Float:x,Float:y,Float:z,Float:a,&Float:ox,&Float:oy,&Float:oz,&Float:rx,&Float:ry,&Float:rz)
{
	if (!Mount_IsValidType(type))
	{
		type = 0;
	}

	new Float:dx = s_MountStand[type][MOUNT_ATTACH_X], Float:dy = s_MountStand[type][MOUNT_ATTACH_Y];
	ox = x + dx * floatcos(a,degrees) - dy * floatsin(a,degrees);
	oy = y + dx * floatsin(a,degrees) + dy * floatcos(a,degrees);
	oz = z + s_MountStand[type][MOUNT_ATTACH_Z];
	rx = s_MountStand[type][MOUNT_ATTACH_RX];
	ry = s_MountStand[type][MOUNT_ATTACH_RY];
	rz = a + s_MountStand[type][MOUNT_ATTACH_RZ];
}

stock Mount_SetStandFromPose(type,Float:x,Float:y,Float:z,Float:a,Float:ox,Float:oy,Float:oz,Float:rx,Float:ry,Float:rz)
{
	if (!Mount_IsValidType(type))
	{
		return;
	}

	new Float:wx = ox - x, Float:wy = oy - y;
	s_MountStand[type][MOUNT_ATTACH_X] = wx * floatcos(-a,degrees) - wy * floatsin(-a,degrees);
	s_MountStand[type][MOUNT_ATTACH_Y] = wx * floatsin(-a,degrees) + wy * floatcos(-a,degrees);
	s_MountStand[type][MOUNT_ATTACH_Z] = oz - z;
	s_MountStand[type][MOUNT_ATTACH_RX] = rx;
	s_MountStand[type][MOUNT_ATTACH_RY] = ry;
	s_MountStand[type][MOUNT_ATTACH_RZ] = rz - a;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO mount_stands (type, x, y, z, rx, ry, rz) VALUES (%d, %f, %f, %f, %f, %f, %f) ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), rx = VALUES(rx), ry = VALUES(ry), rz = VALUES(rz)",type,s_MountStand[type][0],s_MountStand[type][1],s_MountStand[type][2],s_MountStand[type][3],s_MountStand[type][4],s_MountStand[type][5]));
}

forward Mount_LoadPosesOnBoot();

public Mount_LoadPosesOnBoot()
{
	yield 1;

	Mount_ResetPoses();
	await mysql_aquery_s(g_Mysql,str_new("SELECT type, gait, x, y, z, rx, ry, rz FROM mount_seats"),false);

	new seats = cache_num_rows();

	for (new row = 0;row < seats;row++)
	{
		new type, gait, Float:v[MOUNT_ATTACH_COUNT];
		cache_get_value_name_int(row,"type",type);
		cache_get_value_name_int(row,"gait",gait);
		cache_get_value_name_float(row,"x",v[0]);
		cache_get_value_name_float(row,"y",v[1]);
		cache_get_value_name_float(row,"z",v[2]);
		cache_get_value_name_float(row,"rx",v[3]);
		cache_get_value_name_float(row,"ry",v[4]);
		cache_get_value_name_float(row,"rz",v[5]);
		Mount_SetAttach(type,E_MOUNT_GAIT:gait,v[0],v[1],v[2],v[3],v[4],v[5],false);
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT type, x, y, z, rx, ry, rz FROM mount_stands"),false);

	new stands = cache_num_rows();

	for (new row = 0;row < stands;row++)
	{
		new type;
		cache_get_value_name_int(row,"type",type);

		if (Mount_IsValidType(type))
		{
			cache_get_value_name_float(row,"x",s_MountStand[type][0]);
			cache_get_value_name_float(row,"y",s_MountStand[type][1]);
			cache_get_value_name_float(row,"z",s_MountStand[type][2]);
			cache_get_value_name_float(row,"rx",s_MountStand[type][3]);
			cache_get_value_name_float(row,"ry",s_MountStand[type][4]);
			cache_get_value_name_float(row,"rz",s_MountStand[type][5]);
		}
	}

	Log_Info("mounts","%d saved seat(s), %d saved stand(s)",seats,stands);
	Boot_LoaderDone();
}
