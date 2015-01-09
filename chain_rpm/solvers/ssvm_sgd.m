function [model, progress] = ssvm_sgd(patterns, labels, model, params, options)
%

% parse the options
n = length(patterns); % number of training examples
options_default = defaultOptions(n);
if (nargin > 4)
    options = processOptions(options, options_default);
else
    options = options_default;
end

% setup
lambda = options.lambda;
len = params.len;
phi = params.featureFn; 
loss = params.lossFn;
maxOracle = params.oracleFn; 

if ~isfield(model, 'w')
    model.w = zeros(len,1);
end

if (options.do_weighted_averaging)
    wAvg = model.w; % \bar w in the paper contains weighted average of iterates
end

% logging
progress = [];
k = params.kstart; % k large if expect w changes slowly
if (options.debug_multiplier == 0)
    debug_iter = n + k;
    options.debug_multiplier = 100;
else
    debug_iter = 1;
end
progress.primal = [];
progress.eff_pass = [];
progress.train_error = [];
if (isstruct(options.test_data) && isfield(options.test_data, 'patterns'))
    progress.test_error = [];
end

fprintf('running SSVM_SGD on %d examples.\n', n);

rand('state',options.rand_seed);
randn('state',options.rand_seed);
tic();

%% Main loop 
for p = 1:options.num_passes
	fprintf('>');
    if mod(p,50) == 0; fprintf('\n'); end;

    perm = [];
    if (isequal(options.sample, 'perm'))
        perm = randperm(n);
    end

    for dummy = 1:n
        % 1) Picking random example:
        if (isequal(options.sample, 'uniform'))
            i = randi(n); % uniform sampling
        else
            i = perm(dummy); % random permutation
        end
    
        % 2) solve the loss-augmented inference for point i
        ystar_i = maxOracle(params, model, patterns{i}, labels{i});
        
        % TODO: rscore != lscore: probably because shiftdt() != w*def_vec
        %rscore = ystar_i.bbox(end);
        %lscore = model.w'*phi(params, patterns{i}, ystar_i) ...
        %    + loss(params, labels{i}, ystar_i);
        %assert( abs(rscore-lscore) < 1e-10 );
                
        % 3) get the subgradient
        % [the non-standard notation below is by analogy to the BCFW
        % algorithm -- but you can convince yourself that we are just doing
        % the standard subgradient update:
        %    w_(k+1) = w_k - stepsize*(\lambda*w_k - 1/n psi_i(ystar_i))
        % with stepsize = 1/(\lambda*(k+1))]
        %
        % [note that lambda*w_s is subgradient of 1/n*H_i(w) ]
        % psi_i(y) := phi(x_i,y_i) - phi(x_i, y)
        
        %labels{i}.level = ystar_i.level;
        
        phi_gt = phi(params, model, patterns{i}, labels{i});
        phi_y  = phi(params, model, patterns{i}, ystar_i);
        psi_i = phi_gt - phi_y;
        w_s = 1/(n*lambda) * psi_i;
        
        % 4) step-size gamma:
        gamma = 1/(k+1);
        
        % 5) finally update the weights
        model.w = (1-gamma)*model.w + gamma*n * w_s; % stochastic subgradient update (notice the factor n here)
                    
        % 6) Optionally, update the weighted average:
        if (options.do_weighted_averaging)
            rho = 2/(k+2); % resuls in each iterate w^(k) weighted proportional to k
            wAvg = (1-rho)*wAvg + rho*model.w;
        end
        
        k = k+1;
        
        % DEBUG code
        %model = wtomodel(model.w, model);
        %vis_model(model);
        %pause(1);
        
        % debug: compute objective and duality gap. do not use this flag for
        % timing the optimization, since it is very costly!
        if (options.debug && k == debug_iter)
            model_debug = model;
            
            if (options.do_weighted_averaging)
                model_debug.w = wAvg;
            else
                model_debug.w = model.w;
            end
            primal = primal_objective(params, maxOracle, patterns, labels, model_debug, lambda);
            train_error = average_loss(params, maxOracle, patterns, labels, model_debug);
            fprintf('pass %d (iteration %d), SVM primal = %f, train_error = %f \n', ...
                             p, k, primal, train_error);

            progress.primal = [progress.primal; primal];
            progress.eff_pass = [progress.eff_pass; k/n];
            progress.train_error = [progress.train_error; train_error];
            if (isstruct(options.test_data) && isfield(options.test_data, 'patterns'))
                test_error = average_loss(params, maxOracle, ...
                    options.test_data.patterns, options.test_data.labels, model_debug);
                progress.test_error = [progress.test_error; test_error];
            end

            debug_iter = min(debug_iter+n,ceil(debug_iter*(1+options.debug_multiplier/100))); 
        end

        % time-budget exceeded?
        t_elapsed = toc();
        if (t_elapsed/60 > options.time_budget)
            fprintf('time budget exceeded.\n');
            if (options.do_weighted_averaging)
                model.w = wAvg; % return the averaged version
            end
            return
        end
    end
end
fprintf('\n');

if (options.do_weighted_averaging)
    model.w = wAvg; % return the averaged version
end

end % ssvm_sgd

%% helper functions
function options = defaultOptions(n)
%  options:    (an optional) structure with some of the following fields to
%              customize the behavior of the optimization algorithm:
% 
%   lambda      The regularization constant (default: 1/n).
%   num_passes  Number of iterations (passes through the data) to run the 
%               algorithm. (default: 50)
%   debug       Boolean flag whether to track the primal objective, dual
%               objective, and training error (makes the code about 3x
%               slower given the extra two passes through data).
%               (default: 0)
%   do_weighted_averaging
%               Boolean flag whether to use weighted averaging of the iterates.
%               *Recommended -- it made a big difference in test error in
%               our experiments.*
%               (default: 1)
%   time_budget Number of minutes after which the algorithm should terminate.
%               Useful if the solver is run on a cluster with some runtime
%               limits. (default: inf)
%   rand_seed   Optional seed value for the random number generator.
%               (default: 1)
%   sample      Sampling strategy for example index, either a random permutation
%               ('perm') or uniform sampling ('uniform').
%               (default: 'uniform')
%   debug_multiplier
%               If set to 0, the algorithm computes the objective after each full
%               pass trough the data. If in (0,100) logging happens at a
%               geometrically increasing sequence of iterates, thus allowing for
%               within-iteration logging. The smaller the number, the more
%               costly the computations will be!
%               (default: 0)
%   test_data   Struct with two fields: patterns and labels, which are cell
%               arrays of the same form as the training data. If provided the
%               logging will also evaluate the test error.
%               (default: [])

options = [];
options.num_passes = 50;
options.do_weighted_averaging = 0; % NOTE: seems without averaging better
options.time_budget = inf;
options.debug = 0;
options.rand_seed = 1;
options.sample = 'uniform'; % sampling strategy in {'uniform', 'perm'}
options.debug_multiplier = 0; % 0 corresponds to logging after each full pass
options.lambda = 1/n;
options.test_data = [];

end % defaultOptions
