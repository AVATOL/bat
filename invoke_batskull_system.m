function invoke_batskull_system(list_of_characters, input_folder, output_folder, ...
    detection_results_folder, progress_indicator)
% invoke_batskull_system('N','/home/hushell/working/git-dir/bat_backup/data3/input/DPM/N/vent/','','/home/hushell/working/git-dir/bat_backup/data3/detection_results/')

globals

if nargin < 5
    progress_indicator = [];
end

%% data information
% get data
[trainX testX config] = avatol_config([list_of_characters{:}], input_folder);

% convert annotated points to bounding boxes
pos = trainX;
pos = pointtobox(pos,config.parent,config.bb_const1,config.bb_const2);

% visualize training data
show_data = 0;
if (show_data == 1)
    % show data
    for i=1:length(pos)
        B = [pos(i).x1;pos(i).y1;pos(i).x2;pos(i).y2];
        B = reshape(B,[4*config.num_parts,1])';
        A = imread(pos(i).im);
        showboxes(A,B,config.part_color);
        pause;
    end
end

%% training with SSVM
name = config.name; num_mix = config.num_mix; parent = config.parent;
tsize = [4 4 32]; kk = 100; kkk = 100; fix_def = 0; sbin = 8;
model = trainmodel_ssvm(name,pos,num_mix,parent,sbin,tsize,kk,kkk,fix_def);
%save([config.name '.mat'], 'config', 'model');

% visualize model
figure(1); visualizemodel(model);
figure(2); visualizeskeleton(model);

%% testing
model.thresh = 0;
model.thresh = min(model.thresh,-5);
[boxes,pscores] = testmodel(config.name, model, testX, num2str(config.num_mix')');

% visualize predictions
part_mask = config.part_mask(2:(length(config.part_mask)-1)/2+1);
full_parts = config.full_parts;
figure(3);
for ti = 1:length(testX)
    im = imread(testX(ti).im);
    box = boxes{ti}(1,:);
    showboxes(im, box, config.part_color);
    box = box(:,1:4*config.num_parts);
    box = reshape(box,4,config.num_parts);
    point = [(box(1,:)+box(3,:))./2; (box(2,:)+box(4,:))./2];
    left_parts = point(:,2:(config.num_parts-1)/2+1)';
    right_parts = point(:,2+(config.num_parts-1)/2:end)';
    
    j = 1;
    for k = 1:length(full_parts)
        if ~part_mask(k)
            continue
        end
        [~,im] = fileparts(testX(ti).im);
        fp = fopen([detection_results_folder '/' im '_' full_parts{k}, '.txt'], 'w');
        fprintf(fp, '%f,%f\n', left_parts(j,:));
        fprintf(fp, '%f,%f\n', right_parts(j,:));
        fclose(fp);
        j = j + 1;
    end
    fprintf('press enter to continue...\n');
    pause;
end

end