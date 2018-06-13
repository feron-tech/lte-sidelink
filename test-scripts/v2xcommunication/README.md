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
The configuration of the V2X communication setup is very similar to that of standard D2D communication. Two V2X sidelink modes are defined, mode-3 which specifies a "fully-controlled" (by the LTE eNB) resources allocation approach and mode-4 which corresponds to an autonomous approach (currently sensing in mode-4 is not supported)

With respect to the communication-specific configuration, the following parameters are used. Notice that these correspond to IEs from the newly defined (in Rel.14) SL-V2XCommResourcePool L3 structure:
* ```sl_OffsetIndicator_r14``` : indicates the offset (with respect to SFN/DFN #0) of the first subframe of the V2X communication subframes resource pool.
* ```sl_Subframe_r14```: 16/20/100-length bitmap indicating the subframes that are available for V2X PSCCH/PSSCH.
* ```sizeSubchannel_r14``` : indicates the size of the subchannel (in terms of number of PRBs) in the corresponding resource pool; acceptable lengths are: 4, 5, 6, 8, 10, 12, 15,16, 18, 20, 25, 30, 48, 50, 72, 75, 96, and 100.
* ```numSubchannel_r14``` :  indicates the number of subchannels contained in the corresponding resource pool; acceptable configurations are 1, 3, 5, 10, 15, and 20.
* ```startRB_Subchannel_r14``` : indicates the lowest RB index of the subchannel with the lowest index.
* ```adjacencyPSCCH_PSSCH_r14``` : indicates if adjacent PRBs should be assigned for control (PSCCH) and data (PSSCH).
* ```startRB_PSCCH_Pool_r14``` : for non-adjacent PSCCH/PSSCH PRB assigment, it indicates the lowest index of the PSCCH PRB pool.

UE-specific configuration (in scheduled mode) is determined by:
* ```sduSize```: the size of information payload (total PHY PDU payload should account for MAC Overhead)
* ```SFgap``` : determines the gap (in the subframe domain) for retransmission opportunity of the PSCCH/PSSCH;
* ```Linit``` : determines the first transmission opportunity frequency offset, in particular the lowest index of the subchannel allocation used in first PSCCH/PSSCH transmission;
* ```nsubCHstart``` : as in the ```m_subchannel``` definition, but for the second tranmission opportunity;

An example configuration is provided below:
```
NSLRB                           = 25;
NSLID                           = 301;
slMode                          = 3;
syncOffsetIndicator             = 0;
syncTxPeriodic                  = 1;
syncPeriod                      = 160;
sl_OffsetIndicator_r14          = 0;
sl_Subframe_r14                 = [0;0;1;zeros(17,1)];
adjacencyPSCCH_PSSCH_r14        = true;
sizeSubchannel_r14              = 5;
numSubchannel_r14               = 5;
startRB_Subchannel_r14          = 0;
startRB_PSCCH_Pool_r14          = 14;
sduSize                         = 10;
SFgap                           = 0;
if slMode == 3 % fully controlled
	Linit                       = 0;
	nsubCHstart                 = 0;
elseif slMode == 4 % 2 sub-schemes: random
	% nothing here, autonomous selection of resources
end
decodingType                    = 'Soft';
chanEstMethod                   = 'LS';
timeVarFactor                   = 0;
```

#### Running the example

V2X-compliant tx waveform is generated in the following way:
```
slBaseConfig    = struct('NSLRB',NSLRB,'NSLID',NSLID,'slMode',slMode);
slSyncConfig    = struct('syncOffsetIndicator', syncOffsetIndicator,'syncTxPeriodic',syncTxPeriodic,'slMode',slMode,'syncPeriod',syncPeriod);

slV2XCommConfig = struct('sl_OffsetIndicator_r14',sl_OffsetIndicator_r14,'adjacencyPSCCH_PSSCH_r14',adjacencyPSCCH_PSSCH_r14,...    
				'sl_Subframe_r14',sl_Subframe_r14,'sizeSubchannel_r14',sizeSubchannel_r14,'numSubchannel_r14',numSubchannel_r14,...
				'startRB_Subchannel_r14',startRB_Subchannel_r14,'startRB_PSCCH_Pool_r14',startRB_PSCCH_Pool_r14);		
if slMode == 3
	slV2XUEconfig   = struct('sduSize',sduSize, 'SFgap', SFgap, 'Linit', Linit, 'nsubCHstart',nsubCHstart);
elseif slMode == 4
	slV2XUEconfig   = struct('sduSize',sduSize, 'SFgap', SFgap);
end

```
AWGN channel may be induced in the following way:
```
SNR_target_dB = 30; % set SNR
noise = sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1)); % generate noise
rx_input = tx_output + noise; % induce it to the waveform
```
Finally, the recovery/decoding operations for the processed waveform are called using the following snippet:

```
v2xcomm_rx( slBaseConfig, slSyncConfig, slV2XCommConfig, ...
	struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor), ...
	rx_input);
```
The decoder initially searches (blindly) for SCI Format 1 messages, and if it detects one recovers the information contained in it and decodes accordingly the corresponding PSSCH. An example run for two "virtual" V2X UE transmissions is provided below for a single packet arriving at subframe 7:
```
Tx Waveform Processing Starting...
V2X PSxCH Subframe pool (total 508 subframes)
( V2X PSxCH Subframes : 4 24 44 64 84 104 124 144 165 185 205 225 245 265 285 305 326 346 366 386 406 426 446 466 487 507 527 547 567 587 607 627 649 669 689 709 729 749 769 789 810 830 850 870 890 910 930 950 971 991 1011 1031 1051 1071 1091 1111 1132 1152 1172 1192 1212 1232 1252 1272 1294 1314 1334 1354 1374 1394 1414 1434 1455 1475 1495 1515 1535 1555 1575 1595 1616 1636 1656 1676 1696 1716 1736 1756 1777 1797 1817 1837 1857 1877 1897 1917 1939 1959 1979 1999 2019 2039 2059 2079 2100 2120 2140 2160 2180 2200 2220 2241 2261 2281 2301 2321 2341 2361 2381 2402 2422 2442 2462 2482 2502 2522 2542 2564 2584 2604 2624 2644 2664 2684 2704 2725 2745 2765 2785 2805 2825 2845 2865 2886 2906 2926 2946 2966 2986 3006 3026 3047 3067 3087 3107 3127 3147 3167 3187 3209 3229 3249 3269 3289 3309 3329 3349 3370 3390 3410 3430 3450 3470 3490 3510 3531 3551 3571 3591 3611 3631 3651 3671 3692 3712 3732 3752 3772 3792 3812 3832 3854 3874 3894 3914 3934 3954 3974 3994 4015 4035 4055 4075 4095 4115 4135 4155 4176 4196 4216 4236 4256 4276 4296 4316 4337 4357 4377 4397 4417 4437 4457 4477 4499 4519 4539 4559 4579 4599 4619 4639 4660 4680 4700 4720 4740 4760 4780 4801 4821 4841 4861 4881 4901 4921 4941 4962 4982 5002 5022 5042 5062 5082 5102 5124 5144 5164 5184 5204 5224 5244 5264 5285 5305 5325 5345 5365 5385 5405 5425 5446 5466 5486 5506 5526 5546 5566 5586 5607 5627 5647 5667 5687 5707 5727 5747 5769 5789 5809 5829 5849 5869 5889 5909 5930 5950 5970 5990 6010 6030 6050 6070 6091 6111 6131 6151 6171 6191 6211 6231 6252 6272 6292 6312 6332 6352 6372 6392 6414 6434 6454 6474 6494 6514 6534 6554 6575 6595 6615 6635 6655 6675 6695 6715 6736 6756 6776 6796 6816 6836 6856 6876 6897 6917 6937 6957 6977 6997 7017 7037 7059 7079 7099 7119 7139 7159 7179 7199 7220 7240 7260 7280 7300 7320 7340 7361 7381 7401 7421 7441 7461 7481 7501 7522 7542 7562 7582 7602 7622 7642 7662 7684 7704 7724 7744 7764 7784 7804 7824 7845 7865 7885 7905 7925 7945 7965 7985 8006 8026 8046 8066 8086 8106 8126 8146 8167 8187 8207 8227 8247 8267 8287 8307 8329 8349 8369 8389 8409 8429 8449 8469 8490 8510 8530 8550 8570 8590 8610 8630 8651 8671 8691 8711 8731 8751 8771 8791 8812 8832 8852 8872 8892 8912 8932 8952 8974 8994 9014 9034 9054 9074 9094 9114 9135 9155 9175 9195 9215 9235 9255 9275 9296 9316 9336 9356 9376 9396 9416 9436 9457 9477 9497 9517 9537 9557 9577 9597 9619 9639 9659 9679 9699 9719 9739 9759 9780 9800 9820 9840 9860 9880 9900 9921 9941 9961 9981 10001 10021 10041 10061 10082 10102 10122 10142 10162 10182 10202 10222 )
V2X PSCCH PRB Pool contains  5 subchannels, of size  2 PRBs each, with lowest PRB index of subchannel #0 =  0
[Subchannel  0] PRBs :  0  1
[Subchannel  1] PRBs :  5  6
[Subchannel  2] PRBs : 10 11
[Subchannel  3] PRBs : 15 16
[Subchannel  4] PRBs : 20 21
[## Tx ##] In REFERENCE subframe   0
mac_pdu_len_MIN =
	74
For SDU size =  10 bits we set: mcs =  1, N_PRB =  3, TB Size =   88, Qprime = 2 (Padding =   14)
PSSCH ModOrder = 2
PSSCH TBSize = 88 (bits)
PSSCH Num of PRBs = 3
PSSCH Bit Capacity = 720 (bits)
==================================================
 PSSCH PRBs [txOp = 1]: 2 3 4
Resource Reservation (Actual)                                        :  0.0
Frequency resource location (INT)                                    :  0
Time gap between initial transmission and retransmission  (INT)      :  0
Modulation and Coding (INT)                                          :  1
Retransmission index                                                 :  0
Reserved information bits (INT)                                      :  0

==================================================
 PSCCH Subframes : 24
 PSCCH PRBs [txOp = 1]: 0 1
[## Tx ##] In V2X-COMM subframe  24
 SL-SCH TB random message 3a9c51632a0a8 (hex format) generated
User 1, TxOp 1: SCI/PSCCH Tx Processing done (nXID = 883, SCI=1000)
User 1, TxOp 1: SL-SCH/PSSCH Tx Processing done (SL-SCH TB=3a9c51632a0a8)
 Energy = 0.200
Tx Waveform Passed from Channel...


Rx Waveform Processing Starting...
V2X PSxCH Subframe pool (total 508 subframes)
( V2X PSxCH Subframes : 4 24 44 64 84 104 124 144 165 185 205 225 245 265 285 305 326 346 366 386 406 426 446 466 487 507 527 547 567 587 607 627 649 669 689 709 729 749 769 789 810 830 850 870 890 910 930 950 971 991 1011 1031 1051 1071 1091 1111 1132 1152 1172 1192 1212 1232 1252 1272 1294 1314 1334 1354 1374 1394 1414 1434 1455 1475 1495 1515 1535 1555 1575 1595 1616 1636 1656 1676 1696 1716 1736 1756 1777 1797 1817 1837 1857 1877 1897 1917 1939 1959 1979 1999 2019 2039 2059 2079 2100 2120 2140 2160 2180 2200 2220 2241 2261 2281 2301 2321 2341 2361 2381 2402 2422 2442 2462 2482 2502 2522 2542 2564 2584 2604 2624 2644 2664 2684 2704 2725 2745 2765 2785 2805 2825 2845 2865 2886 2906 2926 2946 2966 2986 3006 3026 3047 3067 3087 3107 3127 3147 3167 3187 3209 3229 3249 3269 3289 3309 3329 3349 3370 3390 3410 3430 3450 3470 3490 3510 3531 3551 3571 3591 3611 3631 3651 3671 3692 3712 3732 3752 3772 3792 3812 3832 3854 3874 3894 3914 3934 3954 3974 3994 4015 4035 4055 4075 4095 4115 4135 4155 4176 4196 4216 4236 4256 4276 4296 4316 4337 4357 4377 4397 4417 4437 4457 4477 4499 4519 4539 4559 4579 4599 4619 4639 4660 4680 4700 4720 4740 4760 4780 4801 4821 4841 4861 4881 4901 4921 4941 4962 4982 5002 5022 5042 5062 5082 5102 5124 5144 5164 5184 5204 5224 5244 5264 5285 5305 5325 5345 5365 5385 5405 5425 5446 5466 5486 5506 5526 5546 5566 5586 5607 5627 5647 5667 5687 5707 5727 5747 5769 5789 5809 5829 5849 5869 5889 5909 5930 5950 5970 5990 6010 6030 6050 6070 6091 6111 6131 6151 6171 6191 6211 6231 6252 6272 6292 6312 6332 6352 6372 6392 6414 6434 6454 6474 6494 6514 6534 6554 6575 6595 6615 6635 6655 6675 6695 6715 6736 6756 6776 6796 6816 6836 6856 6876 6897 6917 6937 6957 6977 6997 7017 7037 7059 7079 7099 7119 7139 7159 7179 7199 7220 7240 7260 7280 7300 7320 7340 7361 7381 7401 7421 7441 7461 7481 7501 7522 7542 7562 7582 7602 7622 7642 7662 7684 7704 7724 7744 7764 7784 7804 7824 7845 7865 7885 7905 7925 7945 7965 7985 8006 8026 8046 8066 8086 8106 8126 8146 8167 8187 8207 8227 8247 8267 8287 8307 8329 8349 8369 8389 8409 8429 8449 8469 8490 8510 8530 8550 8570 8590 8610 8630 8651 8671 8691 8711 8731 8751 8771 8791 8812 8832 8852 8872 8892 8912 8932 8952 8974 8994 9014 9034 9054 9074 9094 9114 9135 9155 9175 9195 9215 9235 9255 9275 9296 9316 9336 9356 9376 9396 9416 9436 9457 9477 9497 9517 9537 9557 9577 9597 9619 9639 9659 9679 9699 9719 9739 9759 9780 9800 9820 9840 9860 9880 9900 9921 9941 9961 9981 10001 10021 10041 10061 10082 10102 10122 10142 10162 10182 10202 10222 )
V2X PSCCH PRB Pool contains  5 subchannels, of size  2 PRBs each, with lowest PRB index of subchannel #0 =  0
[Subchannel  0] PRBs :  0  1
[Subchannel  1] PRBs :  5  6
[Subchannel  2] PRBs : 10 11
[Subchannel  3] PRBs : 15 16
[Subchannel  4] PRBs : 20 21
N_blocks =
   160
Signal found for PSSS 1
Normal cp mode discovered
SSSS discovered
Initial Synchronization achieved
Estimated Freq Offset: 0.0103
Successfully Detected SL-BCH
Read out MIB-SL: NSLRB = 25 RBs, directFrameNumber_r12 = 0, directSubframeNumber_r12 = 0
PSBCH Decoding Qual Evaluation [CUMULATIVE Stats]: Bit Errors = 0/1008 (BER = 0.0000), SNR approx (dB) = 20.963
System Info Acquired for the first time!
Trying to decode PSCCH in the expected subframe (4). Energy=0.0101
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (24). Energy=0.2114
   ** SCI/PSCCH Recovery done for PRB Set [ 0  1 ] : CRCerror=0, nXID_rec=883 **
Bit Errors = 0/480 (BER = 0.0000), EVM = 0.0824, SNR(dB) = 21.677
Information Recovery from SCI-1 message 1000 (hex format)
Resource Reservation (Actual)                                        :  0.0
Frequency resource location (INT)                                    :  0
Time gap between initial transmission and retransmission  (INT)      :  0
Modulation and Coding (INT)                                          :  1
Retransmission index                                                 :  0
Reserved information bits (INT)                                      :  0
	(FRL Bitmap --> nsubCHstart = 0, LsubCH = 1)
PSSCH ModOrder = 2
PSSCH TBSize = 88 (bits)
PSSCH Num of PRBs = 3
PSSCH Bit Capacity = 720 (bits)
==================================================
 PSSCH PRBs [txOp = 1]: 2 3 4
==================================================
 PSCCH Subframes :  
	  ** DATA Recovery done !!!!! **
Bit Errors = 0/720 (BER = 0.0000), EVM = 0.0868, SNR(dB) = 21.233
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (44). Energy=0.0101
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (64). Energy=0.0099
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (84). Energy=0.0099
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (104). Energy=0.0098
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (124). Energy=0.0100
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
Trying to decode PSCCH in the expected subframe (144). Energy=0.0101
   ** SCI/PSCCH Recovery failed for PRB Set [ 0  1 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 5  6 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 10  11 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 15  16 ]
   ** SCI/PSCCH Recovery failed for PRB Set [ 20  21 ]
```
