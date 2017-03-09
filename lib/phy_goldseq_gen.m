function output_bitseq = phy_goldseq_gen (Mpn, c_init)
%phy_goldseq_gen creates the pseudo-random sequence generation according to
%3GPP 36.211, 7.2.
% Inputs: 
%   Mpn (the size of the target sequence)
%   c_init (the 2nd m-seq initialization given in integer number)
%#codegen

output_bitseq = zeros(Mpn,1);

Nc = 1600; % shift
x1 = [1; zeros(30,1); zeros(Mpn,1); zeros(Nc,1)];
x2 = [decTobit(c_init, 31, false); zeros(Mpn,1); zeros(Nc,1)]; 

for n = 0 : 31 + Mpn + Nc -1
   x1(n+1+31,1) = mod(x1(n+1+3)+x1(n+1),2);
   x2(n+1+31,1) = mod(x2(n+1+3)+x2(n+1+2)+x2(n+1+1)+x2(n+1),2);    
end

for n = 0 : Mpn -1
   output_bitseq(n+1,1) = mod(x1(n+1+Nc)+x2(n+1+Nc),2);
end

end