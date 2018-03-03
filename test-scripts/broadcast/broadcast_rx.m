function broadcast_rx(slBroadConfig, slSyncConfig, rxConfig, rx_input)
%broadcast_rx is a high-level function for recovering sidelink broadcast
%channel transmissions given an arbitrary number of (time-domain)
%subframes.
% Inputs:
% 1) slBroadConfig is a struct determining broadcast configuration, including:
%       cp_Len_r12 : 'Normal' or 'Extended', default is 'Normal.
%       NSLRB      : 6, 15, 25, 50, 75, 100, default is 25.
%       NSLID      : 0..335, default is 0.
%       slMode     : 1, 2, 3, 4, default is 1.
% 2) slSyncConfig is a struct determiningh_slBroad_rx synchronization configuration, including:
%       syncOffsetIndicator : 0..39, default is 0
%       syncPeriod          : 1..40, default is 40.
% 3) rxConfig is a struct determining rx processing configiration including:
%       decodingType  : 'Soft' or 'Hard', default is 'Soft'
%       chanEstMethod : 'LS' or 'mmse-direct', default is 'LS'
%       timeVarFactor : 0..100, default is 0.
% Provide empty structs for default settings

% create objects
h_slSync_rx  = SL_Sync(slSyncConfig, slBroadConfig); 
h_slBroad_rx = SL_Broadcast(slBroadConfig, h_slSync_rx.sync_grid);

samples_per_subframe = h_slBroad_rx.samples_per_subframe;

%% Start block-by-block processing
% input subframes (potential, before sync)
N_blocks = floor(length(rx_input)/h_slBroad_rx.samples_per_subframe);

% define counters
counter              = 1;  % block samples counter
symbols_processed    = 0;  % counter used for going back in time (really :-))
subframe_counter     = 0;  % system subframe counter
local_subframe_index = -1; % index for actual subframe timing (recovered from SL-BCH MIB Decoding)

% KPIs
psbch_detections = []; % stores psbch detection results for all attempts: 1 for successful, 0 for misdetection

for block = 0:N_blocks-1 % I/Q block processing, as arriving from digitizer
    
    %fprintf('Currently in block %i/%i\n',block, N_blocks-1)
    %% Update buffers
    if block == 0 % dummy initialization for 1st/2nd block
        %previous_frame = 1/(10^(SNR_target_dB/10)))*complex(randn(samples_per_subframe,1), randn(samples_per_subframe,1));
        previous_frame      = 0.001*complex(randn(samples_per_subframe,1), randn(samples_per_subframe,1));
        post_previous_frame = 0.001*complex(randn(samples_per_subframe,1), randn(samples_per_subframe,1));
    else % normal operation
        % Readjustment if sync point is marginally at the end of the frame:
        [h_slSync_rx, post_previous_frame, previous_frame, counter] = determine_frame_accession(h_slSync_rx, rx_input, previous_frame, samples_per_subframe, counter);
    end
    current_frame = rx_input(counter : counter - 1 + samples_per_subframe);

    %% Check for signal (currently you are blind):
    if h_slSync_rx.rx_status == 0 || h_slSync_rx.rx_status == 1
        h_slSync_rx = detector_synchronizer(previous_frame, current_frame, h_slSync_rx);
        h_slSync_rx.sync_point = h_slSync_rx.sync_point - 2*h_slSync_rx.cpLen0;
        if h_slSync_rx.rx_status == 2
            subframe_counter = h_slSync_rx.syncOffsetIndicator;
            symbols_processed = 1;
        end
    end
    
    %% Have found sync...
    if h_slSync_rx.rx_status >= 2
        
        % update counters=0
        subframe_counter = subframe_counter + 1;
        symbols_processed = symbols_processed + 1;
        % sync & freq-offset estimate
        if mod(subframe_counter,h_slSync_rx.syncPeriod) == h_slSync_rx.syncOffsetIndicator
            h_slSync_rx = synchronizer(h_slSync_rx, previous_frame, current_frame);
            h_slSync_rx = freq_offset_estimate(h_slSync_rx, previous_frame, current_frame);
        end
        if h_slSync_rx.sync_point <= 0 % IN THE OLD VERSION IT WAS <0
            signal = [post_previous_frame(end+h_slSync_rx.sync_point:end); previous_frame; current_frame(1:end+h_slSync_rx.sync_point-1)];
            h_slSync_rx.sync_point = 1;            
        else
            signal = [previous_frame; current_frame];
        end
        
        % compensate freq offset in every subframe based on the estimate
        % from sync subframe 
        if ~isempty(h_slSync_rx.freq_offset)
            [h_slSync_rx, signal] = compensate_freq_offset(signal, h_slSync_rx);
            h_slSync_rx.sample_counter = h_slSync_rx.sample_counter + samples_per_subframe;
        end
        
        % original version: keep all        
        %         h_slSync_rx.synched_blocks = ...
        %             [h_slSync_rx.synched_blocks signal(h_slSync_rx.sync_point-h_slSync_rx.cp_guard:h_slSync_rx.sync_point-h_slSync_rx.cp_guard + samples_per_subframe-1)];

        % new version: keep last 20
        % tstart = tic;
        h_slSync_rx.synched_blocks = ...
            [h_slSync_rx.synched_blocks(:,end-min(size(h_slSync_rx.synched_blocks,2)-1,19):end) signal(h_slSync_rx.sync_point-h_slSync_rx.cp_guard:h_slSync_rx.sync_point-h_slSync_rx.cp_guard + samples_per_subframe-1)];
        % tmp1 = [tmp1; toc(tstart)];
        %         keyboard

        %% sync ok, Broadcast recovery
        for nn = symbols_processed:-1:1            
            % get subframe index
            % current_sf_index = subframe_counter - nn + 1;
            
            % VERSION 1: blindly try to recover BCH at every possible subframe
            % [msgRecoveredFlag, ~, psbch_dseq_rx] = RecoverSubframe (h_slBroad_rx, rxConfig, h_slSync_rx.synched_blocks(:,end-nn+1));
            
            % VERSION 2: initially search blindly and after acquiring timing, search at specfic subframes based on syncPeriod
            if local_subframe_index == -1 % initially recover the input blindly
                [msgRecoveredFlag, h_slBroad_rx]  = RecoverSubframe (h_slBroad_rx,  rxConfig, h_slSync_rx.synched_blocks(:,end-nn+1));
                % check if broadcast info has been acquired
                if msgRecoveredFlag
                    fprintf('System Info Acquired for the first time!\n');
                    % get timing
                    local_subframe_index = h_slBroad_rx.subframe_index;
                    % move to next subframe
                    local_subframe_index = local_subframe_index + 1;
                end
            else % timing acquired --> recover at specific subframes only (since we know the period!)
                if mod(local_subframe_index,h_slSync_rx.syncPeriod) == h_slSync_rx.syncOffsetIndicator
                    %if exist('tstart','var')
                    %    tmp2 = [tmp2; toc(tstart)];
                    %    %keyboard
                    %end
                    fprintf('Trying to decode BCH in the expected subframe (SFN=%i)\n',mod(floor(local_subframe_index/10),1024));
                    psbch_detections = [psbch_detections; 0]; % initialize result
                    [msgRecoveredFlag, h_slBroad_rx]  = RecoverSubframe (h_slBroad_rx,  rxConfig, h_slSync_rx.synched_blocks(:,end-nn+1));
                    psbch_detections(end) = msgRecoveredFlag;
                    %tstart = tic;
                    %keyboard
                end                
                % move to next subframe
                local_subframe_index = local_subframe_index + 1;
           end
        end      % symbols_processed
        symbols_processed = 0;
    end % in status-2 (sync found)    keyboard

    %% Update counters
    counter = counter + samples_per_subframe;
    %h_slSync_rx.memory = [h_slSync_rx.memory current_frame]; % keep all
    h_slSync_rx.memory = [h_slSync_rx.memory(:,end-min(size(h_slSync_rx.memory,2)-1,19):end) current_frame]; % keep last 20
    
end % block processing (as they arrive from digitizer)

fprintf('\nOverall PSBCH Detection Ratio = %.2f (%i/%i successful attempts)\n', mean(psbch_detections), sum(psbch_detections), length(psbch_detections));


end