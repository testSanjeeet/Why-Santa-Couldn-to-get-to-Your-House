
// CHARACTER COORDINATES
`define CHARACTER_X 65  //temp
`define CHARACTER_Y 87  //temp
`define JUMP1_HEIGHT 45 //temp
`define JUMP2_HEIGHT 25 //temp

// OBSTACLE 1 = 16 x 16 
// OBSTACLE 2 = 20 x 20 
// OBSTACLE 3 = 24 x 24 
// OBSTACLE 4 = 28 x 28 
`define OBSTACLE1_START_X 144  // 160 - # OF X PIXELS OF THE OBSTACLES
`define OBSTACLE2_START_X 140
`define OBSTACLE3_START_X 136
`define OBSTACLE4_START_X 132
`define OBSTACLE1_START_Y 81  
`define OBSTACLE2_START_Y 77	
`define OBSTACLE3_START_Y 73
`define OBSTACLE4_START_Y 69

// SCORE COORDINATES
`define SCORE_START_X 80
`define SCORE_START_Y 1

// NUMBER OF THINGS TO DRAW ON MONITOR (SCORE, OBSTACLE, CHARACTER)
`define NUMBER_OF_ON_SCREEN_THINGS 3  

// TOP MODULE
module FINAL (CLOCK_50, KEY, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N,VGA_CLK, LEDR);
	input CLOCK_50;
	input [3:0] KEY;

	output [9:0] VGA_R;
	output [9:0] VGA_G;
	output [9:0] VGA_B;
	output VGA_HS;
	output VGA_VS;
	output VGA_BLANK_N;
	output VGA_SYNC_N;
	output VGA_CLK;
	output [9:0] LEDR;

	assign LEDR [0] = obs4;
	assign LEDR [1] = obs3;
	assign LEDR [2] = obs2;
	assign LEDR [3] = obs1;
	assign LEDR [9] = ranNum_en;
	assign LEDR [7] = out[1];
	assign LEDR [6] = out[0];
 
	
	wire [2:0] Colour;
	
	
	
	wire Reset, Start, Jump1, Jump2, plot;
	assign Reset = ~KEY[0];
	assign Start = ~KEY[1];
	assign Jump1 = ~KEY[2];
	assign Jump2 = ~KEY[3];
	
	
	
	
	

	
	reg [7:0] x1, x2, x3, x4, x_character, x_in; // x horizontal animation movement for the obstacles
	reg [6:0] y1, y2, y3, y4, y_character, y_in;
	
	
	
	wire [7:0] x_out;
	wire [6:0] y_out;

	
	reg [8:0] currentState, nextState;

	// VGA
	vga_adapter VGA(
			.resetn(~Reset),
			.clock(CLOCK_50),
			.colour(Colour),
			.x(x_out),
			.y(y_out),
			.plot(plot),
			//Signals for the DAC to drive the monitor. 
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK_N(VGA_BLANK_N),
			.VGA_SYNC_N(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "new_modified_main_menu.mif";
	

	// FSM
	
	// FSM STATES
	parameter MAIN = 9'b000000001, SET = 9'b000000010, DRAW = 9'b000000100, HOLD = 9'b000001000, ERASE = 9'b000010000, 
			CHECK_COLLISION = 9'b000100000, CHANGE_COORDINATE = 9'b001000000, GAME_OVER = 9'b010000000, GAME_WIN = 9'b100000000;

	
	wire [2:0] FinishedDraw;     //temporary until we make the fsm module that draws everything 
	wire Set_en; //
	reg jump_en, jump1_en, jump2_en, y_up, y_down; // Jump related signals
	reg obstacle1_move, obstacle2_move, obstacle3_move, obstacle4_move; // signals for animation of the obstacles
	reg Draw_en;  // One complete signal of module that draws everything
	reg ranNum_en; // to enable the LFSR when needed 
	reg Gameover; // game over signal
	reg Win; // game win signal 
	reg obs1; // signal to draw obstacle1
	reg obs2;
	reg obs3;
	reg obs4;
	
	reg [6:0] upSpeed1, upSpeed2; // signals used for physical model of the Jump 1 and 2
	reg [6:0] downSpeed1, downSpeed2; 
	
	reg [4:0] score; // keeping track of the score
 
	reg BackToMain;
 
	reg DrawFSM_en;  // enables the DrawFSM module (draws everything)
	reg Erase; // enables the erase part of the DrawFSM
	

	// FSM STATE TABLE
	always @(*)
	begin
		case (currentState)
			MAIN: begin
				if (Start)
					nextState = SET;
				else 
					nextState = MAIN;
			end

			SET: begin
				if (Draw_en)
					nextState = DRAW;
				else if (Gameover)
					nextState = GAME_OVER;
				else if (Win)
					nextState = GAME_WIN;
				else 
					nextState = ERASE;
			end

			DRAW: 
			begin
				if (FinishedDraw == `NUMBER_OF_ON_SCREEN_THINGS) // if drew everything 
					nextState = HOLD;
				
				else if (Set_en) 
					nextState = SET;
				
				else 
					nextState = DRAW;
			end

			HOLD: 
			begin 
				if (count == 2000000) // if held for this amount
					nextState = SET;
				else
					nextState = HOLD; 
			end

			ERASE: begin
				if (Set_en)
					nextState = CHECK_COLLISION;
				else
					nextState = ERASE;
			end	

			CHECK_COLLISION: nextState = CHANGE_COORDINATE;
			
			CHANGE_COORDINATE: nextState = SET;

			GAME_OVER: begin
				if (Start)
					nextState = MAIN;
				else
					nextState = GAME_OVER;
			end
			
			GAME_WIN: begin 
				if (Start)
					nextState = MAIN;
				else
					nextState = GAME_WIN;
			end
			
		endcase	
	end
	// END OF THE STATE TABLE

	// STATE FF
	always @ (posedge CLOCK_50)
	begin: state_FFs
		if (Reset)
			currentState = MAIN;
		else
			currentState = nextState;
	end
	

	// OUTPUT LOGIC
	always @(posedge CLOCK_50)
	begin
		case(currentState)
			MAIN: begin // initialize
				x_character = `CHARACTER_X;
				y_character = `CHARACTER_Y;
				x1 = 0;
				y1 = 0;
				x2 = 0;
				y2 = 0;
				x3 = 0;
				y3 = 0;
				x4 = 0;
				y4 = 0;
				y_up = 0;
				y_down = 0;
				ranNum_en = 1;
				DrawFSM_en <= 0;
				Draw_en = 0;
				Gameover = 0;
				obstacle1_move = 0;
				obstacle2_move = 0;
				obstacle3_move = 0;
				obstacle4_move = 0;
				score = 0;
				Win = 0;
			end

			SET: begin 
				// explicit signals for this state 
			end

			DRAW: begin
				DrawFSM_en <= 1;  
				Erase <= 0;
			end
			HOLD: begin
				Draw_en = 0;
				Erase <= 1;	
				DrawFSM_en <= 0;
			end
			
			ERASE: begin
				Erase <= 1;
				DrawFSM_en <= 1;
			end
			
			CHECK_COLLISION: begin     
				DrawFSM_en = 0;
			
			
				// CHECKING FOR COLLISIONS BETWEEN THE CHARACTER AND OBSTACLE
				if (obs1) begin
					if ((`CHARACTER_X + 10) > x1 && `CHARACTER_X < (x1 + 16)) begin
						if ((y_character + 10) > `OBSTACLE1_START_Y) begin
							Gameover = 1;
						end	
					end
				end
				
				if (obs2) begin
					if ((`CHARACTER_X + 10) > x2 && `CHARACTER_X < (x2 + 20)) begin
						if ((y_character + 10) > `OBSTACLE2_START_Y) begin
							Gameover = 1;
						end
					end
				end
				
				if (obs3) begin
					if ((`CHARACTER_X + 10) > x3 && `CHARACTER_X < (x3 + 24)) begin
						if ((y_character + 10) > `OBSTACLE3_START_Y) begin
							Gameover = 1;
						end
					end
				end
				
				if (obs4) begin
					if ((`CHARACTER_X + 10) > x4 && `CHARACTER_X < (x4 + 28)) begin
						if ((y_character + 10) > `OBSTACLE4_START_Y) begin
							Gameover = 1;
						end
					end
				end
				
				// WIN SIGNAL ENABLED IF SCORE = 21
				if (score == 21)
					Win = 1;
				
			end
			
			CHANGE_COORDINATE: begin
				
				// LFSR CHOOSING WHICH OBSTACLE TO DRAW 
				if (ranNum_en) begin
					if (out[1:0] == 2'b00) begin
						obs1 = 1;
						obs2 = 0;
						obs3 = 0;
						obs4 = 0;
						ranNum_en = 0;
					end
					else if (out[1:0] == 2'b01) begin
						obs1 = 0;
						obs2 = 1;
						obs3 = 0;
						obs4 = 0;
						ranNum_en = 0;
					end
					
					else if (out[1:0] == 2'b10) begin
						obs1 = 0;
						obs2 = 0;
						obs3 = 1;
						obs4 = 0;
						ranNum_en = 0;
					end
					else if (out[1:0] == 2'b11) begin
						obs1 = 0;
						obs2 = 0;
						obs3 = 0;
						obs4 = 1;
						ranNum_en = 0;
					end
				end
					
					
				
				// ONCE OBSTACLE CHOSEN FROM ABOVE
				// SETS COORDINATES FOR THE OBSTACLE 
				if (obs1 == 1'b1 && obstacle1_move == 1'b0)begin
					obstacle1_move = 1;
					x1 = `OBSTACLE1_START_X;
					y1 = `OBSTACLE1_START_Y;
				end
				
				else if (obs2 == 1'b1 && obstacle2_move == 1'b0) begin
					obstacle2_move = 1;
					x2 = `OBSTACLE2_START_X;
					y2 = `OBSTACLE2_START_Y;
				end
				
				else if (obs3 == 1'b1 && obstacle3_move == 1'b0)begin
					obstacle3_move = 1;
					x3 = `OBSTACLE3_START_X;
					y3 = `OBSTACLE3_START_Y;
				end
				
				else if (obs4 == 1'b1 && obstacle4_move == 1'b0)begin
					obstacle4_move = 1;
					x4 = `OBSTACLE4_START_X;
					y4 = `OBSTACLE4_START_Y;
				end	
			
				
				
				// OBSTACLE ANIMATION
				if (obstacle1_move) // if obstacle1 was chosen
				begin
					if (x1 <= 7)begin
						ranNum_en = 1;
						score = score + 1;
						obstacle1_move = 0;
						obstacle2_move = 0;
						obstacle3_move = 0;
						obstacle4_move = 0;
						obs1 = 0;
						obs2 = 0;
						obs3 = 0;
						obs4 = 0;
					end
					x1 = x1 - 7;
				end
				
				if (obstacle2_move) // if obstacle2 was chosen
				begin
					if (x2 <= 6)begin
						score = score + 1;
						ranNum_en = 1;
						obstacle1_move = 0;
						obstacle2_move = 0;
						obstacle3_move = 0;
						obstacle4_move = 0;
						obs1 = 0;
						obs2 = 0;
						obs3 = 0;
						obs4 = 0;
					end
					x2 = x2 - 6;
				end
				
				if (obstacle3_move) // if obstacle3 was chosen
				begin
					if (x3 <= 5)begin
						score = score + 1;
						ranNum_en = 1;
						obstacle1_move = 0;
						obstacle2_move = 0;
						obstacle3_move = 0;
						obstacle4_move = 0;
						obs1 = 0;
						obs2 = 0;
						obs3 = 0;
						obs4 = 0;
					end
					x3 = x3 - 5;
				end
				
				if (obstacle4_move) // if obstacle4 was chosen
				begin
					if (x4 <= 5)begin
						score = score + 1;
						ranNum_en = 1;
						obstacle1_move = 0;
						obstacle2_move = 0;
						obstacle3_move = 0;
						obstacle4_move = 0;
						obs1 = 0;
						obs2 = 0;
						obs3 = 0;
						obs4 = 0;
					end
					x4 = x4 - 5;
				end
				

				// JUMP				
				// CHARACTER ANIMATION
				if (~jump_en) begin
					y_character = `CHARACTER_Y;
					x_character = `CHARACTER_X;
					y_up = 0;
					y_down = 0;
				end
				if (Jump1^Jump2) begin
					jump_en = 1;
					if (Jump1)
						jump1_en = 1;
					else if (Jump2)
						jump2_en = 1;
				end
				if (jump_en && y_character == `CHARACTER_Y)
				begin
					y_up = 1;
					y_down = 0;
					upSpeed1 = 8;
					downSpeed1 = 0;
					upSpeed2 = 12;
					downSpeed2 = 0;
				end
				if (jump_en && jump1_en && upSpeed1 == 0)
				begin
					y_up = 0;
					y_down = 1;
				end
				else if (jump_en && jump2_en && upSpeed2 == 0)
				begin
					y_up = 0;
					y_down = 1;
				end
				
				if (y_up && jump1_en && upSpeed1 > 0) begin
					upSpeed1 = upSpeed1 - 1;
					y_character = y_character - upSpeed1;
				end
				
				else if (y_up && jump2_en && upSpeed2 > 0) begin
					upSpeed2 = upSpeed2 - 1;
					y_character = y_character - upSpeed2;
				end
				
				else if (y_down && jump1_en) begin
					downSpeed1 = downSpeed1 + 1;
					y_character = y_character + downSpeed1;
				end
				
				else if (y_down && jump2_en) begin
					downSpeed2 = downSpeed2 + 1;
					y_character = y_character + downSpeed2;
				end
								
				if (jump_en && y_character >= (`CHARACTER_Y - 1) && y_down) begin
					jump_en = 0;
					jump1_en = 0;
					jump2_en = 0;
					upSpeed1 = 8;
					upSpeed2 = 12;
				end

				
				
				Draw_en = 1;
				Erase <= 0;	
				DrawFSM_en <= 0;
			end
			
			GAME_OVER: begin
				DrawFSM_en <= 1;
				Gameover = 1;
				y_up = 0;
				y_down = 0;
				x_character = `CHARACTER_X;
				y_character = `CHARACTER_Y;
				jump_en = 0;
				jump1_en = 0;
				jump2_en = 0;
				score = 0;
			end
			
			
			GAME_WIN: begin
				DrawFSM_en <= 1;
				Win = 1;
				y_up = 0;
				y_down = 0;
				x_character = `CHARACTER_X;
				y_character = `CHARACTER_Y;
				jump_en = 0;
				jump1_en = 0;
				jump2_en = 0;
				score = 0;
			end
		endcase		
	end
	// END OF OUTPUT LOGIC

	
	// calls the module that does all the drawing 
	DrawFSM (Erase, DrawFSM_en, CLOCK_50, x_in, y_in, x_out, y_out, Set_en, plot, FinishedDraw, Colour, obs1, obs2, obs3, obs4, Gameover, score, Win);  


	
	// COUNTER FOR THE HOLD STATE
	reg [32:0] count;
	always @(posedge CLOCK_50)
	begin
		if (currentState == HOLD) begin
			if (count <= 2000000) 
				count = count + 1;
		end
		// resetting counter
		if (currentState == DRAW | currentState == ERASE)
			count = 0;
	end
	

	// LFSP for when choosing 1 of the 4 obstacles 
	reg [3:0] out;  
	wire feedback;  
	assign feedback = ~(out[3] ^ out[2]) ; 
	
	always @(posedge CLOCK_50) 
	begin
		if (ranNum_en) begin
			out[0]<=feedback;
			out[1]<=out[0];
			out[2]<=out[1];
			out[3]<=out[2];
		end	
	end
	

	// PLOTTING
	always @(posedge CLOCK_50)
	begin
		if (currentState == SET)
		begin
			if ((Erase|Gameover) && ~ranNum_en) 
			begin 
				x_in <= 0;
				y_in <= 0;
			end
			else if (FinishedDraw == 0 && ~ranNum_en) // setting coordinates for character
			begin
				x_in <= `CHARACTER_X;
				
				y_in <= y_character;
				
			end
			else if (FinishedDraw == 1) // setting coordinates for the score
			begin
				x_in <= `SCORE_START_X;
				y_in <= `SCORE_START_Y;
			end
				
			else if (ranNum_en) begin
				x_in <= 160;
				y_in <= 0;
			end
			
			else if (FinishedDraw > 1) // setting coordinates for the obstacles
			begin 
				if (obs1) begin
					x_in <= x1;					
					y_in <= y1;
				end
				else if (obs2) begin
					x_in <= x2;
					y_in <= y2;
				end
				else if (obs3) begin
					x_in <= x3;
					y_in <= y3;
				end
				else if (obs4) begin
					x_in <= x4;
					y_in <= y4;
				end
			end
			
		end
	end


endmodule
// end of the Top module



// DrawFSM module
module DrawFSM (EraseSig, DrawFSM_en, Clock, x_in, y_in, x_out, y_out, Set_en, plot, FinishedDraw, Colour, obs1, obs2, obs3, obs4, Gameover, score, Win);
	input EraseSig;
	input DrawFSM_en;
	input Clock;
	input [7:0] x_in;
	input [6:0] y_in; 
	output [7:0] x_out; // x for VGA
	output [6:0] y_out; // y for VGA
	output reg Set_en;
	output reg plot;
	output reg [2:0] FinishedDraw;
	output reg [2:0] Colour;
	input obs1;
	input obs2;
	input obs3;
	input obs4;
	input Gameover;
	input [4:0] score;
	input Win;
	
	
	
	reg [7:0] change_x;
	reg [6:0] change_y;
	
	reg [7:0] maxplot_x, maxplot_y;

	
	assign x_out = x_in + change_x;
	assign y_out = y_in + change_y;


	// ROM INSTANTIATION
	wire [2:0] colour_obstacle1, colour_obstacle2, colour_obstacle3, colour_obstacle4,
					colour_character, colour_background, colour_gameover, colour_gamewin;

	wire [2:0] colour_score00, colour_score01, colour_score02, colour_score03, colour_score04, colour_score05, colour_score06,
					colour_score07, colour_score08, colour_score09, colour_score10, colour_score11, colour_score12, colour_score13,
					colour_score14, colour_score15, colour_score16, colour_score17, colour_score18, colour_score19, colour_score20; 
					
	modified_character (change_y*10 + change_x, Clock, colour_character);
	new_modified_default_background1 (change_y*160 + change_x, Clock, colour_background);
	modified_obstacle1 (change_y*16 + change_x, Clock, colour_obstacle1);
	modified_obstacle3 (change_y*24 + change_x, Clock, colour_obstacle3);
	modified_obstacle4 (change_y*28 + change_x, Clock, colour_obstacle4);
	modified_gameover (change_y*160 + change_x, Clock, colour_gameover);
	score00 (change_y*20 + change_x, Clock, colour_score00);
	score01 (change_y*20 + change_x, Clock, colour_score01);
	score02 (change_y*20 + change_x, Clock, colour_score02);
	score03 (change_y*20 + change_x, Clock, colour_score03);
	score04 (change_y*20 + change_x, Clock, colour_score04);
	score05 (change_y*20 + change_x, Clock, colour_score05);
	score06 (change_y*20 + change_x, Clock, colour_score06);
	score07 (change_y*20 + change_x, Clock, colour_score07);
	score08 (change_y*20 + change_x, Clock, colour_score08);
	score09 (change_y*20 + change_x, Clock, colour_score09);
	score10 (change_y*20 + change_x, Clock, colour_score10);
	score11 (change_y*20 + change_x, Clock, colour_score11);
	score12 (change_y*20 + change_x, Clock, colour_score12);
	score13 (change_y*20 + change_x, Clock, colour_score13);
	score14 (change_y*20 + change_x, Clock, colour_score14);
	score15 (change_y*20 + change_x, Clock, colour_score15);
	score16 (change_y*20 + change_x, Clock, colour_score16);
	score17 (change_y*20 + change_x, Clock, colour_score17);
	score18 (change_y*20 + change_x, Clock, colour_score18);
	score19 (change_y*20 + change_x, Clock, colour_score19);
	score20 (change_y*20 + change_x, Clock, colour_score20);
	modified_obstacle2 (change_y*20 + change_x, Clock, colour_obstacle2);
	modified_gamewin (change_y*160 + change_x, Clock, colour_gamewin);
	
	
	

	// FSM
	// FSM STATES
	parameter [3:0] NEUT = 4'b0001, START = 4'b0010, GET_COLOUR = 4'b0011, ERASE = 4'b0100, DRAW_CHARACTER = 4'b0101, 
			DRAW_OBSTACLE = 4'b0110, PLOT_IT = 4'b0111, INCREMENT_X = 4'b1000, INCREMENT_Y = 4'b1001, DONE = 4'b1010, 
			GAME_OVER = 4'b1011, DRAW_SCORE = 4'b1100, GAME_WON = 4'b1101;
	




	reg [3:0] currentState, nextState;
	// STATE TABLE
	always @(*)
	begin: state_table
		case (currentState)
			NEUT: begin
				if(DrawFSM_en == 1)
					nextState <= START;
				else if (DrawFSM_en == 0)
					nextState <= NEUT;	
			end
		
			START: begin
				if(FinishedDraw == `NUMBER_OF_ON_SCREEN_THINGS)
					nextState <= NEUT;
				else 
					nextState <= GET_COLOUR;	
			end
			
			GET_COLOUR: begin
				if (DrawFSM_en == 0)  
					nextState <= NEUT;
				else if (Gameover)
					nextState <= GAME_OVER;
				else if (Win)
					nextState <= GAME_WON;
				else if (EraseSig)
					nextState <= ERASE; 
				else if (FinishedDraw == 0)
					nextState <= DRAW_CHARACTER;
				else if (FinishedDraw == 1)
					nextState <= DRAW_SCORE;
				else if (FinishedDraw > 1)
					nextState <= DRAW_OBSTACLE;
			end
		
			GAME_OVER: nextState <= PLOT_IT;
			ERASE: nextState <= PLOT_IT;
			DRAW_CHARACTER: nextState <= PLOT_IT;
			DRAW_SCORE: nextState <= PLOT_IT;
			DRAW_OBSTACLE: nextState <= PLOT_IT; 
			GAME_WON: nextState <= PLOT_IT;



			PLOT_IT: begin       
				nextState <= INCREMENT_X;	
			end


			INCREMENT_X: begin
				if (change_x == maxplot_x) 
					nextState <= INCREMENT_Y;
				else
					nextState <= GET_COLOUR;
			end


			INCREMENT_Y: begin
				if (change_y == maxplot_y)
					nextState <= DONE;
				else
					nextState <= GET_COLOUR;
			end


			DONE: begin
				if (EraseSig)
					nextState <= NEUT;
				else 
					nextState <= START;
			end

		endcase
	end

	// STATE FF
	always @(posedge Clock)
	begin
			currentState <= nextState;
	end

	// OUTPUT LOGIC
	always @(posedge Clock)
	begin
		case (currentState)
			NEUT: begin
				
				Set_en <= 0;
				FinishedDraw <=0;
				change_x <= 0;
				change_y <= 0;
			end
			
			START: begin
				
				Set_en <= 0;
				change_x <= 0;
				change_y <= 0;
					
				if (EraseSig|Gameover|Win) // when drawing - default background screen
										   //              - game over screen
										   //              - game win screen
				begin
					maxplot_x = 159;
					maxplot_y = 119;
				end
				
				else if (FinishedDraw == 0) // for the character
				begin
					maxplot_x = 9; 
					maxplot_y = 9; 
				end
				
				else if (FinishedDraw == 1) // for the score
				begin	
					maxplot_x = 19;
					maxplot_y = 9;
				end
				
				else if (FinishedDraw > 1 && obs1)// for obstacle1
				begin
					maxplot_x = 15; 
					maxplot_y = 15; 
				end  
				
				else if (FinishedDraw > 1 && obs2) 
				begin
					maxplot_x = 19; 
					maxplot_y = 19;  
				end  
				
				else if (FinishedDraw > 1 && obs3) 
				begin
					maxplot_x = 23; 
					maxplot_y = 23; 
				end  
				
				else if (FinishedDraw > 1 && obs4) 
				begin
					maxplot_x = 27; 
					maxplot_y = 27; 
				end  
			end				

			GAME_OVER: Colour <= colour_gameover;
			
			GAME_WON: Colour <= colour_gamewin;
			
			ERASE: Colour <= colour_background;
			

			DRAW_CHARACTER: Colour <= colour_character;
				

			DRAW_OBSTACLE: begin
				
				if (obs1) // if obs1 = 1
					Colour <= colour_obstacle1;
				else if (obs3)
					Colour <= colour_obstacle3;
				else if (obs4)
					Colour <= colour_obstacle4;
				else if (obs2)
					Colour <= colour_obstacle2;
					
			end
			
			DRAW_SCORE: begin
				if (score == 0)
					Colour <= colour_score00;
				else if (score == 1)
					Colour <= colour_score01;
				else if (score == 2)
					Colour <= colour_score02;
				else if (score == 3)
					Colour <= colour_score03;
				else if (score == 4)
					Colour <= colour_score04;
				else if (score == 5)
					Colour <= colour_score05;
				else if (score == 6)
					Colour <= colour_score06;
				else if (score == 7)
					Colour <= colour_score07;
				else if (score == 8)
					Colour <= colour_score08;
				else if (score == 9)
					Colour <= colour_score09;
				else if (score == 10)
					Colour <= colour_score10;
				else if (score == 11)
					Colour <= colour_score11;
				else if (score == 12)
					Colour <= colour_score12;
				else if (score == 13)
					Colour <= colour_score13;
				else if (score == 14)
					Colour <= colour_score14;
				else if (score == 15)
					Colour <= colour_score15;
				else if (score == 16)
					Colour <= colour_score16;
				else if (score == 17) 
					Colour <= colour_score17;
				else if (score == 18)
					Colour <= colour_score18;
				else if (score == 19)
					Colour <= colour_score19;
				else if (score == 20)
					Colour <= colour_score20;
				
			end
		
			INCREMENT_X: begin
				change_x <= change_x + 1;
				
			end

			INCREMENT_Y: begin
				change_y <= change_y + 1;
				change_x <= 0;
			end

			DONE: begin
				Set_en <= 1;
				FinishedDraw <= FinishedDraw + 1;
			end
		endcase
	end
	// END OF OUTPUT LOGIC

	// plot = 1 only in PLOT_IT state
	always @(*)
	begin
		if (currentState == PLOT_IT)
			plot <= 1;
		else
			plot <= 0;
	end
	
endmodule