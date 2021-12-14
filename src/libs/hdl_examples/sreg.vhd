library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sreg is
generic (
	WIDTH : integer := 4;
	DEPTH : integer := 3
);
port (
	clk : in std_logic;
	ce : in std_logic;
	sclr : in std_logic;
	d : in std_logic_vector(WIDTH-1 downto 0);
	q : out std_logic_vector(WIDTH-1 downto 0);
);

	-------------------------------------------------
	--               PARAMETERS                    --
	-------------------------------------------------

	-------------------------------------------------
	--            SIGNAL DECLARATION               --
	-------------------------------------------------
architecture behavioral of sreg is
	type sr_type is array (0 to DEPTH-1) of std_logic_vector (WIDTH-1 downto 0);
	signal sr : sr_type;

	------------------------------------------------------------------------------------------------------------
	--                                            Design starts here                                          --
	------------------------------------------------------------------------------------------------------------
begin
	-- The shift register.
	process (clk)
	begin
	if rising_edge(clk) then
		if (sclr = '1') then
			SREG_SCLR : for ii in 1 to DEPTH generate
				s(ii) <= (other => '0');
			end generate;
		elsif (ce = '1') then
			sr(0) <= d;
			SREG_CE : for ii in 1 to DEPTH generate
				sr(ii) <= sr(ii-1);
			end generate;
		end if;
	end if;

	-- Output.
	q <= sr(DEPTH-1);

end behavioral;
