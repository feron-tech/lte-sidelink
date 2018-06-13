classdef SL_V2XCommunication
    %SL_V2XCommunication implements the functionalities of the sidelink v2x communication mode
    
    properties (SetAccess = public, GetAccess = public) % properties configured by class calling
        % base
        NSLRB;                    % 6,15,25,50,75,100: Sidelink bandwidth (default: 25)
        NSLID;                    % 0..335: Sidelink Cell-ID (default: 0)
        slMode                    % Sidelink Mode: 3 (V2V-scheduled) or 4 (V2V autonomous sensing)
        % sync-specific
        syncOffsetIndicator;      % Offset indicator for sync subframe with respect to 0 subframe (default: 0)
        syncTxPeriodic;           % 0 for off, 1 for on: Part of SL-SyncConfig (default: 1)
        syncPeriod=160;               % sync subframe period # subframes. Fixed to 160 for V2V.
        % v2x-pool
        sl_OffsetIndicator_r14;   % {0..10239} Indicates the offset of the first subframe of a resource pool
        sl_Subframe_r14;          % {16,20,100} : Determines PSSCH subframe pool: bitmap with acceptable sizes
        adjacencyPSCCH_PSSCH_r14; % {true,false}: Indicates if PSCCH and PSSCH are adjacent in the frequecy domain
        sizeSubchannel_r14;       % {n4, n5, n6, n8, n9, n10, n12, n15, n16, n18, n20, n25, n30, n48, n50, n72, n75, n96, n100}: Indicates the number of PRBs of each subchannel in the corresponding resource pool
        numSubchannel_r14;        % {n1, n3, n5, n10, n15, n20}: Indicates the number of subchannels in the corresponding resource pool
        startRB_Subchannel_r14;   % {0..99}: Indicates the lowest RB index of the subchannel with the lowest index:
        startRB_PSCCH_Pool_r14;   % {0..99} Indicates the lowest RB index of the PSCCH pool. This field is irrelevant if a UE always transmits control and data in adjacent RBs in the same subframe
        %
        sduSize;                  % In bits: length of MAC SDU size as coming from MAC
        % common for mode-3 and mode-4
        pssch_TBsize;             % PSSCH transport block size (based on mod-order and number of allocated PRBs)
        mcs_r14;                  % {0..31} (5 bits, here given in integer form) Indicates the MCS mode set through higher layers or selected autonously by the UE (default: 10)
        SFgap                     % Time gap between initial transmission and retransmission. Either set through DCI5A or Higher Layers or Preconfigured.
        LsubCH;                   % Number of allocated subchannels for user        
        % v2x mode-3 UE specific
        Linit;                    % 1st transmission opportunity frequency offset: from "Lowest index of the subchannel allocation to the initial transmission" --> ceil(log2(numSubchannel_r14) bits, here in integer form. Either set through DCI5A or Higher Layers or Preconfigured.
        nsubCHstart               % (relevant if SFgap not zero) 2nd transmission opportunity frequency offset: from "Frequency Resource Location of the initial transmission and retransmission" --> ceil(log2(numSubchannel_r14) bits, here in integer form.  This is actually configured using "RIV". Here we provide the corresponding subchannel directly. Either set through DCI5A (frl) or Higher Layers or Preconfigured.
        % v2x mode-4 UE specific        
    end
    
    properties (SetAccess = public) % properties configured throughout various class operations
        subframes_SLSS;                     % subframes where SL-SS will be transmitted
        subframes_Reserved;                 % reserved subframes (36.213, 14.1.5)
        ls_PSSCH_RP;                        % PSSCH Subframe Pool
        ls_PSCCH_RP;                        % PSCCH Subframe Pool
        ms_PSCCH_RP;                        % PSCCH Resource Blocks Pool
        ms_PSSCH_RP                         % PSSCH Resource Blocks Pool
        l_PSCCH_selected=[];                % UE-specific scheduled subframes for PSCCH
        m_PSCCH_selected=[];                % UE-specific scheduled PRBs for PSCCH
        frlbitmap_len;                      % length of v2x frequency resource location field bitmap used in SCI Format 1
        v2x_frlbitmap;                      % frl bitmap for v2x pscch/pssch
        l_PSSCH_selected=[];                % UE-specific scheduled subframes for PSSCH (identical to PSCCH)
        m_PSSCH_selected=[];                % UE-specific scheduled PRBs for PSSCH
        pssch_Qprime;                       % PSSCH transport block  modulation order
        Msc_PSSCH;                          % bandwidth of SL PSCCH in # subcarriers
        pssch_BitCapacity;                  % PSSCH Channel Bit Capacity
        pscch_BitCapacity;                  % PSCCH Channel Bit Capacity
        cmux;                               % multiplier for PUSCH/PSCCH Interleaving
        pscch_muxintlv_indices;             % PUSCH interleaver indices for transport channel processing : pscch
        pscch_b_scramb_seq;                 % PSCCH scrambling sequence
        pssch_muxintlv_indices;             % PUSCH interleaver indices for transport channel processing : pssch
        pscch_dmrs_seq;                     % PSCCH DMRS sequence
        
        NFFT;                               % FFT size
        chanSRate;                          % channel sampling rate
        cpLen0;                             % CP length for the 0th symbol
        cpLenR;                             % CP length for all but 0th symbols
        samples_per_subframe;               % number of samples per subframe
        
        N_RB_PSSCH=0;
        nXIDs = [];                         % calculated dynamically based on SCI. Multi-dimensional because of re-tx
        expectedSPSs=[];                    % auxiliary cell-array for decoding in SPS case (# rows = tx-op, #col-1: subframe index, #col-2: PRBs, #col-3: nXID
        Cresel=-1;                          % counter for resource reservation in mode 4
        SL_RESOURCE_RESELECTION_COUNTER=-1; % counter for resource reservation in mode 4
        sciTBs = [];                        % sci bit sequences (new tx and retx)
    end
    
    properties % non-changeable properties (Constant = true, GetAccess = public)
        cp_Len_r12                       = 'Normal';                  % SL-CP-Len: Cyclic Prefix: For V2V only 'Normal' is allowed
        NRBsc                            = 12;                        % resource block size in the frequency domain, expressed as a number of subcarriers
        sci1_TBsize                      = 32;                        % length of SCI Format 1 message (36.212-5.4.3.1.2)
        Msc_PSCCH                        = 24;                        % bandwidth of SL PSCCH in # subcarriers (2 PRBs in one subframe)
        NSLsymb                          = 7;                         % Number of SL symbols per slot, depending on CPconf
        PSCCH_DMRS_symbloc_perSubframe   = [2 5 8 11]';               % PSCCH DMRS Symbol locations per subframe for PSCCH
        PSCCH_symbloc_perSubframe        = [0 1 3 4 6 7 9 10 12 13]'; % PSCCH Symbol locations per subframe for PSCCH
        PSSCH_DMRS_symbloc_perSubframe   = [2 5 8 11]';               % PSSCH DMRS Symbol locations per subframe for PSCCH
        PSSCH_symbloc_perSubframe        = [0 1 3 4 6 7 9 10 12 13]'; % PSSCH Symbol locations per subframe for PSCCH
        pscch_c_init                     = 510;                       % 36.211, 9.4.1: initializer for PSCCH scrambling sequence
        acceptable_NPRBsizes = ...                                    % Acceptable sizes for NRB_PSSCH
            [1,2,3,4,5,6,8,9,10,12,15,16,18,20,24,25,27,30,32,36,40,45,48,50,54,60,72,75,80,81,90,96,100];
        
        mcs_r14_MAX = 11;                                             % Assume for the time being that only QPSK is allowed
        % mac parametrization
        slschSubHeader_Len = 6;                                       % Length of SL-SCH Subheader in bytes (36.321, 6.1.6)
        macPDU_Len = 2;                                               % Length of MAC PDU Subheader in bytes (36.321, 6.1.6)  
        maxTBSize = 1256;                                             % this is internal: MAX TB Size (due to turbo coding)
    end
    
    
    methods
        
        function h = SL_V2XCommunication(varargin)
            %Constructor & Initialization routine
            
            %% input
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
            
            if isfield(slBaseConfig,'slMode')
                h.slMode = slBaseConfig.slMode;
            else % default
                h.slMode = 3;
            end
            assert(isequal(h.slMode,3) | isequal(h.slMode,4),'Invalid V2X SL mode. Select from {3,4}');
            % assertions for not fully supported slModes
            if isequal(h.slMode,4)
                fprintf('** Sidelink Communications Mode 4 not fully supported yet **\n');
                %keyboard
            end
            
            % --------------------------- sync config inputs ---------------------------
            slSyncConfig = varargin{2};
            if isfield(slSyncConfig,'syncOffsetIndicator')
                h.syncOffsetIndicator = slSyncConfig.syncOffsetIndicator;
            else % default
                h.syncOffsetIndicator = 0;
            end
            assert(h.syncOffsetIndicator>=0 & h.syncOffsetIndicator<=159,'Invalid setting of syncOffsetIndicator. Valid range: 0..159')
            
            if isfield(slSyncConfig,'syncTxPeriodic')
                h.syncTxPeriodic = slSyncConfig.syncTxPeriodic;
            else % default
                h.syncTxPeriodic = 1;
            end
            assert(isequal(h.syncTxPeriodic,0) |isequal(h.syncTxPeriodic,1),'Invalid syncTxPeriodic setting. Select from {0,1}');
            
            % --------------------------- V2X comm config inputs ---------------------------
            slV2XCommConfig = varargin{3};
            if isfield(slV2XCommConfig,'sl_OffsetIndicator_r14')
                h.sl_OffsetIndicator_r14 = slV2XCommConfig.sl_OffsetIndicator_r14;
            else % default
                h.sl_OffsetIndicator_r14 = 0;
            end
            %             assert(h.sl_OffsetIndicator_r14>=0 & h.sl_OffsetIndicator_r14<=10239,'Invalid setting of sl-OffsetIndicator-r14. Valid range: 0..10239');
            
            if isfield(slV2XCommConfig,'sl_Subframe_r14')
                h.sl_Subframe_r14 = slV2XCommConfig.sl_Subframe_r14;
            else % default
                h.sl_Subframe_r14 = 20;
            end
            %             assert(length(h.sl_Subframe_r14)==16 | length(h.sl_Subframe_r14)==20 | length(h.sl_Subframe_r14)==100, 'Invalid sl-Subframe-r14 size. Valid value: {16,20,100}');
            
            
            if isfield(slV2XCommConfig,'adjacencyPSCCH_PSSCH_r14')
                h.adjacencyPSCCH_PSSCH_r14 = slV2XCommConfig.adjacencyPSCCH_PSSCH_r14;
            else % default
                h.adjacencyPSCCH_PSSCH_r14 = true;
            end
            %             assert(h.adjacencyPSCCH_PSSCH_r14==true | h.adjacencyPSCCH_PSSCH_r14==false,'Invalid setting of adjacencyPSCCH_PSSCH_r14. Valid range: {true,false}');
            
            
            if isfield(slV2XCommConfig,'sizeSubchannel_r14')
                h.sizeSubchannel_r14 = slV2XCommConfig.sizeSubchannel_r14;
            else % default
                h.sizeSubchannel_r14 = 4;
            end
            
            if isfield(slV2XCommConfig,'numSubchannel_r14')
                h.numSubchannel_r14 = slV2XCommConfig.numSubchannel_r14;
            else % default
                h.numSubchannel_r14 = 1;
            end
            
            if isfield(slV2XCommConfig,'startRB_Subchannel_r14')
                h.startRB_Subchannel_r14 = slV2XCommConfig.startRB_Subchannel_r14;
            else % default
                h.startRB_Subchannel_r14 = 0;
            end
            
            % extra assertion for respecting total bandwidth
            if h.startRB_Subchannel_r14 + h.numSubchannel_r14*h.sizeSubchannel_r14 - 1 > h.NSLRB
                fprintf('Error in PSSCH Pool Definition. Check  startRB_Subchannel_r14, numSubchannel_r14, sizeSubchannel_r14 parameters\n');
                keyboard;
            end
            
            if isequal(h.adjacencyPSCCH_PSSCH_r14,false) % the following field is relevant only for non-adjacent pscch/pssch
                if isfield(slV2XCommConfig,'startRB_PSCCH_Pool_r14')
                    h.startRB_PSCCH_Pool_r14 = slV2XCommConfig.startRB_PSCCH_Pool_r14;
                else % default
                    h.startRB_PSCCH_Pool_r14 = 0;
                end
                %                 assert(h.startRB_PSCCH_Pool_r14>=0 & h.startRB_PSCCH_Pool_r14<=99,'Invalid setting of sl-startRB_PSCCH_Pool_r14. Valid range: 0..99');
            end
            
            %% phy dimensioning
            
            % phy conf
            switch h.NSLRB
                case 6,   h.NFFT = 128;  h.chanSRate = 1.92e6;
                case 15,  h.NFFT = 256;  h.chanSRate = 3.84e6;
                case 25,  h.NFFT = 512;  h.chanSRate = 7.68e6;
                case 50,  h.NFFT = 1024; h.chanSRate = 15.36e6;
                case 75,  h.NFFT = 1536; h.chanSRate = 23.04e6;
                case 100, h.NFFT = 2048; h.chanSRate = 30.72e6;
            end
            h.cpLen0 = round(0.0781*h.NFFT);
            h.cpLenR = round(0.0703*h.NFFT);
            h.samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
            
            % ---------------- phy parametrization for PSCCH -----------------------
            % PSCCH Bit Capacity x2 due to QPSK
            h.pscch_BitCapacity = h.Msc_PSCCH*length(h.PSCCH_symbloc_perSubframe) * 2;
            
            % obtain interleaver indices needed for PUSCH interleaving (36.212 5.2.2.7 / 5.2.2.8)
            % PUSCH interleaver setting  (36.212-5.4.3)
            h.cmux = 2*(h.NSLsymb-2);
            % Inputs: length of f0_seq, h.cmux for SL, 2 for QPSK, 1 for single-layer
            h.pscch_muxintlv_indices =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.pscch_BitCapacity, h.cmux, 2, 1 );
            % generate scramb-seq: initialized at the start of each subframe with c_init = 510 (36.211, 9.4.1)
            h.pscch_b_scramb_seq = phy_goldseq_gen (h.pscch_BitCapacity, h.pscch_c_init);
            
            % PSCCH DMRS sequences computation (NCS SELECTION NOT IMPLEMENTED YET!!! Set it arbitrarily to 0)
            ncs_val = 0;
            pscch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pscch_V2X'),'N_PRB', 2, 'NCS', ncs_val));
            h.pscch_dmrs_seq = pscch_dmrs_obj.DMRS_seq();
            
            % ///////////////////////// mtlb toolbox comparison /////////////////////////
            %[seq,info] = ltePSCCHDRS(struct('SidelinkMode',SidelinkMode,'PRBSet',[0:1]','CyclicShift',ncs_val));
            %pscchDMRS_proc_ft_mtlb_ok = sum(abs(pscch_dmrs_seq-seq).^2)<1e-8
            %if ~pscchDMRS_proc_ft_mtlb_ok, fprintf('PSCCH DMRS Generation : error in comparison with matlab toolbox\n'); keyboard; end
            %keyboard
            
            % length of frlbitmap
            h.frlbitmap_len = ceil(log2(h.numSubchannel_r14*(h.numSubchannel_r14+1)/2));
            
        end % SL_V2XCommunication
        
        function h = GetV2XCommResourcePool (h)
            %Calculate v2x communication resource pools for given input configuration (36.213 - 14.1.5 (PSSCH) & 14.2.4 (PSCCH))
            
            % ------------------ SUBFRAMES (common for PSSCH/PSSCH, 14.1.5) ----------------------
            % identify subframes where SLSS is configured within an SFN
            if h.syncTxPeriodic, h.subframes_SLSS = (h.syncOffsetIndicator:h.syncPeriod:10239);
            else, h.subframes_SLSS = h.syncOffsetIndicator; end
            Nslss = length(h.subframes_SLSS);
            
            % identify reserved subframes
            remaining_subframes = setdiff((h.sl_OffsetIndicator_r14:10239), h.subframes_SLSS);
            Nreserved = mod(10240-Nslss,length(h.sl_Subframe_r14));
            rix = floor(((0:1:Nreserved-1).*(10240-Nslss)./Nreserved))';
            h.subframes_Reserved = remaining_subframes(rix+1);
            % calculate UE subframe resource pool (common for PSSCH and PSCCH)
            potential_subframes = setdiff(remaining_subframes, h.subframes_Reserved);
            % calculate subframe positions bitmap for all SFN (vector of length(potential_subframes) elements) )
            b = h.sl_Subframe_r14(mod(0:length(potential_subframes)-1,length(h.sl_Subframe_r14))+1)==1;
            % assigned subframes
            h.ls_PSSCH_RP = potential_subframes(b)';
            h.ls_PSCCH_RP = h.ls_PSSCH_RP;
            
            % ----------------------- PRBs ------------------------
            % PSSCH PRB pool (14.1.5)
            h.ms_PSSCH_RP = cell(h.numSubchannel_r14,1);
            for m = 0:size(h.ms_PSSCH_RP,1)-1
                h.ms_PSSCH_RP{m+1,1} = h.startRB_Subchannel_r14 + m*h.sizeSubchannel_r14 + (0:h.sizeSubchannel_r14-1)';
            end
            % PSCCH PRB pool (14.2.4)
            h.ms_PSCCH_RP = cell(h.numSubchannel_r14,1);
            % two cases: adjacent and non-adjacent
            if h.adjacencyPSCCH_PSSCH_r14 % keep first two PRBs of already defined PSSCH pool
                for m = 0:size(h.ms_PSCCH_RP,1)-1, h.ms_PSCCH_RP{m+1,1} = h.ms_PSSCH_RP{m+1}(1:2); end
            else % independent pool
                for m = 0:size(h.ms_PSCCH_RP,1)-1, h.ms_PSCCH_RP{m+1,1} = h.startRB_PSCCH_Pool_r14 + 2*m + (0:1)'; end
            end
            
            % ----------------------- Optional Print-Out ------------------------
            fprintf('V2X PSxCH Subframe pool (total %i subframes)\n',length(h.ls_PSCCH_RP));
            fprintf('( V2X PSxCH Subframes : '); fprintf('%i ',h.ls_PSCCH_RP); fprintf(')\n');
            fprintf('V2X PSCCH PRB Pool contains %2i subchannels, of size  2 PRBs each, with lowest PRB index of subchannel #0 = %2i\n',h.numSubchannel_r14, h.ms_PSCCH_RP{1}(1));
            for ix=1:length(h.ms_PSCCH_RP), fprintf('[Subchannel %2i] PRBs : ',ix-1); fprintf('%2i ',h.ms_PSCCH_RP{ix}); fprintf('\n'); end
        end % function : GetV2XCommResourcePool
        
        function [h] = SetTransmissionFormat(h)
            % Simple algorithm for determining jointly mcs, tbSize, and N_PRB based on given MAC SDU size (accounting for MAC PDU overhead and phy configuration)
            
            % find potential N_PRB assignments based on 1) current bandwidth 2) subchannel size 
            % do not forget that for control/data adjacency case the first 2 PRBs are allocated to control.
            N_PRB_space = h.acceptable_NPRBsizes(h.acceptable_NPRBsizes<=h.NSLRB);
            N_PRB_space = N_PRB_space(mod(N_PRB_space+2*h.adjacencyPSCCH_PSSCH_r14,h.sizeSubchannel_r14)==0)';
            
            % mcs_space
            % 36.213/Table 8.6.1-1
            load('3GPP_36213_Table8_6_1_1.mat','raw');
            mod_table = raw;
            Itbs_space   = (0:raw(h.mcs_r14_MAX+1,3))';

            % mac pdu length accounting for SDU and Headers
            mac_pdu_len_MIN = (h.slschSubHeader_Len + h.macPDU_Len)*8 + h.sduSize
            
            % now load TBS/N_PRB/MCS table
            load('3GPP_36213_Table7_1_7_2_1_1','raw');
            % isolate potential TBsizes for given mcs and N_PRB spaces
            subMat = raw(2:2+length(Itbs_space)-1,N_PRB_space+1);
            % create solutions space
            combs = [];
            for i=1:size(subMat,1)
                for j=1:size(subMat,2)                    
                    if subMat(i,j) >= mac_pdu_len_MIN && subMat(i,j) <= h.maxTBSize
                        %fprintf('itbs = %2i, N_PRB = %2i, TB Size = %4i, Padding = %4i\n', Itbs_space(i), N_PRB_space(j), subMat(i,j), subMat(i,j)-mac_pdu_len_MIN);
                        combs = [combs;  Itbs_space(i), N_PRB_space(j), subMat(i,j), subMat(i,j)-mac_pdu_len_MIN];
                    end                    
                end
            end
            
            if isempty(combs)
                fprintf('Stop here, not able to accomodate the SDU'); keyboard;
            else
                % Criterion for decide which configuration to keep
                % Scenario 1: Minimum Padding
                [c,ix] = min(combs(:,4));
                % Scenario 2: Minimum #N_PRB
                %[c,ix] = min(combs(:,2));
                
                % Results                
                h.N_RB_PSSCH = combs(ix,2);
                h.pssch_TBsize = combs(ix,3);
                padding = combs(ix,4);
                
                modtable_index = find(mod_table(:,3)==combs(ix,1),1,'first');                
                h.mcs_r14 = mod_table(modtable_index,1);
                h.pssch_Qprime = mod_table(modtable_index,2);
                
                % optional printout
                fprintf('For SDU size = %3i bits we set: mcs = %2i, N_PRB = %2i, TB Size = %4i, Qprime = %i (Padding = %4i)\n',...
                    h.sduSize, h.mcs_r14, h.N_RB_PSSCH, h.pssch_TBsize, h.pssch_Qprime, padding);
            end
            % TODO: at some point we will need to check the ratio tbSize/BitCapacity to be lower than 0.93
        end
            
            
        function [h] = PSxCH_Procedures(h, slV2XUEconfig, subframe_counter)
            % 36.213 [14.2.1, 14.1.1.4C], 36.212 [5.4.3.1.2, 5.3.3.1.9A]
            
            %% ----------------------------- Read Configuration -----------------------------
            % Common for both SL modes
            if isfield(slV2XUEconfig,'sduSize') && isfield(slV2XUEconfig,'LsubCH')
                error('Can not set simultaneously sduSize and LsubCH\n');
            else
                if isfield(slV2XUEconfig,'sduSize')
                    h.sduSize = slV2XUEconfig.sduSize; % SDU size known --> Extract N PRBs and Subchannels and MCS
                elseif isfield(slV2XUEconfig,'LsubCH')
                    h.LsubCH = slV2XUEconfig.LsubCH; % Subchannels known (and MCS) --> Extract TB size
                end
            end
            
            if isfield(slV2XUEconfig,'mcs_r14'), h.mcs_r14 = slV2XUEconfig.mcs_r14; end
            assert(all(h.mcs_r14>=0) & all(h.mcs_r14<=31),'Invalid setting of mcs-r14. Valid range: 0..31');

            if isfield(slV2XUEconfig,'SFgap'), h.SFgap = slV2XUEconfig.SFgap; end
            assert(h.SFgap>=0,'Assigned SFgap not valid.');

            if isfield(slV2XUEconfig,'Linit'), h.Linit = slV2XUEconfig.Linit; end
                
            if isfield(slV2XUEconfig,'nsubCHstart'), h.nsubCHstart = slV2XUEconfig.nsubCHstart; end
                        
            %% ----------------------------- PSSCH -----------------------------
            % beta parameter in 14.1.1.4C
            beta = 2*h.adjacencyPSCCH_PSSCH_r14;
            
            % number of transmission opportunities
            numTxOp = (h.SFgap>0)+1;
                        
            % Case 1: We know TB size and we find Num of PRBs and Subchannels
            if isfield(slV2XUEconfig,'sduSize') % at TX
                h = SetTransmissionFormat(h);                
                h.LsubCH = ceil((h.N_RB_PSSCH+beta)/h.sizeSubchannel_r14);      % # of subchannels calculation. account for prbs used for control channel
            elseif isfield(slV2XUEconfig,'LsubCH') % at RX
                h.N_RB_PSSCH = h.sizeSubchannel_r14*h.LsubCH - beta; % # account for prbs used for control channel
                load('3GPP_36213_Table8_6_1_1.mat','raw');             
                h.pssch_Qprime = raw(h.mcs_r14+1,2);
                ITBS =  raw(h.mcs_r14+1,3);
                load('3GPP_36213_Table7_1_7_2_1_1','raw');
                h.pssch_TBsize = raw(raw(:,1)==ITBS,raw(1,:)==h.N_RB_PSSCH);
            end
                
            % check
            % now we are ready for phy parametrization
            h.Msc_PSSCH = h.N_RB_PSSCH.*h.NRBsc;
            h.pssch_BitCapacity = h.Msc_PSSCH*length(h.PSSCH_symbloc_perSubframe)*h.pssch_Qprime;  % length of PSSCH sequence in bits
            h.pssch_muxintlv_indices =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.pssch_BitCapacity, h.cmux, h.pssch_Qprime, 1 );
            % optional printout
            fprintf('PSSCH ModOrder = %i \n',h.pssch_Qprime);
            fprintf('PSSCH TBSize = %i (bits) \n',h.pssch_TBsize);
            fprintf('PSSCH Num of PRBs = %i \n',h.N_RB_PSSCH);
            fprintf('PSSCH Bit Capacity = %i (bits) \n',h.pssch_BitCapacity);
            
            % ----- determine subframe and resource blocks ------            
            % Case 1: Mode-3 Tx/Rx  or Mode-4 Rx only
            if h.slMode==3 || (h.slMode==4 && isfield(slV2XUEconfig,'LsubCH')) %14.1.1.4C                
                m = [h.Linit;h.nsubCHstart];
                % Case 2: Mode-4 Tx only    
            elseif h.slMode==4 && isfield(slV2XUEconfig,'sduSize') %14.1.1.4.Β, 14.1.1.6
                % Baseline Scheme: Random allocation at Tx side                
                % m = [0; 0;]; % fixed
                % smallest possible subchannel index (0-based): m_MIN = 0
                % find the largest possible subchannel index based on
                % LsubCH and sizeSubchannel_r14 (0-based): m_MAX = h.sizeSubchannel_r14 - h.LsubCH;
                % randomly pick indices between m_MIN and m_MAX for new transmission and potential re-transmission
                m = [randi([0,h.sizeSubchannel_r14 - h.LsubCH]);randi([0,h.sizeSubchannel_r14 - h.LsubCH])];
                
                % resource reservation
                %%%% SL_RESOURCE_RESELECTION_COUNTER selection: 36.321, 5.14.1.1
                h = SetResourceReselectionCounter(h);
               
                % initialization of resource reselection counter
                %h.Cresel=10*h.SL_RESOURCE_RESELECTION_COUNTER;   
                
            end        
            
            % allocation based on m0,m1          
            for txOp = 1:numTxOp %num transmission opportunities per UE
                h.m_PSSCH_selected(txOp,:) = (h.startRB_Subchannel_r14 + m(txOp)*h.sizeSubchannel_r14 + beta + (0:h.N_RB_PSSCH-1))';
                % create FRL bitmap
                [h.v2x_frlbitmap(txOp,:), riv_val] = ra_bitmap_resourcealloc_create(h.numSubchannel_r14, m(txOp), h.LsubCH);
            end
            % optional printout
            fprintf('==================================================\n');
            for txOp = 1:size(h.m_PSSCH_selected,1), fprintf(' PSSCH PRBs [txOp = %i]: ', txOp); fprintf('%i ', h.m_PSSCH_selected(txOp, :)); fprintf('\n'); end
            
            %% ----------------------------- PSCCH -----------------------------
            % --------- Determine subframe and resource blocks for transmitting SCI Format 1 message & Generate Messages ------
            % the following are relevant only at tx side where we know the incoming TB size.
            % In Rx we have already the info since we do blind detection of SCIs
            if isfield(slV2XUEconfig,'sduSize') % Mode-3 % Mode-4 TX
                
                h.sciTBs = -ones(numTxOp,h.sci1_TBsize); % define sci bit sequences
                
                % select 1st available subframe
                if subframe_counter <= max(h.ls_PSCCH_RP)
                    n = find(h.ls_PSCCH_RP>=subframe_counter,1,'first');
                else % handle a special case where a packet arrives after last subframe of resource pool
                    n = 1;
                end
                    
                % for each (potential) transmission opportunity
                for txOp = 1:numTxOp                    
                    % new transmission: 1st available subframe
                    % retransmission  : Add SFgap                        
                    if h.slMode==3
                        h.l_PSCCH_selected(txOp,:) = h.ls_PSCCH_RP(1 + mod(mod(n+(txOp-1)*h.SFgap-1,length(h.ls_PSSCH_RP))+length(h.ls_PSSCH_RP),length(h.ls_PSSCH_RP)) );
                    elseif h.slMode==4
                        % Same as mode-3 (Placeholder. TO BE REVISED)
                        h.l_PSCCH_selected(txOp,:) = mod(h.ls_PSCCH_RP(n+(txOp-1)*h.SFgap), length(h.ls_PSSCH_RP));
                    end
                    
                    % get the PRBs based on PSSCH Subchannel Selection
                    h.m_PSCCH_selected(txOp,:) = h.ms_PSCCH_RP{m(txOp)+1}; % +1 due to 0-indexing                    
                    % create SCI bit sequence
                    h.sciTBs(txOp,:) = LoadSCI1TB (h, txOp);
                end % txOp
                
                % ///////////////////////// mtlb toolbox comparison /////////////////////////
                %ue    = struct('NSLRB',h.NSLRB,'PSSCHNSubchannels',h.numSubchannel_r14);
                %sciin = struct('SCIFormat','Format1','RIV',riv_val,'TimeGap',h.SFgap(i),'ModCoding',h.mcs_r14(i),'RetransmissionIdx',double(txOp>1));
                %[sciout,bitsout] = lteSCI(ue,sciin);
                %sci1_ft_mtlb_ok = isequal(double(bitsout'),double(sci1TBs{i}(txOp,:)));
                %if ~sci1_ft_mtlb_ok, fprintf('sci 1 message construction: error in comparison with matlab toolbox\n'); keyboard; end
            end % at TX 
            
            % PSCCH subframes are identical with that of PSSCH
            h.l_PSSCH_selected = h.l_PSCCH_selected;
            
            % optional: print allocation info
            fprintf('==================================================\n');
            fprintf(' PSCCH Subframes : '); fprintf('%i ',h.l_PSCCH_selected); fprintf('\n');
            for txOp = 1:size(h.m_PSCCH_selected,1)
                fprintf(' PSCCH PRBs [txOp = %i]: ', txOp); fprintf('%i ', h.m_PSCCH_selected(txOp, :)); fprintf('\n');
                %                 fprintf(' FRL Bitmap [txOp = %i]: ', txOp); fprintf('%i ', h.v2x_frlbitmap(txOp, :)); fprintf('\n');
                %                 fprintf(' SCI-1 (%i bits) message %x (hex format) generated\n', length(sci1TBs(txOp,:)), bitTodec(sci1TBs(txOp,:)',true));
            end
                
            
        end % PSxCH_Procedures
            
        function output_seq = LoadSCI1TB (h, txOp)
            %Generates SCI Format-1 transport block(36.212/5.4.3.1.2 & 36.213/14.2.1&14.1.1.4C)
            
            % ResourceReservation: 36.213, Table 14.2.1-2
            rr = zeros(4,1);           
            % define tb
            sci1_tb = -ones(h.sci1_TBsize,1);
            % ProSe Per-Packet Priority PPPP [not implemented]
            sci1_tb(1:3,1) = 0;
            % ResourceReservation
            sci1_tb(4:7,1) = rr;
            % Frequency resource location of initial transmission and retransmission
            sci1_tb(7+1:7+h.frlbitmap_len,1) = h.v2x_frlbitmap(txOp,:);
            % Time gap between initial transmission and retransmission
            sci1_tb(7+h.frlbitmap_len+1:7+h.frlbitmap_len+4,1) = decTobit(h.SFgap, 4, true);
            % Modulation and coding scheme
            sci1_tb(7+h.frlbitmap_len+4+1:7+h.frlbitmap_len+4+5,1) = decTobit(h.mcs_r14, 5, true);
            % Retransmission index
            sci1_tb(7+h.frlbitmap_len+4+5+1:7+h.frlbitmap_len+4+5+1,1) = double(txOp>1);
            % Reserved information bits are added until the size of SCI format 1 is equal to 32 bits. The reserved bits are set to zero.
            sci1_tb(7+h.frlbitmap_len+4+5+1+1:end) = 0;
            % print output
            % fprintf('SCI-1 (%i bits) message %x (hex format) generated\n', length(sci1_tb), bitTodec(sci1_tb,true));
            output_seq = sci1_tb;
            
            % optional printout
            fprintf('Resource Reservation (Actual)                                        : % .1f\n', bitTodec(rr,true));
            fprintf('Frequency resource location (INT)                                    : % i\n', bitTodec(sci1_tb(7+1:7+h.frlbitmap_len,1),true));
            fprintf('Time gap between initial transmission and retransmission  (INT)      : % i\n', bitTodec(sci1_tb(7+h.frlbitmap_len+1:7+h.frlbitmap_len+4,1),true));
            fprintf('Modulation and Coding (INT)                                          : % i\n', bitTodec(sci1_tb(7+h.frlbitmap_len+4+1:7+h.frlbitmap_len+4+5,1), true));
            fprintf('Retransmission index                                                 : % i\n', sci1_tb(7+h.frlbitmap_len+4+5+1:7+h.frlbitmap_len+4+5+1,1));
            fprintf('Reserved information bits (INT)                                      : % i\n', bitTodec(sci1_tb(7+h.frlbitmap_len+4+5+1+1:end), true));
            fprintf('\n');
%             keyboard
            
        end % function : GenerateSCI1TB
        
        function [nsubCHstart, LsubCH, SFgap, mcs_r14, ReTx, rr] = ReadSCI1TB (h, input_seq)
            %Readsout SCI Format-1 information (36.212 - 5.4.3.1.1)
            sci1_tb = input_seq;
            fprintf('Information Recovery from SCI-1 message %x (hex format)\n', bitTodec(sci1_tb,true));
            
            % resource reservation: 36.213, Table 14.2.1-2
            rr_int = bitTodec(sci1_tb(4:7,1), true);
            if rr_int >= 0 && rr_int <= 10
                rr = rr_int;
            elseif rr_int == 11
                rr = 0.5;
            elseif rr_int == 12
                rr = 0.2;
            end
            
            frl_bitmap = bitTodec(sci1_tb(7+1:7+h.frlbitmap_len,1),true);
            [~,~,nsubCHstart, LsubCH] = ra_bitmap_resourcealloc_recover(sci1_tb(7+1:7+h.frlbitmap_len,1), h.numSubchannel_r14);
            
            SFgap = bitTodec(sci1_tb(7+h.frlbitmap_len+1:7+h.frlbitmap_len+4,1),true);
            mcs_r14 = bitTodec(sci1_tb(7+h.frlbitmap_len+4+1:7+h.frlbitmap_len+4+5,1), true);
            ReTx = sci1_tb(7+h.frlbitmap_len+4+5+1:7+h.frlbitmap_len+4+5+1,1);
            ReservedBits = bitTodec(sci1_tb(7+h.frlbitmap_len+4+5+1+1:end), true);
            
            fprintf('Resource Reservation (Actual)                                        : % .1f\n', rr);
            fprintf('Frequency resource location (INT)                                    : % i\n', frl_bitmap);
            fprintf('Time gap between initial transmission and retransmission  (INT)      : % i\n', SFgap);
            fprintf('Modulation and Coding (INT)                                          : % i\n', mcs_r14);
            fprintf('Retransmission index                                                 : % i\n', ReTx);
            fprintf('Reserved information bits (INT)                                      : % i\n', ReservedBits);
            fprintf('\t'); fprintf('(FRL Bitmap --> nsubCHstart = %i, LsubCH = %i',nsubCHstart,LsubCH); fprintf(')\n');
            
            
        end
        
        function [output_seq, d_seq, nXID] = SL_SCI_PSCCH_Encode(h, input_seq)
            % V2X-specific Sidelink SCI Transport/Physical Channel Tx Processing:
            % SCI (36.212 / 5.4.3 - 5.3.3.x - 5.2.2.7-8) & PSCCH (36.211 / 9.4)
            % input : SCI TB
            % output: symbol-sequence at the output of pscch encoder, pre-precoder output, nXID
            
            % 36.212 - 5.3.3.2	Transport block CRC attachment
            a_seq = input_seq;
            b_seq = tran_crc16( a_seq, 'encode' );
            
            % ---- this is not part of processing, it will be used at PSSCH processing !!!! -------
            % 36.211 - 9.3.1 : compute nXID
            nXID = bitTodec(b_seq(length(a_seq)+1:end),true);
            % --------------------------------------------------------------------------------------
            
            % no scrambling
            c_seq = b_seq;
            
            % 36.211 - 5.3.3.3 Channel Coding
            d0_seq = tran_conv_coding(c_seq,0); % block #0. Each input stream has length: length(c_seq). Output Length 3x(length(c_seq))
            
            % 36.211 - 5.3.3.4 Rate Matching
            e0_seq = tran_conv_ratematch( d0_seq, h.pscch_BitCapacity, 'encode' );
            
            % dummy assignment to follow standard notation
            f0_seq = e0_seq;
            
            % 36.212 - 5.2.2.7 / 5.2.2.8 PUSCH Interleaving without any control information
            g0_seq(h.pscch_muxintlv_indices,1) = f0_seq; % DIFFERENT ORDER FROM BCH and DCH !!!!!!!!!!!!!!!!
            
            % ///////////////////////// mtlb toolbox comparison /////////////////////////
            %cw = lteSCIEncode(struct('SidelinkMode','V2X','RNTI',0),input_seq,h.pscch_BitCapacity);
            %sci1_tran_proc_ft_mtlb_ok = isequal(double(cw(:)), double(g0_seq(:)));
            %if ~sci1_tran_proc_ft_mtlb_ok, fprintf('sci 1 transport channel processing : error in comparison with matlab toolbox\n'); keyboard; end
            
            % phy processing initialization
            b_seq = g0_seq;
            
            % 36.211 - 9.4.1 Scrambling
            b_seq_tilde = mod(b_seq + h.pscch_b_scramb_seq, 2);
            
            % 36.211 - 9.4.2 Modulation
            d_seq = phy_modulate(b_seq_tilde, 'QPSK');
            
            % 36.211 - 9.4.3 Layer Mapping
            x_seq = d_seq;
            
            % 36.211 - 9.4.4 Transform Precoding
            y_seq = phy_transform_precoding(x_seq,h.Msc_PSCCH);
            
            % ///////////////////////// mtlb toolbox comparison /////////////////////////
            %pscch = ltePSCCH(g0_seq);
            %pscch_proc_ft_mtlb_ok = sum(abs(pscch-y_seq).^2)<1e-8;
            %if ~pscch_proc_ft_mtlb_ok, fprintf('PSCCH channel processing : error in comparison with matlab toolbox\n'); keyboard; end
            
            % assignment
            output_seq = y_seq;
            
        end % function : SL_SCI_PSCCH_Encode
        
        function [output_seq, CRCerror_flg, d_seq_rec, nXID] = SL_SCI_PSCCH_Recover(h, input_seq, decodingType)
            %Sidelink Communication Control Signaling Transport/Physical Channel Rx Processing
            % Follow references in corresponding Encoding function
            CRCerror_flg = true;
            
            % 36.211 - 9.4.4 Transform De-Precoding
            x_seq_rec = phy_transform_deprecoding(input_seq,h.Msc_PSCCH);
            
            %  36.211 - 9.4.3 Layer De-Mapping
            d_seq_rec = x_seq_rec;
            
            %  36.211 - 9.4.2 Demodulation
            if isequal(decodingType,'Hard')
                b_seq_tilde_rec = phy_demodulate(d_seq_rec,'QPSK');
            elseif isequal(decodingType,'Soft')
                b_seq_tilde_rec = phy_symbolsTosoftbits_qpsk( d_seq_rec );
            end
            
            %  36.211 - 9.4.1 Descrambling
            if isequal(decodingType,'Hard')
                b_seq_rec = mod(b_seq_tilde_rec + h.pscch_b_scramb_seq, 2);
            elseif isequal(decodingType,'Soft')
                b_seq_rec = b_seq_tilde_rec.*(-(2*h.pscch_b_scramb_seq-1));
            end
            
            % PHY processing completion
            pscch_output_recovered = b_seq_rec;
            
            %  36.212 - 5.2.2.7 / 5.2.2.8 PUSCH De-interleaving
            f0_seq_rec = -1000*ones(length(pscch_output_recovered),1); f0_seq_rec = pscch_output_recovered(h.pscch_muxintlv_indices);
            
            % dummy assignment to follow standard notation
            e0_seq_rec = f0_seq_rec;
            
            % 5.3.3.4 Rate Matching Recovery
            d0_seq_rec = tran_conv_ratematch( e0_seq_rec, 3*(h.sci1_TBsize+16), 'recover' );
            
            % 5.3.3.3 Channel Decoding
            if isequal(decodingType,'Hard')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 1 );
            elseif isequal(decodingType,'Soft')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 2 );
            end
            
            % 5.3.3.2	Transport block CRC recovery
            b_seq_rec = double(c_seq_rec);
            [ a_seq_rec, CRCerror_flg ] = tran_crc16 (b_seq_rec, 'recover' );
            
            % ---- this is not part of processing, it will be used at PSSCH processing !!!! -------
            % 36.211 - 9.3.1 : compute nXID
            nXID = bitTodec(b_seq_rec(length(a_seq_rec)+1:end),true);
            % --------------------------------------------------------------------------------------
            
            % returned vector
            output_seq = a_seq_rec;
        end
        
        function [output_seq, d_seq] = SL_SCH_PSSCH_Encode(h, input_seq, nXID, nssfPSSCH)
            % Sidelink Communication Data Transport Channel Tx Processing: 36.212 / 5.4.2
            % Sidelink Communication Data Physical Channel Tx Processing: 36.211 / 9.3 - 5.3
            
            % ------------------------ Transport ------------------------
            % Transport block CRC attachment
            a_seq = input_seq;
            b_seq = tran_crc24A( a_seq,'encode' );
            
            % Code block segmentation and code block CRC attachment
            if length(b_seq) > 6144, fprintf('SL-SCH code block segmentation not implemented yet\n'); keyboard;
            else, c_seq = b_seq; end
            
            % ---------------------------- turbo -----------------------------------------
            d0_seq =  tran_turbo_coding(c_seq, 0);
            e0_seq = tran_turbo_ratematch( d0_seq, h.pssch_BitCapacity, 0, 'encode' );
            % ---------------------------- turbo -----------------------------------------
            
            % dummy assignment to follow standard notation
            f0_seq = e0_seq;
            
            % PUSCH Interleaving without any control information (cmux is different for d2d and v2x)
            g0_seq(h.pssch_muxintlv_indices,1) = f0_seq;
            
            % ///////////////////////// mtlb toolbox comparison /////////////////////////
            %cw = lteSLSCH(struct('SidelinkMode','V2X','Modulation','QPSK','RV',0), h.pssch_BitCapacity(msgIndex), input_seq);
            %slsch_tran_proc_ft_mtlb_ok = isequal(double(cw(:)), double(g0_seq(:)));
            %if ~slsch_tran_proc_ft_mtlb_ok, fprintf('SL-SCH transport channel processing : error in comparison with matlab toolbox\n'); keyboard; end
            
            % ------------------------ Physical ------------------------
            b_seq = g0_seq;
            
            % Scrambling
            % c_init calculation
            pssch_c_init = nXID*2^14 + nssfPSSCH*2^9 + 510;
            % sequence
            b_scramb_seq = phy_goldseq_gen (length(b_seq), pssch_c_init);
            % apply
            b_seq_tilde = mod(b_seq + b_scramb_seq, 2);
            
            % Modulation
            if h.pssch_Qprime == 2, d_seq = phy_modulate(b_seq_tilde, 'QPSK');
            elseif  h.pssch_Qprime == 4, d_seq = phy_modulate(b_seq_tilde, '16QAM'); end
            
            % Layer mapping
            x_seq = d_seq;
            
            % Transform Precoding
            y_seq = phy_transform_precoding(x_seq,h.Msc_PSSCH);
            
            % ///////////////////////// mtlb toolbox comparison /////////////////////////
            %pssch = ltePSSCH(struct('SidelinkMode','V2X','Modulation','QPSK','NXID',nXID,'NSubframePSSCH',nssfPSSCH), g0_seq);
            %pssch_proc_ft_mtlb_ok = sum(abs(pssch-y_seq).^2)<1e-8;
            %if ~pssch_proc_ft_mtlb_ok, fprintf('PSSCH channel processing : error in comparison with matlab toolbox\n'); keyboard; end
            
            % output
            output_seq = y_seq;
            
            % DMRS generation
            pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_V2X'),'N_PRB',h.Msc_PSSCH/h.NRBsc,'NXID', nXID,'nPSSCHss', 2*nssfPSSCH));
            pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
            % ///////////////////////// mtlb toolbox comparison /////////////////////////
            %warning on;
            %[seq,info] = ltePSSCHDRS(struct('SidelinkMode',SidelinkMode,'PRBSet',[0:h.Msc_PSSCH(msgIndex)/h.NRBsc-1]','NXID', nXID));% 'NSubframePSSCH',nssfPSSCH
            %psschDMRS_proc_ft_mtlb_ok = sum(abs(pssch_dmrs_seq-seq).^2)<1e-8
            %info, keyboard
            
        end % function : SL_SCH_PSSCH_Encode
        
        function [output_seq, CRCerror_flg, d_seq_rec] = SL_SCH_PSSCH_Recover(h, input_seq, nXID, nssfPSSCH, decodingType)
            
            %Sidelink Communication Dara Transport/Physical Channel Rx Processing
            % Follow references in corresponding Encoding function
            CRCerror_flg = true;
            % ------------------------ Physical ------------------------
            % Transform Deprecoding
            x_seq_rec = phy_transform_deprecoding(input_seq,h.Msc_PSSCH);
            
            % Layer demapping
            d_seq_rec = x_seq_rec;
            
            % Demodulation
            if h.pssch_Qprime == 2
                if isequal(decodingType,'Hard')
                    b_seq_tilde_rec = phy_demodulate(d_seq_rec,'QPSK');
                elseif isequal(decodingType,'Soft')
                    b_seq_tilde_rec = phy_symbolsTosoftbits_qpsk( d_seq_rec );
                end
            elseif  h.pssch_Qprime == 4
                error('not fully supported yet');
            end
            
            % Descrambling
            pssch_c_init = nXID*2^14 + nssfPSSCH*2^9 + 510;
            b_scramb_seq = phy_goldseq_gen (length(b_seq_tilde_rec), pssch_c_init);
            if isequal(decodingType,'Hard')
                b_seq_rec = mod(b_seq_tilde_rec + b_scramb_seq, 2);
            elseif isequal(decodingType,'Soft')
                b_seq_rec = b_seq_tilde_rec.*(-(2*b_scramb_seq-1));
            end
            
            % ------------------------ Transport ------------------------
            % PUSCH Deinterleaving
            f0_seq_rec = -1000*ones(length(b_seq_rec),1); f0_seq_rec = b_seq_rec(h.pssch_muxintlv_indices) ;
            
            % dummy assignment to follow standard notation
            e0_seq_rec = f0_seq_rec;
            
            % ---------------------------- turbo -----------------------------------------
            d0_seq_rec = tran_turbo_ratematch( e0_seq_rec, 3*(h.pssch_TBsize+24)+12, 0, 'recover' );
            c_seq_rec  = tran_turbo_coding (double(d0_seq_rec), 1);
            % ---------------------------- turbo -----------------------------------------
            
            % Code block desegmentation and code block CRC attachment recovery
            b_seq_rec = double(c_seq_rec);
            
            % Transport block CRC recovery
            [ a_seq_rec, CRCerror_flg ] = tran_crc24A( b_seq_rec, 'recover' );
            
            % assignment
            output_seq = a_seq_rec;
        end % function : SL_SCH_PSSCH_Recover
        
        function [output_seq, h] = CreateSubframe (h, subframe_counter, DataTBs)
            
            % define output
            tx_output = complex(zeros(h.samples_per_subframe,1));
            tx_output_grid = complex(zeros(h.NSLRB*h.NRBsc,2*h.NSLsymb));
            
            txOp = find(subframe_counter==h.l_PSSCH_selected);
            
            % (1) Control channel
            if ~isempty(h.sciTBs)
                % get TB
                current_sci = h.sciTBs(txOp,:)';
                % Get PRBs
                prbs_sci = h.m_PSCCH_selected(txOp,:)';
                % Calculate physical control channel output
                [pscch_out, d_seq, h.nXIDs(txOp)] = SL_SCI_PSCCH_Encode(h, current_sci); %keep nXID value for future frames in SPS
                fprintf('User %i, TxOp %i: SCI/PSCCH Tx Processing done (nXID = %i, SCI=%x)\n', 1, txOp, h.nXIDs(txOp), bitTodec(current_sci,true));
                % Map control payload and drms to grid
                pscch_grid      = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSCCH_symbloc_perSubframe,      prbsTosubs(prbs_sci, h.NRBsc), pscch_out);
                pscch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSCCH_DMRS_symbloc_perSubframe, prbsTosubs(prbs_sci, h.NRBsc), h.pscch_dmrs_seq);
                tx_output_grid = pscch_grid + pscch_dmrs_grid;
            end
                        
            % (2) Data channel
            % get TB
            current_datatb = DataTBs(:);
            % Get PRBs
            prbs_data = h.m_PSSCH_selected(txOp,:)';
            % nssfPSSCH calculation (36.211, 9.2.4)
            nssfPSSCH = mod(find(h.ls_PSSCH_RP==subframe_counter)-1,10); % -1 due to 1-based matlab indexing!
            % Calculate physical shared channel output
            [slsch_out] = SL_SCH_PSSCH_Encode(h, current_datatb, h.nXIDs(txOp), nssfPSSCH);
            fprintf('User %i, TxOp %i: SL-SCH/PSSCH Tx Processing done (SL-SCH TB=%x)\n', 1, txOp, bitTodec(current_datatb(1:50),true));
            % Map data payload to grid
            pssch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSSCH_symbloc_perSubframe, prbsTosubs(prbs_data, h.NRBsc), slsch_out);
            % Calculate data dmrs
            pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_V2X'),'N_PRB',length(prbs_data),'NXID', h.nXIDs(txOp),'nPSSCHss', 2*nssfPSSCH));
            pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
            % Map data dmrs to grid
            pssch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSSCH_DMRS_symbloc_perSubframe, prbsTosubs(prbs_data, h.NRBsc), pssch_dmrs_seq);
            
            % Get total grid: Control (if exists) + Data
            tx_output_grid = tx_output_grid + pssch_grid + pssch_dmrs_grid;
            % Time-domain transformation
            tx_output(:) = phy_ofdm_modulate_per_subframe(struct(h), tx_output_grid);
            
            % return sequence
            output_seq = tx_output;
            
        end %CreateSubframe
  
        function [h] = RecoverV2XCommSubframe(h, input_seq, subframe_counter, rxConfig)
            %searches and recover information from possible sidelink sci format 1 messages (v2x)
            %then for every recovered sci-1 msg tries to decode the respective data channel

            % time-to-freq domain
            rx_input_grid   = phy_ofdm_demodulate_per_subframe(struct(h), input_seq);
            
            %% Blind search            
            prbs_sci_candidates =  h.ms_PSCCH_RP;
            for sciIX = 1:length(prbs_sci_candidates)
                % current prbs
                prbs_sci = prbs_sci_candidates{sciIX};
                % chanest/eq set
                ce_params = struct('Method',rxConfig.chanEstMethod, 'fd',rxConfig.timeVarFactor*(1/h.chanSRate),...
                    'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',length(prbs_sci)*h.NRBsc,'NSLsymb',h.NSLsymb,'l_DMRS',h.PSCCH_DMRS_symbloc_perSubframe);
                % equalization
                pscch_rx_posteq = phy_equalizer(ce_params, h.pscch_dmrs_seq, h.PSCCH_symbloc_perSubframe, prbsTosubs(prbs_sci(:), h.NRBsc), rx_input_grid);
               
                % transport and physical channel processing
                [current_sci_rec, CRCerror_flg, pscch_dseq_rx, nXID] = SL_SCI_PSCCH_Recover(h, pscch_rx_posteq, rxConfig.decodingType);
                
                % SCI found!
                if (CRCerror_flg==0 && ~all(current_sci_rec==0))
                    fprintf('   ** SCI/PSCCH Recovery done for PRB Set ['); fprintf(' %i ', prbs_sci); fprintf(']');
                    fprintf(' : CRCerror=%i, nXID_rec=%i **\n', CRCerror_flg, nXID);
                    
                    % Control Channel EVM
                    DecodeQualEstimate (h, current_sci_rec, pscch_dseq_rx, [], [], 'cch');
                    
                    % extract information
                    [startSubCh_cur, LsubCH_cur, SFgap_cur, mcs_r14_cur, ReTx_cur] = ReadSCI1TB (h, current_sci_rec);
                    % configured based on recovered info
                    slV2XUEconfigRx   = struct('mcs_r14',mcs_r14_cur, 'Linit', startSubCh_cur, 'SFgap', SFgap_cur,'nsubCHstart',startSubCh_cur,'LsubCH', LsubCH_cur);
                    % re-rerun PSxCH configuration
                    [h] = PSxCH_Procedures(h, slV2XUEconfigRx, subframe_counter);                    
                    
                    % get prbs
                    prbs_data = h.m_PSSCH_selected(1+ReTx_cur,:)';                                              
                    
                    % decode data for corresponding sci
                    DecodeData(h, subframe_counter, prbs_data, nXID, rxConfig, rx_input_grid);
                    
                else
                    fprintf('   ** SCI/PSCCH Recovery failed for PRB Set ['); fprintf(' %i ', prbs_sci); fprintf(']\n');
                end  % SCI recovery check                
            end % blind search

            
        end % Recover Subframe
                      
        function DecodeData (h, subframe_counter, prbs_data, nXID, rxConfig, rx_input_grid)
            % decoding script only for data channel
            
            % chanest/eq set
            % Calculate data dmrs
            % nssfPSSCH calculation (36.211, 9.2.4)
            nssfPSSCH = mod(find(h.ls_PSSCH_RP==subframe_counter)-1,10); % -1 due to 1-based matlab indexing!
            pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_V2X'),'N_PRB',length(prbs_data),'NXID', nXID,'nPSSCHss', 2*nssfPSSCH));
            pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
            ce_params = struct('Method',rxConfig.chanEstMethod, 'fd',rxConfig.timeVarFactor*(1/h.chanSRate),...
                'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',length(prbs_data)*h.NRBsc,'NSLsymb',h.NSLsymb,'l_DMRS',h.PSSCH_DMRS_symbloc_perSubframe);
            % equalization
            pssch_rx_posteq = phy_equalizer(ce_params, pssch_dmrs_seq, h.PSSCH_symbloc_perSubframe, prbsTosubs(prbs_data(:), h.NRBsc), rx_input_grid);
            % transport and physical channel processing
            [current_datatb_rec, CRCerror_flg, pssch_dseq_rx] = SL_SCH_PSSCH_Recover(h, pssch_rx_posteq, nXID, nssfPSSCH, rxConfig.decodingType);
            if (CRCerror_flg==0 && ~all(current_datatb_rec==0))
                fprintf('      ** DATA Recovery done !!!!! **\n');
                % Data Channel EVM
                DecodeQualEstimate (h, current_datatb_rec, pssch_dseq_rx, nXID, nssfPSSCH, 'sch');
            else
                fprintf('      ** DATA Recovery FAILED !!!!! **\n');
            end % Data recovery check
            %keyboard
                    
        end % DecodeData
                
        function [evm, biterrs, bitsim] = DecodeQualEstimate (h, decoded_bit_seq, recovered_qpskin_seq, nXID, nssfPSSCH, mode)
            
            % regenerate psxch output
            if strcmp(mode,'cch')
                [~, dseq_tx_regen] = SL_SCI_PSCCH_Encode(h, decoded_bit_seq);
            elseif strcmp(mode,'sch')
                [~, dseq_tx_regen] = SL_SCH_PSSCH_Encode(h, decoded_bit_seq, nXID, nssfPSSCH);
            end
            
            % received and ideal seqs
            x = recovered_qpskin_seq;
            r = dseq_tx_regen;
            
            evm = sqrt(mean(abs((x-r)/sqrt(mean(abs(r.^2)))).^2));
            bitseq_Tx = phy_demodulate(r,'QPSK');
            bitseq_Rx = phy_demodulate(x,'QPSK');
            biterrs =  sum(bitseq_Tx~=bitseq_Rx);
            bitsim = length(bitseq_Rx);
            ber = biterrs/bitsim;
            
            fprintf('Bit Errors = %i/%i (BER = %.4f), EVM = %.4f, SNR(dB) = %.3f\n', ...
                biterrs, bitsim, ber, evm, 10*log10(1/(evm^2)));
        end % function : DecodeQualEstimate
        
    end % methods    
end % class


