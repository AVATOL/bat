function model = dpm_train(part_list, taxon_list, taxa, samples, params, options)
%

name = [part_list{:}];
cachedir = params.cachedir;
file = [cachedir name '.log'];
delete(file);
diary(file);

num_parts = length(part_list);
num_taxa = length(taxon_list);
num_samples = length(samples);
params.num_parts = num_parts;
params.num_taxa = num_taxa;
params.num_samples = num_samples;

%% individual part -- model.node,edge,bias,parent
fprintf('--------------------------------------\n');
fprintf('*=1=* train part filters independently\n');
for p = 1:num_parts
    for t = 1:num_taxa
        cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
        try
            load([cachedir cls]);
        catch
            % select samples for p and t
            tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), samples);
            tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            pidx = arrayfun(@(x) taxa(tid).part_mask(p) == 1, samples);
            subsamps = samples(tidx & pidx);
            
            if isempty(subsamps)
                continue
            end

            % keep only box p
            for n = 1:length(subsamps)
                subsamps(n).x1 = subsamps(n).x1(p);
                subsamps(n).y1 = subsamps(n).y1(p);
                subsamps(n).x2 = subsamps(n).x2(p);
                subsamps(n).y2 = subsamps(n).y2(p);
                assert(any([subsamps(n).x1, subsamps(n).y1,...
                    subsamps(n).x2, subsamps(n).y2]));
            end

            % set params 
            params.warp      = 1;
            params.latent    = 0;

            % training
            fprintf('(part %d, taxon %d): training %s...\n', p, t, cls);
            tic
            [model,progress] = train_single_part(cls,subsamps,params,options);
            fprintf('%s trained in %.2fs.\n', cls, toc);

            % DEBUG code
            if params.test_in_train
                vis_model(model);
                fprintf('norm(w) = %f\n', norm(model.w,2));
                im = imread(subsamps(1).im);
                [boxes] = dpm_test(params, model, im);
                figure; showboxes(im,boxes(1,:),{'g'});
                pause;
            end
        end % try-catch
    end % taxa
end % parts

%% DPMs for each taxon
fprintf('--------------------------------------\n');
fprintf('*=2=* train DPMs for each taxon\n');
for t = 1:num_taxa
    cls = [name '_DPM_taxon_' taxon_list{t}];
    try
        load([cachedir cls]);
    catch
        % select samples for t
        tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), samples);
        subsamps = samples(tidx);
        
        if isempty(subsamps)
            continue
        end

        % keep only non-zero points/bboxes
        for n = 1:length(subsamps)
            % keep originals
            subsamps(n).x1orig = subsamps(n).x1;
            subsamps(n).y1orig = subsamps(n).y1;
            subsamps(n).x2orig = subsamps(n).x2;
            subsamps(n).y2orig = subsamps(n).y2;
            subsamps(n).pointorig = subsamps(n).point;
            % remove all-zero columns
            bbox = [subsamps(n).x1;subsamps(n).y1;subsamps(n).x2;subsamps(n).y2];
            bbox = bbox(:,any(bbox,1));
            subsamps(n).x1 = bbox(1,:); 
            subsamps(n).y1 = bbox(2,:);
            subsamps(n).x2 = bbox(3,:);
            subsamps(n).y2 = bbox(4,:);
            % remove all-zero rows
            subsamps(n).point = subsamps(n).point(any(subsamps(n).point,2),:);
        end

        % load indiv models belong to t
        tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
        part_models = {};
        for p = 1:num_parts
            if taxa(tid).part_mask(p) == 0
                continue
            end
            
            pmname = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
            load([cachedir pmname]);

            part_models{end+1} = model;
        end
        assert(length(part_models) == taxa(tid).num_parts);

        % set params 
        params.warp      = 0;
        params.latent    = 1;
        params.kstart    = 100;

        % training
        fprintf('(taxon %d): DPM training %s...\n', t, cls);
        tic
        [model,progress] = train_taxon_dpm(cls,taxa(tid),subsamps,part_models,params,options);
        fprintf('%s trained in %.2fs.\n', cls, toc);

        % DEBUG code
        if params.test_in_train
            vis_model(model);
            fprintf('norm(w) = %f\n', norm(model.w,2));
            im = imread(subsamps(1).im);
            [boxes] = dpm_test(params, model, im);
            figure; showboxes(im,boxes(1,:),taxa(tid).part_color);
            pause;
        end
    end % try-catch
end % taxa

%% DPMs rooted at each node
fprintf('--------------------------------------\n');
fprintf('*=3=* train DPMs rooted at each node\n');

