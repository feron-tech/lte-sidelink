classdef SL_ChannelEstimator
    %SL_ChannelEstimator implements the required functionalities for performing single-subframe channel estimation for all SL physical channels. 
    % This is based on PUSCH channel estimation, so it also supports PUSCH Channel Estimation.
    %
    % Inputs (provided via a structure ce_params):
    %   Method  : Available options: 'LS' or 'mmse-direct' (other methods are also included in the class but not fully supported and tested yet)
    %   N_cp    : 2 element vector containing cyclic prefix length in samples (make sure to be aligned with SL physical channel configuration)
    %   NFFT    : FFT size of SC-FDMA transmission, e.g., 512 for 5MHz mode (make sure to be aligned with SL physical channel configuration).
    %   NSLsymb : scalar corresponding to number of OFDM symbols within a slot, i.e. 7 for 'normal', 6 for 'extended' cyclic prefix modes (make sure to be aligned with SL physical channel configuration).
    %   l_DMRS  : vector with elements the index of DMRS symbols within the subframe (e.g., [3, 10] for PSBCH)            
    %   N_f     : length of frequency resources (number of subcarriers), e.g., 72 (= 6 x 12) for PSBCH
    %   fd      : Doppler frequency of channel. Set equal to 0 for a static (time-invariant) channel
    %   M       : integer, determining the size of the window used in obtaining the channel estimate of each subcarrier (necessary only if Method=='mmse-direct')
    %   L_h     : Number of taps of the discrete-time equivalent channel impulse response (optional, relevant only for Method=='mmse-direct'). If not provided, a default  value floor(N_FFT/14) is used.
    %   SNR_dB  : Estimate of the operational SNR (in dB) (optional, relevant only for Method=='mmse-direct'). If not provided, a default value of SNR = 10 dB is used
    %
    % Contributors: Stelios Stefanatos (SteliosStefanatos)
   
    properties
        h_LS;       % baseline channel estimate obtained by LS channel estimation. One estimate for each DMRS SC-FDMA symbol in the dubframe
        h_est;      % refined version of h_LS by frequency domain filtering (same as h_LS if Method==LS)
        y;          % received sequence (N_f x length(l_DMRS) matrix).
        x;          % pilot sequence (N_f x length(l_DMRS) matrix)
        Method;     % method used to obtain the final channel estimate
        N_f;        % number of (pilot) subcarriers
        M;          % parameter determining the window size for frequency-domain h_LS refinement
        SNR_dB;     % the (nominal) operational SNR that the LMMSE channel estimator considers
        fd;        % normalized Doppler frequency
        L_h;        % (assumed) number of taps of the channel impulse response
        W_t         % weights used to interpolate/extrapolate the pilot-positions channel estimates over the whole subframe grid        
        W_left;     % weight vectors for LMMSE channel estimation per single pilot symbol (left)
        W_right;    % weight vectors for LMMSE channel estimation per single pilot symbol (right)
        w_middle;   % weight vectors for LMMSE channel estimation per single pilot symbol (middle)
        wf_middle;  % for fft chan-est method only        
        N_FFT;      % FFT size of SC-FDMA transmission (e.g., 2048 for 20MHz mode)
        N_cp        % cyclic prefix size (two element vector)        
        NSLsymb;    % scalar corresponding to number of OFDM symbols within a slot (7 for 'normal', 6 for 'extended' cyclic prefix modes)
        l_DMRS;     % vector with elements the index of DMRS symbols within the frame (e.g., [3, 10] for PUSCH)
    end
    
    methods        
            
        function obj = SL_ChannelEstimator(ce_params)
            %Constructor & Initializer
            
            % ---------- Get Input Parameters & Configure ----------------
            if isfield(ce_params,'Method')
                assert(isequal(ce_params.Method,'LS') | isequal(ce_params.Method,'mmse-direct')...
                    | isequal(ce_params.Method,'mmse-FFT') | isequal(ce_params.Method,'moving-average'));
                obj.Method = ce_params.Method;
            else
                warning('Method field of ce_params struct is not provided. Using default (LS)');
                obj.Method = 'LS';
            end
            
            if isfield(ce_params,'N_cp')
                obj.N_cp = ce_params.N_cp;
            else
                error('N_cp field of ce_params struct is required when fd~=0');
            end
            
            if isfield(ce_params,'N_FFT')
                obj.N_FFT= ce_params.N_FFT;
            else
                error('N_FFT field of ce_params struct is required when fd~=0');
            end
            
            if isfield(ce_params,'NSLsymb')
                obj.NSLsymb =  ce_params.NSLsymb;
            else
                error('Parameter NSLsymb is required as input for the requested channel estimation method');
            end
            
            if isfield(ce_params,'l_DMRS')
                obj.l_DMRS =  ce_params.l_DMRS';
            else
                error('Parameter l_DMRS is required as input for the requested channel estimation method');
            end
            
            if isfield(ce_params, 'N_f')
                obj.N_f = ce_params.N_f;
            else
                error('Parameter N_f is required')
            end
            
            if strcmp(ce_params.Method,'mmse-direct') || ...
                    strcmp(ce_params.Method,'mmse-FFT') || ...
                    strcmp(ce_params.Method,'moving-average')
                if isfield(ce_params,'M')
                    assert(ce_params.M>=0, 'parameter M of channel estimator should be a non-negative integer');
                    obj.M = ce_params.M;
                else
                    warning('Parameter M not provided. Default value (2) is used');
                    obj.M = 2;
                end
            end
            
            if isfield(ce_params,'fd')
                obj.fd = ce_params.fd;
            else
                warning('fd field (Doppler freq.) parameter not provided. Default value (0) is used');
                obj.fd = 0;
            end
                         
            if strcmp(ce_params.Method,'mmse-direct') || strcmp(ce_params.Method,'mmse-FFT')                
                if isfield(ce_params,'SNR_dB')
                    obj.SNR_dB = ce_params.SNR_dB;
                else
                    warning('SNR_dB parameter not provided. Default value (10) is used');
                    obj.SNR_dB = 10;
                end
                if isfield(ce_params,'L_h')
                    obj.L_h = ce_params.L_h;
                else
                    warning('L_h parameter not provided. Default value (NFFT/14) is used');
                    obj.L_h = floor(obj.N_FFT/14);
                end
            end
            
            % ---------- Initializations ----------------
            % Generate weights for LMMSE estimator bashannel
            % estimate (corresponding to one SC-FDMA DMRS symbol)
            if strcmp(ce_params.Method, 'mmse-direct')
                obj = obj.generate_mmse_direct_weights();
            end
            
            if strcmp(ce_params.Method, 'mmse-FFT')
                obj = obj.generate_mmse_FFT_weights();
            end
            
            % generate the time-domain weights for interpolation of the 
            % pilot estimates over the whole subframe grid
            if obj.fd==0 % static channel -> average the two LS estimates
                obj.W_t = (1/length(obj.l_DMRS)) * ones(obj.NSLsymb * 2, length(obj.l_DMRS));
            else           % varying channel -> generate interpolation matrix
                obj.W_t = zeros(obj.NSLsymb * 2, length(obj.l_DMRS));
                
                R_yy = zeros(length(obj.l_DMRS), length(obj.l_DMRS));
                for i = 1:length(obj.l_DMRS)
                    R_yy(i,:) = sinc(2*obj.fd*(obj.N_FFT+obj.N_cp(2))*(obj.l_DMRS - obj.l_DMRS(i)));
                end
                
                if length(obj.l_DMRS)==2 % if  2 pilot OFDM symbols within subframe, use the analytic formula for solving the system
                    R_yy_inv = [R_yy(2,2), -R_yy(1,2); -R_yy(2,1), R_yy(1,1)] * (1/(-R_yy(1,2)*R_yy(2,1) + R_yy(1,1)*R_yy(2,2)));
                    for l = 1:obj.NSLsymb * 2
                        obj.W_t(l,:) = sinc(2*obj.fd*(obj.N_FFT+obj.N_cp(2))*(obj.l_DMRS - (l-1))) * R_yy_inv;
                    end
                elseif length(obj.l_DMRS)==4 % if 4 pilot OFDM symbols within subframe, use the analytic formula for solving the system
                    det_R_yy = det(R_yy);
                    R_yy_2 = R_yy * R_yy;
                    R_yy_3 = R_yy * R_yy_2;
                    tr_R_yy = trace(R_yy);
                    tr_R_yy2 = trace(R_yy_2);
                    tr_R_yy3 = trace(R_yy_3);
                    R_yy_inv = ((1/6) * (tr_R_yy^3 - 3 * tr_R_yy * tr_R_yy2 + 2 * tr_R_yy3) * eye(4) -...
                                 0.5 * R_yy * (tr_R_yy^2 - tr_R_yy2) + R_yy_2 * tr_R_yy - R_yy_3)/det_R_yy;
                    for l = 1:obj.NSLsymb * 2
                        obj.W_t(l,:) = sinc(2*obj.fd*(obj.N_FFT+obj.N_cp(2))*(obj.l_DMRS - (l-1))) * R_yy_inv;
                    end         
                else % solve linear system numerically, exploiting that R_yy is 
                     % (a) symmetric and (b) positive definite
                    linsolve_opts.SYM = true; linsolve_opts.POSDEF = true;
                    for l = 1:obj.NSLsymb * 2
                        obj.W_t(l,:) = sinc(2*obj.fd*(obj.N_FFT+obj.N_cp(2))*(obj.l_DMRS - (l-1)))/R_yy;
              
                        obj.W_t(l,:) = linsolve(R_yy,sinc(2*obj.fd*(obj.N_FFT+obj.N_cp(2))*(obj.l_DMRS - (l-1)))',linsolve_opts)';
                    end
                end
            end  
            
        end % function
        
        function [h_est_grid, var_n_est] = chan_estimate(obj, y, x)
            %chan_estimate Main function performing channel estimation
            % Inputs:      y                     - M_sc � N_pilots matrix with each column corresponding to a received DMRS symbol. M_sc is the
            %                                      number of (contiguous) SC-OFDM subcarriers occupied by the DMRS symbols, N_pilots is the number of
            %                                      DMRS symbols used within the subframe.
            %              x                     - The corresponding M_sc � N_pilots matrix of transmitted DMRS symbols
            % Outputs:     h_est_grid            - M_sc �(2�NSLsymb) matrix with the i-th column corresponding to the channel estimate for the i-th SC-FDMA symbol of the subframe.
            %              var_n_est             - real-valued scalar representing an estimate of the noise variance affecting the transmission.
            obj.y = y;
            obj.x = x;
            
            
            % obtain the LS channel estimate per DMRS SC-FDMA symbol
            obj.h_LS = obj.h_LS_single_slot();
            
            % refine each LS estimate by frequency domain filtering
            if strcmp(obj.Method,'LS')
                obj.h_est = obj.h_LS;
            elseif strcmp(obj.Method,'mmse-direct')
                obj.h_est = obj.linear_channel_estimation_direct();
            elseif strcmp(obj.Method,'mmse-FFT')
                obj.h_est = obj.linear_channel_estimation_FFT();
            elseif strcmp(obj.Method,'moving-average')
                obj.h_est = obj.moving_average_channel_estimation();
            end
            
            % extrapolate/interpolate filtered estimates to data SC-FDMA
            % symbols
            h_est_grid = zeros(obj.N_f,2*obj.NSLsymb);
            %              keyboard
            for l = 1:2*obj.NSLsymb
                h_est_grid(:,l) = obj.h_est * (obj.W_t(l,:)');
            end
            
            % obtain an estimate of the noise variance
            var_n_est = sum(sum(abs((obj.y).*conj(obj.x) - h_est_grid(:,obj.l_DMRS+1)).^2))/obj.N_f;
            
        end
        
        function [h_LS] = h_LS_single_slot(obj)
            %h_LS_single_slot Finds the simple, least squares (LS) channel estimate for a single slot over the DRMS SC-FDMA symbols
            
            h_LS = (obj.y).*conj(obj.x);
        end
        
        function [h_est] = linear_channel_estimation_direct(obj)
            %linear_channel_estimation_direct Provides the channel estimate
            % by filtering the LS channel estimate using an MMSE weight
            % matrix
            
            if size(obj.w_middle,2)~=2*obj.M+1 || size(obj.W_left,2)~=2*obj.M+1 || size(obj.W_right,2)~=2*obj.M+1
                error('MMSE weights provided are not of length 2*M + 1')
            end
            
            if size(obj.W_left)~=size(obj.W_right)
                error('MMSE weights provided for left and right estimates are not consistent')
            end
            
            if 2*obj.M+1 > obj.N_f
                error('the length of the MMSE weights is greater than the number of subcarriers');
            end
            
            h_est = zeros(obj.N_f,length(obj.l_DMRS));
            for n = 1:length(obj.l_DMRS)
                for k = 0:obj.M-1
                    h_est(k+1,n) = obj.W_left(k+1,:) * obj.h_LS(1:2*obj.M+1,n);
                end
                for k = obj.M:obj.N_f - obj.M-1
                    h_est(k+1,n) = obj.w_middle * obj.h_LS(k-obj.M+1:k+obj.M+1,n);
                end
                i = 0;
                for k = obj.N_f - obj.M: obj.N_f - 1
                    i = i + 1;
                    h_est(k+1,n) = obj.W_right(i,:) * obj.h_LS(obj.N_f-(2*obj.M+1)+1:obj.N_f,n);
                end
            end
            
        end
        
        function [w] = mmse_weights(obj, k)
            % mmse_weights helper function for generate_mmse_direct_weights
            % method
            
            
            if (k<0) || (k>=obj.N_f)
                error('k should be in {0, 1, ..., obj.N_f-1}');
            elseif (k<obj.M)
                SCs = 0:2*obj.M;
            elseif (k>=obj.N_f - obj.M)
                SCs = obj.N_f-(2*obj.M-1)-2:obj.N_f-1;
            else
                SCs = k-obj.M:k+obj.M;
            end
            
            F = dftmtx(obj.N_FFT);
            F_s = F(SCs+1,1:obj.L_h);
            FF = (1/obj.L_h) * F_s * (F_s');
            var_noise_est = 10^(-obj.SNR_dB/10);
            A = FF/(var_noise_est * eye(2*obj.M+1) + FF);
            
            if k<obj.M
                w = A(k+1,:);
            elseif k >= obj.N_f - obj.M
                w = A(k - (obj.N_f - 2*obj.M-1)+1,:);
            else
                w = A(obj.M+1,:);
            end
            
        end
        
        function obj = generate_mmse_direct_weights(obj)
            % generate_mmse_direct_weights Finds the LMMSE weighting matrix
            % that is applied to the LS channel estimate for noise
            % reduction
            
            obj.W_left = zeros(obj.M,2*obj.M+1);
            obj.W_right = obj.W_left;
            for k = 0:obj.M-1
                obj.W_left(k+1,:) = obj.mmse_weights(k);
            end
            obj.w_middle = obj.mmse_weights(obj.M);
            i = 0;
            for k = obj.N_f - obj.M: obj.N_f - 1
                i = i + 1;
                obj.W_right(i,:) = obj.mmse_weights(k);
            end
        end
        
        % -------------------------------------------------------------
        % Following methods are not fully supported yet.      
        function obj = generate_mmse_FFT_weights(obj)
            %Finds the LMMSE weights for FFT based channel estimation
            
            obj.W_left = zeros(obj.M,2*obj.M+1);
            obj.W_right = obj.W_left;
            for k = 0:obj.M-1
                obj.W_left(k+1,:) = obj.mmse_weights(k);
            end
            
            i = 0;
            for k = obj.N_f - obj.M: obj.N_f - 1
                i = i + 1;
                obj.W_right(i,:) = obj.mmse_weights(k);
            end
            
            obj.wf_middle = obj.mmse_weights(obj.M);
            w_middle_ext = zeros(1,obj.N_f);
            w_middle_flipped = circshift(flipud(obj.wf_middle.'),-obj.M);
            w_middle_ext(1:obj.M+1) = w_middle_flipped(1:obj.M+1);
            w_middle_ext(obj.N_f-obj.M+1:obj.N_f) = w_middle_flipped(obj.M+2:2*obj.M+1);
            obj.wf_middle = fft(w_middle_ext).';
        end
        
        function [h_est] = linear_channel_estimation_FFT(obj)
            %MMSE channel estimation (FFT implementation)
            % For each subcarrier, a symmetric window of size 2*M+1 subcarriers is
            % used to obtain the estimate by means of a linear MMSE method
            
            
            if size(obj.W_left)~=size(obj.W_right)
                error('MMSE weights provided for left and right estimates are not consistent')
            end
            
            if 2*obj.M+1 > obj.N_f
                error('the length of the MMSE weights is greater than the number of subcarriers');
            end
            
            h_est = zeros(obj.N_f,2);
            for n = [1, 2]
                for k = 0:obj.M-1
                    h_est(k+1,n) = obj.W_left(k+1,:) * obj.h_LS(1:2*obj.M+1,n);
                end
                
                i = 0;
                for k = obj.N_f - obj.M: obj.N_f - 1
                    i = i + 1;
                    h_est(k+1,n) = obj.W_right(i,:) * obj.h_LS(obj.N_f-(2*obj.M+1)+1:obj.N_f,n);
                end
                
                
                % obtain "middle" subcarrier estimates via FFT method
                h_est_fft = ifft(fft(obj.h_LS(:,n)) .* obj.wf_middle);
                h_est(obj.M+1:obj.N_f-obj.M,n) = h_est_fft(obj.M+1:obj.N_f-obj.M);
            end
            
        end
        
        function [h_est] = moving_average_channel_estimation(obj)
            %Applies moving average channel estimation
            
            % performs a refinement of the h_LS noisy channel estimate by a moving
            % average operation using a window of size 2*M+1
            
            h_est = zeros(obj.N_f,2);
            for n = [1, 2]
                for k = 0:obj.M-1
                    h_est(k+1,n) =  sum(obj.h_LS(1:k+obj.M+1,n))/(obj.M+1+k);
                end
                for k = obj.M:obj.N_f - obj.M-1
                    h_est(k+1,n) = sum(obj.h_LS(k-obj.M+1:k+obj.M+1,n))/(2*obj.M+1);
                end
                i = 0;
                for k = obj.N_f - obj.M: obj.N_f - 1
                    i = i + 1;
                    h_est(k+1,n) = sum(obj.h_LS(k+1-obj.M:obj.N_f,n))/(2*obj.M+1-i);
                end
            end
            
            
        end
        % -------------------------------------------------------------
        
    end % methods
end % class
