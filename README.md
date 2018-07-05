# project
From the ztex_hardware/ztex/java/DeviceServer directory run the command, 
./DeviceServer -ha <ip address> -sp -1 -v -l2 logfile.
Once the device server is running you should be able to access the ztex board via browser at http://<ip address>:9080

To program you need to erase the bit file in memory and replace it with the new bitfile.
1.	Go to the Bitstream Upload section, check “Erase bitstream in non-volatile memory” and click submit. The device server messages section at the bottom should tell you that the erase has been completed.
At this point I usually unplug the usb and plug it back in. The light on the ztek board should remain on because the fpga has not been programmed as there is no bit file in memory.
2.	Go back to the bitstream upload section, deselect the “Erase bitstream in non-volatile memory”, select “Upload to non-volatile memory”, click “browse”, select the bit file, and click “submit”. The Device Server Messages section should report that the bitstream has been loaded to non-volatile memory.
3.	Power cycle again and this time the light on the ztek should go off after the FPGA is programmed. 

Note that the Firmware Upload section looks very similar to the Bitstream upload section. Make sure you are erasing the and loading the Bitstream and not the wiping out the Firmware.


FYI – 

Pinout.
# Transmit and receive
NET "rxa_p_BC"     LOC = "T12" | IOSTANDARD = LVCMOS33;                    # IO A3
NET "rxa_n_BC"     LOC = "T14" | IOSTANDARD = LVCMOS33;                    # IO A4
NET "txa_p_BC"    LOC = "T15" | IOSTANDARD = LVCMOS33 | DRIVE = 12;        # IO A5 
NET "txa_n_BC"    LOC = "R16" | IOSTANDARD = LVCMOS33 | DRIVE = 12;        # IO A6 

# Capture signal outputs
NET "csw"                  LOC = "R12" | IOSTANDARD = LVCMOS33 | DRIVE = 12 ;    # B3 
NET "dw"                   LOC = "T13" | IOSTANDARD = LVCMOS33 | DRIVE = 12 ;    # B4 
NET "enc_data_en"        LOC = "R14" | IOSTANDARD = LVCMOS33 | DRIVE = 12 ;      # B5 
NET "enc_data"     LOC = "R15" | IOSTANDARD = LVCMOS33 | DRIVE = 12 ;            # B6 

# Trigger signals 
NET "triggerA" LOC = "P15" | IOSTANDARD = LVCMOS33 ;                           # B7 / P15~IO_L48P_HDC_M1DQ8_1  
NET "triggerB" LOC = "N14" | IOSTANDARD = LVCMOS33 ;                           # B8 / N14~IO_L45P_A1_M1LDQS_1  
NET "triggerC" LOC = "M15" | IOSTANDARD = LVCMOS33 ;                           # B9 / M15~IO_L46P_FCS_B_M1DQ2_1

#inputs switch8 is the bypass signal. It should be pulled high. If you want to take the FPGA out of bypass mode this line needs to be tied to GND.
NET "switch8"   LOC = "L14" | IOSTANDARD = LVCMOS33 | PULLUP ;                          # B11 / L14~IO_L47P_FWE_B_M1DQ0_1
