/***
* Name: Festival
* Author: Catalin
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Festival

global {
	/** Insert the global definitions, variables and actions here */
	
	int nb_guests <- rnd(5)+10; // between 10 and 15 guests
	int nb_food_courts <- rnd(2,4);
	int nb_bars <- rnd(2,4);
	int nb_info_point <- 1;
	point loc_info_point <- {50,50}; // info center located in the middle of the map
	int size_building <- 5; // buildings are going to be of size 5 and guests of 2
	int rate_change <- 5; // the rate with which hunger/thirst decreases
	float speed_guest <- 0.5;
	
	init {
		// init all the agents
		create guest number: nb_guests;
		create food_court number: nb_food_courts{
			// this can only be defined here not inside the species part
			store_type <- "food";
		}
		create bar number: nb_bars{
			// this can only be defined here not inside the species part
			store_type <- "drink";
		}
		create info_point number: nb_info_point {
			// this can only be defined here not inside the species part
			location <- loc_info_point;
		}
	}
}

/*
 * Guest species that gets hungry/thirsty and the lvl of food/drink drops to 0
 * 
 * All the other time he just randomly dances using the wander skills (included with command 'skills:[moving]')
 * 
 * Any species has the following predefined attributes: host, location, name(not always unique), peers(others in same species), shape
 */
species guest skills:[moving] {
	// intially each has a lvl of drink or food between 300 and 1000
	int drink <- rnd(700) + 300;
	int food <- rnd(700) + 300;
	
	// used for aspect
	int size <- 2;
	rgb color <- #red;
	
	// target to which it's moving is initially nil
	building target <- nil;
	
	// we draw the sphere and also save the location
	aspect default {
		draw sphere(size) at: location color: color;
	}
	
	// randomly dances inside a circle when no target is given
	reflex dance when: target = nil {
		do wander speed: speed_guest bounds: circle(2);
	}
	
	// when there's a target we move there
	reflex move_to_target when: target != nil {
		do goto target:target.location speed: speed_guest;
	}
	
	// decrease the levels of food and drink and then head to a info point for details
	// we'll decrease only when the target is nil
	reflex get_thirsty_hungry when: target = nil {
		// we decrease randomly the lvl of food and drink
		food <- food - rnd(rate_change);
		drink <- drink - rnd(rate_change);
		
		// now we check what'up with the agent and let him go to info_point
		if food < 0 or drink < 0 {
			string moving_data <- name;
			
			// we print multiple things but we still prioritize food at info_point
			if food < 0 and drink < 0 {
				moving_data <- moving_data + " is hungry and thirsty. ";
			} else if food < 0 {
				moving_data <- moving_data + " is hungry. ";
			} else if drink < 0 {
				moving_data <- moving_data + " is thirsty. ";
			}
			
			// set as target the info_point
			target <- one_of(info_point);
			color <- #yellow; // update the color to see where guest is going
			
			// anounce about moving to info_point
			moving_data <- moving_data + "Going to " + target.name;
			write moving_data + "\n";
		}
	}
	
	
	// when we are at info point and we want to get the info about bars and food courts
	reflex at_info_point when: target != nil and target.location = loc_info_point and location distance_to(target.location) < size_building/2 {
		
		string moving_data <- name + " got to info_point. Next destination: ";
		
		// talk to info_point species found at size_building distance
		ask info_point at_distance size_building {
			// we prioratize the one with lower index, as we're sure that at least one is lower than 0
			if (myself.food <= myself.drink){
				// get randomly a food_court data
				myself.target <- list_food_courts[rnd(length(list_food_courts)-1)];
				myself.color <- #green; // update the color to see where guest is going
				moving_data <- moving_data + "food court " + myself.target.name;
			} else {
				// get randomly a bar data
				myself.target <- list_bars[rnd(length(list_bars)-1)];
				myself.color <- #blue; // update the color to see where guest is going
				moving_data <- moving_data + "food court " + myself.target.name;
			}
			
			// print the data about where we're going
			write moving_data + "\n";
		}
	}
	
	// when we are inside a bar or food_court
	reflex at_store when: target != nil and location distance_to(target.location) < size_building/2 {
		ask target {
			string refill_data <- name + " bought ";
			
			// we refill with food or drink between 700 and 1000
			if store_type = "food" {
				myself.food <- rnd(300) + 700;
				refill_data <- refill_data + "food at " + name;
			} else if store_type = "drink" {
				myself.drink <- rnd(300) + 700;
				refill_data <- refill_data + "drinks at " + name;
			}
			
			// print the data about refill
			write refill_data + "\n";
		}
		
		// once refilled target goes back to nill
		target <- nil;
		location <- {rnd(100),rnd(100)}; // randomly re-assigns a new location in the map
		color <- #red; // update the color back to normal one
	}
}

species building {
	int size <- size_building;
	string store_type;
}

species food_court parent: building {
	rgb color <- #green;
	
	aspect default {
		draw cube(size) color: color;
	}
}

species bar parent: building {
	rgb color <- #blue;
	
	aspect default {
		draw cube(size) color: color;
	}
}

species info_point parent: building {
	
	// list of food courts and bars known by the info point from neighbourhood of 100 (as map is 100x100)
	// we may print them later on if we want for debugging or fun
	list<food_court> list_food_courts <- (food_court at_distance 100);
	list<building> list_bars <- (bar at_distance 100);
	
	rgb color <- #yellow;
	
	aspect default {
		draw pyramid(size) at: location color: color;
	}
}

experiment Festival type: gui {
	/** Insert here the definition of the input and output of the model */
	// input
	parameter "Initial number of guests: " var: nb_guests min: 5 max: 20 category: "Guest";
	
	// output
	output {
		// opengl adds the 3d part
		display main_display type:opengl{
			species guest;
			species food_court;
			species bar;
			species info_point;
		}
	}
}
