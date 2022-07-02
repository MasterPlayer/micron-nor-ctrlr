library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_logic_unsigned.all;
    use ieee.std_Logic_arith.all;

library UNISIM;
    use UNISIM.VComponents.all;

entity micron_nor_rescue is
    generic(
        MODE                :           string := "STARTUPE"                 
    );
    port(
        CLK                 :   in      std_logic                           ;
        RESET               :   in      std_logic                           ;

        START               :   in      std_Logic                           ;
        PAUSE               :   in      std_Logic_vector ( 15 downto 0 )    ;

        C                   :   out     std_logic                           ;

        RESET_OUT           :   out     std_logic                           ;

        DQ_I                :   in      std_Logic_Vector ( 3 downto 0 )     ;
        DQ_T                :   out     std_Logic_Vector ( 3 downto 0 )     ;
        DQ_O                :   out     std_Logic_Vector ( 3 downto 0 )     ;

        S                   :   out     std_logic                           
    );
end micron_nor_rescue;



architecture micron_nor_rescue_arch of micron_nor_rescue is

    type fsm is (
        IDLE_ST                    ,

        RESCUE_SEQUENCE_ST_0       , -- 7
        RESCUE_SEQUENCE_STUB_ST_0  , -- 7
        RESCUE_SEQUENCE_ST_1       , -- 9
        RESCUE_SEQUENCE_STUB_ST_1  , -- 9
        RESCUE_SEQUENCE_ST_2       , -- 13
        RESCUE_SEQUENCE_STUB_ST_2  , -- 13
        RESCUE_SEQUENCE_ST_3       , -- 17
        RESCUE_SEQUENCE_STUB_ST_3  , -- 17
        RESCUE_SEQUENCE_ST_4       , -- 25
        RESCUE_SEQUENCE_STUB_ST_4  , -- 25
        RESCUE_SEQUENCE_ST_5       , -- 33
        RESCUE_SEQUENCE_STUB_ST_5  , -- 33

        WRITE_NVREG_PREPARE_ST     ,
        WRITE_NVREG_ST             , --
        WRITE_NVREG_STUB_ST        ,

        PROTOCOL_0_RESET_ST        ,
        PROTOCOL_0_RESET_STUB_ST   ,

        PROTOCOL_1_RESET_ST        ,
        PROTOCOL_1_RESET_STUB_ST   , 

        READ_ID_CMD_ST             ,
        READ_ID_DATA_ST             
        

    );

    signal  current_state : fsm := IDLE_ST;

    signal  word_cnt : std_logic_Vector ( 31 downto 0 ) := (others => '0');

    signal  dq_t_reg        :       std_Logic_Vector ( 3 downto 0 ) := (others => '0')  ;
    signal  dq_o_reg        :       std_Logic_Vector ( 3 downto 0 ) := (others => '0')  ;

    signal  s_reg           :       std_Logic                       := '0'              ;

    signal  oddre1_d2       :       std_logic := '0';

    signal  counter         :       std_Logic_Vector ( 7 downto 0 ) := (others => '0') ;

    signal  nvreg_cmd       :       std_logic_Vector ( 23 downto 0 ) := (others => '0'); 
    signal  readid_cmd      :       std_logic_Vector (  7 downto 0 ) := (others => '0'); 

    signal  reset_out_reg   :       std_logic                           ;

begin

    RESET_OUT   <= reset_out_reg;
    DQ_T        <= dq_t_reg;
    DQ_O        <= dq_o_reg;
    S           <= s_reg;

    GEN_MODE_STARTUPE : if MODE = "STARTUPE" generate

        bufgce_inst : BUFGCE
            generic map (
                CE_TYPE         =>  "SYNC"          ,   -- ASYNC, HARDSYNC, SYNC
                IS_CE_INVERTED  =>  '0'             ,   -- Programmable inversion on CE
                IS_I_INVERTED   =>  '1'                 -- Programmable inversion on I
            )
            port map (
                O               =>  C               ,   -- 1-bit output: Buffer
                CE              =>  '1'             ,   -- 1-bit input: Buffer enable
                I               =>  oddre1_d2           -- 1-bit input: Buffer
            );

    end generate;

    GEN_MODE_STARTUPE : if MODE = "DIRECT" generate

        oddre1_inst : ODDRE1
            generic map (
                IS_C_INVERTED   =>  '0'             ,   -- Optional inversion for C
                IS_D1_INVERTED  =>  '0'             ,   -- Unsupported, do not use
                IS_D2_INVERTED  =>  '0'             ,   -- Unsupported, do not use
                SIM_DEVICE      =>  "ULTRASCALE"    ,   -- Set the device version (ULTRASCALE)
                SRVAL           =>  '0'                 -- Initializes the ODDRE1 Flip-Flops to the specified value ('0', '1')
            )
            port map (
                Q               =>  C               ,   -- 1-bit output: Data output to IOB
                C               =>  CLK             ,   -- 1-bit input: High-speed clock input
                D1              =>  '0'             ,   -- 1-bit input: Parallel data input 1
                D2              =>  oddre1_d2       ,   -- 1-bit input: Parallel data input 2
                SR              =>  '0'                 -- 1-bit input: Active High Async Reset
            );

    end generate;

    reset_out_reg_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            if RESET = '1' then 
                reset_out_reg <= '0';
            else
                case current_state is

                    when others => 
                        reset_out_reg <= '1';

                end case;
            end if;
        end if;
    end process;

    counter_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            case current_state is
                when IDLE_ST => 
                    counter <= (others => '1');
                
                when others => 
                    if oddre1_d2 = '1' then 
                        counter <= counter + 1;
                    else
                        counter <= counter;    
                    end if;

            end case;
        end if;
    end process;

    nvreg_cmd_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            case current_state is

                when WRITE_NVREG_ST => 
                    nvreg_cmd <= nvreg_cmd (22 downto 0 ) & '0';

                when others => 
                    nvreg_cmd <= x"B1FFFF";

            end case;
        end if;
    end process;

    readid_cmd_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            case current_state is
                when READ_ID_CMD_ST => 
                    readid_cmd <= readid_cmd ( 6 downto 0 ) & '0';

                when others => 
                    readid_cmd <= x"9E";
            end case;
        end if;
    end process;

    current_state_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            if RESET = '1' then 
                current_state <= IDLE_ST;
            else
                
                case current_state is
                    
                    when IDLE_ST => 
                        if START = '1' then 
                            current_state <= RESCUE_SEQUENCE_ST_0;
                        else
                            current_state <= current_state;
                        end if;

                    when RESCUE_SEQUENCE_ST_0 =>  -- 7
                        if word_cnt < 6 then 
                            current_state <= current_state;
                        else
                            current_state <= RESCUE_SEQUENCE_STUB_ST_0;
                        end if;

                    when RESCUE_SEQUENCE_STUB_ST_0 => 
                        current_state <= RESCUE_SEQUENCE_ST_1;

                    when RESCUE_SEQUENCE_ST_1 =>  -- 9
                        if word_cnt < 8 then 
                            current_state <= current_state;
                        else
                            current_state <= RESCUE_SEQUENCE_STUB_ST_1;
                        end if;

                    when RESCUE_SEQUENCE_STUB_ST_1 => 
                        current_state <= RESCUE_SEQUENCE_ST_2;

                    when RESCUE_SEQUENCE_ST_2 =>  -- 13
                        if word_cnt < 12 then 
                            current_state <= current_state;
                        else
                            current_state <= RESCUE_SEQUENCE_STUB_ST_2;
                        end if;

                    when RESCUE_SEQUENCE_STUB_ST_2 => 
                        current_state <= RESCUE_SEQUENCE_ST_3;

                    when RESCUE_SEQUENCE_ST_3 =>  -- 17
                        if word_cnt < 16 then 
                            current_state <= current_state;
                        else
                            current_state <= RESCUE_SEQUENCE_STUB_ST_3;
                        end if;

                    when RESCUE_SEQUENCE_STUB_ST_3 => 
                        current_state <= RESCUE_SEQUENCE_ST_4;

                    when RESCUE_SEQUENCE_ST_4 =>  -- 25
                        if word_cnt < 24 then 
                            current_state <= current_state;
                        else
                            current_state <= RESCUE_SEQUENCE_STUB_ST_4;
                        end if;

                    when RESCUE_SEQUENCE_STUB_ST_4 => 
                        current_state <= RESCUE_SEQUENCE_ST_5;

                    when RESCUE_SEQUENCE_ST_5 =>  -- 33
                        if word_cnt < 32 then 
                            current_state <= current_state;
                        else
                            current_state <= RESCUE_SEQUENCE_STUB_ST_5;
                        end if;

                    when RESCUE_SEQUENCE_STUB_ST_5 => 
                        current_state <= PROTOCOL_0_RESET_ST;

                    when PROTOCOL_0_RESET_ST =>
                        if word_cnt < 7 then 
                            current_state <= current_state;
                        else
                            current_state <= PROTOCOL_0_RESET_STUB_ST;
                        end if; 

                    when PROTOCOL_0_RESET_STUB_ST => 
                        --current_state <= PROTOCOL_1_RESET_ST;
                        current_state <= WRITE_NVREG_PREPARE_ST;

                    when PROTOCOL_1_RESET_ST => 
                        if word_cnt < 15 then 
                            current_state <= current_state;
                        else
                            current_state <= PROTOCOL_1_RESET_STUB_ST;
                        end if; 
                        
                    when PROTOCOL_1_RESET_STUB_ST => 
                        current_state <= WRITE_NVREG_PREPARE_ST;

                    when WRITE_NVREG_PREPARE_ST =>
                        if word_cnt < 10 then 
                            current_state <= current_state;
                        else
                            current_state <= WRITE_NVREG_ST;
                        end if;

                    when WRITE_NVREG_ST =>  -- 
                        if word_cnt < 23 then 
                            current_state <= current_state;
                        else
                            current_state <= WRITE_NVREG_STUB_ST;
                        end if;

                    when WRITE_NVREG_STUB_ST => 
                        current_state <= READ_ID_CMD_ST;

                    when READ_ID_CMD_ST => 
                        if word_cnt < 7 then 
                            current_state <= current_state;
                        else
                            current_state <= READ_ID_DATA_ST;
                        end if;

                    when READ_ID_DATA_ST =>
                        if word_cnt < 159 then 
                            current_state <= current_state;
                        else
                            current_state <= IDLE_ST;
                        end if;

                    when others => 
                        current_state <= IDLE_ST;
                
                end case;
            end if;
        end if;
    end process;

    oddre1_d2_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            case current_state is

                when IDLE_ST => 
                    if START = '1' then 
                        oddre1_d2 <= '1';
                    else
                        oddre1_d2 <= '0';
                    end if;

                when RESCUE_SEQUENCE_ST_0 | RESCUE_SEQUENCE_ST_1 | RESCUE_SEQUENCE_ST_2 | RESCUE_SEQUENCE_ST_3 | RESCUE_SEQUENCE_ST_4 | RESCUE_SEQUENCE_ST_5 =>
                    oddre1_d2 <= '1';

                when RESCUE_SEQUENCE_STUB_ST_0 | RESCUE_SEQUENCE_STUB_ST_1 | RESCUE_SEQUENCE_STUB_ST_2 | RESCUE_SEQUENCE_STUB_ST_3 | RESCUE_SEQUENCE_STUB_ST_4 | RESCUE_SEQUENCE_STUB_ST_5 => 
                    oddre1_d2 <= '1';

                when PROTOCOL_0_RESET_ST | PROTOCOL_1_RESET_ST => 
                    oddre1_d2 <= '1';

                when WRITE_NVREG_PREPARE_ST => 
                    if word_cnt < 10 then 
                        oddre1_d2 <= '0';
                    else
                        oddre1_d2 <= '1';
                    end if;

                when WRITE_NVREG_ST =>  -- 
                    if word_cnt < 23 then 
                        oddre1_d2 <= '1';
                    else
                        oddre1_d2 <= '0';
                    end if;

                when WRITE_NVREG_STUB_ST => 
                    oddre1_d2 <= '1';

                when READ_ID_CMD_ST => 
                    oddre1_d2 <= '1';

                when READ_ID_DATA_ST =>
                    if word_cnt < 159 then 
                        oddre1_d2 <= '1';
                    else
                        oddre1_d2 <= '1';
                    end if;

                when others => 
                    oddre1_d2 <= '0';
            end case;
        end if;
    end process;

    word_cnt_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            case current_state is

                when RESCUE_SEQUENCE_ST_0 =>  -- 7
                    if word_cnt < 6 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when RESCUE_SEQUENCE_ST_1 =>  -- 9
                    if word_cnt < 8 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when RESCUE_SEQUENCE_ST_2 =>  -- 13
                    if word_cnt < 12 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when RESCUE_SEQUENCE_ST_3 =>  -- 17
                    if word_cnt < 16 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when RESCUE_SEQUENCE_ST_4 =>  -- 25
                    if word_cnt < 24 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when RESCUE_SEQUENCE_ST_5 =>  -- 33
                    if word_cnt < 32 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when WRITE_NVREG_PREPARE_ST =>  
                    if word_cnt < 10 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when WRITE_NVREG_ST =>  -- 
                    if word_cnt < 23 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when PROTOCOL_0_RESET_ST => 
                    if word_cnt < 7 then 
                        word_cnt <= word_cnt + 1; 
                    else
                        word_cnt <= (others => '0');
                    end if;

                when PROTOCOL_1_RESET_ST => 
                    if word_cnt < 15 then 
                        word_cnt <= word_cnt + 1; 
                    else
                        word_cnt <= (others => '0');
                    end if;

                when READ_ID_CMD_ST => 
                    if word_cnt < 7 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when READ_ID_DATA_ST =>
                    if word_cnt < 159 then 
                        word_cnt <= word_cnt + 1;
                    else
                        word_cnt <= (others => '0');
                    end if;

                when others => 
                    word_cnt <= (others => '0');

            end case;
        end if;
    end process;

    dq_t_reg_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            case current_state is
                
                when IDLE_ST => 
                    if START = '1' then 
                        dq_t_reg <= "0110";
                    else
                        dq_t_reg <= "1110";
                    end if;

                when RESCUE_SEQUENCE_ST_0 =>  -- 7
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_STUB_ST_0 => 
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_ST_1 =>  -- 9
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_STUB_ST_1 => 
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_ST_2 =>  -- 13
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_STUB_ST_2 => 
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_ST_3 =>  -- 17
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_STUB_ST_3 => 
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_ST_4 =>  -- 25
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_STUB_ST_4 => 
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_ST_5 =>  -- 33
                    dq_t_reg <= "0110";

                when RESCUE_SEQUENCE_STUB_ST_5 => 
                    dq_t_reg <= "0110";

                when PROTOCOL_0_RESET_ST =>
                    dq_t_reg <= "0110";

                when PROTOCOL_0_RESET_STUB_ST => 
                    dq_t_reg <= "0110";

                when PROTOCOL_1_RESET_ST => 
                    dq_t_reg <= "0110";
                    
                when PROTOCOL_1_RESET_STUB_ST => 
                    dq_t_reg <= "0110";

                when WRITE_NVREG_PREPARE_ST => 
                    dq_t_reg <= "1110";

                when WRITE_NVREG_ST =>  -- 
                    dq_t_reg <= "1110";

                when WRITE_NVREG_STUB_ST => 
                    dq_t_reg <= "1110";


                when READ_ID_CMD_ST => 
                    dq_t_reg <= "1110";

                when READ_ID_DATA_ST =>
                    dq_t_reg <= "1110";

                when others => 
                    dq_t_reg <= "1110";
            
            end case;
        end if;
    end process;
    
    dq_o_reg_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            if RESET = '1' then 
                dq_o_reg <= (others => '0');
            else
                case current_state is
 
                    when RESCUE_SEQUENCE_ST_0 | RESCUE_SEQUENCE_ST_1 | RESCUE_SEQUENCE_ST_2 | RESCUE_SEQUENCE_ST_3 | RESCUE_SEQUENCE_ST_4 | RESCUE_SEQUENCE_ST_5 => 
                        dq_o_reg <= "1111";

                    when WRITE_NVREG_PREPARE_ST => 
                        dq_o_reg <= "0000";

                    when WRITE_NVREG_ST => 
                        dq_o_reg(0) <= nvreg_cmd(23); dq_o_reg(3 downto 1) <= "000"; 

                    when READ_ID_CMD_ST => 
                        dq_o_reg(0) <= readid_cmd(7); dq_o_reg(3 downto 1) <= "000";

                    when others => 
                        dq_o_reg <= "1111";

                end case;
            end if;
        end if;
    end process;

    s_reg_processing : process(CLK)
    begin
        if CLK'event AND CLK = '1' then 
            if RESET = '1' then 
                s_reg <= '1';
            else
                case current_state is

                    when IDLE_ST => 
                        s_reg <= '1';

                    when RESCUE_SEQUENCE_ST_0 | RESCUE_SEQUENCE_ST_1 | RESCUE_SEQUENCE_ST_2 | RESCUE_SEQUENCE_ST_3 | RESCUE_SEQUENCE_ST_4 | RESCUE_SEQUENCE_ST_5 => 
                        s_reg <= '0';

                    when PROTOCOL_0_RESET_ST | PROTOCOL_1_RESET_ST => 
                        s_reg <= '0';

                    when WRITE_NVREG_ST => 
                        s_reg <= '0';

                    when READ_ID_CMD_ST => 
                        s_reg <= '0';

                    when READ_ID_DATA_ST => 
                        s_reg <= '0';

                    when others => 
                        s_reg <= '1';

                end case;
            end if;
        end if;     
    end process;




end micron_nor_rescue_arch;


