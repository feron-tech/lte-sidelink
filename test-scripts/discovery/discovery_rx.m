function discovery_rx(slBaseConfig, slSyncConfig, slDiscConfig, slUEConfig, rxConfig, rx_input )
%discovery_rx is a high-level function for recovering sidelink discovery channel transmissions given an arbitrary number of (time-domain) subframes.
% Information about the input fields can be found at the sidelink_discovery_tester example and the SL_Discovery class.
% Provide empty structs for default settings 

% create objects
h_slSync_rx  = SL_Sync(slSyncConfig, slBaseConfig); 
h_slBroad_rx = SL_Broadcast(slBaseConfig, h_slSync_rx.sync_grid);
h_slDisc_rx  = SL_Discovery(slBaseConfig, slSyncConfig, slDiscConfig, slUEConfig);

samples_per_subframe = h_slBroad_rx.samples_per_subframe;

%% Start block-by-block processing
% input subframes (potential, before sync)
N_blocks = floor(length(rx_input)/h_slBroad_rx.samples_per_subframe)

% define counters
counter              = 1;  % block samples counter
symbols_processed    = 0;  % counter used for going back in time (really :-))
subframe_counter     = 0;  % system subframe counter
local_subframe_index = -1; % index for actual subframe timing (recovered from SL-BCH MIB Decoding)

% KPIs
psbch_detections = []; % stores psbch detection results for all attempts: 1 for successful, 0 for misdetection
discovered_msgs_recovered = [];

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
        
        % update counters
        subframe_counter = subframe_counter + 1;
        symbols_processed = symbols_processed + 1;
        % sync & freq-offset estimate
        if mod(subframe_counter,h_slSync_rx.syncPeriod) == h_slSync_rx.syncOffsetIndicator
            h_slSync_rx = synchronizer(h_slSync_rx, previous_frame, current_frame);
            h_slSync_rx = freq_offset_estimate(h_slSync_rx, previous_frame, current_frame);
        end
        if h_slSync_rx.sync_point <= 0
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
            
            % initially search blindly and after acquiring timing, search at specfic subframes based on syncPeriod
            if local_subframe_index == -1 % initially recover the input blindly
                [msgRecoveredFlag, h_slBroad_rx]  = RecoverSubframe (h_slBroad_rx,  rxConfig, h_slSync_rx.synched_blocks(:,end-nn+1));
                % check if broadcast info has been acquired
                if msgRecoveredFlag
                    fprintf('System Info Acquired for the first time!\n');
                    % get timing
                    local_subframe_index = h_slBroad_rx.subframe_index;
                    % move to next subframe
                    local_subframe_index = local_subframe_index + 1;
                    if local_subframe_index == 10240, local_subframe_index = 0; end
                end
            else % timing acquired --> we now know actual subframe timing!
               
                % time-domain signal
                input_signal = h_slSync_rx.synched_blocks(:,end-nn+1);
                
                % Case 1: Broadcast Subframe
                if ismember(local_subframe_index,  h_slDisc_rx.subframes_SLSS)
                    fprintf('Trying to decode BCH in the expected subframe (%i)\n', local_subframe_index);
                    psbch_detections = [psbch_detections; 0]; % initialize result
                    [msgRecoveredFlag, h_slBroad_rx]  = RecoverSubframe (h_slBroad_rx,  rxConfig, input_signal);
                     % resync subframe counter according to latest bch decoding
                    local_subframe_index = h_slBroad_rx.subframe_index;
                    psbch_detections(end) = msgRecoveredFlag;
                % Case 2: Discovery Subframe
                elseif ismember(local_subframe_index, h_slDisc_rx.l_PSDCH_selected)
                    fprintf('Monitoring DCH in the expected subframe (%i)\n', local_subframe_index);
                    discovered_msgs_current = DiscoveryMonitoring(h_slDisc_rx, input_signal, local_subframe_index, rxConfig);
                    % keep all messages                    
                    discovered_msgs_recovered = [discovered_msgs_recovered; discovered_msgs_current];
                end
                % move to next subframe
                local_subframe_index = local_subframe_index + 1;
                if local_subframe_index == 10240, local_subframe_index = 0; end
           end
        end      % symbols_processed
        symbols_processed = 0;
    end % in status-2 (sync found)

    %% Update counters
    counter = counter + samples_per_subframe;
    %h_slSync_rx.memory = [h_slSync_rx.memory current_frame]; % keep all
    h_slSync_rx.memory = [h_slSync_rx.memory(:,end-min(size(h_slSync_rx.memory,2)-1,19):end) current_frame]; % keep last 20
    
end % block processing (as they arrive from digitizer)

fprintf('\nOverall PSBCH Detection Ratio = %.2f (%i/%i successful attempts)\n', mean(psbch_detections), sum(psbch_detections), length(psbch_detections));

% analyze recovered discovery messages
fprintf('\nOverall Recovered Discovery Messages\n');

for ix = 1:length(discovered_msgs_recovered)
fprintf('\t[At Subframe %5i: Found nPSDCH = %3i]\n', ...
    discovered_msgs_recovered(ix).subframe_counter, discovered_msgs_recovered(ix).nPSDCH);
end

