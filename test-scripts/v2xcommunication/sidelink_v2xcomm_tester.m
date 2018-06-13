% Main script for executing a full sidelink v2x communication Tx/Rx scenario
% Contributors: Antonis Gotsis (antonisgotsis), Konstantinos Maliatsos (maliatsos)

clear all;
clc;
addpath('../../core');   % path where core sidelink-specific functionalities are located (Discovery Channel, DMRS, Sync, Channel Estimator).
addpath('../../lib');    % path where generic (non-sidelink specific) tx/rx functionalities are located (signal, physical and transport channel blocks).
warning('off','MATLAB:structOnObject'); % used to supress warning messages in struct(obj) calling

%% Configuration
% common for Tx/Rx: (reflect 36.331 - 6.3.8, sidelink-related IEs)
% SL Basic Operation Parameters: common for communication and broadcast (if present)
NSLRB                           = 25;                     % Sidelink bandwidth configuration in RBs: 6, 15, 25, 50, 100 (default : 25)
NSLID                           = 301;                    % SLSSID: Physical layer sidelink synchronization identity: 0..335 (default 0)
slMode                          = 3;                      % Sidelink Mode: 3 (V2V-scheduled) or 4 (V2V autonomous sensing)
% Sync
syncOffsetIndicator             = 0;                      % SL-SyncConfig: Offset indicator for sync subframe with respect to subframe #0: 0..159 (default : 0)
syncTxPeriodic                  = 1;                      % SL-SyncConfig: single-shot or periodic sync (default: 1)          
syncPeriod                      = 160;
% SL V2X COMMUNICATION Resources Pool Configuration 
sl_OffsetIndicator_r14          = 0;                      % Indicates the offset of the first subframe of a resource pool: {0..10239} 
sl_Subframe_r14                 = [0;0;1;zeros(17,1)];    % Determines PSSCH subframe pool: bitmap with acceptable sizes {16,20,100} 
adjacencyPSCCH_PSSCH_r14        = true;                   % Indicates if PSCCH and PSSCH are adjacent in the frequecy domain {true,false}
sizeSubchannel_r14              = 5;                      % Indicates the number of PRBs of each subchannel in the corresponding resource pool: {n4, n5, n6, n8, n9, n10, n12, n15, n16, n18, n20, n25, n30, n48, n50, n72, n75, n96, n100}
numSubchannel_r14               = 5;                      % Indicates the number of subchannels in the corresponding resource pool: {n1, n3, n5, n10, n15, n20} 
startRB_Subchannel_r14          = 0;                      % Indicates the lowest RB index of the subchannel with the lowest index: {0..99} 
startRB_PSCCH_Pool_r14          = 14;                     % Indicates the lowest RB index of the PSCCH pool. This field is irrelevant if a UE always transmits control and data in adjacent RBs in the same subframe: {0..99} 
% SL V2X COMMUNICATION UE-specific Resource Allocation Configuration
% Common for both modes
sduSize                         = 10;                 % SDU size (coming from MAC)
SFgap                           = 0;                   % Time gap between initial transmission and retransmission. Either set through DCI5A or Higher Layers or Preconfigured.
if slMode == 3 % fully controlled
    Linit                           = 0;                   % 1st transmission opportunity frequency offset: from DCI5A "Lowest index of the subchannel allocation to the initial transmission" --> ceil(log2(numSubchannel_r14) bits, here in integer form. Either set through DCI5A or Higher Layers or Preconfigured.
    nsubCHstart                     = 0;                   % (relevant if SFgap not zero) 2nd transmission opportunity frequency offset: from "Frequency Resource Location of the initial transmission and retransmission" --> ceil(log2(numSubchannel_r14) bits, here in integer form.  This is actually configured using "RIV". Here we provide the corresponding subchannel directly. Either set through DCI5A or Higher Layers or Preconfigured.
elseif slMode == 4 % 2 sub-schemes: random and sensing-based
    % nothing here, autonomous selection of resources
end
% recovery processing
decodingType                    = 'Soft';                % Decoding type for SL-BCH/PSBCH recovery. Pick from 'Soft' or 'Hard' (default : 'Soft')
chanEstMethod                   = 'LS';                  % Channel estimation method. Currently 'LS' and 'mmse-direct' are fully supported (default : 'LS')
timeVarFactor                   = 0;                     % Channel time variance factor. Multiple of 1/(sampling rate). Typical values: 0 for static, 50 for highly time-variant (default : 0)

%% Tx
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
    
%% TX
fprintf('\n\nTx Waveform Processing Starting...\n');

tx_output = v2xcomm_tx( slBaseConfig, slSyncConfig, slV2XCommConfig, slV2XUEconfig );

%% Test Channel (noise, time-offset, freq-offset)
% parameters needed for generating channel samples
switch NSLRB
    case 6,   NFFT = 128;  samples_per_subframe = 1920;
    case 15,  NFFT = 256;  samples_per_subframe = 3840;
    case 25,  NFFT = 512;  samples_per_subframe = 7680;
    case 50,  NFFT = 1024; samples_per_subframe = 15360;
    case 75,  NFFT = 1536; samples_per_subframe = 23040;
    case 100, NFFT = 2048; samples_per_subframe = 30720;
end
            
% Noise
SNR_target_dB = 20; % set SNR
noise = sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1)); % generate noise
rx_input = tx_output + noise; % induce it to the waveform

% Time offset 
% toff = randi([0,2*samples_per_subframe],1,1) % pick a random offset
toff = 0;
rx_input = [zeros(toff,1); rx_input]; % induce it to the waveform

% Freq-offset
foff = 0.01; % set an error (%)
rx_input = rx_input(:).*exp(2i*pi*(0:length(rx_input(:))-1).'*foff/NFFT); % induce it to the waveform

% uncomment for bypassing channel
% rx_input = tx_output;
fprintf('Tx Waveform Passed from Channel...\n');

%% Rx
fprintf('\n\nRx Waveform Processing Starting...\n');

v2xcomm_rx( slBaseConfig, slSyncConfig, slV2XCommConfig, ...
    struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor), ...
    rx_input);
