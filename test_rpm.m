clear
close all
globals;
dbstop if error
Species = demo_config('Molossus');
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

name = Species.name; num_mix = Species.num_mix; parent = Species.parent;
tsize = [4 4 32]; kk = 100; kkk = 100; fix_def = 0;
model = trainmodel_ssvm_rpm(name,pos,num_mix,parent,sbin,tsize,kk,kkk,fix_def);
%save([Species.name '.mat'], 'Species', 'model');


numparts = Species.num_parts;
allov = ones(length(pos),numparts)*1e10;
allovu = ones(length(pos),numparts)*1e10;
for ti = 1:length(pos)
    im = imread(pos(ti).im);
    bbox = [pos(ti).x1' pos(ti).y1' pos(ti).x2' pos(ti).y2'];
    [allov(ti,:),allovu(ti,:)] = detect_fast_initmodel(im, model, bbox); %TODO: ov ovu from GT
end
rov = min(allov,[],1);
rovu = min(allovu,[],1);

param.overlap   = 0.5;
param.overlap1   = param.overlap / 2;
param.fix_def   = 0;

for c = 1:5
ov = rov;
ovu = rovu - 0.2;
model.ominode = struct('w',{},'i',{});
model.omiedge = struct('w',{},'i',{});
for k = 1:numparts
  nb = length(model.ominode);
  b.w = ov(k);
  b.i = model.len + 1;
  model.ominode(nb+1) = b;
  model.len = model.len + numel(b.w);
  model.components{1}(k).onid = nb+1;
  
  if k > 1
    nb = length(model.omiedge);
    bb.w = ovu(k);
    bb.i = model.len + 1;
    model.omiedge(nb+1) = bb;
    model.len = model.len + numel(bb.w);
    model.components{1}(k).omid = nb+1;
  end
end

model.adj = zeros(length(model.pa));
for k = 2:length(model.pa)
  model.adj(k,model.pa(k)) = 1;
end

i = 2;
im = imread(pos(i).im);
bbox = [pos(i).x1' pos(i).y1' pos(i).x2' pos(i).y2'];
B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
%   B = reshape(B,[4*length(Species.parent),1])';

radius = 0;
for j = 1:numparts
  disp(['part ' num2str(j)]);
  bim = im;
  C = ceil(B(:,j));
  bim(max(1,C(2)-radius):C(4)+radius,max(1,C(1)-radius):C(3)+radius,:) = 0;
  pyra = featpyramid(bim, model); 
  pat.pyra = pyra;
  lab.bbox = bbox;
  label = rpm_oracle2(param, model, pat, lab);
  figure;
  showboxes(bim,label.bbox,Species.part_color);
end
pause
end
bb = label.bbox;
bb = reshape(bb(1:44),[4 numparts])';
bb(3:7,:) = box(3:7,:);
label.bbox = reshape(bb', [1 44]);
figure;showboxes(bim,label.bbox,Species.part_color,[8]);
export_fig pics2/G13.png

for i = 1:length(pos)
  bim = imread(pos(i).im);
  j = i + 1;
  C = ceil(B(:,j));
  bim(max(1,C(2)-radius):C(4)+radius,max(1,C(1)-radius):C(3)+radius,:) = 0;
  imshow(bim);
  export_fig(['pics2/bim' num2str(i) '.png'])
end
