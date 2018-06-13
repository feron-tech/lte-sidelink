function tx_output = v2xcomm_tx( slBaseConfig, slSyncConfig, slV2XCommConfig, slV2XUEconfig )
%discovery_tx is a high-level function for creating the sidelink v2x comm
%transmit waveform.

%% Create Objects
h_slSync_tx     = SL_Sync(slSyncConfig, slBaseConfig); 
h_slBroad_tx    = SL_Broadcast(slBaseConfig, h_slSync_tx.sync_grid);
h_slV2XComm_tx  = SL_V2XCommunication(slBaseConfig, slSyncConfig, slV2XCommConfig);
h_slV2XComm_tx  = GetV2XCommResourcePool(h_slV2XComm_tx);

numTotSubframes = 160;
Ncycles = 1;

%%
% ==============================================
% arbitrary subframe index of packet arrival
data_arrived_subframe = 7;
% ==============================================

%%
nsamples = h_slV2XComm_tx.samples_per_subframe;
% define tx_output for the whole simulation period
tx_output =  0*complex(ones(Ncycles*nsamples*numTotSubframes,1), ones(Ncycles*nsamples*numTotSubframes,1));

%per-subframe processing
for cycleIx=0:Ncycles-1
for tested_subframe = 0:numTotSubframes-1
    % initialize signal for current subframe
    tx_output_sf = 0*complex(ones(nsamples,1),ones(nsamples,1));
    
    %% RESOURCE ALLOCATION & CONFIGURATION upon packet arrival
    if tested_subframe==data_arrived_subframe        
        % variable indicating next active subframe. this is updated on the fly        
        if data_arrived_subframe <= max(h_slV2XComm_tx.ls_PSCCH_RP)
            pool_subframe_ix = find(h_slV2XComm_tx.ls_PSSCH_RP>=data_arrived_subframe,1,'first');
        else % handle a special case where a packet arrives after last subframe of resource pool
            pool_subframe_ix = 1;
        end
        % procedures and control message generation
        [h_slV2XComm_tx] = PSxCH_Procedures(h_slV2XComm_tx, slV2XUEconfig, h_slV2XComm_tx.ls_PSSCH_RP(pool_subframe_ix));
    end
    
    %% subframe generation
    % Case 1: Reference Subframe
    if ismember(tested_subframe,  h_slV2XComm_tx.subframes_SLSS)
        fprintf('[## Tx ##] In REFERENCE subframe %3i\n', tested_subframe);
        tx_output_sf = CreateSubframe (h_slBroad_tx, tested_subframe);
    % Case 2: V2X Communication Subframe
    elseif ismember(tested_subframe, h_slV2XComm_tx.l_PSSCH_selected)   
        % ============ current subframe ====================
        fprintf('[## Tx ##] In V2X-COMM subframe %3i\n', tested_subframe);
        % generation of data message (in reality data is already there)
        slschTBs = randi([0,1], h_slV2XComm_tx.pssch_TBsize , 1);
        fprintf(' SL-SCH TB random message %x (hex format) generated\n', bitTodec(slschTBs(1:50),true));
        % create full signal and update for sps
        [tx_output_sf, h_slV2XComm_tx] = CreateSubframe (h_slV2XComm_tx, tested_subframe, slschTBs);
        fprintf(' Energy = %.3f\n', mean(abs(tx_output_sf(:).^2)));        
    end % type of subframe
    
    %%
    % total tx waveform loading: broadcast or comm or nothing
    tx_output(cycleIx*numTotSubframes*nsamples+tested_subframe*nsamples+1:cycleIx*numTotSubframes*nsamples+(tested_subframe+1)*nsamples,1) = tx_output_sf;
end
end
