
-- Layer Controller Module --
------------------------------------------------------------------------------------------------------------------------------------------------------
-- Brief explanation of the module:

-- Layer Controller Module is composed of BRAM interfaces, convolution submodule, data receive/send logic and operation(convolution) control logic parts.
-- This module controls convolution computations of an input image and 2D convolution filter (3x3, 4x4, 5x5, 6x6, 7x7 and 8x8).
-- Convolution module computes vector multiplication of 8 input data - filter coefficient pairs and accumulates results. 
-- Maximum supported size of input image is 256x256 (65536) pixels. 

-- Input data is stored in 4 true dual port BRAMs each having 16384 address space size.
-- Filter coefficient data is stored in 1 true dual port BRAM having 64 address space size.
-- Result data is stored in simple port BRAM having 65536 address space size. 
-- Input data and filter coefficients are represented as 32-bit signed fixed point number, signed fixed<32,24> format.

-- Module BRAM structure:
    -- 4 true dual port BRAMs - Data BRAM1, Data BRAM2, Data BRAM3 and Data BRAM4 stores input data pairs sequentially. 
    -- Convolution module can read 8 input data (1 data batch) simultaneously under no memory collision condition.  
    -- Layer Controller Module has write access to Data BRAMS, Convolution Module has read access to Data BRAMS.
     
    -- 1 true dual port BRAM - Filter BRAM stores convolution filter coefficient data. 
    -- Layer Controller Module has write access to Filter BRAM, Convolution Module has read access to Filter BRAM.

    -- 1 simple port BRAM - Result BRAM stores convolution computation results.
    -- Layer Controller Module has read access to Result BRAM, Convolution Module has write access to Result BRAM.

-- Module functional summary:
    -- Processing commands of operations. CMD("001"): store input data, CMD("010"): store filter data, CMD("100"): start convolution, CMD("000"): data transfer.
    -- Writing input data to Data BRAMs.
    -- Writing filter coefficient data to Filter BRAM.
    -- Controlling Convolution Module.
    -- Reading convolution results from Result BRAM.
    -- Sending results. 

------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
     
entity layer_controller is
    generic (   DATA_WIDTH:     integer:=31                                             -- Input data and filter coefficient data width
            );
    port    (   CLK         :   in      std_logic;                                      -- Module clock signal
                RST         :   in      std_logic;                                      -- Module reset signal
                DIN         :   in      std_logic_vector((2*DATA_WIDTH+1) downto 0);    -- Data input interface  
                VALID       :   in      std_logic;                                      -- Data valid signal
                CMD         :   in      std_logic_vector(2 downto 0);                   -- Command signal 
                DOUT        :   out     std_logic_vector(DATA_WIDTH downto 0);          -- Data output interface 
                READY       :   out     std_logic                                       -- Data output ready signal
            );
attribute dont_touch : string;
attribute dont_touch of layer_controller: entity is "true";
end layer_controller;

architecture behavioral of layer_controller is

-- True Dual Port BRAM - 32-bits data width and 14-bits address width  -- 
component bram_32_14_tdpr is
    Port (
        clka:  in std_logic;
        ena:   in std_logic;
        wea:   in std_logic_vector(0 downto 0);
        addra: in std_logic_vector(13 downto 0);
        dina:  in std_logic_vector(31 downto 0);
        douta: out std_logic_vector(31 downto 0);
        clkb:  in std_logic;
        enb:   in std_logic;
        web:   in std_logic_vector(0 downto 0);
        addrb: in std_logic_vector(13 downto 0);
        dinb:  in std_logic_vector(31 downto 0);
        doutb: out std_logic_vector(31 downto 0)
    );
end component;
  
-- True Dual Port BRAM - 32-bits data width and 6-bits address width  --  
component bram_32_6_tdpr is
    port (
        clka:  in std_logic;
        ena:   in std_logic;
        wea:   in std_logic_vector(0 downto 0);
        addra: in std_logic_vector(5 downto 0);
        dina:  in std_logic_vector(31 downto 0);
        douta: out std_logic_vector(31 downto 0);
        clkb:  in std_logic;
        enb:   in std_logic;
        web:   in std_logic_vector(0 downto 0);
        addrb: in std_logic_vector(5 downto 0);
        dinb:  in std_logic_vector(31 downto 0);
        doutb: out std_logic_vector(31 downto 0)
    );
end component;

-- Simple Port BRAM - 32-bits data width and 16-bits address width  --
component bram_32_16_spr is
    port (
        clka:   in std_logic;
        ena:    in std_logic;
        wea:    in std_logic_vector(0 downto 0);
        addra:  in std_logic_vector(15 downto 0);
        dina:   in std_logic_vector(31 downto 0);
        douta:  out std_logic_vector(31 downto 0)
    );
end component;

-- Convolution Module --
component convolution is
    generic(DATA_WIDTH:     integer:=31
    );
    port (  
        clk:                in std_logic;
        rst:                in std_logic; 
        cnv_start:          in std_logic;
        cnv_prms :          in std_logic_vector (29 downto 0); 
        cnv_completed:      out std_logic;   
        
        data_bram_en:       out std_logic_vector(7 downto 0); 
        data_bram_we:       out std_logic_vector(7 downto 0); 
        
        bram1_addra:        out std_logic_vector(13 downto 0);
        bram1_douta:        in  std_logic_vector(31 downto 0); 
        bram1_addrb:        out std_logic_vector(13 downto 0);
        bram1_doutb:        in  std_logic_vector(31 downto 0);
                    
        bram2_addra:        out std_logic_vector(13 downto 0);
        bram2_douta:        in  std_logic_vector(31 downto 0);
        bram2_addrb:        out std_logic_vector(13 downto 0);
        bram2_doutb:        in  std_logic_vector(31 downto 0);
        
        bram3_addra:        out std_logic_vector(13 downto 0);
        bram3_douta:        in  std_logic_vector(31 downto 0);
        bram3_addrb:        out std_logic_vector(13 downto 0);
        bram3_doutb:        in  std_logic_vector(31 downto 0);
        
        bram4_addra:        out std_logic_vector(13 downto 0);
        bram4_douta:        in  std_logic_vector(31 downto 0);
        bram4_addrb:        out std_logic_vector(13 downto 0);
        bram4_doutb:        in  std_logic_vector(31 downto 0);
        
        filt_bram_ena:      out std_logic;
        filt_bram_wea:      out std_logic_vector(0 downto 0);
        filt_bram_addra:    out std_logic_vector(5 downto 0);
        filt_bram_douta:    in  std_logic_vector(31 downto 0);
        filt_bram_enb:      out std_logic;
        filt_bram_web:      out std_logic_vector(0 downto 0);
        filt_bram_addrb:    out std_logic_vector(5 downto 0);
        filt_bram_doutb:    in  std_logic_vector(31 downto 0);
        
        bram_result_ena:    out std_logic;
        bram_result_wea:    out  std_logic_vector(0 downto 0);
        bram_result_addra:  out std_logic_vector(15 downto 0);
        bram_result_dina:   out std_logic_vector(31 downto 0) 
    );
end component;

-- Data registering and command receive
signal data_in :                std_logic_vector((2*DATA_WIDTH+1) downto 0);
signal wr_in_data:              std_logic:='0';
signal wr_filter_data:          std_logic:='0';
signal cmd_ready:               std_logic:='0';

-- Convolution start / convolution control 
signal cnv_prms:                std_logic_vector(29 downto 0); 
signal start_cnv_op:            std_logic:='0';
signal cnv_completed:           std_logic:='0';
signal cnv_start:               std_logic:='0';
signal cnt_state:               std_logic:='0';
signal cnv_clk:                 std_logic:='0';
signal cnv_rst:                 std_logic:='0';

-- Data BRAM1 signals
signal bram1_clka:              std_logic;
signal bram1_ena:               std_logic;
signal bram1_wea:               std_logic_vector(0 downto 0);
signal bram1_addra:             std_logic_vector(13 downto 0);
signal bram1_dina:              std_logic_vector(31 downto 0);
signal bram1_douta:             std_logic_vector(31 downto 0);
signal bram1_clkb:              std_logic;
signal bram1_enb:               std_logic;
signal bram1_web:               std_logic_vector(0 downto 0);
signal bram1_addrb:             std_logic_vector(13 downto 0);
signal bram1_dinb:              std_logic_vector(31 downto 0);
signal bram1_doutb:             std_logic_vector(31 downto 0);

-- Data BRAM2 signals
signal bram2_clka:              std_logic;
signal bram2_ena:               std_logic;
signal bram2_wea:               std_logic_vector(0 downto 0);
signal bram2_addra:             std_logic_vector(13 downto 0);
signal bram2_dina:              std_logic_vector(31 downto 0);
signal bram2_douta:             std_logic_vector(31 downto 0);
signal bram2_clkb:              std_logic;
signal bram2_enb:               std_logic;
signal bram2_web:               std_logic_vector(0 downto 0);
signal bram2_addrb:             std_logic_vector(13 downto 0);
signal bram2_dinb:              std_logic_vector(31 downto 0);
signal bram2_doutb:             std_logic_vector(31 downto 0);

-- Data BRAM3 signals
signal bram3_clka:              std_logic;
signal bram3_ena:               std_logic;
signal bram3_wea:               std_logic_vector(0 downto 0);
signal bram3_addra:             std_logic_vector(13 downto 0);
signal bram3_dina:              std_logic_vector(31 downto 0);
signal bram3_douta:             std_logic_vector(31 downto 0);
signal bram3_clkb:              std_logic;
signal bram3_enb:               std_logic;
signal bram3_web:               std_logic_vector(0 downto 0);
signal bram3_addrb:             std_logic_vector(13 downto 0);
signal bram3_dinb:              std_logic_vector(31 downto 0);
signal bram3_doutb:             std_logic_vector(31 downto 0);

-- Data BRAM4 signals
signal bram4_clka:              std_logic;
signal bram4_ena:               std_logic;
signal bram4_wea:               std_logic_vector(0 downto 0);
signal bram4_addra:             std_logic_vector(13 downto 0);
signal bram4_dina:              std_logic_vector(31 downto 0);
signal bram4_douta:             std_logic_vector(31 downto 0);
signal bram4_clkb:              std_logic;
signal bram4_enb:               std_logic;
signal bram4_web:               std_logic_vector(0 downto 0);
signal bram4_addrb:             std_logic_vector(13 downto 0);
signal bram4_dinb:              std_logic_vector(31 downto 0);
signal bram4_doutb:             std_logic_vector(31 downto 0);

-- Data BRAM enable / write enable signal switch
signal bram_switch:             std_logic:='0';
signal cnv_bram_en:             std_logic_vector(7 downto 0); 
signal cnv_bram_we:             std_logic_vector(7 downto 0);
signal lyr_bram_en:             std_logic_vector(7 downto 0);
signal lyr_bram_we:             std_logic_vector(7 downto 0);

-- Data BRAM address port switch
type bram_addr_array is array(0 to 7) of std_logic_vector(13 downto 0);
signal cnv_bram_addr:           bram_addr_array;
signal lyr_bram_addr:           bram_addr_array;

-- Data BRAMs write input data 
type bram_state is (BRAM1,BRAM2,BRAM3,BRAM4);
signal d_wr_state:              bram_state:=BRAM1;  

-- Data BRAMs write data counters
signal bram1_count1:            integer range 0 to 8191:=0;
signal bram1_count2:            integer range 0 to 8191:=0;
signal bram2_count1:            integer range 0 to 8191:=0;
signal bram2_count2:            integer range 0 to 8191:=0;
signal bram3_count1:            integer range 0 to 8191:=0;
signal bram3_count2:            integer range 0 to 8191:=0;
signal bram4_count1:            integer range 0 to 8191:=0;
signal bram4_count2:            integer range 0 to 8191:=0;

-- Filter BRAM signals
signal bram_filter_clka:        std_logic;
signal bram_filter_ena:         std_logic;
signal bram_filter_wea:         std_logic_vector(0 downto 0);
signal bram_filter_addra:       std_logic_vector(5 downto 0);
signal bram_filter_dina:        std_logic_vector(31 downto 0);
signal bram_filter_douta:       std_logic_vector(31 downto 0);
signal bram_filter_clkb:        std_logic;
signal bram_filter_enb:         std_logic;
signal bram_filter_web:         std_logic_vector(0 downto 0);
signal bram_filter_addrb:       std_logic_vector(5 downto 0);
signal bram_filter_dinb:        std_logic_vector(31 downto 0);
signal bram_filter_doutb:       std_logic_vector(31 downto 0);

-- Filter BRAM enable / write enable signals switch
signal cnv_filt_bram_ena:       std_logic;
signal cnv_filt_bram_enb:       std_logic;
signal cnv_filt_bram_wea:       std_logic_vector(0 downto 0);
signal cnv_filt_bram_web:       std_logic_vector(0 downto 0);
signal lyr_filt_bram_ena:       std_logic;
signal lyr_filt_bram_enb:       std_logic;
signal lyr_filt_bram_wea:       std_logic;
signal lyr_filt_bram_web:       std_logic;

-- Filter BRAM address port switch
signal cnv_filt_bram_addra:     std_logic_vector(5 downto 0);
signal cnv_filt_bram_addrb:     std_logic_vector(5 downto 0);
signal lyr_filt_bram_addra:     std_logic_vector(5 downto 0);
signal lyr_filt_bram_addrb:     std_logic_vector(5 downto 0);

-- Filter BRAM write data counters
signal bram_count1:             integer range 0 to 31:=0;
signal bram_count2:             integer range 0 to 31:=0;

-- Result BRAM signals
signal bram_result_clka:        std_logic;
signal bram_result_ena:         std_logic;
signal bram_result_wea:         std_logic_vector(0 downto 0);
signal bram_result_addra:       std_logic_vector(15 downto 0);
signal bram_result_dina:        std_logic_vector(31 downto 0);
signal bram_result_douta:       std_logic_vector(31 downto 0);

-- Result BRAM enable / write enable signals switch
signal cnv_rslt_bram_ena:       std_logic;
signal cnv_rslt_bram_wea:       std_logic_vector(0 downto 0);
signal lyr_rslt_bram_ena:       std_logic;
signal lyr_rslt_bram_wea:       std_logic;

-- Result BRAM address port switch
signal cnv_rslt_bram_addra:     std_logic_vector(15 downto 0);
signal lyr_rslt_bram_addra:     std_logic_vector(15 downto 0);

-- Read convolution results
signal read_result:             std_logic:='0';
signal read_state:              std_logic:='0';

-- Send results           
signal read_data:               std_logic:='0';
signal rd_count:                integer range 0 to 65535:=0;
signal out_size:                integer range 0 to 65535:=0;


begin


-- Data BRAM1 storing input data -- 
bram1_i: bram_32_14_tdpr port map (
                                    clka => bram1_clka,
                                    ena  => bram1_ena,
                                    wea  => bram1_wea,
                                    addra=> bram1_addra,
                                    dina => bram1_dina,
                                    douta=> bram1_douta,
                                    clkb => bram1_clkb,
                                    enb  => bram1_enb,
                                    web  => bram1_web,
                                    addrb=> bram1_addrb,
                                    dinb => bram1_dinb,
                                    doutb=> bram1_doutb
                                    );
                                    
-- Data BRAM2 storing input data --                                     
bram2_i: bram_32_14_tdpr port map (
                                    clka => bram2_clka,
                                    ena  => bram2_ena,
                                    wea  => bram2_wea,
                                    addra=> bram2_addra,
                                    dina => bram2_dina,
                                    douta=> bram2_douta,
                                    clkb => bram2_clkb,
                                    enb  => bram2_enb,
                                    web  => bram2_web,
                                    addrb=> bram2_addrb,
                                    dinb => bram2_dinb,
                                    doutb=> bram2_doutb
                                    );

-- Data BRAM3 storing input data --                               
bram3_i: bram_32_14_tdpr port map (
                                    clka => bram3_clka,
                                    ena  => bram3_ena,
                                    wea  => bram3_wea,
                                    addra=> bram3_addra,
                                    dina => bram3_dina,
                                    douta=> bram3_douta,
                                    clkb => bram3_clkb,
                                    enb  => bram3_enb,
                                    web  => bram3_web,
                                    addrb=> bram3_addrb,
                                    dinb => bram3_dinb,
                                    doutb=> bram3_doutb
                                    );
                               
-- Data BRAM4 storing input data --                                     
bram4_i: bram_32_14_tdpr port map (
                                    clka => bram4_clka,
                                    ena  => bram4_ena,
                                    wea  => bram4_wea,
                                    addra=> bram4_addra,
                                    dina => bram4_dina,
                                    douta=> bram4_douta,
                                    clkb => bram4_clkb,
                                    enb  => bram4_enb,
                                    web  => bram4_web,
                                    addrb=> bram4_addrb,
                                    dinb => bram4_dinb,
                                    doutb=> bram4_doutb
                                    );
                                    
-- Data BRAMs clock signals                                    
bram1_clka  <=  CLK; 
bram1_clkb  <=  CLK; 
bram2_clka  <=  CLK;
bram2_clkb  <=  CLK;
bram3_clka  <=  CLK;
bram3_clkb  <=  CLK;
bram4_clka  <=  CLK;
bram4_clkb  <=  CLK;
---------------------------

-- Filter BRAM storing filter coefficients --                                    
bram_filter_i: bram_32_6_tdpr port map (
                                    clka => bram_filter_clka,
                                    ena  => bram_filter_ena,
                                    wea  => bram_filter_wea,
                                    addra=> bram_filter_addra,
                                    dina => bram_filter_dina,
                                    douta=> bram_filter_douta,
                                    clkb => bram_filter_clkb,
                                    enb  => bram_filter_enb,
                                    web  => bram_filter_web,
                                    addrb=> bram_filter_addrb,
                                    dinb => bram_filter_dinb,
                                    doutb=> bram_filter_doutb 
                                    );
                                    
-- Filter BRAMs clock signals
bram_filter_clka <= CLK;
bram_filter_clkb <= CLK;
-----------------------------

-- BRAM storing computation result --                                    
bram_result_i: bram_32_16_spr port map (
                                    clka => bram_result_clka,
                                    ena  => bram_result_ena,
                                    wea  => bram_result_wea,
                                    addra=> bram_result_addra,
                                    dina => bram_result_dina,
                                    douta=> bram_result_douta
                                    );

-- Result BRAM clock signal
bram_result_clka <= CLK;
---------------------------

-- Convolution module --
convolution_i: convolution  generic map (31)
                            port map (  
                                    clk         => cnv_clk,
                                    rst         => cnv_rst,
                                    cnv_start   => cnv_start,
                                    cnv_prms    => cnv_prms, 
                                    
                                    cnv_completed => cnv_completed,
                                    
                                    data_bram_en => cnv_bram_en,
                                    data_bram_we => cnv_bram_we,
                                    
                                    bram1_addra => cnv_bram_addr(0),
                                    bram1_douta => bram1_douta, 
                                    bram1_addrb => cnv_bram_addr(1),
                                    bram1_doutb => bram1_doutb,
                                                
                                    bram2_addra => cnv_bram_addr(2),
                                    bram2_douta => bram2_douta,
                                    bram2_addrb => cnv_bram_addr(3),
                                    bram2_doutb => bram2_doutb,
                                    
                                    bram3_addra => cnv_bram_addr(4),
                                    bram3_douta => bram3_douta,
                                    bram3_addrb => cnv_bram_addr(5),
                                    bram3_doutb => bram3_doutb,
                                    
                                    bram4_addra => cnv_bram_addr(6),
                                    bram4_douta => bram4_douta,
                                    bram4_addrb => cnv_bram_addr(7),
                                    bram4_doutb => bram4_doutb,
                                    
                                    filt_bram_ena   => cnv_filt_bram_ena,
                                    filt_bram_wea   => cnv_filt_bram_wea,
                                    filt_bram_addra => cnv_filt_bram_addra,
                                    filt_bram_douta => bram_filter_douta,
                                    filt_bram_enb   => cnv_filt_bram_enb,
                                    filt_bram_web   => cnv_filt_bram_web,
                                    filt_bram_addrb => cnv_filt_bram_addrb,
                                    filt_bram_doutb => bram_filter_doutb,
                                    
                                    bram_result_ena     => cnv_rslt_bram_ena,
                                    bram_result_wea     => cnv_rslt_bram_wea,
                                    bram_result_addra   => cnv_rslt_bram_addra,
                                    bram_result_dina    => bram_result_dina
                                    );
                                    
-------------------------------------------------------                             
cnv_clk     <=  CLK; -- Convolution module clock signal
cnv_rst     <=  RST; -- Convolution module reset signal
-------------------------------------------------------

-- Data BRAM enable signal switching for layer controller module and convolution module accesses
bram1_ena           <=  cnv_bram_en(0)          when bram_switch = '1' else
                        lyr_bram_en(0);
             
bram1_enb           <=  cnv_bram_en(1)          when bram_switch = '1' else
                        lyr_bram_en(1);
             
bram2_ena           <=  cnv_bram_en(2)          when bram_switch = '1' else
                        lyr_bram_en(2);
             
bram2_enb           <=  cnv_bram_en(3)          when bram_switch = '1' else
                        lyr_bram_en(3);
             
bram3_ena           <=  cnv_bram_en(4)          when bram_switch = '1' else
                        lyr_bram_en(4);
             
bram3_enb           <=  cnv_bram_en(5)          when bram_switch = '1' else
                        lyr_bram_en(5);
             
bram4_ena           <=  cnv_bram_en(6)          when bram_switch = '1' else
                        lyr_bram_en(6);
             
bram4_enb           <=  cnv_bram_en(7)          when bram_switch = '1' else
                        lyr_bram_en(7);
-----------------------------------------------------------

-- Data BRAM write enable signal switching for layer controller module and convolution module accesses
bram1_wea(0)        <=  cnv_bram_we(0)          when bram_switch = '1' else
                        lyr_bram_we(0);
                
bram1_web(0)        <=  cnv_bram_we(1)          when bram_switch = '1' else
                        lyr_bram_we(1);
                
bram2_wea(0)        <=  cnv_bram_we(2)          when bram_switch = '1' else
                        lyr_bram_we(2);
                
bram2_web(0)        <=  cnv_bram_we(3)          when bram_switch = '1' else
                        lyr_bram_we(3);
                
bram3_wea(0)        <=  cnv_bram_we(4)          when bram_switch = '1' else
                        lyr_bram_we(4);
                
bram3_web(0)        <=  cnv_bram_we(5)          when bram_switch = '1' else
                        lyr_bram_we(5);
                
bram4_wea(0)        <=  cnv_bram_we(6)          when bram_switch = '1' else
                        lyr_bram_we(6);
                
bram4_web(0)        <=  cnv_bram_we(7)          when bram_switch = '1' else
                        lyr_bram_we(7);
---------------------------------------------------------------

-- Data BRAM address switching for layer controller module and convolution module accesses
bram1_addra         <=  cnv_bram_addr(0)        when bram_switch = '1' else
                        lyr_bram_addr(0);
             
bram1_addrb         <=  cnv_bram_addr(1)        when bram_switch = '1' else
                        lyr_bram_addr(1);
             
bram2_addra         <=  cnv_bram_addr(2)        when bram_switch = '1' else
                        lyr_bram_addr(2);
             
bram2_addrb         <=  cnv_bram_addr(3)        when bram_switch = '1' else
                        lyr_bram_addr(3);
                
bram3_addra         <=  cnv_bram_addr(4)        when bram_switch = '1' else
                        lyr_bram_addr(4);
             
bram3_addrb         <=  cnv_bram_addr(5)        when bram_switch = '1' else
                        lyr_bram_addr(5);
             
bram4_addra         <=  cnv_bram_addr(6)        when bram_switch = '1' else
                        lyr_bram_addr(6);
             
bram4_addrb         <=  cnv_bram_addr(7)        when bram_switch = '1' else
                        lyr_bram_addr(7);
----------------------------------------------------------------

-- Filter BRAM enable signal switching for layer controller module and convolution module accesses
bram_filter_ena     <=  cnv_filt_bram_ena       when bram_switch = '1' else
                        lyr_filt_bram_ena;
                    
bram_filter_enb     <=  cnv_filt_bram_enb       when bram_switch = '1' else
                        lyr_filt_bram_enb;
---------------------------------------------------------------------                
                    
-- Filter BRAM write enable signal switching for layer controller module and convolution module accesses
bram_filter_wea(0)  <=  cnv_filt_bram_wea(0)    when bram_switch = '1' else
                        lyr_filt_bram_wea;
                    
bram_filter_web(0)  <=  cnv_filt_bram_web(0)    when bram_switch = '1' else
                        lyr_filt_bram_web;
----------------------------------------------------------------------------                
                        
-- Filter BRAM address switching for layer controller module and convolution module accesses
bram_filter_addra   <=  cnv_filt_bram_addra     when bram_switch = '1' else
                        lyr_filt_bram_addra;
                    
bram_filter_addrb   <=  cnv_filt_bram_addrb     when bram_switch = '1' else
                        lyr_filt_bram_addrb;
---------------------------------------------------------------------------

-- Result BRAM enable signal switching for layer controller module and convolution module accesses
bram_result_ena     <=  cnv_rslt_bram_ena       when bram_switch = '1' else
                        lyr_rslt_bram_ena;                 
---------------------------------------------------------------------                
                    
-- Result BRAM write enable signal switching for layer controller module and convolution module accesses
bram_result_wea(0)  <=  cnv_rslt_bram_wea(0)    when bram_switch = '1' else
                        lyr_rslt_bram_wea;                 
----------------------------------------------------------------------------                
                        
-- Result BRAM address switching for layer controller module and convolution module accesses
bram_result_addra   <=  cnv_rslt_bram_addra     when bram_switch = '1' else
                        lyr_rslt_bram_addra;
---------------------------------------------------------------------------


-- Data registering and command receive --
data_cmd_receive:process(CLK)
begin

    if rising_edge(CLK) then
    
        if (RST = '1') then
        
            wr_in_data      <= '0';
            wr_filter_data  <= '0';
            cmd_ready       <= '0';
            
        else
            
            if(VALID ='1') then -- data input valid
                data_in <= DIN;
                
                if(CMD = "001") then        -- write input data to BRAMs
                    wr_in_data      <= '1';
                    wr_filter_data  <= '0';
                    cmd_ready       <= '0';
                    
                elsif (CMD = "010") then    -- write filter data to BRAM
                    wr_in_data      <= '0';
                    wr_filter_data  <= '1';
                    cmd_ready       <= '0';
                    
                elsif (CMD = "100") then    -- start convolution
                    wr_in_data      <= '0';
                    wr_filter_data  <= '0';
                    cmd_ready       <= '1';
                    
                else
                    wr_in_data      <= '0';
                    wr_filter_data  <= '0';
                    cmd_ready       <= '0';
                    
                end if;
         
            end if;
         
        end if;
    end if;
end process data_cmd_receive;


-- Convolution start command -- 
cmd_fetch: process(CLK)
begin

    if rising_edge(CLK) then
    
        if (RST = '1') then
        
            start_cnv_op    <= '0';
            
        else
        
            if(cmd_ready = '1') then
                cnv_prms        <= data_in(29 downto 0);    -- register convolution parameters
                start_cnv_op    <= '1';                     -- start convolution
            else
                start_cnv_op    <= '0';
            end if;
        
        end if;       
    end if;     
end  process cmd_fetch;


-- Write input data --
bram_input_data_write:process(CLK)
begin

    if rising_edge(CLK) then
    
        if (RST = '1') then
        
            lyr_bram_en   <= "ZZZZZZZZ";
            lyr_bram_we   <= "ZZZZZZZZ";
            lyr_bram_addr <= (others=>(others=>'Z'));
            bram1_dina    <= (others=>'Z');
            bram2_dina    <= (others=>'Z');
            bram3_dina    <= (others=>'Z');
            bram4_dina    <= (others=>'Z');
            bram1_dinb    <= (others=>'Z');
            bram2_dinb    <= (others=>'Z');
            bram3_dinb    <= (others=>'Z');
            bram4_dinb    <= (others=>'Z');
            
            bram1_count1 <= 0;
            bram1_count2 <= 0;
            bram2_count1 <= 0;
            bram2_count2 <= 0;
            bram3_count1 <= 0;
            bram3_count2 <= 0;
            bram4_count1 <= 0;
            bram4_count2 <= 0;
            
            d_wr_state   <= BRAM1;
            
        else
        
            if(wr_in_data ='1') then
            
                -- Cyclic input data write; BRAM1, BRAM2, BRAM3, BRAM4, BRAM1, BRAM2, BRAM3, BRAM4, ...  
                case(d_wr_state) is
                
                    when BRAM1 =>           -- write data to BRAM1
                    
                        lyr_bram_addr(0)    <= std_logic_vector(to_unsigned(bram1_count1,bram1_addra'length));
                        bram1_dina          <= data_in(DATA_WIDTH downto 0);
                        bram1_count1        <= bram1_count1 + 1;
                        
                        lyr_bram_addr(1)    <= std_logic_vector(to_unsigned(bram1_count2,bram1_addrb'length));
                        bram1_dinb          <= data_in((2*DATA_WIDTH+1) downto (DATA_WIDTH+1));
                        bram1_count2        <= bram1_count2 + 1;
                        
                        d_wr_state          <= BRAM2;
                        
                        lyr_bram_en         <= "00000011";
                        lyr_bram_we         <= "00000011";
                        
                    when BRAM2 =>           -- write data to BRAM2
                    
                        lyr_bram_addr(2)    <= std_logic_vector(to_unsigned(bram2_count1,bram2_addra'length));
                        bram2_dina          <= data_in(DATA_WIDTH downto 0);
                        bram2_count1        <= bram2_count1 + 1;
                        
                        lyr_bram_addr(3)    <= std_logic_vector(to_unsigned(bram2_count2,bram2_addrb'length));
                        bram2_dinb          <= data_in((2*DATA_WIDTH+1) downto (DATA_WIDTH+1));
                        bram2_count2        <= bram2_count2 + 1;
                        
                        d_wr_state          <= BRAM3;
                        
                        lyr_bram_en         <= "00001100";
                        lyr_bram_we         <= "00001100";
                        
                    when BRAM3 =>           -- write data to BRAM3
                    
                        lyr_bram_addr(4)    <= std_logic_vector(to_unsigned(bram3_count1,bram3_addra'length));
                        bram3_dina          <= data_in(DATA_WIDTH downto 0);
                        bram3_count1        <= bram3_count1 + 1;
                        
                        lyr_bram_addr(5)    <= std_logic_vector(to_unsigned(bram3_count2,bram3_addrb'length));
                        bram3_dinb          <= data_in((2*DATA_WIDTH+1) downto (DATA_WIDTH+1));
                        bram3_count2        <= bram3_count2 + 1;
                        
                        d_wr_state          <= BRAM4;
                        
                        lyr_bram_en         <= "00110000";
                        lyr_bram_we         <= "00110000";
                       
                    when BRAM4 =>           -- write data to BRAM4
                    
                        lyr_bram_addr(6)    <= std_logic_vector(to_unsigned(bram4_count1,bram4_addra'length));
                        bram4_dina          <= data_in(DATA_WIDTH downto 0);
                        bram4_count1        <= bram4_count1 + 1;
                                            
                        lyr_bram_addr(7)    <= std_logic_vector(to_unsigned(bram4_count2,bram4_addrb'length));
                        bram4_dinb          <= data_in((2*DATA_WIDTH+1) downto (DATA_WIDTH+1));
                        bram4_count2        <= bram4_count2 + 1;
                        
                        d_wr_state          <= BRAM1;
                        
                        lyr_bram_en         <= "11000000";
                        lyr_bram_we         <= "11000000";
                        
                    when others => null;
                end case;
            
            else
            
                lyr_bram_en   <= "ZZZZZZZZ";
                lyr_bram_we   <= "ZZZZZZZZ";
                lyr_bram_addr <= (others=>(others=>'Z'));
                bram1_dina    <= (others=>'Z');
                bram2_dina    <= (others=>'Z');
                bram3_dina    <= (others=>'Z');
                bram4_dina    <= (others=>'Z');
                bram1_dinb    <= (others=>'Z');
                bram2_dinb    <= (others=>'Z');
                bram3_dinb    <= (others=>'Z');
                bram4_dinb    <= (others=>'Z');
                
                bram1_count1 <= 0;
                bram1_count2 <= 0;
                bram2_count1 <= 0;
                bram2_count2 <= 0;
                bram3_count1 <= 0;
                bram3_count2 <= 0;
                bram4_count1 <= 0;
                bram4_count2 <= 0;
                
                d_wr_state <= BRAM1;
            
            end if;
            
        end if;
    end if;
end process bram_input_data_write;


-- Write filter coefficient data --
bram_filter_data_write:process(CLK)
begin

    if rising_edge(CLK) then
    
        if (RST = '1') then
        
            lyr_filt_bram_ena   <= 'Z';
            lyr_filt_bram_wea   <= 'Z';
            lyr_filt_bram_enb   <= 'Z';
            lyr_filt_bram_web   <= 'Z';
            lyr_filt_bram_addra <= (others=>'Z');
            lyr_filt_bram_addrb <= (others=>'Z');
            bram_filter_dina    <= (others=>'Z');
            bram_filter_dinb    <= (others=>'Z');           
            
            bram_count1 <= 0;
            bram_count2 <= 0;
            
        else
        
            -- Write filter coefficients to dual port BRAM
            if(wr_filter_data ='1') then
            
                lyr_filt_bram_ena       <= '1';
                lyr_filt_bram_wea       <= '1';
                lyr_filt_bram_addra     <= std_logic_vector(to_unsigned(bram_count1,bram_filter_addra'length));
                bram_filter_dina        <= data_in(DATA_WIDTH downto 0);
                bram_count1             <= bram_count1 + 1;
                
                lyr_filt_bram_enb       <= '1';
                lyr_filt_bram_web       <= '1';
                lyr_filt_bram_addrb     <= std_logic_vector(to_unsigned(bram_count2,bram_filter_addrb'length));
                bram_filter_dinb        <= data_in((2*DATA_WIDTH+1) downto (DATA_WIDTH+1));
                bram_count2             <= bram_count2 + 1;
                        
                        
            
            else
                lyr_filt_bram_ena       <= 'Z';
                lyr_filt_bram_wea       <= 'Z';
                lyr_filt_bram_enb       <= 'Z';
                lyr_filt_bram_web       <= 'Z';
                lyr_filt_bram_addra     <= (others=>'Z');
                lyr_filt_bram_addrb     <= (others=>'Z');
                bram_filter_dina        <= (others=>'Z');
                bram_filter_dinb        <= (others=>'Z');
          
                bram_count1             <= 0;
                bram_count2             <= 0;
 
            end if;
            
        end if;
    end if; 
end process bram_filter_data_write;


-- Convolution module controller --
convolution_control: process(CLK)
begin

    if rising_edge(CLK) then
    
            if (RST = '1') then
            
                cnt_state   <= '0';
                cnv_start   <= '0';
                bram_switch <= '0';
                read_result <= '0';
                
            else
            
                case(cnt_state) is
                
                    when '0' =>
                    
                        -- Checking for convolution start command
                        if(start_cnv_op = '1') then
                            cnt_state   <= '1';
                            cnv_start   <= '1';
                        else
                            cnt_state   <= '0';
                            cnv_start   <= '0';
                        end if;
                        
                        bram_switch <= '0';         -- Switch BRAM ports to layer controller module
                        read_result <= '0';
                        
                        
                    when '1' =>
                    
                        cnv_start <= '0';
                        
                        -- Checking for convolution completed signal
                        if(cnv_completed = '1') then
                            cnt_state   <= '0';
                            read_result <= '1';     -- Start reading result data
                        else
                            cnt_state   <= '1';
                            read_result <= '0';
                        end if;
                        
                        bram_switch <= '1';         -- Switch BRAM ports to convolution module
                       
                    when others =>null;
                
                end case;
    
            end if;       
    end if;
end process convolution_control;


-- Read result of convolution --
read_results:process(CLK)
begin

    if rising_edge (CLK) then
    
        if (RST ='1') then
        
            read_state          <= '0'; 
            lyr_rslt_bram_ena   <= 'Z';
            lyr_rslt_bram_wea   <= 'Z';
            lyr_rslt_bram_addra <= (others=>'Z'); 
            read_data           <= '0';
            rd_count            <= 0; 
            out_size            <= 1;  
            
        else
        
            case (read_state) is
            
                when '0' =>
                
                    -- Checking for read start signal
                    if (read_result='1') then
                        read_state <= '1';
                        out_size   <= to_integer(unsigned(cnv_prms(29 downto 14))); -- Get output data size parameter 
                    else
                        read_state <= '0';
                    end if;
                    
                    lyr_rslt_bram_ena   <= 'Z';
                    lyr_rslt_bram_wea   <= 'Z';
                    lyr_rslt_bram_addra <= (others=>'Z');
                    
                    read_data           <= '0';
                    rd_count            <= 0;
                    
                
                when '1' =>
                
                    -- Checking for the end of data
                    if (rd_count = out_size) then
                        lyr_rslt_bram_ena   <= '0';
                        lyr_rslt_bram_wea   <= '0';
                        
                        read_state          <= '0';
                        read_data           <= '0';
                    else
                    
                        -- Read access to BRAM          
                        lyr_rslt_bram_ena   <= '1';
                        lyr_rslt_bram_wea   <= '0';
                        lyr_rslt_bram_addra <= std_logic_vector(to_unsigned(rd_count,lyr_rslt_bram_addra'length));

                        read_state          <= '1';
                        read_data           <= '1';     -- Read BRAM data port signal   
                    end if;
                    
                    rd_count <= rd_count + 1; 
                    
                when others => null;
            
            end case;
            
        end if;
        
    end if;
end process read_results;


-- Send result data --
send_data:process(CLK)
begin

    if rising_edge (CLK) then
    
        if (read_data = '1') then
        
            DOUT    <= bram_result_douta;   -- Direct data to data out port 
            READY   <= '1';                 -- Send data ready signal
        else
            DOUT    <= (others=>'Z');
            READY   <= '0';
        end if;
                       
    end if;
end process send_data;



end behavioral;
