--5/2/11
--synchronous counter using the 50khz clock from the audioCodecController
--counts the dataBits (0 to 23) sent to the audio codec

library ieee;
use ieee.std_logic_1164.all;

entity dataBitCounter is
	port(
		--active high count enable
		countEnable: in std_logic;
		--active high reset
		reset: in std_logic;
		clock: in std_logic;
		currentBitCount: out integer;
		currentWordCount: out integer
	);
end dataBitCounter;

architecture behavior of dataBitCounter is
 
	--output
	signal countBit: integer range 0 to 23 := 23;
	signal countWord: integer range 0 to 10 := 0;
 
begin

	--starts counting when rest is cleared and enable is 
	process(clock, reset, countEnable)
	begin
		if reset = '0' then
			if rising_edge(clock) then
				if countEnable = '1' then
					if countBit > 0 then
						countBit <= countBit - 1;
					else
						countBit <= 23;
						if countWord < 10 then
							countWord <= countWord + 1;
						else 
							countWord <= 0;
						end if;
					end if;
				end if;
			end if;
		else
			countBit <= 23;
			countWord <= 0;
		end if;
	end process;

	currentBitCount <= countBit;
	currentWordCount <= countWord;
	
end behavior;