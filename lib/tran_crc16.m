function [output_bitseq, CRCerror_flg] = tran_crc16( input_bitseq, mode )
%TRAN_CRC16 implements CRC of size 16 functionalities (attaching,
%detecting), following 36.212 - 5.1.1
% Inputs:
%   input_bitseq : input bit sequence
%   mode : 'encoding' for attaching, 'recover' for detecting
%#codegen

% persistent hCRCEnc;
% persistent hCRCDet;

% if isempty(hCRCEnc)
    gCRC = zeros(1,16);
    gCRC(1,17-[16,12,5,0])=1;    
    hCRCEnc = comm.CRCGenerator('Polynomial', gCRC);
% end
% if isempty(hCRCDet)
    gCRC = zeros(1,16);
    gCRC(1,17-[16,12,5,0])=1;    
    hCRCDet = comm.CRCDetector('Polynomial', gCRC);
% end


if isequal(mode, 'encode')
    output_bitseq = step(hCRCEnc, input_bitseq);
    CRCerror_flg = NaN;
elseif isequal(mode, 'recover')
    [output_bitseq, CRCerror_flg] = step(hCRCDet, input_bitseq);
end


end

