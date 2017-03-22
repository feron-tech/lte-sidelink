function [prbs, RIV, RBstart_rec, Lcrbs_rec] = ra_bitmap_resourcealloc_recover(rabitmap, NRBs)
%Extracts prb contiguous resource allocation info from resource allocation bitmap
% inputs : rabitmap (the bitmap); NRBs (total number of resouce blocks)
% outputs: prbs (the set of prbs); RIV (the indicator value); RBstart_rec
% (starting rb index); Lcrbs_rec (number of allocated prbs)
%#codegen



% recover RIV
RIV = bitTodec(rabitmap, true);

% we don't know if L - 1 <= floor(NRB/2) so we must
% validate the recovered values
% 1st attempt
RBstart_rec = mod(RIV + NRBs, NRBs);
Lcrbs_rec   = floor((RIV + NRBs)/NRBs);
if RBstart_rec + Lcrbs_rec > NRBs
    % 2nd attempt
    RBstart_rec = mod(NRBs^2 + 2*NRBs - 1 - RIV, NRBs);
    Lcrbs_rec   = floor((NRBs^2 + 2*NRBs - 1 - RIV) /NRBs);
    % validate
    if RBstart_rec + Lcrbs_rec > NRBs
        cprintf('red','Error in RIV demapping\n');
        keyboard;
    end
end
prbs = (RBstart_rec:RBstart_rec+Lcrbs_rec-1)';

end