---------------------------------------------------
-- File: top.vhd
-- Entity: top
-- Architecture: STRUCT
-- Author: Qutaiba Saleh
-- Created: 4/28/15
-- Modified: 5/6/15
-- VHDL'93
-- Description: top
----------------------------------------------------
--
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
--
entity top is 
  generic (
	s  : integer := 49; -- size of the input image
    n  : integer := 7;
    m  : integer := 4
    );
  port (
    clk        : in  std_logic;
    Label_in   : in  std_logic;
	Mode       : in std_logic_vector(1 downto 0); -- 00: Idle, 01: Reset, 10: Train, 11: Test
    pixels     : in  std_logic_vector(s*(m+n+1) downto 1);
    LFSR_init  : in  std_logic_vector(m+n downto 1);
	alpha      : in  std_logic_vector(m+n+1 downto 1);
	ready      : out std_logic;
	label_out  : out std_logic
    );
end top;
-- 
architecture STRUCT of top is
------------------------ STATE MACHINE COMPONENT ---------------------------------------------------
	component state_machine is 
	  generic (
		s  : integer -- size of the input image
		);
	  port (
		clk        : in  std_logic;
		Mode       : in std_logic_vector(1 downto 0); -- 00: Idle, 01: Reset, 10: Train, 11: Test
		ready      : out std_logic;
		reset_flag : out std_logic;
		train_flag : out std_logic;
		test_flag  : out std_logic
		);
	end component;
------------------------ LFSR COMPONENT ---------------------------------------------------
	component LFSR is 
	  generic (
		n  : integer;
		m  : integer
		);
	  port (
		clk        : in  std_logic;
		reset_flag : in  std_logic;
		
		LFSR_init  : in  std_logic_vector(m+n+1 downto 1);
		
		LFSR_out   : out std_logic_vector(m+n+1 downto 1)
		);
	end component;
------------------------ WEIGHT BLOCK COMPONENT ----------------------------------------------------
	component weight_block is 
	  generic (
		s  : integer;
		n  : integer;
		m  : integer
		);
	  port (
		clk        		 : in  std_logic;
		Label_in   		 : in  std_logic;
		reset_flag 		 : in  std_logic;
		train_flag 		 : in  std_logic;
		test_flag  		 : in  std_logic;
		
		LFSR_in    		 : in  std_logic_vector(m+n+1 downto 1);
		train_in   		 : in  std_logic_vector(m+n+1 downto 1);
		
		LFSR_out    	 : out std_logic_vector(m+n+1 downto 1);
		weight_train_out : out std_logic_vector(m+n+1 downto 1);
		weight_test_out  : out std_logic_vector(m+n+1 downto 1)
		);
	end component;
------------------------ WEIGHT UPDATE BLOCK COMPONENT ---------------------------------------------
	component weight_update_block is 
	  generic (
		s  : integer;
		n  : integer;
		m  : integer
		);
	  port (
		clk 		     : in std_logic;
		Label_in         : in  std_logic;
		train_flag       : in  std_logic;
		
		pixel_in         : in  std_logic_vector(s*(m+n+1) downto 1);
		weight_in_male   : in  std_logic_vector(s*(m+n+1) downto 1);
		weight_in_female : in  std_logic_vector(s*(m+n+1) downto 1);
		alpha            : in  std_logic_vector(m+n+1 downto 1);
		
		male_weight_out       : out std_logic_vector(s*(m+n+1) downto 1);
		female_weight_out       : out std_logic_vector(s*(m+n+1) downto 1)
		);
	end component;
------------------------ OUTPUT EVALUATE BLOCK COMPONENT --------------------------------------------
	component output_evaluate_block is 
	  generic (
		s  : integer;
		n  : integer;
		m  : integer
		);
	  port (
		test_flag     : in  std_logic;
		network_flag  : in  std_logic;
		pixel_in      : in  std_logic_vector(s*(m+n+1) downto 1);
		weight_male   : in  std_logic_vector(s*(m+n+1) downto 1);
		weight_female : in  std_logic_vector(s*(m+n+1) downto 1);
		value_out     : out std_logic_vector(m+n+1 downto 1)
		);
	end component;
------------------------ NETWORK SELECT COMPONENT -----------------------------------------------------
	component network_sel is 
	  generic (
		n  : integer;
		m  : integer
		--s  : integer;
		--l  : integer
		);
	  port (
		clk           : in  std_logic;
		test_flag     : in  std_logic;
		--pixel_in      : in  std_logic_vector(m+n+1 downto 1);
		netowrk_flag  : out std_logic
		);
	end component;
------------------------ COMPARATOR COMPONENT -------------------------------------------------------
	component comparator is 
	  generic (
		n  : integer;
		m  : integer
		);
	  port (
		clk          : in  std_logic;
		network_flag : in  std_logic;
		value_in     : in  std_logic_vector(m+n+1 downto 1);
		value_out    : out std_logic:='0'
		);
	end component;
------------------------ CONNECTION SIGNALS -----------------------------------------------------------
signal	s_reset_flag      : std_logic;
signal	s_train_flag      : std_logic;
signal	s_test_flag       : std_logic;
signal	s_not_Label_in    : std_logic;
signal	s_network_flag    : std_logic;

signal	s_LFSR_male       : std_logic_vector(m+n+1 downto 1);
signal	s_LFSR_female     : std_logic_vector(m+n+1 downto 1);
signal	s_LFSR_female_out : std_logic_vector(m+n+1 downto 1);
signal	s_ouput_eval      : std_logic_vector(m+n+1 downto 1);


signal	s_male_train_weight_in : std_logic_vector(s*(m+n+1) downto 1);
signal	s_female_train_weight_in : std_logic_vector(s*(m+n+1) downto 1);
signal	s_weight_test_out_male : std_logic_vector(s*(m+n+1) downto 1);
signal	s_weight_train_out_male : std_logic_vector(s*(m+n+1) downto 1);
signal	s_weight_test_out_female : std_logic_vector(s*(m+n+1) downto 1);
signal	s_weight_train_out_female : std_logic_vector(s*(m+n+1) downto 1);

-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
begin

s_not_Label_in <= not Label_in;

------------------------ STATE MACHINE MAP ------------------------------------------------------------
	state: state_machine 
		generic map(s => s)
		port map(
			clk        => clk,
			Mode       => Mode,
			ready      => ready,
			reset_flag => s_reset_flag,
			train_flag => s_train_flag,
			test_flag  => s_test_flag
		);
------------------------ LFSR MAP ---------------------------------------------------
	lfs: LFSR 
		generic map(m => m, n => n)
		port map(
			clk        => clk,
			reset_flag => s_reset_flag,
		
			LFSR_init  => LFSR_init,
		
			LFSR_out   => s_LFSR_male
		);
------------------------  WEIGHT BLOCK MAP -----------------------------------------------------
	male_weight: weight_block  
		generic map(s => s, m => m, n => n)
		port map(
			clk        => clk,
			Label_in   => Label_in,
			reset_flag => s_reset_flag,
			train_flag => s_train_flag,
			test_flag  => s_test_flag,
			
			LFSR_in    => s_LFSR_male,
			train_in   => s_male_train_weight_in,
			
			LFSR_out   => s_LFSR_female,
			weight_train_out => s_weight_train_out_male,
			weight_test_out => s_weight_test_out_male
		);
	-----------------------
	female_weight: weight_block  
		generic map(s => s, m => m, n => n)
		port map(
			clk        => clk,
			Label_in   => s_not_Label_in,
			reset_flag => s_reset_flag,
			train_flag => s_train_flag,
			test_flag  => s_test_flag,
			
			LFSR_in    => s_LFSR_female,
			train_in   => s_female_train_weight_in,
			
			LFSR_out   => s_LFSR_female_out,
			weight_train_out => s_weight_train_out_female,
			weight_test_out => s_weight_test_out_female
		);
------------------------ WEIGHT UPDATE BLOCK MAP ---------------------------------------------
	weight_update: weight_update_block
		generic map(s => s, m => m, n => n)
		port map(
			clk              => clk,
			Label_in         => Label_in,
			train_flag       => s_train_flag,

			pixel_in         => pixels,
			weight_in_male   => s_weight_train_out_male,
			weight_in_female => s_weight_train_out_female,
			alpha      	     => alpha,

			male_weight_out       => s_male_train_weight_in,
			female_weight_out       => s_female_train_weight_in
		);
------------------------ OUTPUT EVALUATE BLOCK MAP --------------------------------------------
	output_evaluate: output_evaluate_block
		generic map(s => s, m => m, n => n)
		port map(
			test_flag     => s_test_flag,
			network_flag  => s_network_flag,
			pixel_in      => pixels,
			weight_male   => s_weight_test_out_male,
			weight_female => s_weight_test_out_female,
			value_out     => s_ouput_eval
		);
------------------------ NETWORK SELECT MAP -----------------------------------------------------
	net_sel: network_sel 
		generic map(m => m, n => n)
		port map(
			clk           => clk,
			test_flag     => s_test_flag,
			--pixel_in      => pixels,
			netowrk_flag  => s_network_flag
		);
------------------------ COMPARATOR MAP -------------------------------------------------------
	comp: comparator 
		generic map(m => m, n => n)
		port map(
			clk          => clk,
			network_flag => s_network_flag,
			value_in     => s_ouput_eval,
			value_out    => label_out
		);
end architecture;