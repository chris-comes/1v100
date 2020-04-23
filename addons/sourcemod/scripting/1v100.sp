// SourceMod Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

// Extra Includes
#include <multicolors>

// Compilation Requirements
#pragma newdecls required
#pragma semicolon 1

// Global Plugin Tag
#define TAG "{orange}1v100 {grey}|{default}"

// Global Booleans
bool g_bRandomSelected;

// Global Integers
int g_iJuggernautKills;

public Plugin myinfo = 
{
	name = "1 vs 100",
	author = "crc1225",
	description = "One Player Faces Off Against Everyone Else",
	version = "1.0.0",
	url = "https://github.com/crc1225"
};

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{	
	g_bRandomSelected = false;
	g_iJuggernautKills = 0;
	
	CheckCvars();
	
	if (GetTeamClientCount(CS_TEAM_CT) == 0)
	{
		CPrintToChatAll("%s No {darkblue}Juggernaut {default}has been found, random being selected", TAG);
		
		int client = SelectJuggernaut();
		g_bRandomSelected = true;
		ChangeClientTeam(client, CS_TEAM_CT);
		CPrintToChatAll("%s {darkblue}%N {default}has been selected as next rounds {darkblue}Juggernaut!", TAG, client);
	}
	
	if (GetTeamClientCount(CS_TEAM_CT) >= 2)
	{
		CPrintToChatAll("%s Multiple {darkblue}Juggernauts {default}detected, swapping and selecting a random one", TAG);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientValid(i))
				continue;
			
			if (GetClientTeam(i) == CS_TEAM_CT)
				ChangeClientTeam(i, CS_TEAM_T);
		}
		
		int client = SelectJuggernaut();
		g_bRandomSelected = true;
		if (client != -1)
		{
			ChangeClientTeam(client, CS_TEAM_CT);
			CPrintToChatAll("%s {darkblue}%N {default}has been selected as next rounds {darkblue}Juggernaut!", TAG, client);
		}
		else
			CPrintToChatAll("%s {darkred}[ERROR] Error Fixing teams: client = 1", TAG);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientValid(i))
			continue;
		
		if (g_bRandomSelected)
			continue;
			
		SetEntProp(i, Prop_Send, "m_ArmorValue", 0);
		SetEntProp(i, Prop_Send, "m_bHasHelmet", 0);
			
		StripWeapons(i);
		GivePlayerItem(i, "weapon_knife");
		GivePlayerItem(i, "item_kevlar");
		CreateTimer(1.0, Timer_GunMenu, i);
		
		if (GetClientTeam(i) == CS_TEAM_CT)
		{
			int iTeamSize = GetTeamClientCount(CS_TEAM_T);
			int health = 150 + ((iTeamSize) * 150);
			SetEntityHealth(i, health);
			GivePlayerItem(i, "weapon_incgrenade");
			SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.75); 

			CPrintToChatAll("%s There are {yellow}%i Terrorists, {default}Juggernaut's health has been set to {darkblue}%i", TAG, iTeamSize, health);
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")); // Get person who died
	int attacker = GetClientOfUserId(event.GetInt("attacker")); // Get the killer
	
	if (GetClientTeam(client) == CS_TEAM_CT && !g_bRandomSelected) // If Juggernaut was killed in active round
	{
		CPrintToChatAll("%s The Juggernaut was {darkred}KILLED by %N, {default}they are the new {darkblue}Juggernaut!", TAG, attacker);
		
		ChangeClientTeam(client, CS_TEAM_T); // Move Juggernaut to T
		ForcePlayerSuicide(attacker); // Slay the killer (just makes things easier)
		ChangeClientTeam(attacker, CS_TEAM_CT);	// Move the killer to ct
	}
	
	else if (GetClientTeam(client) == CS_TEAM_T && GetClientTeam(attacker) == CS_TEAM_CT)
	{
		g_iJuggernautKills++; // Count how many kills the Juggernaut has gotten
		if (g_iJuggernautKills == 5 || g_iJuggernautKills == 10 || g_iJuggernautKills == 15 || g_iJuggernautKills == 20 || g_iJuggernautKills == 25)
		{
			CPrintToChatAll("%s The {darkblue}Juggernaut has {darkred}SLAIN %i {default}opponent(s)", TAG, g_iJuggernautKills);		
		}
	}
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	char sWeapon[64]; // Gather Data
	GetEventString(event, "item", sWeapon, sizeof(sWeapon));
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsClientValid(client))
		return Plugin_Handled;

	if (StrEqual(sWeapon, "c4", false)) // Remove Bomb
	{
		int iBombIndex = GetPlayerWeaponSlot(client, CS_SLOT_C4);
		RemovePlayerItem(client, iBombIndex);
	}
	
	if (GetClientTeam(client) == CS_TEAM_CT && !IsValidWeapon(sWeapon))
	{	
		// Remove any Pistols
		int iSecWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		RemovePlayerItem(client, iSecWeapon);
		CPrintToChat(client, "%s You are not allowed to pick up pistols!", TAG);
	}
	return Plugin_Continue;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true); // Disable "Bob Joined Terrorist Team"
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
	char sTeam[32]; // Gather Info
	GetCmdArg(1, sTeam, sizeof(sTeam));
	int team = StringToInt(sTeam);
	
	if (team == CS_TEAM_CT)
	{
		CPrintToChat(client, "%s You can not join the CT team to become a juggernaut, wait your turn", TAG);
		ChangeClientTeam(client, CS_TEAM_T);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_GunMenu(Handle timer, any client)
{
	if (GetClientTeam(client) == CS_TEAM_T) // If T Open Pistol Menu
	{
		OpenTMenu(client);
	}
	else if (GetClientTeam(client) == CS_TEAM_CT) // If CT open Heavy weapons Menu
	{
		OpenCTMenu(client);
	}
}

void OpenTMenu(int client) // T Weapons
{
	Menu menu = new Menu(Menu_Guns, MENU_ACTIONS_ALL);
	menu.SetTitle("Pick Your Pistol");
	menu.AddItem("weapon_glock", "Glock");
	menu.AddItem("weapon_elite", "Dual Berretas");
	menu.AddItem("weapon_p250", "P250");
	menu.AddItem("weapon_tec9", "Tec9");
	menu.AddItem("weapon_cz75a", "Cz75");
	menu.AddItem("weapon_deagle", "Deagle");
	menu.AddItem("weapon_revolver", "Revolver");
	menu.AddItem("weapon_usp_silencer", "Usp-s");
	menu.AddItem("weapon_hkp2000", "P2000");
	menu.AddItem("weapon_fiveseven", "Five-Seven");
	menu.Display(client, MENU_TIME_FOREVER);
}

void OpenCTMenu(int client) // Juggernaut Weapons
{
	Menu menu = new Menu(Menu_Guns, MENU_ACTIONS_ALL);
	menu.SetTitle("Pick Your Gun!");
	menu.AddItem("weapon_mp7", "Mp7");
	menu.AddItem("weapon_mp9", "Mp9");
	menu.AddItem("weapon_mp5sd", "Mp5-sd");
	menu.AddItem("weapon_ump45", "Ump45");
	menu.AddItem("weapon_p90", "P90");
	menu.AddItem("weapon_bizon", "PP-Bizon");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Guns(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		GivePlayerItem(param1, info); // Give Player Gun
	}
}

public Action TextMsg(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!reliable)
		return Plugin_Continue;

	char buffer[128];
	PbReadString(msg, "params", buffer, sizeof(buffer), 0);

	if (StrContains(buffer, "Game_teammate_attack") != -1) // Disable the "attacked teammate" message
		return Plugin_Handled;

	return Plugin_Continue;
}

void CheckCvars()
{
	ServerCommand("bot_quota 0");
	ServerCommand("bot_kick");
	ServerCommand("mp_autokick 0");
	ServerCommand("mp_buytime 0");
	ServerCommand("mp_buy_allow_guns 0");
	ServerCommand("mp_buy_allow_grenades 0");
	ServerCommand("mp_ct_default_secondary '' ");
	ServerCommand("mp_maxrounds 0");
	ServerCommand("mp_playercashawards 0");
	ServerCommand("mp_roundtime 7.5");
	ServerCommand("mp_roundtime_defuse 7.5");
	ServerCommand("mp_roundtime_hostage 7.5");
	ServerCommand("mp_timelimit 30");
	ServerCommand("mp_warmup_end");
	ServerCommand("mp_weapons_allow_zeus 0");
}

int SelectJuggernaut()
{
	for (int i; i <= 10; i++) // Attempt to find a valid Juggernaut 10 times
	{
		int client = GetRandomPlayer(CS_TEAM_T);
		
		if (IsClientValid(client))
			return client;

		if (i == 10)
		{
			CPrintToChatAll("%s {darkred}[ERROR] Could not find a valid Juggernaut in 10 attempts", TAG);
			return -1;
		}
	}
	return -1;
}

public int GetRandomPlayer(int team)
{
	int teamcount = GetTeamClientCount(team);
	int client = GetRandomInt(1, teamcount);

	return client;
}

public bool IsClientValid(int client)
{
	if (client < 1)
		return false;
	if (client > MaxClients)
		return false;
	if (!IsClientConnected(client))
		return false;
	if (IsFakeClient(client)) 
		return false;
	if (!IsClientInGame(client))
		return false;
	
	return true;
}

void StripWeapons(int client)
{
	int iWeaponId;
	for (int i; i <= 20; i++)
	{
		if ((iWeaponId = GetPlayerWeaponSlot(client, i)) != -1)
		{	
			RemovePlayerItem(client, iWeaponId);
			AcceptEntityInput(iWeaponId, "Kill");
		}	
	}
}

bool IsValidWeapon(const char[] sWeapon)
{
	// Pistol Return 0
	if (StrEqual(sWeapon, "glock", false))
		return false;
	if (StrEqual(sWeapon, "elite", false))
		return false;
	if (StrEqual(sWeapon, "p250", false))
		return false;
	if (StrEqual(sWeapon, "tec9", false))
		return false;
	if (StrEqual(sWeapon, "cz75a", false))
		return false;
	if (StrEqual(sWeapon, "deagle", false))
		return false;
	if (StrEqual(sWeapon, "revolver", false))
		return false;
	if (StrEqual(sWeapon, "usp_silenver", false))
		return false;
	if (StrEqual(sWeapon, "hkp2000", false))
		return false;
	if (StrEqual(sWeapon, "fiveseven", false))
		return false;

	// If the Juggernaut can pick it up
	return true;
}