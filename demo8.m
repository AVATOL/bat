clear
close all
globals;

%% configuration
% data parameters need to be specified
Species = demo_config('Molossus');


Species.part_color = cell(1,Species.num_parts);
colorset = hsv((length(Species.part_mask)-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
colorset = colorset(Species.part_mask,:);
Species.part_color = mat2cell(colorset, ones(1,Species.num_parts), 3);

% feature parameters
sbin = 8; % Spatial resolution of HOG cell

%% annotate few images for training, randomly select K images
all_files = dir(Species.data_dir);
png    = arrayfun(@(x) ~isempty(strfind(x.name, 'png')), all_files);
all_files = all_files(logical(png));
perm = randperm(numel(all_files));
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
neg = getNegativeData([Species.rt_dir,'neg/'],'png');

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
%model = trainmodel_ssvm(Species.name, pos, Species.num_mix, Species.parent, sbin, 100, 100, 1);
tsize = [4 4 32]; kk = 100; kkk = 100; fix_def = 0;
model = trainmodel_ssvm_rpm(Species.name,pos,Species.num_mix,Species.parent,sbin,tsize,kk,kkk,fix_def);
%save([Species.name '.mat'], 'Species', 'model');

% visualize model
% figure(1); visualizemodel(model);
% figure(2); visualizeskeleton(model);

%% getting initialization
% im = imread(testX(1).im);
% pyra = featpyramid(im,model);
% [components,filters,resp] = parsemodel(model,pyra);

patterns = cell(length(pos),1);
labels = cell(length(pos),1);

for i = 1:1  
  im = imread(pos(i).im);
  bbox = [pos(i).x1' pos(i).y1' pos(i).x2' pos(i).y2'];
  B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
%   C = B(:,6);
%   im(C(2):C(4),C(1):C(3),:) = 0;
%   im(C(2)+20:C(4)+20,C(1):C(3),:) = 0;
  
  pyra = featpyramid(im, model); 
  patterns{i}.pyra = pyra;
  %bbox = [reshape(bbox',1,4*length(pos(i).x1)) 1 0];
  labels{i}.bbox = bbox;
end

param.overlap   = 0.5;
param.overlap1   = param.overlap / 2;
param.fix_def   = 0;
label = rpm_oracle2(param, model, patterns{1}, labels{1});
showboxes(im,label.bbox,Species.part_color);
w = model2vec(model);

i = 2;
im = imread(pos(i).im);
bbox = [pos(i).x1' pos(i).y1' pos(i).x2' pos(i).y2'];
B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
%   B = reshape(B,[4*length(Species.parent),1])';

radius = 0;
numparts = Species.num_parts;
for j = 1:numparts
  disp(['part ' num2str(j)]);
  bim = im;
  C = ceil(B(:,j));
  bim(max(1,C(2)-radius):C(4)+radius,max(1,C(1)-radius):C(3)+radius,:) = 0;
  pyra = featpyramid(bim, model); 
  pat.pyra = pyra;
  lab.bbox = bbox;
  label = rpm_oracle2(param, model, pat, lab);
  showboxes(bim,label.bbox,Species.part_color);
  pause
end
