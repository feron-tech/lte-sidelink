function tx_output = discovery_tx(slBaseConfig, slSyncConfig, slDiscConfig, slUEconfig )
%discovery_tx is a high-level function for creating the sidelink discovery transmit waveform for a single discovery period.
% tx_output = discovery_tx(slBaseConfig, slSyncConfig, slDiscConfig, slUEconfig ) creates the sidelink discovery tx waveform.
% Information about the input fields can be found at the sidelink_discovery_tester example and the SL_Discovery class.
% Provide empty structs for default settings 

% create objects
h_slSync_tx  = SL_Sync(slSyncConfig, slBaseConfig); 
h_slBroad_tx = SL_Broadcast(slBaseConfig, h_slSync_tx.sync_grid);
h_slDisc_tx  = SL_Discovery(slBaseConfig, slSyncConfig, slDiscConfig, slUEconfig);

% define simulation time starting always at subframe #0, based on discPeriod_r12.
numTotSubframes     = 0.25*h_slDisc_tx.discPeriod_r12*10; % for example take a part of the whole discovery period 

% define tx_output for the whole simulation period
tx_output =  0*complex(ones(h_slDisc_tx.samples_per_subframe*numTotSubframes,1),...
    ones(h_slDisc_tx.samples_per_subframe*numTotSubframes,1));

%per-subframe processing
for tested_subframe = 0:numTotSubframes-1
    % initialize signal for current subframe
    tx_output_sf = 0*complex(ones(h_slDisc_tx.samples_per_subframe,1),ones(h_slDisc_tx.samples_per_subframe,1));
    
    % subframe generation
    % Case 1: Reference Subframe
    if ismember(tested_subframe,  h_slDisc_tx.subframes_SLSS)
        fprintf('In REFERENCE subframe %3i\n', tested_subframe);
        tx_output_sf = CreateSubframe (h_slBroad_tx, tested_subframe);
    % Case 2: Discovery Subframe
    elseif ismember(tested_subframe, h_slDisc_tx.l_PSDCH_selected)
        fprintf('In DISCOVERY subframe %3i\n', tested_subframe);
        tx_output_sf = CreateSubframe (h_slDisc_tx, tested_subframe);
        
    end
    
    % total tx waveform loading: broadcast or discovery or nothing
    tx_output(tested_subframe*h_slDisc_tx.samples_per_subframe+1:(tested_subframe+1)*h_slDisc_tx.samples_per_subframe,1) = tx_output_sf;
end % all subframes
 
end % function
