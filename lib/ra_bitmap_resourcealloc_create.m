function [ra_bitmap, RIV] = ra_bitmap_resourcealloc_create(NRBs, RBstart, Lcrbs)
%Creates resource allocation bitmap for given contiguous resource
%allocation
% inputs: NRBs (total number of resouce blocks); RBstart (Starting RB
% index); Lcrbs (number of number of allocated prbs)
%#codegen

% calc riv
if (Lcrbs-1)<=floor(NRBs/2), RIV = NRBs*(Lcrbs-1)+RBstart;
else, RIV = NRBs*(NRBs - Lcrbs +1) + (NRBs - 1 - RBstart);
end

% calculate ra_bitmap
ra_bitmap =  decTobit(RIV, ceil(log2(NRBs*(NRBs+1)/2)), true); % right-msb

end