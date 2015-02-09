function avatol_test_zs(det_results, output_dir, part_list, taxon_list, taxa, meta, trains, tests, params)

fsp = filesep;
det_results = strrep(det_results, '\', fsp);
output_dir = strrep(output_dir, '\', fsp);

% delete old files
%delete([det_results fsp '*']);
delete([output_dir fsp '*']);

name = [part_list{:}];
cachedir = params.cachedir;

train_test = cat(2,trains,tests); % DEBUG
samples = train_test; % DEBUG

num_parts = length(part_list);
num_taxa = length(taxon_list);
num_samples = length(samples);

psa_n = cell(num_parts,1);
bba_n = cell(num_parts,1);
for k = 1:num_parts
    psa_n{k} = zeros(num_taxa,num_samples);
    bba_n{k} = zeros(num_taxa,6,num_samples);
end

load('bat_mat/psa_n.mat');
load('bat_mat/bba_n.mat');

%% testing
for n = 1:length(samples)
    fprintf('testing: %d, %s, %s\n', n, samples(n).id, samples(n).taxon);
    im = imread(samples(n).im);
    samples(n).imsiz = size(im);
    
    for p = 1:num_parts
        cid  = arrayfun(@(x) strcmp(x.name, part_list{p}), meta.chars);
        bba = zeros(num_taxa,6);
        psa = -inf.*ones(num_taxa,1);
        
        for t = 1:num_taxa
            fprintf('(%d, %d, %d): %s, %s, %s\n', n, p, t, samples(n).id, part_list{p}, taxon_list{t});  

            %tid  = arrayfun(@(x) strcmp(x.name, taxon_list{t}), taxa);
            if taxa(t).part_mask(p) == 0 % no such part model indexed by (p,t)
                continue
            end
        
            cls = [name '_part_' part_list{p} '_taxon_' taxon_list{t}];
            assert(exist([cachedir cls '.mat'], 'file') > 0);
            load([cachedir cls]);
            
            params.latent = 0;
            [boxes, pscores] = test_single_dpm(params, model, im); 
            bba(t,:) = boxes(1,:);
            psa(t) = pscores(1); 

            %figure(1000); showboxes(im,boxes(1,:),{'g'}); 
            %title(sprintf('%s, %s: %s, %s', samples(n).id, samples(n).taxon, ...
            %    part_list{p}, taxon_list{t}));
            %export_fig([sprintf('%s_%s__%s_%s', samples(n).id, samples(n).taxon, part_list{p}, taxon_list{t}) '_det_single.png']);
        end % t
        
        psa_n{p}(:,n) = psa;
        bba_n{p}(:,:,n) = bba;
    end % p
end % n

save('psa_n.mat', 'psa_n');
save('bba_n.mat', 'bba_n');
