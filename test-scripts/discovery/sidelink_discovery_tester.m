% Main script for executing a full sidelink discovery Tx/Rx scenario
% Contributors: Antonis Gotsis (antonisgotsis), Konstantinos Maliatsos (maliatsos), Stelios Stefanatos (steliosstefanatos)
clear all;
clc;
addpath('../../core');   % path where core sidelink-specific functionalities are located (Discovery Channel, DMRS, Sync, Channel Estimator).
addpath('../../lib');    % path where generic (non-sidelink specific) tx/rx functionalities are located (signal, physical and transport channel blocks).
warning('off','MATLAB:structOnObject'); % used to supress warning messages in struct(obj) calling

%% Configuration
% common for Tx/Rx: (reflect 36.331 - 6.3.8, sidelink-related IEs)
% SL Basic Operation Parameters: common for discovery and broadcast (if present)
cp_Len_r12          = 'Normal';                 % SL-CP-Len: Cyclic Prefix: 'Normal' or 'Extended' (default : 0)
NSLRB               = 25;                       % Sidelink bandwidth configuration in RBs: 6, 15, 25, 50, 100 (default : 25)
NSLID               = 301;                      % SLSSID: Physical layer sidelink synchronization identity: 0..335 (default 0)
slMode              = 1;                        % Sidelink Mode: 1, 2, 3 or 4. For SL-DCH there is no difference. For SL-BCH 1 is equivalent with 2 and 3 is equivalent with 4. Set 1 or 2 for D2D, 3 or 4 for V2V (default : 1)
syncOffsetIndicator = 0;                        % SL-SyncConfig: Offset indicator for sync subframe with respect to subframe #0: 0..39 (default : 0)
syncPeriod          = 40;                       % sync subframe period # subframes. Although this is fixed to 40 in the standard, it is allowed to be flexibly configured (default : 40).
% SL DISCOVERY Configuration 
discPeriod_r12      = 32;                       % SL-DiscResourcePoool: 32,64,128,256,512,1024 radio frames
offsetIndicator_r12 = 0;                        % SL-OffsetIndicator : 0..10239 (time offset)
subframeBitmap_r12  = repmat([0;1;1;1;0],8,1);  % SL-TF-ResourceConfig: size 40 (subframe resources)
numRepetition_r12   = 5;                        % SL-DiscResourcePoool: 1..5 (subframeBitmap_r12 repetitions)
prb_Start_r12       = 2;                        % SL-TF-ResourceConfig: 0.99
prb_End_r12         = 22;                       % SL-TF-ResourceConfig: 0.99
prb_Num_r12         = 8;                       % SL-TF-ResourceConfig: 1..100             
numRetx_r12         = 2;                        % SL-DiscResourcePool: 0..3 (msg retransmissions)
networkControlledSyncTx = 1;                    % RRCConnectionReconfiguration: on-off sync signals 
syncTxPeriodic          = 1;                    % SL-SyncConfig: single-shot or periodic sync         
discType            = 'Type1';                  % 'Type1','Type2B': resource allocation method
% Tx-Only. For Rx we will define a search space for monitoring messages
if isequal(discType,'Type1')
    % determine dummy UEs resource indices 
    n_PSDCHs        = [0; 6];                 % Scheduling-Based: resource allocation index, determining Time and Freq Resources per Msg
elseif isequal(discType,'Type2B')
    discPRB_Index   = [1; 1];                   % SL-DiscConfig (discTF_IndexList): 1..50
    discSF_Index    = [1; 2];                   % SL-DiscConfig (discTF_IndexList): 1..200
    a_r12           = [1; 1];                   % SL-HoppingConfig : N1_PSDCH: 1..200     
    b_r12           = [1; 1];                   % SL-HoppingConfig : N2_PSDCH: 1..10
    c_r12           = [1; 1];                   % SL-HoppingConfig : N3_PSDCH: n1..n5    
end
% needed for Rx only
% search space for monitoring discovery messages
n_PSDCHs_monitored = n_PSDCHs;
% recovery processing
decodingType        = 'Soft';       % Decoding type for SL-BCH/PSBCH recovery. Pick from 'Soft' or 'Hard' (default : 'Soft')
chanEstMethod       = 'LS';         % Channel estimation method. Currently 'LS' and 'mmse-direct' are fully supported (default : 'LS')
timeVarFactor       = 0;            % Channel time variance factor. Multiple of 1/(sampling rate). Typical values: 0 for static, 50 for highly time-variant (default : 0)

%% Tx
slBaseConfig = struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode);
slSyncConfig = struct('syncOffsetIndicator', syncOffsetIndicator,'syncPeriod',syncPeriod);
slDiscConfig = struct('offsetIndicator_r12', offsetIndicator_r12, 'discPeriod_r12',discPeriod_r12, 'subframeBitmap_r12', subframeBitmap_r12, 'numRepetition_r12', numRepetition_r12, ...
    'prb_Start_r12',prb_Start_r12, 'prb_End_r12', prb_End_r12, 'prb_Num_r12', prb_Num_r12, 'numRetx_r12', numRetx_r12, ...
    'networkControlledSyncTx',networkControlledSyncTx, 'syncTxPeriodic',syncTxPeriodic, 'discType', discType);
slUEconfig = struct('n_PSDCHs',n_PSDCHs); % Type 1
% slUEconfig = struct('discPRB_Index',discPRB_Index, 'discSF_Index', discSF_Index, 'a_r12', a_r12, 'b_r12', b_r12, 'c_r12', c_r12); % Type 2B

% uncomment for default configuration
% tx_output = discovery_tx( struct(), struct(), struct(), struct() )
% explicit configuration
tx_output = discovery_tx( slBaseConfig, slSyncConfig, slDiscConfig, slUEconfig );

fprintf('Tx Waveform Created...\n');

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
SNR_target_dB = 13; % set SNR
noise = sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1)); % generate noise
rx_input = tx_output + noise; % induce it to the waveform

% Time offset 
toff = randi([0,2*samples_per_subframe],1,1) % pick a random offset
rx_input = [zeros(toff,1); rx_input]; % induce it to the waveform

% Freq-offset
foff = 0.01; % set an error (%)
rx_input = rx_input(:).*exp(2i*pi*(0:length(rx_input(:))-1).'*foff/NFFT); % induce it to the waveform

% uncomment for bypassing channel
% rx_input = tx_output;
fprintf('Tx Waveform Passed from Channel...\n');

%% Rx
fprintf('\n\nRx Waveform Processing Starting...\n');

discovery_rx(slBaseConfig, slSyncConfig, slDiscConfig,  ...
    struct('n_PSDCHs',n_PSDCHs_monitored), ...
    struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
    rx_input );

