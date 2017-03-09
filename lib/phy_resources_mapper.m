function output_grid = phy_resources_mapper(Nsymbs, Nsubs, symbloc, subloc, input_seq)
%phy_resources_mapper maps a sequence to a grid
% Inputs:
%   Nsymbs      : number of SC-FDMA symbols
%   Nsubs       : number of allocated subcarriers
%   symbloc     : sequence location in symbol-domain
%   subloc      : sequence location in subcarrier-domain
%   input_seq   : the sequence to be mapped to a grid

output_grid = complex(zeros(Nsubs,Nsymbs));
% equally split message into the symbols and assign
for symbIX = 1:length(symbloc)
    msg_part = input_seq((symbIX-1)*(length(input_seq)/length(symbloc))+1:symbIX*(length(input_seq)/length(symbloc)),1);
    output_grid(subloc+1, symbloc(symbIX)+1) = msg_part;
end

end