% Main script for executing a full sidelink v2x communication Tx/Rx scenario
% Contributors: Antonis Gotsis (antonisgotsis), Stelios Stefanatos (steliosstefanatos)
clear all;
clc;
addpath('./core');   % path where core sidelink-specific functionalities are located (V2X communication Channel, DMRS, Sync, Channel Estimator).
addpath('./lib');    % path where generic (non-sidelink specific) tx/rx functionalities are located (signal, physical and transport channel blocks).
warning('off','MATLAB:structOnObject'); % used to supress warning messages in struct(obj) calling

%% Configuration
% common for Tx/Rx: (reflect 36.331 - 6.3.8, sidelink-related IEs)
% SL Basic Operation Parameters: common for communication and broadcast (if present)
NSLRB                           = 25;                      % Sidelink bandwidth configuration in RBs: 6, 15, 25, 50, 100 (default : 25)
NSLID                           = 301;                     % SLSSID: Physical layer sidelink synchronization identity: 0..335 (default 0)
slMode                          = 3;                       % Sidelink Mode: 3 (V2V-scheduled) or 4 (V2V autonomous sensing)
cp_Len_r12                      = 'Normal';                % SL-CP-Len: Cyclic Prefix: 'Normal' or 'Extended'. For V2V only 'Normal' (default : 'Normal')
syncOffsetIndicator             = 0;                       % SL-SyncConfig: Offset indicator for sync subframe with respect to subframe #0: 0..39 (default : 0)
syncPeriod                      = 20;                      % sync subframe period # subframes. Although this is fixed to 40 in the standard, it is allowed to be flexibly configured (default : 40).
% SL V2X COMMUNICATION Resources Pool Configuration 
v2xSLSSconfigured               = true;                    % Enable or disable SLSS transmission {true, false}
sl_OffsetIndicator_r14          = 40;                      % Indicates the offset of the first subframe of a resource pool: {0..10239} 
sl_Subframe_r14                 = repmat([0;1;1;0],5,1);   % Determines PSSCH subframe pool: bitmap with acceptable sizes {16,20,100} 
sizeSubchannel_r14              = 4;                       % Indicates the number of PRBs of each subchannel in the corresponding resource pool: {n4, n5, n6, n8, n9, n10, n12, n15, n16, n18, n20, n25, n30, n48, n50, n72, n75, n96, n100}
numSubchannel_r14               = 3;                       % Indicates the number of subchannels in the corresponding resource pool: {n1, n3, n5, n10, n15, n20} 
startRB_Subchannel_r14          = 2;                       % Indicates the lowest RB index of the subchannel with the lowest index: {0..99} 
adjacencyPSCCH_PSSCH_r14        = true;                    % Indicates if PSCCH and PSSCH are adjacent in the frequecy domain {true,false}
startRB_PSCCH_Pool_r14          = 14;                      % Indicates the lowest RB index of the PSCCH pool. This field is irrelevant if a UE always transmits control and data in adjacent RBs in the same subframe: {0..99} 
networkControlledSyncTx         = 1;                       % RRCConnectionReconfiguration: on-off sync signals  (default: 1)
syncTxPeriodic                  = 1;                       % SL-SyncConfig: single-shot or periodic sync (default: 1)          
% SL V2X COMMUNICATION UE-specific Resource Allocation Configuration
mcs_r14                         = [3; 4];                 % MSC mode set through higher layers or selected autonously by the UE (default: 10): {0..31} (5 bits, here given in integer form)
m_subchannel                    = [0; 0];                  % 1st transmission opportunity frequency offset: Lowest index of the subchannel allocation --> ceil(log2(numSubchannel_r14) bits, here in integer form
nsubCHstart                     = [1; 1];                  % 2nd transmission opportunity frequency offset: Lowest index of the subchannel allocation --> ceil(log2(numSubchannel_r14) bits, here in integer form                                            
LsubCH                          = [2; 1];                  % Number of allocated subchannels for user
SFgap                           = [1; 0];                  % Retransmission time gap
% recovery processing
decodingType                    = 'Soft';                  % Decoding type for transport/physical channel recovery. Pick from 'Soft' or 'Hard' (default : 'Soft')
chanEstMethod                   = 'LS';                    % Channel estimation method. Currently 'LS' and 'mmse-direct' are fully supported (default : 'LS')
timeVarFactor                   = 0;                       % Channel time variance factor. Multiple of 1/(sampling rate). Typical values: 0 for static, 50 for highly time-variant (default : 0)



%% Tx

slBaseConfig = struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode);
slSyncConfig = struct('syncOffsetIndicator', syncOffsetIndicator,'syncPeriod',syncPeriod);
slV2XCommConfig = struct('v2xSLSSconfigured',v2xSLSSconfigured,'sl_OffsetIndicator_r14',sl_OffsetIndicator_r14,'sl_Subframe_r14',sl_Subframe_r14,....
    'sizeSubchannel_r14',sizeSubchannel_r14,'numSubchannel_r14',numSubchannel_r14, 'startRB_Subchannel_r14',startRB_Subchannel_r14,...
    'adjacencyPSCCH_PSSCH_r14',adjacencyPSCCH_PSSCH_r14,'startRB_PSCCH_Pool_r14',startRB_PSCCH_Pool_r14);
slV2XUEconfig = struct('mcs_r14',mcs_r14, 'm_subchannel', m_subchannel, 'nsubCHstart', nsubCHstart, 'LsubCH', LsubCH, 'SFgap', SFgap);

tx_output = communication_tx( slBaseConfig, slSyncConfig, slV2XCommConfig, slV2XUEconfig );


%% Test Channel
SNR_target_dB = 30; % set SNR
noise = sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1)); % generate noise
rx_input = tx_output + noise; % induce it to the waveform

fprintf('Tx Waveform Passed from Channel...\n');

%% Rx
fprintf('\n\nRx Waveform Processing Starting...\n');

communication_rx(slBaseConfig, slSyncConfig, slV2XCommConfig,  ...
    struct(), ...
    struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
    rx_input );


keyboard

