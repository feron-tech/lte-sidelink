function R = auto_correlator(signal, M, lag)

N = length(signal) - (M+lag);

R = zeros(N,1);
R(1) = signal(1+lag:M+lag)'*signal(1:M);
for kk = 2 : N
    R(kk) = R(kk-1) - signal(kk-1)*conj(signal(kk-1+lag)) + signal(kk -1 + M)*conj(signal(kk-1+M+lag));
end
