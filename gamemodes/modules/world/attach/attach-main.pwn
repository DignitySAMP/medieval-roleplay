#include <pp-hooks>

hook OnGameModeInit()
{
	pawn_add_filter("SetPlayerAttachedObject","iiiifffffffffii","Attach_FilterFit",filter_in);
	Boot_RegisterLoader("Attach_LoadOnBoot");
	Command_Describe("attach","Staff: fit any attachment (torch, lantern, loads, weapons) and save the fit for everyone.");
	Command_Describe("attachoff","Staff: take off the attachment /attach put on you.");
}

hook OnMigrationRun()
{
	Migration_Add("attach-1-fits", "CREATE TABLE IF NOT EXISTS attach_fits (model INT NOT NULL, bone TINYINT NOT NULL, ox FLOAT NOT NULL, oy FLOAT NOT NULL, oz FLOAT NOT NULL, rx FLOAT NOT NULL, ry FLOAT NOT NULL, rz FLOAT NOT NULL, sx FLOAT NOT NULL DEFAULT 1, sy FLOAT NOT NULL DEFAULT 1, sz FLOAT NOT NULL DEFAULT 1, PRIMARY KEY (model, bone)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("attach-2-tuned-fits", "INSERT IGNORE INTO attach_fits (model, bone, ox, oy, oz, rx, ry, rz, sx, sy, sz) VALUES (-8219, 6, 0.096, 0.038, 0.0, 87.0, -94.2, 172.2, 1.0, 1.0, 1.0), (-8218, 6, 0.096, 0.038, 0.0, 87.0, -4.2, -174.1, 1.0, 1.0, 1.0), (-6909, 6, 0.167, 0.02, 0.0, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0), (-6650, 1, 0.06, -0.184, 0.0, -92.1, -3.6, -93.8, 1.0, 1.0, 1.0), (-6221, 5, 0.09, 0.03, 0.0, 180.0, 0.0, 0.0, 1.0, 1.0, 1.0), (-6220, 6, 0.089, 0.076, -0.07, 78.4, 76.2, -0.7, 1.0, 1.0, 1.0), (-6219, 5, -0.157, 0.03, -0.06, 41.6, 160.5, -117.7, 1.0, 1.0, 1.0), (-5516, 5, 0.131, 0.011, 0.05, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0), (-5513, 1, 0.103, 0.3, -0.04, 82.9, 91.9, -87.5, 1.0, 1.0, 1.0), (-5512, 1, 0.099, 0.25, -0.04, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0), (-5511, 1, 0.22, 0.0, -0.151, 81.5, 101.7, -82.1, 1.0, 1.0, 1.0), (-5510, 1, 0.166, 0.0, -0.17, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0), (-5509, 5, 0.111, 0.038, 0.0, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0), (-5508, 5, 0.096, 0.025, 0.0, 0.0, -90.0, 17.6, 1.0, 1.0, 1.0), (-5507, 5, 0.142, 0.038, 0.0, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0), (-5505, 1, -0.394, -0.152, -0.003, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0), (-5504, 1, 0.029, -0.158, 0.0, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0), (-5503, 1, -0.043, 0.416, -0.04, 79.6, 87.4, -79.6, 1.0, 1.0, 1.0), (-5306, 7, 0.014, 0.066, -0.136, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0), (-5301, 5, 0.087, 0.025, 0.1, -133.5, 0.0, 180.0, 1.0, 1.0, 1.0), (19632, 5, 0.05, -0.299, -0.222, 0.0, 0.0, 0.0, 0.01, 0.01, 0.01), (-5307, 7, 0.014, 0.066, -0.136, 0.0, -90.0, 0.0, 1.0, 1.0, 1.0)");
}
