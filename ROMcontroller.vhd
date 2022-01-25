--5/3/11
--using input from the audio codec, selects and returns a 24-bit word from the rom
--input is an increment signal, which causes the address of the ROM to increment by one, 
--from 0 to 10

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ROMcontroller is 
	port(
		--asynch active-high reset
		reset: in std_logic;
		increment: in std_logic;
		clock50KHz: in std_logic;
		clock50MHz: in std_logic;
		ROMword: out std_logic_vector(23 downto 0)
	);
end ROMcontroller;

architecture behavior of ROMcontroller is

	--ROM 1-port memory module from MegaIP Wizard
	component codecROM IS
		PORT
		(
			address		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			q		: OUT STD_LOGIC_VECTOR (23 DOWNTO 0)
		);
	END component;

	--address vector sent to the ROM component
	signal address_vector_5: std_logic_vector(4 downto 0);
	signal address_integer: integer range 0 to 9 := 0;
	--output data vector from the ROM component
	signal data_vector_24: std_logic_vector(23 downto 0);
	
	
begin

	codecROMInstance: codecROM port map(address_vector_5, clock50MHz,  data_vector_24);

	process(clock50KHz, reset)
	begin
		if reset = '0' then
			if rising_edge(clock50KHz) then
				if increment = '1' then 
					if address_integer < 9 then
						address_integer <= address_integer + 1;
					else
						address_integer <= 0;
					end if;
				end if;
			end if;
		else
			address_integer <= 0;
		end if;
	end process;
	
	--convert address integer into address vector
	address_vector_5 <= std_logic_vector(to_unsigned(address_integer, 5));
	
	ROMword <= data_vector_24;
	
end behavior;