classdef SL_Discovery
    %SL_Discovery implements the functionalities of Sidelink Discovery
    %including resources allocation and transmit/physical channel processing
    % (1) Resources Allocation:
    %   - Compute subframe/PRB resource pools available for discovery announcement/monitoring
    %   - Compute subframe resources for sending/receiving broadcast/synchronization subframes
    %   - Compute UE-specific subframe/PRB resources for for discovery announcement/monitoring
    % (2) Transmit/physical channel processing
    %   - Generation of a random discovery transport block
    %   - Transport Channel Processing (tx/rx)
    %   - Physical Channel Processing (tx/rx)
    %   - Subframe Loading
    %   - Generation of PSCH DMRS sequences and loading in subframe
    %   - Estimated PSDCH decode quality
    %(For details about the input configuration properties look at the first set of class properties ("properties configured by class calling"))
    
    %Contributors: Antonis Gotsis (antonisgotsis)
    
    
    properties (SetAccess = public, GetAccess = public) % properties configured by class calling
        NSLRB;                    % 6,15,25,50,75,100: Sidelink bandwidth (default: 25)
        NSLID;                    % 0..335: Sidelink Cell-ID (default: 0)
        cp_Len_r12;               % 'Normal','Extended'. Part of SL-CP-Len belonging to DiscResource Pool (default 'Normal')
        syncOffsetIndicator;      % Offset indicator for sync subframe with respect to 0 subframe (default: 0)
        syncPeriod;               % Synchronization subframe period (in # subframes) (default: 40)
        discPeriod_r12;           % 4,7,8,14,16,28,32,64,128,256,512,1024 radio frames (Part of SL-DiscResourcePool: Indicates the period over which resources are allocated in a cell for discovery message transmission/reception, see PSDCH period in TS 36.213 [23]. Value in number of radio frames. Value rf32 corresponds to 32 radio frames, rf64 corresponds to 64 radio frames and so on. ENUMERATED {rf32, rf64, rf128, rf256, rf512, rf1024, rf16-v13x0, spare}) (default: 32)
        offsetIndicator_r12;      % 0..10239 (Part of SL-TF-ResourceConfig/SL-DiscResourcePool): The IE SL-OffsetIndicator indicates the offset of the pool of resources relative to SFN 0 of the cell from which it was obtained or, when out of coverage, relative to DFN 0.) (default: 0)
        subframeBitmap_r12;       % size 40 (Part of SL-TF-ResourceConfig: Indicates the subframe bitmap indicating resources used for sidelink. E-UTRAN configures value bs40 for FDD) (default: all-1s except for the 1st element)
        numRepetition_r12;        % 1..5 for FDD (Included in  SL-DiscResourcePool: Indicates the number of times subframeBitmap is repeated for mapping to subframes that occurs within a discPeriod. The highest value E-UTRAN uses is value 5 for FDD) (default: 5)
        prb_Start_r12;            % 0..99  : Part of SL-TF-ResourceConfig: Starting PRB index allocated to Discovery transmissions (default: 2)
        prb_End_r12;              % 0..99  : Part of SL-TF-ResourceConfig: Ending PRB index allocated to Discovery transmissions (default: 22)
        prb_Num_r12;              % 1..100 : Part of SL-TF-ResourceConfig: Number of PRBs allocated to each Discovery transmissions block.  Actual num is x2 (default: 10).
        numRetx_r12;              % 0..3 (Included in  SL-DiscResourcePool and determines the number of disc msg retransmissions in a period: NTX_SLD = numRetx_r12+1) (default: 3)
        networkControlledSyncTx;  % 0 for off, 1 for on: Part of RRCreconfiguration Msg (default: 1)
        syncTxPeriodic;           % 0 for off, 1 for on (fixed period = 40 ms): Part of SL-SyncConfig (default: 1)
        discType;                 % UE resource allocation type: 'Type1' or 'Type2B' (default : Type-1)
        n_PSDCHs;                 % type-1 only: selected UE resource index: one index per UE/message
        discPRB_Index;            % type-2 only: selected prb index: 1..50   (SL-DiscConfig (discTF_IndexList)) (default:1)
        discSF_Index;             % type-2 only: selected subframe index: 1..200  (SL-DiscConfig (discTF_IndexList)) (default:1)
        a_r12;                    % type-2 only: N1_PSDCH: 1..200 ((SL-HoppingConfig)) (default:1)
        b_r12;                    % type-2 only: N2_PSDCH: 1..10  (SL-HoppingConfig) (default:1)
        c_r12;                    % type-2 only: N3_PSDCH: n1,n5  (SL-HoppingConfig) (default:1)
        l_PSDCH_selected;         % UE-specific allocated subframes for current period
        m_PSDCH_selected;         % UE-specific allocated PRBs
    end
    
    
    properties (SetAccess = private) % properties configured throughout various class operations
        NFFT;                               % FFT size
        chanSRate;                          % channel sampling rate
        cpLen0;                             % CP length for the 0th symbol
        cpLenR;                             % CP length for all but 0th symbols
        NSLsymb;                            % Number of SL symbols per slot, depending on CPconf
        samples_per_subframe;               % number of samples per subframe
        l_PSDCH;                            % Location of PSDCH symbols per slot: all symbols except for one for DMRS
        l_PSDCH_DMRS;                       % 36.211, 5.5.2.1.2: location of DMRS: 3 for normal cp, 2 for extended cp
        Msc_PSDCH;                          % bandwidth of PSDCH in # subcarriers
        psdch_BitCapacity;                  % bit capacity of PSDCH channel
        b_scramb_seq;                       % generated scrambling Sequence in PSDCH processing (based on c_init)
        cmux;                               % PUSCH interleaver multiplier for SL-DCH processing
        muxintlv_indices;                   % generated PUSCH interleaver indices for SL-DCH processing
        psdch_dmrs_seq;                     % the psdch dmrs sequence
        DiscPer                             % discovery period: 2 elements (begin/end subframe)
        ls_PSDCH_RP                         % discovery time resource pool: subframes
        ms_PSDCH_RP                         % discovery frequency resource pool: PRBs
        Nt                                  % time resources size
        Nf                                  % frequency resources size
        NTX_SLD                             % number transmissions per discovery message
        subframes_SLSS;                     % subframes where SL-SS will be transmitted
        subframe_index;                     % actual subframe counter (0..10239) known for tx/ recovered from BCH decoding for Rx
    end
    
    properties (Hidden) % non-changeable properties
        Disc_subframeBitmapSize = 40;    % length of subframe bitmap (36.331)
        DiscMsg_PHY_NPRBs       = 2;     % # PRBs used for Transmitting each PHY Discovery Message per Transmission (36.213/14.3.1)
        NRBsc                   = 12;    % Resource block size in the frequency domain, expressed as a number of subcarriers
        c_init                  = 510;   % 36.211, 9.5.1: initializer for PSDCH scrambling sequence
        discMsg_TBsize          = 232;   % Bit-Msg Size --> 24.334 - Table 11.2.5.1.1: PC5_DISCOVERY message content for open ProSe direct discovery
    end
    
    methods
        
        function h = SL_Discovery(varargin)
            %Constructor & Initialization routine
            
            % --------------------------- base config inputs ---------------------------
            slBaseConfig = varargin{1};
            
            if isfield(slBaseConfig,'NSLRB')
                h.NSLRB = slBaseConfig.NSLRB;
            else % default
                h.NSLRB = 25;
            end
            assert(isequal(h.NSLRB,6) | isequal(h.NSLRB,15) | isequal(h.NSLRB,25) | isequal(h.NSLRB,50) | isequal(h.NSLRB,75) | isequal(h.NSLRB,100),'Invalid SL Bandwidth mode. Select from {6,15,25,50,75,100}');
            
            if isfield(slBaseConfig,'NSLID')
                h.NSLID = slBaseConfig.NSLID;
            else % default
                h.NSLID = 0;
            end
            assert(h.NSLID>=0 & h.NSLID<=335,'Invalid setting of NSLID. Valid range: 0..335');
            
            if isfield(slBaseConfig,'cp_Len_r12')
                h.cp_Len_r12 = slBaseConfig.cp_Len_r12;
            else % default
                h.cp_Len_r12 = 'Normal';
            end
            assert(isequal(h.cp_Len_r12,'Normal') | isequal(h.cp_Len_r12,'Extended'),'Invalid CP Length mode. Select from {Normal,Extended}');
            
            % --------------------------- sync config inputs ---------------------------
            slSyncConfig = varargin{2};
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
            assert(h.syncPeriod>=1 & h.syncPeriod<=40,'Invalid setting of Period. Valid range: 1..40');
            
            % --------------------------- disc config inputs ---------------------------
            % reflect SIB19/RRCReconfiguration IEs (36.331)
            slDiscConfig = varargin{3};
            
            if isfield(slDiscConfig,'discPeriod_r12') % update for Rel.13 where lower values for disc period are defined for the preconfigured mode
                h.discPeriod_r12 = slDiscConfig.discPeriod_r12;
            else % default
                h.discPeriod_r12 = 32;
            end
            
            assert(h.discPeriod_r12==4 | h.discPeriod_r12==7 | h.discPeriod_r12==8 | h.discPeriod_r12==14 | h.discPeriod_r12==16 | h.discPeriod_r12==28|...
                h.discPeriod_r12==32 | h.discPeriod_r12==64 | h.discPeriod_r12==128 | h.discPeriod_r12==256 | h.discPeriod_r12==512 | h.discPeriod_r12==1024,...
                'Invalid setting of discPeriod-r12. Valid values: 4,7,8,14,16,28,32,64,128,256,512,1024');
            
                
            if isfield(slDiscConfig,'offsetIndicator_r12')
                h.offsetIndicator_r12 = slDiscConfig.offsetIndicator_r12;
            else % default
                h.offsetIndicator_r12 = 0;
            end
            %assert(h.offsetIndicator_r12>=0 & h.offsetIndicator_r12+h.discPeriod_r12*10<=10239,'Invalid setting of offsetIndicator_r12. Check it against discPeriod_r12');
            
            if isfield(slDiscConfig,'subframeBitmap_r12')
                h.subframeBitmap_r12 = slDiscConfig.subframeBitmap_r12;
            else % default
                h.subframeBitmap_r12 = [0; ones(39,1)]; % all available except first subframe (used for broad/sync)
            end
            assert(length(h.subframeBitmap_r12)==h.Disc_subframeBitmapSize, 'Invalid subframeBitmap-r12 size. Valid value: 40');
            
            
            if isfield(slDiscConfig,'numRepetition_r12')
                h.numRepetition_r12 = slDiscConfig.numRepetition_r12;
            else % default
                h.numRepetition_r12 = 5;
            end
            assert(h.numRepetition_r12>=1 & h.numRepetition_r12<=5,'Invalid setting of numRepetition-r12. Valid range: 1..5');
            
            if isfield(slDiscConfig,'prb_Start_r12')
                h.prb_Start_r12 = slDiscConfig.prb_Start_r12;
            else % default
                h.prb_Start_r12 = 2;
            end
            assert(h.prb_Start_r12>=0 & h.prb_Start_r12<=99,'Invalid setting of prb_Start-r12. Valid range: 0..99');
            
            if isfield(slDiscConfig,'prb_End_r12')
                h.prb_End_r12 = slDiscConfig.prb_End_r12;
            else % default
                h.prb_End_r12 = 22;
            end
            assert(h.prb_End_r12>=0 & h.prb_End_r12<=99,'Invalid setting of prb_End_r12-r12. Valid range: 0..99');
            
            if isfield(slDiscConfig,'prb_Num_r12')
                h.prb_Num_r12 = slDiscConfig.prb_Num_r12;
            else % default
                h.prb_Num_r12 = 10;
            end
            assert(h.prb_Num_r12>=1 & h.prb_Num_r12<=100,'Invalid setting of prb_Num-r12. Valid range: 1..100');
            
            if isfield(slDiscConfig,'numRetx_r12')
                h.numRetx_r12 = slDiscConfig.numRetx_r12;
            else % default
                h.numRetx_r12 = 3;
            end
            assert(h.numRetx_r12>=0 & h.numRetx_r12<=3,'Invalid setting of numRetx-r12. Valid range: 0..3');
            
            if isfield(slDiscConfig,'discType')
                h.discType = slDiscConfig.discType;
            else % default
                h.discType = 'Type1';
            end
            assert(isequal(h.discType,'Type1') | isequal(h.discType,'Type2B'),'Invalid Discovery type. Select from {Type1,Type2B}');
            
            if isfield(slDiscConfig,'networkControlledSyncTx')
                h.networkControlledSyncTx = slDiscConfig.networkControlledSyncTx;
            else % default
                h.networkControlledSyncTx = 1;
            end
            assert(isequal(h.networkControlledSyncTx,0) |isequal(h.networkControlledSyncTx,1),'Invalid networkControlledSyncTx setting. Select from {0,1}');
            
            if isfield(slDiscConfig,'syncTxPeriodic')
                h.syncTxPeriodic = slDiscConfig.syncTxPeriodic;
            else % default
                h.syncTxPeriodic = 1;
            end
            assert(isequal(h.syncTxPeriodic,0) |isequal(h.syncTxPeriodic,1),'Invalid syncTxPeriodic setting. Select from {0,1}');
            
            
            % --------------------------- UE-specific disc config inputs ---------------------------
            if nargin == 4
                slUEconfig = varargin{4};
                if isequal(h.discType,'Type1')
                    if isfield(slUEconfig,'n_PSDCHs')
                        h.n_PSDCHs = slUEconfig.n_PSDCHs;
                    else % default
                        h.n_PSDCHs = [0];
                    end
                elseif isequal(h.discType,'Type2B')
                    if isfield(slUEconfig,'discPRB_Index')
                        h.discPRB_Index = slUEconfig.discPRB_Index;
                    else % default
                        h.discPRB_Index = [1];
                    end
                    
                    if isfield(slUEconfig,'discSF_Index')
                        h.discSF_Index = slUEconfig.discSF_Index;
                    else % default
                        h.discSF_Index = [1];
                    end
                    
                    if isfield(slUEconfig,'a_r12')
                        h.a_r12 = slUEconfig.a_r12;
                    else % default
                        h.a_r12 = [1];
                    end
                    
                    if isfield(slUEconfig,'b_r12')
                        h.b_r12 = slUEconfig.b_r12;
                    else % default
                        h.b_r12 = [1];
                    end
                    
                    if isfield(slUEconfig,'c_r12')
                        h.c_r12 = slUEconfig.c_r12;
                    else % default
                        h.c_r12 = [1];
                    end
                    
                end % Type1 or Type2B allocation
            end
            
            
            % 1) basic phy configuration: NFFT, chanSRate, cpLen0, cpLenR, NSLsymb, samples_per_subframe
            % 2) time-frequency resources dimensioning: data and pilot symbol positions
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
                h.l_PSDCH_DMRS = [3 10]'; % (36.211-9.8)
                h.l_PSDCH      = [0 1 2 4 5 6 7 8 9 11 12 13]'; % rest not allocated to dmrs
            elseif strcmp(h.cp_Len_r12,'Extended')
                h.cpLen0 = round(0.25*h.NFFT);
                h.cpLenR = round(0.25*h.NFFT);
                h.NSLsymb = 6;
                h.l_PSDCH_DMRS = [2 8]'; % (36.211-9.8)
                h.l_PSDCH      = [0 1 3 4 5 6 7 9 10 11]'; % rest not allocated to dmrs
            end
            h.samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
            
            % PSDCH Bit Capacity dimensioning considering resources for DMRS (2 symbs/subframes)
            h.Msc_PSDCH = h.DiscMsg_PHY_NPRBs*h.NRBsc;                  % bandwidth of PSDCH in # subcarriers
            h.psdch_BitCapacity = h.Msc_PSDCH * length(h.l_PSDCH) * 2;  % PSDCH subcarriers x Num of Symbols x 2 due to QPSK
            
            % Pre-generate scrambling sequence for PSDCH processing (36.211/9.5.1)
            h.b_scramb_seq = phy_goldseq_gen (h.psdch_BitCapacity, h.c_init); % generate scramb-seq: initialized at the start of each subframe with c_init = 510
            
            % scrambling sequence multiplier calculation: needed in pusch interleaving (36.212 5.2.2.7 / 5.2.2.8)
            h.cmux = 2*(h.NSLsymb-1);
            % indices needed for PUSCH interleaving (36.212 5.2.2.7 / 5.2.2.8)
            % Inputs: length of f0_seq, h.cmux for SL, 2 for QPSK, 1 for single-layer
            h.muxintlv_indices =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.psdch_BitCapacity, h.cmux, 2, 1 );
            
            % PSDCH DM-RS SEQUENCE GENERATION (36.211-9.8): notice that this is the same for all subframes so it can be precomputed
            % 1) create object, 2) get sequence.
            % Inputs:
            % Mode  : psdch
            % N_PRB : Number of PSDCH PRBs. It is fixed to DiscMsg_PHY_NPRBs = 2 (24 subcarriers)
            % We cannot yet map it to the grid because we don't know the exact UE-specific subscarriers
            h_psdch_dmrs = SL_DMRS(struct('Mode','psdch','N_PRB',h.DiscMsg_PHY_NPRBs));
            h.psdch_dmrs_seq = h_psdch_dmrs.DMRS_seq();
            
            % Extract discovery resource pool for given input configuration
            h = GetDiscResourcePool(h);
            
            % Determine synchronization subframes for given input configuration
            h = GetSyncResources (h); % output: h_slDisc.subframes_SLSS --> sync/broad
            
            % Extract UE-specific resource allocation
            h = GetResourcesPerUE (h);
            
        end % function: SL_Discovery
        
        function h = GetDiscResourcePool(h)
            %Extract discovery resource pool (non UE-specific for give input configuration (36.213 - 14.3.3)
            
            fprintf('=======================================================\n');
            fprintf('DISCOVERY RESOURCES POOL FORMATION: \n');
            fprintf('=======================================================\n');
            % Assume a single Discovery Period
            h.DiscPer = [h.offsetIndicator_r12, h.offsetIndicator_r12+h.discPeriod_r12*10-1];
            fprintf('Discovery Period #0 starts @ subframe #%i and ends at subframe #%i\n',h.DiscPer(1,1),h.DiscPer(1,2));
            
            % obtain subframe bitmap
            a = h.subframeBitmap_r12;
            NB = length(a);
            % consider repetitions
            Nprime = NB*h.numRepetition_r12;
            b = -ones(Nprime,1);
            b(:,1) = a(mod((0:Nprime-1),NB)+1,1);
            
            % subframe pool (0-based) offset not considered
            h.ls_PSDCH_RP = find(b==1) - 1;
            % add DiscPeriods(1,1) to h.ls_PSDCH for getting the actual subframe counter
            h.ls_PSDCH_RP = h.ls_PSDCH_RP + h.DiscPer(1,1);
            fprintf('Subframe pool (total %i subframes)\n',length(h.ls_PSDCH_RP));
            fprintf('( PSDCH Subframes : '); fprintf('%i ',h.ls_PSDCH_RP); fprintf(')\n');
            
            % RB pool (0-based)
            % PRB POOL FEASIBILITY checking and DEFINITION
            if h.prb_Start_r12 + h.prb_Num_r12 - 1 >= h.prb_End_r12 - h.prb_Num_r12 + 1 || h.prb_End_r12 >= h.NSLRB - 1
                fprintf('Error in PRB pool definition (bottom prb range = %i:%i, top prb range = %i:%i). Check prb_Start_r12, prb_Num_r12, prb_End_r12 \n',...
                    h.prb_Start_r12, h.prb_Start_r12 + h.prb_Num_r12 - 1, h.prb_End_r12 - h.prb_Num_r12 + 1,  h.prb_End_r12); keyboard
            else % ok to proceed
                h.ms_PSDCH_RP = [h.prb_Start_r12:h.prb_Start_r12 + h.prb_Num_r12 - 1, h.prb_End_r12 - h.prb_Num_r12 + 1: h.prb_End_r12]';
                fprintf('PRB pool (total %i PRBs): Bottom prb range = %i:%i, Top prb range = %i:%i\n',...
                    length(h.ms_PSDCH_RP),h.prb_Start_r12,h.prb_Start_r12 + h.prb_Num_r12 - 1,h.prb_End_r12 - h.prb_Num_r12 + 1, h.prb_End_r12);
            end
            
            % Mapping of resources: 14.3.1
            h.NTX_SLD = h.numRetx_r12+1;
            h.Nt = floor(length(h.ls_PSDCH_RP)/h.NTX_SLD);  % time-resource units for each tx (1 subframe per single tx)
            h.Nf = floor(length(h.ms_PSDCH_RP)/2);          % freq-resources (2 PRBs per tx)
            
            % info message
            fprintf('Discovery Pool formed: (%i,%i) (subframes,PRBs) per Disc Period (NTX_SLD = %i, NPRB = %i per Msg --> Nt = %i, Nf = %i)\n',...
                length(h.ls_PSDCH_RP), length(h.ms_PSDCH_RP), h.NTX_SLD, h.DiscMsg_PHY_NPRBs, h.Nt, h.Nf);
            
            
        end % function : GetDiscResourcePool
        
        function h = GetSyncResources (h)
            %Get subframe resources for transmitting/receiving SL-SSs (36.331 - 5.10.7.3)
            
            % initialization
            subframes_slSS_0 = [];
            
            if h.networkControlledSyncTx == 1
                discSubframes_0 = (h.DiscPer(1): h.DiscPer(2))';
                subframes_slSS_0 =  discSubframes_0(mod(discSubframes_0, h.syncPeriod) == h.syncOffsetIndicator);
                
                % check if the 1st SLSS subframe occurs in the 1st subframe of the pool.
                % If not move it to the previous closest subframe indicated by syncOffsetIndicator.(36.331, 5.10.7.3)
                while subframes_slSS_0(1) > h.ls_PSDCH_RP(1)
                    subframes_slSS_0 = subframes_slSS_0 - h.syncPeriod;
                end
                
                % non-periodic adjustment: keep first only
                if ~h.syncTxPeriodic, subframes_slSS_0 = subframes_slSS_0(1); end
                
                % check for conflict of SLSS and PSDCH
                for slssix = 1:length(subframes_slSS_0)
                    if ismember(subframes_slSS_0(slssix), h.ls_PSDCH_RP), fprintf('Check for possible SLSS and PSDCH conflict in subframe #%i\n', subframes_slSS_0(slssix)); end
                end
                
            end % syncConfig.networkControlledSyncTx
            fprintf('=======================================================\n');
            fprintf('( SLSS Subframes for Period #0 : '); fprintf('%i ', subframes_slSS_0); fprintf(')\n');
            
            % now assign for all potential periods in a full SFN cycle subframes = 0..10239)
            N_slss_periods = 10240/length(discSubframes_0); %period #0 already set
            subframes_slSS = [subframes_slSS_0];
            for i=1:N_slss_periods-1
                subframes_slSS = [subframes_slSS; subframes_slSS_0 + i*length(discSubframes_0)];
            end
            h.subframes_SLSS = subframes_slSS;
            
        end % function : GetSyncResources
        
        function h = GetResourcesPerUE (varargin)
            
            % Calculations are done for Period #0. Finally adjustment for
            % actual Period is made.
            %Extract UE-specific resource allocation (36.213 - 14.3.1)
            
            %fprintf('=======================================================\n');
            %fprintf('UE-based PSDCH Resource Allocation \n');
            %fprintf('=======================================================\n');
            
            h = varargin{1};
            
            if isequal(h.discType,'Type1')
                %fprintf('Discovery Type1.\n');
                
                num_of_msgs = length(h.n_PSDCHs);
                ms   = cell(num_of_msgs,h.NTX_SLD);         % selected PRBs for each tx
                ls   = -ones(num_of_msgs,h.NTX_SLD);        % selected subframe for each tx
                
                for i=0:num_of_msgs-1
                    n_PSDCH = h.n_PSDCHs(i+1);
                    fprintf('D2D Discovery Resource Index (n_PSDCH): %i\n',n_PSDCH);
                    assert(n_PSDCH>=0 & n_PSDCH<=h.Nt*h.Nf-1,'Invalid setting of n_PSDCH. Valid range: 0..h.Nt*h.Nf - 1');
                    
                    for j = 1:h.NTX_SLD
                        b1_i = mod(n_PSDCH,h.Nt);
                        a_ij = mod( (j-1)*floor(h.Nf/h.NTX_SLD) + floor(n_PSDCH/h.Nt) , h.Nf);
                        l_ij = h.NTX_SLD*b1_i + j - 1;
                        
                        ms{i+1,j}   = [h.ms_PSDCH_RP(2*a_ij+1),h.ms_PSDCH_RP(2*a_ij+1+1)];
                        ls(i+1,j)   = h.ls_PSDCH_RP(l_ij+1);
                        
                        % info messages
                        %fprintf('D2D Discovery Resource Index (n_PSDCH): %i\n',n_PSDCH);
                        %fprintf('\tIn Transmission %i/%i: ',j,h.NTX_SLD);
                        %fprintf('\tSelected PRBs: [%2i,%2i], ', ms{i+1,j}(1),ms{i+1,j}(2));
                        %fprintf('Selected Subframe: [%3i] \n',ls(i+1,j));
                    end % all re-tx per msg
                end % all msgs
                
            elseif isequal(h.discType,'Type2B')
                
                %fprintf('Discovery Type1.\n');
                num_of_msgs = length(allocInfo.discPRB_Index);
                ms   = cell(num_of_msgs,h.NTX_SLD);         % selected PRBs for each tx
                ls   = -ones(num_of_msgs,h.NTX_SLD);        % selected subframes for each tx
                
                for i=0:num_of_msgs-1
                    fprintf('D2D Discovery Mesage Config %i/%i\n',i+1,num_of_msgs);
                    
                    assert(h.discPRB_Index(i+1)>=1 & h.discPRB_Index(i+1)<=50,'Invalid setting of discPRB-Index. Valid range: 1..50');
                    assert(h.discSF_Index(i+1)>=1 & h.discSF_Index(i+1)<=200,'Invalid setting of discSF-Index. Valid range: 1..200');
                    assert(h.a_r12(i+1)>=1 & h.a_r12(i+1)<=200,'Invalid setting of a-r12 (NPSDCH_1). Valid range: 1..200');
                    assert(h.b_r12(i+1)>=1 & h.b_r12(i+1)<=50, 'Invalid setting of b-r12 (NPSDCH_2). Valid range: 1..50');
                    assert(h.c_r12(i+1)==1,'Invalid setting of c-r12 (NPSDCH_3). Valid range: {1}');
                    
                    nprime = 0; % number of periods since NPDSCH_2 was received
                    
                    alphas(h.NTX_SLD+1,1) = 0;
                    betas(h.NTX_SLD+1,1) = 0;
                    
                    % init
                    alphas(1,1) = h.discPRB_Index(i+1);
                    betas(1,1) = h.discSF_Index(i+1);
                    
                    % rest
                    for j = 1:h.NTX_SLD
                        if j == 1
                            alphas(j+1,1) = mod ( mod(h.b_r12(i+1)+nprime,10) + floor( (alphas(j,1) + h.Nf*betas(j,1) )/h.Nt ) , h.Nf );
                        elseif j>1
                            alphas(j+1,1) = mod ( (j-1)*floor(h.Nf/h.NTX_SLD) + alphas(2,1) , h.Nf );
                        end
                        
                        betas(j+1,1) = mod ( h.a_r12(i+1) + h.c_r12(i+1)*alphas(1,1) + h.Nf*betas(1,1) , h.Nt );
                        l_ij = h.NTX_SLD*betas(j+1,1) + j - 1;
                        
                        ms{1,j}   = [h.ms_PSDCH_RP(2*alphas(j+1,1)+1),h.ms_PSDCH_RP(2*alphas(j+1,1)+1+1)];
                        ls(1,j)   = h.ls_PSDCH_RP(l_ij+1);
                        
                        % info msgs
                        %fprintf('\tIn Transmission %i/%i : ',j,h.NTX_SLD);
                        %fprintf('\tSelected PRBs: [%3i,%3i], ', m_PSDCH_selected{1,j}(1),m_PSDCH_selected{1,j}(2));
                        %fprintf('Selected Subframe (within period): [%3i] \n',l_PSDCH_selected(1,j));
                    end % re-tx of current msg
                end % num of msgs
                
            end % discovery type
            
            if nargin ==1
                h.l_PSDCH_selected = ls;
            elseif nargin == 2
                period_ix = varargin{2};
                h.l_PSDCH_selected = ls + period_ix*h.discPeriod_r12*10;
            end
            h.m_PSDCH_selected = ms;
            
        end % function: GetResourcesPerUE
        
        function output_seq = GenerateDiscoveryTB(varargin)
            %Create dummy DISCOVERY Transport Block, identical to MAC PDU: 24.334 - Table 11.2.5.1.1
            % Inputs: object (h) and an (optional) seed.
            h = varargin{1};
            if nargin == 2
                rng(varargin{2}); % fix seed
            end
            output_seq = randi([0,1], h.discMsg_TBsize, 1); % dummy message
            
        end
        
        function [output_seq, d_seq] = SL_DCH_PSDCH_Encode(h, input_seq)
            %Sidelink DCH Transport/Physical Channel Tx Processing: SL_DCH (36.212 - 5.4.4 & 5.3.2) & PSDCH (36.211 - 9.5)
            
            % input : discovery TB
            % output: symbol-sequence at the output of psdch encoder and pre-precoder output
            
            % 36.212 - 5.3.2.1	Transport block CRC attachment
            a_seq = input_seq;
            [ b_seq ] = tran_crc24A( a_seq,  'encode');
            
            % 36.212 - 5.3.2.3	Channel coding
            c_seq = b_seq;
            d0_seq =  tran_turbo_coding(c_seq, 0);
            
            % 36.212 - 5.3.2.4	Rate matching
            e0_seq = tran_turbo_ratematch( d0_seq, h.psdch_BitCapacity, 0, 'encode' );
            
            % dummy assignment to follow 36.212 standard notation
            f0_seq = e0_seq;
            
            % 36.212 5.2.2.7 / 5.2.2.8 PUSCH Interleaving without any control information
            g0_seq = f0_seq(h.muxintlv_indices);
            
            % phy processing initialization
            b_seq = g0_seq;
            
            % 36.211 - 9.5.1	Scrambling
            b_seq_tilde = mod(b_seq + h.b_scramb_seq, 2);
            
            % 36.211 - 9.5.2	Modulation:
            d_seq = phy_modulate(b_seq_tilde, 'QPSK');
            
            % 36.211 - 9.5.3 Layer Mapping
            x_seq = d_seq; % Single-Antenna Port
            
            % 36.211 - 9.5.4 Transform Precoding
            y_seq = phy_transform_precoding(x_seq,h.Msc_PSDCH);
            
            % returned sequence
            output_seq = y_seq;
            
        end % function SL_DCH_PSDCH_Encode
        
        function [output_seq, CRCerror_flg, d_seq_rec] = SL_DCH_PSDCH_Recover(h, input_seq, decodingType)
            %Sidelink DCH Transport/Physical Channel Rx Processing: SL_DCH (36.212 - 5.4.4 & 5.3.2) & PSDCH (36.211 - 9.5)
            
            % Inputs:
            %   h : System Object
            %   input_seq: extracted PSDCH symbol sequence from grid
            %   decodingType: 'Hard', 'Soft'
            % Outputs:
            %   output_seq   : recovered TB
            %   CRCerror_flg : crc error detection flag
            %   d_seq_rec    : symbol sequence at the input of QPSK demodulator (the output of transform precoder)
            
            % 36.211 - 9.5.4 Transform De-Precoding
            x_seq_rec = phy_transform_deprecoding(input_seq, h.Msc_PSDCH);
            
            % 36.211 - 9.5.3 Layer De-Mapping
            d_seq_rec = x_seq_rec;
            
            %  36.211 - 9.5.2 Demodulation
            if isequal(decodingType,'Hard')
                b_seq_tilde_rec = phy_demodulate(d_seq_rec,'QPSK');
            elseif isequal(decodingType,'Soft')
                b_seq_tilde_rec = phy_symbolsTosoftbits_qpsk( d_seq_rec );
            end
            
            %  36.211 - 9.5.1	Descrambling
            if isequal(decodingType,'Hard')
                b_seq_rec = mod(b_seq_tilde_rec + h.b_scramb_seq, 2); % hard descramble
            elseif isequal(decodingType,'Soft')
                b_scramb_seq_soft = -(2*h.b_scramb_seq-1);            % transform it to soft version (bit 0 --> +1, bit 1 --> -1)
                b_seq_rec = b_seq_tilde_rec.*b_scramb_seq_soft;       % soft scrambling
            end
            
            % PHY processing completion
            psdch_output_recovered = b_seq_rec;
            
            % 36.212 5.2.2.7 / 5.2.2.8 PUSCH De-Interleaving without any control information
            f0_seq_rec = -1000*ones(length(psdch_output_recovered),1);
            f0_seq_rec(h.muxintlv_indices) = psdch_output_recovered;
            
            % dummy assignment to follow 36.211 standard notation
            e0_seq_rec = f0_seq_rec;
            
            % 36.211 - 5.3.2.4	Rate matching Recovery
            d0_seq_rec = tran_turbo_ratematch( e0_seq_rec, 3*(h.discMsg_TBsize+24)+12, 0, 'recover' );
            
            % 5.3.2.3	Channel decoding
            c_seq_rec  = tran_turbo_coding (double(d0_seq_rec), 1);
            
            % 5.3.2.1	Transport block CRC recovery
            b_seq_rec = double(c_seq_rec);
            [ a_seq_rec, CRCerror_flg ] = tran_crc24A( b_seq_rec, 'recover' );
            
            % returned vector
            output_seq = a_seq_rec;
        end % SL_DCH_PSDCH_Recover
        
        function [output_seq] = CreateSubframe (h, subframe_counter)
            %Create a discovery subframe for given subframe index
            
            persistent x;
            if isempty(x)
                x = 0;
            end
            
            h.subframe_index = subframe_counter; % timing
            
            fprintf('\nCreating discovery subframe for subframe %i...\n',subframe_counter);
            % locate message(s) scheduled for current subframe (it could be zero, one or more than one)
            % msgIndices: the distinct msg id
            % txIndices : transmission opportunity of specific msg
            [msgIndices,txIndices] = find(subframe_counter==h.l_PSDCH_selected);
            
            % create subframe
            tx_output_grid = complex(zeros(h.NSLRB*h.NRBsc,2*h.NSLsymb));
            % prepare each message and append to subframe
            for ix = 1:length(msgIndices)
                % assigned prbs for current msg/tx opportunity
                current_prbs = h.m_PSDCH_selected{ix,txIndices(ix)};
                fprintf('\tLoading Message for n_PSDCH = %3i, transmission %i/%i ',h.n_PSDCHs(msgIndices(ix)),txIndices(ix),size(h.l_PSDCH_selected,2));
                fprintf('( PRBs: '); fprintf('%i ', current_prbs(:)); fprintf(')\n');
                % Ggenerate a random discovery TB (the 2nd argument is optional. it used for setting a fixed seed)
                discTB = GenerateDiscoveryTB(h, subframe_counter);
                % transport and physical channel processing --> psdch sequence
                psdch_output = SL_DCH_PSDCH_Encode(h, discTB);
                % map psdch sequence to grid
                psdch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.l_PSDCH, prbsTosubs(current_prbs(:), h.NRBsc), psdch_output);
                % map psdch-drms sequence to grid (the sequence has been pre-computed in the constructor)
                psdch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.l_PSDCH_DMRS, prbsTosubs(current_prbs(:), h.NRBsc), h.psdch_dmrs_seq);
                % add payload + dmrs
                tx_output_grid_current = psdch_grid + psdch_dmrs_grid;
                % add to total grid
                tx_output_grid = tx_output_grid +  tx_output_grid_current;
                % time-domain transformation: in standard-compliant sidelink waveforms the last symbol shoul be zeroed. This is not done here.
                tx_output = phy_ofdm_modulate_per_subframe(struct(h), tx_output_grid);
                % visually illustrate resource mapping
                % visual_subframeGridGraphic(tx_output_grid);
            end % all messages
            
            % return sequence
            output_seq = tx_output;
            
        end % function : CreateSubframe
        
        function  discovered_msgs = DiscoveryMonitoring(h, input_seq, subframe_counter, rxConfig)
            %Searches for discovery messages in input_seq waveform samples
            %based on given configuration in h at a specific subframe.
            
            discovered_msgs = []; % stores discovered messages. each element is a struct containing subframe counter, nPSDCH and the message
            
            % based on discovery configuration look for potential messages
            [msgIndices,txIndices] = find(subframe_counter==h.l_PSDCH_selected);
            
            for ix = 1:length(msgIndices)
                % msg info
                current_prbs = h.m_PSDCH_selected{ix,txIndices(ix)};
                nPSDCH       = h.n_PSDCHs(msgIndices(ix));
                % recovery processing
                % ofdm demodulation
                rx_input_grid   = phy_ofdm_demodulate_per_subframe(struct(h), input_seq);
                % equalization
                ce_params = struct('Method',rxConfig.chanEstMethod, 'fd',rxConfig.timeVarFactor*(1/h.chanSRate),...
                    'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',h.Msc_PSDCH,'NSLsymb',h.NSLsymb,'l_DMRS',h.l_PSDCH_DMRS);
                
                psdch_rx_posteq = phy_equalizer(ce_params, h.psdch_dmrs_seq, h.l_PSDCH, prbsTosubs(current_prbs(:), h.NRBsc), rx_input_grid);
                % transport and physical channel processing
                [msg, crcerr, psdch_dseq_rx] = SL_DCH_PSDCH_Recover(h, psdch_rx_posteq, rxConfig.decodingType);
                % check recovery result
                if (crcerr==0 && ~all(msg==0))
                    fprintf('\t[At Subframe %5i: Found nPSDCH = %3i, CRC Err Flg = %i]\n', subframe_counter, nPSDCH, crcerr);
                    DecodeQualEstimate (h, msg, psdch_dseq_rx);
                    discovered_msgs = [discovered_msgs; struct('subframe_counter',subframe_counter,'nPSDCH',nPSDCH, 'msg',msg)];
                end
            end % all mgs
            
        end % function : DiscoveryMonitoring
        
        function DecodeQualEstimate (h, decoded_bit_seq, recovered_qpskin_seq)
            %PSDCH decode quality estimation
            persistent x r; % x is used for storing ideal regenerated sequences, r for the received.
            
            % measure decode quality
            % regenerate psbch output
            [~, dseq_tx_regen] = SL_DCH_PSDCH_Encode(h, decoded_bit_seq);
            % received and ideal seqs
            x = [x; recovered_qpskin_seq];
            r = [r; dseq_tx_regen];
            
            % metrics computation
            % CUMULATIVE
            postEqualisedEVM_rms=sqrt(mean(abs((x-r)/sqrt(mean(abs(r.^2)))).^2));
            bitseq_Tx = lteSymbolDemodulate(r,'QPSK','Hard');
            bitseq_Rx = lteSymbolDemodulate(x,'QPSK','Hard');
            fprintf('PSDCH Decoding Qual Evaluation [CUMULATIVE Stats]: Bit Errors = %i/%i (BER = %.4f), SNR approx (dB) = %.3f\n', ...
                sum(bitseq_Tx~=bitseq_Rx), length(bitseq_Rx), sum(bitseq_Tx~=bitseq_Rx)/length(bitseq_Rx), 10*log10(1/(postEqualisedEVM_rms^2)));%
            % INSTANCE
            %             postEqualisedEVM_rms_instance=sqrt(mean(abs((recovered_qpskin_seq-dseq_tx_regen)/sqrt(mean(abs(dseq_tx_regen.^2)))).^2));
            %             bitseq_Tx_instance = lteSymbolDemodulate(dseq_tx_regen,'QPSK','Hard');
            %             bitseq_Rx_instance = lteSymbolDemodulate(recovered_qpskin_seq,'QPSK','Hard');
            %             fprintf('PSDCH Decoding Qual Evaluation [INSTANCE Stats]: Bit Errors = %i/%i (BER = %.4f), SNR approx (dB) = %.3f\n', ...
            %                 sum(bitseq_Tx_instance~=bitseq_Rx_instance), length(bitseq_Rx_instance), sum(bitseq_Tx_instance~=bitseq_Rx_instance)/length(bitseq_Rx_instance), 10*log10(1/(postEqualisedEVM_rms_instance^2)));
        end % function : DecodeQualEstimate
        
        
    end % methods
end % class

