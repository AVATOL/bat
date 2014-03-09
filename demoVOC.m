clear
close all
globals;

%% configuration
% data parameters need to be specified
%Species = demo_config('Mormoops');

% feature parameters
sbin = 8; % Spatial resolution of HOG cell

%% prepare data
load VOC2011PersonLayout.mat
viewpoint = 1;
trainX = components{viewpoint,4}.tr;
Species.name = components{viewpoint,4}.prefix;
Species.prefix = Species.name;
Species.num_parts = components{viewpoint,4}.num_parts;
Species.bb_const1 = 0.5;
Species.bb_const2 = 0.7;
Species.parent = [0 1 1 1 1]; % TODO, now [head,belly,lhand,rhand,lfoot,rfoot]
Species.num_mix = [1 1 1 1 1];
Species.part_mask = logical([1 1 1 1 1]);
Species.part_map = [1 2 3 4 5];
Species.num_train_data = 10;

Species.part_color = cell(1,Species.num_parts);
colorset = hsv(numel(Species.part_mask));
%colorset = [colorset; colorset(2:end,:)];
colorset = colorset(Species.part_mask,:);
for i = 1:Species.num_parts
    Species.part_color{i} = colorset(i,:);
end

dag = zeros(length(Species.parent));
pa = Species.parent;
for i = 1:length(pa)
  if pa(i) == 0
    continue
  end
  dag(pa(i),i) = 1;
end
Species.dag = dag;

% convert annotated points to bounding boxes
pos = trainX;
pos = pointtobox(pos,Species.parent,Species.bb_const1,Species.bb_const2);

Species.rt_dir = '/home/hushell/working/datasets/VOCdevkit/'; % TODO
for i=1:length(pos)
  pos(i).im = [Species.rt_dir pos(i).im]; % TODO
end

% visualize training data
show_data = 0;
if (show_data == 1)
    % show data
    for i=1:length(pos)
        B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
        B = reshape(B,[4*length(Species.parent),1])';
        A = imread(pos(i).im);
        fprintf('%s: ', pos(i).im); disp([pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2]);
        showboxes(A,B,Species.part_color);
        pause;
    end
end

% Species.tr = pos(1:Species.num_train_data);
% species{1} = Species;
% kk = 100; kkk = 100; fix_def = 0; tsize = [6 6 32];
% model = train_interface(species,sbin,kk,kkk,fix_def,tsize);
% 
% return

%% training with SSVM
%model = trainmodel_ssvm(Species.name, pos, Species.num_mix, Species.parent, sbin, 100, 100, 1);
tsize = []; kk = 100; kkk = 100; fix_def = 0;
model = trainmodel_ssvm(Species.name,pos,Species.num_mix,Species.parent,sbin,tsize,kk,kkk,fix_def);
save([Species.name '.mat'], 'Species', 'model');

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