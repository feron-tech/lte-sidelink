function R = cross_correlator(signal, sequence)

M =  length(sequence);
N = length(signal) -M + 1;
R = zeros(N,1);

for kk = 1 : N
    R(kk) = signal(kk:kk-1+M)'*sequence;
end