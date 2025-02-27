#include maps\_utility; 
#include common_scripts\utility;
#include maps\_zombiemode_utility;
#include maps\_music; 

init()
{
	level.enemy_dog_spawns = [];
	flag_init( "dog_round" );
	flag_clear( "dog_round" );
	PreCacheRumble( "explosion_generic" );

	// this gets rounded down to 40 damage after the dvar 'player_meleeDamageMultiplier' runs its calculation
	SetSavedDvar( "dog_MeleeDamage", "100" );

	if ( !IsDefined( level.dogs_enabled ) )
	{
		return;
	}

	if ( !level.dogs_enabled )
	{
		return;
	}

	if ( GetDvar( "zombie_dog_animset" ) == "" )
	{
		SetDvar( "zombie_dog_animset", "zombie" );
	}
	
	set_zombie_var( "dog_fire_trail_percent", 50 );

	level._effect[ "lightning_dog_spawn" ]			= Loadfx( "maps/zombie/fx_zombie_dog_lightning_buildup" );


	level._effect[ "dog_eye_glow" ]		= Loadfx( "maps/zombie/fx_zombie_dog_eyes" );
	level._effect[ "dog_gib" ]			= Loadfx( "maps/zombie/fx_zombie_dog_explosion" );
	level._effect[ "dog_trail_fire" ]	= Loadfx( "maps/zombie/fx_zombie_dog_fire_trail" );
	level._effect[ "dog_trail_ash" ]	= Loadfx( "maps/zombie/fx_zombie_dog_ash_trail" );

	animscripts\dog_init::initDogAnimations();
	dog_spawner_init();
	
	level thread dog_round_tracker();

}


dog_spawner_init()
{
	dogs = getEntArray( "zombie_dog_spawner", "script_noteworthy" ); 
	later_dogs = getentarray("later_round_dog_spawners", "script_noteworthy" );
	dogs = array_combine( dogs, later_dogs );

	for( i = 0; i < dogs.size; i++ )
	{
		if( maps\_zombiemode_spawner::is_spawner_targeted_by_blocker( dogs[i] ) )
		{
			dogs[i].locked_spawner = true;
		}
	}

	assert( dogs.size > 0 );
	level.dog_health = 100;

	array_thread( dogs, ::add_spawn_function, ::dog_init );

	level.enemy_dog_spawns = getEntArray( "zombie_spawner_dog_init", "targetname" ); 
}


dog_round_spawning()
{
	level endon( "intermission" );
	
	level.dog_targets = getplayers();
	for( i = 0 ; i < level.dog_targets.size; i++ )
	{
		level.dog_targets[i].hunted_by = 0;
	}


	assert( level.enemy_dog_spawns.size > 0 );

/#
	level endon( "kill_round" );

	if ( GetDVarInt( "zombie_cheat" ) == 2 || GetDVarInt( "zombie_cheat" ) >= 4 ) 
	{
		return;
	}
#/

	if( level.intermission )
	{
		return;
	}

	level.dog_intermission = true;
	level thread dog_round_aftermath();
	players = get_players();
	array_thread( players, ::play_dog_round );	
	wait(7);



	if( level.dog_round_count < 3 )
	{
		max = players.size * 6;
	}
	else
	{
		max = players.size * 8;
	}
	



/#
	if( GetDVar( "force_dogs" ) != "" )
	{
		max = GetDvarInt( "force_dogs" );
	}
#/		

	level.zombie_total = max;
	dog_health_increase();



	count = 0; 
	while( count < max )
	{

	/*	iPrintLnBold(count + "-" + max);*/
	
		num_player_valid = get_number_of_valid_players();
	
		while( get_enemy_count() >= num_player_valid * 2 )
		{
			wait( 2 );
			num_player_valid = get_number_of_valid_players();
		}
		
		//update the player array.
		players = get_players();
		favorite_enemy = get_favorite_enemy();
		spawn_point = dog_spawn_sumpf_logic( level.enemy_dog_spawns, favorite_enemy); 

		ai = spawn_zombie( spawn_point );

		if( IsDefined( ai ) ) 	
		{
			ai.favoriteenemy = favorite_enemy;
			spawn_point thread dog_spawn_fx( ai );
			level.zombie_total--;
			count++;
			
		}
		
		waiting_for_next_dog_spawn( count, max );
	}




	

}
waiting_for_next_dog_spawn( count, max )
{
	default_wait = 1.5;

	if( level.dog_round_count == 1)
	{
		default_wait = 3;
	}
	else if( level.dog_round_count == 2)
	{
		default_wait = 2.5;
	}
	else if( level.dog_round_count == 3)
	{
		default_wait = 2;
	}
	else 
	{
		default_wait = 1.5;
	}

	default_wait = default_wait - ( count / max );

	wait( default_wait );

}


get_number_of_valid_players()
{

	players = get_players();
	num_player_valid = 0;
	for( i = 0 ; i < players.size; i++ )
	{
		if( is_player_valid( players[i] ) )
			num_player_valid += 1;
	}

	
	return num_player_valid;



}

dog_round_aftermath()
{

	level waittill( "last_dog_down" );

	power_up_origin = level.last_dog_origin;
	perk_bottle_drop_org = level.last_dog_origin;

	if( IsDefined( power_up_origin ) )
	{
		valid_drop = false;
		
		while(!valid_drop)
		{
			perk_bottle_drop_org = perk_bottle_drop_org - (15, 15, 0);
			
			playable_area = getentarray("playable_area","targetname");
			
			for (i = 0; i < playable_area.size; i++)
			{
				if (perk_bottle_drop_org istouching(playable_area[i]))
				{
					valid_drop = true;
				}
			}
			
			wait(0.01);
		}
			
		for ( i = 0; i < level.zombie_powerup_array.size; i++ )
		{
			if ( level.zombie_powerup_array[i] == "full_ammo" )
			{
				level.zombie_powerup_index = i;
				break;
			}
		}
		play_sound_2D( "bright_sting" );
		level.zombie_vars["zombie_drop_item"] = 1;
		level.powerup_drop_count = 0;
		level thread maps\_zombiemode_powerups::powerup_drop( power_up_origin );

	}
	
	if( IsDefined( perk_bottle_drop_org ) )
	{
		//level thread randomize_dog_powerup_drop(power_up_origin);
		for ( i = 0; i < level.zombie_powerup_array.size; i++ )
		{
			if ( level.zombie_powerup_array[i] == "perk" )
			{
				level.zombie_powerup_index = i;
				break;
			}
		}
		play_sound_2D( "bright_sting" );
		level.zombie_vars["zombie_drop_item"] = 1;
		level.powerup_drop_count = 0;
		level thread maps\_zombiemode_powerups::powerup_drop( perk_bottle_drop_org );

	}
	
	wait(2);
	clientnotify( "dog_stop" );
	wait(6);
	level.dog_intermission = false;

	//level thread dog_round_aftermath();

}


dog_spawn_fx( ai )
{
	ent = GetStruct( self.target, "targetname" );


	if ( isdefined( ent ) )
	{
		Playfx( level._effect["lightning_dog_spawn"], ent.origin );
		playsoundatposition( "pre_spawn", ent.origin );
		wait( 1.5 );
		playsoundatposition( "bolt", ent.origin );

		Earthquake( 0.5, 0.75, ent.origin, 1000);
		PlayRumbleOnPosition("explosion_generic", ent.origin);
		playsoundatposition( "spawn", ent.origin );
	}

	assertex( IsDefined( ai ), "Ent isn't defined." );
	assertex( IsAlive( ai ), "Ent is dead." );
	assertex( ai enemy_is_dog(), "Ent isn't a dog;" );
	assertex( is_magic_bullet_shield_enabled( ai ), "Ent doesn't have a magic bullet shield." );

	// face the enemy
	angle = VectorToAngles( ai.favoriteenemy.origin - ai.origin );
	angles = ( ai.angles[0], angle[1], ai.angles[2] );
	ai Teleport( ai.origin, angles );

	ai zombie_setup_attack_properties_dog();
	ai stop_magic_bullet_shield();

	// start glowing eyes
	assert( IsDefined( ai.fx_dog_eye ) );
	PlayFxOnTag( level._effect["dog_eye_glow"], ai.fx_dog_eye, "tag_origin" );

	// start trail
	assert( IsDefined( ai.fx_dog_trail ) );
	PlayFxOnTag( ai.fx_dog_trail_type, ai.fx_dog_trail, "tag_origin" );
	ai playloopsound( ai.fx_dog_trail_sound );

	wait( 0.1 ); // dog should come out running after this wait
	ai show();
}


dog_spawn_sumpf_logic( dog_array, favorite_enemy)
{

	assertex( dog_array.size > 0, "Dog Spawner array is empty." );
	dog_array = array_randomize( dog_array );
	for( i = 0; i < dog_array.size; i++ )
	{
		if( IsDefined( level.old_dog_spawn ) && level.old_dog_spawn == dog_array[i] )
		{
			continue;
		}

		if( DistanceSquared( dog_array[i].origin, favorite_enemy.origin ) > ( 200 * 200 ) && DistanceSquared( dog_array[i].origin, favorite_enemy.origin ) < ( 700 * 700 ) )			
		{

			if(distanceSquared( ( 0, 0, dog_array[i].origin[2] ), ( 0, 0, favorite_enemy.origin[2] ) ) > 100 * 100 )
			{
				continue;
			}
			else
			{
				level.old_dog_spawn = dog_array[i];
				return dog_array[i];
			}

		}	

	}

	return dog_array[0];

}
get_favorite_enemy()
{
	dog_targets = getplayers();
	least_hunted = dog_targets[0];
	for( i = 0; i < dog_targets.size; i++ )
	{

		if( !is_player_valid( dog_targets[i] ) )
		{
			continue;
		}

		if( !is_player_valid( least_hunted ) )
		{
			least_hunted = dog_targets[i];
		}
			
		if( dog_targets[i].hunted_by < least_hunted.hunted_by )
		{
			least_hunted = dog_targets[i];
		}

	}
	
	least_hunted.hunted_by += 1;

	return least_hunted;	


}


dog_health_increase()
{
	players = getplayers();

	if( level.dog_round_count == 1 )
	{
		level.dog_health = 350;
	}
	else if( level.dog_round_count == 2 )
	{
		level.dog_health = 700;
	}
	else if( level.dog_round_count == 3 )
	{
		level.dog_health = 1000;
	}
	else if( level.dog_round_count == 4 )
	{
		level.dog_health = 1250;
	}

	if( level.dog_health > 1250 )
	{
		level.dog_health = 1250;
	}
}


dog_round_tracker()
{	
	level.dog_round_count = 1;
	
	// PI_CHANGE_BEGIN - JMA - making dog rounds random between round 5 thru 7
	// NOTE:  RandomIntRange returns a random integer r, where min <= r < max
	level.next_dog_round = randomintrange( 5, 8 );	
	// PI_CHANGE_END
	
	sav_func = level.round_spawn_func;

	while ( 1 )
	{
		level waittill ( "between_round_over" );

		/#
			if( GetDVarInt( "force_dogs" ) > 0 )
			{
				level.next_dog_round = level.round_number; 
			}
		#/

		if ( level.round_number == level.next_dog_round )
		{
			sav_func = level.round_spawn_func;
			dog_round_start();
			level.round_spawn_func = ::dog_round_spawning;

			level.next_dog_round = level.round_number + randomintrange( 4, 6 );
			/#
				get_players()[0] iprintln( "Next dog round: " + level.next_dog_round );
			#/
		}
		else if ( flag( "dog_round" ) )
		{
			dog_round_stop();
			level.round_spawn_func = sav_func;
			
			level.dog_round_count += 1;
		}			
	}	
}


dog_round_start()
{
	flag_set( "dog_round" );
	play_sound_2D( "dark_sting" );
	if(!IsDefined (level.doground_nomusic))
	{
		level.doground_nomusic = 0;
	}
	level.doground_nomusic = 1;
	level notify( "dog_round_starting" );
	clientnotify( "dog_start" );
}


dog_round_stop()
{
	flag_clear( "dog_round" );
	
	if(!IsDefined (level.doground_nomusic))
	{
		level.doground_nomusic = 0;
	}
	level.doground_nomusic = 0;
	level notify( "dog_round_ending" );
	clientnotify( "dog_stop" );
}


play_dog_round()
{
	self playlocalsound("dog_round_start");
	
	wait(1);

	players = getplayers();
	variation_count =5;
	
	playsoundatposition("ann_vox_dog_left", (8330, 592, -160));
	playsoundatposition("ann_vox_dog_right", (11793, 1632, -160));

	wait(2);

	//index = maps\_zombiemode_weapons::get_player_index(players[0]);
	//player_index = "plr_" + index + "_";
	//num_variants = maps\_zombiemode_spawner::get_number_variants(player_index + "vox_dog_spawn");
	wait (1);
	//Plays a random start line on one of the characters
	
	random = randomintrange(0,players.size);
	level thread add_dog_dialog(players[random]);

	//players[i] maps\_zombiemode_spawner::do_player_playdialog ("plr_" + i + "_vox_dog_spawn" + "_" + randomintrange(0, 4));
	wait (4.5);
	play_sound_2D( "ann_vox_dog_start" );


//	setmusicstate("mx_dog_round");
}
add_dog_dialog(player)
{
	index = maps\_zombiemode_weapons::get_player_index(player);
	player_index = "plr_" + index + "_";
	if(!IsDefined (player.vox_dog_spawn))
	{
		num_variants = maps\_zombiemode_spawner::get_number_variants(player_index + "vox_dog_spawn");
		player.vox_dog_spawn = [];
		for(i=0;i<num_variants;i++)
		{
			player.vox_dog_spawn[player.vox_dog_spawn.size] = "vox_dog_spawn_" + i;	
		}
		player.vox_dog_spawn_available = player.vox_dog_spawn;		
	}	
	sound_to_play = random(player.vox_dog_spawn_available);
	
	player.vox_dog_spawn_available = array_remove(player.vox_dog_spawn_available,sound_to_play);
	
	if (player.vox_dog_spawn_available.size < 1 )
	{
		player.vox_dog_spawn_available = player.vox_dog_spawn;
	}
			
	player maps\_zombiemode_spawner::do_player_playdialog(player_index, sound_to_play, 0.25);
}

dog_init()
{
	self.targetname = "zombie_dog";
	self.script_noteworthy = undefined;
	self.animname = "zombie_dog"; 		
	self.ignoreall = true; 
	self.allowdeath = true; 			// allows death during animscripted calls
	self.allowpain = false;
	self.gib_override = true; 		// needed to make sure this guy does gibs
	self.is_zombie = true; 			// needed for melee.gsc in the animscripts
	self.has_legs = true; 			// Sumeet - This tells the zombie that he is allowed to stand anymore or not, gibbing can take 
	// out both legs and then the only allowed stance should be prone.
	self.gibbed = false; 
	self.head_gibbed = false;
	animscripts\dog_init::change_anim_set( getdvar( "zombie_dog_animset" ) );

	//	self.disableArrivals = true; 
	//	self.disableExits = true; 
	self.grenadeawareness = 0;
	self.badplaceawareness = 0;

	self.ignoreSuppression = true; 	
	self.suppressionThreshold = 1; 
	self.noDodgeMove = true; 
	self.dontShootWhileMoving = true;
	self.pathenemylookahead = 0;

	self.badplaceawareness = 0;
	self.chatInitialized = false;

	self.maxhealth = level.dog_health;
	self.health = level.dog_health;

	self thread maps\_zombiemode::round_spawn_failsafe();
	self hide();
	self thread magic_bullet_shield();
	self dog_fx_eye_glow();
	self dog_fx_trail();

	self thread dog_death();

	self disable_pain(); 

	self.flame_damage_time = 0;

	self maps\_zombiemode_spawner::zombie_history( "zombie_dog_spawn_init -> Spawned = " + self.origin );
}


dog_fx_eye_glow()
{
	self.fx_dog_eye = Spawn( "script_model", self GetTagOrigin( "J_EyeBall_LE" ) );
	assert( IsDefined( self.fx_dog_eye ) );

	self.fx_dog_eye.angles = self GetTagAngles( "J_EyeBall_LE" );
	self.fx_dog_eye SetModel( "tag_origin" );
	self.fx_dog_eye LinkTo( self, "J_EyeBall_LE" );
}


dog_fx_trail()
{
	if( randomint( 100 ) > level.zombie_vars["dog_fire_trail_percent"] )
	{
		self.fx_dog_trail_type = level._effect[ "dog_trail_ash" ];
		self.fx_dog_trail_sound = "dog_trail_fire_breath";
	}
	else
	{
		//fire dogs will explode during death	
		self.a.nodeath = true;

		self.fx_dog_trail_type = level._effect[ "dog_trail_fire" ];
		self.fx_dog_trail_sound = "dog_trail_fire";
	}

	self.fx_dog_trail = Spawn( "script_model", self GetTagOrigin( "tag_origin" ) );
	assert( IsDefined( self.fx_dog_trail ) );

	self.fx_dog_trail.angles = self GetTagAngles( "tag_origin" );
	self.fx_dog_trail SetModel( "tag_origin" );
	self.fx_dog_trail LinkTo( self, "tag_origin" );
}


dog_death()
{
	self waittill( "death" );

	if( get_enemy_count() == 0 && level.zombie_total == 0 )
	{

		level.last_dog_origin = self.origin;
		level notify( "last_dog_down" );

	}

	// score
	if( IsPlayer( self.attacker ) )
	{
		self.attacker maps\_zombiemode_score::player_add_points( "death", self.damagemod, self.damagelocation, true );
	}

	// sound
	self stoploopsound();

	// fx
	assert( IsDefined( self.fx_dog_eye ) );
	self.fx_dog_eye delete();

	assert( IsDefined( self.fx_dog_trail ) );
	self.fx_dog_trail delete();

	if ( IsDefined( self.a.nodeath ) )
	{
		level thread dog_explode_fx( self.origin );
		self delete();
	}
}


dog_explode_fx( origin )
{
	fx = maps\_zombiemode_net::network_safe_spawn( "script_model", origin );
	assert( IsDefined( fx ) );

	fx SetModel( "tag_origin" );
	PlayFxOnTag( level._effect["dog_gib"], fx, "tag_origin" );
	fx playsound( "zombie_dog_death" );

	wait( 5 );
	fx delete();
}


// this is where zombies go into attack mode, and need different attributes set up
zombie_setup_attack_properties_dog()
{
	self maps\_zombiemode_spawner::zombie_history( "zombie_setup_attack_properties()" );
	
	self thread dog_behind_audio();

	// allows zombie to attack again
	self.ignoreall = false; 

	self.pathEnemyFightDist = 64;
	self.meleeAttackDist = 64;

	// turn off transition anims
	self.disableArrivals = true; 
	self.disableExits = true; 

}


//COLLIN'S Audio Scripts
stop_dog_sound_on_death()
{
	self waittill("death");
	self stopsounds();
}

dog_behind_audio()
{
	self thread stop_dog_sound_on_death();

	self endon("death");

	while(1)
	{
		wait(.25);
		players = get_players();
		for(i=0;i<players.size;i++)
		{
			dogAngle = AngleClamp180( vectorToAngles( self.origin - players[i].origin )[1] - players[i].angles[1] );
		
			if(isAlive(players[i]) && !isDefined(players[i].revivetrigger))
			{
				if ((abs(dogAngle) > 90) && distance2d(self.origin,players[i].origin) > 100)
				{
					self playsound( "zdog_close" );
				}
			}
		}
	}
}
