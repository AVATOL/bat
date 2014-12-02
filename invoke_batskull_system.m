function invoke_batskull_system_dummy(list_of_characters, input_folder, output_folder, ...
    detection_results_folder, progress_indicator)
% invoke_batskull_system('N','/home/hushell/working/git-dir/bat_backup/data3/input/DPM/N/vent/','','/home/hushell/working/git-dir/bat_backup/data3/detection_results/')

globals

if nargin < 5
    progress_indicator = [];
end

%% data information
input_folder = strrep(input_folder, '\', '/');
output_folder = strrep(output_folder, '\', '/');
detection_results_folder = strrep(detection_results_folder, '\', '/');
% get data
[trainX testX config] = avatol_config([list_of_characters{:}], input_folder);

% convert annotated points to bounding boxes
%pos = trainX;
%pos = pointtobox(pos,config.parent,config.bb_const1,config.bb_const2);

%% training with SSVM

%% testing

%% results writing 
part_mask = config.part_mask(2:(length(config.part_mask)-1)/2+1);
full_parts = config.full_parts;
full_part_names = config.full_part_names;
for i = 1:length(trainX) % DEBUG with trainX, should be testX
    %ti = mod(i,length(trainX));
    ti = i;
    %point = trainX(ti).point;
    left_parts = trainX(ti).left_parts;
    right_parts = trainX(ti).right_parts;
    
    assert(sum(part_mask) == length(left_parts));

    j = 1;
    for k = 1:length(full_parts)
        if ~part_mask(k)
            continue
        end
        [~,im] = fileparts(trainX(ti).im); % DEBUG with trainX, should be testX
        fp = fopen([detection_results_folder '/' full_parts{k} '_' trainX(ti).mid, '.txt'], 'w');
        ss = randi(2,1); 
        sid = config.characters(k).states(ss).id;
        snam = config.characters(k).states(ss).name;
        
        fprintf(fp, '%f,%f', left_parts(j,:));
        fprintf(fp, ':%s:%s:%s:%s\n', full_parts{k}, full_part_names{k}, sid, snam);
        fprintf(fp, '%f,%f', right_parts(j,:));
        fprintf(fp, ':%s:%s:%s:%s\n', full_parts{k}, full_part_names{k}, sid, snam);
        fclose(fp);
        j = j + 1;
    end
    %fprintf('press enter to continue...\n');
    %pause;
end

for k = 1:length(full_parts)
    if ~part_mask(k)
        continue
    end

    fp = fopen([output_folder '/' 'sorted_output_data_' full_parts{k} '_' full_part_names{k} '.txt'], 'w');
    for i = 1:length(trainX) % DEBUG with trainX, should be testX
        det_txt = [detection_results_folder '/' full_parts{k} '_' trainX(i).mid, '.txt'];
        fprintf(fp, 'image_scored|%s|%s|%s|%s|%s|%s|%s\n', ...
            trainX(i).im, full_parts{k}, full_part_names{k}, det_txt, trainX(i).tid, '1', num2str(0.9));
    end
    fclose(fp);
end

end
