### Example Use of the Library: Sidelink communication transceiver simulation (not fully tested)

#### A short introduction to the D2D Communication mode
The sidelink communication mode is used for typical data applications such as VoIP and on-demand video-streaming. Compared to the the discovery mode, the data-rate and reliability requirements are more demanding. Thus, a more complex protocol has been drafted. In particular:
* Resource allocation, both on mode-specific and user-specific levels, is very similar to the approach described in the discovery mode: based on L3 (RRC) or L1 (DCI) signaling, a subset of uplink cell resources are first made available for sidelink communication transmissions (forming respective subframe and PRB resouce pools), and then, at a second stage specific resources are assigned to competing UEs.
* L1 implementation of the sidelink communication mode is similar to regular LTE downlink implementation. Specifically, both a control signaling and a data channel are defined.
  * Control signaling carries the communication-specific parametrization, e.g. modulation and coding scheme, exact PRBs carrying the data, transmission opportunity, identification of the group that the message refers to etc. Control information takes the form of an SCI message, which is similar to the legacy DCIs messages used in LTE downlink. Currently a single SCI message type (Format 0) is defined for sidelink communication. SCI undergoes transport and physical channel processing, and the PSCCH symbols are generated. Eventually the PSCCH channel is loaded in subframe and PRB resources determined during the resource allocation phase. PSCCH DMRS are also inserted in the subframe for channel estimation purposes. This information is required at the receiving side for detecting where the respective data channel symbols reside and how they were transmitted. Each PSCCH sequence is split in two parts and loaded in different subframe/PRB resource units.
  * For payload transmission a transport/physical channel processing chain similar to the one used for legacy LTE downlink/uplink communications is applied. Payload transport blocks first undergo transport processing (SL-SCH), and then physical channel processing (PSSCH). PSSCH DMRS are also inserted for channel estimation purposes. Each PSSCH is loaded in a single subframe and a subset of the  sidelink communication PRB pool. At the receiving side, after an SCI message has been sucessfully detected and the information contained in it has been extracted, data recovery is applied at the subframe indicated by UE-specific configuration and at the PRBs indicated in the SCI message.

#### Configuration
The configuration structure is similar to that of the discovery mode. The basic sidelink operation parameters, i.e. bandwidth mode (```NSLRB```), sidelink PCI (```NSLID```) and cyclic prefix length (```cp_len_r12```), determine the L1 subframe numerology as in the broadcast and discovery examples. The sidelink communication mode (```slMode```) determines if the resources used by each UE are centrally scheduled by the LTE eNB (mode-1) or selected autonomously (mode-2). Currently only mode-1 is fully supported. The sidelink communication mode triggers a "single-shot" or periodic tranmission of synchronization/broadcast subframes. These subframes are used at the receivered for obtaining side system information as well as time-synchronization.

Sidelink communication specific resource allocation is determined by a list of parameters which is very similar to the one used for configuring the sidelink discovery mode. Notice that these parameters mainly correspond to SL-CommResource Pool IEs defined in the 3GPP standard. In summary:
* ```scPeriod_r12```, determines the period (in # subframes) over which the specific sidelink configuration is applied. Possible values are 40,80,160, and 320 subframes. By default, our implementation creates a waveform for a duration corresponding to a single communication period.
* ```offsetIndicator_r12``` , determines the subframe offset (with respect to SFN #0) of the sidelink communication period.
* ```subframeBitmap_r12```, is a length-40 bitmap determining the time (subframe) pattern used for sidelink commuication (unit-elements determine the subframes available for sidelink transmissions)
* ```prb_Start_r12```, ```prb_End_r12```, and ```prb_Num_r12```, determine the PRB pool allocated to sidelink communication.

User-specific resource allocation and transmission configurarion is determined using a set of parameters which are either communicated to the transmitting D2D UE using L3 signaling (RRC/SIB) or L1 signaling (DCI-5) or decided autonomously by the UE. In particular:
* ```mcs_r12``` : determines the modulation and coding scheme used in PSSCH (QPSK and 16-QAM are supported in sidelink).
* ```nPSCCH``` : a scalar index used to determine the subframe/PRB resources drawn from the pool for PSCCH transmission (36.213/14.2.1.1/2); each ```nPSSCH``` configuration corresponds to a distinct subframe/PRB combination, catering for multiple non-colliding PSCCHs in a single subframe. At the receiver side a UE may "blindly" search over different ```nPSCCH``` configurations in order to capture sidelink communication data originating from multiple sources.
* ```nSAID`` : an identifier, used to specify different communication groups at the physical layer. At the receiving side only messages matching the given group ID are taken into account.
* ```HoppingFlag``` : indicates the PRB allocation strategy (hopping or non-hopping). Currently only non-hopping PRB resource allocation is fully supported.
* ```RBstart``` : the index of the starting PRB assigned for PSSCH.
* ```Lcrbs``` : the number of contiguous PRBs assigned for PSSCH. This parameter together with the  ```RBstart``` parameter determine the exact PRB pool subset used for PSSCH transmission.
* ```ITRP``` : a 7-bit bitmap used to determine the exact subframes picked from the sidelink communication resource pool for the specific PSSCH transmission.

#### Running the example
An example "mode-1" configuration is shown below. Notice that in addition to the aforementioned parameters we have included: i) a parameter called ```n_PSCCHs_monitored```, determing which resources the receiving UE will monitor for identifying potential SCI Format 0  messages, ii) a set of three parameters, i.e. ``decodingType```, ```chanEstMethod```, and ```timeVarFactor```, used for tuning channel estimation and channel decoding operations at the receiver side, similarly to the the discovery/broadcast subframe decoding procedures.

```
NSLRB                   = 25;
NSLID                   = 301;
slMode                  = 1;
cp_Len_r12              = 'Normal';
syncOffsetIndicator     = 0;
syncPeriod              = 40;
scPeriod_r12            = 160;
offsetIndicator_r12     = 40;
subframeBitmap_r12      = repmat([0;1;1;0],10,1);
prb_Start_r12           = 2;
prb_End_r12             = 22;
prb_Num_r12             = 10;
networkControlledSyncTx = 1;
syncTxPeriodic          = 1;
mcs_r12                 = [9; 10];
nPSCCH                  = [0; 30];
HoppingFlag             = [0; 0];
RBstart                 = [2; 13];
Lcrbs                   = [10; 10];
ITRP                    = [0; 1];
nSAID                   = [101; 102];
n_PSDCHs_monitored      = [0:1:30];
decodingType            = 'Soft';
chanEstMethod           = 'LS';
timeVarFactor           = 0;
```

In the given example we have configured two "virtual" transmitting D2D-UEs (the i-th UE configuration corresponds to the i-th element of the respective parameters subset  {```mcs_r12```, ```nPSCCH```, ```HoppingFlag```, ```RBstart```, ```Lcrbs```, ```ITRP```, ```nSAID```}. The receiving D2D-UE is able to monitor both transmissions as indicated by the search space it looks at (```n_PSDCHs_monitored```).

Sidelink configuration, mode-specific and user-specific resource allocation, as well as L1 processing are captured in high-level function blocks ```communication_tx()``` and ```communication_rx``` respectively. These are used as follows:

At the transmitter side:
```
slBaseConfig = struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode);
slSyncConfig = struct('syncOffsetIndicator', syncOffsetIndicator,'syncPeriod',syncPeriod);
slCommConfig = struct('scPeriod_r12',scPeriod_r12,'offsetIndicator_r12',offsetIndicator_r12, 'subframeBitmap_r12',subframeBitmap_r12,...
	'prb_Start_r12',prb_Start_r12, 'prb_End_r12', prb_End_r12, 'prb_Num_r12', prb_Num_r12,...
	'networkControlledSyncTx',networkControlledSyncTx, 'syncTxPeriodic',syncTxPeriodic );
slUEconfig   = struct('nPSCCH', nPSCCH, 'HoppingFlag', HoppingFlag, 'ITRP', ITRP, 'RBstart', RBstart, 'Lcrbs', Lcrbs, 'mcs_r12', mcs_r12, 'nSAID',nSAID);
tx_output = communication_tx( slBaseConfig, slSyncConfig, slCommConfig, slUEconfig);
```

At the receiver side (```rx_input``` is the received waveform):
```
communication_rx(slBaseConfig, slSyncConfig, slCommConfig,  ...
	struct('nPSCCH', n_PSDCHs_monitored ), ...
	struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
	rx_input );
```
During the execution of the simulation scenario various information messages are printed in the console output. These allow us to monitor every step of the tx/rx sidelink communication process, including resource pool configuration, generation of tx signals, and recovery of control and signaling information at the rx side. An example output dump is shown below:

```
=======================================================
PSCCH and PSSCH COMMUNICATION RESOURCES POOL FORMATION
=======================================================
Communication Period starts @ subframe #40 and ends at subframe #199
PSCCH Subframe pool (total 20 subframes)
( PSCCH Subframes : 41 42 45 46 49 50 53 54 57 58 61 62 65 66 69 70 73 74 77 78 )
PSSCH Subframe pool (total 60 subframes)
( PSSCH Subframes : 81 82 85 86 89 90 93 94 97 98 101 102 105 106 109 110 113 114 117 118 121 122 125 126 129 130 133 134 137 138 141 142 145 146 149 150 153 154 157 158 161 162 165 166 169 170 173 174 177 178 181 182 185 186 189 190 193 194 197 198 )
PSCCH/PSSCH PRB pools : Bottom prb range = 2:11, Top prb range = 13:22 (total = 20 PRBs)
=======================================================
UE-specific Control Channel (PSCCH) Resource Allocation
=======================================================
PSCCH Resource Allocation for UE with nPSCCH = 0 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 41
	RESOURCE #2 : PRB 13, SUBFRAME 42
PSCCH Resource Allocation for UE with nPSCCH = 30 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 61
	RESOURCE #2 : PRB 14, SUBFRAME 65
=====================================================
UE-specific Data Channel (PSSCH) Resource Allocation
=====================================================
PSSCH SUBFRAME Allocation for UE (with I_trp = 0): Total 4 subframes, First 81, Last: 129
( PSSCH Subframes : 81 97 113 129 )
PSSCH SUBFRAME Allocation for UE (with I_trp = 1): Total 4 subframes, First 82, Last: 130
( PSSCH Subframes : 82 98 114 130 )
[UE 0] PSSCH Transport Block Size = 1544 bits (Mod Order : 2).
	PSSCH Bit Capacity = 11520 bits  (Symbol Capacity = 5760 samples).
[UE 30] PSSCH Transport Block Size = 1736 bits (Mod Order : 2).
	PSSCH Bit Capacity = 11520 bits  (Symbol Capacity = 5760 samples).
=======================================================
Reference Subframes
=======================================================
( SLSS Subframes : 40 80 120 160 )


In REFERENCE subframe  40

Loading Subframe 41/PRB 2 with PSCCH for user 0
SCI-0 (41 bits) message 7180480065 (hex format) generated

Loading Subframe 42/PRB 13 with PSCCH for user 0
SCI-0 (41 bits) message 7180480065 (hex format) generated

Loading Subframe 61/PRB 3 with PSCCH for user 30
SCI-0 (41 bits) message 7701500065 (hex format) generated

Loading Subframe 65/PRB 14 with PSCCH for user 30
SCI-0 (41 bits) message 7701500065 (hex format) generated
In REFERENCE subframe  80

Loading Subframe 81 with PSSCH for user 0

Loading Subframe 82 with PSSCH for user 30

Loading Subframe 97 with PSSCH for user 0

Loading Subframe 98 with PSSCH for user 30

Loading Subframe 113 with PSSCH for user 0

Loading Subframe 114 with PSSCH for user 30
In REFERENCE subframe 120

Loading Subframe 129 with PSSCH for user 0

Loading Subframe 130 with PSSCH for user 30
In REFERENCE subframe 160
Tx Waveform Created...
Tx Waveform Passed from Channel...


Rx Waveform Processing Starting...
=======================================================
PSCCH and PSSCH COMMUNICATION RESOURCES POOL FORMATION
=======================================================
Communication Period starts @ subframe #40 and ends at subframe #199
PSCCH Subframe pool (total 20 subframes)
( PSCCH Subframes : 41 42 45 46 49 50 53 54 57 58 61 62 65 66 69 70 73 74 77 78 )
PSSCH Subframe pool (total 60 subframes)
( PSSCH Subframes : 81 82 85 86 89 90 93 94 97 98 101 102 105 106 109 110 113 114 117 118 121 122 125 126 129 130 133 134 137 138 141 142 145 146 149 150 153 154 157 158 161 162 165 166 169 170 173 174 177 178 181 182 185 186 189 190 193 194 197 198 )
PSCCH/PSSCH PRB pools : Bottom prb range = 2:11, Top prb range = 13:22 (total = 20 PRBs)
=======================================================
UE-specific Control Channel (PSCCH) Resource Allocation
=======================================================
PSCCH Resource Allocation for UE with nPSCCH = 0 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 41
	RESOURCE #2 : PRB 13, SUBFRAME 42
PSCCH Resource Allocation for UE with nPSCCH = 1 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 42
	RESOURCE #2 : PRB 13, SUBFRAME 45
PSCCH Resource Allocation for UE with nPSCCH = 2 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 45
	RESOURCE #2 : PRB 13, SUBFRAME 46
PSCCH Resource Allocation for UE with nPSCCH = 3 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 46
	RESOURCE #2 : PRB 13, SUBFRAME 49
PSCCH Resource Allocation for UE with nPSCCH = 4 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 49
	RESOURCE #2 : PRB 13, SUBFRAME 50
PSCCH Resource Allocation for UE with nPSCCH = 5 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 50
	RESOURCE #2 : PRB 13, SUBFRAME 53
PSCCH Resource Allocation for UE with nPSCCH = 6 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 53
	RESOURCE #2 : PRB 13, SUBFRAME 54
PSCCH Resource Allocation for UE with nPSCCH = 7 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 54
	RESOURCE #2 : PRB 13, SUBFRAME 57
PSCCH Resource Allocation for UE with nPSCCH = 8 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 57
	RESOURCE #2 : PRB 13, SUBFRAME 58
PSCCH Resource Allocation for UE with nPSCCH = 9 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 58
	RESOURCE #2 : PRB 13, SUBFRAME 61
PSCCH Resource Allocation for UE with nPSCCH = 10 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 61
	RESOURCE #2 : PRB 13, SUBFRAME 62
PSCCH Resource Allocation for UE with nPSCCH = 11 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 62
	RESOURCE #2 : PRB 13, SUBFRAME 65
PSCCH Resource Allocation for UE with nPSCCH = 12 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 65
	RESOURCE #2 : PRB 13, SUBFRAME 66
PSCCH Resource Allocation for UE with nPSCCH = 13 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 66
	RESOURCE #2 : PRB 13, SUBFRAME 69
PSCCH Resource Allocation for UE with nPSCCH = 14 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 69
	RESOURCE #2 : PRB 13, SUBFRAME 70
PSCCH Resource Allocation for UE with nPSCCH = 15 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 70
	RESOURCE #2 : PRB 13, SUBFRAME 73
PSCCH Resource Allocation for UE with nPSCCH = 16 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 73
	RESOURCE #2 : PRB 13, SUBFRAME 74
PSCCH Resource Allocation for UE with nPSCCH = 17 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 74
	RESOURCE #2 : PRB 13, SUBFRAME 77
PSCCH Resource Allocation for UE with nPSCCH = 18 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 77
	RESOURCE #2 : PRB 13, SUBFRAME 78
PSCCH Resource Allocation for UE with nPSCCH = 19 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 78
	RESOURCE #2 : PRB 13, SUBFRAME 41
PSCCH Resource Allocation for UE with nPSCCH = 20 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 41
	RESOURCE #2 : PRB 14, SUBFRAME 45
PSCCH Resource Allocation for UE with nPSCCH = 21 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 42
	RESOURCE #2 : PRB 14, SUBFRAME 46
PSCCH Resource Allocation for UE with nPSCCH = 22 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 45
	RESOURCE #2 : PRB 14, SUBFRAME 49
PSCCH Resource Allocation for UE with nPSCCH = 23 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 46
	RESOURCE #2 : PRB 14, SUBFRAME 50
PSCCH Resource Allocation for UE with nPSCCH = 24 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 49
	RESOURCE #2 : PRB 14, SUBFRAME 53
PSCCH Resource Allocation for UE with nPSCCH = 25 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 50
	RESOURCE #2 : PRB 14, SUBFRAME 54
PSCCH Resource Allocation for UE with nPSCCH = 26 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 53
	RESOURCE #2 : PRB 14, SUBFRAME 57
PSCCH Resource Allocation for UE with nPSCCH = 27 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 54
	RESOURCE #2 : PRB 14, SUBFRAME 58
PSCCH Resource Allocation for UE with nPSCCH = 28 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 57
	RESOURCE #2 : PRB 14, SUBFRAME 61
PSCCH Resource Allocation for UE with nPSCCH = 29 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 58
	RESOURCE #2 : PRB 14, SUBFRAME 62
PSCCH Resource Allocation for UE with nPSCCH = 30 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 61
	RESOURCE #2 : PRB 14, SUBFRAME 65

 -- Searching for SCI0 messages in the whole input waveform --

Searching for SCI0 message for nPSCCH = 0
******* FOUND a SCI-0 message *******
Information Recovery from SCI-0 message 7180480065 (hex format)
	Frequency hopping flag           :  0
	Resource Allocation Bitmap (INT) :  227
	Time Resource Pattern            :  0
	Modulation and Coding            :  9
	Timing Advance (not implemented) : --
	Group Destinatiod ID (nSAID)     :  101
	(RA Bitmap --> Assigned PSSCH PRBs : 2 3 4 5 6 7 8 9 10 11 )

Searching for SCI0 message for nPSCCH = 1
Nothing found

Searching for SCI0 message for nPSCCH = 2
Nothing found

Searching for SCI0 message for nPSCCH = 3
Nothing found

Searching for SCI0 message for nPSCCH = 4
Nothing found

Searching for SCI0 message for nPSCCH = 5
Nothing found

Searching for SCI0 message for nPSCCH = 6
Nothing found

Searching for SCI0 message for nPSCCH = 7
Nothing found

Searching for SCI0 message for nPSCCH = 8
Nothing found

Searching for SCI0 message for nPSCCH = 9
Nothing found

Searching for SCI0 message for nPSCCH = 10
Nothing found

Searching for SCI0 message for nPSCCH = 11
Nothing found

Searching for SCI0 message for nPSCCH = 12
Nothing found

Searching for SCI0 message for nPSCCH = 13
Nothing found

Searching for SCI0 message for nPSCCH = 14
Nothing found

Searching for SCI0 message for nPSCCH = 15
Nothing found

Searching for SCI0 message for nPSCCH = 16
Nothing found

Searching for SCI0 message for nPSCCH = 17
Nothing found

Searching for SCI0 message for nPSCCH = 18
Nothing found

Searching for SCI0 message for nPSCCH = 19
Nothing found
####
Searching for SCI0 message for nPSCCH = 20
Nothing found

Searching for SCI0 message for nPSCCH = 21
Nothing found

Searching for SCI0 message for nPSCCH = 22
Nothing found

Searching for SCI0 message for nPSCCH = 23
Nothing found

Searching for SCI0 message for nPSCCH = 24
Nothing found

Searching for SCI0 message for nPSCCH = 25
Nothing found

Searching for SCI0 message for nPSCCH = 26
Nothing found

Searching for SCI0 message for nPSCCH = 27
Nothing found

Searching for SCI0 message for nPSCCH = 28
Nothing found

Searching for SCI0 message for nPSCCH = 29
Nothing found

Searching for SCI0 message for nPSCCH = 30
******* FOUND a SCI-0 message *******
Information Recovery from SCI-0 message 7701500065 (hex format)
	Frequency hopping flag           :  0
	Resource Allocation Bitmap (INT) :  238
	Time Resource Pattern            :  1
	Modulation and Coding            :  10
	Timing Advance (not implemented) : --
	Group Destinatiod ID (nSAID)     :  101
	(RA Bitmap --> Assigned PSSCH PRBs : 13 14 15 16 17 18 19 20 21 22 )


Updated Resource Allocation Information based on recovered SCI0 messages
=======================================================
UE-specific Control Channel (PSCCH) Resource Allocation
=======================================================
PSCCH Resource Allocation for UE with nPSCCH = 0 (max: 199):
	RESOURCE #1 : PRB  2, SUBFRAME 41
	RESOURCE #2 : PRB 13, SUBFRAME 42
PSCCH Resource Allocation for UE with nPSCCH = 30 (max: 199):
	RESOURCE #1 : PRB  3, SUBFRAME 61
	RESOURCE #2 : PRB 14, SUBFRAME 65
=====================================================
UE-specific Data Channel (PSSCH) Resource Allocation
=====================================================
PSSCH SUBFRAME Allocation for UE (with I_trp = 0): Total 4 subframes, First 81, Last: 129
( PSSCH Subframes : 81 97 113 129 )
PSSCH SUBFRAME Allocation for UE (with I_trp = 1): Total 4 subframes, First 82, Last: 130
( PSSCH Subframes : 82 98 114 130 )
[UE 0] PSSCH Transport Block Size = 1544 bits (Mod Order : 2).
	PSSCH Bit Capacity = 11520 bits  (Symbol Capacity = 5760 samples).
[UE 30] PSSCH Transport Block Size = 1736 bits (Mod Order : 2).
	PSSCH Bit Capacity = 11520 bits  (Symbol Capacity = 5760 samples).
=======================================================
Reference Subframes
=======================================================
( SLSS Subframes : 40 80 120 160 )

 -- Recovering data from the input waveform based on recovered SCI0s --
2 Data transport blocks will be recovered based on information provided by detected SCI-0 messages

Detecting data transport block 1/2 (for UE = 0)
CRC detection ok

Detecting data transport block 2/2 (for UE = 30)
CRC detection ok
```

### Example Use of the Library: Sidelink V2X communication transceiver simulation (not fully tested)
#### Introduction to the Sidelink V2X communication mode
The use of the sidelink interface for vehicle-to-vehicle (V2V) or vehicle-to-infrastructure communications has been introduced in the 3GPP standard in Rel.14. Sidelink V2X is heavily based on the Rel.12/13 sidelink communication mode. Two new sidelink communication modes are introduced in the respective 3GPP TSs/TRs, i.e. mode-3 and mode-4 (in addition to existing mode-1 and mode-2) to distinguish V2X from "Standard" D2D. The following new features and "tweaks" have been applied for coping with the peculiar features of the vehicle communications use cases, namely higher channel variability, lower required latency, and increased devices density:
* The number of demodulation reference signals carried in each subframe for V2X PSBCH, PSCCH and PSSCH has increased in order to capture frequent channel changes. In standard D2D two DMRSs are used in each subframe, while in V2X PSBCH there are three DMRSs and in V2X PSCCH/PSSCH there are four.
* V2X transmission control (PSCCH) and data (PSSCH) are carried in the same subframe, differently from standard D2D where control and data subframe pools are clearly distinguished. This new feature allows to decode a PSSCH immediately after a PSCCH is recovered.
* PSCCH and PSSCH for V2X transmission may be assigned adjacent PRBs. Specifically, each PSCCH is loaded in two consecutive PRBs in a single subframe, whereas in standard D2D one PRB and two subframes are used. PSSCH PRB allocation may start at the next available PRB of the pool after PSCCH is considered or at any other PRB for the non-adjacent mode.
* PRBs are organized in groups called "subchannels", and frequency-based resource allocation is configured with subchannel granularity.
* LTE enB controls V2X communication using L1 DCI Format 5A messages, whereas in standard D2D this is done using Format 5 messages.
* A new control message, called SCI Format 1 (SCI-1), is introduced for informing receiving V2X UEs about the selected time-frequency resource allocation (time and frequency based) and the transmission configuration (modulation/coding scheme, re-transmission opportunity).
* SCI Format 1 transport and physical channel processing steps are the same with that of standard D2D (SCI Format 0), except for a slight difference in the PUSCH interleaver sequence generation.
* V2X SL-SCH processing is the same with that of standard D2D except for PUSCH interleaver sequence generation.
* V2X PSSCH processing differs from standard PSSCH only in the gold sequence definition. For standard D2D the sequence is generated based on the group destination ID (```nSAID```) whereas in V2X the CRC checksum of the PSCCH is used (```nXID```).
* Each Data transmission block (SL-SCH) is not split into 4 subframes as in the standard D2D, but it spans exactly a single subframe. A re-transmission of the same block in a subsequent subframe belonging to the V2V resources pool is allowed.
* Only normal cyclic prefix length is allowed in the V2X communication mode.

#### Configuration
The configuration of the V2X communication setup is very similar to that of standard D2D communication. Two V2X sidelink modes are defined, mode-3 which specifies a "fully-controlled" (by the LTE eNB) resources allocation approach and mode-4 which corresponds to an autonomous approach. Currently only mode-3 is fully supported by the library.

With respect to the communication-specific configuration, the following parameters are used. Notice that these correspond to IEs from the newly defined (in Rel.14) SL-V2XCommResourcePool L3 structure:
* ```v2xSLSSconfigured``` : determines if synchronization/broadcast subframes are triggered by the V2X transmission.
* ```sl_OffsetIndicator_r14``` : indicates the offset (with respect to SFN/DFN #0) of the first subframe of the V2X communication subframes resource pool.
* ```sl_Subframe_r14```: 16/20/100-length bitmap indicating the subframes that are available for V2X PSCCH/PSSCH.
* ```sizeSubchannel_r14``` : indicates the size of the subchannel (in terms of number of PRBs) in the corresponding resource pool; acceptable lengths are: 4, 5, 6, 8, 10, 12, 15,16, 18, 20, 25, 30, 48, 50, 72, 75, 96, and 100.
* ```numSubchannel_r14``` :  indicates the number of subchannels contained in the corresponding resource pool; acceptable configurations are 1, 3, 5, 10, 15, and 20.
* ```startRB_Subchannel_r14``` : indicates the lowest RB index of the subchannel with the lowest index.
* ```adjacencyPSCCH_PSSCH_r14``` : indicates if adjacent PRBs should be assigned for control (PSCCH) and data (PSSCH).
* ```startRB_PSCCH_Pool_r14``` : for non-adjacent PSCCH/PSSCH PRB assigment, it indicates the lowest index of the PSCCH PRB pool.

UE-specific configuration (in scheduled mode) is communicated to the transmitting V2X UE using L1 DL signaling, and in particular the DCI Format 5A structure, as well as L3 signalling, i.e. RRC and SIB messages. The following parameters are introduced:
* ```mcs_r14``` : indicates the MCS mode;
* ```SFgap``` : determines the gap (in the subframe domain) for retransmission opportunity of the PSCCH/PSSCH;
* ```m_subchannel``` : determines the first transmission opportunity frequency offset, in particular the lowest index of the subchannel allocation used in first PSCCH/PSSCH transmission;
* ```nsubCHstart``` : as in the ```m_subchannel``` definition, but for the second tranmission opportunity;
* ```LsubCH``` : determines the number of subchannels assigned to the UE;

An example configuration is provided below:
```
NSLRB                           = 25;
NSLID                           = 301;
slMode                          = 3;
cp_Len_r12                      = 'Normal';
syncOffsetIndicator             = 0;
syncPeriod                      = 20;
v2xSLSSconfigured               = true;
sl_OffsetIndicator_r14          = 40;
sl_Subframe_r14                 = repmat([0;1;1;0],5,1);
sizeSubchannel_r14              = 4;
numSubchannel_r14               = 3;
startRB_Subchannel_r14          = 2;
adjacencyPSCCH_PSSCH_r14        = true;
startRB_PSCCH_Pool_r14          = 14;
networkControlledSyncTx         = 1;
syncTxPeriodic                  = 1;          
mcs_r14                         = [3; 4];
m_subchannel                    = [0; 0];
nsubCHstart                     = [1; 1];                           
LsubCH                          = [2; 1];
SFgap                           = [1; 0];
decodingType                    = 'Soft';
chanEstMethod                   = 'LS';
timeVarFactor                   = 0;
```

#### Running the example

V2X-compliant tx waveform is generated in the following way:
```
slBaseConfig = struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode);
slSyncConfig = struct('syncOffsetIndicator', syncOffsetIndicator,'syncPeriod',syncPeriod);
slV2XCommConfig = struct('v2xSLSSconfigured',v2xSLSSconfigured,'sl_OffsetIndicator_r14',sl_OffsetIndicator_r14,'sl_Subframe_r14',sl_Subframe_r14,....
	'sizeSubchannel_r14',sizeSubchannel_r14,'numSubchannel_r14',numSubchannel_r14, 'startRB_Subchannel_r14',startRB_Subchannel_r14,...
	'adjacencyPSCCH_PSSCH_r14',adjacencyPSCCH_PSSCH_r14,'startRB_PSCCH_Pool_r14',startRB_PSCCH_Pool_r14);
slV2XUEconfig = struct('mcs_r14',mcs_r14, 'm_subchannel', m_subchannel, 'nsubCHstart', nsubCHstart, 'LsubCH', LsubCH, 'SFgap', SFgap);

tx_output = communication_tx( slBaseConfig, slSyncConfig, slV2XCommConfig, slV2XUEconfig );
```
AWGN channel may be induced in the following way:
```
SNR_target_dB = 30; % set SNR
noise = sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1)); % generate noise
rx_input = tx_output + noise; % induce it to the waveform
```
Finally, the recovery/decoding operations for the processed waveform are called using the following snippet:

```
communication_rx(slBaseConfig, slSyncConfig, slV2XCommConfig,  ...
	struct(), ...
	struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
	rx_input );
```
The decoder initially searches (blindly) for SCI Format 1 messages, and if it detects one recovers the information contained in it and decodes accordingly the corresponding PSSCH. An example run for two "virtual" V2X UE transmissions is provided below:
```
===========================================================
PSCCH and PSSCH V2X COMMUNICATION RESOURCES POOL FORMATION
===========================================================
V2X Communication Period starts @ subframe #40 and ends at subframe #239
( SLSS Subframes : 0 20 40 60 80 100 120 140 160 180 200 220 )
V2X PSxCH Subframe pool (total 100 subframes)
( V2X PSxCH Subframes : 41 42 45 46 49 50 53 54 57 58 61 62 65 66 69 70 73 74 77 78 81 82 85 86 89 90 93 94 97 98 101 102 105 106 109 110 113 114 117 118 121 122 125 126 129 130 133 134 137 138 141 142 145 146 149 150 153 154 157 158 161 162 165 166 169 170 173 174 177 178 181 182 185 186 189 190 193 194 197 198 201 202 205 206 209 210 213 214 217 218 221 222 225 226 229 230 233 234 237 238 )
V2X PSSCH PRB Pool contains  3 subchannels, of size  4 PRBs each, with lowest PRB index of subchannel #0 =  2
	[Subchannel  0] PRBs :  2  3  4  5
	[Subchannel  1] PRBs :  6  7  8  9
	[Subchannel  2] PRBs : 10 11 12 13
V2X PSCCH PRB Pool contains  3 subchannels, of size  2 PRBs each, with lowest PRB index of subchannel #0 =  2
	[Subchannel  0] PRBs :  2  3
	[Subchannel  1] PRBs :  6  7
	[Subchannel  2] PRBs : 10 11
============================================================
UE-specific Control Channel (PSCCH) V2X Resource Allocation
============================================================
 PSCCH Subframes for user 1 : 41 42
 PSCCH PRBs for user 1 (txOp = 1): 2 3
 PSCCH PRBs for user 1 (txOp = 2): 6 7
 PSCCH Subframes for user 2 : 45
 PSCCH PRBs for user 2 (txOp = 1): 2 3
=========================================================
UE-specific Data Channel (PSSCH) V2X Resource Allocation
=========================================================
 PSSCH Subframes for user 1 : 41 42
 PSSCH PRBs for user 1 (txOp = 1): 4 5 6 7 8 9
 PSSCH PRBs for user 1 (txOp = 2): 8 9 10 11 12 13
[UE 0] PSSCH Transport Block Size = 328 bits (Mod Order : 2).
	PSSCH Bit Capacity = 1440 bits  (Symbol Capacity = 720 samples).
 PSSCH Subframes for user 2 : 45
 PSSCH PRBs for user 2 (txOp = 1): 4 5
[UE 0] PSSCH Transport Block Size = 120 bits (Mod Order : 2).
	PSSCH Bit Capacity = 480 bits  (Symbol Capacity = 240 samples).

Loading Subframe 41 with V2X-PSCCH for user 1 (tx op: #1) [Used PRBs :  2  3 ]
SCI-1 (32 bits) message 1046000 (hex format) generated

Loading Subframe 41 with V2X-PSSCH for user 1 (tx op: #1) [nXID = 41310][Used PRBs :  4  5  6  7  8  9 ]

Loading Subframe 42 with V2X-PSCCH for user 1 (tx op: #2) [Used PRBs :  6  7 ]
SCI-1 (32 bits) message 1047000 (hex format) generated

Loading Subframe 42 with V2X-PSSCH for user 1 (tx op: #2) [nXID = 41517][Used PRBs :  8  9 10 11 12 13 ]

Loading Subframe 45 with V2X-PSCCH for user 2 (tx op: #1) [Used PRBs :  2  3 ]
SCI-1 (32 bits) message 408000 (hex format) generated

Loading Subframe 45 with V2X-PSSCH for user 2 (tx op: #1) [nXID = 1589][Used PRBs :  4  5 ]

Tx Waveform Passed from Channel...

Rx Waveform Processing Starting...
===========================================================
PSCCH and PSSCH V2X COMMUNICATION RESOURCES POOL FORMATION
===========================================================
V2X Communication Period starts @ subframe #40 and ends at subframe #239
( SLSS Subframes : 0 20 40 60 80 100 120 140 160 180 200 220 )
V2X PSxCH Subframe pool (total 100 subframes)
( V2X PSxCH Subframes : 41 42 45 46 49 50 53 54 57 58 61 62 65 66 69 70 73 74 77 78 81 82 85 86 89 90 93 94 97 98 101 102 105 106 109 110 113 114 117 118 121 122 125 126 129 130 133 134 137 138 141 142 145 146 149 150 153 154 157 158 161 162 165 166 169 170 173 174 177 178 181 182 185 186 189 190 193 194 197 198 201 202 205 206 209 210 213 214 217 218 221 222 225 226 229 230 233 234 237 238 )
V2X PSSCH PRB Pool contains  3 subchannels, of size  4 PRBs each, with lowest PRB index of subchannel #0 =  2
	[Subchannel  0] PRBs :  2  3  4  5
	[Subchannel  1] PRBs :  6  7  8  9
	[Subchannel  2] PRBs : 10 11 12 13
V2X PSCCH PRB Pool contains  3 subchannels, of size  2 PRBs each, with lowest PRB index of subchannel #0 =  2
	[Subchannel  0] PRBs :  2  3
	[Subchannel  1] PRBs :  6  7
	[Subchannel  2] PRBs : 10 11
============================================================
UE-specific Control Channel (PSCCH) V2X Resource Allocation
============================================================

 -- Searching for SCI1 messages and recover respective Data in the whole input waveform --

FOUND an SCI-1 message in [Subframe 41, PRB set : 2  3 ]
Information Recovery from SCI-1 message 1046000 (hex format)
Frequency resource location (INT)                                    :  4
Time gap between initial transmission and retransmission  (INT)      :  1
Modulation and Coding (INT)                                          :  3
Retransmission index                                                 :  0
Reserved information bits (INT)                                      :  0
	(FRL Bitmap --> nsubCHstart = 1, LsubCH = 2)
Recovering Data Message in corresponding resources
[UE 0] PSSCH Transport Block Size = 328 bits (Mod Order : 2).
	PSSCH Bit Capacity = 1440 bits  (Symbol Capacity = 720 samples).
CRC detection ok

FOUND an SCI-1 message in [Subframe 42, PRB set : 6  7 ]
Information Recovery from SCI-1 message 1047000 (hex format)
Frequency resource location (INT)                                    :  4
Time gap between initial transmission and retransmission  (INT)      :  1
Modulation and Coding (INT)                                          :  3
Retransmission index                                                 :  1
Reserved information bits (INT)                                      :  0
	(FRL Bitmap --> nsubCHstart = 1, LsubCH = 2)
Recovering Data Message in corresponding resources
[UE 0] PSSCH Transport Block Size = 328 bits (Mod Order : 2).
	PSSCH Bit Capacity = 1440 bits  (Symbol Capacity = 720 samples).
CRC detection ok

FOUND an SCI-1 message in [Subframe 45, PRB set : 2  3 ]
Information Recovery from SCI-1 message 408000 (hex format)
Frequency resource location (INT)                                    :  1
Time gap between initial transmission and retransmission  (INT)      :  0
Modulation and Coding (INT)                                          :  4
Retransmission index                                                 :  0
Reserved information bits (INT)                                      :  0
	(FRL Bitmap --> nsubCHstart = 1, LsubCH = 1)
Recovering Data Message in corresponding resources
[UE 0] PSSCH Transport Block Size = 120 bits (Mod Order : 2).
	PSSCH Bit Capacity = 480 bits  (Symbol Capacity = 240 samples).
CRC detection ok

```
