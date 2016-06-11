function ret = avatol_main(input_dir, output_dir, det_results)

close all
setup_path
[rootDir, ~, ~] = fileparts(output_dir);

%% model params
params = [];
params.num_parts  = 5;
params.sbin       = 8;
params.interval   = 10;
params.tsize      = [5 5 32];
params.maxsize    = [5 5]; %JED sliding window size
params.cachedir   = fullfile(rootDir, 'cache/');
params.boxsize    = 48;
params.bb_cand    = [1 3 4 5]; %JED - used only in pointtobox
                     % JED bb_ratio (bounding box ratio?) used only in pointtobox
params.bb_ratio   = sparse([0 0 1.0 1.5 3.0; % I1-P1 I1-P4 I1-M3
                            0 0 0   0   0; 
                            0 0 0   1.0 2.5; % P1-P4 P1-M3
                            0 0 0   0   2.5; % P4-M3
                            0 0 0   0   0]);
params.bb_range   = [35, 80]; % range of sizes of bbox in pixel - just used in pointtobox
params.bb_taxa_spec = {'Molossus molossus', 'Mormoops megalophylla', ...
    'Pteropus vampyrus', 'Taphozous melanopogon', 'Hipposideros diadema'};
params.bb_ratio_spec = [2.4, 3.4, 2.5, 2.2, 3.3]; % need to test st-ed
% modify below for diff stages using SSVM
params.len        = 0; 
params.kstart     = 1;
params.fix_def    = 0;
params.overlap    = 0.5;
params.thresh     = 0;
params.presence_w = 0;
% control flags
params.show_data   = 0; % 1 = visualize progress, 0 = don't
params.test_in_train = 0; % 1 = visualize progress, 0 = don't
params.show_interm = 0;

%% ssvm params 
options = [];
options.lambda = 1;
options.gap_threshold = 0.1; % duality gap stopping criterion
options.num_passes = 100; % max number of passes through data
options.do_line_search = 1;
options.debug = 0; % for displaying more info (makes code about 3x slower)

%% create cache dir
if ~exist(params.cachedir,'dir')
  mkdir(params.cachedir);
end

%% data configuration
if nargin == 0
    input_dir = '/scratch/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/input/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
    output_dir = '/scratch/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/output/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
    det_results = '/scratch/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/detection_results/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
end
[trainset, testset, taxa, meta, ~, testset_pruned] = avatol_config(input_dir, params);

%% training
traintestset = cat(2,trainset,testset);
avatol_train(meta.part_list, meta.taxon_list, taxa, traintestset, params, options);

%% testing
avatol_test_zs_lr(det_results, output_dir, meta.part_list, meta.taxon_list, taxa, meta, trainset, testset, params, testset_pruned);

ret = 1;

