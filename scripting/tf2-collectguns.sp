/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[TF2] Collect Guns"
#define PLUGIN_DESCRIPTION "A gamemode which allows for gun collecting with custom statistics and attributes Borderlands style."
#define PLUGIN_VERSION "1.0.0"

/*****************************/
//Includes
#include <sourcemod>

/*****************************/
//ConVars

/*****************************/
//Globals

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_generateweapon", Command_GenerateWeapon, ADMFLAG_ROOT);
}

public Action Command_GenerateWeapon(int client, int args)
{
	GenerateWeapon();
	return Plugin_Handled;
}

void GenerateWeapon()
{
	
}