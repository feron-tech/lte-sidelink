function Output_signal = phy_ofdm_demodulate_per_subframe(conf, input_signal)
%phy_ofdm_demodulate_per_subframe creates frequency-domain signal
%(time-frequency grid) given a time-domain waveform (36.211, 9.9).
% Inputs: 
%   conf: struct containing the following phy configuration related
%   fields: NSLsymb, NFFT, cpLen0, cpLenR, NRBsc
%   input_signal : time-frequency grid

Output_signal_fulllen = zeros(conf.NFFT, 2*conf.NSLsymb);
Output_signal = zeros(conf.NSLRB*conf.NRBsc, 2*conf.NSLsymb);

counter = 1;
for ll = 1 :2*conf.NSLsymb
    if ll == 1 || ll == conf.NSLsymb + 1
        cp = conf.cpLen0;
    else
        cp = conf.cpLenR;
    end
    
    Tmp = input_signal(counter: counter-1+conf.NFFT+cp);
    % Shift by half subcarrier
    Tmp = Tmp.*exp(-2i*pi*(-cp:conf.NFFT-1)'/conf.NFFT/2);
    % Remove CP:
    Tmp = Tmp(cp+1:end);
    % FFT
    tmp = fftshift(fft(Tmp));    
    % ------------------------------------------------
    % added by antonis (check with kostas)
    % Normalize power:
    tmp = (1/(conf.NFFT/sqrt(conf.NSLRB*conf.NRBsc)))*tmp;
    % ------------------------------------------------
    Output_signal_fulllen(:, ll) = tmp;
    counter = counter+conf.NFFT+cp;    
    
    % keep useful subcarriers (NRBsc*NSLRB length)
    Output_signal = Output_signal_fulllen(conf.NFFT/2-conf.NSLRB*conf.NRBsc/2+1:conf.NFFT/2+conf.NSLRB*conf.NRBsc/2, :);
            
end
