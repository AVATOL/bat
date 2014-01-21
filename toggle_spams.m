function toggle_spams(start)

persistent orig_envs;

paths = {'external/spams-matlab', ...
         'external/spams-matlab/test_release', ...
         'external/spams-matlab/src_release', ...
         'external/spams-matlab/build'};

spams_envs = {'MKL_NUM_THREADS', '1', ...
              'MKL_SERIAL', 'YES', ...
              'MKL_DYNAMIC', 'NO'};

if isempty(orig_envs)
  orig_envs = cell(length(spams_envs), 1);
  for i = 1:2:length(spams_envs)
    val = getenv(spams_envs{i});
    orig_envs{i} = spams_envs{i};
    orig_envs{i+1} = val;
  end
end

if start
  pathfn = @addpath;
  envs = spams_envs;
else
  pathfn = @rmpath;
  envs = orig_envs;
end

for i = 1:length(paths)
  pathfn(paths{i});
end
if isempty(orig_envs)
  for i = 1:2:length(envs)
    setenv(envs{i}, envs{i+1});
  end
end

