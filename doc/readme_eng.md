# micron_nor_rescue

Component for recovery access to NOR MT25Q, if this access blocked. It may appear when flash programming(or other operations which work with NOR) over Vivado IDE errors occur, and non-volatile register setup in uncompatible mode with Vivado IDE by default. In this case, access to NOR is lost, and needs to go to default state by reset to default configuration for next interactions for flash

Component generate sequences, which described in section named "Power Loss and Interface Rescue", and supports connection over STARTUPE primitive or direct connection. 
- When Startupe primitive connection required, set up `MODE = "STARTUPE"`
- When direct connection required, set up `MODE = "DIRECT`

Note: STARTUPE primitive not placed in this component. Connection and using startupe component must be outside this component

Next code for demonstrate connection over primitive STARTUPE (Kintex UltraScale):

```
    micron_nor_rescue micron_nor_rescue_inst (
        .CLK      (clk_100    ), // Stable clock 
        .RESET    (reset_100  ), // Reset signal 
        .START    (start      ), 
        .C        (flash_clk  ), // signal from component to primitive STARTUP for using as clock
        .RESET_OUT(           ), // signal reset from component to FLASH component, unused when MODE = "STARTUPE"
        .DQ_I     (dq_i       ), // signal to/from startupe primitive
        .DQ_T     (dq_t       ), // signal to/from startupe primitive
        .DQ_O     (dq_o       ), // signal to/from startupe primitive
        .S        (flash_cs0  )  // chip select to FCS_B port in startupe 
    );

    STARTUPE3 #(
        .PROG_USR     ("FALSE"), // Activate program event security feature. Requires encrypted bitstreams.
        .SIM_CCLK_FREQ(6.6    )  // Set the Configuration Clock Frequency (ns) for simulation
    ) startupe3_inst (
        .CFGCLK   (         ), // 1-bit output: Configuration main clock output
        .CFGMCLK  (         ), // 1-bit output: Configuration internal oscillator clock output
        .DI       (dq_i[0]  ), // 4-bit output: Allow receiving on the D input pin
        .EOS      (         ), // 1-bit output: Active-High output signal indicating the End Of Startup
        .PREQ     (         ), // 1-bit output: PROGRAM request to fabric output
        .DO       (dq_o[0]  ), // 4-bit input: Allows control of the D pin output
        .DTS      (dq_t[0]  ), // 4-bit input: Allows tristate of the D pin
        .FCSBO    (flash_cs0), // 1-bit input: Controls the FCS_B pin for flash access
        .FCSBTS   (1'b0     ), // 1-bit input: Tristate the FCS_B pin
        .GSR      (1'b0     ), // 1-bit input: Global Set/Reset input (GSR cannot be used for the port)
        .GTS      (1'b0     ), // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
        .KEYCLEARB(1'b1     ), // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
        .PACK     (1'b1     ), // 1-bit input: PROGRAM acknowledge input
        .USRCCLKO (flash_clk), // 1-bit input: User CCLK input
        .USRCCLKTS(1'b0     ), // 1-bit input: User CCLK 3-state enable input
        .USRDONEO (1'b1     ), // 1-bit input: User DONE pin output control
        .USRDONETS(1'b0     )  // 1-bit input: User DONE 3-state enable output
    );
```

How to work with component :
1. Power-up FPGA 
2. Program FPGA with firmware, which consists of this component
3. Generate START signal 
4. Power-off FPGA 
5. Power-up FPGA 
6. Program FPGA over Vivado IDE and check workability with FLASH

if no result, try steps 1-5 again


# axis_micron_nor_ctrlr_x4

Component for work with Micron NOR MT25Q with support QuadSPI mode over 4 bits bidirectional bus. Supports read/program/erase operations, and read status. Supports various operations of erase. Work with commands from datasheet on MT25Q. By default after reset sets four-byte addressation mode, because work with flash which size is 1 gbit. 

Other operating options than QuadSPI not available

Note : 1 sector = 64 KByte

## Support Command list
CMD | Code | Desc
----|------|-----
Read | 0x0b, 0x6b, 0xEB, 0x0C, 0x6C, 0xEC | Read data from FLASH and transmit it over M_AXIS_TDATA. Limitations - size of read bytes should not exceed memory size, control this limitiation externally
Program | 0x3E 0x12 0x34 0x02 0x32 0x38 | Program Flash. Limitations - writing no more than 256 bytes per command
Erase Sector | 0xDC | Erase sector 64 KByte
Erase 4 KB | 0x21 | Erase Subsector 4 KByte
Erase 32 KB | 0x5c | Erase subsector 32 KByte
Erase Chip | 0x4c | Erase 512 MBit of memory

![axis_micron_nor_ctrlr_x4_struct](https://user-images.githubusercontent.com/45385195/177000750-83cf0ce1-8766-4852-a02e-7c30b84a6694.png)



## generic parameters
Parameter | Type | Range | Description 
----------|------|-------|------------
MODE | string | "STARTUPE" or "DIRECT" | select mode connection from component to memory Flash : STARTUPE - Over STARTUPE primitive (0 bank FPGA, make this connection externally), or direct from component to FLASH over bidirectional buffers, which sets externally
ASYNC | boolean | true or false | Ability work with component in different clock domains for SPI_CLK and S_AXIS_CLK В
SWAP_NIBBLE | boolean | true или false | which nibble transmitted firstly : if `SWAP_NIBBLE=true` transmit lower nibble, if `SWAP_NIBBLE=false` firstly transmit high nibble.

## 1. Ports 

### 1.1. AXI-Stream 

Component contains Slave and Master AXI-Stream ports

#### 1.1.1. Slave AXI-Stream 

Clocked with S_AXIS_CLK

Name | Direction | Width | Description
---------|-------------|-------------|-----------
S_AXIS_TDATA | in | 8 | Data signal for program FLASH
S_AXIS_TVALID | in | 1 | Data Valid signal 
S_AXIS_TLAST | in | 1 | End of packet signal 
S_AXIS_TREADY | out | 1 | ready signal from component for ability receive of data

#### 1.1.2. Master AXI-Stream 

clocked with S_AXIS_CLK

Name | Direction | Width | Description
---------|-------------|-------------|-----------
M_AXIS_TDATA | out | 8 | Data signal readed from flash
M_AXIS_TVALID | out | 1 | Data valid signal 
M_AXIS_TLAST | out | 1 | End of packet signal  
M_AXIS_TREADY | in | 1 | ready signal from user logic 


### 1.2. Clock and reset

When  `ASYNC = false` S_AXIS_CLK and SPI_CLK signals connected to common clock signal 

Name | Direction | Width | Description
---------|-------------|-------------|-----------
S_AXIS_CLK | in | 1 | Clock signal for interfaces S_AXIS_*, M_AXIS_*, *S_AXIS_CMD_*
S_AXIS_RESET | in | 1 | Reset signal for internal logic, queues
SPI_CLK | in | 1 | Clock signal for internal logic 
C | out | 1 | clock signal for NOR flash, form from SPI_CLK over primitive

### 1.3. Control signals

Component perform operations, controlled from `S_AXIS_CMD_*`

Name | Direction | Width | Description
---------|-------------|-------------|-----------
S_AXIS_CMD | in | 8 | Command for execution. List of supported command described in [#Support Command List](). Other commands ignored 
S_AXIS_CMD_TSIZE | in | 32 | Number of bytes for PROGRAM or READ command
S_AXIS_CMD_TADDR | in | 32 | Start Address 
S_AXIS_CMD_TVALID | in | 1 | Command valid signal 
S_AXIS_CMD_TREADY | out | 1 | Ready signal for command interface

### 1.4. Status signals 

Name | Direction | Width | Description
---------|-------------|-------------|-----------
FLASH_STATUS | out | 8 | Current status of flash, valided when `FLASH_STATUS_VALID=1`
FLASH_STATUS_VALID | out | 1 | Valid signal 
BUSY | out | 1 | Busy flaq. When FSM doesnt perform operation, this signal is 0, other case is 1


### 1.5. QuadSPI signal group

Name | Direction | Width | Description
---------|-------------|-------------|-----------
C | out | 1 | clock signal from inversion SPI_CLK
RESET_OUT | out | 1 | reset signal FLASH. 
DQ_I | in | 4 | Data signal from flash FLASH
DQ_T | out | 4 | Tri-State control signal
DQ_O | out | 4 | Data signal to FLASH
S | out | 1 | Chip-select for Flash. If = 0, flash works


## 2. Some principles of component operation
- In beginning FLASH should be without preset of QuadSPI mode, in other case not guaranteed work
- Component have initial phase of initialization when sets up 4 byte addressation mode and QuadSPI mode 
- Configuration performs by writing on Volatile Register of FLASH over Extended SPI (serial interface)
- Setting mode of 4-byte address over command `ENABLE_FOUR_BYTE_ADDRESS_MODE` (0xB7)
- Component can read all Flash over 1 command
- Component can erase FLASH by one command, or half-flash, if size of flash = 1 gbit
- Component can write not greater than 256 byte over command, size control not perform in component
- **DATA-BEFORE-COMMAND** mechanism, in other case data might be corrupted
- When execute erase/program operation, component control busy of flash. when Flash goes on IDLE, Busy flag deasserted. User may control BUSY flag
- Component supports two modes of connection - over STARTUPE, or over direct connection. STARTUPE component doesnt presented inside component, and should be installed outside of component. When DIRECT mode connection, bidirectional buffers installed outside of component.
- Support Asyncronous mode of work, when data buses and internal logic clocked by different clock signals
- Reset is optional
- Clock signal always transmit
- CS actived by zero when operation performed. when no operation, CS asserted in 1
- If data read perform, and user logic doesnt receive current portion of data, FSM transmit in WAIT state, but FLASH not transmit this state. This mechanism should be modified

### 2.1 Connection when MODE=STARTUPE

![axis_micron_nor_ctrlr_x4_startupe](https://user-images.githubusercontent.com/45385195/177000713-61488b3f-28f7-4526-86a1-e8251dffa0d3.png)

### 2.2 Connection when MODE=DIRECT

![axis_micron_nor_ctrlr_x4_direct](https://user-images.githubusercontent.com/45385195/177000728-752db03c-c44a-42b7-b653-2ef54ab66198.png)

## 3. Finite-State-Machine (FSM)

### 3.1 Initialization process

![axis_micron_nor_ctrlr_x4_fsm_init](https://user-images.githubusercontent.com/45385195/177000767-8de47547-5e30-40ac-8e2f-489caed4ce7b.png)

#### 3.1.1 Initialization states of FSM

Current state | Actions | Next state | Transition condition
--------------|---------|------------|---------------------
RST_ST | reset signal transmit 1000 clock periods after deassert internal logic reset | W_CFG_REG_WE_CMD_ST | reset counter exceed 1000 clock periods
W_CFG_REG_WE_CMD_ST | send command write enable | V_CFG_REG_WE_STUB_ST | Completely transmit command
V_CFG_REG_WE_STUB_ST | Wait pause 1 clock period | V_CFG_REG_CMD_ST | unconditional
V_CFG_REG_CMD_ST | Send command 0x61 (`WRITE ENHANCED VOLATILE CONFIGURATION REGISTER`) to device | V_CFG_REG_DATA_ST | completely transmit command
V_CFG_REG_DATA_ST | Send new value to register | ENABLE_FOUR_BYTE_PREPARE | data transmit finalize
ENABLE_FOUR_BYTE_PREPARE | Await pause 8 clock period | ENABLE_FOUR_BYTE_CMD_ST | pause 8 clock period finished
ENABLE_FOUR_BYTE_CMD_ST | Send command 0xB7 | FINALIZE_ST | all nibbles transmitted
FINALIZE_ST | End of command | INIT_ST | unconditional
IDLE_ST | nothing | IDLE_ST | unpresent here

#### 3.1.2. Diagram of initialization process

![axis_micron_nor_ctrlr_x4_init](https://user-images.githubusercontent.com/45385195/177000782-f352dd45-22aa-48d7-9c4d-b379ce462398.png)

### 3.2 Program operation

![axis_micron_nor_ctrlr_x4_fsm_program](https://user-images.githubusercontent.com/45385195/177000789-1e18919e-c1da-4418-9a71-b8b7524aad4c.png)

#### 3.2.1. FSM states of program operation

Current state | Actions | Next state | Transition condition
--------------|---------|------------|---------------------
IDLE_ST | Await valid cmd for writeing | PROGRAM_WE_CMD_ST | Input data is empty and PROGRAM command from list 
PROGRAM_WE_CMD_ST | Send Write enable to FLASH | PROGRAM_WE_STUB_ST | Completely transmit command
PROGRAM_WE_STUB_ST | Check data from input | PROGRAM_CMD_ST | If data is presented in input queue
PROGRAM_CMD_ST | Send PROGRAM to FLASH | PROGRAM_ADDR_ST | Completely command transfer
PROGRAM_ADDR_ST | Send Address to FLASH | PROGRAM_DATA_ST | Address transmitted to FLASH
PROGRAM_DATA_ST | Send DATA to FLASH | PROGRAM_DATA_STUB | All volume of DATA writed to FLASH
PROGRAM_DATA_STUB_ST | WAit 1 clock period | READ_STATUS_ST | Unconditional
READ_STATUS_CMD_ST | Send command READ_STATUS (0x70) | READ_STATUS_DATA_ST | Command transmitted
READ_STATUS_DATA_ST | Read Status from flash | READ_STATUS_STUB_ST | Completely readed statys (2 clock periods, 1 byte of data)
READ_STATUS_STUB_ST | Wait 1 clock period | READ_STATUS_CHK_ST | Unconditional
READ_STATUS_CHK_ST | check status | READ_STATUS_CMD_ST | if FLASH status = busy(`bit7=0`), go to new request from flash
READ_STATUS_CHK_ST | check status | FINALIZE_ST | if FLASH status = idle(`bit7=1`), go to finalize command
FINALIZE_ST | Finalize command | IDLE_ST | unconditional

#### 3.2.2 Diagram of program operation

Start

![axis_micron_nor_ctrlr_x4_programstart](https://user-images.githubusercontent.com/45385195/177000792-e3c68291-fa4b-4e92-a0ec-17fd75b4bd00.png)

End 

![axis_micron_nor_ctrlr_x4_programend](https://user-images.githubusercontent.com/45385195/177000795-fc0d98b3-5f0b-4b43-935a-6b061eed4048.png)

### 3.3 Erase operation

![axis_micron_nor_ctrlr_x4_fsm_erase](https://user-images.githubusercontent.com/45385195/177000800-32c6c34c-9eed-4027-8bec-8dab0da7fe13.png)

#### 3.3.1. FSM states of erase operation

Current state | Actions | Next state | Transition condition
--------------|---------|------------|---------------------
IDLE_ST | Wait for valid command of erase | ERASE_WE_CMD_ST | Command queue is not empty and current command is ERASE from list
ERASE_WE_CMD_ST | Send erase valid | ERASE_WE_STUB_ST | Command transmitted
ERASE_WE_STUB_ST | Wait for 1 clk period | ERASE_CMD_ST | Unconditional 
ERASE_CMD_ST | send ERASE command to FLASH | ERASE_ADDR_ST | Command transmittd
ERASE_ADDR_ST | Send Address | ERASE_STUB_ST | Address transmitted
ERASE_STUB_ST | wait for 1 clk period | READ_STATUS_CMD_ST | Unconditional
READ_STATUS_CMD_ST | Send READ_STATUS command (0x70) | READ_STATUS_DATA_ST | command transmitted
READ_STATUS_DATA_ST | Wait status from flash | READ)STATUS_STUB_ST | status readed (2 clock period, 1 byte)
READ_STATUS_STUB_ST | wait for 1 clk_period | READ_STATUS_CHK_ST | Unconditional
READ_STATUS_CHK_ST | check status | READ_STATUS_CMD_ST | if FLASH status = busy(`bit7=0`), go to new request from flash
READ_STATUS_CHK_ST | check status | FINALIZE_ST | if FLASH status = idle(`bit7=1`), go to finalize command
FINALIZE_ST | finalize command | IDLE_ST | Unconditional

### 3.4 Read operation

Warning: state READ_DATA_WAIT_ABILITY uncorrected, need to changes

![axis_micron_nor_ctrlr_x4_fsm_read](https://user-images.githubusercontent.com/45385195/177000802-607f9890-1a0c-4eaa-bf08-2131d50110e9.png)

Current state | Actions | Next state | Transition condition
--------------|---------|------------|---------------------
IDLE_ST | wait valid cmd for reading | READ_CMD_ST | input command queue isnt empty and current command is read 
READ_CMD_ST | transmit read command to FLASH | READ_ADDRESS_ST | command transmitted
READ_ADDRESS_ST | Send address | READ_DUMMY_ST | ADDRESS transmitted
READ_DUMMY_ST | wait for 10 clock period | READ_DATA_ST | internal counter exceeds limit
READ_DATA_ST | read data from flash and transmit to M_AXIS for user level | READ_DATA_WAIT_ABILITY | output queue is full 
READ_DATA_WAIT_ABILITY | wait for output queue is empty | READ_DATA_ST | output queue is empty
READ_DATA_ST | Read data from flash and transmit to output over M_AXIS to user leve | FINALIZE_ST | Number of readed byte exceeded
FINALIZE_ST | Finalize command | IDLE_ST | unconditional

### 3.5 No valid command 

when command not in list of supported command

![axis_micron_nor_ctrlr_x4_fsm_nocmd](https://user-images.githubusercontent.com/45385195/177000807-1048e850-b9a2-4d44-9626-73fc31a0e7eb.png)

## 4. Required external components

Component | Description
----------|------------
[fifo_cmd_sync_xpm](https://github.com/MasterPlayer/micron-nor-ctrlr/blob/main/src_hw/fifo_cmd_sync_xpm.vhd) | input command queue, used when `ASYNC=false`
[fifo_cmd_async_xpm](https://github.com/MasterPlayer/micron-nor-ctrlr/blob/main/src_hw/fifo_cmd_async_xpm.vhd) | input command queue, used when `ASYNC=true`
[fifo_in_sync_xpm](https://github.com/MasterPlayer/micron-nor-ctrlr/blob/main/src_hw/fifo_in_sync_xpm.vhd) | input data queue, used for write operation FLASH when `ASYNC=false`
[fifo_in_async_xpm](https://github.com/MasterPlayer/micron-nor-ctrlr/blob/main/src_hw/fifo_in_async_xpm.vhd) | input data queue, used for write operation FLASH when `ASYNC=true`
[fifo_out_sync_xpm](https://github.com/MasterPlayer/micron-nor-ctrlr/blob/main/src_hw/fifo_out_sync_xpm.vhd) | output data queue, used for read operation when `ASYNC=false`
[fifo_out_async_xpm](https://github.com/MasterPlayer/micron-nor-ctrlr/blob/main/src_hw/fifo_out_async_xpm.vhd) | output data queue, used for read operation when `ASYNC=true`

## 5. Testing

### 5.1 Speeds

Tested with real flash memory `Micron NOR MT25Q`, volume 1 Gbit. 

time for erase and program depends on data. 

Operation | Volume, Bytes | Speed, MB/s | Total Time, seconds
----------|---------------|-------------|--------------------
ERASE_DIE0 | 67108864 | 0.588 | 114 
ERASE_DIE1 | 67108864 | 0.583 | 115
ERASE_SECTOR | 134217728 | 0.571 | 235
ERASE_SUBSECTOR_32K | 134217728 | 0.415 | 324
ERASE_SUBSECTOR_4K | 134217728 | 0.251 | 534
PROGRAM | 134217728 | 1.29 | 104

### 5.2 Timing

Timing estimation based upon BUSY time on each operation

Operation | Size, Bytes | Time AVG, sec | Time MIN, sec | Time MAX, sec
----------|-------------|---------------|---------------|--------------
ERASE | 65536 | 0.115 | 0.121 | 0.110
ERASE | 32768 | 0.080 | 0.123 | 0.076 
ERASE | 4096 | 0.017 | 0.023 | 0.016 
PROGRAM | 256 | 0.000190 | 0.0002 | 0.0001


## 6. Change log

**1. 03.05.2021 : v1.0 - First version**
Component with documentation and pictures

**2. 02.07.2022 : v1.1 - Update description, add recovery module of FLASH**
- add recovery/rescue unit for flash if it is locked state
- update description
- add eng lang description


