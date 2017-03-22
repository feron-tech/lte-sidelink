classdef SL_Communication
    %SL_Communication implements the functionalities of the sidelink communication mode.
    %These include resources allocation and transmit/physical channel processing for both control and data channels.
    %Rel.12/13 sidelink communications as well as Rel.14 V2X sidelink communications are supported.
    % (1) Resources Allocation
    %   - Calculate control and data channel sidelink resource pools
    %   - Calculate UE-specific control and data channel subframe/prb resources 
    %   - Calculate subframe resources for sending/receiving broadcast/synchronization subframes
    % (2) Control Channel Tx/Rx Processing
    %   - SCI-Format 0 generation and recovery
    %   - SCI transport channel tx/rx processing
    %   - PSCCH physical channel tx/rx processing
    %   - PSCCH DMRS generation
    % (3) Data Channel Tx/Rx Processing
    % ...
    % ...
    %(For details about the input configuration properties look at the first set of class properties ("properties configured by class calling"))
    
    %Contributors: Antonis Gotsis (antonisgotsis)
    
    
    
    %Contributors: Antonis Gotsis (antonisgotsis)
    
    properties (SetAccess = protected, GetAccess = public) % properties configured by class calling
        NSLRB;                    % 6,15,25,50,75,100: Sidelink bandwidth (default: 25)
        NSLID;                    % 0..335: Sidelink Cell-ID (default: 0)
        cp_Len_r12;               % SL-CP-Len: Cyclic Prefix: 'Normal' or 'Extended'. For V2V only 'Normal' (default : 'Normal')
        slMode                    % Sidelink Mode: 1 (D2D scheduled), 2 (D2D UE-selected), 3 (V2V-scheduled) or 4 (V2V autonomous sensing)
        syncOffsetIndicator;      % Offset indicator for sync subframe with respect to 0 subframe (default: 0)
        syncPeriod;               % Synchronization subframe period (in # subframes) (default: 40)
        TransceiverMode;          % 'Tx' for transmitter, 'Rx' for receiver (default : 'Tx');        
        % d2d-specific
        scPeriod_r12;             % 40,80,160,320 subframes for FDD (Part of CommResourcePool-->SL-PeriodComm: Indicates the period over which resources allocated in a cell for sidelink communication.)
        offsetIndicator_r12;      % 0..319: SL Communication Subframe Pool offset with respect to SFN #0 (SL-TF-ResourceConfig) (default: 0)
        subframeBitmap_r12;       % size 40: SL Communication Subframe Pool Bitmap(SL-TF-ResourceConfig) (default: [0; ones(39,1)];
        prb_Start_r12;            % 0..99  : Starting PRB index allocated to Discovery transmissions (default: 2)
        prb_End_r12;              % 0..99  : Ending PRB index allocated to Discovery transmissions (default: 22)
        prb_Num_r12;              % 1..100 : Number of PRBs allocated to each Discovery transmissions block.  Total num of PRBs is 2*prb_Num_r12 (default: 10).
        networkControlledSyncTx;  % 0 for off, 1 for on: Part of RRCreconfiguration Msg (default: 1)
        syncTxPeriodic;           % 0 for off, 1 for on (fixed period = 40 ms): Part of SL-SyncConfig (default: 1)
        nPSCCH;                   % 6 bits (here in integer format: 0..63) --> Resource for PSCCH : Used to determine subframes and RBs used for PSCCH (36.213/14.2.1.1/2) (default: 0)
        HoppingFlag;              % 1 bit  (0 or 1). Currently non-hopping resource allocation is fully supported
        RBstart;                  % Starting RB index for non-hopping type 0 resource allocation (default : prb_Start_r12)
        Lcrbs;                    % Length of contiguously allocated RBs (>=1) for non-hopping type 0 resource allocation
        ITRP;                     % 7 bits for FDD (here in integer format: 0..127): Used to determine the subframe indicator map for PSSCH
        mcs_r12                   % 0..28 (5 bits, here given in integer form): Set through higher layers or selected autonously by the UE (default: 10)
        nSAID;                    % 0..255 (8 bits): Group Destination ID set in higher-layers
        % v2x-specific
        v2xSLSSconfigured;        % {true, false}: Enable or disable SLSS transmission
        sl_OffsetIndicator_r14;   % {0..10239} Indicates the offset of the first subframe of a resource pool
        sl_Subframe_r14;          % {16,20,100} : Determines PSSCH subframe pool: bitmap with acceptable sizes
        sizeSubchannel_r14;       % {n4, n5, n6, n8, n9, n10, n12, n15, n16, n18, n20, n25, n30, n48, n50, n72, n75, n96, n100}: Indicates the number of PRBs of each subchannel in the corresponding resource pool
        numSubchannel_r14;        % {n1, n3, n5, n10, n15, n20}: Indicates the number of subchannels in the corresponding resource pool 
        startRB_Subchannel_r14;   % {0..99}: Indicates the lowest RB index of the subchannel with the lowest index: 
        adjacencyPSCCH_PSSCH_r14; % {true,false}: Indicates if PSCCH and PSSCH are adjacent in the frequecy domain
        startRB_PSCCH_Pool_r14;   % {0..99} Indicates the lowest RB index of the PSCCH pool. This field is irrelevant if a UE always transmits control and data in adjacent RBs in the same subframe 
        mcs_r14;                  % {0..31} (5 bits, here given in integer form) Indicates the MCS mode set through higher layers or selected autonously by the UE (default: 10)
        m_subchannel;             % {ceil(log2(numSubchannel_r14) bits}, here in integer form: 1st transmission opportunity lowest index of the subchannel allocation
        nsubCHstart;              % {ceil(log2(numSubchannel_r14) bits}, here in integer form: 2nd transmission opportunity lowest index of the subchannel allocation
        LsubCH;                   % Number of allocated subchannels for user
        SFgap;                    % Retransmission time gap


    end
    
    
    properties (SetAccess = private) % properties configured throughout various class operations
        CommPer;                            % communication period: 2 elements (begin/end subframe)
        ls_PSCCH_RP;                        % PSCCH Subframe Pool
        ms_PSCCH_RP;                        % PSCCH Resource Blocks Pool
        ls_PSSCH_RP;                        % PSSCH Subframe Pool
        ms_PSSCH_RP                         % PSSCH Resource Blocks Pool
        l_PSCCH_selected;                   % UE-specific scheduled subframes for PSCCH
        m_PSCCH_selected;                   % UE-specific scheduled PRBs for PSCCH  
        l_PSSCH_selected;                   % UE-specific scheduled subframes for PSSCH
        m_PSSCH_selected;                   % UE-specific scheduled PRBs for PSSCH  
        pssch_prbs_ra_bitmap;               % UE-specific pssch scheduled prbs corresponding resource allocation bitmap (to be used in SCI-0 msgs)
        sci0_TBsize;                        % length of SCI Format 0 message (valid only for slMode 1,2)
        cmux;                               % multiplier for PUSCH Interleaving
        pscch_muxintlv_indices;             % PUSCH interleaver indices for transport channel processing : pscch
        pscch_b_scramb_seq;                 % PSCCH scrambling sequence
        NFFT;                               % FFT size
        chanSRate;                          % channel sampling rate
        cpLen0;                             % CP length for the 0th symbol
        cpLenR;                             % CP length for all but 0th symbols
        NSLsymb;                            % Number of SL symbols per slot, depending on CPconf
        samples_per_subframe;               % number of samples per subframe
        PSCCH_symbloc_perSubframe;          % Symbol locations per subframe for PSCCH
        PSCCH_DMRS_symbloc_perSubframe;     % Symbol locations per subframe for DMRS-PSCCH
        Msc_PSCCH;                          % bandwidth of SL PSCCH in # subcarriers
        pscch_BitCapacity;                  % PSSCH Channel Bit Capacity
        pscch_dmrs_seq;                     % PSCCH DMRS sequence per subframe
        PSSCH_symbloc_perSubframe;          % Symbol locations per subframe for PSSCH
        PSSCH_DMRS_symbloc_perSubframe;     % Symbol locations per subframe for DMRS-PSSCH
        PSSCH_PHY_NSFs;                     % # Subframe(s) used for Transmitting each PSSCH Transport Block: 4 for TM1/2, 1 for TM3/4
        Msc_PSSCH;                          % bandwidth of SL PSSCH in # subcarriers
        pssch_TBsize;                       % PSSCH transport block size (based on mod-order and number of allocated PRBs)
        pssch_Qprime;                       % PSSCH transport block  modulation order
        pssch_BitCapacity;                  % PSSCH Channel Bit Capacity
        pssch_muxintlv_indices;             % PUSCH interleaver indices for transport channel processing : pssch
        subframes_SLSS;                     % subframes where SL-SS will be transmitted
        % v2x-specific
        sci1_TBsize;                        % length of SCI Format 1message (valid only for slMode 3,4).
        frlbitmap_len;                      % length of v2x frequency resource location field bitmap
        v2x_frlbitmap;                      % frl bitmap for v2x pscch/pssch
        nXID;                               % CRC of PSCCH for sl modes 3 and 4 only


    end
    
    properties (Hidden) % non-changeable properties
        commSubframeBitmapSize = 40;      % size of subframe bitmap for d2d
        NRBsc                  = 12;      % resource block size in the frequency domain, expressed as a number of subcarriers
        pscch_c_init           = 510;     % 36.211, 9.4.1: initializer for PSCCH scrambling sequence
         
        
    end
    
    
    
    methods
        
        function h = SL_Communication(varargin)
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
                        
            if isfield(slBaseConfig,'slMode')
                h.slMode = slBaseConfig.slMode;
            else % default
                h.slMode = 1;
            end
            assert(isequal(h.slMode,1) | isequal(h.slMode,2) | isequal(h.slMode,3) | isequal(h.slMode,4),'Invalid SL mode. Select from {1,2,3,4}. 1 or 2 for D2D and 3 or 4 for V2V.');
            % assertions for not fully supported slModes
            if isequal(h.slMode,2)
                fprintf('Sidelink Communications Mode 2 not fully supported yet\n'); 
                keyboard; 
            end            
            
            if isequal(h.slMode,3) || isequal(h.slMode,4)
                fprintf('V2X Sidelink Communication not fully supported yet. Go on at your own risk!!!\n');
                keyboard                
            end
            if isequal(h.slMode,4)
               fprintf('Sidelink Communications Mode 4 not fully supported yet\n'); 
            end

            if isfield(slBaseConfig,'cp_Len_r12')
                h.cp_Len_r12 = slBaseConfig.cp_Len_r12;
                if isequal(h.cp_Len_r12,'Extended')
                    fprintf('Extended CP mode not fully supported yet\n');
                    keyboard;
                end
            else % default
                h.cp_Len_r12 = 'Normal';
            end
            assert(isequal(h.cp_Len_r12,'Normal') | isequal(h.cp_Len_r12,'Extended'),'Invalid CP Length mode. Select from {Normal,Extended}');
            % extra assertion for cp_Len_r12 & slMode configuration
            if (isequal(h.slMode,3) || isequal(h.slMode,4)) && isequal(h.cp_Len_r12,'Extended')
                fprintf('Extended CP configuration for V2V sidelink communication is not allowed (only normal).\n'); keyboard;
            end
            
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
            
            % --------------------------- comm config inputs ---------------------------
            slCommConfig = varargin{3};
            
            % common for d2d/v2x
            if isfield(slCommConfig,'networkControlledSyncTx')
                h.networkControlledSyncTx = slCommConfig.networkControlledSyncTx;
            else % default
                h.networkControlledSyncTx = 1;
            end
            assert(isequal(h.networkControlledSyncTx,0) |isequal(h.networkControlledSyncTx,1),'Invalid networkControlledSyncTx setting. Select from {0,1}');
            
            if isfield(slCommConfig,'syncTxPeriodic')
                h.syncTxPeriodic = slCommConfig.syncTxPeriodic;
            else % default
                h.syncTxPeriodic = 1;
            end
            assert(isequal(h.syncTxPeriodic,0) |isequal(h.syncTxPeriodic,1),'Invalid syncTxPeriodic setting. Select from {0,1}');
           
            % d2d-specific only
            if isequal(h.slMode,1) || isequal(h.slMode,2)
                if isfield(slCommConfig,'scPeriod_r12')
                    h.scPeriod_r12 = slCommConfig.scPeriod_r12;
                else % default
                    h.scPeriod_r12 = 320;
                end
                assert(h.scPeriod_r12==40 | h.scPeriod_r12==80 | h.scPeriod_r12==160 | h.scPeriod_r12==320,...
                    'Invalid setting of scPeriod-r12. Valid range: {40, 80, 160, 320} (subframes)');
                
                if isfield(slCommConfig,'offsetIndicator_r12')
                    h.offsetIndicator_r12 = slCommConfig.offsetIndicator_r12;
                else % default
                    h.offsetIndicator_r12 = 0;
                end
                assert(h.offsetIndicator_r12>=0 & h.offsetIndicator_r12+h.scPeriod_r12*10<=10239,'Invalid setting of offsetIndicator_r12. Check it against scPeriod_r12');
                
                if isfield(slCommConfig,'subframeBitmap_r12')
                    h.subframeBitmap_r12 = slCommConfig.subframeBitmap_r12;
                else % default
                    h.subframeBitmap_r12 = [0; ones(39,1)]; % all available except first subframe (used for broad/sync)
                end
                assert(length(h.subframeBitmap_r12)==h.commSubframeBitmapSize, 'Invalid subframeBitmap-r12 size. Valid value: 40');
                
                if isfield(slCommConfig,'prb_Start_r12')
                    h.prb_Start_r12 = slCommConfig.prb_Start_r12;
                else % default
                    h.prb_Start_r12 = 2;
                end
                assert(h.prb_Start_r12>=0 & h.prb_Start_r12<=99,'Invalid setting of prb_Start-r12. Valid range: 0..99');
                
                if isfield(slCommConfig,'prb_End_r12')
                    h.prb_End_r12 = slCommConfig.prb_End_r12;
                else % default
                    h.prb_End_r12 = 22;
                end
                assert(h.prb_End_r12>=0 & h.prb_End_r12<=99,'Invalid setting of prb_End_r12-r12. Valid range: 0..99');
                
                if isfield(slCommConfig,'prb_Num_r12')
                    h.prb_Num_r12 = slCommConfig.prb_Num_r12;
                else % default
                    h.prb_Num_r12 = 10;
                end
                assert(h.prb_Num_r12>=1 & h.prb_Num_r12<=100,'Invalid setting of prb_Num-r12. Valid range: 1..100');               
            
            % v2x-specific only    
            elseif isequal(h.slMode,3) || isequal(h.slMode,4)
                if isfield(slCommConfig,'v2xSLSSconfigured')
                    h.v2xSLSSconfigured = slCommConfig.v2xSLSSconfigured;
                else % default
                    h.v2xSLSSconfigured = true;
                end
                assert(h.v2xSLSSconfigured==true | h.v2xSLSSconfigured==false,'Invalid setting of v2xSLSSconfigured. Valid range: {true,false}');
                
                if isfield(slCommConfig,'sl_OffsetIndicator_r14')
                    h.sl_OffsetIndicator_r14 = slCommConfig.sl_OffsetIndicator_r14;
                else % default
                    h.sl_OffsetIndicator_r14 = 0;
                end
                assert(h.sl_OffsetIndicator_r14>=0 & h.sl_OffsetIndicator_r14<=10239,'Invalid setting of sl-OffsetIndicator-r14. Valid range: 0..10239');
                
                if isfield(slCommConfig,'sl_Subframe_r14')
                    h.sl_Subframe_r14 = slCommConfig.sl_Subframe_r14;
                else % default
                    h.sl_Subframe_r14 = 20;
                end                
                assert(length(h.sl_Subframe_r14)==16 | length(h.sl_Subframe_r14)==20 | length(h.sl_Subframe_r14)==100, 'Invalid sl-Subframe-r14 size. Valid value: {16,20,100}');
            
                
                if isfield(slCommConfig,'sizeSubchannel_r14')
                    h.sizeSubchannel_r14 = slCommConfig.sizeSubchannel_r14;
                else % default
                    h.sizeSubchannel_r14 = 4;
                end       
                assert(h.sizeSubchannel_r14==4 | h.sizeSubchannel_r14==5 | h.sizeSubchannel_r14==6  | h.sizeSubchannel_r14==8 | h.sizeSubchannel_r14==9|...
                h.sizeSubchannel_r14==10 | h.sizeSubchannel_r14==12 | h.sizeSubchannel_r14==15  | h.sizeSubchannel_r14==16 | h.sizeSubchannel_r14==18|...
                h.sizeSubchannel_r14==20 | h.sizeSubchannel_r14==25 | h.sizeSubchannel_r14==30  | h.sizeSubchannel_r14==48 | h.sizeSubchannel_r14==50|...
                h.sizeSubchannel_r14==72 | h.sizeSubchannel_r14==75 | h.sizeSubchannel_r14==96  | h.sizeSubchannel_r14==100, ...
                'Invalid sizeSubchannel-r14 size. Valid values: {4, 5, 6, 8, 9, 10, 12, 15, 16, 18, 20, 25, 30, 48, 50, 72, 75, 96, 100}');

                if isfield(slCommConfig,'numSubchannel_r14')
                    h.numSubchannel_r14 = slCommConfig.numSubchannel_r14;
                else % default
                    h.numSubchannel_r14 = 1;
                end                
                assert(h.numSubchannel_r14==1 | h.numSubchannel_r14==3 | h.numSubchannel_r14==5  | h.numSubchannel_r14==10 | h.numSubchannel_r14==15 | h.numSubchannel_r14==20,...
                    'Invalid numSubchannel_r14 size. Valid values: {1, 3, 5, 10, 15, 20}');
                
                if isfield(slCommConfig,'startRB_Subchannel_r14')
                    h.startRB_Subchannel_r14 = slCommConfig.startRB_Subchannel_r14;
                else % default
                    h.startRB_Subchannel_r14 = 0;
                end
                assert(h.startRB_Subchannel_r14>=0 & h.startRB_Subchannel_r14<=99,'Invalid setting of sl-startRB_Subchannel_r14. Valid range: 0..99');
                
                % extra assertion for respecting total bandwidth
                if h.startRB_Subchannel_r14 + h.numSubchannel_r14*h.sizeSubchannel_r14 - 1 > h.NSLRB
                    fprintf('Error in PSSCH Pool Definition. Check  startRB_Subchannel_r14, numSubchannel_r14, sizeSubchannel_r14 parameters\n');
                    keyboard;
                end
            
                if isfield(slCommConfig,'adjacencyPSCCH_PSSCH_r14')
                    h.adjacencyPSCCH_PSSCH_r14 = slCommConfig.adjacencyPSCCH_PSSCH_r14;
                else % default
                    h.adjacencyPSCCH_PSSCH_r14 = true;
                end
                assert(h.adjacencyPSCCH_PSSCH_r14==true | h.adjacencyPSCCH_PSSCH_r14==false,'Invalid setting of adjacencyPSCCH_PSSCH_r14. Valid range: {true,false}');
                
                if isequal(h.adjacencyPSCCH_PSSCH_r14,false) % the following field is relevant only for non-adjacent pscch/pssch
                    if isfield(slCommConfig,'startRB_PSCCH_Pool_r14')
                        h.startRB_PSCCH_Pool_r14 = slCommConfig.startRB_PSCCH_Pool_r14;
                    else % default
                        h.startRB_PSCCH_Pool_r14 = 0;
                    end
                    assert(h.startRB_PSCCH_Pool_r14>=0 & h.startRB_PSCCH_Pool_r14<=99,'Invalid setting of sl-startRB_PSCCH_Pool_r14. Valid range: 0..99');                    
                end
            end % d2d or v2x mode 
                        
            % --------------------------- UE-specific comm config inputs ---------------------------
            slUEconfig = varargin{4};
            if isequal(h.slMode,1)
                if isfield(slUEconfig,'nPSCCH')
                    h.nPSCCH = slUEconfig.nPSCCH;
                else % default
                    h.nPSCCH = [];
                end
                % assertion for nPSCCH at a later stage (in GetResourcesPerUE)
                
                if isfield(slUEconfig,'HoppingFlag')
                    h.HoppingFlag = slUEconfig.HoppingFlag;
                    for i=1:length(h.HoppingFlag)
                        if isequal(h.HoppingFlag(i),1)
                            fprintf('Hopping resource allocation not supported yet\n'); keyboard;
                        end
                    end
                else % default
                    h.HoppingFlag = [];
                end
                
                if isfield(slUEconfig,'RBstart')
                    h.RBstart = slUEconfig.RBstart;
                else % default
                    h.RBstart = [];
                end
                % assertion expression for RBstart to be added
                
                if isfield(slUEconfig,'Lcrbs')
                    h.Lcrbs = slUEconfig.Lcrbs;
                else % default
                    h.Lcrbs = [];
                end
                % assertion expression for Lcrbs to be added
                
                if isfield(slUEconfig,'ITRP')
                    h.ITRP = slUEconfig.ITRP;
                else % default
                    h.ITRP = [];
                end
                
                if isfield(slUEconfig,'mcs_r12')
                    h.mcs_r12 = slUEconfig.mcs_r12;
                    for i = 1:length(h.mcs_r12)
                        assert(h.mcs_r12(i)>=0 & h.mcs_r12(i)<=28,'Invalid setting of mcs-r12. Valid range: 0..28');
                    end
                else % default
                    h.mcs_r12 = [];
                end
                
                if isfield(slUEconfig,'nSAID')
                    h.nSAID = slUEconfig.nSAID;
                    for i = 1:length(h.nSAID)
                        assert(h.nSAID(i)>=0 & h.nSAID(i)<=255,'Invalid setting of nSAID. Valid range: 0..255 (8-bits)');
                    end
                else % default
                    h.nSAID = [];
                end
            
            elseif isequal(h.slMode,2)
                fprintf('Sidelink communication mode 2 (autonomous) not fully supported yet\n');
                
            elseif isequal(h.slMode,3)
                %fprintf('Sidelink V2X communication mode 3 (scheduled) not fully supported yet\n');
                if isfield(slUEconfig,'mcs_r14')
                    h.mcs_r14 = slUEconfig.mcs_r14;
                    for i = 1:length(h.mcs_r14)
                        assert(h.mcs_r14(i)>=0 & h.mcs_r14(i)<=31,'Invalid setting of mcs-r14. Valid range: 0..31');
                    end
                else % default
                    h.mcs_r14 = 10;
                end
                
                 %fprintf('Sidelink V2X communication mode 3 (scheduled) not fully supported yet\n');
                if isfield(slUEconfig,'m_subchannel')
                    h.m_subchannel = slUEconfig.m_subchannel;
                    for i = 1:length(h.m_subchannel)
                        assert(h.m_subchannel(i)<h.numSubchannel_r14,'PSCCH resource m not valid');
                    end
                else % default
                    h.m_subchannel = [];
                end
                
                if isfield(slUEconfig,'LsubCH')
                    h.LsubCH = slUEconfig.LsubCH;                    
                else % default
                    h.LsubCH = [];
                end
                
                if isfield(slUEconfig,'nsubCHstart')
                    h.nsubCHstart = slUEconfig.nsubCHstart;      
                    for i = 1:length(h.nsubCHstart)
                        assert(h.m_subchannel(i)+h.LsubCH(i)-1<h.numSubchannel_r14,'PSCCH resource m not valid');                        
                    end
                else % default
                    h.nsubCHstart = [];
                end
                
                if isfield(slUEconfig,'SFgap')
                    h.SFgap = slUEconfig.SFgap;                    
                else % default
                    h.SFgap = [];
                end
                
            elseif isequal(h.slMode,4)
                fprintf('Sidelink communication mode 4 (autonomous) not fully supported yet\n');
                
            end % slmode (scheduled mode)
            
            % tx/rx mode
            if nargin == 4                
                h.TransceiverMode = 'Tx';
            elseif nargin == 5
               h.TransceiverMode = varargin{5};
            end
            assert(isequal(h.TransceiverMode,'Tx') | isequal(h.TransceiverMode,'Rx'),'Invalid TransceiverMode. Select from {Tx,Rx}');
            
            % ----------------------- dimensioning ------------------------         
            % phy conf
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
            elseif strcmp(h.cp_Len_r12,'Extended')
                h.cpLen0 = round(0.25*h.NFFT);
                h.cpLenR = round(0.25*h.NFFT);
            end
            
            % basic phy dimensioning
            if strcmp(h.cp_Len_r12,'Normal')
                h.NSLsymb = 7;
                if isequal(h.slMode,1) || isequal(h.slMode,2)
                    h.PSCCH_DMRS_symbloc_perSubframe = [3 10]';
                    h.PSCCH_symbloc_perSubframe      = [0 1 2 4 5 6 7 8 9 11 12 13]';
                elseif isequal(h.slMode,3) || isequal(h.slMode,4) % only normal mode for v2x
                    h.PSCCH_DMRS_symbloc_perSubframe = [2 5 8 11]';
                    h.PSCCH_symbloc_perSubframe      = [0 1 3 4 6 7 9 10 12 13]';
                end
            elseif strcmp(h.cp_Len_r12,'Extended')
                h.NSLsymb = 6;
                h.PSCCH_DMRS_symbloc_perSubframe = [2 8]';
                h.PSCCH_symbloc_perSubframe      = [0 1 3 4 5 6 7 9 10 11]';                
            end
            h.samples_per_subframe = 2*h.NSLsymb*h.NFFT + 2*h.cpLen0 + 2*(h.NSLsymb-1)*h.cpLenR;
             
            % PSSCH phy dimensioning same as PSCCH
            h.PSSCH_DMRS_symbloc_perSubframe = h.PSCCH_DMRS_symbloc_perSubframe;
            h.PSSCH_symbloc_perSubframe      = h.PSCCH_symbloc_perSubframe;
            % number of subframes used for pssch
            if isequal(h.slMode, 1) || isequal(h.slMode, 2)
                h.PSSCH_PHY_NSFs = 4;
            elseif isequal(h.slMode, 3) || isequal(h.slMode, 4)
                h.PSSCH_PHY_NSFs = 1;
            end
            
            % SCI/PSCCH
            if isequal(h.slMode,1) || isequal(h.slMode,2) % d2d
                % 36.212 - 5.4.3.1.1
                h.sci0_TBsize = 1 + ceil(log2(h.NSLRB*(h.NSLRB+1)/2)) + 7 + 5 + 11 + 8;
                % 36.213/14.2.1
                h.Msc_PSCCH = 2*h.NRBsc; % a pair of PRB/Subframe resources is used for PSCCH (2 subframes x 1 PRB/subframe)
                % PUSCH interleaver setting (36.212-5.4.3)
                h.cmux = 2*(h.NSLsymb-1);                 
                % DMRS sequences computation
                pscch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pscch_mode',num2str(h.slMode)),'N_PRB', 1));
                h.pscch_dmrs_seq = pscch_dmrs_obj.DMRS_seq();
            elseif isequal(h.slMode,3) || isequal(h.slMode,4) % v2x
                % 36.212/5.4.3.1.2
                h.sci1_TBsize = 32;
                % 36.213/14.2.4
                h.Msc_PSCCH = 2*h.NRBsc; % a pair of PRB/Subframe resources is used for PSCCH (1 subframe x 2 PRBs/subframe).
                % PUSCH interleaver setting  (36.212-5.4.3)
                h.cmux = 2*(h.NSLsymb-2);
                % DMRS sequences computation (NCS SELECTION NOT IMPLEMENTED YET!!! Set it arbitrarily to 0)
                pscch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pscch_mode',num2str(h.slMode)),'N_PRB', 2, 'NCS', 0));
                h.pscch_dmrs_seq = pscch_dmrs_obj.DMRS_seq();
                h.frlbitmap_len = ceil(log2(h.numSubchannel_r14*(h.numSubchannel_r14+1)/2));
            
            end
            % PSCCH Bit Capacity x2 due to QPSK
            h.pscch_BitCapacity = h.Msc_PSCCH*length(h.PSCCH_symbloc_perSubframe) * 2;                
            % obtain interleaver indices
            % indices needed for PUSCH interleaving (36.212 5.2.2.7 / 5.2.2.8)
            % Inputs: length of f0_seq, h.cmux for SL, 2 for QPSK, 1 for single-layer
            h.pscch_muxintlv_indices =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.pscch_BitCapacity, h.cmux, 2, 1 );
            % generate scramb-seq: initialized at the start of each subframe with c_init = 510 (36.211, 9.4.1)
            h.pscch_b_scramb_seq = phy_goldseq_gen (h.pscch_BitCapacity, h.pscch_c_init);
            
             % -------------------------- initializations --------------------------
             %Extract communication resource pool for given input configuration
             if isequal(h.slMode,1) || isequal(h.slMode,2) % d2d                 
                 h = GetCommResourcePool(h);
                 
                 if isequal(h.TransceiverMode,'Tx')
                     %Extract UE-specific control and data resource allocation
                     [h.m_PSCCH_selected, h.l_PSCCH_selected] = Get_Control_ResourcesPerUE(h);
                     [h, h.m_PSSCH_selected, h.l_PSSCH_selected, h.pssch_prbs_ra_bitmap] = Get_Data_ResourcesPerUE(h);
                     %Get sync subframes and check for conflicts
                     h.subframes_SLSS  = GetSyncResources (h);
                 elseif isequal(h.TransceiverMode,'Rx')
                     % Extract only UE-specific control resource allocation based on given search space.
                     % Data resource allocation depends on acquired SCIs                     
                     [h.m_PSCCH_selected, h.l_PSCCH_selected] = Get_Control_ResourcesPerUE(h);                     
                 end                
             elseif isequal(h.slMode,3) || isequal(h.slMode,4) % v2v
                 h = GetV2XCommResourcePool(h);
                 if isequal(h.TransceiverMode,'Tx')
                     %Extract UE-specific control and data resource allocation
                     h = Get_V2X_Control_ResourcesPerUE(h);
                     h = Get_V2X_Data_ResourcesPerUE(h);                     
                 elseif isequal(h.TransceiverMode,'Rx')
                     % Extract only UE-specific control resource allocation
                     % Data resource allocation depends on acquired SCIs 
                     h = Get_V2X_Control_ResourcesPerUE(h);
                 end
             end
             
        end % function: SL_Communication constructor
        
        function h = GetCommResourcePool(h)
            %Extract standard d2d communication resource pool for given input configuration ((36.213 - 14.2.3, 14.1.3, 14.1.4)
            % Inputs used: scPeriod_r12, offsetIndicator_r12, subframeBitmap_r12, prb_Start_r12, prb_Num_r12, prb_End_r12
            % * for v2x there is a different function defined.
            
            fprintf('=======================================================\n');
            fprintf('PSCCH and PSSCH COMMUNICATION RESOURCES POOL FORMATION \n');
            fprintf('=======================================================\n');
            
            % 36.213 - 14.2.3
            % Assume a single Communication Period
            h.CommPer = [h.offsetIndicator_r12, h.offsetIndicator_r12+h.scPeriod_r12-1];
            fprintf('Communication Period starts @ subframe #%i and ends at subframe #%i\n',h.CommPer(1),h.CommPer(2));
            
            % PSCCH Subframe Pool: 36.213 - 14.2.3
            sf_ControlCandidates = (0:1:h.commSubframeBitmapSize-1)'; %Select the first N' = commSubframeBitmapSize subframes
            h.ls_PSCCH_RP = sf_ControlCandidates(h.subframeBitmap_r12(mod(sf_ControlCandidates,h.commSubframeBitmapSize)+1)==1);
            h.ls_PSCCH_RP = h.ls_PSCCH_RP + h.CommPer(1);
            fprintf('PSCCH Subframe pool (total %i subframes)\n',length(h.ls_PSCCH_RP));
            fprintf('( PSCCH Subframes : '); fprintf('%i ',h.ls_PSCCH_RP); fprintf(')\n');
            
            % PSSCH Subframe Pool: 36.213 - 14.1.3/14.1.4
            % subframes: depends on mode
            if isequal(h.slMode,1) % 'scheduled': 36.213 - 14.1.4
                % Each uplink subframe with subframe index greater than or equal to l_LPSCCH + 1 belongs to the subframe pool for PSSCH
                sf_DataCandidates = (h.ls_PSCCH_RP(end)+1:1:h.CommPer(1)+h.scPeriod_r12-1)';
            elseif isequal(h.slMode,2) % 'ue-selected': 36.213 - 14.1.3
                % Allocation does not depend on Control bitmap. Use a fixed
                % offset. Here we just take the first subframe after the PSCCH pool ends.
                sf_DataCandidates = (h.CommPer(1)+h.commSubframeBitmapSize:1:h.CommPer(1)+h.scPeriod_r12-1)';
            end
            h.ls_PSSCH_RP = sf_DataCandidates(h.subframeBitmap_r12(mod(sf_DataCandidates,h.commSubframeBitmapSize)+1)==1);
            if isempty(h.ls_PSSCH_RP), fprintf('No PSSCH subframe resources available. Check parametrization\n'); keyboard; end
            fprintf('PSSCH Subframe pool (total %i subframes)\n',length(h.ls_PSSCH_RP));
            fprintf('( PSSCH Subframes : '); fprintf('%i ',h.ls_PSSCH_RP); fprintf(')\n');
            % check: 14.1.1.1: number of pssch subframes should be a multiple of 4
            if mod(length(h.ls_PSSCH_RP),4)~= 0
                fprintf('Error: Number of pssch subframes is not a multiple of 4.  Check parametrization\n'); keyboard;
            end
            
            % PSCCH/PSSCH PRB pools (common)
            % PRB POOL FEASIBILITY checking and DEFINITION
            if h.prb_Start_r12 + h.prb_Num_r12 - 1 >= h.prb_End_r12 - h.prb_Num_r12 + 1 || h.prb_End_r12 >= h.NSLRB
                fprintf('Error in PRB pool definition (bottom prb range = %i:%i, top prb range = %i:%i). Check prb_Start_r12, prb_Num_r12, prb_End_r12 \n',...
                    h.prb_Start_r12, h.prb_Start_r12 + h.prb_Num_r12 - 1, h.prb_End_r12 - h.prb_Num_r12 + 1,  h.prb_End_r12); keyboard
            else % ok to proceed
                h.ms_PSCCH_RP = [h.prb_Start_r12:h.prb_Start_r12 + h.prb_Num_r12 - 1, h.prb_End_r12 - h.prb_Num_r12 + 1: h.prb_End_r12]';
                h.ms_PSSCH_RP = h.ms_PSCCH_RP;
                fprintf('PSCCH/PSSCH PRB pools : Bottom prb range = %i:%i, Top prb range = %i:%i (total = %i PRBs)\n',...
                    h.prb_Start_r12,h.prb_Start_r12 + h.prb_Num_r12 - 1,h.prb_End_r12 - h.prb_Num_r12 + 1, h.prb_End_r12, length(h.ms_PSCCH_RP));
            end
        end % function: GetCommResourcePool
     
        function subframes_sync = GetSyncResources (h)
            %Get subframe resources for transmitting/receiving SL-SSs (36.331 - 5.10.7)
            % initialization
            subframes_sync = [];
            if h.networkControlledSyncTx == 1
                subframes_in_currentDiscPer = (h.CommPer(1): h.CommPer(2))';
                subframes_sync =  subframes_in_currentDiscPer(mod(subframes_in_currentDiscPer, h.syncPeriod) == h.syncOffsetIndicator);
                % non-periodic adjustment: keep first only
                if ~h.syncTxPeriodic, subframes_sync = subframes_sync(1); end
                % check for conflict of SLSS and PSCCH/PSSCH
                for slssix = 1:length(subframes_sync)
                    if ismember(subframes_sync(slssix), h.ls_PSCCH_RP) ||...
                            ismember(subframes_sync(slssix), h.ls_PSSCH_RP)
                        fprintf('Check for possible SLSS and PSCCH/PSSCH conflict in subframe #%i\n', subframes_sync(slssix));
                    end
                end
            end % syncConfig.networkControlledSyncTx
            fprintf('=======================================================\n');
            fprintf('Reference Subframes \n');
            fprintf('=======================================================\n');
            fprintf('( SLSS Subframes : '); fprintf('%i ',subframes_sync); fprintf(')\n');            
        end % function : GetSyncResources
        
        function [m_PSCCH_selected, l_PSCCH_selected] = Get_Control_ResourcesPerUE(h) 
            %Extract UE-specific control channel (pscch) resource allocation
            
            m_PSCCH_selected = [];
            l_PSCCH_selected = [];

            fprintf('=======================================================\n');
            fprintf('UE-specific Control Channel (PSCCH) Resource Allocation \n');
            fprintf('=======================================================\n');
            
            % 36.213/14.2.1 Each SCI0 message is transmitted in two subframes and one PRB per slot
            L_PSCCH_RP = length(h.ls_PSCCH_RP);
            M_PSCCH_RP = length(h.ms_PSCCH_RP);
            nPSCCH_max = floor(M_PSCCH_RP/2)*L_PSCCH_RP-1;
            
            % nPSCCH should be set now           
            if isequal(h.slMode,1) % 36.213 - 14.2.1.1
                % no action: nPSCCH is already set through DCI-5
            elseif isequal(h.slMode, 2) % 36.213 - 14.2.1.2
                % select a single nPSCCH randomly
                nPSCCH_Space = (0:1:nPSCCH_max-1)';
                %rng(0);
                tmp = randperm(length(nPSCCH_Space));
                h.nPSCCH = nPSCCH_Space(tmp(1));
            end
            
            % after nPSCCH set we are ready to find PSCCH time/freq
            % resources. For each intend comm session we need two subframes
            % and one prb per subframe            
            num_of_comms = length(h.nPSCCH);
            m_PSCCH_selected   = cell(num_of_comms,1); % selected PRBs for each comm
            l_PSCCH_selected   = cell(num_of_comms,1); % selected subframes for each comm
            for i = 1:num_of_comms
                n_PSCCH = h.nPSCCH(i);
                if n_PSCCH <0 || n_PSCCH>nPSCCH_max
                    % assertion
                    fprintf('Invalid setting of nPSCCH. Valid range: 0..%i',nPSCCH_max); keyboard;
                else
                    % PRB-indices
                    a1 = floor(n_PSCCH/L_PSCCH_RP);
                    a2 = floor(n_PSCCH/L_PSCCH_RP) + floor(M_PSCCH_RP/2);
                    % Subframe-indices
                    b1 = mod(n_PSCCH, L_PSCCH_RP);
                    b2 = mod(n_PSCCH + 1 + mod(floor(n_PSCCH/L_PSCCH_RP), L_PSCCH_RP-1), L_PSCCH_RP);
                    %RESOURCES_PSCCH = {[h.ms_PSCCH_RP(a1+1); h.ls_PSCCH_RP(b1+1)] ; [h.ms_PSCCH_RP(a2+1); h.ls_PSCCH_RP(b2+1)]};
                    m_PSCCH_selected{i} = [h.ms_PSCCH_RP(a1+1);h.ms_PSCCH_RP(a2+1)];
                    l_PSCCH_selected{i} = [h.ls_PSCCH_RP(b1+1); h.ls_PSCCH_RP(b2+1)];
                    
                    fprintf('PSCCH Resource Allocation for UE with nPSCCH = %i (max: %i):\n', n_PSCCH, nPSCCH_max);
                    fprintf('\tRESOURCE #1 : PRB %2i, SUBFRAME %2i\n', m_PSCCH_selected{i}(1),  l_PSCCH_selected{i}(1));
                    fprintf('\tRESOURCE #2 : PRB %2i, SUBFRAME %2i\n', m_PSCCH_selected{i}(2),  l_PSCCH_selected{i}(2));
                end 
            end % comm sessions
                
        end % function : Get_Control_ResourcesPerUE
        
        function [h, m_PSSCH_selected, l_PSSCH_selected, pssch_prbs_ra_bitmap] = Get_Data_ResourcesPerUE(h)
            %Extract UE-specific data channel (pssch) resource allocation
            
            m_PSSCH_selected = [];
            l_PSSCH_selected = [];
            pssch_prbs_ra_bitmap = [];
            
            fprintf('=====================================================\n');
            fprintf('UE-specific Data Channel (PSSCH) Resource Allocation \n');
            fprintf('=====================================================\n');
            
            % --------------- SUBFRAME ASSIGNMENT: map Itrp to subframe indicator bitmap: 14.1.1.1.1 ---------------
            % set possible space
            load('3GPP_36213_Table14_1_1_1_1_1_1.mat','raw');
            I_trps_IXs = -ones(size(raw,1),1);
            b_primes = -ones(size(raw,1),8);
            k_TRPs = -ones(length(I_trps_IXs),1);
            for i=1:length(I_trps_IXs)
                I_trps_IXs(i,1) = raw{i,1};
                b_primes(i,:) = str2num(raw{i,2});
                k_TRPs(i,1) = sum(b_primes(i,:));
            end
            
            % select profile depending on communication mode
            if isequal(h.slMode, 1) % 36.213 - 14.1.1.1/14.1.1.2
                % ITRP already set from input
            elseif isequal(h.slMode, 2) % 36.213 - 14.1.1.3/14.1.1.4
                %fprintf('Sidelink Communications Mode 2 not fully supported yet\n'); keyboard
                %%% not fully supported yet
                %possible_kTRPs = [1; 2; 4];
                %acceptable_kTRPs = possible_kTRPs(h.trpt_Subset_r12==1);
                %acceptable_ITRPIXs = [];
                %for aktrpix = 1:length(acceptable_kTRPs)
                %    acceptable_ITRPIXs = [acceptable_ITRPIXs; find(k_TRPs==acceptable_kTRPs(aktrpix))];
                %end
                %rng(1); %rng shuffle;
                %tmp = randperm(length(acceptable_ITRPIXs));
                %h.ITRP = I_trps_IXs( acceptable_ITRPIXs(tmp(1)) );
            end
            
            % calculate subframes for each comm session
            num_of_comms = length(h.nPSCCH);
            l_PSSCH_selected   = cell(num_of_comms,1); % selected subframes for each comm
            for i = 1:num_of_comms
                I_TRP = h.ITRP(i);
                if I_TRP <0 || I_TRP>106
                    % assertion
                    fprintf('Invalid setting of I_TRP. Valid range: 0..106'); keyboard;
                else
                    b_prime = b_primes(I_TRP==I_trps_IXs,:)';
                    NTRP = length(b_prime);
                    % assign bitmap
                    L_PSSCH_RP = length(h.ls_PSSCH_RP);
                    b = -ones(L_PSSCH_RP,1);
                    b(:,1) = b_prime(mod((0:L_PSSCH_RP-1),NTRP)+1,1);
                    % get subframes
                    l_PSSCH_selected{i} = h.ls_PSSCH_RP(b==1);
                    % keep only first h.PSSCH_PHY_NSFs subframes needed for
                    % transmitting a pssch subframe
                    l_PSSCH_selected{i} = l_PSSCH_selected{i}(1:h.PSSCH_PHY_NSFs);
                    
                    % print message
                    fprintf('PSSCH SUBFRAME Allocation for UE (with I_trp = %i): Total %i subframes, First %i, Last: %i\n',  h.ITRP(i), length(l_PSSCH_selected{i} ), l_PSSCH_selected{i}(1), l_PSSCH_selected{i}(end));
                    fprintf('( PSSCH Subframes : '); fprintf('%i ',l_PSSCH_selected{i}); fprintf(')\n');
                end
            end
            
            % --------------------------- PRB assignment ------------------------------------------------
            m_PSSCH_selected   = cell(num_of_comms,1); % selected PRBs for each comm
            pssch_prbs_ra_bitmap = cell(num_of_comms,1);
            if isequal(h.slMode, 1)       % 14.1.1.2.1 (mode-1)
                % scheduled PRBs
                for i = 1:num_of_comms
                    m_PSSCH_selected{i} = (h.RBstart(i):h.RBstart(i)+h.Lcrbs(i)-1)';
                    pssch_prbs_ra_bitmap{i} = ra_bitmap_resourcealloc_create(h.NSLRB, h.RBstart(i), h.Lcrbs(i));
                end
                
            elseif isequal(h.slMode, 2) % 14.1.1.4   (mode-2)
                fprintf('PSSCH PRB Allocation for Autonomous Mode not fully implemented yet\n');
            end
            
            
            % ---------------------- DIMENSIONING & DMRS ------------------
            
            % SL-SCH/PSSCH
            % determine modulation order (Qprime) and TBS index based on input mcs: 36.213/Table 8.6.1-1 (Notice that Qmprime <= 4 for SIDELINK)
            h.pssch_TBsize = -ones(num_of_comms,1); 
            h.pssch_Qprime = -ones(num_of_comms,1); 
            h.pssch_BitCapacity = -ones(num_of_comms,1); 
            h.Msc_PSSCH = -ones(num_of_comms,1);
            h.pssch_muxintlv_indices = {};
            for i = 1:num_of_comms                
                load('3GPP_36213_Table8_6_1_1.mat','raw');
                ITBS_ix = (raw(:,1)==h.mcs_r12(i));
                h.pssch_Qprime(i) = min( 4, raw(ITBS_ix,2) );
                ITBS = raw(ITBS_ix,3);
                % determine TBS based on ITBS and NPRB: 36.213/Table 7.1.7.2.1s
                load('3GPP_36213_Table7_1_7_2_1_1','raw');
                NPRBs = h.Lcrbs(i);
                h.Msc_PSSCH(i) = NPRBs.*h.NRBsc*h.PSSCH_PHY_NSFs;
                h.pssch_TBsize(i) = raw(raw(:,1)==ITBS,raw(1,:)==NPRBs);
                h.pssch_BitCapacity(i) = h.Msc_PSSCH(i)*length(h.PSSCH_symbloc_perSubframe) * h.pssch_Qprime(i);  % length of PSSCH sequence in bits
                fprintf('[UE %i] PSSCH Transport Block Size = %i bits (Mod Order : %i).\n', h.nPSCCH(i), h.pssch_TBsize(i), h.pssch_Qprime(i));
                fprintf('\tPSSCH Bit Capacity = %i bits  (Symbol Capacity = %i samples).\n', h.pssch_BitCapacity(i), h.pssch_BitCapacity(i)/ h.pssch_Qprime(i));                
                % other dimensioninf issues
                % pusch interleaving indices (36.212 - 5.4.2)
                h.pssch_muxintlv_indices{i} =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.pssch_BitCapacity(i), h.cmux, 2, 1 );
            end
                
        end % function : Get_Data_ResourcesPerUE
       
        function h = GetV2XCommResourcePool (h)
            %Calculate v2x communication resource pools for given input configuration (36.213 - 14.1.5/14.2.4)
            fprintf('===========================================================\n');
            fprintf('PSCCH and PSSCH V2X COMMUNICATION RESOURCES POOL FORMATION \n');
            fprintf('===========================================================\n');
            
            % Assume a period containing a multiple of bitmaps duration (e.g. 10)
            h.CommPer = [h.sl_OffsetIndicator_r14, h.sl_OffsetIndicator_r14+10*length(h.sl_Subframe_r14)-1];
            fprintf('V2X Communication Period starts @ subframe #%i and ends at subframe #%i\n',h.CommPer(1),h.CommPer(2));
            
            % -------------- PSxCH Subframe Pools (common for control/data) Determination (36.213 - 14.1.5) --------------            
            kmax = h.CommPer(2); % max subframe index
            if h.v2xSLSSconfigured, d = 64; else, d = 0; end
            kmax = min(kmax, 10239-d);
            potential_subframes = (0:1:kmax)';
            % apply bitmap
            b = h.sl_Subframe_r14(mod(potential_subframes-h.sl_OffsetIndicator_r14,length(h.sl_Subframe_r14))+1)==1;
            b(potential_subframes<h.sl_OffsetIndicator_r14) = 0;
            
            % slss subframes consideration
            h.subframes_SLSS = [];
            if h.networkControlledSyncTx == 1
                h.subframes_SLSS = (h.syncOffsetIndicator:h.syncPeriod:h.CommPer(2))';
                if ~h.syncTxPeriodic, h.subframes_SLSS = h.subframes_SLSS(1); end
            end
            fprintf('( SLSS Subframes : '); fprintf('%i ',h.subframes_SLSS); fprintf(')\n');
            % remove subframes for slss
            b(h.subframes_SLSS+1) = 0;
            
            % form subframe pool
            h.ls_PSCCH_RP = potential_subframes(b);
            h.ls_PSSCH_RP = h.ls_PSCCH_RP; % common
            fprintf('V2X PSxCH Subframe pool (total %i subframes)\n',length(h.ls_PSCCH_RP));
            fprintf('( V2X PSxCH Subframes : '); fprintf('%i ',h.ls_PSCCH_RP); fprintf(')\n');
            
            % ---------------------------------- PRB pools (different for control/data  --------------------------------------
            % PSSCH PRB pool (14.1.5)
            h.ms_PSSCH_RP = cell(h.numSubchannel_r14,1);
            for m = 0:size(h.ms_PSSCH_RP,1)-1
                h.ms_PSSCH_RP{m+1,1} = h.startRB_Subchannel_r14 + m*h.sizeSubchannel_r14 + (0:h.sizeSubchannel_r14-1)';
            end
            fprintf('V2X PSSCH PRB Pool contains %2i subchannels, of size %2i PRBs each, with lowest PRB index of subchannel #0 = %2i\n',...
                h.numSubchannel_r14, h.sizeSubchannel_r14, h.ms_PSSCH_RP{1}(1));
            for i=1:length(h.ms_PSSCH_RP)
                fprintf('\t[Subchannel %2i] PRBs : ',i-1); fprintf('%2i ',h.ms_PSSCH_RP{i}); fprintf('\n');
            end
            
            % PSCCH PRB pool (14.2.4)
            h.ms_PSCCH_RP = cell(h.numSubchannel_r14,1);
            if h.adjacencyPSCCH_PSSCH_r14
                % keep first two PRBs of PSSCH pool
                for m = 0:size(h.ms_PSCCH_RP,1)-1
                    h.ms_PSCCH_RP{m+1,1} = h.ms_PSSCH_RP{m+1}(1:2)';
                end
            else
                % independent pool
                for m = 0:size(h.ms_PSCCH_RP,1)-1
                    h.ms_PSCCH_RP{m+1,1} = h.startRB_PSCCH_Pool_r14 + 2*m + (0:1)';
                end
            end
            fprintf('V2X PSCCH PRB Pool contains %2i subchannels, of size  2 PRBs each, with lowest PRB index of subchannel #0 = %2i\n',...
                h.numSubchannel_r14, h.ms_PSCCH_RP{1}(1));
            for i=1:length(h.ms_PSCCH_RP)
                fprintf('\t[Subchannel %2i] PRBs : ',i-1); fprintf('%2i ',h.ms_PSCCH_RP{i}); fprintf('\n');
            end
                        
            
        end % function : GetV2XCommResourcePool
        
        function h = Get_V2X_Control_ResourcesPerUE(h)
            %Extract UE-specific control channel (pscch) resource allocation for V2X sidelink communication
            
            fprintf('============================================================\n');
            fprintf('UE-specific Control Channel (PSCCH) V2X Resource Allocation \n');
            fprintf('============================================================\n');
            
            num_of_comms = length(h.m_subchannel);
            h.l_PSCCH_selected = cell(num_of_comms,1);
            h.m_PSCCH_selected  = cell(num_of_comms,1);
            h.v2x_frlbitmap = cell(num_of_comms,1);

            for i = 1:num_of_comms            
                % for each transmission opportunity
                for txOp = 1:h.SFgap(i)+1
                    if txOp == 1
                        tn_SL = h.ls_PSCCH_RP(2*i-1); % arbitrarily select the (2*i-1) available subframe 
                        h.l_PSCCH_selected{i}(txOp,1) = tn_SL;    
                        h.m_PSCCH_selected{i}(txOp,:) = h.ms_PSCCH_RP{h.m_subchannel(i)+1}; % +1 due to 0-indexing
                    elseif txOp == 2
                        tn_SL_Retx = h.ls_PSCCH_RP((2*i-1)+h.SFgap(i));
                        h.l_PSCCH_selected{i}(txOp,1) = tn_SL_Retx;
                        h.m_PSCCH_selected{i}(txOp,:) = h.ms_PSCCH_RP{h.nsubCHstart(i)+1}; % +1 due to 0-indexing
                    end
                end % txOp
                % print allocation info
                fprintf(' PSCCH Subframes for user %i : ',i); fprintf('%i ',h.l_PSCCH_selected{i}); fprintf('\n'); 
                for txOp = 1:h.SFgap(i)+1
                    fprintf(' PSCCH PRBs for user %i (txOp = %i): ',i, txOp); fprintf('%i ', h.m_PSCCH_selected{i}(txOp, :)); fprintf('\n'); 
                end
                % calc frl bitmap
                h.v2x_frlbitmap{i} = ra_bitmap_resourcealloc_create(h.numSubchannel_r14, h.nsubCHstart(i), h.LsubCH(i));
                % define nXID
                h.nXID = -ones(num_of_comms,1);
            end % v2x users      
        end % function
        
        function h = Get_V2X_Data_ResourcesPerUE(h)
            %Extract UE-specific data channel (pscch) resource allocation for V2X sidelink communication
                 
            fprintf('=========================================================\n');
            fprintf('UE-specific Data Channel (PSSCH) V2X Resource Allocation \n');
            fprintf('=========================================================\n');
            
            num_of_comms = length(h.m_subchannel);
            h.l_PSSCH_selected = cell(num_of_comms,1);
            h.m_PSSCH_selected  = cell(num_of_comms,1);
            
            % SUBFRAMES : same allocation with PSCCH
            h.l_PSSCH_selected = h.l_PSCCH_selected;
            
            % dimensioning params
            h.pssch_TBsize = -ones(num_of_comms,1);
            h.pssch_Qprime = -ones(num_of_comms,1);
            h.pssch_BitCapacity = -ones(num_of_comms,1);
            h.Msc_PSSCH = -ones(num_of_comms,1);
            h.pssch_muxintlv_indices = {};
            
             
            % PRBs
            for i = 1:num_of_comms            
                % for each transmission opportunity
                for txOp = 1:h.SFgap(i)+1
                    %h.m_PSCH_selected{i}(txOp,:) = [];
                    tmp = [];
                    if txOp == 1                        
                        for ii = h.m_subchannel(i):1:h.m_subchannel(i)+h.LsubCH(i)-1
                            tmp = [tmp; h.ms_PSSCH_RP{ii+1}];
                        end
                    elseif txOp == 2
                        for ii = h.nsubCHstart(i):1:h.nsubCHstart(i)+h.LsubCH(i)-1
                            tmp = [tmp; h.ms_PSSCH_RP{ii+1}];
                        end                                    
                    end
                    % if pscch/pssch adjacency is activated then remove first two prbs of each pssch pool
                    if h.adjacencyPSCCH_PSSCH_r14
                        tmp = tmp(3:end);
                    end;
                    h.m_PSSCH_selected{i}(txOp,:) = tmp;  
                end % txOp
               
                % print allocation info
                fprintf(' PSSCH Subframes for user %i : ',i); fprintf('%i ',h.l_PSSCH_selected{i}); fprintf('\n'); 
                for txOp = 1:h.SFgap(i)+1
                    fprintf(' PSSCH PRBs for user %i (txOp = %i): ',i, txOp); fprintf('%i ', h.m_PSSCH_selected{i}(txOp, :)); fprintf('\n'); 
                end
                % update phy dim
                h = Get_V2X_PSSCH_Dimensioning(h, h.mcs_r14(i), length(h.m_PSSCH_selected{i}(txOp,:)), i);
                
            end % v2x users
            
        end % function : Get_V2X_Data_ResourcesPerUE
        
        
        function h = Get_V2X_PSSCH_Dimensioning(h, mcs, NPRBs, userIndex)
            % determines basic phy dimensioning
            
            % ---------------------------------------------  SL-SCH/PSSCH dimensioning ------------------------------------------------------
            % determine modulation order (Qprime) and TBS index based on input mcs: 36.213/Table 8.6.1-1 (Notice that Qmprime <= 4 for SIDELINK)
            load('3GPP_36213_Table8_6_1_1.mat','raw');
            ITBS_ix = (raw(:,1)==mcs);
            h.pssch_Qprime(userIndex) = min( 4, raw(ITBS_ix,2) );
            ITBS = raw(ITBS_ix,3);
            % determine TBS based on ITBS and NPRB: 36.213/Table 7.1.7.2.1s
            load('3GPP_36213_Table7_1_7_2_1_1','raw');
            h.Msc_PSSCH(userIndex) = NPRBs.*h.NRBsc*h.PSSCH_PHY_NSFs;
            h.pssch_TBsize(userIndex) = raw(raw(:,1)==ITBS,raw(1,:)==NPRBs);
            h.pssch_BitCapacity(userIndex) = h.Msc_PSSCH(userIndex)*length(h.PSSCH_symbloc_perSubframe) * h.pssch_Qprime(userIndex);  % length of PSSCH sequence in bits
            fprintf('[UE %i] PSSCH Transport Block Size = %i bits (Mod Order : %i).\n', i, h.pssch_TBsize(userIndex), h.pssch_Qprime(userIndex));
            fprintf('\tPSSCH Bit Capacity = %i bits  (Symbol Capacity = %i samples).\n', h.pssch_BitCapacity(userIndex), h.pssch_BitCapacity(userIndex)/ h.pssch_Qprime(userIndex));
            % other dimensioninf issues
            % pusch interleaving indices (36.212 - 5.4.2)
            h.pssch_muxintlv_indices{userIndex} =  tran_uplink_MuxIntlvDataOnly_getIndices(  h.pssch_BitCapacity(userIndex), h.cmux, 2, 1 );
            
        end % function Get_V2X_PSSCH_Dimensioning
        
        function output_seq = GenerateSCI0TB (h, userIndex)
            %Generates SCI Format-0 transport block (36.212 - 5.4.3.1.1)
            rabitmapSZ = ceil(log2(h.NSLRB*(h.NSLRB+1)/2));      
            sci0_tb = -ones(h.sci0_TBsize,1);                        
            % Hopping field
            sci0_tb(1,1) = h.HoppingFlag(userIndex);
            % Resource Allocation field
            if rabitmapSZ ~= length(h.pssch_prbs_ra_bitmap{userIndex}), error('wrong assignment of SCI 0 resource allocation bitmap'); end
            sci0_tb(1+1:1+rabitmapSZ,1) = h.pssch_prbs_ra_bitmap{userIndex};
            % Time Resource Pattern field
            sci0_tb(1+rabitmapSZ+1:1+rabitmapSZ+7,1) = decTobit(h.ITRP(userIndex), 7, true);
            % Modulation and Coding field (MCS assumed common for all UEs)
            sci0_tb(1+rabitmapSZ+7+1:1+rabitmapSZ+7+5,1) = decTobit(h.mcs_r12(userIndex), 5, true);
            % Timing Advance (not implemented)
            sci0_tb(1+rabitmapSZ+7+5+1:1+rabitmapSZ+7+5+11,1) = zeros(11,1);
            % Group Destinatiod ID                      
            sci0_tb(1+rabitmapSZ+7+5+11+1:1+rabitmapSZ+7+5+11+8,1) = decTobit(h.nSAID(userIndex), 8, true);
            % print output
            fprintf('SCI-0 (%i bits) message %x (hex format) generated\n', length(sci0_tb), bitTodec(sci0_tb,true));
            output_seq = sci0_tb;
        end % function: GenerateSCI0TB
        
        function [HoppingFlag, RBstart, Lcrbs, ITRP, mcs_r12, nSAID] = ReadSCI0TB (h, input_seq)
            %Read-out SCI0 info: 36.212 - 5.4.3.1.1
            
            sci0_tb = input_seq;
            fprintf('Information Recovery from SCI-0 message %x (hex format)\n', bitTodec(sci0_tb,true));
            
            rabitmapSZ = ceil(log2(h.NSLRB*(h.NSLRB+1)/2));
            
            HoppingFlag = sci0_tb(1,1);
            assert(isequal(sci0_tb(1,1),0),'Invalid Hopping. Curently only Non-Hopping (flag=0) is supported');
            raBitmap = bitTodec(sci0_tb(1+1:1+rabitmapSZ,1), true);
            % recover PRB allocation from BITMAP
            assigned_pssch_prbs = ra_bitmap_resourcealloc_recover(sci0_tb(1+1:1+rabitmapSZ,1), h.NSLRB);
            RBstart = assigned_pssch_prbs(1);
            Lcrbs = length(assigned_pssch_prbs);
            ITRP = bitTodec(sci0_tb(1+rabitmapSZ+1:1+rabitmapSZ+7,1), true);
            mcs_r12 = bitTodec(sci0_tb(1+rabitmapSZ+7+1:1+rabitmapSZ+7+5,1), true);
            nSAID = bitTodec(sci0_tb(1+rabitmapSZ+7+5+11+1:1+rabitmapSZ+7+5+11+8,1), true);
           
            fprintf('\tFrequency hopping flag           : % i\n', HoppingFlag);
            fprintf('\tResource Allocation Bitmap (INT) : % i\n', raBitmap);
            fprintf('\tTime Resource Pattern            : % i\n', ITRP);
            fprintf('\tModulation and Coding            : % i\n', mcs_r12);
            fprintf('\tTiming Advance (not implemented) : % s\n', '--');
            fprintf('\tGroup Destinatiod ID (nSAID)     : % i\n', nSAID);
            fprintf('\t'); fprintf('(RA Bitmap --> Assigned PSSCH PRBs : '); fprintf('%i ',assigned_pssch_prbs); fprintf(')\n');
            
            
        end % function ReadSCI0TB
        
        function output_seq = GenerateSCI1TB (h, userIndex, txOp)
            %Generates SCI Format-1 transport block(36.212/5.4.3.1.2)            
            % define tb
            sci1_tb = -ones(h.sci1_TBsize,1);
            % Priority [not implemented]
            sci1_tb(1:3,1) = 0;
            % ResourceReservation [not implemented]
            sci1_tb(4:7,1) = 0;
            % Frequency Resource Location
            sci1_tb(7+1:7+h.frlbitmap_len,1) = h.v2x_frlbitmap{userIndex};
            % Time gap between initial transmission and retransmission
            sci1_tb(7+h.frlbitmap_len+1:7+h.frlbitmap_len+4,1) = decTobit(h.SFgap(userIndex), 4, true);
            % Modulation and coding scheme
            sci1_tb(7+h.frlbitmap_len+4+1:7+h.frlbitmap_len+4+5,1) = decTobit(h.mcs_r14(userIndex), 5, true);
            % Retransmission index
            sci1_tb(7+h.frlbitmap_len+4+5+1:7+h.frlbitmap_len+4+5+1,1) = double(txOp>1);
            % Reserved information bits are added until the size of SCI format 1 is equal to 32 bits. The reserved bits are set to zero.
            sci1_tb(7+h.frlbitmap_len+4+5+1+1:end) = 0;
            % print output
            fprintf('SCI-1 (%i bits) message %x (hex format) generated\n', length(sci1_tb), bitTodec(sci1_tb,true));
            output_seq = sci1_tb;
        end % function : GenerateSCI1TB
        
        
        function [nsubCHstart, LsubCH, SFgap, mcs_r14, ReTx] = ReadSCI1TB (h, input_seq)
            %Readsout SCI Format-1 information (36.212 - 5.4.3.1.1)
            
            sci1_tb = input_seq;
            fprintf('Information Recovery from SCI-1 message %x (hex format)\n', bitTodec(sci1_tb,true));
          
            frl_bitmap = bitTodec(sci1_tb(7+1:7+h.frlbitmap_len,1),true);
            [~,~,nsubCHstart, LsubCH] = ra_bitmap_resourcealloc_recover(frl_bitmap, h.numSubchannel_r14);  
            
            SFgap = bitTodec(sci1_tb(7+h.frlbitmap_len+1:7+h.frlbitmap_len+4,1),true);
            mcs_r14 = bitTodec(sci1_tb(7+h.frlbitmap_len+4+1:7+h.frlbitmap_len+4+5,1), true);
            ReTx = sci1_tb(7+h.frlbitmap_len+4+5+1:7+h.frlbitmap_len+4+5+1,1);
            ReservedBits = bitTodec(sci1_tb(7+h.frlbitmap_len+4+5+1+1:end), true);
            
            fprintf('Frequency resource location (INT)                                    : % i\n', frl_bitmap);
            fprintf('Time gap between initial transmission and retransmission  (INT)      : % i\n', SFgap);
            fprintf('Modulation and Coding (INT)                                          : % i\n', mcs_r14);
            fprintf('Retransmission index                                                 : % i\n', ReTx);
            fprintf('Reserved information bits (INT)                                      : % i\n', ReservedBits);
            fprintf('\t'); fprintf('(FRL Bitmap --> nsubCHstart = %i, LsubCH = %i',nsubCHstart,LsubCH); fprintf(')\n');

        end % function: ReadSCI1TB
        
        function [output_seq, d_seq, nXID] = SL_SCI_PSCCH_Encode(h, input_seq)
            %Sidelink SCI Transport/Physical Channel Tx Processing: SCI (36.212 / 5.4.3 - 5.3.3.x - 5.2.2.7-8) & PSCCH (36.211 / 9.4)
            % input : SCI TB
            % output: symbol-sequence at the output of pscch encoder and pre-precoder output
            
            % 36.212 - 5.3.3.2	Transport block CRC attachment
            a_seq = input_seq;
            b_seq = tran_crc16( a_seq, 'encode' );
            
            % no scrambling
            c_seq = b_seq;
            
            % 36.211 - 9.3.1 : for v2x modes only compute nXID
            if isequal(h.slMode,3) || isequal(h.slMode,4)          
                nXID = bitTodec(b_seq(length(a_seq)+1:end),true);
            end
             
            % 36.211 - 5.3.3.3 Channel Coding
            d0_seq = tran_conv_coding(c_seq,0); % block #0. Each input stream has length: length(c_seq). Output Length 3x(length(c_seq))
           
            % 36.211 - 5.3.3.4 Rate Matching
            e0_seq = tran_conv_ratematch( d0_seq, h.pscch_BitCapacity, 'encode' );
            
            % dummy assignment to follow standard notation
            f0_seq = e0_seq; 
            
            % 36.211 - 5.2.2.7 / 5.2.2.8 PUSCH Interleaving without any control information
            g0_seq = f0_seq(h.pscch_muxintlv_indices);
            
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
            
            % assignment
            output_seq = y_seq;
            
        end 
        
        function [output_seq, CRCerror_flg, d_seq_rec, nXID] = SL_SCI_PSCCH_Recover(h, input_seq, decodingType)
           %Sidelink Communication Control Signaling Transport/Physical Channel Rx Processing:36.212 / 5.4.3 - 5.3.3.x - 5.2.2.7-8 &  36.211 / 9.4
                    
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
            f0_seq_rec = -1000*ones(length(pscch_output_recovered),1); f0_seq_rec(h.pscch_muxintlv_indices) = pscch_output_recovered;
            
            % dummy assignment to follow standard notation
            e0_seq_rec = f0_seq_rec;  
            
            % 5.3.3.4 Rate Matching Recovery           
            if isequal(h.slMode,1) || isequal(h.slMode,2)
                d0_seq_rec = tran_conv_ratematch( e0_seq_rec, 3*(h.sci0_TBsize+16), 'recover' );
            elseif isequal(h.slMode,3) || isequal(h.slMode,4)
               d0_seq_rec = tran_conv_ratematch( e0_seq_rec, 3*(h.sci1_TBsize+16), 'recover' );
            end
            
            % 5.3.3.3 Channel Decoding
            if isequal(decodingType,'Hard')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 1 );                
            elseif isequal(decodingType,'Soft')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 2 ); 
            end                
           
            % 5.3.3.2	Transport block CRC recovery
            b_seq_rec = double(c_seq_rec);
            [ a_seq_rec, CRCerror_flg ] = tran_crc16 (b_seq_rec, 'recover' );
            
            % for v2x only compute nXID (36.211/9.3.1)
            if isequal(h.slMode,3) || isequal(h.slMode,4)
                nXID = bitTodec(b_seq_rec(length(a_seq_rec)+1:end),true);
            else
                nXID = [];
            end
            
            % returned vector
            output_seq = a_seq_rec;        
        end
               
        function output_seq = SL_SCH_Encode(h, input_seq, userIndex)
            %Sidelink Communication Data Transport Channel Tx Processing: 36.212 / 5.4.2

            % Transport block CRC attachment
            a_seq = input_seq;
            b_seq = tran_crc24A( a_seq,'encode' );
          
            % Code block segmentation and code block CRC attachment
            if length(b_seq) > 6144, cprintf('red','SL-SCH code block segmentation not implemented yet\n'); keyboard;
            else, c_seq = b_seq; end
            
            % Channel coding (CONVOLUTIIONAL INSTEAD OF TURBO AS IN STANDARD)
            d0_seq = tran_conv_coding(c_seq, 0);
            
            % Rate matching
            e0_seq = tran_conv_ratematch( d0_seq, h.pssch_BitCapacity(userIndex), 'encode' );
            
            % dummy assignment to follow standard notation
            f0_seq = e0_seq;
            
            % PUSCH Interleaving without any control information (cmux is different for d2d and v2x)
            g0_seq = f0_seq(h.pssch_muxintlv_indices{userIndex});
          
            % output
            output_seq = g0_seq;
            
        end % function:SL_SCH_Encode
        
        function [output_seq, CRCerror_flg] = SL_SCH_Recover(h, input_seq, decodingType, userIndex)
            %SL-SCH Rx Transport Processing Recovery following 36.212 / 5.4.2
            
            b_seq_rec = input_seq;
            
            % PUSCH Deinterleaving
            f0_seq_rec = -1000*ones(length(b_seq_rec),1); f0_seq_rec(h.pssch_muxintlv_indices{userIndex}) = b_seq_rec;
            
            % dummy assignment to follow standard notation
            e0_seq_rec = f0_seq_rec;
            
            % Rate matching Recovery
            d0_seq_rec = tran_conv_ratematch( e0_seq_rec, 3*(h.pssch_TBsize(userIndex)+24), 'recover' );
            
            % Channel decoding (CONVOLUTIIONAL INSTEAD OF TURBO AS IN STANDARD)
            if isequal(decodingType,'Hard')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 1 );
            elseif isequal(decodingType,'Soft')
                c_seq_rec = tran_conv_coding( d0_seq_rec, 2 );
            end
            % re-encode and check for errors
            %d0_seq_reencoded = tran_conv_coding(c_seq_rec,0); d0_seq_rec_hard = (d0_seq_rec>0);
            %cprintf('magenta','(CONV COD+RM) BitDiffs = %i\n',sum(d0_seq_reencoded(1:end)~=d0_seq_rec_hard(1:end)));
            
            % Code block desegmentation and code block CRC attachment recovery
            b_seq_rec = double(c_seq_rec);
            
            % Transport block CRC recovery
            [ a_seq_rec, CRCerror_flg ] = tran_crc24A( b_seq_rec, 'recover' );

            % assignment
            output_seq = a_seq_rec;
            
        end % function : SL_SCH_Recover
        
        function output_seq = PSSCH_Generate(h, input_seq, nssfPSSCH, userIndex)
            %PSSCH Tx Physical Channel Processing following 36.211 / 9.3 - 5.3
            
            b_seq = input_seq;
                        
            % Scrambling
            if     isequal(h.slMode, 1) || isequal(h.slMode, 2), pssch_c_init = h.nSAID(userIndex)*2^14 + nssfPSSCH*2^9 + 510;
            elseif isequal(h.slMode, 3) || isequal(h.slMode, 4),     pssch_c_init = h.nXID(userIndex)*2^14 + nssfPSSCH*2^9 + 510;
            end
            b_scramb_seq = phy_goldseq_gen (length(b_seq), pssch_c_init); % generate scramb-seq: initialized at the start of each subframe
            b_seq_tilde = mod(b_seq + b_scramb_seq, 2); % scramble: xor
            
            % Modulation
            if h.pssch_Qprime(userIndex) == 2, d_seq = phy_modulate(b_seq_tilde, 'QPSK');
            elseif  h.pssch_Qprime(userIndex) == 4, d_seq = phy_modulate(b_seq_tilde, '16QAM'); end
            
            % Layer mapping
            x_seq = d_seq;
            
            % Transform Precoding
            y_seq = phy_transform_precoding(x_seq,h.Msc_PSSCH(userIndex));
            
            % output
            output_seq = y_seq;
            
        end
        
        function output_seq = PSSCH_Recover(h, input_seq, nssfPSSCH, decodingType, userIndex)
            % PSSCH Rx Physical Channel Recovery Processing following 36.211 / 9.3
            
            % Transform Deprecoding
            x_seq_rec = phy_transform_deprecoding(input_seq,h.Msc_PSSCH(userIndex));
            
            % Layer demapping
            d_seq_rec = x_seq_rec;
            
            % Demodulation
            if h.pssch_Qprime(userIndex) == 2
                if isequal(decodingType,'Hard')
                    b_seq_tilde_rec = phy_demodulate(d_seq_rec,'QPSK');
                elseif isequal(decodingType,'Soft')
                    b_seq_tilde_rec = phy_symbolsTosoftbits_qpsk( d_seq_rec );
                end
            elseif  h.pssch_Qprime(userIndex) == 4
                error('not fully supported yet');
            end
            
            % Descrambling
            if     isequal(h.slMode, 1) || isequal(h.slMode, 2), pssch_c_init = h.nSAID(userIndex)*2^14 + nssfPSSCH*2^9 + 510;
            elseif isequal(h.slMode, 3) || isequal(h.slMode, 4), pssch_c_init = h.nXID(userIndex)*2^14 + nssfPSSCH*2^9 + 510;
            end
            
            b_scramb_seq = phy_goldseq_gen (length(b_seq_tilde_rec), pssch_c_init);
            if isequal(decodingType,'Hard')
                b_seq_rec = mod(b_seq_tilde_rec + b_scramb_seq, 2);
            elseif isequal(decodingType,'Soft')
                b_seq_rec = b_seq_tilde_rec.*(-(2*b_scramb_seq-1));
            end
            
            % assignment
            output_seq = b_seq_rec;
            
            
        end % function : PSSCH_Recover
                
        function output_seq = CreateSubframe (h, subframe_counter)
            %Creates a sidelink communication subframe for the current subframe accounting for both control and data. 
            tx_output_grid = complex(zeros(h.NSLRB*h.NRBsc,2*h.NSLsymb));
            
            for i = 1:length(h.nPSCCH) % for each comm session                
                % PSCCH
                l_PSCCH = h.l_PSCCH_selected{i};
                if ismember(subframe_counter, l_PSCCH) % this is a subframe carrying PSCCH
                    pscch_ix = find(l_PSCCH==subframe_counter,1,'first');
                    m_PSCCH = h.m_PSCCH_selected{i}(pscch_ix);                   
                    fprintf('\nLoading Subframe %i/PRB %i with PSCCH for user %i\n',subframe_counter, m_PSCCH, h.nPSCCH(i))
                    % SCI-0 TB generation
                    sci0_tb = GenerateSCI0TB (h, i);
                    % Transport and Physical Channel Processing
                    pscch_output = SL_SCI_PSCCH_Encode (h, sci0_tb);
                    % map pscch part (one of two) sequence to grid
                    pscch_output_part = pscch_output((pscch_ix-1)*length(pscch_output)/2+1:pscch_ix*length(pscch_output)/2,1);
                    pscch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSCCH_symbloc_perSubframe, prbsTosubs(m_PSCCH(:), h.NRBsc), pscch_output_part);
                    % map pscch-drms sequence to grid (the sequence has been pre-computed in the constructor)
                    pscch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc,  h.PSCCH_DMRS_symbloc_perSubframe, prbsTosubs(m_PSCCH(:), h.NRBsc), h.pscch_dmrs_seq);
                    % add payload + dmrs
                    tx_output_grid_current = pscch_grid + pscch_dmrs_grid;
                    % add to total grid
                    tx_output_grid = tx_output_grid +  tx_output_grid_current;
                    % mark loaded pscch in order to be not examined in the future
                    h.l_PSCCH_selected{i}(pscch_ix) = -1;
                end % PSCCH    
                
                % PSSCH
                l_PSSCH = h.l_PSSCH_selected{i};                
                if ismember(subframe_counter, l_PSSCH) % this is a subframe carrying PSSCH
                    fprintf('\nLoading Subframe %i with PSSCH for user %i\n',subframe_counter,h.nPSCCH(i));
                    % prbs allocated to current pssch
                    current_prbs = [h.RBstart(i):h.RBstart(i)+h.Lcrbs(i)-1]';
                    % prepare data transport block (set a seed for repeatable patterns)
                    rng(1000); sch_tb = randi([0,1], h.pssch_TBsize(i), 1);
                    % transport channel processing
                    sch_output = SL_SCH_Encode(h, sch_tb, i);
                    % the transport channel output is split into NpsschSFs = h.PSSCH_PHY_NSFs blocks
                    sch_part_len = length(sch_output)/h.PSSCH_PHY_NSFs;
                    % which block are we? the first available (current)
                    block_ix = find(l_PSSCH==subframe_counter,1,'first');
                    % get the block
                    sch_output_part = sch_output((block_ix-1)*sch_part_len+1:block_ix*sch_part_len);
                    % physical channel processing
                    nssfPSSCH = mod(subframe_counter,10);
                    pssch_output_part = PSSCH_Generate(h, sch_output_part, nssfPSSCH, i);
                    % map to grid
                    pssch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSSCH_symbloc_perSubframe, prbsTosubs(current_prbs(:), h.NRBsc), pssch_output_part);
                    % create dmrs sequence and map to grid
                    pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_mode',num2str(h.slMode)),'N_PRB',length(current_prbs),'NSAID', h.nSAID(i),'nPSSCHss', 2*nssfPSSCH));
                    pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
                    pssch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc,  h.PSSCH_DMRS_symbloc_perSubframe, prbsTosubs(current_prbs(:), h.NRBsc), pssch_dmrs_seq);
                    % add payload + dmrs
                    tx_output_grid_current = pssch_grid + pssch_dmrs_grid;
                    % add to total grid
                    tx_output_grid = tx_output_grid +  tx_output_grid_current;
                    
                end % PSSCH                
            end % comm sessions
            % time-domain transformation: in standard-compliant sidelink waveforms the last symbol shoul be zeroed. This is not done here.
            tx_output = phy_ofdm_modulate_per_subframe(struct(h), tx_output_grid);            
            % return sequence
            output_seq = tx_output;
        end % function : CreateSubframe
        
        function h = SCI0_Search_Recover(h, rx_config, rx_input)
           %searches and recover information from possible sidelink communication control signal messages (SCI-0) 
           
           % rx config parameters: 
            if ~isfield(rx_config,'decodingType'),  rx_config.decodingType = 'Soft'; end
            if ~isfield(rx_config,'chanEstMethod'), rx_config.chanEstMethod = 'LS'; end
            if ~isfield(rx_config,'timeVarFactor'), rx_config.timeVarFactor = '0'; end
            
            nPSCCH_found = [];
            
            for i = 1:length(h.nPSCCH) % for each potential message in the search space
                n_PSCCH = h.nPSCCH(i);
                fprintf('\nSearching for SCI0 message for nPSCCH = %i\n',n_PSCCH);
                % search in the two subframes where message may reside
                potential_subframes = h.l_PSCCH_selected{i}; % two subframes carrying pscch
                potential_prbs =  h.m_PSCCH_selected{i};
                % gather pscch message from two subframe/prb pairs
                pscch_rx_posteq = complex(zeros(h.pscch_BitCapacity/2,1),zeros(h.pscch_BitCapacity/2,1));
                for pscch_ix = 1:length(potential_subframes)
                    subframe_counter = potential_subframes(pscch_ix);
                    current_prbs = potential_prbs(pscch_ix);
                    % isolate subframe
                    rx_input_sf = rx_input(subframe_counter*h.samples_per_subframe+1:(subframe_counter+1)*h.samples_per_subframe);
                    % time-to-freq domain
                    rx_input_grid_sf   = phy_ofdm_demodulate_per_subframe(struct(h), rx_input_sf);
                    % desired symbol sequence extraction and channel equalization
                    ce_params = struct('Method',rx_config.chanEstMethod, 'fd',rx_config.timeVarFactor*(1/h.chanSRate),...
                        'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',(h.Msc_PSCCH)/2,'NSLsymb',h.NSLsymb,'l_DMRS',h.PSCCH_DMRS_symbloc_perSubframe);
                    pscch_rx_posteq_part = phy_equalizer(ce_params, h.pscch_dmrs_seq, h.PSCCH_symbloc_perSubframe, prbsTosubs(current_prbs(:), h.NRBsc), rx_input_grid_sf);
                    % gather part
                    pscch_rx_posteq( (pscch_ix-1)*length(pscch_rx_posteq)/2+1:pscch_ix*length(pscch_rx_posteq)/2,1 ) = pscch_rx_posteq_part;
                end
                % transport and physical channel processing
                [msg, crcerr, pscch_dseq_rx] = SL_SCI_PSCCH_Recover(h, pscch_rx_posteq, rx_config.decodingType);
                % read-out recovered message and update respective fields
                if (crcerr==0 && ~all(msg==0))
                    fprintf('******* FOUND a SCI-0 message *******\n');
                    nPSCCH_found = [nPSCCH_found; n_PSCCH];
                    [HoppingFlag_cur, RBstart_cur, Lcrbs_cur, ITRP_cur, mcs_r12_cur, nSAID_cur] = ReadSCI0TB (h, msg);
                    % update object fields
                    h.HoppingFlag = [h.HoppingFlag; HoppingFlag_cur];
                    h.RBstart = [h.RBstart; RBstart_cur];
                    h.Lcrbs = [h.Lcrbs; Lcrbs_cur];
                    h.ITRP = [h.ITRP; ITRP_cur];
                    h.mcs_r12 = [h.mcs_r12; mcs_r12_cur];
                    h.nSAID = [h.nSAID; nSAID_cur];
                else
                    fprintf('Nothing found\n');
                end                
           end % search space
           
           % finally update nPSCCH space to reflect only nPSCCHs carrying info
           h.nPSCCH = nPSCCH_found;
           % Updating resource allocation information
           fprintf('\n\nUpdated Resource Allocation Information based on recovered SCI0 messages\n');
           [h.m_PSCCH_selected, h.l_PSCCH_selected] = Get_Control_ResourcesPerUE(h);
           [h, h.m_PSSCH_selected, h.l_PSSCH_selected, h.pssch_prbs_ra_bitmap] = Get_Data_ResourcesPerUE(h);
           h.subframes_SLSS = GetSyncResources (h);
           
        end % function : SCI0_Search_Recover
        
        function Data_Recover (h, rx_config, rx_input)
            %recovers data payload
            
            % rx config parameters: 
            if ~isfield(rx_config,'decodingType'),  rx_config.decodingType = 'Soft'; end
            if ~isfield(rx_config,'chanEstMethod'), rx_config.chanEstMethod = 'LS'; end
            if ~isfield(rx_config,'timeVarFactor'), rx_config.timeVarFactor = '0'; end
            
            fprintf('%i Data transport blocks will be recovered based on information provided by detected SCI-0 messages\n', length(h.nPSCCH));
            for i = 1:length(h.nPSCCH) % for each potential message found
                fprintf('\nDetecting data transport block %i/%i (for UE = %i)\n',i,length(h.nPSCCH), h.nPSCCH(i));
                % subframes where data resides
                l_PSSCH = h.l_PSSCH_selected{i};
                % sl-sch input message
                sch_input =  -ones(h.pssch_BitCapacity(i),1);
                sch_part_len = length(sch_input)/h.PSSCH_PHY_NSFs;
                for block_ix = 1:h.PSSCH_PHY_NSFs
                   current_suframe = l_PSSCH(block_ix);
                   current_prbs = [h.RBstart(i):h.RBstart(i)+h.Lcrbs(i)-1]';
                   % isolate subframe
                   rx_input_sf = rx_input(current_suframe*h.samples_per_subframe+1:(current_suframe+1)*h.samples_per_subframe);
                   % time-to-freq domain
                   rx_input_grid_sf   = phy_ofdm_demodulate_per_subframe(struct(h), rx_input_sf);
                   % desired symbol sequence extraction and channel equalization
                   ce_params = struct('Method',rx_config.chanEstMethod, 'fd',rx_config.timeVarFactor*(1/h.chanSRate),...
                       'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',length(current_prbs)*h.NRBsc,'NSLsymb',h.NSLsymb,'l_DMRS',h.PSSCH_DMRS_symbloc_perSubframe);
                   % create dmrs sequence
                   nssfPSSCH = mod(current_suframe,10);
                   pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_mode',num2str(h.slMode)),'N_PRB',length(current_prbs),'NSAID', h.nSAID(i),'nPSSCHss', 2*nssfPSSCH));
                   pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
                   % equalization
                   pssch_rx_posteq_part = phy_equalizer(ce_params, pssch_dmrs_seq, h.PSCCH_symbloc_perSubframe, prbsTosubs(current_prbs(:), h.NRBsc), rx_input_grid_sf);
                   % PSSCH recover
                   pssch_rec_part = PSSCH_Recover(h, pssch_rx_posteq_part, nssfPSSCH, rx_config.decodingType, i);
                   % assign part
                   sch_input((block_ix-1)*sch_part_len+1:block_ix*sch_part_len) = pssch_rec_part;                    
                end % 
                % full block transport recovery
                [msg, crcerr] = SL_SCH_Recover(h, sch_input, rx_config.decodingType, i);
                if (crcerr==0 && ~all(msg==0)), fprintf('CRC detection ok\n'); end
            end            
        end % function : Data_Recover
        
        function [h, output_seq] = CreateV2XSubframe (h, subframe_counter)
             %Creates a sidelink v2x communication subframe for the current subframe accounting for both control and data. 
             tx_output_grid = complex(zeros(h.NSLRB*h.NRBsc,2*h.NSLsymb));
             
             for i = 1:length(h.m_subchannel) % for each comm session                
                l_PSCCH = h.l_PSCCH_selected{i};
                l_PSSCH = h.l_PSSCH_selected{i};
                if ismember(subframe_counter, l_PSCCH) % this is a subframe carrying PSCCH and PSSCH (same subframes)
                    % tx opportunity counter
                    txOp = find(l_PSCCH==subframe_counter);  
                    
                    %  -------------------------------------- PSCCH ---------------------------------------------------
                    current_prbs_pscch = h.m_PSCCH_selected{i}(txOp,:);
                    fprintf('\nLoading Subframe %i with V2X-PSCCH for user %i (tx op: #%i) ',subframe_counter, i, txOp);
                    fprintf('[Used PRBs : '); fprintf('%2i ', current_prbs_pscch); fprintf(']\n');
                    % SCI-1 TB generation
                    sci1_tb = GenerateSCI1TB (h, i, txOp);
                    % Transport and Physical Channel Processing
                    [pscch_output, ~,  h.nXID(i)] = SL_SCI_PSCCH_Encode (h, sci1_tb);
                    % Map PSCCH to grid
                    pscch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSCCH_symbloc_perSubframe, prbsTosubs(current_prbs_pscch(:), h.NRBsc), pscch_output);
                    % Map PSCCH DRMS to grid
                    pscch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc,  h.PSCCH_DMRS_symbloc_perSubframe, prbsTosubs(current_prbs_pscch(:), h.NRBsc), h.pscch_dmrs_seq);
                    % add payload + dmrs
                    tx_output_grid_current = pscch_grid + pscch_dmrs_grid;
                    % add to total grid
                    tx_output_grid = tx_output_grid +  tx_output_grid_current;
                    
                    %  -------------------------------------- PSSCH ---------------------------------------------------
                    current_prbs_pssch = h.m_PSSCH_selected{i}(txOp,:);
                    fprintf('\nLoading Subframe %i with V2X-PSSCH for user %i (tx op: #%i) [nXID = %i]',subframe_counter, i, txOp, h.nXID(i));
                    fprintf('[Used PRBs : '); fprintf('%2i ', current_prbs_pssch); fprintf(']\n');
                    % prepare data transport block (set a seed for repeatable patterns)
                    rng(1000); sch_tb = randi([0,1], h.pssch_TBsize(i), 1);
                    % transport channel processing
                    sch_output = SL_SCH_Encode(h, sch_tb, i);                     
                    % calculate nssfPSSCH
                    nssfPSSCH = mod(subframe_counter,10);
                    % Physical Channel Processing
                    pssch_output = PSSCH_Generate(h, sch_output, nssfPSSCH, i);
                    % Map to Grid
                    pssch_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc, h.PSSCH_symbloc_perSubframe, prbsTosubs(current_prbs_pssch(:), h.NRBsc), pssch_output);
                    % Obtain DMRS seq and map to grid
                    pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_mode',num2str(h.slMode)),'N_PRB',length(current_prbs_pssch),'NXID', h.nXID(i),'nPSSCHss', 2*nssfPSSCH));
                    pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
                    pssch_dmrs_grid = phy_resources_mapper(2*h.NSLsymb, h.NSLRB*h.NRBsc,  h.PSSCH_DMRS_symbloc_perSubframe, prbsTosubs(current_prbs_pssch(:), h.NRBsc), pssch_dmrs_seq);
                     % add payload + dmrs
                    tx_output_grid_current = pssch_grid + pssch_dmrs_grid;
                    % add to total grid
                    tx_output_grid = tx_output_grid +  tx_output_grid_current;
                   
                end % pscch/pssch subframe
                
             end % all sessions
             
             % time-domain transformation: in standard-compliant sidelink waveforms the last symbol shoul be zeroed. This is not done here.
            tx_output = phy_ofdm_modulate_per_subframe(struct(h), tx_output_grid);            
            % return sequence
            output_seq = tx_output;

        end % function CreateV2XSubframe
        
        
         function h = SCI1_Data_Search_Recover(h, rx_config, rx_input)
           %searches and recover information from possible sidelink sci format 1 messages (v2x)
           %then for every recovered sci-1 msg tries to decode the respective data channel
           
           % rx config parameters:
           if ~isfield(rx_config,'decodingType'),  rx_config.decodingType = 'Soft'; end
           if ~isfield(rx_config,'chanEstMethod'), rx_config.chanEstMethod = 'LS'; end
           if ~isfield(rx_config,'timeVarFactor'), rx_config.timeVarFactor = '0'; end
           
           % search in every possible subframe of the pool (h.ls_PSCCH_RP)
           % and PRB pools (h.ms_PSCCH_RP)
           potential_subframes = h.ls_PSCCH_RP; % single subframe
           potential_prbsets =  h.ms_PSCCH_RP; % pair of PRBs
           
           for pot_sf_ix = 1:length(potential_subframes)
               for pot_prbset_ix = 1:length(potential_prbsets)
              
                   current_suframe = potential_subframes(pot_sf_ix);
                   current_prbs = potential_prbsets{pot_prbset_ix}(:);
                   % isolate subframe
                   rx_input_sf = rx_input(current_suframe*h.samples_per_subframe+1:(current_suframe+1)*h.samples_per_subframe);
                   % time-to-freq domain
                   rx_input_grid_sf   = phy_ofdm_demodulate_per_subframe(struct(h), rx_input_sf);
                   % desired symbol sequence extraction and channel equalization
                   ce_params = struct('Method',rx_config.chanEstMethod, 'fd',rx_config.timeVarFactor*(1/h.chanSRate),...
                       'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',length(current_prbs)*h.NRBsc,'NSLsymb',h.NSLsymb,'l_DMRS',h.PSCCH_DMRS_symbloc_perSubframe);
                   pscch_rx_posteq = phy_equalizer(ce_params, h.pscch_dmrs_seq, h.PSCCH_symbloc_perSubframe, prbsTosubs(current_prbs(:), h.NRBsc), rx_input_grid_sf);
                   % transport and physical channel processing
                   [msg, crcerr, pscch_dseq_rx, nXID_rec] = SL_SCI_PSCCH_Recover(h, pscch_rx_posteq, rx_config.decodingType);
                   % read-out recovered message and update respective fields
                   if (crcerr==0 && ~all(msg==0))
                       fprintf('\nFOUND an SCI-1 message in [Subframe %i, PRB set :', current_suframe); fprintf('%2i ', current_prbs); fprintf(']\n');                       
                       [nsubCHstart_cur, LsubCH_cur, SFgap_cur, mcs_r14_cur, ReTx_cur] = ReadSCI1TB (h, msg);
                       % identify exact prbs for pssch based on nsubCHstart_cur & LsubCH_cur
                       current_prbs_pssch = [];
                       if ReTx_cur > 0
                           for subchix = nsubCHstart_cur+1:nsubCHstart_cur+LsubCH_cur
                               current_prbs_pssch = [current_prbs_pssch; h.ms_PSSCH_RP{subchix}(:)];
                           end
                       else
                           for subchix = 1:LsubCH_cur
                               current_prbs_pssch = [current_prbs_pssch; h.ms_PSSCH_RP{subchix}(:)];
                           end
                       end
                       if h.adjacencyPSCCH_PSSCH_r14 
                           current_prbs_pssch = current_prbs_pssch(3:end);
                       end                       
                       fprintf('Recovering Data Message in corresponding resources\n');
                       dummy_user_index = 1;
                       h.nXID(dummy_user_index) = nXID_rec;
                       % first update UE-specific data resources based on found info
                       % update phy dim                      
                       h = Get_V2X_PSSCH_Dimensioning(h, mcs_r14_cur, length(current_prbs_pssch), dummy_user_index);
                       % calc nssfPSSCH
                       nssfPSSCH = mod(current_suframe,10);
                       % Obtain DMRS seq
                       pssch_dmrs_obj = SL_DMRS(struct('Mode',strcat('pssch_mode',num2str(h.slMode)),'N_PRB',length(current_prbs_pssch),'NXID', nXID_rec,'nPSSCHss', 2*nssfPSSCH));
                       pssch_dmrs_seq = pssch_dmrs_obj.DMRS_seq();
                       % equalization
                       ce_params = struct('Method',rx_config.chanEstMethod, 'fd',rx_config.timeVarFactor*(1/h.chanSRate),...
                           'N_FFT', h.NFFT,'N_cp',[h.cpLen0, h.cpLenR],'N_f',length(current_prbs_pssch)*h.NRBsc,'NSLsymb',h.NSLsymb,'l_DMRS',h.PSCCH_DMRS_symbloc_perSubframe);
                       pssch_rx_posteq = phy_equalizer(ce_params, pssch_dmrs_seq, h.PSSCH_symbloc_perSubframe, prbsTosubs(current_prbs_pssch(:), h.NRBsc), rx_input_grid_sf);
                       % PSSCH recovery
                       sch_input = PSSCH_Recover(h, pssch_rx_posteq, nssfPSSCH, rx_config.decodingType, dummy_user_index);
                       % SL-SCH recovery
                       [msg, crcerr] = SL_SCH_Recover(h, sch_input, rx_config.decodingType, dummy_user_index);
                       if (crcerr==0 && ~all(msg==0))
                           fprintf('CRC detection ok\n');
                       else
                           fprintf('CRC detection not ok\n');
                       end
                   end % sci-1 crc ok
                   
               end % searched prb sets in the pool               
           end % searched subframes in the pool
           
           
                       
         end % function :SCI1_Data_Search_Recover
        
        
    end % class methods
end % class: SL_Communication