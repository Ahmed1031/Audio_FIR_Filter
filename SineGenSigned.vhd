library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity SineGenSigned is
  generic (
    SamplingFrequency : real := 48000.0;
    Amplitude         : real := 1.0;
    SineFrequency     : real := 697.0);
  port (
    Clock       : in  std_logic;
    ClockEnable : in  std_logic;
    SineWave    : out signed(15 downto 0));  -- Q2.14
end entity SineGenSigned;

architecture Behavioral of SineGenSigned is
  constant w0 : real  := math_2_pi * SineFrequency / SamplingFrequency;
  signal y0   : signed(17 downto 0) := to_signed(0, 18);        -- Q2.16
  signal y1   : signed(17 downto 0) := to_signed(0, 18);        -- Q2.16
  signal y2   : signed(17 downto 0) := to_signed(integer(-Amplitude * sin(w0) * 65536.0), 18);  -- Q2.16
  signal temp : signed(35 downto 0);                            -- Q4.32
begin

  process (Clock) is
  begin  -- process
    if rising_edge(Clock) then
      if ClockEnable = '1' then
        y1 <= y0;
        y2 <= y1;
      end if;
    end if;
  end process;

  temp <= to_signed(integer(2.0 * cos(w0) * 65536.0), 18) * y1;

  y0 <= temp(33 downto 16) - y2;

  SineWave <= y0(17 downto 2);

end architecture Behavioral;
