--5/10/11
--bitCount counter for audio codec.  Input is 18MHz clock (master clock) from PLL. Output is 
--1 period is 12 counts of the master clock => flip the output every 6 counts

library ieee;
use ieee.std_logic_1164.all;

entity bclk_counter is
	port(
		--active high reset
		reset: in std_logic; 
		mclk: in std_logic;
		bclk: out std_logic
	);
end bclk_counter;

architecture behavior of bclk_counter is

	signal count: integer range 0 to 5 := 0;
	signal output: std_logic := '0';
	
begin

	process(reset, mclk)
	begin
		if reset = '1' then
			count <= 0;
		elsif rising_edge(mclk) then
			if count < 5 then
				count <= count + 1;
			else
				output <= not output;
				count <= 0;
			end if;
		end if;
	end process;

	bclk <= output;
	
end behavior;