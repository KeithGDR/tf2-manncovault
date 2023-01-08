/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[TF2] MannCo Vault"
#define PLUGIN_DESCRIPTION "Collect custom built weapons from the MannCo Vault!"
#define PLUGIN_VERSION "1.0.0"

#define DIR_PERMS 511

/*****************************/
//Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#include <json>
#include <tf_econ_data>
#include <tf2items>

/*****************************/
//ConVars

/*****************************/
//Globals

Database g_Database;
KeyValues g_ItemSchema;

enum TF2Quality {
	TF2Quality_Normal = 0, // 0
	TF2Quality_Rarity1,
	TF2Quality_Genuine = 1,
	TF2Quality_Rarity2,
	TF2Quality_Vintage,
	TF2Quality_Rarity3,
	TF2Quality_Rarity4,
	TF2Quality_Unusual = 5,
	TF2Quality_Unique,
	TF2Quality_Community,
	TF2Quality_Developer,
	TF2Quality_Selfmade,
	TF2Quality_Customized, // 10
	TF2Quality_Strange,
	TF2Quality_Completed,
	TF2Quality_Haunted,
	TF2Quality_ToborA
};

/*****************************/
//Plugin Info
public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public void OnPluginStart() {
	Database.Connect(OnSQLConnect, "default");

	RegAdminCmd("sm_mcv", Command_MCV, ADMFLAG_GENERIC, "Opens the MannCo Vault menu.");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/manncovault/");

	if (!DirExists(sPath)) {
		CreateDirectory(sPath, DIR_PERMS);
	}

	g_ItemSchema = GetItemSchema();
	if (g_ItemSchema == null) {
		ThrowError("[TF2] MannCo Vault: Failed to load item schema!");
	}

	// g_ItemSchema.GotoFirstSubKey();
	// char sName[64];
	// do {
	// 	g_ItemSchema.GetSectionName(sName, sizeof(sName));
	// 	//PrintToServer("Name: %s", sName);
	// } while (g_ItemSchema.GotoNextKey());
	// delete g_ItemSchema;
}

public void OnConfigsExecuted() {

}

public void OnSQLConnect(Database db, const char[] error, any data) {
	if (db == null) {
		ThrowError("[TF2] MannCo Vault: Failed to connect to database: %s", error);
	}

	g_Database = db;
	LogMessage("[TF2] MannCo Vault: Connected to database!");

	if (g_Database) {

	}
}

public Action Command_MCV(int client, int args) {
	OpenMenu(client);
	return Plugin_Handled;
}

void OpenMenu(int client) {
	Menu menu = new Menu(OpenMenuHandler);
	menu.SetTitle("MannCo Vault");

	menu.AddItem("generate_e", "Generate Weapon Equipped");
	menu.AddItem("generate_d", "Generate Weapon Drop");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if (StrEqual(info, "generate_e")) {
				OpenGenerateEquipWeapon(param1);
			} else if (StrEqual(info, "generate_d")) {
				OpenGenerateDropWeapon(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	return 0;
}

void OpenGenerateEquipWeapon(int client) {
	Menu menu = new Menu(OpenGenerateEquipMenuHandler);
	menu.SetTitle("MannCo Vault - Generate Weapon Equip");

	menu.AddItem("generate_primary", "Generate a primary weapon.");
	menu.AddItem("generate_secondary", "Generate a secondary weapon.");
	menu.AddItem("generate_melee", "Generate a melee weapon.");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenGenerateEquipMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			TFClassType class = TF2_GetPlayerClass(param1);
			int slot;

			if (StrEqual(info, "generate_primary")) {
				slot = TFWeaponSlot_Primary;
				int entity = GenerateEquipWeapon(class, slot, param1);
				PrintToChatAll("Entity: %d", entity);
			} else if (StrEqual(info, "generate_secondary")) {
				slot = TFWeaponSlot_Secondary;
				int entity = GenerateEquipWeapon(class, slot, param1);
				PrintToChatAll("Entity: %d", entity);
			} else if (StrEqual(info, "generate_melee")) {
				slot = TFWeaponSlot_Melee;
				int entity = GenerateEquipWeapon(class, slot, param1);
				PrintToChatAll("Entity: %d", entity);
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void OpenGenerateDropWeapon(int client) {
	Menu menu = new Menu(OpenGenerateDropMenuHandler);
	menu.SetTitle("MannCo Vault - Generate Weapon Drop");

	menu.AddItem("generate_primary", "Generate a primary weapon.");
	menu.AddItem("generate_secondary", "Generate a secondary weapon.");
	menu.AddItem("generate_melee", "Generate a melee weapon.");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenGenerateDropMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			TFClassType class = TF2_GetPlayerClass(param1);
			int slot;

			float vOrigin[3];
			GetClientEyePosition(param1, vOrigin);

			float velocity[3];
			velocity[0] = GetRandomFloat(-100.0, 100.0);
			velocity[1] = GetRandomFloat(-100.0, 100.0);
			velocity[2] = GetRandomFloat(100.0, 200.0);

			if (StrEqual(info, "generate_primary")) {
				slot = TFWeaponSlot_Primary;
				int entity = GenerateDroppedWeapon(class, slot, vOrigin, velocity);
				PrintToChatAll("Entity: %d", entity);
			} else if (StrEqual(info, "generate_secondary")) {
				slot = TFWeaponSlot_Secondary;
				int entity = GenerateDroppedWeapon(class, slot, vOrigin, velocity);
				PrintToChatAll("Entity: %d", entity);
			} else if (StrEqual(info, "generate_melee")) {
				slot = TFWeaponSlot_Melee;
				int entity = GenerateDroppedWeapon(class, slot, vOrigin, velocity);
				PrintToChatAll("Entity: %d", entity);
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

int GenerateEquipWeapon(TFClassType class, int slot, int client) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return -1;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return -1;
	}

	JSON_Object weapon = GenerateWeapon(class, slot);

	char name[64];
	weapon.GetString("name", name, sizeof(name));
	PrintToChat(client, "Equipping Weapon: %s", name);

	int index = weapon.GetInt("index");

	char classname[64];
	weapon.GetString("classname", classname, sizeof(classname));

	TF2_RemoveWeaponSlot(client, slot);

	return TF2_GiveItem(client, classname, index);
}

int GenerateDroppedWeapon(TFClassType class, int slot, float origin[3], float velocity[3]) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return -1;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return -1;
	}

	JSON_Object weapon = GenerateWeapon(class, slot);
	int index = weapon.GetInt("index");

	return TF2_CreateDroppedWeapon(index, origin, NULL_VECTOR, velocity);
}

JSON_Object GenerateWeapon(TFClassType class, int slot) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return null;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return null;
	}

	JSON_Object weapon = new JSON_Object();

	int index = GetRandomIndex(class, slot);

	char classname[64];
	TF2Econ_GetItemClassName(index, classname, sizeof(classname));

	char name[64];
	GenerateWeaponName(name, sizeof(name));

	weapon.SetString("name", name);
	weapon.SetInt("index", index);
	weapon.SetString("classname", classname);

	return weapon;
}

void GenerateWeaponName(char[] buffer, int size) {
	strcopy(buffer, size, "The");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/manncovault/names.txt");

	File file = OpenFile(sPath, "r");

	if (file == null) {
		ThrowError("[TF2] MannCo Vault: Failed to parse file: %s", sPath);
	}

	for (int i = 0; i < GetRandomInt(1, 2); i++) {
		char name[64]; ArrayList words = new ArrayList(64);
		while (!file.EndOfFile() && file.ReadLine(name, sizeof(name))) {
			if (strlen(name) == 0) {
				continue;
			}

			words.PushString(name);
		}

		words.GetString(GetRandomInt(0, words.Length - 1), name, sizeof(name));
		delete words;

		Format(buffer, size, "%s %s", buffer, name);
	}

	file.Close();
}

int GetRandomIndex(TFClassType class, int slot) {
	if (class < TFClass_Scout || class > TFClass_Spy) {
		LogError("[TF2] MannCo Vault: Invalid class type %d", class);
		return -1;
	}

	if (slot < TFWeaponSlot_Primary || slot > TFWeaponSlot_Item2) {
		LogError("[TF2] MannCo Vault: Invalid slot %d", slot);
		return -1;
	}

	ArrayList items = new ArrayList();

	char sClass[64];
	TF2_GetClassName(class, sClass, sizeof(sClass));
	
	char sSlotString[64];
	if (slot == TFWeaponSlot_Primary) {
		sSlotString = "primary";
	} else if (slot == TFWeaponSlot_Secondary) {
		sSlotString = "secondary";
	} else if (slot == TFWeaponSlot_Melee) {
		sSlotString = "melee";
	}

	for (int i = 0; i < 10000; i++) {
		if (TF2Econ_GetItemLoadoutSlot(i, class) == slot) {
			items.Push(i);
		}
	}

	int length = items.Length;

	if (length < 1) {
		delete items;
		return -1;
	}

	int random = items.Get(GetRandomInt(0, length - 1));
	delete items;

	return random;
}

int TF2_CreateDroppedWeapon(int index, float origin[3], float angle[3] = NULL_VECTOR, float velocity[3] = NULL_VECTOR, const char[] model = "") {
	int entity = CreateEntityByName("tf_dropped_weapon");
	
	if (!IsValidEntity(entity)) {
		return entity;
	}
	
	SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", -1);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", -1);
	
	if (strlen(model) > 0) {
		SetEntityModel(entity, model);
	}
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, origin, angle, velocity);
	
	return entity;
}

KeyValues GetItemSchema() {
	KeyValues kv = new KeyValues("items_game");
	kv.ImportFromFile("scripts/items/items_game.txt");
	return kv;
}

void TF2_GetClassName(TFClassType class, char[] buffer, int size, bool capitalize = false) {
	switch (class) {
		case TFClass_Unknown: {
			strcopy(buffer, size, "unknown");
		}
		case TFClass_Scout: {
			strcopy(buffer, size, "scout");
		}
		case TFClass_Sniper: {
			strcopy(buffer, size, "sniper");
		}
		case TFClass_Soldier: {
			strcopy(buffer, size, "soldier");
		}
		case TFClass_DemoMan: {
			strcopy(buffer, size, "demoman");
		}
		case TFClass_Medic: {
			strcopy(buffer, size, "medic");
		}
		case TFClass_Heavy: {
			strcopy(buffer, size, "heavy");
		}
		case TFClass_Pyro: {
			strcopy(buffer, size, "pyro");
		}
		case TFClass_Spy: {
			strcopy(buffer, size, "spy");
		}
		case TFClass_Engineer: {
			strcopy(buffer, size, "engineer");
		}
	}

	if (capitalize) {
		buffer[0] = CharToUpper(buffer[0]);
	} else {
		buffer[0] = CharToLower(buffer[0]);
	}
}

stock int TF2_GiveItem(int client, char[] classname, int index, TF2Quality quality = TF2Quality_Normal, int level = 0, const char[] attributes = "") {
	char sClass[64];
	strcopy(sClass, sizeof(sClass), classname);
	
	if (StrContains(sClass, "saxxy", false) != -1) {
		switch (TF2_GetPlayerClass(client)) {
			case TFClass_Scout: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bat");
			}
			case TFClass_Sniper: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_club");
			}
			case TFClass_Soldier: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shovel");
			}
			case TFClass_DemoMan: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bottle");
			}
			case TFClass_Engineer: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_wrench");
			}
			case TFClass_Pyro: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_fireaxe");
			}
			case TFClass_Heavy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_fists");
			}
			case TFClass_Spy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_knife");
			}
			case TFClass_Medic: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_bonesaw");
			}
		}
	} else if (StrContains(sClass, "shotgun", false) != -1) {
		switch (TF2_GetPlayerClass(client)) {
			case TFClass_Soldier: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_soldier");
			}
			case TFClass_Pyro: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_pyro");
			}
			case TFClass_Heavy: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_hwg");
			}
			case TFClass_Engineer: {
				strcopy(sClass, sizeof(sClass), "tf_weapon_shotgun_primary");
			}
		}
	}
	
	Handle item = TF2Items_CreateItem(PRESERVE_ATTRIBUTES | FORCE_GENERATION);	//Keep reserve attributes otherwise random issues will occur... including crashes.
	TF2Items_SetClassname(item, sClass);
	TF2Items_SetItemIndex(item, index);
	TF2Items_SetQuality(item, view_as<int>(quality));
	TF2Items_SetLevel(item, level);
	
	char sAttrs[32][32];
	int count = ExplodeString(attributes, " ; ", sAttrs, 32, 32);
	
	if (count > 1) {
		TF2Items_SetNumAttributes(item, count / 2);
		
		int i2;
		for (int i = 0; i < count; i += 2) {
			TF2Items_SetAttribute(item, i2, StringToInt(sAttrs[i]), StringToFloat(sAttrs[i + 1]));
			i2++;
		}
	} else {
		TF2Items_SetNumAttributes(item, 0);
	}

	int weapon = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	if (StrEqual(sClass, "tf_weapon_builder", false) || StrEqual(sClass, "tf_weapon_sapper", false)) {
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
	}
	
	if (StrContains(sClass, "tf_weapon_", false) == 0) {
		EquipPlayerWeapon(client, weapon);
	}
	
	return weapon;
}