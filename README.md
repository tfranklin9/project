Readme
======

Unzip the project, project-develop.zip.

Unzip the Ztex Hardware file, ztex-171119.zip.

Building the project.

Generating a bit file should be relatively straight forward.

1.  From ISE, open the the project, core\_1553.xise.

> The archived project targets the Spartan6 LX25. The part can be changed to the LX16 by right clicking on top\_1553 in ISE\'s hierarchy view and changing the part in \'Design Properties\'.

2.  In the Processing window pane, right click on \'Generate Programming file\' and select \'ReRun All\'.

Loading the Bitfile.

1.  From the /ztex/java/DeviceServer directory run the command,

> ./DeviceServer -ha \<ip address\> -sp -1 -v -l2 logfile.

2.  Once the device server is running you should be able to access the ztex board via browser at http://\<ip address\>:9080

Once connected via USB you can erase the bit file in memory and replace it with a new bitfile.

3.  In the Bitstream Upload section, check "Erase bitstream in non-volatile memory" and click submit. The device server messages section at the bottom should tell you that the erase has been completed.

4.  Disconnect the usb and plug it back in. The light on the ztek board should remain on because the fpga has not been programmed as there is no bit file in memory.

5.  In the bitstream upload section, deselect the "Erase bitstream in non-volatile memory", select "Upload to non-volatile memory", click "browse", select the bit file from the project's core\_1553 directory, and click "submit". The Device Server Messages section should report that the bitstream has been loaded to non-volatile memory.

6.  Power cycle again and this time the light on the ztek should go off after the FPGA is programmed.

*Note that the Firmware Upload section looks very similar to the Bitstream upload section. Make sure you are erasing and loading the Bitstream and not the Firmware.*

FPGA Pinout.

\# Transmit and receive

NET \"rxa\_p\_BC\" LOC = \"T12\" \| IOSTANDARD = LVCMOS33; \# IO A3

NET \"rxa\_n\_BC\" LOC = \"T14\" \| IOSTANDARD = LVCMOS33; \# IO A4

NET \"txa\_p\_BC\" LOC = \"T15\" \| IOSTANDARD = LVCMOS33 \| DRIVE = 12; \# IO A5

NET \"txa\_n\_BC\" LOC = \"R16\" \| IOSTANDARD = LVCMOS33 \| DRIVE = 12; \# IO A6

\# Capture signal outputs

NET \"csw\" LOC = \"R12\" \| IOSTANDARD = LVCMOS33 \| DRIVE = 12 ; \# B3

NET \"dw\" LOC = \"T13\" \| IOSTANDARD = LVCMOS33 \| DRIVE = 12 ; \# B4

NET \"enc\_data\_en\" LOC = \"R14\" \| IOSTANDARD = LVCMOS33 \| DRIVE = 12 ; \# B5

NET \"enc\_data\" LOC = \"R15\" \| IOSTANDARD = LVCMOS33 \| DRIVE = 12 ; \# B6

\# Trigger signals

NET \"triggerA\" LOC = \"P15\" \| IOSTANDARD = LVCMOS33 ; \# B7 / P15\~IO\_L48P\_HDC\_M1DQ8\_1

NET \"triggerB\" LOC = \"N14\" \| IOSTANDARD = LVCMOS33 ; \# B8 / N14\~IO\_L45P\_A1\_M1LDQS\_1

NET \"triggerC\" LOC = \"M15\" \| IOSTANDARD = LVCMOS33 ; \# B9 / M15\~IO\_L46P\_FCS\_B\_M1DQ2\_1

\#inputs switch8 is the bypass signal. It should be pulled high. If you want to take the FPGA out of bypass mode this line needs to be tied to GND.

\#For triggering leave this line alone.

NET \"switch8\" LOC = \"L14\" \| IOSTANDARD = LVCMOS33 \| PULLUP ; \# B11 / L14\~IO\_L47P\_FWE\_B\_M1DQ0\_1

Triggering
----------

To assert a trigger, the following generics are set in the vhdl top level file, top\_1553.vhd.

> *constant WAIT\_MAX : positive := 32 ;*
>
> *constant DELAY\_MAX : positive := 1000 ;*
>
> *constant HLD\_MAXA : positive := 1088 ; *
>
> *constant DLY\_MAXA : positive := 2 ; *
>
> *constant HLD\_MAXB : positive := 544 ; *
>
> *constant DLY\_MAXB : positive := 2 ; *
>
> *constant HLD\_MAXC : positive := 272 ; *
>
> *constant DLY\_MAXC : positive := 2 ;*
>
> *constant NO\_HLDA : std\_logic := \'0\'; *
>
> *constant NO\_DLYA : std\_logic := \'0\'; *
>
> *constant NO\_HLDB : std\_logic := \'0\'; *
>
> *constant NO\_DLYB : std\_logic := \'0\'; *
>
> *constant NO\_HLDC : std\_logic := \'0\'; *
>
> *constant NO\_DLYC : std\_logic := \'0\';*

WAIT\_MAX is the duration, in microseconds, of inactivity on the rx bus before searching for and triggering on an incoming command/status sync word. DELAY\_MAX is the duration, in microseconds that the user expects the complete transaction to take. After DELAY\_MAX, the user can assert triggers of different delays and lengths. The duration of the bus transactions and gaps can be obtained by examining csw, dw, enc\_data, and enc\_data\_en on a scope or logic analyzer.

There are three triggers, triggerA, triggerB, and triggerC. There is a maximum delay, DLY\_MAX, and a maximum hold time, HLD\_MAX, for each. For each trigger, DLY\_MAX is the wait between the DELAY\_MAX of the transaction and the assertion of the trigger. For each trigger, HLD\_MAX is how long to assert the corresponding trigger.

A timing diagram of the trigger delays is shown below.

![Alt text](trigger_timing.png?raw=true "Trigger Timing")

Use the NO\_HLD generic if there is no need for the trigger. Use the NO\_DLY generic to start the trigger immediately after DELAY\_MAX.

Note that the current code does not support '0' values and the units are in microseconds.
