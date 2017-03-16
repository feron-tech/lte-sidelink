function [output_seq] = phy_equalizer(ce_params, dmrs_seq, l_data, subIXs, input_grid)
%phy_equalizer implements sidelink/uplink equalization based on the
%following inputs:
% ce_params : struct containing channel estimation configuration including DMRS symbol positions, number of frequency resources, etc.
% dmrs_seq  : the ideal DMRS sequence
% l_data    : symbol      positions carrying DATA within subframe (these symbols are equalized)
% subIXs    : subcarriers positions carrying DATA within subframe (these symbols are equalized)
% input_grid: the received (pre-equalized) complete grid
% Contributors: Antonis Gotsis (antonisgotsis), Stelios Stefanatos (steliosstefanatos)


% create channel object at first subframe call
% persistent chan_est_obj;
% if isempty(chan_est_obj)
chan_est_obj = SL_ChannelEstimator(ce_params);
% end

% extract DMRS symbol sequence from grid to perform channel estimation
l_dmrs = ce_params.l_DMRS; % the symbol positions carrying the pilots (e.g for d2d 3, 10)
drms_seq_Rx = phy_resources_demapper(l_dmrs, subIXs, input_grid); % get the sequence (e.g. for broadcast: 144x1 [2 symbols of 72 subs vectorized)

% construct inputs for channel estimation: the ideal and the actual values (e.g. for broadcast 72x2)
dmrs_obs_mat = -ones(length(drms_seq_Rx)/length(l_dmrs),length(l_dmrs));
dmrs_ideal_mat = -ones(size(dmrs_obs_mat));
for lix = 1:size(dmrs_obs_mat,2)
    dmrs_obs_mat(:,lix) = drms_seq_Rx((lix-1)*size(dmrs_obs_mat,1)+1:lix*size(dmrs_obs_mat,1));
    dmrs_ideal_mat(:,lix) = dmrs_seq((lix-1)*size(dmrs_ideal_mat,1)+1:lix*size(dmrs_ideal_mat,1));
end

% perform channel estimation based on ideal and actual sequences and get chan-est grid
[hf_est_grid_used, var_n_est] = chan_est_obj.chan_estimate(dmrs_obs_mat,dmrs_ideal_mat);
hf_est_grid = zeros(size(input_grid));
hf_est_grid(subIXs+1,:) = hf_est_grid_used;

% extract received PSDCH and h_est symbol sequences from grid
r_obs = phy_resources_demapper( l_data, subIXs, input_grid  );
h_est = phy_resources_demapper( l_data, subIXs, hf_est_grid );

% LMMSE channel equalization
output_seq = (conj(h_est).*r_obs)./(abs(h_est).^2 + var_n_est);

end