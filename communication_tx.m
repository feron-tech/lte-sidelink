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
