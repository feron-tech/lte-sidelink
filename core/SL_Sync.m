classdef SL_Sync
    %SL_SYNC implements the functionalities of sidelink ssynchronization for both transmitter and receiver, based on 36.211, 9.7
    %The following input fields should be provided (if not set, default values are used).
    %   syncOffsetIndicator (default is 0)
    %   syncPeriod          (default is 40)  
    %   cp_Len_r12          (default is 'Normal')
    %   NSLRB               (default is 25)
    %   NSLID               (default is 0)
    % Contributors: Konstantinos Maliatsos (maliatsos), Antonis Gotsis (antonisgotsis)

    %% properties
    
     properties (SetAccess = protected, GetAccess = public)  % properties configured by class calling (sync-only and common with SL_Broadcast)
        syncOffsetIndicator;                % Offset indicator for sync subframe with respect to 0 subframe
        syncPeriod;                         % sync subframe period (im # subframes)
        cp_Len_r12;                         % CP configuration: 'Normal' or 'Extended'. Determines Number of Symbols per slot (7 or 6)
        NSLRB;                              % Sidelink bandwidth (sl-bandwidth) (transmitted in MIB-SL): This is in ul-bandwidth (SIB2)
        NSLID;                              % Sidelink Cell-ID (slssid)
        slMode;                             % Sidelink Mode (1, 2, 3 or 4). Value 0 corresponds to the legacy LTE case, but this is not fully supported/validated yet.
    end
    
    properties (SetAccess = public)     
        N_pss_cazac = 63;                   % Zadoff-Chu length (actually -1)
        psss_symbols;                       % Vector to contain psss_symbols
        psss_time_domain;                   % Vector to contain psss in time domain
        psss_indices;                       % Indices of the psss into the grid
        ssss_symbols_0;                     % Vector to contain ssss_symbols 0
        ssss_symbols_1;                     % Vector to contain ssss_symbols 1
        ssss_time_domain_0;                 % Vector to contain ssss_symbols_0
        ssss_time_domain_1;                 % Vector to contain ssss_symbols_1
        ssss_indices_0;                     % Index of the ssss 0 into the grid
        ssss_indices_1;                     % Index of the ssss 1 into the grid
        sync_grid;                          % Grid of Synchronization subframe
        rx_status = 0;                      % Receiver status: 0 searching for signal, 1: signal found/synchronizing 2: operating.
        memory;                             % Temporary matrix for storing intermediatte results
        psss_point                          % Points for psss
        psss_val                            % Values of psss metric
        ssss_point                          % Points for ssss
        ssss_val                            % Values of ssss metric
        sync_point                          % Synchronization point
        cp_guard = 0;                       % Guard inside cyclic prefix.
        synched_blocks                      % Synchronized blocks
        freq_offset                         % Frequency offset estimate
        sample_counter = 0;                 % sample counter related with frequency offset
        NRBsc = 12;                         % Resource block size in the frequency domain, expressed as a number of subcarriers
        NSLsymb;                            % Number of SL symbols per slot, depending on CPconf
        NFFT;                               % FFT size
        cpLen0;                             % CP length for 0th symbol
        cpLenR;                             % CP length for remaining symbols
        chanSRate;                          % Channel Sampling Rate
    end
    
    properties (Hidden) % needed for rx sync
        threshold1 = [];                    % Autocorrelation threshold
        threshold2 = [];                    % PSSS threshold
        threshold3 = [];                    % SSSS threshold  
        signal_old = [];                    % temporary vector for storing intermediate results
        psss_status = [];                   % temporary vector for storing intermediate results
        Rauto_old = [];                     % temporary vector for storing intermediate results
        Renergy_old = [];                   % temporary vector for storing intermediate results
    end
    
    %% methods
    
    methods
        
        
        function h = SL_Sync(varargin)
            %Constructor & Initializer
            
            % ----------------------------------- CONFIGURATION -----------------------------------
            % 1st input: sync conf
            slSyncConfig = varargin{1};
            if isfield(slSyncConfig,'syncOffsetIndicator')
                h.syncOffsetIndicator = slSyncConfig.syncOffsetIndicator;
            else % default
                h.syncOffsetIndicator = 0;
            end
            assert(h.syncOffsetIndicator>=0 & h.syncOffsetIndicator<=39,'Invalid setting of syncOffsetIndicator. Valid range: 0..39')
            
            if isfield(slSyncConfig,'syncPeriod')
                h.syncPeriod = slSyncConfig.syncPeriod;
            else % default
                h.syncPeriod = 40;
            end
            assert(h.syncPeriod>=1 & h.syncPeriod<=160,'Invalid setting of Period. Valid range: 1..160');

            % 2nd input: phy conf
            slBroadConfig = varargin{2};
            if isfield(slBroadConfig,'cp_Len_r12')
                h.cp_Len_r12 = slBroadConfig.cp_Len_r12;
            else % default
                h.cp_Len_r12 = 'Normal';
            end
            assert(isequal(h.cp_Len_r12,'Normal') | isequal(h.cp_Len_r12,'Extended'),'Invalid CP Length mode. Select from {Normal,Extended}');

            if isfield(slBroadConfig,'NSLRB')
                h.NSLRB = slBroadConfig.NSLRB;
            else % default
                h.NSLRB = 25;
            end
            assert(isequal(h.NSLRB,6) | isequal(h.NSLRB,15) | isequal(h.NSLRB,25) | isequal(h.NSLRB,50) | isequal(h.NSLRB,75) | isequal(h.NSLRB,100),'Invalid SL Bandwidth mode. Select from {6,15,25,50,75,100}');           
            
            if isfield(slBroadConfig,'NSLID')
                h.NSLID = slBroadConfig.NSLID;
            else % default
                h.NSLID = 0;
            end
            assert(h.NSLID>=0 & h.NSLID<=335,'Invalid setting of NSLID. Valid range: 0..335');
            
            if isfield(slBroadConfig,'slMode')
                h.slMode = slBroadConfig.slMode;
            else % default
                h.slMode = 1;
            end
            assert(isequal(h.slMode,1) | isequal(h.slMode,2) | isequal(h.slMode,3) | isequal(h.slMode,4),'Invalid SL mode. Select from {1,2,3,4}. 1 or 2 for D2D and 3 or 4 for V2V.');           

            % ----------------------------------- PHY INIT -----------------------------------
            switch h.NSLRB
                case 6,   h.NFFT = 128;  h.chanSRate = 1.92e6;
                case 15,  h.NFFT = 256;  h.chanSRate = 3.84e6;
                case 25,  h.NFFT = 512;  h.chanSRate = 7.68e6;
                case 50,  h.NFFT = 1024; h.chanSRate = 15.36e6;
                case 75,  h.NFFT = 1536; h.chanSRate = 23.04e6;
                case 100, h.NFFT = 2048; h.chanSRate = 30.72e6;
            end
            if strcmp(h.cp_Len_r12,'Normal')
                h.cpLen0 = round(0.0781*h.NFFT);
                h.cpLenR = round(0.0703*h.NFFT);
                h.NSLsymb = 7;
            elseif strcmp(h.cp_Len_r12,'Extended')
                h.cpLen0 = round(0.25*h.NFFT);
                h.cpLenR = round(0.25*h.NFFT);
                h.NSLsymb = 6;
            end
            
            % ----------------------------------- SYNC INIT-----------------------------------
            % generate sequences
            if ~isempty(h.NSLID)
                h = create_pss(h);
                h = create_sss(h);
            end
            % create grid: output h.sync_grid
            h = insert_sync_to_grid(h);
            
            
        end % SL_Sync
        
        function h = create_pss(h)
            %Create Primary Sync Signals (36.211, 9.7.1)
            
            %% Create PSS signals
            if h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                nid_2 = mod(h.NSLID,3); num_nid2s = length(nid_2);
                ZC_ind = [25; 29; 34];
            elseif h.slMode > 0 % sidelink mode
                nid_2 = zeros(size(h.NSLID));
                nid_2(h.NSLID>167) = 1;
                num_nid2s = length(nid_2);
                ZC_ind = [26, 37];
            else
                error('Unknown mode of operation');
            end
            
            % Initialization of output sequence matrix:
            h.psss_symbols = complex(zeros(h.N_pss_cazac-1, num_nid2s));
            
            n_ind = (0:h.N_pss_cazac-1)';
            counter = 1;
            for ii = nid_2
                jj = ii + 1;
                tmp = sqrt(72/(h.N_pss_cazac-1))*exp(-1i*pi*ZC_ind(jj)*n_ind.*(n_ind+1)/h.N_pss_cazac);
                h.psss_symbols(:, counter) = tmp([1:(h.N_pss_cazac-1)/2 (h.N_pss_cazac-1)/2+2:h.N_pss_cazac], 1);
                counter = counter + 1;
            end
            
            %% Create PSSS indices
            Nsc = h.NSLRB*h.NRBsc;
            
            if h.slMode > 0 % sidelink mode
                h.psss_symbols = [h.psss_symbols; h.psss_symbols];
                if strcmp(h.cp_Len_r12, 'Normal')
                    h.psss_indices = [(Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: Nsc+Nsc/2+(h.N_pss_cazac-1)/2) (2*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 2*Nsc+Nsc/2+(h.N_pss_cazac-1)/2)];
                elseif strcmp(h.cp_Len_r12, 'Extended')
                    h.psss_indices = [(Nsc/2-(h.N_pss_cazac-1)/2+1: Nsc/2+(h.N_pss_cazac-1)/2) (Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: Nsc+Nsc/2+(h.N_pss_cazac-1)/2)];
                end
            elseif h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                if strcmp(h.cp_Len_r12, 'Normal')
                    h.psss_indices = (6*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 6*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                elseif strcmp(h.cp_Len_r12, 'Extended')
                    h.psss_indices = (5*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 5*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                end
            end
            
            %% Create time domain signal:
            tmp = zeros(h.NFFT, 1);
            if h.slMode > 0 % sidelink mode
                tmp(h.NFFT/2-(h.N_pss_cazac-1)/2+1:h.NFFT/2+(h.N_pss_cazac-1)/2) = h.psss_symbols(1:h.N_pss_cazac-1);
            elseif h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                ind = [(h.NFFT/2-(h.N_pss_cazac-1)/2:h.NFFT/2);  (h.NFFT/2+2:(h.N_pss_cazac-1)/2+1)] ;
                tmp(ind) =  h.psss_symbols(1:h.N_pss_cazac-1);
            end
            
            % IFFT
            Tmp = ifft(ifftshift(tmp));
            % Normalize power:
            Tmp = h.NFFT/sqrt(h.NSLRB*h.NRBsc)*Tmp;
            % Add CP:
            Tmp = [Tmp(end-h.cpLenR+1:end); Tmp]; 
            % Shift by half subcarrier:
            h.psss_time_domain = Tmp.*exp(2i*pi*(-h.cpLenR:h.NFFT-1)'/h.NFFT/2);
            
        end %  create_pss
        
        function h = create_sss(h)
             %Create Secondary Sync Signals (36.211, 9.7.2)
            
            %% This function creates the secondary synch signals:
            if h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                nid_1 = floor(h.NSLID/3); num_nid1s = length(nid_1);
                nid_2 = mod(h.NSLID,3);                
            elseif h.slMode > 0 % sidelink mode
                nid_1 = mod(h.NSLID, 168); num_nid1s = length(nid_1);
                nid_2 = floor(h.NSLID/168);
                % Initialization of output sequence matrix:
            else
                error('Unknown mode of operation');
            end
            % Initialization of output sequence matrix:
            h.ssss_symbols_0 = complex(zeros(h.N_pss_cazac-1, num_nid1s));
            h.ssss_symbols_1 = complex(zeros(h.N_pss_cazac-1, num_nid1s));
            
            counter = 1;
            for jj = nid_1
                % Find parameters m0 and m1:
                q_hat = floor(jj/((h.N_pss_cazac-1)/2-1));
                q = floor((jj + q_hat*(q_hat+1)/2)/((h.N_pss_cazac-1)/2-1));
                m_hat = jj + q*(q+1)/2;
                
                m0 = mod(m_hat, (h.N_pss_cazac-1)/2);
                m1 = mod(m0 + floor(m_hat/((h.N_pss_cazac-1)/2)) + 1, (h.N_pss_cazac-1)/2);
                
                % Create x sequences for s_wave, c_wave and z:
                x1 = (zeros((h.N_pss_cazac-1)/2,1));
                x2 = (zeros((h.N_pss_cazac-1)/2,1));
                x3 = (zeros((h.N_pss_cazac-1)/2,1));
                x1(5) = 1;x2(5) = 1;x3(5) = 1;
                
                for ii = 1 : length(x1)-5
                    x1(5+ii) = mod(x1(ii+2)+x1(ii),2);
                    x2(5+ii) = mod(x2(ii+3)+x2(ii),2);
                    x3(5+ii) = mod(x3(ii+4)+x3(ii+2)+x3(ii+1)+x3(ii),2);
                end
                
                % Create s_wave sequence:
                s_wave = 1 - 2*x1;
                
                % Create s0_m0 and s1_m1:
                s0_m0 = circshift(s_wave(:), -m0);
                s1_m1 = circshift(s_wave(:), -m1);
                
                % create c_wave:
                c_wave = 1 - 2*x2;
                
                % Create z_wave:
                z_wave = 1 - 2*x3;
                
                % Create z1_m0 and z1_m1:
                n = 0:(h.N_pss_cazac-1)/2-1;
                z1_m0 = z_wave(mod(n + mod(m0,8), (h.N_pss_cazac-1)/2) + 1);
                z1_m1 = z_wave(mod(n + mod(m1,8), (h.N_pss_cazac-1)/2) + 1);
                
                % Create final sequences:
                seq_sub_0 = complex(zeros(h.N_pss_cazac-1, 1));
                seq_sub_1 = complex(zeros(h.N_pss_cazac-1, 1));
                
                
                % Create c0 and c1:
                c0 = circshift(c_wave, -(nid_2(counter)));
                c1 = circshift(c_wave, -(nid_2(counter))-3);
                
                seq_sub_0(1:2:end) = s0_m0.*c0;
                seq_sub_1(1:2:end) = s1_m1.*c0;
                
                seq_sub_0(2:2:end) = s1_m1.*c1.*z1_m0;
                seq_sub_1(2:2:end) = s0_m0.*c1.*z1_m1;
                
                if (h.slMode == 1 || h.slMode == 2 )
                    h.ssss_symbols_0(:, counter) = sqrt(72/62)*seq_sub_0;
                    h.ssss_symbols_1(:, counter) = h.ssss_symbols_0(:, counter);
                elseif (h.slMode == 3 || h.slMode == 4 )
                    h.ssss_symbols_1(:, counter) = sqrt(72/62)*seq_sub_1;
                    h.ssss_symbols_0(:, counter) = h.ssss_symbols_1(:, counter);
                elseif h.slMode == 0 % not fully supported yet
                    h.ssss_symbols_0(:, counter) = sqrt(72/62)*seq_sub_0;
                    h.ssss_symbols_1(:, counter) = sqrt(72/62)*seq_sub_1;
                end
                counter = counter + 1;
            end
            
            %% Create SSSS indices
            Nsc = h.NSLRB*h.NRBsc;
            
            if h.slMode > 0 % sidelink mode
                if strcmp(h.cp_Len_r12, 'Normal')
                    h.ssss_indices_0 = 7*Nsc + (4*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 4*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                    h.ssss_indices_1 = 7*Nsc + (5*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 5*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                elseif strcmp(h.cp_Len_r12, 'Extended')
                    h.ssss_indices_0 = 6*Nsc + (3*Nsc/2-(h.N_pss_cazac-1)/2+1: 3*Nsc/2+(h.N_pss_cazac-1)/2);
                    h.ssss_indices_1 = 6*Nsc + (4*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 4*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                end
            elseif h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                if strcmp(h.cp_Len_r12, 'Normal')
                    h.ssss_indices_0 = (5*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 5*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                    h.ssss_indices_1 = h.ssss_indices_0;
                elseif strcmp(h.cp_Len_r12, 'Extended')
                    h.ssss_indices_0 = (4*Nsc+Nsc/2-(h.N_pss_cazac-1)/2+1: 4*Nsc+Nsc/2+(h.N_pss_cazac-1)/2);
                    h.ssss_indices_1 = h.ssss_indices_0; % h.ssss_indices_1 = h.ssss_indices_0 kostas??
                end
            end
            
            %% Create time domain signal:
            h.ssss_time_domain_0 = create_time_domain_signal(h,  h.ssss_symbols_0);
            if h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                h.ssss_time_domain_1 = create_time_domain_signal(h,  h.ssss_symbols_1);
            elseif h.slMode > 0 % sidelink mode
                h.ssss_time_domain_1 = h.ssss_time_domain_0;
            end
            
        end % create_sss
        
        function signal = create_time_domain_signal(h, in_signal)
        %Get time-domain signals (36.211, 9.9) 
            tmp = zeros(h.NFFT, 1);
            if h.slMode > 0 % sidelink mode
                tmp(h.NFFT/2-(h.N_pss_cazac-1)/2+1:h.NFFT/2+(h.N_pss_cazac-1)/2) = in_signal;
            elseif h.slMode == 0 % legacy LTE mode, not fully tested/supported yet
                ind = [(h.NFFT/2-(h.N_pss_cazac-1)/2:h.NFFT/2);  (h.NFFT/2+2:(h.N_pss_cazac-1)/2+1)] ;
                tmp(ind) =  in_signal;
            end
            % IFFT
            Tmp = ifft(ifftshift(tmp));
            % Normalize power:
            Tmp = h.NFFT/sqrt(h.NSLRB*h.NRBsc)*Tmp;
            % Add CP:
            Tmp = [Tmp(end-h.cpLenR+1:end); Tmp]; 
            % Shift by half subcarrier:
            signal = Tmp.*exp(2i*pi*(-h.cpLenR:h.NFFT-1)'/h.NFFT/2);
        end % create_time_domain_signal
        
        function h = insert_sync_to_grid(h)
            %Map synchronization signals to time-frequency grid)
            h.sync_grid = zeros( h.NSLRB*h.NRBsc, 2*h.NSLsymb );
            h.sync_grid(h.psss_indices)   =  h.psss_symbols;
            h.sync_grid(h.ssss_indices_0) =  h.ssss_symbols_0;
            h.sync_grid(h.ssss_indices_1) =  h.ssss_symbols_1;
        end % insert_sync_to_grid
        
        function h = detector_synchronizer(previous_signal, current_signal, h)
            %DESCRIPTION TO BE ADDED
            
            samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
            
            M = h.NFFT;
            %% Autocorrelator:
            lag = M + h.cpLenR;
            signal = [previous_signal; current_signal(1:lag+M)];
            
            if isempty(h.threshold1)
                h.signal_old = zeros(length(signal), 1);
                h.Rauto_old = zeros(samples_per_subframe, 1);
                h.Renergy_old = ones(samples_per_subframe, 1);
                h.psss_status = 0;
                h.threshold1 = 0.2;
                h.threshold2 = raylinv(0.97, 2*sqrt(h.NFFT/2));
                h.threshold3 = raylinv(0.92, 2*sqrt(h.NFFT/4));
            else
                if h.psss_status == 1
                    h.signal_old = zeros(length(signal), 1);
                    h.Rauto_old = zeros(samples_per_subframe, 1);
                    h.Renergy_old = ones(samples_per_subframe, 1);
                    h.psss_status = 0;
                    h.threshold1 = 0.2;
                    h.threshold2 = raylinv(0.97, 2*sqrt(h.NFFT/2));
                    h.threshold3 = raylinv(0.92, 2*sqrt(h.NFFT/4));
                end
            end
            
            %% Normalize by power:
            Rauto = auto_correlator(signal, M, lag);
            Renergy = energy_detector(signal, 2*M, 0); Renergy = Renergy(1:length(Rauto));
            Q_old = 2*h.Rauto_old./h.Renergy_old;
            Q = 2*Rauto./Renergy;
            Q = [Q_old; Q];
            
            distance_ssss_normal = 10*h.NFFT + round(h.NFFT*0.0781) + 9*round(h.NFFT*0.0703);
            distance_ssss_extended = 9*h.NFFT + 9*h.NFFT*0.25;
            
            if h.psss_status == 0
                % Find values exceeding threshold:
                flag = 1; counter = 0;
                while flag && counter<2
                    check = 0;
                    while ~check && counter<2
                        counter = counter + 1;
                        ind_tmp = abs(Q((counter-1)*samples_per_subframe/2+1:counter*samples_per_subframe/2 + 2*(h.NFFT+h.cpLen0)))>h.threshold1;
                        [~, ind] = max(abs(Q((counter-1)*samples_per_subframe/2+1:counter*samples_per_subframe/2 + 2*(h.NFFT+h.cpLen0))));
                        check = ~isempty(Q(ind_tmp));
                        if ind>samples_per_subframe/2
                            check = 0;
                        end
                    end
                    if check
                        % found something - let's find the 2nd...
                        [val, ind] = max(abs(Q((counter-1)*samples_per_subframe/2+1:counter*samples_per_subframe/2)));
                        ind = (counter-1)*samples_per_subframe/2+ind;
                        if val>0.5
                            h.threshold1 = 0.35;
                        else
                            h.threshold1 = 0.2;
                        end
                        search_space = [ind+min([distance_ssss_normal distance_ssss_extended])-2*h.cpLen0; ind+max([distance_ssss_normal distance_ssss_extended])+2*h.cpLen0];
                        check_2nd = ~isempty(Q(abs(Q(search_space(1):search_space(2)))>h.threshold1));
                        if check_2nd
                            [val1,ind1] = max(abs(Q(search_space(1):search_space(2))));
                            dt_normal = ind1 + search_space(1) -1 - ind - distance_ssss_normal;
                            dt_extended = ind1 - ind + search_space(1) -1 - distance_ssss_extended;
                            
                            if abs(dt_normal)<2*h.cpLen0 || abs(dt_extended)<2*h.cpLen0
                                flag = 1;
                                signal_new = [h.signal_old(h.NFFT+h.cpLen0+1:end); signal];
                                energy = mean(abs(signal_new(ind:ind+samples_per_subframe/2-1)).^2);
                                
                                [h, Rpsss, h.psss_status, values, indices] = find_psss(h, signal_new/sqrt(energy), ind+2*h.cpLen0, lag, h.threshold2);
                            else
                                % moving on....
                            end
                        end
                    end
                end
            end
            
            
            if h.psss_status == 1
                h.psss_point = indices;
                h.psss_val = values;
                [Rssss, h, nid1_index] = find_ssss(h, signal_new/sqrt(energy), lag, h.threshold3);
                flag = 0;
                if h.sync_point < 0
                    signal_new = [h.signal_old; signal];
                    h.sync_point = h.sync_point + h.NFFT + h.cpLen0; 
                    h.sample_counter = length(h.signal_old) - h.sync_point + h.cp_guard +1; 
                    h.psss_point = h.psss_point +  h.NFFT + h.cpLen0;
                    h.ssss_point = h.ssss_point +  h.NFFT + h.cpLen0;
                    flag = 1;
                else
                    h.sample_counter = length(h.signal_old) -h.NFFT - h.cpLen0 - h.sync_point + h.cp_guard +1;                    
                end
                h = freq_offset_estimate(h, signal_new(1:samples_per_subframe), signal_new(samples_per_subframe+1:end));
                [h, out_signal] = compensate_freq_offset(signal_new(h.sync_point - h.cp_guard:h.sync_point - h.cp_guard + samples_per_subframe-1), h);
                
                h.synched_blocks = out_signal;
                if flag == 1
                    h.sync_point = h.sync_point- h.NFFT - h.cpLen0;
                    h.psss_point = h.psss_point - h.NFFT - h.cpLen0;
                    h.ssss_point = h.ssss_point -  h.NFFT - h.cpLen0;
                end
            end
            
            
            h.signal_old = [h.signal_old(end-3*h.cpLen0-h.NFFT+1:end); previous_signal];
            h.Rauto_old = Rauto;
            h.Renergy_old = Renergy;
            
        end % detector/synchronizer
        
        function [h, Rpsss, psss_status, values, indices] = find_psss(h, signal, ind, lag, threshold2)
            %DESCRIPTION TO BE ADDED
                
            % Define search space:
            search_space = [ind - 2*h.cpLen0; ind + 2*h.cpLen0];
            if ind - 2*h.cpLen0<0
                keyboard;
                search_space(1) = 1;
            end
            psss_status = 0;
            %% PSSS Finder:
            rsize = search_space(2)-search_space(1)+lag+1;
            Rpsss = zeros(rsize, size(h.psss_time_domain,2));
            values = []; indices = [];
            for ll = 1 : size(h.psss_time_domain,2)
                Rpsss(:,ll) = cross_correlator(signal(search_space(1):search_space(2)+2*lag-1), h.psss_time_domain(:,ll));
                if ~isempty(Rpsss(abs(Rpsss)>threshold2))
                    [val1, ind1] = max(abs(Rpsss(1:floor(rsize/2))));
                    [val2, ind2] = max(abs(Rpsss(ceil(rsize/2):end)));
                    if val1>threshold2 && val2>threshold2
                        h.rx_status = 1;
                        fprintf('Signal found for PSSS %d \n', ll);
                        psss_status = 1;
                        %% Discover cp mode:
                        cp_dif = floor(rsize/2) + ind2 - ind1;
                        if abs(cp_dif - (1+0.0703)*h.NFFT) < abs(cp_dif - (1+0.25)*h.NFFT)
                            fprintf('Normal cp mode discovered \n');
                            detected_cp_Len_r12 = 'Normal';
                        else
                            fprintf('Extended cp mode discovered \n');
                            detected_cp_Len_r12 = 'Extended';
                        end
                        %h = change_cp_mode(h);
                        % error check
                        if ~isequal(detected_cp_Len_r12, h.cp_Len_r12)
                            error('Detected CP Len is different from Configured');
                        end                        
                        
                        values = [values; val1 val2]; %#ok<AGROW>
                        indices = [indices; search_space(1)+ind1-1 search_space(1)+floor(rsize/2)+ind2-1]; %#ok<AGROW>

                    end
                end
            end
            [~,nid2_index] = max(max(values, [], 2), [], 1);
            values = values(nid2_index,:);
            indices = indices(nid2_index, :);
            
%             keyboard

        end %find_psss
        
        function [Rssss, h, nid1_index] = find_ssss(h, signal, lag, threshold3)
            %DESCRIPTION TO BE ADDED

            samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
            position_ssss = h.psss_point(1) + (h.NSLsymb+3)*h.NFFT + h.cpLen0 + (h.NSLsymb+2)*h.cpLenR;
            
            search_space = [position_ssss - 2*h.cpLen0; position_ssss + 2*h.cpLen0 + h.NFFT+lag];
            rsize = search_space(2)-search_space(1) + 1 - lag;
            Rssss = zeros(rsize, size(h.ssss_time_domain_0, 2));
            
            h.ssss_point = [];
            h.ssss_val = [];
            
            for ll = 1 : size(h.ssss_time_domain_0,2)
                Rssss(:,ll) = cross_correlator(signal(search_space(1):search_space(2)-1), h.ssss_time_domain_0);
                [val3, ind3] = max(abs(Rssss(1:floor(rsize/2))));
                [val4, ind4] = max(abs(Rssss(ceil(rsize/2):end)));
                if val3>threshold3 && val4>threshold3
                    h.rx_status = 2;
                    fprintf('SSSS discovered \n');
                    tmp = [search_space(1)-1+ind3 search_space(1)-1+ind4+floor(rsize/2)];
                    h.ssss_point = [h.ssss_point; tmp];
                    h.ssss_val = [h.ssss_val; val3 val4];
                    
                    %% Estimate the synchronization point:
                    n = sum(h.psss_val) + sum(h.ssss_val);
                    
                    if strcmp(h.cp_Len_r12, 'Normal')
                        s1 = h.psss_point(1) - (h.NFFT + h.cpLen0);
                        s2 = h.psss_point(2) - (2*h.NFFT + h.cpLen0 + h.cpLenR);
                        s3 = h.ssss_point(1) - samples_per_subframe/2 - (4*h.NFFT + h.cpLen0 + 3*h.cpLenR);
                        s4 = h.ssss_point(2) - samples_per_subframe/2 - (5*h.NFFT + h.cpLen0 + 4*h.cpLenR);
                    else
                        s1 = h.psss_point(1);
                        s2 = h.psss_point(2) - (h.NFFT + h.cpLen0);
                        s3 = h.ssss_point(1) - samples_per_subframe/2 - (3*h.NFFT + h.cpLen0 + 3*h.cpLenR);
                        s4 = h.ssss_point(2) - samples_per_subframe/2 - (4*h.NFFT + h.cpLen0 + 4*h.cpLenR);
                    end
                    
                    sync_point = round((s1*h.psss_val(1) + s2*h.psss_val(2) + s3*h.ssss_val(1) + s4*h.ssss_val(2))/n);
                    h.sync_point = [h.sync_point; sync_point];
                    
                end
                
            end % find_ssss
            
            
            [~,nid1_index] = max(max(h.ssss_val, [], 2), [], 1);
            if ~isempty(nid1_index)
                h.ssss_val = h.ssss_val(nid1_index,:);
                h.ssss_point = h.ssss_point(nid1_index, :);
                h.sync_point = h.sync_point(nid1_index, :);
                fprintf('Initial Synchronization achieved \n');
            end
            
        end
        
        function h = freq_offset_estimate(h, previous_signal, current_signal)
            %DESCRIPTION TO BE ADDED

            
            M = h.NFFT;
            lag = h.NFFT + h.cpLenR;
            signal = [previous_signal; current_signal];
            
            R1 = sum(signal(h.psss_point(1)-2*h.cpLen0+h.cpLenR:h.psss_point(1)-1+M-2*h.cpLen0+h.cpLenR).*conj(signal(h.psss_point(1)+lag-2*h.cpLen0+h.cpLenR:h.psss_point(1)-1+M+lag-2*h.cpLen0+h.cpLenR)));
            R2 = sum(signal(h.ssss_point(1)-2*h.cpLen0+h.cpLenR:h.ssss_point(1)-1+M-2*h.cpLen0+h.cpLenR).*conj(signal(h.ssss_point(1)+lag-2*h.cpLen0+h.cpLenR:h.ssss_point(1)-1+M+lag-2*h.cpLen0+h.cpLenR)));
            
            h.freq_offset = -h.NFFT/(h.NFFT+h.cpLenR)*angle(R1)/4/pi - h.NFFT/(h.NFFT+h.cpLenR)*angle(R2)/4/pi;
            
            fprintf('Estimated Freq Offset: %.4f\n',h.freq_offset);
            
            % h.freq_offset = 0;
        end % freq_offset_estimate
        
        function [h, out_signal] = compensate_freq_offset(in_signal, h)
            %DESCRIPTION TO BE ADDED


            out_signal = in_signal.*exp(-2i*pi*(h.sample_counter:h.sample_counter + length(in_signal)-1)'*h.freq_offset/h.NFFT);
        end %compensate_freq_offset

        function h = synchronizer(h, previous_frame, current_frame)
            %DESCRIPTION TO BE ADDED

            lag = h.NFFT + h.cpLenR;
            
            search_space1 = [h.psss_point(1)-2*h.cpLen0 h.psss_point(1)+2*h.cpLen0];
            search_space2 = [h.psss_point(2)-2*h.cpLen0 h.psss_point(2)+2*h.cpLen0];
            search_space3 = [h.ssss_point(1)-2*h.cpLen0 h.ssss_point(1)+2*h.cpLen0];
            search_space4 = [h.ssss_point(2)-2*h.cpLen0 h.ssss_point(2)+2*h.cpLen0];
            
            signal = [h.memory(end-2*h.cpLen0+1:end,end-1); previous_frame; current_frame];
            
            R1 = cross_correlator(signal(search_space1(1):search_space1(2)+lag-1), h.psss_time_domain);
            [val1, ind1] = max(abs(R1)); ind1 = search_space1(1) + ind1 - 1;
            h.psss_point(1) = ind1;
            
            R2 = cross_correlator(signal(search_space2(1):search_space2(2)+lag-1), h.psss_time_domain);
            [val2, ind2] = max(abs(R2)); ind2 = search_space2(1) + ind2 - 1;
            h.psss_point(2) = ind2;
            
            R3 = cross_correlator(signal(search_space3(1):search_space3(2)+lag-1), h.ssss_time_domain_0);
            [val3, ind3] = max(abs(R3)); ind3 = search_space3(1) + ind3 - 1;
            h.ssss_point(1) = ind3;
            
            R4 = cross_correlator(signal(search_space4(1):search_space4(2)+lag-1), h.ssss_time_domain_0);
            [val4, ind4] = max(abs(R4)); ind4 = search_space4(1) + ind4 - 1;
            h.ssss_point(2) = ind4;

            h.psss_val = [val1 val2];
            h.ssss_val = [val3 val4];
            
            n = sum(h.psss_val) + sum(h.ssss_val);
            samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
            
            if strcmp(h.cp_Len_r12, 'Normal')
                s1 = h.psss_point(1) - (h.NFFT + h.cpLen0);
                s2 = h.psss_point(2) - (2*h.NFFT + h.cpLen0 + h.cpLenR);
                s3 = h.ssss_point(1) - samples_per_subframe/2 - (4*h.NFFT + h.cpLen0 + 3*h.cpLenR);
                s4 = h.ssss_point(2) - samples_per_subframe/2 - (5*h.NFFT + h.cpLen0 + 4*h.cpLenR);
            else
                s1 = h.psss_point(1);
                s2 = h.psss_point(2) - (h.NFFT + h.cpLen0);
                s3 = h.ssss_point(1) - samples_per_subframe/2 - (3*h.NFFT + h.cpLen0 + 3*h.cpLenR);
                s4 = h.ssss_point(2) - samples_per_subframe/2 - (4*h.NFFT + h.cpLen0 + 4*h.cpLenR);
            end
            h.sync_point = round((s1*h.psss_val(1) + s2*h.psss_val(2) + s3*h.ssss_val(1) + s4*h.ssss_val(2))/n) - 2*h.cpLen0;
            
            fprintf('Sync Point : %i\n',h.sync_point);
            
        end % synchronizer
        
        function [h, post_previous_frame, previous_frame, counter] = determine_frame_accession(h, rx_input, previous_frame, samples_per_subframe, counter)
            
            % Readjustment if sync point is marginally at the end of the frame:
            if ~isempty(h.psss_point)
                if (h.psss_point(1) == 2*h.cpLen0)
                    counter = counter  - samples_per_subframe/2;
                    h.psss_point = h.psss_point + samples_per_subframe/2;
                    h.ssss_point = h.ssss_point + samples_per_subframe/2;
                    h.sync_point = h.sync_point + samples_per_subframe/2;
                elseif (h.psss_point(1) == 2*h.cpLen0 + samples_per_subframe)
                    counter = counter  + samples_per_subframe/2;
                    h.psss_point = h.psss_point - samples_per_subframe/2;
                    h.ssss_point = h.ssss_point - samples_per_subframe/2;
                    h.sync_point = h.sync_point - samples_per_subframe/2;
                end
                post_previous_frame = rx_input(counter - 2*samples_per_subframe:counter-samples_per_subframe-1);
            else
                post_previous_frame = previous_frame;
            end
            previous_frame = rx_input(counter - samples_per_subframe:counter-1);
        end
        
    end % class methods
    
end % class

