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

%% individual part -- model.node
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
        end

        % DEBUG code
        if params.test_in_train
            vis_model(model);
            fprintf('norm(w) = %f\n', norm(model.w,2));
            im = imread(subsamps(1).im);
            [boxes] = dpm_test(params, model, im);
            figure; showboxes(im,boxes(1,:),{'g'});
            pause;
        end
    end % num_taxa
end % num_parts

return

%% DPMs -- model.node,edge,parent
model = initmodel(samples,sbin,tsize);
def = data_def(samples,model);
idx = clusterparts(def,K,pa); % each part in each example has a cluster label

%% RPM -- model.node,edge,dag,parents,omis
