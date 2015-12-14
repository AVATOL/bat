function avatol_train(part_list, taxon_list, taxa, samples, params, options)
%
% TODO: params.latent -> params.write/fmap

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
        if taxa(t).split == 0
            continue;
        end
        
        cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
        fprintf('(part %d, taxon %d): training %s...\n', p, t, cls);
        try
            load([cachedir cls]);
            fprintf('%s trained already.\n', cls);
        catch
            % select samples for p and t
            tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), samples); % in t
            tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            pidx = arrayfun(@(x) taxa(tid).part_mask(p) == 1, samples); % has p
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
                    subsamps(n).x2, subsamps(n).y2])); % not all 0's
            end

            % training warped
            params.warp      = 1;
            params.latent    = 0;
            tic
            [model,progress] = train_single_part(cls,subsamps,params,options);
            fprintf('warped_%s trained in %.2fs.\n', cls, toc);

            % NOTE: training latent no need & doesn't work well this case
            %params.warp      = 0;
            %params.latent    = 1;
            %tic
            %[model,progress] = train_single_part(cls,subsamps,params,options);
            %fprintf('%s trained in %.2fs.\n', cls, toc);

            % DEBUG code
            if params.test_in_train
                vis_model(model);
                fprintf('norm(w) = %f\n', norm(model.w,2));
                im = imread(subsamps(1).im);
                [boxes] = test_single_dpm(params, model, im);
                figure(1000); showboxes(im,boxes(1,:),{'g'});
                pause(1);
            end
        end % try-catch
    end % taxa
end % parts

%% DPMs for each taxon
fprintf('--------------------------------------\n');
fprintf('*=2=* train DPMs for each taxon\n');
for t = 1:num_taxa
    if taxa(t).split == 0
        continue;
    end
    
    cls = [name '_DPM_taxon_' taxon_list{t}];
    fprintf('(taxon %d): DPM training %s...\n', t, cls);
    try
        load([cachedir cls]);
        fprintf('%s trained already.\n', cls);
    catch
        tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
        pmsk = taxa(tid).part_mask;
        
        % select samples for t
        tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), samples); % in t
        subsamps = samples(tidx);
        
        if isempty(subsamps)
            continue
        end

        % keep only existing points/bboxes
        for n = 1:length(subsamps)
            subsamps(n).x1 = subsamps(n).x1(pmsk); 
            subsamps(n).y1 = subsamps(n).y1(pmsk);
            subsamps(n).x2 = subsamps(n).x2(pmsk);
            subsamps(n).y2 = subsamps(n).y2(pmsk);
            subsamps(n).point = subsamps(n).point(pmsk,:);
        end
        
        % DEBUG code
        if params.show_data
            for i = 1:length(subsamps)
                B = [subsamps(i).x1;subsamps(i).y1;subsamps(i).x2;subsamps(i).y2];
                B = reshape(B,[4*taxa(tid).num_parts,1])';
                A = imread(subsamps(i).im);
                figure(1001); showboxes(A,B,taxa(tid).part_color);
                title(sprintf('%s, %s',subsamps(i).taxon, subsamps(i).id));
                pause(0.5);
            end
        end

        % load indiv models belong to t
        part_models = {};
        for p = 1:num_parts
            if pmsk(p) == 0
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
        params.lossFn    = @dpm_loss;
        params.featureFn = @dpm_featmap;
        params.oracleFn  = @dpm_oracle;

        % training
        tic
        [model,progress] = train_single_dpm(cls,taxa(tid).parent,subsamps,part_models,params,options);
        fprintf('%s trained in %.2fs.\n', cls, toc);

        % DEBUG code
        if params.test_in_train
            vis_model(model, cls);
            im = imread(subsamps(1).im);
            [boxes] = test_single_dpm(params, model, im);
            figure(1000); showboxes(im,boxes(1,:),taxa(tid).part_color);
            export_fig([cls '_det_res.png']);
        end
    end % try-catch
end % taxa

