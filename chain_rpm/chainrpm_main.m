ret = function chainrpm_main()
% TODO: invoke, input, output 

setup_path

%% model params
params = [];
params.sbin       = 8;
params.interval   = 10;
params.tsize      = [4 4 32];
params.maxsize    = [4 4];
% modify below for diff stages
params.len        = 0; 
params.kstart     = 1;
params.fix_def    = 0;
params.overlap    = 0.5;
params.thresh     = 0;
params.presence_w = 0;
params.num_parts  = 1;
% path
params.cachedir   = 'cache/';

%% ssvm params 
options = [];
options.lambda = 1;
options.gap_threshold = 0.1; % duality gap stopping criterion
options.num_passes = 100; % max number of passes through data
options.do_line_search = 1;
options.debug = 0; % for displaying more info (makes code about 3x slower)
