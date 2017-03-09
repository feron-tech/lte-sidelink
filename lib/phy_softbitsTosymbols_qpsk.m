function [ output_seq ] = phy_softbitsTosymbols_qpsk( input_seq )
%phy_softbitsTosymbols_qpsk transforms soft bits to symbols for QPSK
output_seq = -(input_seq(1:2:end) + 1i*input_seq(2:2:end));

end