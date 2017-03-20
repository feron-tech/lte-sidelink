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
