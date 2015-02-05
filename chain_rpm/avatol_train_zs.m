function avatol_train_zs(part_list, taxon_list, taxa, samples, params, options)
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

fprintf('--------------------------------------\n');
fprintf('*=2=* train part filters with hard_neg_mine\n');
for p = 1:num_parts
    for t = 1:num_taxa
        cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t} '_hardneg'];
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

