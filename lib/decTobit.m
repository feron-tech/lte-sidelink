function output = decTobit(input, num_bits, MSBfirst)
%decTobit converts decimal number to bit sequence
%   Inputs:
%       input (the decimal number)
%       num_bits (the length of the bit sequence)

%       MSBfirst (boolean defining the MSB location)
output = zeros(num_bits,1);
if isempty(MSBfirst) || MSBfirst==true
    v = (num_bits-1:-1:0);
else
    v = (0:1:num_bits-1);
end

for jj = v
    output(jj+1,1) = mod(input,2);
    input = floor(input/2);
end
     
end