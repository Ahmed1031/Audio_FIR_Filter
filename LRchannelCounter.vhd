--5/10/11
--left channel, right channel counter for audio codec
--the state changes after 16 falling-edge cycles of the bitClock

library ieee;
use ieee.std_logic_1164.all;

entity LRchannelCounter is
	port(
		--active high reset
		reset: in std_logic;
		bclk: in std_logic;
		--left = '1', right = '0'
		LRchannel: out std_logic
	);
end LRchannelCounter;

architecture behavior of LRchannelCounter is

	signal count: integer range 0 to 15 := 0;
	signal output: std_logic := '1';

begin

	process(reset, bclk)
	begin
		if reset = '1' then
			output <= '1';
			count <= 0;
		elsif falling_edge(bclk) then
			if count < 15 then
				count <= count + 1;
			else
				output <= not output;
				count <= 0;
			end if;
		end if;
	end process;
	
	LRchannel <= output;

end behavior;