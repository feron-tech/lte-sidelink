function [ output_seq ] = phy_modulate( input_seq, constType )
%PHY_MODULATE creates modulated symbol sequence from input bit sequence
% Inputs:
%   input_seq : input bit sequence
%   constType : 'QPSK', '16QAM', '64QAM'
%#codegen

bpsk_lte = 1/sqrt(2)*[1+1i ; -1-1i];
qpsk_lte = 1/sqrt(2)*[1+1i; 1-1i; -1+1i; -1-1i];
qam16_lte = 1/sqrt(10)*[1+1i; 1+3i; 3+1i; 3+3i; 1-1i; 1-3i; 3-1i; 3-3i; -1+1i; -1+3i; -3+1i; -3+3i; -1-1i; -1-3i; -3-1i; -3-3i;];
qam64_lte = 1/sqrt(42)*[ 3+3i;  3+1i;  1+3i;  1+1i;  3+5i;  3+7i;  1+5i;  1+7i;  5+3i;  5+1i;  7+3i;  7+1i;  5+5i;  5+7i;  7+5i; 7+7i;...
    3-3i;  3-1i;  1-3i;  1-1i;  3-5i;  3-7i;  1-5i;  1-7i;  5-3i;  5-1i;  7-3i;  7-1i;  5-5i;  5-7i;  7-5i;  7-7i;...
    -3+3i; -3+1i; -1+3i; -1+1i; -3+5i; -3+7i; -1+5i; -1+7i; -5+3i; -5+1i; -7+3i; -7+1i; -5+5i; -5+7i; -7+5i; -7+7i;...
    -3-3i; -3-1i; -1-3i; -1-1i; -3-5i; -3-7i; -1-5i; -1-7i; -5-3i; -5-1i; -7-3i; -7-1i; -5-5i; -5-7i; -7-5i; -7-7i];

if isequal(constType,'BPSK')
    mod_rank = 2;
elseif isequal(constType,'QPSK')
    mod_rank = 4;
elseif isequal(constType,'16QAM')
    mod_rank = 16;
elseif isequal(constType,'64QAM')
    mod_rank = 64;
else
    error('Unsupported QAM modulation rank')
end

bits_per_symbol = log2(mod_rank);
number_of_bits = length(input_seq);
data_integers = zeros(number_of_bits/bits_per_symbol, 1);
output_seq = zeros(number_of_bits/bits_per_symbol, 1);

symbol_counter = 1;
for kk = 1 : bits_per_symbol: number_of_bits
    if mod_rank == 2
        data_integers(symbol_counter) = input_seq(kk);
        output_seq(symbol_counter) = bpsk_lte(data_integers(symbol_counter)+1);
    elseif mod_rank == 4
        data_integers(symbol_counter) = input_seq(kk)*2 + input_seq(kk+1);
        output_seq(symbol_counter) = qpsk_lte(data_integers(symbol_counter)+1);
    elseif mod_rank == 16
        data_integers(symbol_counter) = input_seq(kk)*8 + input_seq(kk+1)*4 + input_seq(kk+2)*2 + input_seq(kk+3);
        output_seq(symbol_counter) = qam16_lte(data_integers(symbol_counter)+1);
    elseif mod_rank == 64
        data_integers(symbol_counter) = input_seq(kk)*32 + input_seq(kk+1)*16 + input_seq(kk+2)*8 + input_seq(kk+3)*4 + input_seq(kk+4)*2 + input_seq(kk+5);
        output_seq(symbol_counter) = qam64_lte(data_integers(symbol_counter)+1);
    else
        error('Unsupported QAM modulation rank')
    end
    symbol_counter = symbol_counter + 1;
end

end

