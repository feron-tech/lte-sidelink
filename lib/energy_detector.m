function R = energy_detector(signal, M, lag)

N = length(signal) - M - lag + 1;

R = zeros(N,1);
for kk = 1 : N
    R(kk) = sum(abs(signal(kk+lag:kk-1+lag+M)).^2);
end