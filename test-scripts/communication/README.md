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