function subs = prbsTosubs(prbs, NRBsc)
%#codegen
%prbsTosubs calculates 0-based subcarrier indexes for given PRB indices

subs = -ones(length(prbs)*NRBsc,1); %0-indexing
for prbIX = 1:length(prbs)
    subs((prbIX-1)*NRBsc+1:prbIX*NRBsc,1) = prbs(prbIX)*NRBsc:(prbs(prbIX)+1)*NRBsc-1;
end

end