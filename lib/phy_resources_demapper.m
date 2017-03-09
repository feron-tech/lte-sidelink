function extracted_seq = phy_resources_demapper(symbloc, subloc, input_grid)
%phy_resources_demapper extracts sequence from grid
% Inputs:
%   symbloc     : sequence location in symbol-domain
%   subloc      : sequence location in subcarrier-domain
%   input_grid  : the grid from which the sequence is extracted

seq_len = length(symbloc)*length(subloc);
extracted_seq = complex(zeros(seq_len,1));

% get symbol-by-symbol
for symbIX = 1:length(symbloc)
    extracted_seq((symbIX-1)*(seq_len/length(symbloc))+1:symbIX*(seq_len/length(symbloc)),1) = input_grid(subloc+1, symbloc(symbIX)+1);
end

end