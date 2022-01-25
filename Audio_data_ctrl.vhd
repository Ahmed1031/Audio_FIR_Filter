-------------------------------
--Author : Ahmed Asim Ghouri
-- Dated:26 Jan 2012
-- Audio Data Control file
-- Acquires and sends audio data to WM8731 in slave mode  
-- Implemented on DE2-115 Cyclone-IV FPGA
-- Dated : 20/04/2012
-- Added functionality : Reading control switches 
-- 1. Bypas ADC-> DAC
-- 2. Serail-to-parallel convert ADC data and DAC to and from  R & L Ports 
-- 3. Send ADC serial data to GPIO pin 
--------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE IEEE.std_logic_arith.ALL; 
-- Audio Data Contrl -----------------------------------
entity Audio_data_ctrl is
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
end Audio_data_ctrl;
--
architecture audio_acquisition of  Audio_data_ctrl is

----------------
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
	signal LRchannel_sig, inv_LRchannel_sig: std_logic;
--
signal bitCounter     : integer range 30 downto 0 ;
signal LRcontr        : integer range 0 to 15; 
signal reg_contr      : integer range 0 to 10;
signal clk_contr      : std_logic_vector(15 downto 0); 
signal Rchannl_data   : std_logic_vector(15 downto 0);
signal Lchannl_data   : std_logic_vector(15 downto 0);  
signal Dac_data_R     : std_logic_vector(15 downto 0);
signal Dac_data_L     : std_logic_vector(15 downto 0);
signal LReg,DAC_sig, ADC_sig,Rst_sig, STPsig, DAC_LRsig : std_logic;
-- Delay stages 
signal DAC_LRsig1,DAC_LRsig2, DAC_LRsig3,DAC_LRsig4, DAC_LRsig5, DAC_LRsig6: std_logic;
signal DAC_LRsig7,DAC_LRsig8, DAC_LRsig9,DAC_LRsig10: std_logic;
--
attribute keep: boolean;
-----
begin
-----
Rst_sig   <= not (Rst); 
Bclk      <= bitClock_sig;
inv_LRchannel_sig <= not(LRchannel_sig);
-- ADC Parallel Data
Rchannel  <= Rchannl_data;
Lchannel  <= Lchannl_data;
--------------------------
Dac_data_R <= Rchanneli when rising_edge(Clock18Mhz); 
Dac_data_L <= Lchanneli when rising_edge(Clock18Mhz);
-- Parallel data latching clock
Rclk <= inv_LRchannel_sig;
Lclk <= LRchannel_sig;
-- Serial to parallel 
STPsig    <= '1';  	
ADC_sig   <= Adc_dat; -- Serial to parallel and vice versa 
Adc_LRc   <= LRchannel_sig;
DAC_dat   <= DAC_sig;
DAC_LRc   <= DAC_LRsig10;
-----------------------------------------
--turns active-low reset into active-high
	reset <= not Rst;
	
	bclk_counterMap: bclk_counter port map(
	                                      Rst_sig,
													  Clock18Mhz,
													  bitClock_sig
													  );
	----------------------------------------------
	LRchannelCounterMap: LRchannelCounter port map(
	                                               Rst_sig,
																  bitClock_sig,
																  LRchannel_sig
																  );
---------------------------------------------------------------

-- Channelling serial ADC/DAC data
--Serial_data_channeling : 	process (Rst,Control,EN,Clock18Mhz)
--begin 
--      if Rst = '0' then
--	      DAC_dat <= '0';
--		   ADC_sig <= '0';
--		   STPsig  <= '0';
--			ADC_data_out <= '0';
--								
--		elsif rising_edge(Clock18Mhz)  then  
--		   if EN = '1' then 
--		     case  Control is  
--			                   when "0000" => STPsig    <= '0'; 		 
--	         	                            DAC_dat   <= Adc_dat; -- bypass ADC -> DAC  
--														 DAC_LRc   <= LRchannel_sig;
--                                           Adc_LRc   <= LRchannel_sig;
--		                      -----------------------------
--		                      when "0001" => STPsig    <= '1';  	
--						                         ADC_sig   <= Adc_dat; -- Serial to parallel and vice versa 
--						                         Adc_LRc   <= LRchannel_sig;
--														 DAC_dat   <= DAC_sig;
--														 DAC_LRc   <= DAC_LRsig10;
--									 -------------------------------	
--				                when "0010" => ADC_data_out <= Adc_dat; -- ADC Serial out to GPIO
--									                Adc_LRc   <= LRchannel_sig;
--									                DAC_dat <= '0';
--														 STPsig  <= '0';
--				                -------------------------------
--									 when others =>  STPsig  <= '0';  
--									
--			end case ;	      			      
--		end if ;
--	end if ;
--end process ;					  			
--							  			
----------------------------------------------							  			
							  			
Serial_to_parallel : process ( Rst,bitClock_sig,LRchannel_sig,inv_LRchannel_sig,STPsig)
begin 
     if Rst = '0' then
        Rchannl_data <= (others=>'0');   			  			
		  Lchannl_data <= (others=>'0');
	  --<< Right Channel >>--	  
	  elsif rising_edge(bitClock_sig) then
	          if LRchannel_sig = '1' and STPsig = '1' then  
	               Rchannl_data(0) <= ADC_sig;
	               Rchannl_data(15 downto 1) <= Rchannl_data(14 downto 0);
	            end if ;   
	  --<< Left Channel >>--
	 	        if inv_LRchannel_sig = '1' and STPsig = '1' then 
	               Lchannl_data(0) <= ADC_sig;
	               Lchannl_data(15 downto 1) <= Lchannl_data(14 downto 0);
	             end if ;
	     end if;
	     
end process;             
----------------------------------------------------------------------------
Parallel_to_serial : process ( Rst,bitClock_sig,LRchannel_sig,inv_LRchannel_sig,STPsig)	
begin  
         if Rst = '0' then
				DAC_sig   <= '0';
				DAC_LRsig <= '0';
			   bitCounter <= 15;
			elsif rising_edge(bitClock_sig) then 	
               		-- Right Channel 		
				         if LRchannel_sig = '1' and STPsig = '1'  then  
							      -- Bit counter --
									if bitCounter = 0 then 
					                 bitCounter <= 15; 
					              else 	
									     bitCounter <= bitCounter - 1; 	
							       end if ;  
				        		          
								  DAC_sig  <= Dac_data_R(bitCounter); 
					      ----------------------------------------------------
							-- Left Channel
							elsif inv_LRchannel_sig = '1' and STPsig = '1'  then  
							      -- Bit counter --
									if bitCounter = 0 then 
					                 bitCounter <= 15; 
					              else 	
									     bitCounter <= bitCounter - 1; 	
							       end if ;  
				        		  DAC_sig  <= Dac_data_L(bitCounter); 
					           -----------------------------------
								end if ;  
					  		end if ;
					end process;	
---------------------------
-- Delay 
dac_LR_delayed : process (Rst,LRchannel_sig,bitClock_sig)
begin 
      if Rst = '0' then
			DAC_LRsig1 <= '0';
			DAC_LRsig2 <= '0';
			DAC_LRsig3 <= '0';
			DAC_LRsig4 <= '0';
			DAC_LRsig5 <= '0';
			DAC_LRsig6 <= '0';
			DAC_LRsig7 <= '0';
			DAC_LRsig8 <= '0';
			DAC_LRsig9 <= '0';
			DAC_LRsig10 <= '0';
      elsif rising_edge(bitClock_sig) then 
         		DAC_LRsig1 <= LRchannel_sig;
					DAC_LRsig2 <= DAC_LRsig1;
               DAC_LRsig3 <= DAC_LRsig2;
					DAC_LRsig4 <= DAC_LRsig3;
					DAC_LRsig5 <= DAC_LRsig4;
					DAC_LRsig6 <= DAC_LRsig5;
					DAC_LRsig7 <= DAC_LRsig6;
					DAC_LRsig8 <= DAC_LRsig7;
					DAC_LRsig9 <= DAC_LRsig8;
					DAC_LRsig10 <= DAC_LRsig9;
		end if ;
end process;
-------------		
end audio_acquisition;

