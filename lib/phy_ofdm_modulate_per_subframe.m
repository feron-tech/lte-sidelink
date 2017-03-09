function output_signal = phy_ofdm_modulate_per_subframe(conf, input_signal)
%phy_ofdm_modulate_per_subframe creates time-domain waveform for
%transmission (36.211, 9.9).
% Inputs: 
%   conf: struct containing the following phy configuration related
%   fields: NSLsymb, NFFT, cpLen0, cpLenR, NRBsc
%   input_signal : the freq-domain signal (time-frequency grid)
output_signal = zeros(2*conf.NSLsymb*conf.NFFT + 2*conf.cpLen0 + 2*(conf.NSLsymb-1)*conf.cpLenR, 1);

tmp = zeros(conf.NFFT,1);
counter = 1;
for ll = 1 :2*conf.NSLsymb
    if ll == 1 || ll == conf.NSLsymb + 1
        cp = conf.cpLen0;
    else
        cp = conf.cpLenR;
    end
    % zero stuff:
    tmp((conf.NFFT-conf.NSLRB*conf.NRBsc)/2+1:conf.NFFT-(conf.NFFT-conf.NSLRB*conf.NRBsc)/2) = input_signal(:,ll);
    % IFFT
    Tmp = ifft(ifftshift(tmp));
    % Normalize power:
    Tmp = conf.NFFT/sqrt(conf.NSLRB*conf.NRBsc)*Tmp;
    % Add CP:
    Tmp = [Tmp(end-cp+1:end); Tmp]; %#ok<AGROW>
    % Shift by half subcarrier:
    Tmp = Tmp.*exp(2i*pi*(-cp:conf.NFFT-1)'/conf.NFFT/2);
    
    
    output_signal(counter : counter - 1 + conf.NFFT + cp) = Tmp;
    counter = counter + conf.NFFT + cp;
end


