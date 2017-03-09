function [ output_seq ] = phy_symbolsTosoftbits_qpsk( input_seq )
%SYMBOLSTOSOFTBITS transforms a QPSK symbol sequence to a soft bit sequence
% QPSK constellation (00 --> ++, 01 -->+-, 11-->--, 10-->-+)

soft_bit_seq_vec = zeros(2,length(input_seq));

soft_bit_seq_vec(1,:) = -real(input_seq);
soft_bit_seq_vec(2,:) = -imag(input_seq);

output_seq = reshape(soft_bit_seq_vec,1,2*length(input_seq))';

end

