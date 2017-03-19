% Main script for executing a full sidelink communication Tx/Rx scenario
% Contributors: Antonis Gotsis (antonisgotsis), Konstantinos Maliatsos (maliatsos), Stelios Stefanatos (steliosstefanatos)
clear all;
clc;
addpath('./core');   % path where core sidelink-specific functionalities are located (Discovery Channel, DMRS, Sync, Channel Estimator).
addpath('./lib');    % path where generic (non-sidelink specific) tx/rx functionalities are located (signal, physical and transport channel blocks).
warning('off','MATLAB:structOnObject'); % used to supress warning messages in struct(obj) calling

%% Configuration
% common for Tx/Rx: (reflect 36.331 - 6.3.8, sidelink-related IEs)
% SL Basic Operation Parameters: common for communication and broadcast (if present)
cp_Len_r12              = 'Normal';                     % SL-CP-Len: Cyclic Prefix: 'Normal' or 'Extended'. For V2V only 'Normal' (default : 'Normal')
NSLRB                   = 25;                           % Sidelink bandwidth configuration in RBs: 6, 15, 25, 50, 100 (default : 25)
NSLID                   = 301;                          % SLSSID: Physical layer sidelink synchronization identity: 0..335 (default 0)
slMode                  = 1;                            % Sidelink Mode: 1 (D2D scheduled), 2 (D2D UE-selected), 3 (V2V-scheduled) or 4 (V2V autonomous sensing)
syncOffsetIndicator     = 0;                            % SL-SyncConfig: Offset indicator for sync subframe with respect to subframe #0: 0..39 (default : 0)
syncPeriod              = 40;                           % sync subframe period # subframes. Although this is fixed to 40 in the standard, it is allowed to be flexibly configured (default : 40).
% SL COMMUNICATION Resources Pool Configuration 
scPeriod_r12            = 160;                          % 40,80,160,320 subframes: SL Communication period (SL-CommResourcePool) (default: 320)
offsetIndicator_r12     = 40;                           % 0..319: SL Communication Subframe Pool offset with respect to SFN #0 (SL-TF-ResourceConfig) (default: 0)
subframeBitmap_r12      = repmat([0;1;1;0],10,1);       % size 40: SL Communication Subframe Pool Bitmap(SL-TF-ResourceConfig) (default: [0; ones(39,1)]; 
prb_Start_r12           = 2;                            % 0..99  : Starting PRB index allocated to Discovery transmissions (default: 2)
prb_End_r12             = 22;                           % 0..99  : Ending PRB index allocated to Discovery transmissions (default: 22)
prb_Num_r12             = 10;                           % 1..100 : Number of PRBs allocated to each Discovery transmissions block.  Total num of PRBs is 2*prb_Num_r12 (default: 10).
networkControlledSyncTx = 1;                            % RRCConnectionReconfiguration: on-off sync signals  (default: 1)
syncTxPeriodic          = 1;                            % SL-SyncConfig: single-shot or periodic sync (default: 1)          
% SL COMMUNICATION UE-specific resource allocation (each row corresponds to a single UE transmission configuration)
% the following fields are either set through eNB L1 DL signaling (DCI-5)
% or selected autonomously by the UE (for rx these are empty and read-out
% through SCI)
mcs_r12                 = [9; 10];                      % 0..28 (5 bits, here given in integer form): Set through higher layers or selected autonously by the UE (default: 10)
nPSCCH                  = [0; 30];                      % 6 bits (here in integer format: 0..63) --> Resource for PSCCH : Used to determine subframes and RBs used for PSCCH (36.213/14.2.1.1/2)
HoppingFlag             = [0; 0];                       % 1 bit  (0 or 1). Currently non-hopping resource allocation is fully supported 
RBstart                 = [prb_Start_r12; ...           % Starting RB index for non-hopping type 0 resource allocation
    (prb_End_r12-prb_Num_r12+1)'];          
Lcrbs                   = [prb_Num_r12; prb_Num_r12];   % Length of contiguously allocated RBs (>=1) for non-hopping type 0 resource allocation
ITRP                    = [0; 1];                       % 7 bits for FDD (here in integer format: 0..127): Used to determine the subframe indicator map for PSSCH
nSAID                   = [101; 101];                   % 0..255 (8 bits): Group Destination ID set in higher-layers
% needed for Rx only
% search space for monitoring discovery messages
% n_PSDCHs_monitored = n_PSDCHs;
% recovery processing
decodingType        = 'Soft';                           % Decoding type for transport/physical channel recovery. Pick from 'Soft' or 'Hard' (default : 'Soft')
chanEstMethod       = 'LS';                             % Channel estimation method. Currently 'LS' and 'mmse-direct' are fully supported (default : 'LS')
timeVarFactor       = 0;                                % Channel time variance factor. Multiple of 1/(sampling rate). Typical values: 0 for static, 50 for highly time-variant (default : 0)

%% Tx
slBaseConfig = struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode);
slSyncConfig = struct('syncOffsetIndicator', syncOffsetIndicator,'syncPeriod',syncPeriod);
slCommConfig = struct('scPeriod_r12',scPeriod_r12,'offsetIndicator_r12',offsetIndicator_r12, 'subframeBitmap_r12',subframeBitmap_r12,...
    'prb_Start_r12',prb_Start_r12, 'prb_End_r12', prb_End_r12, 'prb_Num_r12', prb_Num_r12,...
    'networkControlledSyncTx',networkControlledSyncTx, 'syncTxPeriodic',syncTxPeriodic );
slUEconfig   = struct('nPSCCH', nPSCCH, 'HoppingFlag', HoppingFlag, 'ITRP', ITRP, 'RBstart', RBstart, 'Lcrbs', Lcrbs, 'mcs_r12', mcs_r12, 'nSAID',nSAID);

% explicit configuration
% slBaseConfig = struct(); slSyncConfig = struct();slCommConfig = struct();

% slUEconfig =  struct('nPSCCH', nPSCCH);
tx_output = communication_tx( slBaseConfig, slSyncConfig, slCommConfig, slUEconfig);

fprintf('Tx Waveform Created...\n');

%% Test Channel
SNR_target_dB = 30; % set SNR
noise = sqrt((1/2)*10^(-SNR_target_dB/10))*complex(randn(length(tx_output),1), randn(length(tx_output),1)); % generate noise
rx_input = tx_output + noise; % induce it to the waveform

fprintf('Tx Waveform Passed from Channel...\n');

%% Rx
fprintf('\n\nRx Waveform Processing Starting...\n');

communication_rx(slBaseConfig, slSyncConfig, slCommConfig,  ...
    struct('nPSCCH', [0:1:30]' ), ...
    struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
    rx_input );


%% Tx function
function tx_output = communication_tx(slBaseConfig, slSyncConfig, slCommConfig, slUEconfig)
%communication_tx is a high-level function for creating the sidelink communication transmit waveform for a single communication period.
% tx_output = communication_tx(slBaseConfig, slSyncConfig, slCommConfig, slUEconfig, 'Tx' ) creates the sidelink communication tx waveform.
% Information about the input fields can be found at the sidelink_communication_tester example and the SL_Communication class.
% Provide empty structs for default settings 

% create objects
h_slSync_tx  = SL_Sync(slSyncConfig, slBaseConfig); 
h_slBroad_tx = SL_Broadcast(slBaseConfig, h_slSync_tx.sync_grid);
h_slComm_tx  = SL_Communication(slBaseConfig, slSyncConfig, slCommConfig, slUEconfig, 'Tx');

% define simulation time starting always at subframe #0, based on scPeriod_r12.
numTotSubframes     = 1*h_slComm_tx.scPeriod_r12; % for example take a part of the whole comm period 

% define tx_output for the whole simulation period
tx_output =  0*complex(ones(h_slComm_tx.samples_per_subframe*numTotSubframes,1),...
    ones(h_slComm_tx.samples_per_subframe*numTotSubframes,1));

for tested_subframe = 0:h_slComm_tx.CommPer(2)
    %fprintf('\nIn subframe % i\n',tested_subframe);
    
    % initialize signal for current subframe
    tx_output_sf = 0*complex(ones(h_slComm_tx.samples_per_subframe,1),ones(h_slComm_tx.samples_per_subframe,1));
    
    % Reference Subframe
    if ismember(tested_subframe,  h_slComm_tx.subframes_SLSS)
        fprintf('In REFERENCE subframe %3i\n', tested_subframe);
        tx_output_sf = CreateSubframe (h_slBroad_tx, tested_subframe);        
    % Communications Subframe (check for pscch/pssch performed inside the function)
    else
        tx_output_sf = CreateSubframe (h_slComm_tx , tested_subframe);
    end
    
    % total tx waveform loading: broadcast or discovery or nothing
    tx_output(tested_subframe*h_slComm_tx.samples_per_subframe+1:(tested_subframe+1)*h_slComm_tx.samples_per_subframe,1) = tx_output_sf;
end % all subframes

end

%% Rx function
function communication_rx(slBaseConfig, slSyncConfig, slDiscConfig, slUEConfig, rxConfig, rx_input)
%communication_rx is a high-level function for recovering sidelink communcation channel transmissions given a waveform corrsponding to a single communication period.
% Time-offset/Freq-offset impairments are not considered (so there is no
% need for synchronization, freq-offset estimation/compensation etc.)
% Information about the input fields can be found at the sidelink_communication_tester example and the SL_Communication class.
% Provide empty structs for default settings 

% create objects
h_slSync_rx  = SL_Sync(slSyncConfig, slBaseConfig); 
h_slBroad_rx = SL_Broadcast(slBaseConfig, h_slSync_rx.sync_grid);
h_slComm_rx  = SL_Communication(slBaseConfig, slSyncConfig, slDiscConfig, slUEConfig,'Rx');

%% searching for PSCCH  based on a defined nPSCCH space
fprintf('\n -- Searching for SCI0 messages in the whole input waveform --\n');
h_slComm_rx = SCI0_Search_Recover(h_slComm_rx, rxConfig, rx_input);

%% decode data in resources designated by SCI-0 recovered messages
fprintf('\n -- Recovering data from the input waveform based on recovered SCI0s --\n');
Data_Recover (h_slComm_rx, rxConfig, rx_input);

%% decode broadcast
fprintf('\n --Detecting broadcast information in the whole input waveform --\n');

for subframe_counter = 0:h_slComm_rx.CommPer(2)
    if ismember(subframe_counter,  h_slComm_rx.subframes_SLSS)
        RecoverSubframe (h_slBroad_rx,  rxConfig, ...
            rx_input(subframe_counter*h_slBroad_rx.samples_per_subframe+1:(subframe_counter+1)*h_slBroad_rx.samples_per_subframe)); 
    end
end


end
