function  output_bitseq  = tran_conv_coding (input_bitseq, mode )
%tran_conv_coding implements 3GPP convolutional coding (encoding & decoding)
% functionalities using MATLAB Communications System Toolbox ConvolutionalEncoder and ViterbiDecoder System Objects
% 3GPPP 36.212 / 5.1.3.1
% mode 0: encoding
% mode 1: hard decoding
% mode 2: soft decoding
%#codegen

persistent hChanEnc;
persistent hChanDecH;
% persistent hChanDecS;

output_bitseq = -1;

if mode == 0
    D = length(input_bitseq);
    output_bitseq = zeros(3*D,1);
    
    % encode
    if isempty(hChanEnc)
        hChanEnc = comm.ConvolutionalEncoder(...
            'TrellisStructure',poly2trellis(7, [133 171 165]),'TerminationMethod','Truncated','InitialStateInputPort',true,'FinalStateOutputPort',true);
    end
    
    % trellis termination
    % Get the last 6 information bits and set them as initial state to the encoder
    InitState_bitseq = double(input_bitseq(end-6+1:end));
    %InitState_int = step(hBitToIntBCHinit,InitState_bitseq);
    InitState_int = bitTodec(InitState_bitseq, false); % MSB-->last
    % Encode data with the above initial state
    outConvEnc = step(hChanEnc, input_bitseq, InitState_int);
    % output check
    % [outConvEnc, FSTATE] = step(hChanEnc, input_bitseq, InitState_int);
    % if InitState_int~=FSTATE, error('In Convolutional Encoding Init and Final States are different'); end
    
    % reorganize output in per stream format
    output_bitseq_perStream = -ones(D,3);
    output_bitseq_perStream(:,1) = outConvEnc(1:3:3*D,1);
    output_bitseq_perStream(:,2) = outConvEnc(2:3:3*D,1);
    output_bitseq_perStream(:,3) = outConvEnc(3:3:3*D,1);
    
    % output: [D0 D1 D2]
    output_bitseq(:,1) = output_bitseq_perStream(:);
    
elseif mode == 1
    
    D = length(input_bitseq)/3;
    output_bitseq = zeros(D,1);
    
    % reorganize input from per-stream ([D0 D1 D2]) to mixed-stream format
    input_bitseq_mixedStream = -ones(3*D,1);
    for i = 1:D
        input_bitseq_mixedStream((i-1)*3+1:3*i,1) = input_bitseq([i, i+D, i+2*D],1);
    end
    
    % Create the neccessary system objects
    if isempty(hChanDecH)
        hChanDecH = comm.ViterbiDecoder(poly2trellis(7, [133 171 165]), 'InputFormat', 'hard', 'TerminationMethod', 'Truncated');
    end
    % Decode Data
    decoded_bitseq_dupl = step(hChanDecH, [input_bitseq_mixedStream; input_bitseq_mixedStream]); % duplicate input and then decode
    output_bitseq(:) = decoded_bitseq_dupl([D+1:floor(3*D/2), floor(D/2+1):D]); %keep midde 1st half of 2nd part and 2nd half of 1st part

elseif mode == 2
    
    D = length(input_bitseq)/3;
    output_bitseq = zeros(D,1);
    
    % reorganize input from per-stream ([D0 D1 D2]) to mixed-stream format
        input_bitseq_mixedStream = -ones(3*D,1);
    for i = 1:D
        input_bitseq_mixedStream((i-1)*3+1:3*i,1) = input_bitseq([i, i+D, i+2*D],1);
    end
    
    % Create the neccessary system objects
%     if isempty(hChanDecS)
        hChanDecS = comm.ViterbiDecoder(poly2trellis(7, [133 171 165]), 'InputFormat', 'Unquantized', 'TerminationMethod', 'Truncated');
%     end
    % Decode Data
    decoded_bitseq_dupl = step(hChanDecS, -[input_bitseq_mixedStream; input_bitseq_mixedStream]); % duplicate input and then decode
    output_bitseq(:) = decoded_bitseq_dupl([D+1:floor(3*D/2), floor(D/2+1):D]); %keep midde 1st half of 2nd part and 2nd half of 1st part

end




end