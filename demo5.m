clear
close all
globals;
dbstop if error

%% configuration
% data parameters need to be specified
Species = demo_config('Artibeus');

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
model = trainmodel_ssvm(name,pos,num_mix,parent,sbin,tsize,kk,kkk,fix_def);
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

return % after was RPM stuffs

%% getting initialization
% im = imread(testX(1).im);
% [~,~,boxes,msgs,parts,bkptr] = detect_fast_initmodel(im, model);
numparts = Species.num_parts;
% allov = ones(length(pos),numparts)*1e10;
% allovu = ones(length(pos),numparts)*1e10;
% for ti = 1:length(pos)
%     im = imread(pos(ti).im);
%     bbox = [pos(ti).x1' pos(ti).y1' pos(ti).x2' pos(ti).y2'];
%     [allov(ti,:),allovu(ti,:)] = detect_fast_initmodel(im, model, bbox); %TODO: ov ovu from GT
% end
% ov = min(allov,[],1);
% ovu = min(allovu,[],1);
% 
% model.ominode = struct('w',{},'i',{});
% model.omiedge = struct('w',{},'i',{});
% for k = 1:numparts
%   nb = length(model.ominode);
%   b.w = ov(k);
%   b.i = model.len + 1;
%   model.ominode(nb+1) = b;
%   model.len = model.len + numel(b.w);
%   model.components{1}(k).onid = nb+1;
%   
%   if k > 1
%     nb = length(model.omiedge);
%     bb.w = ovu(k);
%     bb.i = model.len + 1;
%     model.omiedge(nb+1) = bb;
%     model.len = model.len + numel(bb.w);
%     model.components{1}(k).omid = nb+1;
%   end
% end
% 
% model.adj = zeros(length(model.pa));
% for k = 2:length(model.pa)
%   model.adj(k,model.pa(k)) = 1;
% end

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
param.parts = numparts;
param.len = model.len;
param.warp = 0;

label = detect_oracle(param, model, patterns{1}, labels{1});
w = model2vec(model);
phi = detect_featuremap(param,[],label);
w'*phi


% label = rpm_oracle2(param, model, patterns{1}, labels{1});
% showboxes(im,label.bbox,Species.part_color);
% 
% i = 2;
% im = imread(pos(i).im);
% bbox = [pos(i).x1' pos(i).y1' pos(i).x2' pos(i).y2'];
% B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
% %   B = reshape(B,[4*length(Species.parent),1])';
% 
% radius = 0;
% for j = 1:numparts
%   disp(['part ' num2str(j)]);
%   bim = im;
%   C = ceil(B(:,j));
%   bim(max(1,C(2)-radius):C(4)+radius,max(1,C(1)-radius):C(3)+radius,:) = 0;
%   pyra = featpyramid(bim, model); 
%   pat.pyra = pyra;
%   lab.bbox = bbox;
%   label = rpm_oracle2(param, model, pat, lab);
%   showboxes(bim,label.bbox,Species.part_color);
%   pause
% end
