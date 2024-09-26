
-- Convolution Module --
----------------------------------------------------------------------------
-- Brief explanation of the module:

-- Module computes convolutions for 
-- input images with maximum supported size of 256x256 = 65536 pixels and
-- 2D convolution filters having sizes of 3x3, 4x4, 5x5, 6x6, 7x7 and 8x8.

-- Module functional summary:
    -- Moving convolution filter over input data. 
    -- Handling memory collision and BRAM access. 
    -- Reading filter coefficents and input data as 8 data batches.
    -- Multiplying 8 input data by 8 filter coefficient data simultaneously.
    -- Accumulating multiplied data.
    -- Storing results in BRAM.
    
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  

entity convolution is
    generic (   DATA_WIDTH          :   integer:=31                             -- Input data/ Filter coefficient data width
            );
   	port    (   clk                 :   in std_logic;                           -- Module clock signal
                rst                 :   in std_logic;                           -- Module reset signal
                cnv_start           :   in std_logic;                           -- Module start signal
                cnv_prms            :   in std_logic_vector (29 downto 0);      -- Convolution calculation parameters
                cnv_completed       :   out std_logic;                          -- Convolution operation completed signal
      
                data_bram_en        :   out std_logic_vector(7 downto 0);       -- Data BRAM enable signals for 8 data (1 batch) access
                data_bram_we        :   out std_logic_vector(7 downto 0);       -- Filter BRAM write enable signals for 8 data (1 batch) access
         
                bram1_addra         :   out std_logic_vector(13 downto 0);      -- Data BRAM1 address / data ports A/B
                bram1_douta         :   in  std_logic_vector(31 downto 0);      --
                bram1_addrb         :   out std_logic_vector(13 downto 0);      --
                bram1_doutb         :   in  std_logic_vector(31 downto 0);      --
                            
                bram2_addra         :   out std_logic_vector(13 downto 0);      -- Data BRAM2 address / data ports A/B
                bram2_douta         :   in  std_logic_vector(31 downto 0);      --
                bram2_addrb         :   out std_logic_vector(13 downto 0);      --
                bram2_doutb         :   in  std_logic_vector(31 downto 0);      --
                
                bram3_addra         :   out std_logic_vector(13 downto 0);      -- Data BRAM3 address / data ports A/B
                bram3_douta         :   in  std_logic_vector(31 downto 0);      --
                bram3_addrb         :   out std_logic_vector(13 downto 0);      --
                bram3_doutb         :   in  std_logic_vector(31 downto 0);      --
                
                bram4_addra         :   out std_logic_vector(13 downto 0);      -- Data BRAM4 address / data ports A/B
                bram4_douta         :   in  std_logic_vector(31 downto 0);      --
                bram4_addrb         :   out std_logic_vector(13 downto 0);      --
                bram4_doutb         :   in  std_logic_vector(31 downto 0);      --
      
                filt_bram_ena       :   out std_logic;                          -- Filter BRAM portA enable signal
                filt_bram_wea       :   out std_logic_vector(0 downto 0);       -- Filter BRAM portA write enable signal
                filt_bram_addra     :   out std_logic_vector(5 downto 0);       -- Filter address portA
                filt_bram_douta     :   in  std_logic_vector(31 downto 0);      -- Filter data portA
                filt_bram_enb       :   out std_logic;                          -- Filter BRAM portB enable signal
                filt_bram_web       :   out std_logic_vector(0 downto 0);       -- Filter BRAM portB enable signal
                filt_bram_addrb     :   out std_logic_vector(5 downto 0);       -- Filter address portB
                filt_bram_doutb     :   in  std_logic_vector(31 downto 0);      -- Filter data portB
                
                bram_result_ena     :   out std_logic;                          -- Result BRAM enable signal
                bram_result_wea     :   out  std_logic_vector(0 downto 0);      -- Result BRAM write enable signal
                bram_result_addra   :   out std_logic_vector(15 downto 0);      -- Result BRAM address port
                bram_result_dina    :   out std_logic_vector(31 downto 0)       -- Result BRAM data port
            );
--            attribute clock_buffer_type         : string;                       -- Module input clock signal BUFG assignment
--            attribute clock_buffer_type of clk  : signal is "BUFG";
attribute dont_touch : string;
attribute dont_touch of convolution: entity is "true";
end convolution;

architecture behavioral of convolution is 

-- Module reset 
signal module_rst:              std_logic:='0';

-- Parameter_registers / Convolution start
signal inp_size:                integer range 0 to 255;
signal filt_type:               std_logic_vector(2 downto 0);
signal stride:                  integer range 0 to 7;
signal out_size:                integer range 0 to 65535;
signal op_start:                std_logic := '0';

-- Filter BRAM access
signal filt_rd_state:           std_logic:='0';
signal filt_d_ready:            std_logic:='0';
signal filt_count_1:            integer range 0 to 63:=0;
signal filt_count_2:            integer range 0 to 63:=1;

-- Storing filter coefficient data
type filter_array is array (0 to 63) of std_logic_vector(DATA_WIDTH downto 0);
signal filter_data:             filter_array;
signal rd_count_1:              integer range 0 to 63:=0;
signal rd_count_2:              integer range 0 to 63:=1;

-- Calculated convolution operation parameters
signal inp_bound:               integer range 0 to 65535;
signal batch_number:            integer range 0 to 56;
signal filt_size:               integer range 0 to 63;
signal filt_dim_size:           integer range 0 to 8;
signal collision:               std_logic := '0';
signal batch_cycle:             integer range 0 to 7;

-- Process control / Generated enable signals for the module processes
signal control_state:           std_logic:='0'; 
signal op_end:                  std_logic:='0';
signal stride_en:               std_logic:='0';
signal xy_coord_en:             std_logic:='0';
signal index_en:                std_logic:='0';
signal bram_prm_en:             std_logic:='0';
signal bram_map_en:             std_logic:='0';
signal batch_seq_en:            std_logic:='0';
signal bram_util_en:            std_logic:='0';
signal collision_detect_en:     std_logic:='0';
signal en_reg_1:                std_logic:='0';
signal en_reg_2:                std_logic:='0';
signal en_reg_3:                std_logic:='0';
signal en_reg_4:                std_logic:='0';
signal en_reg_5:                std_logic:='0';
signal en_reg_6:                std_logic:='0';
signal en_reg_7:                std_logic:='0';
signal en_reg_8:                std_logic:='0';
signal en_reg_9:                std_logic:='0';
signal bram_info_calc_en:       std_logic:='0';
signal bram_info_reg_en:        std_logic:='0';

-- Filter stride control and parameters
signal stride_count:            integer range 0 to 7:=0;
signal x_ptr,y_ptr:             integer range 0 to 65535:=0;

-- X-Y coordinates of input data
type coord_array is array(0 to 63, 0 to 1) of integer range 0 to 65535;
signal xy_coord:                coord_array;

-- Index value of input data (X-Y coordinates to index)
type index_array is array (0 to 63) of integer range 0 to 65535;
signal index:                   index_array;

-- Index modulus 8 value 
type mod_array is array (0 to 63) of integer range 0 to 7;
signal index_mod:               mod_array;

-- Index to bram map parameters
type odd_even_array is array (0 to 63) of integer range 0 to 1;
type bram_num_array is array (0 to 63) of integer range 0 to 4;
signal odd_even_prm:            odd_even_array;
signal index_bram_num:          bram_num_array;

-- Input data batch sequencing parameters 
type num_reg_array          is array (0 to 7) of unsigned(3 downto 0);
type bram_prm_array         is array (0 to 7) of integer range 0 to 16383;
type odd_even_batch_array   is array (0 to 7) of integer range 0 to 1;
signal bram_num_reg:            num_reg_array;
signal bram_addr_prm:           bram_prm_array;
signal odd_even_prm2:           odd_even_batch_array;
signal batch_count:             integer range 0 to 7:=0;

-- Data bram assignment registers
type bram_num_batch_array is array (0 to 7) of integer range 0 to 7;
type bram_addr_reg_array  is array (0 to 7) of integer range 0 to 16383;
signal bram_num_dec:            bram_num_batch_array;
signal bram_num_dec_l1:         bram_num_batch_array;
signal bram_num_dec_l2:         bram_num_batch_array;
signal bram_num_dec_l3:         bram_num_batch_array;
signal bram_num_dec_l4:         bram_num_batch_array;
signal bram_num_dec_l5:         bram_num_batch_array;
signal bram_num_dec_q:          bram_num_batch_array;
signal bram_addr_reg:           bram_addr_reg_array;
signal bram_addr_reg_l1:        bram_addr_reg_array;
signal bram_addr_reg_l2:        bram_addr_reg_array;
signal bram_addr_reg_l3:        bram_addr_reg_array;
signal bram_addr_reg_l4:        bram_addr_reg_array;
signal bram_addr_reg_l5:        bram_addr_reg_array;

-- Bram utilization info and registers
type util_sum_1_array   is array (0 to 3, 0 to 3) of unsigned(3 downto 0);
type util_sum_2_array   is array (0 to 3, 0 to 1) of unsigned(3 downto 0);
type util_num_array     is array (0 to 3) of integer range 0 to 8;
type util_queue_array   is array (0 to 3, 0 to 7) of integer range 0 to 7;
signal sum_pairs_l1:            util_sum_1_array;
signal sum_pairs_l2:            util_sum_2_array;
signal bram_util_num_l1:        util_num_array;
signal bram_util_num_l2:        util_num_array;
signal bram_util_num:           util_num_array;
signal util_queue_l1:           util_queue_array;
signal util_queue_l2:           util_queue_array;
signal util_queue_l3:           util_queue_array;
signal util_queue_l4:           util_queue_array;
signal util_queue:              util_queue_array;

-- Collision detection
signal collision_detected:      std_logic:='0';
signal max_util_num_1:          integer range 0 to 8;
signal max_util_num_2:          integer range 0 to 8;
signal max_util_num:            integer range 0 to 8;

-- Computation controller
signal collision_count:         integer range 0 to 15:=0;
signal comp_cnt_en:             std_logic:='0';
signal cnt_state:               std_logic:='0';
signal process_register:        std_logic:='0';
signal max_util_num_reg:        integer range 0 to 8;
signal util_queue_reg:          util_queue_array;
signal bram_util_num_reg:       util_num_array;
signal handler_state:           std_logic:='0';
signal mem_handler_en:          std_logic:='0';
signal bram_info_cnt_en:        std_logic:='0';
signal acc_cnt:                 std_logic:='0';
signal bram_addr_en:            std_logic:='0';

-- Memory access handler
type collision_num_array is array (0 to 3) of integer range 0 to 7;
type end_ind_array is array (0 to 3) of integer range 0 to 7;
signal collision_num:           collision_num_array;
signal q_end_0:                 end_ind_array;
signal q_end_1:                 end_ind_array;
signal data_reg_active:         std_logic_vector(7 downto 0);
signal data_reg_active_q:       std_logic_vector(7 downto 0);
signal util_q_updated:          util_queue_array;
signal bram_access_en:          std_logic:='0';

-- BRAM data ports
type bram_data_std_array is array (0 to 7) of std_logic_vector(31 downto 0);
signal data_bram_d:             bram_data_std_array;

-- BRAM address ports
type bram_addr_array is array (0 to 7) of std_logic_vector(13 downto 0);
signal data_bram_addr:          bram_addr_array;

-- Data Bram access/read
type bram_data_signed_array is array (0 to 7) of signed(31 downto 0);
signal data_bram_reg:           bram_data_signed_array; 
signal read_data_bram:          std_logic:='0';

-- Enable signal registers for accumulation controller and filter coefficient batch sequencer
signal acc_control_en:          std_logic:='0';
signal filter_seq_en:           std_logic:='0';
signal acc_cnt_l1:              std_logic:='0';
signal acc_cnt_l2:              std_logic:='0';
signal acc_cnt_l3:              std_logic:='0';
signal acc_cnt_l4:              std_logic:='0';
signal acc_cnt_l5:              std_logic:='0';
signal acc_collision_cnt:       std_logic:='0';
signal acc_collision_cnt_l1:    std_logic:='0';
signal acc_collision_cnt_l2:    std_logic:='0';
signal acc_collision_cnt_l3:    std_logic:='0';
signal acc_collision_cnt_l4:    std_logic:='0';

-- Filter data sequencer
signal filter_bram_reg:         bram_data_signed_array;
signal filter_count:            integer range 0 to 63 := 0;

-- Multiplication vector 8x
type mult_data_signed_array is array (0 to 7) of signed(63 downto 0);
signal mult_vector:             mult_data_signed_array;

-- Fixed point representation constants for 32-bit signed sfixed<32,24> 
constant  fixed_ptr:            integer range 0 to 31:=24; -- position of the 32-bits fixed point number fractional part
constant  upper_bit:            integer range 0 to 63:=55; -- position of the upper bit of multiplication data
constant  lower_bit:            integer range 0 to 31:=24; -- position of the lower bit of multiplication data 

-- Accumulation vectors and registers
type sum_1_signed_array is array (0 to 3) of signed(31 downto 0);
type sum_2_signed_array is array (0 to 1) of signed(31 downto 0);
signal batch_sum_l1:            sum_1_signed_array; 
signal batch_sum_l2:            sum_2_signed_array; 
signal batch_sum:               signed(31 downto 0);
signal batch_sum_reg:           signed(31 downto 0);

-- Accumulation controller
signal batch_acc_cmd:           std_logic_vector(1 downto 0) := "00";
signal acc_batch_count:         integer range 0 to 7 := 0;

-- Store results / Write access to Bram
signal wr_count:                integer range 0 to 65535:=0;
signal acc_data_ready:          std_logic:='0';
signal wr_bram_data:            std_logic:='0';

-- Attributes
--attribute use_dsp48 : string;
--attribute use_dsp48 of mult_vector : signal is "yes";

--attribute dont_touch : string;
--attribute dont_touch of clk: signal is "true";

begin

-- Module reset generation.
module_reset: process(clk)
begin

     if rising_edge (clk) then
     
        if (rst = '1') then
            module_rst <= '1';
        else
            module_rst <= '0';
        end if;
        
     end if;
end process module_reset;


-- Storing parameters of convolution computation / Starting convolution.
parameter_register: process(clk)
begin

     if rising_edge (clk) then
     
        if (rst = '1') then
            inp_size 	<= 0;    
            filt_type   <= (others=>'0');   
            stride 		<= 0;
            out_size    <= 0;
            op_start    <= '0';
        
        else
            if (cnv_start = '1') then   
                
                -- Register Parameters  
                inp_size 		<=  To_Integer ( unsigned (cnv_prms (7 downto 0)) );    -- Input Size:  Input  row/column size 0 to 256.  
                filt_type   	<=  cnv_prms (10 downto 8);                             -- Filter Size: Filter row/column size 0 to 8. 
                stride 		    <=  To_Integer ( unsigned (cnv_prms (13 downto 11)) );  -- Stride Size: Step size of striding. Supporting 0 to 7 step sizes.  
                out_size        <=  To_Integer ( unsigned (cnv_prms (29 downto 14)) );  -- Output Data Size: Number of output data. Maximum size is 65535.
                 
                op_start        <= '1'; -- Operation start signal
            
            else
                inp_size 		<=  inp_size;    
                filt_type   	<=  filt_type;   
                stride 		    <=  stride;
                out_size        <=  out_size;  
                
                op_start        <= '0';
            
            end if;    
        end if;    
     end if;
end process parameter_register;


-- Accessing true dual port BRAM to read convolution filter coefficients.
read_filter_data: process(clk)
begin

     if rising_edge (clk) then
     
        if (rst = '1') then
            
            filt_rd_state <= '0';
            
            filt_bram_ena   <= 'Z';
            filt_bram_wea   <= "Z";
            filt_bram_addra <= "ZZZZZZ";
            
            filt_bram_enb   <= 'Z';
            filt_bram_web   <= "Z";
            filt_bram_addrb <= "ZZZZZZ";
            
            filt_count_1    <= 0;
            filt_count_2    <= 1;
            
            filt_d_ready    <= '0';
            
        else
            case(filt_rd_state) is
            
                when '0' =>
                
                    -- Checking for convolution operation start signal
                    if (op_start = '1') then 
                        filt_rd_state <= '1';
                    else
                        filt_rd_state <= '0';
                    end if;
                    
                    filt_bram_ena   <= 'Z';
                    filt_bram_wea   <= "Z";
                    filt_bram_addra <= "ZZZZZZ";
                    
                    filt_bram_enb   <= 'Z';
                    filt_bram_web   <= "Z";
                    filt_bram_addrb <= "ZZZZZZ";
                    
                    filt_count_1    <= 0;
                    filt_count_2    <= 1;
                    
                    filt_d_ready    <= '0';
                
                when '1' =>
                
                    -- Checking for the end of filter data
                    if (filt_count_2 = filt_size) then 
                        filt_rd_state <= '0';
                    else
                        filt_rd_state <= '1';
                    end if;
                
                    -- Read access to Filter BRAM
                    filt_bram_ena   <= '1';
                    filt_bram_wea   <= "0";
                    filt_bram_addra <= std_logic_vector(to_unsigned(filt_count_1,filt_bram_addra'length));
                    
                    filt_count_1    <= filt_count_1 + 2;
                    
                    filt_bram_enb   <= '1';
                    filt_bram_web   <= "0";
                    filt_bram_addrb <= std_logic_vector(to_unsigned(filt_count_2,filt_bram_addrb'length));
                    
                    filt_count_2    <= filt_count_2 + 2;
                    
                    filt_d_ready    <= '1';     -- Read BRAM port
                
                when others => null;
                
            end case;  
        end if;    
     end if;
end process read_filter_data;


-- Storing filter coefficient data
store_filter_data: process(clk) 
begin

     if rising_edge (clk) then
     
        if (rst = '1') then
            
            rd_count_1  <=  0;
            rd_count_2  <=  1;
            
        else
            if (filt_d_ready = '1') then   
            
                -- Registering filter coefficients 
                filter_data(rd_count_1)     <= filt_bram_douta;
                rd_count_1                  <= rd_count_1 + 2;
                    
                filter_data(rd_count_2)     <= filt_bram_doutb;
                rd_count_2                  <= rd_count_2 + 2;
                
            else    
                rd_count_1                  <=  0;
                rd_count_2                  <=  1;
                
            end if;   
         end if;
     end if;
end process store_filter_data;


-- Calculating required parameters for convolution operations such as filter striding control and computation batch numbers.
-- Parameters are calculated for 3x3, 4x4, 5x5, 6x6 ,7x7 and 8x8 convolution filters.  
calculate_parameters: process(clk)
begin

     if rising_edge (clk) then
     
        if (op_start = '1') then 
            
            -- Each case includes computations for 3x3, 4x4, 5x5, 6x6, 7x7 or 8x8 filters
            case(filt_type) is
 
                when "000" =>   -- 3x3 Filter
                    inp_bound       <= inp_size - 3;    -- boundry for filter stride position 
                    batch_number    <= 8;               -- indicates number of data batches at one stride position of the filter
                    filt_size       <= 9;               -- indicates number of data in the filter
                    filt_dim_size   <= 3;               -- indicates row/column size of 2D filter
                    batch_cycle     <= 1;               -- indicates number of data batches to be used in accumulation part          
               
                when "001" =>   -- 4x4 Filter
                    inp_bound       <= inp_size - 4;
                    batch_number    <= 8;
                    filt_size       <= 15;
                    filt_dim_size   <= 4;
                    batch_cycle     <= 1;
               
                when "010" =>   -- 5x5 Filter
                    inp_bound       <= inp_size - 5;
                    batch_number    <= 24;
                    filt_size       <= 25;
                    filt_dim_size   <= 5;
                    batch_cycle     <= 3;
                    
                when "011" =>   -- 6x6 Filter
                    inp_bound       <= inp_size - 6;
                    batch_number    <= 32;
                    filt_size       <= 35;
                    filt_dim_size   <= 6;
                    batch_cycle     <= 4;
                
                when "100" =>   -- 7x7 Filter
                    inp_bound       <= inp_size - 7;
                    batch_number    <= 48;
                    filt_size       <= 49;
                    filt_dim_size   <= 7;
                    batch_cycle     <= 6;
                
                when "101" =>   -- 8x8 Filter
                    inp_bound       <= inp_size - 8;
                    batch_number    <= 56;
                    filt_size       <= 63;
                    filt_dim_size   <= 8;
                    batch_cycle     <= 7;
                    
                when others=> null;
                
            end case;
        
        else
            inp_bound       <= inp_bound;
            batch_number    <= batch_number;
            filt_size       <= filt_size;
            filt_dim_size   <= filt_dim_size;
            batch_cycle     <= batch_cycle;
         
        end if; 
                 
     end if;
     
end process calculate_parameters;


-- Generating enable signals for processes.
-- Process Sequence 0
enable_controller: process(clk)
begin

    if rising_edge (clk) then
    
        if (rst = '1') then
        
            control_state       <= '0';
            
            stride_en           <= '0';     -- stride process enable signal
            xy_coord_en         <= '0';     -- xy_coordinates process enable signal 
            en_reg_1            <= '0';     -- enable signal pipeline register
            en_reg_2            <= '0';     -- enable signal pipeline register
            en_reg_3            <= '0';     -- enable signal pipeline register
            en_reg_4            <= '0';     -- enable signal pipeline register
            en_reg_5            <= '0';     -- enable signal pipeline register
            en_reg_6            <= '0';     -- enable signal pipeline register
            en_reg_7            <= '0';     -- enable signal pipeline register
            en_reg_8            <= '0';     -- enable signal pipeline register
            en_reg_9            <= '0';     -- enable signal pipeline register
            index_en            <= '0';     -- xy_coordinates_to_index process enable signal 
            bram_prm_en         <= '0';     -- index_value_modulus_8 process enable signal 
            bram_map_en         <= '0';     -- index_to_bram_map process enable signal 
            batch_seq_en        <= '0';     -- batch_sequencer process enable signal
            bram_info_calc_en   <= '0';     -- data_bram_assignment process enable signal
            bram_util_en        <= '0';     -- bram_utilization_info process enable signal
            bram_info_reg_en    <= '0';     -- data_bram_assignment_pipeline process enable signal
            collision_detect_en <= '0';     -- memory_collision_detector process enable signal
            comp_cnt_en         <= '0';     -- computation_controller process enable signal
            
        else
        
            case (control_state) is
            
                when '0' =>
                
                    if (op_start = '1') then
                        control_state <= '1';
                    else
                        control_state <= '0';
                    end if;
                    
                    stride_en           <= '0';
                    xy_coord_en         <= '0';
                    en_reg_1            <= '0';
                    en_reg_2            <= '0';
                    en_reg_3            <= '0';
                    en_reg_4            <= '0';
                    en_reg_5            <= '0';
                    en_reg_6            <= '0';
                    en_reg_7            <= '0';
                    en_reg_8            <= '0';
                    en_reg_9            <= '0';
                    index_en            <= '0';
                    bram_prm_en         <= '0';
                    bram_map_en         <= '0';
                    batch_seq_en        <= '0';
                    bram_info_calc_en   <= '0';
                    bram_util_en        <= '0';
                    bram_info_reg_en    <= '0';
                    collision_detect_en <= '0';
                    comp_cnt_en         <= '0';
                
                when '1' =>
                
                    if (op_end = '1') then
                        control_state <= '0';
                    else
                        control_state <= '1';
                    end if;
                    
                    -- Generating enable signals for the processes 
                    -- Considering latency and collision cases 
                    stride_en           <=  (not collision);
                    xy_coord_en         <=  (not collision);
                    en_reg_1            <=  '1';
                    en_reg_2            <=  en_reg_1;
                    en_reg_3            <=  en_reg_2;
                    en_reg_4            <=  en_reg_3;
                    en_reg_5            <=  en_reg_4;
                    en_reg_6            <=  en_reg_5;
                    en_reg_7            <=  en_reg_6;
                    en_reg_8            <=  en_reg_7;
                    en_reg_9            <=  en_reg_8;  
                    index_en            <=  en_reg_1 and (not collision);
                    bram_prm_en         <=  en_reg_2 and (not collision);
                    bram_map_en         <=  en_reg_3 and (not collision);
                    batch_seq_en        <=  en_reg_4 and (not collision);
                    bram_info_calc_en   <=  en_reg_5 and (not collision);
                    bram_util_en        <=  en_reg_5 and (not collision);
                    bram_info_reg_en    <=  en_reg_6 and (not collision);
                    collision_detect_en <=  en_reg_8 and (not collision);
                    comp_cnt_en         <=  en_reg_9 ;
                
                when others => null;
                
            end case;
            
        end if;   
    end if;
end process enable_controller;


-- Filter striding controller which computes starting pixel index value of the input data for the stride position of the convolution filter. 
-- Output: x,y coordinates of input data index value which points to first data to be used in convolution computations. 
-- Process Sequence 1
stride_process: process(clk)  
begin

    if rising_edge(clk) then
    
        if(stride_en = '1') then
            
            -- Each case includes computations for 3x3, 4x4, 5x5, 6x6, 7x7 or 8x8 filters
            case(filt_type) is
      
                when "000" =>   -- 3x3 Filter
                    
                    -- Checking number of strides and stride positions 
                    if (stride_count = 1) then
                        stride_count <= 0;
                        if ( x_ptr /= inp_bound ) then 
                            x_ptr <= x_ptr + stride;
                            y_ptr <= y_ptr;   
                        else
                            x_ptr <= 0;
                            y_ptr <= y_ptr + stride;
                        end if;
                    else
                        stride_count <= stride_count + 1;
                    end if;
                    
                when "001" =>   -- 4x4 Filter
                    
                    -- Checking number of strides and stride positions 
                    if (stride_count = 1) then
                        stride_count <= 0;
                        if ( x_ptr /= inp_bound ) then 
                            x_ptr <= x_ptr + stride;
                            y_ptr <= y_ptr;   
                        else
                            x_ptr <= 0;
                            y_ptr <= y_ptr + stride;
                        end if;
                    else  
                        stride_count <= stride_count + 1;
                    end if;
               
                when "010" =>   -- 5x5 Filter 
                
                    -- Checking number of strides and stride positions 
                    if (stride_count = 2) then
                        stride_count <= 0;
                        if ( x_ptr /= inp_bound ) then 
                            x_ptr <= x_ptr + stride;
                            y_ptr <= y_ptr;   
                        else
                            x_ptr <= 0;
                            y_ptr <= y_ptr + stride;
                        end if;
                    else  
                        stride_count <= stride_count + 1;
                    end if;
                    
                when "011" =>   -- 6x6 Filter 
                    
                    -- Checking number of strides and stride positions 
                    if (stride_count = 4) then
                        stride_count <= 0;
                        if ( x_ptr /= inp_bound ) then 
                            x_ptr <= x_ptr + stride;
                            y_ptr <= y_ptr;   
                        else
                            x_ptr <= 0;
                            y_ptr <= y_ptr + stride;
                        end if;
                    else  
                        stride_count <= stride_count + 1;
                    end if;
                
                when "100" =>   -- 7x7 Filter 
                
                    -- Checking number of strides and stride positions 
                    if (stride_count = 6) then
                        stride_count <= 0;
                        if ( x_ptr /= inp_bound ) then 
                            x_ptr <= x_ptr + stride;
                            y_ptr <= y_ptr;   
                        else
                            x_ptr <= 0;
                            y_ptr <= y_ptr + stride;
                        end if;
                    else  
                        stride_count <= stride_count + 1;
                    end if;
                    
                when "101" =>   -- 8x8 Filter 
                
                    -- Checking number of strides and stride positions 
                    if (stride_count = 7) then
                        stride_count <= 0;
                        if ( x_ptr /= inp_bound ) then 
                            x_ptr <= x_ptr + stride;
                            y_ptr <= y_ptr;   
                        else
                            x_ptr <= 0;
                            y_ptr <= y_ptr + stride;
                        end if;
                    else  
                        stride_count <= stride_count + 1;
                    end if;
     
                when others =>null;
                
            end case; 
        
        else
        
            -- Module reset
            if(module_rst = '1') then
                stride_count <= 0;
            else
                stride_count <= stride_count;
            end if;
            
        end if;    
    end if;
end process stride_process;


-- Calculating x,y coordinates of all the input data to be used in computations for a filter stride position.
-- Output: 64x2 integer array which stores x and y coordinates of 64 input data.
-- Process Sequence 2  
xy_coordinates: process(clk) 
variable index_count: integer range 0 to 63:=0; 
begin

    if rising_edge(clk) then
    
        if(xy_coord_en = '1') then
           
            -- Each case includes computations for 3x3, 4x4, 5x5, 6x6, 7x7 or 8x8 filters 
            case(filt_type) is    
                    
                when "000" =>   -- 3x3 Filter 
                
                    -- Calculating x,y coordinates of input data
                    for i in 0 to 2 loop
                        for j in 0 to 2 loop
                            xy_coord(index_count,0) <= x_ptr + j;
                            xy_coord(index_count,1) <= y_ptr + i;
                            index_count := index_count + 1;
                        end loop;
                    end loop;
                    index_count := 0;
    
                when "001" =>   -- 4x4 Filter 
                
                    -- Calculating x,y coordinates of input data
                    for i in 0 to 3 loop
                        for j in 0 to 3 loop
                            xy_coord(index_count,0) <= x_ptr + j;
                            xy_coord(index_count,1) <= y_ptr + i;
                            index_count := index_count + 1;
                        end loop;
                    end loop;
                    index_count := 0;
                    
                when "010" =>   -- 5x5 Filter 
                
                    -- Calculating x,y coordinates of input data
                    for i in 0 to 4 loop
                        for j in 0 to 4 loop
                            xy_coord(index_count,0) <= x_ptr + j;
                            xy_coord(index_count,1) <= y_ptr + i;
                            index_count := index_count + 1;
                        end loop;
                    end loop;
                    index_count := 0;
                    
                when "011" =>   -- 6x6 Filter 
                
                    -- Calculating x,y coordinates of input data
                    for i in 0 to 5 loop
                        for j in 0 to 5 loop
                            xy_coord(index_count,0) <= x_ptr + j;
                            xy_coord(index_count,1) <= y_ptr + i;
                            index_count := index_count + 1;
                        end loop;
                    end loop;
                    index_count := 0;
                    
                when "100" =>   -- 7x7 Filter 
                
                    -- Calculating x,y coordinates of input data
                    for i in 0 to 6 loop
                        for j in 0 to 6 loop
                            xy_coord(index_count,0) <= x_ptr + j;
                            xy_coord(index_count,1) <= y_ptr + i;
                            index_count := index_count + 1;
                        end loop;
                    end loop;
                    index_count := 0;
                    
                when "101" =>   -- 8x8 Filter 
                
                    -- Calculating x,y coordinates of input data
                    for i in 0 to 7 loop
                        for j in 0 to 7 loop
                            xy_coord(index_count,0) <= x_ptr + j;
                            xy_coord(index_count,1) <= y_ptr + i;
                            index_count := index_count + 1;
                        end loop;
                    end loop;
                    index_count := 0;
                  
                when others =>null;
                
            end case;
            
        end if;
    end if;
end process xy_coordinates;


-- Calculating index values by using x,y coordinates for all the input data to be used in computations for a filter stride position.
-- Output: integer array which stores index values of 64 input data.  
-- Process Sequence 3
xy_coordinates_to_index: process(clk)
begin

    if rising_edge (clk) then
    
        if(index_en = '1') then
        
            -- x-y coordinates to data index conversion  
            for i in 0 to 63 loop
            
                index(i) <= ( filt_dim_size * xy_coord(i,1) ) + xy_coord(i,0);
            
            end loop;   
             
        end if;   
    end if;
end process xy_coordinates_to_index;     


-- Calculating modulus-8 of index values prior to BRAM assignment number calculations. 
-- Output: index modulus-8 values for 64 input data.  
-- Process Sequence 4
index_value_modulus_8: process(clk)
begin

    if rising_edge (clk) then
    
        if(bram_prm_en = '1') then
        
            -- Calculating modulus 8 of index number
            for i in 0 to 63 loop
                index_mod(i)  <=  index(i) mod 8;     
            end loop;
            
        end if;   
    end if;
end process index_value_modulus_8;  


-- Calculating BRAM assignment number of input data indices. Determining port/address assignment of input data for dual port BRAMs.  
-- Output: BRAM assignment numbers of 64 input data. Address assignment array of input data for each dual port BRAMs. 
-- Process Sequence 5
index_to_bram_map: process(clk)
begin

    if rising_edge (clk) then
    
        if (bram_map_en = '1') then
        
            -- Determining BRAMs for input data
            for i in 0 to 63 loop
                
                if ( ( index_mod(i) = 0 ) or ( index_mod(i) = 1 ) ) then        -- BRAM1
                    
                    index_bram_num(i) <= 1;      
                    
                    if ( index_mod(i) = 0 ) then
                        odd_even_prm(i) <= 0;
                    else 
                        odd_even_prm(i) <= 1; 
                    end if;  
                
                elsif ( ( index_mod(i) = 2 ) or ( index_mod(i) = 3 ) ) then     -- BRAM2
                    
                    index_bram_num(i) <= 2;  
                    
                    if ( index_mod(i) = 2 ) then
                        odd_even_prm(i) <= 0;  
                    else 
                        odd_even_prm(i) <= 1;  
                    end if;  
                    
                elsif ( ( index_mod(i) = 4 ) or ( index_mod(i) = 5 ) ) then     -- BRAM3
                    
                    index_bram_num(i) <= 3;  
                    
                    if ( index_mod(i) = 4 ) then
                        odd_even_prm(i) <= 0;  
                    else 
                        odd_even_prm(i) <= 1;  
                    end if;    
                
                elsif ( ( index_mod(i) = 6 ) or ( index_mod(i) = 7 ) ) then     -- BRAM4
                    
                    index_bram_num(i) <= 4;  
                    
                    if ( index_mod(i) = 6 ) then
                        odd_even_prm(i) <= 0;  
                    else 
                        odd_even_prm(i) <= 1;  
                    end if;  

                end if;
                     
            end loop;
            
        end if;  
    end if;
end process index_to_bram_map;  


-- Sequencing/Registering BRAM number and address calculation parameters of 8 input data batches.
-- Output: BRAM assignment numbers of 8 input data. Address calculation parameters of 8 input data. 
-- Process Sequence 6
batch_sequencer: process(clk)
begin

    if rising_edge(clk) then
    
        if (batch_seq_en = '1') then

            -- Checking for the end of data batch
            if (batch_count = batch_number) then
            
                for i in 0 to 7 loop
                    bram_num_reg(i)     <=  to_unsigned( index_bram_num(batch_count+i),bram_num_reg(0)'length );    -- BRAM number
                    bram_addr_prm(i)    <=  index_bram_num(batch_count+i) / 4;                                      -- Address calculation
                    odd_even_prm2(i)    <=  odd_even_prm(batch_count+i);                                            -- Odd/even address number  
                end loop;
                
                batch_count <= 0;
            
            else
                
                for i in 0 to 7 loop
                    bram_num_reg(i)     <=  to_unsigned( index_bram_num(batch_count+i),bram_num_reg(0)'length );
                    bram_addr_prm(i)    <=  index_bram_num(batch_count+i) / 4; 
                    odd_even_prm2(i)    <=  odd_even_prm(batch_count+i); 
                end loop;
                
                batch_count <= batch_count + 8;
                
            end if;
            
        else
        
            -- Module reset
            if(module_rst = '1') then
                batch_count <= 0;
            else
                batch_count <= batch_count;
            end if;
     
        end if;
    end if;
end process batch_sequencer;


-- Determining BRAM assignment numbers (decoded as 0 to 7 for 4 dual port BRAMs) for each of input data in the batch. Calculating input data addresses. 
-- Output: input data BRAM assignment number array, input data address array.
-- Process Sequence 7
data_bram_assignment:process(clk) 
begin

    if rising_edge(clk) then
    
        if ( bram_info_calc_en = '1') then 
       
            -- Determining BRAM numbers and ports for the data-BRAM assignment
            for i in 0 to 7 loop
            
                if ( (bram_num_reg(i) = 1) and (odd_even_prm2(i) = 0) ) then        -- BRAM1 portA
                    bram_num_dec(i) <= 0;
                elsif ( (bram_num_reg(i) = 1) and (odd_even_prm2(i) = 1) ) then     -- BRAM1 portB
                    bram_num_dec(i) <= 1;
                elsif ( (bram_num_reg(i) = 2) and (odd_even_prm2(i) = 0) ) then     -- BRAM2 portA
                    bram_num_dec(i) <= 2;
                elsif ( (bram_num_reg(i) = 2) and (odd_even_prm2(i) = 1) ) then     -- BRAM2 portB
                    bram_num_dec(i) <= 3;
                elsif ( (bram_num_reg(i) = 3) and (odd_even_prm2(i) = 0) ) then     -- BRAM3 portA
                    bram_num_dec(i) <= 4;
                elsif ( (bram_num_reg(i) = 3) and (odd_even_prm2(i) = 1) ) then     -- BRAM3 portB
                    bram_num_dec(i) <= 5;
                elsif ( (bram_num_reg(i) = 4) and (odd_even_prm2(i) = 0) ) then     -- BRAM4 portA
                    bram_num_dec(i) <= 6;
                elsif ( (bram_num_reg(i) = 4) and (odd_even_prm2(i) = 1) ) then     -- BRAM4 portB
                    bram_num_dec(i) <= 7;
                end if;    
                       
            end loop;
    
            -- Calculating BRAM addresses
            for i in 0 to 7 loop
                bram_addr_reg(i) <=  bram_addr_prm(i) + odd_even_prm2(i);           -- BRAM address
            end loop;
            
        end if; 
    end if;
end process data_bram_assignment;


-- Registering/Pipelining BRAM assignment numbers and addresses of input data in the batch.
-- Output: pipelined input data BRAM assignment number array and address array.
-- Process Sequence 8
data_bram_assignment_pipeline:process(clk) 
begin

    if rising_edge(clk) then
    
        -- Register and pipeline BRAM assignment numbers 
        if ( bram_info_reg_en = '1') then 
        
            bram_num_dec_l1 <= bram_num_dec;
            bram_num_dec_l2 <= bram_num_dec_l1;
            bram_num_dec_l3 <= bram_num_dec_l2;
            bram_num_dec_l4 <= bram_num_dec_l3;
            
            bram_addr_reg_l1 <= bram_addr_reg;
            bram_addr_reg_l2 <= bram_addr_reg_l1;
            bram_addr_reg_l3 <= bram_addr_reg_l2;
            bram_addr_reg_l4 <= bram_addr_reg_l3;

        end if; 
    end if;
end process data_bram_assignment_pipeline;


-- Calculating utilization numbers of BRAMs for all input data in the batch. Constructing utilization queue which contains input data number in the batch for each BRAM.
-- This process uses adder tree to find the utilization numbers for each BRAMs. Addition latency is 3 Clk cycles. Results are pipelined. 
-- Output: 4 elements array storing utilization numbers for each BRAM. 4x8 utilization queue array containing data positions (0-7) in the batch.
-- Process Sequence 7
bram_utilization_info: process(clk) 
variable q_count: integer range 0 to 7:=0;
begin

    if rising_edge(clk) then
    
        if ( bram_util_en = '1') then

            -- Adder tree ----------------------------------------------------------------
            -- Determining utilization numbers of BRAMs for all input data in the batch
            
            -- Adder layer 1 - Add 4 pairs
            for b in 0 to 3 loop
                for i in 0 to 3 loop
                    sum_pairs_l1(b,i) <= bram_num_reg(2*i) + bram_num_reg(2*i + 1);         
                end loop;
            end loop;
              
            -- Adder layer 2 - Add 2 pairs
            for b in 0 to 3 loop
                for i in 0 to 1 loop
                    sum_pairs_l2(b,i) <= sum_pairs_l1(b,2*i) + sum_pairs_l1(b,(2*i+1)); 
                end loop;
            end loop;
            
            -- Adder layer 3 - Add 1 pair
            for b in 0 to 3 loop
                bram_util_num_l1(b) <= to_integer( sum_pairs_l2(b,0) + sum_pairs_l2(b,1) );
            end loop;
            
            -- Layer 4 - registering utilization number array 
            bram_util_num_l2    <= bram_util_num_l1; -- Pipeline
            ------------------------------------------------------------------------------
            
            -- Utilization queue ---------------------------------------------------------
            -- Determining utilization queue for BRAM1, BRAM2, BRAM3 and BRAM4
            
            for b in 0 to 3 loop
                q_count := 0;
                for i in 0 to 7 loop
                    if ( bram_num_reg(i)(b) = '1' ) then
                        util_queue_l1(b,q_count) <= i;
                        q_count := q_count + 1;
                    end if; 
                       
                end loop;
            end loop;        
            
            -- Pipelining utilization queue array
            util_queue_l2   <= util_queue_l1; -- Pipeline 1
            util_queue_l3   <= util_queue_l2; -- Pipeline 2
            util_queue_l4   <= util_queue_l3; -- Pipeline 3
            ------------------------------------------------------------------------------
            
        end if;
    end if;
end process bram_utilization_info;


-- Detecting memory collision. Determining number of collisions.
-- Output: Collision detection indicator, maximum number of collisions.
-- Process Sequence 10
memory_collision_detector: process(clk) 
begin

    if rising_edge(clk) then
    
        if ( collision_detect_en = '1') then
        
            -- Checking for collision ---------------------------------------------------------------------------------------------------
            if ( (bram_util_num_l1(0) > 2)  or (bram_util_num_l1(1) > 2) or (bram_util_num_l1(2) > 2) or (bram_util_num_l1(3) > 2) ) then
                collision_detected <= '1';
            else
                collision_detected <= '0';
            end if;
            -----------------------------------------------------------------------------------------------------------------------------
        
            -- Maximum BRAM utilization number pre-calculation --
            if ( bram_util_num_l1(0) > bram_util_num_l1(1) ) then 
                max_util_num_1  <= bram_util_num_l1(0);
            else
                max_util_num_1  <= bram_util_num_l1(1);      
            end if;
            
            if ( bram_util_num_l1(2) > bram_util_num_l1(3) ) then 
                max_util_num_2  <= bram_util_num_l1(2);
            else
                max_util_num_2  <= bram_util_num_l1(3);      
            end if;
            -----------------------------------------------------

        end if;
    end if;
end process memory_collision_detector;


-- Controlling data BRAM access, collision handling, multiplication and accumulation processes.  
-- Output: 
-- Process Sequence 11
computation_controller: process(clk)
begin

    if rising_edge(clk) then
    
        if ( comp_cnt_en = '1') then
        
            case (cnt_state) is
                
                when '0' => -- No memory collision state
                    
                    -- Collision check ----------------------------------
                    if ( collision_detected = '1') then
                        cnt_state   <= '1'; -- Controller state
                        collision   <= '1'; -- Collision indicator
                        acc_cnt     <= '0'; -- Accumulation enable signal
                    else
                        cnt_state   <= '0';
                        collision   <= '0';
                        acc_cnt     <= '1'; 
                    end if;
                    -----------------------------------------------------
                    
                    -- Calculating maximum BRAM utilization number ------ 
                    if( max_util_num_1 > max_util_num_2 ) then
                        max_util_num <= max_util_num_1;
                    else
                        max_util_num <= max_util_num_2;
                    end if;
                    -----------------------------------------------------

                    -- Controlling BRAM access handler ---------------------
                    bram_util_num           <= bram_util_num_l2; -- Pipeline
                    util_queue              <= util_queue_l4;    -- Pipeline
                    handler_state           <= '0';              -- memory access handler state
                    mem_handler_en          <= '1';              -- memory access handler enable
                    --------------------------------------------------------
                    
                    collision_count         <= 3;   -- Collision counter 
                    process_register        <= '0'; -- Collision cycle indicator
                    acc_collision_cnt       <= '0'; -- Accumulation enable signal
                    bram_info_cnt_en        <= '1'; -- BRAM info register enable 
                    
                when '1' => -- Memory collision state
                    
                    -- Collision handling ----------------------------------------------------
                    --------------------------------------------------------------------------
                    if( collision_count > max_util_num ) then -- Check collision-end
                        
                        if (process_register = '1') then -- Check 2nd cycle
                            
                            cnt_state               <= '0';
                            mem_handler_en          <= '0'; 
                            collision               <= '0';  
                            bram_info_cnt_en        <= '0';
                                  
                        else -- First cycle for the collision case
                        
                            cnt_state               <= '1';
                            process_register        <= '1';
                            max_util_num            <= max_util_num_reg; 
                 
                            -- BRAM access handler control signals and data ------------------
                            bram_util_num           <= bram_util_num_reg;
                            util_queue              <= util_queue_reg;
                            handler_state           <= '0';
                            mem_handler_en          <= '1';
                            ------------------------------------------------------------------
                            
                            collision_count         <= 3;
                            collision               <= '1';
                            bram_info_cnt_en        <= '1';
                            
                        end if;
                        
                        acc_collision_cnt <= '1';
                        
                    
                    else -- Collision case 
                    
                        handler_state           <= '1';
                        mem_handler_en          <= '1';
                        collision_count         <= collision_count + 2; 
                        collision               <= '1';
                        bram_info_cnt_en        <= '0';
                        acc_collision_cnt       <= '0';

                    end if;
                    --------------------------------------------------------------------------
                    --------------------------------------------------------------------------
   
                    -- Register data from previous processes -------------
                    -- during the deactive time of the collision indicator 
                    if( max_util_num_1 > max_util_num_2 ) then
                        max_util_num_reg <= max_util_num_1;
                    else
                        max_util_num_reg <= max_util_num_2;
                    end if; 
                    
                    bram_util_num_reg   <= bram_util_num_l2;
                    util_queue_reg      <= util_queue_l4;
                    ------------------------------------------------------
    
                    acc_cnt <= '0';
                    
                when others=> null;
            
            end case;
            
         else
        
             -- Module reset
            if(module_rst = '1') then
                cnt_state           <= '0'; 
                collision           <= '0';
                acc_cnt             <= '0'; 
                collision_count     <= 3; 
                mem_handler_en      <= '0';
                process_register    <= '0';
                acc_collision_cnt   <= '0';
                bram_info_cnt_en    <= '0';
            else
                cnt_state           <= cnt_state;
                collision           <= collision;
                acc_cnt             <= acc_cnt;
                collision_count     <= collision_count;
                mem_handler_en      <= mem_handler_en;
                process_register    <= process_register;
                acc_collision_cnt   <= acc_collision_cnt;
                bram_info_cnt_en    <= bram_info_cnt_en;
            end if;
        
        end if;
    end if;
end process computation_controller;


-- BRAM assignment data pipeline control
-- Process Sequence - Controlled by "computation_controller" process.
data_bram_assignment_pipeline_control:process(clk) 
begin

    if rising_edge(clk) then
    
        -- Registering/Pipelining BRAM assignment data
        if ( bram_info_cnt_en = '1') then 
        
            bram_num_dec_l5  <= bram_num_dec_l4;
            bram_addr_reg_l5 <= bram_addr_reg_l4;

        end if; 
    end if;
end process data_bram_assignment_pipeline_control;


-- Determining active BRAM ports for a given computation cycle.
-- BRAM access is queued for the collision case. 
-- Output: Array indicating if there will be a BRAM access for an input data in the batch. 
-- Process Sequence - Controlled by "computation_controller" process.
memory_access_handler: process(clk)
begin

    if rising_edge(clk) then
    
        if (mem_handler_en = '1') then
            
            case (handler_state) is
            
                when '0' =>
     
                    -- BRAM(b:1/2/3/4) is utilization check for 1,2,3,4,5,6,7,8 cases
                    for b in 0 to 3 loop
                    
                        if ( bram_util_num(b) = 1 ) then                -- BRAM(b:1/2/3/4) is utilization 1
                            
                            collision_num(b)    <= 0;                   -- Number of collisions
                            
                            data_reg_active(util_queue(b,0))  <= '1';   -- BRAM access activation array
                            
                            util_q_updated(b,0) <= util_queue(b,0);     -- Utilization queue registering
                            
                            for i in 1 to 7 loop
                                util_q_updated(b,i) <= 8;               -- Non-utilization indicator in the queue 
                            end loop;
                            
                       elsif ( bram_util_num(b) = 2 ) then              
                            
                            collision_num(b)    <= 0;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            
                            util_q_updated(b,0) <= util_queue(b,0);
                            util_q_updated(b,1) <= util_queue(b,1);
                            
                            for i in 2 to 7 loop
                                util_q_updated(b,i) <= 8;
                            end loop;
                            
                        elsif ( bram_util_num(b) = 3 ) then             
                            
                            collision_num(b) <= 1;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            data_reg_active(util_queue(b,2))  <= '0';
                            
                            util_q_updated(b,0) <= util_queue(b,2);
                            util_q_updated(b,1) <= util_queue(b,0);
                            util_q_updated(b,2) <= util_queue(b,1);
                            
                            for i in 3 to 7 loop
                                util_q_updated(b,i) <= 8;
                            end loop;
                        
                        elsif ( bram_util_num(b) = 4 ) then
                            
                            collision_num(b) <= 2;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            data_reg_active(util_queue(b,2))  <= '0';
                            data_reg_active(util_queue(b,3))  <= '0';
                            
                            util_q_updated(b,0) <= util_queue(b,2);
                            util_q_updated(b,1) <= util_queue(b,3);
                            util_q_updated(b,2) <= util_queue(b,0);
                            util_q_updated(b,3) <= util_queue(b,1);
                            
                            for i in 4 to 7 loop
                                util_q_updated(b,i) <= 8;
                            end loop; 
                            
                        elsif ( bram_util_num(b) = 5 ) then
                            
                            collision_num(b) <= 3;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            data_reg_active(util_queue(b,2))  <= '0';
                            data_reg_active(util_queue(b,3))  <= '0';
                            data_reg_active(util_queue(b,4))  <= '0';
                            
                            util_q_updated(b,0) <= util_queue(b,2);
                            util_q_updated(b,1) <= util_queue(b,3);
                            util_q_updated(b,2) <= util_queue(b,4);
                            util_q_updated(b,3) <= util_queue(b,0);
                            util_q_updated(b,4) <= util_queue(b,1);
                            
                            q_end_0(b) <= 3;    -- End of queue indicator
                            q_end_1(b) <= 4;    -- End of queue indicator
                            
                            for i in 5 to 7 loop
                                util_q_updated(b,i) <= 8;
                            end loop;
                            
                        elsif ( bram_util_num(b) = 6 ) then
                            
                            collision_num(b) <= 4;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            data_reg_active(util_queue(b,2))  <= '0';
                            data_reg_active(util_queue(b,3))  <= '0';
                            data_reg_active(util_queue(b,4))  <= '0';
                            data_reg_active(util_queue(b,5))  <= '0';
                            
                            util_q_updated(b,0) <= util_queue(b,2);
                            util_q_updated(b,1) <= util_queue(b,3);
                            util_q_updated(b,2) <= util_queue(b,4);
                            util_q_updated(b,3) <= util_queue(b,5);
                            util_q_updated(b,4) <= util_queue(b,0);
                            util_q_updated(b,5) <= util_queue(b,1);
                            
                            q_end_0(b) <= 4;
                            q_end_1(b) <= 5;
                            
                            for i in 6 to 7 loop
                                util_q_updated(b,i) <= 8;     
                            end loop;
                        
                        elsif ( bram_util_num(b) = 7 ) then
                            
                            collision_num(b) <= 5;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            data_reg_active(util_queue(b,2))  <= '0';
                            data_reg_active(util_queue(b,3))  <= '0';
                            data_reg_active(util_queue(b,4))  <= '0';
                            data_reg_active(util_queue(b,5))  <= '0';
                            data_reg_active(util_queue(b,6))  <= '0';
                            
                            util_q_updated(b,0) <= util_queue(b,2);
                            util_q_updated(b,1) <= util_queue(b,3);
                            util_q_updated(b,2) <= util_queue(b,4);
                            util_q_updated(b,3) <= util_queue(b,5);
                            util_q_updated(b,4) <= util_queue(b,6);
                            util_q_updated(b,5) <= util_queue(b,0);
                            util_q_updated(b,6) <= util_queue(b,1);
                            
                            q_end_0(b) <= 5;
                            q_end_1(b) <= 6;
                            
                            util_q_updated(b,7) <= 8;     
                           
                        
                        elsif ( bram_util_num(b) = 8 ) then
                            
                            collision_num(b) <= 6;
                            
                            data_reg_active(util_queue(b,0))  <= '1';
                            data_reg_active(util_queue(b,1))  <= '1';
                            data_reg_active(util_queue(b,2))  <= '0';
                            data_reg_active(util_queue(b,3))  <= '0';
                            data_reg_active(util_queue(b,4))  <= '0';
                            data_reg_active(util_queue(b,5))  <= '0';
                            data_reg_active(util_queue(b,6))  <= '0';
                            data_reg_active(util_queue(b,7))  <= '0';
                            
                            util_q_updated(b,0) <= util_queue(b,2);
                            util_q_updated(b,1) <= util_queue(b,3);
                            util_q_updated(b,2) <= util_queue(b,4);
                            util_q_updated(b,3) <= util_queue(b,5);
                            util_q_updated(b,4) <= util_queue(b,6);
                            util_q_updated(b,5) <= util_queue(b,7);
                            util_q_updated(b,6) <= util_queue(b,0);
                            util_q_updated(b,7) <= util_queue(b,1);
                            
                            q_end_0(b) <= 6;
                            q_end_1(b) <= 7;
                            
                    
                        end if;
                        
                    end loop;
                
                when '1' =>
                
                    -- Memory access calculations for non-collision and collision cases
                    for b in 0 to 3 loop

                        if ( collision_num(b) = 0 ) then
                        
                            collision_num(b) <= 0;
                            
                            for i in 0 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                end if;
                            end loop;
                        
                        elsif ( collision_num(b) = 1 ) then
                            
                            collision_num(b) <= 0;
                            
                            data_reg_active(util_q_updated(b,0))  <= '1';
                            
                            for i in 1 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                end if;
                            end loop;
                        
                        elsif ( collision_num(b) = 2 ) then

                            collision_num(b) <= 0;
                            
                            data_reg_active(util_q_updated(b,0))  <= '1';
                            data_reg_active(util_q_updated(b,1))  <= '1';
                            
                            for i in 2 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                end if;
                            end loop;
                        
                        elsif ( collision_num(b) = 3 ) then
                            
                            collision_num(b) <= 1;
                            
                            data_reg_active(util_q_updated(b,0))  <= '1';
                            data_reg_active(util_q_updated(b,1))  <= '1';
                            
                            for i in 2 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                    util_q_updated(b,i-2) <= util_q_updated(b,i);
                                end if;
                            end loop;
                            
                            util_q_updated(b,q_end_0(b)) <= util_q_updated(b,0);
                            util_q_updated(b,q_end_1(b)) <= util_q_updated(b,1);
                        
                        elsif ( collision_num(b) = 4 ) then
                            
                            collision_num(b) <= 2;
                            
                            data_reg_active(util_q_updated(b,0))  <= '1';
                            data_reg_active(util_q_updated(b,1))  <= '1';
                            
                            for i in 2 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                    util_q_updated(b,i-2) <= util_q_updated(b,i);
                                end if;
                            end loop;
                            
                            util_q_updated(b,q_end_0(b)) <= util_q_updated(b,0);
                            util_q_updated(b,q_end_1(b)) <= util_q_updated(b,1);
                            
                        elsif ( collision_num(b) = 5 ) then
                            
                            collision_num(b) <= 3;
                            
                            data_reg_active(util_q_updated(b,0))  <= '1';
                            data_reg_active(util_q_updated(b,1))  <= '1';
                            
                            for i in 2 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                    util_q_updated(b,i-2) <= util_q_updated(b,i);
                                end if;
                            end loop;
                            
                            util_q_updated(b,q_end_0(b)) <= util_q_updated(b,0);
                            util_q_updated(b,q_end_1(b)) <= util_q_updated(b,1);
                            
                        elsif ( collision_num(b) = 6 ) then
                            
                            collision_num(b) <= 4;
                            
                            data_reg_active(util_q_updated(b,0))  <= '1';
                            data_reg_active(util_q_updated(b,1))  <= '1';
                            
                            for i in 2 to 7 loop
                                if ( util_q_updated(b,i) /= 8 ) then
                                    data_reg_active(util_q_updated(b,i))  <= '0';
                                    util_q_updated(b,i-2) <= util_q_updated(b,i);
                                end if;
                            end loop;
                            
                            util_q_updated(b,q_end_0(b)) <= util_q_updated(b,0);
                            util_q_updated(b,q_end_1(b)) <= util_q_updated(b,1);
                        
                        end if;
                        
                    end loop;
                
                when others=> null;
            
            end case;
   
            bram_access_en <= '1'; -- BRAM access signal generation enable
            
        else
        
            bram_access_en <= '0';
        
        end if;
    end if;
end process memory_access_handler;
                          
                                                                                                                                                              
-- BRAM address ports -------------------------------------------         
bram1_addra <= data_bram_addr(0) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram1_addrb <= data_bram_addr(1) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram2_addra <= data_bram_addr(2) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram2_addrb <= data_bram_addr(3) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram3_addra <= data_bram_addr(4) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram3_addrb <= data_bram_addr(5) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram4_addra <= data_bram_addr(6) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
bram4_addrb <= data_bram_addr(7) when (bram_access_en = '1') else         
               "ZZZZZZZZZZZZZZ";                                          
-----------------------------------------------------------------         


-- Generating BRAM access signals.
-- Output: BRAM access signals, en, we, addr. 
-- Process Sequence - Controlled by "memory_access_handler" process.
data_bram_access:process(clk)
begin

    if rising_edge(clk) then
    
        if ( bram_access_en = '1') then 
      
            -- Read access to BRAM
            data_bram_en <= (others=> '1');
            data_bram_we <= (others=> '0');
            
            -- BRAM address 
            for i in 0 to 7 loop
                if ( data_reg_active(i) = '1' ) then
                    data_bram_addr(bram_num_dec_l5(i)) <= std_logic_vector( to_unsigned(bram_addr_reg_l5(i),14) ) ;
                end if; 
            end loop;
            
            data_reg_active_q   <= data_reg_active; -- Register BRAM access activation array
            bram_num_dec_q      <= bram_num_dec;    -- Register BRAM assignment numbers (decoded as 0 to 7 for 4 dual port BRAMs)
             
            read_data_bram      <= '1';             -- Read BRAM port   
   
        else
        
            data_bram_en        <= (others=> 'Z');
            data_bram_we        <= (others=> 'Z');
        
            data_reg_active_q   <= data_reg_active_q;
            bram_num_dec_q      <= bram_num_dec_q;
            
            read_data_bram      <= '0';
            
        end if; 
    end if;
end process data_bram_access;


-- BRAM data ports -----------       
data_bram_d(0) <= bram1_douta;       
data_bram_d(1) <= bram1_doutb;       
data_bram_d(2) <= bram2_douta;       
data_bram_d(3) <= bram2_doutb;       
data_bram_d(4) <= bram3_douta;       
data_bram_d(5) <= bram3_doutb;       
data_bram_d(6) <= bram4_douta;       
data_bram_d(7) <= bram4_doutb;       
------------------------------       


-- Read BRAM and register data.
-- Output: BRAM access signals, en, we, addr. 
-- Process Sequence - Controlled by "data_bram_access" process.
data_bram_read:process(clk)
begin

    if rising_edge(clk) then
    
        if ( read_data_bram = '1') then 
        
            -- Registering BRAM data
            for i in 0 to 7 loop
                if ( data_reg_active_q(i) = '1' ) then
                    data_bram_reg(i) <= signed( data_bram_d(bram_num_dec_q(i)) );
                else
                    data_bram_reg(i) <= data_bram_reg(i); 
                end if;
            end loop;
            
        end if; 
    end if;
end process data_bram_read;


-- Synchronization pipeline for accumulator and filter coefficient data batch sequencer enable signal.
-- Controlled by "computation_controller" process. 
-- Outputs: accumulation enable, filter data sequencer enable.   
enable_signal_pipeline:process(clk)
begin

    if rising_edge(clk) then
    
        if (rst = '1') then
            
            acc_cnt_l1              <= '0' ;    -- Pipeline - Accumulator enable signal                            
            acc_cnt_l2              <= '0' ;    -- Pipeline - Accumulator enable signal
            acc_cnt_l3              <= '0' ;    -- Pipeline - Accumulator enable signal
            acc_cnt_l4              <= '0' ;    -- Pipeline - Accumulator enable signal
            acc_cnt_l5              <= '0' ;    -- Pipeline - Accumulator enable signal 
            
            acc_collision_cnt_l1    <= '0' ;    -- Pipeline - Filter coefficient data batch sequencer enable signal                 
            acc_collision_cnt_l2    <= '0' ;    -- Pipeline - Filter coefficient data batch sequencer enable signal 
            acc_collision_cnt_l3    <= '0' ;    -- Pipeline - Filter coefficient data batch sequencer enable signal 
            acc_collision_cnt_l4    <= '0' ;    -- Pipeline - Filter coefficient data batch sequencer enable signal  
            
            acc_control_en          <= '0';     -- Accumulator enable signal 
            
            filter_seq_en           <= '0';     -- Filter coefficient data batch sequencer enable signal     
        
        else
        
            acc_cnt_l1              <= acc_cnt ;                            -- Pipeline - Accumulator enable signal
            acc_cnt_l2              <= acc_cnt_l1 ; 
            acc_cnt_l3              <= acc_cnt_l2 ; 
            acc_cnt_l4              <= acc_cnt_l3 ; 
            acc_cnt_l5              <= acc_cnt_l4 ;  
            
            acc_collision_cnt_l1    <= acc_collision_cnt ;                  -- Pipeline - Filter coefficient data batch sequencer enable signal 
            acc_collision_cnt_l2    <= acc_collision_cnt_l1 ; 
            acc_collision_cnt_l3    <= acc_collision_cnt_l2 ; 
            acc_collision_cnt_l4    <= acc_collision_cnt_l3 ; 
            
            acc_control_en          <= acc_cnt_l5 or acc_collision_cnt_l4;  -- Accumulator enable signal
            
            filter_seq_en           <= acc_cnt_l1 or acc_collision_cnt;     -- Filter coefficient data batch sequencer enable signal 
        
        end if;  
    end if; 
end process enable_signal_pipeline;


-- Filter coefficient data read batch sequencer.
-- Controlled by "enable_signal_pipeline" process. 
-- Outputs: filter coefficient array containing 8 filter coefficients for one batch. 
filter_data_sequencer:process(clk)
begin

    if rising_edge(clk) then
    
        if(rst = '1') then
            filter_count <= 0;
        else
    
            if ( filter_seq_en = '1') then 
            
                -- Preparing 8 data batches of filter coefficients
                for i in 0 to 7 loop
                    filter_bram_reg(i)  <= signed(filter_data(i + filter_count));
                end loop; 
                
                -- Checking for the end of data batch
                if (filter_count = batch_number) then
                    filter_count        <= 0;  
                else
                    filter_count        <= filter_count + 8;  
                end if;
                
            end if; 
        
        end if;  
    end if;
end process filter_data_sequencer;


-- Vector multiplication of 8 input data and filter coefficient data.
-- Latency: 1 clk cycle.
multiplication_8x:process(clk)
begin

    if rising_edge(clk) then

        -- x8 vector multiplication
        for i in 0 to 7 loop
            mult_vector(i) <= data_bram_reg(i) * filter_bram_reg(i);   
        end loop;
  
    end if;
end process multiplication_8x;


-- Adder tree which accumulates 8 multiplication data for each data batch.
-- Latency: 3 clk cycles.
accumulation_8x:process(clk)
begin

    if rising_edge(clk) then
  
        -- Adder tree to accumulate multiplied data
        -- First level of adder tree - Add 4 pairs
        for i in 0 to 3 loop
            batch_sum_l1(i) <= mult_vector(2*i)(upper_bit downto lower_bit) + mult_vector(2*i + 1)(upper_bit downto lower_bit);
        end loop;
        
        -- Second level of adder tree - Add 2 pairs
        for i in 0 to 1 loop
            batch_sum_l2(i) <= batch_sum_l1(2*i) + batch_sum_l1(2*i + 1);
        end loop;
        
        -- Third level of adder tree - Add 1 pair
        -- Total sum of the 8 data in 1 batch
        batch_sum <= batch_sum_l2(0) + batch_sum_l2(1); -- batch sum
 
    end if;
end process accumulation_8x;


-- Accumulation controller which generates enable signal for each data batch.
-- Controlled by "enable_signal_pipeline" process.
batch_accumulation_controller:process(clk)
begin

    if rising_edge(clk) then
    
        if ( acc_control_en = '1') then 
        
            if (acc_batch_count = 0) then               -- Batch accumulation started
                batch_acc_cmd   <= "00";    
                acc_batch_count <= 1;
                
                acc_data_ready  <= '0';
            
            -- Checking the end of batch    
            elsif (acc_batch_count = batch_cycle) then  -- Batch accumulation completed
                batch_acc_cmd   <= "01";
                acc_batch_count <= 0;
                
                acc_data_ready  <= '1';                 -- Accumulated data for 1 batch is ready indicator
                
            else                                        -- Batch accumulation continues
                batch_acc_cmd   <= "01";
                acc_batch_count <= acc_batch_count + 1;
                
                acc_data_ready  <= '0';
            end if;
            
        else
        
            if(module_rst = '1') then
                batch_acc_cmd       <= "11";            -- Batch accumulation reset 
                acc_batch_count     <= 0;
                acc_data_ready      <= '0';
            else
                batch_acc_cmd       <= "10";            -- Batch accumulation halted  
                acc_batch_count     <= acc_batch_count;
                acc_data_ready      <= '0';  
            end if;
              
        end if; 
    end if;
end process batch_accumulation_controller;


-- Accumulating data batches.
-- Controlled by "accumulation_controller" process.
batch_accumulation:process(clk) 
begin

    if rising_edge(clk) then

        -- Checking accumulation command 
        if ( batch_acc_cmd = "00" ) then                    -- Batch accumulation started
            batch_sum_reg <= batch_sum;
        
        elsif ( batch_acc_cmd = "01" ) then                 -- Batch accumulation continues
            batch_sum_reg <= batch_sum_reg + batch_sum;   
            
        elsif ( batch_acc_cmd = "10" ) then                 -- Batch accumulation halted
            batch_sum_reg <= batch_sum_reg;                 
        
        else                                                -- Reset case
            batch_sum_reg <= (others=>'0'); 
            
        end if; 
   
    end if;
end process batch_accumulation;


-- Counting completed convolution operation for 1 filter stride position.
-- Generating BRAM write signal to write result to the BRAM.
operation_counter: process(clk)
begin

     if rising_edge (clk) then
     
        if(rst = '1') then 
            wr_count     <= 0;  
        else
            -- Checking completed convolution operation for 1 filter stride position
            if (acc_data_ready = '1') then 
                
                wr_bram_data    <= '1';
                wr_count        <= wr_count + 1;  
            else 
               
                wr_bram_data    <= '0';
            end if;
        
        end if;
        
    end if;    
end process operation_counter;     


-- Write result to the BRAM.
write_result_to_bram: process(clk)
begin

     if rising_edge (clk) then
     
        if(rst = '1') then 
        
            bram_result_ena     <= 'Z';
            bram_result_wea     <= "Z";
            bram_result_addra   <= (others=>'Z');
            bram_result_dina    <= (others=>'Z');
            op_end              <= '0'; 
            
        else
     
            if (wr_bram_data = '1') then 
            
                -- Write access to BRAM
                bram_result_ena     <= '1';
                bram_result_wea     <= "1";
                bram_result_addra   <= std_logic_vector(to_unsigned(wr_count,bram_result_addra'length));
                bram_result_dina    <= std_logic_vector(batch_sum_reg);
                
                -- End of operation check
                if( wr_count = out_size ) then
                    op_end <= '1';   -- End of operation
                else
                    op_end <= '0';
                end if;
                
            else
                bram_result_ena     <= 'Z';
                bram_result_wea     <= "Z";
                bram_result_addra   <= (others=>'Z');
                bram_result_dina    <= (others=>'Z');
                op_end              <= '0';
                
            end if;
            
        end if;   
     end if;
end process write_result_to_bram; 


end  behavioral;