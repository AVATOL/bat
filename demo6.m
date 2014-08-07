clear
close all
globals;
dbstop if error

%% configuration
% data parameters need to be specified
Species = demo_config('Noctilio');

% feature parameters
sbin = 8; % Spatial resolution of HOG cell

%% annotate few images for training, randomly select K images
all_files = dir(Species.data_dir);
png    = arrayfun(@(x) ~isempty(strfind(x.name, 'png')), all_files);
all_files = all_files(logical(png));
perm = randperm(numel(all_files));
% perm = 1:numel(all_files);
train_index = perm(1:Species.num_train_data);
test_index = perm(Species.num_train_data+1:end);
train_files = all_files(train_index);
test_files = all_files(test_index);

% annotation
annotateParts(Species.data_dir, 'png', '', Species.part_name, train_files);

%% prepare data
[trainX testX] = prepareData(Species.data_dir, train_files, test_files);

% convert annotated points to bounding boxes
pos = trainX;
pos = pointtobox(pos,Species.parent,Species.bb_const1,Species.bb_const2);
% neg = getNegativeData([Species.rt_dir,'neg/'],'png');

% visualize training data
show_data = 0;
if (show_data == 1)
    % show data
    for i=1:length(pos)
        B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
        B = reshape(B,[4*length(Species.parent),1])';
        A = imread(pos(i).im);
        showboxes(A,B,Species.part_color);
        pause;
    end
end

%% training with SSVM
name = Species.name; num_mix = Species.num_mix; parent = Species.parent;
tsize = [4 4 32]; kk = 100; kkk = 100; fix_def = 0;
model = trainmodel_ssvm_rpm(name,pos,num_mix,parent,sbin,tsize,kk,kkk,fix_def);
%save([Species.name '.mat'], 'Species', 'model');

% visualize model
figure(1); visualizemodel(model);
figure(2); visualizeskeleton(model);

%% testing
model.thresh = 0;
model.thresh = min(model.thresh,-5);
[boxes,pscores] = testmodel(Species.name, model, testX, num2str(Species.num_mix')');

% visualize predictions
figure(3);
for ti = 1:length(testX)
    im = imread(testX(ti).im);
    showboxes(im, boxes{ti}(1,:), Species.part_color);
    fprintf('press enter to continue...\n');
    pause;
end