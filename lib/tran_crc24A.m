function [output_bitseq, CRCerror_flg] = tran_crc24A( input_bitseq, mode )
%TRAN_CRC24A implements CRC of size 24 type A functionalities (attaching,
%detecting), following 36.212 - 5.1.1
% Inputs:
%   input_bitseq : input bit sequence
%   mode : 'encoding' for attaching, 'recover' for detecting
%#codegen

% persistent hCRCEnc;
% persistent hCRCDet;

% if isempty(hCRCEnc)
    gCRC = zeros(1,25);
    gCRC(1,25-[24,23,18,17,14,11,10,7,6,5,4,3,1,0])=1;
    hCRCEnc = comm.CRCGenerator('Polynomial', gCRC);
% end
% if isempty(hCRCDet)
    gCRC = zeros(1,25);
    gCRC(1,25-[24,23,18,17,14,11,10,7,6,5,4,3,1,0])=1;
    hCRCDet = comm.CRCDetector('Polynomial', gCRC);
% end


if isequal(mode, 'encode')
    output_bitseq = step(hCRCEnc, input_bitseq);
    CRCerror_flg = NaN;
elseif isequal(mode, 'recover')
    [output_bitseq, CRCerror_flg] = step(hCRCDet, input_bitseq);
end


end

