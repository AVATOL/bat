function model_score = train_model_from_prior(directory, K, pa, name, colorset, directory_txt, ...
    s1, s2, show_data, demo_active, save_model)
% NOTE: need adjust size of BB of pos, so look at data first
% directory: root path
% directory_txt: path where annotations are
% K = [1 1 1 1 1 1 1 1 1 1 1 1];
% pname8 = {'I1','Nasal','u1','u2','u3','u4','u5','l1','l2','l3','l4','l5'};
% pa = [0 1 1 3 4 5 6 1 8 9 10 11];
% name = 'M1Class-transfer';
% colorset = {'g','g','r','r','r','r','r','b','b','b','b','b'};
%

if nargin < 7
    s1 = 0.8;
    s2 = 1;
    show_data = 0;
    demo_active = 0;
    save_model = 1;
end

if nargin < 9
    show_data = 0;
    demo_active = 0;
    save_model = 1;
end

% --------------------
%directory = '/home/hushell/working/AVATOL/datasets/Bat/vent_exp_transfer_resized/';

% Spatial resolution of HOG cell, interms of pixel width and hieght
sbin = 8;

% --------------------
% Define training and testing data
globals;

if (show_data == 1)
    %[pos test] = getPositiveData([directory,'pos/'],'png','txt',1.0);
    [pos ~] = getPositiveDataSeparate(directory,'png', directory_txt, 'txt', []);
    pos = pointtobox(pos,pa,s1,s2);

    % show data
    for i=1:length(pos)
        B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
        B = reshape(B,[4*length(pa),1])';
        A = imread(pos(i).im);
        showboxes(A,B,colorset);
        pause;
    end
end

% --------------------
%% Training 
%nInstances = 20;
content = dir(directory);
im_regex = 'png';
posim    = arrayfun(@(x) regexMatch(x.name, im_regex), content);
nInstances = sum(posim);

nFolds = ceil(nInstances / 10);
neg        = getNegativeData([directory,'../neg_D/'],'png');

apk = cell(nFolds,1);
prec = cell(nFolds,1);
rec = cell(nFolds,1);

allBoxes = cell(nFolds,1);
allTests = cell(nFolds,1);
allModels = cell(nFolds,1);

current = 0;

% cross validation
for ci = 1:nFolds
    fprintf('-----------------------------%d-------------------------------\n', ci);
    
    lastPos = min(current+10,nInstances);
    testID = setdiff(1:nInstances, current+1:lastPos); % current+1:lastTest is pos
    current = lastPos;
    
    [pos test] = getPositiveDataSeparate(directory,'png', directory_txt, 'txt',testID);
    if isempty(pos)
        fprintf('Path error!\n');
        break;
    end
    pos        = pointtobox(pos,pa,s1,s2);
    if isempty(test)
        test = pos;
    end
    
    % --------------------
    % training
    model = trainmodel([name, '_', num2str(ci)],pos,neg,K,pa,sbin);
    %save([name,'.mat'], 'model', 'pa', 'sbin', 'name');

    % --------------------
    % testing
    suffix = num2str(K')';
    model.thresh = min(model.thresh,-2);
    boxes = testmodel([name, '_', num2str(ci)],model,test,suffix);
    allBoxes{ci} = boxes;
    allTests{ci} = test;
    allModels{ci} = model;

    % precision-recall 
    [apk{ci},prec{ci},rec{ci}] = AVATOL_eval_apk(boxes,test);

end

if (save_model == 1)
    save([name, '_eval', '.mat'], 'apk', 'prec', 'rec', 'allBoxes', 'allTests', 'allModels');
end

BB = cat(2,allBoxes{:});
model_score = 0;
for i = 1:length(BB)
    model_score = model_score + BB{i}(1,end);
end

%% show results
%AVATOL_eval_boxplot('M1Class-transfer_eval.mat', directory, pa, colorset, 0.8, 1.5, 1)

if (demo_active == 1)
    BB1 = cat(2,allBoxes{:});
    % BB1 = BB1(:);
    % BB1 = BB1';

    %[TT1 ~] = getPositiveData(directory,'resize.png','resizeparts.txt',1.0);
    [TT1 ~] = getPositiveDataSeparate(directory, 'png', directory_txt, 'txt', []);
    % TT1 = cat(2,allTests{:});
    % TT1 = TT1(:);
    % TT1 = TT1';

    [apk1,prec1,rec1,dist1] = AVATOL_eval_apk(BB1,TT1,0.1,0);
    distMat1 = [dist1{:}];
    %distMat1 = sort(distMat1);
    figure(101), boxplot(distMat1(1:size(BB1,2),:));

    % show data
    testGT = pointtobox(TT1,pa,s1,s2);
    figure(102);
    for i=1:length(TT1)
        dummy = splitstring(TT1(i).im, '/');
        imPath = [directory, dummy{end}];
        im = imread(imPath);
        testB = [testGT(i).x1;testGT(i).y1;testGT(i).x2;testGT(i).y2];
        testB = reshape(testB,[4*length(pa),1])';
        showboxesGT(im,BB1{i}(1,:),testB,colorset);
        pause;
    end
    
    %visualization
    figure(103);
    visualizemodel(allModels{1});
    figure(104);
    visualizeskeleton(allModels{1});
end

function in = regexMatch(string, regex)
  if strfind(string, regex), in = 1; else in = 0; end