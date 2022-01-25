--4/14/11
--Controller for the Wolfson audio codec
--Uses I2C to initialize and send data to the codec
--Data is stored in a 24x10 bit ROM component.

library ieee;
use ieee.std_logic_1164.all;

entity audioCodecController is
	port(
		clock50MHz : in std_logic;
		reset      : in std_logic;
		Enable     : in std_logic;
		I2C_SCLK_Internal: out std_logic;
		--must be inout to allow FPGA to read the ack bit
		I2C_SDAT_Internal: out std_logic;
		SDAT_Control     : out std_logic;
		Tx_end           : out std_logic;
		--for testing
		clock50KHz_Out   : out std_logic
	);
end audioCodecController;

architecture behavior of audioCodecController is

	--50KHz SCLK
	component clock50KHz is
		port(
			inClock,reset: in std_logic;
			outClock50KHz: out std_logic
		);
	end component;
	
	--counts the number of data bits sent
	component dataBitCounter is
		port(
			--active high count enable
			countEnable: in std_logic;
			--active high reset
			reset: in std_logic;
			clock: in std_logic;
			currentBitCount: out integer;
			currentWordCount: out integer
		);
	end component;
	
	--ROM storing codec initialization data.  
	--10 words, 24 bits each
	component ROMcontroller is 
		port(
			--asynch active-high reset
			reset: in std_logic;
			increment: in std_logic;
			clock50KHz: in std_logic;
			clock50MHz: in std_logic;
			ROMword: out std_logic_vector(23 downto 0)
		);
	end component;

	--50KHz clock used for SCLK
	signal clock50KHz_Internal: std_logic;
	
	--internal signals
	signal SDAT_Temp,SCLK_Temp: std_logic;
	
	--starts/stops the data bit counter
	signal bitCountEnable: std_logic;
	
	--start incrementing the ROM each clock cycle
	signal incrementROM: std_logic;
	
	--the 24 bits of data to be sent
	signal ROM_data_vector_24: std_logic_vector(23 downto 0);
	
	--track bit in current set of data (0 -> 23)
	signal currentDataBit: integer;
	
	--trach current 24-bit word in ROM
	signal currentDataWord: integer;
	
	--each state places one bit on the SDAT wire
	type I2CState_type is (
	                       resetState,
							 startCondition,
							       sendData,
								 acknowledge,
								 prepForStop,
							  stopCondition
								 );
	signal I2C_state: I2CState_type;
	--------------------------------
	
begin

	clock50KHzInstance: clock50KHz port map(
	                                        clock50MHz,
	                                             reset,
											  clock50KHz_Internal
											  );
---------------------------------------------------											  
	dataBitCounterInstance: dataBitCounter port map(
	                                                bitCountEnable,
															  	          	reset,
														     clock50KHz_Internal,
															       currentDataBit,
																	currentDataWord
																	 );
-------------------------------------------------------------------																	 
	ROMcontrollerInstance: ROMcontroller port map(
	                                               reset,
													    incrementROM,
										   	clock50KHz_Internal,
											          	clock50MHz,
											  	  ROM_data_vector_24
												); 
--------------------------------------------------------
	
	--FSM that sends start condition, address, write bit = 0,
	--then waits for ack from the codec
	process(clock50KHz_Internal,reset)
	begin
		--asynchronous active-high reset
		if reset = '0' and Enable = '1' then
			if rising_edge(clock50KHz_Internal) then
				case I2C_state is
					when resetState => 
						--place both wires high to prepare for the start condition
						SDAT_Temp <= '1';
						SCLK_Temp <= '1';
						I2C_state <= startCondition;
						incrementROM <= '0';
					when startCondition => 
						--pull the SDAT line low -> the start condition
						SDAT_Temp <= '0';
						I2C_state <= sendData;
						--start counting data bits on the next clock cycle
						bitCountEnable <= '1';
					when sendData =>
						--release the clock
						SCLK_Temp <= '0';
						SDAT_Control <= '1';
						--send the next data bit
						SDAT_Temp <= ROM_data_vector_24(currentDataBit);
						--is it time for the ack bit?
						if (currentDataBit = 16) or (currentDataBit = 8) or (currentDataBit = 0) then
							I2C_state <= acknowledge;
							bitCountEnable <= '0';
						else
							I2C_state <= sendData;
						end if;
					when acknowledge => 
						--To allow the codec to pull SDAT low, SDAT must be set to Z					
						SDAT_Control <= '0';
						--if all 24 bits sent, end the transmission
						if currentDataBit = 23 then
							I2C_state <= prepForStop;
						else
							I2C_state <= sendData;
							bitCountEnable <= '1';
						end if;
					when prepForStop =>
						--take control of SDAT line again
						SDAT_Control <= '1';
						--pull SCLK high, and set SDAT low to prep for stop condition
						SCLK_Temp <= '1';
						SDAT_Temp <= '0';
						I2C_state <= stopCondition;	
					when stopCondition => 
						--keep SCLK high, and pull SDAT high as stop condition
						SDAT_TEMP <= '1';
						--more data words to send?
						--Note: currentDataWord = # of words already sent at this point
						if currentDataWord < 10 then
							incrementROM <= '1';
							I2C_state <= resetState;
						else
							incrementROM <= '0';
							Tx_end <= '1';
						end if;
				end case;
			end if;
		else
			SDAT_Temp <= '1';
			SCLK_Temp <= '1';
			SDAT_Control <= '1';
			bitCountEnable <= '0';
			incrementROM <= '0';
			Tx_end <= '0';
			I2C_state <= resetState;
		end if;
	end process;
	
	I2C_SDAT_Internal <= SDAT_Temp;
	--use the 50KHz clock to drive the state machine, and the (not 50KHz) clock to drive the
	--codec.  The Half-period delay allows the SDAT data to stabilize on the line before 
	--being read by the codec
	I2C_SCLK_Internal <= SCLK_Temp or (not clock50KHz_Internal);
	
	--for testing purposes
	clock50KHz_Out <= clock50KHz_Internal;
	
end behavior;