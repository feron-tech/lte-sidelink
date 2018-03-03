function [ output_seq ] = tran_turbo_ratematch( input_seq, target_outlen, rvidx, mode )
%TRAN_CONV_RATEMATCH implements rate matching functionalities (encoding,
%recovery) for turbo encoding according to 3GPP, 36.212, 5.1.4.1
% Inputs:
%   input_seq     : input bit sequence
%   target_outlen : the output bit-sequence length
%   rvidx         : redundancy version number (0,1,2,3)
%   mode          : encode or recover
%#codegen

% Convolutional Subblock interleaving: Inter-column permutation pattern for sub-block interleaver (36.212 - Table 5.1.4-1)
Pj = [0, 16, 8, 24, 4, 20, 12, 28, 2, 18, 10, 26, 6, 22, 14, 30, 1, 17, 9, 25, 5, 21, 13, 29, 3, 19, 11, 27, 7, 23, 15, 31] + 1;

if isequal(mode, 'encode')    
    D = length(input_seq)/3;
    E = target_outlen;
    output_seq = NaN(E,1);    
elseif isequal(mode, 'recover')    
    E = length(input_seq);
    D = target_outlen/3;   
    output_seq = NaN(target_outlen,1);    
end


%% INTERLEAVE (5.1.4.1.1)
% input indices
d_IXs = (1:1:D)';

% (1) Assign CccSubBlock
CccSubBlock = 32;

% (2) Determine the number of rows of the matrix
RccSubBlock = ceil(D/CccSubBlock); % number of rows: min integer such that D <= RccSubBlock * CccSubBlock
Kp = RccSubBlock*CccSubBlock; % output size

% (3) Write input sequence into the RccSubBloc x CccSubBlock matrix row by
% row after adding (if needed) dummy bits)
ND = Kp - D; % dummy bits
y_IXs = NaN(RccSubBlock*CccSubBlock,1);
y_IXs(ND+1:ND+D) = d_IXs;
% write into matrix
RCmat = reshape(y_IXs,CccSubBlock,RccSubBlock)';

% (4) perform column interleaving
RCmat_perm = zeros(size(RCmat));
for colIX = 1:CccSubBlock
    RCmat_perm(:,colIX) = RCmat(:,Pj(colIX));
end

% (5) Find v indexes: read-out column by column for v0,v1 differently for v2
% v0 and v1: common as in CC
v_01_IXs = NaN(Kp,1); 
i = 0;
for colIX = 1:CccSubBlock
    for rowIX = 1:RccSubBlock
        i = i + 1;
        if ~isnan(RCmat_perm(rowIX,colIX))
            v_01_IXs(i,1) = RCmat_perm(rowIX,colIX);
        end
    end
end
% v2: differently from CC
v_2_IXs = NaN(Kp,1); 
for i=0:Kp-1
    p_k = mod(Pj(floor(i/RccSubBlock)+1)-1 + CccSubBlock*mod(i,RccSubBlock) + 1,Kp);
    v_2_IXs(i+1,1) = y_IXs(p_k+1);
end

%% BIT COLLECTION and SELECTION (5.1.4.2.1)
Kw = 3*Kp;

w_IXs = NaN(Kw,1);
for kpix = 1:Kp
    if ~isnan(v_01_IXs(kpix))
        w_IXs(kpix) = v_01_IXs(kpix);
        w_IXs(Kp+2*kpix-1) = v_01_IXs(kpix)+D;
    end    
    if ~isnan(v_2_IXs(kpix))
        w_IXs(Kp+2*kpix) = v_2_IXs(kpix)+2*D;
    end    
end

% implementation #1: LTE specs
e_IXs = -ones(E,1);
Ncb = Kw;
k0 = RccSubBlock*(2*(ceil(Ncb)/(8*RccSubBlock))*rvidx+2);
k=0;
j=0;
while k<E
    if ~isnan(w_IXs(mod(k0+j,Ncb)+1))
        e_IXs(k+1) = w_IXs(mod(k0+j,Ncb)+1);
        k=k+1;
    end
    j=j+1;
end

%% mode-dependent operation
if isequal(mode, 'encode')    
    output_seq(:,1) = input_seq(e_IXs);
elseif isequal(mode, 'recover')
    if target_outlen<=E      
        output_seq(e_IXs(1:target_outlen)) = input_seq(1:target_outlen);
    else
        output_seq(e_IXs(1:E)) = input_seq(1:E);
        % zero nan elements
        output_seq(isnan(output_seq))=0;
    end
end


end