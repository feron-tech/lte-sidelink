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
* 36.331 Radio Resource Control (RRC); Protocol specificatiοn (Section 6.5.2)
  
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
* Synchronization preambles (PSSS, SSSS) construction & recovery
* Demodulation Reference Signals (DMRS) construction for PSBCH (other sidelink are supported but not fully tested)
* Subframe creation, loading and time-domain signal transformation
* Complete receiver processing functionality for sidelink-compliant waveforms
  * time-synchronization
  * frequency-offset estimation and compensation
  * channel estimation and equalization
  * signal demodulation/decoding
  * example script for configuring and running a full sidelink broadcast transceiver simulation scenario

#### Upcoming Features
* Sidelink discovery mode
  * Physical Signals and Channels: SL-DCH, PSDCH, PSDCH DMRS
  * Subframe/PRB discovery pool formation & UE-specific resource allocation
* Sidelink communication mode
  * Physical Signals and Channels for L1 signaling: SCI-0 (D2D), SCI-1 (V2V), PSCCH, PSCCH DMRS
  * Physical Signals and Channels for Payload: PSSCH, PSSCH DMRS
  * Subframe/PRB discovery pool formation & UE-specific resource allocation

### Repository Structure
* The **home** directory includes scripts for testing sidelink functionality
* The **core/** directory includes sidelink-specific functionalities, i.e. physical/transport channel, DMRS, synchronization, channel estimator) organized in classes.
* The **generic/** directory includes generic (non-sidelink specific) tx/rx functionalities organized in functions, i.e. signal, physical and transport channel blocks, neccessary for core classes implementation.

#### Dependencies/Notes
* All functionalities are developed in-house except for: i) CRC encoding/detection, ii) Convolutional Encoding/Decoding. For these, the corresponding MATLAB Communication Toolbox System Objects have been used. In-house versions of these two blocks will be also provided soon.
* Testing of the code has been done in MATLAB R2016b.

### A simple walkthrough example: Sidelink broadcast/synchronization transceiver simulation
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

### Acknowledgement
Part of the activities leading to this library received funding from the European Union’s Seventh Framework Programme under grant agreement no 612050, ["FLEX Project"](http://www.flex-project.eu/), and in particular FLEX Open Call 2 Project [“FLEX-D: Experimenting with Flexible D2D communications Over LTE”](http://www.flex-project.eu/open-calls/2nd-open-call/results).

### Support

:envelope: Drop us an e-mail if you are interested in using/extending the library or you need further clarifications on the configuration/execution of the examples.

<img src="./feron.png" width="200" height="200" />
