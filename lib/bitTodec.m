function output = bitTodec(input, MSBfirst)
%bitTodec converts bit sequence to decimal
%   Inputs:
%       input (the bit sequence)
%       MSBfirst (boolean defining the MSB location)

num_bits = length(input);
if isempty(MSBfirst) || MSBfirst==true
    v = (num_bits-1:-1:0);
else
    v = (0:1:num_bits-1);
end
    
output = 2.^v*input;

end

