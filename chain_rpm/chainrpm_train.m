function model = chainrpm_train(part_list, taxon_list, samples, params)
% TODO: chainrpm_oracle, latent ssvm for omis

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
fprintf('*=1=* train part filters independently\n');
for p = 1:num_parts
    for t = 1:num_taxa
        cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
        try
            load([cachedir cls]);
        catch
            % select samples for p and t
            tidx = arrayfun(@(x) strcmp(x.taxon, taxon_list{t}), samples);
            pidx = arrayfun(@(x) x.part_mask(p) == 1, samples);
            subsamps = samples(tidx & pidx);

            % keep only box p
            for n = 1:length(subsamps)
                subsamps(n).x1 = subsamps(n).x1(p);
                subsamps(n).y1 = subsamps(n).y1(p);
                subsamps(n).x2 = subsamps(n).x2(p);
                subsamps(n).y2 = subsamps(n).y2(p);
            end

            % set params 
            params.warp      = 1;
            params.latent    = 0;

            % training
            tic
            [model,progress] = train_single_part(cls,subsamps,params,options);
            fprintf('%s trained in %.2fs.\n', cls, toc);
        end

        % DEBUG code
        %visualizemodel(models{1})
        %norm(models{1}.w,2)
        %im = imread(samples(8).im);
        %[boxes] = detect_fast(im, models{1}, 0);
        %boxes = nms(boxes,0.3);
        %showboxes(im,boxes(1,:),{'g'})
        %pause;
    end % num_taxa
end % num_parts

return

%% DPMs -- model.node,edge,parent

%% RPM -- model.node,edge,dag,parents,omis
