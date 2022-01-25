
-- Testbench for the i2c_audio_ctrl_Top.vhd

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
USE IEEE.std_logic_arith.ALL; 

ENTITY tb_audioctrl IS
END tb_audioctrl;

ARCHITECTURE testing_audio OF tb_audioctrl IS 
COMPONENT i2c_audio_ctrl_Top
port (
	     CLOCK_50 : in std_logic;
	     PUSHB    : in std_logic_vector ( 3 downto 0 );  
		  LED      : out std_logic_vector ( 3 downto 0 );  
        SW       : in std_logic_vector ( 17 downto 0 );    
        LEDR     : out std_logic_vector ( 17 downto 0 );
		  LEDG     : out std_logic_vector ( 7 downto 0 );
		  GPIO     : out std_logic_vector ( 35 downto 0 ); -- 40-pin Connector 
		  I2C_SCLK : out std_logic;
		  I2C_SDAT : inout std_logic;
		  --audio codec ports
		  AUD_ADCDAT : in std_logic;
		  AUD_ADCLRCK: out std_logic;
		  AUD_DACLRCK: out std_logic;
		  AUD_DACDAT : out std_logic;
		  AUD_XCK    : out std_logic;
		  AUD_BCLK   : out std_logic
		 ); 
END COMPONENT;
--------------------------------
SIGNAL clktb, sclk_tb, sdat_tb, adcdat_tb, adclrck_tb, daclrck_tb :  std_logic;
SIGNAL dacdat_tb, xck_tb, bclk_tb :  std_logic; 
SIGNAL push_tb :  std_logic_vector(3 downto 0);
SIGNAL led_tb  :  std_logic_vector(3 downto 0);
SIGNAL key_tb  :  std_logic_vector(17 downto 0);
SIGNAL ledr_tb :  std_logic_vector(17 downto 0);
SIGNAL ledg_tb :  std_logic_vector(7 downto 0);
SIGNAL bitcontr:  integer range 0 to 15;
CONSTANT CLOCK_TP : time:= 20 ns;
CONSTANT Adc_data : std_logic_vector(15 downto 0):="1000110010010011";
-----
BEGIN
----------------------------
-- push_tb(0) => Reset
-- push_tb(1) => Start

push_tb(0) <= '1','0' after 5us, '1' after 11us;
push_tb(1) <= '1','0' after 250us,'1' after 256us;
push_tb(2) <= '1';
push_tb(3) <= '1';
key_tb(3 downto 0) <= "0000", "0001" after 5ms ;
-- Instantiate the Unit Under Test (UUT)
	
uut: i2c_audio_ctrl_Top PORT MAP(
			                        CLOCK_50 => clktb,
											PUSHB    => push_tb,
											LED      => led_tb,
											SW       => key_tb,
											LEDR     => ledr_tb,
											LEDG     => ledg_tb,
											I2C_SCLK => sclk_tb,
											I2C_SDAT => sdat_tb,
											AUD_ADCDAT   => adcdat_tb,
											AUD_ADCLRCK  => adclrck_tb,
											AUD_DACLRCK  => daclrck_tb,
											AUD_DACDAT   => dacdat_tb,
											AUD_XCK      => xck_tb,
											AUD_BCLK     => bclk_tb
											);
-----------------------------------------------------------
-- ADC serial data output 
Adc_Data_gen : process
begin 
  for bitcontr in 0 to 15 loop
      wait until bclk_tb = '1'; 
		adcdat_tb <= Adc_data(bitcontr);
		wait until bclk_tb = '0';
		next;
	end loop;
end process;

 
-- Synchronous Clock = 5Mhz
Clock_gen : process
begin
    wait for CLOCK_TP/2;
    clktb <= '0';
    wait for CLOCK_TP/2;
    clktb <= '1';
end process;
end;   