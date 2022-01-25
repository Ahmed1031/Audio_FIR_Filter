-------------------------------
--Author : Ahmed Asim Ghouri
--Dated:21 Dec 2011
-- I2c Audio Control Top file
-- Configures WM8731 into slave mode  
-- Implemented on DE2-115 Cyclone-IV FPGA
-- Tested and verified it, it works ADC->DAC output
-- Ver 1.1.2
-- Upgrade : incorporating Neuron project ROM and its i2c transmission engine
-- Also added LR channel control signals for ADC and DAC and BCLK 
-- Remarks : Works fine without clicking noise and upon Reset the audio stops
-- Dated : 18 April 2012
-- Audio by pass tested , it does redirect audio to LEDR
-- Dated : 21 April 2012
-- Ver:2.1
-- Dated : 11th June 2012
-- incorporating FIR Filter on both Left and Right Channel 
-- Clock frequency : 50Mhz
-- Bandpass pass filter with Band range  = 300hz-to-3Khz 
-- Data input/output port width : 16-bit
-- Output : 16-bit signed binary 
-- Order of FIR Filter : 45 
-- Window : Rectangular
-----------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
-- USE IEEE.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;
USE std.textio.ALL;
-- i2c Audio Contrl ---------
entity i2c_audio_ctrl_Top is
    port (
	     CLOCK_50 : in std_logic;
	     PUSHB    : in std_logic_vector ( 3 downto 0 );  
		  LED      : out std_logic_vector ( 3 downto 0 );  
        SW       : in std_logic_vector ( 17 downto 0 );    
        LEDR     : out std_logic_vector ( 17 downto 0 );
		  LEDG     : out std_logic_vector ( 7 downto 0 );
		  GPIO     : out std_logic_vector ( 35 downto 0 ); -- 40-pin Connector 
		  I2C_SCLK : out std_logic; --<< 250Khz
		  I2C_SDAT : inout std_logic;
		  --audio codec ports
		  AUD_ADCDAT : in std_logic;
		  AUD_ADCLRCK: out std_logic;
		  AUD_DACLRCK: out std_logic;
		  AUD_DACDAT : out std_logic;
		  AUD_XCK    : out std_logic; --<< 18.432Mhz
		  AUD_BCLK   : out std_logic  --<< 500.0Khz
		 ); 
end i2c_audio_ctrl_Top;
-------------------------------------------------------
architecture audio_processing of  i2c_audio_ctrl_Top is 
--
constant RST	      : natural:=0;
constant STRT	      : natural:=1;
constant STOP	      : natural:=2;
constant PLL_RST     : natural:=3;
signal RLchannli     : std_logic_vector(15 downto 0);
-- delacont will count to 999 to create a delay of 5ms 
signal delacont      : integer range 0 to 1000; 
signal cont          : integer range 0 to 10; 
signal clkcont       : integer range 0 to 30; 
signal bitcont       : integer range 0 to 25;
signal DACreg        : std_logic_vector(15 downto 0);
signal Fir_R_reg     : std_logic_vector(15 downto 0);
signal Fir_L_reg     : std_logic_vector(15 downto 0);
signal Data_packt    : std_logic_vector(25 downto 0);
signal Rchanl_reg    : std_logic_vector(15 downto 0);
signal Lchanl_reg    : std_logic_vector(15 downto 0);
signal clk18mhz, Pllckd,Pllrst,Clk500Khz, Rclk, Lclk, FIR_data_clk, FIR_valid : std_logic;
signal Clk10Khz, Audio_EN, i2c_en, BeeClk, Clk50Khz, Clk1Khz  : std_logic; 
signal SDAT_ctrl, Tx_ending, Rst_i2c,clk100mhz, Clk200mhz : std_logic; 
signal SW_reg        : std_logic_vector(3 downto 0);
--
attribute keep: boolean;
-- attribute keep of Audio_EN: signal is true;
----------------------------------------------------
component audio_pll IS
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		      : OUT STD_LOGIC ;  --<< 18.432Mhz
		c1		      : OUT STD_LOGIC ;  --<< 500.0Khz , switching to 100Khz 
		c2          : OUT STD_LOGIC ;  --<< 10.0Khz
		locked		: OUT STD_LOGIC 
	);
end component;
-----------------------------
component Audio_data_ctrl is 
 port (
	     Rst        : in std_logic;
		  Clock18Mhz : in std_logic;
		  EN         : in std_logic;
	     Control    : in std_logic_vector ( 3 downto 0 );  
		  Bclk       : out std_logic;  
		  DAC_LRc    : out std_logic;  
		  Adc_LRc    : out std_logic;     
		  DAC_dat    : out std_logic;   
		  Adc_dat    : in std_logic;
		  ADC_data_out : out std_logic; 
		  Rclk       : out std_logic;
		  Lclk       : out std_logic;
		  Rchannel   : out std_logic_vector ( 15 downto 0 );   
		  Lchannel   : out std_logic_vector ( 15 downto 0 );
		  Rchanneli  : in std_logic_vector ( 15 downto 0 );   
		  Lchanneli  : in std_logic_vector ( 15 downto 0 )
		   ); 
end component;
---------------------------------------------
-- i2c Serial Data Transmitter
component audioCodecController is
	port(
		clock50MHz : in std_logic;
		reset      : in std_logic;
		Enable     : in std_logic;
		I2C_SCLK_Internal: out std_logic;
		I2C_SDAT_Internal: out std_logic;
		SDAT_Control     : out std_logic;
		Tx_end           : out std_logic;
		clock50KHz_Out   : out std_logic
	);
end component;
----------------------------------------
-- FIR PLL --
component firpll IS
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		      : OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC 
	);
end component;
--------------------------------
---- Right Channel FIR Filter --
component fir IS
	PORT (
		clk	           : IN STD_LOGIC;
		reset_n	        : IN STD_LOGIC;
		ast_sink_data	  : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		ast_sink_valid	  : IN STD_LOGIC;
		ast_source_ready : IN STD_LOGIC;
		ast_sink_error   : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		ast_source_data  : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		ast_sink_ready	  : OUT STD_LOGIC;
		ast_source_valid : OUT STD_LOGIC;
		ast_source_error : OUT STD_LOGIC_VECTOR (1 DOWNTO 0)
	);
end component;
--------------------------------------------------------
---- Left Channel FIR Filter --
component fir_left IS
	PORT (
		clk	           : IN STD_LOGIC;
		reset_n	        : IN STD_LOGIC;
		ast_sink_data	  : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		ast_sink_valid	  : IN STD_LOGIC;
		ast_source_ready : IN STD_LOGIC;
		ast_sink_error   : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		ast_source_data  : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		ast_sink_ready	  : OUT STD_LOGIC;
		ast_source_valid : OUT STD_LOGIC;
		ast_source_error : OUT STD_LOGIC_VECTOR (1 DOWNTO 0)
	);
end component;
-- FSM--------------------------------------------------
	type Audio_control_type is (   --THESE ARE THE STATES
	      IDLE,       -- stay here and wait for push buttons
			Reset_codec,  
			Tx_Reset,
			Tx_Reset1,
		   Config,     -- get configuration for various settings
			Config1,
			Lag_State,
			Lag_State1,
			Audio_acquire, -- Acquiring audio data from ADC
			Audio_acquire1 -- Audio data processing 
			 ); --we'll add more as needed	
signal currt_state	: Audio_control_type ;
----------------------------------------------
attribute keep of currt_state : signal is true;
attribute keep of Rchanl_reg  : signal is true;
attribute keep of Lchanl_reg  : signal is true;
attribute keep of Rclk : signal is true;
-----
begin
--
AUD_XCK   <= clk18mhz;
AUD_BCLK  <= BeeClk;
--
-- DACreg <= Fir_R_reg when SW(4)= '1' else RLchannli; 
-- DACreg <= Rchanl_reg when rising_edge(CLOCK_50); 
Pllrst   <= not (PUSHB(PLL_RST)); 
-- Connecttions below going to 40-pin connector 
--GPIO(0)  <= Clk500Khz;   -- to pin IO_D1(pin 2) => FPGA pin AC15
--GPIO(1)  <= PUSHB(STOP); -- to pin IO_D3(pin 4) => FPGA pin 
--GPIO(2)  <= Clk10Khz;    -- to pin IO_D5(pin 6) => FPGA pin 
LEDR(0)  <= Audio_EN;    -- to pin IO_D7(pin 8) => FPGA pin 
Rst_i2c  <= not (PUSHB(PLL_RST));

 	
-- Port Map --
PLL_ports : audio_pll
	port map (
		areset => Pllrst,
		inclk0 => CLOCK_50,	
		c0		 => clk18mhz,  --<< 18.432Mhz
		c1     => Clk500Khz,
		c2     => Clk10Khz,
		locked => LEDG(0)	
	); 
----------------------------
Audio_control_ports : Audio_data_ctrl
 port map (
            Rst        => PUSHB(RST),     
				Clock18Mhz => clk18mhz, 				
				EN         => Audio_EN,        
				Control    => SW_reg,   
				Bclk       => BeeClk,      
				DAC_LRc    => AUD_DACLRCK,   
				Adc_LRc    => AUD_ADCLRCK,   
				DAC_dat    => AUD_DACDAT,   
				Adc_dat    => AUD_ADCDAT,
				ADC_data_out => LEDR(3),
				Rclk       => Rclk,
				Lclk       => Lclk,
				Rchannel   => Rchanl_reg,
				Lchannel   => Lchanl_reg,
				Rchanneli  => Fir_R_reg,          
				Lchanneli  => Fir_L_reg            
				);
--------------------------------------------
i2c_transmitter_ports : audioCodecController
port map 
(
				clock50MHz       => CLOCK_50,
				reset            => Rst_i2c,
				Enable           => i2c_en,
				I2C_SCLK_Internal=> I2C_SCLK,
				I2C_SDAT_Internal=> I2C_SDAT,
				SDAT_Control     => SDAT_ctrl,
				Tx_end           => Tx_ending,
				clock50KHz_Out   => Clk50Khz
				);
-------------------------------------------
-- Righ Channel FIR Filter
FIR_Filter_ports : fir 
port map 
(
		clk              => CLOCK_50,	           
		reset_n	        => PUSHB(RST),  
		ast_sink_data	  => Rchanl_reg, 
		ast_sink_valid	  => Audio_EN, -- Rclk, 
		ast_source_ready => '1',
		ast_sink_error   => "00",
		ast_source_data  => Fir_R_reg,
		ast_sink_ready	  => LEDR(4),
		ast_source_valid => FIR_valid,
		ast_source_error => LEDR(6 downto 5)
		);
------------------------------------------
-- Left Channel FIR Filter
Left_FIR_Filter_ports : fir_left 
port map 
(
		clk              => CLOCK_50,	           
		reset_n	        => PUSHB(RST),  
		ast_sink_data	  => Lchanl_reg, 
		ast_sink_valid	  => Audio_EN, -- Lclk, 
		ast_source_ready => '1',
		ast_sink_error   => "00",
		ast_source_data  => Fir_L_reg,
		ast_sink_ready	  => LEDR(7),
		ast_source_valid => FIR_valid,
		ast_source_error => LEDR(9 downto 8)
		);		
-- FSM------------------------------------------
FIR_PLL : firpll
port map 
(
  areset =>	Pllrst,
  inclk0	=> CLOCK_50,
  c0		=> clk100mhz,  
  locked	=> LEDR(10)
  );
-----------------------------------------------
Main_fsm : process(currt_state,Clk500Khz, PUSHB) 
begin
	if PUSHB(RST) = '0' then
	   currt_state <= Reset_codec;
		------------------------------
	elsif rising_edge(Clk500Khz) then
		case currt_state is
      ------------------------------------------------------------------------------------------	
	when IDLE => 	
		            if PUSHB(STRT) = '0' then
			              currt_state <= Config; --<< Send configuration serial data to Audio Codec
						elsif PUSHB(RST) = '0' then
				          currt_state <= Reset_codec;	
						else 
	                  currt_state <= IDLE; 	
						end if ;	
-----------------------------------------------------------------
------------------ Just for faster simulation -------------------
--                 if PUSHB(RST) = '0' then
--				          currt_state <= Reset_codec;	
--						else 
--	                  currt_state <= Audio_acquire; 	
--						end if ;	


		--------------------------------------------------------------------------------------------------
      when Reset_codec => cont     <= 0;
								  i2c_en   <= '0';
		                    Audio_EN <='0';
		                    bitcont  <= 25;  
		                    delacont <= 0;
								  currt_state <= IDLE; 	 
		
		-----------------------------------------------
		when Config => i2c_en <= '1';
		               currt_state <= Config1;
		-----------------------------------------------
		when Config1 => if Tx_ending = '1' then  
		                   i2c_en <= '0';
		                   currt_state <= Lag_State;	
					       else 
		                   currt_state <= Config1;
			             end if ; 					 
		 ---------------------------------------------
      when Lag_State => -- if delacont > 999 then 
		                  if delacont > 5 then
                           currt_state <= Audio_acquire;	
								else 
								   currt_state <= Lag_State1;
							   end if;   	
		---------------------------------------------
      when Lag_State1 => delacont <= delacont + 1;
		                   currt_state <= Lag_State;
       ----------------------------------------------				
		when Audio_acquire => SW_reg <= SW(3 downto 0);
                            currt_state <= Audio_acquire1; 	
		---------------------------------------------				
		when Audio_acquire1 => Audio_EN <= '1';
                            currt_state <= IDLE; 									 
						
		---------------------------------------------	
   	when others  => currt_state <= IDLE; 
     end case;
	end if;
end process;		

------------
-- Creating data for DAC for testing  
-- Just for testing DAC's parallel to serial data conversion 
-- it worked and i could see saw tooth wave on the scope .
DAC_data : process (BeeClk)
begin 
    if PUSHB(RST) = '0' then
	    RLchannli <=(others=>'0');
    elsif  rising_edge(BeeClk) then 
	          RLchannli <= RLchannli + 1;
		end if ;
end process;	  
-----------------------------------------
--Dac_data_switching : process ( SW, FIR_data_clk, Rclk )
--begin 
--   if PUSHB(RST) = '0' then
--	   DACreg <=(others=>'0');
--   elsif rising_edge(Rclk) then
--	    if SW(4)= '1' then
--		  DACreg <= Rchanl_reg;
--        -- DACreg <= Fir_R_reg;
--	    else 
--		  DACreg <= RLchannli;
--		end if ;   
--	 end if ; 
--end process;	  
---------------------
end audio_processing;
			