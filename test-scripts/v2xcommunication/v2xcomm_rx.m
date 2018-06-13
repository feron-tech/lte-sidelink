function v2xcomm_rx( slBaseConfig, slSyncConfig, slV2XCommConfig, rxConfig, rx_input)


%% Create Objects
h_slSync_rx     = SL_Sync(slSyncConfig, slBaseConfig); 
h_slBroad_rx    = SL_Broadcast(slBaseConfig, h_slSync_rx.sync_grid);
h_slV2XComm_rx  = SL_V2XCommunication(slBaseConfig, slSyncConfig, slV2XCommConfig);
h_slV2XComm_rx  = GetV2XCommResourcePool(h_slV2XComm_rx);


%% Start block-by-block processing
samples_per_subframe = h_slBroad_rx.samples_per_subframe;

% input subframes (potential, before sync)
N_blocks = floor(length(rx_input)/h_slBroad_rx.samples_per_subframe)

% define counters
counter              = 1;  % block samples counter
symbols_processed    = 0;  % counter used for going back in time (really :-))
subframe_counter     = 0;  % system subframe counter
local_subframe_index = -1; % index for actual subframe timing (recovered from SL-BCH MIB Decoding)

for block = 0:N_blocks-1 % I/Q block processing, as arriving from digitizer
    
    %fprintf('Currently in block %i/%i\n',block, N_blocks-1)
    %% Update buffers
    if block == 0 % dummy initialization for 1st/2nd block
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
        h_slSync_rx.synched_blocks = ...
            [h_slSync_rx.synched_blocks(:,end-min(size(h_slSync_rx.synched_blocks,2)-1,20-1):end) signal(h_slSync_rx.sync_point-h_slSync_rx.cp_guard:h_slSync_rx.sync_point-h_slSync_rx.cp_guard + samples_per_subframe-1)];
        
        %% sync ok, Data recovery
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
                    local_subframe_index = mod(local_subframe_index + 1,10240);
                end
            else % timing acquired --> we now know actual subframe timing!
               
                % time-domain signal
                input_signal = h_slSync_rx.synched_blocks(:,end-nn+1);
                
                % Case 1: Broadcast Subframe
                if ismember(local_subframe_index,  h_slV2XComm_rx.subframes_SLSS)
                    fprintf('Trying to decode BCH in the expected subframe (%i), Energy=%.4f\n', local_subframe_index, mean(abs(input_signal).^2));
                    [msgRecoveredFlag, h_slBroad_rx]  = RecoverSubframe (h_slBroad_rx,  rxConfig, input_signal);
                     % resync subframe counter according to latest bch decoding
                    local_subframe_index = h_slBroad_rx.subframe_index;
                % Case 2: (Potential) V2X Comm Subframe
                elseif ismember(local_subframe_index,  h_slV2XComm_rx.ls_PSCCH_RP)
                    fprintf('Trying to decode PSCCH in the expected subframe (%i). Energy=%.4f\n', local_subframe_index, mean(abs(input_signal).^2));
                    h_slV2XComm_rx = RecoverV2XCommSubframe(h_slV2XComm_rx, input_signal, local_subframe_index, rxConfig);                    
                end
                % move to next subframe
                local_subframe_index = mod(local_subframe_index + 1,10240);
           end
        end      % symbols_processed
        symbols_processed = 0;
    end % in status-2 (sync found)

    %% Update counters
    counter = counter + samples_per_subframe;
    %h_slSync_rx.memory = [h_slSync_rx.memory current_frame]; % keep all
    h_slSync_rx.memory = [h_slSync_rx.memory(:,end-min(size(h_slSync_rx.memory,2)-1,19):end) current_frame]; % keep last 20
    
end % block processing (as they arrive from digitizer)

end
