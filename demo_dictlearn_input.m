% demo train models as input for learning dictionary

clear
close all
globals;

s_all = {'Artibeus', 'Noctilio', 'Trachops', 'Molossus'};

for si = 1:length(s_all)
    %% configuration
    % data parameters need to be specified
    Species = demo_config(s_all{si});

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
    num_files = numel(all_files);
    
    all_index = 1:num_files;
    t_st = 1;
    t_end = Species.num_train_data;
    stride = 4;
    while t_end <= num_files && t_st + stride <= t_end
        
        m_name = [Species.name '_' num2str(t_st) '_' num2str(t_end)]
        
        train_index = t_st:t_end;
        test_index = setdiff(all_index, train_index);
        train_files = all_files(train_index);
        test_files = all_files(test_index);

        % annotation
        annotateParts(Species.data_dir, 'png', '', Species.part_name, train_files);

        %% prepare data
        [trainX testX] = prepareData(Species.data_dir, train_files, test_files);

        % convert annotated points to bounding boxes
        pos = trainX;
        %pos = pointtobox(pos,Species.parent,Species.bb_const1,Species.bb_const2);
        pos = pointtobox_fix(pos, 40);
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

        %% training
        model = trainmodel(m_name, pos, neg, Species.num_mix, Species.parent, sbin);
        save([m_name '.mat'], 'Species', 'model');
        
        t_st = t_st + stride;
        t_end = t_end + stride;
        t_end = min(t_end, num_files);

    %   % visualize model
    %     figure(1); visualizemodel(model);
    %     figure(2); visualizeskeleton(model);

    %   %% testing
    %     model.thresh = min(model.thresh,-5);
    %     [boxes,pscores] = testmodel(m_name, model, testX, num2str(Species.num_mix')');
    % 
    %     % visualize predictions
    %     figure(3);
    %     for ti = 1:length(testX)
    %         im = imread(testX(ti).im);
    %         showboxes(im, boxes{ti}(1,:), Species.part_color);
    %         fprintf('press enter to continue...\n');
    %         pause;
    %     end
    end
end
