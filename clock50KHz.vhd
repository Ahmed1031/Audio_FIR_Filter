--50KHz clock for I2C module
--input is 50MHz clock from PLL clockBuffer
--output is 50KHz clock
--50MHz/1000 = 50KHz => count to 500, then not the output
library ieee;
use ieee.std_logic_1164.all;

entity clock50KHz is
		port(
			inClock,reset: in std_logic;
			outClock50KHz: out std_logic
		);
end clock50KHz;

architecture behavior of clock50KHz is

	--count to half the period (500)
	signal count: integer range 0 to 499;
	--output 50KHz clock signal
	signal output: std_logic;

begin

	process(inClock,reset)
	begin
		--asynchronous active-high reset
		if reset = '0' then
			--synchronous count
			if rising_edge(inClock) then
				if count = 499 then 
					count <= 0;
					--count has reached 500 (half-period)
					output <= not output;		
				else
					count <= count + 1;
				end if;
			end if;
		else
			--in reset
			count <= 0;
			output <= '0';
		end if;
	end process;
	
	--assign output signal
	outClock50KHz <= output;
end behavior;