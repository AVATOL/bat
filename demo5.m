clear
close all
globals;

%% configuration
% data parameters need to be specified
Species = demo_config('Artibeus');


Species.part_color = cell(1,Species.num_parts);
colorset = hsv((length(Species.part_mask)-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
colorset = colorset(Species.part_mask,:);
for i = 1:Species.num_parts
    Species.part_color{i} = colorset(i,:);
end

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
model = trainmodel_ssvm(Species.name, pos, Species.num_mix, Species.parent, sbin);