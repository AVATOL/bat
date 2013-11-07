clear
close all

fd_path = '/home/hushell/working/AVATOL/datasets/Bat/vent_small/';
tgt_cls = 'M1';
srcList = {'A', 'N', 'T'};
srcNumParts = {15, 13, 15};

% parameters
cellsize=3;
gridspacing=1;
SIFTflowpara.alpha=2*255;
SIFTflowpara.d=40*255;
SIFTflowpara.gamma=0.005*255;
SIFTflowpara.nlevels=4;
SIFTflowpara.wsize=2;
SIFTflowpara.topwsize=10;
SIFTflowpara.nTopIterations = 60;
SIFTflowpara.nIterations= 30;

addpath('siftflow');
addpath(fullfile('siftflow','mexDenseSIFT'));
addpath(fullfile('siftflow','mexDiscreteFlow'));

% siftflow 
tgtList = get_file_list([fd_path tgt_cls '/']);
tgt_path = [fd_path tgt_cls '/'];

for i = 3:length(srcList)
    src_path = [fd_path srcList{i} '/'];
    fileList = get_file_list(src_path);
    numparts = srcNumParts{i};
    
    % visualize color
    part_color = cell(numparts,1);
    colorset = hsv((numparts-1) / 2 + 1);
    colorset = [colorset; colorset(2:end,:)];
    for bi = 1:numparts
        part_color{bi} = colorset(bi,:);
    end
    
    % for-loop target images
    for j = 1:length(tgtList)
        if isempty(tgtList{j})
            continue
        end
        imTgt = imread([tgt_path tgtList{j}]); imTgt = im2double(imTgt);
        siftTgt = mexDenseSIFT(imTgt,cellsize,gridspacing);
        
        % visualize target image
        figure(2);
        imagesc(imTgt); axis image; axis off;
        
        % for-loop src images
        for k = 1:length(fileList)
            if isempty(fileList{k})
                continue
            end
            imSrc = imread([src_path fileList{k}]); imSrc = im2double(imSrc);
            siftSrc = mexDenseSIFT(imSrc,cellsize,gridspacing);
            
            tic;[vx,vy,energylist]=SIFTflowc2f(siftSrc,siftTgt,SIFTflowpara);toc
            %save([srcList{i}, '_', tgt_cls, num2str(k), '_', num2str(j), '.mat'], 'vx', 'vy');
            
            % annotation transfer
            [lead name ext] = fileparts(fileList{k});
            point = dlmread([src_path '/pos/' name 'parts.txt']);
            vpoint = point;
            quant_xy = round(point); quant_xy(point == 0) = 1;
    
            for bi = 1:numparts
                vpoint(bi,1) = point(bi,1) + vx(quant_xy(bi,2), quant_xy(bi,1));
                vpoint(bi,2) = point(bi,2) + vy(quant_xy(bi,2), quant_xy(bi,1));
            end
            
            % visualize src image
            figure(1);
            imagesc(imSrc); axis image; axis off;
            hold on
            for bi = 1:numparts
                plot(point(bi,1),point(bi,2),'.','MarkerSize',15,'color',part_color{bi});
            end
            figure(2);
            hold on
            for bi = 1:numparts
                plot(vpoint(bi,1),vpoint(bi,2),'.','MarkerSize',15,'color',part_color{bi});
            end
        end
    end
end

%warpI2=warpImage(im2,vx,vy);
