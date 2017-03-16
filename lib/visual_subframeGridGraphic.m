function visual_subframeGridGraphic( grid )
%VISUAL_GRIDGRAPHIC visually illustrates a subframe
%   Detailed explanation goes here

a = grid; 
b = [[a nan*zeros(size(a,1),1)] ; nan*zeros(1,size(a,2)+1)];
pcolor(abs(b)>0); colormap([1 1 1; 1 0 0]);
shading flat
colormap([1 1 1; 1 0 0]);
xlabel('SC-FDMA symbol');
ylabel('subcarrier');

end

