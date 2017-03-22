## Welcome to the *lte-sidelink* project page

*lte-sidelink* is an open software library developed in MATLAB by [Feron Technologies P.C.](http://www.feron-tech.com), that implements the most important functionalities of the 3GPP LTE sidelink interface. 

### Introduction
Sidelink is a new LTE feature introduced in 3GPP Release 12 aiming at enabling device-to-device (**D2D**) communications within legacy cellular-based LTE radio access networks. Sidelink has been enriched in Releases 13 and 14 with various features. D2D is applicable to public safety and commercial communication use-cases, and recently (Rel.14) to vehicle-to-vehicle  (**V2V**) scenarios. In legacy uplink/downlink, two UEs communicate through the Uu interface and data are always traversing the LTE eNB. Differently, sidelink enables the direct communication between proximal UEs using the newly defined PC5 interface, and data does not need to traverse the eNB. Services provided in this way are often called "Proximity Services" (or ProSe) and the UEs suppporting this feature "ProSe"-enabled UEs.

The library provides an (almost) complete implementation of the sidelink physical signals, physical channels and transport layer functionalities described in the 3GPP standard. In addition it provides the neccessary receiver processing functionalities for generating and/or recovering a real sidelink signal which is either simulated/emulated or sent over the air and captured from an SDR board. The code is highly-modular and documented in order to be easily understood and further extended.

The library has many usages. Typical use-case examples are the following:
* LTE sidelink waveform generator.
* End-to-end sidelink link-level simulator.
* Core component of a sidelink system-level simulator.
* Platform for testing new resource allocation/scheduling algorithms for D2D/V2V communications.
* Tool to experiment with live standard-compliant sidelink signals with the help of SDR boards.

The following 3GPP standard documents have been used and referenced through the code:
* 36.211 Physical channels and modulation (Section 9)
* 36.212 Multiplexing and channel coding (Section 5.4)
* 36.213 Physical layer procedures (Sections 5.2.2.25, 5.2.2.26, 5.10, 14)
* 36.321 Medium Access Control (MAC) protocol specification (Sections 5.14, 5.15, 5.16)
* 36.331 Radio Resource Control (RRC); Protocol specificatiοn (Sections 6.5.2, 6.3.8)
  
Further details for the 3GPP D2D/V2V standardization and implementation could be found in:
* 22.803 Feasibility study for Proximity Services (ProSe) [Rel.12]
* 36.843 Study on LTE Device to Device Proximity Services - D2D Radio Aspects [Rel.12]
* 36.877 Study on LTE Device to Device Proximity Services - D2D User Equipment (UE) radio transmission and reception [Rel.12]
* Rohde&Schwarz Device to Device Communication in LTE Whitepaper [Application Note 1MA264](https://www.rohde-schwarz.com/gr/applications/device-to-device-communication-in-lte-white-paper_230854-142855.html)

### Features
#### Supported Features
* Sidelink air-interface compliant with:
  * "Standard" D2D based on Rel.12 and Rel.13 
  * D2D tweaks for V2V communications based on Rel.14
* Broadcast transport & physical channel processing functionalities 
  * Generation and recovery of MIB-SL messages
  * Encoding and recovery of the SL-BCH transport channel
  * Encoding and recovery of the PSBCH physical channel
  * Demodulation Reference Signals (DMRS) construction and loading
* Sidelink discovery mode
  * Physical Signals and Channels: SL-DCH, PSDCH, PSDCH DMRS
  * Subframe/PRB discovery pool formation & UE-specific resource allocation
* Sidelink communication mode :new:
  * Physical Signals and Channels for Control Signaling: SCI Format 0, PSCCH, SL-SCH, PSSCH, PSCCH DMRS
  * Physical Signals and Channels for Payload : SL-SCH, PSSCH, PSSCH DMRS
  * Subframe/PRB communication pool formation & UE-specific resource allocation
* Synchronization preambles (PSSS, SSSS) construction & recovery
* Subframe creation, loading and time-domain signal transformation
* Complete receiver processing functionality for sidelink-compliant waveforms
  * time-synchronization
  * frequency-offset estimation and compensation
  * channel estimation and equalization
  * signal demodulation/decoding
* Example scripts for configuring and running full sidelink broadcast, discovery, communication transceiver simulation scenarios

#### Upcoming Features
* V2X sidelink communication mode
  * Physical Signals and Channels for L1 signaling: SCI Format 1 (V2V), PSCCH, PSCCH DMRS
  * Physical Signals and Channels for Payload: V2X PSSCH, PSSCH DMRS
  * Subframe/PRB pool formation & UE-specific resource allocation for V2X communication

### Repository Structure
* The **home** directory includes scripts for testing sidelink functionality
* The **core/** directory includes sidelink-specific functionalities, i.e. physical/transport channel, DMRS, synchronization, channel estimator) organized in classes.
* The **generic/** directory includes generic (non-sidelink specific) tx/rx functionalities organized in functions, i.e. signal, physical and transport channel blocks, neccessary for core classes implementation.

#### Dependencies/Notes
* All functionalities are developed in-house except for: i) CRC encoding/detection, ii) Convolutional Encoding/Decoding. For these, the corresponding MATLAB Communication Toolbox System Objects have been used. In-house versions of these two blocks will be also provided soon.
* Convolution channel coding has been applied for sidelink discovery and communication modes transport channel processing, instead of standard-compliant turbo coding.
* Testing of the code has been done in MATLAB R2016b.

### Walkthrough Example 1: Sidelink broadcast/synchronization transceiver simulation
The example provides a high-level walkthrough for setting up, configuring, and running a complete transceiver simulation scenario for the sidelink broadcast channel. The example includes (refer to file [sidelink_broadcast_tester.m](sidelink_broadcast_tester.m)):
* The generation of sidelink-compliant broadcast subframes in frequency and time domains.
* The generation and application of noise, delay, and frequency-offset impairments to the ideal waveform.
* The recovery of the MIB-SL messages carried by the channel-impaired broadcast subframes.

The sidelink broadcast subframe carries two kinds of "information":
* The MIB-SL message, containing fields such as the cell subframe/frame timing, the bandwidth mode, in-coverage/out-of-coverage indicators, etc.
* Two sets of synchronization preambles, through which the receiving D2D UEs acquire time reference from the transmitting D2D UEs.
Therefore, each 'broadcast' subframe is simultaneously a 'synchronization' subrame.

:exclamation: _According to the standard the broadcast channel transmission may be triggered by any of the two core D2D operation modes, i.e. discovery and communication, and assists such transmissions. Therefore we could not transmit a broadcast subframe without sending a discovery/communication subframe as well. For flexibility purposes, in our implementation we define a "standalone" broadcast transmission as well._

##### CONFIGURATION
A set of parameters shown in the following Table determine the exact scenario configuration. For each parameter, a default setting is also defined.

Parameter | Description | Acceptable Settings | Default Configuration
------------ | -------------| -------------| -------------
```cp_Len_r12``` | Cyclic Prefix Length | ```'Normal'```, ```'Extended'``` | ```'Normal'```
```NSLRB``` | Number of Sidelink RBs | ```6```,```15```,```25```,```50```,```75```,```100``` | ```25```
```NSLID``` | Sidelink Physical Layer Synchronization ID | ```0``` - ```335```| ```0```
```slMode``` | Sidelink Transmission Mode (D2D, V2V) | ```1```,```2```,```3```,```4```| ```1```
```syncOffsetIndicator``` | Sync Subframe Offset Indicator (w.r.t. subframe #0) | ```0``` - ```39```| ```0```
```syncPeriod``` | Sync Subframe Period (in # subframes) | ```1``` - ```40``` | ```40```
```decodingType``` | Symbol Decoding Type | ```'Soft'```,```'Hard'``` | ```'Soft'```
```chanEstMethod``` | Channel Estimation Method | ```'LS'```,```'mmse-direct'``` | ```'LS'```
```timeVarFactor``` | Estimated Channel Doppler Frequency  | ```0``` or a value ```>0``` (Hz) | ```0```
```numTotSubframes``` | Number of Generated Sidelink Subframes | ```0``` - ```10240``` | ```10240```

More on the parameters:

The top 5 parameters are common for both transmitting and receiving ProSe-enabled UEs.
* ```cp_Len_r12``` determines the cyclic prefix length of the waveform. For in-coverage UEs this is known through L3 signaling (cell-specific/common SIB or ue-specific RRC messages), whereas for out-of-coverage UEs it is pre-configured. For the V2V mode use only the ```'Normal'``` mode. The ```Extended``` mode is not fully tested yet, so for the time being stick to the ```Normal``` mode.
* ```NSLRB``` determines the sidelink bandwidth mode, i.e. 1.4, 3, 5, 10, 15 or 20 MHz for 6, 15, 25, 50, 75, and 100 RBs respectively. The 5 MHz mode is fully tested to date.
* ``` NSLID``` determines the sidelink-equivalent physical cell id. Similarly to the ```cp_Len_r12``` parameter this is configured in higher layers.
* ```slMode``` determines the transmission mode which is triggered by the corresponding sidelink communication functionality. Modes ```1``` or ```2``` refer to "standard" D2D defined in Rel.12 and Rel.13, while modes ```3``` and ```4``` were introduced for the first time in Rel.14 to account for D2D "tweaks" tailored to V2V operation. For the broadcast channel, modes ```1``` and ```2``` are equivalent, so as ```3``` and ```4```.
* ```syncOffsetIndicator``` determines the offset of the sync/broadcast subframe with respect to subframe #0. This could be used for assigning independent sync subframes to different potential D2D transmitting UEs.
* ```syncPeriod``` determines the period (in # subframes) according to which the sync/broadcast subframes are repeated. In our standalone broadcast mode, only periodic transmission is allowed. In actual modes (discovery and communication) non-periodic ("single-shot") broadcast subframe transmission is supported. In addition, according to the standard the broadcast subframe period is fixed to 40 msec. In our implementation we have allowed to tune the period.

The next 3 parameters have to do with the tuning of the in-house receiver processing functionalities, namely channel estimation and signal recovery:
* ```decodingType``` determines if soft or hard decision decoding/demodulation is applied. Soft- and hard-specific signal demapping, descrambling and channel decoding functionalities are implemented accordingly.
* ```chanEstMethod``` determines the applied channel estimation method. Choose between fully supported "Least Squares" ('LS') and Minimum Mean Square error ('mmse-direct') methods.
* ```timeVarFactor``` determines the expected time variability of the channel, based on doppler frequency. Set it to ```0``` for static or unknown channel variability.

The last parameter, ```numTotSubframes```, determines the number of generated sidelink subframes. Up to 10240 subframes could be generated, corresponding to a full operation cycle.

An example configuration using the default settings is the following:
```
cp_Len_r12          = 'Normal';    
NSLRB               = 25;
NSLID               = 0;
slMode              = 1;
syncPeriod          = 40;
decodingType        = 'Soft';
chanEstMethod       = 'LS';
timeVarFactor       = 0;  
numTotSubframes     = 10240;
```

##### Sidelink Broadcast Waveform Generation
The sidelink broadcast waveform is generated using the high-level function ```broadcast_tx```. The output of the function contains the time-domain samples for a duration given by the ```numTotSubframes``` parameter, starting at subframe #0. Assuming a 5 MHz bandwidth mode (```NSLRB=25```), the output of the function is a complex vector with length ```7680*numTotSubframes```, where ```7680``` is the number of time-domain samples per subframe for the given bandwidth.
The function should be used as follows:
```
tx_output = broadcast_tx(struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode), ...
    struct('syncOffsetIndicator',syncOffsetIndicator,'syncPeriod',syncPeriod), ...
    numTotSubframes);
```
The first structure includes the broadcast-specific parameters, the second structure the synchronization-specific parameters, and the last scalar parameter the number of subframes to generate (up to 10240). The provided structures fields are optional. For any missing field its default value is used. To apply the default broadcast/sync configuration call ```broadcast_tx```using empty structures:
```
tx_output = broadcast_tx(struct(), struct(), numTotSubframes);
```
:bell: Beware that for storing the waveform for a full time cycle (10240 subframes) you will need a complex vector containing ```78,643,200 elements```, which requires approximately ```1.25 GB``` of memory.

##### Apply Test Channel
This is an optional module. The objective is to model a simple channel considering three kinds of impairments (noise, time offset, frequency offset) and apply it to the generated sidelink waveform.
The channel impairments are generated as follows:
* _Additive white gaussian noise_ : This is used to test the broadcast decoder robustness in various signal level conditions. The generated noise samples amplitude depends on an input target ```SNR``` level provided in ```dB``` units (e.g. ```SNR_target_dB = 13 dB```).
* _Time offset_: This is used for testing the time synchronization accuracy. A random time-offset is generated using the code snippet ```toff = randi([0,samples_per_subframe],1,1);```.
* _Frequency offset_: This is used for testing the frequency offset estimation quality. A % frequency offset error is configured and then applied to the waveform. An example code snippet for defining a 1% error is ```foff = 0.01;```.

The application of the impairments to the ideal waveform is done as follows (```NFFT``` is the FFT length, depending on the bandwidth mode. For the 5 MHz mode, ```NFFT=512```):
```
rx_input = tx_output + sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1));
rx_input = [zeros(toff,1); rx_input]; 
rx_input = rx_input(:).*exp(2i*pi*(0:length(rx_input(:))-1).'*foff/NFFT);
```

##### Sidelink Broadcast Channel Recovery
The last part of the example corresponds to the recovery of MIB-SL messages given an input waveform and a known sidelink configuration. The input waveform could be one of the following :
* The ideal waveform generated by the ```broadcast_tx()``` function.
* The ideal waveform impaired by the channel model discussed previously.
* A live sidelink broadcast waveform captured using a general-purpose SDR board.
The recovery procedure involves the following steps:
* Initial Acquisition
  * Timing acquisition based on the sidelink synchronization preambles detection
  * Frequency-offset estimation and compensation
  * Time-to-frequency domain signal transformation
  * Channel estimation and equalization based on the SL DMRS signals
  * PSBCH decoding
  * SL-BCH decoding
  * MIB-SL CRC detection check and recovery of frame and subframe timing information fields
* Continuous Operation
  * Refinement of time synchronization and frequency offset estimation/compensation
  * Look only at subframes where the MIB-SL is expected to be present (based on the timing acquisition results and the known synchronization period) and recover the carried information.
  * Estimation of PSBCH decoding quality using BER, PER, and an EMV-based metric.
 
The MIB-SL messages recovery operations are appled by calling the high-level function ```broadcast_rx()``` as follows:
```
broadcast_rx(struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode), ...
     struct('syncOffsetIndicator',syncOffsetIndicator,'syncPeriod',syncPeriod),...
     struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
     rx_input);
```
In addition to the sidelink broadcast and synchronization structures, a receiver processing configuration structure is also defined. The last argument corresponds to a complex vector containing the input waveform time-domain samples.
Again, for the default configuration you may simply call the recovery function as follows:
```
broadcast_rx(struct(), struct(), struct(), rx_input);
```

### Walkthrough Example 2: Sidelink discovery transceiver simulation
#### A short introduction to D2D Discovery
The sidelink discovery mode is used for sending (in a broadcast way) short messages to neighbor UEs. Protocol processing is extremely light; in essence each message corresponds to a single PHY transport block, containing no higher-ligher additional overhead. How to fill the transport block is left open, and depends on the underlying D2D application. To support timing reference recovery at the monitoring D2D UEs, the announcing D2D UE(s) trigger the transmission of broadcast/synchronization subframes as described in the previous example. The sidelink discovery transmission/reception procedure involves two key functionalities:
* Selection of time (subframes) and frequency (PRBs) resources for announcing/monitoring discovery messages. Sidelink resource allocation is realized in two levels:
  * *inter sidelink-uplink level*, responsible for the determination of sidelink resource pools to avoid conflict with resources used for regular uplink transmissions.
  * *intra-sidelink level*, responsible for the determination of UE-specific resources, based on the configured sidelink resource pool(s). For receiving D2D UEs, multiple resources may be monitored in order to "listen" for simultaneous discovery announcements.
* L1 processing, i.e. signal generation (for tx) and transport block recovery operations (for rx). The processing includes:
  * Transport channel processing (SL-DCH);
  * Physical channel processing (PSDCH) assisted by PSDCH DMRS;
  * Triggering of broadcast/synchronization transmissions to assist time-synchronization and frequency offset compensation at the receiving side.

Next, we provide a high-level walkthrough for setting up, configuring, and running a complete transceiver simulation scenario for the sidelink discovery mode (refer to file [sidelink_discovery_tester.m](sidelink_discovery_tester.m)):

#### Configuration
The available parameters may be organized in three groups:
* **Basic** configuration group, providing the key operational system parametrization. It includes the cyclic prefix length (``cp_Len_r12``), sidelink bandwidth mode (``NSLRB``), sidelink physical layer id (``NSLID``), sidelink mode (``slMode``), synchronization offset with respect to SFN/DFN #0 (``syncOffsetIndicator``), and synchronization period (``syncPeriod``), for both discovery and triggered broadcast/synchronization subframes. The detailing of the specific parameters has been provided in the Broadcast example description.
* **Discovery Resources Pool** configuration, providing the sidelink resources allocation parametrization. The available parameters are briefly described in the following bullet points. For more details, please refer to the 3GPP standard, 36.331 - 6.3.8, and particularly at the sidelink-related IEs included in the standard from Rel.12 and on.
  * ``discPeriod_r12``: the period (in # frames) for which the resource allocation configuration is valid (available configurations: 32,64,128,256,512,1024 frames)
  * ``offsetIndicator_r12``: the subframe offset (with respect to SFN/DFN #0) determining the start of the discovery period.
  * ``subframeBitmap_r12`` : a length-40 bitmap determining the time (subframe) pattern used for sidelink transmissions (unit-elements determine the subframes available for sidelink transmissions)
  * ``numRepetition_r12``: the repeating pattern of the subframe bitmap (available configurations: 1-5)
  * ``prb_Start_r12``: the  first PRB index of the bottom PRB pool available for discovery transmissions
  * ``prb_End_r12``: the last PRB index of the top PRB pool available for discovery transmissions
  * ``prb_Num_r12`` : the number of PRBs assigned to top/bottom PRB pools for discovery transmissions
  * ``numRetx_r12`` : the number each discovery message is re-transmitted (available configurations: 0-3)
  * ``networkControlledSyncTx`` : determines if broadcast/sync subframes should be triggered (1 for triggering, 0 for no-triggering) 
  * ``syncTxPeriodic`` : determines if the triggered broadcast/sync subframes are transmitted at once ("single-shot") or periodically
  * ``discType``: determines how sidelink resources are allocated to the different discovery transmissions, i.e. selected by each UE in an autonomous manner (``Type-1``) or configured by the eNB in a centralized manner (``Type-2``).
* **UE-specific resources allocation** configuration, providing the specific subframes and PRBs allocated to each discovery message and the (potential) retrasmissions. In particular:
  * For ``Type-1`` resource allocation, a single parameter, ``nPSDCH``, determines the exact resources subset. In particular,  each``nPSDCH`` value corresponds to a distinct combination of a single subframe and a PRB set used for carrying a single discovery message. Using different ``nPSDCH`` settings for distinct messages announcement allows to avoid intra-sidelink interference.
  * For ``Type-2`` resource allocation, PRB and subframe resources are determined explicitly using a set of two parameters, ``discPRB_Index`` and ``discSF_Index``. Lastly, for hopping-based resource allocation, the applied hopping patterns are determined based on set of three parameters, ``a_r12``,``b_r12``, and ``c_r12``.

#### Running the example
An example ``Type-1`` configuration is shown below. Notice that in addition to the aforementioned parameters we have included: i) a parameter determing which resources the receiving UE will monitor for identifying potential discovery announcements (```n_PSDCHs_monitored```), ii) a set of three parameters (```decodingType```, ```chanEstMethod```, ```timeVarFactor```), used for tuning channel estimation and channel decoding operations at the receiver side.
```
cp_Len_r12              = 'Normal';
NSLRB                   = 25;
NSLID                   = 301;
slMode                  = 1;
syncOffsetIndicator     = 0;
syncPeriod              = 40;
discPeriod_r12          = 32;
offsetIndicator_r12     = 0;
subframeBitmap_r12      = repmat([0;1;1;1;0],8,1);
numRepetition_r12       = 5;
prb_Start_r12           = 2;
prb_End_r12             = 22;
prb_Num_r12             = 5;
numRetx_r12             = 2;
networkControlledSyncTx = 1;
syncTxPeriodic          = 1;
discType                = 'Type1';
n_PSDCHs                = [0; 6];
n_PSDCHs_monitored      = n_PSDCHs;
decodingType            = 'Soft';
chanEstMethod           = 'LS';
timeVarFactor           = 0;
```
As in the broadcast example, transmission/reception operations are captured in corresponding function blocks, ```discovery_tx()``` and ```discovery_rx()```, respectively. 

By default,```discovery_tx()``` creates a standard-compliant discovery waveform for a period determined by the ``discPeriod_r12`` parameter. The waveform (stored in the ``tx_output`` variable) contains not only the discovery signal samples but also the triggered broadcast/synchronization signal samples for the specific period. An example call of the discovery tx waveform generation function block is as follows:
```
slBaseConfig = struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode);
slSyncConfig = struct('syncOffsetIndicator', syncOffsetIndicator,'syncPeriod',syncPeriod);
slDiscConfig = struct('offsetIndicator_r12', offsetIndicator_r12, 'discPeriod_r12',discPeriod_r12, 'subframeBitmap_r12', subframeBitmap_r12, 'numRepetition_r12', numRepetition_r12, ...
    'prb_Start_r12',prb_Start_r12, 'prb_End_r12', prb_End_r12, 'prb_Num_r12', prb_Num_r12, 'numRetx_r12', numRetx_r12, ...
    'networkControlledSyncTx',networkControlledSyncTx, 'syncTxPeriodic',syncTxPeriodic, 'discType', discType);
slUEconfig = struct('n_PSDCHs',n_PSDCHs); 
tx_output = discovery_tx( slBaseConfig, slSyncConfig, slDiscConfig, slUEconfig );
```
The generated time-domain waveform for a period of 50 subframes is illustrated in the following figure. The subframe locations of the discovery message transmissions (and potentially re-transmissions) depend on the selected ``nPSDCH`` configuration. In addition, the triggered broadcast/sync subframes repeated every 40 subframes are also shown.
<img src="./discovery_waveform_example_time.jpg"  width="80%" height="80%" align="middle"/>

The frequency-domain resource allocation for the discovery message configured with ```nPSDCH = 0``` is also shown below. Three transmissions for the particular message have been configured (since ``numRetx_r12=2``).

<img src="./discovery_waveform_example_freq.jpg"  width="60%" height="60%"  align="middle"/>

Next, the tx waveform passes through a typical channel, and the resulted waveform (stored in the ``rx_input`` variable) is fed to the discovery monitoring/receiving function block. This is called as follows:
```
discovery_rx(slBaseConfig, slSyncConfig, slDiscConfig,  ...
    struct('n_PSDCHs',n_PSDCHs_monitored), ...
    struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
    rx_input );
```
Notice that in addition to sidelink basic configuration (``slBaseConfig`` and ``slSyncConfig``) and discovery resources pool configuration (``slDiscConfig``), we provide as input the discovery messages monitoring search space and the channel estimation/decoding parameters. The discovery monitoring function returns the recovered (if any) discovery messages. For the specific configuration example the following output is printed at the end of the execution (intermeddiate log/debug messages print-out is also supported):
```
Recovered Discovery Messages
	[At Subframe     1: Found nPSDCH =   0]
	[At Subframe     2: Found nPSDCH =   0]
	[At Subframe     3: Found nPSDCH =   0]
	[At Subframe    31: Found nPSDCH =   6]
	[At Subframe    32: Found nPSDCH =   6]
	[At Subframe    33: Found nPSDCH =   6]
```
It is clear that both discovery messages contained in the tx waveform have been recovered successfully at the receiver side.


### Walkthrough Example 3: Sidelink communication transceiver simulation
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
An example "mode-1" configuration is shown below. Notice that in addition to the aforementioned parameters we have included: i) a parameter called ```n_PSCCHs_monitored``, determing which resources the receiving UE will monitor for identifying potential SCI Format 0  messages, ii) a set of three parameters, i.e. ``decodingType```, ```chanEstMethod```, and ```timeVarFactor```, used for tuning channel estimation and channel decoding operations at the receiver side, similarly to the the discovery/broadcast subframe decoding procedures.

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

### Acknowledgement
Part of the activities leading to this library received funding from the European Union’s Seventh Framework Programme under grant agreement no 612050, ["FLEX Project"](http://www.flex-project.eu/), and in particular FLEX Open Call 2 Project [“FLEX-D: Experimenting with Flexible D2D communications Over LTE”](http://www.flex-project.eu/open-calls/2nd-open-call/results). FLEX-D is carried out by Feron Technologies and University of Piraeus Research Centre, Greece.

### Support

:envelope: Drop us an e-mail if you are interested in using/extending the library or you need further clarifications on the configuration/execution of the examples.

<img src="./feron.png" width="200" height="200" />
