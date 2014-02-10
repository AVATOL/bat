function runSIFTflow(srcList, tgtList)
%srcList = {'M1'};
%tgtList = {'A', 'G', 'M2', 'N', 'S', 'T'};

fd_path = '../data/vent_small/';
allList = {'A', 'G', 'M1', 'M2', 'N', 'S', 'T'};
[~,loc] = ismember(tgtList, allList);

allImgs = {
    [fd_path, 'A/210871-resize.png'], ...
    [fd_path, 'G/264591-resize.png'], ...
    [fd_path, 'M1/263276-resize.png'], ...
    [fd_path, 'M2/204473-resize.png'], ...
    [fd_path, 'N/209252-resize.png'], ...
    [fd_path, 'S/210465-resize.png'], ...
    [fd_path, 'T/272820-resize.png']
    };
allDirs = {
    [fd_path, srcList{1}, '_from_A/'], ...
    [fd_path, srcList{1}, '_from_G/'], ...
    [fd_path, srcList{1}, '_from_M1/'], ...
    [fd_path, srcList{1}, '_from_M2/'], ...
    [fd_path, srcList{1}, '_from_N/'], ...
    [fd_path, srcList{1}, '_from_S/'], ...
    [fd_path, srcList{1}, '_from_T/']};

targetImgs = allImgs(loc);
targetDirs = allDirs(loc);

cellsize=3;
gridspacing=1;

addpath(fullfile(pwd,'mexDenseSIFT'));
addpath(fullfile(pwd,'mexDiscreteFlow'));

SIFTflowpara.alpha=2*255;
SIFTflowpara.d=40*255;
SIFTflowpara.gamma=0.005*255;
SIFTflowpara.nlevels=4;
SIFTflowpara.wsize=2;
SIFTflowpara.topwsize=10;
SIFTflowpara.nTopIterations = 60;
SIFTflowpara.nIterations= 30;

display = 0;

for fi = 1:numel(targetImgs)
%     if fi == 2, continue, end % DEBUG code
    fprintf('------------- %d -------------\n', fi);
    rt_path = [fd_path srcList{1} '/'];
    files = dir(rt_path);
    fileList = cell(length(files)-2,1);
    for j = 3:length(files)
        fstr = files(j).name;
        if length(fstr) < 10
            continue
        end
        if strncmp(fstr(end-9:end), 'resize.png', 10) == 0
            continue
        end
        fileList{j-2} = files(j).name;
    end  

    imTgt = imread(targetImgs{fi}); imTgt = im2double(imTgt);
    siftTgt = mexDenseSIFT(imTgt,cellsize,gridspacing);
    
    for i = 1:numel(fileList)
        if isempty(fileList{i})
            continue
        end
        imSrc = imread([rt_path fileList{i}]); imSrc = im2double(imSrc);
        siftSrc = mexDenseSIFT(imSrc,cellsize,gridspacing);
        
        tic;[vx,vy,energylist]=SIFTflowc2f(siftTgt,siftSrc,SIFTflowpara);toc
        fprintf('[%d] %s_to_%s\n', i, srcList{1}, tgtList{fi});

        warpI2=warpImage(imSrc,vx,vy);
        imwrite(warpI2, [targetDirs{fi} fileList{i}(1:end-4) '-warp.png']);
        save([targetDirs{fi} fileList{i}(1:end-4) '-vxy.mat'], 'vx', 'vy');
        
        if display
            subplot(1,2,1); imshow(warpI2);

            % display flow
            clear flow;
            flow(:,:,1)=vx;
            flow(:,:,2)=vy;
            subplot(1,2,2); imshow(flowToColor(flow));
            pause
        end
    end

end