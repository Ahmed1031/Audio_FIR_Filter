--5/9/11
--Creates the ADC and DAC signals needed by the audio codec.
--inputs are reset from the delay buffer, 50MHz clock from PLL

library ieee;
use ieee.std_logic_1164.all;

entity AdcDacController is
	port(
		--reset signal starts '0', then goes to '1' after 40 ms => active-low
		resetn: in std_logic;
		--from 50MHz PLL at toplevel
		clock18MHz_in: in std_logic;
		--line-in on the DE1
		adcData: in std_logic;
		--line-out on the DE1
		dacData: out std_logic;
		bitClock: out std_logic;
		dacLRSelect: out std_logic;
		adcLRSelect: out std_logic;
		--neuron model signals
		neuronVin: in std_logic_vector(15 downto 0);
		neuronUin: in std_logic_vector(15 downto 0);
		--selects loopback or neuron signals using switches
		outputSelect: in std_logic_vector(1 downto 0)
	);
end AdcDacController;

architecture behavior of AdcDacController is
	
	--bitCount generator.  Changes every 12 counts of the master clock (18MHz)
	component bclk_counter is
		port(
			--active high reset
			reset: in std_logic; 
			mclk: in std_logic;
			bclk: out std_logic
		);
	end component;
	
	--generates left/right channel signal
	component LRchannelCounter is
		port(
			--active high reset
			reset: in std_logic;
			bclk: in std_logic;
			--left = '1', right = '0'
			LRchannel: out std_logic
		);
	end component;

	--active-high reset
	signal reset: std_logic;
	
	--bit clock
	signal bitClock_sig: std_logic;
	
	--left/right channnel control signal
	signal LRchannel_sig: std_logic;

	--counts the bit of neuron data to be sent
	signal bitCounter: integer range 15 downto 0 := 15;
	
begin
	
	--turns active-low reset into active-high
	reset <= not resetn;
	
	bclk_counterMap: bclk_counter port map(
	                                      reset,
													  clock18MHz_in,
													  bitClock_sig
													  );
	----------------------------------------------
	LRchannelCounterMap: LRchannelCounter port map(
	                                               reset,
																  bitClock_sig,
																  LRchannel_sig
																  );
---------------------------------------------------------------
	
	--output signals
	bitClock <= bitClock_sig;
	dacLRSelect <= LRchannel_sig;
	adcLRSelect <= LRchannel_sig;
	
	--count out the neuron model bits
	process(bitClock_sig, bitCounter)
	begin
		if rising_edge(bitClock_sig) then
			if bitCounter > 0 then
				bitCounter <= bitCounter - 1;
			else 
				bitCounter <= 15;
			end if;
		end if;
	end process;
	
	--select loopback test or neuron model DAC output
	process(neuronVin, neuronUin, adcData, outputSelect, bitCounter)
	begin
		if outputSelect = "01" then
			dacData <= neuronVin(bitCounter);
		elsif outputSelect = "10" then
			dacData <= neuronUin(bitCounter);
		else
			dacData <= adcData;
		end if;
	end process;
		
end behavior;