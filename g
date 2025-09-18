library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sine_lut_pkg.all;  -- LUT sin 256 mẫu

entity spi_dac_sine is
    Port ( 
        clk_100M   : in  STD_LOGIC;     -- 100 MHz clock
        reset_n    : in  STD_LOGIC;     -- Active-low reset

        -- DAC interface
        dac_cs_n   : out STD_LOGIC;
        dac_sck    : out STD_LOGIC;
        dac_sdi    : out STD_LOGIC
       -- index_tb :   out unsigned( 7 downto 0)
    );
end spi_dac_sine;

architecture rtl of spi_dac_sine is
    -- FSM state
    type state_type is (IDLE, LOAD, TRANSMIT, FINISH);
    signal state_reg, state_next : state_type;

    -- Counters
    signal bit_count_reg, bit_count_next : unsigned(4 downto 0);
    signal sck_count_reg, sck_count_next : unsigned(2 downto 0);

    -- Shift register for SPI
    signal shift_reg, shift_reg_next : std_logic_vector(15 downto 0);

    -- LUT index
    signal index : unsigned(12 downto 0) := (others => '0');
    signal sine_sample : std_logic_vector(15 downto 0);

    -- Outputs
    signal dac_cs_n_reg, dac_cs_n_next : std_logic;
    signal dac_sck_reg, dac_sck_next   : std_logic;
    signal dac_sdi_reg, dac_sdi_next   : std_logic;

begin

  --  index_tb <= index;
    ------------------------------------------------
    -- Gen sine từ LUT
    ------------------------------------------------
    sine_sample <= "0111" & sine_lut(to_integer(index));

    ------------------------------------------------
    -- Register process
    ------------------------------------------------
    process(clk_100M, reset_n)
    begin
        if reset_n = '0' then
            state_reg <= IDLE;
            bit_count_reg <= (others => '0');
            sck_count_reg <= (others => '0');
            shift_reg <= (others => '0');
            index <= (others => '0');

            dac_cs_n_reg <= '1';
            dac_sck_reg  <= '0';
            dac_sdi_reg  <= '0';
        elsif rising_edge(clk_100M) then
            state_reg <= state_next;
            bit_count_reg <= bit_count_next;
            sck_count_reg <= sck_count_next;
            shift_reg <= shift_reg_next;

            dac_cs_n_reg <= dac_cs_n_next;
            dac_sck_reg  <= dac_sck_next;
            dac_sdi_reg  <= dac_sdi_next;

            -- Khi kết thúc gửi 1 mẫu thì tăng index
            if (state_reg = FINISH) then
                index <= index + 1;
            end if;
        end if;
    end process;

    ------------------------------------------------
    -- Next state logic
    ------------------------------------------------
    process(state_reg, bit_count_reg, sck_count_reg, shift_reg,
            dac_cs_n_reg, dac_sck_reg, dac_sdi_reg, sine_sample)
    begin
        -- giữ giá trị mặc định
        state_next <= state_reg;
        bit_count_next <= bit_count_reg;
        sck_count_next <= sck_count_reg;
        shift_reg_next <= shift_reg;

        dac_cs_n_next <= dac_cs_n_reg;
        dac_sck_next  <= dac_sck_reg;
        dac_sdi_next  <= dac_sdi_reg;

        case state_reg is
            when IDLE =>
                dac_cs_n_next <= '1';
                dac_sck_next <= '0';
                sck_count_next <= (others => '0');
                -- luôn load mẫu mới
                state_next <= LOAD;

            when LOAD =>
                shift_reg_next <= sine_sample;
                bit_count_next <= to_unsigned(15, 5);
                dac_cs_n_next <= '0';
                state_next <= TRANSMIT;

            when TRANSMIT =>
                sck_count_next <= sck_count_reg + 1;

                case sck_count_reg is
                    when "000" =>
                        dac_sck_next <= '0';
                        dac_sdi_next <= shift_reg(15);

                    when "010" =>
                        dac_sck_next <= '1';

                    when "100" =>
                        dac_sck_next <= '0';
                        shift_reg_next <= shift_reg(14 downto 0) & '0';
                        if bit_count_reg = 0 then
                            state_next <= FINISH;
                        else
                            bit_count_next <= bit_count_reg - 1;
                        end if;
                        sck_count_next <= (others => '0');

                    when others =>
                        null;
                end case;

            when FINISH =>
                dac_cs_n_next <= '1';
                dac_sck_next  <= '0';
                state_next <= IDLE;
        end case;
    end process;

    ------------------------------------------------
    -- Output map
    ------------------------------------------------
    dac_cs_n <= dac_cs_n_reg;
    dac_sck  <= dac_sck_reg;
    dac_sdi  <= dac_sdi_reg;

end rtl;
