# fpga-game-of-life
FPGA implementation of a simulation for Conway's Game of Life, rendered on a monitor via a VGA cable. Reset button implemented to set grid state back to glider in top-left corner.

## Demo
![Conway's Game of Life Demo](demo.gif)

## How It Works
Grid size is 80x60, each cell is 8x8 pixels on a 640x480p monitor transmitted at 60Hz through a VGA output. 
The on board 50MHz clock is used to drive a clock divider to create a 25MHz clock, which is then used to sync VGA output and as a counter for game tick time (0.5s). 
The rules for Conway's Game of Life are implemented with the grid wrapping at the edges. Calculation of next grid state is done combinationally and registered to previous grid every game tick.
Reset button is checked every game tick to decide whether to display initial grid or next grid state.

## Structure
conway_game_of_life.v  - Verilog code with top level module: conway_game_of_life
conway_game_of_life.qpf - Quartus project file
conway_game_of_life.qsf - Pin assignments and settings imported from Terasic's DE1-SoC template qsf file

## How to Run
Using DE1-SoC, connect VGA cable between board and monitor. Compile code in Quartus and program onto board through JTAG.
Hold KEY0 on DE1-SoC to reset the glider pattern back to top-left corner.
