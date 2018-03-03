% Main script for executing a full sidelink broadcast Tx/Rx scenario
% Contributors: Antonis Gotsis (antonisgotsis), Konstantinos Maliatsos (maliatsos), Stelios Stefanatos (steliosstefanatos)
clear all;
clc;
addpath('../../core');   % path where core sidelink-specific functionalities are located (Broadcast Channel, DMRS, Sync, Channel Estimator).
addpath('../../lib');    % path where generic (non-sidelink specific) tx/rx functionalities are located (signal, physical and transport channel blocks).
warning('off','MATLAB:structOnObject'); % used to supress warning messages in struct(obj) calling


%% Configuration
% common for Tx/Rx
cp_Len_r12          = 'Normal';     % Cyclic Prefix: 'Normal' or 'Extended' (default : 0)
NSLRB               = 25;           % Sidelink bandwidth configuration in RBs: 6, 15, 25, 50, 100 (default : 25)
NSLID               = 301;          % Physical layer sidelink synchronization identity: 0..335 (default 0)
slMode              = 1;            % Sidelink Mode: 1, 2, 3 or 4. For SL-BCH 1 is equivalent with 2 and 3 is equivalent with 4. Set 1 or 2 for D2D, 3 or 4 for V2V (default : 1)
syncOffsetIndicator = 0;            % Offset indicator for sync subframe with respect to subframe #0: 0..39 (default : 0)
syncPeriod          = 40;           % sync subframe period # subframes. Although this is fixed to 40 in the standard, it is allowed to be flexibly configured (default : 40).
% needed for Rx only
decodingType        = 'Soft';       % Decoding type for SL-BCH/PSBCH recovery. Pick from 'Soft' or 'Hard' (default : 'Soft')
chanEstMethod       = 'LS';         % Channel estimation method. Currently 'LS' and 'mmse-direct' are fully supported (default : 'LS')
timeVarFactor       = 0;            % Channel time variance factor. Multiple of 1/(sampling rate). Typical values: 0 for static, 50 for highly time-variant (default : 0)
% run-specific
numTotSubframes     = 1024;        % Total number of sidelink subframes to generate starting at #0. Maximum allowed number is 10240.
%% Tx
% use the following for default configuration
% tx_output = broadcast_tx(struct(), struct(), numTotSubframes);

% explicit configuration
tx_output = broadcast_tx(struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode), ...
    struct('syncOffsetIndicator',syncOffsetIndicator,'syncPeriod',syncPeriod), ...
    numTotSubframes);

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
toff = randi([0,samples_per_subframe],1,1); % pick a random offset
rx_input = [zeros(toff,1); rx_input]; % induce it to the waveform

% Freq-offset
foff = 0.01; % set an error (%)
rx_input = rx_input(:).*exp(2i*pi*(0:length(rx_input(:))-1).'*foff/NFFT); % induce it to the waveform

% uncomment for bypassing channel
% rx_input = tx_output;

%% Rx
% use the following for default configuration
% broadcast_rx(struct(), struct(), struct(), rx_input);

% explicit configuration
broadcast_rx(struct('NSLRB',NSLRB,'NSLID',NSLID,'cp_Len_r12',cp_Len_r12, 'slMode',slMode), ...
     struct('syncOffsetIndicator',syncOffsetIndicator,'syncPeriod',syncPeriod),...
     struct('decodingType',decodingType, 'chanEstMethod',chanEstMethod, 'timeVarFactor',timeVarFactor),...
     rx_input);

