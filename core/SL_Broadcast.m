classdef SL_Broadcast
    %SL_BROADCAST implements the functionalities of Sidelink Broadcast including:
    %- MIB-SL generation
    %- Transport channel processing (Tx/Rx)
    %- Physical channel processing (Tx/Rx)
    %- Demodulation reference signals generation. 
    %(Syncrhonization preambles signals and operations are defined in another class).
    %The following input fields are allowed (if not set, default values are used.)
    %   cp_Len_r12          (default is 'Normal')
    %   NSLRB               (default is 25)
    %   NSLID               (default is 0)
    %   slMode              (default is 1)
    %   syncGrid            (time-frequency grid pre-loaded with sync preambles)   
    %Contributors: Antonis Gotsis (antonisgotsis)

    properties (SetAccess = protected, GetAccess = public) % properties configured by class calling
        cp_Len_r12;                         % CP configuration: 'Normal' or 'Extended'.
        NSLRB;                              % Sidelink bandwidth (sl-bandwidth) (transmitted in MIB-SL): This is transmitted in ul-bandwidth (SIB2).
        NSLID;                              % Sidelink Cell-ID (slssid).
        slMode;                             % Sidelink Mode (1, 2, 3 or 4). For SL-BCH 1 is equivalent with 2 and 3 is equivalent with 4.
    end
            
    properties (SetAccess = private)            
        NFFT;                               % FFT size
        cpLen0;                             % CP length for the 0th symbol
        cpLenR;                             % CP length for all but 0th symbols
        chanSRate;                          % channel sampling rate    
        samples_per_subframe;               % number of samples per subframe
        SLMIBs                              % 2D array where each column contains the MIB-SL bit message for a subframe within the 0..10239 range
        l_PSBCH;                            % symbol positions within subframe carrying PSBCH
        psbch_BitCapacity;                  % bit capacity of PSBCH channel
        l_PSBCH_DMRS;                       % symbol positions within subframe carrying PSBCH DMRS
        psbch_dmrs_seq;                     % the psbch dmrs sequence
        psbch_drms_seq_grid;                % the psbch drms sequence mapped to the grid        
        base_grid;                          % base grid including pilots and sync preambles (if provided)
        subixs_PSBCH;                       % (0-based) indices of PSBCH subcarriers
        subframe_index;                     % actual subframe counter (0..10239) known for tx/ recovered from BCH decoding for Rx
    end
    
    properties (Hidden) % non-changeable properties
        Msc_PSBCH = 72;                     % bandwidth of PSBCH in number of subcarriers
        NRBsc = 12;                         % Resource block size in the frequency domain, expressed as a number of subcarriers
        NSLsymb;                            % Number of SL symbols per slot, depending on CPconf
        slBWmodes = [6 15 25 50 75 100];    % acceptable SL bandwidth modes        
        MIBSL_size = 40;                    % size of MIB-SL message
        cmux;                               % PUSCH interleaver multiplier for SL-BCH processing
        muxintlv_indices;                   % PUSCH interleaver indices for SL-BCH processing
        b_scramb_seq;                       % Scrambling Sequence in PSBCH processing
    end
    
    methods
        
       
        function h = SL_Broadcast(varargin)
             %Constructor & Initialization routine
            
            % broadcast config inputs
            slBroadConfig = varargin{1};
            
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
 
            
            % if provided set synchronization grid
            if nargin == 2
                 syncGrid = varargin{2};
            end
            
            % 1) basic phy configuration: NFFT, chanSRate, cpLen0, cpLenR, NSLsymb, samples_per_subframe 
            % 2) time-frequency resources dimensioning: 
            %   l_PSBCH: Exact symbols carrying PSBCH while accounting for dm-rs, ss (guard is included!)
            %   l_PSBCH_DMRS: demodulation reference signals
            switch h.NSLRB
                case 6,   h.NFFT = 128;  h.chanSRate = 1.92e6;
                case 15,  h.NFFT = 256;  h.chanSRate = 3.84e6;
                case 25,  h.NFFT = 512;  h.chanSRate = 7.68e6;
                case 50,  h.NFFT = 1024; h.chanSRate = 15.36e6;
                case 75,  h.NFFT = 1536; h.chanSRate = 23.04e6;
                case 100, h.NFFT = 2048; h.chanSRate = 30.72e6;
            end
            if strcmp(h.cp_Len_r12,'Normal')
                h.NSLsymb = 7; 
                h.cpLen0 = round(0.0781*h.NFFT);  
                h.cpLenR = round(0.0703*h.NFFT);                
                if h.slMode == 1 || h.slMode == 2
                    h.l_PSBCH = [0 4 5 6 7 8 9 13]';
                    h.l_PSBCH_DMRS = [3 10]';
                elseif h.slMode == 3 || h.slMode == 4
                    h.l_PSBCH = [0 3 5 7 8 10 13]';
                    h.l_PSBCH_DMRS = [4 6 9]';                    
                end
            elseif strcmp(h.cp_Len_r12,'Extended')
                h.NSLsymb = 6; 
                h.cpLen0 = round(0.25*h.NFFT);
                h.cpLenR = round(0.25*h.NFFT);
                if h.slMode == 1 || h.slMode == 2
                    h.l_PSBCH = [3 4 5 6 7 11]';
                    h.l_PSBCH_DMRS = [2 8]';
                elseif h.slMode == 3 || h.slMode == 4
                    error('Combination of Extended CP and SL Mode 3 or 4 (V2V) configuration not suppported.');                    
                end
            end
            h.samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
    
            % PSBCH subcarrier resources: central 72 subcarriers are allocated
            h.subixs_PSBCH = (0:1:71)' - 36 +  h.NRBsc*h.NSLRB/2;

            % PSBCH Bit Capacity considering resources for DMRS (2 symbs/subframes) and SS (4 symbs/subframe)
            h.psbch_BitCapacity = h.Msc_PSBCH * length(h.l_PSBCH) * 2; % PSBCH subcarriers x Num of Symbols x 2 due to QPSK
            
            % PSBCH DM-RS SEQUENCE: notice that this is the same for all subframes so it can be precomputed
            % 1) create object, 2) get sequence, 3)  map to time-frequency grid
            % Inputs: 
            % Mode  : 'psbch_d2d' for D2D, 'psbch_v2x'
            % NSLID : sidelink PCI
            % N_PRB : Number of PBCH PRBs is fixed to 6 (72 subcarriers)
            if h.slMode==1 || h.slMode==2, SidelinkMode='D2D';
            elseif h.slMode==3 || h.slMode==4, SidelinkMode='V2X';
            end
            h_psbch_dmrs = SL_DMRS(struct('Mode',strcat('psbch_',SidelinkMode),'NSLID',h.NSLID,'N_PRB',h.Msc_PSBCH/h.NRBsc));
            h.psbch_dmrs_seq = h_psbch_dmrs.DMRS_seq();
            h.psbch_drms_seq_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.l_PSBCH_DMRS, h.subixs_PSBCH, h.psbch_dmrs_seq);
            
            % mtlb toolbox comparison            
            %[seq,info] = ltePSBCHDRS(struct('NSLID',h.NSLID,'SidelinkMode',SidelinkMode));
            %psbchDMRS_ft_mtlb_ok = sum(abs(h.psbch_dmrs_seq-seq).^2)<1e-8
            %if ~psbchDMRS_ft_mtlb_ok, cprintf('red','PSBCH DMRS Generation: error in comparison with matlab toolbox\n'); keyboard; end
            
            % create the MIB-SL messages for all subframes in a full tx
            % cycle (10240 subframes). Results stored in property h.SLMIBs
            h.SLMIBs = Encode_SLMIBs(h);
            
            % initialization for physical and transport channel processing
            % scrambling sequence for PSBCH processing: initialized at the
            % start of each subframe with c_init = NSLID (36.211 9.6.1)
            h.b_scramb_seq = phy_goldseq_gen (h.psbch_BitCapacity, h.NSLID);
            % scrambling sequence multiplier calculation, will be needed in
            % pusch interleaving (36.212 5.2.2.7 / 5.2.2.8)
            if h.slMode == 1 || h.slMode == 2
                h.cmux = 2*(h.NSLsymb-3);
            elseif h.slMode == 3 || h.slMode == 4
                h.cmux = 2*(h.NSLsymb-2)-3;
            end
            % indices needed for PUSCH interleaving (36.212 5.2.2.7 / 5.2.2.8)
            % Inputs: length of f0_seq, h.cmux for SL, 2 for QPSK, 1 for single-layer            
            h.muxintlv_indices =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.psbch_BitCapacity, h.cmux, 2, 1 );   
            
            % Create Base Grid
            if nargin==1 % no dmrs
                h.base_grid = h.psbch_drms_seq_grid;              
            elseif nargin==2 % drms
                h.base_grid = h.psbch_drms_seq_grid  + syncGrid;
            end
            
        end % function: SL_Broadcast
        
        function encoded_mibs = Encode_SLMIBs(h)
            %Create MIB-SL messages (36.331, 6.5.2)    
        
            encoded_mibs = zeros(h.MIBSL_size, 10240);
            
            % common fields accross all messages
            mibsl_bitmsg = zeros(h.MIBSL_size,1);                       
            sl_Bandwidth_r12_int = find(h.slBWmodes==h.NSLRB)-1;                     % 0-based indexing
            mibsl_bitmsg(1:3,1)   = decTobit(sl_Bandwidth_r12_int,3,true);           % sl-Bandwidth-r12: ENUMERATED {n6, n15, n25, n50, n75, n100} --> 3 bits
            mibsl_bitmsg(4:6,1)   = zeros(3,1);                                      % tdd-ConfigSL-r12 (not used) --> 3 bits
            mibsl_bitmsg(21,1)    = 0;                                               % inCoverage-r12 BOOLEAN --> 1 bit
            mibsl_bitmsg(22:end,1) = zeros(19,1);                                    % reserved-r12	BIT STRING (SIZE (19)) --> 19 bits
            
            % fields changing every subframe: actual subframe counter = 10*directFrameNumber-r12 + directSubframeNumber-r12
            mibsl_bitmsg(7:16,1)  = zeros(10,1);                                     % directFrameNumber-r12 BIT STRING (SIZE (10)) --> 10 bits
            mibsl_bitmsg(17:20,1) = zeros(4,1);                                      % directSubframeNumber-r12 INTEGER (0..9) --> 4 bits
            
            for sfix = 0:10239
                % direct frame number (0..1023)
                mibsl_bitmsg(7:16,1) =  decTobit(floor(sfix/10),10,true);
                % direct subframe number (0..9)
                mibsl_bitmsg(17:20,1) = decTobit(mod(sfix,10),4,true);
                % assign
                encoded_mibs(:,sfix+1) = mibsl_bitmsg;
            end
            
        end % function: Encode_SLMIBs
        
        function [NSLRB_r, directFrameNumber_r12, directSubframeNumber_r12]  = Readout_SLMIB(h, mibsl_bitmsg)
            %Readout contents from a recovered MIB-SL (36.331, 6.5.2)
            
            % Input: MIB-SL bit message
            if length(mibsl_bitmsg) ~= h.MIBSL_size, error('Wrong MIB-SL message'); end
            
            % unpack message
            NSLRB_r = h.slBWmodes(bitTodec(mibsl_bitmsg(1:3,1),true) + 1); % +1 due to 0-based indexing
            directFrameNumber_r12 = bitTodec(mibsl_bitmsg(7:16,1),true);
            directSubframeNumber_r12 = bitTodec(mibsl_bitmsg(17:20,1),true);
            
            % validate NSLRB decoding
            if ~isequal(NSLRB_r, h.NSLRB), error('NSLRB mismatch. Check.\n'); end            
        end % function:Readout_SLMIB
        
        function [output_seq, d_seq] = SL_BCH_PSBCH_Encode(h, input_seq)
            %Sidelink BCH Transport/Physical Channel Tx Processing: SL_BCH (36.212/5.4.1) & PSBCH (36.211/9.6)
        
            % input : encoded bit-sequence (MIB-SL)
            % output: symbol-sequence at the output of psbch encoder and pre-precoder output
            
            % 36.212 5.4.1.1: Transport block CRC attachment
            a_seq = input_seq;
            b_seq = tran_crc16( a_seq, 'encode' );
            
            % 36.212 5.4.1.2: Channel coding
            c_seq = b_seq;
            d0_seq = tran_conv_coding(c_seq, 0); % block #0. Each input stream has length: length(c_seq). Output Length 3x(length(c_seq))
                        
            % 36.212 5.4.1.3 Rate Matching
            e0_seq = tran_conv_ratematch( d0_seq, h.psbch_BitCapacity, 'encode' );

            % dummy assignment to follow 36.212 standard notation
            f0_seq = e0_seq;    
                                   
            % 36.212 5.2.2.7 / 5.2.2.8 PUSCH Interleaving without any control information              
            g0_seq = f0_seq(h.muxintlv_indices);

            % mtlb toolbox comparison
            %cw = lteSLBCH(struct('SidelinkMode','V2X'), input_seq);
            %slbch_ft_mtlb_ok = isequal(double(g0_seq(:)),double(cw(:)));
            %if ~slbch_ft_mtlb_ok, cprintf('red','SL BCH Processing: error in comparison with matlab toolbox\n'); keyboard; end
            
            % phy processing initialization
            b_seq = g0_seq;
            
            % 36.211 9.6.1: Scrambling
            b_seq_tilde = mod(b_seq + h.b_scramb_seq, 2);
            
            % 36.211 9.6.2 : Modulation
            d_seq = phy_modulate(b_seq_tilde, 'QPSK');
            
            % 36.211 9.6.3 : Layer Mapping (Single-Antenna Port)
            x_seq = d_seq; 
            
            % 36.211 : 9.6.4 Transform Precoding    
            y_seq = phy_transform_precoding(x_seq,h.Msc_PSBCH);
            
            % mtlb toolbox comparison
            %pssch = ltePSBCH(struct('NSLID',h.NSLID), g0_seq);
            %psbch_ft_mtlb_ok = sum(abs(pssch-y_seq).^2)<1e-8
            %if ~psbch_ft_mtlb_ok, cprintf('red','PSBCH Processing: error in comparison with matlab toolbox\n'); keyboard; end
            
            % returned sequence
            output_seq = y_seq;
            
        end % SL_BCH_PSBCH_Encode

        function [output_seq, CRCerror_flg, d_seq_rec]  = SL_BCH_PSBCH_Recover(h, input_seq, decodingType, targetMsgSize)
            %Sidelink BCH Transport/Physical Channel Rx Processing: SL_BCH (36.212/5.4.1) & PSBCH (36.211/9.6)
            
            % Inputs:
            %   h : System Object
            %   input_seq: extracted PSBCH symbol sequence from grid
            %   decodingType: 'Hard', 'Soft'
            %   targetMsgSize: TB Size (for MIB this is fixed to 40)
            % Outputs:
            %   output_seq   : recovered TB
            %   CRCerror_flg : crc error detection flag
            %   d_seq_rec    : symbol sequence at the input of QPSK demodulator (the output of transform
            %   precoder)
           
            % 36.211 9.6.4 Transform De-Precoding     
            x_seq_rec = phy_transform_deprecoding(input_seq, h.Msc_PSBCH);
                    
            % 36.211 9.6.3 Layer De-Mapping (single-port)
            d_seq_rec = x_seq_rec; 
            
            % 36.211 9.6.2 Demodulation
            if isequal(decodingType,'Hard')            
                b_seq_tilde_rec = phy_demodulate(d_seq_rec,'QPSK');
            elseif isequal(decodingType,'Soft')            
                b_seq_tilde_rec = phy_symbolsTosoftbits_qpsk( d_seq_rec );
            end
            
            % 36.211 9.6.1 Descrambling
            if isequal(decodingType,'Hard')
                b_seq_rec = mod(b_seq_tilde_rec + h.b_scramb_seq, 2); % xor
            elseif isequal(decodingType,'Soft')                               
                b_scramb_seq_soft = -(2*h.b_scramb_seq-1); % transform it to soft version (bit 0 --> +1, bit 1 --> -1)
                b_seq_rec = b_seq_tilde_rec.*b_scramb_seq_soft; % soft scrambling
            end
            
            % PHY processing completion
            psbch_output_recovered = b_seq_rec;
            
            % 36.212 5.2.2.7 / 5.2.2.8 PUSCH De-Interleaving without any control information            
            f0_seq_rec = -1000*ones(length(psbch_output_recovered),1); 
            f0_seq_rec(h.muxintlv_indices) = psbch_output_recovered;
            
            % dummy assignment to follow standard notation
            e0_seq_rec = f0_seq_rec;
            
            % 36.212 5.4.1.3 Rate Matching Recovery
            d0_seq_rec = tran_conv_ratematch( e0_seq_rec, 3*(targetMsgSize+16), 'recover' );

            % 36.212 5.4.1.2	Channel decoding
            if isequal(decodingType,'Hard')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 1 );
            elseif isequal(decodingType,'Soft')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 2 ); 
            end                
            
            % 36.212 5.4.1.1	Transport block CRC recovery
            b_seq_rec = double(c_seq_rec);
            [ a_seq_rec, CRCerror_flg ] = tran_crc16( b_seq_rec, 'recover' );
            
            % returned vector
            output_seq = a_seq_rec;
        end %SL_BCH_PSBCH_Recover    
        
        function output_seq = CreateSubframe (h, subframe_counter)
            %Create a broadcast subframe
            h.subframe_index = subframe_counter;
            input_seq = h.SLMIBs(:,subframe_counter+1);
            
            % mtlb toolbox comparison
            %mibslout = lteSLMIB(struct('NSLRB',h.NSLRB,'NFrame',floor(subframe_counter/10),'NSubframe',mod(subframe_counter,10)));
            %mibsl_ft_mtlb_ok = isequal(double(input_seq(:)),double(mibslout(:)));
            %if ~mibsl_ft_mtlb_ok, cprintf('red','MIB SL message construction: error in comparison with matlab toolbox\n'); keyboard; end
            
            % transport and physical channel processing
            psbch_output = SL_BCH_PSBCH_Encode(h, input_seq);
            % map to grid
            psbch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.l_PSBCH, h.subixs_PSBCH, psbch_output);
            % add pre-calculated base grid (DMRS and SSS if provided)        
            tx_output_grid = psbch_grid + h.base_grid;
            % a visual representation of PSBCH grid : uncomment the following line
            % visual_subframeGridGraphic(tx_output_grid);
            % time-domain transformation: in standard-compliant sidelink
            % waveforms the last symbol shoul be zeroed. This is not done here.
            output_seq = phy_ofdm_modulate_per_subframe(struct(h), tx_output_grid); 
        end % CreateSubframe
        
        function [msgRecoveredFlag, h, psbch_dseq_rx] = RecoverSubframe (h, rx_config, input_seq)
            %Recover a broadcast Subframe
            
            % Inputs: h (object), chan_est_config (channel estimation configuration), input_seq (input time-domain waveform)
            % Outputs: msgRecoveredFlag (crc error detection flag), h
            % (object), psbch_dseq_rx (symbol sequence at the input of QPSK
            % demodulator, used for evaluating PSBCH decode quality)
            msgRecoveredFlag = false;

            % rx config parameters: 
            if ~isfield(rx_config,'decodingType'), rx_config.decodingType = 'Soft'; end
            if ~isfield(rx_config,'chanEstMethod'), rx_config.chanEstMethod = 'LS'; end
            if ~isfield(rx_config,'timeVarFactor'), rx_config.timeVarFactor = '0'; end
            
            ce_params = struct('Method',rx_config.chanEstMethod, 'fd',rx_config.timeVarFactor*(1/h.chanSRate),...
                'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',h.Msc_PSBCH,'NSLsymb',h.NSLsymb,'l_DMRS',h.l_PSBCH_DMRS);
            
            % go back to freq domain
            rx_input_grid = phy_ofdm_demodulate_per_subframe(struct(h), input_seq);
         
            % real channel pre-recovery operations: extraction of psbch sequence, channel estimation and channel equalization
            psbch_rx_posteq = phy_equalizer(ce_params, h.psbch_dmrs_seq, h.l_PSBCH, h.subixs_PSBCH, rx_input_grid);
            
            % perfect channel: you could use the following if no channel is induced instead
            % psbch_rx_posteq = phy_resources_demapper( h.l_PSBCH, h.subixs_PSBCH, rx_input_grid  );
            
            % physical and transport channel recovery processing
            [msg, crcerr, psbch_dseq_rx]  = SL_BCH_PSBCH_Recover(h, psbch_rx_posteq, rx_config.decodingType, h.MIBSL_size);
            
            % PSBCH recover output check
            if (crcerr==0 && ~all(msg==0))  % the 2nd argument is added because MATLAB CRC function may return a wrong all-0 message with valid crcerr
                msgRecoveredFlag = true;
                fprintf('Successfully Detected SL-BCH\n');
                % read-out SL-BCH information
                [nslrb, dframenum, dsubframenum] = Readout_SLMIB(h, msg);
                h.subframe_index = 10*dframenum+dsubframenum;
                fprintf('Read out MIB-SL: NSLRB = %i RBs, directFrameNumber_r12 = %i, directSubframeNumber_r12 = %i\n',nslrb,dframenum,dsubframenum);
                DecodeQualEstimate (h, msg, psbch_dseq_rx);
            else
                fprintf('Did not detect SL-BCH\n');
            end % PSBCH detection check
            
        end % function: recover broadcast subframe
         
        function DecodeQualEstimate (h, decoded_bit_seq, recovered_qpskin_seq)
            %PSBCH decode quality estimation
            
            % a function providing an estimation of decoding quality based
            % on the EVM metric measured at the output of transform
            % deprecoder (input of qpsk demodulator).
            % quality metrics definition
            persistent x r; % x is used for storing ideal regenerated sequences, r for the received.
   
            % measure decode quality
            % regenerate psbch output
            [~, psbch_dseq_tx_regen] = SL_BCH_PSBCH_Encode(h, decoded_bit_seq);
            % received and ideal seqs
            x = [x; recovered_qpskin_seq];
            r = [r; psbch_dseq_tx_regen];
            
            % metrics computation
            % CUMULATIVE
            postEqualisedEVM_rms=sqrt(mean(abs((x-r)/sqrt(mean(abs(r.^2)))).^2));
            psbch_bitseq_Tx = lteSymbolDemodulate(r,'QPSK','Hard');
            psbch_bitseq_Rx = lteSymbolDemodulate(x,'QPSK','Hard');
            fprintf('PSBCH Decoding Qual Evaluation [CUMULATIVE Stats]: Bit Errors = %i/%i (BER = %.4f), SNR approx (dB) = %.3f\n', ...
                sum(psbch_bitseq_Tx~=psbch_bitseq_Rx), length(psbch_bitseq_Rx), sum(psbch_bitseq_Tx~=psbch_bitseq_Rx)/length(psbch_bitseq_Rx), 10*log10(1/(postEqualisedEVM_rms^2)));%
            % INSTANCE
%             postEqualisedEVM_rms_instance=sqrt(mean(abs((recovered_qpskin_seq-psbch_dseq_tx_regen)/sqrt(mean(abs(psbch_dseq_tx_regen.^2)))).^2));
%             psbch_bitseq_Tx_instance = lteSymbolDemodulate(psbch_dseq_tx_regen,'QPSK','Hard');
%             psbch_bitseq_Rx_instance = lteSymbolDemodulate(recovered_qpskin_seq,'QPSK','Hard');
%             fprintf('PSBCH Decoding Qual Evaluation [INSTANCE Stats]: Bit Errors = %i/%i (BER = %.4f), SNR approx (dB) = %.3f\n', ...
%                 sum(psbch_bitseq_Tx_instance~=psbch_bitseq_Rx_instance), length(psbch_bitseq_Rx_instance), sum(psbch_bitseq_Tx_instance~=psbch_bitseq_Rx_instance)/length(psbch_bitseq_Rx_instance), 10*log10(1/(postEqualisedEVM_rms_instance^2)));
            
        
        end % function: DecodeQualEstimate
        
    end % class methods
    
end % class

