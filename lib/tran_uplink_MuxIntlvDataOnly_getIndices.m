function [ output_indices ] = tran_uplink_MuxIntlvDataOnly_getIndices( G, Cmux, Qm, NL )
%tran_uplink_MuxIntlvDataOnly_getIndices calculates indices for PUSCH
%Interleaving without any control information based on 3GPPP 36.212 / 5.1.3.1
%   Inputs:
%       1) G    : length of input sequence
%       2) Cmux : number of columns in interleaved array
%       3) Qm   : modulation order (2 for QPSK)
%       4) NL   : number of layers
%   Outputs:
%       The required indices
%#codegen
output_indices = -ones(G,1);

% 36.212 - 5.2.2.7 (Data multiplexing)
%MUX_array = -ones(Qm*NL,G/2);
Hp = G/(Qm*NL);
MUX_array_indices = reshape(1:1:G,Qm*NL,Hp);

% 36.213 - 5.2.2.8 (Channel interleaver)
Rmux = Hp*Qm*NL/Cmux;
Rmuxp = Rmux/Qm*NL;
% step (4)
y_indices = -ones(Rmux,Cmux);
for cix = 1:Cmux
    els = MUX_array_indices(:,(cix-1)*Rmuxp+1:cix*Rmuxp);
    y_indices(:,cix) = els(:);
end
% step (6)
for i = 1:Rmuxp
    subMat = y_indices((i-1)*Qm*NL+1:i*Qm*NL,:);
    output_indices((i-1)*Cmux*Qm*NL+1:i*Cmux*Qm*NL,1) = subMat(:);
    % directly using: subsref( x ,struct('type','()','subs',{{1:numel(x)}})), where x = y_indices((i-1)*Qm*NL+1:i*Qm*NL,:);
end





end

