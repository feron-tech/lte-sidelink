function tx_output = broadcast_tx(slBroadConfig, slSyncConfig, numTotSubframes)
%broadcast_tx is a high-level function for creating the sidelink broadcast transmit waveform for a full frame cycle (1024 frames)
% tx_output = broadcast_tx(slBroadConfig, slSyncConfig) creates the sidelink broadcast tx waveform
% Inputs:
% 1) slBroadConfig is a struct determining broadcast configuration, including:
%       cp_Len_r12 : 'Normal' or 'Extended', default is 'Normal.
%       NSLRB      : 6, 15, 25, 50, 75, 100, default is 25.
%       NSLID      : 0..335, default is 0.
%       slMode     : 1, 2, 3, 4, default is 1.
% 2) slSyncConfig is a struct determiningh_slBroad_rx synchronization configuration, including:
%       syncOffsetIndicator : 0..39, default is 0
%       syncPeriod          : 1..40, default is 40.
% 3) numTotSubframes : number of simulated subframes (up to 10240)
% Provide empty structs for default settings

assert(numTotSubframes>=0 || numTotSubframes<=10240,'Invalid Number of Subframes. Pick from 0..10240');

% create objects
h_slSync_tx  = SL_Sync(slSyncConfig, slBroadConfig); 
h_slBroad_tx = SL_Broadcast(slBroadConfig, h_slSync_tx.sync_grid);

% define tx_output for the whole simulation period
tx_output =  0*complex(ones(h_slBroad_tx.samples_per_subframe*numTotSubframes,1),...
    ones(h_slBroad_tx.samples_per_subframe*numTotSubframes,1));

%per-subframe processing
for tested_subframe = 0:numTotSubframes-1
    % initialize signal
    tx_output_sf = 0*complex(ones(h_slBroad_tx.samples_per_subframe,1),ones(h_slBroad_tx.samples_per_subframe,1));
    
    % check if this is a broadcast subframe and load it
    if mod(tested_subframe,h_slSync_tx.syncPeriod) == h_slSync_tx.syncOffsetIndicator
         tx_output_sf  = CreateSubframe (h_slBroad_tx, tested_subframe);
    end
    % total tx waveform loading
    tx_output(tested_subframe*h_slBroad_tx.samples_per_subframe+1:(tested_subframe+1)*h_slBroad_tx.samples_per_subframe,1) = tx_output_sf;
end

end
