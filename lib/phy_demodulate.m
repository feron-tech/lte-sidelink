function [ output_seq ] = phy_demodulate( input_seq, constType )
%PHY_DEMODULATE recovers bit sequence from modulated symbol sequenceInputs:
%   input_seq : input symbol sequence
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
number_of_symbols = length(input_seq);
data_bits = zeros(number_of_symbols*bits_per_symbol, 1);
data_integers = zeros(number_of_symbols, 1);


bit_counter = 1;
for kk = 1 :  number_of_symbols
    
    if mod_rank == 2
        [~, ind] = min(abs(input_seq(kk) - bpsk_lte));
        data_integers(kk) = ind-1;
        data_bits(bit_counter) = data_integers(kk);
    elseif mod_rank == 4
        [~, ind] = min(abs(input_seq(kk) - qpsk_lte));
        data_integers(kk) = ind-1;
        data_bits(bit_counter+1) = mod(data_integers(kk), 2);
        data_bits(bit_counter) = mod(floor(data_integers(kk)/2),2);
    elseif mod_rank == 16
        [~, ind] = min(abs(input_seq(kk) - qam16_lte));
        data_integers(kk) = ind-1;        
        data_bits(bit_counter+3) = mod(data_integers(kk), 2);
        data_bits(bit_counter+2) = mod(floor(data_integers(kk)/2),2);
        data_bits(bit_counter+1) = mod(floor(floor(data_integers(kk)/2)/2),2);
        data_bits(bit_counter)   = mod(floor(floor(floor(data_integers(kk)/2)/2)/2),2);
    elseif mod_rank == 64
        [~, ind] = min(abs(input_seq(kk) - qam64_lte));
        data_integers(kk) = ind-1;
        data_bits(bit_counter+5) = mod(data_integers(kk), 2);
        data_bits(bit_counter+4) = mod(floor(data_integers(kk)/2),2);
        data_bits(bit_counter+3) = mod(floor(floor(data_integers(kk)/2)/2),2);
        data_bits(bit_counter+2) = mod(floor(floor(floor(data_integers(kk)/2)/2)/2),2);
        data_bits(bit_counter+1) = mod(floor(floor(floor(floor(data_integers(kk)/2)/2)/2)/2),2);
        data_bits(bit_counter) =   mod(floor(floor(floor(floor(floor(data_integers(kk)/2)/2)/2)/2)/2),2);
    else
        error('Unsupported QAM modulation rank')
    end
    bit_counter = bit_counter + bits_per_symbol;
end

output_seq = data_bits;

end

