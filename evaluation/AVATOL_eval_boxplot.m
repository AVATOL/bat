function AVATOL_eval_boxplot(file, dir, pa, colorset, demo_active)
%
if nargin < 2
    %name = 'NClass';
    dir = '/scratch/working/AVATOL/datasets/Ventral_View/Desmodus/';
    %file = 'DClass_eval.mat';
    pa = [0 1 1 3 4 5 6 7 1 9 10 11 12 13];
    colorset = {'g','g','r','r','b','b'};
    demo_active = 0;
end

load(file);
BB1 = cat(2,allBoxes{:});
% BB1 = BB1(:);
% BB1 = BB1';

TT1 = cat(2,allTests{:});
% TT1 = TT1(:);
% TT1 = TT1';

[apk1,prec1,rec1,dist1] = AVATOL_eval_apk(BB1,TT1,0.1,0);
distMat1 = [dist1{:}];
%distMat1 = sort(distMat1);
boxplot(distMat1(1:size(BB1,2),:));

if (demo_active == 1)
    % show data
    testGT = pointtobox(TT1,pa,1,1);
    for i=1:length(TT1)
        dummy = splitstring(TT1(i).im, '/');
        imPath = [dir,dummy{end}];
        im = imread(imPath);
        testB = [testGT(i).x1;testGT(i).y1;testGT(i).x2;testGT(i).y2];
        testB = reshape(testB,[4*length(pa),1])';
        showboxesGT(im,BB1{i}(1,:),testB,colorset);
        %legend('Some quick information','location','EastOutside')

        %[h,w,~] = size(im);
        %text(w - 100,h - 50,'sth annotation');
        %showboxes(A,BB1{i},colorset);
        pause;
    end
    
    %visualization
    figure(1);
    visualizemodel(allModels{1});
    figure(2);
    visualizeskeleton(allModels{1});

    % demo
    im = imread(TT1(1,1).im);
    box = BB1{1};
    % show all detections
    figure(3);
    subplot(1,2,1); 
    showboxes(im,box,colorset);
    subplot(1,2,2); 
    showskeletons(im,box,colorset,pa);

%     % visual evaluation
%     figure(4);
%     testGT = pointtobox(test,pa,1,1);
%     testB = [testGT(demoimid).x1;testGT(demoimid).y1;testGT(demoimid).x2;testGT(demoimid).y2];
%     testB = reshape(testB,[4*length(pa),1])';
%     showboxesGT(im,box,testB,colorset);
end

end