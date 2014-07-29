function [boxes, model, config] = invoke_DPM_batskull_detection(input_path, output_path, vis)
% 

if nargin < 3
    vis = 0;
end

globals;

%% configuration
% data parameters
Artibeus.data_dir = input_path;
Artibeus.num_train_data = 8;
Artibeus.num_parts = 13;
Artibeus.name = ['Artibeus', '_', num2str(Artibeus.num_parts), '_', num2str(Artibeus.num_train_data)];
Artibeus.num_mix = [1 1 1 1 1 1 1 1 1 1 1 1 1];
Artibeus.parent = [0 1 2 3 4 5 6 1 8 9 10 11 12];
Artibeus.part_name = {'Nasal',...
    'I1 upper','C upper','P4 upper','P5 upper','M1 upper','M2 upper',...
    'I1 lower','C lower','P4 lower','P5 lower','M1 lower','M2 lower'};
Artibeus.part_color = cell(1,Artibeus.num_parts);
colorset = hsv((Artibeus.num_parts-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
for i = 1:Artibeus.num_parts
    Artibeus.part_color{i} = colorset(i,:);
end
config = Artibeus;

% feature parameters
sbin = 8; % Spatial resolution of HOG cell

%% annotate few images for training, randomly select K images
all_files = dir(Artibeus.data_dir);
png    = arrayfun(@(x) ~isempty(strfind(x.name, 'png')), all_files);
all_files = all_files(logical(png));
perm = randperm(numel(all_files));
train_index = perm(1:Artibeus.num_train_data);
test_index = perm(Artibeus.num_train_data+1:end);
train_files = all_files(train_index);
test_files = all_files(test_index);

% annotation
annotateParts(Artibeus.data_dir, 'png', '', Artibeus.part_name, train_files);

%% prepare data
[trainX testX] = prepareData(Artibeus.data_dir, train_files, test_files);

% convert annotated points to bounding boxes
pos = trainX;
pos = pointtobox(pos,Artibeus.parent,0.8,1.3);
neg = getNegativeData([Artibeus.data_dir,'neg/'],'png');

% visualize training data
if (vis == 1)
    figure;
    title('show data');
    for i=1:length(pos)
        B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
        B = reshape(B,[4*length(Artibeus.parent),1])';
        A = imread(pos(i).im);
        showboxes(A,B,Artibeus.part_color);
        pause;
    end
end

%% training
model = trainmodel(Artibeus.name, pos, neg, Artibeus.num_mix, Artibeus.parent, sbin);
save([Artibeus.name '.mat'], 'Artibeus', 'model');

% visualize model
if (vis == 1)
    figure(1); visualizemodel(model);
    figure(2); visualizeskeleton(model);
end

%% testing
model.thresh = min(model.thresh,-2);
[boxes,pscores] = testmodel(Artibeus.name, model, testX, num2str(Artibeus.num_mix')');

% write boxes
for ti = 1:length(test_files)
    fname = [output_path test_files(ti).name(1:end-4) '-output.txt'];
    fp = fopen(fname, 'w');
    fprintf(fp, '%f ', boxes{ti}(1,:));
    fclose(fp);
end

% visualize predictions
if (vis == 1)
    figure(3);
    for ti = 1:length(testX)
        im = imread(testX(ti).im);
        showboxes(im, boxes{ti}(1,:), Artibeus.part_color);
        fprintf('press enter to continue...\n');
        pause;
    end
end