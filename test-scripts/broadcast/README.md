### Example Use of the Library: Sidelink broadcast/synchronization transceiver simulation

The example provides a high-level walkthrough for setting up, configuring, and running a complete transceiver simulation scenario for the sidelink broadcast channel. The example includes (refer to file "sidelink_broadcast_tester.m"):
* The generation of sidelink-compliant broadcast subframes in frequency and time domains.
* The generation and application of noise, delay, and frequency-offset impairments to the ideal waveform.
* The recovery of the MIB-SL messages carried by the channel-impaired broadcast subframes.

The sidelink broadcast subframe carries two kinds of "information":
* The MIB-SL message, containing fields such as the cell subframe/frame timing, the bandwidth mode, in-coverage/out-of-coverage indicators, etc.
* Two sets of synchronization preambles, through which the receiving D2D UEs acquire time reference from the transmitting D2D UEs.
Therefore, each 'broadcast' subframe is simultaneously a 'synchronization' subrame.

:exclamation: _According to the standard the broadcast channel transmission may be triggered by any of the two core D2D operation modes, i.e. discovery and communication, and assists such transmissions. Therefore we could not transmit a broadcast subframe without sending a discovery/communication subframe as well. For flexibility purposes, in our implementation we define a "standalone" broadcast transmission mode as well.

##### CONFIGURATION
A set of parameters shown in the following Table determine the exact scenario configuration. For each parameter, a default setting is also defined.

Parameter | Description | Acceptable Settings | Default Configuration
------------ | -------------| -------------| -------------
```cp_Len_r12``` | Cyclic Prefix Length | ```'Normal'```, ```'Extended'``` | ```'Normal'```
```NSLRB``` | Number of Sidelink RBs | ```6```,```15```,```25```,```50```,```75```,```100``` | ```25```
```NSLID``` | Sidelink Physical Layer Synchronization ID | ```0``` - ```335```| ```0```
```slMode``` | Sidelink Transmission Mode (D2D, V2V) | ```1```,```2```,```3```,```4```| ```1```
```syncOffsetIndicator``` | Sync Subframe Offset Indicator (w.r.t. subframe #0) | ```0``` - ```39```| ```0```
```syncPeriod``` | Sync Subframe Period (in # subframes) | ```1``` - ```160``` | ```40```
```decodingType``` | Symbol Decoding Type | ```'Soft'```,```'Hard'``` | ```'Soft'```
```chanEstMethod``` | Channel Estimation Method | ```'LS'```,```'mmse-direct'``` | ```'LS'```
```timeVarFactor``` | Estimated Channel Doppler Frequency  | ```0``` or a value ```>0``` (Hz) | ```0```
```numTotSubframes``` | Number of Generated Sidelink Subframes | ```0``` - ```10240``` | ```10240```

More on the parameters:

The top 5 parameters are common for both transmitting and receiving ProSe-enabled UEs.
* ```cp_Len_r12``` determines the cyclic prefix length of the waveform. For in-coverage UEs this is known through L3 signaling (cell-specific/common SIB or ue-specific RRC messages), whereas for out-of-coverage UEs it is pre-configured. For the V2V mode use only the ```'Normal'``` mode. The ```Extended``` mode is not fully tested yet, so for the time being stick to the ```Normal``` mode.
* ```NSLRB``` determines the sidelink bandwidth mode, i.e. 1.4, 3, 5, 10, 15 or 20 MHz for 6, 15, 25, 50, 75, and 100 RBs respectively. The 5 MHz mode is fully tested to date.
* ``` NSLID``` determines the sidelink-equivalent physical cell id. Similarly to the ```cp_Len_r12``` parameter this is configured in higher layers.
* ```slMode``` determines the transmission mode which is triggered by the corresponding sidelink communication functionality. Modes ```1``` or ```2``` refer to "standard" D2D defined in Rel.12 and Rel.13, while modes ```3``` and ```4``` were introduced for the first time in Rel.14 to account for D2D "tweaks" tailored to V2X operation. For the broadcast channel, modes ```1``` and ```2``` are equivalent, so as ```3``` and ```4```.
* ```syncOffsetIndicator``` determines the offset of the sync/broadcast subframe with respect to subframe #0. This could be used for assigning independent sync subframes to different potential D2D transmitting UEs.
* ```syncPeriod``` determines the period (in # subframes) according to which the sync/broadcast subframes are repeated. In our standalone broadcast mode, only periodic transmission is allowed. In actual modes (discovery and communication) non-periodic ("single-shot") broadcast subframe transmission is supported. In addition, according to the standard the broadcast subframe period is fixed to 40 msec for standard sidelink modes (1,2), and 160 msec for V2X modes (3,4). In our implementation we enable an arbitrary tuning of the period.

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
