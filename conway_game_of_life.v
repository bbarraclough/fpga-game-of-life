`timescale 1ns/1ps

// old testbench when grid was initialised at start of simulation
module testbench();
	
	integer count = 0;
	reg VGA_VS = 0;
	wire [0:4799] cur_grid;
	
	game_of_life DUT (.clk25(VGA_VS), .cur_grid(cur_grid));
	
	// prints current state of grid
	task print_grid;
		integer x, y;
		begin
			$display("FRAME %d", count);
			for (x = 0; x <= 79; x = x + 1) begin
				for (y = 0; y <= 59; y = y + 1) begin
					if (cur_grid[x * 60 + y]) 
						$write(" X ");
					else 
						$write(" . ");
				end
				$display("");
			end
			count = count + 1;
		end
	endtask
	
	initial begin
		print_grid;
		
		repeat (19) begin
			#20 VGA_VS = 0;
			#20 VGA_VS = 1;
			print_grid;
		end
	end

endmodule



module conway_game_of_life (input CLOCK_50, input [0:0] KEY,
									 output [0:0] LEDR, 
									 output [7:0] VGA_R, VGA_G, VGA_B, 
									 output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
	wire [9:0] hcount, vcount;
	wire visible;
	
	vga_sync vga (.CLOCK_50(CLOCK_50), 
					  .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK_N(VGA_BLANK_N), 
					  .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK),
					  .hcount(hcount), .vcount(vcount), .visible(visible));


	wire [0:4799] prev_grid;
					  
	game_of_life gol (.clk25(VGA_CLK), .reset(KEY[0]), .prev_grid(prev_grid));
	
	vga_projector projector(.hcount(hcount), .vcount(vcount), .grid(prev_grid), .visible(visible), .red(VGA_R), .green(VGA_G), .blue(VGA_B));
	
	//indicate working
	assign LEDR = 10'b1;
					 
endmodule

// calculates next state at vsync pulse (each frame during blanking time)
module game_of_life (input clk25, reset, output reg [0:4799] prev_grid);
	
	wire [0:4799] cur_grid;
	
	function [3:0] count_neighbours;
		input [0:4799] grid;
		input integer x, y;
		integer x_left, x_right, y_up, y_down, x_left_increment, x_right_increment, x_increment;
		begin
			// calculate indices
			x_left = (x > 0)  ? x-1 : 79;
			x_right = (x < 79) ? x+1 : 0;
			y_up = (y > 0)  ? y-1 : 59;
			y_down = (y < 59) ? y+1 : 0;
			x_left_increment = x_left * 60;
			x_right_increment = x_right * 60;
			x_increment = x * 60;
			
			// count neighbours with wrapping of grid
			count_neighbours = grid[x_left_increment + y_up] +
								grid[x_increment + y_up] +
								grid[x_right_increment + y_up] +
								grid[x_left_increment + y] +
								grid[x_right_increment + y] +
								grid[x_left_increment + y_down] +
								grid[x_increment + y_down] +
								grid[x_right_increment + y_down];
		end
	endfunction
	
	genvar x, y;
	generate
		for (x = 0; x < 80; x = x + 1) begin : col
			for (y = 0; y < 60; y = y + 1) begin : row
				wire [3:0] n_neighbours = count_neighbours(prev_grid, x, y);

				assign cur_grid[x * 60 + y] = ((prev_grid[x * 60 + y] && (n_neighbours == 2 || n_neighbours == 3)) || 
														 (~prev_grid[x * 60 + y] && n_neighbours == 3));
			end
		end
	endgenerate
	
	// clock divider for game tick
	reg [23:0] count = 0;
	always @(posedge clk25) begin
		count <= (count < 12_500_000) ? count + 1'd1 : 24'd0;
		// every 1/2 second
		if (count == 12_500_000) begin
			if (reset) prev_grid <= cur_grid;
			else begin
				// glider pattern
				prev_grid = 4800'b0;
				prev_grid[1 * 60] = 1'b1;
				prev_grid[2 * 60 + 1] = 1'b1;
				prev_grid[2] = 1'b1;
				prev_grid[1 * 60 + 2] = 1'b1;
				prev_grid[2 * 60 + 2] = 1'b1;
			end 
		end
	end
	
endmodule


module vga_sync (input CLOCK_50,
						output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK,
						output reg [9:0] hcount, vcount,
						output visible);
	
	initial begin
		hcount = 0; // horizontal pixel pos, 0-799
		vcount = 0; // vertical pixel pos, 0-524
	end
	
	// to half clock frequency to 25MHz
	reg clk25 = 0;
	always @(posedge CLOCK_50)
		clk25 <= ~clk25;
	
	// increment hcount and vcount
	always @(posedge clk25) begin
		hcount <= hcount + 1'd1;
		if (hcount >= 799) begin
			hcount <= 0;
			vcount <= vcount + 1'd1;
			if (vcount >= 524)
				vcount <= 0;
		end
	end
	
	// sync pulse
	assign visible = (hcount < 640) && (vcount < 480);
	assign VGA_HS = ~((656 <= hcount) && (hcount < 752)); // LOW period at 656 <= hcount < 752
	assign VGA_VS = ~((490 <= vcount) && (vcount < 492)); // LOW period at 490 <= vcount < 492
	
	// for Digital to Analog Converter (DAC)
	assign VGA_CLK = clk25;
	assign VGA_BLANK_N = visible; 
	assign VGA_SYNC_N = 1'b0; // disable composite sync, use HS and VS instead
	
endmodule


// maps grid through vga connector to be displayed
module vga_projector (input [9:0] hcount, vcount, input visible, input [0:4799] grid, output reg [7:0] red, green, blue);
	
	wire [6:0] x, y;
	wire [12:0] x_increment;
	assign x = (hcount < 640) ? hcount[9:3] : 7'b0; // divide by 8 if visible
	assign y = (vcount < 480) ? vcount[9:3] : 7'b0; // divide by 8 if visible
	assign x_increment = x * 60;
	
	always @(*) begin
		red <= (visible && grid[x_increment + y]) ? 8'h0 : 8'hFF;
		green <= (visible && grid[x_increment + y]) ? 8'h0 : 8'hFF;
		blue <= (visible && grid[x_increment + y]) ? 8'h0 : 8'hFF;
	end
	
endmodule




