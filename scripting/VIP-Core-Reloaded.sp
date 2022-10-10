#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <vip_core>
#pragma newdecls required
#pragma semicolon 1

#define DEBUG 						0
#define D_FEATURENAME_LENGTH		64
#define D_FEATUREVALUE_LENGTH		128
#define D_GROUPNAME_LENGTH 			32

#define CONFIG_MAIN_PATH			"data/vip/cfg"
#define CONFIG_GROUPS_FILENAME		"groups.ini"
#define CONFIG_INFO_FILENAME		"info.ini"
#define CONFIG_SORT_FILENAME		"sort.ini"
#define CONFIG_TIMES_FILENAME		"times.ini"
#define LOGS_FILENAME				"VIP-Core.logs"

#include "VIP-Core/Global.sp"
#include "VIP-Core/Struct.sp"
#include "VIP-Core/Config.sp"
#include "VIP-Core/Database.sp"
#include "VIP-Core/Cmds.sp"
//#include "VIP-Core/Downloads.sp"
//#include "VIP-Core/Sounds.sp"
//#include "VIP-Core/Info.sp"
//#include "VIP-Core/menus.sp"
#include "VIP-Core/UTIL.sp"
#include "VIP-Core/API.sp"
#include "VIP-Core/Events.sp"
#include "VIP-Core/menus/MainMenu.sp"
#include "VIP-Core/menus/AdminMenu.sp"

#include "VIP-Core/Debugger.sp"

public Plugin myinfo =
{
	name = "VIP-Core-Reloaded",
	author = "HLMod Community", // Special Thanks for R1KO
	description = "Add vip status to player",
	version = "4.0 Alpha", // D - Dev, RC - Release Condidate, R - Release
	url = "https://hlmod.ru/resources/vip-core.245"
};

public void OnPluginStart()
{
	LoadTranslations("vip_core.phrases");
	LoadTranslations("vip_modules.phrases");

	LoadStructModule();
	LoadConfigurationModule();

	API_SetupForwards();

	HookEvents();
	LoadAdminMenu();
	LoadMainMenu();
	RegCmds();

	LoadTest();

	CallForward_OnVIPLoaded();
}
