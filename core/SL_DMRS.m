classdef SL_DMRS
    %SL_DMRS generates DMRS for Sidelink Physical Channels*, i.e. PSBCH/PSDCH/PSCCH/PSSCH, corresponding to one suframe.
    % 3GPP reference: 36.211, Sections 5.5.1, 5.5.2, 9.8.
    % (* PUSCH is also supported since PSxCH DMRS generation is based on PUSCH DMRS generation.)
    % Basic Example:
    % For PSBCH define a struct including:
    %   Mode  : 'psbch_D2D' for "Standard" D2D, 'psbch_V2X' for V2X
    %   NSLID : Sidelink ID
    %   N_PRB : 6 (fixed)
    % Example Constructor Calling for PSBCH: h = SL_DMRS(struct('Mode','psbch_D2D','NSLID',0,'N_PRB',6));
    % Other Examples:
    % PSDCH: h_psdch_dmrs = SL_DMRS(struct('Mode','psdch','N_PRB',2))
    %
    % Contributors: Stelios Stefanatos, Antonis Gotsis
    
    %% properties
    properties % basic parameters extracted from input struct
        
        % Mode - Physical Channel mode
        % Possible values:
        %   PSBCH: {'psbch_D2D','psbch_V2X'}
        %   PSDCH: {'psdch'}
        %   PSCCH: {'pscch_D2D','pscch_V2X'}
        %   PSSCH: {'pssch_D2D','pssch_V2X'}
        Mode;
        
        % PUSCH related parameters (many of which relevant also for
        % sidelink channels):
        
        NCellID;            % Cell ID
        NSubframe;          % Subframe number
        CyclicPrefixUL;     % type of cyclic prefix ('Normal' or 'Extended')
        NTxAnts;            % number of TX antennas (1,2, or 4)
        Hopping;            % Hopping method ('Off', 'Group', 'Sequence')
        SeqGroup;           % D_ss parameter (0 to 29)
        CyclicShift;        % cyclic shift for n_DMRS_1 computation (for finding a)
        NPUSCHID;           % virtual Cell ID that overrides NCellID (if provided) for hopping pattern computation
        NDMRSID;            % ID used (if provided) for n_PN computation (for finding a)
        N_PRB;              % number of PRBs used
        NLayers;            % number of MIMO layers (1,2,3,or 4)
        DynCyclicShift;     % shift for n_DMRS_2 computation (for finding a)
        OrthoCover;         % Orthogonal cover indicator ('On' or 'Off')
        PMI;                % precoding matrix for MIMO transmissions
        
        % Sidelink related parameters (see Sec. 9.8)
        NSLID;              % virtual cell ID for PSBCH (relevant for 'psbch_X' Mode)
        nPSSCHss;           % slot index for PSSCH (relevant for 'pssch' Mode)
        NSAID;              % ??? virtual cell ID for PSBCH modes 1, 2 (relevant for 'psbch_mode1' or 'psbch_mode2' Mode)
        NXID;               % ??? virtual cell ID for PSBCH modes 3, 4 (relevant for 'psbch_mode3' or 'psbch_mode4' Mode)
        NCS                 % cyclic shift (releveant for 'pscch_V2X')
    end
    
    properties (SetAccess = private) % calculated parameters
        
        n_s;                 % slot index (corresponding to the subframe)
        DRSSymInfo = ...     % properties of DMRS sequence
            struct('Mode', [],'Alpha',[], 'SeqGroup', [], 'SeqIdx', [], 'RootSeq', [], 'NZC', [], 'N1DMRS', [], 'N2DMRS', [], ...
            'NPRS',[], 'OrthoSeq', []);
        
    end
    
    
    properties (Hidden = true, Constant = true)
        %Create various initialization matrices
        % table 5.5.1.2-1
        phi_mtx_N_RB_1 = [...
            [ -1, 1, 3, -3, 3, 3, 1, 1, 3, 1, -3, 3];
            [ 1, 1, 3, 3, 3, -1, 1, -3, -3, 1, -3, 3];
            [ 1, 1, -3, -3, -3, -1, -3, -3, 1, -3, 1, -1];
            [-1, 1, 1, 1, 1, -1, -3, -3, 1, -3, 3, -1];
            [-1, 3, 1, -1, 1, -1, -3, -1, 1, -1, 1, 3];
            [1, -3, 3, -1, -1, 1, 1, -1, -1, 3, -3, 1];
            [-1, 3, -3, -3, -3, 3, 1, -1, 3, 3, -3, 1];
            [ -3, -1, -1, -1, 1, -3, 3, -1, 1, -3, 3, 1];
            [ 1, -3, 3, 1, -1, -1, -1, 1, 1, 3, -1, 1];
            [1, -3, -1, 3, 3, -1, -3, 1, 1, 1, 1, 1];
            [-1, 3, -1, 1, 1, -3, -3, -1, -3, -3, 3, -1];
            [3, 1, -1, -1, 3, 3, -3, 1, 3, 1, 3, 3];
            [1, -3, 1, 1, -3, 1, 1, 1, -3, -3, -3, 1];
            [3, 3, -3, 3, -3, 1, 1, 3, -1, -3, 3, 3];
            [-3, 1, -1, -3, -1, 3, 1, 3, 3, 3, -1, 1];
            [ 3, -1, 1, -3, -1, -1, 1, 1, 3, 1, -1, -3];
            [1, 3, 1, -1, 1, 3, 3, 3, -1, -1, 3, -1];
            [ -3, 1, 1, 3, -3, 3, -3, -3, 3, 1, 3, -1];
            [-3, 3, 1, 1, -3, 1, -3, -3, -1, -1, 1, -3];
            [-1, 3, 1, 3, 1, -1, -1, 3, -3, -1, -3, -1];
            [-1, -3, 1, 1, 1, 1, 3, 1, -1, 1, -3, -1];
            [-1, 3, -1, 1, -3, -3, -3, -3, -3, 1, -1, -3];
            [1, 1, -3, -3, -3, -3, -1, 3, -3, 1, -3, 3];
            [1, 1, -1, -3, -1, -3, 1, -1, 1, 3, -1, 1];
            [ 1, 1, 3, 1, 3, 3, -1, 1, -1, -3, -3, 1];
            [1, -3, 3, 3, 1, 3, 3, 1, -3, -1, -1, 3];
            [1, 3, -3, -3, 3, -3, 1, -1, -1, 3, -1, -3];
            [-3, -1, -3, -1, -3, 3, 1, -1, 1, 3, -3, -3];
            [-1, 3, -3, 3, -1, 3, 3, -3, 3, 3, -1, -1];
            [ 3, -3, -3, -1, -1, -3, -1, 3, -3, 3, 1, -1]
            ];
        
        % table 5.5.1.2-2
        phi_mtx_N_RB_2 = [
            [-1, 3, 1, -3, 3, -1, 1, 3, -3, 3, 1, 3, -3, 3, 1, 1, -1, 1, 3, -3, 3, -3, -1, -3];
            [ -3, 3, -3, -3, -3, 1, -3, -3, 3, -1, 1, 1, 1, 3, 1, -1, 3, -3, -3, 1, 3, 1, 1, -3];
            [ 3, -1, 3, 3, 1, 1, -3, 3, 3, 3, 3, 1, -1, 3, -1, 1, 1, -1, -3, -1, -1, 1, 3, 3];
            [ -1, -3, 1, 1, 3, -3, 1, 1, -3, -1, -1, 1, 3, 1, 3, 1, -1, 3, 1, 1, -3, -1, -3, -1];
            [ -1, -1, -1, -3, -3, -1, 1, 1, 3, 3, -1, 3, -1, 1, -1, -3, 1, -1, -3, -3, 1, -3, -1, -1];
            [-3, 1, 1, 3, -1, 1, 3, 1, -3, 1, -3, 1, 1, -1, -1, 3, -1, -3, 3, -3, -3, -3, 1, 1];
            [ 1, 1, -1, -1, 3, -3, -3, 3, -3, 1, -1, -1, 1, -1, 1, 1, -1, -3, -1, 1, -1, 3, -1, -3];
            [-3, 3, 3, -1, -1, -3, -1, 3, 1, 3, 1, 3, 1, 1, -1, 3, 1, -1, 1, 3, -3, -1, -1, 1];
            [-3, 1, 3, -3, 1, -1, -3, 3, -3, 3, -1, -1, -1, -1, 1, -3, -3, -3, 1, -3, -3, -3, 1, -3];
            [1, 1, -3, 3, 3, -1, -3, -1, 3, -3, 3, 3, 3, -1, 1, 1, -3, 1, -1, 1, 1, -3, 1, 1];
            [ -1, 1, -3, -3, 3, -1, 3, -1, -1, -3, -3, -3, -1, -3, -3, 1, -1, 1, 3, 3, -1, 1, -1, 3];
            [1, 3, 3, -3, -3, 1, 3, 1, -1, -3, -3, -3, 3, 3, -3, 3, 3, -1, -3, 3, -1, 1, -3, 1];
            [ 1, 3, 3, 1, 1, 1, -1, -1, 1, -3, 3, -1, 1, 1, -3, 3, 3, -1, -3, 3, -3, -1, -3, -1];
            [ 3, -1, -1, -1, -1, -3, -1, 3, 3, 1, -1, 1, 3, 3, 3, -1, 1, 1, -3, 1, 3, -1, -3, 3];
            [ -3, -3, 3, 1, 3, 1, -3, 3, 1, 3, 1, 1, 3, 3, -1, -1, -3, 1, -3, -1, 3, 1, 1, 3];
            [-1, -1, 1, -3, 1, 3, -3, 1, -1, -3, -1, 3, 1, 3, 1, -1, -3, -3, -1, -1, -3, -3, -3, -1];
            [ -1, -3, 3, -1, -1, -1, -1, 1, 1, -3, 3, 1, 3, 3, 1, -1, 1, -3, 1, -3, 1, 1, -3, -1];
            [ 1, 3, -1, 3, 3, -1, -3, 1, -1, -3, 3, 3, 3, -1, 1, 1, 3, -1, -3, -1, 3, -1, -1, -1];
            [1, 1, 1, 1, 1, -1, 3, -1, -3, 1, 1, 3, -3, 1, -3, -1, 1, 1, -3, -3, 3, 1, 1, -3];
            [ 1, 3, 3, 1, -1, -3, 3, -1, 3, 3, 3, -3, 1, -1, 1, -1, -3, -1, 1, 3, -1, 3, -3, -3];
            [ -1, -3, 3, -3, -3, -3, -1, -1, -3, -1, -3, 3, 1, 3, -3, -1, 3, -1, 1, -1, 3, -3, 1, -1];
            [ -3, -3, 1, 1, -1, 1, -1, 1, -1, 3, 1, -3, -1, 1, -1, 1, -1, -1, 3, 3, -3, -1, 1, -3];
            [ -3, -1, -3, 3, 1, -1, -3, -1, -3, -3, 3, -3, 3, -3, -1, 1, 3, 1, -3, 1, 3, 3, -1, -3];
            [-1, -1, -1, -1, 3, 3, 3, 1, 3, 3, -3, 1, 3, -1, 3, -1, 3, 3, -3, 3, 1, -1, 3, 3];
            [ 1, -1, 3, 3, -1, -3, 3, -3, -1, -1, 3, -1, 3, -1, -1, 1, 1, 1, 1, -1, -1, -3, -1, 3];
            [ 1, -1, 1, -1, 3, -1, 3, 1, 1, -1, -1, -3, 1, 1, -3, 1, 3, -3, 1, 1, -3, -3, -1, -1];
            [ -3, -1, 1, 3, 1, 1, -3, -1, -1, -3, 3, -3, 3, 1, -3, 3, -3, 1, -1, 1, -3, 1, 1, 1];
            [-1, -3, 3, 3, 1, 1, 3, -1, -3, -1, -1, -1, 3, 1, -3, -3, -1, 3, -3, -1, -3, -1, -3, -1];
            [ -1, -3, -1, -1, 1, -3, -1, -1, 1, -1, -3, 1, 1, -3, 1, -3, -3, 3, 1, 1, -1, 3, -1, -1];
            [1, 1, -1, -1, -3, -1, 3, -1, 3, -1, 1, 3, 1, -1, 3, 1, 3, -3, -3, 1, -1, -1, 1, 3]
            ];
        
        % from table 5.5.2.1.1-1
        w_mtx = [
            [1, 1, 1, 1, 1, -1, 1, -1];
            [1, -1, 1, -1, 1, 1, 1, 1];
            [1, -1, 1, -1, 1, 1, 1, 1];
            [1, 1, 1, 1, 1, 1, 1, 1];
            [1, 1, 1, 1, 1, 1, 1, 1];
            [1, -1, 1, -1, 1, -1, 1, -1];
            [1, -1, 1, -1, 1, -1, 1, -1];
            [1, 1, 1, 1, 1, -1, 1, -1]
            ];
        
        %from table 5.5.2.1.1-1
        n_DMRS_2_mtx = [[0, 6, 3, 9];
            [6, 0, 9, 3];
            [3, 9, 6, 0];
            [4, 10, 7, 1];
            [2, 8, 5, 11];
            [8, 2, 11, 5];
            [10, 4, 1, 7];
            [9, 3, 0, 6]];
        
        prime_nums_to_2048      = [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,...
            127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,211,223,227,229,233,239,241,...
            251,257,263,269,271,277,281,283,293,307,311,313,317,331,337,347,349,353,359,367,373,379,383,...
            389,397,401,409,419,421,431,433,439,443,449,457,461,463,467,479,487,491,499,503,509,521,523,...
            541,547,557,563,569,571,577,587,593,599,601,607,613,617,619,631,641,643,647,653,659,661,673,...
            677,683,691,701,709,719,727,733,739,743,751,757,761,769,773,787,797,809,811,821,823,827,829,...
            839,853,857,859,863,877,881,883,887,907,911,919,929,937,941,947,953,967,971,977,983,991,997,...
            1009,1013,1019,1021,1031,1033,1039,1049,1051,1061,1063,1069,1087,1091,1093,1097,1103,1109,...
            1117,1123,1129,1151,1153,1163,1171,1181,1187,1193,1201,1213,1217,1223,1229,1231,1237,1249,...
            1259,1277,1279,1283,1289,1291,1297,1301,1303,1307,1319,1321,1327,1361,1367,1373,1381,1399,...
            1409,1423,1427,1429,1433,1439,1447,1451,1453,1459,1471,1481,1483,1487,1489,1493,1499,1511,...
            1523,1531,1543,1549,1553,1559,1567,1571,1579,1583,1597,1601,1607,1609,1613,1619,1621,1627,...
            1637,1657,1663,1667,1669,1693,1697,1699,1709,1721,1723,1733,1741,1747,1753,1759,1777,1783,...
            1787,1789,1801,1811,1823,1831,1847,1861,1867,1871,1873,1877,1879,1889,1901,1907,1913,1931,...
            1933,1949,1951,1973,1979,1987,1993,1997,1999,2003,2011,2017,2027,2029,2039];
        
        % by concatenation of collumns of the precoding matrices in 5.3.3.A2:
        W_NL1_NAnt2 = (1/sqrt(2)) * [1, 1, 1, 1, 1, 0; 1, -1, 1i, -1i, 0, 1];
        W_NL1_NAnt4 = (1/2) * [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 ;
            1 1 1 1 1i 1i 1i 1i -1 -1 -1 -1 -1i -1i -1i -1i 0 0 0 0 1 1 1 1;
            1 1i -1 -1i 1 1i -1 -1i 1 1i -1 -1i 1 1i -1 -1i 1 -1 1i -1i 0 0 0 0;
            -1 1i 1 -1i 1i 1 -1i -1 1 -1i -1 1i -1i -1 1i 1 0 0 0 0 1 -1 1i -1i];
        W_NL2_NAnt4 = (1/2) * [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0;
            1 0 1 0 -1i 0 -1i 0 -1 0 -1 0 1i 0 1i 0 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1;
            0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 1 0 1 0 -1 0 -1 0 0 1 0 -1 0 1 0 -1;
            0 -1i 0 1i 0 1 0 -1 0 -1i 0 1i 0 1 0 -1 0 1 0 -1 0 1 0 -1 1 0 1 0 -1 0 -1 0];
        W_NL3_NAnt4 = (1/2) * [1 0 0 1 0 0 1 0 0 1 0 0 1 0 0 1 0 0 0 1 0 0 1 0 0 1 0 0 1 0 0 1 0 0 1 0;
            1 0 0 -1 0 0 0 1 0 0 1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0 0 1 0 0 0 0 1 0 0 1;
            0 1 0 0 1 0 1 0 0 -1 0 0 0 0 1 0 0 1 1 0 0 -1 0 0 0 0 1 0 0 1 1 0 0 1 0 0 ;
            0 0 1 0 0 1 0 0 1 0 0 1 1 0 0 -1 0 0 0 0 1 0 0 1 1 0 0 -1 0 0 1 0 0 -1 0 0];
    end
    
    
    
    
    %% methods
    methods
        
        function h = SL_DMRS(pch)
            % SL_DMRS Constructor & initialization (input: structure pch)
            %
            % Note: constructor will raise an error if pch is missing required
            % fields or has unknown fields. For optional fields that are not provided,
            % constructor uses default values
            
            
            % Get input structure fields and perform error checking
            if isfield(pch,'Mode')
                assert(isequal(pch.Mode,'pusch')...
                    | isequal(pch.Mode,'psdch') ...
                    | isequal(pch.Mode,'psbch_D2D') | isequal(pch.Mode,'psbch_V2X')...
                    | isequal(pch.Mode,'pssch_D2D') | isequal(pch.Mode,'pssch_V2X')...
                    | isequal(pch.Mode,'pscch_D2D') | isequal(pch.Mode,'pscch_V2X'))
                
                h.Mode = pch.Mode;
                pch = rmfield(pch,'Mode');
            else
                error('Mode field of input struct is required');
            end
            
            % ------------------------------------------------- PSBCH -------------------------------------------------
            % PSBCH for V2X is exactly the same as "standard" PSBCH, however, returning 3 DMRS symbols instead of two
            if strcmp(h.Mode, 'psbch_D2D') || strcmp(h.Mode, 'psbch_V2X')
                if isfield(pch,'NSLID')
                    assert(pch.NSLID>=0,'NSLID should be a non-negative integer');
                    h.NSLID = pch.NSLID;
                    pch = rmfield(pch,'NSLID');
                else
                    error('NSLID field of input struct is required when Mode is "psbch"');
                end
                
                % override input Hopping field since hopping is
                % predetermined in psbch
                pch.Hopping = 'Off';
                pch.OrthoCover = 'On'; % default is 'on' in sidelink
                
                % remove fields (if present) which are only required for other modes
                if isfield(pch,'NCellID')
                    pch = rmfield(pch,'NCellID');
                end
                if isfield(pch,'NSubframe')
                    pch = rmfield(pch,'NSubframe');
                end
                if isfield(pch,'NSAID')
                    pch = rmfield(pch,'NSAID');
                end
                if isfield(pch,'nPSSCHss')
                    pch = rmfield(pch,'nPSSCHss');
                end
                if isfield(pch,'NCS')
                    pch = rmfield(pch,'NCS');
                end
                if isfield(pch,'NXID')
                    pch = rmfield(pch,'NXID');
                end
            end % check: PSBCH
            
            % ------------------------------------------------- PSSCH -------------------------------------------------
            % check existance of fields necessary for Modes pssch_D2D
            if strcmp(h.Mode, 'pssch_D2D')
                if isfield(pch,'NSAID')
                    assert(pch.NSAID>=0 && pch.NSAID<=255,'NSAID should be an integer, where 0 <= NSAID <= 255');
                    h.NSAID = pch.NSAID;
                    pch = rmfield(pch,'NSAID');
                else
                    error('NSAID field of input struct is required when Mode is "pssch_D2D"');
                end
                
                if isfield(pch,'nPSSCHss')
                    assert(pch.nPSSCHss>=0  && pch.nPSSCHss <=19 && mod(pch.nPSSCHss,2)==0,...
                        'nPSSCHss should be one of {0,2,4,...,18}');
                    h.nPSSCHss = pch.nPSSCHss;
                    pch = rmfield(pch,'nPSSCHss');
                else
                    error('nPSSCHss field of input struct is required when Mode is "pssch_D2D""');
                end
                
                % override input Hopping and OrthoCover fields since
                % hopping and orthocover are
                % predetermined in pssch
                pch.Hopping = 'Group';
                pch.OrthoCover = 'On';
                
                % remove fields (if present) which are only required for other modes
                if isfield(pch,'NCellID')
                    pch = rmfield(pch,'NCellID');
                end
                if isfield(pch,'NSubframe')
                    pch = rmfield(pch,'NSubframe');
                end
                if isfield(pch,'NSLID')
                    pch = rmfield(pch,'NSLID');
                end
                if isfield(pch,'NXID')
                    pch = rmfield(pch,'NXID');
                end
                if isfield(pch,'NCS')
                    pch = rmfield(pch,'NCS');
                end
            end
            
            % check existance of fields necessary for Modes pssch_V2X
            if strcmp(h.Mode, 'pssch_V2X')
                if isfield(pch,'NXID')
                    assert(pch.NXID>=0,'NXID should be a non-negative integer');
                    h.NXID = pch.NXID;
                    pch = rmfield(pch,'NXID');
                else
                    error('NXID field of input struct is required when Mode is "pssch_V2X"');
                end
                
                if isfield(pch,'nPSSCHss')
                    assert(pch.nPSSCHss>=0  && pch.nPSSCHss <=19 && mod(pch.nPSSCHss,2)==0,...
                        'nPSSCHss should be one of {0,2,4,...,18}');
                    h.nPSSCHss = pch.nPSSCHss;
                    pch = rmfield(pch,'nPSSCHss');
                else
                    error('nPSSCHss field of input struct is required when Mode is "pssch_V2X"');
                end
                
                % override input Hopping and OrthoCover fields since
                % hopping and orthocover are
                % predetermined in pssch
                pch.Hopping = 'Group';
                pch.OrthoCover = 'On';
                
                % remove fields (if present) which are only required for other modes
                if isfield(pch,'NCellID')
                    pch = rmfield(pch,'NCellID');
                end
                if isfield(pch,'NSubframe')
                    pch = rmfield(pch,'NSubframe');
                end
                if isfield(pch,'NSLID')
                    pch = rmfield(pch,'NSLID');
                end
                if isfield(pch,'NSAID')
                    pch = rmfield(pch,'NSAID');
                end
                if isfield(pch,'NCS')
                    pch = rmfield(pch,'NCS');
                end
                
            end
            
            % ------------------------------------------------- PSCCH/PSDCH -------------------------------------------------
            if strcmp(h.Mode, 'pscch_d2d') || strcmp(h.Mode, 'psdch')
                % override input Hopping
                pch.Hopping = 'Off';
                pch.OrthoCover = 'On'; % default is 'on' in sidelink
                
                % remove fields (if present) which are only required for other modes
                if isfield(pch,'NCellID')
                    pch = rmfield(pch,'NCellID');
                end
                if isfield(pch,'NSubframe')
                    pch = rmfield(pch,'NSubframe');
                end
                if isfield(pch,'NSAID')
                    pch = rmfield(pch,'NSAID');
                end
                if isfield(pch,'nPSSCHss')
                    pch = rmfield(pch,'nPSSCHss');
                end
                if isfield(pch,'NSLID')
                    pch = rmfield(pch,'NSLID');
                end
                if isfield(pch,'NCS')
                    pch = rmfield(pch,'NCS');
                end
                if isfield(pch,'NXID')
                    pch = rmfield(pch,'NXID');
                end
            end %check: PSCCH mode 1 and 2
            
            % -------------------- V2X PSCCH ----------------------------
            if strcmp(h.Mode, 'pscch_V2X')
                if isfield(pch,'NCS')
                    assert(pch.NCS==0 | pch.NCS==3 | pch.NCS==6 | pch.NCS==9,'NCS should be equal to {0, 3, 6, 9}');
                    h.NCS = pch.NCS;
                else
                    error ('NCS field of input struct is required when Mode is "pscch_V2X"');
                end
                
                % override input Hopping field since hopping is
                % predetermined in psbch
                pch.Hopping = 'Off';
                pch.OrthoCover = 'On'; % default is 'on' in sidelink
                
                % remove fields (if present) which are only required for other modes
                if isfield(pch,'NCS')
                    pch = rmfield(pch,'NCS');
                end
                
                
                if isfield(pch,'NCellID')
                    pch = rmfield(pch,'NCellID');
                end
                if isfield(pch,'NSubframe')
                    pch = rmfield(pch,'NSubframe');
                end
                if isfield(pch,'NSAID')
                    pch = rmfield(pch,'NSAID');
                end
                if isfield(pch,'nPSSCHss')
                    pch = rmfield(pch,'nPSSCHss');
                end
                if isfield(pch,'NSLID')
                    pch = rmfield(pch,'NSLID');
                end
                if isfield(pch,'NXID')
                    pch = rmfield(pch,'NXID');
                end
            end %check: PSCCH mode 3 and 4
            
            
            % ------------------------------------------------- PUSCH-only -------------------------------------------------
            % check existance of fields necessary for Mode=pusch
            if strcmp(h.Mode, 'pusch')
                if isfield(pch,'NCellID')
                    assert(pch.NCellID>=0,'NCellID should be a non-negative integer');
                    h.NCellID = pch.NCellID;
                    pch = rmfield(pch,'NCellID');
                else
                    error('NCellID field of input struct is required');
                end
                
                if isfield(pch,'NSubframe')
                    assert(pch.NSubframe>=0 && pch.NSubframe <=19,'NSubframe should be {0,1,...,19}');
                    h.NSubframe = pch.NSubframe;
                    h.n_s = 2 * h.NSubframe;
                    pch = rmfield(pch,'NSubframe');
                else
                    error('NSubframe field of input struct is required');
                end
                
                % remove fields (if present) which are only required for other modes
                if isfield(pch,'NSAID')
                    pch = rmfield(pch,'NSAID');
                end
                if isfield(pch,'nPSSCHss')
                    pch = rmfield(pch,'nPSSCHss');
                end
                if isfield(pch,'NSLID')
                    pch = rmfield(pch,'NSLID');
                end
                if isfield(pch,'NXID')
                    pch = rmfield(pch,'NXID');
                end
                if isfield(pch,'NCS')
                    pch = rmfield(pch,'NCS');
                end
            end
            
            if isfield(pch,'CyclicPrefixUL')
                assert(isequal(pch.CyclicPrefixUL,'Normal') | isequal(pch.CyclicPrefixUL,'Extended'),...
                    'CyclicPrefixUL should be {"Normal","Extended"}');
                h.CyclicPrefixUL = pch.CyclicPrefixUL;
                pch = rmfield(pch,'CyclicPrefixUL');
            else % default valpch
                h.CyclicPrefixUL = 'Normal';
            end
            
            if isfield(pch,'NTxAnts')
                assert(isequal(pch.NTxAnts,1) | isequal(pch.NTxAnts,2) | isequal(pch.NTxAnts,4),...
                    'NTxAnts should be {1, 2, 4}');
                h.NTxAnts = pch.NTxAnts;
                pch = rmfield(pch,'NTxAnts');
            else % default value
                h.NTxAnts = 1;
            end
            
            if isfield(pch,'Hopping')
                assert(isequal(pch.Hopping,'Off') | isequal(pch.Hopping, 'Group') | isequal(pch.Hopping, 'Sequence'),...
                    'Hopping should be {"Off", "Group", "Sequence"}');
                if (isequal(pch.Hopping,'Sequence') && h.N_PRB<6)
                    error('Sequence hopping is not applicable with less than 6 RBs');
                end
                h.Hopping = pch.Hopping;
                pch = rmfield(pch,'Hopping');
            else % default value
                h.Hopping = 'Off';
            end
            
            if isfield(pch,'SeqGroup')
                assert(pch.SeqGroup>=0 && pch.SeqGroup <=29,'SeqGroup should be {0,1,...,29}');
                h.SeqGroup = pch.SeqGroup;
                pch = rmfield(pch,'SeqGroup');
            else % default value
                h.SeqGroup = 0;
            end
            
            if isfield(pch,'CyclicShift')
                assert(pch.CyclicShift>=0 && pch.CyclicShift <=7,'SeqGroup should be {0,1,..., 7}');
                h.CyclicShift = pch.CyclicShift;
                pch = rmfield(pch,'CyclicShift');
            else % default value
                h.CyclicShift = 0;
            end
            
            if isfield(pch,'NPUSCHID')
                assert(pch.NPUSCHID <=509,'NPUSCHID should be {-1,0,1,...,509} (-1 when no NPUSCHID is provided)');
                h.NPUSCHID = pch.NPUSCHID;
                pch = rmfield(pch,'NPUSCHID');
            else % default value
                h.NPUSCHID = -1;
            end
            
            if isfield(pch,'NDMRSID')
                assert(pch.NDMRSID <=509,'NDMRSID should be {-1,0,1,...,509} (-1 when no NPUSCHID is provided)');
                h.NDMRSID = pch.NDMRSID;
                pch = rmfield(pch,'NDMRSID');
            else % default value
                h.NDMRSID = -1;
            end
            
            if isfield(pch,'N_PRB')
                assert(pch.N_PRB>=1, 'N_PRB should be a positive integer');
                h.N_PRB = pch.N_PRB;
                pch = rmfield(pch,'N_PRB');
            else
                error('PRBSet field of input structure is required');
            end
            
            if isfield(pch,'NLayers')
                assert(isequal(pch.NLayers,1) | isequal(pch.NLayers,2) | isequal(pch.NLayers,3) | isequal(pch.NLayers,4),...
                    'NTxAnts should be {1, 2, 3, 4}');
                h.NLayers = pch.NLayers;
                pch = rmfield(pch,'NLayers');
            else %default value
                h.NLayers = 1;
            end
            
            if isfield(pch,'DynCyclicShift')
                assert(pch.DynCyclicShift>=0 && pch.DynCyclicShift <=7,'SeqGroup should be {0,1,...,7}');
                h.DynCyclicShift = pch.DynCyclicShift;
                pch = rmfield(pch,'DynCyclicShift');
            else % default value
                h.DynCyclicShift = 0;
            end
            
            if isfield(pch,'OrthoCover')
                assert(isequal(pch.OrthoCover,'Off') | isequal(pch.OrthoCover, 'On'),...
                    'OrthoCover should be "On" or "Off" ');
                h.OrthoCover = pch.OrthoCover;
                pch = rmfield(pch,'OrthoCover');
            else % default value
                h.OrthoCover = 'Off';
            end
            
            if isfield(pch,'PMI')
                assert(pch.PMI>=0 && pch.PMI <=23,'SeqGroup should be {0,1,...,23}');
                h.PMI = pch.PMI;
                pch = rmfield(pch,'PMI');
            else % default value
                h.PMI = 0;
            end
            
            % check if there are unknown name fields
            if length(fieldnames(pch))>=1
                fieldnames((pch))
                error('Unknown ue struct fields. Please check naming conventions or if irrelevant fields are given');
            end
            
            %%%%%%% relative error checking %%%%%%%
            if h.NLayers > h.NTxAnts
                error('NLayers must not exceed NTxAnts');
            end
            
            if (~strcmp(h.Mode,'pusch') && (h.NLayers~=1 || h.NTxAnts~=1))
                error('sidelink channels must have NTxAnts = NLayers = 1');
            end
            
            
        end % SL_DMRS constructor
        
        function [antseq, layerseq, h] =  DMRS_seq(h)
            % DMRS_seq Method for creating the DMRS sequence
            % Outputs: antseq      - Matrix of NTxAnts columns, each column contains stacked DMRS symbols corresponding to one subframe
            %          layerseq    - Matrix of NLayers columns, each column representing the two-slot DMRS signal for each layer
            %                        *before* precoding
            
            % --------------------------------------------------------------------------------------------------------
            % "Standard D2D": DMRS for all modes with two DMRS symbols per subframe:
            % --------------------------------------------------------------------------------------------------------
            if ~strcmp(h.Mode,'pscch_V2X') && ~strcmp(h.Mode,'psbch_V2X') && ~strcmp(h.Mode,'pssch_V2X')
                
                if h.N_PRB<6 && strcmp(h.Hopping,'Sequence')
                    warning('Sequence hopping method is not applied when number of RBs < 6');
                    h.Hopping = 'Off';
                end
                
                u_s = h.u_slots();
                v_s = h.v_slots();
                a_s = h.a_slots();
                orth_code = h.w_OOC();
                
                layerseq = zeros(h.NLayers,(12 * h.N_PRB * 2)); % 12 [SCs/RB] * N_PRB [RBs] * 2 [slots/subframe]
                q_vec = [0, 0];
                for l = 0:h.NLayers-1
                    w_l = orth_code(1,l*2+1:l*2+2);
                    for slot = 0:1
                        [base_seq_slot, q_slot] =  h.base_seq_cyclic_shift(u_s(slot+1), v_s(slot+1), a_s(l+1,slot+1));
                        q_vec(slot+1) = q_slot;
                        layerseq(l+1,12 * h.N_PRB * slot +1 :12 * h.N_PRB * (slot+1)) = ...
                            layerseq(l+1,12 * h.N_PRB * slot +1 :12 * h.N_PRB * (slot+1)) + ...
                            base_seq_slot * w_l(mod(slot,2)+1);
                    end
                end
                
                %  update object info
                h.DRSSymInfo.Mode = h.Mode;
                h.DRSSymInfo.Alpha = a_s;
                h.DRSSymInfo.SeqGroup = u_s;
                h.DRSSymInfo.SeqIdx = v_s;
                h.DRSSymInfo.RootSeq = q_vec;
                h.DRSSymInfo.OrthoSeq = reshape(orth_code,h.NLayers,2);
                
                %MIMO precoding (return in column form)
                if (h.NLayers==1) && (h.NTxAnts==1)
                    antseq = layerseq.';
                elseif (h.NLayers==1) && (h.NTxAnts==2)
                    W = h.W_NL1_NAnt2(:,h.PMI+1);
                    antseq = (W * layerseq).';
                elseif (h.NLayers==1) && (h.NTxAnts==4)
                    W = h.W_NL1_NAnt4(:,h.PMI+1);
                    antseq = (W * layerseq).';
                elseif (h.NLayers==2) && (h.NTxAnts==2)
                    antseq = (1/sqrt(2)) * layerseq.';
                elseif (h.NLayers==2) && (h.NTxAnts==4)
                    W = h.W_NL2_NAnt4(:,h.PMI*2+1:h.PMI*2+2);
                    antseq = (W * layerseq).';
                elseif (h.NLayers==3) && (h.NTxAnts==4)
                    W = h.W_NL3_NAnt4(:,h.PMI*3+1:h.PMI*3+3);
                    antseq = (W * layerseq).';
                elseif (h.NLayers==4) && (h.NTxAnts==4)
                    antseq = (0.5 * layerseq).';
                end
                
                % --------------------------------------------------------------------------------------------------------
                % "V2X":DMRS is essentially the concatenation of two (standard) D2D PUSCH DMRS
                % --------------------------------------------------------------------------------------------------------
            elseif strcmp(h.Mode,'psbch_V2X')
                layerseq = zeros(h.NLayers,(12 * h.N_PRB * 2 * 2)); % 12 [SCs/RB] * N_PRB [RBs] * 2 [slots/subframe] * 2 [DMRS/slot]
                
                for ii = [0, 1]
                    
                    if h.N_PRB<6 && strcmp(h.Hopping,'Sequence')
                        warning('Sequence hopping method is not applied when number of RBs < 6');
                        h.Hopping = 'Off';
                    end
                    
                    u_s = h.u_slots();
                    v_s = h.v_slots();
                    a_s = h.a_slots();
                    orth_code = h.w_OOC();
                    
                    q_vec = [0, 0];
                    for l = 0:h.NLayers-1
                        w_l = orth_code(1,l*2+1:l*2+2);
                        for slot = 0:1
                            [base_seq_slot, q_slot] =  h.base_seq_cyclic_shift(u_s(slot+1), v_s(slot+1), a_s(l+1,slot+1));
                            q_vec(slot+1) = q_slot;
                            layerseq(l+1,12 * h.N_PRB * (2*ii+slot) +1 :12 * h.N_PRB * ((2*ii+slot)+1)) = ...
                                layerseq(l+1,12 * h.N_PRB * (2*ii+slot) +1 :12 * h.N_PRB * ((2*ii+slot)+1)) + ...
                                base_seq_slot * w_l(mod(slot,2)+1);
                        end
                    end
                end
                
                %  update object info (with the parameters describing the
                %  DMRS sequences of the second slot
                h.DRSSymInfo.Mode = h.Mode;
                h.DRSSymInfo.Alpha = a_s;
                h.DRSSymInfo.SeqGroup = u_s;
                h.DRSSymInfo.SeqIdx = v_s;
                h.DRSSymInfo.RootSeq = q_vec;
                h.DRSSymInfo.OrthoSeq = reshape(orth_code,h.NLayers,2);
                
                layerseq = layerseq(1:12 * h.N_PRB * 3); % discard the 4th DMRS symbol, as this mode only uses the first 3
                antseq = layerseq.';
                
            elseif strcmp(h.Mode,'pssch_V2X')
                %% THIS IS NOT THE RIGHT VERSION! THIS IS "DUPLICATE PSSCH D2D"
                layerseq = zeros(h.NLayers,(12 * h.N_PRB * 2 * 2),1); % 12 [SCs/RB] * N_PRB [RBs] * 2 [slots/subframe] * 2 [DMRS/slot]
                
                for ii = [0, 1]
                    if h.N_PRB<6 && strcmp(h.Hopping,'Sequence')
                        warning('Sequence hopping method is not applied when number of RBs < 6');
                        h.Hopping = 'Off';
                    end
                    
                    u_s = h.u_slots();
                    v_s = h.v_slots();
                    a_s = h.a_slots();
                    orth_code = h.w_OOC();
                    
                    q_vec = [0, 0];
                    for l = 0:h.NLayers-1
                        w_l = orth_code(1,l*2+1:l*2+2);
                        for slot = 0:1
                            [base_seq_slot, q_slot] =  h.base_seq_cyclic_shift(u_s(slot+1), v_s(slot+1), a_s(l+1,slot+1));
                            q_vec(slot+1) = q_slot;
                            layerseq(l+1,12 * h.N_PRB * (2*ii+slot) +1 :12 * h.N_PRB * ((2*ii+slot)+1)) = ...
                                layerseq(l+1,12 * h.N_PRB * (2*ii+slot) +1 :12 * h.N_PRB * ((2*ii+slot)+1)) + ...
                                base_seq_slot * w_l(mod(slot,2)+1);
                        end
                    end
                end
                
                %  update object info (with the parameters describing the
                %  DMRS sequences of the second slot
                h.DRSSymInfo.Mode = h.Mode;
                h.DRSSymInfo.Alpha = a_s;
                h.DRSSymInfo.SeqGroup = u_s;
                h.DRSSymInfo.SeqIdx = v_s;
                h.DRSSymInfo.RootSeq = q_vec;
                h.DRSSymInfo.OrthoSeq = reshape(orth_code,h.NLayers,2);
                
                antseq = layerseq.';
                
            elseif strcmp(h.Mode,'pscch_V2X')
                layerseq = zeros(h.NLayers,(12 * h.N_PRB * 2 * 2)); % 12 [SCs/RB] * N_PRB [RBs] * 2 [slots/subframe] * 2 [DMRS/slot]
                for ii = [0, 1]
                    if h.N_PRB<6 && strcmp(h.Hopping,'Sequence')
                        warning('Sequence hopping method is not applied when number of RBs < 6');
                        h.Hopping = 'Off';
                    end
                    
                    u_s = h.u_slots();
                    v_s = h.v_slots();
                    a_s = h.a_slots();
                    orth_code = h.w_OOC();
                    
                    q_vec = [0, 0];
                    for l = 0:h.NLayers-1
                        w_l = orth_code(1,l*2+1:l*2+2);
                        for slot = 0:1
                            [base_seq_slot, q_slot] =  h.base_seq_cyclic_shift(u_s(slot+1), v_s(slot+1), a_s(l+1,slot+1));
                            q_vec(slot+1) = q_slot;
                            layerseq(l+1,12 * h.N_PRB * (2*ii+slot) +1 :12 * h.N_PRB * ((2*ii+slot)+1)) = ...
                                layerseq(l+1,12 * h.N_PRB * (2*ii+slot) +1 :12 * h.N_PRB * ((2*ii+slot)+1)) + ...
                                base_seq_slot * w_l(mod(slot,2)+1);
                        end
                    end
                end
                
                %  update object info (with the parameters describing the
                %  DMRS sequences of the second slot
                h.DRSSymInfo.Mode = h.Mode;
                h.DRSSymInfo.Alpha = a_s;
                h.DRSSymInfo.SeqGroup = u_s;
                h.DRSSymInfo.SeqIdx = v_s;
                h.DRSSymInfo.RootSeq = q_vec;
                h.DRSSymInfo.OrthoSeq = reshape(orth_code,h.NLayers,2);
                
                antseq = layerseq.';
            end % end of options
            
        end % function: DMRS_seq()
        
        function [n_floor_prime] = floor_to_prime(h,n)
            % floor_to_prime Find the largest prime number smaller than input n
            %
            % Inputs:      n             - Integer input. (Corresponds to length of the base DMRS seq = # of SCs = 12*N_PRBs)
            % Outputs:     n_floor_prime - the largest prime number (integer) smaller than input n
            
            
            for k = length(h.prime_nums_to_2048):-1:1
                if(h.prime_nums_to_2048(k) < n)
                    n_floor_prime = h.prime_nums_to_2048(k);
                    break;
                end
            end
        end
        
        function [b_seq, q, h] = base_seq(h, u, v)
            % base_seq Generate the (u, v) base sequence used by PUSCH DMRS,
            %          corresponding to N_PRB RBs and one slot
            % Inputs:      u                        - Group number. Must be an element of {0,1,...,29}
            %              v                        - Base sequence number. Either v=0 or v=1
            % Outputs:     b_seq                    - base sequqnece
            %              q                        - root of the Zadoff-Chu sequqnce
            % Spec:        3GPP TS 36.211 section 5.5.1 v13.0.0
            
            %Generate the (u, v) base sequence used by PUSCH DMRS, corresponding to N_PRB RBs and one slot
            if h.N_PRB >= 3
                M_SC = h.N_PRB * 12;
                N_ZC = h.floor_to_prime(M_SC);
                q_bar = N_ZC * (u+1) / 31;
                q = floor(q_bar + 0.5) + v * (-1)^floor(2*q_bar);
                h.DRSSymInfo.NZC = N_ZC; % update object info
                x_seq = h.ZC_seq(q, N_ZC);
                b_seq = [x_seq, x_seq(1:M_SC-N_ZC)];
            end
            
            if h.N_PRB == 1
                q = -1;
                b_seq = exp(1i * h.phi_mtx_N_RB_1(u+1,:) * pi / 4);
            end
            
            if h.N_PRB == 2
                q = -1;
                b_seq = exp(1i * h.phi_mtx_N_RB_2(u+1,:) * pi / 4);
            end
        end
        
        function [ZCseq] = ZC_seq(h, q, N_ZC)
            % ZC_seq Generate the q-th root Zadoff-Chu sequence of length N_ZC
            %              corresponding to N_PRB RBs and one slot
            % Inputs:      q                        - root of sequence (non-negative integer)
            %              N_ZC                     - Lentgh of sequqnce (prime integer)
            % Outputs:     ZCseq                    - complex-valued ZC sequqnece
            % Spec:        3GPP TS 36.211 section 5.5.1 v13.0.0
            
            ZCseq = zeros(1,N_ZC); %allocate memory
            for m = 0:N_ZC-1
                ZCseq(m+1) = exp( -1i * pi * q * m * (m+1) / N_ZC);
            end
        end
        
        function [b_seq_a, q] = base_seq_cyclic_shift(h, u, v, a)
            % base_seq_cyclic_shift Generate the (frequency-domain representation of the) cyclic-shifted (u, v) base sequence used by PUSCH DMRS,
            %              corresponding to N_PRB RBs and one slot
            % Inputs:      u                        - Group number. Must be an element of {0,1,...,29}
            %              v                        - Base sequence number. Either v=0 or v=1
            %              a                        - (Cyclic) shift (non-negative integer)
            % Outputs:     b_seq_a                  - (Cyclic shifted) base sequqnece
            %              q                        - root of the Zadoff-Chu sequqnce
            % Spec:        3GPP TS 36.211 section 5.5.1 v13.0.0
            [b_seq, q, h] =  h.base_seq(u, v);
            
            b_seq_a = zeros(1, h.N_PRB * 12); %allocate memory
            for n = 0:h.N_PRB * 12 - 1
                b_seq_a(n+1) = exp(1i * a * n) * b_seq(n+1);
            end
        end
        
        function [fgh] = f_gh(h, n_ID)
            % f_gh Generate the f_gf sequence (indexed by slot number n_s=0,1,...,19) needed for determination of Group hopping
            % Inputs:      n_ID                     - (virtual) cell ID
            % Outputs:     fgh                      - seq. of base seq. numbers
            % Spec:        3GPP TS 36.211 section 5.5.1.3 v13.0.0
            
            if strcmp(h.Mode,'pusch')
                c_init = floor(n_ID/30);
                
                c = phy_goldseq_gen(8*20, c_init);
                
                fgh = zeros(1,2); %initialization
                for slot = 0:1
                    for i = 0:7
                        fgh(slot+1) = fgh(slot+1) + c(8*(h.n_s+slot)+i+1) * 2^i;
                    end
                end
                
                fgh = mod(fgh,30);
                
            elseif strcmp(h.Mode,'pssch_D2D') %same as pusch, using nPSSCHss slot index instead of n_s
                c_init = floor(n_ID/30);
                
                c = phy_goldseq_gen(8*20, c_init);
                
                fgh = zeros(1,2); %initialization
                for slot = 0:1
                    for i = 0:7
                        fgh(slot+1) = fgh(slot+1) + c(8*(h.nPSSCHss+slot)+i+1) * 2^i;
                    end
                end
                
                fgh = mod(fgh,30);
                
            elseif strcmp(h.Mode,'pssch_V2X') %same as pusch, using nPSSCHss slot index instead of n_s
                c_init = floor(n_ID/30);
                
                c = phy_goldseq_gen(8*20, c_init);
                
                fgh = zeros(1,2); %initialization
                for slot = 0:1
                    for i = 0:7
                        fgh(slot+1) = fgh(slot+1) + c(8*(h.nPSSCHss+slot)+i+1) * 2^i;                        
                    end
                end
                
                fgh = mod(fgh,30);
            end
        end
        
        function [u_slts] = u_slots(h)
            % u_slots Generate the sequence of base indices (u) when Group hopping is enabled
            % Outputs:     u_slts                   - seq. of base seq. numbers
            % Spec:        3GPP TS 36.211 section 5.5.1.3 v13.0.0
            
            if strcmp(h.Mode, 'psbch_D2D') || strcmp(h.Mode, 'psbch_V2X')
                u_slts = mod(floor(h.NSLID/16),30) * ones(1,2);
                
            elseif strcmp(h.Mode,'psdch')
                u_slts = zeros(1,2);
                
            elseif strcmp(h.Mode,'pssch_D2D')
                n_ID = h.NSAID;
                
                %perform Group hopping (only option for pssch)
                u_slts = mod(h.f_gh(n_ID) + mod(n_ID,30), 30);
                % IMPORTANT: Didn't validate with matlab!!!!
                
            elseif strcmp(h.Mode,'pssch_V2X')
                n_ID = h.NXID;
                
                %perform Group hopping (only option for pssch)
                u_slts = mod(h.f_gh(n_ID) + mod(floor(n_ID/16),30), 30);
                
            elseif strcmp(h.Mode,'pscch_D2D')
                u_slts = zeros(1,2);
            elseif strcmp(h.Mode,'pscch_V2X')
                u_slts = [8,8];
            elseif strcmp(h.Mode,'pusch')
                D_ss = h.SeqGroup;
                if h.NPUSCHID >= 0
                    n_ID = h.NPUSCHID;
                    D_ss = 0;  % is virtual cell ID, override given D_ss
                else
                    n_ID = h.NCellID;
                end
                
                if strcmp(h.Hopping, 'Group')
                    u_slts = mod(h.f_gh(n_ID) + mod(n_ID + D_ss,30), 30);
                else
                    u_slts = mod(n_ID + D_ss,30) * ones(1,2);
                end
                
            end
            
        end
        
        function [v_slts] = v_slots(h)
            % v_slots Generate the sequence of sequence indices (v) when Sequence hopping is enabled
            % Outputs:     v_slts                   - seq. of base seq. numbers
            % Spec:        3GPP TS 36.211 section 5.5.1.4 v13.0.0
            D_ss = h.SeqGroup;
            if h.NPUSCHID>=0
                n_ID = h.NPUSCHID;
                D_ss = 0;
            else
                n_ID = h.NCellID;
            end
            
            if strcmp(h.Hopping, 'Sequence')
                c_init = floor(n_ID/30) * 2^5 + mod(n_ID + D_ss,30);
                
                v_slts = phy_goldseq_gen(20, c_init);
                v_slts = v_slts(h.n_s+1:h.n_s+2);
            else
                v_slts = zeros(1,2);
            end
        end
        
        function [nPN] =  n_PN(h, n_ID, D_ss)
            % n_PN  Generate the n_PN value necessary for determining the cyclic shift
            % Inputs:      n_ID                     - (virtual) cell ID
            %              D_ss                     - PUSCH sequence group assignment(should be set to zero
            %                                         when a virtual cell ID is provided
            % Outputs:     nPN                      - 1 x 20 vector of n_PN values  (one for each slot)
            %                                         values corresponding to layers 0,1,2,3, respectively
            if strcmp(h.CyclicPrefixUL, 'Normal')
                N_symb_UL = 7;
            else
                N_symb_UL = 6;
            end
            
            c_init = floor(n_ID/30) * 2^5 + mod(n_ID + D_ss,30);
            
            c = phy_goldseq_gen(1120, c_init);
            
            nPN = zeros(1,20);
            for slot = 0:19
                for i = 0:7
                    nPN(slot+1) = nPN(slot+1) + c(8 * N_symb_UL * slot + i + 1) * 2^i;
                end
            end
            nPN = nPN(h.n_s+1:h.n_s+2);
        end
        
        function [nDMRS2] = n_DMRS_2(h)
            % n_DMRS_2 Generate the n_DMRS_2 value necessary for determining the cyclic shift. Difference value for each layer
            % Outputs:     nDMRS2                   - 1 x NLayer vector of n_DMRS_2
            %                                         values corresponding to layers 0,1,2,3, respectively
            if h.NLayers == 1
                nDMRS2 = h.n_DMRS_2_mtx(h.DynCyclicShift+1,1);
            elseif h.NLayers == 2
                nDMRS2 = h.n_DMRS_2_mtx(h.DynCyclicShift+1,1:2);
            elseif h.NLayers == 3
                nDMRS2 = h.n_DMRS_2_mtx(h.DynCyclicShift+1,1:3);
            else % NLayers == 4
                nDMRS2 = h.n_DMRS_2_mtx(h.DynCyclicShift+1,:);
            end
        end
        
        function [nDMRS1] = n_DMRS_1(h)
            % n_DMRS_1 Generate the n_DMRS_1 value necessary for determining the cyclic shift
            % Outputs:     nDMRS1                   - n_DMRS_1
            % Spec:        3GPP TS 36.211 section 5.5.2.1.1 v13.0.0
            tmp = [0, 2, 3, 4, 6, 8, 9, 10];
            nDMRS1 = tmp(h.CyclicShift + 1);
        end
        
        function [a] = a_slots(h)
            % a_slots Generate the cyclic shift values (a) for 20 slots
            % Outputs:     a                        - NLayers x 20 matrix of n_PN values  (one for each slot)
            %                                         each row corresponds to layers 0,1,2,3, respectively
            % Spec:        3GPP TS 36.211 section 5.5.2.1.1 v13.0.0
            if strcmp(h.Mode, 'psbch_D2D') || strcmp(h.Mode, 'psbch_V2X')
                n_CS_slots_layer = mod(floor(h.NSLID/2),8);
                a = [1, 1] * 2 * pi * n_CS_slots_layer / 12;
                
            elseif strcmp(h.Mode,'psdch')
                n_CS_slots_layer = 0;
                a = [1, 1] * 2 * pi * n_CS_slots_layer / 12;
                
            elseif strcmp(h.Mode,'pssch_D2D')
                n_CS_slots_layer = mod(floor(h.NSAID/2),8);
                a = [1, 1] * 2 * pi * n_CS_slots_layer / 12;
                
            elseif strcmp(h.Mode,'pssch_V2X')
                n_CS_slots_layer = mod(floor(h.NXID/2),8);
                a = [1, 1] * 2 * pi * n_CS_slots_layer / 12;
                
                
            elseif strcmp(h.Mode,'pscch_D2D')
                n_CS_slots_layer = 0;
                a = [1, 1] * 2 * pi * n_CS_slots_layer / 12;
                
            elseif strcmp(h.Mode,'pscch_V2X')
                n_CS_slots_layer = h.NCS;
                a = [1, 1] * 2 * pi * n_CS_slots_layer / 12;
                
            elseif strcmp(h.Mode,'pusch')
                D_ss = h.SeqGroup;
                if h.NDMRSID>=0
                    n_ID = h.NDMRSID;
                    D_ss = 0;
                else
                    n_ID = h.NCellID;
                end
                
                n_DMRS_2_layers = h.n_DMRS_2();
                n_DMRS_1 = h.n_DMRS_1();
                n_PN = h.n_PN(n_ID, D_ss);
                
                h.DRSSymInfo.N1DMRS = n_DMRS_1;         %update object info
                h.DRSSymInfo.N2DMRS = n_DMRS_2_layers;  %   -||-
                h.DRSSymInfo.NPRS = n_PN;               %   -||-
                
                n_CS_slots_layer = zeros(h.NLayers, 2);
                for l = 1:h.NLayers
                    n_CS_slots_layer(l,:) = mod(n_DMRS_1 + n_DMRS_2_layers(l) + n_PN, 12);
                end
                
                a = 2 * pi * n_CS_slots_layer / 12;
                
            end
            
        end
        
        function [wOOC] = w_OOC(h)
            % w_OOC Generate the orthogonal codes for PUSCH DMRS
            % Outputs:     wOOC                     - 1 x NLayers*2 x 20 vector, where
            %                                         each pair of elements corresponds to the orth. code of layer 0,1,2,3,
            %                                         resepecively
            %                                         each row corresponds to layers 0,1,2,3, respectively
            % Spec:        3GPP TS 36.211 section 5.5.2.1.1 v13.0.0
            
            if strcmp(h.Mode, 'psbch_D2D')
                if mod(h.NSLID,2)==0
                    wOOC = [1, 1];
                else
                    wOOC = [1, -1];
                end
            elseif  strcmp(h.Mode, 'psbch_V2X')
                % In the standard this is defined as [+1 +1 +1] or [+1 -1 +1], but in our code this is handled within DMRS_seq generation
                if mod(h.NSLID,2)==0
                    wOOC = [1, 1];
                else
                    wOOC = [1, -1];
                end
            elseif strcmp(h.Mode,'psdch')
                wOOC = [1, 1];
                
            elseif strcmp(h.Mode,'pssch_D2D')
                if mod(h.NSAID,2)==0
                    wOOC = [1, 1];
                else
                    wOOC = [1, -1];
                end
                
            elseif strcmp(h.Mode,'pssch_V2X')
                if mod(h.NXID,2)==0
                    wOOC = [1, 1];
                else
                    wOOC = [1, -1];
                end
                
            elseif strcmp(h.Mode,'pscch_D2D') || strcmp(h.Mode,'pscch_V2X')
                % In the standard this is defined as [+1 +1 +1 +1] but in our code this is handled within DMRS_seq generation
                wOOC = [1, 1];
                
            elseif strcmp(h.Mode,'pusch')
                if strcmp(h.OrthoCover,'Off')
                    wOOC = ones(1, 2 * h.NLayers);
                else
                    wOOC =  h.w_mtx(h.DynCyclicShift+1,1:2*h.NLayers);
                end
            end
            
        end % function w_OOC
        
    end % methods
end % class