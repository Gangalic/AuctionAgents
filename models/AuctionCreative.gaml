/***
* Name: Festival
* Author: Catalin
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Festival

global {
	/** Insert the global definitions, variables and actions here */
	
	int nb_guests <- rnd(10) + 10; // between 10 and 20 guests
	int nb_auctioneers <- 3;
	int size_building <- 5; // buildings are going to be of size 5 and guests of 2
	float speed_guest <- 0.5;
	
	/* ---------------- general auction data ---------------- */
	list<string> auction_items <- ["cap", "T-shirt", "bag", "band"]; // available itema to auction
	
	// price ranges acceptable for guests
	int guest_price_min <- 100;
	int guest_price_max <- 1000;
	
	/* --------------- Dutch aution data -------------- */
	// bid change ranges
	int bid_drop_min <- 5;
	int bid_drop_max <- 10;
	// starting price (bigger than any guest can accept)
	int start_price_min <- 1001;
	int start_price_max <- 1100;
	// min acceptable price range for an item
	int min_accept_price_min <- 99;
	int min_accept_price_max <- 300;
	
	
	init {
		// init all the agents
		create guest number: nb_guests {
			// assign a favourite item that a guest would action for
			fav_item <- auction_items[rnd(length(auction_items)-1)];
		}
		create auctioneer number: nb_auctioneers {
			int item_nb <- rnd(length(auction_items)-1);
			location <- {rnd(100), rnd(100)};
			auctioned_item <- auction_items[item_nb];
		}
	}
}

/*
 * Guest species that just go to auctioneers which auction items they like
 * 
 * All the other time he just randomly dances using the wander skills (included with command 'skills:[moving]')
 * 
 * Any species has the following predefined attributes: host, location, name(not always unique), peers(others in same species), shape
 */
species guest skills:[moving, fipa] {
	// used for aspect
	int size <- 2;
	rgb color <- #red;
	
	// target to which it's moving is initially nil
	building target <- nil;
	
	// favorite item (only one) is initially set to nil
	string fav_item <- nil;
	
	// acceptable price to pay for an item
	int guest_accept_price <- rnd(guest_price_min, guest_price_max);
	
	// target Auctioner in which guest participate is initially nil
	auctioneer target_auction <- nil;
	bool won_auction <- false; // keep track if already won an action or not
	
	// we draw the sphere and also save the location
	aspect default {
		draw sphere(size) at: location color: color;
		
		// drawing the won item on the guest
		if (won_auction = true)
		{
			if(fav_item = "bag"){
				draw cube(1.2) at: location + point([2.1, 0.0, 2.0]) color: #green;
			} else if(fav_item = "cap") {
				draw pyramid(1.2) at: location + point([0.0, 0.0, 3.5]) color: #black;
			} else if(fav_item = "T-shirt") {
				draw cylinder(2.01, 1.5) at: location + point([0.0, 0.0, 1.0]) color: #white;
			} else if(fav_item = "band") {
				draw cylinder(2.01, 1.5) at: location color: #purple;
			}
		}
	}
	
	// move to the action place and stop when close enough
	reflex go_to_auction when: target_auction != nil {
		if (location distance_to(target_auction.location) > 14){
			target <- target_auction;
		} else {
			target <- nil;
		}
	}
	
	// randomly dances inside a circle when no target is given
	reflex dance when: target = nil {
		do wander speed: speed_guest bounds: circle(2);
	}
	
	// when there's a target we move there
	reflex move_to_target when: target != nil {
		do goto target:target.location speed: speed_guest;
	}
	
	// handles the message listening from auctioneers
	reflex listen_messages when: !empty(cfps) {
		message request <- cfps at 0;
		// handle a start announcement
		if(request.contents[0] = 'Start' and request.contents[1] = fav_item and target_auction = nil)
		{
			// guests accepts the participation if it's his/her fav_item being auctioned
			target_auction <- request.sender;
			color <- request.contents[2];
			// print about participation
			write name + " will auction at " + request.sender + "'s auction for " + fav_item;
			// add himself/herself to the list of participating guests
			target_auction.participating_guests <+ self;
		} 
		// handle a stop announcement
		else if (request.contents[0] = 'Stop'){
			write name + " acknowledged about auction end";
			// update all the info to participate again in the auction
			target_auction <- nil;
			target <- nil;
			color <- #red;
			guest_accept_price <- rnd(guest_price_min, guest_price_max);
			fav_item <- auction_items[rnd(length(auction_items)-1)];
		}
		// handle auction winning
		else if(request.contents[0] = 'Winner')
		{
			won_auction <- true;
			write "Yay! " + name + ' won the auction for ' + fav_item + "!";
			// update all the info to participate again in the auction
			target_auction <- nil;
			target <- nil;
			color <- #red;
			guest_accept_price <- rnd(guest_price_min, guest_price_max);
			fav_item <- auction_items[rnd(length(auction_items)-1)];
		}
	}
	
	// handles replies to proposes
	reflex reply_messages when: !empty(proposes) {
		message request <- proposes at 0;
		int offer <- int(request.contents[1]);
		if (guest_accept_price >= offer){
			do accept_proposal (message: request, contents: ["Yolo! " + name + " is going to get your stuff!"]);
		} else {
			do reject_proposal (message: request, contents: ["Booo! What's up with this price?!"]);
		}
	}
}

species building {
	int size <- size_building;
	string store_type;
}

species auctioneer skills:[moving, fipa] parent: building {
	rgb color <- #gray;
	int auctioneer_size <- size;
	
	// price setting
	int auction_start_price <- rnd(start_price_min, start_price_max);
	int auction_min_price <- rnd(min_accept_price_min, min_accept_price_max);
	
	// start and end handling
	bool auction_on <- false;
	bool start_announced <- false;
	
	// auction info
//	string auction_type <- "Dutch";
//	int actual_bid <- 0;
//	string actual_winner <- nil;
//	message message_winner <- nil;
	string auctioned_item <- "";
	list<guest> participating_guests;
	
	aspect {
		draw pyramid(auctioneer_size) color: color;
	}
	
	// method to change lights and attract customers
	reflex change_lights when: flip(0.2) {
		color <- rnd_color(255);
	}
	
	// randomly change size and attract customers
	reflex change_size {
		if (flip(0.7) and auctioneer_size<=5) {
			auctioneer_size <- auctioneer_size + 2;
		} else if (auctioneer_size>10) {
			auctioneer_size <- auctioneer_size - 2;
		}
	}
	
	// method to restart another auction
	reflex restart_auction when: !auction_on and !start_announced and empty(participating_guests) and auctioned_item = ""{
		int item_nb <- rnd(length(auction_items)-1);
		location <- {rnd(100), rnd(100)};
		auctioned_item <- auction_items[item_nb];
		auction_start_price <- rnd(start_price_min, start_price_max);
		auction_min_price <- rnd(min_accept_price_min, min_accept_price_max);
		write "\n\n\n-------------------- Auction restarted! --------------------------";
	}
	
	//	// restart because no one interested
	reflex restart_auction_no_participants when: start_announced and empty(participating_guests) {
		int item_nb <- rnd(length(auction_items)-1);
		start_announced <- false;
		auctioned_item <- auction_items[item_nb];
		auction_start_price <- rnd(start_price_min, start_price_max);
		auction_min_price <- rnd(min_accept_price_min, min_accept_price_max);
		write "\n\n\n" + auctioned_item +"-------------------- (no person) Auction restarted! -------------------------- ";
	}	
	
	// method to announce the imminent start of an action
	reflex announce_start when: !auction_on and !start_announced {
		write name + " announces about starting dutch auction on " + auctioned_item;
		do start_conversation (to: list(guest), protocol: 'fipa-propose', performative: 'cfp', contents: ['Start', auctioned_item, color]);
		start_announced <- true;
	}
	
	// method to start the auction when all the interested guests are close enough
	reflex guests_arrived when: !auction_on and !empty(participating_guests) and (participating_guests max_of (location distance_to(each.location))) < 19 {
		write name + " has all the participant guests arrived";
		auction_on <- true;
	}
	
	// handle the accept messages
	reflex handle_accept_messages when: auction_on and !empty(accept_proposals){
		write name + ' received some accept messages';
		// looping through all accept messages 
		loop one_accept over: accept_proposals {
			write "\n" + name + ' got accepted by ' + one_accept.sender + ': ' + one_accept.contents + "\n";
			do start_conversation (to: one_accept.sender, protocol: 'fipa-propose', performative: 'cfp', contents: ['Winner']);
		}
		auction_on <- false;
		start_announced <- false;
		// end of auction
		do start_conversation (to: participating_guests, protocol: 'fipa-propose', performative: 'cfp', contents: ['Stop']);
		participating_guests <- [];
		auctioned_item <- "";
	}
	
	// handle the reject messages
	reflex handle_reject_messages when: auction_on and !empty(reject_proposals){
		write name + ' received some reject messages';
		// reduce the price
		auction_start_price <- auction_start_price - rnd(bid_drop_min, bid_drop_max);
		// if we're below the possible min price
		if(auction_start_price < auction_min_price)
		{
			auction_on <- false;
			start_announced <- false;
			write "\n" +name + ' price went below minimum value (' + auction_min_price + '). Auction is closed!\n';
			// end of auction
			do start_conversation (to: participating_guests, protocol: 'fipa-propose', performative: 'cfp', contents: ['Stop']);
			participating_guests <- [];
			auctioned_item <- "";
		}
	}
	
	// handles info sending to participating guests
	reflex send_info_to_guests when: auction_on and !empty(participating_guests) {
		write name + ' is sending offer of ' + auction_start_price +' SEK to interested guests';
		do start_conversation (to: participating_guests, protocol: 'fipa-propose', performative: 'propose', contents: ['A new offer for you', auction_start_price]);
	}
}

experiment Auction type: gui {
	/** Insert here the definition of the input and output of the model */
	// input
	parameter "Initial number of guests: " var: nb_guests min: 5 max: 20 category: "Guest";
	
	// output
	output {
		// opengl adds the 3d part
		display main_display type:opengl{
			species guest;
			species auctioneer;
		}
	}
}
